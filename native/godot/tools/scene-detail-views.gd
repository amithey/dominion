extends SceneTree
var w: Node
var prefix := "before"
func _initialize() -> void: call_deferred("run")
func shot(name: String, at: Vector3, distance: float) -> void:
	w.cam_focus = at; w.cam_dist = distance; w.cam_dist_target = distance
	w.cam_ground = INF; w.update_camera(1.0)
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/scene-detail/"+prefix+"-"+name+".png")
	print("CAPTURE ",name," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	if "--after-detail" in OS.get_cmdline_user_args(): prefix = "after"
	seed(1776)
	set_meta("match_config", {"map":"island", "players":4, "nation":0, "opening":"light"})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(2); return
	if w.menu._root == null: w.menu.setup(w)
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	w.quality = "balanced"; w.apply_quality()
	w.set_physics_process(false); w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w)
	w.edge_scroll = false; w.hud.hide(); w.cam_pitch = 0.72; w.cam_yaw = 0.65
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute("res://build/scene-detail")
	await shot("city", w.start, 90.0)
	await shot("facade", w.start, 42.0)
	var p: Vector3 = w.land_point(w.start, 80.0)
	for i in range(3):
		var u: Dictionary = w.spawn_unit(["tank","ifv","reconVehicle"][i],p+Vector3(i*9,0,0),0)
		u.node.reset_physics_interpolation()
	await shot("forest",p+Vector3(8,0,0),85.0)
	for tree in w.tree_nodes: tree.hide()
	await shot("units",p+Vector3(8,0,0),42.0)
	for tree in w.tree_nodes: tree.show()
	var shore: Vector3 = w.start
	for x in range(-160,161,5):
		var at: Vector3 = w.start+Vector3(x,0,85)
		if absf(w.height_at(at.x,at.z)-float(w.map.seaLevel)) < 0.5:
			shore = at; break
	await shot("coast",shore,125.0)
	w.quality = "low"; w.apply_quality()
	await shot("low-city",w.start,90.0)
	w.quality = "high"; w.apply_quality()
	await shot("high-facade",w.start,42.0)
	print("SCENE_DETAIL PASS ",prefix)
	quit(0)
