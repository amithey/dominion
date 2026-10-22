# Arsenal audit, 22 October 2026

Question: does every nation field only the weapons it really has? Method: `godot/tools/arsenal-audit.gd`
plays a match with each nation and dumps `unit_allowed()` and the national name of every unit
(`godot/build/arsenal-audit2.txt`), which was then read nation by nation. Representative systems, not stock counts;
an order or a trial never grants a unit (same rule as ARSENAL-RESEARCH-2026-10-06.md).

## Changed

| System | Before | Now | Why |
| --- | --- | --- | --- |
| Precision long-range rocket launcher ("himars") | every nation except Iraq, Syria, Afghanistan; North Korea, Egypt, France, Pakistan, Brazil, Indonesia, Saudi Arabia shown as "HIMARS" or a generic launcher | removed for Saudi Arabia, Brazil, Indonesia, Egypt; renamed for UK (M270A2 with GMLRS), South Korea (Chunmoo with guided rockets), France (LRU, GMLRS), North Korea (KN-25 600 mm guided rocket), Pakistan (Fatah-II), Ukraine and Australia (M142 HIMARS) | the US HIMARS is in service only with the US, Ukraine, Australia (and a few not modelled); the others have a guided system of their own or none |
| Jammer vehicle ("ewVehicle") | all nations, mostly under the generic name "EW Vehicle" | United States, China, Germany, Russia, India, Japan, Turkey, Israel, UK, France, Ukraine, North Korea (GPS jamming trucks) | no evidence of a ground EW vehicle for Afghanistan, Syria, Iraq, Saudi Arabia, Brazil, Egypt, Indonesia, Australia, Pakistan, South Korea |
| Loitering munition | all nations | United States, China, Germany, Iran, Russia, India, Japan, Turkey, Israel, UK, South Korea, Ukraine, Pakistan, France, North Korea | none documented for Afghanistan, Syria, Iraq, Saudi Arabia, Brazil, Egypt, Indonesia, Australia |
| Indonesia's attack helicopter | AH-64E Apache | Mi-35P | the Apache purchase was never completed |

## Still open (not changed: the evidence is mixed)

- Saudi Arabia's Tornado IDS (retirement under way); Turkey's KAAN and India's AMCA appear in the stealth list (gated by research, not at start).
- Generic names ("Gunboat", "Mine-clearing Vehicle", "Armoured Recovery Vehicle", "Loitering Munition" for UK, South Korea, Ukraine, France, North Korea, Pakistan) stand for the army's own equipment but are not named per nation.
- Mine layers, mine clearers and recovery vehicles are given to every national army (Afghanistan's Taliban army has no such engineers).
- Brazil's guided ASTROS round (SS-40G) and Saudi/Egyptian rocket artillery upgrades: add when they are in service.

Test: `tools/arsenal-reality-check.gd` (registered in `run-tests.ps1`).
