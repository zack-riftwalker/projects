# CLAWD — پژوهش و سند اجرایی طراحی باس‌ها

نسخهٔ طراحی 1.0 • تاریخ پژوهش: 12 October 2026 • پلتفرم هدف: Godot 4 / browser / PC + Android touch / online co-op

**حکم اصلی:** هویت CLAWD باید از «حل‌کردن یک programming problem با حرکت و combat» بیاید؛ سختی از انتخاب و موقعیت‌گیری بیاید، نه از رقابت با latency یا تعداد دکمه‌های زیر یک انگشت.

**راهنمای اعتبار:** «شاهد» یعنی رفتار مستند بازی یا گفتهٔ سازنده؛ «تحلیل» یعنی استنباط طراحی این گزارش؛ «پیشنهاد CLAWD» یعنی طرح تازه، نه ادعای رفتار بازی مرجع. تمام ثانیه‌ها، اندازه‌ها، HPها و آستانه‌های پیشنهادی CLAWD، مقادیر آغازین prototype هستند و هنوز با build واقعی اعتبارسنجی نشده‌اند. هیچ telegraph بازی مرجع در این پژوهش frame-count نشده است. ادعاهای مشخصی که تأیید نشدند در بخش 9 با برچسب **unverified** آمده‌اند.

<table-of-contents />

## 1. Summary — ده درس اصلی

1. هر باس یک فعل حل‌مسئله داشته باشد: NULL را validate کن، MERGE را reconcile کن، LOOP را break کن؛ اسم و sprite کافی نیست.
2. سه attack پایهٔ خوانا با ترکیب‌های تازه، از ده attack مستقل و مبهم بهتر و ارزان‌تر است.
3. telegraph باید نوع خطر، محدوده، هدف و لحظهٔ commit را نشان دهد؛ فقط چشمک یا صدا کافی نیست.
4. دشواری phase بعد را با رابطهٔ تازهٔ الگوهای آشنا بالا ببر، نه با کوتاه‌کردن زمان واکنش مهمان.
5. punish window را از رسیدن واقعی بازیکن به باس حساب کن، نه از پایان animation حمله.
6. باسِ پاداش‌دهندهٔ ability، با kit پیش از reward شکست‌پذیر باشد؛ reward در یک اتاق امن بلافاصله کاربرد پیدا کند.
7. در co-op، هدف یک attack پس از commit ثابت بماند؛ بازیکن دوم حق ندارد ناگهان قربانی target switch شود.
8. hit lag compensation فقط نیمی از مسئله است؛ incoming damage، parry، revive و stateهای مشترک نیز قرارداد زمانی لازم دارند.
9. touch را با input buffering، aim assistance و مسیرهای پهن منصفانه کن؛ صرفاً HP بازیکن را زیاد نکن.
10. rematch را با یک قانون تازه بساز و gauntlet را پس از practice room؛ محتوای اختیاری نباید راه اصلی را گروگان بگیرد.

## 2. Boss design method — از theme تا encounter قابل‌تحویل

### 2.1. شواهد مقایسه‌ای بازی‌های مرجع

این جدول از رفتارهای مشخص درس می‌گیرد؛ «بهتر» یا «بدتر» رتبه‌بندی عینی بازی‌ها نیست.

| بازی / encounter | شاهد مشخص | تصمیم اجرایی برای CLAWD |
| --- | --- | --- |
| Hollow Knight — Hornet Protector | Lunge، حملهٔ هوایی و needle throw؛ Mothwing Cloak پس از پیروزی به دست می‌آید، نه پیش از آن. | NULL حرکت سریع را نمایش دهد اما ضدحمله‌اش با run/jump باشد؛ dash پاداش عبور از همان نوع gap باشد. [[1]](https://hollowknight.wiki/w/Hornet_Protector)[[2]](https://hollowknight.wiki/w/Mothwing_Cloak) |
| Hollow Knight — Mantis Lords | نخست یک مهاجم با Dash / Drop / Boomerang، سپس دو مهاجم با ترکیب همان vocabulary؛ Sisters of Battle هر سه را درگیر می‌کند. | MERGE اول هر head را معرفی کند، سپس overlap کنترل‌شده بسازد؛ یادگیری مقدم بر orchestration. [[3]](https://hollowknight.wiki/w/Mantis_Lords) |
| Hollow Knight — Nightmare King Grimm | Fire Bats بالا/پایین، چهار Flame Pillar در جای قبلی بازیکن، punish کوچک‌تر و غالباً دو Mask آسیب. | الگوی «bait → جابه‌جایی → punish» را بگیر؛ سرعت و آسیب آن را برای 3-pip touch کپی نکن. [[4]](https://hollowknight.wiki/w/Nightmare_King_Grimm) |
| Hollow Knight — Pantheons | gauntlet، Bindings اختیاری، variant و arenaهای متفاوت، اتاق‌های استراحت. | CI gauntlet سه‌باسی با practice جدا، استراحت و medal؛ نه شرط پایان داستان. [[5]](https://hollowknight.wiki/w/Pantheons) |
| Hollow Knight: Silksong — Lace | guard stance پس از بعضی comboها و counter به حملهٔ حریصانه؛ در phase دوم ناحیهٔ دایره‌ای چندضربه‌ای. Patch 1 دشواری Moorwing / Sister Splinter را اندکی کاهش داد. | REVIEWER به event قابل‌دید پاسخ دهد، نه input مخفی؛ tuning باس آغازین پس از playtest مشروع است. جزئیات Lace از guide ثانویه‌اند. [[6]](https://www.ign.com/wikis/hollow-knight-silksong/Lace_Boss_Guide)[[7]](https://steamcommunity.com/app/1030300/discussions/0/595159519774039622/) |
| Cuphead — Cagney / Grim / co-op | Cagney زمین را با roots می‌بندد؛ Grim در phase آخر projectileهایی دارد که با شلیک split می‌شوند؛ شریک با parry روح دیگری revive می‌کند. | phase رابطهٔ بازیکن و arena را عوض کند؛ «همیشه حمله نکن» را قبلاً آموزش بده؛ revive هوایی دقیق برای touch مناسب نیست. [[8]](https://cuphead.fandom.com/wiki/Cagney_Carnation)[[9]](https://cuphead.fandom.com/wiki/Grim_Matchstick)[[10]](https://en.wikipedia.org/wiki/Cuphead) |
| Celeste — Badeline / Reflection | پس از تقابل، همکاری و ادغام به dash دوم منجر می‌شود؛ traversal بخشی از حل تعارض است. سازنده buffering و corner correction را توضیح داده است. | پاداش agents باید پیامد حل همکاری باشد؛ توانایی نتیجهٔ مکانیکی theme شود، نه loot تصادفی. Chase بخش Chapter 2 و confrontation بخش Chapter 6 را یکی ندانیم. [[11]](https://celestegame.fandom.com/wiki/Chapter_6:_Reflection)[[12]](https://www.mattmakesgames.com/articles/celeste_and_forgiveness/index.html) |
| Ori and the Will of the Wisps — Kwolok | زمین خشک به آب تبدیل می‌شود؛ در آب Regeneration در دسترس نیست؛ Bash projectile و Swim Dash کاربرد تازه پیدا می‌کنند. | LEAK همان arena را به مسئلهٔ ارتفاع و مسیر تبدیل کند، ولی تغییر قانون heal را پنهانی اعمال نکند. [[13]](https://godisageek.com/ori-and-the-will-of-the-wisps-complete-boss-guide-kwolok/) |
| Metroid Dread — Kraid / Raven Beak | Kraid راهی برای نزدیک‌شدن به weak point با rail فراهم می‌کند؛ Bomb زودهنگام مسیر میان‌بر دارد. Raven Beak میان melee counter و flight تغییر vocabulary می‌دهد. | tool-check چند راه‌حل داشته باشد؛ final باس توانایی‌های موجود را ترکیب کند؛ میان‌بر mastery را بی‌دلیل ببندیم نه. [[14]](https://omegametroid.com/metroid-dread-walkthrough/bosses)[[15]](https://metroid.nintendo.com/dread/news/metroid-dread-report-vol-5/) |
| Prince of Persia: The Lost Crown — Vahram | time rewind و copy در fight نهایی؛ counter، grapple، teleport و حملات ranged راه‌حل‌های مختلف می‌دهند. تنظیمات مستقل HP، damage، parry و dodge وجود دارد. | REGRESSION «بازگشت خطا» باشد؛ final گزینه‌های موجود را به کار بگیرد؛ accessibility را یک محور مستقل نگه دار. [[16]](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide)[[17]](https://news.ubisoft.com/en-us/article/eQyaL5awqH4AXyovZUG58/prince-of-persia-the-lost-crown-accessibility-spotlight) |
| Nine Sols — Lady Ethereal | phase دوم cloneهای moveset آشنا؛ talisman روی اصل باعث توقف cloneها می‌شود؛ phase سوم اصل از disguise خارج می‌شود. | FORK از حمله‌های reuse‌شده و یک parent خوانا استفاده کند؛ شناخت parent باید کنترل crowd را پاداش دهد. [[18]](https://frostilyte.ca/2025/03/10/nine-sols-boss-guide-lady-ethereal)[[19]](https://intoindiegames.com/features/nine-sols-an-interview-with-red-candle-games) |
| Blasphemous — Expósito | مقیاس عظیم کودک، serpent با دو weak point، و علامت زمینی grabِ instant-kill. | spectacle را با silhouette و عضو متحرک بساز؛ instant-kill آن را برای online 3-pip کپی نکن. این داوری دربارهٔ تناسب CLAWD است، نه اجماع دربارهٔ کیفیت باس. [[20]](https://blasphemous.wiki.gg/wiki/Exp%C3%B3sito,_Scion_of_Abjuration) |
| Dead Cells — Boss Rush | چهار مسیر 3/5 باس، با/بدون modifier؛ patch همچنین warningهای Conjunctivius را اصلاح و overlap tentacle در bullet hell را حذف کرد. | rematch تغییر مکانیک باشد؛ پاک‌کردن overlap ناسازگار tuning است، نه ساده‌سازی بی‌هدف. [[21]](https://dead-cells.com/patchnotes/31) |
| Hades — Theseus / Extreme Measures | shield جلویی، spear با crosshair، Olympian Aid در نیمهٔ HP؛ انتخاب خدا به boonهای run وابسته است؛ EM3 chariot و حمله‌های تازه می‌دهد. | pluginها بتوانند یک variant معلوم بسازند؛ نه random counter-build ناعادلانه. God Mode مقاومت را پس از شکست بالا می‌برد. [[22]](https://hades.fandom.com/wiki/Theseus/Combat)[[23]](https://www.supergiantgames.com/blog/hades-faq/) |
| Enter the Gungeon — co-op | wiki سلامت دشمنان را +40% ذکر می‌کند؛ ghost یک mini-blank دارد؛ chest، Friendship Cookie و پایان باس revive می‌دهند. | شریک مرده کاملاً spectator نباشد؛ revive مقصد زمینی امن داشته باشد. این بازی local co-op است و مدرک راه‌حل latency آنلاین نیست. [[24]](https://enterthegungeon.wiki.gg/wiki/Co-op) |
| Furi | سازنده fight را به تمرین موسیقی و counterattack تشبیه می‌کند؛ Furier الگوهای بازطراحی‌شده دارد؛ dash با release و امکان charge است. | grammar و rematch را بگیر، dash-on-release و محدودیت بازگشت difficulty را برای touch کپی نکن. [[25]](https://www.thegamebakers.com/furi-and-creating-memorable-moments/) |
| Shovel Knight — Plague / Specter / Propeller | سازندگان از 3–4 حرکت و stitching صحبت می‌کنند؛ Plague reactive است نه pure random؛ pose/hitbox Specter کوچک و کندتر شد؛ حملهٔ بازیکن اغلب در طول fight ممکن است. | shared attack library + selection محدود؛ punish انحصاری تنها راه DPS نباشد؛ animation هزینه‌مند پس از graybox. [[26]](https://www.gamedeveloper.com/design/how-yacht-club-games-created-shovel-knight-s-specter-knight-plague-knight-and-propeller-knight-bosses) |

**منابع همیشه هم‌نظر نیستند:** Furi به wait-and-punish و انتخاب‌های عمداً محدودکننده ارزش می‌دهد؛ سازندگان Shovel Knight از player choice و امکان کشتن سریع با مهارت دفاع می‌کنند. این دو نسخهٔ واحد «باس خوب» نیستند. برای CLAWD ترکیب مناسب: آسیب عادی در بیشتر زمان‌های حضور باس ممکن، و recovery پس از counter محل DPS بیشتر. همچنین Furiِ سال 2016 تغییر رفت‌وبرگشتی difficulty را محدود می‌کرد، ولی Hades و The Lost Crown بر تنظیم متناسب با توان فرد تأکید دارند؛ با توجه به touch و internet، مسیر دوم مناسب‌تر است. [[25]](https://www.thegamebakers.com/furi-and-creating-memorable-moments/)[[26]](https://www.gamedeveloper.com/design/how-yacht-club-games-created-shovel-knight-s-specter-knight-plague-knight-and-propeller-knight-bosses)[[23]](https://www.supergiantgames.com/blog/hades-faq/)[[17]](https://news.ubisoft.com/en-us/article/eQyaL5awqH4AXyovZUG58/prince-of-persia-the-lost-crown-accessibility-spotlight)

**Badeline chase را جدا بخوانیم:** در Chapter 2 / Intervention، chaser مسیر حرکت قبلی را تقلید می‌کند و cloneهای بیشتر بدون افزایش سرعت، backtracking را خطرناک‌تر می‌کنند. این مثال «اسکلت آشنا + constraint تازه» و موضوع تعقیب‌شدن توسط بخشی از خود را به مکانیک تبدیل می‌کند. برای CLAWD یک echo trail ثابت در rematch RACE می‌تواند از همین ایده الهام بگیرد، اما با سرعت touch، preview کامل و بدون collision روی sprite دیرهنگام partner؛ scrolling chase برای MVP توصیه نمی‌شود. پاداش dash دوم متعلق به reconciliation در Chapter 6 است، نه به پایان همین chase. [[27]](https://celestegame.fandom.com/wiki/Intervention)[[11]](https://celestegame.fandom.com/wiki/Chapter_6:_Reflection)

### 2.2. Recipe هشت‌مرحله‌ای

1. **Theme → invariant.** یک قانون خرابی بنویس، نه یک استعارهٔ بصری: «LEAK با هر allocation فضای قابل‌استفاده را از دست می‌دهد تا release شود». یک جملهٔ شرط شکست و یک جملهٔ شرط حل بنویس.
2. **Invariant → player verb.** مشخص کن بازیکن دقیقاً چه می‌کند: bait / reclaim / isolate / reconcile / break / serialize. اگر جواب فقط «HP را کم می‌کند» است، theme هنوز mechanic نشده است.
3. **Ability ledger.** پیش از طراحی attack، kit واقعاً موجود را ثبت کن. NULL بدون dash؛ REVIEWER بدون catch؛ MERGE بدون agents؛ LEAK بدون double jump؛ CRAWLER بدون grapple؛ FIREWALL بدون phase. هر encounter دست‌کم یک counter با movement پایه داشته باشد.
4. **Attack vocabulary.** سه حرکت اصلی برای مرحلهٔ یادگیری، دو modifier برای escalation. هر attack پنج قطعه: announce → target lock → active → recovery → cleanup. برای هر قطعه state و زمان مستقل؛ animation منبع حقیقت damage نباشد.
5. **Phases.** در آغاز، یک مفهوم در هر cycle. phase دوم دو حرکت آشنا را با فاصله ترکیب کند. phase سوم فقط برای باس‌هایی که ایدهٔ سوم واقعاً دارند. عبور phase پس از recovery؛ HP threshold در میانهٔ attack فقط transition را queue کند.
6. **Arena.** ابتدا با rectangles در 384×216 تست کن. این viewport دقیقاً 24×13.5 tile است، نه 24×14 tile کامل؛ نیم‌tile پایینی و HUD را در collision/layout حساب کن. ارتفاع بیشتر برای WEB CRAWLER فقط وقتی دوربین هر دو بازیکن و منشأ خطر را پوشش دهد.
7. **Reward.** قبل باس یک preview امن؛ داخل fight استفادهٔ دشمن یا محیط؛ بعد fight یک آزمایش اجباریِ بی‌خطر و سپس یک کاربرد اختیاری. reward نباید تنها counter لازم برای همان باس باشد.
8. **Test & ship.** با touch و guest کند از ابتدا graybox را تست کن، سپس VFX. یک sheet با attack_id، tell، safe regions، target rule، recovery، cost و prereq، قرارداد کدنویسی AI agents باشد. هر agent نباید معنای «زرد»، iframe یا target lock را جداگانه اختراع کند.

### 2.3. Telegraph و punish — قرارداد پیشنهادی برحسب ثانیه

اعداد زیر برای Normal و guest با تأخیر دیداری حداکثر 0.25s پیشنهاد شده‌اند. telegraph از نخستین نشانهٔ واضح تا نخستین collision خطرناک است؛ travel time فقط وقتی مسیر projectile دیده شود جزو بودجه محسوب می‌شود.

| خانواده | Telegraph در host | شرط خوانایی | Recovery / punish |
| --- | --- | --- | --- |
| lunge / melee پایه | 0.90–1.10s | pose متفاوت + خط جهت؛ 0.40s پایانی aim ثابت | 0.75–1.10s؛ برای 1–2 swipe واقعی |
| projectile قابل catch | 0.75–0.95s + حداقل 0.45s سفر تا هدف | زرد + شکل diamond؛ spawn روی بدن بازیکن ممنوع | 0.80–1.20s؛ catch موفق 1.40s |
| slam / ستون در جای بازیکن | 1.10–1.30s | stencil زمینی؛ snapshot موقعیت حداقل 0.50s پیش از impact | 1.10–1.50s |
| sweep / beam / lane denial | 1.40–1.80s | footprint کامل؛ safe lane با عرض حداقل 3 tile، ترجیحاً 4 | 1.20–1.70s |
| transformation / flood | 2.00–3.00s | نشان‌دادن مقصد امن و تغییر سطح | 1.50–2.00s پیش از attack بعد |
| دو target / linked objective | 1.40–1.80s | دو marker شماره‌دار؛ هم‌پوشانی غیرممکن veto شود | stunهای pair دست‌کم 5s؛ MERGE نزدیک‌به‌هم 6s co-op / 8s solo |

**تفاوت tell و catch window:** طول tell 1s به معنای window یک‌ثانیه‌ای parry نیست. پیشنهاد: catch فعال 0.30s، buffer برابر 0.15s و cooldown حدود 0.45s؛ Assist فعال 0.45s و buffer 0.20s. catch همهٔ projectileهای yellow داخل arc را در یک activation برگرداند؛ duplicate event با همان projectile_id دوباره damage نسازد. عدد نهایی به hitbox و input delay وابسته است.

**بودجهٔ واکنش:** برای خطر غیرقابل‌پیش‌بینی، `T_host ≥ D_view + T_decision + T_escape + M`. فرض آغازین: D_view=0.25s، تصمیم=0.25s، خروج از stencil=0.25s، margin=0.15s؛ حاصل 0.90s. اگر خروج 0.55s طول بکشد، tell باید حداقل 1.20s شود. این عدد آزمون طراحی است، نه ثابت فیزیولوژیک. اگر latency اعلام‌شده RTT باشد، با one-way یا D_view برابر نیست؛ تعریف شبکه در بخش 5.

**Recovery قابل‌مصرف:** `P ≥ approach_time + attack_startup + desired_hits×hit_interval + safety`. اگر بازیکن 3 tile دور باشد و run فرضی 96px/s باشد، فقط approach برابر 0.50s است؛ recoveryِ 0.60s وعدهٔ دروغین است. با startup فرضی 0.10s، یک فاصلهٔ ضربه 0.25s و margin 0.15s، حداقل P=1.00s. سرعت واقعی kit باید جای این فرض بنشیند.

**Easy / Assist:** tell را ×1.25، recovery را ×1.20، safe corridor را +1 tile؛ incoming damage معمول همان 1 pip بماند و در Assist max HP یا shield قابل تنظیم باشد. **Hard اختیاری:** overlap و مسئلهٔ positioning سخت‌تر؛ حداقل بودجهٔ guest کم نشود. attack زرد را ناگهان غیرقابل catch نکن.

**خوانایی در pixel-art:** هر family silhouette مستقل: lunge شمشیر افقی، slam فشردگی عمودی، beam خط ممتد، catch diamond. زرد همیشه catchable؛ غیرقابل catch با خط شکسته/قفل هم علامت بخورد. خطر بالاتر از VFX agent و ضربهٔ هم‌تیمی render شود. GDCِ Jake Clark توضیح می‌دهد که anticipation سنگ‌قبر Cuphead با تغییر shape، color و perspective توجه را می‌گیرد؛ به یک palette flash بسنده نکن. [[28]](https://www.youtube.com/watch?v=RmGb-jU3uVQ)

### 2.4. HP، context meter و escalation

- فرمول فعلی فقط وقتی درست است که hit rate را **در کل زمان fight** اندازه بگیری. اگر نرخ حمله در زمان اتصال به باس را داری: `HP = (T_total − T_transition − T_forced_wait) × Σ(hit_rate_i × damage_per_hit_i × uptime_i) × k`. k ضریب residual tuning است، نه محل پنهان‌کردن uptime؛ آن را ابتدا 1.0 بگذار.
- مثال صرفاً محاسباتی: T_total=100s، transition=10s، نرخ اتصال=2 hit/s، damage=1 و uptime=0.35؛ HP=63. اگر 0.70 hit/s را قبلاً روی کل 90s فعال اندازه گرفته‌ای، دوباره ×0.35 نکن.
- هدف اولیه: NULL / REVIEWER حدود 60–90s، میانی 90–120s، اختیاری 120–150s، final سه phase مجموعاً 150–180s. این‌ها median پیروزی بازیکن آموخته‌اند؛ نخستین attempt و شکست‌ها را جدا اندازه بگیر.
- co-op از effective combined DPS محاسبه شود، نه همیشه ×2. اگر PC برابر 0.70DPS و phone برابر 0.40DPS باشد، نسبت 1.57 است؛ multiplier شروع 1.5–1.65 قابل‌آزمون است. revive و split positioning uptime را کم می‌کنند. عدد +40% Gungeon نمونه است، نه ضریب معتبر CLAWD.
- افزایش toughness بیش از یادگیری، باعث تکرار می‌شود. پس از اینکه بازیکن سه cycle را بی‌آسیب حل می‌کند، fight باید پیش برود. HP زیاد را با phase جدید یا کوتاه‌کردن downtime جایگزین کن، نه attack سریع‌تر.
- context meter شخصی باشد؛ مشترک‌بودن meter به PC اجازه می‌دهد مصرف phone را کنترل کند. agents با damage budget معلوم و cap دو agent در هر بازیکن؛ agent hit برای هر projectile/target deduplicate شود.
- heal ابتدا channel پیشنهادی 0.65s، meter قابل‌مصرف برای 1 pip؛ در هر cycle حدود 8–12s یک recovery امن 1.2s فراهم شود. اگر انتخاب heal/agents دو tap کوچک یا long-press مبهم می‌خواهد، مشکل UI است نه skill بازیکن.
- meter از hit واقعی به target آسیب‌پذیر پر شود؛ invulnerable shield و cloneهای تک‌ضربه‌ای قابل farm نباشند. برای MERGE پیش از reward، agents ممنوع؛ mechanic خودش بدون meter قابل‌حل است.

### 2.5. Optional / superboss / gauntlet

REVIEWER #2 همان شخصیت با یک دستور تازهٔ «review دو stage» است، نه 3×HP. الگوی Mantis Lords→Sisters of Battle و Dead Cells modifiers نشان می‌دهد اضافه‌کردن رابطهٔ تازه، محتوای reuse را موجه می‌کند. NKG نمونهٔ mastery شدید است، ولی معیار عادلانهٔ phone نیست. [[3]](https://hollowknight.wiki/w/Mantis_Lords)[[21]](https://dead-cells.com/patchnotes/31)[[4]](https://hollowknight.wiki/w/Nightmare_King_Grimm)

برای CLAWD، سه سطح مستقل: **Practice** انتخاب attack/phase با restart فوری؛ **Rematch** یک modifier مشخص با tooltip؛ **CI gauntlet** سه باس با kit ثابت، heal میان‌باسی و medal اختیاری. نسخهٔ طولانی‌تر فقط پس از اثبات replay value. disconnect نتیجهٔ شکست gauntlet محسوب نشود؛ snapshot بین باس‌ها نگه دار. challenge را با seed و Assist preset ثبت کن؛ progression ability را پشت no-hit، schedule واقعی یا gauntlet قرار نده.

## 3. Pattern catalogue — سی الگوی نام‌دار

Cost نسبت به library مشترک بخش 5: **Low** پارامتر/یک hitbox؛ **Medium** state مشترک یا geometry تازه؛ **High** دوربین، rollback گسترده یا چند subsystem. cost شامل QA online هم هست، نه فقط خطوط کد.

| # / Pattern | چیست و نمونهٔ واقعی | چرا کار می‌کند — تحلیل | کاربرد مشخص CLAWD | Cost |
| --- | --- | --- | --- | --- |
| 01 Committed Lunge | حرکت خطی به جهت ثابت؛ Hornet Protector Lunge. [[1]](https://hollowknight.wiki/w/Hornet_Protector) | خواندن pose و خروج از خط، بدون chase نامحدود | NULL Dereference در lane ثابت | Low |
| 02 Targeted Drop | حضور بالای جای قبلی و سقوط؛ Mantis Lords Lance Drop. [[3]](https://hollowknight.wiki/w/Mantis_Lords) | بازیکن با bait محل خطر را تعیین می‌کند | NULL Stack Drop با snapshot | Low |
| 03 Boomerang Return | رفت و برگشت یک projectile؛ Mantis Blade Boomerang. [[3]](https://hollowknight.wiki/w/Mantis_Lords) | یک شیء با دو مسئلهٔ ارتفاع | FIREWALL shield outbound/return | Low |
| 04 Alternating High–Low | laneهای بالا/پایین؛ NKG Fire Bats. [[4]](https://hollowknight.wiki/w/Nightmare_King_Grimm) | gap قابل‌خواندن به جای random rain | CRON دو lane با beat marker | Low |
| 05 Baited Pillar Trail | ستون‌های جای قبلی؛ NKG چهار Flame Pillar. [[4]](https://hollowknight.wiki/w/Nightmare_King_Grimm) | حرکت آرامِ آگاهانه از panic بهتر می‌شود | PRODUCTION deadline pillars، فقط 3 ستون | Low |
| 06 Ground-Wide Shockwave | موج افقی پس از slam؛ Kwolok spikes در دو جهت. [[13]](https://godisageek.com/ori-and-the-will-of-the-wisps-complete-boss-guide-kwolok/) | jump عمومی را با زمان ورود خطر می‌آزماید | LEAK Allocation موج پایین | Low |
| 07 Frontal Guard / Flank | shield رو به بازیکن؛ Theseus frontal block. [[22]](https://hades.fandom.com/wiki/Theseus/Combat) | positioning به اندازهٔ timing اهمیت دارد | FIREWALL front guard؛ پشت همیشه باز | Low |
| 08 Conditional Riposte | guard سپس counter اگر ضربه بخورد؛ Lace. [[6]](https://www.ign.com/wikis/hollow-knight-silksong/Lace_Boss_Guide) | «یک hit کمتر» تبدیل به تصمیم می‌شود | REVIEWER سومین swipe بی‌فکر را پاسخ می‌دهد | Medium |
| 09 Reflected Ammo | projectile دشمن به ضدحمله تبدیل می‌شود؛ Kwolok Light Spit با Bash. [[13]](https://godisageek.com/ori-and-the-will-of-the-wisps-complete-boss-guide-kwolok/) | دفاع resource و DPS می‌سازد | زردهای CRAWLER / FIREWALL با catch | Low |
| 10 Attack Becomes Access | حمله یا تغییر محیط، راه weak point می‌سازد؛ rail در Kraid. [[14]](https://omegametroid.com/metroid-dread-walkthrough/bosses) | خطر، فرصت traversal هم هست | leg slamِ CRAWLER پای ایمن برای pogo می‌گذارد | Medium |
| 11 Flooded Arena | phase زمین→آب؛ Kwolok. [[13]](https://godisageek.com/ori-and-the-will-of-the-wisps-complete-boss-guide-kwolok/) | مختصات ثابت ولی affordance متفاوت | LEAK سطح flood و platformهای پایدار | Medium |
| 12 Platform Denial | بستن موقت بعضی سکوها؛ Cagney roots. [[8]](https://cuphead.fandom.com/wiki/Cagney_Carnation) | حفظ مسیر بعدی مهم می‌شود | LEAK فقط یک سکوی warningدار را ببندد | Low |
| 13 Seed → Add | projectile به موجود تبدیل می‌شود؛ Cagney seeds. [[8]](https://cuphead.fandom.com/wiki/Cagney_Carnation) | پیشگیری ارزان‌تر از cleanup | FORK nodeها پیش از spawn قابل swipe | Low |
| 14 Shoot-to-Split Hazard | hit رفتار projectile را بدتر می‌کند؛ Grim phase 3 cluster fireballs. [[9]](https://cuphead.fandom.com/wiki/Grim_Matchstick) | trigger خودکار حمله همیشه بهترین پاسخ نیست | FORK فقط parent split؛ نسخهٔ اصلی نشانهٔ crack واضح داشته باشد | Medium |
| 15 Traveling Platforms | مبارزه روی platformهای متحرک؛ Grim cloud arena. [[9]](https://cuphead.fandom.com/wiki/Grim_Matchstick) | مسیر و DPS را به هم پیوند می‌دهد | فقط rematch LEAK؛ نه core mobile fight | Medium |
| 16 Center-Line Flamethrower | beam مرکز با بالا/پایین امن؛ Grim flamethrower. [[9]](https://cuphead.fandom.com/wiki/Grim_Matchstick) | danger footprint بزرگ ولی جواب ساده | PRODUCTION یک beam با دو ledge پهن | Low |
| 17 Radial Burst with Gap | حلقهٔ orb؛ Vahram fiery circles. [[16]](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide) | یافتن مسیر به جای واکنش به تک‌گلوله | LOOP چهار projectile با شکاف 4 tile | Low |
| 18 Inward Ring / Safe Outside | ring نزدیک‌شونده و shell؛ Vahram crystal shell. [[16]](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide) | بیش از یک counter route دارد | FIREWALL حلقه با خروج و flank، بدون phase اجباری | Medium |
| 19 Marked Line Slash | خطوط قبل از slash؛ Vahram. [[16]](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide) | تصویر میدان قبل از damage شکل می‌گیرد | REGRESSION خطای تست در lane نشانه‌دار | Low |
| 20 Learn One → Fight Two | Mantis Lords phase 1 سپس pair. [[3]](https://hollowknight.wiki/w/Mantis_Lords) | بار شناختی پیش از overlap تقسیم می‌شود | MERGE دو head با vocabulary معرفی‌شده | Medium |
| 21 Duo Role Asymmetry | Asterius close pressure + Theseus spear/guard. [[22]](https://hades.fandom.com/wiki/Theseus/Combat) | دو دشمن کار تکراری نمی‌کنند | DEADLOCK reader/writer؛ یکی zone، دیگری sweep | Medium |
| 22 Clone Identification | Lady Ethereal cloneها با hit ناپدید، اصل با talisman stun. [[18]](https://frostilyte.ca/2025/03/10/nine-sols-boss-guide-lady-ethereal) | شناخت درست crowd را خاموش می‌کند | FORK parent با PID ring؛ چشم‌بسته حدس‌زدن حذف شود | Medium |
| 23 State Rewind | Vahram با rewind دوباره بازمی‌گردد. [[16]](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide) | قانون زمان به ساختار encounter وارد می‌شود | REGRESSION فقط hazard flag را برگرداند، نه HP damage قبلی را | Medium |
| 24 Destroy Arena / New Topology | Plague Knight bombها floor را می‌برند. [[26]](https://www.gamedeveloper.com/design/how-yacht-club-games-created-shovel-knight-s-specter-knight-plague-knight-and-propeller-knight-bosses) | شخصیت بی‌ثبات مکانیک محیطی می‌شود | REGRESSION دو hatch ازپیش‌ساخته؛ physics destruction نخواهیم | Medium |
| 25 Huge Body / Small Weak Point | Expósito serpent با face و node؛ پس‌زمینهٔ عظیم. [[20]](https://blasphemous.wiki.gg/wiki/Exp%C3%B3sito,_Scion_of_Abjuration) | scale بدون ده‌ها attack asset | final یک rack عظیم و core کوچک اما حداقل 2 tile | Medium |
| 26 Phase Changes Combat Range | Raven Beak ground counter→flight missiles. [[14]](https://omegametroid.com/metroid-dread-walkthrough/bosses) | kit به صورت متفاوت دوباره فعال می‌شود | CRAWLER سقف→زمین، بدون عوض‌کردن کنترل | Medium |
| 27 Traversal Confrontation | Badeline بخش Reflection؛ پیشروی و تماس به جای HP سنتی. [[11]](https://celestegame.fandom.com/wiki/Chapter_6:_Reflection) | فعل بازی با تعارض داستانی هم‌راستا می‌شود | LOOP رسیدن به BREAK panel، بدون chase اسکرول‌دار | Medium |
| 28 Counter-Build Variant | Theseus Olympian Aid به boonهای run وابسته است. [[22]](https://hades.fandom.com/wiki/Theseus/Combat) | runها fresh، اما familyها ثابت می‌مانند | REGRESSION از دو تست مرتبط با plugin انتخاب کند؛ preview پیش از fight | Medium |
| 29 Rescue as Combat Action | Cuphead parry روح؛ Gungeon chest/cookie و ghost mini-blank. [[10]](https://en.wikipedia.org/wiki/Cuphead)[[24]](https://enterthegungeon.wiki.gg/wiki/Co-op) | همکاری در لحظهٔ بحرانی ملموس است | revive زمینی buffered و ghostِ صرفاً هشداردهنده | Medium |
| 30 Modifier Rematch / Gauntlet | Dead Cells boss modifiers؛ HK Pantheons و Bindings؛ Furier redesigned patterns. [[21]](https://dead-cells.com/patchnotes/31)[[5]](https://hollowknight.wiki/w/Pantheons)[[25]](https://www.thegamebakers.com/furi-and-creating-memorable-moments/) | mastery مصرف تازه می‌گیرد بدون asset set کامل | REVIEWER #2 و CI سه‌باسی؛ difficulty از grammar، نه latency | Low برای rematch / Medium برای mode |

**انتخاب برای تیم کوچک:** 01–09، 12، 13، 16، 19 را اول بساز؛ 10، 11، 20، 22 و 23 با state machine ثابت ارزش هزینه دارند. scrolling chase، تغییر real-time input mapping، physics destruction و rollback کل arena، برای نسخهٔ نخست High محسوب می‌شوند و توصیه نمی‌شوند.

## 4. Boss-by-boss proposals — چهارده encounter اجرایی

### قرارداد مشترک تمام باس‌ها

تمام طرح‌های این بخش **پیشنهاد اختصاصی CLAWD** هستند. اعداد، اندازه‌ها و rewardهای تازه باید prototype شوند. زمان‌ها Normal هستند و در Assist طبق بخش 2 افزایش می‌یابند. هر ردیف حمله شامل action، telegraph، counter و punish است. attackهای بدون punish مستقیم، هدفِ positioning/resource دارند و پس از حداکثر دو مورد به یک recovery می‌رسند.

**Dash در این سند فقط جابه‌جایی است، نه invulnerability.** اگر dash پروژه iframe دارد باید جداگانه ثبت شود؛ هیچ counter اصلی بر dash-throughِ جسم خطرناک متکی نیست. فقط damage iframe پس از hit قطعی است. parry/catch در kit فقط yellow projectile را برمی‌گرداند؛ melee sword خودبه‌خود parryable نیست. hazard عادی 1 pip؛ هیچ unavoidable damage، instant-kill یا double-hit همان impact نداریم.

co-op: player-body collision و friendly fire خاموش؛ helperها marker هدف و telegraph را نمی‌پوشانند. هدف و geometry attack در commit ثابت. safe lane حداقل 3 tile و پناهگاه دو‌نفره ترجیحاً 4 tile. ورود به phase با cleanup و grace؛ زمان‌های حمله در این جدول قابل‌جمع‌کردن دلخواه نیستند: scheduler حداکثر یک خطر اصلی و یک modifierِ سازگار را مجاز می‌کند.

**تعریف اصطلاح‌ها:** stagger یک recovery کوتاه عمومی است؛ latch حالت پایدارِ حل‌شدن objective است؛ stun window یک فرصت زمانی چندثانیه‌ای برای pair objective است. این سه را در کد با یک boolean واحد پیاده نکن.

### 4.1. NULL → dash

**Core idea:** باس نشانی را نشان می‌دهد، اما گاهی مقصد حافظه وجود ندارد. بازیکن valid reference را از empty slot تشخیص می‌دهد و باس را به dereference نامعتبر و recovery می‌کشاند. خود باس collision «ناموجود» روی هر tile ندارد؛ خراب‌کردن خوانایی مفهوم نیست.

**Kit ورودی:** run، variable jump، wall jump، swipe/pogo. dash و catch هنوز نیستند. **Arena:** کف ثابت 20 tile، دو دیوار climbable، سه slot علامت‌دار در پس‌زمینه؛ empty slot تنها خطر warningدار می‌سازد. سوراخ مرگ دائمی لازم نیست.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| N1 Dereference Lunge | pointer افقی مقصد و pose باریک 1.10s؛ 0.50s آخر direction ثابت؛ dash باس تا slot | jump از مسیر یا run بیرون از خط؛ نزدیک slot معتبر نایست | 1.10s پس از توقف؛ به سمت بازیکن teleport نمی‌کند |
| N2 Null Slot Collapse | یک ناحیهٔ 3 tile با outline توخالی 1.40s؛ عمودِ کوتاه error روی آن | run به یکی از دو طرف؛ خروج بدون dash در زمان tell قابل‌تست | core پایین می‌آید: 1.20s |
| N3 Stack Drop | cursor در جای snapshot هدف و shadow 1.20s، سپس سقوط | جابه‌جایی حداقل 2 tile؛ بالای هدف lock نمی‌ماند | 1.20s و pogo اختیاری |
| N4 Broken Address Fan | سه shardِ غیرزرد در یک fan از وسط؛ خطوط مسیر 1.20s، سرعت پیشنهادی 80px/s | از gap پهن عبور یا پشت slot سالم بمان؛ parry لازم نیست | 0.90s در فاصلهٔ melee |
| N5 Failed Lookup | باس یک slot توخالی را 1.50s بررسی می‌کند، سپس pulse حلقه‌ای با دو gap زمینی | gapها قبل از pulse روشن؛ run/jump، نه عبور از pulse با dash | پس از خطای lookup، 1.60s |

**Phases:** P1 از 100–60%: N1/N2/N3 تک‌تک؛ نخستین N2 بدون ترکیب. P2 از 60–0%: N4/N5 و N1→N2 با 0.60s فاصلهٔ خوانا؛ geometry حل‌پذیر veto می‌شود. برای باس اول phase سوم نساز.

**Reward hint:** NULL dashهای کوتاهِ commit‌شده انجام می‌دهد؛ کنار خروج gapای با ghost trail وجود دارد که قبل fight هم دیده شده. پس از پیروزی dash آزاد می‌شود؛ اتاق بعد یک gap بی‌خطر با respawn و سپس shortcut اختیاری.

**Co-op twist:** N3 فقط یک نفر را mark می‌کند؛ دیگری می‌تواند slot مقصد را با swipe validate کند و recovery باس را 0.30s افزایش دهد. مشارکت کمک است، شرط برد نیست. **Solo fallback:** همین validation با ضربهٔ خود بازیکن پیش از bait یا صرفاً dodge انجام می‌شود. **Cost:** Low؛ اولین تست library target lock و stencil.

### 4.2. THE REVIEWER → catch / parry

**Core idea:** باس یک policy پاسخ به حمله دارد: گارد را می‌بینی، ضربهٔ اضافه «comment» می‌گیرد، و بعد از commit می‌توانی از flank پاسخ بدهی. input-reading مخفی ندارد؛ response از hit event تأییدشده می‌آید و telegraph مستقل دارد.

**Kit ورودی:** dash موجود، catch هنوز نیست. **Arena:** زمین صاف، فضای flank در دو طرف، بدون corner spike. شمشیرهای melee غیرقابل catch؛ زرد فقط projectile.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| R1 Review Stance | گارد افقی 1.20s؛ hit به guard یک Reply را با wind-up 0.95s queue می‌کند | attack را متوقف کن یا flank؛ بازیکن کم‌lag نمی‌تواند counter فوری بسازد | اگر bait موفق: 1.00s بعد Reply |
| R2 Redline Thrust | خط forward و pose کشیده 1.00s؛ lunge دوطرفه نیست | jump روی مسیر یا dash دور از footprint | 1.00s پشت باس |
| R3 Inline Cut | شمشیر بالا 1.10s؛ slash قوسی بالای سر | زیر قوس به سمت پشت run؛ pogo این بار گزینهٔ بد است | 0.90s برای swipe افقی |
| R4 Comment Orb | از sword یک orb زرد پس از 0.95s، حداقل 0.60s سفر | پیش از reward dodge؛ باس بعداً خود orb برگشتیِ demonstration را catch می‌کند | 1.20s؛ catch بازیکن لازم نیست |
| R5 Request Changes | دو محدودهٔ متوالی با شمارهٔ 1/2؛ tell اول 1.40s، دومی 1.10s و زمان‌ها overlap ناسازگار ندارند | از اول به ناحیهٔ امن دوم منتقل شو؛ بعد از دوم نزدیک شو | 1.40s و انتخاب heal یا damage |

**Phases:** P1 100–55%: R2/R3/R4؛ guard فقط بعد از R2 و نشان واضح. P2 55–0%: R1/R5 فعال؛ دو slash را cue جدا اعلام می‌کند. حداکثر یک riposte queued؛ spam دو بازیکن دو riposte هم‌زمان نمی‌سازد.

**Reward hint:** در intro کوتاه و قابل skip، orb به یک mirror pad می‌خورد و REVIEWER آن را «catch» می‌کند؛ mirror فقط نمایش است، شرط fight نیست. پس از برد catch باز می‌شود؛ turret بی‌ضرر خروج همان diamond زرد را شلیک می‌کند تا یک در با return shot باز شود.

**Co-op twist:** responder هدف همان attackerِ hit trigger را حفظ می‌کند، نه آخرین کسی که به نزدیکش آمده؛ guard به یک سمت است و شریک flank می‌کند. **Solo fallback:** bait→jump-over→یک swipe پشت؛ damage ordinary نیز کافی. **Cost:** Medium برای conditional response؛ rematch تقریباً reuse.

### 4.3. MERGE CONFLICT → agents

**Core idea:** دو branch جدا پیش می‌روند و تا وضعیت هر دو reconcile نشده commit نهایی رخ نمی‌دهد. سرها واقعاً دو HP/state مستقل دارند، نه یک HP با دو صورت.

**Kit ورودی:** dash و catch، نه agents و نه double jump. **Arena:** دو pedestals در x≈6 و x≈18 tile، فاصلهٔ دسترسی زمینی ≤12 tile؛ landingهای 4 tile. یک خط merge وسط فقط indicator است، دیوار hard separation نیست.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| M1 Ours Slash | head چپ خط کف تا center را 1.10s نشان می‌دهد | jump یا عقب‌رفتن بیرون lane؛ وسط را با شریک خفه نکن | چپ 1.10s |
| M2 Theirs Arc | head راست سه orb با شکاف مشخص، 1.20s؛ یکی زرد | gap یا catch؛ هدف فقط یکی و aim commit ثابت | راست 1.10s |
| M3 Conflict Markers | دو strip از کف با `<<<` و `>>>`، 1.60s، gap مرکزی 4 tile | به gap مشترک برو؛ عرض برای دو نفر کافی | هر دو 1.30s |
| M4 Branch Swap | headها ghost destination دوطرفه 1.80s سپس جابه‌جا می‌شوند | destinationها را خالی کن؛ warp بدون damage است؛ swipe از center | 1.20s پس از settle |
| M5 Unresolved Burst | head باقی‌مانده بعد از disable دیگری، fan زرد 1.20s؛ inactive head حمله ندارد | dodge/catch و HP head دوم را کم کن | 1.40s؛ زمان reconcile در HUD |

**Phases:** P1 100–65% مجموع HP: معرفی M1/M2 نوبتی. P2 65% تا نخستین disable: M3/M4 با یک head مهاجم در هر زمان. P3 وقتی یک head به 0 می‌رسد: یک windowِ 6s co-op / 8s solo برای disable دومی. disableها اگر داخل window باشند final commit؛ اگر دیر شود اولی با 10% HP برمی‌گردد و دومی HP از‌دست‌رفته را پس نمی‌گیرد. یک burst warningدار، نه انفجار فوری. پس از دو miss، window +2s در Assist؛ Normal در سقف ثابت باقی می‌ماند.

**Arena gimmick / solution:** HP هر head همیشه دیده شود؛ علامت «آمادهٔ merge» روی head کم‌HP. latch موقت قابل‌دید؛ نیاز به هم‌زمانی frame-perfect نیست. اگر همین heal loop طول fight را زیاد کرد، بازگشت 10% را با shield یک‌ضربه‌ای جایگزین کن.

**Reward hint:** دو task icon از branchها جدا می‌شوند و پس از reconciliation تبدیل به دو helper agent می‌شوند. اتاق بعد دو switch با latch طولانی دارد؛ agents route را ساده می‌کنند ولی traversal اصلی hard-lock پشت AI pathfinding نیست.

**Co-op twist:** هر نفر head خود را به HP پایین می‌رساند، سپس اعلام آمادگی با نشان محلی؛ cross damage مجاز. **Solo fallback:** headها damage عادی می‌گیرند؛ window 8s برای عبور فاصلهٔ ≤12 tile و یک finish hit؛ هیچ agent قرضی یا meter اجباری نیاز نیست. **Cost:** Medium؛ state pair برای DEADLOCK reuse می‌شود.

### 4.4. THE LEAK → double jump

**Core idea:** هر allocation سطح memory مصرف‌شده را بالا می‌برد؛ بازیکن release valveها را فعال می‌کند و فضای حرکت را reclaim می‌کند. آبِ سبزرنگ به‌تنهایی «memory leak» نیست؛ تجمع و آزادسازی باید causal باشند.

**Kit ورودی:** dash، catch، agents، بدون double jump. **Arena:** floor یکدست، سه سکوی ثابت 4 tile با ارتفاعی قابل‌دستیابی با jump/wall jump فعلی؛ دو valve زمینی. flood یک height scalar است نه fluid simulation. بالاترین flood هرگز تمام landingها را نمی‌پوشاند.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| L1 Allocation Lob | سه blob در سه footprint ثابت؛ 1.20s shadow؛ landing سطح flood را نیم‌tile بالا می‌برد | run به gap یا سکوی کم‌ارتفاع؛ قبل برخورد با swipe یک blob را حذف کن | 1.00s |
| L2 Leak Surge | gauge یک level افزایش را 2.00s پیش‌نمایش می‌کند؛ موج از یک طرف | سکوی معلوم یا valve؛ مسیر بدون double jump باقی است | 1.50s باس روی ledge پایین |
| L3 Fragment Spit | توده می‌لرزد 1.00s، دو زرد با 0.60s فاصله و travel ≥0.50s | catch یا gap؛ orb برگشتی level را کمی پایین می‌آورد | 1.30s |
| L4 Platform Claim | یکی از سه سکوی بالایی 1.60s outline خطر؛ goo ستون کوتاه 0.80s | به یکی از دو سکوی دیگر؛ مسیر انتقال زمان‌دار و reachable است | در همین فاصله weak point پایین: 1.20s |
| L5 Garbage Collection Sweep | blob دو valve را با halo نشان می‌دهد 1.80s و کف را یک sweep می‌زند | jump sweep و swipe valve؛ release دو level و exposed core | 1.70s؛ valve hit اجباری هم‌زمان نیست |

**Phases:** P1 100–65%: L1/L3 با flood cap=1 tile؛ نخستین valve بدون خطر. P2 65–30%: cap=2 tile و L2/L4؛ جمع‌شدن واقعی levelها. P3 30–0%: cap=3 tile و L5 هر cycle، با reclaim دوره‌ای؛ فقط یک platform denied. مقادیر elevation به jump height واقعی مشروط‌اند، نه مختصات قطعی.

**Reward hint:** bubble padهای غیرخطرناک روی goo bounce دوم را نمایش می‌دهند، اما برای مسیر اصلی لازم نیستند. پس از برد double jump؛ خروج در دو مرحله: jump معمول تا platform پایین، سپس jump دوم تا در، با landing امن و auto-reset.

**Co-op twist:** valveها shared؛ یک نفر core را می‌زند و دیگری reclaim می‌کند؛ هر دو می‌توانند یک platform 4 tile را استفاده کنند. flood برای هر دو یک سطح authoritative دارد. **Solo fallback:** هر valve تنها کافی است و cooldown release=4s؛ damage window پس از valve طولانی است تا فاصلهٔ رسیدن جبران شود. **Cost:** Medium؛ height animation + سکوهای ثابت، بدون buoyancy پیچیده.

### 4.5. WEB CRAWLER → grapple

**Core idea:** robot traversalِ یک graph را طی می‌کند: frontier node علامت‌دار، edgeها مسیر خطر، backtrack فرصت hit. spider روی سقف بدون graph تصمیمی، فقط skin است.

**Kit ورودی:** double jump موجود، grapple هنوز نیست. **Arena:** سقف چهار node با اتصال‌های واضح؛ حداکثر ارتفاع لازم برای hit با double jump/up-swipe فعلی یا leg pogo ممکن. پیشنهاد اول یک screen؛ arena بلندتر فقط در صورت حل دوربین مشترک.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| W1 Follow Link | edge بین دو node 1.40s روشن؛ spider روی همان خط حرکت می‌کند | زیر edgeهای بالایی run؛ از leg footprint زمینی دور شو | node مقصد core 1.10s پایین می‌آید |
| W2 Fetch Drop | URL cursor روی snapshot هدف، shadow 1.20s؛ پا سقوط | run کنار؛ روی بخش سفیدِ پا pogo یا up-swipe؛ بخش سفید بعد impact غیرخطرناک | 1.30s |
| W3 Web Edge Sweep | دو رشته به cornerها 1.60s؛ beam رشته‌ای پایین می‌آید | gap 4 tile وسط یا ledge جانبی؛ grapple لازم نیست | 1.30s body پایین |
| W4 Packet Volley | cannons زرد، charge 1.00s و travel ≥0.60s | catch auto-aim به node فعال، یا jump از lane | hit برگشتی کابل را می‌برد؛ 1.60s |
| W5 Backtrack Crash | visited node با `BACK` و صدای جدا 1.80s؛ spider به node قبلی برمی‌گردد و دو leg می‌زند | node قبل از impact معلوم؛ بین legها جای امن 4 tile | core در فاصلهٔ معمول melee 1.50s |

**Phases:** P1 100–60%: مسیر nodeها ثابت و W1/W2/W4. P2 60–25%: W3، branch دوگزینه‌ای با frontier قبل از commit معلوم. P3 25–0%: W5، دو node خراب می‌شوند ولی landingهای پایین ثابت؛ تمام باس offscreen نمی‌رود.

**Reward hint:** web اتصال و pull-to-node را نمایش می‌دهد؛ پس از برد همین cannons به grapple anchor تبدیل می‌شوند. خروج با یک anchor داخل cone auto-target و سقوط بی‌خطر؛ سپس anchor اختیاری برای shortcut.

**Co-op twist:** W2 یک هدف، نفر دوم packet catch می‌کند؛ دو marker شخصی ولی graph مشترک. anchor/leg بعدی طوری انتخاب شود که هر دو در camera باشند. **Solo fallback:** W4 یا W5 دسترسی به weak point را می‌دهد؛ grapple هرگز پیش‌شرط نیست. **Cost:** Medium برای graph سادهٔ 4-node؛ scrolling co-op نسخهٔ High و خارج MVP.

### 4.6. THE FIREWALL → phase through thin walls

**Core idea:** policy عبور، جهت دارد؛ جلوی shield بسته، پشت باز. throw یک exception window می‌سازد؛ teleport مقصدی دارد که از قبل مشخص است. عبور خود باس از دیوار نازک اشارهٔ reward است، نه راه‌حل لازم بازیکن.

**Kit ورودی:** grapple موجود، phase هنوز نیست. **Arena:** دو firewall membrane با ضخامت 1 tile و ارتفاع 3 tile، از بالا قابل jump؛ دو ledge امن. shield route یک خط با turnaround marker است. geometry بن‌بست نمی‌سازد.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| F1 Shield Throw | سمت و مسیر رفت/برگشت 1.30s؛ throw با شفاف‌شدن جلوی body | jump shield؛ نزدیک body بی‌shield damage بده | body هنگام سفر 1.50s قابل hit؛ window از reach محاسبه شود |
| F2 Teleport to Exception | shield در node ثابت، destination outline 1.60s | marker را ترک کن؛ teleport بی‌damage، سپس slash فقط با tell تازه 0.95s | 1.10s بعد slash |
| F3 Port Scan | سه lane با علامت port؛ دو lane خطر پس از 1.60s و یکی باز | lane باز حداقل 4 tile؛ host collision نه از raw sprite | 1.30s |
| F4 Denied Packet | shield pulse 1.10s و orb زرد کند؛ shield هنگام reflect lock رو به تیر است | catch باعث overload و بازشدن؛ یا flank معمول | 1.60s overload؛ بدون catch 0.90s پس از fire |
| F5 Rule Reload | membraneها در 2.20s بالا می‌روند؛ boss پشت یکی phase می‌کند | از بالای دیوار کوتاه jump/grapple؛ landing پشت امن | weak point پشت برای 1.70s؛ phase لازم نیست |

**Phases:** P1 100–55%: F1/F3/F4، membrane خاموش. P2 55–0%: F2/F5؛ shield throw + teleport با دو tell جدا. به shared iframe shield آسیب PC/phone جداگانه رد نکن.

**Reward hint:** thin wall با الگوی raster متفاوت از solid wall؛ باس حرکت phase را در F5 نمایش می‌دهد. پس از برد phase فقط برای material مشخص؛ خروج یک membraneِ بی‌خطر دارد و راه برگشت با توانایی جدید shortcut می‌شود. clarity: phase به معنی عبور از همهٔ bullets یا تمام دیوارها نیست.

**Co-op twist:** یکی throw را bait می‌کند، دیگری rear damage؛ target-switch فقط بعد بازگشت shield و recovery. port scan برای دو بدن space دارد. **Solo fallback:** throw body را بی‌shield می‌کند و wall کم‌ارتفاع قابل‌عبور است؛ دو نفر برای بازشدن shield لازم نیست. **Cost:** Medium؛ throw/warp library و membrane ازپیش‌ساخته.

### 4.7. THE REVIEWER #2 — optional rematch

**Core idea:** review حالا دو stage دارد: «درخواست اصلاح» و «تأیید». response از historyِ attack family معلوم می‌آید، نه از input فعلی مخفی. دشمن از اشتباه آشنا انتقام می‌گیرد، اما با گارد خوانا.

**Reward پیشنهادی:** plugin «Review Cache»: پس از catch موفق یک swipe بعدی bonus کوچک معلوم می‌گیرد؛ قدرت ضروری مسیر اصلی نیست. **Arena:** arena باس نخست + دو perch کوتاه؛ بدون خطر لبه. همهٔ kit موجود، هیچ ability reset نمی‌شود.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| R2a Cached Riposte | آخرین family حملهٔ بازیکن با icon برای 1.30s؛ ضدافقی یا ضدpogo معلوم | family خود را عوض کن یا bait و flank؛ icon هرگز با late hit عوض نشود | 1.00s |
| R2b Double Review | دو thrust با خطوط 1/2؛ اول 1.20s، دوم tell مستقل 1.00s | jump اول، عقب‌رفتن/landing امن برای دوم | 1.40s بعد دوم |
| R2c Approve / Reject | یک diamond زرد و یک X غیرزرد؛ charge 1.20s، fire نوبتی با 0.70s gap | فقط diamond را catch؛ X را jump؛ شکل علاوه بر رنگ | 1.50s پس از return |
| R2d Cross-Comment | marker روی یک نفر 1.60s؛ دو slash از اطراف او اما center route باز | markشده به safe center؛ شریک از راه باز flank | 1.20s |
| R2e Final Sign-off | guard بسته 1.50s سپس lunge به مقصد نشان‌دار؛ یک زرد بعد recovery کوتاه | lunge را bait، سپس catch یا gap؛ نه melee parry | 1.60s |

**Phases:** P1 100–60%: R2a/R2b/R2c با cadence آشنا. P2 60–25%: R2d، تغییر role و familyهای cached. P3 25–0%: R2e؛ پایان نمایشی کوتاه، همان budget latency. HP آغازین حداکثر حدود 1.2× اولین باس با لحاظ kit قوی‌تر، نه 3×.

**Reward hint:** یک buff icon پس از catch باس روشن می‌شود؛ tutorial خروج cached swipe را روی dummy نشان می‌دهد. **Co-op twist:** cache جدا برای هر بازیکن و حداکثر یک response queued؛ hit مهمان با timestamp گذشته تصمیم commit‌شده را rewrite نمی‌کند. **Solo fallback:** یک cache و R2d فقط یک marker، بدون cross-player puzzle. **Cost:** Low–Medium با reuse؛ بعد از first REVIEWERِ polished بساز.

### 4.8. RACE CONDITION → plugin پیشنهادی «Mutex Dash»

**Core idea:** دو worker هم‌زمان read می‌کنند و سپس write ناهماهنگ انجام می‌دهند؛ ترتیب commit نتیجه را عوض می‌کند. این race خودِ encounter است، نه race واقعی netcode. host یک ترتیب قطعی برای taskها می‌سازد. بازیکن با زدن lock node، writeهای خطرناک را serialize می‌کند.

**Prereq پیشنهادی:** پس از FIREWALL؛ reward افزونهٔ dash است، نه افزایش iframe دائمی: نخستین dash بعد از catch موفق cooldown کمی کمتر می‌گیرد، با cap مشخص. **Arena:** دو مسیر افقی، node مشترک center و دو safe ledge؛ UI به جای متن ریز، iconهای `READ` و `WRITE` و شماره دارد.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| RC1 Stale Read | worker یک ghost از جای قبلی هدف در 1.20s ثبت می‌کند و slash همان‌جا | بعد read جابه‌جا شو؛ ghost تا write ثابت | 1.10s |
| RC2 Double Write | دو worker laneهای شماره‌دار را 1.70s نشان می‌دهند؛ ترتیب commit 1 سپس 2 با gap=0.80s | safe ledge یا swipe lock برای تبدیل به دو حملهٔ کاملاً نوبتی | 1.40s پس از write دوم |
| RC3 Lost Update | دو orb زرد به shared node می‌روند؛ charge 1.20s؛ برخوردشان یک burst قابل‌دید بعد 0.90s می‌سازد | یکی را catch یا node را پیش از collision swipe؛ gap بیرونی هم امن | 1.30s |
| RC4 Context Switch | target جدید با شماره 1/2 در 1.60s و arrow؛ سپس lunge | هدف جدید خودش tell کامل می‌گیرد؛ بیرون footprint | 1.20s |
| RC5 Critical Section | center با قفل 2.00s؛ دو beamِ کوتاه اطراف، center safe 4 tile | در critical section بمان یا lock را بشکن و beamها را cancel | 1.60s core وسط |

**Phases:** P1 100–60%: RC1/RC3 از یک worker، order ثابت. P2 60–25%: RC2/RC4 و worker دوم. P3 25–0%: RC5؛ lock تا recovery باقی است و یک resource قابل‌فهم کنترل توالی می‌شود. هر حملهٔ serialized بیش از دو write ندارد.

**Reward hint:** worker پس از تصاحب lock حرکت بعدی را زودتر انجام می‌دهد؛ بازیکن بعد fight با catch→dash روی dummy کاهش cooldown را می‌بیند. **Co-op twist:** شریک node را lock می‌کند و دیگری damage؛ «فشار هم‌زمان دو دکمه» لازم نیست و order host در هر دو HUD یکسان است. **Solo fallback:** lock با یک swipe و latch=6s؛ وقت کافی برای حرکت و ضربه. **Cost:** Medium برای event queue؛ صفر dependency روی thread timing واقعی.

### 4.9. INFINITE LOOP → plugin پیشنهادی «Break Point»

**Core idea:** boss یک cycle سه‌حرکتی را تکرار می‌کند؛ damage پذیرفته می‌شود اما یک shield دوره‌ای بازیابی می‌شود. بازیکن exit condition قابل‌دید را فعال می‌کند، نه اینکه با waiting نامحدود بمیرد. «infinite» در fiction، نه duration واقعی encounter.

**Reward:** plugin که پس از یک cycle دفاع موفق یک context bonus محدود می‌دهد؛ اگر تشخیص «cycle بی‌آسیب» پرهزینه شد، شرط را به سه catch موفق محدود کن. **Arena:** اتاق ثابت حلقه‌مانند با دو ledge، یک BREAK panel روی کف در هر دو سوی قابل‌دسترسی؛ panelها یک objective هستند، نه دو فشار هم‌زمان.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| IL1 Iteration Sweep | stroke افقی 1.20s، شمارهٔ `1` و arrow ثابت | jump sweep؛ safe side landing | 0.90s |
| IL2 Condition Fan | burst چهار projectile و gap پهن؛ 1.40s، شمارهٔ `2` | gap یا catch projectile زردِ تک؛ ورودی panel امن می‌ماند | 1.00s |
| IL3 Continue Pulse | کف جز دو ledge، stencil=1.60s، شمارهٔ `3` | بالا برو؛ بعد pulse BREAK دو ثانیه روشن می‌شود | 1.20s |
| IL4 Nested Loop | دو sweep قبلی با order 1→1 و tell مستقل 1.20s هرکدام | یک counter را دوباره، نه timing متفاوت مخفی | پس از دوم 1.40s |
| IL5 Exit Exception | هنگام زدن BREAK، core 1.80s charge با cancelable زرد | catch یا flank؛ panel interrupt قبلاً ثبت شده | shield خاموش و 2.00s damage/heal |

**Phases:** P1 100–60%: IL1→IL2→IL3 همیشه، یک چراغ BREAK در پایان. P2 60–0%: IL4 جای IL1، اما cycle و indicatorها معلوم. panel hit shield regeneration را برای 10s قطع می‌کند؛ دو interrupt حداقل لازم برای دیدن مفهوم، ولی hitهای معمول HP را عقب نمی‌برند. پس از سه cycle بی‌interrupt، panel روشن می‌ماند و arrow hint می‌دهد؛ softlock نمی‌سازد.

**Arena / reward hint:** هر interrupt یک cycle را به خروج قابل‌دید تبدیل می‌کند؛ icon context پس از دفاع به breakpoint می‌رود. خروج fight یک loop turret بی‌خطر دارد که plugin را روی آن می‌آزمایی. **Co-op twist:** یکی cycle را bait، دیگری panel؛ panel hit برای همه معتبر و attackهای pending پس از interrupt cancel می‌شوند. **Solo fallback:** دو panel جایگزین، هر کدام latch=10s و هزینهٔ meter صفر. **Cost:** Low–Medium؛ finite state machine معمول، نه rewind.

### 4.10. REGRESSION → plugin پیشنهادی «Test Harness»

**Core idea:** patchِ یک feature، یک bug قدیمی را بازمی‌گرداند؛ بازیکن تست invariant را اجرا می‌کند تا آن bug برای ادامهٔ fight دوباره نیاید. boss باید dependency ملموس داشته باشد: زدن core فعلی یکی از hazard flagهای قدیمی را روشن می‌کند. HP یا ability بازیکن rewind نمی‌شود.

**Reward:** Test Harness یک shield تک‌مصرف برای نخستین hazard محیطی پس از checkpoint، نه invulnerability هر fight؛ cap و نمایش واضح. **Arena:** همان room پایه با دو hatch ازپیش‌ساخته، یک TEST console نزدیک center و دو indicator بزرگ. slate انتخاب تست‌های fight قبل شروع قابل‌دید است.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| RG1 Reopened Bug | icon قدیمی N1 و lane pointer؛ 1.30s؛ lunge NULL reuse | jump/run؛ توانایی جدید ممکن کمک کند ولی لازم نیست | 1.10s |
| RG2 Broken Fix | یک hatch با diagonal stripes در 1.80s باز می‌شود و goo کوتاه می‌آید | به کف ثابت یا ledge، نه افتادن در pit مرگ | 1.20s core کنار console |
| RG3 Rollback Wave | ghostِ flood level قبلی 2.00s؛ flood فقط تا 1 tile بازمی‌گردد | ledge ثابت یا swipe TEST و cancel | 1.50s |
| RG4 Unit Test Barrage | دو زرد و یک X با charge=1.30s، fire فاصله‌دار 0.75s | catch زردها، dodge X؛ resolve test به damage core کمک می‌کند | 1.50s |
| RG5 Dependency Chain | یک bug icon→دیگری با arrow، کل chain در 1.80s معلوم؛ دو attack آشنا نوبتی | TEST فعلی را swipe، سپس counter attack اول/دوم؛ هیچ surprise ناشناخته | 1.70s |

**Phases:** P1 100–60%: RG1/RG2، فقط یک flag. P2 60–25%: RG3/RG4؛ تست موفق یک flag را permanently برای همان attempt پاک می‌کند. P3 25–0%: RG5 با حداکثر دو flag؛ نتیجهٔ تست‌ها حفظ می‌شود و chain خودش بلافاصله همه را دوباره روشن نمی‌کند.

**Arena gimmick:** هر 20% damage به core، bug flag بعدی queue می‌شود؛ فقط پس از recovery و tell تازه فعال. TEST با یک hit و سپس surviveِ آزمون کوتاه پاک می‌شود؛ button mash یا کدنویسی متنی ندارد.

**Reward hint:** یک test shield محیطی جلوی نخستین wave را می‌گیرد؛ پس از برد، همین icon روی بازیکن ظاهر و در اتاق امن به hazard بی‌ضرر مصرف می‌شود. **Co-op twist:** یکی patch می‌کند، دیگری test؛ hit جدیدی که با lag جبران شد، flag commit‌شده را retroactively تغییر نمی‌دهد. **Solo fallback:** console در ≤3 tile weak point، window=6s، testها ترتیبی. **Cost:** Medium؛ تنها hazard flagها و prefabها rewind می‌شوند. rollback کل دنیا High و ناموجه است.

### 4.11. FORK BOMB — optional → plugin پیشنهادی «Process Limit»

**Core idea:** هر child میل به تکثیر دارد و ظرفیت arena را مصرف می‌کند. بازیکن parentهای مولد را terminate و spawnهای درحال‌آماده‌سازی را interrupt می‌کند. عملکرد واقعی browser نباید برای نمایش theme بمباران شود.

**Arena:** چهار spawn socket ثابت، حداکثر چهار موجود کوچک فعال و یک parent؛ budget اولیه حداکثر هشت projectile. PID ringِ parent همیشه متفاوت، نه شناسایی با یک pixel. **Reward:** agents موجود فقط یک بار در summon هدف مناسب‌تر انتخاب می‌کنند یا مدت کوتاه افزایش می‌یابد؛ DPS cap حفظ می‌شود.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| FB1 Fork Bud | bubble child با ring پرشونده 1.80s روی socket | با یک swipe قبل spawn؛ missed bud یک child، نه چندین child فوری | parent 1.20s |
| FB2 Child Pounce | child با شماره و خط hop 1.20s؛ فقط یکی مجاز به attack | jump/dash دور؛ child با 1–2 hit می‌میرد | parent هم‌زمان آسیب‌پذیر، 1.00s |
| FB3 Parent Broadcast | سه زرد fan، 1.30s و gap 4 tile | catch به parent auto-target یا gap | parent stagger 1.50s |
| FB4 Copy Storm | دو socket مختلف 1.80s؛ childها فقط threat-mark می‌شوند، فعال‌شدن 0.80s فاصله | نزدیک‌ترین bud را terminate، دیگری را بعد؛ از corner escape مسیر دارد | 1.40s |
| FB5 Process Collapse | parent خاموش 2.00s، childها با timer واضح یک pulse زمینی می‌دهند | jump یا بیرون footprint؛ مرگ child فوراً انفجار ندارد | همهٔ childها cleanup، parent 1.70s |

**Phases:** P1 100–60%: FB1/FB2/FB3، cap child=2. P2 60–0%: FB4/FB5، cap child=4؛ تعداد attacker هم‌زمان همچنان یک. شکست parent یا stagger بزرگ، buds pending را cancel می‌کند. این کپیِ disguise پیچیدهٔ Lady Ethereal نیست؛ parent واضح باقی می‌ماند.

**Reward hint:** ring ظرفیت process با کشتن child جا باز می‌کند؛ reward با نمایش دو agent و عدد cap=2 آموزش داده می‌شود. **Co-op twist:** هر نفر socket خود را cleanup، parent مشترک؛ spawn budget با co-op دو برابر نمی‌شود. **Solo fallback:** buds 2.20s آماده‌سازی در solo و یک termination کافی برای دو socket linked؛ aggressive damage هم قابل‌حل. **Cost:** Medium؛ object pooling و budget scheduler ضروری.

### 4.12. DEADLOCK — optional → plugin پیشنهادی «Lock Breaker»

**Core idea:** دو worker هرکدام یک lock نگه داشته و lock دیگری را می‌خواهند؛ به محض دو stun هم‌پوشان، lockها release می‌شوند. قبل از این وضعیت هر دو attack دارند، اما vulnerability pair یک شرط state است، نه هم‌زمانی یک frame.

**Prereq:** agents در kit هستند، اما meter برای حل اجباری نیست. **Arena:** دو worker با فاصلهٔ ≤10 tile، یک lock pad center، کف ثابت. **Reward:** catch بعدی روی یک projectile armoredِ زرد bonus stagger کوچک می‌دهد؛ رنگ زرد شرط پایه می‌ماند.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| DL1 Hold A | worker چپ floor sweep با tell=1.20s؛ recovery یک lock icon باز | jump و swipe به lock | stun چپ 5s co-op / 8s solo |
| DL2 Wait B | worker راست ستون snapshot با tell=1.40s | run بیرون و up-swipe weak point پایین | stun راست همان window |
| DL3 Circular Wait | دو beam طرفین، center gap=4 tile؛ tell=1.80s | center یا یک lock hit قبلی beam همان سمت را cancel | پس از beam 1.40s |
| DL4 Resource Request | orb زرد از یکی به دیگری، tell=1.30s | catch orb به emitter؛ stun فقط روی همان worker، نه هر دو خودکار | window pair آغاز می‌شود |
| DL5 Timeout Recovery | اگر window تمام شد، worker 1.50s indicator را می‌بندد و یک sweep می‌زند | بیرون footprint؛ در گذار می‌توان دوباره stun کرد | 1.20s؛ HP restore ندارد |

**Phases:** P1 100–60% HP pair: DL1/DL2 نوبتی؛ وقتی هر دو stun هم‌پوشانند، shared core 3s باز و damage وارد می‌شود. P2 60–0%: DL3/DL4، lock order دوطرفه؛ DL5 فقط بعد miss. یک successful pair، health threshold را خودکار skip نمی‌کند؛ damage واقعی را نمایش بده.

**Solo fallback مهم:** stun اول 8s؛ در این مدت worker دوم **فوراً** Resource Requestِ warningدار و قابل‌حل را اجرا می‌کند، نه اینکه تا پایان stun صبر کند. center pad با swipe در solo یک lock را نگه می‌دارد؛ agents اختیاری‌اند. اگر attack RNG فرصت stun دوم نمی‌دهد، scheduler ناقص است.

**Co-op twist:** هر نفر یک worker؛ هم‌پوشانی window، نه input synchronous. بازیکن incapacitated pair را به solo mode در recovery بعدی می‌برد. **Reward hint:** شکستن lock زرد با projectile برگشتی stagger می‌دهد؛ dummy خروج همین رابطه را نمایش می‌دهد. **Cost:** Medium؛ pair state MERGE reuse، ولی condition «هم‌زمان stun» متفاوت است.

### 4.13. CRON — optional → plugin پیشنهادی «Scheduled Task»

**Core idea:** taskها با schedule قابل‌پیش‌بینی اجرا می‌شوند و بازیکن با فرصت‌های بین jobها fight می‌کند. music beat اطلاعات اضافی است؛ collision به audio دستگاه مهمان گره نمی‌خورد.

**Schedule:** بر مبنای simulation داخل session، مثلاً هر سومین rest در hub؛ بعد اولین ظهور، practice/rematch همیشه از terminal قابل‌اجرا. clock واقعی، timezone یا انتظار شبانه ممنوع. **Arena:** یک screen با چهار beat lamp در بالا و دو landing پهن؛ همهٔ مهمات روی shared attack clock. **Reward:** هر 12s simulation یک context bonus کوچک، با timer واضح؛ اختیار heal/summon از بازیکن گرفته نمی‌شود.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| C1 On-Beat Sweep | دو beat preparation و خط افقی، حداقل 1.20s؛ سپس sweep | jump برحسب lamp، نه شنیدن تنها | یک beat خالی 0.80–1.00s |
| C2 Offbeat Packet | diamond پس از 1.20s، یک orb زرد با travel≥0.60s | catch/gap؛ lamp نیم‌beat نشان دارد | 1.10s |
| C3 Scheduled Pillars | سه جای ثابت با 1/2/3 و countdown=1.80s؛ هرکدام 0.80s فاصله | حرکت پیوسته در safe مسیر؛ echo beatهای همه در HUD | 1.50s |
| C4 Missed Job | یک beat چراغ خاموش می‌ماند و `SKIP` با 1.50s نشان می‌دهد؛ بعد strike در beat بعد | منتظر trigger بصری بعدی، نه parry روی صدای قبلی | 1.20s |
| C5 Batch Run | دو attack آشنای C1/C2، timeline همهٔ cueها 2.20s | یکی jump، دیگری catch یا فاصله؛ time budget حفظ | 1.80s پایان batch |

**Phases:** P1 100–60%: C1/C2 و tempo ثابت پیشنهادی 75BPM (0.80s/beat). P2 60–0%: C3/C4/C5؛ BPM تغییر نمی‌کند، subdivisionها با marker معرفی می‌شوند. «سریع‌ترشدن آهنگ» راه ارزانی برای شکستن mobile timing است و توصیه نمی‌شود.

**Co-op twist:** دو نفر یک timeline می‌بینند؛ C3 هدف جای هر دو را هم‌زمان track نمی‌کند، socket ثابت دارد. guest audio offset قابل تنظیم، visuals زمان اصلی. **Solo fallback:** همهٔ jobها یک پاسخ حرکت دارند؛ هیچ rhythm-perfect double input لازم نیست. **Reward hint:** timer job خودش resource پاداش می‌دهد و در hub بعد timer plugin اجرا می‌شود. **Cost:** Medium؛ اگر audio scheduling budget نیست، MVP صرفاً visual clock و یک loop ثابت موسیقی.

### 4.14. Final boss در PRODUCTION — نام پیشنهادی «THE DEPLOYMENT»

**Core idea:** چیزی که در staging درست کار می‌کند، در production با load و dependencyهای متفاوت می‌شکند. هدف پیروزی «افزایش chaos تا HP صفر» نیست؛ تست، rollback امن و deploy موفق است. جملهٔ «it works on my machine» باید به دو محیط با rules واضح اشاره کند، نه کنترل‌های خراب عمدی.

**Reward پیشنهادی:** plugin نمایشی «Release Build» و پایان بازی؛ اگر postgame دارد، انتخاب checkpoint/practice آزاد، نه ability ضروری جدید. **Arena:** یک screen، silhouette عظیم rack در پس‌زمینه، core قابل‌hit روی کف؛ دو ledge 4 tile؛ staging plate / production plate با **icon و texture** متفاوت. camera shake اختیاری، phase flash آسیب نمی‌زند.

| Attack | Action و telegraph | Counter | Punish |
| --- | --- | --- | --- |
| P1 Deadline Pillars | سه ستون از snapshot هدف؛ اولین tell=1.40s، هر ستون cue کامل و 0.90s gap | bait با حرکت یک‌جهته؛ turn تنها به safe lane معلوم | core 1.30s بعد ستون سوم |
| P2 Works on My Machine | دو plate نشان می‌دهند چه خطری در کدام محیط فعال است؛ 2.20s، سپس beam فقط production | روی staging امن یا ledge مشترک؛ عوض‌کردن کنترل/physics ممنوع | 1.60s پس از beam |
| P3 Hotfix Rollback | flag قدیمی flood یا NULL، با icon 2.00s؛ فقط یکی به ترتیب ثابت | counter آموخته‌شده؛ TEST swipe cancel اختیاری | 1.50s |
| P4 Traffic Spike | پنج projectile در fan با gap 4 tile، charge=1.40s؛ یکی زرد | gap/catch؛ density با co-op دوبرابر نمی‌شود | catch 1.70s، dodge 1.20s |
| P5 Deploy Window | shield کف با timer=2.00s و دو RELEASE pad فعال | به هر pad یک swipe؛ یک latch کافی، سپس core melee | 2.20s برای damage/heal؛ هم‌زمانی نفرها لازم نیست |
| P6 Final Commit | پس از HP کم، سه cue آشنای P1/P4/P5 روی timeline 2.50s؛ attackها نوبتی و هرکدام tell کامل | همان counterهای یادگرفته؛ pad سوم پایان را commit می‌کند | پایان phase؛ نه «یک حملهٔ تازهٔ instant kill» |

**Phases:** P1 «Staging» 100–65%: P1/P4/P5 با arena خنثی و targetهای تک. P2 «Production Load» 65–25%: P2/P3، plateها باید ربط محیط و hazard را واقعاً نشان دهند. P3 «Release Candidate» 25–0%: P6 فقط یک sequence تعریف‌شده، core همچنان damage می‌گیرد و deploy شرط خاتمهٔ نمایشی است. HP bar سه segment را از اول نشان بده؛ fake death و refill پنهان نداشته باش.

**Arena gimmick / spectacle:** روی rack نور queueها و deadline iconها شدت می‌گیرند؛ ground topology عوض نمی‌شود. از خط‌نوشته‌های خیلی ریز برای mechanic استفاده نکن. تغییر موسیقی/lights هزینهٔ کمتر از sprite set دوم کامل دارد.

**Reward hint:** release pad در هر phase UIِ plugin خروج را روشن می‌کند؛ بعد پایان همان terminal practiceهای postgame را باز می‌کند. **Co-op twist:** taskها نقش damage / safety دارند و قابل‌تعویض؛ هیچ plate فقط برای player 2 قفل نیست. یک downed player workload را در recovery بعدی solo می‌کند. **Solo fallback:** همهٔ padها latch=8s؛ یک نفر کافی و final sequence دارای safe route مستقل از partner است. **Cost:** Medium با reuse از NULL/LEAK/REGRESSION؛ full environment rollback یا چند دوربین High و حذف.

### 4.15. نقشهٔ reward بدون تناقض ability

| باس | پیش از fight می‌آموزد / می‌آزماید | چیزهایی که نباید لازم شوند | Showcase بعد از fight |
| --- | --- | --- | --- |
| NULL | commitment و jump/run | dash، catch | gap و shortcut dash |
| REVIEWER | فاصله، flank، حمله‌نکردن به guard | catch melee یا yellow توسط بازیکن | return shot به lock در turret امن |
| MERGE | دو state و damage planning | agents / meter کافی | دو switch latched با helper اختیاری |
| LEAK | ارتفاع، reclaim و route planning | double jump | دو stage ارتفاع با jump دوم |
| CRAWLER | node/edge و up-swipe/pogo | grapple | یک anchor امن auto-target |
| FIREWALL | direction policy، flank، shield throw | phase از membrane | wall نازک مشخص و shortcut برگشت |
| REVIEWER #2 / RACE / LOOP / REGRESSION / اختیاری‌ها | mastery و قانون تازه روی kit موجود | pluginِ همان encounter | dummy تک‌وظیفه‌ای + شرح icon |
| PRODUCTION | ترکیب kit و deploy امن | توانایی پس از پایان یا partner زنده | terminal postgame / خروج بدون خطر |

## 5. Co-op and lag — قرارداد انصاف برای 100–250ms دیر‌دیدن

### 5.1. اول latency را درست تعریف کن

سه عدد جدا: **RTT** زمان رفت‌وبرگشت ping؛ **one-way** مسیر یک‌طرفه که لزوماً RTT/2 نیست؛ **D_view** فاصلهٔ زمان نمایش partner/boss با زمان host، شامل snapshot age، jitter buffer و render. همچنین input-to-photon دستگاه و uplinkِ command مستقل‌اند. اگر «250ms» RTT است، مهمان لزوماً partner را 250ms دیر نمی‌بیند؛ اگر تأخیر دیداری 250ms است، حتی با RTT خوب، tellِ 0.40s نامناسب است.

Valve دربارهٔ interpolation و rewind برای lag compensation توضیح می‌دهد؛ این روش‌ها تناقض ادراک را کاهش می‌دهند، اما حذف کامل delay یا انصاف دفاع را تضمین نمی‌کنند. CLAWD PvE است؛ باید دفاع guest را نیز جدا طراحی کند، نه فرمول shooter را بدون تغییر کپی کند. متن کامل Valve در این بررسی پشت bot challenge بود؛ مبنای این گزاره excerpt قابل‌بازیابی و صفحهٔ Lag Compensation است، نه ادعای ممیزی implementation آن engine. [[29]](https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking)[[30]](https://developer.valvesoftware.com/wiki/Lag_Compensation)

### 5.2. یک host-authoritative attack plan، نه animation reaction

**پیشنهاد architecture برای تیم کوچک:** host state و damage را authoritative نگه دارد؛ movement بازیکن محلی predicted؛ partner interpolated؛ boss attackهای committed بر اساس plan زمان‌دار در هر دو دستگاه نمایش داده شوند. مسیر خطر و timer را از state plan reconstruct کن، نه از رسیدن animation snapshot دیرهنگام. برای attackهای کینماتیک از مسیر analytic استفاده کن؛ physics کل Godot را cross-browser deterministic فرض نکن.

هر plan دست‌کم این فیلدهای مفهومی را دارد: `attack_id, sequence, phase_id, target_id, cue_start, lock_time, active_start, active_end, recovery_end, origin, locked_destination, geometry_seed`. این‌ها قرارداد داخلی تیم‌اند؛ لازم نیست روی HUD متن شوند.

1. host attack را **پیش از active_start** اعلام می‌کند؛ cue زمان‌دار همان footprint آینده را می‌سازد. guest ورود به tell را نشان می‌دهد و plan receipt را ACK می‌کند.
2. threshold انتخاب target قبل از lock؛ پس از lock هیچ aim اصلاحی بر اساس packet جدید. بازیکن مرده/قطع‌شده باعث snap به شریک نمی‌شود؛ attack همان مقصد را می‌رود یا بی‌خطر cancel می‌شود.
3. ACK نشان می‌دهد packet رسیده، نه اینکه کاربر آن را واقعاً دیده. باید frame hitch و age هم اندازه‌گیری شوند. اگر plan دیر برسد و readable budget باقی نماند، **همان attack برای همه** postpone/cancel شود؛ collision از وسط بدن guest materialize نشود.
4. stall شبکه بی‌نهایت نباشد: آستانهٔ اولیه 0.50s برای late plan؛ سپس pause/reconnect یا ادامهٔ solo در recovery امن. packet silence حق phase skip یا loot رایگان نمی‌دهد.
5. snapshot جدید حاوی current attack plan و resolved IDs باشد تا packet قبلیِ ازدست‌رفته باعث دیدن دشمن بدون tell نشود. damageهای active قبلی را روی late join بازپخش نکن.
6. reliability برای state transition، reward، revive و attack plan؛ updateهای movement قابل‌جایگزینی و بدون صف قدیمی. priority ترافیک damage/state بالاتر از particle/agent cosmetic.

**تفاوت مهم:** اعلان آینده برای boss خطرناک است؛ partner می‌تواند هنوز 100–250ms عقب نمایش داده شود. هیچ attack اصلی نباید تصمیم آنی بر اساس جای شریک بخواهد: «بایست دقیقاً کنار partner دیده‌شده» یا tether کوتاه پرشتاب ممنوع. marker و safe region از host plan ثابت می‌آیند، نه sprite دیرهنگام شریک.

### 5.3. Target switching و split-pressure

- هدف حداقل یک attack کامل + recovery حفظ شود؛ انتخاب بعدی میان نزدیک‌ترین، کم‌هدف‌شده و last aggressor با weights باشد، نه تغییر در هر hit. baseline: بیش از دو attack پیاپی روی یک نفر فقط وقتی شریک inactive/unreachable است.
- marker هدف شمارهٔ 1/2 + outline distinct داشته باشد؛ رنگ player به‌تنهایی کافی نیست. camera همهٔ danger originها را پوشش دهد.
- marker تعویض، بخشی از tell کامل attack بعد است؛ افزودن 0.50s چشمک و سپس 0.30s lunge کافی نیست.
- نقش‌ها کوتاه و قابل‌تعویض: bait / damage، reclaim / damage، stun A / stun B. phone هم فرصت اصلی damage و catch داشته باشد؛ support-only شدن player 2 شکست طراحی است.
- برای split یک مسیر مستقل به هر safe region بساز؛ هر دو نفر نباید از یک choke یک‌tile عبور کنند. anti-stack fanها ابتدا mark و بعد فاصله بگیرند؛ pile-up فوری به ضرر هر دو نباشد.
- overlap هم‌زمان روی دو بازیکن، attack budget دوبرابر نیست. هر دو stencil پیش از impact نشان داده شوند؛ intersect خطرهایی که تمام reachable safe set را می‌بندند veto شود.
- نبودن یکی از بازیکنان تمام شرط‌های pair را در recovery بعدی به solo تبدیل می‌کند. MERGE/DEADLOCK نباید co-op نرم‌قفل شوند.

### 5.4. Incoming damage و catch — خلأیی که outgoing hit rewind پر نمی‌کند

در سیستم فعلی guest hit توسط host با lag compensation کنترل می‌شود. این **به‌تنهایی** نمی‌گوید host، dash/jump تازهٔ guest را موقع آسیب دریافتی می‌شناسد یا yellow orb را مطابق تصویری که guest دیده catch می‌کند.

**قرارداد پیشنهادی دفاع:**

- client برای inputهای jump/dash/catch، command sequence و timestamp mapped به clock host ارسال کند؛ host تاریخچهٔ حداقل 0.75s state/input و attack planهای اخیر نگه دارد. rewind مجاز پیشنهادی حداکثر 0.35s، نه به اندازهٔ timestamp دلخواه client.
- incoming damage از تماس host با آخرین pose قدیمی guest نهایی نشود. آن را provisional کن و به مدت کوتاهِ معلوم برای inputهای درراه reconcile کن؛ budget اولیه تا 0.30s. نتیجه باید با player input history و همان attack clock plan بررسی شود. اگر margin دفاع دیده‌شده معتبر بود، damage رد می‌شود؛ نه اینکه اول pip کم و بعد مخفیانه زیاد شود.
- local hurt feedback می‌تواند provisional باشد، ولی مصرف heal، death و revive تنها پس از نتیجهٔ تأییدشده؛ از زنجیرهٔ «مردم، زنده شدم، دوباره مردم» جلوگیری کن. اگر چنین delayی حس ضربه را خراب می‌کند، در PvE safety margin collider/damage را بزرگ‌تر در جهت بازیکن کن و complexity rollback را کم کن.
- catch بر اساس relative collision yellow و arc محلی، با input time معتبر بررسی شود. یک projectile فقط یک بار توسط یک player یا agent resolve می‌شود. در catch هم‌زمان، host با order قطعی مالک return shot را انتخاب کند؛ هر دو client باید نتیجهٔ یکسان بگیرند.
- rewinding boss damage نباید target و attack selection انجام‌شده را retroactively عوض کند. رد یا قبول HP hit با تغییر «چه کسی هدف است» دو مسئلهٔ جدا هستند.
- attack_id + victim_id، impact تکراری را deduplicate کند؛ iframe پیشنهادی 0.90s پس از hit برای 3-pip آغاز بازی، سپس با playtest تنظیم. همان explosion/beam در چند tick یا دو packet دوباره pip کم نکند.
- damage grace را به peer identity مرتبط کن، نه گزینهٔ local ناشناس. در PvE اعتماد بیشتر قابل‌قبول است، اما timestamps محدود، سرعت/acceleration bounded و cooldown معتبر بمانند. نیازی به anti-cheat پرهزینهٔ competitive نیست.

**MVP واقع‌بینانه:** نخست attack scheduling آینده، lock ثابت، stencil پهن، local prediction و bounded defensive validation. rollback کل arena، boss AI و flood معمولاً هزینهٔ ناموجه دارد. prototype networking با N1 و R4 پیش از ساخت تمام باس‌ها گیت اصلی پروژه است.

### 5.5. Revive — پیشنهاد روشن و قابل‌آزمون

Cuphead rescue را با parryِ روح به combat می‌بندد؛ Gungeon روح را با mini-blank فعال نگه می‌دارد و chest/cookie/پایان باس revive می‌دهند. هر دو local-origin هستند؛ هیچ‌کدام شاهد fairness اینترنت 250ms نیست. CLAWD می‌تواند نقش اجتماعی rescue را حفظ و execution هوایی حساس را حذف کند. [[10]](https://en.wikipedia.org/wiki/Cuphead)[[24]](https://enterthegungeon.wiki.gg/wiki/Co-op)

**قانون پیشنهادی Normal:**

1. HP صفر → downed echo غیرcolliding در نزدیک‌ترین landing ثابت امن؛ نه روی lava یا زیر دست باس. timeout اولیه 12s simulation و دو rescue charge مشترک در هر attempt.
2. شریک در شعاع 3 tile، Interact را مجموعاً 1.00s نگه می‌دارد. progress تا 2s بیرون شعاع نگه داشته شود؛ motion touch باعث reset فوری نشود. incoming hit یک بار channel را قطع می‌کند، نه چند tick.
3. موفقیت → 2 pips (با cap max HP)، 1.50s iframe و relocation امن؛ بدون refill meter برای جلوگیری از farm.
4. هر cycle یک rescue-friendly recovery داشته باشد؛ boss خطر را کاملاً خاموش نمی‌کند، اما safe pad برای channel در attack plan محفوظ است.
5. timeout → ghost؛ no damage، no meter generation، می‌تواند فقط ping خطر کند. mini-blank واقعیِ Gungeon هزینهٔ tuning اضافه دارد و برای MVP توصیه نمی‌شود.
6. پیروزی باس همه را با HP حداقل ایمن revive می‌کند. هر دو down → restart فوری؛ intro قابل skip. Assist می‌تواند rescue charges و timeout را بیشتر کند، نه collision rule پنهان.

**Scaling هنگام مرگ یا disconnect:** Max HP وسط fight جهش نکند؛ boss قبلاً HPش را برای دو نفر گرفته است. بعد down طولانی/ghost، از recovery بعد `remaining_hp *= D_solo / D_duo` یک بار در attempt، اگر هدف حفظ زمان پایان است؛ ورود/خروج بعدی دوباره این تبدیل را تکرار نکند. معیار actual DPS را از profileهای پیش از fight بگیر، نه چند ضربهٔ اخیر که exploit شود. alternative ارزان‌تر: HP ثابت بماند، اما recovery solo 1.25× و pair objective آسان‌تر؛ یکی از این دو را انتخاب و تست کن، هر دو را هم‌زمان بی‌حساب اجرا نکن. midfight reconnect مزیت HP تازه یا resource refill نمی‌دهد.

### 5.6. Godot 4 / Web — constraints اجرایی

مستندات Godot توضیح می‌دهد که WebSocket TCP است و برای latency-sensitive realtime محدودیت دارد؛ WebRTC به signaling نیاز دارد و کلاس‌های WebRTCPeerConnection / WebRTCDataChannel / WebRTCMultiplayerPeer برای HTML5 در دسترس‌اند. این به معنی تضمین latency کم نیست؛ NAT، TURN، loss و mobile radio باقی‌اند. مسیر browser را با transport فعلی پروژه benchmark کن؛ برای web مستقیم به UDP/ENet معمول native تکیه نکن. Android در این پروژه **browser client** است، نه الزاماً native Android export. [[31]](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html)

صفحهٔ stable هنگام پژوهش 4.7 نشان می‌داد و خودش warning «ممکن است قدیمی باشد» داشت. نسخهٔ دقیق Godot پروژه هنوز داده نشده؛ API و قابلیت multithread/web باید با نسخهٔ pinned پروژه آزموده شود. توصیهٔ این گزارش transport-neutral است. اگر WebSocket فعلی با scheduling و buffering همهٔ گیت‌ها را پاس کند، مهاجرت اجباری نیست.

### 5.7. Budget / scheduler برای AI agents

یک AttackDefinition data-driven، یک state machine مشترک و سه primitive آغازین کافی‌اند: committed dash/slam، projectile path و marked zone. reusable moduleها: `TargetPolicy`, `HazardBudget`, `SharedObjective`, `DamageResolver`, `TouchAssist`, `RewardShowcase`. code review مرکزی برای clock، color grammar و state transitions ضروری است؛ AI-generated scripts مستقلاً damage یا cooldown invent نکنند.

**Invariantهای قابل unit-test:** پس از commit destination ثابت؛ هر plan sequence یکتا؛ phase cleanup فقط hazardهای phase قبل؛ دو safe route برای dual-mark؛ reward هرگز prereq باس خود نیست؛ simultaneous catch یک damage event؛ left/right shield تنها یک policy؛ flood و pair state مشترک؛ disconnect→solo بدون softlock. object pool برای projectile/clone/agent، و boss arena preload پیش از encounter. profiler باید long frame در لحظهٔ phase/VFX را ثبت کند، نه فقط average FPS.

## 6. Phone and touch — چالش را در تصمیم نگه دار

### 6.1. چیزهایی که باید حذف شوند

- frame-perfect catch در 0.08s، double-tap برای dash، swipe gesture اجباری برای attack و dash-on-release به عنوان تنها کنترل. Furi چنین dashای را برای charge انتخاب کرد؛ سازنده از perception تأخیر هم گزارش می‌دهد. با نیاز CLAWD یکسان نیست. [[25]](https://www.thegamebakers.com/furi-and-creating-memorable-moments/)
- نگه‌داشتن jump و هم‌زمان فشردن dash و catch با یک شست؛ pogo با direction ریزِ دائم وسط bullet rain؛ auto-turn ناگهانی روی pogo.
- landing یک‌tile، jump apex اجباری بدون correction، safe gap که partner تمام آن را می‌پوشاند، timer revive روی بدن درحال‌حرکت.
- mechanic فقط با زرد/قرمز یا فقط music beat؛ icon ریز در 384×216 یا flash پشت particleهای agents.
- قرارگرفتن collider ضروری زیر شست یا کنترل‌های bottom corner؛ layout combat را برای areaهای پوشیده طراحی کن، نه فقط تصویر screenshot تمیز.

### 6.2. کنترل‌های پیشنهادی، نه شش دکمهٔ کوچک

- چپ: movement pad با diagonal sectors و deadzone قابل تنظیم. راست: Jump و Attack دکمه‌های اصلی؛ Dash و Catch بزرگ و نزدیک؛ Interact فقط وقتی context امن/مربوط است ظاهر شود. grapple در حضور anchor با همان Interact و icon واضح، **نه** با Catch هنگام fight. ability phase با dash از membrane اجرا شود تا دکمهٔ تازه اضافه نشود.
- Heal و Summon نیاز به معنای مستقل دارند: toggle انتخاب مصرف meter بیرون combat و یک دکمهٔ Context برای اجرای انتخاب؛ Assist امکان دو دکمهٔ بزرگ جدا در layout شخصی. long-press مبهم برای heal وسط خطر توصیه نمی‌شود. default باید نام/آیکون مصرف را نشان دهد.
- directionِ dash در press latch شود؛ thumb drift پس از press آن را نچرخاند. 8-way snap با hysteresis؛ حالت Assist انتخاب four-way/strong diagonal snap قابل‌تنظیم. dash مستقیم از press اجرا شود، مگر hold-to-aim گزینهٔ جدا و اختیاری.
- Attack در touch می‌تواند swipe خودکار با hold در cadence قانونی کند؛ DPS برابر keyboard hold، نه bonus. Up/down attack با direction sector پهن و pogo assist اختیاری زمانی که بالای دشمن است؛ forward همیشه fallback واضح دارد.
- catch direction assist اختیاری رو به نزدیک‌ترین diamond معتبر؛ return shot به target باس مرتبط auto-aim شود. grapple cone پیشنهادی ±35°، انتخاب نزدیک‌ترین anchor با priority، و highlight هدف قبل press؛ زاویهٔ دقیق توصیهٔ prototype است نه استاندارد.

### 6.3. اندازهٔ UI و forgiveness

Android حداقل 48dp برای touch target پیشنهاد می‌کند؛ WCAG معیار enhanced برابر 44×44 CSS px دارد. dp، CSS px و پیکسل داخلی 384×216 یک واحد نیستند. کنترل‌ها باید در overlay وابسته به اندازهٔ viewport دستگاه باشند، نه روی 16px tile بازی scale شوند. آغاز prototype: targetهای 56–64 CSS px با spacing کافی، اندازه قابل‌تنظیم، و بررسی روی دستگاه واقعی؛ این اندازهٔ پیشنهادی جای اندازه‌گیری فیزیکی و dp-native را نمی‌گیرد. [[32]](https://support.google.com/accessibility/android/answer/7101858?hl=en)[[33]](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html)

Xbox XAG نیز remapping و تنظیم اندازه، فاصله و موقعیت touch targetها را توصیه می‌کند. accessibility به menu checkbox محدود نیست؛ شست‌های دو نفر ممکن است layoutهای متفاوت بخواهند. [[34]](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107)

**Forgiveness آغازین CLAWD:** coyote time=0.12s؛ jump buffer=0.15s؛ dash/catch buffer=0.15s؛ corner correction حداکثر 2–3px داخلی فقط وقتی مسیر امن است؛ pogo hitbox افقی کمی پهن‌تر از sprite ولی collision خطر از sprite تجاوز نکند. values مشترک PC/touch، با Assist selectable و بدون advantage در medal مقایسه‌نشده. Celeste دقیقاً اصل widening timing/positioning و jump/dash corner correction را توضیح داده، اما این اعداد از Celeste نقل نشده‌اند. [[12]](https://www.mattmakesgames.com/articles/celeste_and_forgiveness/index.html)

**UI / readability:** letterbox جانبی اگر جا دارد محل controls باشد؛ در landscape کوتاه، تلگراف‌های حیاتی را از دو corner پایین دور کن. high contrast، player-outline مستقل، reduced shake/flash، audio sliders، و یک cue تصویری برای همهٔ صداهای حیاتی. The Lost Crown نمونهٔ مستند high contrast، HUD sizing، multidirectional parry و melee targeting assist است. [[17]](https://news.ubisoft.com/en-us/article/eQyaL5awqH4AXyovZUG58/prince-of-persia-the-lost-crown-accessibility-spotlight)

### 6.4. گیت QA پیش از art polish

اعداد زیر **معیار پذیرش پیشنهادی** هستند، نه نتیجهٔ مطالعهٔ کاربران CLAWD.

| آزمون | setup | شرط عبور آغازین |
| --- | --- | --- |
| latency | PC host + Android browser guest؛ RTTهای 50/100/250ms، جداگانه D_view=100/250ms، jitter=50ms، loss=1% | هیچ attack فعالِ بدون tell کافی؛ هر مورد late plan ثبت و cancel/postpone شود |
| render | 60fps، 30fps و hitch تک‌فریم 100ms در phase | timer بر ثانیهٔ simulation؛ active پس از hitch بدون grace ظاهر نشود |
| target switch | partner قبل lock دور/نزدیک شود، سپس پس از lock | مقصد بعد lock تغییر نکند؛ guest marker با plan یکسان |
| multi-hit | beam چندtick، دو projectile روی یک frame، catch هم‌زمان | iframe/dedup مانع کاهش دو pip از یک impact شود |
| ability gate | هر باس reward را در debug خاموش کن | هر attack حداقل یک counter با kit ورودی داشته باشد |
| solo failover | down، ghost و disconnect در MERGE/DEADLOCK | window و scheduler solo فرصت واقعی completion بدهند |
| learning | گروه کوچک keyboard و touch، قبل/بعد چند attempt | دلایل مرگ به attack مشخص قابل‌شرح؛ مرگ زیر شست/بدون cue صفرِ موردشناخته؛ trend موفقیت با practice رشد کند |
| readability | background grayscale، sound خاموش، controls بزرگ | نوع خطر و target فقط با shape/marker قابل‌تشخیص |

Telemetry: per attack، cue receipt/visible time، locked target، impact time، input sequence، device FPS، deaths، parry reject reason، DPS uptime و remaining HP. بازیکن بعد مرگ یک replay کوتاه یا marker علت ببیند. با sample کوچک ادعای statistical fairness نکن؛ برای هر گروه تعداد attempt و تجربهٔ بازیکن ثبت شود. اگر 250ms را فقط با ping simulator روی desktop تست کنی، input و render Android را تست نکرده‌ای.

## 7. Anti-patterns — اشتباه مشخص، شاهد، جایگزین

| اشتباه | نمونه / شاهد و محدودیت داوری | جایگزین CLAWD |
| --- | --- | --- |
| HP-only hard mode | Dead Cells modifiers و Hades EM3 واقعاً حرکت/شکل تازه می‌دهند؛ صرف HP imitation آن‌ها نیست. [[21]](https://dead-cells.com/patchnotes/31)[[22]](https://hades.fandom.com/wiki/Theseus/Combat) | یک relationship تازه با همان primitive؛ HP از زمان و DPS واقعی |
| Instant-kill در teach fight | Expósito Play Time طبق wiki grabِ instant-kill دارد؛ suit کردن این severity برای آنلاینِ 3-pip نتیجه نمی‌شود. [[20]](https://blasphemous.wiki.gg/wiki/Exp%C3%B3sito,_Scion_of_Abjuration) | mark پهن، damage=1 pip، rescue route؛ no offscreen grab |
| Punish فقط در ظاهر | فاصلهٔ 3 tile می‌تواند نصف ثانیه approach ببرد؛ window 0.6s عملاً صفر است. این مثال CLAWD است، نه اندازه‌گیری بازی مرجع. | weak point نزدیک شود یا recovery ≥approach+swipe+margin |
| input-read بدون cue | Lace guard و counter رفتار قابل‌دید مستند دارد؛ ادعای reading دکمهٔ مخفی از forum ثابت نمی‌شود. [[6]](https://www.ign.com/wikis/hollow-knight-silksong/Lace_Boss_Guide) | REVIEWER بر hit به guard پاسخ دهد و Replyِ مستقل tell داشته باشد |
| هر phase = همه‌چیز سریع‌تر | NKG سریع‌تر و punishing‌تر است، ولی mastery optional آن را نباید به baseline phone تبدیل کرد. [[4]](https://hollowknight.wiki/w/Nightmare_King_Grimm) | relation/arena/task تازه با budget ثابت واکنش |
| تغییر ناگهانی «attack good / bad» | Grim cluster با hit split می‌شود؛ این اصل می‌تواند تصمیم خوب بسازد، اما بدون آموزش به auto-attack تبدیل به trap می‌شود. [[9]](https://cuphead.fandom.com/wiki/Grim_Matchstick) | crack/icon مشخص و نمونهٔ امن پیش از FORK |
| phase تغییر قانون heal بدون معرفی | Kwolok در phase آبی Regeneration ندارد؛ guide این تفاوت را یادآور می‌شود. [[13]](https://godisageek.com/ori-and-the-will-of-the-wisps-complete-boss-guide-kwolok/) | LEAK heal را همان‌طور نگه دارد یا تغییر را پیش‌تر تمرین دهد |
| دعوا بر سر تنها safe tile | دو بدن و دو شست safe spot یک‌tile را عملاً حذف می‌کنند؛ مثال خطر طراحی CLAWD است. | پناه 4 tile یا دو safe region مستقل؛ player collision خاموش |
| دشمن invulnerable طولانی روی صفحه | سازندگان Shovel Knight محدودکردن disappearing/invulnerability و قابلیت hit هنگام حضور را توصیه می‌کنند. [[26]](https://www.gamedeveloper.com/design/how-yacht-club-games-created-shovel-knight-s-specter-knight-plague-knight-and-propeller-knight-bosses) | idle shield front-only، interrupt یا weak point ثانویه؛ waiting reward مکانیکی داشته باشد |
| cutscene refill و fake death فرساینده | Vahram چند rewindِ HP دارد؛ با theme آن معنا دارد، ولی هزینهٔ endurance را برای final CLAWD نباید پنهان کرد. [[16]](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide) | bar segmented از اول، transition کوتاه، checkpoint اختیاری Practice |
| rescue دقیق روی moving soul | Cuphead روح صعودکننده را parry می‌خواهد؛ مدرک مناسب‌بودن آن برای touch آنلاین نیست. [[10]](https://en.wikipedia.org/wiki/Cuphead) | echo روی landing ثابت، buffered channel و grace |
| schedule واقعی یا موسیقی-only | CRONِ CLAWD اگر ساعت واقعی شرط unlock باشد مشارکت را محدود می‌کند؛ این anti-pattern پیشنهادی است نه انتقاد از بازی مرجع. | simulation schedule، rematch همیشه در terminal، lamp visual |
| assist = فقط کاهش HP دشمن | Ubisoft مستقل health، damage، parry و dodge را قابل تنظیم می‌کند؛ Hades God Mode مقاومت را جدا تغییر می‌دهد. [[35]](https://www.ubisoft.com/en-us/help/prince-of-persia-the-lost-crown/gameplay/article/changing-difficulty-settings-in-prince-of-persia-the-lost-crown/000106408)[[23]](https://www.supergiantgames.com/blog/hades-faq/) | input/visibility/timing assistance جدا از endurance |
| simulation را برای theme خراب‌کردن | FORK صدها node واقعی یا RACE با nondeterministic threading باید browser را تخریب نکند؛ concept نمایش است نه bug واقعی. | cap، deterministic queue، pool و performance budget |

## 8. Top 15 recommendations — رتبه‌بندی impact در برابر cost

رتبه‌ها **قضاوت طراحی با فرض تیم کوچک** هستند، نه ROI اندازه‌گیری‌شده. ordering بر پیش‌نیاز انصاف و reuse است؛ درصد اثر یا نفرروز ساخت بدون شناخت codebase داده نمی‌شود.

| رتبه | اقدام | Impact | Cost | علت اولویت / done condition |
| --- | --- | --- | --- | --- |
| 1 | future attack plan + locked target + late-cue safeguard | بسیار بالا | Medium | مهمان attack بی‌tell نبیند؛ N1 در 250ms گیت را پاس کند |
| 2 | incoming damage / catch validation و event dedup | بسیار بالا | Medium | دفاع درست به علت uplink قدیمی رد نشود؛ same impact یک pip |
| 3 | ability ledger و counter بدون rewardِ همان باس | بسیار بالا | Low | NULL بدون dash تا FIREWALL بدون phase کامل قابل‌برد |
| 4 | telegraph grammar: silhouette + footprint + target | بسیار بالا | Low | خاموش‌کردن رنگ/صدا پاسخ را از بین نبرد |
| 5 | touch buffering، 8-way snap و overlay controls | بسیار بالا | Medium | بدون double-tap/gesture اجباری؛ real Android تست شود |
| 6 | attack primitive library و قرارداد مشترک AI agents | بالا | Medium | تمام 14 باس از core clock / damage rule یکسان استفاده کنند |
| 7 | safe region و overlap veto برای دو بدن | بالا | Low–Medium | هیچ seed دو stencil تمام مسیرهای reachable را نبندد |
| 8 | recovery از approach time، نه animation duration | بالا | Low | guest در recovery واقعاً حداقل یک hit یا heal دارد |
| 9 | pair objective latch + solo failover | بالا | Medium | MERGE/DEADLOCK بدون هم‌زمانی frame و با partner down حل شوند |
| 10 | revive زمینی با progress grace و charges محدود | بالا | Medium | شریک ضعیف‌تر spectator طولانی نشود؛ revive farm ندهد |
| 11 | telemetry DPS uptime / D_view / reject reason | بالا | Medium | HP و fairness از دادهٔ build اصلاح شود، نه احساس code writer |
| 12 | phaseها از آشنا→ترکیب، cleanup atomic | بالا | Low | projectile phase قبل هنگام cutscene kill نکند |
| 13 | reward showcase اتاقی و بی‌خطر | متوسط–بالا | Low | توانایی بدون متن طولانی بلافاصله فهمیده شود |
| 14 | Practice terminal + REVIEWER #2 با یک modifier | متوسط–بالا | Low–Medium | replay value بدون production asset set تازه |
| 15 | FORK cap/pool، CRON visual clock، spectacle با نور/صدا | متوسط | Low–Medium | performance و readability هزینهٔ art را کنترل کند |

**ترتیب sprint پیشنهادی:** ابتدا NULL graybox + R4 yellow orb + شبکه/phone؛ سپس REVIEWER polished؛ سپس MERGE و LEAK برای pair/arena؛ بعد CRAWLER/FIREWALL؛ پس از ثبات core، RACE/LOOP/REGRESSION؛ rematchها و final با reuse. FORK/DEADLOCK/CRON فقط وقتی effort تست online از ظرفیت تیم تجاوز نمی‌کند. به باسِ مشکل‌دارِ شبکه صرفاً VFX اضافه نکن.

## 9. Sources — منابع، دامنهٔ شاهد و موارد unverified

### 9.1. روش و محدودیت‌ها

منابع به ترتیب ارزش: گفتهٔ سازنده/patch رسمی/docs → تحلیل یا guide دقیق → wiki رفتار. excerptها با صفحات مرتبط cross-check شدند؛ هیچ دادهٔ فروش/رضایت یا عدد window بازی مرجع از حافظه به‌عنوان نتیجهٔ تحقیق نقل نشده است. محتوا تا تاریخ پژوهش در دسترس بررسی شد؛ ادعای پوشش تمام patchهای 2026 یا همهٔ DLCها نمی‌شود. Silksong اطلاعات واقعی منتشرشده دارد؛ release=4 September 2025 و Patch 1 رسمی بررسی شد، نه speculation پیش‌ازعرضه. [[36]](https://www.engadget.com/gaming/hollow-knight-silksongs-first-patch-should-give-you-a-chance-against-its-early-bosses-134125593.html)[[7]](https://steamcommunity.com/app/1030300/discussions/0/595159519774039622/)

**GMTK clarification:** عنوان Boss Keys عمدتاً world/dungeon progression است، نه handbook اختصاصی boss combat. transcript Hollow Knight آن برای ability progression، چند مسیر critical lock و نقل‌قول Team Cherry دربارهٔ sequence break به کار رفت؛ به آن توصیهٔ ثانیه‌ای combat نسبت داده نشده است. اصل «پاداش توانایی را در چند مسیر نزدیک کاربردی کن» از همین بحث مفید است. [[37]](https://www.youtube.com/watch?v=7ITtPPE-pXE)

**GDC clarification:** talk واقعی Cupheadِ Jake Clark و transcript در دسترس بود؛ برای attention/anticipation و animation process استفاده شد. صفحهٔ Vaultِ هم‌عنوان برچسب Showcase 2021 دارد، ولی ویدئوی GDC توضیح talk سال 2017 است؛ این دو را دو شاهد مستقل برای combat tuning نمی‌شماریم. GDC talk مشخص و تأییدشده‌ای دربارهٔ boss designِ Hollow Knight/Furi در این پژوهش پیدا نشد؛ هیچ نقل‌قولی به talk فرضی نسبت داده نشده، و برای Furi از متن خود Creative Director استفاده شد. [[28]](https://www.youtube.com/watch?v=RmGb-jU3uVQ)[[38]](https://gdcvault.com/play/1026941/Animation-Bootcamp-Cuphead-Process-and)[[25]](https://www.thegamebakers.com/furi-and-creating-memorable-moments/)

### 9.2. فهرست کامل منابع مورد استناد

**Primary / developer statements / official documentation**

- S01 — [The Game Bakers: Furi and creating memorable moments](https://www.thegamebakers.com/furi-and-creating-memorable-moments/) — Emeric Thoa، 22 July 2016؛ counterattack، Furier، dash-on-release و difficulty philosophy. سند تاریخی است، نه تأیید همهٔ تنظیمات نسخهٔ امروز.
- S02 — [GDC: Cuphead’s Animation Process and Philosophy](https://www.youtube.com/watch?v=RmGb-jU3uVQ) — Jake Clark، GDC 2017؛ بخش Tombstone Slam تقریباً 17:42 و بحث attention/anticipation؛ transcript خوانده شد. اندازه‌گیری دقیق زمان‌بندی تمام attackها انجام نشد.
- S03 — [GDC Vault: Animation Bootcamp — Cuphead Process and Philosophy](https://gdcvault.com/play/1026941/Animation-Bootcamp-Cuphead-Process-and) — metadata رسمی؛ Showcase 2021 در صفحه، همان عنوان/speaker. شاهد مستقل از S02 محسوب نمی‌شود.
- S04 — [Game Developer / Boss Fight Books: ساخت Specter، Plague و Propeller Knight](https://www.gamedeveloper.com/design/how-yacht-club-games-created-shovel-knight-s-specter-knight-plague-knight-and-propeller-knight-bosses) — David L. Craddock، 17 October 2018؛ نقل‌قول مستقیم Yacht Club دربارهٔ moves، reactivity، hitbox و player choice. «مصاحبهٔ سازنده در واسطهٔ تحریریه».
- S05 — [Into Indie Games: Nine Sols — An Interview with Red Candle Games](https://intoindiegames.com/features/nine-sols-an-interview-with-red-candle-games) — 1 July 2024؛ Shihwei/Vincent، deflection و iterative combat development. رفتار Lady Ethereal از این مصاحبه استخراج نشده است.
- S06 — [Ubisoft: The Lost Crown — Accessibility Spotlight](https://news.ubisoft.com/en-us/article/eQyaL5awqH4AXyovZUG58/prince-of-persia-the-lost-crown-accessibility-spotlight) — Rémi Boutin؛ 4 January 2024، updated 28 August 2024؛ high contrast، input، custom difficulty و multidirectional parry.
- S07 — [Ubisoft Help: Changing difficulty settings](https://www.ubisoft.com/en-us/help/prince-of-persia-the-lost-crown/gameplay/article/changing-difficulty-settings-in-prince-of-persia-the-lost-crown/000106408) — فهرست پارامترهای health/damage/parry/dodge/Athra؛ gameplay اصلی را از استثناهای mode جدا می‌کند.
- S08 — [Maddy Thorson: Celeste & Forgiveness](https://www.mattmakesgames.com/articles/celeste_and_forgiveness/index.html) — شرح مستقیم coyote، buffering، peak gravity و corner correction؛ فاقد تأیید اعداد prototype CLAWD.
- S09 — [Nintendo: Metroid Dread Report vol. 5 — The powers of Samus](https://metroid.nintendo.com/dread/news/metroid-dread-report-vol-5/) — 20 August 2021؛ Melee Counter، Dash Counter، movement continuity و ability description.
- S10 — [Dead Cells: Update 31 patch notes](https://dead-cells.com/patchnotes/31) — 2022؛ Boss Rush و modifiers، Conjunctivius warning/overlap fixes؛ نسبت‌دادن زمان‌های بازی به آن نشده است.
- S11 — [Supergiant: Hades FAQ](https://www.supergiantgames.com/blog/hades-faq/) — God Mode، Pact of Punishment و فلسفهٔ challenge متناسب. اعداد دقیق مقاومت God Mode در متن گزارش ادعا نشده‌اند.
- S12 — [Team Cherry: Silksong Patch 1 Available Now](https://steamcommunity.com/app/1030300/discussions/0/595159519774039622/) — developer post 9 September 2025، updated 12 September؛ version 1.0.28497، کاهش دشواری Moorwing / Sister Splinter و fixes.
- S13 — [Godot documentation: WebRTC](https://docs.godotengine.org/en/stable/tutorials/networking/webrtc.html) — APIهای HTML5، signaling و تفاوت WebSocket؛ صفحهٔ مشاهده‌شده warning outdated برای 4.7 داشت، لذا نسخهٔ پروژه باید pin/test شود.
- S14 — [Valve Developer Community: Source Multiplayer Networking](https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking) — interpolation / latency / lag compensation؛ search excerpt در دسترس، full load پشت bot challenge.
- S15 — [Valve Developer Community: Lag Compensation](https://developer.valvesoftware.com/wiki/Lag_Compensation) — rewind و historical state؛ جزئیات Source برای Godot copy-paste spec نیست.
- S16 — [Android Accessibility Help: Touch target size](https://support.google.com/accessibility/android/answer/7101858?hl=en) — minimum 48dp؛ واحد native با پیکسل game متفاوت است.
- S17 — [W3C WCAG: Target Size Enhanced](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html) — 44 CSS px معیار enhanced و توصیه به targets بزرگ‌تر در استفادهٔ پرتکرار.
- S18 — [Microsoft Xbox Accessibility Guideline 107: Input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107) — تنظیم اندازه/موقعیت/فاصله touch controls و input barriers.

**Analytical / editorial / mechanical references**

- S19 — [GMTK: The World Design of Hollow Knight — Boss Keys](https://www.youtube.com/watch?v=7ITtPPE-pXE) — Mark Brown؛ transcript progression و quotes Team Cherry بررسی شد؛ موضوع اصلی world design است.
- S20 — [Hollow Knight Wiki: Hornet Protector](https://hollowknight.wiki/w/Hornet_Protector) — moveset و reward؛ community mechanical reference.
- S21 — [Hollow Knight Wiki: Mothwing Cloak](https://hollowknight.wiki/w/Mothwing_Cloak) — dash و محل acquisition پس از Hornet؛ reward از corpse دریافت می‌شود، نه انتقال مستقیم قدرت Hornet.
- S22 — [Hollow Knight Wiki: Mantis Lords](https://hollowknight.wiki/w/Mantis_Lords) — Dash/Drop/Boomerang و ساختار phases؛ attack names wiki لزوماً canon نیستند.
- S23 — [Hollow Knight Wiki: Nightmare King Grimm](https://hollowknight.wiki/w/Nightmare_King_Grimm) — bats، pillars، damage، stagger؛ اعداد زمانی خود wiki از پیشنهاد CLAWD جدا هستند.
- S24 — [Hollow Knight Wiki: Pantheons](https://hollowknight.wiki/w/Pantheons) — gauntlet، Bindings، variant arenas و rest rooms.
- S25 — [IGN: Lace Boss Guide](https://www.ign.com/wikis/hollow-knight-silksong/Lace_Boss_Guide) — updated 11 September 2025؛ guard، counter، diagonal dash و circle attack. guide ثانویه، نه design intent سازنده.
- S26 — [Cuphead Wiki: Cagney Carnation](https://cuphead.fandom.com/wiki/Cagney_Carnation) — seeds، minions، roots و platform denial.
- S27 — [Cuphead Wiki: Grim Matchstick](https://cuphead.fandom.com/wiki/Grim_Matchstick) — clouds، phase 3 splitting cluster و center flamethrower.
- S28 — [Cuphead — Wikipedia](https://en.wikipedia.org/wiki/Cuphead) — local co-op و parry روح برای revive؛ منبع ثانویه برای قاعدهٔ عمومی، نه ضریب co-op HP.
- S29 — [Celeste Wiki: Chapter 6 — Reflection](https://celestegame.fandom.com/wiki/Chapter_6:_Reflection) — confrontation، reconciliation و additional dash.
- S30 — [Celeste Wiki: Intervention / Chapter 2 chase](https://celestegame.fandom.com/wiki/Intervention) — delayed path-mimic و اضافه‌شدن cloneها بدون سریع‌ترشدن خود chaser؛ chase را از Chapter 6 جدا می‌کند.
- S31 — [God is a Geek: Kwolok boss guide](https://godisageek.com/ori-and-the-will-of-the-wisps-complete-boss-guide-kwolok/) — 12 March 2020؛ phases، Bash، water و محدودیت Regeneration.
- S32 — [Omega Metroid: Metroid Dread bosses](https://omegametroid.com/metroid-dread-walkthrough/bosses) — Kraid rail/early Bomb و Raven Beak counter/flight/sun؛ walkthrough ثانویهٔ تفصیلی.
- S33 — [IGN: Vahram, the First Immortal Final Boss Guide](https://www.ign.com/wikis/prince-of-persia-the-lost-crown/Vahram,_the_First_Immortal_Final_Boss_Guide) — updated 27 February 2024؛ rewind، copies، line slashes و چند counter-route.
- S34 — [Frostilyte: Lady Ethereal boss guide](https://frostilyte.ca/2025/03/10/nine-sols-boss-guide-lady-ethereal) — 10 March 2025؛ شاهد تحلیلی player guide با مثال‌های gameplay؛ ابهام شناسایی اصل در phase 2 را خودش محدودیت بررسی می‌داند.
- S35 — [Blasphemous Wiki: Expósito, Scion of Abjuration](https://blasphemous.wiki.gg/wiki/Exp%C3%B3sito,_Scion_of_Abjuration) — scale، weak points و grab؛ lore interpretation به‌عنوان intent قطعی سازنده نقل نشده است.
- S36 — [Hades Wiki: Theseus / Combat](https://hades.fandom.com/wiki/Theseus/Combat) — crosshair، shield، Olympian Aid و Extreme Measures 3؛ رفتار مستند wiki، نه primary interview.
- S37 — [Enter the Gungeon Wiki: Co-op](https://enterthegungeon.wiki.gg/wiki/Co-op) — +40% enemy health، ghost/mini-blank، chest/cookie/boss revive؛ archive تاریخی و release rules از یکدیگر جدا شده‌اند.
- S38 — [Engadget: Silksong first patch / early bosses](https://www.engadget.com/gaming/hollow-knight-silksongs-first-patch-should-give-you-a-chance-against-its-early-bosses-134125593.html) — 9 September 2025؛ release date و patch context، با S12 cross-check.

### 9.3. موارد unverified و تصمیم ناشی از آن‌ها

| ادعا / مجهول | وضعیت | اثر روی سند |
| --- | --- | --- |
| ضریب دقیق HP/damage co-op در Cuphead برای همهٔ versionها | unverified | هیچ درصدی به Cuphead نسبت داده نشده؛ CLAWD از effective DPS tune می‌شود |
| «Lace input دکمهٔ بازیکن را مخفیانه می‌خواند» | unverified | فقط guard/counter قابل‌دید guide استفاده شد؛ REVIEWER input reading ندارد |
| GDC talk اختصاصی boss designِ Hollow Knight یا Furi با عنوان/متن معتبر | unverified در این تحقیق | نسبت‌دادن quotes یا timings به چنین talkی حذف شد |
| timing دقیق telegraph، catch و recovery تمام بازی‌های مرجع | unverified / اندازه‌گیری نشده | تمام ثانیه‌های CLAWD hypothesis prototype هستند |
| تأثیر کمی پیشنهادها بر retention، رضایت یا نرخ پیروزی CLAWD | unverified | Top 15 ranking قضاوت کیفی است؛ telemetry و playtest لازم |
| سرعت run، jump height، dash iframe و cooldown واقعی CLAWD | unverified / ورودی پروژه داده نشده | counterهای اولیه بدون dash iframe؛ مختصات و recovery مشروط به kit measurement |
| 50–250ms اعلام‌شده یعنی RTT یا D_view؟ | unverified | هر دو سناریو در QA؛ تبدیل کور RTT/2 انجام نشود |
| رفتار single-thread/web، audio و networking در نسخهٔ دقیق Godot پروژه | unverified تا تست build pinned | transport و rhythm clock باید روی Android browser واقعی آزموده شوند |
| برداشت «Expósito ترجمهٔ مکانیکی grief است» یا intent فلسفی هر move | unverified به‌عنوان intent | فقط appearance/weak-point/grabِ مستند و تحلیل تناسب ذکر شد |

**پایان طراحی:** باسِ خوب CLAWD باید بازیکن را پس از مرگ به این جمله برساند: «فهمیدم مشکل چه بود و دفعهٔ بعد با این حرکت حلش می‌کنم»؛ نه «باید اینترنت، گوشی یا توانایی‌ای را که هنوز ندارم عوض کنم».