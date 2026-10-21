extends RefCounted
## Bushes in code: lumpy clusters of leaf blobs in several greens, placed at the edges of groves and in
## the open meadow, so the ground between the trees is not bare. Drawn with the foliage wind shader's
## cousin (shrub.gdshader); each is felled with the trees when a building needs the ground (site_clearing.gd).

## One shrub, about 1 unit wide, standing on the origin: five overlapping, noisy blobs.
static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var rings := 6
	var segs := 9
	for b in range(5):
		var centre := Vector3(rng.randf_range(-0.28, 0.28), 0.0, rng.randf_range(-0.28, 0.28))
		var radius := rng.randf_range(0.26, 0.4)
		var squash := rng.randf_range(0.65, 0.9)
		centre.y = radius * squash * 0.85
		var shade := rng.randf_range(0.0, 1.0)
		var pts: Array = []
		for i in range(rings + 1):
			var phi := PI * i / rings
			var row: Array = []
			for j in range(segs):
				var theta := TAU * j / segs
				var bump := rng.randf_range(0.82, 1.18)
				var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
				row.append(centre + Vector3(dir.x * radius, dir.y * radius * squash, dir.z * radius) * bump)
			pts.append(row)
		for i in range(rings):
			for j in range(segs):
				var j2 := (j + 1) % segs
				var a: Vector3 = pts[i][j]
				var b2: Vector3 = pts[i + 1][j]
				var c: Vector3 = pts[i + 1][j2]
				var d: Vector3 = pts[i][j2]
				for tri in [[a, b2, c], [a, c, d]]:
					for v in tri:
						var pos: Vector3 = v
						var out := (pos - centre).normalized()
						st.set_normal((out * 0.75 + Vector3.UP * 0.5).normalized())
						var lift := clampf(pos.y / 0.7, 0.0, 1.0)
						st.set_color(Color(shade, lift, 0.0, 1.0))
						st.add_vertex(pos)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/shrub.gdshader")
	mesh.surface_set_material(0, mat)
	return mesh

## Which of the map's trees get a bush beside them: shrub cards (foliage_cards.gd, the atlas of leafy shrubs).
static func build(w: Node) -> void:
	var Cards := preload("res://scripts/foliage_cards.gd")
	var use_cards: bool = ResourceLoader.exists(Cards.ART + "bush_leaves_atlas_2048.png")
	var mesh := mesh() if not use_cards else null
	var spots: Array = []
	for t in w.map.trees:
		var h := fposmod(sin(t.x * 4.7 + t.z * 9.1) * 43758.5453, 1.0)
		if h < 0.45:
			var a := h * TAU * 5.0
			var d := 3.0 + fposmod(h * 31.0, 1.0) * 5.0
			spots.append({"x": t.x + cos(a) * d, "z": t.z + sin(a) * d, "scale": 0.6 + fposmod(h * 17.0, 1.0) * 0.8})
	var keep: Array = []
	for s in spots:
		var ground: float = w.height_at(s.x, s.z)
		if ground > float(w.map.seaLevel) + 1.0:
			keep.append(s)
	var cells := {}
	for s in keep:
		var key := Vector2i(floori(s.x / 96.0), floori(s.z / 96.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(s)
	for key in cells:
		var list: Array = cells[key]
		var node: MultiMeshInstance3D
		if use_cards:
			var card_spots := []
			for s in list:
				var seed_v := fposmod(sin(s.x * 3.3 + s.z * 5.9) * 43758.5453, 1.0)
				card_spots.append({"pos": Vector3(s.x, w.height_at(s.x, s.z) - 0.1, s.z), "scale": 0.7 + float(s.scale) * 0.8, "yaw": fmod(s.x * 12.9898 + s.z * 78.233, TAU), "cell": int(seed_v * 4.0) % 4, "tone": seed_v})
			node = Cards.patch("bush", card_spots)
		else:
			node = _blob_patch(mesh, list, w)
		var mm: MultiMesh = node.multimesh
		for i in range(list.size()):
			var spot := Vector2(list[i].x, list[i].z)
			if not w.tree_parts.has(spot):
				w.tree_parts[spot] = []
			w.tree_parts[spot].append([mm, i])
		node.visibility_range_end = 260.0
		node.visibility_range_end_margin = 20.0
		w.add_child(node)
		w.tree_nodes.append(node)

static func _blob_patch(mesh: ArrayMesh, list: Array, w: Node) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in range(list.size()):
		var s: Dictionary = list[i]
		var size: float = 2.4 * float(s.scale)
		var spin := fmod(s.x * 12.9898 + s.z * 78.233, TAU)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, spin).scaled(Vector3(size, size * 0.8, size)), Vector3(s.x, w.height_at(s.x, s.z) - 0.1, s.z)))
		mm.set_instance_custom_data(i, Color(fposmod(sin(s.x * 3.3 + s.z * 5.9) * 43758.5453, 1.0), 0.0, 0.0, 1.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	return node
