extends SceneTree
## Tests secondary orders against every registered unit and writes the per-unit table.
const Kit := preload("res://tools/audit_kit.gd")
const Lift := preload("res://scripts/airlift.gd")
const Garrison := preload("res://scripts/urban_garrison.gd")
const Tools := preload("res://scripts/war_tools.gd")
const Brief := preload("res://scripts/brief.gd")

var audit
var w: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	audit = Kit.new(self, "unit-secondary")
	w = await audit.boot({"map": "island", "players": 3, "nation": 0})
	if w == null:
		quit(audit.finish())
		return
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var land: Vector3 = w.land_point(hq.root.position, 78.0)
	var sea: Vector3 = w.water_near(hq.root.position, 240)
	w.place_building("airfield", land + Vector3(20, 0, 0), 0, true)
	w.place_building("helipad", land - Vector3(20, 0, 0), 0, true)
	var heli: Dictionary = w.spawn_unit("helicopter", land, 0)
	var heavy: Dictionary = w.spawn_unit("heavyLift", land, 0)
	var ship: Dictionary = w.spawn_unit("landingShip", sea, 0)
	var carrier: Dictionary = w.spawn_unit("carrier", sea, 0)
	var keys: Array = w.unit_defs.keys()
	keys.sort()
	for key in keys:
		var def: Dictionary = w.unit_defs[key]
		var carrier_wing: bool = key in ["carrierJet", "carrierDrone"]
		var unit: Dictionary = w.spawn_unit(key, sea if def.get("naval", false) or carrier_wing else land, 0)
		if unit.is_empty():
			audit.fail("spawn", key, "could not create unit")
			continue
		if carrier_wing:
			unit.carrier = carrier
		check_unit(key, unit, hq, heli, heavy, ship)
		w.kill(unit, true)
		audit.clean("script errors", key)
		await process_frame
	check_interrupted_pickup(heli, land)
	check_full_garrison(hq, land)
	audit.clean("script errors", "shared scenarios")
	audit.ok("summary", "all units", "%d registered types exercised" % keys.size())
	quit(audit.finish())

func check_unit(key: String, u: Dictionary, hq: Dictionary, heli: Dictionary, heavy: Dictionary, ship: Dictionary) -> void:
	var land_unit: bool = not u.get("naval", false) and not u.get("fly", false)
	var seats: Array[int] = [Lift.places(w, heli, u), Lift.places(w, heavy, u), Lift.places(w, ship, u)]
	var garrisonable: bool = Garrison.can_garrison(w, u, hq)
	var can_mine: bool = Tools._can_lay_mine(u)
	var bombard: bool = w.can_bombard(u)
	if key in ["interceptorDrone", "maritimePatrol", "navalHelicopter", "coastalASM"]:
		audit.expect(not bombard, "bombard eligibility", key, "unit with no land attack is offered a bombard order")
	var patrol := false
	if u.get("fly", false):
		u.air_state = "ready"
		w.order_patrol([u], u.node.position + Vector3(36, 0, 0))
		patrol = u.has("patrol")
		var autonomous_patrol: bool = not (key in w.AirOperations.TUBE_LAUNCHED) and u.get("carrier") == null
		audit.expect(autonomous_patrol or not patrol, "patrol", key, "disposable or carrier-owned aircraft was cleared to patrol")
	var position: Vector3 = u.node.position
	var unreachable := position + Vector3(100000, 0, 100000)
	if patrol:
		w.order_move([u], unreachable)
		audit.expect(u.has("patrol"), "rejected order", key, "out-of-range move cancelled a patrol")
	var move_point := position + Vector3(0, 0, 42)
	w.order_move([u], move_point)
	audit.expect(not u.has("patrol") and u.get("target") != null, "move override", key, "valid move left the prior patrol active or did not set a target")
	if garrisonable:
		var old_range: float = u.range
		var entered := Garrison.enter(w, u, hq)
		if entered:
			Garrison.exit_unit(w, u, hq)
		audit.expect(entered and u.get("garrison_building") == null and is_equal_approx(float(u.range), old_range),
			"garrison", key, "could not enter and leave cover with its original range")
	audit.expect(land_unit or (not garrisonable and not can_mine and seats == [0, 0, 0]), "terrain eligibility", key,
		"a ship or aircraft can board as cargo, garrison, or lay mines")
	if bombard:
		var aim := position + Vector3(0, 0, 18)
		if w.AirOperations.mission_blocked(w, u, aim, 8.0, w.AirOperations.attack_release_range(u)) == "":
			if garrisonable:
				Garrison.order_garrison(w, [u], hq)
			w.order_bombard([u], aim)
			audit.expect(u.get("ground_attack") == aim and u.get("enemy") != null and not u.has("garrison_order"),
				"bombard order", key, "the ground attack did not replace the move order")
	if seats[0] > 0:
		check_cargo(key, u, heli, seats[0])
	elif seats[1] > 0:
		check_cargo(key, u, heavy, seats[1])
	elif seats[2] > 0:
		check_cargo(key, u, ship, seats[2])
	audit.ok("capabilities", key, "patrol=%s bombard=%s garrison=%s mines=%s seats[heli/heavy/ship]=%s transport=%s" %
		[patrol, bombard, garrisonable, can_mine, str(seats), Lift.is_transport(u)])
	var brief := Brief.unit(w, key)
	audit.ok("role", key, "%s. %s" % [brief.role, " / ".join(PackedStringArray(brief.points))])

func check_cargo(key: String, u: Dictionary, transport: Dictionary, seats: int) -> void:
	u.node.position = transport.node.position
	var before: int = Lift.used(transport)
	audit.expect(Lift.order_board(w, [u], transport) == 1 and Lift.used(transport) == before + seats and u.get("stowed", false),
		"cargo", key, "eligible passenger did not embark with the expected space")
	transport.cargo.clear()

func check_interrupted_pickup(heli: Dictionary, land: Vector3) -> void:
	var soldier: Dictionary = w.spawn_unit("soldier", land + Vector3(26, 0, 0), 0)
	heli.air_state = "ready"
	audit.expect(Lift.order_board(w, [soldier], heli) == 1 and is_same(soldier.get("board"), heli) and heli.has("pickup_go"),
		"pickup setup", "helicopter", "passenger was not asked to wait for pickup")
	w.order_move([heli], land + Vector3(100000, 0, 100000))
	audit.expect(heli.has("pickup_go") and is_same(soldier.get("board"), heli), "rejected move", "helicopter",
		"a move beyond range cancelled the accepted pickup")
	w.order_patrol([heli], land + Vector3(50, 0, 0))
	Lift.update(w)
	audit.expect(heli.has("patrol") and not heli.has("pickup_go") and soldier.get("board") == null, "patrol override", "helicopter",
		"accepted patrol left the pickup active or passengers still waiting to board")

func check_full_garrison(hq: Dictionary, land: Vector3) -> void:
	var squads: Array = []
	for i in range(Garrison.capacity_of(hq) + 1):
		squads.append(w.spawn_unit("soldier", land, 0))
	var first := Garrison.order_garrison(w, squads.slice(0, -1), hq)
	var overflow: Dictionary = squads[-1]
	var extra := Garrison.order_garrison(w, [overflow], hq)
	audit.expect(first == Garrison.capacity_of(hq) and extra == 0 and overflow.get("target") == null,
		"garrison capacity", "soldier", "squad began walking to a building with every place reserved")
	w.order_move([squads[0]], land + Vector3(20, 0, 0))
	audit.expect(Garrison.order_garrison(w, [overflow], hq) == 1,
		"garrison cancellation", "soldier", "a cancelled order did not release its place")
