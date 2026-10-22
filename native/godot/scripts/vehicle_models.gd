extends RefCounted
## The code-built vehicle models (assets/art/vehicles/<key>__<slug>.glb, native/tools/models/): each real designation a
## nation fields has its own model, with named parts that turn about their pivots (Turret, Gun, Wheel_*, Track_*...).
## The slug is the nation's name for the unit, lower case with every run of other characters turned into "_" and at most 48 characters
## ("M1A2 SEPv3 Abrams" -> m1a2_sepv3_abrams), so a model is picked up as soon as its file exists. Returns the same dictionary as
## armor.gd (root, turret, radar, axles, muzzle) so the game moves it exactly as it moves the kit's own vehicles.

const DIR := "res://assets/art/vehicles/"
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

static func path_for(w: Node, owner: int, key: String) -> String:
	var name: String = preload("res://scripts/national_variants.gd").name_for(w, owner, key)
	var path := DIR + "%s__%s.glb" % [key, slug(name)]
	return path if ResourceLoader.exists(path) else ""

static func _shader_material(w: Node, owner: int, role: String) -> Material:
	var id := "%d:%s" % [owner, role]
	if _materials.has(id):
		return _materials[id]
	var m: Material
	if role == "glass":
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.06, 0.13, 0.17)
		g.roughness = 0.08
		g.metallic = 0.5
		g.metallic_specular = 0.9
		m = g
	else:
		var s := ShaderMaterial.new()
		s.shader = load("res://shaders/vehicle.gdshader")
		s.set_shader_parameter("noise_tex", w.noise_texture)
		var paint: Color = w.VEHICLE_PAINT[owner % w.VEHICLE_PAINT.size()]
		var team: Color = Color(w.map.nations[owner].color) if owner < w.map.nations.size() else Color.WHITE
		match role:
			"metal_dark":
				s.set_shader_parameter("paint", Color(0.17, 0.17, 0.16))
				s.set_shader_parameter("metal", 1.0)
			"rubber":
				s.set_shader_parameter("paint", Color(0.06, 0.06, 0.06))
				s.set_shader_parameter("shade", 0.7)
			"markings":
				s.set_shader_parameter("paint", team)
				s.set_shader_parameter("shade", 0.85)
			_:
				s.set_shader_parameter("paint", paint)
		m = s
	_materials[id] = m
	return m

## The model dressed for nation `owner`, or {} when there is no model file for this unit.
static func build(w: Node, key: String, owner: int) -> Dictionary:
	var path := path_for(w, owner, key)
	if path == "":
		return {}
	return build_file(w, path, owner)

## A model from its file, dressed for nation `owner` (also the way the checks go through every file).
static func build_file(w: Node, path: String, owner: int) -> Dictionary:
	var scene: PackedScene = load(path)
	if scene == null:
		return {}
	var root: Node3D = scene.instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var src: Material = mesh.surface_get_material(s)
			mi.set_surface_override_material(s, _shader_material(w, owner, src.resource_name if src != null else "paint"))
	# The collision box is the game's own business; the burnt-out copy stays hidden until the tank is destroyed (world.gd kill()).
	var box: Node = root.get_node_or_null("Collision_Box")
	if box != null:
		root.remove_child(box)
		box.queue_free()
	var wreck: Node3D = root.get_node_or_null("Wreck") as Node3D
	if wreck != null:
		wreck.visible = false
	# Detail by distance: LOD0 near, LOD1 beyond 60 m.
	var lod0: Node3D = root.get_node_or_null("LOD0")
	var lod1: Node3D = root.get_node_or_null("LOD1")
	if lod0 != null and lod1 != null:
		lod0.visible = true
		lod1.visible = true
		for gi in lod0.find_children("*", "GeometryInstance3D", true, false):
			gi.visibility_range_end = 60.0
			gi.visibility_range_end_margin = 6.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		for gi in lod1.find_children("*", "GeometryInstance3D", true, false):
			gi.visibility_range_begin = 60.0
			gi.visibility_range_begin_margin = 6.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var base: Node3D = lod0 if lod0 != null else root
	var turret: Node3D = base.find_child("Turret", true, false) as Node3D
	if turret != null:
		turret.set_meta("axis", Vector3.UP)
	var axles := []
	for part in base.find_children("*", "Node3D", true, false):
		var n: String = part.name
		if (n.begins_with("Wheel_") or n.begins_with("Sprocket_") or n.begins_with("Idler_") or n.begins_with("Roller_")) and not n.ends_with("_Mesh"):
			# The wheel's own radius from its mesh, so it rolls as fast as the ground goes under it.
			var radius := 0.4
			for child in part.get_children():
				if child is MeshInstance3D:
					var wb: AABB = child.get_aabb()
					radius = maxf(maxf(wb.size.y, wb.size.z) * 0.5 * absf(child.scale.y), 0.1)
					break
			axles.append({"node": part, "radius": radius})
	# The track pads: the shader moves them round the loop by `track_u` (shaders/vehicle.gdshader).
	var tracks := []
	var track_loop := 16.5   # metres round the loop: the canonical loop, times the scale the model gives its track meshes
	for mi in root.find_children("Track_*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("track_on", 1.0)
		tracks.append(mi)
		track_loop = 16.5 * absf(mi.scale.z)
	var muzzle_dist := 4.4
	var gun: Node3D = base.find_child("Gun", true, false) as Node3D
	var muzzle: Node3D = base.find_child("Muzzle", true, false) as Node3D
	if muzzle != null and gun != null:
		muzzle_dist = (gun.transform * muzzle.transform).origin.length()   # from the turret's pivot to the gun's tip
	return {"root": root, "turret": turret, "radar": null, "axles": axles, "muzzle": muzzle_dist, "gun": gun, "tracks": tracks, "track_loop": track_loop, "wreck": wreck, "model_file": path}
