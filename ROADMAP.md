# DOMINION quality roadmap

The product direction is a readable military RTS with hex cities and vulnerable
supply routes. Local review precedes commits and pushes, following user approval.

## Desktop direction

The user selected an installed PC game with a future Steam target. A separate
Godot evaluation lives in `native/`; see `native/README.md` for launch and scope.
It demonstrates imported assets, animated infantry, camera controls and navigation
around districts. Full migration remains subject to visual and performance review.
The browser game remains available while this evaluation proceeds.

## First local milestone: army control and performance foundations

- Spatial broad-phase for target acquisition and unit separation, updated after
  each moving unit and upon recruitment. Exact combat rules remain in place.
- Control groups, selection merging and double-tap camera focus.
- Batch static vehicle pieces while preserving wheels, limbs, bones and turrets.
- Review controls below the battlefield; at most three routine notifications.
- Army drill creates up to 64 extra units and exercises formation movement.
- 35 automated tests pass. Synthetic distributed-army proximity checks inspect
  4,761 candidates instead of 2,560,000. This is not an FPS measurement.

Live review exposed a remaining major rendering bottleneck: about 4,500 draw
calls with 88 units, and single-digit FPS in sampled windows. The map and camera
were not controlled identically across reloads, so these are diagnostic samples,
not a before/after performance comparison. No stable 60 FPS claim is warranted.

Character batching (2026-09-21) addressed the largest share. Each infantry figure
was ~15 part meshes, each drawn again for shadows. They now merge into one skinned
mesh with vertex colours; rigid parts are skinned to their bone. Measured as the
difference between frames with and without units (camera fixed, army drill, 88 units):
units cost 3,954 draw calls before and 128 after; the full frame fell from ~4,600
to ~550. `?nocharbatch` restores the old path for A/B checks.

Repeatable benchmark (2026-09-21): `?bench=N` seeds Math.random, so the map and
army are identical between runs, and records three fixed camera phases (see README).
Draw-call breakdown on seed 1, 64 drill units selected, every pass forced
(main + shadow + water reflection), same camera, old vs new code:

| | before | after |
|---|---|---|
| Whole frame | 2,225 | 1,396 |
| Units, all passes | 1,557 | 726 |
| Water reflection pass | 852 | 274 |
| Shadow pass | 537 | 537 |

Selection rings and health bars now draw as three InstancedMeshes for every
entity. Land units and those overlays sit on layer 1, which the reflection camera
skips (ships and aircraft are still reflected). Clicks within 18 px of a unit
select it, which also makes small infantry easier to pick.

Building batching (2026-09-21). Two layers:
1. `batchBuildingGeometry` puts opaque standard materials that differ only in
   colour onto shared materials, with colour in the vertices and roughness and
   metalness rounded to quarter steps. Texture maps are part of the key, so
   per-building clones of the same model share one material. A district's `core`
   no longer counts as animated (only its registered radar/beacon/etc. do).
2. `building-batch.js` moves the static parts of every finished building into
   one `BatchedMesh` per material and hides the originals, which stay in place
   for picking. Destroyed buildings leave the batch in the same frame; sites
   under construction join when finished. `?nobuildbatch` disables it for A/B.

Seed 1, same camera and every pass forced: the close-up frame went from 1,396 to
1,116 draw calls (buildings 396 → 202). With 30 extra buildings (39 in total) in
a wide view, it went from 3,141 separately to 1,845 batched, with the same triangle
count (7.42M). Close-ups show no visible material change. Cinematic (AO) works.

Remaining: 45 material batches for the whole map, windows (InstancedMesh per
building), glass (MeshPhysical) and the per-building hex outline lines.

## Engine comparison, first real numbers (2026-09-21)

Same laptop (Intel Iris Xe), 1080p window, both benchmarks with the same three
phases. The browser ran in a separate visible Edge window (`&report=` posts the
JSON to a local collector); Godot ran windowed with V-Sync off.

| Frame rate (close-up / overview / pan) | 64 extra units | 128 extra units |
|---|---|---|
| Browser, full seeded map (88 / 152 units in total) | 25 / 22 / 19 | 23 / 19 / 18 |
| Godot Forward+, 3 districts only | 59 / 69 / 67 | 38 / 44 / 46 |
| Godot Compatibility, 3 districts only | 41 / 48 / 54 | 21 / 25 / 32 |

- The Godot scene is much lighter, so absolute FPS is not comparable. Cost per
  extra 64 units in the close-up is: browser +4.4 ms, Godot Forward+ +9.7 ms,
  Godot Compatibility +22.6 ms. Godot's soldiers are still ~15 separate meshes.
- The browser is CPU-bound in `renderer.render()` (30–50 ms of a 40–55 ms frame;
  simulation ≈ 2–4 ms). A 35% smaller window did not change FPS, so it is not
  fill-rate bound. Early `&probe` readings: shadow pass ≈ 12 ms, units ≈ 12 ms.
- This laptop throttles under sustained load: the same measurement drifted from
  49 ms to 92 ms within about a minute. Comparisons must alternate engines in
  short runs, or use a desktop machine.

Fair next step: build the same scene in both engines, starting with an exported
seeded map (terrain heights, trees, building placements) that Godot loads.

### Same map in both engines (2026-09-21)

`js/map-export.js` exports seed 1 (height grid, trees, buildings, units); the Godot
world scene loads it with Forward+ terrain and sea shaders, SSAO, fog and shadows.
Same laptop, 1920×1080, same drill (82 units), V-Sync off:

| | FPS close-up / overview / pan | Bottleneck |
|---|---|---|
| Browser, three.js | 25 / 22 / 19, p95 55–65 ms | CPU: 30–50 ms in `renderer.render()` |
| Godot, balanced (FSR 77%) | 28 / 25 / 27, p95 37–44 ms | GPU: 34–39 ms; render CPU 10–15 ms |

Godot draws a richer image (refraction, depth-coloured sea, PBR terrain) at a
higher and steadier frame rate, and it is limited by the GPU, which a dedicated
card relieves; the browser is limited by CPU work that a faster GPU does not
reduce. The first Godot version ran at 7 FPS: per-pixel hash noise in the terrain
shader cost ~110 ms; noise now comes from a texture and weights are per vertex.

Recommendation: continue the migration in Godot. Port gameplay systems in order
of dependency (units and combat, then economy and logistics, then AI and diplomacy),
keep the browser build as the reference until each system reaches parity, and
replace the stylised units with a consistent realistic asset set.

## Next acceptance gates

1. Run the benchmark on the named target machine at 1080p with the window
   visible (the Claude browser pane throttles, so its FPS is invalid). Record
   24/64/128-unit runs as the baseline for the engine decision. Next render
   work: building material atlas, then shadow-pass culling of small props.
2. Validate formation arrival through narrow passages and around a growing city;
   eliminate persistent jams and expose order feedback and rally points.
3. Build one cohesive art reference scene: terrain, one district, infantry,
   armor, aircraft and a ship. Match scale, materials and lighting at gameplay zoom.
4. Polish a small combat roster with firing/recoil/impact feedback, positional
   audio and clear counters. Add construction and damage states to key buildings.
5. Create a 15–20 minute match on one authored map with two distinct factions,
   meaningful supply disruption, understandable AI behavior and a short tutorial.
6. Validate saving/loading, settings, stability and repeated external playtests
   before expanding maps, factions or considering multiplayer and distribution.
