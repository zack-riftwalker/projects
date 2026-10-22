# 17b · RACE CONDITION: build plan (for the builder)

This is the complete build plan for RACE CONDITION v3, written for the model that builds it (the `boss-build` skill). The design talk with Zakaria is in [`17-race-condition.md`](17-race-condition.md) (Persian). That doc is the source of truth for **what the player sees and hears**; this file is the source of truth for **how to build it**. If they disagree, the Persian doc wins and you ask Zakaria.

Read before every session: this file, [`15-boss-process.md`](15-boss-process.md) sections 3-5, [`07-js-vs-godot.md`](07-js-vs-godot.md) §3, and `CLAUDE.md`. Reference builds: CRAWLER OF THE WEB (`godot/src/enemies/crawler_boss.gd`, `godot/src/world/index_hall.gd`) and THE FIREWALL (`godot/src/enemies/firewall_boss.gd`, `godot/src/world/honeypot_hall.gd`: moving platforms owned by a hall, two HP bars, the loss menu). **Copy their patterns** (a boss class + an arena helper owned by the room, state in net fields, hazards via `hz_add`, scenes on `room.time`).

The old boss (`godot/src/enemies/race_boss.gd`, kit-era, MV5A-06) is replaced. Keep the class name `RaceBoss` and its `NetClasses` number (46).

---

## 0. How to work

- **One milestone per session.** Find the first milestone in §9 whose status is not `done`, build only that one, test it, commit, push to `ph1`, mark it `done` in the table below (with anything that changed), report to Zakaria **in Persian**, short.
- Start: `git fetch origin ph1 && git checkout ph1 && git pull origin ph1`. `npm ci` if `node_modules` is missing. `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`.
- **Ask, don't guess**, when something the player sees or hears is not decided here or in the Persian doc. Ask in Persian, 2 options + a recommendation. Internal choices are yours.
- Never invent dialogue. All lines are in §6.
- Never merge into `main`. Never skip, disable or loosen a test to get green.

| milestone | what | status |
|---|---|---|
| M1 | arena: T06 26x30, the belfry hall (bells as platforms, escapement, buffer floor), camera, lights; per-room tower tick | not started |
| M2 | the two automata + reads + phase-1 single attacks + intro + two-bar HUD | not started |
| M3 | double write and the clash, guarding, the escapement lock, buffer corruption, bell crack/fall/re-hang | not started |
| M4 | phase 2 (transition, switch, bell drop, triple strike, combo, holes), alone mode, rewind | not started |
| M5 | death scene and reward, voices and interleaved subtitles, sounds, music, logs line | not started |
| M6 | loss menu, foreshadow (TB2, T04), after-state (tower tick, T02/TA1), full tests, web export | not started |

## 1. The fight in one page

TICK and TOCK are two bronze clockwork **bell-strikers** (jacquemarts, like the bronze Moors of St Mark's Clocktower in Venice: one young and slim, one old and bearded). For forty years the tower clock's **escapement** (the rocking anchor that lets the wheel move one tooth per swing: the clock's own mutex, the part that goes "tick... tock") made them take turns. Tonight the user's refactor deleted the escapement's pin (`- escapement.lock();  // slow. useless.`). Now both strike at once, the tower loses beats, and they see Clawd as a third thread writing the same clock.

1. **Before.** Climbing TB2 `mutex.c` the tower tick quickens (0.7 s) and two bells are heard through the wall, almost but not quite together. A small window near the top shows the two silhouettes striking. A sign by the arena door shows the deleted line.
2. **Intro.** The belfry: five bells hang from the ceiling beam and are the platforms; the escapement hangs loose under the beam, a red cross where its pin should be. The two automata stand frozen on the two big bells, wake up, and say `One at a time, little agent.` together (two voices drifting apart, interleaved subtitles). Name card, two HP bars.
3. **Phase 1 (tick 0.7).** They attack **at the same time**, each on its own loop, always hopping between bells (a bell they land on, or strike, swings and rings out a ring wave). **TOCK reads where you were; TICK reads where you are going.** Standing still or running steadily both get you hit: change rhythm. The signature **double write**: both lock on, both raise hammers; stay = 2 damage, leave early = TICK follows, leave **late** = their hammers clash and both are dazed 2 s (the only big punish). Hitting the escapement's bob makes them take turns for 3 s. The floor is a shared buffer: a cell written by both turns corrupt.
4. **Phase 2 (tick 0.6),** at 50 % total HP or when one falls: red heat, springs out, the escapement swings wildly. Context switches, TOCK rips bells down (the room shrinks, fallen bells become cover), TICK's triple strike, corrupt cells become holes.
5. **One falls** (any time): it winds down and lies on the floor; the other shouts `Who wrote last? WHO WROTE LAST?`, fights alone, and after 15 s tries to rewind its partner (2 s, interruptible).
6. **Death.** The last one crawls to its partner; both bow, `After you.` / `No... after you.`, and freeze bowing. The pin clicks into the escapement (the red cross becomes a red dot: a breakpoint), the clock ticks right and jumps to 05:12, the red dot floats down: **breakpoint**.
7. **Loss.** The FIREWALL's menu: `retry` / `back to last commit`.
8. **After.** The two stay frozen bowing forever. The whole tower gets one steady tick (0.8333); T02/TA1 blink blocks turn solid (already built, D40). A changelog line in Logs.

---

## 2. Rules that must hold

- **No on-screen warnings.** Do not call `draw_plan()`, `warn_col()` or `_target_marker()`. Every tell is the body or the room: the raised hammer, the eye light and its thin beam, the chest clock ticking, a bell glowing or shaking, a chain rattling. The READ afterimage (§5.3) is drawn as light from the eye, in the thread's colour, not as a marker box.
- Arena hazards (`hz_add`) need a visible build-up >= 0.6 s (`HZ_WARN_MIN`); the guest is only hurt by hazards it has seen for `HZ_SEEN_MIN` (0.5 s).
- A 2-damage hit needs a cue >= 0.7 s (`bosspresets`). Every cue >= 0.30 s as seen on the guest (watchdog `boss-cue`). **The guard (×0.8) and alone (×0.85) multipliers never apply to 2-damage plans**, and no cue may go under 0.30 s after them.
- Damage: normal 1, heavy 2 via `_big()`.
- **Weighted choice** per automaton by distance, height and phase; never the same attack twice in a row per automaton; the **first cycle of each phase is a fixed teaching order** (§5.5, §5.8).
- **Dangers at once:** at most one plan per automaton (the double write counts as both), plus ring waves already in flight, plus one floor layer (corrupt cells or holes). Two single strikes from different automata may not **land** within 0.15 s of each other (readability); the double write is the exception by design.
- **Beatable without sudo and without catch.** The player surely has: bash (8-way dash, 48 px), jump (54 px ≈ 3.4 tiles, ~0.65 s), wall jump, down-attack, **curl** (a player cannot reach the tower without it). Check every route in §3.3 with these.
- **Co-op:** the host owns the bosses and the hall. Everything the guest must show or be hurt by is state: net fields (`net_fields` / `net_apply`, constant `NF`), hazards (`hz_pack` / `hz_unpack`), or a pure function of `room.time` and those fields. Bell positions are a pure function of `room.time` and the bell fields, so both pages move the same platforms. Damage to P2 only through hazards/harmboxes checked by each page on its own body, or `room.harm_zone`. `--test=parity` after any net-field change.
- **State over events:** phase, tick length, music, bells, holes, the menu: derived from state every frame.
- **Speed:** nothing per frame or per snapshot walks `Game.flags`. The back wall, beam and clockwork backdrop are drawn once in their own node. `--test=perfrooms` before and after M1 and M4.
- **Scope:** T06 and the boss's files, plus the hooks listed per milestone (per-room tick in M1; TB2/T04/aftermath in M6). Do not redraw any other room's map.
- Voice: only `en_GB-northern_english_male-medium` (CC BY-SA 4.0). Never `alan` or `ryan`.
- Nothing personal, no keys, no IPs in the repo.

---

## 3. Geometry (tiles are 16 px; x right, y down; row 0 is the ceiling)

Room T06: **26 × 30 tiles** (416 × 480 px). It grows **upward only**: origin `[1164, -150]` → **`[1164, -166]`** in `godot/src/world/rooms.json` and in `docs/metroidvania/world-phase45.json` (`y: -166, h: 30`). Checked: columns 1164..1190 are free from world row -150 up to -198 (TB2 west and TC2 east reach -198; T08/T09 start at -198 above). The doors keep their world rows, so in room rows they move from 7..10 to **23..26**: `T06:W` `a: 23, b: 26` (to `TB2:E`, lock `fight`), `T06:E` `a: 23, b: 26` (to `TC2:W`, `until:boss:RACE`). TB2/TC2 door entries do not change. Run every map test that reads these (`mapdata`, `worlddigest`, `rooms*`, the world checkers).

### 3.1 The map file `godot/src/world/rooms/T06.txt`

Walls, the floor, the two GET rings and the spawn cells only; the bells, beam and escapement belong to the hall (§4).

```
##########################
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#       @        @       #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
#                        #
                          
                          
                          
   B                B     
##########################
##########################
##########################
```

(Rows 23-26 are open at columns 0 and 25: the doors. `@` at (8, 12) and (17, 12). `B` at (3, 26) and (20, 26) are the spawn cells; the boss moves both automata onto bells 1 and 2 in the intro.)

### 3.2 Named coordinates (constants in the hall)

| name | tiles | notes |
|---|---|---|
| floor top | row 27 (y 432 px) | rows 27-29 solid |
| buffer cells | 8 cells × 3 tiles, x from tile 1 to 24 (`SEG_X0 = 16`, `SEG_W = 48` px) | as the old boss |
| ceiling beam | row 1, x 1..24 | drawn by the hall; not solid (decor), bells hang from it |
| bell 1 (big, low) | x 2..6, top row 24 | deep note |
| bell 2 (big, low) | x 19..23, top row 24 | deep note |
| bell 3 (middle) | x 11..14, top row 21 | middle note |
| bell 4 (small, high) | x 7..9, top row 17 | high note |
| bell 5 (small, high) | x 16..18, top row 17 | high note |
| clock face | centre (13, 7), radius 3.5 tiles | decor, behind the escapement rod (§4.4) |
| escapement anchor | pivot under the beam at (13, 2.5), arc 5 tiles wide with two pallets | decor + state |
| escapement bob (the lock) | centre (13, 11) tiles = (216, 184) px, hitbox 18 × 18 | the thing you hit |
| GET rings | (8, 12), (17, 12) | map `@` |
| lamps | (2, 3), (23, 3) | lights |

A bell's **standing surface** is its top (`top row × 16`), width as listed; the body below is drawn but not solid except the top surface (a one-way platform you can jump through from below, like the packets). Bells are platforms in `room.plats` owned by the hall (flag `bell: i`), skipped by `_move_platforms` and by the generic platform drawing.

### 3.3 Routes (check them in `race3`, M1)

Without sudo or catch: floor → bell 1 or 2 (3 tiles up) → bell 3 (3 up, 4 across) → bell 4 or 5 (4 up, 1-2 across, jump + up-dash) → GET ring (curl, 5 up, within `CURL_RANGE` 104 px) → the bob (from the ring's pop + dash). Write a reach test that runs the player's real jump/dash/curl numbers over these pairs (like the firewall's lane test) and fails if any pair is out of reach. Also with bells 3 and 4 fallen (the worst phase-2 case, §4.3): the bob must still be reachable from bell 5 → ring (17, 12).

### 3.4 Camera

`"cam": "free"` on the boss entry. The room is 480 px tall: the camera follows the players and **leans toward the automaton whose plan is in its cue** (like CRAWLER's lean), clamped to the room. In the intro the camera pans from the floor to the escapement and back (§5.4).

---

## 4. The arena helper: `godot/src/world/belfry_hall.gd`

Like `honeypot_hall.gd`: created by the room when `rooms.json` T06 has `"hall": "belfry"`, owns the bells, the escapement drawing, the buffer floor drawing, the backdrop node.

### 4.1 State (host writes; guest reads from the boss's net fields)

Per bell `i` (5): `strike_t0[i]` (last strike or landing kick), `amp[i]` (px of that swing), `crack_t0[i]` (−1 none), `fall_t0[i]` (−1 none), `fallen[i]` (bool), `fallen_x[i]`, `rehang_t0[i]` (−1 none). Escapement: `serial_until`, `lock_cd_until`, `pin_in` (after the death scene). Buffer: per cell `paint_t[thread][cell]`, `corrupt_t0[cell]`, `hole_t0[cell]`.

### 4.2 Bells (platforms, pure functions)

- Rest position from §3.2. Swing: `dx = amp * sin(2π·(t − strike_t0)/1.2) * exp(−(t − strike_t0)/0.8)`; `amp` = 4 px for a strike on a big bell, 5 px on a small one, 3 px for a landing kick. Players standing on a bell move with it (the moving-platform carry the packets use).
- **Crack** (both automata strike the same bell within 0.25 s, M3): `crack_t0 = t`; 0.8 s rattle (±1 px shake, a high jingle) and a visible crack line; then **falls straight down** (`g` 900 px/s²). While falling it is a hazard (`bellfall`, 2 damage, the 0.8 s rattle is its cue) for anyone under it. Landing: a floor thud (visual shake only), `fallen[i] = true`, `fallen_x` = its x.
- **Phase 1:** a fallen bell lies 8.0 s, fades out over 0.5 s, then a new bell lowers from the beam into its slot over 1.5 s (`rehang_t0`); its top becomes standable when it arrives.
- **Phase 2:** fallen bells stay, lying on the floor as solid blocks (width as the bell, 2 tiles high): **cover** (ring waves do not pass through them, §5.3). **At most 2 fallen** at a time in phase 2; when 2 are down, no crack happens (a double strike then makes a bigger ring only) and TOCK's bell drop is not chosen. **At least 3 bells hang always.**
- **A player hits a bell** (any attack hitbox overlapping it): it rings (small swing, a harmless ring drawn faint) and **cancels the cue** of an automaton standing on it or within 40 px (its plan goes straight to a 0.3 s recovery; no daze). Per-bell cooldown 1.5 s. This is the only "interrupt"; it must not stun.

### 4.3 Buffer floor

- A WRITE that lands on the floor (floor slam, the double write, the crash of a context-switch landing on the floor) paints the cell under it with its thread's colour (`paint_t[thread][cell] = t`).
- A cell painted by **both** threads within 4.0 s turns **corrupt**: 0.6 s white-hot build-up, then
  - phase 1: a 6 px hurt band for 6.0 s, 1 damage (`corrupt` hazard), at most 4 cells at once;
  - phase 2: the cell **opens** for 4.0 s (`hole` hazard): its top two floor rows (27-28) stop being solid, leaving a 2-tile pit over row 29; the pit bottom hurts (1 damage) and bounces the player out, like spikes. At most 2 holes at once, never two neighbouring cells.
- The escapement lock clears every corrupt cell and hole immediately.

### 4.4 Drawing

- **Backdrop node (drawn once):** dark brick wall, brass pipes, two gears and a slow pendulum at the sides, two arched windows with the night sky at the sides above the doors, warm floor stones (reference `17-race-data/ref/background.webp`). The back wall must cover the whole room (`gfxcontrast`).
- **The clock face** (decided in step 2, needed by the death scene): decor in the backdrop, centre (13, 7) tiles, radius 3.5 tiles, deep blue enamel, gold Roman numerals I-XII (draw them right; the reference `clock.webp` has broken numerals), a gold sun-shaped hour hand, a brass riveted rim (reference `17-race-data/ref/clock.webp`). The escapement's rod passes in front of it down to the bob. Hands: phase 1 they tremble and now and then jump back a step; phase 2 the glass is cracked and the hands spin; after the death they jump to 05:12 and then keep real tower time. The hands are drawn every frame (small); the face itself is in the static node.
- Bells: brass with a dark patina, a highlight line on the crown, chains up to the beam; cracked bells show a dark crack; the swing is drawn from §4.2.
- Escapement: brass anchor arc with two pallets, a rod down to the bob; until the pin is in, a small **red cross** at the pivot and the anchor hangs crooked and swings irregularly (phase 1 lazily, phase 2 wildly with sparks); when serialized it swings regularly for the serial time; after the death, `pin_in`: a **red dot** at the pivot, steady swing on the tick.
- Lights (`room_lights.gd` `_arena`, `look.gd`): phase 1 warm amber from the two lamps; phase 2 red-orange, sparks from the anchor; after death warm and calm. No darkness.

### 4.5 Per-room tower tick (M1)

Today `Tower.TICK` is a constant (0.8333) used by `room.gd` (`const TICK`), `tower.gd`, `spinlock.gd`, `ticker.gd`, `hud.gd`. Make it per room:
- `rooms.json` gets an optional `"tick"` per tower room: **T01 1.0, T02 1.0, TB2 0.7**; every other tower room keeps 0.8333 (no key). After the flag `boss:RACE` every tower room uses **0.8333** (the clock is fixed). Cache the value on room load (do not read flags per frame).
- In T06 the boss drives the tick: **0.7 in phase 1, 0.6 in phase 2**, 0.8333 after the death. Because the length changes mid-room, keep a beat clock: `tick_i = beat_i0 + floor((room.time − beat_t0) / tick_len)`, with `beat_i0`, `beat_t0`, `tick_len` as net fields; a phase change starts a new segment at the next tick boundary.
- Replace the constant everywhere by the room's value (`room.tick_len()` or similar); `Tower.tick_i_of` / `tick_f_of` take the room's clock. The tick sound and HUD pendulum follow it.
- **Check the tower rooms with the new ticks:** run `tick5a` and the tower route checks (`tools/godot/roomcheck/` and the 5A sims in `docs/metroidvania/phase5a-data/`) for T01, T02, TB2 at their new tick. If a jump, blink-block run or mutex gate becomes impossible or trivial, **do not redraw the room**: write it in the M1 notes and send it to the world department's inbox (`docs/studio/WORLD.md` «صندوق»), and tell Zakaria. (The mutex gates' 3.5 s and breakpoint's 3.5 s are seconds, not ticks: unchanged.)

---

## 5. The boss: `godot/src/enemies/race_boss.gd` (rewrite)

### 5.1 Names, HP, two bars

- `boss_name = "RACE CONDITION"`, `sub = "two threads, one variable"`.
- Total HP = `Game.boss_hp` of T06 (`T` 100, `u` 0.9 → 90 at normal; ×1.5 in co-op by the existing rule). **TICK = round(0.40 × total), TOCK = the rest.**
- HUD: under the name, **two bars side by side**: `TICK` red (`#ff4a3a`) left, `TOCK` cyan (`#2ee6d6`) right (`hud_bar` hook like the firewall's). A downed automaton's bar shows empty and dim; a rewound one refills to 30 %.
- Bodies: 32 × 48 each, hurtbox = the body (not the hammer). Hits go to the automaton whose hurtbox was struck (the host picks the one nearest a guest's swing, as now).

### 5.2 States

`intro → p1 → trans → p2 → dying`, plus per automaton `alive | down | rewinding`. `alone` = exactly one alive. Phase 2 starts when `hpTICK + hpTOCK <= 0.5 × total` **or** one goes down, whichever first (if a fall starts it, the fall's line plays after the transition line).

### 5.3 Reads, strikes, rings (shared by all attacks)

- **Rhythm:** a beat is half a tick (phase 1: 0.35 s, phase 2: 0.30 s). Cues are counted in beats and start on a beat: **normal cue = 2 beats** (0.70 / 0.60 s), **heavy cue = 3 beats** (1.05 / 0.90 s). Recovery between plans 0.3-0.4 s.
- **READ** at the start of every cue: the eye light turns on, a thin beam in the thread's colour goes from the eye to the read point, and a faint afterimage (Clawd's outline, the thread's colour, 40 % alpha) stays at that point until the strike. The chest clock ticks once.
  - **TOCK, stale read:** the target's position now.
  - **TICK, prefetch:** the target's position + its velocity × 0.5 s (velocity = average over the last 0.25 s), clamped inside the room. On a still target it equals the position.
- **Targets:** solo, the player. Co-op: TICK reads one player and TOCK the other; swap after each plan. **Guard:** when one automaton is vulnerable (hammer stuck, dazed, or kneeling to rewind), the other's next plan targets the player nearest its partner and its cue is ×0.8 (normal plans only).
- **Hopping:** between plans an automaton hops to the bell nearest its next read point (a jump arc of 0.4-0.5 s; 0.25 s crouch before it as the tell). Landing on a bell kicks it (`amp` 3 px) and makes a small ring that does **not** hurt.
- **Ring wave** (`ring` hazard): from the struck bell's centre, a circle growing 0 → 80 px radius in 0.5 s, 6 px thick, 1 damage on touching the circle's band. In phase 2 fallen bells block it (a player whose line to the centre crosses a fallen bell's box is safe). Draw the ring from its `t0`; its 2-beat cue (the raised hammer and the glowing bell) is its build-up.

### 5.4 Intro (6.0 s first time; skipped from the second time and after `retry`)

| t (s) | what |
|---|---|
| 0.0 | Clawd is inside the west door; the door locks (`fight`). The tower tick sound stops. |
| 0.0-2.5 | Camera pans up from the floor over the bells to the escapement (its red cross). The two automata stand frozen on bells 1 and 2. |
| 2.5 | The anchor gives one crooked swing (creak). |
| 3.0 | Both eyes light at once (red, cyan); their keys start turning (wind-up sound). Camera eases back to the players. |
| 3.4-5.4 | Line `intro` (§6) with the interleaved subtitle. |
| 5.0 | Name card `RACE CONDITION` / `two threads, one variable`; the two bars fill. |
| 6.0 | Tick 0.7 starts, music phase 1, fight. |

### 5.5 Phase 1 attacks (tick 0.7)

| id | who | cue | active | damage | punish |
|---|---|---|---|---|---|
| `strike` bell strike | both (TICK prefers bells 4/5/3, TOCK 1/2/3) | 2 beats: hops to the bell nearest the read point, hammer up, the bell glows | the hit + a ring wave | 1 (ring) | 0.3 s recovery on the bell |
| `slam` floor slam | both | 2 beats: crouched on the bell, hammer up | dives to the read point: a 32 × 48 box on landing; paints the cell | 1 | **hammer stuck 0.5 s** (guard triggers) |
| `double` double write | both together | **3 beats (heavy)**: both eyes, both chest clocks show the same number, both hammers up, two ticks on top of each other | see below | **2** | clash: **both dazed 2.0 s** |
| `clapper` | TOCK | 2 beats: tilts its bell, pulls the yellow clapper back | a yellow projectile 150 px/s toward the read point, catchable (`catch`) | 1 | if caught and returned: TOCK dazed **0.7 s** |
| `rope` rope swing | TICK | 2 beats: grabs a bell chain and leans back | swings an arc (radius 64 px, 0.5 s) **toward the target's heading side**, kick box at the feet | 1 | 0.3 s at the arc's end |

**Double write, exactly:** both READ the **same** point (the target's position; prefetch off for this one). At `cue − 0.30 s` the host checks the target: if it is more than 32 px from the read point, **TICK re-reads** (prefetch from there) and the two strikes land separately (TOCK on the old point, TICK on the new one, 0.15 s later), 1 damage each, **no clash**. Otherwise both are **committed**. At impact: if the target is inside the strike box → 2 damage (one hit, `_big()`); if not (it left in the last 0.30 s) → **clash**: a loud bell-crash sound, sparks, **both dazed 2.0 s** (`daze_t`). If the target stood on a bell and the strike lands on it, the bell cracks (§4.2). In co-op the double write reads the player that moved least over the last 1.0 s.

**Weights (phase 1, per automaton):** target farther than 6 tiles → `strike` 3, `clapper` 2 (TOCK), `slam` 1; nearer → `slam` 3, `rope` 2 (TICK), `strike` 1. `double` when both are free and neither used it in its last 3 plans (~every 3-4 plans each), never twice in a row. **Teaching order (first cycle):** TOCK `strike`, TICK `slam`, then `double`.

**Pressure layer:** buffer corruption (§4.3); bells crack and re-hang (§4.2).

### 5.6 The escapement lock

- Hitting the bob (any player attack, one hit) when `lock_cd_until <= t`: a heavy *clang*, the anchor catches. **Serialized for 3.0 s (phase 2: 2.5 s):** the two plan in turns, one plan per tick, alternating TICK, TOCK; no `double`, no `switch`; every corrupt cell and hole clears at once. No extra stumble (decided: no free daze).
- `lock_cd_until = t + 12.0` from the hit. While cooling, the bob sits pinned against the beam's bracket (visibly out of reach) and swings back down when ready.
- Co-op: either player's hit counts for both.

### 5.7 Transition to phase 2 (2.0 s, both invulnerable)

The anchor swings wildly and sparks; the light goes red-orange; both bodies heat red (springs out of the seams, jerky idle); line `p2` (§6). At the end: tick 0.6 from the next boundary, music phase 2.

### 5.8 Phase 2 attacks (tick 0.6)

Everything of phase 1 (cues now 0.6 / 0.9 s), plus:

| id | who | cue | active | damage | punish |
|---|---|---|---|---|---|
| `switch` context switch | both | the two **destination** bells start swinging and jingling 0.6 s before (the body tell is the crouch, the room tell is the bells) | a crossing leap (0.5 s); each landing makes a 1-damage ring (small: 48 px) | 1 | — |
| `drop` bell drop | TOCK | **3 beats (heavy)**: leaps to the chain above the bell nearest the target's read point, the chain rattles and the bell shakes | rips the chain: the bell falls straight down with TOCK riding it (`bellfall`, 2 damage under it); it lands as a fallen bell (§4.2) | **2** | TOCK is stuck **0.8 s** beside the fallen bell on the floor |
| `triple` triple strike | TICK | 2 beats: shakes the hammer three times | three strikes on three different bells, **one beat apart**, each at the bell nearest a fresh prefetch read | 1 each (rings) | 0.8 s after the third |
| `combo` | both | — | `switch`, then `double` with its 3-beat cue starting on the landing | 2 | clash 2.0 s |

**Weights (phase 2):** as phase 1, plus `switch` 2 when both are free, `drop` 2 (TOCK, only if fewer than 2 bells are fallen), `triple` 2 (TICK, target farther than 4 tiles), `combo` instead of `double` half the time. **Teaching order:** `switch`, TOCK `drop`, TICK `triple`.

**Pressure layer:** holes (§4.3); fallen bells stay.

The Persian doc's first wording of `drop` had TOCK stuck on the ceiling beam, which no player can reach; riding the bell down and being stuck on the floor is the fix (Zakaria to confirm, §11).

### 5.9 Alone and rewind

- **Down:** an automaton at 0 HP winds down: its key stops, it drops off its bell to the floor and lies there (dim eyes, no hurtbox). The other plays line `alone` (§6) once.
- **Alone:** every cue ×0.85 (not 2-damage ones; never under 0.30 s on the guest). `double` alone: it READs twice (one stale point, one prefetch point; both afterimages in its colour), then two strikes 0.2 s apart, 1 + 1, no clash. Serialized while alone: one plan per tick, 1.5 s extra recovery after each (this is the only extra stumble, because alone it cannot guard).
- **Rewind:** 15.0 s after the partner went down (timer runs while the survivor lives), the survivor hops down beside it and kneels: **2.0 s** of winding (the key turns, a ratchet sound). Any damage to the survivor cancels it (6.0 s before it tries again). If it completes, the partner stands with **30 %** of its own max HP, eyes relight, and the pair resumes (phase stays 2).

### 5.10 Death (~8.0 s)

| t (s) | what |
|---|---|
| 0.0 | The last automaton's HP hits 0. Plans and hazards stop; holes close; the music cuts. |
| 0.0-2.0 | It drops its hammer and crawls to its partner (if the partner is not down, the partner winds down first, then the crawl). The partner's key turns once more; it half rises. |
| 2.0-5.0 | Face to face, both bow. Line `die` (§6): TICK `After you.`, then TOCK `No... after you.` They freeze, bowing. |
| 5.0 | The pin clicks in (`pin_in`): the red cross becomes a **red dot**; the anchor swings evenly; tick... tock... on 0.8333. |
| 5.5 | Warm light returns. |
| 6.0-8.0 | The red dot floats down to the floor centre; touching it = reward (`reward: "breakpoint"`, the existing banner `breakpoint` / `facing a machine or an enemy, press [special]: it stops for 3.5 s`). The east door unlocks (`until:boss:RACE`). |

### 5.11 Net fields

At least: `active`, `dying`, `ph`, `trans_t0*100`, `intro_t0*100`, `say_k`, `say_t0*100`, `die_t*100`, the beat clock (`beat_i0`, `beat_t0*100`, `tick_len*1000`), per automaton (`x`, `y`, `hp*10`, `max_hp`, `st` alive/down/rewinding, `hop_t0*100`, hop from/to x,y, `hammer` 0 idle/1 up/2 stuck, `daze_until*100`, `read_x`, `read_y`, `read2_x`, `read2_y`, `eye_on`, `dial`), `rewind_t0*100`, the escapement (`serial_until*100`, `lock_cd_until*100`, `pin_in`), the bells (per bell `strike_t0*100`, `amp`, `crack_t0*100`, `fall_t0*100`, `fallen`, `fallen_x`, `rehang_t0*100`), the buffer (paint times packed ×10, `corrupt_t0*100` and `hole_t0*100` per cell), the loss menu fields (§7.1), then `plan_fields()` and `hz_pack()` last. `const NF := <count before plan_fields>` like CRAWLER; `puppet_tick(dt)` like CRAWLER. Hazard kinds in `hz_kinds()`: `["ring", "slambox", "clapper", "rope", "bellfall", "corrupt", "hole"]` (adjust names, keep them registered).

### 5.12 Music

`music_now(want)`: intro → `""` (the tower tick only); phase 1 → placeholder; transition → `""`; phase 2 → placeholder; dying → `""`, then the tower theme at the steady tick. **Placeholders until Zakaria decides (§11 question 1):** phase 1 `"boss"`, phase 2 `"boss_hi"`. Comment them as placeholders.

---

## 6. Lines, voices, subtitles

Voice: `tools/voice/race_voice.py`, **take `a`** (both from `en_GB-northern_english_male-medium`: TICK pitch ×1.14, length ×0.92; TOCK pitch ×0.80, length ×1.08; the clockwork filter at strength 0.6). Add a `--line <key> --out <key>.ogg --json <key>.json` mode like `firewall_voice.py`, writing **word start times per voice** (measure them with a speech recognizer, as `firewall_times.py` does; the takes were checked with `faster-whisper base.en`). Files: `godot/assets/voice/race_<key>.ogg` + `race.json`. Credits in `godot/assets/voice/CREDITS.md` (CC BY-SA 4.0, same as CRAWLER's).

| key | when | who | text | how it is said |
|---|---|---|---|---|
| `intro` | intro 3.4 s | both | `One at a time, little agent.` | together, TOCK 0.08 s later; TICK is faster, so they drift apart |
| `p2` | transition | TICK, then TOCK over it | `We both read zero.` / `We both wrote one.` | TOCK starts halfway through TICK's line |
| `alone` | one goes down | the survivor (its own voice settings) | `Who wrote last?` ... `Who. Wrote. Last?` | slow (×1.25), the second time word by word (×1.1): the ASR misheard it at speed. Decided: keep these words |
| `die` | death 2.0 s | TICK, then TOCK | `After you.` (0.6 s pause) `No... after you.` | |

**The `alone` line:** the old text in the Persian doc is `Who wrote last? WHO WROTE LAST?`; the take says it as `Who wrote last?` then `Who. Wrote. Last?`. The subtitle shows `Who wrote last? WHO WROTE LAST?` (capitals on the second).

**Interleaved subtitles (the race in the text):** for `intro` and `p2`, the subtitle is built word by word from both voices' word times: each word appears when its voice says it, TICK's words red, TOCK's cyan, in one line, so `intro` reads `One One at at a a time, time, little little agent. agent.` as it is heard. Other lines: a normal subtitle in the speaker's colour. Draw in the boss's `draw_hud(ci)` (called last by `hud.gd`), above the bars, like the firewall's.

Sounds (`tools/godot/sfx/make_race_sfx.py`, generated wav, small): bell strikes (3 pitches: big, middle, small), the cracked-bell crash (two strikes together), bell rattle (crack), bell fall thud, chain rattle, hammer up (a short whirr), hammer stuck (thunk), clapper shot, rope creak, eye on (a tiny tick), wind-up key / ratchet (intro, rewind), escapement clang (lock), anchor creak, pin click (death), tick and tock (the tower tick at the room's tick length). Register them in `Audio.SFX`.

---

## 7. Loss menu, foreshadow, after-state (M6)

### 7.1 The loss menu

Reuse THE FIREWALL's menu (`firewall_boss.gd`: `LOSS_ROWS`, `loss_on`, the hooks in `room_manager.gd`, `main.gd` ~916, `coop.gd` `_host_down_logic`). **Generalize it** instead of copying: move the menu state and drawing into `Boss` as an opt-in (`func has_retry() -> bool`, false by default), turn it on for `FirewallBoss` and `RaceBoss`. THE FIREWALL must behave exactly as before (`firewall3` M6 part passes). `retry` reloads T06 with both players just inside the west door (x 24, y 416), full HP, the fight fresh in phase 1, bells and floor reset, the tick back to 0.7, intro short.

### 7.2 Foreshadow (texts and decor only; no map changes)

- **TB2 `mutex.c`:** its tick 0.7 (§4.5). Two bell sounds from the east, spatialized by height: silent at TB2's bottom, loud near its east door; they strike 0.05-0.15 s apart (never exactly together). A small window decor on TB2's east wall near the top of the climb (a few rows above the east door) shows the two silhouettes striking (looped, 2 frames), B8.
- **TB2 sign** next to the east door (add to TB2's `signs`): `- escapement.lock();  // slow. useless.` (the maintainer's voice: the line the user deleted; shown as a diff line).
- **T04:** the two background streaks (`decor.gd` ~184) change colours from orange/blue to red `#ff4a3a` / cyan `#2ee6d6`.

### 7.3 After the fight

- T06: the two automata frozen, bowing, face to face mid-floor (drawn by the hall from `boss:RACE`, no hurtbox); all bells hanging (fallen ones re-hung); the escapement with its red dot swinging on 0.8333; a soft tick per tower tick; warm light.
- Every tower room's tick 0.8333 (§4.5); T02/TA1 blink blocks solid (D40, already built: check it still triggers from `boss:RACE`).
- Logs, changelog section (`logs_view.gd`): `fix: restore escapement.lock() — threads take turns again.` after `boss:RACE`.

---

## 8. Tests

| test | where | what it must check |
|---|---|---|
| `race3` (new; replaces `raceboss`) | `godot/src/test/tests_5a.gd` (replace `t_raceboss` and `"raceboss"` in `NAMES5`, the `match`, and `tools/godot/test-all.sh`) | grows per milestone. M1: map and door rows, routes (§3.3) with and without bells 3/4, bell swing is a pure function (two computations agree), crack → fall → fallen → re-hang timings, at least 3 bells always hang, buffer paint/corrupt/hole timings and limits, per-room tick values and the T06 beat clock across a length change. M2: reads (stale vs prefetch on a moving and a still target), each phase-1 plan seen with its cue, hops, ring damage band, no contact damage from bodies, two bars math. M3: double write's three outcomes (stay 2 dmg, early leave = re-read and no clash, late leave = clash and both dazed 2.0 s), guard targets and ×0.8 (never on 2-dmg plans), lock serializes 3.0 s and clears the floor, cooldown 12 s, crack on a double strike on a bell. M4: phase-2 trigger both ways, transition invulnerable 2.0 s, `switch` tells 0.6 s, `drop` only while < 2 fallen and TOCK reachable after it, `triple` one beat apart, holes max 2 not neighbouring, alone ×0.85 and alone double, rewind 15 s / 2 s / cancel on damage / 30 %. M5: death timeline, pin, reward, flags. M6: loss menu both options; after-state |
| `bosspresets` | `tests_4b3.gd` | rows for every RaceBoss plan (2-damage cues >= 0.7 s, all cues >= 0.30 s after guard/alone multipliers) |
| `fightsim` | `tests_4b3.gd` | the mix per phase is not a fixed order and both automata act concurrently; phase lengths for a simulated good solo player: target **~70 s phase 1, ~80 s phase 2**. If far off, change `T` in `rooms.json` and write the new number here and in the Persian doc |
| `co-race` | `godot/src/test/coop_scenarios.gd` `sc_co_race` (rewrite; structure of `sc_co_crawler` / `sc_co_firewall`, `boss_arena("T06", ...)` with the new size) | both players are read (TICK one, TOCK the other), the guest rides swinging bells without falling through, the guest is hurt by rings it has seen, a double write on the guest resolves the same on both pages, the guest's hit on the bob serializes, phase 2 reached, a fallen bell matches on both pages; M6: `retry` brings both back. Also with `BADLINE_ALL=1` |
| `parity` | | after any net-field change |
| `tick5a`, tower route checks | | with the new per-room ticks (§4.5) |
| `arenas`, `gfxcontrast`, `moodshift`, `perfrooms` | | expected to need updates for the new T06: fix them properly |
| old tests reading the kit boss | `tests_5a.gd` (`t_raceboss` and the tower tests that read `RaceBoss`), `coop_scenarios.gd` | update to the new boss, keep what they test about other rooms |

Known failures that are not this boss's: `co-loopboss`, `co-shop` (timing; passes alone), `gfxother` (golden images not in the repo). Re-run once before calling anything else a flake.

**Screenshots** (look at them yourself; send the useful ones to Zakaria): a scene helper `race:<hp>:<x>:<y>[:<secs>]` in `main.gd` (copy `crawler:` ~262): `<hp>` the total HP fraction (1.0 phase 1, 0.4 phase 2, 0 with `<secs>` = the death scene at that second); `race_intro:<secs>`. Take: M1 the belfry phase 1 and phase 2 (hall stage set directly), the after-state; M2 intro at 1.0, 3.0, 5.0 s and each phase-1 tell; M3 a double write at its cue, a clash, serialized; M4 transition, `switch` tell, `drop` tell, two fallen bells as cover, holes, a rewind; M5 death at 1, 3, 5.5, 7 s; M6 the loss menu, the TB2 window and sign, T04 streaks. Command: `WAIT=N bash tools/godot/shot.sh out.png <scene> gfx=high`.

Last milestone: the whole `bash tools/godot/test-all.sh` (~25 min), then the web export into `public/mv` as its own last commit.

---

## 9. Milestones (one session each)

### M1 · Arena and the tower tick

1. `rooms.json` T06: size `[26, 30]`, origin `[1164, -166]`, `"hall": "belfry"`, doors `a: 23, b: 26`, boss `"cam": "free"`, `"trigger_x": 96` (check it is past the door). `world-phase45.json` T06 `y: -166, h: 30`. `rooms/T06.txt` exactly as §3.1.
2. `belfry_hall.gd` (§4.1-4.4): bells as platforms with swing, crack/fall/fallen/re-hang (callable from tests), buffer floor drawing and timings (the hazards come with the boss), escapement drawing states, backdrop node, after-state drawing (frozen pair) behind a flag.
3. `room.gd` hooks (hall creation, platforms skipped in `_move_platforms` and generic drawing, draw nodes, `step`), `room_view.gd` (back wall from the hall), `room_lights.gd` / `look.gd` per phase.
4. Per-room tick (§4.5) including T06's beat clock; run `tick5a` and the tower checks for T01/T02/TB2 and write the results in the M1 notes (send problems to the world inbox).
5. Screenshot helper `race:` with the boss inert.
6. Tests: `race3` (M1 part), `arenas`, `gfxcontrast`, map tests, `tick5a`, `perfrooms` before/after.
7. Commit: `RACE CONDITION M1: the belfry (T06 26x30), bells as platforms, the escapement, a tick per tower room`.

### M2 · The automata and phase 1 singles

1. Rewrite `race_boss.gd` (§5.1-5.5 without `double`, §5.11 for the fields so far, `hud_bar`, `music_now` placeholders). Bodies drawn after `17-race-data/ref/tick_tock.webp` and `sheet_keys.webp` at 32 × 48: dark bronze with gold rivets and edges, thin red (TICK) / cyan (TOCK) trim, TOCK's cyan headband and curly bronze beard, torn tan sheepskin skirt, big wind-up key on the back, a small clock on the chest. Frames: idle, crouch, hop, hammer up, strike (bowing at the waist), stuck, dazed, down, kneel. Phase-2 look (hot red bronze, springs) can be added here or in M4.
2. Intro (§5.4) without the voice (subtitle text only).
3. Tests: `race3` (M2), `bosspresets`, `fightsim` (phase 1 singles), `parity`, `co-race` (phase 1) with and without `BADLINE_ALL=1`. Screenshots.
4. Commit: `RACE CONDITION M2: TICK and TOCK, reading the past and the future`.

### M3 · Double write, guard, the lock, the buffer, cracks

1. `double` (§5.5), guard (§5.3), the escapement lock (§5.6), buffer corruption hazards (§4.3 phase 1), bell crack/fall/re-hang from strikes (§4.2), player-rings-a-bell interrupt.
2. Tests: `race3` (M3), `fightsim`, `co-race` (double write on the guest, the guest's bob hit). Screenshots.
3. Commit: `RACE CONDITION M3: the double write, the clash, the escapement`.

### M4 · Phase 2, alone, rewind

1. §5.7, §5.8, §5.9, holes (§4.3 phase 2), fallen bells as cover, hot look.
2. Tests: `race3` (M4), `fightsim` (phase 2), `co-race` (phase 2, a fallen bell on both pages). `perfrooms`. Screenshots.
3. Commit: `RACE CONDITION M4: context switches, falling bells, a partner rewound`.

### M5 · Death, voices, subtitles, sounds, music, logs

1. §5.10, §6 (script `--line`, files, JSON with word times, CREDITS, `Audio.VOICE`, interleaved subtitles), sounds, §5.12 (placeholders unless Zakaria answered §11.1), §7.3 Logs line.
2. `--import`; commit the `.import` files; keep files small.
3. Tests: `race3` (M5), `logs`. Screenshots: death at 1, 3, 5.5, 7 s; the interleaved intro subtitle.
4. Commit: `RACE CONDITION M5: After you. No... after you.`

### M6 · Loss menu, foreshadow, after-state, full tests, export

1. §7.1 (generalized menu), §7.2, §7.3.
2. Fix every test that changed because of the new boss (§8, last rows). Full `bash tools/godot/test-all.sh`. Web export to `public/mv` as its **own last commit**.
3. Commits: `RACE CONDITION M6: retry, the bells through the wall, a steady tower`, then `Web export: RACE CONDITION`.
4. Studio duties: tick RACE CONDITION on `docs/studio/PRODUCER.md`; playtest steps (Persian, short) into «منتظر تست» of `docs/studio/PLAYTEST.md`. Report to Zakaria in Persian; ask before anything goes to `main`.

---

## 10. Do not

- Draw warnings on screen (hatched boxes, `!`, target markers) or HUD text announcing an attack. The READ afterimage is light from the eye, nothing else.
- Give more stuns than §5: the only big punish is the clash (2.0 s); stuck hammer 0.5 s, caught clapper 0.7 s, `drop` 0.8 s, `triple` 0.8 s; a rung bell only cancels a cue.
- Let both automata take turns outside the serialized lock: they act concurrently.
- Let fewer than 3 bells hang, or two neighbouring holes, or more than 2 holes.
- Redraw TB2, TC2, T04 or any other room's map (texts, decor and ticks in §4.5 and §7.2 only).
- Add a bench (decided: `retry` is enough).
- Use any voice except `northern_english_male`; change the dialogue.
- Hurt or move the guest's body from the host except through hazards/harmboxes, `room.harm_zone` and the existing revive/respawn/retry events.
- Walk `Game.flags` per frame; draw static things every frame.
- Skip, disable or weaken a test; push an empty commit; merge into `main`.

---

## 11. Open questions (for Zakaria, before or during the build)

1. **Music.** Placeholders `boss` (phase 1) / `boss_hi` (phase 2), or the tower theme `w4` made faster with ffmpeg (`atempo`, pitch kept) for both phases (~171 / 200 bpm, the tick motif)? And the tower floors (T01/T02 slower, TB2 faster): tempo variants of `w4` (two more small files) or keep `w4` as is?
2. **`drop` fix:** TOCK rides the falling bell down and is stuck 0.8 s on the floor (instead of on the unreachable beam).
