// A02-01：工程缩放、画布平移配准、PNG/sRGB 编码与 QA；不画图、不重着色、不修改肢体或 alpha 轮廓。
// Node.js + sharp 0.35.5。原稿独立保留；检视图是排版，不是客户端截图。
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), sharp = require('sharp');
const dir = __dirname, root = path.resolve(dir, '../../..');
const meta = JSON.parse(fs.readFileSync(path.join(dir, 'metadata.json'), 'utf8'));
const raws = new Map(), outputs = new Map(), checks = [], failures = [];
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const round = n => +n.toFixed(4);
function bounds(data,w,h,t=16) { let left=w,top=h,right=-1,bottom=-1; for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(data[(y*w+x)*4+3]>=t){left=Math.min(left,x);right=Math.max(right,x);top=Math.min(top,y);bottom=Math.max(bottom,y);}return {left,top,right,bottom,width:right-left+1,height:bottom-top+1}; }
function registration(ref,src) {
  // 固定身体 ROI，避开触角和活动腿。比较同一画布坐标；不按每帧外轮廓裁切/拉伸。
  let best={dx:0,dy:0,error:Infinity};
  for(let dy=-7;dy<=7;dy++)for(let dx=-8;dx<=8;dx++){
    let error=0,n=0;for(let y=90;y<=108;y++)for(let x=29;x<=145;x++){
      const a=(y*192+x)*4,b=((y+dy)*192+x+dx)*4;
      for(let c=0;c<4;c++){const ar=c===3?ref[a+c]:ref[a+c]*ref[a+3]/255,br=c===3?src[b+c]:src[b+c]*src[b+3]/255;error+=Math.abs(ar-br);n++;}
    }
    error/=n;if(error<best.error)best={dx,dy,error};
  } return {...best,error:round(best.error)};
}
function xml(s){return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;');}
function label(s,x,y,size=17,color='#47382C'){return `<text x="${x}" y="${y}" font-family="Arial, sans-serif" font-size="${size}" fill="${color}">${xml(s)}</text>`;}
function box(x,y,w,h,c){return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}"/>`;}
const svg=(w,h,s)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${s}</svg>`);
async function size(id,w,h=w){return sharp(outputs.get(id)).resize(w,h).png().toBuffer();}
async function main(){
  const ref=(await sharp(path.join(dir,'masters/ant_worker_idle_1.png')).ensureAlpha().resize(192,192).raw().toBuffer());
  for(const asset of meta.assets){
    const source=path.join(root,asset.source),target=path.join(root,asset.runtime);
    fs.mkdirSync(path.dirname(target),{recursive:true});
    const srcmeta=await sharp(source).metadata();
    // 生成工具实出 1254 方形原稿，提示词的 1280 不当作实际文件尺寸；以解码后尺寸为准。
    if(srcmeta.width!==srcmeta.height||srcmeta.width<1024)failures.push(asset.id+': master must be square and at least 1024px');
    let pipeline=sharp(source).ensureAlpha().toColourspace('srgb');
    let align=null;
    if(asset.id.startsWith('ant_worker')){
      const scaled=await pipeline.resize(192,192).raw().toBuffer();
      align=registration(ref,scaled);
      // 在 192px 比较画布统一平移 (-4,-3)，使胸部贴近中心；同时抵消每帧整体位置偏差。
      const left=32-4-align.dx,top=32-3-align.dy;
      const aligned=await sharp({create:{width:256,height:256,channels:4,background:{r:0,g:0,b:0,alpha:0}}})
        .composite([{input:scaled,raw:{width:192,height:192,channels:4},left,top}]).png().toBuffer();
      pipeline=sharp(aligned).extract({left:32,top:32,width:192,height:192});
    }
    await pipeline.resize(asset.pixels[0],asset.pixels[1],{kernel:'lanczos3'}).withIccProfile('srgb').png().toFile(target);
    const {data,info}=await sharp(target).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    const b=bounds(data,info.width,info.height),opaque=bounds(data,info.width,info.height,128);
    let edge=0,solid=0,transparent=0;for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){const a=data[(y*info.width+x)*4+3];if(x===0||y===0||x===info.width-1||y===info.height-1)edge=Math.max(edge,a);if(a===0)transparent++;if(a===255)solid++;}
    if(edge!==0||solid===0||transparent===0||b.width<8||b.height<8)failures.push(asset.id+': alpha/content check');
    if(b.left<4||b.top<4||b.right>info.width-5||b.bottom>info.height-5)failures.push(asset.id+': insufficient padding');
    if(align&&align.error>14)failures.push(asset.id+': body registration/color difference exceeds 14/255');
    asset.master_pixels=[srcmeta.width,srcmeta.height];asset.master_sha256=hash(source);asset.sha256=hash(target);
    asset.export_registration=align?{comparison_scale:192,match_offset:[align.dx,align.dy],canvas_translation:[-4-align.dx,-3-align.dy],body_mae_255:align.error}:null;
    asset.bytes=fs.statSync(target).size;
    checks.push({id:asset.id,pixels:[info.width,info.height],bbox_alpha16:b,bbox_alpha128:opaque,outer_alpha_max:edge,transparent_pixels:transparent,opaque_pixels:solid,registration:asset.export_registration,sha256:asset.sha256,bytes:asset.bytes});
    raws.set(asset.id,{data,w:info.width,h:info.height});outputs.set(asset.id,target);
  }
  const a=raws.get('egg_states_normal'),b=raws.get('egg_states_ready');let intersection=0,union=0;
  for(let i=3;i<a.data.length;i+=4){const x=a.data[i]>=128,y=b.data[i]>=128;if(x||y)union++;if(x&&y)intersection++;}
  const eggIOU=intersection/union;if(eggIOU<0.98)failures.push('egg silhouette IOU below 98%');
  const ids=meta.assets.map(a=>a.id);if(new Set(ids).size!==17||ids.length!==17)failures.push('expected 17 unique IDs');
  if(new Set(meta.assets.filter(a=>a.id.startsWith('ant_worker')).map(a=>a.sha256)).size!==14)failures.push('worker frames must not be duplicate files');
  // 17 张接触表：原画布 x2；小尺寸面板另按运行时显示尺寸检查。
  let paper=box(0,0,1120,1180,'#F7EFDF')+label('CRUMB KINGDOM  /  A02-01',34,44,28)+label('Worker frames · separate cargo · egg states',34,75,17);
  const overlays=[];
  for(let i=0;i<meta.assets.length;i++){
    const asset=meta.assets[i],x=30+(i%4)*275,y=112+Math.floor(i/4)*204;
    paper+=box(x,y,258,175,i%2?'#DABF87':'#EDDCB5')+label(asset.id.replace('ant_worker_',''),x+12,y+166,15);
    overlays.push({input:await size(asset.id,144),left:x+56,top:y+5});
  }
  paper+=label('Desktop asset QA — not a screenshot from the iPhone app',34,1160,16);
  await sharp(svg(1120,1180,paper)).composite(overlays).png().toFile(path.join(dir,'contact-sheet.png'));
  let proof=box(0,0,1050,830,'#F7EFDF')+label('A02-01 / Runtime-size and compositing proof',30,42,26);
  const p=[];
  const rows=[['idle',2],['walk',6],['carry',6]];
  for(let r=0;r<rows.length;r++){
    const [pose,count]=rows[r],y=90+r*108;proof+=label(`${pose}  —  32pt canvas`,30,y+22,19);
    for(let i=1;i<=count;i++){
      const x=304+(i-1)*105;proof+=box(x-8,y-7,82,80,r===1?'#4C3A30':'#E4C991');
      p.push({input:await size(`ant_worker_${pose}_${i}`,32),left:x+16,top:y+8});
      if(pose==='carry')p.push({input:await size('ant_cargo',16),left:x+35,top:y+16});
      proof+=label(String(i),x+28,y+64,13,r===1?'#F7EFDF':'#47382C');
    }
  }
  proof+=label('Queen room — 0 / 1 / 2 eggs at runtime size',30,437,20);
  const room=path.join(root,'assets/game/rooms/queen/room_queen.png');
  for(let count=0;count<=2;count++){
    const x=45+count*210,y=466;proof+=box(x,y,144,96,'#E4C991');
    p.push({input:await sharp(room).resize(144,96).toBuffer(),left:x,top:y});
    for(let e=0;e<count;e++)p.push({input:await size(e===1?'egg_states_ready':'egg_states_normal',24),left:x+22+e*18-12,top:y+22-12});
    proof+=label(`${count} egg${count===1?'':'s'}`,x+40,y+122,16);
  }
  proof+=label('Egg states / 24pt',695,446,18)+label('Cargo / 16pt',875,446,18);
  for(let i=0;i<2;i++){const x=705+i*66;proof+=box(x,470,54,56,'#4C3A30');p.push({input:await size(i?'egg_states_ready':'egg_states_normal',24),left:x+15,top:484});}
  p.push({input:await size('ant_cargo',16),left:913,top:489});
  proof+=label('Cargo offset +11pt; one shared parent rotation. Four headings:',30,655,19);
  const ant=await size('ant_worker_carry_4',96),food=await size('ant_cargo',48);
  const pair=await sharp({create:{width:132,height:132,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:ant,left:18,top:18},{input:food,left:75,top:42}]).png().toBuffer();
  for(let i=0;i<4;i++)p.push({input:await sharp(pair).rotate(i*90).resize(88,88).toBuffer(),left:55+i*150,top:679});
  proof+=label('Scale check only; actual camera motion, device sampling and gameplay remain unverified.',30,807,15);
  await sharp(svg(1050,830,proof)).composite(p).png().toFile(path.join(dir,'runtime-proof.png'));
  meta.runtime_bytes=meta.assets.reduce((n,a)=>n+a.bytes,0);fs.writeFileSync(path.join(dir,'metadata.json'),JSON.stringify(meta,null,2)+'\n');
  const qa={version:meta.version,tool:'Node.js / sharp '+sharp.versions.sharp,checks,egg_alpha128_iou:round(eggIOU),worker_frames:14,runtime_files:17,runtime_bytes:meta.runtime_bytes,failures,scope:'Desktop source/export QA only; browser animation preview separately; NOT device acceptance.'};
  fs.writeFileSync(path.join(dir,'qa.json'),JSON.stringify(qa,null,2)+'\n');
  console.log(JSON.stringify({runtime_files:17,runtime_bytes:meta.runtime_bytes,egg_alpha128_iou:round(eggIOU),body_errors:checks.filter(c=>c.registration).map(c=>[c.id,c.registration.body_mae_255,c.registration.match_offset]),failures},null,2));
  if(failures.length)process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1;});
