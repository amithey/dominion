extends SceneTree
var w: Node
func _initialize() -> void: call_deferred("run")
func shot(name: String, at: Vector3, distance: float, pitch: float) -> void:
	w.cam_focus = at
	w.cam_dist = distance
	w.cam_dist_target = distance
	w.cam_pitch = pitch
	w.update_camera(1.0)
	w.hud._process(1.0)
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/upgrade-%s.png" % name)
func run() -> void:
	change_scene_to_file("res://world.tscn")
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
	paused = true
	w.menu._root.hide()
	w.hud.show()
	w.economy.grant_test_resources()
	w.hud.set_production_open(true)
	await shot("build", w.start, 125, 0.85)
	w.hud.set_production_open(false)
	w.diplomacy.set_score(0, 1, 80)
	w.diplomacy.contacts.begin(1, "visit")
	w.diplomacy.contacts.advance(200)
	w.hud.open_diplomatic_contact(1)
	await shot("summit", w.start, 125, 0.85)
	w.hud.hide()
	var spot: Vector3 = w.start + Vector3(70, 0, 40)
	var soldier: Dictionary = w.spawn_unit("soldier", spot, 0)
	w.cam_yaw = 1.4
	soldier.player.advance(0.5)
	w.cam_lift = 1.5
	await shot("soldier", soldier.node.position, 5.5, 0.1)
	w.cam_yaw = -1.4
	await shot("soldier-reverse", soldier.node.position, 5.5, 0.1)
	w.cam_lift = 0
	w.cam_yaw = 1.4
	for key in ["cottage", "residential", "ammoDepot", "missileSilo"]:
		spot = w.test_site(key, w.start)
		var b: Dictionary = w.place_building(key, spot, 0, true)
		await shot(key, b.root.position, 36, 0.8)
	var fish: Array = w.deposits.filter(func(d): return d.type == "fish")
	if not fish.is_empty(): await shot("fish", fish[0].pos, 32, 0.7)
	print("UPGRADE_VIEWS PASS")
	quit()
