extends SceneTree
## Pictures of every carrier class (force_models.carrier) in a studio of their
## own: build/carriers-<id>.png and build/carriers-all.png. Needs a window.
var w: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for frame in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	root.size = Vector2i(1280, 800)
	w.start_match("easy")
	w.menu.close()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.hud.visible = false
	DirAccess.make_dir_recursive_absolute("res://build")
	# A studio: a plain sea-blue floor far below the map, lit from above.
	var studio := Node3D.new()
	studio.position = Vector3(0, -400, 0)
	w.add_child(studio)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1d4a63")
	floor.material_override = mat
	studio.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	studio.add_child(sun)
	var cam := Camera3D.new()
	studio.add_child(cam)
	cam.current = true
	var original: String = str(w.map.nations[0].get("id", ""))
	var ids := ["usa", "china", "eu", "uk", "india", "japan", "turkiye", "iran"]
	var models := []
	for i in range(ids.size()):
		w.map.nations[0].id = ids[i]
		var parts: Dictionary = w.craft.build("carrier", 0)
		studio.add_child(parts.root)
		parts.root.position = Vector3((i % 4) * 40.0 - 60.0, 0.0, (i / 4) * 34.0 - 17.0)
		parts.root.rotation.y = 0.6
		models.append(parts.root)
	w.map.nations[0].id = original
	cam.global_position = studio.global_position + Vector3(0, 95, 70)
	cam.look_at(studio.global_position + Vector3(0, 0, 4), Vector3.UP)
	for frame in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/carriers-all.png")
	# Each class close up.
	for i in range(ids.size()):
		var at: Vector3 = models[i].global_position
		cam.global_position = at + Vector3(-22, 18, 22)
		cam.look_at(at + Vector3(0, 1, 0), Vector3.UP)
		for frame in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/carriers-%s.png" % ids[i])
	print("CARRIER_VIEWS PASS")
	quit()
