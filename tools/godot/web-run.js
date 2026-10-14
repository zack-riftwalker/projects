// Opens the exported web build (public/mv) in headless Chromium (software GL) through the PC relay and prints the console lines that match.
// Usage: node tools/godot/web-run.js "<query, e.g. ?gfxprobe&debug>" "<regex that ends the run>" [timeout ms] [line filter regex]
'use strict';
const { spawn } = require('child_process');
const fs = require('fs'), path = require('path');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const ROOT = path.resolve(__dirname, '../..'), PORT = 3112;
const [query, endRe, tmo, filt] = [process.argv[2] || '?selftest', new RegExp(process.argv[3] || 'selftest PASS'), +(process.argv[4] || 120000), new RegExp(process.argv[5] || '^(PROBE|BENCH|CLAWD)')];
(async () => {
  if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) { console.log('no build in public/mv'); process.exit(1); }
  const srv = spawn('node', ['server.js'], { cwd: ROOT, env: Object.assign({}, process.env, { PORT: String(PORT), NO_OPEN: '1' }), stdio: 'ignore' });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  let ok = false;
  try {
    await new Promise((r) => setTimeout(r, 1500));
    const page = await (await browser.newContext({ viewport: { width: 768, height: 432 } })).newPage();
    page.on('console', (m) => { const t = m.text(); if (filt.test(t)) console.log(t); if (endRe.test(t)) ok = true; });
    page.on('pageerror', (e) => console.log('PAGEERROR ' + e.message));
    await page.goto(`http://127.0.0.1:${PORT}/mv/${query}`);
    const t0 = Date.now();
    while (!ok && Date.now() - t0 < tmo) await new Promise((r) => setTimeout(r, 500));
  } finally { await browser.close(); srv.kill(); }
  console.log(ok ? 'DONE' : 'TIMEOUT');
  process.exit(ok ? 0 : 1);
})();
