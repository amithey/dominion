extends SceneTree
## Checks for what a playtest found: Esc opens and closes the pause menu, Space
## pauses, the speed keys work, every nation opens with a town and a small
## guard, repeated notices fold into one, the beginner's guide ticks off steps.
var w: Node
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame
	await process_frame
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://beginner_guide.cfg"))
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	var old := w
	w.menu.start("easy")   # a new campaign from the menu reloads the scene with its options
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene != old and is_instance_valid(current_scene) and current_scene.get("nav_ready") == true and current_scene.get("hud") != null and current_scene.hud.visible:
			w = current_scene
			break
	for i in range(30): await process_frame
	# the opening
	for owner in range(4):
		var kinds := {}
		for u in w.units:
			if u.owner == owner: kinds[u.key] = true
		check(kinds.keys().all(func(k): return k in ["worker", "soldier", "rocketSoldier", "manpads", "medic"] or k in w.INFANTRY), "nation %d opens with infantry and workers only: %s" % [owner, str(kinds.keys())])
		if owner == 0: check(kinds.has("worker"), "you open with workers")
	check(w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq").size() == 1, "your town stands")
	# Esc
	await key(KEY_ESCAPE)
	check(w.menu._root.visible and w.get_tree().paused, "Esc opens the pause menu and it stays open")
	await key(KEY_ESCAPE)
	check(not w.menu._root.visible and not w.get_tree().paused, "a second Esc closes it")
	# Space
	await key(KEY_SPACE)
	check(w.game_speed <= 0.0 and Engine.time_scale < 0.01, "Space pauses the world")
	check(w.hud._paused_banner.visible, "the pause banner shows")
	var t0: float = w.game_time
	for i in range(30): await process_frame
	check(absf(w.game_time - t0) < 0.2, "game time stands still while paused")
	var c0: Vector3 = w.cam_focus
	var d := InputEventKey.new()
	d.keycode = KEY_D
	d.physical_keycode = KEY_D
	d.pressed = true
	Input.parse_input_event(d)
	for i in range(40): await process_frame
	d = InputEventKey.new()
	d.keycode = KEY_D
	d.physical_keycode = KEY_D
	d.pressed = false
	Input.parse_input_event(d)
	check(w.cam_focus.distance_to(c0) > 2.0, "the camera still moves while paused")
	await key(KEY_SPACE)
	check(is_equal_approx(w.game_speed, 1.0) and Engine.time_scale > 0.5, "Space again resumes at 1x")
	await key(KEY_EQUAL)
	check(is_equal_approx(w.game_speed, 2.0), "+ doubles the speed")
	await key(KEY_EQUAL)
	check(is_equal_approx(w.game_speed, 4.0), "+ again: 4x")
	await key(KEY_MINUS)
	check(is_equal_approx(w.game_speed, 2.0), "- slows it")
	w.set_speed(1.0)
	# notices
	var before: int = w.hud.notice_log.size()
	w.hud.notice("Same message")
	w.hud.notice("Same message")
	w.hud.notice("Same message")
	check(w.hud.notice_log.size() == before + 1, "a repeated message is logged once")
	# build list
	await key(KEY_B)
	check(w.hud.prod_open, "B opens the build list")
	await create_timer(0.8).timeout
	check(w.hud._guide != null and w.hud._guide.step == 1, "the guide moved on to placing a farm")
	check(not w.hud.get_node("Reopen").visible, "the old floating Build button is gone")
	var first_group: String = w.hud.BUILD_GROUPS.Economy[0][0]
	check(first_group == "Food and resources", "the build list opens with food")
	# guide: place a farm
	var farms_before: int = w.buildings.filter(func(b): return b.owner == 0 and b.key == "farm").size()
	w.economy.res.money = 5000.0
	var at: Vector3 = w.test_site("farm", w.start + Vector3(-30, 0, 20))
	w.place_building("farm", at, 0, false)
	await create_timer(0.8).timeout
	check(w.hud._guide.step >= 2, "the guide notices the farm")
	w.hud._guide.close()
	check(not FileAccess.file_exists("user://beginner_guide.cfg") == false, "skipping the guide is remembered")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://beginner_guide.cfg"))
	print("UX_FIXES ", "PASS" if errors.is_empty() else "FAIL %d" % errors.size())
	quit(0 if errors.is_empty() else 1)
