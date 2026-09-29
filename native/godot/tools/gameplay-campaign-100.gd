extends SceneTree
## A hundred more gameplay checks.
## Part one: every map played at its full count of nations (each with a
## different nation, difficulty cycling easy, normal, hard): every nation in
## place, a worker builds, rivals grow, a warship sails, and the match comes
## back from a save as it was.
## Part two: one match played system by system over time: air power from a
## base, war at sea, missile defence, supply by road, people and seasons, the
## market, spies, alliances, repairs, and losing the capital.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Setup := preload("res://scripts/match_setup.gd")
const Catalogue := preload("res://scripts/map_catalogue.gd")
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

func mine(key: String) -> Array:
	return w.units.filter(func(u): return u.owner == 0 and u.key == key and not u.dead)

## Open water `reach` metres on from a sea point, in any direction.
func sea_leg(from: Vector3, reach: float) -> Variant:
	for k in range(16):
		var p: Vector3 = from + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0) * reach
		if w.is_water(p) and w.is_water(from.lerp(p, 0.5)):
			return p
	return null

# ---------------------------------------------------------------- part one

func map_checks(index: int, key: String) -> void:
	var players: int = Setup.capacity(key)
	var nation: int = index % 9
	var level: String = ["easy", "normal", "hard"][index % 3]
	await load_match({"map": key, "players": players, "nation": nation, "style": "standard"}, level)
	seed(hash(key))
	var name: String = Catalogue.entry(key).name
	print("== %s: %d nations, you lead %s, %s" % [name, players, w.map.nations[0].name, level])
	# 1: every nation in place.
	var ids := {}
	for n in w.map.nations: ids[str(n.get("id", ""))] = true
	var capitals: Array = w.buildings.filter(func(b): return b.key == "hq" and not b.dead)
	var dry: int = capitals.filter(func(b): return w.height_at(b.root.position.x, b.root.position.z) > 0.5).size()
	check(w.map.nations.size() == players and ids.size() == players and capitals.size() == players and dry == players, "%s: %d nations, each its own, each capital on land" % [name, players])
	# 2: a worker builds a cottage.
	w.economy.grant_test_resources()
	grant_land(4)
	var at = find_site("cottage", 1, 5)
	var built := false
	if at != null:
		for u in mine("worker"): u.build_site = null
		w.build_site("cottage", at)
		var site: Dictionary = w.buildings[-1]
		sim(90.0, false, func(): return site.built)
		built = site.built
	check(built, "%s: a worker builds a cottage" % name)
	# 3: rivals grow.
	var before := {}
	for n in w.ai.nations: before[n.id] = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
	sim(120.0, true)
	var grew: int = w.ai.nations.filter(func(n): return w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size() > before[n.id]).size()
	check(grew == w.ai.nations.size(), "%s: every rival builds up in two minutes (%d of %d)" % [name, grew, w.ai.nations.size()])
	# 4: a warship sails.
	var sea = w.water_near(w.start, 260)
	var leg = sea_leg(sea, 90.0) if sea != null else null
	var sailed := INF
	if leg != null:
		var ship: Dictionary = w.spawn_unit("corvette", sea, 0)
		w.order_move([ship], leg)
		sim(60.0, false, func(): return ship.target == null)
		sailed = Vector2(ship.node.position.x - leg.x, ship.node.position.z - leg.z).length()
		check(w.is_water(ship.node.position, -0.5) and sailed < 15.0, "%s: a corvette sails 90 m at sea (%d m short)" % [name, int(sailed)])
		w.kill(ship)
	else:
		check(false, "%s: open water near the capital for a corvette" % name)
	# 5: a save and back.
	var capital_hp: float = hq().hp
	var rel: float = w.diplomacy.rel(0, 1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(data)
	for i in range(5): await process_frame
	check(w.map.nations.size() == players and w.buildings.filter(func(b): return b.key == "hq" and not b.dead).size() == players and absf(w.diplomacy.rel(0, 1) - rel) < 0.2 and absf(hq().hp - capital_hp) < 1.0, "%s: the match comes back from a save as it was" % name)

# ---------------------------------------------------------------- part two

func systems_checks() -> void:
	await load_match({"map": "island", "players": 4, "nation": 2, "style": "standard"}, "normal")
	seed(90210)
	print("== systems, playing %s" % w.map.nations[0].name)
	var eco: Node = w.economy
	eco.grant_test_resources()
	eco.res.money = 500000.0
	eco.pop_cap = 500
	grant_land(8)
	var d: Node = w.diplomacy
	var foe := 1
	d.declare_war(foe, 0)
	var foe_hq: Dictionary = hq(foe)

	# ------------------------------------------------ air power (1-5)
	var field_at = find_site("airfield", 2, 9)
	var base: Dictionary = w.place_building("airfield", field_at, 0, true)
	w.logistics.update_supply()
	w.queue_unit(base, "jet")
	w.queue_unit(base, "jet")
	for i in range(int(120.0 / DT)):
		w.update_training(DT)
		if base.queue.is_empty(): break
	var jets: Array = mine("jet").filter(func(u): return is_same(u.get("air_base"), base))
	check(jets.size() == 2 and jets.all(func(u): return u.air_state == "parked"), "two jets are trained and park on the airfield (%d)" % jets.size())
	var jet: Dictionary = jets[0] if not jets.is_empty() else w.spawn_unit("jet", base.root.position, 0)
	var target: Dictionary = w.buildings.filter(func(b): return b.owner == foe and not b.dead and b.key != "hq")[0] if w.buildings.any(func(b): return b.owner == foe and not b.dead and b.key != "hq") else foe_hq
	var hp0: float = target.hp
	w.order_attack([jet], target)
	var states := {}
	for i in range(int(120.0 / DT)):
		w._physics_process(DT)
		w.effects._physics_process(DT)
		states[jet.air_state] = true
		if target.hp < hp0 and jet.air_state in ["returning", "landing", "taxi_in", "parked", "rearming"]: break
	check(states.has("takeoff") or states.has("taxi_out") or states.has("flying") or states.has("ready"), "a jet ordered to strike takes off (%s)" % str(states.keys()))
	check(target.hp < hp0 or target.dead, "and hits the %s (%d -> %d)" % [target.def.name, int(hp0), int(maxf(target.hp, 0.0))])
	var home_again := func(): return jet.dead or jet.air_state in ["landing", "taxi_in", "parked", "rearming"]
	sim(120.0, false, home_again)
	check(home_again.call(), "it flies home to its base (%s)" % jet.air_state)
	# On its slot the crews rearm it; with its strike order still standing it
	# then takes off again.
	var seen := {"rearmed": false}
	var cap: int = preload("res://scripts/air_operations.gd").CAPACITY.get("jet", 2)
	sim(90.0, false, func():
		if jet.air_state in ["rearming", "taxi_out"] and int(jet.get("ammo", 0)) >= cap: seen.rearmed = true
		return jet.dead or seen.rearmed)
	check(not jet.dead and seen.rearmed, "and is rearmed on the ground (ammo %d of %d)" % [int(jet.get("ammo", 0)), cap])

	# ------------------------------------------------ war at sea (6-9)
	var sea = w.water_near(w.start, 260)
	var far = sea_leg(sea, 50.0)
	var ours: Dictionary = w.spawn_unit("destroyer", sea, 0)
	var theirs: Dictionary = w.spawn_unit("corvette", far if far != null else sea + Vector3(40, 0, 0), foe)
	sim(90.0, false, func(): return theirs.dead)
	check(theirs.dead or theirs.hp < theirs.max_hp * 0.3, "a destroyer sinks an enemy corvette (%d left)" % int(maxf(theirs.hp, 0.0)))
	var sub: Dictionary = w.spawn_unit("submarine", sea, 0)
	var prey: Dictionary = w.spawn_unit("destroyer", far if far != null else sea + Vector3(40, 0, 0), foe)
	var prey0: float = prey.hp
	sim(45.0, false, func(): return prey.dead)
	check(prey.dead or prey.hp < prey0, "a submarine torpedoes an enemy destroyer (%d -> %d)" % [int(prey0), int(maxf(prey.hp, 0.0))])
	w.kill(prey)
	var inland: Vector3 = hq().root.position + (w.start - sea).normalized() * 20.0
	w.order_move([ours], inland)
	sim(30.0)
	check(w.is_water(ours.node.position, -0.5), "a warship ordered inland stays at sea")
	var coast: Vector3 = w.land_point(ours.node.position, 18.0)
	var shore: Dictionary = w.place_building("farm", coast, foe, true)
	var shore0: float = shore.hp
	w.order_attack([ours], shore)
	sim(40.0, false, func(): return shore.dead)
	check(shore.dead or shore.hp < shore0, "a destroyer shells a building on the coast (%d -> %d)" % [int(shore0), int(maxf(shore.hp, 0.0))])
	for u in [ours, sub]: w.kill(u)

	# ------------------------------------------------ missiles and defence (10-13)
	var sam_at = find_site("samSite", 1, 4)
	w.place_building("samSite", sam_at if sam_at != null else hq().root.position + Vector3(20, 0, 0), 0, true)
	var n0: int = w.intercepts.size()
	var hits := 0
	for i in range(6):
		var m: Dictionary = w.missiles.fly("cruise", foe_hq.root.position + Vector3.UP * 3.0, hq().root.position, foe)
		sim(20.0, false, func(): return not m in w.missiles.flying)
	var tries: Array = w.intercepts.slice(n0)
	hits = tries.filter(func(t): return t.hit).size()
	check(tries.size() >= 4 and hits >= 1, "a SAM site engages incoming cruise missiles (%d tries, %d down)" % [tries.size(), hits])
	w.research.progress.missileDefence.stage = 3
	w.research._recompute()
	var abm: Dictionary = w.spawn_unit("abmLauncher", w.land_point(hq().root.position, 18.0), 0)
	var n1: int = w.intercepts.size()
	var bm: Dictionary = w.missiles.fly("ballistic", foe_hq.root.position + Vector3.UP * 3.0, hq().root.position, foe)
	sim(25.0, false, func(): return not bm in w.missiles.flying)
	check(w.intercepts.slice(n1).any(func(t): return t.by == "abmLauncher"), "a missile defence battery engages a ballistic missile")
	var cap0: float = hq().hp
	var soak: Dictionary = w.missiles.fly("tactical", foe_hq.root.position + Vector3.UP * 3.0, hq().root.position + Vector3(4, 0, 4), foe)
	for u in w.units:
		if u.key == "abmLauncher" and u.owner == 0: w.kill(u)
	for b in w.buildings:
		if b.key == "samSite" and b.owner == 0: w.destroy_building(b)
	sim(25.0, false, func(): return not soak in w.missiles.flying)
	check(hq().hp < cap0, "a missile that gets through damages the capital (%d -> %d)" % [int(cap0), int(hq().hp)])
	var silo: Dictionary = w.place_building("missileSilo", find_site("missileSilo", 2, 9), 0, true)
	eco.recalculate()
	var stock0: int = int(w.missiles.stock.get("tactical", 0))
	w.missiles.produce(silo, "tactical")
	w.update_training(1.0)
	var early: int = int(w.missiles.stock.get("tactical", 0))
	for i in range(int(w.missiles.build_time("tactical")) + 3): w.update_training(1.0)
	check(early == stock0 and int(w.missiles.stock.get("tactical", 0)) == stock0 + 1, "a silo builds a missile in its time (%d s), not at once" % int(w.missiles.build_time("tactical")))

	# ------------------------------------------------ supply (14-17)
	var village_at: Vector3 = Vector3.INF
	for ring in range(6, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if village_at == Vector3.INF and w.logistics.hex_distance(home(), h) == ring and w.site_problem("villageCenter", w.logistics.hex_center(h), 0) == "":
					village_at = w.logistics.hex_center(h)
	var village: Dictionary = w.place_building("villageCenter", village_at, 0, true)
	var camp_at = null
	for dq in range(-1, 2):
		for dr in range(-1, 2):
			var p: Vector3 = w.logistics.hex_center(w.logistics.world_hex(village_at) + Vector2i(dq, dr))
			if camp_at == null and (dq != 0 or dr != 0) and w.site_problem("barracks", p, 0) == "": camp_at = p
	var camp: Dictionary = w.place_building("barracks", camp_at if camp_at != null else village_at + Vector3(20, 0, 0), 0, true)
	# The land round the village is the village's own (the test granted it to the capital).
	for key in w.territory.purchased.keys():
		if w.territory.center(int(key)).distance_to(village_at) < 60.0:
			w.territory.purchased[key].settlement = w.territory.settlement_key(village)
	w.territory.tick()
	var route: Array = w.logistics.plan(home(), w.logistics.world_hex(village_at), 0, "road")
	w.logistics.build(route, "road", 0)
	w.logistics.update_supply()
	check(camp.get("supplied", false), "a barracks in a village linked to the capital by road is supplied (%d links)" % (route.size() - 1))
	var cut: Dictionary = {}
	for e in w.logistics.edges.values():
		if e.owner == 0 and e.kind == "road" and e.a in route and e.b in route and e.a != home() and e.b != home():
			cut = e
			break
	cut.hp = 0.0
	cut.half = [0.0, 0.0]
	w.logistics.update_supply()
	check(not camp.get("supplied", true), "cut the road, and it is out of supply")
	var soldiers: int = mine("soldier").size()
	camp.queue.clear()
	w.queue_unit(camp, "soldier")
	for i in range(int(w.unit_defs.soldier.trainTime) + 4): w.update_training(1.0)
	check(mine("soldier").size() == soldiers, "and trains nothing while cut off")
	w.logistics.build(route, "road", 0)
	w.logistics.update_supply()
	for i in range(int(w.unit_defs.soldier.trainTime) + 4): w.update_training(1.0)
	check(camp.get("supplied", false) and mine("soldier").size() == soldiers + 1, "mend the road: supplied again, and the soldier is trained")

	# ------------------------------------------------ people and seasons (18-22)
	for i in range(3):
		var home_at = find_site("housing", 1, 8)
		if home_at != null: w.place_building("housing", home_at, 0, true)
	eco.recalculate()
	eco.res.food = eco.caps.food
	var people0: float = eco.civilians
	for i in range(60):
		eco.res.food = maxf(eco.res.food, eco.caps.food * 0.8)
		eco.tick()
	check(eco.civilians > people0, "with food and homes the people grow (%d -> %d)" % [int(people0), int(eco.civilians)])
	var happy0: float = eco.happiness
	var people1: float = eco.civilians
	for i in range(40):
		eco.res.food = 0.0
		eco.tick()
	check(eco.civilians <= people1 + 0.5 and eco.happiness <= happy0, "hungry, they stop growing and grow unhappy (%d%% -> %d%%)" % [int(happy0), int(eco.happiness)])
	eco.grant_test_resources()
	w.game_time = 100.0
	eco.tick()
	var summer_gas: float = eco.rates.get("gas", 0.0)
	w.game_time = 600.0
	eco.tick()
	var winter_gas: float = eco.rates.get("gas", 0.0)
	check(winter_gas < summer_gas, "winter homes burn gas (%.2f/s against %.2f/s in summer)" % [winter_gas, summer_gas])
	eco.res.gas = 0.0
	eco.tick()
	check("winter heating" in eco.shortages, "and without gas the winter is felt (%s)" % str(eco.shortages))
	w.game_time = 100.0
	eco.grant_test_resources()
	eco.tick()
	check(eco.rates.money > 0.0, "the people pay their way ($%.1f/s)" % eco.rates.money)

	# ------------------------------------------------ the market (23-25)
	w.place_building("market", find_site("market", 1, 9), 0, true)
	eco.recalculate()
	var m: Node = w.market
	var p0: float = m.price("iron")
	eco.res.money = 1e7
	eco.res.iron = 0.0   # room in the warehouses for what is bought
	var bought: String = m.buy("iron", 400)
	for i in range(5): m.buy("iron", 400)
	for i in range(3): m.exchange_step()
	var p_up: float = m.price("iron")
	check(p_up > p0 * 1.02 and bought.begins_with("Bought"), "buying up iron raises its price ($%.2f -> $%.2f; %s)" % [p0, p_up, bought])
	eco.res.iron = 1e5
	for i in range(12): m.sell("iron", 400)
	for i in range(3): m.exchange_step()
	var p_down: float = m.price("iron")
	check(p_down < p_up, "selling it off brings the price down ($%.2f)" % p_down)
	var gap0: float = absf(p_down - p0)
	for i in range(80): m.exchange_step()
	check(absf(m.price("iron") - p0) < gap0 + 0.01, "and the price drifts back toward its level ($%.2f)" % m.price("iron"))

	# ------------------------------------------------ spies (26-28)
	w.place_building("intelAgency", find_site("intelAgency", 1, 9), 0, true)
	eco.recalculate()
	var spies: Node = w.espionage
	spies.recruit()
	check(spies.ready_agents().size() >= 1, "an agent is recruited")
	var target_nation := 2
	var net0: float = float(spies.network.get(target_nation, 0.0))
	var said: String = spies.run("buildNetwork", target_nation, "", -1, 0.0)
	var reports0: int = spies.reports.size()
	for i in range(200): spies.advance(1.0)
	check(float(spies.network.get(target_nation, 0.0)) > net0, "a network is built abroad (%.0f -> %.0f; %s)" % [net0, float(spies.network.get(target_nation, 0.0)), said.substr(0, 40)])
	check(spies.reports.size() > reports0, "and the service reports it")

	# ------------------------------------------------ diplomacy (29-32)
	var friend := 3
	d.set_score(0, friend, 20.0)
	d.gift(friend)
	check(d.rel(0, friend) > 20.0, "a gift warms relations (%d)" % int(d.rel(0, friend)))
	d.set_score(0, friend, 80.0)
	var asks := 0
	while not d.allied(0, friend) and asks < 20:
		d.propose_alliance(friend)
		asks += 1
	check(d.allied(0, friend), "an alliance is formed (%d proposals)" % asks)
	var joined := false
	for i in range(20):
		d.set_score(0, friend, 90.0)
		d.request_joint_war(friend, foe)
		if d.at_war(friend, foe):
			joined = true
			break
	check(joined, "an ally joins your war")
	var calm := 2
	d.make_peace(0, calm)
	d.set_score(0, calm, 50.0)
	var tries_nap := 0
	while not d.nap[0][calm] and tries_nap < 20:
		d.propose_nap(calm)
		tries_nap += 1
	d.set_score(0, calm, -60.0)
	check(d.nap[0][calm] and not d.ai_wants_war(calm, 0), "a non-aggression pact holds even when relations sour")

	# ------------------------------------------------ repairs (33-34)
	var depot: Dictionary = w.place_building("warehouse", find_site("warehouse", 1, 9), 0, true)
	depot.hp = depot.max_hp * 0.5
	depot.last_hit = -100.0
	w.logistics.update_supply()
	var cash: float = eco.res.money
	preload("res://scripts/repairs.gd").request(w, [depot])
	for i in range(40): preload("res://scripts/repairs.gd").update(w, 0.25)
	check(depot.hp > depot.max_hp * 0.5 and eco.res.money < cash, "a damaged warehouse is repaired, and the repair is paid for (%d%%)" % int(100.0 * depot.hp / depot.max_hp))
	depot.hp = depot.max_hp * 0.5
	depot.repairing = true
	depot.last_hit = w.game_time
	var hp_hit: float = depot.hp
	for i in range(8): preload("res://scripts/repairs.gd").update(w, 0.25)
	check(depot.hp == hp_hit, "repairs wait while it is under fire")

	# ------------------------------------------------ losing the capital (35)
	w.destroy_building(hq())
	check(w.game_over == "defeat", "losing your capital loses the match (%s)" % w.game_over)

func run() -> void:
	var only_systems := "--systems" in OS.get_cmdline_user_args()
	for i in range(0 if only_systems else Catalogue.KEYS.size()):
		await map_checks(i, Catalogue.KEYS[i])
	await systems_checks()
	print("\nGAMEPLAY_CAMPAIGN: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("GAMEPLAY_CAMPAIGN PASS" if errors.is_empty() else "GAMEPLAY_CAMPAIGN FAIL")
	quit(0 if errors.is_empty() else 1)
