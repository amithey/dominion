extends SceneTree
## Settings, Game shows a "Road and rail traffic" switch that drives world.road_traffic, Defaults turns it back on, and the
## settings file keeps it. (The menu used here never writes the player's settings.)
class QuietMenu extends "res://scripts/menu.gd":
	var saved := {}
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: saved["road_traffic"] = world.road_traffic
var passed := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: failed.append(label)
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0})
	change_scene_to_file("res://world.tscn")
	var w: Node = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	var old = w.menu
	w.menu = QuietMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	old.queue_free()
	w.start_match("easy")
	var m = w.menu
	m.settings_tab = "game"
	m.open_settings()
	await process_frame
	var found: CheckButton = null
	for b in m.find_children("*", "CheckButton", true, false):
		var row: Node = b.get_parent()
		for l in row.find_children("*", "Label", true, false) + row.get_parent().find_children("*", "Label", true, false):
			if l.text == "Road and rail traffic": found = b
	check(found != null, "Settings, Game has a Road and rail traffic switch")
	check(w.road_traffic == true, "it is on by default")
	if found != null:
		check(found.button_pressed == true, "and shown on")
		found.button_pressed = false
		found.toggled.emit(false)
		check(w.road_traffic == false, "switching it off sets the world's flag")
	m._reset_settings()
	check(w.road_traffic == true, "Defaults turns it back on")
	w.road_traffic = false
	m.save_settings()
	check(m.saved.get("road_traffic", true) == false, "the settings file is written with it")
	print("ROAD_TRAFFIC_SETTING ", "PASS" if failed.is_empty() else "FAIL", ": ", passed, " checks, ", failed.size(), " failures")
	quit(0 if failed.is_empty() else 1)
