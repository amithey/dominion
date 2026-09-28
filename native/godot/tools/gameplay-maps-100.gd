extends SceneTree
## About a hundred gameplay checks across every map, eleven or so on each:
## maps-check.gd proves each map is laid out right; this plays on it. Room for
## a town in the starting land; a harbour site and open water to launch into;
## a worker who builds and a tank that drives; rivals that grow; an economy
## that runs; capitals a fair distance apart; the simulation fast enough on
## the biggest maps; the map kept in a save.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Generator := preload("res://scripts/map_generator.gd")
## Smallest to largest: the original island and its mirror, then the generated maps.
const KEYS := ["small", "island", "mirrored", "twin", "archipelago", "continent", "frontier", "inland_sea", "crown"]
var only: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func name_of(key: String) -> String:
	if Generator.MAPS.has(key): return str(Generator.MAPS[key].name)
	return "Mirrored Island" if key == "mirrored" else "The Island"

func sim(seconds: float, rivals: bool, done := Callable()) -> void:
	var t := 0.0
	var next_tick := 1.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		if rivals: w.ai._physics_process(DT)
		t += DT
		if t >= next_tick:
			next_tick += 1.0
			w.economy.tick()
		if done.is_valid() and done.call():
			break

func dry(at: Vector3) -> Vector3:
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 22.0, 30.0]:
		for i in range(12 if r > 0.0 else 1):
			var a := i * TAU / 12.0
			var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
				p.y = w.height_at(p.x, p.z)
				return p
	return w.land_point(at, 20.0)

func home() -> Vector2i:
	return w.logistics.world_hex(w.start)

func hq(owner := 0) -> Dictionary:
	var list: Array = w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)
	return list[0] if not list.is_empty() else {}

func grant_land(rings: int) -> void:
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home() + Vector2i(q, r)
			if w.logistics.hex_distance(home(), h) > rings: continue
			var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
			if i >= 0 and w.territory.owner_of[i] < 0:
				w.territory.owner_of[i] = 0
				w.territory.control[i] = 80.0
				w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(hq())}

func site(key: String, max_ring := 8) -> Variant:
	for ring in range(1, max_ring + 1):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "":
					return at
	return null

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maps="): only = a.substr(7).split(",")
	for key in KEYS:
		if not only.is_empty() and not key in only: continue
		set_meta("match_config", {"map": key, "players": 4, "nation": 0, "style": "standard"})
		change_scene_to_file("res://world.tscn")
		w = null
		for i in range(6000):
			await process_frame
			if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
				w = current_scene
				break
		if w == null:
			check(false, "%s loads" % key)
			continue
		if w.menu.get("_root") == null: w.menu.setup(w)
		seed(hash(key))
		w.start_match("easy")
		w.menu._root.hide()
		for i in range(10): await physics_frame
		w.set_physics_process(false)
		w.effects.set_physics_process(false)
		w.ai.set_physics_process(false)
		w.economy.set_process(false)
		var name: String = name_of(key)
		print("== %s (%s, %d m)" % [name, key, int(w.map.mapSize)])

		# The starting land: a town fits in it.
		var t: Node = w.territory
		t.tick()
		var cells: int = t.yields(0).cells
		check(cells >= 7, "%s: the capital starts with land of its own (%d hexes)" % [name, cells])
		var fits := 0
		for k in ["farm", "cottage", "barracks", "warehouse", "market"]:
			if site(k, 3) != null: fits += 1
		check(fits == 5, "%s: a farm, homes, a barracks, a warehouse and a market fit in the starting land (%d of 5)" % [name, fits])
		var near_dep := 0
		for d in w.deposits:
			if not d.get("water", false) and d.pos.distance_to(w.start) < 160.0: near_dep += 1
		check(near_dep >= 3, "%s: resource deposits lie within reach of the capital (%d)" % [name, near_dep])
		w.economy.grant_test_resources()
		grant_land(8)
		# A harbour, and open water to launch ships into.
		var harbour = site("shipyard", 8)
		var sea_ok := false
		if harbour != null:
			sea_ok = w.water_near(harbour, 160) != null
		check(harbour != null and sea_ok, "%s: the capital's land reaches a coast for a shipyard, with open water to launch into" % name)
		# A worker builds; a tank drives.
		var farm_at = site("farm", 4)
		var built := false
		if farm_at != null:
			for u in w.units.filter(func(x): return x.owner == 0 and x.key == "worker"): u.build_site = null
			w.build_site("farm", farm_at)
			var farm: Dictionary = w.buildings[-1]
			sim(70.0, false, func(): return farm.built)
			built = farm.built
		check(built, "%s: a worker builds a farm" % name)
		for i in range(6): await physics_frame   # the navigation map takes in the new farm, as it does in play
		# Across open country: from the edge of the town, 110 m on toward the middle of the map.
		# (The first bearing, turning from the middle, whose end point a land route reaches:
		# on the Archipelago the middle holds islets no tank can get to.)
		var inward: Vector3 = (Vector3.ZERO - hq().root.position).normalized()
		var from: Vector3 = dry(hq().root.position + inward * 45.0)
		var away: Vector3 = dry(hq().root.position + inward * 155.0)
		for turn: float in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2]:
			var dir: Vector3 = inward.rotated(Vector3.UP, turn)
			var s0: Vector3 = dry(hq().root.position + dir * 45.0)
			var g0: Vector3 = dry(hq().root.position + dir * 155.0)
			var route: PackedVector3Array = w.path_between(s0, g0)
			if not route.is_empty() and Vector2(route[-1].x - g0.x, route[-1].z - g0.z).length() < 4.0 and s0.distance_to(g0) > 90.0:
				from = s0
				away = g0
				break
		var tank: Dictionary = w.spawn_unit("tank", from, 0)
		w.order_move([tank], away)
		sim(60.0, false, func(): return tank.target == null)
		var got: float = Vector2(tank.node.position.x - away.x, tank.node.position.z - away.z).length()
		check(got < 15.0, "%s: a tank drives 110 m across the country within a minute (%d m short%s)" % [name, int(got), "" if got < 15.0 else (", still driving" if tank.target != null else ", gave up at %s" % str(tank.node.position.snapped(Vector3.ONE)))])
		w.kill(tank)
		# Capitals a fair distance apart.
		var capitals: Array = w.buildings.filter(func(b): return b.key == "hq" and not b.dead)
		var nearest := []
		for a in capitals:
			var best := INF
			for b in capitals:
				if not is_same(a, b): best = minf(best, a.root.position.distance_to(b.root.position))
			nearest.append(best)
		var mean: float = nearest.reduce(func(s, v): return s + v, 0.0) / nearest.size()
		check(nearest.min() >= 120.0, "%s: no two capitals crowd each other (closest %d m)" % [name, int(nearest.min())])
		check(nearest[capitals.find(hq())] >= mean * 0.6, "%s: your nearest rival is not unfairly close (%d m, average %d m)" % [name, int(nearest[capitals.find(hq())]), int(mean)])
		# Rivals grow, and the economy runs.
		var before := {}
		for n in w.ai.nations: before[n.id] = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
		var money0: float = w.economy.res.money
		var t0 := Time.get_ticks_msec()
		sim(150.0, true)
		var per_step: float = float(Time.get_ticks_msec() - t0) / (150.0 / DT)
		var grew: int = w.ai.nations.filter(func(n): return w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size() > before[n.id]).size()
		check(grew == w.ai.nations.size(), "%s: every rival builds up in two and a half minutes (%d of %d)" % [name, grew, w.ai.nations.size()])
		check(w.economy.res.money >= money0 and w.economy.res.values().all(func(v): return not is_nan(v) and v >= 0.0), "%s: the economy runs (no resource negative or broken)" % name)
		check(per_step < 60.0, "%s: the simulation keeps up (%.1f ms a step)" % [name, per_step])
		# The map is part of the save.
		var saved: Dictionary = w.saves.capture()
		check(str(saved.get("match_config", {}).get("map", "")) == key, "%s: a save records which map it is" % name)
	print("\nGAMEPLAY_MAPS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("GAMEPLAY_MAPS PASS" if errors.is_empty() else "GAMEPLAY_MAPS FAIL")
	quit(0 if errors.is_empty() else 1)
