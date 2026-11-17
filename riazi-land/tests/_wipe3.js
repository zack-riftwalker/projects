const {chromium}=require('./lib');const path=require('path');
const files={blank:path.join(__dirname,'_blank.html'),current:path.join(__dirname,'..','index.html')};
const mock=(t0)=>{try{if(!localStorage.getItem('__T'))localStorage.setItem('__T',String(t0))}catch(e){}};
(async()=>{for(const [name,f] of Object.entries(files)){for(const useMock of [false,true]){let wipes=0;const N=30;
 const b=await chromium.launch();const ctx=await b.newContext();
 if(useMock)await ctx.addInitScript(mock,1768035600000);
 const page=await ctx.newPage();await page.goto('file://'+f);
 for(let i=0;i<N;i++){await page.evaluate(i=>{localStorage.setItem('zz_probe',String(i))},i);
  if(useMock)await page.evaluate(([t,i])=>localStorage.setItem('__T',String(t+i)),[1768035600000,i]);
  await page.reload();const ok=await page.evaluate(i=>localStorage.getItem('zz_probe')===String(i),i);if(!ok)wipes++}
 console.log(name,'initScript-writing-localStorage:',useMock,'wipes',wipes,'of',N);await b.close()}}})()
