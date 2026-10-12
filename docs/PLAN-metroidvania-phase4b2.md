# CLAWD Metroidvania — Phase 4B-2 Plan: THE NETWORK (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. گام ۵ از پلن کلیه: منطقه‌ی **THE NETWORK**. همه‌ی تصمیم‌ها گرفته شدن و Sonnet فقط اجرا می‌کنه.
>
> **کِی:** فقط بعد از اینکه 4B-0 و 4B-1 تموم شدن (گزارش هر دو تو `docs/reports/` باشه). این پلن روی کیت باس 4B-0 و نقشه، `tree`، ایجنت‌ها و دفترچه‌ی 4B-1 ساخته می‌شه.
>
> **چی ساخته می‌شه:**
> - **۲۲ اتاق NETWORK.** نقشه‌ی همه‌شون رو خودم کشیدم و با شبیه‌ساز حرکت Clawd (حالا با curl و ssh) چک کردم: هر در رسیدنیه، هر راز با توانایی خودش باز می‌شه و بدون اون نه.
>   - دو ورودی: از HEAP (mmap.c) و از DEPTHS (.npmrc، پشت دروازه‌ی agents). کل مسیر اصلی با bash و catch رد می‌شه، پس کسی که از DEPTHS بیاد و sudo نداشته باشه هم گیر نمی‌کنه.
>   - یه اتاق تازه نسبت به طرح: **review_queue** زیر هاب، که آرنای REVIEWER #2 ـه (توضیح پایین).
> - **دو توانایی تازه:**
>   - **curl:** نزدیک یه حلقه‌ی آبی GET دکمه‌ی SPEC رو بزن؛ Clawd با کابل به حلقه می‌پره و از اونجا به جلو پرتاب می‌شه. حلقه‌ها زنجیر می‌شن. روی گوشی حلقه‌ای که الان می‌گیری یه علامت داره و دکمه‌ی SPEC می‌شه `GET`.
>   - **ssh:** ۰.۳ ثانیه رو به آجر قرمز فایروال فشار بده؛ ازش رد می‌شی (حداکثر دو آجر).
> - **سه باس، همه روی کیت باس 4B-0** (هشدار قبل از هر حمله، صبر برای مهمون، «باس هوشمند»):
>   - **WEB CRAWLER** (جایزه curl): عنکبوتی روی چهار گره‌ی سقف. پاش رو جای تو می‌کوبه، بعد پایین میاد و می‌شه زدش. بسته‌های زردش رو با catch برگردونی. گره‌ی بالای سر کسی که زیرش وایساده رو انتخاب می‌کنه.
>   - **THE FIREWALL** (جایزه ssh): سپر جلوش؛ سپر رو پرت می‌کنه و برمی‌گردونه. «port scan» دو تا از سه خط رو می‌سوزونه. تو فاز ۲ خودش از دیوار نازک رد می‌شه، یعنی ssh رو قبل از دادنش نشون می‌ده. سپر رو سمت کسی می‌چرخونه که آخر زده.
>   - **THE REVIEWER #2** (اختیاری، جایزه پلاگین review cache): زیر هاب یه صندلی خالیه با تابلوی `2nd review: pending`. وقتی curl یا ssh داشتی، روش بشین (بالا) تا بازبینی دوم شروع بشه. به آخرین نوع حمله‌ات جواب می‌ده.
> - **دشمن‌های تازه:** SCRAPER (از قلاب آویزونه و پایین میاد)، WORM (توی آجر فایروال)، DDOS (گله‌ی بسته‌های ریز)، SPYWARE (چشم با لیزر).
> - **صحنه‌ها:** سواری روی بسته از پورت‌ها (port_scan)، زنجیره‌ی curl روی airgap (افتادن یعنی فرود روی پل eth0، نه مرگ)، دریچه‌ی honeypot با موج DDOS، و اهرم loopback که دروازه‌ی DEPTHS رو از این طرف باز می‌کنه.
> - **رازها:** /backup (تکه‌ی حافظه و برگ ۲ دفترچه)، 404 (ایجنت گمشده، روی نقشه نمی‌آد)، honeypot (پلاگین rate_limit). رازهای قدیمی HEAP هم حالا باز می‌شن: heap_top با curl، memory_pool با ssh، و دیوار فایروال هاب به DEPTHS.
> - **ظاهر و صدا:** رنگ سرمه‌ای و فیروزه‌ای و سرخابی، پس‌زمینه‌ی روترها، و یه آهنگ الکترونیک تازه.
> - **ته منطقه دو در «ادامه دارد»:** به سمت برج (`/dev/threads`) و به سمت GIT (`.git`)، چون اون منطقه‌ها هنوز ساخته نشدن.
>
> **چیزهایی که موقع ساختن نقشه نسبت به طرح عوض کردم (به نفع بازی):**
> 1. **آرنای REVIEWER #2 یه اتاق جدا زیر هاب شد** (`review_queue`، 24×14)؛ هاب `core_router` کوتاه‌تر شد (24×34). دلیل: دوربین مبارزه یه صفحه‌ست و نباید کسی وسط مبارزه بره بالای هاب. مبارزه با نشستن روی صندلی شروع می‌شه، پس واقعاً اختیاریه.
> 2. **کف airgap سه دهانه داره، نه یکی:** هر جای زنجیره بیفتی، روی mmap.c، eth0 یا robots.txt فرود میای، همه کنار هاب. قبلاً افتادن از نصف زنجیره به جای بی‌راه می‌رسید.
> 3. **port_scan هشت ستون پهن‌تر شد** تا جای review_queue باز بشه.
>
> **تو چی تست می‌کنی:** آخر کار Sonnet یه گزارش با مراحل تست به فارسی می‌نویسه (دو نفره، روی گوشی، روی خط بد).
>
> **برای دادن به Sonnet:** «فایل `docs/PLAN-metroidvania-phase4b2.md` رو بخون و اجراش کن.» (یا من خودم سشن رو باز می‌کنم.)

---

## 0. Rules of engagement

- **Start only when phases 4B-0 and 4B-1 are done:** `docs/reports/metroidvania-phase4b0.md` and `docs/reports/metroidvania-phase4b1.md` exist on `ph1`. If one is missing, stop and say so.
- **Read first, in order:**
  1. `CLAUDE.md` (especially "Godot version" and its co-op rules).
  2. This file, all of it.
  3. The 4B-0 and 4B-1 reports (what was built, the kit's API as built, deviations). Where a report's API differs from a name in this file, use the report's name and say so in yours.
  4. `docs/metroidvania/08-world-design.md` §3 (THE NETWORK), §10.1, §10.3, §10.8; `docs/metroidvania/03-abilities-and-gates.md` §2 (curl, ssh).
  5. `docs/reports/world-map-research-6-bosses.md` §4.5–§4.7 (the source of the three bosses).
  6. `docs/metroidvania/07-js-vs-godot.md` §3 (the co-op rules).
  7. Then the code under `godot/src` you are about to change.
  - Phase 4A's plan §0 still applies where this file does not say otherwise.
- **Do only phase 4B-2.** Stop after MVB2-14 and report.
- **Do not redesign.** Values, names, letters, maps and JSON in this file and in `docs/metroidvania/phase4b2-data/` are decisions.
  - If one is impossible, take the smallest change that keeps the goal and list it under "deviations" in the report.
  - **Never edit a room file by hand.** If a map must change, change it in `phase4b2-data/` (rooms and json), re-run `apply.py`, then `python3 -I tools/godot/roomcheck/check4b2.py` (must end with `0 problems`) and `world.py` (`errors 0`). Say so in the report.
- **Branch:** `ph1` only.
  - Start with `git fetch origin ph1 && git checkout ph1 && git merge --no-edit origin/ph1`. (`ph1` and `main` have no common history, as the 4B-0 report found: do not merge `main`.)
  - Push with `git push -u origin ph1`. Never push or merge to `main`, never open a PR.
- **Files you may touch:**
  - Allowed: everything under `godot/` and `tools/godot/`; `docs/metroidvania/`; `docs/reports/metroidvania-phase4b2.md`; this plan's status table.
  - **Not allowed:** `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`.
  - `public/mv/` changes only through `tools/godot/export-web.sh`, as the last commit of the phase.
- **Commits:** one commit per task (`MVB2-xx: <what>`), ending with the attribution lines your session gives you. Push after each.
- **Co-op rules (from `CLAUDE.md`, not optional):**
  - State over events. World facts (bosses beaten, levers, waves, abilities) are world flags (`Game.WORLD_PREFIXES`, the 4B-1 digest).
  - Anything the guest's combat reads from a creature goes through `net_fields()`/`net_apply()` and the `parity` test.
  - Anything that hurts on contact is in `harmboxes()`, computed from those fields. A kit boss returns harm only from its active plan.
  - Host-side damage that is not a creature's contact goes through `room.harm_zone`.
  - The partner is seen late: use its recent reports, with limits that grow with ping.
  - A new kind of co-op bug gets a rule in `godot/src/net/watchdog.gd`.
  - Reliable event data lives only in `d`. Never name a field `i` or `k`.
- **Godot naming trap:** never name your own members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Movement must not change for anyone without curl or ssh:** the seven parity tapes against the JS game keep passing; every existing test and co-op scenario keeps passing.
- **Tests:** every task names its tests. Before the final commit: `bash tools/godot/test-all.sh` → `ALL PASS`. Add every new `--test=` to its list and every new co-op scenario to `ALL=` in `tools/godot/coop-test.sh`.
- **The temporary "Skip boss" pause button stays** and must work for the three new bosses (they are room bosses).

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MVB2-01 | room data in (22 rooms, built-room edits); `oneway` lock; end doors; world 6 placeholders; checkers updated | Sonnet | done |
| MVB2-02 | world 6 look: theme and tiles (captured with an injected theme), the NETWORK backdrop, music `w6`, landmark `ci` | Sonnet | done |
| MVB2-03 | curl: rings, hooks, the zip and pop, the target marker, co-op | Sonnet | done |
| MVB2-04 | ssh: the tunnel through firewall bricks, across doors too, co-op | Sonnet | done |
| MVB2-05 | room features: webs `h`, hooks `c`, lever `I` and `gate_lever`, `dead_quiet`, the honeypot wave, sightings, decor | Sonnet | done |
| MVB2-06 | enemies: SCRAPER, WORM, DDOS, SPYWARE | Sonnet | done |
| MVB2-07 | WEB CRAWLER → curl | Sonnet | done |
| MVB2-08 | THE FIREWALL → ssh | Sonnet | done |
| MVB2-09 | THE REVIEWER #2 (pad-triggered, optional) → plugin review cache | Sonnet | done |
| MVB2-10 | plugins: gzip, sourcemap, rate_limit, review_cache | Sonnet | done |
| MVB2-11 | the 4B-1 systems in NETWORK: zone, `tree`, agent, page, fragment, 404, terminal, changelog | Sonnet | done |
| MVB2-12 | NETWORK walk-through tests; the HEAP secrets that open now; the DEPTHS loop | Sonnet | done |
| MVB2-13 | co-op: scenarios, watchdog rules, bad-line runs | Sonnet | done |
| MVB2-14 | tests, build, playtest steps, report → **stop** | Sonnet | done |

---

## 2. Facts already verified (do not rediscover)

Read by Claude on `ph1` at commit `b2253bd` (4B-0 done; 4B-1 not started). Re-check the line numbers; the facts hold.

1. **Player** (`godot/src/player/player.gd`): an exact port of the JS player. Constants `RUN 118`, `JUMP 300`, `G_UP 830`, `G_DOWN 1250`, `MAXFALL 310`, `WJ_X 165`, `WJ_Y 285`, `DASH_SPEED 320`, `DASH_T 0.15`, `DJUMP 272`. `Game.tools` has `bash catch sudo agents opus` (two places in `game.gd`, ~lines 248 and 340). `[special]`: a tap (released before `Game.FOCUS_HOLD`) casts agents with a full meter; a hold on the ground focuses. Touch buttons: `JUMP CLAW DASH SPEC` (`touch_controls.gd`).
2. **Tiles** (`core/tile_grid.gd`): ids `E 0 … THICK 14, PORT 15`; `FIRE 13` (`N`) is solid today. `TileGrid.move_x/move_y/box_hits_solid` use `solid()`. Gates: `room.gd` ~line 433 sets `grid.gates_open.catch/agents` from `gate:<room>:catch/agents`.
3. **Letters in use** after 4B-0/4B-1: tiles `# = ^ v % ~ 1 2 w ! & ; N 0 3`; objects `P C U k $ R Y @ S o * H T M V J E B D |`; enemies `b a t G Z X m n f K s l L i p d x q`. Free: uppercase `A F I O Q W`, lowercase `c e h j r u y z`. `G` is the FIREWALL GUARD (`guard.gd`) already.
4. **Rings `@`** are loaded into `Room.rings` (`{x, y}` centres) and drawn (blue circle, `GET`), decoration only.
5. **Boss fights** (`room.gd` `_step_fight`, ~line 1230): start when a player's centre passes `trigger_x` (or below it with `trigger_side: "E"`); the camera locks to `((pw - W) / 2, ph - H)`; `_finish_reward` sets `Game.tools[reward]`, `ability:<reward>`, `boss:<id>`. Boss HP = `T × u × diff mult` (`Game.boss_hp`): THE REVIEWER is `70 × 0.7 = 49`.
6. **The kit** (4B-0, `boss.gd` ~lines 186–450): `FAMILY`, `plan_start(id, fam, tgt, fp, lock, cue)` (a custom cue is allowed; active and recover come from the family), `plan_step`, `plan_cut`, `plan_fields/plan_apply`, `kit_pick_target`, `BossRead` (`greedy`, `healing`, `under`, `last_hitter`, `last_how`), `draw_plan` (the footprint stencil and the 1/2 marker). `KitDummy` is the worked example.
7. **Guest hits** reach the host as the reliable `hit` event with `dmg` (`coop.gd` ~line 166), so a damage bonus computed on the guest (opus, review cache) needs no new path.
8. **Catchable shots**: `room.shoot(..., {"kind": "diamond", "col": "#ffd23f", "catchable": true, ...})` (see `KitDummy._throw_orbs`). A caught shot flies back at its shooter.
9. **End doors**: a room's `end` text and its `D` letter show the end screen (H11 and D06 have one today, both "to be continued in /net").
10. **Music** comes from the JS game: `capture.js music` renders `G.SONGS[name]` in the page and encodes OGG with ffmpeg. **Themes** are `G.THEME[w]` (JS worlds 1–5: SOURCE TREE, DEPTHS, HEAP, THREAD TOWER, PRODUCTION); the JS has no NETWORK theme and its background builders are closure-private (`build[w]`), so a NETWORK background cannot be captured. `G.SONGS` and `G.THEME` are on `window.G` and can be extended from `page.evaluate` before a capture.
11. **The design checker** (`tools/godot/roomcheck/check4a.py` with `sim.py`, `reach.py`) still prints `0 problems` with the extended `sim.py`/`reach.py` of this phase (Claude ran it).

---

## 3. Shared definitions

### 3.1 The data (`docs/metroidvania/phase4b2-data/`)

| file | what |
|---|---|
| `rooms/N01.txt` … `rooms/N22.txt` | the 22 NETWORK rooms |
| `rooms-4b2.json` | their `rooms.json` entries |
| `room-edits-4b2.json` | edits to built rooms: H11, D06, D07 |
| `apply.py` | puts it all in place (idempotent; also takes a repo root argument) |
| `sim.py`, `reach.py` | the movement simulator, extended with curl, ssh, webs, ports and packets (replaces the copies in `tools/godot/roomcheck/`) |
| `check4b2.py` | Claude's design checker for this phase (all routes below); prints `0 problems` today |
| `rooms.py`, `canvas.py` | the generator Claude drew the rooms with (`python3 rooms.py` rewrites `rooms/` and the two json files; `apply.py` does not need it) |

`world-phase45.json` (the world design) is already updated to match these rooms, so `world.py` passes before and after `apply.py`.

### 3.2 The NETWORK at a glance

```
                      N19 /backup (secret, dead-code ceiling)
                         |
 N10 GET.http <-boss- N09 WEB CRAWLER <-fight- N08 crawl_queue --curl--> N18 token_ring
   |                                             |  (climb)                 |  (ssh, in N14)
 N11 airgap (curl chain; end door -> /dev/threads)  N05 sitemap.xml        |
   | falls: S1 -> H11, S2 -> N01, S3 -> N04          |  N20 404 (secret, dead-code floor)
 H11 mmap.c --- N01 eth0 --- N04 robots.txt --- N05
                 | lid
                N03 core_router (TERMINAL)
                 | hole
 N06 traceroute --- N22 review_queue (REVIEWER #2, pad) --- N12 port_scan --- N13 iptables --- N14 dmz --fight-- N15 FIREWALL --boss-- N16 ssh_tunnel --ssh-- N17 22/tcp
   | hole (tree)                                                              | crack                                   (end door -> .git; CDN door shut)
 N07 ttl (chimneys)                                                         N21 honeypot (wave, rate_limit)
   |
 N02 loopback (lever) --- D07 .npmrc --- D06 symlink.sh (slot gate; the lever opens it too)
```

| room | title | size | origin | role |
|---|---|---|---|---|
| N01 | `eth0` | 48×16 | [1260, -52] | gate from H11; the airgap lands here; lid down to N03 |
| N04 | `robots.txt` | 32×16 | [1308, -52] | the clue sign; airgap landing |
| N05 | `sitemap.xml` | 120×20 | [1340, -58] | webs, scrapers; dead code up (N19) and down (N20) |
| N08 | `crawl_queue` | 26×72 | [1460, -110] | the climb; curl pocket to N18; arena door |
| N09 | `WEB CRAWLER` | 24×14 | [1436, -104] | boss → curl |
| N10 | `GET.http` | 96×20 | [1340, -112] | curl lessons: 1, 2 and 3 rings over spikes |
| N11 | `airgap` | 100×52 | [1240, -104] | curl chain; three falls; end door (towards /dev/threads) |
| N03 | `core_router` | 24×34 | [1290, -36] | hub, **terminal** |
| N22 | `review_queue` | 24×14 | [1290, -2] | under the hub; THE REVIEWER #2 (optional) |
| N06 | `traceroute` | 52×16 | [1238, -3] | `tree` (map of `/net`, 40 tokens); hole to N07 |
| N07 | `ttl` | 24×32 | [1260, 13] | three chimneys (wall jumps only) |
| N02 | `loopback` | 48×16 | [1236, 45] | the back door from DEPTHS; the lever |
| N12 | `port_scan` | 72×16 | [1314, -2] | packets and three ports |
| N13 | `iptables` | 80×24 | [1386, -12] | worms in membranes, spyware, ssh vista; crack to N21 |
| N21 | `honeypot` | 48×16 | [1400, 12] | secret: DDOS waves, then `rate_limit` |
| N14 | `dmz` | 32×16 | [1466, -4] | bench; the ssh shaft up to N18 |
| N15 | `FIREWALL` | 24×14 | [1498, -2] | boss → ssh |
| N16 | `ssh_tunnel` | 40×16 | [1522, -6] | ssh lessons; ssh door east |
| N17 | `22/tcp` | 26×82 | [1562, -6] | the shaft down; end door (towards .git); the door without a handle |
| N18 | `token_ring` | 24×76 | [1486, -80] | loop behind the hub: curl in at the top, ssh in at the bottom |
| N19 | `/backup` | 32×14 | [1400, -72] | secret: fragment, logbook page 2 |
| N20 | `404` | 32×14 | [1380, -38] | secret, off the map: lost agent, tokens |

**Routes the checker proves** (`check4b2.py`; "B" = bash + catch, no sudo, no agents):
- Main path both ways with B only: N01 ↔ N04 ↔ N05 ↔ N08 (climb) → N09; N01 ↔ N03 ↔ N22 ↔ N06 ↔ N07 ↔ N02 ↔ D07; N22 ↔ N12 ↔ N13 ↔ N14 → N15. (So a player from DEPTHS without sudo is never stuck.)
- N08 → N18 needs curl; N10 and N11 need curl (both ways); N16 → N17 needs ssh (both ways); N14 ↔ N18 needs ssh (without ssh you climb back up N18's way in).
- N05's ledge under the dead ceiling reaches N19; N05's nook (drop through its lid) reaches N20; both come back.
- N13's ssh vista is reachable only with ssh; N10's token shelf only with curl.
- The HEAP secrets: H01 → H14 with curl (even without sudo: curl, then a dash up); H12 → H16 with ssh; H03 ↔ D03 with ssh.

### 3.3 Map letters (new)

| letter | what | kind | task |
|---|---|---|---|
| `h` | web strand: hurts like a spike (inset 3 px) until `boss:CRAWLER`, then air (a room `variants` entry) | tile `WEB = 16` | MVB2-05 |
| `c` | a hook: before `boss:CRAWLER` a SCRAPER hangs from it; after, the hook is a GET ring | object (+ enemy) | MVB2-05/06 |
| `I` | a lever (swipe or dash it); its flag is the room's `levers[i].flag`, in reading order | object | MVB2-05 |
| `W` | a WORM; the cell itself is a firewall brick (`FIRE`) | enemy | MVB2-06 |
| `z` | a DDOS swarm (5 bits) | enemy | MVB2-06 |
| `e` | a SPYWARE eye | enemy | MVB2-06 |

### 3.4 `rooms.json` fields (new)

| field | where | meaning |
|---|---|---|
| `"world": 6`, `"music": "w6"`, `"zone": "net"` | NETWORK rooms | world 6 is THE NETWORK in Godot (JS worlds 4 and 5 stay free for THREAD TOWER and PRODUCTION) |
| door `"lock": "oneway"` | doors | never opens from this side (the other side is a drop into this room) |
| `"end": "<text>"` | room | already exists; N11 and N17 use it with a `D` |
| `"levers": [{"x", "y", "flag"}]` | room | lever `i` (the i-th `I` in reading order) sets `flag` |
| `"gate_lever": "<flag>"` | room | the room's `&` gate also opens with this flag (D06: `lever:D06`) |
| `"dead_quiet": [[x, y]]` | room | the dead-code group containing that cell has no moths (N05's `/backup` ceiling: its clue is the robots.txt sign) |
| `"wave": {"flag", "waves": [[[x, y], …], …]}` | room | the honeypot (MVB2-05) |
| `"sighting": {"kind": "crawler", "row": r}` | room | a one-time cosmetic pass of a boss (B8, MVB2-05) |
| `"decor"` kinds `fiber`, `window` | room | MVB2-05 (4B-1's kinds stay) |
| `"landmarks": ["ci"]` | room | a new far landmark (MVB2-02); `tower` is 4B-1's |
| boss `"trigger": "pad"`, `"pad": [x, y]`, `"pad_needs": "<cond>"` | boss | the fight starts when a player presses [up] on the pad cell and `Game.cond(pad_needs)` holds (MVB2-09) |
| boss `"reward": "plugin:<id>"` | boss | the reward is a plugin (the flag `plugin:<id>`), not a tool |

### 3.5 Flags

| flag | meaning |
|---|---|
| `ability:curl`, `ability:ssh` | as for every ability (and `Game.tools.curl/ssh`) |
| `boss:CRAWLER`, `boss:FIREWALL`, `boss:REVIEWER2` | world flags (prefix `boss:` already travels) |
| `lever:D06` | the loopback lever was pulled (prefix `lever:` already in `WORLD_PREFIXES`) |
| `wave:N21` | the honeypot was cleared (add `wave:` to `WORLD_PREFIXES`) |
| `seen:crawler` | the local player saw the crawler pass in N08 (local; never sent) |
| `plugin:gzip`, `plugin:sourcemap`, `plugin:rate_limit`, `plugin:review_cache` | owned plugins (as before) |

`Game.cond(s)` (4B-1) learns one more form: `"<k>of:<f1>,<f2>,..."` (true when at least k flags are set). The `until:` lock already parses it; share the parser.

### 3.6 Constants (decisions)

```
# curl
CURL_RANGE   := 104.0   # px, player centre to ring centre
CURL_SPEED   := 400.0   # px/s, the zip
CURL_POP     := 300.0   # px/s up on arrival (= JUMP)
CURL_EXIT_VX := 210.0   # px/s along the zip's horizontal direction on arrival (0 if the zip was within 4 px of vertical)
# ssh
SSH_HOLD     := 0.30    # s of pushing into a firewall brick
SSH_SPEED    := 280.0   # px/s through the bricks
SSH_BRICKS   := 2       # at most this many bricks in a row (a thicker wall does not open)
```

---

## MVB2-01 · Room data, `oneway`, end doors, checkers

1. **Room data.** `python3 -I docs/metroidvania/phase4b2-data/apply.py`.
   - It copies `N01`–`N22`, applies `room-edits-4b2.json` and merges `rooms-4b2.json` into `rooms.json` (same one-room-per-entry layout).
   - The edits: **H11** gets the hole `H11:N2` (cells 190..198 of row 0, the airgap's west fall), loses its end door `D` and `end`, and sign 2 becomes `/net: connection established. eth0 is up.`; **D07**'s east wall rows 9..12 open as `D07:E` → `N02:W`; **D06** loses its end door `D` and `end` and gets `"gate_lever": "lever:D06"`.
   - If 4B-1 changed one of those cells (it adds a sign, a jar and a package to D07 at row 12, columns 7, 9 and 21: no clash), keep 4B-1's content and report.
   - Commit the changed files under `godot/src/world/`.
2. **Tools.** Copy `phase4b2-data/sim.py`, `reach.py` and `check4b2.py` to `tools/godot/roomcheck/` (the new `sim.py`/`reach.py` replace the old ones; `check4a.py` still passes with them). `check4b2.py` finds the repo root itself and lays the staged data over the live files, so it runs unchanged before and after `apply.py`.
3. **`world.py`:** add to `GATES`: `"oneway"`, `"until:boss:CRAWLER"`, `"until:boss:FIREWALL"`, `"until:wave:N21"`, `"until:lever:CDN"`. With them it prints `errors 0` after `apply.py` (Claude ran it on a copy).
4. **`oneway` lock:** in `Room.update_doors()`, `lock == "oneway"` → `open = false`. A closed N door is a ceiling, so nobody climbs back up the airgap; the drop from above still works (the crossing happens in the room above).
5. **End doors:** N11 (`to be continued in /dev/threads`) and N17 (`to be continued in .git`) use the existing end-door code.
6. **World 6 placeholders** so the rooms load before MVB2-02: `Game.theme(6)` falls back to world 3's theme and tiles until the real ones exist; unknown enemy letters print the existing "not ported yet" warning until MVB2-06; `h`, `c`, `I` load as air until MVB2-05.
7. **Tests:** `parity` keeps passing (it loads every room). New unit test `rooms4b`: every N room loads; every N door's target exists and points back (the checker's static part, in GDScript); `N01:N`, `N04:N`, `H11:N2` are closed; the end doors of N11 and N17 exist; `D07:E` is open.
8. `python3 -I tools/godot/roomcheck/check4b2.py` → `0 problems`; `world.py` → `errors 0`; `check4a.py` → `0 problems`.

## MVB2-02 · World 6: theme, tiles, backdrop, music, `ci`

1. **Theme and tiles, captured with an injected theme** (no change to `public/index.html`): `capture.js` gets an env option `INJECT=w6` that, right after the page loads, runs `page.evaluate` with:
   ```js
   G.THEME[6] = { name: 'THE NETWORK', path: '/net', time: '04:47', music: 'w6', ambient: '#8aa0e0',
     base: '#141a3a', dark: '#0b0f24', lite: '#24306a', cap: '#5ad1ff', capHi: '#d6f6ff', capLo: '#2a6fa8',
     code: ['#1c2550', '#26326a', '#3a2a6a', '#1c2550'],
     plat: '#c04a9a', platHi: '#ff9ad8', platLo: '#5a1f4a', accent: '#5ad1ff', fx: '#ff6ad5', glow: '#9ae8ff',
     liq: '#ff6ad5', liqHi: '#ffe0f6', liqLo: '#7a1f5a' };
   ```
   Then `INJECT=w6 WORLDS=6 node tools/godot/capture/capture.js tiles theme` writes `assets/tiles/w6_tiles.png`, `assets/theme/w6.json` and `sprites/platform_w6.png`. If `drawSolid`/`drawDecor`/`platformSprite` throw for world 6, report it and build `w6_tiles.png` by recolouring `w3_tiles.png` (map w3's theme colours to w6's, exact pixel match) in a small Node script under `tools/godot/capture/`.
2. **Backdrop** (`bg`): the JS background builders are private (fact 10), so world 6's backdrop is drawn by Godot: `godot/src/world/net_backdrop.gd`, used by the room's backdrop when `world == 6`, no art file.
   - Sky: a vertical gradient `#0b0f24` → `#1a1050` (dithered in 4 bands like the JS skies).
   - Far layer (parallax x 0.12, y 0.05): router towers, rectangles 18–34 px wide and 60–150 px tall, `#141a3a` with a 1-px `#24306a` edge, every 7 px a row of LEDs (1×1 px, `#5ad1ff` or `#ff6ad5`) that blink (a hash of tower, row and `floor(time × 2)`).
   - Mid layer (parallax 0.3, 0.12): three fibre cables (2-px lines in `#24306a`) sagging between towers; light dots (`#9ae8ff`) run along them at 60 px/s.
   - Deterministic (a hash, no `randf`), so both pages draw the same.
3. **Music `w6`**, injected the same way: `G.SONGS.w6 = {...}` in the JS song format (study `G.SONGS.w3` at `index.html` ~line 1210 and the section/instrument keys it uses). Direction: 138 bpm, A minor (`Am | F | C | G`); sections `I` (4 bars: pad + a sparse arpeggio), `A` (8 bars: a 16th-note `glass` arpeggio, an off-beat bass `. 1 . 1`, a high `glass` tick on every off-beat as the "packet" pulse), `B` (8 bars: the lead plays a short motif, bass on beats), loop from `A`; a `hi` layer (a second arpeggio an octave up) like `w3_hi`. Add `'w6', 'w6_hi'` to `COPY_MUSIC`; `INJECT=w6 node tools/godot/capture/capture.js music`. Keep it around 40–60 s per loop.
4. **Landmark `ci`** (4B-1's landmark function): a thin diagonal line of light across the upper sky (from 20 % to 80 % of the screen width, 30 px to 12 px from the top, 1 px `#9ae8ff` at 50 %), with three brighter dots moving along it every 2.5 s. Parallax 0.05. N05, N08, N10 use it.
5. **Tests:** `w6assets` (new): `ResourceLoader.exists` for `res://assets/tiles/w6_tiles.png` and `res://assets/music/w6.ogg`; `Game.theme(6).accent == "#5ad1ff"`; N03 builds its view with no error; a 20-frame headless step in N05 draws the backdrop and the `ci` landmark without errors.

## MVB2-03 · curl

**What the player does:** near a blue GET ring, press [special]: Clawd fires a cable, zips to the ring and pops off it, up and onward. Rings chain.

1. **Tools:** `Game.tools` gets `"curl": false, "ssh": false` (both places, and old saves load them as false).
2. **Anchors:** `Room.anchors() -> Array`: `rings` (`@`) plus, when `Game.flag("boss:CRAWLER")`, `hooks` (`c`, MVB2-05). Pure data on both pages.
3. **Picking** (`Room.pick_anchor(q, mx) -> int`, index into `anchors()` or -1):
   - candidates: within `CURL_RANGE` of the body centre; not `q.curl_last`; a clear line (sample every 8 px, `grid.solid_at`; FIRE, THICK and closed gates block);
   - if `mx != 0`, keep only those on that side (`dx × mx > 0` or `|dx| < 12`) when any exist;
   - the nearest wins.
4. **Player** (new fields `zip := -1`, `zip_dx := 0.0`, `curl_last := -1`, `spec_used := false`):
   - **Start:** `Controls.pressed.special` with `tools.curl`, not frozen, not in a menu, `hurt_t <= 0`, `zip < 0`, and `pick_anchor >= 0` → `zip = i`, `zip_dx = ring.x − centre.x`, `dash_t = 0`, `spec_used = true`, `Audio.sfx("dash")` (or a new `curl` sound if you make one), a 1-px cable flash.
   - `spec_used` blocks this press from casting agents on release and from starting a focus until [special] is released (put it next to `special_t`).
   - **Zip** (instead of the run/gravity/jump block while `zip >= 0`): velocity = `CURL_SPEED` toward the ring centre; move with `grid.move_x/move_y` (collisions apply). Two blocked frames in a row end the zip (`vx = vy = 0`). [dash] pressed ends the zip and starts the dash. Getting hurt ends it.
   - **Arrival** (within `CURL_SPEED × dt + 0.5` px): put the body centre on the ring; `vy = −CURL_POP`; `vx = sign(zip_dx) × CURL_EXIT_VX` (0 if `|zip_dx| <= 4`); `can_double = true`; `can_dash = true`; `jumping = false` (the pop is never cut short by releasing [jump]); `curl_last = zip`; `zip = -1`; the ring flashes.
   - `on_ground` clears `curl_last`.
   - The parity tapes never press [special] with curl owned, so nothing else changes.
5. **Drawing:** during the zip, the cable: a 1-px line `#7cc4ff` from Clawd to the ring with a 2-px bright head. **Target marker** (phone feedback): while the local player owns curl and is not zipping, the anchor `pick_anchor(player, mx)` would take gets a small bracket `[ ]` in `#d6f6ff` around it, and the touch SPEC button's label reads `GET` instead of `SPEC`.
6. **Hooks as rings:** after `boss:CRAWLER` hooks draw exactly like rings (the room is rebuilt when entered, 08 §10.1).
7. **Co-op:** curl moves only the local body (each page owns its own). For the partner's look, the `st` message gets `"cz": zip` (−1 when not zipping), and so does whatever carries the host player's pose to the guest; the partner's cable is drawn from its reported position to `anchors()[cz]`. No new reliable event.
8. **Tests:** unit `curl` (new):
   - N10 with curl: a player on the floor at `(81*16, 19*16−10)` that jumps (held 40 frames) and presses [special] at frames 20, 32, 44 … every 12 frames while holding left reaches column ≤ 12 within 600 frames without a hazard (all three trenches).
   - Pick rules: in N10, from `(78*16, 15*16)` facing left the pick is the ring at (74,14); a wall between (a test room built from text, or Z-lab cells set solid) gives −1; the ring just used is not picked again before landing.
   - Without curl, [special] near a ring does nothing new (no zip; agents still cast with a full meter).
   - A [special] tap that started a zip with a full meter does **not** cast agents.
   - With the full meter and no ring in range, the tap casts agents as before.
   - H01 → H14: with curl + bash (no sudo) a scripted jump, [special] at the ring, then dash up, reaches H14.

## MVB2-04 · ssh

**What the player does:** push into a red firewall brick for 0.3 s: Clawd tunnels through (at most two bricks).

1. **Player** (new fields `push_t := 0.0`, `ssh_t := 0.0`, `ssh_dir := 0.0`, `phase_fire := false`):
   - **Pushing:** `tools.ssh`, `mx != 0`, not dashing, not zipping, `hurt_t <= 0`, and the column just past the body's side (`x + w + 0.5` or `x − 0.5`) has a `FIRE` cell in a row the body covers and no other solid kind in those rows → `push_t += dt`; else `push_t = 0`. While pushing, the bricks touched glow (a 1-px `#ff9ad8` edge).
   - **Can it open?** Count the bricks in that direction (the run of columns in which a body row is FIRE): at most `SSH_BRICKS`, and the first spot past them is free (the body box is not solid there, or it is past a W/E edge whose door is open). If not, at `SSH_HOLD` pop `too thick for ssh` once (per push) and do nothing.
   - **Tunnel:** at `push_t >= SSH_HOLD`: `ssh_t = 0.4`, `ssh_dir = mx`, `phase_fire = true`, `vx = mx × SSH_SPEED`, `vy = 0`, `inv = max(inv, 0.45)`, `Audio.sfx("dash")`. While `ssh_t > 0`: no gravity, no input; it ends when the body overlaps no FIRE cell (then `phase_fire = false`, `vx = mx × RUN`), or when `ssh_t` runs out (then put the body back where the tunnel started and end it: this must never happen with the room data; log it).
   - `TileGrid.move_x/move_y/box_hits_solid` treat FIRE as empty for a body whose `phase_fire` is true (read it with `e.get("phase_fire")` so creatures are unaffected).
2. **Across a door:** firewall doors have bricks on both sides (H03:SW/D03:E2, H12:E/H16:W, N16:E/N17:W). `RoomManager` carries `ssh_t`, `ssh_dir`, `phase_fire` and `vx` into the target room, as it carries `dash_t`, so the tunnel goes on through the target's brick.
3. **Drawing:** while tunnelling, Clawd is drawn as a short streak (3 ghost copies, `#58f0c8` and `#ff4f6d`) with tiny `ssh` text; each brick it passes flashes for 0.2 s.
4. **Co-op:** local, like curl. `st` gets `"ss": 1` while tunnelling; the host draws the guest's streak from it. No body-in-wall check exists in the watchdog today; if you add one, exempt a body with `ss`.
5. **Tests:** unit `ssh` (new):
   - N16 with ssh: walking right from the west door crosses the thin wall (col 12) and the thick one (cols 22–23) and reaches `N17` within 600 frames; without ssh it stops at x < 12×16.
   - The tunnel starts only after `SSH_HOLD` (a 0.25 s push does nothing).
   - A three-brick wall (a test grid) does not open and pops `too thick for ssh`.
   - H12 → H16 and H03 (`flood 0`) → D03 through their firewall doors, and back.
   - The parity tapes are unchanged.

## MVB2-05 · Room features

1. **Webs `h`:** tile `WEB = 16`. Not solid. `Room.hazard_at` returns `"web"` when the body overlaps the cell inset by 3 px; the player handles it like a spike (back to its safe spot, 1 damage; the guest for its own body). Drawn in the furniture layer: a 1-px line through the cell centre, `#7cc4ff` at 80 %, horizontal if a web neighbour is left/right, vertical if up/down, both otherwise, with a light dot running along it. N05 and N08 have `variants` turning `h` into air with `boss:CRAWLER` (4B-0's safe variant code does the rest).
2. **Hooks `c`:** `load_room` appends `{x: cx, y: cy}` to `hooks`. Host/solo: if not `boss:CRAWLER`, spawn a `Scraper` hanging from it (MVB2-06). Drawn as a hook (a ring with a gap at the bottom, `#8d8798`) while a scraper may use it, as a ring after the flag.
3. **Lever `I` and `gate_lever`:** `I` → `levers.append({x, y, i})`. A claw swipe or a dash overlapping its box `(x+2, y+2, 12, 14)` sets `levers[i].flag` if unset (`Game.write_save()`, `Audio.sfx("uiOk")`, pop `lever`). Guest: `Net.rel("lever", {"room": id, "n": i})`; the host sets the flag; it travels as a world flag. Drawn as a stick on a base, tilted left when off, right when on (`#c3bccd`, knob `#ff4f6d`). `gates_open.agents` also opens with `Game.flag(def.get("gate_lever", ""))` (when the key is set).
4. **`dead_quiet`:** no moths for the dead-code group that contains a listed cell; `--verbose` still outlines it.
5. **The honeypot (`wave`, N21)** — host/solo:
   - When `wave.flag` is not set and a player is in the room: 1.0 s later spawn wave 0 (a DDOS swarm at each listed cell); when every creature of the wave is dead, 1.0 s later the next wave; after the last, set the flag (`write_save`), `Audio.sfx("kill")`, pop `honeypot drained`.
   - The room's `U` is drawn inside a glass case and cannot be picked up until the flag is set (both pages read the flag).
   - Its N door is `until:wave:N21`, so you are locked in until it is drained. A rebuilt room (everyone left or respawned) starts again. Add `wave:` to `WORLD_PREFIXES`.
6. **Sighting** (`N08`): the first time the local player's `y < row × 16` there while `boss:CRAWLER` is not set and `seen:crawler` is not set: set `seen:crawler`, and a dark silhouette of the crawler (MVB2-07's body drawn at 60 % alpha, no collision) walks along row 1 from x −40 to `pw + 40` in 3 s with a soft skitter. Local only.
7. **Decor:**
   - `fiber` (N01): along row `y` from `x` for `w` cells, a 1-px `#5ad1ff` line on the floor's top edge with light dots running east at 80 px/s.
   - `window` (N13): a `w × h` cell window in the back wall (`#0b0f24` glass, 1-px `#3a4a9a` frame). With `"shadow": "firewall"` and no `boss:FIREWALL`: behind it the FIREWALL's shield outline drifts ±12 px (`sin(time × 0.7)`). After the boss, the window shows a dim green `200`.
   - N22's `chair` is 4B-1's kind.
8. **Tests:** unit `net4b` (new): N05 web hurts at level start and is air after `boss:CRAWLER` on a rebuilt room; N05 has 4 scrapers without the flag and 0 with it, and `anchors()` grows by its 4 hooks; N02's lever sets `lever:D06` from a swipe and D06's gate cells are then open; N05's `/backup` group has no moths and the `404` group has them; N21 spawns wave 0 within 2 s, its `U` cannot be picked up until `wave:N21`, and killing every bit of all three waves sets it; N08's sighting runs once.

## MVB2-06 · Enemies: SCRAPER, WORM, DDOS, SPYWARE

All are host-simulated creatures with `nid`s, guest puppets through `NetClasses` (names and indices after 4B-0's `kitdummy` 25: `"scraper"` 26, `"worm"` 27, `"ddos"` 28, `"spyware"` 29; the bosses take 30–32 in MVB2-07..09). Each passes `--test=parity`.

**SCRAPER** (`c`, `src/enemies/scraper.gd`, `extends EnemySM`): teaches what a GET anchor looks like.
- Body 12×10, hp 2, loot 2, `col #8d8798`, stompable. It hangs on a thread from its hook (`hx, hy`); `len` = thread length.
- `STATES := ["hang", "tell", "drop", "wait", "climb"]`.
  - hang: `len = 8`, sways (draw only). → tell when the nearest player has `|dx| <= 24`, is below it within 160 px, and the line is clear.
  - tell: `0.4 × telegraph_mult` s, shivers.
  - drop: `len` grows at 260 px/s until the body's centre is level with that player's centre (locked at the start of the drop), a solid cell is hit, or `len = 160`.
  - wait: 0.8 s, sways. climb: `len` shrinks at 70 px/s to 8 → hang.
- `harmboxes()`: the body in tell/drop/wait/climb; none in hang (it is a decoration until it moves).
- `net_fields`: `[STATES.find(state), roundi(state_t*100), roundi(len)]`. Draw: a 1-px thread, a grey body with 4 small legs and a red eye.

**WORM** (`W`, `src/enemies/worm.gd`, `extends EnemySM`): lives inside firewall bricks; teaches that they can be passed.
- Its cell is FIRE (`load_room`). At spawn it takes the 4-connected FIRE group containing its cell (`cells`).
- `STATES := ["crawl", "tell", "out", "back"]`.
  - crawl: moves to the next cell of the group every 0.8 s (ping-pong along the list), drawn as a glowing segment over the brick. → tell when a player's box is within 28 px horizontally of the group's face, and its centre is within 8 px of the worm cell's rows.
  - tell: `0.6 × telegraph_mult` s; the brick glows, a hiss.
  - out: 0.35 s; the head (10×8) sticks 14 px out of the brick face toward that player.
  - back: 0.4 s.
- `hurtboxes()`/`harmboxes()`: the head, only in out (and back's first 0.15 s). Inside the bricks it cannot be hit (agents too). hp 2, loot 2.
- `net_fields`: `[STATES.find(state), roundi(state_t*100), cell index, out side (−1/1)]`.

**DDOS** (`z`, `src/enemies/ddos.gd`): the letter spawns five `DdosBit`s (`extends Enemy`) around the cell.
- A bit: 6×6, hp 1, loot 0, flies. Idle until a player is within 140 px with a clear line; then it flies toward its target point: the nearest player's centre + an offset (angle `i × 72° + time × 1.5`, radius 18), acceleration 300, top speed 90 (bits push apart 1 px/frame when closer than 6 px).
- Contact hurts (1) and the bit dies ("packet dropped"). Any hit kills it. Killing bits fills the meter like any hit (agents learn from them).
- `net_fields`: `[]`. Draw: a 6×6 rounded packet, `#ff6ad5` with a `#ffe0f6` corner pixel, a 2-px trail.

**SPYWARE** (`e`, `src/enemies/spyware.gd`, `extends EnemySM`): an eye on the cell, fixed.
- hp 3, loot 3, not stompable, no contact harm.
- `STATES := ["watch", "track", "lock", "fire", "cool"]`.
  - watch: → track when a player is within 160 px with a clear line.
  - track: `1.2 × telegraph_mult` s; a dotted red line from the eye to that player's centre, following it.
  - lock: 0.4 s; the line stops following (its angle is fixed), turns solid and blinks.
  - fire: 0.25 s; a 6-px beam along the locked line to 200 px or the first solid cell.
  - cool: 1.2 s.
- `harmboxes()` in fire: 8×8 boxes every 8 px along the beam. The guest builds the same from the fields.
- `net_fields`: `[STATES.find(state), roundi(state_t*100), roundi(angle*100), roundi(beam_len)]`. Draw: a 10×10 white eye with a red iris toward the target, an eyelid blink every 3 s in watch.

**Tests:** unit `w6enemies` (new): a Scraper drops to a player under it and climbs back; its harmbox is empty in hang. A Worm can't be hit in crawl and can in out; a player next to its membrane is bitten within 2 s. A DDOS letter makes 5 bits; a bit touching the player hurts it and dies. A Spyware's beam angle does not change during lock and fire; a player who moves off the locked line during lock is not hurt. Parity for all four.

## MVB2-07 · WEB CRAWLER → curl

`src/enemies/crawler_boss.gd`, `class_name CrawlerBoss extends Boss`, a kit boss (`kit_init()`), NetClasses `"crawler"` (30). Arena N09 (24×14, `FLOOR = 176`). It never needs curl (B1 rule 6); its rewards come from the legs, the core coming down, and caught packets.

**Body and graph**
- **Nodes** (the ceiling graph): `NODES := [Vector2(56, 40), Vector2(144, 32), Vector2(240, 32), Vector2(328, 40)]`; edges between neighbours. Drawn: 6-px rings `#5ad1ff` joined by 1-px lines; the next node lights up (a pulse) during a `move` cue; a `BACK` label over the previous node during a `back` cue.
- **Core:** 24×16, hangs `18` px under its node on a thread (`core_y`). The hurtbox is the core. Out of reach (≈ 150 px over the floor) except when it comes down.
- **Legs:** 8 drawn legs (2-segment lines). A planted leg is a 6-px column from the core to the floor.
- HP: `T 80, u 0.7` → 56 on normal.

**Attacks** (cue/active/recover from the family, cue × `telegraph_mult`, recover × `punish_mult`)

| id | family | what | footprint and harm | the opening |
|---|---|---|---|---|
| `move` | `sweep` | it walks along an edge to the chosen node (rule 8 below) | none (the body is on the ceiling) | — |
| `drop` | `slam` | Fetch Drop: a leg slams at the target's x (locked 0.5 s before the impact) | fp `[x−16, FLOOR−112, 32, 112]`; active: the leg column `[x−6, core_y, 12, FLOOR−core_y]` | recover: the leg stays planted (harmless) and the core comes down; hits on the core **or the leg's lower 48 px** damage it (a pogo on the leg works) |
| `volley` | `proj` | Packet Volley: 3 yellow packets at the target, 0.25 s apart, travel ≥ 0.6 s | catchable shots (`room.shoot`, kind `diamond`) | a packet caught back into the core: 2 damage, a cable snaps (cosmetic), and the core comes down for 1.6 s |
| `sweep` | `sweep` | Web Edge Sweep (P2+): two strands come down from the corners | two floor bands `[0, FLOOR−40, gx−32, 40]` and `[gx+32, FLOOR−40, 384−gx−32, 40]`; the safe lane is 64 px at `gx` = the target's x clamped to 64..320 | recover: the core comes down |
| `back` | `dual` | Backtrack Crash (P3): `BACK` over the previous node; it returns there and two legs strike at `nx ± 40` | two columns `[nx−52, 0, 24, FLOOR]` and `[nx+28, 0, 24, FLOOR]`, numbered 1 and 2; the 56 px between them is safe | recover 1.5 × punish: the core is down |

- **Phases:** P1 (100–60 %): `move, drop, volley, drop`. P2 (60–25 %): `move, drop, sweep, volley`. P3 (25–0 %): `back, drop, sweep, volley`. A phase change waits for the current attack's recover.
- **The core coming down:** `core_y` (the core's centre) eases to `FLOOR−70` during the recover that grants it and back to `node.y + 18` in the next cue. While down, the core box is `[nx−12, core_y−8, 24, 16]` (y 98–114): a jump + up-swipe from the floor reaches it (the swipe box at the jump's top spans y 88–112). The core never hurts on contact (a kit boss hurts only through its plan).
- **Rule 8** (B1, "it picks the node above whoever stands under it"): `move` goes to the node nearest the x of the player for whom `read.under(key)` was true longest in the last 1.0 s; if nobody stood under it, the next node in order. The target of `drop` is `kit_pick_target()` as usual.
- **Co-op:** everything harmful is in the plan (footprints and `harmboxes()` from the plan and the fields) or a `room.shoot` shot. `net_fields` = `plan_fields()` + `[node, prev_node, roundi(core_y), roundi(leg_x), leg_on, roundi(gap_x)]`.
- **Death:** the nodes go dark one by one, the core drops, the strands fade; the reward is `curl` (`banner_sub`: `near a GET ring, press [special]: you zip to it`). After the flag, N10's rings are drawn as the crawler's packets (yellow-cyan balls with a ring; same anchors).
- **Data** (in `rooms-4b2.json`): `{"id": "CRAWLER", "class": "CrawlerBoss", "trigger_x": 304, "trigger_side": "E", "T": 80, "u": 0.7, "reward": "curl", "music": "boss", "drop": 40, ...}`; `make_boss()` gets the branch.

**Tests:** unit `crawler` (new): the intro starts only when a player's centre is below x 304; HP 56; each attack's harm exists only in its active phase; after `drop`, a scripted jump + up-swipe from the floor under the core hits it during recover; a caught packet deals 2 and brings the core down; rule 8: a player standing under node 2 for 1 s → the next `move` goes to node 2; the phases switch at 60 % and 25 %; the kill sets `ability:curl`, `boss:CRAWLER`, opens `N09:W`. Parity: `CrawlerBoss` record → apply gives the same `harmboxes()` mid-cue and mid-active.

## MVB2-08 · THE FIREWALL → ssh

`src/enemies/firewall_boss.gd`, `class_name FirewallBoss extends Boss`, a kit boss, NetClasses `"firewall"` (31). Arena N15: two thin membranes (FIRE, columns 7 and 16, rows 8–10, x 112–128 and 256–272), perches at row 8 on both sides. It never needs ssh (rule 6).

**Body:** 22×30 on the floor, walks at 50 px/s toward its next target between attacks. The membranes are solid to it except in `phase`. HP `T 85, u 0.7` → 60.

**Shield:** 6×28 in front (`face`). While the shield is on, claws, dashes and agents from the front are blocked (like `Guard.blocks`) with a clang. **Rule 8:** after each recover, `face` turns to `read.last_hitter()` if anyone hit it in the last 2 s, else to the next target; the turn takes 0.4 s and is drawn (the shield swings round).

**Lanes:** L = x 16–112, M = 128–256, R = 272–368 (the floor between the membranes; each ≥ 96 px, so ≥ 4 tiles open, rule 3).

| id | family | what | footprint and harm | the opening |
|---|---|---|---|---|
| `throw` | `sweep` | Shield Throw: the shield flies out along the floor to a turnaround marker at the target's x (locked at the cue's end, clamped to the arena) | the band `[min(bx, tx), FLOOR−18, |tx−bx|, 14]` (jump it); the shield moves out during active | the body has no shield from `throw`'s active until `return` ends: hit it from any side |
| `return` | `sweep` (cue 0.5) | the shield hovers at the marker, then flies back | the same band, back | (as above) |
| `scan` | `sweep` | Port Scan: two lanes burn, one stays open | the two lanes other than the open one, full height `[x, 16, w, FLOOR−16]`; the open lane is the one next to the target's lane (towards the middle; M's neighbour is the side away from the boss); fp = the open lane | recover: it stands, shield on, flank it |
| `deny` | `proj` | Denied Packet: a slow yellow orb (110 px/s) at the target | catchable shot | caught back into it: the shield drops for 1.6 s and it takes 2 |
| `phase` | `slam` (cue 1.6) | P2: it walks into the nearest membrane and **through it** (the ssh preview), out on the far side with a slash | the slash `[dx−24, FLOOR−30, 48, 30]` at the exit point `dx` (shown during cue as the destination outline) | recover: its back is to the membrane |
| `bash` | `lunge` | rule 8: if `read.greedy(key)` on the shield from close, the next attack is a 48-px shield bash at that player | `[bx, FLOOR−30, 48×face, 30]` | recover |

- **Draw `scan` itself** (the kit's stencil shows one rect): the two burning lanes striped red with `22`, `80`, `443` above the three lanes; the open lane shows `OPEN` in green. Shape and text, never colour only.
- **Phases:** P1 (100–55 %): `throw→return, scan, deny`. P2 (55–0 %): `phase, throw→return, scan, deny`. `throw` is always followed by `return`.
- **Co-op:** the shield's position is a pure function of the plan (`throw`/`return` phase and time), so the guest computes it; `net_fields` = `plan_fields()` + `[face, shield_on, roundi(turn_t*100), open_lane, roundi(dest_x)]`.
- **Death:** the shield cracks and falls; the membranes flicker and go dark (they stay as bricks); reward `ssh` (`keep pushing into a thin red firewall: you tunnel through`). With `boss:FIREWALL`, N12's ports are open for good (its `variants` entry) and N13's window shows `200`.

**Tests:** unit `firewall` (new): a front swipe is blocked, a back swipe lands; after a swipe from the right side, `face` turns right after the next recover; during `throw`→`return` a front swipe lands; `scan` never burns the open lane, which is ≥ 96 px; `phase` in P2 puts the boss on the other side of a membrane; a caught `deny` orb drops the shield for 1.6 s; the kill sets `ability:ssh`, `boss:FIREWALL`, opens `N15:E`. Parity.

## MVB2-09 · THE REVIEWER #2 (optional) → plugin review cache

`src/enemies/reviewer2.gd`, `class_name Reviewer2 extends Boss`, a kit boss; it reuses THE REVIEWER's look (copy `draw_boss_body`/`_bubble` or share them) with a `#2` badge. NetClasses `"reviewer2"` (32). Arena N22 (24×14) under the hub.

1. **Pad trigger** (`"trigger": "pad"`): the fight starts only when a player stands on the pad cell (11, 10) (the chair) and presses [up] while `Game.cond(pad_needs)` holds (`1of:ability:curl,ability:ssh`). Host/solo: its own player; guest: `Net.rel("pad", {"room": id})` (the host checks the guest's last reported position is on the pad, then starts the intro). Without the condition, [up] on the chair pops `you have nothing new to show`. The arena's three doors are `fight`-locked, so they only shut during the fight. Leaving or dying resets it; it starts again only from the pad. With `trigger: "pad"`, `_step_fight`'s `none` branch does not read `trigger_x` (the boss data has none).
2. **HP:** `T 70, u 0.84` → 59 (≤ 1.2 × THE REVIEWER, B7).
3. **Attacks:**

| id | family | what | harm | the opening |
|---|---|---|---|---|
| `cached` | `guard` (cue 1.3) | Cached Riposte: shows the icon of the target's last attack kind (`read.last_how`: side swipe, up swipe, pogo, dash, agent, caught shot) and blocks **that** kind during active; a blocked hit is answered by `riposte` (`lunge`, cue 0.8) on the hitter | riposte only | hits of another kind land |
| `double` | `dual` | Double Review: two thrusts, lines 1 and 2 (toward the target, then back), both locked at the cue's end | two bands `[.., FLOOR−24, 150, 24]` numbered | recover |
| `verdict` | `proj` | Approve / Reject: four shots 0.7 s apart, alternating a yellow diamond (catchable) and a grey X (not catchable, jump it) | shots | a caught diamond: 2 damage |
| `cross` | `sweep` | P2+: Cross-Comment: marks the target; two slashes close in from both sides, the 64 px around the mark stay safe | `[mx−112, FLOOR−40, 80, 40]` and `[mx+32, FLOOR−40, 80, 40]` | recover: front hits blocked, back hits land (the partner flanks; solo, walk round) |
| `signoff` | `lunge` (cue 1.5) | P3: a closed guard, then a lunge to a marked spot, then one yellow diamond in its recover | the lunge path | recover |

- **Phases:** P1 (100–60 %): `cached, double, verdict`. P2 (60–25 %): + `cross`. P3 (25–0 %): + `signoff`.
- **Rule 8:** `cached` reads `read.last_how(target)` (never the button); if `read.greedy(key)` for anyone when an attack is chosen, the next attack is `cached` on that player.
4. **Reward:** `"reward": "plugin:review_cache"`: `_finish_reward` sets the flag `plugin:review_cache` (and no tool) when the reward starts with `plugin:`; `boss:REVIEWER2` as usual; the banner is `review cache`. The sign's alt then reads `2nd review: approved. LGTM.`
5. **Tests:** unit `reviewer2` (new): [up] on the chair without curl/ssh pops the message and starts nothing; with `ability:ssh` it starts the intro; walking through the arena never starts it; `cached` after three up-swipes shows the up-swipe icon, blocks an up-swipe and lets a side swipe land; `verdict`'s X is not catchable and its diamond is; the kill sets `plugin:review_cache` and `boss:REVIEWER2` but no tool. Parity.

## MVB2-10 · Plugins

Add to `Game.PLUGINS`:

| id | name | cost | price | desc | where |
|---|---|---|---|---|---|
| `gzip` | `gzip` | 1 | 0 | every second token you pick up counts twice | H16 (`U`, built in 4A) |
| `sourcemap` | `sourcemap` | 1 | 0 | the map marks what you left behind in rooms you have mapped | H14 (`U`, built in 4A) |
| `rate_limit` | `rate_limit` | 2 | 0 | 429: you take at most one hit every 3 s | N21 (after the wave) |
| `review_cache` | `review cache` | 1 | 0 | after a catch, your next claw hit deals +1 | REVIEWER #2's reward |

- **gzip:** per player, a counter of tokens picked up; every second one adds one more. The guest's pickup request carries `"gz": 1` when the guest has gzip on; the host adds the bonus to the shared count.
- **sourcemap:** on the map page (4B-1), in rooms that are committed (`mapped:`), draw a 2-px dot for each item still there: a token cluster (one dot per group of adjacent `o`), a fragment, a plugin, an agent jar, a logbook page. Never in rooms not committed, never in `offmap` rooms (M8). Local.
- **rate_limit:** in `Player.hurt` (each page, its own body): if equipped and less than 3.0 s since the last damage, the damage is ignored (knockback too) and a small `429` pops.
- **review_cache:** when this player catches a shot (the parry path), `cache_bonus = true` (a tiny `+1` icon over Clawd); its next claw hit gets `atk_dmg + 1`, then `cache_bonus = false`. The guest's bonus travels in the `hit` event's `dmg` (fact 7).
- **Tests:** unit `plugins4b` (new): each one's rule as above, including: rate_limit ignores a second hurt at 2.9 s and takes one at 3.1 s; review_cache adds 1 to exactly one hit; gzip gives 3 for 2 pickups; sourcemap lists the dots of a mapped room and none of an unmapped one.

## MVB2-11 · The 4B-1 systems in NETWORK

Everything here is data plus small hooks; 4B-1 built the systems.

1. **Zone:** every N room has `"zone": "net"` (in the data). The map, the counts and `tree`'s outline of `/net` come from it.
2. **`tree`** in N06 at (38, 8) on its ledge, price 40 (data `npc`), with paper scraps `├──` up to it (4B-1's `scrap` decor at (33, 11), (34, 10), (35, 9), in the data).
3. **Agent** in N20 at (24, 11) (data `agents`): one of the eight.
4. **Logbook page 2** in N19 at (5, 11) (data `pages`).
5. **Fragment** in N19 at (26, 11) (`*`): the memory line `04:47 — the backup still had last week's working build.` (already in 4B-1's table).
6. **404:** N20 is `offmap` (data): never on the map, never counted, no pins or pings, the partner line reads `P2 · unindexed` there.
7. **Terminal** N03 (data `terminal`): 4B-1's rules apply on their own (no enemy near the bench, fan, music duck). Check them in the test.
8. **Secrets on the map:** N19 and N21 are `secret` (data), N20 `offmap`.
9. **Changelog:** 4B-1's `OBSTACLES` gets `c` → `curl` (hooks count as curl obstacles before the flag). The lines for curl and ssh then follow from 4B-1's rule (e.g. `changelog: something in /heap now answers to curl`).
10. **Logs:** NETWORK signs are logged under THE NETWORK.
11. **Tests:** unit `net4b1` (new): `tree` in N06 sells `map:net`; N20's agent frees with a swipe (`agent:N20`); N19's page sets `page:2`; N19's fragment shows its memory line; N20 is not on the map with `room:N20:visited`; N03's bench has no enemy within 10 tiles; after `ability:curl`, the next terminal rest shows a changelog line naming `/heap` (H01's ring) and `/net`.

## MVB2-12 · NETWORK walk-through, the HEAP secrets, the DEPTHS loop

1. **`--test=rooms4b`** (extend MVB2-01's): for every N door that can open (set the flags each needs: `boss:*`, `wave:N21`, abilities), put the player 2 px inside the edge on the door's cells moving out (W/E `vx = ∓RUN`; N `vy = −300`; S `vy = +200`); within 60 frames the manager is in the target room, the player is not inside a solid cell and `hazard_at` is `""`. Skip `oneway` doors from their closed side and the doors to rooms not built (T01, T16, P15, G01).
2. **The airgap falls:** in N11, a player put at `y = 48×16` with `vy = 200` and x = 14×16, 40×16 and 80×16 lands in H11, N01 and N04 respectively, on solid ground, hp unchanged.
3. **Secrets:**
   - N05: standing on the ledge at (70, 4) and jumping reaches N19 (dead code revealed); from N19 dropping through the lid lands back on that ledge.
   - N05: [down]+[jump] on the nook's lid (53, 17) falls into N20 (`dead:N05` set); from N20, climbing the platforms and jumping out lands on the lid.
   - N13: a jump + dash down on the crack (35, 21) reaches N21; the door above is shut until `wave:N21`.
4. **The HEAP secrets that open now:** H01 → H14 with curl (MVB2-03's test), H12 → H16 and H03 ↔ D03 with ssh (MVB2-04's test). Pick up `sourcemap` and `gzip` there.
5. **The DEPTHS loop:** a fresh save with bash + catch, starting in N02: pull the lever, walk west through D07 into D06: the slot gate is open without agents.
6. **The two entries:** a save with only bash + catch + agents (no sudo) walks from D06 through N02, N07 (climb), N06, N22, N12, N13, N14 to N15's door (scripted waypoints, or the checker's proof plus a smoke walk of each room, your choice; say which).

## MVB2-13 · Co-op

1. **Scenarios** (each also with `BADLINE_ALL=1`):
   - `co-curl`: both in N10 with curl; the guest crosses all three trenches by curl; the host sees the guest's body past column 12 within 20 s (40 s with `SCN_SLOW`) and the guest's cable drawn at least once; no `INVARIANT`.
   - `co-ssh`: both in N16 with ssh; the guest tunnels to N17 and back; the host sees it in N17 then N16; no `INVARIANT`.
   - `co-crawler`: both in N09; 30 s of fight (60 with `SCN_SLOW`); pass as `co-bosskit` (≥ 6 plans seen, every active plan shown ≥ 0.30 s in cue on the guest, both targeted); plus: the guest catches at least one packet (scripted) and the host's boss loses 2 hp from it.
   - `co-firewall`: as above in N15; plus: the shield turns to the guest after the guest is the last hitter.
   - `co-reviewer2`: the guest sits on the chair with `ability:ssh`; the host's intro starts; 20 s of fight; no `INVARIANT`.
   - `co-honeypot`: both drop into N21; the waves clear (host and guest bots swing); both have `wave:N21`; the guest's N door opens; the guest picks up `rate_limit` (shared ownership).
   - `co-lever`: the guest pulls N02's lever; the host has `lever:D06` within 2 s and its D06 gate is open.
2. **Watchdog rules:**
   - `boss-cue` (4B-0) covers the three bosses as kit bosses (check it does: they are kit puppets).
   - `scan-lane` (guest): during the FIREWALL's `scan` active, the guest's computed open lane must equal the host's (from the fields); a mismatch for 0.3 s → `INVARIANT`.
   - `wave-door` (host): `wave:N21` set but the guest's report still has it inside N21 against the closed door for 3 s → `INVARIANT` (the guest did not get the flag).
3. Add the seven scenarios to `ALL=`.

## MVB2-14 · Tests, build, playtest steps, report — then stop

1. Add to `test-all.sh`: `rooms4b w6assets curl ssh net4b w6enemies crawler firewall reviewer2 plugins4b net4b1`.
2. Add to `ALL=` in `coop-test.sh`: `co-curl co-ssh co-crawler co-firewall co-reviewer2 co-honeypot co-lever`.
3. `python3 -I tools/godot/roomcheck/check4b2.py` → `0 problems`; `check4a.py` → `0 problems`; `world.py` → `errors 0`.
4. `bash tools/godot/test-all.sh` → `ALL PASS` (the known timing-sensitive tests may be re-run once). Also `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-curl co-ssh co-crawler co-firewall co-reviewer2 co-honeypot co-flags co-bosskit`.
5. A screenshot of N05, N11 and N12 each (the `scene=` helper) into `docs/reports/img-phase4b2/`, linked from the report.
6. Export with `tools/godot/export-web.sh` as the **last** commit (`MVB2-14: export public/mv`).
7. Write `docs/reports/metroidvania-phase4b2.md`: what was done; deviations; test results (with the bad-line runs); the kit as used by the three bosses (anything the kit lacked); **playtest steps for Zakaria in Persian**, short:
   - from mmap.c into eth0; robots.txt; sitemap.xml (webs, scrapers); the climb in crawl_queue (the crawler passes overhead); WEB CRAWLER;
   - curl in GET.http; the airgap (fall on purpose once: you land by the hub); the end door at the tower's foot;
   - the hub and its terminal; review_queue's chair (nothing yet);
   - port_scan: ride a packet, then try on foot; iptables (worms, spyware, the window); dmz; THE FIREWALL; ssh_tunnel; 22/tcp down to the end door;
   - back at the chair with ssh or curl: THE REVIEWER #2;
   - secrets: /backup (from the ledge in sitemap.xml), 404 (drop through the little lid), honeypot (bash down through the crack in iptables), token_ring (curl from crawl_queue or ssh from dmz);
   - the HEAP secrets: heap_top (curl in brk.c), memory_pool (ssh in alloca.h), the firewall at the bottom of free_list.h to DEPTHS;
   - from DEPTHS: the lever in loopback, then symlink.sh's gate is open;
   - co-op: the same route together; say on the phone whether the GET marker and the `GET` button help, whether the bosses' warnings read well over the internet, and whether the curl chain in the airgap is fair.
8. Update `docs/metroidvania/README.md` (phase 4B-2 done) and this plan's status table.
9. **Stop** and report. THREAD TOWER (phase 5A) is a separate plan and session.

---

## Appendix A · Where things are

| what | where |
|---|---|
| player movement, curl, ssh | `godot/src/player/player.gd` |
| tiles, collision, `phase_fire` | `godot/src/core/tile_grid.gd` |
| room loading, letters, anchors, levers, waves, hazards, drawing | `godot/src/world/room.gd` |
| world 6 backdrop | `godot/src/world/net_backdrop.gd` (new) |
| room swaps (carry the tunnel), travel | `godot/src/world/room_manager.gd` |
| bosses and the kit | `godot/src/enemies/boss.gd`, `boss_read.gd`, new `crawler_boss.gd`, `firewall_boss.gd`, `reviewer2.gd` |
| new enemies | `godot/src/enemies/scraper.gd`, `worm.gd`, `ddos.gd`, `spyware.gd` |
| flags, plugins, tools, `cond` | `godot/src/autoload/game.gd` |
| co-op | `godot/src/net/coop.gd`, `net_classes.gd`, `watchdog.gd`, `godot/src/player/remote_player.gd` |
| touch button label | `godot/src/ui/touch_controls.gd` |
| capture (theme, tiles, music injection) | `tools/godot/capture/capture.js` |
| room data for this phase | `docs/metroidvania/phase4b2-data/` |
| design checkers | `tools/godot/roomcheck/check4b2.py`, `check4a.py`, `world.py` (`sim.py`, `reach.py`) |

## Appendix B · Why these choices

- **curl is a zip, not a swing:** a swing needs timing and a held button, which is hard on a phone and reads badly to a partner who sees it late. A zip to a visible target with a fixed pop is one press, the same every time, and it chains. The marker and the `GET` label show what a press will do before it is pressed.
- **ssh is horizontal only:** pushing into a wall is natural; pushing into a ceiling is not possible for 0.3 s. The one vertical ssh link of the design (dmz ↔ token_ring) became a short shaft behind a firewall wall in N14.
- **Three airgap falls:** the curl chain spans the whole room; a single hole under part of it would have left falls with nowhere to go. Every fall now lands next to the hub (W2).
- **REVIEWER #2 in its own room with a pad:** the fight camera is one screen; the hub is 34 rows tall. A separate 24×14 room keeps the fight on one screen and the pad keeps it optional (D34).
- **Kit bosses only:** the three bosses use 4B-0's plan, tells and gating; nothing new is invented for co-op fairness here.
