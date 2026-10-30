extends SceneTree
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var path := "res://build/audit/late-usa-island-nan.json"
	if not FileAccess.file_exists(path):
		print("FAIL: no file")
		quit(1)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var cfg: Dictionary = preload("res://scripts/match_setup.gd").normalize(data.get("match_config", {}))
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
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
	w.menu.set_fullscreen(false)
	root.size = Vector2i(1280, 800)
	w.start_match(str(data.get("difficulty", "normal")))
	w.menu.close()
	w.saves.autosave_every = 0
	w.saves.restore(data)
	if is_instance_valid(w.hud._guide): w.hud._guide.queue_free(); w.hud._guide = null
	for i in range(10): await process_frame

	print("=== WORLD CHILDREN AND SCRIPTS ===")
	for k in w.get_children():
		var scr = k.get_script()
		var scr_path: String = str(scr.resource_path) if scr != null else "(no script)"
		var children := k.get_child_count()
		print("Child %-30s | Class: %-18s | Script: %-35s | Children: %d" % [k.name, k.get_class(), scr_path, children])

	print("\n=== HUD CHILDREN ===")
	for k in w.hud.get_children():
		var scr = k.get_script()
		var scr_path: String = str(scr.resource_path) if scr != null else "(no script)"
		print("HUD Child %-26s | Class: %-18s | Script: %-35s | Children: %d" % [k.name, k.get_class(), scr_path, k.get_child_count()])

	print("\n=== WORLD COLLECTIONS SIZES ===")
	for p in w.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var v = w.get(p.name)
		if v is Array or v is Dictionary:
			if v.size() > 50:
				print("  w.%-25s = %d" % [p.name, v.size()])

	print("\n=== SYSTEMS COLLECTION SIZES (>50) ===")
	for name in ["economy", "ai", "effects", "missiles", "territory", "logistics", "diplomacy", "research", "market", "espionage", "hud", "events", "support", "victory", "space", "un", "wmd", "fog", "generals", "defcon", "crisis", "directorate", "minimap", "stats", "saves", "weather", "ambience", "audio", "navigation"]:
		var sys = w.get(name)
		if sys == null: continue
		for p in sys.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
			var v = sys.get(p.name)
			if v is Array or v is Dictionary:
				if v.size() > 50:
					print("  %s.%-25s = %d" % [name, p.name, v.size()])

	quit(0)
