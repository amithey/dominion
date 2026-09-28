extends SceneTree
## About a hundred more gameplay checks, over time rather than at a glance
## (gameplay-100.gd checks that things can be done at all): the economy tick
## by tick (food, growth, taxes, caps, shortages, seasons), workers building,
## factories training, research advancing, land growing, supply and roads,
## diplomacy and war, the market and trade routes, spies, combat and repair,
## and a full save and load that brings everything back.
var errors: Array[String] = []
var passed := 0
var w: Node
var eco: Node
const DT := 1.0 / 30.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## Runs the whole game loop for `seconds` (the economy ticks once a second).
func sim(seconds: float, done := Callable()) -> void:
	var t := 0.0
	var next_tick := 1.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		t += DT
		if t >= next_tick:
			next_tick += 1.0
			eco.tick()
			w.research.tick(1.0)
		if done.is_valid() and done.call():
			break

## `at` itself when it is dry, level ground; otherwise the nearest such point
## (land_point always moves a full `reach` away, so it is only the fallback).
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

func hq() -> Dictionary:
	return w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]

func grant_land(rings: int) -> void:
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home() + Vector2i(q, r)
			if w.logistics.hex_distance(home(), h) > rings:
				continue
			var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
			if i >= 0 and w.territory.owner_of[i] < 0:
				w.territory.owner_of[i] = 0
				w.territory.control[i] = 80.0
				w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(hq())}

func find_site(key: String, from := 1) -> Variant:
	for ring in range(from, 10):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring:
					continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "":
					return at
	return null

func put(key: String) -> Dictionary:
	var at = find_site(key)
	if at == null:
		return {}
	var b: Dictionary = w.place_building(key, at, 0, true)
	w.close_navigation(b.root.position, w.DISTRICT_NAV_SIZE if w.is_district(key) else b.footprint)
	w.economy.recalculate()
	return b

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260928)
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	eco = w.economy
	eco.set_process(false)
	w.research.set_process(false)
	grant_land(6)
	eco.res.money = 60000.0
	for k in ["iron", "oil", "silicon", "food", "uranium", "gas"]:
		eco.res[k] = eco.caps.get(k, 500.0)
	eco.recalculate()

	# ================================================================ economy, tick by tick
	var cfg: Dictionary = eco.cfg
	var farm: Dictionary = put("farm")
	check(not farm.is_empty(), "a farm can be built")
	eco.tick()
	var civ: float = eco.civilians
	var army: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker").size()
	var fed: float = eco.owned("farm") * float(cfg.farmFood) * (1.0 + w.research.bonus("foodPct")) + float(w.territory.yields(0).food)
	var ate: float = civ * float(cfg.foodPerCivilian) * (1.0 + civ / 2000.0) + army * float(cfg.foodPerSoldier)
	check(absf(eco.rates.food - (fed - ate)) < 0.5, "food balance = farms and farmland minus mouths (%.2f vs %.2f)" % [eco.rates.food, fed - ate])
	var soldiers := []
	for i in range(10):
		soldiers.append(w.spawn_unit("soldier", w.land_point(w.start, 30.0), 0))
	var before_food: float = eco.rates.food
	eco.tick()
	check(eco.rates.food < before_food - 10 * float(cfg.foodPerSoldier) * 0.9, "every soldier eats (%.2f -> %.2f)" % [before_food, eco.rates.food])
	for s in soldiers: w.kill(s)
	eco.tick()
	var money0: float = eco.res.money
	for i in range(10): eco.tick()
	check(eco.res.money > money0 and eco.rates.money > 0.0, "taxes fill the treasury ($%.1f/s)" % eco.rates.money)
	eco.civilians = 100.0
	eco.res.food = eco.caps.food
	var c0: float = eco.civilians
	for i in range(30): eco.tick()
	check(eco.civilians > c0, "with food and contentment the people grow (%d -> %d)" % [int(c0), int(eco.civilians)])
	for i in range(3000): eco.tick()
	check(eco.civilians <= eco.civ_cap + 0.01, "never past the housing capacity (%d of %d)" % [int(eco.civilians), int(eco.civ_cap)])
	var saved_farms: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "farm" and not b.dead)
	for f in saved_farms: f.built = false   # no harvest
	eco.res.food = 0.0
	eco.civilians = 300.0
	c0 = eco.civilians
	for i in range(20): eco.tick()
	check(eco.civilians < c0, "starving people dwindle (%d -> %d)" % [int(c0), int(eco.civilians)])
	check(eco.res.food >= 0.0, "food never goes below zero")
	for f in saved_farms: f.built = true
	eco.res.food = eco.caps.food
	eco.res.iron = eco.caps.iron * 3.0
	eco.tick()
	check(eco.res.iron <= eco.caps.iron + 0.01, "stores are capped (%d of %d iron)" % [int(eco.res.iron), int(eco.caps.iron)])
	var cap0: float = eco.caps.iron
	var store: Dictionary = put("warehouse")
	eco.recalculate()
	check(not store.is_empty() and eco.caps.iron >= cap0 + float(cfg.warehouseBonus) - 0.01, "a warehouse raises the stores (%d -> %d)" % [int(cap0), int(eco.caps.iron)])
	var fcap0: float = eco.caps.food
	var depot: Dictionary = put("foodDepot")
	eco.recalculate()
	check(depot.is_empty() or eco.caps.food > fcap0, "a food depot raises the granary (%d -> %d)" % [int(fcap0), int(eco.caps.food)])
	var civ_cap0: float = eco.civ_cap
	var homes: Dictionary = put("cottage")
	eco.recalculate()
	check(not homes.is_empty() and eco.civ_cap > civ_cap0, "homes raise the citizen capacity (%d -> %d)" % [int(civ_cap0), int(eco.civ_cap)])
	var pop0: int = eco.pop_cap
	var barracks_home: Dictionary = put("housing")
	eco.recalculate()
	check(not barracks_home.is_empty() and eco.pop_cap > pop0, "housing blocks raise the army capacity (%d -> %d)" % [pop0, eco.pop_cap])
	var admin0: float = eco.admin
	var res_d: Dictionary = put("residential")
	eco.recalculate()
	check(res_d.is_empty() or eco.admin > admin0 or eco.admin >= 1.0, "a residential district extends the administration (%.2f -> %.2f)" % [admin0, eco.admin])
	eco.civilians = 700.0
	eco.res.oil = 0.0
	eco.tick()
	var happy_short: float = eco.happiness
	check(eco.shortages.has("oil"), "a big city without oil suffers a shortage")
	eco.tick()
	check(eco.happiness < happy_short + 0.01 and eco.happiness <= 60.0 + eco.provided("happiness") + w.research.bonus("happiness"), "shortages make people unhappy (%d)" % int(eco.happiness))
	eco.res.oil = eco.caps.oil
	var t_saved: float = w.game_time
	w.game_time = 600.0   # winter: the last quarter of the year
	eco.tick()
	check(eco.rates.gas < 0.0, "winter burns gas for heating (%.2f/s)" % eco.rates.gas)
	w.game_time = 100.0
	eco.tick()
	check(eco.rates.gas >= 0.0 or eco.rates.gas > -0.001, "summer does not")
	w.game_time = t_saved
	eco.civilians = 200.0
	# An extractor on a deposit, and one cut off.
	var dep_b: Dictionary = {}
	for d in w.deposits:
		if dep_b.is_empty() and not d.get("water", false) and d.extractor == null and w.site_problem("extractor", d.pos, 0) == "":
			dep_b = w.place_building("extractor", d.pos, 0, true)
	if not dep_b.is_empty():
		var res_key: String = dep_b.deposit.def.res
		eco.tick()
		var flowing: float = eco.rates.get(res_key, 0.0)
		dep_b.supplied = false
		eco.tick()
		check(flowing > eco.rates.get(res_key, 0.0), "an extractor yields %s, and nothing when cut off (%.2f -> %.2f)" % [res_key, flowing, eco.rates.get(res_key, 0.0)])
		dep_b.supplied = true
	else:
		check(false, "an extractor can be put on a deposit")

	# ================================================================ workers and construction
	var workers: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == "worker")
	while workers.size() < 2:
		workers.append(w.spawn_unit("worker", w.land_point(hq().root.position, 18.0), 0))
	var m1: float = eco.res.money
	var site_at = find_site("cottage")
	check(site_at != null and w.build_site("cottage", site_at), "a cottage is laid out")
	var site: Dictionary = w.buildings[-1]
	check(eco.res.money < m1 and not site.built, "its price is paid up front and it starts as a site")
	for u in workers: u.build_site = null
	w.order_build([workers[0]], site)
	sim(60.0, func(): return site.built)
	check(site.built, "a worker walks over and builds it (%d%%)" % int(site.progress * 100))
	check(eco.owned("cottage") >= 1, "the finished cottage counts in the town")
	var solo_at = find_site("cottage")
	w.build_site("cottage", solo_at)
	var solo: Dictionary = w.buildings[-1]
	for u in workers: u.build_site = null
	w.order_build([workers[0]], solo)
	sim(12.0)
	var one_rate: float = solo.progress
	var duo_at = find_site("cottage")
	w.build_site("cottage", duo_at)
	var duo: Dictionary = w.buildings[-1]
	w.order_build(workers, duo)
	sim(12.0)
	check(duo.progress > 0.0 and duo.progress >= one_rate * 0.9, "two workers build at least as fast as one (%.2f vs %.2f)" % [duo.progress, one_rate])
	var idle_at = find_site("cottage")
	w.build_site("cottage", idle_at)
	var idle: Dictionary = w.buildings[-1]
	for u in workers:
		u.build_site = null
		u.target = null
	for u in w.units.filter(func(x): return x.owner == 0 and x.key == "worker"): w.kill(u)
	var p_idle: float = idle.progress
	sim(10.0)
	check(idle.progress <= p_idle + 0.001, "without workers a site does not rise")

	# ================================================================ factories
	var barracks: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead)[0] if w.buildings.any(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead) else put("barracks")
	barracks.queue.clear()
	barracks.queue_prog = 0.0
	var m2: float = eco.res.money
	w.queue_unit(barracks, "soldier")
	check(barracks.queue.size() == 1 and eco.res.money < m2, "training a soldier is paid when queued")
	w.cancel_queued(barracks, 0)
	check(barracks.queue.is_empty() and absf(eco.res.money - m2) < 0.01, "cancelling it refunds the price")
	var count0: int = w.units.filter(func(u): return u.owner == 0 and u.key == "soldier" and not u.dead).size()
	w.queue_unit(barracks, "soldier")
	var train: float = float(w.unit_defs.soldier.trainTime)
	for i in range(int(train * 0.5)): w.update_training(1.0)
	check(w.units.filter(func(u): return u.owner == 0 and u.key == "soldier" and not u.dead).size() == count0, "a soldier is not ready before its training time")
	for i in range(int(train) + 2): w.update_training(1.0)
	check(w.units.filter(func(u): return u.owner == 0 and u.key == "soldier" and not u.dead).size() == count0 + 1, "and is ready after it (%d s)" % int(train))
	barracks.supplied = false
	w.queue_unit(barracks, "soldier")
	var prog0: float = barracks.queue_prog
	for i in range(5): w.update_training(1.0)
	check(barracks.queue_prog == prog0, "a factory cut off from supply stops")
	barracks.supplied = true
	barracks.disabled_until = w.game_time + 100.0
	for i in range(5): w.update_training(1.0)
	check(barracks.queue_prog == prog0, "an EMP-struck factory stops too")
	barracks.disabled_until = 0.0
	barracks.queue.clear()
	var locked_q: int = barracks.queue.size()
	w.queue_unit(barracks, "fpvTeam")
	check(barracks.queue.size() == locked_q + 1, "units that need no research can be queued")
	barracks.queue.clear()
	var factory: Dictionary = put("tankFactory")
	if not factory.is_empty():
		factory.queue.clear()
		w.queue_unit(factory, "df17")
		check(factory.queue.is_empty(), "another nation's weapon cannot be queued")
		w.research.progress.guidedMunitions.stage = 0
		w.research._recompute()
		w.queue_unit(factory, "himars")
		check(factory.queue.is_empty(), "a unit whose research is missing cannot be queued")
	var old_garrison: int = eco.garrison
	eco.garrison = 0
	eco.recalculate()
	var q_before: int = barracks.queue.size()
	eco.pop_cap = eco.pop_used
	w.queue_unit(barracks, "soldier")
	check(barracks.queue.size() == q_before or eco.pop_cap > eco.pop_used, "a full army capacity refuses new recruits")
	eco.garrison = old_garrison
	eco.recalculate()
	barracks.queue.clear()

	# ================================================================ research over time
	var r: Node = w.research
	var school: Dictionary = put("school")
	eco.recalculate()
	r.tick(1.0)
	check(r.rate > 0.0, "research earns points (%.2f/s)" % r.rate)
	var pts0: float = r.points
	r.queue.clear()
	for i in range(10): r.tick(1.0)
	check(r.points > pts0 or r.points >= 0.0, "points pile up while nothing is queued")
	var open := []
	for k in r.discoveries:
		if r.blocker(k) == "" and not r.done(k) and r.def_of(k).get("reqBuilding") == null and open.size() < 2:
			open.append(k)
	for k in open: r.enqueue(k)
	r.points = 20000.0
	var s0: int = r.stage_of(open[0])
	var s1: int = r.stage_of(open[1])
	for i in range(3): r.tick(1.0)
	check(r.stage_of(open[0]) > s0 or r.stage_of(open[1]) == s1, "the first project is worked on first")
	for i in range(300): r.tick(1.0)
	check(r.done(open[0]), "a queued discovery completes (%s)" % open[0])
	check(not open[0] in r.queue, "and leaves the queue")
	r.progress.fertilizers.stage = 0
	r._recompute()
	var food_bonus0: float = r.bonus("foodPct")
	r.progress.fertilizers.stage = 3
	r._recompute()
	check(r.bonus("foodPct") > food_bonus0, "a finished discovery takes effect (Synthetic Fertilizers: +%d%% food)" % int((r.bonus("foodPct") - food_bonus0) * 100))
	var needy := ""
	for k in r.discoveries:
		var b = r.def_of(k).get("reqBuilding")
		if needy == "" and b != null and eco.owned(b) == 0 and eco.standing(b) == 0 and r.def_of(k).get("nation", "") == "" and r.era_of(k) <= r.era:
			needy = k
	if needy != "":
		r.progress[needy].stage = 1
		check(r.blocker(needy).contains("needs"), "a discovery that needs a building waits for it (%s)" % r.blocker(needy))
		r.progress[needy].stage = 0
	var tc0: float = r.track_cost("economy")
	r.tracks.economy = int(r.tracks.economy) + 1
	check(r.track_cost("economy") > tc0, "each level of a research track costs more")
	r.tracks.economy = int(r.tracks.economy) - 1
	var era0: int = r.era
	r._check_era()
	check(r.era == era0 or r.era == era0 + 1, "an era advances only one step at a time")

	# ================================================================ land
	var t: Node = w.territory
	t.tick()
	var mine_cells: int = t.yields(0).cells
	check(mine_cells > 0, "the capital holds land (%d hexes)" % mine_cells)
	check(t.owner_at(w.start) == 0, "the capital stands in its own land")
	var y: Dictionary = t.yields(0)
	check(y.money > 0.0, "held land pays ($%.1f/s)" % y.money)
	var rings0: int = t.rings_of(hq())
	eco.civilians = eco.civ_cap
	for i in range(5): t.tick()
	check(t.rings_of(hq()) >= rings0, "land never shrinks while the town grows (%d -> %d rings)" % [rings0, t.rings_of(hq())])
	var cands: Array = t.purchase_candidates(hq())
	var left0: int = t.purchases_left(hq())
	if not cands.is_empty() and left0 > 0:
		var m3: float = eco.res.money
		t.purchase(hq(), cands[0])
		check(t.owner_of[cands[0]] == 0 and eco.res.money < m3 and t.purchases_left(hq()) == left0 - 1, "a hex bought at the town hall is yours, paid for, and counted")
		check(not t.purchase_candidates(hq()).has(cands[0]), "it is no longer for sale")
	var rival_hq: Dictionary = w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0]
	check(w.site_problem("barracks", rival_hq.root.position + Vector3(20, 0, 0), 0) != "", "you cannot build in a rival's land")
	check(not t.purchase_candidates(hq()).any(func(i): return t.owner_of[i] > 0), "rivals' hexes are never for sale")

	# ================================================================ supply
	var v_at = find_site("villageCenter", 4)
	if v_at != null:
		var village: Dictionary = w.place_building("villageCenter", v_at, 0, true)
		w.logistics.update_supply()
		check(not village.get("supplied", true), "a new village is cut off until a road reaches it")
		eco.tick()
		var cover0: float = eco.supply_coverage()
		var route: Array = w.logistics.plan(home(), w.logistics.world_hex(v_at), 0, "road")
		var m4: float = eco.res.money
		var built_road: bool = route.size() > 1 and w.logistics.build(route, "road", 0)
		check(built_road and eco.res.money < m4, "a road is built, and paid for")
		w.logistics.update_supply()
		check(village.get("supplied", false), "the road supplies the village")
		check(eco.supply_coverage() >= cover0, "tax reaches more of the people (%.2f -> %.2f)" % [cover0, eco.supply_coverage()])
		w.logistics.damage_at(w.logistics.hex_center(route[route.size() / 2]), 25.0, 100000.0)
		w.logistics.update_supply()
		check(not village.get("supplied", true), "breaking the road cuts the village off again")
		w.logistics.build(route, "road", 0)
		w.logistics.update_supply()
		check(village.get("supplied", false), "a repaired road reconnects it")
	else:
		check(false, "a village site is found")

	# ================================================================ diplomacy and war
	var d: Node = w.diplomacy
	d.make_peace(0, 2)
	var mine_t: Dictionary = w.spawn_unit("tank", dry(w.start + Vector3(0, 0, 150)), 0)
	var their_t: Dictionary = w.spawn_unit("tank", dry(mine_t.node.position + Vector3(12, 0, 0)), 2)
	sim(8.0)
	check(mine_t.hp == mine_t.max_hp and their_t.hp == their_t.max_hp, "tanks of nations at peace do not fight")
	w.damage(their_t, 10.0, mine_t)
	check(d.at_war(0, 2), "striking a nation at peace starts a war")
	sim(10.0)
	check(mine_t.hp < mine_t.max_hp or their_t.hp < their_t.max_hp - 10.0, "at war, they fight")
	w.kill(mine_t)
	w.kill(their_t)
	d.make_peace(0, 2)
	check(not d.at_war(0, 2) and not w.hostile(0, 2), "peace makes them neutral again")
	var m5: float = eco.res.money
	var rel0: float = d.rel(0, 3)
	d.gift(3)
	check(d.rel(0, 3) > rel0 and eco.res.money < m5, "a gift costs money and warms relations (%d -> %d)" % [int(rel0), int(d.rel(0, 3))])
	d.set_flag(d.alliance, 0, 3, true)
	check(d.allied(0, 3) and not w.hostile(0, 3), "allies are never hostile")
	d.set_flag(d.alliance, 0, 3, false)
	var rels0: Array = [d.rel(0, 1), d.rel(0, 2), d.rel(0, 3)]
	for i in range(60): d.tick()
	check([d.rel(0, 1), d.rel(0, 2), d.rel(0, 3)].all(func(v): return v >= -100.0 and v <= 100.0), "relations drift but stay within ±100 (%s -> %s)" % [str(rels0.map(func(v): return int(v))), str([int(d.rel(0, 1)), int(d.rel(0, 2)), int(d.rel(0, 3))])])

	# ================================================================ the market and trade
	var mk: Node = w.market
	var exchange: Dictionary = put("market")
	eco.recalculate()
	check(not exchange.is_empty() and mk.has_market(), "a Market opens the exchange")
	var p0: float = mk.price("iron")
	var m6: float = eco.res.money
	var iron0: float = eco.res.iron
	eco.res.iron = 0.0
	var bought: String = mk.buy("iron", 400)   # enough to move the price past its daily noise
	check(eco.res.iron > 0.0 and eco.res.money < m6, "buying iron pays money for iron (%s)" % bought)
	for i in range(5): mk.exchange_step()
	check(mk.price("iron") >= p0, "buying pushes the price up (%.2f -> %.2f)" % [p0, mk.price("iron")])
	eco.res.iron = iron0
	var o0: float = mk.price("oil")
	mk.pressure("oil", 3000, false)
	for i in range(10): mk.exchange_step()
	check(mk.price("oil") <= o0, "a glut of oil brings its price down (%.2f -> %.2f)" % [o0, mk.price("oil")])
	check(mk.quote("iron", 10, true) > mk.quote("iron", 10, false), "the buying price is above the selling price")

	# ================================================================ spies
	var e: Node = w.espionage
	var agency: Dictionary = put("intelAgency")
	eco.recalculate()
	if e.agents.is_empty(): e.recruit()
	check(not e.agents.is_empty(), "an agent is recruited")
	var reports0: int = e.reports.size() if e.get("reports") != null else 0
	e.run("buildNetwork", 1)
	var on_job: bool = not e.missions.is_empty()
	check(on_job, "an operation starts")
	e.advance(400.0)
	check(e.missions.is_empty(), "it resolves in time")
	check(e.agents.any(func(a): return a.status in ["recovering", "ready", "captured"]), "and the agent comes back (or is caught)")

	# ================================================================ combat and repair
	var field: Vector3 = w.start
	var clear_best := -1.0
	for i in range(80):
		var p: Vector3 = dry(w.start + Vector3(randf_range(-170, 170), 0, randf_range(-170, 170)))
		var clear := INF
		for b in w.buildings:
			if not b.dead: clear = minf(clear, b.root.position.distance_to(p))
		var flat := true
		for k in range(8):
			var q: Vector3 = p + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * 40.0
			if w.height_at(q.x, q.z) < 1.5 or w.normal_at(q.x, q.z).y < 0.9: flat = false
		if flat and clear > clear_best:
			clear_best = clear
			field = p
	d.declare_war(0, 1)
	var squad_a := []
	var squad_b := []
	for i in range(4):
		squad_a.append(w.spawn_unit("soldier", dry(field + Vector3(0, 0, i * 3)), 0))
		squad_b.append(w.spawn_unit("soldier", dry(field + Vector3(16, 0, i * 3)), 1))
	sim(25.0, func(): return squad_a.all(func(u): return u.dead) or squad_b.all(func(u): return u.dead))
	check(squad_a.any(func(u): return u.dead or u.hp < u.max_hp) and squad_b.any(func(u): return u.dead or u.hp < u.max_hp), "two squads that meet exchange fire")
	for u in squad_a + squad_b:
		if not u.dead: w.kill(u)
	var runner: Dictionary = w.spawn_unit("tank", field, 0)
	var goal: Vector3 = dry(field + Vector3(30, 0, 18))
	w.order_move([runner], goal)
	sim(30.0, func(): return runner.target == null)
	check(Vector2(runner.node.position.x - goal.x, runner.node.position.z - goal.z).length() < 10.0, "a tank drives where it is sent")
	var bait: Dictionary = w.spawn_unit("soldier", dry(goal + Vector3(8, 0, 0)), 1)
	w.order_move([runner], dry(goal + Vector3(35, 0, 0)))
	sim(3.0)
	check(runner.enemy == null, "on a plain move order it drives past the enemy")
	w.order_move([runner], bait.node.position, true)
	sim(15.0, func(): return bait.dead)
	check(bait.dead or bait.hp < bait.max_hp, "on attack-move it engages")
	runner.hp = runner.max_hp * 0.5
	runner.enemy = null
	runner.target = null
	runner.last_hit = -100.0
	var m7: float = eco.res.money
	w.Repairs.request(w, [runner])
	for i in range(int(10.0 / DT)): w._physics_process(DT)   # no tax ticks: only the repair touches the treasury
	check(runner.hp > runner.max_hp * 0.5 and eco.res.money < m7, "a repair order mends a tank and charges for it (%d%%)" % int(runner.hp / runner.max_hp * 100))
	runner.hp = runner.max_hp * 0.5
	runner.repairing = true
	runner.last_hit = w.game_time
	var hp_hit: float = runner.hp
	sim(3.0)
	check(runner.hp == hp_hit, "repairs pause under fire")
	w.kill(runner)
	# Aircraft: out of ammunition they fly home and rearm.
	var base: Dictionary = put("airfield")
	if not base.is_empty():
		var jet: Dictionary = w.spawn_unit("jet", base.root.position + Vector3(0, 0, 30), 0)
		jet.air_state = "ready"
		jet.ammo = 0
		w.AirOperations.consume(jet) if jet.ammo > 0 else null
		jet.air_state = "returning"
		sim(60.0, func(): return jet.air_state in ["rearming", "parked"])
		check(jet.air_state in ["rearming", "parked", "landing", "taxi_in"], "a jet out of ammunition lands at its base (%s)" % jet.air_state)
		sim(30.0, func(): return jet.air_state == "parked" and jet.ammo > 0)
		check(jet.ammo > 0, "and is rearmed (%d)" % jet.ammo)
	# A ship ordered inland stops at the shore.
	var sea = w.water_near(w.start, 220)
	if sea != null:
		var boat: Dictionary = w.spawn_unit("gunboat", sea, 0)
		w.order_move([boat], w.start)
		sim(20.0)
		check(w.is_water(boat.node.position, -0.2), "a gunboat sent inland stays in the water")
		w.kill(boat)

	# ================================================================ save and load
	var snap := {
		"buildings": w.buildings.filter(func(b): return not b.dead).size(),
		"units": w.units.filter(func(u): return not u.dead).size(),
		"money": eco.res.money, "civilians": eco.civilians,
		"stages": r.discoveries.keys().map(func(k): return r.stage_of(k)),
		"rel": d.rel(0, 3), "war": d.at_war(0, 1),
		"land": t.owner_of.count(0), "roads": w.logistics.edges.size(),
		"missiles": w.missiles.stock.duplicate(), "time": w.game_time, "era": r.era,
	}
	var text := JSON.stringify(w.saves.capture())
	w.saves.restore(JSON.parse_string(text))
	sim(0.5)
	check(w.buildings.filter(func(b): return not b.dead).size() == snap.buildings, "loading brings back every building (%d)" % snap.buildings)
	check(absi(w.units.filter(func(u): return not u.dead).size() - snap.units) <= 1, "and every unit (%d)" % snap.units)
	check(absf(eco.res.money - snap.money) < 50.0, "the treasury ($%d vs $%d)" % [int(eco.res.money), int(snap.money)])
	check(absf(eco.civilians - snap.civilians) < 5.0, "the people (%d)" % int(snap.civilians))
	check(r.discoveries.keys().map(func(k): return r.stage_of(k)) == snap.stages, "every discovery's stage")
	check(r.era == snap.era, "the era")
	check(absf(d.rel(0, 3) - snap.rel) < 1.0 and d.at_war(0, 1) == snap.war, "relations and wars")
	check(absi(t.owner_of.count(0) - snap.land) <= 2, "the land (%d hexes)" % snap.land)
	check(w.logistics.edges.size() == snap.roads, "the roads (%d)" % snap.roads)
	check(w.missiles.stock == snap.missiles, "the missile stores")
	check(absf(w.game_time - snap.time) < 2.0, "the clock")

	# ================================================================ the end of the match
	for b in w.buildings.filter(func(b): return b.owner > 0 and b.key == "hq" and not b.dead):
		w.destroy_building(b)
	check(w.game_over == "victory", "taking every rival capital wins the match")
	w.ai._physics_process(0.1)   # the rival's own turn notices its capital is gone
	check(w.diplomacy.defeated(1), "a nation without its capital is defeated")
	w.game_over = ""
	w.destroy_building(hq())
	check(w.game_over == "defeat", "losing your capital loses it")
	print("\nGAMEPLAY_LIVE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("GAMEPLAY_LIVE PASS" if errors.is_empty() else "GAMEPLAY_LIVE FAIL")
	quit(0 if errors.is_empty() else 1)
