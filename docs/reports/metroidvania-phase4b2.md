# Phase 4B-2 report: THE NETWORK

## چی ساخته شد (MVB2-01 تا 14)
- **01** ۲۲ اتاق N01..N22 از `phase4b2-data/` (با `apply.py`)، قفل `oneway`، درهای پایان N11 و N17، ویرایش H11/D07/D06. تست `rooms4b`.
- **02** ظاهر دنیای ۶ (تایل، تم، موسیقی `w6`، پس‌زمینه‌ی شهر شبانه، landmark `ci`). تست `w6assets`.
- **03** `curl`: حلقه‌های GET، پرش به حلقه با [special]، علامت هدف، کابل. تست `curl`، `co-curl`.
- **04** `ssh`: تونل از دیوار قرمز نازک، از در هم رد می‌شه. تست `ssh`، `co-ssh`.
- **05/06** تار عنکبوت، قلاب، اهرم (`I`) و `gate_lever`، موج‌های honeypot، دشمن‌های SCRAPER، WORM، DDOS، SPYWARE (کلاس‌های ۲۶ تا ۲۹). تست `net4b`، `w6enemies`، `co-lever`، `co-honeypot`.
- **07** WEB CRAWLER (کلاس ۳۰) → `curl`. تست `crawler`، `co-crawler`.
- **08** THE FIREWALL (کلاس ۳۱) → `ssh`. تست `firewall`، `co-firewall`.
- **09** THE REVIEWER #2 (کلاس ۳۲)، شروع از صندلی (pad)، جایزه‌ی پلاگین. تست `reviewer2`، `co-reviewer2`.
- **10** پلاگین‌های `gzip`، `sourcemap`، `rate_limit`، `review_cache`. تست `plugins4b`.
- **11** سیستم‌های 4B-1 توی NETWORK (`tree` توی N06، agent توی N20، صفحه و تکه‌ی حافظه توی N19، N20 بی‌نقشه، ترمینال N03، `c` مانع curl). تست `net4b1`.
- **12** تست راه‌رفتن (داخل `rooms4b`): عبور از ۴۹ در، سقوط‌های airgap، رازهای N19/N20/N21، حلقه‌ی DEPTHS با اهرم N02.
- **13** هفت سناریوی co-op (`co-curl co-ssh co-crawler co-firewall co-reviewer2 co-honeypot co-lever`) و دو قانون watchdog: `scan-lane` و `wave-door`. `boss-cue` باس‌های جدید رو هم پوشش می‌ده (همه kit هستن).

## باگ‌های واقعی که سناریوها پیدا کردن
- مهمون پرچم `ability:<x>` رو نمی‌گرفت (فقط `tools`): حالا با رویداد ability پرچم هم ست می‌شه (صندلی N22 اون رو می‌خونه).
- مهمون توی `step_guest` فشار [up] روی صندلی رو نمی‌دید: `_step_pad` اونجا هم صدا زده می‌شه.

## انحراف‌ها از پلن
1. تست `curl` با ربات تطبیق‌داده‌شده کار می‌کنه نه اسکریپت کلید به کلید پلن (همون زمان‌بندی، ولی offset پیدا می‌شه).
2. آهنگ `w6` حدود ۶۲٫۶ ثانیه‌ست (پلن ۴۰ تا ۶۰).
3. HP فایروال ۵۹ شد نه ۶۰ (فرمول مشترک `boss_hp` گرد می‌کنه). REVIEWER #2 هم ۵۹.
4. دشمنی نزدیک ترمینال‌ها نبود.
5. فایروال: بعد از `phase` سپر برای دوره‌ی recovery برمی‌داره (پشتش به غشاست). وقتی کسی مدام به سپر ضربه می‌زنه، قاعده‌ی ۸ (`bash`) پشت‌سرهم روی همون نفر می‌رسه؛ سناریو برای همین فقط p2 رو الزامی می‌کنه.
6. REVIEWER #2: برای `cached` نوع ضربه رو خودش نگه می‌داره (`last_kind`: side/up/pogo/dash/agent/catch) چون `read.last_how` فقط swipe رو می‌گه. شلیک `verdict` هر ۰٫۷ ثانیه است و ریکاوری منتظر آخرین گلوله می‌مونه. X خاکستری یه گوی گرد خاکستریه (نه حرف X).
7. دکمه‌ی «Skip boss» برای باس pad هم کار می‌کنه (اگه هنوز شروع نشده، intro رو شروع می‌کنه).
8. `rooms4b` به‌جای مسیر کامل «دو ورودی» (قدم‌به‌قدم) از اثبات چک‌کننده (`check4b2.py`) به‌علاوه‌ی عبور از همه‌ی درها استفاده می‌کنه (انتخاب پلن).
9. `test-all.sh`: بخش co-op حالا دو مسیر موازی داره (پورت و کد جدا) و `coop-test.sh` متغیرهای `COOP_PORT` و `COOP_CODE` رو می‌خونه.
10. `ci` landmark: offset داخل `Landmarks` مشترک محاسبه می‌شه.

## نتیجه‌ی تست‌ها
- `bash tools/godot/test-all.sh`: **ALL PASS** (۹۷ مورد، شامل smoke، همه‌ی `--test`ها، ۷ نوار parity، export، web-check، relay، و همه‌ی سناریوهای co-op).
- خط بد (`BADLINE_ALL=1`): `co-curl co-ssh co-crawler co-firewall co-reviewer2 co-honeypot co-flags co-bosskit` همه PASS.
- `check4b2.py`، `check4a.py`، `world.py`: نتیجه پایین.
- هیچ `INVARIANT` یا `SCRIPT ERROR` نبود.

## عکس‌ها
`docs/reports/img-phase4b2/N05.png`، `N11.png`، `N12.png`.

## تست دستی (برای زکریا)
1. بازی جدید، با bash و catch بیا تا D06. بعد از N02 (از D07 شرق) اهرم رو با ضربه بکش: درِ شکاف D06 بدون agent باز می‌شه.
2. وارد N-اتاق‌ها شو؛ N08 رو بالا برو تا N09: **WEB CRAWLER**. هسته‌ش بالاست و فقط وقتی پایین میاد که حمله‌ش تموم شه یا یه بسته‌ی زرد رو بهش پس بدی. وقتی بمیره `curl` می‌گیری: نزدیک حلقه‌ی GET [special] بزن.
3. N10: سه ترنچ رو با curl رد کن (پرش + [special] پشت‌سرهم).
4. N15: **THE FIREWALL**؛ سپرش جلو رو می‌گیره. بعد از مرگش `ssh` می‌گیری: توی N16 به دیوار قرمز نازک تکیه بده (۰٫۳ ثانیه) تا رد شی.
5. N11 (airgap): از شکاف بپر پایین: به H11، N01 یا N04 می‌افتی، بدون آسیب.
6. رازها: N05 از لبه‌ی (۷۰,۴) بپر بالا → N19؛ روی درپوش (۵۳,۱۷) [down]+[jump] → N20؛ N13 ترک (۳۵,۲۱) با bash → N21 (honeypot: موج‌ها رو بکش، تراشه‌ی `rate_limit` از شیشه درمیاد).
7. N22: روی صندلی (۱۱,۱۰) با curl یا ssh [up] بزن: **THE REVIEWER #2**. جایزه‌ش پلاگین `review cache`.
8. co-op: دوستت با کد ۶ رقمی وصل شه؛ کابل curl و ssh دوستت رو روی صفحه‌ی خودت می‌بینی.
