// CLAWD co-op relay: serves the game (public/) and forwards messages between the host and one guest.
// Same protocol as the Cloudflare relay (cloud/worker.js), so one public/index.html works with both.
const http = require('http'), fs = require('fs'), path = require('path'), zlib = require('zlib');
const { WebSocketServer } = require('ws');
const PORT = process.env.PORT || 3000;
const ROOT = __dirname, WEB = path.join(ROOT, 'public');
const newCode = () => String(100000 + require('crypto').randomInt(900000));   // 6 digits
let CODE = process.env.CODE || newCode();
const MIME = { '.html': 'text/html; charset=utf-8', '.mp3': 'audio/mpeg', '.js': 'text/javascript', '.png': 'image/png', '.json': 'application/json', '.wasm': 'application/wasm', '.pck': 'application/octet-stream' };

// co-op difficulty defaults: env vars BOSS_HP, NPC_HITS, NPC_MULT (+ LOCK=1 to forbid changes) or an optional coop-config.json
let file = {}; try { file = JSON.parse(fs.readFileSync(path.join(ROOT, 'coop-config.json'), 'utf8')); } catch (e) { /* none */ }
const pick = (env, key) => { const v = process.env[env] !== undefined && process.env[env] !== '' ? process.env[env] : file[key]; return v === undefined || v === null || !Number.isFinite(+v) ? null : +v; };
const COOP = { bossPct: pick('BOSS_HP', 'bossPct'), npcExtra: pick('NPC_HITS', 'npcExtra'), npcMult: pick('NPC_MULT', 'npcMult'), lock: process.env.LOCK === '1' || file.lock === true };

// a request that came through the tunnel carries proxy headers; a local one does not
const isLocal = (req) => {
  const a = req.socket.remoteAddress || '';
  const loop = a === '127.0.0.1' || a === '::1' || a === '::ffff:127.0.0.1';
  return loop && !req.headers['cf-connecting-ip'] && !req.headers['x-forwarded-for'];
};

// ---------- static files: ETag, 304, long cache for voices, gzip for the page (kept in memory until the file changes) ----------
const cache = new Map();
function load(rel) {
  const f = path.join(WEB, rel);
  let st; try { st = fs.statSync(f); } catch (e) { return null; }
  const hit = cache.get(rel);
  if (hit && hit.mtime === st.mtimeMs && hit.size === st.size) return hit;
  const raw = fs.readFileSync(f);
  const ent = { mtime: st.mtimeMs, size: st.size, raw, etag: 'W/"' + st.size.toString(36) + '-' + Math.floor(st.mtimeMs).toString(36) + '"', gz: rel.endsWith('.html') ? zlib.gzipSync(raw, { level: 9 }) : null,
    br: rel.endsWith('.html') ? zlib.brotliCompressSync(raw, { params: { [zlib.constants.BROTLI_PARAM_QUALITY]: 11, [zlib.constants.BROTLI_PARAM_SIZE_HINT]: raw.length } }) : null };
  cache.set(rel, ent);
  return ent;
}
function serveFile(req, res, rel) {
  let ent = load(rel), pre = false;
  if (!ent && rel.startsWith('mv/')) { ent = load(rel + '.gz'); pre = !!ent; }     // stored gzipped by tools/godot/export-web.sh
  if (!ent) { res.writeHead(404); return res.end('not found'); }
  const isMp3 = rel.endsWith('.mp3');
  const h = { 'Content-Type': MIME[path.extname(rel)] || 'application/octet-stream', ETag: ent.etag, 'Cache-Control': isMp3 ? 'public, max-age=31536000, immutable' : 'no-cache' };
  if (req.headers['if-none-match'] === ent.etag) { res.writeHead(304, h); return res.end(); }
  let body = ent.raw;
  if (pre) {               // already gzip: send as is when the browser takes gzip (all do), unpack once otherwise
    h.Vary = 'Accept-Encoding';
    if (/\bgzip\b/.test(req.headers['accept-encoding'] || '')) h['Content-Encoding'] = 'gzip'; else body = ent.plain || (ent.plain = zlib.gunzipSync(ent.raw));
  } else
  if (ent.gz) {            // brotli (every current browser asks for it) is ~20 % smaller than gzip
    const ae = req.headers['accept-encoding'] || '';
    h.Vary = 'Accept-Encoding';
    if (/\bbr\b/.test(ae)) { body = ent.br; h['Content-Encoding'] = 'br'; } else if (/\bgzip\b/.test(ae)) { body = ent.gz; h['Content-Encoding'] = 'gzip'; }
  }
  h['Content-Length'] = body.length;
  res.writeHead(200, h);
  res.end(req.method === 'HEAD' ? undefined : body);
}

// only these paths are ever served: no directory traversal is possible
const VOICE = /^\/assets\/voice\/[a-z0-9_]+\.mp3$/;
const MV = /^\/mv\/[a-z0-9_-]+(\.[a-z0-9]+)+$/;     // the Godot build (Metroidvania test): one flat folder, no sub-paths, no dot-files
const server = http.createServer((req, res) => {
  let u;
  try { u = decodeURIComponent(req.url.split('?')[0]); } catch (e) { res.writeHead(400); return res.end('bad request'); }
  if (u === '/config') {
    if (!isLocal(req)) { res.writeHead(403); return res.end('no'); }
    res.writeHead(200, { 'Content-Type': 'application/json' }); return res.end(JSON.stringify(COOP));
  }
  if (u === '/') u = '/index.html';
  if (u === '/mv') { res.writeHead(301, { Location: '/mv/' + (req.url.includes('?') ? '?' + req.url.split('?')[1] : '') }); return res.end(); }     // the build's files are relative to /mv/
  if (u === '/mv/') u = '/mv/index.html';
  if (u !== '/index.html' && !VOICE.test(u) && !MV.test(u)) { res.writeHead(404); return res.end('not found'); }
  serveFile(req, res, u.slice(1));
});
server.on('clientError', (e, sock) => { try { sock.destroy(); } catch (x) { /* gone */ } });

// ---------- network simulator (off unless a SIM_* env var is set) ----------
// SIM_LAG ms one-way delay, SIM_JITTER +-ms, SIM_STALL_PCT % chance a direction freezes for SIM_STALL_MS (TCP head-of-line blocking),
// SIM_BW bytes/s cap per direction (queue = bufferbloat). Per-direction order is always preserved.
const num = (v, d) => (Number.isFinite(+v) && v !== undefined && v !== '' ? +v : d);
const SIM = { lag: num(process.env.SIM_LAG, 0), jit: num(process.env.SIM_JITTER, 0), stallPct: num(process.env.SIM_STALL_PCT, 0), stallMs: num(process.env.SIM_STALL_MS, 400), bw: num(process.env.SIM_BW, 0) };
const SIM_ON = !!(SIM.lag || SIM.jit || SIM.stallPct || SIM.bw);
const lane = () => ({ q: [], qBytes: 0, timer: null, lastDue: 0, blockedUntil: 0, bwFree: 0 });
const lanes = { toGuest: lane(), toHost: lane() };
function pump(l) {
  if (l.timer) return;
  const step = () => {
    l.timer = null;
    const now = Date.now();
    while (l.q.length && l.q[0].due <= now) { const m = l.q.shift(); l.qBytes -= m.text.length; const to = m.to(); if (to && to.readyState === 1) to.send(m.text); }
    if (l.q.length) l.timer = setTimeout(step, Math.max(1, l.q[0].due - Date.now()));
  };
  l.timer = setTimeout(step, 0);
}
// Messages the game marks as droppable (top-level "u":1: snapshots, body reports) are thrown away while the receiver is clogged,
// so a slow line never builds an ever-growing queue. Everything else (start, leave, events, pings...) always goes through.
const CLOG = 16384;
let dropped = 0;
function relayTo(l, to, text) {
  const t0 = to();
  if (text.endsWith(',"u":1}') && t0 && t0.bufferedAmount + l.qBytes > CLOG) { dropped++; return; }
  if (!SIM_ON) { const t = to(); if (t && t.readyState === 1) t.send(text); return; }
  const now = Date.now();
  let due = now + SIM.lag + (SIM.jit ? (Math.random() * 2 - 1) * SIM.jit : 0);
  if (SIM.stallPct && Math.random() * 100 < SIM.stallPct) l.blockedUntil = Math.max(l.blockedUntil, now + SIM.stallMs);
  due = Math.max(due, l.lastDue, l.blockedUntil);
  if (SIM.bw) { l.bwFree = Math.max(due, l.bwFree) + (text.length / SIM.bw) * 1000; due = l.bwFree; }
  l.lastDue = due;
  l.qBytes += text.length;
  l.q.push({ due, text, to });
  pump(l);
}

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 512 * 1024, perMessageDeflate: { threshold: 200 } });
wss.on('error', (e) => console.log('wss error: ' + e.message));
// wrong codes: 5 failures within a minute from one address lock that address out for a minute
const fails = new Map();
const clientIp = (req) => String(req.headers['cf-connecting-ip'] || (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || req.socket.remoteAddress || '?');
const blocked = (ip) => { const f = fails.get(ip); return !!f && f.until > Date.now(); };
function fail(ip) {
  const now = Date.now(), f = fails.get(ip) || { n: 0, first: now, until: 0 };
  if (now - f.first > 60000) { f.n = 0; f.first = now; }
  if (++f.n >= 5) { f.until = now + 60000; f.n = 0; f.first = now; }
  fails.set(ip, f);
}
setInterval(() => { const now = Date.now(); for (const [k, f] of fails) if (f.until < now && now - f.first > 60000) fails.delete(k); }, 60000).unref();
// heartbeat: a line that dies without a clean close (phone switches network, tunnel hiccup) leaves TCP "open" for minutes.
// Every 2 s each socket gets a tiny {"t":"hb"} (so the page can tell a dead line from a quiet one) and a ping; three missed pongs = dead.
setInterval(() => {
  for (const ws of wss.clients) {
    if ((ws.missed = (ws.missed || 0) + 1) > 3) { ws.terminate(); continue; }
    try { ws.ping(); if (ws.readyState === 1) ws.send('{"t":"hb"}'); } catch (e) { /* closing */ }
  }
}, 2000).unref();
let host = null, guest = null, guestTok = null, graceOn = false, graceTimer = null, hostGrace = false, hostGraceTimer = null;
const GRACE = Number(process.env.GRACE_MS) || 15000;
const send = (ws, o) => { if (ws && ws.readyState === 1) ws.send(JSON.stringify(o)); };
const drop = (ws, code, why) => { ws.replaced = true; try { ws.close(code, why); } catch (e) { /* gone */ } };
function holdGuestSeat() {
  graceOn = true; clearTimeout(graceTimer);
  graceTimer = setTimeout(() => { graceOn = false; guestTok = null; send(host, { t: 'peer', on: false }); }, GRACE);
}
function clearGuestSeat() { clearTimeout(graceTimer); graceOn = false; guestTok = null; }
function startHostGrace() {
  hostGrace = true; clearTimeout(hostGraceTimer);
  send(guest, { t: 'host', lag: true });
  hostGraceTimer = setTimeout(() => { hostGrace = false; send(guest, { t: 'host', on: false }); }, GRACE);
}

wss.on('connection', (ws, req) => {
  ws.on('error', (e) => console.log('socket error: ' + e.message));
  ws.on('pong', () => { ws.missed = 0; });
  const q = new URL(req.url, 'http://x').searchParams, role = q.get('role');
  if (role === 'host') {
    // only the PC running this server may host (no key needed there); the friend joins from anywhere with the code
    if (!isLocal(req)) return ws.close(4004, 'host must be local');
    const resume = q.get('resume') === '1';
    if (host && host.readyState === 1) {
      if (!resume) return ws.close(4002, 'host exists');
      drop(host, 4000, 'replaced');          // the same host is back on a new line: its old one is dead or about to be
    }
    const away = hostGrace || !!host, held = away && resume;
    if (hostGrace) { clearTimeout(hostGraceTimer); hostGrace = false; }
    host = ws;
    send(host, { t: 'code', v: CODE });
    // "held": the host is back inside its grace time, so the guest keeps its level. Otherwise the normal "friend joins" path runs.
    if (away && !resume) send(guest, { t: 'host', on: false });
    send(guest, held ? { t: 'host', on: true, resume: true } : { t: 'host', on: true });
    const peer = guest ? { t: 'peer', on: true } : graceOn ? { t: 'peer', lag: true } : { t: 'peer', on: false };
    if (held && guest) peer.resume = true;
    send(host, peer);
  } else if (role === 'guest') {
    const ip = clientIp(req);
    // a guest whose line dropped may come back with its token within the grace time, even without the right code
    const resume = !!guestTok && (graceOn || !!guest) && q.get('token') === guestTok;      // (or while the relay still holds its old, silently dead socket)
    if (!resume) {
      if (blocked(ip)) return ws.close(4005, 'too many wrong codes');
      if (q.get('code') !== CODE) { fail(ip); return ws.close(4001, 'wrong code'); }
    }
    if (guest && guest.readyState === 1) drop(guest, 4000, 'replaced');
    if (graceOn) { clearTimeout(graceTimer); graceOn = false; }
    guest = ws;
    if (!resume) guestTok = require('crypto').randomBytes(8).toString('hex');
    send(guest, { t: 'tok', v: guestTok });
    send(guest, host ? { t: 'host', on: true } : hostGrace ? { t: 'host', lag: true } : { t: 'host', on: false });
    send(host, resume ? { t: 'peer', on: true, resume: true } : { t: 'peer', on: true });
  } else return ws.close();
  console.log(role + ' connected');
  ws.on('message', (data) => {
    const text = data.toString();
    if (ws === host) {
      if (text.startsWith('{"t":"newcode"')) {          // "new code" button: a fresh code, the current friend is sent away
        CODE = newCode(); console.log(' New friend code: ' + CODE);
        send(host, { t: 'code', v: CODE });
        if (guest) { const g = guest; guest = null; drop(g, 4001, 'new code'); }
        clearGuestSeat(); send(host, { t: 'peer', on: false });
        return;
      }
      relayTo(lanes.toGuest, () => guest, text);
    } else if (ws === guest) relayTo(lanes.toHost, () => host, text);
  });
  ws.on('close', (code) => {
    if (ws.replaced) return;
    console.log(role + ' left (' + code + ')');
    if (ws === host) {
      host = null;
      if (code === 4010) { send(guest, { t: 'host', on: false }); return; }          // the host chose to leave: no grace
      startHostGrace();                                                                // line dropped: the guest keeps its level for a while
    } else if (ws === guest) {
      guest = null;
      if (code === 4010) { clearGuestSeat(); send(host, { t: 'peer', on: false }); return; }        // the friend chose to leave
      // line dropped: keep the seat for a while, the host only hears that the friend is lagging
      holdGuestSeat(); send(host, { t: 'peer', lag: true });
    }
  });
});

// the updater replaces server.js: exit, and start.bat starts the new one (it restarts the server whenever it stops)
fs.watchFile(__filename, { interval: 2000 }, (a, b) => { if (a.mtimeMs !== b.mtimeMs) { console.log('server.js was updated - restarting'); process.exit(0); } });

const lanIps = () => Object.values(require('os').networkInterfaces()).flat().filter((n) => n && n.family === 'IPv4' && !n.internal).map((n) => n.address);
process.on('uncaughtException', (e) => console.log('uncaught: ' + (e && e.stack || e)));
server.listen(PORT, () => {
  console.log('\n==============================');
  console.log(' CLAWD co-op server running');
  console.log(' You (this PC):     http://localhost:' + PORT);
  for (const ip of lanIps()) console.log(' Same Wi-Fi/hotspot: http://' + ip + ':' + PORT);
  console.log(' Over the internet:  http://<your public IP>:' + PORT + '  (port forwarding, see README)');
  console.log(' Friend code: ' + CODE + '   (the 2P panel shows it too)');
  if (SIM_ON) console.log(' NETWORK SIMULATOR ON: lag ' + SIM.lag + '\u00b1' + SIM.jit + 'ms' + (SIM.stallPct ? ', stall ' + SIM.stallPct + '% x ' + SIM.stallMs + 'ms' : '') + (SIM.bw ? ', bw ' + SIM.bw + ' B/s' : ''));
  console.log('==============================\n');
  // open the game in the browser once the server is really listening (Windows only; NO_OPEN=1 disables)
  if (process.platform === 'win32' && !process.env.NO_OPEN) require('child_process').exec('start "" http://localhost:' + PORT);
});
