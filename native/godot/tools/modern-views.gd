extends SceneTree
## Close views of the modern units (modern_warfare.gd) in the player's colours:
## build/modern-<key>.png, and build/modern-lineup.png with the vehicles together.
var w: Node
var cam: Camera3D
func _initialize() -> void: call_deferred("run")
func shot(name: String, at: Vector3, distance: float, height: float, yaw: float) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 40
		w.add_child(cam)
	cam.current = true
	var eye := at + Vector3(sin(yaw), 0, cos(yaw)) * distance + Vector3(0, height, 0)
	cam.look_at_from_position(eye, at + Vector3(0, 1.0, 0))
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/modern-%s.png" % name)
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
	paused = false
	w.set_physics_process(false)
	var spot: Vector3 = w.start
	for tries in range(400):
		var p: Vector3 = w.start + Vector3(randf_range(-150, 150), 0, randf_range(-150, 150))
		if w.height_at(p.x, p.z) > 2.0 and w.normal_at(p.x, p.z).y > 0.97 and w.open_ground(p) and w.open_ground(p + Vector3(24, 0, 0)):
			spot = p
			break
	for n in w.find_children("*", "MultiMeshInstance3D", true, false) + w.find_children("*", "Sprite3D", true, false) + w.find_children("*", "Label3D", true, false):
		n.visible = false
	var keys := ["himars", "ewVehicle", "laserAD", "abmLauncher", "df17", "shahedLauncher", "irisT", "loiterer", "stealthFighter", "raptor", "raider", "shahed", "seaDrone", "fpvTeam", "atgmTeam", "manpads", "medic"]
	var units := {}
	for i in range(keys.size()):
		var key: String = keys[i]
		var at: Vector3 = spot + Vector3(i * 9.0, 0, 0)
		at.y = w.height_at(at.x, at.z)
		var u: Dictionary = w.spawn_unit(key, at, 0)
		if u.get("fly", false) or u.get("naval", false):
			u.node.position = at + Vector3(0, 1.5, 0)   # shown on the ground beside the rest
		u.node.rotation.y = 0.4
		units[key] = u
	for i in range(20): await process_frame
	for key in keys:
		var u: Dictionary = units[key]
		var small: bool = key in ["fpvTeam", "atgmTeam", "manpads", "medic", "loiterer", "seaDrone", "shahed"]
		await shot(key, u.node.position, 7.0 if small else 13.0, 3.0 if small else 5.5, 0.9)
	await shot("lineup", spot + Vector3(18, 0, 0), 42.0, 16.0, 0.5)
	quit()
