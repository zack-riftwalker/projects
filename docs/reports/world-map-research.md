# تحقیق طراحی نقشه‌ی دنیای CLAWD

> **نحوه‌ی خواندن اعتبار ادعاها** (مهم)
> - **[V]** = در همین جلسه از یک منبع (مصاحبه / مقاله / خلاصه‌ی سخنرانی) خوانده و تأیید شد.
> - **[U]** = unverified: از دانش عمومی طراحی بازی‌هاست و در این جلسه منبعی که بتوانم نشانش بدهم نخواندم. قبل از اتکا به آن، خودت یا یک agent آن را چک کن.
> - صادقانه: بیشتر متن کامل ویدیوهای GMTK و سخنرانی‌های GDC (Celeste، Tunic) و مقاله‌ی کامل PC Gamer در دسترس من نبود (صفحه‌ها بسته یا ناقص بودند). برای این‌ها فقط خلاصه‌ی صفحه‌ی منبع را داشتم. مثال‌های room-level برای Super Metroid، Hollow Knight، Dread و بقیه عمدتاً [U] هستند، مگر جایی که [V] بگذارم.
> - بازی‌هایی که منبعی درباره‌شان پیدا نشد: Haiku the Robot، Blasphemous، Rain World (طراحی نقشه)، Nine Sols (طراحی نقشه)، Environmental Station Alpha، La-Mulana (hint design). هر چه درباره‌شان نوشتم [U] است.

---

## ۱. خلاصه — ۱۰ درس مهم

1. **نقشه یک پازل بزرگ است**؛ تغییر در یک ناحیه باید جای دوری را عوض کند (Thomas Mahler، Ori) [V]. پس هر ability جدید باید چند «در قفل» قدیمی را باز کند، نه یکی.
2. **اول چیزی را ببین، بعد بتوانی برسی.** بیشترین «آهان»ها از دیدنِ جایی که هنوز نمی‌شود رفت می‌آید (Tunic: دید ایزومتریک برای نشان دادن و بعداً باز کردن راه [V]).
3. **کمی گم شدن عمدی است.** Team Cherry گفت بزرگ‌ترین چالش، نگه داشتن حس کشف همراه با نقشه‌ی مفید بود و گم‌شدنِ اول بازی عمدی بود [V].
4. **نقشه نباید رازها را لو بدهد.** Basso: راز را روی نقشه علامت نمی‌زنم چون دیگر راز نیست [V].
5. **قفل نرم بهتر از قفل سخت** وقتی بازیکن آماده است (Tunic: درها نیمه‌باز، یک مسیر واضح و یک مسیر دیگر بعد از عبور [V]). ولی playtest نشان داد زیادی باز بودن بازیکن را به جای اشتباه می‌برد [V]، پس تنظیم لازم است.
6. **دنیا باید وقتی برمی‌گردی فرق کرده باشد.** Hollow Knight: Forgotten Crossroads بعداً Infected می‌شود و مسیرهای قدیمی بسته می‌شوند [V]. در CLAWD: سطح آب Heap و boss ها.
7. **ناشناخته‌ی «می‌دانم هست، نمی‌فهمم» از «فهمیدم» هیجان‌انگیزتر است** (مدل loose ends از Shouldice) [V]. loose end بکار.
8. **راز عمیق‌تر = جذاب‌تر، ولی باید الگوی بازی را بشکند** (Basso؛ نقد او از Dread که upgrade ها قابل پیش‌بینی بودند) [V]. یک راز باید چیزی باشد که تا الان قانونِ بازی بوده و حالا نیست.
9. **اتاق امن با موسیقی مخصوص** برای تخلیه‌ی تنش (Animal Well save room) [V].
10. **در co-op جدا بودن دو بازیکن اجتناب‌ناپذیر است** و باید برایش طراحی کرد (نقشه‌ی مشترک، دانستن جای دیگری، بازگشت سریع). انتظار نقشه‌ی مشترک در بازیکنان واقعی هست (Remnant II) [V، فقط نقل‌قول انجمن].

---

## ۲. کاتالوگ الگوها

فرمت: **چیست / بازی‌ها / چرا کار می‌کند / کاربرد در CLAWD / هزینه**. در CLAWD «هزینه» یعنی هزینه‌ی agent ها با توجه به معماری فعلی (index.html یک فایل، host صاحب دنیا).

### الف) ساختار کلی

**۱. Hub با چند خروجی نیمه‌قفل**
- چیست: یک ناحیه‌ی مرکزی امن که چند مسیر از آن شروع می‌شود و بعضی بسته‌اند.
- بازی‌ها: Hollow Knight (Dirtmouth/Crossroads)؛ Ori (Wellspring)؛ جزئیات room-level [U].
- چرا: بازیکن همیشه یک «خانه» برای برگشت دارد؛ قفل‌های دیده‌شده هدف می‌سازند.
- CLAWD: SOURCE TREE را hub کن با ۳ خروجی به DEPENDENCY DEPTHS، THE NETWORK (دیده می‌شود، بسته است) و یک در به THE HEAP از بالا.
- هزینه: کم (چیدمان اتاق‌ها).

**۲. وابستگی اول پهن، آخر باریک**
- چیست: dependency graph؛ مارک براون از آن برای مقایسه‌ی نقشه‌های Metroid استفاده می‌کند (NES Metroid پهن، Zero Mission بلند و باریک) [V، فقط وجود مفهوم از Omega Metroid].
- چرا: پهن = انتخاب و حس آزادی؛ باریک = تمرکز روایی.
- CLAWD: بعد از دو zone موجود، ۳ zone موازی باز کن (HEAP، NETWORK، GIT) و فقط PRODUCTION باریک باشد.
- هزینه: کم (برنامه‌ریزی). 

**۳. حلقه‌ها (loop)**
- چیست: مسیری که از سمت دیگر به همان جا برمی‌گردد.
- بازی‌ها: Super Metroid بین Brinstar/Norfair/Maridia [U].
- چرا: بازیکن حس «دنیا یکی است» می‌گیرد؛ هر loop یک «وای، اینجا وصل می‌شود!».
- CLAWD: قانون فعلی «هر zone با ≥۳ zone» عالی است؛ هر loop را با یک فرود یک‌طرفه و یک shortcut از آن طرف ببند.
- هزینه: کم.

**۴. Drop یک‌طرفه ← برگشت از راه دیگر**
- چیست: می‌افتی پایین و راه برگشت را باید پیدا کنی.
- بازی‌ها: براون درباره‌ی شکافی در Dread می‌گوید که Samus از آن می‌لغزد ولی برنمی‌گردد (point of no return) [V، از خلاصه‌ی جست‌وجو؛ متن ویدیو را نخواندم].
- CLAWD: افتادن از THREAD TOWER به THE HEAP؛ برگشت با asansor/shortcut.
- هزینه: کم.

**۵. چیدمان عمودی (vertical stacking)**
- چیست: چند zone بالای هم به‌جای کنار هم.
- چرا: تصور ذهنی ساده («پایین = عمیق‌تر»)، مخصوصاً با صفحه‌ی کوچک.
- CLAWD: ستون عمودی SOURCE TREE ← DEPTHS ← HEAP ← (GIT زیر آن)؛ THREAD TOWER بالا. هر در بالا/پایین از قبل در کد وجود دارد.
- هزینه: کم.

**۶. بازگشت و «پاکسازی دیرهنگام»**
- Basso از پاکسازی بخش‌های جامانده در پایان لذت می‌برد [V] ولی گفت upgrade های قابل‌پیش‌بینی Dread این حس را خراب می‌کنند [V].
- CLAWD: هر upgrade مخفی یک «قانون‌شکن» باشد، نه فقط +HP.
- هزینه: متوسط.

### ب) دیدن قبل از رسیدن

**۷. Visible gate (دیدن مقصد قفل)**
- چیست: ledge/در/گنجی که می‌بینی و نمی‌رسی.
- بازی‌ها: Tunic، Animal Well [U، مثال‌های دقیق]؛ Tunic: دید ایزومتریک برای نشان دادن و بعداً بازکردن [V].
- چرا: «امانتی» ذهن را باز نگه می‌دارد؛ بازگشت = اتمام یک حلقه‌ی ذهنی.
- CLAWD: در SOURCE TREE یک پنجره‌ی شیشه‌ای به THE NETWORK با router چشمک‌زن؛ جای دشت dash-through.
- هزینه: کم.

**۸. Loose end بکار**
- Shouldice: مرحله‌ی دانش (می‌دانم هست) هیجان‌انگیزترین است [V].
- CLAWD: ۳ loose end در zone اول: یک در با قفل «ssh key»، یک ledge بالای dash، یک پیام رمزی.
- هزینه: کم.

**۹. Landmark (نشانه‌ی دور)**
- چیست: یک شکل بزرگ پس‌زمینه که از چند نقطه دیده می‌شود (برج، درخت، سرور).
- بازی‌ها: نمونه‌های کلی [U].
- چرا: جهت‌یابی بدون نقشه؛ مهم برای صفحه‌ی کوچک موبایل.
- CLAWD: «برج Thread Tower» یا «درخت Source» در parallax پس‌زمینه‌ی چند zone. 
- هزینه: کم تا متوسط (هنر).

**۱۰. هویت zone (رنگ + موسیقی + فعل دشمن)**
- Hollow Knight: هر ناحیه یک تصویر ساده دارد (City of Tears: باران پشت پنجره‌های بلند؛ Queen's Gardens: خار) [V]، با اصل «Keep it simple» [V].
- Basso: هر ناحیه‌ی جدید از «hook» یک‌جمله‌ای شروع می‌شود و ایده تکرار نمی‌شود [V].
- CLAWD: یک جمله برای هر zone + یک رنگ palette + یک مکانیک تازه (جدول بخش ۳).
- هزینه: کم.

### ج) دنیای متغیر

**۱۱. تغییر دائمی بعد از boss**
- Hollow Knight: Infected Crossroads [V]. اصل CLAWD «boss ها دنیا را تغییر می‌دهند» همین است.
- CLAWD: THE LEAK بمیرد ← سطح آب در Heap و DEPTHS پایین می‌آید و راه‌ها باز می‌شوند.
- هزینه: متوسط (حالت‌های دنیا باید به guest sync شوند: epoch/flag).

**۱۲. وضعیت‌های چندگانه‌ی یک اتاق**
- همان اتاق قبل/بعد از رویداد (آب بالا/پایین).
- هزینه: متوسط.

**۱۳. اتاق فرار (rising liquid) به‌عنوان تنش**
- در طرح فعلی هست؛ فقط بعد از یک اتاق آرام بگذارش (الگو ۱۸).
- هزینه: متوسط.

### د) نقشه‌ی UI

**۱۴. نقشه‌ی ناقص که پر می‌شود**
- Hollow Knight: نقشه‌ی ساده از cartographer و پر کردن با گشت [V]؛ هدف: هم رمز و هم کمک [V].
- CLAWD: نقشه‌ی هر zone از یک NPC/terminal پیدا می‌شود؛ بخش‌های تکمیل‌نشده خاکستری.
- هزینه: متوسط (UI).

**۱۵. نقشه رازها را نشان نمی‌دهد**
- Basso [V]. ولی یک «نشانگر خالی» برای اتاق‌های دارای loose end شاید خوب باشد (نظر من).
- CLAWD: فقط درها و آیتم‌های دیده‌شده؛ راز هرگز.
- هزینه: کم.

**۱۶. یادداشت/پین بازیکن**
- Prince of Persia Lost Crown: Memory Shard (عکس از محیط برای به‌یاد آوردن) [V، فقط از یک راهنمای کم‌اعتبار؛ تأیید نشده].
- Islets: نقد بازیکنان درباره‌ی نبودِ علامت‌گذاری روی نقشه [V، خلاصه‌ی Vaporlens].
- CLAWD: دکمه‌ی «پین» روی نقشه (۳ نوع آیکن). روی موبایل لازم است چون حافظه‌ی بازی‌های دو نفره ضعیف‌تر است.
- هزینه: کم تا متوسط.

### ه) رازها

**۱۷. هر راز یک سرنخ دارد**
- Basso: «هر چه بگذاری پیدا می‌شود»؛ هرچه عمیق‌تر جالب‌تر [V]. 
- CLAWD: اصل فعلی (پروانه، token trail) را نگه دار و یک لایه‌ی «بدون سرنخ مستقیم، فقط بین دو zone» اضافه کن (Dependency Hell).
- هزینه: کم.

**۱۸. اتاق استراحت با موسیقی خودش**
- Animal Well [V]. 
- CLAWD: bench هر zone یک motif موسیقی متفاوت؛ آرام و بی‌دشمن. 
- هزینه: کم.

**۱۹. لایه‌ی دوم بازی (post-game)**
- Basso: «چند بازی روی هم»؛ شکار راز پس از پایان [V].
- CLAWD: DEPENDENCY HELL = لایه‌ی دوم.
- هزینه: متوسط.

**۲۰. بازی با دانش (knowledge gate)**
- Outer Wilds: Rumor Mode نقاط کشف‌شده را شبکه‌ی «شایعه» نشان می‌دهد [V، از یک بررسی دانشگاهی].
- Tunic: مدل manual [V].
- CLAWD: «لاگ کشف» در terminal: وقتی کد/کلمه‌ای در یک zone پیدا می‌کنی، در zone دیگر قفل را باز می‌کند، بدون ability. 
- هزینه: متوسط.

**۲۱. اتاق «hook» تک‌ایده‌ای**
- Basso و Celeste (فقط خلاصه‌ی موضوعی؛ جزئیات Celeste [U]).
- CLAWD: هر اتاق یک جمله در نام فایل/کامنت: «اینجا فقط X».
- هزینه: کم.

### و) مکانیک‌های دنیا

**۲۲. Glitch the world (Axiom Verge)**
- Address Disruptor: عناصر دیوار/دشمن پیکسل‌پیکسل می‌شوند و رفتارشان عوض می‌شود [V]. هدف Happ: حس «دنیایی فراتر از مرز بازی» [V].
- CLAWD: ability «revert» در GIT HISTORY و «ssh» در NETWORK را مثل Disruptor ببین: دیوار «dead code» را موقتاً به نسخه‌ی قبل برگردان.
- هزینه: متوسط تا زیاد.

**۲۳. سخت‌گیری زمانی (timed gates)**
- NETWORK: port door ها. هزینه: کم تا متوسط.

**۲۴. Shortcut از طرف دور**
- اصل فعلی شما؛ [U] برای مثال‌های دقیق از Hollow Knight/Dark Souls. Tunic هم shortcut را نرم‌کننده‌ی غیرخطی می‌داند [V].
- هزینه: کم.

**۲۵. Fast travel کمیاب**
- یک bench در هر zone (اصل شما). برای هیجان: bench فقط وقتی فعال می‌شود که zone را از دور تا دور رفته باشی.
- هزینه: کم.

### ز) Co-op

**۲۶. نقشه‌ی مشترک + نشانگر شریک**
- Remnant II: بازیکنان از حذف نقشه‌ی مشترک گله دارند [V، انجمن، ناپایدار].
- CLAWD: نقشه از host sync شود؛ نقطه‌ی رنگی P2 روی نقشه. هزینه: کم.

**۲۷. Remote switch (دو اتاق جدا، یک پازل)**
- Shadow Complex می‌خواست دو بازیکن از دو سر نقشه پازل حل کنند و co-op را کنار گذاشت [V].
- CLAWD: دکمه‌ای در اتاق A دری را در اتاق B (با نشانگر روی HUD شریک) باز می‌کند. این برای دیتای شما ارزان است: یک رویداد reliable (`rel`) با k جدید (به i/k دست نزن).
- هزینه: متوسط.

**۲۸. Pull-to-me / پرش به شریک**
- بازی‌های co-op: Guacamelee بازیکنان را «کمی بخشنده» تنظیم کرد [V].
- CLAWD: دکمه‌ی «بیا پیش من» (احضار P2 با تأیید) و revive rule فعلی.
- هزینه: متوسط.

---

## ۳. لحظه‌های امضا (حداقل ۲ برای هر zone؛ هر کدام به تم برنامه‌نویسی وصل است)

| Zone | لحظه‌ی «وای» | تم |
|---|---|---|
| **۱ SOURCE TREE** | (الف) درخت بزرگ پس‌زمینه که در پایان بازی از بالا، از THREAD TOWER، دوباره دیده می‌شود و ریشه‌هایش به DEPTHS می‌رود. (ب) یک `// TODO: bridge` در وسط پل شکسته؛ در پایان بازی کلمه‌ی TODO عوض می‌شود به `// DONE` و پل ظاهر می‌شود. | `TODO` / comment |
| **۲ DEPENDENCY DEPTHS** | (الف) نقشه‌ی `node_modules` که شاخه‌ها را «عمیق‌تر و عمیق‌تر» می‌برد و یک `left-pad` به‌شکل ساختار دارای معنا (کارگر کوچک) سقف را نگه می‌دارد. (ب) وقتی یک package خراب بیفتد، کل شاخه‌ی بالاش می‌ریزد (crumble زنجیره‌ای)، بعد راه تازه باز می‌شود. | dependency tree |
| **۳ THE HEAP** | (الف) بعد از THE LEAK سطح آب پایین می‌آید و اتاق‌های «غرق‌شده‌ی» zone اول ناگهان قابل رفتن می‌شوند (استفاده از الگو ۱۱). (ب) اتاق فرار با آب بالا‌رونده که «garbage collector» دنبالت می‌کند. | memory / GC |
| **۴ THE NETWORK** | (الف) پورت‌ها فقط در «پنجره‌ی زمانی» باز هستند؛ یک packet کوچک بازیکن را می‌برد. (ب) با `ssh` از دیوار عبور می‌کنی و در «طرف دیگر» می‌فهمی همین اتاق از zone اول بود. | ports / ping |
| **۵ THREAD TOWER** | (الف) دو راه موازی (thread) که باید همزمان در هر دو بروی؛ در co-op هر نفر یکی. (ب) race condition: دو ماشین‌های متحرک که اگر ترتیب را درست نزنی فضا را می‌بندند. | concurrency |
| **۶ GIT HISTORY** | (الف) اتاقی که با `revert` به «commit قبلی» اش برمی‌گردد و پلی که الان نیست می‌آید. (ب) درخت branch ها: یک راه «merge conflict» که دو نفر باید دو طرف را همزمان تغییر دهند. | version control |
| **۷ DEPENDENCY HELL** | (الف) دو نسخه از یک اتاق (v1/v2) که با هم سازگار نیستند و باید راه را با جابه‌جایی بین‌شان پیدا کنی. (ب) راز نهایی بدون هیچ سرنخ مستقیم؛ فقط یک «lockfile» در zone ۲ نشانش می‌دهد. | version conflicts |
| **۸ PRODUCTION** | (الف) تایمر deadline روی کل zone و آتش (از پایین)، در عوض همه‌ی shortcut های بازی یک‌جا باز می‌شوند؛ بازیکن بازی را «از بالا» می‌بیند. (ب) آخرین اتاق: یک `git log` از همه‌ی boss ها که با هم می‌چرخد. | deploy / incident |

> این‌ها ایده‌ی طراحی من هستند، نه از بازی‌های دیگر؛ به همین دلیل تأیید‌شده‌ی منبع نیستند.

---

## ۴. تناسب تم (Programming / Computer)

- **Axiom Verge**: ابزاری که «دنیا را خراب می‌کند» و راه تازه می‌دهد [V] ← `revert` و `ssh` را به‌صورت اصلاح موقتی کد طراحی کن، نه فقط قدرت.
- **Tunic**: دستورالعمل ناقصی که فقط وقتی جمع شد معنی می‌دهد [V] ← در CLAWD یک «README.md» پراکنده: صفحه‌ها در zone های مختلف. هر صفحه یک قانون را فاش می‌کند. هزینه‌ی کم.
- **Animal Well**: رازهای چندلایه و کامل‌شدن جمعی [V]. در co-op عالی است: دو نفر نکته‌ها را مبادله کنند.
- **Outer Wilds**: پیشرفت بر پایه‌ی دانش؛ Rumor Mode به شکل شبکه [V]. نسخه‌ی ارزان: لاگ «کشف‌ها» در terminal.
- **Haiku the Robot**: [U] — منبعی نیافتم.
- **Islets**: جزیره‌ها به نقشه‌ی اصلی می‌چسبند وقتی آهنربایشان پیدا شود [V] ← «merge» کردن zone ها روی نقشه.
- **Environmental Station Alpha**: [U] — منبعی نیافتم.

---

## ۵. نکات co-op و موبایل

**انجام بده**
- نقشه‌ی مشترک از host؛ نقطه‌ی شریک روی آن.
- اگر دو بازیکن جدا هستند، یک نشانگر لبه‌ی صفحه جهت شریک را نشان دهد.
- نیمی از پازل‌های «اجباری» باید با یک نفر قابل حل باشد یا حداقل آزمایش شود؛ در غیر این صورت وقتی P2 افتاد، بازی متوقف می‌شود.
- اتاق‌های بزرگ‌تر از یک صفحه روی موبایل: دوربین کمی به جهت حرکت جلو برود.
- Guacamelee: سختی co-op را کمی بخشنده گذاشتند [V]؛ مشکل تازه‌شان پیدا کردن شخصیت خودت وقتی صفحه شلوغ است [V]. در CLAWD رنگ/outline متفاوت P2.

**اجتناب کن**
- پازلی که هر دو باید لحظه‌ای دقیق (<۲۵۰ms) هماهنگ باشند (ping ۵۰ تا ۲۵۰ms).
- قفل برای ability ای که فقط P1 دارد، بدون راه برای P2.
- نقشه‌ی جدا برای هر نفر (گله‌ی Remnant II [V، نقل انجمن]).

---

## ۶. ضدالگوها

1. **نقشه‌ای که همه چیز را نشان می‌دهد** ← رازها را می‌کشد (Basso [V]).
2. **Upgrade قابل‌پیش‌بینی** (نقد Basso از Dread [V]).
3. **زیادی باز بودن قفل نرم** ← بازیکن در جای اشتباه گم می‌شود (Tunic playtest [V]).
4. **راه‌های زیاد = کار زیاد؛ باید همه معنی بدهند** (Guacamelee [V]).
5. **Backtracking طولانی بدون shortcut** [U].
6. **Point of no return بدون هشدار** (براون درباره‌ی Dread [V، نقل غیرمستقیم]).
7. **Zone های همرنگ** [U].
8. **راز بدون سرنخ در بازی با co-op و ping بالا** (کاری که فقط با ویکی حل می‌شود).
9. **Gate سخت در جایی که شریک نمی‌تواند کمک کند** (co-op).

---

## ۷. ۱۵ توصیه — اثر در برابر هزینه

| # | توصیه | اثر | هزینه |
|---|---|---|---|
| ۱ | Visible gate در هر zone (الگو ۷) | زیاد | کم |
| ۲ | Loop + shortcut از طرف دور (۳، ۲۴) | زیاد | کم |
| ۳ | هویت zone یک‌جمله‌ای + palette + موسیقی (۱۰) | زیاد | کم |
| ۴ | نشانگر P2 روی نقشه (۲۶) | زیاد | کم |
| ۵ | Landmark درخت/برج در parallax (۹) | زیاد | کم/متوسط |
| ۶ | تغییر دائمی دنیا بعد از boss (۱۱) | خیلی زیاد | متوسط |
| ۷ | پین روی نقشه (۱۶) | متوسط | کم/متوسط |
| ۸ | README.md پراکنده (Tunic) | زیاد | کم |
| ۹ | Remote switch co-op (۲۷) | زیاد | متوسط |
| ۱۰ | اتاق استراحت با موسیقی (۱۸) | متوسط | کم |
| ۱۱ | نقشه‌ی ناقص که پر می‌شود (۱۴) | متوسط | متوسط |
| ۱۲ | Knowledge gate / لاگ کشف (۲۰) | زیاد | متوسط |
| ۱۳ | Dependency Hell به‌عنوان لایه‌ی دوم (۱۹) | زیاد | متوسط |
| ۱۴ | Glitch-style `revert`/`ssh` (۲۲) | خیلی زیاد | متوسط/زیاد |
| ۱۵ | Pull-to-me (۲۸) | متوسط | متوسط |

---

## ۸. منابع

**تأییدشده (محتوا خوانده شد)**
- Game Informer، ساخت Hollow Knight: https://gameinformer.com/2018/10/15/the-making-of-hollow-knight
- Game Developer، تیم Tunic (content for "no one"): https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic
- Game Developer، Road to IGF Tunic: https://www.gamedeveloper.com/road-to-igf-2023/how-tunic-weaves-wondrous-unknowable-worlds-inspired-by-inscrutable-nes-manuals
- Game Developer، سخنرانی GDC درباره‌ی رازهای Tunic (خلاصه): https://gamasutra.com/design/video-how-the-tunic-developers-built-a-mysterious-world
- Time Extension، ساخت Animal Well: https://www.timeextension.com/features/the-making-of-animal-well-2024s-most-unique-metroidvania
- Nintendo Life، مصاحبه با Basso: https://www.nintendolife.com/features/best-of-2024-i-avoided-almost-all-the-existing-tropes-peeling-back-the-layers-of-animal-well
- Game Developer، Q&A Ori (Mahler): https://www.gamedeveloper.com/design/q-a-designing-the-gorgeous-metroidvania-i-ori-and-the-will-of-the-wisps-i-
- Gaming Trend، Guacamelee co-op: https://gamingtrend.com/feature/interviews/luchadors-demons-and-co-op-qa-with-the-guacamelee-devs (فقط خلاصه‌ی نتیجه‌ی جست‌وجو؛ صفحه باز نشد)
- Co-Optimus، co-op در metroidvania (Shadow Complex): https://co-optimus.com/article/2170/co-op-in-metroidvania-style-games-not-yet.html (فقط خلاصه)

**فقط خلاصه‌ی جست‌وجو (صفحه‌ی کامل را نخواندم؛ ادعا نیمه‌تأییدشده)**
- GMTK، World Design of Super Metroid: https://amara.org/v/C3BE7 (فقط عنوان/فصل‌ها)
- Omega Metroid، dependency graph: https://omegametroid.com/check-out-this-in-depth-world-design-analysis-of-the-metroid-series/
- PC Gamer، How to design a great Metroidvania map: https://www.pcgamer.com/uk/how-to-design-a-great-metroidvania-map (متن مقاله باز نشد)
- Outer Wilds (Wikipedia/بررسی Rumor Mode): https://en.wikipedia.org/wiki/Outer_Wilds
- Axiom Verge (GamesBeat/Nintendo): https://gamesbeat.com/axiom-verge-preview/
- Remnant II انجمن: https://steamcommunity.com/app/1282100/discussions/0/5276582532043201371
- Darksiders Genesis انجمن: https://steamcommunity.com/app/710920/discussions/0/1745643868489894581
- Islets: https://en.wikipedia.org/wiki/Islets_(video_game)
- Celeste GDC (خلاصه): https://gamedeveloper.com/design/video-the-level-design-of-i-celeste-i-

**unverified — منبع اولیه پیدا نشد**
- Haiku the Robot، Blasphemous، Rain World، Nine Sols، La-Mulana، Environmental Station Alpha، Lost Crown (غیر از یک راهنمای کم‌اعتبار)، و همه‌ی مثال‌های room-level برای Super Metroid / Hollow Knight / Dread.
- اختلاف منابع: Game Developer و itch.io سخنران Celeste را «Matt Thorson» نوشته‌اند؛ باید در GDC Vault چک شود.

---

### گام بعدی پیشنهادی
برای بستن بخش‌های [U] می‌توانی بگویی یک agent جداگانه این منابع را بخواند: متن GMTK Boss Keys (Super Metroid / Dread / Hollow Knight)، GDC Vault Celeste و Tunic، و مقاله‌ی کامل PC Gamer. بدون آن، این گزارش یک نقطه‌ی شروع است، نه «عمیق و کاملاً مستند».
