extends RefCounted
## The Blender-made buildings (assets/art/blender/*.glb, native/tools/models/blender): each primitive of a model is named by its role
## (stone, plaster, roof_slate, glass...) and dressed with the tileable PBR materials (assets/art/materials/*); the UVs are in metres,
## so a material tile keeps its real size on every wall and roof.

const MAT := "res://assets/art/materials/"
## The Blender-made buildings (assets/art/blender/*.glb, native/tools/models/blender): the same idea, with roles of their own
## (role -> [material set or "", metres one tile covers, roughness scale, metallic, colour, emission]); their parts carry a
## vertex colour that varies the bags, planks and crates, and the "banner" role takes the owner's colour.
const BLEND_DIR := "res://assets/art/blender/"
const BLEND_ROLES := {
	"wall_concrete": ["concrete_smooth", 3.0, 0.94, 0.0, Color(0.60, 0.58, 0.55), 0.0],
	"camo": ["camo_woodland", 3.0, 0.95, 0.0, Color(0.78, 0.80, 0.72), 0.0],
	"earth": ["dirt_dry", 2.5, 0.98, 0.0, Color(0.68, 0.60, 0.50), 0.0],
	"turf": ["grass_dry", 2.0, 0.95, 0.0, Color(0.68, 0.76, 0.56), 0.0],
	"gravel": ["gravel", 2.0, 0.96, 0.0, Color(0.46, 0.44, 0.40), 0.0],
	"asphalt": ["asphalt_worn", 3.0, 0.92, 0.0, Color(0.38, 0.39, 0.41), 0.0],
	"wood": ["wood_planks_weathered", 1.5, 0.92, 0.0, Color(0.88, 0.82, 0.74), 0.0],
	"metal": ["steel_painted_dark", 2.0, 0.62, 0.50, Color(1.08, 1.10, 1.14), 0.0],
	"steel_dark": ["steel_painted_dark", 2.0, 0.78, 0.45, Color(0.88, 0.90, 0.94), 0.0],
	"sandbag": ["sand_beach", 0.9, 0.96, 0.0, Color(0.76, 0.65, 0.47), 0.0],
	"net": ["camo_woodland", 2.0, 0.96, 0.0, Color(0.62, 0.68, 0.56), 0.0],
	"hazard": ["", 1.0, 0.82, 0.0, Color(0.84, 0.64, 0.12), 0.0],
	"dark": ["", 1.0, 0.95, 0.0, Color(0.03, 0.035, 0.04), 0.0],
	"glow_warm": ["", 1.0, 1.0, 0.0, Color(1.0, 0.85, 0.55), 1.9],
	"glow_red": ["", 1.0, 1.0, 0.0, Color(1.0, 0.25, 0.2), 2.2],
	"glow_green": ["", 1.0, 1.0, 0.0, Color(0.4, 1.0, 0.4), 1.8],
	"banner": ["", 1.0, 0.9, 0.0, Color.WHITE, 0.0],
	"stone": ["stone_ashlar_beige", 2.5, 0.92, 0.0, Color(0.82, 0.78, 0.71), 0.0],
	"plaster": ["plaster_cream", 3.0, 0.92, 0.0, Color(0.84, 0.80, 0.73), 0.0],
	"brick": ["brick_red", 2.0, 0.92, 0.0, Color(0.88, 0.80, 0.76), 0.0],
	"roof_slate": ["roof_slate", 2.0, 0.86, 0.0, Color(0.70, 0.74, 0.80), 0.0],
	"roof_tile": ["roof_tile_clay", 2.0, 0.90, 0.0, Color(0.88, 0.76, 0.68), 0.0],
	"copper": ["", 1.0, 0.52, 0.50, Color(0.28, 0.56, 0.48), 0.0],
	"gold": ["", 1.0, 0.34, 0.85, Color(0.88, 0.68, 0.22), 0.0],
	"cladding": ["concrete_smooth", 4.0, 0.68, 0.18, Color(0.76, 0.78, 0.81), 0.0],
	"glass": ["", 1.0, 0.08, 0.12, Color(0.15, 0.24, 0.31), 0.0],
	"glow_cyan": ["", 1.0, 1.0, 0.0, Color(0.75, 0.92, 1.0), 1.9],
	"glow_dim": ["", 1.0, 1.0, 0.0, Color(0.45, 0.75, 1.0), 0.9],
	"pavers": ["concrete_pavers", 2.0, 0.90, 0.0, Color(0.58, 0.55, 0.50), 0.0],
	"paint": ["", 1.0, 0.48, 0.22, Color(0.90, 0.90, 0.90), 0.0],
	"leaf": ["", 1.0, 0.94, 0.0, Color(0.56, 0.62, 0.52), 0.0],
	"solar": ["", 1.0, 0.22, 0.55, Color(0.07, 0.12, 0.20), 0.0],
}
static var _cache := {}

## The material of a Blender-model role.
static func blend_material(role: String, tint := Color.WHITE) -> Material:
	var key := "b:" + role + (tint.to_html() if role == "banner" else "")
	if _cache.has(key):
		return _cache[key]
	var def: Array = BLEND_ROLES.get(role, ["concrete_smooth", 3.0, 0.92, 0.0, Color(0.62, 0.60, 0.57), 0.0])
	var m := StandardMaterial3D.new()
	if str(def[0]) != "":
		m.albedo_texture = load(MAT + "%s_albedo.png" % def[0])
		var normal = load(MAT + "%s_normal.png" % def[0]) if ResourceLoader.exists(MAT + "%s_normal.png" % def[0]) else null
		if normal != null:
			m.normal_enabled = true
			m.normal_texture = normal
			m.normal_scale = 0.8
		var rough = load(MAT + "%s_roughness.png" % def[0]) if ResourceLoader.exists(MAT + "%s_roughness.png" % def[0]) else null
		if rough != null:
			m.roughness_texture = rough
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.uv1_scale = Vector3(1.0 / float(def[1]), 1.0 / float(def[1]), 1.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = float(def[2])
	m.metallic = float(def[3])
	m.albedo_color = tint if role == "banner" else def[4]
	m.vertex_color_use_as_albedo = role != "banner"
	if float(def[5]) > 0.0:
		m.emission_enabled = true
		m.emission = def[4]
		m.emission_energy_multiplier = float(def[5])
	if role == "banner":
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m

const PROP_NO_SHADOW_ROLES := [
	"paint", "dark", "glow_warm", "glow_red", "glow_green", "glow_cyan", "glow_dim",
	"hazard", "sandbag", "banner", "glass", "pavers", "turf", "earth", "gravel", "asphalt", "solar",
]
const DETAIL_CULL_ROLES := ["glow_warm", "glow_red", "glow_green", "glow_cyan", "glow_dim", "hazard", "sandbag", "banner"]

## Dynamic window glow multiplier controlled by ambience.gd (1.0 in daylight, up to 2.6 at dusk/winter/crisis).
static func set_window_glow_scale(scale: float) -> void:
	for r in ["glow_warm", "glow_cyan", "glow_dim"]:
		var k: String = "b:" + r
		if _cache.has(k) and _cache[k] is StandardMaterial3D:
			var m := _cache[k] as StandardMaterial3D
			var base_e := float(BLEND_ROLES[r][5])
			m.emission_energy_multiplier = base_e * scale

## An instance of a Blender-made model, dressed; `owner_colour` colours its banner.
static func build_blender(model: String, owner_colour := Color.WHITE) -> Node3D:
	var scene: PackedScene = load(BLEND_DIR + model + ".glb")
	if scene == null:
		return null
	var root: Node3D = scene.instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var primary_role := ""
		for s in range(mesh.get_surface_count()):
			var src: Material = mesh.surface_get_material(s)
			var rname := src.resource_name if src != null else ""
			if primary_role == "":
				primary_role = rname
			mi.set_surface_override_material(s, blend_material(rname, owner_colour))
		var aabb: AABB = mi.get_aabb()
		var max_dim: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		if primary_role in PROP_NO_SHADOW_ROLES or aabb.size.y < 1.35 or max_dim < 2.6:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if max_dim > 0.01 and (max_dim < 2.8 or primary_role in DETAIL_CULL_ROLES):
			mi.visibility_range_end = 205.0
			mi.visibility_range_end_margin = 16.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.set_meta("architecture", true)
	# Empty nodes Smoke_Industry_N / Smoke_Home_N at chimney tops become the markers ambience.gd looks for.
	var own := 0
	for node in root.find_children("Smoke_*", "Node3D", true, false):
		var industry: bool = str(node.name).begins_with("Smoke_Industry")
		var marker := Marker3D.new()
		marker.name = ("SmokeIndustry%d" if industry else "SmokeHome%d") % own
		root.add_child(marker)
		marker.transform = _local_transform(node, root)
		own += 1
	return root

static func has_blender(model: String) -> bool:
	return ResourceLoader.exists(BLEND_DIR + model + ".glb")

## A node's transform in `root`'s space (the model is not in the tree yet, so global_transform is not available).
static func _local_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
