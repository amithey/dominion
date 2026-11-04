extends RefCounted
## The ground cover of the island, made in Blender (native/tools/models/blender/build_ground.py -> assets/art/blender/env/ground_*.glb):
## shrubs at the edges of the groves and a few in the open, ferns under the trees, fallen logs and stumps in the woods, reeds and
## cattails along the water, pebbles on the beaches. One MultiMesh per 96 m cell and model, each kind drawn out to its own distance.
## They are felled (hidden) with the trees when a building needs the ground (world.tree_parts, site_clearing.gd). The grass tufts and
## wildflowers stay cards (foliage_cards.gd): there are far too many of them for models.
const Trees := preload("res://scripts/env_trees.gd")
const Rocks := preload("res://scripts/env_rocks.gd")
const DIR := "res://assets/art/blender/env/"
## kind -> [variants, draw distance]
const KINDS := {"shrub": [3, 230.0], "shrub_flower": [1, 230.0], "fern": [2, 130.0], "reed": [2, 170.0], "log": [3, 200.0], "stump": [2, 180.0], "pebbles": [3, 150.0]}

static func _hash(x: float, z: float, k: float) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + k * 37.719) * 43758.5453, 1.0)

static func _add(spots: Array, kind: String, x: float, z: float, scale: float) -> void:
	var n: int = int(KINDS[kind][0])
	spots.append({"x": x, "z": z, "kind": kind, "model": "ground_%s_%d" % [kind, 1 + int(_hash(x, z, 9.0) * 100.0) % n], "scale": scale})

static func build(w: Node) -> void:
	var sea := float(w.map.seaLevel)
	var spots := []
	# Round the trees: shrubs at the grove edges, ferns underneath, logs and stumps where the woodcutters left them.
	for t in w.map.trees:
		var h := _hash(t.x, t.z, 1.0)
		var a := _hash(t.x, t.z, 2.0) * TAU
		var d := 2.5 + _hash(t.x, t.z, 3.0) * 5.5
		var x: float = t.x + cos(a) * d
		var z: float = t.z + sin(a) * d
		if w.height_at(x, z) - sea < 1.2:
			continue
		if h < 0.40:
			_add(spots, "shrub_flower" if h < 0.05 else "shrub", x, z, 0.8 + _hash(x, z, 4.0) * 0.7)
		elif h < 0.62:
			_add(spots, "fern", x, z, 0.8 + _hash(x, z, 4.0) * 0.6)
		elif h < 0.70:
			_add(spots, "log", x, z, 0.9 + _hash(x, z, 4.0) * 0.3)
		elif h < 0.78:
			_add(spots, "stump", x, z, 0.9 + _hash(x, z, 4.0) * 0.4)
	var half := float(w.map.mapSize) * 0.5
	var x := -half + 3.0
	while x < half - 3.0:
		var z := -half + 3.0
		while z < half - 3.0:
			var px := x + (_hash(x, z, 11.0) - 0.5) * 4.0
			var pz := z + (_hash(x, z, 12.0) - 0.5) * 4.0
			z += 4.0
			var hh: float = w.height_at(px, pz) - sea
			var up: float = w.normal_at(px, pz).y
			if hh > 0.15 and hh < 1.1 and up >= 0.9:
				if _hash(px, pz, 13.0) < 0.2:
					_add(spots, "reed", px, pz, 0.8 + _hash(px, pz, 14.0) * 0.5)   # reeds in the shallows and on the wet shore
			if hh > 0.1 and hh < 0.9 and up >= 0.88 and _hash(px, pz, 15.0) < 0.05:
				_add(spots, "pebbles", px, pz, 0.8 + _hash(px, pz, 16.0) * 0.8)    # stones on the beach
			elif hh > 2.5 and up >= 0.93 and _hash(px, pz, 17.0) < 0.012:
				_add(spots, "shrub", px, pz, 0.8 + _hash(px, pz, 18.0) * 0.6)      # a lone shrub in the open
		x += 4.0
	var cells := {}
	for s in spots:
		var key := "%s|%d|%d" % [s.model, floori(s.x / 96.0), floori(s.z / 96.0)]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(s)
	for key in cells:
		var model: String = str(key).get_slice("|", 0)
		var list: Array = cells[key]
		var kind: String = str(list[0].kind)
		var ps: Array = []
		if kind == "pebbles":
			var rp: Dictionary = Rocks._part(model, w)
			if not rp.is_empty():
				ps.append({"mesh": rp.mesh, "local": rp.local})
		else:
			ps = Trees.parts(model, w)
		for part in ps:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = part.mesh
			mm.instance_count = list.size()
			for i in range(list.size()):
				var s: Dictionary = list[i]
				var yaw := _hash(s.x, s.z, 7.0) * TAU
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * float(s.scale))
				mm.set_instance_transform(i, Transform3D(basis, Vector3(s.x, w.height_at(s.x, s.z), s.z)) * part.local)
				var shade := _hash(s.x, s.z, 8.0)
				mm.set_instance_custom_data(i, Color(0.45 + shade * 0.1, 0.5 + shade * 0.08, 0.45, 1.0))
				var spot := Vector2(s.x, s.z)
				if not w.tree_parts.has(spot):
					w.tree_parts[spot] = []
				w.tree_parts[spot].append([mm, i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.visibility_range_end = float(KINDS[kind][1])
			node.visibility_range_end_margin = 14.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			w.add_child(node)
			w.tree_nodes.append(node)
