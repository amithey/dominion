extends SceneTree
## Which part of a late-game match costs the frame? Loads the state saved by growth-profile.gd (--save-at=N), freezes the
## engine's own processing so the state stands still, and then calls every system's _process and _physics_process by hand,
## timing each call with the microsecond clock (the mean of --calls calls). The table is the cost of one frame's process and
## one physics tick, system by system, the largest first, with the totals: what the machine pays 60 times a second.
## Usage: --tag=name (the profile run's tag) --calls=20. Output: console + build/audit/growth-bisect-<tag>.txt
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
func _initialize() -> void: call_deferred("run")

func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name): return a.split("=")[1]
	return fallback

func all_nodes(n: Node, out: Array) -> void:
	out.append(n)
	for k in n.get_children(): all_nodes(k, out)

func label_of(k: Node) -> String:
	var script: Script = k.get_script()
	return "%s (%s)" % [script.resource_path.get_file(), k.name] if script != null else k.get_class()

func run() -> void:
	var tag := arg("tag", "usa-island-45")
	var calls := int(arg("calls", "20"))
	var path := "res://build/audit/late-%s.json" % tag
	if not FileAccess.file_exists(path):
		print("BISECT FAIL: no saved state at ", path)
		quit(1)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
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
	if is_instance_valid(w.hud._guide): w.hud._guide.queue_free(); w.hud._guide = null
	for i in range(20): await process_frame
	var nodes: Array = []
	all_nodes(w, nodes)
	var scripted: Array = nodes.filter(func(n): return n.get_script() != null and (n.has_method("_process") or n.has_method("_physics_process")))
	# freeze the engine's own calls so the state stands still while we time each by hand
	for n in scripted:
		n.set_process(false)
		n.set_physics_process(false)
	await process_frame
	var units: int = w.units.filter(func(u): return not u.dead).size()
	var buildings: int = w.buildings.filter(func(b): return not b.dead).size()
	var lines := PackedStringArray()
	lines.append("state: game minute %d, %d units, %d buildings, %d nodes, %d scripted systems" % [int(w.game_time / 60.0), units, buildings, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), scripted.size()])
	var rows := []
	var total_p := 0.0
	var total_f := 0.0
	var dt := 1.0 / 60.0
	for n in scripted:
		var p_us := 0.0
		var f_us := 0.0
		if n.has_method("_process"):
			for i in range(calls):
				var t0 := Time.get_ticks_usec()
				n._process(dt)
				p_us += Time.get_ticks_usec() - t0
		if n.has_method("_physics_process"):
			for i in range(calls):
				var t0 := Time.get_ticks_usec()
				n._physics_process(dt)
				f_us += Time.get_ticks_usec() - t0
		var p_ms := p_us / calls / 1000.0
		var f_ms := f_us / calls / 1000.0
		total_p += p_ms
		total_f += f_ms
		rows.append([p_ms + f_ms, label_of(n), p_ms, f_ms])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	lines.append("TOTAL: _process %.2f ms a frame + _physics_process %.2f ms a tick = %.2f ms for one frame with one tick" % [total_p, total_f, total_p + total_f])
	for r in rows:
		if r[0] >= 0.15: lines.append("%7.2f ms  %-48s  process %6.2f   physics %6.2f" % [r[0], r[1], r[2], r[3]])
	for l in lines: print("BISECT ", l)
	var f := FileAccess.open("res://build/audit/growth-bisect-%s.txt" % tag, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	quit(0)
