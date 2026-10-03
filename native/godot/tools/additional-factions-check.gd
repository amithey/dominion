extends SceneTree
const F := preload("res://scripts/additional_factions.gd")
const FA := preload("res://scripts/factions.gd")
const P := preload("res://scripts/additional_powers.gd")
const FP := preload("res://scripts/faction_powers.gd")
const M := preload("res://scripts/modern_warfare.gd")
var w: Node
var failures: Array[String] = []
var passed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: failures.append(label)
func set_nation(owner: int, id: String) -> void:
	w.map.nations[owner] = FA.nation(FA.IDS.find(id), owner == 0)
	if owner == 0: w.research._recompute()
func building(key: String, owner := 0) -> Dictionary:
	var b: Dictionary = w.place_building(key, w.start + Vector3(15 + owner * 80, 0, 15), owner, true)
	b.supplied = true
	return b
func provision(owner: int) -> void:
	if owner == 0: w.economy.grant_test_resources()
	else: P.nation(w, owner).money = 100000
	for r in ["food", "iron", "oil", "silicon", "uranium", "gas"]: P.stock(w, owner)[r] = 400.0
func reset_power() -> void:
	w.power_ready.clear()
	w.power_effects.clear()
	provision(0)
	provision(1)
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, false)
	w.diplomacy.set_flag(w.diplomacy.pact, 0, 1, true)
	w.diplomacy.set_flag(w.diplomacy.alliance, 0, 1, true)
func tick(seconds: float) -> void:
	w.game_time += seconds
	P.step(w, seconds)
func run() -> void:
	set_meta("match_config", {"nation": 10, "players": 4, "map": "island", "style": "sandbox", "rivals": [9, 16, 18]})
	change_scene_to_file("res://world.tscn")
	for i in range(10000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	check(w.map.nations.map(func(n): return n.id) == ["south_korea", "uk", "egypt", "pakistan"], "new roster launches with all four selected identities")
	check(is_equal_approx(w.research.bonus("researchPct"), 0.2), "Korean research modifier reaches the research engine")
	provision(0)
	var homes := {}
	for key in ["tankFactory", "airfield", "shipyard", "port", "bank", "techPark", "farm", "school", "powerPlant", "barracks"]: homes[key] = building(key)
	building("port", 1)
	building("port", 2)
	var field: Vector3 = w.land_point(w.start, 30)
	var sea: Vector3 = w.water_near(w.start, 240)
	for key in F.UNITS:
		var id: String = F.UNITS[key].nation
		set_nation(0, id)
		check(w.research.unit_locked(key).begins_with("Needs"), key + " requires its research")
		w.research.progress[F.UNITS[key].requires] = {"stage": 3}
		check(w.research.unit_locked(key) == "", key + " unlocks for its nation")
		var factory: Dictionary = homes[F.HOME[key]]
		var balance: float = w.economy.res.money
		w.queue_unit(factory, key)
		check(factory.queue.has(key) and w.economy.res.money < balance, key + " queues and charges resources")
		w.cancel_queued(factory, 0)
		check(is_equal_approx(w.economy.res.money, balance), key + " cancellation refunds exactly")
		var u: Dictionary = w.spawn_unit(key, sea if key in w.NAVAL else field, 0)
		check(u.node.get_child_count() > 0 and u.hp > 0.0, key + " spawns with model and health")
		if key == "k9": check(is_equal_approx(u.speed, w.TANK_SPEED * 1.15), "K9 speed bonus reaches movement")
		if key == "heavyRocket": check(is_equal_approx(u.speed, w.TANK_SPEED * 0.8), "heavy launcher speed penalty reaches movement")
		if key == "superTucano":
			check(w.effectiveness(u, w.spawn_unit("jet", field, 1)) == 0.0, "A29 cannot target fighters")
		if key == "interceptorDrone":
			check(w.effectiveness(u, w.spawn_unit("jet", field, 1)) == 0.0 and w.effectiveness(u, w.spawn_unit("soldier", field, 1)) == 0.0 and w.effectiveness(u, w.spawn_unit("shahed", field, 1)) > 0.0, "interceptor engages drones only")
		if w.WEAPONS.has(key):
			w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)
			var target_key := "shahed" if key in ["type45", "interceptorDrone"] else ("corvette" if key == "kcr60" else "tank")
			var enemy: Dictionary = w.spawn_unit(target_key, (sea if key in w.NAVAL else field) + Vector3(12, 0, 0), 1)
			var before_hit: float = enemy.hp
			w.fire_weapon(u, enemy, w.WEAPONS[key])
			for frame in range(240): w.effects._physics_process(1.0 / 30.0)
			check(enemy.dead or enemy.hp < before_hit, key + " projectile hits a valid target in live combat")
			w.kill(enemy)
		w.kill(u)
		set_nation(0, "usa")
		check(w.research.unit_locked(key).ends_with("only"), key + " remains exclusive")
		set_nation(1, id)
		var rival_factory := building(F.HOME[key], 1)
		P.nation(w, 1).tech = 0.0
		check(not F.ai_unlocked(w, 1, key), key + " AI cannot skip research")
		P.nation(w, 1).tech = 10.0
		check(F.ai_unlocked(w, 1, key) and w.ai.production_sites(1, key).has(rival_factory) and w.ai.deploy(1, key), key + " AI can deploy from its proper facility")
		w.research.progress.clear()
	P.nation(w, 1).tech = 0.0
	check(M.intercept_chance(w, "saudiThaad", {"type":"cruise", "owner":1}, 0) == 0.0 and M.intercept_chance(w, "saudiThaad", {"type":"ballistic", "owner":1}, 0) > 0.8, "THAAD intercepts ballistic missiles but not cruise missiles")
	set_nation(0, "south_korea")
	w.research._bonus.rangeArty = 0.2
	w.research._bonus.dmgArty = 0.25
	var upgraded: Dictionary = w.spawn_unit("k9", field, 0)
	check(is_equal_approx(upgraded.range, float(w.unit_defs.k9.range) * 1.2) and w.research.damage_mult(upgraded) >= 1.25, "K9 receives existing artillery range and damage upgrades")
	w.research._recompute()
	set_nation(0, "australia")
	var protected: Dictionary = w.spawn_unit("bushmaster", field, 0)
	var protected_hp: float = protected.hp
	w.damage(protected, 40.0, {"key":"artillery", "owner":1, "dead":true})
	check(is_equal_approx(protected_hp - protected.hp, 30.0), "Bushmaster reduces actual explosive damage by 25 percent")
	for owner in [0, 1]:
		for id in F.IDS:
			reset_power()
			set_nation(owner, id)
			var target: int = 1 if owner == 0 else 0
			for need in P.POWERS[id].needs: building(need, owner)
			if id == "uk": w.spawn_unit("type45", sea, owner)
			if id == "north_korea": w.spawn_unit("heavyRocket", field, owner)
			if id == "ukraine":
				var hq: Dictionary = w.buildings.filter(func(b): return b.owner == owner and b.key == "hq")[0]
				hq.hp = hq.max_hp * 0.5
			if id == "australia":
				var mine := building("extractor", owner)
				mine.deposit = w.deposits[0]
			if id == "syria": w.diplomacy.set_score(owner, target, 45.0)   # a partner to pay for the rebuilding
			if id == "afghanistan":
				w.diplomacy.set_flag(w.diplomacy.war, owner, target, true)   # insurgent attacks only on an enemy
				building("farm", target)
			var resource: String = P.POWERS[id].costs.keys()[0]
			var balance := P.funds(w, owner, resource)
			check(FP.blocked(w, owner, target) == "", "%s owner %d prerequisites met" % [id, owner])
			FP.use(w, owner, target)
			check(P.funds(w, owner, resource) == balance - float(P.POWERS[id].costs[resource]) and FP.ready_in(w, owner) > 0.0, "%s owner %d pays and enters cooldown" % [id, owner])
			var after := P.funds(w, owner, resource)
			FP.use(w, owner, target)
			check(P.funds(w, owner, resource) == after, id + " repeated activation cannot charge twice")
	# Effects reach live systems, then expire.
	reset_power()
	set_nation(0, "south_korea")
	var tank_factory: Dictionary = homes.tankFactory
	w.queue_unit(tank_factory, "tank")
	w.update_training(1.0)
	var first: float = tank_factory.queue_prog
	FP.use(w, 0)
	tank_factory.queue_prog = 0.0
	w.update_training(1.0)
	check(tank_factory.queue_prog > first, "industrial mobilization accelerates actual production")
	tank_factory.supplied = false
	var stopped: float = tank_factory.queue_prog
	w.update_training(1.0)
	check(tank_factory.queue_prog == stopped, "industrial bonus cannot bypass a supply cut")
	tank_factory.supplied = true
	tick(91)
	check(is_equal_approx(w.research.bonus("prodPct"), 0.15), "temporary production bonus expires")
	reset_power()
	set_nation(0, "indonesia")
	w.economy.tick()
	var health: float = w.economy.health
	FP.use(w, 0)
	w.economy.tick()
	check(w.economy.health == health + 8.0, "nutrition improves actual civilian health")
	reset_power()
	set_nation(0, "pakistan")
	FP.use(w, 0, 1)
	check(P.bonus(w, 0, "researchPct") == 0.15 and P.bonus(w, 1, "researchPct") == 0.15, "both allies receive joint research")
	w.diplomacy.set_flag(w.diplomacy.alliance, 0, 1, false)
	check(P.bonus(w, 0, "researchPct") == 0.0 and P.bonus(w, 1, "researchPct") == 0.0, "breaking alliance removes both bonuses immediately")
	tick(1.0)
	w.diplomacy.set_flag(w.diplomacy.alliance, 0, 1, true)
	check(P.bonus(w, 0, "researchPct") == 0.0, "renewing an alliance does not resurrect an expired partnership")
	reset_power()
	set_nation(0, "ukraine")
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	hq.hp = hq.max_hp * 0.5
	FP.use(w, 0)
	var save: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(save)
	hq = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var hp: float = hq.hp
	tick(30)
	check(is_equal_approx(hq.hp - hp, hq.max_hp * 0.125), "saved reconstruction resumes at the right rate")
	hq.owner = 1
	var captured_hp: float = hq.hp
	tick(10)
	check(hq.hp == captured_hp, "reconstruction cannot heal a captured building")
	hq.owner = 0
	reset_power()
	set_nation(0, "brazil")
	for b in w.buildings: b.supplied = true
	FP.use(w, 0, 1)
	var aid: Dictionary = w.power_effects[-1]
	w.power_effects.append({"kind":"hormuz", "by":2, "nation":0, "until":w.game_time + 60, "value":0.7})
	tick(10)
	check(aid.eta == 30.0, "closed strait pauses food aid")
	w.power_effects.pop_back()
	w.market.sabotaged = 1
	var food := P.funds(w, 1, "food")
	tick(31)
	check(P.funds(w, 1, "food") == food and w.market.sabotaged == 0, "sabotage destroys aid without awarding food")
	# AI shipping uses actual stocks and money and preserves cargo across JSON saves.
	set_nation(1, "egypt")
	set_nation(2, "uk")
	provision(1); provision(2)
	w.diplomacy.set_flag(w.diplomacy.war, 1, 2, false)
	w.diplomacy.set_flag(w.diplomacy.pact, 1, 2, true)
	P.use_logistics_hub(w, 1)
	preload("res://scripts/additional_trade.gd").tick(w, 1.0)
	var cargo: Dictionary = P.nation(w, 1).get("national_cargo", {})
	check(not cargo.is_empty() and is_equal_approx(cargo.eta, float(w.market.cfg.voyage) * 0.7), "Egypt AI sends real cargo with shorter journey")
	var json_save: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(json_save.ai[0].has("national_cargo"), "AI cargo is included in disk-save data")
	var generator = preload("res://scripts/map_generator.gd").new()
	for map_key in ["middle_east", "europe", "east_asia"]:
		generator.style = map_key
		generator.size = float(generator.MAPS[map_key].size)
		generator.half = generator.size * 0.5
		generator.starts = generator._start_positions()
		var slots: Array = preload("res://scripts/world_geography.gd").MAPS[map_key].starts
		for slot in range(slots.size()):
			var id: String = F.CITY_FACTIONS.get(str(slots[slot][3]), "")
			if id == "": continue
			var positions: Array = generator._real_starts([FA.nation(FA.IDS.find(id))], 1)
			check(positions[0] == generator.starts[slot], id + " starts at its existing capital slot in " + map_key)
	for id in F.IDS:
		set_meta("match_config", {"nation": FA.IDS.find(id), "players": 2, "map": "island", "style": "sandbox"})
		change_scene_to_file("res://world.tscn")
		w = null
		for frame in range(10000):
			await process_frame
			if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
				w = current_scene
				break
		if w == null: check(false, id + " failed to load"); continue
		w.start_match("easy")
		w.set_physics_process(false)
		w.ai.set_physics_process(false)
		check(w.map.nations[0].id == id and w.units.any(func(u): return u.owner == 0 and u.key == "worker") and not FP.power_of(w, 0).is_empty(), id + " starts a fresh playable match with workers and national power")
		if id == "indonesia": check(w.building_defs.port.cost.money < w.building_defs.port.base_cost.money, "Indonesian building discount applied at match setup")
		if id == "egypt": check(w.unit_defs.worker.name == "Engineering Corps", "Egyptian worker specialty appears in production")
		if id == "north_korea":
			var bunker := building("bunker")
			check(is_equal_approx(bunker.max_hp, float(w.building_defs.bunker.hp) * 1.25), "North Korean bunker health applied on construction")
		if id == "australia": check(is_equal_approx(w.research.bonus("civCapPct"), -0.15), "Australian capacity tradeoff reaches economy")
	print("ADDITIONAL_FACTIONS: %d passed, %d failed" % [passed, failures.size()])
	print("ADDITIONAL_FACTIONS PASS" if failures.is_empty() else "ADDITIONAL_FACTIONS FAIL")
	quit(0 if failures.is_empty() else 1)
