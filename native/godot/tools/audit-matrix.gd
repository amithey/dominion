extends SceneTree
## Audit of nations and maps together (native/ALPHA-1.0-REPORT.md): every one of the 28 nations is played on a map, and
## every one of the 24 maps is played by some nation (28 matches: nation i on map i mod 24, then the maps 24 to 27 get the
## nations that sit last in the roster). For each match: it starts with no error; the capital stands on dry land and is
## linked; the rivals have capitals too; two game minutes at eight times speed run with no script error; the rivals
## build and the player's economy ticks; the match can be saved, passes the save check and loads again. A different
## difficulty is used for each. Table: res://build/audit/matrix.txt
const Kit := preload("res://tools/audit_kit.gd")
const Factions := preload("res://scripts/factions.gd")
const Maps := preload("res://scripts/map_generator.gd")
var K
var w: Node
func _initialize() -> void: call_deferred("run")

func run() -> void:
	K = Kit.new(self, "matrix")
	var maps: Array = ["island", "mirrored"] + Maps.MAPS.keys()
	K.ok("matrix", "maps", "%d maps: %s" % [maps.size(), ",".join(PackedStringArray(maps))])
	var ids: Array = Factions.IDS
	var difficulties := ["easy", "normal", "hard"]
	var runs := maxi(ids.size(), maps.size())
	var from := 0
	var upto := runs
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="): from = int(a.split("=")[1])
		if a.begins_with("--to="): upto = int(a.split("=")[1])
	for i in range(from, mini(upto, runs)):
		var nation: int = i % ids.size()
		var map_key: String = maps[i % maps.size()]
		var label := "%s on %s" % [ids[nation], map_key]
		var capacity: int = preload("res://scripts/match_setup.gd").capacity(map_key)
		var players := clampi(4, 2, capacity)
		K.take_errors()
		var t0 := Time.get_ticks_msec()
		w = await K.boot({"map": map_key, "players": players, "nation": nation}, difficulties[i % 3], true)
		if w == null:
			K.fail("match", label, "did not start")
			continue
		var home_list: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq" and not b.dead)
		if home_list.is_empty():
			K.fail("match", label, "no capital")
			continue
		var home: Vector3 = home_list[0].root.position
		var problems := PackedStringArray()
		if w.height_at(home.x, home.z) < float(w.map.seaLevel) + 0.3: problems.append("the capital is not on dry land")
		if w.map.nations.size() != players: problems.append("%d nations instead of %d" % [w.map.nations.size(), players])
		for n in range(1, w.map.nations.size()):
			if w.buildings.filter(func(b): return b.owner == n and b.key == "hq").is_empty(): problems.append("nation %d has no capital" % n)
		if str(w.diplomacy.name_of(0)).strip_edges() == "": problems.append("the player's nation has no name")
		var units0: int = w.units.size()
		var buildings0: int = w.buildings.size()
		var money0: float = w.economy.res.money
		var rival_buildings0: int = w.buildings.filter(func(b): return b.owner > 0).size()
		Engine.time_scale = 8.0
		var until: float = w.game_time + 120.0
		var guard := 0
		while w.game_time < until and guard < 40000:
			await process_frame
			guard += 1
		Engine.time_scale = 1.0
		if w.game_time < until: problems.append("the game clock stopped at %d s" % int(w.game_time))
		var rival_buildings1: int = w.buildings.filter(func(b): return b.owner > 0 and not b.dead).size()
		if rival_buildings1 <= rival_buildings0: problems.append("the rivals built nothing in two minutes (%d -> %d)" % [rival_buildings0, rival_buildings1])
		if absf(w.economy.res.money - money0) < 0.01 and w.economy.rates.money == 0.0: problems.append("the economy did not tick")
		var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		var why: String = w.saves.problem_with(data)
		if why != "": problems.append("its own save fails the check: " + why)
		var errs: Array = K.take_errors()
		if not errs.is_empty(): problems.append("errors: " + " || ".join(PackedStringArray(errs.slice(0, 2))))
		var seconds: int = (Time.get_ticks_msec() - t0) / 1000
		if problems.is_empty():
			K.ok("match", label, "%s, %d players, capital linked, rivals built %d -> %d, %d s real" % [difficulties[i % 3], players, rival_buildings0, rival_buildings1, seconds])
		else:
			K.fail("match", label, "; ".join(problems))
		if not is_instance_valid(w):
			break
	quit(K.finish())
