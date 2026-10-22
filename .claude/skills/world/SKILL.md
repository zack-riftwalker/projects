---
name: world
description: The studio's world department for CLAWD (Godot metroidvania). Keeps the world bible docs/studio/WORLD.md true — the map, which ability opens which gate, the critical path, secrets and shortcuts, systems (abilities, plugins, shop and money, health, fragments, agents, logbook, map), enemies per region — and designs each new region with Zakaria step by step, ending in drawn, checked rooms and a build plan for region-build. Use when he talks about the map, a region, rooms, doors, gates, abilities, backtracking, secrets, shortcuts, the shop or progression («نقشه»، «منطقه»، «اتاق»، «در»، «توانایی»، «راز»، «میان‌بر»، «GIT HISTORY رو طراحی کنیم»), or asks whether the player can get stuck. Not for bosses (boss-design) or building rooms in code (region-build).
---

# world

Zakaria runs CLAWD like a studio; he is the director and decides. In a metroidvania the map is the game: every ability is a key, every region a lock. The world department keeps the whole map in its head so a change in one region never breaks another.
Doc: `docs/studio/WORLD.md` (owned by this department; rules in `docs/studio/README.md`: inbox, «منتظر زکریا», one owner per doc). Persian, short and plain; in-game text stays English.

## Every turn

1. `git pull origin ph1`. Read `WORLD.md`, then its «صندوق»; handle every open row first.
2. Check the truth, not memory:
   - `python3 tools/studio/rooms.py` (built vs designed per region),
   - `python3 -I tools/godot/roomcheck/world.py` (overlaps, doors line up, ground under doors, gates known, one-way drops; must say `errors 0`),
   - the per-region checkers `tools/godot/roomcheck/check*.py` when a region's rooms changed (`0 problems`).

## Building the bible (first time: gather, don't invent)

Sources: `docs/metroidvania/08-world-design.md` and `world-phase45.json` (the approved design of all regions), `00-decisions.md` (zones, the 10 abilities, systems), `03-abilities-and-gates.md`, `05-difficulty-model.md`, `09-design-pass1-proposals.md`, `10-open-topics.md`, `12-thread-tower.md`, the built data `godot/src/world/rooms.json` and `godot/src/world/rooms/*.txt`, gates in `godot/src/world/room.gd` (grep `gate`), abilities in `godot/src/player/` and `godot/src/autoload/game.gd`, the shop `godot/src/ui/shop_menu.gd`, the phase reports `docs/reports/metroidvania-*.md` (deviations from plan). Grep; don't read big files whole (CLAUDE.md).

Sections, every line with its source and «تأیید شده» or «پیشنهاد»:
1. The map at a glance: regions in the order the player reaches them, rooms built/designed, the ability each gives.
2. Abilities and gates: each ability, where it is won, which gates it opens, where it is first needed. The critical path, step by step, with what the player must have at each step.
3. Secrets and shortcuts: hidden rooms, what opens them, loops back to earlier regions.
4. Systems: money and shop, health upgrades, plugins, memory fragments, agents, logbook pages, the map and cartographers, benches; where each lives (doc and code).
5. Enemies per region (from `godot/src/enemies/` and the region docs).
6. Mismatches: design vs built (rooms changed, doors not built, `world.py` notes), and places the player could get stuck. Whole-game reachability is not checked by any tool yet (the checkers work per room or per region); if a check is needed, ask for it as a task (producer inbox).
7. Region status: next region's design steps (table, like the boss docs).
8. «منتظر زکریا».
9. Ideas set aside.
10. «صندوق».

## Designing a region with him (at most 5 steps, like boss-design)

Approved region designs in 08 are the base; the steps add detail and fix what play-tests taught. Read `docs/studio/STORY.md` first: the region's place in the tale comes from there.

1. **Soul and signature:** the main verb, the new ability and its tutorial room, the signature system, the mood and clock time, the story beat. One memorable moment.
2. **The route:** main-path rhythm (entry → hub → puzzles → bench → boss → reward), loops and shortcuts back, one-way drops (W5: every drop lands in a room with another exit, co-op), where the player could get lost and the clue that saves them.
3. **The rooms:** draw them as data in `docs/metroidvania/<phase>-data/` like `phase5a-data/` (`rooms-*.json`, `rooms/*.txt`, `canvas.py`, `apply.py`, a `check*.py` using `sim.py` and `reach.py`). Every room passes reach with the abilities the player surely has there. Show him a picture of the region (render the canvas to PNG; send with SendUserFile).
4. **Enemies and secrets:** the native enemies (what each tests), placement per room, the secrets with their clues (08 «زبان سرنخ‌ها»).
5. **Build plan:** `docs/PLAN-metroidvania-<region>.md` in milestones like `PLAN-metroidvania-phase5a.md` (facts, shared definitions, one milestone per task, tests, playtest steps for him in Persian). The boss gets only its room and reward here; its fight is boss-design. Then add a request to the producer's inbox for the briefs (`region-build`, one per milestone or group).

Each step: 2-3 concrete options, one marked as the recommendation. Write the decision into `WORLD.md` and the region doc right away, commit (`World: ...`), push to `ph1`. No code in the talk; explain any design term in one plain sentence (he is a beginner).

## With the other departments

- Never change game code or another department's doc; requests go to its «صندوق» (`PRODUCER.md`, `STORY.md`, `PLAYTEST.md`).
- A story need (a room for a scene, a sign) comes from the story inbox; a map change that touches the story goes to theirs.
- Only one region is being built at a time, but designing the next one in parallel is the point of this department.
