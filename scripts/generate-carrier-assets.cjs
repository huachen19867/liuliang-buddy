// Export official emblems at app/widget sizes. Original colors and aspect ratios retained.
const {chromium}=require('../.tools/browser/node_modules/playwright');
const fs=require('fs');const path=require('path');const root=path.resolve(__dirname,'..');
const sources=[
 {key:'mobile',file:'mobile-original.png',crop:[40,43,76,76],url:'https://www.10086.cn/cmccclient/cmccclient_new/images/newlogo.png'},
 {key:'unicom',file:'unicom-logo-full.png',crop:[0,5,117,90],url:'https://www.10010.com/wt_service_web/images/new_wt_logo_new.png'},
 {key:'broadnet',file:'broadnet-broadnet-logo.png',crop:[0,0,90,93],url:'https://www.10099.com.cn/images/login/broadnet-logo.png'},
 {key:'telecom',file:'telecom-logo-full.png',crop:[4,7,43,41],url:'https://www.chinatelecom.com.cn/ct/image/img/dianxin.png'},
];
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true});try{const p=await b.newPage();await p.route('**/*',r=>r.abort());for(const s of sources){const original=fs.readFileSync(path.join(root,'scripts/carrier-originals',s.key+'.png'));const data=await p.evaluate(async ({base64,crop})=>{const i=new Image();i.src='data:image/png;base64,'+base64;await i.decode();const c=document.createElement('canvas');c.width=c.height=128;const x=c.getContext('2d');const [a,b,w,h]=crop;const scale=112/Math.max(w,h);x.drawImage(i,a,b,w,h,(128-w*scale)/2,(128-h*scale)/2,w*scale,h*scale);return c.toDataURL('image/png').split(',')[1];},{base64:original.toString('base64'),crop:s.crop});for(const rel of ['app/assets/carriers/'+s.key+'.png','app/android/app/src/main/res/drawable-nodpi/carrier_'+s.key+'.png']){fs.mkdirSync(path.dirname(path.join(root,rel)),{recursive:true});fs.writeFileSync(path.join(root,rel),Buffer.from(data,'base64'));}console.log(s.key,s.url);}}finally{await b.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
