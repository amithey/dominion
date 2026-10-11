extends SceneTree
const FA := preload("res://scripts/factions.gd")
const F := preload("res://scripts/regional_factions.gd")
const R := preload("res://scripts/regional_powers.gd")
const P := preload("res://scripts/additional_powers.gd")
const FP := preload("res://scripts/faction_powers.gd")
const V := preload("res://scripts/national_variants.gd")
var w: Node
var failures := 0
var count := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures += 1
	print(("ok " if ok else "FAIL ") + label)
func identity(owner: int, id: String) -> void:
	w.map.nations[owner] = FA.nation(FA.IDS.find(id), owner == 0)
	if owner == 0: w.research._recompute()
func provision() -> void:
	w.power_effects = w.power_effects.filter(func(e): return str(e.kind).begins_with("un_"))
	w.power_ready.clear()
	w.economy.grant_test_resources()
	for owner in range(1, w.map.nations.size()):
		P.nation(w, owner).money = 10000
		for key in ["oil", "gas", "iron", "silicon", "food"]: P.stock(w, owner)[key] = 100.0
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, false)
	w.diplomacy.score[0][1] = 30.0
	w.diplomacy.score[1][0] = 30.0
func building(key: String, owner := 0) -> Dictionary:
	var b: Dictionary = w.place_building(key, w.start + Vector3(20 + owner * 60, 0, 20), owner, true)
	b.supplied = true
	return b
func tick(seconds: float) -> void:
	w.game_time += seconds
	P.step(w, seconds)
func run() -> void:
	set_meta("match_config", {"nation": 22, "players": 4, "map": "island", "style": "sandbox", "rivals": [23, 26, 27]})
	change_scene_to_file("res://world.tscn")
	for i in range(10000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	check(FA.IDS.size() == 28 and FA.IDS[16] == "egypt" and FA.IDS[21] == "afghanistan", "28 identities preserve legacy indices")
	check(w.map.nations.map(func(n): return n.id) == ["yemen", "houthis", "sudan", "south_sudan"], "new identities launch in selected slots")
	check(not 1 in w.un.members() and 0 in w.un.members() and 2 in w.un.members() and 3 in w.un.members(), "Houthis excluded from UN; three sovereign states hold separate seats")
	for id in F.IDS:
		identity(0, id)
		check(not FP.power_of(w, 0).is_empty(), id + " has a usable power definition")
		check(not preload("res://scripts/national_profile.gd").summary(id).strengths.is_empty(), id + " has profile strengths")
		check(preload("res://scripts/leader_gallery.gd").portrait(FA.LEADERS[FA.IDS.find(id)]) != "", id + " has authority emblem")
		check(not w.unit_allowed(0, "nuclearSub") and not w.unit_allowed(0, "raptor") and not V.builds(w, 0, "missileSilo"), id + " cannot inherit advanced strategic weapons")
		check(w.unit_allowed(0, "soldier") and w.unit_allowed(0, "worker") and w.unit_allowed(0, "mortarTeam"), id + " retains a playable opening roster")
		w.menu.setup_options.nation = FA.IDS.find(id)
		w.menu.open_new_game()
		check(w.menu._root.find_child("FactionPicker", true, false) != null, id + " opens new-game selection")
		w.menu._root.hide()
	identity(0, "ethiopia")
	check(not V.builds(w, 0, "port") and not V.fields("gunboat", "ethiopia"), "Ethiopia is landlocked")
	identity(0, "south_sudan")
	check(not V.builds(w, 0, "shipyard") and not V.fields("jet", "south_sudan"), "South Sudan has limited ground forces and no navy")
	identity(0, "nigeria")
	w.research.progress.jetPropulsion = {"stage": 3}
	check(w.unit_allowed(0, "superTucano") and w.unit_allowed(0, "jf17") and w.research.unit_locked("jf17") == "", "Nigeria shares A-29 and JF-17 and research unlocks them")
	var airfield := building("airfield")
	provision()
	var money: float = w.economy.res.money
	w.queue_unit(airfield, "jf17")
	check(airfield.queue.has("jf17") and w.economy.res.money < money, "Nigeria queues and pays for shared fighter")
	w.cancel_queued(airfield, 0)
	check(is_equal_approx(w.economy.res.money, money), "shared fighter cancellation refunds")
	for key in F.DISCOVERIES:
		identity(0, F.DISCOVERIES[key].nation)
		w.research.era = 5
		check(w.research.blocker(key) == "", key + " available to its own nation")
		w.research.progress[key] = {"stage": 3}
		w.research._recompute()
		var fx: String = F.DISCOVERIES[key].fx.keys()[0]
		check(w.research.bonus(fx) > float(preload("res://scripts/national_profile.gd").bonuses(w, 0).get(fx, 0)), key + " changes live research bonuses")
		identity(0, "usa")
		check(w.research.blocker(key) != "", key + " remains nation-specific")
	identity(0, "yemen")
	identity(1, "sudan")
	var school := building("school")
	provision()
	P.nation(w, 1).money = 500
	check(FP.blocked(w, 0, 1).contains("cannot fund"), "unfunded aid blocked before charging")
	P.nation(w, 1).money = 1000
	money = w.economy.res.money
	FP.use(w, 0, 1)
	check(is_equal_approx(P.funds(w, 1, "money"), 400) and is_equal_approx(w.economy.res.money, money - 100), "aid reserves donor funds and charges administration")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(FP.capture(w)))
	FP.restore(w, saved)
	check(FP.ready_in(w, 0) > 0 and w.power_effects.filter(func(e): return str(e.kind).begins_with("regional_")).size() == 1, "contract and cooldown survive JSON save")
	tick(30)
	check(is_equal_approx(w.economy.res.money, money + 500), "escrow delivered once")
	tick(30)
	check(is_equal_approx(w.economy.res.money, money + 500), "aid cannot pay twice")
	provision()
	FP.use(w, 0, 1)
	var donor: float = P.funds(w, 1, "money")
	school.supplied = false
	tick(1)
	check(is_equal_approx(P.funds(w, 1, "money"), donor + 600), "lost school refunds reconstruction escrow")
	school.supplied = true
	identity(0, "ethiopia")
	var plant := building("powerPlant")
	provision()
	money = w.economy.res.money
	FP.use(w, 0, 1)
	check(is_equal_approx(P.bonus(w, 1, "prodPct"), 0.15), "hydropower helps the paying partner")
	tick(30)
	check(is_equal_approx(w.economy.res.money, money + 50), "hydropower pays only elapsed service")
	donor = P.funds(w, 1, "money")
	plant.supplied = false
	check(is_zero_approx(P.bonus(w, 1, "prodPct")), "grid bonus stops immediately without power")
	tick(1)
	check(is_equal_approx(P.funds(w, 1, "money"), donor + 300), "unused grid escrow refunded")
	plant.supplied = true
	identity(0, "nigeria")
	provision()
	FP.use(w, 0)
	check(is_equal_approx(P.bonus(w, 0, "prodPct"), 0.25), "Nigeria stabilization reaches production")
	tick(90)
	check(is_zero_approx(P.bonus(w, 0, "prodPct")), "grid stabilization expires")
	identity(0, "south_sudan")
	var mine := building("extractor")
	building("extractor", 1)
	provision()
	money = w.economy.res.money
	var oil: float = w.economy.res.oil
	FP.use(w, 0, 1)
	check(is_equal_approx(w.economy.res.oil, oil - 100), "oil contract reserves actual oil")
	tick(30)
	check(is_equal_approx(w.economy.res.money, money + 400) and is_equal_approx(P.funds(w, 1, "oil"), 200) and is_equal_approx(P.funds(w, 1, "money"), 9600), "oil exchanged for net payment, transit fee retained")
	provision()
	oil = w.economy.res.oil
	FP.use(w, 0, 1)
	mine.supplied = false
	tick(1)
	check(is_equal_approx(w.economy.res.oil, oil) and is_equal_approx(P.funds(w, 1, "money"), 10000), "interrupted oil contract refunds both sides")
	mine.supplied = true
	identity(0, "houthis")
	building("port")
	building("port", 1)
	provision()
	check(FP.blocked(w, 0, 1).contains("war"), "coastal pressure unavailable at peace")
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)
	check(FP.blocked(w, 0, 1).contains("battery"), "coastal pressure requires actual unit")
	var battery: Dictionary = w.spawn_unit("coastalDrone", w.start + Vector3(10, 0, 10), 0)
	check(battery.hp > 0 and battery.node.get_child_count() > 0, "coastal battery has live model")
	FP.use(w, 0, 1)
	check(R.bonus(w, 1, "shippingPressure") > 0 and R.bonus(w, 1, "shippingPressure") <= 0.15, "shipping pressure is bounded")
	battery.dead = true
	check(is_zero_approx(R.bonus(w, 1, "shippingPressure")), "destroyed battery ends pressure immediately")
	identity(0, "sudan")
	provision()
	var hq = P.capital(w, 0)
	hq.hp = hq.max_hp * 0.5
	var before: float = hq.hp
	FP.use(w, 0)
	tick(60)
	check(hq.hp > before and hq.hp <= hq.max_hp, "Sudan repairs existing damage over time")
	identity(0, "egypt")
	check(is_equal_approx(preload("res://scripts/additional_factions.gd").construction_mult(w, 0), 1.25), "Egypt retains its engineering advantage")
	# Exercise actual research payments and all stages, beyond cached modifiers.
	identity(0, "yemen")
	provision()
	w.research.queue.clear()
	w.research.progress.yemenInstitutions = {"stage": 0, "work": 0.0, "paid": false}
	w.research.era = 5
	check(w.research.enqueue("yemenInstitutions") == "", "new research enters the real queue")
	money = w.economy.res.money
	for stage in range(3):
		w.research.points = 100000
		w.research._work(120)
	check(w.research.done("yemenInstitutions") and w.economy.res.money < money, "all three research stages charge and complete")
	identity(0, "houthis")
	check(not w.unit_allowed(0, "jet") and not w.unit_allowed(0, "helicopter"), "Houthis do not inherit a crewed air force")
	identity(0, "yemen")
	check(not w.unit_allowed(0, "jet"), "recognized Yemen does not inherit an operational jet fleet")
	identity(0, "ethiopia")
	check(w.unit_allowed(0, "akinci") and w.unit_allowed(0, "jet"), "Ethiopia can develop its imported air categories")
	identity(0, "south_sudan")
	identity(1, "sudan")
	provision()
	oil = w.economy.res.oil
	FP.use(w, 0, 1)
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)
	tick(1)
	check(is_equal_approx(w.economy.res.oil, oil) and is_equal_approx(P.funds(w, 1, "money"), 10000), "war refunds both oil deposits")
	provision()
	FP.use(w, 0, 1)
	P.stock(w, 1).oil = 500
	tick(30)
	check(is_equal_approx(w.economy.res.oil, oil) and is_equal_approx(P.funds(w, 1, "oil"), 500), "full destination storage cancels without overflow")
	identity(0, "sudan")
	identity(1, "ethiopia")
	provision()
	building("powerPlant", 1)
	check(P.ai_target(w, 1) == 0, "AI chooses a funded hydropower partner")
	FP.use(w, 1, 0)
	check(is_equal_approx(P.bonus(w, 0, "prodPct"), 0.15), "AI grid contract reaches player production")
	var ai_money: float = P.funds(w, 1, "money")
	tick(90)
	check(is_equal_approx(P.funds(w, 1, "money"), ai_money + 450), "AI earns only the paid contract revenue")
	identity(0, "houthis")
	identity(1, "sudan")
	provision()
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)
	battery.dead = false
	FP.use(w, 0, 1)
	var pressure := R.bonus(w, 1, "shippingPressure")
	var escort: Dictionary = w.spawn_unit("gunboat", w.water_near(w.start, 240), 1)
	check(R.bonus(w, 1, "shippingPressure") < pressure, "real naval escort reduces coastal pressure")
	escort.dead = true
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, false)
	check(is_zero_approx(R.bonus(w, 1, "shippingPressure")), "peace ends coastal pressure immediately")
	identity(0, "nigeria")
	identity(1, "houthis")
	identity(2, "sudan")
	provision()
	building("port", 2)
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, true)
	w.diplomacy.set_flag(w.diplomacy.pact, 0, 2, true)
	w.spawn_unit("coastalDrone", w.start + Vector3(80, 0, 15), 1)
	FP.use(w, 1, 0)
	w.economy.recalculate()
	var route := {"id": 91, "nation": 2, "res": "iron", "dir": "export", "qty": 25, "total": 0, "status": "", "overland": false, "shipment": {"qty": 25, "value": 100, "eta": 100.0}}
	w.market.routes = [route]
	w.market.tick()
	check(float(route.shipment.eta) > 100.0 - w.market.TICK, "coastal pressure slows an actual cargo already at sea")
	route.overland = true
	var eta: float = route.shipment.eta
	w.market.tick()
	check(is_equal_approx(float(route.shipment.eta), eta - w.market.TICK), "land freight is unaffected by coastal pressure")
	w.market.routes.clear()
	# Full campaign save, including the two Yemeni sides and two Sudans.
	identity(0, "yemen")
	identity(1, "houthis")
	identity(2, "sudan")
	identity(3, "south_sudan")
	var campaign: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(campaign)
	check(w.map.nations.map(func(n): return n.id) == ["yemen", "houthis", "sudan", "south_sudan"], "full campaign preserves four distinct identities")
	check(not 1 in w.un.members() and 3 in w.un.members(), "full campaign preserves UN status")
	check(w.un.production_mult(3) < 1, "South Sudan carries the standing arms embargo")
	print("REGIONAL_FACTIONS %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", count, failures])
	quit(1 if failures else 0)
