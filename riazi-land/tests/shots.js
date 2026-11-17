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
  ['path-new-user', { fresh: true }, async () => {}],
  ['path-legacy-user', {}, async () => {}],
  ['path-legacy-chapter-top', {}, (page) => page.evaluate(() => window.scrollTo(0, 0))],
  ['lesson-quiz', { fresh: true }, async (page) => { await page.click('#pathBox .pgo'); }],
  ['tab-league', {}, (page) => page.click('#bnav [data-go="league"]')],
  ['tab-shop', {}, (page) => page.click('#bnav [data-go="shop"]')],
  ['tab-profile', {}, (page) => page.click('#btnProf')],
  ['profile-more', {}, async (page) => { await page.click('#btnProf'); await page.evaluate(() => document.querySelector('#pMore').scrollIntoView()); }],
  ['logout-confirm', {}, async (page) => { await page.click('#btnProf'); await page.click('#s-prof #btnOut'); }],
  ['more-exam', {}, async (page) => { await page.click('#btnProf'); await page.click('#pMore [data-more="exam"]'); }],
  ['more-hub', {}, async (page) => { await page.click('#btnProf'); await page.click('#pMore [data-more="hub"]'); }],
  ['move-rhythm', {}, go('move')],
  /* PHASE 2+ : append new screens here */
];

(async () => {
  const browser = await chromium.launch();
  let n = 0;
  for (const [name, o, setup] of SCREENS) {
    const { page, context } = o.fresh ? await open(browser) : await open(browser, { fixture: 'legacy-user.json' });
    try {
      if (o.fresh && !o.noLogin) await register(page, { name: 'نگار احمدی', user: 'shot1', pass: '1234', grade: 8 });
      if (!o.fresh) await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
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
