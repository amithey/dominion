extends SceneTree
## The space layer (space.gd): launches, recon passes through the fog,
## navigation and GPS denial, communications against jamming, early warning,
## anti-satellite missiles and their debris, rivals in orbit, and saving.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["fog"])
	var s = w.space
	var d: Node = w.diplomacy
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	check(s != null and s.total(0) == 0, "the match starts with nothing in orbit")
	check(s.launch_blocked("recon").contains("Satellite Recon"), "a launch needs Satellite Recon first")
	w.research.progress["satelliteRecon"] = {"stage": 3}
	w.research._recompute()
	check(s.launch_blocked("recon").contains("Missile Silo"), "and, for a nation with launchers, a Missile Silo as its pad")
	w.place_building("missileSilo", w.test_site("missileSilo", home + Vector3(-50, 0, 40)), 0, true)
	w.economy.res.silicon = 5000.0
	var money: float = w.economy.res.money
	var said: String = s.launch("recon")
	check(s.count(0, "recon") == 1 and w.economy.res.money < money and said.contains("launch pad"), "a reconnaissance satellite goes up from the silo: \"%s\"" % said)
	# A foreign launch: +50%.
	var own_id = w.map.nations[0].get("id")
	w.map.nations[0].id = "brazil"
	var bought: Dictionary = s.price("recon")
	w.map.nations[0].id = "syria"
	var none: String = s.launch_blocked("recon")
	w.map.nations[0].id = own_id
	check(int(bought.money) == 1350 and int(s.price("recon").money) == 900, "a nation without launchers buys its launch abroad at +50%% ($%d against $%d)" % [int(bought.money), int(s.price("recon").money)])
	check(none.contains("No space programme"), "Syria has no space programme")
	# 1: the recon pass through the fog.
	var rival := 1
	s.watch[0] = rival
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == rival and b.key == "hq")[0]
	w.place_building("barracks", w.test_site("barracks", capital.root.position + Vector3(35, 0, 25)), rival, true)
	var outer: Array = w.buildings.filter(func(b): return b.owner == rival and not b.dead and b.key != "hq" and b.root.position.distance_to(capital.root.position) < s.REVEAL_RADIUS)
	for b in outer: b.seen = false
	w.fog.refresh()
	var dark: bool = not w.fog.watches(capital.root.position)
	var intel_before: float = float(w.espionage.intel.get(rival, 0.0))
	w.game_time += s.PASS_SECONDS + 1.0
	s.update(0.1)
	s.update(0.1)
	check(dark and w.fog.watches(capital.root.position), "a recon pass lifts the fog over the rival's capital")
	check(outer.all(func(b): return b.seen), "and puts its buildings round it on your map (%d)" % outer.size())
	check(float(w.espionage.intel.get(rival, 0.0)) >= intel_before + 3.0 - 0.01, "and adds 3 to your intelligence on it")
	w.game_time += s.REVEAL_SECONDS + 1.0
	s.update(0.1)
	w.fog.refresh()
	check(s.reveals.is_empty() and not w.fog.watches(capital.root.position), "12 s later the fog closes again")
	# 2: navigation.
	var tank: Dictionary = w.units.filter(func(u): return u.owner == 0 and not u.dead)[0]
	s.launch("nav")
	check(is_equal_approx(w.guidance(tank), 1.0), "one navigation satellite is not yet a constellation")
	s.launch("nav")
	check(is_equal_approx(w.guidance(tank), 1.1), "two give guided weapons +10% accuracy")
	var other := -1
	for i in range(1, d.n):
		if not s.GNSS.has(s.ident(i)): other = i
	if other >= 0:
		var foe_unit := {"owner": other}
		var before: float = w.guidance(foe_unit)
		d.declare_war(0, other)
		check(is_equal_approx(before, 1.0) and is_equal_approx(w.guidance(foe_unit), 0.9), "%s, which relies on GPS, loses 10%% at war with the US" % d.name_of(other))
	else:
		check(true, "(every rival here has its own navigation system)")
	# 3: communications.
	s.launch("comms")
	s.launch("comms")
	check(is_equal_approx(w.jam_factor(tank), 0.5), "two communications satellites halve the jamming of your drones")
	# 4: early warning.
	var guard: float = w.research.bonus("interceptPct")
	s.launch("warning")
	check(is_equal_approx(w.research.bonus("interceptPct"), guard + 0.05), "an early-warning satellite adds 5% to interception")
	# 5: anti-satellite.
	s.sats[rival].recon = 2
	check(s.asat_blocked(rival).contains("Anti-Satellite"), "the anti-satellite missile needs its research")
	check(w.map.research.discoveries.has("antiSatellite"), "Anti-Satellite Weapons is a discovery")
	w.research.progress["antiSatellite"] = {"stage": 3}
	w.research._recompute()
	var peace: bool = not d.at_war(0, rival)
	var shot: String = s.fire_asat(0, rival, 0.0)
	check(s.count(rival, "recon") == 1 and s.debris >= 12.0, "it destroys a rival satellite and leaves debris (%d)" % int(s.debris))
	check(peace and d.at_war(0, rival), "and it is an act of war")
	var missed: String = s.fire_asat(0, rival, 0.99)
	check(s.count(rival, "recon") == 1 and missed.contains("missed"), "it can miss (15%)")
	# Debris: satellites struck at random, yours too.
	s.debris = 100.0
	var mine: int = s.total(0)
	for i in range(20): s._orbit_decay()
	check(s.total(0) < mine and s.debris < 100.0, "debris in orbit strikes satellites, yours too (%d of %d left), and slowly falls" % [s.total(0), mine])
	s.debris = 0.0
	# 6: rivals in orbit.
	var r: Dictionary = w.ai.nations.filter(func(n): return n.id == 2)[0]
	r.tech = 9.0
	r.money = 1000000.0
	for i in range(12): s._ai_space()
	check(s.total(2) >= 3, "a rival at technology 9 puts satellites up (%d)" % s.total(2))
	s.watch[2] = 0
	var outpost: Dictionary = w.place_building("barracks", w.test_site("barracks", home + Vector3(30, 0, -30)), 0, true)
	w.game_time += s.PASS_SECONDS + 1.0
	s._pass[2] = 0.0
	s.update(0.1)
	check(outpost.get("known_by", {}).has(2), "and its recon satellite finds your buildings")
	# 7: saving.
	var snap: Dictionary = s.capture()
	var copy = preload("res://scripts/space.gd").new(w)
	copy.restore(JSON.parse_string(JSON.stringify(snap)))
	check(copy.total(0) == s.total(0) and copy.total(2) == s.total(2) and int(copy.watch.get(0, -1)) == int(s.watch.get(0, -1)), "a save keeps what is in orbit and what it watches")
	# 8: the Space tab.
	w.hud.toggle_panel("intel", true)
	w.hud._panels.intel_tab = "space"
	w.hud.refresh_side()
	var texts: Array = w.hud._side_rows.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(texts.any(func(t): return t.begins_with("In orbit:")), "the Intel window has a Space tab")
	print("\nSPACE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("SPACE PASS" if errors.is_empty() else "SPACE FAIL")
	quit(0 if errors.is_empty() else 1)
