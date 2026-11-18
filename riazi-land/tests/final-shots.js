#!/usr/bin/env node
/* Final screenshots (JPEG q82 to keep the repo small) for the presentation: docs/shots/final/<390x844|1280x800>/NN-name, deviceScaleFactor 2.
   Run: node riazi-land/tests/final-shots.js */
const fs = require('fs');
const path = require('path');
const { chromium, ROOT, open, register, openForm } = require('./lib');
const VPS = [['390x844', { width: 390, height: 844 }], ['1280x800', { width: 1280, height: 800 }]].filter(v => !process.env.VP || v[0] === process.env.VP);
const SHOTDIR = process.env.SHOTDIR || 'final';
const CLOCK = Date.UTC(2026, 0, 10, 9);
const fastLesson = (page, wrongFirst) => page.evaluate((w) => { Lesson.start(8, 3, 0); let first = true; for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(first && w ? '99999' : i.ans)) Lesson.key(c); } else Lesson.pick(first && w ? (i.ans === 0 ? 1 : 0) : i.ans); first = false; Lesson.check(); Lesson.next(); } }, !!wrongFirst);
const placement = async (page) => { await page.click('#wlGo'); await page.click('#obBox .gcard[data-g="8"]'); };
const answerPlacement = async (page) => { for (let k = 0; k < 5; k++) { await page.waitForSelector('#obBox .opt:not([disabled])'); await page.evaluate(() => { const o = v9Ob(); document.querySelectorAll('#obBox .opt')[o.q[o.k].opts.findIndex((x) => x.ok)].click(); }); await page.waitForTimeout(900); } };
const startUntil = async (page, g, ch, type) => { for (let t = 0; t < 80; t++) { await page.evaluate(([g, ch]) => Lesson.start(g, ch, 0), [g, ch]); await page.waitForSelector('#lsGo'); if ((await page.evaluate(() => v9Lesson().type)) === type) return; } };
const ans = async (page, right) => { const i = await page.evaluate(() => v9Lesson()); await page.click(`#pqBox .opt[data-k="${right ? i.ans : (i.ans === 0 ? 1 : 0)}"]`); await page.click('#lsGo'); };
/* name, options {fresh|legacy, clock, noLogin}, setup */
const SHOTS = [
  ['welcome', { fresh: true, noLogin: true }, async () => {}],
  ['grade-pick', { fresh: true, noLogin: true }, (p) => p.click('#wlGo')],
  ['placement-question', { fresh: true, noLogin: true }, placement],
  ['placement-result', { fresh: true, noLogin: true }, async (p) => { await placement(p); await answerPlacement(p); }],
  ['path-new-user', { fresh: true, clock: CLOCK }, async () => {}],
  ['path-legacy-user', { legacy: true }, async () => {}],
  ['lesson-mcq', { fresh: true, clock: CLOCK }, (p) => startUntil(p, 8, 3, 'mcq')],
  ['lesson-feedback-correct', { fresh: true, clock: CLOCK }, async (p) => { await startUntil(p, 8, 3, 'mcq'); await ans(p, true); }],
  ['lesson-feedback-wrong', { fresh: true, clock: CLOCK }, async (p) => { await startUntil(p, 9, 0, 'mcq'); await ans(p, false); }],
  ['lesson-numeric-keypad', { fresh: true, clock: CLOCK }, async (p) => { await startUntil(p, 8, 3, 'num'); await p.click('#pqBox .kpk[data-k="-"]'); await p.click('#pqBox .kpk[data-k="5"]'); }],
  ['lesson-shape-card', { fresh: true, clock: CLOCK }, (p) => startUntil(p, 8, 2, 'shape')],
  ['end-screen', { fresh: true, clock: CLOCK }, async (p) => { await p.evaluate(() => { S.goal = 3; persist(); }); await fastLesson(p); await p.waitForSelector('#eGoal'); await p.waitForTimeout(1400); }],
  ['today-enough-card', { fresh: true, clock: CLOCK }, async (p) => { await fastLesson(p); await p.waitForSelector('#goalDone'); await p.waitForTimeout(1400); }],
  ['signup-card', { fresh: true, noLogin: true }, async (p) => { await placement(p); await answerPlacement(p); await p.click('#obStart'); await p.waitForFunction(() => cur === 'pq'); await p.evaluate(() => { for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(i.ans)) Lesson.key(c); } else Lesson.pick(i.ans); Lesson.check(); Lesson.next(); } }); await p.waitForSelector('#suBox'); await p.waitForTimeout(1400); }],
  ['shop', { fresh: true, clock: CLOCK }, async (p) => { await p.evaluate(() => { S.coins = 120; persist(); }); await p.click('#bnav [data-go="shop"]'); }],
  ['purchase-confirm', { fresh: true, clock: CLOCK }, async (p) => { await p.evaluate(() => { S.coins = 120; persist(); }); await p.click('#bnav [data-go="shop"]'); await p.click('#shopBox [data-buy="rb:hat-top"]'); }],
  ['collection', { legacy: true }, async (p) => { await p.click('#btnProf'); await p.evaluate(() => document.querySelector('#colBox').scrollIntoView()); }],
  ['profile-goal-calendar', { fresh: true, clock: CLOCK }, async (p) => { await fastLesson(p); await p.click('#pqGo'); await p.click('#btnProf'); await p.evaluate(() => document.querySelector('#goalPick').scrollIntoView()); }],
  ['profile-more', { legacy: true }, async (p) => { await p.click('#btnProf'); await p.evaluate(() => document.querySelector('#pMore').scrollIntoView()); }],
  ['league-tab', { legacy: true }, (p) => p.click('#bnav [data-go="league"]')],
  ['logout-confirm', { legacy: true }, async (p) => { await p.click('#btnProf'); await p.click('#s-prof #btnOut'); }],
];
(async () => {
  const browser = await chromium.launch();
  for (const [vp, size] of VPS) {
    const out = path.join(ROOT, 'docs', 'shots', SHOTDIR, vp);
    fs.rmSync(out, { recursive: true, force: true }); fs.mkdirSync(out, { recursive: true });
    let n = 0;
    for (const [name, o, setup] of SHOTS) {
      const { page, context } = await open(browser, { viewport: size, dsf: 2, clock: o.clock, fixture: o.legacy ? 'legacy-user.json' : undefined });
      try {
        if (o.fresh && !o.noLogin) await register(page, { name: 'نگار احمدی', user: 'final1', pass: '1234', grade: 8 });
        if (o.legacy) await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
        await setup(page);
        await page.waitForTimeout(700);
        await page.screenshot({ path: path.join(out, String(++n).padStart(2, '0') + '-' + name + '.jpg'), type: 'jpeg', quality: 82 });
        if (page.errors.length) console.log('  pageerror in ' + name + ': ' + page.errors[0]);
      } catch (e) { console.log('SKIP ' + vp + ' ' + name + ': ' + String(e.message).split('\n')[0]); }
      await context.close();
    }
    console.log(vp + ': ' + n + ' shots');
  }
  await browser.close();
})();
