extends SceneTree
## About a hundred checks on the modern units (modern_warfare.gd) and each
## nation's own weapons (national_arsenal.gd). For every unit: it is built with
## a model, in its element (land, sea, air), trained at its building, locked
## behind its research, fielded only by its own nation, hurts the target it is
## made for and never its own side. Then each special ability: stealth ranges,
## SEAD, the DF-17 glide vehicle and its interception odds, the Shahed swarm and
## its cap, IRIS-T's odds, the B-21's bombs, rival nations fielding their own
## weapons, movement orders, and a save round trip.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 30.0
const Modern := preload("res://scripts/modern_warfare.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok   " if ok else "FAIL ", label)
	if ok: passed += 1
	else: errors.append(label)
func settle(seconds: float) -> void:
	for i in range(int(seconds / DT)):
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
func land(offset: Vector3) -> Vector3:
	return w.land_point(w.start + offset, 40.0)
func complete(key: String) -> void:
	w.research.progress[key].stage = 3
	w.research._recompute()

## A fresh enemy of class `cls` near `at` (aircraft in flight, ships at sea).
func target_of(cls: String, at: Vector3, sea: Vector3) -> Dictionary:
	match cls:
		"infantry": return w.spawn_unit("soldier", at, 1)
		"light": return w.spawn_unit("apc", at, 1)
		"armor": return w.spawn_unit("tank", at, 1)
		"naval": return w.spawn_unit("destroyer", sea, 1)
		"air":
			var jet: Dictionary = w.spawn_unit("jet", at, 1)
			jet.air_state = "ready"
			return jet
	return w.place_building("barracks", at, 1, true)

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	w.diplomacy.declare_war(0, 1)
	var sea: Vector3 = w.water_near(w.start, 220)
	var keys: Array = Modern.UNITS.keys() + Arsenal.UNITS.keys().filter(func(k): return k != "shahed")
	var buildings_of := {}
	for table in [Modern.TRAINS, Arsenal.TRAINS]:
		for b in table:
			for k in table[b]: buildings_of[k] = b
	# ------------------------------------------------ every unit
	var slot := 0
	for key in keys:
		slot += 1
		var def: Dictionary = w.unit_defs[key]
		var base: Vector3 = land(Vector3(-160 + (slot % 6) * 55, 0, -120 + (slot / 6) * 70))
		var u: Dictionary = w.spawn_unit(key, sea if def.naval else base, 0)
		var ground: float = w.height_at(u.node.position.x, u.node.position.z)
		var element := "on land"
		var in_element: bool = u.node.position.y >= ground - 0.5
		if def.fly:
			element = "in the air"
			in_element = u.node.position.y > ground + 5.0
		elif def.naval:
			element = "at sea"
			in_element = w.is_water(u.node.position, -0.5)
		check(u.node.get_child_count() > 0 and u.hp > 0.0 and in_element, "%s is built with a model, %s" % [key, element])
		check(key in w.building_defs[buildings_of[key]].trains, "%s is trained at the %s" % [key, buildings_of[key]])
		var need: String = str(def.get("requires", ""))
		var nation: String = str(def.get("nation", ""))
		if need != "" and (nation == "" or nation == "blue"):
			var before: String = w.research.unit_locked(key)
			var was_done: bool = w.research.done(need)   # an earlier unit may have needed it too
			complete(need)
			check((was_done or before != "") and w.research.unit_locked(key) == "", "%s waits for %s" % [key, need])
		elif nation == "":
			check(w.research.unit_locked(key) == "", "%s needs no research" % key)
		if nation != "":
			var mine: bool = nation == "blue"
			check(w.unit_allowed(0, key) == mine and (w.research.unit_locked(key).ends_with("only") != mine), "%s is fielded only by the %s" % [key, Arsenal.NATION_NAMES[nation]])
		# The target it is made for: its best class in the damage table.
		if def.dmg <= 1 and not key in ["df17", "shahedLauncher"]:
			check(u.dmg <= 0.0 and Tactics_target(u) == null, "%s has no weapon of its own and engages nothing" % key)
			w.kill(u)
			continue
		var profile: Dictionary = w.damage_profile[key]
		var best := "infantry"
		for cls in profile:
			if float(profile[cls]) > float(profile[best]): best = cls
		var spot: Vector3 = u.node.position + Vector3(minf(u.range * 0.5, 20.0), 0, 0)
		if not def.naval: spot = w.land_point(spot, 20.0)
		var enemy: Dictionary = target_of(best, spot if best != "naval" or def.naval else sea + Vector3(14, 0, 0), sea + Vector3(14, 0, 0))
		if def.fly:
			u.node.position = enemy.node.position + Vector3(-4, 18, 0)   # over the target (bombs need it)
			u.air_state = "ready"
		var friend: Dictionary = w.spawn_unit("soldier", w.land_point(enemy.node.position + Vector3(0, 0, 18), 8.0), 0) if not enemy.get("naval", false) else {}
		var hp0: float = enemy.hp
		var weapon: String = w.WEAPONS.get(key, "")
		for shot in range(8):
			if enemy.dead or enemy.hp < hp0: break
			if weapon == "swarm":
				break
			if weapon != "":
				if u.dead: break
				w.fire_weapon(u, enemy, weapon)
			else:
				w._fire_gun(u, enemy)
			settle(3.0 if weapon == "hgv" else 1.5)
		if weapon == "swarm":
			var n: int = Arsenal.launch_swarm(w, u, enemy)
			check(n == Arsenal.SWARM and w.units.filter(func(x): return x.key == "shahed" and not x.dead and x.owner == 0).size() >= n, "%s launches a swarm of %d Shaheds at a %s" % [key, n, best])
		else:
			check(enemy.dead or enemy.hp < hp0, "%s hurts a %s (%d -> %d)" % [key, best, int(hp0), int(enemy.hp)])
		if not friend.is_empty() and weapon != "hgv":
			check(not friend.dead and friend.hp >= friend.max_hp, "%s never hurts its own side" % key)
			w.kill(friend)
		w.kill(enemy) if not enemy.dead and not enemy.get("is_building", false) else null
		if enemy.get("is_building", false) and not enemy.dead: w.destroy_building(enemy)
		if not u.dead: w.kill(u)
	for u in w.units.filter(func(x): return x.key == "shahed"): w.kill(u)
	# ------------------------------------------------ what each weapon cannot hit
	var probe := {}
	for key in ["manpads", "laserAD", "irisT", "seaDrone", "df17", "raider", "shahed", "medic"]:
		probe[key] = w.spawn_unit(key, sea if key == "seaDrone" else land(Vector3(0, 0, 60)), 0)
	var tank: Dictionary = w.spawn_unit("tank", land(Vector3(20, 0, 60)), 1)
	var jet: Dictionary = w.spawn_unit("jet", land(Vector3(20, 0, 60)), 1)
	jet.air_state = "ready"
	check(w.effectiveness(probe.manpads, tank) == 0.0 and w.effectiveness(probe.manpads, jet) > 2.0, "MANPADS hit aircraft, not tanks")
	check(w.effectiveness(probe.irisT, tank) == 0.0 and w.effectiveness(probe.irisT, jet) > 3.0, "IRIS-T hits aircraft, not tanks")
	check(w.effectiveness(probe.laserAD, tank) == 0.0, "the laser cannot hit tanks")
	check(w.effectiveness(probe.seaDrone, tank) == 0.0, "a sea drone cannot hit tanks")
	check(w.effectiveness(probe.df17, jet) == 0.0, "a DF-17 cannot hit aircraft")
	check(w.effectiveness(probe.raider, jet) == 0.0, "a B-21 cannot hit aircraft")
	check(w.effectiveness(probe.shahed, jet) == 0.0, "a Shahed cannot hit aircraft")
	check(w.effectiveness(probe.medic, tank) == 0.0, "a medic's pistol cannot hurt a tank")
	# ------------------------------------------------ stealth
	var aa: Dictionary = w.spawn_unit("aaVehicle", land(Vector3(-100, 0, 100)), 1)
	for pair in [["stealthFighter", 0.4], ["raptor", 0.25], ["raider", 0.15]]:
		var plane: Dictionary = w.spawn_unit(pair[0], aa.node.position + Vector3(0, 28, 0), 0)
		plane.air_state = "ready"
		var reach := 70.0
		var outside: bool = Modern.hidden(w, plane, reach * pair[1] + 3.0, reach)
		var inside: bool = Modern.hidden(w, plane, reach * pair[1] - 3.0, reach)
		check(outside and not inside, "%s is seen only within %d%% of an air defence's range" % [pair[0], int(pair[1] * 100)])
		plane.air_state = "parked"
		plane.node.position.y = w.height_at(plane.node.position.x, plane.node.position.z) + 0.5
		check(not Modern.hidden(w, plane, 50.0, reach), "%s parked on the ground is seen like anything else" % pair[0])
		w.kill(plane)
	# ------------------------------------------------ the Raptor's SEAD
	var raptor: Dictionary = w.spawn_unit("raptor", aa.node.position + Vector3(0, 30, 0), 0)
	var sam: Dictionary = w.spawn_unit("samLauncher", aa.node.position + Vector3(10, 0, 0), 1)
	check(w.effectiveness(raptor, sam) >= 2.5 * w.effectiveness(raptor, tank) - 0.01, "the F-22 hits air defences 2.5 times as hard (SEAD)")
	check(w.effectiveness(raptor, jet) > w.effectiveness(w.spawn_unit("jet", land(Vector3(0, 0, 0)), 0), jet), "the F-22 beats an ordinary jet in the air")
	var site: Dictionary = w.place_building("samSite", land(Vector3(-60, 0, 150)), 1, true)
	check(w.effectiveness(raptor, site) > 2.0, "the F-22 hits SAM sites hard")
	# ------------------------------------------------ the B-21's bombs
	var depot: Dictionary = w.place_building("barracks", land(Vector3(120, 0, -140)), 1, true)
	var raider: Dictionary = w.spawn_unit("raider", depot.root.position + Vector3(0, 34, 0), 0)
	raider.air_state = "ready"
	var hp0: float = depot.hp
	check(w.fire_weapon(raider, depot, "bomb"), "a B-21 over its target releases its bombs")
	settle(3.0)
	check(depot.hp < hp0 - 200.0 or depot.dead, "B-21 bombs wreck a barracks (%d -> %d)" % [int(hp0), int(depot.hp)])
	raider.node.position += Vector3(40, 0, 0)
	check(not w.fire_weapon(raider, depot, "bomb"), "away from its target it holds its bombs")
	check(w.AirOperations.CAPACITY.raider == 2, "a B-21 flies two sorties before it rearms")
	# ------------------------------------------------ the DF-17
	var df: Dictionary = w.spawn_unit("df17", land(Vector3(-40, 0, -40)), 0)
	var hex: float = float(w.map.logistics.hexRadius) * sqrt(3.0)
	check(absf(df.range - hex * 6.0) < 1.0, "a DF-17 reaches six hexes (%d m)" % int(df.range))
	var flying: int = w.missiles.flying.size()
	var hall: Dictionary = w.place_building("barracks", land(Vector3(40, 0, -60)), 1, true)
	w.fire_weapon(df, hall, "hgv")
	check(w.missiles.flying.size() == flying + 1 and w.missiles.flying[-1].owner == 0 and w.missiles.flying[-1].type == "df17", "a DF-17 fires a glide vehicle")
	hp0 = hall.hp
	settle(4.0)
	check(hall.hp < hp0 or hall.dead, "the glide vehicle strikes its target (%d -> %d)" % [int(hp0), int(hall.hp)])
	check(not "df17" in w.missiles.types(), "silos cannot build the DF-17's glide vehicle")
	var ship: Dictionary = w.spawn_unit("destroyer", sea + Vector3(-12, 0, 0), 1)
	hp0 = ship.hp
	w.missiles.impact("df17", ship.node.position, 0)
	var ship_loss: float = hp0 - ship.hp
	var hut: Dictionary = w.place_building("barracks", land(Vector3(150, 0, 60)), 1, true)
	var hut0: float = hut.hp
	w.missiles.impact("df17", hut.root.position, 0)
	check(ship_loss > 2.0 * (hut0 - hut.hp) or ship.dead, "the glide vehicle is a carrier killer: 2.5 times as deadly to ships")
	var abm: Dictionary = w.spawn_unit("abmLauncher", land(Vector3(-120, 0, -20)), 1)
	var r_abm := rate(abm, "df17", 0, 500)
	check(absf(r_abm - 0.30) < 0.07, "a missile defence battery stops ~30%% of DF-17 glide vehicles (%.2f)" % r_abm)
	w.kill(abm)
	var r_sam := rate(site, "df17", 0, 500)
	check(r_sam < 0.14, "a SAM site stops few of them (%.2f)" % r_sam)
	# ------------------------------------------------ IRIS-T
	var iris: Dictionary = w.spawn_unit("irisT", land(Vector3(-140, 0, -60)), 0)
	var r_cruise := rate(iris, "cruise", 1, 500)
	var r_ball := rate(iris, "ballistic", 1, 500)
	var r_hyp := rate(iris, "hypersonic", 1, 500)
	var bonus: float = w.research.bonus("interceptPct")   # Missile Defence is done by now: +10%
	check(r_cruise > 0.9, "IRIS-T stops ~95%% of cruise missiles (%.2f)" % r_cruise)
	check(absf(r_ball - (0.45 + bonus)) < 0.07, "IRIS-T stops ~%d%% of ballistic missiles (%.2f)" % [int((0.45 + bonus) * 100), r_ball])
	check(absf(r_hyp - (0.12 + bonus)) < 0.06, "IRIS-T stops few hypersonic missiles (%.2f)" % r_hyp)
	check(w.effectiveness(iris, w.spawn_unit("shahed", iris.node.position + Vector3(30, 12, 0), 1)) > 3.0, "IRIS-T shoots down Shaheds")
	w.kill(iris)
	# ------------------------------------------------ the Shahed swarm
	var launcher: Dictionary = w.spawn_unit("shahedLauncher", land(Vector3(80, 0, 80)), 0)
	var mark: Dictionary = w.place_building("barracks", land(Vector3(80, 0, 150)), 1, true)
	for u in w.units.filter(func(x): return x.key == "shahed"): w.kill(u)
	var total := 0
	for salvo in range(4):
		total += Arsenal.launch_swarm(w, launcher, mark)
	check(total == Arsenal.SWARM_MAX, "no more than %d Shaheds of a nation are in the air at once (%d)" % [Arsenal.SWARM_MAX, total])
	var drones: Array = w.units.filter(func(x): return x.key == "shahed" and not x.dead and x.owner == 0)
	check(drones.all(func(d): return d.get("fly", false) and d.air_state == "ready"), "Shaheds take off at once, without a runway")
	check(drones.all(func(d): return d.enemy == mark or d.target != null), "every Shahed is sent at the target")
	check(drones.all(func(d): return d.get("air_base") == null), "Shaheds hold no parking slot")
	check("shahed" in Modern.DRONES and "shahed" in Modern.KAMIKAZE, "Shaheds can be jammed and die on their strike")
	var one: Dictionary = drones[0]
	hp0 = mark.hp
	one.node.position = mark.root.position + Vector3(-6, 12, 0)
	w.fire_weapon(one, mark, "kamikaze")
	settle(1.5)
	check(one.dead and (mark.hp < hp0 or mark.dead), "a Shahed dives into its target (%d -> %d)" % [int(hp0), int(mark.hp)])
	var gun: Dictionary = w.spawn_unit("aaVehicle", land(Vector3(80, 0, 110)), 1)
	var two: Dictionary = drones[1]
	for i in range(6):
		if two.dead: break
		w._fire_gun(gun, two)
		settle(0.5)
	check(two.dead or two.hp < two.max_hp, "flak brings a Shahed down")
	check(w.unit_defs.shahed.pop == 0 and not "shahed" in w.building_defs.tankFactory.trains, "Shaheds cost no army capacity and are never trained on their own")
	# ------------------------------------------------ nations
	var colours := {"blue": "#3b82f6", "red": "#e0483e", "green": "#33b86e", "gold": "#e8a83a"}
	var own: Dictionary = {"blue": "raptor", "red": "df17", "green": "irisT", "gold": "shahedLauncher"}
	var saved: String = w.map.nations[0].color
	for nation in colours:
		w.map.nations[0].color = colours[nation]
		check(Arsenal.identity(w, 0) == nation, "a nation with the %s flag is the %s" % [nation, Arsenal.NATION_NAMES[nation]])
		var ok := true
		for other in own:
			if w.unit_allowed(0, own[other]) != (other == nation): ok = false
		check(ok, "the %s fields its %s and no other nation's weapon" % [Arsenal.NATION_NAMES[nation], w.unit_defs[own[nation]].name])
	w.map.nations[0].color = "#e0483e"
	var stage: int = w.research.progress.classifiedPrograms.stage
	w.research.progress.classifiedPrograms.stage = 0
	check(w.research.blocker("classifiedPrograms").ends_with("only"), "only the Atlantic Federation can research Classified Programs")
	w.research.progress.classifiedPrograms.stage = stage
	w.map.nations[0].color = saved
	for n in w.ai.nations:
		var who: String = Arsenal.identity(w, n.id)
		var fielded: Array = w.ai.train_pool.filter(func(k): return w.unit_allowed(n.id, k) and w.unit_defs[k].has("nation"))
		check(fielded.all(func(k): return w.unit_defs[k].nation == who) and not fielded.is_empty(), "rival %s trains its own weapon (%s)" % [n.name, ", ".join(PackedStringArray(fielded))])
	# ------------------------------------------------ orders
	var movers := {}
	for key in ["himars", "irisT", "fpvTeam", "ewVehicle"]:
		var u: Dictionary = w.spawn_unit(key, land(Vector3(-20 + movers.size() * 8, 0, 20)), 0)
		var goal: Vector3 = w.land_point(u.node.position + Vector3(30, 0, 18), 10.0)
		w.order_move([u], goal)
		movers[key] = [u, goal, u.node.position]
	for i in range(int(25.0 / DT)):
		w._physics_process(DT)
	for key in movers:
		var m: Array = movers[key]
		var moved: float = Vector2(m[0].node.position.x - m[2].x, m[0].node.position.z - m[2].z).length()
		check(not m[0].dead and moved > 15.0, "%s drives where it is sent (%d m)" % [key, int(moved)])
	# ------------------------------------------------ saving
	var keys_saved := []
	var state: Dictionary = w.saves.capture()
	var round_trip = JSON.parse_string(JSON.stringify(state))
	for s in (round_trip.get("units", []) if round_trip is Dictionary else []):
		keys_saved.append(s.key)
	check(keys_saved.has("himars") and keys_saved.has("irisT"), "new units are saved and survive a JSON round trip (%d units)" % keys_saved.size())
	print("UNITS: %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: ", e)
	print("UNITS_100 PASS" if errors.is_empty() else "UNITS_100 FAIL")
	quit(0 if errors.is_empty() else 1)

func Tactics_target(u: Dictionary):
	var enemy: Dictionary = w.spawn_unit("tank", u.node.position + Vector3(10, 0, 0), 1)
	w.rebuild_grid()
	var t = w.Tactics.pick_target(w, u, 60.0)
	w.kill(enemy)
	return t

## Share of `trials` missiles of `type` fired by `owner` that the defences near `defender` stop.
func rate(defender: Dictionary, type: String, owner: int, trials: int) -> float:
	var at: Vector3 = (defender.root.position if defender.has("root") else defender.node.position) + Vector3(10, 30, 0)
	var stopped := 0
	for i in range(trials):
		var m := {"type": type, "owner": owner, "arc": w.missiles.def_of(type).get("arc", false)}
		var hit := false
		for f: float in [0.6, 0.7, 0.8, 0.9]:
			for d in Modern.defenders(w):
				d.ent.intercept_ready = 0.0
				d.ent.aa_reload = 0.0
			if Modern.intercept(w, m, at, f):
				hit = true
				break
		if hit: stopped += 1
	w.intercepts.clear()
	return float(stopped) / trials
