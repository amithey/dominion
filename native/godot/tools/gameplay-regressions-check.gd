extends SceneTree
## Regression checks for orders, supply links, national powers and trade agreements.
const Lift := preload("res://scripts/airlift.gd")
const Powers := preload("res://scripts/faction_powers.gd")
const Additional := preload("res://scripts/additional_powers.gd")
class IsolatedTowns extends "res://scripts/logistics.gd":
	var destinations := []
	func plan(start: Vector2i, goal: Vector2i, _owner: int, _kind: String) -> Array:
		destinations.append(goal)
		return [] if destinations.size() == 1 else [start, goal]
	func build(route: Array, _kind: String, _owner: int) -> bool:
		return route.size() > 1

class DryWorld extends "res://scripts/world.gd":
	func water_near(_from: Vector3, _reach := 90, _depth_factor := 1.5):
		return null

var w: Node
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0})
	change_scene_to_file("res://world.tscn")
	while current_scene == null or current_scene.get("nav_ready") != true or current_scene.get("menu") == null:
		await process_frame
	w = current_scene
	w.start_match("easy")
	w.saves.autosave_every = 0
	w.economy.grant_test_resources()
	check_roads()
	check_shipyard()
	check_transport()
	check_trade_and_powers()
	check_saved_orders()
	check_campaign_rewind()
	check_transport_command()
	print("GAMEPLAY_REGRESSIONS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check_roads() -> void:
	var isolated := IsolatedTowns.new()
	isolated.world = w
	var hq = Additional.capital(w, 1)
	var first = w.place_building("villageCenter", hq.root.position + Vector3(70, 0, 0), 1, true)
	var second = w.place_building("villageCenter", hq.root.position + Vector3(0, 0, 80), 1, true)
	first.supplied = false
	second.supplied = false
	isolated.connect_isolated(1)
	check(isolated.destinations == [isolated.world_hex(first.root.position), isolated.world_hex(second.root.position)], "an unreachable village does not block the next supply connection")
	isolated.free()
	var lg = w.logistics
	var a: Vector2i = lg.world_hex(w.start)
	var b := a + Vector2i(1, 0)
	var p: Vector3 = lg.hex_center(a).lerp(lg.hex_center(b), 1.0 / 6.0) + Vector3(0, 0, 7.9)
	var existing: Dictionary = lg.edges
	lg.edges = {"test": {"a": a, "b": b, "hp": 100.0}}
	check(lg.overlaps_intact_link(p, 10.0), "an extractor beside an existing road must clear the traffic lane")
	check(lg._hits_circles(lg.hex_center(a), lg.hex_center(b), [Vector3(p.x, 8.55, p.z)]), "the planner sees the same obstruction between sample points")
	lg.edges = existing

func check_shipyard() -> void:
	var dry := DryWorld.new()
	dry.map = w.map
	dry.hud = w.hud
	dry.economy = w.economy
	dry.unit_defs = w.unit_defs
	var yard := {"key": "shipyard", "root": Node3D.new(), "owner": 0, "dead": false, "built": true,
		"queue": [], "queue_prog": 1.0, "footprint": 18.0, "def": {"name": "Shipyard"}}
	dry.buildings.append(yard)
	dry.queue_paid_order(yard, "gunboat", {"money": 100})
	dry.queue_paid_order(yard, "destroyer", {"money": 900})
	dry.update_training(1.0)
	var before: float = w.economy.res.money
	dry.cancel_queued(yard, 0)
	check(w.economy.res.money == before + 100 and yard.queue_costs == [{"money": 900}], "a failed ship launch preserves both receipts for cancellation")
	yard.root.free()
	dry.free()

func check_transport() -> void:
	var pad = w.place_building("helipad", w.start + Vector3(40, 0, 0), 0, true)
	var second = w.place_building("helipad", w.start - Vector3(60, 0, 0), 0, true)
	var heli = w.spawn_unit("helicopter", w.start, 0)
	w.AirOperations.assign(w, heli, pad, 0)
	heli.node.position = pad.root.position + Vector3(115, 0, 0)
	heli.air_state = "ready"
	heli.sortie_left = 30.0
	var soldier = w.spawn_unit("soldier", pad.root.position, 0)
	Lift.order_board(w, [soldier], heli)
	check(Lift.used(heli) == 0 and is_same(soldier.board, heli), "troops at a pad wait for an airborne helicopter")
	check(heli.sortie_left == 30.0, "a pickup order preserves remaining fuel")
	heli.node.position = soldier.node.position
	Lift.order_board(w, [soldier], heli)
	w.order_move([heli], second.root.position)
	check(is_same(heli.get("return_base"), second), "the loaded helicopter goes to the selected base")
	w.game_time += Lift.LANDING_TIMEOUT + 1.0
	Lift._landing_step(w, heli)
	check(not heli.has("unload_go") and Lift.used(heli) == 1, "a timed-out landing retains passengers away from the destination")

func check_trade_and_powers() -> void:
	var rival = w.market.ai_nation(1)
	w.map.nations[1].id = "japan"
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, false)
	rival.money = 0.0
	check(Powers.blocked(w, 1, 0) != "", "Japan needs funds for aid under AI control")
	rival.money = 900.0
	Powers.use(w, 1, 0)
	check(rival.money == 100.0 and w.diplomacy.nap[0][1], "Japanese aid charges the AI treasury")
	var home = Additional.capital(w, 0)
	home.hp = home.max_hp * 0.5
	var village = w.place_building("villageCenter", home.root.position + Vector3(150, 0, 0), 0, true)
	village.hp = village.max_hp * 0.5
	w.selected_building = village
	check(home in Additional.repairs(w, 0) and not village in Additional.repairs(w, 0), "reconstruction stays centred on the capital")
	w.selected_building = null
	var school = w.place_building("school", Additional.capital(w, 1).root.position + Vector3(0, 0, 45), 1, true)
	check(not school in Additional.strike_targets(w, 1), "a school is ineligible for an industrial strike")
	Additional.use_output_cut(w, 1)
	check(Powers.effects_on(w, 1).any(func(e): return "+15%" in e[0]), "income bonuses have a positive sign")
	var port = w.place_building("port", w.start + Vector3(0, 0, 70), 0, true)
	port.supplied = true
	w.economy.recalculate()
	w.diplomacy.set_flag(w.diplomacy.pact, 0, 1, true)
	w.market.open_route(1, "iron", "export", 10)
	Additional.use_insurance_ban(w, 0, 1)
	w.market.tick()
	check(w.market.routes.size() == 1 and w.market.routes[0].shipment == null, "a partner's shipping ban prevents loading sea freight")
	w.market.routes.clear()
	var c = w.diplomacy.contacts
	c.session = {"nation": 1, "leader": c.leader(1), "visitor": c.leader(0), "phase": "talking", "channel": "phone",
		"results": [], "used": [], "counter": {"key": "route", "terms": {"res": "iron", "qty": 10, "dir": "import"}, "fee": 200}}
	w.un._apply_measure("economic", 1, 300)
	var money: float = w.economy.res.money
	check(c.answer_counter(true) != "" and money == w.economy.res.money and w.market.routes.is_empty(), "a prohibited deal cannot collect a concession")
	c.session.clear()
	var store = w.place_building("market", Additional.capital(w, 1).root.position + Vector3(45, 0, 0), 1, true)
	store.supplied = true
	w.market.ai_stock["1"].iron = 5.0
	rival.money = 5000
	w.market.trade_ai()
	check(w.market.ai_stock["1"].iron <= 5.0, "a sanctioned AI cannot buy iron at the spot market")

func check_saved_orders() -> void:
	var site = w.place_building("farm", w.start + Vector3(50, 0, 40), 0, false)
	var next = w.place_building("farm", w.start + Vector3(30, 0, 60), 0, false)
	var worker = w.units.filter(func(u): return u.key == "worker" and u.owner == 0)[0]
	w.order_build([worker], site)
	w.order_build([worker], next, true)
	var tank = w.spawn_unit("tank", w.start, 0)
	var enemy = w.spawn_unit("soldier", w.start + Vector3(80, 0, 0), 1)
	w.order_attack([tank], enemy)
	var saved_target: Vector3 = enemy.node.position
	w.saves.restore(JSON.parse_string(JSON.stringify(w.saves.capture())))
	check(w.units.any(func(u): return u.key == "worker" and u.get("build_site") != null and u.build_site.root.position.distance_to(site.root.position) < 0.1 and u.build_queue.size() == 1 and u.build_queue[0].root.position.distance_to(next.root.position) < 0.1), "worker retains its site and next job after a JSON round trip")
	check(w.units.any(func(u): return u.key == "tank" and u.get("forced", false) and u.enemy != null and u.enemy.node.position.distance_to(saved_target) < 0.1), "tank resumes attacking the same unit after load")

func check_campaign_rewind() -> void:
	var territory = w.territory
	var ownership: PackedInt32Array = territory.owner_of.duplicate()
	for i in range(ownership.size()):
		territory.owner_of[i] = -1 if territory.terrain[i] == territory.Terrain.WATER else 0
	check(is_equal_approx(w.victory.land_share(0), 1.0), "all dry land counts as full control even without territorial waters")
	territory.owner_of = ownership
	var spot: Vector3 = Lift.landing_spot(w, w.start, [], null, 80)
	var fort = w.fortifications
	var position := spot + Vector3(18, 0, 0)
	var trench = fort._spawn(0, position, 0.0, "trench", true)
	var seated = w.spawn_unit("soldier", position, 0)
	fort._seat_unit_immediately(seated, trench)
	var passer = w.spawn_unit("soldier", position, 0)
	w.order_move([passer], spot + Vector3(60, 0, 0))
	var digger = w.spawn_unit("soldier", spot, 0)
	fort.order_dig([digger], "trench")
	fort.update(0.2)
	var checkpoint = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.market.ai_nation(1).national_cargo = {"target": 0, "qty": 30}
	w.generals._enlist(0)
	checkpoint.erase("generals")
	w.saves.restore(checkpoint)
	check(not w.market.ai_nation(1).has("national_cargo"), "rewinding before a shipment removes its cargo")
	check(w.generals.of(0).is_empty() and not w.generals.of(1).is_empty(), "legacy saves start with a fresh general staff")
	check(fort.entries[0].garrison.size() == 1 and w.units.any(func(u): return u.key == "soldier" and u.get("garrisoned_in") == null and u.target != null and u.node.position.distance_to(position) < 4), "the occupant stays seated and a passing soldier keeps walking")
	var unfinished = fort.entries.filter(func(e): return not e.built)[0]
	var progress: float = unfinished.progress
	fort.update(0.5)
	check(unfinished.progress > progress, "the assigned digger continues construction after loading")

func check_transport_command() -> void:
	var spot: Vector3 = Lift.landing_spot(w, w.start, [], null, 80)
	var heli = w.spawn_unit("helicopter", spot, 0)
	var squad = w.spawn_unit("soldier", spot, 0)
	heli.pickup_go = spot + Vector3(200, 0, 0)
	heli.pickup_since = w.game_time - Lift.LANDING_TIMEOUT - 1
	heli.pickup_sweep = true
	Lift._pickup_step(w, heli)
	check(not heli.has("pickup_go") and Lift.used(heli) == 0 and not squad.dead, "a timed-out pickup cannot board unrelated passengers")
	var general = w.generals._enlist(0)
	w.generals.assign(general, squad)
	Lift.order_board(w, [squad], heli)
	var tank = w.spawn_unit("tank", spot, 0)
	w.generals.assign(general, tank)
	var landed: Array = Lift.unload(w, heli)
	check(landed.size() == 1 and not landed[0].has("general") and is_same(general.unit, tank), "unloading respects a general's reassignment")
	var hq = Additional.capital(w, 0)
	var unit = landed[0]
	unit.node.position = hq.root.position
	w.UrbanGarrison.order_garrison(w, [unit], hq)
	var enemy = w.spawn_unit("soldier", spot, 1)
	w.order_attack([unit], enemy)
	w.UrbanGarrison.update(w, 0.2)
	check(not unit.has("garrison_order") and unit.get("garrison_building") == null and is_same(unit.enemy, enemy), "an attack supersedes a pending garrison order")
	w.generals.assign(general, unit)
	heli.node.position = unit.node.position
	Lift.order_board(w, [unit], heli)
	w.kill(heli)
	check(general.unit == null and (not general.alive or general.wounded_until > w.game_time), "losing a transport resolves the fate of its passenger commander")
