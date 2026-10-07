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
    const other = ws === host ? guest : host;
    if (other && other.readyState === 1) other.send(data.toString());
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
  console.log('==============================\n');
});
