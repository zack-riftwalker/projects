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
      for (let i = 0; i < 200 && !guest.lines.some((l) => /COOP guest: start received/.test(l)); i++) await sleep(100);
      if (process.env.MV_LOG) { console.log(guest.lines.slice(-15).join('\n')); console.log('--host'); await guest.page.screenshot({ path: process.env.MV_LOG + '.png' }); console.log(host.lines.slice(-10).join('\n')); }
      chk('join by code', guest.lines.some((l) => /COOP guest: start received/.test(l)));
      chk('host saw guest', host.lines.some((l) => /COOP host: guest joined/.test(l)));
    } finally { await browser.close(); await srv.stop(); }
    return R(!fails.length, info.join(' '));
  };
};
