extends SceneTree
## A hundred checks on the five newest maps (Middle East, Europe, East Asia,
## Continents and Distant Lands, Fractal), twenty on each.
## On the map as generated: the same map every time from the same seed; land
## and sea in proportion; deposits on sound ground; whichever nation you lead,
## a capital of your own (at your real capital where the map shows it); two
## nations far apart; the catalogue and its preview.
## Played, at the map's full count of nations: every nation in its own land;
## no unit standing in the sea; a worker builds; no building in the sea; a
## tank sent into the sea stops on the shore; a warship sails; the map's own
## geography (land routes round the seas, island nations cut off by sea, the
## Distant Lands out of reach by land, Fractal's ragged coast); rivals grow
## and stay ashore; the economy runs and the simulation keeps up; a save.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Gen := preload("res://scripts/map_generator.gd")
const Geo := preload("res://scripts/world_geography.gd")
const Setup := preload("res://scripts/match_setup.gd")
const Factions := preload("res://scripts/factions.gd")
const Catalogue := preload("res://scripts/map_catalogue.gd")
const BASE := ["usa", "china", "eu", "iran", "russia", "india", "japan", "turkiye", "israel"]
## Each map played as a different nation, at a different difficulty.
const PLAY := [["middle_east", 8, "normal"], ["europe", 2, "hard"], ["east_asia", 6, "easy"], ["continents_plus", 0, "normal"], ["fractal", 7, "easy"]]
var only: Array = []
var ragged := {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

# ---------------------------------------------------------------- the map as data

func grid_height(data: Dictionary, p: Vector2) -> float:
	var g: Dictionary = data.grid
	var n: int = int(g.size)
	var c := clampi(roundi((p.x - float(g.origin[0])) / float(g.step)), 0, n - 1)
	var r := clampi(roundi((p.y - float(g.origin[1])) / float(g.step)), 0, n - 1)
	return float(g.heightsCm[r * n + c]) / 100.0

func capitals(data: Dictionary) -> Dictionary:
	var out := {}
	for b in data.buildings:
		if b.key == "hq": out[int(b.owner)] = Vector2(float(b.x), float(b.z))
	return out

func built(key: String, cfg: Dictionary) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	var options := {"map": key}
	options.merge(cfg)
	Setup.apply(data, Setup.normalize(options))
	return data

## Where nation `id` should start on a real map, or null.
func real_home(key: String, size: float, id: String) -> Variant:
	if not key in Gen.REAL: return null
	for s in Geo.MAPS[key].starts:
		if s[2] == id: return Geo.to_world(key, size, s[0], s[1])
	return null

func data_checks(key: String) -> void:
	var name: String = Gen.MAPS[key].name
	var players: int = Setup.capacity(key)
	print("== %s (data)" % name)
	# 1: the same seed, the same map.
	var a: Dictionary = built(key, {"players": players, "nation": 0})
	var b: Dictionary = built(key, {"players": players, "nation": 0})
	check(a.grid.heightsCm == b.grid.heightsCm and JSON.stringify(a.deposits) == JSON.stringify(b.deposits) and JSON.stringify(a.buildings) == JSON.stringify(b.buildings), "%s: the same seed makes the same map, deposits and towns" % name)
	# 2: land and sea in proportion, and the heights sound.
	var hs: Array = a.grid.heightsCm
	var n: int = int(a.grid.size)
	var land := 0
	var coast := 0
	var sound := true
	for i in range(hs.size()):
		var h: float = float(hs[i]) / 100.0
		if is_nan(h) or h < -80.0 or h > 160.0: sound = false
		if h > 0.0:
			land += 1
			var r := i / n
			var c := i % n
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var rr: int = r + d.y
				var cc: int = c + d.x
				if rr >= 0 and rr < n and cc >= 0 and cc < n and float(hs[rr * n + cc]) <= 0.0:
					coast += 1
					break
	var share: float = float(land) / hs.size()
	# (coast length over the round island of the same land: 1 for a disc, more the more ragged)
	ragged[key] = float(coast) / (2.0 * sqrt(PI * land))
	check(sound and share > 0.2 and share < 0.85, "%s: land and sea in proportion (%d%% land), heights sound (coast %.1f times a round island's)" % [name, roundi(share * 100.0), ragged[key]])
	# 3: deposits on sound ground, apart from each other.
	var bad := []
	var crowd := 0
	for i in range(a.deposits.size()):
		var d: Dictionary = a.deposits[i]
		var p := Vector2(float(d.x), float(d.z))
		var h := grid_height(a, p)
		if d.get("water", false) or str(d.type) in ["seaOil", "fish"]:
			if h > 0.0: bad.append("%s ashore" % d.type)
		elif h < 0.5:
			bad.append("%s in the sea (%.1f m)" % [d.type, h])
		for j in range(i + 1, a.deposits.size()):
			if p.distance_to(Vector2(float(a.deposits[j].x), float(a.deposits[j].z))) < 8.0: crowd += 1
	check(bad.is_empty() and crowd == 0, "%s: all %d deposits on sound ground and apart%s" % [name, a.deposits.size(), "" if bad.is_empty() and crowd == 0 else " (%s; %d crowded)" % [", ".join(PackedStringArray(bad.slice(0, 4))), crowd]])
	# 4: whichever nation you lead, a capital of your own on land, at your own capital where the map shows it.
	var wrong := []
	for nation in range(BASE.size()):
		var data: Dictionary = built(key, {"players": players, "nation": nation})
		var hq: Dictionary = capitals(data)
		var size: float = float(data.mapSize)
		if not hq.has(0) or grid_height(data, hq[0]) < 0.5:
			wrong.append(BASE[nation] + " no capital")
			continue
		var at = real_home(key, size, BASE[nation])
		if at != null and hq[0].distance_to(at) > 25.0:
			wrong.append("%s %d m from home" % [BASE[nation], int(hq[0].distance_to(at))])
		if hq.size() != players:
			wrong.append("%s with %d capitals" % [BASE[nation], hq.size()])
	check(wrong.is_empty(), "%s: whichever of the nine nations you lead, you get a capital on land%s%s" % [name, ", at your real capital" if key in Gen.REAL else "", "" if wrong.is_empty() else " (%s)" % ", ".join(PackedStringArray(wrong))])
	# 5: two nations: far apart, both on land.
	var duel: Dictionary = built(key, {"players": 2, "nation": 1})
	var two: Dictionary = capitals(duel)
	var gap: float = two[0].distance_to(two[1]) if two.size() == 2 else 0.0
	check(two.size() == 2 and gap > float(duel.mapSize) * 0.25 and grid_height(duel, two[0]) > 0.5 and grid_height(duel, two[1]) > 0.5, "%s: a two-nation match puts the capitals far apart (%d m on a %d m map)" % [name, int(gap), int(duel.mapSize)])
	# 6: a middling count: every capital its own place.
	var mid: Dictionary = capitals(built(key, {"players": 5, "nation": 4}))
	var closest := INF
	for i in mid:
		for j in mid:
			if i < j: closest = minf(closest, mid[i].distance_to(mid[j]))
	check(mid.size() == 5 and closest > 150.0, "%s: five nations, five capitals of their own (closest %d m)" % [name, int(closest)])
	# 7: the catalogue: room for its count, a name, a description and a preview.
	var entry: Dictionary = Catalogue.entry(key)
	var image := Image.load_from_file(ProjectSettings.globalize_path(Catalogue.preview_path(key))) if FileAccess.file_exists(Catalogue.preview_path(key)) else null
	var tex = load(Catalogue.preview_path(key)) if ResourceLoader.exists(Catalogue.preview_path(key)) else null
	var pic_ok: bool = (image != null and image.get_width() >= 64) or (tex != null and tex.get_width() >= 64)
	check(key in Catalogue.KEYS and players == int(Gen.MAPS[key].slots) and str(entry.get("name", "")) == name and str(entry.get("desc", Gen.MAPS[key].desc)) != "" and pic_ok, "%s: in the map picker for up to %d nations, described, with a preview" % [name, players])

# ---------------------------------------------------------------- the map in play

func load_match(cfg: Dictionary, difficulty: String) -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w == null: return
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match(difficulty)
	w.menu._root.hide()
	for i in range(8): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		node.set_process(false)

func sim(seconds: float, rivals := false, done := Callable()) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		if rivals: w.ai._physics_process(DT)
		for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
			node._process(DT)
		t += DT
		if done.is_valid() and done.call():
			break

func hq(owner := 0):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			return b
	return null

func home() -> Vector2i:
	return w.logistics.world_hex(w.start)

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

func find_site(key: String, from := 1, to := 7) -> Variant:
	for ring in range(from, to):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "":
					return at
	return null

## Dry, level ground at or near `at`.
func dry(at: Vector3, far := 30.0) -> Variant:
	var r := 0.0
	while r <= far:
		for i in range(12 if r > 0.0 else 1):
			var p: Vector3 = at + Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 12.0) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
				p.y = w.height_at(p.x, p.z)
				return p
		r += 3.0
	return null

func geo(key: String, city: String) -> Variant:
	for s in Geo.MAPS[key].starts:
		if s[3] == city:
			var v: Vector2 = Geo.to_world(key, float(w.map.mapSize), s[0], s[1])
			return dry(Vector3(v.x, 0, v.y))
	return null

## The land route from `a` to `b`: [whether it gets there, its length, the straight line].
func land_route(a: Variant, b: Variant) -> Array:
	if a == null or b == null: return [false, 0.0, 0.0]
	var route: PackedVector3Array = w.path_between(a, b)
	var length := 0.0
	var prev: Vector3 = a
	for q in route:
		length += Vector2(q.x - prev.x, q.z - prev.z).length()
		prev = q
	var there: bool = not route.is_empty() and Vector2(route[-1].x - b.x, route[-1].z - b.z).length() < 8.0
	return [there, length, Vector2(a.x - b.x, a.z - b.z).length()]

func reaches(a: Variant, b: Variant, label: String) -> void:
	var r := land_route(a, b)
	check(r[0], "%s by land (%d m of road for %d m as the crow flies)" % [label, int(r[1]), int(r[2])])

## A land route that exists, with sea on the straight line between, and longer than it.
func detour(a: Variant, b: Variant, label: String) -> void:
	var r := land_route(a, b)
	var sea: bool = a != null and b != null and w.is_water(a.lerp(b, 0.5), 0.0)
	check(r[0] and sea and r[1] > r[2] * 1.1, "%s (%d m by land, %d m straight%s)" % [label, int(r[1]), int(r[2]), ("" if sea else ", no sea between") if r[0] else ", no route"])

func cut_off(a: Variant, b: Variant, label: String) -> void:
	var r := land_route(a, b)
	check(a != null and b != null and not r[0], "%s%s" % [label, "" if not r[0] else " (a land route of %d m)" % int(r[1])])

func sea_leg(from: Vector3, reach: float) -> Variant:
	for k in range(16):
		var p: Vector3 = from + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0) * reach
		if w.is_water(p) and w.is_water(from.lerp(p, 0.5)) and w.is_water(from.lerp(p, 0.25)) and w.is_water(from.lerp(p, 0.75)):
			return p
	return null

func ashore(u: Dictionary) -> bool:
	return u.get("naval", false) or u.get("fly", false) or not w.is_water(u.node.position, -0.8)

func play_checks(key: String, nation: int, level: String) -> void:
	var players: int = Setup.capacity(key)
	await load_match({"map": key, "players": players, "nation": nation, "style": "standard"}, level)
	var name: String = Gen.MAPS[key].name
	if w == null:
		check(false, "%s loads" % name)
		return
	seed(hash(key))
	print("== %s: %d nations, you lead %s, %s" % [name, players, w.map.nations[0].name, level])
	var t: Node = w.territory
	t.tick()
	# 8: every nation in place, each capital on land in its own territory.
	var caps: Array = w.buildings.filter(func(b): return b.key == "hq" and not b.dead)
	var own: int = caps.filter(func(b): return w.height_at(b.root.position.x, b.root.position.z) > 0.5 and t.owner_at(b.root.position) == b.owner).size()
	check(w.map.nations.size() == players and caps.size() == players and own == players, "%s: %d nations, each capital on land in its own territory (%d of %d)" % [name, players, own, caps.size()])
	# 9: every nation starts with land of its own.
	var small := []
	for i in range(players):
		var cells: int = t.yields(i).cells
		if cells < 7: small.append("%s %d" % [w.map.nations[i].name, cells])
	check(small.is_empty(), "%s: every nation starts with land of its own (7 hexes or more)%s" % [name, "" if small.is_empty() else " (%s)" % ", ".join(PackedStringArray(small))])
	# 10: no one starts standing in the sea.
	var wet: Array = w.units.filter(func(u): return not u.dead and not ashore(u))
	check(wet.is_empty(), "%s: all %d starting units on land or afloat%s" % [name, w.units.size(), "" if wet.is_empty() else " (%d in the sea)" % wet.size()])
	# 11: a worker builds a cottage.
	w.economy.grant_test_resources()
	grant_land(5)
	var at = find_site("cottage")
	var done := false
	if at != null:
		for u in w.units.filter(func(x): return x.owner == 0 and x.key == "worker" and not x.dead): u.build_site = null
		w.build_site("cottage", at)
		var house: Dictionary = w.buildings[-1]
		sim(70.0, false, func(): return house.built)
		done = house.built
	check(done, "%s: a worker builds a cottage beside the capital" % name)
	for i in range(6): await physics_frame
	# 12: nothing is built in the sea.
	var sea = w.water_near(w.start, 300)
	var refusal: String = w.site_problem("farm", sea, 0) if sea != null else ""
	check(sea != null and refusal != "", "%s: a farm may not be put in the sea (\"%s\")" % [name, refusal])
	# 13: a tank sent into the sea stops on the shore.
	var shore := false
	var how := "no sea"
	if sea != null:
		# (from 60 m inland, back toward the capital)
		var from = dry(sea + (hq().root.position - sea).normalized() * 60.0)
		if from == null: from = dry(w.start, 60.0)
		var tank: Dictionary = w.spawn_unit("tank", from, 0)
		w.order_move([tank], sea)
		sim(50.0, false, func(): return tank.target == null)
		var moved: float = Vector2(tank.node.position.x - from.x, tank.node.position.z - from.z).length()
		shore = not w.is_water(tank.node.position, -0.8) and moved > 25.0
		how = "%d m driven, %d m from the mark, %.1f m above the sea" % [int(moved), int(Vector2(tank.node.position.x - sea.x, tank.node.position.z - sea.z).length()), w.height_at(tank.node.position.x, tank.node.position.z) - float(w.map.seaLevel)]
		w.kill(tank)
	check(shore, "%s: a tank sent into the sea drives to the shore and stops there (%s)" % [name, how])
	# 14: a warship sails.
	var leg = sea_leg(sea, 80.0) if sea != null else null
	var short := INF
	if leg != null:
		var ship: Dictionary = w.spawn_unit("corvette", sea, 0)
		w.order_move([ship], leg)
		sim(60.0, false, func(): return ship.target == null)
		short = Vector2(ship.node.position.x - leg.x, ship.node.position.z - leg.z).length()
		check(w.is_water(ship.node.position, -0.5) and short < 15.0, "%s: a corvette sails 80 m at sea (%d m short)" % [name, int(short)])
		w.kill(ship)
	else:
		check(false, "%s: open water near the capital for a corvette" % name)
	# 15-16: the map's own geography.
	match key:
		"middle_east":
			reaches(geo(key, "Ankara"), geo(key, "Tehran"), "Middle East: Ankara reaches Tehran")
			detour(geo(key, "Kyiv"), geo(key, "Ankara"), "Middle East: from Kyiv to Ankara the land route goes round the Black Sea")
		"europe":
			reaches(geo(key, "Brussels"), geo(key, "Moscow"), "Europe: Brussels reaches Moscow")
			detour(geo(key, "Madrid"), geo(key, "Rome"), "Europe: from Madrid to Rome the land route goes round the sea, through France")
		"east_asia":
			cut_off(geo(key, "Tokyo"), geo(key, "Beijing"), "East Asia: Japan is an island, no land route from Tokyo to Beijing")
			reaches(geo(key, "Beijing"), geo(key, "Hanoi"), "East Asia: Beijing reaches Hanoi")
		"continents_plus":
			var me: Vector3 = hq().root.position
			var other = null
			for b in caps:
				if signf(b.root.position.x) != signf(me.x) and (other == null or b.root.position.distance_to(me) < other.distance_to(me)):
					other = b.root.position
			detour(dry(me + (Vector3.ZERO - me).normalized() * 45.0), dry(other + (Vector3.ZERO - other).normalized() * 45.0) if other != null else null, "Continents: the other continent is reached by land only round by the isthmus")
			var cut := 0
			var islands := 0
			var half := float(w.map.mapSize) * 0.5
			for c in Gen.DISTANT:
				var isle = dry(Vector3(c.x * half, 0, c.y * half), 40.0)
				if isle == null: continue
				islands += 1
				if not land_route(dry(me + (Vector3.ZERO - me).normalized() * 45.0), isle)[0]: cut += 1
			check(islands >= 3 and cut == islands, "Continents: the Distant Lands are out of reach by land (%d of %d islands)" % [cut, islands])
		"fractal":
			var me = dry(hq().root.position + Vector3(0, 0, 0), 60.0)
			var reach := 0
			for b in caps:
				if b.owner == 0: continue
				if land_route(me, dry(b.root.position, 60.0))[0]: reach += 1
			check(reach == caps.size() - 1, "Fractal: a land route still links your capital to every other (%d of %d)" % [reach, caps.size() - 1])
			check(ragged.get("fractal", 0.0) > ragged.get("continents_plus", INF) * 1.25, "Fractal: a more ragged coast than Continents (%.1f against %.1f times a round island's)" % [ragged.get("fractal", 0.0), ragged.get("continents_plus", 0.0)])
	# 17-19: rivals grow and stay ashore; the economy runs; the simulation keeps up.
	var before := {}
	for n in w.ai.nations: before[n.id] = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
	var money0: float = w.economy.res.money
	var t0 := Time.get_ticks_msec()
	sim(120.0, true)
	var per_step: float = float(Time.get_ticks_msec() - t0) / (120.0 / DT)
	var grew: int = w.ai.nations.filter(func(n): return w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size() > before[n.id]).size()
	check(grew == w.ai.nations.size(), "%s: every rival builds up in two minutes (%d of %d)" % [name, grew, w.ai.nations.size()])
	var rivals_wet: Array = w.units.filter(func(u): return u.owner != 0 and not u.dead and not ashore(u))
	check(rivals_wet.is_empty(), "%s: the rivals' land forces keep to the land (%d in the sea%s)" % [name, rivals_wet.size(), "" if rivals_wet.is_empty() else ": " + ", ".join(PackedStringArray(rivals_wet.slice(0, 3).map(func(u): return "%s at %s" % [u.key, str(u.node.position.snapped(Vector3.ONE))])))])
	check(w.economy.res.money >= money0 * 0.98 and w.economy.res.values().all(func(v): return not is_nan(v) and v >= 0.0) and per_step < 70.0, "%s: the economy runs and the simulation keeps up at %d nations (%.1f ms a step)" % [name, players, per_step])
	# 20: a save and back.
	var buildings: int = w.buildings.filter(func(b): return not b.dead).size()
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(data)
	for i in range(5): await process_frame
	var cfg: Dictionary = data.get("match_config", {})
	var back: int = w.buildings.filter(func(b): return not b.dead).size()
	check(str(cfg.get("map", "")) == key and w.map.nations.size() == players and w.buildings.filter(func(b): return b.key == "hq" and not b.dead).size() == players and absi(back - buildings) <= 1, "%s: the match comes back from a save as it was (%d buildings, then %d)" % [name, buildings, back])

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maps="): only = a.substr(7).split(",")
	# (Continents before Fractal: Fractal's coast is measured against it.)
	for p in PLAY:
		if only.is_empty() or p[0] in only or (p[0] == "continents_plus" and "fractal" in only):
			data_checks(p[0])
	for p in PLAY:
		if only.is_empty() or p[0] in only:
			await play_checks(p[0], p[1], p[2])
	print("\nNEW_MAPS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("NEW_MAPS PASS" if errors.is_empty() else "NEW_MAPS FAIL")
	quit(0 if errors.is_empty() else 1)
