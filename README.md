# CLAWD

A 2-player co-op browser platformer. One game file (`public/index.html`) that works with **two kinds of server**:

| way to play | server | who hosts | friend opens |
|---|---|---|---|
| same Wi-Fi / phone hotspot | `start.bat` on your PC | your PC (`http://localhost:3000`) | `http://<PC's LAN IP>:3000` (shown in the black window) |
| over the internet, lowest ping | `start.bat` + **port forwarding** on the modem | your PC | `http://<your public IP>:3000` |
| over the internet, no port forwarding | `start.bat` + `tunnel.bat` | your PC | the `https://xxxx.trycloudflare.com` link |
| PC switched off | Cloudflare Workers (`deploy.bat`) | anyone with the host key (`…workers.dev/?host`) | `https://clawd-coop.<name>.workers.dev` |

All four use the same game, the same 6-digit friend code and the same reconnect rules, so they never get in each other's way:
the PC server only answers on port 3000 of your PC, the Cloudflare one only on its `workers.dev` link.
On the PC that runs `start.bat` you never need a host key; on Cloudflare you do.

## نصب و اجرا (فارسی)

**بار اول:**
1. Node.js نسخه‌ی LTS را از nodejs.org نصب کن.
2. فایل zip را در یک پوشه‌ی **تازه** باز کن (نه روی پوشه‌ی قدیمی `clawd-coop`).
3. `start.bat` را دوبار کلیک کن. بازی روی PC باز می‌شود و پنجره‌ی سیاه کد ۶ رقمی و آدرس‌ها را نشان می‌دهد.

**بازی دونفره:**
- **PC:** دکمه‌ی 2P بالای صفحه، بعد Host. کد در همان پنل هم نوشته می‌شود.
- **دوستت:** یکی از آدرس‌های جدول بالا را باز می‌کند، کد را می‌زند و Join را می‌زند.
  - با پورت‌فورواردی که روی مودم تنظیم کردی: `http://<IP عمومی تو>:3000`. اگر IP عمومی‌ات عوض شد، IP تازه را بفرست.
  - روی یک Wi-Fi یا هات‌اسپات: آدرس `192.168.x.x:3000` که پنجره‌ی سیاه نشان می‌دهد.

**آپدیت:** فقط `update.bat` را دوبار کلیک کن.
- آخرین نسخه از GitHub دانلود و روی همین پوشه نصب می‌شود.
- سیوها، تنظیمات کلیدها و `coop-config.json` دست نمی‌خورند.
- اگر `start.bat` باز باشد، سرور خودش ری‌استارت می‌شود.
- بعدش صفحه‌ی بازی را روی **هر دو دستگاه** reload کن: روی PC با Ctrl+F5، روی گوشی تب را ببند و دوباره باز کن.
- اگر هر دو صفحه نسخه‌ی یکسان نداشته باشند، بالای صفحه با قرمز هشدار داده می‌شود.
- اگر دانلود نشد (فیلتر)، VPN را روشن کن و دوباره اجرا کن.

**نسخه‌ی کلودفلر** (وقتی PC خاموش است): `deploy.bat` را اجرا کن. بعد از هر آپدیت دوباره اجرایش کن تا نسخه‌ی آنلاین هم تازه شود.

## Files

```
public/            the game (index.html + voices); the only thing either server sends to a browser
server.js          PC relay: LAN, hotspot, port forwarding, tunnel (Node + ws)
start.bat          runs server.js and restarts it if it stops
tunnel.bat         optional trycloudflare.com link to the PC server
cloud/worker.js    Cloudflare relay (Worker + one Durable Object), same protocol as server.js
wrangler.jsonc     Cloudflare settings (room name, region hint, difficulty defaults)
deploy.bat         puts public/ + cloud/worker.js online
update.bat         downloads the newest version from GitHub (tools/update.ps1)
tools/             test harness (Playwright) - developers only
docs/              protocol, plans and test reports
```

## Notes

- **Friend code:** 6 digits. Five wrong tries from one address lock it out for a minute. "new code" in the 2P panel makes a fresh one and sends the current friend away.
- **Reconnect:** if a line drops, the game keeps the level and reconnects by itself. The server keeps both seats for 15 s.
- **Line quality:** two small dots next to the hit points show it (green < 120 ms, yellow < 250 ms, red worse, grey = not answering). The 2P panel shows ping, jitter and traffic.
- **Debugging a co-op problem:** open both pages with `?debug` at the end of the address. The host lists every hit the partner announces and why it was accepted or refused; the guest lists what it sent.
- **Difficulty:**
  - Solo: set it in Options → difficulty.
  - Co-op: set it in the 2P panel once the friend is connected.
  - Server defaults:
    - PC server: `BOSS_HP` / `NPC_HITS` / `NPC_MULT` / `LOCK=1` in `start.bat`, or copy `coop-config.example.json` to `coop-config.json`.
    - Cloudflare: the `vars` in `wrangler.jsonc`.
- **Cloudflare region:** set `LOCATION_HINT` plus a new `ROOM_NAME` in `wrangler.jsonc`, then run `deploy.bat`. There is no Middle-East data center; `eeur` was the closest measured (~250 ms from Iran). The PC server with port forwarding is much faster.
- **Tests:**
  - PC relay: `node tools/coop-harness.js all`
  - Cloudflare relay: `TARGET=cloud node tools/coop-harness.js all`
  - See `tools/README.md` for details.
