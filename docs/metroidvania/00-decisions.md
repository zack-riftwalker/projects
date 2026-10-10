# 00 · Decisions so far (context for the executing agent)

This file is the self-contained summary of the research report Zakaria approved. The full Persian report (with sources) is a Claude Docs document: https://claude.ai/artifact/8MqVrs6Exvx7d2sAqYMdo2 (tabs: report, evaluation, roadmap). You may not be able to open it; everything you need is here.

All decisions below were approved by Zakaria on 2026-10-09 unless marked **open**. **§11 (the review of phase 0) is the latest word: where it differs from an earlier section, §11 wins.**

## 1. Direction

- Turn CLAWD into a **Metroidvania**: one interconnected map, ability-gated progression, backtracking, Hollow Knight-like difficulty.
- **Keep the coding theme.** Ideas taken from other games are re-expressed as programming concepts; the best ones make the mechanic *be* the concept (a race condition that desyncs, a deadlock that needs two simultaneous stuns).
- **Co-op stays** for every boss and enemy. Quality first, optimisation later.
- "Feel" work (hitstop, screen shake, art polish) is **later** (phase 6), but the bosses designed now are the ones that will be polished.

## 2. Engine and tools

| item | decision | notes |
|---|---|---|
| Engine | **Godot 4.7.2** (MIT), full rewrite | Conditional: must pass the phone test at the end of phase 1. The current game in `public/` is not touched and stays playable. |
| Verified in a cloud container | Godot 4.7.2 Linux binary runs `--headless`; with `xvfb-run` + `--rendering-driver opengl3` it renders and `get_viewport().get_texture().get_image().save_png()` works | Download: `https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip` (78 MB zip, 146 MB binary). Export templates: `slug=export_templates.tpz&platform=templates` (1.28 GB). ALSA errors under xvfb are harmless (audio falls back to dummy). |
| Map tool | ~~MetSys~~ → **ASCII room files + `rooms.json`** (§11 D12) | MetSys needs its editor GUI, which an agent cannot drive; revisit MetSys/LDtk when Zakaria wants to draw rooms with a mouse |
| Level editor (optional) | LDtk (MIT) + heygleeson/godot-ldtk-importer (MIT, Godot 4.1+) | for when Zakaria wants to draw rooms with a mouse |
| godot-mcp | not needed | the agent runs the Godot CLI directly |
| Platforms | **Web first** (same as now: friend joins by link), Windows and Android later from the same project | Godot web = Compatibility renderer / WebGL 2 only; single-threaded export is the default |
| Co-op transport | ~~WebRTC~~ → **WebSocket through the existing relay** (§11 D5) | WebRTC only if a phase 2 measurement shows TCP is not good enough |
| Art | Phase 1 captures the current code-drawn sprites to PNG with a headless browser | better art is phase 6 |
| Licensing | Take code only if MIT / Apache-2.0 / CC0, with credits. GPL and non-commercial: **ideas only, never copy code.** Commercial games' art/audio: never. | Names like "Claude"/"Opus" need a trademark check before any commercial release (risk noted, no action now) |

Code that may be reused (licenses checked): Godot, MetSys, LDtk importer, CodingQuests/godot-enemy-ai (MIT code, CC0 sprites; shared enemy state machine IDLE→CHASE→TELEGRAPH→ATTACK→RECOVERY→DEAD), wheafun/bread-adventure (Apache-2.0, a complete Godot 4.5 metroidvania), NoelFB/Celeste `Source/Player/Player.cs` (MIT, code only; movement reference), dannygaray60/toziuha-night-oota (MIT code, assets not free).

## 3. The map: 8 zones

The five current worlds become zones of one map, plus three new ones.

| zone | path | bosses | rewards (abilities) | entered with |
|---|---|---|---|---|
| THE SOURCE TREE (start) | `~/src` | NULL, THE REVIEWER #1 | bash, catch | start |
| DEPENDENCY DEPTHS | `~/node_modules` | MERGE CONFLICT, DEPENDENCY HELL (deep part) | agents, --force | bash (from SOURCE TREE) |
| THE HEAP | `/proc/heap` | THE LEAK | sudo | catch (from SOURCE TREE) |
| THE NETWORK (new) | `/net` | WEB CRAWLER, FIREWALL | curl, ssh | sudo (from THE HEAP) |
| THREAD TOWER | `/dev/threads` | RACE CONDITION, INFINITE LOOP | breakpoint, opus | curl (from THE NETWORK) |
| GIT HISTORY (new) | `.git` | REGRESSION | revert | ssh (from THE NETWORK) |
| PRODUCTION (final) | `/var/prod` | THE REVIEWER #3, THE MONOLITH | — | revert (from GIT HISTORY) and/or breakpoint (from THREAD TOWER) — **open** |
| KERNEL (secret) | `/boot` | KERNEL PANIC | true ending | --force, after THE MONOLITH (from DEPENDENCY DEPTHS) |

Also drawn: a shortcut from THREAD TOWER back to SOURCE TREE. **Open:** where THE REVIEWER #2 is fought (suggested: THE NETWORK), whether PRODUCTION needs one door or both, at least one alternative route so the order is not fixed (today SOURCE TREE → THE HEAP → THE NETWORK is forced).

## 4. Abilities (10)

| ability | status | what it does | gate it opens |
|---|---|---|---|
| bash | exists | 8-direction dash, breaks cracked blocks `%` and bugs, recharges on landing | cracked walls |
| agents | exists | context meter (tokens, kills) → two helpers hunt for 11 s | combat only today — **open:** give it an environment use |
| sudo | exists | double jump | high ledges |
| opus | exists | claw reach 30 instead of 24, damage 2 instead of 1 | combat only today — **open:** give it an environment use |
| catch | new | parry: catch an attack and throw it back (yellow = catchable) | from THE REVIEWER #1 |
| breakpoint | new | freezes an enemy or a moving platform for a few seconds | from RACE CONDITION |
| curl | new | grapple hook to special anchor points | from WEB CRAWLER |
| ssh | new | pass through thin "firewall" walls | from FIREWALL |
| revert | new | place a marker, later teleport back to it | from REGRESSION |
| --force | new | downward slam that breaks locked floors ("package-lock") | from DEPENDENCY HELL |

## 5. Bosses

### Current five, each gets new behaviour
| boss | today | new idea | inspired by |
|---|---|---|---|
| NULL | 3 attacks (cursor pokes, rain, screen-wide sweep then tired), 2 phases | phase 2 "dangling pointer": spots the cursor aimed at explode 1 s later; "dereference": throws the cursor and appears there with a slam; a feint poke | Palestag, Seth, Widow (Silksong) |
| MERGE CONFLICT | two heads, 3 attacks each | combined attack: three horizontal lasers `<<<<<<<` `=======` `>>>>>>>` with one safe gap; less in sync each phase; kill one head and not the other within 8 s → the dead one "reverts" at half HP | Cogwork Dancers, Mantis Lords |
| THE LEAK | shrinks when hit, flood rises per phase, 5 attacks | 3 waves of "allocation" enemies first; a Garbage Collector drone appears now and then, hitting it lowers the flood; phase 3 "out of memory": walls close in | Groal, Nyleth |
| INFINITE LOOP | snake, only the tail is vulnerable, 3 paths | a "break" switch in the arena freezes it for 3 s; phase 2 "nested loop": two snakes, inner one faster; head sticks in the floor 1 s after a dive | Fourth Chorus, Uumuu |
| THE MONOLITH | 3 phases, two fists, eye bolts, beam, adds | each phase needs one ability; final phase "refactor": splits into 4 "microservices", each with one attack, linked by "API call" lasers | Radiance, Lost Lace |

### New ten
| boss | core mechanic | inspired by | reward |
|---|---|---|---|
| THE REVIEWER | rival swordfighter met 3 times; parries your hits ("Changes requested"), faster each time | Lace, Hornet | catch |
| RACE CONDITION | two fast threads, in sync at first, more out of sync each phase; hitting one speeds up the other | Cogwork Dancers, Mantis Lords | breakpoint |
| WEB CRAWLER | robot spider; laser web lines, hangs from the ceiling and drops; an "indexing" beam tracks you | Grand Mother Silk, Moss Mother | curl |
| THE FIREWALL | shield in front; throws the shield and teleports to it; only hurt from behind or without the shield | Shrine Guardian Seth | ssh |
| REGRESSION | a shadow replays your last 5 s of movement; phase 2 two shadows; the boss takes your shape | Badeline (Celeste), Nosk | revert |
| DEPENDENCY HELL | throws packages that open into enemies; big packages contain smaller ones (node_modules); empty boxes stack into platforms | The Collector | --force |
| FORK BOMB (optional) | every hit makes a copy; only "PID 1" takes damage; > 16 copies → "system freeze" attack | Savage Beastfly | plugin |
| DEADLOCK (optional) | two chained bosses, only hurt while both are stunned at once; solo: the first stun lasts 4 s | Watcher Knights, Sisters of Battle | plugin |
| CRON (optional) | a "daemon" that appears in different rooms on a schedule; attacks on the music beat | Grimm, Cuphead | plugin |
| KERNEL PANIC (secret final) | after THE MONOLITH; blue screen, bullet hell, platforms appear and vanish | Radiance, Grand Mother Silk | true ending |

Not fights: **DEADLINE** (escape sequence from a red wall, like Ori), **CI PIPELINE** (boss rush, like Hollow Knight's Pantheons), **corrupted** rematches after the ending (like Lost Lace).

## 6. New enemies (12)

| enemy | behaviour | role | teaches |
|---|---|---|---|
| FIREWALL GUARD | blocks from the front; pogo from above or dash behind | tank | down-attack, bash |
| WORM | moves inside floor and walls; green particles show where it will come out | burrower | reading tells |
| ZOMBIE PROCESS | gets up 3 s after dying unless finished with a down-attack (`kill -9`) | walker | down-attack |
| FORK | nest that spawns a small Bug every 3 s until destroyed | support | target priority |
| SEGFAULT | walks to you, flashes red, explodes; the blast also breaks cracked walls | damage | using enemies for puzzles |
| DDOS | swarm of tiny packets, each dies in one hit | swarm | opus |
| EXCEPTION | throws yellow projectiles that `catch` can return | damage | catch |
| SPYWARE | fixed eye with a tracking laser; after 2 s of sight it alerts nearby enemies | support | breakpoint |
| STACK OVERFLOW | enemies that stack into a tower that topples onto you | tank | breakpoint (frozen tower = platform) |
| POLYMORPHIC | turns into another enemy type each time it is hit | variable | fast reactions |
| RANSOMWARE | on hit, locks your dash for 5 s and runs; killing it unlocks — **open:** keep it fair | debuff | chasing |
| BLOATWARE | big, slow, lots of HP, charge attack with a long tell | tank | patience |

Rules for all enemies: one shared state machine; mix roles in encounters (tank in front, shooter behind); colour is a rule (anything catchable is yellow). Stronger "CRITICAL" variants can be bounties, like Silksong's Grand Hunts.

## 7. Systems

- **Plugins:** like Hollow Knight charms; each costs some "context". Optional bosses give plugins.
- **Issue Tracker:** the bestiary; each enemy is an "issue" closed by killing it.
- **Save:** the current checkpoints become save and heal points.
- **Difficulty:** Hollow Knight-like by default, with an easier mode in the options. Numbers: **open** (MV0-07).

## 8. Co-op decisions

- **Cameras are separate.** Each player goes wherever they want. When one player enters a boss room, the other is teleported into it. (Decided by Zakaria.)
- Rules carried from the research (Bleed 2 developer blog, https://bootdiskrevolution.com/2021Blog/?p=995):
  - Boss HP in co-op: Bleed 2 adds only 25 %. The current game's co-op preset adds 50 % (`G.diff.PRESETS.coop`). **Open** (MV0-07).
  - A boss takes at most one hit per player per frame.
  - Wide attacks threaten both players; focused attacks switch target if the target runs away or the other player deals more damage.
  - The second player must never be stranded outside a boss arena and must be present in cutscenes.
  - Boss adds do not double with two players.
  - Mechanics that are better with two but possible solo: DEADLOCK, MERGE CONFLICT, THE FIREWALL, REGRESSION (shadows of both players).
  - The host computes the boss state (as today).

## 9. Roadmap

| phase | content | size | gate |
|---|---|---|---|
| 0 | design completion (this plan) | small | Zakaria approves the documents |
| 1 | Godot base: movement, art capture, web export, touch buttons | medium | **runs smoothly on Zakaria's Huawei Y9s (Firefox)?** If not: try an Android app; if that fails too, decide together before anything else |
| 2 | vertical slice: SOURCE TREE (8–10 rooms), NULL v2, 4 enemies (Bug, Typo, FIREWALL GUARD, ZOMBIE PROCESS), co-op | large | Zakaria and his friend approve feel and difficulty |
| 3 | THE REVIEWER #1 + catch, DEPENDENCY DEPTHS + MERGE CONFLICT, plugins | large | backtracking and map work |
| 4 | THE HEAP, THE NETWORK | large | each zone tested |
| 5 | THREAD TOWER, GIT HISTORY, DEPENDENCY HELL, PRODUCTION | large | whole game tested |
| 6 | optional bosses, KERNEL PANIC, feel, Windows and Android builds | medium | — |

Deferred on purpose: research on Metroid (incl. Dread's E.M.M.I.), Castlevania SotN, Blasphemous, Dead Cells and Ori happens when each boss is designed; ideas that use agents/context/tokens happen at boss design time; per-zone enemy tables happen when each zone is built.

## 10. Known risks

| risk | likelihood | impact | answer |
|---|---|---|---|
| Godot web is slow on the Huawei Y9s | medium | high | test at the end of phase 1 before anything else; light custom export template; Android app as fallback |
| separate-camera co-op is complex (host runs two rooms) | high | high | designed in phase 0, tested for real in phase 2 |
| scope (10 bosses, 12 enemies, 8 zones) | high | medium | phase by phase; optional bosses last; every phase is playable |
| the rewrite takes long | medium | medium | the current game stays playable; the vertical slice comes early |
| trademarked names if sold | low | high | check with a professional before a commercial release |

## 11. Decisions after the phase 0 review (2026-10-09)

Phase 0 was executed by Sonnet (`docs/reports/metroidvania-phase0.md`). Claude reviewed it, Zakaria approved the review ("اوکی"). These are final.

| # | decision | from |
|---|---|---|
| D1 | Back door DEPENDENCY DEPTHS → THE NETWORK, opened with `agents` (key in a slot), so the order is not fixed. | 03 |
| D2 | PRODUCTION opens with **either** door (revert from GIT HISTORY or breakpoint from THREAD TOWER). | 03 |
| D3 | `opus` and `agents` are upgrades, not required keys (except the optional back door). | 03 |
| D4 | THE REVIEWER #2 is fought in THE NETWORK's central room, **without** an extra lock on the exits: `curl` and `ssh` already gate THREAD TOWER and GIT HISTORY, so a player can go to THREAD TOWER right after WEB CRAWLER. (Changed from Sonnet's proposal.) | 03 |
| D5 | Co-op transport: WebSocket through the existing relay (`server.js`, later the Worker); the current protocol's envelope and reliable channel are kept. WebRTC only if a phase 2 measurement says TCP is not good enough. | 04 |
| D6 | Abilities, the explored map, doors and keys are shared; tokens and the plugin loadout are per player. | 04 |
| D7 | A player who goes down far from the partner gets up at the last safe ground of that room, not next to the partner; both down → each at their own bench. | 04 |
| D8 | Healing uses the context meter (33 per hp, +11 per hit); tokens become money for a later shop. | 05 |
| D9 | Boss HP comes from `HP = T × r × u`. The phase 0 numbers (NULL 60, …) are **provisional**: phase 2 measures `r` in real fights (the game records fight statistics) and the numbers are fixed after that. | 05 |
| D10 | Phone gate: pass at ≥ 55 fps average (low 1 % ≥ 40), **or** at a steady 30 fps with the 30-fps cap (avg ≥ 29.5, low 1 % ≥ 27), because the current game also draws at 30 fps on phones (`G.mobile` in `// js/main.js`). | 06 + review |
| D11 | Dash has **no** invulnerability in normal/hard/nightmare (the current game makes Clawd fully invulnerable while dashing: `hurt()` returns early when `dashT > 0`). Easy keeps it. A late upgrade will give dash invulnerability back (like Hollow Knight's Shade Cloak). | review |
| D12 | Rooms are ASCII text files in the current game's level format plus `rooms.json` (doors, origins, signs); the minimap is our own. No MetSys in phases 1–2. | review |
| D13 | Collision is the current game's tile AABB code ported to GDScript (no Godot physics): the feel stays identical (checked frame by frame against the JS game), the simulation is deterministic, and the host can run two rooms without separate physics worlds. | review |
| D14 | The Godot web build is served by `server.js` at `/mv/` over plain http. Godot normally refuses non-secure pages and its audio needs AudioWorklet (secure pages only); a small shell patch (ScriptProcessor audio driver + stub `addModule`) fixes both. Verified in Chromium on 2026-10-09; Firefox on the phone is checked in the phase 1 test. | review |
| D15 | Test builds reach Zakaria through the `ph1` branch with `update-branch.txt` (an existing updater feature), never through `main`, until the Godot version replaces the current game. | review |
| D16 | Co-op snapshots in phase 2 are full room snapshots (no deltas); deltas come later only if the measured bandwidth needs them. | review |
| D17 | Phase 2's SOURCE TREE = the three world 1 levels (edited) + five new rooms: bench before the boss, NULL arena, bash corridor, end door, secret room (`docs/PLAN-metroidvania-phase2.md` MV2-01). | review |
| D18 | New enemy SCRAPER (teaches `curl`) joins the enemy list. | 03 |

Plans: `docs/PLAN-metroidvania-phase1.md`, `docs/PLAN-metroidvania-phase2.md`.

## 12. Phase 3 decisions (2026-10-10)

Taken by Claude for the phase 3 plan (`docs/PLAN-metroidvania-phase3.md`), after phase 2 and the co-op review (`07-js-vs-godot.md`). The revive rule of `07-js-vs-godot.md` §5 (the 6 s revive only inside boss fights) stands.

| # | decision |
|---|---|
| D19 | Phase 3 has two parts, each ending with a build Zakaria tests: **3A** the rest of THE SOURCE TREE (THE REVIEWER #1, catch, plugins), **3B** DEPENDENCY DEPTHS (MERGE CONFLICT v2, agents, the shop). Each part is one Sonnet session. |
| D20 | Map: R08 (README.md) opens east into R09 (Makefile), a tall junction: one-way ledges up to R10 (THE REVIEWER arena) and R11 (try_catch.js, catch tutorial, plugin, "/proc/heap" end door); a low door down to D01. DEPTHS = D01–D03 (the three world 2 levels, edited), D04 (bench + shop), D05 (MERGE CONFLICT arena), D06 (agents tutorial, "/net" end door), D07 (secret). Only side doors: tall rooms use doors at their top and bottom. |
| D21 | D03 (version_hell.lock) is one-way downward; bench travel is the way back (rule R3 of `03-abilities-and-gates.md`). |
| D22 | **catch:** a swipe that starts at most `catch_window` before contact (0.10 s normal, 0.14 easy, 0.08 nightmare) catches a **yellow** projectile (it flies back at 1.5× speed, pierces, 2 damage, presses switches) or parries a catchable melee strike (the boss staggers). Outside the window the claw just destroys projectiles, as before. Yellow means catchable, always. |
| D23 | Catch switches `Y` open catch gates `!`; agents press slot keys `k` that open agents gates `&`; both stay open (flags) and travel to the guest as state. |
| D24 | **agents:** tap `special` with a full meter = two helpers for 11 s (spends the whole meter); hold `special` = focus (heal), as before. A cache station `R` refills the meter (20 s cooldown) next to every agents puzzle. |
| D25 | **Plugins:** 3 notches ("context window"); six plugins: async/await (dash cooldown 0.1), cache (pickup radius), hot-reload (faster focus), eslint --fix (+5 meter per hit), try/finally (+0.4 s invulnerability), rubber duck (claw ×2 at 1 hp). Equipped only at benches. Found plugins are shared in co-op; each player has their own loadout. |
| D26 | **Shop** (npm registry, in D04) sells four plugins for tokens (60–140). Each player pays from their own wallet. |
| D27 | **Boss HP** = `T × R_PLAYER × u × difficulty`. `R_PLAYER` (claw hits per player per second) is 1.0 until Zakaria's fight list gives the real value; then only that constant changes. NULL T 60 u 1; THE REVIEWER #1 T 70 u 0.7; MERGE CONFLICT T 90 u 1 (split over two heads). |
| D28 | **THE REVIEWER #1:** a duelist with lunge (catchable), comment bubbles (yellow, catchable), a counter stance ("CHANGES REQUESTED?": hitting into it is blocked and answered), a three-slash nitpick in phase 2 (the third is a big hit after a 0.7 s pause), and a shove against camping. He yields instead of exploding ("LGTM ✓ Approved") and returns later (#2, #3). Reward: catch. |
| D29 | **MERGE CONFLICT v2:** v1 plus conflict markers (three bands; the floor band or the platform band is safe, the high band never is; with one head left they fire one after another) and git revert (a dead head returns with half hp unless the other dies within 8 s). In co-op each head targets one player. Reward: agents. |
| D30 | **New enemies:** EXCEPTION (throws yellow, catchable errors; teaches catch) and FORK (a nest that spawns small bugs; feeds the meter for agents). World 2's Mimic, Logger, Noodle and Flaky are exact ports, checked frame by frame against the JS game. |

