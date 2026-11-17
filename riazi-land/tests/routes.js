#!/usr/bin/env node
/* Dead-route + UI crawl for riazi-land/index.html.   Run: node riazi-land/tests/routes.js
   1) static: every literal go('x') / data-go / list entry (HG, HUB, profile «بیشتر», nav tabs) points to an existing #s-x section
   2) runtime crawl (new user + legacy fixture): click every visible button on path, each bottom tab, profile (+every «بیشتر» entry),
      shop, league and one node of each type (lesson, chest, boss) -> no pageerror, one active non-empty screen each time
   3) no reachable main screen mentions skipped features. Final line: `SUMMARY: X passed, Y failed`. */
const fs = require('fs');
const path = require('path');
const { chromium, ROOT, open, register, curScreen } = require('./lib');
const tests = [];
const T = (name, fn) => tests.push({ name, fn });
const assert = (c, m) => { if (!c) throw new Error(m || 'assertion failed'); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const state = (page) => page.evaluate(() => {
  const act = [...document.querySelectorAll('main .screen.active')];
  return { cur, n: act.length, id: act[0] && act[0].id, len: act[0] ? act[0].textContent.trim().length + act[0].querySelectorAll('svg,canvas').length * 20 : 0 };
});
const settle = async (page, where) => {
  await sleep(120);
  const s = await state(page);
  assert(s.n === 1, `${where}: ${s.n} active screens`);
  assert(s.id === 's-' + s.cur, `${where}: active ${s.id} but cur=${s.cur}`);
  assert(s.len > 15, `${where}: screen ${s.id} looks empty`);
  assert(page.errors.length === 0, `${where}: pageerror ${page.errors.join(' | ')}`);
};

T('static: every go() / data-go / list target has a #s-<id> section', async ({ browser }) => {
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  const lit = new Set();
  for (const m of html.matchAll(/\bgo\((['"])([a-z0-9:]+)\1\)/g)) lit.add(m[2]);
  for (const m of html.matchAll(/data-go="([a-z]+)"/g)) lit.add(m[1]);
  const { page, context } = await open(browser);
  const dyn = await page.evaluate(() => {
    const ids = [];
    HG.forEach((g) => g[1].forEach((x) => ids.push(x[0]))); HUB.forEach((x) => ids.push(x[0]));
    return ids;
  });
  dyn.forEach((x) => lit.add(x));
  const missing = [];
  for (const raw of lit) {
    const id = raw.replace(/^(gm|arc):.*/, (m, p) => (p === 'gm' ? 'gm' : 'arc')).replace(/^menu$/, 'path'); /* menu is redirected to path by design */
    if (!(await page.evaluate((id) => !!document.getElementById('s-' + id), id))) missing.push(raw);
  }
  await context.close();
  assert(missing.length === 0, 'dead routes: ' + missing.join(', '));
  console.log(`      (${lit.size} distinct targets checked)`);
});

const crawl = (mode) => async ({ browser }) => {
  const { page, context } = mode === 'new' ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
  if (mode === 'new') await register(page, { user: 'crawl1', name: 'پیمایش' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  await page.evaluate(() => { S.coins = 1000; persist(); });
  const closeModal = async () => { if (await page.evaluate(() => document.querySelector('#modal').classList.contains('on'))) await page.evaluate(() => document.querySelector('#modal').classList.remove('on')); };
  /* click every visible, enabled button of a screen one by one (returning to it each time) */
  const clickAll = async (label, enter, scope, skip = []) => {
    await enter(); await settle(page, label + ' (enter)');
    const n = await page.evaluate((scope) => [...document.querySelectorAll(scope + ' button')].filter((b) => { const r = b.getBoundingClientRect(); return r.width > 0 && r.height > 0 && !b.disabled; }).length, scope);
    assert(n > 0, label + ': no buttons found');
    for (let k = 0; k < n; k++) {
      await enter(); await closeModal();
      const info = await page.evaluate(([scope, k]) => { const bs = [...document.querySelectorAll(scope + ' button')].filter((b) => { const r = b.getBoundingClientRect(); return r.width > 0 && r.height > 0 && !b.disabled; }); const b = bs[k]; if (!b) return null; b.setAttribute('data-crawl', '1'); return { id: b.id, t: b.textContent.trim().slice(0, 20) }; }, [scope, k]);
      if (!info) continue;
      if (skip.includes(info.id)) { await page.evaluate(() => document.querySelector('[data-crawl]').removeAttribute('data-crawl')); continue; }
      await page.evaluate(() => { const b = document.querySelector('[data-crawl]'); b.removeAttribute('data-crawl'); b.click(); });
      await settle(page, `${label} › «${info.t || info.id}»`);
      await closeModal();
      await page.evaluate(() => { try { if (Lesson.st) Lesson.st = null; } catch (e) {} });
    }
  };
  const toPath = () => page.evaluate(() => go('path'));
  /* seed one node of each type so the crawl reaches lesson, chest and boss */
  await clickAll('path', toPath, '#s-path', []);
  await page.evaluate(() => { S.path = { l: { 8: { 0: { L: [{ s: 3, a: 100 }, { s: 3, a: 100 }, { s: 3, a: 100 }, { s: 3, a: 100 }], c: 0 } } }, xp: { d: 0, b: 0, v: 0 } }, S.adv = Object.assign(S.adv || {}, { 8: 0 }); S.grade = 8; go('path'); });
  assert(await page.evaluate(() => document.querySelector('#pcur').dataset.k === 'C'), 'chest should be current');
  await clickAll('path(chest)', toPath, '#s-path'); /* chest opens, boss becomes current */
  await page.evaluate(() => { S.path.l[8][0].c = 1; go('path'); });
  assert(await page.evaluate(() => document.querySelector('#pcur').dataset.k === 'B'), 'boss should be current');
  await clickAll('path(boss)', toPath, '#s-path');
  /* tabs */
  for (const tab of ['path', 'league', 'shop', 'prof']) { await page.click(`#bnav [data-go="${tab}"]`); await settle(page, 'tab ' + tab); }
  await page.evaluate(() => { S.coins = 1000; });
  await clickAll('league', () => page.click('#bnav [data-go="league"]'), '#s-league');
  await clickAll('shop', () => page.click('#bnav [data-go="shop"]'), '#s-shop');
  await clickAll('profile', () => page.click('#bnav [data-go="prof"]'), '#s-prof', ['btnOut']);
  /* every «بیشتر» entry */
  const ids = await page.evaluate(() => { go('prof'); return [...document.querySelectorAll('#pMore [data-more]')].map((b) => b.dataset.more); });
  for (const id of ids) { await page.click('#bnav [data-go="prof"]'); await page.click(`#pMore [data-more="${id}"]`); await settle(page, 'بیشتر › ' + id); await page.evaluate(() => go('path')); }
  /* brand + header */
  await page.click('#btnBrand'); await settle(page, 'brand');
  await context.close();
};
T('crawl: new user — every reachable button on path/tabs/profile/shop/league/node types', crawl('new'));
T('crawl: legacy fixture — same', crawl('legacy'));

T('no reachable main screen mentions skipped features (daily missions / play-time / ghosts / friend challenge / «soon»)', async ({ browser }) => {
  const bad = /ماموریت روزانه|مأموریت روزانه|زمان بازی|ماموریت سه|شبح|چالش دوست|به‌زودی|بزودی|لیگ هفتگی/;
  for (const mode of ['new', 'legacy']) {
    const { page, context } = mode === 'new' ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
    if (mode === 'new') await register(page, { user: 'skip1' });
    await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
    for (const id of ['path', 'league', 'shop', 'prof']) {
      await page.evaluate((id) => go(id), id);
      const t = await page.evaluate(() => document.querySelector('main .screen.active').innerText);
      assert(!bad.test(t), `${mode}/${id} mentions a skipped feature: ${(t.match(bad) || [])[0]}`);
    }
    await context.close();
  }
});

(async () => {
  const browser = await chromium.launch();
  let passed = 0, failed = 0;
  for (const t of tests) {
    try { await t.fn({ browser }); passed++; console.log('PASS  ' + t.name); }
    catch (e) { failed++; console.log('FAIL  ' + t.name + '\n      ' + String(e.message).split('\n')[0]); }
  }
  await browser.close();
  console.log(`SUMMARY: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();
