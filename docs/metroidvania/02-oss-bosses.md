# MV0-04 · باس‌ها و دشمن‌های بازی‌های اوپن سورس

**نتیجه:** از ۶ بازی، ۴ تا (Cave Story، SuperTux، Azimuth، Hurrican) منبع قابل‌استفاده داشتن. ۲۰ باس یا دشمن ثبت شد و ۸ ایده‌ی **جدید** برای CLAWD پیدا شد. قوی‌ترین‌ها: شمارنده‌ی «هر ۴ بار» (Core)، سرعتی که با جون کم زیاد می‌شه (Kilofuge) و حمله‌ای که رنگ دشمن‌های زنده‌مونده‌ت تعیینش می‌کنه (Ghost Tree).

> **قانون مجوز:** کد SuperTux و Azimuth (GPL) فقط برای فهمیدن رفتار خونده شد. هیچ کدی کپی نمی‌شه. برای Cave Story و Hurrican (که کدشون رو نخوندیم) هم فقط ایده برمی‌داریم.

## ۱. چی تحقیق شد و چی نشد

| بازی | وضعیت | منبع |
|---|---|---|
| Cave Story | کامل. ۱۴ باس از راهنمای قدم‌به‌قدم | [راهنما](https://www.cavestory.one/guides/cavestory-3lifewalkthru.txt) (باز شد) |
| SuperTux | Yeti و Ghost Tree از کد منبع. صفحه‌ی اخبار فقط می‌گه این دو باس بازطراحی شدن، بدون جزئیات | [yeti.cpp](https://raw.githubusercontent.com/SuperTux/supertux/master/src/badguy/yeti.cpp)، [ghosttree.cpp](https://raw.githubusercontent.com/SuperTux/supertux/master/src/badguy/ghosttree.cpp)، [اخبار](https://www.supertux.org/news/) (همه باز شد) |
| Azimuth | Kilofuge و Forcefiend از کد منبع. README اسم باس نداره | [baddie_kilofuge.c](https://raw.githubusercontent.com/mdsteele/azimuth/master/src/azimuth/tick/baddie_kilofuge.c)، [baddie_forcefiend.c](https://raw.githubusercontent.com/mdsteele/azimuth/master/src/azimuth/tick/baddie_forcefiend.c)، [README](https://github.com/mdsteele/azimuth) (باز شد) |
| Hurrican | فقط یه نقد. اسم باس‌ها پیدا نشد؛ ویکی و لیست باس باز نشد (GitHub مخزن بازی ۴۰۳ داد) | [نقد](https://pekoeblaze.wordpress.com/2013/12/19/review-hurrican-freeware-computer-game/) (باز شد) |
| Toziuha Night | **نشد.** صفحه‌ی itch و مخزن MIT اسم باس ندارن و نمی‌گن باس‌ها از آلکمی استفاده می‌کنن (فقط بازیکن) | [itch](https://dannygaray60.itch.io/toziuha-night-order-of-the-alchemists)، [مخزن](https://github.com/dannygaray60/toziuha-night-oota) (باز شد) |
| Blob Wars: Attrition | **نشد.** صفحه‌ی itch فقط می‌گه «Boss battles» هست. راهنمای بازی پشت محافظ Anubis بود و باز نشد | [itch](https://parallelrealities.itch.io/blob-wars-attrition) (باز شد) |

SuperTux fandom wiki خطای ۴۰۲ داد؛ ادعاهای ثانویه‌ی قبلی (مثل «Yeti با پریدن روی سر کشته می‌شه») فقط تا اونجا که کد تأیید می‌کنه اومده.

## ۲. جدول باس‌ها و دشمن‌ها

«ایده» = ایده‌ی CLAWD. **جدید** = توی `00-decisions.md` نیست. **تقویت** = ایده‌ی موجود رو بهتر می‌کنه. **ردشد** = دلیلش نوشته شده.

### Cave Story ([راهنما](https://www.cavestory.one/guides/cavestory-3lifewalkthru.txt))

| باس | چیکار می‌کنه | چی خاصه | مفهوم برنامه‌نویسی و ایده | وضعیت |
|---|---|---|---|---|
| Balrog (فایت ۲) | فاز ۱ پرواز و تف؛ از ~۱/۳ جون با پرش‌های کوتاه سنگ پرت می‌کنه | باید جای فرودش رو پیش‌بینی کنی، نه حرکتش رو | `pointer prediction`: سایه‌ی نقطه‌ی فرود روی زمین. مناسب NULL فاز ۲ | تقویت (NULL «dangling pointer») |
| Balfrog (فایت ۳) | قورباغه‌های کوچیک و بزرگ می‌ریزه؛ بزرگ‌ها کشنده‌ان | شلوغی دشمن کمکی، یه سمت رو باید تمیز کرد | `triage`: اولویت تمیز کردن | رد شد (فایده‌ی جدید نداره، FORK قبلاً هست) |
| Omega | تو شن قایم می‌شه، چشم‌هاش وقتی بازه آسیب‌پذیره | آسیب‌پذیری با باز بودن چشم | `lazy load`: بازه‌ی آسیب‌پذیری وقتی «لود شده» | رد شد (مثل NULL خسته‌شدن) |
| Frenzied Toroko | ۳ کار: پرتاب بلوک از هوا یا زمین، یا خندیدن | خنده = فرصت ضربه | `idle()` عمدی | تقویت (پنجره‌ی punish، MV0-07) |
| Pooh Black | تو سقف می‌ره و دایره‌ی پر می‌ندازه که کشنده‌ست | بالا شلیک کنی دایره نابود می‌شه | `garbage collect` گلوله‌ی خودش | رد شد (مثل بارون NULL) |
| Monster X | ۴ پاد باید اول از بین برن؛ بعد موشک هدایت‌شونده و غلتیدن | باید پادها رو بزنی تا هسته باز شه | **پورت‌ها**: THE FIREWALL ۴ «پورت» داره؛ بستنشون سپر رو برمی‌داره | **جدید** (THE FIREWALL) |
| The Core | هسته‌ی کوچیک اطراف؛ هر ۴ بار باز شدن، همه رو عقب می‌زنه و گلوله‌ی ۲۰ آسیبی می‌زنه | شمارش مخفی | **`n % 4`**: هر چهارمین پنجره‌ی آسیب‌پذیری، بوس ضدحمله می‌کنه (rate limiter) | **جدید** (THE FIREWALL یا WEB CRAWLER) |
| Ironhead | رد می‌شه، دور بعد از اون سمت برمی‌گرده | باید جای دور بعدی رو حدس زد | `queue` | رد شد (باس شنا/اسکرول است) |
| Heavy Press | لیزر وقتی شلیک می‌کنه زیر توپ باید ایستاد؛ شلیک Curly با تو جمع می‌شه | ضربه‌ی هم‌زمان با یار | `merge` ضربه‌ها: وقتی دو بازیکن هم‌زمان بزنن آسیب جمع می‌شه | تقویت (Co-op و DEADLOCK) |
| Red Demon | اول اندام‌ها رو ایستاده پرت می‌کنه، بعد پریده | حمله‌ی یکسان، دو حالت | `same function, two contexts` | رد شد (تکراری) |
| Misery | فلش می‌زنه: ۵ گلوله، هر فلش سوم بلوک روی سرت می‌ندازه، ۳ کره که اگر زیرشون بری رعد می‌شن، در جون کم دایره‌هایی که تبدیل به imp می‌شن | شمردن فلش‌ها حمله‌ی بعدی رو لو می‌ده | `cron`/شمارنده‌ی قابل‌خوندن | تقویت (CRON) |
| The Doctor | تله‌پورت کنه رو سرت = مرگ فوری | خطر بدون هشدار | `race`: تله‌پورت بی‌هشدار | رد شد (بی‌هشدار با قاعده‌ی «حداقل telegraph» جور نیست) |
| Undead Core + Sue + Misery | سه دشمن هم‌زمان؛ اول Misery رو بکش | ترتیب کشتن مهمه | `priority queue` | تقویت (MERGE CONFLICT، دو سر) |
| Ballos (۴ فرم) | انسان؛ کره‌ی پرنده که هر ۳ پرش مکث می‌کنه؛ کره‌ی چشم‌دار که ساعت‌گرد روی دیوار می‌غلته و وقتی تو سقفه چشمش آسیب‌پذیره؛ فرم آخر فرار ناممکن | آسیب‌پذیری تو یه نقطه‌ی متحرک | **نقطه‌ی ضعف دوار**: WEB CRAWLER فقط وقتی تو سقفه آسیب‌پذیره (`rotating weak point`) | **جدید** (WEB CRAWLER) |

### SuperTux ([yeti.cpp](https://raw.githubusercontent.com/SuperTux/supertux/master/src/badguy/yeti.cpp)، [ghosttree.cpp](https://raw.githubusercontent.com/SuperTux/supertux/master/src/badguy/ghosttree.cpp))

| باس | چیکار می‌کنه | چی خاصه | ایده | وضعیت |
|---|---|---|---|---|
| Yeti | حالت‌ها: RUN، JUMP، IDLE، THROW، STOMP، THROW_BIG، DIZZY. آسیب فقط وقتی پریدن روی سرش در حالت RUN/JUMP/STOMP؛ در IDLE و THROW بی‌اثره. در حالت pinch سرعت و تعداد پرتاب بیشتر و استالاکتیت به‌جای نزدیک بازیکن، الگوی ثابت می‌افته. اگه بازیکن زیر ۱۰۰ px روی زمین وایسته و Yeti ثابت باشه، می‌گیرتش و پرتش می‌کنه | **ضد چسبیدن**: نمی‌ذاره کنار بایستی | **`anti-camping grab`**: THE REVIEWER یا BLOATWARE اگه بازیکن مدت زیادی چسبیده بمونه، اونو پرتاب می‌کنه | **جدید** (THE REVIEWER #1) |
| Yeti – DIZZY | بعد از آخرین جون ۴ ثانیه سر می‌خوره | خستگی آخر مبارزه | `timeout` | تقویت (NULL خسته می‌شه) |
| Ghost Tree | ۹ wisp رنگی (قرمز، سبز، آبی). فقط wisp همرنگ حمله‌ی فعلی رو می‌کشه تو درخت و ریشه‌ی همون رنگ حمله می‌کنه. فقط وقتی RECHARGING و wispها یکی‌یکی می‌ریزن آسیب‌پذیره. در pinch همه‌ی wispها کشیده می‌شن و ۹ تا آزاد می‌شه | **اینکه چی زنده بمونه، حمله‌ی بعدی رو تعیین می‌کنه** | **`state machine driven by data`**: THE LEAK یا DEPENDENCY HELL: دشمن‌های «allocation» که زنده می‌مونن نوع حمله رو انتخاب می‌کنن | **جدید** (DEPENDENCY HELL) |

### Azimuth ([kilofuge](https://raw.githubusercontent.com/mdsteele/azimuth/master/src/azimuth/tick/baddie_kilofuge.c)، [forcefiend](https://raw.githubusercontent.com/mdsteele/azimuth/master/src/azimuth/tick/baddie_forcefiend.c))

| باس | چیکار می‌کنه | چی خاصه | ایده | وضعیت |
|---|---|---|---|---|
| Kilofuge | سرعت = `2 − جون/ماکزیمم‌جون`؛ یعنی از ۱× تا ۲× پیوسته تند می‌شه (حرکت، چشم، پا، cooldown‌ها). هدفش کریستال‌های یخ نزدیکه، نه بازیکن؛ وقتی کریستال تو برد باشه به پایین‌ترینش شلیک می‌کنه. موشک و بمب عقبش می‌ندازن | **سرعت پیوسته** و **طعمه** | **`load average`**: سرعت باس پیوسته با جون عوض می‌شه، نه فقط فازها (مدل سختی). و **طعمه (honeypot)**: WEB CRAWLER «indexing beam» اول به طعمه‌های جایگذاری‌شده شلیک می‌کنه | **جدید** (دو ایده) |
| Forcefiend | بین chase، flee و Force Flurry (۱۰ تا ۱۵ موج) می‌چرخه؛ تخم می‌ذاره (سقف ۴ تا ۸)؛ تخم وقتی به دیوار بخوره دو تا Forceling می‌شه که دور بازیکن می‌چرخن؛ وقتی سقف تخم پر شد، فرار می‌کنه. جون کم = تند‌تر و cooldown کمتر | **سقف تخم** و **تخم‌ریزی با برخورد به دیوار** | **`memory limit`**: وقتی تعداد زیاد شد بوس از ساختن می‌ایسته و می‌گریزه. FORK BOMB با سقف ۱۶ سازگاره؛ «تخم وقتی به دیوار بخوره بازه» برای DEPENDENCY HELL | **جدید** |

### Hurrican ([نقد](https://pekoeblaze.wordpress.com/2013/12/19/review-hurrican-freeware-computer-game/))

| باس | چیکار می‌کنه | ایده | وضعیت |
|---|---|---|---|
| باس مرحله‌ی یخ | فقط وقتی آسیب می‌بینه که موشک یا بمب خودش رو تو موقعیت مشخص بزنی و برگرده طرفش | `catch` برگشتی؛ همون ایده‌ی EXCEPTION و THE REVIEWER | تقویت (catch) |
| باس مخفی | یه باس اضافه تو یکی از مناطق مخفی | باس اختیاری که پلاگین می‌ده | تقویت (FORK BOMB/DEADLOCK/CRON) |

(اسم باس‌ها و رفتار دقیقشون در نقد نیست؛ ننوشتم.)

## ۳. قوی‌ترین ایده‌های جدید (به ترتیب)

| # | ایده | از | کجا می‌خوره | چرا |
|---|---|---|---|---|
| ۱ | **هر چهارمین پنجره، ضدحمله** (`n % 4`) | Core | THE FIREWALL (SOURCE: «rate limiter») | بازیکن تو رو وسوسه می‌کنه حریصانه ضربه بزنه؛ هم کدنویسی ساده، هم با co-op جور، هم قابل‌یادگیری (شمارش) |
| ۲ | **حمله‌ای که از دشمن‌های زنده‌مونده انتخاب می‌شه** (wisp رنگی) | Ghost Tree | DEPENDENCY HELL (DEPENDENCY DEPTHS) و THE LEAK | تصمیم واقعی می‌ده: کدوم «allocation» رو بکشم؟ |
| ۳ | **سرعت پیوسته با جون** (`2 − hp/max`) | Kilofuge | همه‌ی باس‌ها؛ MV0-07 | ساده، به‌جای فاز اضافی؛ هماهنگ با «load average» |
| ۴ | **پورت‌هایی که باید بسته شن** | Monster X | THE FIREWALL (THE NETWORK) | تم کاملاً جوره: ۴ port باز |
| ۵ | **نقطه‌ی ضعف دوار** | Ballos | WEB CRAWLER (THE NETWORK) | آسیب‌پذیری وقتی سقف‌ه؛ بازیکن باید بالا بره |
| ۶ | **سقف تخم و فرار** | Forcefiend | FORK BOMB، DEPENDENCY HELL | جلوی حل‌نشدنی شدن رو می‌گیره، تم «memory limit» |
| ۷ | **طعمه‌ای که باس اول بهش شلیک می‌کنه** | Kilofuge | WEB CRAWLER، THE FIREWALL | پازل تو مبارزه؛ با co-op جوره (یکی طعمه می‌ذاره) |
| ۸ | **ضد چسبیدن (grab)** | Yeti | THE REVIEWER #1 | فاصله‌ی ضربه‌ی نزدیک رو بی‌ریسک نمی‌ذاره |

## ۴. نتیجه برای co-op

- «ضربه‌ی جمع‌شونده» (Heavy Press) و «آسیب فقط وقتی هم‌زمان» (DEADLOCK) تو `04-coop-design.md` بررسی می‌شن.
- ایده‌ی ۷ (طعمه) و ۸ (grab) باید با قانون «حمله‌ی متمرکز به بازیکن دیگه عوض می‌شه» جور باشن.

## ۵. منبع‌ها

همه‌ی لینک‌ها بالا، کنار هر جدول. بازشده: Cave Story walkthrough، SuperTux `yeti.cpp` و `ghosttree.cpp`، صفحه‌ی اخبار SuperTux، Azimuth `baddie_kilofuge.c`، `baddie_forcefiend.c` و `baddie.c`، README Azimuth، صفحه‌ی itch و مخزن Toziuha، نقد Hurrican، صفحه‌ی itch و `winterworks.de` برای Blob Wars/Hurrican. باز نشد: ویکی SuperTux (۴۰۲)، مخزن Hurrican (۴۰۳)، راهنمای Blob Wars (Anubis).
