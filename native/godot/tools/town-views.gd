extends SceneTree
## A grown city (two rings of districts round the capital, mixed kinds) from
## above and from street level (build/town-*.png): to judge how crowded the
## houses look and the ground they stand on.
var w: Node
func _initialize() -> void: call_deferred("run")
func shot(name: String, at: Vector3, dist: float, pitch: float, yaw: float) -> void:
	w.cam_focus = at
	w.cam_dist = dist
	w.cam_dist_target = dist
	w.cam_pitch = pitch
	w.cam_yaw = yaw
	for i in range(30):
		w.update_camera(1.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/town-%s.png" % name)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	w.start_match("easy")
	w.menu._root.hide()
	w.hud.hide()
	var home: Vector2i = w.logistics.world_hex(w.start)
	var kinds := ["housing", "residential", "apartments", "cottage", "market", "school", "housing", "hospital", "residential", "park", "luxuryVillas", "library"]
	var k := 0
	for q in range(-2, 3):
		for r in range(-2, 3):
			var h := home + Vector2i(q, r)
			if w.logistics.hex_distance(home, h) > 2 or w.district_hex.has(h):
				continue
			var at: Vector3 = w.logistics.hex_center(h)
			if w.site_problem("housing", at, 0) != "" and not w.site_problem("housing", at, 0).begins_with("Too close to"):
				continue
			var key: String = kinds[k % kinds.size()]
			k += 1
			if w.building_defs.has(key):
				w.place_building(key, at, 0, true)
	w.refresh_streets()
	for i in range(20): await process_frame
	var c: Vector3 = w.logistics.hex_center(home)
	await shot("overview", c, 150.0, 0.95, 0.5)
	await shot("oblique", c, 95.0, 0.62, 0.9)
	await shot("street", c + Vector3(18, 0, 22), 42.0, 0.42, 2.3)
	quit()
