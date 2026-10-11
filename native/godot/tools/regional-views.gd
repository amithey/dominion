extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	set_meta("match_config", {"nation": 23, "players": 2, "map": "island", "style": "sandbox", "rivals": [22]})
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(20000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.menu.setup_options.nation = 23
	w.menu.open_new_game()
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build")
	root.get_texture().get_image().save_png("res://build/regional-picker.png")
	print("REGIONAL_VIEWS PASS")
	quit()
