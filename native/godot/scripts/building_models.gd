extends RefCounted
## The code-built building models (assets/art/buildings/*.glb, native/tools/models/generate_buildings.py) dressed with the
## tileable PBR materials (assets/art/materials/*): each primitive of a model is named by its role (wall_brick, roof_tile,
## glass...) and its UVs are in metres, so a material tile keeps its real size on every wall and roof.

const DIR := "res://assets/art/buildings/"
const MAT := "res://assets/art/materials/"
## role -> [material set, metres one tile covers, roughness scale, metallic]
const ROLES := {
	"wall_brick": ["brick_red", 2.0, 1.0, 0.0],
	"wall_plaster": ["plaster_cream", 3.0, 1.0, 0.0],
	"wall_stone": ["stone_ashlar_beige", 2.5, 1.0, 0.0],
	"wall_concrete": ["concrete_smooth", 3.0, 1.0, 0.0],
	"roof_tile": ["roof_tile_clay", 2.0, 1.0, 0.0],
	"roof_slate": ["roof_slate", 2.0, 1.0, 0.0],
	"roof_metal": ["corrugated_metal_grey", 2.0, 0.9, 0.35],
	"trim": ["plaster_white_cracked", 2.0, 1.0, 0.0],
	"glass": ["glass_reflective_dark", 2.0, 0.05, 0.0],
	"wood": ["wood_planks_weathered", 1.5, 1.0, 0.0],
	"metal": ["steel_painted_dark", 2.0, 0.8, 0.6],
}
static var _cache := {}

static func material(role: String) -> Material:
	if _cache.has(role):
		return _cache[role]
	var def: Array = ROLES.get(role, ["concrete_smooth", 3.0, 1.0, 0.0])
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(MAT + "%s_albedo.png" % def[0])
	var normal = load(MAT + "%s_normal.png" % def[0])
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = 0.8
	var rough = load(MAT + "%s_roughness.png" % def[0])
	if rough != null:
		m.roughness_texture = rough
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = float(def[2])
	m.metallic = float(def[3])
	m.uv1_scale = Vector3(1.0 / float(def[1]), 1.0 / float(def[1]), 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if role == "metal":
		m.albedo_color = Color(2.4, 2.4, 2.5)   # the dark steel texture, lifted: tanks, silos and rails read as galvanised grey, not black
	if role == "glass":
		# Dark glass that mirrors the sky: a blue-grey body, glossy, bright at a glancing angle.
		m.albedo_color = Color(0.55, 0.8, 1.0)
		m.albedo_texture = null
		m.roughness_texture = null
		m.albedo_color = Color(0.17, 0.27, 0.34)
		m.metallic_specular = 1.0
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.5
	_cache[role] = m
	return m

## Which models exist for a kind of building ("cottage" -> ["cottage_1", "cottage_2", "cottage_3"]).
static func variants(kind: String) -> Array:
	var out := []
	for i in range(1, 8):
		if ResourceLoader.exists(DIR + "%s_%d.glb" % [kind, i]):
			out.append("%s_%d" % [kind, i])
	return out

## An instance of the model, dressed with the materials; LOD0 near, LOD1 beyond `switch` metres.
static func build(model: String, switch := 70.0) -> Node3D:
	var scene: PackedScene = load(DIR + model + ".glb")
	if scene == null:
		return null
	var root: Node3D = scene.instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var src: Material = mesh.surface_get_material(s)
			var role: String = src.resource_name if src != null else ""
			mi.set_surface_override_material(s, material(role))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.set_meta("architecture", true)   # districts.tone() leaves a finished building as it is
	for lod in root.find_children("LOD*", "Node3D", true, false):
		if lod.name == "LOD0":
			lod.visible = true
			for mi in lod.find_children("*", "GeometryInstance3D", true, false):
				mi.visibility_range_end = switch
				mi.visibility_range_end_margin = 6.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		elif lod.name == "LOD1":
			for mi in lod.find_children("*", "GeometryInstance3D", true, false):
				mi.visibility_range_begin = switch
				mi.visibility_range_begin_margin = 6.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# The chimney's smoke (ambience.gd looks for markers named SmokeHome): the houses have their chimney toward the
	# back left (the generator puts it at -27% of the width and -18% of the depth, on top of the roof's highest point).
	# Codex's own smoke emitters (empty nodes Smoke_Home_N and Smoke_Industry_N at the tops of chimneys and stacks) become the
	# markers ambience.gd looks for (Marker3D named SmokeHomeN / SmokeIndustryN), in the model's own space.
	var own := 0
	for node in root.find_children("Smoke_*", "Node3D", true, false):
		var industry: bool = str(node.name).begins_with("Smoke_Industry")
		var marker := Marker3D.new()
		marker.name = ("SmokeIndustry%d" if industry else "SmokeHome%d") % own
		root.add_child(marker)
		marker.transform = root.global_transform.affine_inverse() * node.global_transform if root.is_inside_tree() else _local_transform(node, root)
		own += 1
	var kind := model.rsplit("_", 1)[0]
	if own == 0 and kind in ["cottage", "townhouse", "farmhouse"]:
		var box := AABB()
		for lod in root.find_children("LOD0", "MeshInstance3D", true, false):
			box = lod.get_aabb()
		var marker := Marker3D.new()
		marker.name = "SmokeHome0"
		marker.position = Vector3(-box.size.x * 0.27, box.end.y + 0.15, -box.size.z * 0.18)
		root.add_child(marker)
	return root

## A node's transform in `root`'s space (the model is not in the tree yet, so global_transform is not available).
static func _local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
