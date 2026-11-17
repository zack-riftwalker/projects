/* ریاضی‌لند — service worker: کش‌اول برای خود برنامه (آفلاین)، با تازه‌سازی در پس‌زمینه.
   با هر انتشار تازه، نسخهٔ CACHE را عوض کن تا کش قدیمی پاک شود. */
const CACHE='riazi-land-v1';
const CORE=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>{
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()));
});
self.addEventListener('activate',e=>{
  e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',e=>{
  const r=e.request;
  if(r.method!=='GET'||new URL(r.url).origin!==self.location.origin)return; /* درخواست‌های بیرونی (مثل لیگ) دست‌نخورده */
  e.respondWith(caches.open(CACHE).then(async c=>{
    const hit=await c.match(r,{ignoreSearch:true});
    const net=fetch(r).then(res=>{if(res&&res.ok)c.put(r,res.clone());return res}).catch(()=>null);
    if(hit){e.waitUntil(net);return hit}              /* کش‌اول؛ نسخهٔ تازه برای دفعهٔ بعد ذخیره می‌شود */
    const res=await net;
    if(res)return res;
    if(r.mode==='navigate')return (await c.match('./index.html'))||Response.error();
    return Response.error();
  }));
});
