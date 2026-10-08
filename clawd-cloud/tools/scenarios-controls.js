// Controls scenarios (key remapping), loaded by coop-harness.js. Solo only: nothing here touches the network.
'use strict';
module.exports = (S, h) => {
  const { startServer, openPage, chromium, R } = h;
  // a solo page in manual mode; fn(page, errs) runs the checks
  const solo = async (fn) => {
    const srv = await startServer();
    const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
    const errs = [];
    try {
      const page = await openPage(browser, 'http://127.0.0.1:' + srv.port + '/?mute&manual', errs, 'solo');
      const r = await fn(page, srv);
      if (errs.length) return R(false, r.info + '; page errors: ' + errs.slice(0, 3).join(' | '));
      return r;
    } finally { await browser.close(); await srv.stop(); }
  };
  const press = (page, code) => page.evaluate((c) => { window.dispatchEvent(new KeyboardEvent('keydown', { code: c, bubbles: true, cancelable: true })); const I = G.input; I.poll(); const r = { ...I.pressed }; window.dispatchEvent(new KeyboardEvent('keyup', { code: c, bubbles: true })); I.poll(); return r; }, code);

  S['keys-remap'] = () => solo(async (page, srv) => {
    const before = await press(page, 'KeyZ');
    await page.evaluate(() => { G.save.data.keys = G.input.defaultKeys(); G.save.data.keys.jump = ['KeyQ', null]; G.save.write(); G.input.rebuild(); });
    const q = await press(page, 'KeyQ'), z = await press(page, 'KeyZ'), sp = await press(page, 'Space');
    const reserved = await page.evaluate(() => { G.save.data.keys.attack = ['KeyF', 'KeyM']; G.input.rebuild(); return G.input.binds.attack.join(',') + '|' + G.actionLabel('attack'); });
    await page.evaluate(() => { G.save.data.keys.attack = ['KeyX', 'KeyJ']; G.save.write(); G.input.rebuild(); });
    await page.reload(); await page.waitForFunction(() => window.G && G.scene);
    const after = await page.evaluate(() => ({ keys: G.save.data.keys && G.save.data.keys.jump, lbl: G.actionLabel('jump'), both: G.actionLabel('dash', true), arrow: G.keyLabel('ArrowLeft'), digit: G.keyLabel('Digit1') }));
    const q2 = await press(page, 'KeyQ'), z2 = await press(page, 'KeyZ');
    // erase save keeps the bindings
    const kept = await page.evaluate(() => { G.save.reset(); return G.save.data.keys && G.save.data.keys.jump[0]; });
    const ok = before.jump && q.jump && !z.jump && !sp.jump && reserved === ',|?' && after.keys[0] === 'KeyQ' && after.lbl === 'Q' && after.both === 'C/SHIFT' && after.arrow === 'LEFT' && after.digit === '1' && q2.jump && !z2.jump && kept === 'KeyQ';
    return R(ok, JSON.stringify({ before: before.jump, q: q.jump, z: z.jump, sp: sp.jump, reserved, after, q2: q2.jump, z2: z2.jump, kept }));
  });

  // real key events + manual steps
  const tap = (page, code) => page.evaluate((c) => { const k = (t) => window.dispatchEvent(new KeyboardEvent(t, { code: c, bubbles: true, cancelable: true })); k('keydown'); G.step(2, true); k('keyup'); G.step(2, true); }, code);
  const taps = async (page, code, n) => { for (let i = 0; i < n; i++) await tap(page, code); };
  const binds = (page) => page.evaluate(() => JSON.parse(JSON.stringify(G.input.binds)));
  const shot = async (page, name) => {
    if (!process.env.SHOTS) return;
    await page.evaluate(() => G.render()); await page.screenshot({ path: require('path').join(process.env.SHOTS, name) });
  };

  S['keys-screen'] = () => solo(async (page) => {
    const D = await page.evaluate(() => G.input.defaultKeys());
    await page.evaluate(() => { G.save.data.started = false; G.setScene(G.Scenes.title(true)); G.step(200, true); });
    await tap(page, 'Enter');                    // "press any key" -> menu
    await page.evaluate(() => G.step(200, true));
    await tap(page, 'ArrowDown'); await tap(page, 'Enter');            // new game / options -> options
    await taps(page, 'ArrowDown', 10); await shot(page, 'options.png'); await tap(page, 'Enter');   // controls row
    const out = {};
    await taps(page, 'ArrowDown', 4); await tap(page, 'Enter');       // jump row, capture
    await page.evaluate(() => G.render()); await shot(page, 'controls-capture.png');
    await tap(page, 'Escape'); out.cancel = (await binds(page)).jump[0] === 'KeyZ' && !(await page.evaluate(() => !!G.input.capture));
    await tap(page, 'Enter'); await tap(page, 'KeyX');                 // jump -> X: swaps, attack gets Z
    let b = await binds(page); out.swap = b.jump[0] === 'KeyX' && b.attack[0] === 'KeyZ';
    await tap(page, 'ArrowDown'); await tap(page, 'Enter'); await tap(page, 'KeyQ');   // attack (row 5) -> Q
    b = await binds(page); out.q = b.attack[0] === 'KeyQ' && b.jump[0] === 'KeyX';
    out.saved = await page.evaluate(() => G.save.data.keys && G.save.data.keys.attack[0]) === 'KeyQ';
    // the game itself follows
    const pq = await press(page, 'KeyQ'), pz = await press(page, 'KeyZ'); out.live = pq.attack && !pz.attack && !pz.jump;
    // reserved key refused, clearing: slot 2 ok, the last key of a needed action is not
    await tap(page, 'Enter'); await tap(page, 'KeyF'); out.reserved = (await binds(page)).attack[0] === 'KeyQ';
    await taps(page, 'ArrowUp', 5);                                    // left row
    await tap(page, 'ArrowRight'); await tap(page, 'Enter'); await tap(page, 'Backspace');
    b = await binds(page); out.clear2 = b.left[1] === null && b.left[0] === 'ArrowLeft';
    await tap(page, 'ArrowLeft'); await tap(page, 'Enter'); await tap(page, 'Backspace');
    b = await binds(page); out.keepLast = b.left[0] === 'ArrowLeft';
    await shot(page, 'controls.png');
    await taps(page, 'ArrowUp', 1); await taps(page, 'ArrowDown', 11);  // wraps to "reset to defaults" (row 10)
    await tap(page, 'Enter');
    b = await binds(page); out.reset = JSON.stringify(b) === JSON.stringify(D) && (await page.evaluate(() => G.save.data.keys)) === null;
    const ok = Object.values(out).every(Boolean);
    return R(ok, JSON.stringify(out));
  });

  S['keys-pad'] = () => solo(async (page) => {
    await page.evaluate(() => {
      window.__btn = new Set();
      navigator.getGamepads = () => [{ connected: true, axes: [0, 0], buttons: Array.from({ length: 17 }, (_, i) => ({ pressed: window.__btn.has(i) })) }];
      window.dispatchEvent(new Event('gamepadconnected'));
      G.save.data.started = false; G.setScene(G.Scenes.title(true)); G.step(200, true);
    });
    await tap(page, 'Enter'); await page.evaluate(() => G.step(200, true));
    await tap(page, 'ArrowDown'); await tap(page, 'Enter'); await taps(page, 'ArrowDown', 10); await tap(page, 'Enter');
    const out = {}, step = (n) => page.evaluate((n) => G.step(n, true), n), btn = (i, on) => page.evaluate(([i, on]) => { on ? window.__btn.add(i) : window.__btn.delete(i); }, [i, on]);
    const jumpDown = async () => { await step(2); return page.evaluate(() => G.input.down.jump); };
    await taps(page, 'ArrowDown', 4); await taps(page, 'ArrowRight', 2);   // jump row, pad slot
    await btn(0, true); await tap(page, 'Enter'); await step(3);              // A is held when the capture starts: it must be ignored
    out.heldIgnored = await page.evaluate(() => !!G.input.capture) && (await page.evaluate(() => G.input.padBinds.jump.join())) === '0';
    await btn(6, true); await step(3);                                         // the next fresh press: button 6
    out.bound = await page.evaluate(() => G.input.padBinds.jump.join() + '|' + G.save.data.keys.pad.jump.join());
    out.swallowed = !(await page.evaluate(() => !!G.input.capture));        // capture ended, and the button held down did not re-open it
    out.six = await jumpDown();
    await btn(6, false); out.up = !(await jumpDown());
    await btn(0, true); out.oldA = !(await jumpDown()); await btn(0, false);
    out.dashKept = await page.evaluate(() => G.input.padBinds.dash.join());
    out.ok = out.heldIgnored && out.bound === '6|6' && out.six === true && out.up === true && out.oldA === true && out.dashKept === '1,5,7';
    return R(out.ok, JSON.stringify(out));
  });

  S['keys-hints'] = () => solo(async (page) => {
    // static: no hard-coded key names left in sign strings / tool cards
    const fs = require('fs'), pa = require('path'), f = [pa.join(h.ROOT, 'public', 'index.html'), pa.join(h.ROOT, 'index.html')].find((x) => fs.existsSync(x)), html = fs.readFileSync(f, 'utf8');
    const stale = (html.match(/\[(Z|X|C|V|DOWN|ARROWS|SPACE)\]/g) || []).length;
    const out = { stale: stale === 0 };
    const caps = () => page.evaluate(() => { const l = window.__caps; window.__caps = []; return l; });
    await page.evaluate(() => {
      window.__caps = []; const kc = G.keycap; G.keycap = (...a) => { window.__caps.push(a[3]); return kc(...a); };
      for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true;
      G.save.data.keys = G.input.defaultKeys(); G.save.data.keys.jump = ['KeyQ', null]; G.save.data.keys.pause = ['KeyP', null]; G.input.rebuild();
      G.setScene(G.Scenes.play('1-1', null)); G.step(30, true);
      const L = G.scene.L, sg = L.signs[0]; L.me.x = sg.x - L.me.w / 2; L.me.y = sg.y - L.me.h; G.step(3, true); G.render();
    });
    const a = await caps();
    out.sign = a.includes('Q') && a.includes('ARROWS') && !a.includes('Z') && !a.includes('SPACE');
    await page.evaluate(() => { G.input.rebuild(); G.setScene(G.Scenes.map()); G.step(60, true); G.render(); });
    const b = await caps(); out.map = b.includes('Q') && b.includes('P') && !b.includes('Z') && !b.includes('ESC');
    // bound to something else: the sign follows (and an unknown bracket word is still drawn as written)
    await page.evaluate(() => { G.save.data.keys.jump = ['KeyG', 'Space']; G.input.rebuild(); });
    out.both = await page.evaluate(() => G.actionLabel('jump', true) === 'G/SPACE' && G.actionLabel('move') === 'ARROWS');
    await page.evaluate(() => { G.save.data.keys.left = ['KeyA', null]; G.save.data.keys.right = ['KeyD', null]; G.input.rebuild(); });
    out.move = await page.evaluate(() => G.actionLabel('move'));
    out.ok = out.stale && out.sign && out.map && out.both && out.move === 'A/D';
    return R(out.ok, JSON.stringify(out) + ' caps(sign)=' + a.join(',') + ' caps(map)=' + b.join(','));
  });
};
