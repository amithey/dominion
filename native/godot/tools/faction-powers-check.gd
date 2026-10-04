extends SceneTree
## The five newer factions' weapons (faction_arsenal.gd) and every faction's
## political power (faction_powers.gd): each weapon is built, fielded only by
## its nation and does what it is for; each power does what it says, costs
## what it costs, recharges, wears off, is used by rival nations too, reaches
## the player's economy, and shows on the Diplomacy screen.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 30.0
const FA := preload("res://scripts/faction_arsenal.gd")
const FP := preload("res://scripts/faction_powers.gd")
const Modern := preload("res://scripts/modern_warfare.gd")
## Each arsenal key and a flag colour for it (factions.gd's where it has one).
const FLAGS := {"blue": "#3b82f6", "red": "#e0483e", "green": "#33b86e", "gold": "#e8a83a",
	"russia": "#9868d9", "india": "#ed7938", "japan": "#da79af", "turkiye": "#28b9ab", "israel": "#8fbce6"}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)
func settle(seconds: float) -> void:
	for i in range(int(seconds / DT)):
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
func dry(at: Vector3) -> Vector3:
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 22.0, 30.0]:
		for i in range(12 if r > 0.0 else 1):
			var a := i * TAU / 12.0
			var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
				p.y = w.height_at(p.x, p.z)
				return p
	return w.land_point(at, 20.0)
## Makes `owner` play the nation with arsenal `key`.
func play_as(owner: int, key: String) -> void:
	var factions = preload("res://scripts/factions.gd")
	w.map.nations[owner].id = factions.IDS[factions.ARSENALS.find(key)]
	w.map.nations[owner].color = FLAGS[key]
	w.map.nations[owner].arsenal = key
func rate(defender: Dictionary, type: String, owner: int, trials: int) -> float:
	var at: Vector3 = defender.node.position + Vector3(10, 30, 0)
	var stopped := 0
	for i in range(trials):
		var m := {"type": type, "owner": owner, "arc": w.missiles.def_of(type).get("arc", false)}
		for f: float in [0.6, 0.7, 0.8, 0.9]:
			for d in Modern.defenders(w):
				d.ent.intercept_ready = 0.0
				d.ent.aa_reload = 0.0
			if Modern.intercept(w, m, at, f):
				stopped += 1
				break
	w.intercepts.clear()
	return float(stopped) / trials

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260928)
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	w.diplomacy.declare_war(0, 1)
	var saved_flag: String = w.map.nations[0].color
	var sea: Vector3 = w.water_near(w.start, 220)
	var field: Vector3 = dry(w.start + Vector3(-120, 0, 120))

	# ================================================================ the weapons
	var home_of := {}
	for b in FA.TRAINS:
		for k in FA.TRAINS[b]: home_of[k] = b
	for key in FA.UNITS:
		var def: Dictionary = w.unit_defs[key]
		var u: Dictionary = w.spawn_unit(key, sea if def.naval else field, 0)
		check(u.node.get_child_count() > 0 and key in w.building_defs[home_of[key]].trains, "%s is built with a model and trained at the %s" % [def.name, home_of[key]])
		play_as(0, def.nation)
		var mine: bool = w.unit_allowed(0, key)
		play_as(0, "blue" if def.nation != "blue" else "red")
		check(mine and not w.unit_allowed(0, key) and w.research.unit_locked(key).ends_with("only"), "%s is fielded only by %s" % [def.name, FA.NAMES[def.nation]])
		w.kill(u)
	w.map.nations[0].color = saved_flag
	w.map.nations[0].erase("arsenal")
	# TOS-1A: thermobaric rockets flatten a squad and ignore cover.
	var tos: Dictionary = w.spawn_unit("tos1a", field, 0)
	var squad := []
	for i in range(5): squad.append(w.spawn_unit("soldier", dry(field + Vector3(26 + (i % 3) * 2.0, 0, (i / 3) * 2.0)), 1))
	w.fire_weapon(tos, squad[0], "thermobaric")
	settle(2.5)
	check(squad.filter(func(s): return s.dead).size() >= 3, "a TOS-1A salvo wipes out most of a squad (%d of 5 dead)" % squad.filter(func(s): return s.dead).size())
	check(preload("res://scripts/bunker.gd").cover(w, squad[0], tos) == 1.0, "and no bunker gives cover from it")
	w.kill(tos)
	# BrahMos: a Mach 3 missile few defences stop; twice as deadly to ships.
	var bat: Dictionary = w.spawn_unit("brahmos", field, 0)
	var n0: int = w.missiles.flying.size()
	var target_b: Dictionary = w.place_building("barracks", dry(field + Vector3(100, 0, 0)), 1, true)
	w.fire_weapon(bat, target_b, "brahmos")
	check(w.missiles.flying.size() == n0 + 1 and w.missiles.flying[-1].type == "brahmos", "a BrahMos battery fires its missile")
	settle(4.0)
	check(target_b.hp < target_b.max_hp or target_b.dead, "it strikes its target")
	var site: Dictionary = w.place_building("samSite", dry(field + Vector3(-60, 0, -60)), 1, true)
	for n in w.ai.nations: n.money = 10000000.0   # (every interceptor costs its owner money: war_costs.gd)
	var r_sam := rate(site, "brahmos", 0, 400)
	var r_cruise := rate(site, "cruise", 0, 400)
	check(r_sam < r_cruise - 0.3, "a SAM site stops ~25%% of BrahMos against ~75%% of ordinary cruise missiles (%.2f vs %.2f)" % [r_sam, r_cruise])
	w.destroy_building(site)
	var ship: Dictionary = w.spawn_unit("destroyer", sea + Vector3(10, 0, 0), 1)
	var s0: float = ship.hp
	w.missiles.impact("brahmos", ship.node.position, 0)
	var hut: Dictionary = w.place_building("barracks", dry(field + Vector3(40, 0, 60)), 1, true)
	var h0: float = hut.hp
	w.missiles.impact("brahmos", hut.root.position, 0)
	check((s0 - maxf(ship.hp, 0.0)) > (h0 - hut.hp) * 1.5 or ship.dead, "BrahMos is twice as deadly to ships")
	w.kill(bat)
	# Aegis cruiser: missile defence at sea.
	var aegis: Dictionary = w.spawn_unit("aegisCruiser", sea, 0)
	var r_ball := rate(aegis, "ballistic", 1, 400)
	var bonus: float = w.research.bonus("interceptPct")
	check(absf(r_ball - (0.8 + bonus)) < 0.08, "an Aegis cruiser stops ~%d%% of ballistic missiles at sea (%.2f)" % [int((0.8 + bonus) * 100), r_ball])
	check(Modern.REACH.aegisCruiser > Modern.REACH.abmLauncher, "farther out than a land battery")
	w.kill(aegis)
	# Akinci: a heavy drone, not a jammer's toy.
	var ak: Dictionary = w.spawn_unit("akinci", field, 0)
	check(w.AirOperations.CAPACITY.akinci == 8 and not "akinci" in Modern.DRONES, "an Akinci carries eight strikes and is too big for jammers")
	check(not "akinci" in w.AirOperations.TUBE_LAUNCHED, "it flies from a runway")
	w.kill(ak)
	# Harop: hunts air defence.
	var harop: Dictionary = w.spawn_unit("harop", field + Vector3(0, 16, 0), 0)
	var sam: Dictionary = w.spawn_unit("samLauncher", dry(field + Vector3(40, 0, 0)), 1)
	var tank: Dictionary = w.spawn_unit("tank", dry(field + Vector3(25, 0, 10)), 1)
	check(w.effectiveness(harop, sam) >= 2.9 * w.effectiveness(harop, tank) / 0.8 * 0.8, "a Harop hits air defence three times as hard")
	w.rebuild_grid()
	var picked = w.Tactics.pick_target(w, harop, 90.0)
	check(picked != null and picked.key == "samLauncher", "it picks the SAM launcher over a nearer tank")
	var sam0: float = sam.hp
	w.fire_weapon(harop, sam, "kamikaze")
	settle(1.5)
	check(harop.dead and (sam.dead or sam.hp < sam0), "and dives on it (%d -> %d)" % [int(sam0), int(maxf(sam.hp, 0))])
	check("harop" in preload("res://scripts/future_weapons.gd").HPM_KILLS and "harop" in Modern.DRONES, "microwaves and jammers stop it like any small drone")
	for u in [sam, tank]: w.kill(u)

	# ================================================================ the powers
	var d: Node = w.diplomacy
	w.game_time = 1000.0
	for n in range(1, d.n): d.make_peace(0, n)
	for key in FLAGS:
		check(not FP.POWERS[key].is_empty() and str(FP.POWERS[key].desc) != "", "%s has a national power: %s" % [key, FP.POWERS[key].name])
	# The United States: sanctions.
	play_as(0, "blue")
	w.power_ready.clear()
	var r0: float = d.rel(0, 1)
	FP.use(w, 0, 1)
	check(absf(FP.income_mult(w, 1) - 0.7) < 0.001, "Dollar Sanctions cut the target's income by 30%")
	check(d.rel(0, 1) < r0, "and cost relations with it")
	check(FP.blocked(w, 0, 2).begins_with("Ready in"), "the power must recharge before it is used again")
	w.game_time += 181.0
	check(FP.income_mult(w, 1) == 1.0, "sanctions wear off after three minutes")
	# China: export controls stop a rival's military production.
	play_as(0, "red")
	w.power_ready.clear()
	FP.use(w, 0, 1)
	check(FP.production_blocked(w, 1) and not FP.production_blocked(w, 0), "Rare-Earth Export Controls stop the target's military factories, not yours")
	w.game_time += 91.0
	# The European Union: partners join in.
	play_as(0, "green")
	w.power_ready.clear()
	d.set_flag(d.pact, 0, 2, true)
	var r21: float = d.rel(2, 1)
	FP.use(w, 0, 1)
	check(absf(FP.income_mult(w, 1) - 0.8) < 0.001 and d.rel(2, 1) < r21, "a Sanctions Package cuts income 20% and turns your partners against the target")
	w.game_time += 241.0
	# Iran: the Strait of Hormuz.
	play_as(0, "gold")
	w.power_ready.clear()
	var rels: Array = range(1, d.n).map(func(n): return d.rel(0, n))
	FP.use(w, 0)
	check(FP.sea_closed(w, 1) and not FP.sea_closed(w, 0), "closing Hormuz stops everyone's sea trade but yours")
	check(absf(FP.income_mult(w, 2) - 0.85) < 0.001, "and costs every other nation 15% of its income")
	check(range(1, d.n).all(func(n): return d.rel(0, n) < rels[n - 1]), "the whole world resents it")
	w.game_time += 121.0
	# Russia: energy.
	play_as(0, "russia")
	w.power_ready.clear()
	FP.use(w, 0, 1)
	check(absf(FP.income_mult(w, 1) - 0.75) < 0.001, "Energy Leverage cuts the target's income by 25%")
	w.game_time += 181.0
	# India: every camp at once.
	play_as(0, "india")
	w.power_ready.clear()
	rels = range(1, d.n).map(func(n): return d.rel(0, n))
	FP.use(w, 0)
	check(range(1, d.n).all(func(n): return d.rel(0, n) > rels[n - 1] or d.rel(0, n) >= 100.0), "Strategic Autonomy warms relations with every nation")
	# Japan: aid.
	play_as(0, "japan")
	w.power_ready.clear()
	d.declare_war(0, 3)
	check(FP.blocked(w, 0, 3) != "", "Development Aid is not for a nation you are fighting")
	d.make_peace(0, 3)
	var cash: float = w.economy.res.money
	r0 = d.rel(0, 3)
	FP.use(w, 0, 3)
	check(w.economy.res.money <= cash - 799.0 and d.rel(0, 3) > r0 and d.nap[0][3], "Development Aid costs $800, warms relations and signs a non-aggression pact")
	# Turkiye: peace talks.
	play_as(0, "turkiye")
	w.power_ready.clear()
	d.declare_war(0, 1)
	d.set_score(0, 1, -30.0)
	FP.use(w, 0, 1)
	check(not d.at_war(0, 1), "Istanbul Talks end your war with a nation")
	w.power_ready.clear()
	d.declare_war(2, 3)
	FP.use(w, 0, 2)
	check(not d.at_war(2, 3), "or two other nations' war with each other")
	w.power_ready.clear()
	check(FP.blocked(w, 0, 2) == "No war to end", "and are refused when there is no war")
	d.declare_war(0, 1)
	d.set_score(0, 1, -95.0)
	check(FP.blocked(w, 0, 1) == "It will not talk", "a nation that hates you beyond -80 will not talk")
	# Israel: Mossad.
	play_as(0, "israel")
	w.power_ready.clear()
	var theirs: Array = w.buildings.filter(func(b): return b.owner == 1 and not b.dead and b.built and b.key != "hq")
	var hp_sum := 0.0
	for b in theirs: hp_sum += b.hp
	var pts: float = w.research.points
	FP.use(w, 0, 1)
	var hp_after := 0.0
	for b in theirs: hp_after += maxf(b.hp, 0.0)
	check(hp_after < hp_sum and w.research.points >= pts + 249.0, "a Mossad Operation sabotages the target's industry and steals research")
	# Rivals use theirs on you.
	w.map.nations[0].color = saved_flag
	w.map.nations[0].erase("arsenal")
	play_as(1, "russia")
	d.declare_war(0, 1)
	w.power_ready.erase(1)
	w.power_think = 0.0
	var uses0: int = w.power_uses.size()
	for i in range(40):
		w.power_think = 0.0
		FP.update(w, DT)
		if w.power_uses.size() > uses0: break
	check(w.power_uses.size() > uses0 and int(w.power_uses[-1].owner) == 1 and int(w.power_uses[-1].target) == 0, "a rival at war with you uses its power on you")
	w.economy.tick()
	var sanctioned: float = w.economy.rates.money
	w.power_effects.clear()
	w.economy.tick()
	check(sanctioned < w.economy.rates.money * 0.8, "and your treasury feels it ($%.1f/s against $%.1f/s)" % [sanctioned, w.economy.rates.money])
	# The Diplomacy screen.
	w.map.nations[0].color = "#3b82f6"
	w.map.nations[0].arsenal = "blue"
	w.power_ready.clear()
	w.hud._panels = w.hud._panels if w.hud._panels != null else preload("res://scripts/side_panels.gd").new(w.hud)
	w.hud._panels.diplomacy_tab = "nations"
	w.hud.toggle_panel("diplomacy", true)
	await process_frame
	var texts: Array = []
	for n in w.hud._side_rows.find_children("*", "", true, false):
		if n is Label or n is Button: texts.append(str(n.text))
	check(texts.any(func(t): return t.contains("National power: Dollar Sanctions")), "the Diplomacy screen describes your national power")
	check(texts.filter(func(t): return t == "Dollar Sanctions").size() >= 1, "and each nation's card has the button to use it")
	print("\nFACTION_POWERS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("FACTION_POWERS PASS" if errors.is_empty() else "FACTION_POWERS FAIL")
	quit(0 if errors.is_empty() else 1)
