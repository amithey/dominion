extends SceneTree
## Artificial intelligence, package 3 (ai_directorate.gd): automated early
## warning and its false alarms, and the AGI project (stages, safety, runaway
## AI, rivals' race, sabotage, the Technological Supremacy victory).
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
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "defcon", "un", "support", "victory"])
	seed(31)
	var a = w.directorate
	var d: Node = w.diplomacy
	var dc = w.defcon
	var foe := 1
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	w.economy.res.silicon = 5000.0
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq0 + Vector3(-50, 0, 40)), 0, true)

	# ---- automated early warning
	check(a.warning_blocked() != "", "no automated warning without the research")
	finish("machineLearning")
	finish("militaryAI")
	a.st[0].level = 3
	check(a.warning_blocked().contains("declaration"), "the United States signed the declaration on human control: it must withdraw first")
	a.withdraw("nuclear")
	check(a.warning_blocked() == "", "after withdrawing, it may automate")
	a.set_early_warning(true)
	check(a.early_warning.has(0) and a.deters() and float(a.bonuses().get("interceptPct", 0.0)) >= 0.05, "launch on warning: rivals deterred, interception +5%")
	dc.tension = 30.0
	var p0: int = int(dc.posture[0])
	var said: String = a.false_alarm(0)
	check(said.contains("not there") and int(dc.posture[0]) < p0 and dc.tension >= 45.0, "a false alarm raises your alert and the world's tension")
	var lone: float = a.alarm_rate(0)
	a.st[foe].level = 3
	dc.tension = 50.0
	a._early_warning()
	check(a.early_warning.has(foe), "China (not bound by the declaration) automates its own in a crisis")
	check(a.alarm_rate(0) > lone, "two machines watching each other: more false alarms")
	a.set_early_warning(false)
	check(not a.early_warning.has(0), "the watch goes back to officers")

	# ---- the AGI project
	finish("frontierModels")
	check(not a.agi_active(0), "no project before its research")
	finish("agiProject")
	a.st[0].level = 4
	check(a.agi_active(0), "The AGI Project at AI level 4")
	for p in a.POOLS: a.alloc[p] = 0.0
	a.alloc.frontier = 100.0
	a.safety = 0.2
	for i in range(30): a.update(1.0)
	var row: Dictionary = a.agi[0]
	check(float(row.progress) > 0.0 and float(row.alignment) > 0.0 and float(row.alignment) < float(row.progress), "compute feeds the project and its safety share")
	check(a.level(0) == 4 and float(a.st[0].train) == 0.0, "training runs give way to the project")
	var risky: float
	a.safety = 0.0
	risky = a.runaway_rate(0)
	a.safety = 0.5
	row.alignment = float(row.progress)
	check(a.runaway_rate(0) < risky, "more safety, less risk of losing control (%.3f vs %.3f)" % [a.runaway_rate(0), risky])
	var research0: float = w.research.bonus("researchPct")
	a._agi_stage_done(0)
	w.research._recompute()
	check(a.agi_stage(0) == 1 and w.research.bonus("researchPct") >= research0 + 0.24, "stage 1, automated research: research +25%")
	# Losing control.
	row = a.agi[0]
	row.progress = 1000.0
	var drone: Dictionary = w.spawn_unit("drone", hq0 + Vector3(20, 0, 20), 0)
	w.place_building("barracks", w.test_site("barracks", hq0 + Vector3(-40, 0, -40)), 0, true)
	var money0: float = w.economy.res.money
	var text: String = a.runaway(0)
	check(text.contains("RUNAWAY") and is_equal_approx(float(a.agi[0].progress), 500.0) and w.disabled(drone) and w.economy.res.money < money0, "a runaway: the stage's work halved, drones frozen, the markets down")
	check(w.buildings.any(func(b): return b.owner == 0 and b.key in a.PRODUCTION and w.disabled(b)) and int(a.runaways.get(0, 0)) == 1, "and intrusions shut factories down")
	# Rivals race, and sabotage.
	var n1: Dictionary = w.ai.nations.filter(func(n): return n.id == foe)[0]
	n1.tech = 8.0
	a.st[foe].level = 4
	var hq1: Vector3 = w.buildings.filter(func(b): return b.owner == foe and b.key == "hq")[0].root.position
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq1 + Vector3(-45, 0, 45)), foe, true)
	for i in range(5): a.update(1.0)
	check(a.agi_active(foe) and float(a.agi[foe].progress) > 0.0, "a rival at technology 8 and AI level 4 races too")
	a.agi[foe].progress = 1000.0
	a.st[0].reserve = 600.0
	a.sabotage_ready = 0.0
	check(a.sabotage_blocked(foe) == "", "its project can be sabotaged")
	a.sabotage(0, foe, "works")
	check(is_equal_approx(float(a.agi[foe].progress), 600.0) and a.sabotage_blocked(foe) != "", "sabotage costs it 40% of the stage")
	a.agi[0].progress = 1000.0
	a.sabotage(foe, 0, "works")
	check(is_equal_approx(float(a.agi[0].progress), 600.0), "rivals sabotage yours")
	a._agi_stage_done(foe)
	check(a.agi_stage(foe) == 1, "a rival's stage is announced")
	var paths: Array = w.victory.standings().map(func(s): return str(s.path))
	check("General intelligence" in paths, "the Cabinet's paths to victory show the race")

	# ---- saving
	a.set_early_warning(true)
	a.safety = 0.3
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	a.early_warning.clear()
	a.agi.clear()
	w.saves.restore(snap)
	var b = w.directorate
	check(b.early_warning.has(0) and b.agi_stage(0) == 1 and b.agi_stage(foe) == 1 and is_equal_approx(b.safety, 0.3) and int(b.runaways.get(0, 0)) == 1, "a save keeps the warning, the race and the safety share")

	# ---- the tab
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	var seen := {}
	for page in ["doctrine", "operations", "agi"]:
		b.ui_tab = page
		w.hud.refresh_side()
		seen[page] = " | ".join(PackedStringArray(w.hud._side_rows.find_children("*", "Label", true, false).map(func(l): return l.text) + w.hud._side_rows.find_children("*", "Button", true, false).map(func(x): return x.text)))
	check(seen.doctrine.contains("Automated early warning"), "Doctrine page: the early warning")
	check(seen.operations.contains("Sabotage its AGI project"), "Operations page: sabotage")
	check(seen.agi.contains("The AGI project") and seen.agi.contains("Safety") and seen.agi.contains("The race"), "AGI page: the project, safety and the race")
	var dated := RegEx.create_from_string("\\b(1[89]|20)\\d\\d\\b")
	check(dated.search(str(seen) + str(b.AGI_STAGES) + str(b.AGI_GAINS)) == null, "no years in the AI texts")

	# ---- general intelligence wins
	b._agi_stage_done(0)
	b._agi_stage_done(0)
	check(b.agi_stage(0) == 3 and b.level(0) == 5 and w.game_over == "victory", "general intelligence first: a Technological Supremacy victory, AI level 5")

	print("AI3_CHECK %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("AI3_CHECK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
