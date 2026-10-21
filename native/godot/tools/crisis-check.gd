extends SceneTree
## National crises (crisis.gd, native/CRISES-2026-10-20.md): destroying a nation's power stations, farms, homes and
## industry throws it into recession or depression, an energy and a food crisis, displacement, inflation, debt and a
## falling rating, a political crisis and at last the fall (or the crackdown) of its government; the striker of homes
## and power is condemned; the player's own crises cost bonuses and end on rebuilding; GDP in the statistics follows
## what stands (no floor); the UN's refugee agency appeals; saves keep it all; the overview lists it.
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

func hq_of(id: int) -> Vector3:
	return w.buildings.filter(func(b): return b.owner == id and b.key == "hq")[0].root.position

func build(key: String, owner: int, near: Vector3, i: int) -> Dictionary:
	var at: Vector3 = near + Vector3(-60 + (i % 6) * 22, 0, 40 + int(i / 6) * 22)
	at.y = w.height_at(at.x, at.z)
	return w.place_building(key, at, owner, true)

func pass_time(seconds: float) -> void:
	var C: RefCounted = w.crisis
	var t := 0.0
	while t < seconds:
		w.game_time += 2.0
		C.step(2.0)
		t += 2.0

func run() -> void:
	seed(31)
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w, ["crisis", "support", "un"])
	w.set_physics_process(false); w.ai.set_physics_process(false)
	var C: RefCounted = w.crisis
	check(C != null, "the world keeps a record of national crises")
	var rival := 1
	var F := preload("res://scripts/factions.gd")
	print("rival: ", F.identity(w, rival), " (", w.support.regime(rival), "), you: ", F.identity(w, 0))

	# ---- a developed rival economy
	var keys := ["powerPlant", "powerPlant", "farm", "farm", "farm", "farm", "residential", "residential", "residential", "residential",
		"market", "market", "chipFab", "techPark", "hospital", "school", "warehouse", "oilRefinery"]
	var made := []
	var home: Vector3 = hq_of(rival)
	for i in range(keys.size()):
		made.append(build(keys[i], rival, home, i))
	pass_time(20.0)
	w.stats.release()
	var gdp0: float = w.stats.series[rival].gdp[-1].real
	var infl0: float = float(C.of(rival).inflation)
	var debt0: float = float(C.of(rival).debt)
	var rating0: float = C.rating_score(rival)
	check(C.list(rival).is_empty(), "a rival at peace with its economy standing has no crisis")
	check(gdp0 > 0.5 * float(Stats.BASE_GDP.get(F.identity(w, rival), 500)), "its GDP is near its real-world figure (%s)" % Stats.format("gdp", gdp0))
	check(is_equal_approx(C.ai_income_mult(rival), 1.0), "and its income is untouched")

	# ---- war, and its power, food, homes and industry destroyed by you
	w.diplomacy.declare_war(0, rival)
	var notes0: int = w.hud.notice_log.size()
	var rel0: float = w.diplomacy.rel(0, 2)
	for b in made:
		if b.key in ["market", "school", "warehouse"] or (b.key == "residential" and is_same(b, made[9])):
			continue
		b.last_by = 0
		w.destroy_building(b)
	check(float(C.of(rival).displaced) > 0.0, "people are driven from their homes (%d thousand)" % int(C.of(rival).displaced))
	check(C.active(0, "isolation"), "the striker of homes, power stations and hospitals is condemned")
	check(w.diplomacy.rel(0, 2) < rel0, "and the nations not at war with you think less of you (%d to %d)" % [int(rel0), int(w.diplomacy.rel(0, 2))])
	check(w.hud.notice_log.slice(notes0).any(func(t): return str(t).contains("CRISIS: International condemnation")), "you are told why")
	check(float(C.bonuses().get("incomePct", 0.0)) < 0.0, "condemnation costs you trade")
	pass_time(30.0)
	for kind in ["depression", "energy", "food", "humanitarian"]:
		check(C.active(rival, kind), "the rival is in crisis: %s" % C.KINDS[kind].title.to_lower())
	check(not C.active(rival, "recession"), "a depression replaces a recession")
	check(C.ai_income_mult(rival) < 0.7, "its income falls under its crises (x%.2f)" % C.ai_income_mult(rival))
	check(w.hud.notice_log.slice(notes0).any(func(t): return str(t).contains("World news:")), "the world's news reports it")
	pass_time(120.0)
	check(float(C.of(rival).inflation) > infl0 + 10.0, "its inflation rises (%.1f%% to %.1f%%)" % [infl0, float(C.of(rival).inflation)])
	check(float(C.of(rival).unemployment) > float(C.base_of(rival)[1]) + 10.0, "and unemployment (%.1f%%)" % float(C.of(rival).unemployment))
	check(float(C.of(rival).debt) > debt0, "and its debt (%d%% to %d%% of GDP)" % [int(debt0), int(C.of(rival).debt)])
	check(C.rating_score(rival) < rating0 - 10.0, "its credit rating falls (%s to %s)" % [C.rating_letters(rating0), C.rating(rival)])
	check(C.fragility(rival) > float(C.base_of(rival)[4]) + 20.0, "the state grows fragile (%.0f, usually %.0f)" % [C.fragility(rival), float(C.base_of(rival)[4])])
	w.stats.release()
	check(w.stats.crises(rival).is_empty() and not w.stats.crises(0).has("x"), "a rival's crises are published a release late (none yet shown for %s)" % F.identity(w, rival))
	var gdp1: float = w.stats.series[rival].gdp[-1].real
	check(gdp1 < gdp0 * 0.35, "its GDP collapses with what was destroyed (%s to %s): there is no floor" % [Stats.format("gdp", gdp0), Stats.format("gdp", gdp1)])
	var support0: float = w.support.value(rival)
	pass_time(240.0)
	check(w.support.value(rival) < support0 or w.support.value(rival) <= 1.0, "the crises drain its people's support for the war")
	var fell: bool = C.active(rival, "collapse") or float(C.of(rival).fell_at) > 0.0
	check(fell, "past what a government can bear, it falls or cracks down (pressure %.0f)" % float(C.of(rival).pressure))
	if w.support.regime(rival) != "autocracy":
		check(not w.diplomacy.at_war(0, rival), "a fallen democratic or hybrid government signs a ceasefire")
	else:
		check(w.diplomacy.at_war(0, rival), "an autocracy cracks down and fights on")

	# ---- the UN's refugee agency appeals for the displaced
	w.economy.res.food = 9000.0
	w.economy.cold = false
	w.un.agencies.appeals.clear()
	if C.active(rival, "humanitarian"):
		w.un.agencies._open_appeal()
		check(w.un.agencies.appeals.any(func(a): return int(a.nation) == rival and a.kind == "refugees"), "UNHCR appeals for the rival's displaced")

	# ---- your own power stations destroyed: an energy crisis, its cost, and recovery when rebuilt
	var mine := []
	var you: Vector3 = hq_of(0)
	for i in range(3):
		mine.append(build("powerPlant", 0, you, 20 + i))
	pass_time(10.0)
	var prod0: float = w.research.bonus("prodPct")
	notes0 = w.hud.notice_log.size()
	for b in mine:
		w.destroy_building(b)
	pass_time(2.0)
	check(not C.active(0, "energy"), "a crisis waits a few seconds for its cause to hold")
	pass_time(8.0)
	check(C.active(0, "energy"), "your power stations destroyed: an energy crisis")
	check(w.research.bonus("prodPct") < prod0 - 0.1, "blackouts slow your factories (production %+d%% to %+d%%)" % [int(prod0 * 100), int(w.research.bonus("prodPct") * 100)])
	check(w.hud.notice_log.slice(notes0).any(func(t): return str(t).contains("CRISIS: Energy crisis")), "and you are told what it does")
	w.hud.toggle_cabinet()
	await process_frame
	await process_frame
	check(texts(w.hud._cabinet).any(func(t): return str(t).contains("CRISIS: Energy crisis")), "and the Cabinet lists it among the world news")
	w.hud.toggle_cabinet()
	for i in range(3):
		build("powerPlant", 0, you, 26 + i)
	pass_time(10.0)
	check(not C.active(0, "energy"), "rebuilt, the energy crisis ends")
	check(w.hud.notice_log.any(func(t): return str(t).contains("Recovery: the energy crisis is over")), "with a word of recovery")
	check(is_equal_approx(w.research.bonus("prodPct"), prod0), "and the factories run as before")

	# ---- what you demolish yourself is a choice, not a loss
	var shops := []
	for i in range(4):
		shops.append(build("chipFab", 0, you, 30 + i))
	pass_time(20.0)
	for b in shops:
		w.demolish(b, true)
	pass_time(20.0)
	check(not C.active(0, "recession") and not C.active(0, "depression"), "demolishing your own factories is no recession")

	# ---- the sitrep files a crisis under the economy
	w.sitrep.from_notice("CRISIS: Recession. Output has fallen.")
	check(w.sitrep.events.any(func(e): return e.cat == "econ" and str(e.text).begins_with("CRISIS")), "the situation report files a crisis under the economy")

	# ---- the rating is a published series too
	w.stats.release()
	check(w.stats.series[rival].has("rating") and w.stats.latest(rival, "rating") < w.stats.series[rival].rating[0].shown, "the markets' rating of the rival fell, as published (%s to %s)" % [Stats.format("rating", w.stats.series[rival].rating[0].shown), Stats.format("rating", w.stats.latest(rival, "rating"))])
	# ---- saves
	var snap: Dictionary = JSON.parse_string(JSON.stringify(C.capture()))
	var fresh: RefCounted = preload("res://scripts/crisis.gd").new(w)
	fresh.restore(snap)
	check(fresh.list(rival) == C.list(rival) and is_equal_approx(float(fresh.of(rival).debt), float(C.of(rival).debt)), "crises and indicators survive a save")

	# ---- the statistics: new indicators and the overview
	w.stats.release()
	for m in ["inflation", "unemployment", "debt", "milex", "fragility", "displaced", "energy", "growth"]:
		check(w.stats.series[rival].has(m) and not w.stats.series[rival][m].is_empty(), "the statistics publish %s" % Stats.TITLES[m].to_lower())
	check(w.stats.latest(rival, "growth") < 0.0 or w.stats.series[rival].gdp.size() < 3, "the rival's growth is negative")
	var h: Node = w.hud
	h.toggle_panel("diplomacy")
	await process_frame
	h._panels.diplomacy_tab = "stats"
	h._panels.stats_metric = "overview"
	h.refresh_side()
	await process_frame
	var all := texts(h._side_rows)
	check(all.has("Nations at a glance"), "the overview table is shown")
	check(all.any(func(t): return str(t).contains("Depression") or str(t).contains("Energy crisis")), "with each nation's crises")
	check(all.any(func(t): return str(t) in ["AAA", "AA", "A", "BBB", "BB", "B", "CCC", "CC", "C", "D"]), "and its credit rating")
	h._panels.stats_metric = "growth"
	h.refresh_side()
	await process_frame
	check(texts(h._side_rows).any(func(t): return str(t).contains("Growth")), "a growth chart (below zero too)")
	for t in w.hud.notice_log:
		if str(t).contains("CRISIS") or str(t).contains("World news") or str(t).contains("Recovery"): print("  msg: ", t)
	print("CRISIS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("CRISIS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
