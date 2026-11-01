# 04 · RACE CONDITION: تست کامل و web export تعمیرها

**بخش:** باس   **اسکیل:** boss-build   **مدل:** Opus 5.5 (`claude-opus-5-5`)   **وضعیت:** آماده

## پرامپت (همه‌ی این بخش رو به سشن بده)

تو یه سشن سازنده‌ی استودیوی CLAWD هستی. اول `git pull origin ph1`، بعد `CLAUDE.md` و `docs/studio/README.md` رو بخون.
کار: تعمیرهای دستور کار 03 (کامیت‌های `048db1d` و `422ad44`: sprite‌های TICK و TOCK از عکس‌های زکریا، آسیب لمس بدن، فریم سبک‌تر) هنوز توی web export نیستن (آخرین export: `f4745b3`). سشن 03 قبل از `test-all.sh` و export متوقف شد. پس زکریا هنوز نمی‌تونه نسخه‌ی تعمیرشده رو بازی کنه.
اسکیل: `boss-build`، فقط قانون‌های تست و export.
سندها: `docs/metroidvania/17-race-build.md` بخش «Fix after Zakaria's play-test» (چی عوض شد و کدوم تست‌ها پاس شدن).
انجام بده:
1. `bash tools/godot/test-all.sh`. هر خرابی که مال این تعمیرهاست رو درست کن. خراب‌های قدیمی که مال این باس نیستن: `co-loopboss`، `co-shop`، `gfxother`، `gfxcontrast` (ردیف N15)؛ فقط بنویس هنوز خرابن یا نه.
2. web export توی `public/mv`، به‌عنوان آخرین کامیت خودش.
3. توی یادداشت‌های `17-race-build.md` یه خط: test-all و export انجام شد.
تمام‌شده یعنی: test-all بدون خرابی تازه، و `git log -- public/mv` کامیتی بعد از `422ad44` نشون بده.
آخر کار:
- روی `docs/studio/PRODUCER.md` تیک بزن و این دستور کار رو ببر `briefs/done/`.
- توی `docs/studio/PLAYTEST.md` «منتظر تست»، ردیف RACE CONDITION رو با کامیت export به‌روز کن.
- پوش کن به `ph1`. بدون اجازه‌ی زکریا به `main` مرج نکن.

## چرا الان

تا export نشه، تست دوباره‌ی RACE CONDITION ممکن نیست، و هدف A بدون اون جلو نمی‌ره.
