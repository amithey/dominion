extends SceneTree
## Round-2 1000-Trial Gameplay Fuzz & Stress Test
## Tests carrier air wings, new round-2 craft, mid-flight base destruction
## with alternate airfield diversion, supply cutoffs during missile transfers,
## and live multi-tick combat stability.

var w: Node
var rng := RandomNumberGenerator.new()
var trials := 0
var failures: Array[String] = []

func _initialize() -> void:
	rng.seed = 20261114
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

	var cx: Vector3 = w.buildings[0].node.position
	var af1: Dictionary = w.place_building("airfield", cx + Vector3(0, 0, -55), 0, true)
	af1.supplied = true
	var af2: Dictionary = w.place_building("airfield", cx + Vector3(70, 0, -55), 0, true)
	af2.supplied = true
	var port: Dictionary = w.place_building("port", cx + Vector3(75, 0, 20), 0, true)
	port.supplied = true
	var sc: Dictionary = w.place_building("strategicComplex", cx + Vector3(30, 0, 20), 0, true)
	sc.supplied = true

	# --- 1. 250 Round-2 Craft & Carrier Wing Trials ---
	print("==== Round 2 Phase 1: 250 New Craft & Carrier Trials ====")
	var r2_craft := ["missileBoat", "ewJet", "carrierJet", "carrier", "stealthFighter", "asFrigate"]
	var spawned: Array = []
	for k in r2_craft:
		var u: Dictionary = w.spawn_unit(k, port.node.position + Vector3(45, 0, 45), 0)
		spawned.append(u)
	var foe: Dictionary = w.spawn_unit("corvette", port.node.position + Vector3(130, 0, 45), 1)
	for i in range(250):
		var u: Dictionary = spawned[i % spawned.size()]
		var off := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
		w.place_on_ground(u, u.node.position + off * 0.05)
		var d_ok: bool = u.node.position.is_finite() and not is_nan(float(u.hp))
		var eff: float = w.effectiveness(u, foe)
		trial(d_ok and not is_nan(eff), "round2 craft #%d (%s)" % [i, u.key])

	# --- 2. 250 Mid-Flight Base Loss & Diversion Bingo Fuel Trials ---
	print("==== Round 2 Phase 2: 250 Airfield Loss & Bingo Fuel Diversion Trials ====")
	var jet: Dictionary = w.spawn_unit("jet", af1.node.position + Vector3(0, 0, 15), 0)
	for i in range(250):
		af1.dead = (i % 2 == 0)
		af2.dead = false
		jet.dead = false
		jet.air_base = af1
		jet.had_base = true
		jet.air_state = "ready"
		jet.fuel_warned = false
		var ang := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(50.0, 220.0)
		jet.node.position = af2.node.position + Vector3(cos(ang) * dist, float(jet.altitude), sin(ang) * dist)
		jet.fuel_position = jet.node.position
		jet.heading = rng.randf_range(-PI, PI)
		var alt = w.AirOperations.base_for(w, jet, jet.node.position, INF)
		var bingo: float = w.AirOperations.bingo_fuel(w, jet, alt)
		jet.sortie_left = bingo - 1.0
		w.AirOperations.update(w, jet, 0.1)
		trial(alt != null and jet.air_state in ["returning", "landing", "taxi_in", "parked"], "diversion bingo #%d (af1_dead=%s, state=%s)" % [i, str(af1.dead), str(jet.air_state)])
	af1.dead = false

	# --- 3. 250 Missile Supply Cutoff & Transfer Validation Trials ---
	print("==== Round 2 Phase 3: 250 Supply Cutoff & Transfer Trials ====")
	var ms: Node = w.missiles
	var sub: Dictionary = w.spawn_unit("nuclearSub", port.node.position + Vector3(48, 0, 0), 0)
	sub.moving = false
	sub.target = null
	for i in range(250):
		ms.transfers.clear()
		ms._manifest(sc).clear()
		ms._manifest(port).clear()
		ms._manifest(sub).clear()
		sc.supplied = (i % 3 != 0)
		port.supplied = true
		ms._manifest(sc)["nuke"] = 1
		var why: String = ms.transfer_blocked(sc, port, "nuke", 1)
		if sc.supplied:
			trial(why == "", "supplied transfer allowed #%d" % i)
		else:
			trial(why != "", "unsupplied transfer cleanly blocked #%d" % i)
	sc.supplied = true

	# --- 4. 250 Live Multi-System Physics & Economy Trials ---
	print("==== Round 2 Phase 4: 250 Multi-System Physics & Economy Trials ====")
	for i in range(250):
		w.economy._process(0.1)
		if i % 10 == 0:
			sim(0.1)
		trial(not is_nan(float(w.economy.res.money)) and not is_nan(float(w.economy.res.oil)), "econ/physics step #%d" % i)

	print("\n==========================================")
	print("FUZZ_ROUND2: %d trials, %d passed, %d failed" % [trials, trials - failures.size(), failures.size()])
	print("FUZZ_ROUND2 " + ("PASS" if failures.is_empty() else "FAIL"))
	print("==========================================")
	quit(0 if failures.is_empty() else 1)
