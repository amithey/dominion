extends SceneTree
## A hundred gameplay checks for 0.9.40.
## Part one, playing each of the nine nations in turn: its capital, workers
## and army; a worker builds; the barracks trains; the tank factory turns out
## that nation's own tank; research advances; its national power works; a tank
## drives across the country.
## Part two, a six-nation match on Pangaea: marches across the walk grid's
## tiles (0.9.40 draws it in tiles); a new building blocks the way through it;
## rivals build for minutes and every route between capitals stays open; land,
## economy, war, peace, trade, missiles, spies, land purchase, road traffic,
## a save and a load, and the cost of it all.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Factions := preload("res://scripts/factions.gd")
const V := preload("res://scripts/national_variants.gd")
const Powers := preload("res://scripts/faction_powers.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func load_match(cfg: Dictionary, difficulty := "easy") -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match(difficulty)
	w.menu._root.hide()
	w.un = null   # (the UN's standing sanctions, North Korea's arms embargo among them, would slow its factory: wmd-un-check tests those)
	for i in range(8): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		node.set_process(false)

func sim(seconds: float, rivals := false, done := Callable()) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		if rivals: w.ai._physics_process(DT)
		for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
			node._process(DT)
		t += DT
		if done.is_valid() and done.call():
			break

func hq(owner := 0):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			return b
	return null

func home() -> Vector2i:
	return w.logistics.world_hex(w.start)

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

func find_site(key: String, from := 1, to := 9) -> Variant:
	for ring in range(from, to):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "":
					return at
	return null

func dry(at: Vector3) -> Vector3:
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 22.0, 30.0]:
		for i in range(12 if r > 0.0 else 1):
			var a := i * TAU / 12.0
			var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9 and w.open_ground(p):
				p.y = w.height_at(p.x, p.z)
				return p
	return w.land_point(at, 20.0)

## A tank's drive from `a` to `b`: how far short it ends.
func drive(a: Vector3, b: Vector3, seconds := 70.0) -> float:
	var tank: Dictionary = w.spawn_unit("tank", a, 0)
	w.order_move([tank], b)
	sim(seconds, false, func(): return tank.target == null)
	var short: float = Vector2(tank.node.position.x - b.x, tank.node.position.z - b.z).length()
	w.kill(tank)
	return short

## A finished building of `key` for `owner`, on the nearest site round its capital.
func put(key: String, owner: int) -> Dictionary:
	var centre: Vector3 = hq(owner).root.position
	for ring in range(14, 160, 7):
		for k in range(16):
			var at: Vector3 = w.snap_to_hex(centre + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0) * ring)
			if w.site_problem(key, at, owner) == "":
				return w.place_building(key, at, owner, true)
	# (no proper site, a port inland: put it by the capital, as additional-factions-check does)
	var b: Dictionary = w.place_building(key, centre + Vector3(15, 0, 15), owner, true)
	b.supplied = true
	return b

## The newer nations' powers ask for something first (additional_powers.gd): give it to them.
func meet_needs(id: String) -> void:
	var extra := preload("res://scripts/additional_powers.gd")
	if id == "iran":
		w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)   # Hormuz is closed only at war
	if not extra.POWERS.has(id):
		return
	for need in extra.POWERS[id].needs:
		if not extra.owned(w, 0, need): put(need, 0)
	var d: Node = w.diplomacy
	match id:
		"uk", "indonesia", "north_korea":
			d.set_flag(d.alliance, 0, 1, false)   # hostile levers: not on an ally
		"brazil":
			d.set_flag(d.war, 0, 1, false)
			d.set_flag(d.pact, 0, 1, true)
			if not extra.owned(w, 1, "port"): put("port", 1)
		"pakistan":
			d.set_flag(d.war, 0, 1, false)
			d.set_flag(d.alliance, 0, 1, false)   # a friend, not yet an ally
			d.set_score(0, 1, 40.0)
		"south_korea", "australia":
			d.set_flag(d.war, 0, 1, false)
			d.set_score(0, 1, 30.0)   # a partner
		"syria":
			d.set_score(0, 1, 45.0)
		"afghanistan":
			d.set_flag(d.war, 0, 1, true)
			put("farm", 1)
		"ukraine":
			d.set_flag(d.war, 0, 1, true)   # drone strikes only at war
			put("farm", 1)   # something besides its capital to strike

func mine(key: String) -> Array:
	return w.units.filter(func(u): return u.owner == 0 and u.key == key and not u.dead)

# ---------------------------------------------------------------- part one

func nation_checks(index: int) -> void:
	var id: String = Factions.IDS[index]
	await load_match({"map": "island", "players": 4, "nation": index, "style": "standard"})
	seed(hash(id) + 5)
	var arsenal: String = preload("res://scripts/national_arsenal.gd").identity(w, 0)
	print("== %s (%s)" % [id, arsenal])
	w.economy.grant_test_resources()
	grant_land(6)
	# 1: the start.
	var army: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker" and not u.get("naval", false)).size()
	check(hq() != null and mine("worker").size() >= 3 and army >= 6, "%s: a capital, %d workers and an army of %d" % [id, mine("worker").size(), army])
	# 2: a worker builds a farm.
	var at = find_site("farm", 1, 5)
	var built := false
	if at != null:
		for u in mine("worker"): u.build_site = null
		w.build_site("farm", at)
		var farm: Dictionary = w.buildings[-1]
		sim(90.0, false, func(): return farm.built)
		built = farm.built
	check(built, "%s: a worker builds a farm" % id)
	# 3: the barracks trains a soldier.
	var barracks: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead)[0]
	var soldiers: int = mine("soldier").size()
	w.queue_unit(barracks, "soldier")
	for i in range(int(w.unit_defs.soldier.trainTime) + 3): w.update_training(1.0)
	check(mine("soldier").size() == soldiers + 1, "%s: the barracks trains a soldier" % id)
	# 4: the tank factory turns out the nation's own tank.
	var factory: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "tankFactory" and not b.dead)[0]
	var tanks: int = mine("tank").size()
	w.queue_unit(factory, "tank")
	for i in range(int(w.unit_defs.tank.trainTime) + 3): w.update_training(1.0)
	var own_name: String = V.NAMES.tank.get(arsenal, "Tank")
	check(mine("tank").size() == tanks + 1 and w.unit_defs.tank.name == own_name, "%s: the tank factory turns out its own tank, the %s" % [id, w.unit_defs.tank.name])
	# 5: research advances.
	var r: Node = w.research
	var project := ""
	for k in r.discoveries:
		if r.blocker(k) == "" and not r.done(k) and r.def_of(k).get("reqBuilding") == null:
			project = k
			break
	r.enqueue(project)
	r.points = 5000.0
	var stage0: int = r.stage_of(project)
	for i in range(40): r.tick(1.0)
	check(project != "" and r.stage_of(project) > stage0, "%s: research advances (%s, stage %d)" % [id, project, r.stage_of(project)])
	# 6: its national power works.
	var power: Dictionary = Powers.power_of(w, 0)
	w.economy.res.money = maxf(w.economy.res.money, 5000.0)
	w.diplomacy.declare_war(1, 2)   # a war for a mediator (Turkiye) to end
	meet_needs(id)
	var target := -1
	if not power.is_empty() and power.target:
		for n in range(1, w.diplomacy.n):
			if Powers.blocked(w, 0, n) == "":
				target = n
				break
	var said: String = Powers.use(w, 0, target) if not power.is_empty() else "no power"
	check(not power.is_empty() and Powers.ready_in(w, 0) > 0.0, "%s: its national power is used and recharges (%s)" % [id, said.substr(0, 70)])
	# 7: a tank drives across country.
	var inward: Vector3 = (Vector3.ZERO - hq().root.position).normalized()
	var short := INF
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0]:
		var dir: Vector3 = inward.rotated(Vector3.UP, turn)
		var a: Vector3 = dry(hq().root.position + dir * 45.0)
		var b: Vector3 = dry(hq().root.position + dir * 135.0)
		var route: PackedVector3Array = w.path_between(a, b)
		if route.is_empty() or Vector2(route[-1].x - b.x, route[-1].z - b.z).length() > 4.0: continue
		short = drive(a, b)
		break
	check(short < 12.0, "%s: a tank drives 90 m across the country (%d m short)" % [id, int(short)])

# ---------------------------------------------------------------- part two

func pangaea_checks() -> void:
	await load_match({"map": "pangaea", "players": 6, "nation": 0, "style": "standard"}, "normal")
	seed(424242)
	print("== Pangaea, six nations")
	w.economy.grant_test_resources()
	w.economy.res.money = 200000.0
	# Land bought beside the capital (before the test grants the rest).
	w.territory.tick()
	var cells0: int = int(w.territory.yields(0).cells)
	var options: Array = w.territory.purchase_candidates(hq())
	var bought: String = w.territory.purchase(hq(), options[0]) if not options.is_empty() else "nothing to buy"
	w.territory.tick()
	check(int(w.territory.yields(0).cells) > cells0, "land is bought beside the capital (%s)" % bought)
	grant_land(7)
	var tile: float = w.NAV_TILE * w.NAV_STEP
	var half: float = float(w.map.mapSize) * 0.5
	# 1-5: marches across tile borders.
	var crossings := 0
	var arrived := 0
	var tries := 0
	var base: Vector3 = hq().root.position
	for k in range(12):
		if crossings >= 5: break
		var a: Vector3 = dry(base + Vector3.FORWARD.rotated(Vector3.UP, k * 0.55) * 60.0)
		var b: Vector3 = dry(base + Vector3.FORWARD.rotated(Vector3.UP, k * 0.55) * 190.0)
		var ta := Vector2i(int((a.x + half) / tile), int((a.z + half) / tile))
		var tb := Vector2i(int((b.x + half) / tile), int((b.z + half) / tile))
		var route: PackedVector3Array = w.path_between(a, b)
		if ta == tb or route.is_empty() or Vector2(route[-1].x - b.x, route[-1].z - b.z).length() > 4.0: continue
		crossings += 1
		var short: float = drive(a, b, 90.0)
		check(short < 12.0, "Pangaea: a tank crosses from walk tile %s to %s (%d m short)" % [str(ta), str(tb), int(short)])
	while crossings < 5:
		crossings += 1
		check(false, "Pangaea: a route across walk tiles to drive")
	# 6-7: a new building on a tile border blocks the way through it.
	var border_x: float = floorf((base.x + half) / tile) * tile - half
	var spot := Vector3.INF
	for dz in range(-120, 121, 12):
		var p: Vector3 = w.snap_to_hex(Vector3(border_x, 0, base.z + dz))
		if absf(p.x - border_x) < 8.0 and w.site_problem("barracks", p, 0) == "" and p.distance_to(base) > 40.0:
			spot = p
			break
	if spot == Vector3.INF:
		spot = w.snap_to_hex(base + Vector3(60, 0, 0))
	var block: Dictionary = w.place_building("barracks", spot, 0, true)
	w.close_navigation(block.root.position, block.footprint)
	# The navigation server takes in the changed tile a few frames later.
	var nav_map: RID = w.get_world_3d().navigation_map
	var it0: int = NavigationServer3D.map_get_iteration_id(nav_map)
	for i in range(120):
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) > it0 + 1: break
	var west: Vector3 = dry(spot + Vector3(-22, 0, 0))
	var east: Vector3 = dry(spot + Vector3(22, 0, 0))
	var through: PackedVector3Array = w.path_between(west, east)
	var inside := 0
	for p in through:
		if Vector2(p.x - spot.x, p.z - spot.z).length() < block.footprint * 0.4: inside += 1
	check(not w.open_ground(spot), "a new building closes the walk grid under it, on a tile border too")
	check(not through.is_empty() and inside == 0, "and routes go round it, not through it (%d points inside)" % inside)
	# 8-12: rivals build for three minutes; every capital stays reachable.
	var before := {}
	for n in w.ai.nations: before[n.id] = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
	sim(180.0, true)
	for i in range(4): await physics_frame
	for n in w.ai.nations:
		var h = hq(n.id)
		var grew: int = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size() - before[n.id]
		var route: PackedVector3Array = w.path_between(dry(base + (h.root.position - base).normalized() * 40.0), dry(h.root.position + (base - h.root.position).normalized() * 40.0))
		check(grew > 0 and not route.is_empty(), "%s built %d buildings, and the road from your capital to it is still open" % [n.name.split(" · ")[0], grew])
	# 13-18: land.
	w.territory.tick()
	for owner in range(6):
		check(int(w.territory.yields(owner).cells) >= 5, "nation %d holds land (%d hexes)" % [owner, int(w.territory.yields(owner).cells)])
	# 19-20: the economy.
	check(w.economy.res.values().all(func(v): return not is_nan(v) and v >= 0.0), "your economy runs on the big map")
	check(w.ai.nations.all(func(n): return n.money >= -1.0), "no rival's treasury goes below zero")
	# 21-22: war: a wave comes, your troops answer.
	var foe: Dictionary = w.ai.nations[0]
	w.diplomacy.declare_war(foe.id, 0)
	foe.money = 20000.0
	for i in range(8): w.spawn_unit("tank", w.land_point(hq(foe.id).root.position, 30.0), foe.id)
	foe.next_attack = 0.0
	var closing := func(): return w.units.any(func(u): return u.owner == foe.id and not u.dead and u.node.position.distance_to(base) < 200.0)
	sim(320.0, true, closing)
	check(closing.call(), "a rival at war sends its army to you across the continent")
	var guard: Array = []
	for i in range(6): guard.append(w.spawn_unit("tank", dry(base + Vector3(0, 0, 25)), 0))
	var fought := func(): return guard.any(func(u): return u.enemy != null or u.dead)
	sim(90.0, true, func(): return fought.call())
	check(fought.call(), "your troops take on the invaders")
	# 23: peace.
	w.diplomacy.set_score(0, foe.id, 60.0)
	var offers := 0
	while w.diplomacy.at_war(0, foe.id) and offers < 15:
		w.diplomacy.offer_peace(foe.id)
		offers += 1
	check(not w.diplomacy.at_war(0, foe.id), "peace is made (%d offers)" % offers)
	# 24-25: a trade pact, and a route.
	var partner: int = w.ai.nations[1].id
	w.diplomacy.set_score(0, partner, 60.0)
	w.diplomacy.propose_pact(partner)
	check(w.diplomacy.pact[0][partner], "a trade pact is signed")
	var port_at = find_site("port", 1, 12)
	if port_at != null: w.place_building("port", port_at, 0, true)
	w.economy.recalculate()
	var opened: String = w.market.open_route(partner, "iron", "export", 10)
	check(w.market.routes.any(func(r): return int(r.nation) == partner) or opened.contains("Port") or opened.contains("road"), "a trade route opens, or says what it needs (%s)" % opened)
	# 26-27: missiles from a silo.
	var silo_at = find_site("missileSilo", 1, 10)
	var silo: Dictionary = w.place_building("missileSilo", silo_at if silo_at != null else base + Vector3(30, 0, 30), 0, true)
	w.economy.recalculate()
	w.missiles.stock["cruise"] = 1
	var target_hq = hq(w.ai.nations[2].id)
	var hp0: float = target_hq.hp
	var launched: String = w.missiles.launch("cruise", target_hq.root.position)
	check(launched != "" and not launched.begins_with("No") and not launched.begins_with("Missiles launch"), "a cruise missile leaves the silo (%s)" % launched)
	sim(40.0, false, func(): return w.missiles.flying.is_empty())
	check(target_hq.hp < hp0 or target_hq.dead, "and strikes a far capital (%d -> %d)" % [int(hp0), int(maxf(target_hq.hp, 0.0))])
	# 28: spies.
	w.place_building("intelAgency", find_site("intelAgency", 1, 10), 0, true)
	w.economy.recalculate()
	w.espionage.recruit()
	var spy: String = w.espionage.run("openSources", w.ai.nations[3].id)
	check(w.espionage.missions.any(func(m): return int(m.nation) == w.ai.nations[3].id), "an agent is sent abroad (%s)" % spy.substr(0, 60))
	# 30-31: a road, and its traffic.
	var traffic: Node = w.get_children().filter(func(n): return n.get_script() == preload("res://scripts/route_traffic.gd"))[0]
	traffic.set_process(false)
	var road_ok := false
	for goal in [home() + Vector2i(-8, 3), home() + Vector2i(6, 5), home() + Vector2i(-3, -8), home() + Vector2i(8, -4)]:
		var route: Array = w.logistics.plan(home(), goal, 0, "road")
		if route.size() >= 6 and w.logistics.build(route, "road", 0):
			road_ok = true
			break
	check(road_ok, "a road is laid out into the country")
	traffic._sync()
	for i in range(900): traffic._process(1.0 / 30.0)
	var cars: Array = traffic._fleet.filter(func(c): return c.kind == "road")
	check(cars.size() >= 2 and cars.any(func(c): return c.s > 5.0), "cars drive on it (%d)" % cars.size())
	# 32-33: save and load.
	var count: int = w.buildings.filter(func(b): return not b.dead).size()
	check(w.saves.save("nations100"), "the six-nation match saves")
	var ok: bool = w.saves.load_slot("nations100")
	for i in range(30): await process_frame
	w = current_scene
	for i in range(30000):
		if w != null and w.get("nav_ready") == true: break
		await process_frame
		w = current_scene
	check(ok and w.map.nations.size() == 6 and absi(w.buildings.filter(func(b): return not b.dead).size() - count) <= 1, "and loads with its six nations and its towns")
	DirAccess.remove_absolute(w.saves.path_of("nations100"))
	for i in range(10): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		node.set_process(false)
	# 34: after loading, routes work (the walk grid is rebuilt in tiles).
	var a2: Vector3 = dry(hq().root.position + Vector3(40, 0, 40))
	var b2: Vector3 = dry(hq(w.ai.nations[1].id).root.position + (hq().root.position - hq(w.ai.nations[1].id).root.position).normalized() * 40.0)
	check(not w.path_between(a2, b2).is_empty(), "after loading, routes between capitals are found")
	# 35-37: the cost of it all.
	var times: Array[float] = []
	for i in range(450):
		var t0 := Time.get_ticks_usec()
		w._physics_process(DT)
		w.ai._physics_process(DT)
		for node in [w.economy, w.territory, w.market, w.diplomacy]:
			node._process(DT)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var mean := 0.0
	for t in times: mean += t / times.size()
	check(mean < 12.0, "a step costs %.1f ms on average (budget 12)" % mean)
	check(times[int(times.size() * 0.99) - 1] < 45.0, "and %.1f ms at the 99th percentile (budget 45)" % times[int(times.size() * 0.99) - 1])
	var t1 := Time.get_ticks_usec()
	var extra: Dictionary = w.place_building("farm", find_site("farm", 2, 10), 0, true)
	w.close_navigation(extra.root.position, extra.footprint)
	var build_ms := (Time.get_ticks_usec() - t1) / 1000.0
	check(build_ms < 25.0, "placing a building and updating the walk grid takes %.1f ms (budget 25)" % build_ms)

func run() -> void:
	for index in range(Factions.IDS.size()):
		await nation_checks(index)
	await pangaea_checks()
	print("\nGAMEPLAY_NATIONS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("GAMEPLAY_NATIONS PASS" if errors.is_empty() else "GAMEPLAY_NATIONS FAIL")
	quit(0 if errors.is_empty() else 1)
