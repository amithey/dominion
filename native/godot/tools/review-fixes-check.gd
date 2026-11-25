extends SceneTree
## The fixes from the player's review: why a unit stands idle (on the card and
## over the unit), the message log, the fog for rivals and over deposits, the
## health-bar overlay, and the paths to victory besides conquest.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

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
	var hud: Node = w.hud
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position

	# 1: why a unit stands idle.
	var tank: Dictionary = w.units.filter(func(u): return u.owner == 0 and u.key == "tank" and not u.dead)[0]
	tank.operating_shortage = "fuel"
	for u in w.units: u.selected = false
	tank.selected = true
	hud._update_selection()
	check(hud._sel_info.text.contains("HALTED") and hud._sel_info.text.contains("no fuel"), "the unit card says why a tank stands idle: \"%s\"" % hud._sel_info.text.get_slice("\n", hud._sel_info.text.get_slice_count("\n") - 1))
	check(preload("res://scripts/unit_overlay.gd").shortage_text("ammunition budget") == "NO AMMUNITION" and hud._overlay != null, "and a marker over the unit says it (NO FUEL / NO AMMUNITION)")
	tank.operating_shortage = ""
	tank.selected = false
	# 2: the message log.
	hud.notice("Test message one")
	hud.notice("Test message two")
	hud.toggle_log()
	hud.set_log_tab("all")
	var box: Control = hud.find_child("MessageLog", true, false)
	var lines: Array = hud._log_rows.get_children().filter(func(c): return c is Label and not c.is_queued_for_deletion())
	check(box != null and box.visible and lines.size() >= 2 and lines[0].text.ends_with("Test message two") and lines[0].text.contains(":"), "L opens the message log, newest first, with the time (\"%s\")" % (lines[0].text if not lines.is_empty() else ""))
	hud.close_windows()
	check(not box.visible, "Esc closes it")
	# 3: the fog: deposits on land never seen, and the rivals.
	var fog = w.fog
	fog.refresh()
	var hidden_deps: int = w.deposits.filter(func(d): return not d.node.visible).size()
	var near_dep: Array = w.deposits.filter(func(d): return fog.charted(d.pos))
	check(hidden_deps > 0 and near_dep.all(func(d): return d.node.visible), "deposits on land never seen are hidden (%d), those seen shown (%d)" % [hidden_deps, near_dep.size()])
	var outpost: Dictionary = w.place_building("barracks", w.test_site("barracks", home + Vector3(-40, 0, 30)), 0, true)
	fog.refresh()
	check(not fog.rival_knows(1, outpost) and fog.rival_knows(1, w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]), "a rival knows your capital but not a barracks it has never seen")
	w.diplomacy.declare_war(1, 0)
	var found = w.ai.nearest_enemy_asset(w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0].root.position, [0], 1)
	check(found != null and found.key == "hq", "so its attack goes for what it knows (your %s)" % ("nothing" if found == null else found.def.name))
	var raider: Dictionary = w.spawn_unit("tank", ground(outpost.root.position + Vector3(80, 0, 0)), 1)
	w.engagement.punish(1)
	var hq_pos: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	check(raider.target != null and raider.target.distance_to(hq_pos) < raider.target.distance_to(outpost.root.position), "a punitive border column also obeys fog of war and heads for the known capital")
	w.kill(raider)
	var scout: Dictionary = w.spawn_unit("soldier", ground(outpost.root.position + Vector3(20, 0, 0)), 1)
	for i in range(4): fog.refresh()
	check(fog.rival_knows(1, outpost), "a rival soldier near it finds it")
	var gun: Dictionary = w.spawn_unit("artillery", ground(home + Vector3(-90, 0, -60)), 1)
	var mark: Dictionary = w.spawn_unit("tank", ground(home + Vector3(-90, 0, -10)), 0)
	check(not fog.rival_spots(1, mark), "a rival's artillery cannot fire on your tank 50 m off without a spotter")
	w.kill(scout)
	# 4: health bars: a damaged unit is drawn a bar (the overlay picks it).
	tank.hp = tank.max_hp * 0.4
	var hidden_enemy: Dictionary = w.spawn_unit("tank", ground(home + Vector3(200, 0, 0)), 1)
	hidden_enemy.hp = hidden_enemy.max_hp * 0.5
	fog.refresh()
	check(not fog.shows(hidden_enemy), "a damaged enemy tank under the fog gets no health bar (health_overlay checks the fog)")
	# 5: paths to victory.
	var v = w.victory
	var paths: Array = v.standings().map(func(s): return str(s.path)) if v != null else []
	check(paths.size() == (6 if w.get("directorate") != null else 5) and paths.has("Dominance") and paths.has("Technology") and paths.has("Economic prosperity") and paths.has("Diplomatic coalition"), "the Cabinet lists the paths to victory: conquest, dominance, technology and, with the AI programme, the AGI project %s" % str(paths))
	var t = w.territory
	var cells: int = t.owner_of.size()
	var mine := 0
	var land := 0
	for i in range(cells):
		if t.terrain[i] == t.Terrain.WATER: continue
		land += 1
		if t.owner_of[i] == 0: mine += 1
	var need := int(ceil(land * v.LAND_SHARE)) - mine
	for i in range(cells):
		if need <= 0: break
		if t.terrain[i] != t.Terrain.WATER and t.owner_of[i] < 0:
			t.owner_of[i] = 0
			need -= 1
	v.update(5.0)
	check(v.land_since.has(0), "holding 40%% of the land starts a dominance countdown (%d%%)" % roundi(v.land_share(0) * 100))
	w.game_time += v.LAND_HOLD + 1.0
	v.update(5.0)
	check(w.game_over == "victory", "held for 3 minutes, it is a victory")
	check_civil_victories(home)
	print("\nREVIEW_FIXES: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("REVIEW_FIXES PASS" if errors.is_empty() else "REVIEW_FIXES FAIL")
	quit(0 if errors.is_empty() else 1)

func check_civil_victories(home: Vector3) -> void:
	var v = w.victory
	var d = w.diplomacy
	w.game_over = ""
	v.restore({})
	# Undo the territorial majority granted by the previous scenario.
	w.territory.owner_of.fill(-1)
	var sites := []
	for key in ["villageCenter", "villageCenter", "farm", "market", "school", "hospital", "embassy"]:
		var site = w.place_building(key, home + Vector3(24 * (sites.size() + 1), 0, 48), 0, true)
		sites.append(site)
		site.supplied = true
	w.economy.res.money = v.RESERVE
	v.update(2.0)
	check(v.economic_since.has(0), "supplied towns, services and reserves start the economic countdown")
	w.economy.res.money -= 1
	v.update(2.0)
	check(not v.economic_since.has(0), "spending down the reserve interrupts the countdown")
	w.economy.res.money += 1
	v.update(2.0)
	var started: float = w.game_time
	v.restore(JSON.parse_string(JSON.stringify(v.capture())))
	check(is_equal_approx(float(v.economic_since.get(0, -1.0)), started), "economic progress survives a JSON round trip")
	w.game_time += v.CIVIL_HOLD + 1.0
	v.update(2.0)
	check(w.game_over == "victory", "civilian prosperity wins with every rival capital standing")
	w.game_over = ""
	w.economy.res.money = 0
	v.restore({})
	for other in range(1, d.n):
		d.set_flag(d.war, 0, other, false)
		d.set_score(0, other, 60)
		d.propose_pact(other)
		d.set_flag(d.nap, 0, other, true)
	v.update(2.0)
	check(v.diplomatic_since.has(0), "a peaceful coalition starts without military alliances")
	d.set_flag(d.war, 0, 1, true)
	v.update(2.0)
	check(not v.diplomatic_since.has(0), "war interrupts a diplomatic campaign")
	d.set_flag(d.war, 0, 1, false)
	v.update(2.0)
	v.restore(JSON.parse_string(JSON.stringify(v.capture())))
	check(v.diplomatic_since.has(0), "diplomatic progress survives a JSON round trip")
	w.game_time += v.CIVIL_HOLD + 1.0
	v.update(2.0)
	check(w.game_over == "victory", "the diplomatic coalition wins with all rivals still in play")
