const {chromium,open,register,setClock}=require('./lib');
const U=(y,m,d,h,mi=0)=>Date.UTC(y,m-1,d,h,mi);
const fast=(page)=>page.evaluate(()=>{Lesson.start(8,3,0);for(let k=0;k<80&&Lesson.st;k++){const i=v9Lesson();if(!i)break;if(i.type==='num'){for(const c of String(i.ans))Lesson.key(c)}else Lesson.pick(i.ans);Lesson.check();Lesson.next()}});
(async()=>{let wipes=0,total=0;
for(let run=0;run<8;run++){const b=await chromium.launch();const {page,context}=await open(b,{clock:U(2026,1,10,12)});

await page.reload();
await register(page,{user:'tz1'});
const steps=[U(2026,1,10,20,31),U(2026,1,10,23,0),U(2026,1,11,20,31),U(2026,1,12,20,29)];
for(const t of steps){total++;const keysBefore=await page.evaluate(()=>Object.keys(localStorage).length);
await setClock(page,t);await page.reload();await page.waitForTimeout(500);
const r=await page.evaluate(()=>[Object.keys(localStorage).length,!!localStorage.getItem('mh_users'),window.__lsLog&&window.__lsLog.slice(0,3),typeof USER!=='undefined'&&USER]);
if(!r[1]){wipes++;console.log('WIPE run',run,'before keys',keysBefore,'after',JSON.stringify(r));break}
await fast(page)}
await b.close()}
console.log('wipes',wipes,'of',total,'reloads')})()
