# VISUAL FINISH — Codex → Claude — 2026-10-12

Source changes are **already applied** in the shared working tree. Do not apply the patch twice. This handoff is the user's requested visual pass after the arsenal research expansion. It covers the native Godot game; browser files and official `dist`/installer are outside this change.

`visual-finish.patch` is built against snapshots taken **after the completed arsenal work**, before the visual pass. Integrate the arsenal handoff first. In particular, `side_panels.gd` and `world.gd` also contain arsenal work in the checkout: the visual patch contains only the visual delta. Preserve your 0.9.92 strategic AI changes.

The user-facing coverage matrix is `native/VISUAL-FINISH-2026-10-12.md`. Shared styles cover the existing menus, campaign/settings, cabinet, research, diplomacy, economy, intelligence, defence/AI/arsenal/nuclear, territory, UN, help, log and tooltips. Specific changes also address production portrait stages, research cards, charts, notifications, unit/health markers, minimap symbols, building/vehicle finishes and terrain/water lighting. No balance, save schema or research progression changes.

## Verification

- `menus-check.gd`: 52 checks passed.
- `readability-check.gd`: PASS, including production text, displayed prices, targeting vs production, storage-full gating, 80% scale and full resource strip.
- `research-100.gd`: 101 checks passed.
- `report-polish-check.gd`: 70 checks passed, including selection and role/construction markers.
- `arsenal-check.gd`: 332 checks passed.
- `performance-check.gd`: 10 checks passed. Island load 6.3 s; Pangaea/nine nations 17.1 s and 400 MB; battle simulation with 234 units averaged 24.3 ms per step (48.2 ms at p99). These are headless simulation timings, not GPU frame-rate claims.
- `visual-finish-views.gd`: 68 checks passed; 21 screenshots covering 1280×800 / 100% and a 1600×900 market view. Includes damaged armour selection, unfinished construction, missile production, all ministry landing pages, AI/arsenal/nuclear tabs, cabinet, log, research, campaign and settings. Final log contains no SCRIPT ERROR or shader compilation error. Representative captures were visually inspected.
- Additional default Vulkan/Forward+ smoke: PASS, including a visually inspected battlefield capture (`11-forward-battlefield.png`). This brings the final gallery to 22 images. The harness explicitly initializes the menu for this command-line test, since world.gd skips interactive menu setup when test flags are present.
- Windows preview export: exit 0. Official distribution unchanged. Patch reverse dry-run: PASS (`git apply --reverse --check --ignore-space-change native/review/codex-visual-handoff/visual-finish.patch`).

Full logs are `build/visual-*-console.log`; screenshots are `native/godot/build/visual-finish/`. OpenGL compatibility captures emit the existing unsupported FSR/screen-space-AA warnings and the environment's unavailable user shader-cache warning. These do not prevent rendering. Some headless tools report pre-existing ObjectDB/resource cleanup warnings at exit. GPU frame rate is not measured by the screenshot check.

## Reproduce

From the repository root in PowerShell, use `.local-tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path native/godot --script res://tools/menus-check.gd`, substituting the other headless checks above as required.

For the screenshot check, replace `--headless` with `--rendering-method gl_compatibility --rendering-driver opengl3` and use `res://tools/visual-finish-views.gd`.

For the default Vulkan renderer smoke, omit those renderer overrides and append `-- --visual-forward-smoke`.

`package.py` generates the visual-only patch and SHA-256 fingerprints from `baseline/`. Keep the baseline intact. The preview is `build/regional-preview/DOMINION.exe`, launched by `Start-Regional-Preview.bat`.

Please integrate the already-applied source with the arsenal work, run merged/exported checks, rebuild the official distribution, and record receipt/publication in `COORDINATION.md`. Codex has not published this build.
