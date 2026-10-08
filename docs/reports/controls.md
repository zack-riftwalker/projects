# Custom controls (PLAN-controls.md, K1–K5)

Branch `claude/controls-k1-k5`, one commit per task ID. `server.js`, `src/worker.js` and the network layer were not touched.

## What changed
- **K1** bindings model: `save.keys` (null = defaults, survives "erase save"), `G.input.rebuild()` rebuilds `KEYMAP`, `G.keyLabel` / `G.actionLabel`. `KeyF`, `KeyM`, `Tab` are reserved. The old hidden extra aliases (`KeyK`, `ShiftRight`, `KeyL`, `KeyI`) were dropped, not kept.
- **K2** `Controls` screen, opened from a new Options row (hidden on touch devices). Two key slots per action, `press a key...` capture (the game's input sees nothing while capturing), Esc cancels, Backspace/Delete clears (the last key of left/right/up/down/jump/attack/pause cannot be cleared), conflicts swap with a 1.5 s note, `reset to defaults`, `back`. It works from the title, the map pause, the level pause and the co-op guest pause menu, since all of them reuse `Options()`.
- **K3** gamepad: **included, it did not get messy.** `keys.pad`, a third "pad" column, capture waits for the next *fresh* button press (buttons already held are ignored), and `pollPad` reads the table. The d-pad and left stick stay fixed. New `input.settle()` stops a button that is still held from counting as a new press after a rebind. A pad button has one action: binding it removes it from any other action.
- **K4** signs use action tokens (`[jump]`, `[attack]`, `[dash]`, `[special]`, `[down]`, `[move]`). Old bracket text still renders as written. `[jump]` shows both keys, e.g. `Z/SPACE`. Hard-coded caps now follow the bindings: map hints, results `commit`, HUD special, `press Z`, the title footer, tool cards (`tl.key` became `tl.act`) and `HOLD <start> TO SKIP`. Pad names in hints (the optional point 4) were skipped.
- Arrow glyphs are not in the tiny font, so arrow keys are labelled `LEFT`/`RIGHT`/`UP`/`DOWN`.
- **K5** same diff applied to `clawd-cloud/public/index.html`. New scenarios in `tools/scenarios-controls.js` (both harnesses): `keys-remap keys-screen keys-pad keys-hints`.

## Tests
- `clawd-coop`: `node tools/coop-harness.js all` → 48/48 pass (includes `smoke` and the four new scenarios).
- `clawd-cloud` (`wrangler dev`): `smoke host-blip pause-resume` + the four `keys-*` scenarios → all pass.

## Screenshots
`reports/controls/`: `options.png` (new row), `controls.png` (screen with pad column), `controls-capture.png` (capture state).
