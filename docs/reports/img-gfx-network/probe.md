# MVGN-01 — renderer probe (what works, what it costs)

Probe: `--scene=gfxprobe` (native) or `/mv/?gfxprobe&debug` (web). Each step draws one feature into the 384×216 game viewport and checks that a
measured pixel changed the way the feature should change it. ms/frame is the average over 120 frames. Run on the cloud box with **no GPU**
(llvmpipe natively, SwiftShader in headless Chromium), so the ms numbers are CPU-rasteriser costs: they show the *relative* cost of each feature,
not what a phone's GPU does. The real phone numbers come from Zakaria's run (steps at the bottom).

| step | desktop (opengl3) works | web (WebGL 2) works | desktop ms | web ms | note |
|---|---|---|---|---|---|
| base (no feature) | — | — | 6.17 | 28.33 | a grey rect only: the floor for the other rows |
| 1 lights: `CanvasModulate` + 4 `PointLight2D` | yes | yes | 7.98 | 57.14 | lit 0.61 vs dark 0.08 |
| 2 normal map (`CanvasTexture`) | yes | yes | 6.35 | 28.32 | lit side 0.31 vs 0.12; no extra cost over the lights |
| 3 `LightOccluder2D` shadows (PCF5) | yes | yes | 11.90 | 58.98 | the pixel behind the occluder is darker (0.08 vs 0.17) |
| 4 native glow (`WorldEnvironment`, canvas background) | yes | yes | 27.09 | 84.34 | works without HDR 2D, but **it also blooms the HUD** (one effect for the whole viewport) and costs about 2× the custom bloom |
| 5 custom bloom (shader, `hint_screen_texture` + mip lod) | yes | yes | 17.39 | 51.50 | halo next to a bright rect (0.73 vs 0.10) |
| 6 `canvas_item` shader reading `hint_screen_texture` | yes | yes | 10.83 | 38.07 | needed for haze, reflections, LUT |
| 7 16³ LUT grade from a 256×16 strip | yes | yes | 8.24 | 37.44 | red/blue swap checked exactly |

## What the plan uses (decisions)

- **Bloom: custom** (step 5), not native glow. It works everywhere, it sits *below* the HUD layer so the HUD is never touched (native glow would bloom
  the HUD text), and it is cheaper. It is built from `BackBufferCopy` + one `hint_screen_texture` shader with mip-level taps (no extra viewports).
- **Lights and normal maps: native** (`PointLight2D`, `CanvasTexture`). They work in both renderers. The light count is the cost driver (step 1: 4 lights
  cost about +1.8 ms natively, +29 ms on the software web renderer), so the light budgets of §3.5 stay.
- **Shadows: native `LightOccluder2D`** with PCF5 works in both; it stays Ultra-only (MVGN-16).
- **Screen-reading shaders** (haze, reflection, LUT, vignette, grain) all work: one `BackBufferCopy` per full-screen pass, kept to as few passes as possible
  (the post chain is merged into one shader where it can be).
- Nothing needed a fallback. If a phone fails a step, the table from its log says which (see below) and that feature drops to its fallback: lights → off,
  normals → off, shadows → off, bloom/LUT/haze → off.

## Zakaria's check on the Y9s (about 2 minutes)

1. Open `http://<PC address>:3000/mv/?gfxprobe&debug` in Firefox on the phone (the same address the game uses; after `update.bat` has fetched this build).
2. The page shows seven steps for about 2 s each, and a list of "feature: yes/NO ms" in the corner. Wait for `DONE (send the log)`.
3. Open the pause-less log: the probe has no menu, so take a **screenshot of the screen** when it says DONE and send it. (The same lines are printed in the browser console.)
4. Anything marked `NO` is a feature the phone cannot do; tell me which and I turn it off for that tier.
