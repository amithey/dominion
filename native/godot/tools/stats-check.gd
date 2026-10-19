extends SceneTree
## National statistics (world_stats.gd, stats_view.gd): a release every 20 seconds for every nation,
## exact figures for you and published estimates for the others (the error shrinking with intelligence,
## the same draw every time it is read), rankings, changes, headlines, the Statistics tab, and saves.
var errors: Array[String] = []
var passed := 0
var w: Node
const Stats := preload("res://scripts/world_stats.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func texts(node: Node, out := []) -> Array:
	for c in node.get_children():
		if c is Label or c is Button: out.append(c.text)
		texts(c, out)
	return out

func run() -> void:
	seed(99)
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("hard"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w, ["costs"])
	var S: RefCounted = w.stats
	check(S != null, "the world has a statistics office")
	Engine.time_scale = 8.0
	var until: float = w.game_time + 10.0 * 60.0
	var guard := 0
	while w.game_time < until and guard < 200000:
		await process_frame
		guard += 1
	Engine.time_scale = 1.0
	w.set_physics_process(false)
	var n: int = w.map.nations.size()
	check(S.series.size() == n, "every nation has a series (%d of %d)" % [S.series.size(), n])
	var length: int = S.series[0].gdp.size()
	check(length >= 25 and length <= 40, "a release every 20 seconds: %d in ten minutes" % length)
	check(Stats.METRICS.all(func(m): return S.series[1][m].size() == length), "every metric is released together")
	# ---- your figures are exact
	var mine: Array = S.series[0].gdp
	check(mine.all(func(s): return is_equal_approx(s.shown, s.real)) and S.series[0].military.all(func(s): return is_equal_approx(s.shown, s.real)), "your own figures are exact")
	check(S.latest(0, "gdp") > 20000.0 and S.latest(0, "gdp") < 40000.0, "your economy starts from the real figure (%s)" % Stats.format("gdp", S.latest(0, "gdp")))
	# ---- the rivals grow, and the published land and technology trail by a release
	var rival: int = 1
	var first: float = S.series[rival].infra[0].real
	var last: float = S.series[rival].infra[-1].real
	check(last > first, "a rival's infrastructure grew (%d to %d)" % [first, last])
	check(S.series[rival].gdp[-1].real > S.series[rival].gdp[0].real, "and so did its economy")
	check(is_equal_approx(S.series[rival].land[-1].shown, S.series[rival].land[-2].real), "land is published one release late")
	check(S.series[rival].tech[-1].real > S.series[rival].tech[0].real, "technology rises")
	# ---- estimates: bounded by what you know, fixed for a given release
	w.espionage.intel[rival] = 0.0
	var e0: float = S.error(rival)
	w.espionage.intel[rival] = 100.0
	var e1: float = S.error(rival)
	check(is_equal_approx(e0, 0.35) and is_equal_approx(e1, 0.05), "the error is 35% with no intelligence and 5% with a full network")
	check(S._noise(2, "military", 7) == S._noise(2, "military", 7) and absf(S._noise(2, "military", 7)) <= 1.0, "an estimate's draw is the same every time")
	var within := true
	for s in S.series[rival].military:
		if s.real > 0.0 and absf(s.shown - s.real) > s.real * 0.351 + 0.01: within = false
	check(within, "every published military figure is within the error bound of the truth")
	# ---- reading
	var ranking: Array = S.ranking("gdp")
	check(ranking.size() == n and ranking[0][1] >= ranking[-1][1], "the ranking is sorted")
	check(absf(S.change(0, "gdp", 120.0)) < 5.0, "changes are fractions")
	check(Stats.format("gdp", 29000.0) == "$29.0 tn" and Stats.format("gdp", 530.0) == "$530 bn" and Stats.format("tech", 3.14) == "3.1" and Stats.format("land", 41.6) == "42", "figures are formatted")
	# ---- the headline
	var H: RefCounted = S
	H._last_headline = -999.0
	for m in ["gdp", "military", "land"]:
		var list: Array = H.series[rival][m]
		list[-1].shown = 1000.0
		for i in range(list.size() - 1):
			list[i].shown = 700.0 if float(list[-1].t) - float(list[i].t) >= 120.0 else 1000.0
	w.game_time = maxf(w.game_time, 300.0)
	var log0: int = w.hud.notice_log.size()
	H._headline()
	check(H.headlines >= 1 and w.hud.notice_log.size() == log0 + 1 and str(w.hud.notice_log[-1]).contains("Statistics:"), "a big move makes a headline: %s" % str(w.hud.notice_log[-1]))
	var again: int = w.hud.notice_log.size()
	H._headline()
	check(w.hud.notice_log.size() == again, "but not two in a row")
	# ---- saves
	var snap: Dictionary = JSON.parse_string(JSON.stringify(S.capture()))
	var fresh: RefCounted = Stats.new(w)
	fresh.restore(snap)
	check(fresh.series.size() == n and fresh.series[0].gdp.size() == length and is_equal_approx(fresh.latest(1, "military"), S.latest(1, "military")), "the series survive a save")
	# ---- the Statistics tab
	var h: Node = w.hud
	h.toggle_panel("diplomacy")
	await process_frame
	h._panels.diplomacy_tab = "stats"
	h.refresh_side()
	await process_frame
	var all := texts(h._side_rows)
	check(all.has("Statistics") and all.has("Economy") and all.has("Military") and all.has("Technology"), "the tab offers the five metrics")
	check(all.any(func(t): return str(t).contains("You")) and all.any(func(t): return str(t).contains("$")), "and lists you with your economy")
	h._panels.stats_metric = "military"
	h.refresh_side()
	await process_frame
	var mil := texts(h._side_rows)
	check(mil.any(func(t): return str(t).contains("±")) and mil.any(func(t): return str(t).contains("estimates")), "military figures for others show their error")
	h._panels.stats_hidden[1] = true
	h.refresh_side()
	await process_frame
	check(texts(h._side_rows).has("show"), "a nation's line can be hidden")
	print("STATS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("STATS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
