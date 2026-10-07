# CLAWD Co-op on Cloudflare — Implementation Plan (for the executing agent)

> **خلاصه برای زکریا:** این پلن اجرایی برای Sonnet است و برای دقت بیشتر به انگلیسی نوشته شده.
>
> **هدف:** رله‌ی بازی روی Cloudflare اجرا شود (Workers + Durable Objects، پلن رایگان). تو و دوستت فقط یک لینک ثابت باز می‌کنید. دیگر نه `start.bat` لازم است، نه `cloudflared`، نه روشن ماندن سرور روی PC.
>
> **بکاپ:** همه‌ی کار در پوشه‌ی جدید `clawd-cloud/` و روی شاخه‌ی جدید انجام می‌شود. پوشه‌ی `clawd-coop/` (نسخه‌ی فعلیِ سالم) حتی یک بایت هم تغییر نمی‌کند. اگر نسخه‌ی ابری خوب کار نکرد، نسخه‌ی قبلی دست‌نخورده سر جایش است.
>
> **ترتیب کار:**
> - C0: کپی، ساختار پروژه، اجرای محلی با `wrangler dev`
> - C1: رله در Durable Object (همان رفتار `server.js`)
> - C2: تغییرات کلاینت (کلید هاست، کد، اتصال دوباره‌ی هاست)
> - C3: تست‌ها روی `wrangler dev`
> - C4: deploy (این مرحله را خودت روی PC انجام می‌دهی) و راهنما
>
> **کار تو در آخر:** یک بار `deploy.bat` را اجرا می‌کنی (لاگین Cloudflare در مرورگر، تعیین کلید هاست). لینک `https://clawd-coop.<اسم-تو>.workers.dev` را برای دوستت می‌فرستی.

---

## 0. Rules of engagement (read first)

- **Never modify `clawd-coop/`.** It is the working backup. All new work goes into a new folder `clawd-cloud/`. Acceptance check at the end of every phase: `git diff --stat <base> -- clawd-coop/` must print nothing.
- **Branch:** start from `claude/tender-lovelace-ejlz7m` (it contains Phases 0–3 plus the four review fixes; after PR #1 is merged, `main` is equivalent). Work on your own session branch. Commit after each task ID (`C1-03: host grace`). Never batch several tasks into one commit.
- **Read first:** `clawd-coop/PROTOCOL.md`, `clawd-coop/server.js`, and the co-op module in `clawd-coop/index.html` (last `<script>`, `// js/coop.js`). The cloud relay must behave exactly like `server.js` unless this plan says otherwise.
- **Style:** same as the game: compact ES2017+, no build step, no framework. Only one new dependency: `wrangler` (dev dependency). The Worker is plain JavaScript (ES modules), not TypeScript.
- **Game logic stays in the browser.** The host's browser simulates the world, and the relay only forwards messages. Do not move game logic to the server.
- **Free plan only.** Durable Objects on the free plan must be **SQLite-backed** (`new_sqlite_classes` in the migration). Do not use anything that needs a paid plan.
- **CPU budget:** the relay forwards about 50 messages/s. Do **not** `JSON.parse` relayed game messages. Inspect them with cheap string checks only, as `server.js` does (`text.endsWith(',"u":1}')`). Parse only the few small control messages the relay itself handles.
- **Verify platform facts against the live Cloudflare docs** (developers.cloudflare.com) before relying on them. This plan was written in October 2026, and the following can change: free limits, `_headers` support for static assets, `locationHint` values, and the WebSocket API surface. If a fact is wrong, choose the smallest change that still meets the goal, and record it in the report.
- **Definition of done for every task:** its test passes, `smoke` passes, and there are no console errors in host or guest.
- **Report:** at the end, write `clawd-cloud/reports/cloud.md` covering what changed, the test results, and anything that differs from this plan.

---

## Phase C0 — Project skeleton

### C0-01 · Copy
- Create `clawd-cloud/public/` and copy into it `clawd-coop/index.html` and `clawd-coop/assets/` (46 voice mp3s, 2.7 MB).
- Copy `clawd-coop/tools/` to `clawd-cloud/tools/`, and copy `PROTOCOL.md`.
- Do **not** copy `server.js`, `start.bat` or `coop-config*.json`. They are replaced.
- From now on, edit only the copies under `clawd-cloud/`.

### C0-02 · Wrangler project
```
clawd-cloud/
  package.json        { "private": true, "scripts": { "dev": "wrangler dev", "deploy": "wrangler deploy" }, "devDependencies": { "wrangler": "^4" } }
  wrangler.jsonc
  src/worker.js       Worker entry + Durable Object class Room
  public/             static files (index.html, assets/voice/*.mp3, _headers)
  tools/              test harness (adapted in C3)
  deploy.bat          one-click deploy for Windows (C4)
  README.txt
  .gitignore          node_modules/  .wrangler/  .dev.vars
```

`wrangler.jsonc` (set `compatibility_date` to the day you create it; check `wrangler init` or the docs for the current key names):
```jsonc
{
  "name": "clawd-coop",
  "main": "src/worker.js",
  "compatibility_date": "YYYY-MM-DD",
  "assets": { "directory": "./public", "binding": "ASSETS" },
  "durable_objects": { "bindings": [{ "name": "ROOM", "class_name": "Room" }] },
  "migrations": [{ "tag": "v1", "new_sqlite_classes": ["Room"] }],
  "vars": { "BOSS_HP": "", "NPC_HITS": "", "NPC_MULT": "", "LOCK": "", "ROOM_NAME": "main", "LOCATION_HINT": "" }
}
```
- **Secret `HOST_KEY`:** set with `wrangler secret put HOST_KEY`. Never put it in `wrangler.jsonc` or commit it. For local dev it goes in `.dev.vars` (git-ignored): `HOST_KEY=test`, `CODE=123456`.
- **`public/_headers`:**
  ```
  /assets/voice/*
    Cache-Control: public, max-age=31536000, immutable
  /
    Cache-Control: no-cache
  /index.html
    Cache-Control: no-cache
  ```
  Cloudflare already handles ETag, 304 and brotli/gzip for static assets. If `_headers` is not supported for Workers static assets, set these headers in the Worker instead.

### C0-03 · Worker routing (`src/worker.js`)
- `GET /ws` with `Upgrade: websocket` → forward to the room's Durable Object:
  - `const id = env.ROOM.idFromName(env.ROOM_NAME || 'main')`
  - `env.ROOM.get(id, env.LOCATION_HINT ? { locationHint: env.LOCATION_HINT } : undefined).fetch(request)`
- `GET /config` → JSON `{bossPct, npcExtra, npcMult, lock}` from the env vars, using the same `pick()` rules as `server.js` (empty string → `null`).
  - The old server served this to localhost only. That is no longer needed: the values are not secret, and `lock` is enforced by the host UI exactly as before.
- Every other request → `env.ASSETS.fetch(request)`. Static assets are normally matched before the Worker runs, so this is only a fallback.
- **One room only:** this is a game for two friends, so there is one room. That keeps the design identical to `server.js`: one host, one guest, one code. `ROOM_NAME` exists so the user can start a fresh room (a new name gets a new Durable Object).
- **Note on placement:** a Durable Object is placed near whoever first creates it, and its location is then fixed. `LOCATION_HINT` (for example `enam`, `weur`, `eeur`; check the docs for valid values) lets the user choose a region between the two players. Changing it only affects a **new** `ROOM_NAME`.

**Test:** `npx wrangler dev` → `http://localhost:8787/` shows the game, the mp3s load, `/config` returns JSON, and `smoke` (solo) passes against it (see C3-01).

---

## Phase C1 — The relay as a Durable Object

Port `clawd-coop/server.js` (the parts after the static-file code) into `class Room` in `src/worker.js`. The differences below are forced by the platform or by the cloud.

### C1-01 · Accepting sockets
- In `Room.fetch(req)`: create a `WebSocketPair`, call `server.accept()`, and return `new Response(null, { status: 101, webSocket: client })`.
- **Use the standard API, not the Hibernation API.** The room keeps in-memory state, timers and an ordered relay, and it is only awake while somebody is connected. Duration on the free plan is plenty for two players.
  - If the docs say hibernation is required on the free plan, switch, keeping every per-socket field in `serializeAttachment` and the room state in storage.
- **Client address for the lockout:** the `CF-Connecting-IP` header. The Worker passes the original request through, so the header is present.
- **Max payload:** reject messages larger than 512 KB by closing with **1009**, the same as `maxPayload` today. Check `typeof data === 'string' ? data.length : data.byteLength`.

### C1-02 · Roles and authentication (replaces "host must be local")
The old rule "the host must connect from localhost" cannot work in the cloud. Replace it with a host key:
- **Host:** `/ws?role=host&key=KEY`. Compare against `env.HOST_KEY` in constant time (compare all characters). If `HOST_KEY` is empty or unset, refuse every host.
  - A wrong key closes with **4003** "wrong host key" and counts as a failure for the IP lockout (same 5 failures / 60 s rule).
  - A second live host closes with **4002**, as before.
- **The code:**
  - The 6-digit `CODE` is generated once and stored in `ctx.storage` (key `code`), so it survives restarts of the object. `env.CODE`, if set (dev/tests only), overrides it.
  - On host connect, the room sends `{t:'code', v:CODE}` to the host. This replaces the old `GET /code`.
  - A host can ask for a new code with the control message `{t:'newcode'}`. The room then generates a new code, stores it, replies with `{t:'code', v}`, and kicks the current guest with **4001**.
- **Guest:** `/ws?role=guest&code=CODE[&token=TOKEN]`. The rules are the same as `server.js`:
  - lockout check, then wrong code → 4001
  - token resume when the token matches while in grace, **or** while the old guest socket is still held
  - replacing an old guest → 4000
  - `{t:'tok'}`, `{t:'host', on}`, and `{t:'peer', on[, resume]}` to the host
- **Persist the guest token** in storage too (`guestTok`), so a guest can resume after the object restarts.

### C1-03 · Relay + droppable messages
- **Forwarding:** host → guest and guest → host, order preserved.
- **Control messages the relay handles itself:** `{"t":"newcode"}` from the host, and nothing else. Recognise them by an exact string compare or a short prefix check. Everything else is forwarded untouched.
- **Backpressure:** `server.js` drops `u:1` messages when `bufferedAmount` is over 16 KB. Workers' server-side `WebSocket` has **no `bufferedAmount`**; check the docs, and use it if it now exists. Otherwise, remove the relay-side drop. The client-side backpressure (`ws.bufferedAmount > 4096` → skip snapshots and reports) stays, and that is the important half.
  - Document this in the report.

### C1-04 · Heartbeat (replaces ws ping/pong)
- Workers do not expose WebSocket ping/pong events, so use an application-level heartbeat with the same timings:
  - Every 2 s, the room sends the exact string `{"t":"hb"}` to each open socket. The client already ignores it and uses it for its 6-second watchdog.
  - The room records `lastSeen` per socket on **every** incoming message. Clients send `pg` every 2 s anyway.
  - A socket silent for **> 7 s** is closed with **4011** "silent" and treated exactly like a dropped line (guest → grace; host → host grace, C1-05).
- **Timers:** use `setInterval` while at least one socket is open, and clear it when the last socket closes, so an empty room costs nothing.
  - If timers turn out not to survive in a Durable Object, use `ctx.storage.setAlarm()` for the 2 s tick instead.

### C1-05 · Host grace (new, needed because the host now uses the internet too)
Today the host is on localhost and never drops. In the cloud it can drop like the guest, so give it the same treatment:
- **Host socket closes** (not an explicit leave, not a replacement):
  - hold the host seat for **15 s** (`GRACE_MS`, env-overridable for tests)
  - send the guest `{t:'host', lag:true}` (new message)
- **Host returns** within the grace period with the right key:
  - send the guest `{t:'host', on:true, resume:true}`
  - send the host `{t:'peer', on: !!guest, resume:true}`
- **Grace expires:** send the guest `{t:'host', on:false}`. The existing guest behaviour then applies: back to the wait scene.
- **Explicit host disconnect:** the client closes with **4010**. No grace; `{t:'host', on:false}` immediately.

### C1-06 · Dev-only network simulator
- Port the `SIM_LAG / SIM_JITTER / SIM_STALL_PCT / SIM_STALL_MS / SIM_BW` lanes from `server.js` (same scheduling, order preserved), but **only active when the vars are set in `.dev.vars` or passed with `--var`**. In production they are unset, and the relay must not schedule anything.
- Without `bufferedAmount`, skip the "drop `u:1` when clogged" part of the simulator.
- Print the same banner (`NETWORK SIMULATOR ON: …`) on the first connection when it is on.

**Tests:** see C3. At minimum, the ported server scenarios plus `blip`, `grace`, `half-open` and the new `host-blip` and `host-key`.

---

## Phase C2 — Client changes (`clawd-cloud/public/index.html` only)

All changes are in the co-op module and the 2P panel. Do not touch game code.

### C2-01 · Who may host
- The old rule `const host = location.hostname === 'localhost' || …` shows the Host button. Replace it:
  - The Host button is shown when `localStorage['clawd.hostKey']` exists, or when the URL has `?host`.
  - Wrap every `localStorage` access in try/catch.
- **First click on Host** with no key saved: show an input "host key" plus an OK button in the panel. Use the panel's DOM, not `prompt()`, because `prompt()` is ugly and blocked in some mobile browsers. Save the key, then connect.
- `coop.connect('host', key)` → URL `/ws?role=host&key=…`.
  - On close code **4003**, delete the saved key and show "wrong host key".
- The friend's flow stays the same: open the link, type the code, Join. The panel already opens automatically for non-hosts, so the URL-param check only changes who sees the Host button.

### C2-02 · The code comes over the socket
- Remove `fetch('/code')`. On `{t:'code', v}`, show `v` in `#cShow`. `coop.fetchCfg()` stays (`/config` exists).
- **"New code" button:** next to the code, in the host panel, while connected. It sends `{t:'newcode'}` with the plain `send()`, not `gsend()`.

### C2-03 · Close codes and messages
- `FATAL` becomes `{4000, 4001, 4002, 4003, 4005, 4010}`. 4004 no longer exists; 4011 is **not** fatal (a silent line → reconnect).
- Status texts:
  - 4003 "wrong host key"
  - remove the 4004 text
  - 4011 is handled like a drop: "connection lost – reconnecting"

### C2-04 · Host auto-reconnect (counterpart of C1-05)
Mirror the guest's P3-10 logic for the host:
- **Host socket closes** with a non-fatal code:
  - Do **not** call `partnerLost`. Keep `L.net`, `L.p2`, the epoch and the reliable queue.
  - Mark `coop.reconnecting = true`, show "reconnecting…", and retry with backoff 0.5 s … 15 s using the saved key.
  - While reconnecting, the host's game keeps running.
- **On `{t:'peer', on:true, resume:true}` after a resume:**
  - set `coop.peer = true` and `coop.kfNext = true`, so the next snapshot is a keyframe
  - unacked reliable events go out with the next message, as today
- **Grace expires** (the reconnected host gets `peer on:false`, or the reconnect is refused): call `partnerLost` as today.
- **Guest side**, on `{t:'host', lag:true}`:
  - show "host reconnecting…" and grey out the partner (`L.partner.lagging = true` on the guest)
  - keep the level
- **Guest side**, on `{t:'host', on:true, resume:true}`: clear that state and request a keyframe (`coop.needFull = true`).

### C2-05 · Watchdog for the host too
The 6 s silence watchdog in the `pgT` interval currently runs only for `role === 'guest'`. In the cloud the host needs it too: run it for both roles. For the host, firing it starts C2-04.

### C2-06 · Texts
- README / panel texts that mention the PC, `start.bat`, the tunnel or "localhost" must be updated for the cloud.
- The panel text "waiting for your friend (give them the link and code)" stays.

---

## Phase C3 — Tests on `wrangler dev`

### C3-01 · Harness target
- `tools/coop-harness.js`, `startServer()`: spawn `npx wrangler dev --port <p> --ip 127.0.0.1` with:
  - `--var CODE:123456 --var HOST_KEY:test --var GRACE_MS:<n>`
  - and the `SIM_*` vars passed through as `--var` when they are set in the environment
- Wait for wrangler's "Ready on" line (allow up to 60 s on the first run).
- Use a fresh `--persist-to <tmpdir>` per server start, so stored codes and tokens don't leak between scenarios.
- `openPair()`:
  - **Host:** `G.coop.connect('host', 'test')`.
  - **Guest:** unchanged.
  - Both pages can now use `localhost`. The `127.0.0.1` trick for "host must be local" is no longer needed, but it does no harm.
- **Chromium:** `executablePath: '/opt/pw-browsers/chromium'`, as today.

### C3-02 · Which scenarios apply
- **Run unchanged:** every game scenario from Phases 1–3 and the review fixes:
  - `double-hit … late-join`
  - `diff-*`
  - `reliable … grace`
  - `p2-freeze`, `bandwidth`, `smoke`
  - `pause-resume`, `pause-proj`, `half-open`, `zombie`
- **Replace the server scenarios:**
  - `crash-url` → bad URL `/%E0%A4%A` returns 400 or 404 and the room keeps working afterwards.
  - `crash-big` → a 600 KB guest message closes that socket with 1009 and the room keeps working.
  - `paths` → `/server.js`, `/src/worker.js`, `/wrangler.jsonc` and `/.dev.vars` are all 404.
  - `cache` → `/assets/voice/nar_title.mp3` has `immutable` and the page has `no-cache`. 304 on `If-None-Match`, and the lockout codes as before.
    - Note that compression on `wrangler dev` may differ from production, so do not assert brotli locally.
- **New scenarios:**
  - `host-key`:
    - a wrong key → 4003
    - five wrong keys from one address → the sixth try gets 4005 even with the right key
    - an empty `HOST_KEY` refuses all hosts
  - `host-blip`:
    - mid-boss (`3-B`), kill the host's socket (`G.coop.ws.close()`)
    - within 3 s the host is back: same level object, same `p2`, guest still in the same fight
    - the boss hp is identical on both sides, and a reliable event raised during the outage arrives
  - `host-grace`: with `GRACE_MS=2000`, close the host page → within 1 s the guest shows "host reconnecting" (`lag`); after the grace period the guest is on the wait scene.
  - `new-code`:
    - the host sends `newcode` → the guest is kicked with 4001
    - the old code no longer works; the new one does
  - `restart`:
    - restart `wrangler dev` with the same `--persist-to`
    - both clients reconnect by themselves within 20 s, the code is unchanged, and the guest resumes with its token
    - this checks the C1-02 storage
- **Network profiles:** run all scenarios on the three lines (clean; `SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5`; `SIM_LAG=300 SIM_JITTER=100 SIM_STALL_PCT=10 SIM_BW=8000`).
  - Report every failure, and re-run each failing scenario at least 3 times alone to separate test timing from real bugs.
  - Known timing-sensitive checks: `lenient` and the `bufferbloat` maximum on jittery lines. Do not loosen a threshold to make a test pass without saying so in the report.

### C3-03 · Backup check
- `git diff --stat <base> -- clawd-coop/` prints nothing.
- The old `clawd-coop` suite still passes from its own folder: `cd clawd-coop && node tools/coop-harness.js smoke double-hit blip`.

---

## Phase C4 — Deploy + guide (the user runs this; you prepare it)

You cannot log into the user's Cloudflare account. Prepare everything so that it is one double-click for them.

### C4-01 · `deploy.bat` (Windows)
```
@echo off
cd /d %~dp0
if not exist node_modules ( echo Installing... first time only & call npm install )
call npx wrangler whoami >nul 2>nul || call npx wrangler login
echo.
echo Set (or change) the HOST KEY - only you need it, it lets your browser be the host.
call npx wrangler secret put HOST_KEY
call npx wrangler deploy
echo.
echo Done. Open the link above ending in .workers.dev once with ?host at the end, enter your host key, and send the plain link + the code to your friend.
pause
```
- Check the exact `wrangler secret put` behaviour on a first deploy. If the Worker must exist first, run `wrangler deploy` before `secret put` and once more after it.
- **Free plan only:** if `wrangler deploy` complains about Durable Objects, the cause is almost always a missing `new_sqlite_classes` migration. Mention this in the README.

### C4-02 · `README.txt` (short, for Zakaria and the friend)
1. **One-time setup:** install Node.js, create a free Cloudflare account, double-click `deploy.bat`, log in when the browser opens, and choose a host key.
2. **You:** open `https://clawd-coop.<you>.workers.dev/?host`, then 2P → Host → enter the host key (it is remembered). The panel shows the 6-digit code.
3. **Friend:** opens `https://clawd-coop.<you>.workers.dev`, types the code, Join.
4. **Updating after a change:** run `deploy.bat` again (it is safe to repeat).
5. **Choosing the server region:** set `LOCATION_HINT` (for example `weur`) **and** a new `ROOM_NAME` in `wrangler.jsonc`, then deploy again.
6. **Free limits, roughly:**
   - About 100,000 Durable Object requests per day. Incoming WebSocket messages count 20:1, so about 50 msgs/s of play ≈ 2.5 requests/s, which is roughly **10 hours of co-op per day**.
   - If a limit is hit, the connection fails until 00:00 UTC.
   - Check the current numbers on Cloudflare's pricing page.
7. **Fallback:** the old way (`clawd-coop/start.bat` + tunnel) still works, unchanged.

### C4-03 · Report
Write `clawd-cloud/reports/cloud.md`:
- what was built
- deviations from this plan (with the doc link that forced them)
- test results per network profile, with re-runs
- known limits:
  - no relay-side backpressure (if that is the case)
  - one room
  - region fixed at the room's creation
- what the user must still test by hand: PC + Huawei Y9s (Firefox) over the real `workers.dev` link, on Wi-Fi and on mobile data, including switching network mid-game

---

## Appendix — Mapping from `server.js`

| `server.js` | Cloud |
|---|---|
| static files, ETag, gzip/brotli, `immutable` mp3 | Workers static assets (`public/`) + `_headers` |
| `GET /code` (local only) | `{t:'code'}` over the host's socket; the host is authenticated by `HOST_KEY` |
| `GET /config` (local only) | `GET /config` (public, values are not secret) |
| `isLocal()` host check, 4004 | host key check, 4003 |
| `maxPayload` 512 KB → 1009 | manual size check → close 1009 |
| relay drops `u:1` when `bufferedAmount` > 16 KB | not available on Workers (unless the docs say otherwise); client-side backpressure stays |
| ws ping/pong + `{"t":"hb"}` every 2 s, 3 missed pongs = dead | `{"t":"hb"}` every 2 s; socket silent > 7 s = dead (4011) |
| guest grace 15 s + token (in memory) | same, with code and token in Durable Object storage |
| host on localhost, never drops | host grace 15 s + host auto-reconnect (C1-05, C2-04) |
| `SIM_*` simulator | same, dev-only (`.dev.vars` / `--var`) |
| `start.bat` restart loop + `cloudflared` | not needed; `deploy.bat` |
