#!/usr/bin/env node
/* Screenshots of key screens -> riazi-land/docs/shots/<phase>/NN-name.png  (viewport 390x844, deviceScaleFactor 1)
   Usage: node riazi-land/tests/shots.js phase-0
   Later phases: add entries to SCREENS (name + async fn(page)); everything runs against a seeded legacy user unless `fresh:true`. */
const fs = require('fs');
const path = require('path');
const { chromium, ROOT, open, register, openForm } = require('./lib');

const phase = process.argv[2];
/* Housekeeping (phase 5+): only screens tagged with { p: N } (new/changed in phase N) are shot for `phase-N`.
   Entries without `p` are older screens; run `node shots.js phase-N --all` for the complete set (phase 12). */
const PN = +(String(phase || '').match(/(\d+)/) || [0, -1])[1];
const ALL = process.argv.includes('--all');
if (!phase || !/^[\w.-]+$/.test(phase)) { console.error('usage: node shots.js <phase-name>   e.g. phase-0'); process.exit(2); }
const OUT = path.join(ROOT, 'docs', 'shots', phase);
fs.mkdirSync(OUT, { recursive: true });

const go = (id) => (page) => page.evaluate((id) => go(id), id);
/* name, options, setup */
const lessonShot = (g, ch, type, act) => async (page) => {
  await page.evaluate(([g, ch]) => Lesson.start(g, ch, 0), [g, ch]);
  for (let t = 0; t < 80; t++) { const i = await page.evaluate(() => v9Lesson()); if (i && i.type === type) break; await page.evaluate(([g, ch]) => Lesson.start(g, ch, 0), [g, ch]); }
  if (act) await act(page);
};
const clickRight = async (page) => { const i = await page.evaluate(() => v9Lesson()); await page.click(`#pqBox .opt[data-k="${i.ans}"]`); await page.click('#lsGo'); };
const clickWrong = async (page) => { const i = await page.evaluate(() => v9Lesson()); await page.click(`#pqBox .opt[data-k="${i.ans === 0 ? 1 : 0}"]`); await page.click('#lsGo'); };
const SCREENS = [
  ['welcome', { fresh: true, noLogin: true }, async () => {}],
  ['login-form', { fresh: true, noLogin: true }, (page) => openForm(page, 'login')],
  ['grade-pick', { fresh: true, noLogin: true }, (page) => page.click('#wlGo')],
  ['placement-question', { fresh: true, noLogin: true }, async (page) => { await page.click('#wlGo'); await page.click('#obBox .gcard[data-g="8"]'); }],
  ['placement-result', { fresh: true, noLogin: true }, async (page) => { await page.click('#wlGo'); await page.click('#obBox .gcard[data-g="8"]'); for (let k = 0; k < 5; k++) { await page.waitForSelector('#obBox .opt:not([disabled])'); await page.evaluate(() => { const o = v9Ob(); document.querySelectorAll('#obBox .opt')[o.q[o.k].opts.findIndex((x) => x.ok)].click(); }); await page.waitForTimeout(900); } }],
  ['path-after-placement', { fresh: true, noLogin: true }, async (page) => { await page.click('#wlGo'); await page.click('#obBox .gcard[data-g="8"]'); for (let k = 0; k < 5; k++) { await page.waitForSelector('#obBox .opt:not([disabled])'); await page.evaluate(() => { const o = v9Ob(); document.querySelectorAll('#obBox .opt')[o.q[o.k].opts.findIndex((x) => x.ok)].click(); }); await page.waitForTimeout(900); } await page.click('#obStart'); await page.waitForFunction(() => cur === 'pq'); await page.evaluate(() => go('path')); }],
  ['signup-card', { fresh: true, noLogin: true }, async (page) => { await page.click('#wlGo'); await page.click('#obBox .gcard[data-g="8"]'); for (let k = 0; k < 5; k++) { await page.waitForSelector('#obBox .opt:not([disabled])'); await page.evaluate(() => { const o = v9Ob(); document.querySelectorAll('#obBox .opt')[o.q[o.k].opts.findIndex((x) => x.ok)].click(); }); await page.waitForTimeout(900); } await page.click('#obStart'); await page.waitForFunction(() => cur === 'pq'); for (let g = 0; g < 40; g++) { const i = await page.evaluate(() => v9Lesson()); if (!i) break; if (i.type === 'num') { for (const ch of String(i.ans)) await page.click(`#pqBox .kpk[data-k="${ch}"]`); } else await page.click(`#pqBox .opt[data-k="${i.ans}"]`); await page.click('#lsGo'); await page.click('#lsGo'); } await page.waitForSelector('#suBox'); }],
  ['path-new-user', { fresh: true }, async () => {}],
  ['path-legacy-user', {}, async () => {}],
  ['path-legacy-chapter-top', {}, (page) => page.evaluate(() => window.scrollTo(0, 0))],
  ['lesson-quiz', { fresh: true }, async (page) => { await page.click('#pathBox .pgo'); }],
  ['tab-league', {}, (page) => page.click('#bnav [data-go="league"]')],
  ['tab-shop', {}, (page) => page.click('#bnav [data-go="shop"]')],
  ['tab-profile', {}, (page) => page.click('#btnProf')],
  ['profile-more', {}, async (page) => { await page.click('#btnProf'); await page.evaluate(() => document.querySelector('#pMore').scrollIntoView()); }],
  ['logout-confirm', {}, async (page) => { await page.click('#btnProf'); await page.click('#s-prof #btnOut'); }],
  ['more-exam', {}, async (page) => { await page.click('#btnProf'); await page.click('#pMore [data-more="exam"]'); }],
  ['more-hub', {}, async (page) => { await page.click('#btnProf'); await page.click('#pMore [data-more="hub"]'); }],
  ['move-rhythm', {}, go('move')],
  ['lesson-mcq', { fresh: true }, lessonShot(8, 3, 'mcq')],
  ['lesson-mcq-selected', { fresh: true }, lessonShot(7, 6, 'mcq', (p) => p.click('#pqBox .opt[data-k="1"]'))],
  ['lesson-feedback-correct', { fresh: true }, lessonShot(8, 3, 'mcq', clickRight)],
  ['lesson-feedback-wrong', { fresh: true }, lessonShot(9, 0, 'mcq', clickWrong)],
  ['lesson-numeric-keypad', { fresh: true }, lessonShot(8, 3, 'num', async (p) => { await p.click('#pqBox .kpk[data-k="-"]'); await p.click('#pqBox .kpk[data-k="5"]'); })],
  ['lesson-shape-card', { fresh: true }, lessonShot(8, 2, 'shape')],
  ['lesson-end', { fresh: true }, async (page) => { await page.evaluate(() => Lesson.start(8, 3, 0)); for (let g = 0; g < 40; g++) { const i = await page.evaluate(() => v9Lesson()); if (!i) break; if (i.type === 'num') { for (const ch of String(i.ans)) await page.click(`#pqBox .kpk[data-k="${/\d/.test(ch) ? ch : ch}"]`); } else await page.click(`#pqBox .opt[data-k="${i.ans}"]`); await page.click('#lsGo'); await page.click('#lsGo'); } }],
  ['lesson-combo', { fresh: true }, async (page) => { await page.evaluate(() => Lesson.start(8, 3, 0)); for (let k = 0; k < 5; k++) { const i = await page.evaluate(() => v9Lesson()); if (i.type === 'num') { for (const ch of String(i.ans)) await page.click(`#pqBox .kpk[data-k="${ch}"]`); } else await page.click(`#pqBox .opt[data-k="${i.ans}"]`); await page.click('#lsGo'); if (k < 4) await page.click('#lsGo'); } }],
  ['shop', { fresh: true }, async (page) => { await page.evaluate(() => { S.coins = 120; persist(); }); await page.click('#bnav [data-go="shop"]'); }],
  ['shop-purchase-confirm', { fresh: true }, async (page) => { await page.evaluate(() => { S.coins = 120; persist(); }); await page.click('#bnav [data-go="shop"]'); await page.click('#shopBox [data-buy="rb:hat-top"]'); }],
  ['collection-legacy', {}, async (page) => { await page.click('#btnProf'); await page.evaluate(() => document.querySelector('#colBox').scrollIntoView()); }],
  ['avatar-tier1-lv5', { fresh: true }, async (page) => { await page.evaluate(() => { S.xp = 800; go('prof'); }); }],
  ['avatar-tier2-lv10', { fresh: true }, async (page) => { await page.evaluate(() => { S.xp = 1800; S.eq = { rbh: 'hat-cap', rbc: 'col-pink' }; go('prof'); }); }],
  ['avatar-tier3-lv20', { fresh: true }, async (page) => { await page.evaluate(() => { S.xp = 3800; S.eq = { rbo: 'out-cape', rbc: 'col-gold' }; go('prof'); }); }],
  ['lesson-sets-question', { fresh: true }, lessonShot(9, 0, 'mcq')],
  ['lesson-vector-question', { fresh: true }, lessonShot(8, 4, 'mcq')],
  ['goal-picker-calendar', { fresh: true, p: 5, clock: Date.UTC(2026, 0, 10, 9) }, async (page) => { await page.evaluate(() => { Lesson.start(8, 3, 0); for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(i.ans)) Lesson.key(c); } else Lesson.pick(i.ans); Lesson.check(); Lesson.next(); } }); await page.click('#pqGo'); await page.click('#btnProf'); await page.evaluate(() => document.querySelector('#goalPick').scrollIntoView()); }],
  ['streak-plus-one', { fresh: true, p: 5, clock: Date.UTC(2026, 0, 10, 9) }, async (page) => { await page.evaluate(() => { Lesson.start(8, 3, 0); for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(i.ans)) Lesson.key(c); } else Lesson.pick(i.ans); Lesson.check(); Lesson.next(); } }); }],
  ['today-enough-card', { fresh: true, p: 5, clock: Date.UTC(2026, 0, 10, 9) }, async (page) => { await page.evaluate(() => { Lesson.start(8, 3, 0); for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(i.ans)) Lesson.key(c); } else Lesson.pick(i.ans); Lesson.check(); Lesson.next(); } }); await page.evaluate(() => document.querySelector('#goalDone').scrollIntoView()); }],
  ['freeze-toast', { fresh: true, p: 5, clock: Date.UTC(2026, 0, 10, 9) }, async (page) => { await page.evaluate(() => { Lesson.start(8, 3, 0); for (let k = 0; k < 80 && Lesson.st; k++) { const i = v9Lesson(); if (!i) break; if (i.type === 'num') { for (const c of String(i.ans)) Lesson.key(c); } else Lesson.pick(i.ans); Lesson.check(); Lesson.next(); } }); await page.click('#pqGo'); await page.evaluate(() => { S.streak.freezes = 1; persist(); localStorage.setItem('__T', String(Date.UTC(2026, 0, 12, 9))); }); await page.reload(); await page.waitForFunction(() => document.querySelector('#toast').textContent.includes('یخ‌استریک')); }],
  /* PHASE 6+ : append new screens here */
];

(async () => {
  const browser = await chromium.launch();
  let n = 0;
  for (const [name, o, setup] of SCREENS) {
    if (!ALL && (o.p || 0) !== PN) continue;
    const { page, context } = o.fresh ? await open(browser, { clock: o.clock || undefined }) : await open(browser, { fixture: 'legacy-user.json' });
    try {
      if (o.fresh && !o.noLogin) await register(page, { name: 'نگار احمدی', user: 'shot1', pass: '1234', grade: 8 });
      if (!o.fresh) await page.waitForFunction(() => typeof USER !== 'undefined' && USER);
      await setup(page);
      await page.waitForTimeout(700); /* let the fade-in animation finish */
      const file = path.join(OUT, String(++n).padStart(2, '0') + '-' + name + '.png');
      await page.screenshot({ path: file, fullPage: false });
      console.log('shot ' + path.relative(ROOT, file) + (page.errors.length ? '  (pageerror: ' + page.errors[0] + ')' : ''));
    } catch (e) { console.log('SKIP ' + name + ': ' + e.message.split('\n')[0]); }
    await context.close();
  }
  await browser.close();
})();
