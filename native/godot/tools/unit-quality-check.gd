extends SceneTree
## Each nation's own system in a shared unit class (unit_quality.gd): every
## nation that fields a class has its figures and its system's name; a
## third-generation-plus tank outclasses a Cold War one in protection,
## firepower and accuracy; in a match the figures reach the units, the unit
## card shows them, and four Merkava 4s beat four T-64BVs, four T-64BVs four
## captured T-62s, while two equal armies each win some. The M1A2 SEPv3 leads
## the tanks in service; the M1E3 Abrams, researched by the United States
## alone, replaces it with more of everything and its own active protection.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Q := preload("res://scripts/unit_quality.gd")
const V := preload("res://scripts/national_variants.gd")
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func sim(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT

func flat(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

func run() -> void:
	# 1: the table covers every nation that fields each class, with its own name.
	var missing := []
	var unnamed := []
	for cls in Q.QUALITY:
		for i in range(Factions.IDS.size()):
			var id: String = Factions.IDS[i]
			var arsenal: String = Factions.ARSENALS[i]
			if cls != "infantry" and not V.fields(cls, arsenal):
				continue
			if not Q.QUALITY[cls].has(id): missing.append("%s/%s" % [cls, id])
			elif cls != "infantry" and not V.NAMES.get(cls, {}).has(arsenal): unnamed.append("%s/%s" % [cls, id])
	check(missing.is_empty(), "every nation that fields a class has its figures (%d classes)%s" % [Q.QUALITY.size(), "" if missing.is_empty() else " missing " + str(missing)])
	check(unnamed.is_empty(), "and the name of its own system%s" % ("" if unnamed.is_empty() else " unnamed " + str(unnamed)))
	# 2: the generations, in the tank table.
	var t: Dictionary = Q.QUALITY.tank
	var order_ok := true
	for top in ["usa", "israel", "south_korea", "eu"]:
		for stat in range(3):
			order_ok = order_ok and t[top][stat] > t.ukraine[stat] and t.ukraine[stat] > t.afghanistan[stat]
	check(order_ok, "Abrams SEPv3, Merkava 4, K2, Leopard 2A8 > T-64BV > T-62 in protection, firepower and accuracy")
	check(t.ukraine[0] <= t.israel[0] * 0.65 and t.ukraine[2] <= t.israel[2] * 0.65, "a T-64BV has at most 65%% of a Merkava 4's protection and accuracy (%.2f / %.2f, %.2f / %.2f)" % [t.ukraine[0], t.israel[0], t.ukraine[2], t.israel[2]])
	check(Q.of("china", "tank").hp == 1.0 and Q.of("nobody", "tank").hp == 1.0 and Q.of("usa", "himars").damage == Q.of("usa", "mlrs").damage and Q.of("israel", "commando").accuracy == Q.QUALITY.infantry.israel[2],
		"a 4th-generation system keeps the shared figures; HIMARS takes the rocket artillery's, a commando the infantry's")
	check(Q.QUALITY.infantry.afghanistan[0] > 0.75 and Q.QUALITY.infantry.usa[0] < 1.1, "infantry differs half as much as machines (%.2f to %.2f)" % [Q.QUALITY.infantry.afghanistan[0], Q.QUALITY.infantry.usa[0]])

	# 3: a match. You are Israel; your rival's flag is changed for each duel.
	set_meta("match_config", {"map": "pangaea", "players": 3, "nation": Factions.IDS.find("israel"), "style": "sandbox"})
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
	w.effects.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.diplomacy.declare_war(1, 0)
	w.diplomacy.declare_war(1, 2)
	var spot: Vector3 = Vector3.INF
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for k in range(24):
		var c: Vector3 = home + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 24.0) * 150.0
		var dry := true
		for x in range(-60, 61, 10):
			for z in range(-40, 41, 10):
				if w.height_at(c.x + x, c.z + z) < 1.5: dry = false
		if dry:
			spot = c
			break
	check(spot != Vector3.INF, "open dry ground to fight on")
	w.map.nations[1].id = "ukraine"
	var merkava: Dictionary = w.spawn_unit("tank", flat(spot), 0)
	var t64: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(0, 0, 30)), 1)
	var def: Dictionary = w.unit_defs.tank
	check(Factions.identity(w, 1) == "ukraine" and absf(merkava.accuracy - t.israel[2]) < 0.001 and absf(t64.accuracy - t.ukraine[2]) < 0.001,
		"the figures reach the units: accuracy %d%% for the Merkava, %d%% for the T-64BV" % [int(round(merkava.accuracy * 100)), int(round(t64.accuracy * 100))])
	var hp_ratio: float = merkava.max_hp / t64.max_hp
	var dmg_ratio: float = w.research.damage_mult(merkava) / w.research.damage_mult(t64)
	check(hp_ratio > 1.5 and dmg_ratio > 1.25, "the Merkava has %.1fx the T-64BV's health (%d / %d) and hits %.2fx as hard" % [hp_ratio, int(merkava.max_hp), int(t64.max_hp), dmg_ratio])
	check(merkava.speed < float(def.speed) and merkava.speed < t64.speed * 1.01, "the heavy Merkava is the slower (%.1f / %.1f)" % [merkava.speed, t64.speed])
	merkava.selected = true
	w.hud._update_selection()
	var shown: String = w.hud._stat_values["ACCURACY"][1].text
	var attack: String = w.hud._stat_values["ATTACK"][1].text
	check(w.hud._stat_values["ACCURACY"][0].visible and shown == "%d%%" % int(round(t.israel[2] * 100)) and int(attack) > int(def.dmg),
		"the unit card shows accuracy %s and an attack of %s (the shared tank's %d)" % [shown, attack, int(def.dmg)])
	merkava.selected = false
	for u in [merkava, t64]: w.kill(u)

	# 3b: the American tank. The SEPv3 (depleted-uranium armour, Trophy, the M829A4
	# round) stands above the Leopard 2A8, K2 and Merkava 4 in protection and
	# firepower; the M1E3 is a United States-only discovery that replaces it.
	var top_ok := true
	for rival in ["eu", "south_korea", "israel"]:
		top_ok = top_ok and t.usa[0] > t[rival][0] and t.usa[1] > t[rival][1]
	check(top_ok and t.usa[3] < 1.0, "the M1A2 SEPv3 is the best-protected and hardest-hitting tank in service (%d%% health, %d%% firepower), and slower at 78 t" % [int(round(t.usa[0] * 100)), int(round(t.usa[1] * 100))])
	check(w.research.def_of("nextGenAbrams").get("nation", "") == "blue" and w.research.blocker("nextGenAbrams") != "" and Q.upgrade(w, 0, "israel", "tank").is_empty(),
		"the M1E3 discovery is the United States' alone (for Israel: \"%s\")" % w.research.blocker("nextGenAbrams"))
	w.map.nations[0].id = "usa"
	w.map.nations[0].arsenal = "blue"
	var sep: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(-20, 0, 0)), 0)
	check(not sep.get("aps_builtin", false) and V.name_for(w, 0, "tank") == "M1A2 SEPv3 Abrams", "before the research, the United States builds the %s" % V.name_for(w, 0, "tank"))
	w.research.progress["nextGenAbrams"].stage = 3
	w.research._recompute()
	var m1e3: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(-30, 0, 0)), 0)
	var aps: float = preload("res://scripts/modern_warfare.gd").aps_chance(w, m1e3)
	check(w.unit_defs.tank.name == "M1E3 Abrams" and V.name_for(w, 0, "tank") == "M1E3 Abrams", "after it, every new tank is an M1E3 Abrams, by name on the card")
	check(m1e3.max_hp > sep.max_hp * 1.04 and is_equal_approx(m1e3.cooldown / sep.cooldown, 0.8) and m1e3.speed > sep.speed * 1.1 and m1e3.accuracy > sep.accuracy,
		"the M1E3: health %d (SEPv3 %d), reload %.1f s (%.1f, the autoloader), speed %.1f (%.1f, 60 t), accuracy %d%% (%d%%)" % [int(m1e3.max_hp), int(sep.max_hp), m1e3.cooldown, sep.cooldown, m1e3.speed, sep.speed, int(round(m1e3.accuracy * 100)), int(round(sep.accuracy * 100))])
	check(m1e3.get("aps_builtin", false) and aps >= 0.5, "the Iron Fist built in: %d%% of missiles and drones stopped, without the Active Protection discovery" % int(round(aps * 100)))
	w.map.nations[2].id = "usa"
	var rival_us: Dictionary = {}
	for n in w.ai.nations:
		if n.id == 2: rival_us = n
	rival_us.tech = 4.0
	var old_rival: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(-40, 0, 0)), 2)
	rival_us.tech = 8.0
	var new_rival: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(-50, 0, 0)), 2)
	check(not old_rival.get("aps_builtin", false) and new_rival.get("aps_builtin", false) and V.name_for(w, 2, "tank") == "M1E3 Abrams",
		"a rival United States fields the M1E3 once its technology reaches era 4")
	rival_us.tech = 0.0
	w.research.progress["nextGenAbrams"].stage = 0
	w.map.nations[0].id = "israel"
	w.map.nations[0].arsenal = "israel"
	w.research._recompute()
	w.unit_defs.tank.name = V.NAMES.tank.israel
	for u in [sep, m1e3, old_rival, new_rival]: w.kill(u)

	# 4: duels between two rivals (the same difficulty on both sides), four tanks a
	# side, 22 m apart, five rounds each; a mirror match as the control.
	var duels := [["israel", "ukraine", "Merkava 4 against T-64BV", 4], ["ukraine", "afghanistan", "T-64BV against captured T-62", 4], ["saudi", "saudi", "M1A2S against M1A2S (equal)", -1]]
	for duel in duels:
		var wins := 0
		var losses := 0
		var left := []
		for round in range(5):
			seed(round * 7919 + duel[2].length())
			# (the stronger side is rival 2, which shoots second: the weaker gets the edge of the turn order)
			w.map.nations[1].id = duel[1]
			w.map.nations[2].id = duel[0]
			var a := []
			var b := []
			var base: Vector3 = spot + Vector3(0, 0, -20 + round * 8)
			w.game_time = 0.0   # (the rivals keep their national powers for later: a duel of tanks alone)
			if not w.diplomacy.at_war(1, 2): w.diplomacy.declare_war(1, 2)
			for n in w.ai.nations: n.money = 50000.0   # (fuel and shells cost money: war_costs.gd)
			# (in the mirror match the sides swap each round, so the turn order evens out)
			var first := 2 if duel[0] == duel[1] and round % 2 == 1 else 1
			for i in range(4):
				a.append(w.spawn_unit("tank", flat(base + Vector3(-15 + i * 10, 0, -11)), first))
				b.append(w.spawn_unit("tank", flat(base + Vector3(-15 + i * 10, 0, 11)), 3 - first))
			for s in range(90):
				sim(1.0)
				if a.all(func(u): return u.dead) or b.all(func(u): return u.dead): break
			var alive_a: int = a.filter(func(u): return not u.dead).size()
			var alive_b: int = b.filter(func(u): return not u.dead).size()
			left.append("%d-%d" % [alive_b, alive_a])
			if alive_b > alive_a: wins += 1
			elif alive_a > alive_b: losses += 1
			for u in a + b: if not u.dead: w.kill(u)
			sim(2.0)
		if int(duel[3]) > 0:
			check(wins >= int(duel[3]), "%s: %d of 5 won (tanks left %s)" % [duel[2], wins, ", ".join(PackedStringArray(left))])
		else:
			check(wins >= 1 and losses >= 1, "%s: each side wins some (%d won, %d lost: %s)" % [duel[2], wins, losses, ", ".join(PackedStringArray(left))])
	print("\nUNIT_QUALITY: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("UNIT_QUALITY PASS" if errors.is_empty() else "UNIT_QUALITY FAIL")
	quit(0 if errors.is_empty() else 1)
