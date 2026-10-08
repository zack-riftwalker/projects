# Phase 1 report — bug fixes

All Phase 1 scenarios PASS (`node tools/coop-harness.js <name>`), plus `smoke` (solo, 18 levels). `bandwidth` is a Phase 3 target and still fails (numbers unchanged from baseline).

| Task | What changed | Test |
|---|---|---|
| P1-01 | Server: 400 on bad URL, error handlers on every socket/server, path allow-list, `start.bat` restart loop, server opens the browser itself (`NO_OPEN=1` disables) | crash-url, crash-big, paths |
| P1-02 | `coop.partnerLost` (host), guest goes to wait scene when the host leaves and to the map when its own connection ends, 2 s notice | softlock (restart after 2.0 s), host-gone (0.7 s), guest-leave |
| P1-03 | Per-player `hitKey`/`dashKey` (`hitId`/`hitId2`); `+1e6` offset removed. Found by the test: the guest's player dump carried `hitKey` into the host's P2, so `hitKey`/`dashKey` are in the dump skip-list | double-hit (14 → 2), solo-hit |
| P1-04 | Per-key fx ack gating (`coop.fxKeys`), `rAck` reset per level | p2-freeze (150 → 50 ms, together with P1-10) |
| P1-05 | Epoch `e` on start/s/fx; queue is kept across `start`, old/new scenes only eat their own epoch | boss-intro 1-B..5-B all `true` |
| P1-06 | Queue keeps the newest 400, dropped fx still acked, `full` keyframe request + `kf` flag, `away` on `visibilitychange`, P2 shown "away" and invulnerable, no sound burst after a >3 snapshot backlog | background (30 s) |
| P1-07 | Either player can pause for both and either can resume; host re-sends `hs` every 250 ms while paused; guest has a local menu (resume / options / leave co-op); the host menu says "PAUSED BY P2" | pause |
| P1-08 | Guest predicts only real `CRACK` breaks, re-applies unconfirmed breaks after snapshots, no more `bt` spam | bt-spam (34 → 0), crack-dash |
| P1-09 | `L.players()`; rising liquid, blink, crumble, loot magnet, checkpoint heal (both players, and first visit of the partner), guest anti-embed (`_myHold`) | liquid, loot |
| P1-10 | `L._ctx` p1/p2/all: no cross shake/flash/hitstop, partner sounds attenuated by distance, UI sfx never relayed, no double particles for `explode` | fx-ctx |
| P1-11 | `coop.attachPartner`: a friend joining a running level gets the live state, no restart; level ids are now handed out for solo levels too (stable construction order); `pendingAttach` during transitions | late-join |
| P1-12 | 2P button top-centre (smaller on touch), panel closes on connect, ping dot green/yellow/red | screenshot checked |
| P1-13 | Partner has `agents:false` → no sub-agent meter / pop. **Accepted limitation:** P2 has no sub-agents | — |
| P1-14 | `clearInterval(pgT)`, close code 4004 + message, 4003 removed, 6-digit code, 5 failures/60 s lockout (4005), ETag + 304, `immutable` mp3, `no-cache` + gzip page (108 KB gzipped) | cache |

## Notes / deviations
- P1-07 and P1-08 are in one commit, P1-12 and P1-13 in another (edits were made together).
- The `p2-freeze` threshold needed P1-10: the remaining ~100 ms freeze after P1-04 was the host's own hitstop when P2 got hurt.
- Everything must still be play-tested by hand on PC and phone (Huawei Y9s / Firefox) — automated tests ran in headless Chromium only.
