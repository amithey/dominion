# Codex → Claude: arsenal diversity, 12 October 2026

The human user requested deeper weapon diversity research for **every playable country**, implementation in the game, and delivery of the finished changes to Claude for the official update.

## Result

- **28 dossiers**, six domains each: land, air, maritime, fires / air defence, sustainment, evidence limits. **39 source records** with dated evidence and explicit exclusions. The full research document is `native/ARSENAL-DIVERSITY-RESEARCH-2026-10-12.md`.
- **3 functional roles / 20 country-role choices**: five recoilless teams, nine wheeled howitzers, six short-range air-defence systems. These complement the previous roster (159 total operator-role choices in force_catalog).
- New `Defence → Arsenal` country/category browser, source links, current game roster for comparison and production-facility navigation for the player's available roles. Existing game entries are explicitly distinguished from newly researched evidence.
- Actual production and research gates, rival AI pool and facilities, projectile dispatch, target restrictions, indirect bombard, movement tradeoffs, infantry / vehicle classification, native models and portraits, save/load compatibility.

All code is **already applied** in the shared working tree. **Do not apply the patch again.** The isolated patch is for review or transfer to another checkout. Source and preview hashes are in `sha256.json`; whole-file hashes of shared files also include concurrent work. Reverse dry-run validation passed with `git apply --reverse --check --ignore-space-change arsenal-diversity.patch`; the whitespace option accommodates this Windows checkout's CRLF files.

## Ownership and integration

New: `arsenal_diversity_data.gd`, `arsenal_diversity_panel.gd`, `tools/arsenal-diversity-check.gd`, `tools/arsenal-diversity-views.gd`, the research report and reproducible `build_report.py`.

Extended: `force_catalog.gd`, `force_models.gd`, `regional_factions.gd` (one positive-evidence roster exception), `side_panels.gd` (Arsenal tab and two UI state variables), `tools/force-roster-check.gd` (names accessor and updated count). `world.gd` has **four narrow arsenal hooks only**: infantry list, vehicle list, SAM bombard exclusion and weapon dispatch. `native/run-tests.ps1` has one new suite entry.

Preserve your AI/strategic work and the prior Codex UI handoff. This patch excludes those changes, browser work, project/version changes, unrelated tools, generated imports and the official release/installer. No commit, push or official publication performed by this handoff.

## Validation

- `ARSENAL_DIVERSITY`: **293/293** — every country and six category views, positive evidence/operator gates, real queues, research, foreign weapon refusal, firing and damage, target restrictions, spotting, JSON round trip.
- `FORCE_ROSTER`: **674/674** — 159 operator-role choices, all roles/models/AI registration, existing aircraft servicing and naval gates, save/load.
- `ARSENAL_CHECK`: **332/332**.
- `REGIONAL_FACTIONS`: **104/104**.
- `REGIONAL_ENTITIES`: **66/66**.
- `MENUS`: **52/52**.
- `ARSENAL_DIVERSITY_VIEWS PASS`: inspected at 1280×800 / 100%; Japan, Ethiopia, Sudan, USA dossier screens and all three native portraits. Final models use an elevated gun and visible missile pods. Screenshots: `native/godot/build/arsenal-*.png` (ignored build artifacts).
- `git diff --check`: no whitespace errors (working-tree CRLF notices only).

Local preview: `build/regional-preview/DOMINION.exe`; launcher `Start-Regional-Preview.bat`. Final Windows Desktop export completed with **exit code 0**. Official release should run merged / packaged checks and be rebuilt by Claude.

## Research and gameplay limits

These are representative operator examples, not fleet counts or readiness estimates. SH-15 attribution for Ethiopia/Pakistan is labelled reported; Russian deliveries are labelled supplier statements. Ancient reports remain dated. Orders and prototypes do not grant production. Booker cancellation, Redback trials, Egyptian K9 schedule, RSF-specific weapons and alleged South Sudan purchase plans are explicitly excluded as new operational grants.

Country dossiers cover all 28 identities; countries lacking positive evidence get a dossier rather than an invented new unit. Existing game arsenals are not all re-certified by this research. Short-range SAMs fight aircraft/UAV **units only** and do not intercept strategic missile events. Numerical stats and role silhouettes are game abstractions. Recoilless ammunition selection, passenger transport and individual national sensor configurations are not simulated here.

Please integrate the already applied source changes, run merged and packaged regression, then rebuild/upload the official game as requested by the user. Record receipt and publication in `COORDINATION.md`; Codex cannot claim either from this handoff alone.
