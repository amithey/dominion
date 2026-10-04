extends SceneTree
## Intelligence without a click a minute (espionage.gd): the agency opens with
## its first agent, standing orders grow a network and keep a dossier fresh on
## their own, and intelligence fades half as fast as before.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

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
	var e: Node = w.espionage
	w.economy.res.money = 20000.0
	e.tick()
	check(e.agents.is_empty(), "no agency, no agent")
	w.place_building("intelAgency", w.test_site("intelAgency", w.start), 0, true)
	w.economy.recalculate()
	e.tick()
	check(e.agents.size() == 1 and e.ready_agents().size() == 1, "the agency opens with its first agent, free")
	e.tick()
	check(e.agents.size() == 1, "only one is given")
	# Standing orders on nation 1: no click after this one.
	e.standing[1] = true
	var spent0: float = w.economy.res.money
	var minutes := 0.0
	while (e.network[1] < 60.0 or e.intel[1] < 40.0) and minutes < 15.0:
		e.advance(10.0)
		e.tick()
		minutes += 10.0 / 60.0
	check(e.network[1] >= 60.0 and e.intel[1] >= 40.0, "standing orders alone grow the network to %d and intelligence to %d in %.1f minutes, one agent" % [int(e.network[1]), int(e.intel[1]), minutes])
	check(w.economy.res.money < spent0, "each job is paid for ($%d)" % int(spent0 - w.economy.res.money))
	# A dossier kept fresh.
	e.advance(200.0)
	for i in range(30):
		e.advance(10.0)
		e.tick()
	check(e.dossiers.has(1) and e.clock - float(e.dossiers[1].t) <= 180.0, "and the dossier is kept fresh (%ds old)" % int(e.clock - float(e.dossiers[1].t)))
	# Withdrawn: nothing more.
	e.standing.erase(1)
	e.missions.clear()
	for a in e.agents: a.status = "ready"
	var before: float = w.economy.res.money
	for i in range(12):
		e.advance(10.0)
		e.tick()
	check(e.missions.is_empty() and is_equal_approx(before, w.economy.res.money) or w.economy.res.money >= before - 1.0, "withdrawn, the agents wait for orders")
	# Slower decay.
	var intel0: float = e.intel[1]
	e.tick()
	check(is_equal_approx(intel0 - e.intel[1], 0.18) or intel0 < 0.2, "intelligence fades 0.18 a tick (was 0.35)")
	print("\nINTEL_STANDING: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("INTEL_STANDING PASS" if errors.is_empty() else "INTEL_STANDING FAIL")
	quit(0 if errors.is_empty() else 1)
