# CLAWD co-op on Cloudflare — report

Branch `claude/clawd-cloud` (from `claude/tender-lovelace-ejlz7m`). `clawd-coop/` untouched: `git diff --stat claude/tender-lovelace-ejlz7m -- clawd-coop/` was empty before every commit.
Not deployed, no PR. `deploy.bat` is ready (never run: no Cloudflare login here).

## What was built
- `src/worker.js`: Worker (routes `/ws` to the Durable Object, `/config`, everything else to static assets) + `class Room` (standard WebSocket API, SQLite-backed, plain JS).
  Host key (4003), lockout (4005, shared by host and guest), code + guest token in storage, guest grace 15 s, **host grace 15 s**, `{"t":"hb"}` every 2 s, silent > 7 s → 4011, 512 KB limit → 1009, `newcode`, dev-only network simulator.
- `public/` = the game (+ `_headers`). Client changes (C2-01..06) only in the co-op module and panel: host key UI, code over the socket, "new code", host auto-reconnect, host watchdog, guest "host reconnecting" state.
- `tools/`: harness runs against `wrangler dev`; new scenarios `host-key host-blip host-half-open host-grace new-code restart`.
- `deploy.bat`, `README.txt`.

## Deviations from the plan (and why)
1. **`wrangler whoami` exits 0 when not logged in** (checked on wrangler 4.148), so the plan's `whoami || login` never logs in. `deploy.bat` greps the output for "You are logged in" instead.
2. **Deploy order:** the docs do not say what `secret put` does for a Worker that does not exist yet. `deploy.bat` deploys first, then sets the secret (only if `HOST_KEY` is missing, or on request). Secrets are separate from `vars`, so later deploys keep them. Unverified here (no account): the user's first run confirms it.
3. **Host resume flag:** the host reconnects with `&resume=1`. With the right key, a resuming host replaces its own old socket instead of getting 4002 (otherwise a half-dead old socket or a close/connect race would give a fatal 4002). A non-resume second host still gets 4002.
4. **`resume:true` to the host only if its seat was really held.** After the grace time (guest already sent to the wait scene) the host gets the normal "friend joined" path and re-attaches the guest; otherwise host and guest would be in different states.
5. **Restart handling:** when the object starts with a stored guest token, it treats the guest seat as in grace; a guest resuming while no host is present gets `{t:'host', lag:true}` and a host-grace timer, not `on:false` (which would kick it out of its level).
6. **No relay-side backpressure.** Server-side Workers `WebSocket` has no `bufferedAmount` (the docs page does not mention it either), so the relay never drops `u:1` messages; the client-side 4 KB rule stays. The simulator's "drop when clogged" part is also gone. Protocol doc (`PROTOCOL.md`, copied) still describes the old relay rule.
7. `GET /index.html` answers 307 → `/` (assets' default html handling). Harmless.
8. Compression is not asserted locally (as the plan says). Verified via docs: `_headers` is supported for static assets (not for Worker-generated responses; we don't generate any); free plan needs SQLite DOs (done), hibernation not required, standard API used, `setInterval` is fine (prevents hibernation, which we do not use), locationHint values as listed in README.
9. Commits: C0-03 and C1-01..06 are **one commit** (the relay was written as one file); C2-01..06 one commit. Tests are per scenario, not per task ID.
10. Test adaptations (no threshold changed): `host-gone` now uses `GRACE_MS=2000` and waits for the grace (old server kicked at once); `cache` drops gzip/br assertions; `diff-lock` asserts public `/config` instead of 403; `late-join` host connects with the host key. (The `late-join` bug was in my first harness edit: it passed the code as the key.)

## Test results (wrangler dev, 50 scenarios per profile)
| profile | full run | failures in the full run |
|---|---|---|
| clean | 48/50 | `host-gone` (old expectation, see 10), `late-join` (harness bug, see 10) |
| SIM_LAG=150 JITTER=60 STALL=5% | 49/50 | `late-join` (same bug) |
| SIM_LAG=300 JITTER=100 STALL=10% BW=8000 | 48/50 | `fx-ctx`, `late-join` (same bug) |

Logs: `reports/logs/{clean,bad,terrible}.log`. The two test bugs were fixed after those runs; the full suites were **not** re-run from scratch afterwards.
Re-runs of each failure alone, 3x each: `late-join` and `host-gone` 3/3 pass on the clean profile and 3/3 on the terrible profile; **`fx-ctx` passed 3/3 alone on the terrible profile** (it failed once in the full run: a visual-flash timing check on a very bad line; looks like test timing, not a relay bug, but it was seen once and I did not find the cause). No threshold was loosened.
New scenarios (all passed on first run, clean): host back after a blip in ~0.5 s, host half-open recovery in ~7.7 s (client watchdog 6 s), `restart` keeps code, token, level.
Old suite from a copy of `clawd-coop/` (so the folder stays untouched): `smoke double-hit blip` pass.

## Measured traffic (for the free limit)
3-B fight, guest standing still: ~19 messages/s into the room (host 16, guest 3). A moving guest adds up to ~30/s, so the README's "~50 msgs/s ≈ 10 h/day" is an upper-bound estimate (idle ≈ 25 h). Limits from the live pricing page: 100,000 requests/day, incoming WS messages 20:1, 13,000 GB-s duration/day.

## Known limits
- One room; region fixed when the room is first created (`LOCATION_HINT` only affects a new `ROOM_NAME`).
- No relay-side backpressure.
- A deploy disconnects everyone (clients reconnect within the grace time).
- Lockout counters are in memory (reset on object restart).
- If `CF-Connecting-IP` is missing (wrangler dev) all clients share one lockout bucket.

## Still to test by hand
PC + Huawei Y9s (Firefox) over the real `workers.dev` link, on Wi-Fi and mobile data, including switching network mid-game; first `deploy.bat` run (login, secret order, `?host` flow); real latency to the chosen region.
