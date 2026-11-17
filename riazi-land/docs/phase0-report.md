# Phase 0 report — code map, wrappers, question bank

Line numbers refer to `index.html` AFTER the phase-0 edits (±5 lines drift from the original; no big blocks moved).
Everything below was verified by reading the code and by running it in Chromium (Playwright).

## 1. Corrected code map (PLAN.md section 1)

| Thing | Where (current line) | Notes / corrections to PLAN |
|---|---|---|
| Global state | `const S={...}` 718, `let USER` 1245 | `S` is a flat object; per-user data lives in `users()[USER].d` and is copied into `S` by `enter()`. |
| Navigation | `function go(id)` 722, `SCREENS` 720 (+ `SCREENS.push` at 1482 arc, 1596 hub/gm, 1734 exam/vid, 1918 shop/adv/weak/live, 2036 subj/sg/tch, 2414 move, 2462 wheel, 2483 home, 2661 prof) | A screen = `<section id="s-<id>" class="screen">`; `go()` toggles `.active` for ids in `SCREENS`, so a new screen must be pushed to `SCREENS`. Base `go` now also sets `document.body.dataset.scr=id` (phase 0, used by CSS). `go('gm:<id>')`, `go('arc:<mode>')` are pseudo-ids parsed by wrappers. **`go('menu')` is rewritten to `home` by the v8 wrapper (2504)** unless the closure flag `raw` is set (only the "ریاضی" tile does that). |
| Home | `home()` 2499 (v8) renders `#s-home` (12 tiles + "ادامهٔ ماجراجویی"); old mission list is `#s-menu` + `refreshMenu` | **Finding:** a returning user (auto-login from `mh_session` at line ~1580) lands on the OLD `#s-menu`, not `#s-home`, because auto-login runs `enter()->go('menu')` before the v8 wrapper is installed (verified: `cur==='menu'`). Fresh register/login (after load) lands on `home`. Phase 1 must fix this by design. |
| Storage | `store(k,v)` 464, `users()` 1246, `persist()` base 1248 | `persist` is REPLACED wholesale at 1367 (v3), then wrapped (see section 2). `ST=['coins','items','eq','wrong','adv','team','wk','cd']` at 1925; `advExtra` is pushed into `ST` at ~2568. |
| Login/register | `enter(u,rec)` 1249, form `#regForm` submit 1251, `sha()` 1247 (SHA-256 of `mh|user|pass`, fallback djb2 `f...`) | auto-login: `window.__auto` set at ~1346, consumed at ~1580. Logout moved to v9 section (profile screen). |
| XP / level | `xpOf()` 1269 (computed from results: learn 120 + lab<=8x25 + game score + quiz x30 + expo x40 + memo stars x50; `xpD(d)` 1349/1367 variant adds run/duel) ; level = `floor(xp/200)+1` in `refreshMenu` 1271, `home()` 2499, profile 2665; `RANKS` 1268, `BADGES` 1350, league `TIER` ~1467 | XP is NOT stored; it is derived. A stored xp counter would be a new `d` field. |
| Coins | **TWO separate balances.** (a) `S.coins` via `earn(n)` 1929 (v6; sources: `save()`/`arcEnd` 1930-1931, adventure win 1981, side-quests 2605, wheel 2467, live prize 2017, **daily login bonus 2032 `earn(5+2*streak)` once per day on first `refreshMenu`**). (b) `mathHero.shop.v1` `profile().coins` (shop modal script 2380-2411; starts at 40 for any name; `award()` 2398 limited to 50/day; manual button "پاداش تمرین روزانه +۱۰"). | The two are never synced. Key of shop.v1 user = text of `#who` with `🎮` and whitespace stripped (so "علی رضایی" -> `علیرضایی`); fragile: v7 `who()` later puts the equipped `eq.ch` emoji into `#who`, changing that key. `award(...,'شروع فعالیت')` in the `window.go` wrap was REMOVED in phase 0. |
| Question bank | `QG[7|8|9]` 1371 (6 generator templates per grade) + `genQ()` 1390; `EXQ[g]` 1739 (8 static MCQs/grade); `TOP[g]` 1957 (topic per static item); `topicOf(text)` 1958 (regex classifier for generated text); `exBuild(g,only)` 1959 (overrides 1744; `only` = topic list); `CH[g]` 1767 (chapter names); `chTopic(chapterName)` 1972 (regex -> one of 7 topics); `BANK` 2043 + `VOC` 2280 (فارسی/علوم/اجتماعی, text format `q|ok|w1|w2|w3`); `buildQuiz()` ~1086 (13 grade-8 symmetry questions, hard-wired to grade 8) | See inventory in section 3. |
| Adventure | `advShow` 1974, `advFight(i)` 1977 (pool = `exBuild(g,[chTopic(CH[g][i])])`, falls back to unfiltered if < 8; 8 questions, 3 lives, need 3 correct), `advQ` 1978, `advEnd` 1981; progress `S.adv[grade]` = number of chapters beaten; v9-ish side missions (cave/tower/daily/star) added by a second `advShow` wrapper at ~2572-2610 + a third `go` override for `adv` at 2632 | `S.advExtra={done:{},daily:'YYYY-MM-DD'}`. |
| Wrong answers | `S.wrong['<grade>|<topic>']=count` via `recW` 1960; page `weak` (`weakShow` 1965) | topics are the coarse 7 (`TOP`) not chapters. |
| League | `LG` 1483 (`mh_lg`: `{url,code}`), `lgReq` ~1488, `lgSync` ~1490, `lgFetch`, `renderLeague` 1492 (+wrap 2030), `myRec` (+2 wraps); team `S.team` | Firebase RTDB REST; works only when teacher configures URL+code. `lgSync()` is called from `persist` wrapper (1571) on every persist. |
| Game hub | `HG` 1906 (groups; `HG.unshift` by move/wheel), `HUB` 1707, `hubShow` 1708, `GAMES` 1598, `startG`, `gmStop` | |
| Shop | v6 `SHOP` 1933 / `shopShow` 1941 / `chip()` 1947 (S.items `'<cat>:<value>'`, S.eq), v7 extended `SHOP.ch/pt/ti/ba/ef` ~2452, **and** shop.v1 modal (`showShop` 2401; items in its own db, `owned`, `equip`, `chars`) | Two parallel shop systems + wheel; confirmed. |
| Effects | `confetti` 1214 (wrapped by v7 effects), `SFX` 471, `toast` 463 (wrapped v4 for reg errors), `modal(html)` 1507 (`#modal`, always adds a "بستن ✕" button) | |
| Teacher AI | `tchBrain/aiReply/tchShow` ~2331-2360, keys `tm_<user>` (memory), `mh_ai` (`{url,key,model}`) | |
| Misc keys | `wh_<user>` (wheel day number), `mv_<user>` (rhythm rounds count), `mh_lg`, `mh_ai`, `tm_<user>` | all verified in code. |
| Floating buttons | `#btnSup` 🛟 (created 1534), `#btnTch` 🧑‍🏫 (created ~2371); visibility set by wrappers `_g5` and `_g9`; phase 0 adds CSS `body[data-scr="reg"] #btnSup,... {display:none!important}` | They still overlap the bottom-left corner on other screens (e.g. cover the footer credit text) — cosmetic, left for phase 1 bottom bar. |
| PWA | static `<link rel=manifest href=manifest.webmanifest>` + icons in head; sw registered at 2380 only when `location.protocol` starts with `http` (silent `.catch`) ; **phase 0 removed two JS-created Blob manifests (v2 ~1243, v6 ~1956)** which duplicated/overrode the static link; created `manifest.webmanifest`, `icon-192.png`, `icon-512.png`, `sw.js` | Original had 3-5 manifest links (static + 2 blobs + duplicate meta tags). |
| Developer credit | `<footer id="dev" class="credit">` filled at 1366 (`DEV`) ; a second raw `<footer>` after the v8 script was **removed**; `DEV` name also shown in `home()` `.mini` and in the report text | |

## 2. Everywhere go / persist / enter (and other things) are wrapped or replaced

Current line numbers. "base" = original definition; others wrap `previous` unless noted.

**go()** (11 layers + 1 override)
1. 722 base (`go`)
2. 1226 v1: report/expo/memo/run/duel init, sets `body.dataset.gr`, calls `persist()` on EVERY navigation
3. 1535 `_g5` v4: hides 🛟 on game/run
4. 1542 `_g4` v4: `arc:` pseudo-ids, `arcIntro`
5. 1711 `_g6` v4/hub: `gm:` pseudo-ids, hub/gm
6. 1911 `_g7` v5: exam/vid
7. 2031 `_g8` v6: shop/adv/weak/live
8. 2371 `_g9` v7: sg/subj/tch + FAB visibility for 🛟 and 🧑‍🏫
9. 2407 shop.v1 `window.go=` : `addEntryPoints()` (injects `#economyMenu` into `#s-menu` and a shop button into hub), `applyTheme()`, active-hero badge (**coin award removed**)
10. 2445 move: stop rhythm timer
11. 2504 v8: `menu` -> `home` redirect
12. 2632 adv-fix: **overrides** adventure navigation, force-activates `#s-adv` and sets `cur='adv'` itself
Plus v9 (phase 0) base `go()` edit: `body.dataset.scr`. No wrapper added by phase 0.

**persist()**: 1248 base (v2) -> **1367 replaced wholesale** (v3: adds grade/run/duel) -> 1571 `_p4` (adds `arc`, `stk`, calls `lgSync()` network!) -> 1927 `_p8` (ST fields) -> 2572 advExtra (pushes `advExtra` into `ST` too, so it is written twice).

**enter()**: 1249 base -> 1572 `_e4` (reset arc/stk, start 30s league polling interval) -> 1928 `_e8` (reset ST fields, defaults) -> 2570 advExtra default.
Caveat: auto-login at load (~1580) calls the enter chain as it exists at that point (base + `_e4` only), later layers only run on form login (so e.g. the `S.coins||0` / `S.wrong||{}` defaults from `_e8` are not applied on auto-login; fields come straight from `rec.d`).

**refreshMenu()**: 734 base + 8 wrappers (1271, 1352, 1468, 1573, 1712, 1912, 2032 [daily coin bonus], 2372).

**Other wrapped/replaced functions**: `xpD` 2x, `calc`, `reportText` 2x, `toast`, `surveyShow`, `myRec` 2x, `save` (adds coins), `arcEnd` (adds coins), `exFinish` (records wrong answers), `exBuild` (replaced), `renderLeague`, `shopShow`, `chip`, `confetti`, `advShow` (side missions), `tchBrain`, `prev` (shop preview), `applyTheme` duplicated (v6 `applyTheme` class-based vs shop.v1 `applyTheme` CSS-var based — two different theme systems).

## 3. Question-bank inventory

How questions are produced:
* Static MCQs `EXQ[g]`: **8 per grade** (24 total), each tagged with a coarse topic in `TOP[g]`.
* Generated: `QG[g]` = **6 numeric templates per grade** (18 total); `genQ()` picks one at random. Variants are only number changes.
* Everything else (exam = 20 questions, adventure = 8, side-missions, duel, runner, arcade, live) draws from these through `exBuild`/`genQ`.
* Chapters (`CH[g]`) are NOT stored on questions. A chapter maps to one of 7 coarse topics by regex (`chTopic`), then questions are filtered by topic (`TOP` for static, `topicOf(text)` regex for generated).
* Other banks: `BANK` (text-format MCQ) per subject x grade — فارسی 17/14/14 (+30 vocab pairs each grade, as generated "معنی ... چیست؟" items), علوم 32/32/32, اجتماعی 32/32/32 for grades 7/8/9. `buildQuiz()` = 13 hard-wired grade-8 symmetry/polygon questions (also used in grade 7/9 through the same screen).

Measured (Chromium, 30,000 `genQ` draws per grade, union of distinct question texts; plus static). "Reachable" = what `advFight` / `exBuild(g,[chTopic(chapter)])` can actually return for that chapter.

| Grade | # | Chapter (`CH`) | Topic via `chTopic` | Static | Generator templates hitting topic | Distinct generated texts | **Reachable total** | < 20 ? |
|---|---|---|---|---|---|---|---|---|
| 7 | 1 | راهبردهای حل مسئله | عددهای صحیح | 2 | 0 | 0 | **2** | FLAG |
| 7 | 2 | عددهای صحیح | عددهای صحیح | 2 | 0 | 0 | **2** | FLAG |
| 7 | 3 | جبر و معادله | جبر و معادله | 1 | 2 | 229 | **230** | ok (numeric variants of 2 templates) |
| 7 | 4 | هندسه و استدلال | هندسه | 2 | 1 | 121 | **123** | ok (1 template, area only) |
| 7 | 5 | شمارنده‌ها و اعداد اول | اعداد اول و شمارنده | 3 | 0 | 0 | **3** | FLAG |
| 7 | 6 | سطح و حجم | هندسه | 2 | 1 | 121 | **123** | ok (same pool as ch.4) |
| 7 | 7 | کسر | عددهای صحیح | 2 | 0 | 0 | **2** | FLAG |
| 7 | 8 | توان و جذر | توان و جذر | 0 | 0 | 0 | **0** | FLAG |
| 7 | 9 | آمار و احتمال | آمار و احتمال | 0 | 0 | 0 | **0** | FLAG |
| 8 | 1 | عددهای صحیح و گویا | عددهای صحیح | 0 | 0 | 0 | **0** | FLAG |
| 8 | 2 | عددهای اول | اعداد اول و شمارنده | 1 | 0 | 0 | **1** | FLAG |
| 8 | 3 | چندضلعی‌ها | هندسه | 3 | 2 | 13 | **16** | FLAG |
| 8 | 4 | جبر و معادله | جبر و معادله | 1 | 1 | 324 | **325** | ok (1 template) |
| 8 | 5 | بردار و مختصات | هندسه | 3 | 2 | 13 | **16** | FLAG (same pool as ch.3/6; no vector/coordinate question exists) |
| 8 | 6 | مثلث | هندسه | 3 | 2 | 13 | **16** | FLAG (same pool) |
| 8 | 7 | توان و جذر | توان و جذر | 2 | 2 | 26 | **28** | ok (2 templates, only 26 variants) |
| 8 | 8 | آمار و احتمال | آمار و احتمال | 1 | 0 | 0 | **1** | FLAG |
| 9 | 1 | مجموعه‌ها | (default) عددهای صحیح | 0 | 0 | 0 | **0** | FLAG (the static set question is tagged `مجموعه‌ها` in `TOP` but `chTopic` never returns that tag -> unreachable) |
| 9 | 2 | عددهای حقیقی | (default) عددهای صحیح | 0 | 0 | 0 | **0** | FLAG (static item tagged `عددهای حقیقی`, unreachable) |
| 9 | 3 | استدلال و اثبات در هندسه | هندسه | 1 | 1 | 4 | **5** | FLAG |
| 9 | 4 | توان و ریشه | توان و جذر | 2 | 4 | 91 | **93** | ok (templates mis-tagged, see below) |
| 9 | 5 | عبارت‌های جبری | جبر و معادله | 3 | 0 | 0 | **3** | FLAG |
| 9 | 6 | خط و معادله‌های خطی | جبر و معادله | 3 | 0 | 0 | **3** | FLAG (same pool; no line/slope generator) |
| 9 | 7 | عبارت‌های گویا | جبر و معادله | 3 | 0 | 0 | **3** | FLAG (same pool) |
| 9 | 8 | حجم و مساحت | هندسه | 1 | 1 | 4 | **5** | FLAG |

Summary: **19 of 25 chapters are < 20** (G7: ch1,2,5,7,8,9 = 6 of 9; G8: ch1,2,3,5,6,8 = 6 of 8; G9: ch1,2,3,5,6,7,8 = 7 of 8). Chapters sharing a topic share one pool (e.g. G8 ch.3/5/6 all draw the same 16 geometry questions; G9 ch.5/6/7 the same 3). Even the "ok" chapters are 1-2 templates with number changes, not 20 distinct problems. Conceptually distinct items in the whole app: 24 static + 18 templates.

Classification bugs found (affect phase 3/7, not fixed):
* `topicOf` mis-tags generated text: grade-9 sequence template ("جملهٔ **اول**") -> "اعداد اول و شمارنده" (270 variants), the `(x+a)²` template -> "توان و جذر"; generated G7/G8 items that match nothing become `محاسبات` (G7 455, G8 128 distinct), a topic `chTopic` never returns, so they are reachable only from the unfiltered `exBuild(g)` (exam, weak-spot fill-up, side missions).
* `chTopic` has no case for sets/real numbers/fractions/probability; defaults to `عددهای صحیح`.
* `TOP[9]` uses tags `مجموعه‌ها` and `عددهای حقیقی` that no filter ever asks for.
* Wrong-answer tracking keys `grade|topic` (7 coarse topics), not chapter.
* Chapters with 0 reachable questions silently fall back to the unfiltered pool in `advFight` (so the boss is not about that chapter).

Phase 3 (3-minute lesson engine) therefore needs ~19 chapters of new content (>=20 distinct items each) or a template-per-chapter generator set, and a per-question `chapter` tag.

## 4. Phase-0 changes made to index.html (summary)

1. Topbar: 🚪 removed, `#btnProf` 👤 (aria-label «پروفایل») added; `.ib` is 44x44 (was 38).
2. Logout is in the new profile screen `#s-prof` (button `#btnOut`), asks via in-app `modal()` («بله، خارج شو» / «نه، می‌مانم»); code lives in the new `/* ===== نسخهٔ ۹: مسیر ===== */` script at the end of the file. The old `$('#btnOut').onclick` line was removed.
3. 🛟/🧑‍🏫 hidden on the register screen via `body[data-scr="reg"]` (set in base `go()`, initial `<body data-scr="reg">`).
4. Duplicate developer `<footer>` removed (kept `#dev`).
5. Rhythm: answer hidden behind a «جواب» button (44px).
6. `.gnote` "به‌زودی" message + its CSS removed.
7. `award(...,'شروع فعالیت')` removed from the shop.v1 `window.go` wrap (the daily login bonus `earn(5+2*streak)` at 2032 and other real rewards remain; that is a phase 4/5 topic).
8. Blob manifests removed; real `manifest.webmanifest`, `sw.js` (cache-first + background refresh; bump `CACHE` per release), `icon-192.png`, `icon-512.png` (generated by `tests/tools/make-icons.js`).

## 5. Other findings for later phases
* Returning-user landing screen is the old menu (section 1, Home).
* `persist()` is called on every `go()` and each time triggers `lgSync()` (network, if league configured).
* `S.cls`/`cls:'هشتم'` default in `enter` and `body[data-gr]` hide `.g8` missions (learn/lab/game/quiz) for grades 7/9 — with the "به‌زودی" note gone, grade 7/9 users see no explanation for the missing lesson/lab/game/quiz missions on the old `#s-menu` (it is no longer the landing screen for new sessions, so low impact).
* Date handling mixes `Date.now()+12600000` day numbers (`dayN`, Iran offset) and `toISOString().slice(0,10)` (UTC) -> day boundaries differ between features (streak/daily bonus vs. side-mission daily / shop.v1).
* No test exists for any game engine; smoke tests only open screens.
