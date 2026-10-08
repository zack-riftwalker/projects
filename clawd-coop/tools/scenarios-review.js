// Scenarios for four bugs found in review (loaded by coop-harness.js)
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, R, key } = h;
  const K = () => Math.max(1, (+process.env.SIM_LAG || 0) / 150);
  const sleep = (ms) => h.sleep(ms * K());

  // the guest pauses and resumes 8 times: the host must always be playing again afterwards (the guest's menu used to close itself
  // when an older snapshot was shown after the newer pause message, so the next Esc paused again and the host stayed paused)
  S['pause-resume'] = async () => {
    const T = await openPair(); const out = [];
    try {
      await startLevel(T, '1-1'); await sleep(1500);
      let stuck = 0;
      for (let i = 0; i < 8; i++) {
        await key(T.guest, 'Escape', true); await key(T.guest, 'Escape', false); await sleep(600);
        await key(T.guest, 'Escape', true); await key(T.guest, 'Escape', false);
        const t0 = Date.now(); let st = 'paused';
        while (Date.now() - t0 < 1500 * K() + 1000) { st = await T.host.evaluate(() => G.scene.getState()); if (st === 'play') break; await h.sleep(20); }
        out.push(st === 'play' ? (Date.now() - t0) + 'ms' : 'STUCK');
        if (st !== 'play') stuck++;
        await sleep(800);
      }
      return R(stuck === 0, 'host playing again after each guest resume: ' + out.join(', '));
    } finally { await T.close(); }
  };

  // the host pauses while an orb flies at the guest: on the host it hangs still, so on the guest it must hang still and not hurt
  S['pause-proj'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(1200);
      await T.host.evaluate(() => { G.scene.L.ents.length = 0; });
      await sleep(400);
      await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.hp = p.maxHp; });
      await T.host.evaluate(() => { const L = G.scene.L, p = L.p2; window.__q = L.shoot(p.x + 120, p.y + 5, -60, 0, { tile: false, life: 8 }); });
      await sleep(500);
      await key(T.host, 'Escape', true); await key(T.host, 'Escape', false);
      await sleep(400);
      const g0 = await T.guest.evaluate(() => { const q = G.scene.L.projs.find((x) => x.pid && !x.dead); return q ? q.x : null; });
      await h.sleep(3000);
      const g1 = await T.guest.evaluate(() => { const L = G.scene.L, q = L.projs.find((x) => x.pid); return { hp: L.me.hp, max: L.me.maxHp, x: q ? q.x : null, dead: q ? !!q.dead : null }; });
      const ok = g0 !== null && g1.x !== null && !g1.dead && Math.abs(g1.x - g0) < 2 && g1.hp === g1.max;
      return R(ok, 'guest orb x ' + (g0 && g0.toFixed(1)) + ' -> ' + (g1.x && g1.x.toFixed(1)) + ' during 3 s of pause (want still), dead=' + g1.dead + ', guest hp ' + g1.hp + '/' + g1.max);
    } finally { await T.close(); }
  };

  // the line dies without a clean close (the socket still looks open, nothing arrives): the guest notices, reconnects, same level
  S['half-open'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(1500);
      await T.host.evaluate(() => { window.__L0 = G.scene.L; });
      await T.guest.evaluate(() => { window.__GL0 = G.scene.L; const ws = G.coop.ws; ws.onmessage = null; ws.send = () => {}; });
      const t0 = Date.now(); let back = false;
      while (Date.now() - t0 < 15000) { if (await T.guest.evaluate(() => G.coop.open && G.coop.ws && G.coop.ws.onmessage !== null && !G.coop.reconnecting)) { back = true; break; } await h.sleep(200); }
      const tBack = Date.now() - t0;
      await sleep(2000);
      const hs = await T.host.evaluate(() => ({ same: G.scene.L === window.__L0, net: G.scene.L.net, peer: G.coop.peer, lagging: !!(G.scene.L.p2 && G.scene.L.p2.lagging) }));
      const gs = await T.guest.evaluate(() => ({ same: G.scene.L === window.__GL0, net: G.scene.L && G.scene.L.net }));
      return R(back && tBack < 10000 && hs.same && hs.net === 'host' && hs.peer && !hs.lagging && gs.same && gs.net === 'guest', 'guest back after ' + tBack + ' ms (want < 10000); host ' + JSON.stringify(hs) + ' guest ' + JSON.stringify(gs));
    } finally { await T.close(); }
  };

  // the guest kills a bug walking at it with one swipe: the dead bug must not hurt the guest while the host's word is on its way
  S['zombie'] = async () => {
    const env = process.env.SIM_LAG ? {} : { SIM_LAG: '150', SIM_JITTER: '60', SIM_STALL_PCT: '5' };
    const T = await openPair({ env }); const log = []; let hurts = 0, kills = 0;
    try {
      await startLevel(T, '1-1'); await sleep(1200);
      for (let k = 0; k < 6; k++) {
        await T.host.evaluate(() => { const L = G.scene.L; L.ents = L.ents.filter((e) => e.isBoss); });
        await sleep(300);
        const id = await T.host.evaluate(() => {
          const L = G.scene.L, p = L.p2, e = new G.Enemies.Bug(L, 0, 0, false);
          e.x = p.x + 46; e.y = p.y + p.h - e.h; e.face = -1; e.vx = -e.speed; e.onGround = true; e.edgeAhead = () => false;
          L.ents.push(e); G.coop.hostTick(L, 0); window.__bug = e; return e._id;
        });
        await T.guest.waitForFunction((id) => G.scene.L.ents.some((e) => e._id === id), id, { timeout: 8000 });
        await T.guest.evaluate(() => { const p = G.scene.L.me; p.face = 1; p.inv = 0; p.grace = 0; p.hp = p.maxHp; p.vx = 0; });
        await T.guest.waitForFunction((id) => { const L = G.scene.L, p = L.me, e = L.ents.find((x) => x._id === id); return e && e.x - (p.x + p.w) < 12; }, id, { timeout: 5000 }).catch(() => {});
        await key(T.guest, 'KeyX', true); await h.sleep(60); await key(T.guest, 'KeyX', false);
        await sleep(1500);
        const hp = await T.guest.evaluate(() => [G.scene.L.me.hp, G.scene.L.me.maxHp]);
        const dead = await T.host.evaluate(() => !!window.__bug.dead);
        if (dead) kills++; if (hp[0] < hp[1]) hurts++;
        log.push((dead ? 'killed' : 'alive') + (hp[0] < hp[1] ? '+HURT' : ''));
        await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 2; p.hp = p.maxHp; });
        await h.sleep(2200);
      }
      return R(kills === 6 && hurts === 0, 'six swipes at a bug walking in: ' + log.join(', ') + ' (want killed every time, never hurt)');
    } finally { await T.close(); }
  };

  // revive: a fallen player comes back after 6 s if the other one is alive; both screens show a countdown; both down = restart
  S['revive'] = async () => {
    const T = await openPair(); const out = [];
    try {
      await startLevel(T, '1-1'); await sleep(1200);
      // the guest falls
      await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.hp = 1; p.hurt(1, p.x + 30); });
      await sleep(1500);
      const a = await T.host.evaluate(() => { const L = G.scene.L; return { dead: L.p2.dead, left: G.coop.reviveLeft(L, L.p2) }; });
      const b = await T.guest.evaluate(() => { const L = G.scene.L; return { dead: L.me.dead, left: G.coop.reviveLeft(L, L.me) }; });
      await h.sleep(3500);
      const mid = await T.guest.evaluate(() => G.scene.L.me.dead);
      await h.sleep(2200 + 600 * K());
      const c = await T.guest.evaluate(() => ({ dead: G.scene.L.me.dead, hp: G.scene.L.me.hp }));
      out.push('guest down: host countdown ' + (a.left && a.left.toFixed(1)) + ' s, guest countdown ' + (b.left && b.left.toFixed(1)) + ' s; still down at ~5 s=' + mid + '; back after ~7 s=' + !c.dead + ' hp ' + c.hp);
      const ok1 = a.dead && b.dead && a.left > 3.5 && a.left <= 6 && b.left > 3 && b.left <= 6 && mid === true && !c.dead;
      // the host falls: the guest sees the countdown of its partner
      await T.host.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.die(); });
      await sleep(1500);
      const d = await T.guest.evaluate(() => { const L = G.scene.L; return { dead: L.partner.dead, left: G.coop.reviveLeft(L, L.partner) }; });
      await h.sleep(5500);
      const e = await T.host.evaluate(() => !G.scene.L.me.dead);
      out.push('host down: guest sees countdown ' + (d.left && d.left.toFixed(1)) + ' s; host back=' + e);
      const ok2 = d.dead && d.left > 3 && d.left <= 6 && e;
      // both fall: the level restarts
      await T.host.evaluate(() => { window.__L0 = G.scene.L; const p = G.scene.L.me; p.inv = 0; p.die(); });
      await T.guest.evaluate(() => { const p = G.scene.L.me; p.inv = 0; p.die(); });
      let restarted = false; const t0 = Date.now();
      while (Date.now() - t0 < 6000 * K()) { if (await T.host.evaluate(() => G.scene.L !== window.__L0 && !!G.scene.L)) { restarted = true; break; } await h.sleep(100); }
      out.push('both down: level restarted=' + restarted);
      return R(ok1 && ok2 && restarted && T.errs.length === 0, out.join(' | ') + (T.errs.length ? ' ERRORS ' + T.errs.join('; ') : ''));
    } finally { await T.close(); }
  };
};
