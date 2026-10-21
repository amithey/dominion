extends SceneTree
## The aircraft carrier made clear and sound (native/FIXES-2026-10-20.md, 8): the air wing's reach is one number
## (240 m) used everywhere (the selection panel's RANGE, the blue ring, the brief, the stand-off); the wing is shown
## (on deck, flying, rearming, lost); an enemy in reach is struck and one beyond it is not; orders-only mode launches
## only at what you point at; the wing can be recalled; a lost aircraft is replaced for $400 (and waits when the
## money is short); the carrier never sails up to an enemy to use its guns; the wing survives a save (on deck,
## rearming, and the aircraft in the air still fly for their carrier).
var errors: Array[String] = []
var passed := 0
var w: Node
const T := preload("res://scripts/war_tools.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func tick(seconds: float) -> void:
	for i in range(int(seconds / 0.25)):
		w.game_time += 0.25
		T.update(w, 0.25)

func texts(node: Node, out := []) -> Array:
	for c in node.get_children():
		if c is Label or c is Button: out.append(c.text)
		texts(c, out)
	return out

func flying(carrier: Dictionary) -> Array:
	return w.units.filter(func(u): return not u.dead and is_same(u.get("carrier"), carrier))

func run() -> void:
	seed(77)
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false); w.ai.set_physics_process(false)
	for d in w.research.discoveries: w.research.progress[d] = {"stage": 3}
	w.research._recompute()
	w.economy.res.money = 100000.0
	w.diplomacy.declare_war(0, 1)
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var sea: Vector3 = w.water_near(hq, 240)
	check(sea != null and sea != Vector3.ZERO, "the fixture found open sea")
	var carrier: Dictionary = w.spawn_unit("carrier", sea, 0)
	var size: int = T.wing_size(w, carrier)
	var home: Vector3 = carrier.node.position

	# ---- one number for the reach
	check(is_equal_approx(T.STRIKE_REACH, 240.0) and T.standoff(w, carrier) < T.STRIKE_REACH and T.standoff(w, carrier) > 150.0, "the wing's reach is %d m and the carrier stands off inside it (%d m)" % [int(T.STRIKE_REACH), int(T.standoff(w, carrier))])
	check(str(w.unit_defs.carrier.desc).contains("240 m"), "the carrier's description names the reach")
	check(preload("res://scripts/brief.gd").unit(w, "carrier").points.any(func(p): return str(p).contains("240 m")), "and so does its brief")
	carrier.selected = true
	w.hud._update_panel()
	await process_frame
	var plates: Array = texts(w.hud._sel_stats)
	check(plates.has("240 m") and plates.has(str(int(round(float(w.unit_defs.carrierJet.dmg) * w.research.damage_mult(carrier))))), "the panel's RANGE and ATTACK are the wing's, not the guns' (%s)" % str(plates))
	var panel: Array = texts(w.hud._wing_row)
	check(panel.any(func(t): return str(t).begins_with("AIR WING") and str(t).contains("240 m")) and panel.any(func(t): return str(t).contains("%d on deck" % size)), "the selection shows the air wing: %s" % str(panel.slice(0, 2)))
	check(panel.any(func(t): return str(t) == "Launch: automatic") and panel.has("Recall wing"), "with its two buttons")

	# ---- an enemy in reach is struck, one beyond it is not
	var near: Dictionary = w.spawn_unit("destroyer", home + Vector3(200, 0, 0), 1)
	check(near.get("naval", false), "(a rival destroyer 200 m away, inside the reach)")
	tick(1.0)
	check(flying(carrier).size() >= 1 and flying(carrier)[0].enemy != null, "the wing launches at an enemy 200 m away (%d flying)" % flying(carrier).size())
	var info: Dictionary = T.wing_info(w, carrier)
	check(info.aboard + info.flying + info.rearming + info.lost == size and info.flying == flying(carrier).size(), "the wing's numbers add up (%s)" % T.wing_text(w, carrier))
	# recall
	var recalled: int = T.recall(w, carrier)
	check(recalled >= 1 and flying(carrier).all(func(u): return u.air_state == "returning"), "Recall sends every aircraft home (%d)" % recalled)
	for i in range(400):
		for u in flying(carrier): w.AirOperations.update(w, u, 0.1)
		T.update(w, 0.25)
		w.game_time += 0.25
		if flying(carrier).is_empty(): break
	check(flying(carrier).is_empty() and T.wing_info(w, carrier).rearming >= 1, "they land aboard and are rearmed")
	check(w.units.filter(func(u): return not u.dead and is_same(u.get("carrier"), carrier)).is_empty() and T.wing_text(w, carrier).contains("held down"), "and in automatic mode they are held down after the recall (%s)" % T.wing_text(w, carrier))
	w.kill(near)
	w.game_time += T.REARM + T.HOLD + 1.0
	tick(1.0)
	carrier.wing.next = 0.0
	var far: Dictionary = w.spawn_unit("destroyer", home + Vector3(330, 0, 0), 1)
	tick(1.0)
	check(flying(carrier).is_empty() and T.wing_info(w, carrier).aboard == size, "an enemy 330 m away, beyond the reach, is not struck")
	w.kill(far)

	# ---- orders only
	T.set_auto(carrier, false)
	var near2: Dictionary = w.spawn_unit("destroyer", home + Vector3(120, 0, 0), 1)
	tick(2.0)
	check(flying(carrier).is_empty(), "in orders-only mode nothing launches at an enemy it was not told to strike")
	w.order_attack([carrier], near2)
	carrier.wing.next = 0.0
	tick(1.0)
	check(flying(carrier).size() >= 1, "and the wing goes at once at the enemy it was told to strike")
	check(carrier.target == null and Vector2(near2.node.position.x - carrier.node.position.x, near2.node.position.z - carrier.node.position.z).length() <= T.STRIKE_REACH, "the carrier stays where it is: the target is in reach")
	T.set_auto(carrier, true)

	# ---- the carrier does not sail up to its enemy
	w.kill(near2)
	T.recall(w, carrier)
	for i in range(200):
		for u in flying(carrier): w.AirOperations.update(w, u, 0.1)
		T.update(w, 0.25); w.game_time += 0.25
	var distant: Dictionary = w.spawn_unit("destroyer", home + Vector3(380, 0, 0), 1)
	w.order_attack([carrier], distant)
	check(Vector2(distant.node.position.x - carrier.node.position.x, distant.node.position.z - carrier.node.position.z).length() > T.standoff(w, carrier), "(an enemy beyond the stand-off)")
	check(T.standoff(w, carrier) > float(carrier.range) * 4.0, "the stand-off is far beyond the carrier's own guns (%d m against %d m)" % [int(T.standoff(w, carrier)), int(carrier.range)])
	w.kill(distant)
	carrier.enemy = null

	# ---- a lost aircraft is replaced
	var wing: Dictionary = carrier.wing
	wing.aboard = size - 1   # one aircraft was shot down
	wing.rearming = []
	wing.replace_in = T.REPLACE_EVERY
	var money0: float = w.economy.res.money
	check(T.wing_info(w, carrier).lost == 1 and T.wing_text(w, carrier).contains("1 lost"), "a lost aircraft is counted and the panel says when its replacement comes (%s)" % T.wing_text(w, carrier))
	tick(T.REPLACE_EVERY + 1.0)
	check(int(wing.aboard) == size and absf((money0 - w.economy.res.money) - T.REPLACE_COST) < 1.0, "a replacement arrives after %d s and costs $%d" % [int(T.REPLACE_EVERY), int(T.REPLACE_COST)])
	wing.aboard = size - 1
	w.economy.res.money = 0.0
	tick(T.REPLACE_EVERY + 1.0)
	check(int(wing.aboard) == size - 1 and w.hud.notice_log.any(func(t): return str(t).contains("no money for a replacement")), "with no money it waits and says so")
	w.economy.res.money = 10000.0
	tick(12.0)
	check(int(wing.aboard) == size, "and the replacement comes when the money does")

	# ---- the wing survives a save
	var foe: Dictionary = w.spawn_unit("destroyer", home + Vector3(150, 0, 0), 1)
	wing.next = 0.0
	tick(1.0)
	var flying0: int = flying(carrier).size()
	wing.rearming = [w.game_time + 9.0]
	wing.aboard = size - flying0 - 1   # (a consistent wing: the rest on deck, one rearming, the others flying)
	check(flying0 >= 1, "(an aircraft in the air for the save)")
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(w.saves.problem_with(data) == "", "the save passes its own check")
	w.saves.restore(data)
	await process_frame
	var carriers: Array = w.units.filter(func(u): return u.owner == 0 and u.key == "carrier" and not u.dead)
	check(carriers.size() == 1 and carriers[0].has("wing"), "the carrier comes back with its wing")
	if carriers.size() == 1:
		var c2: Dictionary = carriers[0]
		check(int(c2.wing.aboard) == size - flying0 - 1 and c2.wing.rearming.size() == 1 and absf(float(c2.wing.rearming[0]) - (w.game_time + 9.0)) < 1.5, "on deck %d, one rearming in about 9 s" % int(c2.wing.aboard))
		check(flying(c2).size() == flying0, "and the %d aircraft in the air still fly for it" % flying0)
		check(T.wing_info(w, c2).lost == 0, "nothing is counted lost by the load")
	print("CARRIER %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("CARRIER %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
