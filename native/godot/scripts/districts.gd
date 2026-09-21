extends RefCounted
## Civilization-style districts: every building owns a whole hex.
## A district is a paved or planted hex tile laid over the terrain (flattened
## toward its centre, with a skirt that hides gaps on slopes), the building
## itself, and props that say what the place is: house clusters with gardens,
## container yards and fuel tanks, barns and haystacks, sandbags and a
## watchtower, a plaza with planters and street lamps. Procedural props merge
## into one vertex-coloured mesh per district; houses are the Kenney models.
## Streets inside the tile are drawn by district.gdshader toward connected
## neighbours (see set_streets).

const STYLE := {
	"hq": 0, "villageCenter": 0, "cityCenter": 0, "market": 0, "intelAgency": 0,
	"cottage": 1, "housing": 1, "residential": 1, "workerHouse": 1, "apartments": 1, "luxuryVillas": 1,
	"warehouse": 2, "foodDepot": 2, "tankFactory": 2, "powerPlant": 2, "oilRefinery": 2,
	"farm": 3,
	"barracks": 4, "bunker": 4, "commandCenter": 4, "ammoDepot": 4, "helipad": 4, "airfield": 4, "missileSilo": 4,
	"shipyard": 2, "port": 2,
}
const HOUSES := ["res://assets/House_A.glb", "res://assets/House_B.glb", "res://assets/House_C.glb", "res://assets/House_D.glb"]
# How many houses stand in a residential district, one per wedge between streets.
const HOUSE_COUNT := {"cottage": 4, "residential": 6, "workerHouse": 3, "luxuryVillas": 3}

var world: Node
var radius := 12.0
var ground: ShaderMaterial
var props_material: StandardMaterial3D
var _house_scenes := {}
var _tinted := {}          # [source material, owner] -> toned copy
var owner := 0             # nation of the district being built
var city_size := 0         # districts that nation already has
# Tallest a district's central building may stand, per style (metres).
const MAX_HEIGHT := {0: 13.0, 1: 8.0, 2: 7.5, 3: 7.0, 4: 6.5}

func setup(world_node: Node) -> void:
	world = world_node
	radius = world.logistics.radius
	ground = ShaderMaterial.new()
	ground.shader = load("res://shaders/district.gdshader")
	ground.set_shader_parameter("paving_tex", load("res://assets/architecture/concrete_diffuse.jpg"))
	ground.set_shader_parameter("grass_tex", load("res://assets/terrain/grass_color.jpg"))
	ground.set_shader_parameter("dirt_tex", load("res://assets/terrain/dirt_color.jpg"))
	ground.set_shader_parameter("noise_tex", world.noise_texture)
	ground.set_shader_parameter("hex_radius", radius)
	props_material = StandardMaterial3D.new()
	props_material.vertex_color_use_as_albedo = true
	props_material.vertex_color_is_srgb = true
	props_material.roughness = 0.85

func style_of(key: String) -> int:
	return STYLE.get(key, 2)

## Builds a district for `key` at hex centre `centre` (y = terrain height).
## Returns {pad, container, floor_y}: the pad stays put, the container (building
## and props) is what grows during construction and collapses when destroyed.
func build(key: String, centre: Vector3, seed: float, owner_id := 0, size := 0) -> Dictionary:
	owner = owner_id
	city_size = size
	var floor_y := floor_height(centre)
	var pad := make_pad(centre, floor_y)
	pad.set_instance_shader_parameter("style", style_of(key))
	pad.set_instance_shader_parameter("seed", seed)
	var container := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed * 1000.0) + key.hash()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match style_of(key):
		0:
			plaza(key, container, st, rng)
		1:
			residential(key, container, st, rng)
		3:
			farmstead(key, container, st, rng)
		4:
			barracks(key, container, st, rng)
		_:
			yard(key, container, st, rng)
	landmarks(key, st, rng)
	tone(container, owner)
	var props := MeshInstance3D.new()
	props.mesh = st.commit()  # normals were set per primitive
	props.material_override = props_material
	container.add_child(props)
	return {"pad": pad, "container": container, "floor_y": floor_y}

# ---------------------------------------------------------------- the tile

func corner(k: int) -> Vector2:
	var a := deg_to_rad(30.0 + 60.0 * k)
	return Vector2(cos(a), sin(a)) * radius

func floor_height(centre: Vector3) -> float:
	var total: float = world.height_at(centre.x, centre.z)
	for k in range(6):
		var c := corner(k) * 0.7
		total += world.height_at(centre.x + c.x, centre.z + c.y)
	return total / 7.0

# Three rings of a hexagon, eased onto the floor height near the middle and
# onto the terrain at the rim, never below the ground; a skirt drops from the
# rim so no gap shows on a slope.
func make_pad(centre: Vector3, floor_y: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [0.0, 0.4, 0.75, 1.0]
	var points := []   # rings of local Vector3
	for f in rings:
		var ring := []
		var count := 1 if f == 0.0 else 24
		for j in range(count):
			var p := Vector2.ZERO
			if f > 0.0:
				var c := j / 4
				p = corner(c).lerp(corner((c + 1) % 6), (j % 4) / 4.0) * f
			var ground_y: float = world.height_at(centre.x + p.x, centre.z + p.y)
			var y: float = maxf(lerpf(floor_y, ground_y, pow(f, 3.0)), ground_y + 0.03) + 0.05
			ring.append(Vector3(p.x, y - centre.y, p.y))
		points.append(ring)
	for j in range(24):
		# Clockwise seen from above: Godot's front faces.
		st.add_vertex(points[0][0])
		st.add_vertex(points[1][j])
		st.add_vertex(points[1][(j + 1) % 24])
	for r in range(1, rings.size() - 1):
		for j in range(24):
			var a: Vector3 = points[r][j]
			var b: Vector3 = points[r][(j + 1) % 24]
			var c: Vector3 = points[r + 1][j]
			var d: Vector3 = points[r + 1][(j + 1) % 24]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	var rim: Array = points[rings.size() - 1]
	for j in range(24):
		var a: Vector3 = rim[j]
		var b: Vector3 = rim[(j + 1) % 24]
		var a2 := a - Vector3(0, 1.8, 0)
		var b2 := b - Vector3(0, 1.8, 0)
		for v in [a, a2, b, b, a2, b2]:
			st.add_vertex(v)
	st.generate_normals()
	var pad := MeshInstance3D.new()
	pad.mesh = st.commit()
	pad.material_override = ground
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pad

## Streets run toward neighbours whose bit is set (bit k = direction k * 60°).
func set_streets(pad: MeshInstance3D, mask: int) -> void:
	pad.set_instance_shader_parameter("streets", mask)

# ---------------------------------------------------------------- props

# Adds a primitive, transformed and painted, to the district's prop mesh.
func shape(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(color)
	for i in indices:
		st.set_normal((xf.basis * normals[i]).normalized())
		st.add_vertex(xf * verts[i])

func box(st: SurfaceTool, size: Vector3, at: Vector3, yaw: float, color: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	shape(st, m, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, size.y * 0.5, 0)), color)

func cylinder(st: SurfaceTool, r: float, h: float, at: Vector3, color: Color, sides := 10) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	shape(st, m, Transform3D(Basis(), at + Vector3(0, h * 0.5, 0)), color)

func tree(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator, scale := 1.0) -> void:
	var h := rng.randf_range(3.2, 4.6) * scale
	cylinder(st, 0.14 * scale, h * 0.45, at, Color("4f3a2a"), 6)
	var crown := SphereMesh.new()
	crown.radius = h * 0.32
	crown.height = h * 0.62
	crown.radial_segments = 8
	crown.rings = 5
	var green := Color("3e5a2c").lerp(Color("5f7a34"), rng.randf())
	shape(st, crown, Transform3D(Basis(), at + Vector3(0, h * 0.62, 0)), green)

func lamp(st: SurfaceTool, at: Vector3) -> void:
	cylinder(st, 0.06, 3.4, at, Color("2d3032"), 6)
	box(st, Vector3(0.45, 0.18, 0.28), at + Vector3(0, 3.35, 0), 0.0, Color("e9dfbf"))

# Wedge centres between the six street directions.
func slot(k: int, r: float) -> Vector3:
	var a := deg_to_rad(30.0 + 60.0 * k)
	return Vector3(cos(a) * r, 0, sin(a) * r)

# A low fence along the hex edge, open where streets may enter.
func fence(st: SurfaceTool, color: Color, height := 1.1) -> void:
	var apothem := radius * 0.866 - 1.0
	for k in range(6):
		var a := corner(k) * (apothem / (radius * 0.866))
		var b := corner((k + 1) % 6) * (apothem / (radius * 0.866))
		for i in range(9):
			var t := i / 8.0
			if absf(t - 0.5) < 0.2:
				continue  # the gateway in the middle of each side
			var p := a.lerp(b, t)
			box(st, Vector3(0.12, height, 0.12), Vector3(p.x, 0, p.y), 0.0, color)
		for part in [[0.0, 0.3], [0.7, 1.0]]:
			var p0 := a.lerp(b, part[0])
			var p1 := a.lerp(b, part[1])
			var mid := (p0 + p1) * 0.5
			var yaw := -atan2(p1.y - p0.y, p1.x - p0.x)
			box(st, Vector3(p0.distance_to(p1), 0.08, 0.06), Vector3(mid.x, height * 0.75, mid.y), yaw, color)

func main_building(key: String, container: Node3D, footprint: float, at := Vector3.ZERO) -> void:
	var model: Node3D = world.building_model(key, 0.0, 0.0)
	var bounds: AABB = world.model_bounds(model)
	var size := maxf(maxf(bounds.size.x * model.scale.x, bounds.size.z * model.scale.z), 0.01)
	var k := footprint / size
	var height := bounds.size.y * model.scale.y * k
	var cap: float = MAX_HEIGHT.get(style_of(key), 8.0) * (1.0 + 0.04 * mini(city_size, 10))
	if height > cap:
		k *= cap / height  # tall Kenney towers would dwarf the district
	model.scale *= k
	model.position = model.position * k + at
	container.add_child(model)

# The Kenney colour atlases are near-white and toy-bright. Each model is
# knocked back to weathered, lived-in tones, and roofs, awnings and trim take
# a little of the owner's colour so a city's nation reads from the air.
func tone(container: Node3D, nation: int) -> void:
	var colour: Color = Color(world.map.nations[nation].color) if nation < world.map.nations.size() else Color.WHITE
	for mesh_instance in container.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		for i in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(i) as BaseMaterial3D
			if source == null:
				continue
			var key := [source.get_instance_id(), nation]
			if not _tinted.has(key):
				var m: BaseMaterial3D = source.duplicate()
				var name := source.resource_name.to_lower()
				var accent := name.contains("roof") or name.contains("awning") or name.contains("red") or name.contains("door")
				var base := m.albedo_color * Color(0.76, 0.74, 0.69)
				m.albedo_color = base.lerp(colour * Color(0.8, 0.8, 0.8), 0.45 if accent else 0.1)
				m.roughness = maxf(m.roughness, 0.8)
				m.metallic = minf(m.metallic, 0.1)
				_tinted[key] = m
			mesh_instance.set_surface_override_material(i, _tinted[key])

func house(container: Node3D, at: Vector3, face: float, size: float, rng: RandomNumberGenerator) -> void:
	var path: String = HOUSES[rng.randi() % HOUSES.size()]
	if not _house_scenes.has(path):
		_house_scenes[path] = load(path)
	var model: Node3D = _house_scenes[path].instantiate()
	var bounds: AABB = world.model_bounds(model)
	var k := size / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
	model.scale = Vector3.ONE * k
	model.position = Vector3(-bounds.get_center().x * k, -bounds.position.y * k, -bounds.get_center().z * k)
	var holder := Node3D.new()
	holder.add_child(model)
	holder.position = at
	holder.rotation.y = face
	container.add_child(holder)

# ---------------------------------------------------------------- layouts

func plaza(key: String, container: Node3D, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	main_building(key, container, 10.0 if key != "villageCenter" else 7.5)
	for k in [0, 2, 4]:
		var p := slot(k, 7.6)
		cylinder(st, 1.1, 0.5, p, Color("8a877d"), 12)
		tree(st, p + Vector3(0, 0.5, 0), rng, 0.9)
	for k in range(6):
		var a := deg_to_rad(60.0 * k + 18.0)
		lamp(st, Vector3(cos(a), 0, sin(a)) * 8.4)
	if key == "villageCenter":
		var well := slot(1, 7.0)
		cylinder(st, 0.9, 0.8, well, Color("7d7568"), 12)
		box(st, Vector3(1.9, 0.12, 0.25), well + Vector3(0, 1.9, 0), 0.0, Color("5a4432"))
	else:
		for k in [1, 3, 5]:
			var p := slot(k, 8.0)
			box(st, Vector3(1.6, 0.45, 0.5), p, deg_to_rad(-(30.0 + 60.0 * k)), Color("6a5039"))

func residential(key: String, container: Node3D, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	if key in ["housing", "apartments"]:
		main_building(key, container, 8.5)
		for k in [0, 2, 3, 5]:
			tree(st, slot(k, 7.8), rng)
		return
	# A growing city fills its blocks: more and larger houses, fewer gardens.
	var growth := clampf(city_size / 10.0, 0.0, 1.0)
	var count: int = mini(6, HOUSE_COUNT.get(key, 4) + int(growth * 2.0))
	var slots := [0, 1, 3, 4, 2, 5].slice(0, count)
	for k in slots:
		var p := slot(k, 6.2)
		# Houses face the middle of the block; each has a hedge and a tree.
		house(container, p, deg_to_rad(-(30.0 + 60.0 * k)) - PI * 0.5, 5.0 + growth * 0.9 + rng.randf() * 0.8, rng)
		var back := slot(k, 9.0)
		box(st, Vector3(3.6, 0.8, 0.5), back, deg_to_rad(-(30.0 + 60.0 * k)) + PI * 0.5, Color("3f5a2c"))
		tree(st, slot(k, 8.6) + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), rng, 0.8)
	if growth < 0.6:
		tree(st, Vector3.ZERO, rng, 1.2)
	else:
		cylinder(st, 1.3, 0.6, Vector3.ZERO, Color("8a877d"), 12)  # a small square with a fountain
		cylinder(st, 0.3, 1.3, Vector3.ZERO, Color("a8a59b"), 8)

func farmstead(key: String, container: Node3D, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	main_building(key, container, 7.5, slot(0, 4.2))
	cylinder(st, 1.5, 7.0, slot(1, 6.4), Color("9aa0a0"), 14)
	cylinder(st, 1.6, 0.4, slot(1, 6.4) + Vector3(0, 7.0, 0), Color("6e7474"), 14)
	for i in range(5):
		var p := slot(3, 6.0) + Vector3(rng.randf_range(-2.2, 2.2), 0, rng.randf_range(-2.2, 2.2))
		cylinder(st, 0.7, 0.9, p, Color("c9ae62"), 10)
	fence(st, Color("6b5238"), 1.0)

func yard(key: String, container: Node3D, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	if key == "extractor":
		main_building(key, container, 6.0)
		return
	main_building(key, container, 9.5)
	# Stacked shipping containers in faded paint.
	var paints := [Color("7a3b2e"), Color("35506a"), Color("5b6b3a"), Color("8a6a2a")]
	for k in [0, 3]:
		var p := slot(k, 7.8)
		var yaw := deg_to_rad(-(30.0 + 60.0 * k)) + PI * 0.5
		for layer in range(rng.randi_range(1, 2)):
			for side in [-1, 1]:
				var offset := Vector3(0, layer * 2.4, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, side * 1.25)
				box(st, Vector3(5.8, 2.4, 2.35), p + offset, yaw, paints[rng.randi() % paints.size()])
	# Fuel tanks.
	for i in range(2):
		cylinder(st, 1.2, 3.2, slot(1, 7.4) + Vector3(i * 2.6 - 1.3, 0, 0), Color("b9bcb8"), 14)
	# Crates and pallets.
	for i in range(6):
		var p := slot(4, 7.4) + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
		box(st, Vector3(1.0, 0.9, 1.0), p, rng.randf() * TAU, Color("7b5f3e"))
	for k in [2, 5]:
		lamp(st, slot(k, 8.8))
	fence(st, Color("5d6264"), 1.6)

func barracks(key: String, container: Node3D, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	main_building(key, container, 9.0)
	# Sandbag emplacements.
	for k in [1, 4]:
		var centre := slot(k, 7.6)
		for i in range(5):
			var a := deg_to_rad(30.0 + 60.0 * k) + (i - 2) * 0.28
			var p := Vector3(cos(a), 0, sin(a)) * 7.6
			for layer in range(2):
				box(st, Vector3(1.1, 0.4, 0.6), p + Vector3(0, layer * 0.4, 0), -a + PI * 0.5, Color("8a7a58").lerp(Color("6f6246"), rng.randf()))
	# Watchtower.
	var tower := slot(2, 7.8)
	for dx in [-0.9, 0.9]:
		for dz in [-0.9, 0.9]:
			box(st, Vector3(0.18, 5.0, 0.18), tower + Vector3(dx, 0, dz), 0.0, Color("5a4532"))
	box(st, Vector3(2.4, 1.2, 2.4), tower + Vector3(0, 5.0, 0), 0.0, Color("6a5440"))
	box(st, Vector3(2.8, 0.15, 2.8), tower + Vector3(0, 6.3, 0), 0.0, Color("4a3a2a"))
	fence(st, Color("5d6264"), 1.8)

# ---------------------------------------------------------------- landmarks

# What makes a special district recognisable from the air.
func landmarks(key: String, st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	match key:
		"market":
			# Striped stall awnings around the square.
			var awnings := [Color("9c3b30"), Color("c9a24a"), Color("3e6a8a"), Color("5f7a34")]
			for k in range(6):
				var p := slot(k, 6.6)
				var yaw := deg_to_rad(-(30.0 + 60.0 * k))
				for dx in [-1.0, 1.0]:
					for dz in [-0.7, 0.7]:
						box(st, Vector3(0.1, 2.2, 0.1), p + Basis(Vector3.UP, yaw) * Vector3(dx, 0, dz), 0.0, Color("4a3a2a"))
				box(st, Vector3(2.4, 0.12, 1.8), p + Vector3(0, 2.2, 0), yaw, awnings[k % awnings.size()])
				box(st, Vector3(2.0, 0.8, 0.9), p, yaw, Color("7b5f3e"))
		"intelAgency":
			# Radar dishes and an antenna mast behind a security fence.
			for k in [1, 4]:
				var p := slot(k, 7.2)
				cylinder(st, 0.25, 2.4, p, Color("8e9396"), 8)
				var dish := CylinderMesh.new()
				dish.top_radius = 1.7
				dish.bottom_radius = 0.3
				dish.height = 0.7
				dish.radial_segments = 16
				dish.rings = 1
				shape(st, dish, Transform3D(Basis(Vector3.RIGHT, -0.8).rotated(Vector3.UP, rng.randf() * TAU), p + Vector3(0, 2.9, 0)), Color("dfe2e0"))
			var mast := slot(3, 7.6)
			cylinder(st, 0.18, 12.0, mast, Color("b0b3b0"), 6)
			for h in [4.0, 7.0, 10.0]:
				box(st, Vector3(1.6, 0.08, 0.08), mast + Vector3(0, h, 0), 0.0, Color("b0b3b0"))
			cylinder(st, 0.22, 0.3, mast + Vector3(0, 12.0, 0), Color("c83a2e"), 8)
			fence(st, Color("5d6264"), 2.0)
		"port":
			# Two gantry cranes and a stack of bollards on the quay.
			for k in [0, 3]:
				var p := slot(k, 6.8)
				var yaw := deg_to_rad(-(30.0 + 60.0 * k))
				for side in [-1.2, 1.2]:
					box(st, Vector3(0.35, 11.0, 0.35), p + Basis(Vector3.UP, yaw) * Vector3(side, 0, 0), yaw, Color("c28a2a"))
				box(st, Vector3(3.2, 0.6, 0.6), p + Vector3(0, 11.0, 0), yaw, Color("c28a2a"))
				box(st, Vector3(0.5, 0.5, 9.0), p + Vector3(0, 11.3, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 2.5), yaw, Color("c28a2a"))
				box(st, Vector3(0.9, 1.0, 1.0), p + Vector3(0, 9.6, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 5.0), yaw, Color("3b3f40"))
		"missileSilo":
			# Armoured launch hatches, one open with a missile nose showing.
			for i in range(2):
				var p := slot(2 + i * 3, 6.6)
				cylinder(st, 2.0, 0.5, p, Color("5c605d"), 20)
				cylinder(st, 1.5, 0.12, p + Vector3(0, 0.5, 0), Color("2e3230"), 20)
				if i == 0:
					cylinder(st, 0.55, 1.6, p + Vector3(0, 0.3, 0), Color("d8dde2"), 12)
					var nose := CylinderMesh.new()
					nose.top_radius = 0.02
					nose.bottom_radius = 0.55
					nose.height = 1.1
					nose.radial_segments = 12
					nose.rings = 1
					shape(st, nose, Transform3D(Basis(), p + Vector3(0, 2.45, 0)), Color("c83a2e"))
				else:
					box(st, Vector3(3.2, 0.25, 1.6), p + Vector3(1.4, 0.5, 0), 0.0, Color("4b4f4c"))  # hatch door, slid open
			for k in [0, 1]:
				var p := slot(k, 8.2)
				box(st, Vector3(3.0, 1.2, 0.5), p, deg_to_rad(-(30.0 + 60.0 * k)) + PI * 0.5, Color("e2c23a"))  # hazard barrier
		"ammoDepot":
			# Earth-covered magazines with blast doors.
			for k in [0, 2, 4]:
				var p := slot(k, 7.0)
				var yaw := deg_to_rad(-(30.0 + 60.0 * k)) + PI * 0.5
				box(st, Vector3(4.2, 1.8, 3.2), p, yaw, Color("5b6b3a"))
				box(st, Vector3(1.6, 1.4, 0.2), p + Basis(Vector3.UP, yaw) * Vector3(0, 0, 1.65), yaw, Color("3b3f40"))
