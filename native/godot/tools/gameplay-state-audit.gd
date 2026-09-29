extends SceneTree
## Regressions for refunds and saving a match during active combat/policy.
const Powers = preload("res://scripts/faction_powers.gd")
const Factions = preload("res://scripts/factions.gd")
var w: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func site(key: String) -> Vector3:
	var at = w.test_site(key, w.start)
	assert(at != null, "test needs a valid " + key + " site")
	return at

func json_save() -> Dictionary:
	return JSON.parse_string(JSON.stringify(w.saves.capture()))

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.saves.autosave_every = 0
	paused = true
	seed(20260929)
	w.economy.grant_test_resources()
	# Iran pays 75% for missiles. Cancelling must return exactly that price.
	var original: Dictionary = w.map.nations[0].duplicate(true)
	w.map.nations[0] = Factions.nation(3, true)
	w.research._recompute()
	var silo: Dictionary = w.place_building("missileSilo", site("missileSilo"), 0, true)
	var before: Dictionary = w.economy.res.duplicate()
	w.missiles.produce(silo, "tactical")
	check(silo.queue.size() == 1, "discounted missile was queued")
	var paid: float = before.money - w.economy.res.money
	check(paid > 0 and paid < w.missiles.def_of("tactical").cost.money, "national missile discount was charged")
	w.cancel_queued(silo, 0)
	check(w.economy.res == before, "cancelled discounted missile refunds only what was paid")
	# Queue two differently priced orders, serialize, and cancel them out of order.
	w.missiles.produce(silo, "tactical")
	w.map.nations[0] = original
	w.research._recompute()
	w.missiles.produce(silo, "tactical")
	var queued_at: Vector3 = silo.root.position
	var queued_save := json_save()
	w.saves.restore(queued_save)
	silo = w.buildings.filter(func(b): return b.key == "missileSilo" and b.root.position.distance_to(queued_at) < 1)[0]
	w.cancel_queued(silo, 1)
	w.cancel_queued(silo, 0)
	check(w.economy.res == before, "saved queue retains the price of each individual order")
	# A researched unit discount can change while an older order waits.
	var barracks: Dictionary = w.place_building("tankFactory", site("tankFactory"), 0, true)
	w.economy.pop_cap = 999
	before = w.economy.res.duplicate()
	w.queue_unit(barracks, "tank")
	check(barracks.queue.size() == 1, "unit order accepted")
	w.research._bonus["costVehiclePct"] = -0.4
	w.cancel_queued(barracks, 0)
	check(w.economy.res == before, "unit refund does not change when a new discount is discovered")
	w.research._recompute()
	before = w.economy.res.duplicate()
	w.queue_unit(barracks, "tank")
	var first_cost: float = before.money - w.economy.res.money
	w.research._bonus["costVehiclePct"] = -0.4
	w.queue_unit(barracks, "tank")
	barracks.supplied = true
	w.update_training(100)
	check(barracks.queue.size() == 1 and barracks.queue_costs.size() == 1, "completed order removes only its own receipt")
	w.cancel_queued(barracks, 0)
	check(is_equal_approx(w.economy.res.money, before.money - first_cost), "cancelling the next order refunds the next receipt")
	w.research._recompute()
	# Loading the same save must rewind policies, not retain later effects.
	w.game_time = 100
	w.power_ready.clear()
	w.power_effects.clear()
	Powers.use(w, 0, 1)
	var cooldown: float = Powers.ready_in(w, 0)
	var active_save := json_save()
	w.power_ready.clear()
	w.power_effects.clear()
	w.power_uses.clear()
	w.saves.restore(active_save)
	check(is_equal_approx(Powers.ready_in(w, 0), cooldown), "power cooldown survives JSON load")
	check(is_equal_approx(Powers.income_mult(w, 1), 0.7), "active sanctions survive JSON load")
	check(w.power_uses.size() == 1, "power usage history survives load")
	w.game_time += 181
	check(Powers.income_mult(w, 1) == 1 and Powers.ready_in(w, 0) > 0, "loaded sanctions expire while their cooldown continues")
	w.game_time = 500
	w.power_ready.clear()
	w.power_effects.clear()
	var peaceful_save := json_save()
	Powers.use(w, 0, 1)
	w.saves.restore(peaceful_save)
	check(Powers.ready_in(w, 0) == 0 and Powers.income_mult(w, 1) == 1, "loading earlier state clears policies applied after that save")
	# A missile has left storage and is halfway to its target when saved.
	var target: Vector3 = w.start + Vector3(150, 0, 0)
	var missile: Dictionary = w.missiles.fly("cruise", w.start + Vector3.UP * 5, target, 1, true)
	target = missile.to  # launch adjusts the destination to the terrain height
	w.missiles._physics_process(0.3)
	var elapsed: float = missile.t
	var defender: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	missile.engaged = {defender.node.get_instance_id(): true, "dome": true}
	defender.disabled_until = w.game_time + 25
	defender.intercept_ready = w.game_time + 8
	defender.aa_reload = 3.0
	var mobile: Dictionary = w.spawn_unit("samLauncher", w.land_point(w.start, 35), 0)
	mobile.disabled_until = w.game_time + 12
	mobile.intercept_ready = w.game_time + 6
	missile.engaged[mobile.node.get_instance_id()] = true
	w.research.tracks.military = 5
	w.research._recompute()
	var veteran: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 45), 0)
	var veteran_max: float = veteran.max_hp
	for nation in w.ai.nations:
		if nation.id == 1:
			nation.tech = 8.0
	var rival_veteran: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 55), 1)
	var rival_max: float = rival_veteran.max_hp
	var original_stats: Array = w.units.map(func(u): return [u.max_hp, u.range, u.speed, u.cooldown])
	var flight_save := json_save()
	w.saves.restore(flight_save)
	check(w.missiles.flying.size() == 1, "missile in flight is not erased by loading")
	if w.missiles.flying.size() == 1:
		var restored: Dictionary = w.missiles.flying[0]
		check(restored.type == "cruise" and restored.owner == 1 and is_equal_approx(restored.t, elapsed), "missile owner, type and elapsed flight are preserved")
		check(restored.to.distance_to(target) < 1, "missile keeps its destination")
		var loaded_defender: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
		check(restored.engaged.has(loaded_defender.node.get_instance_id()) and restored.engaged.has("dome"), "load does not grant a defender another interception attempt")
		check(loaded_defender.disabled_until == w.game_time + 25 and loaded_defender.intercept_ready == w.game_time + 8 and loaded_defender.aa_reload == 3, "EMP and defence cooldowns survive load")
		var loaded_mobile: Dictionary = w.units.filter(func(u): return u.key == "samLauncher" and u.disabled_until == w.game_time + 12)[0]
		check(restored.engaged.has(loaded_mobile.node.get_instance_id()) and loaded_mobile.intercept_ready == w.game_time + 6, "mobile defence keeps its EMP, cooldown and interception attempt")
		w.missiles._physics_process(restored.dur)
		check(w.missiles.flying.is_empty(), "restored missile continues to impact")
	# Exercise the menu's fresh-scene loading path, not only restore in-place.
	var old_world := w.get_instance_id()
	set_meta("match_config", flight_save.match_config)
	set_meta("pending_load", flight_save)
	paused = false
	reload_current_scene()
	w = null
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_world and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	check(w != null, "saved combat state opens in a fresh scene")
	if w == null:
		quit(1)
		return
	paused = true
	w.saves.autosave_every = 0
	check(w.missiles.flying.size() == 1 and w.missiles.flying[0].owner == 1, "fresh scene retains the incoming missile")
	var saved_veterans: Array = w.units.filter(func(u): return u.key == "soldier" and u.owner == 0 and is_equal_approx(u.hp, veteran_max))
	check(saved_veterans.size() == 1 and is_equal_approx(saved_veterans[0].max_hp, veteran_max), "fresh load restores researched maximum health before spawning player units")
	var saved_rivals: Array = w.units.filter(func(u): return u.key == "soldier" and u.owner == 1 and is_equal_approx(u.hp, rival_max))
	check(saved_rivals.size() == 1 and is_equal_approx(saved_rivals[0].max_hp, rival_max), "fresh load restores rival technology before spawning rival units")
	check(w.units.map(func(u): return [u.max_hp, u.range, u.speed, u.cooldown]) == original_stats, "loading preserves equipment on both old and upgraded units")
	# Old saves start with no new policy, flight or receipt data.
	var legacy := json_save()
	legacy.erase("national_powers")
	legacy.missiles.erase("flying")
	for b in legacy.buildings:
		b.erase("queue_costs")
		for timer in ["disabled_until", "intercept_ready", "aa_reload"]:
			b.erase(timer)
	for u in legacy.units:
		u.erase("equipment")
		for timer in ["disabled_until", "intercept_ready"]:
			u.erase(timer)
	w.saves.restore(legacy)
	check(w.power_ready.is_empty() and w.power_effects.is_empty() and w.missiles.flying.is_empty(), "legacy saves load with safe empty state")
	check(w.units.all(func(u): return u.disabled_until == 0 and u.intercept_ready == 0), "legacy unit timers default to ready")
	for i in range(3):
		await process_frame
	print("GAMEPLAY_STATE_AUDIT %d checks, %d failures" % [checks, failures.size()])
	print("GAMEPLAY_STATE_AUDIT PASS" if failures.is_empty() else "GAMEPLAY_STATE_AUDIT FAIL")
	quit(0 if failures.is_empty() else 1)
