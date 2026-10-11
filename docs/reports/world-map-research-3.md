<aside>
🎯

**تصمیم اصلی:** CLAWD باید یک **web تدریجاً بازشونده با hubهای محلی** باشد؛ نه هشت corridor زنجیره‌ای و نه یک labyrinth که از ابتدا همهٔ خروجی‌هایش فعال‌اند. پاداش اصلی نقشه: «شناختن نسبت مکان‌ها»، «استفادهٔ تازه از اتاق قدیمی» و «تغییر دائمی مسیرهای مشترک».

</aside>

**دامنه:** پژوهش طراحی برای بازی دو‌نفرهٔ browser-based با نمایش 384×216، tileهای 16px و latency اعلام‌شدهٔ 50–250ms. تاریخ تدوین: ۱۱ اکتبر ۲۰۲۶. گزارش شامل spoiler جدی برای بازی‌های بررسی‌شده است.

**روش و مرز شواهد:** توضیح طراح، postmortem و transcript در اولویت‌اند؛ guide و wiki برای راستی‌آزمایی مکان/مکانیک استفاده شده‌اند. شناسه‌های S01–S40 به منابع بخش ۸ ارجاع می‌دهند. «نمونهٔ بازی» با «پیشنهاد CLAWD» متفاوت است. توضیح روان‌شناختی، تفسیر طراحی است، نه نتیجهٔ آزمایش علمی. اندازه‌ها، زمان‌ها و هزینه‌ها در پیشنهادها **فرضیهٔ blockout/playtest** هستند؛ کد، build و نقشهٔ فعلی CLAWD بررسی نشده‌اند. «low/medium/high» شامل art، integration، co-op و QA است، نه فقط نوشتن کد. فقط بخش‌های خوانده‌شدهٔ منابع مبنای ادعا هستند؛ مشاهدهٔ کامل همهٔ ویدئوها یا بازی‌کردن تازهٔ همهٔ عناوین ادعا نمی‌شود.

## ۱. Summary — ده درس اصلی

1. اتصال تازه به **landmark آشنا** پاداش فضایی است؛ خروج shortcut نباید به corridor بی‌نام برسد.
2. بازیکن باید بداند **کجاست و چه چیزهایی را هنوز نمی‌فهمد**؛ curiosity با ابهامِ راه‌حل رشد می‌کند، نه با گم‌کردن موقعیت.
3. «دیدن قبل از رسیدن» را با یک مانع خوانا، یک نام و امکان pin به وعدهٔ قابل‌حفظ تبدیل کنید.
4. سه اتصال هر zone را در **نقشهٔ نهایی** تضمین کنید؛ در شروع همهٔ سه اتصال را فعال نکنید.
5. هر ability یک کاربرد امن نزدیک، یک برگشت آشنا و یک کاربرد اختیاری پیشرفته داشته باشد.
6. boss فقط item ندهد؛ یک علت قابل‌دیدن در جهان را اصلاح و یک مسیر واقعی را کوتاه کند.
7. one-way drop برای expedition کوتاه مفید است؛ در co-op بدون مسیر خروج و recovery، trap است.
8. optional depth را از main path جدا اعلام کنید؛ پیچیدگی ESA/La-Mulana نباید شرط پایان عادی باشد.
9. در co-op، **state مشترک پایدار + camera مستقل + reunite اختیاری** از synchronized platforming مهم‌تر است.
10. برای phone، challenge را در انتخاب مسیر و استفادهٔ ابزار نگه دارید؛ precision اجباری، blind landing و انتظار برای PC player را حذف کنید.

## ۲. Pattern catalogue — ۲۶ الگوی اجرایی

### ۲.۱. مدل هیجان: نقشه چگونه «aha» تولید می‌کند؟

سه زنجیرهٔ متفاوت را طراحی کنید:

- **Anticipation → capability → payoff:** از پایین یک balcony می‌بینم، بعد double jump می‌گیرم، بالا می‌روم و همان منظره را از جهت دیگر می‌بینم.
- **Uncertainty → recognition → compression:** سفر طولانی ظاهراً دوری را تمام می‌کنم؛ gate باز می‌شود و صدای bench آشنا را می‌شنوم؛ درمی‌یابم فاصلهٔ دو مکان در جهان کم بوده است.
- **Observation → hypothesis → reinterpretation:** commentهای پس‌زمینه را decoration فرض می‌کردم؛ یک manual page نشان می‌دهد که همان‌ها اشارهٔ مسیرند؛ اتاق‌های قبلی معنای تازه پیدا می‌کنند.

Ari Gibson و William Pellen اتصال‌ها را هم ابزار backtracking و هم پاداش خودِ اکتشاف می‌دانند؛ Blue Lake را بالای City of Tears گذاشتند تا باران شهر علت مکانی داشته باشد. Andrew Shouldice سه مرحلهٔ ignorance، knowledge و understanding را پیشنهاد می‌کند و تأکید دارد که این مدل empirical نیست. برای CLAWD، هر room مهم باید یکی از این زنجیره‌ها را هدف بگیرد، نه صرفاً یک chest در انتهای راه.[[1]](https://www.pcgamer.com/how-to-design-a-great-metroidvania-map)[[2]](https://www.gamedeveloper.com/design/video-how-the-tunic-developers-built-a-mysterious-world)

### ۲.۲. اختلاف منابع؛ کدام جهت برای CLAWD مناسب است؟

- **Hollow Knight در برابر Metroid Dread:** Team Cherry آزادی گم‌شدنِ ثمربخش را معتبر می‌داند؛ تحلیل Mark Brown نشان می‌دهد Dread با point of no return، lock نزدیک key و teleporter فضای جست‌وجو را کوچک می‌کند. نتیجهٔ او دربارهٔ Dread منفی‌تر از نظر بازیکنان action-oriented است؛ این سلیقه را قانون عمومی نکنید. **انتخاب CLAWD:** آموزش اولیه با guidance نسبتاً قوی؛ midgame با انتخاب واقعی و دو راه ورود به مقصد؛ funnel فقط در escape/encounter مشخص. S01، S04.
- **Animal Well در برابر ESA:** Basso از تراکم و چند لایهٔ معنایی در تعداد محدود room دفاع می‌کند؛ Teikari در postmortem می‌گوید map بسیار فشردهٔ ESA به فضای تنفس نیاز داشت. تناقض ظاهری با تفکیک **semantic density** از **physical density** حل می‌شود: room می‌تواند دو راز داشته باشد و همچنان landing و vista باز داشته باشد. S06، S08، S13.
- **La-Mulana در برابر The Lost Crown:** Naramura وجود hint و challenge عمدی را کافی می‌داند؛ critique بازی از فاصلهٔ clue، puzzle و item و ندانستن solvability شکایت می‌کند. Boutin در The Lost Crown مشکل mental notes را با pin حل می‌کند. **انتخاب CLAWD:** رمز سخت فقط optional؛ پیش‌نیاز main path و یادداشت‌های دیده‌شده روشن و قابل‌بازیابی. S11، S15، S16.
- **Ori در برابر lock-and-key صرف:** Chris McEntee می‌گوید drill کم‌تنوع را حذف کردند چون ability باید روش بازی را عوض کند، نه فقط یک door باز کند. **انتخاب CLAWD:** curl، ssh و revert هر کدام حداقل یک traversal، یک reinterpretation و یک shortcut بسازند؛ اگر فقط قفل رنگی‌اند، scope را کم کنید. S05.

### ۲.۳. Catalogue

#### P01 — Anchored Hub-and-Spoke | hub لنگردار

- **چیست:** یک مرکز قابل‌شناسایی با شاخه‌های متفاوت؛ برای reset ذهنی، نه اجبار عبور از مرکز در هر سفر.
- **نمونه:** Nine Sols: Four Seasons Pavilion پایگاه Yi است و به New Kunlun Central Hall متصل است؛ شخصیت‌ها و امکانات، برگشت را به رابطه و استراحت تبدیل می‌کنند. این نمونه اثبات نمی‌کند کل map بازی یک star ساده است. S12، S24.
- **چرا:** مکان ثابت بار حافظه را کم و بازگشت را به احساس خانه تبدیل می‌کند.
- **CLAWD:** `ST-root-bench` زیر trunk روشن؛ سه شاخه به DEPTHS، NETWORK و GIT، اما فقط یکی در شروع مسیر اصلی فعال باشد. hub کوچک هر zone پیرامون تنها terminal bench همان zone شکل بگیرد.
- **هزینه:** low؛ layout و landmark، بدون سیستم traversal تازه.

#### P02 — Progressive Web | web تدریجی

- **چیست:** جهان با چند مسیر متقاطع که با progress به web تبدیل می‌شود، نه هشت مرحلهٔ جدا.
- **نمونه:** Hollow Knight بعد از Mantis Claw به City of Tears، Deepnest، Ancient Basin و مسیرهای دیگر باز می‌شود؛ شرق City of Tears چند ورودی دارد. S01، S03.
- **چرا:** بازیکن مسیر شخصی دارد؛ باز شدن یال تازه، mental model را غنی می‌کند.
- **CLAWD:** graph دوازده‌یالهٔ بخش ۴؛ Source–Git دیرهنگام، Depths–Hell اختیاری و Heap–Production بستهٔ نهایی. سه neighbor هر zone در final state، نه سه انتخاب اجباری از minute one.
- **هزینه:** medium؛ طراحی graph و reachability QA مهم‌تر از art اضافه است.

#### P03 — Local Lollipop Loop | loop محلیِ بازگشت

- **چیست:** از stem امن وارد یک loop شوید و با پیشرفت به همان stem برگردید.
- **نمونه:** Blasphemous gateهای lever/glass case را از طرف مقابل باز می‌کند؛ Colinet shortcut نزدیک پایان boss را صریحاً برای حس «این همان در بود» توضیح می‌دهد. S10.
- **چرا:** دور شدن، tension؛ شناختن نقطهٔ آغاز، relief و mastery.
- **CLAWD:** `DD-import-loop`: bench → چهار room crumbling → dependency resolver → gate پشت bench. اتصال جدید را در همان قاب bench نشان دهید.
- **هزینه:** low؛ یک latch و چند room موجود.

#### P04 — Cross-Zone Return | shortcut بین zoneها

- **چیست:** پایان سفر به zone قبلی وصل شود، نه فقط ابتدای همان dungeon.
- **نمونه:** Hollow Knight: Crystal Heart مسیر Crystal Peak به Dirtmouth را ممکن می‌کند؛ رسیدن از بالا به شهر اولیه سفر را از نو معنا می‌کند. S03.
- **چرا:** شناخت فاصلهٔ واقعی، «world کوچک‌تر و من قوی‌تر شده‌ام».
- **CLAWD:** بعد از GIT HISTORY یک merge tunnel به پشت trunk اولیهٔ SOURCE TREE؛ همان silhouette، lamp و NPC را پیش از نمایش اسم zone ببینید.
- **هزینه:** low–medium؛ door pair، latch و تغییر مختصر art.

#### P05 — Far-Side Latch | قفلِ طرف مقابل

- **چیست:** مانع در سفر اول، shortcut دائمی در سفر برگشت؛ سمت بازشدن علت فضایی داشته باشد.
- **نمونه:** Blasphemous glass case با sword شکسته می‌شود تا مسیر باز شود؛ مسئلهٔ اشغال دائمی فضا توسط lever به شکل کوچک‌تر حل شده است. S10.
- **چرا:** بازیکن shortcut را کسب می‌کند؛ پیدا کردن جهتِ دسترسی پاداش است.
- **CLAWD:** هر latch با یک cable رو به سمت قابل‌فعال‌سازی؛ با dash cracked wall از back face بشکند. art دوطرفه باشد تا «از این طرف نمی‌شود» روشن باشد.
- **هزینه:** low؛ persistent boolean، اگر زیرساخت مشترک state وجود دارد.

#### P06 — Bounded Point of No Return | سقوطِ یک‌طرفهٔ محدود

- **چیست:** موقتاً مسیر برگشت بسته شود تا expedition تمرکز بگیرد؛ خروج آینده تضمین شود.
- **نمونه:** Dread gap قابل‌slide با خروجی بلند اجازهٔ برگشت بدون Morph Ball نمی‌دهد؛ Red Brinstar در Super Metroid نیز مسیر معمول بازگشت را به ابزار تازه وابسته می‌کند. S04، S02، S28.
- **چرا:** کوچک کردن فضای انتخاب و ایجاد تعهد؛ زیاده‌روی agency را می‌کاهد.
- **CLAWD:** ورود اول به HEAP از سقوط به balcony امن. هر بازیکن جداگانه حق ورود دارد؛ دهانه بسته نشود تا نفر دوم نرسیده. در پایین یک loop تا bench و خروج قابل‌استفاده با kit موجود؛ recovery توافقی برای قطع اتصال.
- **هزینه:** medium؛ geometry آسان، split-party/softlock QA پرهزینه‌تر.

#### P07 — Multiple Critical Entrances | چند ورودی به مقصد مهم

- **چیست:** مقصد ضروری با دو مسیر مستقل قابل‌کشف باشد؛ یک miss نباید پیشرفت را متوقف کند.
- **نمونه:** Resting Grounds در Hollow Knight از chasmِ Crystal Peak، Tram، lift از City و Blue Lake قابل‌دسترسی است. S03، S27.
- **چرا:** chance کشف بیشتر، بدون waypoint اجباری؛ بازیکن مسیرش را انتخاب می‌کند.
- **CLAWD:** NETWORK از SOURCE TREE یک entrance دیداری و از HEAP یک entrance پس از double jump داشته باشد. دو مسیر به router central می‌رسند، اما roomهای میانی یکسان نیستند.
- **هزینه:** medium؛ door pair و کنترل orderingِ curl/ssh.

#### P08 — Promise Window | پنجرهٔ وعده

- **چیست:** مکان جذاب را پیش از امکان رسیدن نشان دهید؛ مانع باید علت روشن داشته باشد.
- **نمونه:** Hollow Knight bridge مسیر City of Tears پیش از Mantis Claw؛ Dread landmark و lockها قبل از keyها، با اهمیت proximity. S03، S04.
- **چرا:** بازیکن برای ability بعدی یک مقصد ذهنی دارد، نه فقط آمار بهتر.
- **CLAWD:** `ST-pointer-balcony`: alcove با یک agent خوابیده در ارتفاع پیشنهادی پنج tile؛ wall-jump و dash را با سقف/سطح غیرقابل‌چسبیدن کنترل کنید و فقط بعد از simulation kit آن را double-jump gate بدانید. یک pin کنار bench ثبت شود.
- **هزینه:** low؛ هندسه، قاب دید و یک reward.

#### P09 — Landmark Triangulation | landmark چندنما

- **چیست:** یک جسم بزرگ در چند مسیر، ارتفاع یا zone دیده شود؛ به مختصات ذهنی تبدیل شود.
- **نمونه:** Hollow Knight: City of Tears زیر Blue Lake و با liftها/برج‌ها فهمیده می‌شود؛ Nine Sols هویت pavilion را با پایگاه ثابت نگه می‌دارد. S01، S24.
- **چرا:** «نسبت به آن کجا هستم؟» جای «در کدام corridor بودم؟» را می‌گیرد.
- **CLAWD:** trunk سفید-سبز SOURCE TREE از hub، پایین DEPTHS و دریچهٔ GIT دیده شود؛ یک background sprite با orientation سازگار، نه سه landmark تصادفیِ شبیه‌به‌هم.
- **هزینه:** low؛ asset مشترک و compositing ثابت.

#### P10 — Causal Vertical Stacking | چیدمان عمودیِ علّی

- **چیست:** بالا/پایین بودن zoneها یک فرآیند را توضیح دهد.
- **نمونه:** Blue Lake علت باران City of Tears است؛ توضیح مستقیم Team Cherry، نه صرفاً تفسیر منتقد. S01.
- **چرا:** world به مکان باورپذیر تبدیل می‌شود؛ کشف علت، reward مستقل است.
- **CLAWD:** chunkهای memory از DEPTHS به HEAP سقوط می‌کنند؛ pipe همان coolant به PRODUCTION می‌رود. پس از THE LEAK در دو نقطهٔ از پیش دیده‌شده کاهش آب/بخار دیده شود. macro layout باید اتصال واقعی pipe را حفظ کند.
- **هزینه:** low برای visual، medium برای state cross-zone.

#### P11 — Honest Map Grammar | دستور زبان صادق نقشه

- **چیست:** visited، seen-but-unreached، unexplored و blocked را متفاوت نشان دهید؛ map با world تناقض نداشته باشد.
- **نمونه:** The Lost Crown Guided mode lock دیده‌شده را با گرفتن power مناسب به unexplored تغییر می‌دهد؛ Hollow Knight به coherence فضایی متعهد است. S11، S01.
- **چرا:** بازیکن uncertainty راه‌حل را تحمل می‌کند، نه دروغ دادهٔ رابط را.
- **CLAWD:** solid fill = walked؛ outline = دیده‌شده؛ stub = خروجی ناشناخته؛ آیکن gate فقط برای مانع بررسی‌شده. roomهای واقعاً دیده‌نشده را با گرفتن ability آشکار نکنید.
- **هزینه:** medium؛ data model روشن و UI خوانا.

#### P12 — Bookmark With Context | pin همراه با زمینه

- **چیست:** یادآوریِ یک مانع با تصویر یا نشانهٔ دقیق، نه صرفاً نقطهٔ قرمز.
- **نمونه:** Memory Shards در The Lost Crown screenshot را روی map ذخیره می‌کند؛ Rémi Boutin نسخهٔ aiming/scanning پیچیده‌تر را پس از playtest کنار گذاشت. S11.
- **چرا:** حافظهٔ navigation آزاد می‌شود تا inference و curiosity باقی بمانند.
- **CLAWD:** نسخهٔ ارزان «stack trace pin»: room name، موقعیت door، نوع مانعِ دیده‌شده و یک thumbnail از پیش‌ساخته؛ screenshot زنده و sync تصویری را فقط در صورت نیاز واقعی اضافه کنید. tap یک‌مرحله‌ای، بدون pause جهانی.
- **هزینه:** low–medium برای metadata pin؛ medium–high برای screenshot sync کامل.

#### P13 — Camera as Cartographer | cameraِ نقشه‌ساز

- **چیست:** framing به بازیکن رابطهٔ exit، خطر و landmark را نشان دهد؛ مسیر بعدی خارج از frame پنهان نشود.
- **نمونه:** Celeste در Forsaken City side-roomهای strawberry و roomهای کوتاهِ challenge دارد؛ Guacamelee! 2 نمونهٔ منفیِ camera مشترک است که در co-op می‌تواند بازیکن را از edge خارج کند. S09، S25، S18.
- **چرا:** قبل از input، برنامهٔ حرکت ساخته می‌شود؛ حذف blind leap حس انصاف می‌دهد.
- **CLAWD:** camera جدا برای هر client؛ در shaftِ THREAD TOWER پیش از jump بالا peek عمودی؛ ورود از بالا landing را پیش از آزادکردن کنترل نشان دهد. camera را برای همراهِ دور zoom out نکنید.
- **هزینه:** medium؛ transition و testing phone لازم است.

#### P14 — Knowledge Gate | knowledge به‌جای key

- **چیست:** حرکت/تعامل از اول ممکن است، اما فهمِ قانون دیرتر به دست می‌آید.
- **نمونه:** Tunic Holy Cross در manual به D-pad/arrow input معنا می‌دهد؛ Outer Wilds پیشرفت را بر دانش می‌گذارد، نه upgrade. S07، S22، S23.
- **چرا:** «همیشه اینجا بود!»؛ قدرت در ذهن بازیکن است، نه inventory.
- **CLAWD:** یک secret در SOURCE TREE از ابتدا با دنبال‌کردن جهت branchها و استفاده از catch روی projectile زرد باز شود؛ page بعدی قانون را توضیح دهد. این secret پایان اصلی یا ability حیاتی را نبندد.
- **هزینه:** low؛ rule ثابت، clue و reaction.

#### P15 — Manual as World Interface | manualِ درون‌جهانی

- **چیست:** manual فقط controls نیست؛ map، clue و grammar جهان را تدریجی آشکار می‌کند.
- **نمونه:** Tunic صفحات ۴۳–۴۴ خوانش الگوهای Holy Cross را راه می‌اندازند؛ GDC talkِ Shouldice secrets را loose ends معرفی می‌کند. S07، S22.
- **چرا:** بازخوانی اطلاعات قدیمی reward دارد؛ discovery صرفاً کشف room تازه نیست.
- **CLAWD:** «README fragments» چهار صفحهٔ تصویری: moth=dead code، pipe=world cause، branch=route، light pulse=port state. zoom متن روی phone ضروری؛ خواندن توضیح input اصلی نباید خودش puzzle باشد.
- **هزینه:** medium؛ UI، localization و چهار تصویر؛ از alphabet عظیم شروع نکنید.

#### P16 — Tool With Several Verbs | ابزارِ چندفعل‌دار

- **چیست:** ability کاربردهای متفاوت داشته باشد: traversal، interaction و تغییر interpretation.
- **نمونه:** Animal Well disc علاوه بر پرتاب‌کردن، قابل‌سواری است؛ Axiom Verge Address Disruptor دشمن/blocks را تغییر می‌دهد؛ ESA hookshot فراتر از کاربرد اولیه مسیرهای مهارتی ایجاد می‌کند. S06، S13، S26.
- **چرا:** «خودم کشف کردم» و mastery، به‌جای lock رنگیِ مکانیکی.
- **CLAWD:** catch موجود: combat، انعکاس به relay، و روشن‌کردن یک debug clue با projectile. curl: عبور امن، swing shortcut و کشیدن latch. رفتارهای محدود و مشخص، نه یک simulation عمومی.
- **هزینه:** low–medium با ابزار موجود؛ high اگر هر کاربرد سیستم جدا بخواهد.

#### P17 — Authored Sequence Break | sequence break طراحی‌شده

- **چیست:** راه پیشرفته‌ای که ordering را تغییر می‌دهد و state بازی همچنان معتبر می‌ماند.
- **نمونه:** Team Cherry placementهایی برای nail bounce عمدی داشته؛ Dread early Bombs یک payoff مخصوص Kraid دارد. S03، S04، S29.
- **چرا:** بازیکن احساس می‌کند قانون را فهمیده و بر طراح غلبه کرده است.
- **CLAWD:** `DD-pogo-import`: دشمن مشخص با respawn مطمئن امکان رسیدن زود به optional Hell vestibule بدهد. reward اختیاری و مسیر خروج بدون double jump؛ ورود زود نباید THE LEAK یا story flags را auto-complete کند.
- **هزینه:** medium؛ room ارزان، آزمون prerequisiteها مهم.

#### P18 — Boss Changes the Graph | boss تغییر‌دهندهٔ graph

- **چیست:** victory یال‌های traversal را تغییر دهد، نه فقط ظاهرِ اتاق را.
- **نمونه:** Dread سرمای Artaria/Cataris با بحران thermal energy و نبرد Experiment Z-57 مرتبط است؛ ESA در encounterهای آبی state آب را عوض می‌کند. اولی تغییر state است، نه الزاماً shortcut دائمی مشابه CLAWD. S30، S31.
- **چرا:** agency قابل‌دیدن و خاطرهٔ قبل/بعد؛ victory در سفرهای بعدی باقی می‌ماند.
- **CLAWD:** THE LEAK سطح HEAP را یک مرحلهٔ دائمی پایین بیاورد و راه خشک HEAP–NETWORK را باز کند؛ pipe همان تغییر را نزدیک SOURCE TREE نشان دهد. unlock سراسری، animation محلی و امن.
- **هزینه:** medium؛ discrete state، occupancy check و persistence.

#### P19 — Same Room, New Route | اتاق ثابت، مسیر تازه

- **چیست:** یک geometry با ability یا state تازه معنای traversal متفاوت بگیرد.
- **نمونه:** در Windswept Wastesِ Ori، collapsing platform با sand/burrow ترکیب شد تا هم challengeِ رفت و هم مسیر برگشت داشته باشد؛ McEntee حذف امکان backtracking را مسئلهٔ طراحی می‌داند. S05.
- **چرا:** یادگیری و power ملموس می‌شود؛ ساخت room تازه برای هر reward لازم نیست.
- **CLAWD:** HEAP cistern قبل از drain مسیر balcony؛ بعد از drain مسیر کف و tunnel؛ پس از double jump عبور مستقیم سقفی. main path را با تغییر آب پشت سر بازیکن قطع نکنید.
- **هزینه:** low–medium؛ دو یا سه preset، نه fluid simulation.

#### P20 — Optional Deep Layer | لایهٔ عمیق اختیاری

- **چیست:** پایان عادی کافی و کامل؛ عمق اضافه برای بازیکن پیگیر با قرارداد روشن.
- **نمونه:** Animal Well سه audience/layer دارد؛ ESA postgameِ ARG-like را اضافه کرد و بعداً فهمید شروع بسیار آشکارش بازیکنان عادی را به مسیر نامناسب می‌کشاند. S06، S13.
- **چرا:** راز باقیمانده جهان را بزرگ‌تر حس می‌کند، بدون تحمیل تکلیف به همه.
- **CLAWD:** DEPENDENCY HELL برچسب «optional diagnostics» در map و terminal؛ هیچ boss flag ضروری PRODUCTION در آن نباشد. دو یا سه puzzle room کافی است؛ ARG برون‌بازی فعلاً حذف.
- **هزینه:** medium؛ محدود کردن scope بخش اصلیِ کاهش هزینه است.

#### P21 — Tension–Rest–Reveal | تنش، استراحت، کشف

- **چیست:** پس از challenge یک فضای کم‌خطر برای خواندن و بازسازی موقعیت، سپس revelation.
- **نمونه:** Ori Windtorn Ruins پس از burrow platforming و پیش از escape به بخش خطی روایت تبدیل شد؛ McEntee این تصمیم را برای pacing مفید می‌داند. Rain World با soundscape mood محیط را می‌سازد. S05، S17.
- **چرا:** surprise وقتی register می‌شود که attention صرف زنده‌ماندن نباشد.
- **CLAWD:** پس از escapeِ HEAP یک safe cache با نمای پایین‌رفتن آب؛ دشمن/timer خاموش. نیازی به terminal fast travel دوم نیست؛ rest ledge با bench اصلی اشتباه نشود.
- **هزینه:** low؛ یک screen آرام و audio cue.

#### P22 — Legible Optional Branch | شاخهٔ اختیاریِ خوانا

- **چیست:** هزینه و خطر شاخه پیش از ورود روشن باشد؛ discovery پاداشِ انتخاب، نه تنبیه ناآگاهی.
- **نمونه:** Blasphemous انشعاب Wasteland را اصلاح کرد تا مسیر آسان‌تر Mercy Dreams جذاب‌تر از مسیر کوهستان سخت دیده شود؛ step-ladder جای gap را گرفت. S10.
- **چرا:** بازیکن سختی را انتخاب می‌کند و failure را به انتخاب خود نسبت می‌دهد.
- **CLAWD:** DEPTHS به HEAP با کف و light آرام؛ به Hell با dependency chainهای درهم، warning plaque و landing قابل‌بازگشت. palette تنها کافی نیست؛ silhouette و حرکت خطر هم فرق کند.
- **هزینه:** low؛ dressing و geometry جزئی.

#### P23 — Teach–Test–Twist | آموزش، آزمون، وارونه‌سازی

- **چیست:** mechanic را ابتدا بدون فشار، سپس در challenge و در آخر با کاربرد خلاف انتظار ارائه کنید.
- **نمونه:** Ori collapsing platform اول مانع traversal است، سپس باید عمداً شکسته شود تا projectile عبور کند؛ Celeste Forsaken City dash و strawberryهای معمول/winged را معرفی می‌کند. S05، S25.
- **چرا:** skill با understanding رشد می‌کند؛ twist از قانون آموخته‌شده می‌آید.
- **CLAWD:** NETWORK: relay زردِ ثابت را catch کنید؛ بعد هدف متحرک؛ در secret آخر projectile را برنگردانید و از پایین‌اش عبور کنید تا firewall خودش relay را بزند. cue قابل‌دیدن، نه راه‌حل حدسی.
- **هزینه:** low–medium؛ reuse projectile/catch با هدف‌های مشخص.

#### P24 — Asynchronous Relay | relay همکاریِ غیرهم‌زمان

- **چیست:** نفر A تغییر پایدار ایجاد کند، نفر B در مکان دیگر اثرش را استفاده کند؛ simultaneous input لازم نیست.
- **نمونهٔ نزدیک، نه یکسان:** Guacamelee! 2 اجازه می‌دهد هر player در combat در dimension خودش باشد؛ Rain World Jolly Co-op رسیدن به shelter را با policyهای متفاوت حل می‌کند. این منابع **اثباتِ puzzle بین دو room در مدل آنلاین CLAWD نیستند**. پیشنهاد زیر synthesis است. S18، S19.
- **چرا:** همکاری از «اطلاعات و پیامد مشترک» می‌آید، نه آزمون latency.
- **CLAWD:** در THREAD TOWER یک نفر relay A را latch می‌کند؛ دیگری بعداً در مسیر B elevator را آزاد می‌کند؛ دو مسیر در rendezvous به هم می‌رسند. disconnect با agent fallback یا ورودی بازگشت حل شود.
- **هزینه:** medium؛ state مشترک و طراحی recovery؛ physics مشترکِ carry حذف.

#### P25 — Parallel Routes, Shared Reunion | مسیر موازی و ملاقات دوباره

- **چیست:** دو player می‌توانند جدا شوند اما target مشترک، مسیر برگشت و محل ملاقات روشن دارند.
- **نمونهٔ هشدار:** Guacamelee! 2 precision platforming غالباً به «یک نفر انجام می‌دهد، دیگران orb می‌شوند» می‌رسد؛ review این را کاهش مشارکت می‌داند. Rain World با camera targeting و shelter policy جدایی را مدیریت می‌کند. S18، S19.
- **چرا:** اختلاف skill به انتظار یا احساس بی‌فایده‌بودن تبدیل نمی‌شود.
- **CLAWD:** tower دو route به balcony `TT-barrier`: PC route با dashهای optional، phone route با سکوهای پایدار و relay. هر دو یک shortcut واقعی باز کنند؛ نقش‌ها قابل‌تعویض باشد، نه قفل بر اساس device.
- **هزینه:** medium؛ دو path کوتاه، نه دو نسخهٔ کامل zone.

#### P26 — Density Budget + Breathing Space | تراکم با بودجهٔ تنفس

- **چیست:** هر room یک وظیفهٔ اصلی و حداکثر چند معنای ثانویه؛ همهٔ screenها combat+puzzle+secret نباشند.
- **نمونه:** Animal Well با 256 room و ID یک‌بایتی scope را محدود کرد؛ Teikari اتاق‌های کوچک و نبود فضای خالی ESA را نقد می‌کند. S08، S13.
- **چرا:** roomهای قابل‌حفظ و surpriseهای متمایز؛ recognition بدون سکوت تصویری اتفاق نمی‌افتد.
- **CLAWD:** هر zone یک landmark room آرام، یک local loop و دو wow هدف‌دار؛ roomهای انتقالی می‌توانند کوتاه باشند. «کمتر از 256 room» هدفِ خودکار نیست؛ بودجه را با time-to-traverse و iteration بسنجید.
- **هزینه:** low؛ معمولاً حذف یا بازچینی، نه افزودن سیستم.

### ۲.۴. Coverage — درس مشخص از همهٔ بازی‌های درخواستی

| بازی | مثال بررسی‌شده | چیزی که برای CLAWD برداریم | چیزی که کپی نکنیم | منبع |
| --- | --- | --- | --- | --- |
| Super Metroid | Red Brinstar/Red Tower؛ بازگشت با Ice Beam و استفاده از Ripperهای یخ‌زده | loopِ توانایی و تغییر معنای دشمن به platform | hard gate صرفاً بر اساس height با وجود wall jump | S02، S28 |
| Metroid Dread | slide یک‌طرفه؛ Morph Ball نزدیک teleporter به Varia Suit؛ early Bombs/Kraid | first-use نزدیک و sequence breakِ سالم | بستن مکرر پشت سر گروه | S04، S29 |
| Hollow Knight | Blue Lake/City of Tears؛ چهار ورودی Resting Grounds؛ nail bounce | جهان علّی، چند مسیر، shortcut پاداشی | وسعت بیش از ظرفیت حافظه و تیم | S01، S03، S27 |
| Ori and the Will of the Wisps | Windswept Wastes، sand/collapsing platforms، Windtorn Ruins | mechanic workshop، برگشت‌پذیری، تنفس پیش از escape | ability فقط برای یک نوع در | S05 |
| Axiom Verge | Address Disruptor در Absu و تغییر blocks/enemies | debug به‌عنوان reinterpretation با rule محدود | shader glitch همه‌جا بدون affordance | S14، S26 |
| Animal Well | disc به‌عنوان وسیلهٔ حرکت؛ egg hunt و سه layer | چندکاربردی‌بودن و بازخوانی decoration | mysteryِ جمعی اجباری در main path | S06، S08 |
| Tunic | manual و Holy Cross؛ درهای patternedِ Overworld | README و knowledge gate اختیاری | پنهان کردن basic controls و متن ناخوانا روی phone | S07، S22 |
| Celeste | Forsaken City، شاخه‌های strawberry و forgiving movement | challenge کوتاه، landing واضح، coyote/buffer | زنجیرهٔ precision اجباری برای دو player آنلاین | S09، S25 |
| Prince of Persia: The Lost Crown | Memory Shards؛ Guided/Exploration mode | pin زمینه‌دار و lock-state روشن | aiming/scanning UI پیچیده برای ثبت یادداشت | S11 |
| Nine Sols | Four Seasons Pavilion در New Kunlun؛ Taopunkِ محیط | پایگاه خوانا و علت صنعتی پشت scenery | تلقیِ قوت combat به‌عنوان اثباتِ قوت map | S12، S24 |
| Blasphemous | Albero shortcutها؛ Mercy Dreams/Where Olive Trees Wither | gate کوچک، return بعد boss، signal difficulty | کپی مستقیم هفت screen بین checkpointها به CLAWD | S10 |
| Haiku the Robot | Arcadia؛ Pinion’s Expanse/Train Stations | fast travel به‌صورت زیرساخت درون‌جهانی | فرض اینکه معرفی تبلیغاتی معادل postmortem است | S20، S21 |
| La-Mulana | Gate of Guidance، tabletها و Holy Grail | آموزش grammarِ clue و archive | فاصلهٔ زیاد clue/puzzle/item در مسیر ضروری | S15، S16، S32 |
| Rain World | محیط صنعتی متروک، تهدید rain؛ camera/shelter در Jolly Co-op | anticipation صوتی و policy روشن reunion | ecology simulation کامل و shared camera | S17، S19 |
| Outer Wilds | found textِ High Energy Lab؛ ship log؛ progression با knowledge | log از چیزهای واقعاً فهمیده‌شده؛ clue پیونددهنده | time loop کامل یا حذف همهٔ rewardهای action | S23 |

**نکتهٔ دامنه:** Celeste، Tunic، Rain World و Outer Wilds لزوماً همان metroidvaniaِ ability-gatedِ CLAWD نیستند؛ کاربردشان در این گزارش room composition، mystery، navigation و state است. وجود co-op در یک بازی local، شاهد عملکرد آنلاین در 250ms نیست.

## ۳. Signature moments — دو لحظه برای هر یک از هشت zone

**همهٔ roomها و نام‌های این بخش پیشنهاد جدید برای CLAWD هستند، نه توصیف build موجود.** ابعاد به tile نوشته شده‌اند. یک screen تقریباً 24×13 tile است؛ ارتفاع نمایش واقعاً 13.5 tile می‌شود، بنابراین روی مرز نیم‌tile پایین HUD یا landing حیاتی نگذارید. اعداد blockout هستند. اگر dash یا wall jump از قبل در دسترس باشد، «ارتفاع بیش از 3.5 tile» به‌تنهایی hard gate محسوب نمی‌شود.

### ۳.۱. SOURCE TREE

**ST-A — «Root که همیشه زیر پایمان بود» | P04، P09 | low**

- **Setup:** در `ST-root-bench`، trunk شاخص از کف به سقف می‌رود؛ سمت راست یک gate بسته و cable ریشه‌ای دیده می‌شود. بازیکن بعداً در GIT همان root را با رنگ قدیمی می‌بیند.
- **Payoff:** پس از mergeِ GIT، یک room کوتاه به پشت همان gate می‌رسد. نخست lamp و bench از شکاف دیده می‌شوند، بعد gate باز می‌شود؛ اسم SOURCE TREE با تأخیر کوتاه ظاهر شود تا خود recognition جلوتر باشد.
- **اجرای ارزان:** door pair ثابت، gate latch و sprite مشترک؛ هیچ room نباید هنگام animation واقعاً جابه‌جا شود. دو player در roomهای جدا می‌توانند همین اتصال را بعداً جداگانه کشف کنند.
- **Theme:** rootِ source و rootِ history یک مکان‌اند، نه دو asset بی‌ارتباط. الهام: Crystal Peak–Dirtmouth و coherence در Hollow Knight، S01/S03.

**ST-B — «Comment زنده» | P14، P15 | low–medium**

- **Setup:** یک screen آرام با سه branch خمیده و mothها؛ روی trunk سه comment کوتاه که جهت نگاه‌کردن را القا می‌کنند. secret از شروع بازی با kit پایه قابل‌حل باشد.
- **Payoff:** README fragment بعدی نشان می‌دهد branchها «مسیر projectile» هستند. catchِ یک projectile زرد آن را در امتداد سه relay می‌فرستد و fake dead-code wall باز می‌شود؛ اولین محیط از decoration به دستور قابل‌فهم تبدیل می‌شود.
- **اجرای ارزان:** سه target ثابت، ترتیب کوتاه و reaction برای تلاش غلط. input secret را از controller یا swipe دشوار مستقل کنید؛ solution با موقعیت و catch باشد، نه تایپ کد. reward: یک agent cosmetic/optional utility، نه ability ضروری.
- **Theme:** comment ظاهراً اجرا نمی‌شود اما برای انسان اطلاعات دارد. الهام: Tunic/Animal Well، S06/S07/S22.

### ۳.۲. DEPENDENCY DEPTHS

**DD-A — «همهٔ importها به یک package می‌رسیدند» | P03، P10 | low**

- **Setup:** loop چهار تا شش room با سه ستون package؛ کابل‌های import پشت هر کدام به یک core می‌روند. در ابتدای سفر یک gate نازک کنار bench بسته است.
- **Payoff:** resolution رویداد اصلی/باس این zone ستون‌های تکراری را خاموش می‌کند؛ بازیکن از پشت core یک case را می‌شکند و مستقیماً کنار bench درمی‌آید. short return را با همان صدای bench قابل‌شناسایی کنید.
- **اجرای ارزان:** به‌جای ساخت resolver پیچیده، یک world flag؛ art duplicateها محو شود و platformهای ضروری حذف نشوند. boss موجود، اگر هست، همین flag را set کند؛ boss تازه فقط برای این لحظه لازم نیست.
- **Theme:** deduplication در طول سفر دیده و در کوتاه‌شدن graph تجربه می‌شود. الهام: shortcut بعد boss در Blasphemous، S10.

**DD-B — «DAG نبود؛ cycle بود» | P17، P22 | low–medium**

- **Setup:** یک shaft حدود 24×26 با تابلو `A → B → C`، crumbling platform و یک bridge آشکارِ cracked. route عادی از side ledgeهای پایدار عبور کند.
- **Payoff:** در پایین، کابل C دوباره به A برمی‌گردد و دریچهٔ اختیاری DEPENDENCY HELL آشکار می‌شود. بازیکن می‌فهمد این عمق، همان cycleِ زیر سازهٔ آشناست. pogo روی دشمن مشخص، ورود زودتر را ممکن کند، اما اجباری نباشد.
- **اجرای ارزان:** sequence break فقط reward اختیاری؛ خروج با kit پایه، enemy reset قابل‌اعتماد و هیچ crumble timer مشترکی که نفر دوم را جا بگذارد. boss اصلی zone می‌تواند support bridge این shaft را دائماً تثبیت کند.
- **Theme:** dependency graphِ ظاهراً سالم زیرش cycle پنهان دارد؛ topology همان joke است.

### ۳.۳. THE HEAP

**HP-A — «Memory freed؛ شهر پایین آب پنهان بود» | P18، P19 | medium**

- **Setup:** cistern حدود 48×26؛ در مسیر بالایی فقط outlineِ doorها، numbered addressها و یک statue نیمه‌غرق دیده شوند. پیشرفت قبلی دو سطحِ آب تعریف‌شده را پایین بیاورد.
- **Payoff:** THE LEAK double jump می‌دهد و آخرین drain پایدار، ground route و HEAP–NETWORK را آشکار می‌کند. پنجرهٔ امن بالای arena دو مسیر جدید را در یک قاب نشان دهد؛ map فقط مکان‌های واقعاً دیده‌شده را outline کند.
- **اجرای ارزان:** سه preset آب و collision؛ نه fluid simulation. water کاهش‌یافته روی client دیگر هم اعمال شود، اما raft/landing ضروری تا تخلیهٔ occupancy حفظ شود. pipe کاهش فشار را در zone قدیمی بازتاب دهد.
- **Theme:** آزادشدن memory، آزادشدن فضای قابل‌عبور است. الهام: world state در Dread و criticism/reuse در ESA، S13/S30/S31.

**HP-B — «Stack traceِ فرار» | P21، P23 | medium**

- **Setup:** escape shaft حدود 24×39، سه screen؛ پیش از trigger مسیر را در شرایط کم‌خطر ببینید. warningِ memory leak از پایین شروع شود؛ مسیر اصلی فقط روی mechanics آموخته‌شده تکیه کند.
- **Payoff:** در بالا بازیکن یک vent را از far side باز می‌کند و در room امنی که قبلاً از SOURCE TREE دیده بود وارد می‌شود. برای حفظ graph بخش ۴، این اتصال **از مسیر NETWORK به SOURCE TREE** ادامه پیدا کند، نه یک یال مستقیمِ اضافیِ HEAP–SOURCE.
- **اجرای ارزان:** escape با timer/مایع محلی؛ reset سریع. در co-op شروع با تأیید هر دو نفرِ حاضر؛ برای کسی که در zone دیگری است world flood آغاز نشود. برای سازگاری با یالِ gatedِ HEAP–NETWORK، این escape پس از THE LEAK در exit connector قرار گیرد؛ double jump پیش‌تر در room امن آموزش داده شود. rising liquid فقط overflow محلی است؛ شکست/resetِ escape سطحِ آبِ جهان را به وضعیت پیش از boss برنگرداند.
- **Theme:** escape به‌شکل unwindِ stack؛ آدرس‌ها از پایین به بالا به root نزدیک می‌شوند. بعد از پایان، vent shortcut بماند ولی escape قابل‌تکرارِ بی‌خطر باشد.

### ۳.۴. THE NETWORK

**NW-A — «Ping روشن؛ راه قدیمی پاسخ داد» | P07، P10 | low–medium**

- **Setup:** در router central سه cable به stubهای روشن/خاموش map می‌روند؛ یک connection به SOURCE TREE قبلاً دیده شده و یک connection از HEAP آمده است.
- **Payoff:** با حل relay، pulse روی cable می‌رود؛ یک shutter باز می‌شود و trunk آشنای SOURCE TREE پشت window دیده می‌شود. از این پس gate NETWORK–SOURCE از هر دو طرف باز و راه اصلی مستقل از timed portهاست.
- **اجرای ارزان:** tween کوتاه در room حاضر و iconِ changed-link برای player دور؛ به‌جای tracking هزار packet، سه مسیر ثابت. گرفتن curl پیش از این event یک swing کوتاه امن برای reachِ relay ایجاد کند.
- **Theme:** topology منطقی network با کابل قابل‌دنبال‌کردن تبدیل به geography می‌شود. الهام: coherence و چند ورودی در Hollow Knight، S01/S03.

**NW-B — «Firewall corridor نبود؛ boundary بود» | P16، P19 | medium**

- **Setup:** پیش از ssh، سه window در wall با texture ثابت دیده شوند؛ پشت یکی یک safe room و پشت دیگری tower silhouette است. مسیر ordinary با timed ports موجود قابل‌عبور است.
- **Payoff:** ssh اجازه می‌دهد از یک **wall مشخص و علامت‌دار** به passage پشتی بروید، نه هر wall. عبور اولین بار از firewallِ قبلاً ترسناک، کوتاه‌ترین راه به پایهٔ THREAD TOWER را می‌دهد؛ سپس latch آن passage برای backtracking باز بماند.
- **اجرای ارزان:** whitelist surface + destination landing + collision check. ssh فقط روی boundaryهای eligible، با مقصد previewشده؛ هیچ materialization داخل دشمن یا wall. رویداد اصلی NETWORK timed portهای مسیر برگشت را دائماً باز کند.
- **Theme:** ssh عبور امن از boundary به پشت سرویس است؛ استعاره است، شبیه‌سازی دقیق پروتکل نیست. الهام: Address Disruptor در Axiom Verge، S14/S26.

### ۳.۵. THREAD TOWER

**TT-A — «دو thread، یک barrier» | P24، P25 | medium**

- **Setup:** tower حدود 48×39، دو shaft کوتاه با یک دیدگاه مشترک در میانه. thread A راه optionalِ dash و thread B راه stable platform/relay؛ هر دو برای هر device قابل‌انتخاب‌اند.
- **Payoff:** player A flag اول و B flag دوم را در هر ترتیب فعال می‌کنند؛ lift مرکزی بدون reset زمانی باز می‌شود. در balcony ملاقات می‌کنند و دو مسیر دور، کنار یکدیگر دیده می‌شوند.
- **اجرای ارزان:** دو latch مستقل و یک logical AND، با agent fallback پس از disconnect؛ agent فقط flagِ مجاز را فعال کند، نه teleport یا ability bypass. این puzzle بین roomها، پیشنهاد CLAWD است و در منابع مطالعه‌شده به همین شکل تأیید نشده.
- **Theme:** barrier synchronization از «هر دو رسیدند» می‌آید، نه از «هر دو در یک frame دکمه زدند». حضور دو نفرِ فعال برای session عادی حفظ می‌شود.

**TT-B — «Race را حل کردیم؛ زمان به مسیر تبدیل شد» | P18، P21 | medium**

- **Setup:** platformهای موجود در upper tower به‌صورت cycleهای deterministic بالا/پایین می‌روند؛ safe ledgeهای متناوب و phase indicator واضح. first traversal مسیر کند و قابل‌بازگشت داشته باشد.
- **Payoff:** رویداد boss/progressِ tower یک scheduler را stabilise می‌کند؛ چند platform در docking points قفل می‌شوند و یک stair دائمی تا terminal می‌سازند. climbِ پرتنش قبلی، returnِ آسان می‌شود؛ window بالا routeِ GIT را نشان می‌دهد.
- **اجرای ارزان:** دو preset `running/stable`، نه physics race simulation. snapِ platform زیر پای player ممنوع؛ transition در next safe dock. shadow destination پیش از commit.
- **Theme:** race condition را با نظم قابل‌دیدن رفع کرده‌اید. الهام: ابزار traversalِ عمیق ESA و state تغییرپذیر Dread؛ mechanism دقیق، پیشنهاد جدید است.

### ۳.۶. GIT HISTORY

**GH-A — «Merge جهان‌های جدا» | P02، P04 | medium**

- **Setup:** دو شاخه در **دو room متفاوت** با hash کوتاه و background variant؛ در branch A bridge ناقص، در B support کامل است. README تصویرِ relation این دو را می‌دهد.
- **Payoff:** revert روی چند prop eligible، مسیر بین شاخه‌ها را کامل می‌کند؛ پس از eventِ merge، اتصال SOURCE–GIT باز می‌شود. روی map فقط connector افزوده شود، نه مختصات همهٔ roomها جابه‌جا.
- **اجرای ارزان:** variant tile group و latch. Islets واقعاً reunification جهانِ جزیره‌ای را وعده/اجرا می‌کند؛ اقتباس CLAWD با «وصل‌کردن seam» است، نه island physics یا انتقال roomِ دارای player. S33/S34.
- **Theme:** merge یک commit path جدید می‌سازد؛ history نه یک corridor از پوسترهای قدیمی، بلکه geometry شاخه‌ای است.

**GH-B — «Broken الآن، usable در commit قبلی» | P14، P19 | low–medium**

- **Setup:** یک room 24×13 با bridge شکسته، ghost outlineِ قطعات و sign تاریخ؛ مسیر پایین به خروج امن برسد. تعامل revert فقط prop selection نزدیک و ساده داشته باشد.
- **Payoff:** برگرداندن bridge به نسخهٔ قبلی امکان رسیدن به alcove را می‌دهد؛ alcove علتِ حذف bridge را در یک log کوتاه توضیح می‌دهد و latch مستقل shortcut را باز می‌کند. همین نشانهٔ ghost در room قدیمی SOURCE TREE معنای تازه پیدا می‌کند.
- **اجرای ارزان:** برای هر prop فقط دو state، نه rewind فریم‌به‌فریم. revert هرگز ability، boss victory یا shared discovery را پس نگیرد؛ اگر player روی prop است حذف آن defer شود. اثر رویداد اصلی GIT اتصال‌ها و archive را دائماً merge کند.
- **Theme:** revert و history مفهوم counterfactual می‌سازند، با state محدود و قابل‌آزمون. الهامِ دانش: Tunic/Outer Wilds، نه ادعای یک مکانیک یکسان در آن‌ها.

### ۳.۷. DEPENDENCY HELL — اختیاری

**DH-A — «Cycle که با حذف یک edge تمام شد» | P20، P22 | low–medium**

- **Setup:** سه room A/B/C با gateهای متمایز و arrowهای کوتاه. خروجی به DEPTHS از ابتدا باز بماند؛ گردش عمدی با warning تکرار‌شونده فهمیده شود، نه با teleport بی‌علامت.
- **Payoff:** یک relay به‌جای «باز کردن gate دیگر»، کابل cycle را قطع می‌کند؛ fourth seam به GIT آشکار می‌شود. reward یک debug fragment/upgrade غیرضروری؛ هیچ mandatory boss seal اینجا نیست.
- **اجرای ارزان:** روی layout فیزیکی یک loop واقعی رسم شود؛ از impossible-space که map را دروغگو می‌کند استفاده نکنید. cloneِ art با letter و silhouette متفاوت، نه room کاملاً یکسان.
- **Theme:** optional area به بازیکن اجازه می‌دهد dependency cycle را واقعاً در navigation حل کند. الهام: deep layerِ Animal Well/ESA، S06/S13.

**DH-B — «Version conflict؛ فقط یکی واقعی است» | P15، P16 | medium**

- **Setup:** یک room با دو bridgeِ دارای label `v1` و `v2`؛ یکی solid و دیگری ghost. READMEِ optional clue توضیح می‌دهد hash برابر چه رفتاری دارد. پنل conflict به‌صورت props، نه shell واقعی.
- **Payoff:** با revertِ prop و catch به relay، یک version compatible تثبیت می‌شود؛ bridge نهایی به far-side bypassِ PRODUCTION می‌رسد، اما **release seal نهایی را دور نمی‌زند**. حل optional boss/event، duplicate branch را خاموش و return را کوتاه می‌کند.
- **اجرای ارزان:** دو preset و یک latch؛ همهٔ dependencyها فقط data خیالیِ داخل بازی. targetِ flash/glitch محدود، واضح و بدون effect تمام‌صفحه.
- **Theme:** dependency hell با «ناسازگاریِ چیزهای نزدیک» تجربه می‌شود، نه صرفاً دشمنان سخت‌تر و نام scary.

### ۳.۸. PRODUCTION

**PR-A — «Release pipeline یک مسیر، سه علت» | P10، P18 | medium**

- **Setup:** ingress از HEAP، THREAD TOWER و HELL با seal مشترک؛ نخستین room نهایی سه gauge را نشان دهد: coolant، scheduler، connection. پیشرفت اصلی قبلی هر کدام را در وضعیت خوانا قرار داده است.
- **Payoff:** آماده‌بودن جهان اجازه می‌دهد از corridor آتشِ کنترل‌شده عبور کنید؛ در windowها pipeِ HEAP و silhouetteِ TOWER دیده می‌شوند. بازیکن می‌فهمد این‌ها مراحل بی‌ربط نبودند؛ محصول اقدامات او همین مسیر است.
- **اجرای ارزان:** سه visual flag و preset کم‌خطرتر، بدون چند نسخهٔ کامل finale. HELL فقط یک entrance/route alternative است؛ انجامش برای gauge یا seal لازم نیست.
- **Theme:** production نتیجهٔ سیستم‌های قبلی است؛ progression graph همان pipeline. الهام: spatial causalityِ Hollow Knight، S01.

**PR-B — «Hotfix: جهان شبانه دوباره نفس می‌کشد» | P21، P26 | low–medium**

- **Setup:** روی final approach یک safe window با منظرهٔ ترکیبی trunk، coolant pipe و tower؛ هیچ collectible اجباری در این قاب نباشد. emergency lighting از شروع zone دیده شده است.
- **Payoff:** final boss flag آتش/هشدار را در چند نقطهٔ کلیدی خاموش می‌کند؛ route کوتاه به terminal PRODUCTION باز می‌شود. return به zoneهای قبلی optional بماند؛ هرکدام یک تغییر کوچک قابل‌دیدن داشته باشند، نه cutscene طولانیِ اجباریِ کل map.
- **اجرای ارزان:** palette/lamp/audio variant با collision اصلی ثابت؛ خروج arena باز شود و save post-victory ثبت شود. همراهِ دور recap قابل‌بازیابی ببیند، نه cutscene ناخواسته در وسط jump.
- **Theme:** hotfix دنیا را واقعاً پایدار می‌کند؛ victory فقط credits یا damage upgrade نیست.

## ۴. Theme fit و Blueprintِ پیشنهادی جهان

### ۴.۱. کدام اقتباس‌ها بهترین fit را دارند؟

| الهام | اصل قابل‌اقتباس | نسخهٔ دقیق CLAWD | محدودکنندهٔ scope |
| --- | --- | --- | --- |
| Haiku the Robot | جهان ماشین‌ها و سفر در زیرساخت | terminal bench مثل service station؛ cableهای distinct به سه neighbor؛ train فقط اگر از قبل وجود دارد | سیستم rail تازه نسازید؛ terminal موجود کافی است. S20/S21 |
| Axiom Verge | glitch به‌عنوان تغییر rule | eligible wallهای NETWORK با ssh؛ debug relay که یک prop را stable می‌کند | whitelist از سه نوع prop؛ نه تغییر arbitrary tile. S14/S26 |
| Tunic | manual معنای world را آشکار می‌کند | چهار README fragment، با مثالِ تصویر و zoom؛ راز SOURCE TREE از اول ممکن | script رمزگذاری طولانی و UI مبهم حذف. S07/S22 |
| Animal Well | یک tool چند راه‌حل؛ secrets چندلایه | catch combat/relay/clue، agent برای fallback، یک secret layer فراتر از پایان | main path بدون community puzzle. S06 |
| Islets | progress جهان تکه‌تکه را دوباره وصل می‌کند | mergeِ GIT connectorهای ثابت و far-side route به SOURCE را فعال کند | roomهای loaded حرکت نکنند؛ world فقط یال تازه بگیرد. S33/S34 |
| Environmental Station Alpha | traversal با عمق و postgameِ مستقل | curl با مسیر سادهٔ phone و shortcut مهارتی؛ optional diagnostics | نه powerupِ بی‌قید که همهٔ gateها را با پرواز حذف کند. S13 |
| Outer Wilds | knowledge و log، نه فراموشیِ forced | logِ clueها با links بین roomهای دیده‌شده، «سؤال باز» به‌جای همهٔ answerها | journal جواب نداده را invent نکند؛ no global time loop. S23 |
| Nine Sols | scenery صنعتی معنای روایی دارد | کشف اینکه علف SOURCE از منابع HEAP تغذیه می‌کند؛ pipe علت را نشان دهد | lore فقط flavor نباشد، اما long exposition در traversal ممنوع. S12 |

**زبان theme:** متخصص programming باید analogy را بفهمد و player غیرمتخصص هم بتواند با shape/behavior مسئله را حل کند. `curl`، `ssh`، memory leak و merge استعاره‌اند؛ از آن‌ها توقع شبیه‌سازی واقعی OS یا network نداریم. secret به command-line یا دانش خارج از بازی وابسته نشود.

### ۴.۲. Final graph: دوازده یال، هر zone دقیقاً سه neighbor

این graph یک **پیشنهاد بازطراحی** است، نه بازسازی نقشهٔ فعلی. سادگیِ degree=3 حداقل خواستهٔ سه اتصال را برآورده می‌کند و جلوی connector inflation را می‌گیرد. برای یک embeddingِ planar اولیه، چرخهٔ بیرونی SOURCE–DEPTHS–HELL–GIT–SOURCE و چرخهٔ داخلی NETWORK–HEAP–PRODUCTION–TOWER–NETWORK را به‌شکل دو مستطیل تودرتو رسم کنید؛ چهار اتصال SOURCE–NETWORK، DEPTHS–HEAP، HELL–PRODUCTION و GIT–TOWER گوشه‌های متناظر را وصل می‌کنند و crossing ندارند. این یک دیاگرام adjacency است، نه تعیینِ طول و ارتفاعِ corridorها؛ stackingِ علّی و اندازه‌های واقعی باید در macro blockout بدون هم‌پوشانی تثبیت شوند. «همسایه در graph» به معنی «adjacent screen» نیست.

| یال | اولین وضعیت پیشنهادی | شرط فعال‌شدن/کارکرد | payoff فضایی |
| --- | --- | --- | --- |
| SOURCE–DEPTHS | باز پس از introduction | kit پایه؛ شاخهٔ main path اولیه | descent زیر root آشنا |
| SOURCE–NETWORK | lobby قابل‌دیدن، ادامه بسته | ورودی اولیه با double jump؛ latch جدا از سمت NETWORK پس از relay برای برگشت مستقیم | router route برگشت به root |
| SOURCE–GIT | دیده‌شده، بسته | far-side merge پس از رویداد GIT | بزرگ‌ترین return reveal |
| DEPTHS–HEAP | باز بعد progressِ DEPTHS | drop با خروج/recoveryِ پایه؛ double jump پیش‌نیاز ورود نیست | chunkها به memory basin می‌ریزند |
| DEPTHS–HELL | اختیاری و هشدار‌دار | route عادی با kit موجود؛ pogo فقط shortcut | cycle پنهان زیر dependency DAG |
| HEAP–NETWORK | ابتدا flooded/outline | drain پس از THE LEAK؛ سپس double jump کاربرد نزدیک دارد | route خشک زیر pipe |
| NETWORK–TOWER | foothold بعد curl؛ upper route بعد ssh | doorهای مشخص، backtracking با latch | firewall به tower boundary تبدیل می‌شود |
| GIT–TOWER | از سمت tower بعد ssh | traversal به GIT؛ سپس far-side shortcut مستقل | شاخهٔ history کنار execution |
| GIT–HELL | ابتدا از HELL قابل‌دیدن/بسته | conflict resolve یا revert مسیر alternative | loopِ optional به جهان اصلی |
| HEAP–PRODUCTION | فقط vista، بسته | release seal نهایی | coolant به destination خودش می‌رسد |
| TOWER–PRODUCTION | bridge دیده‌شده، بسته | همان release seal؛ مسیر main ورود نهایی | execution thread به deployment |
| HELL–PRODUCTION | optional ingress، بسته | همان release seal + latch خود route | optional challenge مسیر متفاوت، نه شرط پایان |

**Neighbor audit:** SOURCE={DEPTHS,NETWORK,GIT}؛ DEPTHS={SOURCE,HEAP,HELL}؛ HEAP={DEPTHS,NETWORK,PRODUCTION}؛ NETWORK={SOURCE,HEAP,TOWER}؛ TOWER={NETWORK,GIT,PRODUCTION}؛ GIT={SOURCE,TOWER,HELL}؛ HELL={DEPTHS,GIT,PRODUCTION}؛ PRODUCTION={HEAP,TOWER,HELL}. هر connection دو endpoint مشخص دارد؛ teleport bench در این شمارش جایگزین اتصال فیزیکی نیست.

**Main progression پیشنهادی:** SOURCE → DEPTHS → HEAP/THE LEAK → NETWORK/curl سپس ssh → TOWER → GIT/revert → PRODUCTION. این skeleton تضمین اولین تجربه است، نه ordering یگانهٔ همهٔ optionalها. بعد از NETWORK، loopِ SOURCE–DEPTHS–HEAP–NETWORK–SOURCE کامل می‌شود؛ بعد از GIT، loopِ SOURCE–NETWORK–TOWER–GIT–SOURCE کامل می‌شود. HELL یک loop جانبی از DEPTHS به GIT دارد و برای پایان ضروری نیست.

**Release seal:** یک شرط روشن مشترک، مثلاً `heap_stable && network_online && thread_stable && history_merged`. شرط‌های TOWER/GIT نام‌های پیشنهادی progress flagاند؛ باس‌های ناشناختهٔ فعلی invent نشده‌اند. ability داشتن با story event تکمیل‌شده یکسان نیست. seal هر سه entranceِ PRODUCTION یکسان است تا optional Hell یا sequence break آن را ناخواسته دور نزند. چهار indicator در ingress توضیح دهند چه prerequisiteای باقی است؛ همان progress log قابل‌بازیابی باشد.

**سازگاری با roomهای چهاردره:** هر macro connector در endpoint واقعی، door چپ/راست/بالا/پایین دارد؛ wall window بدون traversal یال نیست. room boundaryها در global tile coordinates نگه داشته شوند و دو endpoint ordinary door از نظر ارتفاع/جهت سازگار باشند. teleportهای terminal تنها exception صریح با icon هستند. شاخهٔ GIT دو room مستقل است، نه portal بی‌علامتی که مختصات ذهنی را بشکند.

### ۴.۳. Zone identity: فقط recolor کافی نیست

| Zone | landmark | دستور زبانِ shape و حرکت | نشانهٔ خروج به neighbor |
| --- | --- | --- | --- |
| SOURCE TREE | trunk و root bench | branchهای rounded، رشد آرام، grass code | root پایین به DEPTHS؛ cable مربع به NETWORK |
| DEPENDENCY DEPTHS | package core | columnهای modular و شکستگی‌ها | chunk chute به HEAP؛ cable cycle به HELL |
| THE HEAP | numbered cistern و gauge | basin، pipe، memory blockهای شناور | router addressها کنار drain به NETWORK |
| THE NETWORK | router با سه cable | rectilinear، indicator، port pulses | silhouette عمودی tower پشت firewall |
| THREAD TOWER | scheduler spindle | vertical shafts، dock markers، cycle حرکت | history ribbon در side shaftِ GIT |
| GIT HISTORY | fork/merge node | مسیرهای دوشاخه، ghost prop، hashهای کوتاه | root قدیمی SOURCE و conflict chainِ HELL |
| DEPENDENCY HELL | knotِ cable | loopهای تودرتو، duplicate با label distinct | خروج امن علامت‌دار به DEPTHS/GIT |
| PRODUCTION | release furnace/gauges | مسیر رو به هدف، heat bands، سپس خاموشی | coolant pipeِ HEAP و silhouette TOWER |

Transition room یک یا دو نشانه از neighbor داشته باشد تا zone switch تصادفی احساس نشود. رنگ با pattern/icon جفت شود؛ player بدون color یا audio هم خروج را تشخیص دهد. اسم zone و room در map همیشه قابل‌مشاهده باشد؛ نقد player از Islets نشان می‌دهد نامی که فقط هنگام ورود نمایش داده شود بعداً برای quest/navigation کارایی ندارد، اما این نقد دادهٔ یک player است، نه قانون اثبات‌شده. S40.

### ۴.۴. Boss aftermath: اتصال موجود را نگه دارید، رفت‌وبرگشت را عوض کنید

برای حفظ اصلِ «bossها جهان را دائماً تغییر می‌دهند»، تغییرها را روی bossهای موجود/برنامه‌ریزی‌شده بنشانید، نه اینکه صرفاً برای map یک boss اضافی بسازید. در SOURCE TREE، aftermath پیشنهادی یک root bridge پایدار در local loop است؛ در DEPTHS، dedup و support bridge؛ در HEAP، drain و route خشک؛ در NETWORK، latch شدن portهای مسیر برگشت؛ در TOWER، schedulerِ stable؛ در GIT، merge connector؛ در HELL، قطع cycle و short return اختیاری؛ در PRODUCTION، خاموشی heat/hazardهای منتخب و خروج arena. فقط THE LEAK و rewardِ double jump دادهٔ تأییدشدهٔ context هستند؛ جزئیات بقیه **پیشنهاد طراحی و نیازمند تطبیق با باس‌های واقعی پروژه** است.

### ۴.۵. Room budget و اولین vertical slice

**قبل از ساخت شش zone، این slice را امتحان کنید:** دو room فعلی SOURCE، local loopِ DEPTHS، cistern کوچک HEAP و یک router room؛ در حدود ۸–۱۲ room نمونه. اندازه و تعداد هدف production نیست؛ هدف آزمودن سه promise زیر است:

- بازیکن یک مانعِ آینده را به خاطر بسپارد و پس از ability برگردد.
- shortcut از far side باز شود و player بدون waypoint محل را بشناسد.
- نفر دوم در room دیگری باشد و state change/reconnect بدون trap اعمال شود.

هر room card برای AI coding agents: `purpose`، bounds، چهار door endpoint، required kit، optional bypass، landmark، secret clue، world flags read/write، safe landing، fallbackِ disconnect و test cases. agent نباید فقط از روی اسم zone room تولید کند؛ graph و قرارداد state پیش از art ثبت شود.

## ۵. Co-op and phone notes

### ۵.۱. چه چیزی واقعاً از co-op games می‌دانیم؟

Guacamelee! 2 local co-op دارد؛ review از coordinated platforming، shared camera و تبدیل همراهان به orb انتقاد می‌کند، ولی combat را سرگرم‌کننده می‌داند. این tradeoff مخصوصاً برای اختلاف skill مهم است. Rain World: Downpour در devlog رسمی، camera targeting و سه policy برای shelter/death معرفی می‌کند: Easy یک نفر به shelter؛ Normal همهٔ بدن‌ها؛ Hard همه زنده. این‌ها نمونهٔ تصمیم صریح دربارهٔ reunion هستند، نه proof برای online netcode. CLAWD دو client دارد و در این طرح camera مستقل برای هر client پیشنهاد می‌شود؛ وضعیت camera در build فعلی بررسی نشده است. بنابراین مشکل shared viewport را **نباید در بازطراحی ایجاد کرد**.[[1]](https://www.co-optimus.com/review/2185/guacamelee-2-co-op-review.html)[[2]](https://store.steampowered.com/news/posts?appids=312520&enddate=1661957422&feed=steam_community_announcements)

### ۵.۲. قرارداد پیشنهادی co-op

| موضوع | انجام دهید | پرهیز کنید |
| --- | --- | --- |
| Camera | camera مستقل هر client؛ iconِ room/location همراه | zoom-out جهانی، tether camera یا force-follow |
| Map discovery | unionِ discoveryِ session، با نشان «partner discovered»؛ location هر نفر و pin شخصی/shared | فرض اینکه دریافت flag یعنی نفر دوم خودش vista را دیده |
| Ability | abilityهای progression مشترک و monotonic؛ tutorial/replay مستقل | player دوم بدون double jump پشت gateِ جدید بماند |
| Puzzles | persistent latch، token، relay، ترتیب مستقل | دو pressure plate با دقت frame در دو room |
| Boss access | ready confirmation؛ optional reunite به foyer امن قبل شروع | کشیدن player دور از وسط platforming به arena |
| Boss reward | reward و graph flag مشترک؛ recap قابل‌دیدن و vista replay | cutscene اجباری روی client دور؛ knowledge فقط toast |
| Death | respawn شخصی در نقطهٔ امن؛ local challenge resetِ مشخص | reset جهانی همهٔ roomها با مرگ یک نفر |
| Rest/fast travel | یک terminal per zone؛ rest ledge جدا؛ travel هر نفر مستقل | انتقال اجباری هر دو نفر با interact یک نفر |
| Reunion | opt-in به bench/foyerِ کشف‌شده؛ موقعیت landing تضمین‌شده | teleport به هر نقطهٔ بدنِ همراه یا عبور از seal قفل |
| Disconnect | حفظ latchها؛ agent fallback برای puzzleِ منتظر؛ session قابل‌ادامه | پاک‌شدن progress یا deadlockِ حضور هم‌زمان |
| Role sharing | مسیر/وظیفه بر اساس انتخاب، امکان swap | قفل «PC فقط action، phone فقط spectator» |

**Reunite travel در چارچوب محدودیت bench:** پیش‌فرض فقط بین terminalهای کشف‌شده/فعال باشد. انتقال پیش از boss به foyer یک استثنای co-op است و باید با تیم تأیید شود؛ اگر اصل «هر travel فقط bench» غیرقابل‌تغییر است، foyer را نزدیک همان bench بگذارید و reunite فقط به bench انجام شود. این ویژگی نباید به cheat برای برداشتن item آن‌سوی ability gate تبدیل شود.

### ۵.۳. State تغییرپذیر بدون گیرانداختن همراه

برای تیم کوچک، world را به **discrete state** محدود کنید: gate boolean؛ HEAP flood level 0/1/2؛ scheduler running/stable؛ eligible prop old/new. نیازی به syncِ همهٔ tileها یا simulationِ fluid نیست.

1. **Authoritative progress:** یک authority معتبر session flag را ثبت کند؛ event تکراری همان نتیجه را بدهد، نه reward دوبرابر. مدل دقیق host/server باید با netcode موجود انتخاب شود.
2. **Monotonic unlock:** boss defeated، ability acquired و shortcut opened برگشت‌ناپذیرند. revert فقط prop مجاز را تغییر دهد، نه این flagها.
3. **Occupancy safety:** پیش از عوض‌کردن collision، محل هر دو player/agent بررسی شود. در حالت ناسازگار transition تا safe dock/خروج عقب بیفتد یا bridge ایمن موقت حفظ شود.
4. **Cold-room state:** room unloadشده هنگام ورود snapshot تازه را می‌خواند؛ room loadشده نیز event را reconcile می‌کند. animation ممکن است محلی باشد اما collision decision از state معتبر می‌آید.
5. **Reconnect:** snapshot شامل abilityها، boss flagها، latchها، discovery، challenge state و safe spawn باشد. HTTP reconnect یا packet retry نباید flood را دوباره بالا ببرد.
6. **Readiness:** escape محلی در خود room، دو participant حاضر را ثبت کند. از بین رفتن اتصال policy روشن دارد: pause/reset challenge یا fallback؛ timer جهانی ناخواسته برای playerِ دور ممنوع.

این‌ها engineering recommendations هستند، نه رفتار مشاهده‌شدهٔ همهٔ games. داشتن AI coding agents هزینهٔ integration و edge-case QA را حذف نمی‌کند؛ state contract ارزشمندترین سرمایه‌گذاری زیرساختی این طرح است.

### ۵.۴. Latency و phone: هندسه مهم‌تر از آسان‌کردن همه‌چیز

**ابهام ورودی:** 50–250ms اعلام‌شده مشخص نمی‌کند RTT است یا one-way. report از آن یک input-lag قطعی نمی‌سازد. movement باید locally responsive باشد؛ هزینهٔ شبکه بیشتر در shared state و reconcile دیده می‌شود. اگر حرکت client منتظر رفت‌وبرگشت authority بماند، با افزایش ledge width به‌تنهایی تجربه درست نمی‌شود.

**قواعد blockout پیشنهادی — نیازمند playtest روی Android واقعی:**

- روی main path، platformهای landing حدود 3–4 tile عرض و فاصلهٔ عمودیِ عادی حدود 2–3 tile داشته باشند؛ jump سقف 3.5 tile را به تک‌تک jumpهای اجباری تحمیل نکنید. **عرض gap به run speed، jump duration و dash distance بستگی دارد**؛ چون داده نشده‌اند مقدار قطعی برای horizontal gate نمی‌دهیم.
- درِ ورود حداقل landing امن چندtile‌ای داشته باشد؛ اولین دشمن/مایع lethal دقیقاً زیر top door نباشد. door از پایین باید با headroom و خط دید مناسب قابل‌وصول باشد.
- فرض اولیه برای coyote time و jump buffer: حدود 100–150ms؛ با phone/frame rate tuning کنید، نه copyِ عدد ثابت از Celeste. Thorson وجود همین forgiving techniques، corner correction و windowهای عریض wall jump را توضیح می‌دهد، نه این مقدار پیشنهادی برای CLAWD. S09.
- grapple/curl targetهای main path فقط به یک یا دو جهت ساده snap کنند؛ routeِ 8-direction precision اختیاری. indicatorِ target پیش از press معلوم باشد؛ سیستم auto-select هدف پشت wall را انتخاب نکند.
- timed port روی main path پس از یک clear، latch شود یا bypass دائم داشته باشد. window عبور بر اساس travel time واقعی + margin ورودی/شبکه تنظیم شود؛ «250ms پس 250ms grace کافی است» نتیجهٔ نامعتبر است.
- crumbling platformها خطر اصلی برای نفر عقب‌اند: shared crumble فقط با reset واضح و safe parallel ledge. بهتر: landing ledgeهای اصلی stable، crumbleها optional speed route؛ timer را player-indexed نکنید مگر collision semantics شبکه واقعاً پشتیبانی کند.
- hazard anticipation هم visual و هم audio: glow قبل flame، port indicator قبل close؛ catch به projectile yellow با silhouette/trail مشخص، نه فقط رنگ زرد در زمینهٔ fire.
- touch HUD روی دو گوشهٔ پایین می‌نشیند؛ clue، pickup و landing تصمیم‌ساز زیر thumbها نباشد. touch targetها در CSS/display scale سنجیده شوند، نه 16px world tile. safe-area و اندازه‌های مختلف Android را تست کنید.
- pauseِ map/README محلی باشد؛ همراه ادامه می‌دهد. actorِ خواننده فقط در safe location تعامل طولانی بکند یا وضعیت خطر را روشن ببیند؛ invulnerability نامحدود در combat با map ایجاد نکنید.
- puzzle text در 384px باید کوتاه باشد، manual زوم داشته باشد، و outlineِ خوانا علیه background. noiseِ code scrolling را پشت platform edge کم کنید.

### ۵.۵. Browser/Godot: محدودیت واقعی، نه فرضِ desktop

مستندات stableِ Godot می‌گویند export وب Godot 4 از WebGL 2 و Compatibility renderer استفاده می‌کند؛ performance موبایل از native محدودتر است و networking browser از low-level معمول پشتیبانی نمی‌کند؛ WebSocket client و WebRTC از گزینه‌های پشتیبانی‌شده‌اند. برای نسخهٔ دقیق پروژه دوباره چک شود. گزارش تغییرِ transportِ موجود را پیشنهاد نمی‌کند؛ صرفاً از طراحی map بر مبنای assumptionِ desktop networking پرهیز می‌کند. S38.[[3]](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

- فقط roomهای فعالِ دو player و دادهٔ سبک همسایه‌ها را نگه دارید؛ بازیکنان جدا یعنی ممکن است دو simulation region فعال باشد.
- terrain ثابت به‌صورت data محلی؛ network event برای flag/prop change، نه broadcastِ کل TileMap در هر frame.
- waterfall/flood نمایشی با shader ساده یا sprite، collision سطح آب discrete؛ reflection/lighting تمام‌صفحه و particle storm فقط پس از profiling.
- phone را زیر **worst case واقعی** تست کنید: دو نفر در دو room سنگین، agent فعال، flood و map thumbnail؛ نه فقط یک empty room روی PC.
- backgroundingِ tab/Android می‌تواند activity را مختل کند؛ escape و reconnect به policy توقف/بازگشت نیاز دارند. این مورد باید روی browserهای هدف آزمایش شود؛ رفتار دقیق CLAWD **unverified** است.

### ۵.۶. Playtest: معیارهایی که می‌گویند نقشه واقعاً هیجان دارد

پیش از art کامل با دو گروه تست کنید: یک pair کم‌تجربه و یک pair آشنا با metroidvania؛ سپس skill-mismatchِ PC/phone. latencyهای 50، 150 و 250ms را با تعریف روشن RTT یا one-way، jitter و قطع کوتاه اتصال تکرار کنید؛ شبکهٔ شبیه‌سازی‌شده جای Android واقعی را نمی‌گیرد.

| سؤال آزمون | ثبت عملی | علامت شکست |
| --- | --- | --- |
| «می‌دانم کجایم؟» | پس از room transition از player بخواهید bench و یک neighbor را روی map نشان دهد | صرفاً دنبال marker است؛ landmark را نمی‌شناسد |
| «می‌توانم بالاخره آنجا بروم؟» | پس از double jump نخستین مقصد انتخابی و علتش را ثبت کنید | هیچ promise قبلی به ذهن نمی‌آید |
| «اینجا وصل می‌شد؟» | در far-side return recognition قبلِ banner/waypoint را ثبت کنید | محل آشنا را فقط از نوشته تشخیص می‌دهد |
| «همراه سهم داشت؟» | زمان active play، waiting، orb/spectating و relay contribution برای هر نفر | phone player بخش عمدهٔ traversal را تماشا می‌کند |
| «جهان درست تغییر کرد؟» | partner در room دیگری، روی bridge یا raft و هنگام reconnect | trap، double reward، disappearing landing |
| «انتخاب واقعی بود؟» | مسیرهای انتخابی، time spent در dead ends و pin usage | هر شاخه همان blocker را بی‌پاداش تکرار می‌کند |

**هدف اولیه، نه نتیجهٔ پژوهش:** هر sessionِ slice بدون softlock؛ هر بازیکن حداقل یک shortcut را مستقل بشناسد و یک contribution واقعی داشته باشد. threshold نهاییِ زمان گم‌شدن/انتظار از مشاهدهٔ slice تعیین شود؛ این report دادهٔ player study CLAWD ندارد.

## ۶. Anti-patterns — چیزهایی که excitement را می‌کشند

| Anti-pattern | شاهد یا مثال | مشکل برای CLAWD | جایگزین مشخص |
| --- | --- | --- | --- |
| Degree سه از minute one | Dread عمداً فضای explorable را کوچک می‌کند؛ Hollow Knight ابتدا بازشدن تدریجی دارد. S01/S04 | سه lobby از هر zone، اما همه قفل؛ choices بی‌معنا | degree نهایی سه، یک main path اولیه و دو promise |
| One-wayهای پشت‌سرهم | Mark Brown از funnel شدن Dread انتقاد می‌کند؛ تفسیر اوست، نه consensus. S04 | player عقب یا جدا حق explore را از دست می‌دهد | یک expeditionِ محدود + خروج تضمینی + recovery |
| Shortcut بدون recognition | Colinet «Oh wow, that’s the door» را هدف می‌گیرد. S10 | بازشدن gate فقط مسافت کم می‌کند، خاطره نمی‌سازد | خروج کنار lamp/bench/trunk دیده‌شده |
| Abilityِ key-only | Ori drill کم‌تنوع را حذف کرد. S05 | ssh فقط blue door؛ curl فقط hook رنگی | هر ابزار سه کاربرد، سپس حذف duplicate mechanics |
| لغو مسیر برگشت | مشکل collapsing platformِ اولیه در Ori، S05 | partner از همان مسیر می‌آید و زمین از دست رفته | stable return ledge یا far-side latch |
| Superpowerِ بی‌قید | ESA Dash Booster X/Supercharge curve را به هم زد. S13 | double jump+dash+wall jump همهٔ intended gates را دور می‌زنند | full-kit reach test و sequence breakهای whitelist |
| تراکم بدون تنفس | خود Teikari cramped map را نقد می‌کند. S13 | phone player نمی‌تواند clue را از danger تشخیص دهد | room آرام قبل revelation؛ collision ساده |
| سختی ناگهانیِ boss | ESA feedback فاصلهٔ boss/world difficulty را برجسته می‌کند. S13 | گروه موفق در explore ناگهان متوقف می‌شود | قبل boss roomِ تمرینِ cue و retry نزدیک |
| Puzzle ضروری با clue دور و مبهم | اختلاف Naramura و critique Game Wisdom، S15/S16 | ندانستنِ «الان قابل‌حل هست؟» با «راه‌حل چیست؟» اشتباه می‌شود | solvability signal، logِ clue و optional deep puzzles |
| ARG به‌شکل next quest | ESA postgame بسیاری را ناخواسته به راز سخت کشاند. S13 | Hell پایان عادی را می‌بلعد | optional diagnostics، هیچ final prerequisite در Hell |
| همگام‌سازیِ frame-perfect | Guacamelee! 2 review مشکل coordinated platforming را توصیف می‌کند. S18 | latency و touch به مشکل map تبدیل می‌شوند | relay latchِ order-independent |
| Spectator co-op | راه‌حل orb در Guacamelee! 2 کمکی است اما مشارکت را می‌کاهد. S18 | PC همه‌چیز را انجام می‌دهد، phone فقط منتقل می‌شود | دو route با contribution متفاوت و امکان swap |
| Map زیبا اما کم‌زمینه | Memory Shards نیاز به mental note را حل می‌کند. S11 | رنگ/نقطه بدون room name یا blocker context | pin metadata و door-specific cue |
| Impossible-space بی‌علامت | Team Cherry coherent space را ضروری برای mental map می‌داند. S01 | GIT branch و Hell loop شبیه bugِ door pair می‌شوند | مختصات ثابت؛ exception teleport آشکار |
| Changed state بی‌خبر | این خطر engineering است، نمونهٔ خرابی CLAWD تأیید نشده | raft/bridge نفر دور حذف می‌شود | authoritative flags، occupancy-safe commit، recap |
| رازِ بی‌clue | McEntee از hidden barrelهای off-screenِ نیازمند jump-to-death انتقاد می‌کند. S05 | wall-hitting یا مرگ تصادفی جای inference | moth + lip + token trail؛ clue هنگام خطر زیر HUD نباشد |

**بازخورد playerها:** یک پست Reddit در favourite locations، City of Tears، Mouldwood Depths، Shoreline و چند مکان Blasphemous را در فهرست شخصی آورده؛ از این فقط می‌توان گفت atmosphere/location برای آن player مهم بوده است، نه اینکه «اکثریت» این مکان‌ها را بهترین می‌دانند. threadِ favourite shortcut moment نیز علاقهٔ نویسنده به shortcut را نشان می‌دهد، اما متن کامل پاسخ‌ها قابل‌خواندن نبود. از آن داستانِ موردی یا quote ساخته نشده است. S36/S37.

## ۷. Top 15 recommendations — رتبه‌بندی impact در برابر cost

**روش:** این رتبه‌ها judgment طراحی و dependency-aware هستند، نه ROI محاسبه‌شده از دادهٔ production. impact یعنی اثر بر شناخت جهان، agency و مشارکت؛ cost شامل art، state، browser/phone testing و integration است. پروژهٔ بدون زیرساخت shared state هزینهٔ مورد ۱ را بالاتر تجربه خواهد کرد. رتبهٔ ۱ prerequisite است حتی اگر نسبت impact/cost بعضی تغییرهای layout بهتر باشد.

| رتبه | اقدام مشخص | Impact | Cost | چرا این رتبه؟ | اولین تحویل قابل‌آزمون |
| --- | --- | --- | --- | --- | --- |
| ۱ | قرارداد shared state، monotonic unlock و occupancy-safe transition | بسیار بالا | medium–high | بدون این، flood/revert/co-op ایده‌ها unsafeاند | دو room، یک gate، reconnect، player روی prop |
| ۲ | یک far-side return به landmark موجود | بسیار بالا | low | ارزان‌ترین «wow، اینجا بود!» | DD loop به bench با lamp آشنا |
| ۳ | یک promise room پیش از double jump | بالا | low | ability فوراً مقصد ذهنی می‌گیرد | ST-pointer-balcony با gate تست‌شده |
| ۴ | تثبیت graph دوازده‌یاله و endpointها | بسیار بالا | medium | مانع بازسازی دیرهنگام شش zone می‌شود | macro blockout با neighbour audit |
| ۵ | یک room آرام پس از escapeِ HEAP | بالا | low | revelation زیر فشار combat گم نمی‌شود | safe cache و vistaِ drain |
| ۶ | landmark/shape grammar برای هر zone و transition | بالا | low–medium | orientation بدون GPS | trunk، package core و router، در سه context |
| ۷ | pin سبک با room/door/blocker context | بالا | low–medium | mental notes کم، curiosity حفظ | metadata pin روی phone و shared map |
| ۸ | first-use نزدیک برای double jump، curl و ssh | بالا | low–medium | خطای next-step و skill frustration کم | یک تمرین امن + یک shortcut برای هر ability |
| ۹ | camera مستقل، landing preview و safe door spawn | بسیار بالا | medium | phone و split-party را playable نگه می‌دارد | shaft و top/bottom entry در دو client |
| ۱۰ | HEAP با سه preset و graph changeِ boss | بسیار بالا | medium | signature theme و world agency | cistern کوچک، drain، route NETWORK |
| ۱۱ | relay دو-roomِ غیرهم‌زمان در TOWER | بالا | medium | co-op contribution واقعی، بدون timing fragile | دو latch، AND، disconnect fallback |
| ۱۲ | route stable + optional expert bypass | بالا | medium | اختلاف skill به انتظار تبدیل نمی‌شود | TT split path با نقش قابل‌تعویض |
| ۱۳ | چهار README fragmentِ تصویری | متوسط–بالا | medium | reinterpretation در roomهای قدیمی | فقط ST-B و یک صفحهٔ zoomable در slice |
| ۱۴ | یک sequence break اختیاریِ authored | متوسط | medium | mastery و replay بدون inflation | pogo entry به Hell vestibule، خروج پایه |
| ۱۵ | GIT merge با connectorهای ثابت | بالا | medium | fitِ theme قوی، ولی پس از state foundation | old/new bridge + Source return؛ no room movement |

**فعلاً نسازید:** global rewind، island physics، fluid simulation، scripting/terminal واقعی، infinite procedurally shuffled map، ARGِ خارج بازی، shared camera با dynamic zoom و puzzleِ نیازمند carry physics آنلاین. ارزش احتمالی دارند، اما نسبت به scope تیم و constraints شواهد کافی برای اولویت‌دادنشان وجود ندارد.

**ترتیب اجرای پیشنهادی:** نخست rankهای ۱–۹ در sliceِ SOURCE/DEPTHS؛ سپس HEAP و NETWORK؛ بعد co-op sliceِ TOWER؛ سپس GIT/HELL؛ PRODUCTION وقتی سه stateِ پیشین واقعاً پایدارند. cost reduction از reuseِ prop/state و محدودکردن variantها می‌آید، نه از امید به اینکه AI همهٔ edge caseها را خودکار حل می‌کند.

## ۸. Sources — منابع، لینک‌ها و وضعیت راستی‌آزمایی

### ۸.۱. منابع اولیه، transcriptها و تحلیل اصلی

- **S01 — How to design a great Metroidvania map — Wes Fenlon / Team Cherry.** مصاحبهٔ اولیهٔ ۲۰۱۷ با Ari Gibson و William Pellen، بازنشر ۲۰۲۵. متن دربارهٔ progression، حذف hard gating، Blue Lake، coherence، connections، cutting scope و blockout خوانده شد. strong primary برای Hollow Knight.
- **S02 — The World Design of Super Metroid | Boss Keys — GMTK.** تحلیل ثانویه؛ صفحه/عنوان و ارتباط با تحلیل map تأیید شد، اما load متن ویدئو 403 داد. **جزئیات transcript کامل unverified**؛ room claimها با S28 و شرح S35 تقویت شده‌اند. ادعای تماشای کامل یا quote از آن نشده است.
- **S03 — The World Design of Hollow Knight | Boss Keys — GMTK.** متن بازیابی‌شده شامل چند مسیر Resting Grounds/City، nail bounce و پاسخ Team Cherry دربارهٔ sequence break و connections. secondary analysis با نقل‌قول طراح؛ برای geometry و ordering از آن استفاده شد.
- **S04 — Why You (Probably) Didn’t Get Lost in Metroid Dread — GMTK.** transcript کامل بازیابی شد: point of no return، lock نزدیک key، teleport، breadcrumbs، انتقاد شخصی Brown و early Bombs/Kraid. نظر او با «همهٔ بازیکنان» خلط نشده است.
- **S05 — Making Ori and the Will of the Wisps’ Best Level — GMTK / Chris McEntee.** transcript بخش عمدهٔ مصاحبهٔ lead designer، دربارهٔ **Windswept Wastes**، burrow/collapsing platforms، دو مسیر main path، حذف drill، Windtorn Ruins و escape. primary design explanation؛ انتهای transcript خارج از بخش بازیابی‌شده مبنای claim نیست.
- **S06 — Interview: How Animal Well is using secrets and mysteries… — Thinky Games / Billy Basso.** ۷ مه ۲۰۲۴؛ متن کامل خوانده شد. سه layer، چند order ابزارها، یادگیری factهای کوچک و reaction به آزمایش player. برای disc ride همچنین تحلیل Thinky Games به‌عنوان شاهد ثانویه استفاده شد.
- **S07 — TUNIC: This Was Here the Whole Time — Andrew Shouldice, GDC 2023.** خلاصهٔ رسمی session دربارهٔ loose ends و secrets. توضیح سه مرحله و تصریح غیرempirical بودن مدل از گزارشِ متن‌دارِ Game Developer خوانده شد؛ این جایگزینِ ادعای مشاهدهٔ کامل talk نیست.
- **S08 — The scratch coding and sharp constraints at the heart of Animal Well — Game Developer.** ۱۹ مارس ۲۰۲۵؛ گزارش talkِ Billy Basso با توضیح 16×16=256 room و ID یک‌بایتی، به‌عنوان constraint production. نقلِ report از talk، نه postmortemِ نوشته‌شده توسط خود طراح.
- **S09 — Celeste & Forgiveness — Maddy Thorson.** primary؛ متن کامل coyote time، buffer، corner correction، wall-jump windows خوانده شد. Designing Celeste — GDC 2017 برای scopeِ workshop و ساخت 300+ stage بررسی شد؛ جزئیات آموزش room از متن session به‌تنهایی نسبت داده نشده. نام Maddy در متن گزارش استفاده شده؛ listing تاریخی نام متفاوت دارد.
- **S10 — How Blasphemous’ level design iterates on classic Metroidvanias — Game Developer / Enrique Colinet.** ۶ نوامبر ۲۰۱۹؛ مصاحبهٔ level designer دربارهٔ districts/zones/scenes، glass case، shortcutها، branchِ Mercy Dreams و playtest، checkpoint spacing. primary توضیح طراحی.
- **S11 — How Ubisoft Made The Lost Crown Its Most Accessible Game Ever — Microsoft / Rémi Boutin.** ۵ مارس ۲۰۲۵؛ مصاحبهٔ senior designer دربارهٔ Memory Shards، simplification، Guided mode، mental notes و save constraints. اصل screenshot pin با صفحهٔ رسمی Ubisoft نیز تأیید شد.
- **S12 — Nine Sols: An Interview with Red Candle Games — Into Indie Games.** ۱ ژوئیه ۲۰۲۴؛ primary برای Taopunk، world/narrative و حرکت/deflection. **توضیح مفصل topology از خود طراح در این متن وجود ندارد**؛ آن ادعا به مصاحبه نسبت داده نشده است.
- **S13 — Environmental Station Alpha — post-release thoughts — Arvi Teikari.** ۲۶ مه ۲۰۱۵؛ primary postmortem کامل. hookshot، overpowered upgrades، دشواری editor/puzzles، midgame lostness، postgame confusion و cramped map. نسخهٔ وبلاگ اصلی load نشد؛ متن بازنشرِ نویسنده در Game Developer خوانده شد.
- **S14 — Address Disruptor — Thomas Happ / Axiom Verge.** ۱۱ اوت ۲۰۱۳؛ developer blog، scrambling دشمنان. rangeِ behavior و location ابزار با S26، نه تنها این پست، تأیید شده است.
- **S15 — Meet the pioneering Japanese indie behind La-Mulana — Game Developer / Takumi Naramura.** ۲۴ سپتامبر ۲۰۱۸؛ primary interview برای puzzle-based progression، hintها و دشواری عمدی؛ بخشی دربارهٔ La-Mulana 2 است و با طراحی نسخهٔ اول خلط نشده.
- **S16 — La-Mulana 2 Gives a Whole New Meaning to Stubborn — Game Wisdom.** critique ثانویهٔ فاصلهٔ clue/puzzle/item و unclear prerequisites؛ شواهد اختلاف نگاه، نه اثبات ناعادلانه‌بودن تمام puzzleها.
- **S17 — Road to the IGF: Videocult’s Rain World — Game Developer.** ۱۹ فوریه ۲۰۱۸؛ primary interview با Joar Jakobsson/James Therrien برای industrial mood، sound layers، textless projection و threat music. از این متن عددی برای اندازهٔ room/zone استنباط نشده.
- **S18 — Guacamelee! 2 Co-Op Review — Jason Love / Co-Optimus.** ۱۷ اکتبر ۲۰۱۸؛ secondary observation مشخص دربارهٔ orb، shared camera، skill mismatch و coordinated platforming. درصدهای review در ranking CLAWD استفاده نشده‌اند.
- **S19 — Rain World: Downpour — official co-op devlogs on Steam.** primary؛ متن camera input و Easy/Normal/Hard shelter policy خوانده شد. بازآفرینی manual در wiki برای پیدا کردن topic استفاده شد؛ devlog رسمی پشتوانهٔ claim نهایی است.
- **S20 — Haiku the Robot — Mister Morris Games.** primary product page برای Arcadia، interconnected machinery world و ability progression؛ منبع توضیح فلسفهٔ room-level نیست. مصاحبهٔ معرفی‌شده در Set Side B پیدا شد، اما transcript کامل بررسی نشده: **unverified** برای هر ادعای مستقیم دربارهٔ فلسفهٔ Jordon Morris؛ چنین quoteای در report ساخته نشده.
- **S23 — Sparking Curiosity-Driven Exploration Through Narrative in Outer Wilds — Kelsey Beachum, GDC 2021 slides.pdf).** primary slides؛ نویسنده **Kelsey** است، نه Alex. Alex در thesis quotationِ slides آمده است. knowledge-only progression، showing hooks، found textِ High Energy Lab، و وظیفهٔ trackingِ ship computer از متن خوانده شد. listing رسمی talk انتساب را تأیید می‌کند.
- **S33 — Islets — Armor Games Studios.** primary publisher page برای reunite fragmented islands/world؛ از آن جزئیاتِ engine یا physicsِ moving room استنباط نشده است.
- **S34 — Kyle Thompson’s exclusive interview — Des Clics et des Lettres.** مصاحبهٔ ۲۹ سپتامبر ۲۰۲۴؛ primary برای scope، سیستم ساده، impactful low-time ideas و پرهیز از iteration بی‌پایان. جزئیات مکانیکی merge در CLAWD، پیشنهادِ این گزارش است.
- **S35 — Looking back at the level design triumphs of Super Metroid — Game Developer.** شرح ثانویهٔ Boss Keys و dependency chart؛ کمک برای corroboration موضوع S02، نه transcript کامل آن.
- **S38 — Exporting for the Web — Godot stable documentation.** primary technical docs، sections WebGL/Mobile/Networking/Threads خوانده شد. stable با زمان تغییر می‌کند؛ با Godot minor version و browser targets پروژه تطبیق داده شود.
- **S39 — TUNIC secrets model — Game Developer report of Shouldice’s talk.** همان متن مکملِ S07؛ برای explicit distinctionِ ignorance/knowledge/understanding و caveatِ empirical نبودن مدل. تکرار intentional برای ردیابیِ دقیق این claim است.

### ۸.۲. منابع تکمیلیِ مکان، room و مکانیک

- **S21 — Pinion’s Expanse — Haiku the Robot Wiki.** secondary/community برای Train Stations و Steam Town. attributionِ intention طراح از آن انجام نشده.
- **S22 — Tunic manual page 43 — TUNIC Game Wiki.** secondary برای Holy Cross به‌عنوان D-pad/arrow keys و patterned doors نزدیک fountain، West Garden و Swamp؛ screenshot/manual explanation مبنای مثال مکانیک است.
- **S24 — Four Seasons Pavilion — Nine Sols Wiki.** secondary برای Yi’s base، اتصال New Kunlun Central Hall و NPC/facilities؛ جزئیات geography با Locations هم cross-check شد.
- **S25 — Chapter 1: Forsaken City — Celeste guide, IGN.** secondary برای strawberry side rooms، Theo و cassette/alternating platforms؛ Celeste Wiki معرفی dash و normal/winged strawberry را corroborate کرد.
- **S26 — Address Disruptor 1 — Axiom Verge Wiki.** secondary؛ behaviorِ passable/impassable blocks، changed enemies و location در Absu زیر Telal variant. هیچ ادعای arbitrary runtime tile editing در Godot از آن استنباط نشده.
- **S27 — Resting Grounds — Hollow Knight Wiki.** secondary برای چهار route؛ با transcriptِ S03 cross-check شد.
- **S28 — Super Metroid: Power Bomb Expansions — Omega Metroid.** secondary walkthrough؛ Red Brinstar و استفاده از frozen Rippers برای climb/Power Bomb access؛ شاهدِ room-level، نه توضیح نیت Sakamoto.
- **S29 — Metroid Dread: Sequence Breaks — Omega Metroid.** secondary؛ Early Bombs پس از Varia Suit و routeِ Dairon، Early Grapple و خطر شکست slide jump. special Kraid payoff با S04 corroborated.
- **S30 — Metroid Dread: Frozen Planet — Omega Metroid.** secondary برای frozen doors، thermal energy و investigation در Cataris؛ Experiment No Z-57 — IGN مکان boss را corroborate می‌کند.
- **S31 — Environmental Station Alpha Quick+Full Guide — Oymon / Steam Community.** secondary برای hookshot training، console/map objective، Teleporter Access Card و encounter با drain آب. دربارهٔ فلسفهٔ طراحی، S13 اولویت دارد.
- **S32 — Cheshire’s hint-based guide to La-Mulana — Steam Community.** secondary برای Gate of Guidance به‌عنوان introductionِ puzzle/trap و اهمیت Holy Grail؛ Gate of Guidance Wiki اولین field و tablet را corroborate می‌کند.
- **S40 — Islets: Game Reflections — BH.** player critique، نه primary developer statement؛ نام zoneها، دو map zoom و friction انتخاب teleport. تجربهٔ فردیِ ثبت‌شده، نه metric عمومی.

### ۸.۳. شواهد بازیکنان و چیزهای unverified

- **S36 — Favourite locations in metroidvania games — Reddit.** opening post و فهرست شخصیِ locationها قابل‌بازیابی بود؛ هیچ درصد، consensus یا جمع‌بندی همهٔ پاسخ‌ها به آن نسبت داده نشده است.
- **S37 — Favourite metroidvania shortcut moment — Reddit.** opening snippet تأیید می‌کند نویسنده shortcutها را دوست دارد. خواندن کامل thread با 403 ناموفق بود؛ **جزئیات پاسخ‌ها و shortcut momentهای معین unverified** و از گزارش حذف شدند.
- **Haiku map-system thesis — repository listing.** عنوانِ «Haiku, the Robot. Sistema de mapas para 2D Metroidvania» در search ظاهر شد؛ متن repository با 403 خوانده نشد. **محتوای thesis و هر نتیجهٔ فنی از آن unverified**؛ report به آن تکیه ندارد.
- **اعداد CLAWD:** ابعاد پیشنهادی room، landing width، coyote/buffer timing، latency tolerance، cost ranking و تعداد roomهای slice همگی **design hypotheses، نه validated facts** هستند. engine version، movement speed، dash length، transport، save schema و رفتار Android background در build CLAWD **unverified** هستند.
- **منابع طراحان:** توضیح مستقیم topology برای Nine Sols و جزئیات room-levelِ طراح Haiku در متن‌های در‌دسترس کامل به دست نیامد؛ examplesِ مکانی با wiki/guide پشتیبانی شده‌اند، نه quote ساختگی. attributionِ جزئیات به طراحان محدود به چیزی است که واقعاً خوانده شد.

### ۸.۴. حکم نهایی برای بازطراحی

**CLAWD زمانی map به‌یادماندنی خواهد داشت که player بتواند سه جمله بگوید:** «می‌دانم نسبت به root کجا هستم»، «آن منظرهٔ قدیمی حالا قابل‌رسیدن است»، و «کاری که همراهم در جای دیگر کرد، مسیر مرا عوض کرد». برای رسیدن به این، جهان بزرگ‌تر لازم نیست؛ **اتصالِ بهتر، قرارداد state امن‌تر و دو reveal دقیق در هر zone** لازم است.
