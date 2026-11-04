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
	"wall_concrete": ["concrete_smooth", 3.0, 1.0, 0.0, Color.WHITE, 0.0],
	"camo": ["camo_woodland", 3.0, 1.0, 0.0, Color(0.9, 0.9, 0.85), 0.0],
	"earth": ["dirt_dry", 2.5, 1.0, 0.0, Color(0.85, 0.8, 0.75), 0.0],
	"turf": ["grass_dry", 2.0, 1.0, 0.0, Color(0.85, 0.85, 0.7), 0.0],
	"gravel": ["gravel", 2.0, 1.0, 0.0, Color(0.9, 0.9, 0.9), 0.0],
	"asphalt": ["asphalt_worn", 3.0, 1.0, 0.0, Color.WHITE, 0.0],
	"wood": ["wood_planks_weathered", 1.5, 1.0, 0.0, Color(1.1, 1.05, 1.0), 0.0],
	"metal": ["steel_painted_dark", 2.0, 0.7, 0.55, Color(2.4, 2.4, 2.5), 0.0],
	"steel_dark": ["steel_painted_dark", 2.0, 0.8, 0.5, Color(1.1, 1.1, 1.15), 0.0],
	"sandbag": ["sand_beach", 0.9, 1.0, 0.0, Color(0.85, 0.72, 0.52), 0.0],
	"net": ["camo_woodland", 2.0, 1.0, 0.0, Color(0.7, 0.75, 0.65), 0.0],
	"hazard": ["", 1.0, 0.8, 0.0, Color(0.92, 0.7, 0.1), 0.0],
	"dark": ["", 1.0, 1.0, 0.0, Color(0.02, 0.025, 0.03), 0.0],
	"glow_warm": ["", 1.0, 1.0, 0.0, Color(1.0, 0.85, 0.55), 2.2],
	"glow_red": ["", 1.0, 1.0, 0.0, Color(1.0, 0.25, 0.2), 2.5],
	"glow_green": ["", 1.0, 1.0, 0.0, Color(0.4, 1.0, 0.4), 2.0],
	"banner": ["", 1.0, 0.9, 0.0, Color.WHITE, 0.0],
	"stone": ["stone_ashlar_beige", 2.5, 1.0, 0.0, Color(1.05, 1.02, 0.98), 0.0],
	"plaster": ["plaster_cream", 3.0, 1.0, 0.0, Color(1.0, 0.98, 0.92), 0.0],
	"brick": ["brick_red", 2.0, 1.0, 0.0, Color(1.0, 0.95, 0.92), 0.0],
	"roof_slate": ["roof_slate", 2.0, 0.9, 0.0, Color(0.9, 0.92, 0.95), 0.0],
	"roof_tile": ["roof_tile_clay", 2.0, 1.0, 0.0, Color.WHITE, 0.0],
	"copper": ["", 1.0, 0.55, 0.55, Color(0.32, 0.6, 0.52), 0.0],
	"gold": ["", 1.0, 0.3, 0.9, Color(0.95, 0.75, 0.25), 0.0],
	"cladding": ["concrete_smooth", 4.0, 0.55, 0.25, Color(1.25, 1.27, 1.3), 0.0],
	"glass": ["", 1.0, 0.06, 0.1, Color(0.17, 0.27, 0.34), 0.0],
	"glow_cyan": ["", 1.0, 1.0, 0.0, Color(0.75, 0.92, 1.0), 2.2],
	"glow_dim": ["", 1.0, 1.0, 0.0, Color(0.45, 0.75, 1.0), 1.0],
	"pavers": ["concrete_pavers", 2.0, 1.0, 0.0, Color(1.2, 1.2, 1.2), 0.0],
	"paint": ["", 1.0, 0.4, 0.3, Color.WHITE, 0.0],
	"leaf": ["", 1.0, 1.0, 0.0, Color(0.62, 0.66, 0.6), 0.0],
	"solar": ["", 1.0, 0.2, 0.6, Color(0.08, 0.13, 0.22), 0.0],
}
static var _cache := {}

## The material of a Blender-model role.
static func blend_material(role: String, tint := Color.WHITE) -> Material:
	var key := "b:" + role + (tint.to_html() if role == "banner" else "")
	if _cache.has(key):
		return _cache[key]
	var def: Array = BLEND_ROLES.get(role, ["concrete_smooth", 3.0, 1.0, 0.0, Color.WHITE, 0.0])
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
		for s in range(mesh.get_surface_count()):
			var src: Material = mesh.surface_get_material(s)
			mi.set_surface_override_material(s, blend_material(src.resource_name if src != null else "", owner_colour))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
