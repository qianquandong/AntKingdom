# A02-01 实际生成提示词

使用内置 image_gen；每个最终资产/修订单独一次调用，透明背景均启用。原稿的实际尺寸以 metadata 为准，不能把提示词尺寸当作工具输出尺寸。图片中文字为空；检视页英文标签是后期排版。

## ant_worker_idle_1

- 来源文件：`exec-d0ee232a-20fd-47d6-aa27-37a5f1f4e4b8.png`
- 参考：room_queen (style only)

```text
Use case: stylized-concept. Asset type: production 2D iPhone game sprite, ant_worker_idle_1, transparent square 1024x1024 canvas. Create ONE original friendly worker ant for Crumb Kingdom. The attached queen-room picture is ONLY a material/color style reference, not the pose or composition: match the soft hand-painted warm dark chocolate/charcoal body and muted upper-left highlights. The worker must be an orthographic TOP-DOWN ant, facing EXACTLY RIGHT, perfectly horizontal, with three clearly separated rounded body segments, a large oval abdomen on the left, small thorax at the canvas center, modest round head on the right, EXACTLY SIX legs (three above and three below) and two fine bent antennae projecting right. No wings. No clothing, no eyebrows, no human face. Keep a simple friendly silhouette that reads at 20 pixels wide. Fixed registration: thorax pivot at (512,512); abdomen center approximately (370,512); head center approximately (645,512); entire ant including legs and antennae inside x=175..840,y=325..699. Three body segments must remain on y=512. Legs planted symmetrically in a quiet idle stance. Body is warm deep brown #45382C with subtle broad highlight #75614B, outline dark brown, not shiny plastic and not black hairline limbs. No food carried: cargo is a separate sprite. All background pixels genuinely transparent including around and between legs; no ground, leaf, stage, paper rectangle, checkerboard, floor, glow or cast shadow. No text, numbers, grid, labels, extra ants or multiple frames. This one file is one frame, generous transparent margins. Preserve maximum silhouette clarity after reducing to 96x96.
```

## ant_worker_idle_2

- 来源文件：`exec-7fc43bd4-8ca0-444d-a6b7-3eedfadb21cd.png`
- 参考：ant_worker_idle_1

```text
Use case: precise-object-edit. Edit target: the attached SINGLE ant sprite. Output ONE transparent sprite frame named ant_worker_idle_2. Keep original square canvas and exact framing. CRITICAL invariants: preserve the original body pixels, body contour, abdomen bands, head eye, body segment sizes, torso center, upper-left highlights, colors, opacity, antenna roots, and right-facing orientation. Do not redraw, rescale, translate or rotate the torso. Keep 6 legs only. Change ONLY the distal ends of the two antennae: gently lower the upper antenna tip by 12 pixels and raise the lower tip by 12 pixels, a barely visible calm twitch. Keep ALL six legs and the entire three-segment body exactly unchanged. Idle frame 2 of 2. Keep every extremity fully inside the original transparent margins. No cast shadow, food, props, text, border, new backdrop, grid, or extra ants. True transparent background; one frame only. Match the reference's painterly edges and leg thickness.
```

## ant_worker_walk_1

- 来源文件：`exec-5698776b-4f46-47db-8c2c-1a1ce10a723e.png`
- 参考：ant_worker_idle_1

```text
Use case: precise-object-edit. Edit target: the attached SINGLE ant sprite. Output ONE transparent sprite frame named ant_worker_walk_1. Keep original square canvas and exact framing. CRITICAL invariants: preserve the original body pixels, body contour, abdomen bands, head eye, body segment sizes, torso center, upper-left highlights, colors, opacity, antenna roots, and right-facing orientation. Do not redraw, rescale, translate or rotate the torso. Keep 6 legs only. Walk cycle frame 1 of 6, alternating tripod gait, rightward travel but stationary torso. Legs named Ufront, Umiddle, Urear above the body and Lfront, Lmiddle, Lrear below it. Tripod A = Ufront/Urear/Lmiddle: extend distal feet about 45 px to the RIGHT of the neutral stance. Tripod B = Lfront/Lrear/Umiddle: extend distal feet about 45 px to the LEFT of neutral. Keep leg roots fixed and legs bent naturally. Keep all body segments and antennae exactly unchanged. Keep every extremity fully inside the original transparent margins. No cast shadow, food, props, text, border, new backdrop, grid, or extra ants. True transparent background; one frame only. Match the reference's painterly edges and leg thickness.
```

## ant_worker_walk_2

- 来源文件：`exec-a72ce716-c9bf-4be6-a07a-a350c0861037.png`
- 参考：ant_worker_walk_2-initial

```text
Use case: precise-object-edit. Repair the attached single worker-ant walk sprite. Keep its 1280x1280 transparent canvas, three body segments, head, eye, bands, antennae, existing five legs, lighting and every non-leg pixel unchanged. There is a MISSING SIXTH LEG on the UPPER REAR side. Restore exactly ONE upper rear leg attached at the left/top edge of the thorax (around x=585,y=605), bending up-left with knee near (530,485) and foot near (448,440). It must be clearly visible above the abdomen, same brown and thickness as the other legs. Final total is exactly THREE legs above, THREE legs below, and two antennae at the right. Do not remove or merge any of the other legs. No body movement or scaling. One transparent image, no labels, no food.
```

## ant_worker_walk_3

- 来源文件：`exec-3e689461-b165-49ff-b4eb-ec18b02acb81.png`
- 参考：ant_worker_walk_3-initial

```text
Use case: precise-object-edit. Target: attached ant frame. Repair ONLY the crossed pair of legs above the front half. Keep the 1280x1280 transparent canvas and EVERY body segment, eye, texture, band, highlight, antenna, lower legs and upper rearmost leg unchanged. There must be exactly three separate legs above the body. Keep the upper FRONT leg rooted near (790,602) and ending at (864,451). Move ONLY the upper MIDDLE leg so it starts near (684,584), bends at (662,465) and ends around (606,405). This removes the X-shaped crossing. Upper middle and front legs must have a visible transparent gap between them, without crossing or touching. Do not change anything else or add food/text/background. Preserve body registration and all alpha padding.
```

## ant_worker_walk_4

- 来源文件：`exec-1f35a081-58e7-445e-974c-02184ec71d05.png`
- 参考：ant_worker_idle_1

```text
Use case: precise-object-edit. Attached image is the edit target: one right-facing worker ant. Produce ONLY frame ant_worker_walk_4, one transparent square image. Preserve the original canvas 1280x1280 and exact original body pixels/outline/position: no new illustration, no repositioning, no zoom, no changes to abdomen/head/thorax/eye/antennae/highlights. Change ONLY six leg joint poses. All SIX legs must remain clearly visible: 3 above the body, 3 below. Upper rear leg must not disappear behind the abdomen. Walk cycle frame 4 of 6, opposite of frame 1. Tripod A (upper front, upper rear, lower middle) feet 45px LEFT of neutral; tripod B (lower front, lower rear, upper middle) feet 45px RIGHT of neutral. Keep leg roots fixed, body segments and antennae exactly unchanged. Keep generous transparent margins; transparent background with no ground or shadow, no food, no text. Each leg root stays attached in its original location; keep the same leg thickness.
```

## ant_worker_walk_5

- 来源文件：`exec-73b33253-f6ab-430e-a00a-da6b0ba516b6.png`
- 参考：ant_worker_idle_1

```text
Use case: precise-object-edit. Edit the attached ant into one frame ant_worker_walk_5. Preserve 1280x1280 canvas, same stationary horizontal right-facing torso, same body pixels/outline/abdomen bands/eye/antennae and body registration. Do not redraw, rescale or translate the ant body. Change ONLY legs. Exactly SIX clearly visible separated legs, three upper and three lower. Upper rear leg must remain visible. Keep three upper legs separated without crossing each other. Walk cycle frame 5 of 6. Tripod A (upper front, upper rear, lower middle) feet near neutral, lifted 10px closer to body; tripod B (lower front, lower rear, upper middle) feet 20px RIGHT of neutral. Only articulate legs, keep roots, body segments and antennae exactly unchanged. No food, props, backdrop, ground, shadow, text or extra figures. Transparent background.
```

## ant_worker_walk_6

- 来源文件：`exec-004fbc22-a3fe-498d-92e1-e7f098007c82.png`
- 参考：ant_worker_idle_1

```text
Use case: precise-object-edit. Edit the attached ant into one frame ant_worker_walk_6. Preserve 1280x1280 canvas, same stationary horizontal right-facing torso, same body pixels/outline/abdomen bands/eye/antennae and body registration. Do not redraw, rescale or translate the ant body. Change ONLY legs. Exactly SIX clearly visible separated legs, three upper and three lower. Upper rear leg must remain visible. Keep three upper legs separated without crossing each other. Walk cycle frame 6 of 6 returning toward frame 1. Tripod A (upper front, upper rear, lower middle) feet 20px RIGHT of neutral; tripod B (lower front, lower rear, upper middle) feet 20px LEFT of neutral. Keep leg roots fixed and body segments and antennae exactly unchanged. No food, props, backdrop, ground, shadow, text or extra figures. Transparent background.
```

## ant_worker_carry_1

- 来源文件：`exec-7eb9e2bc-3e91-475e-ba7f-1d3c576ed1aa.png`
- 参考：ant_worker_idle_1 + carry_1 initial

```text
Use case: precise-object-edit. Image 1 is TARGET carrying ant frame 1. Image 2 is authoritative base ant for BODY identity and geometry. Keep image 1's SIX legs and narrowed antennae in the same stride pose. Restore only the three BODY SEGMENTS to image 2's dark muted chocolate/charcoal color, exact painted texture and bands, body silhouette, size and centered registration. The target torso is slightly shifted/enlarged and brighter; make abdomen, thorax and head match image 2 precisely, with no warm/orange boost. Keep single eye and highlight. Keep all six legs visible, connect existing roots naturally without redesigning their poses. Same transparent square canvas. No food, floor, text, cast shadow or extra objects.
```

## ant_worker_carry_2

- 来源文件：`exec-6a4ae3f2-0902-4cff-919f-9381b23fb27b.png`
- 参考：ant_worker_idle_1 + carry_2 initial

```text
Use case: precise-object-edit. Image 1 is the TARGET carrying ant frame. Image 2 is the authoritative base worker ant, used ONLY to restore torso colors, texture and exact torso silhouette. Keep image 1's six leg poses and narrowed antennae. Correct the BODY ONLY: its abdomen, thorax and head became too bright/orange. Restore these three body segments to the exact dark muted brown tones and painted texture of image 2. Match image 2's body geometry and registration; keep the eye highlight and abdomen bands the same as image 2. Do not redesign any shape or limb. Dark chocolate/charcoal, no orange saturation increase. Same square transparent canvas and margins as inputs. No food, background or shadow. One ant frame.
```

## ant_worker_carry_3

- 来源文件：`exec-0bf217da-370c-4d18-aec0-553247412c1a.png`
- 参考：ant_worker_walk_3

```text
Use case: precise-object-edit. ONE ant carrying frame 3; attached walk frame is the edit target. Keep the entire body, SIX legs and their pose, eye, body size and position, original dark brown paint, texture and upper-left shading pixel-stable. DO NOT brighten, recolor or redraw the body. Keep 1280x1280 transparent canvas. Change only antennae: softly narrow them toward the right-facing mouth, upper tip near original x=1070,y=625, lower tip near x=1080,y=713, preserving distinct ends and a clear gap. Cargo is independent, so no food in this frame. No floor, shadow, text, border or objects.
```

## ant_worker_carry_4

- 来源文件：`exec-80c7f82c-67d8-4ff0-bbca-8af5ddf38797.png`
- 参考：ant_worker_walk_4

```text
Use case: precise-object-edit. Attached image is walk frame 4. Make only a subtle antenna pose edit for carrying frame 4: upper antenna angles gently down toward the rightward mouth, lower antenna angles gently up. Tips remain separate and no food is drawn. Preserve 1280x1280 transparent canvas, dark brown colors, highlights, texture, body location and exact body contour, THREE segments and all SIX legs in their current positions. Do not brighten, thicken, recolor, reposition or regenerate the body. Do not change stride. ONE ant, no text or additional object, no background or shadow.
```

## ant_worker_carry_5

- 来源文件：`exec-31c73c9c-8cf3-4426-839f-54966f3adaa6.png`
- 参考：ant_worker_walk_5

```text
Use case: precise-object-edit. Make ant carrying frame 5 by editing ONLY antennae of the attached walk sprite. Keep 1280x1280 transparent canvas, exact stationary body position/size, dark warm brown colors, body pixels/texture/highlights/bands/eye, and all SIX leg poses. Subtly curve the upper antenna tip downward and lower tip upward, toward a separate crumb that will sit in front of the mouth. Antenna tips stay visibly separated. No body movement or recoloring. Do not add food or props, no backdrop, no shadow, no text. One ant only.
```

## ant_worker_carry_6

- 来源文件：`exec-90710392-4b2a-47be-9239-3fbc36410464.png`
- 参考：ant_worker_idle_1 + carry_6 initial

```text
Use case: precise-object-edit. Image 1 TARGET is carrying ant frame 6. Image 2 is authoritative base worker ant for body color and paint. Keep image 1's SIX legs and their exact stride, curled antennae, silhouette, body size/location, eye and canvas unchanged. Correct only the body paint: the abdomen, thorax and head must match image 2's muted dark charcoal-brown colors and restrained highlights. Remove the target's brighter orange/brown cast. Preserve painted texture and abdomen bands; do not shift or scale. No new body parts, no food, no shadow, text or floor. True transparent square background.
```

## ant_cargo

- 来源文件：`exec-6f25d5f8-b167-4417-b45f-b74fc64159e1.png`
- 参考：无（新生成）

```text
Use case: stylized-concept. Asset type: single carried FOOD CRUMB sprite for Crumb Kingdom, cozy hand-painted 2D ant colony game. Genuinely transparent square 1024x1024 canvas. One small rounded irregular golden cookie crumb with a friendly clear polygonal silhouette, centered at (512,512), visible footprint approximately 420x360 pixels, about 40% of the square width. Honey-gold #D9AA48, toasted edge #9F6E34, pale butter highlight at upper left, two or three subtle tiny pores on its surface, simple gouache shading. It will display on a 16pt canvas and must read as one tiny food pellet, not a whole biscuit or a pile. No chocolate chip, no ant, no plate, no surrounding scattered crumbs, no wrapper or leaf, no cast shadow or floor, no letters or numbers. All exterior truly transparent and generous clear margins.
```

## egg_states_normal

- 来源文件：`exec-bf22ad57-7fd4-4a5c-9b2f-7c29511ba862.png`
- 参考：无（新生成）

```text
Use case: stylized-concept. Asset type: single production 2D game egg sprite for a cozy miniature ant colony, on a genuinely transparent square 1024x1024 canvas. ONE small smooth cream-colored ant egg/cocoon, upright vertical oval, gently tapered at top, rounded at bottom, centered EXACTLY (512,512). Visible silhouette fits x=300..724 and y=230..794, approximately 42% width and 55% height. Warm ivory #F7E6BF, soft pale golden tan edge #B99058, subtle upper-left warm highlight. Simple hand-painted gouache texture with extremely restrained fine fibers, friendly soft shape, tiny-scale clarity. No chicken eggshell spots, no cracks in normal state, no facial features, no legs, no baby insect visible, no leaf/nest/plate/ground, no halo or cast shadow, no text/grid/checkerboard. Keep the outline clear against a pale sand tunnel and dark brown soil. All exterior pixels transparent; generous transparent margins. One egg only, no cluster.
```

## egg_states_ready

- 来源文件：`exec-54ea4ccb-6cbc-4ed2-9465-0a78516545f7.png`
- 参考：egg_states_normal

```text
Use case: precise-object-edit. Edit target: attached single ivory ant egg/cocoon. Make the READY-TO-HATCH state. Preserve EXACT 1280x1280 canvas, egg outer silhouette and alpha boundary, size, position, vertical orientation, cream colors and original light/shading. Change only a small area INSIDE the front middle of the cocoon: add a clearly visible warm brown short opening seam, a soft shallow three-segment zig-zag, centered across its middle third. It should look like a tiny cocoon beginning to split, not a broken chicken egg. Dark brown seam thick enough to read when sprite is displayed at 24x24 pixels, but no hole, baby, detached shell, extra bits or deformation of the outer edge. Keep original contour pixel-stable. No glow, star, sparkles, shadow, text, ground or extra eggs; exterior truly transparent.
```

## ant_worker_walk_2-initial

- 来源文件：`exec-5ab89dcc-53e9-4677-ab56-b9dd54036924.png`
- 参考：ant_worker_idle_1
- 未采用原因：missing upper rear leg

```text
Use case: precise-object-edit. Edit target: the attached SINGLE ant sprite. Output ONE transparent sprite frame named ant_worker_walk_2. Keep original square canvas and exact framing. CRITICAL invariants: preserve the original body pixels, body contour, abdomen bands, head eye, body segment sizes, torso center, upper-left highlights, colors, opacity, antenna roots, and right-facing orientation. Do not redraw, rescale, translate or rotate the torso. Keep 6 legs only. Walk cycle frame 2 of 6, alternating tripod gait. Tripod A (upper front, upper rear, lower middle) feet about 20 pixels RIGHT of neutral; tripod B (lower front, lower rear, upper middle) feet near neutral, lifted slightly 10px closer to the body. Only articulate knees and distal legs; keep roots, body segments and antennae unchanged. Keep every extremity fully inside the original transparent margins. No cast shadow, food, props, text, border, new backdrop, grid, or extra ants. True transparent background; one frame only. Match the reference's painterly edges and leg thickness.
```

## ant_worker_walk_3-initial

- 来源文件：`exec-76f8708f-453b-423f-a80b-8543c3a5a009.png`
- 参考：ant_worker_idle_1
- 未采用原因：crossing upper legs

```text
Use case: precise-object-edit. Attached image is the edit target: one right-facing worker ant. Produce ONLY frame ant_worker_walk_3, one transparent square image. Preserve the original canvas 1280x1280 and exact original body pixels/outline/position: no new illustration, no repositioning, no zoom, no changes to abdomen/head/thorax/eye/antennae/highlights. Change ONLY six leg joint poses. All SIX legs must remain clearly visible: 3 above the body, 3 below. Upper rear leg must not disappear behind the abdomen. Walk cycle frame 3 of 6, alternating tripod gait. Tripod A (upper front, upper rear, lower middle) feet about 20 pixels LEFT of neutral; tripod B (lower front, lower rear, upper middle) feet about 20 pixels RIGHT of neutral. Only articulate legs, keep roots, three body segments and antennae exactly unchanged. Keep generous transparent margins; transparent background with no ground or shadow, no food, no text. Each leg root stays attached in its original location; keep the same leg thickness.
```

## ant_worker_carry_1-initial

- 来源文件：`exec-810aac0d-5239-45c4-800b-fd23faa41e01.png`
- 参考：ant_worker_walk_1
- 未采用原因：body color/registration drift > 14/255

```text
Use case: precise-object-edit. Produce carrying-cycle frame 1 from the attached walk-cycle frame 1. ONE transparent 1280x1280 sprite. Change ONLY the antennae: bring both tips toward the right-facing mouth center so they form a narrower forward-reaching pair, ready to guide a separate food crumb at runtime. Their tips should remain distinct and not join. Preserve all SIX legs in EXACTLY the same stride pose and preserve every body segment, body position/size, eye, abdomen bands, painted texture and highlight. Do not add a crumb: cargo is an independent image. No torso movement or redraw, no rescaling, no text, floor, shadow, grid or other objects. Maintain true transparency and the same margins. This is the same ant as the reference, only a slight antenna pose edit.
```

## ant_worker_carry_2-initial

- 来源文件：`exec-4688502b-19ac-4ac0-947d-2652bf1c7d8f.png`
- 参考：ant_worker_walk_2
- 未采用原因：body color/registration drift > 14/255

```text
Use case: precise-object-edit. ONE production ant carrying frame 2. Attached walk frame 2 is edit target. Preserve original 1280x1280 transparent canvas and exact body registration, all three segments, abdomen bands, eye, painted texture, highlights, and all SIX legs in this exact stride. Change ONLY both antennae into a narrower forward-reaching pair toward the mouth: upper and lower tips approach y=640 and y=700, respectively, with a clear gap. They do not touch or cross. No body redraw, no motion, no scaling, no leg changes. Do not draw food: independent cargo will be overlaid by game. No text, floor, ground shadow, objects or background.
```

## ant_worker_carry_6-initial

- 来源文件：`exec-f06058aa-d3ca-4829-a589-c0516d43eda3.png`
- 参考：ant_worker_walk_6
- 未采用原因：body color/registration drift > 14/255

```text
Use case: precise-object-edit. Ant carrying frame 6. Attached walk frame 6 is the edit target. Keep 1280x1280 transparent canvas. Preserve the entire torso (three segments, brown paint, size, exact position, bands, eye, highlights) and SIX legs exactly unchanged. Only curl the ends of both antennae a little inward toward the rightward mouth, maintaining a clear gap between their tips. Keep original thin antenna thickness, do not make claws. Do not brighten, redraw or move any body part. No food: separate cargo sprite used later. No text, background, shadow or additional figures.
```
