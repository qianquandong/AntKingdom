// Engineering export and QA contact sheets. No game artwork is drawn here.
// Run from repository root: node assets/source/a02-02/export.cjs (sharp 0.35.5).
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../../..');
const rel = p => path.relative(root, p).replaceAll('\\', '/');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const out = path.join(__dirname, 'qa');
const refSoil = 'assets/source/a01-01/masters/terrain_soil_1.png';
const refQueen = 'assets/source/a01-02/masters/room_queen.png';
const items = [
  {id:'surface_backdrop', group:'surface_backdrop', dir:'environment/surface', size:[1296,288], points:[432,48], crop:[0,72,1296,144], alpha:false, file:'exec-745507e9-2add-4174-b7b9-49d57a1cf613.png', refs:[refSoil,refQueen]},
  {id:'dig_feedback_crack_1', prompt:'dig_feedback_crack_1_cleanup', group:'dig_feedback', dir:'effects/dig', size:[144,144], points:[48,48], alpha:true, file:'exec-65c27556-5f94-43a7-815b-d8de42797983.png', refs:['assets/source/a02-02/reference_sources/crack_1_initial.png']},
  {id:'dig_feedback_crack_2', prompt:'dig_feedback_crack_2_readability', group:'dig_feedback', dir:'effects/dig', size:[144,144], points:[48,48], alpha:true, file:'exec-9bc40d6f-334d-4ce6-969e-e3edf7e8b50d.png', refs:['assets/source/a02-02/reference_sources/crack_2_initial.png']},
  {id:'dig_feedback_crumb', group:'dig_feedback', dir:'effects/dig', size:[36,36], points:[12,12], alpha:true, file:'exec-994bc319-b882-4a4d-a947-a946a11bb229.png', refs:[refSoil]},
];
function label(text,w=1200,h=30,size=18,color='#503b32') {
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><text x="0" y="${size+2}" font-family="sans-serif" font-size="${size}" fill="${color}">${text}</text></svg>`);
}
async function rawAlpha(p) { return sharp(p).ensureAlpha().raw().toBuffer({resolveWithObject:true}); }
async function alphaStats(p) {
  const {data,info}=await rawAlpha(p);let minX=info.width,minY=info.height,maxX=-1,maxY=-1,solid=0,clear=0,edge=0;
  for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++) {
    const a=data[(y*info.width+x)*4+3];if(a===0)clear++;if(a>=128)solid++;
    if(a>8){minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
    if((x===0||y===0||x===info.width-1||y===info.height-1)&&a>0)edge++;
  }
  return {pixels:[info.width,info.height],opaque_fraction:solid/(info.width*info.height),fully_clear_fraction:clear/(info.width*info.height),visible_bounds:[minX,minY,maxX,maxY],nontransparent_edge_pixels:edge};
}
async function main() {
  fs.mkdirSync(out,{recursive:true});const records=[],qa=[];
  for(const a of items) {
    a.master=path.join(__dirname,'masters',a.id+'.png');
    a.runtime=path.join(root,'assets/game',a.dir,a.id+'.png');
    fs.mkdirSync(path.dirname(a.runtime),{recursive:true});
    const m=await sharp(a.master).metadata();
    let pipeline=sharp(a.master);let transform;
    if(!a.alpha) {
      // Native source is 3:1; resize proportionally first, then center crop to 4.5:1.
      const h=Math.round(m.height*a.size[0]/m.width);
      const intermediate=await pipeline.resize({width:a.size[0]}).toColourspace('srgb').removeAlpha().png().toBuffer();
      pipeline=sharp(intermediate).extract({left:0,top:Math.floor((h-a.size[1])/2),width:a.size[0],height:a.size[1]});
      transform={operation:'uniform_resize_then_center_crop',intermediate_pixels:[a.size[0],h],crop:[0,Math.floor((h-a.size[1])/2),...a.size]};
    } else {
      if(m.width!==m.height)throw Error(a.id+' expected square master');
      pipeline=pipeline.resize(...a.size);transform={operation:'whole_canvas_uniform_resize',translation:[0,0]};
    }
    await pipeline.toColourspace('srgb').png({compressionLevel:9}).toFile(a.runtime);
    const stats=await alphaStats(a.runtime);const md=await sharp(a.runtime).metadata();
    if(JSON.stringify(stats.pixels)!==JSON.stringify(a.size)||md.space!=='srgb')throw Error(a.id+' size/color');
    if(a.alpha && (!md.hasAlpha || stats.nontransparent_edge_pixels || stats.fully_clear_fraction<0.6))throw Error(a.id+' alpha/padding');
    if(a.alpha && Math.min(stats.visible_bounds[0]/a.size[0],stats.visible_bounds[1]/a.size[1],(a.size[0]-1-stats.visible_bounds[2])/a.size[0],(a.size[1]-1-stats.visible_bounds[3])/a.size[1])<0.15)throw Error(a.id+' 15% clear padding');
    if(!a.alpha && stats.opaque_fraction!==1)throw Error(a.id+' opacity');
    qa.push({id:a.id,pass:true,...stats,space:md.space,has_alpha:md.hasAlpha});
    records.push({id:a.id,group:a.group,source:rel(a.master),runtime:rel(a.runtime),pixels:a.size,catalog_scale:3,catalog_points:a.size.map(n=>n/3),render_points:a.points,...(a.crop?{render_crop_pixels:a.crop}:{}),anchor:[0.5,0.5],transparent:a.alpha,status:'reviewed',prompt_id:a.prompt||a.id,generated_filename:a.file,master_pixels:[m.width,m.height],sha256:hash(a.runtime),master_sha256:hash(a.master),bytes:fs.statSync(a.runtime).size,export:transform,reference_inputs:a.refs.map(p=>({source:p,sha256:hash(path.join(root,p))}))});
  }
  const surface=items[0].runtime,c1=items[1].runtime,c2=items[2].runtime,crumb=items[3].runtime;
  const one=await rawAlpha(c1),two=await rawAlpha(c2);let total=0,withinOne=0;
  for(let y=0;y<144;y++)for(let x=0;x<144;x++)if(one.data[(y*144+x)*4+3]>=96) {
    total++;let found=false;
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const xx=x+dx,yy=y+dy;if(xx>=0&&xx<144&&yy>=0&&yy<144&&two.data[(yy*144+xx)*4+3]>=96)found=true;}
    if(found)withinOne++;
  }
  const alignment={method:'stage1 alpha>=96 support retained by stage2 within 1 runtime pixel',retained_pixels:withinOne,total_pixels:total,ratio:withinOne/total,threshold:0.97,pass:withinOne/total>=0.97};
  if(!alignment.pass)throw Error('Crack continuation failed: '+JSON.stringify(alignment));
  const crop=await sharp(surface).extract({left:0,top:72,width:1296,height:144}).png().toBuffer();
  await sharp(crop).toFile(path.join(out,'surface-device-crop@3x.png'));
  const layers=[];
  function put(input,left,top){layers.push({input,left,top});}
  put(label('A02-02 | Surface + digging feedback',1296,40,26),36,24);
  put(label('Desktop asset proof. Not a gameplay screenshot.',1296,30,17),36,69);
  put(label('Surface master export | 1296 x 288 px',1296,30,18),36,115);
  put(surface,36,151);
  put(label('Runtime row: center crop y=72..215 | 1296 x 144 px (432 x 48 pt)',1296,30,18),36,458);
  put(crop,36,494);
  put(label('1x logical-size preview | 432 x 48',1296,25,16),36,654);
  put(await sharp(crop).resize(432,48).png().toBuffer(),36,686);
  put(label('0 taps / 1 tap / 2 taps | Three existing soil variants at @3x',1296,30,18),36,760);
  for(let row=0;row<3;row++) {
    const soil=path.join(root,`assets/game/terrain/soil/terrain_soil_${row+1}.png`);
    for(let col=0;col<3;col++) {
      const tile=await sharp(soil).composite(col?[{input:col===1?c1:c2}]:[]).png().toBuffer();
      put(tile,36+col*164,802+row*164);
      put(await sharp(tile).resize(48,48).png().toBuffer(),565+col*68,835+row*164);
    }
  }
  put(label('48 pt / 1x sampling',520,28,16),565,801);
  put(label('Crack alpha on light / dark',520,28,17),816,801);
  for(let i=0;i<2;i++) {
    const p=i?c2:c1;
    for(let j=0;j<2;j++)put(await sharp(p).flatten({background:j?'#302925':'#ffffff'}).png().toBuffer(),816+j*164,839+i*164);
  }
  put(label('Soil crumb | 36px / 12pt / 8pt',520,28,17),816,1180);
  put(await sharp(crumb).flatten({background:'#f6ecd8'}).png().toBuffer(),826,1220);
  put(await sharp(crumb).resize(12,12).flatten({background:'#f6ecd8'}).png().toBuffer(),886,1232);
  put(await sharp(crumb).resize(8,8).flatten({background:'#302925'}).png().toBuffer(),925,1234);
  put(label('Whole canvas; no alpha trim. Crack 1 -> 2 uses the same anchor.',1296,30,17),36,1315);
  await sharp({create:{width:1368,height:1370,channels:3,background:'#f6ecd8'}}).composite(layers).png().toFile(path.join(out,'contact-sheet.png'));
  await sharp(path.join(out,'contact-sheet.png')).greyscale().png().toFile(path.join(out,'contact-sheet-grayscale.png'));
  const metadata={schema_version:1,version:'A02-02 1.0.0',created_at:'2026-10-12',owner:'Codex',integrator:'Claude',status:'reviewed',generation:'内置 image_gen；原创提示词与本仓库生成素材作参考；生成alpha原样保留。非第三方许可证，不宣称独占版权。',export_tool:'sharp@'+sharp.versions.sharp,source_record:'prompts.json',runtime_mapping_reference:'015d631f09eedac77143dd77cca54719a0badf85:design/asset_runtime_names.json',assets:records};
  fs.writeFileSync(path.join(__dirname,'metadata.json'),JSON.stringify(metadata,null,2)+'\n');
  const report={delivery:'A02-02 1.0.0',status:'desktop_checks_passed_device_not_run',checks:qa,crack_alignment:alignment,runtime_bytes:records.reduce((n,a)=>n+a.bytes,0),surface_crop:{runtime_pixels:[1296,288],device_source_rect:[0,72,1296,144],device_points:[432,48],normalized_texture_rect:[0,0.25,1,0.5]},proofs:['qa/contact-sheet.png','qa/contact-sheet-grayscale.png','qa/surface-device-crop@3x.png'],limitations:['静态工程与桌面视觉检查；不是客户端/物理设备证据','route_markers/UI/audio/发行内容尚未交付；strict发行门槛不可放宽']};
  fs.writeFileSync(path.join(__dirname,'qa.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({assets:records.length,runtime_bytes:report.runtime_bytes,alignment,checks:qa},null,2));
}
main().catch(e=>{console.error(e);process.exit(1)});
