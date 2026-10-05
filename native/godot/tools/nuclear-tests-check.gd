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
	seed(5)
	var d: Node = w.diplomacy
	var nt = w.tests
	var u = w.un

	# ---- a nuclear test
	w.economy.res.uranium = 500.0
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
