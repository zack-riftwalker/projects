CLAWD co-op on Cloudflare
=========================
The relay runs on Cloudflare (a Worker + one Durable Object, free plan). You and your friend only open a fixed link.
No start.bat, no tunnel, and your PC does not need to stay on.

ONE-TIME SETUP
 1. Install Node.js (LTS) from https://nodejs.org
 2. Create a free Cloudflare account at https://dash.cloudflare.com/sign-up
 3. Double-click deploy.bat. A browser opens: log in and allow wrangler.
    When asked, choose a HOST KEY (any password you like; only you need it).
 4. At the end deploy.bat prints your link:  https://clawd-coop.<your-name>.workers.dev

PLAYING
 You:     open  https://clawd-coop.<your-name>.workers.dev/?host
          click 2P, then Host, type your host key (the browser remembers it).
          The panel shows a 6-digit code. ("new code" makes a fresh one and disconnects the current friend.)
 Friend:  opens  https://clawd-coop.<your-name>.workers.dev  (no ?host), types the code, Join.
 If either of you loses the line, the game waits 15 s and reconnects by itself; nothing restarts.

UPDATING AFTER A CHANGE
 Run deploy.bat again. It is safe to repeat; it only asks about the host key if you want to change it.
 (A deploy disconnects everybody who is playing at that moment.)

CHOOSING THE SERVER REGION
 The room lives in one data center, chosen near whoever opens it first, and it never moves.
 To pick a region between you and your friend: in wrangler.jsonc set  "LOCATION_HINT"  (for example "weur", "eeur", "enam", "wnam", "apac")
 AND change "ROOM_NAME" to a new word (a new name = a new room, which is when the hint is used). Then run deploy.bat.
 Hints are best effort. Valid values: wnam enam sam weur eeur apac apac-ne apac-se oc afr me
 (sam, afr and me have no data centers yet and fall back to a nearby region.)

DIFFICULTY DEFAULTS (optional)
 In wrangler.jsonc "vars": BOSS_HP (0-100), NPC_HITS (0-5), NPC_MULT (100-300) and LOCK ("1" = the host cannot change them).

FREE LIMITS (roughly - check https://developers.cloudflare.com/durable-objects/platform/pricing/ for the current numbers)
 - 100,000 Durable Object requests per day. Incoming WebSocket messages count 20:1, and a 2-player game sends about
   50 messages/s into the room = about 2.5 requests/s = about 10 hours of co-op per day.
 - If a limit is hit the connection fails until 00:00 UTC.

IF DEPLOY SAYS SOMETHING ABOUT DURABLE OBJECTS
 The free plan only allows SQLite-backed Durable Objects. wrangler.jsonc must keep this block untouched:
   "migrations": [{ "tag": "v1", "new_sqlite_classes": ["Room"] }]

TESTING ON YOUR PC (no deploy)
 npm install, then:  npx wrangler dev --var HOST_KEY:test      -> http://localhost:8787/?host   (host key: test)
 Test suite:         node tools/coop-harness.js all            (see tools/README.md)

FALLBACK
 The old way (clawd-coop/start.bat + a tunnel) still works, unchanged, in the clawd-coop folder.
