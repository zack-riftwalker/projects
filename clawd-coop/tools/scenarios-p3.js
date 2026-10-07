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
};
