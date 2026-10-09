# DOMINION — native PC strategy game

The active product is the downloadable Windows game built with Godot in `native/godot`. Steam is the intended distribution target. Continuing development, bug fixes, playtesting and releases refer to this native game by default.

## Play

On Windows, double-click `Start-Game.bat` or run `dist/DOMINION.exe`. Install or update the game with `dist/DOMINION-Setup.exe`. The main menu displays the installed version. Saves and settings are kept in `%APPDATA%/DOMINION`.

Press F1 for controls and F11 to switch between a window and full screen. Campaigns can continue after victory or defeat.

## Develop and validate

Read [native/README.md](native/README.md) and [native/HANDOFF.md](native/HANDOFF.md) for the engine, build requirements and implementation details.

- Native source: `native/godot`.
- Prepare assets: `native/prepare-desktop.ps1`.
- Native checks: `native/run-tests.ps1`; `-Exported` checks the built executable.
- Release build: `native/build-windows.ps1` builds the committed source and the installer.
- Current customer audit: [round 4 report](native/CUSTOMER-REVIEW-ROUND-4-2026-10-09.md) (earlier: [round 3](native/CUSTOMER-REVIEW-ROUND-3-2026-10-09.md), [round 2](native/CUSTOMER-REVIEW-ROUND-2-2026-10-08.md)).

The older browser implementation remains in the repository as historical reference and some asset/data inputs. It is outside the active product and release scope. Steam integration and upload are separate work; this repository does not claim a published Steam release.
