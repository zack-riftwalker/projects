#!/usr/bin/env node
/* Screenshots of key screens -> riazi-land/docs/shots/<phase>/NN-name.png  (viewport 390x844, deviceScaleFactor 1)
   Usage: node riazi-land/tests/shots.js phase-0
   Later phases: add entries to SCREENS (name + async fn(page)); everything runs against a seeded legacy user unless `fresh:true`. */
const fs = require('fs');
const path = require('path');
const { chromium, ROOT, open, register } = require('./lib');

const phase = process.argv[2];
if (!phase || !/^[\w.-]+$/.test(phase)) { console.error('usage: node shots.js <phase-name>   e.g. phase-0'); process.exit(2); }
const OUT = path.join(ROOT, 'docs', 'shots', phase);
fs.mkdirSync(OUT, { recursive: true });

const go = (id) => (page) => page.evaluate((id) => go(id), id);
/* name, options, setup */
const SCREENS = [
  ['register', { fresh: true, noLogin: true }, async () => {}],
  ['login-tab', { fresh: true, noLogin: true }, (page) => page.click('.tabs button[data-m="login"]')],
  ['home-new-user', { fresh: true }, async () => {}],
  ['legacy-auto-login-landing', { raw: true }, async () => {}], /* where a returning user lands after reload (phase-0 finding: old #s-menu, not #s-home) */
  ['home-legacy-user', {}, async () => {}],
  ['missions-menu', {}, (page) => page.click('#s-home [data-g="menu!"]')],
  ['learn', {}, go('learn')],
  ['lab', {}, go('lab')],
  ['game-intro', {}, go('game')],
  ['quiz', {}, go('quiz')],
  ['expo', {}, go('expo')],
  ['adventure', {}, go('adv')],
  ['hub', {}, go('hub')],
  ['shop', {}, go('shop')],
  ['move-rhythm', {}, go('move')],
  ['profile', {}, (page) => page.click('#btnProf')],
  ['logout-confirm', {}, async (page) => { await page.click('#btnProf'); await page.click('#s-prof #btnOut'); }],
  /* PHASE 1+ : append new screens here */
];

(async () => {
  const browser = await chromium.launch();
  let n = 0;
  for (const [name, o, setup] of SCREENS) {
    const { page, context } = o.fresh ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
    try {
      if (o.fresh && !o.noLogin) await register(page, { name: 'نگار احمدی', user: 'shot1', pass: '1234', grade: 8 });
      if (!o.fresh) { await page.waitForFunction(() => typeof USER !== 'undefined' && USER); if (!o.raw) await page.evaluate(() => go('home')); }
      await setup(page);
      await page.waitForTimeout(700); /* let the fade-in animation finish */
      const file = path.join(OUT, String(++n).padStart(2, '0') + '-' + name + '.png');
      await page.screenshot({ path: file, fullPage: false });
      console.log('shot ' + path.relative(ROOT, file) + (page.errors.length ? '  (pageerror: ' + page.errors[0] + ')' : ''));
    } catch (e) { console.log('SKIP ' + name + ': ' + e.message.split('\n')[0]); }
    await context.close();
  }
  await browser.close();
})();
