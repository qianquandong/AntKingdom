// A01-02 工程导出与 QA：只缩放/编码原稿；检视图仅排版，不是游戏截图。
// 已验证 Node.js + sharp 0.35.5。资源根目录由脚本位置解析。
const fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto'), sharp=require('sharp');
const dir=__dirname, root=path.resolve(dir,'../../..');
const metaPath=path.join(dir,'metadata.json'), meta=JSON.parse(fs.readFileSync(metaPath,'utf8'));
const raw=new Map(), files=new Map(), checks=[], edges=[], pairs=[], failures=[];
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const rnd=n=>+n.toFixed(3), avg=a=>a.reduce((s,v)=>s+v,0)/a.length;
const lum=c=>c[0]*0.2126+c[1]*0.7152+c[2]*0.0722;
const px=(r,x,y)=>Array.from(r.data.subarray((y*r.w+x)*4,(y*r.w+x)*4+4));
function bounds(r,t){let l=r.w,top=r.h,right=-1,b=-1;for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++)if(px(r,x,y)[3]>=t){l=Math.min(l,x);top=Math.min(top,y);right=Math.max(right,x);b=Math.max(b,y);}return {left:l,top,right,bottom:b};}
function edgePixels(r,d){const a=[];for(let i=36;i<108;i++)for(let k=0;k<3;k++){let x,y;if(d==='N'){x=i;y=k;}if(d==='S'){x=i;y=143-k;}if(d==='E'){x=143-k;y=i;}if(d==='W'){x=k;y=i;}a.push(px(r,x,y));}return a;}
const directions=[['N',1],['E',2],['S',4],['W',8]];
const xml=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;');
const text=(s,x,y,size=16)=>`<text x="${x}" y="${y}" font-family="Arial,sans-serif" font-size="${size}" fill="#503B32">${xml(s)}</text>`;
const rect=(x,y,w,h,c)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}"/>`;
const svg=(w,h,b)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${rect(0,0,w,h,'#F6ECD8')}${b}</svg>`);
async function resized(id,w,h){return sharp(files.get(id)).resize(w,h,{fit:'fill'}).toBuffer();}
async function main(){
  for(const a of meta.assets){
    const source=path.join(root,a.master), out=path.join(root,a.output), sm=await sharp(source).metadata();
    if(Math.abs(sm.width/sm.height-a.pixels[0]/a.pixels[1])>0.001)throw new Error(`${a.id}: 原稿比例不符，禁止拉伸`);
    fs.mkdirSync(path.dirname(out),{recursive:true});
    await sharp(source).resize(...a.pixels,{fit:'inside',kernel:'lanczos3'}).withIccProfile('srgb').png({compressionLevel:9}).toFile(out);
    const om=await sharp(out).metadata(), {data,info}=await sharp(out).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    const r={data,w:info.width,h:info.height};raw.set(a.id,r);files.set(a.id,out);
    let min=255,max=0,edgeMax=0;for(let y=0;y<r.h;y++)for(let x=0;x<r.w;x++){const v=px(r,x,y)[3];min=Math.min(min,v);max=Math.max(max,v);if(x===0||y===0||x===r.w-1||y===r.h-1)edgeMax=Math.max(edgeMax,v);}
    const b16=bounds(r,16),b128=bounds(r,128),margin=Math.min(b128.left/r.w,b128.top/r.h,(r.w-1-b128.right)/r.w,(r.h-1-b128.bottom)/r.h);
    const pass=om.width===a.pixels[0]&&om.height===a.pixels[1]&&om.space==='srgb'&&!!om.icc&&(a.alpha?min===0&&max===255&&edgeMax<=2&&margin>=0.03:min===255);
    checks.push({id:a.id,pixels:[om.width,om.height],space:om.space,icc:!!om.icc,alpha_min:min,alpha_max:max,outer_edge_alpha_max:edgeMax,bounds_alpha16:b16,bounds_alpha128:b128,opaque_margin_fraction:rnd(margin),pass});if(!pass)failures.push(`${a.id}: 尺寸/色彩/alpha 检查失败`);
    a.master_pixels=[sm.width,sm.height];a.master_sha256=hash(source);a.output_sha256=hash(out);
  }
  for(let m=0;m<16;m++)for(const [d,bit] of directions){const samples=edgePixels(raw.get(`terrain_tunnel_masks_${m}`),d).map(lum),mean=avg(samples),light=samples.filter(x=>x>175).length/samples.length,expected=!!(m&bit);const pass=expected?mean>185&&light>0.98:mean<165&&light<0.02;edges.push({mask:m,direction:d,expected_open:expected,mean_luma:rnd(mean),light_fraction:rnd(light),pass});if(!pass)failures.push(`mask ${m} ${d}: 方向/通口检查失败`);}
  for(const [axis,first,second,b1,b2] of [['horizontal','E','W',2,8],['vertical','S','N',4,1]])for(let a=0;a<16;a++)if(a&b1)for(let b=0;b<16;b++)if(b&b2){const x=edgePixels(raw.get(`terrain_tunnel_masks_${a}`),first),y=edgePixels(raw.get(`terrain_tunnel_masks_${b}`),second);const deltas=x.flatMap((v,i)=>[0,1,2].map(c=>Math.abs(v[c]-y[i][c]))),mae=avg(deltas),pass=mae<=18;pairs.push({axis,from:a,to:b,central_edge_rgb_mae:rnd(mae),pass});if(!pass)failures.push(`${axis} ${a} -> ${b}: 接缝色差超过容差`);}
  fs.writeFileSync(metaPath,JSON.stringify(meta,null,2)+'\n');
  const qa={delivery:meta.delivery,sharp_version:sharp.versions.sharp,scope:'桌面资源检查，不是 iOS/真机验收',thresholds:{open_mean_luma_min:185,open_light_fraction_min:0.98,closed_mean_luma_max:165,closed_light_fraction_max:0.02,light_cutoff:175,open_edge_rgb_mae_max:18,room_outer_edge_alpha_max:2,room_opaque_margin_fraction_min:0.03},checks,edge_checks:edges,connected_pair_checks:pairs,failures};
  fs.writeFileSync(path.join(dir,'qa.json'),JSON.stringify(qa,null,2)+'\n');
  let body=text('CRUMB KINGDOM / A01-02',30,44,28)+text('18 sprites / 16 connections + Queen Chamber + Pantry',30,74,17)+text('Room overlays: no fixed entrances, no baked text or egg counts',30,106,15);
  let layers=[{input:await resized('room_queen',540,360),left:30,top:125},{input:await resized('room_pantry',360,360),left:655,top:125}];
  body+=text('room_queen / 432 x 288px / 144 x 96pt',40,508,16)+text('room_pantry / 288 x 288px / 96 x 96pt',645,508,16)+text('Tunnel masks: N=1 / E=2 / S=4 / W=8. Image TOP is NORTH.',30,556,17);
  for(let m=0;m<16;m++){const x=30+(m%4)*265,y=590+Math.floor(m/4)*216;body+=text(`${m} / ${directions.filter(([d,b])=>m&b).map(x=>x[0]).join('')||'CLOSED'}`,x,y,16);layers.push({input:files.get(`terrain_tunnel_masks_${m}`),left:x,top:y+14});layers.push({input:await resized(`terrain_tunnel_masks_${m}`,48,48),left:x+163,top:y+110});body+=text('48pt',x+163,y+176,12);}
  await sharp(svg(1110,1460,body)).composite(layers).png().toFile(path.join(dir,'contact-sheet.png'));
  // 两间房间在 @1x 逻辑大小与白/深底上的透明检视，以及两倍逻辑大小。
  body=text('A01-02 / room alpha + logical size',25,40,25);layers=[];
  for(const [idx,id] of ['room_queen','room_pantry'].entries()){const a=meta.assets.find(x=>x.id===id),[w,h]=a.logical_points,y=85+idx*310;body+=text(`${id} / ${w} x ${h}pt`,25,y,17);for(let bg=0;bg<3;bg++){const x=25+bg*330;body+=rect(x,y+20,310,260,['#FFFFFF','#302925','#DDBF91'][bg]);const scale=bg===2?2:1;layers.push({input:await resized(id,w*scale,h*scale),left:x+Math.floor((310-w*scale)/2),top:y+20+Math.floor((260-h*scale)/2)});}}
  body+=text('White + dark: 1px = 1pt. Sand: 2x logical size. Not a gameplay capture.',25,725,16);
  await sharp(svg(1020,760,body)).composite(layers).png().toFile(path.join(dir,'room-proof.png'));
  // 从真实原型地图派生视觉夹具，仅增加已挖格与 Pantry，不修改设计地图或模拟器。
  const grid=fs.readFileSync(path.join(root,'design/map_prototype.txt'),'utf8').trim().split(/\r?\n/);
  const dug=[[1,3],[2,3],[1,4],[2,4],[1,5],[2,5],[5,2],[6,2],[6,3],[7,3],[7,4],[6,4],[6,5],[6,6],[7,6],[4,5],[4,6],[5,6]];
  const pantry=[[1,4],[2,4],[1,5],[2,5]],open=new Set(dug.map(p=>p.join(',')));
  grid.forEach((row,y)=>[...row].forEach((ch,x)=>{if('.EQ'.includes(ch))open.add(`${x},${y}`);}));
  const maskAt=(x,y)=>(open.has(`${x},${y-1}`)?1:0)|(open.has(`${x+1},${y}`)?2:0)|(open.has(`${x},${y+1}`)?4:0)|(open.has(`${x-1},${y}`)?8:0);
  const prev=JSON.parse(fs.readFileSync(path.join(root,'assets/source/a01-01/metadata.json'),'utf8'));prev.assets.forEach(a=>files.set(a.id,path.join(root,a.output)));
  const placements=[];for(let y=0;y<grid.length;y++)for(let x=0;x<grid[y].length;x++){const ch=grid[y][x];let id=`terrain_soil_${(x*7+y*3)%3+1}`;if(ch==='~')continue;if(open.has(`${x},${y}`))id=`terrain_tunnel_masks_${maskAt(x,y)}`;placements.push({input:files.get(id),left:x*144,top:y*144});if(ch==='X')placements.push({input:files.get('terrain_stone'),left:x*144,top:y*144});}
  for(const [id,x,y] of [['room_queen',3,3],['room_pantry',1,4],['source_cookie_full',0,6],['source_sugar_full',7,2],['source_sap',8,6]])placements.push({input:files.get(id),left:x*144,top:y*144});
  const mapImage=await sharp({create:{width:1296,height:1440,channels:4,background:'#F6ECD8'}}).composite(placements).png().toBuffer();
  body=text('A01-02 / connected layout proof',25,40,27)+text('Static art fixture on the prototype map. No ants/UI. NOT a gameplay screenshot.',25,70,16)+text('150% logical size',25,105,16)+text('100% logical size',695,105,16);
  layers=[{input:await sharp(mapImage).resize(648,720).toBuffer(),left:25,top:120},{input:await sharp(mapImage).resize(432,480).toBuffer(),left:695,top:120}];
  body+=text('Fixture preserves real room/source footprints; added dug cells are recorded in fixture.json.',25,880,15);
  await sharp(svg(1155,915,body)).composite(layers).png().toFile(path.join(dir,'layout-proof.png'));
  fs.writeFileSync(path.join(dir,'fixture.json'),JSON.stringify({purpose:'静态美术检视；不是平衡/运行时测试，不覆盖 design/map_prototype.txt',base_map:'design/map_prototype.txt',dug,pantry,open:[...open],mask_convention:'N1 E2 S4 W8, image top = N'},null,2)+'\n');
  console.log(JSON.stringify({assets:checks.length,asset_checks_pass:checks.filter(x=>x.pass).length,directions:edges.length,directions_pass:edges.filter(x=>x.pass).length,pairs:pairs.length,pairs_pass:pairs.filter(x=>x.pass).length,worst_seam_mae:Math.max(...pairs.map(x=>x.central_edge_rgb_mae)),failures},null,2));
  if(failures.length)process.exitCode=1;
}
main().catch(e=>{console.error(e);process.exitCode=1;});
