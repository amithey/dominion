extends SceneTree
## The era goals ask for nothing abroad (no trade routes, no share of the land),
## and the testing tools (cheats.gd): the Settings switch, the Cheats button,
## its screen and every action on it.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light", "fog": true})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu.close()
	w.ai.set_physics_process(false)
	var r: Node = w.research
	var C := preload("res://scripts/cheats.gd")

	# ---- the era goals
	var labels := []
	for i in range(1, r.eras.size()):
		for q in r.era_requirements(i):
			labels.append(str(q[0]))
	check(not labels.has("Trade routes"), "no era asks for trade routes with other nations")
	check(not labels.any(func(t): return t.begins_with("Share of the land")), "no era asks for a share of the land")
	check(labels.has("Discoveries") and labels.has("City Centres"), "the eras still ask for discoveries and cities (%s)" % ", ".join(PackedStringArray(labels)))
	var future: Array = r.era_requirements(r.eras.size() - 1).map(func(q): return str(q[0]))
	check(future.size() >= 2 and not future.has("Share of the land"), "the Future era: %s" % ", ".join(PackedStringArray(future)))

	# ---- the switch
	w.testing_tools = false
	w.hud.refresh_cheats()
	var dock: Button = w.hud._cheats_button
	check(dock != null, "the top bar has a Cheats button")
	w.testing_tools = true
	w.hud.refresh_cheats()
	check(C.allowed(w) and dock.visible, "with Testing tools on it shows")
	var cfg_path: String = w.menu.SETTINGS
	w.menu.save_settings()
	w.testing_tools = false
	w.menu.load_settings()
	check(w.testing_tools, "the setting is saved with the others")

	# ---- the screen
	dock.pressed.emit()
	await process_frame
	var buttons: Array = w.menu._root.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree()).map(func(b): return str(b.text).strip_edges())
	check(buttons.size() >= 7 and buttons.has("Next era") and buttons.has("Back"), "the button opens the testing tools (%d buttons: %s)" % [buttons.size(), str(buttons)])
	w.menu.close()

	# ---- every action
	var money0: float = w.economy.res.money
	C.resources(w)
	check(w.economy.res.money >= money0 + 99999.0, "money and stores")
	var era0: int = r.era
	C.next_era(w)
	check(r.era == era0 + 1, "the next era (%s)" % r.eras[r.era].name)
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var site = w.test_site("farm", home + Vector3(30, 0, 30))
	var farm: Dictionary = w.place_building("farm", site, 0, false)
	check(not farm.built, "(a farm under construction)")
	C.finish_all(w)
	check(farm.built, "finish all construction")
	var fog_on: bool = w.fog.enabled
	C.toggle_fog(w)
	check(w.fog.enabled != fog_on, "the fog of war lifted")
	C.toggle_fog(w)
	check(w.fog.enabled == fog_on, "and restored")
	w.diplomacy.declare_war(1, 0)
	C.peace(w)
	check(not w.diplomacy.at_war(0, 1), "peace with every nation")
	C.everything(w)
	check(r.era == r.eras.size() - 1, "everything: the last era")
	w.testing_tools = false
	w.menu.save_settings()

	print("CHEAT_TOOLS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("CHEAT_TOOLS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
