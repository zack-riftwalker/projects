# CLAWD Metroidvania — Phase 1 Plan (for the executing agent)

> **خلاصه برای زکریا:** این پلن برای Sonnet نوشته شده و برای دقت انگلیسیه. همه‌ی تصمیم‌ها از قبل گرفته شدن و Sonnet فقط اجرا می‌کنه.
>
> **فاز ۱ چیه:** پایه‌ی نسخه‌ی Godot. خروجیش یه اتاق قابل بازی‌ه، یعنی مرحله‌ی اول بازی فعلی (`hello_world.py`) با حرکت دقیقاً مثل الان، dash، Bug و Typo، دکمه‌های لمسی و صدا. این نسخه روی گوشی تست می‌شه.
>
> **یه چیز مهم که قبل از نوشتن پلن تست کردم:** Godot وقتی صفحه با `http` باز بشه (مثل آدرس PC تو که رفیقت باهاش وصل می‌شه)، صدا رو نمی‌تونه راه بندازه و کرش می‌کنه. راه حلش رو پیدا کردم و تست کردم: بازی اجرا شد و صدا هم پخش شد. پس نسخه‌ی Godot هم از همون `start.bat` و همون آدرس بازی می‌شه.
>
> **تو چیکار می‌کنی (آخر فاز):** Sonnet یه پیام فارسی با قدم‌ها برات می‌فرسته. خلاصه‌ش: تو پوشه‌ی بازی یه فایل `update-branch.txt` می‌سازی که توش نوشته `ph1`، بعد `update.bat` رو می‌زنی، بعد با گوشی آدرس `http://<آدرس PC>:3000/mv/?debug` رو باز می‌کنی و ۱۰ دقیقه بازی می‌کنی و از اعداد اسکرین‌شات می‌گیری. بازی فعلی‌تون (آدرس بدون `/mv/`) دست نمی‌خوره. برای برگشتن به آپدیت‌های عادی، فایل `update-branch.txt` رو پاک کن و دوباره `update.bat` رو بزن.
>
> **چطوری بدی به Sonnet:** یه جلسه‌ی جدید با مدل Sonnet روی برنچ `ph1` باز کن و بنویس:
> «فایل `docs/PLAN-metroidvania-phase1.md` رو بخون و فاز ۱ رو اجرا کن.»

---

## 0. Rules of engagement (read first, follow exactly)

- **Read, in this order, before any work:** `CLAUDE.md`, this file (all of it), `docs/metroidvania/00-decisions.md` (especially §11, the final decisions), `docs/metroidvania/01-current-game.md`.
- **Do not redesign.** Every decision is already made in this file. When this file gives a value, a name, a path or a code block, use it as written. If something here is impossible (a command fails, an API does not exist in Godot 4.7.2), do the smallest change that keeps the stated goal and write it down under "deviations" in the phase report. Never silently pick a different approach.
- **Branch:** `ph1` only. Before starting, run `git fetch origin main ph1 && git checkout ph1 && git merge --no-edit origin/main` (keeps the current game identical to `main`), then push. Push with `git push -u origin ph1`. **Never push to `main`, never merge into `main`, never open a PR.**
- **Files you may change:** everything under `godot/`, `tools/godot/`, `docs/metroidvania/`, `docs/reports/metroidvania-phase1.md`, this plan's status table; plus exactly these existing files, only as described in MV1-02: `server.js`, `tools/coop-harness.js` (one line), `.gitattributes`. **Never touch** `public/index.html`, `public/assets/`, `cloud/`, any `.bat`/`.ps1`, `package*.json`, `wrangler.jsonc`, `CLAUDE.md`. `public/mv/` is written only by `tools/godot/export-web.sh` and committed only in MV1-09.
- **One commit per task**, message `MV1-xx: <what>`, ending with the attribution lines your session gives you. Push after every commit. A task is done only when its "Acceptance" commands pass; paste their output into the commit message body (short) or the phase report.
- **Before every push that touches `server.js` or `tools/coop-harness.js`:** run `node tools/coop-harness.js smoke cache paths mv-serve` and the co-op quick set `node tools/coop-harness.js fight-hits revive soak` (with `SOAK_S=20`). All must pass.
- **Language:** code, comments and this plan are English. Anything Zakaria reads (the phase report, the final chat message, signs he sees in game) is Persian, short and plain, technical names in English.
- **Process rules from `CLAUDE.md`:** kill only processes you started (never `pkill -f "node server.js"`, never `pkill -f` with a pattern that matches your own shell; kill by PID). Use the scratchpad for temporary files.
- **Godot naming trap (this already bit phase 0):** never name your own method or variable after a built-in Object/Node/CanvasItem member. Forbidden as your own names: `set`, `get`, `_set`, `_get`, `name`, `owner`, `position`, `scale`, `rotation`, `visible`, `show`, `hide`, `free`, `queue_free`, `call`, `connect`, `emit`, `notification`, `draw` (use `draw_body`), `process`, `size`, `tr`. JS → GDScript renames you must use: `set(st, t)` → `set_state(st, t)`, `this.name` → `boss_name`, `L` → `room`, `g.fillRect` → `draw_rect(Rect2(...), color)`.
- **Stop at the end of phase 1** (after MV1-09) and report to Zakaria in Persian. Do not start phase 2.

---

## 1. Status

| task | what | owner | status |
|---|---|---|---|
| MV1-01 | export templates, Godot project skeleton, web export pipeline | Sonnet | todo |
| MV1-02 | the PC relay serves the Godot build at `/mv/` | Sonnet | todo |
| MV1-03 | capture art, font, sound effects and music from the current game | Sonnet | todo |
| MV1-04 | input, tile collision, room loading, tile rendering | Sonnet | todo |
| MV1-05 | the player (exact port), Clawd drawing, camera, hitstop, particles | Sonnet | todo |
| MV1-06 | Bug, Typo, combat, items, checkpoint, signs, HUD, sound | Sonnet | todo |
| MV1-07 | touch controls, pause, debug overlay for the phone test | Sonnet | todo |
| MV1-08 | automated tests: parity with the JS game, headless run, web check | Sonnet | todo |
| MV1-09 | delivery build, phone test instructions, phase report | Sonnet | todo |

Order: strictly MV1-01 → MV1-09. Update this table and `docs/metroidvania/README.md` in the same commit as each task.

---

## 2. Facts already verified (do not rediscover)

All of these were run in this kind of container on 2026-10-09.

| fact | detail |
|---|---|
| Godot install | `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)` installs 4.7.2 into `~/.cache/clawd-godot/4.7.2/` (phase 0 tool). Zip SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`. |
| Export templates | `https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz&platform=templates` is a 1,281,349,702-byte zip. It contains `templates/web_nothreads_release.zip` (10.2 MB), `templates/web_nothreads_debug.zip`, `templates/version.txt` (`4.7.2.stable`). Godot looks for them in `~/.local/share/godot/export_templates/4.7.2.stable/`. Only those three files are needed. |
| Headless web export | `"$GODOT" --headless --path <project> --export-release "Web" <out>/index.html` works in ~8 s. The preset must contain `include_filter=""` and `exclude_filter=""` or Godot prints two harmless errors. Output: `index.html`, `index.js` (280 KB), `index.wasm` (39.5 MB, ~10 MB gzipped), `index.pck`, `index.audio.worklet.js`, `index.audio.position.worklet.js`, `index.png`, `index.icon.png`, `index.apple-touch-icon.png`. |
| Secure context | Godot 4.7.2's page refuses to start on a non-secure origin (plain `http://` on a LAN or public IP): `Engine.getMissingFeatures()` reports "Secure Context" even for single-threaded builds. `localhost` is secure. |
| Audio on plain http | `AudioContext.audioWorklet` does not exist on non-secure pages; Godot's audio init calls `ctx.audioWorklet.addModule(...)` unconditionally and crashes ("Cannot read properties of undefined (reading 'addModule')"). **Fix, verified in Chromium:** (1) give `AudioContext.prototype` a stub `audioWorklet` with `addModule: () => Promise.resolve()` only when `!window.isSecureContext`; (2) start the engine with `--audio-driver ScriptProcessor`; (3) set the project setting `audio/general/default_playback_type.web=0` (Stream; the Sample type needs a real worklet); (4) drop "Secure Context" from the missing-features list. With these, a 440 Hz test tone came out of the ScriptProcessor (peak 0.366) on `http://192.0.2.2`. On secure pages nothing changes (the normal AudioWorklet driver runs). |
| Page URL | `JavaScriptBridge.eval("location.search")` returns e.g. `?debug&fps30` in the web build. `DisplayServer.screen_get_scale()` gives the device pixel ratio. |
| JS game as reference | Load `file:///home/user/projects/public/index.html?mute&manual` in Playwright (`require('/opt/node-tools/node_modules/playwright')`, `executablePath: '/opt/pw-browsers/chromium'`). Mark levels seen: `for (const k of Object.keys(G.LEVELS)) G.save.data.seen['b' + k] = true`. Start a level: `G.go(() => G.Scenes.play('1-1', null))`, then call `G.step(1, true)` until `G.scene.L && !G.transitioning()`. Drive input with `G.input.script = { right: true, jump: true }` (any of `left right up down jump attack dash special pause start`), advance with `G.step(1, true)`, read `G.scene.L.player.x/.y/.vx/.vy/.onGround`. `G.LEVELS` is an object, not an array. |
| Reference trace | In level 1-1 the player settles at x 35, y 198. Holding right for 60 frames and jump on frames 10–39 gives x 151.608 at frame 89 and a minimum y of 140.596. |
| Offline audio | `G.audio.renderOffline('sfx:jump', 1.2)` and `G.audio.renderOffline('w1', 47.27)` render through an `OfflineAudioContext`. Patching `OfflineAudioContext.prototype.startRendering` in `page.addInitScript` to keep the returned `AudioBuffer` in `window.__lastBuf` gives the samples; encode as 16-bit WAV in the page, return base64, and `ffmpeg -c:a libvorbis -q:a 4` makes the OGG (`/usr/bin/ffmpeg` has libvorbis). Song length: after one render `G.SONGS[name]._c[section].bars` exists; one pass = Σ bars over `song.order` × 16 steps × `60 / bpm / 4` s; the loop restarts at `song.order[song.loop || 0]`. Example: `w1` = 132 bpm, order I A A B, bars 2 8 8 8 → 47.273 s, loop start 3.636 s. |
| Updater | `tools/update.ps1` follows the branch named in an optional `update-branch.txt` in the game folder (kept across updates). That is how Zakaria gets `ph1` without anything reaching `main`. |
| Current game on phones | It runs logic at 60 Hz but draws at most 30 frames per second on phones (`G.mobile` in `// js/main.js`). |

---

## 3. Architecture (fixed; do not change)

### 3.1 Folder layout
```
godot/                      the Godot project (res://)
  project.godot
  export_presets.cfg
  .gitignore                .godot/  *.translation  build.txt
  web/shell.html            custom HTML shell (MV1-01)
  src/
    main.tscn, main.gd      root: viewport, screen fitting, touch layer, overlays
    autoload/game.gd        Game: constants, flags, current settings
    autoload/controls.gd    Controls: input actions, touch state, poll() → down/pressed/released
    autoload/audio.gd       Audio: sfx(name, vol), music(name), stop_music()
    core/tile_grid.gd       TileGrid: tiles + collision (port of the Level tile functions)
    core/fx.gd              Fx: particles, rings, pops, shake, flash (drawn with _draw)
    core/pixel_text.gd      PixelText: draws the captured bitmap font
    world/room.gd           Room: loads a room file, owns entities, steps the simulation
    world/room_view.gd      draws tiles (TileMapLayer), decor, background
    world/rooms.json        room metadata
    world/rooms/R01.txt     room maps (ASCII, same letters as the current game)
    player/player.gd        Player (exact port of class Player)
    player/clawd_draw.gd    port of G.drawClawd (rectangles, squash and stretch)
    enemies/enemy.gd        Enemy base (port of class Enemy)
    enemies/bug.gd, enemies/typo.gd
    ui/hud.gd, ui/touch_controls.gd, ui/pause.gd, ui/debug_overlay.gd
    test/run_tests.gd       headless test entry (MV1-08)
  assets/
    sprites/*.png  tiles/*.png  fonts/*.png + *.json  bg/*.png  sfx/*.wav  music/*.ogg
tools/godot/
  setup-godot.sh (exists)  smoke.sh (exists)  setup-templates.sh  export-web.sh
  capture/capture.js        Playwright capture of art, font, sound, music, levels
  parity/tapes/*.json  parity/js-trace.js  parity/compare.py
  web-check.js  test-all.sh
public/mv/                  the exported web build (generated; committed only in MV1-09)
```

### 3.2 Simulation rules
- **Coordinates are the current game's**: pixels, origin top-left of the room, tile 16 px, entity `x, y` = top-left of its hitbox, `w, h` = hitbox size. Screen 384 × 216.
- **Fixed step 1/60 s.** `Room._physics_process(delta)` calls `Controls.poll()` then `room.step(1.0/60.0)` once. Physics ticks 60, max 4 steps per frame (project settings below). Never use `delta` from `_process` for game logic.
- **No Godot physics.** Collision is the current game's tile AABB code, ported to `TileGrid`. No `CharacterBody2D`, no `Area2D`, no collision shapes.
- **Update order inside `Room.step(dt)`** = the JS `Level.update` order: hitstop check (if `hitstop > 0`: `hitstop -= dt`, return) → `time += dt` → break queue → player update → entities update (in list order) → combat (`interact_combat`) → items → projectiles → camera → fx. Read `Level.update` in `// js/level.js` and keep its order for the parts that exist.
- **Floats are GDScript `float` (64-bit)**, the same as JS numbers. Port expressions in the same order so results match bit for bit; `Math.floor(v)` → `floori(v)`, `Math.round(v)` → JS rounds .5 up: use `floori(v + 0.5)`; `Math.sign` → `signf`, `Math.hypot` → `sqrt(a*a+b*b)`, `G.approach` → a local `approach()` with the same code, `G.damp(a, b, rate, dt)` = `lerp(a, b, 1.0 - exp(-rate * dt))`, `G.clamp` → `clampf`.
- **Randomness:** `Math.random()` / `G.rand(a, b)` → `randf()` / `randf_range(a, b)` from a `RandomNumberGenerator` owned by the room (seeded with 1 in tests). `G.hash(a, b, c)` must be ported exactly (read it in `// js/core.js`) because enemy start directions and tile variety use it.

### 3.3 Rendering rules
- `main.tscn`: `Main` (Control, full rect) → children in this order:
  1. `GameViewport` (SubViewport, size 384×216, `render_target_update_mode = UPDATE_ALWAYS`, `canvas_item_default_texture_filter = NEAREST`, `snap_2d_transforms_to_pixel = true`, `snap_2d_vertices_to_pixel = true`, `transparent_bg = false`). Its child `World` (Node2D) holds the room view, entities, player, fx and a `Camera2D` (`anchor_mode = ANCHOR_MODE_FIXED_TOP_LEFT`, smoothing off). A `CanvasLayer` inside the SubViewport holds the HUD, pause menu and signs (pixel art at 384×216).
  2. `Screen` (TextureRect): `texture = $GameViewport.get_texture()` (set in code), `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`, `texture_filter = TEXTURE_FILTER_NEAREST`.
  3. `Touch` (Control, full rect, `touch_controls.gd`), hidden until the first touch.
  4. `Debug` (Control, full rect, `debug_overlay.gd`), visible only with `?debug`.
- Screen fitting (in `main.gd`, on `size_changed`): landscape (`width >= height`) → `Screen` fills the window. Portrait → `Screen` is anchored to the top, full width, height = `width * 216 / 384`, top margin 10 px × device scale (same as the current CSS `padding-top: 10px`). The touch layer always covers the whole window.
- Sprites captured from the current game are drawn exactly like `G.spr`: bottom-centre anchor, i.e. top-left at `(round(x - w/2), round(y - h))` where `(x, y)` = `(entity.x + entity.w/2, entity.y + entity.h + 1 + oy)`. Use `Sprite2D` with `centered = false`, `offset = Vector2(-floor(w/2.0), -h)`, `flip_h` for `flip`. For a squash (`sx`, `sy`) set the Sprite2D `scale` (negative x for flip is not needed; use `flip_h`).
- White hit flash (`G.tint(img, '#ffffff')` while `flash > 0`): one shared `ShaderMaterial` on enemy sprites:
  ```glsl
  shader_type canvas_item;
  uniform float flash = 0.0;
  void fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a); }
  ```
  Set `flash = 1.0` while the entity's `flash > 0`, else `0.0` (use `material.set_shader_parameter`; give every sprite its own material copy with `material.duplicate()` or use instance uniforms).
- Lighting (`G.light`) and the screen-space glow are **not** ported in phase 1 (phase 6).

### 3.4 Exact config files

`godot/project.godot` (write exactly this, then add `[autoload]` entries as tasks create them):
```ini
; Engine configuration file.
config_version=5

[application]
config/name="CLAWD"
run/main_scene="res://src/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[autoload]
Game="*res://src/autoload/game.gd"
Controls="*res://src/autoload/controls.gd"
Audio="*res://src/autoload/audio.gd"

[audio]
general/default_playback_type.web=0

[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/stretch/mode="disabled"
window/energy_saving/keep_screen_on=true

[input_devices]
pointing/emulate_touch_from_mouse=false
pointing/emulate_mouse_from_touch=false

[physics]
common/physics_ticks_per_second=60
common/max_physics_steps_per_frame=4
common/physics_jitter_fix=0.0

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
environment/defaults/default_clear_color=Color(0.0509804, 0.0392157, 0.0705882, 1)
```

`godot/export_presets.cfg`:
```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.txt"
exclude_filter="src/test/*"
export_path="../public/mv/index.html"

[preset.0.options]

variant/thread_support=false
html/custom_html_shell="res://web/shell.html"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
```
(`include_filter` makes Godot pack the room `.txt` files and `rooms.json`, which are not imported resources.)

---

## MV1-01 · Templates, project skeleton, web export

**Goal:** one command turns `godot/` into a working web build in `public/mv/`, served gzipped.

**Steps:**
1. `tools/godot/setup-templates.sh` (bash, `set -euo pipefail`):
   - Target dir `T=$HOME/.local/share/godot/export_templates/4.7.2.stable`.
   - If `$T/web_nothreads_release.zip`, `$T/web_nothreads_debug.zip` and `$T/version.txt` all exist → print `templates ok` to stderr and exit 0.
   - Else download the tpz (URL in §2) with `curl -fSL --retry 3` into `mktemp -d`, then `unzip -o -j -q tpz templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt -d "$T"`, delete the temp dir (trap), verify `cat $T/version.txt` is `4.7.2.stable`.
2. Create `godot/project.godot` and `godot/export_presets.cfg` exactly as in §3.4, `godot/.gitignore` (`.godot/`, `*.translation`, `build.txt`), and placeholder scripts so the project runs: `src/main.tscn` + `src/main.gd` (prints `CLAWD: ready` in `_ready`), the three autoloads as empty `extends Node` scripts.
3. `godot/web/shell.html`: extract the default shell with `unzip -p $T/web_nothreads_release.zip godot.html > godot/web/shell.html`, then make exactly these three edits (search for the quoted line, it is unique):
   - Directly before the line `<script src="$GODOT_URL"></script>` insert:
     ```html
     <script>
     // Plain http on a LAN or public IP (how the friend joins the PC) is not a "secure context":
     // browsers hide AudioWorklet there and Godot refuses to start. Use the ScriptProcessor audio driver instead
     // and give Godot a do-nothing addModule for its sample-position worklet. Verified 2026-10-09 (Chromium).
     if (!window.isSecureContext && window.AudioContext && !('audioWorklet' in AudioContext.prototype)) {
     	Object.defineProperty(AudioContext.prototype, 'audioWorklet', { get() { return { addModule: () => Promise.resolve() }; } });
     	window.CLAWD_INSECURE = true;
     }
     </script>
     ```
   - Replace `const engine = new Engine(GODOT_CONFIG);` with:
     ```js
     if (window.CLAWD_INSECURE) GODOT_CONFIG['args'] = (GODOT_CONFIG['args'] || []).concat(['--audio-driver', 'ScriptProcessor']);
     const engine = new Engine(GODOT_CONFIG);
     ```
   - Directly before the line `	if (missing.length !== 0) {` insert:
     ```js
     	if (window.CLAWD_INSECURE) missing.splice(0, missing.length, ...missing.filter((m) => !m.startsWith('Secure Context')));
     ```
   - Page background = the game's night colour: the first `background-color: black;` (in the `html, body` rule) → `background-color: #0d0a12;`. Leave `$GODOT_PROJECT_NAME`, `$GODOT_URL`, `$GODOT_CONFIG` and the other `$GODOT_...` placeholders as they are; Godot fills them in at export.
   All four anchors were checked in the 4.7.2 template (`$GODOT_URL` line 110, `new Engine` line 114, `missing.length` line 167, `black` line 16).
4. `tools/godot/export-web.sh` (bash, `set -euo pipefail`):
   - `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`; `bash tools/godot/setup-templates.sh`.
   - `rm -rf public/mv && mkdir -p public/mv`.
   - Write `godot/build.txt`: one line `<branch> <git short sha> <UTC date YYYY-MM-DD HH:MM>` (the debug overlay shows it; `build.txt` is in `godot/.gitignore`).
   - `"$GODOT" --headless --path godot --import` (imports new assets; ignore its exit code only if the next step succeeds), then `"$GODOT" --headless --path godot --export-release "Web" ../public/mv/index.html`.
   - Fail if `public/mv/index.html`, `index.js`, `index.wasm`, `index.pck` are missing.
   - For every file in `public/mv/` larger than 256 KiB (wasm, pck, js): `gzip -9 -n -f <file>` (creates `<file>.gz`, removes the original).
   - Copy `godot/build.txt` to `public/mv/build.txt`.
   - Print every file with its size.
5. Run it.

**Acceptance:**
- `bash tools/godot/export-web.sh` exits 0 and lists `index.html`, `index.js.gz`, `index.wasm.gz` (≈10 MB), `index.pck` or `index.pck.gz`, `build.txt`.
- `git status` shows `public/mv/` as untracked or ignored, **not staged**. Do not commit `public/mv/` in this task (add nothing to `.gitignore` for it either; MV1-09 commits it once).

---

## MV1-02 · The PC relay serves the Godot build

**Goal:** `http://<pc>:3000/mv/` serves the build; big files go out gzipped; nothing else changes for the current game.

**Steps:**
1. `server.js` — make exactly these changes (keep the file's compact style; comments explain why):
   - `MIME`: add `'.wasm': 'application/wasm', '.pck': 'application/octet-stream'`.
   - Next to `const VOICE = ...` add:
     ```js
     const MV = /^\/mv\/[a-z0-9_-]+(\.[a-z0-9]+)+$/;     // the Godot build (Metroidvania test): one flat folder, no sub-paths, no dot-files
     ```
   - In the request handler, after `if (u === '/') u = '/index.html';` add `if (u === '/mv' || u === '/mv/') u = '/mv/index.html';` and change the 404 test to `if (u !== '/index.html' && !VOICE.test(u) && !MV.test(u)) { ... }`.
   - In `serveFile`, big Godot files exist only as `<name>.gz` (export-web.sh). Replace its first two lines with:
     ```js
     let ent = load(rel), pre = false;
     if (!ent && rel.startsWith('mv/')) { ent = load(rel + '.gz'); pre = !!ent; }     // stored gzipped by tools/godot/export-web.sh
     if (!ent) { res.writeHead(404); return res.end('not found'); }
     ```
     and before `if (ent.gz) {` insert:
     ```js
     if (pre) {               // already gzip: send as is when the browser takes gzip (all do), unpack once otherwise
       h.Vary = 'Accept-Encoding';
       if (/\bgzip\b/.test(req.headers['accept-encoding'] || '')) h['Content-Encoding'] = 'gzip'; else body = ent.plain || (ent.plain = zlib.gunzipSync(ent.raw));
     } else
     ```
     so the existing `if (ent.gz) { ... }` becomes the `else` branch. `Content-Type` keeps using `path.extname(rel)` (the name without `.gz`).
2. `.gitattributes`: add lines `*.gz binary`, `*.wasm binary`, `*.pck binary`, `*.ogg binary`, `*.wav binary`, `*.ttf binary`.
3. New file `tools/scenarios-mv.js` (same shape as `tools/scenarios-controls.js`), one scenario `S['mv-serve']`:
   - If `public/mv/index.html` does not exist → `return R(true, 'skipped: no Godot build in public/mv')`.
   - Start a server with `startServer()`. Check with plain `http.get` (look at how `S['paths']` in `tools/coop-harness.js` does requests):
     - `/mv/` → 200, `content-type` starts with `text/html`.
     - `/mv/index.wasm` with `accept-encoding: gzip` → 200, `content-encoding: gzip`, `content-type: application/wasm`.
     - `/mv/index.wasm` without accept-encoding → 200, body starts with bytes `00 61 73 6d`.
     - `/mv/../server.js`, `/mv/sub/x.js`, `/mv/.hidden` → 404.
     - `/` still 200 and identical in size to before the change (compare with `fs.statSync('public/index.html').size` after decompression).
   - Open `http://127.0.0.1:<port>/mv/?selftest` in Chromium; wait (≤ 40 s) for a console line `CLAWD: selftest PASS` (MV1-08 implements it; until then accept `CLAWD: ready`). Page errors → fail.
4. `tools/coop-harness.js`: add `'scenarios-mv.js'` to the file list on the line that starts with `for (const f of ['scenarios-p1.js'`. Nothing else.

**Acceptance:** `node tools/coop-harness.js mv-serve smoke cache paths` → all PASS (with the build from MV1-01 present). Then the co-op quick set from §0. Commit `server.js`, `.gitattributes`, `tools/scenarios-mv.js`, the harness line.

---

## MV1-03 · Capture art, font, sound and music from the current game

**Goal:** the Godot project uses the current game's real pixels and sounds, produced by a script anyone can re-run.

**`tools/godot/capture/capture.js`** (Node + Playwright, see §2 for how to load the game). Usage: `node tools/godot/capture/capture.js <what...>` where what ∈ `sprites tiles font bg sfx music levels all`. Output goes to `tools/godot/capture/out/` (add `tools/godot/capture/out/` to `tools/godot/.gitignore`), then the script copies the files listed below into `godot/assets/`.

1. **sprites** — walk `G.SPR` recursively in the page. Every `HTMLCanvasElement` leaf becomes `sprites/<path>.png`, path = keys joined with `_` (e.g. `G.SPR.bug[0]` → `bug_0.png`, `G.SPR.slash.f[2]` → `slash_f_2.png`, `G.SPR.pip` → `pip.png`). Get bytes with `canvas.toDataURL('image/png')`. Also write `sprites/index.json` = `{ "<file>": [w, h] }`. Copy all of them to `godot/assets/sprites/`.
2. **tiles** — one atlas `tiles/w1_tiles.png`, 16 × 7 cells of 16 px (256 × 112), drawn in the page with the world-art functions for world 1:
   - rows 0–3, column `m` (0–15), row `v`: `G.drawSolid(g, 1, m*16, v*16, 3 + v*5, 7 + v*3, { u: !!(m&1), d: !!(m&2), l: !!(m&4), r: !!(m&8) })`. `m` bit set = that neighbour is solid.
   - row 4, column `c` (0–7): `G.drawOneway(g, 1, c*16, 64, c >> 2, { l: !!(c&1), r: !!(c&2) })` (columns 0–3: even tile, 4–7: odd tile, which changes the little notch).
   - row 5: col 0 `G.drawSpikes(g, 0, 80, false)`, col 1 `G.drawSpikes(g, 16, 80, true)`, col 2 `G.SPR.cracked`, col 3 `G.SPR.crumble`.
   - row 6, column `i` (0–15): `G.drawDecor(g, 1, i*16, 96, i, 40)` (many are empty; that is fine).
   Read `G.drawSolid` first to confirm the meaning of `u d l r` (neighbour is solid → no edge on that side). Copy to `godot/assets/tiles/`.
3. **font** — two atlases from `G.text`: `fonts/big.png` + `fonts/big.json` and `fonts/tiny.png` + `fonts/tiny.json` (tiny = `{ tiny: true }`). For each character code 32–126: `w = G.textW(ch, o)`; draw `G.text(g, ch, x, 0, '#ffffff', o)` left to right with 1 px gaps; record `{ "<ch>": [x, w] }` and the height `h` = last non-transparent row + 1 over the whole strip. JSON = `{ "h": h, "sp": 1, "glyphs": { ... } }`. Copy to `godot/assets/fonts/`.
4. **bg** — `bg/w1.png` 384 × 216: `G.drawBG(1, g, 0, 0, 0, false)` on a 384×216 canvas (read `G.drawBG` in `// js/world_art.js`; if it needs a different argument list, follow its code and note it). Copy to `godot/assets/bg/`.
5. **sfx** — for each name in this list render `G.audio.renderOffline('sfx:' + name, 1.2)` (use 2.5 s for `explode`, `bigExplode`, `roar`, `logo`, `die`, `gate`, `spark`), take `window.__lastBuf`, trim trailing samples below 1/1000 of full scale (keep 50 ms after the last loud sample), encode as **mono** 16-bit 44.1 kHz WAV (average the two channels) → `sfx/<name>.wav`:
   `jump djump walljump land swipe swipeBig hit clang squish kill hurt die token spark heal dash spring crumble brk checkpoint shoot bossHit explode bigExplode uiMove uiOk uiBack text textLow textSys key gate agent agentHit warn charge laser drip splash thud roar glitch tick tock pause flap logo stamp`
   Copy all to `godot/assets/sfx/`.
6. **music** — for each song in `G.SONGS`: first `await G.audio.renderOffline(name, 1)` (this compiles it), then compute the pass length from `_c` (§2), then render `passLength` seconds (+ 3 s if `song.once`). Encode stereo WAV → `ffmpeg -y -i x.wav -c:a libvorbis -q:a 4 music/<name>.ogg`. Write `music/index.json` = `{ "<name>": { "len": s, "loop_start": s, "once": bool } }`. Songs that contain events with `hi` set (look at `_c[...].ev`) are also rendered with `G.audio.intensity = 1` as `<name>_hi.ogg`. **Copy only `w1.ogg` into `godot/assets/music/` in this phase** (the others stay in `out/` until a phase needs them; they are re-creatable).
7. **levels** — write `levels/<id>.txt` for every level (rows joined with `\n`, right-padded with spaces to the level width) and `levels/index.json` with `{ id, name, world, boss, w, h, signs }`. Not copied into Godot; MV1-04 uses `1-1`.
8. Also write `tools/godot/capture/README.md` (Persian, 10 lines: what each target makes, how to re-run).

**Acceptance:** `node tools/godot/capture/capture.js all` exits 0; `godot/assets/sprites` has > 60 PNGs including `bug_0.png`, `typo_0.png`, `pip.png`, `pipOff.png`, `token_0.png`, `checkpoint_0.png`, `checkpoint_1.png`, `sign.png`, `slash_f_0.png`; `godot/assets/tiles/w1_tiles.png` is 256×112; `godot/assets/sfx/` has 48 WAVs; `godot/assets/music/w1.ogg` exists and `index.json` says `len` ≈ 47.27, `loop_start` ≈ 3.636. Open three PNGs with the Read tool and look at them. Commit the script, the README and `godot/assets/` (not `out/`).

---

## MV1-04 · Input, tile collision, room loading, tile rendering

**Goal:** room R01 (level 1-1) loads in Godot with the right tiles on screen, and the collision functions behave exactly like the JS ones.

**Steps:**
1. **`controls.gd` (autoload `Controls`).**
   - Actions (in this order): `left right up down jump attack dash special pause start`. Create them in `_ready()` with `InputMap.add_action` (skip if present) and these events:
     - keys (use `physical_keycode`): left `Left`,`A`; right `Right`,`D`; up `Up`,`W`; down `Down`,`S`; jump `Z`,`Space`; attack `X`,`J`; dash `C`,`Shift`; special `V`,`E`; pause `Escape`,`P`; start `Enter`.
     - joypad buttons: jump `JOY_BUTTON_A`; attack `JOY_BUTTON_X`; dash `JOY_BUTTON_B`, `JOY_BUTTON_RIGHT_SHOULDER`; special `JOY_BUTTON_Y`, `JOY_BUTTON_LEFT_SHOULDER`; pause `JOY_BUTTON_BACK`; start `JOY_BUTTON_START`; d-pad to the four directions; left stick axes to the four directions (deadzone 0.4).
   - State: `var down := {}`, `var pressed := {}`, `var released := {}`, `var touch := {}` (set by the touch layer), `var tq := {}` (touch presses not yet seen), `var script_input = null` (Dictionary used by tests and tapes), `var locked := false`, private `_prev := {}`.
   - `func poll() -> void`: exact port of `input.poll` in `// js/core.js`: for each action `state = Input.is_action_pressed(a) or script_input.get(a) or touch.get(a) or tq.get(a)`; then `d = state and not locked`; `pressed[a] = d and not _prev.get(a, false)`; `released[a] = (not d) and _prev.get(a, false)`; `down[a] = d`; `_prev[a] = d`; finally clear `tq`. When `script_input != null` ignore the keyboard/joypad/touch entirely (tests must be deterministic).
2. **`tile_grid.gd` (`class_name TileGrid extends RefCounted`).** Constants `E=0 SOLID=1 ONEWAY=2 SPIKE_U=3 SPIKE_D=4 CRACK=5 CRUMBLE=6 BLINK_A=7 BLINK_B=8 LIQ=9` and the char map `{'#':SOLID,'=':ONEWAY,'^':SPIKE_U,'v':SPIKE_D,'%':CRACK,'~':CRUMBLE,'1':BLINK_A,'2':BLINK_B,'w':LIQ}`. Fields `w, h, tiles: PackedByteArray, crumble := {}, blink_hold := {}, blink_phase := 0`. Port these `Level` methods from `// js/level.js` line by line, same names in snake_case: `tile`, `solid`, `solid_at`, `box_hits_solid`, `move_x`, `move_y`, `grounded`, `plat_under` (takes the room's platform list), `break_tile` (returns bool; the room does the burst/shake/sound and the break queue), `find_safe`. `move_x`/`move_y` take the entity object (anything with `x y w h` properties) and change its `x`/`y` exactly like the JS. Keep the `- 0.001` and `+ 0.01` epsilons. Outside the grid: left/right/top = SOLID, below the bottom = E (exactly as `tile()` in JS; phase 2 adds doors).
3. **Room files.** `godot/world/rooms/R01.txt` = `tools/godot/capture/out/levels/1-1.txt` with exactly these edits (x = column, y = row, 0-based): `(198,12)` `E`→space (no exit in a metroidvania), `(168,10)` `f`→space (Flaky is not ported). `godot/world/rooms.json`:
   ```json
   { "R01": { "file": "R01.txt", "title": "hello_world.py", "world": 1, "music": "w1", "origin": [0, 0],
              "signs": ["MOVE with the [move] and JUMP with [jump] - hold it to go higher.",
                        "Bugs. Swipe them with [attack] - or simply land on them.",
                        "Between two walls? Jump at one, then jump again. Clawd has grippy legs.",
                        "Land on an enemy, or hold [down] and swipe in mid-air, to bounce off it."],
              "doors": [] } }
   ```
   Sign texts are numbered in reading order of the `T` letters (row by row, left to right), exactly like `signN++` in the JS constructor. `[move]` etc. are replaced at display time with the key names (keyboard) or the button names (touch: `JUMP`, `CLAW`, `DASH`, `SPECIAL`).
4. **`room.gd` (`class_name Room extends Node2D`).** `load_room(id: String)`: read `rooms.json` and the `.txt` with `FileAccess`; build the `TileGrid` (row count = h, width = longest row); scan letters exactly like the JS `Level` constructor: `P` start (`x+3, y+6`), `C` checkpoint (`x+8, y+16`), `T` sign (`x+8, y+16`), `o` token item (`x+8, y+8`, id = running item counter), `*` spark item (sorted, max 3, like the JS), `H` coffee, `S` spring (`x+2, y+9, 12×7`), `M`/`V` moving platforms (port the JS track search), enemy letters → `spawn_enemy(ch, x, y)` (phase 1: `b`, `a`, `t` only; unknown letters are ignored with a printed warning). Fields mirror the JS: `ents, items, plats, projs, cps, signs, springs, time, hitstop, trauma, flash, break_q, tokens, kills, hits, cam`.
5. **`room_view.gd`** draws the static room once per load:
   - `TileMapLayer` named `Tiles` with a `TileSet` built in code: tile size 16, one `TileSetAtlasSource` on `res://assets/tiles/w1_tiles.png`, `texture_region_size = Vector2i(16,16)`, `create_tile(Vector2i(c, r))` for every cell of the 16×7 atlas.
   - For each cell: SOLID → atlas `(mask, variant)` with `mask = u | d<<1 | l<<2 | r<<3` where `u = tile(tx,ty-1)==SOLID or ty==0`, `d = tile(tx,ty+1)==SOLID or ty==h-1`, `l = tile(tx-1,ty)==SOLID`, `r = tile(tx+1,ty)==SOLID` (the same `isS` rule as `renderStatic`), `variant = floori(hash(tx, ty, 1) * 4)`; ONEWAY → `(mask2 + 4 * (tx & 1), 4)` with `mask2 = l | r<<1`, `l = tile(tx-1,ty) in [ONEWAY, SOLID]`, same for `r`; SPIKE_U `(0,5)`, SPIKE_D `(1,5)`, CRACK `(2,5)`, CRUMBLE `(3,5)` — CRACK and CRUMBLE go on a second layer `Dynamic` so they can be erased when broken.
   - Decor layer `Decor` (TileMapLayer, same TileSet, drawn before `Tiles`): for every SOLID tile whose upper neighbour is E, put atlas `(floori(hash(tx, ty, 77) * 16), 6)` in the cell above.
   - Background: a `Parallax2D` with a `Sprite2D` of `res://assets/bg/w1.png` (`centered=false`), `repeat_size = Vector2(384, 0)`, `scroll_scale = Vector2(0.25, 0.1)`, drawn behind everything.
6. A temporary `main.gd` path: load R01, put the camera at the start position, render.

**Acceptance:**
- Headless: `"$GODOT" --headless --path godot -- --test=tiles` runs `src/test/run_tests.gd` (create it now: a script that `main.gd` hands control to when the user arg `--test=<name>` is present; it prints `TEST <name> PASS|FAIL <info>` and quits with exit code 0/1). Tests never wait for real frames: they set `room.auto_step = false` (so `Room._physics_process` does nothing), then loop `Controls.poll(); room.step(1.0 / 60.0)` themselves. Test `tiles`: load R01; assert `w == 202`, `h == 16`, `tile(0,13) == SOLID`, `tile(-1,5) == SOLID`, `tile(5,99) == E`, `tile(24,12) == SOLID`, `tile(75,11) == ONEWAY`; a 10×10 box at (35, 190) moved down by 20 → y 198, result 1; a 10×10 box at (35, 198) moved right in steps of 2 until `move_x` returns non-zero → x 374, result 1 (the step at column 24); the same box at (1219, 150) moved down by 20 with `no_oneway = false` → y 166, result 1 (lands on the `====` at row 11, columns 75–78); with `no_oneway = true` → y 170, result 0.
- Screenshot: `xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path godot --rendering-driver opengl3 -- --shot=/tmp/.../r01.png` (main.gd saves the GameViewport image after 30 frames and quits when `--shot=` is given). Look at it with the Read tool: ground with grass, the sign, the background.

---

## MV1-05 · The player, Clawd drawing, camera, hitstop, particles

**Goal:** Clawd moves exactly like in the current game.

**Steps:**
1. **`player.gd` (`class_name Player extends Node2D`)** — port `class Player` from `// js/player.js` **line by line**, in the same order, with the same constants (`RUN = 118` … `POGO = 262`), the same field names (snake_case where JS is camelCase: `on_ground`, `jump_buf`, `wall_dir`, `wall_coy`, `last_wall`, `dash_t`, `dash_cd`, `dash_buf`, `can_dash`, `dash_id`, `dash_dx`, `dash_dy`, `can_double`, `atk_t`, `atk_cd`, `atk_buf`, `atk_id`, `atk_dir`, `atk_face`, `atk_live`, `atk_dmg`, `inv`, `hurt_t`, `prev_bottom`, `drop_t`, `lock`, `grace`, `ride`, `safe`, `meter`). Port: `hurtbox`, `atk_box`, `set_safe`, `add_meter` (meter exists, agents do not in phase 1), `update`, `on_oneway`, `on_hit`, `bounce`, `spring`, `hurt`, `hazard`, `die`. Skip in phase 1: `Agent`, `celebrate`, `auto`, `frozen`, co-op branches (`G.coop`, `remote`, `blue`).
   - `tools` = `Game.tools` (Dictionary `{bash, sudo, agents, opus}`); phase 1 test build: `bash = true`, the rest false.
   - Calls to effects (`L.stop`, `L.shake`, `L.dust`, `L.ring`, `L.burst`, `L.part`, `L.spark`, `L.pop`, `L.flashScreen`) go to the room (`room.stop(t)` etc.), sounds to `Audio.sfx(name, {vol})`.
   - Hitstop: `room.stop(t)` sets `room.hitstop = max(room.hitstop, t)` — read `stop()` in `// js/level.js` and port it exactly; the room skips simulation while `hitstop > 0` (§3.2), which the parity test depends on.
2. **`clawd_draw.gd`** — port `G.drawClawd(g, x, y, o)` and `G.clawdPixels()` from `// js/art.js` line by line as `static func draw_clawd(ci: CanvasItem, x: float, y: float, o: Dictionary)` using `ci.draw_rect(Rect2(a, b, w, h), color)`; colours from `G.COL` (copy the hex values into `game.gd` as `const COL = {...}`). The player's `_draw()` = port of `Player.draw` (poses, blink, breathing, wall slide, dash ghosts, hurt blink) **without** `G.light`. The claw slash uses the captured `slash_*`/`slashBig_*` sprites with the same frame choice and offsets as the JS `draw`. Call `queue_redraw()` every frame. The player node sits at `(0,0)` of the room and draws in room coordinates (so the JS math with `cx = cy = 0` applies directly).
3. **Camera** — port `snapCam`, `updateCam`, `camTarget`, `camP` into `room.gd`; each frame set `Camera2D.position = Vector2(floori(cam.x + shake_x + 0.5), floori(cam.y + shake_y + 0.5))` where the shake offset is the port of the current game's trauma shake (find `trauma` use in `// js/level.js` `draw`/`shake` and port it).
4. **`fx.gd`** — port the particle helpers the player and enemies use: `part`, `burst`, `spark`, `dust`, `ring`, `pop` (floating text with `PixelText`), `flash_screen`, `explode` (look each up in `// js/level.js`). Keep a flat array of particles, step them in `room.step`, draw them with `_draw()`.
5. **`pixel_text.gd`** — `static func draw_text(ci, text, x, y, color, opts := {})` reading `assets/fonts/big|tiny.json`, drawing glyphs with `ci.draw_texture_rect_region(tex, Rect2(x, y, w*sc, h*sc), Rect2(gx, 0, w, h), color)`; supports `align` (`"c"`, `"r"`), `scale`, `outline` (8 offsets like the JS), `shadow`. Also `text_width(text, opts)`.

**Acceptance:**
- `--test=jump`: with `Controls.script_input` driving the same input as the reference trace in §2 (right 0–59, jump 10–39, room R01, no enemies — delete them after load), final x = 151.608 (±0.001) and min y = 140.596 (±0.001). Print both.
- Play it yourself under xvfb with a scripted input that runs, jumps, dashes and swipes; save 4 screenshots and look at them (pose, slash, dash ghosts).

---

## MV1-06 · Bug, Typo, combat, items, checkpoint, signs, HUD, sound

**Goal:** room R01 is fully playable like level 1-1, minus Flaky and the exit.

**Steps:**
1. **`enemy.gd` (`class_name Enemy extends Node2D`)** — port `class Enemy` (`hit`, `die`, `physics`, `edge_ahead`, `tick`, `to_player`, `hurtboxes`, `harmboxes`) with a `Sprite2D` child for drawing (anchor rules §3.3, flash shader). `hit()` returns `"block"`, `"kill"`, `"hit"` or `""` (JS `false`/`undefined` → `""`). `die()` drops loot with `room.drop(cx, cy, loot)` and calls `room.player.add_meter(8)`.
2. **`bug.gd`, `typo.gd`** — exact ports of `Bug` (letters `b` normal, `a` spiky) and `Typo`. Animation frames as in their JS `draw`.
3. **Combat** — port `Level.interactCombat(p)` (claw vs entities, claw vs projectiles, dash hits, stomps, contact damage, hazards via `hazardAt`, springs) and `hazardAt` exactly. Keep the per-player marks `hitKey`/`dashKey` as dictionary keys on the enemy (`e.marks["hit_p1"] = atk_id`).
4. **Items** — port the items part of `Level.update` (loose drops with gravity and bounce, magnet, pickup radius) and `collect()` for `token`, `spark`, `coffee`. Token sprite `token_0..3`, spark sprites `spark_0/1`, coffee `coffee`. Keep the current rule "every 25 tokens heals 1" in phase 1 (the new healing model comes in phase 2).
5. **Checkpoint** — port `interactGoals` for checkpoints only (activate, heal to full, set safe point, `committed ✓` pop, sound). Death in phase 1: after 1.2 s reload R01 and place the player at the active checkpoint (or the start), hp full.
6. **Signs** — port the sign behaviour (find `signs` in `// js/level.js`: when the player stands near a sign its text box shows). Draw with `PixelText` and the captured `sign` sprite.
7. **HUD** (`hud.gd`, inside the SubViewport's CanvasLayer): hp pips with `pip`/`pipOff` at the same positions as the current HUD (read the HUD drawing in `// js/scenes.js`, search for `S.pip`), token count, room title for 2.5 s after load (top-left, tiny font).
8. **Audio** (`audio.gd`): preload every `res://assets/sfx/*.wav` into a dictionary; `sfx(name, opts := {})` plays it on a pool of 12 `AudioStreamPlayer`s (bus `Master`, `volume_db = linear_to_db(opts.get("vol", 1.0))`), and applies the JS minimum gap of 28 ms per name. `music(name)` plays `res://assets/music/<name>.ogg` with `loop = true` and `loop_offset = index.json loop_start` (OGG import: set `loop` in code on the `AudioStreamOggVorbis`), crossfade 0.5 s. Start `w1` when R01 loads. Browsers only start audio after the first touch/click/key: Godot handles that itself; do nothing special.

**Acceptance:**
- `--test=combat`: R01, place a Bug at (500, 199) facing left and the player at (470, 198); script: attack on frame 5 → the Bug dies within 20 frames (`kills == 1`) and drops 1 token; place another Bug and drop the player on it from 40 px above → stomp kill and the player bounces (vy < 0 right after).
- `--test=hurt`: a Typo touching the player → hp 4, `inv` ≈ 1.3; a second touch within 1 s does nothing.
- Screenshot with HUD, a sign open and a Bug.

---

## MV1-07 · Touch controls, pause, debug overlay

**Goal:** the phone test can be run and measured.

**Steps:**
1. **`touch_controls.gd`** — port the on-screen pad from the `<script>` right after `<div id="touch" hidden>` in `public/index.html` (read all of it and the `.tb`/`#stick` CSS above it). Same behaviour, drawn with `_draw()`:
   - Enabled on the first `InputEventScreenTouch` (or immediately if `DisplayServer.is_touchscreen_available()`); then `Touch.visible = true`.
   - Sizes in CSS px × `k_css` where `k_css = DisplayServer.screen_get_scale()`; `k = clamp(min(win_w, win_h) / k_css / 380, 0.8, 1.25)`; button spots `{jump: [22, 26, 82], attack: [116, 30, 62], dash: [34, 120, 62], special: [118, 112, 54]}` = [right, bottom, diameter] in CSS px × k; pause = small rounded rect 46×38 top-right (landscape: 10 px from the top; portrait: just under the game screen).
   - Left half: floating stick, radius `R = 50 * k` CSS px, base follows the thumb, direction thresholds exactly as `moveStick` (`m > 0.28 && ux < -0.38` → left, etc.).
   - A finger belongs to the button under it (hit radius `r * 1.18 + 8` CSS px, nearest wins) and moves to another button when it slides onto it. Every press sets `Controls.touch[a] = true` and `Controls.tq[a] = true`; a release keeps the press for at least `MIN_HOLD = 90 ms`. Multi-touch by `event.index`.
   - Look: circles with the colours of the CSS (`rgba(244,237,224,0.42)` border, dark translucent fill; pressed = Clawd orange `#d77757`), labels `JUMP CLAW DASH SPEC` in the tiny font scaled ×2 × device scale.
2. **Pause** (`pause.gd`): `pause`/`start` toggles; shows `PAUSED`, options `Resume`, `Restart room`, `30 fps: on/off`. While paused the room does not step; music volume −10 dB.
3. **Debug overlay** (`debug_overlay.gd`), shown when the URL query (web) or user args (native) contain `debug`. Text in the big font, scale 2 × device scale, top-left, black outline:
   ```
   FPS 60 | avg 59.4 | low1% 52.0 | min1 59.8 | now-min 58.7
   input 12 ms (max 33) | audio 85 ms | mem 48.2 MB (2m 47.9 / 10m 48.3)
   ph1 abc1234 | ScriptProcessor | 1080x2340 @2.75 | 16:42
   ```
   - FPS: `Engine.get_frames_per_second()`; keep every frame time since the room loaded in a ring of 36000 samples; avg = frames / seconds; low1% = the 1st percentile of instantaneous fps (1/frame time) over the whole session, recomputed once per second; `min1` = average fps during minute 1, `now-min` = average during the current minute.
   - input: on `InputEventScreenTouch`/key press store `Time.get_ticks_usec()`; in the next `_process` show the difference; keep the max.
   - audio: time from the first touch to the first `Audio.sfx` that actually starts playing (on the first touch play `uiOk`).
   - mem: `OS.get_static_memory_usage() / 1048576.0`, sampled at 2 min and 10 min (show both once taken).
   - line 3: contents of `res://build.txt` (written by export-web.sh; `dev` when missing), audio driver `AudioServer.get_driver_name()` (web reports the active one), window size, device scale, wall clock.
4. **Query options** (read once in `game.gd` from `JavaScriptBridge.eval("location.search")` on web, `OS.get_cmdline_user_args()` natively): `debug`, `fps30` (`Engine.max_fps = 30`), `mute`, `selftest`.
5. **Selftest** (`?selftest`): load R01, run a fixed 180-frame script (run right, jump, dash, swipe), play `jump`, then print `CLAWD: selftest PASS` if the player moved more than 100 px and no script error happened, else `CLAWD: selftest FAIL <why>`. Then keep running (do not quit on web).

**Acceptance:** web build under xvfb in Chromium with a touch-emulating context (`hasTouch: true, isMobile: true, viewport 800×360, deviceScaleFactor 2`): tap at the jump button position → the player jumps (check through `?debug` overlay text or a `console.log` you add for tests: `CLAWD: jump`); the stick moves the player right. Screenshot the overlay in portrait (360×800) and landscape and look at them.

---

## MV1-08 · Automated tests

**Goal:** one command proves the build works and the movement matches the current game.

1. **Parity** (`tools/godot/parity/`):
   - Tape format (`tapes/<name>.json`): `{ "room": "1-1", "start": [x, y] | null, "tools": {"bash": true}, "frames": 120, "input": [[from, to, ["right","jump"]], ...] }` — inclusive frame ranges; `start: null` = the level's own start after 60 settle frames.
   - Tapes (write exactly these): `run_jump` (§2 reference), `short_hop` (right 0–40, jump 5–6), `dash_ground` (settle, dash on frame 10, right 0–30), `dash_air` (jump 0–20, dash + right 12, up 12), `wall_jump` (start [2355, 198], inside the two-wall shaft of 1-1: walls at columns 144–145 and 149–150, rows 4–9; frames 120; jump 0–10, right 0–40, jump 20–24, left 30–60, jump 34–38), `drop_oneway` (start [1219, 166], standing on the `====` at row 11, columns 75–78; frames 60; down 10–20, jump 12), `pogo_none` (frames 60; jump 0–15, down 5–30, attack 12).
   - `js-trace.js <tape>`: loads the JS game (§2), sets `G.save.data.tools` from the tape, starts the level, removes all entities (`L.ents.length = 0`), settles or teleports the player (`pl.x = ...; pl.y = ...; pl.vx = pl.vy = 0`), then for each frame sets `G.input.script` and calls `G.step(1, true)`, writing `frame,x,y,vx,vy,onGround` CSV lines (6 decimals) to stdout.
   - Godot side: `--test=tape:<path>` does the same in R01 (rooms.json maps level `1-1` → `R01`) and writes the same CSV.
   - `compare.py a.csv b.csv` → prints the first frame that differs by more than 0.01 px in x or y, or `PARITY OK <frames>`; exit 1 on difference.
2. **Headless run**: `--test=soak`: R01 with enemies, 3600 frames of random input from a seeded RNG (seed 7, a new random set of held actions every 15 frames); pass = no script errors (check the log for `SCRIPT ERROR`) and the player is still inside the room bounds.
3. **`tools/godot/web-check.js`**: starts `server.js` on port 3110 (`NO_OPEN=1`, kill by PID at the end), opens `http://127.0.0.1:3110/mv/?selftest` and `http://<container ip>:3110/mv/?selftest` (container ip = first address of `hostname -I`; set `NO_PROXY` for it) in Chromium with `--autoplay-policy=no-user-gesture-required --enable-unsafe-swiftshader --use-angle=swiftshader`; for both: wait for `CLAWD: selftest PASS` (≤ 40 s), no page errors; for the insecure one also assert, with an init script wrapping `AudioContext.prototype.createScriptProcessor` that records the peak of its output (see the 2026-10-09 check in §2), that the peak is > 0.01.
4. **`tools/godot/test-all.sh`**: smoke.sh → every `--test=` (tiles, jump, combat, hurt, soak, all tapes with compare) → export-web.sh → web-check.js → `node tools/coop-harness.js mv-serve cache`. Prints a summary table; exit 1 if anything failed.

**Acceptance:** `bash tools/godot/test-all.sh` → all PASS. If a parity tape fails, fix the port (not the tape, not the tolerance). Paste the summary in the commit message.

---

## MV1-09 · Delivery, phone test instructions, phase report

1. `git fetch origin main && git merge --no-edit origin/main` (so the current game on `ph1` equals `main`), `bash tools/godot/test-all.sh` once more.
2. Commit `public/mv/` (the build from that run). This is the only commit of `public/mv/` in phase 1.
3. Run the existing full quick checks: `node tools/coop-harness.js smoke cache paths mv-serve fight-hits revive soak` (`SOAK_S=20`). All PASS.
4. Write `docs/metroidvania/06-phase1-test.md` §6 "نسخه‌ی نهایی آستانه‌ها" — append (do not rewrite the file) the final gate, which replaces §3's overall rule:
   - **Test A** (`?debug`): pass if avg ≥ 55, low1% ≥ 40, input ≤ 50 ms, sound plays, memory growth ≤ 20 %, now-min ≥ 90 % of min1.
   - **Test B** (only if A fails on fps): `?debug&fps30`. Pass if avg ≥ 29.5 and low1% ≥ 27 (the current game also draws at 30 on phones).
   - **Pass** = A or B. **Fail** = both fail → next step is an Android build (decided in a later phase with Zakaria).
5. `docs/reports/metroidvania-phase1.md` (Persian): what was built, test summary, every deviation from this plan, the build size (wasm gz, pck), and the exact steps for Zakaria (below).
6. Final message to Zakaria (Persian, short), containing these steps verbatim (fill in nothing else):
   1. تو پوشه‌ی بازی (همون‌جا که `start.bat` هست) با Notepad یه فایل جدید بساز، فقط بنویس `ph1`، و با اسم `update-branch.txt` ذخیره کن (موقع Save، نوع فایل رو بذار All files).
   2. `update.bat` رو بزن و صبر کن تموم شه. اگه `start.bat` روشنه، سرور خودش ریستارت می‌شه.
   3. رو PC: `http://localhost:3000/mv/` رو باز کن و با کیبورد یه دور بازی کن.
   4. رو گوشی (همون Wi-Fi): آدرسی که پنجره‌ی `start.bat` جلوی `Same Wi-Fi/hotspot` نشون می‌ده رو باز کن و آخرش `/mv/?debug` بذار. مثلاً `http://192.168.1.5:3000/mv/?debug`.
   5. قدم‌های `docs/metroidvania/06-phase1-test.md` بخش ۲ رو انجام بده (۱۰ دقیقه بازی، اسکرین‌شات دقیقه‌ی ۲ و ۱۰).
   6. اگه FPS زیر ۵۵ بود، یه بار هم با `/mv/?debug&fps30` تست کن.
   7. اسکرین‌شات‌ها رو بفرست.
   8. بازی فعلی‌تون (`http://.../` بدون `/mv/`) عوض نشده. برای برگشتن به آپدیت‌های عادی: `update-branch.txt` رو پاک کن و `update.bat` رو بزن.
7. Stop. Phase 2 starts only after Zakaria sends the numbers and says so.

---

## Appendix A · Where things are in `public/index.html`

Search for these markers (line numbers drift): `// js/core.js` (input, hash, helpers), `// js/gfx.js` (text, spr, tint), `// js/audio.js` (sfx table, renderOffline), `// js/art.js` (COL, drawClawd, SPR), `// js/world_art.js` (THEME, drawSolid, drawBG), `// js/level.js` (Level: tiles, collision, camera, items, combat), `// js/player.js`, `// js/enemies.js` (Enemy, Bug, Typo, MAKE letters), `// js/bosses.js`, `// js/data.js` (levels), `// js/scenes.js` (HUD, menus), `// js/main.js` (loop: 60 Hz fixed, max 4 steps, phones draw at ≤ 30 fps).
