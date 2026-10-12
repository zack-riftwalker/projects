# CLAWD Metroidvania — Phase 4B-3 Plan: THE NETWORK made hard (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. طراحیش (فارسی) اینجاست: [`metroidvania/11-network-v2.md`](metroidvania/11-network-v2.md).
>
> **چی عوض می‌شه:** NETWORK همون ۲۲ اتاق می‌مونه (درها، اندازه‌ها، نقشه‌ی دنیا بی‌تغییر)، ولی:
> - **۸ دشمن بومی:** چهار تازه (SNIFFER که کابل curl رو می‌بُره، MITM که حمله‌ات رو آینه‌ای تکرار می‌کنه، BOTNET که گله‌ی DDOS می‌سازه، PINGER با توپ کمونه‌ای) و چهار قوی‌تر (SCRAPER، WORM، DDOS، SPYWARE). Drone و Lint از NETWORK می‌رن.
> - **۱۵ اتاق دوباره کشیده شدن** و هر کدوم یه کار دارن: پیچ‌وخم تار و خار، دودکش‌های تاردار، بسته‌ای که وسط راه غیب می‌شه، فرار از خط RST تو 22/tcp و غیره. همه با شبیه‌ساز چک شدن: مسیر اصلی هنوز فقط با bash و catch رد می‌شه.
> - **سه باس از نو:** WEB CRAWLER (تارهایی که آرنا رو پر می‌کنن، دویدن روی زمین، تاب خوردن تو فاز ۳)، THE FIREWALL (دیوارهای deny که آرنا رو کوچیک می‌کنن، «DROP ALL» تو فاز ۳)، THE REVIEWER #2 (کامنت‌هایی که کف رو پر می‌کنن). ضربه‌ی بزرگ ۲ آسیب، استراحت کوتاه‌تر، از فاز ۲ دو خطر با هم.
> - انصاف co-op سر جاشه: هر حمله قبل از ضربه برای دوستت هم دیده می‌شه.
>
> **برای دادن به Sonnet:** «فایل `docs/PLAN-metroidvania-phase4b3.md` رو بخون و اجراش کن.»

---

## 0. Rules of engagement

- **Read first, in order:**
  1. `CLAUDE.md`.
  2. This file, all of it.
  3. `docs/metroidvania/11-network-v2.md` (the design, Persian; this plan is its English spec).
  4. `docs/reports/metroidvania-phase4b2.md` (what was built: the three bosses, the four enemies, curl, ssh) and `docs/PLAN-metroidvania-phase4b2.md` §3 (letters, fields, constants).
  5. `docs/metroidvania/05-difficulty-model.md` §1 rows 2, 5 and 6 (damage, telegraph, punish numbers).
  6. `godot/src/enemies/leak_boss.gd`: THE LEAK is the model of a good boss here (an arena that changes per phase, an environmental counter).
  7. Then the code you change.
  - Phase 4B-2's plan §0 still applies where this file does not say otherwise.
- **Do only phase 4B-3.** Stop after MVB3-10 and report.
- **Do not redesign.** Numbers, letters, room files and JSON here and in `docs/metroidvania/phase4b3-data/` are decisions. If one is impossible, take the smallest change that keeps the goal and list it under deviations. **Never edit a room file by hand**: change `phase4b3-data/rooms.py`, run it, re-run `apply.py` and `check4b3.py` (`0 problems`).
- **Difficulty is the point of this phase.** When a number here makes something trivially easy in play (you will see it in your bots and scenarios), say so in the report; do not quietly make anything easier.
- **Branch:** `ph1` only. `git fetch origin ph1 && git checkout ph1 && git merge --no-edit origin/ph1`. Do not merge `main` (no common history). Never push to `main`, never open a PR.
- **Files you may touch:** everything under `godot/` and `tools/godot/`; `docs/metroidvania/`; `docs/reports/metroidvania-phase4b3.md`; this plan's status table. Not `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`. `public/mv/` only through `export-web.sh`, as the last commit.
- **Commits:** one per task (`MVB3-xx: <what>`), with your session's attribution lines. Push after each.
- **Co-op rules** (CLAUDE.md; not optional): state over events; what the guest's combat reads goes through `net_fields()`/`net_apply()` and `parity`; contact harm is `harmboxes()` from those fields; a kit boss hurts only through its plan **or an arena hazard (MVB3-02)**; a new co-op bug class gets a watchdog rule; reliable event data only in `d`; never a field named `i` or `k`.
- **Godot naming trap:** never name members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Tests:** every task names its tests; before the final commit `bash tools/godot/test-all.sh` → `ALL PASS`; new `--test=`s in its list, new scenarios in `ALL=`.
- **"Skip boss" stays** and works for the three reworked bosses.

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MVB3-01 | room data in (15 rooms redrawn, N21 waves, N12 packet loss, N17 chase); letters `j u r y`; checker | Sonnet | todo |
| MVB3-02 | engine: kit `rec`, arena hazards + watchdog `arena-tell`, bouncing shots, body effects (slow, jam), tags | Sonnet | todo |
| MVB3-03 | new enemies: SNIFFER, MITM, BOTNET, PINGER | Sonnet | todo |
| MVB3-04 | reworked enemies: SCRAPER, WORM, DDOS, SPYWARE | Sonnet | todo |
| MVB3-05 | room mechanics: packet loss, the RST chase, typed waves | Sonnet | todo |
| MVB3-06 | WEB CRAWLER v2 | Sonnet | todo |
| MVB3-07 | THE FIREWALL v2 | Sonnet | todo |
| MVB3-08 | THE REVIEWER #2 v2 | Sonnet | todo |
| MVB3-09 | co-op scenarios, bad line, difficulty presets check | Sonnet | todo |
| MVB3-10 | tests, build, playtest steps, report → **stop** | Sonnet | todo |

---

## 2. Facts (verified by Claude on `ph1` at `769c3c1`, 4B-2 done)

1. The NETWORK rooms, curl, ssh, the kit bosses (`crawler_boss.gd` 351 lines, `firewall_boss.gd` 434, `reviewer2.gd` 407) and the four enemies (`scraper.gd`, `worm.gd`, `ddos.gd`, `spyware.gd`, NetClasses 26–29; bosses 30–32) are built as `PLAN-metroidvania-phase4b2.md` says, with the deviations in its report.
2. Enemy counts per room today: N01 1 drone; N02 1 guard; N04 1 guard; N05 4 scrapers + 1 drone; N08 7 scrapers; N12 2 DDOS; N13 1 guard, 2 worms, 1 spyware; N17 2 drones, 1 spyware, 1 DDOS; N18 1 drone, 1 DDOS; all other rooms none.
3. `Player.hurt(d, src_x)` takes any damage `d` (2 works). `rate_limit` and `inv` checks run first.
4. `Room.shoot(...)` projectiles die on the first solid cell (`update_projs`, host side); the guest sees them from snapshots.
5. The kit's `plan_start(id, fam, tgt, fp, lock, cue)` takes a custom cue; active and recover come from `FAMILY`.
6. Free letters after 4B-2: uppercase `A F O Q`, lowercase `j r u y`.
7. Simulator facts for this phase's rooms (Claude, `phase4b3-data/sim.py`): a 3-wide spike pit with a web strand 5 rows above the floor is cleared by a running jump held 9–21 frames (a 13-frame window); a 4-wide pit under the same web only by 18–21 frames (4 frames) or with a dash. A full-height jump touches the web.

---

## 3. Shared definitions

### 3.1 The data (`docs/metroidvania/phase4b3-data/`)

| file | what |
|---|---|
| `rooms/N*.txt` | the 15 redrawn rooms: N01 N02 N04 N05 N06 N07 N08 N10 N11 N12 N13 N16 N17 N18 (+ N21 unchanged file, new waves) |
| `rooms-4b3.json` | their `rooms.json` entries (only `wave`, `packets.lossy` and `chase` are new; every door and size is unchanged) |
| `apply.py` | copies the files and replaces the entries (idempotent; takes a repo root argument) |
| `sim.py`, `reach.py`, `check4b3.py`, `rooms.py`, `canvas.py` | the simulator (`j` counts as a ring), the checker, the generator |

### 3.2 New letters

| letter | what | task |
|---|---|---|
| `j` | a GET ring with a SNIFFER on it (the cell is a ring; host/solo spawn the sniffer there) | MVB3-03 |
| `u` | MITM | MVB3-03 |
| `r` | BOTNET (its bottom stands on the floor under the cell) | MVB3-03 |
| `y` | PINGER (attaches to the nearest solid side: left, right or up) | MVB3-03 |

`d` (Drone) and `l`/`L` (Lint) no longer appear in N rooms. `G` (FIREWALL GUARD) stays.

### 3.3 New `rooms.json` fields

| field | room | meaning |
|---|---|---|
| `"packets": {..., "lossy": {"every": 3, "x": [27, 45], "warn": 0.5, "off": 0.6}}` | N12 | MVB3-05 |
| `"chase": {"flag": "rst:N17", "trigger_row": 16, "speed": 46, "end_row": 76}` | N17 | MVB3-05 |
| `wave.waves` entries `[x, y]` (a DDOS swarm) or `["u"|"r"|"y", x, y]` | N21 | MVB3-05 |

### 3.4 Flags

`rst:N17` (world flag; add `rst:` to `WORLD_PREFIXES`). Nothing else new.

### 3.5 Damage and timing rules (normal; `telegraph_mult` and `punish_mult` scale them per difficulty as today)

- Ordinary hit 1. A big boss hit is 2 and always has a cue ≥ 0.70 s.
- Every other boss cue ≥ 0.45 s (above the kit's `SEEN_MIN` 0.35, so a lagging guest still sees it).
- Recovers 0.5–0.8 s unless stated.
- Enemy tells ≥ 0.35 s.

---

## MVB3-01 · Room data, letters, checker

1. `python3 -I docs/metroidvania/phase4b3-data/apply.py`: copies the 15 room files and replaces those rooms' `rooms.json` entries (keeping the same doors, sizes and every 4B-1/4B-2 field).
2. Copy `sim.py`, `reach.py` and `check4b3.py` to `tools/godot/roomcheck/` (the new `sim.py` only adds `j` to the rings; `check4a.py` and `check4b2.py` still pass). Add `run check4b3 python3 -I tools/godot/roomcheck/check4b3.py` to `test-all.sh` next to `worldcheck` (it must end `0 problems`; it takes a few minutes).
3. Until MVB3-03, `j` loads as a ring, and `u`, `r`, `y` print the "not ported yet" warning.
4. `world.py` → `errors 0` (nothing about doors changed).
5. Tests: `rooms4b` and `parity` keep passing.

## MVB3-02 · Engine: kit `rec`, arena hazards, bouncing shots, body effects, tags

1. **Kit `rec`:** `plan_start(id, fam, tgt, fp, lock := 0.0, cue := -1.0, rec := -1.0)`; `rec >= 0` replaces the family's recover (still × `punish_mult`, never below 0.4). Bosses chain attacks with it.
2. **Arena hazards** (a boss's environment, beside its one attack plan): a list on the boss, each `{kind, t0, warn, ...}` built from data that travels in `net_fields`. Rules:
   - A hazard is drawn from the moment it exists; it hurts only after `warn` (≥ 0.6 s) has passed on the host's room clock.
   - Its harm boxes are a pure function of its fields and `room.time` (the guest computes them; snapshots carry `rt`).
   - Damage from a hazard is like contact damage (each page checks its own body).
   - **Watchdog `arena-tell`** (guest): a hazard that hurts the guest must have been visible on the guest for ≥ 0.5 s; otherwise `INVARIANT arena-tell: <boss> <kind> after <x> s`.
3. **Bouncing shots:** a projectile option `"bounce": n`. On a solid cell it reflects instead of dying (reflect `vx` if the cell beside it in x is solid, `vy` if the cell above or below is), `n -= 1`, `Audio.sfx("tick")`; with `n == 0` it dies as today.
4. **Body effects** (each page, its own body only; the guest computes from the puppets it sees):
   - `slow_t` (seconds): `RUN` and air acceleration × 0.5 while `> 0` (SCRAPER's thread).
   - `jam`: true while ≥ 3 DDOS bits (any swarm) are within 28 px of the body's centre: `RUN` × 0.6, no dash start. Draw: a red `JAM` over Clawd and a static noise ring.
   - Both off for anything else; parity tapes never meet them.
5. **Tags:** `room.tags := {"p1": t, "p2": t}` (seconds left, host). While a player is tagged, every enemy's `to_player()` returns that player when it is in the room and alive. Snapshots carry `tg` (the tagged keys); both pages draw a red crosshair over the tagged body.
6. **Tests:** unit `kit4b3` (new): `rec` overrides and the 0.4 floor; an arena hazard's harm boxes are empty before `warn` and equal on a host and a guest room built from the same fields at the same `time`; a bouncing shot in a closed box bounces exactly `n` times; `jam` turns on with 3 bits at 20 px and off at 2; `slow_t` halves `RUN`; a tag makes a Bug next to both players pick the tagged one.

## MVB3-03 · New enemies (NetClasses 33–36)

**SNIFFER** (`j`, `src/enemies/sniffer.gd`, `extends EnemySM`, `"sniffer"` 33): it taps a GET ring.
- Body 10×10 over its ring's centre (bobs ±2 px), hp 2, loot 2, flies, contact harm 1.
- `STATES := ["tap", "probe", "hop"]`.
  - tap: the ring is **tapped** (drawn with a red ring and a tiny `tap`). A player whose zip goes to a tapped ring has its zip cut 0.25 s after it started: the zip ends (`vx = vy = 0`), Clawd falls, a pop `RST` (each page, its own body: the guest reads "tapped" from the puppet's fields).
  - probe: every 2.5 s while a player is within 120 px with a clear line: a 0.4 × `telegraph_mult` s glow, then one slow yellow catchable shot (90 px/s, `kind: "diamond"`, `dmg 1`). A caught probe back into it deals 2 (it dies).
  - hop: every 4 s, if no player is within 64 px, it flies (0.4 s) to the nearest free ring within 80 px (not tapped, not the one a player is zipping to). The ring it left is clean.
- When it dies the ring is a normal ring again.
- `net_fields`: `[STATES.find(state), roundi(state_t*100), ring index (in anchors), from ring index]`.

**MITM** (`u`, `src/enemies/mitm.gd`, `extends EnemySM`, `"mitm"` 34): man in the middle; it echoes your last attack.
- Body 12×16, hp 5, loot 3, walks at 50 px/s toward the nearest player within 160 px and stops 40 px from it, facing it. Contact 1.
- `STATES := ["listen", "record", "echo", "open"]`.
  - listen: while facing a player, its front blocks claws, dashes and agents (like `Guard.blocks`; clang). → record when that player attacks (host: its own player's swipe/dash start; the guest's from the `st` attack state already reported for drawing).
  - record: 0.5 × `telegraph_mult` s; over its head the icon of what it copies (side swipe, up swipe, pogo, dash) and a filling bar.
  - echo (mirrored, toward the player): side → a slash box 28×22 in front (0.15 s); up → a slash box 26×24 above it (0.15 s); pogo → it hops (`vy = −260`) and lands with a 24×8 stomp box under it; dash → it dashes 64 px at 320 px/s with its body as the harm box.
  - open: 0.6 × `punish_mult` s, no guard, it staggers. Hits land from any side. Then listen.
- Hits from behind always land.
- `net_fields`: `[STATES.find(state), roundi(state_t*100), echo kind index, int(face)]`.

**BOTNET** (`r`, `src/enemies/botnet.gd`, `extends Enemy`, `"botnet"` 35): a server rack that raises DDOS swarms.
- Body 24×32 standing on the floor under its cell, hp 10, loot 6, no contact harm, not stompable, does not move.
- It owns one DDOS swarm at a time. When none of its bits is alive: a 4.0 s countdown (four LEDs go out one by one), then a new swarm of 5 bits at its top. Its bits move 20 % faster.
- **Shield:** while any of its bits is alive, hits on it are blocked (clang, a blue shield shimmer). In the countdown it takes hits.
- Its death kills its bits.
- `net_fields`: `[roundi(countdown*100), int(shielded)]`.

**PINGER** (`y`, `src/enemies/pinger.gd`, `extends EnemySM`, `"pinger"` 36): an ICMP turret.
- 12×12, attached to the nearest solid side (left, right or up), hp 3, loot 2, no contact harm.
- Every 3.0 s while a player is within 200 px with a clear line: a 0.6 × `telegraph_mult` s tell (its dish glows, a tiny `ping`), then a ball (r 4, 130 px/s) aimed at that player, `"bounce": 4`, `dmg 1`. Every third ball is yellow and catchable; a caught ball back into the pinger deals 3 (it dies).
- `net_fields`: `[STATES.find(state), roundi(state_t*100), shot count]`.

**Tests:** unit `w6enemies2` (new): a zip to a tapped ring is cut after 0.25 s and Clawd falls; a dead sniffer leaves a normal ring; a caught probe kills the sniffer; the sniffer hops off a ring with no player near within 4.5 s. MITM: a side swipe from the front is blocked and echoed 0.5 s later as a slash toward the player; a swipe in `open` lands; a swipe from behind lands in `listen`. BOTNET: shielded while a bit lives, hittable in the countdown, a new swarm 4 s after the last bit dies, its death kills its bits. PINGER: a ball bounces 4 times then dies; the third ball is catchable and kills the pinger when caught. Parity for all four.

## MVB3-04 · Reworked enemies

- **SCRAPER:** hp 3. In `wait` (at the bottom of its drop) it shoots one grey sticky thread at the player it dropped for (160 px/s, not catchable, `dmg 1`); a hit also sets that body's `slow_t = 0.8`. Draw the thread as a 1-px line from it to the shot.
- **WORM:** hp 3. In crawl it moves one cell per 0.4 s toward the cell of its group nearest to the closest player (instead of ping-pong). A bite (`out`) that ends without the worm being hit lays an egg in a free cell of its group (a pulsing brick); 5 s later the egg is a new worm. At most 3 worms per group.
- **DDOS:** bits no longer all fly at once. The swarm orbits the target at radius 30; every 0.6 s one bit (round robin) darts straight at the target's centre (a 0.25 s tell: it flashes white) at 220 px/s, then rejoins. Contact still kills the bit. The `jam` rule (MVB3-02) applies.
- **SPYWARE:** hp 4. If the track phase ends with the same player in line of sight the whole time, that player is **tagged** for 4 s (MVB3-02) whether or not the beam then hits. Breaking the line during track resets the track (no tag, no shot). Its beam is now 8 px thick.
- **Tests:** extend `w6enemies`: a scraper's thread slows the hit body for 0.8 s; a worm that bites unhurt lays an egg that hatches in 5 s (max 3); one bit at a time darts; a player kept in view for the whole track is tagged, one who steps behind a wall during track is not.

## MVB3-05 · Room mechanics

1. **Packet loss (N12, `packets.lossy`):** packet `j` with `j % every == every − 1` is lossy. When its centre is within `warn` seconds of reaching a listed column's centre (`x × 16 + 8`), it flickers (red/clear at 10 Hz, and a `LOSS` text over it); from that column for `off` seconds it has no collision and is drawn as an outline. A rider who jumps keeps the packet's speed (`player.gd` already adds `ride.dx`) and lands on it again. Pure function of the room clock: both pages compute it; ports use only existing (not lost) packets. Under the two loss columns the floor has 4-wide spike strips (the room file).
2. **RST chase (N17, `chase`):** host/solo:
   - When `rst:N17` is not set and a player's `y > trigger_row × 16`, the chase starts: `ch_t0 = room.time`. The line's y = `−32 + speed × (room.time − ch_t0)`; snapshots carry `ch` (`ch_t0` or −1), so the guest draws and checks the same line.
   - A body whose top is above the line takes 1 damage and is put on the nearest safe floor below the line (search down from the line, the same column first). Each page, its own body.
   - When every player in the room is below `end_row × 16`, set `rst:N17` (write_save); the line fades. It never runs again.
   - Draw: a full-width red band with `RST` text and a falling static, 6 px tall, plus a 0.6 s `connection reset` banner at the start.
3. **Typed waves (N21):** a wave entry `[x, y]` is a DDOS swarm (as before); `["u", x, y]` a MITM, `["r", x, y]` a BOTNET, `["y", x, y]` a PINGER at that cell. A wave is cleared when every creature it spawned (and their bits) is dead.
4. **Tests:** unit `net4b3` (new): in N12 the third packet loses collision for 0.6 s at column 27 and a rider placed on it falls unless it jumps 0.3 s before; the loss is identical on two rooms given the same `time`; in N17 the line starts when a player passes row 16, a player standing above it is moved below it with 1 damage, and `rst:N17` is set when the player reaches row 77 (then a rebuilt room has no line); N21's third wave spawns a botnet and a pinger.

## MVB3-06 · WEB CRAWLER v2

Rework `crawler_boss.gd` (same class, NetClasses 30). Arena N09, `FLOOR = 176`, nodes as today. **HP: `T 110, u 0.75` → 82.**

**The web (arena hazard):**
- **Knots** (anchor points): ceiling `(96, 0)`, `(192, 0)`, `(288, 0)`; walls `(0, 64)`, `(0, 128)`, `(384, 64)`, `(384, 128)`; floor `(48, 176)`, `(144, 176)`, `(240, 176)`, `(336, 176)`.
- A **strand** joins the crawler's current node to a knot. Harm: 8×8 boxes every 8 px along the segment (1 damage). At most 4 strands; a fifth cuts the oldest.
- **Cutting:** a claw hit on a knot's 12×12 box (floor knots are easy; wall knots need a jump; ceiling knots an up-swipe from a high spot), or a caught packet flying back within 8 px of the strand. Cut strands snap and fade (0.3 s, harmless).
- The crawler may walk along any strand between a node and a knot (its `move` uses them).

**Attacks** (cue/recover; × the difficulty multipliers):

| id | what | cue | harm | then |
|---|---|---|---|---|
| `fetch` | a leg slams at the target's x; P1 one slam, P2 two, P3 three; each re-locked at the target 0.45 s before its impact | first 0.75 (2 dmg), the others 0.45 (1 dmg), each its own plan with `rec 0.1`, the last `rec 0.8` | the leg column | the last leg stays planted (pogo it) and the core comes down to `FLOOR−70` during the last recover |
| `spin` | a strand from its node to the knot nearest the target on the far side of the target from the boss | 0.9 (dotted line) | the strand from the end of the cue | — |
| `volley` | P1 3, P2 4, P3 5 yellow packets in a fan at the target | 0.6 | shots | a catch back hits the core for 2 and cuts the strands it crosses |
| `skitter` (P2+) | it drops from its node to the floor (its shadow is the tell), runs to the far wall at 300 px/s, climbs it and goes back up to the nearest node | 0.7 | landing 2 dmg under it (32×24); the running body 32×18, 1 dmg (jump it: its top is `FLOOR−18`) | on the wall, 0.6 s still: its body is the hurtbox; on the floor too (pogo off it) |
| `back` (P3) | as in 4B-2, legs 2 dmg | 0.8 | two leg columns | recover 0.8, core down |

- **Movement** is never an attack of its own: at the end of each recover it walks (≤ 0.6 s, harmless) to the node chosen by rule 8 (the node above whoever stood under it longest in the last 1 s), along a strand if one leads there.
- **Phases:** P1 (100–65 %): `fetch, spin, volley, fetch`. P2 (65–30 %): `fetch, skitter, spin, volley`; two SCRAPERs drop from the ceiling knots at the start (hp 3, no hook: they hang from a thread at the knot). P3 (30–0 %): **deep crawl** (below), two more SCRAPERs at its start.
- **Deep crawl (P3):** all strands are cut, the nodes go dark. It hangs from `(192, 0)` on a 120 px thread and swings as a pendulum: angle = `0.9 × sin(2π × (room.time − sw_t0) / 3.2)` (pure function; `sw_t0` in the fields). Core contact harm 1. At the swing's ends (|sin| > 0.95) it may `fetch` (three legs) at the target; every 2.4 s a `volley` of 5; every second swing a `spin` from its swing point. The core passes 56 px over the floor at the middle of the swing: a jump + up-swipe there hits it.
- `net_fields` = `plan_fields()` + `[node, prev_node, core_y, leg_x, leg_on, skitter_x, skitter_state, sw_t0×100, strands (up to 4 × [knot index, node index, t0×100])]`. The guest builds the strand harm from them (arena hazard rules).
- **Tests:** unit `crawler2` (replaces `crawler`'s attack checks, keep its intro/reward checks): HP 82; `fetch` in P2 makes two plans, the first with cue 0.75 and 2 damage; a fifth strand cuts the oldest; a swipe on a floor knot cuts its strand; a caught packet cuts the strand it crosses; `skitter`'s running body hurts a standing player and not one at the top of a jump; deep crawl's pendulum is the same on two rooms at the same `time`; a jump + up-swipe at the swing's middle hits the core.

## MVB3-07 · THE FIREWALL v2

Rework `firewall_boss.gd` (NetClasses 31). Arena N15 (membranes at columns 7 and 16 stay). **HP: `T 110, u 0.75` → 82.**

**Arena hazards:**
- **Deny walls (P2+):** at the start of P2 two walls advance from x = 0 and x = 384 to x = 96 and x = 288 over 6 s (a 1 s red warning stripe first) and stay. Harm (1) on contact plus a push inward (`vx = ±180`); drawn as brick walls 16 px thick, full height. Not solid. The boss passes through them (the ssh preview).
- **DROP ALL (P3):** every 3.0 s the floor band (`FLOOR−6` to `FLOOR`) between the deny walls burns for 0.4 s, except a 64 px **port** whose x is shown 0.9 s before (a green frame with its number: 22, 80, 443 or 8080). The port x is the next of a fixed sequence derived from the boss's seed (in the fields).

**Attacks:**

| id | what | cue | harm |
|---|---|---|---|
| `throw` | the shield flies out along the low band (`FLOOR−18..−4`) to the far wall (or deny wall), **bounces**, and comes back along the high band (`FLOOR−40..−26`): jump the first pass, stay low for the second | 0.75 (2 dmg) | the shield box |
| `return` | (chained, `cue 0.25`) the way back | 0.25 | the shield box |
| `rule` | a brick block 16×32 slides along the floor from its side at 200 px/s to the far side; P2+ two of them 0.5 s apart | 0.7 | the block (1); jump it |
| `scan` | the three lanes burn **in order** (L→M→R or R→L, away from the boss), 0.35 s apart, 0.4 s each; P1 0.6 s apart | 0.6 | each lane while it burns |
| `deny` | P1 one, P2+ two slow yellow orbs | 0.6 | shots; a catch back drops the shield for 2.0 s and deals 2 |
| `phase` (P2+) | it walks into a membrane or a deny wall and out the other side with a slash | 0.75 (2 dmg) | the slash |
| `bash` | rule 8 (greedy on the shield) | 0.45 | 48 px shield bash |

- **Shield:** blocks front hits while on (as now); faces the last hitter after each recover (rule 8). **P3:** it also turns every 1.5 s on its own (a 0.3 s swing, drawn), so the back is open at a rhythm.
- **Phases:** P1 (100–60 %): `throw→return, rule, scan, deny`. P2 (60–25 %): deny walls; `phase, throw→return, rule×2, scan, deny`. P3 (25–0 %): DROP ALL plus `throw→return, deny, phase` (shorter recovers: `rec 0.5`).
- `net_fields` = `plan_fields()` + `[face, shield_on, turn_t×100, wall_l, wall_r, walls_t0×100, drop_t0×100, seed, rule_x (up to 2), lane order]`.
- **Tests:** unit `firewall2`: HP 82; `throw` hits a standing player on the way out and a jumping one on the way back, not the other way round; the deny walls stop at 96 and 288 and push inward; DROP ALL burns everything but the announced port, and the port is announced ≥ 0.9 s before; `scan` order is away from the boss; P3's shield turns every 1.5 s. Keep the 4B-2 checks that still hold.

## MVB3-08 · THE REVIEWER #2 v2 (optional superboss)

Rework `reviewer2.gd` (NetClasses 32). Pad trigger, reward and arena unchanged. **HP: `T 120, u 0.8` → 96.**

**Arena hazard: unresolved comments.** Every grey `reject` shot and every `nitpick` pen that lands on the floor leaves a mark (`//`, 16 px wide) at its x. A mark hurts (1) a body standing on it (the floor band 6 px high) after 0.8 s. At most 8 marks (a ninth removes the oldest). **Resolving:** each caught yellow diamond back into the boss clears the two oldest marks (pop `LGTM`). A phase change clears them all.

| id | what | cue | harm |
|---|---|---|---|
| `cached` | as built (it blocks your last attack kind and ripostes), faster | 1.0 | riposte (2 dmg, cue 0.75) |
| `double` | two thrusts (P3: three), each 150 px, numbered | 0.75 (2 dmg) | bands |
| `verdict` | 6 shots 0.5 s apart, alternating diamond and grey; P2+ a diamond and a grey together each time | 0.6 | shots; greys leave marks |
| `nitpick` (new) | 6 red pens rain on x's marked 0.7 s before (never on the same x as a standing partner's mark gap: keep one 4-tile gap free) | 0.7 | pens (1); each leaves a mark |
| `cross` | as built | 0.9 | slashes |
| `signoff` (P3) | lunge → slash → diamond, chained (`rec 0.2` between) | 0.75 then 0.45 | each |

- **Phases:** P1 (100–60 %): `cached, double, verdict, nitpick`. P2 (60–25 %): attacks come in pairs (`rec 0.4` between the two): `double+verdict`, `cross+nitpick`, `cached`. P3 (25–0 %): pairs plus `signoff`.
- Rule 8 as built (greedy → `cached` on that player).
- `net_fields` = `plan_fields()` + `[last_kind, marks (up to 8 × [x, t0×100])]`.
- **Tests:** unit `reviewer2b`: HP 96; a grey shot leaves a mark that hurts after 0.8 s and not before; a caught diamond clears the two oldest marks; a ninth mark drops the oldest; a phase change clears them; `nitpick` always leaves a 64 px gap; P2 chains two attacks with a 0.4 s recover between. Keep the pad and reward checks.

## MVB3-09 · Co-op and difficulty

1. **Scenarios** (each also with `BADLINE_ALL=1`): update `co-crawler`, `co-firewall`, `co-reviewer2` to the new attacks (pass rules as 4B-2's, plus: no `arena-tell` and no `boss-cue` invariant; the guest takes at least one hit from an arena hazard in 40 s of fight, so the guest really checks them). New `co-sniffer` (N11: the guest's zip to a tapped ring is cut on the guest's page; the host's sniffer hops), `co-mitm` (N01: the MITM echoes the guest's swipe toward the guest), `co-rst` (N17: the guest triggers the chase; both pages draw the line within 8 px of each other; `rst:N17` set when both are down), `co-loss` (N12: the guest rides; the loss happens at the same packet on both pages).
2. **Difficulty presets:** run the three boss unit tests on `easy` too: every cue × `telegraph_mult`, every recover × `punish_mult`, and no 2-damage hit has a cue under 0.7 × `telegraph_mult`.
3. **A bot check of the hard rooms** (unit `hardrooms`, new): in N05 a bot that holds [jump] 40 frames before each pit (a full jump) is hurt by a web; one that holds 12 frames over the 3-wide pits and dashes over the 4-wide ones reaches the east door. (This is the difficulty proven: the naive way fails, the right way works.)

## MVB3-10 · Tests, build, playtest steps, report — then stop

1. `test-all.sh` list += `kit4b3 w6enemies2 net4b3 crawler2 firewall2 reviewer2b hardrooms`; `ALL=` += `co-sniffer co-mitm co-rst co-loss`.
2. `check4b3.py` `0 problems`; `check4b2.py`, `check4a.py` `0 problems`; `world.py` `errors 0`.
3. `bash tools/godot/test-all.sh` → `ALL PASS`; `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-crawler co-firewall co-reviewer2 co-sniffer co-mitm co-rst co-loss co-honeypot`.
4. Screenshots of N05, N12, N17 (the chase) and each boss's P3 into `docs/reports/img-phase4b3/`.
5. Export as the last commit (`MVB3-10: export public/mv`).
6. `docs/reports/metroidvania-phase4b3.md`: what was done; deviations; test results; **what felt too easy or too hard in your bots** (honestly); **playtest steps for Zakaria in Persian**, short:
   - N05's pits under the webs (short jumps, dashes); N07's chimneys; N08's climb;
   - the three bosses: say which phase is unfair and which is easy;
   - N11 with the sniffers; N12's packet loss; N13; N16; N17's RST chase;
   - the honeypot's new waves; co-op over the internet: do the tells still read with ping?
7. Update `docs/metroidvania/README.md` and this plan's status table. **Stop.**

---

## Appendix · Where things are

| what | where |
|---|---|
| kit, arena hazards | `godot/src/enemies/boss.gd` |
| the three bosses | `crawler_boss.gd`, `firewall_boss.gd`, `reviewer2.gd` |
| new enemies | `sniffer.gd`, `mitm.gd`, `botnet.gd`, `pinger.gd` (new); `scraper.gd`, `worm.gd`, `ddos.gd`, `spyware.gd` |
| body effects, zip cut | `godot/src/player/player.gd` |
| shots (bounce), packet loss, chase, waves, tags | `godot/src/world/room.gd` |
| co-op | `coop.gd`, `net_classes.gd`, `watchdog.gd` |
| data | `docs/metroidvania/phase4b3-data/` |
