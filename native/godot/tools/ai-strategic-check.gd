extends SceneTree
## The strategic AI applications (research: native/AI-STRATEGIC-USE-RESEARCH-2026-10-11.md):
## who uses what (ai_use_data.gd), the nine new applications and their effects in
## play, automated retaliation and its accidents, undersea sensing and the second
## strike, AI exports, the second generation (the next research stage), saves, the
## rivals' priorities and the screens.
var errors: Array[String] = []
var passed := 0
var w: Node
const F := preload("res://scripts/factions.gd")
const Data := preload("res://scripts/ai_applications_data.gd")
const Use := preload("res://scripts/ai_use_data.gd")
const AIData := preload("res://scripts/ai_data.gd")
const Strategic := preload("res://scripts/ai_strategic.gd")
const NEW := ["revenue", "targeting", "counterDrone", "undersea", "surveillance", "infoShield", "export", "deadHand", "biosecurity"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	# ---- the record
	for id in F.IDS:
		check(Use.has_record(id), "%s: an entry in the record" % id)
		for k in Use.record(id):
			check(k in Use.DOMAINS and str(Use.record(id)[k][0]) in ["fielded", "developing", "barred", "pledged"] and str(Use.record(id)[k][1]).length() > 20, "%s/%s: a status and its evidence" % [id, k])
			var text: String = str(Use.record(id)[k][1])
			var dated := false
			for y in range(1950, 2040):
				if str(y) in text: dated = true
			check(not dated, "%s/%s: no year in the game's text" % [id, k])
	check(Use.status("germany", "surveillance") == "barred", "the EU's law bars mass surveillance")
	check(Use.status("russia", "deadHand") == "fielded" and Use.status("north_korea", "deadHand") == "fielded", "Russia and North Korea automate retaliation")
	for id in ["usa", "china", "uk", "france"]:
		check(Use.status(id, "deadHand") == "pledged" and "nuclear" in AIData.entry(id).signs, "%s pledged human control of nuclear use, and is bound by the declaration" % id)
	for id in ["china", "russia", "iran"]:
		check(Use.status(id, "surveillance") == "fielded" and Use.status(id, "influence") == "fielded", "%s fields mass surveillance and influence operations" % id)
	check(Use.work_factor("russia", "deadHand") == 0.5 and Use.work_factor("ukraine", "revenue") == 0.8 and Use.work_factor("afghanistan", "revenue") == 1.0, "fielded halves the trials, developing 80%")
	for k in NEW:
		var p: Dictionary = Data.PROGRAMS[k]
		check(Data.discoveries().has(p.research), "%s: a discovery" % k)
	check(Data.discoveries().has(Data.SECOND_GENERATION), "the second generation is a discovery")

	# ---- in play: Russia, against the United States and China
	set_meta("match_config", {"map": "crown", "players": 3, "nation": F.IDS.find("russia"), "rivals": [0, 1], "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "defcon", "events", "support", "un"])
	var a = w.directorate
	var apps = a.applications
	var d: Node = w.diplomacy
	for key in ["machineLearning", "militaryAI", "frontierModels", Data.SECOND_GENERATION]:
		w.research.progress[key].stage = 3
	for k in Data.PROGRAMS:
		w.research.progress[Data.PROGRAMS[k].research].stage = 3
	w.research.era = 5
	for res in w.economy.res: w.economy.res[res] = 100000.0
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var placed := []
	for key in ["aiDataCenter", "aiDataCenter", "aiDataCenter", "aiDataCenter", "fusionCell", "missileSilo", "policeStation", "tvStation", "bank", "samSite", "hospital", "university", "shipyard"]:
		var site = w.test_site(key, hq + Vector3(randf_range(-60, 60), 0, randf_range(-60, 60)))
		if site != null:
			w.place_building(key, site, 0, true)
			placed.append(key)
	check(placed.has("missileSilo") and placed.has("policeStation") and placed.has("fusionCell"), "facilities built (%s)" % ", ".join(PackedStringArray(placed)))
	a.st[0].level = 3
	a.alloc = {"military": 40.0, "economy": 20.0, "intel": 30.0, "frontier": 10.0}
	a._refresh(0)
	for i in range(w.map.nations.size()): a.st[i].reserve = 0.0
	check(apps.eligible(0, "deadHand") == "", "Russia may automate retaliation (%s)" % apps.eligible(0, "deadHand"))
	# Trials: a fielded use needs half the compute.
	apps.start(0, "deadHand")
	var before: float = float(apps.row(0, "deadHand").work)
	apps.update()
	var fast: float = float(apps.row(0, "deadHand").work) - before
	apps.pause(0)
	apps.start(0, "revenue")
	before = float(apps.row(0, "revenue").work)
	apps.update()
	var normal: float = float(apps.row(0, "revenue").work) - before
	apps.pause(0)
	check(absf(fast / maxf(0.0001, normal) - 1.6) < 0.01, "Russia's trials of what it fields (its dead hand) run 1.6x those it only develops (%.3f vs %.3f)" % [fast, normal])
	var rel_us: float = d.rel(0, 1)
	for k in NEW + ["strategic"]:
		apps.row(0, k).validated = true
		apps.commission(0, k)
	apps.refresh()
	var running: Array = NEW.filter(func(k): return apps.factor(0, k) > 0.0)
	check(running.size() >= 8, "the strategic applications run (%s)" % ", ".join(PackedStringArray(running)))
	check(F.identity(w, 1) == "usa" and d.rel(0, 1) <= rel_us - 5.99, "the democracies think less of a surveillance state (%.0f -> %.0f)" % [rel_us, d.rel(0, 1)])
	w.research._recompute()
	check(w.research.bonus("incomePct") >= 0.05 and w.research.bonus("interceptPct") >= 0.06, "revenue analytics and counter-drone feed the economy and air defence")

	# ---- targeting support and undersea sensing
	var gun := {"owner": 0, "key": "artillery"}
	var with_t: float = a.damage_mult(gun)
	var sub: float = a.damage_mult({"owner": 0, "key": "destroyer"}, {"key": "submarine"})
	var tank: float = a.damage_mult({"owner": 0, "key": "destroyer"}, {"key": "tank"})
	a.st[0].doctrine = "in"
	var risk_on: float = a.incident_rate(0)
	apps.suspend(0, "targeting")
	var without_t: float = a.damage_mult(gun)
	check(with_t > without_t + 0.05, "target lists make the guns deadlier (%.2f vs %.2f)" % [with_t, without_t])
	check(sub > tank + 0.15, "undersea sensing: submarines hit harder (%.2f vs %.2f)" % [sub, tank])
	check(risk_on > 0.0 and a.incident_rate(0) == 0.0, "a human approving does not remove targeting's civilian risk (%.3f, none without it)" % risk_on)
	apps.commission(0, "targeting")
	check(Strategic.second_strike(w, 1, 0.8) < 0.8, "a rival's second strike is less certain against your sonar")

	# ---- surveillance and counter-disinformation
	d.declare_war(1, 0)
	var s0: float = w.support.value(0)
	w.support.step(60.0)
	var watched: float = s0 - w.support.value(0)
	apps.suspend(0, "surveillance")
	w.support.support[0] = s0
	w.support.step(60.0)
	var free: float = s0 - w.support.value(0)
	check(watched < free and watched > 0.0, "surveillance slows war-weariness (%.2f vs %.2f)" % [watched, free])
	apps.commission(0, "surveillance")
	w.support.support[0] = 60.0
	a.influence(1, 0, "works")
	var shielded: float = 60.0 - w.support.value(0)
	apps.suspend(0, "infoShield")
	w.support.support[0] = 60.0
	a.influence(1, 0, "works")
	var exposed: float = 60.0 - w.support.value(0)
	check(shielded < exposed, "counter-disinformation halves a campaign's harm (%.1f vs %.1f)" % [shielded, exposed])
	apps.commission(0, "infoShield")

	# ---- automated retaliation
	check(Strategic.armed(w, 0), "the dead hand is armed")
	for key in preload("res://scripts/wmd.gd").NUCLEAR: w.missiles.stock[key] = 0
	w.missiles.stock["nuke"] = 3
	var flying: int = w.missiles.flying.size()
	w.defcon.nuclear_used(1, [0])
	check(int(w.missiles.stock.nuke) == 2 and w.missiles.flying.size() == flying + 1, "a nuclear attack is answered by the machine, with no order given")
	check(Strategic.accident(w, 0, 0.99) == "" and int(w.missiles.stock.nuke) == 2, "most false warnings fire nothing")
	var fired: String = Strategic.accident(w, 0, 0.0)
	check(fired.contains("false") and int(w.missiles.stock.nuke) == 1, "but an armed machine can fire on a false warning: %s" % fired.left(90))
	var p_plain: float = Strategic.ACCIDENT * (1.0 - 0.6 * apps.factor(0, "strategic"))
	check(apps.factor(0, "strategic") > 0.0 and p_plain < Strategic.ACCIDENT, "strategic warning verification makes the accident rarer (%.3f)" % p_plain)
	check(apps.eligible(1, "deadHand") != "" or F.identity(w, 1) == "russia", "a pledged rival (%s) may not automate: %s" % [F.identity(w, 1), apps.eligible(1, "deadHand")])

	# ---- the law: the EU may not run mass surveillance
	var original: Dictionary = w.map.nations[0].duplicate(true)
	w.map.nations[0] = F.nation(F.IDS.find("germany"), true)
	check(apps.eligible(0, "surveillance").begins_with("Barred"), "as the EU: %s" % apps.eligible(0, "surveillance").left(70))
	w.map.nations[0] = original

	# ---- AI exports
	d.set_flag(d.war, 0, 2, false)
	d.change(0, 2, 50.0)
	var buyer: Dictionary = w.ai.nations.filter(func(n): return int(n.id) == 2)[0]
	buyer.money = 5000.0
	var rel: float = d.rel(0, 2)
	var cash: float = w.economy.res.money
	check(apps.export_blocked(0, 1) != "", "no sale to an enemy: %s" % apps.export_blocked(0, 1))
	var sold: String = apps.export_to(0, 2)
	check(d.rel(0, 2) >= rel + 9.9 and w.economy.res.money > cash and float(buyer.money) < 5000.0, "a package sold: %s" % sold.left(80))
	check(apps.export_blocked(0, 2).begins_with("Next package"), "one sale at a time")

	# ---- the next stage: the second generation
	var inc0: float = apps.bonuses().get("incomePct", 0.0)
	check(apps.upgrade_blocked(0, "revenue").begins_with("Field experience"), "the second generation waits on field experience")
	for i in range(10): apps.update()
	check(float(apps.row(0, "revenue").exp) > 0.0, "running gathers field experience")
	apps.row(0, "revenue").exp = apps.experience_needed("revenue")
	check(apps.upgrade_blocked(0, "revenue") == "", "experience and the discovery: ready to upgrade")
	cash = w.economy.res.money
	apps.upgrade(0, "revenue")
	check(int(apps.row(0, "revenue").gen) == 2 and w.economy.res.money < cash, "the second generation bought")
	check(apps.bonuses().get("incomePct", 0.0) > inc0 + 0.02, "and half again as strong (%.3f -> %.3f)" % [inc0, apps.bonuses().get("incomePct", 0.0)])

	# ---- saves
	var snap: Dictionary = JSON.parse_string(JSON.stringify(a.capture()))
	apps.row(0, "revenue").gen = 1
	apps.export_ready.clear()
	a.restore(snap)
	check(int(apps.row(0, "revenue").gen) == 2 and float(apps.row(0, "revenue").exp) > 0.0 and apps.export_ready.has(0), "a save keeps the generation, the experience and the export cooldown")

	# ---- rivals put what they field first
	var rival: Dictionary = w.ai.nations.filter(func(n): return int(n.id) == 1)[0]
	rival.tech = 7.0
	rival.money = 100000.0
	a.st[1].level = 3
	var rhq: Vector3 = w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0].root.position
	for key in ["aiDataCenter", "bank", "policeStation", "tvStation", "university"]:
		var site = w.test_site(key, rhq + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40)))
		if site != null: w.place_building(key, site, 1, true)
	a._refresh(1)
	apps.projects.erase(1)
	apps._rivals()
	var rid: String = F.identity(w, 1)
	check(apps.projects.has(1) and str(apps.projects[1]) in Use.fielded(rid), "%s starts with what it fields: %s (fields %s)" % [rid, apps.projects.get(1, "nothing"), ", ".join(PackedStringArray(Use.fielded(rid)))])

	# ---- the screens
	a.ui_tab = "applications"
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	for group in ["doomsday", "state", "security", "civil"]:
		apps.category = group
		w.hud.refresh_side()
		await process_frame
		var texts: Array = w.hud._side_rows.find_children("*", "Label", true, false).map(func(x): return x.text)
		var keys: Array = preload("res://scripts/ai_applications_panel.gd").GROUPS[group]
		check(keys.all(func(k): return texts.any(func(t): return str(Data.PROGRAMS[k].name) in t)), "%s: every application on screen" % group)
		if group == "doomsday":
			check(texts.any(func(t): return "Your nation: Fielded" in t), "the doomsday tab shows Russia's own record")
	apps.category = "world"
	w.hud.refresh_side()
	await process_frame
	var world_texts: Array = w.hud._side_rows.find_children("*", "Label", true, false).map(func(x): return x.text)
	check(world_texts.any(func(t): return "Who uses AI for what" in t) and world_texts.any(func(t): return "Automated retaliation" in t) and world_texts.any(func(t): return d.name_of(1) in t), "who uses what: every nation and its record")
	var buttons: Array = w.hud._side_rows.find_children("*", "Button", true, false).map(func(b): return b.text)
	apps.category = "state"
	w.hud.refresh_side()
	await process_frame
	buttons = w.hud._side_rows.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(buttons.any(func(t): return str(t).begins_with("Sell to")), "the export buttons")

	print("AI_STRATEGIC %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("AI_STRATEGIC %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
