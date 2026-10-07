// Phase 1 scenarios (loaded by coop-harness.js)
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, sleep, R, holdKey } = h;

  S['guest-leave'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(800);
      await T.guest.evaluate(() => G.coop.disconnect());
      await T.guest.waitForFunction(() => !G.scene.L && !G.transitioning() && !G.scene.isWait, null, { timeout: 4000 });
      const host = await T.host.evaluate(() => ({ net: G.scene.L.net, p2: !!G.scene.L.p2, peer: G.coop.peer }));
      return R(!host.net && !host.p2 && !host.peer, 'guest on the map; host back to solo: ' + JSON.stringify(host));
    } finally { await T.close(); }
  };

  // guest tab goes to the background for 30 s (no guest updates), then comes back
  S['background'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      await T.guest.evaluate(() => {
        window.__upd = G.scene.update; G.scene.update = () => {};
        Object.defineProperty(document, 'hidden', { get: () => true, configurable: true });
        document.dispatchEvent(new Event('visibilitychange'));
      });
      await sleep(800);
      const away = await T.host.evaluate(() => G.scene.L.p2.away === true);
      await T.host.evaluate(() => { const L = G.scene.L; L.shoot(L.p2.x + 5, L.p2.y + 5, 0, 0, { dmg: 1, life: 0.2, tile: false, cut: false, r: 4 }); });   // would hurt a present P2
      await sleep(29000);
      const hurtWhileAway = await T.host.evaluate(() => G.scene.L.p2.hp < G.scene.L.p2.maxHp);
      await T.guest.evaluate(() => {
        G.scene.update = window.__upd;
        Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
        document.dispatchEvent(new Event('visibilitychange'));
      });
      await sleep(2000);
      const ids = (p) => p.evaluate(() => G.scene.L.ents.filter((e) => !e.dead).map((e) => e._id).sort((a, b) => a - b).join(','));
      const [hi, gi] = [await ids(T.host), await ids(T.guest)];
      // P2 moves on the host again
      const x0 = await T.host.evaluate(() => G.scene.L.p2.x);
      await holdKey(T.guest, 'ArrowRight', 600); await sleep(300);
      const x1 = await T.host.evaluate(() => G.scene.L.p2.x);
      const awayAfter = await T.host.evaluate(() => !!G.scene.L.p2.away);
      // entities near the host are all present on the guest (the host only sends nearby ones)
      const hs = new Set(hi.split(',')), gl = gi.split(',');
      const gOnlyOrSame = gl.every((id) => hs.has(id));
      return R(away && !hurtWhileAway && !awayAfter && Math.abs(x1 - x0) > 20 && gOnlyOrSame, 'away shown=' + away + ' hurtWhileAway=' + hurtWhileAway + ' awayAfter=' + awayAfter + ' p2 moved ' + (x1 - x0).toFixed(0) + 'px; host ents [' + hi + '] guest ents [' + gi + ']');
    } finally { await T.close(); }
  };

  S['pause'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      const st = (p) => p.evaluate(() => G.scene.getState());
      const gx = () => T.guest.evaluate(() => G.scene.L.me.x);
      // host pauses with the keyboard
      await h.key(T.host, 'Escape', true); await h.key(T.host, 'Escape', false);
      await sleep(500);
      const gFrozen = await T.guest.evaluate(() => G.scene.L.me.frozen), gState = await st(T.guest);
      const x0 = await gx(); await h.key(T.guest, 'ArrowRight', true); await sleep(2000); await h.key(T.guest, 'ArrowRight', false);
      const x1 = await gx();
      // the guest resumes with its own pause key (opens its menu, then Esc again)
      await h.key(T.guest, 'Escape', true); await h.key(T.guest, 'Escape', false); await sleep(200);
      await h.key(T.guest, 'Escape', true); await h.key(T.guest, 'Escape', false); await sleep(800);
      const hostAfter = await st(T.host), gFrozen2 = await T.guest.evaluate(() => G.scene.L.me.frozen);
      // the guest pauses for both
      await h.key(T.guest, 'Escape', true); await h.key(T.guest, 'Escape', false); await sleep(600);
      const hostPaused = await st(T.host);
      await h.key(T.guest, 'Escape', true); await h.key(T.guest, 'Escape', false); await sleep(600);
      const hostBack = await st(T.host);
      const ok = gFrozen === true && gState === 'paused' && Math.abs(x1 - x0) < 0.5 && hostAfter === 'play' && gFrozen2 === false && hostPaused === 'paused' && hostBack === 'play';
      return R(ok, 'host pause: guest frozen=' + gFrozen + ' state=' + gState + ', guest moved ' + (x1 - x0).toFixed(1) + 'px; guest resume -> host ' + hostAfter + ', frozen=' + gFrozen2 + '; guest pause -> host ' + hostPaused + ', resume -> ' + hostBack);
    } finally { await T.close(); }
  };

  // the guest dashes into a cracked wall: passes through at once, the host's tile follows
  S['crack-dash'] = async () => {
    const T = await openPair();
    try {
      const ids = await T.host.evaluate(() => Object.keys(G.LEVELS).filter((k) => !G.LEVELS[k].boss && G.LEVELS[k].map.some((r) => r.includes('%'))));
      let spot = null, id = null;
      for (const cand of ids) {
        await startLevel(T, cand); await sleep(600); id = cand;
        spot = await T.guest.evaluate(() => {
          const L = G.scene.L, C = G.TILE.CRACK;
          for (let ty = 1; ty < L.h - 1; ty++) for (let tx = 4; tx < L.w - 3; tx++) {
            if (L.tiles[ty * L.w + tx] !== C) continue;
            const free = [1, 2, 3].every((d) => L.tile(tx - d, ty) === 0 && L.tile(tx - d, ty - 1) === 0);
            if (free && L.solid(tx - 3, ty + 1) && L.solid(tx - 2, ty + 1)) {
              const p = L.me; p.tools.bash = true; p.x = (tx - 3) * 16 + 3; p.y = (ty + 1) * 16 - 10; p.vx = p.vy = 0; p.face = 1;
              return { tx, ty, x: p.x };
            }
          }
          return null;
        });
        if (spot) break;
      }
      if (!spot) return R(false, 'no usable crack in ' + id);
      await sleep(500);
      await h.key(T.guest, 'ArrowRight', true); await h.key(T.guest, 'KeyC', true); await h.key(T.guest, 'KeyC', false);
      await sleep(450); await h.key(T.guest, 'ArrowRight', false);
      const gx = await T.guest.evaluate(() => G.scene.L.me.x);
      let hostOpen = false;
      for (let i = 0; i < 10 && !hostOpen; i++) { hostOpen = await T.host.evaluate((s) => G.scene.L.tiles[s.ty * G.scene.L.w + s.tx] === 0, spot); if (!hostOpen) await sleep(100); }
      return R(gx > (spot.tx + 1) * 16 && hostOpen, id + ': guest x ' + spot.x.toFixed(0) + ' -> ' + gx.toFixed(0) + ' (crack at x=' + spot.tx * 16 + '), host tile open=' + hostOpen);
    } finally { await T.close(); }
  };

  // a rising-liquid level only starts rising for the host's partner too
  S['liquid'] = async () => {
    const T = await openPair();
    try {
      const id = await T.host.evaluate(() => Object.keys(G.LEVELS).find((k) => G.LEVELS[k].rise && !G.LEVELS[k].boss));
      if (!id) return R(false, 'no level with def.rise');
      await startLevel(T, id); await sleep(1200);
      const before = await T.host.evaluate(() => ({ rising: G.scene.L.rising, trig: G.scene.L.rise.trigger, y: G.scene.L.me.y }));
      await T.guest.evaluate(() => { const L = G.scene.L, p = L.me; p.y = L.rise.trigger * 16 - 60; p.vy = 0; });
      await sleep(800);
      const after = await T.host.evaluate(() => ({ rising: G.scene.L.rising, p2y: G.scene.L.p2.y, ly: G.scene.L.liquidY }));
      return R(!before.rising && after.rising, id + ': trigger row ' + before.trig + ', host y ' + before.y.toFixed(0) + ' rising before=' + before.rising + ' after guest climbs=' + after.rising);
    } finally { await T.close(); }
  };
  // loot drops fly to the nearest living player, not always to the host
  S['loot'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(800);
      const far = await T.host.evaluate(() => {
        const L = G.scene.L, p1 = L.me, f = L.findSafe(p1.x + 280, p1.y);
        L.ents.length = 0;
        if (!f || Math.abs(f.x - p1.x) < 150) return null;
        return f;
      });
      if (!far) return R(false, 'could not find a spot far from the host');
      await T.guest.evaluate((f) => { const p = G.scene.L.me; p.x = f.x; p.y = f.y; p.vx = p.vy = 0; }, far);
      await sleep(600);
      // tokens sit 80 px to the partner's left (the host's side) and are already "loose": they must come to the partner
      const r = await T.host.evaluate(() => {
        const L = G.scene.L, p2 = L.p2; L.items.length = 0;
        for (let i = 0; i < 3; i++) L.items.push({ kind: 'token', x: p2.x - 80, y: p2.y - 6, vx: 0, vy: 0, loose: true, t: 0.34, ph: i });
        return { d0: 80 };
      });
      await sleep(330);
      const mid = await T.host.evaluate(() => { const L = G.scene.L, p2 = L.p2; const a = L.items.filter((i) => !i.dead).map((i) => Math.hypot(i.x - p2.x, i.y - p2.y)); return a.length ? a.reduce((x, y) => x + y) / a.length : 0; });
      return R(mid < 80, 'tokens started 80px from the partner (272px from the host); 0.33 s later mean distance to the partner ' + mid.toFixed(0) + 'px (want < 80)');
    } finally { await T.close(); }
  };
};
