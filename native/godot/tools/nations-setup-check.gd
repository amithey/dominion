extends SceneTree
## Matches of two to nine nations, each rival of its own difficulty
## (match_setup.gd, ai.gd, the New Game picker in menu.gd):
##  - the options: rivals as many as the map has regions, each rival's level;
##  - every nation starts with a capital, a town and an army of its own, on
##    land (its warships at sea), far from the others, with land to its name;
##  - each rival plays at the difficulty chosen for it, and a hard rival
##    outgrows an easy one; the choice survives a save;
##  - the picker offers the rivals and a difficulty for each.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Setup := preload("res://scripts/match_setup.gd")
const Factions := preload("res://scripts/factions.gd")
const MATCHES := [
	{"map": "pangaea", "players": 9, "nation": 0, "rivals": [8, 4], "levels": ["hard", "easy", "normal"], "difficulty": "normal"},
	{"map": "ten_isles", "players": 9, "nation": 5, "levels": ["easy", "hard"], "difficulty": "easy"},
	{"map": "great_lakes", "players": 7, "nation": 2, "levels": ["hard", "easy"], "difficulty": "normal"},
	{"map": "highlands", "players": 5, "nation": 7, "levels": ["hard", "easy"], "difficulty": "easy"},
	{"map": "crown", "players": 8, "nation": 1, "levels": ["hard", "easy"], "difficulty": "normal"},
	{"map": "small", "players": 2, "nation": 3, "levels": ["hard"], "difficulty": "easy"},
	{"map": "island", "players": 3, "nation": 6, "levels": ["hard", "easy"], "difficulty": "normal"},
]
var only: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func sim(seconds: float) -> void:
	var t := 0.0
	var next_tick := 1.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.ai._physics_process(DT)
		t += DT
		if t >= next_tick:
			next_tick += 1.0
			w.economy.tick()
			w.research.ai_tick()

func assets(owner: int) -> int:
	return w.buildings.filter(func(b): return b.owner == owner and not b.dead).size() + w.units.filter(func(u): return u.owner == owner and not u.get("dead", false)).size()

func options_checks() -> void:
	var o: Dictionary = Setup.normalize({"map": "island", "players": 9})
	check(int(o.players) == 4, "the original island holds four nations at most (asked 9, got %d)" % int(o.players))
	o = Setup.normalize({"map": "pangaea", "players": 12})
	check(int(o.players) == mini(10, Factions.IDS.size()), "a ten-region map holds every faction there is (asked 12, got %d)" % int(o.players))
	check(Setup.capacity("ten_isles") == mini(10, Factions.IDS.size()) and Setup.capacity("highlands") == 5 and Setup.capacity("small") == 4, "each map's room for nations follows its regions")
	o = Setup.normalize({"map": "pangaea", "players": 4, "levels": ["hard", "bogus", "easy", "hard", "hard"]})
	check(o.levels == ["hard", "", "easy"], "rival difficulties: unknown ones dropped, no more than the rivals (%s)" % str(o.levels))
	check(not Setup.normalize({"map": "small", "levels": ["", ""]}).has("levels"), "no chosen difficulties: the match's own for everyone")
	check(Setup.level_of(o, 1, "normal") == "hard" and Setup.level_of(o, 2, "normal") == "normal" and Setup.level_of(o, 5, "easy") == "easy", "each rival's difficulty, else the match's")
	var r: Array = Setup.roster(Setup.normalize({"map": "pangaea", "players": 9, "nation": 4, "rivals": [0, 8]}))
	var unique := {}
	for i in r: unique[i] = true
	check(r.size() == 9 and unique.size() == 9 and r[0] == 4 and r[1] == 0 and r[2] == 8, "nine nations, all different, yours first and your chosen rivals next (%s)" % str(r))

func match_checks(m: Dictionary) -> void:
	var cfg: Dictionary = m.duplicate()
	var difficulty: String = cfg.difficulty
	cfg.erase("difficulty")
	cfg.style = "standard"
	set_meta("match_config", cfg)
	var t0 := Time.get_ticks_msec()
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(30000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	var tag := "%s, %d nations" % [m.map, m.players]
	if w == null:
		check(false, tag + ": loads")
		return
	print("== %s (%d m), ready in %.1f s" % [tag, int(w.map.mapSize), (Time.get_ticks_msec() - t0) / 1000.0])
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(hash(m.map))
	w.start_match(difficulty)
	w.menu._root.hide()
	for i in range(10): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.set_process(false)
	var count: int = m.players
	var nations: Array = w.map.nations
	var ids := {}
	for n in nations: ids[str(n.get("id", ""))] = true
	check(nations.size() == count and ids.size() == count, tag + ": %d nations, each a different faction" % nations.size())
	check(str(nations[0].get("id", "")) == Factions.IDS[m.nation], tag + ": you lead %s" % Factions.IDS[m.nation])
	var rivals: Array = m.get("rivals", [])
	check(rivals.is_empty() or range(rivals.size()).all(func(i): return str(nations[i + 1].get("id", "")) == Factions.IDS[rivals[i]]), tag + ": the rivals you chose, in your order")
	# Every nation: one capital on land, a town and an army; warships at sea.
	var capitals := []
	var armies := 0
	var towns := 0
	var dry := 0
	var wet := 0
	var navy := 0
	for owner in range(count):
		var hqs: Array = w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)
		if hqs.size() == 1:
			capitals.append(hqs[0])
			if w.height_at(hqs[0].root.position.x, hqs[0].root.position.z) > 0.5: dry += 1
		if w.buildings.filter(func(b): return b.owner == owner and b.key != "hq").size() >= (4 if owner == 0 else 0): towns += 1
		if w.units.filter(func(u): return u.owner == owner and not u.get("naval", false) and u.key != "worker").size() >= (6 if owner == 0 else 2): armies += 1
		for u in w.units.filter(func(u): return u.owner == owner and u.get("naval", false)):
			navy += 1
			if w.height_at(u.node.position.x, u.node.position.z) < -1.0: wet += 1
	check(capitals.size() == count and dry == count, tag + ": every nation has one capital, on land (%d, %d dry)" % [capitals.size(), dry])
	check(towns == count and armies == count, tag + ": you start with the full town, workers and army, whichever nation you lead; every rival with its capital and guard (%d, %d)" % [towns, armies])
	var workers: int = w.units.filter(func(u): return u.owner == 0 and u.key == "worker").size()
	check(workers >= 3, tag + ": you start with workers (%d)" % workers)
	check(navy == 0 or wet == navy, tag + ": warships start at sea (%d of %d)" % [wet, navy])
	var closest := INF
	for a in range(capitals.size()):
		for b in range(a):
			closest = minf(closest, capitals[a].root.position.distance_to(capitals[b].root.position))
	check(closest >= (250.0 if count > 4 else 150.0), tag + ": capitals far apart (closest %d m)" % int(closest))
	w.territory.tick()
	var landed := 0
	for owner in range(count):
		if int(w.territory.yields(owner).cells) >= 5: landed += 1
	check(landed == count, tag + ": every nation holds land of its own (%d of %d)" % [landed, count])
	check(int(w.diplomacy.n) == count and w.ai.nations.size() == count - 1, tag + ": diplomacy and the AI know every nation (%d, %d rivals)" % [int(w.diplomacy.n), w.ai.nations.size()])
	# Each rival at its own difficulty.
	var right := 0
	for n in w.ai.nations:
		var want: String = Setup.level_of(w.match_config, int(n.id), difficulty)
		if str(n.get("level", "")) == want and w.ai.row(n) == w.map.ai.difficulty[want]: right += 1
	check(right == count - 1, tag + ": every rival plays at the difficulty chosen for it (%d of %d)" % [right, count - 1])
	var hard := -1
	var easy := -1
	for n in w.ai.nations:
		if n.level == "hard" and hard < 0: hard = int(n.id)
		if n.level == "easy" and easy < 0: easy = int(n.id)
	# Treasuries level, then two and a half minutes of play.
	for n in w.ai.nations: n.money = 400.0
	var before := {}
	for n in w.ai.nations: before[n.id] = assets(n.id)
	var start_ms := Time.get_ticks_msec()
	sim(150.0)
	var per_step: float = float(Time.get_ticks_msec() - start_ms) / (150.0 / DT)
	var grew: int = w.ai.nations.filter(func(n): return assets(n.id) > before[n.id]).size()
	check(grew == count - 1, tag + ": every rival builds up (%d of %d)" % [grew, count - 1])
	if hard > 0 and easy > 0:
		var gain_hard: int = assets(hard) - before[hard]
		var gain_easy: int = assets(easy) - before[easy]
		check(gain_hard > gain_easy, tag + ": the hard rival outgrows the easy one (+%d vs +%d)" % [gain_hard, gain_easy])
	check(per_step < 80.0, tag + ": the simulation keeps up (%.1f ms a step)" % per_step)
	check(w.economy.res.values().all(func(v): return not is_nan(v) and v >= 0.0), tag + ": the economy runs")
	var saved: Dictionary = w.saves.capture()
	var levels_kept: bool = saved.match_config.get("levels", []) == w.match_config.get("levels", [])
	var rivals_kept: bool = saved.ai.all(func(n): return str(n.get("level", "")) != "")
	check(int(saved.match_config.players) == count and levels_kept and rivals_kept, tag + ": a save keeps the nations and each rival's difficulty")

func picker_checks() -> void:
	set_meta("match_config", {"map": "pangaea", "players": 6, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(30000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	var menu: Node = w.menu
	menu.setup_options = w.match_config.duplicate()
	menu.setup_difficulty = "normal"
	menu.open_new_game()
	await process_frame
	var pickers: Array = menu._panel.find_children("RivalPicker*", "OptionButton", true, false)
	var levels: Array = menu._panel.find_children("RivalLevel*", "OptionButton", true, false)
	check(pickers.size() == 5 and levels.size() == 5, "the picker: a nation and a difficulty for each of 5 rivals (%d, %d)" % [pickers.size(), levels.size()])
	var counts := 0
	for b in menu._panel.find_children("*", "OptionButton", true, false):
		for i in range(b.item_count):
			if b.get_item_text(i) == "9 rivals": counts += 1
	check(counts == 1, "ten-region map offers nine rivals")
	var eight := false
	for b in menu._panel.find_children("*", "OptionButton", true, false):
		for i in range(b.item_count):
			if b.get_item_text(i) == "8 rivals": eight = true
	check(eight, "Pangaea offers up to eight rivals")
	var level: OptionButton = menu._panel.find_child("RivalLevel2", true, false)
	level.select(2)
	level.item_selected.emit(2)
	check(menu.setup_options.get("levels", []).size() == 5 and menu.setup_options.levels[1] == "hard", "choosing a rival's difficulty records it (%s)" % str(menu.setup_options.get("levels", [])))
	check("1 hard" in menu._briefing.text and "4 normal" in menu._briefing.text, "the briefing tells the mix: %s" % menu._briefing.text.replace("\n", " / "))
	# A smaller map: fewer rivals.
	var map_picker: OptionButton = menu._panel.find_child("MapPicker", true, false)
	var small: int = preload("res://scripts/map_catalogue.gd").KEYS.find("small")
	map_picker.select(small)
	map_picker.item_selected.emit(small)
	await process_frame
	check(int(menu.setup_options.players) == 4 and menu._panel.find_children("RivalLevel*", "OptionButton", true, false).size() == 3, "a four-region map cuts the rivals to three (%d nations)" % int(menu.setup_options.players))
	check(Setup.normalize(menu.setup_options).get("levels", []) == ["", "hard", ""], "the chosen difficulty stays with its rival")

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maps="): only = a.substr(7).split(",")
	options_checks()
	for m in MATCHES:
		if not only.is_empty() and not m.map in only: continue
		await match_checks(m)
	if only.is_empty() or "picker" in only:
		await picker_checks()
	print("\nNATIONS_SETUP: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("NATIONS_SETUP PASS" if errors.is_empty() else "NATIONS_SETUP FAIL")
	quit(0 if errors.is_empty() else 1)
