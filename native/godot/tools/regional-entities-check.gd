extends SceneTree
## The six regional entities given what every other nation has (research:
## native/REGIONAL-ENTITIES-RESEARCH-2026-10-11.md): their own names for their
## systems, unit quality that matches them (not the shared 1.0), the Houthis'
## missiles and launch sites (no one else's), South Sudan's helicopters, and
## their regime, town plan, sanctions, treaties and officer corps.
var errors: Array[String] = []
var passed := 0
var w: Node
const F := preload("res://scripts/factions.gd")
const Q := preload("res://scripts/unit_quality.gd")
const R := preload("res://scripts/regional_factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func begin(id: String) -> void:
	set_meta("match_config", {"map": "crown", "players": 3, "nation": F.IDS.find(id), "rivals": [0, F.IDS.find("iran")], "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	w.ai.set_physics_process(false)

func run() -> void:
	var expect := {"yemen": "T-55 / T-62", "houthis": "T-62 / T-72 (captured)", "ethiopia": "T-72UA1 / T-72B", "nigeria": "VT-4 / Vickers Mk 3", "sudan": "T-72 / Al-Bashir", "south_sudan": "T-72AV"}
	for id in R.IDS:
		# ---- data that needs no match
		var tank: Dictionary = Q.of(id, "tank")
		check(float(tank.hp) < 1.0 and float(tank.damage) < 1.0, "%s: its tanks are rated as they are, not as a modern tank (%.2f health)" % [id, tank.hp])
		check(float(Q.of(id, "soldier").hp) < 1.05, "%s: its infantry has a rating" % id)
		check(str(preload("res://scripts/war_support.gd").REGIME.get(id, "")) != "", "%s: a regime type (%s)" % [id, preload("res://scripts/war_support.gd").REGIME.get(id, "")])
		check(str(preload("res://scripts/city_planner.gd").STYLE.get(id, "")) != "", "%s: a town plan" % id)
		check(preload("res://scripts/cbrn_data.gd").TREATIES.has(id), "%s: its treaties" % id)
		check(preload("res://scripts/generals.gd").DOCTRINE.has(id) and preload("res://scripts/generals.gd").NAMES.get(id, []).size() >= 8, "%s: an officer corps and its names" % id)
	check(preload("res://scripts/un_data.gd").STANDING.has("houthis") and preload("res://scripts/un_data.gd").STANDING.has("sudan"), "the Houthi and Darfur sanctions are in force")
	check(bool(preload("res://scripts/cbrn_data.gd").TREATIES.nigeria.icc) and not bool(preload("res://scripts/cbrn_data.gd").TREATIES.sudan.icc), "Nigeria is an ICC party, Sudan is not")

	# ---- in play: the Houthis
	await begin("houthis")
	check(str(w.unit_defs.tank.name) == expect.houthis, "the Houthis' tank is the %s" % w.unit_defs.tank.name)
	check(str(w.unit_defs.loiterer.name).contains("Qasef"), "their loitering munition is the %s" % w.unit_defs.loiterer.name)
	check(preload("res://scripts/national_variants.gd").builds(w, 0, "missileSilo"), "they may dig a missile launch site")
	for key in R.HOUTHI_MISSILES:
		var blocked: String = preload("res://scripts/arsenal_catalog.gd").missile_blocked(w, 0, key)
		var foreign: String = preload("res://scripts/national_arsenal.gd").foreign(w, w.missiles.def_of(key).get("nation", ""))
		check(blocked == "" and foreign == "", "they field the %s (%s)" % [preload("res://scripts/arsenal_catalog.gd").missile_name(w, 0, key), key])
	check(preload("res://scripts/arsenal_catalog.gd").missile_name(w, 0, "ballistic") == "Toufan / Palestine-2", "the long-range missile is the Toufan / Palestine-2")
	check(not preload("res://scripts/national_variants.gd").builds(w, 0, "nuclearReactor"), "but no reactor")

	# ---- in play: each of the others
	for id in ["yemen", "ethiopia", "nigeria", "sudan", "south_sudan"]:
		await begin(id)
		check(str(w.unit_defs.tank.name) == expect[id], "%s: its tank is the %s" % [id, w.unit_defs.tank.name])
		check(not preload("res://scripts/national_variants.gd").builds(w, 0, "missileSilo"), "%s: no missile silo" % id)
		var ballistic: String = preload("res://scripts/national_arsenal.gd").foreign(w, w.missiles.def_of("ballistic").get("nation", ""))
		check(ballistic != "", "%s: no ballistic missiles" % id)
		if id == "south_sudan":
			check(w.unit_allowed(0, "gunship") and str(w.unit_defs.gunship.name) == "Mi-24V", "South Sudan flies Mi-24V gunships (%s)" % w.unit_defs.gunship.name)
		if id == "sudan":
			check(str(w.unit_defs.drone.name).contains("TB2"), "Sudan's army flies the %s" % w.unit_defs.drone.name)
		if id == "ethiopia":
			check(str(w.unit_defs.aaVehicle.name) == "Pantsir-S1" and str(w.unit_defs.jet.name).contains("Su-30"), "Ethiopia: Pantsir-S1 and Su-30")
		if id == "nigeria":
			check(str(w.unit_defs.gunship.name).contains("T129"), "Nigeria: T129 ATAK gunships")

	print("REGIONAL_ENTITIES %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("REGIONAL_ENTITIES %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
