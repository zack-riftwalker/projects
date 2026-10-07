// Phase 2 scenarios: difficulty settings (loaded by coop-harness.js)
'use strict';
module.exports = (S, h) => {
  const { openPair, startLevel, sleep, R } = h;
  // one solo page (no co-op connection)
  const solo = async (opt, id) => {
    const T = await openPair({ connect: false });
    await T.host.evaluate(([o, id]) => { Object.assign(G.save.data.opt, o); for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true; G.go(() => G.Scenes.play(id, null)); }, [opt, id]);
    await T.host.waitForFunction((id) => G.scene.L && G.scene.L.id === id && !G.transitioning(), id);
    await sleep(300);
    return T;
  };

  S['diff-solo'] = async () => {
    const T = await solo({ npcExtra: 1, diffPreset: 'custom' }, '1-1');
    try {
      const r = await T.host.evaluate(() => {
        const L = G.scene.L, p = L.me; L.ents.length = 0;
        const mk = () => { const e = new G.Enemies.Bug(L, p.x + 40, p.y, false); e.update = () => {}; L.ents.push(e); return e; };
        const a = mk(); L.update(1 / 60);                      // scaled at the start of the update
        const out = { hp: a.hp, scaled: !!a._scaled };
        a.hit(1, 1, 0, 'swipe'); out.afterClaw1 = !a.dead; a.hit(1, 1, 0, 'swipe'); out.afterClaw2 = a.dead;
        const b = mk(); L.update(1 / 60); b.x = p.x; b.y = p.y + 8; b.vx = 0;         // stomp: player lands on top
        p.x = b.x + 1; p.y = b.y - p.h + 2; p.vy = 120; p.prevBottom = b.y - 1; p.grace = 0; p.inv = 0;
        L.interact(1 / 60); out.stompKills = b.dead; out.hpB = b.hp;
        return out;
      });
      return R(r.hp === 2 && r.afterClaw1 && r.afterClaw2 && r.stompKills, 'bug hp ' + r.hp + ' (want 2); dead after 1st claw hit: ' + !r.afterClaw1 + ', after 2nd: ' + r.afterClaw2 + '; one stomp kills: ' + r.stompKills);
    } finally { await T.close(); }
  };
  S['diff-boss'] = async () => {
    const T = await solo({ bossPct: 50, diffPreset: 'custom' }, '1-B');
    try {
      const r = await T.host.evaluate(() => { const b = G.scene.L.boss; return { hp: b.hp, max: b.maxHp, drop: b.dropN }; });
      return R(r.max === 39 && r.hp === 39 && r.drop === 36, 'boss 1-B hp ' + r.hp + '/' + r.max + ' (want 39, 26 x 1.5), death drop ' + r.drop + ' tokens (want 36)');
    } finally { await T.close(); }
  };
  S['diff-merge'] = async () => {
    const T = await solo({ bossPct: 100, diffPreset: 'custom' }, '2-B');
    try {
      const r = await T.host.evaluate(() => {
        const L = G.scene.L, b = L.boss, o = { heads: b.heads.map((x) => x.hp), hp: b.hp, max: b.maxHp };
        b.start(); L.me.frozen = false;
        const hd = b.heads[0]; b.hit(28, 1, 0, 'swipe', { x: hd.x, y: hd.y, w: 28, h: 24, head: hd });
        o.phase = b.phase; o.dying = b.dying; o.hpAfter = b.hp; o.alone = !!b.alone;
        return o;
      });
      return R(r.heads[0] === 28 && r.heads[1] === 28 && r.hp === 56 && r.max === 56 && r.phase === 2 && !r.dying && r.hpAfter === 28, 'heads ' + r.heads + ', boss ' + r.hp + '/' + r.max + '; after one head dies: phase ' + r.phase + ', boss hp ' + r.hpAfter + ', dying=' + r.dying);
    } finally { await T.close(); }
  };
  S['diff-loot'] = async () => {
    const T = await solo({ npcExtra: 2, diffPreset: 'custom' }, '1-1');
    try {
      const r = await T.host.evaluate(() => {
        const L = G.scene.L, p = L.me; L.ents.length = 0; L.items = L.items.filter((i) => false);
        const e = new G.Enemies.Bug(L, p.x + 60, p.y, false); e.update = () => {}; L.ents.push(e); L.update(1 / 60);
        const o = { hp: e.hp, loot: e.loot }; e.hit(99, 1, 0, 'swipe');
        o.tokens = L.items.filter((i) => i.kind === 'token' && i.loose).length;
        return o;
      });
      return R(r.hp === 3 && r.tokens === 3, 'bug hp ' + r.hp + ' (want 3), dropped ' + r.tokens + ' tokens (want 3)');
    } finally { await T.close(); }
  };
  S['diff-coop'] = async () => {
    const T = await openPair();
    try {
      await T.host.evaluate(() => { const d = G.save.data.coopDiff; Object.assign(d, { preset: 'custom', bossPct: 50, npcExtra: 1, npcMult: 100 }); });
      await startLevel(T, '1-B'); await sleep(2500);
      const hb = await T.host.evaluate(() => ({ max: G.scene.L.boss.maxHp, hp: G.scene.L.boss.hp })), gb = await T.guest.evaluate(() => ({ max: G.scene.L.boss.maxHp, hp: G.scene.L.boss.hp, line: G.coop.diffLine }));
      // a creature spawned at run time is scaled exactly once
      const sl = await T.host.evaluate(() => { const L = G.scene.L; const s = new G.Enemies.Slime(L, L.me.x + 40, L.me.y - 20, true); L.ents.push(s); const base = 1; return { id: L.ents.length - 1, s: s }; }).catch(() => null);
      await sleep(300);
      const r = await T.host.evaluate(() => { const L = G.scene.L; const sl = L.ents.filter((e) => e instanceof G.Enemies.Slime); return sl.map((e) => [e.hp, !!e._scaled]); });
      await sleep(500);
      const r2 = await T.host.evaluate(() => { const L = G.scene.L; return L.ents.filter((e) => e instanceof G.Enemies.Slime).map((e) => [e.hp, !!e._scaled]); });
      return R(hb.max === 39 && gb.max === 39 && /BOSS \+50%/.test(gb.line) && r.length && r.every((x) => x[0] === 2 && x[1]) && JSON.stringify(r) === JSON.stringify(r2), 'host boss ' + hb.max + ', guest boss bar ' + gb.max + ' (want 39), guest sees "' + gb.line + '"; runtime small slime hp ' + JSON.stringify(r) + ' then ' + JSON.stringify(r2) + ' (want [[2,true]] both times)');
    } finally { await T.close(); }
  };

  // LOCK=1: the server's numbers win and the host UI is disabled; /config is local only
  S['diff-lock'] = async () => {
    const T = await openPair({ env: { BOSS_HP: '100', NPC_HITS: '2', NPC_MULT: '150', LOCK: '1' } });
    try {
      await sleep(600);
      await T.host.evaluate(() => Object.assign(G.save.data.coopDiff, { bossPct: 0, npcExtra: 0, npcMult: 100, preset: 'normal' }));
      await startLevel(T, '1-B'); await sleep(1500);
      const hb = await T.host.evaluate(() => ({ max: G.scene.L.boss.maxHp, line: G.coop.diffLine }));
      await T.host.click('#coopBtn');
      const dis = await T.host.evaluate(() => document.querySelector('#cB').disabled && document.querySelector('#cPre').disabled);
      const remote = await h.rawReq(T.srv.port, 'GET /config HTTP/1.1\r\nX-Forwarded-For: 1.2.3.4');
      return R(hb.max === 52 && dis && /BOSS \+100%/.test(hb.line) && /403/.test(remote), 'locked boss maxHp ' + hb.max + ' (want 52), line "' + hb.line + '", inputs disabled=' + dis + ', /config via tunnel header -> ' + (remote.split('\r\n')[0]));
    } finally { await T.close(); }
  };
};
