# 02 · ساخت RACE CONDITION v3 (همه‌ی M1 تا M6)

**بخش:** باس   **اسکیل:** boss-build   **مدل:** Sonnet 5.5 (`claude-sonnet-5-5`)، خواست زکریا   **وضعیت:** انجام شد (۲۰۲۶-۱۰-۲۳، M1 تا M6 روی `ph1`)

## پرامپت (همه‌ی این بخش رو به سشن بده)

تو یه سشن سازنده‌ی استودیوی CLAWD هستی. اول `git fetch origin ph1 && git checkout ph1 && git pull origin ph1`، بعد `CLAUDE.md` و `docs/studio/README.md` رو بخون.

**کار:** باس RACE CONDITION v3 رو توی نسخه‌ی Godot (`godot/`) **کامل** بساز: همه‌ی milestoneهای پلن، M1 تا M6، **پشت سر هم توی همین یه سشن**.

**دو استثنا که زکریا خودش گفته (از قانون‌های اسکیل مهم‌ترن):**
1. اسکیل `boss-build` می‌گه «هر milestone یه سشن». **اینجا نه:** همه‌ی شش‌تا رو توی همین سشن بساز. اول یه فهرست کار کامل بریز (TaskCreate)، بعد milestone به milestone جلو برو. بعد از هر milestone تست‌هاش رو بزن، commit کن، به `ph1` پوش کن، و توی جدول وضعیت `docs/metroidvania/17-race-build.md` علامت `done` بزن با یادداشت چیزهایی که عوض شد. اگه context پر شد و خلاصه شد، از روی همون جدول و یادداشت‌ها ادامه بده.
2. اسکیل می‌گه «هر جا پلن چیزی رو تعیین نکرده، بپرس». **اینجا سؤال نپرس:** معقول‌ترین گزینه رو خودت انتخاب کن (نزدیک‌ترین به سند فارسی، به قانون‌ها و به رفرنس‌ها)، و هر تصمیمی که بازیکن می‌بینه یا می‌شنوه رو توی یادداشت همون milestone بنویس تا زکریا بعداً ببینه. دیالوگ تازه اختراع نکن (همه توی پلن هست).

**اسکیل:** `boss-build` (`.claude/skills/boss-build/SKILL.md`) و طبقش کار کن، جز دو استثنای بالا.

**سندها:**
- `docs/metroidvania/17-race-build.md`: **پلن ساخت کامل (انگلیسی)، مرجع اصلی تو.** هندسه، عددها، حمله‌ها، فیلدهای شبکه، تست‌ها، milestoneها، «Do not».
- `docs/metroidvania/17-race-condition.md`: طراحی فارسی با زکریا. هر جا با پلن نخوند، **این برنده‌ست**.
- `docs/metroidvania/17-race-data/ref/` و `README.md` ـش: **عکس‌های رفرنس** (آدمک‌ها، پس‌زمینه‌ها، ناقوس‌ها، گریز، ساعت). قبل از کشیدن هر چیزی ببینشون. پس‌زمینه‌ها خودشون فایل بازی می‌شن (پلن §4.4). طرح هندسه: `17-race-data/arena_B.png`.
- `docs/metroidvania/15-boss-process.md` بخش ۳ تا ۵ و `docs/metroidvania/07-js-vs-godot.md` §3: قانون‌های co-op و درس‌های باس‌های قبلی.
- مرجع کد: CRAWLER (`godot/src/enemies/crawler_boss.gd`، `godot/src/world/index_hall.gd`) و FIREWALL (`godot/src/enemies/firewall_boss.gd`، `godot/src/world/honeypot_hall.gd`، منوی باخت).

**کد (احتمالاً دست می‌خوره):** `godot/src/enemies/race_boss.gd` (بازنویسی، اسم کلاس `RaceBoss` و شماره‌ی ۴۶ `NetClasses` می‌مونه)، `godot/src/world/belfry_hall.gd` (تازه)، `godot/src/world/rooms/T06.txt`، `godot/src/world/rooms.json`، `docs/metroidvania/world-phase45.json`، `godot/src/world/room.gd` و `tower.gd` و `room_view.gd` و `room_lights.gd` و `look.gd`، `spinlock.gd`، `ticker.gd`، `hud.gd`، `main.gd` (صحنه‌ی عکس `race:`)، `godot/src/world/decor.gd` (رنگ رگه‌های T04)، `boss.gd` (منوی باخت عمومی)، `tools/voice/race_voice.py`، `tools/godot/sfx/`، `godot/assets/`، تست‌ها (`tests_5a.gd`، `tests_4b3.gd`، `coop_scenarios.gd`، `tools/godot/test-all.sh`).

**محیط:** Chromium در `/opt/pw-browsers/chromium`؛ قبل از سناریوهای co-op `npm ci`؛ Godot: `GODOT=$(bash tools/godot/setup-godot.sh | tail -1)`. صدا: Piper توی یه venv (`tools/voice/README.md`)، فقط `en_GB-northern_english_male-medium`، take `a`. خراب‌های قدیمی که مال این باس نیستن: `co-loopboss`، `co-shop`، `gfxother`. هیچ تستی رو رد نکن، خاموش نکن یا شل نکن.

**تمام‌شده یعنی:**
- هر شش milestone توی جدول `17-race-build.md` علامت `done` دارن، با یادداشت.
- تست‌های هر milestone سبزن: `race3`، `bosspresets`، `fightsim`، `parity`، `co-race` (با و بدون `BADLINE_ALL=1`)، `tick5a`، `arenas`، `gfxcontrast`، `perfrooms`.
- آخرش کل `bash tools/godot/test-all.sh` سبزه (جز سه خراب قدیمی بالا). اگه چیزی سبز نشد، صادقانه بنویس چی و چرا.
- اسکرین‌شات‌هایی که پلن §8 می‌گه گرفته شده و خودت نگاهشون کردی؛ بهترین‌هاشون رو برای زکریا بفرست (SendUserFile).
- خروجی وب `public/mv` به‌عنوان **آخرین commit جدا**.

**آخر کار:**
- RACE CONDITION رو روی `docs/studio/PRODUCER.md` تیک بزن و این دستور کار رو ببر `docs/studio/briefs/done/`.
- چیزهایی که برای بخش‌های دیگه پیدا کردی (مثلاً پرشی توی T01/T02/TB2 که با ضرب تازه خراب شد) رو توی صندوقشون بنویس (`docs/studio/WORLD.md` و ...). اتاق‌های دیگه رو از نو نکش.
- قدم‌های تست بازی برای زکریا رو، فارسی و کوتاه، توی `docs/studio/PLAYTEST.md` بخش «منتظر تست» بنویس.
- پوش کن به `ph1`. **بدون اجازه‌ی زکریا به `main` مرج نکن.**
- یه گزارش کوتاه فارسی بده: چی ساخته شد، نتیجه‌ی تست‌ها (با خراب‌ها)، تصمیم‌هایی که خودت گرفتی.

## چرا الان

هدف A تابلو: «همه‌ی باس‌های بعد از LEAK با v3»؛ RACE CONDITION اولیشه و طراحیش تموم شده (سند 17).
