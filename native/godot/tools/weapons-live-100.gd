extends SceneTree
## About a hundred checks on the modern, national and future weapons in live
## combat: forces are set down on an open field (or at sea), the game runs on
## its own loop (targeting, movement, flight, projectiles, missiles,
## interception, microwave pulses, wingmen) and the outcome is checked. Unlike
## units-100.gd nothing fires on command: every shot here is the game's own.
var errors: Array[String] = []
var passed := 0
var w: Node
var made := []
var placed := []
var field: Vector3
var sea: Vector3
const DT := 1.0 / 30.0
const Modern := preload("res://scripts/modern_warfare.gd")
const Future := preload("res://scripts/future_weapons.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## Runs the game for `seconds`, or until `done` returns true. Returns the time taken.
func sim(seconds: float, done := Callable()) -> float:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		t += DT
		if done.is_valid() and done.call():
			break
	return t

func mk(key: String, at: Vector3, owner: int) -> Dictionary:
	var u: Dictionary = w.spawn_unit(key, at, owner)
	made.append(u)
	return u

func building(key: String, at: Vector3, owner: int) -> Dictionary:
	var b: Dictionary = w.place_building(key, dry(at), owner, true)
	placed.append(b)
	return b

## A land point exactly `dist` from `at` (the first bearing that is dry and level).
func beside(at: Vector3, dist: float) -> Vector3:
	for i in range(24):
		var a := i * TAU / 24.0
		var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * dist
		if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
			p.y = w.height_at(p.x, p.z)
			return p
	return at + Vector3(dist, 0, 0)

## `at` itself when it is dry, level ground; otherwise the nearest such point
## (land_point always moves a full `reach` away, so it is only the fallback).
func dry(at: Vector3) -> Vector3:
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 22.0, 30.0]:
		for i in range(12 if r > 0.0 else 1):
			var a := i * TAU / 12.0
			var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
				p.y = w.height_at(p.x, p.z)
				return p
	return w.land_point(at, 20.0)

func near(offset: Vector3) -> Vector3:
	return dry(field + offset)

## Clears the field for the next scenario.
func cleanup() -> void:
	for u in made:
		if not u.dead: w.kill(u)
	for u in w.units:
		if not u.dead and u.key in ["shahed", "wingman"]: w.kill(u)
	for b in placed:
		if not b.dead: w.destroy_building(b)
	made.clear()
	placed.clear()
	for m in w.missiles.flying:
		m.node.queue_free()
	w.missiles.flying.clear()
	sim(1.0)

func complete(key: String) -> void:
	w.research.progress[key].stage = 3
	w.research._recompute()

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260928)   # the same field and the same dice every run
	w.start_match("easy")
	w.fog.enabled = false   # (these checks are of the weapons' reach; tools/fog-of-war-check.gd checks spotting)
	for n in w.ai.nations: n.money = 10000000.0   # (shots cost money: war_costs.gd)
	w.support = null   # (no home front: its forced ceasefires would end the test's wars; war-support-check checks it)
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	w.diplomacy.declare_war(0, 1)
	# An open field well away from every town, and open sea.
	var best := -1.0
	for i in range(80):
		var p: Vector3 = w.land_point(w.start + Vector3(randf_range(-170, 170), 0, randf_range(-170, 170)), 30.0)
		var clear := INF
		for b in w.buildings:
			if not b.dead: clear = minf(clear, b.root.position.distance_to(p))
		if clear > best and w.normal_at(p.x, p.z).y > 0.93 and w.height_at(p.x, p.z) > 2.0:
			best = clear
			field = p
	sea = w.water_near(w.start, 220)
	for u in w.units:
		if not u.dead: w.kill(u)   # the starting armies and fleets would join the fights
	sim(1.0)
	print("  field at %s, %d m from the nearest building; sea at %s" % [str(field), int(best), str(sea)])
	check(best > 45.0, "an open battlefield is found")

	# ---------------------------------------------------------------- FPV drones and jamming
	var tank: Dictionary = mk("tank", near(Vector3(26, 0, 0)), 1)
	var fpv: Dictionary = mk("fpvTeam", near(Vector3.ZERO), 0)
	var own: Dictionary = mk("apc", tank.node.position + Vector3(0, 0, 6), 0)   # a friendly vehicle beside the target
	own.dmg = 0.0
	tank.dmg = 0.0   # the tank holds its fire: only the drones' own blasts could touch the APC
	var shots0: int = w.shots_fired
	var hp0: float = tank.hp
	sim(30.0, func(): return tank.dead)
	var open_loss: float = hp0 - maxf(tank.hp, 0.0)
	check(tank.dead or tank.hp < hp0, "an FPV team engages a tank on its own (%d -> %d)" % [int(hp0), int(tank.hp)])
	check(w.shots_fired > shots0, "its drones are launched")
	check(own.hp >= own.max_hp, "its strikes spare a friendly vehicle beside the target")
	cleanup()
	tank = mk("tank", near(Vector3(26, 0, 0)), 1)
	fpv = mk("fpvTeam", near(Vector3.ZERO), 0)
	var ewv: Dictionary = mk("ewVehicle", near(Vector3(34, 0, 6)), 1)
	tank.dmg = 0.0   # the tank holds its fire, so the team keeps launching
	var lost0: int = w.jammed_strikes
	hp0 = tank.hp
	sim(30.0, func(): return tank.dead)
	var jammed_loss: float = hp0 - maxf(tank.hp, 0.0)
	check(w.jammed_strikes > lost0, "an enemy EW vehicle brings FPV drones down in battle (%d lost)" % (w.jammed_strikes - lost0))
	check(jammed_loss < open_loss or open_loss == 0.0, "the jammed tank suffers less (%d vs %d)" % [int(jammed_loss), int(open_loss)])
	cleanup()

	# ---------------------------------------------------------------- anti-tank missiles and active protection
	var mine: Dictionary = mk("tank", near(Vector3(20, 0, 0)), 0)
	var atgm: Dictionary = mk("atgmTeam", near(Vector3.ZERO), 1)
	mine.dmg = 0.0
	# Armour enough to take every missile of the half minute (a plain tank dies
	# after two or three, leaving too few throws of the dice to judge by).
	mine.max_hp = 3000.0
	mine.hp = 3000.0
	hp0 = mine.hp
	sim(30.0)
	check(mine.hp < hp0 or mine.dead, "an ATGM team hits a tank from 20 m (%d -> %d)" % [int(hp0), int(mine.hp)])
	var plain_loss: float = hp0 - maxf(mine.hp, 0.0)
	cleanup()
	complete("activeProtection")
	mine = mk("tank", near(Vector3(20, 0, 0)), 0)
	atgm = mk("atgmTeam", near(Vector3.ZERO), 1)
	mine.dmg = 0.0   # the tank holds its fire, so the team keeps firing
	mine.max_hp = 3000.0
	mine.hp = 3000.0
	var aps0: int = w.aps_intercepts
	hp0 = mine.hp
	sim(30.0)   # about six missiles: half are stopped, one every 4 s
	check(w.aps_intercepts > aps0, "active protection blows up missiles in battle (%d)" % (w.aps_intercepts - aps0))
	check(hp0 - maxf(mine.hp, 0.0) <= plain_loss, "the protected tank loses less (%d vs %d)" % [int(hp0 - maxf(mine.hp, 0.0)), int(plain_loss)])
	cleanup()

	# ---------------------------------------------------------------- MANPADS and medics
	var team: Dictionary = mk("manpads", near(Vector3.ZERO), 0)
	var heli: Dictionary = mk("helicopter", near(Vector3(20, 0, 0)), 1)
	heli.air_state = "ready"
	var target_hut: Dictionary = building("barracks", field + Vector3(-12, 0, 20), 0)
	w.order_attack([heli], target_hut)
	hp0 = heli.hp
	sim(20.0, func(): return heli.dead)
	check(heli.dead or heli.hp < hp0, "MANPADS engage a helicopter on their own (%d -> %d)" % [int(hp0), int(maxf(heli.hp, 0))])
	check(not team.dead, "the MANPADS team survives the pass")
	cleanup()
	var medic: Dictionary = mk("medic", near(Vector3.ZERO), 0)
	var hurt := []
	for i in range(3):
		var s: Dictionary = mk("soldier", near(Vector3(3 + i * 2, 0, 2)), 0)
		s.hp = 25.0
		hurt.append(s)
	sim(10.0)
	check(hurt.all(func(s): return s.hp > 25.0), "a medic treats a wounded squad in the field")
	check(hurt.any(func(s): return s.hp >= 40.0), "the worst hurt recover first (%s)" % str(hurt.map(func(s): return int(s.hp))))
	check(not medic.dead and medic.hp == medic.max_hp, "the medic is unhurt")
	cleanup()

	# ---------------------------------------------------------------- long-range fires
	var hex: float = float(w.map.logistics.hexRadius) * sqrt(3.0)
	var himars: Dictionary = mk("himars", near(Vector3.ZERO), 0)
	var depot: Dictionary = building("barracks", field + Vector3(hex * 3.0, 0, 0), 1)
	hp0 = depot.hp
	sim(30.0, func(): return depot.dead or depot.hp < hp0 - 150.0)
	check(depot.hp < hp0 or depot.dead, "HIMARS strikes a barracks three hexes away on its own (%d -> %d)" % [int(hp0), int(depot.hp)])
	check(himars.node.position.distance_to(depot.root.position) > hex * 2.0, "it fires from a distance, without closing in")
	cleanup()
	var df: Dictionary = mk("df17", near(Vector3.ZERO), 0)
	var far_hq: Dictionary = building("barracks", field + Vector3(hex * 5.0, 0, 20), 1)
	var launched0: int = w.missiles.flying.size()
	hp0 = far_hq.hp
	var fired_df := false
	sim(40.0, func():
		if w.missiles.flying.any(func(m): return m.type == "df17"): fired_df = true
		return far_hq.hp < hp0 or far_hq.dead)
	check(fired_df or far_hq.hp < hp0, "a DF-17 fires its glide vehicle at a target five hexes away")
	check(far_hq.hp < hp0 or far_hq.dead, "the glide vehicle lands on target (%d -> %d)" % [int(hp0), int(far_hq.hp)])
	cleanup()
	var df2: Dictionary = mk("df17", near(Vector3.ZERO), 1)
	var abm: Dictionary = mk("abmLauncher", near(Vector3(hex * 4.0, 0, 0)), 0)
	var mark: Dictionary = building("barracks", field + Vector3(hex * 4.5, 0, 12), 0)
	var tries0: int = w.intercepts.size()
	sim(40.0, func(): return w.intercepts.size() > tries0)
	var tried: Array = w.intercepts.slice(tries0)
	check(tried.any(func(t): return t.type == "df17" and t.by == "abmLauncher"), "a missile defence battery tries to stop a rival's DF-17 (%s)" % str(tried.map(func(t): return "%s:%s" % [t.by, t.hit])))
	cleanup()

	# ---------------------------------------------------------------- air defence against drones
	var laser: Dictionary = mk("laserAD", near(Vector3.ZERO), 0)
	var drone: Dictionary = mk("drone", near(Vector3(40, 0, 0)), 1)
	var hut: Dictionary = building("barracks", field + Vector3(-10, 0, -16), 0)
	w.order_attack([drone], hut)
	sim(15.0, func(): return drone.dead)
	check(drone.dead, "a laser burns an attacking drone out of the sky")
	check(hut.hp >= hut.max_hp - 60.0, "before it does much harm (%d of %d)" % [int(hut.hp), int(hut.max_hp)])
	cleanup()
	var iris: Dictionary = mk("irisT", near(Vector3.ZERO), 0)
	var raid: Dictionary = mk("jet", near(Vector3(70, 0, 0)), 1)
	var shed: Dictionary = building("barracks", field + Vector3(-6, 0, 18), 0)
	w.order_attack([raid], shed)
	sim(20.0, func(): return raid.dead)
	check(raid.dead, "IRIS-T shoots down a strike jet")
	cleanup()

	# ---------------------------------------------------------------- loitering munitions, sea drones
	var prey: Dictionary = mk("tank", near(Vector3(60, 0, 0)), 1)
	var loiter: Dictionary = mk("loiterer", near(Vector3.ZERO), 0)
	w.order_attack([loiter], prey)
	hp0 = prey.hp
	sim(25.0, func(): return loiter.dead)
	sim(2.0)   # the warhead lands
	check(loiter.dead, "a loitering munition flies to its target and dives in")
	check(prey.hp < hp0 or prey.dead, "the tank is hit (%d -> %d)" % [int(hp0), int(prey.hp)])
	cleanup()
	# Sea drones attack in packs: a destroyer's guns stop a lone one.
	var ship: Dictionary = mk("destroyer", sea, 1)
	var pack := []
	for i in range(3):
		var start_at = w.water_near(sea + Vector3(40, 0, i * 8 - 8), 60)
		pack.append(mk("seaDrone", start_at if start_at != null else sea + Vector3(30, 0, i * 6), 0))
	w.order_attack(pack, ship)
	hp0 = ship.hp
	var dry := true
	sim(30.0, func():
		for b in pack:
			if not b.dead and not w.is_water(b.node.position, -0.2): dry = false
		return pack.all(func(b): return b.dead) or ship.dead)
	sim(2.0)
	check(pack.all(func(b): return b.dead) or ship.dead, "a pack of sea drones closes on a destroyer (%d of 3 spent)" % pack.filter(func(b): return b.dead).size())
	check(dry, "they never leave the water on the way")
	check(ship.hp < hp0 - 200.0 or ship.dead, "the destroyer is badly hurt (%d -> %d)" % [int(hp0), int(maxf(ship.hp, 0.0))])
	cleanup()

	# ---------------------------------------------------------------- stealth and SEAD
	var aa: Dictionary = mk("aaVehicle", near(Vector3.ZERO), 1)
	var f35: Dictionary = mk("stealthFighter", near(Vector3(-80, 0, 0)), 0)
	w.order_attack([f35], aa)
	var seen_at := -1.0
	sim(25.0, func():
		if seen_at < 0.0 and aa.enemy != null and is_same(aa.enemy, f35):
			seen_at = w.flat_distance(aa, f35)
		return aa.dead or f35.dead)
	check(seen_at < 0.0 or seen_at <= aa.range * 0.45, "flak sees a stealth fighter only close in (at %d m of its %d)" % [int(seen_at), int(aa.range)])
	check(aa.hp < aa.max_hp or aa.dead, "the stealth fighter strikes the flak vehicle")
	cleanup()
	var sam: Dictionary = mk("samLauncher", near(Vector3.ZERO), 1)
	var raptor: Dictionary = mk("raptor", near(Vector3(-90, 0, 0)), 0)
	w.order_attack([raptor], sam)
	hp0 = sam.hp
	sim(30.0, func(): return sam.dead)
	check(sam.dead or sam.hp < hp0 * 0.5, "an F-22 on a SEAD mission knocks out a mobile SAM (%d -> %d)" % [int(hp0), int(sam.hp)])
	check(not raptor.dead, "and flies home")
	cleanup()
	var target_b: Dictionary = building("barracks", field + Vector3(40, 0, 0), 1)
	var raider: Dictionary = mk("raider", near(Vector3(-100, 0, 0)), 0)
	w.order_attack([raider], target_b)
	hp0 = target_b.hp
	sim(40.0, func(): return target_b.dead or target_b.hp < hp0 - 300.0)
	check(target_b.dead or target_b.hp < hp0, "a B-21 flies a bombing run on a barracks (%d -> %d)" % [int(hp0), int(target_b.hp)])
	cleanup()

	# ---------------------------------------------------------------- the Shahed swarm
	var launcher: Dictionary = mk("shahedLauncher", near(Vector3.ZERO), 1)
	var aim: Dictionary = building("barracks", field + Vector3(hex * 3.5, 0, 0), 0)
	hp0 = aim.hp
	sim(10.0, func(): return w.units.any(func(u): return u.key == "shahed" and not u.dead))   # reloads start within 3 s
	var swarm: Array = w.units.filter(func(u): return u.key == "shahed" and not u.dead and u.owner == 1)
	check(swarm.size() == Arsenal.SWARM, "a Shahed launcher fires its swarm at a barracks in range (%d)" % swarm.size())
	sim(100.0, func(): return swarm.all(func(d): return d.dead))
	check(swarm.all(func(d): return d.dead), "every Shahed is spent on the target, or runs out of fuel")
	check(aim.hp < hp0 or aim.dead, "the swarm hits the barracks (%d -> %d)" % [int(hp0), int(aim.hp)])
	cleanup()
	launcher = mk("shahedLauncher", near(Vector3.ZERO), 1)
	aim = building("barracks", field + Vector3(hex * 3.5, 0, 0), 0)
	var hpm: Dictionary = mk("hpmVehicle", w.land_point(aim.root.position + Vector3(-14, 0, 8), 12.0), 0)
	var fried0: int = w.hpm_kills
	hp0 = aim.hp
	sim(60.0, func(): return w.hpm_kills - fried0 >= Arsenal.SWARM)
	check(w.hpm_kills - fried0 >= Arsenal.SWARM, "a microwave weapon fries a whole incoming swarm (%d)" % (w.hpm_kills - fried0))
	check(aim.hp >= hp0 - 1.0, "the barracks it guards is untouched (%d -> %d)" % [int(hp0), int(aim.hp)])
	cleanup()
	var guard: Dictionary = mk("tank", near(Vector3.ZERO), 0)
	var hpm2: Dictionary = mk("hpmVehicle", near(Vector3(-6, 0, 8)), 0)
	var lm: Dictionary = mk("loiterer", near(Vector3(80, 0, 0)), 1)
	w.order_attack([lm], guard)
	hp0 = guard.hp
	sim(25.0, func(): return lm.dead)
	check(lm.dead and guard.hp >= hp0 - 1.0, "an enemy loitering munition is fried before it reaches the tank")
	cleanup()

	# ---------------------------------------------------------------- warships
	var shore: Dictionary = building("barracks", dry(sea), 1)   # on the nearest shore
	var rail: Dictionary = mk("railgunShip", sea, 0)
	hp0 = shore.hp
	sim(25.0, func(): return shore.hp < hp0 - 150.0 or shore.dead)
	check(shore.hp < hp0 or shore.dead, "a railgun cruiser shells a barracks on the shore (%d -> %d, %d m)" % [int(hp0), int(shore.hp), int(rail.node.position.distance_to(shore.root.position))])
	cleanup()
	var hunted: Dictionary = mk("gunboat", sea, 1)
	var orca: Dictionary = mk("orca", w.water_near(sea + Vector3(18, 0, 0), 40) if w.water_near(sea + Vector3(18, 0, 0), 40) != null else sea + Vector3(14, 0, 0), 0)
	hp0 = hunted.hp
	sim(20.0, func(): return hunted.dead)
	check(hunted.hp < hp0 or hunted.dead, "an uncrewed submarine torpedoes a gunboat on its own (%d -> %d)" % [int(hp0), int(hunted.hp)])
	check(not orca.dead, "the submarine survives")
	cleanup()

	# ---------------------------------------------------------------- the sixth-generation fighter
	var six: Dictionary = mk("sixthGen", near(Vector3(-60, 0, 0)), 0)
	var mates: Array = Future.escort(w, six)
	var bandit: Dictionary = mk("jet", near(Vector3(60, 0, 0)), 1)
	w.order_attack([six], bandit)
	sim(25.0, func(): return bandit.dead)
	check(bandit.dead, "a sixth-generation fighter and its wingmen shoot down a jet")
	var gaps: Array = []
	var closest := [INF, INF]
	sim(20.0, func():
		for i in range(2):
			closest[i] = minf(closest[i], Vector2(mates[i].node.position.x - six.node.position.x, mates[i].node.position.z - six.node.position.z).length())
		return false)
	gaps = closest.map(func(g): return int(g))
	var alive: Array = range(2).filter(func(i): return not mates[i].dead)
	check(not alive.is_empty() and alive.all(func(i): return gaps[i] < 45), "its surviving wingmen come back to fly with it after the fight (closest %s m)" % str(alive.map(func(i): return gaps[i])))
	var bomber: Dictionary = mk("bomber", near(Vector3(80, 0, 40)), 1)
	w.order_attack([six], bomber)
	sim(1.0)
	check(mates.all(func(m): return m.enemy == null or is_same(m.enemy, bomber)), "the wingmen take its new target")
	cleanup()

	# ---------------------------------------------------------------- every weapon fights on its own
	# Each unit, left idle, with a fitting enemy inside its range: it must open
	# fire by itself and hurt it within 25 s.
	var duels := {
		"fpvTeam": ["apc", 0.7], "atgmTeam": ["tank", 0.7], "manpads": ["helicopter", 0.6], "medic": ["soldier", 0.6],
		"himars": ["tank", 0.6], "laserAD": ["drone", 0.5], "irisT": ["jet", 0.5], "df17": ["tank", 0.5],
		"shahedLauncher": ["tank", 0.5], "loiterer": ["tank", 0.4], "stealthFighter": ["tank", 0.5], "raptor": ["jet", 0.5],
		"raider": ["tank", 0.4], "sixthGen": ["jet", 0.5], "wingman": ["jet", 0.5],
		"seaDrone": ["gunboat", 0.4], "railgunShip": ["gunboat", 0.5], "orca": ["gunboat", 0.5],
	}
	for key in duels:
		var naval: bool = key in w.NAVAL
		var at: Vector3 = sea if naval else near(Vector3.ZERO)
		var u: Dictionary = mk(key, at, 0)
		var reach: float = minf(u.range * float(duels[key][1]), 60.0)
		var foe_key: String = duels[key][0]
		var foe_at: Vector3 = at + Vector3(reach, 0, 0)
		if foe_key in w.NAVAL:
			var wet = w.water_near(foe_at, 40)
			foe_at = wet if wet != null else sea + Vector3(12, 0, 0)
		else:
			foe_at = beside(at, reach)
		var foe: Dictionary = mk(foe_key, foe_at, 1)
		foe.dmg = 0.0   # the target holds its fire: the question is whether the unit opens fire, not who wins
		if foe.get("fly", false): foe.air_state = "ready"
		if u.get("fly", false):
			u.air_state = "ready"
		var start_hp: float = foe.hp
		sim(70.0 if u.get("fly", false) else 25.0, func(): return foe.dead or foe.hp < start_hp)   # a jet may have to chase its prey down
		sim(2.0)
		check(foe.dead or foe.hp < start_hp, "%s opens fire on its own at a %s %d m away (%d -> %d)" % [key, foe_key, int(reach), int(start_hp), int(maxf(foe.hp, 0.0))])
		cleanup()

	# ---------------------------------------------------------------- what they must not do
	var mp: Dictionary = mk("manpads", near(Vector3.ZERO), 0)
	var armour: Dictionary = mk("tank", near(Vector3(18, 0, 0)), 1)
	armour.dmg = 0.0   # a harmless tank, to see whether the MANPADS waste missiles on it
	sim(8.0)
	check(armour.hp >= armour.max_hp, "MANPADS never fire at a tank")
	cleanup()
	var doc: Dictionary = mk("medic", near(Vector3.ZERO), 0)
	var wreck: Dictionary = mk("tank", near(Vector3(4, 0, 0)), 0)
	wreck.hp = 100.0
	sim(6.0)
	check(wreck.hp <= 100.0, "a medic does not mend tanks")
	cleanup()
	var own_hpm: Dictionary = mk("hpmVehicle", near(Vector3.ZERO), 0)
	var own_drone: Dictionary = mk("loiterer", near(Vector3(10, 0, 0)), 0)
	sim(8.0)
	check(not own_drone.dead, "a microwave weapon spares its own side's drones")
	cleanup()
	var hunter: Dictionary = mk("destroyer", sea, 1)
	var quiet: Dictionary = mk("orca", w.water_near(sea + Vector3(hunter.range * 0.75, 0, 0), 40) if w.water_near(sea + Vector3(hunter.range * 0.75, 0, 0), 40) != null else sea + Vector3(18, 0, 0), 0)
	quiet.dmg = 0.0   # holds its fire: can the destroyer find it?
	w.rebuild_grid()
	var seen = w.Tactics.pick_target(w, hunter, maxf(hunter.aggro, hunter.range))
	check(seen == null or not is_same(seen, quiet), "a destroyer cannot find an uncrewed submarine at three quarters of its range")
	cleanup()
	var flak: Dictionary = mk("aaVehicle", near(Vector3.ZERO), 1)
	var leader: Dictionary = mk("sixthGen", near(Vector3(flak.range * 0.5, 0, 0)), 0)
	leader.air_state = "ready"
	var pair: Array = Future.escort(w, leader)
	w.rebuild_grid()
	var first = w.Tactics.pick_target(w, flak, maxf(flak.aggro, flak.range))
	check(first != null and first.key == "wingman", "enemy flak locks on to the wingmen, not the stealthy fighter")
	cleanup()

	# ---------------------------------------------------------------- jamming in battle
	var jam_hut: Dictionary = building("barracks", field + Vector3(0, 0, 0), 0)
	var gunner: Dictionary = mk("drone", near(Vector3(30, 0, 0)), 1)
	w.order_attack([gunner], jam_hut)
	var hut_hp: float = jam_hut.hp
	sim(35.0)
	var open_harm: float = hut_hp - jam_hut.hp
	cleanup()
	jam_hut = building("barracks", field + Vector3(0, 0, 0), 0)
	gunner = mk("drone", near(Vector3(30, 0, 0)), 1)
	mk("ewVehicle", near(Vector3(-8, 0, 10)), 0)
	w.order_attack([gunner], jam_hut)
	hut_hp = jam_hut.hp
	sim(35.0)
	var jammed_harm: float = hut_hp - jam_hut.hp
	check(open_harm > 0.0 and jammed_harm < open_harm * 0.7, "an EW vehicle blunts a drone's guns (%d harm jammed vs %d)" % [int(jammed_harm), int(open_harm)])
	cleanup()
	var lm_target: Dictionary = mk("tank", near(Vector3.ZERO), 0)
	mk("ewVehicle", near(Vector3(-6, 0, 6)), 0)
	var lost_before: int = w.jammed_strikes
	for i in range(6):
		var l: Dictionary = mk("loiterer", near(Vector3(70, 0, i * 6 - 15)), 1)
		w.order_attack([l], lm_target)
	sim(30.0)
	check(w.jammed_strikes > lost_before, "jamming brings down loitering munitions in battle (%d of 6)" % (w.jammed_strikes - lost_before))
	cleanup()

	# ---------------------------------------------------------------- air defence against missiles in flight
	var zap: Dictionary = mk("laserAD", near(Vector3.ZERO), 0)
	var zone: Dictionary = building("barracks", field + Vector3(12, 0, 12), 0)
	var tries: int = w.intercepts.size()
	var cm: Dictionary = w.missiles.fly("cruise", field + Vector3(300, 3, 0), zone.root.position, 1)
	sim(15.0, func(): return not cm in w.missiles.flying)
	check(w.intercepts.slice(tries).any(func(t): return t.by == "laserAD"), "a laser fires at a cruise missile passing over it")
	cleanup()
	var rg: Dictionary = mk("railgunShip", sea, 0)
	var coast: Dictionary = building("barracks", w.land_point(sea, 80.0), 0)
	tries = w.intercepts.size()
	var hm: Dictionary = w.missiles.fly("hypersonic", coast.root.position + Vector3(400, 3, 200), coast.root.position, 1)
	sim(10.0, func(): return not hm in w.missiles.flying)
	check(w.intercepts.slice(tries).any(func(t): return t.by == "railgunShip"), "a railgun cruiser fires at a hypersonic missile heading for the coast")
	cleanup()
	var shield: Dictionary = mk("irisT", near(Vector3.ZERO), 0)
	var cover: Dictionary = building("barracks", field + Vector3(hex * 3.0, 0, 0), 0)
	var lnch: Dictionary = mk("shahedLauncher", near(Vector3(hex * 6.5, 0, 0)), 1)
	var iris_fired := false
	var t_launch: float = w.game_time
	sim(15.0, func(): return w.units.any(func(u): return u.key == "shahed" and not u.dead))
	var wave: Array = w.units.filter(func(u): return u.key == "shahed" and not u.dead)
	var aloft0: int = w.shots_fired
	sim(100.0, func():
		if shield.enemy != null and shield.enemy.get("key", "") == "shahed": iris_fired = true
		return wave.all(func(d): return d.dead))
	check(not wave.is_empty() and wave.all(func(d): return d.dead), "no Shahed of the wave is left flying (%d launched)" % wave.size())
	check(iris_fired or float(shield.get("last_fire", -1.0)) > t_launch, "IRIS-T engages the swarm")
	cleanup()

	# ---------------------------------------------------------------- the national weapons at work
	var r_jet: Dictionary = mk("jet", near(Vector3(60, 0, 0)), 1)
	var f22: Dictionary = mk("raptor", near(Vector3(-40, 0, 0)), 0)
	r_jet.air_state = "ready"
	w.order_attack([r_jet], f22)
	w.order_attack([f22], r_jet)
	sim(25.0, func(): return r_jet.dead or f22.dead)
	check(r_jet.dead and not f22.dead, "an F-22 wins a dogfight with a strike jet")
	check(f22.hp > f22.max_hp * 0.5, "with little damage (%d of %d)" % [int(f22.hp), int(f22.max_hp)])
	cleanup()
	var guarded: Dictionary = building("barracks", field + Vector3(30, 0, 0), 1)
	var guard_site: Dictionary = building("samSite", field + Vector3(50, 0, 30), 1)
	var b21: Dictionary = mk("raider", near(Vector3(-110, 0, 0)), 0)
	w.order_attack([b21], guarded)
	hp0 = guarded.hp
	sim(40.0, func(): return guarded.dead or guarded.hp < hp0 - 300.0)
	check(not b21.dead and b21.hp > b21.max_hp * 0.5, "a B-21 bombs a target under a SAM site's umbrella and survives (%d of %d)" % [int(b21.hp), int(b21.max_hp)])
	check(guarded.hp < hp0 or guarded.dead, "the target is hit (%d -> %d)" % [int(hp0), int(guarded.hp)])
	cleanup()
	var carrier: Dictionary = mk("destroyer", sea, 1)
	var dfc: Dictionary = mk("df17", w.land_point(sea, 90.0), 0)
	hp0 = carrier.hp
	sim(35.0, func(): return carrier.dead)
	check(carrier.dead or carrier.hp < hp0 * 0.3, "a DF-17 on the coast wrecks a destroyer at sea (%d -> %d)" % [int(hp0), int(maxf(carrier.hp, 0.0))])
	cleanup()

	# ---------------------------------------------------------------- missile strikes on the capital
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var nation: Dictionary = w.ai.nations[0]
	var home: Dictionary = w.ai.hq(nation.id)
	var battery: Dictionary = mk("abmLauncher", w.land_point(hq.root.position + Vector3(14, 0, 0), 20.0), 0)
	var iris2: Dictionary = mk("irisT", w.land_point(hq.root.position + Vector3(-14, 0, 0), 20.0), 0)
	var n0: int = w.intercepts.size()
	var landed := 0
	for i in range(6):
		var strike: Dictionary = w.missiles.fly(["ballistic", "cruise", "hypersonic"][i % 3], home.root.position + Vector3.UP * 3.0, hq.root.position, nation.id)
		sim(14.0, func(): return not strike in w.missiles.flying)
		sim(6.5)   # the batteries reload (an ABM takes 6 s) before the next launch
	var fought: Array = w.intercepts.slice(n0)
	check(fought.size() >= 6, "every rival missile at the capital meets an interceptor (%d attempts for 6 missiles)" % fought.size())
	check(fought.any(func(t): return t.by == "abmLauncher") and fought.any(func(t): return t.by == "irisT"), "both batteries take part")
	check(fought.any(func(t): return t.hit), "some are shot down (%d)" % fought.filter(func(t): return t.hit).size())
	cleanup()
	complete("goldenDome")
	var cash: float = w.economy.res.money
	n0 = w.intercepts.size()
	for i in range(4):
		var strike: Dictionary = w.missiles.fly("ballistic", home.root.position + Vector3.UP * 3.0, hq.root.position, nation.id)
		sim(14.0, func(): return not strike in w.missiles.flying)
	fought = w.intercepts.slice(n0)
	check(fought.filter(func(t): return t.by == "goldenDome").size() == 4, "Golden Dome fires on every missile (%d of 4)" % fought.filter(func(t): return t.by == "goldenDome").size())
	check(w.economy.res.money < cash, "and charges the treasury")
	w.research.progress.goldenDome.stage = 0
	w.research._recompute()

	# ---------------------------------------------------------------- rival nations field them
	var red: Dictionary = {}
	for n in w.ai.nations:
		if Arsenal.identity(w, n.id) == "red": red = n
	if not red.is_empty():
		var red_home: Dictionary = w.ai.hq(red.id)
		var factory: Dictionary = building("tankFactory", red_home.root.position + Vector3(30, 0, 30), red.id)
		var fields: Dictionary = building("airfield", red_home.root.position + Vector3(-30, 0, 30), red.id)
		var before: int = w.units.filter(func(u): return u.owner == red.id and u.key == "df17").size()
		check(w.ai.deploy(red.id, "df17"), "the Crimson Empire's factory turns out a DF-17")
		check(w.units.filter(func(u): return u.owner == red.id and u.key == "df17").size() == before + 1, "and it stands by the factory")
		var wing0: int = w.units.filter(func(u): return u.owner == red.id and u.key == "wingman" and not u.dead).size()
		check(w.ai.deploy(red.id, "sixthGen") and w.units.filter(func(u): return u.owner == red.id and u.key == "wingman" and not u.dead).size() == wing0 + 2, "its J-36 takes off with two wingmen")
		check(not w.ai.train_pool.filter(func(k): return w.unit_allowed(red.id, k) and str(w.unit_defs[k].get("nation", "")) == "blue").size() > 0, "it never fields the Atlantic Federation's F-22")
	cleanup()

	# ---------------------------------------------------------------- saving the new forces
	var saved_six: Dictionary = mk("sixthGen", near(Vector3(-40, 0, 0)), 0)
	var saved_mates: Array = Future.escort(w, saved_six)
	mk("hpmVehicle", near(Vector3.ZERO), 0)
	mk("irisT", near(Vector3(8, 0, 0)), 0)
	var data: Dictionary = w.saves.capture()
	var back = JSON.parse_string(JSON.stringify(data))
	var keys: Array = back.units.map(func(s): return s.key)
	check(keys.has("sixthGen") and keys.has("hpmVehicle") and keys.has("irisT") and keys.count("wingman") >= 2, "a save keeps the new forces")
	w.saves.restore(back)
	var restored: Array = w.units.filter(func(u): return not u.dead and u.key == "wingman" and u.owner == 0)
	sim(2.0)
	check(not restored.is_empty() and restored.all(func(m): return m.get("leader") != null and not m.leader.dead), "after loading, the wingmen fly with their fighter again")
	print("\nWEAPONS_LIVE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("WEAPONS_LIVE PASS" if errors.is_empty() else "WEAPONS_LIVE FAIL")
	quit(0 if errors.is_empty() else 1)
