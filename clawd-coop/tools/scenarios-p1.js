// Phase 1 scenarios (loaded by coop-harness.js)
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, sleep, R } = h;

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
};
