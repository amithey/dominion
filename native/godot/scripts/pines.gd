extends RefCounted
## Conifers made in code, so the forests are not a single species. A pine is
## a tapering trunk and five irregular tiers of drooping, jagged branches,
## dark blue-green and lighter at the tips; it sways with the same wind shader
## as the birches. The island's higher ground and a share of every grove get
## pines; each tree has its own size, lean and shade (instance colour).

## One pine, about 1 unit tall, standing on the origin.
## `detail` false is the cheap version for far away (fewer, plain boughs, no toothed fringe).
static func mesh(detail := true) -> ArrayMesh:
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
	# Each tier is a rounded, drooping skirt of boughs: a ring part-way down bulges out (so the
	# silhouette is lumpy, not a smooth cone), the outer rim alternates long and short boughs that
	# hang below the tier, and the normals lean outward and up so the light wraps round the crown
	# instead of showing flat facets. Dark inside, lighter at the bough tips.
	var tiers := 7 if detail else 6
	var n := 13 if detail else 9
	for k in range(tiers):
		var f := float(k) / tiers
		var y0 := 0.13 + f * 0.72
		var r := 0.37 * (1.0 - f * 0.8)
		var rise := 0.27 * (1.0 - f * 0.4)
		var tip := Vector3(rng.randf_range(-0.02, 0.02), y0 + rise, rng.randf_range(-0.02, 0.02))
		var mid: Array[Vector3] = []
		var rim: Array[Vector3] = []
		var rim_t: Array[float] = []
		for j in range(n):
			var angle := TAU * j / n + k * 0.45
			var long_bough := 1.0 if j % 2 == 0 else 0.62
			var radius := r * rng.randf_range(0.8, 1.12) * (0.78 + 0.3 * long_bough)
			rim.append(Vector3(cos(angle) * radius, y0 - (0.02 + 0.07 * long_bough) * rng.randf_range(0.7, 1.2), sin(angle) * radius))
			rim_t.append(long_bough)
			var a2 := angle + rng.randf_range(-0.1, 0.1)
			var rm := r * rng.randf_range(0.5, 0.64)
			mid.append(Vector3(cos(a2) * rm, y0 + rise * 0.42 + rng.randf_range(-0.012, 0.012), sin(a2) * rm))
		var dark := Color("203a2a")
		var inner := Color("2f5136")
		for i in range(n):
			var i2 := (i + 1) % n
			var tip_a := Color("4d7a4a").lerp(Color("6d9a5a"), rim_t[i] * rng.randf())
			var tip_b := Color("4d7a4a").lerp(Color("6d9a5a"), rim_t[i2] * rng.randf())
			# The notch between two boughs sits back and up, so the fringe of the tier is toothed, not scalloped.
			var between := (rim[i] + rim[i2]) * 0.5
			var notch := Vector3(between.x * 0.8, between.y + 0.045, between.z * 0.8)
			var notch_col := Color("3a6040")
			var faces := [
				[[tip, dark], [mid[i2], inner], [mid[i], inner]],
				[[mid[i], inner], [notch, notch_col], [rim[i], tip_a]],
				[[mid[i], inner], [mid[i2], inner], [notch, notch_col]],
				[[mid[i2], inner], [rim[i2], tip_b], [notch, notch_col]]]
			if not detail:
				faces = [
					[[tip, dark], [mid[i2], inner], [mid[i], inner]],
					[[mid[i], inner], [mid[i2], inner], [rim[i], tip_a]],
					[[mid[i2], inner], [rim[i2], tip_b], [rim[i], tip_a]]]
			for face in faces:
				for v in face:
					var pos: Vector3 = v[0]
					var out := Vector3(pos.x, 0.0, pos.z)
					var nrm := (out.normalized() * 0.8 + Vector3.UP * 0.6).normalized() if out.length() > 0.001 else Vector3.UP
					crown.set_normal(nrm)
					crown.set_color(v[1])
					crown.set_uv(Vector2(clampf(out.length() / 0.4, 0.0, 1.0), pos.y))
					crown.add_vertex(pos)
			# The underside, in shade.
			var under := Vector3(0, y0 - 0.03, 0)
			for tri in ([[under, rim[i], notch], [under, notch, rim[i2]]] if detail else [[under, rim[i], rim[i2]]]):
				for v in tri:
					crown.set_normal(Vector3.DOWN)
					crown.set_color(Color("1c3a28"))
					crown.set_uv(Vector2(0, v.y))
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
