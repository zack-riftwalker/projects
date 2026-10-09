// Captures art, tiles, font, background, sound effects, music and level maps from the current game (public/index.html)
// into godot/assets/ (and everything, including music, into tools/godot/capture/out/). Usage: node capture.js <what...>
// what: sprites tiles font bg sfx music levels all
'use strict';
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const ROOT = path.resolve(__dirname, '../../..'), OUT = path.join(__dirname, 'out'), ASSETS = path.join(ROOT, 'godot/assets');
const WHAT = process.argv.slice(2).length ? process.argv.slice(2) : ['all'];
const want = (k) => WHAT.includes('all') || WHAT.includes(k);
const SFX = 'jump djump walljump land swipe swipeBig hit clang squish kill hurt die token spark heal dash spring crumble brk checkpoint shoot bossHit explode bigExplode uiMove uiOk uiBack text textLow textSys key gate agent agentHit warn charge laser drip splash thud roar glitch tick tock pause flap logo stamp'.split(' ');
const LONG = new Set(['explode', 'bigExplode', 'roar', 'logo', 'die', 'gate', 'spark']);
const mk = (...p) => { const d = path.join(...p); fs.mkdirSync(d, { recursive: true }); return d; };
const save = (rel, b64) => { const f = path.join(OUT, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, Buffer.from(b64, 'base64')); return f; };
const put = (rel, srcAbs) => { const f = path.join(ASSETS, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.copyFileSync(srcAbs, f); };

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  page.on('pageerror', (e) => { console.error('page error:', e.message); process.exitCode = 1; });
  // keep the rendered AudioBuffer of every offline render
  await page.addInitScript(() => {
    const sr = OfflineAudioContext.prototype.startRendering;
    OfflineAudioContext.prototype.startRendering = function () { return sr.call(this).then((b) => { window.__lastBuf = b; return b; }); };
  });
  await page.goto('file://' + path.join(ROOT, 'public/index.html') + '?mute&manual');
  await page.waitForFunction(() => window.G && G.scene);
  const png = (expr, arg) => page.evaluate(expr, arg);

  // 16-bit WAV (base64) of window.__lastBuf. mono: average the channels; trim: cut the silent tail (keeps 50 ms)
  const wavOf = (opts) => page.evaluate((o) => {
    const b = window.__lastBuf, n = b.length, ch = [b.getChannelData(0), b.numberOfChannels > 1 ? b.getChannelData(1) : b.getChannelData(0)];
    let end = n;
    if (o.trim) { end = 0; for (let i = n - 1; i >= 0; i--) if (Math.abs(ch[0][i]) > 0.001 || Math.abs(ch[1][i]) > 0.001) { end = Math.min(n, i + Math.floor(0.05 * 44100)); break; } }
    const nc = o.mono ? 1 : 2, buf = new ArrayBuffer(44 + end * nc * 2), v = new DataView(buf);
    const s = (off, str) => { for (let i = 0; i < str.length; i++) v.setUint8(off + i, str.charCodeAt(i)); };
    s(0, 'RIFF'); v.setUint32(4, 36 + end * nc * 2, true); s(8, 'WAVE'); s(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, nc, true);
    v.setUint32(24, 44100, true); v.setUint32(28, 44100 * nc * 2, true); v.setUint16(32, nc * 2, true); v.setUint16(34, 16, true); s(36, 'data'); v.setUint32(40, end * nc * 2, true);
    let off = 44;
    for (let i = 0; i < end; i++) {
      const put = (x) => { x = Math.max(-1, Math.min(1, x)); v.setInt16(off, x < 0 ? x * 0x8000 : x * 0x7fff, true); off += 2; };
      if (o.mono) put((ch[0][i] + ch[1][i]) / 2); else { put(ch[0][i]); put(ch[1][i]); }
    }
    let bin = ''; const u = new Uint8Array(buf);
    for (let i = 0; i < u.length; i += 0x8000) bin += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
    return btoa(bin);
  }, opts);

  if (want('sprites')) {
    const sp = await png(() => {
      const out = {};
      const walk = (o, p) => { for (const k of Object.keys(o)) { const v = o[k], pp = p ? p + '_' + k : k; if (v instanceof HTMLCanvasElement) out[pp] = { w: v.width, h: v.height, d: v.toDataURL('image/png').split(',')[1] }; else if (v && typeof v === 'object') walk(v, pp); } };
      walk(G.SPR, '');
      const ps = G.platformSprite(1);        // the moving platform of world 1 is built on demand
      out.platform_48 = { w: ps.width, h: ps.height, d: ps.toDataURL('image/png').split(',')[1] };
      return out;
    });
    const idx = {};
    for (const [k, v] of Object.entries(sp)) { const f = save('sprites/' + k + '.png', v.d); put('sprites/' + k + '.png', f); idx[k + '.png'] = [v.w, v.h]; }
    fs.writeFileSync(path.join(OUT, 'sprites/index.json'), JSON.stringify(idx, null, 1)); put('sprites/index.json', path.join(OUT, 'sprites/index.json'));
    console.log('sprites', Object.keys(sp).length);
  }

  if (want('tiles')) {
    const d = await png(() => {
      const c = G.makeCanvas(256, 112), g = c.g;
      for (let v = 0; v < 4; v++) for (let m = 0; m < 16; m++) G.drawSolid(g, 1, m * 16, v * 16, 3 + v * 5, 7 + v * 3, { u: !!(m & 1), d: !!(m & 2), l: !!(m & 4), r: !!(m & 8) });
      for (let k = 0; k < 8; k++) G.drawOneway(g, 1, k * 16, 64, k >> 2, { l: !!(k & 1), r: !!(k & 2) });
      G.drawSpikes(g, 0, 80, false); G.drawSpikes(g, 16, 80, true); g.drawImage(G.SPR.cracked, 32, 80); g.drawImage(G.SPR.crumble, 48, 80);
      for (let i = 0; i < 16; i++) G.drawDecor(g, 1, i * 16, 96, i, 40);
      return c.toDataURL('image/png').split(',')[1];
    });
    put('tiles/w1_tiles.png', save('tiles/w1_tiles.png', d)); console.log('tiles');
  }

  if (want('font')) {
    for (const [name, tiny] of [['big', false], ['tiny', true]]) {
      const r = await png((tiny) => {
        const o = tiny ? { tiny: true } : {}, glyphs = {}, widths = [];
        let total = 0;
        for (let c = 32; c <= 126; c++) { const ch = String.fromCharCode(c), w = Math.max(1, G.textW(ch, o)); widths.push(w); total += w + 1; }
        const c = G.makeCanvas(total, 12), g = c.g;
        let x = 0;
        for (let i = 0; i < widths.length; i++) { const ch = String.fromCharCode(32 + i); G.text(g, ch, x, 0, '#ffffff', o); glyphs[ch] = [x, widths[i]]; x += widths[i] + 1; }
        const px = g.getImageData(0, 0, total, 12).data; let h = 0;
        for (let y = 0; y < 12; y++) for (let xx = 0; xx < total; xx++) if (px[(y * total + xx) * 4 + 3] > 0) h = y + 1;
        const c2 = G.makeCanvas(total, h); c2.g.drawImage(c, 0, 0);
        return { d: c2.toDataURL('image/png').split(',')[1], json: { h, sp: 1, glyphs } };
      }, tiny);
      put('fonts/' + name + '.png', save('fonts/' + name + '.png', r.d));
      fs.writeFileSync(path.join(OUT, 'fonts/' + name + '.json'), JSON.stringify(r.json)); put('fonts/' + name + '.json', path.join(OUT, 'fonts/' + name + '.json'));
    }
    console.log('font');
  }

  if (want('bg')) {
    const d = await png(() => { const c = G.makeCanvas(384, 216); G.drawBG(1, c.g, 0, 0, 0, 0); return c.toDataURL('image/png').split(',')[1]; });
    put('bg/w1.png', save('bg/w1.png', d)); console.log('bg');
  }

  if (want('sfx')) {
    for (const n of SFX) {
      await page.evaluate(([n, s]) => G.audio.renderOffline('sfx:' + n, s), [n, LONG.has(n) ? 2.5 : 1.2]);
      put('sfx/' + n + '.wav', save('sfx/' + n + '.wav', await wavOf({ mono: true, trim: true })));
    }
    console.log('sfx', SFX.length);
  }

  if (want('music')) {
    const names = await page.evaluate(() => Object.keys(G.SONGS)), index = {};
    for (const name of names) {
      for (const hi of [false, true]) {
        const info = await page.evaluate(async ([name, hi]) => {
          G.audio.intensity = 0; await G.audio.renderOffline(name, 1);
          const s = G.SONGS[name];
          if (hi && !JSON.stringify(s.sections).includes('"hi"')) return null;
          const step = 60 / s.bpm / 4, bars = (sec) => s._c[sec].bars;
          const total = s.order.reduce((a, sec) => a + bars(sec) * 16 * step, 0);
          const loopStart = s.order.slice(0, s.loop || 0).reduce((a, sec) => a + bars(sec) * 16 * step, 0);
          const len = total + (s.once ? 3 : 0);
          G.audio.intensity = hi ? 1 : 0;
          await G.audio.renderOffline(name, len);
          G.audio.intensity = 0;
          return { total, loopStart, len, once: !!s.once };
        }, [name, hi]);
        if (!info) continue;
        const key = name + (hi ? '_hi' : ''), wav = save('music/' + key + '.wav', await wavOf({ mono: false, trim: false }));
        execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', path.join(OUT, 'music/' + key + '.ogg')]);
        fs.unlinkSync(wav);
        index[key] = { len: +info.total.toFixed(3), loop_start: +info.loopStart.toFixed(3), once: info.once };
        if (key === 'w1') put('music/w1.ogg', path.join(OUT, 'music/w1.ogg'));
      }
    }
    fs.writeFileSync(path.join(OUT, 'music/index.json'), JSON.stringify(index, null, 1));
    // only w1 is copied this phase, so the index in godot/assets lists only w1
    const sub = { w1: index.w1 }; fs.writeFileSync(path.join(ASSETS, 'music/index.json'), JSON.stringify(sub, null, 1));
    console.log('music', Object.keys(index).length);
  }

  if (want('levels')) {
    const lv = await page.evaluate(() => Object.entries(G.LEVELS).map(([id, d]) => { const w = Math.max(...d.map.map((r) => r.length)); return { id, name: d.name, world: d.world, boss: d.boss || null, w, h: d.map.length, signs: d.signs || [], rows: d.map.map((r) => r.padEnd(w, ' ')) }; }));
    mk(OUT, 'levels');
    const idx = lv.map(({ rows, ...m }) => m);
    for (const l of lv) fs.writeFileSync(path.join(OUT, 'levels/' + l.id + '.txt'), l.rows.join('\n'));
    fs.writeFileSync(path.join(OUT, 'levels/index.json'), JSON.stringify(idx, null, 1));
    console.log('levels', lv.length);
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
