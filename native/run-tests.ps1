# Runs every automated test of the Godot game, one after another, and prints a
# table. A test fails if it reports FAIL, does not report PASS, times out, or
# prints any SCRIPT ERROR along the way (an error in code it happened to pass
# through). This runner tests the native Godot game.
# Usage:  powershell -ExecutionPolicy Bypass -File native\run-tests.ps1 [-Exported] [-Quick]
#   -Exported  runs the same tests against dist\DOMINION.exe (the built game)
#   -Quick     skips the long ones (the 12-minute match and the AI war)
param([switch]$Exported, [switch]$Quick)
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $repo '.local-tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$exe = Join-Path $repo 'dist\DOMINION.exe'

$tests = @(
    @('customer playtest: replacement orders cancel boarding, water and safe unloading retain passengers', @('--script', 'res://tools/customer-airlift-check.gd'), 'CUSTOMER_AIRLIFT PASS', 180),
    @('customer windows: navigation at three sizes, UN notices, shortcuts and live aircraft animation', @('--script', 'res://tools/customer-window-check.gd'), 'CUSTOMER_WINDOW PASS', 240),
    @('action wording: button help across menus, weapon roles, production versus launch, blocking reasons and unchanged actions', @('--script', 'res://tools/action-copy-check.gd'), 'ACTION_COPY PASS', 180),
    @('UN session invitations, full conference screen, live ballots, eligibility, outcomes and save restore', @('--script', 'res://tools/un-session-check.gd'), 'UN_SESSION PASS', 180),
    @('fish and gold: clickable deposits, construction actions, coastal reach, food / treasury output and supply gating', @('--script', 'res://tools/resource-use-check.gd'), 'RESOURCE_USE PASS', 180),
    @('28 arsenal dossiers, evidence-backed operators, new support / artillery / air-defence roles, production, live combat and save round trip', @('--script', 'res://tools/arsenal-diversity-check.gd'), 'ARSENAL_DIVERSITY PASS', 600),
    @('tools of war: engineers and minefields, mine clearing, field recovery, decoys, counter-battery radar, coastal anti-ship, AEW, electronic attack, submarine hunters, carriers, saves', @('--script', 'res://tools/war-tools-check.gd'), 'WAR_TOOLS PASS', 600),
    @('strategic AI: who uses what, targeting, counter-drone, undersea sensing, surveillance, counter-disinformation, revenue, exports, the dead hand and its accidents, biosecurity, the second generation, saves, rivals and screens', @('--script', 'res://tools/ai-strategic-check.gd'), 'AI_STRATEGIC PASS', 600),
    @('practical AI: national evidence, research, validation, commissioning, compute budgets, live effects, diplomacy, rivals and saves', @('--script', 'res://tools/ai-applications-check.gd'), 'AI_APPLICATIONS PASS', 600),
    @('the six regional entities: national names, unit quality, Houthi missiles and launch sites, South Sudan helicopters, regime, plan, sanctions, treaties, generals', @('--script', 'res://tools/regional-entities-check.gd'), 'REGIONAL_ENTITIES PASS', 900),
    @('nation registry: one file per nation, saved order frozen, unique names, colours and portraits, every field present, columns match the registry', @('--script', 'res://tools/nation-registry-check.gd'), 'NATION_REGISTRY PASS', 120),
    @('regional leaders: PNG portraits, face crops, HUD badges and legacy authority labels', @('--script', 'res://tools/regional-portraits-check.gd'), 'REGIONAL_PORTRAITS PASS', 120),
    @('eras ask nothing abroad (no trade routes, no share of the land); the Testing tools switch, Cheats button, screen and actions', @('--script', 'res://tools/cheat-tools-check.gd'), 'CHEAT_TOOLS PASS', 600),
    @('six new regional identities, escrow contracts, national research, restricted arsenals and old indices', @('--script', 'res://tools/regional-factions-check.gd'), 'REGIONAL_FACTIONS PASS', 600),
    @('troop transports: the landing ship, troops walking to a ship and boarding it, landing from the coast and from open water, Land at, helicopters taking a crowd, losses and saves', @('--script', 'res://tools/transports-check.gd'), 'TRANSPORTS PASS', 900),
    @('balance: value for price of every armed unit, the corrections hold and apply once', @('--script', 'res://tools/balance-check.gd'), 'BALANCE PASS', 300),
    @('rival towns: compact, no gaps or lone arms after fourteen minutes of building', @('--script', 'res://tools/ai-city-check.gd'), 'AI_CITY PASS', 900),
    @('order marks: the flag where units were sent, one per group, green red amber, going when they arrive', @('--script', 'res://tools/order-marks-check.gd'), 'ORDER_MARKS PASS', 300),
    @('situation report: merged hits and losses, warnings only from intelligence, banner, window, unread count, battle report', @('--script', 'res://tools/sitrep-check.gd'), 'SITREP PASS', 300),
    @('national statistics: releases, exact own figures, estimates with an error that shrinks with intelligence, ranking, headline, tab, saves', @('--script', 'res://tools/stats-check.gd'), 'STATS PASS', 900),
    @('espionage teams: several agents on one operation and several operations on one nation, odds, cost, exposure, losses, recall and saves', @('--script', 'res://tools/espionage-teams-check.gd'), 'ESPIONAGE_TEAMS PASS', 300),
    @('rivals at sea: a war across water: shipyard on the coast, a fleet, landing ships loaded and escorted, troops put ashore, sorties', @('--script', 'res://tools/ai-navy-check.gd'), 'AI_NAVY PASS', 2700),
    @('sixteen points: sovereignty over harbours and offshore works, fishing platform, land gas and the cold winter, the research tree, demolish and replace, standing units, a spy by name, the UN agencies, the Veterans text, the birds', @('--script', 'res://tools/fixes-1019-check.gd'), 'FIXES_1019 PASS', 900),
    @('the report of 2026-10-20: a carrier stands off and its jets strike, a submarine offers only its own missiles, air-launched missiles from a parked jet, nuclear launches from the strategic complex, sanctions on the card, troops aboard shown, short briefs', @('--script', 'res://tools/fixes-1020-check.gd'), 'FIXES_1020 PASS', 600),
    @('alpha build: version and label, About, problem report, hidden testing tools, saves checked before loading, an earlier save loads', @('--script', 'res://tools/alpha-check.gd'), 'ALPHA PASS', 600),
    @('audit of every control: 80+ surfaces and tabs, every enabled button pressed (no error, no dead button without a reason)', @('--script', 'res://tools/audit-ui.gd'), 'AUDIT_UI PASS', 1500),
    @('audit of every unit: definition, class plausibility, training, nations, model, combat, friendly fire, orders', @('--script', 'res://tools/audit-units.gd'), 'AUDIT_UNITS PASS', 1500),
    @('audit of every building: definition, site, finish, what it provides, what it trains, demolish, save', @('--script', 'res://tools/audit-buildings.gd'), 'AUDIT_BUILDINGS PASS', 900),
    @('audit of every missile: launcher, launch, flight, effect, who may field it, the launcher message', @('--script', 'res://tools/audit-missiles.gd'), 'AUDIT_MISSILES PASS', 900),
    @('audit of every discovery: definition, tree walk, stated effects, effects seen in play, researched for real', @('--script', 'res://tools/audit-research.gd'), 'AUDIT_RESEARCH PASS', 900),
    @('audit of the world: 28 national powers, 16 espionage operations, UN measures, world events, crises, victory paths, diplomacy', @('--script', 'res://tools/audit-world.gd'), 'AUDIT_WORLD PASS', 1500),
    @('audit of every text: no years, British spelling, no leaked placeholders, lengths; 1,100 definitions and reasons and the scripts messages', @('--script', 'res://tools/audit-text.gd'), 'AUDIT_TEXT PASS', 900),
    @('vehicle models (glb): found by the nations own name, turret, wheels, muzzle, real size, gun lift and kick, track pads, wreck, the kit tank for nations without one', @('--script', 'res://tools/vehicle-model-check.gd'), 'VEHICLE_MODEL PASS', 300),
    @('filmed effects: every flipbook sheet loads, blasts on ground, air and sea, dust, looping wreck flames, frames run and end', @('--script', 'res://tools/fx-flipbook-check.gd'), 'FX_FLIPBOOK PASS', 300),
    @('the aircraft carrier: one reach (240 m) everywhere, the wing shown, strike in reach and not beyond, orders-only, recall, replacement for a lost aircraft, stand-off, saved wing', @('--script', 'res://tools/carrier-check.gd'), 'CARRIER PASS', 600),
    @('what can exist: buildings train what belongs, sites refused where they cannot stand, cargo, weapons vs targets, orders of class in the real world, orders the terrain forbids, a ten-minute soak with physical invariants', @('--script', 'res://tools/audit-physics.gd'), 'AUDIT_PHYSICS PASS', 1800),
    @('the attack order for every armed unit: it hurts the enemy in reach, and closes in or stands off by design when it is out of reach', @('--script', 'res://tools/audit-orders.gd'), 'AUDIT_ORDERS PASS', 1800),
    @('national crises: lost power, farms, homes and industry bring recession, blackouts, inflation, debt, default, protest, a fallen government, condemnation; GDP with no floor; the statistics overview', @('--script', 'res://tools/crisis-check.gd'), 'CRISIS PASS', 600),
    @('what each nation really has: no chip fab, data centre or reactor without that industry, no HIMARS or submarine for militias or landlocked states, compute goal asks universities instead', @('--script', 'res://tools/national-industry-check.gd'), 'NATIONAL_INDUSTRY PASS', 600),
    @('who can really use AI and the bomb: national AI ceilings, no nuclear release, tension or escalation threats without nuclear weapons', @('--script', 'res://tools/national-realism-check.gd'), 'NATIONAL_REALISM PASS', 900),
    @('the era ladder: what opens in each era, for you and rivals; research and era goals never blocked; Sandbox and old saves open', @('--script', 'res://tools/progression-check.gd'), 'PROGRESSION PASS', 600),
    @('the sea economic zone: rigs on sea fields, rival waters, fish and extractor hints, contractors, gas output', @('--script', 'res://tools/offshore-check.gd'), 'OFFSHORE PASS', 300),
    @('a living world: smoke, the seasons'' snow, birds, order rings, torn-cloud battle smoke, slim unit bars', @('--script', 'res://tools/life-check.gd'), 'LIFE PASS', 400),
    @('construction progress, travelling crew and waiting-worker feedback', @('--script', 'res://tools/construction-feedback-check.gd'), 'CONSTRUCTION_FEEDBACK: 22 checks, 0 failures', 300),
    @('floating resource markers, camera angles and current-click offshore placement', @('--script', 'res://tools/resource-marker-check.gd'), 'RESOURCE_MARKER: 39 checks, 0 failures', 300),
    @('report follow-up: unit roles, quieter resources, sealed pine crowns, guide actions, diplomacy feedback and adaptive music', @('--script', 'res://tools/report-polish-check.gd'), 'REPORT_POLISH PASS', 600),
    @('fourth settlement and continued play across 28 factions and all 24 maps', @('--script', 'res://tools/campaign-expansion-check.gd'), 'EXPANSION: 140 checks, 0 failures', 2400),
    @('decorative wrecks: dense piles, map limits, age, gradual cleanup and live-unit safety', @('--script', 'res://tools/wreck-cleanup-check.gd'), 'WRECK_CLEANUP PASS', 180),
    @('continue after victory or defeat: simulation, diplomacy, territory and saves', @('--script', 'res://tools/post-victory-check.gd'), 'POST_VICTORY PASS', 240),
    @('playtest fixes: Esc, Space pause, speed keys, the common opening, one notice per message, the beginner guide', @('--script', 'res://tools/ux-fixes-check.gd'), 'UX_FIXES PASS', 240),
    @('22 national rosters, new combat roles, aircraft service and save round trip', @('--script', 'res://tools/force-roster-check.gd'), 'FORCE_ROSTER PASS', 240),
    @('floating window input, queued alerts, resize, UI scaling and munition portraits', @('--script', 'res://tools/windows-portraits-check.gd'), 'WINDOWS_PORTRAITS PASS', 240),
    @('UN Council, Assembly, consent, humanitarian access, future members and saves', @('--script', 'res://tools/un-check.gd'), 'UN_CHECK PASS', 240),
    @('national arsenals, future programmes, payload launch platforms and new country metadata', @('--script', 'res://tools/arsenal-check.gd'), 'ARSENAL_CHECK PASS', 240),
    @('artificial intelligence: compute, data centres, AI levels, autonomy doctrine and incidents, seekers, fusion cell, AI cyber, rivals, saves', @('--script', 'res://tools/ai-check.gd'), 'AI_CHECK PASS', 600),
    @('artificial intelligence 2: AI economy and retraining, chip controls, smuggling and the shortage, AI analysis, influence, model theft, loyal wingmen, battle management, treaties', @('--script', 'res://tools/ai2-check.gd'), 'AI2_CHECK PASS', 600),
    @('artificial intelligence 3: automated early warning and false alarms, the AGI project, safety, runaway AI, the race, sabotage, the victory', @('--script', 'res://tools/ai3-check.gd'), 'AI3_CHECK PASS', 600),
    @('operational war costs: fuel, ammunition, interceptors, air sorties and saves', @('--script', 'res://tools/war-costs-check.gd'), 'WAR_COSTS PASS', 240),
    @('thirteen additional leader portraits: unique PNGs and face crops', @('--script', 'res://tools/additional-portraits-check.gd'), 'Additional portraits: 158 checks, 0 failures', 120),
    @('city, offshore, market and air defence upgrades', @('--script', 'res://tools/city-upgrade-check.gd'), 'CITY_UPGRADE_TEST PASS', 180),
    @('smoke', @('res://main.tscn', '--', '--smoke-test'), 'DESKTOP_SMOKE_PASS', 120),
    @('navigation', @('--', '--nav-test'), 'NAV_TEST PASS', 180),
    @('camera', @('--', '--camera-test'), 'CAMERA_TEST PASS', 180),
    @('movement physics', @('--', '--motion-test'), 'MOTION_TEST PASS', 180),
    @('battle dynamics', @('--', '--battle-test'), 'BATTLE_TEST PASS', 300),
    @('armoured column driving', @('--', '--convoy-test'), 'CONVOY_TEST PASS', 240),
    @('armour through city streets, workers finish sites', @('--', '--city-test'), 'CITY_TEST PASS', 400),
    @('shipyards on the coast launch warships; cancelling refunds', @('--script', 'res://tools/naval-check.gd'), 'NAVAL_TEST PASS', 240),
    @('the whole research tree can be completed', @('--script', 'res://tools/research-complete-check.gd'), 'RESEARCH_COMPLETE PASS', 300),
    @('air defence, artillery range, bunkers', @('--script', 'res://tools/combat-rules-check.gd'), 'COMBAT_RULES PASS', 240),
    @('idle troops answer a fight beside them, not one far off or while on the move', @('--script', 'res://tools/assist-check.gd'), 'ASSIST PASS', 400),
    @('the in-game menus: strip, screen buttons and keys, every tab, build list, selections, help, pause menu, Esc, double click', @('--script', 'res://tools/menus-check.gd'), 'MENUS PASS', 600),
    @('long marches round lakes and ridges, across the island', @('--script', 'res://tools/route-check.gd'), 'ROUTE_TEST PASS', 900),
    @('trade ships on every route at a merchant ship pace; shipping sabotage', @('--script', 'res://tools/trade-check.gd'), 'TRADE_TEST PASS', 240),
    @('modern warfare: drones, jamming, active protection, lasers, interception odds, ruins', @('--script', 'res://tools/modern-warfare-check.gd'), 'MODERN_WARFARE PASS', 600),
    @('about 100 checks on the modern units and each nation''s own weapons', @('--script', 'res://tools/units-100.gd'), 'UNITS_100 PASS', 1200),
    @('about 100 checks on the new weapons in live combat', @('--script', 'res://tools/weapons-live-100.gd'), 'WEAPONS_LIVE PASS', 2400),
    @('every nation strengths and weaknesses: economy, science, military, diplomacy', @('--script', 'res://tools/national-profile-check.gd'), 'NATIONAL_PROFILE PASS', 600),
    @('the newer factions weapons and every nation political power', @('--script', 'res://tools/faction-powers-check.gd'), 'FACTION_POWERS PASS', 900),
    @('ten additional nations: production, combat, powers, AI and persistence', @('--script', 'res://tools/additional-factions-check.gd'), 'ADDITIONAL_FACTIONS PASS', 900),
    @('additional nations: resource boundaries, interrupted powers, cargo and saved cooldowns', @('--script', 'res://tools/additional-factions-100.gd'), 'ADDITIONAL_FACTIONS_100 PASS', 300),
    @('about 100 checks playing on every map', @('--script', 'res://tools/gameplay-maps-100.gd'), 'GAMEPLAY_MAPS PASS', 7200),
    @('fifty checks on playing the game: placement, selection, commands, panels, workers, groups', @('--script', 'res://tools/gameplay-ui-50.gd'), 'GAMEPLAY_UI PASS', 1800),
    @('49 customer checks: reversible graphics, input, guide, layouts, save recovery and diplomacy', @('--script', 'res://tools/customer-review-49.gd'), 'CUSTOMER_REVIEW PASS', 300),
    @('100 second-round customer checks: modal input, end screens, research feedback, logs and national panels', @('--script', 'res://tools/customer-round2-100.gd'), 'CUSTOMER_ROUND2: 100 checks, 0 failures', 300),
    @('100 third-round customer checks: lapsing letters, war and quit confirmations, music, spelling, hover names, idle workers, damage tags, seasons, saves', @('--script', 'res://tools/customer-round3-100.gd'), 'CUSTOMER_ROUND3 PASS', 600),
    @('100 fourth-round customer checks: contextual orders, selection, hull hover, help, mute, defaults, research and campaign continuation', @('--script', 'res://tools/customer-round4-100.gd'), 'CUSTOMER_ROUND4: 100 checks, 0 failures', 600),
    @('Save Game preserves other campaigns, timestamp collisions and failed storage', @('--script', 'res://tools/campaign-save-check.gd'), 'CAMPAIGN_SAVE: 4 checks, 0 failures', 120),
    @('a third hundred gameplay checks: rivals on their own, match settings, missiles, spies, trade, bunkers, air bases, disk saves', @('--script', 'res://tools/gameplay-deep-100.gd'), 'GAMEPLAY_DEEP PASS', 2400),
    @('about 100 gameplay checks over time: economy, building, training, research, land, supply, war, trade, saves', @('--script', 'res://tools/gameplay-live-100.gd'), 'GAMEPLAY_LIVE PASS', 1800),
    @('about 100 gameplay checks: every building, unit, research, market, diplomacy, spies, missiles, land, roads, saves', @('--script', 'res://tools/gameplay-100.gd'), 'GAMEPLAY_100 PASS', 1500),
    @('nine factions: leaders, roster, doctrines and save identity', @('--script', 'res://tools/factions-check.gd'), 'FACTIONS_TEST PASS', 240),
    @('map picker: previews, capacities and campaign selection', @('--script', 'res://tools/map-picker-check.gd'), 'MAP_PICKER_TEST PASS', 180),
    @('5-10 map regions: space, resources, passages and reproducible seeds', @('--script', 'res://tools/map-capacity-check.gd'), 'MAP_CAPACITY_TEST PASS', 600),
    @('matches of two to nine nations, each rival at its own difficulty; the New Game picker', @('--script', 'res://tools/nations-setup-check.gd'), 'NATIONS_SETUP PASS', 2400),
    @('real-world maps: each nation at its real capital, the seas and mountains where they are on Earth', @('--script', 'res://tools/real-maps-check.gd'), 'REAL_MAPS PASS', 900),
    @('100 checks on the five newest maps: as generated and played at full count, their geography, rivals, saves', @('--script', 'res://tools/new-maps-100.gd'), 'NEW_MAPS PASS', 2400),
    @('choosing where each nation starts: regions, placement on every kind of map, the New Game pickers, saves', @('--script', 'res://tools/start-choice-check.gd'), 'START_CHOICE PASS', 900),
    @('100 more checks on choosing where each nation starts: every region of every map, rules, real capitals, the screen, matches', @('--script', 'res://tools/start-choice-100.gd'), 'START_CHOICE_100 PASS', 2400),
    @('the testing cheat: every era, all your research, money and stores; another nation''s technology stays theirs', @('--script', 'res://tools/cheat-check.gd'), 'CHEAT PASS', 900),
    @('Iraq, Syria and Afghanistan: what each fields, researches and builds, their powers and units, the rivals', @('--script', 'res://tools/three-nations-check.gd'), 'THREE_NATIONS PASS', 1500),
    @('every map loads: capitals linked by land, resources, ships at sea', @('--script', 'res://tools/maps-check.gd'), 'MAPS_TEST PASS', 1500),
    @('thirty checks on a nine-nation match: wars, a march across Pangaea, treaties, spies, missiles, saves, victory', @('--script', 'res://tools/gameplay-nine-30.gd'), 'GAMEPLAY_NINE PASS', 1200),
    @('every nation fields only its own technology (2025-26), rivals too', @('--script', 'res://tools/nation-tech-check.gd'), 'NATION_TECH PASS', 900),
    @('cars, lorries and trains on roads and railways', @('--script', 'res://tools/road-traffic-check.gd'), 'ROAD_TRAFFIC PASS', 400),
    @('performance budgets: loading, steps, AI, routes, battle, saves, memory', @('--script', 'res://tools/performance-check.gd'), 'PERFORMANCE PASS', 900),
    @('a hundred checks: each of the nine nations played, and a six-nation Pangaea match', @('--script', 'res://tools/gameplay-nations-100.gd'), 'GAMEPLAY_NATIONS PASS', 3000),
    @('a hundred more: every map at full strength, and air, sea, missiles, supply, people, market, spies, alliances, repairs, defeat', @('--script', 'res://tools/gameplay-campaign-100.gd'), 'GAMEPLAY_CAMPAIGN PASS', 5000),
    @('the match pace slows the whole world together; the camera keeps its speed', @('--script', 'res://tools/pace-check.gd'), 'PACE PASS', 240),
    @('the New Game sheet offers every map its full count of rivals', @('--', '--setup-test'), 'SETUP_TEST PASS', 240),
    @('thirty bug hunts: twice, dead, out of bounds, no money, nonsense input, old saves', @('--script', 'res://tools/bugs-30.gd'), 'BUGS_30 PASS', 300),
    @('exact production refunds and saved live missiles, sanctions, EMP and defence cooldowns', @('--script', 'res://tools/gameplay-state-audit.gd'), 'GAMEPLAY_STATE_AUDIT PASS', 300),
    @('settings are saved and restored', @('--script', 'res://tools/settings-check.gd'), 'SETTINGS_TEST PASS', 180),
    @('edge, coastal and hemmed-in sites get built; shipyard counts for research', @('--script', 'res://tools/edge-build-check.gd'), 'EDGE_BUILD PASS', 400),
    @('towns: land from residents, city accounts, roads between town halls, overland trade', @('--script', 'res://tools/towns-check.gd'), 'TOWNS_TEST PASS', 400),
    @('borders, passage and operational zones', @('--', '--border-test'), 'BORDER_TEST PASS', 400),
    @('clearing trees and resources for a building', @('--', '--site-test'), 'SITE_TEST PASS', 200),
    @('clicking any part of a unit selects it', @('--', '--pick-test'), 'PICK_TEST PASS', 200),
    @('land: build in your territory, buy unclaimed land, territorial waters', @('--', '--land-test'), 'LAND_TEST PASS', 200),
    @('ships sail round the island', @('--', '--sea-test'), 'SEA_TEST PASS', 600),
    @('state: far production, market, AI builds an economy', @('--', '--state-test'), 'STATE_TEST PASS', 400),
    @('airfield slots, landing and takeoff', @('--', '--airbase-test'), 'AIRBASE_TEST PASS', 240),
    @('firm diplomacy: protest, warnings, ultimatums', @('--script', 'res://tools/firm-diplomacy-check.gd'), 'FIRM_DIPLOMACY PASS', 180),
    @('a hundred economy checks: stores, citizens, food, taxes, mines, market, trade routes, rivals, army cost, buildings, towns, saves', @('--script', 'res://tools/economy-100.gd'), 'ECONOMY_100 PASS', 900),
    @('economy', @('--', '--economy-test'), 'ECONOMY_TEST PASS', 240),
    @('combat (every weapon)', @('--', '--combat-test'), 'COMBAT_TEST PASS', 400),
    @('combat fixes and aircraft service', @('--', '--combat-regression'), 'COMBAT_REGRESSION PASS', 180),
    @('naval recovery, repairs and diplomacy', @('--', '--polish-test'), 'POLISH_TEST PASS', 180),
    @('campaign maps, players and leaders', @('--', '--campaign-test'), 'CAMPAIGN_TEST PASS', 180),
    @('new campaign and map reload flow', @('--script', 'res://tools/campaign-flow-check.gd'), 'CAMPAIGN FLOW PASS', 180),
    @('air and sea', @('--', '--air-sea-test'), 'AIR_SEA_TEST PASS', 240),
    @('a hundred diplomacy checks: war and peace, treaties, letters, leader contacts, firm language, operations, passage', @('--script', 'res://tools/diplomacy-100.gd'), 'DIPLOMACY_100 PASS', 900),
    @('diplomacy', @('--', '--diplomacy-test'), 'DIPLOMACY_TEST PASS', 180),
    @('leader contacts, negotiations and exports', @('--script', 'res://tools/diplomatic-contacts-check.gd'), 'DIPLOMATIC_CONTACTS_TEST PASS', 180),
    @('supply network', @('--', '--logistics-test'), 'LOGISTICS_TEST PASS', 240),
    @('market, spies, missiles, territory', @('--', '--systems-test'), 'SYSTEMS_TEST PASS', 300),
    @('a hundred intelligence checks: agents, odds, every operation, capture, exposure, warnings, rival services, effects in play, saves', @('--script', 'res://tools/intel-100.gd'), 'INTEL_100 PASS', 900),
    @('intelligence lifecycle', @('--script', 'res://tools/espionage-check.gd'), 'ESPIONAGE_TEST PASS', 180),
    @('a hundred research checks: queue, stages, rate, eras, tracks, every discovery in play, rival research, saves, the tree', @('--script', 'res://tools/research-100.gd'), 'RESEARCH_100 PASS', 900),
    @('research', @('--', '--research-test'), 'RESEARCH_TEST PASS', 300),
    @('interface (every screen and button)', @('--', '--ui-test'), 'UI_TEST PASS', 300),
    @('save and load', @('--', '--save-test'), 'SAVE_TEST PASS', 240),
    @('menus', @('--', '--menu-test'), 'MENU_TEST PASS', 180)
)
if (-not $Quick) {
    $tests += ,@('audit of nations and maps: every nation and every map played for two minutes, saved and checked', @('--script', 'res://tools/audit-matrix.gd', '--', '--budget=3000'), 'AUDIT_MATRIX PASS', 3600)
    $tests += ,@('AI war (hard, fast)', @('--', '--ai-test'), 'AI_TEST PASS', 500)
    $tests += ,@('12-minute match (hard)', @('--', '--soak-test'), 'SOAK_TEST PASS', 600)
    $tests += ,@('12 minutes played as a player: nothing stuck', @('--script', 'res://tools/playthrough-check.gd'), 'PLAYTHROUGH PASS', 2400)
}

$results = @()
$runId = [guid]::NewGuid().ToString('N')
foreach ($t in $tests) {
    $name, $testArgs, $pass, $limit = $t
    if ($Exported -and ($testArgs[0] -like 'res://*' -or $testArgs[0] -eq '--script')) { continue }  # alternate scenes and tools are not part of the release
    if ($Exported) { $runner = $exe; $argsList = @('--headless') }
    else { $runner = $godot; $argsList = @('--headless', '--path', ('"{0}"' -f (Join-Path $PSScriptRoot 'godot'))) }
    $argsList += $testArgs
    $out = Join-Path $env:TEMP "dominion-test-$runId.log"
    $start = Get-Date
    $p = Start-Process -FilePath $runner -ArgumentList $argsList -RedirectStandardOutput $out -RedirectStandardError "$out.err" -PassThru -NoNewWindow
    $null = $p.Handle  # without this PowerShell leaves ExitCode empty after a timed wait
    if (-not $p.WaitForExit($limit * 1000)) { $p.Kill(); $status = 'TIMEOUT' }
    else {
        $log = (Get-Content $out -Raw) + (Get-Content "$out.err" -Raw)
        $errors = ([regex]::Matches($log, 'SCRIPT ERROR')).Count
        if ($p.ExitCode -ne 0 -or $log -match '\bFAIL\b' -or $log -notmatch [regex]::Escape($pass)) { $status = 'FAIL' }
        elseif ($errors -gt 0) { $status = "FAIL ($errors script errors)" }
        else { $status = 'PASS' }
    }
    $seconds = [int]((Get-Date) - $start).TotalSeconds
    $results += [pscustomobject]@{ Test = $name; Result = $status; Seconds = $seconds }
    '{0,-40} {1,-22} {2,4}s' -f $name, $status, $seconds
}
$failed = @($results | Where-Object { $_.Result -ne 'PASS' })
''
if ($failed.Count -eq 0) { "ALL $($results.Count) TEST SUITES PASSED" } else { "$($failed.Count) OF $($results.Count) FAILED: $(($failed | ForEach-Object Test) -join ', ')" }
exit $failed.Count
