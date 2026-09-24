extends SceneTree
## Close views of infantry holding their weapons, standing, walking and in a
## fight (build/soldier-*.png).
var w: Node
func _initialize() -> void: call_deferred("run")
var cam: Camera3D
func shot(name: String, at: Vector3, distance: float, pitch: float, yaw: float) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 40
		w.add_child(cam)
	cam.current = true
	var eye := at + Vector3(sin(yaw), 0, cos(yaw)) * distance + Vector3(0, 1.1 + pitch * distance, 0)
	cam.look_at_from_position(eye, at + Vector3(0, 1.2, 0))
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/soldier-%s.png" % name)
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
	var spot: Vector3 = w.start
	for tries in range(200):
		var p: Vector3 = w.start + Vector3(randf_range(-150, 150), 0, randf_range(-150, 150))
		if w.height_at(p.x, p.z) > 2.0 and w.normal_at(p.x, p.z).y > 0.96 and w.open_ground(p) and w.open_ground(p + Vector3(8, 0, 0)):
			spot = p
			break
	for n in w.find_children("*", "MultiMeshInstance3D", true, false) + w.find_children("*", "Sprite3D", true, false) + w.find_children("*", "Label3D", true, false):
		n.visible = false  # trees, grass and map markers out of the way
	var squad := []
	for k in range(4):
		var key: String = ["soldier", "sniper", "commando", "rocketSoldier"][k]
		var u: Dictionary = w.spawn_unit(key, spot + Vector3(0, 0, k * 2.4), 0)
		u.heading = 0.0
		squad.append(u)
	for i in range(30): await process_frame
	await shot("standing", squad[1].node.position + Vector3(0, 0, 1.2), 9.0, 0.02, PI * 0.5)
	await shot("standing-front", squad[0].node.position, 5.0, 0.02, -0.4)
	# Walking.
	w.order_move(squad, spot + Vector3(60, 0, 0))
	for i in range(50): await process_frame
	await shot("walking", squad[0].node.position, 6.0, 0.02, PI)
	# Firing at an enemy.
	if w.ai and not w.ai.nations.is_empty():
		w.ai.declare_war(1, false)
	var foe: Dictionary = w.spawn_unit("tank", squad[0].node.position + Vector3(45, 0, 0), 1)
	w.order_attack(squad, foe)
	for i in range(90): await process_frame
	await shot("firing", squad[0].node.position, 6.0, 0.02, PI)
	await shot("firing-behind", squad[0].node.position, 6.0, 0.05, -PI * 0.5)
	quit()
