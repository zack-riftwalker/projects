---
name: boss-build
description: Build a boss in the Godot version of CLAWD (godot/) from the build plan in its design doc (docs/metroidvania/NN-<boss>.md), one milestone per session, with the tests and screenshots the plan names, committing and pushing to ph1. Use when Zakaria says "build it", «بساز», «مایلستون بعدی», or names a milestone (M1..M6) of a designed boss. Not for designing: that is boss-design.
---

# boss-build

Builds one milestone of a boss designed with boss-design. The reference build is CRAWLER OF THE WEB (`godot/src/enemies/crawler_boss.gd`, `godot/src/world/index_hall.gd`); copy its patterns.

## Start of every session

1. `git fetch origin ph1 && git checkout ph1 && git pull origin ph1` (a stale clone cost time before).
2. Read: the boss doc (`docs/metroidvania/NN-<boss>.md`, especially "Build plan"), `docs/metroidvania/15-boss-process.md` sections 3-5, and `docs/metroidvania/07-js-vs-godot.md` §3 (co-op rules).
3. Find the next milestone not marked done in the plan. Build **only that one**. One milestone per session keeps the context small.
4. `npm ci` if `node_modules` is missing (co-op scenarios need `ws`). Godot: `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`.

## When to stop and ask

Stop and ask Zakaria (in Persian, short) when the plan does not decide something **visible to the player**: a look, a timing he would feel, a line of text, a sound, a difficulty number not in the plan. Give 2 options and a recommendation. Internal choices (names, structure) are yours. Never invent new dialogue.

## Rules that must hold

- **No on-screen warnings.** Tells come from the body (wind-up, sound, light). Arena hazards: visible build-up >= 0.6 s (guest gate 0.5 s).
- 2-damage hits: cue >= 0.7 s (`bosspresets`). Every plan cue >= 0.30 s on the guest (watchdog `boss-cue`).
- Weighted attack choice by distance and phase; never the same attack twice in a row.
- **State over events:** anything that must be right now (music, locks, deaths, arena tiles, darkness) is derived each frame or carried in snapshots.
- Host-side damage to P2 only through `room.harm_zone`.
- Every creature field the guest reads goes through `net_fields` / `net_apply` (the `NF` constant) and `NetClasses.record/apply`, or `parity` fails.
- Nothing per frame or per snapshot walks `Game.flags`; cache on `Game.flags.hash()`. Static drawing is drawn once in its own node.
- **Keep fixes scoped to the boss's room** (a safe-spot fix applied too widely broke `tick5a`).
- A new kind of co-op bug gets a rule in `godot/src/net/watchdog.gd`.
- Voices: only shippable licences. `en_GB-northern_english_male-medium` (CC BY-SA, credit in `godot/assets/voice/CREDITS.md`) is OK; `alan` (All Rights Reserved) and `ryan` (non-commercial) never ship.
- Never put a key, IP or anything personal in the repo.

## File map

| what | where |
|---|---|
| boss class | `godot/src/enemies/<boss>_boss.gd`, `extends Boss` (`godot/src/enemies/boss.gd`): plans via `plan_start(id, fam, tgt, fp, lock, cue, rec, act)`, hazards via `hz_add(kind, warn, v)` |
| arena helper | `godot/src/world/<arena>.gd` like `index_hall.gd`: tiles that come and go, its own wall/furniture/glow drawing |
| room map | `godot/src/world/rooms/<id>.txt`, entry in `godot/src/world/rooms.json` (`"cam": "free"` for tall arenas); `docs/metroidvania/world-phase45.json` if the size changes |
| co-op damage | `room.harm_zone(kind, x, y, a, b, dmg)` in `godot/src/world/room.gd` |
| lights / ambient | `godot/src/world/room_lights.gd` (`_arena`), `godot/src/world/look.gd` |
| HUD, death scene, subtitles | boss `draw_hud(ci)`, called last by `godot/src/ui/hud.gd` |
| music per phase | boss `music_now()`; files in `godot/assets/music/` |
| logs trace | `godot/src/ui/logs_view.gd`, flag `compacted:<BOSS>` |
| sounds | generated wav, script in `tools/godot/sfx/` (like `make_crawler_sfx.py`) |
| voice | `tools/voice/` (like `crawler_voice.py`), output `godot/assets/voice/<boss>_*.ogg` + `<boss>.json` |
| screenshot scene | `<boss>:<hp>:<x>:<y>[:<secs into death>]` in `godot/src/main.gd` (copy the `crawler:` helper) |
| unit tests | `godot/src/test/tests_4b3.gd` (like `t_crawler3`, `t_bosspresets`, `t_fightsim`) or a new tests file registered the same way |
| co-op scenario | `godot/src/test/coop_scenarios.gd` (like `sc_co_crawler`), run as `co-<boss>` |

## Assets

- Music variants with ffmpeg at `-q:a 0`; keep files small (the phone downloads the pck). A lowpassed variant can use a lower bitrate.
- After adding any asset: `$GODOT --headless --path godot --import` and commit the `.import` files.
- Voice echoes: synthesize the echoed words alone, check word timings with ASR, then send takes as files for him to pick.

## Testing per milestone

- The unit test for the boss: `$GODOT --headless --path godot -- --test=<name>`; add rows to `bosspresets`; `--test=fightsim` for the attack mix per phase.
- Co-op: `bash tools/godot/coop-test.sh co-<boss>`, and again with `BADLINE_ALL=1`. `--test=parity` after any net field change.
- Speed: `--test=perfrooms` / `perfgrow` before and after when you add drawing or per-frame work.
- **Screenshots at fixed scene times** after each milestone: `WAIT=N bash tools/godot/shot.sh out.png <boss>:<hp>:<x>:<y> gfx=high`. Look at them yourself: they found real bugs (camera hid the boss, city behind the hall, room title over the death scene, repeating filler lines). Send the useful ones to him.
- Expect these to break from the change itself and fix them properly (never skip or disable a test): `arenas` (lit body, LED count), `gfxcontrast` (dark room: back wall must cover the room, terrain gain >= 0.06), `tick5a`.
- Known failures not from a boss: `co-loopboss` (fails before the crawler too), `co-shop` (timing; passes alone), `gfxother` (golden images not in the repo). Re-run once before calling anything else a flake.
- Last milestone: the whole `bash tools/godot/test-all.sh` (~25 min).

## Commit and report

- Commit with clear messages, push to `ph1` (`git push -u origin ph1`).
- When `public/mv` is re-exported, it is its **own last commit**. Both pages must run the same build.
- Mark the milestone done in the boss doc's build plan, with anything that changed from the plan.
- Report to Zakaria in Persian, short: what was built, test results (honestly, with failures), screenshots, what the next milestone is (in a new session). Ask before merging into `main`.
