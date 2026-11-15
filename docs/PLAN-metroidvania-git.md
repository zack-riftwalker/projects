# CLAWD Metroidvania — Phase 5B Plan: GIT HISTORY (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای سشن‌های ساخت نوشته شده و انگلیسیه. طراحیش (فارسی): [`metroidvania/19-git-history.md`](metroidvania/19-git-history.md). **پیشنهاده: تا تأیید تو و تموم شدن ساخت INFINITE LOOP ساخته نمی‌شه.**
>
> **چی ساخته می‌شه:**
> - **۱۶ اتاق GIT HISTORY.** نقشه‌ها رو بخش دنیا کشیده و با شبیه‌ساز چک کرده (۰ مشکل). مسیر اصلی فقط با bash، catch و ssh رد می‌شه.
> - **دو شاخه و یه merge:** از هاب G03 دو راه؛ ته هر کدوم یه کلید؛ درِ merge با هر دو باز می‌شه.
> - **checkout:** اهرمی که بلوک‌های سبز `+` و قرمز `−` رو عوض می‌کنه (G04 سه نسخه، G09 دو حالت).
> - **revert:** نشانگر بذار، بعداً برگرد بهش. نشانگر روی صفحه‌ی فشاری، دروازه رو باز نگه می‌داره. جایزه‌ی REGRESSION (فعلاً یه باس موقت).
> - **دو دشمن تازه:** POLYMORPHIC (با هر ضربه نوعش عوض می‌شه) و STASH (جای ۳ ثانیه پیشت رو می‌زنه)؛ به‌علاوه‌ی نسخه‌ی سپیای دشمن‌های اول.
> - **رازها:** old/hello_world.py و symlink به خونه، stash@{0} با b02، initial_commit (بسته تا --force).
>
> **برای دادن به یه سشن:** «فایل `docs/PLAN-metroidvania-git.md` رو بخون و کار MVG-0X رو انجام بده.» تهیه‌کننده برای هر کار یا گروه کار یه دستور کار می‌نویسه.

---

## 0. Rules of engagement

- **Start only when both hold:** Zakaria approved `docs/metroidvania/19-git-history.md` (its status table says so, or `docs/studio/PRODUCER.md` lists it as approved), and the INFINITE LOOP v3 build (`docs/metroidvania/18-loop-build.md`) is done. If not, stop and say so.
- **Read first, in order:**
  1. `CLAUDE.md`.
  2. This file, all of it.
  3. `docs/metroidvania/19-git-history.md` (the design, Persian; this file is its English spec).
  4. `docs/PLAN-metroidvania-phase5a.md` and `docs/reports/metroidvania-phase5a.md` (the model: tower machines, mutex keys `Q` and gates `4`, levers, k-of-n locks, world-flag rules, the 4B-1 systems).
  5. `docs/studio/WORLD.md` (abilities, gates, the black agent shadow), `docs/studio/STORY.md` (tone of the signs).
  6. Then the code you change.
- **One task (or the group your brief names) per session.** Stop after it and report.
- **Do not redesign.** Values, letters, room files and JSON here and in `docs/metroidvania/phase5b-data/` are proposals Zakaria approved by approving doc 19. If one is impossible, take the smallest change that keeps the goal and list it under deviations. **Never edit a room file by hand**: change `phase5b-data/rooms.py`, run it, re-run `apply.py`, `check5b.py` (`0 problems`) and `world.py` (`errors 0`), and re-render `render.py`.
- **Difficulty:** the level of THREAD TOWER. Do not make anything easier than written.
- **Branch:** `ph1` only. `git pull origin ph1` before you start and before each commit. Never push to `main`, never open a PR.
- **Files you may touch:** `godot/`, `tools/godot/`, `docs/metroidvania/` (data and reports), `docs/reports/metroidvania-phase5b*.md`, this plan's status table, and on the last task of a group `docs/studio/PRODUCER.md` (tick) and `docs/studio/PLAYTEST.md` («منتظر تست»). Not `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`, other departments' docs (only their «صندوق»). `public/mv/` only through `export-web.sh`, as the last commit.
- **Commits:** one per task (`MVG-xx: <what>`), with your session's attribution lines. Push after each.
- **Co-op rules** (CLAUDE.md; not optional): state over events (checkout revisions, plates, keys, markers are state in snapshots); what the guest's combat reads goes through `NetClasses.record/apply` and `parity`; host-side harm to P2 through `room.harm_zone`; a new co-op bug class gets a watchdog rule; never an event field named `i` or `k`.
- **Speed rules** (CLAUDE.md): nothing per frame walks `Game.flags`; static drawing is drawn once. Measure G02 and G14 (the long rooms) with `--test=perfrooms` before and after.
- **Godot naming trap:** never name members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Tests:** every task names its tests; before the last commit of a group `bash tools/godot/test-all.sh` → `ALL PASS`; new `--test=`s in its list, new scenarios in `ALL=`.

## 1. Status

| task | what | status |
|---|---|---|
| MVG-01 | room data in (16 rooms, N17 edit); checkers (`check5b.py`, four `world.py` gates) | ⬜ |
| MVG-02 | world 7 look: sepia tiles and backdrop, theme, music `w7` | ⬜ |
| MVG-03 | machines: checkout blocks `6 7 8` and levers, branch keys `9`, plates `Q`+`4` with latches, package-lock `_`, reflog lever, end door | ⬜ |
| MVG-04 | revert (the ability) + the placeholder REGRESSION fight | ⬜ |
| MVG-05 | enemies: POLYMORPHIC, STASH, the v0.1 variants | ⬜ |
| MVG-06 | the systems in GIT (zone, `tree`, agent, page, fragment, terminal, changelog, S6 signs, graph, pedestals, mirror, aftermath, symlink) | ⬜ |
| MVG-07 | walk-through tests, co-op scenarios, watchdog rules, bad line | ⬜ |
| MVG-08 | tests, export, playtest steps, report — then stop | ⬜ |

Suggested briefs: (01+02), (03+04), (05+06), (07+08).

## 2. Facts (checked by the world department on `ph1`, 2026-11-15)

- 84 rooms in `rooms.json`; GIT HISTORY has none. `N17:S` leads to `G01:N` and is an end door today (`end`, a `D` cell at (20, 80)).
- `R06:W` is already a symlink door to `G16:E`, locked `until:link:src`. Doors with `"sets"` set a flag when crossed (`room_manager.gd`).
- `Game.ZONES` already has `git` (`.git`, `#e6783c`); `Game.MEMORIES["G15"]` and `Game.LOGBOOK[4]` exist.
- `Game.tools` has 8 abilities; `revert` and `force` are not there.
- Crumble tiles `~` already break and grow back after 2.6 s (`room.gd` `_step_crumble`); the bridges use them as they are.
- k-of-n locks (`until:2of:...`), levers `I` (`lever:<id>` flags) and mutex keys `Q` + gates `4` exist (5A).
- `docs/metroidvania/phase5b-data/check5b.py` → `0 problems`; `world.py` (design) → `errors 0`; on a copy after `apply.py`, `world.py` only lacks the four new lock names (MVG-01).
- `godot/src/enemies/kit_dummy.gd` (`KitDummy`) is the kit's test boss; MVG-04 uses it as the placeholder REGRESSION.

## 3. Shared definitions

### 3.1 The data (`docs/metroidvania/phase5b-data/`)

| file | what |
|---|---|
| `rooms.py` | draws the 16 rooms (`canvas.py`); writes `rooms/G*.txt` and `rooms-5b.json`. The letter list is at its top. |
| `room-edits-5b.json` | N17: the `D` cell at (20, 80) becomes air; `end` is removed. |
| `apply.py` | copies the rooms, applies the edits, merges `rooms-5b.json` into `rooms.json` (tested on a copy: 100 rooms). |
| `check5b.py` | static checks + reachability with `sim.py`/`reach.py` (all with bash, catch, ssh only). |
| `render.py` | `git-history.png`. |

### 3.2 GIT at a glance

```
N17 ─▶ G01 HEAD ─ G02 git_log ─ G03 branch (terminal)
                    │ (bash)       ├─ W: G04 feature/a ─(N, b02)─ G05 stash@{0}
                   G16 old/ ─symlink─▶ R06     └─ S: G09 checkout (key A) ─▶ G08
                                   └─ S: G06 feature/b ─ G07 bisect (key B) ─ G10 cherry-pick ─▶ G08
G08 merge ─(both keys)─▶ G11 bench ─ G12 REGRESSION ─ G13 reflog ─ G14 revert.sh ─▶ P07 (end door until PRODUCTION)
                                                       │(N hatch, lever)   └─(_ --force)─ G15 initial_commit
                                                       └──▶ G10
```

### 3.3 New letters

| letter | what | behaviour |
|---|---|---|
| `6` | checkout block `+` (green) | solid when the room's revision is in `checkout.solid["6"]`, else air. Never turns solid on a body (wait until it is clear, like blink blocks). |
| `7` | checkout block `-` (red) | same with `checkout.solid["7"]`. |
| `8` | stash plug (purple) | same with `checkout.solid["8"]` (G04: open only at b02). |
| `9` | branch key | a pickup; sets the room's `key` flag (`branch:a` G09, `branch:b` G07) for both players. Drawn: a golden key with a branch glyph. |
| `_` | package-lock floor | solid; broken by `--force` (later phase 5C). Drawn: a lead-grey slab with a padlock and chain. |
| `<` | POLYMORPHIC | enemy (MVG-05). |
| `>` | STASH | enemy (MVG-05). |

Reused: `Q` + `4` (mutex key look and gate) as **plates** (3.4), `I` levers, `~` crumble, `D` end door, `B` boss spawn.

### 3.4 New `rooms.json` fields

| field | rooms | meaning |
|---|---|---|
| `checkout: {start, order, solid}` | G04, G09 | the revision state of the room: starts at `start`; every lever `I` in the room moves it to the next in `order` (wrapping). Saved as world flag `checkout:<room>:<rev>` (exactly one per room); the door lock `until:checkout:G04:b02` reads it. |
| `key` | G07, G09 | the flag the `9` pickup sets. |
| `plates: [{key, cols, latch}]` | G13, G14 | `key` is the plate cell (`Q`). While a body **or a revert marker** stands on it, the `4` cells in the listed columns are open. `latch` is a lever cell: pulling it sets `latch:<room>:<n>` and the gate stays open for good. |
| `panel: {levers, order}` | G15 | Panel F (K3): the four levers pulled in `order` (1-based indices of `levers`) set `panel:F`; a wrong lever resets the sequence (a click, no harm). |
| `variants: {"b": "v0.1", ...}` | G02, G06 | letter → old-version variant (MVG-05). |
| decor kinds `graph`, `pedestal`, `mirror`, `cursor`, `shadow` | G03, G08, G11, G16, G02 | MVG-06. |
| door `sets` | G16:E | `link:src` (already supported). |

### 3.5 Flags

`branch:a`, `branch:b`, `checkout:G04:b01|b02|b03`, `checkout:G09:a|b`, `lever:reflog`, `latch:G13:0`, `latch:G14:0..2`, `panel:F`, `boss:REGRESSION`, `link:src` (exists), `shadow:git`. All world flags: add their heads to `WORLD_PREFIXES` / `_WORLD_HEADS` (`branch`, `checkout`, `latch`, `panel`, `shadow`).

### 3.6 Constants (proposals in doc 19)

| name | value | why |
|---|---|---|
| `REVERT_MARKERS` | 1 per player | 03: one marker. |
| revert input | [down]+[special] places; [special] with no other target recalls | GET rings and breakpoint targets keep priority. |
| recall | instant teleport + 0.3 s of the marker's glow; the marker is used up | readable on the guest's page. |
| crumble regrow | 2.6 s (as built) | no softlock on a bridge. |
| STASH | delay 3.0 s, tell 0.7 s, hidden otherwise | foreshadows REGRESSION (5 s). |
| POLYMORPHIC | 4 hp, cycle Bug → Typo → Guard | D36. |

## MVG-01 · Room data and checkers

1. `python3 -I docs/metroidvania/phase5b-data/apply.py` (16 rooms; N17 edit; 100 rooms in `rooms.json` if nothing else was added).
2. Copy `check5b.py` to `tools/godot/roomcheck/` (fix its `ROOT`/data paths like `check5a.py`); add `run check5b ...` to `test-all.sh` next to the other checkers. `check4a/4b2/4b3/5a` stay `0 problems`.
3. **`world.py`:** `GATES` += `"until:checkout:G04:b02"`, `"until:lever:reflog"`, `"until:2of:branch:a,branch:b"`, `"until:boss:REGRESSION"` → `errors 0` after apply.
4. Until later tasks, the new letters print the "not ported yet" warning or load as air, except `6 7 8 _` which load **solid** (so nobody walks through the puzzles early).
5. Tests: new unit `rooms5b`: every G room loads; every G door's target exists and points back; `N17` has no `end`; `G16:E` is a symlink door with `sets: link:src`.

## MVG-02 · World 7 look

1. A sepia world 7: tiles, backdrop (a git graph with commit dots and tag flags `v0.1`, `v1.0` in the far layer) and `assets/theme/w7.json` (name `GIT HISTORY`). Start from world 1's tiles (the archive of the first rooms), toned to sepia and brown with green `+` and red `-` accents. `vis_world` falls back to 1 while w7 is missing (like w6 → 3).
2. Music `w7`: world 1's motifs, slower (0.85×) with one reversed bar per loop; if the tooling cannot do it, use `w1` and list it as a deviation.
3. Test `w7assets`: the files exist; `Game.theme(7).name == "GIT HISTORY"`; G02 builds its view without errors.

## MVG-03 · The machines

1. **Checkout** (G04, G09): `6 7 8` cells from `checkout`; a claw hit on a lever `I` advances the revision (host decides; guest sends a reliable `lever` event like T02's; the revision is in the snapshot). A cell that would turn solid on a body waits. A small panel above each lever shows the revision (`b01` / `b02` / `HEAD`; `+` / `-`). G04 starts at `b01` with the sign `You are in 'detached HEAD' state.`
2. **Branch keys `9`:** pickup → flag; the merge lock `until:2of:branch:a,branch:b` (existing kind). G08's sign 2 uses `alt` (data). When the second key is taken anywhere, G08's sign 3 `Merge branch 'feature/b'` lights up and the map draws the two branch lines joined (MVG-06).
3. **Plates** (`Q` + `4`, `plates` data): open while a body or a revert marker is on the key cell (MVG-04 adds markers); latch levers per 3.4. Reuse the mutex gate code; only the holder rule differs (no timer). Drawn: the mutex key's look with a `revert` glyph.
4. **Package-lock `_`:** solid, drawn; `--force` later.
5. **Reflog lever** (G13 (31,14)): sets `lever:reflog`; opens `G13:N`/`G10:S`.
6. **End door** G14 (`end: "to be continued in /var/prod"`), as T11's.
7. **Tests:** unit `git5b`: G04 b01 → b02 → b03 by three lever hits, the `-` wall, the plug and the `+` bridge change as listed, `G04:N` opens only at b02; a `+` cell never appears on a body; G09 a ↔ b from both levers; both keys open `G08:S`, one does not; a body on G13's plate opens col 20, leaving it closes it, the latch keeps it open; `lever:reflog` opens `G13:N`.

## MVG-04 · revert and the placeholder fight

1. **revert** (`Game.tools.revert`): [down]+[special] places the player's marker at their feet (only on ground; a new one replaces the old); [special] with no ring or breakpoint target in reach recalls: the player is moved to the marker, the marker is used up. A marker on a plate holds it. Drawn: a small sepia commit dot with the player's colour ring (P1 circle, P2 diamond, like the map). Sound `revert`.
2. **Co-op:** each page owns its player's marker (the guest's body is the guest's); markers travel in the snapshot / `st` reports as `[room, x, y]` so the host's plates see the guest's marker. Watchdog `marker-desync`: a plate open on one page and shut on the other for more than 0.5 s → `INVARIANT`.
3. **Placeholder REGRESSION** (until boss-design and boss-build make the real one): G12 uses the kit's test boss (`KitDummy`) with name `REGRESSION`, sub `(placeholder)`, a short fight, reward `revert`, banner `revert` / `[down]+[special]: leave a marker. [special]: go back to it.`. It sets `boss:REGRESSION` like a real boss. Say in the report that it is a placeholder.
4. **Changelog:** `OBSTACLES` += `Q` (plates) → `revert`, `_` → `force` (shown only once `force` exists). `CHANGELOG_WORDS["revert"] = "answers to revert"`.
5. **Tests:** unit `revert`: place, recall, replace; a marker holds a plate; recall with a GET ring in reach goes to the ring; a guest's marker holds the host's plate (`co-revert`, MVG-07).

## MVG-05 · Enemies (NetClasses: the next free indices, in this order)

1. **POLYMORPHIC `<`:** 4 hp. Forms: walker (Bug's walk), hopper (Typo's hop), guard (FIREWALL GUARD's front block). A hit that does not kill changes the form (a 0.25 s flash and a glyph `<T>` → `<U>`); the next form starts after the flash. Net fields: form, hp, the flash time.
2. **STASH `>`:** hidden in a wall cell next to it (a faint sepia sparkle `stash@`). Every 3.0 s it picks the player it has seen longest in the last 3 s (rule 8 of the boss contract, used here too), drops a sepia mark where that player was 3.0 s ago, and 0.7 s later comes out there and swipes once (1 damage, harm zone), then hides again over 0.5 s. Only takes hits while out. Uses the players' recent position history (host: own; guest: its reports). Net fields: state, mark x/y, timer.
3. **v0.1 variants:** `variants` turns `b`, `a`, `t` into sepia old versions, 0.85× speed. After `boss:REGRESSION`, G02 and G06 spawn no v0.1 enemies (aftermath, data `if`).
4. **Tests:** unit `gitenemies`: POLYMORPHIC cycles its three forms and dies in 4 hits; the guard form blocks from the front; STASH's mark is where a scripted player was 3.0 s before, it comes out 0.7 s later, it cannot be hit while hidden; `netfields` and `parity` pass for both classes.

## MVG-06 · The systems in GIT

1. Zone `git` for all G rooms (data). Terminal G03 (safe, fan, calm music; no enemy within 10 tiles).
2. `tree` in G02 at (105, 8), price 40 (data); paper scraps leading to it from the stairs.
3. Agent in G05 at (20, 11); logbook page 4 in G16 at (24, 20); fragment in G15 (memory line exists); plugin `nohup` in G05 (03: a lethal hit leaves you at 1 hp once, until the next bench) and `blame` in G16 (doc 19: the enemy that last hurt you takes double damage from your next hit; cost 1). Add both to `PLUGINS`.
4. **S6 signs in G02:** the six step signs are filled from the save: bosses beaten with their times (`fix: NULL pointer dereference — Clawd, 02:51`), each optional boss not beaten as `# TODO: ...`, and `Co-authored-by: Clawd #2` if any co-op session happened (a flag `coop:ever`). The two b02/b03 commits stay fixed (K4 clue). After `boss:REGRESSION`, the player's own `revert` commit is added.
5. **Decor:** `graph` (G03: a git graph whose branch lines turn green with `branch:a` / `branch:b`), `pedestal` (G08: empty or holding a key by flag), `mirror` (G11: REGRESSION's shadow copies the player's pose with a 1 s delay, B8), `cursor` (G16: two blinking cursors), `shadow` (G02: the black agent; if the black-agent-shadow brief already made the decor kind, use it; otherwise skip and say so).
6. **Map:** the two branch lines and the merge are drawn as a git graph in the zone view once both keys are taken.
7. **Symlink:** crossing `G16:E` sets `link:src` and arrives at `R06:W`; from then `R06:W` opens both ways (existing lock).
8. **Tests:** unit `git4b1`: `tree` sells `map:git`; G05's agent frees; G16's page and plugin; G15's fragment and Panel F order 3,1,4,2 sets `panel:F`; G03's bench has no enemy within 10 tiles; G02's signs read the flags.

## MVG-07 · Walk-through, co-op, watchdog

1. **`--test=rooms5b`** (extend MVG-01's): every G door that can open (set the flags each needs), crossed outward within 60 frames into the target, not inside a solid cell. The symlink: crossing G16:E arrives at R06 standing. N17 from G01: a body pushed up through `G01:N` arrives in N17.
2. **Co-op scenarios** (each also with `BADLINE_ALL=1`):
   - `co-checkout`: the guest pulls G04's lever twice; both pages show b03 and the bridge; the host walks over it.
   - `co-merge`: the host takes key A in G09, the guest key B in G07; both meet in G08; `G08:S` opens on both pages.
   - `co-plate`: the guest stands on G13's plate; the host passes the gate; the guest steps off and the gate closes on neither body.
   - `co-revert`: the guest leaves a marker on G14's first plate and recalls from beyond the bridge; the host sees the plate held, then released.
   - `co-stash`: a STASH targets the guest; the mark appears where the guest was on the guest's page (within the ping allowance).
3. **Watchdog:** `marker-desync` (MVG-04); `checkout-desync`: a checkout cell solid on one page and air on the other for more than 0.3 s → `INVARIANT`.

## MVG-08 · Tests, build, playtest steps, report — then stop

1. `test-all.sh` += `rooms5b w7assets git5b revert gitenemies git4b1`; `ALL=` += `co-checkout co-merge co-plate co-revert co-stash`.
2. `check5b.py`, `check5a.py`, `check4b3.py`, `check4b2.py`, `check4a.py` → `0 problems`; `world.py` → `errors 0`.
3. `bash tools/godot/test-all.sh` → `ALL PASS`; the five co-op scenarios with `BADLINE_ALL=1`.
4. Screenshots: G02, G03, G04 at b01 and HEAD, G07, G08 merged, G14 → `docs/reports/img-phase5b/`.
5. Export as the last commit (`MVG-08: export public/mv`).
6. `docs/reports/metroidvania-phase5b.md`: what was done; deviations; test results; what felt too easy or unfair in your bots.
7. Tick the board (`docs/studio/PRODUCER.md`) and add to «منتظر تست» in `docs/studio/PLAYTEST.md` these steps, in Persian:
   - از ته 22/tcp بیفت پایین به HEAD؛ نیمکت؛ دوباره از N17 برو بالا و برگرد.
   - پلکان git log: تابلوها از کارهای خودت می‌گن؟ `tree` رو پیدا کن و نقشه بخر.
   - هاب branch: دو راه. شاخه‌ی a: اهرم G04 رو سه بار بزن (b01، b02، HEAD)؛ با b02 درِ سقف (stash) باز می‌شه؟
   - چاه checkout: با اهرم کف سبز رو بردار، برو پایین، کلید A؛ با نردبون قرمز برگرد بالا.
   - شاخه‌ی b: دشمن‌های قدیمی، bisect (سوراخ غلط فقط برت می‌گردونه؟)، کلید B.
   - دونفره: هر کدوم یه شاخه، توی merge به هم برسید.
   - باس موقت REGRESSION، بعد reflog: نشانگر روی صفحه، رد شو از دروازه؛ برگرد بهش.
   - revert.sh تا درِ «ادامه دارد». کف package-lock هنوز نمی‌شکنه (درسته).
   - راز ترک‌دار git_log: old/hello_world.py و درِ symlink به اتاق مخفی اول بازی.
   - دونفره از اینترنت: نشانگر دوستت صفحه رو برای تو هم نگه می‌داره؟
8. Update `docs/metroidvania/README.md` and this plan's status table. **Stop.**

---

## Appendix · Where things are

| what | where |
|---|---|
| checkout, plates, keys, levers, crumble, end doors | `godot/src/world/room.gd`, `room_manager.gd` |
| revert, [special] priority | `godot/src/player/player.gd` |
| enemies | `polymorphic.gd`, `stash.gd` (new); variants in `bug.gd`, `typo.gd` |
| placeholder boss | `godot/src/enemies/kit_dummy.gd` |
| co-op | `coop.gd`, `net_classes.gd`, `watchdog.gd` |
| data | `docs/metroidvania/phase5b-data/` |
| design | `docs/metroidvania/19-git-history.md` |
