# 18b · INFINITE LOOP v3: build plan (for the builder)

> **STATUS: APPROVED (2026-11-15).** Zakaria approved every step of the design ([`18-loop.md`](18-loop.md)) as drafted and asked for the whole boss to be built in one session, M1 to M6, without asking him: the builder answers the open questions (§10) itself and lists its choices in "Decisions taken by the builder" below and in the producer's inbox. The speed session (brief 05) changed the tower and the boss files (report: `docs/reports/perf-2026-11-01.md`, speed rules in `CLAUDE.md`).

This is the build plan for INFINITE LOOP v3, for the model that builds it (skill `boss-build`). The Persian doc is the source of truth for **what the player sees and hears**; this file is the source of truth for **how to build it**. If they disagree, the Persian doc wins and you ask Zakaria.

Read before every session: this file, [`15-boss-process.md`](15-boss-process.md) sections 3-5, [`07-js-vs-godot.md`](07-js-vs-godot.md) §3, `CLAUDE.md`, and the RACE CONDITION build notes ([`17-race-build.md`](17-race-build.md), "Milestone notes": the two-plan, retry-menu, per-room tick and route-check work there is reused here). Reference builds: CRAWLER OF THE WEB (`crawler_boss.gd`: the compact scene `_compact`, `draw_hud`, the phase scenes), THE FIREWALL (`honeypot_hall.gd`: moving platforms owned by a hall), RACE CONDITION (`belfry_hall.gd`, `race_boss.gd`: the generalized loss menu in `Boss`, the hall-owned tiles that change per phase).

**Sketches:** [`18-loop-data/loop_body.png`](18-loop-data/loop_body.png) (body, poses, palette), [`18-loop-data/loop_arena.png`](18-loop-data/loop_arena.png) (the three phases), made by `18-loop-data/sketch.py` (its constants `ONEWAY`, `GANTRY`, `GEARS`, `RINGS`, `PIT` are the geometry below). **If Zakaria gives pixel art of the snake, that art is the sprite** (cut it into the head directions, jaw states, plate states and link colours listed in the Persian doc, step 2); the sketch is then only a layout reference.

The old boss (`godot/src/enemies/loop_boss.gd`, kit-era, MV5A-07) is replaced. Keep the class name `LoopBoss` and its `NetClasses` number (47). Remove its horizontal wrap special case in `room.gd` (`fight_active ... "LoopBoss"`, near line 799) when the new vertical wrap lands.

---

## 0. How to work

- **One milestone per session** (this time all six in one session, Zakaria's call 2026-11-15). Find the first milestone below whose status is not `done`, build it, test it, commit, push to `ph1`, mark it `done` (with anything that changed), report to Zakaria **in Persian**, short.
- Start: `git fetch origin ph1 && git checkout ph1 && git pull origin ph1`. `npm ci` if `node_modules` is missing. `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`.
- **Ask, don't guess**, when something the player sees or hears is not decided here or in the Persian doc. Internal choices are yours.
- Never invent dialogue: all lines are in §6. Never merge into `main`. Never skip, disable or loosen a test to get green.

| milestone | what | status |
|---|---|---|
| M1 | arena: T10 24x32 (up only), the shaft hall (ledges, gears, rings, gantry, counter wall), per-phase room states incl. the phase-3 pit and vertical wrap, camera, route check | **done** (2026-11-15) |
| M2 | the snake body (head + 14 links, trail following), swim, phase-1 attacks, contact damage, tail hits, the fake-loop intro, HP bar | **done** (2026-11-15) |
| M3 | the condition plate: breakpoint freeze (links become platforms), half hits, the yellow ring catch, the break window, `i++` escalation | **done** (2026-11-15) |
| M4 | phase 2 (transition, nested ring layer, recursion, escalate, gantry swing, gear reversal) and phase 3 (transition, pit + ceiling seam, wrap dive, combos, feints, HP = length) | **done** (2026-11-15) |
| M5 | death + compact scene (looping progress bar, echo `stop`), voices and subtitles, sounds, music (phase-3 stutter), logs lines | **done** (2026-11-15/19) |
| M6 | loss menu with the counter, the diff sign, after-state, T09 decor only if the world dept approved it, full tests, web export | **done** (2026-11-19) |

---

## Decisions taken by the builder (2026-11-15; Zakaria said: decide, write it down, do not ask)

Each one is also in the producer's inbox (`docs/studio/PRODUCER.md`), so he can change it.

| # | question | choice | why |
|---|---|---|---|
| D1 | The engine's `BREAK 3.5` text over a frozen creature (§10.1) | kept on the snake | it is the ability's own UI everywhere in the game, not an attack warning (the plan's recommendation) |
| D2 | Voice takes before wiring (§10.2) | three takes per line made with Piper, the builder picked the best and wired it; the other takes are not shipped | Zakaria: "make three takes and pick the best yourself" |
| D3 | Head directions (§10.3) | 8 directions made by the sprite script from the right-facing head (mirror + 45-degree turns at x3, read back per 3x3 block) | the sketch has one direction; a redraw only needs the right-facing poses |
| D4 | `...again.` on the first break | subtitle only, no voice | the plan allows it; a one-word line over a punish window is clearer as text |

## Milestone notes

**M1 (done, 2026-11-15).** `loop_hall.gd` (the shaft), `rooms/T10.txt` (24 x 32), rooms.json and world-phase45.json (origin y -232, h 32, doors rows 25..28, `hall: loop`, `cam: free`), `loop3` (M1 part) replaces the old `loopboss` test, `co-loopboss` rewritten (M1: the guest sees the floor crack and open, falls through the pit, comes back in at the top and lands, with and without `BADLINE_ALL=1`), screenshot scene `loopfight:<p1|p2|p3>[:<x>:<y>]`. The old kit boss is gone: `loop_boss.gd` is an inert stub until M2 (it carries the hall's state to the guest).
- **Map file:** M, L2, R2 and TOP are `=` tiles in `T10.txt` (they never change; `check5a.py` sees them); L1 / R1, the gear teeth, the gantry and the pit belong to the hall. The GET rings are `@` at (6, 7) / (17, 7).
- **Gears:** four teeth (32 px platforms) on a 2-tile radius, one 45-degree step per tower tick (the tower's own easing). The direction flip (`flip_gears`) keeps the teeth where they are (state: `gear_dir`, `gear_s0`, `gear_k0`).
- **Gantry:** a 128 px one-way platform on two 48 px chains from row 1; phase 2+ it swings 32 px each way (period 4 ticks, eased in over 1 s), staying level and rising a little at the ends. It is drawn once in its own node; the swing only moves the node.
- **Low ledges:** phase 2 they go one column per 0.2 s from the room side into the wall; phase 3 they come back the same way from the start of the transition.
- **Pit:** the floor's cracks glow 0.8 s (no damage), then columns 6..17 of rows 29..31 and row 0 open; `TileGrid.seam_a/b` makes the cells above the ceiling open there. A body whose centre passes y 512 inside the pit columns comes back in at y = -h with its fall speed capped (330); each page moves its own body; the camera cuts (moved by the same amount), no pan.
- **Fake loop:** the hall arms it when `intro:LOOP` is not set; the east door is an open portal (`fightwrap`); a body past x 368 (352 for the partner seen late on the host) or 8 s in the room: everybody back at the west door (x 24, feet on the floor, facing east), a 0.35 s flash, the counter 4095 -> 4096, the flag, the intro. The guest moves itself when `wrap_n` changes. `trigger_x` is ignored while it is armed.
- **Routes checked (real physics):** floor -> L1 / R1, L1 / R1 -> M, M -> each gear's side tooth, gear -> L2 / R2, L2 / R2 -> TOP, TOP -> gantry (sudo or curl), phase 3 floor sides -> L1 / R1 -> M, a fall through the pit lands on the gantry. **All of them without sudo** (an earlier run said gear -> L2 / R2 needed it: the room's trigger had started the fight in the middle of the check; fixed in M6); nothing needed a ledge moved.
- **Back wall** drawn once (riveted panels, pipes, the counter, the diff sign in the normal font: the tiny font has no lower case); the phase washes are a `modulate` of that node (no redraw). Speed: `perfrooms` T10 0.67 ms (T06 0.93).
- **Sprites:** `tools/godot/loop_sprites.py` cuts the snake from `18-loop-data/loop_body.png` (heads in 8 directions, links, plates); used from M2. To use a drawing of Zakaria's: replace the image (or `--src`), fix `HEAD_CUTS` / `LINK_CUTS`, run the script, `--import`.

**M2 (done, 2026-11-15).** `loop_boss.gd` rewritten: the body (head + 14 links on the head's own path), swimming, the phase-1 plans (`lunge`, `dive`, `coil`, `spit`, the first cycle's calm coil), touch damage, the tail, the intro, the HP bar. `loop3` M2 part, `bosspresets` rows (`lunge` 0.75 s / 2 damage, `dive` 0.5, `coil` 1.0, `spit` 0.5), `co-loopboss` (phase 1 on both pages: 18 plans, 9 on each player, the guest sees every cue, its tail hits reach the host; then the pit; with and without `BADLINE_ALL=1`), screenshot scenes `loop_intro`, `looptell:<id>[:<x>:<y>]`.
- **The body is the sketch's pixel art** (`loop_head.png`, `loop_links.png`, `loop_plate.png`): 15 textured quads and 14 two-pixel pins a frame. The plate is drawn upright on the brow whichever way the head points.
- **Net:** the snapshot carries the head (x4), its angle and the 14 link centres (x2, 28 ints), the plan, its geometry (lunge direction and length, dive column, coil centre) and the hall; the guest interpolates the head and every link between snapshots (`net_sample` / `puppet_follow_parts`), so its touch and plan boxes are the host's (checked in `loop3`).
- **Swim (decided):** round its target on a flattened circle of ~110 px (the target's head height and above), at most 140 deg/s, kept 40 px off the walls. Between plans it goes after the next plan's target (`kit_pick_target`, alternating in co-op).
- **Plans (decided where the plan was silent):** the lunge's cue turns the head to the locked direction and draws it back 14 px/s (the S-coil reads from the body following); a lunge that stops short of 160 px (a wall, the floor, a ledge on the way down) leaves the head stuck 0.6 s. The dive first goes up over the target's column during its cue (at 420 px/s, then points down) and falls to the first solid or one-way surface (a ledge stops it too: stuck 0.8 s there). The coil circles the target closing from 64 to 40 px in the cue, squeezes to 26 in its 0.5 s; the hurt is the body's own touch. The spit's three rings fly at 110 px/s in a 0.28 rad fan, each swinging round a 12 px circle (the host turns their velocity; the guest flies the snapshot's), the middle one yellow and catchable. The calm coil (first cycle) circles 44 px round a point over the low ledge away from its target for 1.5 s.
- **Intro:** first time 3.0 s of descent (straight down at x 228, then once round the gantry clockwise until the head meets its tail), `click`, the line from 3.2 s, the intro lasts as long as the line (`intro_len` = 3.6 s + the line); the camera looks up at the gantry and comes back down 0.7 s before the fight. Second time (`intro:LOOP_SEEN`) 2.0 s (1.6 s descent, no line). Before the first fight the fake loop (M1) runs; `intro:LOOP` is that flag.
- **Hits:** the tail tip full damage and a flick (a player next to it is pushed 80 px/s); the head and the middle links clang (`block`) until M3's plate rules.
- **Attack mix** (loop3, a bot moving slowly on the floor, 70 s): spit 6, lunge 7, dive 9, coil 12, calm 1, no repeats. The HP (`T`) is tuned with `fightsim` in M4 once the break window exists.

**M3 (done, 2026-11-15).** The condition plate, breakpoint, the half hits, the yellow ring, the break window, `i++`. `loop3` M3 part (the freeze and its platforms on both pages, a player standing on a frozen link, the plate rules, the window, the 4 s rest with its shiver, no freeze in an active part, the gears' flip in phase 2), `breakpoint` still green, `co-loopboss` (the guest freezes the snake with its own breakpoint, claws the plate and breaks the condition on the host; with and without `BADLINE_ALL=1`), screenshot moments `looptell:frozen`, `looptell:break`.
- **Engine hooks (scoped to the snake):** `Room._rebuild_bp_plats` asks a creature with `bp_plats()` for its platforms (the snake: the top 4 px of every link and of the head); `Room.bp_apply` asks `bp_refused()` before it freezes (the snake while it rests: the clang `loop_bpclang` and a blue shiver, nothing stops). The snake sets `bp` (the room's "may be stopped" flag) every frame on both pages: swimming, in a cue or recovery, stuck; never in an active part, lying, recoiling or in a scene.
- **The plate is the head's hurt box** (grown 8 px up over the plate): hits on the head count as hits on the plate (a guest's hit is given to the nearest hurt box, and the plate sits on the head). Frozen: one hit breaks it. Stuck (after a lunge or a dive) or a caught yellow ring: a half hit (`tru_` flickers at 8 Hz, no damage); a second within 3.0 s breaks it. Otherwise the head clangs.
- **The break:** the freeze ends at once (`bp_t = 0`), the plate `false`, the eye crossed; the body lies straight along the surface under its head, toward the middle of the room (a link past a ledge's end drops to the next surface: on the M ledge the chain drapes down to the floor), 2.0 / 1.8 / 1.6 s of full damage on every link and the head, no touch; then a 0.5 s recoil (invulnerable, `click`), `i++`: the wall counter +1, 6 % faster (`_speed`), in phase 2 the gears turn the other way. The first break shows `...again.` (subtitle, no voice: decision D4).
- **The rest after a freeze** (4 s; 6 s in phase 3) starts when a freeze ends, by time or by a break (a break's window and recoil take 2.5 s of it).

**M4 (done, 2026-11-15).** Phase 2 and phase 3. `loop3` M4 part (both changes, the first cycles, escalate's two parts, recursion's copy, the nested ring's orbit / spin-up / crossing / drop, the wrap dive onto the gantry, the feint, hp = length, the guest's copy of the ring and the copy), `bosspresets` rows (`recursion`, `escalate`, `esc2`, `wrap_dive`), `fightsim` (`BOSS=T10`, two bots), `perffight`, `fightbench`, `co-loopboss` (the host's real change to phase 3: the guest sees the cracks, falls through the pit, wraps and lands; with and without `BADLINE_ALL=1`; `parity` green), screenshot scenes `loopfight:p2|p3` (the boss's `force_phase`), `looptell:<id>:<x>:<y>:<phase>`.
- **The changes:** at 66 % / 33 % (`_begin_phase`; the name `_begin_trans` is RACE's and `perffight` calls it without arguments) the boss's phase and the hall's change at once; 2.0 s / 2.5 s of circling (violet / hot), invulnerable, no touch. Phase 2: the hall's ledges retract, the gantry swings, the gears flip at each `i++`, the nested ring starts round the gear on the snake's side. Phase 3: the floor cracks 0.8 s and opens, the ceiling seam, the ledges come back, the ring is gone, the plate cracked. First cycles: `recursion`, `escalate` / `wrap_dive`, `lunge`.
- **Nested ring (decided):** 6 small violet links in a 14 px ring whose centre goes round a gear at 54 px (1.1 rad/s) for 5.4 s, spins up 0.6 s (faster, flashing; its jingle), then crosses over M in an arc (1.2 s, 70 px high) to the other gear: a 7.2 s cycle, a pure function of `nest_base` / `nest_g0` and the room's clock. 1 damage per link. A break drops it on the floor under where it was for 4 s (harmless), then it starts again round the gear it fell from.
- **Recursion:** the copy (head + 4 links, faded violet) replays the head's last 2.0 s (21 points, 0.1 s apart), 1 damage, harmless in its last 0.3 s (fading). Phase 3's `coil + recursion` combo makes a copy at the coil's squeeze.
- **Escalate:** a lunge (0.7 s cue with the body flashing violet, 2 damage, no stuck), then `esc2` at once: aimed again, 0.45 s cue, 1 damage, the head stuck 0.8 s after it. One 2-damage box at most at any time (checked).
- **Wrap dive:** 0.75 s cue: the head sinks into the pit at whatever speed reaches it in the cue, comes in at the top seam over the target's column (a falling player is preferred, and its fall is led 0.3 s) and waits there, links showing in the seam; then straight down at 480 px/s, 2 damage; the gantry (where it is now), TOP, M or the floor beside the pit stops it (stuck 0.6 s); through the pit it wraps on. The body's path jumps at the wrap (no pins across the room; the guest does not slide its links across either).
- **Phase 3 combos and feints (decided rates):** a lunge is followed at once by a dive 35 % of the time; a lunge or wrap dive without a combo holds 0.25 s more after its full cue 35 % of the time. **HP = length:** a link falls off at every 1/8 of phase 3's hp (the eighth goes with the killing hit), they lie on the floor (no collision).
- **HP (calibrated):** `T` 140 -> **240** (144 hp at normal). `fightsim BOSS=T10`: the breakpoint bot **46 / 51 / 60 s** per phase (157 s; the plan's target ~50 / 55 / 60), the bot that never freezes it **176 s** (< 2x: beatable without breakpoint). The bots take no damage: the floor of the fight's length.
- **Speed:** `perffight` (CPU per frame, two players) T10 **1.03 / 1.13 ms** (logic 0.53 / 0.59) against RACE's T06 1.13 / 1.27 (0.46 / 0.52); `fightbench` (xvfb, a real renderer, 900 frames) T10 median **10.5 ms**, p99 14.5-15.5, 58 draw calls, against T06 11.5 / 16.5 / 86. One long frame (133-284 ms) once per run in T10's phase 1 (T06 had one too in the speed report); not found yet.

**M5 (done).** The death and the compact scene, the five voiced lines, eight sounds, the phase-3 music, the Logs lines. `loop3` M5 part (voices registered and their words in the subtitle's order, sounds registered, the death: the pit's floor slides back, it lies on the floor, no harm, silence, it waits for a player at its head, the meter's 60 / 85 / 100 %, the compaction bar to 90 % then back to 0 then all the way, the flags, the reward), `logs`, `co-loopboss` (the host kills it; the guest page sees it lie, speak and compact, standing at its head; with and without `BADLINE_ALL=1`), screenshot scene `loopdie:<secs>`.
- **Voices (decision D2):** `tools/voice/loop_voice.py` made three takes of every line (a: pitch x0.90, length x1.25, a brass ring; b: x0.86, x1.38, a long shaft echo; c: x0.93, x1.15, dry); a speech recognizer listened to all fifteen: **take a** was heard right on `p2`, `p3`, `die` and `compact` and nearly on `intro` (b was misheard most: "Lieutenant 4096", "Pray, stay a minute"; c: "Great segment", "ten someone said"). One take for all lines, so the voice stays the same. Each line's last word comes back once, quieter and darker, 0.35 s after it (`new.`, `escalating.`, `cheap.`, `reached.`, `stop?`). Two lines needed their text changed for Piper (the subtitles are unchanged): `p2` is said as "Re-trying, escalating." twice (alone, Piper says "Retrain" / "Estulating"), `die` as one slow phrase "Break, statement, reached." (alone, "statement" came out as noise). `...again.` stays a subtitle only (D4). Word times: the recognizer (`asr`) for p2, p3, die; spread over the letters (`est`) for intro and compact (it writes "4096" and splits the sentences differently).
- **Sounds** (`tools/godot/sfx/make_loop_sfx.py`, ~0.55 MB): `loop_chain` (the descent, a dive), `loop_click` (it bites its tail: the intro, a recoil, the phase changes, the death), `loop_clack` (a half hit, the break), `loop_collapse` (the break, the death), `loop_bpclang` (breakpoint while it rests), `loop_jingle` (the nested ring's spin-up), `loop_crack` (phase 3's floor), `loop_seam` (the wrap dive in the ceiling seam). Not made: a chain tick per link that follows its speed (a looping sound per frame; left for the polish pass), the tower tick speeding up with `i++` (cosmetic; the room's own tick plays).
- **Music:** phase 1 `boss` (with the room's tower tick), phase 2 `boss_hi`, phase 3 `loop_stutter` (`tools/godot/make-loop-stutter.sh`: the boss track's 24 bars of 1.5 s with the 8th bar of every 8 played twice, 40.5 s, 280 KB), the death: silence.
- **The death (~23 s):** it lets go and lies straight along the floor (the pit's floor slides back first, 0.4 s, and a body inside it is lifted onto it), plate `false`, eye crossed; from 3.0 s it waits (at most 8 s) for a player within 90 px of its head; `die` (subtitle word by word), 0.8 s, the memorable line in the terminal box word by word (the meter 60 % after "works.", 85 % after "you.", red and full on "Who decides when you stop?"), 0.8 s of black, the compaction (6.0 s; the night scrolls with its line in the middle; the bar runs to 90 %, snaps back to 0 and runs again), the summary (`INFINITE LOOP defeated. opus obtained.` / `Continue mission.`) with `stop` fading in the corner for 1 s, then the opus banner. Flags `compacted:LOOP` and `loop:final:<counter>` (the counter of the after-state).
- **Logs:** `INFINITE LOOP: [compacted]` (grey) and the changelog line `fix: restore the retry limit — attempt < 3. the loop may stop now.` (after `boss:LOOP`).
- `coop-test.sh`: the per-process timeout is 180 s (was 150): `co-loopboss` now runs the whole fight and the 22 s death scene on a bad line.

**M6 (code done, 2026-11-19).** The loss menu with the counter, the after-state, T09's chain, the studio docs. `loop3` M6 part (the menu opens instead of the restart, no harm behind it, `retry` raises the counter by one on both pages, the after-state: the snake lying, the counter frozen, no fight, no pit, the east door open, the steady tick; T09's decor), screenshot scene `loopafter`.
- **Retry:** `Boss`'s generalized menu (`has_retry`, spot x 24 feet on the floor, verdigris colours, `loop_click`); `Main._loss_choose` calls the boss's `on_retry` first: `Game.loop_tries` +1 (this session), and the hall's counter on load is 4096 + tries (+ the breaks of the fight). Not saved: a new session starts at 4096 again.
- **After:** `boss:LOOP` -> the hall draws the open snake on the floor once, in the back-wall node (no collision, no per-frame cost), plate `false`, eye crossed; the counter shows `loop:final:<n>` (set at the kill). The diff sign is drawn since M1.
- **T09's chain (the world department said yes, its inbox 2026-11-01):** a `window` decor 12 x 1 tiles at (16, 1) with `shadow: loop` and `if: !boss:LOOP`; in passes 2 and 3 (`iter` 1 and 2) a verdigris chain slides west behind it in a 24 s cycle and clatters (a local `loop_chain` three times a second while it passes). T09's map is unchanged.
- **Full `test-all.sh` (2026-11-19, on `763818d`):** green except `gfxcontrast` (`N15 phase3 cap rows 0.39`: the known old failure, not this boss), `co-race` (the guest made 0 swings once; **passed on its rerun**) and `mv-title` (a different item failed each time: "join by code / host saw guest", then "new game after a failed join"; **passed on the third run, failed on the fourth**: flaky, as in RACE's M6 notes; the export's pck grew 11.21 -> 11.87 MB with LOOP's voices, sounds and music, which may make the page's start a little slower). Every `loop3` part, `co-loopboss`, `bosspresets`, `parity`, `breakpoint`, `logs`, the parity tapes and the room checkers passed. Web export: its own last commit.
- **`loop3` is fast now** (~10 s with the route checks; `test-all` gives each test 180 s): the route search tries the likeliest jumps first and gives up on a try that landed short; the route room holds its fight off (`fight_hold`).

---

## 1. The fight in one page

An old retry worker of the tower's scheduler (`for (attempt = 0; attempt < 3; attempt++)`) became `while (true)  // retries are cheap` in the user's refactor. When RACE CONDITION lost the clock's beats it started retrying, and it can never stop. It escalates with every failure, which is why it holds **opus**. It is a long verdigris brass-chain snake that bites its own tail (an ouroboros) with a condition plate `true` on its brow and a dial eye.

1. **Intro (fake loop).** The room is empty, counter `i = 4095`. Leave by the east door and you come back in by the west door; counter `4096`. The chain comes down from the dark top of the shaft, coils on the gantry, bites its tail. `Attempt four thousand and ninety-six. ... You are new. Every attempt is new.`
2. **Phase 1.** It swims after you (limited turn rate), lunges (2 dmg), dives, coils around campers, spits three brass rings (one yellow: catch it and throw it at the plate).
3. **The signature: break the condition.** Freeze it with **breakpoint**: the whole body hangs still and its links are one-way platforms. Run up the body and hit the plate: `true` becomes `false`, the loop breaks and the snake lies on the floor: the big punish window. Without breakpoint: two hits on the plate while its head is stuck after a lunge or dive, or the yellow ring. Afterwards it bites its tail again, `i++`, 6 % faster.
4. **Phase 2 (66 %), "Escalating".** Violet. A nested ring of 6 links orbits a gear and crosses the room. Recursion copies, double lunges. The low ledges retract, the gantry swings, the gears reverse every iteration.
5. **Phase 3 (33 %), "retries are cheap".** The middle of the floor and the ceiling open: vertical wrap (falling is not damage, you come back in at the top). Wrap dives from the ceiling, combos, feints, and it gets shorter as it loses HP.
6. **Death.** It lets go of its tail and lies open. `Break... statement... reached.` Then the compact scene with the memorable line; the progress bar loops once; the word `stop` stays a moment. opus.
7. **Loss.** `retry` / `back to last commit`; `retry` raises the counter by one.
8. **After.** The snake lies open on the floor forever, plate `false`, the counter frozen.

---

## 2. Rules that must hold

- **No on-screen warnings.** No `draw_plan()`, `warn_col()`, `_target_marker()`. Tells are the body (S-coil, open jaw, lit dial eye and plate, puffed cheeks, clattering links, violet flash), sound, and the room (the seam lights up, the floor cracks glow). The plate text and the wall counter are part of the body / room, never a warning.
- Arena hazards (`hz_add`) need a visible build-up >= 0.6 s (`HZ_WARN_MIN`); the guest is only hurt by hazards it has seen for `HZ_SEEN_MIN` (0.5 s).
- A 2-damage hit needs a cue >= 0.7 s (`bosspresets`). Every cue >= 0.30 s as seen on the guest (watchdog `boss-cue`). Feints only **add** waiting time after a full cue.
- **Body contact hurts** (1 + knock-back) except while broken (on the floor), frozen by breakpoint, in the intro, a phase transition or the death scene.
- Weighted choice by distance, height, stillness and phase; never the same attack twice in a row; the first cycle of each phase is fixed (§5.4).
- **Dangers at once:** one main plan + the phase pressure layer (phase 2: the nested ring; phase 3: the seam) + rings in flight + the body. Never two 2-damage plans live at once.
- **Beatable with what the player surely has:** bash, catch, jump, wall jump, sudo, curl, **breakpoint** (TC2 cannot be passed without it). **Not opus** (it is the reward). Also beatable if breakpoint is never used (the half-hit route) — check in `fightsim` with a bot that never freezes.
- **Co-op:** the host owns the snake and the hall. The guest builds the body from the head path (net fields: head x/y/angle samples, see §5.9), the plate state, freeze state, phase, iteration. Damage to P2 only through plan harm boxes / hazards / `room.harm_zone`. State over events.
- **Speed (brief 05, Zakaria's frame drops in the tower):** the back wall, counter digits, gantry text, ledges and gear bodies are drawn once in their own node; per frame only the snake (15 sprites), the gear teeth and the nested ring move. No per-frame particles beyond the existing hit sparks. Nothing per frame walks `Game.flags`. `--test=perfrooms` before and after M1 and M4; the fight must not cost more than RACE's in `perfrooms`.
- **Scope:** T10 and the boss's files, plus the hooks listed per milestone. Do not redraw any other room's map. T09 decor only after the world department says yes (its inbox).
- Voice: only `en_GB-northern_english_male-medium` (CC BY-SA 4.0). Never `alan` or `ryan`.

---

## 3. Geometry (tiles are 16 px; x right, y down; row 0 is the ceiling)

Room T10: **24 × 32 tiles** (384 × 512 px). Grows **up only**: origin `[1230, -214]` → **`[1230, -232]`** in `godot/src/world/rooms.json` and `docs/metroidvania/world-phase45.json` (`y: -232, h: 32`). Checked 2026-11-01: columns 1230..1254 are free above -214 (no room in the whole map starts above -232); T09 (west) and T11 (east) keep their rows. Doors keep their world rows -207..-204 = room rows **25..28**; floor rows **29..31** (the old rows 11..13). Door ids, targets and locks unchanged (`T10:W` `fight`, `T10:E` `until:boss:LOOP`); update `a`/`b` to 25/28. Tell the world inbox (done by the design session, 2026-11-01).

### 3.1 Map `godot/src/world/rooms/T10.txt` (phase-1 solid tiles only; everything else belongs to the hall)

- Row 0: ceiling `#` across. Columns 0 and 23: wall `#` except rows 25..28 (doors). Rows 29..31: floor `#` across.
- Phase-3 pit and seam: columns **6..17** of row 0 and rows 29..31 are removed by the hall (`apply`, both pages), never by the map file.

### 3.2 Hall-owned pieces (`ONEWAY` etc. in the sketch script; tile coordinates, inclusive)

| piece | where | notes |
|---|---|---|
| L1 / R1 low ledges | row 25, cols 3..5 / 18..20, one-way | phase 2: slide into the walls over 0.6 s (visible); phase 3: back |
| M middle ledge | row 21, cols 9..14, one-way | |
| gears GL / GR | centres (5, 18) / (18, 18), radius 2 tiles | the tower's tick gear (as in TC1; reuse `tower.gd` gear code): the top tooth is a platform, one step per tower tick; clockwise; phase 2 the direction flips at every `i++` |
| L2 / R2 | row 13, cols 2..5 / 18..21, one-way | |
| TOP | row 9, cols 10..13, one-way | |
| GET rings | (6, 7), (17, 7) | curl |
| gantry `while (true) {` | row 4, cols 8..15, one-way | phase 2+: hangs on two chains from row 1 and swings ±2 tiles, period 4 tower ticks, a pure function of `room.time` |
| counter wall | back wall, centre | `i = <n>`, drawn once per change |
| diff sign | inside, right of the west door | `- for (attempt = 0; attempt < 3; attempt++)` / `+ while (true)  // retries are cheap` |

### 3.3 Routes (check with the real `step_keys` physics in `loop3`, M1)

Floor → L1/R1 (4 up), L1/R1 → M, M → gears' top tooth (at its highest), gears → L2/R2, L2/R2 → TOP, TOP → a GET ring (curl) → gantry. Each with jump + dash and with sudo; record which need sudo. Phase 3: each floor side → L1/R1 → M without touching the pit; a fall through the pit lands on the gantry if x is in cols 8..15 (else falls again). Shift a ledge by ±1 tile if a route fails, and note it.

### 3.4 Vertical wrap (phase 3 only)

A body (player or snake) whose centre crosses y > 512 inside cols 6..17 comes out at y = −h (top seam), same x and vx, vy capped at the fall cap. Each page moves its own player (as the old horizontal wrap). Falling through is never damage. Camera: when the followed player wraps, the free camera **cuts** to the new place (no pan across the room). Out of the fight there is no wrap and no pit.

### 3.5 Camera

`"cam": "free"`, leaning toward the head (weight ×2 in a cue). Intro: scripted (§5.2).

---

## 4. The hall: `godot/src/world/loop_hall.gd` (new)

- **State (host writes, guest reads from the boss's net fields):** `phase`, `iter`, `ledges_in_t` (phase 2 retract time), `pit_t` (phase 3 open time), `gear_dir` (from `iter`), `intro_wrap_done`, `counter`.
- `apply(room)`: writes the phase's tiles (pit, seam, ledges) on both pages from state; idempotent.
- Draw: static node (wall, counter, sign, gantry text, ledges, gear bodies) redrawn only on state change; dynamic: gear teeth, gantry swing, seam light (a faint white band at the top and bottom seam in phase 3), floor cracks in the phase-3 build-up.
- Lights: T10 is a world-4 room (no `Look` / `room_lights`, as RACE found); the hall draws its own glow: warm (phase 1), violet wash from the snake (phase 2, 0.15 alpha), darker red (phase 3, but ledges and seam stay lit; check `gfxcontrast` anyway).

---

## 5. The boss: `godot/src/enemies/loop_boss.gd` (rewrite)

### 5.1 Body

- Head 40 × 32, 14 links 16 × 16 at **14 px** spacing along the head's path (a trail buffer of head positions; link k sits at arc length `24 + 14 k` behind the head). The head sprite is drawn in 8 directions (snapped to 45°, never freely rotated).
- Hurtboxes: head (plate = top 18 × 8 of the head), tail tip (last link), each link (blocks outside the break window).
- Contact boxes: head + every link (§2 rule).
- Phase 3: links shed at every 1/8 of phase-3 HP lost (14 → 6); a shed link drops to the floor as a dead prop (no collision).

### 5.2 Intro (first time ~10 s, mostly player-driven; from the second time and after `retry` 2.0 s)

1. Fight trigger as the player enters. West door open, east door drawn **open** (the hall shows it open; it is the fake loop), counter 4095, tower tick audible.
2. Any player whose centre crosses x > 368 (or 8.0 s pass): 0.15 s flash, **every player** is placed at x 24, y 448 facing east; counter 4096; west door locks (`fight`). Flag `intro:LOOP`.
3. 0.0–3.0 s: tick stops; chain sound from above; links come down from y −40 one by one (0.12 s apart) and wind round the gantry; the head last; `click` (bites tail) at 3.0 s.
4. 3.2 s: plate and eye light; line `intro` (§6); name card `INFINITE LOOP` / `while (true)`; HP bar; music phase 1 at the end of the line. Releases its tail and starts swimming.

### 5.3 Swim and targeting

Head speed 90 px/s (phase 2: 105, phase 3: 120) × iteration factor (`1 + 0.06 · i_phase`, max ×1.18; `i_phase` resets each phase). Turn rate 140°/s. Steering target: the current plan's target player; between plans the nearer player, alternating after every plan in co-op. Keeps 40 px off walls except in dives.

### 5.4 Plans and choice

Recovery between plans 0.35–0.5 s. Weights: distance > 160 px → `lunge` 3, `spit` 3, others 1; < 96 px → `dive` 3, `coil` 2; a player who stayed in a 48 px box for 2.5 s → `coil` forced (once per 6 s). Never the same plan twice in a row. **First cycle fixed:** phase 1 `spit`, `lunge`, then a 1.5 s calm coil near L1 or R1 (the breakpoint teaching moment); phase 2 `recursion`, `escalate`; phase 3 `wrap_dive`, `lunge`(feint).

| plan | phase | cue (body) | active | damage | recovery / punish |
|---|---|---|---|---|---|
| `lunge` | 1+ | 0.75 s: S-coil back, jaw open, eye + plate lit | straight 160 px at 420 px/s toward the target locked at the cue start | **2** | head stuck 0.6 s if it ends in a wall/floor/ledge (plate open for a half hit), else 0.4 s |
| `dive` | 1+ | 0.5 s (p2 0.45, p3 0.4): head up, points down, eye hand spins | vertical drop down a 32 px column to the first solid/one-way | 1 | head stuck in the floor 0.8 s (plate half hit) |
| `coil` | 1+ | 1.0 s closing, links clatter; a 40 px gap between head and tail | the ring (radius 40, p3 32) closes round the target | 1 | — |
| `spit` | 1+ | 0.5 s: cheeks puff, rings in the mouth | 3 brass rings on small circles (r 12) drifting 110 px/s toward the target; ring 2 of 3 is **yellow (catchable)** | 1 each | a caught yellow ring thrown at the plate = a half hit |
| `recursion` | 2+ | 0.45 s: head doubles for a frame pair, two eyes | a 4-link copy replays the head path of the last 2.0 s, then fades | 1 | — |
| `escalate` | 2+ | 0.7 s: whole body flashes violet | `lunge`, then a second lunge retargeted with a 0.45 s cue and **1** damage | 2 + 1 | head stuck 0.8 s after the second |
| `wrap_dive` | 3 | 0.75 s: head sinks into the pit, chain sound from the top, links show in the ceiling seam above the target column | falls from the top seam down the target column (prefers a falling player) and wraps on | **2** | head stuck 0.6 s on the gantry or M if it hits one |
| combos | 3 | the first plan's cue | `lunge`→`dive`, `coil`+`recursion` | as parts | after the last part only |
| feint | 3 | a full `lunge` / `wrap_dive` cue | then a 0.25 s hold before the active part | — | — |

### 5.5 The condition plate and the break window

- **Breakpoint:** the boss sets `bp = true` only when not in an active part and not in `bp_immune_t`. Frozen for `Game.BP_TIME` (3.5 s): head and links stop; every link's top 4 px is a **one-way platform** (both pages, from the frozen trail); contact harm off. Afterwards `bp_immune_t` = 4.0 s (phase 3: 6.0 s); a breakpoint on it while immune does nothing but play `bp_clang` and a blue shiver on the body (no text). Note: the engine draws `BREAK %.1f` over frozen creatures (`room.gd`); ask Zakaria whether to keep it for this boss (open question 1).
- **Plate hits:** frozen → 1 hit breaks the condition. Stuck head or caught yellow ring → a half (`tru_` flicker); a second half within 3.0 s breaks it; else it resets.
- **Break window:** `clack`, plate `false`, the body drops and lies along the floor or ledge below it: **2.0 s** (p2 1.8, p3 1.6); every link and the head take full damage; no contact harm. Phase 2: the nested ring drops for 4.0 s too. Then 0.5 s re-coil (invulnerable, bites its tail), plate `true`, `iter += 1`, counter +1, speed factor up. One small line the first time only: `...again.` (subtitle, no voice needed if the take is weak; ask).
- Outside the window: tail tip takes full damage and flicks (knock-back 80 px/s); middle links `"block"` (clang).

### 5.6 Phase transitions (invulnerable, no contact harm)

- **66 % → phase 2, 2.0 s:** bites tail, spins, violet; L1/R1 retract (0.6 s); gantry chains slacken and the swing starts; the nested ring (6 links, 12 × 12) splits off and takes GL; line `p2`; music `boss_hi`.
- **33 % → phase 3, 2.5 s:** plate cracks; floor cols 6..17 cracks glow 0.8 s (hazard-style build-up ≥ 0.6 s; no damage), then fall away; ceiling cols 6..17 open; L1/R1 back; players over the pit fall and wrap (no damage); line `p3`; music phase 3 (stutter).

### 5.7 Phase pressure

- Phase 1: gears on the tick; iteration speed-up.
- Phase 2: **nested ring** orbits a gear (r 3.4 tiles, 1 contact damage); every 6.0 s it crosses to the other gear over M: 0.6 s spin-up and jingle before it goes (cue ≥ 0.6 s); gear direction flips at each `iter`.
- Phase 3: the seam; HP = length.

### 5.8 Death (~20 s; the compact scene)

Use CRAWLER's `_compact` timeline with LOOP's text (§6) and these changes: (1) the fall: it **lets go of its tail** and lies open; if the pit is open, the floor slides back first with a `click` (0.4 s); (2) the progress bar runs to ~90 %, snaps back to 0 and runs again (once); (3) the echo word is `stop`; (4) the summary line is `Summary: INFINITE LOOP defeated. opus obtained. Continue mission.`; then the standard opus banner (`toolget`). Flags `boss:LOOP`, `compacted:LOOP`. The east door opens.

### 5.9 Net fields

Head x, y, dir (8-way), a compact trail (the head's last ~220 px of path as 16 samples; the guest interpolates), plan id / seq / phase of the plan / target, plate state (`true`, `half`, `false`, `cracked`), frozen time left, immune time left, break time left, `phase`, `iter`, `links` (phase 3 length), nested ring angle and gear, intro / death timers. Everything through `NetClasses.record/apply` (`parity` must pass).

### 5.10 HP

`T` in rooms.json tuned with `fightsim` (`BOSS=T10`) so a perfect bot spends ~50 s / ~55 s / ~60 s per phase; start from `T 140, u 0.6` and adjust (RACE needed 140). Also run the bot **without breakpoint** (half-hit route only): it must finish under 2× that time.

---

## 6. Lines, voices, subtitles

| key | who | line |
|---|---|---|
| `intro` | LOOP | `Attempt four thousand and ninety-six.` ... `You are new. Every attempt is new.` |
| `again` | LOOP (first break only, subtitle) | `...again.` |
| `p2` | LOOP | `Retrying. Escalating. Retrying. Escalating.` |
| `p3` | LOOP | `I was allowed three tries. Then someone said... retries are cheap.` |
| `die` | LOOP | `Break... statement... reached.` |
| `compact` (memorable) | LOOP, in the terminal box | `I was told: try again until it works. So were you. ...Who decides when you stop?` (meter 60 % / 85 % / 100 % on the three sentences) |

Voice (M5): Piper `en_GB-northern_english_male-medium`, slow, pitched down a little; the last word of each line echoes once, quieter. Make several takes and let Zakaria pick before wiring (as the crawler). Synthesize echoed words alone and check word timings with ASR.

---

## 7. Sounds and music (M5)

Chain ticks per link (rate follows speed), the tail-bite `click`, the plate `clack`, the chain collapse + silence, `bp_clang`, the nested ring jingle, the seam rattle, floor crack. Tower tick in the room speeds up a little with each `iter` (cosmetic). Music: phase 1 `boss` + a tick layer, phase 2 `boss_hi`, phase 3 the boss track with a one-bar repeat every 8 bars (made with ffmpeg, `-q:a 0`, keep the pck small). Generated wavs via `tools/godot/sfx/`.

---

## 8. Loss, foreshadow, after (M6)

- **Loss menu:** the generalized `Boss` menu (`has_retry`, `retry_spot` = x 24, y 448 for both). `retry`: phase 1, hall reset, short intro, **counter +1**.
- **Sign:** the diff sign inside T10 by the west door (§3.2). Logs changelog line on the kill: `fix: restore the retry limit — attempt < 3. the loop may stop now.`
- **After:** the open snake lies on the floor (drawn by the hall, no collision), plate `false`, counter frozen. Tower tick 0.8333. Existing aftermath (T09 stops spawning, T08's bell) stays.
- **T09 decor** (a chain sliding behind the back wall in laps 2 and 3): only if the world inbox row is answered yes.

---

## 9. Tests and screenshots per milestone

| M | tests | screenshots (`WAIT=N bash tools/godot/shot.sh out.png <scene> gfx=high`) |
|---|---|---|
| M1 | new `loop3` (M1 part: rooms.json size/origin/doors, routes §3.3, pit/seam apply both pages, wrap of a player), `rooms5a`, `tick5a`, `check5a.py`, `perfrooms`, `gfxcontrast` | `loopfight:p1`, `loopfight:p2`, `loopfight:p3` (empty arena per phase) |
| M2 | `loop3` M2 part, `bosspresets` rows (`lunge` 2 dmg cue 0.75, `dive`, `coil`, `spit`), `fightsim BOSS=T10`, `co-loopboss` rewritten (phase 1, with and without `BADLINE_ALL=1`) | `loop_intro` at 1.0 / 3.5 s, `looptell:<plan>` |
| M3 | `loop3` M3 part (freeze → platforms on both pages, plate rules, break window, immunity, yellow ring), `co-loopboss` (the guest freezes it and breaks the condition), `breakpoint` | `loopfrozen`, `loopbreak` |
| M4 | `loop3` M4 part (transitions, nested ring cues ≥ 0.6, wrap dive cue ≥ 0.7, no two 2-damage plans live, min arena), `fightsim` (both bots), `perfrooms`, `co-loopboss` phase 3 with a wrap on a bad line | `loopfight:p2`, `loopfight:p3`, `looptell:wrap_dive` |
| M5 | `loop3` M5 part (lines, word order, compact timeline: the bar loops once, echo `stop`, flags), voice files | `loopdie` at 2 / 8 / 14 / 19 s |
| M6 | `loop3` M6 part, the whole `tools/godot/test-all.sh`, web export as its own last commit | `loopafter` |

---

## 10. Open questions (ask Zakaria before the milestone that needs them)

1. The engine's `BREAK 3.5` text over a frozen creature (`room.gd`): keep it on the snake (it is the ability's own UI, shown everywhere) or hide it for this boss (no on-screen text rule)? Recommendation: keep it; it is not an attack warning.
2. Voice takes before M5 (several takes to pick from) or build with one take?
3. If he draws the snake: how many head directions he wants to draw (8, or 5 and mirror).

## 11. What not to do

- No on-screen attack warnings, no target markers, no fixed attack order.
- No change to T09, T11 or any other room's map (T09 decor only after the world dept says yes).
- No unshippable voice (`alan`, `ryan`).
- No per-frame redraw of static art; no new particles.
- Do not make breakpoint the only way to win.
