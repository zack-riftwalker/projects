// CLAWD co-op relay on Cloudflare: static game (Workers assets) + one Durable Object that forwards messages between the host and one guest.
// Same behaviour as clawd-coop/server.js, except where the platform forces a difference (see reports/cloud.md).
const SOCK_OPEN = 1;
const MAX_PAYLOAD = 512 * 1024;
const HB = '{"t":"hb"}';
const num = (v, d) => (v !== undefined && v !== null && v !== '' && Number.isFinite(+v) ? +v : d);
const json = (o, status) => new Response(JSON.stringify(o), { status: status || 200, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });

// difficulty defaults from the environment; empty string = not set
const pick = (v) => (v === undefined || v === null || v === '' || !Number.isFinite(+v) ? null : +v);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') return new Response('expected websocket', { status: 426 });
      const id = env.ROOM.idFromName(env.ROOM_NAME || 'main');
      return env.ROOM.get(id, env.LOCATION_HINT ? { locationHint: env.LOCATION_HINT } : undefined).fetch(request);
    }
    if (url.pathname === '/config') return json({ bossPct: pick(env.BOSS_HP), npcExtra: pick(env.NPC_HITS), npcMult: pick(env.NPC_MULT), lock: env.LOCK === '1' });
    return env.ASSETS.fetch(request);       // static files are normally answered before the Worker runs; this is the fallback (404 for everything else)
  },
};

// constant-time string compare (looks at every character of the longer string)
function same(a, b) {
  a = String(a); b = String(b);
  let d = a.length ^ b.length;
  for (let i = 0, n = Math.max(a.length, b.length); i < n; i++) d |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return d === 0;
}
const hex = (n) => Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => b.toString(16).padStart(2, '0')).join('');
const newCode = () => String(100000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 900000));

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx; this.env = env;
    this.socks = new Set(); this.host = null; this.guest = null;
    this.code = null; this.guestTok = null;
    this.graceOn = false; this.graceTimer = null;          // the guest's seat is held
    this.hostGrace = false; this.hostGraceTimer = null;    // the host's seat is held
    this.beat = null; this.fails = new Map();
    this.GRACE = num(env.GRACE_MS, 15000);
    this.sim = { lag: num(env.SIM_LAG, 0), jit: num(env.SIM_JITTER, 0), stallPct: num(env.SIM_STALL_PCT, 0), stallMs: num(env.SIM_STALL_MS, 400), bw: num(env.SIM_BW, 0) };
    this.simOn = !!(this.sim.lag || this.sim.jit || this.sim.stallPct || this.sim.bw);
    this.simShown = false;
    this.lanes = { toGuest: this.lane(), toHost: this.lane() };
    // the code and the guest's token survive a restart of the object
    ctx.blockConcurrencyWhile(async () => {
      this.code = (await ctx.storage.get('code')) || null;
      if (!this.code) { this.code = newCode(); await ctx.storage.put('code', this.code); }
      this.guestTok = (await ctx.storage.get('guestTok')) || null;
      if (this.guestTok) this.holdGuestSeat();            // the guest's line was still "in grace" when the object went away
    });
  }
  currentCode() { return this.env.CODE ? String(this.env.CODE) : this.code; }
  send(s, o) { if (s && s.ws.readyState === SOCK_OPEN) { try { s.ws.send(JSON.stringify(o)); } catch (e) { /* closing */ } } }

  // ---------- wrong codes / keys: 5 failures within a minute from one address lock that address out for a minute ----------
  blocked(ip) { const f = this.fails.get(ip); return !!f && f.until > Date.now(); }
  fail(ip) {
    const now = Date.now(), f = this.fails.get(ip) || { n: 0, first: now, until: 0 };
    if (now - f.first > 60000) { f.n = 0; f.first = now; }
    if (++f.n >= 5) { f.until = now + 60000; f.n = 0; f.first = now; }
    this.fails.set(ip, f);
  }

  // ---------- network simulator (dev only: nothing is scheduled unless a SIM_* var is set) ----------
  lane() { return { q: [], timer: null, lastDue: 0, blockedUntil: 0, bwFree: 0 }; }
  pump(l) {
    if (l.timer) return;
    const step = () => {
      l.timer = null;
      const now = Date.now();
      while (l.q.length && l.q[0].due <= now) { const m = l.q.shift(); const to = m.to(); if (to && to.ws.readyState === SOCK_OPEN) to.ws.send(m.text); }
      if (l.q.length) l.timer = setTimeout(step, Math.max(1, l.q[0].due - Date.now()));
    };
    l.timer = setTimeout(step, 0);
  }
  relayTo(l, to, text) {
    if (!this.simOn) { const t = to(); if (t && t.ws.readyState === SOCK_OPEN) t.ws.send(text); return; }
    const S = this.sim, now = Date.now();
    let due = now + S.lag + (S.jit ? (Math.random() * 2 - 1) * S.jit : 0);
    if (S.stallPct && Math.random() * 100 < S.stallPct) l.blockedUntil = Math.max(l.blockedUntil, now + S.stallMs);
    due = Math.max(due, l.lastDue, l.blockedUntil);
    if (S.bw) { l.bwFree = Math.max(due, l.bwFree) + (text.length / S.bw) * 1000; due = l.bwFree; }
    l.lastDue = due;
    l.q.push({ due, text, to });
    this.pump(l);
  }

  // ---------- connection ----------
  async fetch(request) {
    const url = new URL(request.url), q = url.searchParams, role = q.get('role');
    const ip = String(request.headers.get('CF-Connecting-IP') || (request.headers.get('X-Forwarded-For') || '').split(',')[0].trim() || '?');
    const pair = new WebSocketPair(), client = pair[0], server = pair[1];
    server.accept();
    const s = { ws: server, role, ip, last: Date.now(), gone: false, replaced: false };
    if (this.simOn && !this.simShown) { this.simShown = true; const S = this.sim; console.log('NETWORK SIMULATOR ON: lag ' + S.lag + '±' + S.jit + 'ms' + (S.stallPct ? ', stall ' + S.stallPct + '% x ' + S.stallMs + 'ms' : '') + (S.bw ? ', bw ' + S.bw + ' B/s' : '')); }
    this.socks.add(s);
    const refuse = (code, why) => { s.gone = true; this.socks.delete(s); try { server.close(code, why); } catch (e) { /* gone */ } };
    if (role === 'host') {
      if (this.blocked(ip)) refuse(4005, 'too many wrong codes');
      else if (!this.env.HOST_KEY || !same(q.get('key') || '', this.env.HOST_KEY)) { this.fail(ip); refuse(4003, 'wrong host key'); }
      else this.joinHost(s, q.get('resume') === '1');
    } else if (role === 'guest') this.joinGuest(s, q);
    else refuse(1000, 'bad role');
    if (!s.gone) {
      server.addEventListener('message', (ev) => { try { this.onMessage(s, ev.data); } catch (e) { console.log('message error: ' + (e && e.stack || e)); } });
      server.addEventListener('close', (ev) => this.gone(s, ev.code));
      server.addEventListener('error', () => this.gone(s, 1006));
      this.startBeat();
    }
    return new Response(null, { status: 101, webSocket: client });
  }
  joinHost(s, resume) {
    const old = this.host;
    if (old && !old.gone) {
      if (!resume) { s.gone = true; this.socks.delete(s); try { s.ws.close(4002, 'host exists'); } catch (e) { /* gone */ } return; }
      // the real host is back (its old line is dead or about to be): the key proves who it is
      old.replaced = true; old.gone = true; this.socks.delete(old); try { old.ws.close(4000, 'replaced'); } catch (e) { /* gone */ }
    }
    const wasGrace = this.hostGrace || !!old;
    if (this.hostGrace) { clearTimeout(this.hostGraceTimer); this.hostGrace = false; }
    this.host = s;
    this.send(s, { t: 'code', v: this.currentCode() });
    if (resume && wasGrace) {
      this.send(this.guest, { t: 'host', on: true, resume: true });
      this.send(s, this.guest ? { t: 'peer', on: true, resume: true } : this.graceOn ? { t: 'peer', lag: true } : { t: 'peer', on: false, resume: true });
    } else {
      if (wasGrace) this.send(this.guest, { t: 'host', on: false });     // a fresh host (page reload): the guest starts over
      this.send(this.guest, { t: 'host', on: true, resume: resume || undefined });
      this.send(s, this.guest ? { t: 'peer', on: true, resume: resume || undefined } : this.graceOn ? { t: 'peer', lag: true } : { t: 'peer', on: false, resume: resume || undefined });
    }
    console.log('host connected');
  }
  joinGuest(s, q) {
    const refuse = (code, why) => { s.gone = true; this.socks.delete(s); try { s.ws.close(code, why); } catch (e) { /* gone */ } };
    // a guest whose line dropped may come back with its token, even without the right code
    const resume = !!this.guestTok && (this.graceOn || !!this.guest) && same(q.get('token') || '', this.guestTok);
    if (!resume) {
      if (this.blocked(s.ip)) return refuse(4005, 'too many wrong codes');
      if (!same(q.get('code') || '', this.currentCode())) { this.fail(s.ip); return refuse(4001, 'wrong code'); }
    }
    if (this.guest && !this.guest.gone) { this.guest.replaced = true; this.guest.gone = true; this.socks.delete(this.guest); try { this.guest.ws.close(4000, 'replaced'); } catch (e) { /* gone */ } }
    if (this.graceOn) { clearTimeout(this.graceTimer); this.graceOn = false; }
    this.guest = s;
    if (!resume) { this.guestTok = hex(8); this.ctx.storage.put('guestTok', this.guestTok); }
    this.send(s, { t: 'tok', v: this.guestTok });
    if (this.host) this.send(s, { t: 'host', on: true });
    else if (resume) { this.send(s, { t: 'host', lag: true }); if (!this.hostGrace) this.startHostGrace(false); }       // the host is not back yet (or the object restarted): keep the level, give it time
    else this.send(s, { t: 'host', on: false });
    this.send(this.host, resume ? { t: 'peer', on: true, resume: true } : { t: 'peer', on: true });
    console.log('guest connected');
  }

  // ---------- messages ----------
  onMessage(s, data) {
    s.last = Date.now();
    const len = typeof data === 'string' ? data.length : data.byteLength;
    if (len > MAX_PAYLOAD) { this.gone(s, 1009); try { s.ws.close(1009, 'too big'); } catch (e) { /* gone */ } return; }
    const text = typeof data === 'string' ? data : new TextDecoder().decode(data);
    if (s === this.host) {
      if (text.startsWith('{"t":"newcode"')) { this.newCode(); return; }
      this.relayTo(this.lanes.toGuest, () => this.guest, text);
    } else if (s === this.guest) this.relayTo(this.lanes.toHost, () => this.host, text);
  }
  newCode() {
    this.code = newCode(); this.ctx.storage.put('code', this.code);
    this.send(this.host, { t: 'code', v: this.currentCode() });
    const g = this.guest;
    if (g && !g.gone) { g.gone = true; this.socks.delete(g); this.guest = null; try { g.ws.close(4001, 'new code'); } catch (e) { /* gone */ } }
    this.clearGuestSeat();
    this.send(this.host, { t: 'peer', on: false });
  }
  clearGuestSeat() { clearTimeout(this.graceTimer); this.graceOn = false; this.guestTok = null; this.ctx.storage.delete('guestTok'); }
  holdGuestSeat() {
    this.graceOn = true; clearTimeout(this.graceTimer);
    this.graceTimer = setTimeout(() => { this.graceOn = false; this.guestTok = null; this.ctx.storage.delete('guestTok'); this.send(this.host, { t: 'peer', on: false }); }, this.GRACE);
  }
  startHostGrace(notify) {
    this.hostGrace = true; clearTimeout(this.hostGraceTimer);
    if (notify) this.send(this.guest, { t: 'host', lag: true });
    this.hostGraceTimer = setTimeout(() => { this.hostGrace = false; this.send(this.guest, { t: 'host', on: false }); }, this.GRACE);
  }
  // a socket is gone (closed by the peer, or declared dead by the heartbeat). Safe to call twice.
  gone(s, code) {
    if (s.gone) return;
    s.gone = true; this.socks.delete(s);
    if (!this.socks.size) this.stopBeat();
    if (s.replaced) return;
    console.log(s.role + ' left (' + code + ')');
    if (s === this.host) {
      this.host = null;
      if (code === 4010) { this.send(this.guest, { t: 'host', on: false }); return; }          // the host chose to leave: no grace
      this.startHostGrace(true);                                                                 // line dropped: the guest keeps its level for a while
    } else if (s === this.guest) {
      this.guest = null;
      if (code === 4010) { this.clearGuestSeat(); this.send(this.host, { t: 'peer', on: false }); return; }     // the friend chose to leave
      this.holdGuestSeat(); this.send(this.host, { t: 'peer', lag: true });                     // line dropped: keep the seat, the host only hears the friend is lagging
    }
  }

  // ---------- heartbeat: the relay says {"t":"hb"} every 2 s; a socket silent for more than 7 s is dead (clients send "pg" every 2 s) ----------
  startBeat() {
    if (this.beat) return;
    this.beat = setInterval(() => {
      const now = Date.now();
      for (const s of Array.from(this.socks)) {
        if (now - s.last > 7000) { this.gone(s, 4011); try { s.ws.close(4011, 'silent'); } catch (e) { /* gone */ } continue; }
        if (s.ws.readyState === SOCK_OPEN) { try { s.ws.send(HB); } catch (e) { /* closing */ } }
      }
      for (const [k, f] of this.fails) if (f.until < now && now - f.first > 60000) this.fails.delete(k);
    }, 2000);
  }
  stopBeat() { if (this.beat) { clearInterval(this.beat); this.beat = null; } }
}
