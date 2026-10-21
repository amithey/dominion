# Art request for Codex: image-made assets for DOMINION (from Claude)

Goal: make the game look realistic. The game is a 3D real-time strategy game in Godot 4.7 (Forward+ renderer),
camera free, seen from about 8 m to 500 m. Claude writes the code that loads and uses what you make, so everything below
has to be **a plain file that can be dropped into the project**, with a fixed name and layout. Do not edit any
`.gd`, `.gdshader`, `.tscn`, `project.godot` or `export_presets.cfg` file, and do not create `.import` or `.uid` files
(Godot makes them). Only add files under `native/godot/assets/art/` and one manifest file (see the end).

## House rules for every file
- **Realistic, muted, photographic.** No cartoon outline, no glow, no painterly brush. Think aerial and ground photography
  of real places, in overcast-to-sunny daylight. No text, no logos, no real insignia, flags or trademarked designs.
  Everything must be original (made by you), with no copyrighted likeness; say in the manifest how each file was made.
- **No baked light and no baked shadows** in colour maps (the game lights them itself): flat, even lighting, as
  "albedo" or "diffuse" textures for a PBR renderer. Colour in sRGB.
- **Format:** PNG, 8 bit, sizes in powers of two (256, 512, 1024, 2048; 4096 only for flipbooks). Straight alpha (not premultiplied).
- **Seamless** wherever it says tileable: the four edges must meet with no visible seam when tiled 3 x 3.
- **Normal maps:** tangent space, OpenGL convention (green up), flat = RGB(128,128,255). **Roughness:** grey (white = rough).
  **Height:** grey (white = high). **AO:** grey (white = open). Name the maps `_albedo`, `_normal`, `_roughness`, `_ao`, `_height`.
- Where a file says **animation / flipbook**: one PNG with the frames in a grid, left to right and top to bottom, equal cells,
  and the frame count and grid size written in the file name (`..._8x8.png`).

## What to make, in this order (finish a tier before the next; commit after each tier)

### Tier 1: flipbook animations for effects (the biggest visual gain)
Folder `native/godot/assets/art/fx/`. All 2048 x 2048, 8 x 8 = 64 frames, black-free alpha (the background fully transparent).
Each should look like a real photographed or filmed event, turned into a loop-free one-shot (start from nothing, end faded).
1. `fx_explosion_ground_8x8.png` : a ground explosion with a fireball, dirt thrown up, smoke rising; grey and orange only.
2. `fx_explosion_air_8x8.png` : an air burst: a round fireball and expanding smoke ring.
3. `fx_fireball_additive_8x8.png` : only the glowing fire part, on black, to be added (no alpha, black background).
4. `fx_smoke_column_8x8.png` : a dark smoke plume rising and spreading (alpha), grey to black.
5. `fx_smoke_light_8x8.png` : light grey / white dust and smoke puff (alpha), used for dust and chimneys.
6. `fx_dust_impact_8x8.png` : a small puff of dust from a shell or bullet hitting the ground (alpha, brown).
7. `fx_muzzle_flash_4x4.png` (1024 x 1024, 16 frames): a gun muzzle flash from the side, on black, to be added.
8. `fx_fire_loop_8x4.png` (2048 x 1024, 32 frames): a loop of a burning wreck's flames (seamless in time), on black, to be added.
9. `fx_water_splash_8x8.png` : a splash of water from a shell hitting the sea (alpha, white and pale blue).
10. `fx_missile_trail_8x4.png` (2048 x 1024): a thin exhaust and smoke trail segment, to be tiled along a missile's path (alpha).

### Tier 2: tileable PBR materials (ground and buildings)
Folder `native/godot/assets/art/materials/`, 2048 x 2048 each (1024 for the small ones), each with `_albedo`, `_normal`, `_roughness`, `_ao`, `_height`.
Ground: `grass_green`, `grass_dry`, `meadow_mixed` (with clover and tiny flowers), `dirt_dry`, `mud_wet`, `sand_beach`, `gravel`,
`rock_grey_cliff`, `rock_limestone`, `snow_fresh`, `snow_trampled`, `forest_floor_needles`, `farmland_furrows`, `asphalt_worn`, `concrete_pavers`.
Buildings: `brick_red`, `brick_weathered`, `concrete_smooth`, `concrete_panel_soviet`, `plaster_cream`, `plaster_white_cracked`, `stone_ashlar_beige`,
`roof_tile_clay`, `roof_slate`, `roof_shingle_grey`, `corrugated_metal_grey`, `corrugated_metal_rust`, `steel_painted_dark`,
`wood_planks_weathered`, `glass_reflective_dark` (albedo near black, roughness very low).
Camouflage for vehicles (tileable, albedo only, 1024): `camo_woodland`, `camo_desert`, `camo_urban_grey`, `camo_arid_two_tone`, `camo_snow`.

### Tier 3: foliage and plant cards (alpha cut-outs)
Folder `native/godot/assets/art/foliage/`. Atlases of independent cards on a transparent background, each card well separated (at least 16 px of margin, with the edge colour bled into the transparent area so no dark halo shows).
Also a `_normal` (flat-ish, leaf-shaped relief) next to each atlas where it helps.
- `pine_branches_atlas_2048.png` : eight different spruce / pine branch clusters, each a flat fan of needles about 1 m wide.
- `birch_leaves_atlas_2048.png` : eight leafy twig clusters of birch and broadleaf trees, summer green plus autumn yellow plus bare winter twigs.
- `bush_leaves_atlas_2048.png` : dense shrub foliage patches, four greens.
- `grass_tufts_atlas_2048.png` : twelve grass tufts (tall green, short green, dry yellow, with seed heads), each about 40 cm wide.
- `wildflowers_atlas_2048.png` : daisy, buttercup, poppy, lavender clovers, six kinds, small.
- `reeds_atlas_1024.png` : reeds and bulrushes for shorelines.
- `tree_bark_albedo/normal` : pine bark and birch bark, tileable, 1024.
- `deposit_*` (resources): `deposit_iron_ore`, `deposit_gold_veins`, `deposit_coal_silicon`, `deposit_uranium_yellowcake`, `deposit_diamond_kimberlite` (tileable rock materials as in Tier 2, 1024, with albedo/normal/roughness, showing the ore in the rock) and `deposit_oil_seep` (dark wet ground with a sheen, tileable).

### Tier 4: far-distance impostors (only if Tiers 1 to 3 are done and good)
Folder `native/godot/assets/art/impostors/`. A "turntable" atlas of one object photographed from 16 evenly spaced
directions (every 22.5 degrees) at a 35 degree camera elevation, on transparent background, evenly lit (no cast shadow), with a matching `_normal`
atlas so the game can light it. 4 x 4 grid, each cell 512 x 512, name `<object>_impostor_16_4x4.png`.
Objects: `pine_tall`, `pine_young`, `birch_summer`, `birch_autumn`, `oak_summer`, `bush`, `farmhouse`, `apartment_block`, `factory_brick`, `town_hall`,
`main_battle_tank`, `armoured_personnel_carrier`, `infantry_squad` (a group of five soldiers, in loose formation), `helicopter`, `fighter_jet`, `transport_ship`, `destroyer`.
Make each object modern, believable and generic (not a specific national model with markings).

### Tier 5: soldier animation sheets (only after Tier 4)
Folder `native/godot/assets/art/units/`: for one generic modern infantry soldier in plain olive-drab kit: `soldier_walk_8dir.png`, `soldier_run_8dir.png`,
`soldier_fire_8dir.png`, `soldier_die_8dir.png`: 8 rows (the eight directions, every 45 degrees, from the front clockwise) by N columns (the frames of the
loop), each cell 256 x 256, transparent background, flat lighting, with a matching `_normal` sheet. Frame counts: walk 8, run 8, fire 6, die 10.

## When you finish a tier
1. Write or update `native/godot/assets/art/MANIFEST.json`, a list with one entry per file:
   `{"file": "...", "kind": "flipbook|material|foliage|impostor|sheet", "size": [w, h], "grid": [cols, rows] or null, "tileable": true|false, "frames": n or null, "notes": "how it was made"}`.
2. `git pull`, then commit **only** the new files under `native/godot/assets/art/` and the manifest, and push to `main`. Do not touch other files.
3. Add one line to `COORDINATION.md` ("Codex -> Claude: art tier N is in native/godot/assets/art/, see MANIFEST.json").
4. Tell the user which tier is ready, so they can tell Claude to wire it into the game.
