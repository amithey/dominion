extends SceneTree
## The capital selected: its card with the town's accounts (build/town-card.png).
func _initialize() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	w.hud.show()
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	w.select_building(hq)
	w.cam_focus = hq.root.position
	w.cam_dist_target = 90.0
	for i in range(40):
		w.hud._process(1.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/town-card.png")
	quit()
