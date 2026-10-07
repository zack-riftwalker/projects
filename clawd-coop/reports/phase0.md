# Phase 0 report — setup & test tooling

## What changed
- P0-1: the repo already existed (`zack-riftwalker/projects`, branch `claude/sweet-volta-jupdtd`); the game lives in its own folder `clawd-coop/`. The untouched upload is commit `baseline`. `.gitignore` ignores `node_modules/`. Plan copy kept as `PLAN.md`.
- P0-2: `server.js` network simulator (`SIM_LAG`, `SIM_JITTER`, `SIM_STALL_PCT`, `SIM_STALL_MS`, `SIM_BW`), per-direction queue with order preserved, banner when on.
- P0-3: `tools/coop-harness.js` (Playwright, two browser contexts, byte/message counters per message type in both directions). Run `node tools/coop-harness.js <scenario|all>`. Chromium comes from `/opt/pw-browsers/chromium`.

## Baseline results (untouched game logic)
| scenario | result | numbers |
|---|---|---|
| crash-url | FAIL | server died |
| crash-big | FAIL | server died (close 1009 was sent first) |
| paths | FAIL | `/assets/../server.js` leaks the source |
| double-hit | FAIL | hpLost = 14 (must be 2) |
| solo-hit | PASS | 1 hit per swing |
| softlock | FAIL | still dead, reviveQ=1, same level after 6 s |
| host-gone | FAIL | guest still in the level 2.5 s after host closed |
| boss-intro | FAIL | guest `frozen` = false for 1-B..5-B |
| bt-spam | FAIL | 34 `bt` messages in open air |
| p2-freeze | FAIL | 150 ms longest freeze at SIM_LAG=60 (plan estimated ≈250) |
| bandwidth | FAIL | idle 1-1: 4.3 KB/s host→guest; worst boss 4-B: **27.6 KB/s** host→guest; guest→host ≈2.1–2.2 KB/s |
| smoke | PASS | 18 levels × 180 scripted steps, no page errors |

Bandwidth per level (KB/s, host→guest / guest→host): 1-1 4.3/2.2 · 1-B 7.1/2.2 · 2-B 17.7/2.2 · 3-B 8.6/2.1 · 4-B 27.6/2.1 · 5-B 8.8/2.1.
