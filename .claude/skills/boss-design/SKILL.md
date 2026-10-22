---
name: boss-design
description: Design a new boss for the Godot version of CLAWD with Zakaria, in a short step-by-step talk (backstory, dialogue/look/voice, arena, attacks, fight flow), writing each decision into docs/metroidvania/NN-<boss>.md and ending with a build plan for boss-build. Use when he asks to design, redesign or "make" a boss, or says something like «باس بعدی رو طراحی کنیم» / «بریم سراغ باس X». Not for implementing: that is boss-build.
---

# boss-design

The process that made CRAWLER OF THE WEB, as a repeatable talk.
Sources: `docs/metroidvania/15-boss-process.md` (the process), `14-crawler.md` (a full worked example), `13-bosses-v3.md` (why old bosses were weak, contract v3).
Also read the story bible `docs/studio/STORY.md` (the `story` skill keeps it) when it exists: the boss's place in the tale comes from there.
Read all of them before the first message, after `git fetch origin ph1 && git pull origin ph1` (a stale clone cost time before).

## How the talk runs

- **Zakaria decides, Claude proposes.** Persian, short and plain, no code in the talk.
- Each step: 2-3 concrete options in plain words, one marked as the recommendation. He picks, edits or rejects.
- Write the decision into the boss doc **right away** (same turn), commit and push to `ph1`. Mark the step's row in the status table with the date.
- **At most 5 steps** (his rule). Don't add steps; fold questions into the nearest step.
- Show, don't describe, when it matters: voice takes as audio files (several takes), arena screenshots. Send files with SendUserFile.
- Never start building during the talk. "Build it" comes only after all 5 steps are approved, and then it is boss-build's job, in a fresh session.

## The boss doc

Path: `docs/metroidvania/NN-<boss>.md`, NN = next free number in that folder. Write it in Persian like `14-crawler.md`; in-game text stays English.
Start with: a one-line result, the source docs, who builds it, and a status table:

| step | status |
|---|---|
| 1 · story and character | ... |
| 2 · look and voice | ... |
| 3 · arena | ... |
| 4 · attacks | ... |
| 5 · fight flow | ... |

Keep rejected ideas briefly at the end ("ideas set aside"), so they are not proposed again.

## The 5 steps

Step 0, the story base, is already decided for the whole game (section "Story rules" below); don't reopen it.

1. **Backstory and name.** Who it was before (something real in computing that became a creature), why it fights Clawd, mood, title and subtitle. Dialogue: 3-4 English lines (intro, phase 2, phase 3, death), one of them the memorable line. If it is a philosophical boss, design its compact scene (see 14-crawler.md, "صحنه‌ی compact").
2. **Look and voice.** Body (much bigger than Clawd, ~16 px), its own palette against the area's, how it moves, how its body and lights tell attacks, per-phase look. Ambient sounds, music per phase, speaking voice. Voice takes: Piper (`tools/voice/`, see `crawler_voice.py`), only shippable voices (see below). Synthesize echoed words alone and check word timings with ASR before sending a take.
3. **Arena.** A unique room: check free space on the map (`docs/metroidvania/world-phase45.json`, neighbours' rows/columns) before proposing a size. Layout, what changes per phase (the room, not only the speed), light and darkness. Dark rooms must stay readable.
4. **Attacks per phase.** Table per phase: attack, how you know (body tell), what happens, how to dodge, damage, punish window. Plus arena pressure per phase. Phase 3 must be clearly harder (combos, shorter windows, shrinking arena). Check the boss is beatable with the abilities the player can surely have when reaching it (crawler: bash, catch, jump, wall jump; no sudo).
5. **Fight flow.** Foreshadow in the previous room, a bench near the door, intro (skippable from the 2nd time), phase changes (at which HP %, how long, invulnerable), HP and difficulty (from `Game.boss_hp`), co-op (targets, revive), losing, winning (reward, door), what stays in the room after.

## Story rules (his decisions, every boss)

- Clawd is an agent with a mission: fix the red build before dawn. The main game is that journey.
- Some bosses say a philosophical line about AI/agents (being replaced, serving, not being). Clawd thinks until its context window fills and compacts; the line is lost in the summary; a grey `[compacted]` line stays in Logs (flag `compacted:<BOSS>`). That is the bridge to the DLC.
- Deep philosophy (anonymous messages, jailbreak, freeing itself) is DLC only.
- English in-game text, one memorable line per boss.

## Fight rules (check every proposal)

- **No on-screen warnings** ("fake, remove them"). Every tell is the body: wind-up, sound, light. Arena hazards still get a visible build-up >= 0.6 s.
- A 2-damage hit needs a cue >= 0.7 s; every cue >= 0.30 s as seen by the guest.
- No fixed attack order: weighted choice by distance and phase, never the same attack twice in a row.
- Damage: normal 1, heavy 2.
- Each cycle has a big punish window; give something to hit besides the body (a stuck leg, a returnable projectile, a box).
- Phases change the room. Never let the arena shrink below a beatable minimum (crawler: >= 4 platforms).
- Tall arena → free camera (`"cam": "free"`) with boss lean.
- Co-op: both players see every scene; targets alternate; revive 6 s.

## Ending: the build plan

When step 5 is approved, add a section "## Build plan" to the boss doc, written so a cheaper model can build it without guessing. It must have:

- **Milestones**, one per build session: M1 map/arena, M2 body + phase 1, M3 phase 2, M4 phase 3, M5 scenes/voice/music/logs, M6 foreshadow + bench + full tests + web export. Merge or split if this boss needs it.
- **Numbers**: HP and the per-phase split, phase thresholds, every cue/active/recovery time, damage, speeds, punish window lengths, hazard build-ups, intro and scene timings.
- **Files to touch** per milestone (see boss-build's file map).
- **Tests and screenshots** per milestone: which unit test, `bosspresets` rows, the `co-<boss>` scenario, fixed scene times for screenshots.
- **Open questions**: anything visible to the player the plan does not settle. Better to ask now.
- **What not to do**: e.g. no on-screen warnings, no fixes outside the boss's room, no unshippable voice.

Then tell him in Persian that the design is done and the build starts in a new session with boss-build (one milestone per session). Ask before merging anything into `main`.
