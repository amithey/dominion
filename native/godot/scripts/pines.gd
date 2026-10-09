extends RefCounted
## Conifers made in code, so the forests are not a single species. A pine is
## a tapering trunk and five irregular tiers of drooping, jagged branches,
## dark blue-green and lighter at the tips; it sways with the same wind shader
## as the birches. The island's higher ground and a share of every grove get
## pines; each tree has its own size, lean and shade (instance colour).

## One pine, about 1 unit tall, standing on the origin.
static func mesh() -> ArrayMesh:
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	for i in range(sides):
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0), 0, sin(a0)) * 0.035
		var b1 := Vector3(cos(a1), 0, sin(a1)) * 0.035
		var t0 := Vector3(cos(a0), 0, sin(a0)) * 0.012 + Vector3(0, 0.8, 0)
		var t1 := Vector3(cos(a1), 0, sin(a1)) * 0.012 + Vector3(0, 0.8, 0)
		for v in [b0, t0, b1, b1, t0, t1]:
			trunk.set_normal(Vector3(v.x, 0, v.z).normalized())
			trunk.set_color(Color("5a4232"))
			trunk.add_vertex(v)
	var crown := SurfaceTool.new()
	crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var tiers := 7
	for k in range(tiers):
		var f := float(k) / tiers
		var y0 := 0.14 + f * 0.7
		var r := 0.34 * (1.0 - f * 0.78)
		var rise := 0.26 * (1.0 - f * 0.4)
		var n := 13
		var tip := Vector3(rng.randf_range(-0.025, 0.025), y0 + rise, rng.randf_range(-0.025, 0.025))
		# Shared, irregular boughs: neighbouring faces meet exactly. The old
		# independently randomised endpoints left cracks between cone slices.
		var rim: Array[Vector3] = []
		for j in range(n):
			var angle := TAU * j / n + k * 0.4
			var radius := r * rng.randf_range(0.68, 1.12)
			rim.append(Vector3(cos(angle) * radius, y0 - rng.randf_range(0.01, 0.075), sin(angle) * radius))
		for i in range(n):
			# A jagged skirt: every other point pushed out and down like a bough.
			var p0 := rim[i]
			var p1 := rim[(i + 1) % n]
			var nrm := (p1 - tip).cross(p0 - tip).normalized()
			var dark := Color("344c36")
			var light := Color("668361").lerp(Color("4f7050"), rng.randf())
			for v in [[tip, dark], [p1, light], [p0, light]]:
				crown.set_normal(nrm.lerp(Vector3.UP, 0.35).normalized())
				crown.set_color(v[1])
				crown.set_uv(Vector2(0, (v[0].y - 0.1)))
				crown.add_vertex(v[0])
			# The underside, in shade.
			var under := Vector3(0, y0 - 0.02, 0)
			for v in [under, p0, p1]:
				crown.set_normal(Vector3.DOWN)
				crown.set_color(Color("152a1e"))
				crown.set_uv(Vector2(0, 0))
				crown.add_vertex(v)
	var mesh := trunk.commit()
	crown.commit(mesh)
	var bark := StandardMaterial3D.new()
	bark.vertex_color_use_as_albedo = true
	bark.vertex_color_is_srgb = true
	bark.roughness = 0.9
	mesh.surface_set_material(0, bark)
	var needles := ShaderMaterial.new()
	needles.shader = load("res://shaders/pine.gdshader")
	mesh.surface_set_material(1, needles)
	return mesh

## Should the tree at (x, z) be a pine? Higher ground mostly pines, lowland
## mostly birch, and groves mixed.
static func is_pine(w: Node, x: float, z: float) -> bool:
	var h: float = w.height_at(x, z) - float(w.map.seaLevel)
	var hash := fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)
	var chance := clampf(0.3 + (h - 3.0) * 0.12, 0.25, 0.85)
	return hash < chance
