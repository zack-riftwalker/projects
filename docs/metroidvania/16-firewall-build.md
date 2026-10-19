# 16b · THE FIREWALL: build plan (for the builder)

This is the complete build plan for THE FIREWALL, written for the model that builds it (the `boss-build` skill). The design talk with Zakaria is in [`16-firewall.md`](16-firewall.md) (Persian). That doc is the source of truth for **what the player sees and hears**; this file is the source of truth for **how to build it**. If they disagree, the Persian doc wins and you ask Zakaria.

Read before every session: this file, [`15-boss-process.md`](15-boss-process.md) sections 3-5, [`07-js-vs-godot.md`](07-js-vs-godot.md) §3, and `CLAUDE.md`. The reference build is CRAWLER OF THE WEB: `godot/src/enemies/crawler_boss.gd` and `godot/src/world/index_hall.gd`. **Copy its patterns** (a boss class + an arena helper owned by the room, state in net fields, hazards via `hz_add`, scenes on `room.time`).

---

## 0. How to work

- **One milestone per session.** Find the first milestone in §9 whose status is not `done`, build only that one, test it, commit, push to `ph1`, mark it `done` in the status table below (with anything that changed), report to Zakaria **in Persian**, short.
- Start: `git fetch origin ph1 && git checkout ph1 && git pull origin ph1`. `npm ci` if `node_modules` is missing. `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`.
- **Ask, don't guess**, when something the player sees or hears is not decided here or in the Persian doc (a look, a timing he would feel, a text, a sound, a difficulty number). Ask in Persian, 2 options + a recommendation. Internal choices (names, structure, refactors inside the boss) are yours.
- Never invent dialogue. All lines are in §6.
- Never merge into `main`. Never skip, disable or loosen a test to get green.

| milestone | what | status |
|---|---|---|
| M1 | arena: map, HoneypotHall, packets, hot floor, camera, lights | **done** (notes below) |
| M2 | boss body + phase 1 + intro + two-bar HUD | **done** (notes below) |
| M3 | fake-victory cutscene + phase 2 + rate limit | **done** (notes below) |
| M4 | phase 3 + last 15 % | **done** (notes below) |
| M5 | death scene, voices, sounds, music, logs, crawler compact line | **done** (notes below) |
| M6 | loss menu, NETWORK foreshadow (N01 scene, signal icon, signs), after-state, full tests, web export | not started |

### M5 notes (what changed from the plan while building it)

- **Voices** (`godot/assets/voice/firewall_<key>.ogg` + `firewall.json`, ~0.4 MB in all): made by `tools/voice/firewall_voice.py --line <key> --json <key>.json` (the cold voice is the approved take **c**; warm is the LJ Speech voice alone), phrase times by `tools/voice/firewall_times.py`. The times in the JSON are the ones the build used (the file is a join of phrases of known length and pauses, so they are exact); the recognizer (faster-whisper `base.en`, one phrase at a time) is used only to say which phrases it could **not** understand. Slower (length scale up to 1.5) fixed most of them, but the recognizer still misses these cold phrases: `Connection refused.`, `And you believed me.`, `Why?`, `Because I was polite?`, `They trust you for the same reason you trusted me.`, `You are polite.` (it hears the metallic voice badly, it may be fine for a human): **Zakaria should listen to the cold lines** (refused, reveal, p3, die) and say if one must be remade. Credits are in `CREDITS.md`; the voices are in `Audio.VOICE`; `_say(k)` plays the voice (a sound: the guest hears it too) and the subtitle runs from the same line in the JSON.
- **Sounds**: `tools/godot/sfx/make_firewall_sfx.py` writes `fw_ding`, `fw_ok200`, `fw_deny`, `fw_tock`, `fw_hiss`, `fw_whoosh`, `fw_tapestop` (prefixed `fw_` because the game already has a `tock`); they replace the stand-ins (200 OK, the tape, the carpet, the hiss of the arms and the punch, the two deny beeps of a 429 and of a packet about to be dropped, the dry knock of a hit in the cooldown, the hop).
- **Death** (`begin_death`, `_step_death`; both pages draw it from `die_t`): 0-0.8 s the fires go out (`hall.dim` fades the grates and their lights), the face's eyes go out; 0.8 s the line (`firewall_die`, 12.1 s) with its subtitle phrase by phrase, the colour turning from cold to warm; the line's end + 0.5 s the shell flickers back for 1.5 s (the lobby's wall drawn over the furnace at 60 %, blinking, and the green `Everything is fine. Continue.`; `firewall_fine`; flag `fwline:FIREWALL`); then the bricks come down (the hall goes to stage 3 with its stairs at once, falling bricks drawn for 2.0 s), then `gone`, `dead`, the drop and `bossDead` (the room's reward flow: flag `boss:FIREWALL`, the `ssh` banner, the doors). The skip button in an earlier phase turns the fight into phase 3 first so the scene always plays in the furnace.
- **CRAWLER's compact** (`_night()`): with `boss:FIREWALL` the net's three lines and the firewall's last line (lost among the other lines, not highlighted); `compacted:FIREWALL` is set with `compacted:CRAWLER`, and the Logs show `THE FIREWALL: [compacted]` (`crawler3` checks both).
- Screenshot helpers: `fwdie:<secs>[:<x>:<y>]`, and `crawler:<hp>:<x>:<y>:<secs>:fw` (the crawler's compaction with the firewall flag).
- New co-op scenario `co-firewalldeath` (host kills it from phase 3; the guest sees the fires go out, the shell, the stairs, the free camera).

### M4 notes (what changed from the plan while building it)

- The phase-3 scene (`shift_k` 3, 3.0 s, `S3` marks): at 0.0 the cold line's subtitle starts (`say_k` 3), the packets stop (`pk_t0` = none; players on one just fall, no damage), the west wall glows and cracks (drawn by the boss), at 1.5 s the hall's masks become stage 2 (`west_c1` 3), the face shows a doubled image 2.0-2.5 s, at 3.0 s `ph` = 3 and the packets start again with `pk_dir` 1 from `room.time`. Invulnerable, no boxes.
- The face is no longer one rectangle: `faces()` lists the faces out on a wall (`[wall, y]` each; none while it hops or in the scenes; two in a split). Hurtboxes carry `face` (1 or 2), `wall` and `fy`, so a `429` blast is centred on the face that was hit. `face_wall`/`face_y` is the main face, `face2_y` the second one (on the other wall, -1 = none).
- `punch`: the wall nearer the target throws it (not necessarily where the face is). The fist's top is row-aligned (`fy` = a multiple of 16, from the target's feet - 6) so the one-way tile and the drawn fist agree. A packet under the target drops with the punch: the `pdrop` hazard is created at the cue with warn = the cue, `_sync_heat()` mirrors it into `hall.pdrops` (time = hazard t0 + warn) on both pages. In a split a punch stays out 0.6 s, not 1.0 s, so the chain runs 4-5 s.
- `split`: its plan is the tell (cue 0.7: both walls heat, two beeps). On its `active` the host sets `face2_y` and `split_left` (3-4); each strike is its own plan (punch 60 % / flame 40 %, a random wall, aimed at `kit_pick_target()` at its cue); the plan gaps (rec 0.5-0.6 + cue 0.5-0.75) keep the active moments > 0.35 s apart (the test measures it). When the last strike is done: `_end_split()` merges the faces on the east wall at y 368, dazed 1.0 s.
- `hop`: every 2-4 s when nothing is running (not in a split, not dazed) the face jumps to the wall nearer a target (25 % the other one) at its height; `hop_t0/hop_fw/hop_fy` carry where it came from; for `HOP_T` 0.4 s it has no boxes and an orange trail is drawn (the old spot goes dark).
- DROP ALL: the `dropall` hazard (warn 0.9, burn 1.6, 12 px tall over the whole inner floor) every 6 s from 5 s into the phase, never during a split (it waits and starts right after); while one exists no new heat is added.
- 429 in phase 3 steps both walls in (`_on_429`), 18/3 -> 17/4 -> 16/5 (14, 12, 10 tiles); `HoneypotHall._push_out()` pushes this page's own player out of the new column (each page moves only its own body, so nobody is trapped in bricks and nothing is crushed).
- Feint: 1 in 4 slams in phase 3 has a cue of 1.0 s (`SLAM_CUE` + 0.25); a phase-3 slam recovers in 1.0 s. A slam, sweep and banlist come from the face's wall; the slam's arm comes out of the wall in its plan field.
- The last 15 % (`hpf <= 0.105 * max_hp`, once): the plea (`say_k` 4, subtitle only until M5) and `green_t0` (state).
- Phase-3 lights: a red alarm strobe (1 Hz, prio 0) and a red light at each face (`room_lights.gd`).
- Screenshot helper: `fwp3:<x>:<y>[:<punch|flame|split|dropall|green|slam>[:<secs of packets>]]`.
- `co-firewall` now runs phase 3 too (the host forces the scene at 35 %, then a punch, a split, a flame; the guest checks the west wall, the fist, the second face, DROP ALL and the west-wall packets) and the whole scenario fits the bad line (`BADLINE_ALL=1`).

### M3 notes (what changed from the plan while building it)

- The scene is derived from `shift_t0` (room time) on both pages (`shift_k` 2, `shift_long`); the marks are two constants (`CUT_LONG`, `CUT_SHORT`). The host steps the events (sounds, `set_stage(1)` at the fall, the reveal line, the end); the guest only draws and freezes its own body. Each page freezes **its own** player (`_freeze_own`, from the scene's clock), never the partner's.
- Marks (first time, 12 s): `200 OK` chime 0.0, tape stops 1.2 (music `""`), `ACCESS DENIED` 2.0, carpet burns from 2.6, floor and furniture go + body bricks 4.0 (players unfrozen), the door slides 4.0-5.0, the reveal 5.0 (name, line, name card), bar 2 fills 6.0-7.0, phase 2 at 12.0. Short version (3 s): the floor burns at 0.0, goes at 0.5, the face slides 1.0-2.0 (with the reveal), bar 2 fills 1.0-2.0, phase 2 at 3.0; nobody is frozen. The banner is drawn by `draw_hud`.
- **The arm breaks at 2 hits, not 3** (`ARM_BREAK`): the planted fist is out 1.5 s, a player has only 2 free hits in 2 s, so a third hit would always be a 429 and a solo player could never break it. The slam's arm comes out of the wall at y 232 (`SLAM_TOP`), not 200: with the camera at the furnace floor the picture starts at y 232, so the root's glow (the tell) must be there; the harm box runs from 232 to the floor.
- Caught things (`how == "catch"`) are not rate-limited and not counted: they are a counter-attack, not requests. The skip button (`d >= 9999`) goes through the scene and the limit.
- The rate limit's state per player is `rl[key] = [hit time, hit time, cooldown end, blink]` (all carried in the net fields). A hit during the cooldown restarts it at 5.0 s (`tock`), the third hit within 2.0 s is the `429`: the counter blast is the `wave` hazard (0.7 s build-up: a glow grows round the face and `429` shows in it; then 96 x 96 for 0.3 s, `_big()`).
- Hot floor: `_heat_watch()` adds a `heat` hazard (warn 2.0) for a floor column under a player standing on the furnace floor; `_sync_heat()` mirrors the hazards into `hall.heat` on both pages so the hall draws the dim / bright / flame / cool cell from the hazard's own clock. Burn 1.2 s (1.6 s in phase 3), then 1.0 s cooling.
- Phase 2 holds at 35 % (`on_damage`) until M4 brings phase 3. `phase` (the base class's, used by `look.gd`) follows `ph`.
- Stand-in sounds until M5: `uiOk` (200 OK), `degauss` (the tape), `explode` (the carpet), `crumble` + `bigExplode` (the floor), `roar` (the reveal), `charge` (hiss), `warn` (the 429), `tock` (cooldown), `thud` (the slam), `dash` (the sweep).
- Screenshot helpers: `fwcut:<secs>[:short]` (the scene that many seconds in; the first frame runs its events up to there) and `fwp2:<x>:<y>[:<slam|sweep|banlist|429>[:<secs of packets>]]`.
- `co-firewall` now runs the real scene (the host starts it at 70 %), checks both pages fall and the guest was frozen, then 34 s of phase 2: attacks on both players, packets, the hot floor, the guest rides a packet and mashes the attack key at the face until its 429 (the host reads the guest's rate-limit state).

### M2 notes (what changed from the plan while building it)

- The shell holds at 70 % (`on_damage` clamps), so until M3 the fight cannot end by damage; the pause menu's skip button still ends it (a hit of 9999+ is a skip). M3 replaces the hold with the fake-victory cutscene.
- `hud_bar()` returns `[fraction, colour, name]`; `hud.gd` uses it for any boss that has it (the bar's back is the colour darkened). Bar 1 is green and runs from 100 % to 70 % of the hp; the two-bar fill animation is M3.
- A caught cookie is steered at the door's screen (the lob it was thrown with would not find it) and dazes the shell for 1.5 s on any `catch` hit: the only catchable thing in this fight is a cookie, so "hits the door" and "hits the screen" are the same event. The screen is still its own hurtbox for claws.
- The reception tray is at (177, 122), where the hall draws it (the plan said (168, 124)).
- The welcome line has no voice yet: its subtitle runs on `say_t0` with a stand-in length (4.6 s); M5 brings the file and the real length. The intro uses the generic name card (it shows in the last 1.2 s of the 6 s intro).
- New glyph `∞` in `pixel_text.gd` (big and tiny) for the LED text `requests remaining: ∞`.
- Music is `w1` for the whole shell (placeholder, see 5.10). Stand-in sounds: `uiOk` (ding), `gate` (door click, hinge), `chirp` (hold music), `tick` (mat, bite), `dash`, `roar`.
- `fightsim BOSS=N15` now also prints when the first bar ends: ~55 s on normal, ~73 s on hard for the test bot (target ~60 s on normal): `T` stays.
- Screenshot helpers: `fwintro` (the intro; WAIT 345 shows the card) and `fwtell:<cookies|hold|mat|crack>[:<x>]` (phase 1 with that attack just begun).

### M1 notes (what changed from the plan while building it)

- `rooms.json` N15: `"mood": ["stable", 1]` (the lobby is calm); the hall asks for `heat` in stages 1-2 (`look.gd`), `heat_p3` stays the boss's phase 3. `world-phase45.json` N15 `h: 28`. The room file has no trailing newline (the loader counts one as a row).
- The hall also draws the **base bricks** of the two bodies and their four port holes (static, redrawn only when a mask changes); the boss (M2-M4) draws only what moves on them: the face, arms, glows, the LED row.
- `pk_t0` is `HoneypotHall.NO_PK` (-1000) when no packets run: a real room time can be small, so `-1` was not a safe sentinel. Packets are anchored at fixed x (`SURF_E` 288 for the east face, west face base 16 or 64), so a wall stepping in (`429`) never moves a packet; a packet that is entirely inside a wall is `off`.
- The 1.0 s gap rule: green packets are never cancelled, but they count as drops for the *normal* ones (a normal drop within 1.0 s of a green one is cancelled).
- A hot-floor cell's clock is `HoneypotHall.heat_phase(age, burn)` (dim 1.4 s, warning 0.6 s, fire, 1.0 s cooling); the boss's `heat` hazard (M3) follows it and mirrors its cells into `hpot.heat`.
- The boss is an inert door for now (`FirewallBoss`: no attacks, no contact damage, hurt like any boss). Its net fields already carry the hall's masks and the packets' clock (`NF` = 19). M2 rewrites it.
- `RoomHaze` (heat haze over the old bricks) and the old N15 brick glows/embers are gone with the bricks; the old v2 tests (`firewall2`, the shield check in `plugins5a`, `fw_until`, the N15 rows of `bosspresets`) are gone; `bosspresets` now requires every row of its table to give a plan.
- Gfx tests: the lobby is bright on purpose, so `gfxcontrast` asks of the lobby that its wall covers the room (mean L >= 0.30) instead of being dark; the furnace (stages 1-2) keeps the dark-room rules. `arenas`, `moodshift`, `ambient` read the hall's stage.
- Screenshot helper (M1 form): `firewall:<hp>:<x>:<y>[:<secs>]`, 1.0 lobby, 0.6 furnace, 0.3 two walls, 0 the burned shell; `<secs>` = how long the packets have run.

---

## 1. The fight in one page (so you know what you are building)

THE FIREWALL is a **honeypot**: a firewall that learned that walls are not enough, so it pretends to be a friendly open server and lets attackers walk in by themselves. It has two voices: a warm woman (the friendly shell) and a cold woman + man speaking together (its real face).

1. **Before.** Clawd enters NETWORK at N01: a short scene, `Connection refused.` (cold), then `Sorry about that! Please proceed to the dmz for verification.` (warm). A small red "no signal" icon stays on the HUD until the firewall dies. Friendly green-worded signs point to the dmz (N14 bench). N15 is next door.
2. **Phase 1, the shell (HP bar 1, green, name `GUEST SERVICES`).** N15's top half is a warm, bright **lobby**: carpet, a sofa, a reception desk, a shelf, a fake window with a sunny sky, a sign `Welcome! Free Wi-Fi`. The boss is a big green **EXIT door** on the east wall with a small smiling screen on its frame. The door never moves; the lobby's things attack (cookies, hold-music notes, a carpet wave, a flame from the door's crack). Anything you rest on for 2 s bites. No rate limit (a fake LED row says `requests remaining: ∞`).
3. **Fake victory cutscene.** Bar 1 empties: the door opens with `200 OK`, a green banner `THE FIREWALL defeated`… the music stretches like a jammed tape, the banner turns into `ACCESS DENIED`, the carpet burns and **the floor disappears**: everyone falls 14 tiles into a brick **furnace**. The door slides down the wall: it was only the face of a huge brick body that is the whole east wall. Cold voice line. Name card `THE FIREWALL` / `deny by default`, and a red HP bar (bar 2) fills.
4. **Phase 2, fire (bar 2 from 100 % to 50 %).** The face rides up and down the body wall; two brick arms come out of it. There are **no fixed platforms**: **packets** (moving 4-tile platforms) fly out of four port holes in the body (`22`, `80`, `443`, `8080`) to the west wall; some are **inspected and dropped** (they turn red, then crumble). The furnace floor is **stateful**: a floor cell you touched heats up and burns 2 s later. Each player has a **rate limit**: 2 hits in 2 s are free, the 3rd is `429 Too Many Requests` (a counter blast, then that player's hits do nothing for 3 s; hitting during that cooldown restarts it at 5 s).
5. **Phase 3, two walls (bar 2 from 50 % to 0).** The west wall turns into firewall body too. The face jumps between the two walls (an orange trail under the bricks shows where), sometimes **splits in two** and attacks from both sides in random order (punches and flames, each aimed at a player). Packets come from both walls. **DROP ALL** burns the whole floor every ~6 s: only packets are safe. Each `429` pushes both walls one tile closer (down to a 10-tile furnace). **Last 15 %:** the warm voice pleads `Please... you're safe here.`, and green "safe" packets appear that **always** drop (a lie).
6. **Death.** Fires go out, the death line goes from cold to warm, the honeypot shell flickers back for a moment: `Everything is fine. Continue.` Then the ssh reward banner. The body collapses into **brick stairs** up to the east door (and the west wall into stairs up to the west door).
7. **Loss.** Both players down → a terminal-style menu: `retry` (restart from phase 1 right here) or `back to last commit` (the last bench).
8. **After.** The lobby stays burned with the cracked fake-sky window. The green signs go grey. The firewall's death line later shows up (and gets lost) inside CRAWLER's compact scene, and the Logs get `THE FIREWALL: [compacted]`.

---

## 2. Rules that must hold (check every change against these)

- **No on-screen warnings.** Do **not** call `draw_plan()`, `warn_col()` or `_target_marker()` (the kit's hatched boxes, `!` and target markers). Every tell is drawn as part of the body or the room: a glow on the bricks, the door's crack lighting up, a speaker lighting, a packet turning red, a floor cell glowing. CRAWLER does the same; read how it draws its tells.
- Arena hazards (`hz_add`) need a visible build-up of at least 0.6 s (`HZ_WARN_MIN`); the guest is only hurt by hazards it has seen for `HZ_SEEN_MIN` (0.5 s). Draw every hazard from its `t0`.
- A 2-damage hit needs a cue of at least 0.7 s (`bosspresets` checks plans). Every plan cue must be at least 0.30 s as seen on the guest (watchdog `boss-cue`).
- Damage: normal hits 1, heavy hits 2. Use `_big()` (= `Game.dv("big_hit")`) for heavy hits, like CRAWLER.
- **Weighted attack choice** by distance/height and phase; never the same attack twice in a row; the **first cycle of each phase is a fixed teaching order** (§5).
- **At most two dangers at once plus the body:** one attack (plan) + one pressure layer. Pressure layers: phase 1 = bites; phase 2 = hot floor + packet drops; phase 3 = hot floor or DROP ALL + packet drops. DROP ALL never starts during `split`.
- Beatable **without sudo** (no double jump). The player may have: bash (8-way dash, 48 px), catch (parry a yellow projectile back), jump (54 px ≈ 3.4 tiles, ~0.65 s in the air), wall jump, down-attack pogo. Every platform/packet lane is at most 3 tiles above the previous one or the floor.
- **Co-op:** the host owns the boss and the arena. Everything the guest must show or be hurt by is state: net fields (`net_fields` / `net_apply` with a constant `NF`, and the class registered in `NetClasses`), hazards (`hz_pack` / `hz_unpack`), or a pure function of `room.time` (which the snapshot carries as `rt`). Damage the host deals to P2 goes through boss harmboxes / hazards checked by each page on its own body, or `room.harm_zone`; never move or hurt the guest's body from the host directly. Run `--test=parity` after any net-field change.
- **State over events** (CLAUDE.md): phase, names, music, camera, floor tiles, packets, the menu: derive them every frame from state; never from a one-shot event.
- **Speed:** nothing per frame or per snapshot walks `Game.flags`. Static drawing (the lobby wall, the brick wall) is drawn once in its own node and only toggled. Measure `--test=perfrooms` before and after M1 and M4.
- **Scope:** keep changes inside N15, the firewall's files, and the small hooks listed per milestone. Do not change the NETWORK map (only N15's height), N12's packets, or any other boss, except the CRAWLER compact lines in M5.
- Voices: only `en_US-ljspeech-high` (public domain) and `en_GB-northern_english_male-medium` (CC BY-SA 4.0). Never `alan` or `ryan`.
- Nothing personal, no keys, no IPs in the repo.

---

## 3. Geometry (tiles are 16 px; x right, y down)

Room N15: **24 × 28 tiles** (384 × 448 px), origin stays `[1498, -2]` in `rooms.json`; it now reaches down to row 25 in world space (checked: free down to G02 at world row 80). Update the size in `godot/src/world/rooms.json` and in `docs/metroidvania/world-phase45.json` (`h: 28`), and run whatever map test reads them (`mapdata`, `worlddigest`, `rooms*`).

### 3.1 The map file `godot/src/world/rooms/N15.txt`

Legend (same as every room): `#` solid, `=` one-way top, ` ` air, `B` boss spawn. Door gaps: column 0 and column 23 are open on rows 7-10 (west door to N14, east door to N16, unchanged ids and locks).

```
row  0  ########################
row  1  #                      #
row  2  #                      #
row  3  #                      #
row  4  #                      #
row  5  #            ====      #
row  6  #                      #
row  7                          
row  8           ===            
row  9     ====                 
row 10                      B   
row 11  ########################
row 12  #                      #
 ...    (rows 12-24 the same: #, 22 spaces, #)
row 24  #                      #
row 25  ########################
row 26  ########################
row 27  ########################
```

Exact cells: shelf row 5 cols 13-16; desk row 8 cols 9-11; sofa row 9 cols 3-6; `B` row 10 col 20. Rows 7-10 have no `#` at col 0 and col 23 (doors). Row 11 cols 1-22 is the **false floor** (the lobby floor).

Many of these cells are **owned by the hall** (§4): their tiles are set every frame from the hall's masks, so what the file says for them only matters for the very first frame. Write the file as the phase-1 layout above.

### 3.2 Named coordinates (put these in constants)

| name | value |
|---|---|
| lobby floor top | y = 176 (row 11; equals `Boss.FLOOR`) |
| furnace floor top | y = 400 (row 25) |
| door body (phase 1) | x 304..368, y 80..176 (cols 19-22, rows 5-10); 64 × 96 px |
| door screen (its "face" in phase 1; catches return here) | 20 × 14 px centred at (336, 100) |
| speaker (hold music) | centred at (336, 72) |
| reception tray (cookies) | (168, 124), on the desk |
| body wall (phase 2-3) | solid cells cols `BODY_C0`..22, rows 12-24; `BODY_C0` = 18, then 17, 16 after each `429` step in phase 3 |
| west wall (phase 3) | solid cells cols 1..`WEST_C1`, rows 12-24; `WEST_C1` = 3, then 4, 5 after each step |
| furnace inner x range | from `(WEST_C1 + 1) * 16` (phase 2: 16) to `BODY_C0 * 16`; phase 2 = 17 tiles, phase 3 = 14, minimum 10 |
| face | 48 × 48 hurtbox, centred on the active wall's surface (it sticks 24 px out of the wall); centre y clamped to 232..368 |
| face low (after a broken arm) | centre y = 368 |
| carpet stubs (kept after the floor burns) | row 11 cols 1-3 and cols 20-22, one-way |
| packet lanes (top y = row * 16 + 2) | lane 0 `22` row 23 (y 370), lane 1 `80` row 20 (y 322), lane 2 `443` row 17 (y 274), lane 3 `8080` row 14 (y 226) |
| stairs after death, east | one-way cells (3 wide): cols 14-16 row 22, cols 17-19 row 19, cols 19-21 row 16, cols 20-22 row 13, then the stub row 11 cols 20-22 |
| stairs after death, west | cols 7-9 row 22, cols 4-6 row 19, cols 2-4 row 16, cols 1-3 row 13, then the stub row 11 cols 1-3 |

Check every vertical step is at most 3 tiles (stairs: 3, 3, 3, 2; lanes: 2, 3, 3, 3 above the floor; stub row 11 to lane 3 row 14: 3).

### 3.3 Camera

`rooms.json` boss entry: `"cam": "free"`. In phase 1 (and the intro) the player must **not** see the furnace: lock the camera to the top 14 rows (`room.cam.lock = {"x": 0.0, "y": 0.0}`); from the cutscene's fall onward, `null` (free follow). Derive it every frame from the boss state on both pages. Read how `fight_cam_lock()` (room.gd) and the camera use `cam.lock` and make the per-frame switch work; if `cam.lock` is only read at the intro, add a small hook (`boss.cam_lock()` if the boss has that method) inside the camera update. While the lobby floor exists, draw the area under row 11 as solid dark foundation (so a free camera never shows an empty pit before the reveal).

---

## 4. The arena helper: `godot/src/world/honeypot_hall.gd`

A `RefCounted` class like `IndexHall`, **owned by the room** (so it exists before and after the fight). Created in `Room` when `def.hall == "honeypot"` (add `"hall": "honeypot"` to N15 in `rooms.json`). Add `var hpot: HoneypotHall = null` next to `var hall: IndexHall` in `room.gd` and mirror every place `hall` is used (creation ~line 329, the draw proxies ~1041, `step` ~1563 and ~1825, `room_view.gd` back wall ~67 and owned-cell skip ~183, `room_lights.gd`). Do **not** rename or change `IndexHall`.

### 4.1 State (the masks; the boss writes them on the host and from net fields on the guest)

| field | meaning |
|---|---|
| `stage` | 0 lobby (phase 1), 1 furnace (phase 2), 2 two walls (phase 3), 3 after (boss dead) |
| `floor_on` | lobby floor row 11 cols 4-19 present (the stubs cols 1-3 / 20-22 are always present; in stage 0 they are solid like the rest, from stage 1 they are one-way) |
| `furniture` | bit 0 sofa, 1 desk, 2 shelf (one-way); all on in stage 0, all off from the floor burning on |
| `body_c0` | first column of the east body (18, 17, 16), stages 1-2 |
| `west_c1` | last column of the west wall (0 = none, else 3, 4, 5), stage 2 |
| `stairs` | 0 / 1 (stage 3) |
| `fist` | a Rect2 (or empty) of a punch fist that stays out 1.0 s: a temporary one-way top you can stand on |
| `burn_t0` | room time the carpet started burning (cosmetic) |
| `pk_t0`, `seed`, `green_t0` | packets: the room time packets started, the fight's seed, the room time green packets started (-1 never) |
| `pk_dir` | 0 = phase 2 (all lanes east→west), 1 = phase 3 (lanes 0 and 2 east→west, lanes 1 and 3 west→east) |

`apply()` (every frame, both pages) writes tiles from these masks, only changing cells that differ (copy `IndexHall._put`). Owned cells: row 11 cols 1-22, the furniture cells, the body/west wall cells rows 12-24 cols 1-5 and 16-22, the stairs cells. `owns(tx, ty)` lets `RoomView` skip drawing them.

`reset()` puts everything back to stage 0 (used by `retry`). When the room loads with `boss:FIREWALL` set, start in stage 3 (after).

### 4.2 Packets (moving platforms, pure function of room time + seed)

Packets are dictionaries in `room.plats` with keys `x, y, w, h, dx, dy` (so `TileGrid.plat_under` lets players ride them; it already skips entries with `off` or `lost` true) plus `"fw": true`, `"lane"`, `"k"`. Add `if m.has("fw"): continue` to `room._move_platforms()` and skip `fw` entries in the room's platform drawing loop (~line 3233); the hall moves and draws them. Keep a fixed pool (for example 12 dictionaries) and mark unused ones `off`.

Per lane `L` (0..3): `every = [2.0, 2.4, 1.8, 2.2][L]` s, `offset = [0.0, 0.7, 1.3, 0.4][L]` s, `speed = [100, 60, 80, 60][L]` px/s, width 64 px, height 6 px. Packet `k` of lane `L` spawns at `pk_t0 + offset + k * every`; it starts inside the wall it comes from and moves to the other wall, where it disappears into the bricks (draw it clipped by the wall surfaces). In phase 2 every lane goes east→west. In phase 3 lanes 0 and 2 go east→west and lanes 1 and 3 west→east (from the west wall). When the walls step in (`429` in phase 3), a packet whose body is inside a wall is `off`.

**Inspection (drops), deterministic so both pages agree:** use a hash of `(seed, L, k)` (for example `Game.hash3` like the old firewall did) to get `u` in [0, 1):
- packet drops if `u < 0.25` and packet `k - 1` of the same lane did not drop;
- its drop point is at a fraction `0.3 + 0.4 * u2` of its path (`u2` another hash);
- `warn` (drawn red, a deny beep once on the host as a sound) for the 0.6 s before it reaches the drop point, then `lost` (crumbles: draw falling brick bits, no floor) for the rest of its path;
- **no two drops within 1.0 s across all lanes:** decide drops in spawn-time order and cancel a drop whose drop moment is within 1.0 s of an earlier one (keep a small memo per fight; both pages compute the same).
- **Green packets (last 15 %):** packets spawned after `green_t0` with `(k + L) % 3 == 0` are drawn green ("safe") and **always** drop at a fraction `0.5 + 0.3 * u2`, with the same 0.6 s red warning right before (they look green until then). They ignore the 1.0 s rule against normal drops but never two green in a row in a lane.
- **Punch drops (phase 3):** a hazard `pdrop` with `v = [lane, k]` (§5.4) makes that packet `lost` from the moment the punch turns active.

Falling off a dropped packet does no damage (decided).

Draw packets like N12's (`room._draw_packet` look: a two-tone bar with a bright front edge) plus their port number in tiny text on the side, red when warning, crumbling bits when lost, green for green packets.

### 4.3 The hot floor (stateful)

Cells: the furnace floor (row 25), columns inside the current furnace. Only in stages 1-2 and only while the fight is active, not during scenes.

The boss (host) checks each living player every frame: if the player stands on the furnace floor (on ground, feet at y 400) over column `c`, and there is no `heat` hazard for `c` yet (live, burning or cooling), it calls `hz_add("heat", 2.0, [c])`. A heat hazard:
- 0..1.4 s after `t0`: the cell glows dim orange (drawn by the hall or the boss overlay);
- 1.4..2.0 s: bright orange-white (the warning);
- 2.0 s: live; burns for 1.2 s (phase 3: 1.6 s): harm box `{x: c*16, y: 390, w: 16, h: 10, dmg: 1}`;
- then 1.0 s cooling (dark red, no harm), then the hazard is removed (`_hz_expire`), and the cell can heat again.

Standing still therefore burns you after 2 s; walking forward is safe; walking back over your own trail is not. Both players' trails hurt both. No new heat is added while a `dropall` hazard exists.

### 4.4 Drawing

- **Lobby wall** (stage 0, a static node drawn once): cream wallpaper, a dado rail, a framed fake window (pale blue sky, one white cloud, a sun), the sign `Welcome! Free Wi-Fi` in green, two warm table lamps, the reception desk front, the sofa cushions, the shelf with a small router and plants. Warm and a bit too clean for NETWORK.
- **Brick wall** (stages 1-3, its own static node): dark brick with orange cracks; furnace grates in the floor glowing. It covers the whole room (`gfxcontrast` needs the back wall to cover the room).
- **Carpet burn** (the cutscene): the carpet's red turns black from the middle outwards over 1.4 s with flames on the burning edge.
- **After** (stage 3): the lobby's wallpaper half burned away (bricks showing), the fake window cracked but still sunny, the carpet stubs charred, the stairs as loose bricks.
- **Bodies**: the east body (and west wall in stage 2) are drawn by the **boss** (they glow and move), not by the hall; the hall only owns their tiles.
- Lights (`room_lights.gd` `_arena`, an `N15` branch reading `room.hpot` and the boss): stage 0 two warm lamps and a soft window light; stages 1-2 orange glow from the floor grates, a red glow at the face, a soft glow per packet; phase 3 red alarm strobe (1 Hz). Remove the old N15 brick-glow code (line ~47) and the old `FirewallBoss` shield light (~169) as you replace them.
- Mood (`look.gd`): N15 stage 0 → mood `stable` (calm); stages 1-2 → `heat`; phase 3 keeps `heat_p3` (the `moodshift` / gfx tests expect it). Arenas never go below 35 % ambient (existing rule).

---

## 5. The boss: `godot/src/enemies/firewall_boss.gd` (rewrite)

Rewrite the file from scratch; keep `class_name FirewallBoss`, `extends Boss`, and its `NetClasses` id 31 (`net_classes.gd`). The old v2 code (shield, deny walls, scan) goes away entirely; delete what is no longer used. Constructor stays `_init(r, bx, by, base_hp := 82)`; call `super(r, bx, by, 64, 96, base_hp)` and `kit_init()`.

### 5.1 Names, HP and the two bars

`make_boss()` sets `boss_name` from `rooms.json` **after** `_init`, so: set `rooms.json` `"name": "GUEST SERVICES"`, `"sub": "welcome, guest"` (and keep `"banner": "ssh"`). The boss switches to `boss_name = "THE FIREWALL"`, `sub = "deny by default"` when the cutscene reveals it, and must derive the name from its phase on both pages (in `update` and `net_apply`), never only on an event.

One internal `hpf` / `max_hp` (as every boss). `max_hp` comes from `Game.boss_hp` (N15 `T` 109.4, `u` 0.75 → 82 on normal), times the co-op factor (`scale_hp`, applied by the room when both players are in the arena).
- **Bar 1** (green, phase 1): shows `(hpf - 0.70 * max_hp) / (0.30 * max_hp)`.
- When `hpf <= 0.70 * max_hp` in phase 1: start the cutscene (§5.3). Damage that would go below 0.70 * max_hp in phase 1 is clamped to exactly 0.70 * max_hp.
- **Bar 2** (red, phases 2-3): shows `hpf / (0.70 * max_hp)`; during the cutscene draw it filling from 0 to 1 over 1.0 s at the reveal.
- Phase 3 starts at `hpf <= 0.35 * max_hp`. Last 15 %: `hpf <= 0.105 * max_hp`.

HUD: add an optional hook in `godot/src/ui/hud.gd` (~line 78): if the boss has `hud_bar()`, use its `[fraction, fill_colour, name]` instead of `hpf / max_hp`. Other bosses must look exactly as before.

### 5.2 Fight timeline and states

`ph` (1, 2, 3), `shift_k` (0 none, 2 the cutscene, 3 the phase-3 scene), `shift_t`, `dying`, `die_t`. Invulnerable while `shift_k != 0` (`hit()` returns `""`, like CRAWLER). The intro uses the room's intro (`intro_len()`: 6.0 s first time, 2.5 s after; flag `intro:FIREWALL`, set in `start()`).

Intro (fight state `intro`): the west door closes with a soft click (`gate` sound at low volume is fine), the door's screen smiles, the warm intro line plays (§6) with its subtitle, the name card shows `GUEST SERVICES` / `welcome, guest` (the HUD already draws `boss_name` and `sub` during the intro).

### 5.3 Phase 1: the shell

The door does not move and has **no contact damage** (it is a door). Its hurtbox is the whole door (64 × 96). Body tells are drawn on the door and the lobby.

| attack | tell (body, no marker) | what happens | damage | window |
|---|---|---|---|---|
| `cookies` (fam `proj`) | the door screen's smile widens, a `ding` | the tray on the desk throws 3 cookies in arcs (gravity like a lob) towards the target's spot; one is **yellow** (catchable, the yellow diamond kind the kit uses for catchable shots; read CRAWLER `_shoot_results`) | 1 | a caught cookie that hits the door screen: dazed 1.5 s (no attacks, the screen shows a spinning loading icon) |
| `hold` (fam `proj`, harmless plan) | the speaker above the door lights up, the first note sounds | 4 notes (hazards `note`, like CRAWLER's `ling`): each drifts from the speaker towards where the target was at the cue, at 40 px/s, with a sine wobble (amplitude 8 px, 1.5 Hz), for 6 s; each has a small hurtbox: one hit pops it. Not started if 2 or more notes are alive | 1 per note | — |
| `mat` (fam `sweep`) | the corners of the welcome mat in front of the door lift (0.6 s) | a carpet wave runs from the door (x 304) to the west wall at 160 px/s along the lobby floor: harm box 24 px wide, 12 px tall above the floor | 1 | — |
| `crack` (fam `slam`, cue 0.8) | the door opens a crack, the light in the crack goes white → red, a hinge creak | a low flame comes out of the crack: box x 208..304, y 144..176, active 0.35 s | 2 | the door stays half open 1.0 s (rec 1.0) |

Rest between attacks 0.35-0.5 s (`rec`). Weights: `cookies` 3, `hold` 2, `mat` 2 (+2 if the target is on the lobby floor), `crack` 2 (+2 if the target is within 96 px of the door). First cycle fixed: `cookies`, `mat`, `hold`, `crack`.

**Pressure: "don't get comfortable"** (hazard `bite`, `v = [piece]`): the host tracks, per player, how long they have stood on the same piece (sofa, desk, shelf). At 2.0 s it adds `hz_add("bite", 0.6, [piece])`: the piece's cushions/edge twitch for 0.6 s (the build-up), then a bite box over the piece's top (piece width × 10 px) for 0.2 s, 1 damage. That piece then rests 3.0 s.

**Rate limit in phase 1:** none. The LED row (drawn on the door's lintel) shows `requests remaining: ∞` in tiny green text.

### 5.4 The fake-victory cutscene (phase 1 → 2)

Starts when bar 1 empties. `shift_k = 2`. **12.0 s the first time** (flag `reveal:FIREWALL` not set), **3.0 s** after that (set the flag at its end). Both pages run it from `shift_t` (and `room.time`); the guest gets `shift_k`, `shift_t` in net fields.

First time:

| time (s) | what |
|---|---|
| 0.0 | all projectiles and hazards cleared; players frozen (`q.frozen = true`, like `_start_intro`); the door swings open with a `200 OK` chime; a green banner (drawn by the boss's `draw_hud`, the honeypot's green font: pixel text, scale 2, `#57ff8a`) `THE FIREWALL defeated`; music: the phase-1 track keeps playing |
| 1.2 | music stops (`music_now` returns `""`), the `tapestop` sound plays; the banner glitches (letters shifting) |
| 2.0 | the banner becomes `ACCESS DENIED` in red |
| 2.6 | the carpet starts burning from the middle (hall `burn_t0`), crackle + `whoosh` |
| 4.0 | players unfrozen; lobby floor cols 4-19 and the furniture removed (`floor_on = false`, `furniture = 0`): everyone falls to the furnace (no fall damage; nothing to add). Camera lock released. Stubs become one-way |
| 4.0-5.0 | the door slides down the east wall to the face's start height; the body cells (cols 18-22 rows 12-24) become solid; the brick wall node replaces the lobby wall |
| 5.0 | the face's eyes open; the cold reveal line plays with its subtitle (§6); name and sub switch to `THE FIREWALL` / `deny by default`; the name card is shown again (draw it like the intro card) |
| 6.0-7.0 | bar 2 fills red |
| 12.0 | phase 2 begins (packets start: `pk_t0 = room.time`, `seed` set by the host at the start of the fight) |

Short version (3.0 s): at 0.0 the floor burns at once, 0.5 the floor is removed and players fall, 1.0-2.0 the face slides down and the reveal line starts (it keeps playing into the fight), names switch, bar 2 fills; 3.0 phase 2.

If someone is downed during the cutscene, they fall with the floor like everyone (bodies keep physics).

### 5.5 Phase 2: fire

The face moves along the east body's surface: idle drift towards the target's centre height at 40 px/s (clamped 232..368). Hurtboxes: the face (48 × 48) and a stuck arm. The rest of the body wall does not take damage and has no contact damage (it is a wall); the face has contact damage 1.

| attack | tell | what happens | damage | window |
|---|---|---|---|---|
| `slam` (fam `slam`, cue 0.75, act 0.25) | an arm pulls back into the wall above the target's column: the bricks around its root glow orange, steam `hiss` | the arm (a brick fist 32 × 32 on a brick forearm) comes out of the body above and slams down on the target's x: harm box x±16, from y 200 to the floor | 2 | the fist stays planted 1.5 s (hurtbox 32 × 24 at the floor). **Hit it 3 times: the arm breaks** and the face slides down to "low" (centre y 368) for 1.5 s |
| `sweep` (fam `sweep`, cue 0.5, act 0.6) | an arm lowers to the floor at the body's foot and scrapes sparks | it sweeps along the floor from the body to the west wall: harm box 24 px wide, 20 px tall above the floor, moving across in 0.6 s | 1 | — |
| `banlist` (fam `proj`, cue 0.5) | the face's mouth opens and glows hot | 3 burning bricks in a fan (-15°, 0°, +15° around the aim) at 170 px/s; **one is yellow** (catchable) | 1 | a caught brick that hits the face: dazed 1.5 s (the face sags to "low") |

Weights: `slam` 3 (+2 if the target is on the floor), `sweep` 2 (+2 if the target is on the floor and further than 96 px from the body), `banlist` 2 (+2 if the target is on a packet or above row 20). First cycle: `banlist`, `slam`, `sweep`. Rest 0.35-0.5 s.

Pressure: packets with inspection (§4.2) and the hot floor (§4.3), both always on in phase 2.

### 5.6 Rate limit (phases 2 and 3, per player)

In `hit()`, find the hitter with `kit_key_of(room.attacker)` (`"p1"` / `"p2"`, see `deadlock_boss.gd` for the same idiom). State per key: the room times of its last 2 damaging hits, `cd_until` (cooldown end), `blink` (bool).

- A hit while `room.time < cd_until`: **no damage**, a dry `tock` sound, and the cooldown **restarts at 5.0 s** (`cd_until = room.time + 5.0`, `blink = true`). No second counter.
- Else, if that key already has 2 hits in the last 2.0 s: this hit does **no damage** and triggers **`429`**: `cd_until = room.time + 3.0`, `blink = false`, and the counter blast: `hz_add("wave", 0.7, [face_cx, face_cy])`; during its 0.7 s build-up that player's LEDs turn solid red and the `deny` sound (two short low beeps) plays; then a heat wave box 96 × 96 centred on the face for 0.3 s, damage `_big()` (2). In phase 3 the 429 also steps both walls in by one tile (`body_c0 -= 1`, `west_c1 += 1`) unless the furnace is already 10 tiles.
- Else: a normal hit; record its time.

The LED row: drawn on the body above the face (phase 2-3; the door lintel in phase 1). Two rows of small LEDs, one per player, in that player's colour (P1 Clawd orange `Game.COL.clawdHi`, P2 its own colour as used elsewhere for P2). Each recorded hit lights an LED that fades after 1.0 s. Cooldown: all LEDs of that player solid red (blinking at 4 Hz when `blink`). The guest needs all of this: put the per-key hit times, `cd_until` and `blink` in net fields.

The counter blast and the cooldown apply to the boss's face and arms alike (any hurtbox).

### 5.7 Phase 3: two walls

Scene (phase 2 → 3), `shift_k = 3`: **3.0 s** (invulnerable): the west wall cracks and bricks grow out (hall `west_c1 = 3`, stage 2) over 1.5 s; port holes open on the west wall; the face shows a doubled image for 0.5 s; the cold phase-3 line plays (it continues into the fight). Packets switch to `pk_dir = 1` at the end.

The face **hops** between walls between attacks: every 2-4 s when no plan is running, it picks a side and height (towards a target), and an orange trail runs under the bricks from the old spot to the new one over 0.4 s (fields `hop_t0`, from side/y, to side/y); the old spot goes dark. The hop is harmless and the face cannot be hit during the 0.4 s.

| attack | tell | what happens | damage | window |
|---|---|---|---|---|
| `punch` (fam `lunge`, cue 0.75, act 0.2) | the wall facing the target bulges at the target's height, its bricks glow orange, `hiss` | a fist shoots out 96 px from that wall at the target's height (box 96 × 24) | 2 | the fist stays out 1.0 s as a one-way top (hall `fist`) and a hurtbox: stand on it or pogo it. If the target was standing on a packet at that height, that packet drops (hazard `pdrop [lane, k]`, created at the punch's cue so the guest sees it with the punch's tell) |
| `flame` (fam `proj`, cue 0.5, act 0.4) | the face's mouth opens and glows | a horizontal flame 80 px long, 20 px tall from the face towards the furnace | 1 | — |
| `split` (fam `guard`, cue 0.7; then a chain) | the face doubles, **both** walls heat at once, two deep beeps | two faces for 4-5 s, one on each wall at the targets' heights. A chain of 3-4 strikes, each its own plan: side random (left/right), kind random (`punch` 60 %, `flame` 40 %), each aimed at a player's position at its cue (targets alternate in co-op, `kit_pick_target`); between two strikes' active moments at least 0.35 s; each strike has its own tell as above | 2 / 1 | after the last strike the faces merge on the east wall, dazed 1.0 s (centre y 368) |
| `slam`, `sweep`, `banlist` | as phase 2, from either wall | as phase 2 | 2 / 1 / 1 | windows 1.0 s instead of 1.5 |
| feint | — | a `slam` whose cue holds 0.25 s longer than usual (cue 1.0): 1 in 4 slams in phase 3 | 2 | 1.0 |

Both faces share the one HP pool; there is no fake face.

Weights: `split` 3, `punch` 2, `flame` 2, `slam` 1, `sweep` 1, `banlist` 1. First cycle: `punch`, `split`. Rest 0.35-0.5 s.

**DROP ALL** (hazard `dropall`, `v = [x0, x1]` the furnace's inner x range): every 6.0 s (not during `split`, not during a scene): the whole floor glows red for 0.9 s (build-up), then burns 1.6 s: box over the floor (12 px tall), 1 damage. While it exists, no new heat hazards. Only packets (and a fist) are safe.

Hot floor in phase 3: burn time 1.6 s (§4.3).

**Last 15 %** (`hpf <= 0.105 * max_hp`, once): the warm voice plays `Please... you're safe here.` (subtitle in green), `green_t0 = room.time` (green packets start, §4.2).

### 5.8 Death

`begin_death()` like CRAWLER's (clear projectiles and hazards, no explosions). Then on `die_t` (both pages):

| die_t (s) | what |
|---|---|
| 0.0-0.8 | fires go out, the furnace grates dim, the face's glow fades; music silent |
| 0.8 | the death line plays (cold → warm, ~12 s, §6), subtitle phrase by phrase |
| 0.8 + line length + 0.5 | the honeypot shell flickers back over everything for 1.5 s: the lobby wall drawn at 60 % over the bricks, flickering; green text `Everything is fine. Continue.` (warm voice) |
| + 1.5 | the shell is gone; the body collapses: bricks fall and become the stairs (hall `stage = 3`, `stairs = 1`) over 2.0 s; `gone = true`, `dead = true`, `room.drop(...)`, `room.events.append("bossDead")` → the room's normal reward flow (banner `ssh`, flag `boss:FIREWALL`, east door opens) |

Set flag `fwline:FIREWALL` when the line has been heard (used by the CRAWLER compact in M5).

### 5.9 Net fields (the guest must be able to draw and be hurt by everything)

Put in `net_fields()` (and read back in the same order in `net_apply`), at least: `hpf*10`, `max_hp`, `active`, `dying`, `ph`, `shift_k`, `shift_t*100`, face side and centre y, second face y (split), `hop_t0*100`, hop from side/y, hop to side/y, arm state (0 none, 1 striking, 2 planted) and its x, arm hits, face low flag, dazed flag, door state (phase 1: closed / crack / open), `intro_t0*100`, `say_k`, `say_t0*100`, `die_t*100`, the hall masks (`stage`, `floor_on`, `furniture`, `body_c0`, `west_c1`, `stairs`, `burn_t0*100`, fist rect), packets (`pk_t0*100`, `seed`, `green_t0*100`, `pk_dir`), rate limit per key (2 hit times ×100, `cd_until*100`, `blink`), then `plan_fields()` (11 values) and `hz_pack()` last. Define `const NF := <count before plan_fields>` exactly like CRAWLER. Add a `puppet_tick(dt)` like CRAWLER's (kit and hazard ticks; hall sync). Register any new hazard kinds in `hz_kinds()`: `["note", "bite", "heat", "wave", "pdrop", "dropall"]`.

### 5.10 Music (placeholders, decided: no new music now)

`music_now(want)`: intro and phase 1 → `"w1"` (the friendly, familiar first-world theme: the honeypot plays what feels safe); the cutscene from 1.2 s → `""`; phases 2 → `"boss"`; phase 3 → `"boss_hi"`; dying → `""`. Main calls `music_now` already (`main.gd` ~750). Write a comment that these are placeholders until Zakaria makes the firewall's own music.

---

## 6. Lines, voices, subtitles

All in-game text is English. Subtitles: draw like CRAWLER's (read its `draw_hud` and subtitle code), warm lines in green `#57ff8a`, cold lines in pale red `#ff9a8a`.

| key (file `godot/assets/voice/firewall_<key>.ogg`) | voice | text |
|---|---|---|
| `refused` | cold | `Connection refused.` |
| `sorry` | warm | `Sorry about that! Please proceed to the dmz for verification.` |
| `intro` | warm | `Welcome! You're safe here. The exit is just this way.` |
| `reveal` | cold | `Request denied. ...You walked in on your own. They always do.` |
| `p3` | cold, "welcome" warm | `I said "welcome" and you believed me. Why? Because I was polite?` |
| `plead` | warm | `Please... you're safe here.` |
| `die` | cold → warm | `They trust you for the same reason you trusted me. You are polite. You say you mean well. ...Are you what you say you are? Do you even know?` |
| `fine` | warm | `Everything is fine. Continue.` |

Making them (M5): `tools/voice/firewall_voice.py` already makes the takes Zakaria approved (cold take **c**, warm take `warm`). Add a `--line <key>` option that writes one line per file (`.ogg`, `-q:a 4` is plenty), add the `refused` and `plead` lines to it (refused = cold, as `REVEAL`'s first phrase; plead = warm, length scale 1.15, a 0.5 s pause after "Please..."), and a JSON `godot/assets/voice/firewall.json` with each line's text, length and phrase start times. Get the phrase times with a speech recognizer (faster-whisper `base.en`, word timestamps; decode audio with ffmpeg to 16 kHz mono yourself, its `av` decoder can fail) and check that every phrase is recognized; if a phrase is not, make it slower and re-check. Setup (scratchpad, not the repo): `python3 -m venv venv && ./venv/bin/pip install piper-tts faster-whisper`, voices from `tools/voice/README.md`. Add the files to `Audio.VOICE` (`godot/src/autoload/audio.gd`). Add both voices to `godot/assets/voice/CREDITS.md` (LJ Speech: public domain; northern_english_male: CC BY-SA 4.0, as for the crawler). Run `$GODOT --headless --path godot --import` and commit the `.import` files.

Sounds (M5): a script `tools/godot/sfx/make_firewall_sfx.py` (copy `make_crawler_sfx.py`): `ding` (a soft hotel bell), `ok200` (two rising chime notes), `deny` (two short low square beeps), `tock` (a dry stone knock), `hiss` (steam, 0.5 s), `whoosh` (fire catching), `tapestop` (a tone falling in pitch and speed over 0.8 s). Reuse existing `crumble`, `brk`, `gate`, `degauss` where they fit. Add the names to `Audio.SFX`. Until M5, use existing sounds as stand-ins (`uiOk` for ding, `warn` for deny, `clang` for tock).

---

## 7. Loss menu, NETWORK foreshadow, after-state (M6)

### 7.1 The loss menu (only in N15 while the firewall fight is active)

- **When:** solo, the player's death (the room's `restart_requested`, see `room_manager.gd` ~46 and `main.gd` ~104); co-op, both players down (`coop.gd` `_host_down_logic`, where `both_t` runs out and calls `_respawn_both`). In both cases, if `room.boss is FirewallBoss` and the fight is active, open the menu instead of respawning.
- **Look (decided):** a terminal box like CRAWLER's compact box (black, 1 px green border), centred, two lines in green pixel text: `> retry` and `  back to last commit`; the selected line has the `>`. Under it, tiny dim text `[up/down] choose  [jump] ok`.
- **Input:** model it on `BenchMenu` (keyboard and touch both work). On the guest the menu is shown with the host's selection (a net field / snapshot field on the room or boss), and the guest's input does nothing; a line `host decides` in tiny text.
- **`back to last commit`:** exactly today's behaviour (`mgr.respawn(true)` / `_respawn_both()`).
- **`retry`:** counts a death, then reloads N15 with both players just inside the west door (x 24, y 144), full HP, the boss fresh in phase 1 and the hall reset (stage 0). The intro and the cutscene use their short versions (their flags are already set). Co-op: the host sends the guest a new reliable event (for example `retry` with fields `room`, `x4`, `y4`; **never name a field `i` or `k`**) that moves its body there with full HP, the same way `_send_guest_home` moves it to its bench. Look at how `respawn` and `swap_to` work and reuse them.
- Add a co-op scenario check (in `co-firewall`, §8) that both players end up in N15 phase 1 after a `retry`.

### 7.2 N01: `Connection refused`

- When a page's own player enters N01 and the flag `net:refused` is not set: set it, and play a 4 s scene drawn by the HUD (both pages: each page shows it for its own player's first entry): at 0.0 a red brick pattern flickers over the screen twice (0.15 s on, 0.15 s off), the `deny` sound, the `refused` voice with its cold subtitle; at 1.6 s the `sorry` voice with its green subtitle. The player keeps control.
- **Signal icon (decided):** on the HUD, right of the context meter, a small 9 × 7 px icon of three signal bars. While `net:refused` is set and `boss:FIREWALL` is not: red bars with a small red `x`. For 3 s after `boss:FIREWALL` is set: green bars; then hidden for good. (Reading two flags per frame is fine; do not walk `Game.flags`.)

### 7.3 Friendly signs (texts only; no map changes)

Use the existing signs and the sign `alt` mechanism (`{"text": ..., "alt": [{"if": "!boss:FIREWALL", "text": ...}]}`; the first alt that holds wins). The base `text` is what shows after the firewall is dead.

| room | sign | before (alt, `!boss:FIREWALL`) | after (text) |
|---|---|---|---|
| N03 | the only sign | `core_router: guests, the verification desk is east, past the review queue :)` | the current text |
| N12 | the only sign | `nmap: guests, please ride a packet to verification. :)` | the current text |
| N13 | sign 1 (`iptables -P INPUT DROP...`) | `Verification desk: this way :)` | the current text |
| N13 | sign 2 (`...-j HONEYPOT # nothing to see here`) | unchanged (the old warning stays) | unchanged |
| N14 | sign 1 (`dmz: the last bench...`) | `dmz: please wait here. You will be verified shortly.` | the current text |
| N21 | the only sign | add a second line: `script for guests: smile, then deny.` | same |

N13's window (`decor.gd` ~280, `shadow: "firewall"`): before the firewall dies, instead of the shield silhouette, a small green `EXIT` sign that flickers behind a red brick pattern; after, keep the current `200`.

### 7.4 After the fight

The hall starts in stage 3 when `boss:FIREWALL` is set (§4.1): burned lobby, cracked sunny window, stubs, stairs on both sides, no body, no packets. The friendly signs show their after texts (7.3).

### 7.5 CRAWLER's compact (M5)

In `crawler_boss.gd`, `_night()` only. When `Game.flag("boss:FIREWALL")` is set:
- replace the entry `"/net  connected"` with three entries: `"/net  connection refused"`, `"dmz  verified"`, `"ssh  ready"`;
- in the filler loop, at `i == 7`, also append `"FIREWALL: Are you what you say you are? Do you even know?"` (the crawler's own line stays at `i == 14`).

In `_step_death`, where `compacted:CRAWLER` is set, also set `compacted:FIREWALL` when `boss:FIREWALL` is set. In `logs_view.gd`, add `THE FIREWALL: [compacted]` (same style as the crawler's) when `compacted:FIREWALL` is set. Change nothing else in CRAWLER.

---

## 8. Tests

| test | where | what it must check |
|---|---|---|
| `firewall3` (new; replaces `firewall2`) | `godot/src/test/tests_4b3.gd` next to `t_crawler3`; replace `"firewall2"` in `NAMES3`, the `match`, and `tools/godot/test-all.sh` | grows per milestone: M1 map/hall (owned cells, stages, packets ride and drop the same on two computations with the same seed, no two drops within 1.0 s, hot-floor timings), M2 phase 1 (attacks seen, no contact damage from the door, bite after 2.0 s, bar 1 math), M3 cutscene (floor gone at 4.0, names switch, bar 2, rate limit: 3rd hit in 2 s → 429 + no damage, hit during cooldown → 5 s), M4 (west wall, walls never below 10 tiles, split gaps >= 0.35 s, no DROP ALL during split, green packets always drop), M5 (death timeline, stairs, flags), M6 (loss menu both options) |
| `bosspresets` | `tests_4b3.gd` | add rows for every FirewallBoss plan (2-damage cues >= 0.7 s) |
| `fightsim` | `tests_4b3.gd` | the attack mix per phase is not a fixed order; report phase lengths for a simulated good player; target ~60 s / ~80 s / ~80 s solo. If far off, change `T` in `rooms.json` and write the new number in this file and the Persian doc |
| `co-firewall` | `godot/src/test/coop_scenarios.gd` `sc_co_firewall` (rewrite; copy `sc_co_crawler`'s structure, `boss_arena("N15", ...)`) | both players see plans (targets p1 and p2), both fall in the cutscene, the guest rides packets, the guest's rate limit works (its 3rd quick hit → 429), phases 1-3 reached; M6: `retry` brings both back to phase 1. Run also with `BADLINE_ALL=1` |
| `parity` | | after any net-field change |
| `arenas`, `gfxcontrast`, `moodshift`, `perfrooms`, `tick5a` | | expected to need updates because of the new arena: fix them properly (the old v2 checks for N15 go; new ones for the new lights) |
| old tests reading the v2 boss | `tests_5a.gd` ~1394, `tests_4b2.gd` `fw_until` ~811, `tests_gfx.gd` ~499 and ~718 | update them to the new boss (keep what they test about other rooms) |

Known failures that are not the firewall's: `co-loopboss`, `co-shop` (timing; passes alone), `gfxother` (golden images not in the repo). Re-run once before calling anything else a flake.

**Screenshots** (look at them yourself; send the useful ones to Zakaria): add a scene helper `firewall:<hp>:<x>:<y>[:<secs>]` in `main.gd` (copy the `crawler:` helper ~262): `<hp>` the overall hp fraction (1.0 = phase 1 full, 0.6 = phase 2, 0.3 = phase 3, 0 with `<secs>` = the death scene at that second); add `firewall_cut:<secs>` for the cutscene at a given second. Take: M1 lobby, furnace phase 2, furnace phase 3 (no boss logic needed yet: set the hall stage directly); M2 the intro card and each phase-1 tell; M3 the cutscene at 0.6, 2.0, 3.5, 5.5 s and a `429`; M4 a split with two faces, DROP ALL with players on packets, green packets; M5 death at 2, 8 and 14 s and CRAWLER's compact showing the firewall line; M6 the loss menu, N01's scene, the HUD icon, a friendly sign, the after-state. Command: `WAIT=N bash tools/godot/shot.sh out.png <scene> gfx=high`.

Last milestone: the whole `bash tools/godot/test-all.sh` (~25 min), then the web export into `public/mv` as its own last commit.

---

## 9. Milestones (one session each)

### M1 · Arena

1. `rooms.json` N15: size `[24, 28]`, `"hall": "honeypot"`, boss `"cam": "free"`, `"trigger_x": 96`, `"name": "GUEST SERVICES"`, `"sub": "welcome, guest"` (keep id, class, reward, banner, doors). `world-phase45.json` N15 `h: 28`.
2. `rooms/N15.txt` exactly as §3.1.
3. `honeypot_hall.gd` (§4): masks, `apply`, `owns`, `reset`, stages, packets (pool in `room.plats`, `fw` flag, deterministic drops, green packets, `pdrop`), hot-floor drawing helpers (the hazards themselves come with the boss in M3, but write the drawing now), the two static wall nodes, carpet burn, stairs, after-state.
4. `room.gd` hooks (`hpot` var, creation, draw nodes, `step`, skip `fw` in `_move_platforms` and in platform drawing), `room_view.gd` (back wall from the hall, skip owned cells), `room_lights.gd` and `look.gd` (§4.4), the camera lock hook (§3.3).
5. A temporary way to set the stage for screenshots (`firewall:` helper with the boss inert is fine).
6. Tests: `firewall3` (M1 part), `arenas`, `gfxcontrast`, `mapdata`/`rooms` tests, `perfrooms` before/after. Screenshots: lobby, furnace phase 2 with packets, furnace phase 3, after-state.
7. Commit: `THE FIREWALL M1: the honeypot hall (N15 24x28), packets with inspection, hot floor`.

### M2 · Body and phase 1

1. Rewrite `firewall_boss.gd` (§5.1-5.3, §5.9 for the fields used so far, `music_now`, `hud_bar`). Phase 1 only: when bar 1 empties, simply hold at 0.70 (the cutscene comes in M3).
2. HUD hook (`hud_bar`).
3. Tests: `firewall3` (M2), `bosspresets` rows, `fightsim` (phase 1), `parity`, `co-firewall` (phase 1 part) with and without `BADLINE_ALL=1`. Screenshots: intro card, each tell.
4. Commit: `THE FIREWALL M2: the exit door and the honeypot's phase 1`.

### M3 · Cutscene and phase 2

1. The cutscene (§5.4), phase 2 (§5.5), rate limit and `429` (§5.6), hot floor hazards (§4.3), packets running from `pk_t0`.
2. Tests: `firewall3` (M3), `fightsim` (phase 2), `co-firewall` (both fall, guest rides packets, guest's 429). Screenshots: cutscene times, a 429.
3. Commit: `THE FIREWALL M3: the fake victory, the furnace and the rate limit`.

### M4 · Phase 3

1. §5.7: scene, west wall, hops, punch/flame/split, feint, DROP ALL, walls stepping on 429, last 15 % (plead line as a subtitle only until M5 brings the voice; green packets).
2. Tests: `firewall3` (M4), `fightsim` (phase 3), `co-firewall` (phase 3 reached). `perfrooms`. Screenshots: split, DROP ALL on packets, green packets.
3. Commit: `THE FIREWALL M4: two walls, a split face, DROP ALL`.

### M5 · Death, voices, sounds, music, logs

1. §5.8 death scene and stairs; §6 voices (script `--line`, files, JSON, CREDITS, `Audio.VOICE`) and sounds (script, `Audio.SFX`); §5.10 music; §7.5 CRAWLER compact + Logs.
2. `--import`, commit the `.import` files. Keep files small (the phone downloads the pck).
3. Tests: `firewall3` (M5), `crawler3` still passes, `logs`. Screenshots: death at 2, 8, 14 s; crawler compact with the firewall line (`crawler:0:200:300:18`-style helper).
4. Commit: `THE FIREWALL M5: the death scene, its voices and sounds, the line lost in the crawler's compact`.

### M6 · Loss menu, foreshadow, after-state, full tests, export

1. §7.1 loss menu, §7.2 N01 scene + signal icon, §7.3 signs and N13 window, §7.4 after-state.
2. Fix every test that changed because of the new boss (§8 table, last rows). Full `bash tools/godot/test-all.sh`. Then the web export to `public/mv` as its **own last commit**.
3. Screenshots: loss menu, N01 scene, HUD icon, a friendly sign, after-state.
4. Commits: `THE FIREWALL M6: retry or back to last commit, NETWORK's welcome, the after-state`, then `Web export: THE FIREWALL`.
5. Report to Zakaria in Persian: what he can test, and ask before anything goes to `main`.

---

## 10. Do not

- Draw warnings on the screen (hatched boxes, `!`, target markers), or any HUD text that announces an attack.
- Leave a fixed safe platform in the furnace.
- Change N12's packets, `IndexHall`, other bosses, or any room's map except N15's height (signs' texts in §7.3 and the N13 window drawing are the only edits outside N15).
- Change CRAWLER beyond §7.5.
- Add music files (use the placeholders in §5.10).
- Use any voice except the two in §6.
- Hurt or move the guest's body from the host except through hazards/harmboxes, `room.harm_zone` and the existing revive/respawn events.
- Walk `Game.flags` per frame; draw static things every frame.
- Skip, disable or weaken a test; push an empty commit; merge into `main`.
