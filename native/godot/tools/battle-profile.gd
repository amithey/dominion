extends SceneTree
## Battle-only profile: the "battle of 200" from performance-check.gd, on its own,
## with the world profiler's per-system breakdown. Run:
##   godot --headless --path . --script res://tools/battle-profile.gd [-- steps=450 seed=1]
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
const DT := 1.0 / 15.0
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var count := 450
	var profile := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("steps="): count = int(a.substr(6))
		if a == "profile=0": profile = false
	seed(1)
	set_meta("match_config", {"map": "pangaea", "players": 9, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	var old = w.menu
	w.menu = QuietMenu.new(); w.add_child(w.menu); w.menu.setup(w); old.queue_free()
	w.start_match("normal")
	w.menu.close()
	w.saves.autosave_every = 0
	w.edge_scroll = false
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	var procs := [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]
	for node in procs: node.set_process(false)
	var capitals: Array = w.buildings.filter(func(b): return b.key == "hq" and not b.dead)
	var field: Vector3 = w.land_point(capitals[0].root.position.lerp(capitals[1].root.position, 0.5), 40.0)
	var ours: Array = w.spawn_group(field + Vector3(-30, 0, 0), 0, 80, 20)
	var theirs: Array = w.spawn_group(field + Vector3(30, 0, 0), 1, 80, 20)
	w.diplomacy.declare_war(0, 1)
	w.order_move(ours, field + Vector3(15, 0, 0), true)
	w.order_move(theirs, field + Vector3(-15, 0, 0), true)
	var units: int = w.units.filter(func(u): return not u.dead).size()
	w.profiling = profile; w.prof.clear(); w.prof_frames = 0
	var parts := {"world": 0.0, "effects": 0.0, "missiles": 0.0, "ai": 0.0, "procs": 0.0}
	var times: Array[float] = []
	for i in range(count):
		var t0 := Time.get_ticks_usec()
		w._physics_process(DT)
		var t1 := Time.get_ticks_usec()
		w.effects._physics_process(DT)
		var t2 := Time.get_ticks_usec()
		w.missiles._physics_process(DT)
		var t3 := Time.get_ticks_usec()
		w.ai._physics_process(DT)
		var t4 := Time.get_ticks_usec()
		for node in procs: node._process(DT)
		var t5 := Time.get_ticks_usec()
		parts.world += t1 - t0; parts.effects += t2 - t1; parts.missiles += t3 - t2; parts.ai += t4 - t3; parts.procs += t5 - t4
		times.append((t5 - t0) / 1000.0)
		if i % 30 == 29: await process_frame
	times.sort()
	var total := 0.0
	for t in times: total += t
	var fought: int = (ours + theirs).filter(func(u): return u.dead).size()
	print("BATTLE units=%d fell=%d mean=%.2f ms p99=%.2f max=%.2f" % [units, fought, total / times.size(), times[int(times.size() * 0.99) - 1], times[-1]])
	for k in parts: print("  part %s %.2f ms" % [k, parts[k] / count / 1000.0])
	print("PROFILE " + w.profile_report().replace(", ", "\n  "))
	quit(0)
