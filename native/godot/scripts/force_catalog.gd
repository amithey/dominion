extends RefCounted
const Diversity := preload("res://scripts/arsenal_diversity_data.gd")
## Representative operator rosters, not inventories or weapon specifications.
## Evidence, limitations and additions deferred for research are in
## native/FORCE-ROSTER-RESEARCH-2026-10-06.md. All figures below are game balance.
static var IDS: Array = preload("res://scripts/nation_registry.gd").column("id")
const BASE := {"combatUGV": "apc", "logisticsUGV": "apc", "robotDog": "apc", "heavyBomberDrone": "drone", "heavyLift": "helicopter", "navalHelicopter": "helicopter", "mineLayer": "apc", "mineClearer": "tank", "recoveryVehicle": "tank", "decoy": "tank", "counterBatteryRadar": "ewVehicle", "coastalASM": "mlrs", "aewc": "jet", "ewJet": "jet", "maritimePatrol": "jet", "carrier": "destroyer", "asFrigate": "corvette", "landingShip": "corvette", "recoillessTeam": "rocketSoldier", "wheeledHowitzer": "artillery", "shortRangeSAM": "samLauncher", "machineGunTeam": "soldier", "mortarTeam": "artillery", "scoutTeam": "commando", "ifv": "apc", "heavyAPC": "tank", "reconVehicle": "apc", "directFire": "tank", "towedHowitzer": "artillery", "attackJet": "jet", "lightFighter": "jet", "scoutHelicopter": "helicopter", "missileBoat": "corvette"}
const HOME := {"combatUGV": "tankFactory", "logisticsUGV": "tankFactory", "robotDog": "barracks", "heavyBomberDrone": "airfield", "heavyLift": "helipad", "navalHelicopter": "helipad", "mineLayer": "tankFactory", "mineClearer": "tankFactory", "recoveryVehicle": "tankFactory", "decoy": "barracks", "counterBatteryRadar": "tankFactory", "coastalASM": "tankFactory", "aewc": "airfield", "ewJet": "airfield", "maritimePatrol": "airfield", "carrier": "shipyard", "asFrigate": "shipyard", "landingShip": "shipyard", "recoillessTeam": "barracks", "wheeledHowitzer": "tankFactory", "shortRangeSAM": "tankFactory", "machineGunTeam": "barracks", "mortarTeam": "barracks", "scoutTeam": "barracks", "ifv": "tankFactory", "heavyAPC": "tankFactory", "reconVehicle": "tankFactory", "directFire": "tankFactory", "towedHowitzer": "tankFactory", "attackJet": "airfield", "lightFighter": "airfield", "scoutHelicopter": "helipad", "missileBoat": "shipyard"}
const INFANTRY := ["machineGunTeam", "mortarTeam", "scoutTeam", "recoillessTeam"]
const SCOUTS := ["scoutTeam", "reconVehicle", "scoutHelicopter"]
const SIGHT := {"navalHelicopter": 56.0, "aewc": 60.0, "counterBatteryRadar": 46.0, "maritimePatrol": 70.0, "carrier": 70.0, "scoutTeam": 72.0, "reconVehicle": 84.0, "scoutHelicopter": 100.0, "ifv": 44.0, "heavyAPC": 38.0, "directFire": 52.0, "missileBoat": 52.0}
const INDIRECT := ["mortarTeam", "towedHowitzer", "wheeledHowitzer"]
const ROLES := {
	# The tools of war beyond the fighting units: war_tools.gd and native/WAR-TOOLS-RESEARCH-2026-10-12.md.
	"mineLayer": {"name": "Engineer Minelayer", "hp": 260, "dmg": 8, "range": 20, "cooldown": 0.8, "aggro": 24, "speed": 5.0, "cost": {"money": 420, "iron": 30, "oil": 12}, "trainTime": 18, "pop": 2, "requires": "advancedLogistics", "desc": "Halt it for a few seconds and it lays an anti-vehicle minefield where it stands (up to twelve fields a nation). Enemy vehicles that drive in are struck; infantry is not. The enemy cannot see your fields; you see them as a faint disc."},
	"mineClearer": {"name": "Mine-clearing Vehicle", "hp": 420, "dmg": 40, "range": 30, "cooldown": 12.0, "aggro": 32, "speed": 4.6, "cost": {"money": 520, "iron": 45, "oil": 18}, "trainTime": 22, "pop": 2, "requires": "compositeArmor", "desc": "Its rocket-towed line charge clears enemy minefields near it in a few seconds, and reveals them. The same charge is a crude weapon against infantry and buildings."},
	"recoveryVehicle": {"name": "Armoured Recovery Vehicle", "hp": 520, "dmg": 6, "range": 18, "cooldown": 0.8, "aggro": 20, "speed": 4.8, "cost": {"money": 480, "iron": 45, "oil": 16}, "trainTime": 20, "pop": 2, "requires": "advancedLogistics", "desc": "Repairs the most damaged friendly vehicle near it, steadily, in the field. Keep it behind the armour it serves; it barely fights."},
	"decoy": {"name": "Decoy Team", "hp": 160, "dmg": 0, "range": 0, "cooldown": 1.0, "aggro": 0, "speed": 3.5, "cost": {"money": 90, "iron": 6}, "trainTime": 6, "pop": 1, "desc": "An inflatable or wooden copy of a weapon, set up in minutes. It has no weapon: it draws fire, shells and loitering munitions from the real thing at a fraction of the price."},
	"counterBatteryRadar": {"name": "Counter-battery Radar", "hp": 200, "dmg": 0, "range": 0, "cooldown": 1.0, "aggro": 0, "speed": 5.2, "cost": {"money": 650, "iron": 25, "oil": 12, "silicon": 45}, "trainTime": 24, "pop": 2, "requires": "electronicWarfare", "desc": "Tracks shells and rockets back to the guns that fired them: enemy artillery and rocket launchers within its reach are revealed, and your fire on them hits a quarter harder. Unarmed, and a prized target."},
	"coastalASM": {"name": "Coastal Anti-ship Battery", "hp": 260, "dmg": 120, "range": 80, "cooldown": 9.0, "aggro": 80, "speed": 4.8, "cost": {"money": 900, "iron": 40, "oil": 20, "silicon": 40}, "trainTime": 28, "pop": 3, "requires": "guidedMunitions", "desc": "Truck-mounted anti-ship missiles that strike warships far out to sea from the shore. It cannot engage anything on land or in the air."},
	"aewc": {"name": "Airborne Early Warning Aircraft", "hp": 260, "dmg": 0, "range": 0, "cooldown": 1.0, "aggro": 0, "speed": 24, "cost": {"money": 1100, "iron": 40, "oil": 50, "silicon": 60}, "trainTime": 32, "pop": 3, "requires": "electronicWarfare", "fly": true, "naval": false, "desc": "A flying radar: while airborne it reveals enemy aircraft and ships far around it, and your aircraft under its picture hit harder. Unarmed; escort it."},
	"ewJet": {"name": "Electronic Attack Aircraft", "hp": 220, "dmg": 30, "range": 30, "cooldown": 4.0, "aggro": 34, "speed": 33, "cost": {"money": 1000, "iron": 45, "oil": 45, "silicon": 50}, "trainTime": 30, "pop": 3, "requires": "electronicWarfare", "fly": true, "naval": false, "desc": "Jams and deceives radars: enemy air defences near it lose much of their aim, so your strike aircraft get through. Carries anti-radiation missiles for a light attack."},
	"maritimePatrol": {"name": "Maritime Patrol Aircraft", "hp": 300, "dmg": 70, "range": 30, "cooldown": 6.0, "aggro": 40, "speed": 26, "cost": {"money": 950, "iron": 45, "oil": 55, "silicon": 35}, "trainTime": 30, "pop": 3, "requires": "jetPropulsion", "fly": true, "naval": false, "desc": "Hunts submarines with sonobuoys and torpedoes: reveals enemy submarines near it and strikes them hard; also attacks surface ships. It cannot engage targets on land."},
	"carrier": {"name": "Aircraft Carrier", "hp": 2400, "dmg": 18, "range": 24, "cooldown": 1.5, "aggro": 30, "speed": 12, "cost": {"money": 4200, "iron": 260, "oil": 150, "silicon": 90}, "trainTime": 90, "pop": 8, "requires": "navalEngineering", "fly": false, "naval": true, "desc": "A flagship that carries its air wing: the aircraft on its deck take off against any enemy within 240 m (the blue ring), strike, fly back and rearm aboard. Right-click an enemy in reach to send the wing at it; a lost aircraft is replaced for $400. Its own guns and missiles only defend it. It cannot hunt submarines, so give it escorts."},
	# Drones and robots entering armies (native/DRONES-ROBOTS-RESEARCH-2026-10-12.md). A robot lost is no soldier lost.
	"combatUGV": {"name": "Armed Ground Robot", "hp": 180, "dmg": 14, "range": 26, "cooldown": 0.5, "aggro": 30, "speed": 4.5, "cost": {"money": 260, "iron": 16, "silicon": 10}, "trainTime": 12, "pop": 1, "requires": "microchips", "desc": "A remote-controlled tracked robot with a heavy machine gun: it holds a position or leads an assault with no one inside. Its loss costs no war support. A human operator fires it."},
	"logisticsUGV": {"name": "Logistics Robot", "hp": 160, "dmg": 0, "range": 0, "cooldown": 1.0, "aggro": 0, "speed": 4.2, "cost": {"money": 200, "iron": 14, "silicon": 6}, "trainTime": 10, "pop": 1, "requires": "microchips", "desc": "Carries ammunition forward and the wounded back, where drones make it deadly for crews: infantry near it recover faster. Unarmed; its loss costs no war support."},
	"robotDog": {"name": "Armed Robot Dog", "hp": 90, "dmg": 12, "range": 20, "cooldown": 1.2, "aggro": 24, "speed": 6.0, "cost": {"money": 180, "iron": 8, "silicon": 12}, "trainTime": 9, "pop": 1, "requires": "microchips", "desc": "A four-legged robot with a rifle on its back, for scouting and street fighting ahead of troops. Light and fragile; its loss costs no war support."},
	"heavyBomberDrone": {"name": "Heavy Bomber Drone", "hp": 70, "dmg": 45, "range": 9, "cooldown": 6.0, "aggro": 30, "speed": 13, "cost": {"money": 320, "iron": 12, "silicon": 14}, "trainTime": 14, "pop": 1, "requires": "microchips", "fly": true, "naval": false, "desc": "A large hexacopter that loiters low over the front, mostly at night, dropping bombs and mines. Slow and noisy: guns and drones bring it down. Launched from an airfield, it stays aloft until it is lost."},
	"heavyLift": {"name": "Heavy-lift Helicopter", "hp": 420, "dmg": 6, "range": 14, "cooldown": 0.6, "aggro": 16, "speed": 21, "cost": {"money": 900, "iron": 45, "oil": 45, "silicon": 20}, "trainTime": 30, "pop": 3, "requires": "jetPropulsion", "fly": true, "naval": false, "desc": "Carries twelve soldiers, or light vehicles and towed guns (six places each); door guns only. Select troops and right-click it to board; select it and press J to land them on dry ground. Those aboard are lost with it."},
	"navalHelicopter": {"name": "Naval Helicopter", "hp": 240, "dmg": 60, "range": 26, "cooldown": 5.0, "aggro": 38, "speed": 23, "cost": {"money": 760, "iron": 30, "oil": 35, "silicon": 30}, "trainTime": 25, "pop": 2, "requires": "jetPropulsion", "fly": true, "naval": false, "desc": "A ship's helicopter: dipping sonar and torpedoes hunt submarines (found near it, struck hard), and light anti-ship missiles. It cannot engage targets on land."},
	"asFrigate": {"name": "Anti-submarine Frigate", "hp": 640, "dmg": 55, "range": 34, "cooldown": 3.5, "aggro": 40, "speed": 20, "cost": {"money": 1250, "iron": 90, "oil": 50, "silicon": 30}, "trainTime": 45, "pop": 4, "requires": "guidedMunitions", "fly": false, "naval": true, "desc": "An escort built to hunt submarines: towed sonar, a helicopter and torpedoes strike submarines hard. Also carries anti-ship and air-defence missiles."},
	"landingShip": {"name": "Amphibious Landing Ship", "hp": 1300, "dmg": 14, "range": 24, "cooldown": 2.0, "aggro": 28, "speed": 11, "cost": {"money": 1900, "iron": 130, "oil": 70, "silicon": 20}, "trainTime": 55, "pop": 5, "requires": "navalEngineering", "fly": false, "naval": true, "desc": "Carries an invasion across the sea: 36 places, one for a soldier or an engineer and two to six for a vehicle by its size. Select troops and right-click the ship to load them (they walk to the shore beside it). Unload (J) puts them ashore on the nearest coast; Land at sends the ship to a beach you choose. Armed only for self-defence; those aboard are lost if it sinks, so give it escorts."},
	"recoillessTeam": {"name": "Recoilless Support Team", "hp": 95, "dmg": 35, "range": 24, "cooldown": 4.0, "aggro": 28, "speed": 4.0, "cost": {"money": 210, "iron": 12}, "trainTime": 12, "pop": 2, "desc": "Cheap unguided direct fire against light vehicles and fortifications. Shorter reach and less anti-tank power than an ATGM. Exposed crew; cannot engage aircraft or warships. Ammunition selection is abstracted."},
	"wheeledHowitzer": {"name": "Wheeled Self-propelled Howitzer", "hp": 240, "dmg": 62, "range": 88, "cooldown": 6.5, "aggro": 88, "speed": 6.2, "cost": {"money": 610, "iron": 42, "oil": 24}, "trainTime": 25, "pop": 3, "requires": "advancedLogistics", "desc": "Long-range conventional gun support with fast relocation and light protection. Same reach as established artillery; costs more than a towed gun. Needs a spotter beyond its sight. Use Bombard for area fire; cannot engage aircraft."},
	"shortRangeSAM": {"name": "Short-range Air Defence", "hp": 280, "dmg": 36, "range": 44, "cooldown": 2.8, "aggro": 52, "speed": 5.8, "cost": {"money": 570, "iron": 30, "oil": 18, "silicon": 28}, "trainTime": 23, "pop": 3, "requires": "guidedMunitions", "desc": "Mobile local air defence against aircraft and UAV units. Shorter reach and lower cost than the long-range SAM. Cannot attack ground targets, bombard or intercept strategic missile events. Gun and missile combinations are abstracted into one anti-aircraft shot."},
	"machineGunTeam": {"name": "Machine-gun Team", "hp": 110, "dmg": 9, "range": 26, "cooldown": 0.4, "aggro": 30, "speed": 4.3, "cost": {"money": 170, "iron": 8}, "trainTime": 10, "pop": 2, "desc": "Sustained fire against infantry and exposed light vehicles. Cannot engage aircraft, warships or heavy armour. Slower than rifle infantry."},
	"mortarTeam": {"name": "Mortar Team", "hp": 85, "dmg": 28, "range": 54, "cooldown": 4.8, "aggro": 54, "speed": 3.6, "cost": {"money": 230, "iron": 12}, "trainTime": 14, "pop": 2, "desc": "Portable indirect fire against infantry concentrations. Needs a spotter beyond its own sight; weak against armour and vulnerable in close combat. Bombard can target a location."},
	"scoutTeam": {"name": "Reconnaissance Patrol", "hp": 80, "dmg": 6, "range": 16, "cooldown": 1.2, "aggro": 24, "speed": 6.5, "cost": {"money": 140, "iron": 4}, "trainTime": 9, "pop": 1, "desc": "Fast infantry scouts with extended vision. Reveal targets for indirect fire and warn of an advance; light weapons and little protection."},
	"ifv": {"name": "Infantry Fighting Vehicle", "hp": 380, "dmg": 24, "range": 31, "cooldown": 1.2, "aggro": 38, "speed": 5.4, "cost": {"money": 530, "iron": 44, "oil": 18}, "trainTime": 21, "pop": 3, "requires": "compositeArmor", "desc": "Armoured infantry fire support. Rapid cannon fire is strongest against infantry and light vehicles; less protection and anti-tank power than an MBT. Passenger transport is not modelled."},
	"heavyAPC": {"name": "Heavy Armoured Carrier", "hp": 850, "dmg": 12, "range": 23, "cooldown": 0.75, "aggro": 30, "speed": 3.8, "cost": {"money": 690, "iron": 68, "oil": 22}, "trainTime": 27, "pop": 3, "requires": "compositeArmor", "desc": "Heavy protection for an infantry escort. Machine-gun armament suppresses infantry; cannot duel tanks. Passenger transport is not modelled."},
	"reconVehicle": {"name": "Reconnaissance Vehicle", "hp": 210, "dmg": 11, "range": 24, "cooldown": 0.8, "aggro": 32, "speed": 7.6, "cost": {"money": 330, "iron": 25, "oil": 12, "silicon": 8}, "trainTime": 16, "pop": 2, "requires": "advancedLogistics", "desc": "Mobile reconnaissance with extended vision. Finds targets for artillery and scouts flanks; trades armour and firepower for speed."},
	"directFire": {"name": "Mobile Direct-fire Gun", "hp": 370, "dmg": 68, "range": 36, "cooldown": 3.5, "aggro": 42, "speed": 6.1, "cost": {"money": 570, "iron": 45, "oil": 22}, "trainTime": 23, "pop": 3, "requires": "compositeArmor", "desc": "Mobile cannon support: a wheeled gun vehicle or medium tank according to the national system. Good against vehicles and fortifications, with less protection than an MBT."},
	"towedHowitzer": {"name": "Towed Howitzer", "hp": 160, "dmg": 62, "range": 88, "cooldown": 6.5, "aggro": 88, "speed": 2.3, "cost": {"money": 390, "iron": 30}, "trainTime": 19, "pop": 3, "requires": "advancedLogistics", "desc": "Low-cost long-range indirect fire with slow relocation and exposed crews. Needs reconnaissance beyond its own sight. Bombard can target a location. Towing is abstracted into movement speed."},
	"attackJet": {"name": "Ground-attack Aircraft", "hp": 250, "dmg": 68, "range": 24, "cooldown": 3.0, "aggro": 36, "speed": 27, "cost": {"money": 840, "iron": 48, "oil": 45, "silicon": 22}, "trainTime": 27, "pop": 3, "requires": "jetPropulsion", "fly": true, "naval": false, "desc": "Close air support against armour, infantry and buildings. Four firing passes, then returns to an airfield. Cannot dogfight; needs fighter escort against enemy aircraft."},
	"lightFighter": {"name": "Light Multirole Fighter", "hp": 200, "dmg": 42, "range": 31, "cooldown": 2.6, "aggro": 44, "speed": 36, "cost": {"money": 720, "iron": 38, "oil": 38, "silicon": 25}, "trainTime": 23, "pop": 2, "requires": "jetPropulsion", "fly": true, "naval": false, "desc": "Affordable multirole fighter with air-to-air priority and a limited ground attack load. Three firing passes per sortie; shares airfield parking with heavier aircraft."},
	"scoutHelicopter": {"name": "Reconnaissance Helicopter", "hp": 150, "dmg": 0, "range": 0, "cooldown": 1.0, "aggro": 0, "speed": 25, "cost": {"money": 420, "iron": 24, "oil": 20, "silicon": 14}, "trainTime": 20, "pop": 2, "requires": "jetPropulsion", "fly": true, "naval": false, "desc": "An unarmed reconnaissance sortie with extended vision for ground forces. Uses helipad parking and returns for fuel. Weapons on armed national variants are not represented in this reconnaissance role."},
	"missileBoat": {"name": "Fast Missile Boat", "hp": 310, "dmg": 72, "range": 54, "cooldown": 6.0, "aggro": 60, "speed": 22, "cost": {"money": 650, "iron": 48, "oil": 28, "silicon": 16}, "trainTime": 25, "pop": 3, "requires": "guidedMunitions", "fly": false, "naval": true, "desc": "Fast coastal missile combatant. Strong against surface ships, lightly protected and unable to engage aircraft or submarines. Can launch this nation's available conventional anti-ship missiles."},
}
## National models are separate options alongside the existing tank/APC/fighter.
## Generic infantry labels intentionally avoid guessing an undocumented model.
const NAMES := {
	"mineLayer": {"russia": "ISDM Zemledelie", "ukraine": "GMZ-3", "usa": "M139 Volcano", "germany": "Skorpion Mine Dispenser"},
	"mineClearer": {"russia": "UR-77 Meteorit", "ukraine": "UR-77 Meteorit", "usa": "M1150 Assault Breacher", "uk": "Trojan AVRE", "germany": "Keiler"},
	"recoveryVehicle": {"usa": "M88A2 Hercules", "russia": "BREM-1", "ukraine": "BREM-1", "germany": "Bergepanzer 3 Buffel", "uk": "Challenger ARRV", "india": "WZT-3", "south_korea": "K1 ARV", "japan": "Type 90 ARV"},
	"decoy": {"russia": "Inflatable Decoys", "ukraine": "Decoy HIMARS and Tanks"},
	"counterBatteryRadar": {"usa": "AN/TPQ-53", "russia": "Zoopark-1M", "ukraine": "COBRA / AN/TPQ-37", "germany": "COBRA", "india": "Swathi WLR", "pakistan": "SLC-2", "china": "SLC-2"},
	"coastalASM": {"russia": "K-300P Bastion-P", "ukraine": "RK-360MC Neptune", "japan": "Type 12 SSM", "usa": "NMESIS", "germany": "NSM Coastal Defence System", "china": "YJ-62 Coastal Battery", "iran": "Ghader Coastal Battery"},
	"aewc": {"usa": "E-3G Sentry", "china": "KJ-500", "russia": "A-50U", "india": "Netra AEW&C", "japan": "E-767", "uk": "E-7 Wedgetail AEW1", "australia": "E-7A Wedgetail", "turkiye": "E-7T Peace Eagle", "south_korea": "E-7 Peace Eye", "saudi": "E-3A Sentry", "pakistan": "Saab 2000 Erieye", "israel": "G550 Eitam", "brazil": "E-99", "egypt": "E-2C Hawkeye"},
	"ewJet": {"usa": "EA-18G Growler", "australia": "EA-18G Growler", "china": "J-16D", "germany": "Tornado ECR"},
	"maritimePatrol": {"usa": "P-8A Poseidon", "uk": "Poseidon MRA1", "australia": "P-8A Poseidon", "india": "P-8I Neptune", "south_korea": "P-8A Poseidon", "japan": "Kawasaki P-1", "china": "Y-8Q", "russia": "Il-38N", "germany": "P-8A Poseidon", "turkiye": "P-72", "pakistan": "P-3C Orion", "brazil": "P-3AM Orion", "indonesia": "CN-235 MPA"},
	"carrier": {"usa": "Gerald R. Ford-class", "china": "Fujian", "uk": "Queen Elizabeth-class", "india": "INS Vikrant", "japan": "Kaga (F-35B)", "turkiye": "TCG Anadolu (drone carrier)", "iran": "Shahid Bagheri (drone carrier)"},
	"combatUGV": {"ukraine": "Droid TW 12.7", "russia": "Uran-9", "germany": "THeMIS (armed)", "uk": "THeMIS", "israel": "Jaguar UGV", "china": "Sharp Claw"},
	"logisticsUGV": {"ukraine": "Termit / Gimli", "russia": "Kurier", "usa": "S-MET", "germany": "THeMIS Cargo", "uk": "THeMIS Cargo"},
	"robotDog": {"china": "Armed robot dog"},
	"heavyBomberDrone": {"ukraine": "Vampire (Baba Yaga)", "russia": "Heavy hexacopter"},
	"heavyLift": {"usa": "CH-47F Chinook", "uk": "Chinook HC6", "india": "CH-47F(I) Chinook", "japan": "CH-47JA Chinook", "south_korea": "CH-47D Chinook", "australia": "CH-47F Chinook", "germany": "CH-47F Chinook", "turkiye": "CH-47F Chinook", "egypt": "CH-47D Chinook", "russia": "Mi-26", "china": "Z-8L"},
	"navalHelicopter": {"usa": "MH-60R Seahawk", "australia": "MH-60R Seahawk", "india": "MH-60R Seahawk", "south_korea": "MH-60R Seahawk", "saudi": "MH-60R Seahawk", "germany": "NH90 Sea Lion", "uk": "Wildcat HMA2", "japan": "SH-60K", "russia": "Ka-27PL", "china": "Z-20F", "turkiye": "S-70B Seahawk", "egypt": "SH-2G Super Seasprite", "indonesia": "AS565 Panther"},
	"asFrigate": {"china": "Type 054A", "germany": "F125-class", "uk": "Type 23", "russia": "Admiral Gorshkov-class", "india": "Talwar-class", "japan": "Mogami-class", "turkiye": "Istanbul-class", "south_korea": "Daegu-class", "egypt": "FREMM (Tahya Misr)", "pakistan": "Tughril-class", "indonesia": "Martadinata-class", "australia": "Anzac-class", "brazil": "Niteroi-class", "saudi": "Al Riyadh-class", "iran": "Moudge-class"},
	"landingShip": {"usa": "San Antonio-class", "china": "Type 071", "uk": "Albion-class", "russia": "Ivan Gren-class", "india": "INS Jalashwa", "japan": "Osumi-class", "south_korea": "Dokdo-class", "turkiye": "Bayraktar-class", "indonesia": "Makassar-class", "egypt": "Mistral-class", "australia": "Canberra-class", "brazil": "Bahia", "iran": "Hengam-class"},
	"machineGunTeam": {"usa": "M240B Team", "germany": "MG5 Team", "uk": "L7 GPMG Team", "indonesia": "SM2 Team", "pakistan": "MG3 Team"},
	"mortarTeam": {"usa": "M224A1 Mortar Team", "uk": "L16 Mortar Team", "australia": "F2 81mm Mortar Team"},
	"scoutTeam": {},
	"ifv": {"usa": "M2A4 Bradley", "china": "ZBD-04A", "germany": "Puma IFV", "iran": "BMP-2", "russia": "BMP-3", "india": "BMP-2 Sarath", "japan": "Type 89 IFV", "turkiye": "ACV-15", "uk": "Warrior", "south_korea": "K21 IFV", "saudi": "M2A2 Bradley", "indonesia": "Pandur II IFV", "ukraine": "M2A2 Bradley"},
	"heavyAPC": {"israel": "Namer"},
	"reconVehicle": {"usa": "M3 Bradley Scout", "germany": "Fennek", "uk": "Jackal", "australia": "Hawkei", "indonesia": "Komodo Scout"},
	"directFire": {"japan": "Type 16 MCV", "brazil": "EE-9 Cascavel", "indonesia": "Harimau", "ukraine": "AMX-10 RC"},
	"towedHowitzer": {"usa": "M777", "india": "M777", "uk": "L118 Light Gun", "australia": "M777", "japan": "FH70", "ukraine": "M777"},
	"attackJet": {"usa": "A-10C Thunderbolt II", "germany": "Tornado IDS", "iran": "Su-24MK", "russia": "Su-25", "india": "Jaguar", "saudi": "Tornado IDS", "ukraine": "Su-25", "north_korea": "Su-25", "pakistan": "Mirage 5"},
	"lightFighter": {"usa": "F-16C", "china": "J-10C", "germany": "Eurofighter Typhoon", "iran": "F-5E", "india": "Tejas Mk1", "turkiye": "F-16C", "south_korea": "FA-50", "brazil": "F-5M", "pakistan": "F-16"},
	"scoutHelicopter": {"japan": "OH-1", "uk": "Wildcat Mk1"},
	"missileBoat": {"china": "Type 022", "israel": "Sa'ar 4.5", "egypt": "Ambassador Mk III", "pakistan": "Azmat-class"},
}
const CORRECTIONS := {"apc": {"south_korea": "K808 APC"}}
const PROFILES := {
	"mineLayer": [0.8, 0.3, 0.0, 0.0, 0.0, 0.2], "mineClearer": [1.3, 0.6, 0.2, 0.0, 0.0, 1.2], "recoveryVehicle": [0.6, 0.2, 0.0, 0.0, 0.0, 0.1], "decoy": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"counterBatteryRadar": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "coastalASM": [0.0, 0.0, 0.0, 0.0, 2.0, 0.0], "aewc": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "ewJet": [0.3, 0.8, 0.4, 0.0, 0.3, 0.8],
	"combatUGV": [1.6, 0.7, 0.1, 0.0, 0.0, 0.3], "logisticsUGV": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "robotDog": [1.3, 0.3, 0.0, 0.0, 0.0, 0.2], "heavyBomberDrone": [1.4, 1.2, 0.9, 0.0, 0.3, 1.0], "heavyLift": [0.6, 0.2, 0.0, 0.0, 0.0, 0.1], "navalHelicopter": [0.0, 0.0, 0.0, 0.0, 1.6, 0.0], "maritimePatrol": [0.0, 0.0, 0.0, 0.0, 1.8, 0.0], "carrier": [0.4, 0.4, 0.2, 1.4, 0.6, 0.2], "asFrigate": [0.3, 0.5, 0.4, 0.9, 1.4, 0.6], "landingShip": [0.5, 0.3, 0.0, 0.2, 0.3, 0.3],
	"recoillessTeam": [0.7, 1.4, 0.55, 0.0, 0.0, 1.4], "wheeledHowitzer": [1.2, 1.0, 0.8, 0.0, 0.6, 1.4], "shortRangeSAM": [0.0, 0.0, 0.0, 1.6, 0.0, 0.0],
	"machineGunTeam": [1.8, 0.45, 0.0, 0.0, 0.0, 0.25], "mortarTeam": [1.6, 0.8, 0.15, 0.0, 0.2, 0.75], "scoutTeam": [0.8, 0.2, 0.0, 0.0, 0.0, 0.2],
	"ifv": [1.8, 1.4, 0.45, 0.0, 0.2, 0.65], "heavyAPC": [1.6, 0.3, 0.0, 0.0, 0.0, 0.25], "reconVehicle": [1.2, 0.6, 0.0, 0.0, 0.0, 0.25], "directFire": [0.75, 1.4, 1.15, 0.0, 0.4, 1.3],
	"towedHowitzer": [1.2, 1.0, 0.8, 0.0, 0.6, 1.4], "attackJet": [1.5, 1.6, 1.6, 0.0, 0.6, 1.6], "lightFighter": [0.6, 0.7, 0.65, 1.8, 0.6, 0.65], "scoutHelicopter": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "missileBoat": [0.0, 0.0, 0.0, 0.0, 1.8, 0.0],
}

static func base(key: String) -> String:
	return str(BASE.get(key, key))

static func id_of(w: Node, owner: int) -> String:
	return str(w.map.nations[owner].get("id", ""))

static func operators(key: String) -> Array:
	if key in ["mineLayer", "mineClearer", "recoveryVehicle"]:
		# Every national army's engineers; the regional entities keep their own documented rosters (regional_factions.gd).
		return IDS.filter(func(id): return not id in preload("res://scripts/regional_factions.gd").IDS)
	return IDS.duplicate() if key in ["machineGunTeam", "mortarTeam", "scoutTeam"] else names(key).keys()

## id -> model of role `key` for the nations that keep their names in the "force_names" of
## scripts/nations/<id>.gd rather than in NAMES above, in registry order.
static var _own_names := {}
static func own_names(key: String) -> Dictionary:
	if not _own_names.has(key):
		var rows := {}
		for script in preload("res://scripts/nation_registry.gd").ORDER:
			var named: Dictionary = script.DATA.get("force_names", {})
			if named.has(key): rows[script.DATA.id] = named[key]
		_own_names[key] = rows
	return _own_names[key]

static func names(key: String) -> Dictionary:
	var out: Dictionary = NAMES.get(key, {}).duplicate()
	out.merge(own_names(key), true)
	out.merge(Diversity.names(key), true)
	return out

static func name_for(w: Node, owner: int, key: String) -> String:
	var id: String = id_of(w, owner)
	return str(w.map.nations[owner].get("unit_names", {}).get(key, names(key).get(id, CORRECTIONS.get(key, {}).get(id, ROLES.get(key, {}).get("name", "")))))

static func apply(w: Node) -> void:
	for key in ROLES:
		var def: Dictionary = ROLES[key].duplicate(true)
		def.generic = def.name
		def.name = name_for(w, 0, key)
		var provenance: String = Diversity.evidence(key, id_of(w, 0))
		if provenance != "": def.desc += " " + provenance
		if (id_of(w, 0) == "iran" and key in ["ifv", "attackJet", "lightFighter"]) or (id_of(w, 0) == "north_korea" and key == "attackJet"):
			def.desc += " Documented legacy equipment; current readiness is unverified."
		def.nation = operators(key).map(func(id): return {"usa": "blue", "china": "red", "germany": "green", "iran": "gold"}.get(id, id))
		# An explicit roster can grant a role to a future country, but a new ID
		# never inherits everybody's fleet through a colour or default nation.
		for n in w.map.nations:
			if key in n.get("units", []):
				var arsenal: String = {"usa": "blue", "china": "red", "germany": "green", "iran": "gold"}.get(str(n.get("id", "")), str(n.get("id", "")))
				if not arsenal in def.nation: def.nation.append(arsenal)
		# Use the established map-scaled artillery reach: a portable mortar
		# is shorter-ranged, while the cheaper towed gun has the same reach
		# as a self-propelled gun and sacrifices mobility and protection.
		if key in INDIRECT:
			def.range = float(w.unit_defs.artillery.range) * (0.65 if key == "mortarTeam" else 1.0)
			def.aggro = def.range
		w.unit_defs[key] = def
		var p: Array = PROFILES[key]
		w.damage_profile[key] = {"infantry": p[0], "light": p[1], "armor": p[2], "air": p[3], "naval": p[4], "building": p[5]}
		var trains: Array = w.building_defs[HOME[key]].trains
		if not key in trains: trains.append(key)
		if key in INFANTRY and not key in w.infantry_keys: w.infantry_keys.append(key)
	# Heavy protection is distinct from the lightly protected scout vehicles.
	for key in ["ifv", "heavyAPC", "directFire", "mineClearer", "recoveryVehicle"]:
		if not key in w.armor_keys: w.armor_keys.append(key)
	for key in CORRECTIONS:
		if CORRECTIONS[key].has(id_of(w, 0)): w.unit_defs[key].name = CORRECTIONS[key][id_of(w, 0)]
	preload("res://scripts/war_tools.gd").apply(w)   # the aircraft of a carrier's air wing

static func ai_unlocked(w: Node, owner: int, key: String) -> bool:
	if not ROLES.has(key): return true
	var need: String = str(w.unit_defs[key].get("requires", ""))
	return need == "" or (w.research != null and w.research.ai_tech(owner) >= float(w.research.era_of(need)) * 2.0)

static func equip(w: Node, u: Dictionary) -> void:
	if not ROLES.has(u.key): return
	# Existing ground units use a common walking speed; these roles must keep
	# their speed/cost/protection tradeoffs before national and research bonuses.
	if not u.get("fly", false) and not u.get("naval", false): u.speed = float(ROLES[u.key].speed)

static func can_target(w: Node, attacker: Dictionary, target: Dictionary) -> bool:
	if not preload("res://scripts/war_tools.gd").can_target(attacker, target): return false
	if attacker.key == "missileBoat" and (not target.get("naval", false) or base(str(target.get("key", ""))) in ["submarine", "nuclearSub"] or target.get("key", "") == "orca"):
		return false
	return true
