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

## Tier 6: 3D houses and buildings as glTF files (after Tiers 1 to 3, or in parallel if you have the time)
There is no Blender on the user's machine, so build the models **with code**: a small Python script of your own (numpy, and the
`json` and `struct` modules, or `pip install trimesh` / `pygltflib` if you prefer) that writes binary glTF 2.0 (`.glb`). Keep the
generator script in `native/tools/models/` so the models can be rebuilt and changed (that folder is yours; it is not part of the game).
Build real architecture, not boxes: recessed windows with frames, sills and lintels, door with step and canopy, roof with
overhang and gutter, chimneys with caps, dormers, porches, balconies, cornices, plinth, downpipes, brick and stone detail that is geometry
where it matters (corners, quoins, window surrounds), the rest left to the texture.

**Conventions (the game depends on them):**
- Units are metres. Origin on the ground at the centre of the footprint. **+Y up, the front of the building faces +Z.**
- One mesh per building, with several primitives, **one per material, named by role**: `wall_brick`, `wall_plaster`, `wall_stone`, `wall_concrete`,
  `roof_tile`, `roof_slate`, `roof_metal`, `trim` (frames, cornices), `glass`, `wood`, `metal`. The game gives each name its PBR texture (from Tier 2),
  so **do not embed textures or colours**: give each primitive a plain white PBR material with that name, roughness 0.8, metallic 0.
- **UV coordinates in metres** (1.0 = one metre on the wall or roof), so a tileable texture keeps its real size on every surface. Smooth normals
  on round shapes, hard edges on corners. Triangle winding counter-clockwise seen from outside.
- Footprint: one building fits inside a regular hexagon of 12 m radius (a 10 x 10 m square at most, centred). Height as a real building has it.
- Two detail levels in one file as two top-level nodes: `LOD0` (up to about 6,000 triangles) and `LOD1` (up to 1,200 triangles, same silhouette, no small parts).
- Nothing baked: no lights, no cameras, no animation, no vertex colours (apart from `glass`, which may have a darker vertex colour toward its lower edge).

**Which buildings (three variants of each unless it says one):**
`cottage` (single storey, pitched roof, chimney), `townhouse` (two or three storeys, narrow, brick or plaster), `apartment_block` (five storeys, flat roof
with parapet and water tank, balconies), `farmhouse`, `barn` (large gambrel or gable, big doors), `grain_silo` (one), `town_hall` (portico with columns, clock or dome, steps),
`school`, `library`, `hospital` (a long block with a canopy and a helipad mark on the roof), `police_station`, `fire_station` (big doors), `bank` (stone, columns),
`office_tower` (glass and concrete, 12 storeys), `factory_brick` (saw-tooth roof, chimney stack), `warehouse` (corrugated metal), `power_station`
(boiler hall and a cooling tower), `water_tower` (one), `church` (nave, tower and spire), `mosque` (dome and one minaret), `railway_station`, `market_hall`,
`barracks` (long two-storey, plain), `command_bunker` (low, concrete, antennas), `radar_station`, `hangar` (large arched), `control_tower`, `harbour_crane` (one), `lighthouse` (one).
Make them plain, believable and generic: no flags, no national symbols, no signs with words.

**Files:** `native/godot/assets/art/buildings/<name>_<variant>.glb` (for example `cottage_1.glb`), and add each to `MANIFEST.json` with
`{"kind": "model", "triangles": [lod0, lod1], "footprint": [w, d], "height": h, "materials": [...]}`. Check every file by loading it back
(for example with trimesh) and confirm that it has no flipped faces, no loose pieces under the ground and no overlapping duplicate faces.

## Tier 7: vehicles, aircraft and ships as glTF models with named moving parts (start with one tank as a pilot)
Same method as Tier 6 (a code-built `.glb`, generator kept in `native/tools/models/`). **Build the tank first, alone, and tell the user**: Claude will wire it
into the game and judge it before you build the rest. The game moves units itself (it has no rigid-body physics for vehicles): Claude drives the position, heading, pitch and roll
over the terrain, the suspension bob, the turret turn, the gun elevation, the recoil, the track scroll, the wheel turn, the damage and the wreck. What
you give is **the shape and the named parts, with their pivots in the right place**, so that Claude can move them.

**Conventions:** metres, real size (a main battle tank is about 9.8 m long including the gun, 3.6 m wide, 2.4 m tall without the machine gun), origin on the ground
at the centre of the hull footprint, **+Y up, the front faces +Z**. Materials by role, plain white PBR, no embedded textures, UVs in metres (as Tier 6), with these names:
`paint` (the painted hull and turret: the game applies its own camouflage and the nation's colours), `metal_dark` (tracks, wheels, barrel, fittings),
`rubber` (road-wheel tyres, track pads), `glass` (periscopes, sights), `markings` (a flat panel on each side and the turret that the game paints with the nation's mark).
Two detail levels as two top-level nodes `LOD0` (up to about 15,000 triangles) and `LOD1` (up to 2,500).

**Named nodes (empties with the pivot at the point they turn about; the meshes are their children):**
- `Hull` (the root of the body), under it `Turret` (pivot on the turret ring, axis Y), under that `Gun` (pivot at the trunnion, axis X, so it can elevate -8 to +20 degrees), and a marker `Muzzle` at the end of the barrel pointing along +Z.
- `Wheel_L0`, `Wheel_L1`, ... and `Wheel_R0`, ... (road wheels: pivot at each axle, axis X), `Sprocket_L/R`, `Idler_L/R`, `Roller_L0..` (return rollers).
- `Track_L` and `Track_R`: one mesh each, with the **UV's U running along the track loop** from 0 to 1, so the game can scroll the track by changing the UV offset; put the track pads as real geometry.
- Optional: `Hatch_Commander` (pivot on its hinge), `Antenna_1` (a thin whip, pivot at the base), `Smoke_Launcher_L/R`, `Exhaust` (marker), `Engine_Deck` (marker for smoke when damaged).
- A separate mesh `Wreck` (hidden node at the top level): the same tank burnt out, turret blown off beside the hull, as a static model.
- Add a `collision` node: a simple box (`Collision_Box`) around the hull, for the game's own use.

**Then, only after the user has approved the tank:** the same for an armoured personnel carrier (`Hull`, `Turret`, `Gun`, `Muzzle`, `Wheel_L0..L3`, `Wheel_R0..R3`),
a self-propelled howitzer, a 6x6 truck, a rocket launcher truck, an air-defence launcher (`Hull`, `Launcher` that rises about X), then aircraft: `jet_fighter`
(`Fuselage`, `Gear_Nose`, `Gear_Left`, `Gear_Right` which retract about their hinge, `Flap_L/R`, `Rudder`, `Afterburner` marker, `Canopy`), `helicopter` (`Fuselage`, `Rotor_Main` axis Y,
`Rotor_Tail` axis X, `Skid` or wheels), `bomber`, `transport_plane`, then ships: `destroyer` (`Hull`, `Turret_Main` axis Y with a `Gun` at its trunnion, `Radar` axis Y,
`Wake_Bow` and `Wake_Stern` markers), `carrier` (with a flat deck and an island), `submarine` (hull, sail, `Propeller`), `landing_ship`.
Soldiers are **not** in this tier: they need a skeleton and animation, which has to be agreed separately.

**Files:** `native/godot/assets/art/vehicles/<name>.glb`, `aircraft/<name>.glb`, `ships/<name>.glb`, each with a MANIFEST.json entry
(`"kind": "model"`, triangles, size, the list of named nodes and the pivots' positions). Check each file by loading it back and printing the node tree with every pivot.

**Which vehicles, aircraft and ships exactly:** see `native/CODEX-UNIT-ROSTER.md` (and the same list as data in `native/CODEX-UNIT-ROSTER.json`): one model per real designation each nation fields,
in seven priorities (P1 main battle tanks, P2 armoured carriers, P3 artillery and rockets, P4 air defence, P5 helicopters, P6 aircraft, P7 ships), 522 models in all. The pilot tank comes first; the rest follow in that order, only after the user approves each priority.
