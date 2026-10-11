# گزارش: اصلاح‌های فاز ۳ (MV3-FIX-1 … 9)

شاخه `ph1`، برای هر اصلاح یک commit. برای هر کدام اول تست نوشته شد و روی کد قدیم **FAIL** شد، بعد از اصلاح **PASS**.

| # | مشکل | تغییر | تست (قدیم → جدید) |
|---|---|---|---|
| 1 | agentهای مهمان فقط یک بار در هر اتصال کار می‌کردند | تایمر بی‌مصرف حذف شد؛ هر cast جای قبلی را می‌گیرد | `co-agents` (دو cast) FAIL → PASS، با خط بد هم |
| 2 | سرهای MERGE CONFLICT روی مهمان می‌پریدند | بافر درون‌یابی برای سرها (`net_sample`، `puppet_follow_parts`) | `mergeinterp` FAIL → PASS؛ `parity`، `merge`، `co-merge` PASS |
| 3 | منو (نیمکت/فروشگاه) روی یک صفحه کل دنیا را در co-op می‌ایستاند | در co-op دنیا ادامه دارد، بدن بی‌ورودی می‌ایستد (`in_menu`)؛ تنها بودن مثل قبل | `co-menutick` FAIL (سمت host) → PASS؛ `shop`، `bench`، `co-shop`، `co-bench` PASS |
| 4 | loadout مهمان با پلاگین‌های نداشته | یک فیلتر `Game.filter_loadout` در همه جا | `loadout` FAIL → PASS؛ `plugins`، `save`، `co-plugins` PASS |
| 5 | خرید مهمان می‌توانست برای همیشه «در انتظار» بماند | شروع تازه `pending` را پاک می‌کند | `co-rejoin` FAIL → PASS؛ `co-shop` PASS |
| 6 | صفحه Fights ضربه‌ی agent/catch/dash را ضربه‌ی پنجه حساب می‌کرد | فقط `swipe` در `hits`؛ بقیه در `other` | `bossstats` FAIL → PASS؛ `null`، `reviewer`، `merge`، `bossreg` PASS |
| 7 | host ضربه‌ها را زود فراموش می‌کرد و parry دیرِ مهمان رد می‌شد | یک ثانیه از ضربه‌ها نگه داشته می‌شود | `strikeseen` FAIL → PASS؛ `reviewer`، `co-reviewer` (خط بد هم) PASS |
| 8 | REVIEWER جدید شناسه‌ی ضربه‌های parry شده را دوباره استفاده می‌کرد | شناسه یکتا در کل جلسه + پاک کردن `parried` در شروع نبرد | `sidunique` FAIL → PASS؛ `reviewer`، `catch`، `co-reviewer` PASS |
| 9 | snapshot می‌توانست به صاحبِ آزاد‌شده‌ی agent دست بزند | `is_instance_valid` | بدون تست جدید (طبق plan)؛ `co-agents`، `co-soak` بدون SCRIPT ERROR |

## نتیجه‌ها
- `tools/godot/test-all.sh`: **ALL PASS** (smoke، همه‌ی تست‌ها، parity، export، web-check، relay، coop).
- `BADLINE_ALL=1 bash tools/godot/coop-test.sh all`: **همه ۳۷ سناریو PASS**.

## انحراف‌ها از plan
- **FIX-6:** در `_start_reward` به جای `stats.other[0]` از `stats.get("other", [0, 0])` استفاده شد، چون تست `bossreg` مقدار `stats` را دستی می‌سازد (بدون `other`) و با دسترسی مستقیم خطای SCRIPT ERROR می‌داد. هدف plan (همان خط لاگ) حفظ شد.
- **FIX-3:** `co-menutick` روی کد قدیم فقط سمت host FAIL شد؛ سمت مهمان همان موقع PASS بود (اتاق مهمان خودش زمان را جلو می‌برد). تست درست است چون کل سناریو FAIL می‌شود؛ رفع اصلی برای host بود، و برای مهمان ورودی و شبیه‌سازی بدن.
- محیط: `npm install` لازم بود (ماژول `ws` نصب نبود)؛ `node_modules` در git نیست.
