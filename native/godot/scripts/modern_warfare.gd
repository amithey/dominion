extends RefCounted
## Modern warfare, after the wars of 2022-2026 (Ukraine, Israel and Iran, the
## Red Sea): cheap drones everywhere, jamming against them, lasers and layered
## missile defence, and armour that shoots down what is fired at it.
##
## Units:
##   fpvTeam        infantry who fly first-person-view kamikaze drones at vehicles
##   atgmTeam       Javelin-style top-attack anti-tank missiles
##   manpads        Stinger-style shoulder-launched anti-aircraft missiles
##   medic          heals the infantry around it
##   himars         wheeled precision rocket artillery: two guided rockets, far
##   ewVehicle      electronic warfare: jams drones, loitering munitions and sea drones
##   laserAD        Iron Beam-style laser: burns drones and aircraft, and shoots
##                  down cruise missiles near it
##   abmLauncher    Arrow / THAAD-style battery: intercepts ballistic missiles
##   loiterer       Switchblade / Lancet-style loitering munition (dies on its strike)
##   stealthFighter F-35-style: seen by radar and air defence only close in
##   seaDrone       Magura-style unmanned boat that rams ships (dies on its strike)
##
## Interception odds per engagement (one shot by each battery the missile
## flies past, so batteries in layers multiply). From published results:
## Israel against Iran, June 2025: 86% of ballistic missiles intercepted
## (Arrow 2/3, THAAD, David's Sling in layers); Ukraine's Patriots against
## Iskander and Kinzhal: 24% overall from 2022 to Oct 2025, 6-37% a month in
## 2025 once the warheads manoeuvred in the dive; cruise missiles and Shahed
## drones: 80-97%.

const DRONES := ["drone", "loiterer", "fpvTeam", "seaDrone", "shahed", "harop", "interceptorDrone"]   # jammable
const KAMIKAZE := ["loiterer", "seaDrone", "shahed", "harop", "interceptorDrone"]
const Arsenal := preload("res://scripts/national_arsenal.gd")
const Future := preload("res://scripts/future_weapons.gd")
const FactionArsenal := preload("res://scripts/faction_arsenal.gd")
const JAM_RADIUS := 55.0
const JAM_FAIL := 0.7          # chance a jammed drone strike is lost
const JAM_DAMAGE := 0.4        # damage a jammed drone still does with its guns
const HEAL_RADIUS := 11.0
const HEAL_RATE := 6.0         # health per second, one patient at a time
const STEALTH_SEEN := 0.4      # share of its range at which air defence sees a stealth aircraft
const APS_RELOAD := 4.0        # an active protection system rearms between intercepts

## Missile classes and each defender's chance to stop one per engagement.
const CLASS_OF := {"cruise": "cruise", "cluster": "cruise", "emp": "cruise", "antiShip": "seaSkimmer",
	"tactical": "shortBallistic", "ballistic": "ballistic", "hypersonic": "hypersonic", "nuke": "icbm", "df17": "hypersonic", "brahmos": "supersonic",
	"tacticalNuke": "shortBallistic", "hydrogenBomb": "icbm", "tsarBomba": "icbm", "neutronBomb": "ballistic", "nuclearEmp": "icbm",
	"dirtyBomb": "shortBallistic", "chemical": "shortBallistic", "bioweapon": "shortBallistic"}
const INTERCEPT := {
	# SAM site, mobile SAM, ABM battery, laser, the Verdant Union's IRIS-T SLM,
	# and the railgun (future_weapons.gd: cheap shots, nearly half the hypersonics)
	# (reported ~99% against what it engaged in Ukraine, mostly cruise missiles
	# and drones, and some ballistic missiles).
	"cruise":         {"samSite": 0.75, "samLauncher": 0.55, "abmLauncher": 0.8, "laserAD": 0.5, "irisT": 0.95, "railgunShip": 0.7, "aegisCruiser": 0.85},
	"seaSkimmer":     {"samSite": 0.6, "samLauncher": 0.45, "abmLauncher": 0.7, "laserAD": 0.4, "irisT": 0.9, "railgunShip": 0.8, "aegisCruiser": 0.8},
	"shortBallistic": {"samSite": 0.35, "samLauncher": 0.2, "abmLauncher": 0.8, "laserAD": 0.0, "irisT": 0.6, "railgunShip": 0.5, "aegisCruiser": 0.8},
	"ballistic":      {"samSite": 0.25, "samLauncher": 0.1, "abmLauncher": 0.86, "laserAD": 0.0, "irisT": 0.45, "railgunShip": 0.45, "aegisCruiser": 0.8},
	"hypersonic":     {"samSite": 0.08, "samLauncher": 0.03, "abmLauncher": 0.3, "laserAD": 0.0, "irisT": 0.12, "railgunShip": 0.45, "aegisCruiser": 0.4},
	# BrahMos, Mach 3: none of the 15-19 fired in May 2025 was reported intercepted.
	"supersonic":     {"samSite": 0.25, "samLauncher": 0.15, "abmLauncher": 0.45, "laserAD": 0.1, "irisT": 0.4, "railgunShip": 0.5, "aegisCruiser": 0.55},
	"icbm":           {"samSite": 0.03, "samLauncher": 0.0, "abmLauncher": 0.55, "laserAD": 0.0, "irisT": 0.0, "railgunShip": 0.1, "aegisCruiser": 0.5},
}
## How far each defender reaches, and how long it takes to fire again.
const REACH := {"samSite": 140.0, "samLauncher": 115.0, "abmLauncher": 230.0, "laserAD": 60.0, "irisT": 120.0, "railgunShip": 150.0, "aegisCruiser": 250.0, "type45": 200.0, "saudiThaad": 253.0}
const RELOAD := {"samSite": 2.2, "samLauncher": 3.0, "abmLauncher": 6.0, "laserAD": 1.5, "irisT": 2.5, "railgunShip": 1.5, "aegisCruiser": 3.0, "type45": 3.0, "saudiThaad": 6.0}

const UNITS := {
	"fpvTeam": {"name": "FPV Drone Team", "hp": 80, "dmg": 55, "range": 30, "cooldown": 5.0, "aggro": 34, "speed": 8.5,
		"fly": false, "naval": false, "cost": {"money": 150, "silicon": 6}, "trainTime": 10, "pop": 1,
		"desc": "Two operators and a crate of first-person-view kamikaze drones: cheap, and deadly to vehicles out to 30 m. Jammers bring most of them down."},
	"atgmTeam": {"name": "ATGM Team", "hp": 90, "dmg": 70, "range": 28, "cooldown": 5.0, "aggro": 30, "speed": 8.0,
		"fly": false, "naval": false, "cost": {"money": 220, "iron": 15, "silicon": 8}, "trainTime": 12, "pop": 1,
		"desc": "Javelin-style fire-and-forget missiles that dive onto a tank's thin roof. Active protection can stop them."},
	"manpads": {"name": "MANPADS Team", "hp": 85, "dmg": 40, "range": 30, "cooldown": 3.5, "aggro": 34, "speed": 8.5,
		"fly": false, "naval": false, "cost": {"money": 200, "iron": 10, "silicon": 8}, "trainTime": 12, "pop": 1,
		"desc": "Stinger-style shoulder-launched missiles: infantry that can shoot down helicopters, drones and low jets."},
	"medic": {"name": "Combat Medic", "hp": 90, "dmg": 6, "range": 12, "cooldown": 1.0, "aggro": 20, "speed": 9.0,
		"fly": false, "naval": false, "cost": {"money": 120}, "trainTime": 9, "pop": 1,
		"desc": "Treats the wounded: heals the infantry around it (6 health a second, the worst hurt first)."},
	"himars": {"name": "HIMARS", "hp": 220, "dmg": 90, "range": 34, "cooldown": 7.0, "aggro": 40, "speed": 16,
		"fly": false, "naval": false, "cost": {"money": 650, "iron": 70, "oil": 20, "silicon": 20}, "trainTime": 22, "pop": 3,
		"requires": "guidedMunitions",
		"desc": "Wheeled launcher firing pairs of GPS-guided rockets four hexes: precise, deadly to buildings and depots. Shoot and move."},
	"ewVehicle": {"name": "EW Vehicle", "hp": 260, "dmg": 0, "range": 0, "cooldown": 0, "aggro": 0, "speed": 12,
		"fly": false, "naval": false, "cost": {"money": 420, "iron": 40, "silicon": 30}, "trainTime": 16, "pop": 2,
		"requires": "electronicWarfare",
		"desc": "Electronic warfare truck: within 55 m enemy drones, loitering munitions and sea drones lose their link (7 in 10 strikes fail, drone guns do 40%)."},
	"laserAD": {"name": "Laser Air Defence", "hp": 300, "dmg": 30, "range": 60, "cooldown": 1.2, "aggro": 70, "speed": 9,
		"fly": false, "naval": false, "cost": {"money": 700, "iron": 60, "silicon": 40}, "trainTime": 24, "pop": 3,
		"requires": "directedEnergy",
		"desc": "Iron Beam-style 100 kW laser: burns drones out of the sky for the price of electricity, hurts aircraft, and stops half the cruise missiles it sees. No use against ballistic missiles."},
	"abmLauncher": {"name": "Missile Defence Battery", "hp": 280, "dmg": 0, "range": 0, "cooldown": 0, "aggro": 0, "speed": 9,
		"fly": false, "naval": false, "cost": {"money": 900, "iron": 80, "oil": 10, "silicon": 45}, "trainTime": 26, "pop": 3,
		"requires": "missileDefence",
		"desc": "Arrow / THAAD-style interceptors: 86% against a ballistic missile, 30% against a hypersonic one, 55% against an ICBM, out to 230 m. Two batteries make two layers."},
	"loiterer": {"name": "Loitering Munition", "hp": 40, "dmg": 160, "range": 14, "cooldown": 1.0, "aggro": 60, "speed": 20,
		"fly": true, "naval": false, "cost": {"money": 180, "oil": 5, "silicon": 12}, "trainTime": 8, "pop": 1,
		"requires": "droneSwarms",
		"desc": "Switchblade / Lancet-style: circles over the front, then dives into its target and explodes. One use. Jammers bring most of them down."},
	"stealthFighter": {"name": "Stealth Fighter", "hp": 240, "dmg": 85, "range": 28, "cooldown": 2.4, "aggro": 40, "speed": 30,
		"fly": true, "naval": false, "cost": {"money": 950, "iron": 60, "oil": 60, "silicon": 40}, "trainTime": 30, "pop": 3,
		"requires": "stealthTech",
		"desc": "F-35-style fifth-generation fighter: air defence and enemy fighters only see it at 40% of their range."},
	"seaDrone": {"name": "Sea Drone", "hp": 60, "dmg": 380, "range": 10, "cooldown": 1.0, "aggro": 60, "speed": 24,
		"fly": false, "naval": true, "cost": {"money": 260, "oil": 10, "silicon": 15}, "trainTime": 10, "pop": 1,
		"requires": "navalEngineering",
		"desc": "Magura-style unmanned explosive boat: fast and low, it rams a warship or a harbour and blows up. One use. Jammers stop most of them."},
}

const PROFILES := {
	"fpvTeam": {"infantry": 0.8, "light": 1.3, "armor": 1.5, "air": 0.0, "naval": 0.6, "building": 0.4},
	"atgmTeam": {"infantry": 0.3, "light": 1.2, "armor": 2.0, "air": 0.3, "naval": 0.5, "building": 0.6},
	"manpads": {"infantry": 0.0, "light": 0.0, "armor": 0.0, "air": 3.2, "naval": 0.0, "building": 0.0},
	"medic": {"infantry": 0.5, "light": 0.1, "armor": 0.0, "air": 0.0, "naval": 0.0, "building": 0.0},
	"himars": {"infantry": 0.9, "light": 1.2, "armor": 1.1, "air": 0.0, "naval": 0.8, "building": 2.0},
	"ewVehicle": {"infantry": 0, "light": 0, "armor": 0, "air": 0, "naval": 0, "building": 0},
	"laserAD": {"infantry": 0.0, "light": 0.0, "armor": 0.0, "air": 2.5, "naval": 0.0, "building": 0.0},
	"abmLauncher": {"infantry": 0, "light": 0, "armor": 0, "air": 0, "naval": 0, "building": 0},
	"loiterer": {"infantry": 0.9, "light": 1.6, "armor": 1.6, "air": 0.0, "naval": 1.2, "building": 1.2},
	"stealthFighter": {"infantry": 0.9, "light": 1.1, "armor": 1.05, "air": 1.6, "naval": 0.75, "building": 0.9},
	"seaDrone": {"infantry": 0.0, "light": 0.0, "armor": 0.0, "air": 0.0, "naval": 2.0, "building": 0.8},
}

const TRAINS := {
	"barracks": ["fpvTeam", "atgmTeam", "manpads", "medic"],
	"tankFactory": ["himars", "ewVehicle", "laserAD", "abmLauncher"],
	"airfield": ["loiterer", "stealthFighter"],
	"shipyard": ["seaDrone"],
}

const DISCOVERIES := {
	"electronicWarfare": {"name": "Electronic Warfare", "cost": 380, "branch": "hightech", "era": 2,
		"reqDiscovery": "microchips", "reqBuilding": null, "fx": {},
		"desc": "Unlocks the EW Vehicle, which jams enemy drones, loitering munitions and sea drones near it."},
	"activeProtection": {"name": "Active Protection", "cost": 420, "branch": "army", "era": 3,
		"reqDiscovery": "compositeArmor", "reqBuilding": "tankFactory", "fx": {"aps": 0.5},
		"desc": "Trophy-style radar and interceptors on your armoured vehicles: half the missiles, rockets and kamikaze drones fired at them are blown up before they hit (one every 4 s)."},
	"missileDefence": {"name": "Missile Defence", "cost": 600, "branch": "strategic", "era": 3,
		"reqDiscovery": "microchips", "reqBuilding": null, "fx": {"interceptPct": 0.1},
		"desc": "Unlocks the Missile Defence Battery (Arrow / THAAD) and gives every air defence +10% to intercept missiles."},
	"manoeuvringWarheads": {"name": "Manoeuvring Warheads", "cost": 550, "branch": "strategic", "era": 4,
		"reqDiscovery": "ballisticTech", "reqBuilding": "missileSilo", "fx": {"evasion": 0.4},
		"desc": "Your ballistic and hypersonic warheads jink in the final dive: 40% less likely to be intercepted."},
	"directedEnergy": {"name": "Directed Energy", "cost": 650, "branch": "hightech", "era": 4,
		"reqDiscovery": "missileDefence", "reqBuilding": "powerPlant", "fx": {},
		"desc": "Unlocks Laser Air Defence: a 100 kW beam that downs drones for the cost of electricity."},
}

static func apply(w: Node) -> void:
	for key in UNITS:
		w.unit_defs[key] = UNITS[key].duplicate(true)
	for key in PROFILES:
		w.damage_profile[key] = PROFILES[key].duplicate()
	for key in ["fpvTeam", "atgmTeam", "manpads", "medic"]:
		if not key in w.infantry_keys:
			w.infantry_keys.append(key)
	for b in TRAINS:
		if not w.building_defs.has(b):
			continue
		var list: Array = w.building_defs[b].get("trains", [])
		for key in TRAINS[b]:
			if not key in list:
				list.append(key)
		w.building_defs[b].trains = list
	var discoveries: Dictionary = w.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)
	var droneSwarms: Dictionary = discoveries.get("droneSwarms", {})
	if not droneSwarms.is_empty():
		droneSwarms.desc = "Drones, FPV teams and loitering munitions deal +40% damage; drones cost 30% less. Unlocks the Loitering Munition."
	# HIMARS reaches four hexes (its card says so; it used to stop at 34 m).
	var hex: float = float(w.map.logistics.hexRadius) * sqrt(3.0)
	w.unit_defs.himars.range = hex * 4.0
	w.unit_defs.himars.aggro = hex * 4.0
	Arsenal.apply(w)   # each nation's own weapons
	Future.apply(w)    # weapons still in development
	FactionArsenal.apply(w)   # the five newer factions' own weapons
	preload("res://scripts/additional_factions.gd").apply(w)
	preload("res://scripts/national_variants.gd").apply(w)   # who really fields what, under which name
	preload("res://scripts/unit_quality.gd").apply(w)   # the systems that replace them (the M1E3 Abrams)
	preload("res://scripts/national_capabilities.gd").apply(w)   # Russia's from the war in Ukraine
	preload("res://scripts/space.gd").apply(w)   # anti-satellite weapons
	preload("res://scripts/wmd.gd").apply(w)   # nuclear yields, EMP, chemical, biological, radiological
	var types: Dictionary = w.map.missiles.types
	for key in types:
		var odds: Dictionary = INTERCEPT[CLASS_OF.get(key, "cruise")]
		types[key].desc = "%s Interception: SAM site %d%%, missile defence %d%%." % [str(types[key].desc).split(" Interception:")[0], int(odds.samSite * 100), int(odds.abmLauncher * 100)]

# ---------------------------------------------------------------- capabilities

## A hostile electronic-warfare vehicle jams the air around `at` for `owner`'s drones.
static func jammed(w: Node, at: Vector3, owner: int) -> bool:
	for u in w.units:
		if u.dead or u.key != "ewVehicle" or not w.hostile(owner, u.owner) or w.disabled(u):
			continue
		if Vector2(u.node.position.x - at.x, u.node.position.z - at.z).length() < JAM_RADIUS:
			return true
	return false

## Damage a drone still does through jamming.
static func jam_mult(w: Node, source: Dictionary) -> float:
	if source.get("key", "") == "drone" and source.has("node") and jammed(w, source.node.position, source.owner):
		return JAM_DAMAGE
	return 1.0

## An aircraft that radar sees only close in.
static func hidden(w: Node, target: Dictionary, distance: float, reach: float) -> bool:
	var seen: float = Arsenal.STEALTH.get(target.get("key", ""), 1.0)
	if seen >= 1.0 or distance <= reach * seen:
		return false
	return target.get("naval", false) or w.airborne(target)   # a submarine hides at sea; an aircraft only in flight

## Chance that `vehicle`'s active protection defeats a missile, rocket or kamikaze drone.
static func aps_chance(w: Node, vehicle: Dictionary) -> float:
	if vehicle.get("is_building", false) or vehicle.get("fly", false) or vehicle.get("naval", false) or not vehicle.get("vehicle", false):
		return 0.0
	if float(vehicle.get("aps_ready", 0.0)) > w.game_time:
		return 0.0
	if vehicle.get("aps_builtin", false):
		return maxf(0.5, w.research.bonus("aps") if vehicle.owner == 0 and w.research else 0.0)   # the M1E3's Iron Fist
	if vehicle.owner == 0:
		return w.research.bonus("aps") if w.research else 0.0
	return 0.3 if w.research and w.research.ai_tech(vehicle.owner) >= 5.0 else 0.0

## Rolls the target's active protection; true when the shot is defeated.
static func aps_stops(w: Node, target: Dictionary) -> bool:
	var chance := aps_chance(w, target)
	if chance <= 0.0:
		return false
	if not preload("res://scripts/war_costs.gd").pay(w, int(target.owner), 0.75, 0.0, "intercepts"): return false
	target.aps_ready = w.game_time + APS_RELOAD
	return randf() < chance

## Medics heal; called every frame.
static func update(w: Node, delta: float) -> void:
	for u in w.units:
		if u.dead or u.key != "medic" or w.disabled(u):
			continue
		u.heal_tick = float(u.get("heal_tick", 0.0)) - delta
		if u.heal_tick > 0.0:
			continue
		u.heal_tick = 0.5
		var worst = null
		var worst_share := 0.999
		for other in w.units:
			if other.dead or other.owner != u.owner or not other.key in w.infantry_keys or other.key == "worker":
				continue
			var share: float = other.hp / maxf(other.max_hp, 1.0)
			if share < worst_share and other.node.position.distance_to(u.node.position) < HEAL_RADIUS:
				worst_share = share
				worst = other
		if worst != null:
			worst.hp = minf(worst.max_hp, worst.hp + HEAL_RATE * 0.5)
			u.healing = worst

# ---------------------------------------------------------------- missile defence

## Chance that defender `kind` (owned by `defender`) stops missile `m`.
static func intercept_chance(w: Node, kind: String, m: Dictionary, defender: int) -> float:
	var odds: float = INTERCEPT[CLASS_OF.get(m.type, "cruise")].get(kind, 0.0)
	if kind == "type45": odds = {"cruise": 0.7, "seaSkimmer": 0.65, "shortBallistic": 0.25}.get(CLASS_OF.get(m.type, "cruise"), 0.0)
	if kind == "saudiThaad": odds = {"shortBallistic": 0.8, "ballistic": 0.86}.get(CLASS_OF.get(m.type, "cruise"), 0.0)
	if odds <= 0.0:
		return 0.0
	if defender == 0 and w.research:
		odds += w.research.bonus("interceptPct")
		if kind == "abmLauncher" and CLASS_OF.get(m.type, "cruise") == "hypersonic":
			odds += w.research.bonus("hgvIntercept")   # Glide Phase Interceptor
	elif defender > 0 and w.research:
		odds += 0.01 * w.research.ai_tech(defender)
	if preload("res://scripts/factions.gd").identity(w, defender) == "israel":
		odds += 0.05
	var cls: String = CLASS_OF.get(m.type, "cruise")
	if cls in ["shortBallistic", "ballistic", "hypersonic", "icbm"]:
		var evasion := 0.0
		if int(m.owner) == 0 and w.research:
			evasion = w.research.bonus("evasion")
		elif int(m.owner) > 0 and w.research and w.research.ai_tech(int(m.owner)) >= 6.0:
			evasion = 0.2
		odds *= 1.0 - evasion
	return clampf(odds, 0.0, 0.97)

## Every air defence the missile passes gets one shot at it: the terminal dive
## for a missile on a high arc, any time for one flying low. Returns true when
## the missile is destroyed.
static func intercept(w: Node, m: Dictionary, at: Vector3, f: float) -> bool:
	if not m.has("engaged"):
		m.engaged = {}
	if dome(w, m, at, f):
		return true
	var dive: bool = not m.arc or f > 0.55   # up high on its arc, only an ABM reaches it
	for d in defenders(w):
		var id: int = d.node.get_instance_id()
		if m.engaged.has(id) or not w.hostile(d.owner, int(m.owner)):
			continue
		if not dive and d.kind not in ["abmLauncher", "saudiThaad"]:
			continue
		if not m.arc and d.kind == "abmLauncher" and f < 0.3:
			continue
		if Vector2(d.node.position.x - at.x, d.node.position.z - at.z).length() > REACH[d.kind]:
			continue
		var chance := intercept_chance(w, d.kind, m, d.owner)
		if chance <= 0.0:
			continue
		if float(d.ent.get("intercept_ready", 0.0)) > w.game_time or (d.kind == "samSite" and float(d.ent.get("aa_reload", 0.0)) > 0.0):
			continue   # reloading; it may still get its shot while the missile is in reach
		if not preload("res://scripts/war_costs.gd").pay(w, int(d.owner), float(preload("res://scripts/war_costs.gd").INTERCEPT.get(d.kind, 5.0)), 0.0, "intercepts"):
			preload("res://scripts/war_costs.gd").blocked(w, d.ent, "interceptor budget")
			continue
		m.engaged[id] = true
		d.ent.intercept_ready = w.game_time + RELOAD[d.kind]
		if d.kind == "samSite":
			d.ent.aa_reload = RELOAD.samSite
		var from: Vector3 = d.node.position + Vector3.UP * (5.0 if d.kind == "samSite" else 3.0)
		var hit := randf() < chance
		w.intercepts.append({"type": m.type, "by": d.kind, "hit": hit, "owner": int(m.owner)})
		if d.kind == "laserAD":
			w.effects.beam(from, at)
		else:
			w.effects.projectile("missile", from, at, func(p): w.effects.explosion(p, 1.2 if hit else 0.4, false))
		_report(w, m, d, hit)
		if hit:
			return true
	return false

## Golden Dome: one shot from orbit at a missile fired at the player, wherever
## it flies, while the treasury can pay for the interceptor.
static func dome(w: Node, m: Dictionary, at: Vector3, f: float) -> bool:
	if int(m.owner) == 0 or m.engaged.has("dome") or w.research == null or w.research.bonus("goldenDome") <= 0.0:
		return false
	if not w.hostile(0, int(m.owner)) or (m.arc and f < 0.3):
		return false
	if not preload("res://scripts/war_costs.gd").pay(w, 0, Future.DOME_COST, 0.0, "intercepts"):
		return false
	m.engaged.dome = true
	var cls: String = CLASS_OF.get(m.type, "cruise")
	var chance: float = Future.DOME[cls]
	if cls in ["shortBallistic", "ballistic", "hypersonic", "icbm"] and w.research.ai_tech(int(m.owner)) >= 6.0:
		chance *= 0.8   # a rival's manoeuvring warheads
	var hit := randf() < chance
	w.intercepts.append({"type": m.type, "by": "goldenDome", "hit": hit, "owner": int(m.owner)})
	w.effects.projectile("missile", at + Vector3(randf_range(-30, 30), 140.0, randf_range(-30, 30)), at, func(p): w.effects.explosion(p, 1.2 if hit else 0.4, false))
	_report(w, m, {"kind": "goldenDome", "owner": 0}, hit)
	return hit

## Air defences able to shoot at missiles: SAM sites and the mobile batteries.
static func defenders(w: Node) -> Array:
	var out := []
	for b in w.buildings:
		if b.key == "samSite" and not b.dead and b.built and b.get("supplied", true) and not w.disabled(b):
			out.append({"kind": "samSite", "node": b.root, "owner": b.owner, "ent": b})
	for u in w.units:
		if u.key in ["samLauncher", "abmLauncher", "laserAD", "irisT", "railgunShip", "aegisCruiser", "type45", "saudiThaad"] and not u.dead and not w.disabled(u):
			out.append({"kind": u.key, "node": u.node, "owner": u.owner, "ent": u})
	return out

static func _report(w: Node, m: Dictionary, d: Dictionary, hit: bool) -> void:
	if w.hud == null:
		return
	var name: String = w.missiles.def_of(m.type).get("name", "missile")
	var by: String = {"samSite": "a SAM site", "samLauncher": "a mobile SAM", "abmLauncher": "a missile defence battery", "laserAD": "a laser", "irisT": "an IRIS-T battery", "railgunShip": "a railgun", "goldenDome": "Golden Dome", "aegisCruiser": "an Aegis cruiser", "type45": "a Type 45 destroyer", "saudiThaad": "a THAAD battery"}[d.kind]
	if int(m.owner) == 0:
		w.hud.notice(("Your %s was shot down by %s." if hit else "Your %s slipped past %s.") % [name, by])
	elif d.owner == 0:
		w.hud.notice(("Incoming %s intercepted by %s." if hit else "Incoming %s evaded %s!") % [name, by])
