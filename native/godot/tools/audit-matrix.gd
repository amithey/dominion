extends SceneTree
## Runs one campaign for each registered nation and each playable map, pairing them in roster order.
## Confirms capital placement, economy and rival activity, then checks and reloads a JSON save.
## The default plays two game minutes per campaign. Shorter runs still exercise save and load.
## Report: res://build/audit/matrix.txt
const Kit := preload("res://tools/audit_kit.gd")
const Factions := preload("res://scripts/factions.gd")
const Maps := preload("res://scripts/map_generator.gd")
var K
var w: Node
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var report := "matrix"
	var seconds_to_play := 120.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="): report = a.split("=")[1].validate_filename()
		if a.begins_with("--seconds="): seconds_to_play = clampf(float(a.split("=")[1]), 1.0, 120.0)
	K = Kit.new(self, report)
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
		if Factions.identity(w, 0) != ids[nation]: problems.append("selected nation did not become the player")
		if w.height_at(home.x, home.z) < float(w.map.seaLevel) + 0.3: problems.append("the capital is not on dry land")
		if w.map.nations.size() != players: problems.append("%d nations instead of %d" % [w.map.nations.size(), players])
		for n in range(1, w.map.nations.size()):
			if w.buildings.filter(func(b): return b.owner == n and b.key == "hq").is_empty(): problems.append("nation %d has no capital" % n)
		if str(w.diplomacy.name_of(0)).strip_edges() == "": problems.append("the player's nation has no name")
		var money0: float = w.economy.res.money
		var rival_buildings0: int = w.buildings.filter(func(b): return b.owner > 0).size()
		Engine.time_scale = 8.0
		var until: float = w.game_time + seconds_to_play
		var guard := 0
		while w.game_time < until and guard < 40000:
			await process_frame
			guard += 1
		Engine.time_scale = 1.0
		if w.game_time < until: problems.append("the game clock stopped at %d s" % int(w.game_time))
		var rival_buildings1: int = w.buildings.filter(func(b): return b.owner > 0 and not b.dead).size()
		if seconds_to_play >= 120.0 and rival_buildings1 <= rival_buildings0: problems.append("the rivals built nothing in two minutes (%d -> %d)" % [rival_buildings0, rival_buildings1])
		if absf(w.economy.res.money - money0) < 0.01 and w.economy.rates.money == 0.0: problems.append("the economy did not tick")
		var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		var why: String = w.saves.problem_with(data)
		if why != "":
			problems.append("its own save fails the check: " + why)
		else:
			w.saves.restore(data)
			if Factions.identity(w, 0) != ids[nation] or not is_equal_approx(w.game_time, float(data.game_time)):
				problems.append("reload did not preserve the nation and match clock")
			if w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq" and not b.dead).size() != home_list.size():
				problems.append("reload changed the number of player capitals")
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
