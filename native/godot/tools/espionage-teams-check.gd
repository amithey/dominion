extends SceneTree
## Espionage teams (espionage.gd): several agents on one operation, and several operations against one
## nation at once. A team raises the odds and shortens the preparation, costs more, leaves more tracks,
## yields more, risks every agent in it, is recalled together, and survives a save.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	seed(4817)
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	w.start_match("easy")
	paused = true
	var e: Node = w.espionage
	var at = w.test_site("intelAgency", w.start)
	w.place_building("intelAgency", at, 0, true)
	w.economy.res.money = 500000.0
	for i in range(5): e.recruit()
	e.network[1] = 80.0
	e.intel[1] = 80.0
	e.heat[1] = 0.0
	check(e.agents.size() >= 5 and e.ready_agents().size() >= 5, "five agents are ready")

	# ---- the odds, cost, time and risk of a team
	e.network[1] = 5.0
	e.intel[1] = 80.0
	var base: float = e.success_chance("sabotage", 1)
	check(is_equal_approx(e.success_chance("sabotage", 1, 2), minf(base + 0.08, 0.95)) and e.success_chance("sabotage", 1, 4) >= e.success_chance("sabotage", 1, 3), "a team raises the odds (%d%%, %d%%, %d%%, %d%%)" % [roundi(base * 100), roundi(e.success_chance("sabotage", 1, 2) * 100), roundi(e.success_chance("sabotage", 1, 3) * 100), roundi(e.success_chance("sabotage", 1, 4) * 100)])
	var cost1: int = e.team_cost("sabotage", 1)
	e.network[1] = 80.0
	check(e.team_cost("sabotage", 3) == int(roundf(cost1 * 1.5)) and cost1 == int(e.ops().sabotage.cost), "each extra agent costs a quarter more (%d, %d)" % [cost1, e.team_cost("sabotage", 3)])
	check(e.team_duration("sabotage", 3) < e.team_duration("sabotage", 1) and e.team_duration("sabotage", 4) >= float(e.PROGRAMS.sabotage[0]) * 0.55, "and shortens the preparation, but not below 55%")
	check(e.exposure_chance("sabotage", 1, 3) > e.exposure_chance("sabotage", 1, 1) * 1.6, "and leaves more tracks (%.2f against %.2f)" % [e.exposure_chance("sabotage", 1, 3), e.exposure_chance("sabotage", 1, 1)])
	check(e.blocked_reason("sabotage", 1, "", -1, 9).contains("needs") or e.blocked_reason("sabotage", 1, "", -1, 9) == "", "(a team is limited to what is ready)")

	# ---- sending a team
	var funds: float = w.economy.res.money
	var said: String = e.run("sabotage", 1, "", -1, 0.0, 3)
	check(said.contains("authorized") and said.contains("team of 3"), "a team of three is authorized: %s" % said)
	var m: Dictionary = e.missions[0]
	check(m.agents.size() == 3 and m.team == 3, "three agents are on the mission")
	check(m.agents.all(func(id): return e._agent(id).status == "deployed"), "all three are deployed")
	check(is_equal_approx(w.economy.res.money, funds - float(e.team_cost("sabotage", 3))), "and the team's cost was paid (%d)" % int(funds - w.economy.res.money))
	check(is_equal_approx(float(m.ends) - float(m.started), e.team_duration("sabotage", 3)), "its preparation is shorter")
	check(e.ready_agents().size() == e.agents.size() - 3, "the others are left")

	# ---- several operations against one nation at once, but never the same twice
	check(e.blocked_reason("sabotage", 1).contains("already under way"), "the same operation cannot run twice against one nation")
	var second: String = e.run("reconDossier", 1, "", -1, 0.0)
	check(second.contains("authorized"), "another operation against the same nation may run beside it")
	var third: String = e.run("stealFunds", 1, "", -1, 0.0)
	check(third.contains("authorized") and e.missions.size() == 3, "and a third")
	var fourth: String = e.blocked_reason("cyberAttack", 1)
	check(fourth.begins_with("No ready agent") or fourth.contains("At most"), "then the limit or the lack of agents stops it: %s" % fourth)

	# ---- the result: everyone recovers and gains
	e.advance(float(m.ends) - e.clock + 0.5)
	check(m.agents.all(func(id): return e._agent(id).status == "recovering"), "the whole team recovers afterwards")
	check(m.agents.all(func(id): return e._agent(id).ops >= 1), "each agent counts the operation")
	check(e.reports.any(func(r): return str(r.text).contains("a team of 3")), "the report names the team")
	for mm in e.missions.duplicate():
		e.cancel_mission(int(mm.agent))
	e.advance(31.0)
	check(e.ready_agents().size() == e.agents.size(), "recalled agents are ready again")

	# ---- more yield from a team
	e.network[2] = 80.0
	e.heat[2] = 0.0
	e.intel[2] = 20.0
	e.run("buildNetwork", 2, "", -1, 0.0, 1)
	var before_a: float = e.intel[2]
	e.advance(60.0)
	var gain1: float = e.intel[2] - before_a
	e.advance(100.0)
	e.cooldowns[2] = {}
	e.intel[2] = 20.0
	e.run("buildNetwork", 2, "", -1, 0.0, 3)
	var before_b: float = e.intel[2]
	e.advance(60.0)
	var gain3: float = e.intel[2] - before_b
	check(gain3 > gain1 * 1.6, "a team of three gleans about twice as much (%.1f against %.1f)" % [gain3, gain1])

	# ---- failure risks the whole team and leaves more heat
	e.advance(200.0)
	for key in [2, 3]:
		e.cooldowns[key] = {}
		e.network[key] = 80.0
		e.intel[key] = 80.0
		e.heat[key] = 0.0
	seed(11)
	var r1: String = e.run("sabotage", 3, "", -1, 1.0, 1)
	check(r1.contains("authorized"), "the single run is authorized: %s" % r1)
	e.advance(float(e.missions[0].ends) - e.clock + 0.5)
	var heat_single: float = e.heat[3]
	e.advance(60.0)
	e.heat[3] = 0.0
	for a in e.agents:
		if a.status == "captured": a.status = "ready"
	var r4: String = e.run("sabotage", 2, "", -1, 1.0, 4)
	check(r4.contains("authorized"), "the team of four is authorized: %s (ready %d)" % [r4, e.ready_agents().size()])
	var team_ids: Array = e.missions[0].agents.duplicate()
	e.advance(float(e.missions[0].ends) - e.clock + 0.5)
	var heat_team: float = e.heat[2]
	check(heat_team > heat_single * 1.15, "a failed team leaves more heat behind (%.0f against %.0f)" % [heat_team, heat_single])
	var captured: int = team_ids.filter(func(id): return e._agent(id).status == "captured").size()
	var recovering: int = team_ids.filter(func(id): return e._agent(id).status == "recovering").size()
	check(captured + recovering == 4, "each of the four was either captured or got away (%d captured)" % captured)

	# ---- saves
	e.advance(300.0)
	for a in e.agents:
		a.status = "ready"
	e.cooldowns[2] = {}
	e.run("openSources", 2, "", -1, 0.0, 2)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(e.capture()))
	e.restore(saved)
	check(e.missions.size() == 1 and e.missions[0].agents.size() == 2 and e.missions[0].team == 2 and typeof(e.missions[0].agents[0]) == TYPE_INT, "a team mission survives a save")
	# An older save has one agent and no team field.
	var old_mission: Dictionary = {"op": "counterSweep", "nation": 3, "role": "", "agent": e.agents[4].id, "started": 0.0, "ends": 999999.0, "roll": 0.5}
	e.missions.append(old_mission)
	e.restore(JSON.parse_string(JSON.stringify(e.capture())))
	check(e.missions.any(func(mm): return mm.agents.size() == 1 and mm.team == 1), "an older save's mission becomes a team of one")
	print("ESPIONAGE_TEAMS %d passed, %d failed" % [passed, errors.size()])
	for er in errors: print("  FAILED: " + er)
	print("ESPIONAGE_TEAMS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
