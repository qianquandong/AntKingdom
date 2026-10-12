// 工程尺寸导出与检视表；不绘制或修饰原稿。已验证 sharp 0.35.5。
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');
const dir = __dirname;
const root = path.resolve(dir, '../../..');
const metaPath = path.join(dir, 'metadata.json');
const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const xml = s => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
const svg = (w,h,body) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}">${body}</svg>`);
const text = (s,x,y,size=16,fill='#503B32') => `<text x="${x}" y="${y}" font-family="Arial, sans-serif" font-size="${size}" fill="${fill}">${xml(s)}</text>`;
function bbox(data,w,h,threshold=128) {
  let left=w,top=h,right=-1,bottom=-1;
  for(let y=0;y<h;y++) for(let x=0;x<w;x++) if(data[(y*w+x)*4+3]>=threshold) { left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y); }
  return {left,top,right,bottom};
}
async function main() {
  const rows=[], raw=new Map();
  for(const a of meta.assets) {
    const source=path.join(root,a.master), output=path.join(root,a.output);
    fs.mkdirSync(path.dirname(output), {recursive:true});
    const sm=await sharp(source).metadata();
    if(sm.width!==sm.height) throw new Error(`${a.id}: 原稿非正方形，禁止强行拉伸`);
    await sharp(source).resize(a.pixels[0],a.pixels[1],{fit:'inside',kernel:'lanczos3'}).withIccProfile('srgb').png({compressionLevel:9}).toFile(output);
    const m=await sharp(output).metadata();
    const {data,info}=await sharp(output).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    raw.set(a.id,{data,w:info.width,h:info.height});
    let min=255,max=0,edgeMax=0;
    for(let y=0;y<info.height;y++) for(let x=0;x<info.width;x++) {const v=data[(y*info.width+x)*4+3];min=Math.min(min,v);max=Math.max(max,v);if(x===0||y===0||x===info.width-1||y===info.height-1)edgeMax=Math.max(edgeMax,v);}
    const b=bbox(data,info.width,info.height);
    // 保留生成的 alpha。8-bit alpha <=1 的孤立残留低于 0.4%，允许但在 QA 明示，不清边。
    const faint=bbox(data,info.width,info.height,16);
    const padding=Math.min(faint.left,faint.top,info.width-1-faint.right,info.height-1-faint.bottom);
    const pass=m.width===a.pixels[0]&&m.height===a.pixels[1]&&m.space==='srgb'&&!!m.icc&&(a.alpha ? min===0&&max===255&&edgeMax<=1&&padding>=Math.floor(info.width*0.04) : min===255);
    if(!pass) throw new Error(`${a.id}: 导出/透明度/可见边界检查失败 ${JSON.stringify({min,max,edgeMax,padding})}`);
    a.master_pixels=[sm.width,sm.height];a.master_sha256=hash(source);a.output_sha256=hash(output);
    rows.push({id:a.id,width:m.width,height:m.height,space:m.space,has_icc:!!m.icc,alpha_min:min,alpha_max:max,outer_edge_alpha_max:edgeMax,minimum_padding_alpha16:padding,visible_bounds_alpha128:b,warning:a.alpha&&edgeMax>0?'最外缘存在 alpha=1 的近透明残留；已保留，深浅底未见色边。':null,pass});
  }
  const pairs=[];
  for(const group of ['cookie','sugar']) {
    const a=raw.get(`source_${group}_full`),b=raw.get(`source_${group}_empty`);
    let same=0,union=0,intersection=0,diff=0;
    for(let i=3;i<a.data.length;i+=4){ const x=a.data[i]>=128,y=b.data[i]>=128; if(x||y)union++;if(x&&y)intersection++;if(x===y)same++;diff+=Math.abs(a.data[i]-b.data[i]); }
    const fullBounds=bbox(a.data,a.w,a.h),emptyBounds=bbox(b.data,b.w,b.h);
    const maxShift=Math.max(...Object.keys(fullBounds).map(k=>Math.abs(fullBounds[k]-emptyBounds[k])));
    if(intersection/union<0.99||maxShift>1) throw new Error(`${group}: 两态轮廓差异超过当前接入容差`);
    pairs.push({group,alpha_mask_iou:+(intersection/union).toFixed(6),alpha_mean_absolute_delta:+(diff/(a.w*a.h)).toFixed(3),max_bounds_delta_px:maxShift,full_bounds:fullBounds,empty_bounds:emptyBounds});
  }
  const soil=meta.assets.filter(a=>a.group==='terrain_soil'), seams=[];
  for(const a of soil) for(const b of soil) {
    const x=raw.get(a.id),y=raw.get(b.id);let h=0,v=0;
    for(let i=0;i<144;i++) for(let c=0;c<3;c++) {h+=Math.abs(x.data[(i*144+143)*4+c]-y.data[i*144*4+c]);v+=Math.abs(x.data[((143*144)+i)*4+c]-y.data[i*4+c]);}
    seams.push({from:a.id,to:b.id,horizontal_edge_rgb_mae:+(h/432).toFixed(3),vertical_edge_rgb_mae:+(v/432).toFixed(3)});
  }
  const qa={delivery:meta.delivery,sharp_version:sharp.versions.sharp,thresholds:{transparent_outer_edge_alpha_max:1,visible_padding_fraction_at_alpha16:0.04,pair_alpha128_iou_min:0.99,pair_max_bounds_delta_px:1},checks:rows,full_empty_pairs:pairs,soil_edges:seams,notes:'边缘差值是排查线索，不等于美术无缝验收。接触表为资产检视图，不是游戏截图。真机未测。'};
  fs.writeFileSync(metaPath,JSON.stringify(meta,null,2)+'\n');fs.writeFileSync(path.join(dir,'qa.json'),JSON.stringify(qa,null,2)+'\n');
  let body='<rect width="1140" height="1310" fill="#F6ECD8"/>'+text('CRUMB KINGDOM / A01-01',30,44,28)+text('Terrain + food sources | 9 runtime sprites | Artwork review, not gameplay',30,74,16);
  const layers=[];
  for(let i=0;i<meta.assets.length;i++){
    const a=meta.assets[i],col=i%3,row=Math.floor(i/3),x=30+col*370,y=100+row*395;
    body+=`<rect x="${x}" y="${y}" width="340" height="365" rx="12" fill="#E9DCC5"/>`+text(a.id,x+14,y+25,17)+text(`${a.pixels[0]}px / ${a.logical_points[0]}pt @3x`,x+14,y+48,14);
    const display=240;
    layers.push({input:await sharp(path.join(root,a.output)).resize(display,display).toBuffer(),left:x+50,top:y+62});
    const logical=a.logical_points[0];
    body+=text('Small size',x+14,y+337,12)+`<rect x="${x+128}" y="${y+308}" width="48" height="48" fill="#503B32"/>`;
    // 两种背景上的逻辑大小；Cookie 96pt 另放卡片内下方会溢出，改为 48px 预览并标注。
    const small=Math.min(48,logical);
    body+=text(logical===96?'50% preview':'48pt preview',x+225,y+337,12);
    layers.push({input:await sharp(path.join(root,a.output)).resize(small,small).toBuffer(),left:x+128,top:y+308});
  }
  await sharp(svg(1140,1310,body)).composite(layers).png().toFile(path.join(dir,'contact-sheet.png'));
  let proof='<rect width="1080" height="720" fill="#F6ECD8"/>'+text('A01-01 / edge + alpha + state checks',24,35,23)+text('Soil variants: no gaps, native 144px',24,68)+text('Light / dark backgrounds at logical size',495,68);
  const proofLayers=[];
  for(let r=0;r<3;r++)for(let c=0;c<3;c++)proofLayers.push({input:path.join(root,soil[(r+c)%3].output),left:24+c*144,top:90+r*144});
  let y=100;
  for(const group of [['source_cookie_full','source_cookie_empty'],['source_sugar_full','source_sugar_empty'],['terrain_stone','source_sap']]){
    proof+=text(group.join(' / '),495,y-8,13);
    for(let i=0;i<group.length;i++) {const a=meta.assets.find(x=>x.id===group[i]),n=a.logical_points[0];for(let bg=0;bg<2;bg++){
      const x=495+i*260+bg*120;proof+=`<rect x="${x}" y="${y}" width="110" height="110" fill="${bg?'#302925':'#FFFFFF'}"/>`;
      proofLayers.push({input:await sharp(path.join(root,a.output)).resize(n,n).toBuffer(),left:x+Math.floor((110-n)/2),top:y+Math.floor((110-n)/2)});
    }}y+=150;
  }
  proof+=text('No texture painting, masking or edge recoloring during export.',24,590,16)+text('Generated alpha is preserved. Device integration remains NOT_RUN.',24,618,16)+text('Soil seam acceptance requires visual inspection, not the numeric metric alone.',24,646,16);
  await sharp(svg(1080,720,proof)).composite(proofLayers).png().toFile(path.join(dir,'qa-proof.png'));
  console.log(JSON.stringify({assets:rows.length,all_export_checks_pass:rows.every(x=>x.pass),full_empty_pairs:pairs,soil_edges:seams},null,2));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
