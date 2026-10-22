extends SceneTree
## The glb vehicle models (assets/art/vehicles, scripts/vehicle_models.gd): the file for a nation's tank is found by its name,
## a nation without a model keeps the kit's vehicle, the parts the game moves are all there (turret with its axis, wheels, the
## muzzle at the gun's tip), the model stands on the ground facing +Z at its real size, the turret turns, the wheels roll when the
## tank drives, LOD1 takes over far away, and the model is left out of the way when it is shot (the turret can be thrown).
var errors: Array[String] = []
var passed := 0
var w: Node
const VM := preload("res://scripts/vehicle_models.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	seed(9)
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
	check(VM.slug("M1A2 SEPv3 Abrams") == "m1a2_sepv3_abrams" and VM.slug("T-62 / T-72 (captured)") == "t_62_t_72_captured" and VM.slug("VT-4 / Vickers Mk 3") == "vt_4_vickers_mk_3", "the file slug follows the roster's rule")
	w.map.nations[0]["id"] = "usa"
	var path: String = VM.path_for(w, 0, "tank")
	check(path.ends_with("tank__m1a2_sepv3_abrams.glb"), "the American tank is found by its name (%s)" % path)
	w.map.nations[1]["id"] = "france"   # (the one nation whose tank has no model yet)
	check(VM.path_for(w, 1, "tank") == "", "a nation whose model is not made yet has no file (%s)" % VM.path_for(w, 1, "tank"))
	var u: Dictionary = w.spawn_unit("tank", w.land_point(w.start + Vector3(30, 0, 30), 30.0), 0)
	var built: Dictionary = VM.build(w, "tank", 0)
	check(not built.is_empty() and built.turret != null and built.turret.name == "Turret", "the model has its turret")
	check(built.turret.get_meta("axis") == Vector3.UP, "which turns about the vertical")
	check(built.axles.size() >= 18, "the running gear is there: %d wheels, sprockets, idlers and rollers" % built.axles.size())
	check(float(built.muzzle) > 5.0 and float(built.muzzle) < 6.5, "the muzzle is at the gun's tip (%.1f m from the turret)" % float(built.muzzle))
	var bounds: AABB = w.model_bounds(built.root.get_node("LOD0"))
	check(absf(bounds.position.y) < 0.05 and bounds.size.z > 9.0 and bounds.size.z < 10.5 and bounds.size.x < 4.0, "it stands on the ground at its real size (%s)" % str(bounds.size))
	var forward: float = bounds.end.z
	check(forward > 5.0 and bounds.position.z > -4.5, "and the gun points along +Z (the front is +Z: %.1f to %.1f)" % [bounds.position.z, bounds.end.z])
	check(built.wreck != null and not built.wreck.visible and built.root.get_node_or_null("Collision_Box") == null, "the burnt-out copy is kept hidden for the tank's death and the collision box is left out")
	check(built.tracks.size() >= 4 and built.tracks.all(func(t): return t.get_instance_shader_parameter("track_on") > 0.5), "the track pads of both detail levels are marked to run round their loop (%d)" % built.tracks.size())
	# in the game
	check(u.model.get_node_or_null("LOD0") != null and u.turret != null and u.axles.size() >= 18, "a tank spawned in the game uses the model (%d moving parts)" % u.axles.size())
	var other: Dictionary = w.spawn_unit("tank", w.land_point(w.start + Vector3(40, 0, 30), 30.0), 1)
	check(other.model.get_node_or_null("LOD0") == null, "a nation without a model keeps the kit's tank")
	# the turret and wheels (the camera is near: the fine animation runs only within 70 m of it)
	w.cam_focus = u.node.position; w.cam_dist = 20.0; w.cam_dist_target = 20.0; w.cam_ground = INF; w.update_camera(1.0)
	w.set_physics_process(true)
	var yaw0: float = u.turret_yaw
	var wheel: Dictionary = u.axles[0]
	var r0: float = wheel.node.rotation.x
	u.moving = true
	u.cur_speed = 6.0
	for i in range(60): await physics_frame
	check(absf(wheel.node.rotation.x - r0) > 0.05, "the wheels roll as the tank drives (%.1f rad)" % absf(wheel.node.rotation.x - r0))
	var d: Dictionary = w.spawn_unit("soldier", u.node.position + Vector3(0, 0, 20), 1)
	u.moving = false
	w.diplomacy.declare_war(0, 1)
	u.enemy = d
	for i in range(90): await physics_frame
	check(absf(u.turret_yaw) < 3.2 and absf(u.turret_yaw - yaw0) > 0.0 or absf(u.turret_yaw) < 0.3, "the turret follows the target")
	# the gun lifts to a far target and kicks back
	var far: Dictionary = w.spawn_unit("soldier", u.node.position + Vector3(0, 0, 55), 1)
	u.enemy = far
	for i in range(90): await physics_frame
	check(u.gun.rotation.x < -0.01, "the gun lifts to a target 55 m away (%.3f rad)" % -u.gun.rotation.x)
	u.gun_kick = 1.0
	w.cam_focus = u.node.position; w.update_camera(1.0)
	await physics_frame
	check(u.gun.position.z < u.gun_base.z - 0.1, "and kicks back when it fires (%.2f m)" % (u.gun_base.z - u.gun.position.z))
	w.kill(far); w.kill(d)   # (nothing left to shoot at, so it does not fire again)
	u.enemy = null
	for i in range(150): await physics_frame
	check(absf(u.gun.position.z - u.gun_base.z) < 0.01, "then returns (%.3f m off)" % absf(u.gun.position.z - u.gun_base.z))
	check(absf(float(u.get("track_u", 0.0))) > 0.0, "the track pads ran along their loop while it drove (%.3f of the loop)" % float(u.get("track_u", 0.0)))
	# death: the turret flies off for some
	w.set_physics_process(false)
	w.kill(u)
	check(u.dead and u.wreck.visible and not u.model.get_node("LOD0").visible, "the tank can be destroyed: its burnt-out copy replaces it")
	print("VEHICLE_MODEL %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("VEHICLE_MODEL %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
