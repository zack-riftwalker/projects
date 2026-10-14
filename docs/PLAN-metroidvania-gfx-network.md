# CLAWD Metroidvania — Plan GFX-N: THE NETWORK at its best look (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و انگلیسیه. هدف: ظاهر منطقه‌ی Network در حد بازی‌های AAA. اول «حداکثر گرافیک»، بعد بهینه‌سازی.
>
> **چی ساخته می‌شه (همه‌ی پیشنهادهای جمینای، اصلاح‌شده، به‌اضافه‌ی ایده‌های من):**
> - **حال‌وهوای رنگی هر بخش:** آبیِ پایدار، بنفشِ پکت‌لاس (`N12`)، سبزِ لانه (`N08`، `N09`، `N17`)، قرمزِ Firewall (`N13` تا `N15`)، سفیدِ Reviewer (`N22`). رنگ‌ها بین اتاق‌ها نرم عوض می‌شن.
> - **قانون کنتراست سه لایه:** پس‌زمینه تیره، زمین متوسط، بازیکن و دشمن و تیر روشن. یه تست خودکار هم اندازه‌اش می‌گیره.
> - **پس‌زمینه‌ی پنج لایه** با مه و ستون نور؛ **لایه‌ی جلوی دوربین**.
> - **نور واقعی:** محیط تاریک، نور روی Clawd، تیرها، LEDها و باس‌ها؛ **Normal Map** روی تایل‌ها؛ **سایه‌ی پویا** (کیفیت Ultra).
> - **افکت تمام‌صفحه:** Bloom، فیلتر رنگ LUT، سایه‌ی دور صفحه، دانه‌ی ریز، خطوط مانیتور.
> - **کفِ براق** با انعکاس، **ذرات زنده** برای هر بخش، **تایل‌های زنده** (LED، فن).
> - **پس‌زمینه‌ای که واکنش نشون می‌ده:** موج قرمز RST، ریختن تارها بعد از کرالر، آروم شدن منطقه بعد از Firewall، گلیچ لحظه‌ای وقتی بسته گم می‌شه.
> - **نورپردازی جدا برای هر آرنا:** کرالر (تاریکی و بیم)، Firewall (هوای داغ و لرزان)، Reviewer (نور سفید).
> - **نور لبه دور Clawd**، **زوم و پالس رنگی** در ضربه‌های بزرگ.
> - **تنظیم گرافیک:** Low / High / Ultra و گزینه‌ی «کم کردن چشمک».
> - منطقه‌های دیگه دست نمی‌خورن. Co-op هم تغییری نمی‌کنه: همه‌اش ظاهریه.
>
> **برای دادن به Sonnet:** «فایل `docs/PLAN-metroidvania-gfx-network.md` رو بخون و اجراش کن.»
> بعدش با تنظیم Ultra روی PC و High روی گوشی بازی کنید. بهینه‌سازی بعد از تست تو روی Y9s انجام می‌شه.

---

## 0. Rules of engagement

- **Start after phase 5A is done** (`docs/reports/metroidvania-phase5a.md` exists on `ph1`). Do not run this plan at the same time as another phase that edits `room.gd`, `room_view.gd` or `main.gd`.
- **Read first, in order:**
  1. `CLAUDE.md`, all of it. The Godot section's speed rules apply to everything here.
  2. This file, all of it.
  3. `docs/reports/fix-2026-10-13-log.md`. It explains why the NETWORK sky was the main lag on the phone, and how it was fixed.
  4. `godot/src/world/net_backdrop.gd`, `room_view.gd`, `landmarks.gd`, `room_layer.gd`, `core/fx.gd`, `main.gd` (`_ready`, `_snap`, `_shot_after`, the `Game.scene` helpers), `ui/pause.gd`, `ui/debug_overlay.gd`, `autoload/game.gd` (settings, URL args).
  5. `assets/theme/w6.json`, and the screenshots in `docs/reports/img-phase4b3/`. They show how the zone looks today.
- **Goal:** the best look we can build. Phone speed is handled with the quality setting (§3.6) and a later optimisation pass after Zakaria's phone test. **Do not drop a feature because it might be slow.** Build it, put it behind the right tier, and measure it.
- **Scope: world 6 (THE NETWORK) only.** Build every system generally, because other zones will adopt it later. But in worlds 1–5 every new system stays off, and those worlds must render exactly as before (§3.8, test `gfxother`).
- **Cosmetic only.** No new net fields, no new reliable events, no change to `NetClasses`, `parity` or the watchdog's rules. Everything a page draws comes from state both pages already have:
  - the room clock `room.time`;
  - hashes;
  - world flags;
  - boss `phase`;
  - `ch_t0`;
  - the packet `lost` / `warn` marks.
  If you find you need new synced state, stop and say so.
- **Never use `room.rng` for anything new.** `room.rng` drives gameplay bursts and the parity tapes. New ambient particles and flicker use their own `RandomNumberGenerator` (seeded from the room id), or hashes.
- **Gameplay readability beats beauty, every time:**
  - Telegraphs, hazards, projectiles, catchable strikes, doors, pickups, the HUD and both players are never darkened, blurred or hidden. They are drawn unshaded, or lit.
  - **Yellow stays reserved for catchable things.** That means `#ffd23f` and any hue from 40° to 65° with saturation above 50 %. No decorative yellow or gold anywhere in this plan; where Gemini's palette had one, this plan replaces it.
  - Flicker, glitch, chromatic aberration and screen flashes all obey "Reduce flashing" (§3.6).
- **Do not redesign rooms.** No room file, door or collision changes. `rooms.json` changes only through `docs/metroidvania/gfx-network-data/apply.py` (MVGN-02).
- **Branch:** `ph1` only. `git fetch origin ph1 && git checkout ph1 && git merge --no-edit origin/ph1`. Do not merge `main`. Never push to `main`, never open a PR.
- **Files you may touch:**
  - May touch: everything under `godot/` and `tools/godot/`; `docs/metroidvania/gfx-network-data/`; `docs/reports/metroidvania-gfx-network.md` and `docs/reports/img-gfx-network/`; this plan's status table.
  - May not touch: `server.js`, `public/index.html`, `cloud/`, `.bat` / `.ps1`, `package*.json`, `CLAUDE.md`.
  - `public/mv/` changes only through `export-web.sh`, as the last commit.
- **No new dependencies.** Generate art (normal maps, LUTs, light textures) with Godot itself, in a headless tool script using `Image`. Commit the generated PNGs and the script that makes them.
- **Commits:** one per task (`MVGN-xx: <what>`), with your session's attribution lines. Push after each.
- **Godot naming trap:** never name members `set`, `get`, `name`, `owner`, `position`, `scale`, `visible`, `show`, `hide`, `free`, `draw`, `size`, `process`, `tr`.
- **Rendering tests need a real renderer.** `--headless` uses a dummy renderer, so lights, shaders and screenshots do nothing there. Screenshot and contrast tests run like `tools/godot/smoke.sh`: `xvfb-run` with `--rendering-driver opengl3`. Put them in `test-all.sh` that way.
- **Tests:** every task names its tests. Before the final commit, `bash tools/godot/test-all.sh` must print `ALL PASS`. Add new `--test=` names to its list.

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MVGN-01 | renderer probe: what works in the web build (Compatibility / WebGL 2), and what it costs | Sonnet | done |
| MVGN-02 | moods: the `mood` field, palettes, the `Look` node that owns every look parameter | Sonnet | done |
| MVGN-03 | quality tiers, "Reduce flashing", URL args, debug overlay line | Sonnet | done |
| MVGN-04 | backdrop v2: five depth layers, haze, light shafts, mood palettes, the 3-tier contrast fix | Sonnet | done |
| MVGN-05 | 2D lighting: ambient, player / partner / projectile / LED / boss lights, unshaded emissives | Sonnet | done |
| MVGN-06 | normal maps for the w6 tiles and the NETWORK sprites | Sonnet | done |
| MVGN-07 | post chain at 384×216: bloom, LUT grading, vignette, grain, scanlines, CA pulse | Sonnet | done |
| MVGN-08 | mood transitions and in-room shifts (N17 chase, FIREWALL phase 3) | Sonnet | done |
| MVGN-09 | foreground silhouette layer | Sonnet | done |
| MVGN-10 | ambient particles per mood and animated tiles (LEDs, fans, vents) | Sonnet | done |
| MVGN-11 | glossy floors (reflection strip) | Sonnet | done |
| MVGN-12 | living backdrop: RST wave, packet-loss glitch, crawler strands fall, calm after FIREWALL | Sonnet | done |
| MVGN-13 | arena lighting: WEB CRAWLER, THE FIREWALL, THE REVIEWER #2 | Sonnet | done |
| MVGN-14 | rim light and outlines: players and creatures | Sonnet | done |
| MVGN-15 | impact feel: zoom punch, CA pulse, flash rules | Sonnet | done |
| MVGN-16 | dynamic shadows (Ultra) | Sonnet | done |
| MVGN-17 | tests, screenshots, measurements, co-op pass, web export | Sonnet | done |
| MVGN-18 | report and playtest steps → **stop** | Sonnet | done |

---

## 2. Facts (verified by Claude on `ph1` at `8203a34`)

1. **The picture:**
   - The game draws into a `SubViewport` of **384×216** (`main.gd`, `game_vp`, nearest filter, 2D snapping).
   - A `TextureRect` (`screen`) scales it up to the window.
   - The HUD is a `CanvasLayer` inside `game_vp`.
   - So every full-screen effect done inside `game_vp` costs only about 83k pixels, even on a phone. Effects drawn on `screen` at window size cost 10–30× more. **Do not put post effects on `screen`.**
2. **Renderer:** `gl_compatibility` on every platform (`project.godot`). The web build is WebGL 2. Which of Godot's 2D effects work there is checked in MVGN-01, not assumed.
3. **THE NETWORK's sky** is `NetBackdrop` (`net_backdrop.gd`), drawn with shapes:
   - eight sky bands;
   - towers with blinking LEDs (parallax 0.12 / 0.05);
   - three sagging cables with running dots (0.3 / 0.12).
   It does **not** use `assets/bg/w1–w4.png`; those are worlds 1–4. The sky is drawn once, the towers redraw twice a second, and only the cables redraw every frame (the 2026-10-13 fix).
4. **Contrast problem today:**
   - The tower fill `C_FILL #141a3a` equals the terrain `base #141a3a` (`w6.json`), so walls melt into the backdrop. See N05's left wall in `img-phase4b3/N05.png`.
   - Every NETWORK room shows the same sky.
5. **Rooms:**
   - Ids: `N01`–`N22`.
   - Arenas: `N09` WEB CRAWLER (boss id `CRAWLER`), `N15` THE FIREWALL (`FIREWALL`), `N22` THE REVIEWER #2 (`REVIEWER2`).
   - Packet loss: `N12` (`packets` + `variants`).
   - The RST chase: `N17` (`chase`).
   - **Gemini's names `N12_loss`, `N17_chase`, `crawler_P3` and `firewall_P3` are screenshot file names, not ids.** "P3" is a boss's third phase (`boss.phase == 3`), not a room.
6. **State both pages already have:**
   - Bosses: `phase` (`boss.gd`; each boss sets it from `_phase_now()`).
   - Defeated bosses: the world flag `boss:<id>` (`room.gd` ~2008).
   - The N17 chase start: `ch_t0`, carried in snapshots as `ch`.
   - Packet loss: per packet `m.lost` / `m.warn`. These are a pure function of the clock (`room.gd` ~857).
7. **Existing effects:**
   - `Fx` has particles (`glow: 1` marks bright ones), rings, pops, discs, `shake` (trauma) and `flash_screen`.
   - `room.hitstop` exists.
   - `Game.shake_opt` scales shake.
   - `Game.low_fx` exists but nothing sets it.
   - Settings are saved by `Game.save_settings()` (diff, coop_hp_pct, vol_music, vol_sfx, fps30).
8. **Co-op rooms:** when the players are in different rooms, the host runs both. The room only the partner is in is `visible = false` (`room.gd` `build_nodes(local = false)`). Every new node must live under its room, so a hidden room shows nothing and lights nothing.
9. **Catchable colour** is yellow `#ffd23f` (`room.gd` ~2174, ~2447; `boss.gd` ~429).
10. **Screenshots:**
    - `--shot=<path>` saves after `--wait=<frames>`; `--full` saves the window instead of the 384×216 picture.
    - `--scene=<name>` sets up special scenes (`main.gd` ~127–215).
    - `debug_overlay.gd` already shows FPS / avg / 1 % low.

## 3. Shared definitions

### 3.1 Moods

A room's look comes from `"mood": [name, k]` in its `rooms.json` entry. `k` (0–1) is how strongly the mood is mixed over `stable`; approach rooms use it to build up to an arena. A room without `mood` in world 6 is `["stable", 1]`. Worlds 1–5 have no mood and keep today's look.

| room | title | mood |
|---|---|---|
| N01–N07, N10, N11, N16, N18, N19, N21 | (all) | `stable` 1 |
| N08 | crawl_queue | `lair` 0.6 |
| N09 | WEB CRAWLER | `lair` 1 |
| N12 | port_scan | `loss` 1 |
| N13 | iptables | `heat` 0.5 |
| N14 | dmz | `heat` 0.7 |
| N15 | FIREWALL | `heat` 1 |
| N17 | 22/tcp | `lair` 0.8 (the chase pushes it, MVGN-08) |
| N20 | 404 | `loss` 0.5 |
| N22 | review_queue | `review` 1 |

After `boss:FIREWALL`, the NETWORK's `stable` rooms use `stable_clean` (MVGN-12).

### 3.2 Palettes

These are Gemini's palettes, minus the yellows, plus `review` and `stable_clean`. All numbers are starting values; tune them by eye against the screenshots and the contrast test (§3.7), and list every change in the report.

| key | stable | loss | lair | heat | heat (boss phase 3) | review | stable_clean |
|---|---|---|---|---|---|---|---|
| `sky_far` | `#070B14` | `#0E0714` | `#060D0A` | `#160505` | `#1E0508` | `#0C0E14` | `#081020` |
| `sky_mid` | `#101F33` | `#231130` | `#11241C` | `#2E0B0E` | `#3A0A12` | `#1A1F2B` | `#12284A` |
| `fog` (rgb, a) | `#1A3A5A`, 0.35 | `#2A1238`, 0.42 | `#0D261B`, 0.48 | `#3D0C11`, 0.38 | `#590815`, 0.25 | `#2A3040`, 0.30 | `#1A4A6A`, 0.28 |
| `ambient` (multiply on the lit world) | `#B0C4DE` | `#9E8FB2` | `#8AA696` | `#D9B3A6` | `#F29999` | `#C8CCD8` | `#C0D6EA` |
| `accent_a` | `#00F0FF` | `#FF0055` | `#39FF14` | `#FF4500` | `#FF1E42` | `#FFFFFF` | `#00F0FF` |
| `accent_b` | `#00FF9D` | `#B266FF` (was `#FFE600`) | `#FF6B00` | `#FF7A2E` (was `#FFA500`) | `#FF4500` | `#FF4B5C` | `#7CFFCB` |
| `bg_brightness` | 0.45 | 0.38 | 0.32 | 0.50 | 0.55 | 0.42 | 0.50 |
| `bg_saturation` | 0.55 | 0.45 | 0.40 | 0.65 | 0.75 | 0.30 | 0.60 |
| `glitch` | 0 | 0.65 | 0.20 | 0.15 | 0.35 | 0 | 0 |
| `bloom` | 0.8 | 0.95 | 0.85 | 1.0 | 1.2 | 0.7 | 0.85 |
| `particles` | data motes | glitch shards | spores, dust | embers | embers ×2 | paper bits | data motes, brighter |
| `gloss` | 0.35 | 0.25 | 0.15 | 0.30 | 0.30 | 0.45 | 0.40 |

How the keys are used:
- `glitch` is the **ceiling** for event-driven glitches (MVGN-12), never a constant effect.
- The LED colours of the towers become `accent_a` / `accent_b`. The tower fill and edge come from `sky_mid` (darker than the terrain, §3.7).

### 3.3 The `Look` node

There is one `Look` per local room (`godot/src/world/look.gd`, `class_name Look`). It holds the current mood parameters as plain floats and colours. It blends them toward a target with `Game.damp` (or a Tween), and pushes them every frame to:
- the backdrop;
- `CanvasModulate`;
- the post chain;
- the particles;
- the lights' colours.

Systems read from `Look`; nothing else stores look state. `Look.set_target(mood, k, immediate)` is called:
- on room load (`immediate = true`);
- on door transitions (1.2 s blend);
- by in-room shifts (MVGN-08, MVGN-12).

In worlds 1–5 `Look` is not created.

### 3.4 Layers (z order inside the room, back to front)

| z / node | what | lit? |
|---|---|---|
| backdrop layers 0–4 (MVGN-04) | sky, far skyline, towers, cable bundles, near racks; haze between them | no: graded by `bg_brightness` / `bg_saturation` / fog in their own colours |
| landmarks | as today | no |
| `Decor`, `Tiles`, `Dynamic` | terrain | **yes** (normal maps, MVGN-06) |
| `furniture` layer (z 1) | signs, benches, terminals | yes; their screens are unshaded emissives |
| `Entities` (z 2) | players, creatures, projectiles | creatures lit + rim (MVGN-14). Projectiles, telegraphs, hazards and catchables are unshaded. |
| `top` layer (z 4) | as today | unshaded |
| foreground silhouettes (z 6, MVGN-09) | near cables and racks | no (dark, see MVGN-09) |
| post chain (MVGN-07) | a `CanvasLayer` in `game_vp`, **below** the HUD layer | — |
| HUD `CanvasLayer` | unchanged | never touched by post |

"Unshaded" means a `CanvasItemMaterial` with `light_mode = LIGHT_MODE_UNSHADED`, or a light mask that `CanvasModulate` and lights skip. Pick one way and use it everywhere: `CanvasModulate` darkens every item in its canvas that is not unshaded.

### 3.5 Lights

- **Kinds:**
  - player (both players);
  - projectile (pooled);
  - LED or sign (static);
  - boss (eyes, beams, the firewall's bricks);
  - arena (MVGN-13);
  - shaft (backdrop only, faked).
- **Budget:** at most 24 active `PointLight2D`s per room on High and 48 on Ultra. Players and bosses first, then projectiles nearest the camera, then statics. The JS game used 40 on mobile / 140 on PC with cheaper lights.
- **Textures:** light textures are generated, soft radial plus one "cone" for beams, small (64 or 128 px), nearest-filtered so lit areas stay pixel-crisp.
- **Shadows:** only lights flagged `shadow: true` cast them, on Ultra (MVGN-16).

### 3.6 Quality tiers and accessibility

| feature | Low | High | Ultra |
|---|---|---|---|
| moods, palettes, contrast fix, transitions | ✔ | ✔ | ✔ |
| backdrop layers | 3 | 5 | 5 + light shafts |
| 2D lights | players + bosses only | budget 24 | budget 48 |
| normal maps | — | ✔ | ✔ |
| bloom | — | ✔ (half-res) | ✔ |
| LUT grading | ✔ | ✔ | ✔ |
| vignette / grain / scanlines | vignette | ✔ | ✔ |
| foreground silhouettes | — | ✔ | ✔ |
| ambient particles | 25 % | 60 % | 100 % |
| glossy floors | — | — | ✔ |
| heat haze (FIREWALL) | — | ✔ | ✔ |
| dynamic shadows | — | — | ✔ |

- **Setting:**
  - "Graphics: Low / High / Ultra" in the pause menu's options, saved with the other settings.
  - `?gfx=low|high|ultra` overrides it (tests, Zakaria's phone check).
  - Default: **Ultra on a PC, High on a touch device** (`Game.touch_seen` or the web's touch check at start).
  - `Game.low_fx = (tier == Low)`, so `Fx` caps follow.
- **"Reduce flashing":** a separate on/off option, saved.
  - When on: no flicker, no glitch tears, no chromatic aberration, `flash_screen` alpha ≤ 0.25, no zoom punch.
  - Gameplay telegraphs stay.
- **Debug overlay:** a line `GFX <tier> lights <n>/<budget> parts <n> post <ms>` (post ms if measurable, else omitted).

### 3.7 The 3-tier contrast rule (measured)

Luminance is `L = 0.299 R + 0.587 G + 0.114 B` on the 384×216 picture.

| tier | what | target |
|---|---|---|
| 1 background | backdrop and landmarks | mean L ≤ 0.16; 99th percentile ≤ 0.35, except LEDs and dots, which are ≤ 2 % of pixels |
| 2 terrain | `Tiles` cells on screen | mean L at least **0.06 above** the background mean behind them; floor cap rows at least 0.40 |
| 3 active | players, creatures, projectiles, hazards | each one's mean L ≥ terrain mean + 0.15, **or** it has an outline (MVGN-14) |

The `gfxcontrast` test (MVGN-17) renders each layer group alone, using node visibility in a test scene, and checks these numbers for every NETWORK room in every mood.

### 3.8 Other worlds stay exactly the same

Before MVGN-02, capture golden PNGs (384×216) of S01, D05, H05 and T04 with a fixed `--wait`, with the bot standing still. Commit them to `tools/godot/golden/`. The `gfxother` test re-renders them and compares bytes. Allow a difference only if it is proven to come from something outside this plan, and say so in the report.

---

## 4. Tasks

### MVGN-01 · Renderer probe (do this first; it decides the paths below)

- **Probe scene:** `--scene=gfxprobe` and `?gfxprobe`. It shows, one after another, 2 s each, with a label:
  1. `CanvasModulate` + 4 `PointLight2D`s;
  2. the same with a `CanvasTexture` normal map on a tile;
  3. `LightOccluder2D` shadows from one light;
  4. a `WorldEnvironment` with 2D glow (background mode Canvas; try with and without the viewport's HDR 2D);
  5. a custom bloom made of two blur passes on down-sampled copies inside `game_vp`;
  6. a `canvas_item` shader reading `hint_screen_texture` (needed for haze, reflections and LUT);
  7. a 3D-LUT grade from a 2D strip texture (16³ as 256×16).
- **Each step logs:** works yes/no (compare the rendered pixels against an expected change), and frame ms over 120 frames.
- **Run it three ways:**
  - desktop under `xvfb-run --rendering-driver opengl3`;
  - the web export in headless Chromium (`tools/godot/web-check.js` style);
  - **write down the steps for Zakaria to open `/mv/?gfxprobe&debug` on the Y9s and send the log.**
- **Choose:**
  - Native glow if it works in the web build; otherwise the custom bloom.
  - Native lights and normals are expected to work; if one does not, its fallback is a shader that fakes it from the light list. Say which.
- **Output:** `docs/reports/img-gfx-network/probe.md` with the table.
- **Tests:** `gfxprobe` (passes when the probe finishes and writes its table; it does not fail on "no").

### MVGN-02 · Moods, palettes, `Look`

- **`docs/metroidvania/gfx-network-data/`:**
  - `moods.json`: the table of §3.1;
  - `palettes.json`: §3.2;
  - `apply.py`: adds `mood` to the `rooms.json` entries; idempotent; takes a repo root argument, like the phase data scripts.
- **`look.gd`:** as §3.3. It loads `palettes.json` (copied to `godot/assets/theme/moods.json`). `RoomManager` creates it for world-6 local rooms and calls `set_target` on load and on door transitions.
- **Tests:**
  - `moods`: every N room resolves to a mood.
  - `Look` reaches its target in 1.2 s ± 0.1.
  - A room in worlds 1–5 has no `Look`.
  - `gfxother` (golden capture first, §3.8).

### MVGN-03 · Quality tiers and "Reduce flashing"

- Build §3.6:
  - the pause-menu options (same widget style as the existing ones);
  - the saved settings;
  - `?gfx=` and the default by device;
  - the debug overlay line;
  - `Game.low_fx`.
- Every later task reads `Game.gfx_tier` and `Game.reduce_flash`.
- **Tests:** `gfxtier`. The setting round-trips through `save_settings`/`load_settings`; `?gfx=` wins over the saved value; `low_fx` follows the tier.

### MVGN-04 · Backdrop v2

Rebuild `NetBackdrop` as five layers plus haze. It is still drawn with shapes and still deterministic.

| layer | parallax (x / y) | what | redraw |
|---|---|---|---|
| 0 sky | fixed | `sky_far` → `sky_mid` gradient, dithered seams (as today) | on mood change only |
| 1 far skyline | 0.04 / 0.02 | low silhouettes of server halls; a few accent windows | on mood change only |
| 2 towers | 0.12 / 0.05 | today's towers. Fill and edge come from `sky_mid` (darker than the terrain); LEDs use `accent_a` / `accent_b`. | twice a second (blink), as today |
| 3 cable bundles | 0.3 / 0.12 | today's cables, three to five, with running packet dots in `accent_a` | every frame (cheap polylines, as today) |
| 4 near racks | 0.55 / 0.25 | big dark rack silhouettes with rare status lights | on mood change only |

- **Haze:** between layers 1–2 and 3–4, a full-width band in `fog` colour and alpha, slowly drifting (a texture scrolled by position, not redrawn).
- **Light shafts (Ultra):** two or three soft diagonal shafts from ceiling LEDs, additive, alpha 0.05–0.12, slowly breathing.
- **Grading:** grade layers 0–4 by `bg_brightness` and `bg_saturation` (a shared `canvas_item` shader on the backdrop root, or pre-multiplied colours when the mood changes; pick by MVGN-01's numbers).
- **Speed:** obey the CLAUDE.md rule. Static layers are their own nodes, drawn once and moved by position. Run `--test=perfrooms PERF_ROOMS=N` before and after; the CPU ms per NETWORK room must not grow by more than 0.3 ms.
- **Tests:** `netbackdrop2`. Five layers exist; the static ones do not redraw in 300 frames; the mood colours apply. `gfxcontrast` tier 1 passes.

### MVGN-05 · 2D lighting

- **Ambient:** in world-6 rooms a `CanvasModulate` with `Look.ambient` (lit items only, §3.4).
- **Lights:**
  - **Players:** each player (local and the remote puppet) carries a soft warm light, r ≈ 70 px, energy ~0.9, Clawd's colour mixed 30 % with `accent_a`.
  - **Projectiles:** small lights in their own colour, r 24–40, pooled and capped by §3.5.
  - **Static:** terminals, benches, signs' screens and door frames get a fixed light, built once per room from the room data.
  - **Bosses:** eyes and beams (MVGN-13 details).
  - **Fx:** particles with `glow: 1` add a short-lived light only on Ultra, at most 6 at once.
- **Unshaded:** projectiles, hazards, telegraph shapes, catchable strikes, pickups, the `top` layer and every "screen" are unshaded (§3.4).
- **Co-op:** lights are children of their room (fact 8). The partner's light follows its interpolated puppet.
- **Tests:**
  - `lights`: the budget holds in the worst room (N05 with a DDOS swarm) and in each arena.
  - A hidden room has no visible lights.
  - `gfxcontrast` tier 3 passes for both players in all moods.

### MVGN-06 · Normal maps

- **`tools/godot/make-normals.gd`** (run with `--script`, headless; no new dependencies). It builds `w6_tiles_n.png` from `w6_tiles.png`:
  - height = luminance, plus a 2-px bevel on each tile's exposed edges (use the atlas layout of `make_tileset`: 16 columns × 7 rows, row = mask variant);
  - Sobel to a normal; strength 1.5.
- **Sprites:** the same for the NETWORK creature and boss sprites (`assets/sprites/` names used by world-6 classes), and Clawd's captured frames if Clawd is drawn from textures. If Clawd is drawn with rects (`clawd_draw.gd`), skip it; MVGN-14's rim does that job.
- **Wiring:** `RoomView.make_tileset(6)` uses a `CanvasTexture` (diffuse + normal) on High and Ultra.
- **Tests:** `normals`. The files exist and match the diffuse size. A lit tile's left and right halves differ in L when a light is to one side (render test).

### MVGN-07 · Post chain (inside `game_vp`, below the HUD)

In order:
1. **Bloom:** threshold 0.9 on luminance, so only emissives, LEDs, projectiles and lights bloom, never the background; intensity `Look.bloom`. Native glow or custom, per MVGN-01. Half resolution on High.
2. **LUT grade:** one 16³ LUT per mood, generated by `tools/godot/make-luts.gd` from the palette (lift shadows toward `sky_far`, tint mids toward `ambient`, keep highlights neutral so the catchable yellow stays yellow). `Look` cross-fades between two LUTs.
3. **Vignette:** 0.35 at the corners. It never covers the HUD (the HUD is above).
4. **Grain:** amplitude 0.025, 24 fps, from a hash.
5. **Scanlines:** every second row −4 % brightness; off when `reduce_flash` is on and on Low.
6. **CA pulse:** chromatic aberration only as a short pulse driven by `Look.ca_pulse` (MVGN-12, MVGN-15); 0 at rest.

- **Pixel art stays crisp:** bloom adds a soft halo only, and the base picture is never blurred.
- **Tests:**
  - `post`: the HUD's pixels are identical with post on and off.
  - Catchable yellow `#ffd23f` stays within ΔE 6 after grading in every mood.
  - `gfxother` passes (post is off outside world 6).

### MVGN-08 · Transitions and in-room shifts

- **Door transitions:** blend the `Look` over 1.2 s, ease in-out. Respawn, load and fast travel are immediate.
- **N17:** when `ch_t0 ≥ 0` (the chase is running), push `ambient` and `accent_b` toward the siren orange `#FF6B00` with a 1.2 s pulse (±15 %). It is guarded by `reduce_flash` (no pulse then, only the shift). It ends when the chase ends (`ch_fade`).
- **N15:** while `boss.phase == 3`, target the `heat (boss phase 3)` column over 2 s. Back to `heat` when the fight ends.
- **N09 and N22:** phase 3 raises `bloom` by 0.15 and darkens `ambient` by 10 %.
- **Co-op:** all of this is read from the guest's existing snapshot values. The guest's look may lag by its interpolation delay; that is fine.
- **Tests:** `moodshift`.
  - Scripted: start the N17 chase; the look moves within 0.2 s.
  - The FIREWALL at phase 3 gets the phase-3 look; skipping the boss restores `heat`.
  - The guest does the same in `co-firewall`: run it and check its log for the look line, added for tests only.

### MVGN-09 · Foreground silhouettes

- **What:** per room, 2–6 near-camera shapes (hanging cable loops, rack edges, pipe clusters) at parallax 1.3 / 1.1, drawn in `sky_far` darkened by 40 %, alpha 0.9, with a 1-px `accent_a` rim on one side.
- **Placement:** deterministic from the room id. Never inside the 64-px band around any door, bench, terminal or boss trigger. Never lower than 48 px above a floor the player can stand on, so they hang from above or rise from below the screen edge.
- **Fade:** a shape fades to alpha 0.3 while a player's box is behind it (screen overlap).
- **Tests:** `foreground`. Placement rules hold in all 22 rooms; the fade works; tier Low has none.

### MVGN-10 · Ambient particles and animated tiles

- **Particles:**
  - Per mood (§3.2), their own system, not `Fx`, with their own RNG (rule 0), drawn behind `Entities`.
  - Counts: 40 / 100 / 160 for Low / High / Ultra × the tier share.
  - Motes drift with the parallax of layer 3 and are pushed away from a player within 20 px.
  - Embers rise; spores sink; glitch shards blink only when not `reduce_flash`.
- **Animated tiles:**
  - In the w6 atlas, add LED strips and fan grilles as extra tile variants: 4 frames each, with TileSet animation.
  - `RoomView` puts them on some wall faces that touch an empty cell, by hash, ≤ 1 in 12, never on a cell `room.reserved()` uses.
  - Vents (≤ 2 per room) puff steam particles every 3–5 s.
- **Tests:** `ambient`. Counts per tier; `room.rng`'s state is the same with ambient particles on and off after 600 frames (proves rule 0); the parity tapes pass.

### MVGN-11 · Glossy floors (Ultra)

- **Shader:** a `canvas_item` shader drawn as a strip under each floor cap run, 0–12 px below the top edge.
- **What it shows:** the screen texture mirrored around the floor line, faded with depth, blurred by 1 px, alpha `Look.gloss` × 0.5, with a slow ripple (±1 px).
- **Where:** only floors of `Tiles`, not one-way platforms, not liquids.
- **Strips:** built once per room from the grid.
- **Tests:** `gloss`. A bright projectile above the floor brightens the strip under it; Low and High have no strip.

### MVGN-12 · Living backdrop

- **N17 RST wave:** when the chase starts, the towers' LEDs turn `#FF2A2A` in a wave from top to bottom, matching the line's speed. They stay red while it runs, then fade back over 2 s.
- **N12 packet loss:**
  - For each packet whose `lost` turns true: a 150 ms horizontal tear on the backdrop rows behind it (±6 px shifts on 2–4 bands) and a `ca_pulse` of 0.6 × `glitch`.
  - `warn` makes its backdrop LEDs blink magenta.
  - All of it is skipped when `reduce_flash` is on, except the LED colour change.
- **Crawler strands:** the backdrop of N08 and N09 shows web strands between the towers until `boss:CRAWLER`. After that they are broken and hang loose. On the frame the boss dies, they fall: 1.5 s of animation, then the broken state.
- **Calm after FIREWALL:** with `boss:FIREWALL`, `stable` rooms use `stable_clean`. Fewer flickering LEDs, more green dots on the cables.
- **Tests:** `livingbg`. Scripted: the chase wave, a lost packet's tear, the crawler flag's strands, the clean palette after the firewall flag. All are derived from flags and state, so a fresh load with the flag set shows the end state.

### MVGN-13 · Arena lighting

- **N09 WEB CRAWLER:**
  - Ambient drops to 45 % of `lair` during the fight.
  - The crawler's eyes are two small lights.
  - Its "indexing" beam is a cone light that follows the beam (`shadow: true` on Ultra).
  - The web strands catch light: unshaded thin lines, alpha from the distance to the nearest light.
  - The fight must stay readable: the ambient never goes below 35 %, and the strands' knots stay unshaded.
- **N15 THE FIREWALL:**
  - Heat haze: a `canvas_item` distortion shader on the screen region above the deny walls and red bricks, ±1.5 px, 6 Hz noise. High and Ultra; off with `reduce_flash`.
  - Embers from the bricks.
  - The shield gets a rim light.
  - Phase 3 per MVGN-08.
- **N22 THE REVIEWER #2:**
  - Three cold white overhead lights, soft.
  - The unresolved comments glow `#FF4B5C` (unshaded + a small light).
  - The "verdict" moment: `bloom` +0.3 for 0.5 s.
- **Tests:**
  - `arenas`: screenshots of each arena at phase 1 and 3 (via `--scene=`, see MVGN-17). `gfxcontrast` tier 3 passes for the boss and its strikes. The boss's telegraphs are unshaded.
  - `co-crawler`, `co-firewall` and `co-reviewer2` pass.

### MVGN-14 · Rim light and outlines

- **Players:** a 1-px outline in `accent_a` at 60 % on the side away from the camera's centre, plus a 1-px dark (`sky_far`) outer line. Use a shader on the player's node, or draw it in `clawd_draw.gd` if Clawd is drawn with rects. It applies to both players, all tiers.
- **Creatures:** a 1-px dark outline (all tiers) and a rim in the creature's own highlight colour (High and Ultra).
- **The flash shader:** `enemy.gd`'s `flash_mat` and `boss.gd`'s `tint_mat` must keep working. Combine them into one shader with both uniforms; do not stack materials.
- **Tests:** `rim`. The outline pixels exist around Clawd in N05; the hit flash still turns a creature white.

### MVGN-15 · Impact feel

- **Zoom punch:**
  - On a boss phase change and on the final hit, zoom to 1.04 and back over 0.25 s.
  - On a player's death, 1.03.
  - Through `Camera2D.zoom` around the action point; clamp to the room.
  - Not with `reduce_flash` on.
- **CA pulse:** on a boss phase change and on the player taking a hit of 2 or more damage, `ca_pulse` 0.5 for 0.12 s.
- **Flash rules:** `flash_screen` keeps working; its alpha is capped at 0.25 with `reduce_flash` on.
- **Hitstop and shake** stay as they are (`shake_opt` still scales them).
- **Tests:** `feel`. Zoom returns to 1.0 exactly; no zoom when `reduce_flash` is on; co-op guest camera unaffected by the host's zoom (each page zooms on its own events).

### MVGN-16 · Dynamic shadows (Ultra)

- **Occluders:** `LightOccluder2D` polygons from the tile grid. Merge solid runs into rectangles first, then into polygons; built once per room. Cap at 120 polygons per room; above that, use only the walls nearest the arena centre.
- **Who casts:** only lights with `shadow: true` (the crawler's beam, the arena overheads in N22, the shafts' source LEDs). Shadow colour from `sky_far`, alpha 0.6, filter PCF5 if supported (MVGN-01), else none.
- **Tests:** `shadows`. A shadowed area behind a wall is darker than the same spot with the occluder removed; perf: the frame ms delta in N09 is logged.

### MVGN-17 · Tests, screenshots, measurements

- **Contrast:** `gfxcontrast` (§3.7) for all 22 rooms × their mood, plus the arena phase-3 looks. Print one line per room with the three means.
- **Screenshots:** before (from the golden run of MVGN-02, NETWORK rooms included) and after, for N01, N05, N08, N09 (phases 1 and 3), N12 (with a lost packet), N15 (phases 1 and 3), N17 (chase running), N20, N22 (phase 3), on Low, High and Ultra. Save them in `docs/reports/img-gfx-network/` as `<room>_<tier>.png` plus `<room>_before.png`. Add `--scene=` helpers for the boss phases (like `null:<attack>`).
- **Speed:**
  - `perfrooms` for `N*` before and after (CPU, headless).
  - Desktop GPU frame ms under xvfb for N05 and N09 on each tier (`--scene=gfxbench`, 600 frames).
  - The web build in headless Chromium: average FPS for N05 on each tier.
  - All numbers go in the report. They are measurements, not gates, except `perfrooms`' +0.3 ms rule from MVGN-04.
- **Co-op:**
  - The full scenario list, including the 90 s soak on a bad line, must pass. No new watchdog rule is expected; if one is needed, the cosmetic rule was broken somewhere, so fix that instead.
  - `parity` passes unchanged.
- **Other worlds:** `gfxother` passes.
- **Build:** `bash tools/godot/test-all.sh` → `ALL PASS`. Then `export-web.sh` into `public/mv` as the last commit.

### MVGN-18 · Report and stop

`docs/reports/metroidvania-gfx-network.md`, in **Persian**, short and plain, for Zakaria:
- what was built, with before/after pictures;
- the probe table (what works in the web build);
- the numbers per tier;
- every value tuned away from §3.2 and why;
- anything left out, and why.

**Playtest steps** (also in the report):
1. Run `update.bat` once this is in `main` (ask Zakaria before merging).
2. PC: open `/mv/?debug`, Graphics = Ultra. Walk N01 → N05 → N08 → N09 and fight the crawler; then N12, N17 (the chase), N13 → N15 and fight the firewall; then N22. Copy the LOG.
3. Phone (Y9s, Firefox): open the same page as the guest, Graphics = High. Note the FPS line in N05 and in a boss fight; switch to Low and Ultra once each and note the FPS again. Send the LOG.
4. Say what looks best, what is too dark or too busy, and where anything was hard to read.

Fill the status table, push, and **stop**. Optimisation for the phone is a separate plan, written after Zakaria's numbers come back.
