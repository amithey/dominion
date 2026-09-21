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

## Next acceptance gates

1. Establish a seeded, repeatable 1080p benchmark on a named target machine.
   Record simulation, render submission, frame p95, calls and triangles separately.
   Profile shadows, infantry meshes and environment draw calls. Keep image quality
   fixed when comparing changes. Test dense groups as well as dispersed armies.
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
