extends SceneTree
## Sites at the edges get built: a shipyard on the coast and districts on the
## outermost hexes of the player's land (by the water, on slopes, in the
## corners) are each finished by the player's workers, and a finished
## shipyard counts for research (Naval Engineering's prototype stage).
var errors: Array[String] = []
const DT := 1.0 / 60.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func step(w: Node) -> void:
	w._physics_process(DT)
	w.effects._physics_process(DT)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	w.start_match("easy")
	w.menu._root.hide()
	w.economy.grant_test_resources()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	var home: Vector2i = w.logistics.world_hex(w.start)
	# A harbour must stand in your own land: the nearest coastal hex is granted,
	# as if the town had grown to it.
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var gh: Vector2i = w.logistics.world_hex(w.start) + Vector2i(q, r)
				var ga: Vector3 = w.logistics.hex_center(gh)
				if w.logistics.hex_distance(w.logistics.world_hex(w.start), gh) == ring and w.site_problem("shipyard", ga, 0) == "Outside your territory" and not w.has_meta("granted"):
					var gi: int = w.territory.index_of(w.territory.hex_at(ga))
					w.territory.owner_of[gi] = 0
					w.territory.control[gi] = 80.0
					var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
					w.territory.purchased[str(gi)] = {"owner": 0, "settlement": w.territory.settlement_key(capital)}
					w.set_meta("granted", ga)
	# The coastal hex for a shipyard, and the outermost buildable hexes of our land.
	var coast = null
	var coasts := []
	var edges := []
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				if w.logistics.hex_distance(home, h) != ring:
					continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem("shipyard", at, 0) == "":
					if coast == null:
						coast = at
					elif coasts.size() < 8:
						coasts.append(at)
				elif ring >= 2 and w.site_problem("housing", at, 0) == "" and edges.size() < 5:
					var outer := false
					for d in w.logistics.DIRECTIONS:
						if w.territory.owner_at(w.logistics.hex_center(h + d)) != 0:
							outer = true
					if outer:
						edges.append(at)
	check(coast != null, "a coastal hex takes a shipyard")
	var sites := []
	if coast != null:
		sites.append(w.place_building("shipyard", coast, 0, false))
	for at in edges:
		sites.append(w.place_building("housing", at, 0, false))
	for at in coasts:
		if sites.all(func(s): return s.root.position.distance_to(at) > 30.0):
			sites.append(w.place_building("port", at, 0, false))
	# A site hemmed in: every neighbouring hex already built up.
	var boxed_hex: Vector2i = home + Vector2i(-3, 1)
	var boxed_at: Vector3 = w.logistics.hex_center(boxed_hex)
	for d in w.logistics.DIRECTIONS:
		var nb: Vector3 = w.logistics.hex_center(boxed_hex + d)
		if not w.district_hex.has(boxed_hex + d) and w.height_at(nb.x, nb.z) > 1.0:
			w.place_building("housing", nb, 0, true)
			w.close_navigation(nb, w.DISTRICT_NAV_SIZE)
	if not w.district_hex.has(boxed_hex):
		sites.append(w.place_building("school", boxed_at, 0, false))
	for s in sites:
		w.close_navigation(s.root.position, w.DISTRICT_NAV_SIZE)
	w.refresh_streets()
	for i in range(4): await physics_frame
	print("  %d sites: %s" % [sites.size(), sites.map(func(s): return "%s at %s" % [s.key, s.root.position])])
	for f in range(60 * 400):
		step(w)
		if f % 60 == 0:
			for s in sites:
				if not s.built:
					w.call_worker(s)
		if sites.all(func(s): return s.built):
			break
	for s in sites:
		if not s.built:
			var near: Array = w.units.filter(func(u): return is_same(u.build_site, s))
			print("   NOT BUILT %s at %s, progress %.2f, workers on it %d, open ground by it %s" % [s.key, s.root.position, s.progress, near.size(), w.nearest_open_centre(s.root.position)])
			for u in near:
				print("      worker at %s, %.1f m away, target %s" % [u.node.position, u.node.position.distance_to(s.root.position), u.target])
	check(sites.all(func(s): return s.built), "every edge and coastal site is finished")
	if coast != null and sites[0].built:
		w.logistics.update_supply()
		print("  shipyard supplied %s, owned %d" % [sites[0].get("supplied", true), w.economy.owned("shipyard")])
		w.research.era = 1
		w.research.progress["navalEngineering"].stage = 1
		check(w.research.blocker("navalEngineering") == "", "with a shipyard, Naval Engineering's prototype can start (blocker: '%s')" % w.research.blocker("navalEngineering"))
		sites[0].supplied = false  # cut off from the capital
		check(w.research.blocker("navalEngineering") == "", "a shipyard cut off from supply still counts for research")
	print("EDGE_BUILD PASS" if errors.is_empty() else "EDGE_BUILD FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
