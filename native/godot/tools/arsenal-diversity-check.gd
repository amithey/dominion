extends SceneTree
const Data := preload("res://scripts/arsenal_diversity_data.gd")
const F := preload("res://scripts/factions.gd")
const C := preload("res://scripts/force_catalog.gd")
var w: Node
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: failed += 1
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for frame in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu.close()
	for frame in range(4): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["fog", "un", "wmd"])
	var original: Dictionary = w.map.nations[0].duplicate(true)
	check(Data.PROFILES.size() == 28, "every playable identity has a dossier")
	for id: String in F.IDS:
		var dossier: Dictionary = Data.PROFILES.get(id, {})
		check(["land", "air", "sea", "fires", "support", "limits"].all(func(k): return str(dossier.get(k, "")).length() > 35), id + " six substantive research domains")
		check(not dossier.get("watch", []).is_empty() and not dossier.get("sources", []).is_empty(), id + " uncertainty and sources recorded")
		check(dossier.sources.all(func(s): return Data.SOURCES.has(s) and str(Data.SOURCES[s][1]).begins_with("https://")), id + " valid source references")
	var added := 0
	for key: String in Data.ROSTER:
		check(C.ROLES.has(key) and key in w.ai.train_pool and key in w.building_defs[C.HOME[key]].trains, key + " live AI and production registration")
		for id: String in Data.ROSTER[key]:
			added += 1
			w.map.nations[0] = F.nation(F.IDS.find(id), true)
			check(w.unit_allowed(0, key) and not Data.evidence(key, id).is_empty(), id + " / " + key + " positively attributed production")
	check(added == 20, "20 evidence-backed additional country / role choices")
	w.map.nations[0] = original
	w.economy.grant_test_resources()
	w.economy.pop_cap = 10000
	var at: Vector3 = w.start + Vector3(25, 0, 22)
	var barracks: Dictionary = w.place_building("barracks", at + Vector3(18, 0, 12), 0, true)
	w.queue_unit(barracks, "recoillessTeam")
	check(barracks.queue == ["recoillessTeam"], "support crew enters paid production without guided-missile research")
	w.update_training(100.0)
	check(w.units.any(func(u): return u.key == "recoillessTeam" and u.owner == 0), "support crew finishes training")
	var factory: Dictionary = w.place_building("tankFactory", at + Vector3(18, 0, -15), 0, true)
	w.queue_unit(factory, "shortRangeSAM")
	check(factory.queue.is_empty(), "local SAM cannot bypass guided research")
	w.research.progress.guidedMunitions = {"stage": 3, "work": 0, "paid": false}
	w.research.progress.advancedLogistics = {"stage": 3, "work": 0, "paid": false}
	w.research._recompute()
	w.queue_unit(factory, "shortRangeSAM")
	check(factory.queue == ["shortRangeSAM"], "local SAM enters actual queue after research")
	w.cancel_queued(factory, 0)
	w.queue_unit(factory, "wheeledHowitzer")
	check(factory.queue.is_empty(), "US production cannot acquire a foreign wheeled gun")
	w.map.nations[0] = F.nation(F.IDS.find("china"), true)
	w.queue_unit(factory, "wheeledHowitzer")
	check(factory.queue == ["wheeledHowitzer"], "Chinese PCL-181 enters actual factory queue")
	w.update_training(100.0)
	check(w.units.any(func(u): return u.key == "wheeledHowitzer"), "wheeled gun completes production")
	w.map.nations[0] = original
	var sam: Dictionary = w.spawn_unit("shortRangeSAM", at, 0)
	var crew: Dictionary = w.spawn_unit("recoillessTeam", at + Vector3(5, 0, 0), 0)
	var gun: Dictionary = w.spawn_unit("wheeledHowitzer", at + Vector3(10, 0, 0), 0)
	var light: Dictionary = w.spawn_unit("apc", at + Vector3(15, 0, 0), 1)
	var infantry: Dictionary = w.spawn_unit("soldier", at + Vector3(16, 0, 0), 1)
	var aircraft: Dictionary = w.spawn_unit("drone", at + Vector3(18, 0, 0), 1)
	check(sam.vehicle and gun.vehicle and not crew.vehicle and w.target_class(crew) == "infantry", "spawn uses vehicle models and exposed support crew classification")
	check(w.effectiveness(sam, aircraft) > 0 and w.effectiveness(sam, light) == 0 and not w.can_bombard(sam), "local air defence cannot attack ground or bombard")
	check(w.effectiveness(crew, light) > 1 and w.effectiveness(crew, aircraft) == 0, "unguided crew counters light vehicles, not aircraft")
	check(w.can_bombard(gun) and gun.range > w.fog.sight_of(gun) and gun.speed > C.ROLES.towedHowitzer.speed, "wheeled gun needs spotting and can relocate / bombard")
	w.diplomacy.declare_war(0, 1)
	w.fog.enabled = false
	w.rebuild_grid()
	check(w.fire(sam, aircraft) and not w.fire(sam, light), "real local SAM firing dispatch respects target restriction")
	check(w.fire(crew, light) and not w.fire(crew, aircraft), "real support crew projectile dispatch respects target restriction")
	var hp: float = infantry.hp
	check(w.fire(gun, infantry), "wheeled gun dispatches an indirect shell")
	for step in range(100): w.effects._physics_process(0.1)
	check(infantry.hp < hp, "new gun shell applies live damage")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(saved)
	check(Data.ROSTER.keys().all(func(key): return w.units.any(func(u): return u.key == key and not u.dead)), "JSON save / restore preserves all three new roles")
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "arsenal"
	for id: String in F.IDS:
		w.hud._panels.arsenal_country = id
		for domain: String in ["land", "air", "sea", "fires", "support", "limits"]:
			w.hud._panels.arsenal_domain = domain
			w.hud.refresh_side()
			check(w.hud._side_rows.find_child("ArsenalCountry", true, false) != null, id + " / " + domain + " dossier renders")
	# No years in the game's text: source titles are shown undated (the dates stay in the links and the doc).
	var year := RegEx.new()
	year.compile("\\b(?:19|20)\\d{2}\\b")
	for key in Data.SOURCES:
		var shown: String = preload("res://scripts/arsenal_diversity_panel.gd").undated(str(Data.SOURCES[key][0]))
		check(year.search(shown) == null and shown.length() > 8, "source shown without a year: " + shown)
	print("ARSENAL_DIVERSITY: %d passed, %d failed" % [passed, failed])
	print("ARSENAL_DIVERSITY PASS" if failed == 0 else "ARSENAL_DIVERSITY FAIL")
	quit(0 if failed == 0 else 1)
