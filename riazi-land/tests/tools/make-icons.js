/* Generates icon-192.png and icon-512.png next to index.html (Playwright canvas). Run: node tests/tools/make-icons.js */
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');
(async()=>{
  const b=await chromium.launch();const pg=await b.newPage();
  for(const size of [192,512]){
    const data=await pg.evaluate(size=>{
      const c=document.createElement('canvas');c.width=c.height=size;const x=c.getContext('2d'),s=size;
      const bg=x.createLinearGradient(0,0,s,s);bg.addColorStop(0,'#121a2b');bg.addColorStop(1,'#0a0e17');
      x.fillStyle=bg;x.fillRect(0,0,s,s);
      /* hexagon */
      x.beginPath();for(let i=0;i<6;i++){const a=Math.PI/3*i-Math.PI/2,X=s/2+s*.36*Math.cos(a),Y=s/2+s*.36*Math.sin(a);i?x.lineTo(X,Y):x.moveTo(X,Y)}x.closePath();
      const g=x.createLinearGradient(0,0,s,s);g.addColorStop(0,'#34e0c0');g.addColorStop(1,'#7c8cff');
      x.fillStyle=g;x.fill();
      x.fillStyle='#0a0e17';x.font='bold '+Math.round(s*.42)+'px sans-serif';x.textAlign='center';x.textBaseline='middle';x.fillText('π',s/2,s/2+s*.02);
      return c.toDataURL('image/png');
    },size);
    fs.writeFileSync(path.join(__dirname,'..','..','icon-'+size+'.png'),Buffer.from(data.split(',')[1],'base64'));
  }
  await b.close();
})();
