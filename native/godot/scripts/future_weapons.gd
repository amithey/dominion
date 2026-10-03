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

## Two loyal wingmen go with a new sixth-generation fighter. While it stands on
## its airfield they are not on the map at all (counted aboard, in
## wingmen_stowed); they are launched beside it as it takes off and recovered
## as it lands (command), so a hangar of fighters costs the game nothing.
static func escort(w: Node, leader: Dictionary) -> Array:
	leader.wingmen_stowed = WINGMEN
	if leader.get("air_state", "ready") == "ready":
		return launch_wingmen(w, leader)
	return []

## The wingmen aboard take to the air beside their fighter.
static func launch_wingmen(w: Node, leader: Dictionary) -> Array:
	var out := []
	var flying: int = mates(w, leader).size()
	for i in range(int(leader.get("wingmen_stowed", 0))):
		var side := -1.0 if (flying + i) % 2 == 0 else 1.0
		var at: Vector3 = leader.node.position + Basis(Vector3.UP, leader.heading) * Vector3(side * (7.0 + 6.0 * ((flying + i) / 2)), 0, -5.0)
		var drone: Dictionary = w.spawn_unit("wingman", at, leader.owner)
		drone.air_state = "ready"
		drone.heading = leader.heading
		drone.leader = leader
		out.append(drone)
	leader.wingmen_stowed = 0
	return out

## A wingman recovered with its fighter: off the map, with no wreck or loss.
static func stow(w: Node, u: Dictionary) -> void:
	u.stowed = true
	u.killed = true
	u.dead = true
	u.selected = false
	u.ring.visible = false
	u.target = null
	u.enemy = null
	u.node.visible = false
	if u.get("engine"):
		u.engine.stop()
	u.dead_time = 100.0   # (world.update_dead removes it at once)

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
				u.follow_tick = 0.25
				follow(w, u)
		elif u.key == "sixthGen":
			u.group_tick = float(u.get("group_tick", 0.0)) - delta
			if u.group_tick <= 0.0:
				u.group_tick = 0.5
				command(w, u)

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

## The battle group: one sixth-generation fighter and its loyal wingmen, each
## a unit of its own (its own health, its own missiles, its own place on the
## map), that fly, defend and attack as one (the Air Force's CCA concept: the
## drones fly beside the crewed fighter, strike what it strikes, meet what
## threatens it and draw the enemy's fire):
## - in formation: on a straight leg each wingman holds its slot off the
##   fighter's wing; circling, they share its circle a little ahead and behind;
## - attacking: the wingmen take the fighter's target;
## - defending: whatever shoots at one of the group is engaged by all of it,
##   the wingmen before anything else;
## - drawing fire: an escorted fighter is the enemy's last choice of target;
## - together: a click on any of them selects the group; the wingmen return over
##   the airfield with the fighter, and a lost wingman is replaced while the
##   fighter rearms ($200 each, one every 20 s).
const SLOTS := [Vector3(-10.0, 0, -7.0), Vector3(10.0, 0, -7.0), Vector3(-20.0, 0, -14.0), Vector3(20.0, 0, -14.0)]
const GROUP_RADIUS := 80.0
const REPLACE_COST := 200.0
const REPLACE_SECONDS := 20.0

## The fighter and its wingmen, the fighter first ([] for any other unit).
static func group_of(w: Node, u: Dictionary) -> Array:
	var leader = u if u.key == "sixthGen" else (u.get("leader") if u.key == "wingman" else null)
	if leader == null or leader.dead:
		return []
	return [leader] + mates(w, leader)

static func mates(w: Node, leader: Dictionary) -> Array:
	return w.units.filter(func(o): return not o.dead and o.key == "wingman" and is_same(o.get("leader"), leader))

## A click on one of the group selects all of it (world._unhandled_input).
static func select_group(w: Node, u: Dictionary) -> void:
	for member in group_of(w, u):
		member.selected = true

## Who is shooting at the group, nearest the fighter first.
static func threats(w: Node, leader: Dictionary, group: Array) -> Array:
	var out := []
	var at: Vector3 = leader.node.position
	for other in w.units:
		if other.dead or other.owner == leader.owner or not w.hostile(leader.owner, other.owner):
			continue
		var aim = other.get("enemy")
		if not (aim is Dictionary) or not group.any(func(m): return is_same(m, aim)):
			continue
		if Vector2(other.node.position.x - at.x, other.node.position.z - at.z).length() < GROUP_RADIUS:
			out.append(other)
	out.sort_custom(func(a, b): return a.node.position.distance_squared_to(at) < b.node.position.distance_squared_to(at))
	return out

## Twice a second for each fighter: the group's orders, defence and repairs.
static func command(w: Node, leader: Dictionary) -> void:
	var wing := mates(w, leader)
	if not leader.has("wingmen_stowed"):
		# Just loaded from a save: its wingmen in the air join it again first, and
		# only those missing count as aboard (else it would launch two more).
		for o in w.units:
			if wing.size() >= WINGMEN:
				break
			var lead = o.get("leader")
			if not o.dead and o.key == "wingman" and o.owner == leader.owner and (lead == null or lead.dead) and o.node.position.distance_to(leader.node.position) < 150.0:
				o.leader = leader
				wing.append(o)
		leader.wingmen_stowed = maxi(0, WINGMEN - wing.size())
	# Down on the airfield, the wingmen are recovered with it; in the air again,
	# they are launched beside it.
	if leader.get("air_state", "ready") in ["landing", "taxi_in", "rearming", "parked", "taxi_out"]:
		for u in wing:
			stow(w, u)
			leader.wingmen_stowed = int(leader.wingmen_stowed) + 1
		wing = []
	elif leader.get("air_state", "ready") == "ready" and int(leader.wingmen_stowed) > 0:
		wing += launch_wingmen(w, leader)
	var group: Array = [leader] + wing
	leader.escorted = wing.size()   # (Tactics.pick_target: the enemy's last choice)
	var danger := threats(w, leader, group)
	var airborne: bool = leader.get("air_state", "ready") == "ready"
	# The fighter answers whoever attacks one of its wingmen when it has nothing else to do.
	if airborne and leader.enemy == null and leader.target == null and not danger.is_empty():
		for t in danger:
			if w.effectiveness(leader, t) > 0.01:
				leader.enemy = t
				break
	for i in range(wing.size()):
		var u: Dictionary = wing[i]
		u.slot_index = i
		var foe = null
		for t in danger:
			if w.effectiveness(u, t) > 0.01:
				foe = t
				break
		if foe == null and airborne and leader.enemy != null and not leader.enemy.dead and w.effectiveness(u, leader.enemy) > 0.01:
			foe = leader.enemy
		if foe != null:
			if not is_same(u.enemy, foe):
				u.enemy = foe
			u.target = null
			u.slot_goal = null
		elif u.enemy != null and not airborne:
			u.enemy = null   # the fighter has gone home: so do they
	# A wingman lost: the fighter takes on a new one while it rearms.
	if leader.get("air_state", "") in ["rearming", "parked"] and int(leader.wingmen_stowed) < WINGMEN and w.game_time >= float(leader.get("wingman_ready", 0.0)):
		if preload("res://scripts/war_costs.gd").pay(w, int(leader.owner), REPLACE_COST):
			leader.wingman_ready = w.game_time + REPLACE_SECONDS
			leader.wingmen_stowed = int(leader.wingmen_stowed) + 1   # (aboard, launched with it)
			if leader.owner == 0:
				w.hud.notice("A new loyal wingman joins your %s ($%d)." % [w.unit_defs.sixthGen.name, int(REPLACE_COST)])

## A wingman keeps its place in the group (four times a second).
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
			var d: float = f.node.position.distance_to(u.node.position)
			if mates(w, f).size() + int(f.get("wingmen_stowed", 0)) < WINGMEN and d < best:
				best = d
				leader = f
		u.leader = leader
		u.slot_goal = null
		if leader == null:
			return
	var base_speed := float(w.unit_defs.wingman.speed)
	if (u.enemy == null or u.enemy.dead) and leader.get("air_state", "ready") == "ready" and leader.enemy != null and not leader.enemy.dead and w.effectiveness(u, leader.enemy) > 0.01:
		u.enemy = leader.enemy   # the fighter's target (command() may give it a nearer threat)
		u.target = null
	if u.enemy != null and not u.enemy.dead:
		u.speed = base_speed
		u.slot_goal = null
		return
	u.target = null   # (its own move orders give way to the formation)
	var slot: Vector3 = SLOTS[int(u.get("slot_index", 0)) % SLOTS.size()]
	var at: Vector3 = leader.node.position
	var airborne: bool = leader.get("air_state", "ready") == "ready"
	var leg = leader.get("egress") if leader.get("egress") != null else (leader.target if leader.target != null else (leader.enemy.node.position if leader.enemy != null and not leader.enemy.dead else null))
	if airborne and leg != null:
		# A straight leg: hold the slot off the fighter's wing. It steers for a
		# point 40 m beyond its slot (so it never turns back on an overshoot) and
		# matches the fighter's speed, faster when behind its slot, slower ahead.
		var turn := Basis(Vector3.UP, leader.heading)
		var forward: Vector3 = turn * Vector3.BACK
		var place: Vector3 = at + turn * slot
		var carrot: Vector3 = place + forward * 40.0
		u.slot_goal = Vector3(carrot.x, 0, carrot.z)
		var behind: float = Vector2(place.x - u.node.position.x, place.z - u.node.position.z).dot(Vector2(forward.x, forward.z))
		u.speed = float(leader.speed) * clampf(1.0 + behind / 20.0, 0.7, 1.6)
	else:
		# Circling (or over the airfield while the fighter is serviced): the
		# fighter's own circle, a little ahead or behind it.
		u.slot_goal = null
		u.speed = base_speed * 1.05
		u.orbit = Vector3(leader.orbit.x, 0, leader.orbit.z) if airborne else Vector3(at.x, 0, at.z)
		if airborne:
			var rank: int = int(u.get("slot_index", 0))
			u.phase = float(leader.get("phase", 0.0)) + (0.35 if rank % 2 == 0 else -0.35) * (1 + rank / 2)
