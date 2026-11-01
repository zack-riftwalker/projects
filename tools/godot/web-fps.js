// The 30 fps check on the exported web build (brief 05, Zakaria's play-test 2026-11-01: "at 30 fps the whole game is slow and the music
// plays badly"). Opens ?scene=fpsprobe:<room>:<s> with and without ?fps30 in headless Chromium and compares:
//   - how fast the game runs in real time (physics steps, the room's clock, the music's position per real second: FPSPROBE line)
//   - the audio: with no threads Godot mixes the sound on the page's main thread, between frames. A main thread that is busy (the
//     engine's own frame cap busy-waits on the web) mixes too late: the music falls behind real time (its position per real second
//     drops below 1) and crackles. How late a message to the main thread is handled shows that busy time directly.
// Usage: node tools/godot/web-fps.js [room, T02] [seconds, 6]   Exit 1 when the 30 fps page differs from the 60 fps one.
'use strict';
const { spawn } = require('child_process');
const fs = require('fs'), path = require('path');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const ROOT = path.resolve(__dirname, '../..'), PORT = 3114;
const ROOM = process.argv[2] || 'T02', SECS = +(process.argv[3] || 6);
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function probe(browser, extra) {
  const ctx = await browser.newContext({ viewport: { width: 768, height: 432 } });
  const page = await ctx.newPage();
  await page.addInitScript(() => {
    window.__lat = [];
    // main-thread latency: a message every 4 ms, how late it runs
    const ch = new MessageChannel();
    let sent = 0;
    ch.port1.onmessage = () => { const now = performance.now(); if (window.__measure) window.__lat.push(now - sent); setTimeout(() => { sent = performance.now(); ch.port2.postMessage(0); }, 4); };
    sent = performance.now(); ch.port2.postMessage(0);
  });
  let line = '';
  page.on('console', (m) => { const t = m.text(); if (/^FPSPROBE/.test(t)) line = t; });
  page.on('pageerror', (e) => console.log('PAGEERROR ' + e.message));
  await page.goto(`http://127.0.0.1:${PORT}/mv/?scene=fpsprobe:${ROOM}:${SECS}${extra}`);
  // start measuring once the room runs (the probe waits 90 frames itself); the worklet's count is cumulative: take the difference
  await wait(4000);
  await page.evaluate(() => { window.__measure = true; });
  const t0 = Date.now();
  while (!line && Date.now() - t0 < (SECS + 60) * 1000) await wait(250);
  await wait(1100);
  const r = await page.evaluate(() => { window.__measure = false; const l = window.__lat.slice().sort((a, b) => a - b); return { p50: l[l.length >> 1] || 0, p99: l[Math.floor(l.length * 0.99)] || 0, max: l[l.length - 1] || 0 }; });
  await ctx.close();
  const num = (k) => { const m = line.match(new RegExp(k + ' (-?[\\d.]+)')); return m ? +m[1] : NaN; };
  return { line, physics: num('physics'), clock: num('clock'), music: num('music'), drawn: num('drawn'), lat: r };
}

(async () => {
  if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) { console.log('FAIL  no build in public/mv'); process.exit(1); }
  const srv = spawn('node', ['server.js'], { cwd: ROOT, env: Object.assign({}, process.env, { PORT: String(PORT), NO_OPEN: '1' }), stdio: 'ignore' });
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  let fail = 0;
  try {
    await wait(1500);
    const res = {};
    for (const [name, q] of [['60', ''], ['30', '&fps30']]) {
      res[name] = await probe(browser, q);
      const r = res[name];
      console.log(`${name} fps: ${r.line || '(no FPSPROBE line)'}`);
      console.log(`        main-thread message delay p50 ${r.lat.p50.toFixed(1)} p99 ${r.lat.p99.toFixed(1)} max ${r.lat.max.toFixed(1)} ms`);
    }
    const a = res['60'], b = res['30'];
    const check = (name, ok, info) => { if (!ok) fail++; console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + '  ' + info); };
    check('both pages ran', !!a.line && !!b.line, '');
    check('game speed: physics steps per second the same', Math.abs(a.physics - b.physics) < 2 && b.physics > 58, `${a.physics} vs ${b.physics}`);
    check('timers: the room clock runs at real time', Math.abs(b.clock - 1) < 0.03 && Math.abs(a.clock - 1) < 0.03, `${a.clock} vs ${b.clock}`);
    check('music: the 30 fps page keeps up with real time as well as the 60 fps one', a.music > 0 && b.music > 0.97 * a.music, `${a.music} vs ${b.music}`);
    check('30 fps draws about 30 frames a second', b.drawn > 24 && b.drawn < 36, `${b.drawn}`);
    check('the main thread is not blocked at 30 fps', b.lat.p99 < Math.max(25, a.lat.p99 * 1.5), `p99 ${a.lat.p99.toFixed(1)} vs ${b.lat.p99.toFixed(1)} ms`);
  } finally { await browser.close(); srv.kill(); }
  process.exit(fail ? 1 : 0);
})();
