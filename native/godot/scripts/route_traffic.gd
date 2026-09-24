extends Node3D
## Ambient logistics vehicles use intact built links. Cargo ships exist only
## while an actual market shipment is at sea, and use the sea navigation grid.
var world: Node
var vehicles := {}
var elapsed := 0.0
var refresh := 0.0

func _process(delta: float) -> void:
	if world == null or world.market == null: return
	elapsed += delta
	refresh -= delta
	if refresh <= 0:
		refresh = 2.0
		_sync()
	for key in vehicles:
		var v: Dictionary = vehicles[key]
		var f: float = fposmod(elapsed * (0.07 if v.kind == "rail" else 0.11) + v.phase, 2.0)
		var reverse := f > 1.0
		if v.kind == "ship":
			var route = null
			for r in world.market.routes:
				if r.id == v.route: route = r
			if route == null or route.shipment == null:
				v.node.visible = false
				continue
			v.node.visible = true
			f = clampf(1.0 - (float(route.shipment.eta) - world.market._tick) / float(world.market.cfg.voyage), 0, 1)
			reverse = route.dir == "import"
			if reverse: f = 1.0 - f
		else:
			f = f if f <= 1.0 else 2.0 - f
		var step: float = f * (v.path.size() - 1)
		var i := mini(floori(step), v.path.size() - 2)
		var a: Vector3 = v.path[i]
		var b: Vector3 = v.path[i + 1]
		var p := a.lerp(b, step - i)
		p.y = float(world.map.seaLevel) + 0.2 if v.kind == "ship" else world.height_at(p.x, p.z) + 0.22
		v.node.position = p
		v.node.rotation.y = atan2(b.x - a.x, b.z - a.z) + (PI if reverse else 0.0)

func _sync() -> void:
	var live := {}
	for key in world.logistics.edges:
		if live.size() >= 80: break # bounded cosmetic draw cost
		var e: Dictionary = world.logistics.edges[key]
		if e.hp <= 0: continue
		var id := "land:" + str(key)
		live[id] = true
		if vehicles.has(id):
			if vehicles[id].kind == e.kind: continue
			vehicles[id].node.queue_free()
			vehicles.erase(id)
		_add(id, e.kind, PackedVector3Array([world.logistics.hex_center(e.a), world.logistics.hex_center(e.b)]), -1)
	for r in world.market.routes:
		if r.shipment == null: continue
		var id := "ship:%d" % r.id
		live[id] = true
		if vehicles.has(id): continue
		var port = null
		for b in world.buildings:
			if b.owner == 0 and b.key == "port" and b.built and not b.dead: port = b
		if port == null: continue
		if world.naval_navigation == null:
			world.naval_navigation = preload("res://scripts/naval_navigation.gd").new()
			world.naval_navigation.setup(world)
		var target: Array = world.map.startPositions[r.nation]
		var path: PackedVector3Array = world.naval_navigation.route(port.root.position, Vector3(target[0], 0, target[1]))
		if path.size() >= 2: _add(id, "ship", path, r.id)
	for key in vehicles.keys():
		if not live.has(key):
			vehicles[key].node.queue_free()
			vehicles.erase(key)

func _add(id: String, kind: String, path: PackedVector3Array, route: int) -> void:
	var root := Node3D.new()
	add_child(root)
	var ship := kind == "ship"
	var rail := kind == "rail"
	_box(root, Vector3(3.2, 1.3, 9) if ship else Vector3(1.4, 0.7, 4.2 if rail else 2.8), Vector3(0, 0.7, 0), Color("253b46"))
	_box(root, Vector3(2.5, 1.5, 2) if ship else Vector3(1.2, 0.7, 1.2), Vector3(0, 1.6 if ship else 1.2, 2.7 if ship else 0.6), Color("c2c1ae"))
	_box(root, Vector3(2.4, 1.2, 3.5) if ship else Vector3(1.25, 1, 1.5), Vector3(0, 1.6 if ship else 1.2, -1), Color("ae643c"))
	if not ship:
		for z in [-0.9, 0.9]:
			for x in [-0.72, 0.72]:
				var wheel := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.35
				mesh.bottom_radius = 0.35
				mesh.height = 0.18
				mesh.radial_segments = 10
				wheel.mesh = mesh
				wheel.rotation.z = PI * 0.5
				wheel.position = Vector3(x, 0.4, z)
				wheel.material_override = world.matte(Color("192329"))
				root.add_child(wheel)
		if rail:
			for z in [-4.5, -8.0]: _box(root, Vector3(1.4, 1.3, 3), Vector3(0, 0.9, z), Color("51666b"))
	vehicles[id] = {"node": root, "path": path, "kind": kind, "route": route, "phase": fposmod(float(id.hash()), 2.0)}

func _box(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = world.matte(colour)
	root.add_child(mesh)
