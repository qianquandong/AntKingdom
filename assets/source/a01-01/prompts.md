# A01-01 生成提示词

生成方式：内置 image_gen。每个 asset 单独生成；full→empty 使用 full 原稿作为编辑输入。土层 2/3 使用土层 1 作为编辑输入。实际生成分辨率见 metadata.json，运行时缩放导出与生成原稿分开保存。

## terrain_soil_1

```text
Use case: stylized-concept. Asset: terrain_soil_1, production master for a cozy flat 2D iPhone ant-colony game. Make a single SQUARE seamless tiling soil texture, ideally 144 x 144 pixels, completely opaque and filling the entire canvas edge to edge. Warm medium clay-brown base #986B4C, subtle matte paper/clay surface, very sparse small rounded earthen granules, soft shallow upper-left light. Quiet texture that will stay legible behind tiny dark ants and pale tunnel borders. Uniform brightness across the entire image; no corner darkening, no bevel, no vignette, no raised block, no gaps, no borders, no grid, no cracks, no frame, no soil cross-section perspective. Opposite edges must wrap seamlessly, and a thin outer edge band must blend into the same uniform medium clay-brown on all four sides to join two companion variants. Do not draw stones larger than 4% of the canvas; no grass, roots, insects, objects, text, glyphs or UI. This is raw flat orthographic material albedo, not an illustrated room or screenshot. Low-frequency earthy color variation, restrained detail; charming handmade casual-game art, not photorealistic noisy dirt.
```

## terrain_soil_2

```text
Edit this flat soil texture into companion terrain variant soil2. Preserve the exact image dimensions and every pixel within the outer 20% border on all four sides, so that this variant can meet the original tile without a new seam. Slightly rearrange only the sparse small clay granules in the central 60% of the tile; add one barely visible softer earthen patch, with the SAME mean brightness. Keep the same warm matte clay-brown paper texture, flat orthographic material, uniform lighting, no vignette, no tile border, no embossed block, no cracks, no objects, no text or insects. Changes should be very subtle at 144 pixels; this is a coordinated production tile variant, not a new scene.
```

## terrain_soil_3

```text
Edit this flat soil texture into companion terrain variant soil3. Preserve the exact image dimensions and every pixel within the outer 20% border on all four sides, so that this variant can meet the original tile without a new seam. Use fewer tiny granules in the central 60% and add two subtle shallow clay flecks, with the SAME mean brightness and color. Keep the same warm matte clay-brown paper texture, flat orthographic material, uniform lighting, no vignette, no tile border, no embossed block, no cracks, no objects, no text or insects. Changes should be very subtle at 144 pixels; this is a coordinated production tile variant, not a new scene.
```

## terrain_stone

```text
Use case: stylized-concept. Asset terrain_stone: one production game sprite for a cozy 2D ant-colony game. Single SQUARE canvas, ideally 144 by 144 pixels. One broad irregular rounded warm-gray stone blockage seen in flat orthographic top view, like a handmade matte clay pebble with three broad simplified facets. Muted warm grey #7A6E66, charcoal-brown low-contrast crevices and soft upper-left illumination; no shiny realistic rock texture. It occupies the central 86% of the square, with a clearly readable solid silhouette. A very small integrated contact shadow may stay beneath it but cannot extend beyond the sprite's inner margin. True transparent background; keep at least 5% transparent padding on every edge. No soil background, no floor, no scenery, no UI or text, no multiple separate rocks, no tunnel-like pale holes, no isometric angle, no perspective base slab. Match the warm clay-and-paper casual-game materials of Crumb Kingdom. Designed to read as an impassable stone at 48pt.
```

## source_cookie_full

```text
Use case: stylized-concept. Asset source_cookie_full. One standalone SQUARE production sprite, ideally 288 x 288 pixels, for a warm handmade-clay-and-paper 2D ant-colony game. Flat orthographic top-down view, no perspective tilt. A single large appealing golden cookie crumb deposit: 3 or 4 chunky broken biscuit pieces, buttery ochre #E8B654, broad soft porous facets, a few clean biscuit pores, no chocolate chips. They sit inside a shallow rounded-square dark earth patch whose outside footprint fills about 88% of the square canvas. Thin gently scalloped clay rim #986B4C, earth floor slightly darker, soft upper-left light. All objects stay within the patch; at least 5% truly transparent padding on every side. Make the full pile occupy most of the patch, leaving an unchanged thin visible rim that can match an empty-state sprite later. Bold simplified shapes readable at 96pt; matte material, no glitter. No tunnels or entrances in the rim, no characters, ants, eggs, plants, gems, coins, labels, UI or text. Transparent background outside the isolated patch, no white matte or checkerboard drawn into the image. This is a finite food deposit, not a room or a plate.
```

## source_cookie_empty

```text
Edit the supplied source_cookie_full production game sprite into its depleted counterpart source_cookie_empty. Keep exactly the same square canvas size, centered anchor, transparent background, outside silhouette, padding, earth rim, earth colors and light direction. Preserve the earth patch's outer rim shape and all pixels outside the food area as closely as possible. Remove ALL of the large golden biscuit pieces and replace the area they covered with the same dark packed-earth floor of the patch. Leave only a very faint sprinkling of tiny biscuit dust, not a remaining harvestable piece. The empty state must read immediately as depleted at 96pt, while still clearly an occupied impassable dark food-source footprint, never a pale walkable tunnel. No new holes or entrances, objects, text, icons, ants or UI. Flat orthographic top view, warm matte clay-and-paper style, true alpha background outside the patch.
```

## source_sugar_full

```text
Use case: stylized-concept. Production game sprite source_sugar_full for Crumb Kingdom. Single square image, ideally 144x144 pixels, true transparent background. A compact pile of 3 large ivory-white sugar crystals with simple angular broad facets, cream highlights #FFF4DD and warm muted gray shadows, sitting on a small dark packed-earth rounded-square patch. Flat orthographic top-down view; subtly handmade matte clay-and-paper material, restrained soft light from upper left. Thin rounded clay rim #986B4C, darker brown soil floor #503B32, no plate or container. The entire patch fits inside the central 86% of canvas, leaving at least 6% transparent padding on all four sides. Sugar should fill the central area and stay inside the rim so the rim can remain identical in a depleted-state version. Bold silhouettes read at 48pt; minimal pores and grain, no glitter. No text, labels, coins, candy wrappers, plants, characters, UI, tunnel entrances, white matte or drawn checkerboard. Differentiate from golden round cookie chunks using pale angular crystal shapes.
```

## source_sugar_empty

```text
Use case: precise-object-edit. Edit this source_sugar_full production sprite into source_sugar_empty. Remove only the three large ivory sugar crystals. Fill their former area with the matching dark packed earth floor, leaving just a few very small pale sugar dust specks: there must be no remaining harvestable sugar chunk. Keep exactly the same square canvas, original patch size and centered position, transparent padding, outside alpha silhouette, clay rim shape and all existing visible soil texture outside the former crystal area. Preserve warm matte clay-and-paper style, soft upper-left lighting, flat orthographic top-down view. Do not enlarge the earth patch to fill the image. The depleted state remains a dark blocked food-source footprint, not a walkable pale floor. No added holes, portals, labels, text, characters, UI, plants, or objects. True transparency outside the existing rim, no matte.
```

## source_sap

```text
Use case: stylized-concept. Production sprite source_sap, cozy 2D ant-colony game Crumb Kingdom. Single SQUARE canvas, ideally 144x144 pixels, true transparent background. Flat orthographic top-down view of a small rounded-square patch of dark packed earth bounded by a thin warm clay rim #986B4C. Inside the rim is one broad organically rounded pool of amber-green tree sap: muted sage-olive green #8B9A59 with a little honey amber #C9A653 towards the center and ONE broad soft cream highlight. The sap must look viscous and sweet, not water or a gem. Small simple green leaf tip at the inside upper corner gives a tree-sap cue but never extends beyond the earth patch. Matte handmade clay-and-paper environment, restrained upper-left light, clear clean big shapes at 48pt, almost no fine texture. Patch occupies central 80% of canvas, at least 8% transparent padding on all sides. Match warm clay rim and dark floor used for cookie and sugar food deposits. No ants, text, UI, labels, coins, trees, vessel, pedestal, tunnels, entrances, isometric tilt, photorealistic gloss, white matte or checkerboard. This continuous source has one state, so show a stable generous sap pool.
```
