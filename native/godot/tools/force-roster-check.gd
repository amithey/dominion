extends SceneTree
const C := preload("res://scripts/force_catalog.gd")
const F := preload("res://scripts/factions.gd")
const N := preload("res://scripts/national_variants.gd")
var w: Node
var passed := 0
var errors: Array[String] = []
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
	preload("res://tools/test_kit.gd").quiet(w, ["fog", "un", "wmd"])
	var original: Dictionary = w.map.nations[0].duplicate(true)
	var entries := 0
	for index in range(F.IDS.size()):
		w.map.nations[0] = F.nation(index, true)
		for key in C.ROLES:
			var legal: bool = str(F.IDS[index]) in C.operators(key)
			check(w.unit_allowed(0, key) == legal and N.fields(key, F.ARSENALS[index]) == legal, "%s / %s operator and starting-roster gate" % [F.IDS[index], key])
			if legal:
				entries += 1
				check(N.name_for(w, 0, key) == str(C.NAMES.get(key, {}).get(F.IDS[index], C.ROLES[key].name)), "%s / %s national model name" % [F.IDS[index], key])
	check(entries == 139, "139 operator-role choices across all 28 identities")
	w.map.nations[0].id = "future_nation"
	check(C.ROLES.keys().all(func(key): return not w.unit_allowed(0, key)), "new country ID does not inherit an arsenal")
	w.map.nations[0].units = ["scoutTeam", "ifv"]
	w.map.nations[0].unit_names = {"ifv": "Custom ICV"}
	check(w.unit_allowed(0, "ifv") and N.name_for(w, 0, "ifv") == "Custom ICV" and not w.unit_allowed(0, "missileBoat"), "explicit future-country roster and naming override")
	w.map.nations[0] = original
	w.map.nations[0].id = "south_korea"
	check(N.name_for(w, 0, "apc") == "K808 APC" and N.name_for(w, 0, "ifv") == "K21 IFV", "K808 carrier and K21 IFV have separate choices")
	w.map.nations[0] = original
	for key in C.ROLES:
		var need: String = str(w.unit_defs[key].get("requires", ""))
		check(need == "" or w.research.discoveries.has(need), "%s research dependency exists" % key)
		check(key in w.building_defs[C.HOME[key]].trains and key in w.ai.train_pool, "%s player and rival production registered" % key)
		var model: Node3D = w.display_model(key)
		check(model != null and w.model_bounds(model).size.length() > 0.5, "%s real model for portrait" % key)
		if model != null: model.free()
	var centre: Vector3 = w.start + Vector3(28, 0, 22)
	var training: Dictionary = w.place_building("barracks", centre + Vector3(14, 0, -12), 0, true)
	for resource in w.economy.res: w.economy.res[resource] = 100000.0
	w.economy.pop_cap = 10000
	w.queue_unit(training, "mortarTeam")
	check(training.queue == ["mortarTeam"], "portable mortar enters a paid barracks production queue")
	var mortar_count: int = w.units.filter(func(u): return u.key == "mortarTeam").size()
	w.update_training(100.0)
	check(training.queue.is_empty() and w.units.filter(func(u): return u.key == "mortarTeam").size() == mortar_count + 1, "completed barracks order deploys a mortar team")
	var factory: Dictionary = w.place_building("tankFactory", centre + Vector3(14, 0, -28), 0, true)
	w.queue_unit(factory, "ifv")
	check(factory.queue.is_empty(), "new IFV cannot bypass incomplete composite-armour research")
	w.research.progress.compositeArmor = {"stage": 3, "work": 0, "paid": false}
	w.research._recompute()
	w.queue_unit(factory, "ifv")
	check(factory.queue == ["ifv"], "national IFV enters production after its research")
	w.queue_unit(factory, "heavyAPC")
	check(factory.queue == ["ifv"], "foreign heavy carrier is refused by the actual production command")
	w.cancel_queued(factory, 0)
	var infantry: Dictionary = w.spawn_unit("soldier", centre + Vector3(0, 0, 22), 1)
	var tank: Dictionary = w.spawn_unit("tank", centre + Vector3(10, 0, 22), 1)
	var made := {}
	for key in C.ROLES:
		var at: Vector3 = w.water_near(w.start, 220) if key == "missileBoat" else centre
		made[key] = w.spawn_unit(key, at, 0)
		check(made[key].speed > 0 and made[key].max_hp > 0, "%s deploys with equipment and movement" % key)
	check(w.target_class(made.mortarTeam) == "infantry" and w.target_class(made.ifv) == "armor" and w.target_class(made.reconVehicle) == "light", "combat target classes distinguish crews, armour and scouts")
	check(w.effectiveness(made.machineGunTeam, infantry) > 1.0 and w.effectiveness(made.machineGunTeam, tank) == 0.0, "machine gun counters infantry without piercing tanks")
	check(w.effectiveness(made.heavyAPC, tank) == 0.0 and made.heavyAPC.max_hp > made.ifv.max_hp, "heavy carrier trades anti-tank firepower for protection")
	check(w.fog.sight_of(made.scoutTeam) > w.fog.sight_of(infantry) and w.fog.sight_of(made.scoutHelicopter) > w.fog.sight_of(made.scoutTeam), "scouts extend battlefield visibility")
	check(w.fog.sight_of(made.mortarTeam) < made.mortarTeam.range and w.fog.sight_of(made.towedHowitzer) < made.towedHowitzer.range, "indirect fire needs a spotter beyond its own sight")
	check(is_equal_approx(made.towedHowitzer.range, w.unit_defs.artillery.range) and made.mortarTeam.range < made.towedHowitzer.range, "towed artillery keeps established map reach; mortar has shorter reach")
	check(made.scoutTeam.speed > made.machineGunTeam.speed and made.reconVehicle.speed > made.heavyAPC.speed and made.towedHowitzer.speed < made.ifv.speed, "speed tradeoffs survive native spawn and national equipment")
	check(w.can_bombard(made.mortarTeam) and not w.can_bombard(made.missileBoat), "portable mortar bombard enabled; naval-only boat ground bombard excluded")
	w.order_bombard([made.mortarTeam], infantry.node.position)
	check(made.mortarTeam.has("ground_attack") and made.mortarTeam.enemy.get("is_building", false), "mortar receives a usable area-fire order")
	w.diplomacy.declare_war(0, 1)
	w.fog.enabled = false
	w.rebuild_grid()
	var target_hp: float = infantry.hp
	check(w.fire(made.mortarTeam, infantry), "mortar launches its indirect projectile")
	var old_ammo: int = made.attackJet.ammo
	made.attackJet.heading = atan2(infantry.node.position.x - made.attackJet.node.position.x, infantry.node.position.z - made.attackJet.node.position.z)
	check(w.fire(made.attackJet, infantry) and made.attackJet.ammo == old_ammo - 1, "ground-attack pass consumes air ammunition")
	check(not w.fire(made.scoutHelicopter, infantry) and not w.fire(made.attackJet, made.lightFighter), "recon helicopter unarmed; strike aircraft cannot dogfight")
	for step in range(90): w.effects._physics_process(0.1)
	check(infantry.hp < target_hp, "new indirect and strike projectiles apply damage in live combat")
	var submerged: Dictionary = w.spawn_unit("submarine", made.missileBoat.node.position + Vector3(6, 0, 0), 1)
	var ship: Dictionary = w.spawn_unit("corvette", made.missileBoat.node.position + Vector3(15, 0, 0), 1)
	check(w.effectiveness(made.missileBoat, ship) > 0 and not w.fire(made.missileBoat, submerged) and not w.fire(made.missileBoat, infantry), "missile boat engages surface ships, not submarines or land")
	check(w.missiles.platforms_for("antiShip").has(made.missileBoat) and not w.missiles.platforms_for("nuke").has(made.missileBoat) and not w.missiles.platforms_for("cruise").has(made.missileBoat), "missile boat only extends conventional anti-ship launch platforms")
	made.missileBoat.selected = true
	w.missiles.stock.antiShip = 1
	w.missiles.stock.nuke = 1
	w.missiles.stock.cruise = 1
	w.hud._fill_launch(true)
	await process_frame
	var launches: Array = w.hud._launch_row.find_children("*", "Button", true, false)
	check(launches.size() == 1 and launches[0].text.contains(w.missiles.def_of("antiShip").name), "selected missile boat displays only its national anti-ship launch button")
	made.missileBoat.selected = false
	made.mortarTeam.selected = true
	w.hud.show_building(null)
	check(not w.hud._commands.Bombard.disabled, "selected infantry mortar enables the actual HUD Bombard command")
	made.mortarTeam.selected = false
	var airfield: Dictionary = w.place_building("airfield", centre + Vector3(-20, 0, 0), 0, true)
	var helipad: Dictionary = w.place_building("helipad", centre + Vector3(-40, 0, 0), 0, true)
	check(w.AirOperations.available(w, made.scoutHelicopter, helipad) and not w.AirOperations.available(w, made.scoutHelicopter, airfield) and w.AirOperations.available(w, made.lightFighter, airfield), "new aircraft respect helicopter and runway parking")
	check(w.AirOperations.CAPACITY.lightFighter == 3 and w.AirOperations.CAPACITY.attackJet == 4 and made.scoutHelicopter.ammo == 1, "new sorties have bounded ammunition; scout has a fuel-only sortie")
	check(w.AirOperations.park_new(w, made.scoutHelicopter, helipad), "recon helicopter acquires a real helipad slot")
	made.scoutHelicopter.air_state = "rearming"
	made.scoutHelicopter.stay = true
	made.scoutHelicopter.service_left = 0.1
	w.AirOperations.update(w, made.scoutHelicopter, 0.2)
	check(made.scoutHelicopter.air_state == "parked" and made.scoutHelicopter.ammo == 1, "recon helicopter completes its service cycle without phantom ammunition")
	var before_tech: float = float(w.ai.nations[0].get("tech", 0.0))
	w.ai.nations[0].tech = 0.0
	check(not C.ai_unlocked(w, 1, "ifv") and C.ai_unlocked(w, 1, "scoutTeam"), "rival research gates mechanized units but permits basic scouts")
	w.ai.nations[0].tech = 10.0
	check(C.ai_unlocked(w, 1, "ifv") and C.ai_unlocked(w, 1, "attackJet"), "rival research unlocks additional roles")
	w.ai.nations[0].tech = before_tech
	var captured: Dictionary = w.saves.capture()
	check(C.ROLES.keys().all(func(key): return captured.units.any(func(u): return u.key == key)), "all new role keys enter the existing save format")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(captured))
	w.saves.restore(saved)
	check(C.ROLES.keys().all(func(key): return w.units.any(func(u): return u.key == key and not u.dead)), "JSON round trip restores all additional unit roles")
	var restored_scout: Dictionary = w.units.filter(func(u): return u.key == "scoutHelicopter")[0]
	check(restored_scout.air_state == "parked" and restored_scout.air_base != null and restored_scout.air_base.key == "helipad", "JSON round trip preserves reconnaissance helicopter base assignment")
	print("\nFORCE_ROSTER: %d passed, %d failed" % [passed, errors.size()])
	for failure in errors: print("  FAILED: " + failure)
	print("FORCE_ROSTER PASS" if errors.is_empty() else "FORCE_ROSTER FAIL")
	quit(0 if errors.is_empty() else 1)
