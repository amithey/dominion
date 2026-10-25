# Scene detail visual pass — 2026-10-12

Applied to the shared tree, incremental AFTER customer-playtest final and all prior Codex FINAL packages. Do not apply twice. No combat, economy, national roster, navigation or save rules changed in this pass.

## Changes

- Architecture: two-tone window panes, crossbars, restrained glass reflections, paneled entry doors and brass handles. Reduced excessive relief on masonry/roof materials; baked lower-wall weathering grounds the buildings even on Low quality.
- Units: broad field-paint variation on painted armour, clean cool optical glass separated from rubber and metal, with road dust kept off the glass. Reuses existing noise reads; no additional texture samples or moving-part nodes.
- District trees: irregular canopies and darker undersides/lighter crowns. Same triangles and district prop material batch as before.
- Terrain: broad meadow palette variation and restrained strata on steep rock. No new textures.
- Coast: softer, broken foam instead of a solid white shore outline; keeps lakes calmer. Reuses the existing foam noise sample.
- Environment: slightly cooler sunlight and less ambient fill so lit faces and shaded faces separate more clearly. No new lights, shadow passes, SSAO requirements, particles or post-processing.

## Verification / evidence

`scene-detail-views.gd` captures city, facade, units, forest, coast and Low-quality city, plus High-quality facade. Unit detail captures intentionally hide forest batches temporarily to show the models; the forest/coast/city views show actual trees. Screenshots: `native/godot/build/scene-detail/`. Before/after cameras are fixed; animation/cloud phases vary, so these are visual comparisons, not deterministic performance A/B measurements.

Vulkan shader compilation and actual screenshots inspected. `report-polish-check.gd`: 70 checks passed. The full rendered performance benchmark was also rerun; see final results below. The prior heavy-battle performance limitation remains open; do not claim it is solved by this visual pass.

Full rendered benchmark: **10 passed, 2 failed**. Heavy battle rendered at **16 FPS (slowest 1% 7)** versus previous run's 15/5; both below the 25 FPS target, and not enough evidence for a performance improvement claim. Battle simulation 28.1 ms average / 65.6 ms p99, peacetime 4.5/39.1 ms, both inside existing budgets. Island startup 17.2 s exceeded 15 s; large map loaded in 32.1 s. No test thresholds changed. Logs: `build/scene-detail-performance-console.log`.

`scene-detail.patch` is isolated against captured baselines, and `sha256.json` fingerprints the changed files plus local preview. Official installer/dist publishing remains Claude's responsibility. Integrate after earlier FINAL packages, check the merged release, then publish and record receipt in COORDINATION.md.

Final validation: seven new captures completed across Balanced, Low and High; no script/parse/shader errors in final capture, import or export logs. Windows release export exited 0 and refreshed `build/regional-preview/DOMINION.exe`. Reverse patch dry-run passed. Eight source/test/UID files packaged; earlier work is excluded from the incremental patch.
