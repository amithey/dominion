extends SceneTree
## Every faction's strengths and weaknesses (national_profile.gd) take effect:
## measured against a neutral nation, each one's income, research, population
## growth, resource output, trade, unit prices, rival nations' income and
## research, and the starting relations between allies and old enemies.
var errors: Array[String] = []
var passed := 0
var w: Node
const NP := preload("res://scripts/national_profile.gd")
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

var saved_nation := {}
func become(owner: int, id: String) -> void:
	var n: Dictionary = w.map.nations[owner]
	if id == "":
		n.erase("id")
		n.color = "#777777"   # no known flag: a neutral nation
	else:
		n.id = id
		n.color = Factions.COLOURS[Factions.IDS.find(id)] if id in Factions.IDS else n.color
	w.research._recompute()
	w.economy.recalculate()

## Income per second with a fixed population, for the nation `owner` plays now
## (room for them all, so the income factor is measured on its own).
func income() -> float:
	w.economy.civ_cap = 5000.0
	w.economy.civilians = 400.0
	w.economy.tick()
	return w.economy.rates.money / maxf(w.economy.civilians, 1.0) * 400.0   # per citizen: the population cap is its own weakness

func research_rate() -> float:
	w.research.tick(1.0)
	return w.research.rate

func growth() -> float:
	w.economy.civilians = 200.0
	w.economy.res.food = w.economy.caps.food
	var before: float = w.economy.civilians
	w.economy.tick()
	return w.economy.civilians - before

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
	w.ai.set_physics_process(false)
	w.economy.set_process(false)
	w.research.set_process(false)
	w.economy.grant_test_resources()
	w.economy.civ_cap = 5000.0
	# An extractor on an oil deposit, so the nations' oil output can be compared.
	for d in w.deposits:
		if d.type == "oil" and d.extractor == null and not d.get("water", false):
			var b: Dictionary = w.place_building("extractor", d.pos, 0, true)
			break
	w.place_building("school", w.land_point(w.start, 40.0), 0, true)
	w.place_building("market", w.land_point(w.start, 60.0), 0, true)
	w.economy.recalculate()

	check(Factions.IDS.all(func(id): return NP.PROFILES.has(id)), "every faction has a national profile (%d)" % Factions.IDS.size())
	for id in NP.PROFILES:
		var s: Dictionary = NP.summary(id)
		check(s.strengths.size() >= 2 and s.weaknesses.size() >= 1, "%s: %d strengths and %d weaknesses written down" % [id, s.strengths.size(), s.weaknesses.size()])

	# The neutral baseline.
	become(0, "")
	var base_income := income()
	var base_research := research_rate()
	var base_growth := growth()
	w.economy.tick()
	var base_oil: float = w.economy.rates.get("oil", 0.0) + maxf(w.economy.civilians - 150.0, 0.0) * w.economy.OIL_PER_PERSON
	var base_tank: float = float(w.research.unit_cost("tank", w.unit_defs.tank.cost).money)
	var base_ship: float = float(w.research.unit_cost("destroyer", w.unit_defs.destroyer.cost).money)
	var base_drone: float = float(w.research.unit_cost("drone", w.unit_defs.drone.cost).money)
	print("  neutral: income %.2f/s, research %.2f/s, growth %.3f, oil %.2f/s" % [base_income, base_research, base_growth, base_oil])

	for id in NP.PROFILES:
		var p: Dictionary = NP.PROFILES[id]
		become(0, id)
		var b: Dictionary = p.bonus
		var inc := income()
		var want_inc: float = float(b.get("incomePct", 0.0))
		if absf(want_inc) > 0.001:
			check((inc > base_income) == (want_inc > 0.0), "%s: income %s (%.2f vs %.2f)" % [id, "higher" if want_inc > 0.0 else "lower", inc, base_income])
		var res := research_rate()
		var want_res: float = float(b.get("researchPct", 0.0))
		if absf(want_res) > 0.001:
			check((res > base_research) == (want_res > 0.0), "%s: research %s (%.2f vs %.2f)" % [id, "faster" if want_res > 0.0 else "slower", res, base_research])
		var gr := growth()
		var want_gr: float = float(p.growth)
		if absf(want_gr - 1.0) > 0.001 and base_growth > 0.0:
			check((gr > base_growth) == (want_gr > 1.0), "%s: population grows %s (%.3f vs %.3f)" % [id, "faster" if want_gr > 1.0 else "slower", gr, base_growth])
		var want_oil: float = float(p.resources.get("oil", 1.0))
		if absf(want_oil - 1.0) > 0.001 and base_oil > 0.0:
			w.economy.tick()
			var oil: float = w.economy.rates.get("oil", 0.0) + maxf(w.economy.civilians - 150.0, 0.0) * w.economy.OIL_PER_PERSON
			check((oil > base_oil) == (want_oil > 1.0), "%s: oil output %s (%.2f vs %.2f)" % [id, "higher" if want_oil > 1.0 else "lower", oil, base_oil])
		var costs: Dictionary = p.costs
		if costs.has("armor"):
			var t: float = float(w.research.unit_cost("tank", w.unit_defs.tank.cost).money)
			check((t < base_tank) == (float(costs.armor) < 1.0), "%s: tanks cost %s ($%d vs $%d)" % [id, "less" if float(costs.armor) < 1.0 else "more", int(t), int(base_tank)])
		if costs.has("naval"):
			var sh: float = float(w.research.unit_cost("destroyer", w.unit_defs.destroyer.cost).money)
			check(sh < base_ship, "%s: warships are cheaper ($%d vs $%d)" % [id, int(sh), int(base_ship)])
		if costs.has("drone"):
			var dr: float = float(w.research.unit_cost("drone", w.unit_defs.drone.cost).money)
			check(dr < base_drone, "%s: drones are cheaper ($%d vs $%d)" % [id, int(dr), int(base_drone)])
		var tr: float = float(p.trade)
		if absf(tr - 1.0) > 0.001:
			w.economy.res.iron = 1000.0
			var cash0: float = w.economy.res.money
			w.market.sell("iron", 100)
			var got: float = w.economy.res.money - cash0
			become(0, "")
			w.economy.res.iron = 1000.0
			cash0 = w.economy.res.money
			w.market.sell("iron", 100)
			var neutral_got: float = w.economy.res.money - cash0
			for i in range(30): w.market.exchange_step()
			check((got > neutral_got) == (tr > 1.0), "%s: trade pays %s ($%d vs $%d for 100 iron)" % [id, "more" if tr > 1.0 else "less", int(got), int(neutral_got)])
	become(0, "")
	var neutral_cap: float = w.economy.civ_cap
	become(0, "israel")
	check(w.economy.civ_cap < neutral_cap, "Israel is a small country: less room for citizens (%d vs %d)" % [int(w.economy.civ_cap), int(neutral_cap)])
	# Rival nations get theirs too.
	become(1, "russia")
	check(NP.ai_income(w, 1) < 1.0 and NP.ai_research(w, 1) < 1.0, "a Russian rival earns and researches less (sanctions, brain drain)")
	check(NP.cost_mult(w, 1, "tank") < 1.0, "but builds tanks cheaper")
	become(1, "israel")
	check(NP.ai_research(w, 1) > 1.25, "an Israeli rival researches far faster")
	become(1, "usa")
	var jet: Dictionary = w.spawn_unit("jet", w.land_point(w.start, 60.0), 1)
	check(NP.ai_damage(w, jet) > 1.05, "an American rival's aircraft hit harder")
	w.kill(jet)
	# Starting relations: allies and enemies.
	become(0, "usa")
	become(1, "iran")
	become(2, "israel")
	become(3, "japan")
	for a in range(4):
		for b2 in range(a + 1, 4): w.diplomacy.set_score(a, b2, 0.0)
	NP.apply_relations(w)
	var d: Node = w.diplomacy
	check(d.rel(0, 1) <= -50.0, "the United States and Iran start as enemies (%d)" % int(d.rel(0, 1)))
	check(d.rel(1, 2) <= -60.0, "Iran and Israel start as enemies (%d)" % int(d.rel(1, 2)))
	check(d.rel(0, 2) >= 30.0 and d.rel(0, 3) >= 30.0, "the United States starts close to Israel and Japan (%d, %d)" % [int(d.rel(0, 2)), int(d.rel(0, 3))])
	become(0, "china")
	become(1, "russia")
	become(2, "india")
	become(3, "japan")
	for a in range(4):
		for b2 in range(a + 1, 4): w.diplomacy.set_score(a, b2, 0.0)
	NP.apply_relations(w)
	check(d.rel(0, 1) >= 25.0, "China and Russia start as partners (%d)" % int(d.rel(0, 1)))
	check(d.rel(0, 3) < 0.0 and d.rel(0, 2) < 0.0, "China starts cold with Japan and India (%d, %d)" % [int(d.rel(0, 3)), int(d.rel(0, 2))])
	check(d.rel(1, 2) > 0.0, "India keeps a friend in Russia too (%d)" % int(d.rel(1, 2)))
	print("\nNATIONAL_PROFILE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("NATIONAL_PROFILE PASS" if errors.is_empty() else "NATIONAL_PROFILE FAIL")
	quit(0 if errors.is_empty() else 1)
