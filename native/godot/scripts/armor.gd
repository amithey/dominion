extends RefCounted
## Ground vehicles built from code, in metres, facing +Z with the origin on the
## ground: a main battle tank, an 8x8 APC, a self-propelled howitzer, a
## Gepard-style anti-aircraft tank, an MLRS and a SAM truck. Armour is shaped
## from eight-corner blocks (sloped glacis, wedge turrets), running gear from
## cylinders and link plates, and every part carries its finish in its vertex
## colour (see vehicle.gdshader: paint shade, bare metal, the nation's
## markings, glass). Static parts merge into one mesh; the turret (with its
## gun) is a second one on a traverse pivot, and each axle of a wheeled vehicle
## is its own node so the wheels can turn. Nothing is downloaded.

const TRACKED := ["tank", "artillery", "aaVehicle", "mlrs"]

var world: Node
var _materials := {}
var _mat: ShaderMaterial   # the owner's material while a vehicle is being built

func setup(world_node: Node) -> void:
	world = world_node

## Returns {root, turret, radar, axles: [{node, radius}], muzzle}.
func build(key: String, owner: int) -> Dictionary:
	var parts := {"root": Node3D.new(), "turret": null, "radar": null, "axles": [], "muzzle": 4.2}
	_mat = material_for(owner)
	var body := _begin()
	var top := _begin()
	match key:
		"apc":
			apc(body, top, parts)
		"artillery":
			howitzer(body, top, parts)
		"aaVehicle":
			flak(body, top, parts, owner)
		"mlrs":
			rocket_launcher(body, top, parts)
		"samLauncher":
			sam_truck(body, top, parts, owner)
		_:
			tank(body, top, parts)
	_attach(parts.root, body)
	if parts.turret != null:
		_attach(parts.turret, top)
		parts.turret.set_meta("axis", Vector3.UP)
	return parts

func material_for(owner: int) -> ShaderMaterial:
	if not _materials.has(owner):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/vehicle.gdshader")
		m.set_shader_parameter("noise_tex", world.noise_texture)
		m.set_shader_parameter("paint", world.VEHICLE_PAINT[owner % world.VEHICLE_PAINT.size()])
		m.set_shader_parameter("team", Color(world.map.nations[owner].color) if owner < world.map.nations.size() else Color.WHITE)
		m.set_shader_parameter("vertex_tone", true)
		_materials[owner] = m
	return _materials[owner]

# ---------------------------------------------------------------- finishes

const PAINT := Color(0.5, 0.0, 0.0)       # shade 1.0
const LIGHT := Color(0.55, 0.0, 0.0)      # shade 1.1
const DARK := Color(0.38, 0.0, 0.0)       # shade 0.76
const METAL := Color(0.5, 1.0, 0.0)
const RUBBER := Color(0.2, 0.75, 0.0)
const TEAM := Color(0.5, 0.0, 1.0)
const GLASS := Color(0.5, 0.0, 0.5)

# ---------------------------------------------------------------- geometry

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _attach(parent: Node3D, st: SurfaceTool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _mat
	parent.add_child(mesh)
	return mesh

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, colour: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	st.set_color(colour)
	var normal := -((b - a).cross(c - a)).normalized()
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)

## A block from eight corners: bottom four then top four, each ring going
## front-left, front-right, back-right, back-left. Sloped plates, wedges and
## tapered turrets are all this.
func hexa(st: SurfaceTool, p: Array, colour: Color, xf := Transform3D.IDENTITY) -> void:
	var q := []
	var centre := Vector3.ZERO
	for v in p:
		q.append(xf * v)
		centre += xf * v
	centre /= 8.0
	for face in [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		var a: Vector3 = q[face[0]]
		var b: Vector3 = q[face[1]]
		var c: Vector3 = q[face[2]]
		var d: Vector3 = q[face[3]]
		var mid := (a + b + c + d) * 0.25
		_tri(st, a, b, c, mid - centre, colour)
		_tri(st, a, c, d, mid - centre, colour)

## Box of `size` centred at `at` (y is the bottom), optionally tapered toward
## the top (`taper` shrinks the top face) and with the top front edge pulled
## back by `slope` metres.
func block(st: SurfaceTool, size: Vector3, at: Vector3, colour: Color, taper := 0.0, slope := 0.0, back_slope := 0.0, xf := Transform3D.IDENTITY) -> void:
	var w := size.x * 0.5
	var l := size.z * 0.5
	var tw := w - taper
	var h := size.y
	hexa(st, [
		at + Vector3(-w, 0, l), at + Vector3(w, 0, l), at + Vector3(w, 0, -l), at + Vector3(-w, 0, -l),
		at + Vector3(-tw, h, l - slope), at + Vector3(tw, h, l - slope), at + Vector3(tw, h, -l + back_slope), at + Vector3(-tw, h, -l + back_slope),
	], colour, xf)

func prim(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, colour: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(colour)
	for i in indices:
		st.set_normal((xf.basis * normals[i]).normalized())
		st.add_vertex(xf * verts[i])

## Cylinder along `axis` ("x", "y" or "z") centred at `at`.
func cyl(st: SurfaceTool, r: float, length: float, at: Vector3, axis: String, colour: Color, sides := 12, r_end := -1.0, xf := Transform3D.IDENTITY) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r if r_end < 0.0 else r_end
	c.bottom_radius = r
	c.height = length
	c.radial_segments = sides
	c.rings = 1
	var basis := Basis()
	match axis:
		"x":
			basis = Basis(Vector3.BACK, -PI * 0.5)
		"z":
			basis = Basis(Vector3.RIGHT, PI * 0.5)
	prim(st, c, xf * Transform3D(basis, at), colour)

# ---------------------------------------------------------------- running gear

## Tracks, road wheels, sprocket, idler and return rollers on both sides.
func tracks(st: SurfaceTool, length: float, half_width: float, width: float, wheels: int, wheel_r: float) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * half_width
		var l := length * 0.5
		# The track is a loop: a ground run, a top run over the wheels, and the
		# rising ends round the idler (front) and sprocket (back).
		var top_y := wheel_r * 2.3
		var w := width * 0.5
		block(st, Vector3(width, 0.1, length - 1.1), Vector3(x, 0.0, 0.0), RUBBER)
		block(st, Vector3(width, 0.1, length - 0.2), Vector3(x, top_y - 0.1, 0.0), RUBBER)
		for end: float in [1.0, -1.0]:
			var near := l - 0.55 if end > 0.0 else l - 0.5
			hexa(st, [
				Vector3(x - w, 0.0, end * near), Vector3(x + w, 0.0, end * near), Vector3(x + w, 0.1, end * (near - 0.12)), Vector3(x - w, 0.1, end * (near - 0.12)),
				Vector3(x - w, top_y - 0.1, end * l), Vector3(x + w, top_y - 0.1, end * l), Vector3(x + w, top_y, end * (l - 0.14)), Vector3(x - w, top_y, end * (l - 0.14)),
			], RUBBER)
		# Link plates across the top and bottom runs.
		var links := int(length / 0.28)
		for i in range(links):
			var z := -l + 0.2 + i * (length - 0.4) / links
			block(st, Vector3(width + 0.06, 0.06, 0.1), Vector3(x, wheel_r * 2.3, z), METAL)
			if absf(z) < l - 0.6:
				block(st, Vector3(width + 0.06, 0.05, 0.12), Vector3(x, -0.02, z), METAL)
		# Road wheels with rubber tyres and hubs, standing proud of the track.
		for i in range(wheels):
			var z := -l + 0.85 + i * (length - 1.7) / (wheels - 1)
			cyl(st, wheel_r, width * 0.92, Vector3(x, wheel_r, z), "x", RUBBER, 14)
			cyl(st, wheel_r * 0.72, width + 0.04, Vector3(x, wheel_r, z), "x", DARK, 12)
			cyl(st, wheel_r * 0.22, width + 0.1, Vector3(x, wheel_r, z), "x", METAL, 8)
		# Sprocket (rear) and idler (front).
		cyl(st, wheel_r * 0.95, width * 0.8, Vector3(x, wheel_r * 1.55, -l + 0.4), "x", METAL, 12)
		cyl(st, wheel_r * 0.8, width * 0.8, Vector3(x, wheel_r * 1.55, l - 0.45), "x", DARK, 12)

## A pair of wheels on one axle as its own node, so it can turn.
func axle(parts: Dictionary, z: float, half_width: float, r: float, tyre_w: float) -> void:
	var st := _begin()
	for side: float in [-1.0, 1.0]:
		cyl(st, r, tyre_w, Vector3(side * half_width, 0, 0), "x", RUBBER, 16)
		cyl(st, r * 0.62, tyre_w + 0.04, Vector3(side * half_width, 0, 0), "x", DARK, 12)
		cyl(st, r * 0.2, tyre_w + 0.1, Vector3(side * half_width, 0, 0), "x", METAL, 8)
		# Tread blocks so rotation shows.
		for i in range(10):
			var a := TAU * i / 10.0
			block(st, Vector3(tyre_w * 0.9, 0.06, 0.12), Vector3(0, r - 0.03, 0), RUBBER, 0.0, 0.0, 0.0, Transform3D(Basis(Vector3.RIGHT, a), Vector3(side * half_width, 0, 0)))
	var node := Node3D.new()
	node.position = Vector3(0, r, z)
	parts.root.add_child(node)
	_attach(node, st)
	parts.axles.append({"node": node, "radius": r})

## Smoke grenade launchers: a fan of short tubes.
func smoke_launchers(st: SurfaceTool, at: Vector3, side: float, count := 4) -> void:
	for i in range(count):
		var yaw := side * (0.35 + i * 0.18)
		var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.5), at + Vector3(side * i * 0.04, i * 0.02, -i * 0.13))
		cyl(st, 0.07, 0.36, Vector3.ZERO, "z", DARK, 8, -1.0, xf)

func antenna(st: SurfaceTool, at: Vector3, height: float) -> void:
	cyl(st, 0.05, 0.14, at + Vector3(0, 0.07, 0), "y", METAL, 6)
	cyl(st, 0.012, height, at + Vector3(0, height * 0.5, 0), "y", METAL, 4)

func hatch(st: SurfaceTool, at: Vector3, r := 0.36) -> void:
	cyl(st, r, 0.12, at + Vector3(0, 0.06, 0), "y", DARK, 14)
	cyl(st, r * 0.8, 0.06, at + Vector3(0, 0.15, 0), "y", PAINT, 14)
	for i in range(4):
		var a := TAU * i / 4.0 + 0.4
		block(st, Vector3(0.1, 0.1, 0.06), at + Vector3(cos(a) * r, 0.1, sin(a) * r), GLASS)

# ---------------------------------------------------------------- vehicles

## Main battle tank: long hull on seven road wheels behind side skirts, sloped
## glacis, a wedge turret with a long smoothbore gun.
func tank(st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var length := 6.8
	tracks(st, length, 1.38, 0.72, 7, 0.34)
	# Lower hull between the tracks and the upper hull over them.
	block(st, Vector3(2.0, 0.75, length - 0.3), Vector3(0, 0.35, 0), DARK)
	block(st, Vector3(3.5, 0.62, length - 0.2), Vector3(0, 0.95, -0.15), PAINT, 0.05, 0.0, 0.25)
	# Glacis: the long sloped plate at the front.
	hexa(st, [Vector3(-1.75, 0.5, length * 0.5 + 0.1), Vector3(1.75, 0.5, length * 0.5 + 0.1), Vector3(1.75, 0.95, length * 0.5 - 0.35), Vector3(-1.75, 0.95, length * 0.5 - 0.35),
		Vector3(-1.72, 0.95, length * 0.5 + 0.05), Vector3(1.72, 0.95, length * 0.5 + 0.05), Vector3(1.7, 1.57, length * 0.5 - 1.6), Vector3(-1.7, 1.57, length * 0.5 - 1.6)], LIGHT)
	# Side skirts over the upper run, in panels.
	for side: float in [-1.0, 1.0]:
		for i in range(6):
			var z := -length * 0.5 + 0.7 + i * 1.02
			block(st, Vector3(0.08, 0.62, 0.98), Vector3(side * 1.78, 0.5, z), PAINT if i % 2 == 0 else LIGHT)
		# Headlights, tow hooks and mudguards.
		block(st, Vector3(0.22, 0.14, 0.12), Vector3(side * 1.35, 1.0, length * 0.5 - 0.3), GLASS)
		block(st, Vector3(0.14, 0.16, 0.3), Vector3(side * 0.9, 0.42, length * 0.5 + 0.02), METAL)
		# Stowage bins along the hull roof.
		block(st, Vector3(0.5, 0.35, 1.6), Vector3(side * 1.45, 1.57, -1.4), DARK)
	# Engine deck: grilles and exhausts at the back.
	for i in range(5):
		block(st, Vector3(2.4, 0.04, 0.12), Vector3(0, 1.57, -length * 0.5 + 0.5 + i * 0.28), METAL)
	block(st, Vector3(2.8, 0.4, 0.2), Vector3(0, 0.95, -length * 0.5 + 0.02), DARK)
	# Driver's hatch and periscopes.
	hatch(st, Vector3(0.5, 1.57, 1.9), 0.32)
	block(st, Vector3(0.7, 0.12, 0.1), Vector3(0.5, 1.6, 2.3), GLASS)

	var turret := Node3D.new()
	turret.position = Vector3(0, 1.57, 0.05)
	parts.root.add_child(turret)
	parts.turret = turret
	# Wedge turret: angled cheeks, flat roof, long bustle.
	hexa(top, [Vector3(-0.9, 0, 2.3), Vector3(0.9, 0, 2.3), Vector3(1.55, 0, -2.0), Vector3(-1.55, 0, -2.0),
		Vector3(-0.55, 0.78, 1.7), Vector3(0.55, 0.78, 1.7), Vector3(1.4, 0.82, -1.9), Vector3(-1.4, 0.82, -1.9)], PAINT)
	hexa(top, [Vector3(-1.55, 0, -2.0), Vector3(1.55, 0, -2.0), Vector3(1.35, 0.05, -2.9), Vector3(-1.35, 0.05, -2.9),
		Vector3(-1.4, 0.82, -1.9), Vector3(1.4, 0.82, -1.9), Vector3(1.25, 0.75, -2.8), Vector3(-1.25, 0.75, -2.8)], LIGHT)
	block(top, Vector3(2.9, 0.08, 0.9), Vector3(0, 0.82, -2.35), METAL)  # bustle rack
	# Mantlet and gun: barrel, fume extractor, muzzle reference.
	block(top, Vector3(0.9, 0.62, 0.5), Vector3(0, 0.1, 2.2), DARK, 0.05)
	cyl(top, 0.13, 4.8, Vector3(0, 0.42, 4.6), "z", PAINT, 12, 0.11)
	cyl(top, 0.19, 0.85, Vector3(0, 0.42, 4.2), "z", LIGHT, 12)
	cyl(top, 0.14, 0.3, Vector3(0, 0.42, 6.95), "z", DARK, 12)
	parts.muzzle = 7.0
	# Commander's cupola with sight, loader's hatch and machine gun.
	cyl(top, 0.42, 0.3, Vector3(-0.65, 0.95, -0.6), "y", DARK, 14)
	hatch(top, Vector3(-0.65, 1.1, -0.6), 0.34)
	block(top, Vector3(0.36, 0.42, 0.36), Vector3(-0.65, 1.2, 0.0), DARK)
	block(top, Vector3(0.3, 0.2, 0.06), Vector3(-0.65, 1.3, 0.19), GLASS)
	hatch(top, Vector3(0.6, 0.82, -0.7), 0.3)
	cyl(top, 0.035, 1.1, Vector3(0.6, 1.2, -0.3), "z", METAL, 6)
	block(top, Vector3(0.16, 0.2, 0.35), Vector3(0.6, 1.02, -0.8), METAL)
	# Gunner's sight box, smoke launchers, antennas, the nation's marking.
	block(top, Vector3(0.45, 0.35, 0.5), Vector3(0.75, 0.78, 1.0), DARK)
	block(top, Vector3(0.34, 0.22, 0.04), Vector3(0.75, 0.86, 1.26), GLASS)
	for side: float in [-1.0, 1.0]:
		smoke_launchers(top, Vector3(side * 1.2, 0.6, 0.6), side)
		block(top, Vector3(0.04, 0.34, 0.6), Vector3(side * 1.43, 0.32, -1.2), TEAM)
	antenna(top, Vector3(-1.1, 0.82, -2.2), 2.4)
	antenna(top, Vector3(1.1, 0.82, -2.2), 1.8)

## 8x8 armoured personnel carrier: boat-shaped nose, a small autocannon turret.
func apc(st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var length := 7.0
	for z: float in [2.2, 0.9, -0.9, -2.2]:
		axle(parts, z, 1.35, 0.56, 0.42)
	# Hull: sloped nose plate, straight sides with a flare, sloped rear.
	block(st, Vector3(2.8, 0.9, length - 1.2), Vector3(0, 0.55, -0.2), DARK)
	hexa(st, [Vector3(-1.55, 1.0, length * 0.5 - 0.7), Vector3(1.55, 1.0, length * 0.5 - 0.7), Vector3(1.6, 1.0, -length * 0.5 + 0.3), Vector3(-1.6, 1.0, -length * 0.5 + 0.3),
		Vector3(-1.5, 2.25, length * 0.5 - 1.5), Vector3(1.5, 2.25, length * 0.5 - 1.5), Vector3(1.45, 2.25, -length * 0.5 + 0.45), Vector3(-1.45, 2.25, -length * 0.5 + 0.45)], PAINT)
	hexa(st, [Vector3(-1.3, 0.55, length * 0.5), Vector3(1.3, 0.55, length * 0.5), Vector3(1.55, 1.0, length * 0.5 - 0.7), Vector3(-1.55, 1.0, length * 0.5 - 0.7),
		Vector3(-1.3, 0.9, length * 0.5 + 0.05), Vector3(1.3, 0.9, length * 0.5 + 0.05), Vector3(1.5, 2.25, length * 0.5 - 1.5), Vector3(-1.5, 2.25, length * 0.5 - 1.5)], LIGHT)
	for side: float in [-1.0, 1.0]:
		# Wheel arches, side vision blocks, a door stripe in the nation's colour.
		for z: float in [2.2, 0.9, -0.9, -2.2]:
			block(st, Vector3(0.2, 0.14, 1.3), Vector3(side * 1.5, 1.2, z), DARK)
		for i in range(3):
			block(st, Vector3(0.04, 0.14, 0.26), Vector3(side * 1.52, 1.85, 0.6 - i * 0.9), GLASS)
		block(st, Vector3(0.04, 0.3, 1.0), Vector3(side * 1.53, 1.35, -1.6), TEAM)
		block(st, Vector3(0.22, 0.14, 0.1), Vector3(side * 1.05, 0.95, length * 0.5 + 0.02), GLASS)
		smoke_launchers(st, Vector3(side * 1.25, 2.25, 1.2), side, 3)
	# Rear ramp outline, driver's hatch, stowage, antennas.
	block(st, Vector3(2.0, 1.3, 0.06), Vector3(0, 0.9, -length * 0.5 + 0.28), METAL)
	hatch(st, Vector3(-0.6, 2.25, 1.9), 0.3)
	block(st, Vector3(0.7, 0.1, 0.1), Vector3(-0.6, 2.3, 2.3), GLASS)
	block(st, Vector3(2.4, 0.3, 1.0), Vector3(0, 2.25, -2.3), DARK)
	antenna(st, Vector3(1.2, 2.25, -2.9), 2.2)
	antenna(st, Vector3(-1.2, 2.25, -2.9), 1.6)
	# Remote turret with a 30 mm cannon.
	var turret := Node3D.new()
	turret.position = Vector3(0.2, 2.25, 0.2)
	parts.root.add_child(turret)
	parts.turret = turret
	block(top, Vector3(1.5, 0.55, 1.8), Vector3(0, 0, 0), PAINT, 0.2, 0.3, 0.1)
	cyl(top, 0.07, 2.4, Vector3(0, 0.3, 2.0), "z", METAL, 8)
	cyl(top, 0.11, 0.5, Vector3(0, 0.3, 1.0), "z", DARK, 10)
	block(top, Vector3(0.36, 0.3, 0.3), Vector3(-0.55, 0.55, 0.3), DARK)
	block(top, Vector3(0.28, 0.18, 0.04), Vector3(-0.55, 0.6, 0.46), GLASS)
	smoke_launchers(top, Vector3(0.65, 0.3, 0.6), 1.0, 3)
	smoke_launchers(top, Vector3(-0.65, 0.3, 0.6), -1.0, 3)
	parts.muzzle = 3.4

## Self-propelled howitzer: tall tracked hull, big boxy turret at the rear and
## a long 155 mm barrel with a muzzle brake, raised a little.
func howitzer(st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var length := 7.2
	tracks(st, length, 1.4, 0.7, 7, 0.34)
	block(st, Vector3(2.0, 0.8, length - 0.3), Vector3(0, 0.35, 0), DARK)
	block(st, Vector3(3.5, 0.75, length - 0.2), Vector3(0, 0.95, 0), PAINT, 0.05, 0.9, 0.1)
	for side: float in [-1.0, 1.0]:
		for i in range(6):
			block(st, Vector3(0.08, 0.6, 1.08), Vector3(side * 1.78, 0.5, -length * 0.5 + 0.75 + i * 1.1), PAINT if i % 2 == 0 else LIGHT)
		block(st, Vector3(0.22, 0.14, 0.12), Vector3(side * 1.35, 1.2, length * 0.5 - 0.5), GLASS)
		# Recoil spades folded at the back.
		block(st, Vector3(0.5, 0.9, 0.12), Vector3(side * 0.9, 0.6, -length * 0.5 - 0.1), METAL)
	hatch(st, Vector3(0.7, 1.7, 2.3), 0.3)
	block(st, Vector3(1.6, 0.4, 0.8), Vector3(-0.6, 1.7, 2.3), DARK)
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.7, -0.9)
	parts.root.add_child(turret)
	parts.turret = turret
	block(top, Vector3(3.1, 1.35, 3.8), Vector3(0, 0, -0.2), PAINT, 0.15, 0.35, 0.1)
	block(top, Vector3(3.2, 0.08, 1.0), Vector3(0, 1.35, -1.6), METAL)
	# The barrel: cradle, long tube raised ~8 degrees, muzzle brake.
	var raise := Transform3D(Basis(Vector3.RIGHT, -0.14), Vector3(0, 0.75, 1.7))
	block(top, Vector3(1.0, 0.7, 0.7), Vector3(0, -0.35, 0), DARK, 0.0, 0.0, 0.0, raise)
	cyl(top, 0.17, 6.2, Vector3(0, 0, 3.4), "z", PAINT, 12, 0.14, raise)
	cyl(top, 0.25, 0.9, Vector3(0, 0, 1.2), "z", LIGHT, 12, -1.0, raise)
	block(top, Vector3(0.62, 0.3, 0.55), Vector3(0, -0.15, 6.6), DARK, 0.0, 0.0, 0.0, raise)
	parts.muzzle = 8.3
	for side: float in [-1.0, 1.0]:
		block(top, Vector3(0.04, 0.5, 1.2), Vector3(side * 1.56, 0.45, -0.8), TEAM)
		smoke_launchers(top, Vector3(side * 1.4, 0.9, 1.5), side)
	hatch(top, Vector3(-0.7, 1.35, -0.5), 0.34)
	cyl(top, 0.035, 1.1, Vector3(-0.7, 1.75, -0.1), "z", METAL, 6)
	antenna(top, Vector3(1.2, 1.35, -1.9), 2.2)

## Anti-aircraft tank: two 35 mm cannons on the turret sides, a search radar
## that turns on the roof and a tracking radar at the front.
func flak(st: SurfaceTool, top: SurfaceTool, parts: Dictionary, _owner: int) -> void:
	var length := 6.6
	tracks(st, length, 1.35, 0.68, 6, 0.34)
	block(st, Vector3(2.0, 0.75, length - 0.3), Vector3(0, 0.35, 0), DARK)
	block(st, Vector3(3.4, 0.62, length - 0.2), Vector3(0, 0.95, 0), PAINT, 0.05, 0.8, 0.2)
	for side: float in [-1.0, 1.0]:
		for i in range(5):
			block(st, Vector3(0.08, 0.6, 1.14), Vector3(side * 1.74, 0.5, -length * 0.5 + 0.8 + i * 1.18), PAINT if i % 2 == 0 else LIGHT)
		block(st, Vector3(0.22, 0.14, 0.12), Vector3(side * 1.3, 1.1, length * 0.5 - 0.5), GLASS)
	hatch(st, Vector3(0.6, 1.57, 2.2), 0.3)
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.57, -0.3)
	parts.root.add_child(turret)
	parts.turret = turret
	block(top, Vector3(2.3, 1.0, 2.6), Vector3(0, 0, 0), PAINT, 0.15, 0.3, 0.2)
	for side: float in [-1.0, 1.0]:
		# Gun pods on the cheeks, barrels angled up.
		var up := Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(side * 1.45, 0.6, 0.2))
		block(top, Vector3(0.55, 0.6, 1.6), Vector3(0, -0.3, 0), LIGHT, 0.05, 0.2, 0.0, up)
		cyl(top, 0.06, 2.6, Vector3(0, 0, 2.0), "z", METAL, 8, -1.0, up)
		cyl(top, 0.1, 0.3, Vector3(0, 0, 3.2), "z", DARK, 8, -1.0, up)
		block(top, Vector3(0.04, 0.3, 0.9), Vector3(side * 1.02, 0.4, -0.8), TEAM)
	# Tracking radar dish at the front of the roof.
	cyl(top, 0.45, 0.25, Vector3(0, 1.2, 1.1), "z", DARK, 16)
	block(top, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.95, 1.0), METAL)
	# Search radar: its own node so the game can spin it.
	var radar := Node3D.new()
	radar.position = Vector3(0, 1.0, -0.9)
	turret.add_child(radar)
	var dish := _begin()
	cyl(dish, 0.06, 0.6, Vector3(0, 0.3, 0), "y", METAL, 6)
	block(dish, Vector3(1.9, 0.5, 0.12), Vector3(0, 0.6, 0.0), DARK, 0.1)
	block(dish, Vector3(1.7, 0.3, 0.06), Vector3(0, 0.7, 0.08), METAL)
	_attach(radar, dish)
	parts.radar = radar
	parts.muzzle = 4.0

## MLRS: tracked carrier with an armoured cab and two six-tube rocket pods on
## a traversing launcher.
func rocket_launcher(st: SurfaceTool, top: SurfaceTool, parts: Dictionary) -> void:
	var length := 7.0
	tracks(st, length, 1.35, 0.66, 6, 0.33)
	block(st, Vector3(2.0, 0.7, length - 0.3), Vector3(0, 0.35, 0), DARK)
	block(st, Vector3(3.3, 0.45, length - 0.2), Vector3(0, 0.95, 0), PAINT)
	# Cab: sloped windscreen with armoured glass.
	block(st, Vector3(3.2, 1.3, 2.0), Vector3(0, 1.4, 2.3), PAINT, 0.1, 0.6, 0.0)
	block(st, Vector3(2.6, 0.5, 0.06), Vector3(0, 2.0, 3.05), GLASS, 0.0, 0.3)
	for side: float in [-1.0, 1.0]:
		block(st, Vector3(0.04, 0.45, 0.7), Vector3(side * 1.55, 1.9, 2.2), GLASS)
		block(st, Vector3(0.04, 0.5, 1.2), Vector3(side * 1.66, 1.0, 0.8), TEAM)
		block(st, Vector3(0.22, 0.14, 0.12), Vector3(side * 1.2, 1.3, length * 0.5 - 0.2), GLASS)
		for i in range(5):
			block(st, Vector3(0.08, 0.55, 1.2), Vector3(side * 1.7, 0.5, -length * 0.5 + 0.8 + i * 1.24), PAINT if i % 2 == 0 else LIGHT)
	antenna(st, Vector3(1.3, 2.7, 1.8), 2.0)
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.4, -1.4)
	parts.root.add_child(turret)
	parts.turret = turret
	block(top, Vector3(2.2, 0.35, 2.2), Vector3(0, 0, 0), METAL)
	var raise := Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.55, -0.4))
	for side: float in [-0.6, 0.6]:
		block(top, Vector3(1.05, 0.95, 3.6), Vector3(side, -0.1, 0.4), LIGHT, 0.0, 0.0, 0.0, raise)
		# Six tube mouths on the front face.
		for r in range(2):
			for c in range(3):
				cyl(top, 0.13, 0.06, Vector3(side + (c - 1) * 0.32, 0.15 + r * 0.42, 2.22), "z", DARK, 10, -1.0, raise)
	block(top, Vector3(0.3, 1.0, 0.3), Vector3(0, 0, 0.9), DARK)
	parts.muzzle = 2.6

## SAM truck: 6x6 chassis, cab, four canisters on a raised launcher and a
## folded radar mast.
func sam_truck(st: SurfaceTool, top: SurfaceTool, parts: Dictionary, _owner: int) -> void:
	for z: float in [2.4, -0.8, -2.2]:
		axle(parts, z, 1.1, 0.55, 0.45)
	block(st, Vector3(1.4, 0.4, 6.6), Vector3(0, 0.55, -0.1), METAL)  # chassis rails
	# Cab with windscreen, doors and mirrors.
	block(st, Vector3(2.5, 1.7, 1.9), Vector3(0, 0.95, 2.35), PAINT, 0.08, 0.35, 0.0)
	block(st, Vector3(2.2, 0.6, 0.06), Vector3(0, 1.9, 3.12), GLASS, 0.0, 0.25)
	for side: float in [-1.0, 1.0]:
		block(st, Vector3(0.04, 0.55, 0.9), Vector3(side * 1.26, 1.85, 2.3), GLASS)
		block(st, Vector3(0.05, 0.3, 0.1), Vector3(side * 1.4, 2.0, 2.9), METAL)
		block(st, Vector3(0.9, 0.12, 1.5), Vector3(side * 1.1, 1.1, 2.4), DARK)  # mudguards
		block(st, Vector3(0.9, 0.12, 2.6), Vector3(side * 1.1, 1.1, -1.5), DARK)
		block(st, Vector3(0.04, 0.4, 1.0), Vector3(side * 1.27, 1.3, 2.2), TEAM)
		block(st, Vector3(0.22, 0.14, 0.1), Vector3(side * 0.9, 1.1, 3.3), GLASS)
	block(st, Vector3(2.5, 0.25, 4.2), Vector3(0, 1.05, -1.1), PAINT)  # flatbed
	# Radar mast folded along the bed.
	block(st, Vector3(0.25, 0.25, 2.2), Vector3(0.8, 1.3, -1.2), METAL)
	block(st, Vector3(1.0, 0.7, 0.12), Vector3(0.8, 1.3, -2.4), DARK)
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.3, -1.4)
	parts.root.add_child(turret)
	parts.turret = turret
	cyl(top, 0.55, 0.3, Vector3(0, 0.15, 0), "y", METAL, 16)
	var raise := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, 0.55, 0.2))
	for c in range(4):
		var x := (c % 2 - 0.5) * 0.62
		var y := (c / 2) * 0.62
		cyl(top, 0.28, 3.6, Vector3(x, y + 0.3, 0.9), "z", LIGHT, 12, -1.0, raise)
		cyl(top, 0.22, 0.05, Vector3(x, y + 0.3, 2.72), "z", DARK, 12, -1.0, raise)
	block(top, Vector3(1.5, 0.12, 0.8), Vector3(0, -0.1, -0.2), DARK, 0.0, 0.0, 0.0, raise)
	parts.muzzle = 2.4
