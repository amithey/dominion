extends RefCounted
## Blender 5.2 LTS aircraft, helicopter, warship, carrier and submarine models
## (`assets/art/aircraft/<key>__<slug>.glb` and `assets/art/ships/<key>__<slug>.glb`).
## Resolves each nation's real designation via `national_variants.gd`, scales the real-metre
## `.glb` airframe/hull to RTS map dimensions, seats warships & submarines on their exact
## `Waterline` marker, and returns `{root, rotor, rotor2, radar, turret, wreck}` matching `craft.gd`.

const AIR_DIR := "res://assets/art/aircraft/"
const SHIP_DIR := "res://assets/art/ships/"

const SHIP_KEYS := [
	"gunboat", "missileBoat", "corvette", "kcr60", "asFrigate", "destroyer", "type45",
	"aegisCruiser", "railgunShip", "landingShip", "carrier", "submarine", "nuclearSub",
	"orca", "seaDrone",
]

const RTS_SHIP_LENGTH := {
	"seaDrone": 4.5, "gunboat": 7.5, "missileBoat": 8.0, "orca": 9.0,
	"corvette": 10.5, "kcr60": 10.5, "submarine": 11.0, "asFrigate": 13.0,
	"nuclearSub": 14.0, "destroyer": 15.0, "type45": 15.0, "landingShip": 16.0,
	"railgunShip": 16.5, "aegisCruiser": 17.0, "carrier": 28.0,
}

const RTS_AIR_LENGTH := {
	"loiterer": 2.2, "interceptorDrone": 2.2, "heavyBomberDrone": 2.6,
	"shahed": 3.0, "harop": 3.0, "carrierDrone": 3.8, "drone": 4.4, "akinci": 5.2,
	"scoutHelicopter": 6.4, "helicopter": 7.4, "gunship": 7.5, "navalHelicopter": 7.6,
	"superTucano": 7.2, "lightFighter": 7.6, "jf17": 7.8, "attackJet": 8.0,
	"stealthFighter": 8.2, "raptor": 8.4, "carrierJet": 8.2, "jet": 8.5, "ewJet": 8.6,
	"sixthGen": 8.8, "wingman": 5.4, "heavyLift": 10.2, "maritimePatrol": 10.4,
	"aewc": 10.6, "bomber": 11.6, "raider": 10.2,
}

const FINISH_COLOR := {
	"ship": Color("5e676c"), "sub": Color("2b2f32"), "usv": Color("2e3336"),
	"heli": Color("4d5641"), "gunship": Color("454c3c"), "naval_heli": Color("69737a"),
	"jet": Color("737d84"), "stealth": Color("4b5157"), "bomber": Color("50585c"),
	"patrol": Color("7c858c"), "drone": Color("8a9297"), "shahed": Color("9a9b8f"),
}

static var _materials := {}

static func slug(text: String) -> String:
	var out := ""
	var gap := false
	for ch in text.to_lower():
		var ok := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if ok:
			if gap and out != "":
				out += "_"
			out += ch
			gap = false
		else:
			gap = true
	return out.left(48).trim_suffix("_")

static func _finish_for(key: String, is_ship: bool) -> String:
	if is_ship:
		if key in ["submarine", "nuclearSub", "orca"]:
			return "sub"
		if key == "seaDrone":
			return "usv"
		return "ship"
	match key:
		"helicopter", "heavyLift", "scoutHelicopter":
			return "heli"
		"gunship":
			return "gunship"
		"navalHelicopter":
			return "naval_heli"
		"stealthFighter", "raptor", "sixthGen", "raider":
			return "stealth"
		"bomber":
			return "bomber"
		"aewc", "maritimePatrol":
			return "patrol"
		"drone", "loiterer", "carrierDrone", "akinci", "harop", "heavyBomberDrone", "interceptorDrone":
			return "drone"
		"shahed":
			return "shahed"
		_:
			return "jet"

static func _search_dir(dir: String, key: String, text: String) -> String:
	var words := slug(text)
	while words != "":
		var p := dir + "%s__%s.glb" % [key, words]
		if ResourceLoader.exists(p):
			return p
		var cut := words.rfind("_")
		words = "" if cut < 0 else words.left(cut)
	return ""

static func path_for(w: Node, owner: int, key: String) -> String:
	var is_ship := key in SHIP_KEYS
	var dir := SHIP_DIR if is_ship else AIR_DIR
	var name: String = preload("res://scripts/national_variants.gd").name_for(w, owner, key)
	var found := _search_dir(dir, key, name)
	if found != "":
		return found
	if not is_ship and key in ["carrierJet", "carrierDrone"]:
		var id: String = preload("res://scripts/factions.gd").identity(w, owner)
		var wing_name: String = str(preload("res://scripts/war_tools.gd").WING_AIRCRAFT.get(id, ""))
		if wing_name != "":
			found = _search_dir(AIR_DIR, key, wing_name)
			if found != "":
				return found
		var generic := AIR_DIR + ("carrierJet__carrier_fighter.glb" if key == "carrierJet" else "carrierDrone__carrier_drone.glb")
		if ResourceLoader.exists(generic):
			return generic
	var base_key: String = preload("res://scripts/additional_factions.gd").base(key)
	if base_key != key:
		found = _search_dir(SHIP_DIR if base_key in SHIP_KEYS else AIR_DIR, base_key, name)
		if found != "":
			return found
	return ""

static func _shader_material(w: Node, owner: int, finish: String, role: String, is_ship: bool) -> Material:
	var id := "%d:%s:%s:%d" % [owner, finish, role, 1 if is_ship else 0]
	if _materials.has(id):
		return _materials[id]
	var m: Material
	if role == "glass":
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.06, 0.14, 0.19)
		g.vertex_color_use_as_albedo = true
		g.vertex_color_is_srgb = false
		g.roughness = 0.08
		g.metallic = 0.55
		g.metallic_specular = 0.9
		m = g
	else:
		var s := ShaderMaterial.new()
		s.shader = load("res://shaders/vehicle.gdshader")
		s.set_shader_parameter("noise_tex", w.noise_texture)
		var base_paint: Color = FINISH_COLOR.get(finish, FINISH_COLOR.jet)
		var team: Color = Color(w.map.nations[owner].color) if owner < w.map.nations.size() else Color.WHITE
		s.set_shader_parameter("dust_color", base_paint * 0.85)
		s.set_shader_parameter("dust_height", 0.35 if is_ship else 0.0)
		match role:
			"hull_red":
				s.set_shader_parameter("paint", Color(0.44, 0.13, 0.10))
				s.set_shader_parameter("shade", 0.95)
			"deck":
				s.set_shader_parameter("paint", Color(0.20, 0.22, 0.24))
				s.set_shader_parameter("shade", 0.90)
			"radome":
				s.set_shader_parameter("paint", Color(0.74, 0.75, 0.73))
				s.set_shader_parameter("shade", 0.96)
			"white":
				s.set_shader_parameter("paint", Color(0.88, 0.89, 0.88))
				s.set_shader_parameter("shade", 0.98)
			"metal_dark":
				s.set_shader_parameter("paint", Color(0.16, 0.16, 0.17))
				s.set_shader_parameter("metal", 1.0)
			"metal":
				s.set_shader_parameter("paint", Color(0.31, 0.32, 0.34))
				s.set_shader_parameter("metal", 1.0)
			"rubber":
				s.set_shader_parameter("paint", Color(0.06, 0.06, 0.065))
				s.set_shader_parameter("shade", 0.72)
			"dark":
				s.set_shader_parameter("paint", Color(0.03, 0.032, 0.035))
				s.set_shader_parameter("shade", 0.80)
			"markings":
				s.set_shader_parameter("paint", team)
				s.set_shader_parameter("shade", 0.88)
			_:
				s.set_shader_parameter("paint", base_paint)
		m = s
	_materials[id] = m
	return m

static func _local_bounds(node: Node3D) -> AABB:
	var first := true
	var out := AABB()
	var inv := node.global_transform.affine_inverse() if node.is_inside_tree() else Transform3D.IDENTITY
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var cur: Node = pair[0]
		var xf: Transform3D = pair[1]
		if cur is MeshInstance3D and cur.mesh != null:
			var b: AABB = cur.get_aabb()
			for i in range(8):
				var pt: Vector3 = xf * b.get_endpoint(i)
				if first:
					out = AABB(pt, Vector3.ZERO)
					first = false
				else:
					out = out.expand(pt)
		for ch in cur.get_children():
			if ch is Node3D:
				stack.append([ch, xf * ch.transform])
	var _unused := inv
	return out

static func build(w: Node, key: String, owner: int) -> Dictionary:
	var path := path_for(w, owner, key)
	if path == "":
		return {}
	return build_file(w, path, owner, key)

static func build_file(w: Node, path: String, owner: int, key_override := "") -> Dictionary:
	var scene: PackedScene = load(path)
	if scene == null:
		return {}
	var raw: Node3D = scene.instantiate()
	var is_ship := path.contains("/ships/")
	var file_key: String = path.get_file().get_basename().split("__")[0]
	var key: String = key_override if key_override != "" else file_key
	var finish := _finish_for(key, is_ship)

	for mi in raw.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s_idx in range(mesh.get_surface_count()):
			var src: Material = mesh.surface_get_material(s_idx)
			var rname: String = src.resource_name if src != null else "paint"
			mi.set_surface_override_material(s_idx, _shader_material(w, owner, finish, rname, is_ship))

	var cbox: Node = raw.get_node_or_null("Collision_Box")
	if cbox != null:
		raw.remove_child(cbox)
		cbox.queue_free()
	var wreck: Node3D = raw.get_node_or_null("Wreck") as Node3D
	if wreck != null:
		wreck.visible = false

	var lod0: Node3D = raw.get_node_or_null("LOD0") as Node3D
	var lod1: Node3D = raw.get_node_or_null("LOD1") as Node3D
	if lod0 != null and lod1 != null:
		lod0.visible = true
		lod1.visible = true
		var fade_dist := 115.0 if is_ship else 90.0
		for gi in lod0.find_children("*", "GeometryInstance3D", true, false):
			if str(gi.get_parent().name).begins_with("DeckPlane"):
				continue
			gi.visibility_range_end = fade_dist
			gi.visibility_range_end_margin = 8.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		for gi in lod1.find_children("*", "GeometryInstance3D", true, false):
			gi.visibility_range_begin = fade_dist
			gi.visibility_range_begin_margin = 8.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	var base: Node3D = lod0 if lod0 != null else raw
	var box := _local_bounds(base)
	var scale_factor := 1.0
	var y_shift := 0.0

	if is_ship:
		var bow_marker: Node3D = base.find_child("Hull_Bow", true, false) as Node3D
		var wl_marker: Node3D = base.find_child("Waterline", true, false) as Node3D
		var real_len: float = bow_marker.position.z * 2.0 if bow_marker != null else maxf(box.size.z, 1.0)
		var wl_y: float = wl_marker.position.y if wl_marker != null else box.size.y * 0.25
		var target_len: float = float(RTS_SHIP_LENGTH.get(key, RTS_SHIP_LENGTH.get(file_key, 12.0)))
		scale_factor = target_len / maxf(real_len, 0.5)
		var is_sub := key in ["submarine", "nuclearSub", "orca"] or file_key in ["submarine", "nuclearSub"]
		y_shift = (0.9 if is_sub else 0.0) - wl_y * scale_factor
	else:
		var target_air: float = float(RTS_AIR_LENGTH.get(key, RTS_AIR_LENGTH.get(file_key, 8.0)))
		var ref_dim: float = maxf(box.size.z, box.size.x * 0.72)
		scale_factor = target_air / maxf(ref_dim, 0.15)
		y_shift = -box.position.y * scale_factor

	var holder := Node3D.new()
	holder.name = "Craft_" + key
	raw.scale = Vector3.ONE * scale_factor
	raw.position.y = y_shift
	holder.add_child(raw)

	var rotor: Node3D = base.find_child("Rotor_Main", true, false) as Node3D
	var rotor2: Node3D = base.find_child("Rotor_Main_2", true, false) as Node3D
	var radar: Node3D = base.find_child("Radar", true, false) as Node3D
	var turret: Node3D = base.find_child("Turret", true, false) as Node3D
	if turret != null:
		turret.set_meta("axis", Vector3.UP)
	# Parts that turn with no clip: propellers (about the nose axis, +Z) and the tail rotor and fenestron (about the wing axis, +X).
	# Both detail levels have their own. (The landing gear is only on helicopters, whose skids stay down.)
	var props: Array = []
	var tail_rotors: Array = []
	for part in raw.find_children("*", "Node3D", true, false):
		var pn := str(part.name)
		if pn.ends_with("_Mesh") or pn.ends_with("_Mesh_LOD1"):
			continue
		pn = pn.trim_suffix("_LOD1")
		if pn == "Propeller" or (pn.begins_with("Propeller_") and pn.substr(10).is_valid_int()):
			props.append(part)
		elif pn == "Rotor_Tail" or pn == "Fenestron":
			tail_rotors.append(part)

	return {
		"props": props,
		"tail_rotors": tail_rotors,
		"root": holder,
		"rotor": rotor,
		"rotor2": rotor2,
		"radar": radar,
		"turret": turret,
		"wreck": wreck,
		"raw": raw,
		"lod0": lod0,
		"lod1": lod1,
		"real_bounds": box,
		"rts_scale": scale_factor,
		"model_file": path,
	}
