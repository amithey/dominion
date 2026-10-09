extends SceneTree
## A hundred checks on research (research.gd): the queue; the three stages of
## a discovery, their points, materials and minimum time; the research rate
## and what raises it; eras and their goals; the four tracks; what every
## discovery does once it is in service (measured in play, not read off a
## table); unlocks; rival research and what it gives them; national limits;
## saves; and the research tree on screen.
var errors: Array[String] = []
var passed := 0
var w: Node
var r: Node
var eco: Node
const DT := 1.0 / 15.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func load_match(cfg: Dictionary, difficulty := "normal") -> void:
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
	r = w.research
	eco = w.economy

## Puts discovery `key` into service (stage 3) or takes it out (0).
func set_stage(key: String, stage: int) -> void:
	r.progress[key].stage = stage
	r.progress[key].work = 0.0
	r.progress[key].paid = false
	r._recompute()
	eco.recalculate()

func fresh(key: String) -> Dictionary:
	var u: Dictionary = w.spawn_unit(key, w.land_point(w.start, 50.0), 0)
	return u

func income() -> float:
	eco.civ_cap = 5000.0
	eco.civilians = 400.0
	eco.tick()
	return eco.rates.money

func site(key: String) -> Variant:
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for s in range(-ring, ring + 1):
				var h := home + Vector2i(q, s)
				if w.logistics.hex_distance(home, h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "": return at
	return null

func grant_land(rings: int) -> void:
	var home: Vector2i = w.logistics.world_hex(w.start)
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	for q in range(-rings, rings + 1):
		for s in range(-rings, rings + 1):
			var h := home + Vector2i(q, s)
			if w.logistics.hex_distance(home, h) > rings: continue
			var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
			if i >= 0 and w.territory.owner_of[i] < 0:
				w.territory.owner_of[i] = 0
				w.territory.control[i] = 80.0
				w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(capital)}

func put(key: String) -> Dictionary:
	var at = site(key)
	return w.place_building(key, at if at != null else w.land_point(w.start, 70.0), 0, true)

func run() -> void:
	await load_match({"map": "island", "players": 4, "nation": 0, "style": "standard"})
	seed(31337)
	eco.grant_test_resources()
	eco.res.money = 1e6
	grant_land(8)

	# ------------------------------------------------ A. the queue (1-10)
	r.queue.clear()
	check(r.enqueue("fertilizers") == "" and "fertilizers" in r.queue, "a Founding Era discovery goes into the queue")
	r.enqueue("fertilizers")
	check(r.queue.count("fertilizers") == 1, "and only once")
	for k in ["forestry", "taxAdministration", "eliteTraining"]: r.enqueue(k)
	var full: String = r.enqueue("diplomaticCorps")
	check(r.queue.size() == r.QUEUE_MAX and full.contains("full"), "the queue holds %d projects (%s)" % [r.QUEUE_MAX, full])
	r.dequeue("eliteTraining")
	check(not "eliteTraining" in r.queue and r.queue.size() == 3, "a project can be taken out of it")
	r.queue.clear()
	check(r.enqueue("stealthTech").begins_with("Needs the"), "a later era's discovery waits for its era (%s)" % r.blocker("stealthTech"))
	var era0: int = r.era
	r.era = 1
	check(r.enqueue("irrigation").begins_with("Needs"), "a discovery waits for the one before it (%s)" % r.blocker("irrigation"))
	check(r.enqueue("publicEducation") == "" and r.blocker("publicEducation") == "", "a missing facility does not stop a project being queued")
	r.queue.clear()
	r.era = era0
	for k in ["forestry", "fertilizers"]: r.enqueue(k)
	r.points = 1000.0
	r.tick(1.0)
	check(float(r.progress.forestry.work) > 0.0 and float(r.progress.fertilizers.work) == 0.0, "the first project draws the points")
	r.queue.clear()
	r.era = 1
	set_stage("publicEducation", 1)   # the pilot stage needs a School, which there is not
	r.progress.publicEducation.work = 0.0
	r.enqueue("publicEducation")
	r.enqueue("taxAdministration")
	r.points = 1000.0
	var tax0: float = float(r.progress.taxAdministration.work)
	var has_school: bool = eco.owned("school") > 0
	for i in range(3): r.tick(1.0)
	check(has_school or float(r.progress.taxAdministration.work) > tax0, "a project waiting for its facility lets the next one advance")
	r.queue.clear()
	r.enqueue("forestry")
	r.points = 100000.0
	for i in range(80): r.tick(1.0)
	check(r.done("forestry") and not "forestry" in r.queue, "a finished discovery leaves the queue")
	r.era = era0

	# ------------------------------------------------ B. the three stages (11-22)
	check(r.stage_cost("compositeArmor", 0).is_empty(), "the design stage needs no materials")
	var army: Dictionary = r.stage_cost("compositeArmor", 1)
	var air: Dictionary = r.stage_cost("jetPropulsion", 1)
	var tech: Dictionary = r.stage_cost("microchips", 1)
	check(army.has("iron") and air.has("oil") and tech.has("silicon"), "a prototype needs the branch's materials (iron for armour, oil for aircraft, silicon for chips)")
	var last: Dictionary = r.stage_cost("fertilizers", 2)
	var last_eco: Dictionary = r.stage_cost("heavyIndustry", 2)
	check(last.keys() == ["money"] and last_eco.has("iron"), "the last stage is paid in money (industry also in iron)")
	check(int(r.stage_cost("nuclearProgram", 2).get("uranium", 0)) == 20, "the nuclear programme's deployment needs 20 uranium")
	var total: float = r.stage_points("combinedArms", 0) + r.stage_points("combinedArms", 1) + r.stage_points("combinedArms", 2)
	check(absf(total - float(r.def_of("combinedArms").cost)) <= 1.0, "the three stages share the whole cost 35/35/30 (%d of %d)" % [int(total), int(r.def_of("combinedArms").cost)])
	set_stage("diplomaticCorps", 0)
	r.queue = ["diplomaticCorps"]
	r.points = 1e7
	var seconds := 0
	while r.stage_of("diplomaticCorps") < 1 and seconds < 100:
		r.tick(1.0)
		seconds += 1
	check(seconds >= int(r.MIN_STAGE_SECONDS), "no stage completes in under %d seconds, however many points (%d s)" % [int(r.MIN_STAGE_SECONDS), seconds])
	var cash: float = eco.res.money
	eco.res.money = 1.0
	set_stage("eliteTraining", 1)
	r.queue = ["eliteTraining"]
	r.tick(1.0)
	check(r.status_of("eliteTraining").contains("waits for") and float(r.progress.eliteTraining.work) == 0.0, "a stage waits for its materials (%s)" % r.status_of("eliteTraining"))
	eco.res.money = cash
	var before: float = eco.res.money
	r.tick(1.0)
	var paid_once: float = before - eco.res.money
	r.tick(1.0)
	check(paid_once > 0.0 and absf(before - paid_once - eco.res.money) < 0.01, "and pays for them once ($%d)" % int(paid_once))
	set_stage("eliteTraining", 0)
	set_stage("taxAdministration", 2)
	var half: float = r.bonus("incomePct")
	set_stage("taxAdministration", 3)
	var whole: float = r.bonus("incomePct")
	set_stage("taxAdministration", 0)
	var none: float = r.bonus("incomePct")
	check(absf((half - none) - 0.04) < 0.001, "a finished prototype gives half the effect (+%.0f%% income)" % ((half - none) * 100))
	check(absf((whole - none) - 0.08) < 0.001, "the last stage gives all of it (+%.0f%%)" % ((whole - none) * 100))
	check(r.stage_names("compositeArmor") == ["Design", "Prototype", "Field trials"] and r.stage_names("fertilizers")[2] == "National rollout", "each branch names its stages (army: Design, Prototype, Field trials)")
	r.queue = ["diplomaticCorps"]
	check(r.status_of("diplomaticCorps").contains("/"), "the panel shows a stage's progress (%s)" % r.status_of("diplomaticCorps"))

	# ------------------------------------------------ C. the rate (23-28)
	for b in w.buildings:
		if b.owner == 0 and b.key in r.LABS: w.destroy_building(b)
	eco.recalculate()
	r.queue.clear()
	var labs_none: float = 0.0
	r.tick(1.0)
	labs_none = r.rate
	var national: float = r.bonus("researchPct")
	check(absf(labs_none - r.BASE_RATE * (1.0 + national)) < 0.01, "with no schools the capital alone gives %.2f a second" % labs_none)
	put("school")
	eco.recalculate()
	r.tick(1.0)
	var with_school: float = r.rate
	check(with_school > labs_none, "a school raises the research rate (%.2f)" % with_school)
	set_stage("publicEducation", 3)
	r.tick(1.0)
	check(r.rate > with_school * 1.05, "Public Education raises it by a tenth (%.2f)" % r.rate)
	put("techPark")
	var fab: Dictionary = put("chipFab")
	eco.recalculate()
	set_stage("microchips", 3)
	eco.res.silicon = 100.0
	var money0: float = eco.res.money
	var rate_plain: float = r.rate
	r.tick(1.0)
	check(eco.res.silicon < 100.0 and eco.res.money > money0 and r.rate > rate_plain, "a chip fab turns silicon into money and research")
	eco.res.silicon = 0.0
	var rate_fab: float = r.rate
	r.tick(1.0)
	check(r.rate < rate_fab, "and without silicon it adds nothing")
	r.queue.clear()
	var stock: float = r.points
	for i in range(10): r.tick(1.0)
	check(r.points > stock, "points pile up while nothing is being researched (%d)" % int(r.points - stock))

	# ------------------------------------------------ D. eras (29-36)
	r.era = 0
	check(r.eras[0].name == "Founding Era", "the nation starts in the Founding Era")
	var req1: Array = r.era_requirements(1)
	check(req1.size() == 2 and req1.any(func(x): return x[0] == "Village Centres"), "the Regional Era asks for a village and buildings (%s)" % str(req1.map(func(x): return x[0])))
	put("villageCenter")
	for i in range(8): put("cottage")
	var money1: float = eco.res.money
	var pts1: float = r.points
	r._check_era()
	check(r.era == 1, "meeting them opens the Regional Era")
	check(eco.res.money >= money1 + 499.0 and r.points >= pts1 + 99.0, "with its reward: $500 and 100 research")
	var opened: int = r.discoveries.keys().filter(func(k): return r.era_of(k) == 1).size()
	check(opened >= 5 and r.blocker("irrigation") != "Needs the Regional Era", "and opens its discoveries (%d)" % opened)
	var req2: Array = r.era_requirements(2)
	check(req2.map(func(x): return x[0].split(" (")[0]).has("Citizens") and req2.any(func(x): return x[0] == "City Centres") and req2.any(func(x): return x[0] == "Discoveries"), "the Urban Era asks for a city, citizens and discoveries")
	eco.civ_cap = 100.0
	check(r.era_requirements(2).any(func(x): return x[0].contains("homes for")), "short of homes, the goal says what to build")
	r.era = 1
	r._check_era()
	check(r.era == 1, "an era is not skipped")

	# ------------------------------------------------ E. tracks (37-42)
	r.era = 0
	r.queue.clear()
	var inc0: float = r.bonus("incomePct")
	r.enqueue("track:economy")
	r.points = 1e6
	for i in range(60): r.tick(1.0)
	check(r.tracks.economy == 1 and absf(r.bonus("incomePct") - inc0 - 0.12) < 0.001, "Economics level 1: +12% income")
	r.era = 0   # (the era may have moved on meanwhile: its goals were met above)
	check(r.enqueue("track:economy").begins_with("Level 2 needs"), "level 2 needs the next era (%s)" % r.track_blocker("economy"))
	check(r.track_cost("economy") == 2.0 * float(r.tracks_cfg.economy.baseCost), "each level costs more ($%d)" % int(r.track_cost("economy")))
	var tank0: Dictionary = fresh("tank")
	r.tracks.military = 2
	r._recompute()
	var tank1: Dictionary = fresh("tank")
	check(tank1.max_hp > tank0.max_hp * 1.15 and r.damage_mult(tank1) > r.damage_mult(tank0) * 1.15 - 0.001 or r.bonus("dmgAll") >= 0.16, "Military Science 2: +16% damage and health")
	var spy0: float = r.bonus("spyPct")
	r.tracks.espionage = 1
	r._recompute()
	check(absf(r.bonus("spyPct") - spy0 - 0.08) < 0.001, "Covert Ops 1: +8% operation success")
	r.tracks.hightech = 5
	check(r.track_blocker("hightech") == "Maxed", "a track stops at level 5")
	r.tracks.hightech = 0
	r.tracks.military = 0
	r._recompute()
	w.kill(tank0)
	w.kill(tank1)

	# ------------------------------------------------ F. what each discovery does (43-80)
	r.era = 5
	var farm_food := func() -> float:
		eco.tick()
		return eco.rates.food
	var food0: float = farm_food.call()
	set_stage("fertilizers", 3)
	var food1: float = farm_food.call()
	check(food1 > food0, "Synthetic Fertilizers: farms grow more (%.2f -> %.2f food/s)" % [food0, food1])
	set_stage("irrigation", 3)
	check(farm_food.call() > food1, "Modern Irrigation: more again")
	w.territory.tick()
	var forest0: float = float(w.territory.yields(0).money)
	set_stage("forestry", 3)
	check(float(w.territory.yields(0).money) >= forest0 and r.bonus("forestPct") == 1.0, "Industrial Forestry: forest land pays double")
	eco.tick()
	var health0: float = eco.health
	set_stage("advancedMedicine", 3)
	eco.tick()
	check(eco.health >= health0 + 9.9 or eco.health >= 99.9, "Advanced Medicine: +10 health (%d -> %d)" % [int(health0), int(eco.health)])
	var happy0: float = eco.happiness
	set_stage("nationalHealth", 3)
	eco.tick()
	check(eco.happiness > happy0 or eco.happiness >= 99.9, "National Health Service: happier citizens")
	var cap0: float = eco.civ_cap
	eco.recalculate()
	cap0 = eco.civ_cap
	set_stage("urbanPlanning", 3)
	check(eco.civ_cap > cap0 * 1.2, "Urban Planning: a quarter more room in every home (%d -> %d)" % [int(cap0), int(eco.civ_cap)])
	var inc_a: float = income()
	eco.tick()
	var happy_a: float = eco.happiness
	set_stage("welfareState", 3)
	var inc_b: float = income()
	check(inc_b < inc_a and eco.happiness >= happy_a, "Welfare State: happier, for 6% of income")
	set_stage("stockExchange", 3)
	var inc_c: float = income()
	check(inc_c > inc_b * 1.08, "Stock Exchange: +15%% income ($%.1f -> $%.1f)" % [inc_b, inc_c])
	set_stage("taxAdministration", 3)
	check(income() > inc_c, "Tax Administration: +8% more")
	var barracks: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead)[0]
	barracks.queue = ["soldier"]
	barracks.queue_prog = 0.0
	w.update_training(2.0)
	var slow: float = barracks.queue_prog
	set_stage("industrialization", 3)
	barracks.queue_prog = 0.0
	w.update_training(2.0)
	check(barracks.queue_prog > slow * 1.1, "Industrialization: factories work faster")
	barracks.queue.clear()
	var tank_price: float = float(r.unit_cost("tank", w.unit_defs.tank.cost).money)
	set_stage("heavyIndustry", 3)
	check(float(r.unit_cost("tank", w.unit_defs.tank.cost).money) < tank_price * 0.9, "Heavy Industry: vehicles 15%% cheaper ($%d -> $%d)" % [int(tank_price), int(r.unit_cost("tank", w.unit_defs.tank.cost).money)])
	put("port")   # routes need berths
	put("market")
	eco.recalculate()
	var routes0: int = w.market.route_cap()
	set_stage("globalLogistics", 3)
	check(w.market.route_cap() == routes0 + 1, "Global Logistics: one more trade route (%d)" % w.market.route_cap())
	var dep = null
	for dd in w.deposits:
		if dd.type == "iron" and dd.extractor == null and not dd.get("water", false):
			dep = dd
			break
	if dep != null: w.place_building("extractor", dep.pos, 0, true)
	eco.recalculate()
	eco.tick()
	var iron0: float = eco.rates.get("iron", 0.0)
	set_stage("advancedMining", 3)
	eco.tick()
	check(eco.rates.get("iron", 0.0) > iron0, "Advanced Mining: extractors yield more (%.2f -> %.2f iron/s)" % [iron0, eco.rates.get("iron", 0.0)])
	var s0: Dictionary = fresh("soldier")
	var d_inf: float = r.damage_mult(s0)
	set_stage("eliteTraining", 3)
	var s1: Dictionary = fresh("soldier")
	check(s1.max_hp > s0.max_hp * 1.1 and r.damage_mult(s1) > d_inf * 1.15, "Elite Training: infantry +20% damage, +15% health")
	var t0: Dictionary = fresh("tank")
	set_stage("compositeArmor", 3)
	var t1: Dictionary = fresh("tank")
	check(t1.max_hp > t0.max_hp * 1.15, "Composite Armor: vehicles +20%% health (%d -> %d)" % [int(t0.max_hp), int(t1.max_hp)])
	var a0: Dictionary = fresh("artillery")
	var arty_d: float = r.damage_mult(a0)
	set_stage("guidedMunitions", 3)
	var a1: Dictionary = fresh("artillery")
	check(a1.range > a0.range * 1.05 and r.damage_mult(a1) > arty_d * 1.15, "Guided Munitions: artillery reaches 10% further and hits 20% harder")
	set_stage("advancedLogistics", 3)
	var t2: Dictionary = fresh("tank")
	check(t2.speed > t1.speed * 1.1, "Advanced Logistics: ground units 15%% faster (%.1f -> %.1f)" % [t1.speed, t2.speed])
	var all0: float = r.damage_mult(t2)
	set_stage("combinedArms", 3)
	check(r.damage_mult(t2) > all0 * 1.05, "Combined Arms: the whole army +8% damage")
	var j0: Dictionary = fresh("jet")
	set_stage("jetPropulsion", 3)
	var j1: Dictionary = fresh("jet")
	check(j1.speed > j0.speed * 1.15, "Advanced Jet Propulsion: aircraft 20% faster")
	var air_d: float = r.damage_mult(j1)
	set_stage("precisionStrikes", 3)
	check(r.damage_mult(j1) > air_d * 1.1, "Precision Airstrikes: aircraft +15% damage")
	var drone_price: float = float(r.unit_cost("drone", w.unit_defs.drone.cost).money)
	var dr: Dictionary = fresh("drone")
	var drone_d: float = r.damage_mult(dr)
	set_stage("droneSwarms", 3)
	check(float(r.unit_cost("drone", w.unit_defs.drone.cost).money) < drone_price * 0.8 and r.damage_mult(dr) > drone_d * 1.3, "Drone Swarms: drones 30% cheaper, 40% deadlier")
	var shield: float = r.armor_mult(j1)
	set_stage("stealthTech", 3)
	check(r.armor_mult(j1) < shield * 0.75, "Stealth Technology: your aircraft take 30% less damage")
	var ship0: Dictionary = w.spawn_unit("destroyer", w.water_near(w.start, 250), 0)
	var nav_d: float = r.damage_mult(ship0)
	set_stage("sonarSystems", 3)
	var ship1: Dictionary = w.spawn_unit("destroyer", w.water_near(w.start, 250), 0)
	check(ship1.range > ship0.range * 1.05 and r.damage_mult(ship1) > nav_d * 1.1, "Sonar Systems: warships fire further and harder")
	set_stage("navalEngineering", 0)
	var locked_ship: String = r.unit_locked("destroyer")
	set_stage("navalEngineering", 3)
	check(locked_ship.begins_with("Needs") and r.unit_locked("destroyer") == "" and r.unit_locked("submarine") == "", "Naval Engineering unlocks the destroyer and submarine (%s)" % locked_ship)
	set_stage("ballisticTech", 0)
	var bal_locked: String = w.missiles.locked("ballistic")
	set_stage("ballisticTech", 3)
	check(bal_locked != "" and w.missiles.locked("ballistic") == "", "Ballistic Technology unlocks ballistic missiles (%s)" % bal_locked)
	set_stage("nuclearProgram", 3)
	check(w.missiles.locked("nuke") == "" and r.unit_locked("nuclearSub") == "", "the Nuclear Program unlocks the nuclear missile and submarine")
	eco.res.silicon = 50.0
	var fab_money: float = eco.res.money
	r.tick(1.0)
	check(eco.res.money > fab_money, "Microchip Fabrication puts the chip fab to work")
	set_stage("robotics", 0)
	var cot_at = site("cottage")
	var site1: Dictionary = w.place_building("cottage", cot_at, 0, false)
	var worker: Dictionary = w.units.filter(func(u): return u.owner == 0 and u.key == "worker" and not u.dead)[0]
	for u in w.units:
		if u.key == "worker": u.build_site = null
	w.place_on_ground(worker, site1.root.position + Vector3(site1.footprint * 0.5 + 1.0, 0, 0))
	worker.build_site = site1
	w.update_construction(0.5)
	var p_slow: float = site1.progress
	w.update_construction(2.0)
	var slow_step: float = site1.progress - p_slow
	set_stage("robotics", 3)
	var p_mid: float = site1.progress
	w.update_construction(2.0)
	check(site1.progress - p_mid > slow_step * 1.3 or site1.progress >= 1.0, "Robotics: building goes 50% faster")
	var q0: float = r.rate
	set_stage("quantumComputing", 3)
	r.tick(1.0)
	check(r.rate > q0 * 1.15, "Quantum Computing: +25%% research (%.2f -> %.2f)" % [q0, r.rate])
	set_stage("satelliteRecon", 3)
	check(r.bonus("warn") >= 1.0, "Satellite Recon: attacks are reported before they set out")
	var spy_a: float = w.espionage.success_chance("stealFunds", 1)
	set_stage("cyberWarfare", 3)
	check(w.espionage.success_chance("stealFunds", 1) > spy_a, "Cyber Warfare: covert operations succeed more often")
	w.diplomacy.set_score(0, 2, 0.0)
	w.diplomacy.gift(2)
	var plain_gift: float = w.diplomacy.rel(0, 2)
	set_stage("diplomaticCorps", 3)
	w.diplomacy.set_score(0, 2, 0.0)
	w.diplomacy.gift(2)
	check(w.diplomacy.rel(0, 2) >= plain_gift * 1.9, "Diplomatic Corps: gifts count double (+%d against +%d)" % [int(w.diplomacy.rel(0, 2)), int(plain_gift)])
	eco.grant_test_resources()
	eco.civilians = 100.0
	eco.tick()
	eco.tick()
	var happy_p: float = eco.happiness
	set_stage("secretPolice", 3)
	eco.grant_test_resources()
	eco.tick()
	check(r.bonus("counterSpy") >= 0.2 and (eco.happiness < happy_p or happy_p >= 100.0), "Internal Security: catches more spies, costs 3 happiness")
	var ransom_full: int = int(float(w.espionage.cfg.ransom) * (1.0 + r.bonus("ransomPct")))
	set_stage("constitutionalReform", 3)
	check(int(float(w.espionage.cfg.ransom) * (1.0 + r.bonus("ransomPct"))) <= ransom_full / 2 + 1, "Constitutional Framework: agents ransomed for half")
	eco.grant_test_resources()
	eco.tick()
	var happy_m: float = eco.happiness
	set_stage("massMedia", 3)
	eco.grant_test_resources()
	eco.tick()
	check(eco.happiness > happy_m or happy_m >= 100.0, "Mass Media: +4 happiness")
	var odds0: float = preload("res://scripts/modern_warfare.gd").intercept_chance(w, "samSite", {"type": "cruise", "owner": 1}, 0)
	set_stage("missileDefence", 3)
	check(preload("res://scripts/modern_warfare.gd").intercept_chance(w, "samSite", {"type": "cruise", "owner": 1}, 0) > odds0, "Missile Defence: every air defence intercepts better")
	var evade0: float = preload("res://scripts/modern_warfare.gd").intercept_chance(w, "abmLauncher", {"type": "ballistic", "owner": 0}, 1)
	set_stage("manoeuvringWarheads", 3)
	check(preload("res://scripts/modern_warfare.gd").intercept_chance(w, "abmLauncher", {"type": "ballistic", "owner": 0}, 1) < evade0 * 0.7, "Manoeuvring Warheads: your ballistic missiles are 40% harder to stop")
	var aps_tank: Dictionary = fresh("tank")
	var aps0: float = preload("res://scripts/modern_warfare.gd").aps_chance(w, aps_tank)
	set_stage("activeProtection", 3)
	check(aps0 == 0.0 and preload("res://scripts/modern_warfare.gd").aps_chance(w, aps_tank) >= 0.5, "Active Protection: half the missiles at your tanks are stopped")

	# ------------------------------------------------ G. rival research (81-88)
	var hard: Dictionary = w.ai.nations[0]
	var easy: Dictionary = w.ai.nations[1]
	hard.level = "hard"
	easy.level = "easy"
	hard.tech = 0.0
	easy.tech = 0.0
	for i in range(30): r.ai_tick()
	check(float(hard.tech) > 0.0 and float(easy.tech) > 0.0, "rivals research too (%.2f and %.2f levels in five minutes)" % [float(hard.tech), float(easy.tech)])
	check(float(hard.tech) > float(easy.tech), "a hard rival faster than an easy one")
	hard.tech = 0.0
	var foe_tank: Dictionary = w.spawn_unit("tank", w.land_point(w.ai.hq(hard.id).root.position, 30.0), hard.id)
	var foe_d0: float = r.damage_mult(foe_tank)
	hard.tech = 6.0
	check(r.damage_mult(foe_tank) > foe_d0 * 1.15, "each level adds 3% to a rival's damage")
	var foe_tank2: Dictionary = w.spawn_unit("tank", w.land_point(w.ai.hq(hard.id).root.position, 30.0), hard.id)
	check(foe_tank2.max_hp > foe_tank.max_hp * 1.1, "and to the health of its new units (%d -> %d)" % [int(foe_tank.max_hp), int(foe_tank2.max_hp)])
	hard.tech = 9.9
	for i in range(50): r.ai_tick()
	check(float(hard.tech) <= 10.0, "rival research stops at level 10")
	r.points = 30.0
	r.add_points(-70.0)
	check(r.points == 0.0, "stolen research never leaves you below zero")
	w.diplomacy.declare_war(hard.id, 0)
	hard.money = 5000.0
	hard.tech = 1.0
	var none_strike: Dictionary = w.ai.missile_strike(hard, w.ai.hq(hard.id), 1.0)
	hard.tech = 4.0
	var without_platform: Dictionary = w.ai.missile_strike(hard, w.ai.hq(hard.id), 4.0)
	check(without_platform.is_empty(), "rival research does not conjure a missile launch platform")
	var rival_home: Vector3 = w.ai.hq(hard.id).root.position
	var rival_site = w.test_site("missileSilo", rival_home + Vector3(45, 0, 45))
	w.place_building("missileSilo", rival_site, hard.id, true)
	var strike: Dictionary = w.ai.missile_strike(hard, w.ai.hq(hard.id), 4.0)
	check(none_strike.is_empty() and not strike.is_empty(), "a rival fires missiles only once its research allows (level 2 and up)")
	w.diplomacy.make_peace(hard.id, 0)
	check(r.ai_tech(hard.id) == floorf(float(hard.tech)), "a rival's tech counts in whole levels")

	# ------------------------------------------------ H. nations, saves, screen (89-100)
	check(r.blocker("goldenDome") == "" or r.done("goldenDome"), "the United States may build the Golden Dome")
	r.queue.clear()
	r.progress.fertilizers.stage = 1
	r.progress.fertilizers.work = 12.5
	r.enqueue("fertilizers")
	r.enqueue("track:military")
	r.progress["track:military"] = {"work": 33.0}
	r.tracks.economy = 3
	r.points = 777.0
	var era_saved: int = r.era
	r._recompute()
	var bonus_saved: float = r.bonus("incomePct")
	var data: Dictionary = JSON.parse_string(JSON.stringify(r.capture()))
	r.queue.clear()
	r.points = 0.0
	r.tracks.economy = 0
	r.progress.fertilizers.stage = 3
	r.progress.erase("track:military")
	r._recompute()
	r.restore(data)
	check(r.stage_of("fertilizers") == 1 and absf(float(r.progress.fertilizers.work) - 12.5) < 0.01 and r.queue == ["fertilizers", "track:military"], "a save keeps each discovery's stage, its progress and the queue")
	check(r.tracks.economy == 3 and absf(r.points - 777.0) < 0.01 and r.era == era_saved, "and the tracks, the points and the era")
	check(absf(float(r.progress.get("track:military", {}).get("work", 0.0)) - 33.0) < 0.01, "and a track's progress")
	check(absf(r.bonus("incomePct") - bonus_saved) < 0.001, "and the effects are counted again after loading (+%.0f%% income)" % (r.bonus("incomePct") * 100))
	var work0: float = float(r.progress.fertilizers.work)
	r.points = 1000.0
	for i in range(3): r.tick(1.0)
	check(float(r.progress.fertilizers.work) > work0 or r.stage_of("fertilizers") > 1, "and research carries on")
	w.hud.toggle_research()
	await process_frame
	await process_frame
	var tree: Control = null
	for c in w.hud.find_children("*", "Control", true, false):
		if c.get_script() == preload("res://scripts/research_tree.gd"):
			tree = c
			break
	check(tree != null and tree._cards.size() == r.discoveries.size(), "the research tree shows a card for every discovery (%d)" % (tree._cards.size() if tree != null else 0))
	var overlap := false
	if tree != null:
		var rects: Array = tree._cards.values()
		for i in range(rects.size()):
			for j in range(i):
				if rects[i].intersects(rects[j]): overlap = true
	check(tree != null and not overlap, "and no two cards overlap")
	r.era = 0
	var locked_key := "fusionPower"   # a Future Era discovery not yet started
	var tip: String = tree._get_tooltip(tree._cards[locked_key].get_center()) if tree != null else ""
	check(tip.contains("Needs the"), "a locked card says what it waits for (%s)" % tip.replace("\n", " / ").substr(0, 60))
	w.hud.toggle_research()
	# Another nation's weapons research, as China.
	await load_match({"map": "island", "players": 4, "nation": 1, "style": "standard"})
	r.era = 5
	check(r.blocker("goldenDome").ends_with("only") and r.enqueue("goldenDome") != "", "China may not research the Golden Dome (%s)" % r.blocker("goldenDome"))
	check(r.blocker("railguns") == "" or r.blocker("railguns").begins_with("Needs"), "but may research the railgun, which it tests")
	check(r.blocker("glidePhaseInterceptor").begins_with("Not fielded"), "nor the glide phase interceptor (%s)" % r.blocker("glidePhaseInterceptor"))

	print("\nRESEARCH_100: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("RESEARCH_100 PASS" if errors.is_empty() else "RESEARCH_100 FAIL")
	quit(0 if errors.is_empty() else 1)
