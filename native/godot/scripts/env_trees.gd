extends RefCounted
## The island's trees, made in Blender (native/tools/models/blender/build_trees.py -> assets/art/blender/env/tree_<species>_<n>.glb and
## ..._far.glb): birch, oak, Scots pine, spruce, poplar, willow and dead trees. The species of each tree follows the ground it stands
## on (willows and poplars by the water, oaks and birches in the lowland, pines and spruces on the high ground, dead trees on the
## bare heights) and its grove (a grove leans to one species, so the woods look like stands, not a mixed bag). One MultiMesh per 96 m
## cell, species, variant and part; a detailed copy near the camera and a cheap one from 120 m on. They are felled with the rest
## (world.tree_parts, site_clearing.gd).
const DIR := "res://assets/art/blender/env/"
const NEAR_END := 58.0
const FAR_BEGIN := 135.0
const SPECIES := {"birch": 3, "oak": 3, "pine": 3, "spruce": 3, "poplar": 2, "willow": 2, "dead": 2}
## How tall the tree at scale 1 stands (metres); the map's own scale (1.1 to 1.6) comes on top.
const HEIGHT := {"birch": 7.5, "oak": 8.0, "pine": 10.5, "spruce": 11.0, "poplar": 11.0, "willow": 7.5, "dead": 6.0}
## Species by height above the sea (metres), each with its weight.
const BANDS := [
	[1.8, [["willow", 3], ["poplar", 3], ["oak", 3], ["birch", 1]]],
	[6.0, [["oak", 4], ["birch", 4], ["poplar", 1], ["pine", 2]]],
	[13.0, [["pine", 4], ["spruce", 3], ["birch", 2], ["oak", 1]]],
	[1000.0, [["spruce", 5], ["pine", 3], ["dead", 2]]],
]
const CONIFERS := ["pine", "spruce"]
static var _parts := {}
static var _shader: Shader

static func _hash(x: float, z: float, k := 0.0) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + k * 37.719) * 43758.5453, 1.0)

static func _choose(pool: Array, r: float) -> String:
	var total := 0.0
	for e in pool:
		total += float(e[1])
	var at := r * total
	for e in pool:
		at -= float(e[1])
		if at <= 0.0:
			return e[0]
	return pool[0][0]

## The species of the tree at (x, z) in grove `grove` (-1: standing alone).
static func species_for(w: Node, x: float, z: float, grove: int) -> String:
	var h: float = w.height_at(x, z) - float(w.map.seaLevel)
	var pool: Array = BANDS[BANDS.size() - 1][1]
	for band in BANDS:
		if h < float(band[0]):
			pool = band[1]
			break
	var own := _hash(x, z)
	var stand := fposmod(sin(float(grove) * 91.7 + 3.1) * 43758.5453, 1.0) if grove >= 0 else own
	return _choose(pool, stand if own < 0.7 else own)

## The parts of one model, dressed: [{mesh, local, height}], the wood and the crown each with its own material.
static func parts(model: String, w: Node) -> Array:
	if _parts.has(model):
		return _parts[model]
	if _shader == null:
		_shader = load("res://shaders/tree_blender.gdshader")
	var out := []
	var scene: PackedScene = load(DIR + model + ".glb")
	if scene == null:
		_parts[model] = out
		return out
	var root: Node3D = scene.instantiate()
	var top := 0.0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var local: Transform3D = w.mesh_transform(root, mi)
		var dressed: Mesh = mesh.duplicate()
		for s in range(dressed.get_surface_count()):
			var src: Material = mesh.surface_get_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = _shader
			mat.set_shader_parameter("bark", src != null and src.resource_name == "wood")
			dressed.surface_set_material(s, mat)
		out.append({"mesh": dressed, "local": local})
		top = maxf(top, (local * (mi as MeshInstance3D).get_aabb()).end.y)
	root.free()
	for p in out:
		p["height"] = maxf(top, 0.1)
	_parts[model] = out
	return out

## More woods than the map file plants: stands on a coarse grid (a third of the cells), thick toward the middle of a stand and thin at
## its edge, kept off the steep ground, the shore, the start, the deposits and the trees already there.
const WOOD_CELL := 70.0
const WOOD_SHARE := 0.34
static func _woods(w: Node) -> Array:
	var out: Array = []
	var sea := float(w.map.seaLevel)
	var half := float(w.map.mapSize) * 0.5
	var gx := -half
	while gx < half:
		var gz := -half
		while gz < half:
			var ci := floori(gx / WOOD_CELL)
			var cj := floori(gz / WOOD_CELL)
			gz += WOOD_CELL
			if _hash(ci * 3.0, cj * 5.0, 21.0) > WOOD_SHARE:
				continue
			var cx := (ci + 0.3 + _hash(ci * 3.0, cj * 5.0, 22.0) * 0.4) * WOOD_CELL
			var cz := (cj + 0.3 + _hash(ci * 3.0, cj * 5.0, 23.0) * 0.4) * WOOD_CELL
			var radius := 22.0 + _hash(ci * 3.0, cj * 5.0, 24.0) * 22.0
			var x := cx - radius
			while x < cx + radius:
				var z := cz - radius
				while z < cz + radius:
					var px := x + (_hash(x, z, 25.0) - 0.5) * 6.0
					var pz := z + (_hash(x, z, 26.0) - 0.5) * 6.0
					z += 6.5
					var d := Vector2(px - cx, pz - cz).length() / radius
					if d > 1.0 or _hash(px, pz, 27.0) > (1.0 - d * d) * 0.9:
						continue
					if absf(px) > half - 10.0 or absf(pz) > half - 10.0:
						continue
					var h: float = w.height_at(px, pz) - sea
					if h < 1.0 or w.normal_at(px, pz).y < 0.9:
						continue
					if Vector2(px - w.start.x, pz - w.start.z).length() < 50.0:
						continue
					var clear := true
					for dep in w.map.deposits:
						if absf(dep.x - px) < 8.0 and absf(dep.z - pz) < 8.0:
							clear = false
							break
					if not clear:
						continue
					out.append({"x": px, "z": pz, "scale": 0.95 + _hash(px, pz, 28.0) * 0.65, "species": species_for(w, px, pz, ci * 1000 + cj)})
				x += 6.5
		gx += WOOD_CELL
	return out

static func build(w: Node) -> void:
	# species -> variant -> cell -> trees
	var cells := {}
	var all: Array = []
	for t in w.map.trees:
		var sp := species_for(w, t.x, t.z, int(t.grove))
		all.append({"x": t.x, "z": t.z, "scale": float(t.scale), "species": sp})
		if sp in CONIFERS:
			var hh := fposmod(sin(t.x * 3.1 + t.z * 7.7) * 43758.5453, 1.0)
			if hh < 0.5:   # half of the conifers get a smaller companion a few metres off, so the stands look dense
				var a := hh * TAU * 2.0
				var ex: float = t.x + cos(a) * 4.5
				var ez: float = t.z + sin(a) * 4.5
				if w.height_at(ex, ez) > float(w.map.seaLevel) + 0.6:
					all.append({"x": ex, "z": ez, "scale": float(t.scale) * 0.75, "species": sp})
	all.append_array(_woods(w))
	for t in all:
		var variants: int = SPECIES[t.species]
		var v := 1 + int(absf(t.x * 7.0 + t.z * 13.0)) % variants
		var key := "%s_%d|%d|%d" % [t.species, v, floori(t.x / 96.0), floori(t.z / 96.0)]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(t)
	for key in cells:
		var model: String = "tree_" + str(key).get_slice("|", 0)
		var list: Array = cells[key]
		for level in [0, 1, 2]:
			var ps := parts(model + ["", "_mid", "_far"][level], w)
			for part in ps:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = part.mesh
				mm.instance_count = list.size()
				for i in range(list.size()):
					var t: Dictionary = list[i]
					var size: float = float(HEIGHT[t.species]) * float(t.scale) / float(part.height)
					var spin := fmod(t.x * 12.9898 + t.z * 78.233, TAU)
					var lean := Basis(Vector3(cos(spin), 0, sin(spin)), fposmod(t.z * 0.13, 0.06) - 0.03)
					var basis := lean * Basis(Vector3.UP, spin).scaled(Vector3(size, size * (0.92 + fposmod(absf(t.x), 0.16)), size))
					mm.set_instance_transform(i, Transform3D(basis, Vector3(t.x, w.height_at(t.x, t.z) - 0.15, t.z)) * part.local)
					var shade := fposmod(sin(t.x * 5.3 + t.z * 1.7) * 43758.5453, 1.0)
					mm.set_instance_custom_data(i, Color(0.45 + shade * 0.1, 0.5 + shade * 0.08, 0.45, 1.0))
					var spot := Vector2(t.x, t.z)
					if not w.tree_parts.has(spot):
						w.tree_parts[spot] = []
					w.tree_parts[spot].append([mm, i])
				var node := MultiMeshInstance3D.new()
				node.multimesh = mm
				# Three levels of detail: the full tree close up, the same tree on cheaper shapes (a third of the triangles, hardly
				# different at that range) out to 135 m, and the plain one beyond.
				if level == 0:
					node.visibility_range_end = NEAR_END
					node.visibility_range_end_margin = 8.0
				elif level == 1:
					node.visibility_range_begin = NEAR_END
					node.visibility_range_begin_margin = 8.0
					node.visibility_range_end = FAR_BEGIN
					node.visibility_range_end_margin = 14.0
				else:
					node.visibility_range_begin = FAR_BEGIN
					node.visibility_range_begin_margin = 14.0
				node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				w.add_child(node)
				w.tree_nodes.append(node)
