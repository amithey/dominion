extends SceneTree
const Data := preload("res://scripts/ai_applications_data.gd")
const F := preload("res://scripts/factions.gd")
const National := preload("res://scripts/ai_data.gd")
var errors: Array[String] = []
var count := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: errors.append(label)
	print(("ok " if ok else "FAIL ") + label)
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "defcon", "events", "support", "un"])
	var a = w.directorate
	var apps = a.applications
	check(apps.start_blocked(0, "administration") != "", "no application before AI and research")
	for key in ["machineLearning", "militaryAI", "frontierModels"]:
		w.research.progress[key].stage = 3
	w.research.era = 5
	w.economy.grant_test_resources()
	for res in w.economy.res: w.economy.res[res] = 100000.0
	var hq: Vector3 = w.start
	var facilities := ["aiDataCenter", "powerPlant", "fusionCell", "university", "hospital", "farm", "library", "school", "barracks", "techPark"]
	for i in range(facilities.size()):
		w.place_building(facilities[i], hq + Vector3(45.0 + i * 17.0, 0, 65.0), 0, true)
	for i in range(5): w.place_building("aiDataCenter", hq + Vector3(45 + i * 17, 0, 100), 0, true)
	a.st[0].level = 4
	a.alloc = {"military": 25.0, "economy": 25.0, "intel": 25.0, "frontier": 25.0}
	a._refresh(0)
	for key in Data.PROGRAMS:
		var p: Dictionary = Data.PROGRAMS[key]
		check(w.research.discoveries.has(p.research), key + " in research tree")
		check(w.research.effects_of(p.research).is_empty(), key + " research alone gives no deployment bonus")
		w.research.progress[p.research].stage = 3
	check(apps.eligible(0, "administration") == "", "US ready for validated public services")
	var cash: float = w.economy.res.money
	apps.start(0, "administration")
	check(is_equal_approx(cash - w.economy.res.money, apps.price("administration", false)), "validation charges cash once")
	check(apps.start_blocked(0, "agriculture") != "", "one validation per nation")
	check(apps.commission_blocked(0, "administration") != "", "cannot deploy an unvalidated model")
	var frontier: float = a.flow(0, "frontier")
	check(is_equal_approx(apps.training_flow(0), frontier * 0.5), "validation reserves half frontier flow, without duplicating compute")
	apps.update()
	check(float(apps.row(0, "administration").work) > 0.0 and apps.bonuses().is_empty(), "trials advance but give no operational bonus")
	apps.pause(0)
	cash = w.economy.res.money
	apps.start(0, "administration")
	check(is_equal_approx(cash, w.economy.res.money), "resume does not charge validation again")
	for i in range(180): apps.update()
	check(bool(apps.row(0, "administration").validated) and not apps.projects.has(0), "local validation finishes from real compute")
	check(apps.factor(0, "administration") == 0.0, "validated model waits for commissioning")
	cash = w.economy.res.money
	apps.commission(0, "administration")
	check(is_equal_approx(cash - w.economy.res.money, apps.price("administration", true)), "commissioning charges remaining capital")
	check(apps.factor(0, "administration") > 0.99 and float(a.bonuses().incomePct) > 0.06, "commissioned programme reaches live economic bonuses")
	check(float(a.upkeep().money) >= apps.upkeep() and apps.upkeep() > 0, "operating costs reach economy upkeep")
	apps.suspend(0, "administration")
	check(apps.factor(0, "administration") == 0.0 and apps.upkeep() == 0.0, "suspension removes effect and cost")
	cash = w.economy.res.money
	apps.commission(0, "administration")
	check(is_equal_approx(cash, w.economy.res.money), "commissioned service resumes without a second capital charge")
	for key in Data.PROGRAMS:
		apps.row(0, key).validated = true
		apps.commission(0, key)
	check(apps.factor(0, "science") > 0.0, "frontier research automation is commissionable")
	check(w.research.bonus("trainPct") > 0.0 and w.research.bonus("foodPct") >= 0.12, "logistics and farming feed gameplay effects")
	var barracks: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks")[0]
	barracks.queue = ["soldier"]
	barracks.queue_prog = 0.0
	w.update_training(0.2)
	var fast: float = barracks.queue_prog
	apps.suspend(0, "logistics")
	barracks.queue_prog = 0.0
	w.update_training(0.2)
	check(fast > float(barracks.queue_prog), "commissioned logistics speeds actual unit training")
	barracks.queue.clear()
	apps.commission(0, "logistics")
	var hi: float = apps.factor(0, "industry")
	a.alloc.economy = 1.0
	apps.refresh()
	check(apps.factor(0, "industry") < hi and apps.factor(0, "industry") > 0.0, "shared compute proportionally limits coverage")
	a.alloc.economy = 25.0
	w.economy.res.money = 0.0
	apps.refresh()
	check(apps.bonuses().is_empty(), "no cash stops operational effects")
	w.economy.res.money = 100000.0
	var farm: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "farm")[0]
	farm.disabled_until = w.game_time + 100.0
	for b in w.buildings:
		if b.owner == 0 and b.key == "farm": b.disabled_until = w.game_time + 100.0
	apps.refresh()
	check(apps.factor(0, "agriculture") == 0.0, "disabled local facility stops its programme")
	for b in w.buildings:
		if b.owner == 0 and b.key == "farm": b.disabled_until = 0.0
	apps.refresh()
	check(apps.factor(0, "agriculture") > 0.0, "service resumes after facility recovery")
	a.st[0].reserve = 200.0
	w.diplomacy.set_flag(w.diplomacy.war, 0, 1, false)
	var rel: float = w.diplomacy.rel(0, 1)
	cash = w.economy.res.money
	apps.consult(0, 1)
	check(is_equal_approx(w.diplomacy.rel(0, 1), rel + 8.0) and is_equal_approx(cash - w.economy.res.money, 250.0), "consultation changes real relations and pays cash")
	check(is_equal_approx(a.reserve(0), 160.0) and apps.consultation_blocked(0, 2) != "", "consultation spends reserve and cooldown spans all targets")
	var alarm: float = a.alarm_rate(0)
	apps.suspend(0, "strategic")
	check(a.alarm_rate(0) > alarm, "verification reduces false-alarm risk")
	var defence: float = a.cyber_defence(0)
	apps.suspend(0, "cyber")
	check(a.cyber_defence(0) < defence, "cyber service improves defence after its compute cost")
	apps.commission(0, "strategic")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(a.capture()))
	apps.suspend(0, "administration")
	a.restore(snap)
	check(bool(apps.row(0, "administration").enabled) and apps.consultation_blocked(0, 2) != "", "JSON save restores deployments and cooldown")
	var old: Dictionary = a.capture()
	old.erase("applications")
	a.restore(old)
	check(apps.rows.is_empty() and apps.projects.is_empty(), "older saves initialise empty programmes")
	var original: Dictionary = w.map.nations[0].duplicate(true)
	for i in range(F.IDS.size()):
		w.map.nations[0] = F.nation(i, true)
		check(Data.has_evidence(F.IDS[i]) and apps.country(0)[2].size() == 4, F.IDS[i] + " explicit evidence and application priorities")
		for key in Data.PROGRAMS:
			var p: Dictionary = Data.PROGRAMS[key]
			if National.ceiling(w, 0) < int(p.level):
				check(National.beyond(w, 0, p.research) != "" and apps.eligible(0, key) != "", F.IDS[i] + " cannot bypass " + key + " capacity")
	w.map.nations[0] = F.nation(F.IDS.find("nigeria"), true)
	check(apps.eligible(0, "strategic") != "" and National.beyond(w, 0, "aiStrategicVerification") != "", "non-nuclear state cannot research or commission nuclear verification")
	w.map.nations[0] = original
	# Rival follows national priorities, validates, pays and commissions without player orders.
	var rival: Dictionary = w.ai.nations.filter(func(n): return int(n.id) == 1)[0]
	rival.tech = 7.0
	rival.money = 100000.0
	a.st[1].level = 4
	var rhq: Vector3 = w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0].root.position
	for key in ["powerPlant", "school", "aiDataCenter"]: w.place_building(key, rhq + Vector3(35 + randf() * 20, 0, 45), 1, true)
	a._refresh(1)
	apps._rivals()
	check(apps.projects.has(1), "rival starts a national application")
	if apps.projects.has(1):
		var key: String = apps.projects[1]
		apps.row(1, key).work = float(Data.PROGRAMS[key].work) - 0.001
		apps.update()
		var before: float = rival.money
		apps._rivals()
		check(bool(apps.row(1, key).enabled) and rival.money < before, "rival pays for validated deployment")
	a.ui_tab = "applications"
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	for group in ["civil", "security", "state"]:
		apps.category = group
		w.hud.refresh_side()
		await process_frame
		var texts: Array = w.hud._side_rows.find_children("*", "Label", true, false).map(func(x): return x.text)
		var keys: Array = preload("res://scripts/ai_applications_panel.gd").GROUPS[group]
		check(keys.all(func(k): return texts.any(func(t): return str(Data.PROGRAMS[k].name) in t)), group + " application UI contains every service")
	preload("res://scripts/ai_applications_panel.gd").open_research(w.hud, "aiCropForecasts")
	check(w.hud._rs.visible and w.hud._rs_sel == "aiCropForecasts", "research shortcut opens the exact discovery")
	print("AI_APPLICATIONS: %d checks, %d failures" % [count, errors.size()])
	print("AI_APPLICATIONS PASS" if errors.is_empty() else "AI_APPLICATIONS FAIL " + str(errors))
	quit(0 if errors.is_empty() else 1)
