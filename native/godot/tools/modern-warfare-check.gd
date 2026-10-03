extends SceneTree
## Modern warfare (modern_warfare.gd): every new unit is trainable where it
## belongs and locked behind its research; FPV drones and loitering munitions
## are jammed by an EW vehicle; active protection stops missiles; kamikaze
## drones and sea drones die on their strike; a laser burns drones; medics
## heal; a stealth fighter is seen only close in; and missile interception
## follows its odds (measured over hundreds of shots), with layers,
## research and manoeuvring warheads; rivals at war fire missile strikes.
var errors: Array[String] = []
var w: Node
const DT := 1.0 / 30.0
const Modern := preload("res://scripts/modern_warfare.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func complete(key: String) -> void:
	w.research.progress[key].stage = 3
	w.research._recompute()
func settle(seconds: float) -> void:
	for i in range(int(seconds / DT)):
		w.effects._physics_process(DT)
func near(offset: Vector3) -> Vector3:
	var p: Vector3 = w.land_point(w.start + offset, 30.0)
	return p
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
	w.economy.grant_test_resources()
	# Probability/weapon tests require funded ammunition for both sides.
	for n in w.ai.nations: n.money = 1000000.0
	w.diplomacy.declare_war(0, 1)
	# ------------------------------------------------ the units
	var all := Modern.UNITS.keys()
	for key in all:
		var at: Vector3 = w.water_near(w.start, 200) if Modern.UNITS[key].naval else near(Vector3(20, 0, 20))
		var u: Dictionary = w.spawn_unit(key, at, 0)
		var trained_at := ""
		for b in Modern.TRAINS:
			if key in Modern.TRAINS[b]: trained_at = b
		check(not u.is_empty() and u.node.get_child_count() > 0 and key in w.building_defs[trained_at].trains and w.damage_profile.has(key),
			"%s is built with a model and trained at the %s" % [key, trained_at])
		w.kill(u)
	check(w.research.unit_locked("himars") != "" and w.research.unit_locked("fpvTeam") == "", "HIMARS waits for Guided Munitions; FPV teams need no research")
	complete("guidedMunitions")
	check(w.research.unit_locked("himars") == "", "Guided Munitions unlocks HIMARS")
	check(w.research.era_of("directedEnergy") == 4 and w.research.discoveries.has("missileDefence"), "the new discoveries sit in the research tree")
	check(w.ai.train_pool.has("fpvTeam") and w.ai.train_pool.has("himars"), "rival armies train modern units too")
	# ------------------------------------------------ FPV and jamming
	var tank: Dictionary = w.spawn_unit("tank", near(Vector3(60, 0, 0)), 1)
	var fpv: Dictionary = w.spawn_unit("fpvTeam", tank.node.position + Vector3(-20, 0, 0), 0)
	var hp: float = tank.hp
	w.fire_weapon(fpv, tank, "fpv")
	settle(1.5)
	check(tank.hp < hp, "an FPV drone hits a tank (%d -> %d)" % [int(hp), int(tank.hp)])
	var ew: Dictionary = w.spawn_unit("ewVehicle", tank.node.position + Vector3(8, 0, 0), 1)
	var lost_before: int = w.jammed_strikes
	for i in range(40):
		w.fire_weapon(fpv, tank, "fpv")
	settle(1.5)
	var lost: int = w.jammed_strikes - lost_before
	check(lost >= 20 and lost <= 36, "an EW vehicle brings down most FPV drones (%d of 40, ~70%%)" % lost)
	w.kill(ew)
	w.kill(tank)
	tank = w.spawn_unit("tank", near(Vector3(60, 0, 0)), 1)   # the FPV salvo destroyed the first
	# ------------------------------------------------ active protection
	var mine: Dictionary = w.spawn_unit("tank", near(Vector3(-60, 0, 0)), 0)
	var atgm: Dictionary = w.spawn_unit("atgmTeam", mine.node.position + Vector3(20, 0, 0), 1)
	var stopped_before: int = w.aps_intercepts
	for i in range(10):
		mine.aps_ready = 0.0
		w.fire_weapon(atgm, mine, "atgm")
	check(w.aps_intercepts == stopped_before, "without Active Protection nothing is stopped")
	complete("activeProtection")
	for i in range(200):
		mine.aps_ready = 0.0
		w.fire_weapon(atgm, mine, "atgm")
	var stopped: int = w.aps_intercepts - stopped_before
	check(stopped > 70 and stopped < 130, "Active Protection stops about half the missiles (%d of 200)" % stopped)
	var again: int = w.aps_intercepts
	for i in range(40):
		if w.aps_intercepts > again: break
		mine.aps_ready = 0.0
		w.fire_weapon(atgm, mine, "atgm")
	again = w.aps_intercepts
	w.fire_weapon(atgm, mine, "atgm")
	check(w.aps_intercepts == again, "it must rearm before the next intercept")
	settle(2.0)
	mine.hp = mine.max_hp
	# ------------------------------------------------ kamikaze drones
	var loiterer: Dictionary = w.spawn_unit("loiterer", tank.node.position + Vector3(-12, 16, 0), 0)
	hp = tank.hp
	w.fire_weapon(loiterer, tank, "kamikaze")
	settle(1.5)
	check(loiterer.dead and tank.hp < hp, "a loitering munition dives into a tank and is gone (%d -> %d)" % [int(hp), int(tank.hp)])
	var sea: Vector3 = w.water_near(w.start, 200)
	var ship: Dictionary = w.spawn_unit("destroyer", sea, 1)
	var boat: Dictionary = w.spawn_unit("seaDrone", sea + Vector3(5, 0, 0), 0)
	hp = ship.hp
	check(w.effectiveness(boat, tank) == 0.0 and w.effectiveness(boat, ship) > 1.0, "a sea drone attacks ships, not tanks")
	w.fire_weapon(boat, ship, "kamikaze")
	settle(1.5)
	check(boat.dead and ship.hp < hp - 300.0, "a sea drone rams a destroyer (%d -> %d)" % [int(hp), int(ship.hp)])
	# ------------------------------------------------ laser, medic, stealth
	var laser: Dictionary = w.spawn_unit("laserAD", near(Vector3(0, 0, -40)), 0)
	var drone: Dictionary = w.spawn_unit("drone", laser.node.position + Vector3(20, 18, 0), 1)
	drone.air_state = "ready"
	var shots := 0
	while not drone.dead and shots < 6:
		w.fire_weapon(laser, drone, "laser")
		shots += 1
	check(drone.dead and shots <= 3, "a laser burns a drone out of the sky (%d shots)" % shots)
	var jet: Dictionary = w.spawn_unit("jet", laser.node.position + Vector3(30, 26, 0), 1)
	jet.air_state = "ready"
	check(w.effectiveness(laser, jet) < w.effectiveness(laser, drone) and w.effectiveness(laser, tank) == 0.0, "the laser is strongest against drones and cannot hit tanks")
	var medic: Dictionary = w.spawn_unit("medic", near(Vector3(-30, 0, 30)), 0)
	var hurt: Dictionary = w.spawn_unit("soldier", medic.node.position + Vector3(3, 0, 0), 0)
	hurt.hp = 30.0
	for i in range(int(5.0 / DT)):
		Modern.update(w, DT)
	check(hurt.hp >= 55.0 and hurt.hp <= 65.0, "a medic heals a wounded soldier (30 -> %d in 5 s)" % int(hurt.hp))
	var aa: Dictionary = w.spawn_unit("aaVehicle", near(Vector3(-80, 0, -80)), 1)
	var f35: Dictionary = w.spawn_unit("stealthFighter", aa.node.position + Vector3(50, 28, 0), 0)
	f35.air_state = "ready"
	var mig: Dictionary = w.spawn_unit("jet", aa.node.position + Vector3(0, 26, 55), 0)
	mig.air_state = "ready"
	w.rebuild_grid()
	var seen = w.Tactics.pick_target(w, aa, 70.0)
	check(seen != null and is_same(seen, mig), "air defence tracks a jet at 55 m but not a stealth fighter at 50 m")
	f35.node.position = aa.node.position + Vector3(15, 28, 0)
	mig.node.position = aa.node.position + Vector3(0, 26, 60)
	w.rebuild_grid()
	seen = w.Tactics.pick_target(w, aa, 70.0)
	check(seen != null and is_same(seen, f35), "close in, the stealth fighter is seen")
	for u in [f35, mig, aa, jet, laser]: w.kill(u)
	# ------------------------------------------------ missile interception
	var abm: Dictionary = w.spawn_unit("abmLauncher", near(Vector3(0, 0, 0)), 0)
	var rates := {}
	for type in ["cruise", "ballistic", "hypersonic", "nuke"]:
		rates[type] = rate(abm, type, 1, 500)
	print("  one ABM battery: ", rates)
	check(absf(rates.ballistic - 0.86) < 0.06, "an ABM battery stops ~86%% of ballistic missiles (%.2f)" % rates.ballistic)
	check(absf(rates.hypersonic - 0.30) < 0.07, "only ~30%% of hypersonic missiles (%.2f)" % rates.hypersonic)
	check(absf(rates.nuke - 0.55) < 0.08 and rates.cruise > 0.7, "~55%% of ICBMs (%.2f); most cruise missiles (%.2f)" % [rates.nuke, rates.cruise])
	var second: Dictionary = w.spawn_unit("abmLauncher", abm.node.position + Vector3(10, 0, 0), 0)
	var layered := rate(abm, "ballistic", 1, 500)
	check(layered > 0.95, "two batteries in layers stop ~98%% of ballistic missiles (%.2f)" % layered)
	var layered_hyp := rate(abm, "hypersonic", 1, 500)
	check(absf(layered_hyp - 0.51) < 0.08, "and about half the hypersonic ones (%.2f)" % layered_hyp)
	w.kill(second)
	w.kill(abm)
	var sam: Dictionary = w.spawn_unit("samLauncher", near(Vector3(0, 0, 0)), 0)
	var sam_ballistic := rate(sam, "ballistic", 1, 500)
	var sam_cruise := rate(sam, "cruise", 1, 500)
	check(sam_ballistic < 0.18 and sam_cruise > 0.45, "a mobile SAM stops cruise missiles (%.2f) but few ballistic ones (%.2f)" % [sam_cruise, sam_ballistic])
	w.kill(sam)
	# Your missiles against a rival's SAM site, before and after Manoeuvring Warheads.
	var site: Dictionary = w.place_building("samSite", near(Vector3(90, 0, 90)), 1, true)
	var before := rate(site, "ballistic", 0, 600)
	complete("manoeuvringWarheads")
	var after := rate(site, "ballistic", 0, 600)
	check(absf(before - 0.25) < 0.06 and absf(after - 0.15) < 0.05, "a SAM site stops ~25%% of ballistic missiles, ~15%% once they manoeuvre (%.2f -> %.2f)" % [before, after])
	check(Modern.intercept_chance(w, "samSite", {"type": "hypersonic", "owner": 0}, 1) < 0.06, "a SAM site almost never stops a manoeuvring hypersonic missile")
	complete("missileDefence")
	check(absf(Modern.intercept_chance(w, "abmLauncher", {"type": "ballistic", "owner": 1}, 0) - 0.96) < 0.001, "Missile Defence research adds 10% to your interceptors")
	check(str(w.missiles.def_of("hypersonic").desc).contains("Interception: SAM site 8%"), "missile cards show their interception odds")
	# ------------------------------------------------ rival missile strikes
	var nation: Dictionary = w.ai.nations[0]
	var home: Dictionary = w.ai.hq(nation.id)
	nation.money = 5000.0
	var m: Dictionary = w.ai.missile_strike(nation, home, 3.0)
	check(not m.is_empty() and int(m.owner) == nation.id and m.type in ["tactical", "cruise"], "a rival at war fires a %s at you" % str(m.get("type", "nothing")))
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var abm_home: Dictionary = w.spawn_unit("abmLauncher", w.land_point(hq.root.position + Vector3(12, 0, 0), 20.0), 0)
	var attempts: int = w.intercepts.size()
	var hits := 0
	for i in range(8):
		abm_home.intercept_ready = 0.0
		var strike: Dictionary = w.missiles.fly("ballistic", home.root.position + Vector3.UP * 3.0, hq.root.position, nation.id)
		for step in range(int(12.0 / DT)):
			w.missiles._physics_process(DT)
			if not strike in w.missiles.flying: break
	var tried: Array = w.intercepts.slice(attempts)
	for t in tried:
		if t.hit and t.by == "abmLauncher": hits += 1
	check(tried.size() >= 8 and hits >= 5, "the battery at the capital engages every incoming ballistic missile (%d engagements, %d kills)" % [tried.size(), hits])
	# ------------------------------------------------ building on a ruin
	var spot: Vector3 = near(Vector3(-50, 0, 60))
	var old: Dictionary = w.place_building("barracks", spot, 0, true)
	w.destroy_building(old)
	var ruin: Node3D = old.root
	var fresh: Dictionary = w.place_building("barracks", spot, 0, false)
	await process_frame
	check(not is_instance_valid(ruin) and not old in w.buildings and fresh in w.buildings, "building on a ruin clears the charred rubble first")
	print("MODERN_WARFARE PASS" if errors.is_empty() else "MODERN_WARFARE FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)

## Share of `trials` missiles of `type` fired by `owner` that the air defence
## (every defender near `defender`) stops as the missile dives on it.
func rate(defender: Dictionary, type: String, owner: int, trials: int) -> float:
	var at: Vector3 = (defender.root.position if defender.has("root") else defender.node.position) + Vector3(10, 30, 0)
	var stopped := 0
	for i in range(trials):
		for d in Modern.defenders(w):
			d.ent.intercept_ready = 0.0
			d.ent.aa_reload = 0.0
		var m := {"type": type, "owner": owner, "arc": w.missiles.def_of(type).get("arc", false)}
		var hit := false
		for f: float in [0.6, 0.7, 0.8, 0.9]:
			if Modern.intercept(w, m, at, f):
				hit = true
				break
			for d in Modern.defenders(w):
				d.ent.intercept_ready = 0.0
				d.ent.aa_reload = 0.0
		if hit: stopped += 1
	w.intercepts.clear()
	return float(stopped) / trials
