// CLAWD co-op relay: serves the game and forwards messages between the host and one guest.
const http = require('http'), fs = require('fs'), path = require('path');
const { WebSocketServer } = require('ws');
const PORT = process.env.PORT || 3000;
const ROOT = __dirname;
const CODE = process.env.CODE || String(Math.floor(1000 + Math.random() * 9000));
const MIME = { '.html': 'text/html; charset=utf-8', '.mp3': 'audio/mpeg', '.js': 'text/javascript', '.png': 'image/png', '.json': 'application/json' };

// a request that came through the tunnel carries proxy headers; a local one does not
const isLocal = (req) => {
  const a = req.socket.remoteAddress || '';
  const loop = a === '127.0.0.1' || a === '::1' || a === '::ffff:127.0.0.1';
  return loop && !req.headers['cf-connecting-ip'] && !req.headers['x-forwarded-for'];
};

const server = http.createServer((req, res) => {
  let u = decodeURIComponent(req.url.split('?')[0]);
  if (u === '/code') {
    if (!isLocal(req)) { res.writeHead(403); return res.end('no'); }
    res.writeHead(200, { 'Content-Type': 'text/plain' }); return res.end(CODE);
  }
  if (u === '/') u = '/index.html';
  if (u !== '/index.html' && !u.startsWith('/assets/')) { res.writeHead(404); return res.end('not found'); }
  const f = path.join(ROOT, path.normalize(u));
  if (!f.startsWith(ROOT)) { res.writeHead(403); return res.end(); }
  fs.readFile(f, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
    res.end(data);
  });
});

// ---------- network simulator (off unless a SIM_* env var is set) ----------
// SIM_LAG ms one-way delay, SIM_JITTER +-ms, SIM_STALL_PCT % chance a direction freezes for SIM_STALL_MS (TCP head-of-line blocking),
// SIM_BW bytes/s cap per direction (queue = bufferbloat). Per-direction order is always preserved.
const num = (v, d) => (Number.isFinite(+v) && v !== undefined && v !== '' ? +v : d);
const SIM = { lag: num(process.env.SIM_LAG, 0), jit: num(process.env.SIM_JITTER, 0), stallPct: num(process.env.SIM_STALL_PCT, 0), stallMs: num(process.env.SIM_STALL_MS, 400), bw: num(process.env.SIM_BW, 0) };
const SIM_ON = !!(SIM.lag || SIM.jit || SIM.stallPct || SIM.bw);
const lane = () => ({ q: [], timer: null, lastDue: 0, blockedUntil: 0, bwFree: 0 });
const lanes = { toGuest: lane(), toHost: lane() };
function pump(l) {
  if (l.timer) return;
  const step = () => {
    l.timer = null;
    const now = Date.now();
    while (l.q.length && l.q[0].due <= now) { const m = l.q.shift(); const to = m.to(); if (to && to.readyState === 1) to.send(m.text); }
    if (l.q.length) l.timer = setTimeout(step, Math.max(1, l.q[0].due - Date.now()));
  };
  l.timer = setTimeout(step, 0);
}
function relayTo(l, to, text) {
  if (!SIM_ON) { const t = to(); if (t && t.readyState === 1) t.send(text); return; }
  const now = Date.now();
  let due = now + SIM.lag + (SIM.jit ? (Math.random() * 2 - 1) * SIM.jit : 0);
  if (SIM.stallPct && Math.random() * 100 < SIM.stallPct) l.blockedUntil = Math.max(l.blockedUntil, now + SIM.stallMs);
  due = Math.max(due, l.lastDue, l.blockedUntil);
  if (SIM.bw) { l.bwFree = Math.max(due, l.bwFree) + (text.length / SIM.bw) * 1000; due = l.bwFree; }
  l.lastDue = due;
  l.q.push({ due, text, to });
  pump(l);
}

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 512 * 1024, perMessageDeflate: { threshold: 200 } });
let host = null, guest = null;
const send = (ws, o) => { if (ws && ws.readyState === 1) ws.send(JSON.stringify(o)); };

wss.on('connection', (ws, req) => {
  const q = new URL(req.url, 'http://x').searchParams, role = q.get('role');
  if (role === 'host') {
    if (!isLocal(req)) return ws.close(4001, 'host must be local');
    if (host && host.readyState === 1) return ws.close(4002, 'host exists');
    host = ws;
    send(guest, { t: 'host', on: true });
    send(host, { t: 'peer', on: !!guest });
  } else if (role === 'guest') {
    if (q.get('code') !== CODE) return ws.close(4001, 'wrong code');
    if (guest && guest.readyState === 1) guest.close(4000, 'replaced');
    guest = ws;
    send(guest, { t: 'host', on: !!host });
    send(host, { t: 'peer', on: true });
  } else return ws.close();
  console.log(role + ' connected');
  ws.on('message', (data) => {
    if (ws === host) relayTo(lanes.toGuest, () => guest, data.toString());
    else relayTo(lanes.toHost, () => host, data.toString());
  });
  ws.on('close', () => {
    console.log(role + ' left');
    if (ws === host) { host = null; send(guest, { t: 'host', on: false }); }
    else if (ws === guest) { guest = null; send(host, { t: 'peer', on: false }); }
  });
});

server.listen(PORT, () => {
  console.log('\n==============================');
  console.log(' CLAWD co-op server running');
  console.log(' You:    http://localhost:' + PORT);
  console.log(' Friend code: ' + CODE);
  if (SIM_ON) console.log(' NETWORK SIMULATOR ON: lag ' + SIM.lag + '\u00b1' + SIM.jit + 'ms' + (SIM.stallPct ? ', stall ' + SIM.stallPct + '% x ' + SIM.stallMs + 'ms' : '') + (SIM.bw ? ', bw ' + SIM.bw + ' B/s' : ''));
  console.log('==============================\n');
});
