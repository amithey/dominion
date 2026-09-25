extends SceneTree
## Every setting on the Settings screen is saved and comes back: camera speed,
## edge scrolling, frame limit, frame counter, effects volume, autosave. The
## player's own settings file is put back afterwards.
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	var m: Node = w.menu
	var backup := FileAccess.get_file_as_string(m.SETTINGS) if FileAccess.file_exists(m.SETTINGS) else ""
	for tab in ["graphics", "sound", "controls", "game"]:
		m.settings_tab = tab
		m.open_settings()
		check(m._panel.get_child_count() >= 3, "the %s tab has its settings" % tab)
	w.pan_speed = 1.6
	w.edge_scroll = false
	w.show_fps = false
	Engine.max_fps = 60
	m._set_bus_volume("SFX", 40.0)
	w.saves.autosave_every = 60.0
	m.save_settings()
	w.pan_speed = 1.0
	w.edge_scroll = true
	w.show_fps = true
	Engine.max_fps = 0
	m._set_bus_volume("SFX", 100.0)
	w.saves.autosave_every = 180.0
	m.load_settings()
	check(is_equal_approx(w.pan_speed, 1.6), "camera speed is restored")
	check(not w.edge_scroll, "edge scrolling is restored")
	check(not w.show_fps, "the frame counter setting is restored")
	check(Engine.max_fps == 60, "the frame limit is restored")
	check(absf(m._bus_volume("SFX") - 40.0) < 1.5, "the effects volume is restored")
	check(is_equal_approx(w.saves.autosave_every, 60.0), "the autosave interval is restored")
	m._reset_settings()
	check(is_equal_approx(w.pan_speed, 1.0) and w.edge_scroll and absf(m._bus_volume("SFX") - 100.0) < 1.5, "Defaults resets them")
	if backup != "":
		var f := FileAccess.open(m.SETTINGS, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(m.SETTINGS))
	print("SETTINGS_TEST PASS" if errors.is_empty() else "SETTINGS_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
