extends SceneTree
## The real-world maps (world_geography.gd, map_generator.gd): every nation
## whose capital the map shows starts at that capital, the others at the open
## cities; capitals are on land, far enough apart, with ground for a town and
## oil, iron and gold near; the seas, inland seas and mountains are where they
## are on Earth.
var errors: Array[String] = []
var passed := 0
const Gen := preload("res://scripts/map_generator.gd")
const Geo := preload("res://scripts/world_geography.gd")
const Setup := preload("res://scripts/match_setup.gd")
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## Height of the built grid at world point p.
func height(data: Dictionary, p: Vector2) -> float:
	var g: Dictionary = data.grid
	var n: int = int(g.size)
	var c := clampi(roundi((p.x - float(g.origin[0])) / float(g.step)), 0, n - 1)
	var r := clampi(roundi((p.y - float(g.origin[1])) / float(g.step)), 0, n - 1)
	return float(g.heightsCm[r * n + c]) / 100.0

func at(key: String, size: float, lon: float, lat: float) -> Vector2:
	return Geo.to_world(key, size, lon, lat)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	for key in Gen.REAL:
		var slots: Array = Geo.MAPS[key].starts
		var natives: Array = slots.filter(func(s): return s[2] != "").map(func(s): return s[2])
		var lead: int = Factions.IDS.find(natives[0])
		var players: int = Setup.capacity(key)
		var data: Dictionary = source.duplicate(true)
		Setup.apply(data, Setup.normalize({"map": key, "players": players, "nation": lead}))
		var size: float = float(data.mapSize)
		var name: String = Gen.MAPS[key].name
		print("== %s, %d nations" % [name, players])
		var hqs := {}
		for b in data.buildings:
			if b.key == "hq": hqs[int(b.owner)] = Vector2(float(b.x), float(b.z))
		# 1: natives at their capitals.
		var home := 0
		var home_names := []
		for i in range(data.nations.size()):
			var id: String = str(data.nations[i].get("id", ""))
			for s in slots:
				if s[2] == id:
					home_names.append("%s %s" % [id, s[3]])
					if hqs.has(i) and hqs[i].distance_to(at(key, size, s[0], s[1])) < 25.0: home += 1
		check(home == natives.filter(func(id): return data.nations.any(func(n): return str(n.get("id", "")) == id)).size(), "%s: each nation whose capital is on the map starts there (%s)" % [name, ", ".join(PackedStringArray(home_names))])
		# 2: the others at open cities.
		var open_ok := true
		for i in range(data.nations.size()):
			var id: String = str(data.nations[i].get("id", ""))
			if id in natives: continue
			var nearest := INF
			for s in slots:
				if s[2] == "": nearest = minf(nearest, hqs[i].distance_to(at(key, size, s[0], s[1])))
			if nearest > 25.0: open_ok = false
		# (when the nations whose capitals these are stay out of the match, the
		# open cities fill first and then their capitals: 22 nations, 3 open cities)
		var opens: int = slots.filter(func(s): return s[2] == "").size()
		var outsiders: int = data.nations.filter(func(n): return not str(n.get("id", "")) in natives).size()
		var at_open := 0
		for i in range(data.nations.size()):
			if str(data.nations[i].get("id", "")) in natives: continue
			for s in slots:
				if s[2] == "" and hqs[i].distance_to(at(key, size, s[0], s[1])) < 25.0: at_open += 1
		open_ok = at_open == mini(outsiders, opens)
		check(open_ok, "%s: the other nations take the open cities first (%d of %d)" % [name, at_open, mini(outsiders, opens)])
		# 3-6: capitals.
		var dry := 0
		var room := 0
		var rich := 0
		var closest := INF
		var keys: Array = hqs.keys()
		for k in keys:
			var p: Vector2 = hqs[k]
			if height(data, p) > 0.5: dry += 1
			var ground := 0
			for a in range(12):
				var q := p + Vector2.from_angle(TAU * a / 12.0) * 35.0
				if height(data, q) > 0.8: ground += 1
			if ground >= 8: room += 1
			var near := {}
			for dd in data.deposits:
				if p.distance_to(Vector2(dd.x, dd.z)) < 110.0: near[dd.type] = true
			if near.has("oil") and near.has("iron") and near.has("gold"): rich += 1
			for k2 in keys:
				if k2 != k: closest = minf(closest, p.distance_to(hqs[k2]))
		check(dry == keys.size(), "%s: every capital on land (%d of %d)" % [name, dry, keys.size()])
		check(room == keys.size(), "%s: ground for a town round each (%d of %d)" % [name, room, keys.size()])
		check(rich == keys.size(), "%s: oil, iron and gold near each (%d of %d)" % [name, rich, keys.size()])
		check(closest >= 200.0, "%s: capitals at least 200 m apart (closest %d m)" % [name, int(closest)])
	# 7-: the geography itself.
	var probes := [
		["middle_east", 51.0, 42.0, "water", "the Caspian Sea"], ["middle_east", 34.0, 43.0, "water", "the Black Sea"],
		["middle_east", 38.0, 21.0, "water", "the Red Sea"], ["middle_east", 51.0, 27.5, "water", "the Persian Gulf"],
		["middle_east", 44.0, 42.6, "high", "the Caucasus"], ["middle_east", 48.5, 32.0, "high", "the Zagros"],
		["middle_east", 45.0, 24.0, "land", "Arabia"], ["middle_east", 33.0, 39.0, "land", "Anatolia"],
		["europe", 18.0, 35.0, "water", "the Mediterranean"], ["europe", 19.5, 57.5, "water", "the Baltic"],
		["europe", -2.0, 53.0, "land", "Britain"], ["europe", 10.0, 46.6, "high", "the Alps"], ["europe", -5.0, 47.0, "water", "the Bay of Biscay"],
		["europe", 25.0, 28.0, "land", "the Sahara"],
		["east_asia", 85.0, 28.6, "high", "the Himalaya"], ["east_asia", 88.0, 32.5, "high", "the Tibetan plateau"],
		["east_asia", 134.0, 40.0, "water", "the Sea of Japan"], ["east_asia", 88.0, 15.0, "water", "the Bay of Bengal"],
		["east_asia", 78.5, 22.0, "land", "India"], ["east_asia", 105.0, 45.0, "land", "Mongolia"],
	]
	var built := {}
	for pr in probes:
		var key: String = pr[0]
		if not built.has(key):
			var data: Dictionary = source.duplicate(true)
			Gen.generate(data, key)
			built[key] = data
		var data2: Dictionary = built[key]
		var h: float = height(data2, at(key, float(data2.mapSize), pr[1], pr[2]))
		var ok: bool = (h < -1.0) if pr[3] == "water" else ((h > 6.0) if pr[3] == "high" else h > 0.5)
		check(ok, "%s: %s is %s (%.1f m)" % [Gen.MAPS[key].name, pr[4], {"water": "sea", "high": "high ground", "land": "land"}[pr[3]], h])
	print("\nREAL_MAPS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("REAL_MAPS PASS" if errors.is_empty() else "REAL_MAPS FAIL")
	quit(0 if errors.is_empty() else 1)
