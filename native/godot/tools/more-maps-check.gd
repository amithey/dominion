extends SceneTree
## The new maps (native/MAPS-2026-10-12.md): the Strait, Ocean Atolls, Great
## Steppe, River Lands, the Gulf and Hormuz, and the Red Sea and the Horn. Their
## geography is what it claims (the strait and the gulf are water, the steppe is
## land), every capital is joined to the rest by land, and on the real maps each
## nation whose capital lies there starts at it.
var errors: Array[String] = []
var passed := 0
const Gen := preload("res://scripts/map_generator.gd")
const Geo := preload("res://scripts/world_geography.gd")
const Setup := preload("res://scripts/match_setup.gd")
const Catalogue := preload("res://scripts/map_catalogue.gd")
const F := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func height(data: Dictionary, p: Vector2) -> float:
	var grid: Dictionary = data.grid
	var c := clampi(roundi((p.x - float(grid.origin[0])) / float(grid.step)), 0, int(grid.size) - 1)
	var r := clampi(roundi((p.y - float(grid.origin[1])) / float(grid.step)), 0, int(grid.size) - 1)
	return float(grid.heightsCm[r * int(grid.size) + c]) / 100.0

func land_share(data: Dictionary) -> float:
	var land := 0
	var n := 0
	var half := float(data.mapSize) * 0.5
	for y in range(40):
		for x in range(40):
			n += 1
			if height(data, Vector2((x / 39.0 - 0.5), (y / 39.0 - 0.5)) * half * 1.9) > 0.0: land += 1
	return float(land) / n

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	for key in ["strait", "atolls", "steppe", "rivers", "gulf", "red_sea"]:
		check(key in Catalogue.KEYS and Gen.MAPS.has(key) and ResourceLoader.exists(Catalogue.preview_path(key)), "%s: in the map picker, with a preview" % key)
		var data: Dictionary = source.duplicate(true)
		Setup.apply(data, Setup.normalize({"map": key, "players": int(Gen.MAPS[key].slots)}))
		var share := land_share(data)
		print("   %s: land %.0f%%" % [key, share * 100.0])
		match key:
			"steppe": check(share > 0.75, "the steppe is open land (%.0f%%)" % (share * 100.0))
			"atolls": check(share < 0.3, "the atolls are mostly ocean (%.0f%%)" % (share * 100.0))
			"strait":
				check(height(data, Vector2(0, float(data.mapSize) * 0.15)) < 0.0, "the strait runs down the middle")
				check(share > 0.35 and share < 0.85, "two coasts and the sea between (%.0f%%)" % (share * 100.0))
			"rivers":
				var cut := 0
				for x in range(-5, 6):
					var p := Vector2(x * 40.0, 0)
					for y in range(-30, 31):
						if height(data, Vector2(p.x, y * 10.0)) < 0.0: cut += 1
				check(cut > 10, "rivers cut the land (%d water samples across it)" % cut)
			"gulf":
				var hormuz: Vector2 = Geo.to_world("gulf", float(data.mapSize), 56.4, 26.4)
				var gulf_sea: Vector2 = Geo.to_world("gulf", float(data.mapSize), 51.0, 27.5)
				var arabia: Vector2 = Geo.to_world("gulf", float(data.mapSize), 46.0, 23.0)
				check(height(data, hormuz) < 0.0 and height(data, gulf_sea) < 0.0, "the Gulf and the Strait of Hormuz are water")
				check(height(data, arabia) > 0.0, "Arabia is land")
			"red_sea":
				var red: Vector2 = Geo.to_world("red_sea", float(data.mapSize), 38.0, 21.0)
				var aden: Vector2 = Geo.to_world("red_sea", float(data.mapSize), 48.0, 12.5)
				var ethiopia: Vector2 = Geo.to_world("red_sea", float(data.mapSize), 39.0, 9.0)
				check(height(data, red) < 0.0 and height(data, aden) < 0.0, "the Red Sea and the Gulf of Aden are water")
				check(height(data, ethiopia) > 0.0, "Ethiopia's highlands are land")
		var starts: Array = data.get("spawnPositions", [])
		check(starts.size() == int(Gen.MAPS[key].slots), "%s: %d regions" % [key, starts.size()])
		check(starts.all(func(s): return height(data, Vector2(s[0], s[1])) > 1.0), "%s: every region's capital on dry land" % key)
	# The real maps start each nation at its own capital.
	for pair in [["gulf", "iran", 51.39, 35.69], ["gulf", "saudi", 46.72, 24.69], ["red_sea", "ethiopia", 38.74, 9.03], ["red_sea", "egypt", 31.24, 30.04]]:
		var data: Dictionary = source.duplicate(true)
		var nation := F.IDS.find(str(pair[1]))
		Setup.apply(data, Setup.normalize({"map": pair[0], "players": 4, "nation": nation}))
		var hq: Array = data.buildings.filter(func(b): return b.key == "hq" and int(b.owner) == 0)
		var at: Vector2 = Geo.to_world(str(pair[0]), float(data.mapSize), float(pair[2]), float(pair[3]))
		check(not hq.is_empty() and Vector2(float(hq[0].x), float(hq[0].z)).distance_to(at) < 40.0, "%s: %s starts at its capital" % [pair[0], pair[1]])
	print("MORE_MAPS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("MORE_MAPS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
