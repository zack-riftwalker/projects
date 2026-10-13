# CLAWD Metroidvania — Phase 5A Plan: THREAD TOWER (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. طراحیش (فارسی): [`metroidvania/12-thread-tower.md`](metroidvania/12-thread-tower.md).
>
> **چی ساخته می‌شه:**
> - **۱۹ اتاق برج.** نقشه‌ها رو خودم کشیدم و با شبیه‌ساز چک کردم. مسیر اصلی با bash، catch و curl رد می‌شه؛ sudo فقط برای راه اختیاری thread_0 لازمه.
> - **تیک زمان‌بند:** کل برج روی ضرب ساعت (هر ۰.۸۳ ثانیه) کار می‌کنه. بلوک‌ها، چرخ‌دنده‌ها، پیستون‌ها و بیشتر دشمن‌ها روی تیک حرکت می‌کنن.
> - **breakpoint:** رو به یه ماشین یا دشمن، SPEC رو بزن؛ ۳.۵ ثانیه وای‌میسه. جایزه‌ی RACE CONDITION.
> - **۷ دشمن بومی:** HEISENBUG، DATA RACE، DEADLOCK، SPINLOCK، TICKER، ORPHAN، PRIORITY INVERSION.
> - **سه باس:**
>   - RACE CONDITION: دو ریسه که جای قبلی‌ات رو می‌زنن، و بافر کف که خراب می‌شه.
>   - INFINITE LOOP: مار حلقه‌ای تو آرنایی که دور می‌زنه. جایزه‌اش opus.
>   - DEADLOCK: اختیاری و سخت‌ترین؛ جایزه پلاگین lock_free.
> - **صحنه‌ها:**
>   - fork/join: دو ریسه از سه تا.
>   - سرسره‌ی yield().
>   - درهای mutex: کلید رو بزن و بدو.
>   - while_true.js که هر بار تکرارش بدتر می‌شه.
>   - میان‌بر goto تا airgap.
>
> **برای دادن به Sonnet:** «فایل `docs/PLAN-metroidvania-phase5a.md` رو بخون و اجراش کن.» فقط بعد از اینکه 4B-3 تموم شد.

---

## 0. Rules of engagement

- **Start only after phase 4B-3 is done** (`docs/reports/metroidvania-phase4b3.md` exists on `ph1`). If not, stop and say so.
- **Read first, in order:**
  1. `CLAUDE.md`.
  2. This file, all of it.
  3. `docs/metroidvania/12-thread-tower.md` (the design, Persian; this file is its English spec).
  4. The 4B-2 and 4B-3 reports and plans (curl, ssh, the kit, arena hazards, body effects, the bosses as built). Where a name here differs from what those phases built, use the built name and say so.
  5. `docs/metroidvania/05-difficulty-model.md` §1 rows 2, 5 and 6.
  6. `godot/src/enemies/leak_boss.gd` and the 4B-3 bosses (the model of a boss that changes its arena).
  7. Then the code you change.
- **Do only phase 5A.** Stop after MV5A-11 and report.
- **Do not redesign.** Values, letters, room files and JSON here and in `docs/metroidvania/phase5a-data/` are decisions. If one is impossible, take the smallest change that keeps the goal and list it under deviations. **Never edit a room file by hand**: change `phase5a-data/tower.py`, run it, re-run `apply.py`, `check5a.py` (`0 problems`) and `world.py` (`errors 0`).
- **Difficulty is the point** (Hollow Knight level or a bit harder, as in 4B-3). Do not make anything easier than written; say in the report what felt too easy or unfair in your bots.
- **Branch:** `ph1` only. `git fetch origin ph1 && git checkout ph1 && git merge --no-edit origin/ph1`. Do not merge `main`. Never push to `main`, never open a PR.
- **Files you may touch:** everything under `godot/` and `tools/godot/`; `docs/metroidvania/`; `docs/reports/metroidvania-phase5a.md`; this plan's status table. Not `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`. `public/mv/` only through `export-web.sh`, as the last commit.
- **Commits:** one per task (`MV5A-xx: <what>`), with your session's attribution lines. Push after each.
- **Co-op rules** (CLAUDE.md; not optional): state over events; what the guest's combat reads goes through `net_fields()`/`net_apply()` and `parity`; contact harm is `harmboxes()` from those fields; a kit boss hurts only through its plan or an arena hazard (4B-3); a new co-op bug class gets a watchdog rule; reliable event data only in `d`; never a field named `i` or `k`. **Everything that moves on the tick is a pure function of the room clock (plus breakpoint offsets that travel in snapshots).**
- **Godot naming trap:** never name members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Tests:** every task names its tests; before the final commit `bash tools/godot/test-all.sh` → `ALL PASS`; new `--test=`s in its list, new scenarios in `ALL=`.
- **"Skip boss" stays** and works for the three bosses.

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MV5A-01 | room data in (19 rooms, N11/H11 edits); checkers (`check5a.py`, two `world.py` rules) | Sonnet | todo |
| MV5A-02 | world 4 look: tiles, backdrop, theme and music captured from the JS world 4 | Sonnet | todo |
| MV5A-03 | the tick; tick blinks; gears `O`; pistons `A`; mutex keys `Q` and gates `4`; cables `5`; the loop room; `land` trigger | Sonnet | todo |
| MV5A-04 | breakpoint | Sonnet | todo |
| MV5A-05 | enemies: HEISENBUG, DATA RACE, DEADLOCK pair, SPINLOCK, TICKER, ORPHAN, PRIORITY INVERSION | Sonnet | todo |
| MV5A-06 | RACE CONDITION → breakpoint | Sonnet | todo |
| MV5A-07 | INFINITE LOOP → opus | Sonnet | todo |
| MV5A-08 | DEADLOCK (optional) → plugin `lock_free`; plugin `hot_path` | Sonnet | todo |
| MV5A-09 | the 4B-1 systems in the tower (zone, `tree`, agent, page, fragment, terminal, changelog) | Sonnet | todo |
| MV5A-10 | walk-through tests, co-op scenarios, watchdog rules, bad line | Sonnet | todo |
| MV5A-11 | tests, build, playtest steps, report → **stop** | Sonnet | todo |

---

## 2. Facts (verified by Claude on `ph1` at `6208002`; 4B-3 was running)

1. **The design** (`world-phase45.json`, already updated for this phase) places the 18 tower rooms and links of `08-world-design.md` §3 plus one new optional arena, **T18 `lock_order.c`** (24×14 at [1100, −232], above T08 through T08's ceiling, gate `opus`). `world.py` passes on today's repo with it.
2. **JS world 4 is THREAD TOWER**: `G.THEME[4]` (brass and sand, `music: 'w4'`) and a background builder `build[4]` exist in `public/index.html`, so world 4's tiles, backdrop and theme can be captured like worlds 1–3 (`WORLDS=4`). The JS song `w4` runs at **144 bpm** (`index.html` ~line 1369): one tick = 2 beats = **0.8333 s**.
3. **N11** (built in 4B-2) has an end door `D` at (3, 44) and `"end"`; its west door `N11:W` → `T01:E` stays closed until T01 exists. Its ceiling hole `N11:N` (cols 40–43) leads to T16. **H11**'s ceiling hatch `H11:N` (cols 60–63, open cells, no lock) leads to T02.
4. **4B-0's lock** `until:<k>of:<flags>` exists (`thread:0/1/2` are already world flags), as do `sets` doors, variants, blink holds and N/S doors. 4B-2 added `oneway`, levers (`I`), end doors; 4B-3 added the kit's `rec`, arena hazards, bouncing shots and body effects.
5. The simulator facts for this phase's rooms: `phase5a-data/check5a.py` (all routes in §3.2) prints `0 problems`; `world.py` prints `errors 0` before and after `apply.py` with the two rules of MV5A-01.

---

## 3. Shared definitions

### 3.1 The data (`docs/metroidvania/phase5a-data/`)

| file | what |
|---|---|
| `rooms/T*.txt` | the 19 rooms |
| `rooms-5a.json` | their `rooms.json` entries |
| `room-edits-5a.json` | N11 (end door out, `N11:N` gets `oneway`, sign 2 changes), H11 (`H11:N` gets `until:lever:T02`) |
| `apply.py` | copies the rooms, applies the edits, merges the entries (idempotent; takes a repo root argument) |
| `sim.py`, `reach.py`, `check5a.py` | the simulator (mutex gates `4`, cables `5`, gears and busy pistons from the room data) and the checker |
| `tower.py`, `canvas.py` | the generator |

### 3.2 The tower at a glance

```
                           T18 lock_order.c (DEADLOCK, optional; cables in T08's ceiling: opus)
                             |
        T14 volatile.h --;-- TA2 deadlock.rs (sudo) ---- T08 scheduler.c (TERMINAL) ---- T09 while_true.js (loop) ==break;==> T10 INFINITE LOOP ---> T11 busy_wait.c --(breakpoint)--> P01 (end door)
                             |  join + sudo ledge            | mutex                          | breakpoint (TC2's pistons)                    | opus (cable floor)
                             |                            TB2 mutex.c --fight--> T06 RACE CONDITION --> TC2 semaphore.h                    T16 goto (drop to N11, then eth0)
                             |  join                         |  join
   T04 race_condition.go (bench, join: 2 of 3 threads) --------+------------------------------------------- (S holes: TA1, T17 yield, TB1, TC1)
      |                |               |                |
     TA1 thread_0     T17 yield()     TB1 thread_1 -bash- T15 heisenbug.log        TC1 thread_2 (gears)
      |                | (one way)     |                                           |
   T02 async_await.ts (await blocks; trapdoor to H11 mmap.c after its lever) ---- T01 pthread_create.c (bench, tree) <--curl-- N11 airgap
```

**Routes the checker proves** (`B` = bash + catch + curl; nothing else):
- With `B` only: N11 → T01 → T02 → TA1 → T04; T02 → TB1 → T04; T01 → TC1 → T04; T04's yield hole → T17 → T02; T04 (two threads joined) → TB2 → T06 → (boss) → TC2; TB2 (mutex open) → T08 → T09 → T10 → T11 → T16 → N11; every room back the other way.
- `TA2` needs `sudo` (both the ledge in T04 and its climb); without it, `TA2:N` is not reached.
- `TB2:N` is not reached with the mutex gates shut; `TC2:N` and T11's end door are not reached with the busy pistons running (breakpoint opens them); `T11:S` and `T08:N` need the cables cut (opus).
- `TB1:E` (to T15) needs the crack broken (bash).

### 3.3 New letters (tower rooms; most are symbols because letters ran out)

| letter | what | task |
|---|---|---|
| `O` | gear centre (its platforms come from `gears[i]`, in reading order) | MV5A-03 |
| `A` | piston housing (solid); its head comes from `pistons[i]` | MV5A-03 |
| `Q` | mutex key (a plate; its gates come from `mutex[i]`) | MV5A-03 |
| `F` | the `break;` key of the loop room | MV5A-03 |
| `4` | mutex gate tile (solid while its key is not active) | MV5A-03 |
| `5` | spaghetti cable tile (solid; a 2-damage hit cuts the whole cable) | MV5A-03 |
| `(` | HEISENBUG | MV5A-05 |
| `[` | DATA RACE (a pair) | MV5A-05 |
| `]` | DEADLOCK pair | MV5A-05 |
| `)` | SPINLOCK | MV5A-05 |
| `{` | TICKER | MV5A-05 |
| `+` | ORPHAN (a fork with three children) | MV5A-05 |
| `}` | PRIORITY INVERSION | MV5A-05 |

`1`/`2` (blink blocks) keep their letters; in world 4 they follow the tick (MV5A-03).

### 3.4 New `rooms.json` fields

| field | room | meaning |
|---|---|---|
| `"world": 4`, `"music": "w4"`, `"zone": "tower"` | all T rooms | |
| `"gears": [{"x", "y", "r", "n"}]` | TC1, T08 | centre cell, radius in cells, platforms; `"decor": true` = drawn only (T08's clock hands carry riders too, but nothing needs them) |
| `"pistons": [{"x", "y", "len", "w", "ticks", "busy"}]` | TA2, TC2, T11 | housing cell, head length and width in cells; `ticks` = [extend, hold, retract, wait] in ticks; `busy: true` = the fast kind that only breakpoint gets you past |
| `"mutex": [{"key": [x, y], "rows": [r…]}]` | TB2 | key `i` opens the `4` cells of those rows |
| `"loop": {"flag", "after", "iters": [{spawn, variant, key}]}` | T09 | the loop room |
| door `"wrap": true` | T09:E | leads back into its own `T09:W` until `loop.flag`, then to `loop.after` |
| boss `"trigger": "land"` | T18 | the fight starts when a player stands 0.5 s on the arena floor |
| `"decor"` kinds `threads`, `coffee2` | T04, T08 | MV5A-03 |

### 3.5 Flags

`thread:0/1/2` (crossing TA1:N / TB1:N / TC1:N, `sets`, already world flags), `lever:T02`, `boss:RACE`, `boss:LOOP`, `boss:DEADLOCK`, `break:T09` (add `break:`), `cable:<room>:<x>:<y>` (add `cable:`), `ability:breakpoint`, `ability:opus`, `plugin:hot_path`, `plugin:lock_free`. Add the new prefixes to `WORLD_PREFIXES`.

### 3.6 Constants (decisions)

```
TICK        := 0.8333   # s (two beats of w4 at 144 bpm)
BP_RANGE    := 112.0    # px, body centre to target
BP_TIME     := 3.5      # s frozen
BP_COOLDOWN := 6.0      # s
MUTEX_T     := 3.5      # s a key keeps its gates open
```

Damage and timing rules are 4B-3's (§3.5 there): ordinary hit 1; big boss hit 2 with a cue ≥ 0.70 s; other boss cues ≥ 0.45 s; recovers 0.5–0.8 s unless stated; enemy tells ≥ 0.35 s.

---

## MV5A-01 · Room data and checkers

1. `python3 -I docs/metroidvania/phase5a-data/apply.py` (19 rooms; N11 and H11 edits; 84 rooms in `rooms.json` after it, if nothing else was added since).
2. Copy `sim.py`, `reach.py`, `check5a.py` to `tools/godot/roomcheck/` (the new `sim.py` only adds tower tiles and options; `check4a.py`, `check4b2.py`, `check4b3.py` must still print `0 problems`). Add `run check5a python3 -I tools/godot/roomcheck/check5a.py` to `test-all.sh` next to the other checkers.
3. **`world.py`**, two rules (Claude ran `world.py` with exactly these on a post-apply copy: `errors 0`):
   - A built door with `"wrap": true` is skipped in the built-links loop; the door whose target is a wrap door and equals that room's `loop.after` makes a link with gate `break`. A design link with gate `wrap` whose rooms are both built is kept as a design link (no "not built yet" warning).
   - In `ground_ns`, a column of the lower room counts as having ground when the lower room's own S door covers it (a chute: the fall goes on).
   - `GATES` += `"until:lever:T02"`, `"until:2of:thread:0,thread:1,thread:2"`, `"until:boss:RACE"`, `"until:boss:LOOP"`.
4. Until later tasks, unknown letters print the "not ported yet" warning; `4`, `5`, `O`, `A`, `Q`, `F` load as air.
5. Tests: `parity` and the 4B rooms tests keep passing; new unit `rooms5a`: every T room loads; every T door's target exists and points back (except the wrap door, which points at its own room); `N11:W` is open; `N11` has no end door; `H11:N` is closed without `lever:T02`.

## MV5A-02 · World 4 look

1. `WORLDS=4 node tools/godot/capture/capture.js tiles bg theme` → `assets/tiles/w4_tiles.png`, `assets/bg/w4.png`, `assets/theme/w4.json`, `sprites/platform_w4.png`.
2. Add `'w4', 'w4_hi'` to `COPY_MUSIC`; `node tools/godot/capture/capture.js music`.
3. Tower rooms use them through `world: 4` and `music: "w4"`.
4. Test `w4assets` (new): the four files exist; `Game.theme(4).name == "THREAD TOWER"`; T04 builds its view without errors.

## MV5A-03 · The tick and the tower's machines

1. **The tick:** `Room.tick_i() -> int = floori(room.time / TICK)` and `Room.tick_f() -> float` (0..1 inside the tick). Rooms with `world == 4`: a soft `tick` sound each tick (local page) and a small pendulum in the HUD's top centre swinging on the tick (drawn, 1 px brass). Both pages agree because `room.time` is synced (`rt`).
2. **Blink blocks on the tick** (world 4 only): `1` cells are on during even ticks, `2` cells during odd ticks; in the last 0.2 of a tick the cells that will turn off flicker (a warning). The existing blink hold (never closing on a body) stays. Variants turn them solid after `boss:RACE` (T02, TA1: in the data).
3. **Gears `O`:** `gears[i]` (reading order of `O`): `n` one-way platforms 48×6 at radius `r` cells around the centre cell's middle; angle of platform `j` = `(tick_i + ease(tick_f)) × 45° + j × 360° / n`, with `ease` moving in the first 0.3 of the tick and holding after (a ticking motion). Riders are carried like `M` platforms (dx and dy). Drawn: a brass gear disc at the centre with teeth, spokes to the platforms. `"decor": true` gears are drawn the same and carry riders too.
4. **Pistons `A`:** `pistons[i]` (reading order of the `A` runs). The housing cells are solid. The head (w cells wide) moves down from under the housing to `len` cells and back: phases `extend`, `hold`, `retract`, `wait`, each `ticks[k] × TICK` long (busy pistons: 0.25 / 0.1 / 0.25 / 0.1, so the way is clear only 0.1 × TICK at a time). The head and the shaft cells it covers are solid; a body caught between the extending head and something solid takes 1 damage and is put at its safe spot (each page, its own body). A pure function of `room.time` minus its breakpoint offset (MV5A-04).
5. **Mutex `Q` and `4`:** `mutex[i].key` is the key cell; a claw hit or a dash on it, or a body standing on it, makes it active for `MUTEX_T` (standing keeps refreshing it). While active, the `4` cells of its rows are open (not solid). A cell never closes on a body (the blink-hold rule). Drawn: a closed gate is a striped lock bar; an open one is a faint outline with a shrinking timer bar; the key is a pressure plate with a padlock icon. Co-op: the host decides (a guest's hit or stand is a reliable `mutex` event with the key index; the host reports active keys and their time left in the snapshot `mx`).
6. **Cables `5`:** solid. A claw hit with damage ≥ 2 (opus) on a cable cell cuts the whole 4-connected cable: every cell becomes air and `cable:<room>:<x>:<y>` (the hit cell) is set (saved, a world flag). Drawn: a bundle of coloured wires; a 1-damage hit clangs off (`clang`, a spark). With the flag, a rebuilt room loads the cable cut.
7. **The loop room (T09):**
   - The host keeps `iter` (0..3) per loop room (`RoomManager.loop_iter[room]`, survives rebuilds, resets on respawn/travel). A crossing of the wrap door by any player (the guest's comes through its room event with the door id) adds 1 (max 3) and rebuilds the room for both: the spawns of `iters[iter].spawn` (`["{", x, y]` etc.), the variants whose `if` is `iter>=n` (add `iter>=n` to `Game.cond` for the current room), and the `F` key only when `iters[iter].key`.
   - Crossing the wrap door puts the player at `T09:W` like any door into that room.
   - Touching `F` sets `break:T09`; from then the wrap door leads to `loop.after` (T10:W).
   - The iteration count is drawn on the back wall: `i = 0` … `i = 3` in big pixel text. Snapshots carry `it`.
   - After `boss:LOOP`: T09 spawns nothing and `i` stays as it was (aftermath).
8. **`land` trigger** (T18's boss): the intro starts when a player has stood 0.5 s on the arena floor (not on the hole's lid). The guest's stand reaches the host through its `st` reports (the host checks the guest's last position).
9. **Decor:** `threads` (T04, until `boss:RACE`): two thin coloured streaks (orange and blue) racing left and right along row `y` across `w` cells in the background, sometimes overlapping with a red flash (the race). `coffee2` (T08): two cups, one steaming.
10. **Tests:** unit `tick5a` (new): two rooms given the same `time` have the same blink, gear and piston states; a blink cell does not close on a body; a rider on a gear platform is carried through 8 ticks; a busy piston's way is clear only 0.1 × TICK per cycle; a body crushed by a piston takes 1 damage; TB2's first key opens row 45 for 3.5 s, a body on the key keeps it open, a closed gate never closes on a body; a 1-damage hit on a cable clangs and a 2-damage hit cuts the whole cable and sets its flag; T09's wrap door raises `iter` to 3 at most, the third iteration shows the `F` key, `break:T09` sends the next crossing to T10.

## MV5A-04 · breakpoint

**What the player does:** facing a machine or an enemy, press [special]: it stops for 3.5 s (a frozen enemy is harmless and can be stood on).

1. **Tools:** `Game.tools.breakpoint` (both places; old saves load false). `opus` already exists (`player.gd`: range 30, damage 2).
2. **[special] priority:** a curl anchor if one is pickable (4B-2) → else a breakpoint target if one is pickable → else agents / focus as today. A press that starts a breakpoint sets `spec_used` (no agents on release).
3. **Targets:** creatures (not bosses unless the boss data has `"bp": true`), pistons, gears, `M`/`V` platforms, blink groups (the 4-connected `1`/`2` group of a cell). Pick: within `BP_RANGE` of the body centre, in front (`dx × face ≥ −8`), clear line, the nearest wins. Not while the cooldown runs.
4. **Effect:** `BP_TIME` frozen:
   - A creature skips its update, has no harm boxes, and its box is a one-way platform for players.
   - A piston, gear, platform or blink group stops its clock: the room keeps a per-object offset that grows while frozen, so its pure function uses `room.time − offset` and continues from the same state afterwards.
5. **Cooldown:** `BP_COOLDOWN` (a small `BP` dial in the HUD).
6. **Feedback:**
   - On the target: a blue frame, `BREAK` and a countdown.
   - When owned, the target a press would hit gets a pause-bracket marker, and the touch SPEC button reads `BRK` (as curl's `GET`).
7. **Co-op:**
   - The host decides. A guest press sends a reliable `bp` event (`{"kind": "c"|"p"|"g"|"m"|"b", "id": nid or object index}`); the host applies it if the target is valid.
   - Snapshots carry `fz` (the frozen objects with time left) and the per-object offsets, so the guest's machines match.
   - The host's own press is immediate.
   - Watchdog rule `bp-desync` (guest): an object frozen in the last snapshot but moving on the guest for more than 0.5 s → `INVARIANT`.
8. **Tests:** unit `breakpoint` (new):
   - TC2's busy piston frozen retracted lets a player through.
   - A frozen TICKER can be stood on and does not hurt.
   - A frozen gear resumes from the same angle.
   - The cooldown blocks a second press for 6 s.
   - A ring in range takes priority over a piston in range.
   - A breakpoint tap with a full meter does not cast agents.
   - Parity: the frozen state is in the creatures' fields.

## MV5A-05 · Enemies (NetClasses: the next free indices after 4B-3, in this order)

**HEISENBUG** (`(`, `heisenbug.gd`, `extends EnemySM`):
- Body 12×12, hp 3, loot 2, contact 1.
- **Observed** when any player within 200 px faces it (`sign(dx_to_it) == face`, or `|dx| < 8`) with a clear line.
- Observed: it freezes (a grey "observed" eye drawn over it). Unobserved: it dashes at the nearest unobserving player at 90 px/s (flies), with a 0.2 s shimmer when it unfreezes.
- Co-op: the guest's face comes from its reports.
- `net_fields`: `[observed, roundi(state_t×100)]`.

**DATA RACE** (`[`, `datarace.gd`):
- The letter spawns two twins, A at the cell and B 64 px to the right, sharing one hp pool of 4. Body 12×16, contact 1.
- They move mirrored about their midpoint: when A walks right at 60 px/s, B walks left. They turn at walls.
- **Commit rule:** a hit on one twin is pending for 0.5 s; if the other twin is hit inside that window, both hits count; otherwise the pending damage rolls back (pop `ROLLBACK`, a rewind shimmer).
- `net_fields`: `[mid_x×10, phase×100, pending (2 × t×100)]`.

**DEADLOCK pair** (`]`, `deadlockpair.gd`):
- Two guards, at the cell and 96 px right, each 14×18, hp 4, contact 1. They hold still and lunge 32 px at a player within 40 px (tell 0.4 × tm).
- While each has a clear line to the other, a blue chain is drawn between them and both block all hits (clang). A player's body on that line breaks it (the line test includes player boxes).
- `net_fields`: `[linked, a_state, b_state, roundi(t×100)]`.

**SPINLOCK** (`)`, `spinlock.gd`):
- A 20×20 spinning blade attached to the nearest solid side; contact 1.
- On every 4th tick it stops for one tick (only then it can be hit; hp 6), then dashes 48 px out along its axis and back during the next tick.
- breakpoint freezes it (harmless while frozen).
- `net_fields`: `[]` (a pure function of the tick and its spawn cell, plus frozen state).

**TICKER** (`{`, `ticker.gd`):
- 14×12, hp 2, contact 1.
- Moves exactly one cell along the floor at the start of each tick (a 0.15 s step); turns at walls and edges; every 4th tick it hops one cell up and forward instead. Tick-driven: both pages compute its position from its spawn cell, its turns (fields) and the tick.
- `net_fields`: `[cell_x, dir, last_tick]`.

**ORPHAN** (`+`, `orphan.gd`):
- A parent (12×16, hp 4) walking at 40 px/s with three children (6×6, hp 1, contact 1) orbiting it at radius 18.
- When the parent dies, the children become orphans: each dashes at the nearest player every 1.0 s (tell 0.35 s, 200 px/s).
- `net_fields`: parent `[]`, child `[orphan, roundi(t×100)]`; the children are their own creatures.

**PRIORITY INVERSION** (`}`, `priority.gd`):
- 32×32, hp 10, loot 6.
- Asleep (still, no contact harm) until hit. While it is asleep, every enemy within 160 px is frozen too (blue `blocked` tint).
- A hit wakes it: it walks at 20 px/s toward the nearest player (contact 1, pushes players back 1 px/frame like a wall), and the enemies around wake with it. It falls asleep again after 6 s without being hit.
- `net_fields`: `[awake, roundi(t×100)]`.

**Tests:** unit `w4enemies` (new): one or two checks per enemy, as described (observed heisenbug freezes; data race rollback and commit; a player on the deadlock line unblocks; spinlock hittable only on its stop tick; ticker one cell per tick; orphans dash after the parent dies; priority's sleep freezes a ticker 100 px away). Parity for all.

## MV5A-06 · RACE CONDITION → breakpoint

`race_boss.gd`, `class_name RaceBoss extends Boss`, a kit boss; NetClasses next index. Arena T06 (26×14, `FLOOR` 176, perches at row 8 on both sides). **Two threads**, A (orange) and B (blue), 16×24 each, spawned at the two `B` cells, **hp 45 each** (`T 100, u 0.9` → 90 split). Both must die; the last one alive enrages (every cue × 0.85, still ≥ 0.45 / 0.70; recovers − 0.1).

**Arena hazards:**
- **The shared buffer:** the floor is 8 segments of 48 px (x 16–400). Each `write` paints its segment with its thread's colour. A segment painted by both A and B within 4 s turns **corrupt** for 6 s: the floor band `FLOOR−6..FLOOR` hurts (1); at most 4 corrupt.
- **The mutex lock:** a 12×14 lock hangs at (208, 96) (a jump + up-swipe from the floor reaches it). A hit on it (or a caught shot) **serializes** for 6 s: the threads write one at a time at half rate, and every corrupt segment clears; then a 10 s cooldown (drawn on the lock).

**Attacks:**

| id | what | cue | harm |
|---|---|---|---|
| `read`→`write` | each thread drops a ghost of its target **where it is at the start of the cue** ("stale read"); the write strikes the ghost's x | 0.9 (A), B 0.3 s later | 32×40 on the floor at the ghost; 1; both ghosts in one segment = a collision write, 2 |
| `switch` (P2+) | context switch: both teleport to each other's spot; the arrival spots are shown | 0.6 | each body at arrival, 1 |
| `contend` (P3) | both dash at the lock from their sides along a shown line | 0.7 | bodies, 1; if they meet within 24 px they stun each other for 2 s (take hits from anyone) |

- **Phases** (by total hp left): P1 (100–60 %) `read→write` × 2, a short pause; P2 (60–25 %) + `switch`; P3 (25–0 %) + `contend`.
- **Rule 8:** the ghost goes to the player who moved least in the last 1.0 s (it reads your habit).
- `net_fields` = `plan_fields()` + `[a_x, b_x, a_hp, b_hp, ghost_x (2), segments (8 × [owner bits, t×10]), lock_cd×10, serial_t×10]`.
- **Reward:** `breakpoint`; with `boss:RACE` the await blocks of T02 and TA1 stay solid (variants), and the `threads` decor stops.
- **Tests:** unit `raceboss` (new): HP 45 + 45; a write lands on the read position, not the current one; two writes in one segment within 4 s corrupt it and it hurts the floor band; the lock serializes and clears; `contend` stuns both when they meet; the last thread enrages; the kill gives breakpoint and opens T06:E. Parity.

## MV5A-07 · INFINITE LOOP → opus

`loop_boss.gd`, `class_name LoopBoss extends Boss`, a kit boss. Arena T10 (24×14). **HP `T 110, u 0.6` → 66; only the tail is a hurtbox.**

**The arena loops:** while the fight is active, the door rows 7–10 of both walls are a wrap portal for players and the snake: a body whose centre crosses x < 0 appears at the right edge, and the other way round (each page, its own body). Outside the fight they are normal fight-locked doors.

**The snake:** 12 segments of 12×12 along a path; its body is contact harm 1; the head's bite is 2 (cue 0.75: the jaw opens toward the target); the tail (last segment) is the only hurtbox. Its positions are a pure function of `path_t` and the mode (both pages compute them).

**Iterations:** the attacks always come in the order 1, 2, 3; then an iteration ends and `i` (drawn on the back wall) goes up by one. Each iteration is 15 % faster and, from `i = 2`, each attack gets its extra:

| # | id | what | from i = 2 |
|---|---|---|---|
| 1 | `lap` | two laps round the arena's inner walls, floor and ceiling (jump it on the floor, pass under it on the ceiling); the wrap portal lets it come from behind | a head lunge at the target mid-lap (2, cue 0.75) |
| 2 | `nested` | it splits into an outer ring and an inner ring at mid height, rotating; a safe band between them | the inner ring turns the other way |
| 3 | `recursion` | it spits three 4-segment copies; each runs one lap at its own height (low, mid, high) | a fourth copy |

**The BREAK panel (environmental counter):** at (192, 96) on the back wall. At the end of each iteration the snake drops to the floor and the panel lights for 1.5 s: a hit freezes the snake for 3 s with its tail on the floor by the panel (free hits). Missed: the next iteration starts.

**P3 (≤ 30 %):** the floor becomes a conveyor (players pushed toward the head at 40 px/s) and both side strips (x < 32 and x > 352) turn into hazards (the loop body closing in).

- `net_fields` = `plan_fields()` + `[iter, mode, roundi(path_t×100), roundi(speed×100), panel_t×100, freeze_t×100, minis (4 × path_t×100)]`.
- **Reward:** `opus` (the existing tool: range 30, damage 2), banner `your claw reaches further and hits twice as hard; it cuts spaghetti cables`. With `boss:LOOP`: T09 spawns nothing more; T08's clock chimes once when entered (a sound and a pop).
- **Tests:** unit `loopboss` (new): only the tail takes damage; the order is always 1, 2, 3; iteration 2 is 15 % faster; the panel freezes for 3 s with the tail reachable from the floor; a player crossing x < 0 during the fight appears at the right; the kill gives opus. Parity.

## MV5A-08 · DEADLOCK (optional) and two plugins

**DEADLOCK** (`deadlock_boss.gd`, kit boss, `"bp": true`), arena T18 (`land` trigger, its S door `fight`-locked):
- Two halves A and B (20×26 each, at the `B` cells), **48 hp each** (`T 120, u 0.8` → 96).
- **The commit rule** (the room's point): damage to one half is pending for 2.0 s; it counts only if the other half takes damage within that time; otherwise it rolls back (`ROLLBACK`). Solo: hit one, then the other within 2 s, or freeze one with breakpoint and alternate. Two players: one each.
- **The chain (arena hazard):** a line between the halves.
  - `chain` (sweep, cue 1.0): they slide along opposite walls so the line sweeps across the arena; the sweep's path is drawn first.
  - P3: the chain is always live (1) except during their recovers.

| id | what | cue | harm |
|---|---|---|---|
| `chain` | the sweep above | 1.0 | the line, 1 |
| `grab` | one half lunges at its target | 0.75 | 2 |
| `swap` (P2+) | they exchange keys: both invulnerable for 1.5 s (bright tell) | 0.6 | — |

- **Reward:** plugin `lock_free`.

**Plugins** (`Game.PLUGINS`):
- `hot_path` (cost 1, T15 after its corridor): a dash that hits an enemy recharges the dash.
- `lock_free` (cost 2, DEADLOCK): your claw and dash ignore the front guard of regular enemies (FIREWALL GUARD, MITM, the DEADLOCK pair), not of bosses.

**Tests:**
- Unit `deadlockboss`: rollback without the other half; commit with it; breakpoint freezes one half; the kill gives `plugin:lock_free`.
- Unit `plugins5a`: `hot_path` recharge; `lock_free` against a Guard's front and not against a boss.

## MV5A-09 · The 4B-1 systems in the tower

1. **Zone `tower`** for all T rooms (data).
2. **`tree`** in T01 at (54, 8), price 40, with scraps (data).
3. **Agent** in T15 at (21, 10) (data).
4. **Logbook page 3** in T14 at (4, 10) (data).
5. **Fragment** in T14 at (14, 6): its memory line `05:12 — two threads wrote the same line at once.` is already in 4B-1's table.
6. **Terminal** T08: 4B-1's rules (safe, fan, calm music).
7. **Secrets:** T14 and T15 (`secret`).
8. **Changelog:** `OBSTACLES` += `A` (busy pistons only) → `breakpoint`, `5` → `opus`.
9. **Logs:** tower signs go under THREAD TOWER.
10. **Tests:** unit `tower4b1`: `tree` sells `map:tower`; T15's agent frees; T14's page and fragment; T08's bench has no enemy within 10 tiles.

## MV5A-10 · Walk-through, co-op, watchdog

1. **`--test=rooms5a`** (extend MV5A-01's): every tower door that can open (set the flags each needs), crossed outward within 60 frames into the target, not inside a solid cell, `hazard_at` empty. The fork/join: with `thread:0` and `thread:1` set, `T04:N2` is open; with only one, closed. The yield chute: a body dropped through T04's yield lid arrives in T02 standing. The goto drop: a body dropped in T16 arrives in N11 and then N01 (the airgap fall).
2. **Co-op scenarios** (each also with `BADLINE_ALL=1`):
   - `co-tick`: both pages in T02, TC1 and TC2: the blink, gear and piston states agree on both pages at the same `rt` for 20 s.
   - `co-breakpoint`: the guest freezes a busy piston in TC2; the host sees it frozen within 0.6 s; the guest walks through.
   - `co-mutex`: the guest stands on TB2's key; the host climbs through the open gate.
   - `co-loop`: the guest wraps T09 three times; both pages show `i = 3` and the `F` key.
   - `co-race`, `co-loopboss`, `co-deadlock`: 30 s fights, the kit's pass rules (no `boss-cue`, no `arena-tell`), plus: `co-race` — the guest's write lands on the guest's read position on the guest's page; `co-loopboss` — the guest wraps through the portal mid-fight; `co-deadlock` — a host hit and a guest hit within 2 s commit.
3. **Watchdog:**
   - `bp-desync` (MV5A-04).
   - `tick-desync` (guest): a blink, gear or piston state that differs from what the host's last snapshot implies for more than 0.3 s → `INVARIANT`.

## MV5A-11 · Tests, build, playtest steps, report — then stop

1. `test-all.sh` += `rooms5a w4assets tick5a breakpoint w4enemies raceboss loopboss deadlockboss plugins5a tower4b1`; `ALL=` += `co-tick co-breakpoint co-mutex co-loop co-race co-loopboss co-deadlock`.
2. `check5a.py`, `check4b3.py`, `check4b2.py`, `check4a.py` → `0 problems`; `world.py` → `errors 0`.
3. `bash tools/godot/test-all.sh` → `ALL PASS`; `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-tick co-breakpoint co-mutex co-loop co-race co-loopboss co-deadlock`.
4. Screenshots: T02, TC1, TB2, T09 at `i = 3`, each boss's last phase → `docs/reports/img-phase5a/`.
5. Export as the last commit (`MV5A-11: export public/mv`).
6. `docs/reports/metroidvania-phase5a.md`: what was done; deviations; test results; what felt too easy or unfair in your bots; **playtest steps for Zakaria in Persian**, short:
   - from the airgap to the tower's foot; the await blocks on the tick;
   - the three threads (any two), the join;
   - yield();
   - mutex.c (solo and two players);
   - RACE CONDITION; breakpoint in semaphore.h;
   - while_true.js to `i = 3` and `break;`;
   - INFINITE LOOP; opus on the cable floor and the goto drop to eth0;
   - the secrets (heisenbug.log, volatile.h); DEADLOCK above the terminal;
   - co-op over the internet: do the ticks and breakpoints match on both phones?
7. Update `docs/metroidvania/README.md` and this plan's status table. **Stop.**

---

## Appendix · Where things are

| what | where |
|---|---|
| tick, blinks, gears, pistons, mutex, cables, loop room, triggers | `godot/src/world/room.gd`, `room_manager.gd` (loop iteration) |
| breakpoint, [special] priority | `godot/src/player/player.gd` |
| enemies | `heisenbug.gd`, `datarace.gd`, `deadlockpair.gd`, `spinlock.gd`, `ticker.gd`, `orphan.gd`, `priority.gd` (new) |
| bosses | `race_boss.gd`, `loop_boss.gd`, `deadlock_boss.gd` (new) on `boss.gd`'s kit |
| co-op | `coop.gd`, `net_classes.gd`, `watchdog.gd` |
| data | `docs/metroidvania/phase5a-data/` |
