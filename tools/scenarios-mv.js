// Godot (Metroidvania test build) scenarios, loaded by coop-harness.js. Nothing here touches the co-op network.
'use strict';
module.exports = (S, h) => {
  const { startServer, get, chromium, R, ROOT } = h;
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
};
