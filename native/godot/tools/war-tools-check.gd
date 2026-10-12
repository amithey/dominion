extends SceneTree
## The tools of war (war_tools.gd; research native/WAR-TOOLS-RESEARCH-2026-10-12.md):
## every new role registered, trained where it should be, by the nations that
## field it, with its own model; minefields laid, triggered, cleared and saved;
## field repair; counter-battery radar, airborne early warning, electronic attack
## and submarine hunters in the damage and the fog; who may engage what.
var errors: Array[String] = []
var passed := 0
var w: Node
const F := preload("res://scripts/factions.gd")
const C := preload("res://scripts/force_catalog.gd")
const T := preload("res://scripts/war_tools.gd")
const NEW := ["mineLayer", "mineClearer", "recoveryVehicle", "decoy", "counterBatteryRadar", "coastalASM", "aewc", "ewJet", "maritimePatrol", "carrier", "asFrigate"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func tick(seconds: float) -> void:
	var n := int(seconds / 0.25)
	for i in range(n): T.update(w, 0.25)

func run() -> void:
	# ---- the record: no years in the names the game shows
	for key in NEW:
		for id in C.names(key):
			var name: String = str(C.names(key)[id])
			# A model number (Saab 2000) is not a date; a dated note in brackets would be.
			var dated := false
			for y in range(1950, 2040):
				if ("(%d" % y) in name or ("%d)" % y) in name: dated = true
			check(not dated and id in C.IDS, "%s/%s: %s" % [key, id, name])
	check(not C.names("carrier").has("russia"), "Russia's only carrier is in a long refit: no carrier for Russia")
	check(C.operators("decoy") == ["russia", "ukraine"] or C.operators("decoy") == ["ukraine", "russia"], "decoys: the two armies documented using them at scale")
	check(C.operators("mineLayer").size() == C.IDS.size() - preload("res://scripts/regional_factions.gd").IDS.size(), "every national army has engineers (the regional entities keep their own rosters)")

	set_meta("match_config", {"map": "island", "players": 3, "nation": 0, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["fog", "un", "wmd", "directorate", "defcon", "events", "support"])

	# ---- registered, trained, named, modelled
	for key in NEW:
		check(w.unit_defs.has(key), "%s: a unit (%s)" % [key, w.unit_defs.get(key, {}).get("name", "?")])
		check(key in w.building_defs[C.HOME[key]].trains, "%s: trained at the %s" % [key, C.HOME[key]])
	check(w.unit_defs.carrier.name == "Gerald R. Ford-class" and w.unit_defs.aewc.name == "E-3G Sentry" and w.unit_defs.maritimePatrol.name == "P-8A Poseidon", "the United States' carrier, AEW and patrol aircraft by name")
	check(w.unit_allowed(0, "carrier") and w.unit_allowed(0, "ewJet") and not w.unit_allowed(0, "decoy"), "the United States fields carriers and Growlers; decoys are not its documented practice")
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var spot := hq + Vector3(40, 0, 40)
	var made := {}
	for key in NEW:
		var at := spot
		if w.unit_defs[key].get("naval", false):
			var sea = w.water_near(hq, 200)
			if sea == null: continue
			at = sea
		var u: Dictionary = w.spawn_unit(key, at, 0)
		made[key] = u
		check(not u.is_empty() and u.node != null and is_instance_valid(u.node), "%s: spawned with a model" % key)
	if made.has("decoy"):
		check(made.decoy.dmg == 0 and made.decoy.node.find_child("Force_decoy", true, false) != null, "a decoy has no weapon and looks like a tank")

	# ---- minefields
	w.diplomacy.declare_war(0, 1)
	var engineer: Dictionary = made.mineLayer
	engineer.node.position = spot
	tick(7.0)
	var fields: Array = T.state(w).fields
	check(fields.size() == 1 and int(fields[0].owner) == 0, "a halted engineer lays a minefield (%d)" % fields.size())
	var enemy_tank: Dictionary = w.spawn_unit("tank", spot + Vector3(3, 0, 0), 1)
	var hp0: float = enemy_tank.hp
	tick(0.5)
	check(enemy_tank.hp < hp0 - 100.0 or enemy_tank.dead, "an enemy tank that drives in is struck (%d -> %d)" % [hp0, enemy_tank.hp])
	var enemy_soldier: Dictionary = w.spawn_unit("soldier", spot + Vector3(-3, 0, 0), 1)
	var s0: float = enemy_soldier.hp
	tick(0.5)
	check(enemy_soldier.hp == s0, "infantry walks through anti-vehicle mines")
	check(T.visible_fields(w, 0).size() == 1 and T.visible_fields(w, 1).is_empty(), "the owner sees its field, the enemy does not")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(T.capture(w)))
	var clearer: Dictionary = w.spawn_unit("mineClearer", spot + Vector3(12, 0, 0), 1)
	check(T.visible_fields(w, 1).size() == 1, "an enemy clearer near it finds the field")
	tick(3.5)
	check(T.state(w).fields.is_empty(), "and its line charge clears it")
	T.restore(w, snap)
	check(T.state(w).fields.size() == 1 and int(T.state(w).fields[0].charges) <= T.MINE_CHARGES, "a save keeps the minefields")
	w.kill(clearer)

	# ---- recovery
	var tank: Dictionary = w.spawn_unit("tank", spot + Vector3(-20, 0, 20), 0)
	made.recoveryVehicle.node.position = spot + Vector3(-24, 0, 20)
	tank.hp = tank.max_hp * 0.4
	var before: float = tank.hp
	tick(2.0)
	check(tank.hp > before + 20.0, "the recovery vehicle repairs a damaged tank in the field (%d -> %d)" % [before, tank.hp])

	# ---- counter-battery radar
	var guns: Dictionary = w.spawn_unit("artillery", made.counterBatteryRadar.node.position + Vector3(60, 0, 0), 1)
	tick(0.5)
	var mine := {"owner": 0, "key": "artillery", "node": tank.node}
	check(is_equal_approx(T.damage_mult(w, mine, guns), 1.0 + T.RADAR_BONUS), "guns the radar has found are hit a quarter harder")
	check(T.sensed(w, 0, guns), "and they are revealed")
	check(not T.sensed(w, 0, enemy_soldier) or enemy_soldier.dead, "but the radar does not see infantry")
	# In real damage, not only in the factor: the same shell on two guns, with and without the radar.
	var g1: Dictionary = w.spawn_unit("artillery", made.counterBatteryRadar.node.position + Vector3(50, 0, 10), 1)
	var hp1: float = g1.hp
	w.damage(g1, 40.0, {"owner": 0, "key": "artillery", "node": tank.node, "dead": true})
	var with_radar: float = hp1 - g1.hp
	var radars: Array = T.state(w).support[0].get("counterBatteryRadar", [])
	T.state(w).support[0].erase("counterBatteryRadar")   # the radar switched off for one shot
	var g2: Dictionary = w.spawn_unit("artillery", made.counterBatteryRadar.node.position + Vector3(50, 0, -10), 1)
	var hp2: float = g2.hp
	w.damage(g2, 40.0, {"owner": 0, "key": "artillery", "node": tank.node, "dead": true})
	var without: float = hp2 - g2.hp
	T.state(w).support[0].counterBatteryRadar = radars
	check(without > 0.0 and absf(with_radar / without - (1.0 + T.RADAR_BONUS)) < 0.02, "the radar's bonus reaches the guns' real damage (%.1f vs %.1f)" % [with_radar, without])

	# ---- airborne early warning and electronic attack
	for key in ["aewc", "ewJet"]:
		made[key].air_state = "ready"
		made[key].node.position = spot + Vector3(0, 30, 0)
	var jet: Dictionary = w.spawn_unit("jet", spot + Vector3(10, 26, 0), 0)
	jet.air_state = "ready"
	tick(0.5)
	var sam: Dictionary = w.spawn_unit("samLauncher", spot + Vector3(20, 0, 0), 1)
	check(is_equal_approx(T.damage_mult(w, jet, sam), 1.0 + T.AEW_BONUS), "aircraft under the airborne radar hit harder (%.2f)" % T.damage_mult(w, jet, sam))
	check(T.damage_mult(w, jet, guns) > 1.3, "and the radar's bonus on guns it found stacks with it (%.2f)" % T.damage_mult(w, jet, guns))
	check(T.damage_mult(w, sam, jet) <= T.JAM_FACTOR + 0.01, "an enemy air defence near the jammer loses its aim (%.2f)" % T.damage_mult(w, sam, jet))
	made.aewc.air_state = "parked"
	tick(0.5)
	check(is_equal_approx(T.damage_mult(w, jet, sam), 1.0), "an AEW aircraft on the ground gives nothing")

	# ---- submarines, ships and the shore
	var sub := {"key": "submarine", "naval": true, "owner": 1}
	var destroyer := {"key": "destroyer", "naval": true, "owner": 1}
	check(is_equal_approx(T.damage_mult(w, {"owner": 0, "key": "maritimePatrol"}, sub), T.SUB_FACTOR) and is_equal_approx(T.damage_mult(w, {"owner": 0, "key": "asFrigate"}, sub), T.SUB_FACTOR), "patrol aircraft and frigates hit submarines hard")
	check(not C.can_target(w, {"key": "coastalASM"}, {"key": "tank"}) and C.can_target(w, {"key": "coastalASM"}, destroyer), "the coastal battery strikes ships only")
	check(not C.can_target(w, {"key": "maritimePatrol"}, {"key": "tank"}) and C.can_target(w, {"key": "maritimePatrol"}, sub), "the patrol aircraft hunts at sea only")
	check(not C.can_target(w, {"key": "carrier"}, sub) and C.can_target(w, {"key": "carrier"}, {"key": "tank"}), "the carrier's air wing does not hunt submarines")

	# ---- the carrier's air wing
	if made.has("carrier"):
		var carrier: Dictionary = made.carrier
		var foe: Dictionary = w.spawn_unit("destroyer", carrier.node.position + Vector3(70, 0, 0), 1)
		if foe.is_empty() or not foe.get("naval", false):
			foe = w.spawn_unit("tank", carrier.node.position + Vector3(70, 0, 0), 1)
		var aboard0: int = T.wing_size(w, carrier)
		check(aboard0 == 5, "a supercarrier carries five strike aircraft (%d)" % aboard0)
		tick(0.5)
		var wing: Array = w.units.filter(func(u): return not u.dead and u.key == "carrierJet" and u.get("carrier") == carrier)
		check(wing.size() >= 1 and int(carrier.wing.aboard) == aboard0 - wing.size(), "aircraft take off from the deck against a target in reach (%d flying)" % wing.size())
		check(wing.size() >= 1 and wing[0].enemy != null and int(wing[0].enemy.owner) == 1 and str(wing[0].air_state) == "ready", "and fly at an enemy in reach")
		var shown: int = carrier.deck_planes.filter(func(n): return n.visible).size()
		check(shown == int(carrier.wing.aboard), "the deck shows the aircraft still aboard (%d)" % shown)
		check(w.unit_defs.carrierJet.name == "F/A-18E Super Hornet", "the American wing flies Super Hornets")
		if not wing.is_empty():
			var plane: Dictionary = wing[0]
			plane.ammo = 0
			plane.node.position = carrier.node.position + Vector3(30, 24, 0)
			for i in range(200):
				w.AirOperations.update(w, plane, 0.1)
				if plane.dead: break
			check(plane.dead and plane.get("stowed", false), "a spent aircraft flies home and lands aboard, without a wreck")
			check(carrier.wing.rearming.size() >= 1, "and is rearmed below decks")
			w.game_time += T.REARM + 1.0
			var before_aboard: int = int(carrier.wing.aboard)
			carrier.wing.next = 999.0
			tick(0.5)
			check(int(carrier.wing.aboard) == before_aboard + 1, "then it is ready to fly again")
		check(not C.can_target(w, {"key": "carrier"}, {"key": "submarine"}), "the carrier's own guns do not hunt submarines")

	# ---- rival navies
	var naval_picks := 0
	var options := ["tank", "soldier", "apc", "destroyer", "corvette", "artillery", "jet", "mlrs"]
	for i in range(400):
		if w.unit_defs.get(T.ai_pick(w, 1, options), {}).get("naval", false): naval_picks += 1
	check(naval_picks > 400 * 2 / 8, "a rival with a navy favours its fleet while it is short (%d of 400 picks were ships)" % naval_picks)

	print("WAR_TOOLS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("WAR_TOOLS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
