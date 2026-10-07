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
};
