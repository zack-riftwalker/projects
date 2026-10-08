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
    const ok = before.jump && q.jump && !z.jump && !sp.jump && reserved === ',|?' && after.keys[0] === 'KeyQ' && after.lbl === 'Q' && after.both === 'C/SHIFT' && after.arrow === '←' && after.digit === '1' && q2.jump && !z2.jump && kept === 'KeyQ';
    return R(ok, JSON.stringify({ before: before.jump, q: q.jump, z: z.jump, sp: sp.jump, reserved, after, q2: q2.jump, z2: z2.jump, kept }));
  });
};
