// Plays a tape in the JS game and prints `frame,x,y,vx,vy,onGround` (6 decimals) to stdout. Usage: node js-trace.js <tape.json>
'use strict';
const fs = require('fs'), path = require('path');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const tape = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const ROOT = path.resolve(__dirname, '../../..');
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await browser.newPage();
  page.on('pageerror', (e) => { console.error('page error:', e.message); process.exitCode = 1; });
  await page.goto('file://' + path.join(ROOT, 'public/index.html') + '?mute&manual');
  await page.waitForFunction(() => window.G && G.scene);
  const rows = await page.evaluate((tape) => {
    for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true;
    Object.assign(G.save.data.tools, tape.tools);
    G.go(() => G.Scenes.play(tape.room, null));
    for (let i = 0; i < 600 && !(G.scene.L && !G.transitioning()); i++) G.step(1, true);
    const L = G.scene.L, pl = L.player;
    L.ents.length = 0;
    const set = (a) => { const o = {}; for (const k of a) o[k] = true; return o; };
    const frameKeys = (f) => { const keys = []; for (const [a, b, ks] of tape.input) if (f >= a && f <= b) keys.push(...ks); return keys; };
    if (tape.start) { pl.x = tape.start[0]; pl.y = tape.start[1]; pl.vx = pl.vy = 0; }
    else { G.input.script = {}; for (let i = 0; i < 60; i++) G.step(1, true); }
    const out = [];
    for (let f = 0; f < tape.frames; f++) {
      G.input.script = set(frameKeys(f));
      G.step(1, true);
      out.push([f, pl.x, pl.y, pl.vx, pl.vy, pl.onGround ? 1 : 0].map((v, i) => (i === 0 || i === 5 ? v : v.toFixed(6))).join(','));
    }
    G.input.script = null;
    return out;
  }, tape);
  console.log(rows.join('\n'));
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
