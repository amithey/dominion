extends RefCounted
## The foot soldiers and the workers, made and animated in Blender (native/tools/models/blender/build_infantry.py ->
## assets/art/blender/people/inf_<kind>.glb): ten people on one humanoid rig with the clips idle_gun, run_gun, idle_shoot, death and
## interact, the weapon held in both hands in every clip. Here they are matched to the game's unit keys and dressed per nation: the
## uniform and trousers in the nation's field colours, the shoulder patches in the flag colour, everything else as modelled.
const DIR := "res://assets/art/blender/people/"
## unit key -> model kind (national variants are looked up through their base unit by the caller)
const KIND := {"soldier": "rifleman", "sniper": "sniper", "commando": "commando", "rocketSoldier": "rocket", "atgmTeam": "atgm",
	"manpads": "manpads", "medic": "medic", "worker": "worker", "fpvTeam": "fpv", "scoutTeam": "scout", "machineGunTeam": "mg",
	"mortarTeam": "mortar", "recoillessTeam": "rcl"}
## The run clip was authored for this ground speed in the model's own metres.
const RUN_SPEED := 3.2
static var _cache := {}

static func has(key: String) -> bool:
	return KIND.has(key) and ResourceLoader.exists(DIR + "inf_%s.glb" % KIND[key])

## The model for a unit key, dressed for `owner`'s colours (uniform, nation); null when there is none.
static func build(key: String, uniform: Color, pants: Color, nation: Color, skin := Color(0.85, 0.66, 0.5)) -> Node3D:
	if not has(key):
		return null
	var scene: PackedScene = load(DIR + "inf_%s.glb" % KIND[key])
	var root: Node3D = scene.instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in range(mesh.get_surface_count()):
			var src: Material = mesh.surface_get_material(s)
			(mi as MeshInstance3D).set_surface_override_material(s, material(src.resource_name if src != null else "", uniform, pants, nation, skin))
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(mi as MeshInstance3D).extra_cull_margin = 1.0   # skinned: the rest-pose bounds are not where the limbs end up
	root.set_meta("people", true)
	return root

## The skin tone of a nation's people, by the region it belongs to (districts.home_style).
static func skin_for(style: String, variation: float) -> Color:
	var c: Color = {"euro": Color(0.86, 0.68, 0.55), "us": Color(0.84, 0.64, 0.5), "med": Color(0.74, 0.54, 0.4), "asia": Color(0.84, 0.66, 0.48),
		"arab": Color(0.7, 0.5, 0.36), "india": Color(0.56, 0.38, 0.27), "africa": Color(0.38, 0.25, 0.17)}.get(style, Color(0.85, 0.66, 0.5))
	return c.lightened(variation * 0.1) if variation > 0.0 else c.darkened(-variation * 0.12)

static func material(role: String, uniform: Color, pants: Color, nation: Color, skin := Color(0.85, 0.66, 0.5)) -> Material:
	var key := "%s|%s|%s|%s|%s" % [role, uniform.to_html(), pants.to_html(), nation.to_html() if role == "banner" else "", skin.to_html() if role == "skin" else ""]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.roughness = 0.85
	var c := Color(0.5, 0.5, 0.5)
	match role:
		"uniform": c = uniform
		"pants": c = pants
		"dark_uniform": c = Color(0.1, 0.11, 0.12)
		"camo": c = Color(0.3, 0.36, 0.22)
		"work_uniform": c = Color(0.16, 0.26, 0.48)
		"gear": c = Color(0.24, 0.25, 0.19)
		"boot": c = Color(0.09, 0.075, 0.06)
		"glove": c = Color(0.12, 0.11, 0.1)
		"skin": c = skin
		"hair": c = Color(0.07, 0.05, 0.035)
		"metal":
			c = Color(0.2, 0.2, 0.21)
			m.metallic = 0.6
			m.roughness = 0.45
		"wood": c = Color(0.36, 0.22, 0.12)
		"dark": c = Color(0.03, 0.03, 0.035)
		"banner":
			c = nation
			m.vertex_color_use_as_albedo = false
		"hivis_orange":
			c = Color(1.0, 0.42, 0.04)
		"hivis_yellow":
			c = Color(0.95, 0.78, 0.04)
		"reflect":
			c = Color(0.8, 0.8, 0.7)
			m.roughness = 0.4
		"red": c = Color(0.7, 0.08, 0.08)
		"paint": c = Color(0.92, 0.92, 0.88)
		"glass":
			c = Color(0.1, 0.2, 0.26)
			m.roughness = 0.1
			m.metallic = 0.3
		"glow_cyan":
			c = Color(0.6, 0.9, 1.0)
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 2.0
	m.albedo_color = c if role != "banner" else nation
	_cache[key] = m
	return m
