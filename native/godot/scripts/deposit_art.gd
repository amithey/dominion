extends RefCounted
## Natural resources on the map, built from code and readable at a glance.
##
## Every deposit is a site about ten metres across on a patch of ground of its
## own colour, so it shows from strategy distance, with a small resource icon
## floating over it (the interface's own icon, on a dark disc) as a 4X map
## marks its resources:
##   oil       a black glossy pool and a pumpjack that nods
##   iron      rust-red boulders on reddish earth
##   gold      grey granite shot with gold veins
##   silicon   clusters of blue quartz on grey sand
##   uranium   dark rock with glowing green crystals
##   diamond   a dark kimberlite pit with sparkling stones
##   seaOil    an offshore platform with a burning flare, and a sheen on the water
##   fish      a school circling just under the surface
## Each type's mesh is built once and shared; a site is two or three draws.

const UI := preload("res://scripts/ui_theme.gd")
const ICON_PX := 0.05   ## marker size with fixed_size (a fraction of the view height, about 26 px at 800)
const ICON := {"oil": "oil", "seaOil": "oil", "iron": "iron", "gold": "money", "diamond": "money",
	"silicon": "silicon", "uranium": "uranium", "fish": "food"}

var world: Node
var _meshes := {}
var _materials := {}
var _disc: Texture2D
var _site := Vector3.ZERO     # the site being built: rocks sit on its real ground
var _turn := Basis()
var _conform := false

func _init(world_node: Node) -> void:
	world = world_node

## The node for one deposit of `type` at `at` (on the ground, or on the sea).
func build(type: String, at: Vector3, spin: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = spin
	var water: bool = type in ["seaOil", "fish"]
	if not water:
		root.add_child(_patch(at, spin, type))
	# Land sites are built for their own spot, so every rock stands on the
	# slope beneath it instead of sinking into a hillside.
	_site = at
	_turn = Basis(Vector3.UP, spin)
	_conform = not water
	var body := MeshInstance3D.new()
	body.mesh = _mesh_for(type)
	root.add_child(body)
	match type:
		"oil":
			root.add_child(_pumpjack())
		"seaOil":
			root.add_child(_flare())
		"fish":
			root.add_child(_school())
	root.add_child(_icon(type, 9.0 if not water else 11.0))
	return root

# ---------------------------------------------------------------- materials

func _mat(key: String, make: Callable) -> Material:
	if not _materials.has(key):
		_materials[key] = make.call()
	return _materials[key]

func _painted(roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true  # the colours are written as sRGB; read as linear they wash out
	m.roughness = roughness
	m.metallic = metallic
	return m

## Real rock: the photographed rock of the mountains (with its relief),
## projected from every side so it never stretches, tinted per boulder.
func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/terrain/rock_color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/terrain/rock_normal.jpg")
	m.normal_scale = 1.4
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.45
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = Color(2.1, 2.1, 2.1)  # the photo is dark; the tint sets the colour
	m.roughness = 0.88
	return m

func _crystal(colour: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.3
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = glow
	return m

# ---------------------------------------------------------------- building blocks

## A faceted boulder: a coarse sphere with every vertex pushed in or out.
func _rock(st: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, size: Vector3, colour: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# One displacement per position, so seams stay closed.
	var push := {}
	for v in verts:
		var k := Vector3i(roundi(v.x * 100), roundi(v.y * 100), roundi(v.z * 100))
		if not push.has(k):
			push[k] = rng.randf_range(0.78, 1.15)
	var shade := rng.randf_range(0.8, 1.1)
	var base := _ground(at)
	for i in index:
		var v: Vector3 = verts[i]
		var k := Vector3i(roundi(v.x * 100), roundi(v.y * 100), roundi(v.z * 100))
		var p: Vector3 = v * 2.0 * push[k] * size  # the primitive sphere is 0.5 m in radius
		p.y = maxf(p.y, -size.y * 0.3)  # sunk a little into the ground, flat underneath
		st.set_color(Color(colour.r * shade, colour.g * shade, colour.b * shade))
		st.add_vertex(at + p + Vector3(0, base, 0))

## Any primitive mesh, placed and coloured, into the surface being built.
func _shape(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, colour: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in index:
		st.set_color(colour)
		st.add_vertex(xf * verts[i])

## A crystal: a six-sided prism with a pointed tip.
func _prism(st: SurfaceTool, at: Vector3, height: float, radius: float, tilt: Basis, colour: Color) -> void:
	at.y += _ground(at) - 0.15
	var shaft := CylinderMesh.new()
	shaft.radial_segments = 6
	shaft.rings = 1
	shaft.top_radius = radius
	shaft.bottom_radius = radius
	shaft.height = height
	_shape(st, shaft, Transform3D(tilt, at + tilt * Vector3(0, height * 0.5, 0)), colour)
	var tip := CylinderMesh.new()
	tip.radial_segments = 6
	tip.rings = 1
	tip.top_radius = 0.0
	tip.bottom_radius = radius
	tip.height = radius * 1.8
	_shape(st, tip, Transform3D(tilt, at + tilt * Vector3(0, height + radius * 0.9, 0)), colour)

func _commit(st: SurfaceTool, material: Material, into: ArrayMesh = null) -> ArrayMesh:
	st.generate_normals()
	var mesh := st.commit(into)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # faceted: hard edges read as rock
	return st

# ---------------------------------------------------------------- the sites

## Height of the ground under a point of the site (site space), relative to its centre.
func _ground(local: Vector3) -> float:
	if not _conform:
		return 0.0
	var wp: Vector3 = _site + _turn * local
	return world.height_at(wp.x, wp.z) - _site.y

func _mesh_for(type: String) -> ArrayMesh:
	if not _conform and _meshes.has(type):
		return _meshes[type]
	var rng := RandomNumberGenerator.new()
	rng.seed = type.hash() + (int(_site.x * 7.0 + _site.z * 13.0) if _conform else 0)
	var mesh: ArrayMesh = null
	match type:
		"oil":
			var st := _begin()
			for i in range(4):
				var a := rng.randf() * TAU
				_rock(st, rng, Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.5, 4.6), Vector3.ONE * rng.randf_range(0.5, 0.9), Color("a39a90"))
			mesh = _commit(st, _mat("rock", func(): return _stone()))
		"iron":
			var st := _begin()
			for i in range(12):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, 4.6)
				var s := rng.randf_range(0.9, 2.3)
				_rock(st, rng, Vector3(cos(a) * r, 0, sin(a) * r), Vector3(s, s * rng.randf_range(0.6, 0.9), s * rng.randf_range(0.8, 1.2)), Color("e08a5a").lerp(Color("b5643c"), rng.randf()))
			mesh = _commit(st, _mat("rock", func(): return _stone()))
		"gold":
			var st := _begin()
			for i in range(9):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, 4.4)
				var s := rng.randf_range(1.0, 2.4)
				_rock(st, rng, Vector3(cos(a) * r, 0, sin(a) * r), Vector3(s, s * 0.8, s), Color("e6e0d4").lerp(Color("c9bfae"), rng.randf()))
			mesh = _commit(st, _mat("rock", func(): return _stone()))
			var ore := _begin()
			for i in range(22):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.3, 4.6)
				var s := rng.randf_range(0.22, 0.55)
				_rock(ore, rng, Vector3(cos(a) * r, rng.randf_range(0.2, 1.2), sin(a) * r), Vector3(s, s * 0.7, s * 1.4), Color("e0b23c"))
			mesh = _commit(ore, _mat("gold", func(): return _painted(0.28, 1.0)), mesh)
		"silicon", "uranium", "diamond":
			var base_colour: Color = {"silicon": Color("d8d2c6"), "uranium": Color("8c9a80"), "diamond": Color("8b93a6")}[type]
			var st := _begin()
			for i in range(8):
				var a := rng.randf() * TAU
				var r := rng.randf_range(1.0, 4.8)
				var s := rng.randf_range(0.7, 1.6)
				_rock(st, rng, Vector3(cos(a) * r, 0, sin(a) * r), Vector3(s, s * 0.7, s), base_colour.lerp(Color.BLACK, rng.randf() * 0.3))
			mesh = _commit(st, _mat("rock", func(): return _stone()))
			var gem := _begin()
			var clusters := 7 if type != "diamond" else 9
			for c in range(clusters):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, 3.2)
				var centre := Vector3(cos(a) * r, 0, sin(a) * r)
				for k in range(rng.randi_range(3, 5)):
					var tilt := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
					var h := rng.randf_range(0.8, 2.2) * (0.6 if type == "diamond" else 1.0)
					_prism(gem, centre + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), h, rng.randf_range(0.14, 0.3), tilt, Color.WHITE)
			# Deep, saturated colours: pale crystals used to wash out to white.
			var gem_mat: Material = {"silicon": _mat("silicon", func(): return _crystal(Color("3f8fd0"), 0.25)),
				"uranium": _mat("uranium", func(): return _crystal(Color("55e03a"), 1.6)),
				"diamond": _mat("diamond", func(): return _crystal(Color("b8e4ff"), 0.45))}[type]
			mesh = _commit(gem, gem_mat, mesh)
		"seaOil":
			var st := _begin()
			var steel := Color("5d6166")
			for leg in [Vector3(-2.6, 0, -2.6), Vector3(2.6, 0, -2.6), Vector3(-2.6, 0, 2.6), Vector3(2.6, 0, 2.6)]:
				var pile := CylinderMesh.new()
				pile.top_radius = 0.35
				pile.bottom_radius = 0.45
				pile.height = 8.0
				pile.radial_segments = 8
				_shape(st, pile, Transform3D(Basis(), leg + Vector3(0, 0.0, 0)), steel)
			var deck := BoxMesh.new()
			deck.size = Vector3(7.5, 0.8, 7.5)
			_shape(st, deck, Transform3D(Basis(), Vector3(0, 4.2, 0)), Color("8c8f86"))
			var house := BoxMesh.new()
			house.size = Vector3(3.0, 2.2, 2.6)
			_shape(st, house, Transform3D(Basis(), Vector3(-1.8, 5.7, 1.6)), Color("d2c7a4"))
			var derrick := CylinderMesh.new()
			derrick.top_radius = 0.25
			derrick.bottom_radius = 1.3
			derrick.height = 9.0
			derrick.radial_segments = 4
			_shape(st, derrick, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(1.6, 9.1, -1.2)), Color("c96a2b"))
			var boom := BoxMesh.new()
			boom.size = Vector3(0.3, 0.3, 5.0)
			_shape(st, boom, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(-2.5, 6.0, -4.2)), steel)
			mesh = _commit(st, _mat("steel", func(): return _painted(0.6, 0.35)))
			var sheen := _begin()
			var disc := CylinderMesh.new()
			disc.top_radius = 6.0
			disc.bottom_radius = 6.0
			disc.height = 0.02
			disc.radial_segments = 24
			_shape(sheen, disc, Transform3D(Basis(), Vector3(0, 0.06, 0)), Color(0.08, 0.08, 0.1, 0.28))
			mesh = _commit(sheen, _mat("sheen", func():
				var m := _painted(0.03)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				return m), mesh)
		"fish":
			mesh = ArrayMesh.new()  # the shoal itself is drawn by _school()
	_meshes[type] = mesh
	return mesh

## The ground of the site: an irregular disc of the deposit's own earth,
## laid on the terrain so it reads from far away.
func _patch(at: Vector3, spin: float, type: String) -> MeshInstance3D:
	# Tints over the soil texture (which is mid-brown), so lighter than the look.
	var colour: Color = {"oil": Color("15130f"), "iron": Color("d0805a"), "gold": Color("e8d8a8"),
		"silicon": Color("e4e0d4"), "uranium": Color("8d9e78"), "diamond": Color("6e7688")}.get(type, Color("999999"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 131.0 + at.z * 17.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Concentric rings that follow the ground at every vertex: a flat fan
	# lets a bumpy slope poke through and hide most of the patch.
	var n := 28
	var rings := 5
	var radius := 6.4 if type != "oil" else 4.6
	var edge_r: Array[float] = []
	for i in range(n):
		edge_r.append(radius * rng.randf_range(0.78, 1.12))
	var turn := Basis(Vector3.UP, spin)
	var centre_y: float = world.height_at(at.x, at.z)
	var point := func(i: int, ring: int) -> Vector3:
		var a := TAU * (i % n) / n
		var f := float(ring) / rings
		var p := Vector3(cos(a), 0, sin(a)) * edge_r[i % n] * f
		var wp: Vector3 = at + turn * p
		# Lifted a little more on steep ground, where the drawn terrain and the
		# height function part by more than on the flat.
		var lift: float = 0.14 + (1.0 - world.normal_at(wp.x, wp.z).y) * 2.0
		return Vector3(p.x, world.height_at(wp.x, wp.z) - centre_y + lift, p.z)
	var tint := func(ring: int) -> Color:
		var f := float(ring) / rings
		return Color(colour, 0.95 if type == "oil" and f < 0.99 else clampf((1.0 - f) * 2.2, 0.0, 0.92))
	for ring in range(rings):
		for i in range(n):
			var a0: Vector3 = point.call(i, ring)
			var a1: Vector3 = point.call(i + 1, ring)
			var b0: Vector3 = point.call(i, ring + 1)
			var b1: Vector3 = point.call(i + 1, ring + 1)
			var ca: Color = tint.call(ring)
			var cb: Color = tint.call(ring + 1)
			for v in [[a0, ca], [b0, cb], [b1, cb], [a0, ca], [b1, cb], [a1, ca]]:
				st.set_color(v[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	var mesh := st.commit()
	var patch := MeshInstance3D.new()
	patch.mesh = mesh
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.material_override = _mat("patch_oil" if type == "oil" else "patch", func():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.04 if type == "oil" else 0.95
		m.metallic_specular = 0.9 if type == "oil" else 0.3
		if type != "oil":
			# Real soil under the tint, so the site reads as disturbed ground, not paint.
			m.albedo_texture = load("res://assets/terrain/dirt_color.jpg")
			m.normal_enabled = true
			m.normal_texture = load("res://assets/terrain/dirt_normal.jpg")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.3
		return m)
	return patch

## A pumpjack: base, A-frame and a walking beam that nods.
func _pumpjack() -> Node3D:
	var rig := Node3D.new()
	var paint := _mat("pump_paint", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("d99a2b")
		m.roughness = 0.55
		return m)
	var dark := _mat("pump_dark", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("2f3134")
		m.roughness = 0.6
		m.metallic = 0.4
		return m)
	var parts := [[BoxMesh.new(), Vector3(4.2, 0.35, 1.2), Vector3(0, 0.18, 0), Basis(), dark],
		[BoxMesh.new(), Vector3(0.22, 3.0, 0.22), Vector3(0.4, 1.7, 0.45), Basis(Vector3.BACK, 0.18), paint],
		[BoxMesh.new(), Vector3(0.22, 3.0, 0.22), Vector3(0.4, 1.7, -0.45), Basis(Vector3.BACK, 0.18), paint],
		[BoxMesh.new(), Vector3(0.22, 3.0, 0.22), Vector3(-0.3, 1.7, 0.45), Basis(Vector3.BACK, -0.18), paint],
		[BoxMesh.new(), Vector3(0.22, 3.0, 0.22), Vector3(-0.3, 1.7, -0.45), Basis(Vector3.BACK, -0.18), paint],
		[BoxMesh.new(), Vector3(1.0, 0.7, 0.9), Vector3(-1.7, 0.7, 0), Basis(), dark]]
	for p in parts:
		var mi := MeshInstance3D.new()
		p[0].size = p[1]
		mi.mesh = p[0]
		mi.position = p[2]
		mi.basis = p[3]
		mi.material_override = p[4]
		rig.add_child(mi)
	var beam := Node3D.new()
	beam.position = Vector3(0.05, 3.2, 0)
	rig.add_child(beam)
	for p in [[Vector3(4.4, 0.32, 0.3), Vector3(0.3, 0, 0), paint], [Vector3(0.35, 1.3, 0.5), Vector3(2.5, -0.45, 0), dark], [Vector3(0.6, 0.6, 0.6), Vector3(-1.9, 0, 0), dark]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = p[0]
		mi.mesh = box
		mi.position = p[1]
		mi.material_override = p[2]
		beam.add_child(mi)
	# Nods for ever, each rig on its own beat.
	var tween := beam.create_tween().set_loops()
	tween.tween_property(beam, "rotation:z", 0.28, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(beam, "rotation:z", -0.28, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.custom_step(randf() * 3.2)
	# A storage tank beside the rig and the flowline between them.
	var tank := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 1.2
	drum.bottom_radius = 1.2
	drum.height = 2.6
	drum.radial_segments = 16
	tank.mesh = drum
	tank.position = Vector3(-3.4, 1.3, -2.6)
	tank.material_override = _mat("tank", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("d9d4c7")
		m.roughness = 0.5
		m.metallic = 0.3
		return m)
	rig.add_child(tank)
	var pipe := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.09
	tube.bottom_radius = 0.09
	tube.height = 4.2
	pipe.mesh = tube
	pipe.material_override = dark
	pipe.position = Vector3(-1.9, 0.25, -1.3)
	pipe.basis = Basis(Vector3.UP, atan2(-1.9, -2.6) + PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
	rig.add_child(pipe)
	rig.position = Vector3(-0.6, 0, 1.4)
	return rig

## The gas flare on an offshore platform: a flickering flame and its light.
func _flare() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(-2.5, 7.4, -6.3)
	var flame := MeshInstance3D.new()
	var q := SphereMesh.new()
	q.radius = 0.35
	q.height = 1.1
	flame.mesh = q
	flame.material_override = _mat("flame", func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.62, 0.2)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.55, 0.15)
		m.emission_energy_multiplier = 3.0
		return m)
	root.add_child(flame)
	var tween := flame.create_tween().set_loops()
	tween.tween_property(flame, "scale", Vector3(0.8, 1.25, 0.8), 0.18)
	tween.tween_property(flame, "scale", Vector3(1.1, 0.85, 1.1), 0.23)
	return root

## A shoal: dark backs breaking the surface as they circle, and rings
## spreading on the water where they rise.
func _school() -> Node3D:
	var root := Node3D.new()
	var body := SphereMesh.new()
	body.radius = 0.3
	body.height = 0.6
	body.radial_segments = 6
	body.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = body
	mm.instance_count = 14
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(14):
		var a := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(2.5, 5.0)
		var pos := Vector3(cos(a) * r, rng.randf_range(0.0, 0.08), sin(a) * r)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a).scaled(Vector3(0.9, 0.4, 2.6)), pos))
	var fish := MultiMeshInstance3D.new()
	fish.multimesh = mm
	fish.material_override = _mat("fish", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("24343d")
		m.roughness = 0.3
		m.metallic = 0.6
		return m)
	fish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fish)
	var swim := root.create_tween().set_loops()
	swim.tween_property(root, "rotation:y", TAU, 14.0).from(0.0)
	for k in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 3
		ring.mesh = torus
		ring.position = Vector3(cos(k * 2.1) * 3.0, 0.08, sin(k * 2.1) * 3.0)
		ring.scale = Vector3(1.0, 0.05, 1.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.55)
		ring.material_override = mat
		root.add_child(ring)
		var spread := ring.create_tween().set_loops()
		spread.tween_interval(k * 0.9)
		spread.tween_property(ring, "scale", Vector3(3.0, 0.05, 3.0), 2.7).from(Vector3(0.5, 0.05, 0.5))
		spread.parallel().tween_property(mat, "albedo_color:a", 0.0, 2.7).from(0.55)
	return root

## The resource icon over the site, on a dark disc so it reads on any ground.
func _icon(type: String, height: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0, height, 0)
	var back := Sprite3D.new()
	back.texture = _disc_texture()
	back.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# The same size on screen at any zoom, as a map marker should be.
	back.fixed_size = true
	back.pixel_size = ICON_PX / 96.0
	back.no_depth_test = true
	back.render_priority = 1
	back.shaded = false
	root.add_child(back)
	var tex: Texture2D = UI.icon(ICON.get(type, "build"))
	if tex != null:
		var icon := Sprite3D.new()
		icon.texture = tex
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.fixed_size = true
		icon.pixel_size = ICON_PX * 0.62 / maxf(tex.get_width(), 1.0)
		icon.no_depth_test = true
		icon.render_priority = 2
		icon.shaded = false
		root.add_child(icon)
	return root

func _disc_texture() -> Texture2D:
	if _disc != null:
		return _disc
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in range(n):
		for x in range(n):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (n * 0.5)
			var col := Color(0, 0, 0, 0)
			if d < 0.84:
				col = Color("0d1a26").lerp(Color("1d3148"), clampf(1.0 - (y / float(n)), 0.0, 1.0) * 0.6)
				col.a = 0.9
			elif d < 0.97:
				col = Color("c9a55a")
				col.a = clampf((0.97 - d) / 0.04, 0.0, 1.0)
			img.set_pixel(x, y, col)
	_disc = ImageTexture.create_from_image(img)
	return _disc

## --capture-deposits: one close view of each kind of resource
## (build/deposit-<type>.png) and one from strategy height.
static func capture(w: Node) -> void:
	for i in range(30):
		await w.get_tree().process_frame
	var seen := {}
	for d in w.deposits:
		if seen.has(d.type):
			continue
		seen[d.type] = true
		w.cam_focus = d.pos
		w.cam_dist = 38.0
		w.cam_dist_target = 38.0
		w.cam_pitch = 0.62
		for f in range(25):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/deposit-%s.png" % d.type)
	var d0: Dictionary = w.deposits[0]
	w.cam_focus = d0.pos
	w.cam_dist = 150.0
	w.cam_dist_target = 150.0
	w.cam_pitch = 0.9
	for f in range(30):
		await w.get_tree().process_frame
	await RenderingServer.frame_post_draw
	w.get_viewport().get_texture().get_image().save_png("res://build/deposit-overview.png")
	w.get_tree().quit()
