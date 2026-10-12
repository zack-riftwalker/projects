# CLAWD — پژوهش و مشخصات طراحی in-game map

گزارش پژوهشی و پیشنهاد طراحی برای یک 2-player co-op pixel-art metroidvania در browser، با Godot 4 و viewport پایهٔ 384×216.

**تاریخ گردآوری منابع:** 11 October 2026. **دامنه:** هر 16 بازی درخواست‌شده، به‌اضافهٔ Etrian Odyssey برای manual mapping و Deep Rock Galactic و Terraria برای coordination.

**تصمیم محوری:** نقشهٔ CLAWD باید «دفتر ثبت شواهد مشترک» باشد، نه walkthrough: مسیرهای دیده‌شده، درهای شناخته‌شده و موقعیت دو بازیکن روشن؛ محتوای ناشناخته، راه‌حل puzzleها و اسرارِ هنوز کشف‌نشده پنهان.

**روش و حدود اطمینان:** رفتار بازی‌ها از manualهای رسمی، مطالب سازندگان، مصاحبه‌ها، transcriptهای Boss Keys، مستندات و wiki/guideهای مشخص استخراج شده است؛ این گزارش playtest مستقیم یا بررسی buildهای همهٔ بازی‌ها نیست. [Sxx] به فهرست منابع بخش 9 اشاره می‌کند. «unverified» یعنی جزئیات موردنظر در منابع بررسی‌شده تأیید نشده‌اند، نه اینکه قابلیت قطعاً وجود ندارد. قوت/ضعف‌ها، انتخاب «بهترین نمونه»، هزینه‌ها و پیشنهادهای CLAWD داوری طراحی هستند، نه نتایج آزمایش تجربی. نام و وجود abilityهای پیشنهادی CLAWD باید با طراحی واقعی progression تطبیق داده شود.

## 1. Summary — ده درس اصلی

1. **ابهام دربارهٔ مقصد جذاب است؛ ابهام دربارهٔ اتصال اتاق‌ها نه:** هر درِ شناخته‌شده را ثبت کنید، حتی اگر مقصدش هنوز مخفی باشد.
2. **Visited، surveyed و unknown سه وضعیت متفاوت‌اند:** داشتن blueprint نباید معادل قدم‌زدن در اتاق یا جمع‌کردن item باشد.
3. **برای backtracking، «نوع مانع + جای مانع» مهم‌تر از رنگ اتاق است:** الگوی Metroid Dread را با symbol و label غیررنگی پیاده کنید.
4. **نقشهٔ خریدنی خودش reward می‌شود، اما جهت‌یابی پایه نباید هزینه داشته باشد:** برای CLAWD، auto-map رایگان و terminal blueprint اختیاری بهتر از کپی کامل Cornifer است.
5. **Pin بی‌معنا حافظه را نجات نمی‌دهد:** به‌جای چهار رنگ مبهم، markerهایی مانند TODO، ability و HELP با owner مشخص بدهید.
6. **Memory Shards مسئلهٔ حافظه را حل می‌کنند، نه navigation را:** ابتدا metadata note ارزان بسازید؛ screenshot را فقط پس از اثبات نیاز اضافه کنید.
7. **Item reveal را از secret reveal جدا کنید:** sourcemap باید cleanup را آسان کند، نه مسیر رسیدن یا 404 را افشا.
8. **در co-op، نقشه یک ابزار ارتباط است:** P1/P2، ping موقت، مقصد توافق‌شده و shared discoveries از تزئینات مهم‌ترند.
9. **384×216 واحد طراحی تصویر است، نه معیار اندازهٔ touch:** hit target را در CSS/display space کنترل کنید و iconها را با zoom ریز نکنید.
10. **تغییر جهان باید نقشه را هم تغییر دهد، اما نقشه نباید دروغ بگوید:** وضعیتِ نامعلوم را «نیازمند re-scan» بنامید، نه اینکه یک درِ بسته را باز نشان دهید.

## 2. Comparison table — سیستم نقشهٔ بازی‌ها

**شیوهٔ خواندن:** ستون قوت و ضعف برداشت طراحی است. «Marker» میان service icon خودکار و pin دستی تفکیک می‌کند. قابلیت نقشهٔ وبِ طرفداران، قابلیت داخل بازی محسوب نشده است. Blasphemous در این جدول نسخهٔ پس از The Stir of Dawn است؛ Ori and the Will of the Wisps با Ori and the Blind Forest خلط نشده و Axiom Verge به بازی اول اشاره دارد.

| بازی | دریافت / reveal | چه چیزی نشان می‌دهد | Marker و pin | ویژگی ویژه | قوت برای exploration | ضعف / محدودیت مرتبط با CLAWD |
| --- | --- | --- | --- | --- | --- | --- |
| Super Metroid | ثبت اکتشاف + Map Station برای نقشهٔ منطقه | visited در pink، بخش‌های دانلودشدهٔ unexplored در blue؛ station، save، boss و current position [S01] | service icon؛ در نقشه doorway و door-type icon ندارد [S02] | blueprint پیش از بازدید؛ بعضی مسیرهای مخفی حذف می‌شوند | پیدا کردن Map Station خود reward است | مجاورت دو مستطیل اتصال را ثابت نمی‌کند؛ item icon جمع‌شده/جمع‌نشده خوب تفکیک نمی‌شود [S02] |
| Metroid Fusion | نقشه همراه Navigation Room و objective briefing؛ ثبت اکتشاف | visited در pink؛ hidden area کشف‌شده در green؛ objective قابل یادآوری [S03] | objective و service icon؛ pin دستی: unverified | نقشه، terminal و تغییر شرایط station به روایت متصل‌اند | بعد از وقفه، هدف روشن است | تقلید از objective قطعی و پی‌درپی، agency بازی بازتر CLAWD را کم می‌کند؛ این نقدِ تناسب است، نه خطای ذاتی Fusion |
| Metroid Dread | auto exploration + Map Station | point of interest با نام، انواع مانع، hidden-item range درخشان [S04–S05] | marker دستی؛ Icon Highlight برای همهٔ iconهای هم‌نوع [S05] | جست‌وجوی تصویریِ doorهایی که ability جدید باز می‌کند | حافظهٔ موانع را به planning تبدیل می‌کند | density زیادِ icon و terrain را نباید در 384×216 عیناً کپی کرد |
| Hollow Knight | نقشهٔ ناقص خریدنی از Cornifer/Iselda؛ Quill برای update هنگام bench | اتاق‌های ثبت‌شده، سرویس‌های دارای pin؛ current location با Wayward Compass [S06] | چهار مجموعهٔ marker دستی و pinهای سرویس؛ Collector’s Map برای Grubها | سه مرحلهٔ بی‌نقشه → sketch → ثبت اکتشاف؛ نقشه بخشی از اقتصاد | Cornifer و رسیدن به bench لحظهٔ آسودگی می‌سازند | پرداخت برای ابزار پایه، compass slot و update تأخیری برای co-op آنلاین اصطکاک اضافی‌اند |
| Prince of Persia: The Lost Crown | نقشهٔ exploration با ابزار Memory Shards زودهنگام؛ blueprint منطقه از Fariba: unverified در منابع این گزارش | در Guided mode، objective و blocked/available paths؛ Memoryها [S09–S11] | screenshot pin با view/delete؛ تعداد قابل افزایش اما محدود | یادآوری دقیق «اینجا چه دیدم؟» با screenshot | به‌جای حل puzzle، بار حافظه را کاهش می‌دهد | screenshot همگام‌شونده و cloud-save محدودیت واقعی دارد؛ سیستم ظاهراً ساده iteration زیادی می‌خواهد [S10] |
| Ori and the Will of the Wisps | Lupo نقشهٔ منطقه و item-reveal map می‌فروشد | تمایز explored/unexplored و خرید reveal برای Spirit Shard، Life/Energy Cell [S12] | سرویس و collectible icon؛ pin دلخواه: unverified | خرید topology و خرید collectible intelligence جدا هستند | ارتقای نقشه کاربردی و cleanup آسان | reveal زودهنگام همهٔ itemها exploration را به checklist نزدیک می‌کند؛ زمان unlock تعیین‌کننده است |
| Axiom Verge | tile-based auto-map که با حرکت پر می‌شود | درها با white divider، اتصال zone با arrow؛ normal/save/boss/Rusalki با رنگ [S13] | iconهای completion منطقه؛ pin دستی: unverified | دو indicator جدا برای map کامل و item کامل | «کجا بوده‌ام» و «چه چیزی مانده» مخلوط نمی‌شوند | اتکا به رنگ و دو dot بدون label الگوی مناسبی برای موبایل نیست |
| Bloodstained: Ritual of the Night | نقشهٔ اکتشاف قلعه؛ جزئیات trigger پرشدن هر cell: unverified | اتاق‌ها و شبکهٔ قلعه؛ secret roomهای قابل کشف [S15–S16] | custom blue rose marker [S14] | pin دلخواه روی نقشهٔ گسترده | کاربر می‌تواند نقطهٔ بازگشت خودش را ثبت کند | در کنترل‌های گزارش‌شدهٔ 2019، دکمهٔ معمول Back روی نقشه marker می‌گذاشت؛ نمونهٔ مستندِ pin تصادفی [S14] |
| Castlevania: Symphony of the Night | ثبت اکتشاف + خرید unfinished castle map از Librarian [S17] | شبکهٔ قلعه؛ تغییر بزرگ با Inverted Castle | service icon؛ pin دستی دلخواه: unverified | استفادهٔ دوباره از فضای آشنا به‌صورت inverted | خود نقشه حامل reveal ساختاری بزرگ است | map completion تاریخیِ 200.6% را نباید به‌عنوان معیار سادهٔ «همه‌چیز پیدا شد» کپی کرد [S18] |
| Nine Sols | Map Data Chip از Shanhai منطقه، تحویل به Shanhai 9000 در Pavilion [S19] | دادهٔ منطقه و امکان تحلیل بیشتر؛ جزئیات UI شمارنده‌ها: unverified | pin دستی و دقیقاً چه iconهایی با chip باز می‌شوند: unverified | خرید copy یا گرفتن chip با زور در خود جهان معنا دارد | دریافت اطلاعات یک تعامل diegetic است | chip، تحلیل و نقشه سه مفهوم‌اند؛ اگر unlock effect روشن نباشد کاربر نمی‌فهمد چه تغییر کرده |
| Haiku the Robot | از بین بردن Map Disruptor برای visible شدن map منطقه [S20] | map scanning و markerهای گرفته‌شده از Rusty | Rusty markerهای repair/train/bank می‌دهد [S21]؛ pin دستی: unverified | اختلالِ نقشه یک object قابل حل در جهان است | map reveal با fantasy رباتیک سازگار است | محرومیت طولانی از موقعیت partner را از این الگو به co-op منتقل نکنید |
| Animal Well | Map از chest ابتدای بازی؛ update در illuminated areas [S22] | terrain فشرده، gates، mechanisms، fruit، save و چهار flame | Stamps؛ حداکثر 64 در guide؛ Pencil برای رسم یادداشت [S22–S23] | نقشه هم دفتر مشاهده و هم ابزار تحقیق است؛ darkness بر دسترسی اثر دارد | player interpretation حفظ می‌شود | single-pixel information و محدودیت darkness در موبایل/co-op بدون جایگزین مشکل‌سازند |
| Tunic | جمع‌کردن صفحه‌های manual شامل map [S24] | تصویر و اطلاعاتِ authored، tips و secrets؛ نه auto-map معمول metroidvania | یادداشت‌های authored؛ annotation دستی کاربر: unverified | با فهم تازه، صفحهٔ قدیمی معنای تازه پیدا می‌کند | knowledge progression مستقل از ability progression | نقشهٔ هنری و ابهام زبانی برای عملیات لحظه‌ای partner مناسب نیست؛ بخش lore باید جدا بماند |
| Environmental Station Alpha | auto room entry، با استثنای برخی hidden rooms؛ Rough Map برای outline [S26] | رنگ مناطق، مختصات، save/repair/teleporter/boss/item | icon خودکار؛ pin دستی: unverified | بعضی فضاها off-map؛ یک secret-room glyph شبیه -_- | مختصات برای اشارهٔ دقیق و استثناهای محدود برای mystery | بسیاری از dotها فقط با رنگ فرق دارند؛ برای CLAWD symbol و label لازم است |
| Islets | map جزیره‌ها و map جدا برای Sky [S27]؛ روش دقیق unlock: unverified | پنج جزیره و ارتباطشان؛ sky navigation | custom pin و جزئیات legend: unverified | روشن‌کردن magnetic core جزیره‌ها را به هم وصل می‌کند [S28] | فتح جهان روی topology دیده می‌شود | rearrangement کامل نقشه، حفظ marker و spatial memory را پیچیده می‌کند؛ فقط نسخهٔ کوچک آن به‌صرفه است |
| Blasphemous | map exploration؛ UI پس از The Stir of Dawn | منطقه‌ها و area discovery percentage [S29–S30] | custom marker در هر جای map | pixel-perfect zoom و map overhaul | قابلیت استفاده بدون تغییر هویت exploration بهتر می‌شود | «نسخهٔ launch» را با نسخهٔ پس از update مقایسه نکنید؛ zoom pixel-perfect به‌تنهایی touch را حل نمی‌کند |
| Etrian Odyssey، نمونهٔ مکمل | بازیکن paths/walls/events را با Touch Screen رسم می‌کند [S31] | آنچه خود بازیکن ثبت کرده | icon و annotation دستی | خود cartography بخشی از loop بازی است | مالکیت و توجه فعال به فضا | loop آهستهٔ dungeon crawler با action co-op تفاوت دارد؛ رسم اجباری برای CLAWD نامناسب است |
| Deep Rock Galactic، نمونهٔ مکمل | Terrain Scanner از ابتدا | terrain، player و teammate، objective و waypoint [S32] | shared object ping؛ personal waypoint خصوصی [S33] | ارتباط در جهان و نقشه دو لایهٔ متفاوت دارند | پرسش «کجا؟» با یک اشاره پاسخ می‌گیرد | private waypoint را shared ننامید؛ shape/ID را به رنگ class اضافه کنید، نه تقلید صرفِ چهار رنگ |

### 2.1 انتخاب مدل reveal، نه انتخاب یک بازی برای کپی

- **Automatic map:** هزینهٔ حافظه پایین؛ اگر فقط visited geometry را ثبت کند هنوز unknown باقی می‌ماند. برای CLAWD پایهٔ مناسب است. پرداختن اطلاعات ≠ حذف curiosity.
- **Bought map:** یافتن cartographer reward و شخصیت می‌سازد؛ sketch نقشه می‌تواند مقصدهای بالقوه را teaser کند. در Hollow Knight این تجربه با نداشتن map، خرید Quill و bench update ترکیب می‌شود؛ یک قابلیت منفرد نیست [S06، S08]. برای CLAWD اطلاعات اضافه را reward کنید، نه خودِ player location را.
- **Manual mapping:** در Etrian Odyssey رسم بخشی از بازی است؛ در Animal Well نقشهٔ اصلی خودکار است و Pencil لایهٔ annotation اضافه می‌کند. این دو مدل را یکی ننامید [S22، S31]. برای CLAWD pin دسته‌بندی‌شده بهتر از رسم آزاد اجباری است.
- **Map Station:** وعدهٔ «این منطقه بزرگ‌تر از چیزی است که دیده‌ای» می‌دهد. Super Metroid میان visited و downloaded فرق می‌گذارد. یک terminal در هر zone CLAWD می‌تواند همین reward را بدون NPC، shop و quest جدید بدهد [S01].
- **Fog of war:** باید مرز دانستن باشد، نه فیلتر سیاه روی همهٔ UI. اتاق unknown هیچ geometry ندارد؛ surveyed فقط outline دارد؛ visited solid است. «رازی در اتاق visited» هنوز می‌تواند پنهان باشد.

### 2.2 اختلاف شواهد و اختلاف فلسفه

**اختلاف واقعیِ توصیف:** manual رسمی Super Metroid می‌گوید hidden passageways/rooms در download نمایش داده نمی‌شوند؛ Boss Keys نمونه‌هایی از roomهای پشت مانع و hint نقشه را توضیح می‌دهد [S01–S02]. نتیجهٔ قابل اتکا این نیست که station «همهٔ secrets» را نشان می‌دهد یا «هیچ سرنخی» ندارد؛ blueprint بسیاری از roomها را نشان می‌دهد و برخی مسیرهای مخفی حذف می‌شوند. برای CLAWD policy را برای هر room صریح ثبت کنید، نه اینکه واژهٔ secret را مبهم بگذارید.

**اختلاف فلسفه، نه تناقض factual:** Team Cherry از گم‌شدن، مسیر شخصی و کم‌کردن signposting دفاع می‌کند؛ Rémi Boutin در Lost Crown از حذف frustration حافظه و ارائهٔ Guided mode اختیاری می‌گوید [S07–S10]. اولی به جهانِ چندمسیره و rewardهای پراکنده متکی است؛ دومی ابزار کمک را قابل انتخاب می‌کند. برای CLAWD، mystery در محتوا حفظ شود و obstacle recall اختیاری/قابل فیلتر باشد. یک موبایل کوچک و partner منتظر، دلیل خوبی برای تحمیل همان اصطکاک Hollow Knight نیست.

## 3. Feature catalogue — بیست‌وهشت قابلیت

**هزینهٔ نسبی برای تیم کوچک:** low = تغییر rendering یا state ساده با استفاده از دادهٔ موجود؛ medium = metadata جدید، چند UI state، save/network migration یا QA چند ورودی؛ high = capture/storage چندسکویی، puzzle authored یا تغییر اساسی topology. این‌ها زمان‌بندی مهندسی نیستند. shared version معمولاً از local version گران‌تر است. «نمونهٔ برتر» یعنی مناسب‌ترین reference در این مجموعه، نه رتبه‌بندی جهانی.

| # | قابلیت: چیست؟ | نمونهٔ برتر / مبنا | اثر بر exploration | نسخهٔ تماتیک CLAWD | هزینه |
| --- | --- | --- | --- | --- | --- |
| 1 | Auto-map برای roomهایی که واردشان شده‌اید | Axiom Verge [S13] | حافظهٔ مسیر را آزاد می‌کند؛ مقصدهای ندیده حفظ می‌شوند | trace log خودکار؛ مستطیل visited پر می‌شود | low، دادهٔ فعلی موجود است |
| 2 | Blueprint جدا از visited | Super Metroid [S01] | وعدهٔ وسعت، بدون ادعای بازدید | terminal فرمان tree --survey؛ outline عادیِ منطقه | medium |
| 3 | پیدا کردن نقشه در جهان | Hollow Knight [S06] | دریافت اطلاعات خودش reward می‌شود | package اختیاری map-index برای legend/blueprint، نه موقعیت P1/P2 | medium |
| 4 | Manual annotation | Animal Well [S22]؛ رسم کامل: Etrian Odyssey [S31] | مشاهده را فعال می‌کند، ولی کار اضافه دارد | TODO stamp؛ آزادنوشتن را تا بعد از MVP عقب بیندازید | pin: medium؛ freehand: high |
| 5 | Unexplored exit stub | مبنا: کمبود doorway در Super Metroid و نقد Boss Keys [S02] | دعوت به تحقیق، بدون reveal شکل مقصد | خروجی کوتاه با ...؛ target room هنوز hidden | low اگر door data موجود است |
| 6 | Door/obstacle type symbol | Metroid Dread [S04–S05] | «کجا ability لازم بود؟» پاسخ سریع می‌گیرد | iconهای sudo، dash، zip، hook با label | medium |
| 7 | Highlight همهٔ موانع یک نوع | Metroid Dread [S04] | بعد از upgrade چند گزینه می‌دهد، نه یک دستور | filter: compatible with new module | medium |
| 8 | نام در/سرویس هنگام focus | Metroid Dread [S04] | نیاز به حفظ legend را کم می‌کند | tooltip: requires sudo، terminal online | low |
| 9 | Pin دستی با meaning مشخص | Hollow Knight، برای اختیار محل [S06] | intent کاربر را نگه می‌دارد | TODO، ؟، HELP، module؛ نه صرفاً چهار رنگ | medium |
| 10 | Screenshot memory | Lost Crown [S09–S11] | شکل معما را یادآوری می‌کند، راه‌حل نمی‌دهد | snapshot یا stack trace card؛ شروع با metadata | high برای shared screenshot |
| 11 | نقشهٔ hint mode اختیاری | Lost Crown [S09] | امکان کمک بدون تحمیل به همه | Assist: موانع observed قابل استفاده اکنون | medium |
| 12 | Item range hint، نه مختصات دقیق | Metroid Dread [S04] | hunt محلی باقی می‌ماند | sourcemap سطح region: unresolved symbols | medium |
| 13 | Collectible reveal دیرهنگام | Ori / Hollow Knight Collector’s Map [S06، S12] | cleanup را آسان؛ ارزش کشف اولیه حفظ | plugin فقط uncollected memory-fragments مجاز | medium |
| 14 | Map completion و item completion جدا | Axiom Verge [S13] | پرشدن نقشه با خالی‌شدن اتاق خلط نمی‌شود | Coverage و Fragments دو counter | low تا medium |
| 15 | Save point و fast-travel point متمایز | Hollow Knight bench/stag [S06] | برنامه‌ریزی سفر درست می‌شود | bench = bed؛ terminal = >_ داخل قاب | low |
| 16 | مالکیت و identity روی player marker | Deep Rock Galactic [S32] | partner گم نمی‌شود | P1 circle و P2 diamond؛ ID ثابت | low تا medium |
| 17 | Shared contextual ping | Deep Rock Galactic [S33] | گفت‌وگوی طولانیِ «کدام در؟» حذف می‌شود | breakpoint ping روی room یا door | medium |
| 18 | Personal waypoint جدا از shared destination | Deep Rock Galactic [S33] | برنامهٔ خصوصی با تصمیم تیم مخلوط نمی‌شود | local cursor خصوصی؛ party target = مشترک | medium |
| 19 | نام و رنگ zone هماهنگ با جهان | Hollow Knight، تحلیل Boss Keys [S08] | mental map با landmarks وصل می‌شود | path label مانند /net + tint کم‌رنگ | low |
| 20 | Coordinate/reference قابل گفتن | Environmental Station Alpha [S26] | اشارهٔ دقیق بدون spoiler مستقیم | نام کوتاه /net:07؛ grid coords در inspector | low |
| 21 | تغییر topology بعد از رویداد | Islets [S28] | پیشرفت روی خود جهان محسوس می‌شود | mount کردن bridge بین دو directory | high برای جابه‌جایی؛ medium برای edge جدید |
| 22 | Shortcut state و world update | Hollow Knight، Boss Keys [S08] | بازدید دوم سریع‌تر و جهان زنده‌تر | symlink بازشده؛ cache stale پس از deploy | medium |
| 23 | Map blackout به‌عنوان mechanic | Haiku the Robot [S20] | reveal به objective diegetic تبدیل می‌شود | scanner offline فقط برای blueprint اضافی | medium؛ حذف player marker ممنوع |
| 24 | Off-map space محدود | Environmental Station Alpha / Hollow Knight [S06، S26] | استثنای واقعی حس ناشناخته می‌سازد | اتاق 404؛ بیرون از همهٔ counters و plugin | medium |
| 25 | سرنخِ شکل/negative space | ESA برای glyph؛ Tunic برای authored secrets [S24–S26] | بازیکن به خوانندهٔ فعال نقشه تبدیل می‌شود | شکل loop یا {} در چند room؛ puzzle اختیاری | high، شامل level design و playtest |
| 26 | Zoom با detail متناسب | Blasphemous pixel-perfect zoom [S29–S30] | نقشهٔ بزرگ و local decision هر دو خوانا | دو سطح overview/detail؛ iconها screen-sized | medium |
| 27 | Symbol + color، نه color alone | Lost Crown و Game Accessibility Guidelines [S09، S34] | دسترسی بهتر بدون برداشتن راز | code glyph + نام ability؛ grayscale قابل استفاده | low برای asset، medium برای QA |
| 28 | نقشه/راهنما به‌عنوان collectible knowledge | Tunic [S24–S25] | دادهٔ قدیمی با فهم تازه ارزش می‌گیرد | README fragment دربارهٔ legend پنهان، جدا از UX پایه | high؛ فقط پس از تثبیت MVP |

### 3.1 سه الگوی یادآوری بازگشت: کدام را انتخاب کنیم؟

**Metroid Dread: سیستم معنی را می‌داند.** مانع taxonomy دارد و Icon Highlight همهٔ نمونه‌های هم‌نوع را پیدا می‌کند. بهترین راه برای gateهای استاندارد CLAWD: ability ID مشخص، position مشخص و knowledge flag. دقت کنید «این gate با ability X سازگار است» با «کل مسیر اکنون قابل رسیدن است» فرق دارد؛ درِ دیگری در راه ممکن است هنوز بسته باشد [S04].

**Hollow Knight: بازیکن معنی را می‌سازد.** marker محل را نگه می‌دارد ولی اگر رنگش را فراموش کنید context از بین می‌رود. CLAWD باید آزادی pin را نگه دارد اما چهار category نام‌دار و ability tag بدهد. این پیشنهاد اصلاح برای نیاز CLAWD است، نه ادعای اینکه pinهای Hollow Knight labelهای ما را دارند [S06].

**Lost Crown: تصویر context را نگه می‌دارد.** screenshot برای puzzleهایی که taxonomy ساده ندارند عالی است. Boutin می‌گوید limit ابتدا از اندازهٔ cloud-save آمد و بعد به تمیزماندن map و reward دادن shard کمک کرد؛ شروع feature پس از iteration روی 15 قرار گرفت [S10]. برای CLAWD از این عدد کپی نکنید: از 24 shared metadata pin شروع کنید و فقط اگر playtest نشان داد تصویر لازم است 8 snapshot محلیِ اختیاری بیفزایید. limitها پیشنهاد اولیه‌اند.

## 4. Proposed map design for CLAWD

### 4.1 قرارداد اطلاعات: چه چیزی دیده می‌شود و چه چیزی نه؟

این policy مهم‌تر از appearance است؛ باید مشترک میان renderer، save، sourcemap و co-op باشد.

| داده | شرط نمایش | چیزی که عمداً پنهان می‌ماند | دلیل |
| --- | --- | --- | --- |
| room معمولی | پس از ورود هر عضو party: visited؛ یا survey مجاز: outline | محتوا و difficulty اتاق surveyشده | topology teaser بدون spoiler |
| normal door | پس از مشاهدهٔ در یا survey مجاز؛ دیده‌شده بر schematic اولویت دارد | مقصد unknown و شکل اتاق پشت در | راهِ آزمودن واضح؛ reward مقصد باقی |
| unexplored exit | از سمت visited room و فقط اگر exit غیرمخفی شناخته شده | target ID/name و geometry | دعوت به رفتن، نه راه‌حل |
| locked obstacle | فقط پس از encounter؛ type پس از قابل‌شناسایی بودن در جهان | نوع ability ناشناخته: label ؟ | نقشه بیشتر از شخصیت نمی‌داند |
| bench | پس از کشف؛ terminal bench icon متفاوت | benchهای hidden پیش از کشف | جای امن قابل برنامه‌ریزی |
| item دیده‌شده اما نگرفته | marker عمومی memory-fragment در اتاق آن | ترفند رسیدن و platform path | backtracking بدون checklist کامل |
| item هرگز ندیده | پیش‌فرض hidden؛ با sourcemap و policy مشخص | 404 و secret-roomهای undiscovered | exploration اولیه حفظ |
| boss | پس از encounter یا معرفی صریح در narrative | نام، reward، silhouette پیش از معرفی | امکان برگشت بدون پیشگویی |
| secret entrance/room | فقط پس از کشف واقعی؛ سپس room عادی + badge کوچک اختیاری | wall marker پیش از کشف | کشف به observation وابسته می‌ماند |
| 404 | هرگز room polygon، grid coordinate یا target pin ندارد | geometry، item، player coordinate در آن | استثنای معنادار و یکپارچه |
| user pin | فقط روی room/edge شناخته‌شدهٔ قابل نقشه‌سازی | pin در void/404 | کاهش clutter و دورزدن spoiler policy |
| completion | در progress panel، نه بالای هر room | total همهٔ اسرار از شروع بازی | جلوگیری از تبدیل اکتشاف به پرکردن خانه‌ها |

### 4.2 Rendering contract

**Room geometry:** از Rect2i اتاق در world grid استفاده شود؛ نسبت عرض/ارتفاع و جای آن ثابت بماند. اتاق‌های مجاور به‌طور خودکار «متصل» فرض نشوند. اتصال فقط از door/edge واقعی استخراج شود. border یک logical pixel در scale پایه، با camera snapping به integer pixel؛ grid cell size را از bounding box منطقه و zoom انتخاب کنید، نه اینکه همهٔ 120 اتاق را مجبور به fit در نمای default کنید.

**Visited:** fill تیره با zone tint، border روشن. **Surveyed:** داخل خالی، border dashed؛ service/item icon کشف‌نشده ندارد. **Unknown:** هیچ room silhouette ندارد. **Current room:** border دوم یا corner bracket روشن، نه تغییر کامل fill به رنگ player. **Selected room:** dashed cursor مستقل؛ current با selection یکی نیست.

**Door:** شکاف 3 logical pixel در border در detail zoom، در world-side واقعی و offset واقعی در امتداد ضلع، نه الزاماً midpoint. اگر دو door روی یک ضلع هستند، دو slot مستقل بمانند. در zoom پایین، stub/arrow ساده؛ hit testing همچنان object ID را حفظ کند.

**Locked:** روی slot در یا obstacle داخل اتاق، glyph 7×7 با outline تیره؛ status بسته = bar روی glyph. پس از داشتن ability، compatible badge کوچک یا highlight فیلتر؛ پس از بازشدن، bar حذف و edge update شود. برای gate ناشناخته «؟» و برای gateِ نیازمند چند شرط inspector کامل بدهید؛ یک icon کوچک همهٔ شروط را جا نمی‌دهد.

**Internal obstacle:** همهٔ gateها door نیستند. platform بلند یا wall در وسط room باید با normalized local position و obstacle ID ثبت شود؛ renderer لازم نیست terrain دقیق بسازد. pin آن روی room center نباشد تا مانع بالایی و پایینی با هم اشتباه نشوند.

**Icon size:** در detail، service/lock حدود 7–9 logical pixel؛ player glyph حدود 9 logical pixel و ID کنار آن؛ overview فقط 5–7 pixel landmark به‌اضافهٔ P1/P2. این ابعاد نقطهٔ شروع prototype هستند، نه حد دسترس‌پذیریِ touch. در موبایل UI overlay می‌تواند مستقل از pixel-art framebuffer بزرگ شود.

**اولویت هنگام overlap:** P1/P2 → active ping/party target → terminal/bench → selected lock → سایر obstacleها → itemها → pinهای غیرفعال. اگر تعداد زیاد شد cluster با عدد و inspector list؛ icon را به 2 pixel تبدیل نکنید. playerها در یک room: cluster ثابت P1+P2؛ detail نمای offset واقعی در صورت وجود دادهٔ position.

### 4.3 Zone palette، theme و legend

هفت path در brief نمونه‌اند؛ نام zone هشتم هنوز معلوم نیست. **نباید برای آن اسم را قطعی فرض کرد.** پیشنهاد رنگ اولیهٔ هر zone، با identity اصلیِ path label و environment landmark:

| Zone | theme بصریِ پیشنهادی نقشه | accent پیشنهادی |
| --- | --- | --- |
| ~/src | مسیرهای تمیز و corridorهای code | blue #56B4E9 |
| ~/node_modules | شبکهٔ متراکم dependency | violet #CC79A7 |
| /proc/heap | حوضچه و تودهٔ memory | amber #E69F00 |
| /net | ارتباط و switch | teal #009E73 |
| /dev/threads | shaftهای موازی | yellow #F0E442 |
| .git | branch و merge | coral #D55E00 |
| /var/prod | pipeline و deployment | pale cyan #A6DCE8 |
| zone 8، نام TBD | پس از تصمیم art direction | neutral #B8BDC9 |

این palette ادعای «تمایز امن هشت رنگ برای همه» ندارد. فقط یک candidate است؛ low-opacity fill، border روشن، نام zone و symbolها identity را کامل می‌کنند. در grayscale نیز باید visited/surveyed، P1/P2 و lock type قابل تشخیص باشند. زمینهٔ پیشنهادی #10151C؛ رنگ سفیدِ text #F3F5F7؛ مقادیر نهایی با contrast و دستگاه واقعی آزموده شوند [S34، S36].

**Ability glyphهای پیشنهادی، نه abilityهای تأییدشدهٔ بازی:**

| نوع مکانیکی | نام تماتیک نمونه | glyph / نمایش غیررنگی | label در inspector |
| --- | --- | --- | --- |
| permission gate | sudo | key + S | Requires sudo |
| dash barrier | async dash | دو chevron >> | Requires dash |
| narrow passage | zip / compress | مربع فشرده [] | Requires compress |
| grapple point | pointer / hook | hook خمیده | Requires hook |
| heat/hazard gate | sandbox shield | shield | Requires shield |
| شرط co-op | thread sync | دو نقطهٔ متصل | Two players required |
| شرط unknown | unknown module | ؟ | Unknown requirement |

حدود شش خانواده برای map مناسب‌تر از یک icon جدا برای هر spell است. اگر abilityهای واقعی متفاوت‌اند همین mapping table، asset و label عوض شوند؛ logic به string نام نمایشی وابسته نباشد.

**Legend:** نوار دائمی فقط P1/P2، bench و terminal؛ بقیه با دکمهٔ Legend/Help در یک sheet. focus روی icon همیشه نام + state + action را نشان دهد. فونت pathها LTR باشد؛ حتی اگر UI بازی بعداً فارسی شد، code/pathها bidi-isolated بمانند. هیچ مفهوم مهم صرفاً به قرمز/سبز یا blink وابسته نباشد.

### 4.4 دریافت نقشه و reveal

**MVP:** از اولین لحظه auto-map رایگان؛ position هر دو عضو party رایگان؛ در ورود room، هندسه و خروجی‌های معمولیِ مجاز ثبت شوند. مشاهدهٔ obstacle context را به journal اضافه کند. نیازی به map shop، charm slot یا یافتن Cornifer جدید نیست.

**Terminal upgrade:** اولین terminal هر zone امکان Download index می‌دهد؛ فقط normal room blueprintهای دارای survey_allowed. secret، 404، item و typeِ gate ندیده را شامل نشود. یک reveal wipe کوتاه با متن indexing ... → index cached؛ reduced-motion حالت فوری. چون terminal بنچ ویژهٔ موجود است، کمترین محتوای جدید را لازم دارد.

**چرا bench-only update نه؟** CLAWD دو نفرِ آنلاین دارد؛ یکی ممکن است هنگام انتظار دیگری نقشه را بخواند. تاخیر در ثبت geometry نه mystery محتوا بلکه uncertainty مشترک می‌سازد. bench را checkpoint/save نگه دارید، نه تنها فرصت دیدن trace [S06، S08].

**گزینهٔ دوم، پس از MVP:** packet/map-index collectible در نزدیکی junction، که survey بخشی از zone را reward می‌کند. برای gatekeeping نقشهٔ پایه استفاده نشود. اگر صرفاً terminal کامل‌تر همان کار را می‌کند feature جدید نسازید.

### 4.5 Pins، journal و بازگشت با ability

- چهار action اصلی: **TODO**، **؟ / investigate**، **HELP**، **ability tag**. نوع پنجم لازم نیست: shared destination وضعیت یک pin است، نه category جدید.
- حد اولیهٔ 24 shared pin در کل session؛ هر pin owner P1/P2، room/door ID، category و created sequence دارد. حذف فقط برای owner؛ partner می‌تواند درخواست Done بفرستد. در صورت پرشدن، replace/delete chooser؛ هیچ حذف خاموشی نباشد.
- روی room ثبت‌شده tap/focus → card → Add pin. door pin به همان door ID snap شود. Back همیشه Back، نه Add pin [S14].
- **Quick note در gameplay:** یک action قابل remap، آخرین obstacle observed نزدیک player را ثبت می‌کند؛ card: /net:07 — upper-right gate — requires dash. اگر هیچ obstacle نزدیک نیست room TODO می‌گذارد.
- بعد از unlock module، notification یک‌باره: «3 موانع ثبت‌شده با dash سازگارند — View». این عدد فقط از observed data محاسبه شود؛ شمارندهٔ مخفی جهان را لو ندهد.
- filter compatible و ability type؛ فهرست کوتاه zone:room + glyph. **Compatible** یعنی توان عبور از آن مانع را دارید، نه اثبات قابل‌دسترس‌بودن مسیر. اگر route reachability اجرا نشده label Reachable نگذارید.
- یادداشت دستی هیچ‌وقت بازشدن در را override نمی‌کند؛ pin تاریخی باقی می‌ماند اما card می‌گوید gate opened؛ پیشنهاد Done با undo.
- screenshotِ مشترک فعلاً حذف از scope: local thumbnail هم نیازمند capture، persistent storage، crop و input flow است. metadata card نخستین پاسخ به memory است؛ Lost Crown reference برای فاز بعد است، نه MVP [S10].

### 4.6 Completion و sourcemap plugin

**دو سنجهٔ جدا:**

1. **Coverage:** تعداد map-eligible roomهای visited / تعداد map-eligible roomها. surveyed در numerator نیست. معیار room است، نه pixel یا tile؛ لازم نیست گوشهٔ هر room را لمس کنید.
2. **Fragments:** تعداد collectibleهای واجد tracking جمع‌شده / total همان دسته؛ خرید blueprint یا گذاشتن pin به آن امتیاز نمی‌دهد.

پیش از کشف terminal یک zone، فقط تعداد visited و collected نشان دهید، نه denominator کاملِ منطقه. پس از terminal، total roomهای survey مجاز را با label **Indexed rooms** می‌توان نشان داد؛ این را با Coverage کل zone یکی نگیرید. پس از ending یا نصب upgrade مخصوص cleanup، Coverage نهاییِ map-eligible و total fragments فعال شود. اعداد بدون denominator و اصطلاحات مبهم مانند 92% complete ممنوع.

**404:** room از Coverage denominator و numerator خارج است؛ هر reward آن از Fragments denominator هم خارج شود. آن را Easter egg مستقل نگه دارید، نه item لازم برای 100%. اگر countِ کل 120 در داده شامل 404 باشد، denominator باید با policy فیلتر شود، نه hard-code عدد 120. در report UI وعدهٔ «100% همهٔ اسرار» ندهید؛ بگویید **100% indexed coverage**.

**Sourcemap، پیشنهاد دو سطح:**

- سطح A: در visited map-eligible room فقط generic hint برای uncollected fragments؛ قبل از unlock هیچ مکان item ندیده نشان داده نشود. ایده از range hint Dread [S04].
- سطح B، late-game/پس از ending: icon دقیق room-level برای fragmentهای باقی‌مانده در geometry شناخته‌شده. بازی rectangle-room است؛ مختصات داخل room لازم نیست راهِ platforming را افشا کند.
- secret room undiscovered: بدون polygon و بدون icon؛ پس از کشف معمولاً eligible می‌شود. terminal survey نباید این قاعده را دور بزند.
- no geometry، no icon: plugin روی فضای unknown «نقطهٔ شناور» نسازد. اگر محصول تصمیم دارد تمام اسرار عادی را در endgame reveal کند، یک unlock و هشدار مستقل لازم است؛ 404 همچنان exclude.
- collected state از authoritative save خوانده شود؛ آیتم جمع‌شده فوراً در هر دو client خاموش. یک پیشنهاد برای فیلتر Collected اختیاری، با glyph hollow؛ default فقط باقی‌مانده‌ها.

### 4.7 404 و map tricks، بدون تخریب اعتماد

**404 contract:** map درون این room یک صفحهٔ ثابت **404 Not Found — path is intentionally unindexed** نشان می‌دهد؛ دکمهٔ Close، player status و help عادی باقی می‌مانند. با crash/connection failure یکسان طراحی نشود: پیام «connection online» می‌تواند استثنا را روشن کند. artifact glitch کوتاه و قابل خاموش‌کردن، نه flicker دائمی.

بازیکن بیرون اتاق، partner را به‌صورت «P2 — unindexed space» در status row می‌بیند؛ هیچ coordinate، edge-arrow دقیق، bounding-box extension یا auto-centering بر نقطهٔ hidden وجود ندارد. دعوت «برگرد/کمک» ممکن است، اما ping نمی‌تواند مقصد هندسی 404 بسازد. last known room فقط اگر واقعاً پیش از ورود ثبت شده، با label **last known**؛ نه live position. map geometry هرگز برای 404 تولید نمی‌شود حتی پس از بازدید.

داستانِ راه فرار نباید به map متکی باشد: در خود room landmark/exit واضح و جهت بازگشت وجود داشته باشد. بازیکن از ترس گم‌شدن گوشی را کنار نگذارد. 404 فقط یک استثناست؛ اگر چندین room از نقشه حذف شوند، علامت unknown با نامطمئن‌بودن نقشه خلط می‌شود [S06، S26].

**سه trick کم‌هزینه‌تر از نقشهٔ متحرک کامل:**

- **Symlink shortcut:** یک door جدید میان دو room موجود پس از فعال‌سازی؛ animation کوتاهِ edge و log: symlink mounted. roomها جابه‌جا نمی‌شوند.
- **Git branch/merge:** در .git دو مسیر دیده‌شده دور می‌زنند و یک connection تازه loop را می‌بندد؛ بازیکن نتیجه را روی نقشه می‌فهمد. تغییر graph edge ارزان‌تر از Islets-style rearrangement است [S28].
- **Stale cache بعد از deploy:** رویداد /var/prod فقط یک subregion مشخص را stale می‌کند؛ موانع آن با ?/stale state تا مشاهدهٔ تازه. geometry شناخته‌شده پاک نشود. این برداشت طراحی از world changes است، نه ادعای اینکه Hollow Knight چنین cache UI دارد [S08].

**Shape secret، فاز اختیاری:** چیدمان چند room در ~/src شبیه {} یا یک loop ناقص می‌شود؛ NPC/README اشاره می‌کند «one branch never returns». negative space سرنخ است، نه proof: همهٔ empty grid cellها secret نیستند. این puzzle باید مستقل از 404 باشد تا silhouette آن را لو ندهد. از Tunic فقط اصلِ «دانش تازه، نگاه تازه» گرفته شود؛ golden-path/manual puzzle را با room map یکی ندانید [S24–S25].

### 4.8 Fast travel میان terminalها

**ورودی:** تعامل با terminal bench → سه action: Rest، Download index، Connect. map tab بیرون terminal می‌تواند مقصد را preview کند، اما teleport button disabled با توضیح **Use a terminal**. bench عادی هرگز در travel list نیست.

**UI هشت مقصد، بدون نیاز به tap روی icon ریز:** list از terminalهای activated، هر ردیف path، icon >_، short room label و state. current terminal غیرفعال و مشخص؛ locked destination بدون افشای نام zone ناشناخته. انتخاب مقصد → preview map کوچک با terminal highlight → confirm. در 384×216 چهار row در هر page؛ روی phone row height در display space بزرگ‌تر شود.

**Travel فردی، پیشنهاد default:** فقط requester جابه‌جا شود، آن هم هنگامی که خودش در terminal فعال است. partner notification دریافت کند؛ هیچ teleporter-to-partner شبیه Wormhole Potion اضافه نشود چون brief travel را به terminal محدود کرده است. Terraria صرفاً reference برای affordanceِ انتخاب teammate روی map است، نه مجوز نقض محدودیت CLAWD [S39].

**Travel با هم:** هر دو باید در terminalهای فعال، زنده و خارج از combat باشند؛ requester گزینهٔ Travel together می‌زند؛ طرف دوم destination path را می‌بیند و Accept/Decline دارد. زمان پیشنهادی پاسخ 10s؛ timeout/cancel هیچ‌کس را منتقل نکند. approve state با room change، damage/combat یا disconnect invalid شود. بررسی نهایی eligibility و انتقال توسط authority جلسه؛ یک operation برای دو نفر، نه دو RPC مستقلِ غیرقابل rollback.

اگر بازی قرار است هیچ‌گاه playerها را جدا نکند، این جریان را به «هر دو روی همان terminal» محدود کنید. استقلال حرکت و shared ability در brief مشخص نشده‌اند؛ طرح پیش‌فرض این گزارش split exploration و journal مشترک است. چنین تصمیمی باید قبل از پیاده‌سازی network UI ثبت شود.

### 4.9 Layout دقیق 384×216

**Desktop/gamepad detail view، اندازه‌ها در logical pixel:**

- header: x=0، y=0، w=384، h=24؛ Map، path منطقه، Close.
- map canvas: x=8، y=32، w=264، h=144.
- inspector: x=280، y=32، w=96، h=144؛ selected room/obstacle، status، pin action؛ متن wrap و نهایتاً چند خط کوتاه.
- footer: x=8، y=184، w=368، h=24؛ Zoom، Center، Pins، Legend؛ فاصلهٔ 8 از لبهٔ پایین.
- Default بازشدن: current zone، detail zoom و self-centered؛ دفعهٔ بعد آخرین pan/zoom محلیِ همان zone حفظ، با Center همیشه در دسترس.

```
+------------------------------------------------+
| MAP       ~/src                 P1/P2    Close |
+----------------------------------+-------------+
|                                  | ~/src:07    |
|   [visited]--[P1]--...            | upper gate  |
|        |       S                 | requires    |
|   [bench]  [surveyed]             | sudo        |
|        |                         | [Pin]       |
|   [P2 + >_]                      | [Ping]      |
|                                  |             |
+----------------------------------+-------------+
|  -  +   Center    Pins    Legend   Zoom: detail |
+------------------------------------------------+
```

این ASCII فقط structure است، نه نمای scale واقعی. rectangleهای room در canvas از world transform می‌آیند؛ room labelها فقط برای selection، terminal یا zoom detail لازم‌اند. نشان‌های S و ... در mock-up با asset واقعی و legend جایگزین می‌شوند.

**Phone view:** inspector دائمی حذف؛ canvas بین header و footer تمام عرض؛ tap selection یک bottom sheet روی canvas باز می‌کند. حداقل CTAهایی که همیشه می‌مانند: Close، +، −، Center و More. Pins/Legend/partner focus زیر More یا sheet، نه هشت دکمهٔ کوچک در یک ردیف. overview نقشهٔ همهٔ zoneهای کشف‌شده را نشان دهد؛ tap zone → detail. نقشه هرگز خودکار rotate نشود.

### 4.10 قرارداد داده و مسیر پیاده‌سازی برای Godot

**یک registry واحد؛ نه سه سیستم مستقل برای map، sourcemap و travel.** این اسکلت specification است، نه کدِ tested:

```
RoomDef
  id, zone_id, grid_rect
  map_policy: normal | secret | never
  survey_allowed, completion_eligible
  bench_id?, terminal_id?, collectible_ids[]

DoorDef / ObstacleDef
  id, room_id, side?, side_offset?, local_position?
  target_room_id?, requirement_ids[]
  secret, world_state_key?

PartyMapState
  visited_room_ids, surveyed_room_ids
  observed_exit_ids, observed_obstacle_ids
  identified_requirement_ids
  opened_edge_ids, discovered_secret_ids
  activated_terminal_ids, collected_item_ids
  observed_item_ids, discovered_bench_ids, encountered_boss_ids
  unlocked_party_ability_ids
  shared_pins[], agreed_destination?, revision

LocalMapUIState
  zone, zoom, pan, filter, selection, last_focus
```

**Policy اول، rendering بعد:** never از room renderer، sourcemap، counters، search، bounds calculation، auto-fit و spatial ping حذف شود. برای secret، survey_allowed=false مگر آن room واقعاً کشف شده باشد. raw world graph را مستقیم به UI بدهید فقط اگر تمام مصرف‌کننده‌ها policy filter یکسان دارند.

از rectangle/line drawing و یک icon atlas با nearest filtering شروع کنید؛ نیاز به texture capture، shader map یا render هر level به تصویر نیست. base geometry فقط هنگام zone/knowledge تغییر کند؛ player/ping overlay مستقل update شود. 120 room دلیل ساخت mega-cache یا minimap terrain renderer نیست. نیاز به نسخهٔ Godot دقیق وجود دارد؛ 4.3+ single-thread Web با 4.2 محدودیت یکسان ندارد. مستندات stable از WebGL 2/Compatibility، overhead موبایل، محدودیت persistence و توقف tab پس‌زمینه می‌گوید [S38].

**پذیرش فنی:** schema_version برای save؛ IDs پایدار هنگام rename zone؛ terminal_id از bench_id قابل تشخیص؛ هر door normal دو سر سازگار یا one_way صریح؛ collected state قابل merge؛ pin و travel request قابل retry بدون duplication. test هر roomِ never باید assert کند در map-eligible bounds و counters دیده نمی‌شود.

## 5. Co-op — نقشهٔ مشترک، دوربین خصوصی

### 5.1 Position و identity

**P1/P2 از player slot ثابت می‌آید، نه از «خودم/دیگری» یا platform.** در هر دو دستگاه P1 همان شخص است. P1 circle با 1، P2 diamond با 2؛ رنگ پیشنهادی orange و light-blue، با border تیره/روشن قابل تنظیم. خودِ کاربر halo اضافه دارد تا partner identity ثابت بماند. رنگ‌ها از zone fill مستقل‌اند [S32، S34].

بازیکن خارج map viewport: edge tag شامل P2 + path zone؛ action Focus partner. بازیکن در zone دیگر: روی overview badge و در header status «P2 /net:07». arrow در detail فقط جهت روی geometry شناخته‌شده را نشان دهد؛ نه خطی که secret route یا 404 را لو دهد. فاصلهٔ هندسی بدون route معنیِ «سه اتاق راه» ندارد؛ تا pathfinding ندارید room-distance ادعا نکنید.

**Blink فعلی را اصلاح کنید:** player هرگز کامل محو نشود. pulse اختیاریِ halo، با reduced-motion ثابت. labelها در overlap اولویت دارند. disconnected partner marker به last-known hollow glyph تبدیل شود و status «connection lost»، نه live dot یخ‌زده.

### 5.2 Shared discovery، local view

- union از visited rooms، observed obstacles و activated terminals در **همین save/session**؛ هیچ‌یک مجبور به دوباره‌نقشه‌برداری راهی که partner کشف کرده نیست.
- pan، zoom، filters، inspector و cursor **local**؛ حرکت cursor P1 صفحهٔ P2 را تکان ندهد.
- استفاده از ability برای gate در این proposal party-unlocked فرض می‌شود؛ اگر game abilityهای فردی دارد، tooltip روشن بگوید P1 only / P2 only / both required و Compatible برای player انتخابی حساب شود.
- join مجدد full snapshot با revision؛ deltaهای پس از آن با sequence؛ room/item unlock idempotent. pin operation owner و operation ID دارد. session authority با معماری موجود بازی باشد، نه فرض قطعیِ dedicated server.

### 5.3 Ping، pin و destination سه چیز متفاوت‌اند

| ابزار | طول عمر و visibility | action پیشنهادی | محدودیت |
| --- | --- | --- | --- |
| Ping | 6s، برای هر دو | روی room/door: Go here، Wait، Help، Look | یکی فعال برای هر player؛ rate limit اولیه 1/s |
| Pin | پایدار در save مشترک | TODO یا ability note با owner | 24 مشترک در prototype؛ delete/undo |
| Party destination | تا cancel/arrival | انتخاب pin یا terminal → Set destination؛ partner تأیید | در header و map؛ مسیر خودکار نه |

اعداد lifespan/limit target آزمایش‌اند، نه standard industry. ping یک pulse کوتاه + label + صدای اختیاری دارد؛ اطلاعات صوتی با متن/شکل تکرار شود. acknowledgement یک tick کنار ping و پیام P2 acknowledged؛ لازم نیست chat، emoji wheel بزرگ یا voice بسازید.

**Controller:** focus روی object → Ping action؛ باز کردن 4-action menu با press معمولی، نه long-hold اجباری. **Touch:** tap object → sheet → Ping؛ tap روی canvas فقط select، نه broadcast. کمک فوری در gameplay با دکمهٔ HELP مستقل که current room را ping می‌کند؛ نقشه برای هر distress اجباری نیست.

### 5.4 Pause semantics، تصمیم حیاتی

در online co-op، بازشدن map یک player **نباید tree را برای partner ناگهانی pause کند**. نقشهٔ local حرکت requester را متوقف می‌کند، اما زمان جهان ادامه دارد؛ هیچ invulnerability تازه‌ای نمی‌دهد. status «Map open» به partner؛ بازکردن map وسط combat باید warning/امکان بستن فوری داشته باشد. map در terminal/bench محیط امن‌تری برای planning دارد.

**اگر pause مشترک لازم است:** Request pause → partner Accept → authority freeze → Resume برای هر دو. همان status در دو دستگاه، و disconnect/timeout policy مشخص. این feature medium cost دارد و به gameplay/network می‌رسد؛ آن را به‌عنوان تغییر کوچک drawing حساب نکنید.

محدودیت browser مستقل است: tab background ممکن است process را متوقف و network را disconnect کند [S38]. گوشی با بازکردن notification/رفتن به app دیگر می‌تواند stale شود؛ heartbeat/server timestamp وضعیت partner را مشخص کند. browser background با «هر دو pause را پذیرفتند» برابر نیست.

## 6. Phone و touch — مشخصات ورودی و خوانایی

### 6.1 دو coordinate space را جدا کنید

**Logical pixel:** برای pixel-art 384×216. **CSS/display pixel:** برای اندازهٔ فیزیکیِ UI در browser. **Device pixel:** برای density پنل؛ معیار touch نیست. Android guidance حداقل پیشنهادی 48dp با spacing را بیان می‌کند؛ W3C برای Target Size Enhanced مقدار 44×44 CSS pixel و استثناهای مشخص دارد. این واحدها را عیناً یکی ننامید [S37، S40].

برای web CLAWD target محصول را **حداقل 48×48 CSS px، gap حدود 8 CSS px** بگذارید و روی device اندازه‌گیری کنید؛ این انتخاب محافظه‌کارانهٔ طراحی است، نه ادعای اینکه 48dp تعریفاً همان 48 CSS px است. اگر UI داخل canvas مقیاس s دارد، hit width در logical space باید حداقل 48/s باشد؛ حتماً transform و letterbox را حساب کنید. در s=2، دکمهٔ 24 logical pixel هدف 48 CSS pixel دارد؛ در s=1 همان دکمه کوچک است. راه‌حل: mobile UI بزرگ‌تر/overlay مستقل، نه فقط integer upscale کل بازی.

### 6.2 Gestures با جایگزین یک‌دستی

- one-finger drag روی canvas = pan؛ inertial fling پیش‌فرض خاموش، چون room selection دقیق مهم‌تر از حس scrolling است.
- tap روی room/door = select و inspector؛ drag از threshold اولیهٔ 8 CSS px عبور کند تا tap محسوب نشود. این threshold با playtest تنظیم شود.
- pinch = zoom حول midpoint انگشت‌ها، با حفظ world point؛ دو سطح نهایی pixel-aligned. +/− همان کار را بدون نیاز به دو انگشت انجام دهد.
- double-tap و long-press action حیاتی نداشته باشند. اگر shortcut هستند، همان action از sheet قابل دسترسی باشد.
- پس از pan، follow-self خاموش؛ Center آن را برمی‌گرداند. حرکت partner یا دریافت ping نباید دوربین را بدون درخواست برباید.
- pinch/drag خارج canvas به button bar/inspector نفوذ نکند. در container بازی browser pan/zoom handling کنترل شود؛ تنظیم touch-action فقط برای ناحیهٔ بازی، نه کل سایت.

### 6.3 نگاشت ورودی و zoom برای prototype

این bindingها پیشنهاد اولیه و قابل remap هستند؛ با actionهای واقعی بازی قبل از freeze تطبیق داده شوند. همهٔ shortcutها جایگزین visible button دارند.

| Action | Keyboard / mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Open/Close map | M؛ Escape برای Back | View/Select؛ B برای Back | Map؛ Close |
| Pan | drag؛ arrow keys وقتی canvas focus دارد | Left Stick | one-finger drag |
| Zoom | wheel یا +/−، حول cursor/selection | LB/RB، حول selection | pinch یا +/− |
| Select / inspect | click؛ Enter روی focus | D-pad میان POIهای visible؛ A برای inspect | tap room؛ sheet |
| Ping menu | X روی selection | X | sheet → Ping |
| Add pin | P روی selection | Y | sheet → Add pin |
| Center self | C یا دکمهٔ Center | دکمهٔ Center با focus و A | Center |
| UI focus | Tab/Shift+Tab؛ در canvas arrow=pan، در UI arrow=focus | focus bar/inspector با D-pad در mode مربوط | مستقیم با tap |

**Back priority:** ابتدا menu/sheet، سپس selection inspector، سپس خود map؛ همان input هرگز mutation یا pin نمی‌سازد. action label از binding فعلی گرفته شود، نه حرف hard-code. تغییر mode Canvas/UI باید highlight واضح داشته باشد؛ بهتر است D-pad وقتی sheet باز است فقط در sheet عمل کند.

**Zoom prototype:** یک واحد world grid در detail برابر 8 logical px؛ + آن را به 16 و سپس 32 می‌رساند. این اعداد برای آزمون اولیه‌اند؛ اگر کوچک‌ترین room چندین grid cell دارد، scale باید مطابق geometry واقعی تنظیم شود. overview auto-fit فقط geometry مجازِ zoneهای شناخته‌شده را می‌گیرد و به نزدیک‌ترین scale پله‌ای مناسب گرد می‌کند؛ bounding box هرگز raw world یا 404 را شامل نشود. در overview roomها را می‌توان خلاصه کرد؛ iconهای P1/P2 و terminal اندازهٔ screen-space ثابت دارند. pinch هنگام رهاشدن به سطح پله‌ای snap می‌شود؛ حرکت نرم اختیاری و با reduced-motion حذف. هنگام تغییر zoom world point زیر cursor/انگشت ثابت می‌ماند؛ Center تنها فرمانی است که camera را عمداً بازمرکز می‌کند.

### 6.4 Selection مشکلِ icon کوچک را حل کند

Hit area یک door 7-pixel مساوی خود asset نیست. نزدیک‌ترین **شناخته‌شده** در radius مناسب display-space انتخاب شود. اگر دو object نزدیک‌اند، sheet دو candidate را با label نشان دهد؛ click منطقهٔ expanded نباید تصادفاً object دوم را از پشت انتخاب کند. zoom پایین room انتخاب می‌شود؛ انتخاب door از inspector list: Left exit، Upper gate. به‌جای مجبورکردن انگشت به target دوپیکسلی، selection را semantically coarse کنید [S35، S37].

### 6.5 فونت، orientation و accessibility

- path labelها و object name در detail؛ متن compact انگلیسی مانند Requires dash. متن explanatory خارج canvas/در sheet می‌تواند native-resolution font باشد.
- target اولیهٔ text در mobile overlay حدود 16 CSS px برای label اصلی؛ technical pixel font فقط وقتی characterها واقعاً خوانا هستند. guideline اندازهٔ مشخص یکسان برای هر بازی نمی‌دهد؛ font-size و contrast باید روی گوشی واقعی تست شود [S36].
- فقط palette-swapping برای color blindness کافی نیست: glyph، name و outline را اضافه کنید. grayscale test، protan/deutan/tritan simulation و سپس کاربر واقعی؛ یک simulator تأیید نهایی نیست [S34].
- گزینه‌های minimum: UI scale، high-contrast map، reduced motion، remappable Map/Back/Ping، no-blink players و icon name on focus.
- keyboard و gamepad: تمام actionها از focus navigation قابل انجام؛ mouse hover تنها روش labelخواندن نباشد. کنترل Close/Back در همهٔ submenuها ثابت و predictable.
- landscape اولویت gameplay؛ در portrait نقشه اگر مستقل طراحی شده می‌تواند vertical sheet بگیرد، اما ادعای پشتیبانی کامل portrait بدون test نکنید. اگر viewport letterboxed و target کوچک می‌شود، rotate prompt + Close قابل استفاده، نه نقشهٔ غیرقابل لمس.
- Android browser با address bar باز/بسته، notch/safe-area، resize، accidental back gesture و external controller آزمایش شود. هیچ screenshot featureای نباید به خروج به file picker برای استفادهٔ معمول وابسته باشد.

## 7. Anti-patterns — اشتباهات و نمونه‌های دقیق

| اشتباه | مثال / شاهد | چرا برای CLAWD بد است؟ | اصلاح مشخص |
| --- | --- | --- | --- |
| مستطیل‌های مجاور بدون نمایش doorway | Super Metroid؛ نقد Boss Keys [S02] | pair فکر می‌کند مسیر هست و بن‌بست پیدا می‌کند | edge واقعی، slot و unexplored stub |
| نبود type برای مانع ثبت‌شده | تفاوت نقشهٔ Super Metroid با Icon Highlight در Dread [S02، S04] | هر upgrade با tour کل 120 room دنبال می‌شود | ability taxonomy و compatible filter |
| current location با هزینهٔ build/combat | Wayward Compass در Hollow Knight [S06] | ابزار پایهٔ coordination باید همیشه باشد | P1/P2 بدون charm، item یا پول |
| Back دکمهٔ گذاشتن pin باشد | Bloodstained، رفتار گزارش‌شدهٔ 2019 [S14] | map پر از یادداشت‌های تصادفی | Back closes؛ Pin action جدا و undo |
| رنگ، تنها معنیِ dot باشد | completion dots در Axiom Verge؛ room icons در ESA [S13، S26] | روی phone یا grayscale معنی گم می‌شود | icon/label و state shape |
| screenshot را «یک کار سادهٔ کم‌هزینه» فرض کنیم | مصاحبهٔ Boutin دربارهٔ iteration/cloud-save [S10] | هزینهٔ web persistence و shared sync مخفی می‌ماند | metadata MVP؛ capture فاز جدا |
| map خریدنی را بی‌توجه به کل loop کپی کنیم | Hollow Knight نقشه+Quill+bench+compass ترکیب می‌کند [S06، S08] | partner گم است ولی شما دنبال seller می‌گردید | navigation پایه رایگان؛ intelligence reward |
| تغییر جهان بدون تغییر/عدم‌قطعیت نقشه | Infected Crossroads مسیرهای قدیمی را می‌بندد؛ Boss Keys آن را friction می‌داند [S08] | stale map نقشهٔ دروغگو می‌شود | event-driven known-state update یا stale badge |
| survey را visited/complete بشماریم | Super Metroid تفکیک می‌کند [S01] | خرید blueprint حس اکتشاف را عددی نابود می‌کند | state و counter مستقل |
| markerهای راهنمای طرفداران را UI داخل بازی فرض کنیم | نقشه‌های external Ori/Nine Sols/Bloodstained پر از spoiler‌اند | spec با قابلیت‌های ناموجود ساخته می‌شود | فقط in-game شواهد؛ unverified صریح |
| دو بازیکن روی map با یک dot یا رنگ-only | DRG marker رنگ class دارد [S32]؛ این نقد عدم‌تناسب، نه bug آن است | P1/P2 و self از هم تشخیص داده نمی‌شوند | slot ID + shape + halo |
| touch = همان desktop با scale کمتر | GAG دربارهٔ targetهای کوچک [S35] | icon و gesture اشتباه و خستگی | display-space targets و sheet/list |
| نزدیک بودن geometry را قابل‌دسترس‌بودن بدانیم | درهای یک‌طرفه و ability lockها در Boss Keys [S02، S08] | راهنمایی به مسیر غیرممکن | Compatible label؛ Reachable فقط با graph check |
| درصد کل اسرار از شروع نشان دهیم | اعداد completion انگیزهٔ cleanup دارند؛ انتخاب محصول است | هر gap به spoiler عددی تبدیل می‌شود | counts ابتدا، denominator cleanup بعداً |
| 404 فقط از room drawing حذف شود | failure mode پیشنهادی CLAWD، نه ادعای بازی دیگر | bounds، pin، sourcemap یا player arrow راز را لو می‌دهد | policy filter مشترک برای تمام consumerها |
| map opening pause آنلاین ناخواسته باشد | failure mode شبکهٔ CLAWD؛ browser tab نیز pause مستقل دارد [S38] | partner در combat بی‌خبر freeze/زخمی می‌شود | local map state؛ pause handshake جدا |

## 8. Top 15 recommendations — اولویت بر اساس impact در برابر cost

**روش رتبه‌بندی:** داوری کیفی برای همین brief، بدون score ساختگی، تخمین روز یا ادعای A/B test. نخست correctness و coordination، بعد recall/cleanup و در آخر delight. هزینهٔ هر ردیف scope همان ردیف است؛ مثلاً «P1/P2» فرض می‌کند position sync موجود است. اگر نیست cost بالا می‌رود.

| رتبه | اقدام مشخص | impact برای CLAWD | cost | چرا این رتبه؟ | شرط پذیرش |
| --- | --- | --- | --- | --- | --- |
| 1 | Door slots و unexplored stubs | very high | low–medium | بزرگ‌ترین شکاف نقشهٔ امروز: اتصال نامعلوم | هر exit معمولیِ observed پیدا؛ secret ندیده absent |
| 2 | P1/P2 با ID، shape و partner focus | very high | low–medium | اصل وعدهٔ دو نفره | روی هر دو client identity یکسان؛ overlap خوانا |
| 3 | قرارداد never/secret/normal مشترک | very high | medium | مانع spoiler و completion bug در همهٔ featureهای بعدی | 404 در bounds، counters، item و ping نیست |
| 4 | Back/Close ثابت و focus navigation | high | low | ارزان‌ترین پیشگیری از pin تصادفی و input trap | keyboard/gamepad/touch خروج بدون mutation |
| 5 | visited/surveyed/unknown مستقل | high | low–medium | پایهٔ reward نقشه و trust | blueprint Coverage را زیاد نمی‌کند |
| 6 | type glyph برای obstacleهای observed | very high | medium | هر ability از فراموشی به گزینهٔ عملی تبدیل می‌شود | filter فقط gate دیده‌شده با ID واقعی |
| 7 | touch layout با target واقعی و +/- | very high | medium | Android یک endpoint اصلی است، نه فرعی | 48 CSS target محصول؛ pinch اجباری نیست |
| 8 | union discoveries و reconnect snapshot | very high | medium | coordination و save consistency | joiner room/item state درست می‌گیرد |
| 9 | local map-open و pause policy | very high | medium | از آسیب/اختلال شریک جلوگیری می‌کند | map P1 بدون freeze ناخواستهٔ P2 |
| 10 | shared ping با چهار intent | high | medium | بدون voice communication مفید | 6s label؛ ack؛ نرخ کنترل‌شده |
| 11 | bench و terminal icon جدا + travel list | high | low–medium | fast travel محدودِ موجود قابل فهم می‌شود | bench عادی travel target نیست |
| 12 | category pin و quick metadata note | high | medium | جایگزین ارزانِ screenshotهای shared | owner، ID، Done/Undo، persistence |
| 13 | compatible filter پس از ability unlock | high | medium | replay مسیر فقط برای امتحان‌های معنادار | compatible با reachable اشتباه نشده |
| 14 | sourcemap فیلترشده + counters جدا | medium–high | medium | endgame cleanup، بدون spoil early-game | collected خاموش؛ secret/404 policy پابرجا |
| 15 | terminal survey animation + یک symlink reveal | medium | low–medium | map delight با کمترین محتوای جدید | skip/reduced-motion؛ shortcut state دقیق |

**فعلاً نسازید:** freehand drawing شبکه‌ای، minimap terrain دقیق، route GPS خودکار، screenshot مشترک، rearranging room grid و puzzle اجباری در map shape. هیچ‌یک برای رفع ضعف نقشهٔ فعلی لازم نیست. اگر playtest نیاز خاصی اثبات کند، با scope مستقل بازگردند.

### 8.1 ترتیب تحویل برای AI-agent implementation

**Milestone A — correctness:** registry و knowledge state، policy filter، doors، stable P1/P2، Back و renderer دو سطح؛ سپس روی یک zone و حدود 12 room نمونه اجرا. size نمونه پیشنهادی است، نه نسخهٔ جهان واقعی.

**Milestone B — coordination:** local map state، reconnect، ping و pin، partner focus، touch sheet و travel list. برای travel گروهی و pause مشترک testهای network race جدا.

**Milestone C — rewards:** terminal survey، compatible filter، sourcemap و progress panel؛ بعد یک symlink animation. screenshot و authored mystery بیرون این milestone.

برای هر agent یک قرارداد داده/ownership، یک feature branch و test acceptance روشن؛ agentِ renderer اجازه ندارد raw secret data را خودش مجاز کند. agentِ plugin و agentِ co-op همان MapPolicy را مصرف کنند. بازبینی انسانی map metadata حیاتی است: تولید خودکار door type از ظاهر pixel-art قابل اتکا نیست.

### 8.2 Playtest کوچک اما تصمیم‌ساز

اعداد زیر **targetهای اولیهٔ محصول و hypotheses** هستند، نه شواهد پژوهشی از بازی‌های دیگر. با 4–6 pair ترکیبی PC+Android شروع کنید؛ حداقل یک player تازه‌وارد به metroidvania، gamepad و یک مشارکت‌کننده با نیاز دسترس‌پذیری در نمونه بگنجانید. نمونه کوچک برای یافتن مشکل است، نه تعمیم آماری.

| Task | setup | معیار / failure قابل مشاهده |
| --- | --- | --- |
| locate partner | دو zone شناخته‌شده؛ partner حرکت می‌کند | player نام zone و room partner را در حدود 3s می‌گوید؛ ID swap ممنوع |
| return with ability | سه مانع observed؛ پس از 15min وقفه ability unlock | انتخاب یک مانع سازگار در حدود 20s، بدون tour تصادفی همهٔ roomها |
| unknown exit | room با دو exit شناخته‌شده و یک secret ندیده | exit بازِ ناشناخته قابل انتخاب؛ secret از نقشه حدس قطعی زده نمی‌شود |
| mobile select | دو gate نزدیک، drag و pinch پشت‌سرهم | هیچ pin/ping هنگام pan/Close تصادفی ساخته نمی‌شود |
| terminal travel | bench عادی، terminal جاری و دو مقصد | تفاوت bench/terminal فهمیده می‌شود؛ جابه‌جایی partner بدون consent صفر |
| 404 privacy | P2 داخل 404، P1 بیرون با sourcemap | همهٔ UIهای P1 فقط unindexed status؛ geometry/coordinate leak صفر |
| reconnect | Android tab inactive و بازگشت | stale partner تشخیص؛ snapshot دوباره با visited/items یکسان |
| grayscale | رنگ حذف؛ دو player و سه gate type | identity، state و type فقط با glyph/label قابل فهم |

زمان، tap error، map-open frequency، backtrack-to-dead-end و درخواست کمک را log کنید؛ زیادشدن map-open لزوماً بد نیست، شاید planning مفید باشد. سؤال آخر: «چرا این مسیر را انتخاب کردی؟» اگر جواب «نقشه دستور داد» است، کمک بیش از حد محتوا را جایگزین کرده؛ اگر «نمی‌دانستم دو room به هم وصل نیستند» است، topology هنوز ناقص است.

## 9. Sources — لینک‌ها، نوع مدرک و حدود استفاده

همهٔ منابعی که برای factual claim یا reference طراحی این گزارش استفاده شده‌اند در این فهرست آمده‌اند. منابع اولیه بالاترین اولویت را داشته‌اند؛ برای چند indie، شواهد مناسبِ in-game mechanics عمدتاً wiki/guide است و اعتبار آن از developer statement کمتر است. تاریخ‌های انتشار موجود ذکر شده‌اند؛ دسترسی پژوهش 11 October 2026. نتیجهٔ ناکام load یا search بی‌ربط مدرک محسوب نشده است.

| ID | منبع و لینک | نوع / استفاده / محدودیت |
| --- | --- | --- |
| S01 | [Nintendo — Super Metroid electronic manual](https://www.nintendo.com/es-es/games/oms/snes-classic/manuals/super-metroid/manual.pdf) | primary؛ بخش Map Screen: visited/downloaded، icons و حذف hidden passages؛ متن PDF بررسی شد |
| S02 | [GMTK — The World Design of Super Metroid / Boss Keys](https://www.youtube.com/watch?v=nn2MXwplMZA) | تحلیل ثانویه؛ transcript متمرکز بررسی شد؛ doorway، colored-door icon، map terminal و backtracking؛ اختلاف با wording manual در 2.2 |
| S03 | [Metroid Database — transcript of official Metroid Fusion manual](https://metroiddatabase.com/old_site/m4/manual.php) | primary متنِ بازنشرشده؛ map، objective و Navigation Rooms؛ [PDF رسمی Nintendo](https://www.nintendo.com/eu/media/downloads/games_8/emanuals/game_boy_advance_8/Manual_GameBoyAdvance_MetroidFusion_EN_DE_FR_ES_IT.pdf) نیز برای provenance یافت شد |
| S04 | [Nintendo — Metroid Dread Report vol. 9](https://metroid.nintendo.com/dread/news/metroid-dread-report-vol-9/) | primary، 30 September 2021؛ نام icon، highlight، hidden-item range و Map Station؛ متن کامل بررسی شد |
| S05 | [Wikitroid — Map](https://metroid.fandom.com/wiki/Map) | community؛ marker و رفتارهای Dread؛ supplemental به منبع رسمی، نه جایگزین آن |
| S06 | [Hollow Knight Wiki — Map and Quill](https://hollowknight.wiki/w/Map_and_Quill_(Hollow_Knight)) | community؛ متن کامل؛ Cornifer، Quill، bench update، compass، manual/service pins، Collector’s Map و off-map spaces |
| S07 | [PC Gamer — How to design a great Metroidvania map](https://www.pcgamer.com/how-to-design-a-great-metroidvania-map/) | مصاحبهٔ primary با Team Cherry، اصل 2017 و بازنشر 2025؛ spatial coherence، connections، scope و cognitive load؛ پیش از DLCها |
| S08 | [GMTK — The World Design of Hollow Knight / Boss Keys](https://www.youtube.com/watch?v=7ITtPPE-pXE) | تحلیل + اظهارات مستقیم Team Cherry؛ transcript هر دو بخش بررسی شد؛ branching، shortcut، mapping، Infected Crossroads و اختلاف هدف/route |
| S09 | [Ubisoft — Lost Crown Accessibility Spotlight](https://news.ubisoft.com/en-us/article/5nGZiBSFtcEzFd93QlTotS/prince-of-persia-the-lost-crown-accessibility-spotlight) | primary interview با Rémi Boutin، January 2024، update August 2024؛ memory burden، Guided mode، default accessibility؛ متن کامل |
| S10 | [Game Developer — How Memory Shards help players find secrets](https://www.gamedeveloper.com/design/how-memory-shards-help-players-find-secrets-in-prince-of-persia-the-lost-crown) | primary developer interview، 31 January 2024؛ screenshot بدون HUD، resolution مشترک، cloud-save limit، 15 آغازین و iteration؛ متن کامل |
| S11 | [Ubisoft Help — Using Memory Shards](https://www.ubisoft.com/en-us/help/prince-of-persia-the-lost-crown/gameplay/article/using-memory-shards-in-prince-of-persia-the-lost-crown/000106473) | primary؛ unlock زودهنگام، press/hold، delete و یافتن shard بیشتر؛ عنوان Last Crown در body خطای تایپی منبع است |
| S12 | [IGN — Ori and the Will of the Wisps: How to Get Maps](https://www.ign.com/wikis/ori-and-the-will-of-the-wisps/How_to_Get_Maps) | guide، 10 March 2020؛ متن کامل؛ Lupo، area map و collectible maps؛ current-patch pinهای دلخواه تأیید نشده |
| S13 | [Axiom Verge Wiki — Map](https://axiom-verge.fandom.com/wiki/Map) | community؛ متن کامل؛ tile auto-map، door divider و completion dots؛ بخش بازی اول از دوم جدا استفاده شد |
| S14 | [Shacknews — Blue icons on map in Bloodstained](http://www.shacknews.com/article/112695/blue-icons-on-map-in-bloodstained-ritual-of-the-night) | guide، 1 July 2019؛ متن کامل؛ blue rose custom marker و Back conflict؛ رفتار همهٔ patchهای بعدی تأیید نشده |
| S15 | [GameWith — Bloodstained: Breakable Walls and Secret Rooms](https://gamewith.net/bloodstained-ritual-of-the-night/article/show/9987) | guide، update 2022؛ شواهد secret rooms؛ نقشهٔ external و reward lists را قابلیت خود بازی فرض نکردیم |
| S16 | [The Outerhaven — Bloodstained 100% Full Map](https://www.theouterhaven.net/2019/06/bloodstained-ritual-of-the-night-100-full-map) | secondary، 2019؛ مکمل برای دامنهٔ نقشه؛ trigger هر cell را از تصویر استنتاج نکردیم |
| S17 | [GMTK — The World Design of Castlevania: Symphony of the Night](https://www.youtube.com/watch?v=a1hHOVIkrcc) | تحلیل؛ transcript متمرکز بررسی شد؛ خرید unfinished map از Librarian و Inverted Castle |
| S18 | [GameFAQs — SotN 200.6% map completion discussion](https://gamefaqs.gamespot.com/boards/937723-castlevania-symphony-of-the-night/38223949?page=37) | community anecdote؛ فقط برای اصطلاح تاریخی 200.6% و مشکل missing cells؛ نه prevalence یا benchmark |
| S19 | [Nine Sols Wiki — Map Data Chips](https://ninesols.wiki.gg/wiki/Map_Data_Chips) | community؛ متن کامل؛ Shanhai، خرید/زور و تحویل به Pavilion؛ جزئیات pin/counter UI unverified |
| S20 | [Haiku the Robot Wiki — Map Disruptors](https://haiku-the-robot.fandom.com/wiki/Map_Disruptors) | community؛ متن کامل؛ disruption و reveal؛ خود مقاله بخشی از location data را از Neoseeker می‌گیرد |
| S21 | [Steam — Haiku the Robot map markers discussion](https://steamcommunity.com/app/1231880/discussions/0/3417685271691595531/) | community؛ Rusty/service markers؛ confidence کمتر از primary؛ pin دلخواه تأیید نشده |
| S22 | [Official Animal Well Wiki — Map item](https://animalwell.wiki.gg/wiki/Map_(item)) | community با عنوان Official؛ developer statement تلقی نشده؛ متن کامل؛ illuminated mapping، auto markers، Pencil و Stamps |
| S23 | [Polygon — How to get the map in Animal Well](https://www.polygon.com/guides/24150433/animal-well-map-how-to-get-find/) | guide، 9 May 2024؛ متن کامل؛ symbolهای pixel map و 64 stamps |
| S24 | [PlayStation Blog — The creation of Tunic’s in-game manual](https://blog.playstation.com/2022/09/21/the-creation-of-tunics-invaluable-in-game-manual/) | primary نوشتهٔ Andrew Shouldice، 21 September 2022؛ متن کامل؛ collectible manual، maps، secrets و authored ambiguity |
| S25 | [GDC Vault — TUNIC: This Was Here the Whole Time](https://gdcvault.com/play/1029384/-TUNIC-This-Was-Here) | primary session description با Andrew Shouldice؛ فقط abstract عمومی بررسی شد، نه ویدئوی کامل؛ loose ends و ارزش mystery؛ جزئیات ارائه ادعا نشده |
| S26 | [Environmental Station Alpha Wiki — Station Map](https://environmental-station-alpha.fandom.com/wiki/Station_Map) | community؛ متن کامل؛ Rough Map، coordinates، iconها، off-map rooms و glyph مخفی |
| S27 | [Islets Wiki — Map](https://islets.fandom.com/wiki/Map) | community؛ main/sky map و پنج جزیره؛ روش unlock و pin دلخواه unverified |
| S28 | [Islets — developer/publisher Steam page](https://store.steampowered.com/app/1669420/Islets/) | primary product description؛ magnetic cores، اتصال جزیره و دسترسی تازه؛ دسترسیِ محتوای map با جابه‌جایی UI خلط نشده |
| S29 | [Blasphemous — The Stir of Dawn official announcement](https://steamcommunity.com/games/774361/announcements/detail/2719563557145696174) | primary release notes، 4 August 2020؛ search excerpt حاوی marker، zoom و percentage؛ full extraction فقط title داد |
| S30 | [Blasphemous Wiki — The Stir of Dawn](https://blasphemous.wiki.gg/wiki/The_Stir_of_Dawn) | community؛ تطبیق patch notes رسمی؛ version و map overhaul؛ historical launch state جدا |
| S31 | [Nintendo — Etrian Odyssey map demo](https://www.nintendo.com/en-gb/News/2008/Chart-your-surroundings-with-our-Etrian-Odyssey-map-demo-250286.html) | primary، 10 July 2008؛ Touch Screen، stylus و paths/dead ends/dangers؛ loop action co-op نیست |
| S32 | [Official Deep Rock Galactic Wiki — Terrain Scanner](https://deeprockgalactic.wiki.gg/wiki/Terrain_Scanner) | community official-hosted؛ متن کامل؛ teammate arrows، class colors، objective و waypoint |
| S33 | [Official Deep Rock Galactic Wiki — Laser Pointer](https://deeprockgalactic.wiki.gg/wiki/Laser_Pointer) | community؛ متن کامل؛ shared object mark در برابر personal-only waypoint |
| S34 | [Game Accessibility Guidelines — No fixed colour alone](https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-fixed-colour-alone/) | specialist guidance؛ متن کامل؛ symbols، labels، custom color و محدودیت full-palette filter |
| S35 | [Game Accessibility Guidelines — Large, well-spaced controls](https://gameaccessibilityguidelines.com/ensure-interactive-elements-virtual-controls-are-large-and-well-spaced-particularly-on-small-or-touch-screens/) | specialist guidance؛ متن کامل؛ اندازهٔ touch و spacing، از جمله recommendation فیزیکی؛ عدد واحد logical pixel نمی‌دهد |
| S36 | [Game Accessibility Guidelines — Readable default font size](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size) | specialist guidance؛ فونت و viewing context؛ حد فونت CLAWD در گزارش پیشنهاد prototype است |
| S37 | [Google — Android touch target size](https://support.google.com/accessibility/android/answer/7101858?hl=en) | primary platform guidance؛ 48dp و padding خارج visual bounds؛ اندازهٔ CSS محصول جدا مشخص شد |
| S38 | [Godot documentation — Exporting for the Web, stable](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | primary technical docs؛ بخش‌های متمرکز بررسی شد؛ WebGL2، Compatibility، single-thread 4.3+، mobile، IndexedDB و background processing؛ stable mutable است، با نسخهٔ build کنترل شود |
| S39 | [Official Terraria Wiki — Wormhole Potion](https://terraria.wiki.gg/wiki/Wormhole_Potion) | community؛ انتخاب teammate در multiplayer map برای teleport؛ صرفاً comparison، خارج travel rules پیشنهادی CLAWD |
| S40 | [W3C — Target Size Enhanced, WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced) | primary standard explanation؛ 44×44 CSS px، Level AAA و exceptions؛ رعایت target به‌تنهایی ادعای WCAG conformance کل بازی نیست |

### 9.1 دفتر unverified و پرسش‌های باز

- pin دلخواهِ native در Ori and the Will of the Wisps، Axiom Verge، Nine Sols، Haiku the Robot، Islets، ESA و SotN: **unverified**؛ «ندارد» ادعا نشده است.
- روش unlock دقیق map در Islets و trigger map-cell fill در Bloodstained: **unverified** در corpus بررسی‌شده.
- خرید blueprint از Fariba در Lost Crown و جزئیات countهای map chip در Nine Sols: **unverified** در منابع این گزارش؛ در recommendation اصلی به آن‌ها وابسته نیستیم.
- محدودیت‌های input Bloodstained در تمام نسخه‌های 2026: **unverified**؛ شاهد 2019 تاریخی است.
- تمام جزئیات talkهای GDC که فراتر از abstract عمومی‌اند: **unverified** و استفاده نشده‌اند؛ ادعای تماشای ارائه وجود ندارد.
- زمان توسعه، اثر روی retention، درصد بهبود navigation و برتری آماری featureها: **unverified**؛ هیچ عدد اثرگذاری اختراع نشده است.
- abilityهای واقعی CLAWD، zone هشتم، shared یا individual بودن abilityها، امکان split player movement و معماری authority: هنوز از brief مشخص نیست؛ report یک default اجرایی پیشنهاد می‌دهد و این‌ها باید پیش از implementation freeze شوند.

**نتیجهٔ نهایی:** ابتدا درها، knowledge state، P1/P2 و touch را درست کنید؛ سپس pin و ability recall؛ بعد sourcemap و map-reveal delight. نقشهٔ CLAWD باید مسیرهای فکرکردن را روشن کند، نه مسیر حل‌کردن بازی را از پیش تعیین کند.