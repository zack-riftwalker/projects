# CLAWD Metroidvania — Phase 0 Plan (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و برای دقت بیشتر انگلیسیه. سندهایی که Sonnet می‌سازه فارسی‌ان، تا خودت بخونی و تأیید کنی.
>
> **فاز ۰ چیه:** هیچ کدی از بازی فعلی عوض نمی‌شه. خروجیش ۵ تا سند طراحی و یه ابزار کوچیک برای نصب و تست Godot روی سروره، تا فاز ۱ بدون حدس شروع بشه.
>
> **کارها:**
> - انجام‌شده توسط Claude: خود این پلن، فهرست بازی فعلی (`01-current-game.md`)، خلاصه‌ی همه‌ی تصمیم‌ها (`00-decisions.md`)
> - برای Sonnet: ابزار Godot، تحقیق باس‌های اوپن سورس، توانایی‌ها و درها، طراحی Co-op، مدل سختی، پروتکل تست گوشی و گزارش آخر فاز
>
> **جای کار:** برنچ `ph1`. به `main` مرج نمی‌شه تا خودت بگی، پس `update.bat` و بازی‌ای که الان بازی می‌کنید دست نمی‌خوره.
>
> **آخر فاز:** Sonnet می‌ایسته و گزارش می‌ده. تو سندها رو می‌خونی و تأیید می‌کنی.
>
> **چطوری بدی به Sonnet:** یه جلسه‌ی جدید با مدل Sonnet روی برنچ `ph1` باز کن و بنویس:
> «فایل `docs/PLAN-metroidvania-phase0.md` رو بخون و فاز ۰ رو اجرا کن.»

---

## 0. Rules of engagement (read first)

- **Read before you start, in this order:** `CLAUDE.md`, this file, `docs/metroidvania/00-decisions.md`, `docs/metroidvania/01-current-game.md`.
- **Branch:** work on `ph1` only. Push with `git push -u origin ph1`. **Never merge into `main` and never open a PR**: everything on `main` reaches Zakaria's PC through `update.bat`.
- **Do not touch:** `public/`, `server.js`, `cloud/`, any `.bat`/`.ps1`, `tools/*.js`, `package*.json`, `wrangler.jsonc`, existing files under `docs/`. Phase 0 only **adds** files.
- **Where new files go:** design documents in `docs/metroidvania/`, Godot tooling in `tools/godot/`, the phase report in `docs/reports/metroidvania-phase0.md`.
- **One commit per task**, message prefixed with the task ID, e.g. `MV0-04: open-source bosses research`. End every commit message with the attribution lines your session gives you. Push after each commit.
- **Language of deliverables:** Persian, colloquial and short (Zakaria reads them), technical names in English. Short sentences, tables for anything with several attributes. This plan and code comments are English.
- **Sources:** every claim about another game links the page you actually opened, or is labelled «از حافظه». A search-result snippet is not a source. If a page will not open, say so in the document; never invent a mechanic, a number or a URL.
- **Claims about the current game** name the constant or function they come from (line numbers drift). `01-current-game.md` already has the numbers; re-check any you rely on.
- **Licences:** reading GPL or non-commercial source code to understand how a boss behaves is fine. Copying any of it is not. See `00-decisions.md` §2.
- **GitHub access:** this session's GitHub scope may not include other people's repositories. If you need to read a repository's source (MV0-03), request read access through the session's repository tool (`add_repo` with read access) rather than working around the scope. If it is refused, use public web pages and note the gap.
- **Ambiguity:** if this plan contradicts the code or `00-decisions.md`, follow the decisions file, take the smallest step that meets the task's goal, and note it in the phase report.
- **Stop at the end of phase 0** (after MV0-07) and report to Zakaria in Persian. Do not start phase 1.

---

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MV0-01 | this plan + docs index | Claude | done |
| MV0-02 | inventory of the current game → `docs/metroidvania/01-current-game.md` | Claude | done |
| MV0-02b | decisions summary → `docs/metroidvania/00-decisions.md` | Claude | done |
| MV0-03 | Godot tooling → `tools/godot/` | Sonnet | todo |
| MV0-04 | open-source bosses and enemies → `02-oss-bosses.md` | Sonnet | todo |
| MV0-05 | abilities and gates → `03-abilities-and-gates.md` | Sonnet | todo |
| MV0-06 | co-op with separate cameras → `04-coop-design.md` | Sonnet | todo |
| MV0-07 | difficulty model → `05-difficulty-model.md` | Sonnet | todo |
| MV0-08 | phone test protocol + phase report → `06-phase1-test.md`, `docs/reports/metroidvania-phase0.md` | Sonnet | todo |

**Order:** MV0-03 and MV0-04 are independent. MV0-05 after MV0-04 (its ideas may change abilities). MV0-06 and MV0-07 after MV0-05. MV0-08 last. Update the status column of `docs/metroidvania/README.md` in the same commit as each task.

---

## MV0-03 · Godot tooling

**Goal:** any later session can install Godot 4.7.2 in one command and prove it runs, headless and with a screenshot.

**Already known to work in this container (do not rediscover):**
- Download: `curl -sSL -o godot.zip "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip"` → `Godot_v4.7.2-stable_linux.x86_64` after unzip.
- Headless: `$GODOT --headless --path <project>` runs scripts; `print()` goes to stdout.
- Rendering: `xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path <project> --rendering-driver opengl3 --resolution 640x360`; inside the game, `get_viewport().get_texture().get_image().save_png(path)` writes a real image. ALSA errors are harmless; `--audio-driver Dummy` silences them.
- `xvfb-run` and `Xvfb` are installed at `/usr/bin`.

**Steps:**
1. `tools/godot/setup-godot.sh`
   - Installs into `${CLAWD_GODOT_DIR:-$HOME/.cache/clawd-godot}/4.7.2/`.
   - Idempotent: if the binary exists and `--version` prints `4.7.2.stable`, it does nothing.
   - Downloads to a temporary directory, unzips there, then moves the binary into place (never leave a half-written binary).
   - If a checksum file is published on the same host, verify it; otherwise print the zip's size and SHA-256 so the report can record them.
   - Prints the binary path on the last line, so other scripts can do `GODOT=$(tools/godot/setup-godot.sh | tail -1)`.
   - `set -euo pipefail`, clear error messages, exit non-zero on failure.
2. `tools/godot/smoke/` — a minimal Godot 4 project:
   - `project.godot` (`config_version=5`, a name, `run/main_scene`).
   - `main.tscn` with a `Node2D` root running `main.gd` and one visible shape (a coloured rect is enough).
   - `main.gd`: a three-state machine (`idle` → `attack` → `recover`) stepped in `_physics_process`, printing each transition with a fixed prefix (e.g. `smoke:`), then, unless `DisplayServer.get_name() == "headless"`, saving a screenshot to `user://` or a path passed as a user argument (after `--`), then `get_tree().quit()`.
   - Keep it under ~60 lines; it is a probe, not a game.
3. `tools/godot/smoke.sh`
   - Runs setup, then the headless run (pass = exit 0 and the final `smoke: done` line present), then the xvfb run (pass = PNG exists and is larger than 1 KB).
   - Prints `PASS`/`FAIL` per check and exits non-zero on any failure.
   - Writes outputs to a temporary or ignored directory, not into the repo.
4. `.gitignore` additions **inside `tools/godot/`** (a `tools/godot/.gitignore`, so the root `.gitignore` stays untouched): Godot's `.godot/` cache, `*.png` outputs, `*.import`.
5. `tools/godot/README.md` (Persian, short): what the scripts do, the two commands, how long the first run takes.

**Deliberately not done:** a SessionStart hook. Downloading 78 MB in every session that works on the current co-op game would be waste. Decide again at the start of phase 1.

**Done when:** `bash tools/godot/smoke.sh` prints PASS for every check in a fresh shell, twice in a row (the second run must skip the download). You looked at the PNG. Paste the output into the phase report.

---

## MV0-04 · Bosses and enemies of open-source games

**Goal:** fill the biggest gap in the report: ideas from **open-source** games' bosses and enemies (Zakaria's first request), not only from Hollow Knight and Silksong.

**Games:** Cave Story (engine: doukutsu-rs), Toziuha Night, Hurrican, Blob Wars: Attrition, Azimuth, SuperTux.

**Starting points (opened and verified by Claude):**
- Cave Story walkthrough: https://www.cavestory.one/guides/cavestory-3lifewalkthru.txt — Balrog is fought three times (2nd, 3rd, 4th fight in the guide's numbering); Monster X has 4 pods to destroy first, then homing missiles and rolling attacks; the Core opens to become vulnerable and every fourth opening blows you back with 20-damage projectiles; Ballos has four forms (Human, Orb, Orb with Eyes, Final).
- Blob Wars: Attrition: https://parallelrealities.itch.io/blob-wars-attrition — lists "Boss battles" and "Non-linear game progression"; the GPL source excludes data assets. Its in-repo gameplay manual lists the EyeDroid as an ordinary enemy.
- SuperTux 0.7 reworked the Yeti and Ghost Tree bosses (news on https://www.supertux.org/news/). Older descriptions: the Yeti is beaten by jumping on its head and attacks mainly with falling stalactites; the Ghost Tree is beaten using will-o-wisps that hurt on touch. These came from secondary pages; confirm before using.
- Hurrican: changelogs on WinFuture mention a dragon boss and a spider mid-boss (seen in search results only, not opened; confirm). No full list found yet.
- Toziuha Night: the developer's devlogs on https://dannygaray60.itch.io/toziuha-night-order-of-the-alchemists mention new bosses per update, and bosses are said to use the alchemy (element-combination) system (seen in search results only; confirm).
- Azimuth: no public boss list found; the GPL repo `mdsteele/azimuth` is the likely source.

**Steps:**
1. For each game, find its bosses and memorable enemies from walkthroughs, wikis, devlogs, manuals and, where pages are thin, the game's own source code (read only). Open every page you cite.
2. For each entry record: game, name, boss or enemy, what it does, what makes it special (one line), source link.
3. For each entry write the CLAWD idea: a programming-concept name and how the mechanic expresses it, and whether it is **new**, **strengthens** an existing idea in `00-decisions.md` (say which), or is **skipped** (say why).
4. End with a short list of the strongest new ideas, ranked, each with the zone it fits.

**Output:** `docs/metroidvania/02-oss-bosses.md` (Persian): one lead sentence, one table per game (or one big table if short), the ranked list, a sources list.

**Done when:** at least 15 bosses/enemies across at least 5 of the 6 games, each with an opened source; at least 6 ideas marked **new**; any game you could not research is named with the reason.

---

## MV0-05 · Abilities and gates

**Goal:** every ability has a concrete in-game obstacle, the map's open questions are closed, and the map is drawn again.

**Inputs:** `00-decisions.md` §3–§4, `02-oss-bosses.md`.

**Steps:**
1. One table, one row per ability (10 rows): movement verb · the obstacle it opens · what that obstacle looks like and how it behaves in a room · first zone where it is required · at least one backtracking secret it opens in an earlier zone · the enemy that teaches it (from §6 of the decisions, or a new one).
   - Starting suggestions you may change: catch → a switch hit only by a returned yellow projectile; curl → "endpoint" anchor nodes over gaps; ssh → thin firewall walls; revert → collapsing bridges / one-way doors you return through; breakpoint → freezing pistons, fans or an enemy to stand on; --force → "package-lock" floors. agents → hitting switches through small gaps; opus → cutting thick "spaghetti" cables.
2. Close these open questions, each with a one-line reason:
   - where THE REVIEWER #2 is fought;
   - whether PRODUCTION needs one door or both;
   - at least one alternative route so the first zones after SOURCE TREE can be done in more than one order, without allowing a softlock;
   - how agents and opus get an environment use.
3. Softlock check: list each zone and the abilities you could have when entering it; confirm every required obstacle in that zone can be passed with them, and that you cannot get stuck without the ability to leave.
4. Draw the updated map as a Mermaid `flowchart` in the document (zones as nodes, edges labelled with the ability), so it renders on GitHub. Claude will update the Docs diagram from it.

**Output:** `docs/metroidvania/03-abilities-and-gates.md` (Persian).

**Done when:** no obstacle is left without its look and behaviour, the four questions have answers, and the softlock table has no hole.

---

## MV0-06 · Co-op with separate cameras

**Goal:** a design for co-op in Godot that a phase 2 agent can implement without inventing rules.

**Inputs:** `00-decisions.md` §8, `01-current-game.md` §8, `CLAUDE.md` (co-op architecture), `docs/PROTOCOL.md`, `docs/PLAN-coop.md` and `docs/reports/phase*.md` (the bugs already met and fixed).

**Answer each question with a decision, the reason, and what would make you change it:**
1. **Ownership:** keep today's model (host owns the world, guest owns its own body and the damage it takes, guest hits are announced and checked by the host with a short hurtbox history)? How does it map onto Godot's multiplayer authority?
2. **Two rooms at once:** when the players are in different rooms, the host simulates both. Which rooms are active (only occupied ones? a neighbour too?), what happens to a room both players leave (freeze, reset like MetSys rooms), how enemies and items are kept consistent, and what it costs in CPU and bandwidth (rough numbers are fine, say they are estimates).
3. **Boss-room teleport:** exact trigger, warning time for the other player, what happens if the other player is mid-air, in a cutscene, or dead; the arena door locks behind both.
4. **Revive when apart:** today a downed player returns after 6 s (`REVIVE_T`) next to the partner if the partner is alive; both down restarts the level. What replaces "restart the level" in an open map (last checkpoint?), and where does a downed player return when the partner is far away?
5. **Shared or separate:** abilities, map exploration, keys and doors, tokens, plugins, save data. Who owns the save, what the guest keeps on its own device.
6. **Joining, leaving, disconnecting** mid-game, including a host disconnect (today: guest goes to the wait/map screen).
7. **Transport:** WebRTC between browsers with signaling over the existing `server.js` / Worker (recommended in the decisions) versus a WebSocket relay. The current relay protocol must keep working for the current game; new message types only, and only in phase 1+.
8. **Lessons kept:** list the concrete failures already fixed in the current co-op (see the reports and the "never name an event field `i` or `k`" rule) and how the new design avoids each from the start.
9. **Testing:** which of these can only be settled by a real test in phase 2; mark them clearly.

**Output:** `docs/metroidvania/04-coop-design.md` (Persian): a decisions table, a short diagram (Mermaid) of who sends what, the open-for-testing list.

**Done when:** all nine questions have a decision or are explicitly marked "test in phase 2" with the test described.

---

## MV0-07 · Difficulty model

**Goal:** numbers that let phase 2 design NULL v2 without guessing.

**Inputs:** `01-current-game.md` §2, §5, §6; Hollow Knight reference values — use a source you open, or label «از حافظه». Known from a fan guide (rogueranker.com; confirm or label): the Knight starts with 5 masks (max 9), 33 SOUL per Focus heal (rooted while healing, meter holds 99), nail damage from 5 up to 21 (Pure Nail).

**Decide and justify:**
1. Player HP: start value, maximum, how it grows (collectibles?).
2. Damage tiers: which attacks do 1, which do 2 (late bosses?), contact damage.
3. Healing: the mechanic (today: tokens, checkpoints, coffee). Does it use the context meter (which agents already use)? Is the player rooted while healing?
4. Invulnerability after a hit (today 1.3 s) and during dash.
5. Telegraph minimums: the shortest warning before an attack, for normal enemies, early bosses, late bosses; and the minimum punish window after a big attack.
6. Boss HP from player damage: target fight length (seconds), the player's realistic damage per second (today max ~3.7 hits/s, damage 1 or 2 with opus), resulting HP ranges per tier. Check the five current bosses against it.
7. Co-op scaling: Bleed 2 adds 25 % boss HP; the current game's co-op preset adds 50 % (`G.diff.PRESETS.coop`) and Zakaria plays with it. Pick one default, keep it tunable, explain.
8. Modes: the default (Hollow Knight-like) and the easier mode — which numbers change. Map them onto the current presets (`easy`, `normal`, `coop`, `hard`, `nightmare`) or replace them.

**Output:** `docs/metroidvania/05-difficulty-model.md` (Persian): one table of all numbers with their reason, and NULL v2 as a worked example (HP, phases, telegraph and punish times of its attacks in one small table).

**Done when:** every number in the table has a reason, and the NULL example uses only numbers from the table.

---

## MV0-08 · Phone test protocol and phase report

**Goal:** the phase 1 gate ("does it run smoothly on Zakaria's Huawei Y9s in Firefox?") is a measurement, not an impression.

**Steps:**
1. `docs/metroidvania/06-phase1-test.md` (Persian):
   - What is measured: frame rate (average and the slow 1 %), first and repeat load time, touch-to-action delay (at least a simple on-screen check), audio starting after the first tap, 10 minutes of play without overheating or memory growth.
   - How: an on-screen debug overlay in the phase 1 build (Godot's `Engine.get_frames_per_second()` and `Performance` monitors), a stopwatch for load time, the steps Zakaria follows, what he sends back (a screenshot of the overlay is enough).
   - Pass / fail thresholds, with the reason for each (state the frame-rate target the game is designed for).
   - Fallback: the same test on an Android build; if both fail, stop and decide with Zakaria.
   - Also test the PC browser and one mid-range phone if he has one.
2. `docs/reports/metroidvania-phase0.md` (Persian): what was done per task (with links), the smoke test output from MV0-03, decisions Zakaria must approve (from MV0-05, MV0-06, MV0-07, MV0-08), anything deferred and why.
3. Update `docs/metroidvania/README.md` so every row says done.

**Done when:** both files are pushed and the report lists every decision that needs Zakaria's approval.

---

## 2. Final report to Zakaria (in chat, Persian)

Short: what is ready, the link to `docs/reports/metroidvania-phase0.md` on branch `ph1`, the 4–6 decisions he needs to approve, and that phase 1 will not start until he says so.
