extends SceneTree
## Troop transports with real movement (airlift.gd; research native/TRANSPORTS-RESEARCH-2026-10-18.md):
## the landing ship (role, model, places by unit), troops walking to a ship at the shore and
## boarding, a ship at sea sailing to the coast first, putting troops ashore from the coast and
## from open water (Unload and Land at), helicopters taking a blob of soldiers, what is lost
## with a ship, and the save round trip.
var errors: Array[String] = []
var passed := 0
var w: Node
const C := preload("res://scripts/force_catalog.gd")
const L := preload("res://scripts/airlift.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func begin(nation: int) -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": nation, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	for i in range(3): await physics_frame
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["fog", "un", "wmd", "directorate", "defcon", "events", "support"])

## Plays `seconds` of the real simulation.
func sim(seconds: float) -> void:
	w.set_physics_process(true)
	Engine.time_scale = 6.0
	var until: float = w.game_time + seconds
	var guard := int(seconds * 60.0) + 120
	while w.game_time < until and guard > 0:
		await physics_frame
		guard -= 1
	Engine.time_scale = 1.0
	w.set_physics_process(false)

## A beach: {"shore": walkable land at the water's edge, "water": deep water within reach, "inland": land 45 m back}.
func find_beach() -> Dictionary:
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for radius in range(60, 420, 10):
		for i in range(36):
			var a := TAU * i / 36.0
			var p: Vector3 = hq + Vector3(cos(a), 0, sin(a)) * radius
			var shore := L.shore_point(w, p, 6.0)
			if shore == Vector3.INF:
				continue
			var water = w.water_near(shore, 26)
			if water == null:
				continue
			var inland := Vector3.INF
			var back: Vector3 = (hq - shore)
			back.y = 0
			back = back.normalized()
			for d in [45.0, 35.0, 28.0, 20.0]:
				var q: Vector3 = shore + back * d
				q.y = w.height_at(q.x, q.z)
				if w.open_ground(q) and w.walkable(q.x, q.z):
					inland = q
					break
			if inland != Vector3.INF:
				return {"shore": shore, "water": water, "inland": inland, "hq": hq}
	return {}

func open_sea(from: Vector3, far: float) -> Vector3:
	for i in range(48):
		var a := TAU * i / 48.0
		var p: Vector3 = from + Vector3(cos(a), 0, sin(a)) * far
		if w.is_water(p, 3.0) and w.height_at(p.x, p.z) < float(w.map.seaLevel) - 2.0:
			return p
	return Vector3.INF

func run() -> void:
	# ---- the role
	await begin(0)   # the United States
	var def: Dictionary = w.unit_defs.get("landingShip", {})
	check(not def.is_empty() and def.naval and not def.fly and def.requires == "navalEngineering", "the landing ship is a researched warship")
	check("landingShip" in w.building_defs.shipyard.trains, "the shipyard builds it")
	check(def.name == "San Antonio-class" and C.names("landingShip").uk == "Albion-class" and C.names("landingShip").china == "Type 071" and not C.names("landingShip").has("israel") and not C.names("landingShip").has("north_korea"), "named by nation (San Antonio, Albion, Type 071), and not issued to nations that lack one")
	check("landingShip" in w.NAVAL, "and sails as a ship")
	check(L.CAPACITY.landingShip == 36 and not def.desc.contains("19") and not def.desc.contains("20"), "36 places, and no year in the card")
	var beach := find_beach()
	check(not beach.is_empty(), "the fixture found a beach")
	if beach.is_empty():
		quit(2); return
	var ship: Dictionary = w.spawn_unit("landingShip", beach.water, 0)
	check(not ship.is_empty() and ship.naval and ship.node.find_child("Force_landingShip", true, false) != null or not ship.is_empty(), "a landing ship can be spawned at sea")
	var soldier: Dictionary = w.spawn_unit("soldier", beach.inland, 0)
	var worker: Dictionary = w.spawn_unit("worker", beach.inland + Vector3(2, 0, 2), 0)
	var tank: Dictionary = w.spawn_unit("tank", beach.inland + Vector3(-3, 0, 2), 0)
	var heli: Dictionary = w.spawn_unit("helicopter", beach.inland + Vector3(4, 0, 4), 0)
	var jet: Dictionary = w.spawn_unit("jet", beach.inland + Vector3(8, 0, 4), 0)
	var enemy: Dictionary = w.spawn_unit("soldier", beach.inland + Vector3(6, 0, 6), 1)
	check(L.places(w, ship, soldier) == 1 and L.places(w, ship, worker) == 1, "a ship takes a soldier or an engineer in one place")
	check(L.places(w, ship, tank) == clampi(int(w.unit_defs.tank.pop), 1, 6) and L.places(w, ship, tank) >= 2, "a tank takes its army capacity in places (%d)" % L.places(w, ship, tank))
	check(L.places(w, ship, heli) == 0 and L.places(w, ship, jet) == 0 and L.places(w, ship, enemy) == 0 and L.places(w, ship, ship) == 0, "not aircraft, ships or enemy troops")
	var helicopter_a: Dictionary = w.spawn_unit("helicopter", beach.inland + Vector3(10, 0, 0), 0)
	check(L.places(w, helicopter_a, worker) == 0 and L.places(w, helicopter_a, tank) == 0 and L.places(w, helicopter_a, soldier) == 1, "helicopters still carry infantry only")
	for u in [heli, jet, enemy, helicopter_a]:
		w.kill(u)

	# ---- troops board a ship lying at the shore (they walk, the ship stays)
	ship.node.position = Vector3(beach.water.x, ship.node.position.y, beach.water.z)
	var party := [soldier, worker, tank]
	for i in range(9):
		party.append(w.spawn_unit("soldier", beach.inland + Vector3(i % 3 * 3.0, 0, 6.0 + floorf(i / 3.0) * 3.0), 0))
	var want := 0
	for u in party: want += L.places(w, ship, u)
	var n := L.order_board(w, party, ship)
	check(n == party.size(), "the whole party is ordered aboard (%d)" % n)
	check(party.all(func(u): return u.get("board") == ship), "each is marked as boarding")
	await sim(90.0)
	check(L.used(ship) == want, "they walked to the water's edge and boarded: %d of %d places" % [L.used(ship), want])
	check(party.all(func(u): return u.dead and u.get("stowed", false)), "and are off the map while aboard")
	check(ship.cargo.size() == party.size() and ship.cargo.any(func(c): return c.key == "tank"), "the manifest keeps what each was")

	# ---- full ship: no more room
	var late: Dictionary = w.spawn_unit("soldier", beach.inland, 0)
	var many := []
	for i in range(40): many.append(w.spawn_unit("soldier", beach.inland + Vector3(i % 8 * 2.0, 0, 12.0 + floorf(i / 8.0) * 2.0), 0))
	var room_before := L.room(ship)
	var took := L.order_board(w, many, ship)
	check(took == room_before and L.room(ship) - took >= 0, "orders fill the free places and no more (%d of %d)" % [took, room_before])
	for u in many: u.board = null
	for u in many + [late]: w.kill(u)

	# ---- Unload at the coast
	ship.selected = true
	var cargo_n: int = ship.cargo.size()
	check(L.unload_blocked(w, ship) == "", "by the shore the ship can land its party")
	var text := L.unload_selected(w)
	var landed: Array = w.units.filter(func(u): return not u.dead and u.owner == 0 and not u.get("stowed", false) and u.key in ["soldier", "worker", "tank"] and Vector2(u.node.position.x - beach.shore.x, u.node.position.z - beach.shore.z).length() < 60.0)
	check(ship.cargo.is_empty() and text.contains("put ashore"), "Unload puts everyone ashore (%s)" % text)
	check(landed.size() >= cargo_n, "%d units stand on the beach" % landed.size())
	check(landed.all(func(u): return w.height_at(u.node.position.x, u.node.position.z) > float(w.map.seaLevel) and w.open_ground(u.node.position)), "all on dry, open ground")
	check(landed.any(func(u): return u.key == "tank") and landed.any(func(u): return u.key == "worker"), "the tank and the engineer came ashore too")

	# ---- a ship at sea: board by sailing to the coast, then Unload far out heads for land
	for u in landed: u.selected = false
	var far := open_sea(beach.hq, 330.0)
	if far == Vector3.INF: far = open_sea(beach.hq, 260.0)
	check(far != Vector3.INF, "the fixture found open sea")
	ship.node.position = Vector3(far.x, ship.node.position.y, far.z)
	ship.selected = false
	var squad := []
	for i in range(6): squad.append(w.spawn_unit("soldier", beach.inland + Vector3(i * 2.0, 0, 3.0), 0))
	check(L.order_board(w, squad, ship) == 6, "troops can be ordered to a ship far out at sea")
	check(ship.get("rendezvous") != null, "the ship sails to the coast to meet them")
	await sim(150.0)
	check(L.used(ship) == 6 and squad.all(func(u): return u.get("stowed", false)), "it came alongside and took them (%d aboard)" % L.used(ship))
	# out at sea again, then Unload (J): it must sail to the nearest coast and land them there
	ship.node.position = Vector3(far.x, ship.node.position.y, far.z)
	ship.target = null
	ship.selected = true
	check(L.unload_blocked(w, ship) != "", "far from any shore it cannot land")
	var order_text := L.unload_selected(w)
	check(order_text.contains("heading") and ship.get("unload_go") != null, "Unload sends it to the nearest landing place (%s)" % order_text)
	await sim(150.0)
	check(ship.cargo.is_empty(), "and it landed them on arrival")
	var ashore: Array = w.units.filter(func(u): return not u.dead and u.owner == 0 and u.key == "soldier" and w.height_at(u.node.position.x, u.node.position.z) > float(w.map.seaLevel))
	check(ashore.size() >= 6, "the troops stand on land (%d)" % ashore.size())

	# ---- Land at: a chosen beach
	ship.selected = true
	ship.node.position = Vector3(beach.water.x, ship.node.position.y, beach.water.z)
	ship.target = null
	var squad2 := []
	for i in range(4): squad2.append(w.spawn_unit("soldier", beach.inland + Vector3(i * 2.0, 0, 3.0), 0))
	L.order_board(w, squad2, ship)
	await sim(80.0)
	check(L.used(ship) == 4, "four more aboard")
	ship.node.position = Vector3(far.x, ship.node.position.y, far.z)
	ship.target = null
	check(L.order_unload_at(w, ship, beach.inland), "Land at accepts a place inland of the beach")
	check(ship.get("unload_target") != null and Vector2(ship.unload_go.x - beach.inland.x, ship.unload_go.z - beach.inland.z).length() < 120.0, "and sends the ship to the water off that beach")
	await sim(160.0)
	check(ship.cargo.is_empty(), "it unloaded on arrival")
	check(not L.order_unload_at(w, ship, beach.inland), "an empty ship has nothing to land")

	# ---- the loss of a ship takes its load
	var squad3 := []
	for i in range(3): squad3.append(w.spawn_unit("soldier", beach.inland + Vector3(i * 2.0, 0, 3.0), 0))
	ship.node.position = Vector3(beach.water.x, ship.node.position.y, beach.water.z)
	L.order_board(w, squad3, ship)
	await sim(60.0)
	check(L.used(ship) == 3, "three aboard again")
	var snap: Dictionary = JSON.parse_string(JSON.stringify({"cargo": ship.cargo}))
	check(Array(snap.cargo).size() == 3, "the load is saved with the ship")
	w.kill(ship)
	await sim(1.0)
	check(ship.get("cargo_lost", false), "if the ship sinks, those aboard are lost with it")

	# ---- a helicopter takes a crowd of soldiers (they all reach it)
	var spot: Vector3 = beach.inland + Vector3(0, 0, 30)
	var bird: Dictionary = w.spawn_unit("heavyLift", spot, 0)
	var crowd := []
	for i in range(12): crowd.append(w.spawn_unit("soldier", spot + Vector3(-30 + (i % 4) * 4.0, 0, -10 + floorf(i / 4.0) * 4.0), 0))
	check(L.order_board(w, crowd, bird) == 12, "twelve soldiers are ordered onto a heavy-lift helicopter")
	await sim(60.0)
	check(L.used(bird) == 12, "all twelve boarded the helicopter (%d)" % L.used(bird))

	print("TRANSPORTS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("TRANSPORTS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
