<aside>
⚠️

این گزارش حاوی spoiler جدی برای بازی‌های مرجع است؛ برای تیم طراحی نوشته شده، نه برای معرفی بازی به بازیکن. تاریخ تدوین: ۱۱ اکتبر ۲۰۲۶. پیشنهادهای CLAWD «طرح طراحی» هستند، نه ویژگی‌های پیاده‌سازی‌شده یا یافته‌های تجربی دربارهٔ بازیکنان CLAWD.

</aside>

**تصمیم محوری:** حدود ۳۰ secret room فعلی را به زیرساختی مشترک برای سه عمق تبدیل کنید؛ به‌جای ساخت ۳۰ مکانیک یکتا، از چند prefab، یک زبان سرنخ، یک journal و یک terminal محدود استفاده کنید. اتمام داستان اصلی مستقل از حل رمزهای community باشد.

**روش و اعتبار شواهد:** توضیح نیت طراح از مصاحبه و نوشتهٔ توسعه‌دهنده؛ جزئیات راه‌حل از walkthrough و community documentation؛ نقد تجربه از تحلیل یا گزارش بازیکن. نقل‌قول مستقیم فقط جایی آمده که متن قابل‌خواندن بوده است. فهرست منابع S01 تا S38 در بخش ۱۰ است. «چرا کار می‌کند» در کاتالوگ، تحلیل طراحی این گزارش است، نه الزاماً سخن سازنده. وضعیت secrets حل‌نشده بر اساس منابع موجود است؛ بدون تأیید تازه، به اکتبر ۲۰۲۶ تعمیم داده نمی‌شود.

## ۱. Summary — ده درس اصلی

1. هر secret باید زنجیرهٔ قابل‌ردگیری **notice → suspect → test → reward** داشته باشد؛ «اتفاقی پیدا شد» جای زبان سرنخ را نمی‌گیرد.
2. moth فقط نشانهٔ **dead code قابل‌عبور** باشد؛ برای دیوار dash، firewall و floor، علامت‌های مستقل تعریف کنید.
3. سختی کشف، سختی استدلال و سختی اجرا را جدا کنید؛ حل رمز روی Android نباید نیازمند parry دقیق باشد.
4. یک rule کشف‌شده باید چند اتاق قدیمی را دوباره معنی‌دار کند؛ این بازخوانی از یک صندوق اضافی ارزشمندتر است.
5. secrets دانش‌محور باید از ابتدا قابل‌حل باشند؛ پرچم «صفحهٔ manual را گرفته» نباید اجازهٔ اجرای جواب باشد.
6. پایان اصلی و HP لازم برای آن را پشت رمز community نگذارید؛ لایهٔ سوم، دعوت به ادامه است نه جبران پایان ناقص.
7. برای فرضیهٔ غلط feedback بدهید، اما جواب را خودکار اعلام نکنید؛ سکوت رابط نباید با رد فرضیه اشتباه شود.
8. co-op را با تقسیم مشاهده و کارهای latched بسازید؛ هم‌زمانی frame-perfect، puzzle را به آزمون latency تبدیل می‌کند.
9. هر کشف باید برای هر دو نفر حق مالکیت داشته باشد؛ پاداش مشترک، مشاهدهٔ شخصی، و امکان «بعداً خودم بررسی کنم» را جدا کنید.
10. puzzle community باید با جمعیت کوچک هم زنده بماند؛ هیچ راز اصلی به Discord، وب‌سایت زنده، ساعت واقعی یا ابزار استخراج فایل وابسته نباشد.

## ۲. Clue language — سیستم کامل سرنخ برای CLAWD

### ۲.۱. شواهد طراحان و قرارداد انصاف

Billy Basso می‌گوید حتی برای آزمایش اشتباه، تا جای ممکن animation یا واکنشی می‌سازد تا بازی ایدهٔ بازیکن را به رسمیت بشناسد؛ همچنین هر puzzle را فرصت یادگرفتن یک fact دربارهٔ جهان می‌بیند. Andrew Shouldice برای Tunic اتصال‌های کشف‌پذیر را «کمی زیر سطح، در چند محل» پخش کرده، نه در یک سرنخ اجباری. جملهٔ تعیین‌کنندهٔ او: «a mystery isn’t a mystery until you have a clue». Yacht Club Games نیز قواعد صریحی برای تشخیص مسیر اصلی از secret توضیح می‌دهد. این‌ها یک فرمول واحدِ نقل‌شده از طراحان نیستند؛ چرخهٔ چهارمرحله‌ای زیر، ترکیب عملی این شواهد است.[[1]](https://thinkygames.com/features/interview-how-animal-well-is-using-secrets-and-mysteries-to-be-a-different-kind-of-metroidvania/)[[2]](https://www.vice.com/en/article/the-delicate-balancing-act-of-making-a-video-game-built-on-secrets/)[[3]](https://www.yachtclubgames.com/blog/specter-of-torment-level-design-deep-dive-5-of-5/)

| مرحله | وظیفهٔ طراحی | نمونهٔ دقیق CLAWD | معیار پذیرش |
| --- | --- | --- | --- |
| notice | جلب توجه به یک ناهنجاری | دو moth کنار seam مشخص دیوار، نه swarm تمام اتاق | بازیکن در gameplay معمول فرصت دیدن دارد؛ نیازمند screenshot zoom نیست |
| suspect | ساخت فرضیهٔ محدود | token trail به همان seam می‌رسد؛ اتاق آموزشی قبلی عبور moth از seam را نشان داده | می‌تواند بگوید «احتمالاً این دیوار dead code است»، نه «هر چیزی شاید secret باشد» |
| test | آزمون کوتاه و بی‌خطر | راه‌رفتن به سمت seam از سکوی امن | شکست HP یا collectible کم نمی‌کند؛ تلاش دوم فوری است |
| reward | اثبات کشف و پرداخت | fade کاشی‌ها، صدای بازشدن، یک fragment و log جدید | پاسخ هم مکانی است هم اطلاعاتی؛ بازیکن می‌فهمد چرا درست بود |

**قاعدهٔ داخلی پیشنهادی:** برای casual، دو کانال هم‌معنا؛ برای curious، یک نشانهٔ محلی + rule آموخته‌شده؛ برای community، ترکیب شواهد چند محل + تأیید پاسخ. تعداد سرنخ کمتر الزاماً عمق بیشتر نیست. عمق از تغییر تفسیر می‌آید.

### ۲.۲. واژه‌نامهٔ بصری، صوتی و متنی

| خانوادهٔ secret | visual ثابت | audio مکمل | متن/feedback | عمل معتبر |
| --- | --- | --- | --- | --- |
| dead code | moth با silhouette روشن؛ seam تکرارشونده، بدون crack | flutter نزدیک seam | «unreachable ≠ impassable» در آموزش؛ `dead branch` پس از کشف | راه‌رفتن؛ بدون ability |
| cracked wall | crack مورب ضخیم، قطعهٔ شل؛ بدون moth | صدای brittle هنگام برخورد عادی | شکست با ضربهٔ عادی: dust بدون بازشدن | dash |
| catch switch | socket با علامت برگشت `↩`؛ خط اتصال به emitter | click هنگام دریافت projectile | socket در انتظار: pulse آرام | parry/catch و بازتاب |
| agent key | recess کوچک با icon کلید + silhouette helper | دو click برای ورود و فعال‌شدن | `waiting for worker` | helper agent |
| sudo ledge | دو پله/دو chevron عمودی، platform قابل‌دیدن | صدای پاداش فقط پس از رسیدن | pin با icon double jump | double jump؛ این ability-gate است |
| curl ring | حلقهٔ شکستهٔ خوانا و cable کوتاه | pluck پس از اتصال | hover/ping روی هدف مجاز | grapple |
| ssh firewall | خطوط عمودی باریک + گسستگی منظم؛ شکل متفاوت از دیوار جامد | buzz ملایم، نه نشانهٔ انحصاری | `thin barrier`؛ failure قابل‌تشخیص | phase پس از دریافت ssh |
| breakpoint device | bracket گوشه‌ها + pause icon روی جسم | tick قابل‌شنیدن و قابل‌دیدن | timer بصری loop می‌شود | freeze وضعیت محلی |
| revert device | قاب cyan + فلش منحنی + شمارهٔ revision | rewind کوتاه هنگام undo | دو حالت before/after در panel | undo محدودهٔ مشخص |
| --force floor | pattern کف با دو chevron رو به پایین و bolt | thunk؛ تفاوت با crack دیوار | floor در اولین نمونه از زاویهٔ امن دیده می‌شود | --force |
| knowledge terminal | prompt ثابت `>`، قاب کتاب روی سطح؛ بدون ability icon | accept/reject متمایز | خطای صریح `unknown command` / `wrong value` | command یا code با input selector |
| lore/joke غیرمکانیکی | قاب quote/comment؛ بدون seam تعاملی | ambience عادی | برچسب `comment` یا `archive` | خواندن؛ نباید fake clue کل جهان شود |

**token trail دستور عمل نیست.** tokenها فقط مقصد یا مسیر امن را نشان می‌دهند. arc بالا یعنی به لبه نگاه کن؛ خط افقیِ قطع‌شده در دیوار یعنی ادامهٔ مسیر را بررسی کن. هیچ token در پرتگاه کور قرار نگیرد مگر platform امن قابل‌دیدن باشد. tokenهای جمع‌شده نباید تنها سرنخ را برای نفر دوم پاک کنند: outline یا decal کم‌رنگ باقی بماند.

**map gap فقط corroboration است.** همهٔ فضای خالی نقشه secret نیست. کنار نقاط مشکوک، pin دستی با سه شکل `wall?` / `ability` / `code` بدهید؛ نقشهٔ عادی existence لایهٔ سوم را شمارش نکند. پاداشِ پرکردن نقشه را با پایان داستان یکی نکنید.

**moth و تاریخ:** اشارهٔ ۱۹۴۷ عالی است، اما عبارت «اولین computer bug» دقیق نیست. Smithsonian دربارهٔ moth گیرکرده در Mark II و عبارت «first actual case of bug being found» توضیح می‌دهد؛ bug پیش‌تر برای نقص فنی به کار می‌رفت. log بازی بنویسد: «یک bug واقعی در relay — 1947»، نه ادعای اختراع واژه یا اولین خطای کامپیوتری.[[4]](https://www.si.edu/object/log-book-computer-bug:nmah_334663)

**programming theme ≠ آموزش نادرست:** `robots.txt` سند محدودیت crawler است، نه قفل امنیتی؛ `sudo` افزایش privilege است نه double jump، و `ssh` ذاتاً عبور از firewall نیست. نام abilityها استعارهٔ جهان هستند. man page بازی این تفاوت را با یک جمله روشن کند. هیچ secret به اجرای دستور روی PC، console مرورگر یا سیستم‌عامل واقعی نیاز ندارد.

### ۲.۳. ترتیب آموزش و کنترل consistency

- **اولین dead code:** در مسیر عبور، moth داخل seam می‌رود؛ token پشت seam از کنار دیده می‌شود؛ reward کوچک. موفقیت اختیاری ولی احتمال notice زیاد.
- **دومین نمونه:** seam بدون token، با moth؛ امتحان همان rule.
- **سومین نمونه:** اتاق قدیمی با همان moth پس از دسترسی به مسیر برگشت؛ به بازیکن ارزش revisiting را نشان دهید.
- **نخستین crack:** پیش از reward مهم، crack بی‌خطر و بازخورد dust؛ هرگز همان silhouette dead code را reuse نکنید.
- **نخستین terminal:** یک نمونهٔ حل‌شده در کنار panel خالی؛ input، Submit، Clear و نوع feedback بدون lore cryptic آموزش داده شوند.
- **نخستین curious secret:** rule قدیمی در زمینهٔ جدید، نه یک symbol بدون سابقه.

برای هر secret یک record داشته باشید: `secret_id`, `room_id`, `layer`, `clue_family`, `clue_ids`, `required_abilities`, `knowledge_rule`, `accepted_actions`, `wrong_feedback`, `reward_id`, `solo_fallback`, `hint_steps`, `reset_policy`. validator باید اختلاف ability icon و accepted action، clue-only-audio، reward تکراری و نبود fallback را گزارش کند. این پیشنهاد پیاده‌سازی است، نه نتیجهٔ benchmark.

### ۲.۴. hint بدون spoiler — طراحی قابل‌اجرا

Tunic سرنخ‌ها را در manual و حتی پس از ending اول می‌گذارد؛ Outer Wilds در ship log فقط دانسته‌های قطعی را ثبت می‌کند، نه استنتاج حل‌نشده را. راهنمای community برای Crystal Hearts در Celeste نشان می‌دهد که Location، Hint و Solution می‌توانند جدا شوند؛ این **سیستم رسمی خود Celeste نیست**.[[2]](https://www.vice.com/en/article/the-delicate-balancing-act-of-making-a-video-game-built-on-secrets/)[[5]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)[[6]](https://www.reddit.com/r/celestegame/comments/evw2u0/crystal_hearts_hint_guide/)

پیشنهاد: journal با «یک hint دیگر» به درخواست هر نفر؛ نه companion پرحرف و نه timer افشای جواب. نمونهٔ `git history`:

1. **attention:** «این دو log دربارهٔ یک در حرف می‌زنند.»
2. **relationship:** «ترتیب revision با ترتیب پیدا کردن log یکی نیست.»
3. **operation:** «به آخرین revision که در هنوز باز بود برگرد.»
4. **solution اختیاری، جدا و تأییددار:** «revision b02 را در archive terminal انتخاب کن.»

hint را تنها برای صاحب درخواست باز کنید؛ وضعیت puzzle مشترک است، spoiler سطح شخصی. `--verbose` مکمل visual باشد: نزدیک dead code outline بدهد، نه جواب code، محل تمام rewardها یا مسیر لایهٔ سوم. mode accessibility برای کنتراست/شکل از plugin slot و هزینهٔ اقتصادی مستقل باشد؛ نسخهٔ gameplay افزون بر آن می‌تواند برد تشخیص داشته باشد.

## ۳. Secret pattern catalogue — سی الگوی نام‌دار

**تعریف هزینه:** low = یک variation از prefab موجود و tile/text ساده؛ medium = trigger یا state جدید با QA چند حالت؛ high = زیرسیستم، cross-room state، UI اختصاصی یا محتوای زیاد. زمان واقعی وابسته به وضعیت کد است؛ برآورد روز/بودجهٔ مالی قابل‌اتکا از منابع نداریم. «community» یعنی مناسب اشتراک و ترکیب شواهد، نه الزام به جمعیت آنلاین.

### P01 — Seam Passage / دیوار با زبان ثابت

- **چیست:** سطحی ظاهراً جامد، با قرارداد بصری قابل‌آموختن.
- **نمونهٔ واقعی:** Haiku the Robot، false ceiling بالای اتاق مجاور Derelict Hole که به chip می‌رسد؛ راهنمای community محل را ثبت کرده است. منبع: S31.
- **چرا:** بازخوانی هندسه به discovery تبدیل می‌شود؛ ولی بدون clue می‌تواند wall-sweeping شود.
- **CLAWD:** seam در `/unused` با moth؛ عبور عادی به memory fragment.
- **لایه/هزینه:** casual / low.

### P02 — Breakable Side Branch / شاخهٔ شکستنی

- **چیست:** ورودی secret پشت مانع دارای action روشن.
- **نمونه:** Shovel Knight: Specter of Torment؛ developer توضیح می‌دهد secrets اغلب پشت breakable walls و در جهت متفاوت از main path هستند. S32.
- **چرا:** اصطکاک ورودی می‌گوید این مسیر اختیاری است، نه مسیر اصلی تصادفی.
- **CLAWD:** crack کنار راهروی compilation؛ dash، اتاق تک‌صفحه‌ای و fragment.
- **لایه/هزینه:** casual / low.

### P03 — Audible Rescue / نجاتِ شنیدنی

- **چیست:** موجود پشت دیوار با صدای جهت‌دار کشف می‌شود.
- **نمونه:** Hollow Knight، گریهٔ Grub نزدیک jar؛ نجات با Nail و پرداخت Grubfather. S15.
- **چرا:** انگیزهٔ عاطفی + تأیید فوری، نه صرفاً currency.
- **CLAWD:** agent گیرکرده در dead branch، beep و bubble بصری؛ پس از نجات در hub ظاهر شود.
- **لایه/هزینه:** casual / medium.

### P04 — Visible Desire / پاداشِ دیده‌شده، مسیرِ پنهان

- **چیست:** reward پیش از مسیر ورود دیده می‌شود.
- **نمونه:** Celeste، strawberries در detourهای سخت/اختیاری؛ خود berry دعوت بصری است. S27–S29.
- **چرا:** سؤال مشخص «چطور آنجا بروم؟» می‌سازد و ارزش تلاش را نشان می‌دهد.
- **CLAWD:** plugin پشت پنجرهٔ glass RAM؛ مسیر از حلقهٔ curl در اتاق مجاور.
- **لایه/هزینه:** casual / low.

### P05 — Completion Sweep / ابزار جست‌وجوی دیرهنگام

- **چیست:** بعد از یادگیری زبان محیط، ابزار احتمال missed secret را کم می‌کند.
- **نمونه:** Super Metroid، X-Ray Scope passage و block مخفی را نشان می‌دهد و برای اتمام لازم نیست. S17.
- **چرا:** completion را از جست‌وجوی فرساینده به انتخاب هدف تبدیل می‌کند.
- **CLAWD:** `--verbose` فقط seamهای dead code نزدیک را outline کند.
- **لایه/هزینه:** casual / low، اگر highlight فعلی قابل‌استفاده است.

### P06 — Return Address / بازگشت با ability

- **چیست:** مکان به‌یادماندنی که بعداً با توانایی تازه قابل‌دسترسی می‌شود.
- **نمونه:** Super Metroid، دسترسی به محل X-Ray با ابزار traversal مناسب؛ خود scope secret-finding reward است. S17.
- **چرا:** حافظهٔ مکانی را پرداخت می‌کند؛ شرط باید قابل‌تشخیص باشد.
- **CLAWD:** لبهٔ `permission denied` با دو chevron؛ sudo مسیر fragment را باز می‌کند، نه code.
- **لایه/هزینه:** casual / low.

### P07 — NPC Demonstration / rule با اجرای موجود

- **چیست:** به‌جای instruction، NPC action قابل‌تقلید انجام می‌دهد.
- **نمونه:** Etecoons در Super Metroid، Wall Jump را نشان می‌دهند. S18.
- **چرا:** مشاهده مستقیماً به آزمایش تبدیل می‌شود.
- **CLAWD:** moth از seam رد می‌شود؛ helper در آموزشِ ساده یک key recess را فعال می‌کند.
- **لایه/هزینه:** casual / medium.

### P08 — Missing Input Rule / دستور همیشه‌موجود

- **چیست:** action از ابتدا وجود دارد؛ فقط نحوهٔ استفاده پنهان است.
- **نمونه:** Tunic، Holy Cross برای codeهای جهت‌دار، نه یک item فیزیکی تازه. S06، S12.
- **چرا:** کشف، چندین محل قدیمی را ناگهان actionable می‌کند.
- **CLAWD:** روی terminalهای brace، چهار جهت را می‌توان از ابتدا Submit کرد؛ manual بعدها معنی را روشن می‌کند.
- **لایه/هزینه:** curious / medium.

### P09 — Spatial Code / کد در شکل محیط

- **چیست:** هندسهٔ پس‌زمینه، ترتیب input است.
- **نمونه:** Tunic، مسیرهای Holy Cross و Golden Path با قطعات خطی manual. S06؛ تحلیل مکمل در S12. S05 فقط معرفی رسمی talk دربارهٔ مدل secrets است، نه مستند راه‌حل.
- **چرا:** decoration به زبان تبدیل می‌شود؛ نه collectible جدید.
- **CLAWD:** کابل PCB از نقطهٔ بزرگ به terminal، `↑→↓←`؛ marker ابتدا/انتها ثابت.
- **لایه/هزینه:** curious / low پس از terminal.

### P10 — Manual Montage / manual چندبخشی

- **چیست:** صفحات به‌ظاهر مستقل، یک meta-puzzle می‌سازند.
- **نمونه:** Tunic، Golden Path از قطعات صفحات manual برای Mountain Door. S06؛ S12.
- **چرا:** جمع‌آوری به synthesis بدل می‌شود و افشا از قبل در جهان بوده است.
- **CLAWD:** شش man page هر کدام یک مسیر trace؛ شماره‌ها ترتیب اتصال را می‌دهند.
- **لایه/هزینه:** community / medium.

### P11 — Rosetta Fragment / کلید خواندن زبان

- **چیست:** مثال معلوم برای رمزگشایی نوشته‌های قدیمی.
- **نمونه:** Environmental Station Alpha، Eagle بخشی از cipher زبان alien را می‌دهد. S21.
- **چرا:** بازیکن می‌تواند ادامه را استنتاج کند، نه منتظر همهٔ حروف بماند.
- **CLAWD:** log دو زبانهٔ `OPEN = ◇□△○` برای alphabet کوچک چهارعلامتی؛ نه یک زبان کامل.
- **لایه/هزینه:** curious / medium.

### P12 — Decorative Alphabet / رمز در تزئینات

- **چیست:** shop sign و memorial هم زبان lore را حمل می‌کنند.
- **نمونه:** Hyper Light Drifter؛ community glyphهای shop و Monolith را decipher کرده است. S24.
- **چرا:** عمل خواندن خودش reward است؛ ترجمه لزوماً قفل مکانیکی نیست.
- **CLAWD:** commentهای maintenance با glyph؛ ترجمه نام agent فراموش‌شده را آشکار می‌کند.
- **لایه/هزینه:** community / medium.

### P13 — Rule Experiment / اتاقِ آزمایشِ قانون

- **چیست:** چند آزمایش کم‌خطر یک قانون را ثابت می‌کند.
- **نمونه:** Outer Wilds، Tower of Quantum Trials قانون Quantum Imaging را با puzzleهای پیاپی می‌آموزد. S38.
- **چرا:** جواب دربارهٔ عملکرد جهان است، قابل‌انتقال به مکان بعدی.
- **CLAWD:** cached object با snapshot داخلی ثابت می‌ماند؛ مثال ساده، سپس secret دورتر.
- **لایه/هزینه:** curious / high، چون mechanic تازه است؛ فعلاً defer.

### P14 — World as Interface / محیط به‌جای panel

- **چیست:** الگوی رابط در خود محیط قابل‌استفاده می‌شود.
- **نمونه:** The Witness، Environmental Puzzles از viewpoint مناسب بدون panel فعال می‌شوند. S36.
- **چرا:** محدودهٔ «چه چیز puzzle است؟» را بازتعریف می‌کند.
- **CLAWD:** cableهای background همان grammar terminal را دارند؛ بازیکن روی terminal مجاور sequence را وارد می‌کند، نه pixel دقیق را touch.
- **لایه/هزینه:** curious / low با reuse terminal.

### P15 — Start Reinterpreted / آغاز با معنی تازه

- **چیست:** اتاق آغاز پس از کسب دانش secret جدید دارد.
- **نمونه:** The Witness، alignment خورشید و gate آغاز می‌تواند alternate ending را باز کند. S37.
- **چرا:** «از ابتدا اینجا بود» را ملموس می‌کند.
- **CLAWD:** screen boot از ابتدا چهار pulse دارد؛ پس از فهم trace grammar، code یک archive است.
- **لایه/هزینه:** curious / low.

### P16 — Cross-Room Evidence / شاهدهای چنداتاقی

- **چیست:** محل جواب و محل rule متفاوت‌اند؛ journal فاصله را پشتیبانی می‌کند.
- **نمونه:** La-Mulana، tabletهای hints و برنامهٔ laptop برای ثبت آن‌ها؛ برخی hints به مراحل بعدی مربوط‌اند. S14.
- **چرا:** معنی از context می‌آید؛ هزینهٔ سفر و حافظه باید کنترل شود.
- **CLAWD:** دو git log دربارهٔ همان door؛ terminal archive کنار shortcut برگشت.
- **لایه/هزینه:** curious / medium.

### P17 — Symbolic Absence / چیزی که وجود ندارد

- **چیست:** پاسخ از تفاوت میان علائم و جهان است.
- **نمونه:** ESA، Sun/Moon/Star و hint «زیر symbol ناموجود صبر کن»؛ Moon جواب است. S21.
- **چرا:** یک استنتاج محدود و قابل‌توضیح، نه جست‌وجوی همهٔ نقاط.
- **CLAWD:** log `module missing` و سه badge؛ badge غایب در registry را انتخاب کن، نه ایستادن طولانی بی‌نشانه.
- **لایه/هزینه:** curious / low.

### P18 — Deliberate Wait / انتظارِ اعلام‌شده

- **چیست:** مکث کوتاه در جای خاص trigger است.
- **نمونه:** ESA، یکی از key hints می‌گوید روی بخش بالاتر کنار آب منتظر بمانید؛ wall ناپدید می‌شود. S21.
- **چرا:** تنها وقتی مدت/پیشرفت قابل‌فهم باشد، انتظار یک action معتبر است.
- **CLAWD:** روی cache pad بایست؛ progress bar سه‌مرحله‌ای `warming cache`، بدون clock واقعی.
- **لایه/هزینه:** curious / low.

### P19 — Sequence Transformation / rule قدیمی با تبدیل

- **چیست:** همان code با mirror/reverse دوباره استفاده می‌شود.
- **نمونه:** Celeste، Chapter 6 Crystal Heart از code رنگ/جهت Chapter 1 و transformations استفاده می‌کند. S28، S30.
- **چرا:** آزمون فهم است، نه افزودن cipher مستقل.
- **CLAWD:** stack terminal sequence آشنا را در ترتیب LIFO می‌خواهد؛ نمونهٔ حل‌شده در man page.
- **لایه/هزینه:** curious / low.

### P20 — Signal-to-Action / اتصال دو دستهٔ داده

- **چیست:** ترتیب signal و mapping action جدا ارائه می‌شوند.
- **نمونه:** Celeste، کامپیوترِ satellite ترتیب رنگ‌ها و birds جهت dashها را نشان می‌دهند. S28.
- **چرا:** هر بخش ساده است، ترکیب آن‌ها aha می‌سازد.
- **CLAWD:** هر LED علاوه بر رنگ shape دارد؛ log shape→direction، monitor ترتیب shapes.
- **لایه/هزینه:** curious / medium.

### P21 — Community Mosaic / موزاییک اشتراکی

- **چیست:** قطعات مختلف میان saveها پخش می‌شوند.
- **نمونه:** Animal Well، mural و ۵۰ قطعهٔ متفاوت؛ community تصویر را در روزهای آغاز عرضه ترکیب کرد. S03، S04.
- **چرا:** هر نفر contribution قابل‌دیدن دارد؛ اما جمعیت کم یک خطر واقعی است.
- **CLAWD:** شش کارت ASCII با شناسهٔ قطعه؛ هر save یک کارت نخست می‌گیرد، هر شش کارت از طریق observatory همان save هم قابل‌کشف‌اند.
- **لایه/هزینه:** community / high؛ فقط پس از تست جذب بازیکن.

### P22 — Cipher Social Hunt / رمزگشایی جمعی

- **چیست:** ruleهای مشترک، امکان تقسیم آزمایش و بحث می‌سازند.
- **نمونه:** Fez، anti-cubes و numeral/language puzzles؛ Phil Fish صریحاً بازی قابل‌گفت‌وگو در مدرسه/محل کار می‌خواست. S07.
- **چرا:** همه لازم نیست یک code را مستقل پیدا کنند؛ contribution دانش ارزشمند است.
- **CLAWD:** هر zone یک مثال از opcode grammar دارد؛ community جدول را می‌سازد؛ قواعد کامل در خود بازی موجودند.
- **لایه/هزینه:** community / medium.

### P23 — Designed Glitch / glitch نمایشی، نه bug واقعی

- **چیست:** secret ظاهر خارج‌شدن از قواعد جهان دارد، ولی authored و پایدار است.
- **نمونه:** Axiom Verge، glitchهای gameplay برای corrupt environment و hidden areas؛ secret areas نیز در حالت عادی variation دارند. S19–S20.
- **چرا:** theme و discovery یکی می‌شوند؛ تازگی به شکستن اعتماد فنی نیاز ندارد.
- **CLAWD:** اتاق `/dev/null` با shader ساده و layout ثابت؛ هیچ physics یا save واقعاً خراب نشود.
- **لایه/هزینه:** curious / medium.

### P24 — Systems Escalation / ژرفای سیستم

- **چیست:** collectible مخفی پیامدهای گسترده‌تر از pickup عادی دارد.
- **نمونه:** Noita، Orb of True Knowledge با spell unlock و در runهای بعد health؛ تعداد orbs روی قدرت boss اثر دارد. S25.
- **چرا:** کشف به سؤال بعدی وصل می‌شود؛ trade-off فقط با اطلاع‌رسانی منصفانه است.
- **CLAWD:** compile stampهای اختیاری در پایان یک `debug challenge` جدا را فعال کنند؛ boss اصلی را بی‌خبر سخت نکنند.
- **لایه/هزینه:** curious / medium.

### P25 — Archive Set / مجموعه با پرداخت روایی

- **چیست:** اشیای پراکنده در یک gallery معنی کل پیدا می‌کنند.
- **نمونه:** Hyper Light Drifter، ۱۶ Monolith و پاداش Ochre outfit و متن gallery. S23–S24.
- **چرا:** collection با تصویری از تاریخ جهان همراه است.
- **CLAWD:** شش crash report، chronology حادثهٔ شب و skin CRT.
- **لایه/هزینه:** curious / medium.

### P26 — Collection Changes Home / خانهٔ تغییرپذیر

- **چیست:** اثر جمع‌آوری در hub قابل‌دیدن است.
- **نمونه:** Hollow Knight، Grubs نجات‌یافته در Grubhome و rewards Grubfather. S15.
- **چرا:** reward فقط عدد inventory نیست؛ جهان واکنش نشان می‌دهد.
- **CLAWD:** agentهای نجات‌یافته در taskbar خوابگاه می‌سازند؛ هر یک یک رفتار کوتاه.
- **لایه/هزینه:** casual / medium.

### P27 — Emotional Trophy / جایزهٔ اجتماعی کوچک

- **چیست:** تلاش اختیاری، ending را تزئین می‌کند نه اینکه آن را معتبر کند.
- **نمونه:** Celeste، تعداد strawberries ظاهر pie و واکنش‌های epilogue را تغییر می‌دهد. S27.
- **چرا:** trophy بدون power creep؛ به‌شرط آنکه پایان پایه تحقیر نشود.
- **CLAWD:** screenshot نهایی picnic شبانه با tokenهای جمع‌شده و جمله‌های متفاوت agentها.
- **لایه/هزینه:** casual / medium.

### P28 — Secret Mastery Room / چالش بعد از کشف

- **چیست:** یافتن ورودی و اجرای traversal دو وظیفهٔ جدا هستند.
- **نمونه:** Celeste Farewell، Moon Berry با انحراف از مسیر انتهایی و jellyfish challenge. S29.
- **چرا:** mastery reward را از پیشرفت داستان جدا می‌کند؛ failure باید locally retry شود.
- **CLAWD:** اتاق `benchmark` با curl و dash؛ cosmetic flame فقط، checkpoint ورودی، assist مستقل.
- **لایه/هزینه:** curious / medium.

### P29 — Finish Then Reframe / پایان و دعوت دوباره

- **چیست:** پایان مشروع، سپس شاهدی که عمق دیگری را آشکار می‌کند.
- **نمونه:** Tunic بعد از ending اول گزینهٔ Retry و تعداد صفحات missing نشان می‌دهد؛ نیت سازنده «تنبیه بازیکن» نبوده است. S06.
- **چرا:** بازیکن حق دارد تمام کند یا ادامه دهد؛ naming مهم است.
- **CLAWD:** پس از credits یک log جدید `background jobs still running`؛ پایان «ناقص» یا «bad» نامیده نشود.
- **لایه/هزینه:** curious / low.

### P30 — Nested Question / راز درون راز

- **چیست:** room کشف‌شده پایان لایهٔ اول و آغاز لایهٔ بعد است.
- **نمونه:** Animal Well؛ مسیر عادی، egg hunt و rabbit mysteries برای مخاطبان متفاوت؛ Basso سه مخاطب را هم‌زمان طراحی می‌کند. S01، S03.
- **چرا:** یک فضای ساخته‌شده دوباره ارزش می‌یابد، بدون حذف reward نخست.
- **CLAWD:** backup room یک fragment روشن و log دارای trace پنهان دارد؛ trace جایزهٔ fragment را قفل نمی‌کند.
- **لایه/هزینه:** casual → curious → community / low برای seed، medium برای meta-payoff.

**یادداشت منابع کاتالوگ:** جزئیات Golden Path در بخش‌های P09–P10 به توضیح مصاحبهٔ S06 و تحلیل S12 متکی است؛ ادعاهای دقیق‌تر مانند طول code یا تعداد input در این گزارش مبنای طراحی نیستند. نمونهٔ fixed-clock و رمز vibration پلتفرم‌خاص Fez عمداً پیشنهاد نشده‌اند، چون porting به phone دشوار و برای این پروژه کم‌ارزش است.

## ۴. Layered secret plan — شواهد تطبیقی و طرح سه‌لایه

### ۴.۱. شش مطالعهٔ اصلی: شباهت‌ها را با تفاوت‌ها اشتباه نگیرید

**Animal Well — لایه‌های مخاطب.** Basso در مصاحبهٔ پیش از عرضه صریحاً از طراحی برای سه مخاطب می‌گوید: بازی پایه، secrets برای completion و mysteries برای همکاری. گزارش عرضه، چهار flame/credits، egg hunt و rabbit hunt را تفکیک می‌کند. کاربردی‌ترین تکنیک برای CLAWD «تفسیر دومِ همان object» است: یک item ابتدا بازیچهٔ خوش‌دست، بعد ابزار puzzle پیچیده‌تر. او در مصاحبهٔ PAX توضیح می‌دهد که ابتدا fun و playfulness را می‌سازد، سپس کاربردهای دشوارتر را جست‌وجو می‌کند. پس لایهٔ سوم نباید layer 1 را به آزمایشگاهی ناخوانا تبدیل کند.[[1]](https://thinkygames.com/features/interview-how-animal-well-is-using-secrets-and-mysteries-to-be-a-different-kind-of-metroidvania/)[[2]](https://www.videogamesgood.com/post/billy-basso-beautiful-pixel-platformer-animal-well-pax-west-2023-hands-on-interview)[[3]](https://www.ign.com/articles/animal-well-contains-a-hidden-puzzle-that-requires-at-least-50-people-to-complete)

**Tunic — لایه‌های تفسیر.** manual هم کمک کاربردی است هم سطح نگهداری secret؛ Holy Cross مفهوم item را به input rule بازتفسیر می‌کند؛ Golden Path صفحات پراکنده را به یک کل تبدیل می‌کند. talk رسمی Shouldice مدل loose ends و ارزش «رازهای کمی زیر سطح» را معرفی می‌کند. نکتهٔ تولیدی مهم در مصاحبهٔ S06: او secrets را برای QA و marketing در یک presentation داخلی آشکار کرد. تیم ساخت نباید برای حفظ mystery از مستندسازی جواب‌ها خودداری کند. برای CLAWD، man pages و یک solution manifest خصوصیِ تیم چنین نقشی دارند.[[4]](https://gdcvault.com/play/1029384/-TUNIC-This-Was-Here)[[5]](https://www.vice.com/en/article/the-delicate-balancing-act-of-making-a-video-game-built-on-secrets/)

**Fez — آستانه‌های تعهد.** Phil Fish می‌گوید normal cubes باید reasonably easy باشند و رسیدن به ending نیازمند یادگیری numeral system ساختگی نیست؛ anti-cubes حوزهٔ سخت‌ترند و community می‌تواند همکاری کند. این جداسازی برای CLAWD مناسب است، اما «anything was fair game» را نباید قرارداد انصاف پروژه گرفت. دربارهٔ monolith، او brute force جمعی را جالب‌تر از راه‌حل مدنظرش می‌داند؛ Jesper Juul، در نقدی مستقل، تأخیر زیاد میان فرضیه و آزمون به‌علت سفر و تکرار را خسته‌کننده می‌داند. اختلاف واقعی: ارزش اجتماعیِ حل جمعی در برابر هزینهٔ آزمون فردی. پیشنهاد CLAWD: community synthesis، با terminal نزدیک و restart کوتاه؛ نه فضای جواب عظیم و آزمون بی‌feedback.[[6]](https://www.eurogamer.net/fez-at-10-years-old-phil-fish-resurfaces-for-a-rare-interview)[[7]](https://www.jesperjuul.net/ludologist/2012/04/21/the-impossible-fez-puzzle/)

**La-Mulana — شبکهٔ قرائن، نه الزاماً سه سطح آسان/سخت.** tablet، mural، item و مکان با فاصلهٔ زیاد به هم معنی می‌دهند؛ برخی hints دیرتر مفید می‌شوند و laptop امکان ثبت دارد. در blog رسمی ۲۰۰۹، NIGORO از اصلاح lack of guidance، کنترل و بخش‌های «بیشتر trouble تا fun» صحبت می‌کند. نظرات همان صفحه دربارهٔ منصفانه‌بودن puzzleها اختلاف جدی دارند؛ این comments را نباید نظر developer نامید. برای CLAWD، نقش archaeological inference را با crash log و git history بگیرید؛ obscure mandatory bottleneck و mnemonic burden را نگیرید.[[8]](https://gamecritics.com/tayo-stalnaker/la-mulana-review/)[[9]](https://la-mulana.com/en/blog/about_difficulty.html)

**Outer Wilds — عمق اطلاعات، نه grind و community gate.** Kelsey Beachum در اسلایدهای GDC سه نوع محتوا را تعریف می‌کند: surface برای ایجاد سؤال، mid-level برای پیش‌برد thread، hidden برای پاسخ‌های بزرگ که عموماً نیازمند پیروی از clues هستند. دانش هم reward است هم progression. ثبت دانسته‌ها نباید خودش چالش اصلی باشد؛ ship log فقط facts خوانده‌شده را ثبت می‌کند، نه استنتاج بازیکن را. Alex Beachum در مصاحبهٔ S11 می‌گوید دنبال‌کردن سؤال‌ها مطلوب است، نه پاک‌سازی سیاره‌ها یکی‌یکی. انتقال: journal CLAWD بر اساس «چرا این port بسته است؟» و «چه کسی backup را حذف کرد؟»، نه صرفاً فهرست collectible هر zone.[[10]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)[[11]](https://medium.com/@cordialkobold/interview-with-alex-beachum-creative-director-of-outer-wilds-a01bb9631e20)

**The Witness — تغییر دامنهٔ دیدن.** panelها grammar اولیه را می‌سازند؛ Environmental Puzzles همان grammar را در island، خارج از panel آشکار می‌کنند؛ gate آغاز هم دوباره تفسیر می‌شود. Blow در مصاحبهٔ Paris Review روی گذار «نفهمیدن → فهمیدن» و wonder تأکید می‌کند، نه صرفاً «باهوش حس کردن». این بازی را با Outer Wilds یکی نکنید: logهای شخصیت‌محور در یکی ابزار اصلی curiosity هستند، اما Blow توضیح می‌دهد human drama در طرح The Witness می‌توانست توجه را از contemplation منحرف کند. CLAWD باید انتخاب کند: lore کوتاه دربارهٔ agentها + rule عملی، نه novel کنار هر switch.[[12]](https://www.theparisreview.org/blog/2016/01/07/ready-player-none/)[[13]](https://www.ign.com/wikis/the-witness/Environmental_Puzzles)[[14]](https://thewitness.fandom.com/wiki/Easter_Eggs)

### ۴.۲. نه مرجع تکمیلی و برداشت محدود

| بازی | شاهد مشخص | برداشت اجرایی برای CLAWD | چیزی که کپی نشود |
| --- | --- | --- | --- |
| Hollow Knight | Grub cry، نجات، hub reward، Collector’s Map برای یافتن باقی‌مانده‌ها؛ S15 | reward عاطفی + نشانگر completion دیرهنگام | audio-only clue و پاداشی که نفر دوم نتواند ببیند |
| Super Metroid | Etecoons برای Wall Jump؛ X-Ray برای passages؛ S17–S18 | demonstration و ابزار cleanup دو نقش جدا دارند | انتظار تشخیص یک pixel یا action ناشناختهٔ سخت روی touch |
| Axiom Verge | glitch به‌عنوان mechanic؛ secret areas متغیر در بازی عادی؛ S19–S20 | glitch authored برای theme؛ seed مشترک اگر variation دارید | random entrances پیش از اثبات زبان clue ثابت |
| Environmental Station Alpha | Eagle cipher، terminals/four pillars و post-postgame؛ S21 | بازی پس از پایان می‌تواند از traversal به inference تغییر کند | رمز با سفر زیاد یا شرط پنهانِ بدون feedback |
| Hyper Light Drifter | Monolith set، glyph decipher و outfit؛ S23–S24 | lore مجموعه‌ای + cosmetic + gallery | مجبورکردن بازیکن به ترجمهٔ متن ریز برای اتمام اصلی |
| Noita | orbs با اثر سیستمی؛ Eye Messages در wiki هنوز unresolved گزارش شده‌اند؛ S25–S26 | عمق اختیاری و آزمایش systemic | ادعای «هر نشانه حتماً راه‌حل دارد» یا تنبیه بی‌خبرِ collectible |
| Celeste | strawberries/pie، Crystal Hearts، Moon Berry؛ S27–S29 | سه قرارداد متفاوت: exploration، inference، mastery | قراردادن HP ضروری پشت challenge هم‌سطح Moon Berry |
| Haiku the Robot | false ceiling، chip و scraps در hidden spots؛ S31 | benchmark نزدیک برای secret room سادهٔ تیم کوچک | پرکردن همهٔ detourهای دیرهنگام با scrap کم‌ارزش |
| Shovel Knight | branch direction، breakable wall، پایان خوانای room؛ S32 | مسیر اختیاری از main route تمیز باشد | کپی قانون «left همیشه secret» در جهان چهارسویهٔ CLAWD |

این بازی‌ها عمدتاً single-player هستند. پیشنهادهای networked co-op پایین، استنتاج طراحی برای CLAWD است، نه ادعای وجود co-op همسان در این مراجع.

### ۴.۳. بودجهٔ فضای فیزیکی

پیشنهاد اولیه برای حدود ۳۰ اتاق موجود: **۱۸ casual + ۱۰ curious + ۲ meta-payoff**. لایهٔ community بیش از دو اتاق reward تازه نمی‌خواهد؛ شواهدش overlay روی اتاق‌های قبلی، man pages و hub است. شش مثال هر لایه در ادامه، نمونه‌اند نه الزام به افزودن ۱۸ اتاق تازه. تعداد دقیق پس از inventory اتاق‌های فعلی اصلاح شود.

قواعد dependencies:

- graph توانایی‌ها از graph دانش جدا باشد؛ `requires curl` با `knows trace grammar` یک edge نیست.
- layer 1 reward همیشه با یافتن room پرداخت شود؛ خواندن trace لایهٔ دوم شرط fragment اول نباشد.
- log در journal بر اساس مشاهده ثبت شود؛ اما اجرای جواب به `clue_collected` وابسته نباشد.
- تا پیش از credits لازم نیست شمار secrets جامعه در UI ظاهر شود؛ پایان عادی کامل و معتبر است.
- هر meta-chain یک payoff مشخص داشته باشد؛ وعدهٔ «بازی بی‌نهایت راز دارد» ندهید.

### ۴.۴. لایهٔ casual — شش نمونهٔ روشن

| نمونه | سرنخ و عمل | reward | شرط و هزینه |
| --- | --- | --- | --- |
| C1 `/unused` | moth وارد seam؛ trail از پشت دیوار؛ walk | fragment + log کوتاه bug | بدون ability؛ low |
| C2 `compile rubble` | crack مستقل از moth؛ dash از کف امن | plugin قابل‌آزمایش روی dummy همان room | dash؛ low |
| C3 `lost worker` | beep همراه bubble؛ helper key در recess | agent به hub برمی‌گردد + fragment | helper؛ medium |
| C4 `privileged shelf` | دو chevron و fragment قابل‌دیدن؛ sudo | fragment؛ سپس hatch خروج مستقیم | double jump؛ low |
| C5 `download hook` | curl ring بالای مسیر امن؛ reward پشت glass | plugin utility، نه damage اجباری | grapple؛ low |
| C6 `thin tunnel` | pattern ثابت firewall؛ ssh و بازکردن latch برگشت | shortcut بین دو مسیر + comment خنده‌دار | phase؛ low |

برای catch و --force نیز variation همین prefabها ساخته شود: catch room با emitter آهسته و safe ledge؛ force room با کف chevron، سکوی فرود قابل‌دیدن و ladder بازگشت. secret اجرای قدرت را تمرین می‌دهد، نه اینکه کشف را به fine motor test پنهان تبدیل کند.

### ۴.۵. لایهٔ curious — شش نمونهٔ بازتفسیر

| نمونه | دانش و ورودی | reward | هزینه |
| --- | --- | --- | --- |
| Q1 `boot trace` | pulseهای boot با mapping شکل→جهت؛ code روی terminal | access به archive کوتاه + skin cursor | low بعد از terminal |
| Q2 `robots backup` | sign قدیمی `Disallow: /backup`  • man روشن دربارهٔ path | اتاق backup و fragment مستقل | low |
| Q3 `git recovery` | log آخرین revision باز را مشخص می‌کند؛ انتخاب b02 | plugin `autosave` با اثر QoL محدود | medium |
| Q4 `stack echo` | sequence آشنا، این‌بار pop/LIFO | cache room و fragment | low |
| Q5 `port handshake` | table داخل game، ACK sequence بدون deadline | shortcut server corridor | medium |
| Q6 `revert residual` | before/after دو حالت؛ چیزی که تغییر نکرده جواب است | lore دربارهٔ agent حذف‌شده، سپس collectible کوچک | medium؛ کنار revert device، نه global undo |

Q6 می‌تواند hybrid باشد: برای دسترسی ability لازم، برای حل inference. آن را knowledge-only در metrics ثبت نکنید. نمونه‌های بخش ۵، در مقابل، تماماً با terminal پایه قابل‌حل‌اند.

### ۴.۶. لایهٔ community — شش کشف، دو فضای پرداخت

1. **M1 — Boot Atlas:** شش man page در شش zone، trace کوتاه دارند؛ `INDEX` داخل hub ترتیب را می‌دهد. اتصال، یک code کوتاه برای observatory است. reward: اتاق اول، روایت علت خاموش‌نشدن computer. هزینه medium؛ هیچ page-token prerequisite برای Submit نیست.
2. **M2 — ASCII Quilt:** کارت‌های شش‌گانه با coordinate و orientation؛ community می‌تواند screenshotها را کنار هم بگذارد. همان save هر شش را هم می‌دهد تا جمعیت کم قفل نشود. reward: mural کامل در observatory و skin. هزینه high؛ optional stretch.
3. **M3 — Deleted Comment:** git diffs سه log تکه‌تکهٔ comment قدیمی را بازسازی می‌کنند؛ متن حاصل path یک audit panel است. reward: دیدن credit/dedication تیم، نه password واقعی. هزینه low بعد از log UI.
4. **M4 — Opcode Rosetta:** چهار shape در shop signs، logs و man pages همان alphabet محدود را دارند؛ جدول جامعه نتیجه را سریع‌تر روشن می‌کند. reward: خواندن inscription نهایی. هزینه medium؛ code parser همان قبلی.
5. **M5 — Two Traces, One Route:** یک monitor ترتیب اصلی و دیگری annotation معکوس را نشان می‌دهد؛ دو بازیکن می‌توانند اطلاعات را تقسیم کنند، solo هر دو را journal می‌کند. ترکیب به آخرین archive door می‌رسد. هزینه medium؛ cross-room streaming لازم نیست.
6. **M6 — Night Audit:** پس از M1 و با استفاده از دانش M3/M4، checksum کوتاه archive دوم پیدا می‌شود. reward: اتاق دوم، cosmetic `Night Maintainer` و پاسخ مشخص به سرنوشت agent. dependency در narrative است؛ کسی که code را می‌داند می‌تواند زودتر وارد شود. هزینه medium.

**کنترل دامنه:** M1/M3/M4/M5/M6 از زیرساخت موجود استفاده می‌کنند؛ M2 قابل‌حذف است. هیچ لایه‌ای به تغییر فایل save، executable، server پاسخ‌گو یا رویداد تاریخ‌دار وابسته نیست. نسخهٔ اولیه با یک meta-chain خوب بهتر از شش meta-chain نصفه است.

## ۵. Knowledge-based ideas — دوازده راز با حل کامل داخل بازی

### قرارداد مشترک

یک **terminal پایه** از ابتدای بازی موجود باشد؛ commands جهان بازی از palette همیشه‌در‌دسترس انتخاب شوند، نه اینکه بعد از یافتن man page unlock شوند. editor code با directions، رقم‌ها، Submit، Backspace و Clear کار کند؛ keyboard PC فقط shortcut همان UI باشد. terminal یک interpreter واقعی shell نیست. هر پیشنهاد زیر source clue، inference و solution مشخص دارد؛ جواب ذخیره‌شده فقط open flag می‌سازد، نه inventory key. نسخه‌های پایین نمونهٔ authored با جواب معلوم‌اند، نه codeهای نهایی اجباری پروژه.

### K01 — `ls -a` / فایلِ پنهان

- **داخل game:** man page نشان می‌دهد `ls` فایل‌های بدون dot و `ls -a` همه را نمایش می‌دهد؛ نمونهٔ `.note` روشن است. terminal backup فقط `cache` و `log` را فهرست کرده است.
- **استنتاج و جواب:** انتخاب `ls` + flag `-a`، `.door` را آشکار می‌کند؛ انتخاب `open .door` مسیر را باز می‌کند.
- **feedback:** list قبل/بعد کنار هم؛ spell-check لازم نیست.
- **reward / لایه / هزینه:** fragment و روایت کوتاه؛ curious؛ low بعد از palette.

### K02 — HTTP Errors / نوعِ خطا، نه عددِ حفظ‌شده

- **داخل game:** poster سه معنی را می‌دهد: `403 = forbidden`, `404 = not found`, `410 = gone`. log می‌گوید backup «هنوز وجود دارد اما اجازهٔ عادی ندارد».
- **استنتاج و جواب:** روی سه badge، `403` را انتخاب کن؛ سپس route «archive permission» باز می‌شود. هیچ شماره‌ٔ بیرونی لازم نیست.
- **feedback:** انتخاب 404، panel می‌گوید «log وجود resource را تأیید کرده»؛ پاسخ را در اولین خطا نمی‌دهد.
- **reward / لایه / هزینه:** archive room؛ curious؛ low. این یک قفل نمادین است، نه تلاش عبور از HTTP authorization واقعی.

### K03 — Git History / آخرین revision سالم

- **داخل game:** سه log با parent واضح: `b01: door closed`; `b02 parent b01: door opened`; `b03 parent b02: door sealed`. man می‌گوید «recover آخرین state باز، نه قدیمی‌ترین state».
- **استنتاج و جواب:** در archive simulator، `checkout b02`؛ نه b01 و نه b03. این commandِ puzzle مستقل از ability `revert` است.
- **feedback:** preview وضعیت هر revision؛ history پاک نمی‌شود.
- **reward / لایه / هزینه:** shortcut + log چرایی seal؛ curious؛ medium.

### K04 — Network Port / انتخاب سرویس

- **داخل game:** table در server room: `22 ssh`, `80 http`, `443 https`; note: «archive روی HTTPS است». هیچ دانستن port واقعی پیش‌نیاز نیست.
- **استنتاج و جواب:** dial سه‌گزینه‌ای روی 443، سپس `connect archive`.
- **feedback:** portهای دیگر banner مربوط به همان سرویس می‌دهند؛ نه death یا timeout طولانی.
- **reward / لایه / هزینه:** archive و cosmetic terminal؛ curious؛ low.

### K05 — Hex Address / آدرس دوبخشی

- **داخل game:** memory map کوچک با row/column labelهای hex؛ legend: «nibble اول=row، دوم=column؛ هر دو از 0». address log: `0x2B`؛ جدول B=11 و مثال حل‌شده `0x13 → row1,col3` حاضر است.
- **استنتاج و جواب:** در selector، row=2 و column=B؛ نیاز به شمردن کاشی ریز یا حفظ تبدیل نیست.
- **feedback:** address انتخاب‌شده بزرگ نمایش داده می‌شود؛ Confirm جدا.
- **reward / لایه / هزینه:** cache entry و fragment؛ curious؛ medium برای UI، low برای variation.

### K06 — `robots.txt` / ردّ مسیر

- **داخل game:** sign `Disallow: /backup`; man می‌گوید «crawler به این path نمی‌رود، ولی path از این متن معلوم می‌شود؛ این access control نیست». terminal همیشه command `open` و path selector دارد.
- **استنتاج و جواب:** `open /backup`، یا یافتن ورودی همان path روی نقشه؛ sign مکان وجودی را لو می‌دهد، نه password.
- **feedback:** directory preview و صدای کشف، نه پیام «security breached».
- **reward / لایه / هزینه:** room شامل fragment فوری و trace برای لایهٔ بعد؛ curious؛ low.

### K07 — Stack / ترتیبِ pop

- **داخل game:** man با مثال دوشیئی ثابت می‌کند آخرین push اولین pop است. log: `push ↑; push →; push ↓`.
- **استنتاج و جواب:** در trace terminal، `↓ → ↑` سپس Submit. arrows لازم نیست به حرکت شخصیت تبدیل شوند.
- **feedback:** سه slot input دیده می‌شوند؛ failure stack را reset می‌کند، clue را نه.
- **reward / لایه / هزینه:** cache shortcut؛ curious؛ low.

### K08 — XOR / bitهای متفاوت

- **داخل game:** truth table کامل دو bit و مثال موجود؛ دو چهارbit روی monitors: `1010` و `0110`.
- **استنتاج و جواب:** `1100` را روی چهار toggle وارد کن. متن man: «equal→0, different→1».
- **feedback:** عدد و شکل toggle هم‌زمان؛ رنگ تنها حامل 0/1 نیست.
- **reward / لایه / هزینه:** checksum stamp و lore؛ curious؛ low.

### K09 — Log Replay / ترتیبِ sequence

- **داخل game:** سه crash log از یک door با شمارهٔ sequence: `#12 →`, `#10 ↑`, `#11 ←`. manual می‌گوید journal ترتیب پیدا کردن است؛ replay براساس sequence صعودی است.
- **استنتاج و جواب:** `↑ ← →`؛ sorting از داده، نه از مسیر traversal بازیکن.
- **feedback:** journal امکان sort-by-sequence دارد ولی code را خودکار Submit نمی‌کند.
- **reward / لایه / هزینه:** replay واقعهٔ کوچک؛ curious؛ low.

### K10 — Diff / چیزِ تغییرکرده

- **داخل game:** before: `path=/cache`, after: `path=/archive`; بقیهٔ خطوط یکسان. مثال man فقط خط تغییرکرده را به route وصل می‌کند.
- **استنتاج و جواب:** `open /archive`؛ هیچ item یا ability لازم نیست. باقی‌ماندن syntax قدیمی موضوع puzzle نیست.
- **feedback:** lines اضافه/حذف با `+` و `-` علاوه بر رنگ؛ full-text readable mode.
- **reward / لایه / هزینه:** lore room و plugin utility؛ curious؛ low بعد از log viewer.

### K11 — `man` Cross-reference / رجوع دقیق

- **داخل game:** page A می‌گوید «mode restore در section 3 توضیح داده شده»؛ section 3 مثال `restore --keep-log` دارد و توضیح می‌دهد حذف log ممنوع است. terminal سه flagِ `--keep-log`, `--clear`, `--silent` دارد.
- **استنتاج و جواب:** `restore --keep-log`؛ هدف بازی restoration همراه حفظ سند است، نه صرفاً بازکردن در.
- **feedback:** previewِ پیامد هر flag؛ flag غلط commit نمی‌شود مگر تأیید، و puzzle همیشه resettable است.
- **reward / لایه / هزینه:** journal page و اتاق archive؛ curious؛ low.

### K12 — Multi-page Checksum / synthesis جامعه

- **داخل game:** سه log بایت‌های `10101010`, `01100110`, `00111100` را دارند؛ index قاعدهٔ XOR و نام audit endpoint را تعریف می‌کند. مثال دوbitِ حل‌شده در همان man page حاضر است. دو محل مستقل نام `audit` را با همین سه slot مرتبط می‌کنند.
- **استنتاج و جواب:** `10101010 XOR 01100110 XOR 00111100 = 11110000`؛ انتخاب `audit` و input `11110000` در دو گروه چهارbit. ارزش puzzle وصل‌کردن اسناد به endpoint درست است، نه جلوگیری کامل از brute force. حدس موفق یا جوابِ به‌اشتراک‌گذاشته‌شده باید پذیرفته شود؛ بازی فقط provenance را پس از حل روشن می‌کند.
- **feedback:** پس از جواب، provenance سه log و animation join نمایش داده می‌شود؛ جواب دانسته‌شده بدون جمع‌کردن logها هم پذیرفته می‌شود.
- **reward / لایه / هزینه:** meta-archive و cosmetic؛ community؛ medium.

**اولویت اجرا:** K01/K06 یک خانواده‌اند و لازم نیست هر دو در نسخهٔ نخست باشند. برای تنوع، K07، K03 و K10 را انتخاب کنید؛ سپس K04/K05. K08/K12 را فقط اگر rule روی phone خوانا و thematic باشد اضافه کنید. دوازده ایده، دوازده parser مستقل نیستند.

**آزمون knowledge gate:** tester در fresh save، بدون خواندن هیچ clue، با جواب صحیح باید secret را باز کند. tester بدون تجربهٔ programming، فقط با اطلاعات داخلی باید بتواند جواب را توضیح دهد. اگر اولی fail شد، gate واقعاً knowledge-only نیست؛ اگر دومی fail شد، prerequisite بیرونی پنهان دارید.

## ۶. Rewards — پاداش متناسب با قرارداد secret

Outer Wilds نمونه‌ای است که knowledge تنها gameplay reward آن است؛ Kelsey Beachum صریحاً می‌گوید این انتخاب برای همهٔ تیپ‌های بازیکن جذاب نیست. بنابراین نمی‌توان نتیجه گرفت «lore همیشه کافی است». Celeste هم strawberries، hearts و Moon Berry را تحت یک قرارداد واحد نمی‌گذارد؛ Hollow Knight reward نجات Grubs را با hub و progression قابل‌دیدن پیوند می‌دهد. CLAWD یک action metroidvania است: knowledge reward را به rewardهای ملموس کوچک پیوند بدهید، بدون اجبار همه به meta-puzzles.[[10]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)[[15]](https://celeste.ink/wiki/Epilogue)[[16]](https://celestegame.fandom.com/wiki/Crystal_Heart_Guide)[[17]](https://celeste.ink/wiki/Farewell/Moon_Berry)[[18]](https://hollowknight.wiki/w/Grub)

| نوع تلاش | پرداخت اصلی پیشنهادی | پرداخت دوم | چیزی که ندهید |
| --- | --- | --- | --- |
| dead code ساده | memory fragment | یک جملهٔ lore یا joke | فقط currency بسیار کم، خصوصاً اواخر بازی |
| ability detour کوتاه | fragment یا plugin sidegrade | preview مصرف plugin همان‌جا | ability ضروری داستان |
| shortcut کشف‌شده | زمان سفر کمتر و درِ دائمی | map link قابل‌دیدن برای هر دو | shortcut یک‌طرفه به softlock |
| code دانش‌محور محلی | rule جدید یا archive معنی‌دار | cosmetic یا fragment | صفحه‌ای که هیچ کاربرد/پاسخ ندارد |
| نجات agent | تغییر hub و رفتار شخصیت | fragment/plugin utility | فقط عدد rescued بدون اثر قابل‌دیدن |
| mastery room | badge/skin/animation victory | بهترین زمان شخصی اختیاری | HP ضروری یا plugin overwhelmingly best |
| meta-chain community | پاسخ روشن یک mystery + cosmetic متمایز | gallery/credit/room قابل‌عکس | ending عادی را بی‌ارزش‌کردن |
| joke بسیار کوتاه | punchline مرتبط | token کوچک | troll reward پس از یک ساعت رمزگشایی |

**Memory fragments:** چهار تا = +۱ max HP، طبق سیستم موجود. HUD باید progress `1/4 … 4/4` را فوراً نشان دهد؛ هر fragment می‌تواند snippet شخصیتی منحصربه‌فرد داشته باشد تا pickup منفرد هم معنا داشته باشد. difficulty پایه بدون secrets تست شود؛ HP مخفی easing اختیاری باشد، نه راه جبران boss عمداً نامتوازن. layer 3 HP نداشته باشد تا انگیزهٔ completion به اجبار ARG بدل نشود.

**Plugins:** به‌جای افزایش عدد صرف، گزینهٔ متفاوت بدهید؛ مانند نشان‌دادن ringهای curl خارج از combat، حفظ annotation نقشه، یا preview مسیر projectile در training. قبل از equip توضیح و فضای تست داشته باشند؛ مشکل کنترل phone را با plugin اجباری حل نکنید. `--verbose` مهم‌ترین counter-frustration reward فعلی است؛ آن را پشت سخت‌ترین secret wall نگذارید.

**Lore:** هر log باید یکی از سه کار را انجام دهد: سؤال را پاسخ دهد، رابطهٔ قابل‌استفاده بسازد، یا شخصیت را مشخص‌تر کند. log «سیستم قدیمی و اسرارآمیز بود» پرداخت نیست. نمونهٔ خوب: «b03 را بستم چون worker هنوز در backup بود»؛ هم داستان دارد هم reason برای history puzzle.

**ناامیدی قابل‌پیشگیری:** reward چندین‌بار یکسان پس از effort متفاوت؛ plugin بی‌فایده در زمان دریافت؛ clue جدید بدون هیچ پاسخ به سؤال قبلی؛ collectible که boss را بی‌خبر قوی‌تر می‌کند؛ secret که نتیجه‌اش فقط بازشدن achievement بیرون بازی است. Noita اثر تعداد Orb بر boss را نشان می‌دهد، اما این trade-off را برای CLAWD نباید بی‌اعلان کپی کرد. S25.

## ۷. Co-op و phone — قرارداد محصول، نه حاشیهٔ طراحی

### ۷.۱. secrets برای دو نفر، با fallback مشخص

| ایده | نقش بازیکن اول | نقش بازیکن دوم | fallback solo | پرداخت/هزینه |
| --- | --- | --- | --- | --- |
| read–enter trace | monitor و shapes را می‌خواند | code را روی terminal وارد می‌کند | journal snapshot همان monitor | حل سریع‌تر و گفت‌وگو؛ low |
| two-phase commit | switch A را arm می‌کند، روشن می‌ماند | switch B را arm می‌کند؛ سپس هر نفر Confirm | latchها persistent تا reset؛ هر دو را solo فعال کن | vault اختیاری؛ medium |
| catch relay | projectile را از safe ledge بازمی‌تاباند | helper key یا gate latch را فعال می‌کند | latch اول؛ سپس catch همان نفر | animation همکاری؛ medium |
| breakpoint bridge | جسم annotated را freeze می‌کند | مسیر را تست و return hatch را باز می‌کند | panel toggle یا helperِ در‌دسترس، بدون expiry هنگام مطالعه | shortcut؛ medium |
| before/after diff | نسخهٔ before را می‌بیند | after را می‌خواند و تفاوت را گزارش می‌کند | view toggle هر دو سند با labels ثابت | archive؛ low |
| co-authored mural | قطعهٔ اول را annotate می‌کند | قطعهٔ دوم را align می‌کند | همان editor single-player | cosmetic مشترک؛ medium، با M2 high |

**نیاز دو نفر:** اگر واقعاً room ویژهٔ دو نفر می‌خواهید، فقط یک bonus social room با cosmetic مشترک؛ UI پیش از ورودی `co-op bonus` بگوید. هیچ fragment، plugin کلیدی، main-map completion یا story ending به این اتاق وابسته نباشد. گزینهٔ بهتر برای تیم کوچک: همهٔ secrets دو نفر را reward کنند، ولی hard requirement نداشته باشند؛ helper فعلی برای latchها کافی است. نگویید «solo fallback» اگر helper خودش پشت secret co-op قفل است.

**تقسیم اطلاعات، نه تقسیم device capability:** PC نباید plaintext بخواند و Android مجبور به شنیدن کد باشد؛ هر دو inputها و readability یکسان داشته باشند. roleها قابل‌تعویض باشند. secret مبتنی بر vibration، Ctrl chord، mouse hover یا نگه‌داشتن پنج touch هم‌زمان ممنوع.

### ۷.۲. دو نفر جدا از هم: discovery state

سه state را مستقل نگه دارید:

- **world state مشترک:** در باز است، latch فعال است، reward یک‌بار claim شده است.
- **profile state:** حق reward، equip plugin و progress fragment هر نفر؛ هر دو به پاداش دسترسی داشته باشند و race اولین pickup مزیت ندهد.
- **knowledge/seen state شخصی:** این بازیکن log را دیده یا hint گرفته؛ بازی نمی‌تواند ادعا کند او واقعاً rule را فهمیده است.

وقتی A کشف می‌کند و B دور است: B پیام غیرspoiler «یک مسیر تازه پیدا شد» و یک pin اختیاری می‌گیرد، نه پاسخ code. interaction «نمایش کشف دوست» با انتخاب خود B متن را باز می‌کند. room باز می‌ماند، loot pedestal برای B نمایش owned/unseen دارد؛ log و clue خواندنی باقی می‌مانند. اگر B می‌خواهد خودش solve کند، `practice replay` محلیِ terminal بدون تغییر world state ارائه شود. این جایگزین ساخت دو نسخهٔ کامل جهان است.

**دیگر اتاق‌ها را هم‌زمان stream نکنید فقط برای رازها.** اگر architecture موجود اجازهٔ حضور جداگانه دارد، eventهای `room_id` و `secret_id` کافی‌اند؛ اگر ندارد، این تحقیق مجوز افزودن simulation چنداتاقی پرهزینه نیست. discovery در زمان‌های جدا و journal sharing همان حس مشارکت را با هزینه کمتر می‌دهد.

### ۷.۳. شبکه: latency به‌جای puzzle تصمیم نگیرد

- host/serverِ authority، open/claim/reward را commit کند؛ requestهای تکراری با `secret_id + reward_id` دوباره پرداخت نشوند.
- client برای input UI پاسخ محلی فوری بدهد، ولی accept نهایی با revision معتبر بیاید؛ دو Submit هم‌زمان فقط یک open transition ایجاد کنند.
- latchها بعد از فعال‌سازی روشن بمانند؛ پنجرهٔ هم‌زمانی frame-perfect وجود نداشته باشد. countdown، اگر ضروری است، روی authority و با marginِ تست‌شده باشد، نه زمان دریافت packet در هر phone.
- `breakpoint` یک دستگاه مشخص را freeze کند؛ player دیگر و network tick را متوقف نکند. `revert` state همان دستگاه را undo کند؛ reward ledger، partner position و memory fragment را rewind نکند.
- late join snapshot آخرین world state و entitlement را دریافت کند؛ client جدید scene اولیهٔ door بسته را canonical نگیرد.
- disconnect نفر دوم gate را روی نفر اول قفل نکند؛ puzzle cooperative باز به fallback latch تبدیل شود و حل انجام‌شده باقی بماند.

Godot web low-level networking دلخواه desktop را پشتیبانی نمی‌کند؛ docs نسخهٔ 4.3 HTTP client/request، WebSocket client و WebRTC را ذکر می‌کند. طراحی فوق transport-agnostic است و نیازی به ادعای ENet مستقیم در browser ندارد. نسخهٔ دقیق engine پروژه مشخص نشده؛ پیش از انتخاب transport و audio feature، docs همان minor version بررسی شود.[[19]](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_web.html)

### ۷.۴. خوانایی 384×216 و touch

**هندسه:** عرض 384 با tile16 دقیقاً ۲۴ tile است، ولی ارتفاع 216 برابر ۱۳٫۵ tile است. قبل از گذاشتن clue بالای/پایین screen مشخص کنید world grid ۲۴×۱۳ با margin است یا viewport بخشی از tile چهاردهم را نشان می‌دهد. clue حیاتی روی نیم‌tile clipشده قرار نگیرد. این محاسبه از ابعاد داده‌شدهٔ پروژه است، نه قاعدهٔ engine.

- icon سرنخ پیشنهادی حداقل ۸×۸ pixel بازی با silhouette واضح؛ seam با ۲ pixel تغییر پایدار، نه یک pixel sparkle تک‌فریمی. این‌ها starting specification هستند و با device test تأیید می‌شوند.
- critical clue بیرونِ محل پوشش d-pad و ability buttons باشد؛ در دو layout دست‌چپ/راست یا safe-area move شود. خود clue جا‌به‌جا نشود؛ UI مزاحم آن move شود.
- متن world چند کلمه باشد؛ interact، panel خوانا با فونت بزرگ‌تر و scroll به‌جای ۳ خط tiny text. commands و codeها LTR، توضیح فارسی RTL؛ ترتیب arrows در widget مستقل از bidi متن باشد.
- جهت‌کدها در puzzle mode با چهار touch target بزرگ وارد شوند؛ حرکت character در این mode مصرف نشود. double tap و gesture دقیق برای secret لازم نباشد.
- راهنمای Android حداقل 48dp برای touch targets توصیه می‌کند؛ dp را با pixel داخلی 384×216 یکی نگیرید. روی web اندازهٔ فیزیکی/control area را در device واقعی بسنجید و از CSS/layout مناسب استفاده کنید؛ ۸×۸ icon می‌تواند hit area بزرگ‌تر داشته باشد.[[20]](https://support.google.com/accessibility/android/answer/7101858?hl=en)
- رنگ هر clue با شکل یا pattern جفت شود؛ sound با bubble یا waveform. web autoplay audio ممکن است تا input اولیه محدود باشد؛ game با Tap to start audio آغاز شود و حل هیچ راز به شنیدن وابسته نباشد.[[19]](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_web.html)
- انتخاب ring curl با target snapping و highlight واضح؛ secret platform path پهن‌تر از route challenge عمدی. هدف طراحی secret knowledge با touch parry accuracy قاطی نشود.
- journal هنگام pause شخصی قابل‌خواندن باشد؛ در co-op بازکردن journal لزوماً جهان هم‌بازی را متوقف نکند. safe terminals، بازگشت بدون loss و cache متن پس از reload داشته باشید.

**تست الزامی پیشنهادی:** PC keyboard + Android Chrome touch؛ audio خاموش؛ color-insensitive view؛ بزرگ‌کردن text؛ ورود نفر دوم پس از open؛ submit هم‌زمان؛ disconnect وسط latch؛ background/foreground مرورگر؛ refresh پس از reward؛ ping بالا و jitter. مقادیر شبکه باید شرایط آزمون باشند، نه ادعای توانایی اندازه‌گیری‌شدهٔ CLAWD.

## ۸. Anti-patterns — خطاها با نمونه و اصلاح

### ۸.۱. دوازده خطای طراحی

| خطا | نمونه/شاهد و مرز اعتبار | اصلاح دقیق برای CLAWD |
| --- | --- | --- |
| wall-sweeping به‌جای deduction | commentsِ blog La-Mulana از لزوم زدن دیوارهای بی‌نشان انتقاد دارند؛ این تجربهٔ بازیکن است، نه حکم developer. S13 | moth و seam اختصاصی؛ tester باید محل مشکوک را قبل از برخورد تصادفی توضیح دهد |
| فاصلهٔ زیاد فرضیه تا آزمون | Jesper Juul دربارهٔ Fez هزینهٔ travel/repetition را نقد می‌کند. S08 | shortcut نزدیک terminal؛ reset محلی؛ clue در journal همراه room pin |
| پاسخ بدون derivation روشن | monolithِ Fez با brute force جمعی حل شد؛ Fish این روش را جالب می‌داند، اما این تأیید مسیر استنتاج intended نیست. S07 | solution manifest برای هر puzzle شامل همهٔ steps؛ community می‌تواند shortcut کند، designer باید proof داشته باشد |
| تعداد زیادی loose end هم‌زمان | GMTK نگرانی Basso دربارهٔ overloadِ مسیرها و doors را نقل می‌کند. S12 | در early zone فقط چند thread واضح فعال؛ برخی shortcuts از سمت اول اصلاً clue اجباری نداشته باشند |
| basic usability را mystery نامیدن | NIGORO اصلاح guidance و controls را از حفظ challenge جدا می‌کند. S13 | input terminal، Clear و نوع feedback شفاف؛ راز در معنی داده‌ها باشد |
| پایان اول احساس شکست بدهد | Shouldice ending اول Tunic را legitimate می‌داند؛ مصاحبه‌گر و تیم او امکان دریافت «mean/bad» را مطرح می‌کنند. S06 | ending CLAWD مستقل و کامل؛ «شب آرام شد» سپس دعوت به archive، نه «فقط ۶۰٪ حقیقت» |
| puzzle بدون player population | headline گزارش mural Animal Well از نیاز به ۵۰ نفر می‌گوید؛ Basso بعداً حل solo از طریق playthroughهای متعدد را تأیید می‌کند. S03–S04 | شش قطعه، همه در همان save؛ اشتراک سرعت/لذت بدهد، نه وابستگی جمعیتی |
| secret همیشه وعدهٔ راه‌حل نهایی بدهد | Noita wiki Eye Messages را unresolved گزارش می‌کند؛ وضعیت قطعی اکتبر ۲۰۲۶ unverified است. S26 | فقط mystery دارای payoff را interactive clue بنامید؛ background decoration را puzzle قطعی تبلیغ نکنید |
| rewardِ قدرت همراه تنبیه ناگفته | orbs در Noita قدرت boss را تغییر می‌دهند. S25؛ تحلیل انتقال به CLAWD است | تأثیر بر debug challenge جدا؛ preview و consent؛ main boss ثابت بماند |
| رمز درست، execution نابرابر | Moon Berry در Celeste یک مسیر mastery دشوار است، نه نمونهٔ code آسان. S29 | HP پشت knowledge code نیازمند mastery نباشد؛ challenge room cosmetic و checkpoint مستقل |
| opacity را به QA تحمیل کردن | برای ESA، Smite می‌گوید حتی audience بزرگ در puzzle section کمک developer لازم داشت و محتوا patch شد؛ تأیید مستقل جزئیات patch unverified. S22 | testerِ بی‌اطلاع + walkthrough با همهٔ جواب‌ها برای QA؛ «من حل کردم» designer معیار کافی نیست |
| feedback با spoiler اشتباه شود | Basso حتی آزمایش غلط را acknowledge می‌کند؛ این لزوماً hint جواب نیست. S01 | response نوع action را روشن کند: dust، socket pulse، wrong-value؛ companion جواب را پس از چند ثانیه نگوید |

**خطاهای ویژهٔ پروژه، نه ادعا دربارهٔ مراجع:** clue یک‌pixel زیر انگشت؛ code فقط با keyboard یا vibration؛ collectible پاک‌شده برای نفر دوم؛ freeze کل simulation؛ undoِ reward؛ duplicate reward هنگام reconnect؛ falling into secret بدون خروج solo؛ مجبورکردن تازه‌وارد به دریافت جواب کشف‌شدهٔ دوست؛ نیاز به real-world clock یا اجرای command واقعی. همه برای CLAWD باید در checklist release باشند.

### ۸.۲. جامعه چگونه واقعاً کشف می‌کند؟ یک case study قابل‌انتقال

در گزارش contemporaneousِ Animal Well، mural ابتدا decoration به نظر می‌رسد؛ پیدا‌شدن control panel فرضیهٔ تعامل می‌سازد؛ سپس هر بازیکن یک grid کوچک متفاوت می‌بیند. reviewers پیش از عرضه نزدیک ۲۰ قطعه جمع کرده بودند؛ پس از عرضه، contributionهای بیشتر و ترکیب تصویر با ابزارهایی مانند Photoshop/Canva حل را ممکن کرد. گزارش در همان روز با خبر حل update شد. این داستان را با «۵۰ نفر هم‌زمان باید online باشند» اشتباه نگیرید؛ puzzle به مجموعهٔ قطعات نیاز دارد. مصاحبهٔ بعدی Basso نیز می‌گوید Adelman با حدود ۲۵۰ playthrough آن را solo جمع کرده بود. تعداد ۲۵۰، روایت مصاحبه است نه اندازه‌گیری این پژوهش.[[1]](https://www.ign.com/articles/animal-well-contains-a-hidden-puzzle-that-requires-at-least-50-people-to-complete)[[2]](https://www.thegamer.com/animal-well-interview-billy-basso-bigmode-dunkey)

برای CLAWD، contribution card باید **piece_id، orientation، room نام‌دار و نسخهٔ puzzle** داشته باشد؛ خود card با screenshotِ readable قابل‌اشتراک باشد، بدون account و server جدید. duplicates معنی‌دار تشخیص داده شوند. community جواب را ممکن است بسیار زودتر از انتظار پیدا کند؛ زمان «سال‌ها تا کشف» تعهد محصول نیست. بعد از انتشار، hintهای تکمیلی را داخل game و برای همه یکسان اضافه کنید، نه فقط پاسخ‌های موردی در Discord که دیگران مجبور شوند جست‌وجو کنند.

**هزینهٔ واقعی:** UI export یا backend برای نسخهٔ نخست لازم نیست؛ journal card قابل‌عکس و copy-text کافی است. secret در browser قرار نیست در برابر استخراج assets محرمانهٔ امنیتی بماند؛ هدف، تجربهٔ fair discovery است نه شکست‌دادن dataminerها. اگر جواب با inspection پیدا شد، logic جهان همچنان باید coherent و تمام clues موجود باشند.

## ۹. Top 15 recommendations — رتبه‌بندی اثر در برابر هزینه

**روش رتبه‌بندی:** قضاوت کیفی بر اساس پوشش چند secret، رفع خطر co-op/phone، reuse سیستم موجود و هزینهٔ incremental؛ نه ROI مالی، نتیجهٔ user study یا نمرهٔ عددی ساختگی. ترتیب implementation دقیق با dependencyها تنظیم می‌شود. low/medium/high همان تعریف بخش ۳ است. safety و اعتماد بازیکن بر cosmetic novelty مقدم‌اند.

| رتبه | اقدام مشخص | اثر | هزینه | دلیل نسبت اثر/هزینه | معیار Done |
| --- | --- | --- | --- | --- | --- |
| ۱ | moth را فقط dead code کنید؛ crack/firewall/floor grammar جدا | بسیار زیاد | low | روی تقریباً همهٔ roomها اثر، بدون mechanic جدید | هیچ symbol یکسان action متضاد نخواهد داشت؛ ۳ room آموزشی pass شوند |
| ۲ | clue بصری پایدار کنار sound و token باقی‌مانده | بسیار زیاد | low | phone، silent play و نفر دوم را هم‌زمان پشتیبانی می‌کند | همهٔ secrets با audio off قابل‌حل؛ جمع token clue را حذف نمی‌کند |
| ۳ | reward entitlement مشترک و claim idempotent | بسیار زیاد | medium | جلوگیری از dupe/از‌دست‌رفتن انگیزه در تمام co-op | submit هم‌زمان، reconnect و late join دوباره reward نمی‌دهند و کسی محروم نمی‌شود |
| ۴ | solution manifest و validator برای حدود ۳۰ room | زیاد | low | کد AI agents بدون قرارداد محتوا drift می‌کند | هر room clue، جواب، wrong feedback و solo fallback ثبت‌شده دارد |
| ۵ | local reset و hatch/shortcut خروج برای secrets | زیاد | low | کاهش هزینهٔ آزمایش در بیشتر roomها | failure، player را به traverse طولانی یا softlock نمی‌فرستد |
| ۶ | terminal پایهٔ touch-friendly برای ۴ direction و palette | بسیار زیاد | medium | چندین knowledge puzzle با یک UI/parser | جواب صحیح از fresh save و هر دو device پذیرفته شود |
| ۷ | journalِ facts + pins، بدون auto-inference | زیاد | medium | مانع فراموشی و co-op spoiler؛ پایهٔ سه لایه | clue ثبت‌شده قابل‌بازخوانی؛ solved conclusion خودکار نمایش داده نشود |
| ۸ | لایهٔ اول معتبر و پایان اصلی مستقل از meta | زیاد | low | از obligatory ARG و power bottleneck جلوگیری می‌کند | main path بدون knowledge secret کامل تست شود |
| ۹ | hint چهارمرحله‌ای به درخواست هر نفر | زیاد | medium | خروج از بن‌بست، بدون companion spoiler | hint نفر اول برای نفر دوم خودکار باز نشود |
| ۱۰ | three-state latch prefab برای co-op/solo | زیاد | medium | چند puzzle دو‌نفره بدون timingِ شکننده | offline/solo و disconnect همان reward را ممکن کنند |
| ۱۱ | سقف دامنهٔ --verbose؛ accessibility رایگان و مستقل | زیاد | low | cleanup با ابزار فعلی، بدون لو‌دادن meta | outline دیوار، نه code/تمام secrets؛ mode کنتراست plugin slot مصرف نکند |
| ۱۲ | چهار نمونهٔ knowledge مختلف: trace، stack، git، diff | زیاد | low پس از رتبهٔ ۶ | چهار نوع استدلال با یک زیرساخت | testerِ غیرprogrammer جواب هر چهار را با شواهد داخلی توضیح دهد |
| ۱۳ | fragment همراه micro-lore و progress 1/4 | متوسط تا زیاد | low | reward تکراری را با text کم منحصربه‌فرد می‌کند | هر fragment نام/روایت کوتاه متفاوت و progress فوری دارد |
| ۱۴ | یک meta-chain Boot Atlas در دو payoff room | زیاد برای curious | medium | reuse اتاق‌ها؛ احساس عمق بدون map جدید | همهٔ قطعات قابل‌یافتن، مسیر استنتاج کامل، جواب زودهنگام معتبر |
| ۱۵ | hub واکنشیِ rescued agents؛ mosaic را stretch نگه دارید | متوسط | medium؛ mosaic high | اثر عاطفی قابل‌دیدن از collectables؛ هزینه کمتر از ARG backend | چند animation کوتاهِ reused؛ حذف mosaic پایان/secret دیگر را خراب نکند |

### مسیر تولید پیشنهادی

- **Milestone A — زبان و اعتماد:** رتبه‌های ۱–۵، ۸ و ۱۱؛ پنج room representative: walk، dash، catch، agent، phase. این milestone به puzzleهای رمز وابسته نیست.
- **Milestone B — دانش و مشارکت:** terminal، journal، hint و latch؛ سپس چهار secret رتبهٔ ۱۲، با fresh-save test.
- **Milestone C — عمق:** یک Boot Atlas، دو payoff room، lore hub. M2 mosaic و P13 snapshot mechanic فقط اگر زمان QA و علاقهٔ واقعی بازیکن باقی ماند.

### playtest و معیارهای عملی — هدف‌های پیشنهادی، نه نتایج موجود

برای هر session، پنج رخداد ثبت کنید: clue در viewport قابل‌دیدن شد؛ بازیکن clue را verbalize/ping کرد؛ فرضیه گفت؛ action امتحان کرد؛ feedback و reward را فهمید. این‌ها را جدا از صرف ورود به room بشمارید. اگر کشف زیاد است ولی بازیکن دلیلش را نمی‌داند، accidental collision را با fairness اشتباه نگیرید.

- **casual:** پس از آموزش moth، tester در room تازه باید بتواند محل محتمل را پیش از wall-sweeping مشخص کند.
- **curious:** بدون دانش programming بیرونی، حداقل یک مسیر استنتاج قابل‌توضیح باشد؛ fresh save با جواب درست gate را باز کند.
- **community:** دو tester که هر کدام نصف اسناد را دارند باید بتوانند با شرح شفاهی/کارت‌ها answer مشترک بسازند؛ solo هم با یافتن همهٔ اسناد ممکن باشد.
- **phone parity:** failure ناشی از wrong idea و failure ناشی از touch/missed input جدا ثبت شوند؛ برای knowledge puzzle، دومی نقص UI است نه challenge.
- **network trust:** آزمایش شبیه‌سازی‌شدهٔ latency حدود ۲۰۰–۳۰۰ms و jitter، همراه reconnect و double-submit؛ این اعداد سناریوی پیشنهادی تست‌اند، نه وضعیت اینترنت همهٔ کاربران.
- **reward:** پرسش دقیق «چه چیزی گرفتی و کجا به کارت می‌آید؟»؛ جواب نامشخص یعنی reward presentation یا خود reward ضعیف است.

گروه‌های small-team test را از هم جدا کنید: noviceِ بی‌اطلاع، curious solo، PC–Android duo؛ اعضای تیمی که جواب را می‌دانند، برای فنی QA مناسب‌اند نه سنجش کشف. ابتدا failure patternها را اصلاح کنید؛ درصد کشف بدون denominatorِ فرصت دیدن، metric تصمیم‌گیری خوبی نیست.

## ۱۰. Sources — منابع با لینک و دامنهٔ استفاده

**راهنمای اعتبار:** «اولیه» = سخن/نوشتهٔ developer یا سند رسمی؛ «ثانویه» = تحلیل/راهنما؛ «community» = ثبت حل یا تجربهٔ بازیکن. مصاحبهٔ منتشرشده برای نقل سخن developer منبع اولیه است، ولی توضیح خبرنگار شاهد جداست. ویدئویی که فقط معرفی یا abstract آن در دسترس بوده، شاهدِ جزئیات شنیده‌نشده محسوب نشده است. تاریخ‌های نیامده به‌معنی نامعلوم در استخراج این پژوهش‌اند؛ تاریخ navigation سایت‌ها را تاریخ مقاله نگرفته‌ایم.

### منابع اولیه و توضیح طراحان

- **S01 — Billy Basso / Matt Fuller، Thinky Games، ۷ مه ۲۰۲۴.** How Animal Well is using secrets and mysteries. متن کامل مصاحبه خوانده شد؛ سه مخاطب، fact-learning، reaction به آزمایش غلط.
- **S02 — Billy Basso، Video Games Good، PAX West 2023.** Creating mysterious and mind-blowing Animal Well. بخش مصاحبه در نتایج استخراج‌شده؛ fun/playfulness پیش از reinterpretation item. نقل‌قول مستقل بلند در گزارش استفاده نشده است.
- **S04 — Billy Basso / Gabrielle Castania، TheGamer، ۱۲ سپتامبر ۲۰۲۴.** Animal Well: PAX West Interview. بخش مرتبط مصاحبه خوانده شد؛ ۵۰ قطعه و روایت حل solo توسط Adelman در حدود ۲۵۰ playthrough.
- **S05 — Andrew Shouldice، GDC 2023.** TUNIC: This Was Here the Whole Time. abstract رسمی خوانده شد؛ loose ends، barely-beneath-surface و finite game/bottomless mystery. متن کامل ویدئو بررسی نشده؛ جزئیات talk بیش از abstract **unverified** و نقل نشده‌اند.
- **S06 — Andrew Shouldice / Patrick Klepek، Waypoint/Vice، ۱۹ آوریل ۲۰۲۲.** The Delicate Balancing Act of Making a Video Game Built on Secrets. متن کامل خوانده شد؛ hints گسترده، QA/marketing slideshow، دو ending و اختلاف نیت/برداشت.
- **S07 — Phil Fish / Robert Purchese، Eurogamer، ۱۴ آوریل ۲۰۲۲.** Fez at 10: A rare interview. متن کامل خوانده شد؛ cubes/anti-cubes، social discussion، brute-forced monolith. این منبع وضعیت نهایی secrets در ۲۰۲۶ را تأیید نمی‌کند.
- **S09 — Jonathan Blow / Michael Thomsen، Paris Review، ۷ ژانویهٔ ۲۰۱۶.** Ready Player None. متن کامل خوانده شد؛ wonder، جهش فهم، nonverbal teaching و محدودیت language/human drama در vision بازی.
- **S10 — Kelsey Beachum، GDC 2021.** Sparking Curiosity-Driven Exploration Through Narrative in Outer Wilds — slides PDF.pdf). فایل در دو بخش تا انتها خوانده شد؛ curiosity loop، surface/mid/hidden، log facts، knowledge rewards و narrative payoff. سخنران **Kelsey** است؛ نام Alex در thesis نقل‌شده نباید موجب انتساب اشتباه talk شود.
- **S11 — Alex Beachum / Cordial Kobold.** Interview with the creative director of Outer Wilds. excerptهای پرسش‌وپاسخ استخراج‌شده؛ pursue-by-question و مسئولیت طراحیِ clueهای نامفهوم. تاریخ دقیق در استخراج مشخص نبود.
- **S13 — LA-MULANA STAFF / NIGORO، ۲۵ سپتامبر ۲۰۰۹.** About the Difficulty. متن developer و comments به‌صورت مجزا خوانده شد؛ کنترل، guidance و کاهش frustration. complaints خاص دربارهٔ unfair puzzles، شهادت commenters هستند، نه consensus یا اعتراف developer.
- **S16 — Team Cherry، Nintendo.** The Metamorphosis of Hollow Knight. مصاحبهٔ رسمی، زمینهٔ تیم و adventure inspirations؛ برای جزئیات Grub از S15 استفاده شده، نه تعمیم این مصاحبه.
- **S19 — Tom Happ، PlayStation Blog، ۲۶ ژانویهٔ ۲۰۱۵.** Axiom Verge: The Secrets of Speedrun Mode. بخش مرتبط خوانده شد؛ secret areas با location/layout متغیر و تفاوت اهداف speedrun/normal mode.
- **S20 — Thomas Happ Games، سند رسمی محصول.** Axiom Verge — Press Releases. mechanic glitches، corrupt environment و عبور به hidden areas؛ منبع نیت محصول، نه ارزیابی موفقیت همهٔ secrets.
- **S32 — Yacht Club Games، ۲۱ ژانویهٔ ۲۰۲۰.** Specter of Torment Level Design Deep Dive 5/5. بخش secret routing خوانده شد؛ branch direction، friction و خوانایی dead end. دربارهٔ طراحی Shovel Knight family است؛ قواعدش بی‌تغییر به metroidvania چهارسویه منتقل نشده‌اند.

### تحلیل، گزارش عرضه و ثبت حل جامعه

- **S03 — Rebekah Valentine، IGN، ۱۰ مه ۲۰۲۴.** Animal Well’s hidden 50-piece puzzle. متن کامل و update حل خوانده شد؛ روایت contemporaneous از جمع‌آوری pieces، reviewers و ابزارهای ترکیب. عنوان «at least 50 people» با امکان solo در S04 باید مقید خوانده شود.
- **S08 — Jesper Juul، ۲۱ آوریل ۲۰۱۲.** The Impossible Fez Puzzle and Notes on Puzzle Aesthetics. نقد تحلیلی/تجربهٔ شخصی؛ فاصلهٔ فرضیه تا آزمون، نه حکم آماری همهٔ بازیکنان.
- **S12 — Mark Brown، Game Maker’s Toolkit، ۲۷ سپتامبر ۲۰۲۴.** The Secret to Designing Mysterious Games. متن تحلیل مرتبط خوانده شد؛ locked doors، curiosity gaps، knowledge keys، overload و mural. تحلیل ثانویه با نقل طراحان؛ جای مصاحبه‌های مستقیم را نگرفته است.
- **S14 — Tayo Stalnaker، GameCritics.** La-Mulana Review. review ثانویه؛ tablets، delayed hints و laptop recording. نسخه‌های original/remake را برای ادعاهای خاص یکسان فرض نکرده‌ایم.
- **S15 — Hollow Knight Wiki، community.** Grub. crying، Nail rescue، Grubfather rewards و Collector’s Map؛ ثبت رفتار بازی، نه نقل فلسفهٔ Team Cherry.
- **S17 — Metroid Wiki، community با متن manual.** X-Ray Scope. passage/block detection و optional بودن؛ routeهای sequence-break غیرمعمول محور پیشنهاد نیستند.
- **S18 — Metroid Wiki، community.** Etecoon. demonstrationِ Wall Jump در Super Metroid و امکان نجات حیوانات؛ گزارش از مکانیک مشخص.
- **S21 — Steam Community، راهنمای ۲۰۱۵، به‌روزرسانی ۲۰۱۶.** Environmental Station Alpha — Comprehensive Postgame Guide. بخش‌های Eagle cipher، چهار terminals، Moon symbol و key hints خوانده شد؛ برخی requirements در comments اصلاح شده‌اند، بنابراین checklist دقیق progression نسخهٔ کنونی از این متن استخراج نشده است.
- **S22 — Smite، Let’s Play Archive، ثبت ۲۰۱۶.** Environmental Station Alpha. روایت اول‌شخص حل جمعی با audience و کمک developer. اصل روایت موجود است؛ علت و جزئیات patch بدون منبع اولیه **unverified**.
- **S23 — Hyper Light Drifter Wiki، community.** Monoliths. ۱۶ Monolith، gallery text و Ochre outfit.
- **S24 — Aezillo، Steam Community، انتشار ۱۱ آوریل ۲۰۱۶.** Decyphering the Language of Hyper Light Drifter. glyph/cipher و ترجمهٔ Monolithها؛ شاهد تولید دانش community، نه مصاحبهٔ developer.
- **S25 — Noita Wiki، community.** Orb of True Knowledge. spell/health reward و اثر تعداد orbs بر Kolmisilmä؛ اعداد بزرگ boss مبنای tuning CLAWD نیستند.
- **S26 — Noita Wiki، community.** Eye Messages. وجود پیام‌ها و گزارش unresolved بودن؛ تاریخ آخرین بازبینی puzzle روشن نیست؛ ادعای وضعیت قطعی ۱۱ اکتبر ۲۰۲۶ **unverified**.
- **S27 — Celeste Wiki، community.** Epilogue. تفاوت pie و واکنش‌ها بر اساس strawberries؛ thresholdهای عددی برای طراحی CLAWD کپی نشده‌اند.
- **S28 — Celeste Wiki، community.** Crystal Heart Guide. birds/satellite، ترتیب color→direction و code transformations Chapter 6.
- **S29 — Celeste Wiki، community.** Farewell / Moon Berry. مسیر پس از final power box، secret traversal و jellyfish challenge؛ وجود exploitِ spawn در مسیر نشان می‌دهد این الگو برای reward قدرت عادی مناسب نیست.
- **S30 — Reddit r/celestegame، community.** Crystal Hearts Hint Guide. نمونهٔ location/hint/solution جداشده؛ سیستم hint رسمیِ داخل Celeste نیست.
- **S31 — Steam Community، انتشار ۲ مه ۲۰۲۲.** Haiku the Robot — All Achievements, Collectibles, and Hidden Spots. chips، false ceiling، alcoves و scrap؛ برای ادعای «بازیکنان از scrap ناراضی‌اند» استفاده نشده است.
- **S36 — IGN، updated ۳ اوت ۲۰۱۸.** The Witness — Environmental Puzzles. interaction بدون panel، alignment و obelisks.
- **S37 — The Witness Wiki، community.** Easter Eggs. خورشید/entry gate و alternate ending؛ شرح رفتار، نه intentionِ اعلام‌شدهٔ Blow.
- **S38 — Outer Wilds Wiki، community با متن داخل بازی.** Tower of Quantum Trials. آموزش Quantum Imaging، استفاده از Scout photo و trialهای پی‌درپی.

### اسناد فنی و تاریخی

- **S33 — Smithsonian Institution، collection record.** Log Book With Computer Bug. mothِ Mark II در ۱۹۴۷ و قید «first actual case»؛ تصحیح برداشت تاریخی پروژه.
- **S34 — Godot documentation، نسخهٔ 4.3.** Exporting for the Web. محدودیت audio autoplay و networking پشتیبانی‌شده؛ دربارهٔ نسخهٔ دقیق CLAWD ادعایی نشده است.
- **S35 — Google، Android Accessibility Help.** Touch target size. توصیهٔ 48dp و امکان hit area بزرگ‌تر از visual؛ تبدیل مستقیم dp به pixel داخلی بازی نادرست است.

### اختلاف‌ها و موارد unverified که نباید به requirement تبدیل شوند

- **Fez:** Fish موفقیت brute force جامعه را مثبت می‌بیند؛ Juul تکرار/سفر آزمون را نقد می‌کند. اختلاف ارزش‌گذاری است، نه رد وجود secret. راه‌حل intended monolith و وضعیت نهایی آن در ۲۰۲۶ **unverified**.
- **Tunic:** سازنده ending اول را legitimate می‌نامد؛ برداشت «bad ending» در همان مصاحبه مطرح است. CLAWD باید naming و reward واقعی پایان پایه را کنترل کند، نه فقط نیت طراح را.
- **Animal Well:** «۵۰ نفر لازم» تعبیر headline از ۵۰ قطعه است؛ مصاحبهٔ بعدی حل solo با runs متعدد را تأیید می‌کند. همکاری intended است، synchronous attendance شرط نیست.
- **La-Mulana:** commenters دربارهٔ fairness اختلاف دارند؛ statementsِ developer دربارهٔ guidance با ادعای «همهٔ puzzleها unfair هستند» یکی نیست. الزام‌های مشخص original و remake بدون بررسی نسخه **unverified**.
- **Noita:** حل‌نشده‌بودن قطعی Eye Messages در تاریخ امروز **unverified**؛ این گزارش «باقی‌ماندن راز برای سال‌ها» را KPI نمی‌سازد.
- **برآورد اثر/هزینهٔ CLAWD:** ordinal design judgment است؛ زمان تولید، نرخ کشف، retention و latency تحمل‌شده هنوز دادهٔ واقعی ندارند. اعداد و budgets پیشنهادی باید با prototype و playtest آزموده شوند.

**نتیجهٔ اجرایی:** برای نسخهٔ نخست، زبان moth/crack، reward مشترک، terminal touch-friendly و چهار knowledge puzzleِ بازتفسیرکننده را بسازید؛ سپس یک meta-chain مستند اضافه کنید. عمق از بازخوانی جهان موجود بیاید، نه از تعداد زیاد mechanics، codeهای طولانی یا وابستگی به یک community بزرگ.
