# DOMINION — native PC strategy game

[![Tests](https://github.com/amithey/dominion/actions/workflows/tests.yml/badge.svg)](https://github.com/amithey/dominion/actions/workflows/tests.yml)

DOMINION is a real-time strategy game of nations for Windows: cities, supply, research, diplomacy, espionage and war.
It is built with Godot 4.7 in `native/godot`. Steam is the intended distribution target; this repository does not claim a
published Steam release.

**Current version: 1.0.9 ALPHA.** Playable start to finish, but little tested: expect rough edges.

## Play

Download `DOMINION-Setup.exe` from the [latest release](https://github.com/amithey/dominion/releases) and run it.
Windows may warn about an unrecognised publisher, because the installer is not code-signed yet. Releases are alpha
pre-releases on GitHub, and the download link on the portfolio points at the latest one.

The main menu shows the installed version. Saves and settings are kept in `%APPDATA%\DOMINION`; saves from earlier
versions load. Press F1 for controls and F11 to switch between a window and full screen. Campaigns can continue after
victory or defeat. If something goes wrong, use **Report a problem** (About, Esc menu or F1).

From a source checkout on Windows, double-click `Start-Game.bat`, or run `dist/DOMINION.exe` after a release build.

## What is new in 1.0.9 ALPHA

- **Gameplay fixes from an audit (Nov 18–25):** loading a save no longer carries state over from the match before it; a
  renamed unit keeps its name; a defeated nation can no longer act; combat stops after peace is signed; transport seats
  are counted correctly; combat cover, submarine targeting and stealth, Golden Dome, airlift fuel and carrier flight
  physics are fixed.
- **Faster large battles:** target search looks only at enemy sides, fog of war is cached per tick and crowd separation
  does less work per unit (about 15% faster steps in a 234-unit battle).
- **Movement:** tanks no longer creep or circle near crowded marks; a parked vehicle steps sideways out of a passing
  friend's lane instead of being pushed ahead of it.
- **Testing:** the quick test suite runs automatically on GitHub for every push and pull request, and five false test
  failures were fixed.

Earlier versions are described in [native/README.md](native/README.md) and on the
[releases page](https://github.com/amithey/dominion/releases).

## Develop and validate

Read [native/README.md](native/README.md) and [native/HANDOFF.md](native/HANDOFF.md) for the engine, build requirements
and implementation details.

- Native source: `native/godot`.
- Prepare assets: `native/prepare-desktop.ps1` copies the CC0 art from `assets/` into the Godot project.
- Checks: `native/run-tests.ps1` (Windows, PowerShell); `-Quick` runs the quick suite, `-Exported` checks the built executable.
- Continuous integration: [.github/workflows/tests.yml](.github/workflows/tests.yml) runs `run-tests.ps1 -Quick` with
  headless Godot on six parallel Windows machines for every push to `main` and every pull request.
- Release build: `native/build-windows.ps1` builds the committed source and the installer; `native/verify-release.ps1`
  checks the result. Each release bumps the version in `native/godot/project.godot`, `native/godot/export_presets.cfg`
  and `native/godot/tools/alpha-check.gd`.
- Latest audit: [FIXES-AUDIT-2026-11-18.md](native/FIXES-AUDIT-2026-11-18.md) (earlier: [customer review round 5](native/CUSTOMER-REVIEW-ROUND-5-2026-10-30.md),
  [1.0 alpha report](native/ALPHA-1.0-REPORT.md)).

The game began as a browser prototype; that version is retired and no longer in the repository (it is in the git
history up to the commit that removed it).

## Licence

DOMINION is proprietary: copyright (c) 2026 Amit Heymans, all rights reserved (see [LICENSE](LICENSE)). The source is
public for reference; copying, modifying or redistributing it needs written permission. Official builds may be
installed and played for personal use. Versions released before 26 November 2026 (up to 1.0.8 ALPHA) were under
the MIT License, which still applies to those versions.

Third-party work keeps its own licence. The Godot Engine is MIT-licensed. The art in `assets/` (Kenney, Quaternius,
ambientCG, Poly Haven) is CC0 / public domain, with the details in [assets/models/EXTERNAL_ASSETS.md](assets/models/EXTERNAL_ASSETS.md)
and the licence files beside each pack. The Cinzel and Fira Sans fonts are under the SIL Open Font License 1.1
(`native/godot/ui/fonts`). The installer ships [THIRD-PARTY-NOTICES.txt](native/installer/THIRD-PARTY-NOTICES.txt).
Everything else (vehicles, ships, aircraft, effects, sounds, portraits and the interface) is original to DOMINION, made
in code, in Blender or with image generation.
