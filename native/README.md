# DOMINION desktop game

The chosen product target is an installed PC game, with Steam as a future goal.
The active game is in `native/godot`. The browser implementation in `js/` is a
reference for rules and exported data. Run `prepare-desktop.ps1` before changing
or testing the native game; copied art and the engine are local-only.

> Continuing development? Read [HANDOFF.md](HANDOFF.md) first: where the 0.9.4–0.9.5 code lives and the traps to avoid.

## Version 0.9.7: land held hex by hex, and asking before clearing a site

- **Territory by hexes** (`territory.gd`), as in a 4X game. Land is the same 12 m hex grid the
  districts sit on. Every hex you build on is yours, with a ring of hexes around it. The capital
  claims three rings; city and village centres and Command & Control claim two. Units still
  hold the hex they stand on, and conquest wears a hex's control down as before.
  - Borders are always on the map: a line along the hex edges in each nation's colour, with a
    soft band of colour inside it.
  - The territory view (T) also washes the land in its owner's colour and hatches contested
    hexes in gold. The minimap draws the same hexes.
  - Land yields are scaled to the smaller cells, so the economy keeps its balance.
- **Clearing a site** (`site_clearing.gd`). Building where trees grow or on a natural resource asks
  first: "Clear the site and build" or "Cancel".
  - Felled trees give a little timber money ($4 each).
  - A deposit destroyed this way can never be mined again.
  - An extractor or an offshore rig does not count its own deposit.
  - Rival nations and the buildings a map starts with clear trees without asking.
  - Trees no longer grow through buildings.
- The release is built from the last commit, never from uncommitted work in the folder.
- New test: `--site-test`.

## Version 0.9.6: armour that drives like traffic, borders, conquest and resource sites

- **Armoured columns** (`--convoy-test`). Tanks used to weave from side to side and bump each other.
  Four fixes:
  - **Proportional steering** instead of all-or-nothing turns.
  - **Straight routes:** the 4 m nav-grid zigzag is straightened into straight legs wherever the
    ground allows.
  - **Pure pursuit:** each vehicle steers at a point 7 m ahead on its route.
  - **Traffic rules:** a vehicle follows the one ahead at its pace, steers smoothly round a
    stopped or crossing one, and is never shoved sideways; only real hull overlap is pushed apart.

  Formation slots are 8.5 m apart. A tank waiting in line no longer "gives up" far from its mark.
  Climbing costs at most 40% of speed. Measured on 8 vehicles over 130 m: 150–700 left/right
  reversals before, 9–18 after; hulls never closer than 5.2 m.
- **Borders and passage** (`passage.gd`). Armed forces may enter another nation's land only with a
  grant of passage, as its ally, or at war or in a limited operation.
  - **Your orders:** a move order into closed land brings a BORDER letter. Its answers: request
    passage (the other government decides by how it regards you; +50 or better always says yes), a
    military operation under the standing orders, cross anyway, or cancel.
  - **Trespass:** relations fall, and after 25 s their government answers as it would any
    incident: a protest, a strike in kind, or war.
  - **Their forces:** an AI force entering your land without leave brings a letter: grant passage,
    demand withdrawal, or open fire.
  - **Guests take no land:** only hostile forces wear down another nation's hold on a cell.
- **Operational zones** (`occupation.gd`). Press **O** and click the ground: a 60 m dashed ring marked
  OPERATIONAL ZONE appears, and the selected forces spread over the cells still to be taken.
  - Troops inside their own zone count double toward holding the land.
  - A zone in the land of a nation you are not fighting asks the cabinet first (standing orders).
  - When all the land in it is yours, the zone is secured and lifted.
  - Zones and passage grants persist in saves.
- **Natural resources** (`deposit_art.gd`). Every deposit is now a site built in code, about 10 m
  across on its own coloured ground and following the slope, with a fixed-size resource marker over it:
  - oil: a black pool and a nodding pumpjack
  - iron: rust boulders
  - gold: veined granite
  - silicon: blue quartz
  - uranium: glowing green crystals
  - diamonds: a kimberlite pit
  - offshore oil: a platform with a flare
  - fish: a shoal with ripples

  Sea deposits now exist in the game, so the Offshore Rig can be built on offshore oil. Land
  extractors and the AI never pick a sea deposit.
- `dist/` holds exactly `DOMINION.exe` (play) and `DOMINION-Setup.exe` (the release).

## Version 0.9.5: how battles are fought, and the minimap turned with the camera

Problems reported in play: armies ran together into one knot where few
could shoot, a unit sometimes stuck after an attack, and the minimap's view
frame sat crooked. `scripts/tactics.gd` changes how units fight and march:

- **Firing positions.** A unit closing on an enemy heads for a spot inside
  its own weapon range, on its own bearing, rather than to the enemy's
  position, so a squad spreads into a firing line. It stops and fires as
  soon as the target is in range, and a unit holding at the edge of range
  still has its shot.
- **Target choice.** Units prefer targets already in range, those their
  weapon hurts most and those already wounded. Every unit searches as far as
  its weapon reaches (artillery and rocket launchers used to look nearer than
  they could shoot) and swaps to a better target in range now and then.
- **Never stuck.** A target that stops being hostile (a limited operation
  ends) is dropped; ground troops do not chase ships or aircraft out of reach
  and do not "return fire" at an attacker they cannot hurt or reach; a chase
  that makes no progress for 12 s is abandoned (aircraft excepted, they make
  passes); a unit whose slot is occupied counts as arrived when close, or
  re-routes. Blocked units step round each other, and a unit jammed while
  closing in takes a new bearing.
- **Formations.** A group move forms ranks across the line of march: armour
  in front, infantry behind, artillery and air defence at the back. Slots are
  handed out in the order units already stand, and the body marches at the
  pace of its slowest member. Standing units that overlap step apart; hulls
  keep 6.5 m from each other.
- **Accuracy.** Long shots and moving targets miss more, point-blank shots
  rarely do. A 16 against 16 fight now lasts about 40 s of contact, not 10.
- **Blast physics.** Explosions shove soldiers back, jolt vehicle hulls on
  their springs, and throw a soldier killed by the blast through the air.
- **Minimap.** The map turns with the camera, so the top of the screen is the
  top of the map and the view frame always points straight up; a gold needle
  on the rim marks north. The island is scaled so no land is cut off.
- **Engine.** Decisions (target upkeep, firing positions) run ten times a
  second per unit, staggered, while movement stays at 60 Hz; standing units
  use a walk-grid lookup instead of scanning every building; a vehicle
  resamples the ground slope only after moving half a metre. In the 48-a-side
  battle benchmark this took standing units from 4.3 to 1.0 ms and placement
  from 2.5 to 0.3 ms per physics step.
- `--battle-test` fights two equal mixed forces and fails on any unit that sits
  loaded with a target in range for a second, units piling on one spot, a unit
  frozen with an enemy, a squad that will not move after an attack, or ground
  troops chasing a ship. `--capture-tactics` renders the march, the firefight
  and the turned minimap.

## Version 0.9.4: movement physics, debris and a 4X unit card

- **Momentum.** Ground units build up speed and brake onto their mark
  instead of switching between standing and full speed in one frame
  (`scripts/motion.gd`). Vehicles drive along their hull: a tank ordered
  behind itself pivots in place first rather than sliding sideways, slows
  for corners, and climbs slower than it descends.
- **Sprung hulls.** Every vehicle rides a damped spring on pitch and roll: it
  squats when it pulls away, dips its nose when it brakes, leans out of a
  turn, rocks back when its gun fires and follows the ground smoothly.
- **Debris.** Explosions throw clods, armour and masonry that fly under
  gravity, bounce off the slope, tumble, rest and fade (`scripts/debris.gd`,
  one pooled MultiMesh, one draw call). Pieces in the sea sink. Tank shells
  follow a gravity arc, blasts send a shock ring along the ground, a
  destroyed tank may cook off and throw its turret, and buildings burst.
- **Look.** AgX tonemapping, more aerial haze, deeper summer greens for
  meadows, tufts and trees; each tree crown has its own shade and is darker
  inside; leaf edges are anti-aliased.
- **Interface.** The selection card shows a round bronze-and-gold portrait
  medallion on the owner's colour, with ATTACK / RANGE / SPEED / HEALTH
  plaques. The era cartouche counts the years of the reign. Notices run in
  the lane between the side screens and the production list. Health bars
  on the battlefield carry the owner's colour and step clear of each other.
- `--motion-test` checks pivoting, acceleration, stopping, suspension,
  debris landing and the turret toss; it is part of `run-tests.ps1`.

## War is decided by the state, not by the soldier

- A soldier ordered to fire carries out the order. What the shot *means* is
  settled at the level of the state, so the choice between a limited operation
  and a full war left the unit panel: it is now the cabinet's standing orders,
  set in the Diplomacy screen (G) under STANDING ORDERS, and every first strike
  at a nation you are not at war with still goes to the cabinet for
  authorization.
- The struck government then answers for itself: it may contain the incident (a
  protest and colder relations), answer in kind (a limited operation of its own
  and a punitive column sent at your nearest holding), or call it war. The
  choice weighs how far relations had sunk, how many incidents it has already
  swallowed, how its army compares to yours and how aggressive it is — and a
  first incident is never called a war.
- AI governments now hold the same instrument. Unless relations have collapsed,
  one that wants to move against you strikes across the border and calls it a
  limited operation rather than declaring war, and your cabinet puts the three
  answers to you in a letter: contain, answer in kind, or declare war. Answering
  in kind puts another grievance on their books, and a government that runs out
  of patience declares war itself.
- The minimap wedge shows where the camera is really looking: rays through the
  top of the screen pass above the horizon and never meet the ground, so they
  are stopped at a sensible distance instead of folding the wedge into the
  corner of the map. The wedge is filled, carries an arrow at its far edge for
  the direction of view and a dot at the centre of the view, and is clipped at
  the frame.

## Panel and menu redesign

- Every panel, menu and dialog is now built from drawn plates rather than flat
  boxes: a navy body that catches the light along its top edge and sinks into
  shadow at the bottom, a double frame (near black outside, bronze inside) and a
  soft drop shadow, in the manner of the classic 4X interfaces. The plates are
  small textures generated once at startup in `ui_theme.gd` and stretched as
  nine patches, so nothing is downloaded and nothing is loaded from disk.
- Each panel wears a title band: letterspaced serif capitals on a lit strip
  closed by a gold rule. The production list, the selection panel, the screens
  window, the research screen, the controls sheet, the foreign office letters
  and the pause menu all share it.
- The build tabs are a strip of plates, the open one struck in gold with dark
  letters. The list below sits in a sunken trough, and every entry is a plate of
  its own with the picture in a bronze-lipped frame, the name in cream, the cost
  as resource chips and the build time in a small brass tally.
- The resource strip is a lit band with hairline dividers between the yields and
  the era in a brass cartouche at its end; the screen buttons sit in a mounted
  rack below it. Menu entries are plates with a gold edge that widens and
  brightens under the cursor, and the pause card is cut to the height of
  whatever screen is in it.

## September combat and interface update

- Shared navy/gold panels and serif headings, a cartographic menu ornament, and
  visible keyboard focus. Original presentation inspired by classic strategy UI.
- Explicit attacks establish hostility before the first shell's splash filtering.
  Damaged buildings briefly show their remaining health above the model.
- Alt + right click orders armed ground/air vehicles to bombard terrain or roads.
  A move or direct attack cancels the ground order. Conventional infrastructure
  damage is confined to the impacted hex; nuclear blasts retain radius damage.
- Aircraft carry a limited number of firing salvos (jet 4, bomber 3, drone 6,
  helicopters 8). Fixed-wing craft fire forward and continue through waypoints.
  Empty aircraft return to a friendly, supplied, completed airfield (helicopters
  can also use a helipad), descend, rearm for 12 seconds and take off. If no base
  is available they cannot refill; fixed-wing aircraft keep circling.
  Landing is a simplified approach, not a runway reservation or collision system.
- Ammunition, service state and ground bombardment orders persist in saves; old
  saves receive default full loads. Aircraft selection shows ammunition and status.
- `--combat-regression` checks first-strike damage, hex/radius damage, movement,
  ammunition, service, unavailable bases, save/load and the aircraft HUD. Add
  `--capture-operations` for `build/aircraft-ammunition.png`.
- The full test runner now includes 20 suites and also rejects nonzero exits
  and explicit FAIL reports even if a PASS marker was printed.

## Campaign, command and balance update

- New Game now offers the original island or its mirrored western layout,
  2–4 total participants (one human plus AI), four nation/leader pairs, difficulty,
  and Standard or Sandbox (no AI attack waves). The second layout mirrors the
  existing terrain and asset positions; it is not a newly authored continent.
  Setup persists in saves; loading a different setup rebuilds the correct scene.
- Ctrl + right click has priority over direct enemy selection and replaces an old
  bombardment order. Alt + right click bombards. The selection panel also provides
  Attack-move and Bombard buttons: press one, then left-click a destination; Esc or
  right-click cancels the pending mode.
- Ships use a deep-water A* grid, safe coastal destinations and heading recovery,
  including a permitted escape toward deeper water from old shallow-water saves.
- Selected/damaged units and damaged buildings have segmented on-map HP bars.
  The selection panel shows percent and HP; Repair orders vehicle/building repair
  at 2.5% max HP per second for $0.25 per HP. Movement, combat, recent hits (6 s),
  EMP and lost building supply pause work. Rebuild road/rail links to repair them.
- Aircraft salvos deal 2.5x their former damage; silo missiles deal 1.75x. This is
  an initial balance pass, not a claim of competitive balance. Rifle infantry,
  snipers and commandos cannot penetrate armour or attack aircraft/ships; rocket
  infantry and dedicated anti-air retain their appropriate damage profiles.
- The minimap projects actual viewport corner rays onto the ground, so the view
  outline follows camera rotation and zoom.
- Choose Limited operation or Full war in the selection panel. An attack on a
  peaceful nation requires an Authorize/Cancel warning. Limited operations last
  90 s, cost 18 relation points, break treaties and allow local defence without an
  automatic full war. Hostile repeated operations can escalate, and normal AI
  diplomacy can still choose war. Orders against that nation stop at expiration.
  Map/leader choices and operation/repair state persist in saves.
- `--polish-test` checks modifiers, cancellation, repairs, weapon roles, coastal
  navigation, minimap rotation and operation expiry. `--campaign-test` loads the
  mirrored map with two participants and a different leader, checks remapping and
  save identity. `--capture-polish` saves the strike warning for visual inspection.

## Interface and unit behaviour refinement

- Campaign choices show a live briefing with the selected leader, rival count and
  difficulty or sandbox rules. Menu pages fade in, scroll when necessary and support
  keyboard focus. Settings show a numeric volume readout and graphics guidance.
- Shared slate/brass styling covers dropdowns, sliders, text fields and focus states.
  Selection commands disable unavailable actions, indicate active targeting modes,
  explain their controls on hover and restore the saved engagement policy correctly.
  Health colour changes with damage; construction uses a separate blue fill.
- Ships accelerate gradually, reduce speed in turns and slow near their destination.
  Existing coastal collision checks and recovery remain authoritative; this is an
  improved kinematic movement model, not a rigid-body fluid simulation.
- AI production requires an operational, supplied facility and spawns at that
  facility; ships launch in water. Defenders must be able to damage their target.
  Aircraft returning/rearming or out of ammunition are excluded from new missions,
  and ships are excluded from land assault waves.
- The polish regression suite checks contextual commands, AI water launches,
  supply restrictions and aircraft availability alongside coastal navigation.

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
- Interface (hud.gd, ui_theme.gd, portraits.gd, minimap.gd), laid out like a 4X game: a
  top bar of resources with icons (stock, and the rate in green or red; storage caps show
  when a store is nearly full), round screen buttons under it (research, diplomacy,
  market, intelligence, territory, menu), a production list on the right with a bar per
  building or unit: its picture, rendered from the game's own 3D model in an off-screen
  studio, name, what it does, cost in resource icons and time; a selection panel bottom
  left with a large picture, health, status and the training queue as small pictures;
  a minimap bottom right (click or drag to move the camera) and notices as small cards.
  One theme styles every panel, button, tooltip and menu: navy plates in a bronze
  frame with gold rules and title bands, in Windows' Bahnschrift with Palatino headings. The icons are drawn by `tools/make-icons.py` (Pillow) into
  `ui/icons/`. F1 shows the controls.
- Weapons: aircraft, artillery, rocket launchers, SAMs, rocket infantry and submarines fire
  projectiles that are seen to fly and explode where they land: bombers line up over the
  target and drop a stick of four bombs, jets and drones fire guided missiles, helicopters
  and gunships rocket salvos, the MLRS six-rocket barrages, artillery shells on a high arc,
  submarines torpedoes that run under the water. Splash hurts only enemies.
- Territory view (T): each nation's land is painted into the terrain in its colour (deeper
  where control is firm), with bright borders between nations, gold hatching on contested
  fronts and each nation's name over its land; the minimap shows the same. Clicking the map
  while the view is open tells who holds that land, its terrain, control and yield.
- Screens: diplomacy, market, intelligence and territory share one window of cards (a
  relation meter per nation with treaty tags, prices with trends and buy/sell buttons,
  agents with rank stars and a success meter per operation, land shares); the main menu,
  pause menu, foreign letters and the end screen follow the same style.
- The army a nation starts with is its garrison and does not use up housing, so a new
  game can train soldiers at once.
- Camera: WASD or the arrow keys (by key position, so any keyboard layout), the screen
  edge, a middle-button drag, Q/E to turn, R/F or PageUp/PageDown to tilt, and the wheel,
  which zooms toward the cursor. The view stays over the island. `-- --camera-test`.
- Quality: integrated GPUs start on `balanced` (no SSAO, two shadow cascades, FSR
  at 77%); dedicated GPUs on `high`. Override with `-- --quality=high|balanced|low`.

Options: `-- --difficulty=easy|normal|hard` (default easy), `-- --ai-speed=N`.
Controls (F1 in game): click/drag select units, click a building to open its training list,
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

## Performance

Measured on an Intel Iris Xe laptop at 1920x1080 with the seeded benchmark
(`-- --bench=N --no-vsync --quit-after-bench`), which drills the same army over the same
three camera phases every run. `-- --no-perf` puts the old behaviour back, so the two can
be measured against each other in one sitting (the laptop throttles, so only compare runs
taken minutes apart):

| Scene | Before | After |
|---|---|---|
| 128 units, three phases | 7.5 FPS, 2,337 draw calls | 20.1 FPS, 1,456 draw calls |
| 64 units, three phases | 20.6 FPS, 1,448 draw calls | 25.6 FPS, 931 draw calls |
| 120-unit battle (`--battle-bench=60`) | 12.8 FPS, median 60 ms, 165 stalls over 100 ms | 17.1 FPS, median 47 ms, 60 stalls |

What was slow, and what changed:
- **Every unit looked at every other unit** to keep clear and to find a target. Ground
  units are now bucketed into 8 m cells once a frame and read only the buckets around
  them; crowd pressure is worked out every other frame and held in between, and distances
  are compared squared so the square root only runs on a real overlap. Keeping clear fell
  from 11.5 ms to 3.4 ms a frame with 128 units.
- **Animation is the most expensive thing per figure.** Units more than 110 m from the
  camera hold their pose; they pick the animation up again as the camera comes near.
- **Shadows reached the horizon.** The sun's shadow distance is now 220 m on high, 140 m
  on balanced and 95 m on low, with a fade at the edge, and units beyond 75 m stop casting
  a shadow. This is most of the draw-call saving.
- **Health bars** are drawn only for what is hurt or selected, in front of the camera, on
  screen and within 130 m, with the tick marks on selected units only.
- **Vehicles told their shader the ground height every frame**, for every mesh; they now
  only do it when they have actually moved up or down.

`-- --profile` during any benchmark prints where each frame went, by system
(`move`, `combat`, `keeping clear`, `placing`, `steering`, `ai`, `hud`, `effects`...).
`-- --feature-probe --probe-units=N` measures the frame cost of each feature (shadows,
SSAO, grass, trees, animation, health bars) by turning them off one at a time.

## Testing everything

`powershell -ExecutionPolicy Bypass -File native/run-tests.ps1` runs every automated test in turn
(about 25 minutes) and prints a table; `-Quick` skips the AI war and the 12-minute match, and
`-Exported` runs them against the built `dist/DOMINION.exe`. A test fails if it reports FAIL,
times out, or prints any SCRIPT ERROR on the way. The suites:

| Flag | What it checks |
|---|---|
| `--smoke-test` (main.tscn) | models load, a route around a district, units move |
| `--nav-test` | routes never cross buildings or water |
| `--camera-test` | WASD, arrow keys and a middle-button drag move the view; it stays over the island |
| `--economy-test` | workers build, a soldier trains, money and food move |
| `--combat-test` | 19 duels: every armed unit fires its own weapon (bombs, missiles, rockets, torpedoes, arcing shells, bullets) and hurts its target, never its own side |
| `--combat-regression` | first-strike building damage, visible hit feedback, hex-only infrastructure damage, aircraft service, save/load ammunition and HUD |
| `--polish-test` | Alt/Ctrl input, strike cancellation, naval recovery, repairs, weapon roles, limited operations and minimap orientation |
| `--campaign-test` | mirrored terrain, two participants, chosen nation/leader, save configuration |
| `--script res://tools/campaign-flow-check.gd` | real menu start, scene reload and pending-save reload for a custom campaign |
| `--air-sea-test` | ships stay at sea, aircraft at altitude, the damage table holds |
| `--diplomacy-test` | gifts, pacts, allies joining, peace |
| `--logistics-test` | supply cut and restored by roads and rail |
| `--systems-test` | market, trade routes, espionage, missiles (EMP, nuke), territory capture, saving them |
| `--research-test` | stages, facilities, eras, unlocks, tracks, rival research |
| `--ui-test` | every screen opens and every button in it is pressed; build and train from the production list; research, help, minimap, pause and settings |
| `--save-test`, `--menu-test` | save and load, the menu flow |
| `--ai-test` | a hard AI builds, trains, goes to war and reaches the player |
| `--battle-bench=N` | a measured battle: frame times, stalls over 100 ms and draw calls |
| `--soak-test` | 12 minutes of game time against three hard rivals at 4x speed; every few seconds no unit or building has broken numbers, leaves the map or sinks, and no treasury goes negative |

Screenshot flags for looking at the result: `--capture-screens` (every screen), `--capture-ui`,
`--capture-combat` (each weapon in flight), `--capture-vehicles`, `--capture-craft`,
`--capture-infantry`, `--capture-research`, `--capture-systems`.

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

Next art/performance gate: repeatable 1080p measurements with 24/48/96 units,
plus further refinement of building materials and aircraft landing approaches.
