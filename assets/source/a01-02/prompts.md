# A01-02 实际生成提示词

全部通过内置 image_gen 生成。每张贴图独立调用；通路 0 以初版通路 15 地面为编辑输入，通路 1–14 以通路 0 为编辑输入，不旋转母稿。初版地面保留在 reference_sources/tunnel-floor-initial.png；最终通路 15 与通路 4 又从通路 0 修订，采用本文件末尾 revision2。蚁后房间先生成再修订透明背景，初版保留为 reference_sources/room_queen-initial.png；前置输入不进入运行时。

## queen

生成文件：`exec-3c7750c1-825c-47ed-a47c-4e908ed80267.png`

```text
Use case: stylized-concept. Production sprite room_queen for Crumb Kingdom, a cozy flat 2D ant-colony game. LANDSCAPE canvas exactly 3:2 aspect ratio, ideally 1536x1024. One queen chamber decorative floor overlay, orthographic top view, not isometric. A softly rounded rectangular patch of pale packed sand #DDBF91 occupies the central 90% of the canvas, true transparent background around it with at least 4% empty padding. The floor has a very soft thin painted edge, NOT a raised enclosing wall, not a box or tray: all four sides are freely walkable and there are no doorway marks or specific entrances. A friendly dark charcoal-brown QUEEN ANT resting on a sage green leaf bed in the lower-right middle of the floor. Queen is clearly an ant: small head on left, middle thorax, one large plump abdomen on right, six short legs and two antennae, soft matte clay silhouette without realistic hairy detail. Her leaf bed takes no more than 45% width and 40% height. Keep the whole top third, especially the upper-left area, empty pale floor for two live egg sprites that the game will overlay later. Do NOT draw any eggs, worker ants, food, crown, text, icons or labels. Very subtle warm paper/clay texture, consistent gentle upper-left light, minimal decorative leaf flecks confined to bottom corners, no shadows outside the patch. Readable at 144x96pt; original charming casual game art with clean broad shapes. No UI, border, grid, vignette, perspective walls, 3D diorama pedestal, opaque background or fake transparency checkerboard.
```

## queen_cutout

生成文件：`exec-6e5ceadd-b7c3-4960-850b-3218243387de.png`

```text
Use case: background-extraction. Edit this queen-chamber sprite: REMOVE the entire brown blurred vignette/glow outside the pale floor patch and replace it with completely transparent pixels. Preserve the queen ant, leaves and entire interior pale floor as they are. Keep the exact 3:2 landscape canvas, composition, colors and lighting. The outer rounded floor silhouette must have a clean antialiased cutout edge with NO brown haze, no glow and no cast shadow outside it. Ensure the outermost 4% of canvas on ALL four sides is fully transparent; gently shrink the complete floor patch uniformly inside the existing canvas if needed to achieve padding without changing its aspect ratio. No border or added wall; keep all sides visually open. This must be a true alpha PNG isolated game sprite, not a framed illustration, not black/white background, not a transparency checkerboard.
```

## pantry

生成文件：`exec-8b5fcfc2-9518-402b-be74-20434f9a43de.png`

```text
Use case: stylized-concept. Production sprite room_pantry for Crumb Kingdom, cozy flat orthographic 2D ant-colony game. Single SQUARE canvas, ideally 1024x1024; true alpha background. A softly rounded-square pale sandy packed-earth floor patch #DDBF91, occupying central 88% of canvas with fully transparent padding around. No enclosing rim, no walls, box, doorway, border or threshold: this storage room is freely walkable from any side. Broad EMPTY pale center and open cross-shaped walking space. Arrange just TWO small low leaf storage racks along the upper-left and upper-right inner corners, not a continuous shelf across the top; left rack holds two softly rounded golden cookie pieces, right rack holds one ivory sugar piece and a small folded sage leaf parcel. A small empty leaf basket at lower-right corner. Props occupy at most 35% of the floor and never project outside the patch, keep all four side midpoints free. Storage props are illustrative decor, not literal inventory counters, so avoid an overflowing pile. Consistent warm matte clay and paper texture, simplified charming broad shapes readable at 96x96pt, gentle upper-left light, very subtle contact shadows only under props. No insects, eggs, Queen, text, labels, numbers, symbols, UI, isometric tilt, upright furniture wall, dark earth fill, vignette, glow or background shadow. Clean antialiased cutout floor edge, true transparency outside it; no white matte or checkerboard. Match a cream open Queen Chamber with sage leaf furnishings and dark ant characters.
```

## mask0

生成文件：`exec-34bb1c55-b883-4334-9e9a-d1de051a85d9.png`

```text
Use case: precise-object-edit. Convert this pale floor material into production terrain_tunnel_masks_0 for a tile-based 2D ant game. Keep the SAME square canvas and exact pale floor color/quiet central texture. Mask 0 is an isolated excavated cell: ALL FOUR edges are closed. Along the TOP, RIGHT, BOTTOM and LEFT canvas edges add a narrow continuous warm clay-brown soil lip #986B4C, occupying approximately 9% of the canvas width inward from each edge. The brown soil lip extends fully to the outer canvas edge, with NO outside margin. Inner edge has softly rounded concave corners and just a few broad irregularities, shallow clay relief, gentle upper-left light, not a stone wall. The wide center remains the original pale floor. Completely opaque tile fills every pixel. No openings on any edge. No decorative objects, text, symbols, ants, eggs, frames, perspective, shadows outside canvas or checkerboard. It should look like an excavated patch cut into warm earth, quiet and clear at 48pt. Avoid a thick raised tray, a dark vignette or a deep pit; retain a bright flat walking floor.
```

## mask1

生成文件：`exec-273a2b45-e824-4f23-b4ba-2e88a8457bf3.png`

```text
Use case: precise-object-edit. Produce terrain_tunnel_masks_1 from this isolated excavated square. Change ONLY the connection openings. OPEN edge: TOP (north). CLOSED edges: RIGHT, BOTTOM and LEFT. On the open edge completely remove the brown soil strip across the full width between the two side walls, extend the ORIGINAL pale sand floor seamlessly right to the outer canvas boundary, with no end-cap, no threshold, no rim, no dark line and no soil lip across the opening. The remaining closed-edge brown soil strips must stay in their exact original positions, thickness and material; their ends continue straight to the image boundary. Keep the same square canvas, center floor texture and colors, full opaque coverage and flat orthographic view. Do not make a small doorway: the opening spans the full interior corridor width (roughly 86% of the tile). No new colors, props, text, symbols, shadow vignette or extra exits. Preserve the parent floor's brightness, do not warm or brighten it. This 48pt tile must butt directly against another matching open edge without a visible barrier.
```

## mask2

生成文件：`exec-dcbd4735-d392-431a-96a4-ccffa65e56be.png`

```text
Use case: precise-object-edit. Produce terrain_tunnel_masks_2 from this isolated excavated square. Change ONLY the connection openings. OPEN edge: RIGHT (east). CLOSED edges: TOP, BOTTOM and LEFT. On the open edge completely remove the brown soil strip across the full width between the two side walls, extend the ORIGINAL pale sand floor seamlessly right to the outer canvas boundary, with no end-cap, no threshold, no rim, no dark line and no soil lip across the opening. The remaining closed-edge brown soil strips must stay in their exact original positions, thickness and material; their ends continue straight to the image boundary. Keep the same square canvas, center floor texture and colors, full opaque coverage and flat orthographic view. Do not make a small doorway: the opening spans the full interior corridor width (roughly 86% of the tile). No new colors, props, text, symbols, shadow vignette or extra exits. Preserve the parent floor's brightness, do not warm or brighten it. This 48pt tile must butt directly against another matching open edge without a visible barrier.
```

## mask3

生成文件：`exec-fa1af679-cd86-41a5-b43f-068c63f3a964.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_3. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: TOP (north), RIGHT (east). CLOSED edges: BOTTOM, LEFT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; they reach the image boundary at their ends. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask4

生成文件：`exec-2112f199-c515-4727-9372-2c3b47edcbe7.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_4. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: BOTTOM (south). CLOSED edges: TOP, RIGHT, LEFT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; they reach the image boundary at their ends. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask5

生成文件：`exec-ce291a82-5365-46d4-bee0-752434b7fadf.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_5. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: TOP (north), BOTTOM (south). CLOSED edges: RIGHT, LEFT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask6

生成文件：`exec-75658726-77ad-4c6f-be0a-ca3b1d4ba682.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_6. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: RIGHT (east), BOTTOM (south). CLOSED edges: TOP, LEFT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask7

生成文件：`exec-390cff7c-f9e8-43bb-a6ad-eb4dc3aff447.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_7. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: TOP (north), RIGHT (east), BOTTOM (south). CLOSED edges: LEFT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask8

生成文件：`exec-41d7bac7-5017-40e9-81ca-019d4a1b49fc.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_8. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: LEFT (west). CLOSED edges: TOP, RIGHT, BOTTOM. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask9

生成文件：`exec-fcb9db12-dd3b-4c28-b937-f345a6c3bd0b.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_9. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: TOP (north), LEFT (west). CLOSED edges: RIGHT, BOTTOM. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask10

生成文件：`exec-e3854913-7993-4ebc-84ff-b85f096eab31.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_10. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: RIGHT (east), LEFT (west). CLOSED edges: TOP, BOTTOM. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask11

生成文件：`exec-fdf69557-356a-4510-8851-224203d63e80.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_11. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: TOP (north), RIGHT (east), LEFT (west). CLOSED edges: BOTTOM. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask12

生成文件：`exec-f636281e-7a7f-4aa5-9ee1-2b8f82a784ec.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_12. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: BOTTOM (south), LEFT (west). CLOSED edges: TOP, RIGHT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask13

生成文件：`exec-a553be60-1545-46c5-aa4b-f4e8b944898f.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_13. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: TOP (north), BOTTOM (south), LEFT (west). CLOSED edges: RIGHT. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask14

生成文件：`exec-bb4cfb10-4977-4777-976a-8743aee851eb.png`

```text
Use case: precise-object-edit. Production terrain_tunnel_masks_14. Edit this closed square tunnel tile by changing ONLY its edge openings. OPEN edges: RIGHT (east), BOTTOM (south), LEFT (west). CLOSED edges: TOP. REMOVE the brown strip completely along every OPEN side and extend the existing pale packed-sand floor right to the outer canvas boundary. Each opening spans the full interior width (about 86%), not a small doorway. Where two OPEN sides meet, their shared corner is also PALE FLOOR, not a retained brown corner nub. Keep all CLOSED-side strips in their exact parent positions, thickness, shape and brown clay material; importantly they reach the image boundary at their ends, never stop early. Preserve square canvas, original quiet floor, palette and brightness. Fully OPAQUE edge-to-edge. Flat top-down, no perspective. No thresholds, dark lines across openings, new exits, objects, text, glyphs, shadows, glow or vignette. Same warm matte clay-and-paper casual game style; this tile will be shown at 48pt and joined to the other numbered masks.
```

## mask15

生成文件：`exec-5567df14-e0a2-412a-a8ab-63cb8ef258dc.png`

```text
Use case: stylized-concept. Production tile terrain_tunnel_masks_15 for a warm matte clay-and-paper 2D ant-colony game. Single SQUARE seamless material tile, ideally 144x144 pixels, COMPLETELY OPAQUE and edge-to-edge, no transparency. This tile has all four sides open: the ENTIRE square is pale packed-earth walking floor, sandy cream #DDBF91, extremely quiet sparse tiny tan dust flecks. Uniform ambient illumination across the whole canvas. No edge darkening or edge highlights. All four outer 15% bands must be almost perfectly uniform the same sandy cream color #DDBF91 so multiple copies and connector tiles can meet. Texture details are restrained to the central area, very subtle low contrast. Flat orthographic top view, not perspective, not a raised block. Do NOT draw walls, border, rim, cracks, large stones, tunnels as holes, an intersection symbol, arrows, insects, eggs, props, text, grid or UI. This is simply a beautiful quiet continuous floor material used inside a network of excavated tunnels. Its smooth pale value must contrast with medium clay-brown soil #986B4C.
```

## mask4_revision2（最终采用，替代上面的初版）

生成文件：exec-6eaa7ef7-5ecb-45b1-b98d-c25287babaf8.png

```text
Use case: precise-object-edit. Revised production terrain_tunnel_masks_4. Input is the shared mask 0 parent for all our tiles. The previous south-opening tile let the side walls stop before the bottom edge. Fix that: keep the TOP, LEFT and RIGHT brown soil lips, with the LEFT and RIGHT strips running continuously ALL THE WAY to the BOTTOM canvas boundary at unchanged thickness. Remove ONLY the BOTTOM horizontal strip between those side walls. Bottom center is open pale floor; both bottom corners still belong to the side wall strips. Do not round or terminate the side wall tips early. Top-left and top-right corners remain rounded as in the original. Preserve exact square dimensions, quiet central sand texture, matte clay-and-paper style and flat orthographic view. Every pixel opaque. No props, text, glyphs, insects, new light sources, gradients, transparent margin or raised block. Alter only the edge geometry specified above; all common floor and remaining wall regions should retain their original colors and detail. This is a 144px game autotile, not a standalone decorative illustration.
```

## mask15_revision2（最终采用，替代上面的初版）

生成文件：exec-ff2df2f7-8bd4-46d9-aaf2-2e79e22c3735.png

```text
Use case: precise-object-edit. Revised production terrain_tunnel_masks_15. Input is the shared mask 0 parent for all our tiles. Remove ALL FOUR brown soil strips, including every brown corner, and extend the SAME existing pale walking floor out to all four image boundaries. It is a fully open cell with pale floor across the ENTIRE square; no brown edge, corner, border, darkening or vignette. Match the central pale sand color of this parent, do not change its exposure or saturation. Keep the floor at the edge consistent with the center so that the tile joins other masks without forming a darker square. Preserve exact square dimensions, quiet central sand texture, matte clay-and-paper style and flat orthographic view. Every pixel opaque. No props, text, glyphs, insects, new light sources, gradients, transparent margin or raised block. Alter only the edge geometry specified above; all common floor and remaining wall regions should retain their original colors and detail. This is a 144px game autotile, not a standalone decorative illustration.
```
