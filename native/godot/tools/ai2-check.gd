extends SceneTree
## Artificial intelligence, package 2 (ai_directorate.gd): the AI economy and
## automation, chips (export controls, smuggling, the shortage), AI image and
## open-source analysis, synthetic influence, model theft, Collaborative Combat
## Aircraft, air-defence battle management, the AI treaties, saves and the tab.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func finish(key: String) -> void:
	w.research.progress[key].stage = 3
	w.research._recompute()

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "un", "support", "events"])
	seed(21)
	var a = w.directorate
	var d: Node = w.diplomacy
	var foe := 1
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	finish("machineLearning")
	finish("militaryAI")
	w.economy.res.silicon = 5000.0
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq0 + Vector3(-50, 0, 40)), 0, true)
	a.st[0].level = 3
	for p in a.POOLS: a.alloc[p] = 0.0
	a.alloc.economy = 100.0
	a.update(1.0)

	# ---- the AI economy
	var fx: Dictionary = a.bonuses()
	check(float(fx.get("prodPct", 0.0)) > 0.0 and float(fx.get("researchPct", 0.0)) > 0.0, "the AI economy speeds production and research")
	check(a.automation() > 0.1 and float(fx.get("happiness", 0.0)) < -3.0, "automation puts people out of work: happiness falls (%d%% of jobs)" % roundi(a.automation() * 100.0))
	var money_use: float = float(a.upkeep().get("money", 0.0))
	a.set_retraining(true)
	check(not a.bonuses().has("happiness") and float(a.upkeep().money) > money_use, "a retraining programme ends the unrest, at a price")
	a.set_retraining(false)
	w.ai.nations.filter(func(n): return n.id == foe)[0].tech = 5.0
	var hq1: Vector3 = w.buildings.filter(func(b): return b.owner == foe and b.key == "hq")[0].root.position
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq1 + Vector3(-45, 0, 45)), foe, true)
	a.st[foe].level = 3
	a.update(1.0)
	check(a.ai_income_mult(foe) > 1.0, "a rival's AI economy raises its income")

	# ---- intelligence and analysis
	a.alloc.economy = 0.0
	a.alloc.intel = 100.0
	a.update(1.0)
	check(a.intel_mult() > 1.2 and a.recon_mult(0) > 1.1, "AI analysis: intelligence grows faster, recon passes see more")
	var i0: float = float(w.espionage.intel.get(foe, 0.0))
	w.espionage.add_report(foe, "test", "a report", 10.0)
	check(float(w.espionage.intel[foe]) - i0 > 11.0, "a report adds more intelligence")
	check(a.warns(), "AI reading of imagery foresees attacks")

	# ---- air defence and battle management
	a.alloc.intel = 0.0
	a.alloc.military = 100.0
	a.update(1.0)
	check(float(a.bonuses().get("interceptPct", 0.0)) > 0.05 and a.coordinated(0), "AI battle management: batteries share targets and intercept more")
	var Modern := preload("res://scripts/modern_warfare.gd")
	var with_ai: float = Modern.intercept_chance(w, "samSite", {"type": "cruise", "owner": 0}, foe)
	a.st[foe].level = 0
	a.update(1.0)
	var without: float = Modern.intercept_chance(w, "samSite", {"type": "cruise", "owner": 0}, foe)
	check(with_ai > without, "a rival's batteries gain from its AI too (%.2f vs %.2f)" % [with_ai, without])
	a.st[foe].level = 3
	# Two batteries, one aircraft: the second does not fire at the one the first has claimed.
	d.declare_war(0, foe, "test")
	var s1: Dictionary = w.place_building("samSite", w.test_site("samSite", hq0 + Vector3(40, 0, -60)), 0, true)
	var s2: Dictionary = w.place_building("samSite", w.test_site("samSite", hq0 + Vector3(55, 0, -60)), 0, true)
	var jet: Dictionary = w.spawn_unit("jet", s1.root.position + Vector3(0, 0, 30), foe)
	jet.node.position.y = w.height_at(jet.node.position.x, jet.node.position.z) + 26.0
	jet.air_state = "ready"
	w.economy.res.money = 100000.0
	preload("res://scripts/air_defence.gd").update(w, 0.1)
	check(float(s1.get("aa_reload", 0.0)) > 0.0 != (float(s2.get("aa_reload", 0.0)) > 0.0), "two coordinated batteries fire one missile at one aircraft")

	# ---- chips
	check(a.can_control(0) and not a.can_control(foe), "the United States can deny chips; China cannot")
	var rate1: float = a.compute_rate(foe)
	check(a.impose_controls(0, foe).contains("export controls") and a.controlled(foe), "export controls on a rival")
	check(absf(a.compute_rate(foe) - (rate1 - 1.0 * 0.5 * (1.25 if a._has(foe, "powerPlant") or a._has(foe, "nuclearReactor") else 1.0))) < 0.01, "its data centres run at half")
	w.game_time += 61.0
	a._rival_operations()
	check(a.smuggling.has(foe) and is_equal_approx(a.chip_factor(foe), 0.8), "a rival under controls smuggles chips in (80%)")
	var eu := 2
	check(a.control_blocked(eu).contains("makes its own"), "a chip-supply nation cannot be cut off")
	a.impose_controls(eu, 0)
	check(a.controlled(0) and is_equal_approx(a.chip_factor(0), 0.5), "a rival can put controls on you")
	w.economy.res.money = 5000.0
	var smug: String = a.smuggle()
	check(smug.contains("smugglers") and is_equal_approx(a.chip_factor(0), 0.8), "you can smuggle chips in")
	a.controls[0].until = w.game_time - 1.0
	a._lapse_controls()
	check(not a.controlled(0) and not a.smuggling.has(0), "the controls lapse")
	# The global chip shortage.
	var events = preload("res://scripts/world_events.gd").new(w)
	w.events = events
	check(events.cause_of("chips") == "", "no shortage with few data centres")
	for i in range(7):
		w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq0 + Vector3(-90 + i * 18, 0, 90)), 0, true)
	check(a.world_data_centres() >= 8 and events.cause_of("chips").contains("buying up"), "eight data centres buy up the world's chips")
	events.evaluate()
	check(events.active.has("chips") and is_equal_approx(a.chip_factor(0), 0.8), "a global chip shortage: data centres at 80%")
	w.events = null

	# ---- influence
	w.support.change(foe, 0.0)
	var sup: float = w.support.value(foe)
	var stab: float = float(w.espionage.stability[foe])
	a.st[0].reserve = 600.0
	a.influence_ready = 0.0
	a.st[0].level = 3
	check(a.influence_blocked(foe) == "", "a synthetic influence campaign is ready")
	var inf: String = a.influence(0, foe, "works")
	check(w.support.value(foe) < sup and float(w.espionage.stability[foe]) < stab and a.reserve(0) <= 450.0, "deepfakes turn its people against the war (%s)" % inf.substr(0, 60))
	check(a.influence_blocked(foe).contains("Ready in"), "and need time before the next")
	var own_sup: float = w.support.value(0)
	a.influence(foe, 0, "works")
	check(w.support.value(0) < own_sup, "rivals run them against you too")

	# ---- model theft
	a.st[0].level = 1
	a.st[foe].level = 4
	w.place_building("intelAgency", w.test_site("intelAgency", hq0 + Vector3(30, 0, 70)), 0, true)
	w.economy.res.money = 10000.0
	a.theft_ready = 0.0
	check(a.theft_blocked(foe) == "", "model theft against a stronger rival is ready")
	a.steal(0, foe, "works")
	check(a.level(0) == 3, "stolen weights close half the gap (1 -> 3 of 4)")
	check(a.theft_blocked(foe) != "", "and the next must wait")
	a.st[0].level = 4
	a.st[foe].level = 1
	a.steal(foe, 0, "works")
	check(a.level(foe) == 3, "rivals steal yours too")

	# ---- the treaties
	check(a.signatory(eu, "laws") and a.signatory(0, "nuclear") and not a.signatory(0, "laws"), "who signs what at the start (the EU the autonomous weapons treaty, the US the nuclear declaration)")
	a.set_doctrine("on")
	check(a.sign("laws").contains("signed") and a.doctrine_blocked("out").contains("Treaty"), "a signatory cannot take the human out of the loop")
	var rel_eu: float = d.rel(0, eu)
	check(a.withdraw("laws").contains("withdrew") and d.rel(0, eu) < rel_eu and a.doctrine_blocked("out") == "", "withdrawing frees you, and the signatories take it badly")
	w.map.nations[foe]["ai_profile"] = {"lean": "out"}
	a.signed.laws[foe] = true
	a.st[foe].level = 3
	a._rival_doctrines()
	check(a.doctrine(foe) == "on", "a rival that signed keeps a human on the loop at war")
	w.map.nations[foe].erase("ai_profile")

	# ---- collaborative combat aircraft
	var airfield = w.place_building("airfield", w.test_site("airfield", hq0 + Vector3(-80, 0, -60)), 0, true)
	var fighter: Dictionary = w.spawn_unit("jet", airfield.root.position + Vector3(0, 0, 20), 0)
	a.escort_fighter(fighter)
	check(not fighter.get("cca", false), "no wingman before the research")
	finish("collaborativeCombatAircraft")
	a.escort_fighter(fighter)
	var Future := preload("res://scripts/future_weapons.gd")
	check(fighter.get("cca", false) and Future.wing_size(fighter) == 1 and int(fighter.get("wingmen_stowed", 0)) + Future.mates(w, fighter).size() == 1, "with it a fighter takes one loyal wingman")
	fighter.air_state = "ready"
	Future.command(w, fighter)
	check(Future.mates(w, fighter).size() == 1 and Future.group_of(w, fighter).size() == 2, "the wingman flies with it as a battle group")

	# ---- saving
	a.retraining = true
	a.impose_controls(0, foe)
	a.sign("laws")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	a.retraining = false
	a.controls.clear()
	w.saves.restore(snap)
	var b = w.directorate
	check(b.retraining and b.controlled(foe) and b.signatory(0, "laws") and b.signatory(eu, "laws"), "a save keeps retraining, the controls and the treaties")
	check(w.units.filter(func(u): return not u.dead and u.key == "jet" and u.owner == 0).all(func(u): return u.get("cca", false)), "and the fighters keep their wingmen")

	# ---- the tab's pages
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	b.alloc.economy = 50.0
	b.update(1.0)
	var seen := {}
	for page in ["compute", "doctrine", "operations", "rivals"]:
		b.ui_tab = page
		w.hud.refresh_side()
		var texts: Array = w.hud._side_rows.find_children("*", "Label", true, false).map(func(l): return l.text) + w.hud._side_rows.find_children("*", "Button", true, false).map(func(x): return x.text)
		seen[page] = " | ".join(PackedStringArray(texts))
	check(seen.compute.contains("Automation") and seen.compute.contains("retraining"), "Compute page: the split and automation")
	check(seen.doctrine.contains("Treaty on Autonomous Weapons") and seen.doctrine.contains("Withdraw"), "Doctrine page: the doctrine and the treaties")
	check(seen.operations.contains("Synthetic influence") and seen.operations.contains("Steal model weights") and seen.operations.contains("Chip export controls"), "Operations page: cyber, influence, theft and chips")
	check(seen.rivals.contains("Rivals' AI"), "Rivals page")
	var dated := RegEx.create_from_string("\\b(1[89]|20)\\d\\d\\b")
	var descs: Array = b.TREATIES.values().map(func(t): return t.desc) + b.DISCOVERIES.values().map(func(t): return t.desc)
	check(dated.search(str(seen) + str(descs)) == null, "no years in the AI texts")

	print("AI2_CHECK %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("AI2_CHECK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
