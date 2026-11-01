extends SceneTree
## Do the cars, lorries and trains (route_traffic.gd) get stuck, or drive into houses? Loads a saved game (read only:
## --save=autosave reads user://saves/autosave.json, or --path=<file>), runs it forward --seconds game seconds at --scale,
## and every game second looks at every vehicle:
##   stuck    a vehicle that is not waiting at the end of a trip yet has stood still (speed under 0.05 m/s) for 20 game seconds
##   inside   a vehicle body whose centre is inside a building's footprint (the building's own footprint radius)
##   no trip  a vehicle at the end of a trip that cannot find a next one (it waits 4 s, again and again)
## It prints each case with the vehicle's hexes and the building concerned. Nothing is written to the player's folder.
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
var traffic: Node
func _initialize() -> void: call_deferred("run")
func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name): return a.substr(name.length() + 3)
	return fallback

func run() -> void:
	var path := arg("path", "user://saves/%s.json" % arg("save", "autosave"))
	if not FileAccess.file_exists(path):
		print("TRAFFIC FAIL: no saved game at ", path)
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
	for c in w.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("route_traffic.gd"): traffic = c
	if traffic == null:
		print("TRAFFIC FAIL: no traffic node")
		quit(1)
		return
	traffic._sync_network()
	print("TRAFFIC save: %s, game minute %d, %d buildings, %d road links, %d rail links" % [path.get_file(), int(w.game_time / 60.0), w.buildings.size(), traffic._edge_count.road, traffic._edge_count.rail])
	Engine.time_scale = float(arg("scale", "4"))
	var seconds := float(arg("seconds", "300"))
	var start: float = w.game_time
	var still := {}        # vehicle id -> game seconds it has been still without waiting
	var told := {}
	var inside_cases := {}
	var stuck_cases := {}
	var notrip_cases := {}
	var samples := 0
	var vehicles_seen := {}
	var next_sample: float = start + 1.0
	while w.game_time < start + seconds:
		await process_frame
		if w.game_time < next_sample: continue
		next_sample = w.game_time + 1.0
		samples += 1
		for c in traffic._fleet:
			var id: int = c.get_instance_id() if c is Object else hash(str(c.get("hexes", [])) + str(c.kind))
			vehicles_seen[id] = true
			var waiting: bool = float(c.wait) > 0.0
			if not waiting and float(c.v) < 0.05:
				still[id] = float(still.get(id, 0.0)) + 1.0
				if float(still[id]) == 20.0 and not stuck_cases.has(id):
					var at: Vector3 = traffic._point_at(c, c.s)
					stuck_cases[id] = "%s at (%d, %d) hex %s, %.0f m of %.0f m into its trip, gap ahead %s" % [c.kind, at.x, at.z, str(w.logistics.world_hex(at)), c.s, c.total, str(c.get("gap", "?"))]
					# who is close to it, and what are they doing
					var near := PackedStringArray()
					for o in traffic._fleet:
						if is_same(o, c): continue
						var q: Vector3 = traffic._point_at(o, o.s)
						if Vector2(q.x - at.x, q.z - at.z).length() < 14.0:
							near.append("[%s v=%.1f wait=%.1f s=%.0f/%.0f yaw=%.2f vs mine %.2f at %.1f m]" % [o.kind, o.v, o.wait, o.s, o.total, o.yaw, c.yaw, Vector2(q.x - at.x, q.z - at.z).length()])
					stuck_cases[id] += " | neighbours: " + " ".join(near)
			else:
				still[id] = 0.0
			if waiting and float(c.wait) == 4.0 and float(c.total) - float(c.s) < 1.0 and not notrip_cases.has(id):
				var at2: Vector3 = traffic._point_at(c, c.s)
				notrip_cases[id] = "%s at (%d, %d) hex %s: no next trip from the end of its road" % [c.kind, at2.x, at2.z, str(w.logistics.world_hex(at2))]
			for body in c.bodies:
				var p: Vector3 = body.get("at", Vector3.INF)
				if p == Vector3.INF: continue
				for b in w.buildings:
					if b.dead: continue
					var d: float = Vector2(p.x - b.root.position.x, p.z - b.root.position.z).length()
					if d < float(b.footprint) * 0.45:
						var key := "%d:%d" % [id, b.root.get_instance_id()]
						if not inside_cases.has(key):
							inside_cases[key] = "%s body at (%d, %d) is %.1f m from the centre of a %s (footprint %.1f, hex %s)" % [c.kind, p.x, p.z, d, b.key, float(b.footprint), str(w.logistics.world_hex(b.root.position))]
	Engine.time_scale = 1.0
	var kinds := {"road": 0, "rail": 0}
	for c in traffic._fleet: kinds[c.kind] += 1
	print("TRAFFIC watched %d vehicles over %d game seconds (now %d cars and %d trains)" % [vehicles_seen.size(), samples, kinds.road, kinds.rail])
	print("TRAFFIC stuck: %d" % stuck_cases.size())
	for k in stuck_cases: print("TRAFFIC   stuck: ", stuck_cases[k])
	print("TRAFFIC inside a building: %d" % inside_cases.size())
	var n := 0
	for k in inside_cases:
		n += 1
		if n <= 20: print("TRAFFIC   inside: ", inside_cases[k])
	print("TRAFFIC with no next trip: %d" % notrip_cases.size())
	for k in notrip_cases: print("TRAFFIC   no trip: ", notrip_cases[k])
	quit(0)
