# 00 · Decisions so far (context for the executing agent)

This file is the self-contained summary of the research report Zakaria approved. The full Persian report (with sources) is a Claude Docs document: https://claude.ai/artifact/8MqVrs6Exvx7d2sAqYMdo2 (tabs: report, evaluation, roadmap). You may not be able to open it; everything you need is here.

All decisions below were approved by Zakaria on 2026-10-09 unless marked **open**.

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
| Map tool | **MetSys** (KoBeWi/Metroidvania-System, MIT, needs Godot ≥ 4.6) | grid map editor, room transitions, minimap, collectibles, save data |
| Level editor (optional) | LDtk (MIT) + heygleeson/godot-ldtk-importer (MIT, Godot 4.1+) | for when Zakaria wants to draw rooms with a mouse |
| godot-mcp | not needed | the agent runs the Godot CLI directly |
| Platforms | **Web first** (same as now: friend joins by link), Windows and Android later from the same project | Godot web = Compatibility renderer / WebGL 2 only; single-threaded export is the default |
| Co-op transport (recommendation) | WebRTC between the two browsers (`WebRTCMultiplayerPeer`), with the existing `server.js` / Cloudflare Worker used only for signaling | WebRTC is built into Godot's web export; native builds need the webrtc-native GDExtension |
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
