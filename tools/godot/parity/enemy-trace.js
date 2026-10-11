// Runs one creature in the JS game's NULL arena (level 1-B without its boss) and prints `frame,x,y,vx,vy,onGround` per frame (6 decimals).
// Usage: node enemy-trace.js <Class> <x> <y> <px> <py> <frames>   (x, y = the top-left of the creature's tile; px, py = the player, who stands still and cannot be hurt)
'use strict';
const path = require('path');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const [cls, x, y, px, py, frames] = [process.argv[2], ...process.argv.slice(3).map(Number)];
const ROOT = path.resolve(__dirname, '../../..');
(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const page = await browser.newPage();
  page.on('pageerror', (e) => { console.error('page error:', e.message); process.exitCode = 1; });
  await page.goto('file://' + path.join(ROOT, 'public/index.html') + '?mute&manual');
  await page.waitForFunction(() => window.G && G.scene);
  const rows = await page.evaluate(([cls, x, y, px, py, frames]) => {
    for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true;
    G.go(() => G.Scenes.play('1-B', null));
    for (let i = 0; i < 600 && !(G.scene.L && !G.transitioning()); i++) G.step(1, true);
    const L = G.scene.L, pl = L.player;
    // the boss intro runs first (tap through it); once the fight has started the boss and everything else is removed
    for (let i = 0; i < 3000 && !(L.boss && L.boss.active); i++) { G.input.script = i % 20 < 10 ? { jump: true } : {}; pl.inv = 99999; G.step(1, true); }
    L.ents.length = 0; L.boss = null; L.projs.length = 0;
    G.input.script = {};
    for (let i = 0; i < 60; i++) { pl.inv = 99999; G.step(1, true); }
    // (the creature is created after the player has settled, as the Godot side does; both then stand at the same frame)
    const e = cls === 'Bug' ? new G.Enemies.Bug(L, x, y, false) : new G.Enemies[cls](L, x, y);
    L.ents.push(e);
    pl.x = px; pl.y = py; pl.vx = pl.vy = 0;
    const out = [];
    for (let f = 0; f < frames; f++) {
      pl.inv = 99999;
      G.step(1, true);
      out.push([f, e.x, e.y, e.vx, e.vy, e.onGround ? 1 : 0].map((v, i) => (i === 0 || i === 5 ? v : v.toFixed(6))).join(','));
    }
    return out;
  }, [cls, x, y, px, py, frames]);
  console.log(rows.join('\n'));
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
