extends SubViewportContainer
## Original stylised leaders and a ceremonial room, rendered in real time.
var viewport: SubViewport
var figures: Array = []
var elapsed := 0.0
var talking := false

func setup(colours: Array, identities: Array, together: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2(420, 300)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 430)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101f26")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c5d9df")
	settings.ambient_light_energy = 0.45
	env.environment = settings
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_color = Color("ffe4b9")
	light.light_energy = 1.7
	light.shadow_enabled = true
	root.add_child(light)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 3.0, 6.0)
	cam.look_at(Vector3(0, 1.4, 0))
	cam.fov = 43
	box(root, Vector3(0, -0.12, 0), Vector3(12, 0.2, 10), Color("243438"))
	box(root, Vector3(0, 2.8, -2.1), Vector3(10, 5.6, 0.2), Color("12282e"))
	for x in [-3.4, -1.9, 0.0, 1.9, 3.4]:
		box(root, Vector3(x, 2.4, -1.93), Vector3(0.045, 4.8, 0.04), Color("a68a50"), 0.65)
	for i in range(2):
		var x := -2.4 if i == 0 else 2.4
		box(root, Vector3(x, 1.8, -1.5), Vector3(0.035, 3.6, 0.035), Color("d1b576"), 0.75)
		box(root, Vector3(x + 0.32, 2.7, -1.5), Vector3(0.62, 1.05, 0.035), colours[i])
		box(root, Vector3(x + 0.32, 2.7, -1.46), Vector3(0.48, 0.07, 0.02), Color("e6d19b"))
		oval(root, Vector3(x, 3.66, -1.5), Vector3(0.1, 0.1, 0.1), Color("d1b576"))
	# A polished table with brass edging and negotiating folders.
	box(root, Vector3(0, 0.58, 0.45), Vector3(0.55, 1.1, 1.1), Color("182b2e"))
	box(root, Vector3(0, 1.16, 0.45), Vector3(3.45, 0.13, 1.7), Color("c0a575"), 0.6)
	box(root, Vector3(0, 1.24, 0.45), Vector3(3.4, 0.08, 1.65), Color("3c2923"))
	for i in range(2):
		var x := -1.05 if i == 0 else 1.05
		box(root, Vector3(x, 1.3, 0.55), Vector3(0.5, 0.035, 0.4), Color("122c32"))
		box(root, Vector3(x, 1.32, 0.53), Vector3(0.4, 0.008, 0.29), Color("e3dcc3"))
		if together or i == 1:
			_leader(root, x, colours[i], str(identities[i]), i)
	talking = together

func box(parent: Node3D, at: Vector3, dimensions: Vector3, colour: Color, metal := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, at, mesh, colour, metal)

func oval(parent: Node3D, at: Vector3, dimensions: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var node := _mesh(parent, at, mesh, colour)
	node.scale = dimensions
	return node

func _mesh(parent: Node3D, at: Vector3, shape: Mesh, colour: Color, metal := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metal
	material.roughness = 0.45
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

func _leader(parent: Node3D, x: float, accent: Color, identity: String, index: int) -> void:
	box(parent, Vector3(x, 1.1, -0.55), Vector3(0.88, 1.5, 0.2), Color("2a3638"))
	box(parent, Vector3(x, 0.51, -0.22), Vector3(0.88, 0.15, 0.7), Color("273235"))
	var body := Node3D.new()
	parent.add_child(body)
	body.position = Vector3(x, 0.63, -0.15)
	body.rotation.y = -0.46 if index == 1 else 0.46
	var skin: Color = [Color("c69776"), Color("aa7959"), Color("d9b294"), Color("94654d")][absi(identity.hash()) % 4]
	var suit := accent.darkened(0.65).lerp(Color("283038"), 0.5)
	oval(body, Vector3(0, 0.6, 0), Vector3(0.79, 1.02, 0.46), suit)
	box(body, Vector3(0, 0.84, 0.22), Vector3(0.22, 0.42, 0.03), Color("ede9da"))
	box(body, Vector3(0, 0.78, 0.25), Vector3(0.075, 0.32, 0.02), accent.lightened(0.25))
	oval(body, Vector3(0, 1.1, 0), Vector3(0.23, 0.26, 0.23), skin)
	var head := Node3D.new()
	body.add_child(head)
	head.position = Vector3(0, 1.38, 0)
	oval(head, Vector3.ZERO, Vector3(0.46, 0.59, 0.43), skin)
	oval(head, Vector3(0, 0.22, -0.025), Vector3(0.47, 0.19, 0.43), Color("454342") if index == 0 else Color("b1aaa0"))
	oval(head, Vector3(0, 0.0, 0.23), Vector3(0.075, 0.14, 0.11), skin.lightened(0.05))
	for side in [-1, 1]:
		oval(head, Vector3(side * 0.223, 0, 0), Vector3(0.07, 0.15, 0.1), skin)
		oval(head, Vector3(side * 0.09, 0.07, 0.196), Vector3(0.085, 0.027, 0.018), Color("272c2b"))
		box(head, Vector3(side * 0.09, 0.115, 0.185), Vector3(0.1, 0.018, 0.02), Color("58504a"))
		var arm := oval(body, Vector3(side * 0.36, 0.6, 0.13), Vector3(0.22, 0.65, 0.23), suit)
		arm.rotation.x = -0.6
		var forearm := oval(body, Vector3(side * 0.32, 0.65, 0.29), Vector3(0.18, 0.2, 0.48), suit)
		forearm.rotation.x = -0.16
		oval(body, Vector3(side * 0.32, 0.72, 0.49), Vector3(0.16, 0.1, 0.25), skin)
	box(head, Vector3(0, -0.14, 0.183), Vector3(0.13, 0.016, 0.016), Color("855c50"))
	figures.append({"body": body, "head": head, "yaw": body.rotation.y})

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed += delta
	for i in range(figures.size()):
		var f: Dictionary = figures[i]
		var speaking := talking and int(elapsed / 4.0) % 2 == i
		f.head.rotation.x = sin(elapsed * (4.0 if speaking else 0.8) + i) * (0.035 if speaking else 0.015)
		f.head.rotation.y = (0.16 if i == 0 else -0.16) if talking else 0.0
		f.body.rotation.z = sin(elapsed * 1.4 + i * PI) * 0.012

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
