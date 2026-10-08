# CLAWD — Custom controls (key remapping) — Implementation Plan

> **خلاصه برای زکریا:** یک بخش «controls» در Options اضافه می‌شود.
> - برای هر کار بازی (چپ، راست، بالا، پایین، پرش، ضربه، dash، special، start، pause) دو کلید قابل تعیین است.
> - دسته‌ی بازی هم قابل تنظیم است (فاز K3).
> - راهنماهای داخل بازی (مثل «[X] بزن») خودکار کلید جدید را نشان می‌دهند.
> - تنظیمات ذخیره می‌شود و با «erase save» پاک نمی‌شود.
> - روی شبکه و co-op هیچ اثری ندارد: کلیدها فقط روی دستگاه خود هر بازیکن خوانده می‌شوند.

---

## 0. Rules

- **Branch:** start from `claude/tender-lovelace-ejlz7m`. One commit per task ID.
- **Files:** edit `clawd-coop/index.html` first.
  - When K1–K3 pass, apply the **same** changes to `clawd-cloud/public/index.html`. The input, Options and sign code is identical in both files; only the co-op module differs.
  - Do not touch `server.js`, `src/worker.js` or anything network-related.
- **Style:** same as the game (compact ES2017+, `G` namespace, no new dependencies).
- **Solo and co-op must not regress.** `smoke` and the co-op suite must still pass (`node tools/coop-harness.js all` in `clawd-coop/`).
- **Anchors** (locate by symbol, not line number):
  - `const KEYMAP = {`, `const ACTIONS = [`, `input.poll = () =>`, `function pollPad(state)`
  - `function Options(onClose, canErase)`, `G.keycap = (g, x, y, label, col)`
  - the sign parser `/^\[([^\]]+)\](.*)$/`, and the level `signs:` strings
  - hard-coded key caps: `G.keycap(g, px, H - 17, 'Z')`, `'ESC'`, `G.keycap(ug, 55, hudY + 8, 'V')`, `G.keycap(ug, x + pw - 66, yy - 3, 'Z')`, `'HOLD ENTER TO SKIP'`

---

## K1 · Bindings model (keyboard)

1. **Save data:** add `keys` to the save defaults: `keys: null`, where `null` means "use the defaults".
   - Merge it in `load()` exactly like `opt`.
   - Keep it in `reset()`, like `opt` and `coopDiff`: erase save does not wipe controls.
2. **Defaults:** `DEFAULT_KEYS = { left: ['ArrowLeft','KeyA'], right: ['ArrowRight','KeyD'], up: ['ArrowUp','KeyW'], down: ['ArrowDown','KeyS'], jump: ['KeyZ','Space'], attack: ['KeyX','KeyJ'], dash: ['KeyC','ShiftLeft'], special: ['KeyV','KeyE'], start: ['Enter', null], pause: ['Escape','KeyP'] }`.
   - Two slots per action.
   - The current extra defaults `KeyK`, `ShiftRight`, `KeyL`, `KeyI` are dropped. Keep them as hidden third aliases only if that's trivial.
3. **`G.input.rebuild()`:** builds `KEYMAP` (code → action) from `G.save.data.keys || DEFAULT_KEYS`.
   - The keydown and keyup handlers read the rebuilt map.
   - Call it once after the save loads, and after every change.
4. **Reserved keys:** `KeyF` (fullscreen), `KeyM` (mute), `Tab`, and any key held with Ctrl/Meta.
   - None of these can be bound.
   - The F/M shortcuts keep working only while F/M is not bound to an action (it can't be, per the rule above).
5. **Labels:** `G.keyLabel(code)` maps `KeyZ` → `Z`, `Digit1` → `1`, `ArrowLeft` → `←`, `Space` → `SPACE`, `ShiftLeft` → `SHIFT`, `Escape` → `ESC`, `Enter` → `ENTER`, and so on.
   - `G.actionLabel(action)` returns the label of the action's first bound key (or `?`).
   - `G.actionLabel(action, true)` returns both keys, as `Z/SPACE`.

**Test (new scenario `keys-remap` in `tools/scenarios-p1.js` or a new `scenarios-controls.js`, loaded like the others):**
- Bind jump to `KeyQ` via the save and call `rebuild()`.
- A `keydown` with `code: 'KeyQ'` makes `G.input.pressed.jump` true on the next poll.
- The old `KeyZ` no longer does anything.
- Reloading the page keeps the binding.

---

## K2 · Controls screen in Options

1. **Entry point:** a new Options row `controls` (act) opens a sub-screen `Controls(onClose)`, built the same way as `Options` (same panel, same row height logic, same sounds).
   - It works from the title, from the map pause, from the in-level pause, and from the co-op guest pause menu, which already reuses `Options()`.
2. **Rows:** one row per action, showing `label   [key1] [key2]` drawn with `G.keycap`.
   - The cursor moves up and down over rows and left and right between the two slots.
   - Extra rows at the bottom: `reset to defaults`, `back`.
3. **Binding a key:**
   - Confirm on a slot → the slot shows `press a key…`, and input is captured raw (the `KEYMAP` is bypassed).
   - The next keydown is assigned.
   - **Escape** cancels the capture. Escape is still bindable, but only through a slot that is not being captured with Escape itself.
   - **Backspace or Delete** clears the slot, but the last remaining key of `left/right/up/down/jump/attack/pause` can't be cleared. Show a short "needs at least one key" message.
   - **Conflicts:** if the key is already used by another action, **swap** it, so the other action gets this slot's old key. Show a 1.5 s note, e.g. `X moved to dash`.
4. **Safety:**
   - While capturing, the game's own `G.input` sees nothing.
   - After saving, call `G.input.rebuild()` and `G.input.clear()`, so the key just pressed doesn't trigger a menu action.
5. **Mobile:** on touch devices (`body.touch`), the row is hidden or shows "connect a keyboard". The on-screen buttons are not remapped.

**Test:**
- In the controls screen, rebind attack to `KeyQ` with real key events.
- The swap case works: bind jump to `KeyX` and attack gets `KeyZ`.
- Escape cancels the capture.
- `reset to defaults` restores everything.
- A screenshot of the screen goes in the report.

---

## K3 · Gamepad remapping (optional, after K1–K2 are green)

1. `keys.pad = { jump: 0, attack: 2, dash: [1,5,7], special: [3,4], start: 9, pause: 8 }`, with the same defaults as `pollPad` today.
   - The d-pad and left stick stay fixed for movement.
2. The controls screen gets a second column, "pad". Capturing waits for the next newly pressed gamepad button, polled from `navigator.getGamepads()` in the screen's `update`.
3. `pollPad` reads the binding table instead of the hard-coded indices.

**Test:** stub `navigator.getGamepads` in the harness to return a pad with button 6 pressed. Bind jump to 6, and the poll shows `jump` down.

---

## K4 · Hints show the player's keys

1. **Sign strings:** replace hard-coded key names with action tokens:
   - `[Z]` → `[jump]`, `[X]` → `[attack]`, `[C]` → `[dash]`, `[V]` → `[special]`, `[DOWN]` → `[down]`
   - `[ARROWS]` → `[move]` (a special token that shows the four direction keys or `←→`)
   - `[SPACE]` disappears, because `[jump]` already shows both keys
   - Do this in **every** `signs:` string, plus `tl.key` in the tutorial lines.
2. **Sign parser** (`/^\[([^\]]+)\](.*)$/`): if the bracket content is an action name, draw `G.actionLabel(name)`; otherwise draw the text as before, so old strings still render.
3. **Hard-coded caps:** use `G.actionLabel('jump')` for the `'Z'` caps (map "checkout", results "commit"), `G.actionLabel('pause')` for `'ESC'`, and `G.actionLabel('special')` for the HUD `'V'`. `'HOLD ENTER TO SKIP'` becomes `'HOLD ' + G.actionLabel('start') + ' TO SKIP'`.
4. **Pad hints:** if `G.input.padActive`, the hints may show pad names (A/B/X/Y). This is optional; skip it if it makes the code messy.

**Test:**
- With jump bound to `KeyQ`, the first sign of `1-1` and the map hint render `Q`. Check with a canvas-text spy or a screenshot.
- Grep proves no `[Z]`, `[X]`, `[C]`, `[V]` remain in the sign strings.

---

## K5 · Finish

- Run `smoke` + the full `clawd-coop` suite on a clean line. The co-op input path is unchanged, but the harness drives the guest with `ArrowRight`, `KeyX`, `KeyZ` and `Escape`, so it must still pass with the default bindings.
- Apply the same diff to `clawd-cloud/public/index.html`, then run `smoke`, `host-blip` and `pause-resume` there (`clawd-cloud/tools`, against `wrangler dev`).
- Short report `clawd-coop/reports/controls.md`: what changed, test results, screenshots.

---

## Size estimate

| part | new/changed code | agent time |
|---|---|---|
| K1 bindings model | ~60 lines | short |
| K2 controls screen | ~120–150 lines | the main part |
| K3 gamepad (optional) | ~60 lines | short |
| K4 hints / signs | ~40 lines + editing ~10 sign strings | short |
| K5 tests + port to cloud | 4–6 scenarios | short |

Total ≈ **250–330 lines**, a small-to-medium feature. Only the input, Options and sign code change; nothing in the network layer.
