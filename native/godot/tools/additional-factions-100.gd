extends SceneTree
## Boundary and interruption regressions for the ten additions, beyond the launch suite.
const F := preload("res://scripts/factions.gd")
const Extra := preload("res://scripts/additional_factions.gd")
const P := preload("res://scripts/additional_powers.gd")
const FP := preload("res://scripts/faction_powers.gd")
const Trade := preload("res://scripts/additional_trade.gd")
var w: Node
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func nation(owner: int, id: String) -> void:
	w.map.nations[owner] = F.nation(F.IDS.find(id), owner == 0)
	if owner == 0: w.research._recompute()
func sites(owner: int, key: String) -> Array:
	return w.buildings.filter(func(b): return b.owner == owner and b.key == key and not b.dead)
func amount(owner: int, resource: String, value: float) -> void:
	if owner > 0 and resource == "money": P.nation(w, owner).money = value
	else: P.stock(w, owner)[resource] = value
func provision(owner: int) -> void:
	for r in ["money", "food", "oil", "gas", "iron", "silicon", "uranium"]: amount(owner, r, 5000.0 if r == "money" else 300.0)
func reset(id: String, owner := 0) -> void:
	w.game_time = 1000.0
	w.power_ready.clear()
	w.power_effects.clear()
	w.power_uses.clear()
	w.selected_building = null
	w.market.sabotaged = 0
	for n in w.ai.nations:
		n.defeated = false
		n.erase("national_cargo")
	for i in range(4):
		nation(i, "usa")
		provision(i)
		for j in range(i):
			w.diplomacy.set_flag(w.diplomacy.war, i, j, false)
			w.diplomacy.set_flag(w.diplomacy.pact, i, j, true)
			w.diplomacy.set_flag(w.diplomacy.alliance, i, j, true)
			w.diplomacy.set_score(i, j, 0)
	for b in w.buildings:
		if b.dead: continue
		b.built = true
		b.supplied = true
		b.disabled_until = 0.0
		b.hp = b.max_hp
	for u in w.units: u.disabled_until = 0.0
	nation(owner, id)
	if id == "ukraine":
		var hq: Dictionary = sites(owner, "hq")[0]
		hq.hp = hq.max_hp * 0.5
func tick(seconds: float) -> void:
	w.game_time += seconds
	P.step(w, seconds)
func no_side_effects(owner: int, target: int) -> bool:
	var funds: Dictionary = P.stock(w, owner).duplicate()
	var money := P.funds(w, owner, "money")
	var count: int = w.power_effects.size()
	var blocked: bool = FP.blocked(w, owner, target) != ""
	FP.use(w, owner, target)
	return blocked and P.stock(w, owner) == funds and P.funds(w, owner, "money") == money and w.power_effects.size() == count and not w.power_ready.has(owner) and w.power_uses.is_empty()
func sea_roll(success: bool) -> void:
	# Fix the next random draw, so delivery and loss paths are tested independently.
	for value in range(10000):
		seed(value)
		var roll := randf()
		if (success and roll > 0.1) or (not success and roll < 0.01):
			seed(value)
			return
func run() -> void:
	set_meta("match_config", {"nation": 9, "players": 4, "map": "island", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for frame in range(10000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.saves.autosave_every = 0
	paused = true
	w.economy.grant_test_resources()
	var needs := ["port", "tankFactory", "powerPlant", "bank", "techPark", "farm", "school", "extractor"]
	for owner in range(4):
		for index in range(needs.size()):
			var key: String = needs[index]
			if sites(owner, key).is_empty():
				var b: Dictionary = w.place_building(key, w.start + Vector3(18 + index * 8, 0, 18 + owner * 30), owner, true)
				if key == "extractor": b.deposit = w.deposits[0]
		var sea: Vector3 = w.water_near(w.start, 240)
		w.spawn_unit("type45", sea + Vector3(owner * 10, 0, 0), owner)
		w.spawn_unit("heavyRocket", w.start + Vector3(15, 0, owner * 5), owner)
	# 60 boundary checks: the last resource is short, exact balances, JSON cooldowns.
	for owner in [0, 1]:
		for id in Extra.IDS:
			reset(id, owner)
			var target := 1 if owner == 0 else 0
			var costs: Dictionary = P.POWERS[id].costs
			var resource: String = costs.keys()[-1]
			amount(owner, resource, float(costs[resource]) - 0.01)
			check(no_side_effects(owner, target), "%s/%d: short by 0.01, no partial charge or cooldown" % [id, owner])
			for r in costs: amount(owner, r, float(costs[r]))
			FP.use(w, owner, target)
			check(costs.keys().all(func(r): return is_zero_approx(P.funds(w, owner, r))) and FP.ready_in(w, owner) > 0, "%s/%d: exact balances activate without negative stocks" % [id, owner])
			var wait_before := FP.ready_in(w, owner)
			var saved: Dictionary = JSON.parse_string(JSON.stringify(FP.capture(w)))
			w.power_ready.clear()
			w.power_effects.clear()
			FP.restore(w, saved)
			provision(owner)
			var before := P.funds(w, owner, "money")
			var used: int = w.power_uses.size()
			FP.use(w, owner, target)
			check(is_equal_approx(FP.ready_in(w, owner), wait_before) and P.funds(w, owner, "money") == before and w.power_uses.size() == used, "%s/%d: serialized cooldown blocks replay" % [id, owner])
	# 21 prerequisite checks: unfinished, unpowered by EMP, and cut off.
	for id in Extra.IDS:
		if P.POWERS[id].needs.is_empty(): continue
		for mode in ["unfinished", "disabled", "unsupplied"]:
			reset(id)
			for b in sites(0, P.POWERS[id].needs[0]):
				if mode == "unfinished": b.built = false
				elif mode == "disabled": b.disabled_until = w.game_time + 10
				else: b.supplied = false
			check(no_side_effects(0, 1), id + ": " + mode + " prerequisite blocks activation atomically")
	# Target errors and defeated owners never spend resources.
	for id in ["brazil", "pakistan"]:
		for target in [-1, 0, 4]:
			reset(id)
			check(no_side_effects(0, target), "%s: invalid target %d rejected" % [id, target])
		reset(id)
		P.nation(w, 1).defeated = true
		check(no_side_effects(0, 1), id + ": defeated target rejected")
	reset("saudi", 1)
	P.nation(w, 1).defeated = true
	check(no_side_effects(1, -1), "defeated AI cannot fund a new investment")
	# Timed and delayed effects have observable boundaries.
	reset("uk")
	var risk: float = w.market.risk()
	FP.use(w, 0)
	check(is_equal_approx(w.market.risk(), risk * 0.5), "Trade Shield halves actual cargo risk")
	tick(90)
	check(is_equal_approx(w.market.risk(), risk), "Trade Shield expires at its exact boundary")
	reset("north_korea")
	FP.use(w, 0)
	tick(45)
	check(P.bonus(w, 0, "reload") == 0 and is_equal_approx(FP.income_mult(w, 0), 0.8), "readiness ends before its economic penalty")
	tick(45)
	check(is_equal_approx(FP.income_mult(w, 0), 1.0), "readiness penalty ends exactly at 90 seconds")
	reset("pakistan")
	FP.use(w, 0, 1)
	P.use_defence_partnership(w, 2, 1)
	check(is_equal_approx(P.bonus(w, 1, "researchPct"), 0.15), "research partnerships from two allies do not stack")
	P.nation(w, 1).defeated = true
	check(P.bonus(w, 0, "researchPct") == 0, "partner defeat immediately stops research")
	# Food delivery/loss occurs only once; interruptions cannot award goodwill.
	for mode in ["arrival", "war", "pact", "port", "defeat"]:
		reset("brazil")
		amount(1, "food", 480)
		FP.use(w, 0, 1)
		if mode == "war": w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)
		if mode == "pact": w.diplomacy.set_flag(w.diplomacy.pact, 0, 1, false)
		if mode == "port":
			for b in sites(1, "port"): b.supplied = false
		if mode == "defeat": P.nation(w, 1).defeated = true
		sea_roll(true)
		tick(31)
		var arrived: bool = P.funds(w, 1, "food") == 500 and w.diplomacy.rel(0, 1) == 18
		var lost: bool = P.funds(w, 1, "food") == 480 and w.diplomacy.rel(0, 1) == 0
		check(arrived if mode == "arrival" else lost, "food aid " + mode + ": stock cap and relations are correct")
		if mode == "arrival":
			tick(31)
			check(w.diplomacy.rel(0, 1) == 18, "delivered aid cannot award relations twice")
	# Reconstruction cannot transfer to a new structure at identical coordinates.
	reset("ukraine")
	var hq: Dictionary = sites(0, "hq")[0]
	hq.hp = hq.max_hp
	var farm: Dictionary = sites(0, "farm")[0]
	farm.hp = farm.max_hp * 0.9
	var at: Vector3 = farm.root.position
	w.selected_building = hq
	FP.use(w, 0)
	var repair_count: int = w.power_effects.filter(func(e): return e.kind == "extra_repair").size()
	tick(60)
	check(repair_count > 0 and is_equal_approx(farm.hp, farm.max_hp), "reconstruction heals only missing HP, never exceeds max")
	reset("ukraine")
	farm.hp = farm.max_hp * 0.5
	FP.use(w, 0)
	w.destroy_building(farm)
	var replacement: Dictionary = w.place_building("farm", at, 0, true)
	replacement.hp *= 0.5
	var initial_hp: float = replacement.hp
	tick(30)
	check(replacement.hp == initial_hp, "rebuilding at the same coordinates cannot inherit old repairs")
	# AI commercial cargo is paid, paused, lost or delivered; it survives full saves.
	for mode in ["arrival", "random_loss", "war", "closed"]:
		reset("egypt", 1)
		for r in w.market.cfg.price: amount(1, r, 0)
		amount(1, "food", 130)
		amount(2, "food", 0)
		w.diplomacy.set_flag(w.diplomacy.pact, 1, 3, false)
		var cash_before := P.funds(w, 2, "money")
		Trade.tick(w, 1)
		var seller: Dictionary = P.nation(w, 1)
		var cargo: Dictionary = seller.get("national_cargo", {})
		if cargo.is_empty(): check(false, "AI cargo fixture did not depart"); continue
		check(P.funds(w, 1, "food") == 100 and P.funds(w, 2, "money") == cash_before - float(cargo.value), "AI " + mode + ": cargo is paid at departure")
		var seller_cash: float = seller.money
		if mode == "war": w.diplomacy.set_flag(w.diplomacy.war, 1, 2, true)
		if mode == "closed": P.effect(w, "hormuz", 0, 0.7, 200, 3)
		sea_roll(mode != "random_loss")
		Trade.tick(w, float(cargo.eta) + 1)
		if mode == "arrival":
			check(seller.money == seller_cash + float(cargo.value) and P.funds(w, 2, "food") == 30 and not seller.has("national_cargo"), "AI delivery transfers payment and goods exactly once")
		elif mode == "closed":
			check(seller.has("national_cargo") and seller.money == seller_cash and P.funds(w, 2, "food") == 0, "closed strait pauses AI cargo without paying out")
		else:
			check(not seller.has("national_cargo") and seller.money == seller_cash and P.funds(w, 2, "food") == 0, "AI " + mode + ": lost cargo awards neither money nor goods")
	# Persist a half-finished voyage through a complete world restore.
	reset("egypt", 1)
	w.diplomacy.set_flag(w.diplomacy.pact, 1, 3, false)
	Trade.tick(w, 1)
	var voyage: Dictionary = P.nation(w, 1).national_cargo
	Trade.tick(w, float(voyage.eta) / 2)
	var remaining: float = voyage.eta
	var saved_world: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(saved_world)
	check(is_equal_approx(float(P.nation(w, 1).national_cargo.eta), remaining), "full world restore keeps partial AI voyage time")
	print("ADDITIONAL_FACTIONS_100: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("FAILED: " + failure)
	print("ADDITIONAL_FACTIONS_100 PASS" if failures.is_empty() else "ADDITIONAL_FACTIONS_100 FAIL")
	quit(0 if failures.is_empty() else 1)
