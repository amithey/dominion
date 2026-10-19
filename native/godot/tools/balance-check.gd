extends SceneTree
## Cost-efficiency of every armed unit (scripts/balance.gd; native/BALANCE-2026-10-18.md):
## hit points x damage per second x the best damage multiplier it has, per unit of price.
## No unit may stand far above its kind, and the corrections must hold and apply once.
var errors: Array[String] = []
var passed := 0
var w: Node
const B := preload("res://scripts/balance.gd")
const KAMIKAZE := ["suicideSquad", "seaDrone", "interceptorDrone", "loiterer", "harop", "shahed", "wingman"]   # they die on their strike
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func price(d: Dictionary) -> float:
	var money := 0.0
	var cost: Dictionary = d.get("cost", {})
	for r in cost:
		money += float(cost[r]) * (1.0 if r == "money" else (3.0 if r in ["iron", "oil"] else 5.0))
	return money

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	var d: Dictionary = w.unit_defs
	check(float(d.apc.dmg) == 10.0 and float(d.bushmaster.dmg) == 10.0, "a troop carrier no longer out-shoots a tank (APC and Bushmaster 10 damage)")
	var apc_dps: float = float(d.apc.dmg) / float(d.apc.cooldown)
	var tank_dps: float = float(d.tank.dmg) / float(d.tank.cooldown)
	check(apc_dps <= tank_dps * 1.05, "an APC's fire (%.0f) does not exceed a tank's (%.0f)" % [apc_dps, tank_dps])
	check(float(d.seaDrone.dmg) == 240.0 and price(d.seaDrone) > 450.0, "the sea drone no longer sinks a destroyer in one hit for a third of its price")
	check(float(d.seaDrone.dmg) * float(w.damage_profile.seaDrone.naval) < float(d.destroyer.hp), "(one sea drone does not kill a destroyer: %.0f of %.0f hp)" % [float(d.seaDrone.dmg) * float(w.damage_profile.seaDrone.naval), float(d.destroyer.hp)])
	check(float(w.damage_profile.interceptorDrone.air) == 1.5 and float(w.damage_profile.type45.air) == 2.4 and float(w.damage_profile.aaVehicle.air) == 2.8, "air-defence multipliers trimmed")
	check(float(d.gunship.dmg) == 30.0 and price(d.gunship) > 1000.0, "the gunship is no longer the best value in the game")
	var m: Dictionary = w.map.missiles.types
	check(float(m.ballistic.dmg) == 1450.0 and float(m.ballistic.cost.money) == 1100.0 and float(m.tactical.cost.money) == 290.0, "ballistic and tactical missiles retuned")
	check(float(m.ballistic.dmg) < float(w.building_defs.hq.hp) * 0.5, "one ballistic missile no longer takes half a headquarters")
	# Applying again changes nothing.
	var cost_before: float = price(d.seaDrone)
	B.apply(w)
	check(is_equal_approx(price(d.seaDrone), cost_before) and float(d.gunship.dmg) == 30.0, "the corrections apply once (a second call changes nothing)")
	# Bounds on cost-efficiency.
	var worst := {"key": "", "eff": 0.0}
	var worst_k := {"key": "", "eff": 0.0}
	var rows := []
	for k in d:
		var def: Dictionary = d[k]
		var cost := price(def)
		if cost <= 0.0 or float(def.get("dmg", 0)) <= 1.0 or float(def.get("cooldown", 0)) <= 0.0:
			continue
		var prof: Dictionary = w.damage_profile.get(k, {})
		var best := 0.0
		for t in prof: best = maxf(best, float(prof[t]))
		var eff: float = float(def.hp) * (float(def.dmg) / maxf(float(def.cooldown), 0.1)) * maxf(best, 0.3) / cost
		rows.append([k, eff])
		if k in KAMIKAZE:
			if eff > float(worst_k.eff): worst_k = {"key": k, "eff": eff}
		elif eff > float(worst.eff):
			worst = {"key": k, "eff": eff}
	check(float(worst.eff) <= 45.0, "no ordinary unit is above 45 in value per price (the best: %s %.1f)" % [worst.key, worst.eff])
	check(float(worst_k.eff) <= 75.0, "no one-way weapon is above 75 (the best: %s %.1f)" % [worst_k.key, worst_k.eff])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var ordinary := rows.filter(func(r): return not r[0] in KAMIKAZE)
	check(ordinary.size() > 30 and float(ordinary[0][1]) <= float(ordinary[ordinary.size() / 2][1]) * 5.0, "the best ordinary unit is within five times the median (%.1f vs %.1f)" % [ordinary[0][1], ordinary[ordinary.size() / 2][1]])
	print("BALANCE %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("BALANCE %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
