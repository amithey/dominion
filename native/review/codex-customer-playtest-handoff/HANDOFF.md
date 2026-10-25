# Customer playtest — 2026-10-12

Current source is already changed. This package is incremental **after** Codex visual finish, resource use, UN sessions and action copy, on Claude's 0.9.96 source. Those four packages are FINAL, not WIP. Do not apply an already-present patch twice. Official publication and installer remain Claude's responsibility.

## Reproduced and fixed

- Boarding a helicopter survived a later move or attack order. A soldier could disappear into a helicopter it merely passed after cancellation. Replacement move/attack/bombard orders now clear pending boarding; the boarding system explicitly restores its own continuing orders.
- A parked helicopter skipped the water check and could unload soldiers into water. Every state now checks terrain. Unloading searches nearby walkable ground outside buildings and cliffs, separates passengers, and retains any passenger that cannot be placed. Cargo is not silently discarded on failed placement. Replaced deep unit dictionary comparison with identity comparison.
- The persistent UN invitation covered Defence tabs and briefing. It yields while using ministry, research, cabinet, construction or modal windows; the UN badge retains the pending count and the invitation returns afterwards. No vote is cast or message dismissed by this behavior.
- The command dock ran beyond the right edge at ordinary UI scale on smaller displays. Below 1400 logical pixels it keeps full action names, removes redundant icons and fixed minimum widths, and restores the full presentation on larger viewports.
- Heavy battles saturated the 60 Hz simulation and starved rendering. An in-process diagnostic measured 5 FPS initially, 16 FPS at 30 Hz, 24.2 FPS at 15 Hz and 27.3 FPS with simulation paused. The chosen conservative setting is 30 Hz with physics interpolation, a non-interpolated frame-driven camera, and spawn interpolation resets. This improves responsiveness but does **not** claim the 25 FPS heavy-battle target is met. Do not weaken test thresholds.

## Actual validation

- Two complete 12-minute simulated campaigns, before and after changes: construction, production, research, road-linked village, resources, orders and rival growth passed. First run rivals reached 24/26/25 buildings and four discoveries completed. These tests fund the economy; they are not difficulty/balance validation.
- Hard-AI war test: rival armies reached the player's base, expanded settlements/roads, and destroying rival capitals produced victory.
- Real Vulkan window: 17 initial screen captures inspected through the existing UI audit. Its 152 raw findings include scroll-content false positives, not 152 confirmed bugs.
- New regression suites: airlift 10 checks; keyboard/window/animation 66 checks over 1024×720, 1280×800 and 1920×1080. Live helicopter travel, rotor rotation and infantry animation state verified. Screenshots are in `native/godot/build/customer-*.png`.
- War tools 157, robots 20, living-world effects 21, gameplay/save state 27, UN conference 42, action copy 102 checks passed. Together with the two new suites: 445 checks. Combat regression also passed after the 30 Hz change.
- Performance was explicitly tested headless and windowed. Initial windowed heavy battle: 7 FPS (slowest 1%: 3), against a 25 FPS budget. Some runs also exceeded startup or simulation tail-latency budgets. Logs retain failures; performance is not blanket PASS.
- Final full windowed benchmark at 30 Hz: **15 FPS, slowest 1% 5 FPS**, improved from 7/3 but below 25. Simulation battle averaged 33.0 ms (99th percentile 86.3), passing its 45/130 budget; peacetime tail latency was 46.9 ms against 40. Overall 10 checks passed and two failed. Island loaded in 14.5 seconds and Pangaea in 38.2, within their budgets. Static grass interpolation was subsequently disabled to remove warnings when construction instantly clears grass; no simulation rates or benchmark limits were changed afterwards.
- Camera motion remains frame-driven; tactical retarget decisions now occur at 5 Hz (six ticks at 30 Hz). Combat regression, live movement/window checks, a second 12-minute campaign and save/restore were checked after the rate change. Review this tradeoff when integrating.

## Evidence and release

Logs: `build/customer-*-console.log`, `build/customer-airlift-before.log` (five failing assertions before fixes), `build/customer-airlift-after.log` (10 passing), and `build/customer-life.log`.

`customer-playtest.patch` contains only this work relative to per-file snapshots; `sha256.json` fingerprints included files and the local preview. Two new regression suites are registered in `native/run-tests.ps1`. Diagnostic scripts under `native/godot/build` are excluded from exports.

Local Windows release export completed with exit 0. `build/regional-preview/DOMINION.exe` was refreshed; its exported `--headless -- --combat-regression` process completed with exit 0. The release executable did not emit the requested console/log file, so exported verification rests on its process exit status; the source regression log contains the explicit PASS marker. Patch reverse dry-run passed. Package: ten source/config/test files plus preview fingerprint.

Claude: integrate the earlier FINAL packages in order, then this one, preserve unrelated work, verify the merged/exported build and record receipt/publication in `COORDINATION.md`. Heavy-battle rendering remains an explicit performance issue for release review. No official release is claimed here.
