# CLAWD co-op — network protocol (layer 1, WebSocket)

Transport: one WebSocket per player to `server.js`, which only relays text frames between the **host** (the PC that runs the server) and one **guest**.
All game messages are JSON.

## Who owns what
| Owner | What |
|---|---|
| Guest | its own body: position, physics, hit points, hazards (spikes/liquid/pits), contact damage, attacks, deaths |
| Host | creatures and their hit points, items, tiles, checkpoints/exit, level state, revives, the partner-independent clock |

Damage **dealt** by the guest is only announced (`hit` event); the host checks it (target exists, not already hit by this attack, partner is within reach) and applies it.

## Envelope (every game message)
`{t, e, n, ra, u?, r?}`

* `t` type, `e` level epoch (increments on every level start; messages of other epochs are ignored), `n` message counter (gaps = loss), `ra` highest reliable event id received so far.
* `u:1` — the relay may drop this message when the receiver is clogged (snapshots, body reports). Messages that carry reliable events never have it.
* `r` — reliable events `[{i, k, ...}]`. The sender keeps every event until it is acknowledged (`ra`) and re-sends all unacknowledged ones in the next message once the oldest is >220 ms old. The receiver applies id `hi+1` only (in order, once). A keep-alive `{t:'ack'}` carries events when the game loop is not running (background tab, pause).

## Host → guest
| message | content |
|---|---|
| `start` | `{id, snap, tools, e, diff, join?, spawn?}` start (or join) a level |
| `leave`, `cfg {diff}`, `hs {hs}` (pause heartbeat) | control |
| `s` snapshot | `{sn, b, tm, kf?, w, tl, cr, bh, ei, ii, ph, hs, en, eu, in, iu, p, pjk?, lt?, ev?}` — delta against snapshot `b` (the last one the guest acknowledged with `sa`); `b:0` = keyframe (every 5 s, on request `full`, or when the baseline is missing); `tm` host clock |
| reliable | `proj`/`projDead` (hostile projectiles), `heal {n, safe?}`, `revive {x,y,hp}` |

Entities are arrays of quantised numbers in the order of the class field list (`NETSPEC` in `index.html`); `en`/`in` = new `[id, classIdx, ctorArg, ...values]`, `eu`/`iu` = changed `[id, idx, value, idx, value...]`. Types: `p` ¼-pixel, `v` px/s, `t` 1/100 s, `u` 1/10 s, `h` 1/10 hp, `f` 1/100, `n` int, `b` flag, `s` string, `o`/`a` object / list of objects (listed keys).
Hazards that only depend on the level clock (pendulum, gear, fire jet) are not sent; every screen runs them. Boss trails, the Loop's body history, animation clocks are rebuilt locally.

Cosmetic events (`ev`: sounds, particles, shake) carry who caused them (`p1`/`p2`/`all`, `p2#w12` = echo of the partner's swing no. 12) and are played when the guest's render clock reaches their `tm`; events older than 300 ms are dropped.

## Guest → host
| message | content |
|---|---|
| `st` | `{d:[idx,val,...], sa, gt}` body report (sparse delta of the fixed player field list), `sa` = last snapshot applied, `gt` guest clock |
| `full {e}` | please send a keyframe |
| reliable | `hit {eid, how: swipe\|dash\|stomp, dmg, dx, dy, atk, bi}`, `cut {pid}`, `projHit {pid}`, `hurt {x,y,d}`, `hazard {x,y}`, `die {x,y,silent}`, `bt {tx,ty}` (cracked wall), `cr {i,v}` (crumble), `pz {on}` (pause), `away {on}` |

## Timing
* Guest shows the host's world at `render time = now − offset − D`, `D = clamp(snapshot interval + 2·jitter, 0.08, 0.3)`; positions are blended between the two surrounding snapshots, extrapolated with the last speed for ≤0.25 s, then held. After a stall the picture catches up at a limited speed instead of lurching.
* Host shows the partner the same way (delay 0.05–0.25 s) from the guest's reports.
* Rates: good 15 Hz host / 30 Hz guest; RTT>200 ms or jitter>40 ms 10/20 Hz; RTT>350 ms or stalls 6/15 Hz (≥3 s between changes).
* Sends are skipped when the socket buffer exceeds 4 KB; the relay drops `u:1` messages when the receiver has >16 KB queued.

## Connection
* The relay keeps the guest's seat for 15 s after a dropped line (`{t:'peer', lag:true}` to the host) and gives out a token (`{t:'tok'}`); the guest reconnects with the token (0.5 s … 15 s backoff) and the host gets `{t:'peer', on:true, resume:true}`: nothing restarts, unacknowledged events are re-sent, a keyframe follows.
* Explicit disconnect uses close code 4010 (leave at once). 4001 wrong code, 4002 host exists, 4004 host must be local, 4005 too many wrong codes.
