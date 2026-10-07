// CLAWD co-op test harness (dev only, not shipped to players).
//   node tools/coop-harness.js <scenario> [...]      run named scenarios
//   node tools/coop-harness.js all                   run every scenario
// env: SIM_LAG / SIM_JITTER / SIM_STALL_PCT / SIM_BW are passed through to the relay server.
'use strict';
const path = require('path'), http = require('http'), net = require('net'), { spawn } = require('child_process'), { createRequire } = require('module');
let pw;
for (const base of [process.cwd(), '/opt/node-tools', '/home/user/node-tools', __dirname]) { try { pw = createRequire(path.join(base, 'x.js'))('playwright'); break; } catch (e) { /* next */ } }
if (!pw) { console.error('playwright not found'); process.exit(2); }
const { chromium } = pw;
const ROOT = path.join(__dirname, '..');
const CODE = '123456';
let nextPort = 4100 + Math.floor(Math.random() * 400);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const SIMV = ['SIM_LAG', 'SIM_JITTER', 'SIM_STALL_PCT', 'SIM_STALL_MS', 'SIM_BW'];

// ---------------------------------------------------------------- server
async function startServer(extra) {
  const port = nextPort++;
  const env = Object.assign({}, process.env, { PORT: String(port), CODE, NO_OPEN: '1' }, extra || {});
  const proc = spawn('node', ['server.js'], { cwd: ROOT, env, stdio: ['ignore', 'pipe', 'pipe'] });
  let out = '';
  proc.stdout.on('data', (d) => { out += d; });
  proc.stderr.on('data', (d) => { out += d; });
  const srv = { port, proc, get out() { return out; }, dead: false };
  proc.on('exit', () => { srv.dead = true; });
  for (let i = 0; i < 60 && !/running/.test(out); i++) await sleep(100);
  if (!/running/.test(out)) throw new Error('server did not start: ' + out);
  srv.stop = async () => { if (!srv.dead) { proc.kill(); await sleep(100); } };
  return srv;
}
const get = (port, p, headers) => new Promise((res) => {
  const r = http.get({ host: '127.0.0.1', port, path: p, headers: headers || {} }, (rs) => { const b = []; rs.on('data', (c) => b.push(c)); rs.on('end', () => res({ status: rs.statusCode, headers: rs.headers, body: Buffer.concat(b) })); });
  r.on('error', () => res(null)); r.setTimeout(2000, () => { r.destroy(); res(null); });
});
const rawReq = (port, line) => new Promise((res) => { const s = net.connect(port, '127.0.0.1', () => s.write(line + '\r\nHost: x\r\nConnection: close\r\n\r\n')); let d = ''; s.on('data', (c) => { d += c; }); s.on('error', () => res(d)); s.on('close', () => res(d)); setTimeout(() => { s.destroy(); res(d); }, 1500); });

// ---------------------------------------------------------------- browser pair
const COUNT_JS = () => {
  // counts bytes and messages per message type, in both directions, for every WebSocket on the page
  const N = (window.__net = { tx: { n: 0, b: 0, t: {} }, rx: { n: 0, b: 0, t: {} }, log: false, rxLog: [] });
  const typeOf = (d) => { if (typeof d !== 'string') return 'bin'; const m = /^\{"t":"(\w+)"/.exec(d); return m ? m[1] : '?'; };
  const add = (o, d) => { const len = typeof d === 'string' ? d.length : (d.byteLength || 0), t = typeOf(d); o.n++; o.b += len; const e = o.t[t] || (o.t[t] = { n: 0, b: 0 }); e.n++; e.b += len; };
  const send = WebSocket.prototype.send;
  WebSocket.prototype.send = function (d) { add(N.tx, d); return send.call(this, d); };
  const WS = window.WebSocket;
  window.WebSocket = function (...a) { const ws = new WS(...a); ws.addEventListener('message', (ev) => { add(N.rx, ev.data); }); return ws; };
  window.WebSocket.prototype = WS.prototype;
  for (const k of ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED']) window.WebSocket[k] = WS[k];
};
async function openPage(browser, url, errs, tag) {
  const ctx = await browser.newContext({ viewport: { width: 768, height: 432 } });
  const page = await ctx.newPage();
  page.tag = tag;
  await page.addInitScript(COUNT_JS);
  page.on('pageerror', (e) => errs.push(tag + ': ' + e.message));
  page.on('console', (m) => { if (m.type() === 'error') errs.push(tag + ' console: ' + m.text()); });
  await page.goto(url);
  await page.waitForFunction(() => window.G && G.scene);
  return page;
}
async function openPair(opts) {
  opts = opts || {};
  const sim = {}; for (const k of SIMV) if (process.env[k]) sim[k] = process.env[k];
  const srv = await startServer(Object.assign(sim, opts.env));
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--autoplay-policy=no-user-gesture-required', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
  const errs = [];
  const q = opts.query || '?mute';
  const host = await openPage(browser, 'http://localhost:' + srv.port + '/' + q, errs, 'host');
  const guest = await openPage(browser, 'http://127.0.0.1:' + srv.port + '/' + q, errs, 'guest');
  const T = { srv, browser, host, guest, errs, sim };
  T.close = async () => { try { await browser.close(); } catch (e) { /* */ } await srv.stop(); };
  if (opts.connect !== false) {
    await host.evaluate((c) => G.coop.connect('host', c), CODE);
    await host.waitForFunction(() => G.coop.open);
    await guest.evaluate((c) => G.coop.connect('guest', c), CODE);
    await guest.waitForFunction(() => G.coop.open);
    await host.waitForFunction(() => G.coop.peer);
  }
  return T;
}
// start a level on the host and wait until both sides are in it
async function startLevel(T, id, o) {
  o = o || {};
  if (o.seen !== false) await T.host.evaluate(() => { for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true; });
  await T.host.evaluate((id) => { G.go(() => G.Scenes.play(id, null)); }, id);
  await T.host.waitForFunction((id) => G.scene.L && G.scene.L.id === id && !G.transitioning(), id, { timeout: 8000 });
  if (o.guest !== false) await T.guest.waitForFunction((id) => G.scene.L && G.scene.L.id === id && G.scene.L.net === 'guest' && !G.transitioning(), id, { timeout: 8000 });
}
const counters = (p) => p.evaluate(() => JSON.parse(JSON.stringify(window.__net)));
const diffNet = (a, b) => ({ tx: b.tx.b - a.tx.b, rx: b.rx.b - a.rx.b, txn: b.tx.n - a.tx.n, rxn: b.rx.n - a.rx.n, ttx: sub(b.tx.t, a.tx.t), trx: sub(b.rx.t, a.rx.t) });
const sub = (b, a) => { const o = {}; for (const k in b) o[k] = { n: b[k].n - (a[k] ? a[k].n : 0), b: b[k].b - (a[k] ? a[k].b : 0) }; return o; };
// guest input via real key events
const key = (p, code, down) => p.evaluate(([c, d]) => window.dispatchEvent(new KeyboardEvent(d ? 'keydown' : 'keyup', { code: c, bubbles: true, cancelable: true })), [code, down]);
const holdKey = async (p, code, ms) => { await key(p, code, true); await sleep(ms); await key(p, code, false); };
// keep both players alive (invulnerable) so long measurements are not cut short
const godmode = (T) => Promise.all([T.host, T.guest].map((p) => p.evaluate(() => { if (window.__god) clearInterval(window.__god); window.__god = setInterval(() => { const L = G.scene.L; if (!L) return; for (const q of [L.me, L.p2]) if (q && !q.dead) { q.inv = 99; q.hp = q.maxHp; } }, 50); })));
const noGod = (T) => Promise.all([T.host, T.guest].map((p) => p.evaluate(() => { clearInterval(window.__god); })));

const R = (pass, info, extra) => Object.assign({ pass: !!pass, info: info || '' }, extra || {});
const S = {};   // scenarios

// ---------------------------------------------------------------- server hardening
S['crash-url'] = async () => {
  const srv = await startServer();
  try {
    await rawReq(srv.port, 'GET /%E0%A4%A HTTP/1.1');
    await sleep(300);
    const r = await get(srv.port, '/');
    return R(r && r.status === 200 && !srv.dead, srv.dead ? 'server died' : 'server alive');
  } finally { await srv.stop(); }
};
S['crash-big'] = async () => {
  const srv = await startServer();
  const WebSocket = createRequire(path.join(ROOT, 'x.js'))('ws');
  try {
    const code = await new Promise((res) => {
      const ws = new WebSocket('ws://127.0.0.1:' + srv.port + '/ws?role=guest&code=' + CODE);
      ws.on('open', () => ws.send(Buffer.alloc(600 * 1024, 97).toString()));
      ws.on('close', (c) => res(c)); ws.on('error', () => {});
      setTimeout(() => res('timeout'), 3000);
    });
    await sleep(300);
    const r = await get(srv.port, '/');
    return R(r && r.status === 200 && !srv.dead && code === 1009, (srv.dead ? 'server died; ' : 'server alive; ') + 'close code ' + code);
  } finally { await srv.stop(); }
};
S['paths'] = async () => {
  const srv = await startServer();
  try {
    const a = await get(srv.port, '/assets/../server.js'), b = await rawReq(srv.port, 'GET /assets/../server.js HTTP/1.1'), c = await get(srv.port, '/package.json'), d = await get(srv.port, '/assets/voice/nar_title.mp3'), e = await get(srv.port, '/');
    const bad = /CLAWD co-op relay/.test(b);
    return R(!bad && c && c.status === 404 && d && d.status === 200 && e && e.status === 200, 'traversal leaked=' + bad + ' package.json=' + (c && c.status) + ' mp3=' + (d && d.status) + ' index=' + (e && e.status));
  } finally { await srv.stop(); }
};

// ---------------------------------------------------------------- gameplay bugs
S['double-hit'] = async () => {
  // two players on the same creature: the host player's swing and the partner's announced hit each count once, however often they repeat
  const T = await openPair();
  try {
    await startLevel(T, '1-1');
    await sleep(500);
    const r = await T.host.evaluate(() => {
      const L = G.scene.L, p1 = L.me, p2 = L.p2, co = G.coop;
      L.ents.length = 0; L.projs.length = 0;
      const e = new G.Enemies.Typo(L, p1.x + 12, p1.y - 4); e.hp = 100; e.y = p1.y; e.x = p1.x + 12; e.vx = e.vy = 0; e.update = () => {};
      L.ents.push(e); G.coop.hostTick(L, 0);                    // gives it an id
      co.rHas = false; co.inbox.length = 0;
      p2.x = p1.x; p2.y = p1.y; p2.dead = p2.gone = false; p1.dead = p1.gone = false; p2.vx = 0;
      p1.atkT = 0.17; p1.atkLive = true; p1.atkId = 11; p1.atkDir = 'f'; p1.atkFace = 1; p1.atkDmg = 1; p1.dashT = 0; p1.inv = 0; p1.grace = 99;
      const hp0 = e.hp;
      for (let i = 0; i < 7; i++) {
        L.interact(1 / 60);
        co.inbox.push({ t: 'hit', e: co.epoch, eid: e._id, how: 'swipe', dmg: 1, dx: 1, dy: 0, atk: 22, bi: 0 });
        co.hostTick(L, 0);
      }
      return { lost: hp0 - e.hp };
    });
    return R(r.lost === 2, 'hpLost=' + r.lost + ' (want 2)');
  } finally { await T.close(); }
};
S['solo-hit'] = async () => {   // one player alone still lands exactly one hit per swing
  const T = await openPair({ connect: false });
  try {
    await T.host.evaluate(() => G.go(() => G.Scenes.play('1-1', null)));
    await T.host.waitForFunction(() => G.scene.L && !G.transitioning());
    const r = await T.host.evaluate(() => {
      const L = G.scene.L, p1 = L.me; L.ents.length = 0;
      const e = new G.Enemies.Typo(L, p1.x + 12, p1.y); e.hp = 100; e.y = p1.y; e.x = p1.x + 12; e.update = () => {}; L.ents.push(e);
      p1.atkT = 0.17; p1.atkLive = true; p1.atkId = 5; p1.atkDir = 'f'; p1.atkFace = 1; p1.atkDmg = 1; p1.grace = 99;
      const hp0 = e.hp; for (let i = 0; i < 7; i++) L.interact(1 / 60); return hp0 - e.hp;
    });
    return R(r === 1, 'hits per swing=' + r + ' (want 1)');
  } finally { await T.close(); }
};
S['softlock'] = async () => {
  const T = await openPair();
  try {
    await startLevel(T, '1-1');
    await sleep(800);
    await T.host.evaluate(() => { window.__L0 = G.scene.L; G.scene.L.me.die(); });
    const q = await T.host.evaluate(() => G.scene.L.reviveQ.length);
    await T.guest.close();
    const t0 = Date.now(); let restarted = false;
    while (Date.now() - t0 < 6000) { if (await T.host.evaluate(() => G.scene.L !== window.__L0 && !!G.scene.L)) { restarted = true; break; } await sleep(100); }
    const st = await T.host.evaluate(() => ({ dead: G.scene.L.me.dead, rq: (G.scene.L.reviveQ || []).length }));
    return R(restarted, 'reviveQ before=' + q + ' restarted=' + restarted + ' after ' + (Date.now() - t0) + 'ms; now dead=' + st.dead + ' rq=' + st.rq);
  } finally { await T.close(); }
};
S['host-gone'] = async () => {
  const T = await openPair();
  try {
    await startLevel(T, '1-1');
    await sleep(800);
    await T.host.close();
    const t0 = Date.now(); let ok = false;
    while (Date.now() - t0 < 2500) { if (await T.guest.evaluate(() => !G.scene.L && !G.transitioning())) { ok = true; break; } await sleep(100); }
    const desc = await T.guest.evaluate(() => (G.scene.L ? 'still in level net=' + G.scene.L.net : 'no level'));
    return R(ok, desc + ' after ' + (Date.now() - t0) + 'ms');
  } finally { await T.close(); }
};
S['boss-intro'] = async () => {
  const T = await openPair();
  try {
    const out = [];
    let all = true;
    for (const b of ['1-B', '2-B', '3-B', '4-B', '5-B']) {
      await startLevel(T, '1-1'); await sleep(1500);
      await T.host.evaluate(() => { for (const k of Object.keys(G.LEVELS)) delete G.save.data.seen['b' + k]; });
      await T.host.evaluate((b) => G.go(() => G.Scenes.play(b, null)), b);
      await T.host.waitForFunction((b) => G.scene.L && G.scene.L.id === b && !G.transitioning(), b, { timeout: 8000 });
      await sleep(2500);
      const f = await T.guest.evaluate((b) => (G.scene.L && G.scene.L.id === b ? G.scene.L.me.frozen : 'wrong-level:' + (G.scene.L && G.scene.L.id)), b);
      out.push(b + '=' + f); if (f !== true) all = false;
    }
    return R(all, out.join(' ') + ' (guest frozen during intro; want true)');
  } finally { await T.close(); }
};
S['bt-spam'] = async () => {
  const T = await openPair();
  try {
    await startLevel(T, '1-1'); await sleep(1000);
    const a = await counters(T.guest), seq0 = await T.guest.evaluate(() => (G.coop.R ? G.coop.R.seq : 0));
    await T.guest.evaluate(() => { const L = G.scene.L, p = L.me; p.tools.bash = true; p.y -= 30; p.dashT = 0.15; p.dashDx = 1; p.dashDy = 0; });
    await sleep(500);
    const b = await counters(T.guest), seq1 = await T.guest.evaluate(() => (G.coop.R ? G.coop.R.seq : 0));
    const n = (b.tx.t.bt ? b.tx.t.bt.n : 0) - (a.tx.t.bt ? a.tx.t.bt.n : 0) + (seq1 - seq0);   // old "bt" messages + new reliable events
    return R(n === 0, 'tile-break messages/events=' + n + ' (want 0)');
  } finally { await T.close(); }
};
S['p2-freeze'] = async () => {
  const T = await openPair({ env: process.env.SIM_LAG ? {} : { SIM_LAG: '60' } });
  try {
    await startLevel(T, '1-1'); await sleep(800);
    await T.host.evaluate(() => { const L = G.scene.L; L.ents.length = 0; });   // nobody disturbs the test
    for (const p of [T.host, T.guest]) await p.evaluate(() => { window.__s = []; const f = () => { const L = G.scene.L; if (L) window.__s.push([Date.now(), (L.p2 || L.me).x, L.p2 ? 0 : L.me.vx, L.p2 ? performance.now() - G.coop.lastRx : 0]); window.__raf = requestAnimationFrame(f); }; f(); });
    // the guest keeps walking; the host fires a harmless shot at P2 every second
    const walk = (async () => { for (let i = 0; i < 8; i++) { await holdKey(T.guest, i % 2 ? 'ArrowLeft' : 'ArrowRight', 900); } })();
    const shots = (async () => { for (let i = 0; i < 6; i++) { await sleep(1200); await T.host.evaluate(() => { const L = G.scene.L, p = L.p2; L.shoot(p.x + 5, p.y + 5, 0, 0, { dmg: 0, life: 0.1, tile: false, cut: false, r: 4 }); }); } })();
    await Promise.all([walk, shots]);
    const hs = await T.host.evaluate(() => { cancelAnimationFrame(window.__raf); return window.__s; }), gs = await T.guest.evaluate(() => { cancelAnimationFrame(window.__raf); return window.__s; });
    // longest span where the host's copy of P2 stood still although the guest was moving 100-200 ms earlier
    const gAt = (t, k) => { let lo = 0, hi = gs.length - 1; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (gs[m][0] <= t) lo = m; else hi = m - 1; } return gs[lo][k || 1]; };
    const moving = (t) => Math.abs(gAt(t - 100) - gAt(t - 200)) > 1.5 && Math.abs(gAt(t - 100, 2)) > 60 && Math.abs(gAt(t - 200, 2)) > 60;   // clearly running, not turning round or leaning on a wall
    let worst = 0, runStart = null, wAt = null;
    for (let i = 1; i < hs.length; i++) {
      const still = hs[i][1] === hs[i - 1][1] && moving(hs[i][0]) && hs[i][3] < 130;       // a freeze while reports are arriving is ours; while the line itself is silent it is the line's
      if (still) { if (runStart === null) runStart = hs[i - 1][0]; if (hs[i][0] - runStart > worst) { worst = hs[i][0] - runStart; wAt = { x: hs[i][1].toFixed(1), gx: gAt(hs[i][0] - 100).toFixed(1), gvx: gAt(hs[i][0] - 100, 2).toFixed(0), gvx2: gAt(hs[i][0] - 200, 2).toFixed(0), t: hs[i][0] % 100000 }; } } else runStart = null;
    }
    let gap = 0, over = 0; for (let i = 1; i < hs.length; i++) { const d = hs[i][0] - hs[i - 1][0]; gap = Math.max(gap, d); if (d > 40) over++; }
    return R(worst <= 60, '[host rAF max gap ' + gap + ' ms, >40ms frames ' + over + '/' + hs.length + '] longest P2 freeze while guest moving: ' + worst + ' ms' + (worst > 60 ? ' at ' + JSON.stringify(wAt) : '') + ' (want <= 60) [lag=' + (T.sim.SIM_LAG || process.env.SIM_LAG || '60') + ']', { worst });
  } finally { await T.close(); }
};
S['bandwidth'] = async () => {
  const T = await openPair();
  try {
    const rows = [], levels = (process.env.BW_LEVELS || '1-1,1-B,2-B,3-B,4-B,5-B').split(',');
    let worst = 0, worstIdle = 0;
    for (const id of levels) {
      await startLevel(T, id);
      await godmode(T);
      await sleep(id.endsWith('B') ? 3500 : 1500);   // intro (seen) + boss start
      const secs = 6;
      await T.host.evaluate(() => { G.coop.dbg.stat = {}; }); await T.guest.evaluate(() => { G.coop.dbg.stat = {}; });
      const [h0, g0] = [await counters(T.host), await counters(T.guest)];
      let mv = null; if (process.env.BW_MOVE) mv = (async () => { for (let i = 0; i < secs / 0.9; i++) await holdKey(T.guest, i % 2 ? 'ArrowLeft' : 'ArrowRight', 800); })();
      await sleep(secs * 1000); if (mv) await mv;
      const [h1, g1] = [await counters(T.host), await counters(T.guest)];
      const dh = diffNet(h0, h1), dg = diffNet(g0, g1);
      const h2g = dh.tx / 1024 / secs, g2h = dg.tx / 1024 / secs;
      const hk = await T.host.evaluate(() => G.coop.dbg.stat), gk = await T.guest.evaluate(() => G.coop.dbg.stat);
      const top = (o) => Object.entries(o).sort((x, y) => y[1] - x[1]).slice(0, 5).map(([k, v]) => k + ':' + (v / 1024 / secs).toFixed(2)).join(' ');
      if (process.env.BW_DETAIL) console.log('    ' + id + ' host keys KB/s: ' + top(hk) + ' | guest keys: ' + top(gk));
      rows.push(id + ': host->guest ' + h2g.toFixed(1) + ' KB/s, guest->host ' + g2h.toFixed(1) + ' KB/s');
      worst = Math.max(worst, h2g, g2h); if (!id.endsWith('B')) worstIdle = Math.max(worstIdle, h2g, g2h);
      await noGod(T);
    }
    const ok = worst <= 4 && worstIdle <= 1.5;
    return R(ok, '\n    ' + rows.join('\n    ') + '\n    worst ' + worst.toFixed(1) + ' KB/s (want <= 4), idle ' + worstIdle.toFixed(1) + ' (want <= 1.5)', { worst, worstIdle });
  } finally { await T.close(); }
};
S['smoke'] = async () => {   // solo, no co-op: every level for 3 s with scripted input
  const srv = await startServer();
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const errs = [];
  try {
    const page = await openPage(browser, 'http://127.0.0.1:' + srv.port + '/?mute&manual', errs, 'solo');
    const ids = await page.evaluate(() => G.NODES.slice());
    for (const id of ids) {
      const r = await page.evaluate((id) => {
        for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true;
        G.setScene(G.Scenes.play(id, null));
        const acts = ['right', 'jump', 'attack', 'dash', 'left', 'down', 'up'];
        let n = 0;
        for (let i = 0; i < 180; i++) {
          G.input.script = {}; G.input.script.right = (i >> 5) % 2 === 0; G.input.script[acts[(i >> 3) % acts.length]] = true;
          const L = G.scene.L; if (L && L.me) { L.me.inv = 99; L.me.hp = L.me.maxHp; }
          G.step(1, true); n++;
        }
        G.input.script = null;
        return { id: G.scene.L && G.scene.L.id, n };
      }, id);
      if (r.id !== id) errs.push('level ' + id + ' not loaded');
    }
    return R(errs.length === 0, ids.length + ' levels x 180 steps' + (errs.length ? '; errors: ' + errs.slice(0, 5).join(' | ') : ''));
  } finally { await browser.close(); await srv.stop(); }
};

// scenarios for later phases are appended by tools/scenarios-*.js
for (const f of ['scenarios-p1.js', 'scenarios-p2.js', 'scenarios-p3.js']) { try { require('./' + f)(S, { startServer, get, rawReq, openPair, startLevel, counters, diffNet, key, holdKey, godmode, noGod, sleep, R, openPage, chromium, ROOT, CODE, createRequire }); } catch (e) { if (e.code !== 'MODULE_NOT_FOUND') throw e; } }

module.exports = { S, openPair, startLevel, sleep, counters, key, holdKey, godmode, startServer };
if (require.main === module) (async () => {
  const want = process.argv.slice(2);
  const names = want.length === 0 || want[0] === 'all' ? Object.keys(S) : want;
  let fails = 0;
  for (const n of names) {
    if (!S[n]) { console.log('UNKNOWN scenario ' + n); fails++; continue; }
    const t0 = Date.now(); let r;
    try { r = await S[n](); } catch (e) { r = R(false, 'exception: ' + (e && e.stack || e)); }
    console.log((r.pass ? 'PASS' : 'FAIL') + '  ' + n + '  (' + ((Date.now() - t0) / 1000).toFixed(1) + 's)  ' + r.info);
    if (!r.pass) fails++;
  }
  console.log(fails ? fails + ' scenario(s) FAILED' : 'all scenarios passed');
  process.exit(fails ? 1 : 0);
})();
