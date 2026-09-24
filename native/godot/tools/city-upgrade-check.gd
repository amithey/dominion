extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	paused = true
	w.menu._root.hide()
	w.economy.grant_test_resources()
	var b: Dictionary = w.buildings.filter(func(x): return x.owner == 0 and x.key == "barracks")[0]
	w.select_building(b)
	w.hud._update_panel()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(640, 400)
	w.dragging = false
	w._unhandled_input(release)
	check(is_same(w.selected_building, b) and not w.hud.prod_open, "unmatched release preserves the selected production building")
	var other: Dictionary = w.place_building("barracks", w.start + Vector3(50, 0, 50), 0, true)
	var before: String = w.hud._shown_key
	w.select_building(other)
	w.hud._update_panel()
	check(w.hud._shown_key != before, "same-type building refreshes callbacks to the correct instance")
	var selected: Array = w.units.filter(func(u): return u.owner == 0).slice(0, 4)
	w.select_building(null)
	for u in selected: u.selected = true
	w.hud._update_selection()
	check(w.hud._unit_roster.get_child_count() == selected.size(), "roster includes every selected unit")
	var depot: Dictionary = w.place_building("market", w.start + Vector3(-50, 0, 50), 0, true)
	w.logistics.update_supply()
	w.economy.res.iron = 500
	var price: float = w.market.price("iron")
	w.market.buy("iron", 100)
	check(w.market.price("iron") > price, "buy demand raises commodity price")
	w.market.sell("iron", 100)
	check(is_equal_approx(w.market.price("iron"), price), "equal supply reverses market pressure")
	var treasury: float = w.economy.res.money
	w.market.buy("iron", -10)
	check(w.economy.res.money == treasury, "negative trades cannot create money")
	var gas: Array = w.deposits.filter(func(d): return d.type == "seaGas")
	check(not gas.is_empty(), "campaign has offshore natural gas")
	if not gas.is_empty():
		var dep: Dictionary = gas[0]
		var reason: String = w.site_problem("offshoreRig", dep.pos, 0)
		check(reason in ["", "Outside your territory"] or reason.begins_with("Inside"), "offshore placement does not require dry ground")
		var rig: Dictionary = w.place_building("offshoreRig", dep.pos, 0, false)
		w.update_construction(40)
		check(rig.built and rig.deposit == dep and rig.root.position.y > w.map.seaLevel, "marine contractors finish a floating gas rig without land workers")
	w.game_time = 550
	w.economy.tick()
	var winter: float = w.economy.rates.gas
	w.game_time = 50
	w.economy.tick()
	check(w.economy.rates.gas > winter, "gas consumption rises for winter heating")
	var base: Dictionary = preload("res://scripts/airbase_regression.gd").setup(w)
	var heli: Dictionary = w.spawn_unit("helicopter", base.root.position + Vector3(80, 0, -60), 0)
	w.AirOperations.assign(w, heli, base, 0)
	w.AirOperations.order_land(w, heli, base)
	heli.node.position = w.AirOperations.goal(w, heli) + Vector3.UP * 10
	w.AirOperations.update(w, heli, 0.1)
	check(heli.air_state == "landing", "helicopter return target enters its landing corridor")
	heli.air_state = "parked"
	w.AirOperations.order_land(w, heli, base)
	check(heli.air_state == "parked", "recall leaves already parked aircraft on their slot")
	w.diplomacy.declare_war(0, 1)
	var sam: Dictionary = w.place_building("samSite", w.start + Vector3(70, 0, 0), 0, true)
	var enemy: Dictionary = w.spawn_unit("helicopter", sam.root.position + Vector3(90, 20, 0), 1)
	preload("res://scripts/air_defence.gd").update(w, 0.1)
	check(sam.get("aa_reload", 0.0) > 0, "fixed SAM fires on a hostile aircraft at long range")
	var artillery: Dictionary = w.spawn_unit("artillery", w.start, 0)
	check(artillery.range >= 80 and w.unit_defs.samLauncher.range >= 110, "artillery and mobile SAM have distinct long engagement ranges")
	var saved: Dictionary = w.market.capture()
	w.market.restore(JSON.parse_string(JSON.stringify(saved)))
	check(w.market.volume.get("iron", 0) >= 200, "market activity survives save serialization")
	check(preload("res://scripts/leader_gallery.gd").available(["President E. Hale", "Premier K. Volkov"]), "portraits resolve by identity after nation reorder")
	var ready: bool = w.nav_ready
	w.nav_ready = false
	check(w.path_between(w.start, w.start + Vector3(100, 0, 0)).is_empty(), "unavailable navigation never becomes an unsafe straight-line order")
	w.nav_ready = ready
	var traffic: Node = w.get_children().filter(func(n): return n.get_script() == preload("res://scripts/route_traffic.gd"))[0]
	var hex: Vector2i = w.logistics.world_hex(w.start)
	# Out in the country, clear of the capital's districts (route_traffic.gd, 0.9.15:
	# vehicles make trips on the network rather than one per link).
	w.logistics.edges["upgrade-road"] = {"a": hex + Vector2i(6, 0), "b": hex + Vector2i(7, 0), "kind": "road", "hp": 100.0}
	w.logistics.edges["upgrade-rail"] = {"a": hex + Vector2i(6, 2), "b": hex + Vector2i(6, 3), "kind": "rail", "hp": 100.0}
	traffic._sync()
	var moved := false
	for i in range(40):
		var positions: Array = traffic._fleet.map(func(c): return c.s)
		traffic._process(0.25)
		for k in range(mini(positions.size(), traffic._fleet.size())):
			moved = moved or absf(traffic._fleet[k].s - positions[k]) > 0.1
	var kinds: Array = traffic._fleet.map(func(c): return c.kind)
	check(moved and "road" in kinds and "rail" in kinds, "cars and trains animate on built infrastructure")
	w.logistics.edges["upgrade-road"].hp = 0.0
	traffic._sync()
	check(not traffic._fleet.any(func(c): return c.kind == "road"), "traffic stops on destroyed roads")
	w.place_building("market", Vector3(w.map.startPositions[2][0], 0, w.map.startPositions[2][1]), 2, true)
	w.market.ai_stock["2"] = {"iron": 10.0}
	var iron_price: float = w.market.price("iron")
	w.market.trade_ai()
	check(w.market.price("iron") > iron_price and w.market.ai_stock["2"].iron > 10, "AI buys shortages and contributes real market demand")
	w.logistics.edges.erase("upgrade-road")
	w.logistics.edges.erase("upgrade-rail")
	w.place_building("port", w.start + Vector3(0, 0, 60), 0, true)
	w.diplomacy.pact[0][2] = true
	w.market.open_route(2, "iron", "export", 25)
	w.market.tick()
	traffic._process(2.1)
	var ships: Array = traffic.vehicles.values().filter(func(v): return v.kind == "ship")
	check(not ships.is_empty(), "an actual loaded trade shipment creates a cargo ship")
	if not ships.is_empty():
		check(Array(ships[0].path).all(func(p): return w.is_water(p)), "trade ship follows water around the island")
	print("CITY_UPGRADE_TEST PASS" if errors.is_empty() else "CITY_UPGRADE_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
