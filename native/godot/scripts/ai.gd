extends Node
## AI nations, ported from aiUpdate() in js/ai.js. The difficulty table,
## opening build order and training pool come from the map export.
## Each AI has an abstracted income, builds its opening order and then
## adaptively, self-builds (no workers), trains from the pool its buildings
## allow, rushes every unit home when its capital is threatened, and launches
## attack waves at the nearest player asset once it is at war.
## Diplomacy is not ported yet: an AI goes to war with the player when its
## attack timer comes up and its aggression roll succeeds, or at once if the
## player attacks it.

var world: Node
var cfg: Dictionary      # the difficulty row
var build_order: Array
var train_pool: Array
var nations: Array[Dictionary] = []

# Which building each unit needs (ai.js).
const TRAINED_AT := {"soldier": "barracks", "rocketSoldier": "barracks", "commando": "barracks", "sniper": "barracks",
	"tank": "tankFactory", "apc": "tankFactory", "artillery": "tankFactory", "samLauncher": "tankFactory"}

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
	for n in nations:
		if n.id == id:
			return n.at_war
	return false

## The player struck this nation (or it chose war).
func declare_war(id: int, provoked: bool) -> void:
	for n in nations:
		if n.id == id and not n.at_war and not n.defeated:
			n.at_war = true
			n.next_attack = minf(n.next_attack, float(cfg.firstAttack) * 0.35 / n.speed)
			world.hud.notice("%s %s" % [n.name, "retaliates: you are at war!" if provoked else "has declared war on you!"])

func _physics_process(delta: float) -> void:
	if world == null or world.economy == null:
		return
	for n in nations:
		if n.defeated:
			continue
		var home = hq(n.id)
		if home == null:
			n.defeated = true
			continue
		think(n, home, delta)

func think(n: Dictionary, home: Dictionary, delta: float) -> void:
	var s: float = n.speed
	n.money += float(cfg.income) * delta * s
	n.next_build -= delta
	n.next_train -= delta
	n.next_attack -= delta
	n.next_defend -= delta

	# Construction: fixed opening, then whatever the economy lacks.
	if n.next_build <= 0.0:
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
					world.close_navigation(spot, site.footprint)
					if n.build_idx < build_order.size():
						n.build_idx += 1
				elif n.build_idx < build_order.size():
					n.build_idx += 1  # no room for this one: move on
		var total: int = world.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
		n.next_build = maxf(6.0, float(cfg.buildEvery) * randf_range(0.7, 1.1) - total * 0.3) / s

	# Self-building: AI sites rise on their own.
	for b in world.buildings:
		if b.owner == n.id and not b.built and not b.dead and b.get("ai_build", false):
			b.progress = minf(1.0, b.progress + delta * s / maxf(float(b.def.buildTime), 8.0))
			b.model.scale.y = b.full_scale_y * lerpf(0.06, 1.0, b.progress)
			if b.progress >= 1.0:
				world.finish_building(b)

	# Training.
	if n.next_train <= 0.0:
		var army: Array = world.units.filter(func(u): return u.owner == n.id and not u.dead)
		if army.size() < int(cfg.maxArmy):
			var options: Array = train_pool.filter(func(k): return world.buildings.any(func(b): return b.owner == n.id and b.built and not b.dead and b.key == TRAINED_AT[k]))
			if not options.is_empty():
				var key: String = options[randi() % options.size()]
				var cost := weighted_cost(world.unit_defs[key].cost)
				if n.money >= cost:
					n.money -= cost
					var a := randf() * TAU
					var at: Vector3 = home.root.position + Vector3(cos(a), 0, sin(a)) * (home.footprint * 0.6 + 8.0)
					world.spawn_unit(key, at, n.id)
		n.next_train = float(cfg.trainEvery) * randf_range(0.8, 1.2) * (0.55 if n.at_war else 1.0) / s

	# Defence: a threat near the capital brings every unit home.
	if n.next_defend <= 0.0:
		n.next_defend = 4.0
		var centre: Vector3 = home.root.position
		for u in world.units:
			if u.dead or u.owner == n.id or not world.hostile(n.id, u.owner):
				continue
			if u.node.position.distance_to(centre) < 70.0:
				var defenders: Array = world.units.filter(func(d): return d.owner == n.id and not d.dead and d.dmg > 0.0)
				world.order_move(defenders, u.node.position, true)
				break

	# Attack waves.
	if n.next_attack <= 0.0:
		n.next_attack = float(cfg.firstAttack) * randf_range(0.55, 1.05) / s
		if not n.at_war and randf() < float(cfg.aggression):
			declare_war(n.id, false)
		if n.at_war:
			var army: Array = world.units.filter(func(u): return u.owner == n.id and not u.dead and u.dmg > 0.0)
			var guard: int = mini(3, army.size() / 4)
			var squad: Array = army.slice(guard, guard + maxi(int(cfg.squad), int(army.size() * 0.6)))
			var target = nearest_player_asset(home.root.position)
			if squad.size() >= maxi(3, int(cfg.squad) - 2) and target != null:
				world.order_move(squad, target.root.position, true)
				world.hud.notice("%s forces are advancing!" % n.name)
			n.next_attack = minf(n.next_attack, float(cfg.firstAttack) * 0.35 / s)

# Money-equivalent price (ai.js weights materials the AI does not stockpile).
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
	for attempt in range(24):
		var a := randf() * TAU
		var r := randf_range(18.0, 56.0)
		var at := centre + Vector3(cos(a), 0, sin(a)) * r
		at.y = world.height_at(at.x, at.z)
		if world.site_problem(key, at, n.id) == "":
			return at
	return null

func nearest_player_asset(from: Vector3):
	var best = null
	var best_d := INF
	for b in world.buildings:
		if b.owner == 0 and not b.dead:
			var d: float = b.root.position.distance_to(from)
			if d < best_d:
				best_d = d
				best = b
	return best
