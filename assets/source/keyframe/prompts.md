# A00 实际生成提示词

工具：内置 image_gen；不透明 PNG。中文交接，画面文案英文。初版仅作来源记录，不作为最终选用预览。

## 1. 主界面初稿

```text
Use case: ui-mockup.
Asset type: A00 art direction draft for an original iPhone game, Crumb Kingdom. Create ONE complete portrait gameplay screen, flat straight-on screen capture without a device frame. Target aspect ratio 390:844, as close as supported.
Primary request: A polished, warm miniature underground ant colony that feels like a tactile paper-and-clay natural history specimen box, while staying a clear playable 2D orthographic cutaway. This is a design mockup, not a marketing poster.
Composition: compact cream native-style HUD in the upper 17% of the screen, playable earth cutaway in the middle 66%, a calm cream instruction card and one honey-gold action button at the bottom 17%. Comfortable top safe area, no enormous game logo, no device bezel. Clean rounded system-like typography. All visible words must be English and limited to the exact UI copy specified below.
World: a narrow grassy surface strip and small central ant entrance. Under it a mostly unexcavated warm brown soil field, with a subtle square tile structure, rounded scalloped digging edges. ONE pale tunnel descends from the surface into ONE cozy queen chamber (wide rectangle, three cells by two cells) in the upper central region. A second pale tunnel leaves the chamber's lower-left edge, steps down and left at right angles toward a single delicious large golden cookie crumb deposit (two cells square) in the lower left. Leave ONE undug cracked soil cell between the explored path and the cookie as the immediate dig target, indicated by a clear cream dotted outline, not just color. Keep tunnel geometry strictly horizontal and vertical and visually one cell wide; no stairs, diagonal paths, perspective floors, random extra tunnels or unrelated rooms. Show a small white sugar deposit embedded in soil near the upper right and a tiny sage-green sap pocket further down the right, both disconnected. Rounded stone patches only at the far right.
Ants: around eight tiny friendly dark ants in the connected pale tunnels, each a clear simplified three-segment top-down silhouette, six small legs and two antennae. Some carry one tiny gold crumb. Space individuals so they do not form a black pile. In the queen chamber show a larger calm stylized queen and exactly two cream eggs in a subtle leaf nest. Keep all decoration within the chamber bounds. No built pantry in this state.
Rendering: original premium casual game art, matte handmade paper texture and softly modeled clay edges, restrained grain, broad uncluttered forms readable at phone size, consistent soft upper-left light and shallow contact shadows. Gentle, cozy, alive, not photorealistic insects or childish clipart. Terrain detail should support the route, not overpower it. No glowing magical elements, furniture houses or new gameplay systems.
Palette: paper #F6ECD8, soil #986B4C, deepest earth #503B32, pale walkable floor #DDBF91, ants #302925, cookie and main action #E8B654, sage #688C70. High contrast dark UI type. Make the cookie, queen and the dig target the three visual anchors.
Exact HUD copy, cleanly aligned:
"Food" above "62 / 100"
"Ants" above "8 / 24"
"Eggs" above "2"
A small gear icon at top right.
Second HUD row: "Surface Foraging" and "Food/min 33.3"
Exact bottom instruction: "Tap the soil to reach the crumb."
Exact single bottom button: "Build Pantry" with "50 Food" on its right.
UI values are illustrative design copy, not a certified numerical game snapshot. Do not add extra text, room labels, shop buttons, ads, coins, gems, time-limited offers, badges, watermarks, drop shadows over copy, fake navigation tabs or game title lettering. All UI text remains visually separate from world artwork; final game will use native text, this image is only the appearance draft.
```

## 2. 数值勘误（选用 main-screen-v2）

输入：本次主界面初稿。

```text
Edit the supplied Crumb Kingdom main gameplay mockup. Change ONLY the numeric text on the second HUD row from "Food/min 33.3" to "Food/min 53.3". Preserve every other word, layout, ant, room, texture, hue, object, position, crop and image dimensions. Render the replacement with identical font, baseline, scale and color. The corrected label must read exactly "Food/min 53.3". This is a concept UI illustration, not a real device screenshot.
```

## 3. 无文字底稿

输入：main-screen-v2.png。

```text
Create a text-free art direction plate by editing the supplied Crumb Kingdom screenshot concept. Preserve the exact portrait canvas dimensions, all underground artwork, tunnel layout, queen chamber, queen, two eggs, all worker ants, cookie deposit, sugar deposit, sap pocket, soil and rock textures, lighting, colors, and the grassy surface strip.
Change ONLY the UI overlay areas: remove the entire top HUD panel, all its words, numbers, separator rules, resource icons and gear; replace that upper area with a smooth quiet pale-cream paper background, without moving the grassy surface or map. Remove the entire bottom instruction panel, hand illustration, miniature dirt illustration, yellow button, all its words, icons, lines and numbers; replace that lower area with the same smooth quiet pale-cream paper background. Remove the cream dotted dig-target outline from the soil cell, leaving its cracked soil unchanged.
This is the text-free visual reference to place native UI over later. There must be absolutely no text, no numerals, no labels, no buttons, no border panels, no diagrams, no watermarks. Preserve every world object and the world composition. Do not stretch the map or fill the reserved top/bottom UI spaces with extra scenery. Opaque background, not transparent.
```
