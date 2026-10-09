// Checks the exported web build (public/mv) through the PC relay: it boots on a secure origin (127.0.0.1) and on a plain-http
// LAN address (how the friend joins), plays sound on both, and the on-screen buttons and stick work with touch emulation.
// Usage: node tools/godot/web-check.js   (SHOTS=<dir> saves overlay screenshots). Exit 1 on any failure.
'use strict';
const { spawn, execSync } = require('child_process');
const fs = require('fs'), path = require('path'), http = require('http');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const ROOT = path.resolve(__dirname, '../..'), PORT = 3110, SHOTS = process.env.SHOTS;
const ARGS = ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'];
const lanIp = () => (execSync('hostname -I').toString().trim().split(/\s+/)[0] || '').trim();
process.env.NO_PROXY = (process.env.NO_PROXY || '') + ',' + lanIp() + ',127.0.0.1,localhost';
const results = [];
const check = (name, ok, info) => { results.push(ok); console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (info ? '  ' + info : '')); };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function boot(browser, url, opts) {
  const ctx = await browser.newContext(Object.assign({ viewport: { width: 768, height: 432 } }, opts || {}));
  const page = await ctx.newPage();
  const logs = [], errs = [];
  page.on('console', (m) => logs.push(m.text()));
  page.on('pageerror', (e) => errs.push(e.message));
  if (opts && opts.peak) await page.addInitScript(() => {
    window.__peak = 0;
    const d = Object.getOwnPropertyDescriptor(ScriptProcessorNode.prototype, 'onaudioprocess');
    const orig = AudioContext.prototype.createScriptProcessor;
    if (!d || !orig) return;
    AudioContext.prototype.createScriptProcessor = function (...a) {
      const node = orig.apply(this, a);
      Object.defineProperty(node, 'onaudioprocess', { configurable: true, get() { return d.get.call(node); }, set(f) { d.set.call(node, f ? function (e) { const r = f.call(this, e); for (let c = 0; c < e.outputBuffer.numberOfChannels; c++) { const x = e.outputBuffer.getChannelData(c); for (let i = 0; i < x.length; i++) if (Math.abs(x[i]) > window.__peak) window.__peak = Math.abs(x[i]); } return r; } : f); } });
      return node;
    };
  });
  await page.goto(url);
  return { page, ctx, logs, errs };
}
const until = async (fn, ms) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { if (fn()) return true; await wait(200); } return false; };

(async () => {
  if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) { console.log('FAIL  no build in public/mv (run tools/godot/export-web.sh)'); process.exit(1); }
  const srv = spawn('node', ['server.js'], { cwd: ROOT, env: Object.assign({}, process.env, { PORT: String(PORT), NO_OPEN: '1' }), stdio: 'ignore' });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ARGS });
  try {
    await wait(1500);
    // 1. secure origin
    let a = await boot(browser, `http://127.0.0.1:${PORT}/mv/?selftest`);
    check('boot on 127.0.0.1 (secure)', await until(() => a.logs.some((l) => /CLAWD: selftest PASS/.test(l)), 40000) && !a.errs.length, a.errs[0] || '');
    await a.ctx.close();
    // 2. plain http on the LAN address, with the audio checked
    const ip = lanIp();
    a = await boot(browser, `http://${ip}:${PORT}/mv/?selftest`, { peak: true });
    const ok = await until(() => a.logs.some((l) => /CLAWD: selftest PASS/.test(l)), 40000);
    await wait(1500);
    const insecure = await a.page.evaluate(() => !window.isSecureContext);
    const peak = await a.page.evaluate(() => window.__peak);
    check(`boot on http://${ip} (insecure=${insecure})`, ok && !a.errs.length, a.errs[0] || '');
    check('sound comes out on the insecure page (ScriptProcessor)', insecure ? peak > 0.01 : true, 'peak ' + (peak || 0).toFixed(3));
    await a.ctx.close();
    // 3. touch emulation: tap on the jump button, drag the stick right
    for (const [name, vp] of [['landscape', { width: 800, height: 360 }], ['portrait', { width: 360, height: 800 }]]) {
      a = await boot(browser, `http://127.0.0.1:${PORT}/mv/?debug&play`, { viewport: vp, deviceScaleFactor: 2, hasTouch: true, isMobile: true });
      await until(() => a.logs.some((l) => /CLAWD: ready/.test(l)), 40000);
      await wait(3000);
      const k = Math.max(0.8, Math.min(1.25, Math.min(vp.width, vp.height) / 380));
      await a.page.touchscreen.tap(vp.width - 22 * k - 41 * k, vp.height - 26 * k - 41 * k);
      await wait(600);
      check(`touch jump button (${name})`, a.logs.some((l) => /CLAWD: jump/.test(l)));
      const cdp = await a.ctx.newCDPSession(a.page);
      const sy = vp.height - 96, sx = 80;
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: sx, y: sy, id: 1 }] });
      for (let i = 1; i <= 6; i++) { await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: sx + i * 12, y: sy, id: 1 }] }); await wait(60); }
      await wait(1500);
      const moved = a.logs.filter((l) => /CLAWD: x=/.test(l)).length;
      if (SHOTS) await a.page.screenshot({ path: path.join(SHOTS, `overlay_${name}.png`) });
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      check(`touch stick moves Clawd (${name})`, moved > 0 && !a.errs.length, a.errs[0] || `${moved} position logs`);
      await a.ctx.close();
    }
  } finally {
    await browser.close();
    srv.kill();
  }
  process.exit(results.every(Boolean) ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(1); });
