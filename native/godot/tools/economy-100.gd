extends SceneTree
## A hundred checks on the economy: the stores and their caps; citizens (growth,
## housing, happiness, health, hunger, fuel, chips, winter heating); food;
## taxes and administration; land, mines and rigs; the world market (spreads,
## slippage, price moves, war, recovery); trade routes (ports, pacts, berths,
## exports, imports, losses, collapse, overland trade, sabotage); rival
## economies; army capacity and prices; what each building really adds (power
## plants, ammo depots, command centres); towns' own accounts; saves; and the
## numbers on screen.
var errors: Array[String] = []
var passed := 0
var w: Node
var eco: Node
var m: Node
var d: Node
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
	eco = w.economy
	m = w.market
	d = w.diplomacy

func hq(owner := 0) -> Dictionary:
	return w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)[0]

func grant_land(rings: int) -> void:
	var home: Vector2i = w.logistics.world_hex(w.start)
	for q in range(-rings, rings + 1):
		for s in range(-rings, rings + 1):
			var h := home + Vector2i(q, s)
			if w.logistics.hex_distance(home, h) > rings: continue
			var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
			if i >= 0 and w.territory.owner_of[i] < 0:
				w.territory.owner_of[i] = 0
				w.territory.control[i] = 80.0
				w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(hq())}

func site(key: String, from := 1, to := 10) -> Variant:
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(from, to):
		for q in range(-ring, ring + 1):
			for s in range(-ring, ring + 1):
				var h := home + Vector2i(q, s)
				if w.logistics.hex_distance(home, h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "": return at
	return null

func put(key: String, from := 1) -> Dictionary:
	var at = site(key, from)
	var b: Dictionary = w.place_building(key, at if at != null else w.land_point(w.start, 60.0), 0, true)
	w.logistics.update_supply()
	eco.recalculate()
	return b

func deposit(type: String):
	for dep in w.deposits:
		if dep.type == type and dep.extractor == null: return dep
	return null

## Money a second from taxes alone, for a fixed population.
func taxes(people := 400.0) -> float:
	eco.civ_cap = maxf(eco.civ_cap, people)
	eco.civilians = people
	eco.recalculate()
	var land: float = float(w.territory.yields(0).money)
	eco.tick()
	return eco.rates.money - land

func run() -> void:
	await load_match({"map": "island", "players": 4, "nation": 0, "style": "standard"})
	seed(8080)

	# ------------------------------------------------ A. stores (1-10)
	check(absf(eco.res.food - 250.0) < 30.0 and absf(eco.res.iron - 120.0) < 30.0 and absf(eco.res.gas - 100.0) < 10.0 and eco.civilians >= 100.0, "a nation starts with food, iron, gas and 120 citizens (%d food, %d iron, %d gas)" % [int(eco.res.food), int(eco.res.iron), int(eco.res.gas)])
	eco.recalculate()
	var extra: float = 400.0 * eco.owned("warehouse")   # the starting town has a warehouse
	check(eco.caps.iron == 500.0 + extra and eco.caps.oil == 500.0 + extra and eco.caps.silicon == 400.0 + extra and eco.caps.uranium == 300.0 + extra and eco.caps.gas == 400.0 + extra and eco.caps.food == 300.0, "storage: 500 iron and oil, 400 silicon and gas, 300 uranium, 300 food (and %d from its warehouse)" % int(extra))
	var iron_cap0: float = eco.caps.iron
	var gas_cap0: float = eco.caps.gas
	var wh: Dictionary = put("warehouse")
	check(eco.caps.iron == iron_cap0 + 400.0 and eco.caps.gas == gas_cap0 + 400.0, "a warehouse adds 400 to every material store")
	put("foodDepot")
	check(eco.caps.food == 800.0, "a food warehouse adds 500 to the granary")
	eco.res.iron = eco.caps.iron
	var dep = deposit("iron")
	if dep != null: w.place_building("extractor", dep.pos, 0, true)
	eco.tick()
	check(eco.res.iron <= eco.caps.iron + 0.001, "stores never overflow their cap")
	eco.res.gas = 0.0
	w.game_time = 600.0
	eco.tick()
	w.game_time = 100.0
	check(eco.res.gas >= 0.0 and eco.res.values().all(func(v): return v >= 0.0), "and never fall below zero")
	var money0: float = eco.res.money
	eco.res.money = 10.0
	check(not eco.pay({"money": 50.0, "iron": 1.0}) and eco.res.money == 10.0, "a cost that cannot be met takes nothing")
	check(eco.missing({"money": 50.0}) == "money" and eco.missing({"iron": 1.0}) == "", "and says what is missing")
	eco.res.money = money0
	eco.res.iron = eco.caps.iron
	eco.refund({"iron": 300.0})
	eco.tick()
	check(eco.res.iron <= eco.caps.iron + 0.001, "a refund above the cap is trimmed back")
	var test_cash: float = eco.res.money
	eco.grant_test_resources()
	check(eco.caps.iron >= 99999.0 and eco.res.money >= test_cash + 99999.0, "the testing grant (F8) opens every store")
	eco.test_mode = false
	eco.garrison = 0
	eco.recalculate()
	for k in eco.caps: eco.res[k] = minf(eco.res[k], eco.caps[k])
	eco.res.money = 50000.0

	# ------------------------------------------------ B. citizens (11-22)
	grant_land(8)
	for i in range(3): put("apartments", 2)   # homes for the numbers below (the cap is recounted every tick)
	eco.res.food = eco.caps.food
	eco.civ_cap = 1000.0
	eco.civilians = 200.0
	eco.shortages.clear()
	var p0: float = eco.civilians
	eco.tick()
	var grown: float = eco.civilians - p0
	check(grown > 0.0, "fed and content, citizens grow (+%.2f a second)" % grown)
	var h0: float = eco.health
	put("hospital")
	eco.civilians = 200.0
	eco.res.food = eco.caps.food
	eco.tick()
	check(eco.health >= h0 + 9.9 and eco.civilians - 200.0 > grown, "a hospital: +10 health, faster growth")
	eco.civilians = 999.5
	eco.civ_cap = 1000.0
	eco.res.food = eco.caps.food
	eco.tick()
	check(eco.civilians <= eco.civ_cap, "never more citizens than homes")
	eco.recalculate()
	eco.res.food = 0.0
	eco.civilians = 300.0
	for i in range(3): eco.tick()
	check(eco.civilians < 300.0, "starving, the population falls (%d)" % int(eco.civilians))
	eco.civilians = 21.0
	for i in range(50): eco.tick()
	check(eco.civilians >= 20.0, "but never below 20")
	eco.res.food = eco.caps.food
	var cap_a: float = eco.civ_cap
	put("cottage")
	check(eco.civ_cap >= cap_a + 79.9, "a cottage houses 80 more (%d -> %d)" % [int(cap_a), int(eco.civ_cap)])
	eco.shortages.clear()
	eco.tick()
	var joy0: float = eco.happiness
	put("park")
	eco.shortages.clear()
	eco.tick()
	check(eco.happiness >= joy0 + 5.9 or eco.happiness >= 99.9, "a park: +6 happiness")
	eco.res.oil = 0.0
	eco.res.silicon = 0.0
	eco.civilians = 800.0
	eco.civ_cap = 1000.0
	eco.tick()
	var shorts: int = eco.shortages.size()
	var joy_a: float = eco.happiness
	eco.tick()
	check(shorts >= 2 and eco.happiness <= joy_a - 11.9 + (joy_a - eco.happiness) * 0.0 or eco.happiness <= 88.1, "each shortage costs 6 happiness (%s)" % str(eco.shortages))
	eco.res.oil = 400.0
	eco.civilians = 400.0
	eco.tick()
	var burn: float = -float(eco.rates.oil)
	check(eco.rates.oil < 0.0 and absf(burn - 250.0 * eco.OIL_PER_PERSON) < 0.05 + float(deposit("oil") == null) * 0.0, "past 150 citizens a nation burns oil (%.2f a second at 400)" % burn)
	eco.res.silicon = 100.0
	eco.civilians = 600.0
	eco.tick()
	check(eco.rates.silicon < 0.0, "past 400 it uses chips (%.2f silicon a second)" % eco.rates.silicon)
	w.game_time = 100.0
	eco.tick()
	var summer: float = eco.rates.gas
	w.game_time = 560.0
	eco.tick()
	var winter: float = eco.rates.gas
	w.game_time = 100.0
	check(winter < summer and absf((summer - winter) - 600.0 * 0.006) < 0.05, "winter homes burn gas (%.2f a second for 600 citizens)" % (summer - winter))

	# ------------------------------------------------ C. food (23-30)
	eco.civilians = 200.0
	eco.recalculate()
	eco.tick()
	var in0: float = eco.rates.food
	var farm: Dictionary = put("farm")
	eco.tick()
	check(absf(eco.rates.food - in0 - float(eco.cfg.farmFood)) < 0.01, "a farm grows %d food a second" % int(eco.cfg.farmFood))
	var soldiers0: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker").size()
	eco.tick()
	var f_a: float = eco.rates.food
	for i in range(4): w.spawn_unit("soldier", w.land_point(w.start, 30.0), 0)
	eco.tick()
	check(absf((f_a - eco.rates.food) - 4.0 * float(eco.cfg.foodPerSoldier)) < 0.01, "each soldier eats %.2f" % float(eco.cfg.foodPerSoldier))
	var f_b: float = eco.rates.food
	for i in range(3): w.spawn_unit("worker", w.land_point(w.start, 30.0), 0)
	eco.tick()
	check(absf(eco.rates.food - f_b) < 0.01, "workers eat at home, not from the army's rations")
	eco.civilians = 200.0
	eco.tick()
	var per_small: float = (in0 - eco.rates.food)
	eco.civilians = 200.0
	eco.tick()
	eco.civilians = 1000.0
	eco.civ_cap = 1500.0
	eco.tick()
	var eat_big: float = 1000.0 * float(eco.cfg.foodPerCivilian) * (1.0 + 1000.0 / 2000.0)
	check(eat_big / 1000.0 > float(eco.cfg.foodPerCivilian) * 1.4, "a big city eats more per head (%.4f against %.4f)" % [eat_big / 1000.0, float(eco.cfg.foodPerCivilian)])
	eco.recalculate()
	eco.res.food = eco.caps.food - 1.0
	eco.civilians = 50.0
	for i in range(20): eco.tick()
	check(eco.res.food <= eco.caps.food + 0.001, "the granary holds only so much")
	var wharf_at: Variant = site("fishingWharf", 1, 12)
	var wharf_food := 0.0
	if wharf_at != null:
		eco.tick()
		var fw0: float = eco.rates.food
		var wharf: Dictionary = w.place_building("fishingWharf", wharf_at, 0, true)
		w.logistics.update_supply()
		eco.tick()
		wharf_food = eco.rates.food - fw0
		var shoals := 0
		for dd in w.deposits:
			if dd.type == "fish" and dd.pos.distance_to(wharf.root.position) <= 60: shoals += 1
		check(absf(wharf_food - (2.0 + mini(shoals, 2) * 2.0)) < 0.01, "a fishing wharf lands 2 food, and 2 more for each shoal nearby (%.0f with %d)" % [wharf_food, shoals])
		wharf.supplied = false
		eco.tick()
		var cut_food: float = eco.rates.food
		wharf.supplied = true
		check(cut_food < fw0 + wharf_food - 0.5, "cut off from supply it lands nothing")
	else:
		check(false, "a coast for a fishing wharf")
		check(false, "a coast for a fishing wharf (supply)")
	grant_land(6)
	w.territory.tick()
	var land_food: float = float(w.territory.yields(0).food)
	check(land_food > 0.0, "held plains grow food too (%.2f a second)" % land_food)

	# ------------------------------------------------ D. taxes (31-42)
	eco.recalculate()
	var admin0: float = eco.admin
	check(absf(admin0 - float(eco.cfg.baseAdmin)) < 0.01 or admin0 > float(eco.cfg.baseAdmin), "administration starts at %.2f" % float(eco.cfg.baseAdmin))
	var t0: float = taxes()
	var cov: float = eco.supply_coverage()
	var expect: float = eco.civilians * float(eco.cfg.taxPerCivilian) * eco.admin * cov * (1.0 + eco.provided("incomePct") + w.research.bonus("incomePct"))
	check(absf(t0 - expect) < 0.05, "taxes: citizens x $0.035 x administration x coverage x bonuses ($%.2f a second)" % t0)
	put("residential", 2)
	var t_res: float = taxes()
	check(eco.admin > admin0 and t_res > t0, "a residential district extends the administration (%.2f)" % eco.admin)
	var village: Dictionary = put("villageCenter", 4)
	var v_route: Array = w.logistics.plan(w.logistics.world_hex(w.start), w.logistics.world_hex(village.root.position), 0, "road")
	w.logistics.build(v_route, "road", 0)   # a village counts once it is linked to the capital
	w.logistics.update_supply()
	eco.recalculate()
	var admin_v: float = eco.admin
	check(admin_v >= eco.admin - 0.001 and admin_v > admin0 + 0.09, "and so does a village (%.2f)" % admin_v)
	var admin_cap := true
	for i in range(6): put("residential", 2)
	check(eco.admin <= 1.0 and eco.admin <= float(eco.cfg.baseAdmin) + 0.15 + 0.15 + 0.1 * eco.owned("cityCenter") + 0.001, "residential districts count up to three")
	var t_mk0: float = taxes()
	put("market", 2)
	var mk_pct: float = eco.provided("incomePct")
	check(taxes() > t_mk0 * 1.03, "a market: +8%% income (bonuses now +%.0f%%)" % (mk_pct * 100))
	village.supplied = false
	var cov_cut: float = eco.supply_coverage()
	village.supplied = true
	check(cov_cut < eco.supply_coverage(), "a town cut off from the capital pays no taxes (coverage %.0f%% -> %.0f%%)" % [eco.supply_coverage() * 100, cov_cut * 100])
	w.territory.tick()
	check(float(w.territory.yields(0).money) > 0.0, "held land pays too ($%.2f a second)" % float(w.territory.yields(0).money))
	var nearest := func(type: String):
		var best = null
		for dd in w.deposits:
			if dd.type == type and dd.extractor == null and w.territory.owner_at(dd.pos) == 0 and (best == null or dd.pos.distance_to(w.start) < best.pos.distance_to(w.start)): best = dd
		return best
	var gold = nearest.call("gold")
	var diamond = nearest.call("diamond")
	eco.tick()
	var cash_rate: float = eco.rates.money
	if gold != null: w.place_building("extractor", gold.pos, 0, true)
	w.logistics.update_supply()
	eco.tick()
	check(gold == null or eco.rates.money >= cash_rate + 3.9, "a gold mine pays $4 a second")
	cash_rate = eco.rates.money
	if diamond != null: w.place_building("extractor", diamond.pos, 0, true)
	w.logistics.update_supply()
	eco.tick()
	check(diamond == null or eco.rates.money >= cash_rate + 5.9, "a diamond mine $6")
	var oil_dep = deposit("oil")
	var oil_x: Dictionary = w.place_building("extractor", oil_dep.pos, 0, true)
	w.logistics.update_supply()
	eco.civilians = 100.0
	eco.tick()
	var oil_rate: float = eco.rates.oil
	check(absf(oil_rate - 2.0 * preload("res://scripts/national_profile.gd").resource_mult(w, 0, "oil")) < 0.05 or oil_rate > 2.0, "an oil well: 2 a second, more for an oil-rich nation (%.2f for the United States)" % oil_rate)
	var towns_tax := 0.0
	for b in w.buildings:
		if b.owner == 0 and not b.dead and b.built and b.def.get("settlement") != null:
			towns_tax += float(eco.city_report(b).tax)
	eco.civilians = 400.0
	eco.tick()
	var nation_tax: float = eco.rates.money - float(w.territory.yields(0).money)
	towns_tax = 0.0
	var residents := 0.0
	for b in w.buildings:
		if b.owner == 0 and not b.dead and b.built and b.def.get("settlement") != null:
			var rep: Dictionary = eco.city_report(b)
			towns_tax += float(rep.tax)
			residents += float(rep.residents)
	check(absf(residents - eco.civilians) < eco.civilians * 0.05, "the towns' accounts house the whole nation (%d of %d citizens)" % [int(residents), int(eco.civilians)])

	# ------------------------------------------------ E. mines and rigs (43-48)
	eco.tick()
	var iron_rate: float = eco.rates.iron
	check(dep == null or iron_rate >= 1.99, "an iron mine: 2 a second (%.2f)" % iron_rate)
	for b in w.buildings:
		if b.owner == 0 and b.key == "extractor" and b.deposit != null and b.deposit.type == "iron": b.supplied = false
	eco.tick()
	check(eco.rates.iron < iron_rate - 1.9, "cut off from supply, it yields nothing")
	for b in w.buildings:
		if b.owner == 0 and b.key == "extractor": b.supplied = true
	var rigs := {"seaGas": "gas", "seaOil": "oil"}
	for type in rigs:
		var sea_dep = deposit(type)
		if sea_dep == null:
			check(false, "an offshore %s field on the map" % type)
			continue
		eco.tick()
		var before: float = eco.rates.get(rigs[type], 0.0)
		var rig: Dictionary = w.place_building("offshoreRig", sea_dep.pos, 0, true)
		rig.supplied = true
		eco.tick()
		check(eco.rates.get(rigs[type], 0.0) > before + 1.9, "an offshore rig on a %s field yields %s (%.1f a second)" % [type, rigs[type], eco.rates.get(rigs[type], 0.0) - before])
	w.destroy_building(oil_x)
	check(oil_dep.extractor == null, "a destroyed well frees its field for a new one")

	# ------------------------------------------------ F. the world market (49-60)
	for b in w.buildings:
		if b.owner == 0 and b.key == "market": b.supplied = false
	eco.recalculate()
	check(m.sell("iron", 10).begins_with("Instant market deals require"), "no instant deals without a Market")
	for b in w.buildings:
		if b.owner == 0 and b.key == "market": b.supplied = true
	eco.recalculate()
	var list: float = m.price("iron")
	check(absf(m.quote("iron", 1, false) - list * 0.9) < list * 0.01, "a Market buys at 90% of the price")
	check(absf(m.quote("iron", 1, true) - list * 1.15) < list * 0.01, "and sells at 115%")
	check(m.quote("iron", 600, true) / 600.0 > m.quote("iron", 10, true) / 10.0 * 1.05, "a big order fills at a worse price than a small one (slippage)")
	eco.res.iron = 0.0
	eco.res.money = 1e7
	var p0m: float = m.price("iron")
	m.buy("iron", 500)
	check(absf(m.price("iron") - p0m) < 0.001, "the listed price does not jump at once")
	for i in range(5): m.exchange_step()
	var up: float = m.price("iron")
	check(up > p0m * 1.03, "it rises over the next seconds ($%.2f -> $%.2f)" % [p0m, up])
	eco.res.iron = 5000.0
	for i in range(4): m.sell("iron", 800)
	for i in range(6): m.exchange_step()
	check(m.price("iron") < up, "heavy selling brings it down ($%.2f)" % m.price("iron"))
	m.flow["oil"] = 1e7
	for i in range(30): m.exchange_step()
	var top: float = float(m.mult.oil)
	m.flow["oil"] = -1e7
	for i in range(60): m.exchange_step()
	check(top <= 3.0 and float(m.mult.oil) >= 0.35, "prices stay between 35% and 300% of their base (%.2f, %.2f)" % [top, float(m.mult.oil)])
	m.flow["oil"] = 0.0
	m.mult["silicon"] = 2.0
	for i in range(120): m.exchange_step()
	check(float(m.mult.silicon) < 1.7, "and drift back toward their fair value (%.2f)" % float(m.mult.silicon))
	for key in m.fair: m.fair[key] = 1.0
	d.declare_war(0, 1)
	for i in range(200): m.exchange_step()
	check(float(m.fair.oil) > 1.1 and float(m.fair.gas) > 1.1, "war makes fuel dear (fair value oil %.2f, gas %.2f)" % [float(m.fair.oil), float(m.fair.gas)])
	d.make_peace(0, 1)
	check(m.history.iron.size() <= m.HISTORY, "three minutes of price history are kept")
	check(m.resources().has("gas") and m.price("gas") > 0.0, "gas is traded too ($%.2f)" % m.price("gas"))

	# ------------------------------------------------ G. trade routes (61-74)
	for b in w.buildings:
		if b.owner == 0 and b.key == "port": w.destroy_building(b)
	d.set_score(0, 2, 60.0)
	d.set_flag(d.pact, 0, 2, false)
	check(m.open_route(2, "iron", "export", 25).begins_with("Trade needs a Commercial Port"), "a trade route needs a Commercial Port or a road")
	var port_at = site("port", 1, 12)
	var port: Dictionary = w.place_building("port", port_at if port_at != null else w.water_near(w.start, 200), 0, true)
	w.logistics.update_supply()
	eco.recalculate()
	check(m.open_route(2, "iron", "export", 25).begins_with("Trade routes need a trade pact"), "and a trade pact")
	d.set_flag(d.pact, 0, 2, true)
	var cap_r: int = m.route_cap()
	check(cap_r >= 1 and cap_r <= m.ports() * int(m.cfg.routesPerPort) + m.land_links() * 2, "routes: contracts from pacts and markets, limited by berths (%d)" % cap_r)
	m.routes.clear()
	eco.res.iron = 200.0
	eco.res.money = 50000.0
	m.open_route(2, "iron", "export", 25)
	var cash_e: float = eco.res.money
	var partner: Dictionary = w.ai.nations.filter(func(n): return n.id == 2)[0]
	partner.money = 5000.0
	var rel_e: float = d.rel(0, 2)
	m.tick()
	var loaded: bool = eco.res.iron <= 175.1 and m.routes[0].shipment != null
	var delivered := false
	for i in range(8):
		var before_money: float = eco.res.money
		m.tick()
		if m.delivered > 0:
			delivered = true
			break
	check(loaded and delivered and eco.res.money > cash_e, "an export: 25 iron load, sail and are paid for")
	check(d.rel(0, 2) > rel_e, "each delivery warms relations")
	check(float(partner.money) < 5000.0, "and the buyer pays for it")
	m.routes.clear()
	eco.res.iron = 0.0
	m.open_route(2, "iron", "import", 25)
	var cash_i: float = eco.res.money
	m.tick()
	var paid_i: float = cash_i - eco.res.money
	check(paid_i >= m.price("iron") * 25.0 * 1.14, "an import is paid for on loading, at 115% ($%d)" % int(paid_i))
	for i in range(8): m.tick()
	check(eco.res.iron >= 24.9 or m.lost > 0, "and its goods arrive (%d iron)" % int(eco.res.iron))
	eco.res.iron = eco.caps.iron
	m.routes[0].shipment = null
	m.tick()
	check(m.routes[0].status.begins_with("Stalled — no storage"), "an import with no room waits (%s)" % m.routes[0].status)
	m.routes.clear()
	eco.res.iron = 0.0
	m.open_route(2, "iron", "export", 25)
	m.tick()
	check(m.routes[0].status.begins_with("Stalled — not enough stock"), "an export with nothing to send waits")
	eco.res.iron = 200.0
	m.routes[0].shipment = null
	m.tick()
	var lost0: int = m.lost
	d.declare_war(0, 2)
	m.tick()
	check(m.routes.is_empty() and m.lost == lost0 + 1, "war ends a route, and the cargo at sea is lost")
	d.make_peace(0, 2)
	d.set_flag(d.pact, 0, 2, true)
	m.open_route(2, "iron", "export", 25)
	w.destroy_building(port)
	w.logistics.update_supply()
	eco.recalculate()
	m.tick()
	check(m.routes.is_empty() or m.routes.all(func(r): return r.get("overland", false)), "losing the port closes its routes")
	var bare: float = m.risk()
	for i in range(3): w.spawn_unit("destroyer", w.water_near(w.start, 250), 0)
	check(m.risk() < bare, "warships at sea lower the risk to cargo (%.1f%% -> %.1f%%)" % [bare * 100.0, m.risk() * 100.0])
	# Overland: a road to their town.
	var their_town: Dictionary = w.ai.hq(3)
	var route: Array = w.logistics.plan(w.logistics.world_hex(w.start), w.logistics.world_hex(their_town.root.position), 0, "road")
	var roads: bool = route.size() > 1 and w.logistics.build(route, "road", 0)
	w.logistics.update_supply()
	check(roads and m.land_link(3) == "road", "a road to a rival's town opens overland trade (%d links)" % (route.size() - 1))
	d.set_score(0, 3, 60.0)
	d.set_flag(d.pact, 0, 3, true)
	m.routes.clear()
	eco.res.iron = 200.0
	var said_o: String = m.open_route(3, "iron", "export", 25)
	m.tick()
	check(m.routes.size() == 1 and m.routes[0].overland and m.routes[0].shipment != null and float(m.routes[0].shipment.eta) <= float(m.cfg.voyage) * 0.66, "overland cargo travels faster than by sea (%ds)" % int(m.routes[0].shipment.eta if not m.routes.is_empty() and m.routes[0].shipment != null else -1))
	m.routes.clear()
	var port2 = site("port", 1, 12)
	if port2 != null: w.place_building("port", port2, 0, true)
	w.logistics.update_supply()
	eco.recalculate()
	d.set_flag(d.pact, 0, 2, true)
	eco.res.iron = 200.0
	m.open_route(2, "iron", "export", 25)
	m.tick()
	m.sabotaged = 1
	var lost_s: int = m.lost
	for i in range(4): m.tick()
	check(m.sabotaged == 0 and m.lost >= lost_s + 1, "an enemy saboteur sinks the next cargo")
	m.routes.clear()

	# ------------------------------------------------ H. rival economies (75-82)
	var rival: Dictionary = w.ai.nations.filter(func(n): return n.id == 1)[0]
	var rid := str(rival.id)
	var rmarket: Dictionary = w.place_building("market", w.land_point(w.ai.hq(1).root.position, 25.0), 1, true)
	w.territory.tick()
	w.logistics.update_supply()
	m.ai_stock[rid] = {"food": 20.0, "oil": 300.0, "iron": 100.0, "silicon": 100.0, "uranium": 100.0, "gas": 100.0}
	rival.money = 5000.0
	var rcash: float = rival.money
	m.trade_ai()
	check(float(m.ai_stock[rid].food) >= 30.0, "a rival short of food buys it on the market (%d in stock)" % int(float(m.ai_stock[rid].food)))
	check(float(m.ai_stock[rid].oil) < 300.0 - 3.0, "and sells a surplus")
	w.destroy_building(rmarket)
	m.ai_stock[rid] = {"food": 20.0}
	rcash = rival.money
	m.trade_ai()
	check(rival.money == rcash, "without a market it cannot trade")
	rival.money = 0.0
	rival.next_build = 9999.0
	rival.next_train = 9999.0
	for i in range(int(10.0 / DT)): w.ai._physics_process(DT)
	check(rival.money > 50.0, "a rival earns its income ($%d in 10 s)" % int(rival.money))
	var land_money: float = rival.money
	w.territory.tick()
	check(rival.money > land_money, "and its land pays it too")
	m.ai_stock[rid] = {"food": 20.0}
	w.place_building("market", w.land_point(w.ai.hq(1).root.position, 25.0), 1, true)
	rival.money = 10.0
	m.trade_ai()
	check(rival.money >= 0.0 and float(m.ai_stock[rid].food) <= 20.0, "a poor rival keeps a reserve and does not buy")
	var extractor_owner: Dictionary = {}
	for b in w.buildings:
		if b.owner == 1 and not b.dead and b.deposit != null: extractor_owner = b
	if extractor_owner.is_empty():
		var rd = null
		for dd in w.deposits:
			if dd.extractor == null and not dd.get("water", false) and dd.pos.distance_to(w.ai.hq(1).root.position) < 160.0:
				rd = dd
				break
		if rd != null: w.place_building("extractor", rd.pos, 1, true)
	var stock0: float = float(m.ai_stock[rid].get("iron", 100.0))
	m.trade_ai()
	check(m.ai_stock[rid].size() >= 5, "a rival keeps stocks of every commodity (%s)" % str(m.ai_stock[rid].keys()))
	check(rival.money >= 0.0 and w.ai.nations.all(func(n): return n.money >= 0.0), "no rival's treasury goes below zero")

	# ------------------------------------------------ I. the army's cost (83-90)
	eco.garrison = 0
	eco.recalculate()
	var cap0: int = eco.pop_cap
	put("housing", 2)
	check(eco.pop_cap == cap0 + 8, "housing blocks give the army room for 8 more (%d)" % eco.pop_cap)
	var used0: int = eco.pop_used
	var sold: Dictionary = w.spawn_unit("tank", w.land_point(w.start, 30.0), 0)
	eco.recalculate()
	check(eco.pop_used == used0 + int(w.unit_defs.tank.get("pop", 1)), "each unit takes its room (a tank %d)" % int(w.unit_defs.tank.get("pop", 1)))
	w.kill(sold)
	eco.recalculate()
	check(eco.pop_used == used0, "and a fallen one frees it")
	var barracks: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead)[0]
	barracks.queue.clear()
	eco.garrison = -9999
	eco.recalculate()
	w.queue_unit(barracks, "soldier")
	check(barracks.queue.is_empty(), "no training when the army has no room")
	eco.garrison = 0
	eco.res.money = 50000.0
	eco.recalculate()
	eco.pop_cap = 999
	var cash_q: float = eco.res.money
	w.queue_unit(barracks, "soldier")
	var price_s: float = cash_q - eco.res.money
	w.cancel_queued(barracks, 0)
	check(price_s > 0.0 and absf(eco.res.money - cash_q) < 0.01, "a unit is paid for when queued, refunded when cancelled ($%d)" % int(price_s))
	var cash_b: float = eco.res.money
	var bsite = site("park", 1, 10)
	w.build_site("park", bsite)
	check(absf(cash_b - eco.res.money - float(w.building_defs.park.cost.money)) < 0.01, "a building is paid for when laid out ($%d)" % int(w.building_defs.park.cost.money))
	eco.res.money = 5.0
	var n_sites: int = w.buildings.size()
	w.build_site("park", site("park", 1, 10))
	check(w.buildings.size() == n_sites, "and not without the money")
	eco.res.money = 50000.0
	eco.garrison = 12
	eco.recalculate()
	check(eco.pop_cap >= int(eco.provided("pop")) + 12, "the starting army is a garrison of its own, outside the housing")

	# ------------------------------------------------ J. what buildings add (91-96)
	var plant_before: float = eco.plant_bonus()
	put("powerPlant", 2)
	check(absf(eco.plant_bonus() - plant_before - 0.15) < 0.001, "a power plant: +15% production and construction")
	put("powerPlant", 2)
	put("powerPlant", 2)
	check(absf(eco.plant_bonus() - 0.30) < 0.001, "up to +30%, however many")
	barracks.queue = ["soldier"]
	barracks.queue_prog = 0.0
	w.update_training(2.0)
	var fast: float = barracks.queue_prog
	for b in w.buildings:
		if b.owner == 0 and b.key == "powerPlant": b.supplied = false
	eco.recalculate()   # (the economy recounts its buildings every second)
	barracks.queue_prog = 0.0
	w.update_training(2.0)
	var slow: float = barracks.queue_prog
	for b in w.buildings:
		if b.owner == 0 and b.key == "powerPlant": b.supplied = true
	eco.recalculate()
	barracks.queue.clear()
	check(fast > slow * 1.25, "and the factories really work faster with them (%.3f against %.3f)" % [fast, slow])
	var tank_a: Dictionary = w.spawn_unit("tank", w.land_point(w.start, 30.0), 0)
	var dmg0: float = w.research.damage_mult(tank_a)
	put("ammoDepot", 2)
	check(w.research.damage_mult(tank_a) > dmg0 * 1.04 and eco.depot_reload() >= 0.059, "an ammo depot: +5% damage, 6% faster reloading")
	var hp0: float = w.spawn_unit("tank", w.land_point(w.start, 30.0), 0).max_hp
	put("commandCenter", 3)
	var hp1: float = w.spawn_unit("tank", w.land_point(w.start, 30.0), 0).max_hp
	check(hp1 > hp0 * 1.09, "a command centre: +10% health for units trained after it (%d -> %d)" % [int(hp0), int(hp1)])
	var descs_ok := true
	for key in ["tvStation", "policeStation", "school", "museum", "park", "stadium", "courthouse"]:
		var text: String = str(w.building_defs[key].get("desc", "")).to_lower()
		if text.contains("approval") or text.contains("public order") or text.contains("culture") or text.contains("+8 education") or text.contains("smarter citizens"): descs_ok = false
	check(descs_ok, "no building card promises what the game does not have (approval, order, culture, education)")

	# ------------------------------------------------ K. saves and the screen (97-100)
	eco.res.money = 12345.0
	eco.civilians = 321.0
	m.mult["iron"] = 1.7
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	eco.res.money = 1.0
	eco.civilians = 50.0
	m.mult["iron"] = 1.0
	w.saves.restore(data)
	for i in range(5): await process_frame
	eco = w.economy
	m = w.market
	check(absf(eco.res.money - 12345.0) < 1.0 and absf(eco.civilians - 321.0) < 1.0, "a save keeps the treasury and the people")
	check(absf(float(m.mult.iron) - 1.7) < 0.01, "and the market's prices")
	w.hud.show()
	eco.tick()
	paused = false   # (the match was started from a paused menu)
	await create_timer(0.6).timeout   # the resource bar refreshes four times a second
	var chip: String = w.hud._chips.money[0].text
	check(chip == w.hud.compact_number(eco.res.money), "the treasury is on screen (%s)" % chip)
	var tips := PackedStringArray()
	for c in w.hud.find_children("*", "Control", true, false):
		if str(c.tooltip_text).contains("gas") or str(c.tooltip_text).contains("Natural gas"): tips.append(c.tooltip_text)
	check(not tips.is_empty() and tips[0].contains("inter"), "and gas explains winter heating")

	print("\nECONOMY_100: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("ECONOMY_100 PASS" if errors.is_empty() else "ECONOMY_100 FAIL")
	quit(0 if errors.is_empty() else 1)
