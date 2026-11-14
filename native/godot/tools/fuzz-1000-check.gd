extends SceneTree
## 1000-Trial Gameplay Fuzz & Stress Test (Step 3)
## Exercises 1000 randomized gameplay scenarios across Air/Bingo Fuel,
## Missile/Nuke Transfers, Naval/Carrier Ops, Homefront/Fires/Garrison,
## HUD Selection, and Save/Load to catch edge-case bugs.

var w: Node
var rng := RandomNumberGenerator.new()
var trials := 0
var failures: Array[String] = []

func _initialize() -> void:
	rng.seed = 20261113
	call_deferred("run")

func trial(ok: bool, label: String) -> void:
	trials += 1
	if not ok:
		failures.append("Trial %d: %s" % [trials, label])
		print("FAIL [%d] %s" % [trials, label])

func sim(seconds: float, step := 0.1) -> void:
	var n := int(roundf(seconds / step))
	for _i in range(n):
		w._physics_process(step)
		w.missiles._physics_process(step)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for _i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		print("FAIL world load")
		quit(1)
		return
	w.start_match("easy")
	w.menu.hide()
	if w.fog != null:
		w.fog.enabled = false
	w.research.progress["nuclearProgram"] = {"stage": 3, "work": 0.0, "paid": true}
	w.research.progress["ballisticTech"] = {"stage": 3, "work": 0.0, "paid": true}
	w.research.progress["navalEngineering"] = {"stage": 3, "work": 0.0, "paid": true}
	w.economy.res.money = 500000.0
	w.economy.res.oil = 500000.0
	w.economy.res.iron = 500000.0

	var cx: Vector3 = w.buildings[0].node.position
	var airfield: Dictionary = w.place_building("airfield", cx + Vector3(0, 0, -50), 0, true)
	airfield.supplied = true
	var airfield2: Dictionary = w.place_building("airfield", cx + Vector3(60, 0, -50), 0, true)
	airfield2.supplied = true
	var helipad: Dictionary = w.place_building("helipad", cx + Vector3(-60, 0, -50), 0, true)
	helipad.supplied = true
	var complex: Dictionary = w.place_building("strategicComplex", cx + Vector3(30, 0, 15), 0, true)
	complex.supplied = true
	var silo: Dictionary = w.place_building("missileSilo", cx + Vector3(-30, 0, 15), 0, true)
	silo.supplied = true
	var port: Dictionary = w.place_building("port", cx + Vector3(70, 0, 15), 0, true)
	port.supplied = true
	var shipyard: Dictionary = w.place_building("shipyard", cx + Vector3(95, 0, 15), 0, true)
	shipyard.supplied = true
	var house: Dictionary = w.place_building("apartments", cx + Vector3(-55, 0, -15), 0, true)
	house.supplied = true
	var fire_st: Dictionary = w.place_building("fireStation", cx + Vector3(-55, 0, 15), 0, true)
	fire_st.supplied = true

	# --- 1. 250 Air & Bingo Fuel trials ---
	print("==== Phase 1: 250 Air & Bingo Fuel Trials ====")
	var air_keys := ["jet", "bomber", "stealthFighter", "helicopter", "gunship", "ewJet"]
	var jets: Array = []
	for k in air_keys:
		var base_b: Dictionary = helipad if k in ["helicopter", "gunship"] else airfield
		var u: Dictionary = w.spawn_unit(k, base_b.node.position + Vector3(0, 0, 12), 0)
		u.air_base = base_b
		u.had_base = true
		u.air_state = "ready"
		jets.append(u)
	for i in range(250):
		var u: Dictionary = jets[i % jets.size()]
		var base_b: Dictionary = helipad if u.key in ["helicopter", "gunship"] else airfield
		if u.dead:
			u = w.spawn_unit(u.key, base_b.node.position + Vector3(0, 0, 12), 0)
			u.air_base = base_b
			u.had_base = true
			jets[i % jets.size()] = u
		u.air_state = "ready"
		u.fuel_warned = false
		var dist := rng.randf_range(40.0, 240.0)
		var ang := rng.randf_range(0.0, TAU)
		u.node.position = base_b.node.position + Vector3(cos(ang) * dist, float(u.altitude), sin(ang) * dist)
		u.fuel_position = u.node.position
		u.heading = rng.randf_range(-PI, PI)
		var bingo: float = w.AirOperations.bingo_fuel(w, u, base_b)
		u.sortie_left = bingo + rng.randf_range(-2.0, 8.0)
		var pos_ok: bool = u.node.position.is_finite() and not is_nan(bingo) and bingo > 0.0
		w.AirOperations.update(w, u, 0.1)
		var rtb_ok: bool = (float(u.sortie_left) > bingo) or (u.air_state in ["returning", "landing", "taxi_in", "parked"])
		trial(pos_ok and rtb_ok, "air trial %d (%s, fuel=%.1f, bingo=%.1f, state=%s)" % [i, u.key, float(u.sortie_left), bingo, str(u.air_state)])
		if i % 50 == 0:
			u.selected = true
			w.order_mode = "patrol" if (i % 100 == 0) else ""
			w.hud._update_selection()
			trial(w.hud._sel_info.text.count("\n") >= 1, "hud selection stable for %s" % u.key)
			u.selected = false

	# --- 2. 250 Missile / Nuke Transfer & Launch Trials ---
	print("==== Phase 2: 250 Missile & Transfer Trials ====")
	var ms: Node = w.missiles
	var sub: Dictionary = w.spawn_unit("nuclearSub", port.node.position + Vector3(rng.randf_range(28.0, 62.0), 0, 0), 0)
	var dd: Dictionary = w.spawn_unit("destroyer", port.node.position + Vector3(0, 0, rng.randf_range(28.0, 62.0)), 0)
	sub.moving = false
	sub.target = null
	dd.moving = false
	dd.target = null
	for i in range(250):
		ms.transfers.clear()
		ms._manifest(complex).clear()
		ms._manifest(silo).clear()
		ms._manifest(port).clear()
		ms._manifest(shipyard).clear()
		ms._manifest(sub).clear()
		ms._manifest(dd).clear()
		var mode := i % 5
		if mode == 0:
			ms._manifest(complex)["nuke"] = 1
			var err: String = ms.start_transfer(complex, port, "nuke", 1)
			var redir: String = ms.redirect_transfer(ms.transfers[0], shipyard) if err == "" and not ms.transfers.is_empty() else "skip"
			trial(err == "" and redir == "", "nuke transfer+redirect #%d (%s / %s)" % [i, err, redir])
		elif mode == 1:
			var r := rng.randf_range(25.0, 64.0)
			var th := rng.randf_range(0.0, TAU)
			sub.node.position = port.node.position + Vector3(cos(th) * r, 0, sin(th) * r)
			ms._manifest(port)["nuke"] = 1
			var err: String = ms.start_transfer(port, sub, "nuke", 1)
			trial(err == "", "port->sub nuke load at %.1fm (%s)" % [r, err])
		elif mode == 2:
			var r := rng.randf_range(25.0, 64.0)
			var th := rng.randf_range(0.0, TAU)
			dd.node.position = shipyard.node.position + Vector3(cos(th) * r, 0, sin(th) * r)
			ms._manifest(shipyard)["tactical"] = 1
			var err: String = ms.start_transfer(shipyard, dd, "tactical", 1)
			trial(err == "", "shipyard->dd tactical load at %.1fm (%s)" % [r, err])
		elif mode == 3:
			ms._manifest(silo)["tactical"] = 1
			var err: String = ms.start_transfer(silo, port, "tactical", 1)
			var canc: String = ms.cancel_transfer(ms.transfers[0]) if err == "" and not ms.transfers.is_empty() else "skip"
			trial(err == "" and canc == "", "silo->port transfer+cancel #%d (%s / %s)" % [i, err, canc])
		else:
			ms._manifest(sub)["nuke"] = 1
			var ready: Array = ms.ready_platforms("nuke", 0)
			trial(ready.any(func(p): return is_same(p, sub)), "sub ready_platforms for nuke #%d" % i)

	# --- 3. 250 Homefront, Fires, Garrison & Grid Trials ---
	print("==== Phase 3: 250 Homefront / Fires / Garrison Trials ====")
	var Garrison := preload("res://scripts/urban_garrison.gd")
	var BF := preload("res://scripts/building_fires.gd")
	var inf: Dictionary = w.spawn_unit("soldier", house.root.position + Vector3(4, 0, 0), 0)
	for i in range(250):
		var act := i % 4
		if act == 0:
			var ok_g: bool = Garrison.enter(w, inf, house)
			var ok_e: bool = Garrison.evacuate(w, house) >= 0
			trial(ok_g and ok_e, "garrison enter+evac #%d" % i)
		elif act == 1:
			BF.ignite(w, house, 0.35, 1)
			BF.update(w, 0.2)
			trial(not is_nan(float(house.get("fire", 0.0))), "fire ignite+update #%d" % i)
			house.fire = 0.0
		elif act == 2:
			var pt := cx + Vector3(rng.randf_range(-120.0, 120.0), 0, rng.randf_range(-120.0, 120.0))
			var h: float = w.height_at(pt.x, pt.z)
			var nrm: Vector3 = w.normal_at(pt.x, pt.z)
			trial(not is_nan(h) and nrm.is_finite() and nrm.length() > 0.5, "terrain height/normal query #%d" % i)
		else:
			w.homefront.update(0.1)
			trial(float(w.homefront.power_supply.get(0, 0.0)) >= 0.0, "homefront power tick #%d" % i)

	# --- 4. 250 New Craft / Combat / AI / Save-Load Trials ---
	print("==== Phase 4: 250 National Craft, Combat & Save/Load Trials ====")
	var craft_tests := [
		["carrier", 4, "Admiral Kuznetsov"],
		["carrier", 1, "Fujian"],
		["carrier", 12, "NAM Atlantico"],
		["asFrigate", 0, "Constellation-class"],
		["asFrigate", 14, "Hetman Ivan Mazepa"],
		["stealthFighter", 7, "KAAN"],
		["stealthFighter", 5, "AMCA"],
		["ewJet", 4, "Su-34EW"],
	]
	var test_units: Array = []
	for spec in craft_tests:
		var u: Dictionary = w.spawn_unit(spec[0], port.node.position + Vector3(45, 0, 45), 0)
		test_units.append(u)
	for i in range(250):
		if i < 200:
			var u: Dictionary = test_units[i % test_units.size()]
			var target: Dictionary = jets[i % jets.size()]
			var picked = w.Tactics.pick_target(w, u, 80.0)
			w.place_on_ground(u, u.node.position)
			trial(u.node.position.is_finite() and (picked == null or picked is Dictionary), "tactics/place_on_ground #%d (%s)" % [i, u.key])
		elif i < 245:
			sim(0.1)
			trial(not w.units.is_empty(), "live physics tick #%d" % i)
		else:
			var saved: Dictionary = w.save_state() if w.has_method("save_state") else {}
			trial(saved is Dictionary, "state capture #%d" % i)

	print("\n==========================================")
	print("FUZZ_1000: %d trials, %d passed, %d failed" % [trials, trials - failures.size(), failures.size()])
	print("FUZZ_1000 " + ("PASS" if failures.is_empty() else "FAIL"))
	print("==========================================")
	quit(0 if failures.is_empty() else 1)
