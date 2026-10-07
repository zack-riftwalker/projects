// Phase 3 scenarios (loaded by coop-harness.js)
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, sleep, R, holdKey } = h;

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
      const ok = guestLag > 100 && guestLag < 500 && hpG === maxHp - 1 && hpH === maxHp - 1 && tBounce > 0 && killLag > 100 && killLag < 500 && hpAfter === maxHp;
      return R(ok, 'spikes: guest acted ' + guestLag.toFixed(0) + ' ms before the host heard of it (want 100..500 at lag 150), hp guest ' + hpG + ' / host ' + hpH + ' (want ' + (maxHp - 1) + ' both, no double loss); stomp: guest bounced ' + killLag.toFixed(0) + ' ms before the bug died on the host (want 100..500), guest hp unchanged ' + (hpAfter === maxHp));
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
      const flightOk = gq && Math.abs(gq.x - hq.x) < 25;
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
        const d = Math.abs(xs[i][1] - xs[i - 1][1]); maxD = Math.max(maxD, d);
        if (prevD === 0 && d > 6) lurch++;
        prevD = d;
      }
      return R(maxD <= 3 && lurch === 0, 'walking bug, ' + xs.length + ' frames at lag ' + (T.sim.SIM_LAG || process.env.SIM_LAG || '150') + ': max per-frame step ' + maxD.toFixed(2) + ' px (want <= 3), freeze-then-lurch frames ' + lurch + ' (want 0)');
    } finally { await T.close(); }
  };
};
