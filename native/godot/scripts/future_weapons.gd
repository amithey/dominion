extends RefCounted
## Weapons still in development in 2026, for the Global and Future eras.
##
##   hpmVehicle   high-power microwave (Epirus Leonidas, in US Army service as
##                IFPC-HPM; 61 of 61 drones in a 2025 test, 49 with one pulse):
##                a pulse every few seconds fries every enemy drone near it,
##                fibre-optic and jam-proof ones included
##   railgunShip  electromagnetic railgun (Japan's test ship Asuka hit a target
##                ship in 2025, Mach 6.5): a very long gun, and cheap shots
##                that stop nearly half the hypersonic missiles it sees
##   sixthGen     sixth-generation fighter (F-47 to fly in 2028; China's J-36
##                and J-50 flying since December 2024; only these two): the
##                stealthiest aircraft, and it leads two loyal wingmen
##   wingman      Collaborative Combat Aircraft (FQ-42 / FQ-44, ordered into
##                production in June 2026): drones that fly with the fighter,
##                attack what it attacks and draw the enemy's fire
##   orca         extra-large uncrewed submarine (Boeing Orca, a 1,000-mile
##                transit in July 2026): cheap, quiet, torpedoes; enemies find
##                it only at half their range
## Discoveries:
##   Glide Phase Interceptor (US-Japan, in development): your missile defence
##   batteries stop twice as many hypersonic missiles (30% -> 60%).
##   Golden Dome (United States only; interceptors in orbit, $1.2 trillion
##   by the CBO's 2026 estimate): one more shot from space at every missile
##   fired at you, anywhere on the map, at $150 an interceptor.

const HPM_RADIUS := 45.0
const HPM_RELOAD := 6.0
const HPM_KILLS := ["drone", "loiterer", "shahed", "seaDrone", "harop"]   # small drones, not the large wingmen
const WINGMEN := 2
const DOME_COST := 150.0
## Golden Dome's chance per missile, by class: built against ballistic missiles
## in their boost and mid-course, weaker against low cruise missiles.
const DOME := {"cruise": 0.2, "seaSkimmer": 0.1, "shortBallistic": 0.4, "ballistic": 0.6, "hypersonic": 0.35, "icbm": 0.6}
## Names of the sixth-generation fighter for each nation.
const SIXTH_GEN_NAMES := {"blue": "F-47", "red": "J-36"}

const UNITS := {
	"hpmVehicle": {"name": "Microwave Weapon", "hp": 260, "dmg": 0, "range": 0, "cooldown": 0, "aggro": 0, "speed": 12,
		"fly": false, "naval": false, "cost": {"money": 800, "iron": 50, "silicon": 50}, "trainTime": 24, "pop": 2,
		"requires": "highPowerMicrowave",
		"desc": "Leonidas-style high-power microwave: every 6 s one pulse destroys every enemy drone within 45 m (Shaheds, loitering munitions, sea drones), even the jam-proof ones. No effect on crewed aircraft."},
	"railgunShip": {"name": "Railgun Cruiser", "hp": 900, "dmg": 95, "range": 70, "cooldown": 2.5, "aggro": 75, "speed": 10,
		"fly": false, "naval": true, "cost": {"money": 1500, "iron": 160, "oil": 40, "silicon": 60}, "trainTime": 36, "pop": 4,
		"requires": "railguns",
		"desc": "Electromagnetic railgun at Mach 6.5: shells land 70 m away, and its cheap shots stop 45% of hypersonic missiles and 70-80% of cruise missiles within 150 m."},
	"sixthGen": {"name": "Sixth-Gen Fighter", "hp": 340, "dmg": 95, "range": 34, "cooldown": 2.0, "aggro": 46, "speed": 36,
		"fly": true, "naval": false, "cost": {"money": 1800, "iron": 90, "oil": 80, "silicon": 80}, "trainTime": 40, "pop": 4,
		"requires": "sixthGeneration",
		"desc": "The next generation: the stealthiest fighter (seen at a fifth of the range), and it takes off with two loyal wingman drones that attack what it attacks."},
	"wingman": {"name": "Loyal Wingman", "hp": 150, "dmg": 45, "range": 26, "cooldown": 2.2, "aggro": 40, "speed": 34,
		"fly": true, "naval": false, "cost": {"money": 0}, "trainTime": 1, "pop": 0,
		"desc": "Collaborative combat drone: flies with its sixth-generation fighter and draws the enemy's fire."},
	"orca": {"name": "Uncrewed Submarine", "hp": 320, "dmg": 55, "range": 22, "cooldown": 2.4, "aggro": 30, "speed": 10,
		"fly": false, "naval": true, "cost": {"money": 450, "iron": 40, "silicon": 25}, "trainTime": 16, "pop": 1,
		"requires": "unmannedSubmarines",
		"desc": "Orca-style extra-large uncrewed submarine: cheap and quiet, it torpedoes ships, and enemies find it only at half their range."},
}

const PROFILES := {
	"hpmVehicle": {"infantry": 0, "light": 0, "armor": 0, "air": 0, "naval": 0, "building": 0},
	"railgunShip": {"infantry": 0.9, "light": 1.2, "armor": 1.2, "air": 0.0, "naval": 1.3, "building": 1.4},
	"sixthGen": {"infantry": 0.8, "light": 1.1, "armor": 1.1, "air": 2.4, "naval": 0.8, "building": 1.0},
	"wingman": {"infantry": 0.7, "light": 0.9, "armor": 0.8, "air": 1.4, "naval": 0.6, "building": 0.6},
	"orca": {"infantry": 0, "light": 0, "armor": 0, "air": 0, "naval": 1.6, "building": 0},
}

const TRAINS := {"tankFactory": ["hpmVehicle"], "shipyard": ["orca", "railgunShip"], "airfield": ["sixthGen"]}

const DISCOVERIES := {
	"highPowerMicrowave": {"name": "High-Power Microwave", "cost": 600, "branch": "hightech", "era": 4,
		"reqDiscovery": "electronicWarfare", "reqBuilding": "powerPlant", "fx": {},
		"desc": "Unlocks the Microwave Weapon: one pulse fries a whole drone swarm, even drones that jamming cannot touch."},
	"unmannedSubmarines": {"name": "Uncrewed Submarines", "cost": 550, "branch": "navy", "era": 4,
		"reqDiscovery": "sonarSystems", "reqBuilding": "shipyard", "fx": {},
		"desc": "Unlocks the Uncrewed Submarine: cheap, quiet, found only at half the range."},
	"railguns": {"name": "Electromagnetic Railgun", "cost": 900, "branch": "navy", "era": 5,
		"reqDiscovery": "navalEngineering", "reqBuilding": "powerPlant", "fx": {},
		"desc": "Unlocks the Railgun Cruiser: Mach 6.5 shells 70 m out, and cheap interception of hypersonic missiles."},
	"sixthGeneration": {"name": "Sixth-Generation Fighter", "cost": 1000, "branch": "air", "era": 5,
		"reqDiscovery": "stealthTech", "reqBuilding": "airfield", "fx": {},
		"desc": "Unlocks the sixth-generation fighter and its loyal wingman drones."},
	"glidePhaseInterceptor": {"name": "Glide Phase Interceptor", "cost": 850, "branch": "strategic", "era": 5,
		"reqDiscovery": "missileDefence", "reqBuilding": null, "fx": {"hgvIntercept": 0.3},
		"desc": "An interceptor that catches hypersonic glide vehicles while they manoeuvre: missile defence batteries stop 60% of hypersonic missiles instead of 30%."},
	"goldenDome": {"name": "Golden Dome", "cost": 1600, "branch": "strategic", "era": 5, "nation": "blue",
		"reqDiscovery": "missileDefence", "reqBuilding": null, "fx": {"goldenDome": 1.0},
		"desc": "United States only. Interceptors in orbit: one more shot at every missile fired at you, anywhere (60% against ballistic, 35% hypersonic, 20% cruise), at $150 an interceptor."},
}

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
	var discoveries: Dictionary = w.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)
	# The player's own sixth-generation fighter; China's flies first, so the
	# Crimson Empire gets there for three quarters of the research.
	var Arsenal := preload("res://scripts/national_arsenal.gd")
	var me := Arsenal.identity(w, 0)
	w.unit_defs.sixthGen.name = SIXTH_GEN_NAMES.get(me, "Sixth-Gen Fighter")
	if me == "red":
		discoveries.sixthGeneration.cost = int(discoveries.sixthGeneration.cost * 0.75)
		discoveries.sixthGeneration.desc += " The Crimson Empire's J-36 has flown since 2024: this costs a quarter less."

## Two loyal wingmen take off with a new sixth-generation fighter.
static func escort(w: Node, leader: Dictionary) -> Array:
	var out := []
	for i in range(WINGMEN):
		var side := -1.0 if i == 0 else 1.0
		var at: Vector3 = leader.node.position + Basis(Vector3.UP, leader.heading) * Vector3(side * 7.0, 0, -5.0)
		var drone: Dictionary = w.spawn_unit("wingman", at, leader.owner)
		drone.air_state = "ready"
		drone.heading = leader.heading
		drone.leader = leader
		out.append(drone)
	return out

## Microwave pulses and wingmen; called every frame.
static func update(w: Node, delta: float) -> void:
	for u in w.units:
		if u.dead or w.disabled(u):
			continue
		if u.key == "hpmVehicle":
			u.hpm_ready = float(u.get("hpm_ready", 0.0)) - delta
			if u.hpm_ready <= 0.0 and pulse(w, u) > 0:
				u.hpm_ready = HPM_RELOAD
		elif u.key == "shahed" and w.game_time > float(u.get("fuel_until", INF)):
			# Out of fuel: a one-way drone that found nothing to hit comes down.
			w.effects.explosion(Vector3(u.node.position.x, maxf(w.height_at(u.node.position.x, u.node.position.z), float(w.map.seaLevel)), u.node.position.z), 0.8, true)
			w.kill(u)
		elif u.key == "wingman":
			u.follow_tick = float(u.get("follow_tick", 0.0)) - delta
			if u.follow_tick <= 0.0:
				u.follow_tick = 0.5
				follow(w, u)

## Fries every hostile drone within reach of `hpm`. Returns how many.
static func pulse(w: Node, hpm: Dictionary) -> int:
	var fried := 0
	var paid := false
	for other in w.units:
		if other.dead or not other.key in HPM_KILLS or not w.hostile(hpm.owner, other.owner):
			continue
		if Vector2(other.node.position.x - hpm.node.position.x, other.node.position.z - hpm.node.position.z).length() < HPM_RADIUS:
			if not paid:
				if not preload("res://scripts/war_costs.gd").pay(w, int(hpm.owner), 0.35, 0.0, "intercepts"): return 0
				paid = true
			w.damage(other, other.hp + 1.0, hpm)
			fried += 1
	if fried > 0:
		w.effects.emp_flash(hpm.node.position + Vector3.UP * 2.0, HPM_RADIUS * 0.5)
		w.hpm_kills += fried
	return fried

## True when an enemy microwave weapon covers `at` (FPV strikes there fail).
static func covered(w: Node, at: Vector3, owner: int) -> bool:
	for u in w.units:
		if u.dead or u.key != "hpmVehicle" or not w.hostile(owner, u.owner) or w.disabled(u):
			continue
		if Vector2(u.node.position.x - at.x, u.node.position.z - at.z).length() < HPM_RADIUS:
			if preload("res://scripts/war_costs.gd").pay(w, int(u.owner), 0.35, 0.0, "intercepts"): return true
	return false

## A wingman attacks what its leader attacks, and keeps close to it otherwise.
static func follow(w: Node, u: Dictionary) -> void:
	var leader = u.get("leader")
	if leader == null or leader.dead:
		# A wingman whose fighter is gone (or that was just loaded from a save)
		# joins the nearest of its side's sixth-generation fighters short of two.
		leader = null
		var best := 90.0
		for f in w.units:
			if f.dead or f.key != "sixthGen" or f.owner != u.owner:
				continue
			var mates: int = w.units.filter(func(o): return not o.dead and o.key == "wingman" and is_same(o.get("leader"), f)).size()
			var d: float = f.node.position.distance_to(u.node.position)
			if mates < WINGMEN and d < best:
				best = d
				leader = f
		u.leader = leader
		if leader == null:
			return
	if leader.enemy != null and not leader.enemy.dead and not is_same(u.enemy, leader.enemy) and w.effectiveness(u, leader.enemy) > 0.01:
		u.enemy = leader.enemy
		u.target = null
		return
	if u.enemy == null:
		# Formation: its idle circle is centred on the fighter, wherever it
		# flies, and it hurries back when it has strayed.
		# (No waypoint orders: a jet that reaches a waypoint flies on 80 m to
		# turn, which would throw the formation apart.)
		var at: Vector3 = leader.node.position
		u.orbit = Vector3(at.x, 0, at.z)
