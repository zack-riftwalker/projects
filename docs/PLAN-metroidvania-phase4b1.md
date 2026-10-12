# CLAWD Metroidvania — Phase 4B-1 Plan: the map, the cartographer and the small systems (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. گام ۳ و ۴ از پلن کلی رو با هم داره. **بعد از تموم شدن فاز 4B-0 اجراش کن** (وقتی گزارش `docs/reports/metroidvania-phase4b0.md` اومد)، چون روی کارهای اون ساخته می‌شه.
>
> **گام ۳، نقشه‌ی تازه:**
> - **نقشه خودبه‌خود باز نمی‌شه.** نقشه‌نویسی به اسم `tree` تو هر منطقه هست. صدای تایپش میاد و کاغذهای `├──` تا پیشش می‌رن. نقشه‌ی منطقه رو با توکن می‌فروشه. تو R08 کنار README نشسته و نقشه‌ی اول رو مجانی می‌ده. تو DEPTHS بالای اولین دیوار ترک‌دار D01ـه، تو HEAP روی لبه‌ی بالای خارهای H04.
> - **جاهایی که رفتی** فقط وقتی رو نقشه کشیده می‌شن که رو نیمکت استراحت کنی («commit»). نقشه بین دو نفر مشترکه.
> - **نقشه‌ی خوندنی:**
>   - زوم منطقه و زوم کل دنیا، با کشیدن انگشت و دکمه‌های + و −.
>   - درها روی دیوار اتاق‌ها، و یه «…» برای درهایی که پشتشون رو هنوز ندیدی.
>   - P1 دایره با «1»، P2 لوزی با «2». بالای صفحه نوشته شریکت کجاست.
>   - مانع‌هایی که هنوز ازشون رد نشدی یه «؟» بی‌اسم دارن.
> - **نقشه دیگه شریک رو pause نمی‌کنه:** یه دکمه‌ی map کنار pause میاد. شریکت یه آیکون نقشه بالای سرت می‌بینه.
> - **سنجاق و پینگ:** رو نقشه سنجاق می‌ذاری (TODO، ؟، HELP، توانایی). پینگ «بیا اینجا / صبر کن / کمک / نگاه کن» شش ثانیه برای هر دو دیده می‌شه، با یه فلش کنار صفحه.
> - **خط changelog:** وقتی توانایی تازه می‌گیری، تو اولین استراحت ترمینال یه خط مرموز میاد که فقط اسم منطقه رو می‌گه.
> - **سفر به منطقه‌ی شریک:** تو لیست Travel یه خط «→ P2» هست.
> - **رازها هیچ‌وقت لو نمی‌رن:** اتاق مخفی فقط بعد از پیدا شدن روی نقشه میاد، و 404 اصلاً نمیاد.
>
> **گام ۴، سیستم‌های کوچیک و منطقه‌های ساخته‌شده:**
> - **ایجنت‌های گمشده:** تو شیشه‌ان و با یه ضربه آزاد می‌شن. دور نیمکت R08 جمع می‌شن (`contributors: n/8`). با ۴ تا یه خونه‌ی پلاگین اضافه می‌گیری، با ۸ تا یکی دیگه. الان دو تا ساخته می‌شه: H13 و D07.
> - **دفترچه‌ی پروانه:** برگ اول تو H15. بقیه با منطقه‌هاشون میان.
> - **صفحه‌ی Logs:** همه‌ی تابلوهایی که خوندی، با فونت بزرگ، به ترتیب منطقه. هر تکه‌ی حافظه هم یه خاطره از اون شب داره.
> - **تغییرهای منطقه‌های ساخته‌شده:**
>   - درِ بسته‌ی symlink تو R06، با تابلوی TODO، چراغ و دو صندلی.
>   - چکه‌ی HEAP تو سطل D04.
>   - تابلوی ته چاه H03.
>   - صحنه‌ی D07.
>   - ترمینال‌ها امن می‌شن و صدای فن می‌گیرن.
>   - نشونه‌های دور تو پس‌زمینه: سایه‌ی برج، فانوس GC، سرخی افق.
>
> **جلسه‌ی Sonnet:** یه جلسه‌ی جدید با Sonnet روی برنچ `ph1` باز کن و بنویس «فایل `docs/PLAN-metroidvania-phase4b1.md` رو بخون و اجراش کن». یا بگو تا خودم باز کنم.

---

## 0. Rules of engagement

- **Start only after phase 4B-0 is done:** `docs/reports/metroidvania-phase4b0.md` exists and its status table says MVB0-11 done. If not, stop and say so.
- **Read first, in order:**
  1. `CLAUDE.md` (especially "Godot version" and its co-op rules).
  2. This file, all of it.
  3. `docs/reports/metroidvania-phase4b0.md` (what 4B-0 built: world flags in snapshots, sign alts, variants, packets, the boss kit; names as built).
  4. `docs/metroidvania/08-world-design.md` §7, §8 and §10 (especially §10.4, §10.6, §10.7, §10.9).
  5. `docs/metroidvania/00-decisions.md` §14 (D37–D52; this phase builds D42, D46–D50, D52's built-zone part).
  6. `docs/reports/world-map-research-7-ingame-map.md` §2, §4 and §5 (the map research this follows).
  7. Then the code under `godot/src` you are about to change.
  - Phase 4A's plan (`docs/PLAN-metroidvania-phase4a.md`) §0 still applies where this file does not say otherwise.
- **Do only phase 4B-1.** Stop after MVB1-15 and report. No NETWORK rooms, no new abilities, no bosses.
- **Do not redesign.** Values, names, texts, coordinates and data in this file are decisions. If one is impossible, take the smallest change that keeps the goal and list it under "deviations" in the report.
- **Room files:** only the changes listed in MVB1-13 (R06, D04, D07, H03). Coordinates are `(column, row)`, 0-based, as in the room file.
- **Branch:** `ph1` only.
  - Start with `git fetch origin main ph1 && git checkout ph1 && git merge --no-edit origin/ph1 && git merge --no-edit origin/main`.
  - Push with `git push -u origin ph1`. Never push or merge to `main`, never open a PR.
- **Files you may touch:**
  - Allowed: everything under `godot/` and `tools/godot/`; `docs/metroidvania/`; `docs/reports/metroidvania-phase4b1.md`; this plan's status table.
  - **Not allowed:** `server.js`, `public/index.html`, `cloud/`, `.bat`/`.ps1`, `package*.json`, `CLAUDE.md`.
  - `public/mv/` changes only through `tools/godot/export-web.sh`, as the last commit of the phase.
- **Commits:** one commit per task (`MVB1-xx: <what>`), ending with the attribution lines your session gives you. Push after each.
- **Co-op rules (from `CLAUDE.md`, not optional):** state over events; what the guest reads goes through snapshots or world flags; a new kind of co-op bug gets a watchdog rule; reliable event data lives only in `d`; never name a field `i` or `k`.
- **Godot naming trap:** never name your own members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Tests:** every task names its tests; every new `--test=` goes into `test-all.sh`, every new scenario into `ALL=` in `coop-test.sh`. Before the final commit: `bash tools/godot/test-all.sh` → `ALL PASS`.
- **Nothing built may change behaviour** except what this plan changes: parity tapes, every existing test and scenario keep passing. Movement is untouched.
- **Phone first:** every new screen works with touch (buttons drawn in the game viewport, the existing `tap()` pattern) and fits 384×216. No text smaller than the `tiny` font; running text in the Logs page uses the normal font.

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MVB1-01 | world state by digest (the guest asks for the world flags only when its digest differs) | Sonnet | done |
| MVB1-02 | zones table; `zone`, `secret`, `offmap` in `rooms.json` | Sonnet | done |
| MVB1-03 | map data: staged and committed rooms, map ownership, commit on rest, save migration | Sonnet | done |
| MVB1-04 | the cartographer `tree`: NPC data, drawing, sound, paper scraps, the index menu, co-op buying | Sonnet | done |
| MVB1-05 | the map page: zone and world view, rooms, doors, stubs, markers, header, counters, secret rules | Sonnet | done |
| MVB1-06 | the map as a local overlay (no pause in co-op); the `map` action and touch button; the partner's map icon | Sonnet | done |
| MVB1-07 | obstacles: `?` marks and the terminal changelog line | Sonnet | done |
| MVB1-08 | pins and pings | Sonnet | done |
| MVB1-09 | travel to the partner's zone terminal | Sonnet | done |
| MVB1-10 | the Logs page and the memory line of every fragment | Sonnet | done |
| MVB1-11 | lost agents and the plugin notches | Sonnet | done |
| MVB1-12 | logbook pages (the item and the data for all six) | Sonnet | done |
| MVB1-13 | decor and the built-zone changes (R06, R08, D01, D04, D07, H03, H04, H13, H15) | Sonnet | done |
| MVB1-14 | terminals (safe, fan, calm music) and far landmarks | Sonnet | done |
| MVB1-15 | tests, build, playtest steps, report → **stop** | Sonnet | done |

## 2. Facts already verified (do not rediscover)

Read by Claude on `ph1` at `efcfbbc` (4B-0 in progress; names from 4B-0 may differ slightly, its report wins).

1. **The pause map today** (`godot/src/ui/pause.gd` `_draw_map`): every room in `Game.map_rooms()` (flag `room:<id>:visited`, set by `RoomManager` when a room is entered; lab rooms skipped) as a rectangle scaled to fit 360×170 at most 0.5 px per tile; benches green; the player a blinking white dot. It is a page of the pause menu, and pause is shared in co-op (`Main.set_paused` sends `pause`), so opening it stops the partner.
2. **Benches** (`RoomManager.rest`): heal, `bench:<room>` flag, respawn point, save; the first rest pops `committed ✓`. `rested(room_id)` is emitted; a guest's rest reaches the host. `travel_targets()` = rested benches of `terminal` rooms. The bench menu (`bench_menu.gd`) has Rest / Travel (terminals only) / Plugins / Leave.
3. **The shop** (`shop_menu.gd`, letter `$`): solo and host buy at once; a guest asks the host (`buy`) and pays only when the host's answer arrives (`Coop`, ~line 452 and ~1387). The index menu of `tree` copies this pattern.
4. **Menus in co-op:** while a bench or shop menu is open, the local body stands still and takes no input (`player.in_menu`), and the world goes on (`main.gd` ~line 520). Alone, the world waits. The map overlay (MVB1-06) uses the same rule.
5. **World flags** (4B-0): `Game.WORLD_PREFIXES` and `wf` in snapshots, sent when changed and on every 10th snapshot. This phase adds many world flags (rooms committed, logs, agents), so MVB1-01 turns `wf` into a digest exchange first.
6. **Signs** are `T` letters numbered in reading order (row by row, left to right); `signs[i]` in `rooms.json` is the text of the i-th `T` (a string, or since 4B-0 a dict with `alt`). Adding a `T` before an existing one shifts the list: MVB1-13 gives the final lists.
7. **Items** (`Room.items`, `collect()`): kinds `token`, `spark` (memory fragment, id `item:<room>:f<n>`), `plugin`, `coffee`. A guest asks the host for a pickup (`net_pickup`); the host decides. Fragments today: R01, R02, R03, R06, R11, R13, D01, D02, D03, H12, H15 (one each).
8. **Plugin notches:** `Game.NOTCHES := 3` (const), used by `notches_used()`/`filter_loadout()`/`toggle_plugin()`.
9. **Input actions** (`controls.gd`): `left right up down jump attack dash special pause start`. Touch has four buttons and a pause rect (`touch_controls.gd`).
10. **Audio** (`audio.gd`) has sound effects and one music player with crossfade and `duck()`; no ambience channel.
11. **Free map letters** after 4B-0: uppercase `A F I O Q W`, lowercase `c e h j r u y z`. This phase adds **no** letter: NPCs, agents, pages and decor are placed by coordinates in `rooms.json`, so built room files barely change.
12. **The world checker** (`tools/godot/roomcheck/world.py`, 4B-0) already knows `R06:W` will be a symlink door to `G16:E` (the design link); after MVB1-13 it must still print `errors 0`.

## 3. Shared definitions

### 3.1 Zones

`Game.ZONES` (order = map legend order):

| id | name | path | colour |
|---|---|---|---|
| `src` | THE SOURCE TREE | `~/src` | `#3fa46a` |
| `dep` | DEPENDENCY DEPTHS | `~/node_modules` | `#c9792a` |
| `heap` | THE HEAP | `/proc/heap` | `#3cbfaa` |
| `net` | THE NETWORK | `/net` | `#5078e6` |
| `tower` | THREAD TOWER | `/dev/threads` | `#c8a05a` |
| `git` | GIT HISTORY | `.git` | `#e6783c` |
| `hell` | DEPENDENCY HELL | `~/node_modules/**` | `#9a5ac8` |
| `prod` | PRODUCTION | `/var/prod` | `#dc3c3c` |
| `lab` | LAB | `/tmp/lab` | `#8a8f99` |

### 3.2 New `rooms.json` fields

| field | where | meaning |
|---|---|---|
| `"zone": "<id>"` | every room | R* `src`, D* `dep`, H* `heap`, Z* `lab` (later phases set theirs) |
| `"secret": true` | room | R06, R12, R13, R15, D07, H12, H13, H14, H15, H16: on the map only once committed; never in a `tree` outline; not in the zone's room count |
| `"offmap": true` | room | never on the map, never counted, no pins or pings there (N20 `404` in phase 4B; no built room has it) |
| `"npc": [{"kind": "tree", "x": c, "y": r, "zone": "<id>", "price": n}]` | room | the cartographer, feet on the floor under cell `(x, y)` |
| `"agents": [[c, r]]` | room | a lost agent's jar at that cell (MVB1-11) |
| `"pages": [[c, r, n]]` | room | logbook page `n` (1–6) at that cell (MVB1-12) |
| `"decor": [{"kind": k, "x": c, "y": r, "if": cond}]` | room | decoration, no collision (MVB1-13) |
| `"landmarks": ["tower" \| "lantern" \| "horizon"]` | room | far landmarks in the backdrop (MVB1-14) |

Conditions (`if` in decor, already `if` in sign alts and variants): `"<flag>"`, `"!<flag>"`, `"flood>0"`, `"flood==0"` (`Game.heap_flood()`). Put the parser in one place (`Game.cond(s)`) and use it for all three.

### 3.3 Flags (all world flags: add the prefixes to `Game.WORLD_PREFIXES`)

| flag | meaning |
|---|---|
| `map:<zone>` | the zone's index is owned (bought from `tree`) |
| `mapped:<room>` | the room is committed (drawn on the map) |
| `map:migrated` | an old save was migrated once (MVB1-03) |
| `changelog:<ability>` | that ability's changelog line was shown |
| `log:<room>:<n>` | sign `n` of the room has been read |
| `agent:<room>` | the agent of that room was freed |
| `page:<n>` | logbook page `n` was found |

`room:<id>:visited` stays as it is (each page's own "has been here"); it is the **staged** list of the local player.

---

## MVB1-01 · World state by digest

1. `Game.world_digest() -> int`: a stable hash (e.g. FNV-1a 32-bit over the sorted world flags joined by `\n`). Order-independent, same on both pages.
2. Host: every snapshot carries `wh` (its digest). It sends `wf` (the full sorted list) only when the guest's last reported digest differs from its own, at most once per second, and once right after a guest joins.
3. Guest: its `st` message carries `wh` (its own digest after applying everything). On `wf`, set every listed flag (never clear one) and call `room.update_doors()`.
4. Remove the "every 10th snapshot" rule from 4B-0 (the digest replaces it). Keep "send when changed": a change makes the digests differ, so it goes out within a second.
5. Watchdog rule `world-digest` (host): the guest's digest differs from the host's for more than 5 s while the guest is connected and not lagging → `INVARIANT world-digest: ...`. A guest-only world flag the host never learns is a bug and shows here.
6. Tests:
   - Unit `worlddigest`: the digest does not depend on insertion order; adding a flag changes it; a non-world flag does not.
   - Co-op `co-worldsync`: the host sets 200 world flags (`log:Z01:0`…) in one step; the guest has all of them within 3 s (8 s with `SCN_SLOW`); then, for 10 s with nothing changing, the host sends no `wf` (count them); no `INVARIANT`. Also with `BADLINE_ALL=1`.
   - `co-flags` (4B-0) still passes.

## MVB1-02 · Zones and room data

1. `Game.ZONES` (§3.1) and `Game.zone_of(room_id) -> String` (from the room's `zone`).
2. Add `zone` to every room in `rooms.json`, and `secret: true` to the ten secret rooms of §3.2.
3. `Game.map_rooms()` keeps its job (the visited list) for anything that still uses it; the new map uses MVB1-03's functions.
4. Test (in `mapdata`, MVB1-03): every room has a known zone; the ten secret rooms are marked; no lab room is `src`.

## MVB1-03 · Map data: staged, committed, owned

1. **Staged:** `room:<id>:visited` (unchanged): set for the local player when it enters a room.
2. **Committed:** `mapped:<room>` world flags.
   - Solo: resting at any bench commits every staged room that is not committed yet.
   - Co-op: the **host** keeps a staged list for the guest too (it already learns the guest's room changes). When either player rests (the host's `rested`, or the guest's rest reaching the host), the host commits both lists. The guest learns through world flags.
   - Resting shows `committed ✓ +N rooms` when N > 0 (instead of only on the first rest).
3. **Owned:** `map:<zone>` world flags (MVB1-04 sets them).
4. **What the map may draw** (`Game.map_view(zone) -> Dictionary`, one function both pages use):
   - `outline`: if `map:<zone>`: every room of the zone that is in `rooms.json`, not `secret`, not `offmap`, not `lab`.
   - `filled`: committed rooms of the zone, minus `offmap`. A committed `secret` room is drawn (it has been found).
   - Without `map:<zone>`: nothing for that zone, even committed rooms (the map must be found). The text lines (header, partner) still show.
5. **Save migration** (on load, once): if `map:migrated` is not set, commit every visited room (`mapped:`), own the zone of every visited room (`map:`), set `map:migrated`. A new game has no map until `tree`.
6. Unit test `mapdata`:
   - Visit R01, R02 (staged), no rest: nothing committed; rest at R08: both committed.
   - Without `map:src` the view of `src` is empty even with committed rooms; with it, `outline` has every non-secret `src` room and `filled` the committed ones.
   - A committed secret room (R06) is in `filled`; an uncommitted one is in neither list.
   - Migration: a save with H01–H04 visited and no `map:migrated` gets them committed and `map:heap`.
   - Co-op part in `co-commit` (MVB1-05).

## MVB1-04 · The cartographer `tree`

1. **Data:** `npc` entries (§3.2). This phase: R08, D01, H04 (MVB1-13 gives the coordinates).
2. **Drawing** (no art file): a small hunched daemon (about 12×14 px) at a tiny desk with a printer; a strip of paper hangs from the printer and grows by one `├──` line every 2 s while a player is within 10 tiles, then tears off (a falling scrap particle). `├──` and `└──` drawn with `PixelText` (they are in its font; if not, draw them as 1-px lines).
3. **Sound:** a soft typing tick (an existing UI tick sound at low volume, random gaps 0.08–0.25 s) while a player is within 14 tiles; volume rises as you come closer. It never plays alone as the only clue: the scraps (`decor` kind `scrap`) lead to it.
4. **Interaction:** standing next to it and pressing [up] opens the **index menu** (copy `shop_menu.gd`'s structure):
   - not owned: `tree -L 1 <path>` on the first line, then `index <path> — <price> tokens`, `your tokens: n`, and Back. Buying spends the tokens and sets `map:<zone>`. Not enough tokens: `not enough tokens` (no sale).
   - price 0 (R08): `take the index of ~/src` (no tokens).
   - owned: `<path> is indexed. (rest at a bench to commit what you walked.)` and Back.
5. **Co-op:** the map is shared, the tokens are each player's. Solo and host buy at once. The guest asks the host (`buymap`, `{"zone": ...}`); the host sets the flag and answers; the guest pays only when the answer says it was the buyer. A second buyer pays nothing (`already indexed`).
6. Tests:
   - Unit `tree`: R08's index is free; D01's costs 40 and needs 40 tokens; buying sets `map:dep` and takes the tokens; buying an owned map does nothing.
   - Co-op `co-tree`: the guest buys D01's index: both have `map:dep`; the guest paid 40, the host nothing; no `INVARIANT`.

## MVB1-05 · The map page

Replace `_draw_map()` with a map view used both by the pause menu's Map page and by the overlay of MVB1-06 (one class, e.g. `godot/src/ui/map_view.gd`).

**Layout (384×216):**

- Header, y 4: the zone name and path on the left (`THE HEAP  /proc/heap`); on the right `rooms n/N` when the zone's index is owned (N = its outline rooms; secrets and offmap never counted).
- Partner line, y 15: `P2 · /net · N03` (on the guest's screen `P1 · ...`); `P2 · unindexed` when the partner is in an `offmap` room; hidden when alone.
- Map area: x 8–376, y 26–196.
- Button bar, y 200–214 (touch and mouse; each also has a key): `zone/world` [jump], `−` and `+` (zoom), `P2` [attack] (centre on the partner), `pin` [special] (MVB1-08), `ping` (MVB1-08), `back` [dash] or [pause].
- Arrows pan the view (24 px per press, repeating while held); a drag pans too.
- Without the index of the current zone: the map area says `no index for <path>` in the middle; everything else still works (world view still shows other indexed zones).

**Views:**

- **Zone view** (default): the current zone's `outline` + `filled` rooms fit the map area, at most 2 px per tile and at least 0.35; `+`/`−` change the scale ×1.5 within 0.35–4.
- **World view:** every indexed zone; fit at most 0.5 px per tile; each zone tinted with its colour at low alpha and labelled with its path at its centre.

**Rooms:**

- `filled`: zone colour at 25% alpha, a 1-px border in the zone colour; the current room's border in `#f0a184`.
- `outline` only: a dotted grey border (2 on, 2 off), no fill.
- Benches: a green 2×2 dot; terminals: a small screen icon (different from benches).
- **Doors** of a filled room (M2): the border is broken along the door's span. A door whose target room is not `filled` gets a short stub (3 px out) and `…` when the scale allows (≥ 1 px per tile). Never drawn: a door into a `secret` room that is not committed, a door whose cells are unrevealed dead code (`;` without `dead:<room>`), a door to a room that does not exist (sealed), any door of an `offmap` room.
- Never drawn: `lab` rooms, `offmap` rooms, uncommitted secret rooms.

**Players (M3):** P1 a circle with `1` (`#f0a184`), P2 a diamond with `2` (`#8fd0ff`), 7 px, steady (no blink), drawn at the player's cell inside its room. Drawn only when that room is in the view (filled or outline); otherwise only the partner line says where it is. On the guest's page the host is P1.

**Counters (M8):** zone view header `rooms n/N` (only with the index). The world total is never shown in this phase (it comes with the ending).

**Tests:**

- Unit `mappage`: for every zone and both views, with everything committed and indexed, the draw runs without error and every drawn room rectangle is inside the map area; zoom and pan by script input change the transform; a secret room appears only after `mapped:`; lab rooms never; `no index` text without `map:<zone>`.
- Screenshot helper: `scene=map` (main.gd) now commits and indexes every non-lab room, so the capture tool shows the new page.
- Co-op `co-commit`: the guest walks R08 → R09 → D01 (staged on the host), the host rests at R08: both have `mapped:R09` and `mapped:D01`; the guest's map view lists them as filled (with `map:dep` set by the scenario).

## MVB1-06 · The map as a local overlay

1. New action `map`: keys `M` and `Tab`, joystick `JOY_BUTTON_GUIDE` and `JOY_BUTTON_LEFT_STICK`. Touch: a small map button left of the pause rect (same size and style).
2. Opening the map this way does **not** pause in co-op: the body stands still and takes no input (`in_menu`, like the bench menu), the world goes on, the partner is not paused. Alone, the world waits (like the bench menu).
3. The pause menu's Map page stays (pause is shared, so it pauses both, as today).
4. **The partner's map icon:** while a player has the overlay open, its partner sees a small folded-map icon above that player's head. Carried as state: the guest's `st` gets `"mn": 1|0`; the host's own player in the snapshot (`p1` record) gets the same flag (add a field, do not reuse `pose`).
5. **Quick pin:** holding the map button (or key) 0.6 s without releasing drops a `TODO` pin at the player's position (MVB1-08) instead of opening the map; a short pop `pinned`.
6. Closing: the `back` button, [dash], [pause] or the map action again. [dash] closes; it never places a pin (research report 7: the Back button never pins).
7. Tests:
   - Co-op `co-map`: the guest opens the overlay for 3 s: the host's room time keeps advancing and the host is not paused; the host sees `mn` = 1 for the guest during it and 0 after; then the host opens it and the guest sees the same. No `INVARIANT`.
   - Unit `mapoverlay`: alone, the world does not step while the overlay is open; holding the map key 0.6 s places a TODO pin and does not open the overlay.

## MVB1-07 · Obstacles: `?` marks and the changelog line (M5, option A)

1. **Obstacle table** (`Game.OBSTACLES`, letter → ability): `%` → `bash`, `!` → `catch`, `&` and `k` → `agents`, `@` → `curl`, `N` → `ssh`. Later phases add their letters (package-lock floor → `--force`, piston → `breakpoint`, plate → `revert`, cable → `opus`).
2. **`?` marks:** for every **filled** room, each obstacle cell (one mark per 4-connected group, at its centre) is drawn as a small unnamed `?` in the zone view, unless:
   - it has been passed: a crack broken (`crack:` flag), a gate opened (`gate:<room>:catch|agents`), a slot key pressed;
   - it lies within 2 cells of unrevealed dead code (it would point at a secret).
   Marks never show the ability or the type. (Rings and firewall bricks stay marked; the player has to remember which `?` was what.)
3. **Changelog:** when an ability is gained (`Game.tools[x]` turns true; the abilities of 4B and later use the same path), it is remembered as pending. At the next rest at a **terminal**, for each zone that has a filled room with an unpassed obstacle of that ability, one line appears in a small panel under the bench menu for 6 s (and goes to the Logs page, MVB1-10):
   - `changelog: something in <path> now answers to <ability>`
   - Then `changelog:<ability>` is set (once per game). No zone → no line, the flag is still set.
   - Wording per ability: `bash` "gives way to bash", `catch` "answers to catch", `agents` "waits for agents", `curl` "answers to curl", `ssh` "lets ssh through". Format: `changelog: something in <path> <wording>`.
4. Co-op: both pages compute the marks from world flags (no sync needed). The changelog is shown on the page that rests; the flag is a world flag.
5. Tests: unit `changelog`:
   - H02 committed with its ceiling crack unbroken → one `?` there; after `crack:H02:...` → none.
   - With H01 committed and `map:heap`, gaining `curl` then resting at H03 shows exactly one line naming `/proc/heap`; resting again shows nothing.
   - No mark next to H03's unrevealed dead code.

## MVB1-08 · Pins and pings (M6, M7)

**Pins:**

1. Kinds: `TODO`, `?`, `HELP`, `ability` (icons: a small T, a ?, a !, a diamond). Each has an owner (P1/P2) and is drawn in the owner's colour. At most 24 shared pins; a 25th removes the oldest.
2. Place: in the map, a crosshair in the middle of the map area; the `pin` button (or [special]) cycles the kind on the first press and places on the second; pressing on an existing pin within 6 px removes it. Quick pin: MVB1-06 §5.
3. Shared state: the host owns the list; a guest asks with reliable `pin` (`{"op": "add"|"del", "room": ..., "x": ..., "y": ..., "kind": ...}`); snapshots carry `pn` (the full list) when it changed, and its hash is part of the world digest (MVB1-01) so a lost update corrects itself.
4. No pins in `offmap` rooms; saved with the game (host's save).

**Pings:**

5. In the map, `ping` then a kind: `go here`, `wait`, `help`, `look`, at the crosshair. Reliable `ping` (`{"room", "x", "y", "kind", "id"}`); lives 6 s on both pages.
6. Shown on the map (a pulsing ring with the kind's word) and in the game as an arrow at the screen edge pointing from the player's room centre to the ping, with the word and the seconds left.
7. The receiver acknowledges by tapping the arrow, or opening the map while it lives: reliable `pingok` (`{"id"}`); the sender sees `✓` on its ping.
8. No pings in `offmap` rooms; a ping never pauses anything.
9. Tests: co-op `co-pins`: the guest adds a pin and the host lists it within 1 s; the host removes it and the guest's list is empty within 1 s; the host pings, the guest sees the arrow, acknowledges, and the host sees `✓` within 2 s; no `INVARIANT`.

## MVB1-09 · Travel to the partner's zone terminal (M10)

1. The Travel page gets an extra first line `→ P2 (<path>)` (on the guest's page `→ P1 (...)`) when the partner is in another zone and this player has rested at a terminal of that zone. It travels to that terminal, like the other entries. Each player moves only itself; nobody is pulled. D32 is unchanged (only from a terminal, only to a terminal).
2. Unit `travelp2`: with a fake partner in H05 and `bench:H03` set, standing at R08's bench, the Travel list's first line is `→ P2 (/proc/heap)` and choosing it travels to H03; with the partner in `src`, the line is absent.

## MVB1-10 · The Logs page and the fragment memories (L3, L4)

1. **Reading a sign** (the moment its text box shows) sets `log:<room>:<n>`. Finding is shared (world flag); reading the Logs page is local.
2. **Logs page:** a new item `Logs` in the pause menu and in the bench menu of terminals. Sections by zone (in `Game.ZONES` order), each listing the read signs' texts as they read now (sign alts included), then `memories` (MVB1-10 §3), then `logbook` (MVB1-12) and `changelog` lines (MVB1-07). Normal font (not tiny), wrapped to 340 px, scroll with up/down or a drag; [dash]/[pause] back.
3. **Fragment memories:** picking up a fragment shows, under the existing `memory chip ✳ n/4` pop, one line from this table (also listed in Logs under `memories`). Keyed by the fragment's room:

| room | line |
|---|---|
| R01 | `02:47 — the build went red. nobody else was awake.` |
| R02 | `02:51 — the first test failed: null, where something used to be.` |
| R03 | `02:58 — the linter screamed about code nobody had read in years.` |
| R06 | `03:02 — an old room, left in on purpose. the lamp was still on.` |
| R11 | `03:20 — try/catch around everything, and then sleep.` |
| R13 | `03:05 — the tests folder still had a test for two players.` |
| D01 | `03:34 — npm install. one thousand and forty-two packages.` |
| D02 | `03:41 — a package was unpublished. everything above it fell.` |
| D03 | `03:50 — the lockfile and the code disagreed about what was true.` |
| H12 | `04:20 — memory was taken and never given back.` |
| H15 | `04:31 — the crash dump kept a process mid-sentence.` |
| N19 | `04:47 — the backup still had last week's working build.` |
| T14 | `05:12 — two threads wrote the same line at once.` |
| X13 | `03:59 — the cache remembered a version that worked.` |
| G15 | `05:33 — the first commit: "hello world. for two."` |
| P16 | `05:51 — nine minutes to deploy. the old core still holding the roof up.` |

   (The last five rooms come with their zones; the table lives in `Game` now so those phases only place the fragment.)
4. Tests: unit `logs`: reading Z01's sign sets `log:Z01:0`; the Logs page lists it under `LAB`? No: lab rooms are skipped in Logs too; use R08's sign: reading it sets `log:R08:0` and the page lists its text under THE SOURCE TREE; picking up R06's fragment shows the R06 line and lists it under memories.

## MVB1-11 · Lost agents and the plugin notches (K2)

1. **The jar:** `agents` entries (§3.2). A glass jar (12×16 px) with a tiny agent inside (reuse the agent helper's look from `player/agent.gd`, smaller), a `…` bubble above it, a soft beep every 2 s while a player is within 10 tiles (sound **and** the bubble: never sound only).
2. **Freeing:** a claw swipe or a dash that overlaps the jar breaks it (not walking into it): glass burst, the agent flies up and off-screen, pop `agent freed  n/8`. Sets `agent:<room>`. A guest's swipe asks the host (the pickup path: the host checks the overlap with its record of the guest's attack, sets the flag, answers). It counts for both players.
3. **R08:** freed agents gather around the bench: `n` small idle agents drawn left and right of R08's bench, and a line `contributors: n/8` above it (decor kind `contributors`, MVB1-13), shown when n ≥ 1.
4. **Notches:** `Game.notches() -> int` = 3, +1 with 4 agents, +1 more with 8 (D47; D25 grows to 5). Replace every use of the constant (`notches_used`, `filter_loadout`, `toggle_plugin`, the bench menu's dots, the shop if it shows them).
5. Placements this phase: H13 and D07 (MVB1-13). The other six (R18, N20, T15, G05, X13, P17) come with their zones.
6. Tests:
   - Unit `agents`: a swipe overlapping D07's jar frees it and sets `agent:D07`; walking into it does not; with `agent:*` flags for 4 rooms `notches()` is 4, with 8 it is 5; a loadout of 4 notches fits with 4 agents and not with 3.
   - Co-op `co-lostagent`: the guest frees H13's agent: both have `agent:H13`; the host's R08 shows one contributor; no `INVARIANT`.

## MVB1-12 · Logbook pages (K3)

1. **The page:** `pages` entries (§3.2). A torn sheet of yellowed paper that flutters in place; collected on touch (the normal pickup path); sets `page:<n>`; pop `logbook page n/6`. Its text goes to the Logs page under `logbook`.
2. **Texts** (all six now; only page 1 is placed this phase, the others come with their rooms; the order of Panel F's switches in G15 is the relays sorted by time: 3, 1, 4, 2):

| n | room | text |
|---|---|---|
| 1 | H15 | `15:25  relay #4 clicked twice. nothing found.` |
| 2 | N19 | `14:10  relay #1 stuck open. tapped it shut.` |
| 3 | T14 | `15:45  relay #2: moth in relay. first actual case of bug being found.` |
| 4 | G16 | `13:05  relay #3 warm. ran the test again.` |
| 5 | X13 | `16:00  taped into this book. we checked the relays in the order of these times.` |
| 6 | P16 | `15:50  panel F closed up. it ran.` |

3. Test (in `logs`): picking up H15's page sets `page:1` and the Logs page shows its text under `logbook`.

## MVB1-13 · Decor and the built-zone changes

**Decor** (`decor` entries, §3.2; drawn on the furniture layer; no collision; `if` per §3.2):

| kind | look |
|---|---|
| `scrap` | a curled paper scrap with a tiny `├──` |
| `drip` | a harmless green drop falling from the cell to the first solid cell below, one every 0.6 s, with a small splash; no damage |
| `bucket` | a small grey bucket |
| `lamp` | an orange desk lamp; lit (a warm glow cone) only when the entry's `"lit": "<cond>"` holds |
| `chair` | an office chair |
| `package` | a cardboard box with a patch of tape and a handprint |
| `contributors` | the text `contributors: n/8` and the gathered agents (MVB1-11) |

**The changes, one by one** (08 §7, pass-1 table; this phase does rows 1–4, 6–14; row 5's art is MVB1-14):

1. **R06** (W1, S1, L2):
   - Room file: cells `(0, 9)`, `(0, 10)`, `(0, 11)`, `(0, 12)` become ` ` (the door opening). Add `T` at `(2, 8)` and `T` at `(17, 12)`.
   - Door: `{"id": "R06:W", "side": "W", "a": 9, "b": 12, "to": "G16:E", "lock": "until:link:src", "symlink": true}`. G16 does not exist yet, so it stays shut (a door to a missing room never opens).
   - Signs, final list in reading order:
     1. `ln: ../.git/old: broken symlink`
     2. `A hidden file! Cracked walls like that one hide things all over ~/src.` (unchanged)
     3. `{"text": "// TODO: remove this room.", "alt": [{"if": "boss:MONOLITH", "text": "// TODO: remove this room. — Not tonight."}]}`
   - Decor: `lamp` at `(19, 12)` with `"lit": "boss:MONOLITH"`; `chair` at `(20, 12)` and `(21, 12)`.
2. **R08** (K2, the map):
   - `npc`: `{"kind": "tree", "x": 15, "y": 12, "zone": "src", "price": 0}`.
   - Decor: `contributors` at `(3, 9)`; `scrap` at `(12, 12)` and `(13, 12)`.
   - Sign 1 becomes `{"text": "Next door: the ledges go up to a code review; the low door goes down to ~/node_modules.", "alt": [{"if": "boss:MONOLITH", "text": "README: shipped at 06:00. keep the little orange one."}]}`.
3. **D01** (the map): `npc` `{"kind": "tree", "x": 19, "y": 4, "zone": "dep", "price": 40}` (on the row-5 ledge above the first cracked wall; reached with jump + bash up). Decor `scrap` at `(9, 8)`, `(11, 8)`, `(14, 4)`, `(16, 4)`.
4. **D04** (S2): Room file: add `T` at `(18, 12)`. Signs: keep sign 1; add sign 2 `{"text": "leak detected: please bring a bucket", "alt": [{"if": "boss:LEAK", "text": "leak fixed. keeping the bucket, just in case."}]}`. Decor: `drip` at `(15, 2)` with `"if": "flood>0"`; `bucket` at `(15, 12)`.
5. **D07** (K2, L2): Room file: add `T` at `(7, 12)`. Signs: keep sign 1; add sign 2 `abandoned does not mean unloved`. `agents`: `[[21, 12]]`. Decor: `package` at `(9, 12)`.
6. **H03** (S3): Room file: add `T` at `(9, 57)` (next to the existing sign; only reachable at flood 0). Signs: keep 1 and 2; add sign 3 `free() is not the same as goodbye.`
7. **H04** (the map): `npc` `{"kind": "tree", "x": 45, "y": 8, "zone": "heap", "price": 40}` (on the row-9 ledge above the spikes). Decor `scrap` at `(40, 8)`, `(42, 8)` and `(27, 14)`.
8. **H13** (K2): `agents`: `[[52, 12]]`.
9. **H15** (K3): `pages`: `[[24, 12, 1]]` (on the floor right of the first sign; if the cell is not empty floor-level, the nearest empty one to the right, and say so in the report).

Before adding a `T` or placing anything, check the cell is empty in the room file; if not, take the nearest empty cell on the same row and list it under deviations.

**Tests:**

- Unit `decor`: D04's drip draws only while `heap_flood() > 0`; R06's lamp is lit only with `boss:MONOLITH`; R06's sign 3 reads its alt with `boss:MONOLITH`; R06's west door is closed and its four cells are open inside the room; H03, D04, D07 sign lists match their `T` counts (load each, count `signs`).
- `python3 -I tools/godot/roomcheck/world.py` → `errors 0` (R06's door now has open cells).
- `parity` and the existing room tests still pass.

## MVB1-14 · Terminals and far landmarks

**Terminals (W7, D42):** R08, D04, H03, H08 (and every later `terminal` room automatically).

1. **Safe:** no enemy within 10 tiles of a terminal's bench. Check the four rooms; if one has an enemy letter that close, move it just outside that radius (or remove it if there is no room) and list it under deviations.
2. **Fan:** a new ambience channel in `Audio` (a second player, its own volume, follows the music volume setting): `res://assets/audio/amb_fan.wav`, a 4 s seamless loop of soft low noise with a faint 120 Hz hum. Generate it once with a small Python script using only the standard library (`wave`, `math`, `random`) committed under `tools/godot/` (no new dependency). Volume: full within 6 tiles of the terminal's bench, fading to silent at 20 tiles; silent elsewhere.
3. **Calm music:** within 8 tiles of a terminal's bench the music ducks by 6 dB (`Audio.duck`), smoothly; it comes back when you leave.
4. Sound is only extra: nothing depends on hearing it.

**Far landmarks (W4):** a backdrop layer behind the tiles, slow parallax (0.15), drawn with shapes (no art files), never covering the playfield's readability (low contrast, dark):

| landmark | rooms now | look |
|---|---|---|
| `tower` | H01, H11 | far top right: three thin brass columns and a clock face (THREAD TOWER) |
| `lantern` | H02, H04 | a pale GC lantern far away whose light slowly sweeps |
| `horizon` | R09, R10 | a low red glow along the bottom of the sky with rising specks (PRODUCTION on fire) |

(N01, N05, N08, N10, N11, T08 get theirs with their zones.) The dawn sky after THE MONOLITH (S1) comes with phase 5D; do not build it now.

**Tests:** unit `terminals`: no enemy within 10 tiles of any terminal bench; the fan volume function gives 1 at the bench, 0 at 20 tiles, 0 in a non-terminal room; the four `landmarks` rooms load and draw without error.

## MVB1-15 · Tests, build, playtest steps, report — then stop

1. Add to `test-all.sh`'s list: `worlddigest mapdata tree mappage mapoverlay changelog travelp2 logs agents decor terminals`.
2. Add to `ALL=` in `coop-test.sh`: `co-worldsync co-tree co-commit co-map co-pins co-lostagent`.
3. `python3 -I tools/godot/roomcheck/world.py` → `errors 0`.
4. `bash tools/godot/test-all.sh` → `ALL PASS` (the known timing-sensitive tests may be re-run once). Also `BADLINE_ALL=1 bash tools/godot/coop-test.sh co-worldsync co-commit co-map co-pins co-flags`.
5. Capture the new map page with the screenshot helper (`scene=map`) on a phone-sized viewport and look at it once: text readable, nothing outside the screen. Put the picture in the report.
6. Export with `tools/godot/export-web.sh` as the **last** commit (`MVB1-15: export public/mv`).
7. Write `docs/reports/metroidvania-phase4b1.md`: what was done, deviations, test results, the bandwidth of `wf` before and after the digest (bytes per second with nothing changing), and **playtest steps for Zakaria in Persian**, short:
   - a new game: no map until R08; take the free index from `tree` next to README; rest, and the rooms you walked appear;
   - find `tree` in DEPTHS (D01, on the ledge above the first cracked wall) and in the HEAP (H04, above the spikes) and buy the index;
   - the map button next to pause: in co-op your friend keeps playing and sees a map icon over you;
   - zone and world view, zoom, centring on the partner, a pin, a ping (and the friend's ✓);
   - an old save: its explored zones are still on the map;
   - free the agents in H13 and D07 and see them at R08's bench; the extra plugin notch comes with 4;
   - the Logs page; a fragment's memory line;
   - R06's closed door and its sign; D04's drip and bucket; the fan at terminals.
8. Update `docs/metroidvania/README.md` (phase 4B-1 done) and this plan's status table.
9. Then **stop** and report. Phase 4B (THE NETWORK) is a separate plan and session.

---

## Appendix A · Where things are

| what | where |
|---|---|
| pause menu and today's map | `godot/src/ui/pause.gd` |
| bench menu (Rest, Travel, Plugins) | `godot/src/ui/bench_menu.gd` |
| shop (the index menu copies it) | `godot/src/ui/shop_menu.gd` |
| menus while playing, pause | `godot/src/main.gd` |
| rest, travel, room visits | `godot/src/world/room_manager.gd` |
| items, signs, decor layer, combat checks | `godot/src/world/room.gd`, `room_layer.gd`, `room_view.gd` |
| flags, zones, notches, conditions, save | `godot/src/autoload/game.gd` |
| input actions, touch | `godot/src/autoload/controls.gd`, `godot/src/ui/touch_controls.gd` |
| sound | `godot/src/autoload/audio.gd` |
| co-op | `godot/src/net/coop.gd`, `watchdog.gd`, `godot/src/player/remote_player.gd` |
| tests | `godot/src/test/run_tests.gd`, `coop_scenarios.gd`, `tools/godot/test-all.sh`, `coop-test.sh` |
| world checker | `tools/godot/roomcheck/world.py` |

## Appendix B · Not in this phase

- The ending scene with the agents and `Room for one more.` (5D), Panel F in G15 (5B), the other agents, pages and fragments (with their zones), the dawn sky after THE MONOLITH (5D), the 404 room (4B), a world room total (the ending).
- Retrofitting THE REVIEWER #1 or the other built bosses to the kit.
