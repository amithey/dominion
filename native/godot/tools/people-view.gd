## Contact sheet of the Blender-made people: every kind in each clip, from the front-left, saved to build/people-<clip>.png.
## Run windowed: Godot --path native/godot -s res://tools/people-view.gd -- [kind ...] [--clip=run_gun] [--time=0.3] [--yaw=40]
extends SceneTree

const People := preload("res://scripts/people.gd")

func _initialize() -> void:
	var kinds: Array = []
	var clip := "run_gun"
	var at := 0.3
	var yaw := 40.0
	var dist := -1.0
	var focus := 0.95
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="): clip = a.get_slice("=", 1)
		elif a.begins_with("--time="): at = float(a.get_slice("=", 1))
		elif a.begins_with("--yaw="): yaw = float(a.get_slice("=", 1))
		elif a.begins_with("--dist="): dist = float(a.get_slice("=", 1))
		elif a.begins_with("--focus="): focus = float(a.get_slice("=", 1))
		else: kinds.append(a)
	if kinds.is_empty():
		kinds = ["soldier", "sniper", "commando", "rocketSoldier", "atgmTeam", "manpads", "medic", "worker", "fpvTeam", "scoutTeam"]
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.4
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 20)
	floor.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.45, 0.32)
	floor.material_override = fm
	root.add_child(floor)
	var n := kinds.size()
	for i in range(n):
		var m: Node3D = People.build(kinds[i], Color("5d6446"), Color("4c5139"), Color("2f6fd0"))
		if m == null:
			print("MISSING ", kinds[i])
			continue
		m.position = Vector3((i - (n - 1) * 0.5) * 1.6, 0, 0)
		m.rotation_degrees.y = yaw
		root.add_child(m)
		for p in m.find_children("*", "AnimationPlayer", true, false):
			var list: PackedStringArray = (p as AnimationPlayer).get_animation_list()
			if i == 0: print("CLIPS ", list)
			if (p as AnimationPlayer).has_animation(clip):
				(p as AnimationPlayer).play(clip)
				(p as AnimationPlayer).seek(at, true)
				(p as AnimationPlayer).pause()
	var cam := Camera3D.new()
	cam.position = Vector3(0, focus + 0.1, dist if dist > 0.0 else 2.0 + n * 1.25)
	cam.fov = 38.0
	root.add_child(cam)
	cam.look_at(Vector3(0, focus, 0))
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://build/people-%s.png" % clip)
	quit()
