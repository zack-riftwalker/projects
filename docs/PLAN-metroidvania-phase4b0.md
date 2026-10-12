# CLAWD Metroidvania — Phase 4B-0 Plan: engine groundwork and the boss kit (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. گام ۱ و ۲ از پلن کلی رو با هم داره، چون هر دو زیرساختن و منطقه‌ی بعدی (NETWORK، فاز 4B) به هر دو احتیاج داره.
>
> **چی ساخته می‌شه:**
> - **یه باگ co-op درست می‌شه:** الان وقتی میزبان از یه دریچه‌ی یک‌طرفه رد می‌شه (مثل کف sudoers)، مهمون باخبر نمی‌شه و درش بسته می‌مونه. از این به بعد فلگ‌های دنیا (باس‌ها، دریچه‌ها، symlink، ریسه‌ها) مثل وضعیت تو هر snapshot می‌رن.
> - **چیزهای تازه‌ی موتور** که منطقه‌های بعدی لازم دارن:
>   - قفل «۲ از ۳ فلگ» (برای fork/join برج)
>   - تابلویی که متنش با فلگ عوض می‌شه (TODO‌ی R06 بعد از پایان، git log)
>   - کاشی‌ای که بعد از باس عوض می‌شه، ولی هیچ‌وقت زیر پای کسی نه (پس‌لرزه‌ی باس‌ها)
>   - درِ symlink (در دوری که کنار اتاقش نیست)
>   - بسته‌ی متحرک و پورت زمان‌دار (سواری روی بسته در N12)
>   - درپوش یک‌طرفه روی سوراخ کف
> - **قرارداد باس‌ها (کیت باس):** کد مشترک همه‌ی باس‌های تازه:
>   - هر حمله اول با هشدار اعلام می‌شه (هدف و جای خطر).
>   - اگه مهمون هشدار رو دیر بگیره، حمله برای همه صبر می‌کنه یا لغو می‌شه.
>   - «باس هوشمند»: باس کاری که بازیکن کرده رو می‌خونه (طمع، heal، فاصله، آخرین ضربه‌زن)، نه دکمه‌ش رو.
>   - هدف تا آخر هر حمله عوض نمی‌شه.
> - **یه باس تمرینی (عروسک):** فقط برای تست کیت. تو بازی اصلی نیست.
> - **شش اتاق آزمایشگاه** (Z01 تا Z06) دور از نقشه‌ی اصلی، فقط برای تست‌ها و تست تو.
> - **اسکریپت چک نقشه** میره تو تست‌ها.
>
> **تو چی تست می‌کنی:**
> - تو co-op: میزبان از کف sudoers (H10) بیفته پایین؛ درِ سقف dangling_ptr.c برای دوستت هم باید باز بشه.
> - با `?debug&lab` بازی تو آزمایشگاه شروع می‌شه: سوار بسته‌ها شو و از پورت‌ها رد شو، بعد با دوستت با عروسک بجنگید و بگید هشدار حمله‌ها روی گوشی و با پینگ خوندنیه یا نه.
>
> **جلسه‌ی Sonnet رو خودم باز می‌کنم.** اگه خواستی دستی بدی: یه جلسه‌ی جدید با Sonnet روی برنچ `ph1` باز کن و بنویس «فایل `docs/PLAN-metroidvania-phase4b0.md` رو بخون و اجراش کن».

---

## 0. Rules of engagement

- **Read first, in order:**
  1. `CLAUDE.md` (especially "Godot version" and its co-op rules).
  2. This file, all of it.
  3. `docs/metroidvania/08-world-design.md` §8 and §10 (the engine needs and the rules of design pass 1).
  4. `docs/metroidvania/00-decisions.md` §13 and §14 (D31–D52).
  5. `docs/metroidvania/07-js-vs-godot.md` §3 (the co-op rules).
  6. `docs/reports/world-map-research-6-bosses.md` §2.2, §2.3, §5.2 and §5.3 (the boss timing contract this kit implements).
  7. Then the code under `godot/src` you are about to change.
  - Phase 4A's plan (`docs/PLAN-metroidvania-phase4a.md`) §0 still applies where this file does not say otherwise.
- **Do only phase 4B-0.** Stop after MVB0-11 and report. No NETWORK rooms, no curl or ssh: those are phase 4B.
- **Do not redesign.** Values, names, letters, paths, room files and JSON in this file and in `docs/metroidvania/phase4b0-data/` are decisions.
  - If one is impossible, take the smallest change that keeps the goal and list it under "deviations" in the report.
  - The lab rooms are data: copy them, do not redraw them. If one must change, change it in `phase4b0-data/` too and re-run the world checker.
- **Branch:** `ph1` only.
  - Start with `git fetch origin main ph1 && git checkout ph1 && git merge --no-edit origin/ph1 && git merge --no-edit origin/main`.
  - Push with `git push -u origin ph1`.
  - Never push or merge to `main`, and never open a PR.
- **Files you may touch:**
  - Allowed: everything under `godot/` and `tools/godot/`; `docs/metroidvania/`; `docs/reports/metroidvania-phase4b0.md`; this plan's status table.
  - **Not allowed:** `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`.
  - `public/mv/` changes only through `tools/godot/export-web.sh`, as the last commit of the phase.
- **Commits:** one commit per task (`MVB0-xx: <what>`), ending with the attribution lines your session gives you. Push after each.
- **Co-op rules (from `CLAUDE.md`, not optional):**
  - State over events.
  - Anything the guest's combat reads from a creature goes through `net_fields()`/`net_apply()` and the `parity` test.
  - Anything that hurts on contact is in `harmboxes()`, computed from those fields.
  - Host-side damage that is not a creature's contact goes through `room.harm_zone`.
  - The partner is seen late: use its recent reports, with limits that grow with ping.
  - A new kind of co-op bug gets a rule in `godot/src/net/watchdog.gd`.
  - Reliable event data lives only in `d`. Never name a field `i` or `k`.
- **Godot naming trap:** never name your own members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Tests:**
  - Every task names its tests.
  - A bug fix comes with a test that fails on the old code (MVB0-01).
  - Before the final commit: `bash tools/godot/test-all.sh` → `ALL PASS` (~30 min). Add every new `--test=` to its list and every new co-op scenario to `ALL=` in `tools/godot/coop-test.sh`.
- **Nothing that is built may change behaviour:** the parity tapes, every existing test and every existing co-op scenario keep passing. NULL, THE REVIEWER, MERGE CONFLICT and THE LEAK do not move to the kit in this phase.
- **The temporary "Skip boss" pause button stays.** It does not apply to the lab dummy (it is not a room boss).

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MVB0-01 | world flags travel in snapshots (fixes host-crossed `sets` doors never opening for the guest) | Sonnet | done |
| MVB0-02 | lab rooms Z01–Z06, `lab` rooms kept off the map, `?lab`; world checker in `test-all.sh` | Sonnet | done |
| MVB0-03 | lock `until:<k>of:<flags>`; one-way lids over floor holes | Sonnet | done |
| MVB0-04 | signs whose text depends on flags | Sonnet | done |
| MVB0-05 | tiles that change with a flag, never under or inside a body | Sonnet | done |
| MVB0-06 | symlink doors (two doors whose rooms do not touch) | Sonnet | done |
| MVB0-07 | packets (looping platforms, letter `J`) and ports (letter `3`) | Sonnet | done |
| MVB0-08 | boss kit 1: the attack plan, families and timings, tells, plan gating on the guest's acks | Sonnet | done |
| MVB0-09 | boss kit 2: target rules, the behaviour reader (rule 8), the guest's focus report | Sonnet | done |
| MVB0-10 | the sparring dummy `KitDummy` in Z06; `bosskit` test, `co-bosskit` scenario, watchdog rule `boss-cue` | Sonnet | done |
| MVB0-11 | tests, build, playtest steps, report → **stop** | Sonnet | done |

## 2. Facts already verified (do not rediscover)

Read by Claude in the code on `ph1` at commit `2a5f741`.

1. **Doors and locks.** `Room.update_doors()` (`godot/src/world/room.gd`) runs every step and knows four locks: `""`, `fight`, `until:<flag>` and `flood:<n>`. A door whose target room is not in `rooms.json` never opens. A closed door is solid (`grid.door_at`, `grid.tile(x, -1)` etc.).
2. **`sets` doors.** `RoomManager._on_door_crossed()` sets `Game.flags[d.sets]` for the local player. A guest's crossing reaches the host through the guest's room event (`Coop._host_door_sets`), checked by the watchdog rule `door-sets`.
3. **The bug MVB0-01 fixes.** The other direction is missing: a flag the **host** sets (by crossing a `sets` door, e.g. `hatch:H10S`) never reaches the guest while it plays. The guest's flags come only from the `start` message (joining), the room-scoped `gf` list in snapshots (`switch:`, `key:`, `gate:`, `dead:` of the snapshot's room) and `flag` events for `boss:` flags (sent together with abilities, `coop.gd` ~line 269). So after the host drops through H10's floor, the guest's `H04:N` (`until:hatch:H10S`) stays shut until the next join. `co-nsdoor` only tests guest → host.
4. **Room clock.** Snapshots carry `rt` (the host room's `time`); the guest snaps to it when more than 0.5 s off and eases into it otherwise (`coop.gd` ~line 1125). Moving platforms (`Room._move_platforms`) and blinking blocks are pure functions of `room.time`, so the guest computes them itself. Packets and ports in MVB0-07 must work the same way.
5. **Blinking blocks never close on a body:** `grid.blink_hold` keeps a cell open while any `players()` box overlaps it (`Room.step`). Ports reuse that idea.
6. **One-way tiles** (`=`): a player can drop through with [down]+[jump] (`player.gd` `drop_t`). That stays allowed on lids.
7. **N/S doors** (`RoomManager._place_in_target`): going up, the player arrives at the bottom of the room above, inside the hole, with at least `Player.JUMP` upward speed; falling, at `y = 1` with at least 60 px/s downward. W/E doors place the player by the **target door's own rows** (`new_y` from `t_door.b`), so a door pair whose rooms do not touch already lands correctly.
8. **Bosses.** `Boss` (`godot/src/enemies/boss.gd`) is host-simulated; the guest has a puppet built by `NetClasses.make()` that applies `net_fields()` (`NetClasses.record/apply`). The guest checks its own body against the puppet's `harmboxes()` in `Room.interact_combat` (a box with `sid` is a catchable strike). `Boss.pick_target()/next_target()` alternate targets; `aim_point()` leads a remote player by `Net.rtt + 0.18` (clamped 0.1–0.45 s).
9. **Difficulty multipliers already exist:** `Game.DIFF[diff].telegraph_mult` (easy 1.3) and `punish_mult` (easy 1.3, nightmare 0.9). THE REVIEWER uses them through `Game.dv()`; the kit uses the same two, unchanged.
10. **Snapshot acks.** The guest's state message (`st`, ~30 Hz) carries `sa` = the last snapshot number it applied; the host already uses it for `Net.rtt` (`coop.gd` ~line 400). The kit's plan gating (MVB0-08) uses the same `sa`.
11. **Who hit the boss.** `Room.boss_damage(boss, d, how)` knows `room.attacker` (the local player or a `RemotePlayer`) and `how` (`swipe`, `dash`, `agent`, `stomp`, caught projectiles). The guest's focus (heal) is **not** reported today: its `st` message has no such field.
12. **Tests.** Unit tests are `--test=<name>` functions in `godot/src/test/run_tests.gd` that load real rooms with `new_room(id)` / `new_manager()`; co-op scenarios are `sc_co_<name>()` in `coop_scenarios.gd`, run by `tools/godot/coop-test.sh` (`BADLINE_ALL=1` for a bad line). `t_parity` loads **every** room in `rooms.json`, so the lab rooms and the dummy must load cleanly.
13. **URL options** are parsed in `Game` (`game.gd` ~line 406): `debug`, `play`, `scenario`, `test`, ... A run with `test`, `scenario` or a guest never writes the save (`persist = false`).
14. **The world checker** (`docs/metroidvania/phase4b0-data/world_check.py`) passes on the current world and on the world plus the lab rooms: 131 rooms, 149 doors, `errors 0`.

## 3. Shared definitions

### 3.1 New map letters

| letter | what | notes |
|---|---|---|
| `3` | port cell | solid while closed, empty while open; open/closed comes from the room's packets (MVB0-07) |
| `J` | packet start | like `M`: the path runs along the row to the next `|`; the room's `packets` entry gives timing and width |

### 3.2 New `rooms.json` fields

| field | where | meaning |
|---|---|---|
| `"lab": true` | room | a test room: never on the pause map, never in Travel, not counted anywhere a player sees counts |
| `"lab_boss": "KitDummy"` | room | spawn this sparring dummy at the room's `B` letter (host/solo); it is an entity, not the room's boss fight |
| `"until:<k>of:<f1>,<f2>,..."` | door `lock` | open when at least `k` of the listed flags are set |
| `"symlink": true` | door | the door's partner is in a room that does not touch this one; only the world checker reads it |
| sign entry as a dict | `signs[i]` | `{"text": "...", "alt": [{"if": "<flag>" or "!<flag>", "text": "..."}]}`: the first `alt` whose condition holds wins, else `text`. A plain string still works |
| `"variants": [...]` | room | `{"if": "<flag>", "rect": [tx, ty, w, h], "from": "<letter>", "to": "<letter>"}`: while the flag is set, every cell of the rect that the room file has as `from` is `to` (MVB0-05) |
| `"packets": {...}` | room | `{"every": s, "speed": px/s, "w": tiles, "lead": px, "lag": px}` (MVB0-07) |

### 3.3 Flags

| flag | set by | read by |
|---|---|---|
| `lab:a`, `lab:b`, `lab:c`, `lab:solid`, `lab:open` | the lab tests (and `Z01:E` sets `lab:a`) | `Z01` |
| `link:lab` | crossing `Z04:W` | `Z03:E` |
| `thread:0/1/2`, `link:src` | phase 5 (named here so the world-flag list knows them) | THREAD TOWER, R06 |

`Game.WORLD_PREFIXES := ["boss:", "hatch:", "link:", "thread:", "lever:", "lab:"]`: the flags that are world state and travel to the guest (MVB0-01). Room-scoped flags (`switch:`, `key:`, `gate:`, `dead:`) keep travelling in `gf`; items, cracks, benches and plugins keep their own paths.

### 3.4 The lab rooms

All in `docs/metroidvania/phase4b0-data/`: `rooms/Z01.txt` … `rooms/Z06.txt` and `rooms-4b0.json` (the six `rooms.json` entries, ready to merge). Far from the world (x ≥ 3000), so they never touch a real room.

```
Z02 lab_lid (32x16, [3000, 984])  floor hole 14..17 with a one-way lid ====
  | S/N 14..17
Z01 lab_locks (32x16, [3000, 1000]) --E 9..12 (sets lab:a)--> Z03 lab_link_a (24x16, [3032, 1000]) ==E 9..12 symlink (until:link:lab)==> Z04 lab_link_b (24x16, [3200, 1040]) W 5..8 (sets link:lab)
  N door: until:2of:lab:a,lab:b,lab:c; sign with alts; variants lab:solid (blink 1111 -> wall), lab:open (floor patch -> air)

Z05 lab_ports (64x16, [3000, 1100]) packets J..| along row 8, ports in columns 20 and 36 --E 9..12--> Z06 lab_arena (24x14, [3064, 1102]) KitDummy at B
```

---

## MVB0-01 · World flags travel in snapshots (bug fix)

1. In `Game`, add `const WORLD_PREFIXES := ["boss:", "hatch:", "link:", "thread:", "lever:", "lab:"]` and `func world_flags() -> Array` (the set flags with one of those prefixes, sorted).
2. Host: every snapshot carries `wf` when the list changed since the last snapshot, and in any case every 10th snapshot (state, so a lost one corrects itself). Keep it out of the other snapshots (bandwidth).
3. Guest: on a snapshot with `wf`, set every listed flag (never clear one). Call `room.update_doors()` right away so a door that just opened is open on this frame.
4. **Test that fails on the old code** — co-op scenario `co-flags`:
   - The host goes to H10 and drops through its floor hole (it sets `hatch:H10S`). The guest stands in H04 under `H04:N`.
   - Pass: within 2 s (5 s with `SCN_SLOW`) the guest has `hatch:H10S` and its `H04:N` door is open (`grid.door_at("N", 107).open`).
   - Then the host crosses `Z01:E` (sets `lab:a`): the guest has `lab:a` within 2 s.
   - Then (after MVB0-05 exists) the host sets `lab:solid` while the guest stands in Z01 away from the blink cells: the guest's cells at `(17..20, 10)` become solid within 2 s.
   - No `INVARIANT` line.
5. Add `co-flags` to `ALL=`.

## MVB0-02 · Lab rooms, `?lab`, the world checker in the tests

1. Copy `phase4b0-data/rooms/Z0*.txt` to `godot/src/world/rooms/` and merge the six entries of `phase4b0-data/rooms-4b0.json` into `godot/src/world/rooms.json` (same formatting as the file).
2. `lab` rooms:
   - the pause map skips them (also the `scene=map` screenshot helper that marks every room visited);
   - Travel never lists them;
   - any count a player sees (rooms, fragments, secrets) leaves them out.
3. `?lab` (only together with `?debug`): `Game.lab = true`, `persist = false`, and a new game (solo or host) starts in Z05 at its `P`. A guest joins the host's room as usual.
4. Copy `phase4b0-data/world_check.py` to `tools/godot/roomcheck/world.py` (no other change) and add to `test-all.sh`, right after `smoke`: `run worldcheck python3 -I tools/godot/roomcheck/world.py`. It must print `errors 0`.
5. Tests:
   - `parity` keeps passing with the six new rooms (it loads every room).
   - New unit test `lab`: every `Z0*` room loads; `Z0*` rooms are not in `RoomManager.travel_targets()`; the pause map's room list (whatever function feeds it) has no `Z0*` even with `room:Z01:visited` set.

## MVB0-03 · Lock `until:<k>of:<flags>`; one-way lids

1. `update_doors()`: `until:<k>of:<f1>,<f2>,...` is open when at least `k` of the flags are set. Plain `until:<flag>` keeps working. Parse once at load if you like, not every frame by string splitting.
2. One-way lids need no new code (a `=` row over a floor hole); this task proves it.
3. Unit test `locks4b` (Z01, Z02):
   - No flags: `Z01:N` closed (`grid.tile(15, -1)` solid). `lab:a` only: closed. `lab:a` + `lab:c`: open. A test door with `until:1of:lab:b` (built in the test from Z01's door dictionary): open with `lab:b` alone.
   - With the door open, a player in Z01 standing on the `========` ledge (row 4) jumps straight up under the hole: it arrives in Z02 and, within 1 s, stands on the lid (`on_ground`, `y + h <= 15 * 16`).
   - Walking left and right across the lid for 1 s, it stays in Z02.
   - [down]+[jump] on the lid drops it back into Z01 (allowed: the lid stops accidents, not choices).

## MVB0-04 · Signs that change with flags

1. A `signs[i]` entry may be a dict (§3.2). The text is chosen when the sign is read (shown), not only at load, so a flag set while the player is in the room shows at once.
2. Conditions: `"<flag>"` (set) or `"!<flag>"` (not set). Nothing else in this phase.
3. Both pages compute it from their own flags (state; MVB0-01 brings the world flags to the guest).
4. Unit test `signs4b` (Z01's sign): no flags → `lab: waiting for a.`; `lab:a` → `lab: nothing joined yet.`; `lab:a` + `lab:c` → `lab: c joined.` (the first matching `alt` wins). A plain-string sign in R08 still reads as before.

## MVB0-05 · Tiles that change with a flag

1. `variants` (§3.2). At load, every variant whose flag is set is applied to the grid and the view.
2. While the room is loaded, when a variant's flag becomes set, its cells are applied one by one, each only when it is safe:
   - a cell becoming solid (or a port, or a hazard) waits while any body overlaps it: `players()` and every creature;
   - a cell becoming empty waits while any body stands on it (a body whose feet are within 2 px above the cell's top and overlap it horizontally).
   - Pending cells are retried every step. This is the rule of 08 §10.1: never a solid tile inside a partner, never a floor vanishing under one.
3. The guest applies variants from its own flags with the same rule (its own body plus the puppets it sees).
4. Flags never clear in this phase, so variants only go one way.
5. Unit test `variants4b` (Z01):
   - `lab:solid` set before load: cells `(17..20, 10)` are `SOLID`.
   - Loaded first, a player box overlapping `(18, 10)`, then `lab:solid` set: `(17, 10)`, `(19, 10)`, `(20, 10)` turn solid at once, `(18, 10)` only after the player moves away.
   - `lab:open` with a player standing on `(25, 13)`: `(24, 13)`, `(26, 13)`, `(27, 13)` open, `(25, 13)` waits until the player steps off.
   - The view shows the changed cells (whatever `apply_tile`/`erase_tile` path the room uses).

## MVB0-06 · Symlink doors

1. No engine change is expected (fact 7). If the guest's or the host's room bookkeeping assumes neighbouring rooms anywhere, fix that.
2. Unit test `symlink` (Z03, Z04):
   - `Z03:E` is closed without `link:lab`.
   - A player standing on Z04's row-9 ledge walks west through `Z04:W` (rows 5..8): it arrives in Z03 at its east edge standing on Z03's floor (row 13), because the engine keeps the height above the door's bottom row (Z04's door ends at row 8, Z03's at row 12); and `link:lab` is set.
   - Then walking east through `Z03:E` lands in Z04 on the row-9 ledge.
3. Co-op: the guest crosses `Z04:W` → the host has `link:lab` (the existing `door-sets` path); covered by `co-flags`' second half if convenient, else a short `co-symlink`.

## MVB0-07 · Packets and ports

**Packets** (letter `J`, the room's `packets` entry):

1. The path runs from the `J` cell along the row to the next `|` (exactly like `M`): `x_a = J column × 16`, `x_b = (| column + 1) × 16 − w × 16`. `y` = the row's top + 2, like `M`.
2. `n = ceil((x_b − x_a) / (speed × every)) + 1` packets. Packet `j` (0..n−1): `u = fposmod(time + j × every, n × every)`; `x = x_a + u × speed`; it exists only while `x <= x_b`. Pure function of `room.time` (fact 4): the guest computes the same.
3. A packet is a platform `w × 16` px wide (default 4 tiles) that carries riders like `M` platforms (use the `plats` carry path with `dx`). A packet that does not exist has no collision. It never collides with walls or ports (it passes through a port only while that port is open; see below).
4. Draw: a packet of light (two-tone bar, bright front edge). No new art file.

**Ports** (letter `3`):

5. A port column (the `3` cells sharing a column) is **open** while some existing packet satisfies `packet.x + packet.w ≥ X − lead` and `packet.x ≤ X + 16 + lag`, where `X` = the column's left pixel. Otherwise closed (solid).
6. A closed-to-be port cell stays open while any `players()` box or any creature overlaps it (the blink-hold idea, fact 5). It never closes on a body.
7. Draw: a closed port is a red bar with its number painted on the middle cell (the column order in the room: 22, 80, 443, then 8080 for a fourth); an open port is a faint outline.

**Tests:**

8. Unit test `packets` (Z05):
   - Two rooms loaded at different moments, then given the same `time`: identical packet positions and port states.
   - At a time when no packet is near column 20, `grid.tile(20, 5)` is solid; when a packet's front is 16 px before it, open.
   - A player overlapping `(20, 6)` while the port would close: stays open until the player leaves.
   - A player placed on a packet just after `x_a`: carried through both ports and still on a packet (or on the end ledge) when the packet passes column 50; never inside a solid cell on the way.
   - `mode = "guest"` gives the same port states at the same `time`.
9. Co-op scenario `co-packet`: host and guest in Z05; the guest rides a packet from the start to the end ledge; the host sees the guest's body past column 50 within 12 s (30 s with `SCN_SLOW`); no `INVARIANT`. Must also pass with `BADLINE_ALL=1`.

---

## MVB0-08 · Boss kit 1: the attack plan

The kit lives in `Boss` (opt-in: a boss that never calls `plan_start` behaves exactly as today) plus `godot/src/enemies/boss_read.gd` (MVB0-09). Names below are decisions.

**The plan.** One attack at a time:

```
var plan := {}      # {} = no attack. Else:
                    # seq: int (host counter, never reused in a room)
                    # id: String (the attack's name, e.g. "lunge")
                    # fam: String (a key of FAMILY)
                    # tgt: "p1" | "p2" | "" (p1 = the host's player, p2 = the guest's)
                    # ph: "cue" | "active" | "recover"
                    # t: float (seconds left in this phase)
                    # fp: [x, y, w, h] (the danger footprint in room pixels, for the tell)
                    # lock: float (seconds before the end of the cue when the target point stops following; 0 = fixed at start)
var plan_seq := 0
var seen_seq := 0   # host: the newest plan seq the guest has acknowledged (Coop writes it); solo: always plan.seq
var hold_t := 0.0   # host: how long the end of this cue has been held for the guest
```

**Families** (research report 6, §2.3, Normal; the cue × `telegraph_mult`, the recovery × `punish_mult`, never below 0.4 s):

| fam | cue | active | recover | tell |
|---|---|---|---|---|
| `lunge` | 1.00 | 0.35 | 0.90 | pose + a line along the path; the aim is fixed for the last 0.40 s |
| `proj` | 0.85 | until the shots are spent (travel ≥ 0.45 s) | 1.00 | the boss glows; yellow diamonds = catchable |
| `slam` | 1.20 | 0.30 | 1.20 | a ground stencil under the target; its x is fixed 0.50 s before the impact |
| `sweep` | 1.60 | 0.60 | 1.40 | the whole footprint; a safe lane ≥ 4 tiles |
| `flood` | 2.50 | 1.00 | 1.75 | the safe destination and the new level |
| `dual` | 1.60 | 0.50 | 1.50 | two markers, numbered 1 and 2 |
| `guard` | 0.50 | 1.20 | 0.40 | a raised guard with a `// nit:` bubble |

```
const FAMILY := {"lunge": [1.0, 0.35, 0.9], "proj": [0.85, 0.6, 1.0], "slam": [1.2, 0.3, 1.2], "sweep": [1.6, 0.6, 1.4],
                 "flood": [2.5, 1.0, 1.75], "dual": [1.6, 0.5, 1.5], "guard": [0.5, 1.2, 0.4]}
const SEEN_MIN := 0.35   # the guest has the plan at least this long before it turns active
const HOLD_MAX := 0.60   # longer than this unseen: the attack is cancelled for everyone (it goes to recover without hurting)
```

**API** (host/solo; the puppet only applies fields):

- `plan_start(id, fam, tgt, fp, lock := 0.0) -> void`: a new seq; `ph = "cue"`, `t = cue`.
- `plan_step(dt) -> String`: counts down; returns the phase that **just began** (`"active"`, `"recover"`, `"done"`) or `""`. The cue → active step is gated:
  - solo, or no guest in this room: no gating;
  - with a guest in the room: active may begin only when `seen_seq >= plan.seq` **and** at least `SEEN_MIN` has passed since the host learned that (keep the host time of that moment); while waiting, `hold_t += dt`;
  - if `hold_t > HOLD_MAX`: skip the active phase (no harm at all), go to `recover`, `Game.dlog("<boss> plan <seq> cancelled: the guest did not see it")`.
- `plan_phase() -> String`, `plan_active() -> bool`.
- `plan_fields() -> Array` / `plan_apply(a: Array)`: `[seq, id_index, fam_index, tgt (0 none, 1 p1, 2 p2), ph_index, t×100, fp…, lock×100]`. A kit boss appends them to its `net_fields()`; the `parity` test then covers them.
- `draw_plan(ci)`: during `cue`, the footprint as a hazard stencil (shape + stripes + a short `!`), and over the target a marker: **a circle with "1" for P1, a diamond with "2" for P2** (the same shapes the map will use, 08 §10.7 M3). Colour is never the only signal. Yellow means catchable, always.
- A kit boss returns harm only from `harmboxes()` computed from the plan during `active` (so the guest is hurt only by what it was shown).

**Coop: who has seen what.**

- When the host builds a snapshot, for each creature that has `plan` and a new `plan.seq`, remember `[nid, seq, snap_n]` (first snapshot carrying that seq).
- When a guest `st` arrives with `sa`, every remembered entry with `snap_n <= sa` sets that boss's `seen_seq` (and the host time it happened). Drop old entries.
- Solo / no guest: `seen_seq = plan.seq` at once.

**Tests** (MVB0-10's `bosskit` unit test covers these): family timings on normal and easy; gating (unseen → held, cancelled after `HOLD_MAX`; seen at 0.2 s → active starts ≥ 0.2 + `SEEN_MIN`); solo → no wait; plan fields round-trip.

## MVB0-09 · Boss kit 2: targets and the behaviour reader (rule 8)

**Target rules** (research report 6, §5.3; replace nothing in the four built bosses):

1. `kit_pick_target() -> String` (`"p1"`/`"p2"`), called only when a new attack starts. The target never changes during cue, active or recover.
2. Score per player in the room (alive, not lagging): +2 if nearest to the boss, +1 if it was targeted least recently, +1 if it was the last to hit the boss. Highest wins; ties go to the one not targeted last.
3. Never three attacks in a row on the same player while the other is in the room, alive and not lagging.
4. Solo: always the one player. If the partner leaves, goes down or lags, the boss is solo from the next attack (rule 5 of the B1 contract).

**The reader** (`class_name BossRead extends RefCounted`, `godot/src/enemies/boss_read.gd`; host only; a kit boss owns one):

- Per player key (`"p1"`, `"p2"`): samples every 0.1 s for the last 1.0 s: distance to the boss centre, on ground, under the boss (`|dx| < 20` and above the floor), focusing.
- Hits: `Room.boss_damage()` calls `boss.read.note_hit(key, how)` for a kit boss (key from `room.attacker`: the local player is `p1`, a `RemotePlayer` is `p2`).
- Queries: `dist(key)`, `greedy(key, n := 3, secs := 1.2, near := 48.0) -> bool` (at least `n` swipes in `secs` while within `near` px), `healing(key)`, `under(key)`, `last_hitter() -> String`, `last_how(key) -> String`.
- The guest is read from its reports (late by design): that is the point of rule 8. Never read button presses.

**The guest's focus.** Add `"fo": 1 | 0` (focusing: `focus_t >= 0`) to the guest's `st` message; `RemotePlayer.focusing` on the host. The host's own player is read directly. Document the field next to the other `st` fields in `docs/metroidvania/07-js-vs-godot.md` (protocol notes) or wherever the Godot `st` fields are listed.

## MVB0-10 · The sparring dummy, `bosskit`, `co-bosskit`, `boss-cue`

**`KitDummy`** (`godot/src/enemies/kit_dummy.gd`, `class_name KitDummy extends Boss`; NetClasses index 25, name `"kitdummy"`):

- A 18×26 grey practice dummy drawn with rectangles (no new art). Name "SPARRING DUMMY", sub "boss kit".
- Spawned by `lab_boss` at Z06's `B` (MVB0-02 data). It starts when a player is within 160 px and idles when none is in the room.
- Never dies: hp 999; when `hpf` falls under half, it is reset to `max_hp` (a sparring partner). No drop, no reward, no flag.
- The cycle, using only the kit: `lunge` (target's lane, `lunge` family) → `orbs` (`proj`: two yellow catchable diamonds at the target, travel ≥ 0.45 s) → `drop` (`slam`: a 4-tile stencil at the target's x, fixed 0.5 s before impact) → again.
- Rule 8: if `read.greedy(key)` for any player when an attack is to be chosen, the next attack is `guard` on that player (blocks swipes and dashes like THE REVIEWER's `review`, `blocks()`); a swipe into the guard is answered by `riposte` (`lunge` family, cue 0.8 s × `telegraph_mult`) on the hitter.
- Its `net_fields()` = its own fields + `plan_fields()`; `harmboxes()` only from the active plan (and its projectiles through `room.shoot`, catchable).

**Unit test `bosskit`** (Z06):

1. Timings: for each family, `plan_start` on `normal` and `easy` gives the table's cue and recover × the multipliers (recover never below 0.4).
2. Gating: host mode with a fake remote player in the room and `seen_seq` held back → the plan stays in `cue` and is cancelled to `recover` after `HOLD_MAX`, with no harmbox at any step; `seen_seq` set 0.2 s after the cue's end → `active` begins at ≥ 0.2 + `SEEN_MIN`; solo → `active` right at the cue's end.
3. Targets: with the local player and a `RemotePlayer` both alive for 40 s of simulated fight: the target never changes inside an attack; no three attacks in a row on one player; both are targeted at least four times.
4. Rule 8: three swipes from 40 px within 1.0 s by `p2` → the next attack is `guard` on `p2`; a swipe into the guard is blocked and the following attack is `riposte` on the hitter.
5. Parity: `KitDummy` is in `t_parity`'s creature list (record → apply → the same `harmboxes()` mid-cue and mid-active).

**Co-op scenario `co-bosskit`** (Z06; also with `BADLINE_ALL=1`):

- Both players in Z06 (host and guest bots stand at different x, swing now and then; their hp is kept full so nobody goes down).
- 25 s of fight (60 s with `SCN_SLOW`).
- Guest side: for every plan seq it sees, the time it was shown in `cue`. Pass: at least 6 plans seen; every plan that turned `active` on the guest was shown in `cue` for ≥ 0.30 s; the guest was targeted at least twice.
- Host side: both players targeted; no target change inside an attack.
- No `INVARIANT` on either page.

**Watchdog rule `boss-cue`** (guest): when a kit puppet's plan turns `active`, the guest must have shown that seq in `cue` for ≥ 0.30 s (guest time). Otherwise `INVARIANT boss-cue: plan <seq> active after <x> s of cue` (grace 0). This is the co-op bug class "the guest was hit by an attack it never saw".

Add `bosskit` (and `locks4b signs4b variants4b symlink packets lab`) to the test list and `co-flags co-packet co-bosskit` to `ALL=`.

## MVB0-11 · Tests, build, playtest steps, report — then stop

1. Add every new test to `test-all.sh`'s `for t in ...` list: `lab locks4b signs4b variants4b symlink packets bosskit`.
2. Add to `ALL=` in `coop-test.sh`: `co-flags co-packet co-bosskit` (and `co-symlink` if you made it).
3. `python3 -I tools/godot/roomcheck/world.py` → `errors 0`.
4. `bash tools/godot/test-all.sh` → `ALL PASS`.
   - The known timing-sensitive tests from `CLAUDE.md` may be re-run once.
   - Also run `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-flags co-packet co-bosskit co-nsdoor co-leak`.
5. Export with `tools/godot/export-web.sh` as the **last** commit (`MVB0-11: export public/mv`).
6. Write `docs/reports/metroidvania-phase4b0.md` with:
   - what was done;
   - deviations;
   - test results (including the bad-line runs);
   - the kit's API as built (names and signatures), so the phase 4B plan can be written against it;
   - **playtest steps for Zakaria in Persian**, short:
     - co-op: the host drops through the floor of `sudoers` (H10); the friend in `dangling_ptr.c` (H04) sees the ceiling hatch open (the fixed bug);
     - `?debug&lab`: ride a packet through the two ports; try the ports on foot;
     - in the arena next door, fight the dummy together; say whether every attack's warning (stencil, marker 1/2, yellow) is readable on the phone over the internet, and whether hitting it greedily makes it guard;
     - a normal co-op run through the HEAP still works.
7. Update `docs/metroidvania/README.md` (phase 4B-0 done) and this plan's status table.
8. Then **stop** and report. Phase 4B (THE NETWORK) is a separate plan and session.

---

## Appendix A · Where things are

| what | where |
|---|---|
| tiles, doors, collision | `godot/src/core/tile_grid.gd` |
| room loading, letters, doors, platforms, combat checks | `godot/src/world/room.gd` |
| static tile drawing | `godot/src/world/room_view.gd` |
| room swaps, transitions, `sets` | `godot/src/world/room_manager.gd` |
| flags, URL options, difficulty | `godot/src/autoload/game.gd` |
| bosses | `godot/src/enemies/boss.gd` and one file per boss |
| co-op | `godot/src/net/coop.gd`, `net_classes.gd`, `watchdog.gd`, `godot/src/player/remote_player.gd` |
| pause map | `godot/src/ui/pause.gd` |
| tests | `godot/src/test/run_tests.gd`, `coop_scenarios.gd`, `tools/godot/test-all.sh`, `coop-test.sh` |
| data for this phase | `docs/metroidvania/phase4b0-data/` (lab rooms, `rooms-4b0.json`, `world_check.py`) |
| design checker (Claude's, reachability) | `tools/godot/roomcheck/check4a.py` (`sim.py`, `reach.py`) |

## Appendix B · Why these and not more

- Abilities (curl, ssh), new enemies and the NETWORK rooms are phase 4B; the map rework (`tree`, M1–M10) is step 3 of the roadmap; agents, logbook pages and the built-zone changes are step 4.
- The kit is proved on a dummy first so the WEB CRAWLER in 4B is written against a kit that already passed a bad line.
- Things the design needs later but this phase does not build: the escape wall of P11 (phase 5D), the checkout lever (5B), the cartographer (step 3), sign text generated from the game's history (5B, S6).
