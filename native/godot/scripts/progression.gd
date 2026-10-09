extends RefCounted
## The era ladder: what a nation may build and train opens era by era, so a
## campaign grows from a founding town to a modern state instead of offering
## a nuclear reactor, a missile silo and jet bombers at minute one.
##
##   Founding    village, farms, homes, mines and rigs, market, bank, school,
##               barracks (riflemen, rocket squads, snipers, medics, mortars)
##   Regional    city, library, port, TV station, Intelligence
##               Agency, tank factory (tanks, APCs, artillery), shipyard
##               (gunboats), airfield (reconnaissance drones), SAM site
##   Urban       university, hospital, city hall, police, courthouse, oil
##               refinery, Tech Park, helipad, ammunition depot, missile silo;
##               helicopters, fighters, corvettes, submarines, rocket artillery
##   Industrial  power plant, Chip Fab; bombers, gunships, destroyers,
##               mobile SAM batteries
##   Global      nuclear reactor, strategic weapons, special weapons, AI
##   Future      (the Future era's own programmes stay gated by research)
##
## The ladder respects the research: every building a discovery needs for its
## prototype opens no later than that discovery's era, and every building an
## era's goals ask for opens before them (a village before the Regional era,
## cities and schools before the Urban, research buildings before the
## Industrial, Chip Fabs before the Future).
## Rivals climb the same ladder by their technology (an era every two levels).
## The ladder applies to campaigns under the Standard rules (match_config
## "progression"); the Sandbox rules leave everything open.

const BUILDINGS := {
	"hq": 0, "villageCenter": 0, "farm": 0, "cottage": 0, "housing": 0, "workerHouse": 0, "warehouse": 0, "foodDepot": 0,
	"extractor": 0, "mountainMine": 0, "fishingWharf": 0, "offshoreRig": 0, "market": 0, "bank": 0, "school": 0, "barracks": 0, "bunker": 0,
	"cityCenter": 1, "residential": 1, "library": 1, "port": 1, "tvStation": 1, "intelAgency": 1,
	"tankFactory": 1, "shipyard": 1, "airfield": 1, "samSite": 1,
	"university": 2, "hospital": 2, "cityHall": 2, "policeStation": 2, "courthouse": 2, "oilRefinery": 2, "techPark": 2,
	"helipad": 2, "ammoDepot": 2, "missileSilo": 2,
	"powerPlant": 3, "chipFab": 3,
	"nuclearReactor": 4, "strategicComplex": 4, "specialLab": 4, "aiDataCenter": 4, "fusionCell": 4,
}
## Units by their base class (additional_factions.base maps national units to these).
const UNITS := {
	"worker": 0, "soldier": 0, "rocketSoldier": 0, "sniper": 0, "medic": 0, "machineGunTeam": 0, "mortarTeam": 0, "scoutTeam": 0,
	"commando": 1, "atgmTeam": 1, "manpads": 1, "tank": 1, "apc": 1, "artillery": 1, "reconVehicle": 1, "ifv": 1, "heavyAPC": 1,
	"directFire": 1, "towedHowitzer": 1, "gunboat": 1, "drone": 1, "missileBoat": 1,
	"fpvTeam": 2, "mlrs": 2, "aaVehicle": 2, "helicopter": 2, "scoutHelicopter": 2, "jet": 2, "lightFighter": 2, "attackJet": 2,
	"corvette": 2, "submarine": 2, "ewVehicle": 2,
	"bomber": 3, "gunship": 3, "destroyer": 3, "samLauncher": 3, "himars": 3,
}
const ERA_NAMES := ["Founding Era", "Regional Era", "Urban Era", "Industrial Era", "Global Era", "Future Era"]

## Whether a campaign set up with `options` climbs the ladder (menu.start).
static func wanted(options: Dictionary) -> bool:
	return str(options.get("style", "standard")) != "sandbox"

static func on(w: Node) -> bool:
	return w != null and w.get("match_config") != null and bool(w.match_config.get("progression", false))

## The era nation `owner` has reached: the player's research era, a rival's technology / 2.
static func era_of(w: Node, owner: int) -> int:
	if w.research == null:
		return 0
	if owner == 0:
		return int(w.research.era)
	return clampi(int(w.research.ai_tech(owner) / 2.0), 0, 5)

static func _base(key: String) -> String:
	return preload("res://scripts/additional_factions.gd").base(key)

static func building_era(key: String) -> int:
	return int(BUILDINGS.get(key, 0))

## A unit's era: its own, its base class's, or at least its training building's.
static func unit_era(w: Node, key: String) -> int:
	if UNITS.has(key):
		return int(UNITS[key])
	var b := _base(key)
	if UNITS.has(b):
		return int(UNITS[b])
	for site in w.building_defs:
		if key in w.building_defs[site].get("trains", []):
			return building_era(site)
	return 0

static func _name(w: Node, era: int) -> String:
	if w.research != null and era < w.research.eras.size():
		return str(w.research.eras[era].name)
	return ERA_NAMES[clampi(era, 0, 5)]

## Why `owner` may not build `key` yet ("" when it may).
static func building_blocked(w: Node, owner: int, key: String) -> String:
	if not on(w):
		return ""
	var need := building_era(key)
	return "" if era_of(w, owner) >= need else "Opens in the %s" % _name(w, need)

## Why `owner` may not train `key` yet ("" when it may).
static func unit_blocked(w: Node, owner: int, key: String) -> String:
	if not on(w):
		return ""
	var need := unit_era(w, key)
	return "" if era_of(w, owner) >= need else "Opens in the %s" % _name(w, need)

## What opens in `era`, by name, for the player's notice and the era card.
static func opened_in(w: Node, era: int) -> PackedStringArray:
	var out := PackedStringArray()
	for key in BUILDINGS:
		if int(BUILDINGS[key]) == era and w.building_defs.has(key) and preload("res://scripts/national_variants.gd").builds(w, 0, key):
			out.append(str(w.building_defs[key].name))
	var units := PackedStringArray()
	for site in w.building_defs:
		for u in w.building_defs[site].get("trains", []):
			if unit_era(w, u) == era and w.unit_defs.has(u) and w.unit_allowed(0, u) and not str(w.unit_defs[u].name) in units:
				units.append(str(w.unit_defs[u].name))
	out.append_array(units)
	return out
