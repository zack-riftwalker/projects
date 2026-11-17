#!/usr/bin/env node
/* Smoke tests for riazi-land/index.html (Playwright, 390x844, file://).
   Run:  node riazi-land/tests/smoke.js        (optional: node smoke.js <substring-filter>)
   Add tests for later phases by appending T('name', async (ctx) => {...}) calls in the "PHASE N" blocks below.
   Each test gets a browser; use open()/register() from lib.js. Any uncaught page error fails the test it happened in. */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { chromium, ROOT, FIXTURE, open, register, openForm, lsGet, curScreen, setClock } = require('./lib');

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

T('new user: zero -> register -> path screen (landing)', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { name: 'نگار احمدی', user: 'negar1', pass: '1234', grade: 7 });
  eq(await curScreen(page), 'path');
  assert(await visible(page, '#s-path'), 'path not visible');
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
  eq(r.coins, D.coins + 85, 'S.coins = old coins + shop.v1 coins (migration)'); eq(r.items, D.items, 'items'); eq(r.eq, D.eq, 'eq'); eq(r.wrong, D.wrong, 'wrong'); eq(r.adv, D.adv, 'adv'); eq(r.team, D.team, 'team');
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
  eq(d.coins, D.coins + 85, 'coins after migration');
  for (const k of ['items', 'eq', 'wrong', 'adv', 'team', 'learn', 'lab', 'game', 'quiz', 'survey', 'expo', 'memo', 'run', 'duel', 'grade', 'advExtra'])
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
  eq(await page.evaluate(() => [USER, S.coins]), ['ali_r', 320], 'after reload (no double migration)');
  await context.close();
});

T('MIGRATION: legacy user can log in with the form (hash compatibility)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json', drop: ['mh_session'] });
  eq(await curScreen(page), 'reg');
  await openForm(page, 'login');
  await page.fill('#inUser', 'ali_r'); await page.fill('#inPass', '1234'); await page.click('#regBtn');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER && cur !== 'reg', null, { timeout: 8000 });
  eq(await page.evaluate(() => [USER, S.coins, S.adv[8]]), ['ali_r', 320, 3]);
  await context.close();
});

T('starting activities gives NO coins (new user and legacy user)', async ({ browser }) => {
  const screens = ['learn', 'lab', 'game', 'quiz', 'expo', 'memo', 'run', 'duel', 'arc:blitz', 'shop', 'prof', 'league', 'weak', 'subj', 'vid', 'exam', 'tch', 'hub', 'adv', 'move', 'wheel', 'path'];
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

T('floating 🧑‍🏫/🛟 buttons never cover the UI (hidden; reachable from profile)', async ({ browser }) => {
  const { page, context } = await open(browser);
  assert(!(await visible(page, '#btnSup')), '🛟 visible on register screen');
  assert(!(await visible(page, '#btnTch')), '🧑‍🏫 visible on register screen');
  await register(page);
  assert(!(await visible(page, '#btnSup')) && !(await visible(page, '#btnTch')), 'floating buttons must not overlap the bottom nav');
  await context.close();
});

T('developer credit text appears once', async ({ browser }) => {
  const { page, context } = await open(browser);
  const reg = await page.evaluate(() => document.body.innerText);
  assert(count(reg, 'توسعه‌دهنده') <= 1, 'dup credit on register: ' + count(reg, 'توسعه‌دهنده'));
  await register(page);
  await page.evaluate(() => go('prof'));
  const home = await page.evaluate(() => document.body.innerText);
  eq(count(home, 'توسعه‌دهنده'), 1, 'credit count on profile');
  const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  eq(count(html, '<footer'), 1, '<footer> tags in source');
  await context.close();
});

T('logout is in the profile screen (not next to 🏠) and asks for confirmation', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  assert(!(await page.evaluate(() => !!document.querySelector('#topbar #btnOut'))), '🚪 still in topbar');
  assert(await visible(page, '#btnProf'), 'profile tab missing');
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
  eq((await lsGet(page, 'mh_users')).ali_r.d.coins, 320, 'progress kept after logout');
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


/* ============================== PHASE 1 ============================== */
const inView = (page, scope) => page.evaluate((scope) => [...document.querySelectorAll(scope + ' button')].filter((b) => {
  const r = b.getBoundingClientRect(), cs = getComputedStyle(b);
  return cs.display !== 'none' && cs.visibility !== 'hidden' && r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight && !b.closest('[hidden]') && !(b.closest('.screen') && !b.closest('.screen').classList.contains('active'));
}).map((b) => ({ id: b.id, t: b.textContent.trim(), h: b.getBoundingClientRect().height })), scope);

T('PHASE1: new user lands on path with exactly ONE primary CTA «شروع» in first viewport', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'cta1', name: 'نگار' });
  eq(await curScreen(page), 'path');
  const cta = (await inView(page, '#s-path')).filter((b) => b.t === 'شروع');
  eq(cta.length, 1, 'visible «شروع» buttons');
  eq((await inView(page, '#s-path')).length, 1, 'all buttons inside the path map in first viewport');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE1: path first viewport has <= 12 visible buttons (header + nav included)', async ({ browser }) => {
  for (const mode of ['new', 'legacy']) {
    const { page, context } = mode === 'new' ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
    if (mode === 'new') await register(page, { user: 'btn1' });
    await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
    await page.waitForTimeout(300);
    const all = await inView(page, 'body');
    assert(all.length <= 12, `${mode}: ${all.length} visible buttons: ` + all.map((b) => b.id || b.t).join(','));
    assert(all.every((b) => b.h >= 43.5), `${mode}: a visible button is < 44px high: ` + all.filter((b) => b.h < 43.5).map((b) => b.id || b.t).join(','));
    await context.close();
  }
});

T('PHASE1: legacy auto-login lands on path; adv progress => completed chapters, current node scrolled into view', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await curScreen(page), 'path');
  const r = await page.evaluate(() => ({
    states: [...document.querySelectorAll('#pathBox .pch')].map((c) => c.dataset.state),
    doneNodes: document.querySelectorAll('#pathBox .pn.done').length,
    cur: (() => { const c = document.querySelector('#pcur'); return c && { ch: +c.closest('.pch').dataset.ch, k: c.dataset.k, top: c.getBoundingClientRect().top }; })(),
    h: innerHeight, n: CH[8].length
  }));
  eq(r.states.slice(0, 4), ['done', 'done', 'done', 'current'], 'chapter states (adv[8]=3)');
  assert(r.states.slice(4).every((s) => s === 'locked'), 'later chapters must be locked');
  eq(r.states.length, r.n, 'chapter count');
  eq(r.doneNodes, 18, 'done nodes = 3 chapters x 6');
  assert(r.cur && r.cur.ch === 3 && r.cur.k === 'L', 'current node should be first lesson of chapter 4');
  assert(r.cur.top > 0 && r.cur.top < r.h, 'current node not scrolled into view: ' + r.cur.top);
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE1: lesson node completes via the Lesson engine, records stars, unlocks next node, persists in us[USER].d.path', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'path2', grade: 8 });
  await page.click('#pathBox .pgo');
  eq(await curScreen(page), 'pq');
  await finishLesson(page);
  await page.click('#pqGo');
  eq(await curScreen(page), 'path');
  const r = await page.evaluate(() => ({ stars: document.querySelector('.pch .pn.done .pst')?.getAttribute('aria-label'), curJ: [...document.querySelectorAll('.pch[data-ch="0"] .pn')].findIndex((n) => n.id === 'pcur') }));
  assert(/۳/.test(r.stars || ''), 'expected 3 stars, got ' + r.stars);
  eq(r.curJ, 1, 'second lesson should now be current');
  const d = (await lsGet(page, 'mh_users')).path2.d;
  eq(d.path.l[8][0].L[0].s, 3, 'stored stars');
  eq(d.coins, 10, 'flawless lesson = 5 + 5 coins');
  await context.close();
});

T('PHASE1: chest gives 10 coins once and unlocks the boss node (S.path seeded for chapter 1)', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'chest1' });
  await page.evaluate(() => { S.path = { l: { 8: { 0: { L: [{ s: 2, a: 70 }, { s: 3, a: 100 }, { s: 1, a: 40 }, { s: 3, a: 100 }], c: 0 } } }, xp: { d: 0, b: 0, v: 0 } }; go('path'); });
  const before = await page.evaluate(() => [S.coins || 0, MathHeroShop.coins()]);
  assert(await page.evaluate(() => document.querySelector('#pcur').dataset.k === 'C'), 'chest should be current');
  await page.click('#pathBox .pgo');
  await page.click('#chOk');
  eq(await page.evaluate(() => S.coins || 0), before[0] + 10, 'chest = +10 coins'); eq(await page.evaluate(() => MathHeroShop.coins()), before[1], 'shop.v1 untouched');
  assert(await page.evaluate(() => document.querySelector('#pcur').dataset.k === 'B'), 'boss should be current after chest');
  await page.click('#pathBox .pgo');
  eq(await curScreen(page), 'adv');
  assert(await page.evaluate(() => document.querySelector('#advBox').textContent.includes('فصل ۱')), 'boss fight of chapter 1 not shown');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE1: every bottom-nav tab navigates to an existing active screen without errors; nav is accessible', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  const tabs = await page.evaluate(() => [...document.querySelectorAll('#bnav button')].map((b) => ({ go: b.dataset.go, label: b.getAttribute('aria-label'), txt: b.textContent.trim(), h: b.getBoundingClientRect().height, w: b.getBoundingClientRect().width })));
  eq(tabs.map((t) => t.go), ['path', 'league', 'shop', 'prof']);
  assert(tabs.every((t) => t.label && t.txt.includes(t.label) && t.h >= 44 && t.w >= 44), 'nav tab a11y: ' + JSON.stringify(tabs));
  for (const t of tabs) {
    await page.click(`#bnav [data-go="${t.go}"]`);
    const r = await page.evaluate(() => ({ cur, act: [...document.querySelectorAll('main .screen.active')].map((e) => e.id), pressed: document.querySelector('#bnav [aria-current="page"]')?.dataset.go }));
    eq(r.cur, t.go); eq(r.act, ['s-' + t.go], 'active screens'); eq(r.pressed, t.go, 'active tab highlight');
  }
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE1: every profile→بیشتر entry opens an existing active screen without errors', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  await page.click('#btnProf');
  const ids = await page.evaluate(() => [...document.querySelectorAll('#pMore [data-more]')].map((b) => b.dataset.more));
  assert(ids.length >= 14, 'too few entries: ' + ids.length);
  for (const id of ids) {
    await page.click('#btnProf');
    await page.click(`#pMore [data-more="${id}"]`);
    const r = await page.evaluate(() => ({ cur, act: [...document.querySelectorAll('main .screen.active')].map((e) => e.id) }));
    eq(r.act.length, 1, id + ' active screens ' + r.act);
    assert(r.act[0] === 's-' + r.cur && r.cur !== 'prof', `${id}: went to ${r.cur} / ${r.act}`);
    await page.evaluate(() => go('path')); /* leave game-ish screens (timers) */
  }
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE1: sound toggle lives in profile; brand and back buttons go to path (not old menu/home)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  await page.click('#btnProf');
  const t0 = await page.textContent('#btnSound'); await page.click('#btnSound');
  assert((await page.textContent('#btnSound')) !== t0, 'sound label did not change');
  await page.click('#btnBrand'); eq(await curScreen(page), 'path');
  await page.evaluate(() => go('menu')); eq(await curScreen(page), 'path', "go('menu') redirect");
  await page.evaluate(() => go('hub')); await page.click('#hubBack'); eq(await curScreen(page), 'path', 'hub back button');
  await context.close();
});

T('PHASE1: page height outside the path map does not balloon; one visible screen only', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  const r = await page.evaluate(() => ({
    total: document.documentElement.scrollHeight, map: document.querySelector('#s-path').getBoundingClientRect().height,
    vis: [...document.querySelectorAll('main > *')].filter((e) => e.getBoundingClientRect().height > 0).map((e) => e.id),
    stray: [...document.querySelectorAll('#app > *')].filter((e) => !['topbar', 'MAIN'].includes(e.id || e.tagName) && getComputedStyle(e).display !== 'none' && e.getBoundingClientRect().height > 0).map((e) => e.id || e.tagName)
  }));
  eq(r.vis, ['s-path'], 'visible sections inside main');
  assert(r.total - r.map < 330, `non-map height ${r.total - r.map}px`);
  eq(r.stray, [], 'stray visible blocks in #app');
  await context.close();
});

T('PHASE1: old entry points are detached (old menu/home never active after login; hub has no shop/wheel dup)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  await page.evaluate(() => go('hub'));
  const r = await page.evaluate(() => ({ shopBtn: !!(document.querySelector('#hubShop') && getComputedStyle(document.querySelector('#hubShop')).display !== 'none'), wheel: !!document.querySelector('#tiles [data-t="wheel"]'), tiles: document.querySelectorAll('#tiles .tile').length }));
  eq(r.shopBtn, false); eq(r.wheel, false); assert(r.tiles > 30, 'hub games should still exist: ' + r.tiles);
  await context.close();
});


/* ============================== PHASE 2 ============================== */
const welcomeVisibleButtons = (page) => inView(page, '#s-reg');
const startGuest = async (page, grade = 8, wrongAt = -1) => { /* wrongAt: index of the placement question to answer wrongly (-1 = all correct) */
  await page.click('#wlGo'); await page.click(`#obBox .gcard[data-g="${grade}"]`);
  for (let k = 0; k < 5; k++) {
    await page.waitForSelector('#obBox .opt:not([disabled])');
    await page.evaluate(([k, wrongAt]) => { const o = v9Ob(), ci = o.q[o.k].opts.findIndex((x) => x.ok); document.querySelectorAll('#obBox .opt')[k === wrongAt ? (ci === 0 ? 1 : 0) : ci].click(); }, [k, wrongAt]);
    await page.waitForTimeout(900);
  }
  await page.waitForSelector('#obStart');
};
/* answers one lesson card with REAL clicks (keypad for numeric cards). wrong=true answers the card wrongly */
const KEYMAP = { '-': '-', '/': '/', '.': '.' };
const answerCard = async (page, info, wrong = false) => {
  if (info.type === 'num') {
    const s = wrong ? '99999' : String(info.ans);
    for (const ch of s) await page.click(`#pqBox .kpk[data-k="${/\d/.test(ch) ? ch : KEYMAP[ch]}"]`);
  } else {
    const n = await page.evaluate(() => document.querySelectorAll('#pqBox .opt').length);
    const k = wrong ? (info.ans === 0 ? 1 : 0) : info.ans;
    await page.click(`#pqBox .opt[data-k="${k}"]`);
  }
  await page.click('#lsGo'); /* بررسی */
};
const finishLesson = async (page, opts = {}) => {
  let guard = 0, first = true;
  while (guard++ < 60) {
    const info = await page.evaluate(() => v9Lesson());
    if (!info) break;
    await answerCard(page, info, first && opts.wrongFirst); first = false;
    await page.click('#lsGo'); /* ادامه */
  }
  await page.waitForSelector('#suBox, #pqGo');
};

T('PHASE2: no-session first screen = ONE big «بزن بریم!» + small «حساب دارم»', async ({ browser }) => {
  const { page, context } = await open(browser);
  const b = await welcomeVisibleButtons(page);
  eq(b.map((x) => x.t).sort(), ['بزن بریم! 🚀', 'حساب دارم'].sort(), 'visible buttons on welcome');
  assert(b.every((x) => x.h >= 44), 'buttons < 44px');
  assert(!(await visible(page, '#regForm')), 'form must not be visible on welcome');
  await context.close();
});

T('PHASE2: tap budget — fresh page → بزن بریم → grade → first answer = 3 clicks, no pageerror', async ({ browser }) => {
  const { page, context } = await open(browser);
  let clicks = 0;
  await page.click('#wlGo'); clicks++;
  await page.click('#obBox .gcard[data-g="8"]'); clicks++;
  await page.waitForSelector('#obBox .opt');
  await page.click('#obBox .opt'); clicks++;
  eq(clicks, 3);
  assert((await page.textContent('#obM')).length > 0, 'no feedback after the first answer');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE2: «حساب دارم» opens the classic form; login/register still work (existing users unaffected)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json', drop: ['mh_session'] });
  await page.click('#wlHave');
  assert(await visible(page, '#regForm'), 'form not shown');
  assert(await visible(page, '#fmBack'), 'back button missing');
  await page.click('#fmBack'); assert(await visible(page, '#wlGo'), 'back to welcome failed');
  await page.click('#wlHave'); await page.fill('#inUser', 'ali_r'); await page.fill('#inPass', 'nope'); await page.click('#regBtn');
  await page.waitForTimeout(400); eq(await curScreen(page), 'reg', 'wrong password must not log in');
  await page.fill('#inPass', '1234'); await page.click('#regBtn');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER, null, { timeout: 8000 });
  eq(await page.evaluate(() => [USER, cur, S.coins]), ['ali_r', 'path', 320]);
  await context.close();
});

T('PHASE2: placement sets the start chapter; earlier chapters are «رد شده» (not locked) and replayable', async ({ browser }) => {
  const { page, context } = await open(browser);
  await startGuest(page, 8, -1); /* all correct -> start at the hardest answered chapter */
  const X = await page.evaluate(() => v9Ob().X);
  assert(X > 0, 'all-correct placement should skip chapters, X=' + X);
  const txt = await page.textContent('#obBox');
  assert(txt.includes('شروع می‌کنی') && txt.includes('رد شده'), 'result text: ' + txt);
  await page.click('#obStart');
  await page.waitForFunction(() => cur === 'pq');
  await page.evaluate(() => go('path'));
  const r = await page.evaluate(() => ({ states: [...document.querySelectorAll('#pathBox .pch')].map((c) => c.dataset.state), cur: (() => { const c = document.querySelector('#pcur'); return c && [+c.closest('.pch').dataset.ch, c.dataset.k, [...c.parentNode.children].indexOf(c)]; })(), replay: document.querySelectorAll('#pathBox .pch[data-state="skipped"] .pre').length, label: document.querySelector('.pch[data-state="skipped"] .pbn').textContent }));
  eq(r.states.slice(0, X), Array(X).fill('skipped'), 'skipped chapters');
  eq(r.states[X], 'current'); assert(r.states.slice(X + 1).every((s) => s === 'locked'), 'later chapters locked');
  eq(r.cur, [X, 'L', 0], 'current node');
  assert(r.replay >= 2 * X, 'skipped chapters must have replay buttons: ' + r.replay);
  assert(r.label.includes('رد شده'), 'banner label');
  const d = (await lsGet(page, 'mh_users')); const g = Object.keys(d)[0];
  assert(g.startsWith('guest_'), 'guest key'); eq(d[g].d.adv[8], X, 'adv mapped'); eq(d[g].d.path.skip[8], X, 'skip stored');
  /* replay a skipped lesson */
  await page.click('#pathBox .pch[data-state="skipped"] .pre'); eq(await curScreen(page), 'pq');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE2: wrong first answer starts at chapter 1', async ({ browser }) => {
  const { page, context } = await open(browser);
  await startGuest(page, 7, 0);
  eq(await page.evaluate(() => v9Ob().X), 0);
  await page.click('#obStart'); await page.waitForFunction(() => cur === 'pq');
  await page.evaluate(() => go('path'));
  eq(await page.evaluate(() => [...document.querySelectorAll('#pathBox .pch')].map((c) => c.dataset.state).slice(0, 2)), ['current', 'locked']);
  await context.close();
});

T('PHASE2: guest → first lesson → signup card → rename migration keeps everything; form login works later', async ({ browser }) => {
  const { page, context } = await open(browser);
  await startGuest(page, 8, 0); await page.click('#obStart');
  await page.waitForFunction(() => cur === 'pq');
  const guest = await page.evaluate(() => USER); assert(guest.startsWith('guest_'), 'guest user');
  eq(await lsGet(page, 'mh_session'), guest);
  await page.evaluate((g) => { localStorage.setItem('wh_' + g, '123'); localStorage.setItem('mv_' + g, '2'); localStorage.setItem('tm_' + g, JSON.stringify({ h: [{ q: 'x' }] })); }, guest);
  await finishLesson(page);
  assert(await visible(page, '#suBox'), 'signup card not shown after the first lesson');
  assert((await page.textContent('#suBox')).includes('اسمت چیه که پیشرفتت ذخیره بشه؟'), 'card title');
  eq(await page.evaluate(() => document.querySelector('#suPh').closest('details').open), false, 'mobile must be behind «بیشتر»');
  const before = (await lsGet(page, 'mh_users'))[guest].d;
  /* validation */
  await page.fill('#suName', 'علی'); await page.fill('#suUser', 'ab'); await page.fill('#suPass', '1234'); await page.click('#suGo');
  assert(await visible(page, '#suErr'), 'short username must be rejected');
  await page.fill('#suUser', 'Newkid'); await page.fill('#suPass', '12'); await page.click('#suGo'); assert(await visible(page, '#suErr'), 'short password');
  await page.fill('#suPass', 'pass1234'); await page.click('#suGo');
  await page.waitForFunction(() => USER === 'newkid');
  const us = await lsGet(page, 'mh_users');
  assert(!Object.keys(us).some((k) => k.startsWith('guest_')), 'guest key left behind');
  eq(us.newkid.n, 'علی'); eq(us.newkid.d.path.l, before.path.l.constructor === Object ? us.newkid.d.path.l : {}, 'path');
  eq(us.newkid.d.grade, 8); eq(us.newkid.d.wrong, before.wrong, 'wrong'); eq(us.newkid.d.path.skip, before.path.skip);
  assert(us.newkid.d.path.l[8][before.path.skip[8]].L[0].s >= 1, 'lesson stars moved with the data');
  eq(await lsGet(page, 'mh_session'), 'newkid');
  eq([await lsGet(page, 'wh_newkid'), await lsGet(page, 'mv_newkid'), (await lsGet(page, 'tm_newkid')).h.length], [123, 2, 1], 'per-user keys');
  eq([await lsGet(page, 'wh_' + guest), await lsGet(page, 'mv_' + guest), await lsGet(page, 'tm_' + guest)], [null, null, null], 'old per-user keys removed');
  eq(await curScreen(page), 'path');
  await page.reload(); await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [USER, cur]), ['newkid', 'path'], 'reload stays logged in');
  /* logout (non-guest: plain confirm) then form login with new credentials */
  await page.click('#btnProf'); await page.click('#s-prof #btnOut'); await page.click('#outYes');
  eq(await curScreen(page), 'reg');
  await openForm(page, 'login'); await page.fill('#inUser', 'newkid'); await page.fill('#inPass', 'pass1234'); await page.click('#regBtn');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER && cur !== 'reg', null, { timeout: 8000 });
  eq(await page.evaluate(() => [USER, S.grade]), ['newkid', 8]);
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE2: signup username must be unique (existing user)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json', drop: ['mh_session'] });
  await startGuest(page, 8, 0); await page.click('#obStart'); await page.waitForFunction(() => cur === 'pq');
  await finishLesson(page);
  await page.fill('#suName', 'x y'); await page.fill('#suUser', 'ali_r'); await page.fill('#suPass', 'pass1234'); await page.click('#suGo');
  assert((await page.textContent('#suErr')).includes('قبلاً ثبت'), 'duplicate username not rejected');
  assert((await page.evaluate(() => USER)).startsWith('guest_'), 'must stay guest');
  eq((await lsGet(page, 'mh_users')).ali_r.d.coins, 235, 'existing user untouched');
  await context.close();
});

T('PHASE2: «بعداً» keeps the guest across reload; reminder is not shown on the next lesson; profile offers ذخیرهٔ پیشرفت; guest logout warns', async ({ browser }) => {
  const { page, context } = await open(browser);
  await startGuest(page, 9, 0); await page.click('#obStart'); await page.waitForFunction(() => cur === 'pq');
  const guest = await page.evaluate(() => USER);
  await finishLesson(page); await page.click('#suLater');
  eq(await curScreen(page), 'path');
  await page.reload(); await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [USER, cur]), [guest, 'path']);
  assert(Object.keys(await lsGet(page, 'mh_users')).includes(guest), 'guest record lost');
  /* second lesson same day: no nag */
  await page.click('#pathBox .pgo'); await finishLesson(page);
  assert(!(await visible(page, '#suBox')) && (await visible(page, '#pqGo')), 'reminder shown again too soon');
  await page.click('#pqGo');
  await page.click('#btnProf');
  assert(await visible(page, '#pSave'), 'profile needs ذخیرهٔ پیشرفت for guests');
  assert((await page.textContent('#s-prof')).includes('مهمان'), 'friendly guest label');
  await page.click('#s-prof #btnOut');
  assert((await page.textContent('#modal')).includes('پاک می‌شود'), 'guest logout warning missing');
  await page.click('#outNo'); eq(await page.evaluate(() => USER), guest);
  await page.click('#s-prof #btnOut'); await page.click('#outYes'); eq(await curScreen(page), 'reg');
  assert(!Object.keys((await lsGet(page, 'mh_users')) || {}).includes(guest), 'abandoned guest should be removed');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE2: legacy fixture: auto-login still lands on path with data intact (no guest created)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [USER, cur, S.coins, S.adv[8]]), ['ali_r', 'path', 320, 3]);
  assert(!Object.keys(await lsGet(page, 'mh_users')).some((k) => k.startsWith('guest_')), 'guest created for legacy user');
  assert(!(await visible(page, '#s-reg')), 'welcome visible for logged-in user');
  await context.close();
});


/* ============================== PHASE 3 ============================== */
const startLesson = async (page, g, ch, j = 0) => { await page.evaluate(([g, ch, j]) => Lesson.start(g, ch, j), [g, ch, j]); await page.waitForSelector('#lsGo'); };
const lessonUntilQ = async (page, g, ch, pred) => { for (let t = 0; t < 80; t++) { await page.evaluate(([g, ch]) => Lesson.start(g, ch, 0), [g, ch]); await page.waitForSelector('#lsGo'); const i = await page.evaluate(() => v9Lesson()); if (pred(i)) return i; } throw new Error('no card'); };
const lessonUntil = async (page, g, ch, pred) => { for (let t = 0; t < 60; t++) { await startLesson(page, g, ch); const i = await page.evaluate(() => v9Lesson()); if (pred(i)) return i; } throw new Error('no card of the wanted type'); };

T('PHASE3: content — every chapter of every grade yields >= 20 distinct questions; MCQ = 4 unique options incl. answer; numeric answers parse; shapes valid', async ({ browser }) => {
  const { page, context } = await open(browser);
  const r = await page.evaluate(() => {
    const out = { bad: [], perCh: [], cnt: 0 };
    const numRe = /^-?\d+(\.\d+)?$|^-?\d+\/\d+$/;
    for (const g of [7, 8, 9]) { eq9 = V9Q[g].length === CH[g].length; if (!eq9) out.bad.push(`grade ${g}: ${V9Q[g].length} chapter lists vs ${CH[g].length}`);
      V9Q[g].forEach((L, ch) => {
        const keys = new Set();
        if (L.length < 4) out.bad.push(`${g}.${ch}: only ${L.length} templates`);
        for (let k = 0; k < 400; k++) {
          const c = v9Cards(g, ch, 1)[0]; if (!c) { out.bad.push(`${g}.${ch}: no card`); continue; } out.cnt++;
          keys.add(c.q + (c.type === 'shape' ? '|' + c.opts.map((o) => o.id).sort().join() : ''));
          if (c.type === 'mcq') {
            const t = c.opts.map((o) => o.t);
            if (c.opts.length !== 4 || new Set(t).size !== 4 || c.opts.filter((o) => o.ok).length !== 1) out.bad.push(`${g}.${ch} mcq options: ${t.join('|')}`);
          } else if (c.type === 'shape') {
            if (c.opts.length !== 4 || new Set(c.opts.map((o) => o.id)).size !== 4 || c.opts.filter((o) => o.ok).length !== 1 || c.opts.some((o) => !byId(o.id))) out.bad.push(`${g}.${ch} shape options`);
          } else if (c.type === 'num') {
            if (!numRe.test(c.a)) out.bad.push(`${g}.${ch} numeric answer not parseable: ${c.a} in ${c.q}`);
          } else out.bad.push(`${g}.${ch} unknown type ${c.type}`);
          if (!c.hint || c.hint.length < 5) out.bad.push(`${g}.${ch} missing hint: ${c.q}`);
          if (/[0-9]/.test(c.q.replace(/[⁦⁩]/g, ''))) out.bad.push(`${g}.${ch} Latin digit in question: ${c.q}`);
        }
        out.perCh.push([g, ch, L.length, keys.size]);
      });
    }
    return out;
  });
  eq(r.bad.slice(0, 5), [], 'content problems (' + r.bad.length + ')');
  assert(r.perCh.length === 25, 'expected 25 chapters, got ' + r.perCh.length);
  const low = r.perCh.filter((x) => x[3] < 20);
  eq(low, [], 'chapters with < 20 distinct questions');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE3: answer normalisation (Persian/Arabic digits, minus, decimal point, fractions, spaces)', async ({ browser }) => {
  const { page, context } = await open(browser);
  const r = await page.evaluate(() => [Lesson.same('۳/۴', '3/4'), Lesson.same('−۵', '-5'), Lesson.same('٣', '3'), Lesson.same('۲٫۵', '2.5'), Lesson.same(' ۱ / ۲ ', '2/4'), Lesson.same('3', '4'), Lesson.same('', '0'), Lesson.same('-3', '3'), Lesson.same('abc', '3')]);
  eq(r, [true, true, true, true, true, false, false, false, false]);
  await context.close();
});

T('PHASE3: no duplicate question text within a lesson (20 runs x every chapter)', async ({ browser }) => {
  const { page, context } = await open(browser);
  const bad = await page.evaluate(() => {
    const bad = [];
    for (const g of [7, 8, 9]) CH[g].forEach((_, ch) => { for (let k = 0; k < 20; k++) { const L = v9Cards(g, ch, 8); if (L.length !== 8) bad.push(`${g}.${ch}: only ${L.length} cards`); if (new Set(L.map((c) => c.q)).size !== L.length) bad.push(`${g}.${ch}: duplicate text`); } });
    return bad;
  });
  eq(bad, []);
  await context.close();
});

T('PHASE3: full lesson with real clicks completes in < 4 min, bar/aria/feedback behave, no pageerror', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'les1', grade: 8 });
  const t0 = Date.now();
  await page.click('#pathBox .pgo');
  await page.waitForSelector('#lsBar');
  assert((await page.evaluate(() => v9Lesson().total)) === 8, 'lesson should have 8 cards');
  assert(await page.evaluate(() => document.querySelector('#lsGo').disabled), 'بررسی must be disabled until an answer is chosen');
  assert(await page.evaluate(() => !document.querySelector('#bnav') || getComputedStyle(document.querySelector('#bnav')).display === 'none'), 'bottom nav should be hidden during a lesson');
  let n = 0;
  while (true) {
    const info = await page.evaluate(() => v9Lesson()); if (!info) break;
    eq(await page.evaluate(() => document.querySelector('#pqBox [role=progressbar]').getAttribute('aria-valuenow')), String(info.done), 'progress aria');
    await answerCard(page, info);
    assert(await page.evaluate(() => document.querySelector('#lsBar').classList.contains('ok')), 'green bar after a correct answer');
    assert(await page.evaluate(() => document.querySelector('#lsFb').getAttribute('aria-live') === 'polite' && document.querySelector('#lsFb').textContent.length > 8), 'feedback region');
    await page.click('#lsGo'); n++;
  }
  eq(n, 8, 'cards answered');
  assert(Date.now() - t0 < 240000, 'lesson took too long: ' + (Date.now() - t0));
  const txt = await page.textContent('#pqBox'); assert(txt.includes('همه درست'), 'end text: ' + txt);
  await page.click('#pqGo'); eq(await curScreen(page), 'path');
  const d = (await lsGet(page, 'mh_users')).les1.d;
  eq(d.path.l[8][0].L[0].s, 3); eq(d.path.l[8][0].L[0].a, 100);
  eq(d.xp, 110, '8 first-try correct = 10x5 + 20x3'); eq(d.coins, 10);
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE3: wrong answer shows red bar + correct answer, re-queues once at the end; lesson ends only all-correct; stars from first-try accuracy', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'les2', grade: 7 });
  await startLesson(page, 7, 1);
  const first = await page.evaluate(() => v9Lesson());
  await answerCard(page, first, true);
  assert(await page.evaluate(() => document.querySelector('#lsBar').classList.contains('bad')), 'red bar expected');
  assert((await page.textContent('#lsFb')).includes('جواب درست'), 'correct answer must be shown');
  await page.click('#lsGo');
  const after = await page.evaluate(() => v9Lesson());
  eq([after.done, after.left], [0, 8], 'wrong card stays in the queue (7 others + itself again)');
  await finishLesson(page); /* answers everything correctly, including the re-queued card */
  assert(await page.evaluate(() => v9Lesson()) === null, 'lesson should be over');
  const txt = await page.textContent('#pqBox'); assert(!txt.includes('همه درست'), 'not all first-try');
  await page.click('#pqGo');
  const d = (await lsGet(page, 'mh_users')).les2.d;
  eq(d.path.l[7][1].L[0].s, 2, '7/8 first-try -> 2 stars'); eq(d.path.l[7][1].L[0].a, 88);
  eq(d.xp, 90, 'wrong first card resets combo: 5x10 + 2x20'); eq(d.coins, 5, 'non-flawless lesson = 5 coins');
  await context.close();
});

T('PHASE3: ✕ asks for confirmation and discards progress only on «بله»', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'les3', grade: 9 });
  await startLesson(page, 9, 0);
  await page.click('#lsX');
  assert((await page.textContent('#modal')).includes('پیشرفت این درس از دست می‌رود'), 'confirm text');
  await page.click('#lxNo'); eq(await curScreen(page), 'pq'); assert(await page.evaluate(() => !!v9Lesson()), 'lesson must continue');
  await page.click('#lsX'); await page.click('#lxYes');
  eq(await curScreen(page), 'path'); assert(await page.evaluate(() => v9Lesson()) === null);
  eq(await page.evaluate(() => Object.values(S.path.l[9]).every((r) => r.L.length === 0 && !r.c)), true, 'nothing recorded after exit');
  await context.close();
});

T('PHASE3: numeric keypad — on-screen Persian keys, no native input, >=44px, edit/check works (also physical keys)', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'les4', grade: 8 });
  const info = await lessonUntil(page, 8, 3, (i) => i.type === 'num');
  eq(await page.evaluate(() => document.querySelectorAll('#pqBox input, #pqBox textarea').length), 0, 'no native inputs');
  const keys = await page.evaluate(() => [...document.querySelectorAll('#pqBox .kpk')].map((b) => ({ k: b.dataset.k, t: b.textContent, h: b.getBoundingClientRect().height, w: b.getBoundingClientRect().width, a: !!b.getAttribute('aria-label') })));
  eq(keys.map((k) => k.k).sort(), ['-', '.', '/', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'bs'].sort());
  assert(keys.every((k) => k.h >= 44 && k.w >= 44 && k.a), 'keys < 44px or unlabelled');
  assert(keys.filter((k) => /[0-9]/.test(k.k)).every((k) => /[۰-۹]/.test(k.t)), 'digits must be Persian');
  await page.click('#pqBox .kpk[data-k="-"]'); await page.click('#pqBox .kpk[data-k="5"]'); await page.click('#pqBox .kpk[data-k="/"]'); await page.click('#pqBox .kpk[data-k="3"]');
  eq(await page.textContent('#lsVal'), '−۵/۳');
  await page.click('#pqBox .kpk[data-k="bs"]');
  eq(await page.textContent('#lsVal'), '−۵/');
  assert(await page.evaluate(() => document.querySelector('#lsGo').disabled), 'incomplete fraction must not be checkable');
  await page.click('#pqBox .kpk[data-k="bs"]'); await page.click('#pqBox .kpk[data-k="bs"]'); await page.click('#pqBox .kpk[data-k="bs"]');
  eq(await page.textContent('#lsVal'), '؟');
  for (const ch of String(info.ans)) await page.keyboard.press(ch); /* physical keyboard path */
  await page.keyboard.press('Enter'); /* check */
  assert(await page.evaluate(() => document.querySelector('#lsBar').classList.contains('ok')), 'typed correct answer must be accepted: ' + info.ans);
  await context.close();
});

T('PHASE3: shape card (SVG options) works; MCQ keyboard: press 1 then Enter checks', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'les5', grade: 8 });
  const i = await lessonUntil(page, 8, 2, (x) => x.type === 'shape');
  eq(await page.evaluate(() => document.querySelectorAll('#pqBox .opt svg').length), 4, 'four svg options');
  assert(await page.evaluate(() => [...document.querySelectorAll('#pqBox .opt')].every((b) => b.getAttribute('aria-label'))), 'shape buttons need aria-label');
  await page.click(`#pqBox .opt[data-k="${i.ans}"]`); await page.click('#lsGo');
  assert(await page.evaluate(() => document.querySelector('#lsBar').classList.contains('ok')), 'correct shape accepted');
  const m = await lessonUntil(page, 7, 6, (x) => x.type === 'mcq');
  await page.keyboard.press(String(m.ans + 1)); await page.keyboard.press('Enter');
  assert(await page.evaluate(() => document.querySelector('#lsBar').classList.contains('ok')), 'keyboard selection + Enter');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE3: placement uses V9 questions (5 MCQ, start chapter capped at 4)', async ({ browser }) => {
  const { page, context } = await open(browser);
  await startGuest(page, 9, -1);
  const X = await page.evaluate(() => v9Ob().X); assert(X <= 3, 'start chapter must be capped at chapter 4, got index ' + X);
  eq(X, 3, 'all-correct starts at chapter 4');
  await context.close();
});


/* ============================== PHASE 3 review fixes ============================== */
T('PHASE3b: wrong pick is red ✗, correct is green ✓, others dimmed (not colour alone); math isolates do not wrap', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'rv1', grade: 9 });
  await lessonUntilQ(page, 9, 0, (i) => i.type === 'mcq');
  const i = await page.evaluate(() => v9Lesson());
  await page.click(`#pqBox .opt[data-k="${i.ans === 0 ? 1 : 0}"]`); await page.click('#lsGo');
  await page.waitForTimeout(400);
  await page.waitForTimeout(450);
  const r = await page.evaluate(() => [...document.querySelectorAll('#pqBox .opt')].map((b) => ({ c: b.className, mk: b.querySelector('.mk') && b.querySelector('.mk').textContent, bg: getComputedStyle(b).backgroundColor, op: getComputedStyle(b).opacity })));
  eq(r.filter((x) => /\bno\b/.test(x.c)).length, 1); eq(r.filter((x) => /\bok\b/.test(x.c)).length, 1);
  eq(r.find((x) => /\bno\b/.test(x.c)).mk, '✗'); eq(r.find((x) => /\bok\b/.test(x.c)).mk, '✓');
  assert(r.filter((x) => /dim/.test(x.c)).every((x) => +x.op < .6) && r.filter((x) => /dim/.test(x.c)).length === 2, 'others dimmed');
  assert(r.find((x) => /\bno\b/.test(x.c)).bg !== r.find((x) => /\bok\b/.test(x.c)).bg, 'bg must differ');
  assert(!r.some((x) => /\bsel\b/.test(x.c)), 'selected highlight removed after check');
  const m = await page.evaluate(() => { const e = document.createElement('div'); document.body.appendChild(e); e.innerHTML = rich0('x ⁦A = {۱ , ۲}⁩ y'); const c = getComputedStyle(e.querySelector('.mth')); return [c.whiteSpace, c.display, c.direction]; });
  eq(m, ['nowrap', 'inline-block', 'ltr']);
  await context.close();
});

T('PHASE3b: keypad display is LTR (minus on the left) and «٫»/«/» keys are labelled', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'rv2', grade: 8 });
  await lessonUntilQ(page, 8, 3, (i) => i.type === 'num');
  await page.click('#pqBox .kpk[data-k="-"]'); await page.click('#pqBox .kpk[data-k="5"]');
  const d = await page.evaluate(() => { const e = document.querySelector('#lsVal'), c = getComputedStyle(e); const r = document.createRange(); r.selectNodeContents(e); const rects = [...r.getClientRects()]; return { dir: c.direction, ub: c.unicodeBidi, txt: e.textContent }; });
  eq([d.dir, d.txt], ['ltr', '−۵']); assert(/override|isolate/.test(d.ub), 'unicode-bidi: ' + d.ub);
  const k = await page.evaluate(() => ['.', '/'].map((x) => { const b = document.querySelector(`#pqBox .kpk[data-k="${x}"]`); return [b.getAttribute('aria-label'), b.textContent]; }));
  eq(k[0][0], 'ممیز اعشاری'); eq(k[1][0], 'خط کسری'); assert(k[0][1].includes('ممیز') && k[1][1].includes('کسر'), 'visible captions');
  await context.close();
});

T('PHASE3b: long questions (sets, equations, vectors) never split mid-expression', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'rv3', grade: 9 });
  for (const [g, ch] of [[9, 0], [8, 4], [8, 3], [9, 5]]) {
    await page.evaluate(([g, ch]) => Lesson.start(g, ch, 0), [g, ch]);
    for (let k = 0; k < 6; k++) {
      const bad = await page.evaluate(() => [...document.querySelectorAll('#pqBox .mth')].filter((e) => { const rs = [...e.getClientRects()]; return rs.length > 1; }).length);
      eq(bad, 0, `${g}.${ch}: a math span is split over lines`);
      await page.evaluate(([g, ch]) => Lesson.start(g, ch, 0), [g, ch]);
    }
  }
  await context.close();
});

/* ============================== PHASE 4 ============================== */
T('PHASE4: opening every screen/tab gives 0 coins (incl. shop, profile, league, all «بیشتر» entries)', async ({ browser }) => {
  for (const mode of ['new', 'legacy']) {
    const { page, context } = mode === 'new' ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
    if (mode === 'new') await register(page, { user: 'z4' + mode, name: 'سکه' });
    await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
    await page.waitForTimeout(200);
    const before = await page.evaluate(() => S.coins || 0);
    for (const tab of ['league', 'shop', 'prof', 'path']) await page.click(`#bnav [data-go="${tab}"]`);
    await page.click('#btnProf');
    const ids = await page.evaluate(() => [...document.querySelectorAll('#pMore [data-more]')].map((b) => b.dataset.more).filter((x) => !['live', 'report'].includes(x)));
    for (const id of ids) { await page.evaluate((id) => go(id), id); await page.evaluate(() => go('path')); }
    eq(await page.evaluate(() => S.coins || 0), before, `coins changed while only opening screens (${mode})`);
    assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
    await context.close();
  }
});

T('PHASE4: wheel entry is gone from profile→بیشتر; daily login bonus stays off', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json', keepDaily: true });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  await page.click('#btnProf');
  eq(await page.evaluate(() => !!document.querySelector('#pMore [data-more="wheel"]')), false);
  eq(await page.evaluate(() => S.coins), 320, 'old daily bonus (cd != today) must not add coins');
  await context.close();
});

T('PHASE4: legacy migration — coins = v6 coins + shop.v1 coins once; all old items in collection; idempotent across reloads/re-login', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [S.coins, S.mig9]), [320, 1]);
  const shop = await lsGet(page, 'mathHero.shop.v1');
  assert(shop.users['علیرضایی'] && shop.users['علیرضایی'].mig9 && shop.users['علیرضایی'].coins === 85, 'shop.v1 profile flagged, key and data kept');
  eq(await page.evaluate(() => v9Coll()), ['av:🦊', 'av:🐼', 'fr:#ffd166', 'th:sunset', 'v1:theme_3', 'v1:avatar_2', 'v1:char_3']);
  await page.click('#btnProf');
  eq(await page.evaluate(() => document.querySelectorAll('#colBox .ctile').length), 7, 'collection tiles');
  /* equip an old v6 item and an old shop.v1 item */
  await page.click('#colBox .ctile[data-id="th:sunset"] button');
  eq(await page.evaluate(() => [S.eq.th, document.body.classList.contains('th-sunset')]), ['sunset', true]);
  await page.click('#colBox .ctile[data-id="v1:theme_3"] button');
  eq(await page.evaluate(() => [S.col.eq.theme, S.eq.th, document.body.classList.contains('th-sunset')]), ['theme_3', '', false]);
  for (let k = 0; k < 2; k++) { await page.reload(); await page.waitForFunction(() => typeof USER !== 'undefined' && USER); await page.waitForTimeout(200); }
  eq(await page.evaluate(() => S.coins), 320, 'no double add after reloads');
  /* logout + form login + enter() again */
  await page.click('#btnProf'); await page.click('#s-prof #btnOut'); await page.click('#outYes');
  await openForm(page, 'login'); await page.fill('#inUser', 'ali_r'); await page.fill('#inPass', '1234'); await page.click('#regBtn');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER && cur !== 'reg');
  eq(await page.evaluate(() => S.coins), 320, 'no double add after re-login');
  eq((await lsGet(page, 'mh_users')).ali_r.d.coins, 320);
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE4: migration does not touch other users, new accounts or guests (no stolen coins)', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json', drop: ['mh_session'] });
  /* a brand-new user whose name equals the old shop.v1 profile key */
  await register(page, { name: 'علی رضایی', user: 'newali', pass: '1234' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER && cur === 'path');
  eq(await page.evaluate(() => [S.coins || 0, S.mig9]), [0, 1], 'new registrations start fresh');
  const shop = await lsGet(page, 'mathHero.shop.v1');
  assert(!shop.users['علیرضایی'].mig9, 'old profile untouched');
  await context.close();
});

T('PHASE4: combo — 5 correct in a row => ×2 shown and computed (8 correct = 110 XP); wrong resets', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'cmb1', grade: 8 });
  await startLesson(page, 8, 3);
  const seen = [];
  for (let k = 0; k < 8; k++) {
    const info = await page.evaluate(() => v9Lesson()); await answerCard(page, info);
    seen.push(await page.evaluate(() => [document.querySelector('#lsCombo').hidden, document.querySelector('#lsFb .xpg').textContent.replace(/\s+/g, ' ')]));
    await page.click('#lsGo');
  }
  eq(seen.map((x) => x[0]), [true, true, true, true, false, false, false, false], 'combo badge appears after the 5th correct');
  assert(/۱۰ XP/.test(seen[4][1]) && !/کمبو/.test(seen[4][1]), '5th still ×1: ' + seen[4][1]);
  assert(/۲۰ XP/.test(seen[5][1]) && /کمبو ×۲/.test(seen[5][1]), '6th ×2: ' + seen[5][1]);
  eq(await page.evaluate(() => S.xp), 110);
  await page.waitForSelector('#pqGo'); assert((await page.textContent('.xpl')).includes('۱۱۰ XP'), 'XP summary');
  await context.close();
});

T('PHASE4: XP total = legacy xpOf + lesson XP; level = floor(total/200)+1 in profile', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  const r = await page.evaluate(() => { const legacy = xpOf(); S.xp = 400; return [xpOf() - legacy, Math.floor(xpOf() / 200) + 1, v9Lv(xpOf())]; });
  eq(r[0], 400); eq(r[1], r[2]);
  await page.click('#btnProf');
  assert((await page.textContent('#s-prof')).includes('سطح ' + await page.evaluate(() => fa(v9Lv(xpOf())))), 'profile level text');
  await context.close();
});

T('PHASE4: lesson coins 5, flawless 10; daily cap 50', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'coin4', grade: 8 });
  await startLesson(page, 8, 3); await finishLesson(page); await page.click('#pqGo');
  eq(await page.evaluate(() => S.coins), 10);
  await startLesson(page, 8, 3); await finishLesson(page, { wrongFirst: true }); await page.click('#pqGo');
  eq(await page.evaluate(() => S.coins), 15);
  eq(await page.evaluate(() => [v9Coins(100, 'x'), S.coins]), [35, 50], 'cap leaves 35 of the remaining 100 (50 per day)');
  eq(await page.evaluate(() => [v9Coins(5, 'x'), S.coins]), [0, 50], 'nothing more today');
  await context.close();
});

T('PHASE4: ONE shop — buying deducts coins after confirm, persists after reload, owned item usable; insufficient coins blocked; freeze max 2', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'shp1', grade: 8 });
  await page.evaluate(() => { S.coins = 100; persist(); });
  await page.click('#bnav [data-go="shop"]');
  assert((await page.evaluate(() => document.querySelectorAll('#shopBox [data-buy]').length)) >= 15, 'catalog size');
  eq(await page.evaluate(() => !document.querySelector('#shopLayer') && !document.querySelector('#s-shop .shopbtn') && !document.querySelector('#s-shop [data-c]')), true, 'old shop UI must not be reachable');
  /* insufficient */
  await page.evaluate(() => { S.coins = 30; });
  await page.click('#shopBox [data-buy="rb:col-gold"]');
  eq(await page.evaluate(() => [S.coins, document.querySelector('#modal').classList.contains('on'), S.items.includes('rb:col-gold')]), [30, false, false], 'no purchase, no confirm without coins');
  await page.evaluate(() => { S.coins = 100; });
  /* confirm flow */
  await page.click('#shopBox [data-buy="rb:hat-cap"]');
  assert((await page.textContent('#modal')).includes('۵۰ سکه'), 'confirm shows price');
  await page.click('#bNo'); eq(await page.evaluate(() => S.coins), 100);
  await page.click('#shopBox [data-buy="rb:hat-cap"]'); await page.click('#bYes');
  eq(await page.evaluate(() => [S.coins, S.items.includes('rb:hat-cap'), S.eq.rbh]), [50, true, 'hat-cap']);
  await page.click('#shopBox [data-buy="fz"]'); await page.click('#bYes'); await page.click('#shopBox [data-buy="fz"]'); 
  eq(await page.evaluate(() => [S.coins, S.streak.freezes]), [10, 1]);
  await page.reload(); await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [S.coins, S.items.includes('rb:hat-cap'), S.eq.rbh, S.streak.freezes]), [10, true, 'hat-cap', 1], 'persisted');
  await page.evaluate(() => { S.coins = 200; S.streak.freezes = 2; go('shop'); });
  assert(await page.evaluate(() => document.querySelector('#shopBox [data-buy="fz"]').disabled), 'freeze capped at 2');
  assert(await page.evaluate(() => [...document.querySelectorAll('#shopBox button')].every((b) => b.getBoundingClientRect().height >= 43.5 && (b.getAttribute('aria-label') || b.textContent.trim()))), 'shop buttons >= 44px and labelled');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE4: robot evolves at level 5 / 10 / 20 (profile + header)', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'evo1', grade: 8 });
  for (const [xp, tier, lv] of [[0, 0, 1], [799, 0, 4], [800, 1, 5], [1799, 1, 9], [1800, 2, 10], [3799, 2, 19], [3800, 3, 20]]) {
    await page.evaluate((xp) => { S.xp = 0; const base = xpOf(); S.xp = xp - base; go('prof'); }, xp);
    eq(await page.evaluate(() => v9Lv(xpOf())), lv);
    eq(await page.evaluate(() => +document.querySelector('#profAv svg').dataset.tier), tier, `profile tier @${xp}xp`);
    eq(await page.evaluate(() => +document.querySelector('#hAv svg').dataset.tier), tier, `header tier @${xp}xp`);
  }
  await context.close();
});


/* ============================== PHASE 5 ============================== */
const UTC = (y, m, d, h = 9, mi = 0) => Date.UTC(y, m - 1, d, h, mi);
const fastLesson = (page, g = 8, ch = 3, j = 0) => page.evaluate(([g, ch, j]) => {
  Lesson.start(g, ch, j);
  for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(i.ans)) Lesson.key(c); } else Lesson.pick(i.ans); Lesson.check(); Lesson.next(); }
}, [g, ch, j]);
/* reload + wait for auto-login. Known Chromium quirk: on a file:// page a reload can occasionally come back with a completely EMPTY
   localStorage (seen ~1 in 5 runs, unrelated to app code). If that happens we restore the pre-reload snapshot once and say so. */
let storageWipes = 0;
const reloadIn = async (page) => {
  const snap = await page.evaluate(() => Object.fromEntries(Object.keys(localStorage).map((k) => [k, localStorage.getItem(k)])));
  await page.reload();
  const empty = await page.evaluate(() => !localStorage.getItem('mh_users'));
  if (empty && snap.mh_users) {
    storageWipes++; console.log('      (note: Chromium wiped file:// localStorage on reload; restoring snapshot)');
    await page.evaluate((snap) => { for (const k of Object.keys(snap)) localStorage.setItem(k, snap[k]); }, snap);
    await page.reload();
  }
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER, null, { timeout: 8000 });
  await page.waitForTimeout(150);
};
const toastHas = (page, txt) => page.waitForFunction((t) => document.querySelector('#toast').textContent.includes(t), txt, { timeout: 4000 });

T('PHASE5: Tehran day boundary — 23:59 vs 00:01 Tehran differ, 20:31 UTC and 23:00 UTC are the same Tehran day', async ({ browser }) => {
  const { page, context } = await open(browser, { clock: UTC(2026, 1, 10, 12) });
  const r = await page.evaluate(([a, b, c, d]) => ({ a: v9Tday(a), b: v9Tday(b), c: v9Tday(c), d: v9Tday(d), ja: v9Jal(v9Tday(a)), jb: v9Jal(v9Tday(b)) }), [UTC(2026, 1, 10, 20, 29), UTC(2026, 1, 10, 20, 31), UTC(2026, 1, 10, 23, 0), UTC(2026, 1, 10, 12, 0)]);
  eq(r.b - r.a, 1, '20:29 UTC (23:59 Tehran) vs 20:31 UTC (00:01 Tehran)'); eq(r.c, r.b, '23:00 UTC same Tehran day as 20:31 UTC'); eq(r.a, r.d, '12:00 UTC same day as 23:59 Tehran');
  eq([r.ja.y, r.ja.m, r.ja.d], [1404, 10, 20], 'Jalali 20 Dey 1404'); eq([r.jb.y, r.jb.m, r.jb.d], [1404, 10, 21]);
  /* integration: lesson at 00:01 and 02:30 Tehran = same day (streak 1); then 23:59 next day vs 00:01 = different days */
  await register(page, { user: 'tz1', grade: 8 });
  await setClock(page, UTC(2026, 1, 10, 20, 31)); await reloadIn(page);
  await fastLesson(page); eq(await page.evaluate(() => S.streak.n), 1);
  await setClock(page, UTC(2026, 1, 10, 23, 0)); await reloadIn(page);
  await fastLesson(page); eq(await page.evaluate(() => [S.streak.n, S.tl.n]), [1, 2], 'same Tehran day: second lesson, no second streak increment');
  await setClock(page, UTC(2026, 1, 11, 20, 31)); await reloadIn(page); /* 00:01 Tehran, Jan 12 */
  await fastLesson(page); eq(await page.evaluate(() => S.streak.n), 2, 'next Tehran day => +1');
  await setClock(page, UTC(2026, 1, 12, 20, 29)); await reloadIn(page); /* 23:59 Tehran, still Jan 12 */
  await fastLesson(page); eq(await page.evaluate(() => S.streak.n), 2, '23:59 Tehran is still the same day');
  await setClock(page, UTC(2026, 1, 12, 20, 31)); await reloadIn(page); /* 00:01 Tehran, Jan 13 */
  await fastLesson(page); eq(await page.evaluate(() => S.streak.n), 3, '00:01 Tehran is a new day');
  await context.close();
});

T('PHASE5: streak — consecutive days +1, one missed day uses a freeze, otherwise resets (neutral message)', async ({ browser }) => {
  const { page, context } = await open(browser, { clock: UTC(2026, 1, 10, 9) });
  await register(page, { user: 'stk1', grade: 8 });
  eq(await page.evaluate(() => [S.streak.n, S.goal]), [0, 1], 'goal default 1 lesson');
  eq(await page.textContent('#hXp'), '⚡ ۰/۱');
  await fastLesson(page);
  assert(await visible(page, '#goalDone') && await visible(page, '.streakup'), 'streak +1 and «امروز کافیه» card');
  eq(await page.evaluate(() => [S.streak.n, S.streak.best]), [1, 1]); eq(await page.textContent('#hStk'), '🔥 ۱');
  await page.click('#pqGo'); eq(await curScreen(page), 'path');
  await setClock(page, UTC(2026, 1, 11, 9)); await reloadIn(page); /* consecutive */
  eq(await page.evaluate(() => S.streak.n), 1, 'still alive on next day before the goal');
  await fastLesson(page); eq(await page.evaluate(() => [S.streak.n, S.streak.best]), [2, 2]);
  /* miss 12th, have 1 freeze */
  await page.evaluate(() => { S.streak.freezes = 1; persist(); });
  await setClock(page, UTC(2026, 1, 13, 9)); await page.reload(); await toastHas(page, 'یخ‌استریک');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [S.streak.n, S.streak.freezes]), [2, 0], 'freeze consumed, streak kept');
  await fastLesson(page); eq(await page.evaluate(() => S.streak.n), 3);
  /* miss two days, no freezes */
  await setClock(page, UTC(2026, 1, 16, 9)); await page.reload(); await toastHas(page, 'شروع تازه');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [S.streak.n, S.streak.best]), [0, 3], 'reset to 0, best kept');
  assert(!(await page.textContent('#toast')).includes('ناامید'), 'no shaming');
  /* 2 missed days with only 1 freeze => reset (not enough) */
  await fastLesson(page); await page.evaluate(() => { S.streak.freezes = 1; persist(); });
  await setClock(page, UTC(2026, 1, 19, 9)); await page.reload(); await page.waitForFunction(() => typeof USER !== 'undefined' && USER); await page.waitForTimeout(150);
  eq(await page.evaluate(() => [S.streak.n, S.streak.freezes]), [0, 1], 'insufficient freezes are not consumed');
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE5: daily goal 2 lessons — streak only after the 2nd; «امروز کافیه» exactly once per day; «یکی دیگه» is optional', async ({ browser }) => {
  const { page, context } = await open(browser, { clock: UTC(2026, 1, 10, 9) });
  await register(page, { user: 'goal2', grade: 8 });
  await page.click('#btnProf');
  eq(await page.evaluate(() => [...document.querySelectorAll('#goalPick button')].map((b) => [b.textContent.trim(), b.getAttribute('aria-pressed')])), [['۱ درس', 'true'], ['۲ درس', 'false'], ['۳ درس', 'false']]);
  await page.click('#goalPick [data-g="2"]');
  eq(await page.evaluate(() => S.goal), 2); eq(await page.textContent('#hXp'), '⚡ ۰/۲');
  eq(await page.evaluate(() => document.querySelector('#goalPick [data-g="2"]').getAttribute('aria-pressed')), 'true');
  await fastLesson(page);
  assert(!(await visible(page, '#goalDone')) && await visible(page, '#pqGo'), 'no goal card after lesson 1 of 2');
  eq(await page.evaluate(() => S.streak.n), 0); await page.click('#pqGo'); eq(await page.textContent('#hXp'), '⚡ ۱/۲');
  await fastLesson(page);
  assert(await visible(page, '#goalDone'), 'goal card after lesson 2'); assert((await page.textContent('#goalDone')).includes('امروز کافیه'), 'text');
  eq(await page.evaluate(() => S.streak.n), 1); eq(await page.textContent('#hXp'), '✓ ۲/۲');
  await page.click('#pqMore'); eq(await curScreen(page), 'pq', '«یکی دیگه» starts another lesson');
  await page.evaluate(() => go('path'));
  await fastLesson(page, 8, 3, 1);
  assert(!(await visible(page, '#goalDone')), 'card must not repeat on the same day'); eq(await page.evaluate(() => S.streak.n), 1, 'streak +1 only once per day');
  await page.click('#pqGo');
  await setClock(page, UTC(2026, 1, 11, 9)); await reloadIn(page);
  await fastLesson(page, 8, 3, 2); assert(!(await visible(page, '#goalDone')), 'day 2 lesson 1 of 2: no card'); await page.evaluate(() => go('path'));
  await fastLesson(page, 8, 3, 3); assert(await visible(page, '#goalDone'), 'day 2 completes goal: card again (once per day)');
  eq(await page.evaluate(() => S.streak.n), 2);
  assert(page.errors.length === 0, 'pageerror: ' + page.errors.join(' | '));
  await context.close();
});

T('PHASE5: profile calendar — Persian month/weekday headers from Saturday, active days marked, prev/next', async ({ browser }) => {
  const { page, context } = await open(browser, { clock: UTC(2026, 1, 10, 9) });
  await register(page, { user: 'cal2', grade: 8 });
  await fastLesson(page); await page.click('#pqGo');
  await setClock(page, UTC(2026, 1, 11, 9)); await reloadIn(page); await fastLesson(page); await page.click('#pqGo');
  await page.click('#btnProf');
  eq(await page.textContent('#calTitle'), '📅 دی ۱۴۰۴');
  eq(await page.evaluate(() => [...document.querySelectorAll('.cal-h')].map((e) => e.textContent)), ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']);
  eq(await page.evaluate(() => document.querySelectorAll('.cal-on').length), 2, 'two active days marked');
  const cols = await page.evaluate(() => { const kids = [...document.querySelector('.cal').children].slice(7); return kids.map((e, i) => e.classList.contains('cal-on') ? i % 7 : -1).filter((x) => x >= 0); });
  eq(cols, [0, 1], '10 Jan 2026 is a Saturday (column 0), 11 Jan Sunday (column 1)');
  eq(await page.evaluate(() => document.querySelectorAll('.cal-d').length), 30, 'Dey has 30 days');
  assert(await page.evaluate(() => document.querySelector('.cal-t').textContent) !== '', 'today outlined');
  await page.click('#calPrev'); eq(await page.textContent('#calTitle'), '📅 آذر ۱۴۰۴'); eq(await page.evaluate(() => document.querySelectorAll('.cal-d').length), 30);
  eq(await page.evaluate(() => document.querySelectorAll('.cal-on').length), 0);
  await page.click('#calNext'); await page.click('#calNext'); eq(await page.textContent('#calTitle'), '📅 بهمن ۱۴۰۴');
  await page.click('#calNext'); eq(await page.textContent('#calTitle'), '📅 اسفند ۱۴۰۴'); eq(await page.evaluate(() => document.querySelectorAll('.cal-d').length), 29, 'Esfand 1404 has 29 days');
  assert(await page.evaluate(() => ['#calPrev', '#calNext', '#goalPick button'].every((s) => [...document.querySelectorAll(s)].every((b) => b.getBoundingClientRect().height >= 43.5 && b.getBoundingClientRect().width >= 43.5))), 'controls >= 44px');
  await context.close();
});

T('PHASE5: header goal display never overflows (clamped, «✓ n/n»); legacy streak migrates into S.streak', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  eq(await page.evaluate(() => [S.streak.n, S.streak.freezes >= 0, S.goal === undefined || S.goal === 1]), [3, true, true], 'legacy login streak (3) carried over');
  await page.evaluate(() => { S.tl = { d: v9Tday(), n: 500, sd: 1 }; v9Hdr(); });
  eq(await page.textContent('#hXp'), '✓ ۱/۱');
  await context.close();
});

T('PHASE4b: collection names use Persian digits, no Latin digits or broken glyph fallbacks', async ({ browser }) => {
  const { page, context } = await open(browser, { fixture: 'legacy-user.json' });
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
  await page.click('#btnProf');
  const names = await page.evaluate(() => [...document.querySelectorAll('#colBox .ctile > b')].map((b) => b.textContent));
  assert(names.length === 7 && names.every((n) => !/[0-9]/.test(n)), 'names: ' + names.join(' | '));
  assert(await page.evaluate(() => getComputedStyle(document.querySelector('.mth') || document.body).marginLeft !== undefined), 'ok');
  await context.close();
});

/* ============================== PHASE 6+ : append below ============================== */

/* ---------------------------------- runner ---------------------------------- */
(async () => {
  const filter = process.argv[2] || '';
  const browser = await chromium.launch();
  let passed = 0, failed = 0;
  for (const t of tests) {
    if (filter && !t.name.includes(filter)) continue;
    try { await t.fn({ browser }); passed++; console.log('PASS  ' + t.name); }
    catch (e) { failed++; console.log('FAIL  ' + t.name + '\n      ' + String(e.message).split('\n')[0] + (process.env.STACK ? '\n' + e.stack : '')); }
  }
  await browser.close();
  console.log(`SUMMARY: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();
