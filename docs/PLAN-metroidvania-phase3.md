# CLAWD Metroidvania — Phase 3 Plan (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. همه‌ی تصمیم‌ها گرفته شدن و Sonnet فقط اجرا می‌کنه.
>
> **فاز ۳ دو تیکه‌ست و آخر هر تیکه Sonnet می‌ایسته که تو تست کنی:**
>
> **۳A — بقیه‌ی SOURCE TREE:**
> - اتاق `README.md` حالا دو راه داره: با پله‌ها برو بالا پیش **THE REVIEWER** (باس جدید، شمشیرزنی که ضربه‌هات رو جواب می‌ده)، یا از در پایین برو `~/node_modules`، که تو ۳B باز می‌شه.
> - جایزه‌ی REVIEWER توانایی **catch**ه: هر حمله‌ی **زرد** رو اگه درست لحظه‌ی رسیدنش بزنی، برمی‌گرده سمت خودش. با همین، کلیدهایی رو می‌زنی که با بدن نمی‌رسی.
> - **پلاگین‌ها** (مثل charmهای Hollow Knight): روی نیمکت سوارشون می‌کنی. ۳ خونه جا داری.
>
> **۳B — منطقه‌ی DEPENDENCY DEPTHS:**
> - ۷ اتاق: سه مرحله‌ی دنیای ۲ بازی فعلی، اتاق نیمکت و فروشگاه (`npm registry`)، باس **MERGE CONFLICT** نسخه‌ی ۲، اتاق آموزش agents، و یه اتاق مخفی.
> - جایزه‌ی MERGE CONFLICT توانایی **agents**ه: وقتی context meter پره، یه ضربه‌ی کوتاه رو `special` دو تا کمکی می‌فرسته. نگه داشتن `special` مثل قبل شفا می‌ده.
> - ۴ دشمن قدیمی دنیای ۲ (Mimic، Logger، Noodle، Flaky) و دو دشمن جدید: **EXCEPTION** که خطای زرد پرت می‌کنه، و **FORK** که لونه‌ست و باگ می‌سازه.
> - توکن‌ها بالاخره به درد می‌خورن: باهاشون از فروشگاه پلاگین می‌خری.
>
> **جون باس‌ها:** از فرمول `زمان × r × ضریب` حساب می‌شه. وقتی آمار مبارزه‌هات رو بفرستی (صفحه‌ی `Fights` تو منوی توقف)، فقط یه عدد عوض می‌شه و جون همه‌ی باس‌ها درست می‌شه.
>
> **چطوری بدی به Sonnet:**
> - تیکه‌ی اول: یه جلسه‌ی جدید با Sonnet روی برنچ `ph1` باز کن و بنویس:
>   «فایل `docs/PLAN-metroidvania-phase3.md` رو بخون و بخش ۳A رو اجرا کن.»
> - بعد از اینکه ۳A رو تست کردی، یه جلسه‌ی **جدید** باز کن و بنویس:
>   «فایل `docs/PLAN-metroidvania-phase3.md` رو بخون و بخش ۳B رو اجرا کن.»
>   جلسه‌ی جدید ارزون‌تر و دقیق‌تره.

---

## 0. Rules of engagement

- **Read first, in order:** `CLAUDE.md` (especially "Godot version" and its co-op rules), this file, `docs/metroidvania/00-decisions.md` §11 and §12, `docs/metroidvania/07-js-vs-godot.md` §3 (the ten co-op rules), `docs/metroidvania/05-difficulty-model.md`, then the code under `godot/src` you are about to change. Phase 1 §3 (architecture) and phase 2 §0 still apply.
- **Which part:** Zakaria tells you "3A" or "3B". Do only that part, then stop and report. 3B requires 3A to be done (all MV3-01…07 `done` in the status table).
- **Do not redesign.** Values, names, letters, paths, maps and JSON in this file are decisions. If one is impossible, take the smallest change that keeps the goal and list it under "deviations" in the report.
- **Branch:** `ph1` only. Start with `git fetch origin main ph1 && git checkout ph1 && git merge --no-edit origin/ph1 && git merge --no-edit origin/main`. Push with `git push -u origin ph1`. Never push or merge to `main`, never open a PR.
- **Files you may touch:** everything under `godot/`, `tools/godot/`, `tools/scenarios-mv.js`, `docs/metroidvania/`, `docs/reports/metroidvania-phase3*.md`, this plan's status table. **Not** `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`. `public/mv/` only through `tools/godot/export-web.sh`, as its own last commit of each part.
- **One commit per task** (`MV3-xx: <what>`), ending with the attribution lines your session gives you; push after each.
- **Co-op rules (from `CLAUDE.md`, they are not optional):** state over events; anything the guest's combat reads from a creature goes through `net_fields()`/`net_apply()` and the `parity` test; anything that hurts on contact is in `harmboxes()` computed from those fields; host-side damage that is not a creature's contact goes through `room.harm_zone`; the partner is seen late (use its recent reports, limits that grow with ping); a new kind of co-op bug gets a rule in `godot/src/net/watchdog.gd`; reliable event data lives only in `d` (never a field named `i` or `k`).
- **Godot naming trap:** never name your own members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`. Bosses have `boss_name`, not `name`.
- **Tests:** every task's acceptance names its tests. A bug fix comes with a test that fails on the old code. Before each part's final commit: `bash tools/godot/test-all.sh` → `ALL PASS` (it takes ~25 min; add every new `--test=` and co-op scenario to it).
- **Movement must not change:** the seven parity tapes against the JS game must keep passing. Plugins only change numbers while equipped.

## 1. Status

| task | part | what | owner | status |
|---|---|---|---|---|
| MV3-01 | 3A | boss framework: registry, HP formula, generic reward, fight list page, per-boss music | Sonnet | todo |
| MV3-02 | 3A | rooms R08 (edit), R09, R10, R11; map scaling; end-door texts | Sonnet | todo |
| MV3-03 | 3A | catch: parry projectiles and strikes; switches `Y`; gate tiles `!`; co-op | Sonnet | todo |
| MV3-04 | 3A | EXCEPTION enemy; the guard's diagonal-dash fix | Sonnet | todo |
| MV3-05 | 3A | THE REVIEWER #1 | Sonnet | todo |
| MV3-06 | 3A | plugins: ownership, bench loadout, six effects, pickups `U`, co-op | Sonnet | todo |
| MV3-07 | 3A | tests, build, playtest steps, report → **stop** | Sonnet | todo |
| MV3-08 | 3B | world 2 assets and rendering (tiles, backdrop, platform, liquid); crumbling tiles in co-op | Sonnet | todo |
| MV3-09 | 3B | Mimic, Logger, Noodle, Flaky (exact ports, checked against the JS game); FORK nest | Sonnet | todo |
| MV3-10 | 3B | DEPENDENCY DEPTHS rooms D01–D07; R09's low door opens | Sonnet | todo |
| MV3-11 | 3B | MERGE CONFLICT v2 | Sonnet | todo |
| MV3-12 | 3B | agents; slot keys `k`; gate tiles `&`; cache station `R`; co-op | Sonnet | todo |
| MV3-13 | 3B | the shop `$` (npm registry); co-op purchases | Sonnet | todo |
| MV3-14 | 3B | tests, build, playtest steps, report → **stop** | Sonnet | todo |

---

## 2. Facts already verified (do not rediscover)

- **World 2 levels** of the JS game (extract them with the phase 1 capture tool, target `levels`): `2-1` npm_install.sh 186×22, `2-2` left_pad.js 192×15, `2-3` version_hell.lock 26×52 (vertical: you bash down through cracked floors), `2-B` MERGE CONFLICT arena 24×14 (floor y 176, like NULL's). Letters used there: `m` Mimic, `g` Logger, `n` Noodle, `f` Flaky, `b`, `a`, `t`, `C`, `H`, `M`/`|` platforms, `~` crumbling, `w` liquid, `*` sparks, `T` signs, `P`, `E`.
- **World 2 theme** (`G.THEME[2]` in `// js/world_art.js`): liquid `#c46ad8` / hi `#f6d0ff` / lo `#5a2470`; platform `plat #8f6238`, `platHi #e2b475`, `platLo #4e3220`, accent `#ff8fb0`; music `w2`. `G.platformSprite(w)` takes the **world number**. `G.drawLiquid(g, w, x0, y, x1, y1, t, camX)` draws a surface; LIQ tiles without liquid above them are drawn as two translucent fills (see the "liquid goes over everything" loop in `Level.draw`).
- **JS enemy sources:** `class Logger`, `class Mimic`, `class Noodle`, `class Flaky` in `// js/enemies.js` (short, deterministic except Noodle's dust); their sprites are already in `godot/assets/sprites/` (`logger_*`, `mimic_*`, `noodle_*`, `flaky_*`, `flakyMad_*`). `class Merge` (MERGE CONFLICT v1) in `// js/bosses.js`: two heads (`HEADS`, `headSpr()`), 14 hp each, attacks lunge / spit / slam with ground waves; a conductor alternates heads.
- **JS `class Agent`** is at the top of `// js/player.js` (11 s life, target search within 150 px every time its cooldown allows, `hit(1, …, 'agent')`, bosses halve agent damage).
- **Godot today** (after phase 2 and the co-op review, `ba3aa85..bd7fa16`): boss creation is hard-coded to `NullBoss` with `roundi(60 * boss_hp_mult)` in `Room.load_room`; `_start_reward`/`_finish_reward` hard-code "bash" and `boss:NULL`; `Main.song_for` maps fights to `boss`; `NetClasses` has 6 classes; snapshots carry `en it pj hz p1 fs fa bn sl fx pz`; the capture tool only makes world 1 tiles/backdrop; doors are only W/E (enough for this phase: tall rooms use side doors at the top and the bottom).
- **All phase 3 room maps and door tables below were generated and checked by a script** (every door: cells open, floor under it, the partner door links back, the two door bottoms on the same world row, no two rooms overlapping). Copy them exactly.

---

## 3. Shared definitions (used by both parts)

### 3.1 New map letters

| letter | what | part |
|---|---|---|
| `X` | EXCEPTION (enemy) | 3A |
| `Y` | catch switch (object; pressed by a caught projectile) | 3A |
| `!` | catch gate tile: solid until every `Y` of the room is pressed | 3A |
| `U` | plugin pickup; ids from the room's `plugins` list, in reading order | 3A |
| `B` | boss spawn (exists) | — |
| `D` | end door (exists); its text comes from the room's `end` field | 3A |
| `m` `g` `n` `f` | Mimic, Logger, Noodle, Flaky | 3B |
| `K` | FORK nest (enemy) | 3B |
| `k` | slot key (object inside a wall; only agents can press it) | 3B |
| `&` | agents gate tile: solid until every `k` of the room is pressed | 3B |
| `R` | cache station (object; refills the context meter) | 3B |
| `$` | shop stall (npm registry) | 3B |

`TileGrid`: add `GATE_C = 10` (`!`) and `GATE_A = 11` (`&`) to the constants and `CHARS`; `solid()` returns true for them unless `gates_open.catch` / `gates_open.agents` is true (`var gates_open := {"catch": false, "agents": false}`). The room sets them from flags every step. Closed gate tiles are drawn with the `gate` sprite (as closed doors are); open ones are not drawn.

### 3.2 Flags (in `Game.flags`, saved, sent in `start`)
`switch:<room>:<i>`, `gate:<room>:catch`, `key:<room>:<i>`, `gate:<room>:agents`, `plugin:<id>` (owned, shared by both players), `boss:<id>`, `ability:<name>`, `phase:3b` (never set; it keeps R09's low door closed in 3A).

### 3.3 Abilities
`Game.tools` gets `"catch": false` (in `fresh()` and the declaration). The co-op `ability` event already copies any tool name.

### 3.4 Boss HP formula (decision D9)
`Game.R_PLAYER := 1.0` — claw hits per player per second in a real fight. **Provisional**: Claude replaces it with the value measured from Zakaria's fight list (MV3-01 makes that list visible). Never inline boss HP numbers.
`Game.boss_hp(b: Dictionary) -> int = maxi(1, roundi(float(b.T) * R_PLAYER * float(b.u) * float(dv("boss_hp_mult"))))`. NULL keeps 60 (T 60, u 1).

### 3.5 Difficulty table additions
Add to every row of `Game.DIFF`: `catch_window`: easy 0.14, normal 0.10, hard 0.10, nightmare 0.08 (seconds after a swing starts during which a swipe catches).

---

# PART 3A

## MV3-01 · Boss framework

1. **rooms.json boss entries** now carry everything. R05's entry becomes exactly:
   ```json
   "boss": {"id": "NULL", "class": "NullBoss", "name": "NULL", "sub": "the null pointer", "trigger_x": 80, "T": 60, "u": 1.0, "reward": "bash", "banner": "bash", "banner_sub": "dash in any direction - breaks cracked % walls", "music": "boss", "drop": 24}
   ```
2. **`Room.load_room`:** build the boss from `def.boss.class` (`"NullBoss"`, `"Reviewer"`, `"MergeBoss"`; a `match`, no reflection) with HP `Game.boss_hp(def.boss)` and `drop_n = def.boss.drop`.
3. **`Boss.scale_hp(k: float)`** (base: `max_hp = roundi(max_hp * k); hpf = max_hp; hp = max_hp`); `_begin_fight` calls `boss.scale_hp(1 + coop_hp_pct/100)` instead of touching fields (MERGE overrides it in 3B).
4. **Generic reward:** `_start_reward` uses `def.boss.banner` / `banner_sub` and `def.boss.name` for the statistics line (`"<name> 72s - P1 41 hits - P2 30 hits - r 0.99/s - won"`); fight records use `def.boss.id`. `_finish_reward` sets `Game.tools[def.boss.reward] = true`, flags `ability:<reward>` and `boss:<id>`, saves, and the host sends the existing `ability` event with that name.
5. **Music:** `Main.song_for`: during `intro`/`active` play `def.boss.music`; `reward` stays `toolget`; an empty room song after the fight falls back to `"w%d" % def.get("world", 1)`. Capture tool: copy `tension` (and `tension_hi` if made) into `godot/assets/music/` and add it to `index.json`.
6. **Fight list:** the pause menu gets a `Fights` page: the last 10 entries of `Game.fights` (newest first), one line each: `NULL 72s P1 41 P2 30 r 0.99 won normal`, and at the bottom `average r (won fights): 0.97 over 5 fights`. Guests show "the host keeps the fight list". (Zakaria sends a screenshot of this page; Claude sets `R_PLAYER` from it.) With `?debug`, the page also has `Refight bosses`: it clears every `boss:<id>` flag (abilities, plugins and everything else stay), so a beaten boss can be fought again for more measurements.

**Acceptance:** all existing tests pass unchanged (NULL behaves exactly as before); `--test=bossreg`: R05 builds a `NullBoss` with 60 hp on normal and 78 on hard; after `_finish_reward` `Game.tools.bash` and `boss:NULL` are set; `Fights` page lists a fight added by the test.

## MV3-02 · Rooms R08, R09, R10, R11

**R08.txt** (replace the file; the `D` door goes, the east wall opens):
```text
########################
########################
##                    ##
#                      #
#                      #
#                      #
#                      #
#                      #
#                      #
                        
                        
                        
   C      T             
########################
########################
########################
```
**New rooms** (pad rows to the width; the loader already checks sizes):
```text
# R09.txt  (24 x 32)  Makefile: one-way ledges up to the review room, a low door down to ~/node_modules
########################
########################
##                    ##
#                      #
#                      #
#                       
#                       
#                       
#                    o  
#                  #####
#                      #
#             ====     #
#                      #
#                      #
#        ====          #
#                      #
#    o                 #
#   ====               #
#                      #
#                      #
#        ====          #
#                      #
#              o       #
#             ====     #
#                      #
                        
         ====           
                        
   T                    
########################
########################
########################
```
(Each ledge is 3 rows above the previous one: 48 px, inside the 57 px jump.)
```text
# R10.txt  (24 x 14)  code_review.md: THE REVIEWER #1 arena (floor y 176)
########################
#                      #
#                      #
#                      #
#                      #
#                      #
#                      #
    ====        ====    
                        
                        
                  B     
########################
########################
########################
```
```text
# R11.txt  (32 x 16)  try_catch.js: the catch tutorial. X throws left at you; the caught error flies back right, through X, onto Y; the gate opens
################################
################################
##                            ##
#                              #
#                              #
#                              #
#                              #
#                              #
#                              #
                        !      #
                        !      #
                        !  *   #
   C  T       X     Y   ! U  D #
################################
################################
################################
```
**rooms.json** — replace R08's entry and add these (R09's low door stays closed until 3B by its lock):
```json
"R08": {"file": "R08.txt", "title": "README.md", "size": [24, 16], "origin": [664, 0], "world": 1, "music": "w1", "signs": ["Next door: the ledges go up to a code review; the low door goes down to ~/node_modules."], "doors": [{"id": "R08:W", "side": "W", "a": 9, "b": 12, "to": "R07:E"}, {"id": "R08:E", "side": "E", "a": 9, "b": 12, "to": "R09:W"}]},
"R09": {"file": "R09.txt", "title": "Makefile", "size": [24, 32], "origin": [688, -16], "world": 1, "music": "w1", "signs": ["make review: climb the ledges. make install: the low door on the right."], "doors": [{"id": "R09:W", "side": "W", "a": 25, "b": 28, "to": "R08:E"}, {"id": "R09:NE", "side": "E", "a": 5, "b": 8, "to": "R10:W"}, {"id": "R09:E", "side": "E", "a": 25, "b": 28, "to": "D01:W", "lock": "until:phase:3b"}]},
"R10": {"file": "R10.txt", "title": "code_review.md", "size": [24, 14], "origin": [712, -18], "world": 1, "music": "", "boss": {"id": "REVIEWER1", "class": "Reviewer", "name": "THE REVIEWER", "sub": "changes requested", "trigger_x": 80, "T": 70, "u": 0.7, "reward": "catch", "banner": "catch", "banner_sub": "swipe a yellow attack just as it hits you: it flies back", "music": "tension", "drop": 30}, "signs": [], "doors": [{"id": "R10:W", "side": "W", "a": 7, "b": 10, "to": "R09:NE", "lock": "fight"}, {"id": "R10:E", "side": "E", "a": 7, "b": 10, "to": "R11:W", "lock": "until:boss:REVIEWER1"}]},
"R11": {"file": "R11.txt", "title": "try_catch.js", "size": [32, 16], "origin": [736, -20], "world": 1, "music": "w1", "plugins": ["async_await"], "end": "to be continued in /proc/heap", "signs": ["An EXCEPTION throws yellow errors. Swipe one just as it reaches you to catch it: it flies back. Hit the switch behind it."], "doors": [{"id": "R11:W", "side": "W", "a": 9, "b": 12, "to": "R10:E"}]}
```
Rules:
- Rooms without `"world"` are world 1. The end door reads its text from `def.end` (default `"to be continued"`); the end screen shows it.
- A door whose `to` room is not in rooms.json must never open (R09:E in 3A); `load_meta` must not fail on it.
- **Pause map:** fit the bounding box of the visited rooms into 360×170 px (scale = min(360/width, 170/height, 0.5) px per tile), centred. Current room, benches, players as before.
- Until MV3-05 exists, R10 may build a placeholder boss; do not commit a broken R10.

**Acceptance:** `--test=rooms3`: walk R07→R08→R09 (bottom), teleport onto each ledge in turn and check that one jump reaches the next (scripted hold-jump + steer; `on_ground` on the next ledge within 60 frames), go through R09:NE into R10, and (with `boss:REVIEWER1` set) R10→R11; R09:E is SOLID. Screenshots of R09 and the pause map with everything visited.

## MV3-03 · catch

**Rules (all in one place: `Player.catch_window_open()` and `Room._try_catch()`):**
1. The catch window is open while `Game.tools.catch` and `atk_t > 0.17 - dv("catch_window")` (a swing lasts 0.17 s from its start).
2. **Projectiles:** a projectile is catchable when `q.catchable` is true; catchable projectiles are yellow (`#ffd23f`) — the colour rule, never break it. In `interact_combat`, before the existing "claw cuts projectiles" loop: a catchable, non-friendly projectile overlapping the claw box while the window is open is **caught**: `q.friendly = true; q.vx *= -1.5; q.vy *= -1.5; q.life = 2.0; q.dmg = 2; q.pierce = true; q.hit = {}` (creature nids already hit), white core when drawn. Effects: sound `clang` then `uiOk`, `stop(0.06)`, a yellow ring, `gain_meter()`, a "caught" counter in the fight statistics. Outside the window (or without catch) the old behaviour stays: the claw destroys cuttable projectiles.
3. **Caught projectiles** (in `update_projs`): never hurt players; for every living creature they overlap once (`q.hit`), call `e.hit(q.dmg, signf(q.vx), 0.0, "catch", box)` (bosses take catch damage in full); they press catch switches they touch; they die on solid tiles (gates included) and after `life`.
4. **Strikes** (melee attacks a boss marks as catchable): a boss's `harmboxes()` may include boxes with `"sid": <strike id>, "catchable": true`. A claw box overlapping such a box while the window is open **parries** it: the player gets `parried[sid] = true` (that strike can no longer hurt this player) and the boss's `parried(by, sid)` runs (REVIEWER: stagger). Contact damage skips boxes whose `sid` the player parried.
5. **Switches `Y`:** objects (like springs) at `(x+3, y+3, 10, 10)`; drawn as a round button with `{ }` (`#ffd23f` when off, `#7fd08a` when on). A caught projectile touching one sets `switch:<room>:<i>`; when all switches of the room are set, `gate:<room>:catch` is set (sound `gate`, shake 0.3) and stays.
6. **Co-op:**
   - Projectiles are the host's. The guest checks its own claw against the projectiles it shows: on a catch it reverses its local copy at once (prediction: keep that local copy for up to 0.5 s, or until a snapshot shows the projectile friendly, then follow the snapshots again) and sends the reliable event `catch` `{pid}`. The host catches that projectile with the same function if it still exists, is catchable and not friendly. The snapshot's `pj` records get two more fields: `friendly` (0/1), `catchable` (0/1).
   - Strikes: the guest parries against the harmboxes its puppet computes (so they must come from `net_fields`), keeps its own `parried` set, and sends `parry` `{nid, sid}`; the host calls `boss.parried(remote, sid)` when that strike was active within the last `rtt/2 + 0.35` s.
   - Gate and switch state is **state**: snapshots get `gf` = the list of set `switch:/key:/gate:` flags of the guest's room; the guest applies it every snapshot (and from `start`).
   - Watchdog: a rule `gate_state` (guest): its room's `gates_open` equals what the last `gf` says, after a 1 s grace.

**Acceptance:** `--test=catch`: a test shooter fires a catchable projectile at the player; swinging 2 frames before contact → caught (friendly, reversed ×1.5); swinging 12 frames early → just destroyed; without the ability → destroyed; the caught projectile damages a Bug for 2 and presses a switch; the gate opens and stays open after the room is rebuilt. Co-op scenario `co-catch`: the guest catches a host projectile in R11 → the host's projectile is friendly, the switch is pressed, the gate is open on both pages.

## MV3-04 · EXCEPTION, and the guard's diagonal dash

**EXCEPTION (`X`, `src/enemies/exception.gd`)**, shared state machine, drawn in code:

| item | value |
|---|---|
| hitbox | 12 × 14 |
| HP / contact damage / loot | 3 / 1 / 3 |
| stompable | true |
| behaviour | stands; faces the nearest player; cooldown 2.2 s; when a player is within 180 px horizontally, 40 px vertically and in line of sight: `windup` 0.5 s × `telegraph_mult` (a yellow `!` over its head, body flashes), then throws, then `recover` 0.6 s × `punish_mult` |
| throw | `room.shoot(cx + face*8, y + 5, face*130, 0, {"kind": "err", "col": "#ffd23f", "r": 4.0, "catchable": true, "cut": true, "life": 3.0, "dmg": 1})`, sound `shoot` |
| look | a yellow warning triangle 12×12 (`#ffd23f`, ink outline), black `!` in the middle, two 1-px legs; projectile kind `err` = a yellow disc with a black `!` pixel column |
| net fields | `[state_code, state_t*100]` (+ `NetClasses` entry `exception`) |

**Guard fix:** `Guard.blocks()` compares the side, not the exact value: `signf(dx) == -face` (a diagonal dash from the front is blocked too). Add a test case.

**Acceptance:** `--test=exception` (windup length, throw only in line of sight, projectile catchable), `--test=guard` extended with a diagonal dash from the front → `block`. `parity` covers `exception`.

## MV3-05 · THE REVIEWER #1 (`src/enemies/reviewer.gd`, class `Reviewer`)

A rival duelist (inspired by Hornet / Lace). Floor-based, 14×24, arena R10 (floor y 176). HP from the formula (T 70, u 0.7 → 49 on normal with `R_PLAYER` 1). Drawn in code: grey-blue hoodie `#5a6b8c`, pale face `#f4ede0` with dark square glasses, a red pen-sword `#ff4f6d` (16 px) held forward, ink outline; in the counter stance the pen is raised and a speech bubble `CHANGES REQUESTED?` (tiny font) floats above.

**Attacks** (telegraph and punish times × difficulty multipliers; punish never below 0.4 s):

| attack | phase | telegraph | what happens | damage | catchable | punish |
|---|---|---|---|---|---|---|
| lunge | 1, 2 | 0.55 s: crouch, the pen glints, a dotted line on the floor shows the path | dashes 150 px at 420 px/s toward the target; strike box 18×10 in front of the pen during the dash | 1 | **yes** (parry → stagger 0.9 s) | 0.6 s (turns slowly) |
| comments | 1, 2 | 0.6 s: jumps to y FLOOR−60, raises a hand | throws 3 comment bubbles `//` at the target, at −15°, 0°, +15°, 150 px/s, no gravity, life 2.5 s, kind `comment`, yellow, `catchable: true` | 1 | **yes** (projectiles) | 0.5 s after landing |
| review (counter stance) | 1, 2 | the stance itself: 1.2 s, pen up, speech bubble | a claw or dash hit from a player within 40 px is blocked (`block`, clang) and answered at once with a riposte at that player (slash box 22×16 in front, active 0.12 s); if nobody hits him, he lowers the pen: 0.5 s open window | 1 | no | 0.5 s (only if not provoked) |
| nitpick | 2 only | 0.6 s: taps the pen three times | three slashes 0.35 s apart, each stepping 20 px forward (strike box 20×14); before the third a clear 0.7 s pause with the pen high | slashes 1, 1, **big** | slashes 1–2 yes (a parry staggers 0.9 s and cancels the rest) | 0.9 s after the third |
| shove (anti-camping) | 1, 2 | 0.5 s: arms out | if a player stays within 26 px for 1.2 s while he is idle or in the stance: a 20×20 box around him, knock-back 180 px/s | 1 | no | — |

- **Idle:** keeps 70–110 px from the target, walking at 60 px/s; idle time 0.9 s (phase 2: 0.7 s).
- **Cycle:** phase 1 `lunge → comments → review` repeating; phase 2 (at half HP) `lunge → nitpick → review → comments`, all movement and projectile speeds × 1.15 (never the telegraphs). Phase change: 1.0 s pose (`Hmm. Let me take another look.` bubble), projectiles cleared.
- **Stagger** (`parried()`): 0.9 s × punish_mult, flashes, takes normal damage, sound `clang` + `hit`.
- **Hits:** no knock-back (`kb 0`), flash. Agents and dash deal half, as all bosses.
- **Targeting** (co-op): one target per attack, taken in turns (copy `NullBoss.pick_target/next_target`), aim with `aim_point` (the partner is seen late). The riposte targets whoever hit him.
- **Defeat:** no explosion. `begin_death()` as usual (it appends `bossDying`, clears projectiles), then he kneels 1.5 s with a `LGTM ✓ Approved.` bubble, a white ring, disappears, drops `drop_n` tokens and appends `bossDead` (the framework then runs the reward: catch).
- **Net fields** must give the guest everything its combat reads: `[st_code, st_t*100, phase, strike_sid, hpf*10, max_hp, target_is_p2]`; `harmboxes()` (body + current strike box with `sid`/`catchable`) and `blocks()` (true in the stance) must be computable from them. Register `reviewer` in `NetClasses`. The `parity` test must pass for R10.

**Acceptance:** `--test=reviewer`: a bot stands still with invulnerability; the boss goes through every attack of both phases within 120 s and never stays in one state longer than 6 s; a test parry during a lunge staggers him; hitting him in the stance gives `block` and a riposte; standing next to him triggers the shove; dealing damage by test kills him → `catch` granted, `boss:REVIEWER1` set, R10's east door opens. Co-op scenarios `co-reviewer` (both fight: attacks alternate targets, the guest is hurt by strikes through its own contact check, the guest's parry staggers the host's boss) and `co-reviewer` with `SIM_LAG=150 SIM_JITTER=60`. Screenshots of each telegraph.

## MV3-06 · Plugins

1. **Table** (`Game.PLUGINS`, ordered):

   | id | name | cost | effect while equipped | price | where |
   |---|---|---|---|---|---|
   | `async_await` | async/await | 2 | dash cooldown 0.2 → 0.1 s | — | R11, behind the catch gate |
   | `cache` | cache | 1 | pickup radius × 2.5; loose tokens within 64 px fly to you | — | D07 (3B) |
   | `hot_reload` | hot-reload | 2 | focus 0.9 → 0.6 s | 90 | shop (3B) |
   | `eslint_fix` | eslint --fix | 1 | context meter +5 per hit | 60 | shop (3B) |
   | `try_finally` | try/finally | 1 | invulnerability after a hit +0.4 s | 80 | shop (3B) |
   | `rubber_duck` | rubber duck | 2 | claw damage × 2 while hp is 1 | 140 | shop (3B) |

   `Game.NOTCHES := 3` (the "context window"). Owned = flag `plugin:<id>` (shared by both players). Equipped = `Game.equipped: Array` (saved in the save; the guest keeps its own in `user://profile.json`).
2. **Effects** through one function per number (`Game.mod_dash_cd()`, `mod_focus_time()`, `mod_meter_bonus()`, `mod_inv_bonus()`, `mod_claw_mult(hp)`, `mod_pickup_radius()`); the player and the room call those, nothing else checks plugin ids.
3. **Pickup `U`:** item kind `plugin` (a 10×10 chip: dark `#231d2e` square, `#58f0c8` pins, a blinking dot); collecting sets `plugin:<id>`, shows a banner `<name>` / `plugin - equip it at a bench` for 2 s, sound `gate`, saves.
4. **Bench menu → `Plugins` page:** every owned plugin as a row `[x] async/await ●●`; JUMP/tap toggles it if the notches allow; the header shows `context 2/3`. Equipping is only possible at a bench. The pause menu shows the equipped list (read only).
5. **Co-op:** the guest sends the reliable event `loadout` `{ids}` on `ready` and whenever it changes. The host uses the guest's loadout for what the host decides: the pickup check radius (`cache`) and the claw damage check: allowed damage = (2 if opus else 1) × (2 if `rubber_duck` equipped and the guest's reported hp is 1 else 1). New pickups/purchases reach the guest with the reliable event `plugin` `{id, by}`; snapshots also carry `pl` = the owned plugin ids (state).

**Acceptance:** `--test=plugins`: equipping refuses a 4th notch; each effect changes exactly its number (measure: dash cooldown frames, focus duration, meter after one hit, inv after a hit, claw damage at hp 1 and 2, pickup distance); all parity tapes unchanged with nothing equipped. Co-op `co-plugins`: the guest with `cache` picks a token from 20 px and the host accepts it; with `rubber_duck` at hp 1 a guest hit of 2 is accepted, a hit of 3 is not.

## MV3-07 · 3A: tests, build, playtest, report — then stop

1. Add every new test and scenario to `test-all.sh`; `BADLINE_ALL=1 bash tools/godot/coop-test.sh all` once (all pass).
2. `bash tools/godot/test-all.sh` → `ALL PASS`; the export is its own last commit.
3. `docs/reports/metroidvania-phase3a.md` (Persian): what was built, tests, deviations, build size, known problems.
4. Final message to Zakaria (Persian), these steps verbatim:
   1. `update.bat` رو بزن.
   2. رو PC: `http://localhost:3000/mv/` → `Continue` (ذخیره‌ی قبلی‌ت سر جاشه) → `Host co-op` اگه رفیقت هست.
   3. از اتاق `README.md` برو راست تو `Makefile`، از سکوها برو بالا: THE REVIEWER اونجاست.
   4. بعد از بردن، تو `try_catch.js` با `catch` کلید رو بزن و پلاگین `async/await` رو بردار، رو نیمکت سوارش کن.
   5. چند بار با REVIEWER بجنگید. برای دوباره جنگیدن بعد از بردن: آدرس رو با `?debug` باز کن (`http://localhost:3000/mv/?debug`)، از منوی توقف برو `Fights` و `Refight bosses` رو بزن. آخرش از صفحه‌ی `Fights` اسکرین‌شات بگیر.
   6. بگو: لحظه‌ی catch سخت بود یا راحت؟ REVIEWER منصفانه بود؟ پلاگین‌ها رو فهمیدی؟
5. Stop. 3B starts in a new session when Zakaria says so.

---

# PART 3B

## MV3-08 · World 2 assets and rendering; crumbling tiles in co-op

1. **Capture tool:** `tiles`, `bg` and a new `theme` target take the worlds `1,2` (default both): `tiles/w2_tiles.png` (same atlas layout as world 1, drawn with world 2), `bg/w2.png`, `sprites/platform_w2.png` (`G.platformSprite(2)`), `theme/w2.json` (`G.THEME[2]` as JSON). Music: copy `w2` (+ `w2_hi` if it exists). Copy all into `godot/assets/`.
2. **Room view:** pick the atlas, backdrop, platform sprite and theme from `def.world`.
3. **Liquid (`w`):** port the JS drawing: for every column, a LIQ run whose top has no LIQ above gets `G.drawLiquid` (surface line wobbling with time and camera x, body fills `liq` 50 % and `liqLo` 45 %); other LIQ tiles get the two translucent fills. Liquid draws over everything (z above creatures and players). Hazard behaviour already exists.
4. **Crumbling tiles in co-op** (the old game needed this; world 1 had none): the guest's body starting a crumble predicts it locally and sends the reliable event `crumble` `{tx, ty}`; the host starts it if that tile is CRUMBLE and the guest's recent reports put it standing on it; snapshots carry `cr` = `[[tx, ty, s, t*100], ...]` for the guest's room and the guest's grid follows them (its own prediction expires after 1 s without a confirmation). Watchdog rule `crumble_state` (guest): a crumble the host does not list is gone after 1 s.

**Acceptance:** screenshots of a world 2 room with liquid (static `--scene=room:D01` after MV3-10, or a test room now); `--test=crumble` (timings as JS: stand → falls after 0.42 s → back later, read `Level.update`'s crumble code for the numbers); co-op `co-crumble`.

## MV3-09 · Mimic, Logger, Noodle, Flaky; FORK

1. **Exact ports** of `Mimic` (`m`), `Logger` (`g`, projectile kind `log`: port its look from the JS projectile drawing), `Noodle` (`n`), `Flaky` (`f`). Each gets `net_fields()` with every state its harmboxes and drawing need, and a `NetClasses` entry.
2. **Enemy parity against the JS game** (`tools/godot/parity/enemy-trace.js` + `--test=etrace:<class>:<x>:<y>:<px>:<py>:<frames>` + `compare.py`): in the NULL arena (JS level `1-B` with `L.ents.length = 0; L.boss = null`; Godot room R05 with `boss:NULL` set), create one creature with the constructor arguments (x, y) = the top-left of its tile, exactly as the level loader passes them (JS: `new G.Enemies.Mimic(L, 192, 160)`), put the player (invulnerable, standing still) at (px, py), step N frames, write `frame,x,y,vx,vy` per frame. Cases, pass = within 0.01 px on every frame:

   | creature | x, y | px, py | frames |
   |---|---|---|---|
   | Bug | 96, 160 | 300, 166 | 240 |
   | Mimic | 192, 160 | 230, 166 | 240 |
   | Noodle | 96, 160 | 260, 166 | 300 |
   | Logger | 80, 160 | 240, 166 | 300 |
   | Flaky | 144, 112 | 260, 166 | 300 |

   These positions keep every creature away from R05's door openings (the JS arena has walls there). Typo is excluded (it uses random numbers).
3. **FORK (`K`, `src/enemies/fork.gd`)**: a nest 14×12, HP 4, loot 2, not stompable, contact damage 1, does not move. While a player is within 200 px and fewer than 4 of its children are alive: every 3.0 s it shakes 0.4 s (telegraph) and spawns a small Bug (the existing `Bug`, loot 0) at its side through a new `room.add_entity(e)` (nid, difficulty scaling, list). Look: a dark `#3a3346` mound with a `#ffd97a` `fork()` label in the tiny font and a door-like hole. Net fields `[state_code, state_t*100]`.

**Acceptance:** all five enemy traces pass; `--test=w2enemies` (Mimic wakes at 46 px and pops `DEPRECATED!`; Noodle revs then charges; Logger fires `log` projectiles; Flaky swoops); `--test=fork` (never more than 4 children; stops when destroyed); `parity` covers the new classes.

## MV3-10 · DEPENDENCY DEPTHS: rooms D01–D07

1. Add to `godot/src/world/room_edits.json` and generate with `tools/godot/make-rooms.py`:
   ```json
   "D01": {"from": "2-1", "edits": [[2, 8, "P", " "], [181, 13, "E", " "], [60, 4, "*", "o"], [173, 11, "*", "o"]]},
   "D02": {"from": "2-2", "edits": [[2, 11, "P", " "], [188, 5, "E", " "], [173, 4, "*", "o"], [118, 6, "*", "o"]]},
   "D03": {"from": "2-3", "edits": [[3, 3, "P", " "], [20, 49, "E", " "], [3, 21, "*", "o"], [23, 41, "*", "o"], [0, 1, "#", " "], [0, 2, "#", " "], [0, 3, "#", " "], [25, 45, "#", " "], [25, 46, "#", " "], [25, 47, "#", " "], [25, 48, "#", " "], [25, 49, "#", " "]]},
   "D05": {"from": "2-B", "edits": [[12, 10, "P", "B"], [0, 7, "#", " "], [0, 8, "#", " "], [0, 9, "#", " "], [0, 10, "#", " "], [23, 7, "#", " "], [23, 8, "#", " "], [23, 9, "#", " "], [23, 10, "#", " "]]}
   ```
   One memory fragment stays in each of D01 (inside the cracked pocket at 111,13), D02 (the pocket at 90,5) and D03 (the pocket at 24,17); with R11's they are 4 more fragments (+1 max hp).
2. New rooms (the maps below start at column 0 on purpose: copy them exactly):

```text
# D04.txt  (32 x 16)  package.json: bench and the npm registry
################################
################################
##                            ##
#                              #
#                              #
#                              #
#              oo              #
#           ========           #
#                              #
                                
                                
                                
      C   T           $         
################################
################################
################################
```
```text
# D06.txt  (40 x 16)  symlink.sh: cache station R, FORK K, slot key k inside the wall block, agents gate &, end door D, east door to the secret
########################################
########################################
##                                    ##
#                                      #
#                       #####          #
#                       #####          #
#                       ##k##          #
#                       #####          #
#                       #####          #
                               &        
                               &        
                               &        
   R      K   T     D          &        
########################################
########################################
########################################
```
```text
# D07.txt  (24 x 16)  .npmrc: the secret behind the agents gate
########################
########################
##                    ##
#                      #
#                      #
#                      #
#                      #
#                      #
#                      #
                       #
                       #
                       #
     T      U  o o o   #
########################
########################
########################
```

3. **rooms.json:** remove R09:E's `lock`, add:
   ```json
   "D01": {"file": "D01.txt", "title": "npm_install.sh", "size": [186, 22], "origin": [712, 4], "world": 2, "music": "w2", "signs": ["~/node_modules: 1,042 packages, and each one needs three more. Keep your bash ready.", "BASH works in mid-air too. Jump, then bash across."], "doors": [{"id": "D01:W", "side": "W", "a": 5, "b": 8, "to": "R09:E"}, {"id": "D01:E", "side": "E", "a": 10, "b": 13, "to": "D02:W"}]},
   "D02": {"file": "D02.txt", "title": "left_pad.js", "size": [192, 15], "origin": [898, 6], "world": 2, "music": "w2", "signs": ["These packages were unpublished. They crumble when you stand on them."], "doors": [{"id": "D02:W", "side": "W", "a": 8, "b": 11, "to": "D01:E"}, {"id": "D02:E", "side": "E", "a": 2, "b": 5, "to": "D03:W"}]},
   "D03": {"file": "D03.txt", "title": "version_hell.lock", "size": [26, 52], "origin": [1090, 8], "world": 2, "music": "w2", "signs": ["The way on is DOWN. Jump, hold [down] and press [dash] to bash through the cracked floor."], "doors": [{"id": "D03:W", "side": "W", "a": 1, "b": 3, "to": "D02:E"}, {"id": "D03:E", "side": "E", "a": 45, "b": 49, "to": "D04:W"}]},
   "D04": {"file": "D04.txt", "title": "package.json", "size": [32, 16], "origin": [1116, 45], "world": 2, "music": "w2", "signs": ["Rest here. The npm registry sells plugins for tokens: stand at the stall and press [up]."], "doors": [{"id": "D04:W", "side": "W", "a": 9, "b": 12, "to": "D03:E"}, {"id": "D04:E", "side": "E", "a": 9, "b": 12, "to": "D05:W"}]},
   "D05": {"file": "D05.txt", "title": "MERGE CONFLICT", "size": [24, 14], "origin": [1148, 47], "world": 2, "music": "", "boss": {"id": "MERGE", "class": "MergeBoss", "name": "MERGE CONFLICT", "sub": "both modified: everything", "trigger_x": 80, "T": 90, "u": 1.0, "reward": "agents", "banner": "agents", "banner_sub": "full context meter: tap [special] - two helpers hunt for 11 s", "music": "boss", "drop": 40}, "signs": [], "doors": [{"id": "D05:W", "side": "W", "a": 7, "b": 10, "to": "D04:E", "lock": "fight"}, {"id": "D05:E", "side": "E", "a": 7, "b": 10, "to": "D06:W", "lock": "until:boss:MERGE"}]},
   "D06": {"file": "D06.txt", "title": "symlink.sh", "size": [40, 16], "origin": [1172, 45], "world": 2, "music": "w2", "end": "to be continued in /net", "signs": ["A slot too small for you. With a full context meter, tap [special]: your agents fly in and press it. The cache server refills the meter."], "doors": [{"id": "D06:W", "side": "W", "a": 9, "b": 12, "to": "D05:E"}, {"id": "D06:E", "side": "E", "a": 9, "b": 12, "to": "D07:W"}]},
   "D07": {"file": "D07.txt", "title": ".npmrc", "size": [24, 16], "origin": [1212, 45], "world": 2, "music": "w2", "plugins": ["cache"], "signs": ["A hidden .npmrc. Someone left a plugin here."], "doors": [{"id": "D07:W", "side": "W", "a": 9, "b": 12, "to": "D06:E"}]}
   ```
4. **One-way stretch:** D03 is entered at its top and left at its bottom; climbing back up is not intended. Its bench (11,33) and D04's bench make bench travel the way back (rule R3 of `03-abilities-and-gates.md`). Do not add ladders.

**Acceptance:** `--test=rooms3b` walks every new door in both directions (except D03 upward, which it reaches by bench travel); `parity` passes over all rooms; screenshots of D01, D03 (top and bottom), D04, D06.

## MV3-11 · MERGE CONFLICT v2 (`src/enemies/merge_boss.gd`, class `MergeBoss`)

1. **Port v1 first** (heads, `HEADS` colours and glyph trails, lunge / spit / slam, the ground `wave` projectile and its drawing, the conductor). Capture the head sprites: add to the capture tool's `boss` target the `headSpr` function and the `HEADS` data from `// js/bosses.js` → `merge_head_<i>_<open>.png`, `merge_dead_<i>.png`.
2. **HP:** the formula (T 90, u 1.0) gives the total; each head gets `ceili(total / 2)` (45 on normal). `hp`/`hpf`/`max_hp` are the sums; `hit()` with a box that is not a head damages the head with more hp; `scale_hp(k)` scales both heads.
3. **Changes from v1:**
   - **Conflict markers** replace v1's double slam (conductor step `k == 4` with two heads): both heads rise to the top corners (0.6 s), then **1.0 s telegraph** × telegraph_mult: three dashed bands across the arena with their glyphs — high band H (y 48–96) `<<<<<<<`, middle band M (y 96–144) `=======`, low band L (y 144–176) `>>>>>>>`. One of L or M (random) is drawn green `✓ resolved` and is safe; H is never safe. Then the two unsafe bands fire for 0.35 s (damage 1). Standing on the floor = band L, standing on a platform (row 8, top y 128) = band M. **One head left:** the bands fire one after another, L, M, H, 0.25 s apart ("less in sync").
   - **Revert:** when one head dies and the other lives, a `git revert in 8` countdown floats over the dead head; if the other head is not killed within 8 s, the dead head comes back with half of its max hp (`git revert` pop, sound `glitch`). Both dead within the window = defeated.
   - **Slam** contact damage is **big**.
   - **Co-op targeting:** with two players head 0 targets P1 and head 1 targets P2 (a lone head takes turns, as NULL).
4. **Harm:** head bodies, lunges, slams and the active bands are all in `harmboxes()`, computed from net fields (per head `[x4, y4, hp, st_code, t*100, open, dead, revert_t*10, aim_x4, aim_y4]` plus `[band_state, safe_band, band_t*100]`); waves and spit are projectiles (already sent). Register `merge` in `NetClasses`; `parity` must pass for D05.

**Acceptance:** `--test=merge`: the safe band is never H and never hurts; killing head 0 and waiting 8 s brings it back with half hp; killing both within 8 s ends the fight → `agents` granted, `boss:MERGE` set, D05's east door opens. Co-op `co-merge` (heads target different players; a band hurts the guest through its own contact check; the revert countdown shows on the guest).

## MV3-12 · agents; slot keys; agents gates; cache station

1. **agents** (`src/player/agent.gd`, port of `class Agent`): with `Game.tools.agents` and a full meter (`>= METER_MAX`), **tap** `special` (pressed and released within `FOCUS_HOLD`, focus not started) → `meter = 0`, two agents for 11 s, sound `agent`, pop `Task(subagent) x2`. Holding `special` still focuses (heal). Agents ignore tiles, seek the nearest target within 150 px of their owner (creatures that can be hit, and **slot keys**), hit for 1 (`how = "agent"`; bosses halve it), cooldown 0.85 s, sound `agentHit`. Drawn with the captured `agent_0/1` sprites and their trail.
2. **Slot keys `k`:** objects inside wall blocks (10×10 at the tile); claws never reach them; an agent hit sets `key:<room>:<i>`; when all keys are set, `gate:<room>:agents` opens the `&` tiles (sound `gate`). Drawn as a small key in a slot (`#ffd97a` on `#231d2e`), lit when pressed.
3. **Cache station `R`:** touching it fills the meter to `METER_MAX` (pop `cache hit`, sound `agent`), then 20 s cooldown per player (dimmed while cooling down). Drawn as a 12×16 server rack with blinking `#58f0c8` lights.
4. **Co-op:** the host simulates every agent, including the guest's: the guest taps → empties its own meter → reliable event `agents` `{}` → the host gives the guest's `RemotePlayer` two agents. Snapshots carry `ag` = `[[owner(1|2), x4, y4], ...]`; the guest draws them. Cache station use by the guest: the guest fills its own meter locally (its body) when it touches one that is not cooling down on its page; the host does nothing. Watchdog rule `agent_owner` (host): no agent outlives its owner leaving the room.

**Acceptance:** `--test=agents` (tap vs hold; agents kill a Bug; agents press D06's key and the gate opens; the cache station refills once per 20 s); co-op `co-agents` (the guest's agents appear on both pages and press the key).

## MV3-13 · The shop (npm registry)

1. **Stall `$`:** drawn as a 24×24 booth (`#8f6238` wood, `#e2b475` top, `npm` in the tiny font on a `#ff4f6d` sign, a little Clawd-sized vendor face). Stand near it and press `up` → the shop page: every plugin with a price that is not owned yet, `name - cost - price`, plus your tokens. JUMP/tap buys if tokens ≥ price: tokens drop, `plugin:<id>` set, sound `token` three times, pop `npm install <name>`, save.
2. **Plugin `U` in D07** (`cache`) works through MV3-06.
3. **Co-op:** the guest's wallet is its own (profile). The guest buys → reliable event `buy` `{id}` → the host sets the flag if it is not owned and answers `plugin` `{id, by: "p2"}`; the guest pays only when that answer arrives (no double payment if both buy at once; the second buyer gets `by: ""` and pays nothing).

**Acceptance:** `--test=shop` (not enough tokens → refused; bought item leaves the list; saved); co-op `co-shop` (the guest buys with its own tokens; the host's flag is set; a simultaneous double buy charges one player).

## MV3-14 · 3B: tests, build, playtest, report — then stop

1. Everything in `test-all.sh`; `BADLINE_ALL=1 bash tools/godot/coop-test.sh all` once.
2. `bash tools/godot/test-all.sh` → `ALL PASS`; the export is its own last commit.
3. `docs/reports/metroidvania-phase3b.md` (Persian).
4. Final message to Zakaria (Persian), these steps verbatim:
   1. `update.bat` رو بزن.
   2. `http://localhost:3000/mv/` → `Continue` → `Host co-op` (رفیقت با `/mv/?debug` و `Join co-op`).
   3. از `Makefile` در پایین سمت راست رو برو: `~/node_modules` (DEPENDENCY DEPTHS).
   4. تو `package.json` از `npm registry` با توکن‌هات پلاگین بخر و رو نیمکت سوار کن.
   5. با MERGE CONFLICT بجنگید (دو تا سر: با هم بکشیدشون، وگرنه `git revert` برمی‌گرده).
   6. بعدش تو `symlink.sh` با meter پر یه ضربه‌ی کوتاه رو `special` بزن: agents کلید رو می‌زنن.
   7. صفحه‌ی `Fights` رو اسکرین‌شات بگیر و بفرست.
   8. بگو: DEPTHS زیادی سخت یا آسون بود؟ فروشگاه و پلاگین‌ها جالب بودن؟ MERGE CONFLICT منصفانه بود؟
5. Stop.

---

## Appendix A · Where things are

JS (`public/index.html`): `// js/player.js` (`class Agent` at the top), `// js/enemies.js` (`Logger`, `Mimic`, `Noodle`, `Flaky`, `MAKE` letters), `// js/bosses.js` (`class Merge`, `HEADS`, `headSpr`), `// js/level.js` (crumble update, LIQ drawing, projectile kinds), `// js/world_art.js` (`G.THEME`, `G.drawLiquid`, `G.platformSprite`).
Godot (`godot/src`): `world/room.gd` (load_room, boss creation, interact_combat, update_projs, harm_zone, fight flow), `world/room_manager.gd` (doors, travel), `core/tile_grid.gd`, `enemies/boss.gd` + `null_boss.gd` (targeting, aim_point, net fields), `net/coop.gd` (events, `_send_snapshot`, `_apply_snapshot`), `net/net_classes.gd`, `net/watchdog.gd`, `ui/bench_menu.gd`, `ui/pause.gd`, `main.gd` (`song_for`), `autoload/game.gd` (DIFF, flags, save, tools), `test/run_tests.gd` (`t_parity`), `test/coop_scenarios.gd`.
