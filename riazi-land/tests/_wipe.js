const {chromium}=require('./lib');const path=require('path');
const files={blank:path.join(__dirname,'_blank.html'),original:path.join(__dirname,'..','original','index.html'),current:path.join(__dirname,'..','index.html')};
(async()=>{const N=+process.argv[2]||30;
for(const [name,f] of Object.entries(files)){
  for(const mode of ['immediate','wait300']){
  const b=await chromium.launch();const ctx=await b.newContext();const page=await ctx.newPage();
  await page.goto('file://'+f);let wipes=0;
  await page.evaluate(()=>localStorage.setItem('probe0','x'));
  for(let i=0;i<N;i++){
    await page.evaluate(i=>{localStorage.setItem('mh_users',JSON.stringify({u:{n:'x',d:{i}}}));localStorage.setItem('mh_session','"u"')},i);
    if(mode==='wait300')await page.waitForTimeout(300);
    await page.reload();
    const ok=await page.evaluate(i=>{try{return JSON.parse(localStorage.getItem('mh_users')).u.d.i===i}catch(e){return false}},i);
    if(!ok)wipes++;
  }
  console.log(name,mode,'reloads',N,'wipes',wipes);await b.close()}}
})()
