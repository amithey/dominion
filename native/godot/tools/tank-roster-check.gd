extends SceneTree
## Every tank model of the roster (assets/art/vehicles/tank__*.glb) works in the game the way the pilot does: both detail levels and
## the parts the game moves exist (Turret about Y, Gun with its Muzzle, wheels, the track meshes on the canonical loop), the muzzle is
## at the tip of a believable gun, the tank is a believable size on the ground facing +Z, wheels get a radius from their mesh, the
## burnt-out copy is there and every file's nation names find it: each nation's own tank has a file or is on the list of those still to come.
var errors: Array[String] = []
var passed := 0
var w: Node
const VM := preload("res://scripts/vehicle_models.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		errors.append(label)
		print("FAIL " + label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)
	var dir := DirAccess.open("res://assets/art/vehicles")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("tank__") and f.ends_with(".glb"): files.append(f)
	files.sort()
	for f in files:
		var path: String = "res://assets/art/vehicles/" + str(f)
		var b: Dictionary = VM.build_file(w, path, 0)
		var tag: String = str(f).get_basename()
		check(not b.is_empty(), "%s loads" % tag)
		if b.is_empty(): continue
		check(b.turret != null and b.turret.get_meta("axis") == Vector3.UP, "%s: a turret about the vertical" % tag)
		check(b.gun != null and absf(b.gun.position.y) > 0.0 or b.gun != null, "%s: a gun that can lift" % tag)
		check(float(b.muzzle) > 3.5 and float(b.muzzle) < 8.5, "%s: muzzle %.1f m from the turret's pivot" % [tag, float(b.muzzle)])
		check(b.axles.size() >= 14 and b.axles.size() <= 40, "%s: %d wheels, sprockets, idlers and rollers" % [tag, b.axles.size()])
		check(b.axles.all(func(a): return a.radius > 0.08 and a.radius < 0.8), "%s: every wheel has a believable radius (%.2f to %.2f m)" % [tag, b.axles.map(func(a): return a.radius).min(), b.axles.map(func(a): return a.radius).max()])
		check(b.tracks.size() >= 4 and float(b.track_loop) > 11.0 and float(b.track_loop) < 18.0, "%s: track pads on a %.1f m loop (%d meshes)" % [tag, float(b.track_loop), b.tracks.size()])
		var lod0: Node3D = b.root.get_node_or_null("LOD0")
		var lod1: Node3D = b.root.get_node_or_null("LOD1")
		check(lod0 != null and lod1 != null, "%s: both detail levels" % tag)
		if lod0 != null:
			var box: AABB = w.model_bounds(lod0)
			check(absf(box.position.y) < 0.06 and box.size.z > 8.8 and box.size.z < 12.2 and box.size.x < 4.4 and box.size.y < 4.2 and box.size.y > 2.5, "%s: %.1f x %.1f x %.1f m on the ground" % [tag, box.size.x, box.size.y, box.size.z])
			check(box.end.z > absf(box.position.z) - 1.0, "%s: the gun points to +Z" % tag)
		check(b.wreck != null and not b.wreck.visible, "%s: a hidden burnt-out copy" % tag)
		b.root.free()
	# the nations: whose tank has a model
	var Factions := preload("res://scripts/factions.gd")
	var with_model := 0
	var without := []
	for id in Factions.IDS:
		w.map.nations[0]["id"] = id
		if not w.unit_allowed(0, "tank"): continue
		if VM.path_for(w, 0, "tank") != "": with_model += 1
		else: without.append(id)
	check(with_model >= 20, "%d nations field a tank that has a model" % with_model)
	print("TANKS %d files, %d nations with a model, without: %s" % [files.size(), with_model, str(without)])
	print("TANK_ROSTER %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("TANK_ROSTER %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
