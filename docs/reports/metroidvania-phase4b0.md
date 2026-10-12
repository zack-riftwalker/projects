# Phase 4B-0 report: engine groundwork and the boss kit

## چی ساخته شد (MVB0-01 تا 11)
- **MVB0-01** فلگ‌های دنیا (`boss: hatch: link: thread: lever: lab:`) توی snapshot میزبان می‌رن (`wf`). باگ دریچه‌ی یک‌طرفه درست شد. تست `co-flags` روی کد قدیم رد می‌شد و حالا قبول می‌شه.
- **MVB0-02** اتاق‌های Z01–Z06، `?debug&lab` (بازی از Z05 شروع می‌شه)، اتاق lab روی نقشه و Travel نیست، `world.py` توی `test-all.sh`، تست `lab`.
- **MVB0-03** قفل `until:<k>of:<flags>`، درپوش یک‌طرفه. تست `locks4b`.
- **MVB0-04** تابلو با متن وابسته به فلگ (`Room.sign_text`). تست `signs4b`.
- **MVB0-05** `variants`: کاشی‌ای که با فلگ عوض می‌شه و هیچ‌وقت داخل یا زیر بدن نیست (`Room._step_variants`، `RoomView.refresh_tile`). تست `variants4b`.
- **MVB0-06** درِ symlink: تغییری توی موتور لازم نبود. تست `symlink`. عبور مهمون از `Z04:W` توی `co-flags` تست می‌شه.
- **MVB0-07** بسته‌ها (حرف `J`) و پورت‌ها (حرف `3`، `TileGrid.PORT`). تست `packets` و `co-packet`.
- **MVB0-08/09/10** کیت باس (`boss.gd`)، `BossRead`، `KitDummy` (کلاس شبکه ۲۵)، فیلد `fo` مهمون، قانون watchdog `boss-cue`. تست `bosskit` و `co-bosskit`.

## انحراف‌ها از پلن (deviations)
1. `git merge origin/main` ممکن نبود: تاریخچه‌ی `ph1` و `main` هیچ جد مشترکی ندارن («unrelated histories»). `ph1` بدون merge ادامه پیدا کرد.
2. MVB0-08 و 09 و 10 توی یک commit رفتن (کد کیت و دامی به هم وابسته‌ان). بقیه‌ی تسک‌ها هرکدوم commit جدا دارن.
3. `plan_start` یه پارامتر اختیاری ششم گرفت: `cue` (برای riposte با cue ‎0.8 s).
4. تست قدیمی `rooms4` از جفت‌درهای `symlink` صرف‌نظر می‌کنه (از طراحی هم‌ردیف نیستن).
5. `co-packet` مهمون رو روی بسته‌ای می‌ذاره که `x` اون بین ۱۰۰ و ۲۶۰ باشه (نه دقیقاً از ابتدا)، چون سواری کامل از شروع ۱۲ ثانیه می‌شه و حاشیه‌ای برای تأخیر نمی‌ذاره. توی تست، رسیدن به ستون ۵۰ حدود ۱۰.۷ ثانیه طول کشید.
6. `co-bosskit`: بدون gating (`_guest_waits` همیشه false) هم تست رد می‌شه، چون cue ها ≥ ۰.۵ ثانیه‌ان و خط بد هم هشدار رو می‌رسونه. gating با تست واحد `bosskit` (نگه‌داشتن، لغو بعد از `HOLD_MAX`، `SEEN_MIN`) پوشش داده می‌شه.

## نتیجه‌ی تست‌ها
- `bash tools/godot/test-all.sh`: همه PASS (smoke، worldcheck، همه‌ی `--test`، parity tapes، etrace، export، web-check، کل co-op) به‌جز `relay` که فقط `mv-title` («new game after a failed join») یک‌بار رد شد.
  - `mv-title` تست حساس به زمان‌بندیه: روی export قدیمیِ commit شده هم (با خطای دیگه‌ای) رد شد. دوباره اجرا شد: PASS. بعد کل مجموعه‌ی relay (`mv-serve mv-coop mv-title mv-phone cache`) دوباره اجرا شد: همه PASS.
- خط بد (`BADLINE_ALL=1`، هرکدوم جدا): `co-flags co-packet co-bosskit co-nsdoor co-leak` همه PASS.
- `world.py`: `errors 0`.
- هیچ خط `INVARIANT` یا `SCRIPT ERROR` نبود.

## API کیت، همونی که ساخته شد
`Boss` (`godot/src/enemies/boss.gd`):
- ثابت‌ها: `FAMILY`, `FAM_KEYS`, `PLAN_PH`, `SEEN_MIN = 0.35`, `HOLD_MAX = 0.60`.
- متغیرها: `plan`, `plan_seq`, `seen_seq`, `seen_at`, `hold_t`, `plan_clock`, `read`, `kit_hist`, `plan_snap_seq`; سمت مهمون: `cue_shown`, `kit_violation`, `kit_active_seen`, `kit_ignore_seq`.
- `kit_init()` — `read` رو می‌سازه.
- `plan_ids() -> Array` — هر باس کیت override می‌کنه (فهرست نام حمله‌ها برای شبکه).
- `plan_start(id, fam, tgt, fp, lock := 0.0, cue := -1.0)`.
- `plan_step(dt) -> String` — `"active" | "recover" | "done" | ""`.
- `plan_phase()`, `plan_active()`, `plan_cut()` (حمله بره سر recover), `plan_seen(seq)`.
- `plan_fields() -> Array`, `plan_apply(a)` — به `net_fields()` / `net_apply()` باس اضافه می‌شن.
- `kit_puppet_tick(dt)` — از `puppet_tick` صدا زده می‌شه.
- `kit_body(key)`, `kit_alive(key)`, `kit_keys()`, `kit_key_of(q)`, `kit_dist(key)`, `kit_aim(key)`, `kit_pick_target() -> "p1"|"p2"`.
- `draw_plan(ci)` — استنسیل و نشانگر ۱ (دایره) / ۲ (لوزی).

`BossRead` (`boss_read.gd`): `update(dt)`, `note_hit(key, how)`, `dist(key)`, `greedy(key, n=3, secs=1.2, near=48.0)`, `healing(key)`, `under(key)`, `last_hitter()`, `last_how(key)`.

`Room`: `boss_damage()` خودش `note_hit` رو صدا می‌زنه؛ `bodies()`, `sign_text(s)`, `_step_variants()`, `_move_packets()`, `_update_ports()`, `shoot(...)` با `kind: "diamond"` (الماس زرد قابل گرفتن).

`Coop`: `plan_snaps` (host: اولین snapshot که هر plan رو داشت؛ با `sa` مهمون `plan_seen` صدا زده می‌شه)، `wf` توی snapshot، `fo` توی `st`.

`KitDummy` (`kit_dummy.gd`، کلاس شبکه ۲۵): چرخه‌ی lunge → orbs → drop؛ قانون ۸: اگه `read.greedy(k)` پس `guard` روی اون بازیکن؛ ضربه به guard → `riposte` (cue ‎0.8 s) روی ضربه‌زن.

## مراحل تست برای زکریا (فارسی)
1. **co-op، باگ دریچه:** تو (میزبان) برو `sudoers` (H10)، روی کف دریچه‌ی یک‌طرفه بایست و [پایین]+[پرش] بزن تا بیفتی پایین. دوستت وسط `dangling_ptr.c` (H04) زیر سقف دریچه (ستون ۱۰۶ تا ۱۰۹) باشه. باید سقف بعد از یکی-دو ثانیه برای اون هم باز بشه (قبلاً بسته می‌موند).
2. **آزمایشگاه:** با `?debug&lab` بازی رو باز کن (مثلاً `http://127.0.0.1:3000/mv/?debug&lab`). توی اتاق اول (Z05) سوار بسته‌ی نورانی شو و ببین از دو پورت قرمز (۲۲ و ۸۰) رد می‌شی. بعد پیاده هم سعی کن زمان‌بندی پورت‌ها رو بگیری. پورت هیچ‌وقت نباید روی تو بسته بشه.
3. **عروسک:** از در شرقی برو اتاق کناری (Z06، «SPARRING DUMMY»). با دوستت (از گوشی، با اینترنت) باهاش بجنگید. بگو:
   - هشدار هر حمله (استنسیل راه‌راه، نشانگر ۱ یا ۲ بالای سر هدف، الماس زرد قابل گرفتن) روی گوشی و با پینگ واقعی خوانا هست یا نه؛
   - اگه چند تا ضربه‌ی پشت‌سرهم از نزدیک بزنی، عروسک سپر می‌گیره (`// nit:`) و بعد از ضربه به سپر یه حمله‌ی تلافی می‌زنه یا نه.
4. **HEAP:** یه دور co-op عادی توی THE HEAP هم بزنید و ببینید هنوز درست کار می‌کنه.
5. بالای صفحه اگه نوار قرمز «DIFFERENT BUILDS» دیدی، دو طرف نسخه‌ی یکسان ندارن.
