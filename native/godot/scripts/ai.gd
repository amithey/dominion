extends Node
## AI nations, ported from aiUpdate() in js/ai.js. The difficulty table,
## opening build order and training pool come from the map export.
## Each AI has an abstracted income, builds its opening order and then
## adaptively, self-builds (no workers), trains from the pool its buildings
## allow, rushes every unit home when its capital is threatened, and launches
## attack waves at the nearest player asset once it is at war.
## War and peace come from diplomacy.gd: an AI starts a war when its attack
## timer comes up and it wants one (relations below -35, or its aggression
## roll against a player it dislikes), and at once if the player attacks it.
## Attack waves go at the nearest building of any nation it is at war with.

var world: Node
var cfg: Dictionary      # the match's difficulty row
var levels: Dictionary   # every difficulty row: each rival plays its own (n.level)
var build_order: Array
var train_pool: Array
var nations: Array[Dictionary] = []

# Which building each unit needs (ai.js).
const TRAINED_AT := {"soldier": "barracks", "rocketSoldier": "barracks", "commando": "barracks", "sniper": "barracks",
	"tank": "tankFactory", "apc": "tankFactory", "artillery": "tankFactory", "samLauncher": "tankFactory",
	"helicopter": "helipad", "jet": "airfield", "drone": "airfield", "gunboat": "shipyard", "destroyer": "shipyard", "corvette": "shipyard",
	"fpvTeam": "barracks", "atgmTeam": "barracks", "manpads": "barracks", "medic": "barracks", "himars": "tankFactory",
	"ewVehicle": "tankFactory", "loiterer": "airfield", "raptor": "airfield", "df17": "tankFactory",
	"shahedLauncher": "tankFactory", "irisT": "tankFactory", "hpmVehicle": "tankFactory", "orca": "shipyard", "sixthGen": "airfield",
	"tos1a": "tankFactory", "brahmos": "tankFactory", "aegisCruiser": "shipyard", "akinci": "airfield", "harop": "airfield"}
## Modern units rival armies field alongside the export's training pool.
const MODERN_POOL := ["fpvTeam", "atgmTeam", "manpads", "medic", "himars", "ewVehicle", "loiterer", "raptor", "df17", "shahedLauncher", "irisT", "hpmVehicle", "orca", "sixthGen", "tos1a", "brahmos", "aegisCruiser", "akinci", "harop"]
## Missiles a rival at war fires at the player, by its technology level.
const STRIKE_TYPES := [[2.0, ["tactical", "cruise"]], [4.0, ["tactical", "cruise", "ballistic", "bunkerMissile", "antiRadar"]], [6.0, ["cruise", "ballistic", "hypersonic", "bunkerMissile", "antiRadar", "thermobaricMissile"]]]
const STRIKE_TARGETS := ["hq", "cityCenter", "villageCenter", "airfield", "tankFactory", "barracks", "missileSilo", "powerPlant", "port", "samSite"]

func setup(world_node: Node, ai: Dictionary, difficulty: String, speed := 1.0) -> void:
	world = world_node
	cfg = ai.difficulty.get(difficulty, ai.difficulty.easy)
	levels = ai.difficulty
	build_order = ai.buildOrder
	# Only units the native world can draw yet (no aircraft).
	train_pool = ai.trainPool.filter(func(k): return TRAINED_AT.has(k))
	for key in MODERN_POOL + preload("res://scripts/additional_factions.gd").BASE.keys() + load("res://scripts/force_catalog.gd").ROLES.keys():
		if not key in train_pool and world.unit_defs.has(key):
			train_pool.append(key)
	for id in range(1, world.map.nations.size()):
		# Each rival's own difficulty, as chosen in the New Game picker.
		var level: String = world.MatchSetup.level_of(world.match_config, id, difficulty if ai.difficulty.has(difficulty) else "easy")
		nations.append({
			"id": id, "name": world.map.nations[id].name, "money": 400.0, "build_idx": 0, "level": level,
			"next_build": (14.0 + randf() * 14.0) / speed, "next_train": (22.0 + randf() * 12.0) / speed,
			"next_attack": float(ai.difficulty[level].firstAttack) * (0.9 + randf() * 0.4) / speed,
			"next_defend": 5.0, "at_war": false, "defeated": false, "speed": speed,
		})

## Rival `n`'s difficulty row: income, build and training pace, army size,
## first attack, squad size, aggression.
func row(n: Dictionary) -> Dictionary:
	return levels.get(str(n.get("level", "")), cfg)

func row_of(id: int) -> Dictionary:
	for n in nations:
		if n.id == id:
			return row(n)
	return cfg

func aggression_of(id: int) -> float:
	return float(row_of(id).get("aggression", 0.35))

func hq(id: int):
	for b in world.buildings:
		if b.owner == id and b.key == "hq" and not b.dead:
			return b
	return null

func at_war(id: int) -> bool:
	return world.diplomacy.at_war(0, id)

## The player struck this nation (or it chose war).
func declare_war(id: int, provoked: bool) -> void:
	for n in nations:
		if n.id == id and not at_war(id) and not n.defeated:
			if provoked:
				world.diplomacy.declare_war(0, id, "You attacked %s: you are at war!" % n.name)
			else:
				world.diplomacy.declare_war(id, 0)
			n.next_attack = minf(n.next_attack, float(row(n).firstAttack) * 0.35 / n.speed)

func _physics_process(delta: float) -> void:
	if world == null or world.economy == null:
		return
	if world.match_stopped(): return
	var clock: int = world.clock()
	for n in nations:
		if n.defeated:
			continue
		var home = hq(n.id)
		if home == null:
			n.defeated = true
			continue
		think(n, home, delta)
	world.spent("ai", clock)

func think(n: Dictionary, home: Dictionary, delta: float) -> void:
	if world.match_config.get("style","standard")=="sandbox":
		n.next_attack = maxf(n.next_attack,99999.0)
	var s: float = n.speed
	var spies: Node = world.espionage
	n.money += float(row(n).income) * delta * s * preload("res://scripts/additional_powers.gd").civic_income(world, n, delta) * (spies.income_mult(n.id) if spies else 1.0) * preload("res://scripts/faction_powers.gd").income_mult(world, n.id) * preload("res://scripts/national_profile.gd").ai_income(world, n.id) * (1.0 + 0.05 * floorf(float(n.get("tech", 0.0)))) * (world.support.ai_income_mult(n.id) if world.get("support") != null else 1.0) * (world.events.ai_income_mult(n.id) if world.get("events") != null else 1.0) * (world.wmd.ai_income_mult(n.id) if world.get("wmd") != null else 1.0) * (world.directorate.ai_income_mult(n.id) if world.get("directorate") != null and world.directorate != null else 1.0)   # the home front; world events; sick towns; its AI economy
	var cyber: bool = spies != null and spies.production_down(n.id) or preload("res://scripts/faction_powers.gd").production_blocked(world, n.id)
	n.age = float(n.get("age", 0.0)) + delta   # (its own clock, for the buildings set aside)
	n.next_build -= delta * (1.0 + preload("res://scripts/additional_powers.gd").bonus(world, n.id, "buildPct"))
	n.next_train -= delta * (world.un.production_mult(n.id) if world.get("un") != null and world.un != null else 1.0) * maxf(0.1, 1.0 + float(preload("res://scripts/additional_factions.gd").profile(world, n.id).get("bonus", {}).get("prodPct", 0.0)) + preload("res://scripts/additional_powers.gd").bonus(world, n.id, "prodPct"))
	n.next_attack -= delta
	n.next_defend -= delta

	# Construction: fixed opening, then whatever the economy lacks.
	if n.next_build <= 0.0 and not cyber:
		var key: String = build_order[n.build_idx] if n.build_idx < build_order.size() else pick_building(n)
		if not preload("res://scripts/national_variants.gd").builds(world, n.id, key):
			key = ""   # (no reactor for Afghanistan): the next in the order
			if n.build_idx < build_order.size(): n.build_idx += 1
		elif preload("res://scripts/progression.gd").building_blocked(world, n.id, key) != "":
			key = pick_building(n)   # not open yet in its era: something that is, and the opening waits
		var def: Dictionary = world.building_defs.get(key, {})
		if not def.is_empty():
			var cost := weighted_cost(preload("res://scripts/additional_factions.gd").building_cost(world, n.id, key, def.get("base_cost", def.cost)))
			if n.money >= cost:
				var spot = find_spot(n, home, key)
				if spot != null:
					n.money -= cost
					var site: Dictionary = world.place_building(key, spot, n.id, false)
					site.ai_build = true
					world.close_navigation(site.root.position, world.DISTRICT_NAV_SIZE if world.is_district(key) else site.footprint)
					world.refresh_streets()
					if n.build_idx < build_order.size():
						n.build_idx += 1
				elif n.build_idx < build_order.size():
					n.build_idx += 1  # no room for this one: move on
				else:
					# No room for it now: set it aside for 90 s, so one building
					# that fits nowhere does not stop all the others.
					if not n.has("no_room"): n.no_room = {}
					n.no_room[key] = float(n.get("age", 0.0)) + 90.0
		var total: int = world.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
		n.next_build = maxf(6.0, float(row(n).buildEvery) * randf_range(0.7, 1.1) - total * 0.3) / s

	# Land: a nation with money to spare buys some at its town halls (as the player does).
	if n.money > 3500.0 and world.territory != null and randf() < delta * s * 0.02:
		world.territory.ai_purchase(n.id)

	# Self-building: AI sites rise on their own.
	for b in world.buildings:
		if b.owner == n.id and not b.built and not b.dead and b.get("ai_build", false) and not cyber:
			b.progress = minf(1.0, b.progress + delta * s * preload("res://scripts/additional_factions.gd").construction_mult(world, n.id) * (1.0 + preload("res://scripts/additional_powers.gd").bonus(world, n.id, "buildPct")) / maxf(float(b.def.buildTime), 8.0))
			b.model.scale.y = b.full_scale_y * lerpf(0.06, 1.0, b.progress)
			if b.progress >= 1.0:
				world.finish_building(b)

	# Training.
	if n.next_train <= 0.0 and not cyber:
		var army: Array = world.units.filter(func(u): return u.owner == n.id and not u.dead)
		if army.size() < int(row(n).maxArmy):
			var options: Array = train_pool.filter(func(k): return world.unit_allowed(n.id, k) and preload("res://scripts/additional_factions.gd").ai_unlocked(world, n.id, k) and preload("res://scripts/progression.gd").unit_blocked(world, n.id, k) == "" and not production_sites(n.id,k).is_empty())
			if not options.is_empty():
				var key: String = options[randi() % options.size()]
				var cost := weighted_cost(world.unit_defs[key].cost) * preload("res://scripts/national_profile.gd").cost_mult(world, n.id, key)
				# Money for the next building is kept back, unless the nation is at
				# war or has hardly an army: a state that only trains never grows.
				var at_war: bool = not world.diplomacy.enemies_of(n.id).is_empty()
				var next_key: String = build_order[n.build_idx] if n.build_idx < build_order.size() else pick_building(n)
				var next_def: Dictionary = world.building_defs.get(next_key, {"cost": {}})
				var reserve: float = 0.0 if at_war or army.size() < 4 else weighted_cost(preload("res://scripts/additional_factions.gd").building_cost(world, n.id, next_key, next_def.get("base_cost", next_def.cost)))
				if n.money - cost >= reserve:
					if deploy(n.id,key):
						n.money -= cost
						n.train_mult = preload("res://scripts/additional_factions.gd").train_mult(world, n.id, key)
						n.train_mult /= float(preload("res://scripts/additional_factions.gd").UNITS.get(key, {}).get("scale", {}).get("trainTime", 1.0))
		n.next_train = float(row(n).trainEvery) / float(n.get("train_mult", 1.0)) * randf_range(0.8, 1.2) * (0.55 if not world.diplomacy.enemies_of(n.id).is_empty() else 1.0) / s

	# Defence: a threat near the capital brings every unit home.
	if n.next_defend <= 0.0:
		n.next_defend = 4.0
		var centre: Vector3 = home.root.position
		for u in world.units:
			if u.dead or u.owner == n.id or not world.hostile(n.id, u.owner):
				continue
			if u.node.position.distance_to(centre) < 70.0:
				var defenders: Array = world.units.filter(func(d): return d.owner == n.id and available(d) and world.effectiveness(d,u)>0)
				if defenders.is_empty():
					# Nothing at home can hurt it (riflemen against a tank): it raises
					# what can, at once, rather than watching the enemy at its gates.
					var answer := _answer_to(n, u)
					if answer != "" and float(n.money) >= weighted_cost(world.unit_defs[answer].get("cost", {})) and deploy(n.id, answer):
						n.money -= weighted_cost(world.unit_defs[answer].get("cost", {}))
						defenders = world.units.filter(func(d): return d.owner == n.id and available(d) and world.effectiveness(d,u)>0)
				if not defenders.is_empty():
					world.order_attack(defenders, u)
					break

	# Attack waves.
	# Agents inside the nation (intel 60+) report an attack half a minute early.
	if spies and n.next_attack > 0.0 and n.next_attack * s < 30.0 and not n.get("warned", false) and world.diplomacy.at_war(0, n.id):
		n.warned = true
		spies.warn_attack(n.id)
	if n.next_attack <= 0.0 and not (spies and spies.paralyzed(n.id)):
		n.warned = false
		n.next_attack = float(row(n).firstAttack) * randf_range(0.55, 1.05) / s
		var d: Node = world.diplomacy
		if d.enemies_of(n.id).is_empty() and randf() < float(row(n).aggression):
			# Pick the most hated neighbour it is willing to fight.
			var worst := -1
			for i in range(d.n):
				if i != n.id and not d.defeated(i) and d.ai_wants_war(n.id, i) and (worst < 0 or d.rel(n.id, i) < d.rel(n.id, worst)):
					worst = i
			if worst == 0:
				# A government does not go to war over every grievance. Unless
				# relations have collapsed it strikes across the border first
				# and calls it a limited operation, and waits to see how the
				# player's cabinet answers.
				if world.engagement != null and d.rel(n.id, 0) > -70.0 and not world.engagement.active(0, n.id) and randf() < 0.6:
					world.engagement.raid(n.id)
				else:
					declare_war(n.id, false)
			elif worst > 0:
				d.declare_war(n.id, worst)
		var enemies: Array = d.enemies_of(n.id)
		if not enemies.is_empty():
			var army: Array = world.units.filter(func(u): return u.owner == n.id and available(u) and not u.get("naval",false))
			var guard: int = mini(3, army.size() / 4)
			var squad: Array = army.slice(guard, guard + maxi(int(row(n).squad), int(army.size() * 0.6)))
			var target = nearest_enemy_asset(home.root.position, enemies, n.id)
			if squad.size() >= maxi(3, int(row(n).squad) - 2) and target != null:
				world.order_move(squad, target.root.position, true)
				if target.owner == 0:
					world.hud.notice("%s forces are advancing on you." % n.name)
			n.next_attack = minf(n.next_attack, float(row(n).firstAttack) * 0.35 / s)

	# Missile strikes: a nation at full war with the player, with the
	# technology for it, fires at the player's towns and bases now and then.
	# Air defence may intercept them (modern_warfare.gd).
	if world.diplomacy.at_war(0, n.id) and world.missiles != null and world.match_config.get("style", "standard") != "sandbox":
		var tech: float = float(n.get("tech", 0.0))
		if tech >= 2.0:
			n.next_missile = float(n.get("next_missile", 240.0 / s)) - delta
			if n.next_missile <= 0.0 and n.money > 600.0:
				n.next_missile = randf_range(200.0, 320.0) / s
				missile_strike(n, home, tech)

## Fires one missile at one of the player's important buildings.
func missile_strike(n: Dictionary, home: Dictionary, tech: float) -> Dictionary:
	var kinds: Array = []
	for row in STRIKE_TYPES:
		if tech >= float(row[0]):
			kinds = row[1]
	# Only the missiles this nation really has (national_variants.gd: hypersonic ones).
	var me: String = preload("res://scripts/national_arsenal.gd").identity(world, n.id)
	kinds = kinds.filter(func(k): return world.missiles.available_to(n.id, k) and not world.missiles.platforms_for(k, n.id).is_empty())
	if kinds.is_empty():
		return {}
	# Only what it has found of the player's (fog_of_war.gd: its capital is known to all).
	var targets: Array = world.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.built and b.key in STRIKE_TARGETS and (world.fog == null or world.fog.rival_knows(n.id, b)))
	if targets.is_empty():
		return {}
	var target: Dictionary = targets[randi() % targets.size()]
	var key: String = kinds[randi() % kinds.size()]
	# The anti-radiation missile only for an air-defence site it knows of.
	if key == "antiRadar":
		var sams: Array = targets.filter(func(b): return b.key == "samSite")
		if sams.is_empty():
			if not "cruise" in kinds: return {}
			key = "cruise"
		else:
			target = sams[randi() % sams.size()]
	n.money -= 400.0
	var platforms: Array = world.missiles.platforms_for(key, n.id)
	var source: Dictionary = platforms[randi() % platforms.size()]
	var m: Dictionary = world.missiles.fly(key, source.node.position + Vector3.UP * 3.0, target.root.position, n.id, not source.get("is_building", false))
	world.hud.notice("%s launched a %s at your %s." % [n.name, load("res://scripts/arsenal_catalog.gd").missile_name(world, n.id, key), target.def.name])
	return m

# Money-equivalent price (ai.js weights materials the AI does not stockpile).
func available(u: Dictionary) -> bool:
	return not u.dead and (u.dmg>0 or u.key in load("res://scripts/force_catalog.gd").SCOUTS) and not world.disabled(u) and (not u.get("fly",false) or u.get("air_state","ready")=="ready" and u.get("ammo",0)>0)

func production_sites(owner: int, key: String) -> Array:
	var home: String = load("res://scripts/force_catalog.gd").HOME.get(key, preload("res://scripts/additional_factions.gd").HOME.get(key, TRAINED_AT.get(key, "")))
	return world.buildings.filter(func(b):return b.owner==owner and b.key==home and b.built and not b.dead and b.get("supplied",true) and not world.disabled(b))

## The unit rival `n` raises against a threat its army cannot hurt: anti-armour
## infantry against vehicles, air defence against aircraft, whichever its nation fields.
func _answer_to(n: Dictionary, threat: Dictionary) -> String:
	var options: Array = ["samLauncher", "aaVehicle", "manpads"] if threat.get("fly", false) else ["rocketSoldier", "atgmTeam", "tank"]
	for key in options:
		if world.unit_defs.has(key) and world.unit_allowed(n.id, key) and not production_sites(n.id, key).is_empty():
			return key
	return ""

func deploy(owner: int, key: String) -> bool:
	for site in production_sites(owner,key):
		var at: Vector3 = site.root.position
		var door = world.water_near(at) if key in world.NAVAL else world.land_point(at+Vector3(site.footprint*0.7+5,0,0),20.0)
		if door==null:
			continue
		var unit: Dictionary = world.spawn_unit(key,door,owner)
		if key == "sixthGen":
			preload("res://scripts/future_weapons.gd").escort(world, unit)
		elif world.get("directorate") != null and world.directorate != null:
			world.directorate.escort_fighter(unit)   # a loyal wingman (Collaborative Combat Aircraft)
		var out: Vector3 = door-at
		unit.heading = atan2(out.x,out.z)
		world.place_on_ground(unit,door)
		return true
	return false

func weighted_cost(cost: Dictionary) -> float:
	return float(cost.get("money", 0)) + float(cost.get("iron", 0)) * 2.0 + float(cost.get("oil", 0)) * 3.0 + float(cost.get("silicon", 0)) * 4.0

# After the opening, a city plan: a nation grows as a state, not only as an
# army. Economic and civic goals have target counts that rise as the nation
# grows; military buildings are kept to about a third of everything built
# (more while at war). The first goal still short of its target is built.
# New towns come before the plan (pick_building): a capital and one village
# was all a rival ever had.
const CITY_PLAN := [
	# [key, how many per 10 buildings the nation owns (at least 1)]
	["farm", 1.6], ["cottage", 1.4], ["market", 0.6], ["warehouse", 0.6], ["extractor", 1.0],
	["school", 0.5], ["foodDepot", 0.4], ["park", 0.5], ["hospital", 0.3], ["library", 0.3],
	["residential", 0.8], ["powerPlant", 0.4], ["bank", 0.3], ["port", 0.2], ["university", 0.2],
	["policeStation", 0.3], ["fishingWharf", 0.3], ["oilRefinery", 0.2], ["techPark", 0.15],
]
const MILITARY_PLAN := [["barracks", 0.8], ["housing", 1.2], ["tankFactory", 0.4], ["ammoDepot", 0.3],
	["helipad", 0.2], ["airfield", 0.15], ["shipyard", 0.15], ["bunker", 0.3], ["samSite", 0.2], ["commandCenter", 0.1]]

func pick_building(n: Dictionary) -> String:
	var mine: Array = world.buildings.filter(func(b): return b.owner == n.id and not b.dead)
	var counts := {}
	var military := 0
	for b in mine:
		counts[b.key] = int(counts.get(b.key, 0)) + 1
		if b.def.get("cat", "") == "military":
			military += 1
	var total := maxi(mine.size(), 1)
	var share := float(military) / total
	var want_military: float = 0.45 if world.diplomacy != null and not world.diplomacy.enemies_of(n.id).is_empty() else 0.3
	# A state spreads: a new town for every 7 buildings it owns, a city for every
	# two villages, before anything else (unless there was no room for it lately).
	var villages := int(counts.get("villageCenter", 0))
	var cities := int(counts.get("cityCenter", 0))
	if villages + cities < total / 7:
		var town := "cityCenter" if cities * 2 < villages else "villageCenter"
		if float(n.get("no_room", {}).get(town, 0.0)) <= float(n.get("age", 0.0)) and preload("res://scripts/national_variants.gd").builds(world, n.id, town) and preload("res://scripts/progression.gd").building_blocked(world, n.id, town) == "":
			return town
	# Its weapons of mass destruction need their facilities (wmd.armed): a nation
	# that has them builds a Strategic Weapons Complex once its technology
	# allows, a second in a war, and a Special Weapons Laboratory.
	var tech: float = float(n.get("tech", 0.0))
	var NV := preload("res://scripts/national_variants.gd")
	var wanted_complexes: int = 0 if tech < 5.0 else (2 if tech >= 7.0 and world.diplomacy != null and not world.diplomacy.enemies_of(n.id).is_empty() else 1)
	# Its AI (ai_directorate.gd): data centres as its technology and national
	# compute allow, and a Targeting Fusion Cell once it has military AI.
	var compute_rating: int = preload("res://scripts/ai_data.gd").rating(world, n.id, "compute")
	var wanted_dc: int = 0 if tech < 4.0 else (2 if tech >= 6.0 and compute_rating >= 3 else 1)
	var wanted_cell: int = 1 if tech >= 5.0 and world.get("directorate") != null and world.directorate != null and world.directorate.level(n.id) >= 3 else 0
	for fac in [["missileSilo", 1 if tech >= 2.0 else 0], ["strategicComplex", wanted_complexes], ["specialLab", 1 if tech >= 4.0 else 0], ["aiDataCenter", wanted_dc], ["fusionCell", wanted_cell]]:
		var fkey: String = fac[0]
		if int(counts.get(fkey, 0)) < int(fac[1]) and world.building_defs.has(fkey) and NV.builds(world, n.id, fkey) and preload("res://scripts/progression.gd").building_blocked(world, n.id, fkey) == "" and float(n.get("no_room", {}).get(fkey, 0.0)) <= float(n.get("age", 0.0)):
			return fkey
	var plans := [MILITARY_PLAN, CITY_PLAN] if share < want_military else [CITY_PLAN, MILITARY_PLAN]
	for plan in plans:
		var short := []
		for goal in plan:
			var key: String = goal[0]
			if not world.building_defs.has(key):
				continue
			if float(n.get("no_room", {}).get(key, 0.0)) > float(n.get("age", 0.0)):
				continue   # no room for it lately: the next goal instead
			var def: Dictionary = world.building_defs[key]
			if def.get("unique", false) and counts.get(key, 0) > 0:
				continue
			if not preload("res://scripts/national_variants.gd").builds(world, n.id, key) or preload("res://scripts/progression.gd").building_blocked(world, n.id, key) != "":
				continue
			var target := maxi(1, int(ceil(total / 10.0 * float(goal[1]))))
			if int(counts.get(key, 0)) < target:
				short.append(key)
		if not short.is_empty():
			# The first two unmet goals, in order of the plan, with a little variety.
			return short[0] if short.size() == 1 or randf() < 0.7 else short[1]
	return ["farm", "cottage", "market", "barracks"][randi() % 4]

func find_spot(n: Dictionary, home: Dictionary, key: String):
	var def: Dictionary = world.building_defs[key]
	var centre: Vector3 = home.root.position
	if def.get("onDeposit", false):
		var best = null
		var best_d := 300.0
		for d in world.deposits:
			if d.extractor == null and not d.get("water", false) and d.pos.distance_to(centre) < best_d:
				best_d = d.pos.distance_to(centre)
				best = d
		return Vector3(best.pos.x, best.pos.y, best.pos.z) if best != null else null
	# A city grows hex by hex: first try free hexes touching its own districts.
	if def.get("settlement") == null:
		var options := []
		for hex in world.district_hex:
			var owned = world.district_hex[hex]
			if owned.dead or owned.owner != n.id:
				continue
			for d in world.logistics.DIRECTIONS:
				options.append(hex + d)
		# By zone and in the nation's own style (city_planner.gd), not the first free hex.
		var planned = preload("res://scripts/city_planner.gd").best(world, n.id, key, options)
		if planned != null:
			return planned
	if def.get("settlement") != null:
		# A new town stands 75-130 m out from one of the nation's towns (the
		# capital or any village or city), so the state spreads outward.
		var towns: Array = world.buildings.filter(func(b): return b.owner == n.id and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"])
		towns.shuffle()
		for town in towns.slice(0, 4):
			for attempt in range(12):
				var a := randf() * TAU
				var at: Vector3 = world.snap_to_hex(town.root.position + Vector3(cos(a), 0, sin(a)) * randf_range(75.0, 130.0))
				if world.site_problem(key, at, n.id) == "":
					return at
		return null
	for attempt in range(24):
		var a := randf() * TAU
		var at: Vector3 = world.snap_to_hex(centre + Vector3(cos(a), 0, sin(a)) * randf_range(18.0, 56.0))
		if world.site_problem(key, at, n.id) == "":
			return at
	return null

func nearest_enemy_asset(from: Vector3, enemies: Array, seeker := -1):
	var best = null
	var best_d := INF
	for b in world.buildings:
		if b.owner in enemies and not b.dead and (seeker < 0 or world.fog == null or world.fog.rival_knows(seeker, b)):
			var d: float = b.root.position.distance_to(from)
			if d < best_d:
				best_d = d
				best = b
	return best
