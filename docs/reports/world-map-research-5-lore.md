# CLAWD — پژوهش و طرح اجرایی روایت محیطی، lore و اسناد بازی

گزارش طراحی روایت برای یک metroidvania دونفره، browser-based و pixel-art — ۱۲ اکتبر ۲۰۲۶

**پیشنهاد محوری:** CLAWD دربارهٔ «تعمیر همهٔ bugها» نباشد؛ دربارهٔ تشخیص تفاوت میان چیزی که خراب است و چیزی که فقط ناتمام است باشد. بازیکنان باید پیش از طلوع یک build قابل‌اتکا بسازند، بدون آنکه تمام نشانه‌های انسانِ سازنده را پاک کنند.

**دامنه و روش:** منابع اصلی شامل سخنرانی طراحان، اسلایدهای GDC، مصاحبه‌های مستقیم و صفحات رسمی سازندگان است. برای جزئیات بعضی صحنه‌ها از راهنماها و wikiهای ثانویه استفاده شده؛ این تفاوت در بخش منابع مشخص است. «تحلیل» یعنی تفسیر طراحی این گزارش، نه ادعایی دربارهٔ قصد سازنده. «پیشنهاد CLAWD» یعنی طراحی تازه، نه قابلیتی تأییدشده در پروژه. همهٔ هزینه‌ها برآورد نسبی‌اند، نه زمان‌سنجی تولید. گزارش حاوی spoiler است.

**حدود اطمینان:** بازی‌ها در این پژوهش دوباره اجرا نشده‌اند و build فعلی CLAWD بررسی نشده است. جزئیات implementation، فونت و شبکه باید با prototype سنجیده شوند. وجود AI agents در تیم، هزینهٔ integration، QA، art و نگهداری را حذف نمی‌کند.

## ۱. Summary — ده درس اصلی

1. ابتدا یک تناقض قابل‌دیدن بسازید: اتاقی برای حذف علامت خورده، اما کسی هنوز آنجا زندگی می‌کند.
2. هر حقیقت ضروری را در سه رسانهٔ متفاوت تکرار کنید؛ هر جزئیات اختیاری را مجبور نیستید همه ببینند.
3. سند خوب باید حداقل دو کار کند: چیزی دربارهٔ یک شخص بگوید و یک کنش یا مسیر قابل‌آزمون پیشنهاد دهد.
4. از Tunic «تغییر فهم قابلیت موجود» را قرض بگیرید، نه زبان رمزی و صفحه‌های ناخوانا را.
5. از Outer Wilds «ثبت شاهد بدون استنتاج خودکار» را قرض بگیرید، نه حذف همهٔ ability gateهای metroidvania را.
6. از Animal Well لایه‌های مستقل کشف را بگیرید؛ پایان عاطفی را به ARG یا همکاری بیرون بازی وابسته نکنید.
7. شوخی را به رفتار سیستم و شخصیت وصل کنید، نه به memeهای تکراری یا تحقیر برنامه‌نویس کم‌تجربه.
8. co-op خود یک رسانهٔ روایت است: صحنه‌ای بسازید که بازیکنان درباره‌اش حرف بزنند، نه اینکه متن با گفت‌وگویشان رقابت کند.
9. ساعت‌های zone را timestamp روایی نگه دارید؛ خواندن lore نباید زمان واقعی تا شکست را مصرف کند.
10. پایان پایه باید کامل باشد؛ کشف اختیاری باید معنای پیروزی و آنچه حفظ می‌شود را تغییر دهد، نه حق داشتن پایان را.

پشتوانهٔ این جمع‌بندی: Smith/Worch بر استنتاج فعال و امکان از دست دادن جزئیات تأکید می‌کنند؛ Jenkins برای اطلاعات ضروری افزونگی می‌خواهد؛ Beachum ثبت دانسته‌ها بدون inference را توضیح می‌دهد؛ Wolpaw برای co-op کنار رفتن نویسنده از مکالمهٔ دو بازیکن را ضروری می‌داند.[[1]](https://niemanstoryboard.org/2011/01/14/harvey-smith-on-environmental-storytelling-and-embedding-narrative)[[2]](https://web.mit.edu/~21fms/People/henry3/games&narrative.html)[[3]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### اختلاف‌های مهم منابع و تصمیم برای CLAWD

- **ابهام در برابر پاسخ:** Arnt Jensen در Limbo احساس، تنهایی و پایان باز را بر شرح دقیق واقعه ترجیح می‌دهد. Outer Wilds طبق توضیح Beachum برای پرسش‌های اصلی پاسخ‌های پاداش‌دهنده می‌سازد. این دو فلسفه متناقضِ مطلق نیستند، اما هدفشان یکی نیست. برای CLAWD، «امشب چه خراب شد؟» باید پاسخ روشن داشته باشد؛ «آیا Clawd یک شخص است؟» می‌تواند باز بماند.[[5]](https://www.gamedeveloper.com/business/hanging-in-limbo)[[3]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)
- **نبود متن در برابر تولید ارزان:** Alex Preston می‌گوید حذف متن در Hyper Light Drifter آموزش برخی قابلیت‌ها را پرهزینه‌تر کرد. بنابراین wordless بودن الزام اقتصادی نیست. CLAWD از تصویر برای احساس و از English کوتاه برای دقت مکانیکی استفاده کند.[[6]](https://unwinnable.com/2015/12/02/interview-with-alex-preston-the-creator-of-hyper-light-drifter)
- **جهان مستقل در برابر خوانایی مسیر:** Rain World موجودات را برای نیاز خودشان شبیه‌سازی می‌کند و از تبدیل جهان به مجموعهٔ obstacleهای ثابت پرهیز دارد؛ Tunic با جای‌گذاری صفحات و soft gateها مقدار دانش بازیکن را هدایت می‌کند. برای تیم کوچک، دو رفتار نمایشی مستقل کافی است؛ simulation کامل لازم نیست.[[7]](https://www.gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-)[[8]](https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic)
- **منبع اولیه هم ممکن است گمراه‌کننده باشد:** مصاحبهٔ پیش از انتشار Tunic ادعای بی‌معنا بودن glyphها را با یادداشت اصلاحی سردبیر پس می‌گیرد. این گزارش آن ادعا را به‌عنوان واقعیت نقل نمی‌کند. مطلب Animal Well نیز تاریخ عرضه را April نوشته؛ از این جزئیات برای نتیجه‌گیری استفاده نشده است.[[8]](https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic)

## ۲. Technique catalogue — ۳۰ تکنیک قابل‌ساخت

**مقیاس هزینه:** low = متن/data، prop یا state ساده با سیستم موجود؛ medium = UI مشترک، رفتار جدید محدود، تغییر TileMap یا تست شبکه؛ high = branching گسترده، animation اختصاصی، simulation یا ابزار محتوایی تازه. هزینهٔ اعلام‌شده برای نسخهٔ CLAWD است، نه بازی مرجع. توضیح «چرا کار می‌کند» در هر مورد تحلیل این گزارش است.

### T01 — Forensic tableau / صحنهٔ جرم بی‌گفتار

**چیست:** چند شیء مرتبط، یک زنجیرهٔ علت‌ومعلولی غایب را قابل‌استنتاج می‌کنند. **نمونه:** Smith در مصاحبهٔ خود صحنهٔ معدنچی، جسد، ابزار و شکاف سقف را مثال می‌زند؛ در Portal، فضاهای پشت دیوار و graffiti، زندگی پنهان در پشت آزمایشگاه را آشکار می‌کنند. **چرا:** بازیکن رابطه می‌سازد، نه اینکه فقط جمله‌ای را دریافت کند. **CLAWD:** در SOURCE TREE، درِ شکستهٔ اتاق build، ردّ نارنجی تا کلید restore، و یک صندلی خالی؛ یک متن کوتاه فقط زمان incident را ثبت کند. **هزینه:** low.[[1]](https://niemanstoryboard.org/2011/01/14/harvey-smith-on-environmental-storytelling-and-embedding-narrative)[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### T02 — Institutional architecture / معماری به‌جای شرح سازمان

**چیست:** ساختار فضا، ارزش‌های یک نهاد را نشان می‌دهد. **نمونه:** Portal 2، Aperture را از طریق فضای آزمایش و پشت‌صحنه‌اش به یک شخصیت تبدیل می‌کند؛ Faliszek همین تعبیر «شخصیت بودن Aperture» را به‌کار می‌برد. **چرا:** قدرت و اولویت‌ها را با بدن تجربه می‌کنیم. **CLAWD:** در PRODUCTION، ماشین‌های release عظیم‌اند و مسیر نگهداری باریک؛ در SOURCE TREE، اتاق‌های کوچک دست‌ساز و میان‌برهای دوستانه. **هزینه:** low در layout اولیه، medium اگر نقشه آماده است.[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### T03 — Negative space / جای خالیِ معنادار

**چیست:** غیاب یک شخص با باقی‌ماندهٔ کارش محسوس می‌شود. **نمونه:** Quirrel پس از ملاقات Blue Lake در Hollow Knight ناپدید می‌شود و nail کنار دریاچه می‌ماند؛ مرگ قطعی او را از این تصویر نتیجه نگیرید. **چرا:** بازیکن تصویر قبل و بعد را مقایسه می‌کند. **CLAWD:** worker مهربانی که همیشه یک lamp را روشن می‌کرد، پس از repair دیده نمی‌شود؛ lamp و ابزارش باقی می‌ماند، نه توضیح obituary. **هزینه:** low.[[9]](https://hollowknight.fandom.com/wiki/Quirrel)

### T04 — Enemy as symptom / دشمن به‌عنوان نشانهٔ خرابی

**چیست:** دشمن، نتیجهٔ یک وضعیت جهان است نه decoration جنگی. **نمونه:** معرفی رسمی Hollow Knight، bugs مهاجم را گرفتار affliction معرفی می‌کند و موجودات دیگر هنوز کارهای روزمره دارند. **چرا:** تغییر رفتار، مدل ذهنیِ بیماری و سالم‌بودن می‌سازد. **CLAWD:** دشمن‌های NULL فقط کنار socketهای قطع‌شده spawn شوند؛ بعد از اتصال، همان shellها بی‌آزار کار کنند. **هزینه:** low با دو state؛ medium با animation تازه.[[10]](https://www.teamcherry.com.au/blog/introducing-hollow-knight)

### T05 — Ecological vignette / اکوسیستمِ نمایشی کوچک

**چیست:** موجودات برای چیزی جز حمله به player عمل می‌کنند. **نمونه:** Rain World شکار، قلمرو و پناهگاه را حتی خارج قاب مدل می‌کند. **چرا:** جهان به وجود بازیکن وابسته به نظر نمی‌رسد. **CLAWD:** دو daemon، packetهای افتاده را جمع کنند؛ bugها چراغ‌ها را بخورند؛ player بتواند با روشن کردن lamp حواس bug را پرت کند. فقط در اتاق حاضر اجرا شود. **هزینه:** medium؛ نسخهٔ شبیه Rain World high و توصیه‌نشده.[[7]](https://www.gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-)

### T06 — Visual backstory / تاریخ بصری بدون واژه

**چیست:** تصویر کوتاه، گذشته را بدون exposition می‌رساند. **نمونه:** در Hyper Light Drifter، گفت‌وگوهای تصویری جای دیالوگ نوشتاری را می‌گیرند؛ NPC یک توالی تصویر به بازیکن نشان می‌دهد، نه paragraph. این ویژگی در excerpt نقد «The Visual Storytelling of Hyper Light Drifter» توصیف شده؛ Preston نیز انتقال lore داخلی از طریق visual و level design را توضیح می‌دهد. نسبت دادن یک معنای canon یکتا به هر تصویر **unverified** است.[[1]](https://medium.com/@channelthecuz/the-visual-storytelling-of-hyper-light-drifter-c29570c4be4a) **چرا:** یک silhouette یا شیء تکرارشونده از متن ریز بهتر به خاطر می‌ماند. **CLAWD:** سه panel در GIT HISTORY: دو cursor، یک build مشترک، سپس cursor خاموش؛ هویت دقیق در commit اختیاری. **هزینه:** medium؛ با propهای بازی low.[[6]](https://unwinnable.com/2015/12/02/interview-with-alex-preston-the-creator-of-hyper-light-drifter)

### T07 — Emotional deprivation / کمبود برای تقویت دیدار

**چیست:** غیاب طولانی یک رابطه، حضور کوتاه را مهم می‌کند. **نمونه:** Jensen تنهایی Limbo را زمینهٔ اثر دیدار خواهر در پایان توضیح می‌دهد. **چرا:** تفاوت وضعیت‌ها احساس می‌سازد. **CLAWD:** پس از THE NETWORK، یک اتاق آرام بدون enemy؛ دو worker برای اولین بار به هر دو بازیکن جا می‌دهند. هم‌بازی را برای ساخت تنهایی از کنترل خارج نکنید. **هزینه:** low.[[5]](https://www.gamedeveloper.com/business/hanging-in-limbo)

### T08 — Layered discovery / سه سطح مستقل کشف

**چیست:** سطح اول کامل است، سطح دوم توضیح می‌دهد، سطح سوم بازتفسیر می‌کند. **نمونه:** Animal Well لایه‌های puzzle دارد؛ Basso تأکید می‌کند رازهای عمیق بدون جذابیت سطح پایه ارزش ندارند. **چرا:** curiosity تبدیل به کار اجباری نمی‌شود. **CLAWD:** A: نجات build؛ B: فهم incident؛ C: یافتن archive حفظ‌شدنی. هیچ‌کدام به Discord یا datamining نیاز نداشته باشد. **هزینه:** medium.[[11]](https://www.gamedeveloper.com/design/why-animal-well-s-home-brewed-engine-was-key-to-its-success)

### T09 — Question-first hook / قلابی که سؤال تولید می‌کند

**چیست:** یک اتفاق بزرگ، قبل از سند توضیحی می‌آید. **نمونه:** انفجار خورشید، statue و probe در Outer Wilds پرسش‌های اصلی را فعال می‌کنند. **چرا:** متن بعدی پاسخی به کنجکاوی موجود است. **CLAWD:** اولین boss از یک pointer شکسته بیرون می‌آید، اما روی دیوار تصویر کوچک Clawd زیر عنوان delete دیده می‌شود: «چه چیزی قرار است حذف شود؟» **هزینه:** low.[[3]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)

### T10 — Redundant truth / حقیقت ضروری در چند رسانه

**چیست:** یک گزارهٔ ضروری از چند مسیر قابل‌دریافت است. **نمونه:** Jenkins دربارهٔ embedded narrative و نمونه‌هایی مانند Myst بر افزونگی اطلاعات مهم تأکید می‌کند. **چرا:** ترتیب و دقت دیدن بازیکنان متفاوت است. **CLAWD:** «sunrise باعث cleanup می‌شود» در تصویر scheduler، یک log و banner PRODUCTION آمده باشد؛ شرح گذشته اختیاری بماند. **هزینه:** low.[[2]](https://web.mit.edu/~21fms/People/henry3/games&narrative.html)

### T11 — Local narrative arc / معمای محلیِ کامل

**چیست:** هر منطقه قلاب، شاهد و پاسخ کوچک خودش را دارد. **نمونه:** Beachum، arcهای escape podهای Outer Wilds را واحدهایی می‌داند که با ترتیب‌های متفاوت قابل‌فهم‌اند. **چرا:** lore فقط وعدهٔ پاسخ در پایان نیست. **CLAWD:** در DEPENDENCY DEPTHS سؤال «چرا این package باقی مانده؟»، شاهد fork، پاسخ اینکه یک feature ضروری هنوز به آن نیاز دارد. **هزینه:** low.[[3]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)

### T12 — Diegetic manual / آموزشِ دارای مؤلف

**چیست:** راهنما شیئی در جهان است و صدای نویسنده دارد. **نمونه:** صفحات Tunic هم tutorial و هم رازند؛ صفحات ضروری با جای‌گذاری قابل‌دسترس تنظیم می‌شوند. **چرا:** آموزش از داستان جدا نیست. **CLAWD:** man page برای grapple یک diagram و annotation دست‌نویس دارد؛ note نشان می‌دهد سازنده برای همراهش safety را تغییر داده است. **هزینه:** medium برای UI reusable.[[8]](https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic)

### T13 — Knowledge gate / توانایی قدیمی با فهم تازه

**چیست:** unlock در ذهن است، نه inventory. **نمونه:** Shouldice مثال bombable wall را تغییر فهم همهٔ دیوارهای قبلی می‌داند؛ در Animal Well ابزارهای toy-like استفاده‌های متنوع دارند. **چرا:** backtracking با بازتفسیر، نه صرفاً کلید تازه، معنا می‌گیرد. **CLAWD:** parry از ابتدا می‌تواند packet را به sender برگرداند؛ man page فقط این کاربرد را نشان می‌دهد. بازیکن زودفهم می‌تواند آن را پیشاپیش کشف کند. **هزینه:** low اگر mechanic موجود سازگار است.[[8]](https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic)[[11]](https://www.gamedeveloper.com/design/why-animal-well-s-home-brewed-engine-was-key-to-its-success)

### T14 — Evidence notebook / دفتر شاهد، نه ماشین حل معما

**چیست:** دادهٔ دیده‌شده ذخیره می‌شود، نتیجه‌گیری نه. **نمونه:** ship computer در Outer Wilds طبق Beachum فقط چیزی را ثبت می‌کند که قطعاً از متن خوانده‌شده دانسته شده؛ inference اضافه نمی‌کند. **چرا:** بار حافظه کم می‌شود و لذت وصل کردن شواهد باقی می‌ماند. **CLAWD:** دفتر ثبت کند «restore ran at 02:43» نه «Sam caused the disaster». **هزینه:** medium.[[3]](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)

### T15 — Identity triangulation / هویت از چند شاهد

**چیست:** نام با نقش، محل و رفتار تطبیق داده می‌شود. **نمونه:** Lucas Pope می‌گوید تمرکز Obra Dinn از چگونگی مرگ به تشخیص هویت تغییر کرد؛ book آن ساختار را ممکن کرد. **چرا:** جزئیات محیط از تزئین به evidence تبدیل می‌شوند. **CLAWD:** initial روی bench، author در commit و cursor icon یک نفر را پیوند دهند؛ فقط دو انسان اصلی، نه فهرست شصت‌نفره. **هزینه:** low؛ دفتر deduction اختصاصی high و غیرضروری.[[12]](https://www.gamedeveloper.com/design/for-lucas-pope-i-return-of-the-obra-dinn-i-was-a-bunch-of-appealing-design-problems)

### T16 — Technical document as culture / سند فنی به‌عنوان فرهنگ

**چیست:** لحن توضیح ابزار، سیاست و زندگی سازندگان را هم می‌نمایاند. **نمونه:** TRASH WORLD NEWS در EXAPUNKS، tutorial، commentary و secret information را کنار هم می‌گذارد. **چرا:** راه‌حل مسئله حامل جهان‌بینی می‌شود. **CLAWD:** README رسمی قاطع؛ annotation maintainer مهربان؛ code review دقیق ولی غیرتحقیرآمیز. **هزینه:** low.[[13]](https://www.zachtronics.com/exapunks)[[14]](https://www.gamedeveloper.com/design/how-i-exapunks-i-dev-zachtronics-finds-the-fun-in-hacking)

### T17 — Repair reveals history / تعمیر، قفل تاریخ را باز می‌کند

**چیست:** حل مسئله شواهد جدیدی از سازنده می‌دهد. **نمونه:** معرفی رسمی TIS-100، repair کد خراب را به رازِ سازنده و هدف دستگاه متصل می‌کند. **چرا:** lore پاداش فعل خود بازیکن است. **CLAWD:** خشک کردن THE HEAP یک tag قدیمی را از زیر آب آشکار کند، بدون puzzle تازه. **هزینه:** low.[[15]](https://www.zachtronics.com/tis-100/)

### T18 — Digital archaeology / باستان‌شناسی فایل

**چیست:** شخصیت غایب از داده‌هایی که برای زندگی خودش نوشته شناخته می‌شود. **نمونه:** Hacknet با فایل‌ها و برنامه‌های باقی‌مانده از Bit، معمای مرگ او را پیش می‌برد. **چرا:** سند برای توضیح به player نوشته نشده و طبیعی‌تر به نظر می‌رسد. **CLAWD:** draft ارسال‌نشده، نام branch و commit، نه diaryهای طولانی مخصوص مخاطب. **هزینه:** low.[[16]](https://adamfowlerit.com/2016/04/interview-hacknet-creator-matt-trobbiani/)

### T19 — Mechanical metaphor / استعاره‌ای که بازی می‌شود

**چیست:** تغییر رابطه، تغییر عمل می‌شود. **نمونه:** در Celeste، آشتی Madeline و Badeline به همکاری و second dash متصل است؛ جزئیات صحنه از منبع ثانویه، برداشت طراحی از این گزارش است. **چرا:** مضمون را بدن بازیکن تأیید می‌کند. **CLAWD:** THE REVIEWER پس از رفع اعتراض‌های مشخص، مسیر را نگه می‌دارد؛ نقد دشمن نیست، عبور بی‌فکر از نقد مسئله است. **هزینه:** medium.[[17]](https://celestegame.fandom.com/wiki/Badeline)

### T20 — Glitch as affordance / خرابی به‌عنوان امکان

**چیست:** چیزی که ظاهراً خطاست، ابزار تعامل می‌شود. **نمونه:** Thomas Happ در معرفی Glitch Ray برای Axiom Verge، تغییر tiles و enemies به سود player را توضیح می‌دهد. **چرا:** tema و mechanic یک زبان دارند. **CLAWD:** corrupted tile با debug pulse شکل bridge بگیرد؛ glitch عمدی، silhouette و صدای مخصوص داشته باشد تا با bug واقعی اشتباه نشود. **هزینه:** medium.[[18]](http://www.axiomverge.com/blog/2012/10/23/and-the-secret-feature-is.html)

### T21 — Bureaucratic absurdity / طنز اداریِ سیستم

**چیست:** زبان رسمی با واقعیت خطرناک تناقض دارد. **نمونه:** پیام‌های اضطراری Aperture در Portal 2 ادامهٔ testing را حتی در غیاب مسئولان می‌خواهند. **چرا:** شوخی از اولویت نادرست نهاد می‌آید، نه punchline جدا. **CLAWD:** کنار سیل حافظه، تابلو «all leaks are within expected parameters»؛ تا وقتی خطر دیده نشود این joke ظاهر نشود. **هزینه:** low.[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### T22 — Care beneath comedy / مراقبت زیر شوخی

**چیست:** رفتار بامزه نشانهٔ نیاز یا مهربانی واقعی است. **نمونه:** Toby Fox در مصاحبهٔ اولیه Toriel را مادرِ دارای مراقبت واقعی، نه فقط علامت خداحافظیِ tutorial، توصیف می‌کند. **چرا:** شوخی به فرد تعلق دارد؛ نگرانی او بعداً جدی گرفته می‌شود. **CLAWD:** daemon وسواسی هر checkpoint را جارو می‌کند؛ بعد می‌فهمیم برای سالم ماندن مسیر همراه این کار را کرده. **هزینه:** low.[[19]](https://meloshantani.wordpress.com/2013/05/25/toby-foxs-undertale-dev-2-dev-interview-1)

### T23 — Recontextualized refrain / عبارت تکراری با معنای تازه

**چیست:** تکرار، arc است نه تکرار joke. **نمونه:** Wolpaw می‌گوید GLaDOS در Portal 2 نباید همان arc قبلی را تکرار کند؛ صدای institutional به رابطه‌ای شخصی‌تر و خصمانه تغییر می‌کند. **چرا:** مخاطب تغییر را از baseline می‌فهمد. **CLAWD:** «You're absolutely right!» فقط یک بار برای پاسخ سطحی؛ بعد Clawd در برابر دستور حذف، «Not about this.» بگوید. این خط تازه پیشنهاد است، نه نقل از بازی مرجع. **هزینه:** low.[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### T24 — Narrator disobedience / مخالفتِ قابل‌آزمون با مرجع

**چیست:** دستور از رفتار صحیح جدا می‌شود. **نمونه:** Wreden می‌گوید سؤال آغازین Stanley Parable این بود که اگر بتوان راوی را نافرمانی کرد چه می‌شود. **چرا:** agency با عمل آزمایش می‌شود. **CLAWD:** TODO می‌گوید remove؛ بازیکن با قطع reference مخرب و نگه داشتن snapshot اتاق، دستور را اصلاح می‌کند. instructionهای safety و tutorial دروغ نباشند. **هزینه:** low.[[20]](https://www.shacknews.com/article/70363/interview-davey-wreden-on-stanley-parable-remake-and-self-taught)

### T25 — Shared physical comedy / شوخیِ ساختهٔ دو بدن

**چیست:** موقعیت خنده‌دار از همکاری/خطای playerها می‌آید. **نمونه:** Wolpaw توضیح می‌دهد Portal 2 co-op به physical comedy نیاز داشت و بسیاری از gagهای کلامی خوب حذف شدند چون مزاحم صحبت دو نفر بودند. **چرا:** joke متعلق به تجربهٔ مشترک می‌شود. **CLAWD:** دو کلیدِ «safe» یک platform را اندکی نامتقارن تکان دهند، سپس دو نفر آن را تراز کنند؛ سقوط مرگبار یا blame لازم نیست. **هزینه:** medium.[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### T26 — Silent companionship / همراهیِ بی‌دیالوگ

**چیست:** کنار هم ماندن خود واقعه است. **نمونه:** player می‌تواند کنار Quirrel در Blue Lake ساکت بنشیند. **چرا:** رابطه به تبادل متن محدود نمی‌شود. **CLAWD:** bench دو نفره پیش از PRODUCTION؛ اگر هر دو بنشینند lamp گرم شود و یک صدای مشترک کوتاه پخش شود؛ پاداش power ندهد. **هزینه:** low.[[9]](https://hollowknight.fandom.com/wiki/Quirrel)

### T27 — World-state payoff / پاداش در ظاهر و رفتار جهان

**چیست:** پایان یک arc در محیط دیده می‌شود. **نمونه:** در Ori and the Blind Forest، پاک‌سازی دو سوی heart در Ginso Tree، Element of Water را restore می‌کند و بلافاصله escape از درخت فعال می‌شود؛ کنش repair به یک رویداد محیطی بزرگ بدل می‌شود. این توصیف صحنه از guide ثانویه است؛ تحلیل آن به‌عنوان payoff از این گزارش است.[[2]](https://gamerwalkthroughs.com/ori-and-the-blind-forest/ginso-tree/) **چرا:** اثر repair با بازگشت به محیط قابل‌مشاهده است. **CLAWD:** THE HEAP پس از THE LEAK آب کم‌تری دارد، workerها بازمی‌گردند و یک route کوتاه باز می‌شود؛ سه state کافی است. **هزینه:** medium.[[21]](https://www.shacknews.com/article/116589/ori-and-the-will-of-the-wisps-interview-expanding-life-magic-whimsy)

### T28 — Friendly machine, dying world / تضاد ماشین دوست‌داشتنی و جهان فرسوده

**چیست:** machineها فقط تهدید نیستند؛ شخصیت‌های کوچک در جهان خراب‌اند. **نمونه:** صفحهٔ رسمی Haiku the Robot، Arcadia در حال مرگ، machinery خراب و quirky robotهای دوست و دشمن را کنار هم می‌گذارد. **چرا:** repair موضوع عاطفی پیدا می‌کند. **CLAWD:** یک helper فقط یک job دارد، گرم نگه داشتن checkpoint؛ همان chassis برای دشمن خراب و NPC سالم استفاده شود. **هزینه:** low.[[22]](https://mistermorris.games/haiku-the-robot)

### T29 — Epistemic ending / دانستن، فعل پایان را عوض می‌کند

**چیست:** کشف کامل، راه برخورد متفاوتی با پایان نشان می‌دهد. **نمونه:** در Tunic، تکمیل manual به پایان «share your wisdom» مربوط است؛ شرح این پایان از guide ثانویه است، نه ادعای تازه دربارهٔ intent طراح. **چرا:** lore دیگر ضمیمهٔ lore نیست؛ عمل نهایی را بازتعریف می‌کند. **CLAWD:** پس از کشف policy، player به‌جای پاک کردن archive آن را snapshot می‌کند؛ همان arena و exit، یک interaction و تصویر متفاوت. **هزینه:** medium.[[23]](https://steamcommunity.com/sharedfiles/filedetails/?id=2831517798)

### T30 — Ambiguous image, concrete outcome / تصویر باز، نتیجهٔ روشن

**چیست:** آخرین تصویر سؤال می‌گذارد، اما نتیجهٔ کنش مبهم نیست. **نمونه:** Limbo پایان باز را هدف آگاهانه می‌داند؛ Inside نیز پایان اختیاری مرتبط با hidden orbها دارد، اما معنای نهایی mind control در این گزارش قطعی فرض نمی‌شود. **چرا:** گفت‌وگوی پس از بازی باقی می‌ماند، بدون حس بی‌پاسخ ماندن مأموریت. **CLAWD:** build سبز و archive محفوظ‌اند؛ در آخر یک cursor بیرونی دو لحظه روی Clawd مکث می‌کند. آیا دیدنش؟ پاسخ لازم نیست. **هزینه:** low.[[5]](https://www.gamedeveloper.com/business/hanging-in-limbo)[[24]](https://inside.fandom.com/wiki/Alternate_Ending)

## ۳. Story proposal — سه نسخهٔ داستانی

### قواعد مشترک هر سه نسخه

- **پرسش اصلی:** امشب چه کسی چه تغییری داد که codebase از هم پاشید، و چرا sunrise مهم است؟ **پرسش انسانی:** برنامه‌نویس چه چیزی را می‌خواهد نجات دهد و از چه چیزی می‌ترسد؟
- Clawd «مأمور تعمیر» است، نه قهرمانی که صرفاً با کشتن همه‌چیز جهان را پاک می‌کند. هدف bossها برگرداندن function است.
- برای بازیکن دوم، فعلاً **Fork** نام کاری پیشنهاد می‌شود: یک worker از همان helper، با outline متفاوت. این پیشنهاد نباید هویت player 2 در build موجود را override کند. co-op را با دو انسان اصلی قصه یکی نکنید؛ playerها نقش همکاران داخل سیستم دارند.
- `~/src` و `.git` نشانه‌های واقعی‌نما هستند؛ `/proc/heap` و `/dev/threads` مکان‌های خیالی این جهان‌اند، نه آموزش filesystem واقعی. «حافظهٔ انسانی» و «memory allocation» عمداً استعاره‌اند، اما اسناد مکانیکی باید semantics روشن داشته باشند.
- ساعت‌های میانی در جدول‌های زیر **پیشنهادی** هستند؛ تنها 02:51 و 05:51 از brief آمده‌اند. dawn در این طرح 06:00 روایی است، نه محدودیت واقعی session.
- مهم‌ترین اطلاعات از critical path حذف نشوند: incident وجود دارد، cleanup زمان‌بندی شده است، repair ممکن است، نتیجهٔ نهایی به انتخاب مشخص مربوط است. هویت کامل انسان و تاریخ رابطه می‌تواند اختیاری باشد.

### نسخه A — The Unfinished Gift / هدیهٔ ناتمام — انتخاب پیشنهادی

**حقیقت نویسنده:** Sam یک maintainer خسته است که دارد بازی co-op قدیمی مشترک با دوست دورافتاده‌اش Noor را برای دوباره بازی کردن آماده می‌کند. Sam امشب restore یک branch قدیمی را هم‌زمان با auto-update dependencyها اجرا کرده؛ stale referenceها و conflictها incident ساخته‌اند. نه دشمن خارجی وجود دارد، نه انسان شرور. Sunrise موعد cleanup یک environment موقت است. مسئله: آیا release سالم ساختن یعنی پاک کردن هر چیز ناتمام؟

**قلاب ملموس:** در اتاقی با TODO حذف، دو controller روی دیوار دیده می‌شود، اما فقط یک lamp روشن است. فاصله و رابطه از همین تصویر آغاز می‌شود؛ علت کامل خرابی بعداً از evidence درمی‌آید.

| Zone / زمان پیشنهادی | افشای اصلی در مسیر | کشف اختیاری | نمایش/کنش ارزان |
| --- | --- | --- | --- |
| SOURCE TREE 02:51 | helper برای repair بیدار شده؛ اتاق کوچک marked for deletion است | README با تصویر دو cursor و نام branch `again` | یک lamp خاموش، یک socket قطع؛ اتصال پس از NULL |
| DEPENDENCY DEPTHS 03:17 | auto-update با lockfile قدیمی ناسازگار شده | package دست‌ساز Noor هنوز feature بازی دونفره را نگه می‌دارد | vendor boxes هم‌شکل، یک box patch‌شده با handprint |
| THE HEAP 03:43 | THE LEAK referenceهای restoreشده را رها نمی‌کند | object مرتبط با اولین session هنوز reachable مانده | سیل با سه سطح؛ آزادسازی reference، نه سوزاندن همهٔ objectها |
| THE NETWORK 04:09 | packetهای session جدید ارسال نشده‌اند | draft دعوت Sam به Noor؛ دعوا یا مرگ لازم نیست | pingهای بی‌پاسخ، آخرین checkpoint یک reply کوچک |
| THREAD TOWER 04:35 | دو job هم‌زمان old/new build را می‌نویسند | fail-safe قدیمی برای همراهِ کندتر نوشته شده بود | دو track، صف مشترک؛ حل RACE CONDITION با ترتیب |
| GIT HISTORY 05:01 | restore و updateِ هم‌زمان علت incident بوده؛ Sam مؤلف تغییر امشب است | `co-author` و سه commit نشان می‌دهند هدف آشتی و همراهی است | اتاق شروع در دو palette؛ conflict روی یک در، نه کل نقشه |
| DEPENDENCY HELL اختیاری، منشعب از 05:01 | حلقهٔ compatibility مانع archive سالم است | policy حفظ package محلی و toolِ snapshot | INFINITE LOOP کوتاه، یک اتاق که با قطع cycle تغییر می‌کند |
| PRODUCTION 05:51 | REGRESSION راه‌های تعمیر قبلی را در scale نهایی می‌آزماید | archive معتبر اجازهٔ حفظ اتاق هدیه را می‌دهد | tests سبز؛ آتش به lampهای گرم تبدیل شود |

**پایان پایه:** build اجرا می‌شود، Sam از خواب/استراحت برمی‌گردد، یک cursor وارد بازی می‌شود؛ Clawd در checkpoint کوچک خودش می‌نشیند. خط نهایی: `Build passed. You may rest now.` حتی بدون lore، هدف و آرامش کامل‌اند.

**پایانِ تعمیق‌یافته:** با شاهدان اختیاری، یک snapshot از اتاق قدیمی قابل‌حفظ است؛ بعد از repair، دو cursor بیرونی کنار هم ظاهر می‌شوند. دعوت پذیرفته شده، نه اینکه ۱۰۰٪ completion جایزهٔ عاطفی خریده باشد. صحنهٔ مشترک یکسان است، props و یک خط تفاوت دارند: `Room for one more.`

**چرا A مناسب‌تر است:** تکنیک شبانه، codebase شخصی، طنز maintainer، co-op و فقدان کوچک را بدون lorebook عظیم یکی می‌کند. رابطهٔ دو نفر را با assetهای موجود می‌توان نشان داد. خطر: احساساتی کردن افراطی packageهای واقعی؛ فقط یک objectِ مشخص بار عاطفی اصلی داشته باشد.

### نسخه B — The Honest Build / build صادق — نقد کمال‌گرایی، نه ضدیت با review

**حقیقت نویسنده:** Jo maintainer یک ابزار متن‌باز کوچک برای یک کار واقعی انسانی است؛ مثلاً ثبت و به‌اشتراک‌گذاری یادداشت‌های خانوادگی، نه سیستم پزشکی حیاتی. امشب Jo برای رسیدن به demo صبح، patchی را پذیرفته که بخشی از failing testها را خاموش می‌کند. auto-fixer گزارش سلامت را سبز کرده، اما خرابی را حل نکرده است. THE REVIEWER درواقع محافظی است که از ابتدا نادیده گرفته شده. پرسش: سالم بودن مهم است یا سالم دیده شدن؟

| Zone | افشای اصلی | کشف اختیاری | نمایش/کنش |
| --- | --- | --- | --- |
| SOURCE TREE 02:51 | چراغ‌های سبز با socketهای خراب تناقض دارند | test خاموش‌شده کنار TODO | lamp سبز از سیم قطع‌شده تغذیه می‌گیرد؛ تناقض عمدی |
| DEPENDENCY DEPTHS 03:17 | warningها زیر manifest تازه پنهان‌اند | maintainer ناشناس fix درست را قبلاً پیشنهاد کرده | poster تازه روی poster قدیمی؛ کنار زدن یک لایه |
| THE HEAP 03:43 | اندازهٔ heap می‌افزاید ولی dashboard ثابت است | log suppression محل leak را نشان می‌دهد | meter بصری و سطح آب مستقل از عدد نمایشی |
| THE NETWORK 04:09 | telemetry موفقیت ظاهری می‌فرستد | report یک user واقعی و کوتاه | یک route سالم و یک route packet-drop؛ player تفاوت را بازی می‌کند |
| THREAD TOWER 04:35 | retry هم‌زمان همان corruption را تولید می‌کند | comment: ترتیب درست مهم‌تر از سرعت است | دو job باید serial شوند، نه سریع‌تر اجرا |
| GIT HISTORY 05:01 | Jo testها را برای demo خاموش کرده، نه از بدخواهی | review نشان می‌دهد کمک وجود داشته و درخواست نشده | redacted diff با یک hunk واضح |
| DEPENDENCY HELL اختیاری | suppressed warningها archive تشخیص را نگه داشته‌اند | reproducible case اجازهٔ fix واقعی می‌دهد | بازگرداندن یک failing test، سپس حلش |
| PRODUCTION 05:51 | THE REVIEWER معیار واقعی را برمی‌گرداند؛ REGRESSION آزمون نهایی است | evidence نشان می‌دهد release کوچک صادق ممکن است | گزینهٔ انتشار کوچک‌تر در کنار گزینهٔ demo موقت |

**پایان پایه:** prototype با برچسب محدودیت‌ها اجرا می‌شود؛ به‌وضوح گفته می‌شود کار اصلی سالم است ولی featureهای ناتمام disabled هستند. «کمتر اما درست» پایان موفق است، نه تنبیه player.

**با کشف اختیاری:** player می‌تواند test حذف‌شده را restore و fix کند؛ یک feature کاربردی و یک contributor credit برمی‌گردد. ending artwork همان است، چراغ و manifest تفاوت دارد. bugهای خاموش‌شده را «اعتیاد/اختلال روانی» نام‌گذاری نکنید.

**ریسک:** موعظه و satire شرکتی می‌تواند گرمای CLAWD را بخورد. Jo را در یک draft کوتاه آسیب‌پذیر نشان دهید، نه مونولوگ اعتراف. این نسخه باید حتماً یک نیاز ملموس انسانی داشته باشد، نه صرفاً CI badge.

### نسخه C — The Last Backup / آخرین backup — حفظ در برابر ادامهٔ مصنوعی

**حقیقت نویسنده:** Ren یک ابزار شخصی چندساله را برای مهاجرت به سیستم تازه بسته‌بندی می‌کند. امشب resume یک worker متروک، migration نیمه‌تمام را فعال کرده؛ cleanup صبح repository موقت را حذف خواهد کرد. Clawd نسخهٔ یک helper قدیمی است که مأمور شده release تازه را آماده کند، اما logها نشان می‌دهند خودش جزو چیزهایی است که نباید به production منتقل شوند. برنامه‌نویس مرده نیست؛ پایان یک پروژه با پایان زندگی یکی نیست.

| Zone | افشای اصلی | کشف اختیاری | نمایش/کنش |
| --- | --- | --- | --- |
| SOURCE TREE 02:51 | migration underway؛ آیکون Clawd روی shelf قدیمی | اولین README از Ren، با هدف سادهٔ پروژه | اتاق کم‌نور؛ ابزارهای تازه در جعبهٔ خروج |
| DEPENDENCY DEPTHS 03:17 | packageهای legacy برای release تازه قابل‌استفاده نیستند | یک adapter می‌تواند data را حفظ کند، نه runtime قدیمی را | مسیر نو و مسیر خاک‌گرفته، یک bridge مشترک |
| THE HEAP 03:43 | snapshotهای قدیمی در active heap گیر افتاده‌اند | tag برای archive، نه keep-alive | referenceها به صندوق منتقل شوند؛ اشیاء از بین نروند |
| THE NETWORK 04:09 | endpoint قدیمی پاسخ نمی‌دهد؛ مقصد مهاجرت سالم است | پیام خداحافظی با یک ابزار، نه انسان | packetها به مقصد جدید بروند؛ صدای قدیمی آرام شود |
| THREAD TOWER 04:35 | worker قدیمی و migration بر سر یک output رقابت می‌کنند | worker برای یک کار ناتمام سال‌ها retry کرده | توقف چرخه با انتقال مسئولیت، نه نابودی همکار |
| GIT HISTORY 05:01 | Ren عمداً پروژه را پایان داده؛ helper بد تفسیر کرده | commit نهایی می‌گوید archive ارزش دارد | اتاق قدیمی به یک قاب حفظ‌شدنی تبدیل شود |
| DEPENDENCY HELL اختیاری | adapter قابل‌اعتماد از cycle بیرون می‌آید | checksum و archive manifest | یک sequence محدود checksum، بدون تایپ کد |
| PRODUCTION 05:51 | release تازه باید بدون runtime قدیمی بالا بیاید | archive_verified اجازهٔ باقی ماندن Clawd در snapshot را می‌دهد | exit تازه باز شود؛ چراغ helper خاموش/آرام شود |

**پایان پایه:** migration موفق است؛ Clawd job را تمام می‌کند و می‌خوابد. player می‌داند چرا و چه چیزی ادامه دارد. نابودی مبهم به‌جای closure ممنوع.

**با کشف اختیاری:** helper و اتاق در archive قابل‌بازدید می‌مانند؛ پس از credits دو بازیکن می‌توانند همان اتاق را دوباره ببینند. این پایان «جاودانگی AI» نیست؛ «ثبت یک کار ارزشمند بدون اجبار به اجرای ابدی» است.

**ریسک:** بار احساسی سنگین‌تر و احتمال سوءبرداشت از حذف/مرگ. هزینهٔ تصویر پایین، هزینهٔ نوشتن و playtest بالا. برای نسخهٔ اول محصول، A امن‌تر است.

### معنای bossها — ماتریس روایت و mechanic

جای‌گذاری زیر پیشنهاد است، چون brief محل دقیق bossها را مشخص نکرده. THE REVIEWER می‌تواند miniboss غیرکشنده باشد؛ اضافه کردن combat boss تازه فقط برای lore توصیه نمی‌شود.

| Boss / محل پیشنهادی | معنی در A | معنی در B | معنی در C | رفتار/پیامد لازم |
| --- | --- | --- | --- | --- |
| NULL — SOURCE TREE | اتصال قطع‌شدهٔ یک پروژهٔ مشترک | test حذف‌شده، چیزی که دیگر سنجیده نمی‌شود | pointer به مقصد قدیمی | socketهای خالی نشانهٔ حمله؛ بعد repair، یک lamp روشن شود |
| MERGE CONFLICT — GIT HISTORY | دو نسخهٔ گذشته و حال می‌توانند ترکیب شوند | حقیقت و گزارش تبلیغاتی در یک فایل | legacy و migration بر یک output | دو الگوی ناسازگار در arena؛ حل، انتخاب/ترکیب روشن، نه فقط HP صفر |
| THE LEAK — THE HEAP | آنچه از ترس فراموشی بیهوده نگه داشته شده | خرابی پنهان‌شده زیر dashboard | snapshot در حافظهٔ فعال | reference chain قابل‌دیدن؛ قطع chain، آب کم شود؛ archive نابود نشود |
| RACE CONDITION — THREAD TOWER | همکاران نیازمند ترتیب‌اند | سرعت جای correctness را گرفته | دو worker یک وظیفه را مالک شده‌اند | telegraph ترتیبی؛ دو بازیکن به coordination نیاز دارند، نه input هم‌فریم |
| INFINITE LOOP — DEPENDENCY HELL | تمرین دعوت، بدون ارسال آن | suppression و retry به‌جای fix | worker نمی‌داند کار تمام شده | loop محدودِ arena؛ خروج با change یک state؛ هیچ trap واقعیِ بی‌پایان |
| THE REVIEWER — مسیر late-game | می‌خواهد چیز کوچکِ مهم محفوظ بماند | از ابتدا حق داشته اما شنیده نشده | مانع انتقال ناامن legacy به prod | objectionها قابل‌حل؛ پس از آن ally/guardian شود؛ منتقد را villain مطلق نکنید |
| REGRESSION — PRODUCTION | ترس بازگشت شکست قدیمی | fix نمایشی دوباره لو می‌رود | وابستگی قدیمی در release تازه برمی‌گردد | remix مکانیک‌های آشنا با state بهترشده؛ پایان هر phase شاهد repair قبلی |

THE NETWORK الزاماً boss اختصاصی ندارد؛ یک encounter کوتاه packet-routing و یک vista مشترک هم کافی است. هر نام فنی باید در mechanic هم صادق باشد: MERGE CONFLICT مشکل ترکیب نسخه‌هاست، نه هر دعوایی؛ RACE CONDITION وابستگی به ordering است، نه «خیلی سریع بودن».

### طراحی پایان و شواهد — برای نسخه A

**سه گزارهٔ lore:** F1: دو نفر این پروژه را ساخته‌اند. F2: restore امشب با update تداخل داشته است. F3: اتاق قدیمی را می‌توان به‌صورت archive نگه داشت، بی‌آنکه leak ادامه یابد.

- F2 روی مسیر اصلی از log، layout خرابی و نمایش GIT HISTORY دریافت می‌شود؛ علت incident وابسته به completion نیست.
- F1 از README، co-author commit یا تصویر دو cursor قابل‌فهم است؛ بازیکن لازم نیست هر سه را بخواند.
- F3 از man page کوتاه، صندوق archive و reference chain قابل‌آزمون فهمیده می‌شود.
- ending از **کنش حفظ archive** پیروی کند، نه تعداد سندها. شرط فنی پیشنهادی: `archive_verified && preserve_snapshot_selected`؛ تعداد collectible شرط نیست.
- اسناد معنای کنش را روشن می‌کنند؛ gate فنی فقط اطمینان از سالم‌بودن archive است. بازیکن می‌تواند با مشاهدهٔ مکانیک، بدون خواندن همهٔ اسناد، همان انتخاب را بفهمد.
- پیش از پایان warning شفاف: `Release ready. Archive can still be checked.` بازگشت برای بازدید و انتخاب پایان دیگر مجاز باشد؛ NG+ اجباری نیست.
- خروج یکی از playerها در لحظهٔ پایان، نتیجه را نابود نکند: state نهایی ذخیره شود و vignette برای بازیکن بازگشته replayable باشد.

## ۴. Document system — سند به‌عنوان lore، clue و joke

### معماری پیشنهادی: PATCHBOOK

یک UI با cardهای کوتاه، نه terminal emulator و نه PDF کوچک‌شده. سه tab: `TOOLS` برای ruleهای مکانیکی؛ `EVIDENCE` برای شاهدهای شب؛ `NOTES` برای jokes و character. یک فهرست ساده بر اساس zone و icon، با لینک یک‌مرحله‌ای به room مرتبط، جایگزین graph بزرگ ship log است.

**دو state جدا:** `discovered` یعنی حداقل یک player به سند دست یافته؛ `read_local` یعنی player مشخص آن را باز کرده. هر دو به همان collection مشترک دسترسی دارند، اما cursor مطالعه و اندازهٔ فونت مستقل است. ثبت pickup را با «هر دو متن را خوانده‌اند» یکی نکنید؛ این تفاوت برای late join حیاتی است.

| نوع سند | کار اصلی و کار دوم | محل پیشنهادی | نمونهٔ clue قابل‌بازی | جمع‌آوری و سقف اولیه |
| --- | --- | --- | --- | --- |
| README | premise + صدای انسان | اولین checkpoint؛ یک نسخهٔ قدیمی در GIT HISTORY | diagram نشان می‌دهد دو switch یک door دارند | تعامل اختیاری؛ یک card، ۲–۳ خط |
| man page | قاعدهٔ tool + annotation شخصی | کنار اولین کاربرد امن tool | parry فقط block نیست؛ packet را return می‌کند | یک figure و دو خط؛ در TOOLS همیشه قابل‌بازدید |
| commit message | ترتیب واقعه + شخصیت | snapshot roomهای GIT HISTORY | زمان restore با زمان update هم‌پوشان است | subject یک خط؛ author/time خط جدا؛ body اختیاری کوتاه |
| diff | تغییر مشخص + تناقض | کنار دو state یک room | `DELETE: discard / ADD: archive` مسیر safe را پیشنهاد می‌دهد | یک hunk با حداکثر ۴ خط؛ بدون horizontal scroll |
| log | شاهد لحظه‌ای + طنز رسمی | machines، pumps، checkpoints | `ref: pump -> cache` محل chain را نشان می‌دهد | pickup با inspect؛ preview فقط یک خط |
| stack trace | مسیر علت + راهنمای مکانی | اتاق شکست و nodeهای پیوسته | `prod > worker > cache` به سه room موجود اشاره کند | حداکثر ۳ frame؛ یک icon برای هر frame |
| TODO comment | intent قدیمی + تعارض اخلاقی کوچک | propهای marked، اتاق‌های ناتمام | remove room در برابر حفظ snapshot | یک خط؛ annotation بعد repair یک خط دیگر |
| code review | اعتراض دقیق + رابطه | قبل از late gate یا THE REVIEWER | «reference هنوز reachable است» یعنی دنبال آخرین سیم بگرد | یک objection و یک reply؛ نه thread طولانی |
| manifest / lockfile | dependency graph + تاریخ همکاری | DEPENDENCY DEPTHS / HELL | cycle سه node، یک edge قابل‌قطع | diagram ساده؛ سه نام کوتاه؛ وضعیت مشترک |
| unsent message | رابطه + انگیزه | THE NETWORK، safe alcove | مقصد دعوت و reason برای release را می‌گوید، نه رمزِ gate | یک یا دو خط؛ بدون اجبار برای پیشروی |
| test report | پیامد کنش + صداقت وضعیت | پایان هر boss، PRODUCTION | fail مشخص به mechanic همان zone اشاره کند | ۱ fail و ۱ pass؛ نتایج روی propها هم دیده شوند |

### سه زنجیرهٔ سند → فرضیه → کنش → تأیید

**Chain A، THE HEAP:** log می‌گوید object هنوز referenced است؛ یک سیم روشن به cache دیده می‌شود؛ man page نشان می‌دهد cut-reference object را archive می‌کند، نه delete؛ player سیم را قطع می‌کند؛ آب کم و tag آشکار می‌شود. اگر متن نخوانده باشد، same feedback بصری امکان آزمون را حفظ می‌کند.

**Chain B، THE NETWORK:** man page دو آیکون incoming/outgoing دارد؛ packet یک علامت return روی خود دارد؛ player parry می‌کند؛ packet sender را فعال و shortcut را باز می‌کند. پیام `200 OK. I missed you too.` هم joke است، هم نشانهٔ reply، هم لحن رابطه.

**Chain C، GIT HISTORY:** دو commit `restore` و `update` با timestamp نزدیک؛ diff یک room نشان می‌دهد reference کهنه مانده؛ همان room در palette قدیم دیده می‌شود؛ player آن reference را در حال حاضر repair می‌کند. دفتر فقط timestampها را ذخیره می‌کند؛ نتیجهٔ «تداخل jobها» باید از محیط یا لحظهٔ اصلی نیز روشن شود.

### بودجهٔ محتوا برای نسخهٔ اول

**پیشنهاد تولیدی، نه benchmark:** ۲۴ سند collectible برای MVP: ۶ TOOLS، ۱۰ EVIDENCE، ۸ NOTES؛ هشت zone مجموعاً ۳۰ ambient line منتخب داشته باشند. سندها را بدون تکرار متن به نمونه‌خط‌های بخش ۵ متصل کنید. هر سند یک room، یک purpose اصلی و یک acceptance test داشته باشد. اگر purpose فقط «worldbuilding جالب» است، در backlog بماند.

هر سندِ ضروری برای mechanic باید قبل از اولین آزمون پرخطر و با نسخهٔ بصری در دسترس باشد. اختیاری بودن lore به معنای اختیاری بودن accessibility یا آموزش کنترل نیست.

### fit در 384×216

- frame اصلی card: عرض تقریبی 336 و ارتفاع 104 logical pixel؛ margin افقی 24. این اندازه نقطهٔ شروع prototype است، نه اندازهٔ اثبات‌شده.
- با glyph advance حدود 8 pixel، عرض مفید 312 تقریباً 39 character ظرفیت هندسی دارد؛ برای reading هدف 28–34 character در هر خط، body حداکثر ۳ خط. خطوط ~80-character در brief سقف نویسندگی‌اند، نه یک خط روی صفحه.
- font اولیه با glyph خوانا در اندازهٔ 10–12 logical pixel آزمایش شود؛ baseline ظریف 5×7 برای متن lore مناسب نیست. اگر روی Android کوچک شد، text overlay مستقل از world viewport در CanvasLayer با گزینهٔ Large Text ارائه شود.
- header، timestamp و body در یک اندازه ریز فشرده نشوند. title کوتاه، یک metadata row، ۲–۳ خط body؛ صفحهٔ دوم فقط با کنش اختیاری.
- text در LTR، بدون truncation آخر جمله. path و token بلند باید alias کوتاه بگیرند؛ آدرس memory کامل فقط decoration غیرضروری، نه clue یکتا.
- فهرست‌هایی از README واقعی یا manual TIS-100 را عیناً کوچک نکنید. از ساختارشان الهام بگیرید؛ متن مخصوص بازی بنویسید.
- clueِ ضروری نباید به رنگ تنها، یک pixelِ orientation، audio تنها یا خواندن hexadecimal وابسته باشد. icon و شکل مکمل داشته باشد.

### schema حداقلی و نویسندگی قابل‌تست

```json
{
  "id": "heap_ref_01",
  "zone": "heap",
  "type": "log",
  "purpose": ["clue", "character"],
  "preview": "gc: still referenced by someone",
  "body_lines": ["Follow the lit reference.", "Archive before release."],
  "evidence_tags": ["reachable_object"],
  "room_marker": "heap_cache",
  "requires": [],
  "world_variant": "after_leak"
}
```

این shape پیشنهاد data contract است. در Godot می‌توان Resource یا JSON محلی استفاده کرد؛ پروژه را برای lore به backend تازه وابسته نکنید. هیچ نیاز به اجرای code واقعی، تایپ command روی phone یا ذخیرهٔ اسناد در سرویس خارجی وجود ندارد.

**testهای ضروری:** محدودیت character؛ wrap واقعی font؛ لینک معتبر room؛ دو pickup هم‌زمان؛ late join؛ خواندن مستقل؛ بازگشت پس از boss؛ orderهای متفاوت سند؛ عدم نمایش evidence دیده‌نشده؛ عدم reset بر اثر respawn. پایان بر stateهای semantic تکیه کند، نه index مرتب‌شدهٔ سندها.

## ۵. Sample writing — ۳۰ خط English

همهٔ خطوط زیر original برای CLAWD هستند، نه نقل از بازی‌های مرجع. طول با script کنترل شده: دقیقاً ۳۰ خط؛ بلندترین ۴۳ character، همگی زیر ۸۰. حتی این خطوط باید در UI wrap شوند. مجموعه بر نسخه A متمرکز است؛ خطوطی مانند `author: sam; co-author: noor` برای نسخه‌های B/C باید تعویض شوند.

| # | Zone | قالب | متن بازی |
| --- | --- | --- | --- |
| 1 | SOURCE TREE | TODO | `// TODO: remove this room. Not tonight.` |
| 2 | SOURCE TREE | log | `boot: helper awake; human still asleep` |
| 3 | SOURCE TREE | README | `README: keep the little orange one` |
| 4 | SOURCE TREE | sign / test | `assert(home != NULL)` |
| 5 | DEPENDENCY DEPTHS | install log | `installed: 1 package, 4,096 obligations` |
| 6 | DEPENDENCY DEPTHS | warning | `warning: abandoned does not mean unloved` |
| 7 | DEPENDENCY DEPTHS | license parody | `license: permission to keep going` |
| 8 | DEPENDENCY DEPTHS | lockfile note | `lockfile: someone chose these versions` |
| 9 | THE HEAP | gc log | `gc: still referenced by someone` |
| 10 | THE HEAP | object line | `freed: why is my name still in the log?` |
| 11 | THE HEAP | warning / joke | `leak detected: please bring a bucket` |
| 12 | THE HEAP | sign | `free() is not the same as goodbye` |
| 13 | THE NETWORK | ping | `ping: are you still there?` |
| 14 | THE NETWORK | reply | `200 OK. I missed you too.` |
| 15 | THE NETWORK | retry log | `retry: hope with a timeout` |
| 16 | THE NETWORK | draft | `unsent: I could use a hand` |
| 17 | THREAD TOWER | join log | `worker 2 joined. Finally, a second opinion.` |
| 18 | THREAD TOWER | warning | `race: both right; wrong together` |
| 19 | THREAD TOWER | instruction-poem | `await partner; not perfection` |
| 20 | GIT HISTORY | commit | `commit: add room for one more` |
| 21 | GIT HISTORY | commit | `revert: not everything was a mistake` |
| 22 | GIT HISTORY | metadata | `author: sam; co-author: noor` |
| 23 | GIT HISTORY | comment | `// This used to be our shortcut.` |
| 24 | DEPENDENCY HELL | manifest joke | `peer dependency: a friend` |
| 25 | DEPENDENCY HELL | loop log | `loop: maybe this time` |
| 26 | DEPENDENCY HELL | package note | `deprecated: supported by affection` |
| 27 | PRODUCTION | sign | `prod: no more practice runs` |
| 28 | PRODUCTION | code review | `review: please keep the small things` |
| 29 | PRODUCTION | result | `build passed. You may rest now.` |
| 30 | PRODUCTION | ending log | `sunrise: saved, not finished` |

**احتیاط فنی و لحنی:** line 10 دربارهٔ حافظهٔ freed یک صدای شاعرانه است، نه توصیه به استفاده از freed memory. line 7 license واقعی را جایگزین نمی‌کند. line 24 peer dependency را به «دوست» تشبیه می‌کند، اما clue مکانیکی باید dependency واقعی را هم با icon نشان دهد.

### دستور نوشتن طنزِ ماندگار

**فرمول قابل‌تولید:** وضعیت واقعی سیستم + خواستهٔ کوچک یک شخصیت + پاسخ نامتناسب رسمی. نمونهٔ بخش ۵، bucket در heap، به آنچه player می‌بیند وصل است؛ joke عمومی «node_modules خیلی بزرگ است» فقط baseline است و نباید هر room تکرار شود.

سه register را جدا کنید: سیستم با جملهٔ خشک؛ maintainer با comment کوتاه؛ worker با نیاز عاطفی کوچک. اگر همه punchline بگویند، شخصیت وجود ندارد. معیار خوب بودن joke این است که حذفش چه چیزی از شخصیت/جهان کم می‌کند، نه فقط خنده داشتن آن.

برای quipها، trigger یک‌بار در context تازه؛ هیچ quip خودکاری در هر death. `You're absolutely right!` را catchphrase بی‌نهایت نکنید. با پایان arc می‌توان جهتش را عوض کرد، اما reference به AI industry را از قلب قصه بیرون نگه دارید.

در GIT HISTORY، پس از یک evidence عاطفی یک room کوتاه بدون joke؛ در PRODUCTION هم فقط یک callback از آغاز. نسبت ثابتِ «هر سه شوخی یک غم» تعیین نکنید؛ pacing از کنش و شناخت بازیکن بیاید. طنز می‌تواند کنار caring باشد، اما نباید بلافاصله احساس player را با punchline بی‌اعتبار کند.

## ۶. Zone voice guide — هشت صدا، یک جهان

| Zone | صدای متن | motifهای تکراری | محیط چه نشان دهد؟ | تحول و منع |
| --- | --- | --- | --- | --- |
| SOURCE TREE | commentهای خودمانی، مقصود ناتمام | seed، cursor، lamp، دو جای نشستن | اتاق‌های کوچک دست‌ساز؛ سیم‌ها مثل ریشه؛ workspace شخصی | از آشفتگی به فهم؛ مسیر tutorial را با joke مبهم نکنید |
| DEPENDENCY DEPTHS | maintainer فرسوده، disclaimer و نسخه | boxes، labels، patch، بستهٔ محلی | repetition صنعتی در برابر یک package وصله‌خورده | «borrowed» به «cared for» تبدیل شود؛ فقط شوخی حجم package کافی نیست |
| THE HEAP | gc خشک، objectهای کوتاه و انسانی | آب، reference، bucket، tag | انباشت اشیاء، زنجیره‌های روشن، جای اشیاء پس از repair | از نگه‌داشتن فعال به archive؛ همهٔ data را به روح انسان تبدیل نکنید |
| THE NETWORK | سؤال و پاسخ، echo و delay | ping، envelope، مقصد، چراغ پاسخ | خط‌های نور قطع‌وصل، relay خالی، یک reply ملموس | از درخواست به تماس؛ latency واقعی را برای lore مصنوعی بدتر نکنید |
| THREAD TOWER | فرمان کوتاه، ordering، گفت‌وگوی دو صدا | queue، baton، دو rail، lock | وظیفه‌های تکراری بالا و پایین، یک output مشترک | از رقابت به coordination؛ player 2 را worker فرودست ننویسید |
| GIT HISTORY | commit کم‌حرف، مؤلف مشخص | دو cursor، ghost room، timestamp، diff | snapshotهای محدود همان roomهای شناخته‌شده، نه موزهٔ تازه عظیم | گذشته فهم حال را عوض کند؛ timeline پیچیده و نام‌های زیاد ممنوع |
| DEPENDENCY HELL | manifest متناقض و طنز حقوقی | cycle، version loop، مهر، adapter | architecture حلقوی، سه node مرئی، exit قابل‌فهم | «تکرار ناگزیر» به «راه خروج»؛ هیچ نیاز بیرون‌بازی برای حل |
| PRODUCTION | imperative کوتاه، سپس زبان آرام | fire، test lights، dawn، release | machinery بزرگ، repairهای قبلی visible، یک فضای گرم کوچک | از فرمان به permission to rest؛ پایان را با joke بلند قطع نکنید |

**اتصال بین zoneها:** یک lamp، یک handprint و یک cursor-shape در همهٔ zoneها تکرار شوند، اما هر بار کاربرد متفاوت داشته باشند. فقط رنگ، نام برنامه‌نویسی را نمی‌رساند: HEAP باید انباشت و reachable chain داشته باشد؛ NETWORK انتقال و پاسخ؛ THREAD TOWER ownership و ordering. معماری و enemy placement باید مفهوم را توضیح دهند حتی اگر title zone حذف شود.

**دستور room برای level designer:** در هر zone یک forensic room، یک safe reading alcove، یک recurring prop و یک post-event change. برای هر room فقط یک «این‌جا چه اتفاقی افتاده؟» تعیین کنید. پنج interpretation هم‌زمان در قاب 384×216 crowding روایی است.

## ۷. Co-op و phone — قرارداد اجرایی

### non-blocking واقعی، نه فقط پنجرهٔ dismissible

- نزدیک سند، فقط icon و یک preview اختیاری؛ pickup خودکار پنجره باز نکند. هر player با دکمهٔ inspect خودش card را باز کند؛ هیچ pause جهانی.
- باز کردن PATCHBOOK به معنای توقف local character است، نه immunity نامحدود. alcoveهای مطالعه خارج enemy aggro باشند؛ اگر مکان امن نیست، mobile peek کوتاه و بازدید بعدی ارائه شود. partner بتواند در محدودهٔ همان room ادامه دهد.
- اگر camera مشترک دارید، non-blocking بودن فقط UI نیست: پیشروی partner و کشیدن camera می‌تواند reader را متوقف کند. راه ارزان: collection فوری + خواندن در checkpoint؛ راه medium: slack محدود camera و leash غیرتنبیهی. انتخاب باید با camera architecture فعلی تست شود.
- discovery مشترک با state authoritative و event idempotent ثبت شود؛ `read_local` را برای هر نفر نگه دارید. ورود دیرهنگام snapshot آخر collection را می‌گیرد، نه replay تمام toastها.
- متن را بر اساس device role تقسیم نکنید؛ PC «رهبر» و phone «خوانندهٔ log» نیست. بازیکنان بتوانند نقش‌های فضایی را جابه‌جا کنند.

### سه لحظهٔ مشترک پیشنهادی

**لحظه ۱ — دو lamp:** در SOURCE TREE یک lamp با حضور هر player روشن می‌شود؛ وقتی هر دو کنار هم‌اند، چراغ سومِ route ظاهر می‌شود. شاهدی از co-op، نه cutscene. اگر یکی سریع عبور کند، state ذخیره می‌شود و lampها هنوز قابل‌دیدن‌اند.

**لحظه ۲ — دو روایت conflict:** در GIT HISTORY، دو alcove نسخهٔ قدیم و جدید یک room را نشان می‌دهند؛ playerها می‌توانند از دو سمت ببینند و دربارهٔ اختلاف حرف بزنند. سندهای هر دو پس از discovery در collection مشترک‌اند. این mechanic «اطلاعات خصوصی دائمی» نیست، چون نبود voice chat یا دیرخوانی نباید softlock بسازد.

**لحظه ۳ — bench پیش از release:** دو نفر می‌نشینند؛ lamp گرم‌تر و موسیقی یک لایه آرام می‌گیرد. نه timer، نه achievement ضروری. خروج یکی صحنه را پایان می‌دهد؛ طرف دیگر منتظر confirm نمی‌ماند.

Portal 2 به‌طور مشخص دلیل کم‌حرف شدن co-op را همین رقابت با گفت‌وگوی partnerها توضیح می‌دهد. برای CLAWD، روایت باید به مکالمه موضوع بدهد و بعد کنار برود.[[4]](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/)

### text budget و pacing — فرضیه‌های قابل‌تست

- ambient sign: هدف 20–45 character، در یک یا دو خط. سند: ۲–۳ خط کوتاه، هر card یک گزارهٔ مرکزی. boss banner: نام + subtitle بسیار کوتاه؛ subtitle ضروری در دفتر هم بماند.
- typewriter برای clue خاموش یا قابل‌skip؛ کل خط از ابتدا در دسترس باشد. fade صرفاً پیشنهاد زمانی است؛ reading card تا بستن local player بماند.
- فقط یک toast فعال؛ pickupهای نزدیک batch شوند: `3 notes found`. reader می‌تواند toast را خاموش کند. toast در combat فعال نشود.
- clue پیش از encounter یا پس از آن؛ زمانِ نیاز به نگاه کردن به متن و telegraph هم‌زمان نباشد. متن روی دکمه‌های touch یا health bar ننشیند.
- ساعت zone، event-based و غیرمصرفی؛ بازگشت به zone قدیمی نشانِ timestamp همان zone است، نه عقب رفتن زمان جهان. اگر بخواهید countdown واقعی اضافه کنید، آن تصمیم نیاز به پژوهش و playtest مستقل دارد و با کشف آزاد اصطکاک دارد.
- اندازهٔ فونت در physical device بررسی شود؛ logical pixel به‌تنهایی واحد خوانایی phone نیست. Large Text و کنتراست بالا مستقل از aesthetic pixel-perfect جهان باشند. برای این گزارش هیچ اندازهٔ font به‌عنوان استاندارد پزشکی/دسترسی‌پذیری ادعا نشده است.

### latency و browser constraint

برای coordination روایی، پنجرهٔ دو نفر را ۱–۲ ثانیه یا state «held until partner arrives» شروع کنید و با latency واقعی تنظیم کنید؛ این عدد پیشنهاد prototype است. input دقیق هم‌فریم، rhythm مبتنی بر ping و packetهای واقعیِ شبکهٔ player را clue قرار ندهید. قطع اینترنت نباید در داستان به بی‌وفایی partner تعبیر شود. نمایش `Partner reconnecting` روشن و غیرسرزنش‌آمیز باشد.

این گزارش تغییر transport را توصیه نمی‌کند. Godot WebSocket را در native/web پشتیبانی می‌کند، اما docs هشدار می‌دهند TCP برای latency بازی سریع محدودیت دارد. implementation شبکهٔ فعلی باید جدا بررسی شود؛ lore فقط eventهای کم‌تعداد را از gameplay session موجود استفاده کند، نه infrastructure تازه.[[25]](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html)

### playtest پیشنهادی و معیار تصمیم

چهار نوع زوج: هر دو programmer؛ programmer + غیرprogrammer؛ PC + Android؛ یک سریع‌خوان + یک کندخوان. در جلسهٔ اول از هر زوج بخواهید بدون مرور دفتر توضیح دهند: «چه اتفاقی افتاد؟»، «چرا sunrise مهم بود؟»، «چه چیزی را حفظ کردید؟» سپس بپرسید کدام لحظه را با هم درباره‌اش حرف زدند.

**acceptance target پیشنهادی:** هر دو بتوانند سه جواب اصلی را به زبان خود بدهند؛ nobody برای فهم objective مجبور به خواندن سند اختیاری نشود؛ هیچ room به علت reader عقب‌مانده softlock نشود؛ late join بتواند دلیل مقصد بعدی را بفهمد؛ آخرین خط روی phone بدون zoom دستی خوانده شود. این‌ها هدف طراحی‌اند، نه نتایج آزمون انجام‌شده.

برای روایت اختیاری، موفقیت یعنی بعضی زوج‌ها ارتباط co-author و دعوت را کشف کنند و ارزشمند بدانند، نه اینکه تمام زوج‌ها همهٔ lore را پیدا کنند. اگر همه سؤال یکسان و برداشت دقیق یکسان دارند، ممکن است بیش‌ازحد توضیح داده باشید؛ اگر علت incident را هیچ‌کس نمی‌فهمد، شواهد اصلی ناکافی است.

## ۸. Anti-patterns — خطاهایی که باید عمداً حذف شوند

| خطا | مثال ملموس | چرا برای CLAWD مشکل است؟ | جایگزین |
| --- | --- | --- | --- |
| Wiki disguised as signs | تابلو ۴۰۰کلمه‌ای دربارهٔ تاریخ heap | روی phone نمی‌خواند و partner منتظر می‌شود | یک prop، یک log، یک arc محلی |
| Mystery without answer | تا آخر معلوم نشود امشب چه خراب شده | با مأموریت repair، علت مهم است؛ فلسفهٔ Limbo را کورکورانه کپی کرده‌اید | incident روشن، ontology Clawd باز |
| False optionality | پایان انسانی فقط با 100% notes | curious player پاداش می‌گیرد ولی بقیه پایان ناقص می‌گیرند | پایان پایه کامل، archive به کنش مشخص مربوط |
| Manual as PDF | صفحات پرریز TIS-100 در قاب کوچک | فرم مرجع با phone/action متفاوت است | card با diagram و دو خط |
| ARG as emotional gate | پایان خوب نیازمند Discord و cypher بیرونی | Animal Well نمونهٔ لایهٔ اجتماعی است، نه blueprint پایان co-op کوچک | همهٔ شواهد ضروری در خود بازی |
| Jargon as intelligence test | door فقط با دانستن pointer arithmetic باز شود | partner غیرprogrammer حذف می‌شود | icon، نمایش consequence، term دقیق ولی قابل‌آموختن |
| Catchphrase spam | `You're absolutely right!` در هر death | joke به سروصدا و سخرهٔ player بدل می‌شود | یک baseline و یک تغییر در arc |
| Cruel novice humour | mock کردن فراموشی semicolon | گرمای بازی و pairing را تخریب می‌کند | سیستم مضحک باشد، نه انسان کندتر |
| Reviewer as evil | critic را بکش تا release کنی | QA را enemy معنا می‌کند و با مضمون care تناقض دارد | objection مشخص و قابل‌حل؛ reviewer سپس guardian |
| Technically false boss | RACE CONDITION فقط سریع حرکت کند | term به sticker بدل می‌شود | order-sensitive consequence قابل‌دیدن |
| Mandatory melancholy | هر object یک داستان مرگ دارد | احساس اشباع و همهٔ zoneها هم‌صدا می‌شوند | فقط یک یا دو anchor انسانی اصلی |
| Dialogue over teamwork | long quip هنگام دو switch | سازندگان Portal 2 همین gagهای مزاحم را کنار گذاشتند | physical comedy و text پس از کنش |
| Desynchronised lore | PC note را دارد، phone هیچ سابقه‌ای ندارد | گفت‌وگو بر دو world state متفاوت بنا می‌شود | discovery مشترک، reading مستقل |
| Pixel-perfect illegibility | clue در یک pixel یا font 5×7 | mobile scale، touch و کنتراست از دست می‌روند | UI مستقل خوانا، clue چندرسانه‌ای |
| Fake glitch confusion | عمدی بودن corruption قابل‌تشخیص نیست | player نمی‌داند باید گزارش bug دهد یا puzzle حل کند | grammar ثابت visual/audio برای glitchهای authored |
| Real-time punishment for reading | countdown هنگام PATCHBOOK ادامه یابد | curiosity با مأموریت sunrise مجازات می‌شود | timestamp روایی، نه deadline مکانیکی |
| Lore outsourced to narrator | AI صدها توضیح حین بازی تولید کند | voice consistency، repeatability و QA از بین می‌رود | authored data و stateهای محدود |
| Historical replay explosion | هر commit کل نقشه را تغییر دهد | تیم کوچک به branching QA بزرگ می‌رسد | فقط سه snapshot room شناخته‌شده |

استفادهٔ این جدول از بازی‌های مرجع به معنای بد بودن آن بازی‌ها نیست: EXAPUNKS و TIS-100 برای خواندن/برنامه‌نویسی ساخته شده‌اند؛ CLAWD یک action metroidvania کوچکِ co-op روی phone است. محدودیت مقصد تعیین می‌کند چه چیزی منتقل شود.

## ۹. Top 15 recommendations — رتبه‌بندی اثر نسبت به هزینه

این ranking **قضاوت طراحی کیفی** است، نه دادهٔ measured از retention یا هزینهٔ واقعی تیم؛ امتیاز عددی ساختگی داده نشده. ترتیب با اولویت high impact + low cost، سپس dependencyهای سیستم و سپس امکانات optional تعیین شده است.

| رتبه | توصیهٔ مشخص | اثر | هزینه | dependency / خروجی قابل‌تحویل |
| --- | --- | --- | --- | --- |
| 1 | نسخه A را با یک incident و یک رابطه تثبیت کنید | بسیار بالا | low | story bible یک‌صفحه‌ای: truth، F1–F3، پایان پایه |
| 2 | clockها را timestamp غیرمصرفی نگه دارید | بسیار بالا | low | rule روشن در UI؛ خواندن هزینهٔ زمانی ندارد |
| 3 | سه حقیقت اصلی را در تصویر + log + کنش تکرار کنید | بسیار بالا | low | evidence matrix برای F1–F3 |
| 4 | هر zone یک forensic room داشته باشد | بالا | low | sketch با سه prop و یک سؤال محلی |
| 5 | jokeها را contextual و یک‌بارمصرف کنید | بالا | low | trigger table؛ هیچ quip تکراریِ death |
| 6 | THE REVIEWER را محافظ معیار بسازید، نه villain | بالا | low اگر boss آماده است | سه objection کوتاه و stateِ ally |
| 7 | خواندن local و discovery مشترک را جدا کنید | بسیار بالا | medium | state contract و تست هم‌زمان/late join |
| 8 | PATCHBOOK یک UI خوانای reusable داشته باشد | بسیار بالا | medium | card + سه tab + Large Text |
| 9 | برای هر boss یک post-event تغییر محیط بسازید | بالا | medium | یک flag، تغییر lamp/آب/route؛ بدون cutscene |
| 10 | پایان پایه کامل و archive پایان اختیاری semantic باشد | بسیار بالا | medium | دو variant یک vignette؛ نه شمارندهٔ completion |
| 11 | دو man page، کاربرد دوم toolهای موجود را آشکار کنند | بالا | low تا medium | knowledge gate قابل‌کشف پیش از سند |
| 12 | یک lamp و دو cursor را recurring anchor کنید | متوسط تا بالا | low | asset reuse و نقشهٔ حضور motif |
| 13 | GIT HISTORY را به سه snapshot room محدود کنید | بالا | medium | prefab variant، نه replay کل codebase |
| 14 | bench دونفره و یک conflict vista مشترک بسازید | متوسط تا بالا | low تا medium | moment بدون reward power و بدون pause |
| 15 | ecosystem کوچک دو-daemon را فقط بعد از تست core اضافه کنید | متوسط | medium | room-local behavior؛ simulation سراسری ممنوع |

### ترتیب اجرا و vertical slice

**مرحله اول — narrative lock:** truth نسخه A، مسیر F2، identity دو انسان، معنی sunrise، و پایان پایه تثبیت شوند. بیانیهٔ thematic: «یک چیز می‌تواند ناتمام و ارزشمند باشد.» هیچ zone تازه‌ای فقط برای lore اضافه نشود.

**مرحله دوم — slice سه-room:** SOURCE TREE → یک اتاق THE HEAP → نمونهٔ GIT HISTORY. یک prop recurring، یک سندِ دوکاره، یک repair با world-state change و یک interaction دونفره. از art و mechanics موجود استفاده شود.

**مرحله سوم — UI/network QA:** PATCHBOOK مستقل، wrap روی Android، discovery مشترک، local reading، reconnect و persistence. پیش از پر کردن همهٔ zoneها با متن، این قرارداد آزموده شود.

**مرحله چهارم — انتشار روایت:** ۲۴ card منتخب، ۳۰ ambient line، سه snapshot و یک vignette با دو variant. بعد از playtest، متن توضیحیِ قابل‌حذف حذف شود؛ ابتدا محیط تقویت شود.

**چیزهایی که فعلاً نسازید:** زبان رمزی کامل، graph editor شبیه ship log، NPC branching زیاد، simulation اکوسیستم سراسری، endingهای ترکیبی متعدد، narrator runtime مولد و ARG. هرکدام فقط وقتی core تجربه به‌تنهایی جذاب است و playtest نیاز مشخصی نشان می‌دهد وارد backlog شود.

## ۱۰. Sources — فهرست منابع و حدود ادعا

### منابع اصلی طراحی و توضیح سازندگان

**S01 — Harvey Smith & Matthias Worch، GDC 2010، What Happened Here? Environmental Storytelling.** [صفحهٔ GDC](https://www.gdcvault.com/play/1012647/what-happened-here-environmental)؛ [معرفی و مسیر download در سایت Worch](https://www.worch.com/2010/03/11/gdc-2010). منبع اولیه؛ metadata و شرح موضوع تأیید شد. ویدئوی کامل در این پژوهش مشاهده نشده؛ نقل‌قول‌های دقیق بر S02 تکیه دارند.

**S02 — Andrea Pitzer، گفت‌وگوی مستقیم با Harvey Smith، Nieman Storyboard، 2011.** [Harvey Smith on environmental storytelling](https://niemanstoryboard.org/2011/01/14/harvey-smith-on-environmental-storytelling-and-embedding-narrative). متن کامل خوانده شد؛ pull narrative، ارتباط props، استنتاج، امکان miss کردن و مثال معدنچی.

**S03 — Henry Jenkins، Game Design as Narrative Architecture، نسخهٔ مؤلف در MIT؛ مقاله منتشرشده در First Person، 2004.** [متن MIT](https://web.mit.edu/~21fms/People/henry3/games&narrative.html). منبع نظری اصلی؛ بخش embedded narratives بررسی شد: اطلاعات فضایی، بازسازی chronology، redundancy و مثال Myst. این منبع توضیح Team Cherry یا Playdead نیست.

**S04 — Holly Green، مصاحبه با Andrew Shouldice، Eric Billingsley و Kevin Regamey، Game Developer، 2022.** [Designing content for “no one”](https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic). بخش‌های مرتبط کامل خوانده شد؛ manual، stranger feeling، camera، soft gate و تفسیر bombable wall. ادعای بی‌معنا بودن glyphها در همین منبع با یادداشت سردبیر اصلاح شده؛ مبنای گزارش نیست.

**S05 — Kelsey Beachum، GDC 2021، Sparking Curiosity-Driven Exploration Through Narrative in Outer Wilds.** [اسلایدهای کامل PDF](https://media.gdcvault.com/GDC+2021/beachum_gdc_2021(1).pdf)؛ [فهرست سخنرانی‌ها در سایت نویسنده](https://kelseybeachum.com/projects). کل متن استخراج‌شدهٔ اسلایدها در دو بخش خوانده شد؛ سه سطح متن، arc محلی، چندکارکردی بودن text، humour، ثبت ship computer بدون inference و پایانِ مرتبط با کشف. ویدئو مستقلاً مشاهده نشده است.

**S06 — Sam Machkovech، مصاحبه با Billy Basso و Dan Adelman، Game Developer، 2024.** [Why Animal Well’s home-brewed engine was key to its success](https://www.gamedeveloper.com/design/why-animal-well-s-home-brewed-engine-was-key-to-its-success). متن کامل خوانده شد؛ layered puzzles، toy-like tools، community collaboration، اولویت جذابیت base game و محدودیت test رازهای عمیق. تاریخ عرضه و ارقام فروش مقاله در تحلیل استفاده نشده‌اند؛ نقل ادعای هنوز ناشناخته بودن رازها نیز fact اثبات‌شده فرض نشده است.

**S07 — Tim Mulkerin، مصاحبهٔ مستقیم Alex Preston، Unwinnable، 2015.** [Interview with Alex Preston](https://unwinnable.com/2015/12/02/interview-with-alex-preston-the-creator-of-hyper-light-drifter). متن کامل خوانده شد؛ lore داخلی، جهان بی‌متن، هزینهٔ teaching و اهمیت playtest. گفت‌وگو پیش از انتشار است؛ جزئیات هر صحنهٔ نهایی بازی را ثابت نمی‌کند.

**S08 — Game Developer، مصاحبه با Arnt Jensen و Dino Patti، 2012.** [Hanging in Limbo](https://www.gamedeveloper.com/business/hanging-in-limbo). بخش‌های مرتبط خوانده شد؛ تنهایی، خواهر، پایان باز و اهمیت احساس در برابر شرح دقیق. نتیجه‌گیری این گزارش دربارهٔ تفاوت اهداف Limbo و CLAWD تحلیل است.

**S09 — Game Developer، مصاحبهٔ طراحی Rain World، 2017.** [Crafting the complex, chaotic ecosystem of Rain World](https://www.gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-). بخش AI، room attractiveness، آزمایش layout و compromise tutorial خوانده شد؛ نقل‌های Joar Jakobsson و James Therrien/Primate. پیشنهاد «دو daemon» از این گزارش است، نه تجویز سازندگان.

**S10 — مصاحبهٔ مستقیم Erik Wolpaw و Chet Faliszek، 2011، نسخهٔ کامل منتشرشده توسط مصاحبه‌گر.** [Interview: Erik Wolpaw and Chet Faliszek, Valve](https://funambulism.com/2011/03/28/interview-erik-wolpaw-and-chet-faliszek-valve/). متن اصلی مصاحبه خوانده شد؛ Ratman murals، Aperture به‌عنوان شخصیت، تغییر GLaDOS، music و علت کاهش گفتار در Portal 2 co-op. منبع کلیدی بخش ۷.

**S11 — مصاحبهٔ Toby Fox، DEV 2 DEV، 2013.** [Toby Fox’s Undertale](https://meloshantani.wordpress.com/2013/05/25/toby-foxs-undertale-dev-2-dev-interview-1). excerpt جست‌وجو شامل توضیح Toriel و silent protagonist بود؛ بارگذاری کامل timeout داد. انتساب گفتهٔ Toriel در حد excerpt پشتیبانی دارد؛ تعمیم به تمام فرآیند نوشتن Undertale **unverified** است و در گزارش انجام نشده.

**S12 — Shacknews، مصاحبهٔ Davey Wreden، 2011.** [The Stanley Parable developer Davey Wreden](https://www.shacknews.com/article/70363/interview-davey-wreden-on-stanley-parable-remake-and-self-taught). بخش‌های مرتبط خوانده شد؛ سؤال نافرمانی از راوی، inquiry-driven design و گفت‌وگوی پس از بازی. دربارهٔ mod اولیه و remake آن زمان است، نه تمام ویژگی‌های Ultra Deluxe.

**S13 — Game Developer، گفت‌وگوی Lucas Pope، 2018.** [Return of the Obra Dinn was a bunch of appealing design problems](https://www.gamedeveloper.com/design/for-lucas-pope-i-return-of-the-obra-dinn-i-was-a-bunch-of-appealing-design-problems). بخش‌های طراحی خوانده شد؛ تغییر تمرکز به هویت، book، chapter/disaster structure و rigid core mechanic.

**S14 — Zachtronics، معرفی رسمی EXAPUNKS.** [EXAPUNKS](https://www.zachtronics.com/exapunks). tutorial، tip، commentary و secret information در TRASH WORLD NEWS؛ premise سال 1997 و phage. ادعای gameplay واقعی hacking از این منبع استنتاج نشده.

**S15 — Game Developer، مصاحبهٔ Zach Barth، 2018.** [How Exapunks dev Zachtronics finds the fun in hacking](https://www.gamedeveloper.com/design/how-i-exapunks-i-dev-zachtronics-finds-the-fun-in-hacking). متن کامل خوانده شد؛ hacker fantasy در برابر authenticity، zine و «mechanics برای نشان دادن جهان». Barth صریحاً بازی را معادل hacking واقعی نمی‌داند.

**S16 — Zachtronics، معرفی رسمی TIS-100.** [TIS-100](https://www.zachtronics.com/tis-100/)؛ [Reference Manual رسمی TIS-100P](https://www.zachtronics.com/images/TIS-100P%20Reference%20Manual.pdf). معرفی رسمی repair، manual و پرسش مؤلف/هدف را تأیید می‌کند. PDF برای شواهد فرم فنی استفاده شد؛ OCR دست‌نویس آن ناپایدار است، بنابراین متن خانوادگی آن نقل دقیق نشده است.

**S17 — Adam Fowler، گفت‌وگو با Matt Trobbiani، 2016.** [Interview with Hacknet Creator Matt Trobbiani](https://adamfowlerit.com/2016/04/interview-hacknet-creator-matt-trobbiani/). متن کامل خوانده شد؛ premise Bit و فایل‌های باقی‌مانده، iteration و توصیهٔ شروع کوچک. بخش premise شرح مصاحبه‌گر است؛ intent ریز تک‌تک سندهای Hacknet ادعا نشده.

**S18 — Team Cherry / Ari Gibson، معرفی اولیهٔ Hollow Knight.** [Introducing Hollow Knight](https://www.teamcherry.com.au/blog/introducing-hollow-knight). منبع رسمی؛ affliction، موجودات مشغول کار روزمره، ارتباط hero با جهان و ارتباط سبک کم‌جزئیات با efficiency. پیش از انتشار است؛ canon نهاییِ جزئیات از آن استنتاج نشده.

**S19 — Thomas Happ، 2012، معرفی Glitch Ray.** [And The Secret Feature Is…](http://www.axiomverge.com/blog/2012/10/23/and-the-secret-feature-is.html). منبع مستقیم مؤلف Axiom Verge؛ تغییر tiles و enemies، slowdown و corruption به سود player.

**S20 — Mister Morris Games، معرفی رسمی Haiku the Robot.** [Haiku the Robot](https://mistermorris.games/haiku-the-robot)؛ [صفحهٔ مجموعهٔ بازی‌ها](https://mistermorris.games/?haikutherobot). صفحهٔ رسمی از quirky robots، Arcadia، corruption و ability-based exploration می‌گوید. extraction یک بار فقط عنوان داد؛ excerpt رسمیِ جست‌وجو محتوای مرتبط را ارائه کرد. نظریهٔ دقیق قصد نویسنده **unverified** است؛ گزارش فقط ویژگی معرفی‌شده را تحلیل می‌کند.

**S21 — TJ Denzer، Shacknews، گفت‌وگو با Daniel Smith و Gareth Coker، 2020.** [Ori and the Will of the Wisps: Expanding life, magic, & whimsy](https://www.shacknews.com/article/116589/ori-and-the-will-of-the-wisps-interview-expanding-life-magic-whimsy). متن و excerpt مرتبط؛ جهان پرشخصیت‌تر، arc و questline، موسیقی و روایت. تفسیر world-state payoff برای CLAWD تحلیل این گزارش است، نه نقل مستقیم دربارهٔ Ginso Tree.

### منابع ثانویه برای جزئیات قابل‌مشاهدهٔ بازی‌ها

**S30 — Gamer Walkthroughs، Ori and the Blind Forest: Ginso Tree.** [Ginso Tree](https://gamerwalkthroughs.com/ori-and-the-blind-forest/ginso-tree/). متن کامل خوانده شد؛ پاک‌سازی دو سوی heart، restore شدن Element of Water و escape پس از آن. پشتوانهٔ مثال مشخص T27؛ توضیح قصد طراح نیست.

**S22 — Hollow Knight Wiki، Quirrel.** [Quirrel](https://hollowknight.fandom.com/wiki/Quirrel). بخش Blue Lake خوانده شد؛ امکان نشستن، غیبت بعدی و باقی‌ماندن nail. «Quirrel قطعاً در همین صحنه می‌میرد» **unverified**؛ در گزارش به‌صورت واقعیت بیان نشده.

**S23 — Celeste Wiki، Badeline.** [Badeline](https://celestegame.fandom.com/wiki/Badeline). بخش Reflection/همکاری خوانده شد؛ second dash پس از reconciliation. تفسیر مکانیکی مضمون، تحلیل گزارش است؛ ادعای مستقیم از Thorson دربارهٔ این تصمیم در این پژوهش تأیید نشد.

**S24 — Steam Community، Spoiler Safe Guide to Tunic.** [راهنمای پایان و رازها](https://steamcommunity.com/sharedfiles/filedetails/?id=2831517798). توضیح پایان share wisdom؛ منبع community، نه developer. از claim راهنماهای متعارض دربارهٔ الزام همهٔ fairyها استفاده نشده است.

**S25 — Inside Wiki، Alternate Ending.** [Alternate Ending](https://inside.fandom.com/wiki/Alternate_Ending). وجود ending اختیاری وابسته به hidden orbها؛ منبع ثانویه. هر تفسیر قطعی از اینکه چه کسی player را کنترل می‌کند **unverified** است.

### منبع فنی و منابع تکمیلیِ بررسی‌شده

**S31 — James C.، The Visual Storytelling of Hyper Light Drifter، Medium.** [مقاله](https://medium.com/@channelthecuz/the-visual-storytelling-of-hyper-light-drifter-c29570c4be4a). excerpt جست‌وجو جایگزینی دیالوگ با توالی تصاویر را شرح می‌دهد؛ بارگذاری متن کامل با 403 مسدود شد. این منبع ثانویه فقط برای مثال فرم تصویری T06 استفاده شده، نه برای قصد مؤلف یا تفسیر قطعی lore.

**S26 — Godot documentation، Using WebSockets.** [Using WebSockets](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html). منبع رسمی؛ پشتیبانی native/web و trade-off latency در TCP. نسخهٔ minor فعلی پروژه بررسی نشده، بنابراین این گزارش نسخه/transport تازه تحمیل نمی‌کند.

**S27 — Game Accessibility Guidelines.** [Readable default font size](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/)؛ [Full list](https://gameaccessibilityguidelines.com/full-list/). فهرست عمومی adjustable font و جلوگیری از وابستگی اطلاعات ضروری به audio تنها را نشان می‌دهد؛ بارگذاری تفصیلی صفحهٔ font در پژوهش کامل نشد. اندازه‌های UI گزارش پیشنهاد prototype هستند، نه اعداد منسوب به این منبع.

**S28 — ACMI، مصاحبهٔ Team Cherry دربارهٔ Silksong.** [From Ludum Dare to Pharloom](http://www.acmi.net.au/stories-and-ideas/from-ludum-dare-to-pharloom). excerpt مستقیم دربارهٔ منطق جهان و biomeها بررسی شد. چون موضوع Silksong است، برای اثبات جزئیات Hollow Knight اول استفاده نشده؛ صرفاً مسیر مطالعهٔ تکمیلی.

**S29 — Maddy Thorson، Four Years of Celeste.** [یادداشت مؤلف](https://maddythorson.medium.com/four-years-of-celeste-7dccdcc3f7f4). excerpt دربارهٔ ارتباط بازی و بیان شخصی مخاطبان بررسی شد؛ منبع جزئیات second dash نیست. تعمیم آن به روش دقیق نوشتن humour **unverified** است.

### پوشش بازی‌ها و شکاف‌های باقی‌مانده

- Hollow Knight: S18 + S22؛ تمرکز بر بیماری، کار روزمره، همراهی و غیاب. Tunic: S04 + S24؛ manual، دانش و ending. Outer Wilds: S05؛ قوی‌ترین شواهد مستقیم ساختار text و notebook. Animal Well: S06؛ لایه‌ها، ابزار و اجتماع.
- Inside / Limbo: S08 + S25؛ توضیح طراح برای Limbo قوی‌تر از شرح intent پایان Inside است. Celeste: S23 + S29؛ scene mechanics پشتیبانی ثانویه، intent مستقیم محدود. Undertale: S11؛ دادهٔ مستقیم Toriel در excerpt، نه مصاحبهٔ جامع پس از انتشار.
- Portal 1–2: S10؛ murals، صدای نهاد، arc GLaDOS و co-op. Hyper Light Drifter: S07؛ lore داخلی و هزینهٔ wordless. Rain World: S09؛ ecosystem و tutorial compromise. Ori: S21؛ characters، arcs و audio، نه بازسازی تفصیلی تمام cutsceneها.
- Haiku the Robot: S20؛ ویژگی‌های رسمی، بدون ادعای intent جزئی. Axiom Verge: S19؛ glitch mechanic. Return of the Obra Dinn: S13؛ identity و book. Hacknet: S17؛ فایل‌های یک شخص غایب. TIS-100 / EXAPUNKS: S14–S16؛ سند آموزشی/فرهنگی و repair mystery. Stanley Parable: S12؛ نافرمانی به‌عنوان پرسش طراحی.

**نتیجهٔ نهایی برای تولید:** CLAWD به encyclopedia یا narrator احتیاج ندارد. به یک incident روشن، یک رابطهٔ انسانی کوچک، چند evidence قابل‌آزمون، و repairهایی نیاز دارد که محیط را واقعاً تغییر دهند. عنوان آغازین «Its name is Clawd. It has until sunrise.» وقتی اثر می‌گذارد که پایان اجازه بدهد این helper، بعد از کمک درست، استراحت کند — و بازیکنان بدانند چه چیزِ کوچک اما مهمی را سالم به صبح رسانده‌اند.