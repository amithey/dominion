extends SceneTree

const Air := preload("res://scripts/airlift.gd")
const AirOps := preload("res://scripts/air_operations.gd")
const Kit := preload("res://tools/test_kit.gd")

var world: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + msg)

func _step_world(seconds: float, dt := 0.05) -> void:
	var steps := int(round(seconds / dt))
	for i in range(steps):
		world._physics_process(dt)

func run() -> void:
	seed(77)
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true:
			world = current_scene
			break
	if world == null:
		quit(1)
		return
	world.start_match("easy")
	paused = true
	world.saves.autosave_every = 0
	Kit.quiet(world, ["defcon"])
	world.economy.grant_test_resources()
	for key in world.research.discoveries:
		world.research.progress[key] = {"stage": 3}
	world.research._recompute()

	var home: Vector3 = world.start
	var pad_at = world.test_site("helipad", home)
	var pad: Dictionary = world.place_building("helipad", pad_at, 0, true)
	world.close_navigation(pad.root.position, world.DISTRICT_NAV_SIZE)
	pad.supplied = true

	# 1. Helicopter parked on helipad + soldiers outside helipad -> order_board must embark them!
	var heli: Dictionary = world.spawn_unit("helicopter", pad.root.position, 0)
	check(AirOps.park_new(world, heli, pad), "helicopter parked on helipad")
	var soldiers := []
	for i in range(3):
		var s: Dictionary = world.spawn_unit("soldier", pad.root.position + Vector3(24.0 + i * 2.0, 0, 0), 0)
		soldiers.append(s)
	var ordered := Air.order_board(world, soldiers, heli)
	check(ordered == 3, "order_board accepts 3 soldiers for parked helicopter (%d)" % ordered)
	for i in range(240):
		_step_world(0.1)
		if heli.get("cargo", []).size() == 3:
			break
	check(heli.get("cargo", []).size() == 3, "soldiers boarded helicopter parked on helipad (%d/3)" % heli.get("cargo", []).size())

	# 2. Fly to distant battlefield and unload via order_unload_at (Land at...)
	var battle_spot: Vector3 = world.land_point(home, 140.0)
	check(Air.order_unload_at(world, heli, battle_spot), "order_unload_at accepts battlefield destination")
	for i in range(400):
		_step_world(0.1)
		if heli.get("cargo", []).is_empty() and heli.get("unload_go") == null:
			break
	check(heli.get("cargo", []).is_empty(), "helicopter arrived at battlefield and unloaded all 3 soldiers")
	var field_soldiers: Array = world.units.filter(func(u): return not u.dead and u.owner == 0 and u.key == "soldier" and not u.get("stowed", false) and u.node.position.distance_to(battle_spot) < 60.0)
	check(field_soldiers.size() >= 3, "3 unloaded soldiers standing in battlefield (%d)" % field_soldiers.size())

	# 3. Exhaust helicopter's rocket ammo -> must NOT force helicopter to abandon battlefield!
	while int(heli.ammo) > 0:
		AirOps.consume(heli)
	_step_world(1.0)
	check(heli.air_state == "ready", "helicopter with 0 rocket ammo stays ready for troop transport (state=%s)" % str(heli.air_state))

	# 4. Fly helicopter away (or back near base) and extract soldiers from battlefield via order_pickup_at!
	heli.node.position = pad.root.position + Vector3(0, heli.altitude, 0)
	heli.target = null
	check(Air.order_pickup_at(world, heli, battle_spot), "order_pickup_at sends helicopter to extract battlefield troops")
	for i in range(450):
		_step_world(0.1)
		if heli.get("cargo", []).size() >= 3:
			break
	check(heli.get("cargo", []).size() >= 3, "helicopter extracted battlefield troops back aboard (%d)" % heli.get("cargo", []).size())

	# 5. Return & Unload at Base -> unloads troops near home base and lands helicopter!
	check(Air.order_return_home(world, [heli]) == 1, "order_return_home accepted")
	for i in range(450):
		_step_world(0.1)
		if heli.get("cargo", []).is_empty() and heli.get("unload_go") == null:
			break
	check(heli.get("cargo", []).is_empty(), "Return & Unload at Base unloaded troops near home base")
	var home_soldiers: Array = world.units.filter(func(u): return not u.dead and u.owner == 0 and u.key == "soldier" and not u.get("stowed", false) and u.node.position.distance_to(pad.root.position) < 65.0)
	check(home_soldiers.size() >= 3, "extracted soldiers are safely back at home base (%d)" % home_soldiers.size())

	# 6. Nuclear warheads loading onto Submarine, Nuclear Submarine, and Destroyer / Cruiser!
	var ms: Node = world.missiles
	var sea = world.water_near(home, 300)
	check(sea != null, "open sea found for naval nuclear loading")
	var complex_at = world.test_site("strategicComplex", home)
	var complex: Dictionary = world.place_building("strategicComplex", complex_at, 0, true)
	complex.supplied = true
	var sub_tac: Dictionary = world.spawn_unit("submarine", sea, 0)
	var sub_nuc: Dictionary = world.spawn_unit("nuclearSub", sea + Vector3(8, 0, 0), 0)
	var ship_dd: Dictionary = world.spawn_unit("destroyer", sea + Vector3(16, 0, 0), 0)
	var nuke_key := "tacticalNuke" if ms.available_to(0, "tacticalNuke") else "nuke"
	ms.finished(nuke_key, complex)
	ms.finished(nuke_key, complex)
	ms.finished("nuke", complex)
	check(ms.quick_load_onto(sub_tac, nuke_key, 1) == "", "quick_load_onto loads %s onto Submarine" % nuke_key)
	check(ms.quick_load_onto(ship_dd, nuke_key, 1) == "", "quick_load_onto loads %s onto Destroyer" % nuke_key)
	check(ms.quick_load_onto(sub_nuc, "nuke", 1) == "", "quick_load_onto loads nuke onto Nuclear Submarine")
	ms._update_transfers(30.0)
	check(ms.local_count(sub_tac, nuke_key) == 1, "Submarine holds loaded %s" % nuke_key)
	check(ms.local_count(ship_dd, nuke_key) == 1, "Destroyer holds loaded %s" % nuke_key)
	check(ms.local_count(sub_nuc, "nuke") == 1, "Nuclear Submarine holds loaded nuke")

	world.defcon.authorise_release()
	check(not ms.launch_from(nuke_key, home + Vector3(60, 0, 60), 0, sub_tac).has("error"), "Submarine launches loaded %s" % nuke_key)
	check(not ms.launch_from(nuke_key, home + Vector3(60, 0, 60), 0, ship_dd).has("error"), "Destroyer launches loaded %s" % nuke_key)
	check(not ms.launch_from("nuke", home + Vector3(60, 0, 60), 0, sub_nuc).has("error"), "Nuclear Submarine launches loaded nuke")

	# 7. Nuclear & Ordnance UI panels open cleanly
	world.hud.toggle_panel("ordnance", true)
	await process_frame
	check(world.hud._win.visible and world.hud._side_rows.get_child_count() > 0, "Ordnance (Warheads & Stock) panel opens cleanly")
	world.hud.toggle_panel("defence", true)
	await process_frame
	check(world.hud._win.visible and world.hud._side_rows.get_child_count() > 0, "Command / Nuclear DEFCON panel opens cleanly")

	print("AIRLIFT_AND_NUKES %s (%d/%d checks)" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	quit(0 if failures == 0 else 1)
