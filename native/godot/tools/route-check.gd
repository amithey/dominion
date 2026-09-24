extends SceneTree
## Long marches round obstacles: a mixed group ordered across the island's
## lake, and over a ridge, must walk round (not stall at the shore or the
## cliff), and every unit must arrive. Prints how far each walked against
## the length of the route the planner found.
var errors: Array[String] = []
const DT := 1.0 / 60.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func step(w: Node) -> void:
	w._physics_process(DT)
	w.effects._physics_process(DT)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	for i in range(5):
		await physics_frame
	# The lake: the lowest dry-land basin nearest the middle of the island.
	var lake := Vector3.ZERO
	var best := INF
	for x in range(-200, 201, 8):
		for z in range(-200, 201, 8):
			if w.height_at(x, z) < 0.0 and Vector2(x, z).length() < best and w.lake_mask.size() > 0:
				best = Vector2(x, z).length()
				lake = Vector3(x, 0, z)
	var trials := []
	for angle in [0.0, 1.1, 2.3]:
		var dir := Vector3(cos(angle), 0, sin(angle))
		var a := lake - dir * 70.0
		var b := lake + dir * 70.0
		if w.open_ground(a) and w.open_ground(b):
			trials.append(["across the lake", a, b])
	# The steepest ridge near the middle.
	var ridge := Vector3.ZERO
	var worst := 0.0
	for x in range(-160, 161, 8):
		for z in range(-160, 161, 8):
			if w.height_at(x, z) > 2.0 and not w.open_ground(Vector3(x, 0, z)) and w.normal_at(x, z).y < 0.8:
				var rise: float = w.height_at(x, z)
				if rise > worst:
					worst = rise
					ridge = Vector3(x, 0, z)
	for angle in [0.4, 1.9]:
		var dir := Vector3(cos(angle), 0, sin(angle))
		var a := ridge - dir * 55.0
		var b := ridge + dir * 55.0
		if w.open_ground(a) and w.open_ground(b):
			trials.append(["over a ridge", a, b])
	# Right across the island: from the capital to near each rival capital.
	for n in range(1, w.map.startPositions.size()):
		var sp: Array = w.map.startPositions[n]
		var far := Vector3(sp[0], 0, sp[1])
		var goal: Vector3 = far + (w.start - far).normalized() * 45.0
		if w.open_ground(goal):
			trials.append(["across the island to nation %d" % n, w.start + (far - w.start).normalized() * 30.0, goal])
	check(not trials.is_empty(), "found obstacles to march round")
	for t in trials:
		var group := []
		for i in range(6):
			var key: String = ["tank", "soldier", "apc", "soldier", "artillery", "sniper"][i]
			group.append(w.spawn_unit(key, t[1] + Vector3((i % 3) * 5.0 - 5.0, 0, floorf(i / 3.0) * 5.0), 0))
		var planned: PackedVector3Array = w.path_between(t[1], t[2])
		var plan_len := 0.0
		var prev: Vector3 = t[1]
		for p in planned:
			plan_len += Vector2(p.x - prev.x, p.z - prev.z).length()
			prev = p
		w.order_move(group, t[2])
		var walked := {}
		var last := {}
		for u in group:
			walked[u.node.get_instance_id()] = 0.0
			last[u.node.get_instance_id()] = u.node.position
		var took := -1.0
		for f in range(60 * 260):
			step(w)
			for u in group:
				var id: int = u.node.get_instance_id()
				walked[id] += Vector2(u.node.position.x - last[id].x, u.node.position.z - last[id].z).length()
				last[id] = u.node.position
			if group.all(func(u): return u.target == null):
				took = f / 60.0
				break
		var short: Array = group.filter(func(u): return Vector2(u.node.position.x - t[2].x, u.node.position.z - t[2].z).length() > 25.0)
		print("  %s: straight %.0f m, planned %.0f m, took %s, walked %s, short of the goal %d" % [t[0], t[1].distance_to(t[2]), plan_len, ("%.0f s" % took) if took >= 0 else "TIMEOUT", str(walked.values().map(func(v): return int(v))), short.size()])
		for u in short:
			print("     %s stopped at %s, %.0f m from the goal" % [u.key, u.node.position, Vector2(u.node.position.x - t[2].x, u.node.position.z - t[2].z).length()])
		check(took >= 0.0 and short.is_empty(), "every unit gets %s" % t[0])
		for u in group:
			w.kill(u)
	print("ROUTE_TEST PASS" if errors.is_empty() else "ROUTE_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
