# CLAUDE.md

CLAWD: a 2-player co-op browser platformer. The owner is Zakaria, a vibe coder. **Reply to him in Persian**, short and plain. He plays on a Windows PC (host) with a friend on an Android phone (guest, P2).

## How he plays (do not break these)
- **PC server:** `start.bat` runs `node server.js` on port 3000. It restarts the server when it stops, and when the updater replaces `server.js`.
- **Ways the friend connects:**
  - Usually over the internet: the modem forwards TCP 3000 to his PC. Lowest ping.
  - The same Wi-Fi or hotspot also works.
  - `tunnel.bat` (trycloudflare) is the fallback.
- **Cloudflare relay:** `cloud/worker.js` + `wrangler.jsonc`, deployed with `deploy.bat`. Used when the PC is off.
  - The Durable Object can't be placed in the Middle East; the measured RTT is ~250 ms. The PC server is the main path.
  - `HOST_KEY` is a Cloudflare secret. **Never** put it in code, config or commits.
- **Updates reach him only through `main`.** `update.bat` → `tools/update.ps1`:
  - Downloads the newest `main` commit from GitHub and copies only the changed files.
  - Keeps `coop-config.json`, `node_modules` and `.wrangler`.
  - Every change he should get must be tested, then merged into `main`. Ask him before merging unless he has said to merge.
  - Never commit his public IP or anything personal; the repo is public.

## Layout
| path | what |
|---|---|
| `public/index.html` | The whole game, one file (~7.8k lines). Both servers serve only `public/`. The co-op module is the last script (`// js/coop.js`). |
| `server.js` | PC relay. Same protocol as the worker. |
| `cloud/worker.js` | Cloudflare relay. |
| `tools/coop-harness.js` + `tools/scenarios-*.js` | Playwright two-tab tests. |
| `docs/PROTOCOL.md` | Network protocol. |
| `docs/PLAN-*.md`, `docs/reports/` | History of the work. |

## Co-op architecture (short)
- **Ownership:**
  - The host browser owns the world: creatures, items, tiles.
  - The guest owns its own body: movement, damage it takes, hazards.
  - The guest **announces** its hits with a reliable `hit` event. The host checks them in `hostHit`, with lag compensation via `recordHist` (one second of hurtbox history), and applies them.
- **Envelope:** every game message carries `e` (level epoch), `n` (sequence number) and `ra` (ack).
- **Reliable events:** `coop.rel(k, fields)` assigns `i`, which must be applied once and in order.
  - The channel's own `i` / `k` always win over event fields: a crumble event once used `i` and froze the whole channel.
  - Never name an event field `i` or `k`.
- **State sync:** delta snapshots per class follow the field lists in `NETSPEC`. Run the `netfields` test after adding or changing an enemy.
- **Guest view:** the guest shows the host's world through an interpolation buffer, so it is a bit in the past.
- **Revive rule:** a downed player revives after 6 s (`REVIVE_T`) if the other is alive; both down restarts the level. Deaths and revives are numbered (`dn`, `rg`) and also carried in snapshots, so a lost event corrects itself.
- **Diagnostics:**
  - `?debug` on both pages shows the host's verdict for each P2 hit (`TOO FAR`, `NO SUCH CREATURE`, ...).
  - The `LOG` button has Copy and Download. Guest lines are relayed to the host's log, so one copy from the PC has both sides.
  - A red banner shows when the two pages run different builds (`BUILD` = sum of script lengths).
- **Hosting:**
  - On the PC server, only `localhost` may host, and no key is needed (4004 otherwise).
  - On Cloudflare, hosting needs the host key (4003 if it's wrong).
  - The friend joins with a 6-digit code.

## Testing (before every push)
- Playwright needs Chromium at `/opt/pw-browsers/chromium`.
- `node tools/coop-harness.js <scenario...>`, or `all` for the full suite (~15 min, ~60 scenarios).
  - Bad line: `SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5` before the command.
  - Cloudflare relay: `TARGET=cloud` before the command (uses `wrangler dev`, slower).
- Useful focused scenarios:
  - `smoke`: every level, solo.
  - `soak`: 60 s of drops, pauses, level changes, both directions; `SOAK_S` sets the length.
  - `fight-hits`: a real P2 attacking bosses or slimes; `FIGHT_LV` / `FIGHT_S` set the level and length.
  - `crumble-jam`, `revive`, `revive-lost`, `touch`, `touch-slime`, `debug-log`, `pause-resume`, `blip`, `host-blip`, `cache`.
- A bug fix should come with a scenario that fails on the old code and passes on the new one.
- Known timing-sensitive tests on bad lines: `bufferbloat`, `lenient`, `fx-ctx`. Re-run once before calling them real.
- Keep the brotli page under 120 KB: the `cache` test checks it.
- Kill only the servers you started. `pkill -f "node server.js"` can kill your own shell.

## Godot version (`godot/`, branch `ph1`, served at `/mv/`)
- Godot: `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`. Full check: `bash tools/godot/test-all.sh` (~25 min: unit tests, parity tapes, web export into `public/mv`, browser checks, every co-op scenario incl. a 90 s soak on a bad line). One co-op scenario: `bash tools/godot/coop-test.sh co-<name>`; one unit test: `$GODOT --headless --path godot -- --test=<name>`.
- Co-op rules (details: `docs/metroidvania/07-js-vs-godot.md` §3):
  - State over events: anything that must be right now (music, locks, deaths) is derived each frame or carried in snapshots.
  - Host-side damage to P2 goes through `room.harm_zone` (the guest checks its own body).
  - Every creature field the guest's combat reads goes through `NetClasses.record/apply`; the `parity` test fails otherwise.
  - The partner is seen late: use its recent reports, with limits that grow with ping.
  - A new kind of co-op bug gets a rule in `godot/src/net/watchdog.gd`. Any `INVARIANT` or `SCRIPT ERROR` line fails a scenario.
- Commit the web export (`public/mv`) as its own last commit. Both pages must run the same build (debug overlay line 3; "DIFFERENT BUILDS" notice).

## Style
- Match the game's compact ES2017 style: `G` namespace, no new dependencies, comments explain *why*.
- Windows `.bat` files use CRLF (`.gitattributes`).
- Any `.bat` that may be replaced while running keeps its work on a single line; `update.bat` relies on this.
