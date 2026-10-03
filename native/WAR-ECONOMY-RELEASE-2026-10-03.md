# Playable operational war economy build

Source commit: 41a194c (version metadata 0.9.52). Built from an isolated committed
snapshot, excluding Claude's ongoing 0.9.53 menu work.

Local release artifacts:
- dist/DOMINION-War-Economy.exe
- dist/DOMINION-War-Economy-Setup.exe
- dist/DOMINION-Setup.exe also updated after checking no concurrent replacement.

The running dist/DOMINION.exe was locked and was not interrupted. Close the old
game and launch the War-Economy executable, or use the new installer. The next
normal build from the shared branch includes the committed operating-cost system.

Verification:
- Isolated source snapshot: WAR_COSTS PASS (165 checks).
- Exported executable: UI_TEST PASS.
- Inno Setup: successful compile.
- Working-source regressions: economy 100, save audit 27, live weapons 89,
  modern warfare, battle dynamics, motion, air-sea and UI passed.

Research, cost table and modelling boundaries:
[WAR-ECONOMY-RESEARCH-2026-10-03.md](WAR-ECONOMY-RESEARCH-2026-10-03.md).

Binary artifacts remain local and ignored by Git; source, research and tests are
committed. The archived build snapshot is in dist/war-economy-build.
