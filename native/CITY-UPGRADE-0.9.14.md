# DOMINION 0.9.14 — cities, commands and logistics

User-requested changes, grouped by the original issue numbers:

- **1, 7:** fewer, smaller homes with garden space between them; buildings remain opaque.
  Military yards use maintained concrete slabs. Grass is cleared beneath new districts.
- **2, 4, 12:** illustrated construction cards with descriptions, cost and time; searchable
  categories, a Menu button, themed search fields and compact resource figures with rates
  underneath. Exact inventory and capacity remain available in tooltips. F8 is in Help.
- **3, 10, 11:** unmatched mouse releases cannot deselect a building after missile targeting.
  Re-selecting the same building does not replace its buttons mid-click; changing to another
  building of the same type refreshes callbacks using the building instance identity.
- **5:** original ImageGen portraits for Hale, Volkov, Moreau and Qadir, resolved by identity
  after campaign nation reorder. These are static illustrations; successors retain the 3D
  fallback. See `godot/ui/leaders/README.md` for provenance and prompts.
- **6:** cars and trains animate on intact roads/rails. These are ambient traffic, not army
  units. Actual market shipments have cargo ships following navigable water, with direction
  and progress tied to export/import and shipment ETA. Destroyed links lose their traffic.
- **8, 9:** sea reserves use survey buoys; commissioned rigs show the platform. Added offshore
  natural gas and winter heating (four 180-second seasons per year). Rigs snap to deposits on
  the water surface and marine contractors complete them without a land worker. The Build
  list includes Offshore Rig and Fishing Wharf. Wharves belong on dry coastal hexes and gain
  food from nearby fish schools; they are not floating extractors. Fish have slender bodies,
  forked tails and a loose shoal instead of upright capsules in an evenly spaced ring.
- **13:** purchases raise prices, sales lower them, bulk orders pay the average across their
  price impact. AI markets buy shortages and sell produced surplus using national money and
  persistent commodity stocks. Trade shipments also affect supply/demand. Negative orders
  are rejected. Quotes, volume, prices and AI inventories survive save/load.
- **14, 15:** absent navigation no longer means "drive straight through". Vehicle look-ahead
  cannot cut a blocked corner, and movement/crowd displacement obey the navigation obstacles.
  Blocked steps stop and replan without turning buildings transparent. Terrain suspension
  blending avoids an unstable near-parallel rotation axis.
- **16:** active intelligence assignments show continuously updating time/progress; existing
  deployment, reports, recovery, security cooldowns and exposure rules remain in force.
- **17:** missile silos have large underground launch cells, an inspection missile and a
  gantry; ammunition depots retain low earth-covered magazines and storage racks.
- **18:** adjusted the rifle grip relative to its receiver while preserving muzzle alignment.
- **19:** every selected unit has an individual portrait; click to isolate, Shift-click to
  remove one from the selection, scroll for larger groups.
- **20, 21:** artillery/MLRS range 82/96 m, mobile AA/SAM 65/115 m. Mobile air defence searches
  while moving. Fixed SAM sites now actually launch at hostile aircraft within 140 m and
  intercept cruise missiles, sharing a cooldown; ballistic warheads are not intercepted.
- **22, 23:** returning aircraft use the same approach point as their landing state machine.
  Bases have "Recall all assigned aircraft"; parked aircraft stay parked. Recall orders a
  return flight and landing, not teleportation.

## Verification

`tools/city-upgrade-check.gd` exercises selection stability, multi-selection, marine
construction, gas heating, market pressure and AI trades, save serialization, helicopter
approach/parked recall, fixed SAM firing, traffic removal and cargo navigation. It is included
in `native/run-tests.ps1`. `tools/city-upgrade-views.gd` captures the menus, portraits, buildings,
fish and soldier grip into the ignored Godot build directory.

The broad existing suite was run, including navigation, convoy, combat, aircraft service,
economy, intelligence lifecycle, diplomacy, territory, research, UI and save/load. Tests that
write `user://` need access to the local DOMINION user-data directory; sandbox denial must
not be mistaken for a broken game save. Existing engine shutdown resource-leak warnings
remain distinct from script errors.

The committed `native/godot` source is the active game. `js/` is the legacy browser version.
Public distribution remains one installer: `dist/DOMINION-Setup.exe`; `dist/DOMINION.exe` is
the standalone executable for local play/testing. Both must be rebuilt from the release commit.
