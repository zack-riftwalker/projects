/* Shared helpers for smoke.js and shots.js (Playwright + Chromium preinstalled; no install needed). */
const path = require('path');
const fs = require('fs');
let chromium;
try { ({ chromium } = require('playwright')); }
catch (e) {
  try { ({ chromium } = require('/opt/node-tools/node_modules/playwright')); }
  catch (e2) { console.error('Cannot resolve playwright. Set NODE_PATH to `npm root -g` or /opt/node-tools/node_modules'); process.exit(2); }
}
const ROOT = path.resolve(__dirname, '..');
const URL_APP = 'file://' + path.join(ROOT, 'index.html');
const VIEWPORT = { width: 390, height: 844 };
const FIXTURE = (name) => JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', name), 'utf8'));

/* Opens a fresh isolated page. opts.fixture = 'legacy-user.json' seeds localStorage BEFORE the app scripts run
   (only on the first load of the tab, so reloads keep whatever the app saved). opts.drop = [keys] to skip some keys. */
async function open(browser, opts = {}) {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: opts.dsf || 1, locale: 'fa-IR' });
  const page = await context.newPage();
  page.errors = [];
  page.on('pageerror', (e) => page.errors.push(e.message));
  if (opts.fixture) {
    const fx = FIXTURE(opts.fixture).localStorage;
    for (const k of opts.drop || []) delete fx[k];
    /* app grants a daily login bonus (earn(5+2*streak)) once per day when cd != today; pin cd/stk to "today" so coin assertions are deterministic */
    if (!opts.keepDaily) {
      const today = Math.floor((Date.now() + 12600000) / 864e5);
      for (const u of Object.values(fx.mh_users || {})) { if (u.d && u.d.cd !== undefined) u.d.cd = today; if (u.d && u.d.stk) u.d.stk.d = today; }
      if (fx.wh_ali_r !== undefined) fx.wh_ali_r = today - 1;
    }
    await context.addInitScript((data) => {
      try {
        if (sessionStorage.getItem('__seeded')) return;
        sessionStorage.setItem('__seeded', '1');
        for (const k of Object.keys(data)) localStorage.setItem(k, JSON.stringify(data[k]));
      } catch (e) {}
    }, fx);
  }
  await page.goto(URL_APP);
  await page.waitForFunction(() => window.__ok !== undefined || document.readyState === 'complete');
  return { context, page };
}

/* Registers a brand-new player through the real form and waits for the home screen. */
async function register(page, { name = 'تست', user = 'tester1', pass = '1234', grade = 8 } = {}) {
  await page.click(`.gc[data-g="${grade}"]`);
  await page.fill('#inName', name);
  await page.fill('#inUser', user);
  await page.fill('#inPass', pass);
  await page.click('#regBtn');
  await page.waitForFunction(() => typeof USER !== 'undefined' && USER && cur !== 'reg', null, { timeout: 8000 });
}

const lsGet = (page, k) => page.evaluate((k) => { const r = localStorage.getItem(k); return r === null ? null : JSON.parse(r); }, k);
const curScreen = (page) => page.evaluate(() => cur);

module.exports = { chromium, ROOT, URL_APP, VIEWPORT, FIXTURE, open, register, lsGet, curScreen };
