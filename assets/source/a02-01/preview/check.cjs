const fs=require('fs'),path=require('path'),{pathToFileURL}=require('url'),{chromium}=require('playwright');
const dir=path.resolve(__dirname,'..');
(async()=>{
  const browser=await chromium.launch({headless:true,channel:process.env.A02_BROWSER_CHANNEL||undefined});
  const page=await browser.newPage({viewport:{width:1040,height:680},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(pathToFileURL(path.join(dir,'preview/index.html')).href);
  await page.evaluate(async()=>{await Promise.all([...document.images].map(i=>i.decode()));});
  const samples=[];
  for(const t of [...Array.from({length:60},(_,i)=>i/10+0.01),0.26,2.01,4.01,0.01]){
    const state=await page.evaluate(t=>{
      window.__timelines['a02-proof'].seek(t);
      const ids=[...document.querySelectorAll('img')].filter(i=>+getComputedStyle(i).opacity>0.5).map(i=>i.id);
      return {ids,decoded:[...document.images].every(i=>i.complete&&i.naturalWidth>0)};
    },t);
    const expected=[];
    for(const [pose,count,fps] of [['idle',2,4],['walk',6,10],['carry',6,10]])for(const variant of ['large','native'])expected.push(`${pose}-${variant}-${Math.floor(t*fps)%count+1}`);
    expected.push('cargo-large','cargo-native',t>=2&&t<4?'egg-ready':'egg-normal');
    if(!state.decoded||JSON.stringify(state.ids.sort())!==JSON.stringify(expected.sort()))errors.push({t,state,expected});
    samples.push({t,visible:state.ids});
  }
  await page.evaluate(()=>{window.__timelines['a02-proof'].seek(2.31);});
  await page.screenshot({path:path.join(dir,'motion-proof.png')});
  const result={version:'A02-01 1.0.0',tool:'Playwright / '+(process.env.A02_BROWSER_CHANNEL||'bundled Chromium'),browser_version:browser.version(),viewport:[1040,680],samples_checked:samples.length,all_images_decoded:true,errors,samples,scope:'Desktop seek/frame-visibility check; does not validate iOS code or physical-device performance.'};
  fs.writeFileSync(path.join(dir,'preview-qa.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify({samples_checked:samples.length,errors}));
  await browser.close();if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
