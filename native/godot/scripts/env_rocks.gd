extends RefCounted
## Boulders, groups of stones, scree and rock outcrops on the island (Blender models: native/tools/models/blender/build_rocks.py ->
## assets/art/blender/env/rock_*.glb), scattered by the lie of the land: outcrops and scree where the ground is steep, boulders and
## groups on the gentler rises, now and then a stone on the flat. One MultiMesh per 96 m cell and model, drawn out to 320 m. Felled
## (hidden) with the trees when a building needs the ground (world.tree_parts, site_clearing.gd).
const DIR := "res://assets/art/blender/env/"
const COUNTS := {"rock_boulder": 4, "rock_group": 3, "rock_outcrop": 3, "rock_scree": 2}
const STEP := 9.0
static var _material: Material
static var _meshes := {}

static func _stone() -> Material:
	if _material != null:
		return _material
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/terrain/rock_color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/terrain/rock_normal.jpg")
	m.normal_scale = 1.4
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.45
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.albedo_color = Color(2.1, 2.1, 2.1)   # the photo is dark; the vertex colour sets the tone
	m.roughness = 0.88
	_material = m
	return m

## The mesh of one model with its transform inside the scene, dressed with the stone material.
static func _part(model: String, w: Node) -> Dictionary:
	if _meshes.has(model):
		return _meshes[model]
	var out := {}
	var scene: PackedScene = load(DIR + model + ".glb")
	if scene != null:
		var root: Node3D = scene.instantiate()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh.duplicate()
			for s in range(mesh.get_surface_count()):
				mesh.surface_set_material(s, _stone())
			out = {"mesh": mesh, "local": w.mesh_transform(root, mi)}
			break
		root.free()
	_meshes[model] = out
	return out

static func _hash(x: float, z: float, k: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + k * 37.719) * 43758.5453, 1.0)

static func build(w: Node) -> void:
	var half := float(w.map.mapSize) * 0.5
	var sea := float(w.map.seaLevel)
	var spots := []
	var x := -half + 4.0
	while x < half - 4.0:
		var z := -half + 4.0
		while z < half - 4.0:
			var px := x + (_hash(x, z, 1.0) - 0.5) * STEP
			var pz := z + (_hash(x, z, 2.0) - 0.5) * STEP
			z += STEP
			var h: float = w.height_at(px, pz) - sea
			if h < 0.5:
				continue
			var steep: float = 1.0 - w.normal_at(px, pz).y
			var chance := clampf(steep * 2.4 - 0.05, 0.0, 0.7) + (0.025 if h > 1.5 else 0.0)
			if _hash(px, pz, 3.0) > chance:
				continue
			if Vector2(px - w.start.x, pz - w.start.z).length() < 30.0:
				continue
			var near_deposit := false
			for d in w.map.deposits:
				if absf(d.x - px) < 9.0 and absf(d.z - pz) < 9.0:
					near_deposit = true
					break
			if near_deposit:
				continue
			var r := _hash(px, pz, 4.0)
			var kind := "rock_boulder"
			if steep > 0.28:
				kind = "rock_outcrop" if r < 0.45 else ("rock_scree" if r < 0.7 else "rock_boulder")
			elif steep > 0.12:
				kind = "rock_group" if r < 0.5 else "rock_boulder"
			else:
				kind = "rock_boulder" if r < 0.7 else "rock_group"
			var model := "%s_%d" % [kind, 1 + int(_hash(px, pz, 5.0) * 100.0) % int(COUNTS[kind])]
			spots.append({"x": px, "z": pz, "model": model, "scale": 0.8 + _hash(px, pz, 6.0) * 0.9})
		x += STEP
	var cells := {}
	for s in spots:
		var key := "%s|%d|%d" % [s.model, floori(s.x / 96.0), floori(s.z / 96.0)]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(s)
	for key in cells:
		var part := _part(str(key).get_slice("|", 0), w)
		if part.is_empty():
			continue
		var list: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part.mesh
		mm.instance_count = list.size()
		for i in range(list.size()):
			var s: Dictionary = list[i]
			var yaw := _hash(s.x, s.z, 7.0) * TAU
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(s.scale))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(s.x, w.height_at(s.x, s.z) + 0.1, s.z)) * part.local)
			var spot := Vector2(s.x, s.z)
			if not w.tree_parts.has(spot):
				w.tree_parts[spot] = []
			w.tree_parts[spot].append([mm, i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.visibility_range_end = 320.0
		node.visibility_range_end_margin = 24.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		w.add_child(node)
		w.tree_nodes.append(node)
