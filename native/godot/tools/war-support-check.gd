extends SceneTree
## The home front (war_support.gd): an attacked people rallies, a long war and
## losses wear support down (a democracy far faster than an autocracy), low
## support costs income, output and morale, a weary rival will not start a war,
## and a democracy whose support collapses for two minutes is forced into a
## ceasefire.
var errors: Array[String] = []
var passed := 0
var w: Node
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": Factions.IDS.find("usa"), "style": "standard"})
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
	var s = w.support
	var d: Node = w.diplomacy
	var china: int = -1
	for i in range(1, d.n):
		if Factions.identity(w, i) == "china": china = i
	check(s != null and s.regime(0) == "democracy" and s.value(0) == 60.0 and china > 0 and s.regime(china) == "autocracy" and s.value(china) == 70.0,
		"the United States, a democracy, starts at 60; China, an autocracy, at 70")

	# 1: attacked, a people rallies.
	d.declare_war(china, 0)
	check(is_equal_approx(s.value(0), 72.0) and is_equal_approx(s.value(china), 70.0), "China attacks: the American people rally (60 -> %d); China's support is unmoved" % int(s.value(0)))
	# 2: a long war wears it down, a war of defence half as fast as one of choice.
	var before: float = s.value(0)
	s.step(60.0)
	var defence_loss: float = before - s.value(0)
	var other: int = 1 if china != 1 else 2
	var start_other: float = s.value(0)
	d.declare_war(0, other)
	var aggression: float = start_other - s.value(0)
	check(is_equal_approx(aggression, s.AGGRESSOR), "a democracy that starts a war unprovoked loses %d points at once" % int(aggression))
	d.make_peace(0, china)
	before = s.value(0)
	s.step(60.0)
	var choice_loss: float = before - s.value(0)
	check(choice_loss > defence_loss * 1.8, "a minute of a war of choice costs %.2f points, of a war of defence %.2f" % [choice_loss, defence_loss])
	# 3: a democracy tires far faster than an autocracy.
	d.declare_war(china, other)
	var c0: float = s.value(china)
	var p0: float = s.value(0)
	s.step(100.0)
	check((p0 - s.value(0)) > (c0 - s.value(china)) * 1.8, "in 100 s of war the democracy loses %.1f points, the autocracy %.1f" % [p0 - s.value(0), c0 - s.value(china)])
	# 4: losses.
	var tank: Dictionary = w.units.filter(func(u): return u.owner == 0 and u.key == "tank" and not u.dead)[0]
	before = s.value(0)
	var enemy_before: float = s.value(other)
	w.kill(tank)
	check(is_equal_approx(before - s.value(0), 0.5) and s.value(other) > enemy_before, "a tank lost costs half a point; the enemy takes heart")
	# 5: the effects.
	s.support[0] = 20.0
	s.step(1.0)
	check(s.tier(0) == "Protests" and w.research.bonus("incomePct") <= s.EFFECTS.Protests.incomePct + 0.5 and w.research._bonus.get("prodPct", 0.0) < 0.0,
		"at 20%%: protests, income %d%%, production %d%%" % [int(s.EFFECTS.Protests.incomePct * 100), int(s.EFFECTS.Protests.prodPct * 100)])
	var low_damage: float = w.research.damage_mult(w.units.filter(func(u): return u.owner == 0 and not u.dead)[0])
	s.support[0] = 90.0
	s.step(1.0)
	var high_damage: float = w.research.damage_mult(w.units.filter(func(u): return u.owner == 0 and not u.dead)[0])
	check(s.tier(0) == "Rallied" and high_damage > low_damage and w.research._bonus.get("prodPct", 0.0) >= 0.1 - 0.001, "at 90%%: the nation rallies (production +10%%, damage %.2f against %.2f)" % [high_damage, low_damage])
	w.hud._process(0.3)
	check(w.hud._extra.support[0].text == "90%", "the strip shows war support (%s)" % w.hud._extra.support[0].text)
	# 6: a weary rival will not start a war, and earns less.
	d.make_peace(china, other)
	d.set_score(china, other, -90.0)
	s.support[china] = 30.0
	check(not d.ai_wants_war(china, other) and s.ai_income_mult(china) < 1.0, "a weary China (30) will not start another war, and its income is %d%%" % int(s.ai_income_mult(china) * 100))
	# 7: a democracy in collapse is forced to a ceasefire.
	s.support[0] = 10.0
	s.step(1.0)
	w.game_time += s.CEASEFIRE_AFTER + 1.0
	s.step(1.0)
	check(d.enemies_of(0).is_empty(), "two minutes of collapse: parliament forces a ceasefire")
	before = s.value(0)
	s.step(60.0)
	check(s.value(0) > before, "in peace support recovers (%d -> %d)" % [int(before), int(s.value(0))])
	# 8: saved.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.capture()))
	var keep: float = s.value(china)
	s.support[china] = 0.0
	s.restore(saved)
	check(is_equal_approx(s.value(china), keep), "war support survives a save")
	print("\nWAR_SUPPORT: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("WAR_SUPPORT PASS" if errors.is_empty() else "WAR_SUPPORT FAIL")
	quit(0 if errors.is_empty() else 1)
