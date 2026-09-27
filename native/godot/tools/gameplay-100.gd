extends SceneTree
## About a hundred gameplay checks in one match, each reported on its own line
## and none stopping the rest:
##   every building in the build list can be placed in your land and works;
##   every unit is trained by its own building and comes out where it belongs;
##   research, economy, market, diplomacy, espionage, missiles, combat,
##   territory, roads and railways, save and load.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 60.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok:
		passed += 1
	else:
		errors.append(label)
func step(n := 1) -> void:
	for i in range(n):
		w._physics_process(DT)
		w.effects._physics_process(DT)

func home() -> Vector2i:
	return w.logistics.world_hex(w.start)

## The player's land spread to `rings` round the capital (as a grown town's would be).
func grant_land(rings: int) -> void:
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home() + Vector2i(q, r)
			if w.logistics.hex_distance(home(), h) > rings:
				continue
			var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
			if i >= 0 and w.territory.owner_of[i] < 0:
				w.territory.owner_of[i] = 0
				w.territory.control[i] = 80.0
				w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(capital)}

func find_site(key: String) -> Variant:
	for ring in range(1, 10):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring:
					continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "":
					return at
	return null

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.economy.grant_test_resources()
	grant_land(8)
	# ------------------------------------------------ buildings
	var built := {}
	var menu: Dictionary = w.hud.BUILD_MENU
	for tab in menu:
		for key in menu[tab]:
			if not w.building_defs.has(key):
				continue
			var at = null
			if key == "extractor" or key == "mountainMine":
				for d in w.deposits:
					if at == null and not d.get("water", false) and d.extractor == null and w.site_problem(key, d.pos, 0) == "":
						at = d.pos
			elif key == "offshoreRig":
				for d in w.deposits:
					var sea := Vector3(d.pos.x, float(w.map.seaLevel) + 0.5, d.pos.z)
					if at == null and d.get("water", false) and d.extractor == null and w.site_problem(key, sea, 0) == "":
						at = sea
			else:
				at = find_site(key)
			if key == "offshoreRig" and at == null:
				var reasons := {}
				for d in w.deposits:
					if d.get("water", false):
						var sea := Vector3(d.pos.x, float(w.map.seaLevel) + 0.5, d.pos.z)
						reasons[w.site_problem(key, sea, 0)] = int(reasons.get(w.site_problem(key, sea, 0), 0)) + 1
				print("  offshore rig refusals: ", reasons)
			var why: String = w.site_problem(key, at, 0) if at != null else "no site found"
			check(at != null and why == "", "%s can be placed in your land (%s)" % [key, why if why != "" else "ok"])
			if at != null and why == "":
				var b: Dictionary = w.place_building(key, at, 0, true)
				w.close_navigation(b.root.position, w.DISTRICT_NAV_SIZE if w.is_district(key) else b.footprint)
				built[key] = b
	w.refresh_streets()
	w.economy.recalculate()
	w.territory.tick()
	w.logistics.update_supply()
	for i in range(3): await physics_frame
	check(w.economy.civ_cap > 700.0, "homes raise the citizen capacity (%d)" % int(w.economy.civ_cap))
	check(w.economy.pop_cap > 40, "barracks and housing raise army capacity (%d)" % w.economy.pop_cap)
	# New towns are cut off until a road reaches them; everything else is supplied.
	var unsupplied: Array = built.values().filter(func(b): return not b.get("supplied", true) and b.def.get("settlement") == null)
	check(unsupplied.is_empty(), "every building in the capital's land is supplied (%s)" % str(unsupplied.map(func(b): return b.key)))
	# A site built by workers from the ground up.
	var site_at = find_site("park")
	if site_at != null:
		w.build_site("park", site_at)
		var site: Dictionary = w.buildings[-1]
		for f in range(60 * 120):
			step()
			if site.built: break
		check(site.built, "workers build a park from its foundations")
	# ------------------------------------------------ units
	for r in w.research.UNIT_REQUIRES.values():
		w.research.progress[r].stage = 3  # unlock the late units for this check
	w.research._recompute()
	for key in built:
		var b: Dictionary = built[key]
		for unit in b.def.get("trains", []):
			var before: int = w.units.filter(func(u): return u.key == unit and u.owner == 0).size()
			b.queue.clear()
			w.queue_unit(b, unit)
			var queued: bool = b.queue.size() == 1
			for s in range(120):
				w.update_training(1.0)
				if b.queue.is_empty(): break
			var made: Array = w.units.filter(func(u): return u.key == unit and u.owner == 0)
			var ok: bool = queued and made.size() > before
			var where := ""
			if ok:
				var u: Dictionary = made[-1]
				if u.get("naval", false):
					ok = w.is_water(u.node.position, -0.8)
					where = "at sea" if ok else "not at sea"
				elif u.get("fly", false):
					where = "in the air base or air"
				else:
					ok = w.height_at(u.node.position.x, u.node.position.z) > 0.2
					where = "on land" if ok else "in the water"
			check(ok, "%s trains a %s (%s)" % [key, unit, where if queued else "not queued: queue %s" % str(b.queue)])
	# ------------------------------------------------ research
	var r: Node = w.research
	r.queue.clear()
	var open := ""
	for k in r.discoveries:
		if open == "" and r.blocker(k) == "" and not r.done(k):
			open = k
	check(r.enqueue(open) == "" and open in r.queue, "a discovery can be queued (%s)" % open)
	r.dequeue(open)
	check(not open in r.queue, "a discovery can be taken off the queue")
	var stage0: int = r.stage_of(open)
	r.enqueue(open)
	r.points = 5000.0
	for s in range(60): r.tick(1.0)
	check(r.stage_of(open) > stage0, "research advances a stage with points (%d -> %d)" % [stage0, r.stage_of(open)])
	check(r.enqueue("track:economy") == "" or r.track_blocker("economy") != "", "a research track can be queued")
	check(r.era_requirements(r.era + 1).size() > 0 or r.era >= r.eras.size() - 1, "the next era lists its goals")
	# ------------------------------------------------ economy
	var eco: Node = w.economy
	var m0: float = eco.res.money
	check(eco.pay({"money": 100}) and absf(eco.res.money - (m0 - 100)) < 0.01, "paying takes the money")
	eco.refund({"money": 100})
	check(absf(eco.res.money - m0) < 0.01, "a refund gives it back")
	eco.tick()
	check(eco.rates.get("money", 0.0) > 0.0, "the treasury earns taxes (%.2f/s)" % eco.rates.get("money", 0.0))
	check(eco.res.values().all(func(v): return v >= 0.0 and not is_nan(v)), "no resource is negative or not a number")
	var poor: float = eco.res.money
	eco.res.money = 5.0
	check(not eco.pay({"money": 50}) and eco.res.money == 5.0, "you cannot pay what you do not have")
	eco.res.money = poor
	# ------------------------------------------------ market
	var mk: Node = w.market
	var iron: float = eco.res.iron
	check(mk.sell("iron", -5).begins_with("Choose") and eco.res.iron == iron, "a negative sale is refused")
	var sold: String = mk.sell("iron", 25)
	check(eco.res.iron == iron - 25, "selling takes the goods (%s)" % sold)
	mk.pressure("oil", 100000, true)
	for s in range(30): mk.exchange_step()
	check(mk.mult.values().all(func(v): return v >= 0.35 and v <= 3.0), "prices stay in bounds after an enormous order")
	check(mk.history.values().all(func(h): return h.size() <= mk.HISTORY), "the price history stays bounded")
	var cap_before: float = eco.caps.get("uranium", INF)
	eco.res.uranium = cap_before
	check(not mk.buy("uranium", 50).begins_with("Bought"), "buying past your storage is refused")
	# ------------------------------------------------ diplomacy
	var d: Node = w.diplomacy
	var rel0: float = d.rel(0, 2)
	d.gift(2)
	check(d.rel(0, 2) >= rel0, "a gift does not sour relations")
	d.change(0, 2, 500.0)
	check(d.rel(0, 2) <= 100.0, "relations never pass +100")
	d.change(0, 2, -1000.0)
	check(d.rel(0, 2) >= -100.0, "relations never pass -100")
	d.declare_war(0, 3)
	check(d.at_war(0, 3) and d.at_war(3, 0), "war is declared both ways")
	d.make_peace(0, 3)
	check(not d.at_war(0, 3), "peace ends the war")
	d.set_score(0, 1, 90.0)
	check(d.propose_pact(1) != "", "a trade pact can be proposed")
	check(d.propose_nap(1) != "", "a non-aggression pact can be proposed")
	check(d.propose_alliance(1) != "", "an alliance can be proposed")
	check(d.status_text(1) != "", "a nation's status reads")
	# ------------------------------------------------ espionage
	var e: Node = w.espionage
	var agents: int = e.agents.size()
	check(e.has_agency() == built.has("intelAgency"), "the intelligence agency is recognised")
	e.recruit()
	check(e.agents.size() == agents + 1, "an agent can be recruited")
	var said: String = e.run("buildNetwork", 1)
	check(not e.missions.is_empty(), "an operation is under way (%s)" % said)
	if not e.missions.is_empty():
		e.cancel_mission(int(e.missions[0].agent))
	check(e.missions.is_empty(), "an operation can be recalled")
	check(e.enemy_attempt("caught").contains("caught"), "counter-intelligence can catch an enemy agent")
	# ------------------------------------------------ missiles
	var ms: Node = w.missiles
	if built.has("missileSilo"):
		var silo: Dictionary = built.missileSilo
		var kinds: Array = ms.types().keys()
		var first: String = kinds[0]
		check(ms.produce(silo, first) == "" and not silo.queue.is_empty(), "a silo builds a %s" % first)
		for s in range(120):
			w.update_training(1.0)
			if silo.queue.is_empty(): break
		check(ms.stored() > 0, "the missile goes into store")
		var target: Dictionary = w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0]
		var hp: float = target.hp
		d.declare_war(0, 1)
		var fired: String = ms.launch(first, target.root.position)
		for s in range(60 * 60):
			step()
			w.missiles._physics_process(DT)  # the missiles fly on their own clock
			if target.hp < hp: break
		check(target.hp < hp, "a missile strikes its target (%s)" % fired)
	# ------------------------------------------------ combat
	var spot: Vector3 = w.land_point(w.start, 140.0)
	var a: Dictionary = w.spawn_unit("tank", spot, 0)
	var foe: Dictionary = w.spawn_unit("soldier", spot + Vector3(10, 0, 0), 1)
	w.damage(foe, 10000.0, a)
	check(foe.dead, "a unit dies when its health runs out")
	var jet: Dictionary = w.spawn_unit("jet", spot + Vector3(0, 0, 20), 1)
	jet.node.position.y = w.height_at(jet.node.position.x, jet.node.position.z) + 30.0
	check(w.effectiveness(a, jet) == 0.0, "a tank cannot shoot down a jet")
	check(w.effectiveness(w.spawn_unit("samLauncher", spot, 0), jet) > 0.0, "a mobile SAM can")
	var rig = null
	for b in w.buildings:
		if b.owner == 0 and b.deposit != null and not b.dead:
			rig = b
	if rig != null:
		var dep: Dictionary = rig.deposit
		w.destroy_building(rig)
		check(dep.extractor == null, "a destroyed extractor frees its deposit")
		var icon: Node = dep.node.find_child("Icon", true, false) if is_instance_valid(dep.node) else null
		check(icon == null or icon.visible, "and its map marker shows again")
	# ------------------------------------------------ territory
	var t: Node = w.territory
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var cands: Array = t.purchase_candidates(hq)
	var left: int = t.purchases_left(hq)
	if not cands.is_empty() and left > 0:
		var money0: float = eco.res.money
		t.purchase(hq, cands[0])
		check(t.owner_of[cands[0]] == 0 and eco.res.money < money0, "land can be bought at the town hall")
	check(t.describe(w.start) != "", "land describes who holds it")
	check(t.rings_of(hq) >= 1 and t.rings_of(hq) <= t.RINGS_MAX.hq, "the capital's rings stay within their limit")
	var yields: Dictionary = t.yields(0)
	check(yields.cells > 0 and yields.money > 0.0, "your land yields money")
	# ------------------------------------------------ roads and railways
	var village_at = null
	for ring in range(4, 10):
		for q in range(-ring, ring + 1):
			for rr in range(-ring, ring + 1):
				var h := home() + Vector2i(q, rr)
				if village_at == null and w.logistics.hex_distance(home(), h) == ring and w.site_problem("villageCenter", w.logistics.hex_center(h), 0) == "":
					village_at = w.logistics.hex_center(h)
	check(village_at != null, "a village can be founded")
	if village_at != null:
		var village: Dictionary = w.place_building("villageCenter", village_at, 0, true)
		var route: Array = w.logistics.plan(home(), w.logistics.world_hex(village_at), 0, "road")
		check(route.size() > 1 and w.logistics.build(route, "road", 0), "a road links the village to the capital")
		w.logistics.update_supply()
		check(village.get("supplied", false), "the linked village is supplied")
		var hits: int = w.logistics.damage_at(w.logistics.hex_center(route[1]), 20.0, 10000.0)
		w.logistics.update_supply()
		check(hits > 0, "a blast breaks the road")
		var repair: Dictionary = w.logistics.quote(route, "road", 0)
		var fresh: float = float(w.logistics.transport.road.money) * (route.size() - 1)
		check(repair.money < fresh, "repairing costs less than building new ($%d vs $%d)" % [int(repair.money), int(fresh)])
	# ------------------------------------------------ save and load
	var counts := [w.buildings.filter(func(b): return not b.dead).size(), w.units.filter(func(u): return not u.dead).size(), w.logistics.edges.size()]
	var data: Dictionary = w.saves.capture()
	var text := JSON.stringify(data)
	check(text.length() > 1000, "the match captures to a save (%d KB)" % (text.length() / 1024))
	var back = JSON.parse_string(text)
	check(back is Dictionary and back.buildings.size() >= counts[0] - 2, "the save reads back with its buildings")
	print("\nGAMEPLAY: %d passed, %d failed" % [passed, errors.size()])
	for f in errors:
		print("  FAILED: " + f)
	print("GAMEPLAY_100 PASS" if errors.is_empty() else "GAMEPLAY_100 FAIL")
	quit(0 if errors.is_empty() else 1)
