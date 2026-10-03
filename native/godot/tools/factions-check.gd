extends SceneTree
const Factions = preload("res://scripts/factions.gd")
const Setup = preload("res://scripts/match_setup.gd")
const Gallery = preload("res://scripts/leader_gallery.gd")
const Arsenal = preload("res://scripts/national_arsenal.gd")
const Modern = preload("res://scripts/modern_warfare.gd")
var errors: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors.append(label)
		push_error(label)
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	for i in range(Factions.IDS.size()):
		for count in [2, 3, 4]:
			var data := source.duplicate(true)
			Setup.apply(data, Setup.normalize({"nation": i, "players": count}))
			check(data.nations[0].id == Factions.IDS[i], "selected faction %d" % i)
			check(data.nations.size() == count and data.startPositions.size() == count, "active counts")
			var unique := {}
			for n in data.nations:
				unique[n.id] = true
			check(unique.size() == count, "no duplicate factions")
			for owner in range(count):
				check(data.buildings.filter(func(b): return int(b.owner) == owner and b.key == "hq").size() == 1, "one capital per nation")
			check(data.units.all(func(u): return int(u.owner) >= 0 and int(u.owner) < count), "valid army owners")
		check(ResourceLoader.exists(Gallery.portrait(Factions.LEADERS[i])), "portrait exists " + Factions.IDS[i])
		check(Gallery.face(Factions.LEADERS[i], 1.5) != null, "face crop loads")
	check(Gallery.portrait("Successor 1 (President)") == "", "successor does not inherit incumbent image")
	var selected := Setup.normalize({"nation": 0, "players": 4, "rivals": [4, 5, 8]})
	check(Setup.roster(selected) == [0, 4, 5, 8], "choose US versus Russia, India and Israel")
	check(Setup.roster(Setup.normalize({"nation": 0, "players": 4, "rivals": [0, Factions.IDS.size(), -1, 4, 4]})) == [0, 4, 1, 2], "invalid or duplicate rivals repaired")
	check(Setup.normalize(JSON.parse_string(JSON.stringify(selected))) == selected, "chosen rivals survive JSON save")
	set_meta("match_config", Setup.normalize({"map": "frontier", "nation": 8, "players": 4, "rivals": [4, 5, 7], "style": "sandbox"}))
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	check(w.map.nations[0].id == "israel", "Israel launches as player")
	check(w.units.all(func(u): return u.get("faction_equipped", false)), "starting garrisons receive doctrines")
	check(w.map.nations.map(func(n): return n.id) == ["israel", "russia", "india", "turkiye"], "four selected factions on a large map")
	check(w.map.mapCapacity == 6 and int(w.map.mapSize) == 1120, "factions integrate with expanded geography")
	var original_unit_count: int = w.units.size()
	var originals: Array = w.map.nations.duplicate(true)
	for i in range(Factions.IDS.size()):
		w.menu.setup_options.nation = i
		w.menu.open_new_game()
		await process_frame
		var picker: OptionButton = w.menu._panel.find_child("FactionPicker", true, false)
		check(picker.item_count == Factions.IDS.size() and picker.selected == i, "all selectable leaders")
		check(w.menu._briefing.text.contains(Factions.NAMES[i]), "leader summary " + Factions.IDS[i])
		w.map.nations[0] = Factions.nation(i, true)
		check(Arsenal.identity(w, 0) == Factions.ARSENALS[i], "arsenal identity " + Factions.IDS[i])
		for key in ["raptor", "df17", "irisT", "shahedLauncher"]:
			check(Arsenal.allowed(w, 0, key) == (str(w.unit_defs[key].nation) == Factions.ARSENALS[i]), "exclusive arsenal")
	w.menu.setup_options.nation = 0
	w.menu.open_new_game()
	await process_frame
	var rival_picker: OptionButton = w.menu._panel.find_child("RivalPicker1", true, false)
	var choice := rival_picker.get_item_index(4)
	rival_picker.select(choice)
	rival_picker.item_selected.emit(choice)
	await process_frame
	check(Setup.roster(w.menu.setup_options)[1] == 4, "rival picker selects Russia")
	var faction_picker: OptionButton = w.menu._panel.find_child("FactionPicker", true, false)
	faction_picker.select(4)
	faction_picker.item_selected.emit(4)
	await process_frame
	check(Setup.roster(w.menu.setup_options).count(4) == 1, "changing player faction removes duplicate rival")
	# Verify actual spawned units and research combat multiplier for player and AI.
	var cases := [[4, "artillery", 1.0, 1.2, 1.1, 0.85, 1.0], [5, "rocketSoldier", 1.15, 1.15, 1.0, 1.0, 1.0],
		[5, "jet", 0.9, 1.0, 1.0, 1.0, 1.0], [6, "gunboat", 1.0, 1.0, 1.15, 1.1, 1.0],
		[6, "tank", 0.9, 1.0, 1.0, 1.0, 1.0], [7, "drone", 0.85, 1.1, 1.0, 1.2, 1.0],
		[8, "samLauncher", 0.9, 1.0, 1.1, 1.0, 0.85], [8, "commando", 0.9, 1.15, 1.0, 1.0, 1.0]]
	for owner in [0, 1]:
		for c in cases:
			w.map.nations[owner] = Factions.nation(0, owner == 0)
			if owner == 0:
				w.research._recompute()
			var baseline: Dictionary = w.spawn_unit(c[1], w.start + Vector3(0, 0, 30), owner)
			w.map.nations[owner] = Factions.nation(c[0], owner == 0)
			if owner == 0:
				w.research._recompute()
			var u: Dictionary = w.spawn_unit(c[1], w.start + Vector3(12, 0, 30), owner)
			# National profiles stack with doctrines in 0.9.36. Check the
			# independently specified bonuses for both player and rival units.
			var profile_hp := 1.0
			if ResourceLoader.exists("res://scripts/national_profile.gd"):
				if c[0] == 4:
					profile_hp = 1.05
				elif c[0] == 5 and c[1] == "rocketSoldier":
					profile_hp = 1.10
			# Each nation's own system (unit_quality.gd, 0.9.54) on top: this nation's against the American baseline.
			var qn: Dictionary = preload("res://scripts/unit_quality.gd").of(Factions.IDS[c[0]], c[1])
			var qb: Dictionary = preload("res://scripts/unit_quality.gd").of("usa", c[1])
			check(is_equal_approx(u.max_hp / baseline.max_hp, c[2] * profile_hp * qn.hp / qb.hp), "health owner %d " % owner + str(c))
			check(is_equal_approx(w.research.damage_mult(u), c[3] * qn.damage), "damage " + str(c))
			check(is_equal_approx(u.range / baseline.range, c[4] * qn.range / qb.range), "range " + str(c))
			check(is_equal_approx(u.speed / baseline.speed, c[5] * qn.speed / qb.speed), "speed " + str(c))
			check(is_equal_approx(u.cooldown / baseline.cooldown, c[6]), "reload " + str(c))
			var hp: float = u.max_hp
			Factions.equip(w, u)
			check(is_equal_approx(hp, u.max_hp), "doctrine does not stack")
		w.map.nations[owner] = Factions.nation(8, owner == 0)
		check(is_equal_approx(Modern.intercept_chance(w, "abmLauncher", {"type": "ballistic", "owner": 1 - owner}, owner), 0.91), "Israel missile interception")
	w.map.nations = originals
	w.research._recompute()
	# Remove synthetic comparison units before validating a real saved campaign.
	for u in w.units.slice(original_unit_count):
		u.node.queue_free()
	w.units.resize(original_unit_count)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(Setup.normalize(saved.match_config).nation == 8, "save retains ninth faction")
	check(Setup.normalize(saved.match_config).rivals == [4, 5, 7], "save retains all chosen opponents")
	w.saves.restore(saved)
	check(w.map.nations[0].id == "israel" and w.espionage.person(0, "president") == Factions.LEADERS[8], "save restore retains leader")
	var previous := w.get_instance_id()
	set_meta("match_config", Setup.normalize(saved.match_config))
	set_meta("pending_load", saved)
	reload_current_scene()
	w = null
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != previous and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	check(w != null, "saved large-map campaign reloads into a fresh world")
	if w == null:
		quit(1)
		return
	check(w.map.nations.map(func(n): return n.id) == ["israel", "russia", "india", "turkiye"], "fresh load preserves every faction")
	check(w.map.style == "frontier" and w.espionage.person(2, "president") == Factions.LEADERS[5], "fresh load preserves map and rival leader")
	if DisplayServer.get_name() != "headless":
		w.menu.open_main()
		w.menu.setup_options.nation = 8
		w.menu.open_new_game()
		for i in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/faction-menu.png")
	print("FACTIONS_TEST PASS (%d checks)" % checks if errors.is_empty() else "FACTIONS_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
