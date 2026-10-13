# Performance in big battles: where the time went (2026-10-13)

**The problem:** with 128 units fighting, the game ran at about 15 FPS on the integrated-graphics test machine (Intel Iris Xe, 1920×1055, Balanced quality). The goal is 25 FPS. Codex had measured that the **CPU, not the graphics**, was the limit: the GPU needed about 20 ms a frame, the CPU about 90.

## How it was measured

1. The built-in benchmark: `Godot --path native/godot -- --bench=128 --no-vsync --quit-after-bench`, with `--profile` to split the simulation into buckets.
2. **Switching systems off** to see what each costs. A temporary switch (not shipped) disabled the processing of one node or script at a time and re-ran the benchmark:
   - the whole HUD layer: +5 FPS (CPU −24 ms a frame);
   - unit badges, minimap, health bars, effects, logistics, territory, missiles: each measured alone.
3. **Timing each `_draw`** of the three overlays directly with `Time.get_ticks_usec()`.

## What was found, and fixed

| Cost | Before | After | Why |
|---|---|---|---|
| Minimap redraw (4 a second) | 14.8 ms | 2.7 ms | Every owned hex of territory was drawn as its own polygon, each recomputing six corners with `cos` and `sin` and being triangulated; and every unit was a tessellated circle (12 ms for 128 units). Now the territory is **one mesh with vertex colours, rebuilt only when ownership changes**, and units are small rectangles and bare triangles. |
| Unit role badges (about 10 a second) | 8.3 ms | 3.2 ms | 80 badges tested for overlap against every other (about 6,400 rectangle tests), measured their text on every call, used a rounded, bordered style box (tessellated every call) and `is_visible_in_tree()` per unit. Now: a **spatial grid** for overlap, cached text widths and shaped text lines, two plain rectangles per badge, `node.visible`, and cheap tests first. |
| Heavy-battle frame rate | 14.8 / 19.2 / 17.8 FPS (close-up, base, pan) | 19 / 21 / 22 FPS | About +25%. Draw calls fell from 2,083 to 1,745. |

## What is left

- **Simulation: about 17 ms a physics step**, of which unit movement is 13 ms (crowd pressure 3.3, ground placement 3.2, steering 1.5, driving 1.3). At 30 steps a second this is half a second of CPU a second, which is why the frame rate is still under 25.
- **The HUD itself:** switching it off still gains 1.3–2.5 FPS; it refreshes its resource strip and panels four times a second with theme overrides that notify on every call.
- **Draw calls:** about 1,700, from per-unit meshes. Merging same-type units into multimeshes would cut them, at a large cost in complexity.
- **Startup:** 17 s to the island against a 15 s budget (Codex's measure); not addressed here.

## Notes for next time

- Godot's `draw_circle`, `draw_colored_polygon` and `draw_style_box` **tessellate on every call**: in per-unit overlays use `draw_rect`, `draw_primitive`, a cached `ArrayMesh`, or `TextLine` objects.
- `Node.is_visible_in_tree()` walks every ancestor; test `node.visible` when the ancestors are known to be visible.
- `PackedInt32Array` has no `hash()` method; use the global `hash(array)`.
