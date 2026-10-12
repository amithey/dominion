# Native interface readability — 2026-10-11

Implemented in the existing Godot game, preserving the concurrent gameplay work.

- One Segoe UI / Arial family for titles and body copy; a minimum 13-point size for shared labels and ministry content.
- Production cards have a name, brief role, named resource costs, duration, explicit action and a separate prerequisite warning. Cards size themselves to their wrapped contents.
- Missile facilities have separate Produce weapons and Stockpile / target tabs. Production shows storage and queue counts. Target selection only lists stored payloads and explains the next map click and Escape cancellation.
- Missile summaries show the actual role, compatible launch platform, damage and blast radius; detailed descriptions remain on hover. Capability assessments and research restrictions stay visible.
- Ship launch buttons wrap instead of running off the selection panel. Ministry meters put their captions above the fill.
- New installations and settings reset use 100% interface size; existing saved preferences are preserved. Settings show explicit percentages.
- Four explicit float annotations fix compilation of the in-progress AI directorate without changing its behavior.

Validation: menus-check (52), arsenal-check (332), plus readability-check at 100% with card geometry, stockpile/action behavior, resource-strip clearance and screenshots of construction, missile production/stockpile, diplomacy, market, intelligence and defence.

Local preview: build/regional-preview/DOMINION.exe through Start-Regional-Preview.bat. Official release installers are not updated by this change.
