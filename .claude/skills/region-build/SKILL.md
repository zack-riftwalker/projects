---
name: region-build
description: Build (part of) a region of the Godot version of CLAWD from its approved build plan (docs/PLAN-metroidvania-<region>.md, written by the world department), one milestone or brief per session, with the plan's tests, screenshots and playtest steps, committing and pushing to ph1. Use when a brief in docs/studio/briefs/ names region-build, or Zakaria says «منطقه رو بساز» / names a region milestone. Not for designing a region (world) or a boss fight (boss-build).
---

# region-build

A short session that builds what the world department designed. It does not design: if the plan is wrong or unclear, stop and write it to the inbox of `docs/studio/WORLD.md` (and tell Zakaria in one Persian line) instead of improvising.

## Before coding

1. `git pull origin ph1`. Read `CLAUDE.md` (Godot section: co-op rules, speed rules, tests), `docs/studio/README.md`, the brief, and the plan's milestone plus its «facts» and «shared definitions».
2. Verify the plan's facts on the current `ph1` (other sessions push in parallel): file paths, class indices in `NetClasses`, letters already used by room files, the rooms count in `rooms.json`. A fact that changed → adapt the smallest way and note it as a deviation.
3. `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`.

## Building

- Rooms come from the plan's data folder (`docs/metroidvania/<phase>-data/apply.py`), not drawn by hand in the session.
- New region checker: copy it to `tools/godot/roomcheck/` and add it to `tools/godot/test-all.sh`, like the earlier `check*.py`. The older checkers must still print `0 problems`, `world.py` `errors 0`.
- Co-op rules from CLAUDE.md for every new enemy, machine or gate (state over events, `NetClasses.record/apply`, `room.harm_zone`, a watchdog rule for a new kind of desync). Add the plan's `co-*` scenarios.
- Speed rules: nothing per frame walks `Game.flags`; static drawing once. Run `--test=perfrooms` before and after a region's rooms land.

## Done

1. The milestone's tests, then `bash tools/godot/test-all.sh` → all pass (re-run timing-sensitive ones once before calling them real).
2. Screenshots the plan names → `docs/reports/img-<phase>/`; send the key ones to him with SendUserFile.
3. Web export (`public/mv`) as its own last commit.
4. Report `docs/reports/metroidvania-<phase>.md` (what was built, deviations, test results, what felt easy or unfair in the bots), and **playtest steps in Persian** → also a row in «منتظر تست» of `docs/studio/PLAYTEST.md`.
5. Tick the task on `docs/studio/PRODUCER.md`, mark the brief done (move it to `docs/studio/briefs/done/`), and put anything found for other departments in their «صندوق».
6. Push to `ph1`. Never merge into `main` without his OK. Then stop: the next milestone is the next session.
