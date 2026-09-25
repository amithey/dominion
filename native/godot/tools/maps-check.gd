extends SceneTree
## Every map loads and is playable: each capital stands on land with its town
## and army, every rival capital can be reached by land from yours, oil, iron
## and gold lie near each capital, and warships start at sea. With a window,
## saves an overview of each map (build/map-<key>.png).
var errors: Array[String] = []
const MAPS := ["small", "twin", "archipelago", "continent", "island"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	for key in MAPS:
		set_meta("match_config", {"map": key, "players": 4, "nation": 0, "style": "standard"})
		change_scene_to_file("res://world.tscn")
		var w: Node = null
		var t0 := Time.get_ticks_msec()
		for i in range(4000):
			await process_frame
			if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
				w = current_scene
				break
		if w == null:
			errors.append("%s did not load" % key)
			continue
		print("MAP %s: size %d, grid %d, loaded in %.1f s, %d trees, %d deposits" % [key, int(w.map.mapSize), w.grid_size, (Time.get_ticks_msec() - t0) / 1000.0, w.map.trees.size(), w.deposits.size()])
		if w.menu.get("_root") == null: w.menu.setup(w)
		w.start_match("easy")
		w.menu._root.hide()
		for i in range(20):
			await physics_frame  # the navigation map takes in the towns' closed cells
		check(int(w.map.mapSize) == ({"small": 440, "twin": 720, "archipelago": 800, "continent": 960}.get(key, 640)), "%s has its size" % key)
		var hqs: Array = w.buildings.filter(func(b): return b.key == "hq")
		check(hqs.size() == 4 and hqs.all(func(b): return w.height_at(b.root.position.x, b.root.position.z) > 1.0), "%s: four capitals on dry land" % key)
		var mine: Vector3 = hqs.filter(func(b): return b.owner == 0)[0].root.position
		for b in hqs:
			if b.owner == 0:
				continue
			var goal: Vector3 = b.root.position + (mine - b.root.position).normalized() * 16.0
			var route: PackedVector3Array = w.path_between(mine + (b.root.position - mine).normalized() * 16.0, goal)
			var reached: bool = not route.is_empty() and Vector2(route[-1].x - goal.x, route[-1].z - goal.z).length() < 20.0
			if not reached:
				print("   route %d points, ends %s, goal %s" % [route.size(), route[-1] if not route.is_empty() else Vector3.INF, goal])
			check(reached, "%s: nation %d's capital can be reached by land" % [key, b.owner])
		for b in hqs:
			var near := {}
			for d in w.deposits:
				if d.pos.distance_to(b.root.position) < 110.0:
					near[d.type] = true
			if key != "island": check(near.has("oil") and near.has("iron") and near.has("gold"), "%s: oil, iron and gold near nation %d" % [key, b.owner])
		var ships: Array = w.units.filter(func(u): return u.get("naval", false))
		check(ships.all(func(u): return w.is_water(u.node.position, -1.0)), "%s: warships start at sea" % key)
		check(w.units.filter(func(u): return not u.get("naval", false) and not u.get("fly", false)).all(func(u): return w.height_at(u.node.position.x, u.node.position.z) > 0.3), "%s: land units start on land" % key)
		if DisplayServer.get_name() != "headless":
			w.hud.hide()
			w.cam_focus = Vector3.ZERO
			w.cam_dist = float(w.map.mapSize) * 1.25
			w.cam_dist_target = w.cam_dist
			w.cam_pitch = 1.35
			w.cam_yaw = 0.0
			for i in range(40):
				w.update_camera(1.0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/map-%s.png" % key)
	print("MAPS_TEST PASS" if errors.is_empty() else "MAPS_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
