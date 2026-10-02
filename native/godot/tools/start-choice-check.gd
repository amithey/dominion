extends SceneTree
## Choosing where each nation starts (match_setup.gd "starts", the Start
## pickers on the New Game screen): every map lists its regions; a nation
## given a region starts there, on every kind of map; the others never land
## on it; nonsense choices fall away; no choice leaves the map as it was; the
## screen's pickers swap a taken region, and a new map clears the choices;
## a match started and saved keeps them.
var errors: Array[String] = []
var passed := 0
const Setup := preload("res://scripts/match_setup.gd")
const Gen := preload("res://scripts/map_generator.gd")
const Catalogue := preload("res://scripts/map_catalogue.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

var source: Dictionary
func built(options: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	Setup.apply(data, Setup.normalize(options))
	return data

func capitals(data: Dictionary) -> Dictionary:
	var out := {}
	for b in data.buildings:
		if b.key == "hq": out[int(b.owner)] = Vector2(float(b.x), float(b.z))
	return out

## Region k of map `key` in metres.
func region(key: String, k: int, size: float) -> Vector2:
	return Setup.start_slots(key)[k].at * size * 0.5

func run() -> void:
	source = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	# 1-2: every map lists its regions, named.
	var counts := []
	for key in Catalogue.KEYS:
		var slots: Array = Setup.start_slots(key)
		if slots.size() != Setup.region_count(key) or slots.size() < Setup.capacity(key) or slots.any(func(s): return str(s.name) == "" or absf(s.at.x) > 1.0 or absf(s.at.y) > 1.0):
			counts.append(key)
	check(counts.is_empty(), "every map lists its regions, named and on the map (%d maps)%s" % [Catalogue.KEYS.size(), "" if counts.is_empty() else ": " + str(counts)])
	var me: Array = Setup.start_slots("middle_east").map(func(s): return s.name)
	var isle: Array = Setup.start_slots("island").map(func(s): return s.name)
	var mirror: Array = Setup.start_slots("mirrored").map(func(s): return s.name)
	check(me[1] == "Jerusalem" and me[5] == "Riyadh" and isle[0] == "North-east" and mirror[0] == "North-west" and Setup.start_slots("pangaea").any(func(s): return s.name == "South"), "regions are named by city on the real maps, by their quarter elsewhere (%s; %s)" % [", ".join(PackedStringArray(me.slice(0, 3))), ", ".join(PackedStringArray(isle))])
	# 3: nonsense falls away.
	var n: Dictionary = Setup.normalize({"map": "crown", "players": 4, "starts": [3, 3, 99, "x", 5, 6]})
	check(n.starts == [3, -1, -1, -1], "a region chosen twice, out of range or not a number is left to the map (%s)" % str(n.starts))
	n = Setup.normalize({"map": "island", "players": 4, "starts": [2, 0, 3, 1]})
	check(n.starts == [-1, -1, 3, 1], "on the original island your town is fixed and no rival takes it (%s)" % str(n.starts))
	check(not Setup.normalize({"map": "crown", "starts": [-1, -1]}).has("starts") and not Setup.normalize({"map": "crown", "starts": "north"}).has("starts"), "no real choice: no starts kept")
	# 6-: a nation given a region starts there.
	var cases := [
		["crown", 6, [5, 0, -1, 2, -1, -1]], ["pangaea", 9, [-1, 9, 4, -1, -1, -1, -1, -1, 0]],
		["continents_plus", 8, [4, -1, -1, 0, -1, -1, -1, -1]], ["fractal", 4, [-1, -1, 5, -1]],
		["small", 4, [3, -1, 0, -1]], ["twin", 2, [-1, 2]],
		["middle_east", 8, [3, -1, -1, -1, -1, -1, -1, 5]], ["europe", 5, [-1, 0, -1, 8, -1]], ["east_asia", 9, [6, 2, -1, -1, -1, -1, -1, -1, -1]],
	]
	for c in cases:
		var key: String = c[0]
		var data: Dictionary = built({"map": key, "players": c[1], "nation": 2, "starts": c[2]})
		var hq := capitals(data)
		var size: float = float(data.mapSize)
		var at_choice := true
		var taken := {}
		for i in range(c[2].size()):
			if c[2][i] >= 0:
				taken[c[2][i]] = true
				if not hq.has(i) or hq[i].distance_to(region(key, c[2][i], size)) > 2.0: at_choice = false
		var clash := false
		for i in hq:
			if i < c[2].size() and c[2][i] >= 0: continue
			for k in taken:
				if hq[i].distance_to(region(key, k, size)) < 2.0: clash = true
		var apart := true
		for i in hq:
			for j in hq:
				if i < j and hq[i].distance_to(hq[j]) < 50.0: apart = false
		check(at_choice and not clash and apart and hq.size() == c[1], "%s: the chosen nations start at their regions, the others elsewhere (%s)" % [Gen.MAPS[key].name, str(c[2])])
	# The real maps: give Moscow to another, and Russia goes to an open city.
	var moscow: Dictionary = built({"map": "middle_east", "players": 8, "nation": 8, "rivals": [4, 0, 1, 2, 3, 5, 6], "starts": [3]})
	var russia := -1
	for i in range(moscow.nations.size()):
		if str(moscow.nations[i].get("id", "")) == "russia": russia = i
	var hq_m := capitals(moscow)
	check(hq_m[0].distance_to(region("middle_east", 3, float(moscow.mapSize))) < 2.0 and russia > 0 and hq_m[russia].distance_to(region("middle_east", 3, float(moscow.mapSize))) > 100.0, "Middle East: Israel set at Moscow, and Russia starts elsewhere")
	# The island: rivals take the chosen start, its town with them.
	var island: Dictionary = built({"map": "island", "players": 4, "nation": 0, "starts": [-1, 3, 1, 2]})
	var hq_i := capitals(island)
	check(hq_i[1].distance_to(Vector2(-155.88, -162)) < 2.0 and hq_i[2].distance_to(Vector2(155.88, 162)) < 2.0 and hq_i[3].distance_to(Vector2(-155.88, 162)) < 2.0 and hq_i[0].distance_to(Vector2(155.88, -162)) < 2.0, "the original island: rivals at the starts chosen, you in your town")
	var mirrored: Dictionary = built({"map": "mirrored", "players": 2, "nation": 0, "starts": [-1, 1]})
	check(capitals(mirrored)[1].distance_to(Vector2(-155.88, 162)) < 2.0, "the mirrored island: a rival at the start chosen, mirrored")
	# No choice: the map as before.
	for key in ["crown", "middle_east", "island"]:
		var a: Dictionary = built({"map": key, "players": 4, "nation": 3})
		var b: Dictionary = built({"map": key, "players": 4, "nation": 3, "starts": [-1, -1, -1, -1]})
		check(JSON.stringify(a.buildings) == JSON.stringify(b.buildings) and not a.has("startSlots"), "%s: leaving every start to the map changes nothing" % key)
	# The New Game screen and a match.
	set_meta("match_config", {"map": "crown", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	var w: Node = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.menu.open_new_game()
	await process_frame
	var root: Node = w.menu._root
	var pickers: Array = range(4).map(func(i): return root.find_child("StartPicker%d" % i, true, false))
	var marks: Node = root.find_child("MapPreview", true, false)
	check(pickers.all(func(p): return p != null and p.item_count == 9) and marks != null and marks.get_child_count() == 8, "the New Game screen: a Start picker for you and each rival (Auto and 8 regions), and 8 numbers on the map")
	# Rival 1 to region 3, then you to region 3: rival 1 swaps to yours (Auto).
	var p1: OptionButton = pickers[1]
	p1.select(3)
	p1.item_selected.emit(3)
	await process_frame
	var p0: OptionButton = root.find_child("StartPicker0", true, false)
	p0.select(3)
	p0.item_selected.emit(3)
	await process_frame
	check(Setup.starts_of(w.menu.setup_options) == [2, -1, -1, -1], "choosing a region a rival holds swaps the two (%s)" % str(Setup.starts_of(w.menu.setup_options)))
	var mark3: Label = root.find_child("Region3", true, false)
	check(mark3 != null and mark3.get_theme_color("font_color") == Color(Setup.COLOURS[0]), "the region you chose shows in your colour on the map")
	var p2: OptionButton = root.find_child("StartPicker2", true, false)
	p2.select(8)
	p2.item_selected.emit(8)
	await process_frame
	var options: Dictionary = w.menu.setup_options.duplicate()
	var map_picker: OptionButton = root.find_child("MapPicker", true, false)
	var other := Catalogue.KEYS.find("great_lakes")
	map_picker.select(other)
	map_picker.item_selected.emit(other)
	await process_frame
	check(not w.menu.setup_options.has("starts"), "another map clears the chosen regions")
	# Begin with the choices: the match keeps them, and so does a save.
	set_meta("match_config", options)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	for i in range(5): await physics_frame
	var size: float = float(w.map.mapSize)
	var hq0 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var hq2 = w.buildings.filter(func(b): return b.owner == 2 and b.key == "hq")[0]
	check(Vector2(hq0.root.position.x, hq0.root.position.z).distance_to(region("crown", 2, size)) < 3.0 and Vector2(hq2.root.position.x, hq2.root.position.z).distance_to(region("crown", 7, size)) < 3.0, "a match begun with the choices starts you in region 3 and rival 2 in region 8")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(Setup.normalize(saved.match_config).get("starts", []) == [2, -1, 7, -1], "a save keeps the chosen regions (%s)" % str(saved.match_config.get("starts")))
	print("\nSTART_CHOICE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("START_CHOICE PASS" if errors.is_empty() else "START_CHOICE FAIL")
	quit(0 if errors.is_empty() else 1)
