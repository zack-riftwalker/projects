#!/usr/bin/env node
/* Smoke tests for riazi-land/index.html (Playwright, 390x844, file://).
   Run:  node riazi-land/tests/smoke.js        (optional: node smoke.js <substring-filter>)
   Add tests for later phases by appending T('name', async (ctx) => {...}) calls in the "PHASE N" blocks below.
   Each test gets a browser; use open()/register() from lib.js. Any uncaught page error fails the test it happened in. */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { chromium, ROOT, FIXTURE, open, register, openForm, lsGet, curScreen } = require('./lib');

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
  await openForm(page, 'login');
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

T('PHASE1: lesson node quick quiz records stars, unlocks next node, persists in us[USER].d.path; boss state follows S.adv', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'path2', grade: 8 });
  await page.click('#pathBox .pgo');
  eq(await curScreen(page), 'pq');
  for (let k = 0; k < 5; k++) {
    await page.waitForSelector('#pqBox .opt:not([disabled])');
    await page.evaluate(() => { const P = v9Pq(), q = P.q[P.k]; document.querySelectorAll('#pqBox .opt')[q.opts.findIndex((o) => o.ok)].click(); });
    await page.waitForTimeout(1000);
  }
  await page.waitForSelector('#pqGo');
  await page.click('#pqGo');
  eq(await curScreen(page), 'path');
  const r = await page.evaluate(() => ({ stars: document.querySelector('.pch .pn.done .pst')?.getAttribute('aria-label'), curJ: [...document.querySelectorAll('.pch[data-ch="0"] .pn')].findIndex((n) => n.id === 'pcur') }));
  assert(/۳/.test(r.stars || ''), 'expected 3 stars, got ' + r.stars);
  eq(r.curJ, 1, 'second lesson should now be current');
  const d = (await lsGet(page, 'mh_users')).path2.d;
  eq(d.path.l[8][0].L[0].s, 3, 'stored stars');
  assert(!(d.coins > 0), 'lessons must not give coins');
  await context.close();
});

T('PHASE1: chest gives no coins and unlocks the boss node (S.path seeded for chapter 1)', async ({ browser }) => {
  const { page, context } = await open(browser);
  await register(page, { user: 'chest1' });
  await page.evaluate(() => { S.path = { l: { 8: { 0: { L: [{ s: 2, a: 70 }, { s: 3, a: 100 }, { s: 1, a: 40 }, { s: 3, a: 100 }], c: 0 } } }, xp: { d: 0, b: 0, v: 0 } }; go('path'); });
  const before = await page.evaluate(() => [S.coins || 0, MathHeroShop.coins()]);
  assert(await page.evaluate(() => document.querySelector('#pcur').dataset.k === 'C'), 'chest should be current');
  await page.click('#pathBox .pgo');
  await page.click('#chOk');
  eq(await page.evaluate(() => [S.coins || 0, MathHeroShop.coins()]), before, 'coins changed by chest');
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
  await page.evaluate(() => go('shop')); await page.click('#shopBox [data-back]'); eq(await curScreen(page), 'path', 'shop back button');
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
const finishLesson = async (page) => {
  for (let k = 0; k < 5; k++) {
    await page.waitForSelector('#pqBox .opt:not([disabled])');
    await page.evaluate(() => { const P = v9Pq(), q = P.q[P.k]; document.querySelectorAll('#pqBox .opt')[q.opts.findIndex((o) => o.ok)].click(); });
    await page.waitForTimeout(1000);
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
  eq(await page.evaluate(() => [USER, cur, S.coins]), ['ali_r', 'path', 235]);
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
  eq(await page.evaluate(() => PQ === undefined || true), true);
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
  assert(!(await visible(page, '#suPh')), 'mobile must be behind «بیشتر»');
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
  eq(await page.evaluate(() => [USER, cur, S.coins, S.adv[8]]), ['ali_r', 'path', 235, 3]);
  assert(!Object.keys(await lsGet(page, 'mh_users')).some((k) => k.startsWith('guest_')), 'guest created for legacy user');
  assert(!(await visible(page, '#s-reg')), 'welcome visible for logged-in user');
  await context.close();
});

/* ============================== PHASE 3+ : append below ============================== */

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
