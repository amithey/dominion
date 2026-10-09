extends SceneTree
## Performance, measured and held to budgets: how long maps take to load; the
## cost of a simulation step in peace with nine nations and in a battle of two
## hundred; the AI's thinking; long routes across the largest continent; the
## economy, land and supply ticks; saving and loading a big match; memory; and,
## with a window, the frame rate over the battle (build/perf-battle.png).
## The budgets leave room for slower PCs than the one they were set on.
var errors: Array[String] = []
var passed := 0
var w: Node
var report: Array[String] = []
const DT := 1.0 / 15.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	report.append(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func load_match(cfg: Dictionary) -> float:
	set_meta("match_config", cfg)
	var t0 := Time.get_ticks_msec()
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	var seconds := (Time.get_ticks_msec() - t0) / 1000.0
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("normal")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	return seconds

func freeze() -> void:
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		node.set_process(false)

## Mean and worst milliseconds of `steps` whole simulation steps.
func steps(count: int) -> Array:
	var times: Array[float] = []
	for i in range(count):
		var t0 := Time.get_ticks_usec()
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		w.ai._physics_process(DT)
		for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
			node._process(DT)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
		# Real frames release queued bodies/effects and commit deferred navigation.
		# Keep this outside the measured step; a tight 30-second loop cannot do so.
		if i % 30 == 29: await process_frame
	times.sort()
	var total := 0.0
	for t in times: total += t
	return [total / times.size(), times[int(times.size() * 0.99) - 1], times[-1]]

func run() -> void:
	var windowed := DisplayServer.get_name() != "headless"
	# 1-2: loading.
	var small_s := await load_match({"map": "island", "players": 4, "nation": 0, "style": "standard"})
	check(small_s < 15.0, "the original island loads in %.1f s (budget 15)" % small_s)
	var eco_ms := 0.0
	for i in range(20):
		var t0 := Time.get_ticks_usec()
		w.economy.tick()
		eco_ms += (Time.get_ticks_usec() - t0) / 1000.0 / 20.0
	check(eco_ms < 3.0, "an economy tick takes %.2f ms (budget 3)" % eco_ms)
	var big_s := await load_match({"map": "pangaea", "players": 9, "nation": 0, "style": "standard"})
	check(big_s < 45.0, "Pangaea with nine nations loads in %.1f s (budget 45)" % big_s)
	var mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	check(mem_mb < 2500.0, "memory after loading the largest match: %d MB (budget 2500)" % int(mem_mb))
	freeze()
	# 3-4: peacetime with nine nations, and the AI's share.
	w.economy.grant_test_resources()
	var peace: Array = await steps(900)
	check(peace[0] < 12.0 and peace[1] < 40.0, "a peacetime step with nine nations: %.1f ms on average, %.1f ms at the 99th percentile (budget 12 / 40)" % [peace[0], peace[1]])
	var ai_ms := 0.0
	for i in range(300):
		var t0 := Time.get_ticks_usec()
		w.ai._physics_process(DT)
		ai_ms += (Time.get_ticks_usec() - t0) / 1000.0 / 300.0
	check(ai_ms < 3.0, "eight rival governments think in %.2f ms a step (budget 3)" % ai_ms)
	# 5: land and supply.
	var t1 := Time.get_ticks_usec()
	for i in range(10): w.territory.tick()
	var land_ms := (Time.get_ticks_usec() - t1) / 1000.0 / 10.0
	t1 = Time.get_ticks_usec()
	for i in range(10):
		w.logistics.dirty = true
		w.logistics.update_supply()
	var supply_ms := (Time.get_ticks_usec() - t1) / 1000.0 / 10.0
	check(land_ms < 40.0 and supply_ms < 40.0, "a land tick takes %.1f ms, a supply update %.1f ms on the largest map (budget 40 each)" % [land_ms, supply_ms])
	# 6: long routes across the continent.
	var capitals: Array = w.buildings.filter(func(b): return b.key == "hq" and not b.dead)
	var route_ms: Array[float] = []
	var found := 0
	for i in range(1, capitals.size()):
		var t0 := Time.get_ticks_usec()
		var route: PackedVector3Array = w.path_between(capitals[0].root.position + Vector3(20, 0, 20), capitals[i].root.position + Vector3(-20, 0, -20))
		route_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		if not route.is_empty(): found += 1
	route_ms.sort()
	check(found >= capitals.size() - 2 and route_ms[-1] < 120.0, "routes to every capital across Pangaea: %d of %d found, the longest in %.1f ms (budget 120)" % [found, capitals.size() - 1, route_ms[-1]])
	# 7-8: a battle of two hundred.
	var field: Vector3 = w.land_point(capitals[0].root.position.lerp(capitals[1].root.position, 0.5), 40.0)
	var ours: Array = w.spawn_group(field + Vector3(-30, 0, 0), 0, 80, 20)
	var theirs: Array = w.spawn_group(field + Vector3(30, 0, 0), 1, 80, 20)
	w.diplomacy.declare_war(0, 1)
	w.order_move(ours, field + Vector3(15, 0, 0), true)
	w.order_move(theirs, field + Vector3(-15, 0, 0), true)
	var units: int = w.units.filter(func(u): return not u.dead).size()
	w.profiling = true; w.prof.clear(); w.prof_frames = 0
	var battle: Array = await steps(450)
	print("BATTLE PROFILE: " + w.profile_report())
	w.profiling = false
	var fought: int = (ours + theirs).filter(func(u): return u.dead).size()
	# Measured at 29-41 ms on the PC the budgets were set on (it varies with the fight).
	check(battle[0] < 45.0 and battle[1] < 130.0, "a battle of 200 (%d units on the map, %d fell): %.1f ms a step on average, %.1f at the 99th percentile (budget 45 / 130)" % [units, fought, battle[0], battle[1]])
	# 9: save and load the big match.
	var t2 := Time.get_ticks_msec()
	var data: Dictionary = w.saves.capture()
	var text := JSON.stringify(data)
	var save_ms := Time.get_ticks_msec() - t2
	t2 = Time.get_ticks_msec()
	w.saves.restore(JSON.parse_string(text))
	var load_ms := Time.get_ticks_msec() - t2
	check(save_ms < 1500 and load_ms < 8000, "saving the big match takes %d ms (%d KB), restoring it %d ms (budget 1500 / 8000)" % [save_ms, text.length() / 1024, load_ms])
	# 10: frames, with a window.
	if windowed:
		for i in range(20): await process_frame
		w.set_physics_process(true)
		w.effects.set_physics_process(true)
		var more: Array = w.spawn_group(field + Vector3(0, 0, 35), 0, 40, 10) + w.spawn_group(field + Vector3(0, 0, -35), 1, 40, 10)
		w.order_move(more, field, true)
		w.cam_focus = field
		w.cam_dist_target = 90.0
		w.cam_dist = 90.0
		for i in range(60): await process_frame
		var frames: Array[float] = []
		for i in range(300):
			await process_frame
			frames.append(w.get_process_delta_time() * 1000.0)
		frames.sort()
		var mean := 0.0
		for f in frames: mean += f / frames.size()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/perf-battle.png")
		check(1000.0 / mean >= 25.0, "the battle on screen runs at %d frames a second, the slowest 1%% at %d (budget 25)" % [int(1000.0 / mean), int(1000.0 / frames[int(frames.size() * 0.99) - 1])])
	print("\n" + "\n".join(report))
	print("\nPERFORMANCE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("PERFORMANCE PASS" if errors.is_empty() else "PERFORMANCE FAIL")
	quit(0 if errors.is_empty() else 1)
