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

Remaining cost is mostly buildings: each has 20–40 meshes because of distinct
materials (palette clones, textured walls, glass, animated parts). Reducing that
needs a shared texture atlas, not more merging.

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
