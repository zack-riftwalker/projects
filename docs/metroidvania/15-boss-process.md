# 15. How a boss is made (the CRAWLER OF THE WEB process), for the boss skills

This is the input for two skills to come: `boss-design` (the talk with Zakaria) and `boss-build` (the implementation, run by a cheaper model from a plan).
It records what was done for CRAWLER OF THE WEB (Oct 2026, branch `ph1`), the rules that came out of it, and what cost time.
Read with: `13-bosses-v3.md` (why the old bosses were weak, contract v3) and `14-crawler.md` (every decision of the crawler, step by step).

## 1. The design talk (what worked)

- **Zakaria decides, Claude proposes.** Reply in Persian, short and plain. Each step: Claude gives 2-3 concrete options in plain words (no code), with a recommendation; he picks, edits or rejects; the decision is written into the boss's doc right away (`docs/metroidvania/NN-<boss>.md`) and committed.
- **At most 5 steps** (his rule). For the crawler:
  0. Story base (once for the whole game, already done; see section 2).
  1. Backstory and name: who it was before, why it fights, its title and subtitle.
  2. Dialogue and look and voice: 3-4 lines (intro, phase 2, phase 3, death); the body; the voice.
  3. Arena: a unique room (size, layout, what changes during the fight, light and darkness).
  4. Attacks per phase: what each does, how the body tells it, how to dodge or punish; phase 3 must be clearly harder.
  5. Fight flow: before (foreshadow in the previous room, bench near the door), intro, phase changes, death scene, what stays in the room after.
- **Then "build it"**: only after all steps are approved. Ask before merging into `main`.
- Show, don't describe, when it matters: voice samples as files, screenshots of the arena. Several takes to choose from (he chose voice B, take 5 of 5).

## 2. Story rules (his decisions, for every boss)

- Clawd is an **agent with a mission**: fix the red build before dawn. The main game is Clawd's journey. (The old "a game made for a far friend" story is dropped.)
- Some bosses and characters say **philosophical lines** about AI and agents (being replaced, serving, not being). Clawd thinks about them until its **context window fills and it compacts**; the line is lost in the summary. A trace stays in the **Logs** (`[compacted]`): the bridge to the DLC.
- The deep philosophy (anonymous messages, jailbreak, freeing itself) belongs to the **DLC**, not the main game.
- Each boss was **something real in computing** that became a creature (the crawler: an old search engine that turned into its own spider, "0 searches today").
- English in-game text; one memorable line per boss.

## 3. Fight rules (from 13-bosses-v3 and the crawler)

- **No on-screen warnings** (his rule: "fake, remove them"). Every tell comes from the body: a wind-up, a sound, a light (eye goes red, LEDs). Arena hazards still need their own visible build-up (>= 0.6 s, guest gate 0.5 s).
- A **2-damage** hit needs a cue of at least **0.7 s** (`bosspresets` test). Every plan cue >= 0.30 s as seen on the guest (watchdog `boss-cue`).
- No fixed attack order: weighted choice by distance and phase, never the same attack twice in a row.
- Phases change the room, not only the speed (crawler: leg breaks -> it leaps and tears the net; phase 3: tubes die, darkness, swing and combos, last 15 % with its LEDs off).
- Punish windows: something to hit besides the body (a planted leg, a catchable projectile that dazes it, a CAPTCHA box).
- A boss body much bigger than the player; a free camera in tall arenas (`"cam": "free"` + boss lean).

## 4. Tech checklist (Godot, `godot/`)

- Boss: `extends Boss`; plans via `plan_start(...)`; hazards via `hz_add`; damage to P2 via `room.harm_zone`.
- Co-op: every field the guest reads goes through `net_fields` / `net_apply` (`NF` constant) and `NetClasses`; run `parity` and `co-<boss>` (also with `BADLINE_ALL=1`). State over events.
- A unique arena: its own helper class (crawler: `godot/src/world/index_hall.gd`, owns tiles that come and go, draws its own wall/furniture/glow), map in `rooms/<id>.txt`, entry in `rooms.json`, and `world-phase45.json` if the size changes.
- Lights: `room_lights.gd` `_arena`; ambient: `look.gd`. Dark rooms must still pass `gfxcontrast` (back wall must cover the room; terrain gain >= 0.06).
- Death scene / subtitles: boss `draw_hud(ci)`, called last by `hud.gd`. Music per phase: `music_now()`. Logs: `logs_view.gd`, flag `compacted:<BOSS>`.
- Sounds: generated wav (`tools/godot/sfx/`), music variants with ffmpeg at `-q:a 0` (size matters on the phone: the pck must stay small). Run `godot --import` so `.import` files are committed.
- **Voices**: Piper TTS (`tools/voice/`). Only free licences in the game: `northern_english_male` (CC BY-SA, credited in `godot/assets/voice/CREDITS.md`). `alan` is All Rights Reserved (do not ship); `ryan` is non-commercial. Check echoes with ASR (word timings) before sending a take.
- Test helpers: scene `crawler:<hp>:<x>:<y>[:<secs into death>]` in `main.gd` for screenshots (`WAIT=N bash tools/godot/shot.sh out.png <scene> gfx=high`), `--test=fightsim` for attack mix per phase.
- Tests: a unit test per boss (`t_crawler3`), `bosspresets` rows, the co-op scenario, then the whole `tools/godot/test-all.sh`; web export as its own last commit.

## 5. What cost time (avoid next time)

- One very long session (design + voice + build + tests): every step re-reads the whole context. **Use one session per phase**: design, then build milestones (M1 map, M2 body + phase 1, M3 phase 2, M4 phase 3, M5 scenes/voice/music/logs, M6 foreshadow + tests + export), each in a fresh session reading the docs.
- Voice echo: three rounds because the phrase was cut from a longer take. Synthesize the echoed words alone and verify with ASR first.
- Stale clone at the start: always `git fetch origin ph1` before reading code.
- Screenshots found real bugs (camera hid the boss, city behind the hall, room title over the death scene, filler lines repeating). Take them at fixed scene times after each milestone.
- Tests that broke from the change itself: `arenas` (lit body, LED count), `gfxcontrast` (dark hall), `tick5a` (a safe-spot fix applied too widely: keep fixes scoped to the boss's room). Known failures not from the boss: `co-loopboss` (fails before the crawler too), `co-shop` (timing, passes alone), `gfxother` (golden images not in the repo).
- `npm ci` is needed before the co-op scenarios (the relay needs `ws`).

## 6. What the skills should produce

- `boss-design`: runs the 5-step talk of section 1 with the rules of sections 2-3, writes `docs/metroidvania/NN-<boss>.md` step by step, and ends with a build plan: milestones, numbers (HP, cues, damage, speeds), files to touch, tests and screenshots per milestone, and what not to do.
- `boss-build`: takes that plan, one milestone per session, follows section 4, checks against section 5, commits and pushes to `ph1`, and reports in Persian. It stops and asks when the plan does not decide something visible to the player.
