extends SceneTree
## Stage 5: veterancy (veterancy.gd), generals with traits (generals.gd) and
## the nuclear escalation ladder (defcon.gd), with saving and the Defence window.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

## The damage `source` does to a fresh enemy tank with `amount`.
func hit(source: Dictionary, amount: float, at: Vector3, owner := 1) -> float:
	var t: Dictionary = w.spawn_unit("tank", ground(at), owner)
	var before: float = t.hp
	w.damage(t, amount, source)
	var dealt: float = before - t.hp
	w.kill(t)
	return dealt

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
	preload("res://tools/test_kit.gd").quiet(w, ["events", "generals", "defcon"])
	seed(7)
	var V := preload("res://scripts/veterancy.gd")
	var d: Node = w.diplomacy
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var field: Vector3 = home + Vector3(-60, 0, 50)

	# ---- veterancy
	var tank: Dictionary = w.spawn_unit("tank", ground(field), 0)
	check(V.rank(tank) == 0 and float(tank.get("xp", 0.0)) == 0.0, "a new tank is a Regular with no experience")
	var plain: float = hit(tank, 100.0, field + Vector3(12, 0, 0))
	check(float(tank.get("xp", 0.0)) > 0.0, "damage dealt earns experience (%d)" % int(tank.get("xp", 0.0)))
	var victim: Dictionary = w.spawn_unit("tank", ground(field + Vector3(14, 0, 0)), 1)
	var xp0: float = float(tank.xp)
	w.damage(victim, victim.hp * 3.0, tank)
	check(victim.dead and float(tank.xp) - xp0 >= victim.max_hp * V.KILL_SHARE, "a kill adds half the victim's health in experience")
	V.add(w, tank, tank.max_hp * 1.0)
	check(V.rank(tank) >= 1 and w.hud.notice_log.any(func(l): return str(l).contains("PROMOTED")), "it is promoted, and told (%s)" % V.rank_name(tank))
	V.set_xp(tank, tank.max_hp * 1.0)
	var veteran: float = hit(tank, 100.0, field + Vector3(12, 0, 0))
	check(is_equal_approx(snappedf(veteran / plain, 0.01), 1.1), "a Veteran deals 10%% more (%.1f against %.1f)" % [veteran, plain])
	var hero: Dictionary = w.spawn_unit("tank", ground(field + Vector3(0, 0, 10)), 0)
	V.set_xp(hero, hero.max_hp * 6.0)
	var enemy: Dictionary = w.spawn_unit("tank", ground(field + Vector3(20, 0, 10)), 1)
	var before: float = hero.hp
	w.damage(hero, 100.0, enemy)
	var taken: float = before - hero.hp
	var regular: Dictionary = w.spawn_unit("tank", ground(field + Vector3(0, 0, 20)), 0)
	before = regular.hp
	w.damage(regular, 100.0, enemy)
	check(V.rank_name(hero) == "Heroic" and is_equal_approx(snappedf(taken / (before - regular.hp), 0.01), 0.8), "a Heroic tank takes 20% less damage")
	hero.last_hit = w.game_time - 20.0
	var hp0: float = hero.hp
	V.update(w, 10.0)
	check(hero.hp > hp0, "and patches itself up out of combat (%d to %d)" % [int(hp0), int(hero.hp)])
	w.kill(enemy)
	w.kill(regular)

	# ---- generals
	var g = w.generals
	check(g != null and g.candidates.size() == 3, "three candidates for the general staff")
	w.economy.res.money = 100000.0
	var money: float = w.economy.res.money
	var hired: String = g.hire(0)
	check(g.of(0).size() == 1 and w.economy.res.money < money, "appointing one costs money: \"%s\"" % hired.left(60))
	var gen: Dictionary = g.of(0)[0]
	gen.traits = ["spearhead", "fortress"]
	var cmd: Dictionary = w.spawn_unit("tank", ground(field + Vector3(-30, 0, 0)), 0)
	check(g.assign(gen, cmd).contains("takes command") and cmd.has("general"), "the general takes command from a tank")
	var near: Dictionary = w.spawn_unit("tank", ground(field + Vector3(-20, 0, 0)), 0)
	var far: Dictionary = w.spawn_unit("tank", ground(home + Vector3(150, 0, -150)), 0)
	check(is_equal_approx(g.damage_mult(near), 1.15) and is_equal_approx(g.damage_mult(far), 1.0), "Armoured Spearhead: a tank 10 m away deals +15%, one far off does not")
	check(is_equal_approx(g.taken_mult(near), 0.88), "Defensive Genius: it takes 12% less damage")
	var jet: Dictionary = w.spawn_unit("jet", ground(home + Vector3(100, 0, 100)), 0)
	gen.traits = ["airpower", "fortress"]
	check(is_equal_approx(g.damage_mult(jet), 1.15) and is_equal_approx(g.damage_mult(near), 1.0), "Air Power reaches the whole air force, and only aircraft")
	gen.traits = ["spearhead", "fortress"]
	for i in range(8):
		var foe: Dictionary = w.spawn_unit("tank", ground(field + Vector3(-10, 0, 8)), 1)
		w.damage(foe, foe.hp * 5.0, near)
	check(int(gen.kills) == 8 and int(gen.level) == 2 and is_equal_approx(g.damage_mult(near), 1.1875), "8 kills under command: level 2, traits +25%")
	var rivals_ok := true
	for n in w.ai.nations:
		if g.of(int(n.id)).size() != 2: rivals_ok = false
	g._ai_next = 0.0
	g._ai_staff()
	var rival_cmd: int = g.roster.filter(func(x): return x.alive and int(x.owner) > 0 and x.unit != null).size()
	check(rivals_ok and rival_cmd > 0, "every rival keeps two generals, at the head of its strongest units (%d in command)" % rival_cmd)
	var rival := 1
	var senior: int = g.of(rival).size()
	var killed: String = g.assassinated(rival)
	check(killed != "" and g.of(rival).size() == senior - 1, "an assassination kills a rival's senior general (%s)" % killed)
	# Saving.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snap)
	g = w.generals
	var back: Array = g.of(0)
	var carrier: Array = w.units.filter(func(u): return not u.dead and u.owner == 0 and u.has("general"))
	var vets: Array = w.units.filter(func(u): return not u.dead and u.owner == 0 and V.rank(u) == 3)
	check(back.size() == 1 and int(back[0].level) == 2 and carrier.size() == 1 and back[0].unit == carrier[0], "a save keeps the general, their level and their command")
	check(not vets.is_empty(), "and the units' experience (a Heroic tank)")
	# The general's unit destroyed.
	var gone: Dictionary = back[0]
	w.kill(carrier[0])
	check(gone.unit == null and (not gone.alive or float(gone.wounded_until) > w.game_time), "the unit carrying a general destroyed: the general is %s" % ("killed" if not gone.alive else "wounded"))

	# ---- DEFCON
	var dc = w.defcon
	check(dc != null and dc.level() == 5, "the world starts at DEFCON 5")
	var nuke_rival := -1
	for i in range(1, d.n):
		if dc.nuclear(i) and nuke_rival < 0: nuke_rival = i
	check(dc.nuclear(0) and nuke_rival > 0, "the United States and %s are nuclear powers" % (d.name_of(nuke_rival) if nuke_rival > 0 else "no rival"))
	if not d.at_war(0, nuke_rival): d.declare_war(0, nuke_rival)
	for i in range(6): dc.update(2.0)
	check(dc.level() == 3, "two nuclear powers at war: DEFCON 3 (%s)" % dc.cause())
	w.missiles.stock["nuke"] = 1
	var blocked: String = w.missiles.launch("nuke", home + Vector3(300, 0, 0))
	check(blocked.contains("posture 2") and int(w.missiles.stock.nuke) == 1, "a nuclear missile cannot be released at posture 5")
	var bystander := -1
	for i in range(1, d.n):
		if i != nuke_rival and not d.at_war(0, i) and bystander < 0: bystander = i
	var rel0: float = d.rel(0, bystander)
	dc.raise_posture()
	dc.raise_posture()
	dc.raise_posture()
	w.research._recompute()
	check(int(dc.posture[0]) == 2 and dc.release_blocked() == "" and d.rel(0, bystander) < rel0, "raised to posture 2 (mobilised): release authorised, relations fall")
	check(is_equal_approx(w.research.bonus("prodPct"), 0.2) or w.research.bonus("prodPct") >= 0.2, "mobilisation: production +20%")
	for i in range(4): dc.update(2.0)
	check(dc.level() == 2, "the world is at DEFCON 2")
	w.events.evaluate()
	check(w.events.active.has("nuclear"), "and the markets shake: the Nuclear crisis event")
	check(dc.deterrent(0), "a stored nuclear missile is a deterrent")
	# The player's nuclear strike on a nuclear power: DEFCON 1, a second strike.
	var their_hq: Dictionary = w.buildings.filter(func(b): return b.owner == nuke_rival and b.key == "hq")[0]
	w.missiles.impact("nuke", their_hq.root.position, 0)
	check(dc.level() == 1, "a nuclear weapon used: DEFCON 1")
	var answered: bool = dc.retaliation.has(nuke_rival)
	if not answered:
		dc.retaliation[nuke_rival] = w.game_time   # (20% of the time it does not answer)
	w.game_time += 45.0
	var flying: int = w.missiles.flying.size()
	dc.update(0.1)
	check(w.missiles.flying.size() == flying + 1 and preload("res://scripts/wmd.gd").is_nuclear(str(w.missiles.flying[-1].type)) and int(w.missiles.flying[-1].owner) == nuke_rival, "%s strikes back with a nuclear missile (%s)" % [d.name_of(nuke_rival), str(w.missiles.flying[-1].type)])
	# A rival fighting for its survival.
	their_hq.hp = their_hq.max_hp * 0.3
	check(dc.existential(nuke_rival), "a nuclear power with its capital half destroyed fights for its survival")
	dc._ai_nuclear()
	check(int(dc.posture[nuke_rival]) == 2, "and goes to posture 2")
	# Saving.
	var snap2: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snap2)
	check(int(w.defcon.posture[0]) == 2 and w.defcon.level() == 1, "a save keeps the posture and the DEFCON")

	# ---- the Defence window and the top bar
	w.hud.show()
	for tab in ["generals", "veterans", "nuclear"]:
		w.hud.toggle_panel("defence", true)
		w.hud._panels.defence_tab = tab
		w.hud.refresh_side()
		check(w.hud._side_rows.get_child_count() >= 2, "the Defence window's %s tab" % tab)
	w.hud._process(0.5)
	check(str(w.hud._extra.defcon[0].text) == "DEFCON 1", "the top bar shows DEFCON 1")
	print("\nSTAGE5: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("STAGE5 PASS" if errors.is_empty() else "STAGE5 FAIL")
	quit(0 if errors.is_empty() else 1)
