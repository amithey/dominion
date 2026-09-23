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
var cfg: Dictionary      # the difficulty row
var build_order: Array
var train_pool: Array
var nations: Array[Dictionary] = []

# Which building each unit needs (ai.js).
const TRAINED_AT := {"soldier": "barracks", "rocketSoldier": "barracks", "commando": "barracks", "sniper": "barracks",
	"tank": "tankFactory", "apc": "tankFactory", "artillery": "tankFactory", "samLauncher": "tankFactory",
	"helicopter": "helipad", "jet": "airfield", "drone": "airfield", "gunboat": "shipyard", "destroyer": "shipyard", "corvette": "shipyard"}

func setup(world_node: Node, ai: Dictionary, difficulty: String, speed := 1.0) -> void:
	world = world_node
	cfg = ai.difficulty.get(difficulty, ai.difficulty.easy)
	build_order = ai.buildOrder
	# Only units the native world can draw yet (no aircraft).
	train_pool = ai.trainPool.filter(func(k): return TRAINED_AT.has(k))
	for id in range(1, world.map.nations.size()):
		nations.append({
			"id": id, "name": world.map.nations[id].name, "money": 400.0, "build_idx": 0,
			"next_build": (14.0 + randf() * 14.0) / speed, "next_train": (22.0 + randf() * 12.0) / speed,
			"next_attack": float(cfg.firstAttack) * (0.9 + randf() * 0.4) / speed,
			"next_defend": 5.0, "at_war": false, "defeated": false, "speed": speed,
		})

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
			n.next_attack = minf(n.next_attack, float(cfg.firstAttack) * 0.35 / n.speed)

func _physics_process(delta: float) -> void:
	if world == null or world.economy == null:
		return
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
	n.money += float(cfg.income) * delta * s * (spies.income_mult(n.id) if spies else 1.0) * (1.0 + 0.05 * floorf(float(n.get("tech", 0.0))))
	var cyber: bool = spies != null and spies.production_down(n.id)
	n.next_build -= delta
	n.next_train -= delta
	n.next_attack -= delta
	n.next_defend -= delta

	# Construction: fixed opening, then whatever the economy lacks.
	if n.next_build <= 0.0 and not cyber:
		var key: String = build_order[n.build_idx] if n.build_idx < build_order.size() else pick_building(n)
		var def: Dictionary = world.building_defs.get(key, {})
		if not def.is_empty():
			var cost := weighted_cost(def.cost)
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
		var total: int = world.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
		n.next_build = maxf(6.0, float(cfg.buildEvery) * randf_range(0.7, 1.1) - total * 0.3) / s

	# Self-building: AI sites rise on their own.
	for b in world.buildings:
		if b.owner == n.id and not b.built and not b.dead and b.get("ai_build", false) and not cyber:
			b.progress = minf(1.0, b.progress + delta * s / maxf(float(b.def.buildTime), 8.0))
			b.model.scale.y = b.full_scale_y * lerpf(0.06, 1.0, b.progress)
			if b.progress >= 1.0:
				world.finish_building(b)

	# Training.
	if n.next_train <= 0.0 and not cyber:
		var army: Array = world.units.filter(func(u): return u.owner == n.id and not u.dead)
		if army.size() < int(cfg.maxArmy):
			var options: Array = train_pool.filter(func(k): return not production_sites(n.id,k).is_empty())
			if not options.is_empty():
				var key: String = options[randi() % options.size()]
				var cost := weighted_cost(world.unit_defs[key].cost)
				if n.money >= cost:
					if deploy(n.id,key):
						n.money -= cost
		n.next_train = float(cfg.trainEvery) * randf_range(0.8, 1.2) * (0.55 if not world.diplomacy.enemies_of(n.id).is_empty() else 1.0) / s

	# Defence: a threat near the capital brings every unit home.
	if n.next_defend <= 0.0:
		n.next_defend = 4.0
		var centre: Vector3 = home.root.position
		for u in world.units:
			if u.dead or u.owner == n.id or not world.hostile(n.id, u.owner):
				continue
			if u.node.position.distance_to(centre) < 70.0:
				var defenders: Array = world.units.filter(func(d): return d.owner == n.id and available(d) and world.effectiveness(d,u)>0)
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
		n.next_attack = float(cfg.firstAttack) * randf_range(0.55, 1.05) / s
		var d: Node = world.diplomacy
		if d.enemies_of(n.id).is_empty() and randf() < float(cfg.aggression):
			# Pick the most hated neighbour it is willing to fight.
			var worst := -1
			for i in range(d.n):
				if i != n.id and not d.defeated(i) and d.ai_wants_war(n.id, i) and (worst < 0 or d.rel(n.id, i) < d.rel(n.id, worst)):
					worst = i
			if worst == 0:
				declare_war(n.id, false)
			elif worst > 0:
				d.declare_war(n.id, worst)
		var enemies: Array = d.enemies_of(n.id)
		if not enemies.is_empty():
			var army: Array = world.units.filter(func(u): return u.owner == n.id and available(u) and not u.get("naval",false))
			var guard: int = mini(3, army.size() / 4)
			var squad: Array = army.slice(guard, guard + maxi(int(cfg.squad), int(army.size() * 0.6)))
			var target = nearest_enemy_asset(home.root.position, enemies)
			if squad.size() >= maxi(3, int(cfg.squad) - 2) and target != null:
				world.order_move(squad, target.root.position, true)
				if target.owner == 0:
					world.hud.notice("%s forces are advancing!" % n.name)
			n.next_attack = minf(n.next_attack, float(cfg.firstAttack) * 0.35 / s)

# Money-equivalent price (ai.js weights materials the AI does not stockpile).
func available(u: Dictionary) -> bool:
	return not u.dead and u.dmg>0 and not world.disabled(u) and (not u.get("fly",false) or u.get("air_state","ready")=="ready" and u.get("ammo",0)>0)

func production_sites(owner: int, key: String) -> Array:
	return world.buildings.filter(func(b):return b.owner==owner and b.key==TRAINED_AT.get(key,"") and b.built and not b.dead and b.get("supplied",true) and not world.disabled(b))

func deploy(owner: int, key: String) -> bool:
	for site in production_sites(owner,key):
		var at: Vector3 = site.root.position
		var door = world.water_near(at) if key in world.NAVAL else world.land_point(at+Vector3(site.footprint*0.7+5,0,0),20.0)
		if door==null:
			continue
		var unit: Dictionary = world.spawn_unit(key,door,owner)
		var out: Vector3 = door-at
		unit.heading = atan2(out.x,out.z)
		world.place_on_ground(unit,door)
		return true
	return false

func weighted_cost(cost: Dictionary) -> float:
	return float(cost.get("money", 0)) + float(cost.get("iron", 0)) * 2.0 + float(cost.get("oil", 0)) * 3.0 + float(cost.get("silicon", 0)) * 4.0

# After the opening: more farms when short of food, factories when rich.
func pick_building(n: Dictionary) -> String:
	var mine: Array = world.buildings.filter(func(b): return b.owner == n.id and not b.dead)
	var count := func(key): return mine.filter(func(b): return b.key == key).size()
	if count.call("barracks") < 2:
		return "barracks"
	if count.call("tankFactory") < 1 and n.money > 900:
		return "tankFactory"
	if count.call("housing") < 3:
		return "housing"
	if n.money > 1200 and count.call("helipad") < 1:
		return "helipad"
	if n.money > 1200 and count.call("shipyard") < 1:
		return "shipyard"
	return ["farm", "housing", "barracks", "warehouse", "extractor"][randi() % 5]

func find_spot(n: Dictionary, home: Dictionary, key: String):
	var def: Dictionary = world.building_defs[key]
	var centre: Vector3 = home.root.position
	if def.get("onDeposit", false):
		var best = null
		var best_d := 300.0
		for d in world.deposits:
			if d.extractor == null and d.pos.distance_to(centre) < best_d:
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
		options.shuffle()
		for hex in options:
			var at: Vector3 = world.logistics.hex_center(hex)
			if world.site_problem(key, at, n.id) == "":
				return at
	for attempt in range(24):
		var a := randf() * TAU
		# New settlements stand well apart (ai.js: villages 65-110 m, cities 90-135 m).
		var r := randf_range(75.0, 120.0) if def.get("settlement") != null else randf_range(18.0, 56.0)
		var at: Vector3 = world.snap_to_hex(centre + Vector3(cos(a), 0, sin(a)) * r)
		if world.site_problem(key, at, n.id) == "":
			return at
	return null

func nearest_enemy_asset(from: Vector3, enemies: Array):
	var best = null
	var best_d := INF
	for b in world.buildings:
		if b.owner in enemies and not b.dead:
			var d: float = b.root.position.distance_to(from)
			if d < best_d:
				best_d = d
				best = b
	return best
