extends SceneTree
## Rivals at sea (ai_navy.gd; native/AI-NAVY-2026-10-18.md). A real-map war across water, East Asia, Japan
## against China: the rival finds that its army cannot walk to its enemy, builds a shipyard (founding a town on the
## coast if it must), raises a fleet and landing ships, musters troops on the quay, sails them to a beach with
## escorts, lands them, and they attack; its warships sortie. Played at speed until all of it has happened (at most thirteen minutes).
var errors: Array[String] = []
var passed := 0
var w: Node
const N := preload("res://scripts/ai_navy.gd")
const Air := preload("res://scripts/airlift.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	seed(5)
	set_meta("match_config", {"map": "east_asia", "players": 2, "nation": 6, "rivals": [1]})
	change_scene_to_file("res://world.tscn")
	for i in range(60000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("hard"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w, ["costs"])
	check(preload("res://scripts/factions.gd").identity(w, 0) == "japan" and preload("res://scripts/factions.gd").identity(w, 1) == "china", "Japan against China")
	w.diplomacy.declare_war(0, 1, "test")
	var n: Dictionary = w.ai.nations[0]
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var seen := {"needs_sea": false, "yard": false, "landing_ship": false, "loaded": 0, "sortie": false, "ashore": 0, "escort": false, "wave_orders": false}
	Engine.time_scale = 8.0
	var t_end: float = w.game_time + 13.0 * 60.0
	var guard := 0
	while w.game_time < t_end and guard < 400000:
		await process_frame
		guard += 1
		n.money = maxf(float(n.money), 6000.0)
		if guard % 45 != 0:
			continue   # (looked at about every second and a half of play)
		var st: Dictionary = n.get("navy", {})
		if st.get("needs_sea", false): seen.needs_sea = true
		if not st.get("sortie", {}).is_empty(): seen.sortie = true
		if w.buildings.any(func(b): return b.owner == 1 and b.key == "shipyard" and not b.dead): seen.yard = true
		for s in N.transports(w, 1):
			seen.landing_ship = true
			seen.loaded = maxi(seen.loaded, Air.used(s))
			if s.get("op", {}).get("escorts", []).size() > 0: seen.escort = true
		var landed := 0
		for u in w.units:
			if u.owner == 1 and not u.dead and not u.get("naval", false) and not u.get("fly", false) and u.node.position.distance_to(hq0) < 220.0 and w.height_at(u.node.position.x, u.node.position.z) > float(w.map.seaLevel):
				landed += 1
		seen.ashore = maxi(seen.ashore, landed)
		if seen.ashore >= 3 and seen.sortie and seen.escort and seen.loaded >= N.MIN_TROOPS and N.warships(w, 1).size() >= 3:
			break   # everything has happened: no need to play on
	Engine.time_scale = 1.0
	w.set_physics_process(false)
	check(seen.needs_sea, "the rival finds that its army cannot walk to its enemy")
	check(seen.yard, "it builds a shipyard")
	check(seen.landing_ship, "and raises landing ships")
	check(seen.loaded >= N.MIN_TROOPS, "it loads troops aboard (%d at most)" % seen.loaded)
	check(seen.escort, "with warships to escort them")
	check(seen.ashore >= 3, "its troops are landed near your capital (%d at most)" % seen.ashore)
	check(seen.sortie, "its warships sortie against you")
	var fleet: Array = N.warships(w, 1)
	check(fleet.size() >= 3, "it keeps a fleet (%d warships)" % fleet.size())
	var land_army: int = w.units.filter(func(u): return u.owner == 1 and not u.dead and not u.get("naval", false) and not u.get("fly", false) and u.key != "worker").size()
	check(land_army <= int(w.ai.row(n).maxArmy) + 4, "ships do not count against its land army (%d land units)" % land_army)
	print("AI_NAVY %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("AI_NAVY %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
