# Playable operational war economy build

## Main release verified after the game was closed

The current main release is now 0.9.53, built after Claude committed the situation
room UI in 4bc8ca1, which includes the operating-cost commit 41a194c.
Use dist/DOMINION.exe or dist/DOMINION-Setup.exe. The newer release was preserved;
the older isolated 0.9.52 build was not copied over it.

Verification on 2026-10-03: main exported executable UI_TEST PASS; current shared
source WAR_COSTS PASS (165 checks). Godot still reports the Windows certificate
store warning and test-exit resource cleanup diagnostics.

SHA256:
- DOMINION.exe: 21217A9695C8CADD13A5E18A5D452216F1E89124396BEFB9800B5775ED1653C1
- DOMINION-Setup.exe: 91828626D1FA7892EFFB835B4EA37F9126A7204004F5A5C055772995311127FD

## Earlier isolated build

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
