CLAWD 2-player

1) Install once:  Node.js (nodejs.org)  and  cloudflared  (open cmd: winget install Cloudflare.cloudflared)
2) Double-click start.bat
   - The game opens on your PC. The black window shows "Friend code: ######".
   - The tunnel window shows a link like https://xxxx.trycloudflare.com  -> send this link + the code to your friend.
3) You: click "2P" (top-left) -> Host.   Friend: opens the link -> types the code -> Join.
4) Pick any level on your PC. Friend joins automatically.
Voices are included (assets\voice).

Notes
- The friend code is 6 digits. 5 wrong tries from one address lock that address out for a minute.
- start.bat restarts the server by itself if it ever stops, and the server opens the browser (set NO_OPEN=1 to stop that).
- Developers: node tools/coop-harness.js all   (Playwright two-tab tests; SIM_LAG / SIM_JITTER / SIM_STALL_PCT / SIM_BW simulate a bad network)

Difficulty
- Options -> difficulty (solo): presets easy / normal / coop / hard / nightmare, or set boss HP, extra enemy hits and enemy HP yourself. Applies from the next level or restart.
  A jump on an enemy always kills it in one hit, and tougher enemies drop more tokens.
- Co-op: once your friend is connected, open the 2P panel to change the co-op difficulty (it has its own saved profile, default "coop": boss +50%).
- Server defaults: set BOSS_HP (0, 10..100), NPC_HITS (0..5), NPC_MULT (100..300) as environment variables (see start.bat) or copy coop-config.example.json to coop-config.json.
  LOCK=1 makes those values final (the host cannot change them).

Bad internet (Phase 3)
- Your body is yours: your friend's movement, jumps, attacks, damage you take and hazards are decided on THEIR screen, so they feel instant even on a slow line.
  The host owns the world (enemies, items, tiles); damage dealt is announced to the host and checked there.
- The host's world is shown to the friend a fraction of a second in the past and smoothed (the delay follows the line quality, 0.08-0.3 s).
- If the line drops, the friend's game keeps the level and reconnects by itself (0.5 s, 1 s, 2 s ... 15 s). The server keeps their seat for 15 s; the fight continues where it was.
- Two small dots next to the hit points show the line: green < 120 ms, yellow < 250 ms, red worse, grey = that player is not answering.
  The 2P panel shows ping, jitter, stalls per minute, send rate and KB/s.
- Typical traffic: about 1-3.5 KB/s per direction (it was up to 27 KB/s).
- Testing a bad line on one PC:  set SIM_LAG=150 SIM_JITTER=60 SIM_STALL_PCT=5   (and SIM_BW=8000 for a narrow line)  before  node server.js
