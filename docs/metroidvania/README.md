# سندهای متروید وینیای CLAWD

این پوشه سندهای طراحی نسخه‌ی متروید وینیا رو نگه می‌داره. تصمیم‌های نهایی بعد از بررسی فاز ۰ تو بخش ۱۱ِ [`00-decisions.md`](00-decisions.md) هستن و تصمیم‌های فاز ۳ تو بخش ۱۲، طراحی دنیای فاز ۴ و ۵ تو بخش ۱۳، و فاز ۱ طراحی (به‌روز کردن دنیا با پژوهش‌ها) تو بخش ۱۴.

## پلن‌ها (برای Sonnet)

| پلن | چی | وضعیت |
|---|---|---|
| [`../PLAN-metroidvania-phase0.md`](../PLAN-metroidvania-phase0.md) | فاز ۰: طراحی و ابزار Godot | انجام شد |
| [`../PLAN-metroidvania-phase1.md`](../PLAN-metroidvania-phase1.md) | فاز ۱: پایه‌ی Godot، یه اتاق قابل بازی، تست گوشی | انجام شد |
| [`../PLAN-metroidvania-phase2.md`](../PLAN-metroidvania-phase2.md) | فاز ۲: ۸ اتاق SOURCE TREE، NULL v2، دو دشمن جدید، co-op | انجام شد |
| [`../PLAN-metroidvania-phase3.md`](../PLAN-metroidvania-phase3.md) | فاز ۳: ۳A بقیه‌ی SOURCE TREE (THE REVIEWER، catch، پلاگین‌ها)، ۳B منطقه‌ی DEPENDENCY DEPTHS (MERGE CONFLICT، agents، فروشگاه) | انجام شد (۳A و ۳B) |
| [`../PLAN-metroidvania-phase4a.md`](../PLAN-metroidvania-phase4a.md) | فاز ۴A: منطقه‌ی THE HEAP (۱۶ اتاق، درهای بالا و پایین، سیل سه‌مرحله‌ای، dead code، THE LEAK → sudo، سفر فقط از ترمینال، سه راز تازه در SOURCE TREE). داده‌ی اتاق‌ها: [`phase4a-data/`](phase4a-data/). گزارش: [`../reports/metroidvania-phase4a.md`](../reports/metroidvania-phase4a.md) | انجام شد (۴A) |
| [`../PLAN-metroidvania-phase4b0.md`](../PLAN-metroidvania-phase4b0.md) | فاز ۴B-0 (گام ۱ و ۲ پلن کلی): زیرساخت موتور (فلگ‌های دنیا در co-op، قفل «k از n»، تابلو و کاشی وابسته به فلگ، درِ symlink، بسته و پورت) و کیت باس‌ها با یه باس تمرینی؛ شش اتاق آزمایشگاه. داده: [`phase4b0-data/`](phase4b0-data/) | انجام شد (۴B-0). گزارش: [`../reports/metroidvania-phase4b0.md`](../reports/metroidvania-phase4b0.md) |
| [`../PLAN-metroidvania-phase4b1.md`](../PLAN-metroidvania-phase4b1.md) | فاز ۴B-1 (گام ۳ و ۴ پلن کلی): نقشهٔ جدید (نقشه‌کش `tree`، صفحهٔ نقشه، نقشهٔ روی بازی، پین و پینگ، خط سفر به P2)، وضعیت دنیا با digest، صفحهٔ Logs، agentهای گمشده، صفحه‌های logbook، دکور و تغییرات اتاق‌های ساخته‌شده، ترمینال‌ها و نشانه‌ها | بعد از 4B-0، در صف Sonnet |

## سندها

| سند | کار | کی | وضعیت |
|---|---|---|---|
| [`00-decisions.md`](00-decisions.md) | خلاصه‌ی همه‌ی تصمیم‌ها (به انگلیسی، برای Sonnet) | Claude | انجام شد |
| [`01-current-game.md`](01-current-game.md) | MV0-02: فهرست بازی فعلی | Claude | انجام شد |
| [`../../tools/godot/README.md`](../../tools/godot/README.md) | MV0-03: ابزار Godot | Sonnet | انجام شد |
| [`02-oss-bosses.md`](02-oss-bosses.md) | MV0-04: باس‌ها و دشمن‌های بازی‌های اوپن سورس | Sonnet | انجام شد |
| [`03-abilities-and-gates.md`](03-abilities-and-gates.md) | MV0-05: توانایی‌ها و درها | Sonnet | انجام شد |
| [`04-coop-design.md`](04-coop-design.md) | MV0-06: Co-op با دوربین جدا | Sonnet | انجام شد |
| [`05-difficulty-model.md`](05-difficulty-model.md) | MV0-07: مدل سختی | Sonnet | انجام شد |
| [`06-phase1-test.md`](06-phase1-test.md) | MV0-08: پروتکل تست گوشی | Sonnet | انجام شد |
| [`../reports/metroidvania-phase0.md`](../reports/metroidvania-phase0.md) | MV0-08: گزارش فاز ۰ | Sonnet | انجام شد |

## فاز ۱

| سند | کار | کی | وضعیت |
|---|---|---|---|
| [`../PLAN-metroidvania-phase1.md`](../PLAN-metroidvania-phase1.md) | پلن فاز ۱ (پایه‌ی Godot) | Claude | انجام شد |
| [`../../godot/`](../../godot) | MV1-01 تا MV1-08: پروژه‌ی Godot | Sonnet | انجام شد |
| [`../reports/metroidvania-phase1.md`](../reports/metroidvania-phase1.md) | MV1-09: گزارش فاز ۱ و قدم‌های تست گوشی | Sonnet | انجام شد |

## بعد از فاز ۲: ریویو و پایداری co-op

| سند | کار | کی | وضعیت |
|---|---|---|---|
| [`07-js-vs-godot.md`](07-js-vs-godot.md) | مقایسه‌ی co-op نسخه‌ی JS با Godot، ریشه‌ی باگ‌ها، ۱۰ قانون برای تغییرهای بعدی، چیزهای باز | Claude | انجام شد |

## فاز ۴ و ۵: طراحی دنیا

| سند | کار | کی | وضعیت |
|---|---|---|---|
| [`08-world-design.md`](08-world-design.md) | طراحی دنیا و اتاق‌های فاز ۴ و ۵: شش منطقه، ۱۰۷ اتاق، درهای مخفی، حلقه‌ها، روح هر منطقه؛ با تغییرهای فاز ۱ طراحی (بخش ۱۰) (نقشه‌ی تعاملی: https://claude.ai/artifact/3idnat2P5utcSquVZ7oSyp) | Claude | تأیید شد (۲۰۲۶-۱۰-۱۱)، به‌روز با فاز ۱ طراحی (۲۰۲۶-۱۰-۱۲) |
| [`world-phase45.json`](world-phase45.json) | داده‌ی خام همون طراحی (اتاق‌ها، درها، قفل‌ها، سرنخ و لایه‌ی رازها، پس‌لرزه‌ی باس‌ها، نقشه‌نویس‌ها، ایجنت‌ها) برای پلن پیاده‌سازی | Claude | تأیید شد (۲۰۲۶-۱۰-۱۱)، به‌روز (۲۰۲۶-۱۰-۱۲) |
| [`09-design-pass1-proposals.md`](09-design-pass1-proposals.md) | فاز ۱ طراحی: ۴۶ پیشنهاد از ۸ پژوهش (ساختار، لحظه‌ی امضا، راز، نقشه، باس، داستان) و بسته‌ی پیشنهادی | Claude | انتخاب شد: ۴۴ از ۴۶ (همه جز W6 و B9)؛ در 08 و JSON اومد |
| [`10-open-topics.md`](10-open-topics.md) | انتخاب Zakaria، بحث‌های طراحی (S8، K1، M5، ساختار نقشه، B1) و گزینه‌هاشون، و ایده‌ی DLC «پیام‌های ناشناس» | Claude | بسته شد: همه «الف» (۲۰۲۶-۱۰-۱۲) |
