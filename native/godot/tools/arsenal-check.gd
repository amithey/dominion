extends SceneTree
var w: Node
var passed := 0
var errors: Array[String] = []
const C := preload("res://scripts/cbrn_data.gd")
const A := preload("res://scripts/arsenal_catalog.gd")
const F := preload("res://scripts/factions.gd")
const N := preload("res://scripts/national_variants.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for frame in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu._root.hide()
	for frame in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["wmd", "un"])
	var original: Dictionary = w.map.nations[0].duplicate(true)
	for index in range(F.IDS.size()):
		w.map.nations[0] = F.nation(index, true)
		for key in A.MISSILES:
			check((A.missile_blocked(w, 0, key) == "") == (A.MISSILES[key].has(F.IDS[index]) and not F.IDS[index] in A.MISSILE_PROGRAMS.get(key, [])), "%s / %s access" % [F.IDS[index], key])
		check(not C.has(w, 0, "dirtyBomb") and not C.has(w, 0, "chlorine"), "%s has no invented radiological/chlorine arsenal" % F.IDS[index])
		for key in A.UNIT_PROGRAMS:
			if F.IDS[index] in A.UNIT_PROGRAMS[key]:
				check(A.unit_blocked(w, 0, key) != "" and not N.fields(key, F.ARSENALS[index]), "%s / %s prototype excluded from starting army" % [F.IDS[index], key])
	w.map.nations[0] = original.duplicate(true)
	check(w.research.era_of(A.PROGRAM) == 5, "future programme uses future era")
	w.map.nations[0].id = "india"
	check(N.name_for(w, 0, "tank") == "Arjun Mk1" and A.unit_blocked(w, 0, "stealthFighter") != "", "India starts with Mk1; AMCA needs development")
	w.research.progress[A.PROGRAM] = {"stage": 3, "work": 0, "paid": false}
	w.research._recompute()
	check(A.unit_blocked(w, 0, "stealthFighter") == "" and N.name_for(w, 0, "tank").contains("Mk1A"), "research unlocks AMCA and ordered tank upgrade")
	w.research.progress.erase(A.PROGRAM)
	w.research._recompute()
	w.map.nations[0].id = "egypt"
	check(not C.has(w, 0, "chemical"), "CWC non-membership does not invent Egyptian nerve agents")
	w.map.nations[0].id = "israel"
	check(not C.has(w, 0, "chemical"), "Israel treaty signature does not establish chemical inventory")
	w.map.nations[0].id = "turkiye"
	w.diplomacy.set_flag(w.diplomacy.alliance, 0, 1, true)
	check(not C.has(w, 0, "tacticalNuke") and w.missiles.locked("tacticalNuke") != "", "sharing never grants sovereign nuclear production")
	w.map.nations[0].id = "pakistan"
	check(not C.has(w, 0, "mirv") and C.blocked(w, 0, "mirv").contains("Future"), "Ababeel is a programme, not deployed MIRV inventory")
	w.map.nations[0].id = "russia"
	check(C.has(w, 0, "nuclearGlide") and not C.has(w, 0, "poseidon") and not C.has(w, 0, "nuclearAsat"), "Avangard current; Poseidon and nuclear ASAT future")
	w.map.nations[0].id = "north_korea"
	check(not C.has(w, 0, "poseidon"), "Haeil claim does not grant a Russian Poseidon")
	w.map.nations[0].id = "iraq"
	check(w.unit_allowed(0, "tos1a") and not w.unit_allowed(0, "corvette"), "Iraq operates TOS but patrol boats are not missile corvettes")
	w.map.nations[0].id = "brazil"
	check(not w.unit_allowed(0, "gunship"), "retired AH-2 is unavailable")
	w.map.nations[0].id = "australia"
	check(not w.unit_allowed(0, "drone"), "cancelled MQ-9B is unavailable")
	w.map.nations[0].id = "japan"
	var recon: Dictionary = w.spawn_unit("drone", w.start + Vector3(15, 0, 15), 0)
	check(recon.dmg == 0.0, "SeaGuardian ISR variant has no attack payload")
	w.map.nations[0].id = "ukraine"
	w.research.progress.fibreOpticDrones = {"stage": 3, "work": 0, "paid": false}
	w.research._recompute()
	var fpv: Dictionary = w.spawn_unit("fpvTeam", w.start + Vector3(20, 0, 20), 0)
	check(fpv.get("fibre_optic", false), "Ukrainian fibre-optic research equips real new units")
	w.map.nations[0] = original.duplicate(true)
	for key in ["nuclearProgram", "ballisticTech", "precisionStrikes", "guidedMunitions"]: w.research.progress[key] = {"stage": 3, "work": 0, "paid": false}
	w.research._recompute()
	w.missiles.stock.bunkerBuster = 1
	var fake: Dictionary = {"key": "missileSilo", "owner": 1, "built": true, "dead": false, "queue": []}
	check(w.missiles.produce(fake, "tactical").contains("another nation"), "enemy facility cannot spend player's stock/resources")
	var silos: Array = w.missiles.silos()
	if silos.is_empty():
		var site = w.test_site("missileSilo", w.start + Vector3(65, 0, 45))
		silos.append(w.place_building("missileSilo", site, 0, true))
	var money: float = w.economy.res.money
	var shot: String = w.missiles.launch("bunkerBuster", w.start + Vector3(120, 0, 120), silos[0])
	check(shot.contains("platform") and w.missiles.stock.bunkerBuster == 1 and w.economy.res.money == money, "B61 cannot launch from silo; rejection is atomic")
	var aircraft: Dictionary = w.spawn_unit("bomber", w.start + Vector3(25, 0, 25), 0)
	aircraft.air_state = "ready"
	var launched: String = w.missiles.launch("bunkerBuster", w.start + Vector3(120, 0, 120), aircraft)
	check(launched.contains("launched") and w.missiles.stock.bunkerBuster == 0, "gravity bomb launches from an owned strike aircraft and spends one payload")
	w.missiles.stock.tactical = 1
	var enemy_silo: Dictionary = silos[0].duplicate()
	enemy_silo.owner = 1
	check(w.missiles.launch("tactical", w.start, enemy_silo).contains("cannot") and w.missiles.stock.tactical == 1, "explicit enemy launch platform rejected without consuming stock")
	w.missiles.stock.hypersonic = 1
	check(w.missiles.launch("hypersonic", w.start).contains("Future") and w.missiles.stock.hypersonic == 1, "old save inventory cannot bypass programme gate")
	w.research.progress[A.PROGRAM] = {"stage": 3, "work": 0, "paid": false}
	w.research._recompute()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(snapshot.research.progress[A.PROGRAM].stage == 3 and snapshot.missiles.stock.hypersonic == 1 and snapshot.has("un"), "JSON save preserves future research, payload inventory and UN process together")
	w.map.nations[0].id = "future_country"
	check(not w.missiles.available_to(0, "hypersonic") and not w.unit_allowed(0, "stealthFighter") and not C.has(w, 0, "nuke"), "new countries do not inherit advanced weapons from slot colour")
	w.map.nations[0].missiles = ["cruise"]
	w.map.nations[0].units = ["tank"]
	w.map.nations[0].missile_platforms = {"cruise": "ground"}
	check(w.missiles.available_to(0, "cruise") and w.unit_allowed(0, "tank") and not w.unit_allowed(0, "jet"), "future country explicit operator lists override defaults")
	check(0 in w.un.members() and not w.un.permanent(0), "future country's UN membership follows identity without inheriting a veto")
	w.map.nations[0] = original
	print("ARSENAL_CHECK %s (%d checks)" % ["PASS" if errors.is_empty() else "FAIL", passed])
	quit(0 if errors.is_empty() else 1)
