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
