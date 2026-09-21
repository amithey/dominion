extends RefCounted
## Warships and aircraft, modelled from primitives (the browser game builds
## them procedurally too). Hull plates and fittings merge into one
## vertex-coloured mesh; moving parts (rotors, radar, gun turret) stay separate
## nodes. Models face +Z like every other unit. Naval grey or olive airframes,
## with the owner's colour on a funnel band, tail fin or roundel.

const NAVAL := ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
const AIR := ["helicopter", "gunship", "jet", "bomber", "drone"]

var world: Node
var material: StandardMaterial3D
var _wake_process: ParticleProcessMaterial
var _wake_mesh: QuadMesh

func setup(world_node: Node) -> void:
	world = world_node
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.62
	material.metallic = 0.25

## Returns {root, rotor, radar, turret}; unused parts are null.
func build(key: String, owner: int) -> Dictionary:
	var team: Color = Color(world.map.nations[owner].color) if owner < world.map.nations.size() else Color.WHITE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := {"root": Node3D.new(), "rotor": null, "radar": null, "turret": null}
	match key:
		"destroyer":
			ship(st, parts, 15.0, 2.8, team, 2, true)
		"corvette":
			ship(st, parts, 10.5, 2.2, team, 1, true)
		"gunboat":
			ship(st, parts, 7.5, 1.8, team, 1, false)
		"submarine", "nuclearSub":
			submarine(st, 11.0 if key == "submarine" else 14.0, team)
		"helicopter", "gunship":
			helicopter(st, parts, key == "gunship", team)
		"bomber":
			plane(st, 9.5, 11.5, team, true)
		"drone":
			plane(st, 3.2, 4.6, team, false)
		_:
			plane(st, 8.5, 7.0, team, false)
	var body := MeshInstance3D.new()
	body.mesh = st.commit()
	body.material_override = material
	parts.root.add_child(body)
	return parts

# ---------------------------------------------------------------- primitives

func shape(st: SurfaceTool, mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(color)
	for i in indices:
		st.set_normal((xf.basis * normals[i]).normalized())
		st.add_vertex(xf * verts[i])

func box(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, basis := Basis()) -> void:
	var m := BoxMesh.new()
	m.size = size
	shape(st, m, Transform3D(basis, at), color)

# A cylinder lying along Z.
func tube(st: SurfaceTool, r_back: float, r_front: float, length: float, at: Vector3, color: Color, sides := 12) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_front
	m.bottom_radius = r_back
	m.height = length
	m.radial_segments = sides
	m.rings = 1
	shape(st, m, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at), color)

func wedge(st: SurfaceTool, size: Vector3, at: Vector3, color: Color, basis := Basis()) -> void:
	var m := PrismMesh.new()
	m.size = size
	shape(st, m, Transform3D(basis, at), color)

# ---------------------------------------------------------------- ships

func ship(st: SurfaceTool, parts: Dictionary, length: float, beam: float, team: Color, turrets: int, missiles: bool) -> void:
	var hull := Color("5c666c")
	var deck := Color("4a5054")
	var dark := Color("2c3134")
	var hull_len := length * 0.78
	# Hull below the deck line, a pointed bow and a flat transom.
	box(st, Vector3(beam, 1.4, hull_len), Vector3(0, 0.1, -length * 0.08), hull)
	wedge(st, Vector3(beam, length * 0.3, 1.4), Vector3(0, 0.1, hull_len * 0.5 - length * 0.08 + length * 0.1), hull, Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.0))
	box(st, Vector3(beam * 0.98, 0.08, hull_len), Vector3(0, 0.84, -length * 0.08), deck)
	box(st, Vector3(beam * 1.02, 0.18, hull_len * 1.02), Vector3(0, -0.45, -length * 0.08), Color("3b2b28"))  # boot topping
	# Superstructure, funnel with the nation's band, mast.
	var bridge_z := length * 0.02
	box(st, Vector3(beam * 0.7, 1.4, length * 0.2), Vector3(0, 1.55, bridge_z), hull.lightened(0.12))
	box(st, Vector3(beam * 0.62, 0.5, length * 0.08), Vector3(0, 2.5, bridge_z + length * 0.05), hull.lightened(0.18))
	box(st, Vector3(beam * 0.58, 0.14, 0.05), Vector3(0, 2.55, bridge_z + length * 0.09 + 0.02), Color("223038"))  # bridge windows
	var funnel_z := -length * 0.14
	box(st, Vector3(beam * 0.35, 1.9, beam * 0.55), Vector3(0, 1.8, funnel_z), hull.darkened(0.1))
	box(st, Vector3(beam * 0.36, 0.3, beam * 0.56), Vector3(0, 2.5, funnel_z), team.darkened(0.15))
	box(st, Vector3(0.12, 3.4, 0.12), Vector3(0, 3.6, bridge_z - length * 0.02), dark)
	box(st, Vector3(1.4, 0.08, 0.08), Vector3(0, 4.6, bridge_z - length * 0.02), dark)
	var radar := Node3D.new()
	radar.position = Vector3(0, 5.0, bridge_z - length * 0.02)
	var radar_mesh := MeshInstance3D.new()
	var radar_box := BoxMesh.new()
	radar_box.size = Vector3(1.3, 0.35, 0.08)
	radar_mesh.mesh = radar_box
	radar_mesh.material_override = world.matte(Color("8b9296"), 0.5, 0.4)
	radar.add_child(radar_mesh)
	parts.root.add_child(radar)
	parts.radar = radar
	# Main gun turret forward (rotating), a second one aft on destroyers.
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.0, length * 0.26)
	var t_st := SurfaceTool.new()
	t_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(t_st, Vector3(beam * 0.5, 0.55, beam * 0.6), Vector3(0, 0.25, 0), hull.lightened(0.08))
	tube(t_st, 0.09, 0.07, 2.2, Vector3(0, 0.35, 1.2), dark, 8)
	var t_mesh := MeshInstance3D.new()
	t_mesh.mesh = t_st.commit()
	t_mesh.material_override = material
	turret.add_child(t_mesh)
	parts.root.add_child(turret)
	parts.turret = turret
	if turrets > 1:
		box(st, Vector3(beam * 0.5, 0.55, beam * 0.6), Vector3(0, 1.25, -length * 0.36), hull.lightened(0.08))
		tube(st, 0.09, 0.07, 2.0, Vector3(0, 1.35, -length * 0.36 - 1.1), dark, 8)
	if missiles:
		for i in range(4):
			box(st, Vector3(0.35, 0.3, 0.35), Vector3(-0.4 + (i % 2) * 0.8, 1.0, length * 0.13 - int(i / 2) * 0.45), dark)
	# Railings as a thin dark line along the deck edge.
	for side in [-1, 1]:
		box(st, Vector3(0.04, 0.3, hull_len * 0.9), Vector3(side * beam * 0.48, 1.0, -length * 0.08), dark)

func submarine(st: SurfaceTool, length: float, team: Color) -> void:
	var hull := Color("2e3336")
	tube(st, 1.0, 1.0, length * 0.8, Vector3(0, 0, 0), hull, 16)
	var nose := SphereMesh.new()
	nose.radius = 1.0
	nose.height = 2.0
	shape(st, nose, Transform3D(Basis().scaled(Vector3(1, 1, 1.6)), Vector3(0, 0, length * 0.4)), hull)
	tube(st, 1.0, 0.2, length * 0.2, Vector3(0, 0, -length * 0.5), hull, 16)
	box(st, Vector3(0.7, 1.9, 2.2), Vector3(0, 1.4, length * 0.12), hull)
	box(st, Vector3(0.72, 0.25, 2.22), Vector3(0, 2.1, length * 0.12), team.darkened(0.3))
	box(st, Vector3(3.2, 0.1, 0.8), Vector3(0, 1.7, length * 0.12), hull)
	box(st, Vector3(2.8, 0.1, 0.9), Vector3(0, 0, -length * 0.52), hull)
	box(st, Vector3(0.1, 1.8, 0.9), Vector3(0, 0, -length * 0.52), hull)

## Foam churned up behind a moving ship.
func wake(length: float) -> GPUParticles3D:
	if _wake_process == null:
		_wake_process = ParticleProcessMaterial.new()
		_wake_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_wake_process.emission_box_extents = Vector3(0.9, 0.05, 0.4)
		_wake_process.direction = Vector3(0, 0.2, -1)
		_wake_process.spread = 25
		_wake_process.initial_velocity_min = 0.3
		_wake_process.initial_velocity_max = 1.0
		_wake_process.gravity = Vector3.ZERO
		_wake_process.scale_min = 1.0
		_wake_process.scale_max = 1.8
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.6))
		grow.add_point(Vector2(1, 1.0))
		var grow_tex := CurveTexture.new()
		grow_tex.curve = grow
		_wake_process.scale_curve = grow_tex
		var fade := Gradient.new()
		fade.set_color(0, Color(0.95, 0.97, 0.97, 0.7))
		fade.set_color(1, Color(0.9, 0.95, 0.95, 0.0))
		var fade_tex := GradientTexture1D.new()
		fade_tex.gradient = fade
		_wake_process.color_ramp = fade_tex
		var puff := Gradient.new()
		puff.set_color(0, Color(1, 1, 1, 1))
		puff.set_color(1, Color(1, 1, 1, 0))
		var puff_tex := GradientTexture2D.new()
		puff_tex.gradient = puff
		puff_tex.fill = GradientTexture2D.FILL_RADIAL
		puff_tex.fill_from = Vector2(0.5, 0.5)
		puff_tex.fill_to = Vector2(0.5, 0.0)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = puff_tex
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_wake_mesh = QuadMesh.new()
		_wake_mesh.size = Vector2(2.2, 2.2)
		_wake_mesh.material = m
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 3.5
	p.local_coords = false
	p.emitting = false
	p.process_material = _wake_process
	p.draw_pass_1 = _wake_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0.1, -length * 0.45)
	return p

# ---------------------------------------------------------------- aircraft

func helicopter(st: SurfaceTool, parts: Dictionary, heavy: bool, team: Color) -> void:
	var body := Color("4d5641") if not heavy else Color("3f463a")
	var s := 1.25 if heavy else 1.0
	var cabin := SphereMesh.new()
	cabin.radius = 1.1 * s
	cabin.height = 2.0 * s
	shape(st, cabin, Transform3D(Basis().scaled(Vector3(0.9, 0.85, 1.6)), Vector3(0, 0, 0.3)), body)
	var glass := SphereMesh.new()
	glass.radius = 0.7 * s
	glass.height = 1.1 * s
	shape(st, glass, Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.2)), Vector3(0, 0.25 * s, 1.55 * s)), Color("1f2a30"))
	tube(st, 0.35 * s, 0.14 * s, 4.2 * s, Vector3(0, 0.2 * s, -2.6 * s), body, 8)
	box(st, Vector3(0.08, 1.2 * s, 0.7 * s), Vector3(0, 0.75 * s, -4.6 * s), body)
	box(st, Vector3(0.1, 0.5 * s, 0.6 * s), Vector3(0, 0.95 * s, -4.6 * s), team.darkened(0.2))
	box(st, Vector3(1.7 * s, 0.08, 0.5 * s), Vector3(0, 0.3 * s, -4.3 * s), body)
	for side in [-1, 1]:
		box(st, Vector3(0.08, 0.08, 2.6 * s), Vector3(side * 0.8 * s, -1.05 * s, 0.2), Color("2a2d2b"))
		box(st, Vector3(0.06, 0.5 * s, 0.06), Vector3(side * 0.7 * s, -0.8 * s, 0.8), Color("2a2d2b"))
		if heavy:
			box(st, Vector3(1.2, 0.12, 0.5), Vector3(side * 1.3, 0.0, 0.2), body)
			tube(st, 0.18, 0.18, 1.2, Vector3(side * 1.9, -0.15, 0.25), Color("2a2d2b"), 8)
	box(st, Vector3(0.5, 0.35, 0.8), Vector3(0, 0.95 * s, 0.1), body.darkened(0.15))
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 1.2 * s, 0.1)
	var blades := MeshInstance3D.new()
	var b_st := SurfaceTool.new()
	b_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(4 if heavy else 2):
		box(b_st, Vector3(0.26, 0.04, 5.6 * s), Vector3.ZERO, Color("1c1f1d"), Basis(Vector3.UP, k * PI / (4 if heavy else 2)))
	blades.mesh = b_st.commit()
	blades.material_override = material
	rotor.add_child(blades)
	parts.root.add_child(rotor)
	parts.rotor = rotor

func plane(st: SurfaceTool, length: float, span: float, team: Color, bomber: bool) -> void:
	var body := Color("6c7478") if not bomber else Color("50585c")
	var r := length * 0.07
	tube(st, r, r * 0.9, length * 0.72, Vector3(0, 0, -length * 0.04), body, 12)
	var nose := SphereMesh.new()
	nose.radius = r
	nose.height = r * 2.0
	shape(st, nose, Transform3D(Basis().scaled(Vector3(1, 1, 2.6)), Vector3(0, 0, length * 0.33)), body)
	tube(st, r * 0.85, r * 0.55, length * 0.2, Vector3(0, 0, -length * 0.46), body.darkened(0.2), 10)
	var canopy := SphereMesh.new()
	canopy.radius = r * 0.7
	canopy.height = r * 1.2
	shape(st, canopy, Transform3D(Basis().scaled(Vector3(0.8, 0.8, 2.2)), Vector3(0, r * 0.7, length * 0.24)), Color("1f2a30"))
	# Wings: swept on fighters, straight on the bomber.
	var chord := length * (0.22 if bomber else 0.34)
	for side in [-1, 1]:
		var sweep := Basis(Vector3.UP, side * (0.0 if bomber else -0.42))
		box(st, Vector3(span * 0.5, r * 0.25, chord), Vector3(side * span * 0.25, -r * 0.2, -length * 0.02), body, sweep)
		box(st, Vector3(length * 0.14, r * 0.2, length * 0.1), Vector3(side * length * 0.1, 0, -length * 0.42), body)
		if bomber:
			for e in [0.2, 0.36]:
				tube(st, r * 0.35, r * 0.35, length * 0.14, Vector3(side * span * e, -r * 0.4, length * 0.04), body.darkened(0.15), 8)
		# Roundel in the nation's colour on each wing.
		box(st, Vector3(r * 1.1, r * 0.27, r * 1.1), Vector3(side * span * 0.34, -r * 0.18, -length * 0.06 - (0.0 if bomber else 0.8)), team)
	box(st, Vector3(r * 0.2, length * 0.14, length * 0.12), Vector3(0, length * 0.08, -length * 0.42), body)
	box(st, Vector3(r * 0.22, length * 0.05, length * 0.06), Vector3(0, length * 0.12, -length * 0.44), team.darkened(0.2))
