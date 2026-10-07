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
};
