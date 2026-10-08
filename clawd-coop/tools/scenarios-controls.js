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
};
