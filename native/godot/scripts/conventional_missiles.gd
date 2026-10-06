extends RefCounted
## More conventional missiles for the Missile Silo, so the silo is not the
## poor relation of the Strategic Weapons Complex. Any nation may build them;
## each answers a problem the others do not.
##   Bunker-Buster Missile   a hardened penetrating warhead: buildings, bunkers
##                           and silos take three times the damage and bunkers
##                           shelter no one from it; troops in the open little
##   Thermobaric Missile     a fuel-air warhead: a wide blast that kills
##                           infantry, in the open or dug in, and shakes vehicles
##   Anti-Radiation Missile  homes on the nearest air-defence radar within 40 m
##                           of where it is aimed: SAM sites and batteries take
##                           three times the damage and fall silent for 30 s
## Rivals use the bunker-buster on your strongholds and the anti-radiation
## missile on your air defences once their technology allows (ai.gd).

const MISSILES := {
	"bunkerMissile": {"name": "Bunker-Buster Missile", "icon": "BB", "buildTime": 30, "cost": {"money": 700, "iron": 60, "silicon": 14},
		"dmg": 650, "radius": 8, "speed": 70, "arc": true, "special": "penetrator", "needsDiscovery": "precisionStrikes",
		"desc": "A hardened warhead that drives deep before it bursts: buildings, bunkers and silos take three times the damage, and a bunker shelters no one from it. Little use against troops in the open."},
	"thermobaricMissile": {"name": "Thermobaric Missile", "icon": "TB", "buildTime": 26, "cost": {"money": 520, "iron": 40, "oil": 25},
		"dmg": 420, "radius": 20, "speed": 72, "special": "thermobaric",
		"desc": "A fuel-air warhead: a wide blast and pressure wave that kills infantry in the open or dug in (bunkers do not help), shakes vehicles, and does less to solid buildings."},
	"antiRadar": {"name": "Anti-Radiation Missile", "icon": "ARM", "buildTime": 22, "cost": {"money": 480, "iron": 25, "silicon": 20},
		"dmg": 520, "radius": 7, "speed": 110, "special": "antiRadar", "needsDiscovery": "guidedMunitions",
		"desc": "Homes on the nearest air-defence radar within 40 m of where it is aimed: SAM sites, missile defence batteries and anti-aircraft vehicles take three times the damage and fall silent for 30 s. Fire it before your aircraft or missiles go in."},
}
## What an anti-radiation missile homes on.
const EMITTERS := ["samSite", "samLauncher", "aaVehicle", "abmLauncher", "irisT", "laserAD", "saudiThaad", "aegisCruiser", "type45"]
const HOMING := 40.0
const SILENCE := 30.0

static func apply(world: Node) -> void:
	var types: Dictionary = world.map.missiles.get("types", {})
	for key in MISSILES:
		types[key] = MISSILES[key].duplicate(true)

## The anti-radiation missile's aim: the nearest enemy radar near `at`, or `at`.
static func home(w: Node, at: Vector3, owner: int) -> Vector3:
	var best = null
	var best_d := HOMING
	for e in w.units + w.buildings:
		if e.dead or int(e.owner) == owner or not e.key in EMITTERS:
			continue
		var p: Vector3 = e.node.position
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best if best != null else at

## The damage factor of a warhead `special` on `ent`, or -1 when it is not one of these.
static func mult(special: String, ent: Dictionary, building: bool) -> float:
	match special:
		"thermobaric":
			if building: return 0.7
			return 1.8 if not ent.get("vehicle", false) and not ent.get("naval", false) else 0.8
		"antiRadar":
			return 3.0 if ent.key in EMITTERS else 0.3
	return -1.0
