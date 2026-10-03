extends RefCounted
## Each nation's own "star" weapons, which only it can field (and rivals of that
## nation field too when the AI plays it). A nation is known by its flag colour,
## so the arsenal follows it when the player picks another nation.
##
##   blue (United States, after the United States)
##     raptor          F-22 Raptor: air superiority, supercruise, the stealthiest
##                     fighter (seen at a quarter of the range), and SEAD: its
##                     missiles hit air defences two and a half times as hard
##     raider          B-21 Raider, from the Classified Programs discovery: a
##                     flying-wing bomber still largely secret in 2025, seen only
##                     at 15% of the range, heavy precision bombs
##   red (China, after China)
##     df17            DF-17 launcher: a hypersonic glide vehicle six hexes out,
##                     hard to intercept, deadly to ships (the DF-21D / DF-26
##                     "carrier killer" role)
##   gold (Iran, after Iran)
##     shahedLauncher  fires a swarm of five Shahed-136 one-way attack drones; each
##                     is slow and easy to shoot down, together they saturate
##   green (European Union, after Europe)
##     irisT           IRIS-T SLM: the air defence Ukraine reported hitting about
##                     99% of its targets; stops most cruise missiles and some
##                     ballistic ones

const NATION_OF_COLOUR := {"#3b82f6": "blue", "#e0483e": "red", "#33b86e": "green", "#e8a83a": "gold"}
const NATION_NAMES := {"blue": "United States", "red": "China", "green": "European Union", "gold": "Iran"}
const SWARM := 5            # Shaheds per salvo
const SWARM_MAX := 15       # a nation's Shaheds in the air at once
const SEAD := 2.5           # the Raptor against air defences
const SHAHED_FUEL := 90.0   # seconds a Shahed can fly before it comes down

const UNITS := {
	"raptor": {"name": "F-22 Raptor", "nation": "blue", "hp": 280, "dmg": 80, "range": 32, "cooldown": 2.0, "aggro": 44, "speed": 34,
		"fly": true, "naval": false, "cost": {"money": 1300, "iron": 70, "oil": 70, "silicon": 50}, "trainTime": 32, "pop": 3,
		"requires": "stealthTech",
		"desc": "United States only. The air superiority fighter: supercruise, and so stealthy that air defence and fighters see it at a quarter of their range. Its missiles hit air defences 2.5 times as hard (SEAD)."},
	"raider": {"name": "B-21 Raider", "nation": "blue", "hp": 420, "dmg": 160, "range": 20, "cooldown": 4.0, "aggro": 36, "speed": 22,
		"fly": true, "naval": false, "cost": {"money": 2200, "iron": 120, "oil": 90, "silicon": 80}, "trainTime": 40, "pop": 4,
		"requires": "classifiedPrograms",
		"desc": "United States only. A classified flying-wing bomber: seen only at 15% of the range, it drops heavy precision bombs on buildings and armour. Two sorties before it rearms."},
	"df17": {"name": "DF-17 Launcher", "nation": "red", "hp": 260, "dmg": 1, "range": 60, "cooldown": 30.0, "aggro": 60, "speed": 12,
		"fly": false, "naval": false, "cost": {"money": 1100, "iron": 80, "oil": 30, "silicon": 45}, "trainTime": 30, "pop": 3,
		"requires": "ballisticTech",
		"desc": "China only. Fires a hypersonic glide vehicle six hexes: a SAM site stops 8% of them, a missile defence battery 30%. Two and a half times as deadly to ships (the carrier killer)."},
	"shahedLauncher": {"name": "Shahed Launcher", "nation": ["gold", "russia"], "hp": 240, "dmg": 1, "range": 50, "cooldown": 45.0, "aggro": 50, "speed": 12,
		"fly": false, "naval": false, "cost": {"money": 700, "iron": 40, "silicon": 30}, "trainTime": 24, "pop": 3,
		"requires": "microchips",
		"desc": "Iran only. Launches a swarm of five Shahed one-way attack drones five hexes out. Each is slow and easy to shoot down; together they overwhelm air defence."},
	"shahed": {"name": "Shahed Drone", "nation": ["gold", "russia"], "hp": 35, "dmg": 110, "range": 8, "cooldown": 1.0, "aggro": 70, "speed": 14,
		"fly": true, "naval": false, "cost": {"money": 0}, "trainTime": 1, "pop": 0,
		"desc": "A one-way attack drone from a Shahed Launcher."},
	"irisT": {"name": "IRIS-T SLM", "nation": "green", "hp": 300, "dmg": 45, "range": 90, "cooldown": 2.0, "aggro": 100, "speed": 10,
		"fly": false, "naval": false, "cost": {"money": 950, "iron": 60, "silicon": 45}, "trainTime": 26, "pop": 3,
		"requires": "guidedMunitions",
		"desc": "European Union only. The air defence that hit ~99% of its targets in Ukraine: shoots down aircraft and drones 90 m out, stops 95% of cruise missiles and 45% of ballistic ones."},
}

const PROFILES := {
	"raptor": {"infantry": 0.7, "light": 1.0, "armor": 1.0, "air": 2.2, "naval": 0.7, "building": 1.0},
	"raider": {"infantry": 1.2, "light": 1.4, "armor": 1.4, "air": 0.0, "naval": 1.2, "building": 2.6},
	"df17": {"infantry": 0.3, "light": 0.8, "armor": 1.0, "air": 0.0, "naval": 2.5, "building": 1.5},
	"shahedLauncher": {"infantry": 0.4, "light": 1.0, "armor": 1.0, "air": 0.0, "naval": 1.0, "building": 1.5},
	"shahed": {"infantry": 0.6, "light": 1.2, "armor": 1.0, "air": 0.0, "naval": 1.0, "building": 1.8},
	"irisT": {"infantry": 0.0, "light": 0.0, "armor": 0.0, "air": 4.0, "naval": 0.0, "building": 0.0},
}

const TRAINS := {"airfield": ["raptor", "raider"], "tankFactory": ["df17", "shahedLauncher", "irisT"]}

## The DF-17's glide vehicle: fired only by the launcher, never built in a silo.
const MISSILES := {
	"df17": {"name": "DF-17 Glide Vehicle", "dmg": 420, "radius": 9, "speed": 170, "special": "hgv",
		"desc": "A hypersonic glide vehicle."},
}

const DISCOVERIES := {
	"classifiedPrograms": {"name": "Classified Programs", "cost": 900, "branch": "air", "era": 5, "nation": "blue",
		"reqDiscovery": "stealthTech", "reqBuilding": "airfield", "fx": {},
		"desc": "United States only. Special access programs: unlocks the B-21 Raider, a flying-wing bomber that radar sees only at 15% of its range."},
}

## How close (as a share of an observer's range) a stealth aircraft is seen.
const STEALTH := {"stealthFighter": 0.4, "raptor": 0.25, "raider": 0.15, "sixthGen": 0.2, "orca": 0.5, "seaDrone": 0.6}

static func apply(w: Node) -> void:
	for key in UNITS:
		w.unit_defs[key] = UNITS[key].duplicate(true)
	for key in PROFILES:
		w.damage_profile[key] = PROFILES[key].duplicate()
	for b in TRAINS:
		if not w.building_defs.has(b):
			continue
		var list: Array = w.building_defs[b].get("trains", [])
		for key in TRAINS[b]:
			if not key in list:
				list.append(key)
		w.building_defs[b].trains = list
	for key in DISCOVERIES:
		w.map.research.discoveries[key] = DISCOVERIES[key].duplicate(true)
	# The launchers reach six and five hexes.
	var hex: float = float(w.map.logistics.hexRadius) * sqrt(3.0)
	w.unit_defs.df17.range = hex * 6.0
	w.unit_defs.df17.aggro = hex * 6.0
	w.unit_defs.shahedLauncher.range = hex * 5.0
	w.unit_defs.shahedLauncher.aggro = hex * 5.0

## "blue", "red", "green" or "gold": the nation `owner` plays.
static func identity(w: Node, owner: int) -> String:
	if owner < 0 or owner >= w.map.nations.size():
		return ""
	return str(NATION_OF_COLOUR.get(str(w.map.nations[owner].get("color", "")).to_lower(), w.map.nations[owner].get("arsenal", "")))

## True when `owner` may field `key` (every nation fields the common units).
static func allowed(w: Node, owner: int, key: String) -> bool:
	return preload("res://scripts/national_variants.gd").admits(w.unit_defs.get(key, {}).get("nation", ""), identity(w, owner))

## Why the player may not field `key` or research `discovery`, or "".
static func foreign(w: Node, nation) -> String:
	if preload("res://scripts/national_variants.gd").admits(nation, identity(w, 0)):
		return ""
	if nation is Array:
		return "Not fielded by %s" % str(w.map.nations[0].get("name", "your nation")).split(" · ")[0]
	var extra := preload("res://scripts/additional_factions.gd")
	if nation in extra.IDS: return "%s only" % extra.NAMES[extra.IDS.find(nation)]
	return "%s only" % NATION_NAMES.get(nation, preload("res://scripts/faction_arsenal.gd").NAMES.get(nation, nation))

## A salvo of Shaheds from `launcher` at `enemy`. Returns how many flew.
static func launch_swarm(w: Node, launcher: Dictionary, enemy: Dictionary) -> int:
	var aloft: int = w.units.filter(func(u): return not u.dead and u.key == "shahed" and u.owner == launcher.owner).size()
	var n := mini(SWARM, SWARM_MAX - aloft)
	if n <= 0:
		return 0
	var toward: Vector3 = enemy.node.position - launcher.node.position
	toward.y = 0
	var yaw := atan2(toward.x, toward.z)
	for i in range(n):
		var at: Vector3 = launcher.node.position + Basis(Vector3.UP, yaw) * Vector3((i - (n - 1) * 0.5) * 3.0, 0, -2.0 - i * 1.5)
		var drone: Dictionary = w.spawn_unit("shahed", at, launcher.owner)
		drone.air_state = "ready"
		drone.heading = yaw
		drone.stay = false
		drone.fuel_until = w.game_time + SHAHED_FUEL
		w.order_attack([drone], enemy)
	w.effects.explosion(launcher.node.position + Vector3.UP * 2.5, 0.6, false)
	return n
