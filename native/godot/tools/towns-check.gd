extends SceneTree
## Towns, land, roads and trade:
## - the camera's angle does not change from the keyboard;
## - on a generated map every deposit sits at a hex centre;
## - a deposit under an extractor loses its marker;
## - land is not free: a hex outside your land cannot be built on;
## - a town hall reports its residents, happiness, food and taxes, and its
##   land grows with its residents;
## - roads and railways run between town halls; a railway on a road's link
##   runs beside it; a road to another nation's town opens overland trade;
## - a standing City Center counts toward the Urban Era.
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func boot(config: Dictionary) -> Node:
	set_meta("match_config", config)
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			var w: Node = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			w.start_match("easy")
			w.menu._root.hide()
			return w
	return null
func run() -> void:
	# Generated map: deposits at hex centres.
	var w: Node = await boot({"map": "continent", "players": 4, "nation": 0, "style": "standard"})
	var off := 0
	for d in w.deposits:
		var c: Vector3 = w.snap_to_hex(d.pos)
		if Vector2(c.x - d.pos.x, c.z - d.pos.z).length() > 0.5:
			off += 1
	check(off == 0, "every deposit on the continent sits at a hex centre (%d off)" % off)
	# The original island for the rest.
	w = await boot({"map": "island", "players": 4, "nation": 0, "style": "standard"})
	w.economy.grant_test_resources()
	# Camera keys.
	var yaw: float = w.cam_yaw
	var pitch: float = w.cam_pitch
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_Q
	ev.pressed = true
	Input.parse_input_event(ev)
	w.pan_camera(0.5)
	check(is_equal_approx(w.cam_yaw, yaw) and is_equal_approx(w.cam_pitch, pitch), "the keyboard no longer turns or tilts the camera")
	var up := InputEventKey.new()
	up.physical_keycode = KEY_Q
	up.pressed = false
	Input.parse_input_event(up)
	# A deposit under an extractor.
	var dep = null
	for d in w.deposits:
		if not d.get("water", false) and d.extractor == null and w.territory.owner_at(d.pos) == 0:
			dep = d
	if dep == null:
		for d in w.deposits:
			if not d.get("water", false) and d.extractor == null:
				dep = d
	var ex: Dictionary = w.place_building("extractor", dep.pos, 0, true)
	var icon: Node = dep.node.find_child("Icon", true, false)
	check(icon != null and not icon.visible, "the resource marker hides under an extractor")
	# Land is not free.
	var home: Vector2i = w.logistics.world_hex(w.start)
	var outside = null
	for ring in range(2, 8):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				var at: Vector3 = w.logistics.hex_center(h)
				if outside == null and w.logistics.hex_distance(home, h) == ring and w.territory.owner_at(at) < 0 and w.height_at(at.x, at.z) > 2.0:
					outside = at
	check(outside != null and w.site_problem("housing", outside, 0) != "", "an unclaimed hex cannot be built on (%s)" % (w.site_problem("housing", outside, 0) if outside != null else "none found"))
	# The capital's accounts and land.
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var c: Dictionary = w.economy.city_report(hq)
	print("  capital: %d residents of %d, happiness %d, food +%.1f -%.1f, tax %.2f/s, rings %d" % [c.residents, c.capacity, c.happiness, c.food_in, c.food_out, c.tax, w.territory.rings_of(hq)])
	check(c.residents > 0.0 and c.tax > 0.0 and c.capacity >= c.residents, "the capital reports residents, capacity and taxes")
	var rings_before: int = w.territory.rings_of(hq)
	w.economy.civilians = 60.0
	var small: int = w.territory.rings_of(hq)
	w.economy.civilians = w.economy.civ_cap
	for k in range(3):
		w.place_building("residential", w.logistics.hex_center(home + [Vector2i(2, -1), Vector2i(-2, 1), Vector2i(1, 1)][k]), 0, true)
	w.economy.recalculate()
	w.economy.civilians = w.economy.civ_cap
	var big: int = w.territory.rings_of(hq)
	check(big > small, "the capital's land grows with its residents (%d rings at 60 people, %d at %d)" % [small, big, int(w.economy.civilians)])
	# Roads between town halls; a railway beside the road.
	var other: Dictionary = w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0]
	var hq_hex: Vector2i = w.logistics.world_hex(hq.root.position)
	var other_hex: Vector2i = w.logistics.world_hex(other.root.position)
	var route: Array = w.logistics.plan(hq_hex, other_hex, 0, "road")
	check(route.size() > 1 and route[-1] == other_hex, "a road can be planned to another nation's capital")
	w.logistics.build(route, "road", 0)
	var rail_route: Array = w.logistics.plan(hq_hex, other_hex, 0, "rail")
	if rail_route.size() > 1:
		w.logistics.build(rail_route, "rail", 0)
	var roads := 0
	var rails := 0
	for e in w.logistics.edges.values():
		if e.owner == 0:
			if e.kind == "road": roads += 1
			else: rails += 1
	check(roads >= route.size() - 1 and (rail_route.size() < 2 or rails >= rail_route.size() - 1), "road and railway both stand (%d road links, %d rail links)" % [roads, rails])
	if rail_route.size() > 1:
		var shared := false
		for i in range(1, rail_route.size()):
			if w.logistics.rail_offset(rail_route[i - 1], rail_route[i]).length() > 1.0:
				shared = true
		check(shared, "where they share a link the railway runs beside the road")
	w.logistics.update_supply()
	check(w.market.land_link(1) != "", "the link reaches the other nation's town (%s)" % w.market.land_link(1))
	w.diplomacy.pact[0][1] = true
	w.diplomacy.pact[1][0] = true
	var said: String = w.market.open_route(1, "oil", "export", 25)
	print("  ", said)
	check(not w.market.routes.is_empty() and w.market.routes[-1].get("overland", false), "an overland trade route opens without a port")
	# The Urban Era counts a City Center even before it is linked by road.
	var far: Vector3 = w.logistics.hex_center(home + Vector2i(-6, 3))
	w.place_building("cityCenter", far, 0, true)
	w.logistics.update_supply()
	var reqs: Array = w.research.era_requirements(2)
	var cities: Array = reqs.filter(func(q): return str(q[0]).begins_with("City"))
	check(not cities.is_empty() and cities[0][1] >= 1.0, "a City Center counts for the Urban Era, linked or not (%s)" % str(cities))
	print("TOWNS_TEST PASS" if errors.is_empty() else "TOWNS_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
