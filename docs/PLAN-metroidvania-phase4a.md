# CLAWD Metroidvania — Phase 4A Plan: THE HEAP (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. همه‌ی تصمیم‌ها گرفته شدن و Sonnet فقط اجرا می‌کنه.
>
> **فاز ۴ دو تیکه‌ست:** ۴A (این فایل) منطقه‌ی **THE HEAP**، و ۴B (فایل بعدی) منطقه‌ی **THE NETWORK**. آخر ۴A، Sonnet می‌ایسته که تو تست کنی.
>
> **چی تو ۴A ساخته می‌شه:**
> - **۱۶ اتاق HEAP**. ورودیش از R11 ـه، پشت دروازه‌ی catch. سه مرحله از بازی JS هم توشه: `malloc.c`، `dangling_ptr.c` و `stack_overflow.c`.
> - **درهای بالا و پایین (N/S):**
>   - از سقف که رد بشی، یه هل رو به بالا می‌گیری تا رو لبه‌ی اتاق بالایی فرود بیای.
>   - از کف که بیفتی، می‌ری اتاق پایینی.
>   - بعضی‌هاشون دریچه‌ی یک‌طرفه‌ان: از یه طرف باز می‌شن و بعدش همیشه بازن.
> - **سیل سه‌مرحله‌ای:**
>   - اول کار، کف هاب (`free_list.h`) زیر آبه.
>   - شیر `free.c` رو با catch بزنی، آب پایین می‌ره و در تازه پیدا می‌شه.
>   - بعد از کشتن **THE LEAK** آب کامل خالی می‌شه و درهای آخر و راه پایین به DEPTHS باز می‌شن.
> - **`stack_overflow.c` با سیل بالارونده:** مایع دنبالت می‌آد و باید سریع بری بالا.
> - **دیوار dead code (در مخفی):** شبیه دیواره ولی ازش رد می‌شی. پروانه‌ها دورش می‌چرخن.
>   - رد که بشی، برای همیشه پیدا می‌مونه.
>   - **آجر قرمز فایروال** رو هم می‌بینی، ولی تا ۴B (ssh) ازش رد نمی‌شی.
> - **دشمن‌ها:**
>   - از بازی JS: Slime (با مرگ دو تا می‌شه)، Lint، چکه‌کن، پاندول، پهپاد.
>   - جدید: **SEGFAULT** (سمتت می‌دوه و منفجر می‌شه؛ انفجارش دیوار فولادی رو هم می‌شکنه) و **STACK OVERFLOW** (برج باگ‌ها که روت می‌افته و سه تا باگ می‌شه).
> - **باس THE LEAK:** حباب حافظه‌ای که آرنا رو آب می‌کنه. جایزه‌اش **sudo** ـه (پرش دوم).
> - **سفر سریع فقط از ترمینال‌ها:** R08، D04، H03.
> - **سه اتاق مخفی تازه تو SOURCE TREE:**
>   - بالای R01 با catch (تکه‌ی حافظه).
>   - بالای R02 با sudo (پلاگین `--verbose` که دیوارهای dead code رو نشون می‌ده).
>   - بالای R03 با agents (پلاگین `restart: always`).
>
> **همه‌ی نقشه‌ی اتاق‌ها رو خودم ساختم و با یه شبیه‌ساز حرکت Clawd چک کردم:** هر در رسیدنیه و هیچ‌جا گیر نمی‌کنی. Sonnet فقط کد موتور رو می‌نویسه و داده‌ها رو کپی می‌کنه.
>
> **جلسه‌ی Sonnet رو خودم باز می‌کنم.** اگه خواستی دستی بدی: یه جلسه‌ی جدید با Sonnet روی برنچ `ph1` باز کن و بنویس «فایل `docs/PLAN-metroidvania-phase4a.md` رو بخون و اجراش کن».

---

## 0. Rules of engagement

- **Read first, in order:**
  1. `CLAUDE.md` (especially "Godot version" and its co-op rules).
  2. This file.
  3. `docs/metroidvania/08-world-design.md` §3 (THE HEAP) and §8.
  4. `docs/metroidvania/00-decisions.md` §13 (D31–D36).
  5. `docs/metroidvania/07-js-vs-godot.md` §3 (the co-op rules).
  6. Then the code under `godot/src` you are about to change.
  - Phase 3's plan (`docs/PLAN-metroidvania-phase3.md`) §0 still applies where this file does not say otherwise.
- **Do only phase 4A.** Stop after MV4-10 and report.
- **Do not redesign.** Values, names, letters, paths, maps and JSON in this file and in `docs/metroidvania/phase4a-data/` are decisions.
  - If one is impossible, take the smallest change that keeps the goal and list it under "deviations" in the report.
  - **Never edit a room file by hand.** If a map must change, edit it in `phase4a-data/` (and `rooms-4a.json`), re-run `apply.py`, then re-run `python3 -I tools/godot/roomcheck/check4a.py` (it must end with `0 problems`). Say so in the report.
- **Branch:** `ph1` only.
  - Start with `git fetch origin main ph1 && git checkout ph1 && git merge --no-edit origin/ph1 && git merge --no-edit origin/main`.
  - Push with `git push -u origin ph1`.
  - Never push or merge to `main`, and never open a PR.
- **Files you may touch:**
  - Allowed: everything under `godot/` and `tools/godot/`; `docs/metroidvania/`; `docs/reports/metroidvania-phase4a.md`; this plan's status table.
  - **Not allowed:** `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`.
  - `public/mv/` changes only through `tools/godot/export-web.sh`, as the last commit of the phase.
- **Commits:** one commit per task (`MV4-xx: <what>`), ending with the attribution lines your session gives you. Push after each.
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
  - A bug fix comes with a test that fails on the old code.
  - Before the final commit: `bash tools/godot/test-all.sh` → `ALL PASS` (~30 min). Add every new `--test=` to its list, every new co-op scenario to `ALL=` in `tools/godot/coop-test.sh`, and every new etrace case to `enemy-cases.sh`.
- **Movement must not change:** the seven parity tapes against the JS game must keep passing. The double jump (`tools.sudo`) is already in `player.gd`; do not touch it.
- **The temporary "Skip boss" pause button stays.** It must work for THE LEAK too (it uses the room's `boss` entry, so it should without changes).

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MV4-01 | room data in; N/S doors; door `sets` flags and `flood:` locks; terminal-only travel | Sonnet | done |
| MV4-02 | tiles: dead code `;`, firewall brick `N`, bulkhead `0`; GET ring `@`; moths; `Room.blast` | Sonnet | done |
| MV4-03 | flood levels, the valve, rising flood; co-op | Sonnet | done |
| MV4-04 | plugins `--verbose`, `restart: always` | Sonnet | done |
| MV4-05 | world 3 look: tiles, backdrop, theme, music `w3`, THE LEAK sprite | Sonnet | done |
| MV4-06 | JS ports: Slime, Lint, Dripper, Pendulum, Drone (etrace parity) | Sonnet | done |
| MV4-07 | SEGFAULT and STACK OVERFLOW (new) | Sonnet | done |
| MV4-08 | THE LEAK v2 → sudo | Sonnet | done |
| MV4-09 | HEAP walk-through tests; retrofits' secrets; end door in `mmap.c` | Sonnet | done |
| MV4-10 | tests, build, playtest steps, report → **stop** | Sonnet | done |

---

## 2. Facts already verified (do not rediscover)

- **Positions in tests** are top-left pixel positions of the player's 10×10 box. "On a floor whose top is row r" means `y = r*16 - 10`.

- **All room maps are done and checked.** They live in `docs/metroidvania/phase4a-data/`:

  | file | what |
  |---|---|
  | `rooms/` | H01–H16, R12, R13, R15 |
  | `R11.txt`, `D04.txt` | full replacements of hand-made rooms |
  | `room-edits-4a.json` | new edits for the generated rooms R01, R02, R03, D03 |
  | `expected/` | what `make-rooms.py` must produce for those four |
  | `rooms-4a.json` | every new or changed `rooms.json` entry |
  | `apply.py` | puts it all in place |

  - `tools/godot/roomcheck/check4a.py` (Claude's design checker) re-checks all of it:
    - every door's cells, floor and partner door;
    - world alignment;
    - no overlaps;
    - reachability of every route with a movement simulator that ports `Player.update`.
    - It prints `0 problems` today.
- **Movement heights the gates are built on.** Measured with the simulator; JUMP 300, G_UP 830, apex float included:

  | move | rise |
  |---|---|
  | jump | 57 px |
  | jump + double jump | 104 px |
  | jump + bash up | 116 px |
  | all three | ~160 px |

  - So a "sudo only" gate needs a rise between ~120 and ~150 px. R02's notch needs 134.
  - The `curl` ring hole in H01 needs 182: impossible until 4B.
- **JS sources** (`public/index.html`):

  | what | lines |
  |---|---|
  | `class Lint` | 3791 |
  | `class Slime` | 3865 |
  | `class Drone` | 3929 |
  | `class Pendulum` | 3957 |
  | `class Dripper` | 3989 |
  | `leakSpr` (the sprite builder) | 4377–4388 |
  | `class Leak` | 4389–4490 |
  | `G.drawLiquid` | 2410 |
  | the rising liquid | 2941–2947 |
  | the liquid hazard | 3003 |
  | the tide backing off after a hazard | 3588–3589 |
  | co-op: the guest's hazard pushes the tide | 6865 |
  | co-op: snapshot `ly` | 6985 |
  | co-op: snapshot `ly` applied | 7200 |

  - `const FLOOR = 176` (4044) is `Boss.FLOOR`.
  - JS 3-3 has `rise: {trigger: 55, speed: 19, top: 5}`. Ours differs: see H06.
- **Sprites already in `godot/assets/sprites/`:** `slime_0/1`, `slimeS_0/1`, `lint_0/1`, `drone_0..3`, `pendulum`, `bug_0/1`, `gate`. Missing: `leak_0/1` (MV4-05).
- **Godot today (head 7fd6082):**
  - Doors are W/E only:
    - `TileGrid.tile()` opens the W/E edge for `doors[{side,a,b,open}]` and treats `ty < 0` as SOLID and `ty >= h` as air (a pit).
    - `Room._check_door()` looks only at `mid_x`.
    - `RoomManager._place_in_target()` maps only W/E.
  - Bench travel goes from any rested bench (`bench_menu.gd` "Travel").
  - `Room.liquid_y` exists but nothing uses it.
  - `Game.tools.sudo` and the double jump exist.
  - The boss intro trigger is `q.x + q.w/2 > trigger_x` (only an entry from the west).
  - `Coop._guest_joined` finds an arena's entrance as its `W` door.
- **A trap found while reading `TileGrid.tile()`:** `if d.open and (d.side == "W") == (tx < 0) and ...` is also true for a door whose side is N or S on the east edge. A N/S door with columns `a..b` would open rows `a..b` of the east wall. MV4-01 fixes it, and its test checks it.

---

## 3. Shared definitions

### 3.1 Map letters (new in 4A)

| letter | what | kind | task |
|---|---|---|---|
| `;` | dead code: drawn as wall, walked through; revealed for good once touched | tile `DEAD = 12` | MV4-02 |
| `N` | firewall brick: solid (ssh passes it in 4B) | tile `FIRE = 13` | MV4-02 |
| `0` | bulkhead: solid; only `Room.blast` breaks it (a SEGFAULT) | tile `THICK = 14` | MV4-02 |
| `@` | GET ring: decoration in 4A (the `curl` anchor in 4B) | object | MV4-02 |
| `s` | Slime (big; splits in two small ones) | enemy | MV4-06 |
| `l` / `L` | Lint, horizontal / vertical | enemy | MV4-06 |
| `i` | Dripper (ceiling) | enemy (hazard) | MV4-06 |
| `p` | Pendulum (anchor in this cell) | enemy (hazard) | MV4-06 |
| `d` | Drone | enemy | MV4-06 |
| `x` | SEGFAULT | enemy | MV4-07 |
| `q` | STACK OVERFLOW | enemy | MV4-07 |

- Existing letters keep their meaning (`Y` catch switch, `!` catch gate, `k` slot key, `&` agents gate, `S` spring, `*` memory fragment, `U` plugin, `T` sign, `C` bench, `D` end door, `B` boss spawn).
- `Room.reserved()` already treats every non-space letter as reserved, so no decor grows on the new ones.

### 3.2 `rooms.json` fields (new)

| field | where | meaning |
|---|---|---|
| door `"side": "N"` / `"S"` | doors | `a..b` are **columns** of the top / bottom edge |
| door `"sets": "<flag>"` | doors | crossing this door sets the flag (saved) |
| door `"lock": "flood:<n>"` | doors | open while `Game.heap_flood() <= n` |
| `"terminal": true` | room | its bench offers Travel (to other rested terminals only) |
| `"flood": [r2, r1, r0]` | room | the liquid surface row at flood level 2 / 1 / 0, or `null` for none. Surface pixel `y = row * 16 + 6` |
| `"rise": {"trigger", "speed", "top"}` | room | the rising flood (rows, px/s, rows) |
| `"valve": true` | room | its `Y` switch is drawn as a valve wheel |
| boss `"trigger_side": "E"` | boss | the intro starts when a player's centre x is **below** `trigger_x` (an arena entered from the east) |

- The existing door `lock` values (`"fight"`, `"until:<flag>"`) stay.
- A door whose target room is not in `rooms.json` never opens (as today). The 4A data uses that for:
  - `H11:E` → `N01`, which comes in 4B;
  - `H11:N` → `T02`, phase 5;
  - `H15:E` → `F01`, phase 6.

### 3.3 Flags (in `Game.flags`, saved, sent in `start`)

| flag | meaning |
|---|---|
| `hatch:H10S`, `hatch:H10N` | set by crossing the `sets` doors |
| `dead:<room>` | that room's dead code is revealed |
| `gate:H07:catch` | the valve (it is the existing catch-gate flag of H07): **flood level 1** |
| `boss:LEAK`, `ability:sudo` | THE LEAK is beaten: **flood level 0** |
| `crack:<room>:<tx>:<ty>` | now also marks a broken bulkhead cell |
| `plugin:verbose`, `plugin:restart_always` | plugins owned |

### 3.4 `Game.heap_flood() -> int`

```gdscript
var flood_net := -1          # guest: the host's flood level from the last snapshot (-1 = none yet)
func heap_flood() -> int:
	if net_role == "guest" and flood_net >= 0:
		return flood_net
	if flag("boss:LEAK"):
		return 0
	if flag("gate:H07:catch"):
		return 1
	return 2
```

`Game.fresh()` sets `flood_net = -1`.

---

## MV4-01 · Room data, N/S doors, door flags, terminal travel

1. **Room data.** Run `python3 -I docs/metroidvania/phase4a-data/apply.py`.
   - It copies the rooms, appends the edits, re-runs `make-rooms.py`, checks the four generated rooms against `expected/`, and rewrites `rooms.json`, which has 37 rooms after it.
   - If it stops, report.
   - Commit the changed files under `godot/src/world/` in this task's commit.
   - Until later tasks port them, unknown enemy letters only print the existing "not ported yet" warning, and the new tile letters load as air. That is fine in between, but not at the end.
2. **`TileGrid.tile(tx, ty)`** becomes exactly:
   ```gdscript
   func tile(tx: int, ty: int) -> int:
   	if ty < 0:
   		for d in doors:
   			if d.side == "N" and tx >= d.a and tx <= d.b:
   				return E if d.open else SOLID
   		return SOLID
   	if tx < 0 or tx >= w:
   		if ty < h:
   			var want := "W" if tx < 0 else "E"
   			for d in doors:
   				if d.side == want and d.open and ty >= d.a and ty <= d.b:
   					return E
   		return SOLID
   	if ty >= h:
   		for d in doors:
   			if d.side == "S" and tx >= d.a and tx <= d.b:
   				return E if d.open else SOLID
   		return E
   	return tiles[ty * w + tx]
   ```
   `door_at(side, idx)` keeps its meaning: `idx` is a row for W/E and a column for N/S.
3. **`Room.load_room`** copies `sets` into each grid door: `"sets": d.get("sets", "")`.
   **`update_doors()`** adds this lock kind:
   `elif lock.begins_with("flood:"): open = Game.heap_flood() <= int(lock.substr(6))`
4. **`Room._check_door()`**:
   ```gdscript
   var mid_x: float = p.x + p.w / 2.0
   var side := ""
   var idx := 0
   if mid_x < 0.0:
   	side = "W"; idx = floori((p.y + p.h / 2.0) / T)
   elif mid_x > pw:
   	side = "E"; idx = floori((p.y + p.h / 2.0) / T)
   elif p.y < 0.0 and p.vy < 0.0:
   	side = "N"; idx = floori(mid_x / T)
   elif p.y + p.h > ph and p.vy >= 0.0:
   	side = "S"; idx = floori(mid_x / T)
   ```
   Then the existing `door_at(side, idx)` / `open` / `door_crossed` code runs.
   - A pit (no S door under you) still kills by `hazard_at`, because `p.y > ph + 24` comes later than `p.y + p.h > ph`.
   - With a closed S door the floor is solid, so you cannot fall.
5. **`RoomManager`:**
   - `_on_door_crossed` also stores `trans.src_x = player.x` and `trans.src_room = from_room.id`.
   - If `d.sets != ""`: `Game.flags[d.sets] = true` and `Game.write_save()`.
   - It remembers `last_door_id = d.id`. `travel()` and `respawn()` set `last_door_id = ""`.
   - `_place_in_target()`: for W/E doors nothing changes. For N/S:
     ```gdscript
     var src: Dictionary = Game.rooms_meta.rooms[trans.src_room]
     var nx: float = trans.src_x + (float(src.origin[0]) - float(tmeta.origin[0])) * 16.0   # columns line up in the world
     nx = clampf(nx, int(t_door.a) * 16.0, (int(t_door.b) + 1) * 16.0 - player.w)
     var ny: float
     if d.side == "N":                      # going up: arrive at the bottom of the room above, pushed upward (D31)
     	ny = float(tmeta.size[1]) * 16.0 - player.h - 1.0
     	player.vy = minf(trans.vy, -Player.JUMP)
     else:                                  # falling through a floor
     	ny = 1.0
     	player.vy = maxf(trans.vy, 60.0)
     player.vx = trans.vx
     ```
     Then `face`, `dash_t`, `atk_t` and `swap_to` run as for W/E. Do not reset `vy` after this.
6. **Co-op:**
   - The guest's `room` reliable event (`Coop._on_room_changed`) sends `"door": mgr.last_door_id`.
   - The host's `room` handler: if `d.door != ""`, find that door in `Game.rooms_meta`. If it has `sets`, set the flag and `Game.write_save()`.
   - `_guest_joined`: the arena entrance is the door whose `lock == "fight"`, not the `W` door. Keep the rest.
   - Watchdog rule `door-sets` (host): a `sets` door the guest crossed (from the `room` event) whose flag is still not set 2 s later.
7. **Closed N/S doors are drawn** in `draw_layer("furniture")`. The W/E branch stays; add it under `if d.side == "W" or d.side == "E"`. For N/S, for each column `tx` in `a..b`:
   - a hatch bar `Rect2(tx*16, 0, 16, 4)` (N) or `Rect2(tx*16, ph-4, 16, 4)` (S), filled `Game.COL.ink`;
   - inside it `Rect2(tx*16+1, y+1, 14, 2)` in `#8d8798`;
   - a 1-px `#c3bccd` rivet at `(tx*16+7, y+1)`.
8. **Terminal travel (D32):**
   - `RoomManager.travel_targets() -> Array`: rested benches (`rested_benches()`) whose room has `"terminal": true`, without the current room, sorted.
   - `BenchMenu.main_options()` shows `Travel` only when the current room is a terminal and `travel_targets()` is not empty. The Travel page lists `travel_targets()`.
   - Rooms with `terminal`: R08, D04, H03 (already in the data).
9. **Tests that change because the world changed:**
   - `t_end` used R11's `D`: switch it to H11's `D`. R11 has no end door any more.
   - The DEPTHS travel check in `t_rooms3b` travelled D04 → D03. Now: D03 is not offered, and D04 → R08 works (both terminals).
   - Fix any other test that broke only because R01/R02/R03/R11/D03/D04 changed. List those tests in the report.

**Acceptance:** `--test=nsdoors` (new):
1. `TileGrid` on real rooms:
   - In `H10`: `tile(51, -1) == E` (N door open), `tile(20, -1) == SOLID`, `tile(41, 16) == E` (S door), `tile(20, 16) == E` (a pit), `tile(64, 10) == E` (E door) and `tile(64, 5) == SOLID`.
   - In `H03`: `tile(32, 15) == SOLID`. The S door covers columns 14..17; the old code opened rows 14..17 of the east wall, so this fails on the old code.
   - In `H11` without flags: `tile(51, 16) == SOLID`. After `Game.flags["hatch:H10N"] = true` and `update_doors()`: `E`.
2. Up through a hatch:
   - Set `Game.tools.sudo = true` and `swap_to("H10")`.
   - Put the player on ledge B under the hatch: `x = 51*16+3`, `y = 6*16-10`, `vx = vy = 0`.
   - Script jump at frame 0, and jump again (double jump) at frame 20, holding jump to frame 40.
   - Within 120 frames the manager's room is `H11`, `hatch:H10N` is set, and the player's x is within `50*16-10 .. 54*16`.
   - Within 90 more frames the player is `on_ground` with `y + h <= 16*16`.
3. Down through the hatch:
   - In `H11` (flag set), put the player at `x = 51*16+3`, `y = 14*16`.
   - Within 60 frames the room is `H10`.
   - On the first frame in `H10`, `player.y < 32`.
4. The floor drop:
   - In `H10`, stand on the one-way at `x = 41*16+3`, `y = 13*16-10`.
   - Script `down` + `jump` (one press).
   - Within 120 frames the room is `H04`, `hatch:H10S` is set, and `H04`'s N door is open after `update_doors()`.
5. Travel:
   - Set `bench:R08`, `bench:H03`, `bench:D03`.
   - In D03 the bench menu has no `Travel`.
   - In R08, `travel_targets() == ["H03"]`.

**Co-op scenario `co-nsdoor`:**
- Both start in `H10`. The guest owns sudo through the start save.
- The guest goes up the hatch (the same script as test 2) and comes back down the hole (test 3).
- The host sees `_remote_room().id` become `H11`, then `H10`, and `hatch:H10N` set on the host (from the guest's door id).
- No `INVARIANT` lines.

## MV4-02 · Dead code, firewall bricks, bulkheads, GET rings, `Room.blast`

1. **`TileGrid`:**
   - Add `DEAD := 12`, `FIRE := 13`, `THICK := 14`.
   - Add `";": DEAD, "N": FIRE, "0": THICK` to `CHARS`.
   - `solid()`: `FIRE` and `THICK` → `true`; `DEAD` → `false`. Creatures and projectiles also pass dead code; that is fine.
2. **`Room.load_room`:**
   - A `THICK` cell with the flag `crack:<room>:<tx>:<ty>` loads as `E`, the same rule as `CRACK`.
   - Keep a list `dead_cells` of `[tx, ty]` and `dead_groups`: the pixel centres of the 4-connected groups of DEAD cells.
   - Letter `@` → `rings.append({"x": x + 8, "y": y + 8})`.
3. **Drawing (`RoomView.build`):**
   - In the SOLID mask, a neighbour counts as wall when it is `SOLID`, `DEAD`, `FIRE` or `THICK`. Write a helper `_wallish(t)`.
   - A `DEAD` cell is drawn in the `tiles` layer exactly like a `SOLID` cell (same mask rule, same variant hash) unless the room's `dead:<room>` flag is set.
   - `FIRE` and `THICK` are not drawn by the TileMap. `Room.draw_layer("furniture")` draws them first, before the closed doors:
     - **FIRE (16×16):**
       - fill `#a8183a`;
       - mortar 1 px `#1b1226`: the horizontal line at y 7 and y 15; vertical lines at x 7 and 15 in the top half, and at x 3 and 11 in the bottom half;
       - a 1-px `#ff4f6d` highlight along the top of each brick.
     - **THICK:**
       - fill `#3a3346`;
       - 1-px border `#8d8798`;
       - 2×2 rivets `#c3bccd` at (2,2), (12,2), (2,12), (12,12).
   - **Rings `@`:**
     - a circle of radius 6, 2 px thick, `#7cc4ff`, with a 1-px ink outline;
     - tiny text `GET` in `#7cc4ff` under it at `y + 9`;
     - it bobs `floori(sin(time*2)*1.5)`.
4. **Reveal:**
   - `Room.reveal_dead(announce := true)` sets `dead:<id>` and erases every `dead_cells` cell from `view.tiles`.
   - With `announce`, it also plays `Audio.sfx("glitch")`, makes a grey burst at each group centre (`burst(..., 10, ["#8d8798","#c3bccd","#4c4658"], 80, 200)`), and pops `"dead code"` in `#c3bccd`.
   - Solo and host: in `step()`, after the local player's update, if not flagged and the player's box overlaps a DEAD cell → `reveal_dead()`.
   - Guest: the same check in `step_guest()`, then `Net.rel("reveal", {"room": id})`.
   - Host `reveal` handler: set the flag, `Game.write_save()`, and call `reveal_dead(false)` on that room if it is built.
   - The snapshot's `gf` list also carries flags starting with `dead:`. The guest calls `reveal_dead(false)` on its room when that flag newly appears.
   - Revealed DEAD cells get a dotted outline: every other pixel of the cell border, `Color(0.55, 0.53, 0.6, 0.35)`.
5. **Moths:** while a room's dead code is not revealed, the furniture layer draws 3 moths per group.
   - Moth `i` sits at `centre + (sin(time*1.7 + i*2.1)*14, cos(time*2.3 + i*1.3)*10 - 4)`.
   - Body: 1×2 px `#e8e0f0`. Wings: one pixel each side, `#c3bccd`, at y−1 or y+1 alternating at 8 Hz.
6. **`Room.blast(cx: float, cy: float, r: float) -> void`** (solo and host):
   - Every cell whose centre is within `r` and that is `THICK` or `CRACK` becomes `E`.
   - For each such cell: flag `crack:<id>:tx:ty`, `view.erase_tile`, the crack burst, `tile_broken.emit(tx, ty)`. The host sends `tile` to the guest, as for cracks today.
   - Then `shake(0.5)`, `explode(cx, cy, 20)`, `Audio.sfx("explode")`.
   - `apply_tile()` on the guest also handles `THICK` like `CRACK`.

**Acceptance:** `--test=tiles4` (new):
1. Basic tiles:
   - `H03`: `solid(31, 5) == false`.
   - `H12`: `solid(23, 8) == true`.
   - `H05`: `solid(44, 11) == true`.
2. After `room.blast(44*16+8, 11*16+8, 34)` in `H05`:
   - `solid(44, 11) == false` and `crack:H05:44:11` is set;
   - `solid(44, 6)` is still `true`.
   - Rebuilt from its file, the room still has `(44, 11)` open.
3. Reveal:
   - Manager in `H03`. Put the player at `x = 31*16 - 14`, `y = 8*16 - 10`, and script `right`.
   - Within 30 frames `dead:H03` is set. Within 120 frames the room is `H13`.
4. A new `H03` with the flag has no TileMap cell at (31, 5) (`tiles.get_cell_source_id(Vector2i(31, 5)) == -1`). One without the flag has one.

**Co-op scenario `co-deadcode`:**
- The guest walks through `H03`'s dead code into `H13`.
- The host has `dead:H03` within 3 s.
- No `INVARIANT`.

## MV4-03 · Flood levels, the valve, the rising flood

1. **Static flood (rooms with `flood`):**
   - `Room.flood_target()` returns `null` or `flood[2 - Game.heap_flood()] * 16 + 6`.
   - `load_room` sets `liquid_y = flood_target()`.
   - Solo and host `step()`: when the room has `flood` and is not rising, `liquid_y` approaches the target at **26 px/s**. A `null` target is approached as `ph + 40`, and `liquid_y` becomes `null` once it is past `ph + 30`.
   - So the water visibly drains when the level drops. Nothing else is needed for the doors: the `flood:` locks read `heap_flood()`.
2. **Hazard:** in `hazard_at`, after the tile loop:
   `if liquid_y != null and p.y + p.h > liquid_y + 5: hz = "liq"`.
   - In `Player.hazard()`, after moving back to `safe` (JS 3589): if `room.liquid_y != null and safe.y + h > room.liquid_y - 8`, call `grid.find_safe(x, y, room.liquid_y)`.
   - If that finds a spot, `set_safe` and move there.
3. **Rising (`rise`, H06 only):**
   - `var rise_on := false`.
   - Solo and host `step()`, when `def.has("rise") and Game.heap_flood() > 0`:
     ```gdscript
     var ps := players()
     if not rise_on and not ps.is_empty():
     	for q in ps:
     		if q.y < float(def.rise.trigger) * T:
     			rise_on = true; Audio.sfx("roar"); shake(0.5); break
     if rise_on and liquid_y != null and not ps.is_empty():
     	var low := -1e9
     	for q in ps: low = maxf(low, q.y + q.h)
     	var gap: float = liquid_y - low                # from the lowest player: nobody is left behind
     	liquid_y -= (float(def.rise.speed) + maxf(0.0, gap - 130.0) * 1.2) * dt
     	liquid_y = maxf(liquid_y, float(def.rise.top) * T)
     ```
   - The static approach (item 1) does not run while `rise_on`.
   - A liquid hazard of the local player in a rising room: `liquid_y += 72` (JS 3588).
   - A room rebuilt fresh (nobody in it, or a respawn) starts with `rise_on = false` at the base level, as the room manager already rebuilds empty rooms.
   - H06 data: `"flood": [37, 59, null]`, `"rise": {"trigger": 48, "speed": 19, "top": 8}`.
4. **Drips:** projectiles of kind `"drip"` die when `liquid_y != null and q.y > liquid_y + 3` (JS 3139).
5. **Drawing:** `_draw_liquid` also draws a body when `liquid_y != null`.
   - It runs from `liquid_y` to `ph + 4` across the columns the camera sees, with the same colours and per-pixel wave as the LIQ tile surface code. Factor that loop into a helper used by both.
   - It goes in the `top` layer, as today.
6. **The valve (H07, `"valve": true`):**
   - Its `Y` switch is drawn as a wheel instead of the `{}` disc:
     - disc of radius 6 in ink, then radius 5 in `#3fbfae` (or `#7fd08a` once on);
     - 4 spokes (1-px ink lines at 0°, 45°, 90° and 135°, length 4);
     - a 2×2 ink hub.
   - When `gate:H07:catch` turns on, it is set by the existing `press_switch` code. Also play `Audio.sfx("roar")`, `shake(0.8)`, and pop `"free()  heap level 1"` in `#58f0c8` at the valve.
7. **Co-op:**
   - **Snapshot:**
     - always `"fl": Game.heap_flood()`;
     - for the guest's room `"lq": NetClasses.x4(r.liquid_y)` or `-1`;
     - and `"rs": 1 if r.rise_on else 0`.
   - **Guest `_apply_snapshot`:**
     - `Game.flood_net = int(m.fl)`.
     - For its room: if `lq == -1`, `liquid_y = null`. Else, if `liquid_y == null` or the difference is over 60, snap. Otherwise `liquid_y += (lq/4 - liquid_y) * 0.5` (JS 7200).
     - `r.rise_on = rs == 1`.
     - The guest never runs the approach or the rise code itself. Before the first snapshot, its room starts at `flood_target()`.
   - **Guest liquid hazard in a room with `rise_on`:** `Net.rel("lqhit", {"room": id})`.
     - The host adds 72 to that room's `liquid_y` if it is rising.
     - At most once per 0.5 s per room, so a re-sent event cannot push twice.
   - **Watchdog rule `liquid-desync` (guest):** in a room with `liquid_y != null`, `|liquid_y - last lq/4| > 80` for 2 s.

**Acceptance:** `--test=flood` (new):
1. `heap_flood()`: `{}` → 2; `gate:H07:catch` → 1; with `boss:LEAK` → 0.
2. `H03` at level 2:
   - `liquid_y == 23*16+6`.
   - Put the player at `(20*16, 30*16)`. After one step its hp is 1 lower and `player.y + 10 < liquid_y`.
3. Level change:
   - Set `gate:H07:catch`. After 2 s, `374 < liquid_y < 726`. After 20 s, `liquid_y == 45*16+6`.
   - `H03`'s door `E2` (`grid.tile(32, 37)`) is SOLID at level 2 and E at level 1.
4. The valve: in `H07`, `press_switch(0)` sets `gate:H07:catch` and `heap_flood() == 1`.

`--test=rise` (new):
1. `H06` at level 1: `liquid_y == 59*16+6` and `rise_on == false`.
2. Move the player to `y = 40*16`, then step once: `rise_on == true`.
3. After 2 s, `liquid_y < 59*16+6 - 30`.
4. Put the player under the surface and step once: `liquid_y` grows by more than 60.
5. At level 0 (`boss:LEAK`): `liquid_y == null`, and `rise_on` stays false with the player at row 10.

**Co-op scenario `co-flood`:**
- Both are in `H03`. The host sets `gate:H07:catch`.
  - Within 2 s, the guest's `Game.heap_flood() == 1`.
  - After 12 s, the guest's `H03.liquid_y` is within 8 px of the host's.
- Both move to `H06`. The host goes to `y = 40*16`.
  - Within 2 s, the guest has `rise_on`, and its `liquid_y` is within 20 px of the host's.
- The guest steps into the liquid: the host's `liquid_y` grows by 60 or more within 2 s.

## MV4-04 · Plugins `--verbose` and `restart: always`

1. `Game.PLUGINS` += `{"id": "verbose", "name": "--verbose", "cost": 1, "price": 0}` and `{"id": "restart_always", "name": "restart: always", "cost": 1, "price": 0}`.
   - They are picked up from `U` in R12 / R15 (`plugins` lists in the data).
   - `gzip` and `sourcemap` (H16, H14) are defined in 4B; those rooms cannot be reached in 4A.
2. **`--verbose`:**
   - `Room.verbose_cells() -> Array`: the unrevealed DEAD cells within 96 px of the local player's centre, when `verbose` is in that player's loadout; otherwise `[]`.
   - The furniture layer draws a 1-px `#58f0c8` border on each of them, blinking at 2 Hz (`int(time*4) % 2 == 0`).
   - Their moths are drawn in `#58f0c8` instead of pale.
3. **`restart: always`:**
   - When the local player respawns at a bench (`RoomManager.respawn`, and the guest's `respawn` reliable event), its `meter = Game.METER_MAX` if `restart_always` is in its own loadout.

**Acceptance:** `--test=plugins4` (new):
1. With `restart_always` owned and equipped, `respawn()` gives `meter == 99`. Without it, `meter == 0`.
2. In `H03`, with the player at `(28*16, 8*16-10)`:
   - `verbose_cells()` lists (31, 4..7) with `verbose` equipped;
   - it is `[]` without it;
   - it is `[]` with it but with `dead:H03` set.

## MV4-05 · World 3 look

1. `WORLDS=3 node tools/godot/capture/capture.js tiles bg theme` adds `assets/tiles/w3_tiles.png`, `assets/bg/w3.png`, `assets/theme/w3.json` and `assets/sprites/platform_w3.png`.
2. Music:
   - Add `'w3', 'w3_hi'` to `COPY_MUSIC` in `capture.js`, then `node tools/godot/capture/capture.js music`.
   - It keeps earlier `index.json` entries. If `w3_hi` is not produced (no "hi" section), that is fine.
3. A new capture target `leak`: the builder of `leakSpr` (index.html 4377–4388; `K` is `G.COL.ink`) → `sprites/leak_0.png`, `sprites/leak_1.png`. Write it like the `boss` target's MERGE heads.
4. HEAP rooms use `"music": "w3"` (data). `Main.song_for` already plays the room's `music`; check that the world 3 song plays in H01 and that `boss` plays in the LEAK fight.

**Acceptance:** `--test=w3assets` (new):
- `ResourceLoader.exists` is true for `res://assets/tiles/w3_tiles.png`, `res://assets/bg/w3.png`, `res://assets/sprites/leak_0.png` and `res://assets/music/w3.ogg`.
- `Game.theme(3).liq == "#58f0c8"`.
- `H01` builds its view without errors.

## MV4-06 · JS ports: Slime, Lint, Dripper, Pendulum, Drone

- **Exact ports**, same order of operations and same constants as the JS classes, in `src/enemies/`:

  | file | class |
  |---|---|
  | `slime.gd` | `Slime` |
  | `lint.gd` | `Lint` |
  | `dripper.gd` | `Dripper` |
  | `pendulum.gd` | `Pendulum` |
  | `drone.gd` | `Drone` |

- `Room.spawn_enemy`:

  | letter | spawns |
  |---|---|
  | `s` | `Slime.new(self, x, y, false)` |
  | `l` | `Lint.new(self, x, y, false)` |
  | `L` | `Lint.new(self, x, y, true)` |
  | `i` | `Dripper.new(self, x, y)` |
  | `p` | `Pendulum.new(self, x, y)` |
  | `d` | `Drone.new(self, x, y)` |

- Rules for the port:
  - `G.hash` → `Game.hash3`.
  - `Math.random()` → `room.rng.randf()` (Slime, only when far from every player).
  - `this.L.player` → `to_player()` (the nearest player).
  - `this.L.time` → `room.time`.
  - `G.damp` → `Game.damp`.
  - `boxHitsSolid` → `room.grid.box_hits_solid`.
- **Slime:**
  - `die()` adds two small slimes with `room.add_entity`. Each is created at `(x, y)` and then set to `x = cx - 4 + d*4, y = y, vx = d*80, vy = -170, wait = 0.5`, for `d` in `[-1, 1]`.
  - Small slimes: 8×6, hp 1, loot 1. Big: 14×10, hp 2, loot 0.
- **Dripper:**
  - It shoots `room.shoot(x + 2, y + 5, 0, 20, {"kind": "drip", "col": Game.theme(3).liq, "g": 520.0, "r": 2.0, "cut": false})`.
  - Where `update_projs` kills a projectile that hit a tile: for kind `drip`, `burst(q.x, q.y - 2, 4, [liq, liqHi], 50, 300)`, plus `Audio.sfx("drip", {"vol": 0.6})` if within 200 px of the local player.
  - Drips always use world 3's liquid colours. They are memory leaks, even when one drips in another world.
- **Pendulum:**
  - `no_hit`, not stompable, not dashable.
  - Its harmbox is the 12×12 box at the bob.
  - Draw: the 10-segment chain (alternating `#8b91a3` / `#5c6378` 2×2 dots from the anchor to the bob), a 6×3 ink anchor plate, the `pendulum` sprite centred on the bob.
- **Drone:** shoots `{"kind": "orb", "col": "#ff5d5d", "r": 3.0}`.
- **`NetClasses`:**
  - `NAMES` += `"slime", "slime_s", "lint", "lint_v", "dripper", "pendulum", "drone"` (indices 14–20).
  - `cls_of` checks them before the `Bug` check.
  - `make()` builds them (Slime small for 15, Lint vertical for 17).
  - `net_fields`:
    - Slime `[roundi(wait*100), roundi(land*100)]`;
    - Lint `[]`;
    - Dripper `[roundi(grow*100)]`;
    - Pendulum `[]`;
    - Drone `[roundi(aim*100)]`.
- **etrace:**
  - `tools/godot/parity/enemy-trace.js` accepts `Class:v` or `Class:s` and passes `true` as the 4th constructor argument (Lint vertical / Slime small).
  - `t_etrace` parses the same and adds `Slime`, `Lint`, `Drone`.
  - Add to `enemy-cases.sh`:
    ```
    Slime 96 160 140 166 300
    Lint 96 128 200 166 240
    Lint:v 96 112 200 166 240
    Drone 96 96 200 166 300
    ```

**Acceptance:**
- the four new etrace cases pass (every frame within 0.01 px);
- `--test=parity` passes; it now visits the HEAP rooms with these creatures;
- `--test=w3enemies` (new):
  1. A big Slime given `hit(9, 1, 0, "swipe")` leaves two small slimes in `room.ents`, each with an `nid`.
  2. A vertical Lint's `x` never changes over 120 frames.
  3. A Pendulum at time where `sin(room.time*1.8 + ph) == 0` has its bob at `(x + 8, y + 54)`. Set `room.time` to make it so.
  4. A Dripper makes a `drip` projectile within 3 s.
  5. A Drone 150 px from the player fires an `orb` within 4 s.

## MV4-07 · SEGFAULT and STACK OVERFLOW

**SEGFAULT** (`x`, `src/enemies/segfault.gd`, `class_name Segfault extends EnemySM`):
- **Body:** box 12×12, hp 2, loot 2, `col = "#ff5d5d"`.
- **States:** `STATES := ["idle", "chase", "arm", "boom"]`.
  - **idle:** walks at 20 px/s and turns at walls and edges, like `Bug`.
    - It goes to chase when `to_player()` has `|dx| <= 140`, `|dy| <= 40` and `sees_player(140, 40)`.
  - **chase:** runs at 95 px/s toward the target. It stops at ledge edges (no walking off).
    - It goes to arm when `|dx| <= 26`, or when it bumped into a wall cell that is THICK (`hit_wall != 0` and the cell ahead at its middle height is `THICK`).
  - **arm:** stands; blinks white/red at 12 Hz for `0.6 * telegraph_mult` s; then boom.
  - **boom:** `room.blast(cx, cy, 34)`.
    - Area damage like NULL's blast: copy `null_boss.gd` around line 292. The local players within 30 px get `hurt(1, cx)`, and `room.harm_zone("c", cx, cy, 30.0, 0.0, 1)` is added for the guest.
    - Creatures within 30 px take `hit(2, sign, 0, "blast")`.
    - Pop `"core dumped"` in `#ff5d5d`.
    - Then `die("blast")` (it drops its loot).
- A hit during `arm` makes it explode at once. A kill in `idle` or `chase` is a normal death: no blast.
- `harmboxes()`: its body in `chase` and `arm`; none in `idle` (it is slow and harmless there) and none in `boom`.
- `net_fields`: `[STATES.find(state), roundi(state_t*100)]`.
- **Draw:**
  - a 12×12 dark-red rounded block (`#a8183a`, ink outline);
  - two white 2×2 eyes;
  - a `0x0` tiny text on it in `#ffd0d6`;
  - while arming, the whole body flashes white.

**STACK OVERFLOW** (`q`, `src/enemies/stack_overflow.gd`, `class_name StackOverflow extends EnemySM`):
- **Body:** box 12×36 (three stacked bugs), hp 3, loot 0, `col = "#f2c14e"`, not stompable.
- **States:** `STATES := ["stand", "wobble", "fall", "split"]`.
  - **stand:** sways (draw only).
    - It goes to wobble when `|dx| <= 56` and `|dy| <= 48` to the nearest player and `stun <= 0`. `face` = the side of that player.
  - **wobble:** `0.5 * telegraph_mult` s.
  - **fall:** 0.35 s. The tower rotates about its base toward `face`, from 0 to 90°.
    - Its harmbox is the rotated tower approximated by three 12×12 boxes along it.
    - At the end, a slam harm box `face>0 ? Rect2(x+6, y+24, 36, 12) : Rect2(x-30, y+24, 36, 12)` is active for 0.15 s: the host uses its harmbox; the guest checks the same box from the fields.
  - **split:** spawns three `Bug.new(room, bx, by, false)` with `room.add_entity`, at the three segment centres laid along the floor, then `dead = true` (no loot, no kill count).
- A kill in `stand` (3 hits) is a normal death: pop `"stack unwound"`, and no bugs.
- `harmboxes()`: the body in stand / wobble; as above in fall; none in split.
- `net_fields`: `[STATES.find(state), roundi(state_t*100), int(face)]`.
- **Draw:**
  - three `bug_<frame>` sprites stacked (each 12 px tall, the frame from `t`);
  - in stand, a sway of `sin(t*3)*1` px per segment, growing with height;
  - in wobble, a ±2 px shake;
  - in fall, the same rotated with `draw_set_transform` about the base centre.

**`NetClasses`** += `"segfault"` (21) and `"stackover"` (22). Both must pass `--test=parity`.

**Acceptance:** `--test=segfault` (new):
1. A blast at the bulkhead:
   - In `H05` with `gate:H07:catch` set (level 1), clear the room's creatures.
   - Put the player at `x = 43*16 - 12`, on the floor. Add a `Segfault` at `x = 30*16` on the floor.
   - Within 6 s: `crack:H05:44:12` is set, `solid(44, 12) == false`, the Segfault is dead, and the player's hp is 1 lower (`inv = 0`, no dash).
2. A normal kill: a second Segfault in `chase`, given two `hit(1, ...)`, dies with no new `crack:` flags.

`--test=stackover` (new):
1. A topple:
   - In `H06` at level 0, clear creatures. Put the player on the floor; add a `StackOverflow` 40 px to its left.
   - Within 2 s, three new `Bug`s are in `room.ents` and the tower is dead.
   - The slam hurt the player (`inv = 0`).
2. A kill: another tower, hit 3 times while it stands, dies with no Bugs added.

**Co-op scenario `co-segfault`:**
- Both are in `H05` at level 1.
- The host places a Segfault next to the bulkhead with the guest beside it.
- The guest's `grid.solid(44, 12)` turns false within 3 s. The guest takes its own blast damage through the harm zone.
- No `INVARIANT`.

## MV4-08 · THE LEAK v2 (`src/enemies/leak_boss.gd`, `class_name LeakBoss extends Boss`)

1. **An exact port of `class Leak`** (index.html 4389–4490) on top of `Boss`, as `null_boss.gd` ports NULL.
   - **Box and stats:** `super(r, bx, by, 44, 32, hp)`, `col #58f0c8`, `sub "malloc() without free()"`.
   - **Shape:** `scale`, `hurtboxes()`, `harmboxes()` (with the geyser column).
   - **`on_damage()`:**
     - levels at hp ≤ 67% / ≤ 34%: `phase = level + 1`;
     - `room.events` `bossPhase` / `bossPhase3`;
     - `shake(0.8)`, roar, `set_state("flood", 1.6)`, `vx = 0`, `vy = -200`.
   - **The tide:** targets `FLOOR+40` / `FLOOR-14` / `FLOOR-60` at 26 px/s, written to `room.liquid_y` every update.
   - **Dying:** `flood_y` approaches `FLOOR+60` at 60 px/s while dying.
   - **Attack cycles:**
     - afloat (`level > 0 and flood_y < FLOOR - 4`): lob / geyser / spawn+rain;
     - on the ground: hop×3 with waves / spawn 3 / rain 4.
   - **Movement and attacks:**
     - physics with gravity 760;
     - x clamps `18 .. pw - 18 - w`;
     - `lob(n)`, `spawn(n)` (small slimes via `room.add_entity`, at most 4 alive, `loot = 0`, `wait = 0.8`);
     - `rain(n)` (marks → drips from `y = 18`).
   - **Drawing:** the `leak_0/1` sprites (MV4-05), with its squash `sq`, the marks and the geyser.
   - JS `L.player` becomes `pick_target()`, and `next_target()` runs after each attack, as the other bosses do. `W` becomes `room.pw`.
2. **v2: the GC drone** (`src/enemies/gc_drone.gd`, `class_name GcDrone extends Enemy`):
   - While the boss is active at level ≥ 1, every 9 s it adds a GcDrone with `room.add_entity`.
     - It enters from the side farther from the boss, at `y = 40`, and flies across at 70 px/s. It is freed when off the arena.
     - It is not hostile: no harmboxes, hp 1, loot 0, `always = true`.
     - It is drawn as `drone_<f>` tinted `#7fd08a`.
   - When it dies from a player's hit (any `how`, agents too), it calls `boss.gc_popped()`:
     - `flood_y += 30`; the tide then goes back toward its target at 26 px/s;
     - pop `"gc()"` in `#7fd08a`;
     - `Audio.sfx("uiOk")`.
   - Guest hits reach it through the normal `hit` event and `_host_hit` (it is a creature with an `nid`).
3. **`trigger_side`:** in `_step_fight`'s `"none"` branch, when `def.boss.get("trigger_side", "W") == "E"`, the intro starts when `q.x + q.w/2 < trigger_x`. H09 uses `trigger_x 304`.
4. **After the fight:**
   - When `fight.state` becomes `"done"`, or the boss is freed, H09's `liquid_y` drains: it approaches `ph + 60` at 60 px/s and then becomes `null`.
   - H09 has no `flood` of its own.
   - Beating it gives `sudo`: the generic reward code with the data's `reward/banner/banner_sub` (`"press [jump] again in mid-air"`).
5. **`NetClasses`:**
   - `"leak"` (23) and `"gcdrone"` (24).
   - LeakBoss `net_fields`: `[level, ST.find(st), roundi(st_t*100), roundi(flood_y), roundi(sq*100), geyser_x, geyser_on, roundi(geyser_t*100), roundi(geyser_top), marks...]`, where `marks` is up to 6 pairs `[roundi(x), roundi(t*100)]`.
   - The guest's `harmboxes()` (body and geyser) come from these fields.
   - The guest's `liquid_y` comes from the snapshot's `lq` (MV4-03), not from the puppet.
6. **Boss data** (already in `rooms-4a.json`): `{"id": "LEAK", "class": "LeakBoss", "trigger_x": 304, "trigger_side": "E", "T": 75, "u": 0.8, "reward": "sudo", "music": "boss", "drop": 36}`. `make_boss()` gets a `"LeakBoss"` branch.

**Acceptance:** `--test=leak` (new):
1. The intro:
   - Manager in `H09` entered from `H09:E`.
   - The intro starts only after the player's centre x is below 304.
   - The boss has `Game.boss_hp(def.boss)` hp (60 on normal).
2. Level 1:
   - Hit it to 66%: `level == 1`.
   - Within 10 s, `room.liquid_y` is within 4 of `FLOOR - 14`.
   - A player standing on the floor takes a `liq` hazard.
3. The GC drone:
   - Within 12 s at level 1, a GcDrone exists.
   - Killing it raises the boss's `flood_y` by 30 (±1).
4. The kill:
   - `Game.tools.sudo`, `boss:LEAK` and `ability:sudo` are set.
   - `H09:W` opens.
   - `liquid_y == null` once the fight is `done` (allow 5 s).
   - `Game.heap_flood() == 0`.

**Co-op scenario `co-leak`:**
- Both are in the arena.
- At level 1:
  - the guest's `liquid_y` stays within 10 px of the host's;
  - a guest standing on the floor gets its own `liq` hazard;
  - a guest hit on a GcDrone pops it on the host (its `flood_y` rises).
- No `INVARIANT`.

## MV4-09 · HEAP walk-through, retrofits, the end door

The data is already in (MV4-01). This task proves that the world works end to end.

**`--test=rooms4`** (new):
1. **For every room in `rooms.json`:**
   - the file has `size[1]` rows of `size[0]` columns;
   - every door's target door exists and points back;
   - the two doors cover the same world rows (W/E) or columns (N/S).
     - The two known old exceptions are D02↔D03 and D03↔D04 (DEPTHS, phase 3). Skip exactly those two pairs.
2. **For every HEAP door (rooms whose id starts with `H`) that can open:**
   - put the player 2 px inside the edge on the door's cells, moving out:
     - W/E: `vx = ∓RUN`;
     - N: `vy = -300`;
     - S: `vy = +200`;
   - set the flags needed so the door is open: `hatch:*`, flood level via `gate:H07:catch` / `boss:LEAK`, `fire` doors excluded;
   - within 60 frames the manager is in the target room;
   - there, the player's box is not inside a solid cell and `hazard_at` is `""`.
3. **The secrets:**
   - **R01:**
     - `press_switch(0)` sets `gate:R01:catch`.
     - A player put on the spring at `(54*16+3, 7*16-10)` is in `R13` within 90 frames.
     - Without the flag it stays in `R01`.
   - **R03:**
     - `press_key(0)` sets `gate:R03:agents`.
     - The spring at `(95*16+3, 7*16-10)` takes the player to `R15` within 90 frames.
   - **R02** (sudo and bash owned):
     - From the notch (`x = 89*16+3`, `y = 9*16-10`): jump at frame 0 (held to 40), double jump at frame 20, bash up at frame 40. The player is in `R12` within 120 frames.
     - The same script without the double jump stays in `R02`.
   - **R11:**
     - Without `gate:R11:catch`: from `(22*16, 13*16-10)`, jump + bash up-right. The player never gets past `x = 25*16` in 120 frames, because the gate now reaches the ceiling.
     - With the flag: walking right reaches `H01`.
   - **H02:** a bash up from the top of the high block under the crack (`x = 131*16`, `y = 6*16-10`, jump then bash up at frame 18) breaks `crack:H02:131:0` and reaches `H12`.
4. **The end:** `H11`'s `D` door shows the end screen with `to be continued in /net`.

**Map:** check by eye in the playtest that the pause map shows the HEAP rooms. No code change is expected.

## MV4-10 · Tests, build, playtest steps, report — then stop

1. Add every new test to `test-all.sh`'s `for t in ...` list:
   `nsdoors tiles4 flood rise plugins4 w3assets w3enemies segfault stackover leak rooms4`
2. Add to `ALL=` in `coop-test.sh`:
   `co-nsdoor co-deadcode co-flood co-segfault co-leak`
3. Run `python3 -I tools/godot/roomcheck/check4a.py` → `0 problems`.
4. Run `bash tools/godot/test-all.sh` → `ALL PASS`.
   - The known timing-sensitive tests from `CLAUDE.md` may be re-run once.
   - Also run `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-flood co-leak`.
5. Export with `tools/godot/export-web.sh` as the **last** commit (`MV4-10: export public/mv`).
6. Write `docs/reports/metroidvania-phase4a.md` with:
   - what was done;
   - deviations;
   - test results;
   - **playtest steps for Zakaria in Persian**, short:
     - R11's gate → the HEAP;
     - the hub flood;
     - the valve in free.c;
     - segfault.c's bulkhead;
     - climbing stack_overflow.c while it floods;
     - THE LEAK;
     - sudo in sudoers;
     - the hatch to mmap.c and its end door;
     - the floor drop back to dangling_ptr.c;
     - the three SOURCE TREE secrets (R01 catch, R02 sudo, R03 agents);
     - the dead code next to the hub bench;
     - terminal travel R08 ↔ D04 ↔ H03;
     - co-op over the same route.
7. Update `docs/metroidvania/README.md` (phase 4A done) and this plan's status table.
8. Then **stop** and report. Phase 4B is a separate plan and session.

---

## Appendix A · Where things are

| what | where |
|---|---|
| tiles, doors, collision | `godot/src/core/tile_grid.gd` |
| room loading, letters, doors, hazards, drawing | `godot/src/world/room.gd` |
| static tile drawing | `godot/src/world/room_view.gd` |
| room swaps, transitions, travel | `godot/src/world/room_manager.gd` |
| bench menu | `godot/src/ui/bench_menu.gd` |
| flags, plugins, save | `godot/src/autoload/game.gd` |
| co-op | `godot/src/net/coop.gd`, `net_classes.gd`, `watchdog.gd` |
| tests | `godot/src/test/run_tests.gd`, `coop_scenarios.gd`, `tools/godot/test-all.sh`, `coop-test.sh`, `parity/` |
| capture tool | `tools/godot/capture/capture.js` |
| room data for this phase | `docs/metroidvania/phase4a-data/` |
| room checker | `tools/godot/roomcheck/check4a.py` (`sim.py`, `reach.py`) |

## Appendix B · The HEAP at a glance

```
               H14 heap_top (curl, 4B)        H12 alloca.h --N(ssh)-- H16 memory_pool.c (gzip, 4B)
                  | N                            | S (bash crack)
R11 --!--> H01 brk.c ---> H02 malloc.c ------> H04 dangling_ptr.c ---> H03 free_list.h  (hub, TERMINAL)
                                                   ^ N (drop from H10)    | E 4..7  ; dead code -> H13 use_after_free.c
                                                   |                      | E 18..21 -> H07 free.c (valve) --; dead code--> H06
   H11 mmap.c --D (end of 4A) / E -> N01 (4B)       |                      | E 36..39 (flood 1) -> H05 segfault.c -> H06
     ^ S hatch (from below, sets hatch:H10N)       |                      | E 53..56 (flood 0) -> H15 core_dump (fragment)
   H10 sudoers <-- H09 THE LEAK <-- H08 gc.log <-- H06 stack_overflow.c (rising flood)
     | S drop (sets hatch:H10S) -------------------'                      | W 53..56 N firewall -> D03 (ssh, 4B)
                                                                         | S (flood 0) -> D04 package.json (TERMINAL)
```
