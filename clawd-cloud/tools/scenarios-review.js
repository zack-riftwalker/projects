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

  // phone controls with real touch input (CDP touch events in a touch-enabled page): nothing may be lost or stuck
  S['touch'] = async () => {
    const srv = await h.startServer();
    const browser = await h.chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
    const out = []; let ok = true;
    try {
      const ctx = await browser.newContext({ hasTouch: true, isMobile: true, viewport: { width: 780, height: 360 }, deviceScaleFactor: 2 });
      const pg = await ctx.newPage(); const errs = []; pg.on('pageerror', (e) => errs.push(e.message));
      await pg.goto('http://localhost:' + srv.port + '/?mute'); await pg.waitForFunction(() => window.G && G.scene && G.touchPad);
      await pg.evaluate(() => { for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true; G.go(() => G.Scenes.play('1-1', null)); });
      await pg.waitForFunction(() => G.scene.L && !G.transitioning()); await pg.waitForTimeout(800);
      const cdp = await ctx.newCDPSession(pg);
      const T = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
      const ctr = (id) => pg.evaluate((id) => { const r = document.getElementById(id).getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }, id);
      await pg.evaluate(() => { window.__p = {}; const op = G.input.poll; G.input.poll = function () { op.call(this); for (const a in G.input.pressed) if (G.input.pressed[a]) window.__p[a] = (window.__p[a] || 0) + 1; }; });
      const count = (a) => pg.evaluate((a) => window.__p[a] || 0, a);
      const J = await ctr('t-jump'), A = await ctr('t-attack');
      // 1. a tap whose down and up arrive together (the phone was busy for 60 ms): still a jump, and a proper one
      const p0 = await pg.evaluate(() => { const p = G.scene.L.me; p.vy = 0; return p.y; });
      await pg.evaluate(() => setTimeout(() => { const t = performance.now(); while (performance.now() - t < 60); }, 0));
      await T('touchStart', [{ x: J.x, y: J.y, id: 1 }]); await T('touchEnd', []);
      await pg.waitForTimeout(500);
      const j1 = await count('jump'), minY = await pg.evaluate(() => window.__minY);
      out.push('0 ms tap during a hitch -> jumps ' + j1); if (j1 !== 1) ok = false;
      // height of a quick-tap jump vs a held jump
      const hop = async (ms) => { await pg.evaluate(() => { const p = G.scene.L.me; window.__y0 = p.y; window.__top = p.y; window.__hw = setInterval(() => { window.__top = Math.min(window.__top, G.scene.L.me.y); }, 5); }); await T('touchStart', [{ x: J.x, y: J.y, id: 1 }]); await pg.waitForTimeout(ms); await T('touchEnd', []); await pg.waitForTimeout(900); return pg.evaluate(() => { clearInterval(window.__hw); return Math.round(window.__y0 - window.__top); }); };
      const hTap = await hop(0), hHold = await hop(400);
      out.push('jump height: quick tap ' + hTap + ' px, held ' + hHold + ' px'); if (hTap < 12) ok = false;
      // 2. twenty quick taps of 0..40 ms on claw: twenty swipes seen
      const a0 = await count('attack');
      for (let i = 0; i < 20; i++) { await T('touchStart', [{ x: A.x, y: A.y, id: 2 }]); if (i % 2) await pg.waitForTimeout(i * 2); await T('touchEnd', []); await pg.waitForTimeout(260); }
      const a1 = (await count('attack')) - a0; out.push('20 quick claw taps -> ' + a1 + ' seen'); if (a1 !== 20) ok = false;
      // 3. floating stick: its centre is where the thumb lands; a push right walks right; letting go stops
      const s1 = { x: 230, y: 230 }, s2 = { x: 120, y: 150 };
      await T('touchStart', [{ x: s1.x, y: s1.y, id: 3 }]); await T('touchMove', [{ x: s1.x + 30, y: s1.y, id: 3 }]); await pg.waitForTimeout(120);
      const st1 = await pg.evaluate(() => ({ right: G.input.down.right, left: G.input.down.left, down: G.input.down.down, tr: document.getElementById('stick').style.transform }));
      // 4. two fingers: stick right held + tap jump
      const j2 = await count('jump');
      await T('touchMove', [{ x: s1.x + 30, y: s1.y, id: 3 }, { x: J.x, y: J.y, id: 4 }]); await pg.waitForTimeout(150);
      const both = await pg.evaluate(() => G.input.down.right && G.input.down.jump);
      await T('touchMove', [{ x: s1.x + 30, y: s1.y, id: 3 }]); await pg.waitForTimeout(150);      // (finger 4 lifted)
      await T('touchEnd', []); await pg.waitForTimeout(150);
      const st2 = await pg.evaluate(() => ({ right: G.input.down.right, jump: G.input.down.jump }));
      await T('touchStart', [{ x: s2.x, y: s2.y, id: 5 }]); await T('touchMove', [{ x: s2.x - 30, y: s2.y, id: 5 }]); await pg.waitForTimeout(120);
      const st3 = await pg.evaluate(() => ({ left: G.input.down.left, tr: document.getElementById('stick').style.transform }));
      await T('touchEnd', []); await pg.waitForTimeout(100);
      out.push('stick at ' + s1.x + ',' + s1.y + ': right=' + st1.right + ' (no duck=' + !st1.down + ') | +jump with 2nd finger: both=' + both + ' | released: right=' + st2.right + ' jump=' + st2.jump + ' | new spot ' + s2.x + ',' + s2.y + ': left=' + st3.left + ', base moved=' + (st3.tr !== st1.tr));
      if (!st1.right || st1.left || st1.down || !both || st2.right || st2.jump || !st3.left || st3.tr === st1.tr || (await count('jump')) !== j2 + 1) ok = false;
      // 5. slide from claw to jump without lifting: jump gets pressed, claw lets go
      const j3 = await count('jump');
      await T('touchStart', [{ x: A.x, y: A.y, id: 6 }]); await pg.waitForTimeout(120);
      for (let i = 1; i <= 5; i++) await T('touchMove', [{ x: A.x + (J.x - A.x) * i / 5, y: A.y + (J.y - A.y) * i / 5, id: 6 }]);
      await pg.waitForTimeout(150);
      const sl = await pg.evaluate(() => ({ jump: G.input.down.jump, attack: G.input.down.attack }));
      await T('touchEnd', []); await pg.waitForTimeout(200);
      const sl2 = await pg.evaluate(() => ({ jump: G.input.down.jump, attack: G.input.down.attack }));
      out.push('slide claw->jump: jump=' + sl.jump + ' claw=' + sl.attack + ', after lift jump=' + sl2.jump + ' claw=' + sl2.attack);
      if (!sl.jump || sl.attack || sl2.jump || sl2.attack || (await count('jump')) !== j3 + 1) ok = false;
      // 6. layout: buttons do not overlap each other, all on screen, the 2P button stays tappable
      const lay = await pg.evaluate(() => { const r = Array.from(document.querySelectorAll('.tb')).map((e) => e.getBoundingClientRect()); let ov = 0; for (let i = 0; i < r.length; i++) for (let j = i + 1; j < r.length; j++) if (!(r[i].right <= r[j].left || r[j].right <= r[i].left || r[i].bottom <= r[j].top || r[j].bottom <= r[i].top)) ov++; const off = r.filter((b) => b.left < 0 || b.top < 0 || b.right > innerWidth || b.bottom > innerHeight).length; const top = document.elementFromPoint(innerWidth / 2, 14); return { ov, off, coop: !!(top && top.id === 'coopBtn') }; });
      out.push('layout: overlapping buttons ' + lay.ov + ', off-screen ' + lay.off + ', 2P button reachable ' + lay.coop); if (lay.ov || lay.off || !lay.coop) ok = false;
      await pg.screenshot({ path: require('path').join(h.ROOT, 'reports', 'touch-landscape.png') });
      await pg.setViewportSize({ width: 360, height: 760 }); await pg.waitForTimeout(500);
      await pg.screenshot({ path: require('path').join(h.ROOT, 'reports', 'touch-portrait.png') });
      const lay2 = await pg.evaluate(() => { const r = Array.from(document.querySelectorAll('.tb')).map((e) => e.getBoundingClientRect()); let ov = 0; for (let i = 0; i < r.length; i++) for (let j = i + 1; j < r.length; j++) if (!(r[i].right <= r[j].left || r[j].right <= r[i].left || r[i].bottom <= r[j].top || r[j].bottom <= r[i].top)) ov++; return { ov, off: r.filter((b) => b.left < 0 || b.top < 0 || b.right > innerWidth || b.bottom > innerHeight).length }; });
      out.push('portrait: overlapping ' + lay2.ov + ', off-screen ' + lay2.off); if (lay2.ov || lay2.off) ok = false;
      if (errs.length) { ok = false; out.push('ERRORS ' + errs.join('; ')); }
      return R(ok, out.join(' | '));
    } finally { await browser.close(); await srv.stop(); }
  };
};
