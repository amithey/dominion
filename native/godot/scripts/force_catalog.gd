extends RefCounted
## Representative operator rosters, not inventories or weapon specifications.
## Evidence, limitations and additions deferred for research are in
## native/FORCE-ROSTER-RESEARCH-2026-10-06.md. All figures below are game balance.
const IDS := ["usa", "china", "eu", "iran", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "saudi", "brazil", "indonesia", "ukraine", "north_korea", "egypt", "australia", "pakistan", "iraq", "syria", "afghanistan"] + preload("res://scripts/regional_factions.gd").IDS
const BASE := {"machineGunTeam": "soldier", "mortarTeam": "artillery", "scoutTeam": "commando", "ifv": "apc", "heavyAPC": "tank", "reconVehicle": "apc", "directFire": "tank", "towedHowitzer": "artillery", "attackJet": "jet", "lightFighter": "jet", "scoutHelicopter": "helicopter", "missileBoat": "corvette"}
const HOME := {"machineGunTeam": "barracks", "mortarTeam": "barracks", "scoutTeam": "barracks", "ifv": "tankFactory", "heavyAPC": "tankFactory", "reconVehicle": "tankFactory", "directFire": "tankFactory", "towedHowitzer": "tankFactory", "attackJet": "airfield", "lightFighter": "airfield", "scoutHelicopter": "helipad", "missileBoat": "shipyard"}
const INFANTRY := ["machineGunTeam", "mortarTeam", "scoutTeam"]
const SCOUTS := ["scoutTeam", "reconVehicle", "scoutHelicopter"]
const SIGHT := {"scoutTeam": 72.0, "reconVehicle": 84.0, "scoutHelicopter": 100.0, "ifv": 44.0, "heavyAPC": 38.0, "directFire": 52.0, "missileBoat": 52.0}
const INDIRECT := ["mortarTeam", "towedHowitzer"]
const ROLES := {
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
	"machineGunTeam": {"usa": "M240B Team", "eu": "MG5 Team", "uk": "L7 GPMG Team", "indonesia": "SM2 Team", "pakistan": "MG3 Team"},
	"mortarTeam": {"usa": "M224A1 Mortar Team", "uk": "L16 Mortar Team", "australia": "F2 81mm Mortar Team"},
	"scoutTeam": {},
	"ifv": {"usa": "M2A4 Bradley", "china": "ZBD-04A", "eu": "Puma IFV", "iran": "BMP-2", "russia": "BMP-3", "india": "BMP-2 Sarath", "japan": "Type 89 IFV", "turkiye": "ACV-15", "uk": "Warrior", "south_korea": "K21 IFV", "saudi": "M2A2 Bradley", "indonesia": "Pandur II IFV", "ukraine": "M2A2 Bradley"},
	"heavyAPC": {"israel": "Namer"},
	"reconVehicle": {"usa": "M3 Bradley Scout", "eu": "Fennek", "uk": "Jackal", "australia": "Hawkei", "indonesia": "Komodo Scout"},
	"directFire": {"japan": "Type 16 MCV", "brazil": "EE-9 Cascavel", "indonesia": "Harimau", "ukraine": "AMX-10 RC"},
	"towedHowitzer": {"usa": "M777", "india": "M777", "uk": "L118 Light Gun", "australia": "M777", "japan": "FH70", "ukraine": "M777"},
	"attackJet": {"usa": "A-10C Thunderbolt II", "eu": "Mirage 2000D", "iran": "Su-24MK", "russia": "Su-25", "india": "Jaguar", "saudi": "Tornado IDS", "ukraine": "Su-25", "north_korea": "Su-25", "pakistan": "Mirage 5", "iraq": "L-159 ALCA"},
	"lightFighter": {"usa": "F-16C", "china": "J-10C", "eu": "JAS 39 Gripen C", "iran": "F-5E", "india": "Tejas Mk1", "turkiye": "F-16C", "south_korea": "FA-50", "brazil": "F-5M", "pakistan": "F-16", "iraq": "T-50IQ"},
	"scoutHelicopter": {"japan": "OH-1", "uk": "Wildcat Mk1"},
	"missileBoat": {"china": "Type 022", "israel": "Sa'ar 4.5", "egypt": "Ambassador Mk III", "pakistan": "Azmat-class"},
}
const CORRECTIONS := {"apc": {"south_korea": "K808 APC"}}
const PROFILES := {
	"machineGunTeam": [1.8, 0.45, 0.0, 0.0, 0.0, 0.25], "mortarTeam": [1.6, 0.8, 0.15, 0.0, 0.2, 0.75], "scoutTeam": [0.8, 0.2, 0.0, 0.0, 0.0, 0.2],
	"ifv": [1.8, 1.4, 0.45, 0.0, 0.2, 0.65], "heavyAPC": [1.6, 0.3, 0.0, 0.0, 0.0, 0.25], "reconVehicle": [1.2, 0.6, 0.0, 0.0, 0.0, 0.25], "directFire": [0.75, 1.4, 1.15, 0.0, 0.4, 1.3],
	"towedHowitzer": [1.2, 1.0, 0.8, 0.0, 0.6, 1.4], "attackJet": [1.5, 1.6, 1.6, 0.0, 0.6, 1.6], "lightFighter": [0.6, 0.7, 0.65, 1.8, 0.6, 0.65], "scoutHelicopter": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "missileBoat": [0.0, 0.0, 0.0, 0.0, 1.8, 0.0],
}

static func base(key: String) -> String:
	return str(BASE.get(key, key))

static func id_of(w: Node, owner: int) -> String:
	return str(w.map.nations[owner].get("id", ""))

static func operators(key: String) -> Array:
	return IDS.duplicate() if key in INFANTRY else NAMES.get(key, {}).keys()

static func name_for(w: Node, owner: int, key: String) -> String:
	var id: String = id_of(w, owner)
	return str(w.map.nations[owner].get("unit_names", {}).get(key, NAMES.get(key, CORRECTIONS.get(key, {})).get(id, ROLES.get(key, {}).get("name", ""))))

static func apply(w: Node) -> void:
	for key in ROLES:
		var def: Dictionary = ROLES[key].duplicate(true)
		def.generic = def.name
		def.name = name_for(w, 0, key)
		if (id_of(w, 0) == "iran" and key in ["ifv", "attackJet", "lightFighter"]) or (id_of(w, 0) == "north_korea" and key == "attackJet"):
			def.desc += " Documented legacy equipment; current readiness is unverified."
		def.nation = operators(key).map(func(id): return {"usa": "blue", "china": "red", "eu": "green", "iran": "gold"}.get(id, id))
		# An explicit roster can grant a role to a future country, but a new ID
		# never inherits everybody's fleet through a colour or default nation.
		for n in w.map.nations:
			if key in n.get("units", []):
				var arsenal: String = {"usa": "blue", "china": "red", "eu": "green", "iran": "gold"}.get(str(n.get("id", "")), str(n.get("id", "")))
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
	for key in ["ifv", "heavyAPC", "directFire"]:
		if not key in w.armor_keys: w.armor_keys.append(key)
	for key in CORRECTIONS:
		if CORRECTIONS[key].has(id_of(w, 0)): w.unit_defs[key].name = CORRECTIONS[key][id_of(w, 0)]

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
	if attacker.key == "missileBoat" and (not target.get("naval", false) or base(str(target.get("key", ""))) in ["submarine", "nuclearSub"] or target.get("key", "") == "orca"):
		return false
	return true
