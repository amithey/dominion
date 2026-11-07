extends SceneTree
## Verification suite for all 414 Blender 5.2 LTS Air & Naval models
## (`assets/art/aircraft/*.glb`: 251 files, `assets/art/ships/*.glb`: 163 files)
## loaded and dressed by `scripts/craft_models.gd`.
var errors: Array[String] = []
var passed := 0
var w: Node
const CM := preload("res://scripts/craft_models.gd")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		errors.append(label)
		print("FAIL " + label)

func _glb_files(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".glb"):
			out.append(f)
	out.sort()
	return out

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)

	var air_files := _glb_files("res://assets/art/aircraft")
	var ship_files := _glb_files("res://assets/art/ships")
	check(air_files.size() == 251, "251 aircraft & rotorcraft .glb files present (%d)" % air_files.size())
	check(ship_files.size() == 163, "163 ship & submarine .glb files present (%d)" % ship_files.size())

	# 1. Verify all 251 aircraft & rotorcraft GLBs
	for f in air_files:
		var path: String = "res://assets/art/aircraft/" + str(f)
		var tag: String = str(f).get_basename()
		var role: String = tag.split("__")[0]
		var b: Dictionary = CM.build_file(w, path, 0)
		check(not b.is_empty(), "%s loads" % tag)
		if b.is_empty():
			continue
		check(b.lod0 != null and b.lod1 != null, "%s: both LOD0 and LOD1 exist" % tag)
		check(b.wreck != null and not b.wreck.visible, "%s: hidden Wreck exists" % tag)
		var rb: AABB = b.real_bounds
		check(absf(rb.position.y) < 0.12 and rb.size.z > 0.05 and rb.size.x > 0.05 and rb.size.y > 0.05,
			"%s: real bounds %.2f x %.2f x %.2f m seated near y=0 (%.2f)" % [tag, rb.size.x, rb.size.y, rb.size.z, rb.position.y])
		check(float(b.rts_scale) > 0.05 and float(b.rts_scale) < 20.0, "%s: RTS scale %.3f" % [tag, float(b.rts_scale)])
		var is_heli := role in ["helicopter", "gunship", "navalHelicopter", "heavyLift", "scoutHelicopter"]
		if is_heli:
			check(b.rotor != null, "%s: main rotor pivot exists" % tag)
		if tag.contains("chinook") or tag.contains("ch_47") or tag.contains("mh_47") or tag.contains("h_47") or tag.begins_with("gunship__ka_52") or tag.begins_with("navalHelicopter__ka_"):
			check(b.rotor != null and b.rotor2 != null, "%s: tandem/coaxial dual rotors exist" % tag)
		if b.turret != null:
			check(b.turret.get_meta("axis") == Vector3.UP, "%s: turret turns about Vector3.UP" % tag)
		b.root.free()

	# 2. Verify all 163 warship, carrier & submarine GLBs
	for f in ship_files:
		var path: String = "res://assets/art/ships/" + str(f)
		var tag: String = str(f).get_basename()
		var role: String = tag.split("__")[0]
		var b: Dictionary = CM.build_file(w, path, 0)
		check(not b.is_empty(), "%s loads" % tag)
		if b.is_empty():
			continue
		check(b.lod0 != null and b.lod1 != null, "%s: both LOD0 and LOD1 exist" % tag)
		check(b.wreck != null and not b.wreck.visible, "%s: hidden Wreck exists" % tag)
		var rb: AABB = b.real_bounds
		check(absf(rb.position.y) < 0.15 and rb.size.z > 4.0 and rb.size.x > 1.0 and rb.size.y > 1.0,
			"%s: real naval hull %.1f x %.1f x %.1f m" % [tag, rb.size.x, rb.size.y, rb.size.z])
		var wl: Node3D = b.lod0.find_child("Waterline", true, false) as Node3D
		var hb: Node3D = b.lod0.find_child("Hull_Bow", true, false) as Node3D
		check(wl != null and hb != null and wl.position.y > 0.1 and hb.position.z > 2.0, "%s: Waterline and Hull_Bow markers exist" % tag)
		if role == "carrier":
			var all_deck := true
			for di in range(5):
				if b.root.find_child("DeckPlane%d" % di, true, false) == null:
					all_deck = false
			check(all_deck, "%s: carrier exposes DeckPlane0..DeckPlane4" % tag)
		if b.turret != null:
			check(b.turret.get_meta("axis") == Vector3.UP, "%s: naval turret turns about Vector3.UP" % tag)
		b.root.free()

	# 3. Verify national roster coverage via craft_models.path_for
	var Factions := preload("res://scripts/factions.gd")
	var covered := {}
	for key in ["jet", "stealthFighter", "helicopter", "gunship", "heavyLift", "navalHelicopter", "aewc", "maritimePatrol", "drone", "destroyer", "asFrigate", "corvette", "carrier", "landingShip", "submarine", "nuclearSub"]:
		var have := 0
		var total := 0
		for id in Factions.IDS:
			w.map.nations[0]["id"] = id
			if not w.unit_allowed(0, key):
				continue
			total += 1
			if CM.path_for(w, 0, key) != "":
				have += 1
		covered[key] = "%d of %d" % [have, total]
		check(total == 0 or have * 10 >= total * 8, "%s: %d of %d nations that field it have a model" % [key, have, total])

	print("CRAFT_COVERAGE ", covered)
	print("CRAFT_ROSTER %d passed, %d failed" % [passed, errors.size()])
	for e in errors:
		print("  FAILED: " + e)
	print("CRAFT_ROSTER %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
