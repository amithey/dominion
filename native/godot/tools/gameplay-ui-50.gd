extends SceneTree
## Fifty gameplay checks on playing the game rather than on its rules: laying
## out buildings through the placement ghost, selecting and the command bar,
## the side panels, notices, pause, the road tool, workers and their build
## queues, and moving groups of units.
var errors: Array[String] = []
var passed := 0
var w: Node
var eco: Node
var hud: Node
const DT := 1.0 / 20.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func sim(seconds: float, done := Callable()) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT
		if done.is_valid() and done.call():
			break

func dry(at: Vector3) -> Vector3:
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 22.0, 30.0]:
		for i in range(12 if r > 0.0 else 1):
			var a := i * TAU / 12.0
			var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
				p.y = w.height_at(p.x, p.z)
				return p
	return w.land_point(at, 20.0)

func home() -> Vector2i:
	return w.logistics.world_hex(w.start)

func hq() -> Dictionary:
	return w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq" and not b.dead)[0]

func grant_land(rings: int) -> void:
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home() + Vector2i(q, r)
			if w.logistics.hex_distance(home(), h) > rings: continue
			var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
			if i >= 0 and w.territory.owner_of[i] < 0:
				w.territory.owner_of[i] = 0
				w.territory.control[i] = 80.0
				w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(hq())}

func site_for(key: String) -> Variant:
	for ring in range(1, 10):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "" and w.SiteClearing.conflicts(w, key, at).trees.is_empty() and w.SiteClearing.conflicts(w, key, at).deposits.is_empty():
					return at
	return null

func notices() -> int:
	return hud._notices.get_child_count()

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260930)
	w.start_match("easy")
	w.menu.close()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.ai.set_physics_process(false)
	eco = w.economy
	hud = w.hud
	eco.grant_test_resources()
	grant_land(6)

	# ================================================================ laying out a building
	w.begin_placement("farm")
	check(w.placing == "farm" and w.ghost != null, "choosing a farm shows its ghost on the map")
	var count0: int = w.buildings.size()
	var n0: int = notices()
	var sea = w.water_near(w.start, 220)
	w.ghost.position = sea
	w.confirm_placement(false)
	check(w.buildings.size() == count0 and notices() > n0, "a click on the sea is refused, with the reason shown")
	check(w.placing == "farm", "and the ghost stays for another try")
	var at = site_for("farm")
	var money0: float = eco.res.money
	w.ghost.position = at
	w.confirm_placement(true)
	var site: Dictionary = w.buildings[-1]
	check(w.buildings.size() == count0 + 1 and site.key == "farm" and not site.built, "a click on good ground lays out the farm")
	check(eco.res.money < money0, "and pays for it")
	check(w.placing == "farm", "holding Shift keeps placing more")
	check(w.units.any(func(u): return u.owner == 0 and not u.dead and u.key == "worker" and is_same(u.build_site, site)), "a worker is sent to the new site")
	w.cancel_placement()
	check(w.placing == "" and w.ghost == null, "cancelling clears the ghost")
	var rich: float = eco.res.money
	eco.res.money = 0.0
	n0 = notices()
	w.begin_placement("barracks")
	check(w.placing == "" and notices() > n0, "without the money, placement does not start and says why")
	eco.res.money = rich

	# ================================================================ selection and the command bar
	var barracks: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead and b.built)
	var bar: Dictionary = barracks[0] if not barracks.is_empty() else w.place_building("barracks", site_for("barracks"), 0, true)
	w.select_building(bar)
	check(is_same(w.selected_building, bar) and w.selection_marker.visible, "clicking a barracks selects it and rings it")
	hud._update_panel()
	var names: Array = []
	for n in hud._list.find_children("*", "Label", true, false): names.append(n.text)
	check(names.any(func(t): return str(t).contains("Soldier")), "its panel offers soldiers to train")
	check(not names.any(func(t): return str(t).contains(w.unit_defs.tank.name)), "and not tanks")
	var factory: Dictionary = w.place_building("tankFactory", site_for("tankFactory"), 0, true)
	w.select_building(factory)
	hud._update_panel()
	names.clear()
	for n in hud._list.find_children("*", "Label", true, false): names.append(n.text)
	check(names.any(func(t): return str(t).contains(w.unit_defs.tank.name)), "a tank factory offers tanks (%s)" % w.unit_defs.tank.name)
	check(not names.any(func(t): return str(t).contains("DF-17") or str(t).contains("IRIS-T") or str(t).contains("Shahed Launcher")), "and never another nation's own weapon")
	w.select_building(null)
	check(w.selected_building == null and not w.selection_marker.visible, "clicking empty ground clears the selection")
	var hall: Dictionary = hq()
	w.select_building(hall)
	hud._update_selection()
	check(hud._commands["Buy land"].visible, "a selected town hall offers to buy land")
	w.select_building(bar)
	hud._update_selection()
	check(not hud._commands["Buy land"].visible, "a barracks does not")
	w.select_building(null)
	for u in w.units: u.selected = false
	var workers: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == "worker")
	for u in workers: u.selected = true
	hud._update_selection()
	check(hud._commands["Attack-move"].disabled, "workers alone cannot attack-move")
	for u in workers: u.selected = false
	var tank: Dictionary = w.spawn_unit("tank", dry(w.start + Vector3(30, 0, 30)), 0)
	tank.selected = true
	hud._update_selection()
	check(not hud._commands["Attack-move"].disabled and not hud._commands["Bombard"].disabled, "a tank can attack-move and bombard")
	check(hud._commands["Repair"].disabled, "an unhurt tank needs no repair")
	tank.hp = tank.max_hp * 0.5
	hud._update_selection()
	check(not hud._commands["Repair"].disabled, "a damaged one does")
	tank.selected = false
	var sam: Dictionary = w.spawn_unit("samLauncher", dry(w.start + Vector3(40, 0, 30)), 0)
	sam.selected = true
	hud._update_selection()
	check(hud._commands["Bombard"].disabled, "a SAM launcher cannot bombard the ground")
	sam.selected = false
	w.kill(sam)
	hud._update_selection()

	# A rival's barracks: nothing to order there.
	var theirs: Array = w.buildings.filter(func(b): return b.owner == 1 and not b.dead and b.built and not b.def.get("trains", []).is_empty())
	if not theirs.is_empty():
		var enemy_b: Dictionary = theirs[0]
		w.select_building(enemy_b)
		hud._update_panel()
		await process_frame   # the previous card's rows are freed at the end of the frame
		var trains: Array = []
		for n in hud._list.find_children("*", "Button", true, false):
			if n.has_meta("cost") and n.is_visible_in_tree(): trains.append(n)
		check(trains.is_empty(), "a rival's %s offers you nothing to train" % enemy_b.def.name)
		var q_before: int = enemy_b.queue.size()
		var cash_b: float = eco.res.money
		w.queue_unit(enemy_b, enemy_b.def.trains[0])
		check(enemy_b.queue.size() == q_before and eco.res.money == cash_b, "and no order can be slipped into its queue")
		w.select_building(null)

	# ================================================================ panels and notices
	for mode in ["market", "intel", "territory"]:
		hud.toggle_panel(mode, true)
		check(hud.side_mode == mode and hud._side_rows.get_child_count() > 1, "the %s panel opens with its contents" % mode)
	hud.toggle_panel("territory")
	check(hud.side_mode == "", "pressing its key again closes it")
	hud.toggle_diplomacy()
	check(hud.side_mode == "diplomacy" or hud.get("diplomacy_open") == true or hud._win.visible, "the diplomacy screen opens")
	hud.toggle_panel("", false)
	n0 = notices()
	hud.notice("Test notice")
	check(notices() == mini(n0 + 1, 3), "a notice appears (the feed shows three at most)")
	var last: Control = hud._notices.get_child(hud._notices.get_child_count() - 1)
	check(last.find_children("*", "Label", true, false)[0].text == "Test notice", "with its text")
	for i in range(30): hud.notice("flood %d" % i)
	await process_frame
	check(hud._notices.get_child_count() <= 12, "a flood of notices does not pile up without end (%d shown)" % hud._notices.get_child_count())

	hud.toggle_research()
	await process_frame
	check(hud.find_children("*", "", true, false).any(func(n): return n.get_script() == preload("res://scripts/research_tree.gd") and n.is_visible_in_tree()), "the research tree opens")
	hud.toggle_research()

	# ================================================================ pause
	w.menu.open_pause()
	check(paused, "the pause menu stops the game")
	w.menu.close()
	check(not paused, "closing it resumes")

	# ================================================================ the road tool
	w.begin_transport("road")
	check(w.transport_kind == "road", "the road tool starts")
	w.cancel_transport()
	check(w.transport_kind == "" and w.transport_start == null, "and cancels cleanly")

	# ================================================================ workers
	for u in w.units.filter(func(x): return x.owner == 0 and x.key == "worker"): w.kill(u)
	var builder: Dictionary = w.spawn_unit("worker", dry(hall.root.position + Vector3(14, 0, 0)), 0)
	var s1_at = site_for("cottage")
	w.build_site("cottage", s1_at)
	var s1: Dictionary = w.buildings[-1]
	var s2_at = site_for("cottage")
	w.build_site("cottage", s2_at)
	var s2: Dictionary = w.buildings[-1]
	builder.build_site = null
	w.order_build([builder], s1)
	w.order_build([builder], s2, true)
	sim(150.0, func(): return s1.built and s2.built)
	check(s1.built, "a worker builds the first site in its queue")
	check(s2.built, "then walks on to the next")
	var leftover: Array = w.buildings.filter(func(b): return b.owner == 0 and not b.dead and not b.built)
	check(builder.build_site == null or (not builder.build_site.built and builder.build_site in leftover), "and then goes on to any unfinished site, or stands idle")
	sim(120.0, func(): return w.buildings.all(func(b): return b.owner != 0 or b.dead or b.built))
	check(site.built, "an idle worker finishes the site left over from earlier on its own")
	var s3_at = site_for("cottage")
	w.build_site("cottage", s3_at)
	var s3: Dictionary = w.buildings[-1]
	w.order_build([builder], s3)
	sim(4.0)
	w.destroy_building(s3)
	check(builder.build_site == null, "a site destroyed under construction frees its worker")
	var far_at = site_for("warehouse")
	w.build_site("warehouse", far_at)
	var s4: Dictionary = w.buildings[-1]
	w.order_build([builder], s4)
	sim(120.0, func(): return s4.built)
	check(s4.built, "a worker crosses the town to build")

	# ================================================================ moving groups
	var field: Vector3 = dry(w.start + Vector3(-60, 0, 90))
	var squad := []
	for i in range(12):
		squad.append(w.spawn_unit("soldier", dry(field + Vector3((i % 4) * 2.0, 0, (i / 4) * 2.0)), 0))
	var goal: Vector3 = dry(field + Vector3(45, 0, 20))
	w.order_move(squad, goal)
	sim(35.0, func(): return squad.all(func(u): return u.target == null))
	var arrived: int = squad.filter(func(u): return Vector2(u.node.position.x - goal.x, u.node.position.z - goal.z).length() < 14.0).size()
	check(arrived == squad.size(), "a squad of twelve arrives where it is sent (%d of 12)" % arrived)
	var tight := INF
	for a in squad:
		for b in squad:
			if not is_same(a, b): tight = minf(tight, Vector2(a.node.position.x - b.node.position.x, a.node.position.z - b.node.position.z).length())
	check(tight > 0.5, "without standing on each other (closest pair %.1f m)" % tight)
	check(squad.all(func(u): return w.height_at(u.node.position.x, u.node.position.z) > float(w.map.seaLevel)), "and nobody walks into the sea")
	var armour := []
	for i in range(4):
		armour.append(w.spawn_unit("tank", dry(field + Vector3(i * 8.0, 0, -20)), 0))
	var goal2: Vector3 = dry(field + Vector3(30, 0, -50))
	w.order_move(armour, goal2)
	sim(40.0, func(): return armour.all(func(u): return u.target == null))
	var gap := INF
	for a in armour:
		for b in armour:
			if not is_same(a, b): gap = minf(gap, Vector2(a.node.position.x - b.node.position.x, a.node.position.z - b.node.position.z).length())
	check(armour.all(func(u): return Vector2(u.node.position.x - goal2.x, u.node.position.z - goal2.z).length() < 20.0), "four tanks arrive together")
	check(gap > 2.5, "and park apart (closest %.1f m)" % gap)
	w.diplomacy.declare_war(0, 1)
	var lone: Dictionary = w.spawn_unit("soldier", dry(goal + Vector3(25, 0, 0)), 1)
	lone.dmg = 0.0
	w.order_move(squad, lone.node.position, true)
	sim(20.0, func(): return lone.dead)
	check(lone.dead, "on attack-move the squad takes out an enemy in its path")
	for u in squad + armour: if not u.dead: w.kill(u)

	# ================================================================ the end
	w.destroy_building(hq())
	await process_frame
	check(w.game_over == "defeat", "losing the capital ends the match")
	check(hud.find_children("*", "Label", true, false).any(func(l): return l.is_visible_in_tree() and str(l.text) == "DEFEAT"), "and the defeat screen shows")

	print("\nGAMEPLAY_UI: %d passed, %d failed" % [passed, errors.size()])
	for fl in errors: print("  FAILED: " + fl)
	print("GAMEPLAY_UI PASS" if errors.is_empty() else "GAMEPLAY_UI FAIL")
	quit(0 if errors.is_empty() else 1)
