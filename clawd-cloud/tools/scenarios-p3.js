// Phase 3 scenarios (loaded by coop-harness.js)
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, R, holdKey } = h;
  // on a slow line everything simply takes longer: waits grow with the lag
  const K = () => Math.max(1, (+process.env.SIM_LAG || 0) / 150);
  const sleep = (ms) => h.sleep(ms * K());

  // reliable channel: 40 % of all incoming messages are thrown away on both sides, 100 events must still arrive once, in order
  S['reliable'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(800);
      for (const p of [T.host, T.guest]) await p.evaluate(() => { G.coop.dbg.dropRx = 0.4; G.coop.testLog = []; });
      await T.guest.evaluate(() => { for (let i = 1; i <= 100; i++) G.coop.rel('test', { n: i }); });
      let log = [];
      for (let i = 0; i < 80; i++) { log = await T.host.evaluate(() => G.coop.testLog); if (log.length >= 100) break; await sleep(250); }
      await sleep(600);
      log = await T.host.evaluate(() => G.coop.testLog);
      const pending = await T.guest.evaluate(() => G.coop.R.out.length);
      for (const p of [T.host, T.guest]) await p.evaluate(() => { G.coop.dbg.dropRx = 0; });
      const inOrder = log.length === 100 && log.every((v, i) => v === i + 1);
      return R(inOrder && pending === 0, 'host received ' + log.length + '/100 events ' + (inOrder ? 'once each, in order' : 'WRONG: ' + log.slice(0, 20).join(',')) + '; still unacknowledged on the guest: ' + pending);
    } finally { await T.close(); }
  };

  // half of the host's snapshots never reach the guest for 6 s (kills, token pickups, a broken wall happen meanwhile);
  // afterwards the guest must show exactly the host's world again
  S['lossy'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '2-1'); await sleep(1200);
      await T.guest.evaluate(() => { G.coop.dbg.dropRx = 0.5; });
      // while snapshots are being lost: the host kills enemies, collects things, breaks a cracked wall
      await T.host.evaluate(() => { const L = G.scene.L; window.__kills = []; for (const e of L.ents.filter((x) => !x.isBoss && !x.noHit).slice(0, 3)) { window.__kills.push(e._id); e.hit(99, 0, 0, 'swipe'); } L.tokens += 5; const t = L.tiles.indexOf(G.TILE.CRACK); if (t >= 0) L.breakTile(t % L.w, (t / L.w) | 0); });
      await sleep(6000);
      await T.guest.evaluate(() => { G.coop.dbg.dropRx = 0; });
      await sleep(2000);
      const snap = (p) => p.evaluate(() => { const L = G.scene.L; return { ids: L.ents.filter((e) => !e.dead).map((e) => e._id).sort((a, b) => a - b).join(','), tokens: L.tokens, tiles: Array.from(L.tiles).join('').length + ':' + L.tiles.reduce((a, v, i) => a + v * (i % 97 + 1), 0), items: L.items.filter((i) => !i.dead).length }; });
      const [hs, gs] = [await snap(T.host), await snap(T.guest)];
      const ok = hs.ids === gs.ids && hs.tokens === gs.tokens && hs.tiles === gs.tiles && hs.items === gs.items;
      return R(ok, 'host ' + JSON.stringify(hs) + ' guest ' + JSON.stringify(gs));
    } finally { await T.close(); }
  };

  // at 150 ms one-way lag the guest's own body reacts at once: spikes teleport it back immediately, a stomp bounces immediately,
  // the creature dies on the host a lag later, and nothing is counted twice
  S['ownership'] = async () => {
    const T = await openPair({ env: process.env.SIM_LAG ? {} : { SIM_LAG: '150' } });
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      await T.host.evaluate(() => { const L = G.scene.L; L.ents.length = 0; });
      await sleep(300);
      // --- spikes
      const spot = await T.guest.evaluate(() => {
        const L = G.scene.L;
        for (let ty = 1; ty < L.h - 1; ty++) for (let tx = 2; tx < L.w - 2; tx++) if (L.tiles[ty * L.w + tx] === G.TILE.SPIKE_U && L.tile(tx, ty - 1) === 0 && L.tile(tx, ty - 2) === 0) { return { tx, ty }; }
        return null;
      });
      if (!spot) return R(false, 'no spikes found in 1-1');
      await T.host.evaluate(() => { const o = G.coop.onRel; window.__hzHost = 0; G.coop.onRel = function (ev, m) { if (ev.k === 'hazard' && !window.__hzHost) window.__hzHost = performance.now() + performance.timeOrigin; return o.call(this, ev, m); }; });
      await T.guest.evaluate((sp) => {
        const L = G.scene.L, p = L.me; window.__hzGuest = 0; p.inv = 0; p.hp = p.maxHp;
        const h0 = p.hazard; p.hazard = function () { if (!window.__hzGuest) window.__hzGuest = performance.now() + performance.timeOrigin; return h0.call(this); };
        p.x = sp.tx * 16 + 3; p.y = sp.ty * 16 - 14; p.vx = p.vy = 0; p.gone = false; p.dashT = 0;
      }, spot);
      await sleep(1500);
      const tHazG = await T.guest.evaluate(() => window.__hzGuest), tHazH = await T.host.evaluate(() => window.__hzHost);
      const guestLag = tHazH - tHazG;               // the guest acted this long BEFORE the host heard about it
      const hpG = await T.guest.evaluate(() => G.scene.L.me.hp);
      await sleep(900);
      const hpH = await T.host.evaluate(() => G.scene.L.p2.hp);
      const maxHp = await T.guest.evaluate(() => G.scene.L.me.maxHp);
      // --- stomp
      await T.guest.evaluate(() => { const p = G.scene.L.me; p.hp = p.maxHp; p.inv = 0; p.gone = false; });
      const bug = await T.host.evaluate(() => {
        const L = G.scene.L, p = L.p2, e = new G.Enemies.Bug(L, 0, 0, false);
        e.update = () => {}; e.x = p.x + 40; e.y = p.y + p.h - e.h; e.vx = e.vy = 0; L.ents.push(e); G.coop.hostTick(L, 0);
        window.__bug = e; return { id: e._id, x: e.x, y: e.y };
      });
      await T.guest.waitForFunction((id) => G.scene.L.ents.some((e) => e._id === id), bug.id, { timeout: 5000 });
      await T.host.evaluate(() => { window.__tdead = 0; const iv = setInterval(() => { if (window.__bug.dead && !window.__tdead) { window.__tdead = performance.now() + performance.timeOrigin; clearInterval(iv); } }, 4); });
      await T.guest.evaluate((b) => {
        const L = G.scene.L, p = L.me, e = L.ents.find((x) => x._id === b.id);
        window.__tb = 0; const b0 = p.bounce; p.bounce = function (k) { if (!window.__tb) window.__tb = performance.now() + performance.timeOrigin; return b0.call(this, k); };
        p.x = e.x + 1; p.y = e.y - p.h - 10; p.vx = 0; p.vy = 160; p.gone = false;
      }, bug);
      await sleep(1500);
      const tBounce = await T.guest.evaluate(() => window.__tb), tdead = await T.host.evaluate(() => window.__tdead);
      const killLag = tdead - tBounce;               // the creature dies on the host this long AFTER the guest already bounced
      const hpAfter = await T.guest.evaluate(() => G.scene.L.me.hp);
      const lag = +(process.env.SIM_LAG || 150), lo = lag * 0.65, hi = lag * 3.2 + 250;
      const ok = guestLag > lo && guestLag < hi && hpG === maxHp - 1 && hpH === maxHp - 1 && tBounce > 0 && killLag > lo && killLag < hi && hpAfter === maxHp;
      return R(ok, 'spikes: guest acted ' + guestLag.toFixed(0) + ' ms before the host heard of it (want ' + lo.toFixed(0) + '..' + hi.toFixed(0) + '), hp guest ' + hpG + ' / host ' + hpH + ' (want ' + (maxHp - 1) + ' both, no double loss); stomp: guest bounced ' + killLag.toFixed(0) + ' ms before the bug died on the host (want ' + lo.toFixed(0) + '..' + hi.toFixed(0) + '), guest hp unchanged ' + (hpAfter === maxHp));
    } finally { await T.close(); }
  };

  // the guest swings at a boss: the host's boss loses hit points; and a fallen guest is revived by the host
  S['guest-fight'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-B'); await sleep(2800);
      await h.godmode(T);
      const b0 = await T.host.evaluate(() => G.scene.L.boss.hp);
      await T.guest.evaluate(() => { const L = G.scene.L, p = L.me, b = L.boss; p.x = b.x - 14; p.y = b.y + b.h - p.h; p.vx = p.vy = 0; p.face = 1; });
      for (let i = 0; i < 6; i++) { await h.key(T.guest, 'ArrowRight', true); await h.key(T.guest, 'KeyX', true); await sleep(80); await h.key(T.guest, 'KeyX', false); await h.key(T.guest, 'ArrowRight', false); await sleep(450); await T.guest.evaluate(() => { const L = G.scene.L, p = L.me, b = L.boss; p.x = b.x - 14; p.y = b.y + b.h - p.h; p.vx = p.vy = 0; }); }
      const b1 = await T.host.evaluate(() => G.scene.L.boss.hp);
      await h.noGod(T);
      // --- fall and be revived
      await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.hp = 1; p.hurt(1, p.x + 30); });
      await sleep(600);
      const down = await T.host.evaluate(() => ({ dead: G.scene.L.p2.dead, q: G.scene.L.reviveQ.length }));
      await sleep(4600);
      const up = await T.guest.evaluate(() => ({ dead: G.scene.L.me.dead, hp: G.scene.L.me.hp }));
      const hostSees = await T.host.evaluate(() => ({ dead: G.scene.L.p2.dead, hp: G.scene.L.p2.hp }));
      return R(b1 < b0 && down.dead && down.q === 1 && !up.dead && up.hp > 0 && !hostSees.dead, 'boss hp ' + b0 + ' -> ' + b1 + ' (guest swings); guest down on host=' + down.dead + ' queued=' + down.q + '; after 5 s guest dead=' + up.dead + ' hp=' + up.hp + ', host sees dead=' + hostSees.dead);
    } finally { await T.close(); }
  };

  // projectiles are events: the guest flies them itself (matches the host), takes hits from them itself, cuts them itself
  S['projectiles'] = async () => {
    const T = await openPair({ env: process.env.SIM_LAG ? {} : { SIM_LAG: '100' } });
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      await T.host.evaluate(() => { G.scene.L.ents.length = 0; });
      // 1) a long flight far from both players: same place on both screens
      await T.host.evaluate(() => { const L = G.scene.L; window.__q1 = L.shoot(40, 20, 90, 0, { kind: 'orb', col: '#ff5d5d', r: 3, life: 6, tile: false }); });
      await sleep(900);
      const [hq, gq] = [await T.host.evaluate(() => ({ x: window.__q1.x, dead: window.__q1.dead })), await T.guest.evaluate(() => { const q = G.scene.L.projs.find((q) => q.pid === 1); return q ? { x: q.x } : null; })];
      const flightOk = gq && Math.abs(gq.x - hq.x) < 25 + (+process.env.SIM_LAG || 100) * 0.35;
      // 2) one flies into the guest: it loses exactly one hit point, the host's projectile is gone
      await T.host.evaluate(() => { G.scene.L.me.inv = 99; });       // the host player stands next to the partner: it must not catch the shot
      const hp0 = await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.hp = p.maxHp; p.dashT = 0; return p.hp; });
      await T.host.evaluate(() => { const L = G.scene.L, p = L.p2; window.__q2 = L.shoot(p.x - 60, p.y + 5, 120, 0, { kind: 'orb', col: '#ff5d5d', r: 3, life: 4, tile: false }); });
      await sleep(1500);
      const hp1 = await T.guest.evaluate(() => G.scene.L.me.hp), q2dead = await T.host.evaluate(() => window.__q2.dead);
      // 3) the guest cuts one with its claw
      await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 99; });
      await T.host.evaluate(() => { const L = G.scene.L, p = L.p2; window.__q3 = L.shoot(p.x + 90, p.y + 4, -60, 0, { kind: 'orb', col: '#ff5d5d', r: 3, life: 6, tile: false }); });
      await sleep(250);
      for (let i = 0; i < 16; i++) { await h.key(T.guest, 'KeyX', true); await sleep(60); await h.key(T.guest, 'KeyX', false); await sleep(130); if (await T.host.evaluate(() => window.__q3.dead)) break; }
      await sleep(400);
      const q3dead = await T.host.evaluate(() => window.__q3.dead), q3x = await T.host.evaluate(() => window.__q3.x - G.scene.L.p2.x);
      const ok = flightOk && hp1 === hp0 - 1 && q2dead && q3dead;
      return R(ok, 'flight: host x ' + hq.x.toFixed(0) + ' guest x ' + (gq ? gq.x.toFixed(0) : 'missing') + '; hit: guest hp ' + hp0 + ' -> ' + hp1 + ' (want -1), host projectile gone=' + q2dead + '; cut by claw: host projectile gone=' + q3dead);
    } finally { await T.close(); }
  };

  // a walking creature must look smooth on the guest: no frame-to-frame jump above 3 px, no freeze followed by a lurch
  S['smooth'] = async () => {
    const env = process.env.SIM_LAG ? {} : { SIM_LAG: '150', SIM_JITTER: '60', SIM_STALL_PCT: '5' };
    const T = await openPair({ env });
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      const id = await T.host.evaluate(() => {
        const L = G.scene.L; L.ents.length = 0;
        const p = L.me; const e = new G.Enemies.Bug(L, 0, 0, false); e.x = p.x + 30; e.y = p.y + p.h - e.h; e.speed = 40; L.ents.push(e); G.coop.hostTick(L, 0);
        // keep it walking in a corridor around the players (turn at fixed limits, never hurt anyone)
        const x0 = p.x + 20; window.__bugIv = setInterval(() => { const q = L.ents[0]; if (!q) return; q.dmg = 0; if (q.x > x0 + 140) q.face = -1; if (q.x < x0) q.face = 1; }, 30);
        return e._id;
      });
      await T.guest.waitForFunction((id) => G.scene.L.ents.some((e) => e._id === id), id, { timeout: 8000 });
      await sleep(1500);
      await T.guest.evaluate((id) => { window.__sm = []; const f = () => { const e = G.scene.L.ents.find((x) => x._id === id); if (e) window.__sm.push([performance.now(), e.x]); window.__smraf = requestAnimationFrame(f); }; f(); }, id);
      await sleep(6000);
      const xs = await T.guest.evaluate(() => { cancelAnimationFrame(window.__smraf); return window.__sm; });
      let maxD = 0, lurch = 0, prevD = null;
      for (let i = 1; i < xs.length; i++) {
        const dtMs = Math.max(8, xs[i][0] - xs[i - 1][0]), d = Math.abs(xs[i][1] - xs[i - 1][1]) * (1000 / 60) / dtMs;      // per 60 fps frame, so a slow test machine does not count as lurching
        maxD = Math.max(maxD, d);
        if (prevD === 0 && d > 6) lurch++;
        prevD = d;
      }
      return R(maxD <= 3 && lurch === 0, 'walking bug, ' + xs.length + ' frames at lag ' + (T.sim.SIM_LAG || process.env.SIM_LAG || '150') + ': max per-frame step ' + maxD.toFixed(2) + ' px (want <= 3), freeze-then-lurch frames ' + lurch + ' (want 0)');
    } finally { await T.close(); }
  };

  // are the per-class field lists complete? Every property that a creature's draw() / hurtboxes() / harmboxes() reads AND that changes
  // while it lives must be on its list (or be rebuilt locally). Checked by running every level and every boss with property-read tracking.
  S['netfields'] = async () => {
    const srv = await h.startServer();
    const browser = await h.chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
    const errs = [];
    try {
      const page = await h.openPage(browser, 'http://127.0.0.1:' + srv.port + '/?mute&manual', errs, 'solo');
      const res = await page.evaluate(() => {
        const need = {}, listed = G.coop.netspec, local = G.coop.localrun;
        const own = (o, k) => Object.prototype.hasOwnProperty.call(o, k);
        const snap = (e) => { const o = {}; for (const k of Object.keys(e)) { const v = e[k], t = typeof v; if (t === 'number' || t === 'string' || t === 'boolean') o[k] = v; else if (v && t === 'object' && k !== 'L' && !(v instanceof HTMLElement) && (Array.isArray(v) || Object.getPrototypeOf(v) === Object.prototype)) { try { o[k] = JSON.stringify(v, (kk, vv) => (kk === 'def' ? undefined : vv)); } catch (x) { /* cyclic */ } } } return o; };
        for (const id of G.NODES) {
          for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true;
          G.setScene(G.Scenes.play(id, null));
          const L = G.scene.L, last = new Map(), reads = new Map(), chg = new Map();
          const acts = ['right', 'jump', 'attack', 'dash', 'left', 'down', 'up'];
          for (let i = 0; i < (id.endsWith('B') ? 1500 : Math.max(700, L.ents.length * 45 + 60)); i++) {
            G.input.script = { right: (i >> 6) % 2 === 0 }; G.input.script[acts[(i >> 4) % acts.length]] = true;
            L.me.inv = 99; L.me.hp = L.me.maxHp;
            if (!id.endsWith('B') && i % 45 === 0 && L.ents.length) { const e = L.ents[(i / 45 | 0) % L.ents.length]; L.me.x = e.x - 24; L.me.y = e.y - 6; L.me.vx = L.me.vy = 0; L.snapCam(); }       // visit every creature so it wakes up
            G.step(1, true);
            for (const e of L.ents) {
              const c = e.constructor.name;
              if (e.dead) continue;
              const now = snap(e), was = last.get(e);
              if (was) for (const k in now) if (was[k] !== now[k]) { (chg.get(c) || chg.set(c, new Set()).get(c)).add(k); }
              last.set(e, now);
              if (i % 3 === 0) {
                const rs = reads.get(c) || reads.set(c, new Set()).get(c);
                const px = new Proxy(e, { get(t, k, r) { if (typeof k === 'string' && own(t, k) && typeof t[k] !== 'function') rs.add(k); return Reflect.get(t, k, r); } });
                try { px.draw(G.g, L.cx || 0, L.cy || 0); px.hurtboxes(); px.harmboxes(); } catch (x) { /* some need a rendered frame */ }
              }
            }
          }
          G.input.script = null;
          for (const [c, rs] of reads) for (const k of rs) if (chg.get(c) && chg.get(c).has(k)) (need[c] || (need[c] = {}))[k] = 1;
        }
        const out = {};
        for (const c in need) {
          if (local.has(c)) continue;
          const have = new Set((listed[c] || listed.Bug).split(' ').map((x) => x.split(':')[0]));
          const miss = Object.keys(need[c]).filter((k) => !have.has(k));
          out[c] = { miss, needed: Object.keys(need[c]) };
        }
        return out;
      });
      // properties the guest rebuilds by itself, or that only matter to the host
      const OK = { '*': ['t', 'hitWall', 'stun'], Loop: ['x', 'y', 'hist', 'N', 'u', 'path', 'lastK', 'dieT', 'ang'], Null: ['trail', 'tx', 'ty', 'x', 'y'] };
      const bad = [];
      for (const c in res) { const miss = res[c].miss.filter((k) => !(OK['*'].includes(k) || (OK[c] || []).includes(k))); if (miss.length) bad.push(c + ': ' + miss.join(',')); }
      return R(bad.length === 0 && errs.length === 0, bad.length ? 'MISSING ' + bad.join(' | ') : 'all ' + Object.keys(res).length + ' classes complete (' + Object.keys(res).map((c) => c + '[' + res[c].needed.join(',') + ']').join(' ') + ')' + (errs.length ? '; errors ' + errs.slice(0, 3).join('|') : ''));
    } finally { await browser.close(); await srv.stop(); }
  };

  // the send rate follows the line: bad ping -> fewer snapshots / reports (3 s dwell between changes)
  S['rates'] = async () => {
    const out = [];
    let ok = true;
    for (const [lag, want] of [[0, 0], [150, 1], [300, 2]]) {
      const T = await openPair({ env: { SIM_LAG: String(lag), SIM_JITTER: '0', SIM_STALL_PCT: '0', SIM_BW: '0' } });      // this test sets its own line, whatever the environment says
      try {
        await startLevel(T, '1-1'); await sleep(8500);
        const r = await T.host.evaluate(() => ({ lvl: G.coop.rate.level, snap: G.coop.rate.snap, rtt: G.coop.ping }));
        const g = await T.guest.evaluate(() => ({ lvl: G.coop.rate.level, st: G.coop.rate.st, rtt: G.coop.ping }));
        out.push('lag ' + lag + ': rtt ' + r.rtt + ' -> level ' + r.lvl + ' (host ' + Math.round(60 / r.snap) + ' Hz), guest level ' + g.lvl + ' (' + Math.round(60 / g.st) + ' Hz)');
        if (r.lvl !== want || g.lvl !== want) ok = false;
      } finally { await T.close(); }
    }
    return R(ok, out.join('; '));
  };
  // a narrow line must not build a growing queue: after a minute of boss fight the ping is still close to the bare line delay
  S['bufferbloat'] = async () => {
    const lag = +(process.env.SIM_LAG || 150), env = process.env.SIM_LAG ? {} : { SIM_LAG: '150', SIM_JITTER: '60', SIM_STALL_PCT: '5', SIM_BW: '8000' };
    const T = await openPair({ env });
    try {
      await startLevel(T, '2-B'); await sleep(3000);
      await h.godmode(T);
      const secs = +(process.env.BB_SECS || 60), hist = [];
      const walk = (async () => { for (let i = 0; i < secs / 1.2; i++) await holdKey(T.guest, i % 2 ? 'ArrowLeft' : 'ArrowRight', 1000); })();
      for (let i = 0; i < secs; i++) { await sleep(1000); hist.push(await T.guest.evaluate(() => G.coop.ping)); }
      await walk;
      const late = hist.slice(-20), max = Math.max(...late), med = late.slice().sort((a, b) => a - b)[10];
      const drops = await T.host.evaluate(() => G.coop.skipped);
      const base = 2 * lag;
      return R(max < base * 2 + 150, 'bare round trip ' + base + ' ms; last 20 s: median ' + med + ' ms, max ' + max + ' ms (want < ' + (base * 2 + 150) + '); host skipped ' + drops + ' sends; ping every 10 s: ' + hist.filter((_, i) => i % 10 === 9).join(','));
    } finally { await T.close(); }
  };

  // the guest's own swing is felt at the moment of contact (sound, spark, 30 ms hitstop), and the host's echo is not played again
  S['hitfeel'] = async () => {
    const T = await openPair({ env: process.env.SIM_LAG ? {} : { SIM_LAG: '150' } });
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      await T.host.evaluate(() => { const L = G.scene.L; L.ents.length = 0; });
      const bug = await T.host.evaluate(() => {
        const L = G.scene.L, p = L.p2, e = new G.Enemies.Bug(L, 0, 0, false);
        e.update = () => {}; e.hp = 6; e.x = p.x + 16; e.y = p.y + p.h - e.h; e.vx = e.vy = 0; L.ents.push(e); G.coop.hostTick(L, 0);
        window.__bug = e; window.__thit = 0; window.__hp0 = e.hp;
        const iv = setInterval(() => { if (e.hp < window.__hp0 && !window.__thit) { window.__thit = performance.now() + performance.timeOrigin; clearInterval(iv); } }, 4);
        return { id: e._id };
      });
      await T.guest.waitForFunction((id) => G.scene.L.ents.some((e) => e._id === id), bug.id, { timeout: 5000 });
      await sleep(600);
      await T.guest.evaluate(() => {
        const L = G.scene.L, p = L.me; window.__sfx = {}; window.__tsfx = 0; window.__stop = 0;
        const o = G.audio.sfx; G.audio.sfx = function (n, a) { window.__sfx[n] = (window.__sfx[n] || 0) + 1; if (n === 'hit' && !window.__tsfx) window.__tsfx = performance.now() + performance.timeOrigin; return o.call(this, n, a); };
        const f = () => { if (L.hitstop > 0) window.__stop = Math.max(window.__stop, L.hitstop); requestAnimationFrame(f); }; f();
        p.face = 1;
      });
      await h.key(T.guest, 'KeyX', true); await sleep(60); await h.key(T.guest, 'KeyX', false);
      await sleep(1500);
      const g = await T.guest.evaluate(() => ({ sfx: window.__sfx, t: window.__tsfx, stop: window.__stop })), th = await T.host.evaluate(() => window.__thit);
      const early = th - g.t;
      const lag = +(process.env.SIM_LAG || 150);
      return R((g.sfx.hit || 0) === 1 && early > lag * 0.65 && g.stop > 0 && g.stop <= 0.031, 'hit sound played ' + (g.sfx.hit || 0) + 'x on the guest (want 1), ' + early.toFixed(0) + ' ms before the host applied the damage (want > ' + (lag * 0.65).toFixed(0) + '), guest hitstop ' + g.stop.toFixed(3) + ' s (want 0..0.03)');
    } finally { await T.close(); }
  };

  // a partner who stops answering becomes a ghost (not targeted, cannot revive); a bad line gives the guest extra mercy
  S['lenient'] = async () => {
    const T = await openPair({ env: process.env.SIM_LAG ? {} : { SIM_LAG: '150' } });
    try {
      await startLevel(T, '1-1'); await sleep(3500);       // let the first ping measure the line
      // extra invulnerability after a hit on a slow line
      const inv = await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.grace = 0; p.hurt(1, p.x + 20); return p.inv; });
      await sleep(300);
      const ok0 = await T.host.evaluate(() => !G.scene.L.p2.lagging);
      // the guest's game loop stops answering
      await T.guest.evaluate(() => { window.__upd = G.scene.update; G.scene.update = () => {}; });
      await sleep(1800);
      const lag = await T.host.evaluate(() => { const L = G.scene.L; return { lagging: L.p2.lagging, aim: G.coop.aimAt(L, { x: L.p2.x, y: L.p2.y, w: 1, h: 1 }) === L.me }; });
      await T.host.evaluate(() => { window.__L0 = G.scene.L; G.scene.L.me.die(); });          // nobody can pick me up: the level restarts
      let restarted = false; const t0 = Date.now();
      while (Date.now() - t0 < 6000) { if (await T.host.evaluate(() => G.scene.L !== window.__L0 && !!G.scene.L)) { restarted = true; break; } await sleep(100); }
      return R(inv > 1.6 && ok0 && lag.lagging && lag.aim && restarted, 'guest inv after a hit ' + inv.toFixed(2) + ' (1.3 normal, want > 1.6 on a slow line); partner lagging after 1.8 s silence=' + lag.lagging + ', enemies ignore it=' + lag.aim + '; host down + lagging partner -> restart ' + restarted + ' after ' + (Date.now() - t0) + ' ms');
    } finally { await T.close(); }
  };

  // the guest's connection dies in the middle of a boss fight: it comes back to the same fight within seconds, nothing restarts
  S['blip'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '3-B'); await sleep(3500);
      await h.godmode(T);
      await T.host.evaluate(() => { window.__L0 = G.scene.L; window.__P0 = G.scene.L.p2; window.__hp0 = G.scene.L.boss.hp; });
      await T.guest.evaluate(() => { window.__GL0 = G.scene.L; });
      const t0 = Date.now();
      await T.guest.evaluate(() => G.coop.ws.close());
      // a reliable event raised during the outage must still arrive afterwards
      await T.guest.evaluate(() => { G.coop.testLog = []; G.coop.rel('test', { n: 7 }); });
      let back = false;
      while (Date.now() - t0 < 5000) { if (await T.guest.evaluate(() => G.coop.open && !G.coop.reconnecting)) { back = true; break; } await sleep(100); }
      const tBack = Date.now() - t0;
      await sleep(1500);
      const host = await T.host.evaluate(() => ({ same: G.scene.L === window.__L0 && G.scene.L.p2 === window.__P0, peer: G.coop.peer, lag: !!G.scene.L.p2.lagging, hpMoved: G.scene.L.boss.hp <= window.__hp0, boss: G.scene.L.boss.hp, ev: G.coop.testLog.slice() }));
      const guest = await T.guest.evaluate(() => ({ same: G.scene.L === window.__GL0, net: G.scene.L.net, fight: G.scene.L.boss.active, hp: G.scene.L.boss.hp }));
      const ok = back && tBack < 3000 && host.same && host.peer && !host.lag && guest.same && guest.net === 'guest' && guest.fight && host.ev.includes(7) && Math.abs(guest.hp - host.boss) < 0.01;
      return R(ok, 'guest back after ' + tBack + ' ms; host level+partner unchanged=' + host.same + ' peer=' + host.peer + ' lagging=' + host.lag + '; guest same level=' + guest.same + ' fight on=' + guest.fight + '; event sent during outage arrived=' + host.ev.includes(7) + '; boss hp host ' + host.boss + ' guest ' + guest.hp);
    } finally { await T.close(); }
  };

  // a guest that never comes back is let go after the grace time (shortened here to 2 s)
  S['grace'] = async () => {
    const T = await openPair({ env: { GRACE_MS: '2000' } });
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      await T.guest.close();
      await sleep(900);
      const early = await T.host.evaluate(() => ({ net: G.scene.L.net, lag: !!(G.scene.L.p2 && G.scene.L.p2.lagging) || G.coop.peerLag }));
      await sleep(2600);
      const late = await T.host.evaluate(() => ({ net: G.scene.L.net, peer: G.coop.peer }));
      return R(early.net === 'host' && early.lag && !late.net && !late.peer, 'right after the drop: partner kept, marked lagging=' + early.lag + '; after the grace time: net=' + late.net + ' peer=' + late.peer);
    } finally { await T.close(); }
  };
};
