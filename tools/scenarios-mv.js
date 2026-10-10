// Godot (Metroidvania test build) scenarios, loaded by coop-harness.js. Nothing here touches the co-op network.
'use strict';
module.exports = (S, h) => {
  const { startServer, get, chromium, R, ROOT, CODE, sleep } = h;
  const fs = require('fs'), path = require('path'), zlib = require('zlib');

  S['mv-serve'] = async () => {
    if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) return R(true, 'skipped: no Godot build in public/mv');
    const srv = await startServer();
    const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--use-angle=swiftshader'] });
    const fails = [], info = [];
    const chk = (name, ok) => { info.push(name + '=' + (ok ? 'ok' : 'BAD')); if (!ok) fails.push(name); };
    try {
      const idx = await get(srv.port, '/mv/');
      chk('mv/', idx && idx.status === 200 && /^text\/html/.test(idx.headers['content-type'] || ''));
      const rd = await get(srv.port, '/mv?debug');
      chk('/mv redirects', rd && rd.status === 301 && rd.headers.location === '/mv/?debug');
      const wz = await get(srv.port, '/mv/index.wasm', { 'accept-encoding': 'gzip' });
      chk('wasm-gzip', wz && wz.status === 200 && wz.headers['content-encoding'] === 'gzip' && wz.headers['content-type'] === 'application/wasm');
      const wp = await get(srv.port, '/mv/index.wasm', {});
      chk('wasm-plain', wp && wp.status === 200 && !wp.headers['content-encoding'] && wp.body.slice(0, 4).equals(Buffer.from([0, 0x61, 0x73, 0x6d])));
      for (const bad of ['/mv/../server.js', '/mv/sub/x.js', '/mv/.hidden']) { const r = await get(srv.port, bad); chk('404 ' + bad, r && r.status === 404); }
      const root = await get(srv.port, '/', { 'accept-encoding': 'gzip' });
      const want = fs.statSync(path.join(ROOT, 'public/index.html')).size;
      chk('root', root && root.status === 200 && zlib.gunzipSync(root.body).length === want);
      // the page itself starts without errors
      const errs = [];
      const ctx = await browser.newContext({ viewport: { width: 768, height: 432 } });
      const page = await ctx.newPage();
      page.on('pageerror', (e) => errs.push(e.message));
      let ready = false;
      page.on('console', (m) => { if (/CLAWD: (selftest PASS|ready)/.test(m.text())) ready = true; });
      await page.goto('http://127.0.0.1:' + srv.port + '/mv/?selftest');
      for (let i = 0; i < 400 && !ready; i++) await new Promise((r) => setTimeout(r, 100));
      chk('boots', ready && !errs.length);
      if (errs.length) info.push(errs[0]);
    } finally { await browser.close(); await srv.stop(); }
    return R(!fails.length, info.join(' '));
  };

  // two browser tabs: the host on 127.0.0.1, the guest on the container's LAN address (an insecure origin, like the friend's phone)
  S['mv-coop'] = async () => {
    if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) return R(true, 'skipped: no Godot build in public/mv');
    const os = require('os');
    let lan = '127.0.0.1';
    for (const l of Object.values(os.networkInterfaces())) for (const a of l || []) if (a.family === 'IPv4' && !a.internal) lan = a.address;
    const srv = await startServer();
    const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--no-proxy-server', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
    const res = { host: null, guest: null }, errs = [];
    try {
      const open = async (role, url) => {
        const ctx = await browser.newContext({ viewport: { width: 768, height: 432 } });
        const page = await ctx.newPage();
        page.on('pageerror', (e) => errs.push(role + ': ' + e.message));
        page.on('console', (m) => { const t = m.text(); if (process.env.MV_LOG) console.log(role, t); if (/CLAWD: coop (PASS|FAIL)/.test(t)) res[role] = t; });
        await page.goto(url);
      };
      await open('host', 'http://127.0.0.1:' + srv.port + '/mv/?host&autotest&mute');
      await sleep(3000);
      await open('guest', 'http://' + lan + ':' + srv.port + '/mv/?join=' + CODE + '&autotest&mute');
      for (let i = 0; i < 600 && !(res.host && res.guest); i++) await sleep(100);
    } finally { await browser.close(); await srv.stop(); }
    const ok = /PASS/.test(res.host || '') && /PASS/.test(res.guest || '') && !errs.length;
    return R(ok, 'host=' + res.host + ' guest=' + res.guest + (errs.length ? ' ' + errs[0] : '') + ' lan=' + lan);
  };

  // the title screen with the keyboard: New game starts the world; Join co-op takes the 6 digits and reaches the host
  S['mv-title'] = async () => {
    if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) return R(true, 'skipped: no Godot build in public/mv');
    const os = require('os');
    let lan = '127.0.0.1';
    for (const l of Object.values(os.networkInterfaces())) for (const a of l || []) if (a.family === 'IPv4' && !a.internal) lan = a.address;
    const srv = await startServer();
    const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--no-proxy-server', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
    const info = [], fails = [];
    const chk = (n, ok) => { info.push(n + '=' + (ok ? 'ok' : 'BAD')); if (!ok) fails.push(n); };
    try {
      const open = async (url) => {
        const ctx = await browser.newContext({ viewport: { width: 768, height: 432 } });
        const page = await ctx.newPage();
        const lines = [];
        page.on('console', (m) => lines.push(m.text()));
        await page.goto(url);
        for (let i = 0; i < 300 && !lines.some((l) => /CLAWD: ready/.test(l)); i++) await sleep(100);
        await sleep(1500);
        return { page, lines };
      };
      const solo = await open('http://127.0.0.1:' + srv.port + '/mv/?debug');
      const fsEl = () => solo.page.evaluate(() => !!document.fullscreenElement);
      const fsLines = () => solo.lines.filter((l) => /CLAWD: fullscreen on/.test(l)).length;
      await solo.page.keyboard.press('f');                    // F toggles fullscreen, as in the JS game
      for (let i = 0; i < 30 && !(fsLines() && (await fsEl())); i++) await sleep(100);
      chk('F fullscreen on', fsLines() === 1 && (await fsEl()));
      await solo.page.keyboard.press('f');
      for (let i = 0; i < 30 && (await fsEl()); i++) await sleep(100);
      chk('F fullscreen off', !(await fsEl()));
      await solo.page.keyboard.press('Enter');                // the first entry (New game on a fresh profile)
      await sleep(500);
      await solo.page.keyboard.down('ArrowRight');
      for (let i = 0; i < 40 && !solo.lines.some((l) => /CLAWD: x=/.test(l)); i++) await sleep(100);
      await solo.page.keyboard.up('ArrowRight');
      chk('new game moves', solo.lines.some((l) => /CLAWD: x=/.test(l)));
      const host = await open('http://127.0.0.1:' + srv.port + '/mv/?host&debug');
      await sleep(2000);
      const guest = await open('http://' + lan + ':' + srv.port + '/mv/?debug');
      await guest.page.keyboard.press('ArrowDown');           // Join co-op
      await guest.page.keyboard.press('Enter');
      await sleep(300);
      await guest.page.keyboard.type(CODE, { delay: 250 });
      await guest.page.keyboard.press('Enter');
      for (let i = 0; i < 500 && !guest.lines.some((l) => /COOP guest: start received/.test(l)); i++) await sleep(100);
      if (process.env.MV_LOG) { console.log(guest.lines.slice(-15).join('\n')); console.log('--host'); await guest.page.screenshot({ path: process.env.MV_LOG + '.png' }); console.log(host.lines.slice(-10).join('\n')); }
      chk('join by code', guest.lines.some((l) => /COOP guest: start received/.test(l)));
      chk('host saw guest', host.lines.some((l) => /COOP host: guest joined/.test(l)));
      // a join that failed (wrong code), then Back and New game: the world must still start
      const late = await open('http://' + lan + ':' + srv.port + '/mv/?debug');
      await late.page.keyboard.press('ArrowDown');
      await late.page.keyboard.press('Enter');
      await sleep(300);
      await late.page.keyboard.type('000000', { delay: 250 });
      await late.page.keyboard.press('Enter');
      await sleep(2500);
      await late.page.keyboard.press('Escape');
      await sleep(300);
      await late.page.keyboard.press('Enter');
      await sleep(500);
      await late.page.keyboard.down('ArrowRight');
      for (let i = 0; i < 40 && !late.lines.some((l) => /CLAWD: x=/.test(l)); i++) await sleep(100);
      await late.page.keyboard.up('ArrowRight');
      chk('new game after a failed join', late.lines.some((l) => /CLAWD: x=/.test(l)));
    } finally { await browser.close(); await srv.stop(); }
    return R(!fails.length, info.join(' '));
  };

  // the owner's phone (Huawei Y9s, Firefox): 741x280 css px at device scale 3, so the 384x216 picture is a centred strip with bars on both sides.
  // Taps must land on the drawn picture (not on the whole canvas), and the pad must stay on the menus: stick down + JUMP choose, DASH goes back.
  S['mv-phone'] = async () => {
    if (!fs.existsSync(path.join(ROOT, 'public/mv/index.html'))) return R(true, 'skipped: no Godot build in public/mv');
    const os = require('os');
    let lan = '127.0.0.1';
    for (const l of Object.values(os.networkInterfaces())) for (const a of l || []) if (a.family === 'IPv4' && !a.internal) lan = a.address;
    const srv = await startServer();
    const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--autoplay-policy=no-user-gesture-required', '--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--no-proxy-server', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
    const info = [], fails = [];
    const chk = (n, ok, extra) => { info.push(n + '=' + (ok ? 'ok' : 'BAD' + (extra ? '(' + extra + ')' : ''))); if (!ok) fails.push(n); };
    try {
      const ctx = await browser.newContext({ viewport: { width: 741, height: 280 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
      const page = await ctx.newPage();
      const lines = [];
      page.on('console', (m) => lines.push(m.text()));
      await page.goto('http://' + lan + ':' + srv.port + '/mv/?debug');       // an insecure origin, like the phone's
      for (let i = 0; i < 300 && !lines.some((l) => /CLAWD: ready/.test(l)); i++) await sleep(100);
      await sleep(1500);
      const last = (re) => { for (let i = lines.length - 1; i >= 0; i--) { const m = re.exec(lines[i]); if (m) return m; } return null; };
      const wait = async (fn, ms) => { for (let t = 0; t < (ms || 3000); t += 50) { if (fn()) return true; await sleep(50); } return fn(); };
      const pageIs = (n) => { const m = last(/CLAWD: page (\S+)/); return !!m && m[1] === n; };
      const codeIs = (c) => { const m = last(/CLAWD: code ?(\d*)/); return (m ? m[1] : '') === c; };
      const padVisible = () => { const m = last(/CLAWD: touch visible (true|false)/); return !!m && m[1] === 'true'; };
      // the picture inside the canvas: aspect fit, centred
      const box = await page.evaluate(() => { const r = document.querySelector('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
      const gw = Math.min(box.w / 384, box.h / 216), ox = box.x + (box.w - 384 * gw) / 2, oy = box.y + (box.h - 216 * gw) / 2;
      const tapG = async (gx, gy) => { await page.touchscreen.tap(ox + gx * gw, oy + gy * gw); };
      const canvasPx = await page.evaluate(() => document.querySelector('canvas').width);
      const dpr = canvasPx / box.w;                                          // canvas px per css px (the pad prints canvas px)
      const pad = (a) => { for (let i = lines.length - 1; i >= 0; i--) { const m = new RegExp('CLAWD: pad ' + a + ' (\\d+) (\\d+)').exec(lines[i]); if (m) return { x: m[1] / dpr, y: m[2] / dpr }; } return null; };
      const press = async (a) => { const c = pad(a); if (c) await page.touchscreen.tap(c.x, c.y); return !!c; };
      chk('geometry', Math.abs(box.w - 741) < 2 && Math.abs(dpr - 3) < 0.05 && ox > 100, JSON.stringify(box) + ' dpr=' + dpr);

      // 1. the pad is there on the title
      chk('pad on title', await wait(() => pageIs('main') && padVisible(), 5000), lines.filter((l) => /CLAWD/.test(l)).slice(-4).join(' | '));
      chk('pad buttons known', !!pad('jump') && !!pad('dash'));

      // 2. Join co-op (item 1 of New game / Join co-op / Settings), then the drawn BACK button at the far left of the picture
      await tapG(192, 120);
      chk('join opens', await wait(() => pageIs('join')));
      await tapG(38, 200);
      chk('back by tap', await wait(() => pageIs('main')));
      const tp = last(/CLAWD: tap \S+ \([^)]*\) -> \(([-\d.]+), ([-\d.]+)\)/);
      chk('tap maps to the picture', !!tp && Math.abs(tp[1] - 38) < 1.5 && Math.abs(tp[2] - 200) < 1.5, tp ? tp[1] + ',' + tp[2] : 'no tap line');

      // 3. every pad digit, at its centre and 14 game px right of its left edge; DEL takes it away again
      await tapG(192, 120);
      await wait(() => pageIs('join'));
      const PAD = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'DEL', '0', 'OK'];
      const rect = (i) => ({ x: 192 - 58 + (i % 3) * 40, y: 70 + Math.floor(i / 3) * 28, w: 36, h: 24 });
      const bad = [];
      for (const d of '1234567890') {
        const r = rect(PAD.indexOf(d)), del = rect(9);
        for (const [dx, tag] of [[r.w / 2, 'centre'], [14, 'left+14']]) {
          await tapG(r.x + dx, r.y + r.h / 2);
          if (!(await wait(() => codeIs(d), 1500))) bad.push(d + ' ' + tag);
          await tapG(del.x + del.w / 2, del.y + del.h / 2);
          if (!(await wait(() => codeIs(''), 1500))) { bad.push('DEL after ' + d + ' ' + tag); break; }
        }
      }
      chk('code pad digits', !bad.length, bad.join(', '));
      await tapG(38, 200);
      await wait(() => pageIs('main'));

      // 4. the pad itself: the stick down once moves to Join co-op, JUMP chooses it, DASH goes back
      const cdp = await ctx.newCDPSession(page);
      const tch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
      await tch('touchStart', 60, 120);                                      // in the bar left of the picture, the left half: the stick
      await sleep(100);
      await tch('touchMove', 60, 170);
      await sleep(500);
      await tch('touchEnd');
      await sleep(300);
      chk('stick keeps main', pageIs('main'));
      chk('JUMP button', await press('jump'));
      chk('stick + JUMP opens join', await wait(() => pageIs('join')));
      chk('DASH button', await press('dash'));
      chk('DASH goes back', await wait(() => pageIs('main')));

      // 5. Settings > Fullscreen by a tap (rows are 20 px apart from y 52; Back is the row after it), then Back
      const fsOn = () => lines.filter((l) => /CLAWD: fullscreen on/.test(l)).length;
      const fsOff = () => lines.filter((l) => /CLAWD: fullscreen off/.test(l)).length;
      await tapG(192, 140);
      chk('settings opens', await wait(() => pageIs('settings')));
      await tapG(192, 52 + 5 * 20 + 9);
      chk('settings Fullscreen on', await wait(() => fsOn() === 1) && await wait(() => page.evaluate(() => !!document.fullscreenElement)));
      await sleep(500);
      await tapG(192, 52 + 5 * 20 + 9);
      chk('settings Fullscreen off', await wait(() => fsOff() === 1));
      await tapG(192, 52 + 6 * 20 + 9);
      chk('settings Back', await wait(() => pageIs('main')));

      // 6. New game: the world starts and the pad stays; the pause menu has Fullscreen too (5th entry, 22 px apart from y 78)
      await tapG(192, 100);
      chk('new game starts', await wait(() => pageIs('game'), 6000));
      await sleep(500);
      chk('pad in game', padVisible());
      chk('pause button', await press('pause'));
      await sleep(800);
      await tapG(192, 78 + 4 * 22 + 9);
      chk('pause Fullscreen', await wait(() => fsOn() === 2));
      if (process.env.MV_LOG) console.log(lines.filter((l) => /CLAWD/.test(l)).join('\n'));
    } finally { await browser.close(); await srv.stop(); }
    return R(!fails.length, info.join(' '));
  };
};
