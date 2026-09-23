# Handoff: versions 0.9.4 and 0.9.5 (2026-09-23, Claude)

This note is for whoever continues the Godot game (`native/godot`). The player-facing
description of each change is in `native/README.md` (sections "Version 0.9.5" and
"Version 0.9.4"). This file covers where the code is, how it fits together, and
the traps found along the way.

## Commits, oldest first

| Commit | What |
|---|---|
| `8e8a705` | Ground momentum, pivot turns, slopes, sprung vehicle hulls (`motion.gd`) |
| `6ccc7f9` | Ballistic debris pool, shell gravity arc, shock rings, tossed turrets (`debris.gd`, `effects.gd`) |
| `3c1ce40` | AgX colour grading, greens, foliage; round portrait medallion and stat plaques; health bars that step apart |
| `e61681c` | Version 0.9.4, README |
| `e3cc593` | Battle behaviour (`tactics.gd`), formations, blast shove, minimap turned with the camera, 10 Hz decisions, version 0.9.5 |

## New files

- `scripts/motion.gd`: static functions, no state of its own.
  - `drive()` moves a ground unit one step: acceleration, braking, turn rate, slope, formation pace.
    It writes `cur_speed`, `accel` and `yaw_rate` into the unit.
  - `body_basis()` runs the suspension spring. It uses `sus_pitch`/`sus_roll` and their `_v` velocities.
  - `halt()`, `recoil()`, `shove()` (blast impulse) and `knock_step()`.
- `scripts/tactics.gd`: static functions.
  - `firing_spot()` picks where a unit stands to shoot. Each unit keeps its own bearing offset, plus a `bearing` shift after a jam.
  - `pick_target()` scores candidate targets. `keep_target()` drops a target that is dead, no longer hostile, unreachable or stuck in a chase, and sometimes retargets.
  - `formation()` places ranks: armour, then infantry, then `SUPPORT`.
  - `crowd_push()`, `sidestep()` and `unjam()`.
- `scripts/debris.gd`: one `MultiMeshInstance3D`, a pool of 360 pieces, simulated on the CPU. It is created by `effects.gd` as `effects.debris`, and `world` is set in `world._ready`.
- `scripts/medallion.gd`: the round portrait in the selection card. It clips its children with `clip_children`.
- `scripts/motion_regression.gd` (`--motion-test`) and `scripts/battle_regression.gd` (`--battle-test`, and `--capture-tactics` for screenshots).

## Changes to existing files

- `world.gd` ground movement loop, in `_physics_process`:
  - A chasing unit goes to `unit.spot` (its firing spot) instead of the enemy's position.
  - Holding uses hysteresis: hold at 0.99 × range, chase again past 1.03 × range. A unit can fire out to 1.03 × range.
  - Stall arrival: see the `best_rem`, `stall` and `stuck` fields.
  - Standing units call `spread_out()`, which uses the walk-grid lookup `open_ground()`, not `walkable()`.
- `world.gd` combat:
  - `update_combat` uses `Tactics.keep_target`/`pick_target`. The search radius is `max(aggro, range)`.
  - Return fire in `damage()` only targets an attacker the unit can hurt and reach.
  - `order_attack` sets `forced` (no retargeting). `order_move` uses `Tactics.formation` and sets `pace`.
  - Accuracy depends on range and whether the target is moving (`_fire_gun`). `blast()` and `shell_hit()` call `Motion.shove`.
  - `shots_fired` and `unit.last_fire` exist for the tests.
- `minimap.gd`: `view_transform()` rotates the drawing by `cam_yaw` and scales it by `_fit`. `camera_outline()` still returns un-rotated map coordinates (the polish test relies on that). Clicks go through the inverse transform.
- `hud.gd`: the medallion, the ATTACK/RANGE/SPEED/HEALTH plaques, `YEAR n` in the era cartouche (a minute per year), and the notice lane.
- `health_overlay.gd`: bars step up so they do not overlap, and carry an owner-colour tab.
- Shaders: `foliage` (per-tree shade, AO, alpha antialiasing), `terrain` (deeper grass tint), `grass` (colours).
- `world.build_environment`: AgX tonemapping, fog, saturation and contrast.
- `run-tests.ps1`: now also runs `movement physics` and `battle dynamics`.

## Traps (please keep these in mind)

1. **Never use a unit Dictionary as a Dictionary key, and never compare units by value**
   (`in`, `has`, `==`). Units point at each other through `enemy` and `chase_of`, so hashing
   or deep comparison recurses until it hits "Max recursion reached". Use
   `unit.node.get_instance_id()` as the key and `is_same(a, b)` to compare.
2. **Staggered work uses `world.sim_tick`, not `Engine.get_physics_frames()`.** Tests step
   `_physics_process` by hand, and the engine's counter does not advance during those steps.
   That is how a bug hid in which 5 of 6 units never "thought". `thinks(unit)` runs every
   `THINK_EVERY` (6) ticks per unit.
3. **Aircraft are exempt from the chase time limit.** They make passes by design; without the
   exemption the bomber never drops its bombs, which the combat test catches.
4. **`walkable()` is expensive** (it loops over every building). Anything that runs per frame
   should use `open_ground()`.
5. **Physics interpolation at 30 Hz was tried and reverted.** It barely helped on the Iris Xe
   laptop, and effects are created and then moved within one tick (glitch risk). If you try it
   again, call `reset_physics_interpolation()` after every placement and take the camera out of
   interpolation.
6. Packed arrays are values: `for arr in [a, b]: arr.resize()` changes nothing. See the comment
   in `debris.gd`.
7. `python` on this machine reads files as cp1252 by default. Open with `encoding='utf-8'`.

## How to check

```
powershell -ExecutionPolicy Bypass -File native\run-tests.ps1          # 22 suites, about 6 min
powershell -ExecutionPolicy Bypass -File native\run-tests.ps1 -Quick   # without the AI war and the long match
.local-tools\godot\Godot_v4.7.2-stable_win64_console.exe --path native\godot -- --capture-tactics   # build\tactics-*.png, build\minimap-*.png
.local-tools\godot\Godot_v4.7.2-stable_win64_console.exe --path native\godot -- --battle-bench=48 --profile   # frame times and CPU by system
```

State at handoff: all 22 suites pass. The AI war depends on random timing and failed once in
about 8 runs. The battle test passed 10 of 10 after the final fixes. The installer is
`dist\DOMINION-Setup-0.9.5.exe` (local only, not in git).

## Open for the next stage

- Performance: in a 48-a-side battle this laptop manages about 22 fps. The simulation takes
  about 7 ms per step (60 Hz); the rest is rendering (about 1,200–1,400 draw calls). The next
  candidates are LOD or impostors for trees, and fewer shadow-casting objects in battle.
- Infantry cannot hurt tanks, by design (`effectiveness`). Soldiers facing only armour stand
  idle. Consider having them fall back or take cover.
- The browser version (`js/`) did not receive any of these changes.

## Added in 0.9.6 (Claude)

- `tactics.gd`:
  - `look_ahead()`: pure pursuit.
  - `traffic()`: follow, or steer round. The lane is measured along the route, and anything past the
    unit's own mark is ignored.
  - `hard_push()`: vehicles are only ever separated on real overlap.
- `world.gd`:
  - `straighten()` and `clear_line()` post-process every navigation route.
  - Stall rule: waiting in a queue is not being stuck, and a unit only gives up near its mark.
- `motion.gd`: `STEER_GAIN` (proportional steering) and `traffic_cap`.
- `passage.gd`: `check_order()` wraps every player move order in `world._unhandled_input`, and
  `watch()` runs once a second. Tests drive the letters through `passage.answer(label)`, which is
  independent of the hud layout.
- `occupation.gd`: zones. `territory.tick` multiplies unit weight by `occupation.weight(u)` and skips
  non-hostile units standing in foreign cells.
- `deposit_art.gd`: land sites are meshed per site (`_conform`); water sites share one mesh per type.
  Vertex-coloured materials must set `vertex_color_is_srgb = true`, or the colours wash out.
- New tests: `--convoy-test`, `--border-test`; captures: `--capture-deposits`.

## Added in 0.9.7 (Claude)

- `territory.gd` is hex-based:
  - Grid functions: `axial(i)`, `index_of(q, r)`, `hex_at(pos)`, `neighbours(i)`, `cell_polygon(i)`.
  - Storage: by row (`r + r0`) and offset column (`q + (r - (r & 1)) / 2 + c0`); the texture uses the
    same layout.
  - The terrain shader works out the hex per pixel (`hex_round`, `hex_owner`) and draws borders
    along hex edges whenever `show_borders` is on (always).
  - `area_scale` keeps land yields where they were with 40 m squares.
- `site_clearing.gd`:
  - `conflicts()` / `ask()` / `fell()` / `destroy()`.
  - `world.tree_parts` maps each tree (x, z) to its MultiMesh instances; felling scales them to zero.
  - `world.confirm_placement` now calls `build_site(key, at)` (paying and laying out), possibly after
    the letter.
- `build-windows.ps1` exports a clean `git archive` of HEAD under %TEMP%, with `.local-tools` joined
  in, and copies both files to `dist/`. Use `-Working` to build the folder as it is.

## Added after 0.9.7 (Claude): picking units

- `picking.gd`: a click hits a unit anywhere on the screen outline of its mesh box (measured once and
  cached as `unit.pick_box`, leaving out the selection ring), within 8 px, with an 18 px minimum
  around the centre for small units. Overlaps go to the nearest centre. A drag box uses the box centre.
  `--pick-test` checks the middle, ends and sides of a submarine, destroyer, tank, soldier, jet and
  helicopter. By the old 24 px centre rule, the ends of every large unit were unclickable.
- `--battle-test` failed once in about 13 runs (a rare random case); it passed the other 12.
