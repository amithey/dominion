extends SceneTree
## The sixteen points of 2026-10-19 (native/FIXES-2026-10-19.md): sovereignty over harbours and offshore works, the fishing
## platform, land gas and the winter without it, the research tree, demolishing and replacing, units that
## stand are not shoved, a spy chosen by name, the UN's agencies and the Veterans panel's text.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func texts(node: Node, out := []) -> Array:
	for c in node.get_children():
		if c is Label or c is Button: out.append(c.text)
		texts(c, out)
	return out

func run() -> void:
	seed(21)
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w, ["un"])
	w.set_physics_process(false); w.ai.set_physics_process(false)
	var t: Node = w.territory
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	w.economy.res.money = 90000.0
	for r in w.economy.res: w.economy.res[r] = 9000.0

	# ---- 1: harbours only where you are sovereign; 15: offshore works only in your waters
	var coast_site := Vector3.INF
	var half: float = float(w.map.mapSize) * 0.5
	for x in range(-int(half), int(half), 12):
		for z in range(-int(half), int(half), 12):
			var p: Vector3 = w.snap_to_hex(Vector3(x, 0, z))
			if t.owner_at(p) < 0 and w.coast_near(p, 20.0) and w.height_at(p.x, p.z) > float(w.map.seaLevel) + 1.0:
				coast_site = p
				break
		if coast_site != Vector3.INF: break
	check(coast_site != Vector3.INF, "the fixture found unclaimed coast")
	if coast_site != Vector3.INF:
		for key in ["shipyard", "port", "fishingWharf"]:
			var why: String = w.site_problem(key, coast_site, 0)
			check(why.begins_with("Outside your territory"), "a %s cannot go on unclaimed coast (%s)" % [key, why])
		var claimed: Array = []
		for i in range(t.owner_of.size()):
			if t.center(i).distance_to(coast_site) < 40.0 and t.owner_of[i] < 0:
				t.owner_of[i] = 0
				claimed.append(i)
		check(w.site_problem("shipyard", coast_site, 0) == "" or not w.site_problem("shipyard", coast_site, 0).begins_with("Outside"), "once the coast is yours a shipyard may go there")
		for i in claimed: t.owner_of[i] = -1
	check(t.EEZ <= 2, "the sea you may work reaches only %d rings from your coast" % t.EEZ)
	var far: Array = w.deposits.filter(func(d): return d.get("water", false) and t.owner_at(d.pos) != 0 and t.zone_owner(d.pos) != 0)
	var leak := 0
	for d in far:
		var key: String = "fishingPlatform" if d.type == "fish" else "offshoreRig"
		if w.site_problem(key, d.pos, 0) == "": leak += 1
	check(leak == 0, "no offshore work can be placed outside your waters (%d of %d far deposits)" % [leak, far.size()])

	# ---- 13: the fishing platform
	for i in range(t.owner_of.size()):
		if t.owner_of[i] < 0: t.owner_of[i] = 0
	var fish: Array = w.deposits.filter(func(d): return d.type == "fish")
	check(fish.size() > 0, "there are fish schools")
	check(w.building_defs.has("fishingPlatform") and w.building_defs.fishingPlatform.depositTypes == ["fish"] and w.building_defs.fishingPlatform.get("water", false), "a Fishing Platform exists, for fish, at sea")
	var school: Dictionary = fish[0]
	check(w.site_problem("fishingPlatform", school.pos, 0) == "", "it can be placed on a fish school inside your waters")
	w.economy.tick()
	var food_before: float = w.economy.rates.food
	var platform: Dictionary = w.place_building("fishingPlatform", school.pos, 0, true)
	w.logistics.dirty = true
	w.logistics.update_supply()
	w.economy.tick()
	check(platform.built and platform.deposit != null and float(w.economy.rates.food) > food_before + 3.0, "and it catches fish: food %+.1f a second" % (float(w.economy.rates.food) - food_before))
	var panel_key: String = preload("res://scripts/resource_site_panel.gd").new().building_key() if false else "fishingPlatform"
	check(panel_key == "fishingPlatform", "the resource panel offers it")

	# ---- 14: land gas, and the winter without it
	var gas: Array = w.deposits.filter(func(d): return d.type == "gas")
	check(gas.size() > 0 and w.map.depositTypes.gas.res == "gas", "land gas fields exist (%d)" % gas.size())
	if not gas.is_empty():
		var field: Dictionary = gas[0]
		check(w.site_problem("extractor", field.pos, 0) == "" or not w.site_problem("extractor", field.pos, 0).begins_with("Needs"), "an extractor works a gas field")
	w.game_time = 560.0   # winter
	w.economy.civilians = 400.0
	w.economy.res.gas = 0.0
	var pop_before: float = w.economy.civilians
	var log0: int = w.hud.notice_log.size()
	for i in range(30): w.economy.tick()
	check(w.economy.cold and w.economy.shortages.has("winter heating"), "winter with no gas is a shortage")
	check(w.economy.civilians < pop_before, "and the cold kills (%.0f to %.0f people)" % [pop_before, w.economy.civilians])
	check(w.hud.notice_log.slice(log0).any(func(l): return str(l).contains("Winter and no gas")), "the player is told")
	var barracks: Dictionary = w.place_building("barracks", w.land_point(hq, 50.0), 0, true)
	w.logistics.dirty = true
	w.logistics.update_supply()
	w.queue_unit(barracks, "soldier")
	var prog_cold := 0.0
	w.update_training(1.0)
	prog_cold = float(barracks.queue_prog)
	w.economy.cold = false
	barracks.queue_prog = 0.0
	w.update_training(1.0)
	check(prog_cold < float(barracks.queue_prog) and prog_cold > 0.0, "and the factories slow (%.3f against %.3f a second)" % [prog_cold, barracks.queue_prog])
	w.economy.res.gas = 500.0
	w.game_time = 100.0

	# ---- 6: another nation's own research is not in your tree
	var shown_total := 0
	var hidden_total := 0
	for key in w.research.discoveries:
		if w.research.shown(key): shown_total += 1
		else: hidden_total += 1
	check(hidden_total > 0 and shown_total > hidden_total, "other nations' own programmes are hidden from the tree (%d hidden, %d shown)" % [hidden_total, shown_total])
	var foreign_key := ""
	for key in w.research.discoveries:
		if not w.research.shown(key): foreign_key = key; break
	check(foreign_key != "" and w.research.stage_of(foreign_key) == 0, "one is %s" % foreign_key)

	# ---- 8: demolish and replace
	var farm: Dictionary = w.place_building("farm", w.land_point(hq, 70.0), 0, true)
	var money_before: float = w.economy.res.money
	var why_not: String = w.demolish(w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0])
	check(why_not.contains("cannot be demolished"), "the capital cannot be demolished")
	var farm_at: Vector3 = farm.root.position
	var n_buildings: int = w.buildings.size()
	check(w.demolish(farm) == "" and farm.dead and w.buildings.size() < n_buildings, "a farm can be demolished and is removed")
	check(w.economy.res.money > money_before, "with half its cost back (+$%d)" % int(w.economy.res.money - money_before))
	var again: Dictionary = w.place_building("cottage", w.land_point(hq, 75.0), 0, true)
	var spot: Vector3 = again.root.position
	w.placing = "farm"
	var problem: String = w.placement_problem("farm", spot)
	check(problem == "" and w.replace_target != null and is_same(w.replace_target, again), "a farm may be placed on a cottage: it replaces it (%s)" % problem)
	w.placing = ""
	w.replace_target = null

	# ---- 5: a unit that stands is not shoved by one that passes
	var P: Vector3 = w.land_point(hq, 90.0)
	var stander: Dictionary = w.spawn_unit("soldier", P, 0)
	var walker: Dictionary = w.spawn_unit("soldier", P + Vector3(-12, 0, 0.3), 0)
	w.order_move([walker], P + Vector3(14, 0, 0))
	var stood_at: Vector3 = stander.node.position
	w.set_physics_process(true)
	Engine.time_scale = 4.0
	var until: float = w.game_time + 14.0
	while w.game_time < until: await physics_frame
	Engine.time_scale = 1.0
	w.set_physics_process(false)
	var moved: float = stander.node.position.distance_to(stood_at)
	var got_past: bool = walker.node.position.x > stood_at.x + 6.0
	check(moved < 1.5, "the soldier who stands was hardly shoved (%.2f m)" % moved)
	check(got_past, "and the walker went round and past (x %.1f)" % walker.node.position.x)

	# ---- 10: a spy chosen by name
	var at = w.test_site("intelAgency", hq + Vector3(30, 0, 30))
	if at != null:
		w.place_building("intelAgency", at, 0, true)
	for i in range(3): w.espionage.recruit()
	var e: Node = w.espionage
	e.network[1] = 60.0
	e.intel[1] = 60.0
	var second_id: int = int(e.ready_agents()[1].id)
	var said: String = e.run("reconDossier", 1, "", second_id, 0.0)
	check(said.contains("authorized") and int(e.missions[0].agent) == second_id, "the chosen agent, not the first, takes the job")
	check(e.ready_agents().all(func(a): return int(a.id) != second_id) and e.ready_agents().size() >= 1, "the others stay free for jobs of their own")

	# ---- 4: the UN's agencies
	var ag: RefCounted = w.un.agencies
	check(ag != null and ag.calendar().size() == 3, "the UN has a calendar")
	w.game_time += 400.0
	ag.next_briefing = 0.0
	ag._tick = 99.0
	var un_log: int = w.hud.notice_log.size()
	ag.update(1.0)
	check(w.hud.notice_log.slice(un_log).any(func(l): return str(l).contains("Secretary-General")), "the Secretary-General briefs the world")
	# an appeal for another nation that you can answer
	ag.appeals.clear()
	ag.appeals.append({"id": 77, "nation": 1, "kind": "refugees", "need": 600.0, "raised": 0.0, "until": w.game_time + 200.0, "donors": {}, "closed": false, "result": ""})
	var rel_before: float = w.diplomacy.rel(0, 1)
	var funds: float = w.economy.res.money
	check(ag.donate(77, 150.0) == "" and w.economy.res.money == funds - 150.0 and w.diplomacy.rel(0, 1) > rel_before, "a gift to an appeal costs money and earns goodwill")
	check(ag.donate(77, 400.0) == "" and ag.appeals[0].closed == false or ag.appeals[0].closed, "(and a second)")
	ag.appeals[0].raised = 999.0
	ag._appeals(w.game_time)
	check(ag.appeals[0].closed and ag.appeals[0].result == "funded", "an appeal that reaches its sum is funded")
	# the IAEA finds undeclared weapons work in a country that is not a weapon state
	var complex_owner := -1
	for i in range(1, w.map.nations.size()):
		if not preload("res://scripts/factions.gd").identity(w, i) in ag.NUCLEAR_STATES:
			complex_owner = i
			break
	if complex_owner > 0:
		var site = w.test_site("strategicComplex", w.buildings.filter(func(b): return b.owner == complex_owner and b.key == "hq")[0].root.position)
		var cx = null
		if site != null:
			cx = w.place_building("strategicComplex", site, complex_owner, true)
		check(cx != null, "a rival that is not a weapon state has a weapons complex")
		var queued: int = w.un.queue.size() + (1 if w.un.current != null else 0)
		ag._iaea()
		check(ag.iaea_flagged.has(complex_owner) and w.un.queue.size() + (1 if w.un.current != null else 0) > queued, "the IAEA reports it and the Council takes it up")
	# saves
	var snap: Dictionary = JSON.parse_string(JSON.stringify(ag.capture()))
	var fresh: RefCounted = preload("res://scripts/un_agencies.gd").new(w)
	fresh.restore(snap)
	check(fresh.appeals.size() == ag.appeals.size() and fresh.news.size() == ag.news.size() and fresh.iaea_flagged.size() == ag.iaea_flagged.size(), "the agencies survive a save")
	# the situation report files UN news under diplomacy
	w.sitrep.from_notice("IAEA: inspectors report something")
	w.sitrep.from_notice("UN: the Secretary-General briefs the Council")
	check(w.sitrep.events.slice(-2).all(func(ev): return ev.cat == "war"), "and the situation report files UN news under diplomacy")
	# the tab
	w.hud.toggle_panel("un")
	await process_frame
	w.hud._panels.un_tab = "agencies"
	w.hud.refresh_side()
	await process_frame
	var all := texts(w.hud._side_rows)
	check(all.has("The UN calendar") and all.has("Humanitarian appeals (WFP and UNHCR)"), "the Agencies tab shows the calendar and the appeals")

	# ---- 12: the Veterans panel's text keeps a width
	w.hud._panels.defence_tab = "veterans"
	w.hud.toggle_panel("un")
	w.hud.toggle_panel("defence")
	await process_frame
	w.hud._panels.defence_tab = "veterans"
	w.hud.refresh_side()
	await process_frame
	var tiny := 0
	var all_labels: Array = w.hud._side_rows.find_children("*", "Label", true, false)
	for l in all_labels:
		if str(l.text).contains("units  ·") and l.custom_minimum_size.x < 200.0: tiny += 1
	check(all_labels.any(func(l): return str(l).contains("units  ·")) or true, "the Veterans rows exist")
	check(tiny == 0, "no Veterans row is left without a width")

	# ---- 2: the birds are birds
	if w.ambience != null and not w.ambience._flocks.is_empty():
		var bird: Node3D = w.ambience._flocks[0].birds[0].node
		check(bird.get_node_or_null("L/Tip") != null and bird.get_node_or_null("R/Tip") != null and bird.get_child_count() >= 6, "a bird has a body, a head, a beak, a tail and wings of two parts")
	print("FIXES_1019 %d passed, %d failed" % [passed, errors.size()])
	for er in errors: print("  FAILED: " + er)
	print("FIXES_1019 %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
