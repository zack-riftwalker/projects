# CLAWD Metroidvania — Phase 2 Plan (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. همه‌ی تصمیم‌ها گرفته شدن و Sonnet فقط اجرا می‌کنه.
>
> **فاز ۲ چیه:** اولین تکه‌ی واقعی بازی متروید وینیا، که دو نفره هم بازی می‌شه:
> - منطقه‌ی THE SOURCE TREE با ۸ اتاق به هم وصل. سه تاش همون سه مرحله‌ی دنیای ۱ بازی فعلی‌ان، به اضافه‌ی ۵ اتاق جدید: نیمکت قبل از باس، اتاق باس، راهروی dash، در آخر، و یه اتاق مخفی.
> - باس NULL نسخه‌ی ۲ با سه حمله‌ی جدید.
> - دو دشمن جدید: FIREWALL GUARD (سپر جلوش داره) و ZOMBIE PROCESS (اگه با ضربه‌ی رو به پایین تمومش نکنی، دوباره بلند می‌شه).
> - نیمکت، ذخیره، شفا با context meter، نقشه، و حالت‌های سختی.
> - co-op با دوربین جدا: هر کی هر جا خواست می‌ره، و وقتی یکی وارد اتاق باس شد اون یکی بعد از ۳ ثانیه هشدار تله‌پورت می‌شه.
>
> **آخر فاز:** تو و رفیقت با هم بازی می‌کنید و می‌گید حس و سختیش خوبه یا نه. خود بازی زمان مبارزه با NULL و تعداد ضربه‌های هر کدومتون رو اندازه می‌گیره، تا جون باس‌ها با عدد واقعی تنظیم بشه.
>
> **شرط شروع:** فاز ۱ تموم شده باشه و تست گوشی قبول شده باشه.
>
> **چطوری بدی به Sonnet:** یه جلسه‌ی جدید با مدل Sonnet روی برنچ `ph1` باز کن و بنویس:
> «فایل `docs/PLAN-metroidvania-phase2.md` رو بخون و فاز ۲ رو اجرا کن.»

---

## 0. Rules of engagement

- **Precondition:** phase 1 is done (all MV1 tasks `done` in `docs/PLAN-metroidvania-phase1.md`) and Zakaria has said the phone test passed. If not, stop and say so.
- **Read first, in order:** `CLAUDE.md`, this file, `docs/PLAN-metroidvania-phase1.md` §0 and §3 (all its rules and the architecture still apply), `docs/metroidvania/00-decisions.md` §11, `docs/metroidvania/04-coop-design.md`, `docs/metroidvania/05-difficulty-model.md`, `docs/PROTOCOL.md`, then the phase 1 code under `godot/`.
- **Do not redesign.** Values, names, paths and code blocks in this file are decisions. If one is impossible, take the smallest change that keeps the goal and list it under "deviations" in the phase report.
- **Branch, commits, pushes, files you may touch, process and naming rules:** exactly as phase 1 §0, with task IDs `MV2-xx`. In addition you may add scenarios to `tools/scenarios-mv.js`. `server.js` is **not** changed in phase 2 (the relay already forwards any text frame).
- **Room maps are data, not design work:** use the edits and the maps in MV2-01 exactly.
- **Stop at the end of phase 2** (after MV2-09). Do not start phase 3.

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MV2-01 | 8 rooms, doors, transitions, pause map | Sonnet | todo |
| MV2-02 | benches, save file, death and respawn, persistence | Sonnet | todo |
| MV2-03 | cracked walls and bash, moving platforms, springs, memory fragments | Sonnet | todo |
| MV2-04 | combat model: context meter healing, dash without i-frames, big hits, difficulty presets | Sonnet | todo |
| MV2-05 | FIREWALL GUARD and ZOMBIE PROCESS | Sonnet | todo |
| MV2-06 | NULL v2, arena, reward (bash), fight statistics | Sonnet | todo |
| MV2-07 | co-op: protocol, host with two rooms, guest, summon, revive, reconnect | Sonnet | todo |
| MV2-08 | title screen, menus, sound and music for the slice | Sonnet | todo |
| MV2-09 | tests, delivery build, playtest instructions, phase report | Sonnet | todo |

Order: MV2-01 → MV2-09. MV2-07 needs MV2-01…06 finished; do not start it earlier.

---

## MV2-01 · Rooms, doors, transitions, pause map

**Goal:** the eight rooms of THE SOURCE TREE are connected and walkable.

### Room files
Create `godot/world/rooms/<id>.txt` for each room. Pad every row with spaces to the room width given in `rooms.json` (the loader must pad rows to `size[0]` and fail loudly if a row is longer or the row count differs from `size[1]`).

**From the current levels** (`tools/godot/capture/out/levels/<id>.txt`, made by the phase 1 capture tool) with these edits. Save the edits verbatim as `godot/world/room_edits.json` and write `tools/godot/make-rooms.py` (Python 3, run with `python3 -I`) that applies them and writes the `.txt` files. Each edit is `[x, y, expected_old_char, new_char]`; the script must stop with an error if the old char does not match.

```json
{
  "R01": { "from": "1-1", "edits": [
    [198, 12, "E", " "],
    [168, 10, "f", " "], [168, 12, " ", "Z"],
    [90, 5, "*", "o"], [168, 6, "*", "o"],
    [0, 9, " ", "%"], [0, 10, " ", "%"], [0, 11, " ", "%"], [0, 12, " ", "%"],
    [1, 9, " ", "%"], [1, 10, " ", "%"], [1, 11, " ", "%"], [1, 12, " ", "%"] ] },
  "R02": { "from": "1-2", "edits": [
    [174, 14, "E", " "], [2, 14, "P", " "],
    [87, 5, "f", " "], [80, 7, " ", "G"],
    [169, 11, "f", " "], [169, 14, " ", "Z"],
    [133, 13, "l", " "],
    [35, 11, "*", "o"], [111, 8, "*", "o"] ] },
  "R03": { "from": "1-3", "edits": [
    [181, 12, "E", " "], [3, 12, "P", " "],
    [79, 4, "l", " "], [89, 4, "l", " "], [88, 6, " ", "G"],
    [128, 9, "L", " "], [136, 9, "L", " "], [144, 9, "L", " "], [133, 12, " ", "Z"], [141, 12, " ", "G"],
    [170, 4, "*", "o"], [107, 5, "*", "o"] ] },
  "R05": { "from": "1-B", "edits": [
    [3, 10, "P", " "],
    [0, 7, "#", " "], [0, 8, "#", " "], [0, 9, "#", " "], [0, 10, "#", " "],
    [23, 7, "#", " "], [23, 8, "#", " "], [23, 9, "#", " "], [23, 10, "#", " "] ] }
}
```
What the edits do: no level exits (`E`) and only one start (`P`, in R01); Flaky and Lint (not in the slice) become ZOMBIE PROCESS (`Z`) and FIREWALL GUARD (`G`); exactly four memory fragments (`*`) stay in the slice (R01 top of the wall-jump shaft, R02 end, R03 inside the cracked box, R06 secret room); R01 gets a cracked wall at its west edge that you see from the very first screen; the NULL arena gets door openings.

**New rooms** (copy exactly; `D` is a new letter = the demo's end door):
```text
# R04.txt  (24 x 16)  bench before the boss
########################
########################
##                    ##
#                      #
#                      #
#                      #
#                      #
#       ========       #
#                      #
                        
                        
            o           
    T      C            
########################
########################
########################
```
```text
# R06.txt  (24 x 16)  secret room behind R01's cracked wall
########################
########################
##                    ##
#                      #
#                      #
#           *          #
#                      #
#         ======       #
#                      #
#                       
#   =====               
#                       
#  T     o o o          
########################
########################
########################
```
```text
# R07.txt  (48 x 16)  after NULL: a gap that needs bash, then a cracked wall
################################################
################################################
##                                   %%%      ##
#                                    %%%       #
#                                    %%%       #
#                                    %%%       #
#                                    %%%       #
#                                    %%%       #
#                                    %%%       #
                                     %%%        
                                     %%%        
     o o o                o o o      %%%        
   T                                 %%%   T    
##############        ##########################
##############        ##########################
##############^^^^^^^^##########################
```
```text
# R08.txt  (24 x 16)  end of the demo
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
   C      T         D  #
########################
########################
########################
```
Why the R07 gap is 8 tiles: a running jump covers about 98 px (reference trace in phase 1 §2); the gap is 128 px, so only jump + dash crosses it.

### `godot/world/rooms.json` (replace the phase 1 file with exactly this)
```json
{
  "start": { "room": "R01", "spawn": "P" },
  "rooms": {
    "R06": { "file": "R06.txt", "title": ".secret", "size": [24, 16], "origin": [-24, 0], "music": "w1",
             "signs": ["A hidden file! Cracked walls like that one hide things all over ~/src."],
             "doors": [ { "id": "R06:E", "side": "E", "a": 9, "b": 12, "to": "R01:W" } ] },
    "R01": { "file": "R01.txt", "title": "hello_world.py", "size": [202, 16], "origin": [0, 0], "music": "w1",
             "signs": ["MOVE with the [move] and JUMP with [jump] - hold it to go higher.",
                       "Bugs. Swipe them with [attack] - or simply land on them.",
                       "Between two walls? Jump at one, then jump again. Clawd has grippy legs.",
                       "ZOMBIE PROCESS gets back up. Finish it off with [down] + [attack] in mid-air: kill -9."],
             "doors": [ { "id": "R01:W", "side": "W", "a": 9, "b": 12, "to": "R06:E" },
                        { "id": "R01:E", "side": "E", "a": 9, "b": 12, "to": "R02:W" } ] },
    "R02": { "file": "R02.txt", "title": "branching_out.js", "size": [180, 18], "origin": [202, -2], "music": "w1",
             "signs": ["Up the shaft: jump into a wall, then jump again. And again."],
             "doors": [ { "id": "R02:W", "side": "W", "a": 11, "b": 14, "to": "R01:E" },
                        { "id": "R02:E", "side": "E", "a": 11, "b": 14, "to": "R03:W" } ] },
    "R03": { "file": "R03.txt", "title": "the_linter.rb", "size": [186, 16], "origin": [382, 0], "music": "w1",
             "signs": ["FIREWALL GUARDs block from the front. Bounce on them: hold [down] and swipe in mid-air.",
                       "A spring. Land on it."],
             "doors": [ { "id": "R03:W", "side": "W", "a": 9, "b": 12, "to": "R02:E" },
                        { "id": "R03:E", "side": "E", "a": 9, "b": 12, "to": "R04:W" } ] },
    "R04": { "file": "R04.txt", "title": "pre_boss.sh", "size": [24, 16], "origin": [568, 0], "music": "w1",
             "signs": ["NULL waits behind the next door. Rest first: stand at the bench and press [up]."],
             "doors": [ { "id": "R04:W", "side": "W", "a": 9, "b": 12, "to": "R03:E" },
                        { "id": "R04:E", "side": "E", "a": 9, "b": 12, "to": "R05:W" } ] },
    "R05": { "file": "R05.txt", "title": "NULL", "size": [24, 14], "origin": [592, 2], "music": "",
             "boss": { "id": "NULL", "trigger_x": 80 },
             "signs": [],
             "doors": [ { "id": "R05:W", "side": "W", "a": 7, "b": 10, "to": "R04:E", "lock": "fight" },
                        { "id": "R05:E", "side": "E", "a": 7, "b": 10, "to": "R07:W", "lock": "until:boss:NULL" } ] },
    "R07": { "file": "R07.txt", "title": "bash.sh", "size": [48, 16], "origin": [616, 0], "music": "w1",
             "signs": ["bash: press [dash]. Dash in any direction - it crosses gaps and breaks cracked % walls.",
                       "Cracked walls hide things all over ~/src. Go back and look."],
             "doors": [ { "id": "R07:W", "side": "W", "a": 9, "b": 12, "to": "R05:E" },
                        { "id": "R07:E", "side": "E", "a": 9, "b": 12, "to": "R08:W" } ] },
    "R08": { "file": "R08.txt", "title": "README.md", "size": [24, 16], "origin": [664, 0], "music": "w1",
             "signs": ["~/node_modules is locked for now (phase 3). Stand at the door and press [up] to finish the demo."],
             "doors": [ { "id": "R08:W", "side": "W", "a": 9, "b": 12, "to": "R07:E" } ] }
  }
}
```
Door fields: `side` W/E (rows `a..b` on the left/right edge are open) — phase 2 has no N/S doors. `lock`: absent = always open; `"fight"` = closed while a boss fight runs in this room; `"until:<flag>"` = closed until `Game.flags[<flag>]` is true.

### Rules
1. **Outside the grid:** `TileGrid.tile(tx, ty)` for `tx < 0`: E if an open W door covers row `ty`, else SOLID. Same for `tx >= w` with E doors. A closed door → SOLID. Above the top = SOLID, below the bottom = E (pit, as now).
2. **Closed door look:** draw a gate column one tile wide just inside the edge for rows `a..b` using the captured `gate` sprite tiled vertically (it is in `G.SPR.gate`), so the player sees why it is closed.
3. **Transition:** each step, if the player's centre `x + w/2 < 0` (W door) or `> room.pw` (E door) and the door at that row is open → start a transition to `to`. Placement in the target room: keep the distance between the player's feet and the door's bottom edge: `new_y = (t.b + 1) * 16 - ((d.b + 1) * 16 - y)`; for a target W door `new_x = 1`, for a target E door `new_x = t_room.pw - w - 1`; keep `vx`, `vy`, `face`, `dash_t` cleared. Transition look: 0.12 s fade to `#0d0a12`, load, snap the camera, 0.12 s fade back; input locked (`Controls.locked`) during the fade.
4. **Room reset:** entering a room builds it fresh from its file: enemies respawn (like Hollow Knight), except what the persistent flags say (MV2-02).
4b. **Music:** entering a room plays its `music` (nothing happens if that song is already playing); an empty string fades the music out over 1 s. The boss fight and the reward override it (MV2-06).
5. **Pause map:** the pause menu gets a `MAP` page. Draw every visited room as a rectangle at `origin * 0.5` px, size `size * 0.5` px, centred in the 384×216 view (the slice is 712 tiles wide → 356 px). Current room outlined in `#f0a184`, others `#8d8798`, benches as 2×2 `#7fd08a` dots, the player as a blinking 2×2 `#ffffff` dot (and the partner in co-op as `#6aa8ff`). Unvisited rooms are not drawn.

**Acceptance:** `--test=rooms`: walk (teleport to 4 px left of each E door, hold right) R01→R02→R03→R04 and check the room id and that the feet stayed on the floor (`on_ground` within 5 frames). `--test=doors`: in R05 with `boss:NULL` unset, the E edge at rows 7–10 is SOLID; set the flag → E. Screenshots of R04, R07 and the pause map; look at them.

---

## MV2-02 · Benches, save, death, persistence

1. **Benches** = every `C`. Drawn with `checkpoint_0` (never rested) / `checkpoint_1` (rested). Standing within 12 px of it and pressing `up` opens the bench menu (pixel UI in the CanvasLayer): `Rest` (heal to full, refill nothing else, save, this becomes the respawn bench, `committed ✓` pop the first time, sound `checkpoint`), `Travel` (only when ≥ 2 benches are rested: list their room titles; choosing one moves you there with the transition fade), `Leave`.
2. **Persistent flags** in `Game.flags` (Dictionary of String → bool/int):
   - `room:<id>:visited`, `bench:<id>` (rested), `item:<room>:<item id>` (tokens `o`, fragments `*`, coffee — collected for good), `crack:<room>:<tx>:<ty>` (broken cracked tiles stay broken), `boss:NULL`, `ability:bash` (also mirrored in `Game.tools.bash`).
   - Rooms read these flags when they load (skip collected items, set broken tiles to E).
3. **Save file** `user://save.json` (on the web this is IndexedDB, it survives reloads):
   ```json
   { "version": 1, "flags": {}, "tools": {"bash": false, "sudo": false, "agents": false, "opus": false},
     "bench": "", "tokens": 0, "max_hp": 5, "fragments": 0, "diff": "normal", "coop_hp_pct": 50,
     "time": 0.0, "deaths": 0, "fights": [] }
   ```
   Written on: bench rest, ability gained, boss defeated, fragment collected, demo finished. `New game` deletes it.
4. **Death** (hp 0, solo): Clawd's pixel-scatter death (port `die` + `scatter`), 1.2 s, then load the respawn bench's room and stand on the bench with full hp (or the start `P` of R01 if no bench was rested). Nothing is lost. `deaths += 1`. The room is rebuilt (enemies back, a boss fight resets).
5. **Hazards** (spikes, pits) stay as in phase 1: −1 hp and back to the last safe ground.

**Acceptance:** `--test=save`: rest at R01's bench, collect a token, save, reload the game from the file, the token is gone and the respawn bench is R01's; die → you are on that bench with full hp.

---

## MV2-03 · Cracked walls, moving platforms, springs, memory fragments

1. **Cracked walls (`%`)**: port the dash-through-cracks loop from `Player.update` (it calls `L.breakTile` for every tile the dash box touches) and `Level.breakTile` + the break queue (neighbouring cracks break 0.06 s later, so a whole wall crumbles). Broken tiles: erase from the `Dynamic` TileMapLayer, set `crack:<room>:<tx>:<ty>`. Burst colours, shake 0.3, sound `brk` as in the JS.
2. **Moving platforms (`M`, `V`, track ends `|`)**: port the platform scan in the `Level` constructor, their motion in `Level.update` (cosine ease, `platSpeed` 44), `platUnder` riding and the platform sprite (`G.platformSprite(48)` → capture it as `sprites/platform_48.png` by adding it to the capture tool).
3. **Springs (`S`)**: port `Player.spring` and the spring checks in `interactCombat` (land on it, or down-swipe it). Sprites `spring_0`/`spring_1`.
4. **Memory fragments (`*`)**: the JS "spark" item becomes a memory fragment: same sprite and pickup effect, text `memory chip ✳ <n>/4`. Every 4 fragments: `max_hp += 1`, hp to full, pop `+1 max hp`. HUD: next to the pips, a small 4-segment square that fills with fragments.

**Acceptance:** `--test=crack`: give bash, dash into R07's wall → all 33 `%` tiles of the wall (columns 37–39, rows 2–12) are E within 1.5 s and the flags are set. `--test=platform`: stand on R02's first `M` platform for 4 s → the player moves with it and never falls through. Screenshot of the HUD with 2 fragments.

---

## MV2-04 · Combat model

The numbers come from `docs/metroidvania/05-difficulty-model.md`, with the changes decided in `00-decisions.md` §11. Put every number in `game.gd` as constants or in the difficulty table, never inline.

1. **Difficulty table** (`Game.DIFF`), selected by `Game.diff` (`easy`, `normal` default, `hard`, `nightmare`):

   | key | easy | normal | hard | nightmare |
   |---|---|---|---|---|
   | `start_hp` | 7 | 5 | 5 | 3 |
   | `big_hit` | 1 | 2 | 2 | 2 |
   | `boss_hp_mult` | 0.7 | 1.0 | 1.3 | 1.6 |
   | `enemy_hp_mult` | 1.0 | 1.0 | 1.0 | 1.5 |
   | `enemy_hp_extra` | 0 | 0 | 1 | 2 |
   | `meter_per_hit` | 16 | 11 | 11 | 8 |
   | `telegraph_mult` | 1.3 | 1.0 | 1.0 | 1.0 |
   | `punish_mult` | 1.3 | 1.0 | 1.0 | 0.9 |
   | `inv_after_hit` | 1.6 | 1.3 | 1.3 | 1.0 |
   | `dash_iframes` | true | false | false | false |

   `max_hp` = `start_hp` + fragment bonuses. In co-op, boss HP is also multiplied by `1 + coop_hp_pct / 100` (`coop_hp_pct` 25–100, default 50, a slider in Settings) when both players are in the arena when the fight starts. Enemy HP: `ceil(base * enemy_hp_mult) + enemy_hp_extra` (port `G.diff.scale` in `// js/diff.js` for the rounding, then use this table instead of its presets). A stomp still kills in one hit.
2. **Context meter and healing** (replaces the 25-token heal):
   - `meter` 0–99. Every claw hit that returns `hit` or `kill` (not `block`), and every stomp, adds `meter_per_hit`. Dash hits add nothing.
   - **Focus:** hold `special` while on the ground, not attacking, not dashing, not hurt, with `meter >= 33`. After 0.25 s of holding, focus starts: the player is rooted (`vx = 0`, no jump/attack/dash), sound `charge`, a ring effect every 0.3 s. At 0.9 s of focus: `hp += 1` (max `max_hp`), `meter -= 33`, sound `heal`, burst; if still held and `meter >= 33` and hp < max, the next focus starts at once. Releasing, being hit or leaving the ground cancels with no cost. Tapping `special` (< 0.25 s) does nothing in phase 2 (`agents` is not in the slice).
   - HUD: a 99-wide bar under the pips with marks at 33 and 66 (colour `#ffe2c4`, empty `#3a3346`).
   - Tokens no longer heal; they are counted (a shop comes later). Coffee `H` heals 1 only in `easy` (and there is none in the slice).
3. **Dash without i-frames** (except `easy`): in `hurt()` drop the `dash_t > 0` early return unless `dash_iframes`; projectiles hit during a dash unless `dash_iframes`. Touching an enemy during a dash still deals the dash hit (as now); if that hit's result is not `kill`, the player also takes the contact damage (no i-frames), unless `dash_iframes`.
4. **Damage:** normal hits 1; attacks marked "big" in the boss table do `big_hit`. `inv` after a hit = `inv_after_hit`.

**Acceptance:** `--test=focus`: meter 40, hp 3, hold special 1.2 s → hp 4, meter 7; hold 0.2 s and release → nothing. `--test=dashhurt`: a Bug with hp set to 3 stands 20 px in front of the player, who dashes into it: `normal` → Bug hp 2, player hp 4; `easy` → Bug hp 2, player hp unchanged.

---

## MV2-05 · FIREWALL GUARD and ZOMBIE PROCESS

Both extend `Enemy`. New enemies share `enemy_sm.gd`: `state: String`, `state_t: float`, `set_state(s, t)`, and the states `idle chase telegraph attack recover dead` (only those each enemy needs). Their art is drawn in code with `_draw()` in the current game's style (ink outline `#1b1226`, 1-px details), because the current game has no sprites for them.

### FIREWALL GUARD (`G`)
| item | value |
|---|---|
| hitbox | 14 × 16 |
| HP | 8 (before difficulty) |
| contact damage | 1 |
| stompable | false (landing on it hurts; the down-swipe pogo is the answer) |
| loot | 3 tokens |
| patrol | like Bug: speed 18, turns at walls and ledges |
| alert | player within 112 px horizontally and 48 px vertically, in line of sight (no SOLID tile on the straight line between centres; sample every 8 px) |
| turning | when the player is behind it, it turns after 0.6 s (the shield keeps facing the old way during that time) — this is the window to hit its back |
| chase | walks at 24 toward the player |
| attack | when the player is within 28 px in front: `telegraph` 0.5 s × `telegraph_mult` (shield raised, flashes `#ffd23f`), `attack` 0.15 s (lunges 24 px forward; the harmbox grows 6 px in front), `recover` 0.6 s × `punish_mult` (stands still) |
| block | `blocks(dx, dy, how)`: true when `how` is `swipe`, `agent` or `dash`, `dy == 0`, and `dx == -face` (the hit comes from the side it faces). Blocked hits return `block` (the existing clang + push-back in `Player.on_hit`). Hits from behind, down-swipes (`dy == 1`) and up-swipes (`dy == -1`) land. |
| look | body 10×14 `#5c6378` with a `#8d8798` top edge, eyes 2 white pixels; shield 4×16 on the facing side `#ff7a2f` with two `#ffd23f` flame pixels; outline `#1b1226` |

### ZOMBIE PROCESS (`Z`)
| item | value |
|---|---|
| hitbox | 12 × 12 |
| HP | 2 |
| contact damage | 1 |
| stompable | true |
| loot | 2 tokens, only on the real death |
| walk | like Bug at 22; when the player is within 96 px and on the same floor (|dy| < 24), walks toward it at 30 |
| "death" | when hp reaches 0 from anything except a down-swipe (`how == "swipe"` and `dy == 1`) or a stomp: it does not die. It becomes a corpse: `state = "down"`, `passive = true` (no contact damage), flat 12×5 look, `zzz` pop, timer 3.0 s |
| kill -9 | a down-swipe or a stomp on the corpse (or on the living zombie for its last hp) kills it for good: pop `kill -9`, `die()` with loot. Other hits on the corpse only flash it |
| rise | at the end of the timer: `state = "rise"` 0.5 s × `telegraph_mult` (shakes 1 px, eyes blink), then hp = full, alive again |
| look | body `#8fa37a`, shadow `#56664a`, eyes `#ff5d5d`, a tiny `Z` in the tiny font on its chest; corpse = 12×5 rect of the same colours with closed eyes |

Both get net fields for co-op (MV2-07): Guard `[state, state_t*100, face, turn_t*100]`, Zombie `[state, state_t*100]`.

**Acceptance:** `--test=guard`: claw a guard from the front → `block`, hp unchanged; from behind → hp −1; pogo (down-swipe from above) → hp −1 and the player bounces. `--test=zombie`: kill with side swipes → corpse; after 3.5 s it is alive with full hp; kill again, then down-swipe the corpse → dead, `kills == 1`, 2 tokens dropped. Screenshot of both enemies.

---

## MV2-06 · NULL v2, arena, reward, fight statistics

Port `class Boss` and `class Null` from `// js/bosses.js` first (all of v1 works the same), then apply this table. Capture the NULL and cursor sprites: add to the capture tool a target `boss` that copies the `nullSpr` and `cursorSpr` builder code from `// js/bosses.js` into `page.evaluate` (it only uses `G.pix`, `G.rng`, `G.ring`, `G.text`) and saves `null_0.png`, `null_1.png`, `cursor.png`. The arena floor is y 176 (`FLOOR`), as in the JS.

**HP:** 60 × `boss_hp_mult` (× co-op factor, MV2-04). Phase 2 starts at half HP.

| attack | phase | telegraph (normal) | damage | punish after | notes |
|---|---|---|---|---|---|
| poke (cursor aims, then flies) | 1: 3 pokes; 2: 5 pokes | first aim 0.7 s, next aims 0.62 s; phase 2: 0.5 s each (v1's 0.45 is raised to 0.5) | 1 | stuck cursor 0.4 s between pokes (phase 2: 0.25 s); after the last poke NULL slumps 1.9 s | v1 behaviour; the dotted aim line is the telegraph |
| rain (marked columns, shards fall) | 1: 3 waves × 5; 2: 4 waves × 7 | 0.75 s per mark | 1 | 1.2 s idle | v1 |
| sweep (across the floor) | both | 0.9 s prep (shakes, floor dashes) | **big** | `tired` 1.5 s (phase 2: 1.0 s) | v1 speed 330 / 400 |
| dangling pointer | 2 | 1.0 s: 4 cursor-shaped marks (one on the target player's position, three random within 96 px of it, never inside SOLID) | 1, explosion radius 20 px | 0.4 s | new; sound `warn` at marking, `explode` at each blast |
| dereference | 2 | 0.7 s: the cursor flies in an arc to the target's position (visible the whole way); NULL fades out | **big**: slam box 40×16 on the floor at the landing point | stays stuck 0.8 s | new; NULL reappears at the landing point; sound `thud` + shake 0.5 |
| feint poke | 2 | one random poke after the first in a poke run: aims 0.5 s, the cursor jerks visibly, re-aims for a new 0.5 s, then flies | 1 | as poke | new; the real telegraph is always ≥ 0.5 s after the last visible change |

- Idle time between attacks: v1 values, × 0.8 in phase 2. All telegraphs × `telegraph_mult`, all punish windows × `punish_mult` (never below 0.4 s).
- Cycle: phase 1 `poke → rain → sweep` (v1). Phase 2 `poke → dangling → sweep → rain → dereference → poke(with feint)`, repeating.
- **Co-op targeting:** pokes, dangling pointer and dereference aim at the "target": the player who dealt more damage in the last 5 s; switch to the other one if the target is more than 200 px away or down. Rain and sweep threaten both. Dangling pointer with two players: 2 marks at each player.
- **Arena flow:** when a player's centre passes `trigger_x` (80 px) and `boss:NULL` is not set: start the fight — doors with `lock: "fight"` close, the camera locks to the arena, name card `NULL` / `the null pointer` for 1.5 s (big font, centred, port the current boss intro look from `// js/scenes.js` if easy, otherwise a simple card), then `start()`, music `boss`. In co-op wait for the partner's summon (MV2-07) up to 5 s before `start()`.
- **Player death in the arena:** normal death (MV2-02); the boss resets.
- **Victory:** v1 `deathRattle` (2.2 s), 24 tokens, then the reward: freeze input 3 s, banner `bash` / `dash in any direction · breaks cracked % walls`, music `toolget`, then `Game.tools.bash = true`, flags `ability:bash` and `boss:NULL`, save, all doors open.
- **Fight statistics** (for tuning HP with real numbers): from `start()` to the boss death or the last player's death record duration, claw hits that landed per player, damage taken per player, result. Show for 5 s after the fight: `NULL 72s · P1 41 hits · P2 30 hits · r 0.99/s · won` (r = hits per player per second, averaged). Append `{boss, secs, hits:[p1,p2], dmg_taken:[p1,p2], won, diff, coop}` to the save's `fights` list.

**Acceptance:** `--test=null`: with a bot that stands still and invulnerability on, the boss goes through every attack of both phases (log the attack names) within 120 s and never stays in one state longer than 6 s; with damage applied by the test (hit the boss 1 per 0.5 s) it dies, bash is granted and R05's E door opens. Screenshots of each new attack's telegraph; look at them and check the telegraph is visible.

---

## MV2-07 · Co-op

Read `docs/metroidvania/04-coop-design.md` (decisions) and `docs/PROTOCOL.md` (the current protocol) first. The design below follows them; where they differ, this file wins.

### 7.1 Connection (autoload `Net`, `src/autoload/net.gd`)
- Roles: `none`, `host`, `guest`. Transport: `WebSocketPeer`, polled every `_process` and at the start of every physics step.
- URL: on the web `ws://` + `location.host` + `/ws?...` (`wss://` when the page is `https`); natively from user args `--port=<p>` → `ws://127.0.0.1:<p>/ws?...`.
- Host: `?role=host` (the relay only allows this from the PC itself). It receives `{t:'code', v:'123456'}`; show the code on screen.
- Guest: `?role=guest&code=<6 digits>`, plus `&token=<t>` when resuming. It receives `{t:'tok', v}`; keep it.
- Relay control messages (`code`, `peer`, `host`, `tok`, `hb`) and close codes are exactly as in `docs/PROTOCOL.md` "Connection". Resume: reconnect with the token with 0.5 s … 15 s backoff; a guest that hears nothing (not even `hb`) for 6 s treats the line as dead.
- Leaving on purpose: close with code 4010.

### 7.2 Envelope and reliable events
- Every game message: `{"t": type, "e": epoch, "n": seq, "ra": last_reliable_id_received, ...fields, "r": [...] (optional), "u": 1 (optional, LAST key)}`.
- Build JSON with `JSON.stringify(msg, "", false)` (**`sort_keys = false`**, otherwise `u` is not last). `u` must be the integer `1`, so the text ends with `,"u":1}` — the relay drops only such messages when the receiver is clogged. Put `u` only on snapshots and body reports.
- Reliable events: `{"i": id, "k": kind, "d": {...}}`. **All event data lives inside `d`**, never next to `i`/`k` (the old game froze once because an event field was called `i`). Sender keeps unacknowledged events and re-sends all of them in the next message once the oldest is older than 220 ms; the receiver applies only `i == last + 1`, once, in order; `ra` acknowledges. With nothing else to send for 250 ms, send `{"t":"ack", ...}` (carries `r`).
- `e` (epoch) goes up when the host starts or loads a world. Game messages with another `e` are ignored.
- Skip sending when `WebSocketPeer.get_current_outbound_buffered_amount() > 4096` (except reliable resends; they ride the next message anyway).

### 7.3 Who owns what (unchanged from the current game)
- **Host** owns the world: rooms, enemies, boss, items, projectiles, doors, broken tiles, flags, fight statistics.
- **Guest** owns its body: movement, hp, the damage it takes, hazards. It **announces** its hits; the host checks and applies them.
- The host simulates **every room that has a player in it** (its own and the guest's). Each is a separate `Room` instance; only the host's own room is visible on the host. Rooms with no player are not kept (they are rebuilt on entry, MV2-01 rule 4). Because collision is our own tile code (no Godot physics), no `SubViewport`/`own_world_2d` is needed.
- In the guest's room on the host, the guest is a `RemotePlayer`: drawn (blue tint `#6aa8ff`) only when it is in the host's room, positioned from `st` reports with a 0.05–0.25 s interpolation delay, with a hurtbox that enemies target. Enemies target the nearest living player in their room (`to_player` must use that).

### 7.4 Messages
Positions are sent as integers ×4 (`x4 = round(x * 4)`), times ×100, hp ×10 for bosses.

**Host → guest**
| type | content |
|---|---|
| `start` (no `u`) | `{save: {tools, flags, diff, coop_hp_pct}, you: {room, x4, y4, hp, max_hp}, tm}` — when the guest joins or the world (re)starts. The guest answers with the reliable event `ready`. |
| `s` (`u:1`), 15 Hz (10 Hz if RTT > 200 ms or jitter > 40 ms) | `{sn, tm, room, en: [[id, cls, x4, y4, vx, vy, hp, face, flash, ...class fields]], it: [[id, kind, x4, y4]], pj: [[id, kind, x4, y4, vx, vy, r]], boss: null or [hp10, max10, phase, state_code], p1: [room, x4, y4, vx, vy, face, pose, hp, dead, dn], ev: [[tm, sound, x4, y4, who]]}` — a **full** snapshot of the guest's room (no deltas in phase 2). `cls` indexes `["bug", "bug_spiky", "typo", "guard", "zombie", "null"]`. Class fields come from each class's `net_fields()` and are applied with `net_apply()`. |
| reliable `heal` | `{n}` (bench rest by the host heals the guest too) |
| reliable `revive` | `{x4, y4, hp}` |
| reliable `respawn` | `{room, x4, y4}` (both were down: go to your bench) |
| reliable `summon` | `{room, warn}` |
| reliable `door` | `{room, id, closed}` |
| reliable `tile` | `{room, tx, ty}` (a cracked tile broke) |
| reliable `ability` | `{name}` |
| reliable `boss` | `{room, ev}` with `ev` = `start`, `phase`, `dead` |
| reliable `pick` | `{room, id, by}` (`by` = `p1`/`p2`; the guest adds tokens to its own wallet when `by == "p2"`) |
| reliable `pause` | `{on}` |

**Guest → host**
| type | content |
|---|---|
| `st` (`u:1`), 30 Hz (20 Hz on a bad line) | `{room, x4, y4, vx, vy, face, pose, hp, dead, dn, atk: [atk_id, dir, live], dash: [dash_id, dx100, dy100, t100], gt}` |
| reliable `ready` | `{}` |
| reliable `hit` | `{eid, how, dmg, dx, dy, atk}` (`atk` = atk_id or dash_id) |
| reliable `projhit` | `{pid}` |
| reliable `hurt` | `{d}` |
| reliable `die` | `{}` |
| reliable `room` | `{to, door}` (the guest went through a door) |
| reliable `crack` | `{room, tx, ty}` |
| reliable `pickup` | `{room, id}` |
| reliable `bench` | `{room}` (the guest rested: its respawn bench) |
| reliable `summon_ok` | `{}` |
| reliable `pause` | `{on}` |

### 7.5 Host rules
- **Hit check** (port `hostHit` + `recordHist` from `// js/coop.js`): keep for every entity a 1-second ring of `(time, hurtboxes)`. Accept a `hit` when the entity exists in the guest's room and is alive, it was not hit by this `(p2, atk)` before, some recorded hurtbox from the last `rtt/2 + 0.35 s` overlaps the guest's attack box rebuilt from its reported body (`atk_box` with the reported `dir`, at the reported position), and the guest's body centre is within 64 px of that hurtbox. Then call `e.hit(dmg, dx, dy, how, box)`. With `?debug`, log a verdict per hit (`OK`, `ALREADY`, `TOO FAR`, `NO SUCH CREATURE`, `DEAD`) like the current game.
- **Items:** a `pickup` is accepted when the item exists and the guest body is within 24 px; then the item is removed and `pick` is sent.
- **Cracks:** a `crack` is accepted when the tile is CRACK and the guest reported a dash in the last 0.3 s within 32 px; then break it (with the chain) and send a `tile` event for every broken tile. The guest hides the tile at once and shows it again if no `tile` arrives within 1 s.
- **Room changes:** on `room`, the host builds the target room if nobody is in it (fresh, from flags) and starts sending its snapshots; the old room is dropped if nobody is left in it.

### 7.6 Guest rules
- Loads its room locally from the room files and the flags (start + events). Simulates only its own body (the same `Player` code against its local `TileGrid`).
- Shows enemies, items, projectiles and the boss from snapshots at `render time = host clock − D`, `D = clamp(snapshot interval + 2·jitter, 0.08, 0.3)` (host clock offset estimated from `tm` like the current game). Blend between the two snapshots around the render time; extrapolate ≤ 0.25 s with the last speed, then hold.
- Checks its own damage against the shown harmboxes and projectiles (each class computes harmboxes from its shown state, e.g. the Guard's lunge) → local `hurt()`, then the `hurt` (and `projhit`) events.
- Its claw/dash overlapping a shown hurtbox → local spark and sound at once, then the `hit` event (once per attack per entity). Damage only happens on the host.
- Goes through doors itself, then sends `room`. Until the first snapshot of the new room arrives, it shows the room without enemies.

### 7.7 Boss summon (Zakaria's rule: when one goes in, the other is brought in)
1. The host starts a fight when either player passes the arena trigger (for the guest: its `st` position).
2. If the other player is not in the arena: the host sends `summon {room: "R05", warn: 3}`. The guest shows a banner `Partner fights NULL — joining in 3…2…1`, its body becomes invulnerable and frozen; if it is in the air it first waits for landing (max 1 s). At 0 it loads R05, stands 24 px inside the W door with 1.5 s invulnerability, and sends `room` + `summon_ok`. If the host is the one being summoned (the guest triggered), the host does the same locally.
3. The fight starts on `summon_ok` or after 5 s, whichever comes first. HP gets the co-op factor only if both are in the arena at that moment. Nobody can leave the arena while the boss lives.
4. A guest who joins the game during a fight is summoned the same way; boss HP does not change.

### 7.8 Down, revive, both down
- hp 0 → downed (body lies there, `dn += 1`). If the partner is alive: after 6 s (`REVIVE_T`) the downed player gets up with 3 hp — at its body if both are in the same room, otherwise at its last safe ground in the room where it fell.
- Both down → after 1.2 s both respawn at their own respawn bench (host: its bench; guest: the bench it last rested at, from `bench` events; none → R01 start) with full hp; rooms rebuild; a boss fight resets. The host sends `respawn`.
- `dead` and `dn` ride in every `st`/snapshot, so a lost event corrects itself.

### 7.9 Pause, leaving, reconnect
- Either player pausing pauses both (shared world): `pause {on}` both ways; the guest's simulation also stops.
- Guest line drops: the host shows `P2 lagging`; the guest's body stays (ghost, invulnerable, not targeted) up to 15 s; on resume the host re-sends unacknowledged events and a fresh snapshot; nothing restarts.
- Host leaves (4010) or its grace runs out: the guest shows `Host left` and returns to the title screen.

### 7.10 Save in co-op
The host saves the world (its normal save). The guest saves only a small profile `user://profile.json` `{tokens, settings}`. The guest never takes abilities or flags home.

### 7.11 Tests (`tools/godot/coop-test.sh <scenario|all>`)
- Starts `server.js` on port 3120 with `CODE=246810 NO_OPEN=1` (kill by PID at the end), then two native Godot processes: host `"$GODOT" --headless --path godot -- --net=host --port=3120 --scenario=<s>` and guest `... -- --net=guest --port=3120 --code=246810 --scenario=<s>`. Each prints `COOP <scenario> <role> PASS|FAIL <info>` and quits. The script passes when both pass within the scenario timeout. `SIM_*` variables are passed to the server (the bad-line runs).
- Scenarios (each side runs a small scripted bot; the scenario code lives in `src/test/coop_scenarios.gd`):

  | scenario | what must happen |
  |---|---|
  | `co-connect` | guest joins R01; within 3 s the host sees the RemotePlayer and the guest has received a snapshot with every R01 enemy |
  | `co-hit` | a Bug is placed next to the guest; the guest swipes; within 1 s the Bug is dead on the host and gone on the guest; exactly one hit applied |
  | `co-rooms` | the guest walks into R02, the host stays in R01: the host simulates 2 rooms, the guest gets R02 snapshots, the host's R01 keeps running |
  | `co-summon` | the guest is in R03, the host passes the R05 trigger: the guest sees the banner, is in R05 within 4.5 s, boss HP = 60 × 1.5 = 90 |
  | `co-revive` | the guest is killed (test hook) next to the host: back after 6 s with 3 hp; then both killed: both on their benches |
  | `co-crack` | bash granted; the guest dashes R07's wall: the host confirms every tile; both see the wall gone |
  | `co-resume` | the guest's socket is closed without 4010 mid-game: it resumes with its token within 15 s; no restart; no event applied twice |
  | `co-netfields` | every class's `net_fields()` → `net_apply()` round trip gives the same state within quantisation (run on one process) |
  | `co-badline` | `co-hit` and `co-summon` again with `SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5` |
- Plus a web two-tab check in `tools/scenarios-mv.js`, `S['mv-coop']`: build present → host tab `http://127.0.0.1:<port>/mv/?host&autotest`, guest tab `http://<container ip>:<port>/mv/?join=<CODE>&autotest` (the insecure origin, like the friend's phone); both print `CLAWD: coop PASS` within 60 s.

**Acceptance:** `bash tools/godot/coop-test.sh all` → all PASS; `node tools/coop-harness.js mv-serve mv-coop` → PASS.

---

## MV2-08 · Title screen, menus, sound and music

1. **Title screen** (pixel UI, 384×216): `CLAWD` logo in the big font ×3, subtitle `metroidvania demo · ~/src`, menu: `Continue` (when a save exists), `New game`, `Host co-op` (only when the page is on `localhost`/`127.0.0.1` or natively with `--net=host`), `Join co-op` (code entry: 6 digits; on touch an on-screen 0–9 pad with ⌫ and OK), `Settings`. Music `title`.
2. **Settings:** difficulty (easy/normal/hard/nightmare; changing it mid-game applies on the next room load), co-op boss HP slider 25–100 % step 25, music and sfx volume, `30 fps` toggle. Saved in the save file (guest: profile).
3. **URL options** (in addition to phase 1's): `host` (go straight to Host co-op), `join=<code>`, `autotest` (runs the co-op web check bot), `diff=<preset>`.
4. **Music:** copy from `tools/godot/capture/out/music/` into `godot/assets/music/`: `boss`, `toolget`, `title`, `clear` (plus their `_hi` versions if they exist). `toolget` and `clear` play once (no loop). The demo's end screen plays `clear`.
5. **End of demo** (the `D` door in R08, press `up`): a screen with time played, deaths, memory fragments x/4, tokens, and the NULL fight statistics, and the line `to be continued in ~/node_modules` (English: the pixel font has no Persian glyphs).
6. **Sounds:** every place where the JS plays an sfx in the ported code plays the same name. New ones: focus start `charge`, focus done `heal`, guard block `clang`, guard lunge `dash` (vol 0.6), zombie rises `glitch` (vol 0.5), kill -9 `kill`, summon banner `warn`, door closes `thud`, door opens `gate`.

**Acceptance:** screenshots of the title, settings, join pad (touch emulation) and end screen; look at them.

---

## MV2-09 · Tests, delivery, playtest instructions, report

1. Extend `tools/godot/test-all.sh` with every `--test=` from this phase and `coop-test.sh all`. All parity tapes from phase 1 must still pass (the movement must not have changed; the dash i-frame change only affects `hurt`).
2. `git fetch origin main && git merge --no-edit origin/main`; `bash tools/godot/test-all.sh`; `node tools/coop-harness.js smoke cache paths mv-serve mv-coop fight-hits revive soak` (`SOAK_S=20`). All PASS.
3. Commit the new `public/mv/` build (the only `public/mv/` commit of phase 2).
4. `docs/reports/metroidvania-phase2.md` (Persian): what was built, tests, deviations, build size, known problems, and the playtest steps below.
5. **Playtest steps for Zakaria** (put them in the final message, Persian, verbatim):
   1. `update.bat` رو بزن (فایل `update-branch.txt` با متن `ph1` باید هنوز تو پوشه باشه).
   2. رو PC: `http://localhost:3000/mv/` → `Host co-op`. یه کد ۶ رقمی نشون می‌ده.
   3. رفیقت رو گوشی: همون آدرسی که همیشه برای بازی می‌زنه، با `/mv/` آخرش (مثلاً `http://<IP تو>:3000/mv/`) → `Join co-op` → کد.
   4. با هم تا آخر دمو بازی کنید (در آخر اتاق `README.md`). حداقل ۳ بار با NULL بجنگید، حتی اگه بار اول بردید (با `New game` یا مردن).
   5. بعد از هر مبارزه یه عدد ۵ ثانیه رو صفحه میاد (`NULL 72s · P1 41 hits ...`). ازش اسکرین‌شات بگیر.
   6. این سؤال‌ها رو جواب بدید، از ۱ تا ۵: حس حرکت مثل بازی قبلیه؟ NULL سخت بود یا آسون؟ دشمن‌های جدید منصفانه بودن؟ تله‌پورت به اتاق باس ناگهانی بود؟ لگ داشت؟
   7. اسکرین‌شات‌ها و جواب‌ها رو بفرست.
6. Stop. The gate: Zakaria and his friend approve feel and difficulty. The fight statistics decide the final boss HP numbers (phase 3 updates `05-difficulty-model.md` with the measured `r`).

---

## Appendix · Code to read in `public/index.html`

`// js/bosses.js` (`class Boss`, `class Null`, `FLOOR = 176`), `// js/level.js` (`breakTile`, break queue, platforms, `interactCombat`, `interactGoals`, items), `// js/player.js` (`spring`, dash crack loop), `// js/coop.js` (`hostHit`, `recordHist`, interpolation, reliable channel, summon-free revive logic), `// js/diff.js` (`scale`), `// js/scenes.js` (HUD, boss intro card, title screen look).
