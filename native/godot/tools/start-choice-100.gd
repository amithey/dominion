extends SceneTree
## A hundred checks on choosing where each nation starts (match_setup.gd
## "starts", map_generator.gd _spread_starts / _real_starts, the Start pickers).
## On every map: each region can be yours (a rival's on the original islands),
## on land, your town and army with you; a full house in a shuffled order; half
## the nations placed, the rest left to the map. The options' rules; the real
## maps' own capitals given away; duels; riches near every chosen capital; the
## same choice, the same map. The New Game screen's pickers and region numbers.
## Matches begun with choices: towns, armies, territory, rivals, saves.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Setup := preload("res://scripts/match_setup.gd")
const Gen := preload("res://scripts/map_generator.gd")
const Geo := preload("res://scripts/world_geography.gd")
const Catalogue := preload("res://scripts/map_catalogue.gd")
const NAVAL := ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
## The original island's capitals (data/map-seed1.json), by start.
const ISLAND_HQ := [Vector2(155.88, -162), Vector2(155.88, 162), Vector2(-155.88, 162), Vector2(-155.88, -162)]
var source: Dictionary
var only: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

# ---------------------------------------------------------------- the map as data

func built(options: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	Setup.apply(data, Setup.normalize(options))
	return data

func capitals(data: Dictionary) -> Dictionary:
	var out := {}
	for b in data.buildings:
		if b.key == "hq": out[int(b.owner)] = Vector2(float(b.x), float(b.z))
	return out

func fixed(key: String) -> bool:
	return not Gen.is_generated(key)

## Region k of map `key`, in metres.
func region(key: String, k: int, size: float) -> Vector2:
	if fixed(key):
		var p: Vector2 = ISLAND_HQ[k]
		return Vector2(-p.x, p.y) if key == "mirrored" else p
	return Setup.start_slots(key)[k].at * size * 0.5

func grid_height(data: Dictionary, p: Vector2) -> float:
	var g: Dictionary = data.grid
	var n: int = int(g.size)
	var c := clampi(roundi((p.x - float(g.origin[0])) / float(g.step)), 0, n - 1)
	var r := clampi(roundi((p.y - float(g.origin[1])) / float(g.step)), 0, n - 1)
	return float(g.heightsCm[r * n + c]) / 100.0

## Whether every nation given a region is there, and the others apart from them and each other.
func placed(key: String, data: Dictionary, picks: Array) -> String:
	var hq := capitals(data)
	var size: float = float(data.mapSize)
	var wrong := []
	for i in range(picks.size()):
		if picks[i] >= 0 and (not hq.has(i) or hq[i].distance_to(region(key, picks[i], size)) > 2.0):
			wrong.append("nation %d not at region %d" % [i, picks[i] + 1])
	for i in hq:
		for j in hq:
			if i < j and hq[i].distance_to(hq[j]) < 60.0:
				wrong.append("nations %d and %d together" % [i, j])
		if grid_height(data, hq[i]) < 0.5:
			wrong.append("nation %d in the sea" % i)
	return ", ".join(PackedStringArray(wrong))

func map_checks(key: String) -> void:
	var name: String = Catalogue.entry(key).name
	var regions: int = Setup.region_count(key)
	var players: int = Setup.capacity(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	print("== %s: %d regions" % [name, regions])
	# 1: every region can be yours (on the original islands, a rival's), your town and army with you.
	var bad := []
	var who := 1 if fixed(key) else 0
	for k in range(1 if fixed(key) else 0, regions):
		var picks := [-1, -1]
		picks[who] = k
		var data: Dictionary = built({"map": key, "players": players, "nation": 3, "starts": picks})
		var problem := placed(key, data, picks)
		var hq: Vector2 = capitals(data)[who]
		var strays: int = data.units.filter(func(u): return int(u.owner) == who and not u.key in NAVAL and Vector2(float(u.x), float(u.z)).distance_to(hq) > 90.0).size()
		var town: int = data.buildings.filter(func(b): return int(b.owner) == who and Vector2(float(b.x), float(b.z)).distance_to(hq) < 90.0).size()
		var guard: int = data.units.filter(func(u): return int(u.owner) == who and Vector2(float(u.x), float(u.z)).distance_to(hq) < 90.0).size()
		# (on the original islands a rival starts with its capital and a guard of two)
		var enough: bool = (town >= 1 and guard >= 2) if fixed(key) else town >= 2
		if problem != "" or strays > 0 or not enough:
			bad.append("region %d: %s%s" % [k + 1, problem, " %d units astray, %d buildings, %d units" % [strays, town, guard] if strays > 0 or not enough else ""])
	check(bad.is_empty(), "%s: every region can be %s, on land, with %s%s" % [name, "a rival's" if fixed(key) else "yours", "its capital and guard" if fixed(key) else "your town and army", "" if bad.is_empty() else " (%s)" % "; ".join(PackedStringArray(bad))])
	# 2: a full house, in a shuffled order.
	var order := range(regions)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var full: Array = order.slice(0, players)
	if fixed(key):
		# (your town is fixed there: the rivals shuffled over the other three)
		full = [-1] + order.filter(func(k): return k != 0)
	var data2: Dictionary = built({"map": key, "players": players, "nation": 5, "starts": full})
	var p2 := placed(key, data2, full)
	check(p2 == "" and capitals(data2).size() == players, "%s: all %d nations each at the region chosen, in a shuffled order %s%s" % [name, players, str(full.map(func(k): return k + 1)), "" if p2 == "" else " (%s)" % p2])
	# 3: half chosen, the rest left to the map.
	var half := []
	for i in range(players):
		half.append(full[i] if i % 2 == 1 else -1)
	var data3: Dictionary = built({"map": key, "players": players, "nation": 7, "starts": half})
	var hq3 := capitals(data3)
	var clash := 0
	for i in hq3:
		if half[i] >= 0: continue
		for k in half:
			if k >= 0 and hq3[i].distance_to(region(key, k, float(data3.mapSize))) < 2.0: clash += 1
	var p3 := placed(key, data3, half)
	check(p3 == "" and clash == 0 and hq3.size() == players, "%s: half the nations placed, the others elsewhere on their own%s" % [name, "" if p3 == "" and clash == 0 else " (%s; %d on a chosen region)" % [p3, clash]])

func rule_checks() -> void:
	print("== the options")
	var n: Dictionary = Setup.normalize(JSON.parse_string(JSON.stringify({"map": "crown", "players": 4, "starts": [2, 5]})))
	check(n.get("starts") == [2, 5], "regions from a save (numbers read as decimals) are taken (%s)" % str(n.get("starts")))
	check(Setup.normalize({"map": "crown", "players": 3, "starts": ["3", "x", 1]}).get("starts") == [3, -1, 1], "a region written as text is read, nonsense left to the map")
	check(Setup.normalize({"map": "crown", "players": 3, "starts": [-5, 4, -1]}).get("starts") == [-1, 4, -1], "a negative region is left to the map")
	check(Setup.normalize({"map": "crown", "players": 3, "starts": [0, 1, 2, 3, 4]}).get("starts") == [0, 1, 2], "choices past the count of nations fall away")
	check(Setup.normalize({"map": "crown", "players": 3, "starts": [8, 7]}).get("starts") == [-1, 7], "a region past the map's last is left to the map (Crown Isles has 8)")
	check(Setup.normalize({"map": "small", "players": 4, "starts": [1, 2, 1, 2]}).get("starts") == [1, 2, -1, -1], "a region chosen twice goes to the first who chose it")
	check(Setup.normalize({"map": "mirrored", "players": 3, "starts": [1, 0, 2]}).get("starts") == [-1, -1, 2], "on the mirrored island your town is fixed and no rival takes it")
	check(not Setup.normalize({"map": "crown", "starts": [-1, -1, -1]}).has("starts") and not Setup.normalize({"map": "crown", "starts": {"a": 1}}).has("starts") and not Setup.normalize({"map": "island", "starts": [0]}).has("starts"), "no real choice: nothing kept")
	check(Setup.starts_of({"players": 4, "starts": [3]}) == [3, -1, -1, -1] and Setup.starts_of({"players": 2}) == [-1, -1], "every nation has a start, left to the map unless chosen")
	var once: Dictionary = Setup.normalize({"map": "pangaea", "players": 6, "nation": 4, "rivals": [1, 2], "levels": ["hard"], "starts": [9, -1, 3, 3, 0]})
	check(Setup.normalize(once) == once and once.get("levels") == ["hard"] and once.get("rivals") == [1, 2], "the options settle at once, the rivals and their levels untouched (%s)" % str(once.get("starts")))

func real_checks() -> void:
	for key in Gen.REAL:
		var name: String = Gen.MAPS[key].name
		var slots: Array = Geo.MAPS[key].starts
		var native := -1
		var native_id := ""
		for k in range(slots.size()):
			if slots[k][2] != "":
				native = k
				native_id = slots[k][2]
				break
		var native_index: int = Setup.NATIONS.size()
		native_index = preload("res://scripts/factions.gd").IDS.find(native_id)
		var other := 0 if native_index != 0 else 1
		# You (not from here) take a native's capital: that nation starts elsewhere.
		var data: Dictionary = built({"map": key, "players": 4, "nation": other, "rivals": [native_index], "starts": [native]})
		var hq := capitals(data)
		var size: float = float(data.mapSize)
		var home: Vector2 = Geo.to_world(key, size, slots[native][0], slots[native][1])
		check(hq[0].distance_to(home) < 25.0 and hq[1].distance_to(home) > 100.0 and placed(key, data, [native]) == "", "%s: you take %s's capital %s, and %s starts elsewhere" % [name, native_id, slots[native][3], native_id])
		# A native sent to an open city: there, and the others still at home.
		var open := -1
		for k in range(slots.size()):
			if slots[k][2] == "": open = k
		var locals := []
		for s in slots:
			var idx: int = preload("res://scripts/factions.gd").IDS.find(str(s[2]))
			if s[2] != "" and idx != native_index: locals.append(idx)
		var data2: Dictionary = built({"map": key, "players": 4, "nation": native_index, "rivals": locals.slice(0, 3), "starts": [open]})
		var hq2 := capitals(data2)
		var still := 0
		var natives := 0
		for i in range(1, data2.nations.size()):
			var id := str(data2.nations[i].get("id", ""))
			for s in slots:
				if s[2] == id:
					natives += 1
					if hq2[i].distance_to(Geo.to_world(key, size, s[0], s[1])) < 25.0: still += 1
		check(hq2[0].distance_to(region(key, open, size)) < 2.0 and still == natives, "%s: %s sent to %s starts there; the other nations from here keep their capitals (%d of %d)" % [name, native_id, slots[open][3], still, natives])
	# Duels.
	var duel: Dictionary = built({"map": "middle_east", "players": 2, "nation": 0, "rivals": [1], "starts": [5, 6]})
	var d := capitals(duel)
	check(placed("middle_east", duel, [5, 6]) == "" and d[0].distance_to(d[1]) < 400.0, "a duel set at Riyadh and Baghdad is played there, close as they are (%d m)" % int(d[0].distance_to(d[1])))
	var duel2: Dictionary = built({"map": "middle_east", "players": 2, "nation": 0, "rivals": [1], "starts": [5, -1]})
	var d2 := capitals(duel2)
	check(d2[0].distance_to(region("middle_east", 5, 1600.0)) < 2.0 and d2[0].distance_to(d2[1]) >= 400.0, "you set at Riyadh in a duel: the rival left to the map starts across it (%d m)" % int(d2[0].distance_to(d2[1])))

func riches_checks() -> void:
	for c in [["middle_east", [7, 3, 0, 5, 1, 6, 2, 4]], ["europe", [8, 6, 0, 1, 2, 3, 4, 5, 7]], ["east_asia", [8, 7, 6, 5, 4, 3, 2, 1, 0]], ["continents_plus", [2, 6, 0, 4, 1, 3, 5, 7]], ["pangaea", [9, 1, 3, 5, 7, 0, 2, 4, 6]]]:
		var key: String = c[0]
		var picks: Array = c[1].slice(0, Setup.capacity(key))
		var data: Dictionary = built({"map": key, "players": picks.size(), "nation": 1, "starts": picks})
		var poor := []
		var hq := capitals(data)
		for i in hq:
			var near := {}
			for dd in data.deposits:
				if hq[i].distance_to(Vector2(float(dd.x), float(dd.z))) < 110.0: near[dd.type] = true
			if not (near.has("oil") and near.has("iron") and near.has("gold")): poor.append(str(picks[i] + 1))
		check(poor.is_empty(), "%s: oil, iron and gold near every chosen capital%s" % [Catalogue.entry(key).name, "" if poor.is_empty() else " (not at regions %s)" % ", ".join(PackedStringArray(poor))])
	var a: Dictionary = built({"map": "europe", "players": 6, "nation": 2, "starts": [4, -1, 0, 7]})
	var b: Dictionary = built({"map": "europe", "players": 6, "nation": 2, "starts": [4, -1, 0, 7]})
	check(a.grid.heightsCm == b.grid.heightsCm and JSON.stringify(a.buildings) == JSON.stringify(b.buildings) and JSON.stringify(a.deposits) == JSON.stringify(b.deposits), "the same choices make the same map, every time (as a save reloads it)")
	check(not a.has("startSlots") and a.startPositions.size() == 6, "the choices leave nothing behind in the map but its towns")

# ---------------------------------------------------------------- the screen

func wait_world(old: Node = null) -> void:
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene != old and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			return

func reopen() -> void:
	w.menu.open_new_game()
	await process_frame
	await process_frame

func node(name: String) -> Node:
	return w.menu._root.find_child(name, true, false)

func pick(name: String, index: int) -> void:
	var p: OptionButton = node(name)
	p.select(index)
	p.item_selected.emit(index)
	await process_frame
	await process_frame

func screen_checks() -> void:
	set_meta("match_config", {"map": "crown", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	await wait_world()
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.menu.setup_options = Setup.normalize({"map": "crown", "players": 4, "nation": 0})
	await reopen()
	print("== the New Game screen")
	var items: Array = range(4).map(func(i): return node("StartPicker%d" % i))
	var p1: OptionButton = items[1]
	check(items.all(func(p): return p != null) and node("StartPicker4") == null, "a Start picker for you and each of three rivals, no more")
	check(p1.item_count == 9 and p1.get_item_text(0) == "Auto" and p1.get_item_text(3).begins_with("3 · "), "each lists Auto and the eight regions, numbered (%s)" % p1.get_item_text(3))
	# Every map: as many numbers as regions, on the preview.
	var wrong := []
	for key in Catalogue.KEYS:
		w.menu.setup_options.map = key
		w.menu.setup_options.players = mini(int(w.menu.setup_options.players), Setup.capacity(key))
		await reopen()
		var preview: Control = node("MapPreview")
		var marks: Array = preview.get_children().filter(func(c): return c is Label and not c.is_queued_for_deletion())
		if marks.size() != Setup.region_count(key) or marks.any(func(m): return m.anchor_left < 0.0 or m.anchor_left > 1.0 or m.anchor_top < 0.0 or m.anchor_top > 1.0):
			wrong.append(key)
	check(wrong.is_empty(), "every map shows its regions' numbers on its preview%s" % ("" if wrong.is_empty() else ": not " + str(wrong)))
	# The original island: your town fixed, the rivals Auto or one of three.
	w.menu.setup_options = Setup.normalize({"map": "island", "players": 4, "nation": 0})
	await reopen()
	var mine: OptionButton = node("StartPicker0")
	var theirs: OptionButton = node("StartPicker2")
	check(mine.disabled and mine.get_item_text(0).contains("your town") and theirs.item_count == 4 and not theirs.disabled, "the original island: your town fixed (%s), a rival's start Auto or one of three" % mine.get_item_text(0))
	# Back to the Crown Isles: choose, swap, clear.
	w.menu.setup_options = Setup.normalize({"map": "crown", "players": 4, "nation": 0})
	await reopen()
	await pick("StartPicker1", 5)
	await pick("StartPicker2", 2)
	await pick("StartPicker3", 5)
	check(Setup.starts_of(w.menu.setup_options) == [-1, -1, 1, 4], "a region one rival holds, chosen for another, leaves the first to the map (%s)" % str(Setup.starts_of(w.menu.setup_options)))
	await pick("StartPicker2", 6)
	await pick("StartPicker1", 6)
	check(Setup.starts_of(w.menu.setup_options) == [-1, 5, -1, 4], "two rivals swap when one takes the other's region (%s)" % str(Setup.starts_of(w.menu.setup_options)))
	await pick("StartPicker3", 0)
	check(Setup.starts_of(w.menu.setup_options) == [-1, 5, -1, -1], "Auto gives a region back to the map")
	var sel: OptionButton = node("StartPicker1")
	check(sel.get_selected_id() - 1 == 5 and node("StartPicker0").get_selected_id() == 0, "the pickers show what was chosen, after the screen is rebuilt")
	var mark: Label = node("Region6")
	var rival_colour := Color(Setup.COLOURS[Setup.roster(w.menu.setup_options)[1]])
	check(mark != null and mark.get_theme_color("font_color") == rival_colour and node("Region1").get_theme_color("font_color") != rival_colour, "a rival's chosen region shows in its colour on the map")
	# A rival's nation changed: the region stays with that place in the list.
	var nation_picker: OptionButton = node("RivalPicker1")
	var before: int = Setup.roster(w.menu.setup_options)[1]
	var other := 0
	for i in range(nation_picker.item_count):
		if nation_picker.get_item_id(i) != before: other = i
	await pick("RivalPicker1", other)
	check(Setup.roster(w.menu.setup_options)[1] != before and Setup.starts_of(w.menu.setup_options)[1] == 5, "a rival's nation changed keeps that rival's region")
	# More rivals: the choices kept; fewer: the cut rival's choice gone.
	await pick("StartPicker3", 8)
	w.menu.setup_options.players = 6
	await reopen()
	var more: Array = Setup.starts_of(w.menu.setup_options)
	var sixth: bool = node("StartPicker5") != null
	w.menu.setup_options.players = 3
	await reopen()
	var fewer: Dictionary = Setup.normalize(w.menu.setup_options)
	check(more == [-1, 5, -1, 7, -1, -1] and sixth and fewer.get("starts") == [-1, 5, -1] and node("StartPicker3") == null, "more rivals keep the choices made; fewer drop the choices of those left out (%s; %s)" % [str(more), str(fewer.get("starts"))])

# ---------------------------------------------------------------- matches

func begin(cfg: Dictionary, level := "easy") -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	await wait_world()
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match(level)
	w.menu._root.hide()
	for i in range(8): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for n in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		n.set_process(false)

func sim(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		w.ai._physics_process(DT)
		for n in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
			n._process(DT)
		t += DT

func hq(owner: int):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			return b
	return null

func flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

func match_checks() -> void:
	# Europe: you (the EU) at Madrid, Russia left to the map, a rival at Brussels.
	await begin({"map": "europe", "players": 5, "nation": 2, "rivals": [4, 0, 1, 7], "starts": [4, -1, 0]})
	print("== Europe: the EU at Madrid, the USA at Brussels")
	var size: float = float(w.map.mapSize)
	w.territory.tick()
	var me: Vector2 = flat(hq(0).root.position)
	check(me.distance_to(region("europe", 4, size)) < 3.0 and w.territory.owner_at(hq(0).root.position) == 0 and w.territory.yields(0).cells >= 7, "Europe: your capital at Madrid, in land of your own (%d hexes)" % w.territory.yields(0).cells)
	var army: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and not u.get("naval", false))
	var astray: Array = army.filter(func(u): return flat(u.node.position).distance_to(me) > 110.0)
	check(not army.is_empty() and astray.is_empty(), "Europe: your army stands by your capital (%d units, %d astray)" % [army.size(), astray.size()])
	var town: Array = w.buildings.filter(func(b): return b.owner == 0 and not b.dead)
	var far_off: Array = town.filter(func(b): return flat(b.root.position).distance_to(me) > 110.0)
	check(town.size() >= 5 and far_off.is_empty(), "Europe: your whole town stands round your capital (%d buildings, %d away)" % [town.size(), far_off.size()])
	var russia: Vector2 = flat(hq(1).root.position)
	var moscow: Vector2 = Geo.to_world("europe", size, 37.62, 55.75)
	check(russia.distance_to(moscow) < 25.0 and flat(hq(2).root.position).distance_to(region("europe", 0, size)) < 3.0 and w.territory.owner_at(hq(2).root.position) == 2, "Europe: Russia left to the map is at Moscow; the USA at Brussels holds its land")
	var before := {}
	for n in w.ai.nations: before[n.id] = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
	sim(100.0)
	var grew: int = w.ai.nations.filter(func(n): return w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size() > before[n.id]).size()
	check(grew == w.ai.nations.size(), "Europe: every rival builds up from where it was put (%d of %d)" % [grew, w.ai.nations.size()])
	var places := {}
	for i in range(5): places[i] = flat(hq(i).root.position)
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(data)
	for i in range(5): await process_frame
	var kept := true
	for i in range(5):
		if hq(i) == null or flat(hq(i).root.position).distance_to(places[i]) > 1.0: kept = false
	check(kept and Setup.normalize(data.match_config).get("starts") == [4, -1, 0], "Europe: a save brings every capital back where it was chosen")
	# East Asia: China on Tokyo's island, Japan left to the map.
	await begin({"map": "east_asia", "players": 4, "nation": 1, "rivals": [6, 5, 0], "starts": [1]})
	print("== East Asia: China at Tokyo")
	size = float(w.map.mapSize)
	me = flat(hq(0).root.position)
	var ships: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.get("naval", false))
	check(me.distance_to(region("east_asia", 1, size)) < 3.0 and not ships.is_empty() and ships.all(func(u): return w.is_water(u.node.position, -0.5) and flat(u.node.position).distance_to(me) < 220.0), "East Asia: China starts on Tokyo's island, its %d warships at sea off it" % ships.size())
	var japan: Vector2 = flat(hq(1).root.position)
	check(japan.distance_to(me) > 100.0 and w.height_at(japan.x, japan.y) > 0.5 and w.territory.owner_at(hq(1).root.position) == 1, "East Asia: Japan, its capital taken, starts on land of its own elsewhere")
	# The original island: the rivals at the starts chosen, each with its town.
	await begin({"map": "island", "players": 4, "nation": 0, "starts": [-1, 3, 1, 2]})
	print("== The Island: rivals placed")
	var towns := 0
	for i in range(1, 4):
		var at: Vector2 = flat(hq(i).root.position)
		var guard: int = w.units.filter(func(u): return u.owner == i and not u.dead and flat(u.node.position).distance_to(at) < 90.0).size()
		if at.distance_to(region("island", [3, 1, 2][i - 1], 640.0)) < 3.0 and guard >= 2: towns += 1
	check(towns == 3 and flat(hq(0).root.position).distance_to(ISLAND_HQ[0]) < 3.0, "The Island: each rival at the start chosen with its capital and guard, you in your town (%d of 3)" % towns)
	# The mirrored island: begun from the screen's Begin campaign.
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	await wait_world()
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.menu.setup_options = Setup.normalize({"map": "mirrored", "players": 3, "nation": 4, "starts": [-1, 3]})
	var old := w
	w.menu.start("normal")
	await wait_world(old)
	for i in range(5): await physics_frame
	check(w.match_config.map == "mirrored" and w.match_difficulty == "normal" and hq(1) != null and flat(hq(1).root.position).distance_to(region("mirrored", 3, 640.0)) < 3.0 and flat(hq(0).root.position).distance_to(region("mirrored", 0, 640.0)) < 3.0, "The mirrored island, begun from the New Game screen: the rival at the start chosen, you in the west")

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7).split(",")
	source = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	if only.is_empty() or "maps" in only:
		for key in Catalogue.KEYS: map_checks(key)
	if only.is_empty() or "rules" in only:
		rule_checks()
		real_checks()
		riches_checks()
	if only.is_empty() or "screen" in only:
		await screen_checks()
	if only.is_empty() or "match" in only:
		await match_checks()
	print("\nSTART_CHOICE_100: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("START_CHOICE_100 PASS" if errors.is_empty() else "START_CHOICE_100 FAIL")
	quit(0 if errors.is_empty() else 1)
