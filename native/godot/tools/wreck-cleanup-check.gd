extends SceneTree
## Decorative wreck budgets; live units, recent deaths and naval/air deaths are exempt.
var w: Node
var count := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures += 1
	print(("ok " if ok else "FAIL ") + label)
func wreck(at: Vector3, age: float, kind := "tank") -> Dictionary:
	var u: Dictionary = w.spawn_unit(kind, at, 0)
	u.dead = true; u.dead_time = age
	return u
func retiring(u: Dictionary) -> bool: return u.get("wreck_retiring", false)
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(1); return
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_process(false); w.set_physics_process(false)
	for child in w.get_children(): child.set_process(false); child.set_physics_process(false)
	var at: Vector3 = w.start + Vector3(30, 0, 30)
	var live: Dictionary = w.spawn_unit("tank", at, 0)
	var recent := wreck(at, 2.0)
	var pile: Array = []
	for i in range(8): pile.append(wreck(at, 10.0 + i))
	var ship := wreck(at, 100.0, "destroyer")
	var jet := wreck(at, 100.0, "jet")
	var foot := wreck(at, 100.0, "soldier")
	w.trim_wrecks()
	check(not retiring(live) and not live.dead, "Live vehicles are never retired")
	check(not retiring(recent), "Recent explosions retain their wreck")
	check(pile.filter(func(u): return not retiring(u)).size() == w.WRECKS_PER_CELL, "Only three settled wrecks remain in a dense area")
	check(not retiring(pile[0]) and retiring(pile[-1]), "Newest wrecks are retained before older ones")
	check(not retiring(ship) and not retiring(jet) and not retiring(foot), "Ship, aircraft and infantry death sequences stay independent")
	var old := wreck(at + Vector3(80, 0, 0), 90.0)
	w.trim_wrecks(); check(retiring(old), "A distant wreck eventually expires too")
	var retired: Dictionary = pile[-1]
	var node: Node3D = retired.node
	var height: float = node.position.y
	w.update_dead(retired, 1.0, w.units.find(retired))
	check(node.position.y < height and w.units.has(retired), "An excess wreck sinks gradually instead of popping away")
	w.update_dead(retired, 3.1, w.units.find(retired))
	check(not w.units.has(retired) and node.is_queued_for_deletion(), "Cleanup removes both the world entry and its model")
	check(w.units.has(live) and not live.node.is_queued_for_deletion(), "Cleanup preserves a live vehicle in the same location")
	for i in range(60): wreck(at + Vector3(200 + (i % 10) * 30, 0, (i / 10) * 30), 20.0)
	w.trim_wrecks()
	var kept: Array = w.units.filter(func(u): return u.dead and u.vehicle and not u.get("fly", false) and not u.get("naval", false) and u.dead_time >= 8 and not retiring(u))
	check(kept.size() == w.WRECK_LIMIT, "Scattered settled wrecks are bounded across the entire map")
	w.trim_wrecks()
	check(kept.all(func(u): return not retiring(u)), "Repeated budget passes preserve the retained wrecks")
	print("WRECK_CLEANUP: %d checks, %d failures" % [count, failures])
	print("WRECK_CLEANUP PASS" if failures == 0 else "WRECK_CLEANUP FAIL")
	quit(0 if failures == 0 else 1)
