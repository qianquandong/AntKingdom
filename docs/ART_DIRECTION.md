# 美术方向与资源交付规范

主责：Codex。运行时集成主责：Claude。状态：[A00 主界面方向样张与无文字底稿](../assets/source/keyframe/README.md)为 draft；[A01-01 地形/食物源](../assets/source/a01-01/README.md)与 [A01-02 通路/房间](../assets/source/a01-02/README.md)累计交付 27 张运行时 PNG，8 个资源组 reviewed，待客户端接入与真机终验。地表背景及其他图片/音频未交付。资源状态见 [manifest](../design/asset_manifest.json)。样张英文文字仅用于组合预览，正式贴图无烘焙文字。

## 1. 视觉目标

方向定为“温暖的微缩地下标本盒”：柔和纸张纹理、圆润土层、清晰的浅色通路、能读懂路线的小蚂蚁。玩家第一眼应看到 Cookie Crumb、Queen Chamber 与正在搬运的队伍，随后注意到可挖土边界。

使用正交 2D 地下剖面，不用等距透视；房间在同一平面，蚂蚁用简化俯视轮廓沿路径转向。固定左上柔光，少量接触阴影，避免大量写实毛发、细碎噪声与反光。三节身体、六条腿、两根触角，在小尺寸仍可辨认。世界保持可爱安静，不做写实虫群恐惧感。

| 角色 | 色值 | 用法 |
|---|---|---|
| 纸张/面板 | `#F6ECD8` | HUD 与说明背景 |
| 土层 | `#986B4C` | Soil 主色 |
| 土层深部 | `#503B32` | 地图外缘与暗部 |
| 通路 | `#DDBF91` | 可通行区域 |
| 蚂蚁 | `#302925` | 高辨识主体 |
| 食物/关键行动 | `#E8B654` | 饼干、高亮、主要按钮 |
| 正常连接 | `#688C70` | 连通反馈，与图形标记一起使用 |
| 繁忙/警示 | `#D57A3B` | 拥堵格，配队列图标/线型 |

调色板是制作起点，不表示每一组前景背景都已满足可访问性对比。Codex 在实际 HUD 和小尺寸贴图上检查对比；红绿不得作为唯一状态编码。

## 2. 主界面布局

主设计板使用 390×844pt，另做 375×667pt 和大屏适配检视。HUD 顶部显示 Food/Ants/Eggs，底部为上下文操作，中央地图为视觉主体；房间面板从底部展开，选择状态有明确边框。避免常驻商业化按钮抢占地图。

原生文字与按钮布局由 SwiftUI 实现；文本不烘焙进图。主要按钮至少 44pt 高。小屏不要强行把 9 列格子与宽面板同时挤进屏幕；游戏格默认 48pt，可横向轻拖看全图，另有总览缩放。引导把目标移动到视野内，不能让第一次挖格落在屏外。缩小总览后不得误把拖动当挖掘。

字体优先使用系统圆体风格与系统数字排版；不在包内拷贝无授权字体。Food/min、Trip 与库存数字保持清楚、稳定宽度，不能用装饰字牺牲可读性。

必须提供的设计状态：默认 HUD、源详情、Queen 面板、Pantry 建造合法/非法/确认/取消、移动预览、仓满、离线总结、设置、重置确认。正式版补章节选择、完成页、外观预览/已拥有、广告可用/加载/不可用/boost 中。

## 3. 资源规格与契约

统一 sRGB，地图/角色透明 PNG，背景可不透明；UI 图标可用干净矢量源，再按客户端要求导出。源文件保留可编辑版本，输出不预乘背景色、不画进黑白棋盘。

| 类别 | 导出基准 | 关键约定 |
|---|---|---|
| 单格地形/裂纹 | 144×144px，对应 48pt@3x | 逻辑占地一格；接缝不能有透明漏线 |
| 通路边缘 | 16 种四邻遮罩，每种 144×144px | 位序 N=1/E=2/S=4/W=8；只影响绘制，不影响通行 |
| Queen Chamber | 432×288px | 占 3×2 格，基准锚点中心 |
| Pantry / Cookie 区 | 288×288px | 占 2×2 格，不能画出误导性的额外入口 |
| Sugar / Sap / Stone | 144×144px | 1×1；Sugar 有货/空两态，Sap 连续源单态，Stone 单态 |
| 蚂蚁帧 | 96×96px 透明画布，主体约 60×36px | 统一中心锚点；基础朝右，四向由运行时旋转 |
| 蚂蚁动作 | idle 2 帧、walk 6 帧、carry 6 帧 | 帧间主体位置一致；所运食物保持独立可叠加 |
| UI 图标 | 96×96px 画布，显示约 24–32pt | 面板/文字由原生组件绘制 |
| 商店图标 | 先做 1024×1024px 主视觉源稿 | 最终 AppIcon 按当时 Xcode/Apple 资产规则导出验证 |

一套 walk 可供正常与繁忙队伍使用，速度来自逻辑周期；不额外生产几十套方向图。图集边缘留 padding/extrusion，导入前核对实际纹理尺寸、锚点和缩放。命名使用 `snake_case`，版本由 manifest 与 Git 管理，避免 `final_final2.png`。

交付包包含：asset ID、路径、用途、帧顺序、像素尺寸、逻辑尺寸、锚点、透明状态、许可证/生成来源、版本、预览接触表、状态。任何项缺失都不能标 `approved`。音频单列来源和循环点，不用无授权素材。

A01-02 通路虽然名称含 masks，交付的是完整不透明地形 PNG（包含地面与封闭土边），不是只有边缘的 alpha 图；图片上方=N。房间是带透明留白的开放装饰层，贴图尺寸使用完整占地 Queen 144×96pt / Pantry 96×96pt，不再套占位图的 3pt inset 拉伸，不以装饰/alpha 产生碰撞。具体接入和验收见 [Issue #13](https://github.com/qianquandong/AntKingdom/issues/13)。

## 4. 制作批次与验收

| 批次 | Codex 交付 | Claude 可同步做什么 | 验收证据 |
|---|---|---|---|
| A00 风格样张 | 完整主界面稿 + 1 蚂蚁/土块/房间近景 | C00–C03 灰盒 | 用户确认方向；实际尺寸可辨认 |
| A01 环境 | Soil/通路/石头/源/房间静态 | 地图/碰撞/布局 | 棋盘与深浅底测试，无接缝或假通路 |
| A02 生物与反馈 | 蚂蚁帧、卵、裂纹、碎屑、连接/繁忙反馈 | 动作状态与逻辑事件绑定 | 无跳帧位移；正常/繁忙可区分 |
| A03 UI 与音效 | 所有核心面板稿、图标、点击/建造/补给声音 | 适配、触觉、音量与减少动态 | 最小屏不截字；关闭效果不影响操作 |
| A04 内容 | 第二/三地图布局与目标、美术细节变化 | 数据加载与章节 | 免费通关录像；每图路线优化基准 |
| A05 商品 | Garden Decor Pack 的 Queen/Pantry 两件皮肤 | 预览、购买、恢复 | 美术和默认风格兼容；不改变碰撞/数值 |
| A06 发行素材 | 图标、5 张截图版式与英文标题 | 真实设备截图和商店上传 | 所示功能真实；无原型/调试 UI |

先做样张再成批制作。客户端占位与最终美术必须复用相同 ID 和尺寸，避免每换图都重写逻辑。Codex 以集成到设备的画面终验，源图好看不等于在游戏中可用。

## 5. 可直接复用的英文制作提示词

以下供 Codex 后续制作素材使用，是输入模板，不是已生成的素材；输出需经尺寸、帧一致性和授权检查后才能交付。

**Style keyframe**

> Create an original portrait mobile game art concept for "Crumb Kingdom": a warm miniature ant colony seen as a flat orthographic underground cutaway, rounded soil blocks, pale readable tunnels, tiny dark three-segment ants carrying cookie crumbs, a cozy queen chamber and a small pantry. Muted clay brown, cream, sage and honey gold. Soft paper texture, consistent upper-left light, clear shapes at small scale. Leave clean areas for native UI at the top and bottom. No baked-in text, no logos, no photorealistic insects, no isometric perspective.

**Ant reference**

> Design one original friendly worker ant for a cozy 2D colony game. Simplified top-down silhouette, three body segments, six legs, two antennae, facing right, readable at 24 pixels. Dark warm charcoal body with a small soft highlight. Centered on a transparent background, no ground, no shadow outside the sprite bounds, no text. This is a character reference; animation frames will be produced and checked separately.

**Room reference**

> Design a cozy underground pantry interior for a flat 2D cutaway game, a square two-by-two-tile footprint, pale packed-earth floor, tidy cookie crumbs and leaf shelving, rounded friendly shapes, soft upper-left lighting. Keep the walking floor readable and the outer silhouette inside the square. Transparent background, no text, no perspective tilt, no characters.

**Store icon concept**

> Create an original mobile game icon concept: a friendly dark ant carrying a large golden cookie crumb at the entrance of a warm little tunnel. One bold focal point, simple cream and clay background, readable at a tiny size, soft tactile shapes. Square composition, no words, no badge, no pre-rounded corners. Avoid realistic insect detail.

## 6. 商店截图分镜

首发计划 5 张：真实游戏画面占主导，Codex 加英文标题，Claude 从对应候选构建导出。尺寸按 [Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 和实际支持设备重新确认，不把一张截图拉伸套全部设备。

| 顺序 | 英文标题草案 | 必须有的真实画面 |
|---|---|---|
| 1 | Dig a Little Kingdom | 全景，已有可观察的蚁群与食物 |
| 2 | Make Every Path Count | 真实捷径/旁路和改善反馈 |
| 3 | Watch Your Colony Grow | Queen、卵与新蚂蚁 |
| 4 | Build Closer. Carry Faster. | Pantry 移动/合法放置 |
| 5 | Make It Your Own | 三地图选择或真实外观；付费外观注明 IAP |

无可玩构建前只做版式草图，不用生成的假截图充当商店实机图。预告视频可暂缓，避免它成为首发关键依赖。
