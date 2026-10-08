# CLAWD Co-op — Implementation Plan (for the executing agent)

> **خلاصه برای زکریا:** این پلن اجرایی برای Sonnet است و برای دقت بیشتر به انگلیسی نوشته شده.
>
> **ترتیب کار:**
> - فاز ۰: آماده‌سازی و ابزار تست
> - فاز ۱: رفع همه‌ی باگ‌ها، به ترتیب اهمیت
> - فاز ۲: تنظیم سختی (هم Co-op هم تک‌نفره)
> - فاز ۳: لایه‌ی ۱ شبکه
>
> لایه‌ی ۲ (WebRTC) عمداً در این پلن نیست.
>
> **تصمیم‌های تو که در پلن اعمال شده:**
> - پریدن روی دشمن (stomp) مثل قبل با یک ضربه می‌کُشد، حتی وقتی جون دشمن زیاد شده.
> - دشمن پرجون‌تر توکن بیشتری می‌دهد.
> - تنظیمات سختی در تک‌نفره هم وجود دارد.
>
> بعد از هر فاز، Sonnet باید بایستد تا خودت روی PC و گوشی (Huawei Y9s / Firefox) تست کنی.

---

## 0. Rules of engagement (read first)

- **Codebase:** `index.html` (single file, ~6.7k lines, several `<script>` blocks; the co-op module is the last script, headed `// js/coop.js`), `server.js` (Node + `ws`), `start.bat`, `package.json`, `assets/voice/*.mp3`.
- **Line numbers** in this plan refer to the *original* uploaded files. They drift as you edit. Always locate code by the quoted symbol or snippet, not by line number.
- **Style:** keep the existing style (compact ES2017+, IIFE modules, `G` global namespace, no build step, no new dependencies besides `ws`). Do not refactor unrelated code. Do not split `index.html` into several files.
- **Solo play must never regress.** Any co-op hook must be a no-op when `L.net` is `null`.
- **Version control:** run `git init` before the first change. Commit after **each task ID** with message `P1-03: per-player hit ids` etc. Never batch several tasks into one commit.
- **Definition of done for every task:** the task's *Test* passes, the Phase 0 regression smoke test passes, and there are no console errors in host or guest.
- **Stop at the end of each phase** and write a short report: what changed, test results, anything deferred. The user play-tests between phases.
- **Ambiguity:** if something in this plan contradicts the actual code, prefer the smallest change that satisfies the task's *Goal*, and note it in the phase report.

---

## Phase 0 — Setup & test tooling

### P0-1 · git + baseline
- `git init`, add `.gitignore` (`node_modules/`), and commit the untouched code as `baseline`.

### P0-2 · Network simulator in `server.js` (off by default)
**Goal:** reproduce bad internet on one PC.

Add env vars, all defaulting to 0 or off:

| Env var | Meaning |
|---|---|
| `SIM_LAG` | Extra one-way delay in ms, added to every relayed message. |
| `SIM_JITTER` | Random ± ms added to the delay. **Preserve per-direction order:** `due = max(lastDue[dir], now + lag + rand(-j, j))`. |
| `SIM_STALL_PCT` | Per-message chance (0–100) that this direction freezes for `SIM_STALL_MS` (default 400). Every later message in that direction waits too. This mimics TCP head-of-line blocking after a lost packet. |
| `SIM_BW` | Bytes per second cap per direction. Messages queue behind each other, which creates bufferbloat. |

- Implement this inside the relay `ws.on('message')`, using one queue and one timer per direction.
- When any `SIM_*` var is set, print a banner such as `NETWORK SIMULATOR ON: lag 150±60ms, stall 5%`.

### P0-3 · Playwright harness `tools/coop-harness.js`
**Goal:** automated two-tab tests. Not shipped to players.

- Starts `server.js` on a test port with `CODE=1234` (and optional `SIM_*`).
- Opens a **host** tab at `http://localhost:PORT/?mute` and a **guest** tab at `http://127.0.0.1:PORT/?mute`.
- Connects with `G.coop.connect('host','1234')` / `G.coop.connect('guest','1234')`.
- Starts a level with `G.go(() => G.Scenes.play(id, null))`.
- Before page scripts load (`addInitScript`), counts bytes and messages per `t` type by wrapping `WebSocket.prototype.send` and adding a `message` listener.
- **Moving the guest:** dispatch `KeyboardEvent('keydown'/'keyup', {code:'ArrowRight'})` on `window`. Setting `G.input.down` directly does not work, because `input.poll()` overwrites it every step.
- Exposes named scenarios (`node tools/coop-harness.js <scenario>`). Each prints `PASS`/`FAIL` plus numbers.

Scenarios to create now. They must reproduce today's bugs, i.e. they **FAIL** on baseline:

| Scenario | What it does | Expected on baseline |
|---|---|---|
| `crash-url` | `curl /%E0%A4%A` (bad URL) | Server dies. FAIL |
| `crash-big` | A guest socket sends 600 KB | Server dies. FAIL |
| `double-hit` | Freeze the loop: run everything in **one** `page.evaluate`. Put P1 and P2 on the same enemy, set `hp=100`, both with live forward attacks (`atkT=.17, atkLive=true`, distinct `atkId`). Call `L.interact(1/60)` 7×. | `hpLost` = 14. Must be 2. FAIL |
| `softlock` | Host `L.me.die()` while P2 alive, then close the guest tab, wait 6 s. | Host still dead, `reviveQ.length===1`, same level. FAIL |
| `boss-intro` | Host starts `1-B`; after 2.5 s check guest `G.scene.L.me.frozen`. | `false`. Must be `true`. FAIL |
| `bt-spam` | Guest sets `tools.bash` and forces a dash in open air (`dashT=.15, dashDx=1`); count `bt` messages. | 34. Must be 0. FAIL |
| `p2-freeze` | With `SIM_LAG=60`, guest walks back and forth; host spawns a 0-damage projectile on P2; sample `L.p2.x` on host per rAF. | P2 is static ≈250 ms. Must be ≤ 60 ms. FAIL |
| `bandwidth` | Measure KB/s each direction for 6 s: idle in `1-1`, then in each boss `1-B..5-B` after `L.me.frozen=false; L.boss.start()`, keeping both players alive with an interval. | Baseline worst ≈26 KB/s (host→server, 4-B). Record the numbers. |
| `smoke` | **Solo** (no co-op): load every level in `G.LEVELS` for 3 s each. | No `pageerror`. PASS |

Commit. The phase report must list the baseline numbers.

---

## Phase 1 — Fix all bugs (most severe first)

> Tasks marked **(temporary)** get replaced in Phase 3. Keep them small.

### P1-01 · Server must never crash 🔴
- Wrap `decodeURIComponent` in try/catch and answer **400** on failure.
- Add `ws.on('error', …)` on every socket (log only), plus `wss.on('error')` and `server.on('clientError', (e, s) => s.destroy())`.
- **Allow-list served paths**, so traversal like `/assets/../server.js` gets a 404:
  - `/` → `index.html`
  - `/index.html`
  - `^/assets/voice/[a-z0-9_]+\.mp3$`
  - everything else → 404
- **`start.bat`:** run the server in a restart loop (`:loop` … `node server.js` … `timeout /t 2` … `goto loop`). Open the browser only after the server is listening, i.e. let `server.js` open it itself in `listen` callback via `child_process.exec('start "" http://localhost:'+PORT)` when `process.platform==='win32'` and `NO_OPEN` is unset. Remove the `start "" http://localhost:3000` line from the .bat.
- **Test:** `crash-url` and `crash-big` PASS: server still answers `GET /` afterwards and the oversized sender got close code 1009.

### P1-02 · Soft-locks on disconnect 🔴
**Host side.** Add `coop.partnerLost(L)` and call it in both places that today only null `L.net` (the `peer` off handler and `ws.onclose`). It must:
1. If `L.me.dead` and `L.reviveQ` contains an entry for `L.me`, push `'death'` onto `L.events` so the normal fail/restart flow runs.
2. Clear `L.reviveQ`.
3. Then do what the code does today: `L.net = null; L.partner = null; L.p2 = null`.

**Guest side.**
- On `{t:'host', on:false}` while in a guest level: `G.go(() => coop.waitScene())`.
- On `ws.onclose` or **Disconnect** while in a guest level: `G.go(() => G.Scenes.map())`. Also make sure the guest `Play` scene can never stay with `L.net==='guest'` after disconnect.
- Show a 2-second message on the wait/map screen ("host disconnected").

**Test:** `softlock` PASS: within 2 s the host level restarts (new `G.scene.L`). Add a scenario `host-gone`: close the host tab; within 2 s the guest is on the wait or map scene.

### P1-03 · Per-player hit ids 🔴
- Give `Player` two fields: `hitKey = 'hitId'` and `dashKey = 'dashId'`. The host's `p2` gets `'hitId2'` / `'dashId2'`.
- In `Level.interact`, replace `e.hitId` with `e[p.hitKey]` and `e.dashId` with `e[p.dashKey]`.
- Remove the `+1e6` offset for `atkId`/`dashId` in `applyRemote`. It is no longer needed.
- Agents keep their own cooldown logic, so leave them unchanged.
- **Test:** `double-hit` PASS (`hpLost === 2`). Also check one player alone still lands exactly 1 hit per swing.

### P1-04 · P2 freezes on host after an fx (temporary, replaced by P3-03) 🟠
- Keep a map `coop.fxKeys` (key → fx seq). In `sendFx(d)`, record the current seq for every key in `d`.
- In `applyRemote`, skip key `k` only while `coop.fxKeys.get(k) > coop.rAck`; delete stale entries.
- Remove the global gate `if (coop.rHas && coop.rAck >= coop.fxSeq)`. Apply whenever `rHas`.
- Reset `coop.rAck = 0` in `initLevel` (a bug of its own).
- **Test:** `p2-freeze` PASS (static ≤ 60 ms while walking).

### P1-05 · Level epoch: stop the old scene eating the new level's messages 🟠
- **Host:** `coop.epoch++` in `initLevel` (host branch). Put `e: coop.epoch` on every `start`, `s` and `fx` message.
- **Guest:** in the `start` handler, remember `m.e`. Do **not** clear `coop.q`; instead drop queued messages whose `e < m.e`. In `initLevel` (guest branch), set `L._ep = coop.startMsgEpoch`.
- In `guestUpdate`, process queued messages only while `m.e === L._ep`. Stop at the first `m.e > L._ep` and leave it queued. Discard `m.e < L._ep`.
- **Test:** `boss-intro` PASS for all 5 bosses (guest frozen during the intro).

### P1-06 · Queue overflow and background tab 🟠
- **Cap.** When `coop.q.length > 400`, drop the **oldest** messages, not the newest. For each dropped `fx`, still advance `coop.fxAck = max(coop.fxAck, m.q)`. Set `coop.needFull = true`.
- **Keyframe request.** The guest sends `{t:'full', e}` (at most once per second while `needFull`). The host, on `full` for the current epoch, sets `L._net = null`. That makes the next `sendSnap` a complete keyframe, because every per-key cache is empty. Clear `needFull` when the next snapshot is applied.
- **`visibilitychange` on the guest:**
  - *Hidden:* send `{t:'away', on:true}`.
  - *Visible:* clear `coop.q` (keep `start`/`leave` state as-is), set `needFull`, and send `{t:'away', on:false}`.
- **Host on `away`:** set `p2.away = true/false`. While away, `p2.inv = 1` is refreshed every tick, `coop.aimAt` ignores P2, and P2 is drawn at 40 % alpha with "away".
- **Backlog sound burst.** If more than 3 snapshots are applied in one `guestUpdate`, skip the `ev` arrays of all but the last.
- **Test:** add scenario `background`. In the guest, stub `document.hidden` and dispatch `visibilitychange`, and stop guest updates for 30 s by replacing `G.scene.update` temporarily. Then restore. PASS when, within 2 s, the guest's entity set matches the host's (same `_id` list), P2 moves on host again, and the host showed "away" during the pause.

### P1-07 · Pause in co-op 🟠
**Rule: either player can pause for both; either can resume.**

**Host.**
- `coop.setState` must stop mapping `'paused'` → `'play'`.
- While paused, the host `Play.update` returns early, so add `coop.pauseTick(L)` there. It sends `hostState` every 250 ms so the guest learns about the pause.
- Messages `{t:'pz', on}` from the guest put the host into or out of `'paused'`: same as its own pause, with `sel=0`, and the menu title shows "paused by P2".

**Guest.**
- When `hostState.st === 'paused'`: draw a "PAUSED" overlay, set `L.me.frozen = true`, and keep running `guestUpdate` so the queue drains.
- The guest's own pause button opens a **local** menu with these items:
  - *Resume:* sends `pz` off.
  - *Options:* reuse `Options()`.
  - *Leave co-op:* disconnect and go to the map, via P1-02.
- Opening the menu sends `pz` on.

**Test:** scenario `pause`. Host pauses; the guest's `me.frozen` becomes true within 0.5 s, and guest position does not change for 2 s. Guest pause makes the host's state `paused`.

### P1-08 · Guest dash through cracked walls 🟠
Replace the guest override of `L.breakTile`:
- If the tile is not `CRACK`, return `false` **without sending**.
- Otherwise set the tile to `E` locally, play the same burst/sfx as `Level.breakTile`, add the index to `L._predBroken` (Map index → expiry time `L.time + 1`), send `bt`, and return `true`.

In `applySnap`, after rebuilding tiles from `_tiles0 + tl`, re-apply unexpired predicted breaks that are still `CRACK`.

**Test:** `bt-spam` PASS (0 messages in open air). New scenario `crack-dash`: in level `1-1` (or any level with `CRACK` tiles; pick one via `def.map`), place the guest next to a crack and dash into it. PASS if the guest passes through (x keeps increasing past the tile) and the host's tile becomes `E` within 1 s.

### P1-09 · Mechanics that only consider the host 🟡
Add a helper `L.players()` that returns the living players: `[me, p2]` filtered `!dead`, or `[player]` in solo.

| Item | Change |
|---|---|
| a. Rising liquid | Trigger when **any** living player is above `rise.trigger*T`. Catch-up speed uses the **lowest** living player (largest `y + h`). Keep rising if at least one player is alive and not frozen. |
| b. Blink holds | When the phase flips, add holds for **every** player's box. When pruning, keep a hold while **any** player overlaps it. |
| c. Crumble | State-2 tiles stay non-solid while **any** player overlaps them. |
| d. Guest anti-embed | On the guest, keep `L._myHold` (a Set). Each frame, add every `CRUMBLE`/`BLINK_A`/`BLINK_B` tile that overlaps the guest's box and is currently non-solid; remove a tile once it no longer overlaps. Patch `solid()` on the **guest level instance** to return `false` for indices in `_myHold`. |
| e. Loot magnet | Loose items fly toward the **nearest** living player (host: `me`/`p2`). |
| f. Checkpoints | When anyone activates a checkpoint, heal **both** players to `maxHp` (heal `p2` through the normal state/fx path). Also, the first time P2 touches an already-active checkpoint, heal P2 (`c.healed2 = true`). |

**Test:** scenarios `liquid` (pick a level with `def.rise`: host idle at the bottom, guest climbs above the trigger → `L.rising` becomes true) and `loot` (P2 kills an enemy far from host → drops move toward P2). Do (b)–(d) by code review plus a manual note in the report.

### P1-10 · Effect cross-talk 🟡
**Context tags.** Add `L._ctx` with values `'p1'`, `'p2'` or `'all'`.
- Wrap `Player.prototype.update/hurt/hazard/die/onHit/bounce/spring` so that during the call `L._ctx = (this === L.p2) ? 'p2' : (L.net === 'guest' ? 'p2' : 'p1')`, restored afterwards.
- `withFx` also sets `'p2'`.
- Everything else defaults to `'all'`.

**Host.**
- `shake`, `flashScreen` and `stop` are applied locally only if `_ctx !== 'p2'`.
- Every recorded event carries the ctx as its last element.

**Guest replay.**
- Skip `shake`/`flashScreen` events whose ctx is `'p1'`.
- Play `'p1'` sfx at volume × `clamp(1 - dist/320, 0.25, 1)`, where `dist` is the distance between the two players.
- Never relay UI sfx: `uiMove`, `uiOk`, `uiBack`, `pause`, `tick`, `tock`.

**Other.**
- While `explode` runs, set a flag so the nested `ring`/`burst` calls are **not** recorded separately (no double particles).
- On the host, `'p2'` sfx get the same distance attenuation.

**Test:** scenario `fx-ctx`. Hurt host P1 → guest `L.flash` stays 0. Hurt P2 → host `L.flash` and `L.hitstop` stay 0.

### P1-11 · Joining mid-level without restarting 🟡
On `peer` on, if the host is in a `Play` scene, call `coop.attachPartner(L)` instead of `G.go(restart)`. It does the host part of `initLevel`:
- create `p2` at the host position − 8 px
- set `net`, `reviveQ` and counters
- run `ensureIds`
- send `start` with `{ id, snap: L.snapshot(), tools, e: epoch, join: true, spawn: {x, y} }`
- set `L._net = null`, so the first snapshot is a full keyframe

The guest's `initLevel` must use `m.spawn` for its own player when present.

If the host is transitioning, set `coop.pendingAttach = true` and retry from the `G.step` hook once `!G.transitioning()`.

**Test:** scenario `late-join`.
1. Host plays `1-1` alone for 5 s and kills one enemy.
2. Guest joins.
3. Host level object is unchanged (no restart).
4. Within 2 s the guest's enemy `_id` list equals the host's, and the killed enemy is absent on the guest.

### P1-12 · Guest UI on phones 🟡
- Close the 2P panel automatically in `ws.onopen` (both roles).
- The 2P button keeps showing a ping. Color the dot: green < 120 ms, yellow < 250 ms, red otherwise.
- Make sure the button does not overlap the HP pips: move it to the **top-center** or shrink it on `G.mobile`.

### P1-13 · Sub-agents meter for P2 🟡
- The host's `p2.tools = Object.assign({}, G.save.data.tools, { agents: false })`, so `addMeter` is a no-op for P2: no "subagents ready" pop, no meter fx.
- P2 not having sub-agents is accepted for now. Mention it in the report.

### P1-14 · Low-severity bundle 🟢
**Connection hygiene**
- In `coop.connect`, `clearInterval(coop.pgT)` before opening a new socket.
- Host-not-local close: use code **4004** "host must be local", and map it in the UI to "Host only works on the PC running the server".
- Remove the unused 4003 mapping.

**Join code**
- Raise it to 6 digits.
- Rate-limit wrong codes per remote IP (`cf-connecting-ip` or `x-forwarded-for`, falling back to the socket address): after 5 failures in 60 s, refuse for 60 s.

**Caching (saves the friend's data)**
- `.mp3`: `ETag` + `Cache-Control: public, max-age=31536000, immutable`.
- `index.html`: `ETag` + `Cache-Control: no-cache`, answer `304` on `If-None-Match`, and gzip with `zlib` when `Accept-Encoding` includes gzip.
- Cache the gzipped buffer in memory and invalidate it on file mtime change.

**Test:** `curl -I` shows the headers. A second request with `If-None-Match` returns 304. The gzip response is < 120 KB.

**End of Phase 1:** every scenario above PASSes, including `smoke`. Write the phase report with before/after numbers.

---

## Phase 2 — Difficulty settings (solo + co-op)

### Decisions (fixed by the user)
- **Stomp still kills in one hit** regardless of extra HP. Bosses are not stompable, so they are unaffected.
- **Tougher enemies drop more tokens.**
- **Settings exist in solo as well.**

### P2-01 · Settings model
In the save defaults (`opt: { music, sfx, … }`), add flat keys:
```
diffPreset: 'normal', bossPct: 0, npcExtra: 0, npcMult: 100
```
Co-op has its own profile: `G.save.data.coopDiff = { preset:'coop', bossPct:50, npcExtra:0, npcMult:100 }`. Make sure the save loader merges it with defaults the same way `opt` is merged.

**Presets** (choosing one fills the three numbers; editing a number switches the preset to `custom`):

| preset | bossPct | npcExtra | npcMult |
|---|---|---|---|
| easy | 0 | 0 | 100 |
| normal | 0 | 0 | 100 |
| coop | 50 | 0 | 100 |
| hard | 80 | 1 | 100 |
| nightmare | 100 | 2 | 150 |

**Ranges**
- `bossPct`: 0 (off) or 10–100, step 10.
- `npcExtra`: 0–5.
- `npcMult`: 100–300, step 25.

### P2-02 · Central scaler `G.diff`
New small module, placed before the co-op script:
- `G.diff.cfgFor(L)` returns the config to use:
  - the co-op config when `L.net === 'host'`
  - `null` (do nothing) when `L.net === 'guest'`, because the host is authoritative
  - otherwise the solo `opt` values
- `G.diff.scale(e, cfg)`. Idempotent via `e._scaled = true`. Skip entities with `noHit`.
  - **Normal enemy:**
    - `base = e.hp`
    - `e.hp = Math.ceil(base * cfg.npcMult / 100) + cfg.npcExtra`
    - if `e.loot > 0`: `e.loot = Math.round(e.loot * e.hp / base)` (tokens scale with toughness; loot 0 stays 0)
  - **Boss** (`e.isBoss`):
    - `k = 1 + cfg.bossPct / 100`
    - `e.hp = e.maxHp = Math.round(e.maxHp * k)`
    - **Merge boss:** also `h.hp = Math.round(h.hp * k)` for each of `e.heads`. The boss hp is the sum of the heads.
    - Boss death drops: find the `L.drop(..., 24)` calls in the boss code and make them use `Math.round(24 * k)` via a `this.dropN` field, default 24.
- **Where it is applied:** at the start of `Level.update` (host and solo only, never on the guest), loop `for (const e of this.ents) if (!e._scaled) G.diff.scale(e, cfg)`. This one place covers constructor-spawned enemies **and** runtime spawns (Slime split, Leak's slimes, Monolith's bugs). `cfg` is resolved once per level and cached on `L._diff`.
- **Phases and bars:** they use `hp/maxHp` ratios, so they already work. Verify with the Merge boss: `this.hp` must equal the sum of head hp right after scaling.

### P2-03 · Stomp stays a one-hit kill
- In `Level.interact`'s stomp branch, call `e.hit(Math.max(1, e.hp), 0, 1, 'stomp', b)`.
- In Phase 3 the guest-side stomp sends `how:'stomp'`, and the host applies the same rule.

### P2-04 · Solo UI (Options menu)
Extend `Options()` with these rows. They are choice rows: left/right cycles values.

| Row | Values |
|---|---|
| `difficulty` | preset name |
| `boss HP` | `off` / `+10%` … `+100%` |
| `enemy hits` | `+0` … `+5` |
| `enemy HP` | `100%` … `300%` |

- Draw the value right-aligned like the existing toggles.
- Add a dim footer line: "applies from next level / restart".

### P2-05 · Co-op lobby UI + server config
**Host panel (DOM).** Once a friend is connected, show:
- a preset `<select>`
- three `<input type=range>` with live value labels
- values saved to `G.save.data.coopDiff`

**Server.**
- Optional `coop-config.json` or env vars `BOSS_HP`, `NPC_HITS`, `NPC_MULT`, `LOCK=1`.
- New endpoint `GET /config`, **local only**, same check as `/code`, returns JSON.
- When `LOCK=1`, the host UI disables the inputs and the server values win.
- Document the env vars in `README.txt` and add commented examples to `start.bat`.

**Sending settings.** The co-op config travels in every `start` message (`diff: {...}`). The guest's wait screen and the level start show a line like `BOSS +50% · ENEMIES +1 hit`. Settings changed mid-level apply on the next `start`.

### P2-06 · Tests
- **Solo:**
  - set `npcExtra=1` → a Bug needs 2 claw hits but **1 stomp**
  - `bossPct=50` on `1-B` → `maxHp` is 39 (26 × 1.5)
- **Merge (`2-B`) at +100%:** each head hp is 28 and the boss hp is 56; the phase change happens when one head dies.
- **Co-op:**
  - host sets `coop` preset → guest's boss bar matches the host's `maxHp`
  - a runtime-spawned Slime gets scaled exactly once (`_scaled`)
- **Loot:** at `npcExtra=2`, a Bug (base hp 1, loot 1) drops 3 tokens.
- `smoke` still PASSes.

---

## Phase 3 — Network Layer 1 (bad ping + packet loss, still on WebSocket)

> **Targets, measured with the harness at `SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5`:**
> - The guest's own movement and attacks have zero added latency.
> - Enemies and the partner render smoothly: the max per-frame position delta of a walking enemy on the guest is ≤ 3 px at 60 fps.
> - P2 is never frozen > 100 ms on the host.
> - Bandwidth is ≤ 4 KB/s per direction in the worst boss (`4-B`), compared with ≈26 KB/s at baseline.
> - No desync after stalls, background, or 10-second disconnects.
>
> Do the steps in order. Each step keeps the game playable.

### P3-01 · Protocol envelope + reliable/cosmetic event channels
Every game message gets `{t, e: epoch, n: seq}`.

**Reliable events** (things that must never be lost) carry an increasing id:
- damage dealt / taken
- kill, pickup, heal, revive
- checkpoint
- state change
- tile break
- pause

The sender keeps unacked events. The receiver piggybacks `ra` (the highest contiguous id received) on its regular messages. On resume (P3-10), unacked events are resent. Receivers ignore duplicate ids.

**Cosmetic events** (sfx, particles, shake): stamp them with host time `tm`. The guest drops them if they are older than 300 ms when played. Cosmetic events are never resent.

Neither queue trimming nor backpressure (P3-07) may drop reliable events.

### P3-02 · Baseline-ack snapshots + keyframes
Replace the "delta vs last sent" caches (`L._net.e/i/p` + `N.tl/N.cr/...`).

**Host.**
- Keep a ring buffer of the last 32 snapshot states: per entity, the encoded field array from P3-06, plus world fields.
- Each snapshot carries `n` and `b` (baseline seq). It contains only what differs from snapshot `b`, where `b` is the latest seq the guest has acked (`sa` in guest messages).
- If `b` is missing or older than the ring, send a **keyframe** (`b: 0`, everything).
- Also send a keyframe every 5 s, and immediately on a `full` request (this replaces P1-06's `L._net = null` trick).

**Guest.**
- Keep the same ring of reconstructed states: `state(n) = state(b) + delta`.
- If it lacks `state(b)`, request `full`.
- Ignore any snapshot with `n <=` the last applied.

**Effect:** any message can be lost, skipped or trimmed, and the next one still reconstructs correctly. This is also the prerequisite for a future UDP layer.

### P3-03 · Body ownership: the guest owns P2 (removes the fx/ack system)
**Host side**
- `p2` becomes a pure puppet. Apply every field the guest sends. **Delete** `withFx`, `sendFx`, the fx/ack logic, `HOSTOWN` gating for movement fields, and P1-04.
- Host `interact` for `p2` keeps **only**:
  - checkpoints
  - exit
  - item pickups (host stays authoritative so items can't be double-collected)

  On a pickup or checkpoint the host sends reliable `heal`/`meter` events with **deltas**, never absolute hp. The host does **no** damage, hazard, attack or spring logic for P2.
- **Revive:** the host decides it (existing `reviveQ`) and sends reliable `{k:'revive', x, y, hp}`.

**Guest side.** The guest runs, locally on its own body:
- **Hazards:** spikes, liquid (`L.liquidY` from snapshots), pits → `p.hazard()`. Send reliable `{k:'hazard'}` so the host mirrors the hp loss and the "gone" animation.
- **Contact damage** against its locally rendered (interpolated) enemies' `harmboxes()`, skipping `passive`, respecting `grace`, `inv`, `dashT`, using the synced `dmg`. Calls `p.hurt()` locally and sends reliable `{k:'hurt', dmg, srcX}`.
- **Hostile projectiles** from P3-04: on a hit, run `p.hurt()` locally and send `{k:'projHit', pid}`, so the host kills non-piercing ones.
- **Death:** when hp reaches 0, the guest sends reliable `{k:'die'}`. The host calls `p2.die()`, which uses the existing `holdDeath` / `reviveQ` / level-fail flow.
- **Attacks:**
  - The guest detects claw / dash / stomp overlaps against its rendered enemies, using its own per-enemy hit-id bookkeeping.
  - It sends reliable `{k:'hit', eid, how, dmg, dx, dy, atk}` (`atk` = atkId or dashId).
  - It applies its **own** reactions immediately: pogo `bounce`, stomp bounce, air-hit recoil, and clang recoil when a block is visually obvious; otherwise wait.
  - Claw cutting a projectile sends `{k:'cut', pid}`.
- **Host validation** of `hit`:
  - the entity exists and is alive
  - not a `noHit` entity
  - `(eid, atk)` not already applied
  - distance between the enemy and P2's last reported position < 64 px
  - then call `e.hit(...)` with the same arguments the local claw path uses

  Stomp uses `Math.max(1, e.hp)` (P2-03). Kills award meter/loot as today.

**Ownership summary**

| Owner | What it owns |
|---|---|
| Guest | own position, physics, hp/inv/dead, hazards, damage taken, own reactions |
| Host | enemies and their hp, items, tiles, checkpoints/exit, level state, revive decisions |

**Test:** `p2-freeze` must show 0 ms freeze. New scenario `ownership` at `SIM_LAG=150`:
- the guest walks into spikes → the guest teleports to its safe spot **immediately**, with no RTT delay
- the guest stomps a Bug → the guest bounces immediately, and the Bug dies on the host within 400 ms
- no double hp loss

### P3-04 · Projectiles as events
- The host assigns `q.pid` in `Level.shoot`. It sends a reliable `{k:'proj', pid, x, y, vx, vy, g, r, kind, col, life, tile, cut, pierce, dmg, friendly}` on spawn and `{k:'projDead', pid}` when a projectile dies for any reason other than lifetime expiry.
- The guest simulates projectiles exactly like `updateProjs` does (gravity, motion, tile collision, `drip` `onLand` effect, life). No projectile in the game has a custom `update` callback, and nothing mutates projectiles after spawn except `beginDeath`, which kills them all; send `projDead` for each.
- Keyframes include the full projectile list.
- Remove `pj` from regular snapshots.

### P3-05 · Interpolation / jitter buffer
**Guest.**
- For every entity and the host player, keep a buffer of `(tm, fields)` from reconstructed snapshots.
- Render time is `latestTm - D`, where `D = clamp(snapInterval + 2*jitter, 0.08, 0.3)` s, updated smoothly.
- Lerp positional fields (`x, y, hx, hy`, Loop head, etc.) between the two snapshots around the render time. Non-positional fields switch when their snapshot is passed.
- If no newer snapshot exists, extrapolate with `vx/vy` for at most 0.25 s, then hold.
- Replace the current `_sm` offset smoothing on the guest. Keep `Level.draw` clean.

**Host.** Interpolate `p2` the same way, from guest state messages stamped with guest time. Use the guest's own clock delta; no clock sync needed.

**Loop boss:** send only `hx, hy, u, path, cycle…`, not `hist`. The guest appends interpolated head positions to its local `hist` each frame the way the host does.

### P3-06 · Compact encoding
- Replace generic `dump()` with **per-class field lists**: `G.NETFIELDS = { Bug: ['x','y','vx','vy','face','hp','flash','stun',...], ... , Boss subclasses: [...] }`.
  - Include only what the guest needs to **draw**, plus to **interact locally**: `harmboxes`/`hurtboxes` inputs, `passive`, `dmg`, `noHit`, `stompable`.
  - Derive each list by reading each class's `draw()` and `harmboxes()`. Document every list with a one-line comment.
- An entity is encoded as an array in that order, numbers quantized:
  - positions × 4 → int
  - velocities → int
  - timers × 100 → int
  - booleans packed in one int bitfield
- Players use one fixed field list for both directions. Drop purely cosmetic per-frame fields (`sx`, `sy`, `t`, `blinkT`, `runT`, `lookT`, `ghostT`); the receiver re-derives them.
- Send world scalars only on change.
- **Measure.** If `4-B` still exceeds 4 KB/s, switch messages to binary `ArrayBuffer` with a small codec over the same field lists (`Int16` positions, `Uint8` flags), with `?json` as a debug fallback. Do not build binary first.

### P3-07 · Backpressure + adaptive rates
**Client.** Before sending a snapshot or state message, if `ws.bufferedAmount > 4096`, skip it. Reliable events always go: queue them into the next message.

**Server.** In the relay, if `other.bufferedAmount > 16384`, drop non-reliable game messages for that direction. The server can recognize them by a cheap top-level flag `u:1` (unreliable) on snapshot/state messages. Never drop `start`, `leave`, `host`, `peer`, `pz`, or anything carrying reliable events.

**Metrics.** Every 2 s each side computes:
- **RTT** from `pg`/`po`
- **jitter:** the mean absolute deviation of snapshot arrival intervals
- **loss proxy:** the count of skipped seq numbers, plus stalls > 250 ms

**Rates** (host snapshots / guest state):

| Condition | Host snapshots | Guest state |
|---|---|---|
| good | 15 Hz | 30 Hz |
| RTT > 200 ms or jitter > 40 ms | 10 Hz | 20 Hz |
| RTT > 350 ms or stalls | 6 Hz | 15 Hz |

Change rate with hysteresis (stay ≥ 3 s in a level before changing).

### P3-08 · Local hit feedback on the guest
The moment the guest's claw/dash/stomp overlaps a rendered enemy (the same check that sends `hit`), play locally:
- a spark at the contact point
- `hit` sfx (`clang` if `box.armor`)
- a 30 ms hitstop (guest-local `L.hitstop` that only pauses guest-side rendering/physics)

Tag these cosmetic effects so the host's echo of the same hit is **not** replayed on the guest: the host includes the `atk` id in the cosmetic events it records while applying the hit, and the guest drops events whose `atk` it already predicted.

### P3-09 · Lenient rules under bad network
**Host.**
- If no guest message arrives for > 1 s, mark P2 `lagging`: draw it as a ghost, `aimAt` ignores it, and it is excluded from rising-liquid speed and from "both dead" checks.
- After 10 s of lag, behave like away (P1-06).

**Guest.** When its measured RTT > 250 ms or stalls occurred in the last 5 s:
- give itself +0.4 s extra `inv` after each hit
- ignore contact damage from enemies whose interpolated position is extrapolated (no fresh snapshot)

### P3-10 · Resume without restart
**Server.**
- On the first guest connect, issue a random `token` (send `{t:'tok', v}`).
- If the guest reconnects within 15 s with `?token=...`, accept it even if the code changed in between, and tell the host `{t:'peer', on:true, resume:true}`. Do **not** send `peer off` during those 15 s; send `{t:'peer', lag:true}` instead.

**Guest.**
- Auto-reconnect with exponential backoff: 0.5 s, 1 s, 2 s, … up to 15 s.
- Show "reconnecting…" over the game while disconnected (the world keeps rendering, extrapolated or frozen).
- After a resume, if the page was **not** reloaded and the epoch is unchanged: request `full` and resend unacked reliable events.
- If the page was reloaded: go through `late-join` (P1-11).

**Host.** On `resume`, keep `p2` in place (it was `lagging`), with no restart.

**Test:** scenario `blip`. Kill the guest's socket (`G.coop.ws.close()`) mid-boss. The guest is back in the same fight within 3 s, the boss hp is unchanged, and there is no restart.

### P3-11 · Network quality HUD
- A small dot next to each player's HP:
  - green: RTT < 120 and no stalls
  - yellow: RTT < 250
  - red: otherwise
  - grey: lagging
- In the 2P panel: RTT, jitter, stall count over the last minute, current send rate, and KB/s in each direction.

### Phase 3 acceptance (run all at `SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5`, then again at `SIM_LAG=300 SIM_JITTER=100 SIM_STALL_PCT=10 SIM_BW=8000`)
- All Phase 1/2 scenarios still PASS.
- `p2-freeze`: 0 ms.
- `ownership`: PASS.
- `blip`: PASS.
- `background`: PASS.
- `bandwidth`: ≤ 4 KB/s per direction in every boss, and ≤ 1.5 KB/s idle.
- **Smoothness:** scenario `smooth`. Sample a walking Bug's rendered x on the guest per frame for 5 s; the max per-frame delta is ≤ 3 px and there is no frame with delta 0 followed by a delta > 6.
- **Under `SIM_BW=8000`:** RTT stays < 2× `SIM_LAG` after 60 s of boss fight (no bufferbloat spiral).
- `smoke` PASS. Also do a manual solo playthrough of one level and one boss.

**Deferred (do NOT implement):** WebRTC DataChannel (Layer 2), TURN, named Cloudflare tunnel. These are only revisited if the user reports that Phase 3 is not enough on real networks.

---

## Appendix A — Bug ↔ task map (from the original review)

| Review # | Bug | Task |
|---|---|---|
| 1 | Server crash (bad URL / big frame) | P1-01 |
| 2 | Soft-lock on partner disconnect (host and guest) | P1-02 |
| 3 | Double hits (shared `hitId`/`dashId`) | P1-03 |
| 4 | P2 frozen on host after fx | P1-04 → P3-03 |
| 5 | Old scene consumes new level's snapshots | P1-05 (+ P3-02) |
| 6 | Queue overflow / background → permanent desync | P1-06 (+ P3-02, P3-10) |
| 7 | Pause | P1-07 |
| 8 | Guest dash vs cracked walls + `bt` spam | P1-08 |
| 9 | Host-only mechanics (liquid, blink, crumble, loot, checkpoints) | P1-09 |
| 10 | Effect cross-talk + double explode particles | P1-10 |
| 11 | Reconnect restarts the level / join during transition | P1-11 (+ P3-10) |
| 12 | 2P panel covers HUD on phone | P1-12 |
| 13 | P2 sub-agent meter | P1-13 |
| 14 | Low: interval leak, `rAck`, close codes, 4-digit code, path traversal, caching, `start.bat` order | P1-01, P1-04, P1-14 |

## Appendix B — Key code anchors (original file)

| Area | Anchor |
|---|---|
| `server.js` HTTP / WS | `decodeURIComponent(req.url`, `wss.on('connection'` |
| Level core | `class Level {`, `update(dt) {`, `interact() {`, `updateItems(dt) {`, `collect(it) {`, `updateProjs(dt) {`, `breakTile(tx, ty) {`, `shoot(x, y, vx, vy, o) {` |
| Player | `class Player {`, `hurt(d, srcX) {`, `hazard() {`, `die(silent) {`, `onHit(e, res, b) {`, `addMeter(n) {` |
| Enemies / bosses | `class Enemy {`, `hit(d, dx, dy, how) {`, `class Boss extends G.Enemy {`, `class Merge extends Boss {` (`hp: 14` per head), `this.L.drop(this.cx, this.cy, 24)` |
| Play scene | `function Play(id, snap) {`, `if (L.net === 'guest') {`, `state === 'paused'` |
| Options | `function Options(onClose, canErase) {` |
| Save defaults | `opt: { music: 0.7` |
| Main loop | `G.step = (n, quiet) =>`, `function stepTrans(dt)` |
| Co-op module | `// js/coop.js`: `coop.initLevel`, `hostTick`, `applyRemote`, `withFx`, `sendSnap`, `applySnap`, `guestUpdate`, `onMsg`, `coop.connect`, `G.setScene = function`, `const ui = {` |
