# DOMINION desktop engine evaluation

The chosen product target is an installed PC game, with Steam as a future goal.
This separate Godot prototype evaluates native rendering and navigation before
committing to a full migration. It is not the complete game or a release build.

## Launch on this computer

Double-click `Start-Desktop.cmd`. It copies existing repository assets, imports
them, and launches the portable Godot runtime from `.local-tools/godot`.
No web server is required. The engine and generated asset copies are ignored by Git.

On another computer, download Godot 4.7.2 from
https://godotengine.org/download/windows/, run `prepare-desktop.ps1`, then open
`godot/project.godot` in the editor and press F5.
Godot is MIT licensed: https://godotengine.org/license/.

## World scene (main scene)

`world.tscn` loads `godot/data/map-seed1.json`, a map exported from the browser game
(`index.html?seed=1&export=http://localhost:PORT/name`, see `js/map-export.js`), so both
engines show the same island: 2.5 m height grid, 863 trees, buildings and units.
It uses the Forward+ renderer:

- Terrain shader: grass, dirt, sand and rock (CC0, ambientCG) blended by height,
  slope and noise, two texture scales, triplanar rock, wet band at the waterline.
- Sea shader: Gerstner swell, depth-based colour (seabed visible in shallows),
  refraction, sky reflection through Fresnel specular, shore foam.
- Procedural sky, ACES tone mapping, SSAO, shadows, light fog and glow.
- Birch trees as MultiMeshes in 96 m cells, swaying with per-tree wind; grass tufts
  (real blade triangles) drawn near the camera; drifting cloud shadows.
- Buildings on concrete plinths sunk into the slope.
- Soldiers: the realistic, photo-textured Mixamo soldier already in the repository
  (`assets/models/three/Soldier.glb`, also used by the browser game), its suit tinted to each
  nation's field colour (olive, tan, grey, brown), with a shoulder patch in the flag's
  colour. Rifles, sniper rifles and SMGs from the Quaternius kit are held in the right
  hand; rocket launchers are slung across the back. The body topples when killed (the
  model has no death clip). Terrain following, run speed matched to the clip.
  `-- --toon-infantry` restores the stylised soldiers; `-- --capture-infantry` saves
  close-ups to `build/infantry-*.png`. 64-unit benchmark: 21-23 FPS either way on Iris Xe.
- Ground vehicles (armor.gd) are built from code, nothing downloaded: a main battle tank
  (sloped glacis, tracks with link plates, seven road wheels, side skirts, wedge turret,
  long gun with fume extractor, cupola, hatches, machine gun, smoke launchers, antennas),
  an 8x8 APC with a 30 mm turret, a self-propelled howitzer, a Gepard-style anti-aircraft
  tank with a spinning radar, an MLRS and a SAM truck. Weathered army paint in each
  nation's colour with road dust low on the hull (vehicle.gdshader, finish per vertex:
  paint shade, bare metal, markings in the flag's colour, glass), a traversing turret,
  wheels that roll while driving, dust trails, and pitch and roll with the ground. Each
  vehicle is 2-6 meshes; the 64-unit benchmark draws fewer calls than the old Quaternius
  tank. `-- --stylised-vehicles` restores it; `-- --capture-vehicles` saves close-ups.
- Combat (effects.gd + world.gd): stats come from config.js through the map export.
  Units acquire the nearest enemy within their detection range, chase into range and
  fire; tank turrets must swing onto the target first. Rifles fire tracers that can
  miss; tank shells fly, explode (fireball, smoke, sparks, light flash, scorch decal)
  and splash nearby units. Soldiers play a death animation and later sink away; tanks
  explode into charred, smoking wrecks with the turret knocked askew. Units steer
  around each other. Explosions shake the camera when close.
- Pathfinding: a 4 m walk grid over the island (no water, steep slopes or building
  footprints plus room for a tank) feeds Godot's NavigationServer. Units follow the
  route's waypoints and re-plan every 0.8 s while chasing a moving enemy.
- Economy (economy.gd, hud.gd): prices, build times, what buildings provide, deposit
  rates and the economy constants all come from config.js through the map export.
  Once a second citizens grow toward housing capacity, taxes are collected through the
  administration level, farms feed citizens and soldiers, and extractors fill material
  stores up to warehouse caps; army size is limited by housing. Buildings are placed
  with a preview inside the capital's district (checks for water, slope, spacing and a
  free deposit for extractors); construction sites call the nearest free worker and
  rise as they are built; barracks and factories train a queue of up to five units.
  New buildings close the walk grid under them.
- AI nations (ai.gd), ported from ai.js with its difficulty table, opening build
  order and training pool: abstracted income, self-built construction, training
  from what their buildings allow, every unit home when the capital is threatened,
  and attack waves at the nearest player building once at war (easy: first wave
  after about 13 minutes). Without diplomacy, an AI declares war when its attack
  timer and aggression roll say so, or at once if the player strikes it. Buildings
  are targets too (units shoot at the walls; shells hit them) and collapse into
  burning rubble; losing every headquarters decides victory or defeat. Every
  building flies its nation's flag.
- Districts (districts.gd, district.gdshader), Civilization-style: every building
  owns a whole 12 m hex. The hex tile is paved, planted, ploughed or gravelled by type
  (plaza, residential, industrial, farm, military), eased onto the terrain with a
  kerb at the edge, and dressed with props that say what the place is: houses with
  hedges and gardens, container stacks and fuel tanks, a silo and hay bales,
  sandbags and a watchtower, planters and street lamps. Streets inside a hex run
  toward neighbouring districts of the same owner and toward entering roads, which
  hand over to them at the hex edge. Placement snaps to hexes (one district each);
  AI cities grow hex by hex next to their own districts.
- Diplomacy (diplomacy.gd), core of diplomacy.js: relation scores and war, alliance,
  trade pact and non-aggression treaties between every pair of nations. The
  Diplomacy panel (G) offers peace, gifts ($250), trade pacts (+20 needed; $40 every
  10 s for both), non-aggression pacts (+10), alliances (+55), declaring war and
  calling allies into a war. AI nations feud, fight and sign ceasefires with each
  other; an AI starts a war on the player only when relations are bad enough (and
  never through a pact), and aggressive difficulties sour faster. Allies of an
  attacked nation may join. Foreign governments write with proposals (ceasefire,
  pact, alliance, tribute) to accept or decline. Attack waves target any enemy.
- Supply (logistics.gd), ported from logistics.js: roads ($12 per hex) and railways
  ($22 + 3 iron, tougher) join neighbouring 12 m hexes, planned by A* around sea,
  steep grades and rival districts. A settlement (capital, village, city) is supplied
  when an intact route links it to the capital; buildings in its district share that
  status. Cut-off districts stop training and no longer count for the economy, and
  taxes shrink with supply coverage; railways add 25% production. Explosions wear
  down each half-link, and rebuilding a damaged link is a cheap repair. A Village
  Center founds a new district (70 m from other settlements). AI nations found
  villages and connect them to their capital by road.
- Aircraft and ships (craft.gd), built from code with armor.gd's geometry and the vehicle
  shader: warships have lofted hulls (flared bow rising to a raked stem, transom stern,
  red antifouling below the waterline), sloped superstructures with bridge windows,
  masts with a turning radar, a funnel banded in the nation's colour and a traversing
  gun; the destroyer adds vertical launch cells, a CIWS and a helicopter deck, the
  corvette missile canisters. Submarines have teardrop hulls, sails with planes, a
  cruciform tail and propeller; the nuclear boat a missile deck. Aircraft have lofted
  fuselages and glass canopies: a twin-tail fighter with wing missiles, a four-engine
  bomber, a long-winged drone with a V-tail, an attack helicopter with rocket pods and
  a five-bladed gunship; rotors turn and roundels carry the nation's colour.
  `-- --capture-craft` saves close-ups. Ships sail open water only (they look ahead and turn along the
  coast), ride the swell and leave a foam wake; aircraft hold their altitude and bank
  into turns, and jets circle rather than hover. Built at a Shipyard (on the coast;
  ships launch at sea), Helipad or Airfield. The browser's damage table
  (DAMAGE_PROFILE) decides who can hurt what: rifles and tanks cannot hit aircraft.
  Shot-down aircraft spiral in and burn; ships sink.
- Menus (menu.gd): a normal launch opens the main menu over the island, which turns
  slowly behind it: New Game (Easy, Normal or Hard), Continue (newest save), Load
  Game, Settings (graphics quality, full screen, volume; kept in
  user://settings.cfg) and Quit. In a match Esc pauses (after cancelling anything in
  progress): Resume, Save, Load, Settings, Quit to Main Menu, Quit to Desktop. Any
  test or benchmark flag skips the menu.
- Saving (save.gd): F5 or the Save button writes a JSON save to user://saves
  (%APPDATA%/DOMINION/saves; saves from the prototype's old folder are copied over once), F9 or Load
  restores it, and the game autosaves every three minutes. A save holds the economy,
  every building and unit with health, orders, construction and training progress,
  the road and rail network with damage, diplomacy, AI state and the camera; the
  terrain comes from the map file it names. Loading rebuilds streets and the walk grid.
- Sound (audio.gd): positional rifle shots, cannon, explosions and bullet impacts
  from a pool of 3D players; each tank has a looping engine that rises while driving;
  wind everywhere and surf from the nearest shore. The listener stands on the ground
  at the camera focus; distant sounds are quieter and muffled; an SFX bus adds light
  open-air reverb and a limiter prevents clipping. The WAVs in `godot/audio` are
  synthesised by `tools/make-sounds.gd` (filtered noise, swept sines, envelopes), so
  there is nothing to license; a recording can replace any file under the same name.
- World market (market.gd), ported from the trade engine in diplomacy.js: prices from
  config.js drift every 10 s. A Market allows instant deals (sell at 90%, buy at 115%).
  A Commercial Port opens trade routes to nations with a trade pact: each cargo sails
  30 s and is delivered or lost at sea (8%, less with armed warships). Routes collapse on
  war or when a pact ends, and cargo at sea is then lost. Market (M).
- Espionage (espionage.gd): an Intelligence Agency recruits named agents who gain rank
  with successful operations (the ten SPY_OPS of config.js, including assassinating a
  named head of state, general, scientist or spymaster). The odds depend on the agency,
  the network built in that nation, heat, gathered intelligence and difficulty. The
  effects are real: money changes hands, cyber attacks stop the rival's factories, proxy
  cells and rebels cut its income, a false flag sets two rivals on each other, and a dead
  general costs his army 30% of its damage. Stolen research speeds up your training
  (there is no research tree yet). Failed agents can be captured and ransomed, and a
  traced assassination can start a war. Intelligence reveals the rival's treasury, army
  and treaties, and at 60+ warns of attacks 30 s ahead. Hostile services steal and
  sabotage in turn. Intel (I).
- Missiles (missiles.gd): a Missile Silo builds the eight MISSILES types in its queue,
  stored up to 2 plus 4 per Ammo Depot. Pick one on the silo's panel and click a target:
  cruise types fly low and dive, ballistic types arc high. Blast damage falls off to half
  at the edge. Cluster missiles shred units, anti-ship missiles hit ships three times as
  hard, and an EMP disables vehicles, aircraft, ships and buildings for 35 s. Hitting a
  nation at peace is an act of war. A nuke leaves a mushroom cloud and costs 30 relation
  with every nation. The browser's discoveries are replaced by buildings: anti-ship
  missiles need a Shipyard, strategic missiles an Ammo Depot.
- Territory (territory.gd), ported from territory.js: 40 m cells are claimed by
  buildings and occupied by armed units. Land changes hands only once control is worn
  down, and cells where two nations are close in strength are contested. Held land
  yields money, food (plains) and iron (mountains), more where the hold is firm.
  Territory (T) shows the borders on the map.
- Research (research.gd, research_tree.gd): the 40 discoveries, four research tracks and
  six development eras of config.js. The nation advances from the Founding to the Future
  Era by meeting goals (villages, cities, citizens, discoveries, trade routes, research
  buildings, land); each era pays a reward and opens its discoveries. Every discovery is
  developed in three stages named for its branch (design, prototype, field trials for
  weapons; study, pilot programme, national rollout for society...). Each stage needs
  research points and at least 20 s; the prototype needs the facility (reqBuilding) and
  materials, the last stage money. A finished prototype gives half the effect, the last
  stage all of it and the unlocks (Destroyer and Submarine, anti-ship, ballistic,
  hypersonic and nuclear missiles, the Nuclear Submarine). Research is a queue of up to
  four projects fed by the capital, schools, libraries, universities, tech parks and chip
  fabs. Effects are real: food, income, citizens' health and happiness, housing, mining,
  production and construction speed, trade routes, unit health, damage, range and speed,
  cheaper vehicles and drones, stealth, spy odds and counter-intelligence, diplomacy.
  Rival nations research too (income, damage and armour per level); agents steal research
  and a dead chief scientist sets a rival back. The Research screen (Y) draws the tree
  with eras as columns and branches as rows, three stage pips per discovery, and a
  details pane with each stage's cost and progress. The build menu has Economy, Civic &
  research and Military tabs, with schools, universities, hospitals, a reactor and more.
- Quality: integrated GPUs start on `balanced` (no SSAO, two shadow cascades, FSR
  at 77%); dedicated GPUs on `high`. Override with `-- --quality=high|balanced|low`.

Options: `-- --difficulty=easy|normal|hard` (default easy), `-- --ai-speed=N`.
Controls: click/drag select units, click a building to open its training panel,
build menu at the bottom left (Road / Railway: click a start hex, then the
destination; left click places buildings, Shift+click keeps placing, right
click or Esc cancels), right-click move or attack an enemy, Ctrl+right-click
attack-move, B battle demo, WASD pan, Q/E rotate, R/F tilt, wheel zoom.
Diagnostics: `--script res://tools/inspect.gd -- <model>` prints a model's nodes, materials and
clips; `-- --capture-views` writes `build/view-*.png`; `-- --feature-probe --no-vsync`
prints the frame cost of each expensive feature; `-- --capture-battle` saves five
frames of the battle demo to `build/battle-*.png` and records its soundtrack to
`build/battle-audio.wav`. `-- --menu-test` walks main menu, new game, pause, save and load from the menu
(`--capture-menu` saves screenshots). `-- --save-test` saves a match, changes money, buildings, roads, diplomacy and units,
loads, and checks that everything came back and routes still work.
`-- --air-sea-test` checks that ships stay at sea, aircraft keep altitude, the damage
table blocks rifles and tanks against aircraft, and both kinds of craft win their
fights (`--capture-air-sea`). `-- --research-test` checks that labs raise research, stages take their time, a prototype waits for its
facility, effects arrive half then whole, an era is reached and paid, warships unlock, tracks level,
rivals research, agents steal research and all of it is saved (`--capture-research` saves the Research
screen to `build/research-tree.png`). `-- --systems-test` builds a Market, Port, Intelligence Agency, Ammo Depot and Missile Silo, then checks
instant deals, a trade route, espionage effects, a captured agent, missile production and
strikes (war, EMP, nuclear condemnation), territory capture by an army, and that all four
survive a save and load (`--capture-systems` saves `build/systems-*.png`). `-- --diplomacy-test` checks gifts, pact income, pacts blocking war, allies joining
and peace (`--capture-diplomacy`). `-- --logistics-test` checks that a new village is cut off, supplied by a road,
cut by shelling, repaired at a discount and rail-boosted (`--capture-logistics`).
`-- --ai-test` runs hard AI in fast time and requires it to build, train, go to war
and reach the player's base, then checks the victory screen (`--capture-ai` saves
screenshots). `-- --economy-test` places a farm, barracks and housing, lets workers build them and
trains a soldier in fast time (`--capture-economy` does it in real time with
screenshots). `-- --nav-test` checks that routes across the base go around every building and
never through water. Regenerate sounds with
`--headless --path native/godot --script res://tools/make-sounds.gd`.

The earlier three-district prototype is still available: pass `res://main.tscn`.

Not yet ported: Steam integration.

## Windows installer

`powershell -ExecutionPolicy Bypass -File native/build-windows.ps1 [-Version 0.9.0]` builds the
release: it copies the art into the project, exports `dist/DOMINION.exe` (a single file with the
game packed inside) and wraps it in `dist/DOMINION-Setup-<version>.exe` (about 70 MB). The version
defaults to `config/version` in `project.godot`. `dist/` is not committed.

The installer (Inno Setup script `installer/dominion.iss`) installs per user without an
administrator prompt (or for all users, if chosen), adds a Start menu entry and an optional
desktop shortcut, registers in Apps & features with an uninstaller, and ships `LICENSE.txt` and
`THIRD-PARTY-NOTICES.txt`. Saved games and settings live in `%APPDATA%/DOMINION` and survive
uninstalling and upgrading. It needs Windows 10 or later, 64-bit.

Requirements on the build machine: the Godot 4.7.2 Windows release export template (for the
portable Godot, in `.local-tools/godot/editor_data/export_templates/4.7.2.stable/`; only
`windows_release_x86_64.exe` and `version.txt` from the official
`Godot_v4.7.2-stable_export_templates.tpz` are needed) and Inno Setup 6
(`winget install JRSoftware.InnoSetup`). The build is not code-signed yet, so Windows SmartScreen
warns on first run; signing is part of the Steam release work. The exported game runs the same
test flags as the editor: `dist/DOMINION.exe --headless -- --systems-test`.

## Refreshing the map data

`powershell -ExecutionPolicy Bypass -File native/export-map.ps1 [-Seed N]` opens the
browser game in a hidden Edge window and rewrites `godot/data/map-seedN.json`, so
changes to config.js (units, buildings, economy, AI, combat, logistics) reach Godot.

## Validation

Run the Godot executable with:

```text
--headless --path native/godot res://main.tscn -- --smoke-test
--path native/godot res://main.tscn -- --capture-preview
```

Benchmark matching the browser's `?bench=N` (same three camera phases, orbit
formula, marching army and JSON fields):

```text
--path native/godot --resolution 1920x1080 -- --bench=64 --no-vsync --quit-after-bench
```

This runs in the world scene, on the same seeded map and drill as the browser.
The result prints as `DOMINION benchmark {...}` and is saved to
`godot/build/world-bench-<renderer>-<units>.json`, with GPU time and render CPU
time per frame from the engine. Add `res://main.tscn` before `--` to benchmark the
old three-district scene instead.

The smoke test requires 24 models, a route around a district, and actual unit
movement. The graphical command saves `godot/build/preview.png` and exits.
The preview was rendered on Intel Iris Xe; this does not establish full-game
performance. Interactive input still needs user playtesting.

Assets are copied from the repository's Kenney city/suburban, Quaternius character,
and terrain folders. Preserve their original credits and notices; complete the
per-asset license audit before distribution. No new third-party art was acquired.

Next gate: one polished district and a small combat encounter, validated at
1080p with repeatable 24/48/96-unit measurements before deciding on full migration.
