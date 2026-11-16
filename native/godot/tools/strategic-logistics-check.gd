
extends SceneTree

const Air := preload("res://scripts/air_operations.gd")
const Kit := preload("res://tools/test_kit.gd")

var world: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + message)

func run() -> void:
	seed(41)
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
	Kit.quiet(world)
	for resource in ["iron", "silicon", "uranium"]:
		world.economy.res[resource] = 1000.0
	for key in world.research.discoveries:
		world.research.progress[key] = {"stage": 3}
	world.research._recompute()
	var home: Vector3 = world.start
	var sea = world.water_near(home, 300)
	if sea == null:
		check(false, "fixture needs open sea")
		quit(1)
		return
	var ms: Node = world.missiles
	var silo: Dictionary = world.place_building("missileSilo", home + Vector3(28, 0, 16), 0, true)
	var complex: Dictionary = world.place_building("strategicComplex", home + Vector3(-32, 0, 12), 0, true)
	var shipyard: Dictionary = world.place_building("shipyard", sea, 0, true)
	var comm_port: Dictionary = world.place_building("port", sea + Vector3(95, 0, 0), 0, true)
	var depot: Dictionary = world.place_building("ammoDepot", home + Vector3(12, 0, -24), 0, true)
	var farm: Dictionary = world.place_building("farm", home + Vector3(48, 0, 24), 0, true)
	var house: Dictionary = world.place_building("residential", home + Vector3(56, 0, 24), 0, true)
	var sub: Dictionary = world.spawn_unit("nuclearSub", sea + Vector3(5, 0, 0), 0)
	var ship: Dictionary = world.spawn_unit("destroyer", sea + Vector3(9, 0, 0), 0)
	var sea_far_sub: Dictionary = world.spawn_unit("nuclearSub", sea + Vector3(220, 0, 0), 0)
	for site in [silo, complex, shipyard, comm_port, depot, farm, house]:
		site.supplied = true
	check(ms.storage_slots(farm) == 0 and not ms.storage_accepts(farm, "nuke"), "farm cannot store nuclear/tactical weapons")
	check(ms.storage_slots(house) == 0 and not ms.storage_accepts(house, "tactical"), "residential building cannot store weapons")
	check(ms.storage_slots(comm_port) == 0 and not ms.storage_accepts(comm_port, "nuke"), "commercial port cannot store warheads")
	check(ms.storage_slots(depot) > 0 and ms.storage_accepts(depot, "nuke") and ms.storage_accepts(depot, "chemical"), "ammoDepot accepts unconventional warheads for storage")
	check(ms.quick_load_onto(sea_far_sub, "nuke", 1, complex) != "", "open-ocean submarine away from Shipyard cannot load nuclear weapons")
	var production: String = ms.produce(silo, "tactical")
	check(production == "", "production queues a tactical missile (%s)" % production)
	check(ms.local_count(silo, "tactical") == 0, "queued weapon unavailable before completion")
	silo.queue_prog = 0.999
	world.update_training(10.0)
	check(ms.local_count(silo, "tactical") == 1 and ms.total_for("tactical") == 1, "training credits only the producing silo")
	check(ms.launch_from("tactical", home, 0, ship).has("error"), "empty surface launcher cannot borrow from silo")
	var transfer: String = ms.start_transfer(silo, shipyard, "tactical")
	check(transfer == "", "silo to shipyard transfer starts (%s)" % transfer)
	if transfer != "":
		quit(1)
		return
	var job: Dictionary = ms.transfers[0]
	var shipment_id := int(job.id)
	var remaining := float(job.remaining)
	shipyard.supplied = false
	ms._update_transfers(5.0)
	check(is_equal_approx(job.remaining, remaining), "cut supply pauses the shipment")
	shipyard.supplied = true
	ms._update_transfers(1.0)
	check(ms.local_count(silo, "tactical") == 0 and ms.local_count(shipyard, "tactical") == 0 and ms.total_for("tactical") == 1, "in-transit weapon counted once")
	remaining = float(job.remaining)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(world.saves.capture()))
	world.saves.restore(snapshot)
	ms = world.missiles
	job = ms.transfer_job(shipment_id)
	check(is_equal_approx(float(job.remaining), remaining) and ms.total_for("tactical") == 1, "shipment ID, progress and quantity restored")
	silo = job.source
	shipyard = job.destination
	shipyard.supplied = true
	silo.supplied = true
	ms._update_transfers(120.0)
	check(ms.local_count(shipyard, "tactical") == 1 and ms.transfers.is_empty(), "shipment delivered to its reserved destination")
	ship = world.units.filter(func(u): return not u.dead and u.owner == 0 and u.key == "destroyer")[-1]
	sub = world.units.filter(func(u): return not u.dead and u.owner == 0 and u.key == "nuclearSub" and u.node.position.distance_to(shipyard.node.position) < 60.0)[0]
	check(ms.start_transfer(shipyard, ship, "tactical") == "", "a stopped compatible ship can load at the shipyard")
	ship.target = ship.node.position + Vector3(100, 0, 0)
	ms._update_transfers(2.0)
	check(ms.transfers.is_empty() and ms.local_count(shipyard, "tactical") == 1 and ms.local_count(ship, "tactical") == 0, "departure during loading returns the weapon to shipyard")
	ship.target = null
	check(ms.start_transfer(shipyard, ship, "tactical") == "", "loading can be reissued")
	ms._update_transfers(20.0)
	check(ms.local_count(ship, "tactical") == 1 and ms.local_count(shipyard, "tactical") == 0, "completed loading moves the weapon onto the ship")
	var launched: Dictionary = ms.launch_from("tactical", home, 0, ship)
	check(not launched.has("error") and ms.local_count(ship, "tactical") == 0 and ms.total_for("tactical") == 0, "ship launches exactly one carried missile")
	check(ms.launch_from("tactical", home, 0, ship).has("error"), "second launch cannot consume the same missile again")

	# Legacy inventory is assigned to facilities first and overflow remains recoverable.
	ms.restore({"stock": {"nuke": 3}})
	complex = world.buildings.filter(func(b): return b.owner == 0 and b.key == "strategicComplex")[-1]
	check(ms.local_count(complex, "nuke") == 2 and int(ms.unassigned.get("nuke", 0)) == 1, "legacy inventory fills the complex and preserves the excess")
	check(ms.ready_platforms("nuke").has(complex) and not ms.ready_platforms("nuke").has(sub), "empty submarine has no launch-ready weapon")
	complex.supplied = true
	depot = world.buildings.filter(func(b): return b.owner == 0 and b.key == "ammoDepot")[-1]
	depot.supplied = true
	var green_dests: Array = ms.valid_destinations(complex, "nuke", 1)
	check(green_dests.any(func(d): return is_same(d, depot)), "green placement highlights ammoDepot as valid storage")
	check(green_dests.any(func(d): return is_same(d, sub)), "green placement highlights shipyard-docked submarine as valid launcher")
	check(not green_dests.any(func(d): return d.key in ["farm", "residential", "port"]), "green placement never includes farms, houses, or commercial ports")
	check(ms.start_transfer(complex, shipyard, "nuke", 2) == "", "complex sends a nuclear payload to the shipyard")
	ms._update_transfers(120.0)
	var sub_load_err: String = ms.start_transfer(shipyard, sub, "nuke", 2)
	check(sub_load_err == "", "submarine can load a compatible payload (%s)" % sub_load_err)
	ms._update_transfers(20.0)
	check(ms.ready_platforms("nuke").has(sub), "submarine carries a launch-ready payload")
	world.defcon.authorise_release()
	var sub_shot: Dictionary = ms.launch_from("nuke", home, 0, sub)
	check(not sub_shot.has("error") and ms.local_count(sub, "nuke") == 1, "submarine launches a weapon from its own loaded inventory")
	world.kill(sub)
	check(ms.total_for("nuke") == 1, "sinking the loaded submarine removes its remaining payload only")
	ms.finished("nuke", complex)
	check(ms.start_transfer(complex, depot, "nuke", 1) == "", "nuclear warhead transfers from complex to ammoDepot")
	ms._update_transfers(120.0)
	check(ms.local_count(depot, "nuke") == 1, "ammoDepot stores transferred nuclear warhead")
	var nuke_before_destroy: int = ms.total_for("nuke")
	world.destroy_building(depot)
	check(ms.local_count(depot, "nuke") == 0 and ms.total_for("nuke") == nuke_before_destroy - 1, "destroying ammoDepot destroys all warheads stored inside")

	var field: Dictionary = world.place_building("airfield", home + Vector3(25, 0, -40), 0, true)
	var forward: Dictionary = world.place_building("airfield", home + Vector3(245, 0, -40), 0, true)
	field.supplied = true
	forward.supplied = true
	var bomber: Dictionary = world.spawn_unit("bomber", field.node.position, 0)
	check(Air.park_new(world, bomber, field), "bomber has a reserved parking slot")
	check(Air.mission_blocked(world, bomber, field.node.position + Vector3(70, 0, 0)) == "", "nearby round trip is allowed")
	check(Air.mission_blocked(world, bomber, field.node.position + Vector3(10000, 0, 0)) != "", "far destination rejected")
	world.order_move([bomber], forward.node.position)
	check(bomber.air_state == "taxi_out" and bomber.ferrying and is_same(bomber.air_base, forward), "normal move to airfield reserves arrival and starts from source runway")
	for i in range(3000):
		world.game_time += 0.05
		world.move_craft(bomber, 0.05)
		if bomber.dead or bomber.air_state == "parked":
			break
	check(not bomber.dead and bomber.air_state == "parked" and is_same(bomber.air_base, forward), "ferry completes taxi, takeoff, landing and service")
	# An air-delivered payload stays in inventory until the aircraft reaches release range.
	ms.finished("tacticalNuke", complex)
	check(ms.start_transfer(complex, forward, "tacticalNuke") == "", "air-delivered payload can be sent to the forward airfield")
	ms._update_transfers(120.0)
	check(ms.start_transfer(forward, bomber, "tacticalNuke") == "", "parked bomber can load at its current airfield")
	ms._update_transfers(20.0)
	world.defcon.authorise_release()
	var aim: Vector3 = forward.node.position + Vector3(85, 0, 75)
	var assigned: Dictionary = ms.launch_from("tacticalNuke", aim, 0, bomber)
	check(assigned.get("pending", false) and ms.local_count(bomber, "tacticalNuke") == 1, "air launch order reserves the payload without spending it (%s)" % str(assigned))
	world.order_move([bomber], forward.node.position)
	check(not bomber.has("payload_order") and ms.local_count(bomber, "tacticalNuke") == 1, "cancelling a sortie preserves its payload")
	assigned = ms.launch_from("tacticalNuke", aim, 0, bomber)
	check(assigned.get("pending", false), "cancelled air sortie can be reissued (%s)" % str(assigned))
	for i in range(3000):
		world.game_time += 0.05
		world.move_craft(bomber, 0.05)
		ms._update_air_payloads()
		if bomber.dead or not bomber.has("payload_order"):
			break
	check(not bomber.dead and ms.local_count(bomber, "tacticalNuke") == 0 and ms.flying.any(func(m): return m.type == "tacticalNuke"), "aircraft releases only after reaching its target area")
	var scout: Dictionary = world.spawn_unit("jet", field.node.position, 0)
	check(Air.park_new(world, scout, field), "patrol fighter has a departure slot")
	ms.stock["antiRadar"] = 1
	var conventional: Dictionary = ms.launch_from("antiRadar", field.node.position + Vector3(80, 0, 55), 0, scout)
	check(conventional.get("pending", false) and ms.stock.antiRadar == 1 and ms.pooled_available("antiRadar") == 0, "air-launched conventional missile also requires a feasible flight and reserves its stock")
	world.order_move([scout], field.node.position)
	check(not scout.has("payload_order") and ms.pooled_available("antiRadar") == 1, "cancelling a conventional flight releases its reservation")
	world.order_patrol([scout], field.node.position + Vector3(85, 0, 65))
	check(scout.has("patrol") and float(scout.patrol.remaining) > 0.0, "patrol plans time on station from its fuel budget")
	var reached_station := false
	for i in range(2800):
		world.game_time += 0.05
		world.move_craft(scout, 0.05)
		if scout.has("patrol"):
			reached_station = reached_station or scout.patrol.on_station
		else:
			break
	check(reached_station and not scout.dead and scout.air_state == "returning", "patrol reaches its station and returns before running out of fuel")

	var enemy_sites: Array = world.buildings.filter(func(b): return not b.dead and b.owner == 1 and b.key == "hq")
	if not enemy_sites.is_empty() and ms.available_to(1, "tactical"):
		var enemy_silo: Dictionary = world.place_building("missileSilo", enemy_sites[0].node.position + Vector3(22, 0, 20), 1, true)
		enemy_silo.supplied = true
		check(ms.queue_rival_payload(1, "tactical") and ms.ready_platforms("tactical", 1).is_empty(), "rival pays to produce before its silo is launch-ready")
		enemy_silo.queue_prog = 0.999
		world.update_training(10.0)
		check(ms.local_count(enemy_silo, "tactical") == 1, "rival's completed order goes into its own local stock")
		var rival: Dictionary = ms.launch_from("tactical", home, 1, enemy_silo)
		check(not rival.has("error") and ms.local_count(enemy_silo, "tactical") == 0, "rival launch consumes its own inventory")
	else:
		check(false, "fixture needs a rival that fields tactical missiles")

	# Routed two-stage air transfer, special CBRN local storage/destruction, and Strategic Arsenal UI
	var depot2: Dictionary = world.place_building("ammoDepot", home + Vector3(-18, 0, -28), 0, true)
	depot2.supplied = true
	var lab: Dictionary = world.place_building("specialLab", home + Vector3(-42, 0, -20), 0, true)
	lab.supplied = true
	ms.finished("chemical", lab)
	check(ms.local_count(lab, "chemical") == 1, "specialLab stores finished chemical warhead locally")
	check(ms.transfer_or_load(lab, depot2, "chemical", 1) == "", "specialLab can transfer chemical warhead to ammoDepot")
	ms._update_transfers(120.0)
	check(ms.local_count(depot2, "chemical") == 1, "chemical warhead arrived in ammoDepot storage")

	# Airborne bomber cannot load while flying; parked bomber receives routed two-stage transfer via airfield
	bomber.air_state = "ready"
	ms.finished("tacticalNuke", complex)
	check(ms.transfer_or_load(complex, bomber, "tacticalNuke", 1) != "", "flying bomber cannot load warheads")
	bomber.air_state = "parked"
	bomber.air_base = forward
	check(ms.transfer_or_load(complex, bomber, "tacticalNuke", 1) == "", "parked bomber accepts routed two-stage warhead transfer")
	ms._update_transfers(200.0)
	check(ms.local_count(bomber, "tacticalNuke") == 1, "parked bomber receives warhead after transit + runway load")

	# Strategic Arsenal panel opens with green map pick, Show focus, and portrait cards; carrier destruction purges payload
	world.begin_payload_transfer(depot2, "chemical")
	check(not world.payload_pick.is_empty() and ms.valid_destinations(depot2, "chemical", 1).size() > 0, "green placement mode highlights valid destinations")
	world.hud.toggle_panel("ordnance", true)
	await process_frame
	check(world.hud._win.visible and world.hud._side_rows.get_child_count() > 2, "Strategic Arsenal panel renders owned weapons and green banner")
	world.hud.focus_asset(bomber)
	var cam_xz := Vector2(world.cam_focus.x - bomber.node.position.x, world.cam_focus.z - bomber.node.position.z).length()
	check(bomber.selected and cam_xz < 5.0, "Show button centers camera and selects carrier unit (xz=%.1f)" % cam_xz)
	world.cancel_payload_transfer()

	bomber.air_state = "ready"
	bomber.sortie_left = 0.001
	Air.update(world, bomber, 1.0)
	check(bomber.dead, "out of fuel in flight loses the aircraft")
	check(ms.local_count(bomber, "tacticalNuke") == 0 and ms.total_for("tacticalNuke") == 0, "destroying loaded bomber destroys its carried tacticalNuke")
	print("STRATEGIC_LOGISTICS %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

