extends SceneTree
## The era ladder (progression.gd): what opens when, for you and for rivals;
## the ladder never blocks the research or an era's own goals; a real climb
## from the Founding to the Regional era opens the tank factory; the Sandbox
## rules and older saves leave everything open.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light", "style": "standard", "progression": true})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.ai.set_physics_process(false)
	var L := preload("res://scripts/progression.gd")
	var r: Node = w.research
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position

	# ---- what the Founding era offers
	check(L.on(w) and r.era == 0, "a campaign under the Standard rules climbs the ladder from the Founding era")
	var open := []
	var shut := []
	for tab in w.hud.BUILD_MENU:
		for k in w.hud.BUILD_MENU[tab]:
			if w.building_defs.has(k): (open if L.building_blocked(w, 0, k) == "" else shut).append(k)
	check(open.size() <= 18 and shut.size() >= 20, "the Founding era opens a town's worth of buildings (%d open, %d to come)" % [open.size(), shut.size()])
	check("farm" in open and "barracks" in open and "school" in open and "villageCenter" in open and "offshoreRig" in open, "farms, barracks, a school, villages and offshore rigs from the start")
	check(not "nuclearReactor" in open and not "missileSilo" in open and not "airfield" in open and not "tankFactory" in open, "no reactor, silo, airfield or tank factory at minute one")
	check(L.building_blocked(w, 0, "tankFactory") == "Opens in the Regional Era", "the tank factory says when it opens")
	var site: Vector3 = w.test_site("barracks", hq0 + Vector3(-40, 0, -40))
	check(w.site_problem("tankFactory", site, 0) == "Opens in the Regional Era", "and cannot be placed before then, by any path")
	check(r.unit_locked("tank").begins_with("Opens in the Regional Era") and r.unit_locked("soldier") == "", "riflemen train at once; tanks wait for the Regional era")
	check(r.unit_locked("jet").begins_with("Opens in the Urban Era") and r.unit_locked("bomber").begins_with("Opens in the Industrial Era"), "fighters in the Urban era, bombers in the Industrial")
	w.hud.toggle_build()
	await process_frame
	await process_frame
	var rows: Array = w.hud.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and str(l.text).begins_with("Opens in the"))
	check(not rows.is_empty(), "the build list shows the closed buildings, with when they open")
	w.hud.toggle_build()

	# ---- the ladder never blocks the research or an era's goals
	var late := []
	for k in r.discoveries:
		var b = r.def_of(k).get("reqBuilding")
		if b != null and L.building_era(str(b)) > r.era_of(k):
			late.append("%s needs %s" % [k, b])
	check(late.is_empty(), "every building a discovery needs opens by that discovery's era %s" % str(late))
	check(L.building_era("villageCenter") < 1 and L.building_era("cityCenter") < 2 and L.building_era("chipFab") < 5, "each era's goals use buildings already open (village, city, Chip Fab)")
	var labs: Array = r.LABS.filter(func(k): return L.building_era(k) < 3)
	check(labs.size() >= 3, "three kinds of research building open before the Industrial era (%s)" % str(labs))
	check(L.building_era("market") < 4 and L.building_era("port") < 4, "markets and ports before the Global era's trade routes")

	# ---- a real climb: a village and eight buildings open the Regional era
	w.economy.grant_test_resources()
	var village = null
	for k in range(24):
		var p: Vector3 = w.test_site("villageCenter", hq0 + Vector3(cos(k * 0.5) * 120.0, 0, sin(k * 0.5) * 120.0))
		if p != null and w.site_problem("villageCenter", p, 0) == "":
			village = w.place_building("villageCenter", p, 0, true)
			break
	for k in ["farm", "cottage", "housing", "school", "market", "warehouse"]:
		var p = w.test_site(k, hq0 + Vector3(randf_range(-50, 50), 0, randf_range(-50, 50)))
		if p != null: w.place_building(k, p, 0, true)
	var log0: int = w.hud.notice_log.size()
	r._check_era()
	check(village != null and r.era == 1, "a village and eight buildings: the Regional era")
	var news := "\n".join(PackedStringArray(w.hud.notice_log.slice(log0)))
	check(news.contains("NOW OPEN") and news.contains("Tank Factory"), "the new era names what it opens: %s" % news.get_slice("NOW OPEN", 1).left(90))
	check(L.building_blocked(w, 0, "tankFactory") == "" and r.unit_locked("tank") == "", "the tank factory and tanks are open now")
	check(L.building_blocked(w, 0, "airfield") == "" and r.unit_locked("jet").begins_with("Opens in the Urban"), "the airfield opens, fighters still wait")

	# ---- rivals climb the same ladder
	var n1: Dictionary = w.ai.nations[0]
	n1.tech = 0.0
	var picks := {}
	for i in range(60): picks[w.ai.pick_building(n1)] = true
	check(picks.keys().all(func(k): return L.building_blocked(w, n1.id, k) == ""), "a rival at the start builds only what its era allows (%s)" % ", ".join(PackedStringArray(picks.keys())))
	check(L.unit_blocked(w, n1.id, "tank") != "" and L.unit_blocked(w, n1.id, "soldier") == "", "and trains riflemen, not tanks")
	n1.tech = 2.0
	check(L.unit_blocked(w, n1.id, "tank") == "", "technology 2: the rival reaches the Regional era")
	n1.tech = 8.0
	check(L.building_blocked(w, n1.id, "nuclearReactor") == "", "technology 8: the Global era and its reactor")

	# ---- the Sandbox rules, tests and old saves
	check(L.wanted({"style": "standard"}) and not L.wanted({"style": "sandbox"}), "the Standard rules climb the ladder; the Sandbox rules open everything")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(bool(saved.match_config.get("progression", false)), "a save keeps the ladder")
	w.match_config.erase("progression")
	check(L.building_blocked(w, 0, "nuclearReactor") == "" and r.unit_locked("bomber") != "Opens in the Industrial Era", "without it (an older save, a test) everything is open as before")

	print("PROGRESSION %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("PROGRESSION %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
