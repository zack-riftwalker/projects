// Relay scenarios: host reconnect, host grace, new code (both relays); host key and a restart of the Durable Object (TARGET=cloud only);
// the host-only-on-its-own-PC rule (local relay only). Loaded by coop-harness.js.
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, R, key, wsTry } = h;
  const K = () => Math.max(1, (+process.env.SIM_LAG || 0) / 150);
  const sleep = (ms) => h.sleep(ms * K());
  const until = async (p, fn, arg, ms) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { if (await p.evaluate(fn, arg)) return Date.now() - t0; await h.sleep(50); } return -1; };

  // the host key: wrong key 4003, five wrong keys lock the address out (4005, even for the right key), no key configured = nobody may host
  if (h.CLOUD) S['host-key'] = async () => {
    const srv = await h.startServer(), srv2 = await h.startServer({ HOST_KEY: '' });
    try {
      const ok0 = await wsTry(srv.port, 'role=host&key=test', { hold: 300 });
      await ok0.ws.close(); await h.sleep(300);
      const bad = await wsTry(srv.port, 'role=host&key=nope');
      const none = await wsTry(srv.port, 'role=host');
      const more = []; for (let i = 0; i < 3; i++) more.push((await wsTry(srv.port, 'role=host&key=wrong' + i)).code);       // 5 failures in total (bad, none, 3 more)
      const locked = await wsTry(srv.port, 'role=host&key=test');
      const guestLocked = await wsTry(srv.port, 'role=guest&code=' + h.CODE);
      const e1 = await wsTry(srv2.port, 'role=host&key=test'), e2 = await wsTry(srv2.port, 'role=host&key='), e3 = await wsTry(srv2.port, 'role=host');
      const ok = ok0.code === 'open' && ok0.msgs.some((m) => /"t":"code","v":"123456"/.test(m)) && bad.code === 4003 && none.code === 4003 && more.every((c) => c === 4003) && locked.code === 4005 && guestLocked.code === 4005 && [e1, e2, e3].every((x) => x.code === 4003);
      return R(ok, 'right key -> ' + ok0.code + ' (+code msg); wrong ' + bad.code + ',' + none.code + ',' + more.join(',') + '; sixth try with the right key -> ' + locked.code + ' (want 4005), guest from the same address ' + guestLocked.code + '; empty HOST_KEY -> ' + [e1, e2, e3].map((x) => x.code).join(','));
    } finally { await srv.stop(); await srv2.stop(); }
  };

  // the host's line blips mid-boss: it comes back by itself, same level, same partner, same fight, nothing restarted
  S['host-blip'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '3-B'); await sleep(3500);
      await h.godmode(T);
      await T.host.evaluate(() => { window.__L0 = G.scene.L; window.__P0 = G.scene.L.p2; });
      await T.guest.evaluate(() => { window.__GL0 = G.scene.L; });
      const t0 = Date.now();
      await T.host.evaluate(() => G.coop.ws.close());
      await T.guest.evaluate(() => { G.coop.testLog = []; });
      await T.host.evaluate(() => { G.coop.rel('test', { n: 9 }); });         // raised during the outage: must still arrive
      let back = false;
      while (Date.now() - t0 < 6000 * K()) { if (await T.host.evaluate(() => G.coop.open && !G.coop.reconnecting && G.coop.peer)) { back = true; break; } await h.sleep(50); }
      const tBack = Date.now() - t0;
      await sleep(2500);
      const host = await T.host.evaluate(() => ({ same: G.scene.L === window.__L0 && G.scene.L.p2 === window.__P0, net: G.scene.L.net, peer: G.coop.peer, lag: !!G.scene.L.p2.lagging, boss: G.scene.L.boss.hp }));
      const guest = await T.guest.evaluate(() => ({ same: G.scene.L === window.__GL0, net: G.scene.L.net, fight: G.scene.L.boss.active, hp: G.scene.L.boss.hp, ev: G.coop.testLog.slice(), lag: !!G.coop.hostLag, fresh: performance.now() - G.coop.latestAt }));
      const ok = back && tBack < 3000 * K() && host.same && host.net === 'host' && host.peer && !host.lag && guest.same && guest.net === 'guest' && guest.fight && !guest.lag && guest.ev.includes(9) && Math.abs(guest.hp - host.boss) < 0.01 && guest.fresh < 1500;
      return R(ok, 'host back after ' + tBack + ' ms (want < ' + 3000 * K() + '); host same level+partner=' + host.same + ' peer=' + host.peer + ' lagging=' + host.lag + '; guest same level=' + guest.same + ' fight on=' + guest.fight + ' hostLag cleared=' + !guest.lag + '; event raised during outage arrived=' + guest.ev.includes(9) + '; boss hp host ' + host.boss + ' guest ' + guest.hp + '; snapshots flowing again=' + (guest.fresh < 1500));
    } finally { await T.close(); }
  };

  // the host line goes silent (socket looks open, nothing moves): the page notices after 6 s, reconnects, nothing restarts
  S['host-half-open'] = async () => {
    const T = await openPair();
    try {
      await startLevel(T, '1-1'); await sleep(1500);
      await T.host.evaluate(() => { window.__L0 = G.scene.L; window.__P0 = G.scene.L.p2; const ws = G.coop.ws; window.__ws0 = ws; ws.onmessage = null; ws.send = () => {}; });
      await T.guest.evaluate(() => { window.__GL0 = G.scene.L; });
      const t0 = Date.now(); let back = false;
      while (Date.now() - t0 < 16000) { if (await T.host.evaluate(() => G.coop.ws !== window.__ws0 && G.coop.open && !G.coop.reconnecting && G.coop.peer)) { back = true; break; } await h.sleep(200); }
      const tBack = Date.now() - t0;
      await sleep(1500);
      const hs = await T.host.evaluate(() => ({ same: G.scene.L === window.__L0 && G.scene.L.p2 === window.__P0, net: G.scene.L.net, lag: !!G.scene.L.p2.lagging }));
      const gs = await T.guest.evaluate(() => ({ same: G.scene.L === window.__GL0, net: G.scene.L && G.scene.L.net, hostOn: G.coop.hostOn }));
      return R(back && tBack < 12000 && hs.same && hs.net === 'host' && !hs.lag && gs.same && gs.net === 'guest' && gs.hostOn, 'host back after ' + tBack + ' ms (want < 12000); host ' + JSON.stringify(hs) + ' guest ' + JSON.stringify(gs));
    } finally { await T.close(); }
  };

  // the host disappears for good: the guest sees "host reconnecting" at once and lands on the wait scene after the grace time (2 s here)
  S['host-grace'] = async () => {
    const T = await openPair({ env: { GRACE_MS: '2000' } });
    try {
      await startLevel(T, '1-1'); await sleep(1000);
      await T.host.close();
      const tLag = await until(T.guest, () => G.coop.hostLag === true && !!G.scene.L && G.scene.L.net === 'guest' && G.scene.L.partner.lagging === true, null, 1000 * K() + 300);
      const during = await T.guest.evaluate(() => ({ level: !!G.scene.L, wait: !!G.scene.isWait }));
      const tWait = await until(T.guest, () => !G.scene.L && !G.transitioning(), null, 5000 * K());
      const after = await T.guest.evaluate(() => ({ wait: !!G.scene.isWait, hostOn: G.coop.hostOn, lag: G.coop.hostLag, open: G.coop.open }));
      return R(tLag >= 0 && during.level && tWait >= 0 && after.wait && !after.hostOn && after.open, 'guest saw "host reconnecting" after ' + tLag + ' ms (want < ' + (1000 * K() + 300) + ') and kept its level (' + during.level + '); wait scene after ' + tWait + ' ms: ' + JSON.stringify(after));
    } finally { await T.close(); }
  };

  // "new code" from the host: the guest is let go with 4001, the old code is dead, the new one works
  S['new-code'] = async () => {
    const T = await openPair({ env: { CODE: null }, connect: false });
    try {
      await T.host.evaluate(() => G.coop.connect('host', 'test')); await T.host.waitForFunction(() => G.coop.open && G.coop.code);
      const c1 = await T.host.evaluate(() => G.coop.code);
      await T.guest.evaluate((c) => G.coop.connect('guest', c), c1); await T.guest.waitForFunction(() => G.coop.open); await T.host.waitForFunction(() => G.coop.peer);
      await T.host.evaluate(() => G.coop.send({ t: 'newcode' }));
      const t = await until(T.guest, () => !G.coop.open && G.coop.status === 'wrong code', null, 3000 * K());
      await T.host.waitForFunction((c) => G.coop.code && G.coop.code !== c, c1, { timeout: 3000 });
      const c2 = await T.host.evaluate(() => G.coop.code), hostPeer = await T.host.evaluate(() => G.coop.peer);
      const old = await wsTry(T.srv.port, 'role=guest&code=' + c1), fresh = await wsTry(T.srv.port, 'role=guest&code=' + c2, { hold: 300 });
      return R(t >= 0 && c1 !== c2 && /^\d{6}$/.test(c2) && !hostPeer && old.code === 4001 && fresh.code === 'open', 'code ' + c1 + ' -> ' + c2 + '; guest kicked (4001) after ' + t + ' ms; host peer=' + hostPeer + '; old code ' + old.code + ', new code ' + fresh.code);
    } finally { await T.close(); }
  };

  // the Durable Object restarts (wrangler dev killed and started again on the same --persist-to): code and token survive, both pages come back alone
  if (h.CLOUD) S['restart'] = async () => {
    const T = await openPair({ env: { CODE: null }, connect: false });
    try {
      await T.host.evaluate(() => G.coop.connect('host', 'test')); await T.host.waitForFunction(() => G.coop.open && G.coop.code);
      const c1 = await T.host.evaluate(() => G.coop.code);
      await T.guest.evaluate((c) => G.coop.connect('guest', c), c1); await T.guest.waitForFunction(() => G.coop.open && G.coop.token); await T.host.waitForFunction(() => G.coop.peer);
      await startLevel(T, '1-1'); await sleep(1500);
      await T.host.evaluate(() => { window.__L0 = G.scene.L; window.__P0 = G.scene.L.p2; });
      await T.guest.evaluate(() => { window.__GL0 = G.scene.L; window.__tok = G.coop.token; });
      const t0 = Date.now();
      await T.srv.restart();
      const tH = await until(T.host, () => G.coop.open && !G.coop.reconnecting && G.coop.peer, null, 20000);
      const tG = await until(T.guest, () => G.coop.open && !G.coop.reconnecting, null, 20000);
      await sleep(2500);
      const hs = await T.host.evaluate(() => ({ code: G.coop.code, same: G.scene.L === window.__L0 && G.scene.L.p2 === window.__P0, net: G.scene.L.net, peer: G.coop.peer }));
      const gs = await T.guest.evaluate(() => ({ same: G.scene.L === window.__GL0, net: G.scene.L && G.scene.L.net, tok: G.coop.token === window.__tok, fresh: performance.now() - G.coop.latestAt }));
      const ok = tH >= 0 && tG >= 0 && hs.code === c1 && hs.same && hs.net === 'host' && hs.peer && gs.same && gs.net === 'guest' && gs.tok && gs.fresh < 1500;
      return R(ok, 'after the restart: host back ' + tH + ' ms, guest back ' + tG + ' ms (total ' + (Date.now() - t0) + ', want each < 20000); code ' + c1 + ' -> ' + hs.code + '; host ' + JSON.stringify(hs) + ' guest ' + JSON.stringify(gs));
    } finally { await T.close(); }
  };

  // local relay: only the PC running server.js may host (no key needed there); a host through a tunnel / port forward is refused with 4004
  if (!h.CLOUD) S['host-local'] = async () => {
    const srv = await h.startServer();
    const WebSocket = h.createRequire(require('path').join(h.ROOT, 'x.js'))('ws');
    const viaProxy = (q) => new Promise((res) => { const ws = new WebSocket('ws://127.0.0.1:' + srv.port + '/ws?' + q, { headers: { 'X-Forwarded-For': '1.2.3.4' } }); ws.on('close', (c) => res(c)); ws.on('open', () => setTimeout(() => ws.close(), 300)); ws.on('error', () => {}); setTimeout(() => res('timeout'), 3000); });
    try {
      const own = await wsTry(srv.port, 'role=host', { hold: 300 });
      own.ws.close(4010); await h.sleep(300);
      const remote = await viaProxy('role=host&key=anything'), friend = await viaProxy('role=guest&code=' + h.CODE);
      const ok = own.code === 'open' && own.msgs.some((m) => /"t":"code","v":"123456"/.test(m)) && remote === 4004 && friend === 1005;
      return R(ok, 'host on its own PC -> ' + own.code + ' (+code msg); host from outside -> ' + remote + ' (want 4004); friend from outside -> ' + friend + ' (closed normally = joined)');
    } finally { await srv.stop(); }
  };
};
