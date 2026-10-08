# Test harness (developers only, not shipped to players)

```
npm i playwright            # once; Chromium is expected at /opt/pw-browsers/chromium (or edit executablePath)
node tools/coop-harness.js all                 # every scenario
node tools/coop-harness.js ownership blip      # some of them
SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5 node tools/coop-harness.js all           # on a bad line
SIM_LAG=300 SIM_JITTER=100 SIM_STALL_PCT=10 SIM_BW=8000 node tools/coop-harness.js all   # on a terrible line
BW_DETAIL=1 BW_MOVE=1 node tools/coop-harness.js bandwidth                          # per-field traffic, guest running around
```

`TARGET=cloud node tools/coop-harness.js all` runs the same suite against `wrangler dev` (cloud/worker.js) instead of `node server.js`.

Each scenario starts its own relay server on a free port (`CODE=123456`, host key `test`) and, for co-op tests, two browser contexts (host on `localhost`, guest on `127.0.0.1`).
The harness counts every WebSocket message per type and direction (`window.__net`).

| group | scenarios |
|---|---|
| server | `crash-url crash-big paths cache` |
| bugs (phase 1) | `double-hit solo-hit softlock host-gone guest-leave boss-intro bt-spam pause crack-dash liquid loot fx-ctx late-join background` |
| difficulty (phase 2) | `diff-solo diff-boss diff-merge diff-loot diff-coop diff-lock` |
| network (phase 3) | `reliable lossy ownership guest-fight projectiles hitfeel smooth rates bufferbloat lenient blip grace netfields p2-freeze bandwidth` |
| review fixes | `pause-resume pause-proj half-open zombie revive revive-lost touch touch-slime` |
| relay | `host-blip host-half-open host-grace new-code`, `host-local` (PC relay only), `host-key restart` (cloud only) |
| controls | see `scenarios-controls.js` |
| solo | `smoke` (every level, 3 s of scripted input, no page errors) |

`netfields` checks that the per-class field lists in `index.html` (`NETSPEC`) cover every property that `draw()` / `hurtboxes()` / `harmboxes()` reads and that changes while a creature lives. Run it after adding or changing an enemy.
