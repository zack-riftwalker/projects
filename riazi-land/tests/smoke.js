#!/usr/bin/env node
/* Smoke tests for riazi-land/index.html (Playwright, 390x844, file://).
   Run:  node riazi-land/tests/smoke.js        (optional: node smoke.js <substring-filter>)
   Add tests for later phases by appending T('name', async (ctx) => {...}) calls in the "PHASE N" blocks below.
   Each test gets a browser; use open()/register() from lib.js. Any uncaught page error fails the test it happened in. */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { chromium, ROOT, FIXTURE, open, register, lsGet, curScreen } = require('./lib');

const tests = [];
const T = (name, fn) => tests.push({ name, fn });
const assert = (c, msg) => { if (!c) throw new Error(msg || 'assertion failed'); };
const eq = (a, b, msg) => assert(JSON.stringify(a) === JSON.stringify(b), `${msg || 'not equal'}: got ${JSON.stringify(a)} expected ${JSON.stringify(b)}`);
const visible = (page, sel) => page.evaluate((s) => { const e = document.querySelector(s); if (!e) return false; const r = e.getBoundingClientRect(); return getComputedStyle(e).display !== 'none' && getComputedStyle(e).visibility !== 'hidden' && r.width > 0 && r.height > 0; }, sel);
const count = (s, sub) => s.split(sub).length - 1;
const LEG = () => FIXTURE('legacy-user.json').localStorage;

/* ============================== PHASE 0 ============================== */

T('page loads without errors, register screen is active', async ({ browser }) => {
  const { page, context } = await open(browser);
  eq(await curScreen(page), 'reg');
  assert(await visible(page, '#s-reg'), 'register screen not visible');
  eq(await page.title(), 'ریاضی‌لند');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('new user: zero -> register -> home screen', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { name: 'نگار احمدی', user: 'negar1', pass: '1234', grade: 7 });
  eq(await curScreen(page), 'home');
  assert(await visible(page, '#s-home'), 'home not visible');
  assert(await visible(page, '#topbar'), 'topbar not visible');
  const r = await page.evaluate(() => ({ user: USER, name: S.name, grade: S.grade, who: $('#who').textContent, regActive: $('#s-reg').classList.contains('active') }));
  eq(r.user, 'negar1'); eq(r.name, 'نگار احمدی'); eq(r.grade, 7); assert(r.who.includes('نگار'), 'who label'); assert(!r.regActive, 'reg still active');
  const us = await lsGet(page, 'mh_users'); assert(us.negar1 && us.negar1.n === 'نگار احمدی', 'user not stored');
  eq(await lsGet(page, 'mh_session'), 'negar1');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('MIGRATION: legacy snapshot opens logged-in with all progress intact', async ({ browser }) => {
  const L = LEG(), D = L.mh_users.ali_r.d;
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER, null, { timeout: 8000 });
  const r = await page.evaluate(() => ({
    user: USER, cur, topbarOn: $('#topbar').classList.contains('on'), regActive: $('#s-reg').classList.contains('active'),
    who: $('#who').textContent, name: S.name, grade: S.grade, coins: S.coins, items: S.items, eq: S.eq, wrong: S.wrong, adv: S.adv,
    team: S.team, learn: S.learn, labN: Object.keys(S.lab).length, game: S.game, quiz: S.quiz, expo: S.expo, memo: S.memo, run: S.run, duel: S.duel,
    arc: S.arc, advExtra: S.advExtra, shopCoins: window.MathHeroShop.coins(), xp: xpOf()
  }));
  assert(r.user === 'ali_r' && !r.regActive && r.topbarOn, 'not logged in / still on register: ' + JSON.stringify([r.user, r.cur]));
  assert(r.cur !== 'reg', 'screen is reg');
  assert(r.who.includes('علی'), 'who label missing name: ' + r.who);
  eq(r.name, 'علی رضایی'); eq(r.grade, 8);
  eq(r.coins, D.coins, 'S.coins'); eq(r.items, D.items, 'items'); eq(r.eq, D.eq, 'eq'); eq(r.wrong, D.wrong, 'wrong'); eq(r.adv, D.adv, 'adv'); eq(r.team, D.team, 'team');
  eq(r.learn, true); eq(r.labN, Object.keys(D.lab).length, 'lab shapes'); eq(r.game, D.game, 'game'); eq(r.quiz, D.quiz, 'quiz'); eq(r.expo, D.expo, 'expo'); eq(r.memo, D.memo, 'memo');
  eq(r.run, D.run, 'run'); eq(r.duel, D.duel, 'duel'); eq(r.arc, D.arc, 'arc'); eq(r.advExtra, D.advExtra, 'advExtra');
  eq(r.shopCoins, L['mathHero.shop.v1'].users['علیرضایی'].coins, 'shop.v1 coins');
  assert(r.xp > 0, 'xp should be computed from results');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('MIGRATION: saved data is not lost after navigating around (persist round-trip)', async ({ browser }) => {
  const L = LEG(), D = L.mh_users.ali_r.d;
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  const whSeed = await lsGet(page, 'wh_ali_r');
  await page.evaluate(() => { go('learn'); go('lab'); go('quiz'); go('expo'); go('memo'); go('adv'); go('shop'); go('home'); });
  const us = await lsGet(page, 'mh_users');
  const d = us.ali_r.d;
  for (const k of ['coins', 'items', 'eq', 'wrong', 'adv', 'team', 'learn', 'lab', 'game', 'quiz', 'survey', 'expo', 'memo', 'run', 'duel', 'grade', 'advExtra'])
    eq(d[k], D[k], 'mh_users.ali_r.d.' + k);
  eq(d.arc.blitz, D.arc.blitz, 'arc.blitz');
  eq(us.sara_k, L.mh_users.sara_k, 'other user untouched');
  eq(us.ali_r.h, L.mh_users.ali_r.h, 'password hash'); eq(us.ali_r.m, L.mh_users.ali_r.m, 'phone');
  eq(await lsGet(page, 'mh_session'), 'ali_r');
  eq(await lsGet(page, 'wh_ali_r'), whSeed, 'wh_ali_r');
  for (const k of ['tm_ali_r', 'mv_ali_r', 'mh_lg', 'mh_ai']) eq(await lsGet(page, k), L[k], k);
  const shop = await lsGet(page, 'mathHero.shop.v1');
  eq(shop.users['علیرضایی'].owned, L['mathHero.shop.v1'].users['علیرضایی'].owned, 'shop owned');
  eq(shop.users['علیرضایی'].coins, 85, 'shop coins');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  // reload keeps session
  await page.reload(); await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [USER, S.coins]), ['ali_r', 235], 'after reload');
  await context.close();
});

T('MIGRATION: legacy user can log in with the form (hash compatibility)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json', drop: ['mh_session'] });
  eq(await curScreen(page), 'reg');
  await page.click('.tabs button[data-m="login"]');
  await page.fill('#inUser', 'ali_r'); await page.fill('#inPass', '1234'); await page.click('#regBtn');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER && cur !== 'reg', null, { timeout: 8000 });
  eq(await page.evaluate(() => [USER, S.coins, S.adv[8]]), ['ali_r', 235, 3]);
  await context.close();
});

T('starting activities gives NO coins (new user and legacy user)', async ({ browser }) => {
  const screens = ['learn', 'lab', 'game', 'quiz', 'expo', 'memo', 'run', 'duel', 'arc:blitz'];
  for (const mode of ['new', 'legacy']) {
    const { page, context } = mode === 'new' ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
    if (mode === 'new') await register(page, { user: 'coin1', name: 'سکه' });
    await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
    const before = await page.evaluate(() => ({ s: S.coins || 0, shop: window.MathHeroShop.coins() }));
    for (const id of screens) await page.evaluate((id) => go(id), id);
    await page.evaluate(() => go('home'));
    const after = await page.evaluate(() => ({ s: S.coins || 0, shop: window.MathHeroShop.coins() }));
    const shopDb = (await lsGet(page, 'mathHero.shop.v1')) || { users: {} };
    eq(after, before, `coins changed after opening screens (${mode})`);
    if (mode === 'legacy') eq(shopDb.users['علیرضایی'].coins, 85, 'stored shop.v1 coins');
    assert(page.errors.length === 0, `pageerror (${mode}): ` + page.errors.join(' | '));
    await context.close();
  }
});

T('floating 🧑‍🏫/🛟 buttons are hidden on register screen and back on home', async ({ browser }) => {
  const { page, context } = await open(browser);
  assert(!(await visible(page, '#btnSup')), '🛟 visible on register screen');
  assert(!(await visible(page, '#btnTch')), '🧑‍🏫 visible on register screen');
  await register(page);
  assert(await visible(page, '#btnSup'), '🛟 should be visible after login');
  assert(await visible(page, '#btnTch'), '🧑‍🏫 should be visible after login');
  await context.close();
});

T('developer credit text appears once', async ({ browser }) => {
  const { page, context } = await open(browser);
  const reg = await page.evaluate(() => document.body.innerText);
  assert(count(reg, 'توسعه‌دهنده') <= 1, 'dup credit on register: ' + count(reg, 'توسعه‌دهنده'));
  await register(page);
  const home = await page.evaluate(() => document.body.innerText);
  eq(count(home, 'توسعه‌دهنده'), 1, 'credit count on home');
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  eq(count(html, '<footer'), 1, '<footer> tags in source');
  await context.close();
});

T('logout is in the profile screen (not next to 🏠) and asks for confirmation', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  assert(!(await page.evaluate(() => !!document.querySelector('#topbar #btnOut'))), '🚪 still in topbar');
  assert(await visible(page, '#btnProf'), 'profile button missing');
  await page.click('#btnProf');
  eq(await curScreen(page), 'prof');
  assert(await visible(page, '#s-prof #btnOut'), 'logout button not in profile');
  await page.click('#s-prof #btnOut');
  assert(await visible(page, '#modal #outYes'), 'no confirmation shown');
  assert((await page.evaluate(() => USER)) === 'ali_r', 'logged out without confirming');
  await page.click('#outNo');
  eq(await page.evaluate(() => USER), 'ali_r', 'cancel must keep the session');
  eq(await lsGet(page, 'mh_session'), 'ali_r');
  await page.click('#s-prof #btnOut'); await page.click('#outYes');
  eq(await curScreen(page), 'reg');
  eq(await page.evaluate(() => USER), null);
  eq(await lsGet(page, 'mh_session'), null);
  eq((await lsGet(page, 'mh_users')).ali_r.d.coins, 235, 'progress kept after logout');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('«حرکات موزون»: answer is hidden until the جواب button is pressed', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'move1' });
  await page.evaluate(() => go('move'));
  assert(await visible(page, '#s-move'), 'move screen not visible');
  const t0 = await page.evaluate(() => document.querySelector('#mvQ').innerText);
  assert(!t0.includes('جواب: ') && !/جواب\s*:/.test(t0), 'answer leaked next to the question: ' + t0);
  assert(await visible(page, '#mvAn'), 'جواب button missing');
  const h = await page.evaluate(() => document.querySelector('#mvAn').getBoundingClientRect().height);
  assert(h >= 44, 'جواب button < 44px: ' + h);
  await page.click('#mvAn');
  const t1 = await page.evaluate(() => document.querySelector('#mvAv').innerText.trim());
  assert(t1.length > 0, 'answer not revealed');
  await context.close();
});

T('no «به‌زودی» lesson/lab message anywhere in the app source or menu', async ({ browser }) => {
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  assert(!html.includes('درسنامه و آزمایشگاه تعاملی این پایه به‌زودی'), 'message still in source');
  for (const g of [7, 9]) {
    const { page, context } = await open(browser);
    await register(page, { user: 'soon' + g, grade: g });
    const txt = await page.evaluate(() => document.querySelector('#s-menu').textContent + document.body.innerText);
    assert(!txt.includes('به‌زودی اضافه می‌شود'), 'soon message visible for grade ' + g);
    await context.close();
  }
});

T('PWA files resolve: manifest, icon-192.png (real 192x192 PNG), sw.js (valid, cache-first); file:// registration is silent', async ({ browser }) => {
  const mf = JSON.parse(fs.readFileSync(path.join(ROOT, 'manifest.webmanifest'), 'utf8'));
  eq([mf.display, mf.dir, mf.lang], ['standalone', 'rtl', 'fa']);
  for (const ic of mf.icons) assert(fs.existsSync(path.join(ROOT, ic.src)), 'icon missing: ' + ic.src);
  const png = fs.readFileSync(path.join(ROOT, 'icon-192.png'));
  eq(png.slice(1, 4).toString(), 'PNG', 'png magic');
  eq([png.readUInt32BE(16), png.readUInt32BE(20)], [192, 192], 'icon size');
  const sw = fs.readFileSync(path.join(ROOT, 'sw.js'), 'utf8');
  new vm.Script(sw);
  assert(/addEventListener\('fetch'/.test(sw) && /caches\.match|c\.match/.test(sw), 'sw has no cache-first fetch');
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  for (const ref of ['manifest.webmanifest', 'icon-192.png', 'sw.js']) assert(html.includes(ref), 'index.html no longer references ' + ref);
  eq(count(html, 'rel="manifest"') + count(html, "rel='manifest'") + count(html, "l.rel='manifest'"), 1, 'exactly one manifest link');
  const { page, context } = await open(browser);
  assert(page.errors.length === 0, 'pageerror on load: ' + page.errors.join(' | '));
  await context.close();
});

T('a11y: topbar buttons are >= 44x44 and have aria-label', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'a11y1' });
  const bad = await page.evaluate(() => [...document.querySelectorAll('#topbar button')].map((b) => { const r = b.getBoundingClientRect(); return { id: b.id, w: r.width, h: r.height, label: !!b.getAttribute('aria-label') }; }).filter((x) => x.w < 44 || x.h < 44 || !x.label));
  eq(bad, [], 'small/unlabelled topbar buttons');
  await context.close();
});

/* ============================== PHASE 1+ : append below ============================== */

/* ---------------------------------- runner ---------------------------------- */
(async () => {
  const filter = process.argv[2] || '';
  const browser = await chromium.launch();
  let passed = 0, failed = 0;
  for (const t of tests) {
    if (filter && !t.name.includes(filter)) continue;
    try { await t.fn({ browser }); passed++; console.log('PASS  ' + t.name); }
    catch (e) { failed++; console.log('FAIL  ' + t.name + '\n      ' + String(e.message).split('\n')[0]); }
  }
  await browser.close();
  console.log(`SUMMARY: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();
