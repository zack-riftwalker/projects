# ضبط هنر و صدا از بازی فعلی

`capture.js` بازی فعلی (`public/index.html`) رو تو یه مرورگر بدون صفحه باز می‌کنه و از روش فایل می‌سازه.

| هدف | خروجی |
|---|---|
| `sprites` | همه‌ی PNGهای `G.SPR` (دشمن، توکن، checkpoint، ضربه‌ها...) و `index.json` با اندازه‌ها |
| `tiles` | یه اطلس ۲۵۶×۱۱۲ از کاشی‌های دنیای ۱ |
| `font` | دو فونت bitmap (`big` و `tiny`) با JSON |
| `bg` | پس‌زمینه‌ی ۳۸۴×۲۱۶ دنیای ۱ |
| `sfx` | ۴۸ صدای کوتاه، WAV تک‌کاناله |
| `music` | همه‌ی آهنگ‌ها OGG تو `out/music/`؛ فقط `w1` کپی می‌شه به `godot/assets/music/` |
| `levels` | نقشه‌ی متنی همه‌ی مرحله‌ها تو `out/levels/` |

اجرا: `node tools/godot/capture/capture.js all` (حدود ۵ دقیقه، بیشترش موسیقیه) یا فقط `... sprites tiles`.
خروجی خام تو `tools/godot/capture/out/` می‌مونه (commit نمی‌شه) و فایل‌های لازم کپی می‌شن به `godot/assets/`.
