# CLAWD — پژوهش اجرایی طراحی اتاق، pacing و set-piece

<aside>
🧭

تصمیم محوری: CLAWD باید سختی را از «خواندن وضعیت و انتخاب مسیر» بگیرد، نه از دقت frame-perfect یا هماهنگی لحظه‌ای دو بازیکن. اتاق‌های کوتاه و قابل‌بازخوانی را به یک جهان تغییرپذیر متصل کنید؛ spectacle را عمدتاً با تغییر state، صدا و ترکیب بلوک‌های موجود بسازید.

</aside>

**تاریخ پژوهش:** ۱۱ اکتبر ۲۰۲۶. **دامنه:** منابع عمومی، مصاحبهٔ سازندگان، postmortem، تحلیل room-level و گزارش‌های بازیکنان؛ بدون دسترسی به build، کد یا telemetry واقعی CLAWD. این سند گزارش playtest نیست.

**قرارداد شواهد:** «مستند» یعنی ویژگی در منبع قابل‌خواندن تأیید شده؛ «تحلیل» یعنی تفسیر این گزارش از نمونه؛ «پیشنهاد» یعنی طراحی جدید برای CLAWD. تمام اندازه‌ها، زمان‌ها، ترتیب unlock و آستانه‌های پذیرش پیشنهادی‌اند و نیاز به playtest دارند. ادعای تأییدنشده صریحاً **unverified** است. کدهای S به فهرست منابع بخش ۹ ارجاع می‌دهند. Spoiler برای محیط‌ها و پایان بعضی بازی‌ها وجود دارد.

## ۱. Summary — ده درس اصلی

1. هر اتاق یک فعل محوری داشته باشد: «منتظر بمان»، «بازتاب بده»، «از مسیر فروپاشنده عبور کن»؛ نه پنج هدف هم‌زمان.
2. ساختار introduce → develop → twist → conclude را در مقیاس مناسب اجرا کنید؛ چهار مرحله لزوماً در یک screen جا نمی‌شوند. [S01–S02]
3. پیش از خطر، نتیجهٔ یک ورودی را روی زمین امن قابل‌مشاهده کنید؛ «بمیر تا بفهمی» آموزش نیست. [S03–S04]
4. در ورودی، مقصد، سطح فرود بعدی و نشانهٔ خطر دیده شوند؛ مسیر ممنوع باید آشکارا ممنوع باشد، نه وسوسهٔ یک پرش تقریباً ممکن. [S03]
5. فاصلهٔ retry مهم‌تر از تعداد spikes است؛ چالش سخت را کوتاه و بازگشت را سریع نگه دارید. [S03، S06]
6. set-piece خوب یک وضعیت آشنا را تغییر می‌دهد: همان shaft اکنون پر از liquid؛ همان hub اکنون خشک و قابل‌عبور. [S07، S12]
7. خطر شدید مرز داشته باشد؛ بیرون آن واقعاً امن باشد، همان‌طور که E.M.M.I. در محدودهٔ مشخص باقی می‌ماند. [S08]
8. traversal، combat و puzzle را ابتدا پشت سر هم ترکیب کنید؛ هم‌زمانی را فقط پس از تسلط و به‌عنوان climax به کار ببرید.
9. در co-op، همکاری را با state پایدار و نقش‌های قابل‌تعویض بسازید؛ نه با پریدن روی شریک تأخیردار یا دو parry هم‌زمان.
10. برای تیم کوچک، room grammar، reset قابل‌اعتماد و تغییرات دوحالته از یک دشمن تعقیب‌کنندهٔ جدید ارزشمندترند. [S13]

## ۲. Room design method — دستور ساخت یک اتاق خوب

### ۲.۱. چه چیزی را از هر بازی برداریم؛ چه چیزی را نه

| بازی و نمونهٔ مشخص | شواهد room-level و برداشت طراحی | انتقال به CLAWD / محدودیت |
| --- | --- | --- |
| Celeste — moving-block momentum و Old Site chase | Thorson توضیح می‌دهد که مسیر ظاهراً ممکنِ اشتباه بازیکن را گرفتار می‌کرد؛ دو اتاق جانبی momentum را یاد می‌دادند. در Old Site، کاربرد آرام مکانیک پیش از chase می‌آید. [S03] | یک teaching loop کوتاه قبل از آزمون، قابل‌دورزدن برای بازیکن ماهر؛ chase را پیش از معرفی کامل آغاز نکنید. |
| Celeste — The Summit و 7B | Summit مکانیک‌های فصل‌های قبل را در subchapterها جمع می‌کند؛ 7B در flag 08، wallbounce را با bird آموزش می‌دهد. این نمونه کاملاً «بدون متن/نشانهٔ آموزشی» نیست. [S05] | DEPENDENCY HELL محل remix اختیاری است؛ تکنیک ضروری تازه را در آخر یک gauntlet طولانی پنهان نکنید. |
| Hollow Knight — White Palace / Path of Pain | atrium با bench و شاخه‌های switchدار، رشته‌های platforming را جدا می‌کند؛ Path of Pain با pogo روی hazards، Soul Totemهای تجدیدپذیر و دو Kingsmould در پایان شناخته می‌شود. [S09–S10] | استراحت مرکزی و checkpointهای موضعی را بگیرید؛ punish سنگین combat پایانی را برای مسیر اصلی تقلید نکنید. |
| Hollow Knight — Crystal Peak | conveyorها، crusherها و crystal laserها زبان مکانیکی mine را می‌سازند؛ بالای منطقه یک room با Quirrel و نمای Dirtmouth وجود دارد. [S11] | THREAD TOWER باید با silhouette و حرکت عمودی شناخته شود؛ vista بعد از سختی، نه صرفاً تزیین در شروع. |
| Ori and the Blind Forest — Ginso Tree | آب رو به بالا و استفادهٔ پی‌درپی از Bash در escape، مهارت traversal را به climax تبدیل می‌کند؛ تجربهٔ difficulty بین بازیکنان اختلاف دارد. [S15، S23] | rising liquid روی مسیر قبلاً تمرین‌شده؛ دشمن/پرتابهٔ لازم برای عبور نباید با عمل شریک حذف شود. |
| Ori and the Will of the Wisps — Windswept Wastes | McEntee از sketch و blockout برای Burrow، سپس ترکیب با collapsing sand و sandworm escape می‌گوید؛ collapsing sand راه backtrack را هم حفظ می‌کند. [S07] | اول سناریوی حرکت را blockout کنید؛ پس از collapse یک راه برگشت دائمی بسازید. |
| Super Metroid — Etecoons و Maridia glass tube | Etecoons حرکت wall jump را نمایش می‌دهند؛ tube شکستهٔ مشابه، نمونه‌ای از سرنخ محیطی است. سازندگان بر روایت کم‌متن و صدا تأکید می‌کنند. [S12، S14] | agent نمایشی یا ترک هم‌خانواده را زود ببینیم؛ سرنخ کم‌رنگ روی مسیر اجباری را با نشانهٔ دوم تقویت کنید. |
| Metroid Dread — E.M.M.I. Zones | light state، درهای متمایز، checkpoint نزدیک و محدودکردن قلمرو تهدید صریحاً در گزارش سازندگان آمده؛ counter هنگام گیر افتادن عمداً بسیار دشوار است. [S08] | مرز تهدید و state واضح را بگیرید؛ rescue مبتنی بر narrow counter را برای touch کنار بگذارید. |
| Prince of Persia: The Lost Crown — blocked routes / Memory Shards | screenshot اتاق روی map، بار حافظهٔ بازگشت را کاهش می‌دهد؛ Boutin تأکید می‌کند طبیعی‌شدن آن iteration زیادی خواسته است. [S16] | نسخهٔ کم‌هزینه: map icon برای ring/phase/cracked؛ screenshot کامل اولویت بعدی است، نه یک feature «مجانی». |
| Rayman Legends — Castle Rock | حرکت، jump و attack با music track هماهنگ‌اند؛ autoscroll به sequence شتاب می‌دهد و collapse یک tower بخشی از صحنه است. [S17] | rhythm بصری/شنیداری را بگیرید؛ beat موسیقی نباید شرط زمان‌بندی مشترک شبکه باشد. |
| Super Meat Boy — اتاق‌های کوتاه با goal آشکار | postmortem خود تیم: حذف lives، کم‌کردن respawn time، کوتاه‌کردن levels و نگه‌داشتن goal در دید؛ replay شکست‌ها را به feedback تبدیل می‌کند. [S06] | retry سریع و هدف مرئی برای سختی اختیاری؛ ترکیب آن با corpse run بلند ناقض همین منطق است. |
| Hollow Knight: Silksong — Moss Grotto / Citadel | اطلاعات موجود است و بازی منتشر شده؛ مصاحبهٔ Team Cherry توضیح می‌دهد Moss Grotto برای آشنایی آرام‌تر با moveset اضافه شد، اما باید جزئی از ecosystem باشد. Citadel در جهان پیش‌آگهی می‌شود. [S18–S19] | SOURCE TREE آموزش را به «راهروهای واقعی فایل‌ها» تبدیل کند؛ PRODUCTION از چند zone قبل در background دیده شود. |
| Nine Sols — Factory (Great Hall) | radiation دوره‌ای با هشدار محیطی، پناهگاه و دستگاه محافظ؛ پازل جداگانهٔ platformها با Mystic Nymph و تغییر همسایه‌ها. اطلاعات جزئی از wiki است، نه اظهار قصد طراح. [S20–S21] | combat signatureِ catch را حفظ کنید؛ puzzle آرام را از radiation عبوری جدا کنید. |
| Dead Cells — biome-specific handmade chunks | Bénard: roomهای treasure، shop و combat متفاوت‌اند؛ graph ابتدا entry/exit و special roomها را تعیین می‌کند. Sewers تنگ‌تر و Ramparts خطی‌تر است. [S13] | template library با قرارداد درها؛ نیاز به procedural generation کامل ندارید، graph دستی کافی است. |
| Haiku the Robot — Abandoned Wastes / Electro-Magnetism | walkthrough: پس از Trash Magnet، wall jump گرفته می‌شود و خروج از مسیر دیوارها آن را فوراً به کار می‌گیرد؛ سپس save room. secretها با notchهای دیوار/سقف دیده می‌شوند. [S22] | اتاق پس از unlock یک کاربرد امن و فوری بدهد؛ نشانهٔ هندسی secret بهتر از wall spam است. |

**نمونهٔ تکمیلیِ room-level از The Lost Crown:** در hands-on رسمی Ubisoft، یک chasm با outlineِ platformها توصیف شده است: arrow به bell، platformهای اطراف را موقتاً solid می‌کند؛ Shadow of Simurgh اجازه می‌دهد پس از سقوط به نقطهٔ قبلی برگردید. برداشت برای CLAWD: محل solidِ توقف و reset بخشی از راه‌حل یک puzzle زمانی است، نه چیزی بیرون طراحی room. نسخهٔ ارزان با blinking blocks، ledge امن و checkpoint موضعی ساخته می‌شود؛ teleport/rewind تازه لازم نیست. این منبع پیش از انتشار است و نام room را مشخص نمی‌کند؛ نام دقیق **unverified** است. [S31]

### ۲.۲. سه اختلاف مهم؛ یک نسخه برای همه وجود ندارد

- **رویکرد آموزشی:** Hayashida بر یک concept و چهار گام تأکید دارد؛ Team Cherry بر «فضای باورپذیر» و پنهان‌کردن lock-and-key صریح. این تضاد هدف است، نه تناقض داده. برای CLAWD، skeleton آموزشی را طراحی کنید، سپس آن را در معماری zone ادغام کنید: bridge برای dependency، buffer برای memory، port برای network. [S01، S18]
- **شدت و هزینهٔ شکست:** Super Meat Boy سختی بالا را با retry کوتاه می‌پذیرد؛ Dread تهدید را در zone محدود می‌کند؛ بازیکنان Ori دربارهٔ Ginso Tree از «بهترین لحظه» تا «علت ترک بازی» گزارش داده‌اند. نتیجه: موفقیت هنری یک escape مجوز اجبار همهٔ بازیکنان به آن نیست. [S06، S08، S23–S24]
- **collapse و بازگشت:** McEntee صریحاً توضیح می‌دهد sequence یک‌طرفهٔ Rayman را نمی‌توان بی‌تغییر در metroidvania قرار داد؛ sand دوباره قابل‌عبور شد. برای CLAWD هر تغییر دائمی باید route بعدی و شریک جامانده را در نظر بگیرد. [S07]

### ۲.۳. Recipe ده‌مرحله‌ای

1. **کارت اتاق را قبل از tilemap بنویسید.** zone، نقش در pacing، مکانیک لازم، توانایی‌های ممنوع، چهار door و جهت ورود معتبر، حالت پیش/پس از event، reset، و ایدهٔ یک‌جمله‌ای. مثال: «روی crumbling نمی‌توان منتظر platform ماند؛ باید زمان ورود را روی solid انتخاب کرد.»
2. **فقط یک learning objective انتخاب کنید.** پرسش اندازه‌پذیر: آیا بازیکن پس از اولین تماس می‌فهمد crumbling پس از delay می‌ریزد؟ اگر نه، دشمن و liquid را اضافه نکنید.
3. **envelope حرکت را اندازه بگیرید.** jump حدود ۳٫۵ tile فقط ارتفاع است؛ عرض gap از آن به دست نمی‌آید. run speed، زمان airtime، dash range/cooldown، wall jump، collider و touch aiming را روی build ثبت کنید. مقادیر این سند سقف پرش دقیق را فرض نمی‌کنند.
4. **ورودی امن بسازید.** landing pad حداقل ۴ tile برای دو avatar، دید به obstacle اول، بدون spawn projectile پشت door. در آموزش، کف گیرنده یا retry نزدیک قرار دهید؛ دوربین برای خواندن اتاق فرصت بدهد.
5. **introduce بدون چندوظیفگی.** یک crumbling با solid کنار آن و کف امن زیر آن؛ animation ترک پیش از سقوط. touch جدید و enemy تازه در همین نقطه معرفی نشوند.
6. **develop با تغییر یک متغیر.** فقط ارتفاع، طول رشته یا جهت را تغییر دهید؛ نه هر سه. room بعدی همان قانون را با stakes بیشتر تست کند.
7. **twist از قانون قبلی نتیجه بگیرد.** crumbling زیر moving platformِ آشنا: بازیکن باید روی solid منتظر بماند و سپس عبور کند. اگر باید قانون کاملاً تازه‌ای حدس بزند، این introduce جدید است، نه twist.
8. **conclude با اثبات و سکون.** safe exit، پاداش اختیاری یا دیدن gate بازشده. نتیجهٔ موفقیت در همان screen دیده شود؛ عبور موفق به دشمن بی‌هشدار ختم نشود.
9. **بازگشت و co-op را طراحی کنید.** هر door فعال را از هر دو جهت تست کنید؛ reset gate شریک را زندانی نکند؛ crumbling برای نفر دوم راه برگشت یا respawn داشته باشد. اگر unlock هنوز نیامده، branch بسته باید واضح و بازگشت کوتاه باشد.
10. **سه تست پیش از art polish.** آزمون خوانایی با screenshot سه‌ثانیه‌ای؛ blind playtest روی touch؛ PC+Android با تأخیر و jitter. ثبت کنید: اولین مسیر انتخابی، علت شکست، فاصلهٔ retry، انتظار شریک، و برداشت بازیکن از قانون. مشکل هندسه را با افزایش افکت نپوشانید.

### ۲.۴. Worked example — «Catch Lane» در ۲۴×۱۳ tile

**نقش:** introduce + تأیید کاربرد catch در SOURCE TREE؛ نه فشردن تمام چهارگام در یک screen. run و jump از قبل آموخته شده‌اند. **قانون:** yellow projectileِ بازتاب‌شده switch را فعال می‌کند. **ورودی:** چپ؛ **خروج:** راست؛ doorهای بالا/پایین این نمونه غیرفعال‌اند.

**مختصات:** x=0…23 به راست، y=0…12 به پایین؛ سطح کف بالای ردیف y=11 است. مختصات projectile به مرکز lane اشاره دارد و با collider واقعی تنظیم می‌شود.

- ردیف‌های y=11 و y=12 در تمام عرض solid؛ spikes، liquid، crumble و moving platform صفر.
- entry/refuge در x=0…6؛ pillarِ solid در x=7، y=9…10، شلیک را می‌گیرد. بالای pillar باز است؛ عبور از آن یک jump حدود دوtile‌ایِ آشنا است.
- lane صاف در x=8…22؛ محل اولین catch در x=10…12. partner می‌تواند در refuge بماند یا با فاصله پشت نفر دیگر بایستد.
- enemyِ موجودِ شلیک‌کنندهٔ yellow projectile در حدود x=21، y=10، به چپ شلیک می‌کند؛ switch در x=17 و همان ارتفاع. شلیک عادی switch را فعال نمی‌کند؛ شلیک catchشده به راست برمی‌گردد و **پیش از رسیدن به enemy** به switch می‌رسد. enemy نباید بین player و switch باشد.
- gate در x=23، y=8…10 خروج را می‌بندد؛ بالای gate دیوار solid است تا jump/wall jump bypass ندهد. switch با خط بصری به gate وصل است؛ نتیجه در همان screen دیده می‌شود.
- پس از حل، source شلیک متوقف یا enemy به‌صورت معمول قابل‌حذف می‌شود؛ laneِ x=18…22 فضای نتیجه/توقف است. اگر چنین enemy/source در library نیست، emitter ساده هزینهٔ medium دارد و باید به scope اضافه شود، نه اینکه موجود فرض شود.

**beatهای player:** ① از refuge، یک شلیک کامل تا pillar را بی‌خطر می‌بیند و cadence را می‌خواند. ② از pillar می‌گذرد و روی کف ثابت catch را بدون aimِ midair می‌آزماید. ③ projectileِ برگشتی switch را می‌زند، خط نور روشن و gate باز می‌شود؛ علت و نتیجه هم‌قاب‌اند. ④ شلیک قطع و خروج آرام می‌شود؛ gate latched می‌ماند.

**develop و twist در roomهای بعد:** develop = همان lane از روی ledge ثابت، با جهت projectileِ قابل‌خواندن؛ twist = انتخاب موقعیت catch برای دو switch در دو lane مستقل، بدون timer؛ conclude = gate بازشده shortcut برگشت را نشان می‌دهد. جهت بازتاب واقعی catch باید اندازه‌گیری شود؛ ricochet/aim تازه فرض نشده است.

**co-op / recovery:** gate برای هر دو باز می‌ماند؛ reflected projectile نباید با برخورد به partner مصرف شود یا friendly damage بدهد. اگر enemy پیش از حل کشته شود، source از resetِ موضعی recover شود؛ وگرنه layout به علت softlock رد است. source recovery/stop اگر موجود نباشد، هزینهٔ medium دارد.

**فرضیهٔ playtest:** cadence اولیه حدود ۲٫۵ثانیه و telegraph حدود ۰٫۸ثانیه؛ projectile به‌اندازه‌ای کند که روی touch قابل‌خواندن باشد. سرعت و catch window از build تعیین می‌شوند. معیار پذیرش اولیه: player پس از اولین موفقیت توضیح دهد چرا شلیک عادی gate را باز نمی‌کند و بار دوم catch را بدون راهنمایی انجام دهد. خطای شبکه از خطای timing جدا ثبت شود.

### ۲.۵. نشان‌دادن مکانیک پیش از unlock؛ بدون text tutorial

**قاعده:** اول «وعدهٔ قابل‌شناسایی»، بعد acquisition، بعد کاربرد امن، سپس بازگشت به وعده. نمایش یک مانع نامفهوم آموزش نیست.

| قابلیت | پیش‌آگهی بصری قبل از unlock | اولین کاربرد پس از unlock | جلوگیری از برداشت اشتباه |
| --- | --- | --- | --- |
| dash / cracked | ترک یکسان روی wall و تکهٔ شکستهٔ همان material؛ پاداش پشت دیوار دیده می‌شود | یک cracked wall روی کف solid، بدون hazard | ضربهٔ melee feedback متفاوت از dash بدهد؛ wall معمولی همین ترک را نداشته باشد |
| double jump | ledge با فاصلهٔ عمودی آشکارا بیش از jump پایه و reward visible | دو ledge با کف گیرنده؛ نه spikes | فاصله را «تقریباً قابل‌پرش» تنظیم نکنید؛ مسیر اصلی از کنار آن ادامه یابد |
| grapple | ringهای هم‌شکل روی route اختیاری، با silhouette واضح | یک ring بالای کف امن، سپس دو ring | ring تزیینی از ring تعاملی متمایز باشد؛ تا unlock مسیر اجباری به آن وابسته نباشد |
| phase | thin wall با بافت/لبهٔ ویژه و مسیر قابل‌مشاهده در پشت آن | یک thin wall روی زمین، بدون timer | cracked و phase material هم‌شکل نباشند؛ phase از solid معمولی عبور نکند |
| catch | دشمنِ موجود یک yellow projectile کند روی lane امن می‌فرستد؛ خط بصری به switch | بازتاب افقی به switch در همان screen؛ gate نتیجه را نشان می‌دهد | فعلاً زنجیرهٔ ricochet تازه فرض نشده؛ زرد فقط برای projectile قابل‌catch استفاده شود |
| dead code | قطع‌شدن الگوی tile و notch کوچک، صدای reward یا نور پشت دیوار | یک secret اختیاری با مسیر برگشت واضح | secret اجباری بدون سرنخ ممنوع؛ بازیکن را به ضربه‌زدن به همهٔ دیوارها عادت ندهید |

این‌ها پیشنهاد CLAWD هستند، نه ادعای حضور عین این ترفندها در همهٔ بازی‌ها. الگوی نمایش عملی از Etecoons، نشانهٔ مشابه از Maridia و کاهش بار حافظه از Memory Shards گرفته شده است. [S12، S16]

## ۳. Room pattern catalogue — ۳۰ الگوی قابل‌ساخت

نام‌گذاری و دسته‌بندی زیر ابزار طراحی این گزارش است، نه taxonomy رسمی بازی‌ها. «چرا کار می‌کند» تحلیل است؛ نمونه‌های بازی با S به شواهد ارجاع دارند. **cost** شامل implementation، art و QA است: **low** = چیدمان/پارامتر بلوک موجود؛ **medium** = اتصال state، trigger، camera/audio یا reset مشترک؛ **high** = AI/قابلیت تازه یا state پیچیدهٔ چنداتاقی. این‌ها برآورد نسبی‌اند، نه نفرروز.

### A. آموزش و mastery

**01 — Teach Room**

- **چیست:** یک قانون، با شکست بی‌خطر.
- **نمونه:** دو room جانبی آموزش moving-block momentum در Celeste. [S03]
- **چرا:** نتیجهٔ حرکت از فشار اصلی جدا می‌شود.
- **CLAWD:** crumbling سه‌tile‌ای با solid کنار آن و کف گیرنده؛ دشمن صفر.
- **cost:** low.

**02 — Single-Rule Test**

- **چیست:** آزمون همان قانون بدون کمک تازه.
- **نمونه:** مسیر خروج wall climb پس از Electro-Magnetism در Haiku the Robot. [S22]
- **چرا:** acquisition فوراً به عمل تبدیل می‌شود.
- **CLAWD:** shaft کوتاه ۲۴×۲۶ با wall jump و سه ledge امن؛ سقوط به ledge قبلی.
- **cost:** low.

**03 — Controlled Variation**

- **چیست:** تغییر فقط یک بُعد از چالش.
- **نمونه:** flagهای متوالی Summit در Celeste با تغییر جهت wind. [S05]
- **چرا:** بازیکن قانون را حفظ می‌کند و adaptation را می‌آموزد.
- **CLAWD:** همان dash/cracked corridor، بار دوم با دیوار بالاتر؛ hazard جدید اضافه نشود.
- **cost:** low.

**04 — Rule Twist**

- **چیست:** کاربرد غافلگیرکننده اما منطقیِ قانون آشنا.
- **نمونه:** collapsing sand در Windswept Wastes که هم می‌ریزد و هم با Burrow قابل‌عبور است. [S07]
- **چرا:** یک شیء دو نقش traversal پیدا می‌کند.
- **CLAWD:** crumbling ابتدا bridge است؛ بعد از فروپاشی، مسیر پایین به dead code reward دیده می‌شود.
- **cost:** low؛ persistence دائمی medium.

**05 — Optional Teaching Loop**

- **چیست:** شاخهٔ کوتاه برای حل مشکل فهم، نه skill gate اجباری.
- **نمونه:** teaching detourِ momentum در Celeste. [S03]
- **چرا:** مبتدی تمرین می‌کند، ماهر مجبور به تکرار نیست.
- **CLAWD:** کنار catch gate، lane امن با projectile کند و switch نمایشیِ همان شکل؛ سپس بازگشت یک‌screen‌ای.
- **cost:** low؛ اگر projectile source تازه لازم باشد medium.

**06 — Mastery Remix / B-side**

- **چیست:** نسخهٔ اختیاری سخت‌تر از زبان آشنا.
- **نمونه:** Summit 7B، ترکیب dash/momentum و wallbounce. [S05]
- **چرا:** عمق از recombination می‌آید، نه tutorial طولانی.
- **CLAWD:** DEPENDENCY HELL همان crumbling و springs، با solidهای کمتر و retry کوتاه؛ reward غیرضروری.
- **cost:** low برای layout؛ QA روی touch medium.

### B. تنش، استراحت و جهت‌یابی

**07 — Gauntlet**

- **چیست:** چند عمل پیوسته با توقف کم.
- **نمونه:** رشته‌های pogo و saw در Path of Pain. [S10]
- **چرا:** استمرار، احساس تسلط و stakes می‌سازد.
- **CLAWD:** سه cellِ wall jump → dash از cracked → spring در corridorِ ۷۲ tile؛ checkpoint بین رشته‌ها.
- **cost:** low؛ reset قابل‌اعتماد لازم است.

**08 — Breather**

- **چیست:** سکون واقعی پس از تنش، بدون تعهد حرکت.
- **نمونه:** bench در atriumِ White Palace. [S10]
- **چرا:** بازیکن ریتم، route و منابع را دوباره می‌خواند.
- **CLAWD:** room کوچک با solid، نور cursor آرام، صدای fan و دو جای توقف؛ دشمن و timer صفر.
- **cost:** low؛ save feature فقط اگر موجود باشد.

**09 — Vista**

- **چیست:** مکانی که مقیاس جهان را بدون HUD توضیح می‌دهد.
- **نمونه:** Crystal Peak overlook با Quirrel و نمای Dirtmouth. [S11]
- **چرا:** تلاش قبلی به فاصله و موقعیت معنی‌دار تبدیل می‌شود.
- **CLAWD:** balconyِ THREAD TOWER با silhouette عظیم PRODUCTION و مسیرهای پایینِ پیموده‌شده.
- **cost:** medium برای background اختصاصی؛ با reuse کم‌تر.

**10 — Hub / Decision Room**

- **چیست:** مکانی امن برای انتخاب شاخه و بازگشت.
- **نمونه:** atriumِ White Palace، دو hallwayِ switchدار و lift مرکزی. [S10]
- **چرا:** graph در یک مکان قابل‌به‌خاطرسپردن خلاصه می‌شود.
- **CLAWD:** SOURCE TREE با درهای چهارطرف، shape متفاوت هر branch و gateهای stateدارِ قابل‌دیدن.
- **cost:** low؛ state مشترک medium.

**11 — Landmark Room**

- **چیست:** room با شکل/صدای یکتا برای نقشهٔ ذهنی.
- **نمونه:** glass tubeِ Maridia در Super Metroid. [S12]
- **چرا:** یک شیء خاص به نشانی فضایی تبدیل می‌شود.
- **CLAWD:** pointer bridge شیشه‌مانند بالای liquid؛ در نقشه silhouette همان پل ثبت شود.
- **cost:** low.

**12 — Threat Boundary**

- **چیست:** ورود خوانا به قلمرو خطر محدود.
- **نمونه:** E.M.M.I. Zone Doors در Metroid Dread. [S08]
- **چرا:** بازیکن می‌فهمد چه زمانی آماده شود و کجا آسوده است.
- **CLAWD:** port doorِ THE NETWORK با lane امن قبل و بعد، الگوی hazard متفاوت و warning واضح.
- **cost:** low برای layout؛ تعقیب واقعی high و ضروری نیست.

**13 — Maintenance Refuge**

- **چیست:** پناهگاه کوچک داخل منطقهٔ خطر دوره‌ای.
- **نمونه:** walled-off areas و Anti-radiation Device در Nine Sols Factory. [S21]
- **چرا:** خطر را به پنجره‌های قابل‌برنامه‌ریزی تبدیل می‌کند.
- **CLAWD:** alcove چهارtile‌ای solid کنار blinking bridge؛ امکان مشاهدهٔ یک cycle کامل.
- **cost:** low.

### C. progression و جهان واکنش‌پذیر

**14 — Locked Teaser**

- **چیست:** پاداش/مسیر قابل‌دیدن اما فعلاً دست‌نیافتنی.
- **نمونه:** blocked paths که Memory Shards برای بازدید بعدی ثبت می‌کنند، The Lost Crown. [S16]
- **چرا:** curiosity را به قصد بازگشت تبدیل می‌کند.
- **CLAWD:** grapple ring بالای liquid با reward پشت thin wall؛ map icon، نه dead end چنداتاقی.
- **cost:** low؛ map marker اگر تازه باشد medium.

**15 — Acquisition Chamber**

- **چیست:** دریافت قدرت با فضای امنِ درک آن.
- **نمونه:** Electro-Magnetism بعد از Trash Magnet در Haiku. [S22]
- **چرا:** unlock یک تغییر فضایی است، نه فقط عدد.
- **CLAWD:** grapple در THE HEAP؛ ring اول بالای کف solid و بدون timer.
- **cost:** low برای room؛ خود unlock خارج از این هزینه است.

**16 — Confirmation Corridor**

- **چیست:** خروجی که توانایی تازه را فوراً و ساده لازم می‌کند.
- **نمونه:** wall climb به خروج و save room پس از upgrade در Haiku. [S22]
- **چرا:** feedback موفقیت قبل از آزادی انتخاب ثبت می‌شود.
- **CLAWD:** phase از یک thin wall روی کف امن، سپس door به hub؛ هیچ blinking هم‌زمانی ندارد.
- **cost:** low.

**17 — Return Shortcut**

- **چیست:** مسیر کوتاه‌تر که loop طولانی را می‌بندد.
- **نمونه:** bridge و elevatorهای یک‌طرفه‌قابل‌بازشدن در Factory Great Hall، Nine Sols. [S21]
- **چرا:** جهان کوچک نمی‌شود، traversal خسته‌کننده حذف می‌شود.
- **CLAWD:** gate در پشت cracked wall به hub؛ پس از بازشدن برای هر دو نفر latched بماند.
- **cost:** low؛ cross-room persistence medium.

**18 — Changed-World Room**

- **چیست:** یک مکان آشنا با state معنایی جدید.
- **نمونه:** glass tubeِ Maridia پس از Power Bomb می‌شکند و ورودی تازه می‌شود. [S12]
- **چرا:** بازیکن تفاوت قبل/بعد را خودش تشخیص می‌دهد.
- **CLAWD:** THE HEAP پس از event خالی‌تر می‌شود؛ flood level پایین می‌آید و door زیر آب نمایان می‌شود.
- **cost:** medium.

**19 — Safe Demonstrator**

- **چیست:** موجود/عنصری که قانون را پیش از آزمون نشان می‌دهد.
- **نمونه:** Etecoons نمایش‌دهندهٔ wall jump در Super Metroid. [S12]
- **چرا:** imitation به جای توضیح انتزاعی.
- **CLAWD:** agent نمایشی روی platform جدا crumbling را لمس می‌کند و روی solid می‌پرد؛ replay کوتاه غیرتعاملی.
- **cost:** medium؛ رفتار تازهٔ AI لازم نیست.

### D. combat و puzzle

**20 — Arena**

- **چیست:** combat با کف و محدودهٔ قابل‌پیش‌بینی.
- **نمونه:** Kingsmould در ورودی White Palace پیش از atrium. [S10]
- **چرا:** محیط ساده خواندن enemy pattern را ممکن می‌کند.
- **CLAWD:** کف ۱۲tile‌ای solid، دو ledge سه‌tile‌ای و یک enemy typeِ آشنا؛ spikes وسط arena نگذارید.
- **cost:** low؛ اگر encounter gate/kill tracking تازه باشد medium.

**21 — Boss Threshold**

- **چیست:** آماده‌سازی پیش از commitmentِ نبرد.
- **نمونه:** مسیر save room و سپس Trash Magnet در Abandoned Wastes. [S22]
- **چرا:** retry و انتظار فضایی روشن‌اند.
- **CLAWD:** ante-roomِ PRODUCTION با solid landing، صدای fan رو به افزایش و gate شروع فقط بعد از آمادگی هر دو.
- **cost:** medium.

**22 — Boss Arrival**

- **چیست:** معرفی antagonist با عمل محیطی پیش از pattern جنگ.
- **نمونه:** Kuro پس از escapeِ Ginso Tree، Ori and the Blind Forest. [S15]
- **چرا:** اوج traversal به حضور روایی تبدیل می‌شود.
- **CLAWD:** سایهٔ boss موجود از پشت heatsink عبور می‌کند، نور قطع می‌شود، سپس arena باز می‌شود؛ hit در reveal ممنوع.
- **cost:** medium؛ خود boss جداگانه هزینه دارد.

**23 — Puzzle Box**

- **چیست:** کل مسئله در یک محدوده دیده می‌شود؛ reset در دسترس است.
- **نمونه:** platform-switch subroom در Nine Sols Factory با Mystic Nymph. [S21]
- **چرا:** وابستگی‌ها قابل‌ردیابی‌اند و exploration با execution خلط نمی‌شود.
- **CLAWD:** دو catch switch با خط بصری جدا، gate latched و reset روی کف امن؛ هم‌زمانی لازم نباشد.
- **cost:** medium.

**24 — Combat-to-Utility Bridge**

- **چیست:** مهارت combat به تغییر traversal تبدیل می‌شود.
- **نمونه:** Unbounded Counter روی Core Agitators، خاموش‌شدن radiation در Nine Sols. [S21]
- **چرا:** skill جنگ اثر واقعی در جهان دارد.
- **CLAWD:** catchِ yellow projectile به switch، gate را باز می‌کند و مسیر برگشت آسان می‌شود؛ projectile source باید recoverable باشد.
- **cost:** low با بلوک موجود؛ recovery logic medium.

### E. set-piece و reward

**25 — Rising Escape**

- **چیست:** مسیر تمرین‌شده با تهدید متحرک از پایین.
- **نمونه:** Ginso Tree escape. [S15]
- **چرا:** progression عمودی با فشار زمانی هم‌جهت است.
- **CLAWD:** shaftِ ۴۰–۶۰tile‌ای THE HEAP با rising liquid، ledge امن در هر segment و checkpoint موضعی.
- **cost:** medium.

**26 — Controlled Collapse**

- **چیست:** مسیر زیر پا تغییر می‌کند، ولی مقصد خوانا می‌ماند.
- **نمونه:** collapsing sand در Windswept Wastes؛ مسیر برگشت با Burrow حفظ می‌شود. [S07]
- **چرا:** spectacle از تغییر عملکرد geometry می‌آید.
- **CLAWD:** dependency bridgeِ crumbling می‌ریزد؛ route solid پایین، راه برگشت شریک و backtrack است.
- **cost:** low؛ collapseِ دائمی stateدار medium.

**27 — Rhythm Corridor**

- **چیست:** توالی حرکت با نشانهٔ زمانی تکرارشونده.
- **نمونه:** Castle Rock در Rayman Legends. [S17]
- **چرا:** پیش‌بینی beat بار تصمیم‌گیری را کم می‌کند.
- **CLAWD:** ۴۸tile blinking corridor با سه alcove؛ صدا و نور پیش از toggle، برخورد تابع ساعت room نه audio stream.
- **cost:** medium.

**28 — Risk–Reward Fork**

- **چیست:** route ایمن برای ادامه، route دشوار برای پاداش.
- **نمونه:** shaftِ Etecoons، escape tunnel آسان‌تر و Power Bomb Expansion در بالا، Super Metroid. [S12]
- **چرا:** بازیکن شدت و مدت challenge را انتخاب می‌کند.
- **CLAWD:** پایین solid bridge؛ بالا crumbling و spikes برای cosmetic/agent skin، نه توانایی ضروری.
- **cost:** low.

**29 — Secret with a Clue**

- **چیست:** secret اختیاری با نشانهٔ قابل‌استدلال.
- **نمونه:** notchهای دیوار و سقف در Abandoned Wastesِ Haiku. [S22]
- **چرا:** reward برای مشاهده است، نه brute-forceِ همهٔ دیوارها.
- **CLAWD:** dead code wall با یک bracket ناقص در الگوی tile و نور reward پشت آن.
- **cost:** low.

**30 — Quiet Payoff Room**

- **چیست:** پاداش معنایی/روایی بدون نبرد بعدی.
- **نمونه:** صحنهٔ کوتاه Pale King و Hollow Knight پس از Path of Pain. [S10]
- **چرا:** effort به کشف تبدیل می‌شود، نه صرفاً loot بیشتر.
- **CLAWD:** پس از DEPENDENCY HELL یک room با دو terminal خاموش و نخستین spriteِ Clawd؛ reward cosmetic، خروج دائمی به hub.
- **cost:** low؛ animation تازه medium.

**قانون ترکیب الگوها:** Teach + Breather یک room طبیعی است؛ Arena + Puzzle Box فقط وقتی معتبر است که puzzle پیش از combat فهمیده شده باشد. Gauntlet + Rising Escape + enemy تازه، سه بارِ توجه را روی هم می‌گذارد و برای مسیر اصلی CLAWD رد می‌شود.

## ۴. Signature moments — ۲۴ طرح، سه طرح برای هر zone

**همهٔ طرح‌های این بخش پیشنهادهای جدید برای CLAWD هستند؛ نمونهٔ مشاهده‌شده در بازی دیگر نیستند.** اندازه‌ها و مدت‌ها نقطهٔ شروع blockout‌اند. در هر zone فقط یکی را climax اجباری کنید؛ دو طرح دیگر می‌توانند vista، تغییر جهان یا رویداد اختیاری باشند. ساخت هر سه به شکل chase، تنوع را نابود می‌کند.

**قرارداد مشترک اجرا:** event اجباری فقط پس از rendezvous و تأیید آمادگی هر دو آغاز شود؛ تغییر world state خارج از room، بازیکن دوردست را نکشد. هر sequence حالت‌های idle / armed / running / completed و reset تعریف‌شده داشته باشد. یک global timer با ورود نفر اول بی‌خبر آغاز نشود. checkpoint و ready check در فهرست امکانات موجود ذکر نشده‌اند؛ اگر هنوز ساخته نشده‌اند، هزینهٔ medium دارند.

### ۴.۱. SOURCE TREE

#### ST-1 — «درختی که روشن می‌شود»؛ vista و orientation

**ابعاد/پیش‌نیاز:** hubِ ۴۸×۲۶، run و jump و catchِ ازقبل‌آموخته‌شده؛ منطق برگرفته از landmark و Citadelِ پیش‌آگهی‌شده. [S11، S18]

1. **می‌بیند:** ریشهٔ کابل‌ها خاموش است؛ سه شاخه با silhouette متفاوت به بالای تصویر می‌روند. روی یک platform امن، PRODUCTION دوردست دیده می‌شود؛ حس کوچک‌بودن.
2. **انجام می‌دهد:** یک مسیر کوتاه one-way را بالا می‌رود و switchِ catchِ معرفی‌شده را فعال می‌کند؛ خط نور از switch تا یک gateِ همان screen می‌رود.
3. **می‌بیند/می‌فهمد:** تنها شاخهٔ مربوط روشن و door آن باز می‌شود؛ جهان پاسخ علت‌ومعلولی دارد، نه teleport مبهم.
4. **استراحت:** balconyِ solid هر دو را کنار هم جا می‌دهد؛ پیش از ورود branch بعدی انتخاب آزاد است.
**بلوک/هزینه/ایمنی:** one-way، gate، switch + overlay نور؛ medium. پیش از آموزش catch این set-piece قرار نگیرد؛ state روشن‌شدن latched و برای بازیکنِ room دیگر غیرمرگبار است.

#### ST-2 — «کدی که هرگز اجرا نمی‌شود»؛ نخستین secret

**ابعاد:** یک screen، ۲۴×۱۳؛ dash اگر cracked استفاده شود، وگرنه فقط کشف fake wall.

1. **می‌بیند:** الگوی bracketهای دیوار یک شکاف نامعمول دارد؛ پشت آن یک pixel نور pulse می‌زند؛ حس شک.
2. **انجام می‌دهد:** به notch نزدیک می‌شود؛ fake dead code wall را می‌یابد، بدون requirementِ تخریب جدید.
3. **غافلگیری:** راهرو از پشت route قبلی عبور می‌کند؛ یک پاداش کوچک و تصویر Clawd در فضای تاریک است، نه arena پنهان.
4. **بازگشت:** gate یک‌طرفه از داخل باز می‌شود و player دوباره entry pad را می‌بیند؛ کشف با گم‌شدن مجازات نمی‌شود.
**بلوک/هزینه/ایمنی:** dead code، solid، gate؛ low، persistence medium. reward مشترک/دو نسخه؛ dead end نباید شریک را با بسته‌شدن wall محبوس کند. الهام از notchهای Haiku. [S22]

#### ST-3 — «اولین Build موفق»؛ پایان آموزش پایه

**ابعاد:** سه roomِ ۲۴×۱۳؛ ترکیب sequential، نه simultaneous.

1. **می‌بیند:** سه ناحیهٔ مسیر با اشکال آشنا: ledge، cracked wall، yellow lane؛ احساس آمادگی.
2. **انجام می‌دهد:** room اول فقط jump، دوم dash در cracked روی کف solid، سوم catchِ ایستاده به switch؛ هر action نتیجهٔ کوتاه دارد.
3. **پاسخ جهان:** با آخرین gate، چراغ‌های source tree به‌ترتیب روشن می‌شوند؛ صدای کوتاه success، نه متن آموزشی طولانی.
4. **آرامش:** room خروجی هیچ enemy ندارد؛ branchهای آینده در یک نمای ثابت دیده می‌شوند.
**بلوک/هزینه/ایمنی:** solid، cracked، switch/gate؛ medium برای سه flag و audio. شکست فقط room جاری را reset می‌کند؛ progress یک نفر برای هر دو ثبت می‌شود، اما برای نفر دوم فرصت تمرین می‌ماند. ریتم mastery و conclude از S01، S06.

### ۴.۲. DEPENDENCY DEPTHS

#### DD-1 — «npm avalanche»؛ collapse قابل‌بازگشت

**ابعاد:** corridorِ ۷۲×۱۳، crumbling قبلاً آموخته شده.

1. **می‌بیند:** packageهای انباشته روی یک bridge، routeِ solid پایین از شکاف‌ها پیداست؛ اضطراب قابل‌کنترل.
2. **انجام می‌دهد:** سه رشتهٔ crumbling را عبور می‌کند؛ میان آن‌ها solid island برای خواندن مسیر بعدی.
3. **twist:** bridge می‌ریزد و packageهای background به پایین می‌افتند؛ سقوط player به routeِ پایین است، نه void مرگ.
4. **conclude:** انتها cracked shortcut به hub دارد؛ route پایین پس از event برای backtrack باقی می‌ماند.
**بلوک/هزینه/ایمنی:** crumbling، solid، cracked؛ medium برای collapse state. تزیین avalanche collider ندارد؛ نفر دوم route پایین را از دست نمی‌دهد. درس collapseِ Ori: راه برگشت حذف نشود. [S07]

#### DD-2 — «دو نسخه از یک package»؛ fork بدون دوگانگی زمان‌بندی

**ابعاد:** ۴۸×۲۶، دو route برای دو flag مشترک؛ پاداش بالایی کنار مسیر و اختیاری است.

1. **می‌بیند:** دو مسیر موازی به یک gate؛ پایین solid طولانی‌تر، بالا crumbling کوتاه‌تر با reward visible؛ حس انتخاب.
2. **انجام می‌دهد:** هر بازیکن یکی را انتخاب می‌کند؛ touch می‌تواند پایین برود، اما نقش‌ها اجباریِ device-based نیستند.
3. **کشف:** هر مسیر switch خودش را دارد؛ فعال‌شدن آن پایدار است. یک نفر می‌تواند هر دو را با shortcut انجام دهد، بدون softlock هنگام disconnect.
4. **join:** gate مرکزی پس از هر دو flag باز می‌ماند؛ بازیکنان یک فضای انتظار مشترک می‌بینند.
**بلوک/هزینه/ایمنی:** solid، crumbling، switches/gates؛ medium. گرفتن flag نباید نیازمند دو parry در یک لحظه باشد. «نسخه‌ها» با shape، نه فقط رنگ، تفکیک شوند.

#### DD-3 — «package متروک»؛ quiet payoff پس از cascade

**ابعاد:** ۲۴×۱۳، پس از DD-1 یا gauntlet.

1. **می‌بیند:** پشت dead code، قفسه‌ای خالی و یک package کوچک سالم؛ صدای ریزش قطع می‌شود، حس کنجکاوی.
2. **انجام می‌دهد:** یک jump آسان به platformِ solid و دریافت reward اختیاری؛ combat صفر.
3. **غافلگیری:** از پنجره، bridgeِ فروپاشیدهٔ قبلی دیده می‌شود؛ بازیکن اثر عمل خودش را در محیط می‌خواند.
4. **استراحت:** door برگشت روی همان ارتفاع، بدون timer؛ دو نفر می‌توانند دربارهٔ مسیر بعدی تصمیم بگیرند.
**بلوک/هزینه/ایمنی:** dead code، one-way، solid؛ low با reuse background. این room جای مناسبی برای enemy surprise نیست؛ احساس حاصل باید relief باشد، نه سوءظن.

### ۴.۳. THE HEAP

#### HP-1 — «Memory Leak»؛ rising-liquid escape اصلی

**ابعاد:** shaftِ ۲۴×۵۲، wall jump/dash؛ grapple فقط اگر از قبل unlocked باشد.

1. **پیش‌خوانی:** مسیر ascent یک بار در حالت liquid ثابت/کم‌ارتفاع طی می‌شود؛ ledgeها و خروج‌ها آشنا می‌شوند.
2. **آغاز:** در پایین shaft، دو player آماده‌اند؛ liquid با warning و صدای پمپ بالا می‌آید؛ فشار از یک تغییر آشنا ناشی می‌شود.
3. **عمل:** سه segment با solid ledgeهای پهن؛ هر segment فقط یک نوع عمل غالب دارد. cracked wall روی ledge، نه در midpoint پرش blind.
4. **رهایی:** آخرین gate به room خشک می‌رود؛ پمپ خاموش و نمای سطح liquid دیده می‌شود؛ بعد هیچ combat فوری نیست.
**بلوک/هزینه/ایمنی:** rising liquid، solid، one-way، cracked؛ medium. speed از envelope حرکتِ touch با حاشیه تعیین شود، نه از PC speedrun. checkpoint بین segmentها سطح liquid را در state مشخص reset می‌کند؛ عقب‌ماندن شریک با بالا‌رفتن نفر اول مجازات نمی‌شود.

#### HP-2 — «Garbage Collection»؛ جهان خالی می‌شود

**ابعاد:** دو room آشنای ۴۸×۲۶، flood-state موجود.

1. **می‌بیند:** اولین بار یک door و ring زیر liquid دیده می‌شوند؛ مقصد فعلاً غیرقابل‌استفاده است؛ وعدهٔ بازگشت.
2. **انجام می‌دهد:** از route بالا به catch switch می‌رسد و valveِ تزیینی پاسخ می‌دهد؛ خطر همان مکانیک آشنا است.
3. **اثر:** flood level یک مرحله پایین می‌آید؛ با camera framing ثابت، tileهای جدید و door زیرین نمایان می‌شوند؛ احساس «جا آزاد شد».
4. **عمل دوم:** بازیکن از route خشک تازه بازمی‌گردد و shortcut می‌گشاید؛ حلقهٔ جهان کوتاه می‌شود.
**بلوک/هزینه/ایمنی:** liquid/flood progress، switch، gate؛ medium. فقط room خالی از player به‌صورت ناگهانی geometry عوض کند، یا تغییر زیر پای افراد غیرکشنده باشد. secret زیر آب برای progression ضروری نباشد.

#### HP-3 — «آخرین pointer زنده»؛ plateau و grapple teaser

**ابعاد:** ۲۴×۱۳ یا ۴۸×۱۳؛ بدون timer.

1. **می‌بیند:** جزیره‌ای solid وسط فضای liquid، یک ring در بالا و reward در branch دورتر؛ باقی محیط خاموش است؛ حس تنهایی.
2. **انجام می‌دهد:** روی moving platform پهن و کند به جزیره می‌رسد؛ همانجا می‌تواند توقف کند.
3. **کشف:** پیش از grapple مسیر اصلی از کنار ring می‌گذرد؛ پس از unlock همان ring مسیر پاداش را باز می‌کند؛ یک خاطرهٔ فضایی دوباره معنا می‌گیرد.
4. **آرامش:** صدای drip و انعکاس نارنجیِ Clawd؛ مسیر خروج اصلی روی solid/one-way روشن است.
**بلوک/هزینه/ایمنی:** liquid، moving platform، ring، solid؛ low/medium برای vista. رنگ liquid همان خطر قبلی را داشته باشد؛ اینجا به‌خاطر زیبایی بی‌خبر بی‌خطر نشود.

### ۴.۴. THE NETWORK

#### NW-1 — «Handshake»؛ همکاری asynchronous

**ابعاد:** دو room مجاور ۲۴×۱۳ و یک join pad.

1. **می‌بیند:** دو lane با شکل packet متفاوت و دو lamp خاموش در join؛ خط نور نشان می‌دهد هر room به کدام lamp مربوط است.
2. **انجام می‌دهد:** در هر room، catchِ projectileِ آشنا یک switch را می‌زند؛ انجام A و B ترتیب دلخواه دارد.
3. **اثر:** flagهای A/B پایدار می‌مانند؛ بازیکن می‌تواند room دیگر را تمام کند یا شریک را یاری کند؛ حس همکاری بدون عجله.
4. **join:** gate و route مرکزی برای هر دو باز می‌شوند؛ نمایش اتصال شبکه کوتاه و غیرکشنده.
**بلوک/هزینه/ایمنی:** switch/gate، solid و sourceِ projectile موجود؛ medium. ارسال دوبارهٔ trigger نباید gate را دوباره ببندد؛ reset فقط حل‌نشده‌ها را reset کند. source اگر کشته شد recover شود.

#### NW-2 — «Port Window»؛ timed door با پناهگاه

**ابعاد:** corridorِ ۴۸×۱۳، سه port؛ نه ۲۰۰tileِ بدون break.

1. **می‌بیند:** port اول از safe pad باز و بسته می‌شود؛ light و outline یک cycle کامل را نشان می‌دهند.
2. **انجام می‌دهد:** هنگام open از مسیر کوتاه عبور می‌کند؛ room بعدی یک alcove solid دارد؛ تصمیم «کی حرکت کنم» مهم‌تر از دقت dash است.
3. **twist:** port سوم مسیر فرعی reward دارد؛ بازیکن میان یک cycle انتظار یا مسیر اختیاری انتخاب می‌کند؛ closed door او را له نمی‌کند.
4. **رهایی:** خروج به فضای بدون port؛ صدای packet pulse خاموش می‌شود.
**بلوک/هزینه/ایمنی:** timed gates/blinking، solid؛ medium برای schedule/anti-crush. open window باید بیشتر از عبور اندازه‌گیری‌شده + jitter margin باشد؛ یک windowِ پیشنهادی ۲–۳ثانیه‌ای را با build تأیید کنید. الهام از مرزبندی Dread، نه narrow counter آن. [S08]

#### NW-3 — «Firewall Lockdown»؛ chase بدون AI تعقیب‌کننده

**ابعاد:** سه screenِ تمرین‌شده؛ trigger فقط بعد از ready check.

1. **می‌بیند:** نور قرمز از background عبور می‌کند؛ portها پیش از بسته‌شدن warning می‌دهند؛ حس دیده‌شدن.
2. **انجام می‌دهد:** از سه cellِ traversal آشنا می‌گذرد؛ درهای پشت سر فقط پس از عبور هر دو بسته می‌شوند.
3. **twist:** مسیر مستقیم با gate بسته است، اما cracked bypassِ از قبل نشان‌داده‌شده در کنار آن وجود دارد؛ نه maze جدید در حین chase.
4. **escape:** ورود به safe room صدای alarm را قطع می‌کند؛ latchِ completed مسیر برگشت دائمی را باز می‌کند.
**بلوک/هزینه/ایمنی:** gate، cracked، blinking + صوت/نور؛ medium. تهدید با collision path ساده ساخته می‌شود؛ E.M.M.I.-مانندِ pathfindingدار **high** و برای MVP رد است. door هیچ‌وقت براساس silhouette تأخیردار شریک بسته نشود.

### ۴.۵. THREAD TOWER

#### TT-1 — «Scheduler Shaft»؛ ریتم عمودی

**ابعاد:** ۲۴×۵۲، سه resting ledge.

1. **می‌بیند:** دو ستون moving platform با phase زمانی متفاوت؛ railهایشان کاملاً دیده می‌شوند؛ حس ماشین زنده.
2. **انجام می‌دهد:** روی solid pad cycle را می‌خواند و با یک jump به platform پهن می‌رود؛ wall jump جایگزینِ برگشت دارد.
3. **twist:** بالاتر، ترتیب ستون‌ها جابه‌جا می‌شود، اما هیچ platform تازه‌ای معرفی نمی‌شود؛ بازیکن schedule را بازخوانی می‌کند.
4. **conclude:** balcony به route پایین نگاه می‌کند؛ fan آرام‌تر و PRODUCTION نزدیک‌تر دیده می‌شود.
**بلوک/هزینه/ایمنی:** moving platform، solid، one-way؛ medium برای sync. phase تابع room clock مشترک است؛ local receipt time یا سرعت partner معیار نباشد. دو avatar روی یک platform جا شوند.

#### TT-2 — «Race Condition، اما قابل‌حل»؛ اولویت، نه رقابت reaction

**ابعاد:** ۴۸×۲۶ با دو route و central gate.

1. **می‌بیند:** دو خط به resource مرکزی می‌رسند؛ یکی کوتاه و سخت، یکی طولانی و آرام؛ حس احتمال تداخل.
2. **انجام می‌دهد:** اولین switch یک lane را claim می‌کند؛ lamp و gate واضح، نه تشخیص «کدام player یک frame زودتر بود».
3. **کشف:** route دوم blocked نمی‌شود؛ به solid bypass وصل است. نفر دیگر flag مکمل را جمع می‌کند؛ شکستِ race به شکست بازی بدل نمی‌شود.
4. **join:** هر دو flag gate بالا را باز می‌کنند و resource مشترک «settled» می‌شود؛ حس رفع conflict.
**بلوک/هزینه/ایمنی:** gates/switches، solid؛ medium. اگر این state logic زیاد است، نسخهٔ low: دو route کاملاً مستقل با یک خروج مشترک. هم‌زمانی input نه reward اضافی بدهد، نه softlock.

#### TT-3 — «Thread Join»؛ rendezvousِ معنادار

**ابعاد:** دو branchِ ۲۴×۲۶ به یک roomِ ۲۴×۱۳.

1. **می‌بیند:** partner از پنجرهٔ جدا روی ستون همسایه دیده می‌شود؛ تعامل فیزیکی ندارند؛ حس پیشرفت موازی.
2. **انجام می‌دهد:** هر route یک چالش آشنا دارد؛ branch A springs، branch B wall jump، و در پایین fallback امن.
3. **wait:** نفر زودرس روی balconyِ امن flag خود را ثبت می‌کند؛ gate منتظر completion flag دوم می‌ماند، نه حضور هم‌زمان روی pressure plate.
4. **payoff:** با join، background دو thread به یک کابل تبدیل می‌شود؛ route بعدی هر دو را دوباره کنار هم می‌گذارد.
**بلوک/هزینه/ایمنی:** spring، solid، one-way، gate؛ medium. بازیکن تنها بتواند از shortcut به branch دوم برود؛ disconnect باعث بن‌بست دائمی نشود. نقش دشوارتر قابل‌تعویض است.

### ۴.۶. GIT HISTORY

#### GH-1 — «Branch / Merge»؛ دو انتخاب، یک نتیجهٔ پایدار

**ابعاد:** hubِ ۲۴×۱۳ و دو branch کوتاه؛ phase فقط اگر unlocked باشد.

1. **می‌بیند:** خط مرکزی دو شاخه می‌شود؛ silhouette دو route روی دیوار hub کشیده شده است؛ حس تاریخ چندمسیره.
2. **انجام می‌دهد:** یکی traversal با crumbling، دیگری puzzle catchِ آرام؛ هر branch یک flagِ completed دارد.
3. **merge:** بازگشت به hub نشان می‌دهد هر دو خط به یک gate روشن وصل شده‌اند؛ کار قبلی با انتخاب branch دوم از بین نمی‌رود.
4. **conclude:** gate نهایی باز، routeهای قبلی برای explore باقی؛ نه نیاز به rewind واقعی کل جهان.
**بلوک/هزینه/ایمنی:** gate، switch، crumbling، thin wall اختیاری؛ medium. merge یک visual/state event است، نه حل network conflict واقعی. shared reward یک‌بار صادر شود.

#### GH-2 — «Revert Chamber»؛ reset قابل‌دیدن یک room

**ابعاد:** یک ۲۴×۱۳، دو layout از پیش‌ساختهٔ A/B.

1. **می‌بیند:** crumbling شکست‌خورده و gate بسته؛ یک switch با نماد برگشت کنار solid alcove؛ حس امکان ترمیم.
2. **انجام می‌دهد:** switch را فعال می‌کند؛ geometry به variant اولیه برمی‌گردد، بازیکنان روی safe pad می‌مانند.
3. **twist:** درمی‌یابد ترتیب عبور مهم است؛ بار دوم ابتدا gate را latch می‌کند، سپس crumbling را فرو می‌ریزد و route reward باز می‌شود.
4. **payoff:** از exit امن، ghost outline نسخهٔ قبلی دیده می‌شود؛ فهمِ history به عمل تبدیل می‌شود.
**بلوک/هزینه/ایمنی:** crumbling، gate، switch + variant reset؛ medium. collectibles، unlock و موقعیت player rollback نمی‌شوند. rewind فیزیکی واقعی، replay input و تاریخچهٔ کامل multiplayer **high** و توصیه نمی‌شود.

#### GH-3 — «Blame Gallery»؛ خاطرهٔ جهان، نه mechanic تازه

**ابعاد:** corridorِ ۴۸×۱۳ پس از GH-2، بی‌خطر.

1. **می‌بیند:** قاب‌های ثابت از roomهای SOURCE TREE، avalanche و memory leak؛ حس سفرِ طی‌شده.
2. **انجام می‌دهد:** روی solid راه می‌رود؛ در هر قاب فقط یک outline پیش/پس event دیده می‌شود؛ interact ضروری ندارد.
3. **کشف:** اولین dead code wall اکنون از زاویهٔ دیگر معلوم است؛ secret قبلی معنا می‌گیرد، نه اینکه reward اصلی اینجا پنهان باشد.
4. **آرامش:** دو terminal بی‌صدا با رنگ نارنجی Clawd و door بعدی؛ توقف به انتخاب player است.
**بلوک/هزینه/ایمنی:** solid، one-way و reuse tile/background؛ low/medium. قاب‌ها render زندهٔ roomهای دیگر نیستند؛ artwork/variant ثابت‌اند تا هزینه و network coupling کم بماند.

### ۴.۷. DEPENDENCY HELL — تماماً optional

#### DH-1 — «Cycle Detected»؛ loop با راه خروج روشن

**ابعاد:** سه roomِ ۲۴×۱۳ در یک loop، shortcut خروج همیشه قابل‌دسترسی.

1. **می‌بیند:** سه gate به شکل dependency triangle؛ همان palette و بلوک‌های DEPENDENCY DEPTHS سخت‌تر شده‌اند؛ هشدار بصریِ مسیر اختیاری.
2. **انجام می‌دهد:** هر room یک رشتهٔ کوتاهِ crumbling یا dash دارد؛ completion موضعی باقی می‌ماند.
3. **twist:** پس از room سوم، بازیکن از پشت یک dead code wall دوباره room اول را می‌بیند؛ loop واقعاً در فضا بسته شده است.
4. **payoff:** gate وسط cosmetic را آزاد می‌کند و exit مستقیم به hub باز می‌شود؛ مسیر اصلی بازی به آن وابسته نیست.
**بلوک/هزینه/ایمنی:** crumbling، cracked، gate، dead code؛ medium برای flags. دشواری از انتخاب route/کمبود استراحت است، نه window زیر ۱۰۰ms؛ partner می‌تواند بیرون منتظر بماند.

#### DH-2 — «CI Torture Suite»؛ سه تست سخت اما کوتاه

**ابعاد:** سه cell یک‌screen‌ای با checkpoint مستقل.

1. **می‌بیند:** سه test با iconِ dash، pogo، catch؛ goal هر cell در دید است؛ حس challenge انتخاب‌شده.
2. **انجام می‌دهد:** dash/cracked؛ سپس pogo روی enemy آشنای قابل‌احیا با ledge fallback؛ سپس catchِ ایستاده با lane باریک‌تر اما warning کافی.
3. **فشار:** زمان retry کوتاه و هر cell یک هدف؛ co-op می‌تواند برای مشاهده/راهنمایی کنار pad امن بایستد.
4. **payoff:** سه چراغ سبز ثابت و reward cosmetic؛ combat surpriseِ آخر ندارد.
**بلوک/هزینه/ایمنی:** cracked، spike، enemy موجود، switch؛ medium. enemyِ pogo target به‌دست شریک نباید برای همیشه حذف شود؛ اگر recovery ندارید، spring جای آن بگذارید. منطق short goal/retry از Super Meat Boy. [S06]

#### DH-3 — «Deprecated Heaven»؛ reward سکوت

**ابعاد:** ۲۴×۱۳، پایان optional route.

1. **می‌بیند:** پس از صدای failure، یک terminal قدیمی روشن مانده؛ نور گرم و هیچ hazard؛ حس رسیدن.
2. **انجام می‌دهد:** فقط یک jump آسان برای cosmetic یا agent appearance؛ هیچ توانایی ضروری داده نمی‌شود.
3. **کشف:** پشت شیشه، طرح اولین اتاق بازی دیده می‌شود؛ مسیری که اول ساده بود اکنون موضوع خاطره است.
4. **بازگشت:** gate دائمی به hub؛ partner می‌تواند reward را هم دریافت کند، بی‌نیاز از replay کل gauntlet.
**بلوک/هزینه/ایمنی:** solid، gate و art محدود؛ low. از quiet payoffِ Path of Pain الهام دارد، نه از punishment دو Kingsmould آخر. [S10]

### ۴.۸. PRODUCTION

#### PR-1 — «Deploy Deadline»؛ فشار مرحله‌ای، نه timeout کور

**ابعاد:** corridorِ ۹۶×۱۳ با چهار cell و سه service alcove.

1. **می‌بیند:** heat/fire در background، route تمرین‌شده در foreground؛ alarm بعد از ready check؛ حس فوریت.
2. **انجام می‌دهد:** wall jump → dash/cracked → catch روی solid → خروج؛ فقط مهارت‌های آموخته‌شده، بدون ability تازه.
3. **فشار:** heat front در هر cell پس از warning advance می‌کند؛ alcove مرز segment و checkpoint است. یک deadline کلیِ کم‌مهلت لازم نیست.
4. **رهایی:** door نهایی به فضای خنک؛ alarm قطع و کوتاهیِ سفر در نمای پشت سر آشکار می‌شود.
**بلوک/هزینه/ایمنی:** rising liquid با artِ heat، gates، cracked، solid؛ medium. skin نارنجی فقط با علامت hazard روشن؛ body-collision آتش جدید فرض نشده. سرعت از touch path تعیین شود؛ phase/grapple فقط اگر مسیر قبلی آموزش داده باشد.

#### PR-2 — «The Build Breaks»؛ boss arrival از جهان

**ابعاد:** ante-room و arenaِ ۴۸×۱۳؛ boss از قبل در scope بازی باشد.

1. **می‌بیند:** fan عظیمِ background که در vistaهای قبلی دیده بود آرام می‌ایستد؛ نور emergency، سکوت کوتاه؛ anticipation.
2. **انجام می‌دهد:** روی کف solid جلو می‌رود؛ gate فقط بعد از حضور/آمادگی هر دو می‌بندد، input در reveal مصادره نمی‌شود.
3. **arrival:** silhouette boss پشت heatsink، سپس ورود به foreground؛ نخستین attack با wind-up کامل و همان زبان catch آشنا.
4. **پس از نبرد:** یک gate ثابت باز، room بعدی آرام؛ boss arrival هر retry کوتاه یا skip‌پذیر است.
**بلوک/هزینه/ایمنی:** solid، gate، lighting/audio؛ medium برای presentation؛ boss جدید high و هزینه‌اش جداست. projectile storm، platform نابودشونده و tutorial تازه را به اولین phase اضافه نکنید.

#### PR-3 — «Computer Sleeps Again»؛ پایان جهان واکنش‌پذیر

**ابعاد:** دو room آرام یا یک corridorِ ۴۸×۱۳.

1. **می‌بیند:** همان branchهای SOURCE TREE در قاب‌ها؛ قرمزهای failure خاموش و چند چراغ نرم باقی؛ حس ترمیم.
2. **انجام می‌دهد:** بدون timer و combat، یک مسیر کوتاه solid را به پنجرهٔ آخر طی می‌کند؛ دو Clawd کنار هم دیده می‌شوند.
3. **پاسخ:** flood state و gateهای completed در artwork ثابت منعکس‌اند؛ آخرین terminal با یک pulse خاموش می‌شود.
4. **سکون:** موسیقی کامل می‌شود، player می‌تواند بماند یا به hubِ postgame برگردد؛ پایان نیازمند دو input هم‌زمان نیست.
**بلوک/هزینه/ایمنی:** solid، gate و reuse art؛ medium. اگر world reset برای postgame ندارید، این نمایش noninteractiveِ variantها باشد؛ reset ناگهانی همهٔ roomهای فعال ممنوع. منطق payoff از روایت کم‌متن Super Metroid. [S14]

### ۴.۹. چه چیزی سال‌ها در حافظه می‌ماند؟ شواهد و محدودیت

این بخش **نمونهٔ کیفیِ گفتگوهای عمومی** است، نه survey نمایندهٔ همهٔ بازیکنان؛ رأی‌ها، نرخ رضایت یا «محبوب‌ترین room» محاسبه نشده‌اند.

| لحظه | شواهد ادامهٔ گفتگو | برداشت قابل‌استفاده برای CLAWD |
| --- | --- | --- |
| Ginso Tree escape | excerpt یک thread دربارهٔ سختی آن را memorable می‌نامد؛ تاریخ دقیق و context کامل Reddit unverified است. threadِ Steam در ۲۰۱۶ واکنش مخالف و ترک بازی را ثبت می‌کند. [S23–S24] | یک تغییر جهانی + موسیقی + کاربرد پیوستهٔ مهارت، خاطره می‌سازد؛ difficulty spike می‌تواند همان خاطره را منفی کند. |
| Path of Pain | excerpt ایندکس‌شدهٔ thread، با تاریخ دقیق unverified: بازیکن بیش از یک سال بعد هنوز صدای music/saws را به خاطر دارد؛ load کامل Reddit با 403 ممکن نشد، بنابراین متن/زمینهٔ کامل **unverified**. [S25] | sound identity با effort طولانی پیوند می‌خورد؛ CLAWD باید هزینهٔ retry را کم کند، نه صرفاً رنج را تقلید کند. |
| Maridia glass tube | دو excerpt دربارهٔ خشم از tube و کشف راه Maridia در نخستین بازی‌اند؛ متن/تاریخ کامل unverified است. قدمت Super Metroid و ویژگی room جداگانه در S12 مستندند. [S26–S27] | room به‌یادماندنی می‌تواند «پاسخ فیزیکی غافلگیرکننده» باشد؛ به‌یادماندن، معادل خوانایی خوب نیست. |
| Castle Rock | دو thread قدیمی در excerptها آن را از لذت‌بخش‌ترین levelها توصیف می‌کنند؛ تاریخ‌های دقیق unverified هستند؛ منبع مکانیکی جدا، syncِ music و action را تأیید می‌کند. [S17، S28–S29] | چند فعل ساده با cadence و soundِ یکتا بهتر از هفت hazard متفاوت به خاطر می‌ماند. این نمونهٔ تاریخی است، نه اثبات گفتگوی مداوم تا ۲۰۲۶. |
| Moss Grotto / Citadel در Silksong | منبع اولیهٔ ۲۰۲۵ برای طراحی وجود دارد؛ هنوز برای «خاطرهٔ چندین‌ساله» شواهد کافی نیست. [S18] | درس جهان‌سازی معتبر است؛ ادعای nostalgia بلندمدت برای Silksong در این گزارش مطرح نمی‌شود. |

**فرمول کاربردی، نه قانون علمی:** مکان آشنا + یک تغییر تعیین‌کننده + امضای صوتی/بصری + نتیجهٔ قابل‌دیدن. برای CLAWD، HP-2، DD-1 و PR-3 این چهار جزء را بدون enemy AI تازه فراهم می‌کنند.

## ۵. Pacing — zoneِ ۱۸room‌ای، با adaptation برای ۱۵–۲۰ room

**تعریف:** tensionِ ۰ یعنی امکان توقف واقعی؛ ۱ جهت‌یابی/حرکت آسان؛ ۲ challenge منفرد؛ ۳ ترکیب آشنا؛ ۴ climax. این عددها rating طراحی‌اند، نه دادهٔ اندازه‌گیری‌شده یا توصیهٔ علمی دربارهٔ دقیقه‌های play. Bénard از peaks و relaxing breaks و Nintendo از محدودکردن تهدید E.M.M.I. می‌گویند؛ هیچ‌کدام نسبت جهانیِ ثابت ارائه نمی‌کنند. [S08، S13]

| room | نقش | فعل غالب و محتوا | tension | قرارداد استراحت / retry |
| --- | --- | --- | --- | --- |
| 01 | arrival / vista | دیدن theme و مقصد؛ زمین solid | 0 | هیچ timer یا enemy نیست |
| 02 | teach | یک بلوک تازه، کف گیرنده | 1 | failure بی‌خطر، نتیجه در دید |
| 03 | test | همان قانون، stakes کم | 2 | retry از همین room |
| 04 | variation | تغییر یک متغیر | 2 | stop pad پیش از obstacle |
| 05 | breather / fork | route اصلی و secret teaser | 0 | امکان map و گفتگوی دو نفر |
| 06 | combat teach/test | enemy آشنا روی کف solid | 2 | traversal دقیق حذف شود |
| 07 | traversal development | room دوscreen‌ای؛ دو cell | 2 | solid بین cellها |
| 08 | puzzle box | switch و gate در دید | 1 | بدون pressure زمانی؛ reset واضح |
| 09 | twist | ترکیب دو قانون آشنا | 3 | retry موضعی؛ هیچ enemy تازه |
| 10 | quiet reward / vista | دیدن نتیجه و مقصد بعدی | 0 | room واقعاً امن |
| 11 | acquisition یا route change | unlock امن؛ اگر unlock نداریم shortcut | 1 | یک کاربرد ساده، بدون spike |
| 12 | confirmation test | کاربرد توانایی تازه | 2 | کف گیرنده / checkpoint نزدیک |
| 13 | mixed room | traversal اول، combat روی shelf دوم | 3 | بین دو وظیفه solid کافی |
| 14 | rendezvous / pre-climax | خواندن مسیر escape یا آماده‌شدن arena | 0 | ready check، قطع alarm در انتظار |
| 15 | signature climax | escape یا boss؛ نه هر دو پشت‌سرهم | 4 | checkpoint segmentها یا arena |
| 16 | immediate decompression | اتاق خشک/روشن/بی‌دشمن | 0 | نه combat ambush، نه jump سخت |
| 17 | changed world / shortcut | route جدید در مکان آشنا | 1 | backtrack کوتاه و امن |
| 18 | exit / future teaser | silhouette zone بعد، ring/phase branch | 0 | player می‌تواند session را اینجا قطع کند |

**برای ۱۵room:** 03+04 را ترکیب، 06 را در 13 با بخش combatِ مجزا ادغام، و 17+18 را ترکیب کنید؛ roomهای 05، 10، 14 و 16 را برای صرفه‌جویی حذف نکنید. **برای ۲۰room:** یک secret room و یک challenge اختیاری کنار 05/10 اضافه کنید، نه دو roomِ شدت ۳ روی critical path.

**سه مقیاس rhythm:**

- **درون room:** مشاهده → عمل → landing → مشاهدهٔ بعدی. حتی در gauntlet، «landing برای خواندن» لازم است؛ هر solid الزاماً checkpoint نیست.
- **میان roomها:** tension غالب را عوض کنید؛ combat شدید پس از traversal شدید، استراحت محسوب نمی‌شود. تغییر وظیفه با کاهش بار یکی نیست.
- **در zone:** یک climax اصلی، نتیجهٔ جهانی، سپس relief. DEPENDENCY HELL می‌تواند سلسلهٔ peakهای اختیاری داشته باشد، ولی میان آن‌ها exit/retry نزدیک بماند.

**ترکیب combat/traversal/puzzle در room واقعی:** screen اول jumping روی one-way؛ shelfِ solidِ حداقل ۶tile‌ای برای combatِ enemy آشنا؛ پس از پایان combat، catch switch بدون دشمن فعال. برای climax بعدی می‌توان catch را روی platform پهن گذاشت، اما enemy تازه، moving platform باریک و gate timer را با هم اضافه نکنید. اگر بازیکن از مبارزه جان سالم به در برده، اجازه بدهید نتیجهٔ switch را ببیند؛ gate بیرون camera تجربه را مبهم می‌کند.

**اتاق‌های بسیار بزرگ:** ۲۰۰tile عرض حدود ۸٫۳ عرض screen است؛ ۸۰tile ارتفاع حدود ۵٫۹ ارتفاع screen با viewportِ ۱۳٫۵tile‌ای. اندازهٔ فایل room واحد pacing نیست. یک corridorِ ۲۰۰tile‌ای را به ۶–۸ cellِ خوانا و یک یا دو rest node تقسیم کنید؛ shaftِ ۸۰tile‌ای به segmentهای ascent با camera look-ahead و ledgeهای توقف. این تعدادها blockout پیشنهادی‌اند؛ loading یک room بزرگ نباید به معنی retry کل آن باشد.

**تست zone:** مجموع زمان اولین عبور، زمان توقف انتخابی، تعداد retry، انتظار شریک و علت خروج از session را ثبت کنید. اگر وقت zone عمدتاً در تکرار یک escape مصرف می‌شود، با میانگین tension توجیهش نکنید؛ checkpoint یا هندسه را تغییر دهید.

## ۶. Co-op و phone — قراردادهای طراحی، نه حدس دربارهٔ netcode

### ۶.۱. سه نوع تعامل را جدا کنید

| تعامل | تصمیم برای CLAWD | نمونهٔ عملی |
| --- | --- | --- |
| حرکت خود player روی geometry | باید responsive و تا حد ممکن مستقل از نمایش partner باشد؛ روش prediction/authority نیازمند بررسی build است | jump، dash و landing روی ledge ثابت |
| تغییر state جهان | shared، پایدار و دارای ترتیب مشخص؛ پیام تکراری نباید toggle دوم ایجاد کند | catch switch یک gate را از closed به open می‌برد و همانجا می‌ماند |
| تماس لحظه‌ای با شریک | روی critical path حذف شود، چون avatar حدود ۱۰۰–۲۵۰ms دیر دیده می‌شود | partner platform، midair catch relay، body-block rescue ممنوع |

**نکتهٔ latency:** معلوم نیست ۵۰–۲۵۰msِ اعلام‌شده RTT است یا one-way؛ جداگانه اندازه بگیرید. این مقدار را خودکار به هر jump buffer اضافه نکنید. latencyِ دیدن partner، latencyِ input خود بازیکن و latencyِ تأیید state سه مسئلهٔ متفاوت‌اند.

### ۶.۲. طراحی‌های توصیه‌شده

- **Independent execution, shared progress:** هر نفر jump/parry خودش را انجام دهد؛ نتیجهٔ gate و reward برای هر دو ثبت شود. co-op از تقسیم کار و کشف می‌آید، نه وابستگی به colliderِ شریک.
- **دو role قابل‌تعویض:** scout مسیر بالا، solver در laneِ solid؛ بعداً roleها عوض شوند. Android همیشه «نگه‌دارندهٔ دکمه» نباشد.
- **Latch به جای hold:** A و B دو flagِ پایدار؛ درهای chain به جای plateِ هم‌زمان. اگر تک‌نفره/قطع اتصال باید recover شود، یک route برای انجام هر دو task فراهم کنید.
- **آمادگی قبل از commitment:** arena و escape در ready pad مشترک شروع شوند؛ player دوردست می‌تواند decline کند. animation شروع برای هر دو از یک timestamp/مرحلهٔ تأییدشده آغاز شود.
- **توقفگاه برای دو نفر:** entry/exit pad از نظر برخورد، حدود چهارtile یا بیشتر؛ ظرفیت واقعی با collider تست شود. body blocking و friendly fire در traversal lane ترجیحاً غیرفعال.
- **Crumbling با سیاست واضح:** یا respawnِ قابل‌پیش‌بینی، یا مسیر fallback ثابت. نفر اول نباید bridge یگانهٔ نفر دوم را مصرف کند.
- **Pogo target غیرمصرفی:** وقتی enemy ابزار traversal ضروری است، کشتن آن به‌دست شریک نباید softlock بسازد؛ respawn موضعی یا spring fallback بدهید. برای MVP، spring معمولاً ساده‌تر است.
- **Cross-room state بدون مجازات کور:** بازکردن gate/کم‌کردن flood امن‌تر از حذف floor یا بالا‌بردن liquid در roomِ شریک است. roomهای اشغال‌شده را پیش از تغییر geometry بررسی کنید.
- **اعلام پیشرفت، نه مختصات دقیق:** روی map نشان کوچک «partner در این branch» و وضعیت flagها؛ ping متنی/نمادین اختیاری. remote avatar ابزار زمان‌بندی hazard نباشد.
- **محدودهٔ simulation مستقل از camera:** roomِ شریکِ حاضر در جهان به‌دلیل off-screen بودن در PC freeze نشود؛ اگر این پشتیبانی نیست، puzzleِ دوroom‌ای را تا اصلاح engine اجرا نکنید.

### ۶.۳. touch و خوانایی در ۳۸۴×۲۱۶

**ارتفاع viewport:** ۲۱۶÷۱۶ = ۱۳٫۵tile؛ layout روی ۱۳ ردیف کامل plan شود، نیم‌ردیف آخر برای اطلاعات critical فرض نشود. یک roomِ ۱۳tile‌ای ۲۰۸px ارتفاع دارد، نه تمام ۲۱۶px.

- **شناخت قبل از دقت:** route اصلی ابتدا پرش با اختلاف ارتفاع حداکثر حدود ۳tile، landingِ ۳tile‌ای یا پهن‌تر، dash عمدتاً cardinal. ۳٫۵tile سقف اسمی را به همهٔ ledgeها تبدیل نکنید؛ collider و variable jump margin لازم‌اند.
- **Dashِ هشت‌جهته:** diagonal را روی optional reward route یا lane پهن قرار دهید. اجبار به اصلاح سریع زاویهٔ ۴۵° وسط هوا روی touch را به main route ندهید. sector snapping در کنترل، تغییر کد است و باید جدا آزموده شود.
- **Wall jump:** wall segmentهای ممتد و بدون گوشهٔ ریز؛ target ledge دیده شود. از zigzagهایی که نیازمند جهت‌عوض‌کردن سریع بین دو دیوار باریک‌اند، در مسیر اصلی پرهیز کنید.
- **Grapple:** ring hit target از spriteِ کوچک سخاوتمندانه‌تر باشد؛ نزدیک‌ترین targetِ معتبر قابل‌پیش‌بینی. جابه‌جایی target پشت دوربین یا نیاز به tap دقیق روی ring کوچک ممنوع. auto-target/reticle تغییر controller است، نه layout-only.
- **Parry:** اولین catch روی solid و مقابل projectileِ کندِ تک‌جهت. برای prototype، telegraph حدود ۰٫۷–۱ثانیه و catch window حدود ۱۸۰–۳۰۰ms را بررسی کنید؛ این‌ها **unverified به‌عنوان مقادیر مناسب CLAWD** و صرفاً فرضیه‌اند. اگر input منتظر round trip است، بزرگ‌کردن window به‌تنهایی درمان نیست؛ local responsiveness/validation باید بررسی شود.
- **Forgiveness در controller:** coyote time، jump buffer و corner correction مبنای مستند Celeste‌اند؛ مقادیر آن بازی را به CLAWD کپی نکنید. شروع آزمایشِ buffer/coyote حدود ۱۰۰–۱۵۰ms می‌تواند معقول باشد، ولی frame-rate، jump curve و قابلیت‌های فعلی باید بررسی شوند. [S04]
- **دو انگشت کافی:** sequence اصلی نباید هم‌زمان aim دقیق، direction، jump، dash، attack و summon بخواهد. عامل دشواری را عوض کنید، نه اینکه button chord بیشتری اضافه کنید.
- **finger occlusion واقعی:** با screenshot روی Android و controls overlay، گوشه‌های پوشانده‌شده را اندازه بگیرید. spikes کوچک، switch ضروری یا تنها floor بعدی زیر thumb pad نباشد. کنترل‌ها در فضای CSS/device scale سنجیده شوند، نه فقط pixelهای viewport.
- **زبان تصویری پایدار:** solid لبهٔ پیوسته؛ one-way سطح بالایی واضح؛ cracked ترک؛ crumble animationِ فروپاشی؛ blink outlineِ وضعیت بعدی؛ phase materialِ باریک متفاوت. color تنها سرنخ نباشد. نور/particles روی colliderِ قابل‌عبور غلبه نکنند.
- **camera:** روی shaft پیش از jump مقصد بالاتر را نشان دهید؛ هنگام falling کف بعدی را. zoom-out تا حدی که avatar روی phone ناخوانا شود راه‌حل اتاق بزرگ نیست. camera هر نفر از حرکت شریک تبعیت نکند؛ این انتخاب باید با معماری واقعی camera بررسی شود.

### ۶.۴. خطرهای Godot web که روی room design اثر دارند

مستندات Godot می‌گویند browser low-level networking ندارد و web export از HTTP، WebSocket client و WebRTC پشتیبانی می‌کند؛ همچنین background tab ممکن است processing را pause کند. audio ممکن است به gesture آغازین نیاز داشته باشد و تنظیمات playback/thread بر latency اثر می‌گذارند. این‌ها **ویژگی browser/export** هستند، نه تأیید اینکه CLAWD از transport خاصی استفاده می‌کند. صفحهٔ stable ممکن است با نسخهٔ بعدی تغییر کند؛ export target واقعی تیم باید pin شود. [S30]

**پیامد اجرایی:** beatِ موسیقی collision authority نباشد؛ هشدار بصری هم وجود داشته باشد. بعد از tab switch یا screen lock، player در safe rendezvous یا آخرین checkpoint معتبر resume کند، نه زیر rising liquidِ ادامه‌یافته. roomهای کم‌افکت را روی Androidِ متوسط تست کنید؛ دشمن بیشتر برای «حس climax» می‌تواند frame pacing را خراب کند، حتی اگر شبکه خوب باشد.

### ۶.۵. ماتریس QA پیش از قبول room

| سناریو | چه چیزی را عمداً امتحان کنیم؟ | شرط رد |
| --- | --- | --- |
| PC + touch، تأخیر کم | اولین تلاش بدون توضیح | مسیر اصلی فقط با اشارهٔ طراح فهمیده شود |
| تأخیرهای ۵۰ / ۱۵۰ / ۲۵۰ms با معنای RTT مشخص | catch، gate، moving platform | نتیجهٔ محلی و shared collision ناسازگار و کشنده شود |
| jitter و packet lossِ شبیه‌سازی‌شده | دریافت تکراری/دیرِ trigger، rejoin | gate دوباره بسته شود یا reward دو بار صادر شود |
| دو player در یک room | هر دو روی spring/platform، killِ pogo target | مصرف ابزار traversal برای نفر دوم |
| دو player در roomهای متفاوت | flood change و switch دوردست | تغییر بی‌هشدار زیر پای شریک یا freezeِ room |
| خروج از tab / phone lock | بازگشت پس از وقفه | resume اجباری در وضعیت مرگِ اجتناب‌ناپذیر |
| reset / disconnect | A حل شده، B حل نشده | بن‌بستِ دائمی یا resetِ progressِ بی‌ربط |
| ورود از چهار door معتبر | ورود معکوس با abilities فعلی | افتادن فوری، spawn داخل collider یا گیرکردن |

این جدول پروتکل پیشنهادی است؛ هیچ‌یک از این تست‌ها در این پژوهش روی CLAWD اجرا نشده است.

## ۷. Anti-patterns — اشتباه، نمونه و اصلاح

| اشتباه | نمونهٔ مستند یا failure mode مشخص | اصلاح CLAWD |
| --- | --- | --- |
| چهارگام را در هر screen زورکی جا دادن | Hayashida دربارهٔ یک stage سخن می‌گوید، نه الزام چهارگام در ۲۴tile؛ Team Cherry رویکرد world-first دارد. [S01، S18] | teach و twist را در roomهای مجاور پخش کنید؛ recipe را با واحد مناسب اجرا کنید |
| «تقریباً ممکن» جلوه‌دادن راه غلط | Thorson از مسیری می‌گوید که باید آشکارا ناممکن می‌بود؛ بازیکنان در راه غلط وقت تلف می‌کردند. [S03] | برای double-jump teaser اختلاف ارتفاع واضح؛ main route روشن |
| tutorialِ lethal پیش از فهم | شفت wall jumpِ Super Metroid بازیکن را تا آموختن تکنیک محدود می‌کند؛ تحلیل منبع این harshness را یادآور می‌شود. [S12] | کف گیرنده و exit/fallback؛ mimic موجود بدون trapِ طولانی |
| دام اصلی با سرنخ ضعیف | Maridia tube برای برخی کشف عالی و برای برخی سال‌ها موضوع frustration است. [S12، S26–S27] | روی progression اجباری دو cue: ترک material + نمونهٔ شکسته/feedbackِ ضربه |
| climax اجباریِ جهش‌دار | واکنش‌های متضاد به Ginso Tree، از هیجان تا ترک بازی. [S23–S24] | preview مسیر، checkpoint segment، پنجرهٔ touch سخاوتمندانه؛ حالت ساده‌تر اختیاری |
| surprise combat پس از exhaustion | دو Kingsmould پایان Path of Pain نمونهٔ تنش اضافه پس از platforming بسیار سخت است؛ اینکه بد است ارزیابی این گزارش است، نه نظر رسمی سازنده. [S10] | DEPENDENCY HELL با quiet payoff تمام شود؛ main escape مستقیم breather داشته باشد |
| کپی narrow rescueِ E.M.M.I. | Nintendo counterِ capture را عمداً تقریباً ناممکن توصیف می‌کند. [S08] | rescue optional و بخشنده، یا حذف؛ survivabilityِ touch به parry فوق‌باریک وابسته نباشد |
| collapseِ بی‌راه برگشت | McEntee مشکل one-way collapse در metroidvania را صریحاً شرح می‌دهد. [S07] | route پایین solid/shortcut؛ شریک جامانده و backtrack را در state نهایی حل کنید |
| beat موسیقی = frame مشترک | Castle Rock طراحی sync دارد، اما از آن تضمین latencyِ آنلاین به دست نمی‌آید. [S17] | ساعت hazard جدا از music؛ warning بصری و safe alcove |
| random room بدون purpose | Bénard می‌گوید نسخهٔ procedural اولیه chaotic و inconsistent بود. [S13] | ابتدا graph دستی و templateِ دارای role/door contract؛ بعد variation محدود |
| enemy را هم opponent و هم کلید مصرفی قرار دادن | CLAWD: شریک enemyِ لازم برای pogo/catch را می‌کشد و gate بسته می‌ماند | respawn/replacement، یا spring و emitter recoverable؛ QAِ softlock الزامی |
| rest جعلی | CLAWD: bench/vista با spawnِ hidden enemy یا liquid timer | یک دستهٔ room با تضمین سکون؛ player به rest trust کند |
| secret بدون clue یا reward ضروری | CLAWD: dead code اجباری با texture عین solid | main path clue چندگانه؛ fake wall فقط optional مگر آموزش روشن قبلی |
| دوclock هم‌زمانِ بدون توقف | CLAWD: crumble زیر پا + blinking landing + timed gate | یکی را deterministic/static کنید، stop pad بدهید، یا challenge را optional کنید |
| حل تک‌نفرهٔ co-op که شریک را بیکار می‌کند | CLAWD: PC همهٔ catchها را تمام می‌کند و touch فقط تماشا می‌کند | branchهای موازی، role rotation و فرصت تمرین؛ completion مشترک با execution مستقل |
| scope creep با اسم برنامه‌نویسی | «Git» را به rewind کامل netcode و «Network» را به E.M.M.I. AI تبدیل کردن | دو variantِ room و latch؛ theme را با هندسه و state بیان کنید، نه شبیه‌سازی کامل مفهوم |

## ۸. Top 15 recommendations — رتبه‌بندی impact در برابر cost

**روش رتبه‌بندی:** قضاوت کیفی بر اساس جلوگیری از failure/softlock، گسترهٔ استفاده در همهٔ zoneها و هزینهٔ implementation+QA؛ هیچ score عددی، نسبت ROI یا برآورد نفرروزِ ساختگی استفاده نشده است. پیش‌نیازهای engine، حتی اگر cost بالاتر دارند، از polish نمایشی جلوترند.

| رتبه | اقدام دقیق | impact | cost | دلیل اولویت / خروجی قابل‌قبول |
| --- | --- | --- | --- | --- |
| 1 | room reset و checkpoint موضعی برای هر skill cell | بسیار زیاد | medium | پایهٔ difficulty منصفانه؛ مرگ room جاری، progress بی‌ربط را حذف نکند |
| 2 | قرارداد co-op: latched gates، idempotent flags و recoveryِ disconnect | بسیار زیاد | medium | جلوگیری از softlock در همهٔ zoneها؛ ترتیب A/B هر دو کار کند |
| 3 | حرکت و catchِ responsive روی touch؛ auditِ authority/prediction | بسیار زیاد | medium/high، بسته به کد | اگر input خود player منتظر شبکه باشد، room polish مسئله را حل نمی‌کند |
| 4 | safe pad، visible landing و screenshot-read test برای همهٔ roomها | زیاد | low | ارزان‌ترین اصلاح خوانایی؛ route و خطر اول در سه ثانیه قابل‌توصیف باشد |
| 5 | هر mechanic یک teach roomِ بی‌خطر + یک test room | زیاد | low | از مرگ‌آموزی جلوگیری؛ player قانون را با عمل نشان دهد |
| 6 | critical path با landing پهن و cardinal dash؛ diagonal سخت optional | زیاد | low | هزینهٔ touch adaptation را در هندسه کم می‌کند |
| 7 | targetهای traversal غیرمصرفی و fallback برای crumbling/pogo | زیاد | low/medium | نفر اول ابزار نفر دوم را نابود نکند؛ تست عمدی kill/reset پاس شود |
| 8 | یک breather واقعی بعد از هر peak و قبل از climax | زیاد | low | pacing بدون feature جدید؛ انتظار partner هم معنادار می‌شود |
| 9 | graphِ zone و libraryِ template با role و door contract | زیاد | medium ابتدا، low در reuse | به AI agents قرارداد مشترک می‌دهد؛ room تصادفیِ بی‌هدف کم می‌شود |
| 10 | preview و ready check برای HP-1 / PR-1 | زیاد | medium | escape به مهارت آشنا فشار می‌آورد، نه به حفظ blind layout |
| 11 | permanent shortcut پس از loop یا collapse | زیاد | low/medium | backtracking و جدایی partner کم می‌شود |
| 12 | buildِ vertical slice با ST-3، DD-1 و HP-2 پیش از ۸zone | زیاد | medium | آموزش، spectacle و changed-world با بلوک موجود آزمایش می‌شوند؛ scope کنترل می‌شود |
| 13 | visual grammarِ distinct برای cracked/crumble/phase/blink + audio cue | زیاد | low/medium | خوانایی ۳۸۴×۲۱۶؛ معنا فقط به رنگ یا صدا وابسته نیست |
| 14 | map markerِ ability gate، نه screenshot system کامل در MVP | متوسط/زیاد | low/medium | درس Memory Shards با هزینهٔ کمتر؛ revisit بدون حافظه‌سپاری اجباری |
| 15 | vista و quiet payoffِ اختصاصی با reuse art در هر zone | متوسط | low/medium | خاطره و هویت بدون AI تازه؛ سقف یک background hero اختصاصی برای هر zone |

**فعلاً نسازید:** تعقیب‌کنندهٔ pathfindingدار E.M.M.I.-مانند، physical rewind multiplayer، ricochet puzzle وابسته به parry شریک در هوا، و music-levelِ اجباریِ با window باریک. فقط پس از vertical sliceِ پایدار و شواهد playtest هزینهٔ high این‌ها قابل‌دفاع می‌شود.

**معیار تحویل room به تیم:** کارت objective، tile layout، camera plan، door/ability contracts، دو stateِ مهم، reset policy، co-op fallback، touch margin و علت هر hazard باید همراه room باشد. «AI agents کد را می‌نویسند» جای validationِ برخورد و blind playtest را نمی‌گیرد.

## ۹. Sources — لینک، نوع و دامنهٔ اعتبار

تمام منابع زیر در ۱۱ اکتبر ۲۰۲۶ برای این پژوهش بررسی شدند؛ «بررسی» ممکن است خواندن متن کامل/بخش مرتبط یا فقط excerpt ایندکس‌شده باشد و در هر مورد مشخص شده است. منابع اولیه برای **قصد و فرایند طراحی** وزن بیشتر دارند؛ wiki/walkthrough برای **ویژگی room** استفاده شده‌اند؛ نظر بازیکن فقط تجربهٔ همان فرد را نشان می‌دهد.

### منابع اولیه و تحلیل‌های نزدیک به سازنده

- **S01 — [The Structure of Fun: Learning from Super Mario 3D Land’s Director](https://www.gamedeveloper.com/design/the-structure-of-fun-learning-from-i-super-mario-3d-land-i-s-director)** — Christian Nutt، مصاحبه با Koichi Hayashida، ۱۳ آوریل ۲۰۱۲؛ **primary interview**. بخش مرتبط خوانده شد: core concept، kishōtenketsu، introduce/develop/twist/conclude. مبنای نسبت ثابت pacing یا قانون همهٔ genres نیست.
- **S02 — [Super Mario 3D World’s 4 Step Level Design — GMTK](https://www.youtube.com/watch?v=dBmIkEvEBtA&xstg=CAMSBhUDze3xHw%3D%3D)** — Mark Brown؛ **secondary design analysis**، شناسایی از search. چهارگام از S01 مستقلاً تأیید شده؛ ادعای room جزئیِ دیده‌نشده به این ویدیو نسبت داده نشده است.
- **S03 — [Level Design Workshop: Designing Celeste — GDC](https://www.youtube.com/watch?v=4RlpMhBKNr0)**؛ [صفحهٔ GDC Vault](https://www.gdcvault.com/play/1024307/Level-Design-Workshop-Designing-Celeste) — Maddy Thorson، talkِ GDC 2017، انتشار ویدیو ۲۰۱۸؛ **primary talk**. transcriptِ بخش مرتبط در extraction، به‌صورت ترجمه‌شده، خوانده شد؛ room length، safety، مسیر غلط، teaching detour و Old Site chase. نام تاریخی روی صفحهٔ Vault با نام فعلی سازنده یکسان نیست.
- **S04 — [Celeste & Forgiveness](https://www.maddymakesgames.com/articles/celeste_and_forgiveness/index.html)** — Maddy Thorson؛ **primary developer article**، متن کامل خوانده شد. coyote، buffer، corner correction و forgiveness؛ اعداد CLAWD از این مقاله استخراج نشده‌اند.
- **S06 — [Postmortem: Team Meat’s Super Meat Boy](https://www.gamedeveloper.com/audio/postmortem-team-meat-s-i-super-meat-boy-i-)** — Team Meat، ۱۴ آوریل ۲۰۱۱؛ **primary postmortem**، بخش مرتبط خوانده شد. short levels، goal in sight، respawn و editor؛ [GDC Meatmortem](https://www.gdcvault.com/play/1014684/Team-Meat-Presents-SUPER-MEAT) منبع تکمیلیِ شناسایی‌شده است، نه transcriptِ مبنای نقل جزئی.
- **S07 — [Making Ori and The Will of the Wisps’ Best Level — GMTK / On the Level](https://www.youtube.com/watch?v=gIdHTL18kTU)** — Mark Brown با level designerِ Moon Studios، Chris McEntee؛ **primary interview داخل تحلیل**. بخش transcriptِ Burrow، blockout، collapsing sand، backtracking و sandworm خوانده شد. کلمهٔ «Best» عنوان ویدیو است، نه رتبه‌بندی این پژوهش.
- **S08 — [Metroid Dread Report Vol. 2: Researching the E.M.M.I.](https://metroid.nintendo.com/dread/news/metroid-dread-report-vol-2)** — Nintendo / development team، ۲۰۲۱؛ **primary official report**، متن مرتبط در search قابل‌خواندن بود. modes، zone boundaries، checkpoint، narrow counter و جلوگیری از sustained tension.
- **S09 — [White Palace, Backer NPC, Hollow Knight at GDC!](https://www.teamcherry.com.au/blog/post-easter-update-white-palace-backer-npc-hollow-knight-at-gdc)** — Team Cherry؛ **primary development update**، excerpt خوانده شد. معرفی trap-filled late-game area؛ سند پیش از انتشار است، جزئیات نهایی از S10 گرفته شده‌اند.
- **S13 — [The Level Design of Dead Cells: a hybrid approach](https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach)** — Sébastien Bénard، lead designer؛ بازنشر ۱۵ فوریهٔ ۲۰۲۰ از مقالهٔ قبلی؛ **primary developer article**، متن کامل خوانده شد. handmade chunks، biome-specific graph، enemy constraints، peaks/breaks. الگوریتم همهٔ نسخه‌های بعدی فرض نشده است.
- **S14 — [Super Metroid Staff Interview](https://metroiddatabase.com/old_site/sm/interview.php)** — مصاحبهٔ staff در راهنمای رسمی ژاپنی، ترجمهٔ Metroid Database؛ **primary در ترجمهٔ ثانویه**، بخش مرتبط خوانده شد. روایت کم‌متن، صدا و تغییر ending با نجات animals؛ ترجمه با اصل ژاپنی در این پژوهش مقابله نشده است.
- **S16 — [How Memory Shards help players find secrets in Prince of Persia: The Lost Crown](https://www.gamedeveloper.com/design/how-memory-shards-help-players-find-secrets-in-prince-of-persia-the-lost-crown)** — Bryant Francis با Rémi Boutin، ۳۱ ژانویهٔ ۲۰۲۴؛ **primary interview**، متن خوانده شد. cognitive load، screenshot map، محدودیت save و iteration.
- **S18 — [From Ludum Dare to Pharloom — Interview with Team Cherry](https://www.acmi.net.au/stories-and-ideas/from-ludum-dare-to-pharloom)** — Jini Maxwell / ACMI، ۵ سپتامبر ۲۰۲۵؛ مصاحبه انجام‌شده در مهٔ ۲۰۲۵؛ **primary interview**، متن کامل خوانده شد. world-first، Citadel، Moss Grotto و movesetِ Hornet.
- **S19 — [The Hunt Is On!](https://www.teamcherry.com.au/blog/silksong-available-now)** — Team Cherry، ۴ سپتامبر ۲۰۲۵؛ **primary release announcement**، search excerpt. تأیید منتشرشدن Silksong، نه شاهد طراحی roomهای بررسی‌نشده.
- **S20 — [Nine Sols — Red Candle Games](https://shop.redcandlegames.com/projects/ninesols)**؛ [official presskit](https://redcandlegames.com/presskit/sheet.php?p=nine%20sols) — **primary official description**، excerptها. deflection-focused / Sekiro-lite combat و Taopunk؛ قصد طراحیِ puzzle خاص از این‌ها استنتاج نشده است.
- **S30 — [Godot: Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)** — **primary technical documentation**، بخش audio/networking/background processing خوانده شد. صفحهٔ stable تغییرپذیر است؛ تیم باید نسخهٔ مورداستفادهٔ خودش را بررسی کند.
- **S31 — [Prince of Persia: The Lost Crown Will Put Your Combat, Platforming, and Puzzle-Solving Skills to the Test](https://news.ubisoft.com/en-us/article/e1SD5gR3TWqk5GPAjWHSz/prince-of-persia-the-lost-crown-will-put-your-combat-platforming-and-puzzlesolving-skills-to-the-test)** — Ubisoft، ۱۲ ژوئن ۲۰۲۳؛ **official hands-on، پیش از انتشار**، بخش مرتبط خوانده شد. bell/platform outline، Shadow of Simurgh، Wak Wak و yellow/red attack telegraph؛ نام room در این متن ذکر نشده، نسبت‌دادن نام دقیق به آن **unverified** است.
- **S32 — [Platformer Toolkit — GMTK](https://gmtk.itch.io/platformer-toolkit)** — Mark Brown؛ **ابزار آموزشی تعاملی**، توضیح رسمی در search خوانده شد. برای اندازه‌گیری/فهم jump variables پیشنهاد می‌شود؛ در این پژوهش اجرا نشده است.
- **S33 — [Why Does Celeste Feel So Good to Play? — GMTK](https://www.patreon.com/GameMakersToolkit/posts/why-does-celeste-28582857)** — ۳۱ ژوئیهٔ ۲۰۱۹؛ **secondary analysis**، عنوان و توضیح عمومی بررسی شد؛ بدنهٔ محدودشده مبنای claim تازه نیست. منبع اصلی forgiveness در این سند S04 است.

### منابع room-level ثانویه

- **S05 — [The Summit — Celeste Wiki](https://celeste.ink/wiki/The_Summit)** — **community documentation**؛ بخش flagها، 7B wallbounce و tutorial خوانده شد. تعبیر pacing در این گزارش تحلیل است.
- **S10 — [White Palace / Path of Pain — Hollow Knight Wiki](https://hollowknight.wiki/w/Path_of_Pain)** — **community documentation**؛ صفحه به محتوای White Palace می‌رسد؛ بخش atrium، soul totems، saw/pogo و دو Kingsmould آخر خوانده شد.
- **S11 — [Crystal Peak — Hollow Knight Wiki](https://hollowknight.wiki/w/Crystal_Peak)**؛ [نسخهٔ Fandom](https://hollowknight.fandom.com/wiki/Crystal_Peak) — **community documentation**، excerptهای machinery، bench/Guardian و overlook. roomهای خاص در build این پژوهش بازپخش نشده‌اند.
- **S12 — [The Invisible Hand of Super Metroid](https://www.gamedeveloper.com/design/the-invisible-hand-of-super-metroid)** — تحلیل مستقل، ۱۴ ژانویهٔ ۲۰۱۲؛ **secondary room-by-room analysis**، بخش Etecoons، glass tube و guidance خوانده شد. نظر نویسنده دربارهٔ water handling نظر شخصی است و به‌عنوان واقعیت controller منتقل نشده است.
- **S15 — [Ginso Tree — Ori Wiki](https://oriandtheblindforest.fandom.com/wiki/Ginso_Tree)**؛ [Ginso Tree walkthrough](https://gamerwalkthroughs.com/ori-and-the-blind-forest/ginso-tree) — **community/walkthrough**، search excerpts برای escape، traversal و حضور Kuro. تفاوت بازگشت/collectibles نسخهٔ اصلی و Definitive Edition به‌عنوان جزئیات طراحی CLAWD استفاده نشده است.
- **S17 — [Castle Rock — IGN Guide](https://www.ign.com/wikis/rayman-legends/Castle_Rock)** — ۶ سپتامبر ۲۰۱۳؛ **walkthrough**، متن کامل خوانده شد؛ syncِ music/action، autoscroll، collapsed tower و tempo. وجود آنلاین co-op برای Rayman از این منبع ادعا نشده است.
- **S21 — [Factory (Great Hall) — Nine Sols Wiki](https://ninesols.wiki.gg/wiki/Factory_(Great_Hall))** — **community documentation**، متن مربوط خوانده شد؛ radiation، protection، Core Agitators، Mystic Nymph و platform puzzle. sequenceِ puzzle در این گزارش به CLAWD کپی نشده است.
- **S22 — [Abandoned Wastes — Haiku the Robot walkthrough](https://www.neoseeker.com/haiku-the-robot/Abandoned_Wastes)** — **walkthrough**، بخش مرتبط خوانده شد؛ secret notches، Trash Magnet، Electro-Magnetism و خروج wall climb. برخی قسمت‌های راهنما بازدیدهای بعدی را هم در هم می‌آمیزد؛ نقلِ ترتیب دقیقِ تمام unlockها انجام نشده است. [سایت رسمی Haiku](https://haikutherobot.com/) منبع تکمیلیِ هویت و exploration است.

### صدای بازیکنان؛ وزن محدود و claimsِ unverified

- **S23 — [My thoughts on the Ginso Tree Difficulty — Steam](https://steamcommunity.com/app/261570/discussions/0/412446890558315732/)** — ۱۳ فوریهٔ ۲۰۱۶؛ **player discussion**، excerpt دارای تاریخ و چند نظر خوانده شد. تجربهٔ frustration/ترک بازی و اختلاف نظر؛ نمایندهٔ همهٔ players نیست.
- **S24 — [Please tell me it’s not going to get harder than this — Reddit](https://www.reddit.com/r/OriAndTheBlindForest/comments/1hpvnn1/please_tell_me_its_not_going_to_get_harder_than/)** — **player discussion، فقط excerpt ایندکس‌شده**. تعبیر memorable در excerpt هست؛ context کامل و تاریخ دقیق **unverified**. ادعای «اکثر بازیکنان» در comment به نتیجهٔ تحقیق تبدیل نشده است.
- **S25 — [What are your thoughts on the Path of Pain? — Reddit](https://www.reddit.com/r/HollowKnight/comments/wbyo5t/part_187_what_are_your_thoughts_on_the_path_of/)** — **player discussion، excerpt ایندکس‌شده**؛ یادآوری صدا بیش از یک سال بعد. load کامل 403؛ context کامل و تاریخ قطعی **unverified**.
- **S26 — [The glass tube in Super Metroid infuriates me — Reddit](https://www.reddit.com/r/Metroid/comments/1il741u/the_glass_tube_in_super_metroid_infuriates_me/)** — **player discussion، excerpt/title**. frustration مشخص؛ تاریخ و متن کامل **unverified**. ادعای comment دربارهٔ تنها راه ورود Maridia به‌عنوان واقعیت speedrun/sequence break پذیرفته نشده است.
- **S27 — [How did people in 1994 find the Power… — Reddit](https://www.reddit.com/r/Metroid/comments/lgmkh8/super_metroid_how_did_people_in_1994_find_the/)** — **player discussion، excerpt** دربارهٔ کشف glass tube در نخستین play؛ context کامل **unverified**.
- **S28 — [Castle Rock might be the single most fun video game level… — Reddit](https://www.reddit.com/r/wiiu/comments/2rjkf1/castle_rock_on_rayman_legends_might_be_the_single/)** — **player discussion، متن آغاز post در search**؛ گزارش لذت فردی. تاریخ دقیق و comments کامل **unverified**.
- **S29 — [Castle Rock Perfect Run on PS4 — Reddit](https://www.reddit.com/r/Rayman/comments/49e1wu/rayman_legends_castle_rock_perfect_run_on_ps4/)** — **player discussion، excerpt**؛ context کامل و تاریخ دقیق **unverified**.

### محدودهٔ عدم‌قطعیت و تصمیم بعدی

- هیچ منبع عمومی solvabilityِ مختصات یا زمان‌های پیشنهادی CLAWD را تأیید نمی‌کند؛ این‌ها فقط blockout hypotheses هستند.
- ترتیب unlockِ double jump / grapple / phase در zoneها داده نشده؛ اگر یک طرح از آن‌ها استفاده کند، پیش‌نیاز باید در graph واقعی ثبت و route جایگزین طراحی شود.
- netcode، physics ticks، collider، dash distance، enemy projectile source و reset موجود CLAWD بررسی نشده‌اند؛ هزینه‌ها به وجود این زیرساخت وابسته‌اند.
- «خاطره‌انگیزترین»، «بهترین» و «اکثر players» بدون survey قابل‌دفاع نیست؛ این سند چنین رتبه‌بندی‌ای ندارد.
- برای پیش‌برد طراحی، نخست چهار prototype را در build واقعی بسنجید: catch laneِ امن، crumbling با fallback، دو switchِ latched در دو room، و flood-stateِ قبل/بعد. فقط پس از حل failureهای آن‌ها، set-pieceِ طولانیِ HP-1 و PR-1 را بسازید.