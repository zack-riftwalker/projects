// Frame cost of rooms and boss fights on the exported web build (public/mv) in headless Chromium (software GL: drawing costs CPU,
// so a heavy picture shows up here, unlike the headless Godot benches). Brief 05.
// Usage: node tools/godot/web-bench.js <scene> [scene...]   scene = gfxbench:<room>[:<frames>] | fightbench:<room>[:<frames>[:<hp>]]
//   THROTTLE=4 slows the page's CPU 4x (Chrome's CPU throttling: a rough mid-range phone), GFX=low|mid|high picks the tier,
//   Q="&debug" adds query options. Prints each scene's BENCH line.
'use strict';
const { spawn } = require('child_process');
const path = require('path');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const ROOT = path.resolve(__dirname, '../..'), PORT = +(process.env.BENCH_PORT || 3116);
const THROTTLE = +(process.env.THROTTLE || 1), GFX = process.env.GFX || '', Q = process.env.Q || '';
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const srv = spawn('node', ['server.js'], { cwd: ROOT, env: Object.assign({}, process.env, { PORT: String(PORT), NO_OPEN: '1' }), stdio: 'ignore' });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  let bad = 0;
  try {
    await wait(1500);
    for (const scene of process.argv.slice(2)) {
      const ctx = await browser.newContext({ viewport: { width: 768, height: 432 } });
      const page = await ctx.newPage();
      let line = '', start = null, cdp = null;
      cdp = await ctx.newCDPSession(page);
      await cdp.send('Performance.enable');
      // the page's main-thread work (JS, wasm, GL calls) per frame: Chrome's TaskDuration between BENCHSTART and the BENCH line. With
      // software GL the picture itself is drawn in the GPU process (not throttled, not counted), so this is the CPU side alone
      const task = async () => (await cdp.send('Performance.getMetrics')).metrics.find((x) => x.name === 'TaskDuration').value;
      page.on('console', async (m) => { const t = m.text(); if (t === 'BENCHSTART') start = task(); if (/^BENCH /.test(t)) { const s0 = await start; const s1 = await task(); const fr = +((t.match(/frames (\d+)/) || [])[1] || 1); line = t + ` | main thread ${((s1 - s0) * 1000 / fr).toFixed(2)} ms/frame`; } if (/SCRIPT ERROR|^ERROR/.test(t)) console.log('  ' + t); });
      page.on('pageerror', (e) => console.log('PAGEERROR ' + e.message));
      if (THROTTLE > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: THROTTLE });
      await page.goto(`http://127.0.0.1:${PORT}/mv/?scene=${scene}${GFX ? '&gfx=' + GFX : ''}${Q}`);
      const t0 = Date.now();
      while (!line && Date.now() - t0 < 240000) await wait(250);
      console.log(line ? `${line}${THROTTLE > 1 ? ' | cpu x' + THROTTLE : ''}` : `TIMEOUT ${scene}`);
      if (!line) bad++;
      await ctx.close();
    }
  } finally { await browser.close(); srv.kill(); }
  process.exit(bad ? 1 : 0);
})();
