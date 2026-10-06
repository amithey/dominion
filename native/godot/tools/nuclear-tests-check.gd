extends SceneTree
## Nuclear tests (nuclear_tests.gd), the nuclear release decision, satellite
## jamming (space.gd), the interface size, and in-game text without dates.
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
	preload("res://tools/test_kit.gd").quiet(w, ["wmd", "un", "defcon", "tests"])
	# Nuclear payloads are built once the Nuclear Program is researched (arsenal_catalog.gd).
	w.research.progress["nuclearProgram"].stage = 3
	w.research._recompute()
	seed(5)
	var d: Node = w.diplomacy
	var nt = w.tests
	var u = w.un

	# ---- a nuclear test
	w.economy.res.uranium = 500.0
	check(nt.blocked("underground").contains("Strategic Weapons Complex"), "a device needs a Strategic Weapons Complex")
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	w.place_building("strategicComplex", w.test_site("strategicComplex", hq0 + Vector3(-60, 0, 60)), 0, true)
	var rel0: float = d.rel(0, 3)
	var pts0: float = w.research.points
	var q0: int = u.queue.size()
	var said: String = nt.conduct(0, "underground")
	check(said.contains("NUCLEAR TEST") and nt.believed(0), "an underground test: your deterrent is believed")
	check(d.rel(0, 3) < rel0 and w.research.points > pts0 and u.queue.size() > q0, "the world condemns it, your scientists learn, and the Council takes it up")
	check(nt.blocked("underground").contains("readied"), "the test site needs time before the next")
	d.set_score(3, 0, -50.0)
	check(not d.ai_wants_war(3, 0), "a rival that dislikes you does not start a war with a proven deterrent")
	nt.deterred.clear()
	check(d.ai_wants_war(3, 0), "without it, it would")
	nt.last.clear()
	var zones0: int = w.wmd.zones.size()
	nt.conduct(0, "atmospheric")
	check(w.wmd.zones.size() == zones0 + 1, "an atmospheric test leaves fallout drifting downwind")
	# A rival that has just broken out proves its bomb.
	w.wmd.break_out(3)
	w.ai.nations.filter(func(n): return n.id == 3)[0].defeated = false
	nt._ai_tick = 60.0
	nt.update(0.0)
	check(int(nt.count.get(3, 0)) == 0, "a rival without a Strategic Weapons Complex cannot test")
	var hq3: Vector3 = w.buildings.filter(func(b): return b.owner == 3 and b.key == "hq")[0].root.position
	var iran_complex: Dictionary = w.place_building("strategicComplex", w.test_site("strategicComplex", hq3 + Vector3(50, 0, -50)), 3, true)
	var tries := 0
	while int(nt.count.get(3, 0)) == 0 and tries < 30:
		nt._ai_tick = 60.0
		nt.update(0.0)
		tries += 1
	check(int(nt.count.get(3, 0)) == 1, "a state that has just broken out tests its bomb")
	# Saving.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snap)
	check(int(w.tests.count.get(0, 0)) == 2, "a save keeps the tests")

	# ---- the nuclear release decision
	w.defcon.posture[0] = 5
	w.missiles.stock["nuke"] = 1
	w.place_building("missileSilo", w.test_site("missileSilo", w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position + Vector3(-50, 0, 40)), 0, true)
	var letters0: int = w.hud._letters.size() + (1 if w.hud._letter_box != null else 0)
	w.begin_missile("nuke")
	var letters1: int = w.hud._letters.size() + (1 if w.hud._letter_box != null else 0)
	check(letters1 > letters0 and w.missile_aim != "nuke", "arming a nuclear missile asks for the order to release it, stating its price")
	var msg: String = w.defcon.authorise_release()
	check(int(w.defcon.posture[0]) == 2 and w.defcon.release_blocked() == "" and msg.contains("DEFCON 2"), "giving the order takes your forces to DEFCON 2 at once")
	w.begin_missile("nuke")
	check(w.missile_aim == "nuke", "and the missile is armed")
	w.missile_aim = ""

	# ---- satellite jamming
	var s = w.space
	w.research.progress["satelliteRecon"] = {"stage": 3}
	w.research._recompute()
	s.sats[1].recon = 2
	s.sats[1].nav = 2
	check(s.can_jam(0) and not s.can_jam(3), "the United States fields satellite jammers; Iran does not")
	w.economy.res.money = 100000.0
	var j: String = s.jam(0, 1)
	check(s.active(1, "recon") == 0 and s.active(1, "nav") == 0 and s.count(1, "recon") == 2, "jamming silences China's satellites without destroying them")
	check(not d.at_war(0, 1) and j.contains("2 minutes"), "for two minutes, and it is no act of war")
	w.game_time += s.JAM_SECONDS + 1.0
	check(s.active(1, "recon") == 2, "then they work again")

	# ---- where weapons are made: the silo, the complex, the laboratory
	var NV := preload("res://scripts/national_variants.gd")
	var ms: Node = w.missiles
	check(NV.builds(w, 0, "strategicComplex") and not NV.builds(w, 0, "specialLab"), "the United States may build a Strategic Weapons Complex, and no Special Weapons Laboratory")
	check(NV.builds(w, 3, "specialLab") and NV.builds(w, 1, "strategicComplex") and not NV.builds(w, 1, "specialLab"), "Iran a laboratory (its incapacitants); China a complex, no laboratory")
	var silo_list: Array = ms.listed_at("missileSilo")
	check(not silo_list.is_empty() and silo_list.all(func(k): return ms.category(k) == "conventional"), "the silo lists only conventional missiles (%d)" % silo_list.size())
	var complex_list: Array = ms.listed_at("strategicComplex")
	check(complex_list.has("nuke") and complex_list.has("bunkerBuster") and complex_list.all(func(k): return ms.category(k) == "nuclear") and not complex_list.has("tsarBomba"), "the complex lists your nuclear warheads only (%d)" % complex_list.size())
	check(ms.listed_at("specialLab").is_empty(), "and the United States has nothing for a laboratory")
	var home2: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var silo_b: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "missileSilo" and not b.dead)
	w.research.progress["nuclearProgram"] = {"stage": 3}
	w.economy.res.money = 100000.0
	w.economy.res.uranium = 500.0
	w.economy.res.silicon = 500.0
	w.economy.res.iron = 500.0
	var at_silo: String = ms.produce(silo_b[0], "nuke") if not silo_b.is_empty() else "made at a Strategic Weapons Complex"
	check(at_silo.contains("Strategic Weapons Complex"), "a nuclear warhead is not made at the silo")
	for b in w.buildings.filter(func(x): return x.owner == 0 and x.key == "strategicComplex" and not x.dead): w.destroy_building(b)   # (the test site's)
	check(ms.capacity("nuclear") == 0, "without a complex there is no room for warheads")
	var complex: Dictionary = w.place_building("strategicComplex", w.test_site("strategicComplex", home2 + Vector3(70, 0, -70)), 0, true)
	var made: String = ms.produce(complex, "nuke")
	check(ms.capacity("nuclear") == 2 and made == "" and complex.queue.size() == 1, "a complex holds two and assembles one (%d; %s)" % [ms.capacity("nuclear"), made])
	ms.stock["nuke"] = 2
	check(ms.stored("conventional") == ms.stored() and ms.stored("nuclear") == 2, "warheads do not take the conventional missiles' room")

	# ---- rivals need their facilities too
	var china: Dictionary = w.ai.nations.filter(func(n): return n.id == 1)[0]
	china.tech = 5.0
	for b in w.buildings.filter(func(x): return x.owner == 1 and x.key == "strategicComplex" and not x.dead): w.destroy_building(b)
	# (its Missile Silo first: the launch platform, ai.pick_building)
	w.place_building("missileSilo", w.test_site("missileSilo", w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0].root.position + Vector3(55, 0, -45)), 1, true)
	check(w.ai.pick_building(china) == "strategicComplex", "a nuclear rival at technology 5 with a silo builds a Strategic Weapons Complex next")
	for sub in w.units.filter(func(x): return x.owner == 1 and x.key == "nuclearSub" and not x.dead): w.kill(sub)
	var fly0: int = ms.flying.size()
	w.defcon._strike(1, "test")
	check(ms.flying.size() == fly0 and not w.wmd.armed(1, "nuclear"), "without a complex or a submarine at sea, it cannot launch a nuclear weapon")
	var hq1: Vector3 = w.buildings.filter(func(b): return b.owner == 1 and b.key == "hq")[0].root.position
	var cn_complex: Dictionary = w.place_building("strategicComplex", w.test_site("strategicComplex", hq1 + Vector3(-60, 0, 50)), 1, true)
	w.defcon._strike(1, "test")
	check(ms.flying.size() == fly0 + 1, "with one, it can")
	cn_complex.last_by = 0
	w.destroy_building(cn_complex)
	check(not w.wmd.armed(1, "nuclear") and w.wmd.zones.any(func(z): return z.at.distance_to(cn_complex.root.position) < 1.0), "destroying it disarms the rival (and scatters a little fissile material)")
	# Your own complex lost: the warheads it held go with it.
	var mine: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "strategicComplex" and not b.dead)[0]
	for b in w.buildings.filter(func(x): return x.owner == 0 and x.key == "strategicComplex" and not x.dead and x != mine): w.destroy_building(b)
	ms.stock["nuke"] = 2
	w.destroy_building(mine)
	check(ms.stored("nuclear") == 0, "your complex destroyed: the warheads in it are lost")

	# ---- the new conventional missiles
	var silo_now: Array = ms.listed_at("missileSilo")
	check(silo_now.has("bunkerMissile") and silo_now.has("antiRadar") and not silo_now.has("thermobaricMissile") and silo_now.size() == 9, "the US silo lists the bunker-buster and anti-radiation missiles (the thermobaric one is Russia's): %d" % silo_now.size())
	var base_hq: Vector3 = w.buildings.filter(func(b): return b.owner == 2 and b.key == "hq")[0].root.position
	var bunker_t: Dictionary = w.place_building("bunker", w.test_site("bunker", base_hq + Vector3(70, 0, 0)), 2, true)
	bunker_t.max_hp = 100000.0
	bunker_t.hp = 100000.0
	ms.impact("bunkerMissile", bunker_t.root.position, 0)
	var dug_hit: float = 100000.0 - bunker_t.hp
	bunker_t.hp = 100000.0
	ms.impact("tactical", bunker_t.root.position, 0)
	var plain_hit: float = 100000.0 - bunker_t.hp
	check(dug_hit > plain_hit * 3.0, "a bunker-buster strikes a bunker far harder than a tactical missile (%d against %d)" % [int(dug_hit), int(plain_hit)])
	var sam: Dictionary = w.place_building("samSite", w.test_site("samSite", base_hq + Vector3(-70, 0, 30)), 2, true)
	sam.max_hp = 100000.0
	sam.hp = 100000.0
	ms.impact("antiRadar", sam.root.position + Vector3(25, 0, 0), 0)
	check(sam.hp < 100000.0 and float(sam.get("disabled_until", 0.0)) > w.game_time, "an anti-radiation missile aimed 25 m off homes on the SAM site and silences it")

	# ---- the interface size
	check(is_equal_approx(w.ui_scale, 0.8) and is_equal_approx(w.get_tree().root.content_scale_factor, 0.8), "the interface is 20% smaller by default")
	w.ui_scale = 0.7
	w.apply_ui_scale()
	check(is_equal_approx(w.get_tree().root.content_scale_factor, 0.7), "and the setting changes it")
	w.ui_scale = 0.8
	w.apply_ui_scale()

	# ---- no dates or one-off events in the game's text
	var dated := []
	var year := RegEx.new()
	year.compile("\\b(1[89][0-9][0-9]|20[0-2][0-9])\\b")
	for key in w.missiles.types():
		if year.search(str(w.missiles.def_of(key).get("desc", ""))) != null: dated.append(key)
	for key in w.map.research.discoveries:
		if year.search(str(w.map.research.discoveries[key].get("desc", ""))) != null: dated.append(key)
	for key in w.unit_defs:
		if year.search(str(w.unit_defs[key].get("desc", ""))) != null: dated.append(key)
	check(dated.is_empty(), "no weapon, unit or discovery description cites a year (%s)" % ", ".join(PackedStringArray(dated)))
	print("\nNUCLEAR_TESTS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("NUCLEAR_TESTS PASS" if errors.is_empty() else "NUCLEAR_TESTS FAIL")
	quit(0 if errors.is_empty() else 1)
