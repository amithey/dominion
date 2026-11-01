extends SceneTree
## Counts, in a restored late match (growth-profile.gd --save-at=N), how many nodes have per-frame processing switched
## on, grouped by script (or node class), plus the node counts by class: what the engine walks every frame.
## Usage: --tag=name
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
func _initialize() -> void: call_deferred("run")
func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name): return a.split("=")[1]
	return fallback
func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://build/audit/late-%s.json" % arg("tag", "freeze4")))
	set_meta("match_config", preload("res://scripts/match_setup.gd").normalize(data.get("match_config", {})))
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
	for i in range(30): await process_frame
	var proc := {}
	var phys := {}
	var classes := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var label: String = n.get_script().resource_path.get_file() if n.get_script() != null else n.get_class()
		classes[n.get_class()] = int(classes.get(n.get_class(), 0)) + 1
		if n.is_processing(): proc[label] = int(proc.get(label, 0)) + 1
		if n.is_physics_processing(): phys[label] = int(phys.get(label, 0)) + 1
		for k in n.get_children(): stack.append(k)
	var show := func(title: String, d: Dictionary):
		var keys: Array = d.keys()
		keys.sort_custom(func(a, b): return d[a] > d[b])
		print("CENSUS ", title, ": ", ", ".join(PackedStringArray(keys.slice(0, 14).map(func(k): return "%s %d" % [k, d[k]]))))
	show.call("nodes by class", classes)
	show.call("processing every frame", proc)
	show.call("physics-processing", phys)
	print("CENSUS total nodes ", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), ", objects ", int(Performance.get_monitor(Performance.OBJECT_COUNT)), ", resources ", int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	quit(0)
