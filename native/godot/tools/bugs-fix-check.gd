extends SceneTree

var errors: Array[String] = []
var passed := 0
var w: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok:
		passed += 1
	else:
		errors.append(label)

func sim(seconds: float, step := 0.1) -> void:
	var n := int(roundf(seconds / step))
	for _i in range(n):
		w._physics_process(step)
		w.missiles._physics_process(step)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0, "opening": "light", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for _i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.menu.hide()
	if w.fog != null:
		w.fog.enabled = false
	w.research.progress["nuclearProgram"] = {"stage": 3, "work": 0.0, "paid": true}
	w.research.progress["ballisticTech"] = {"stage": 3, "work": 0.0, "paid": true}
	w.economy.res.money = 50000.0
	w.economy.res.oil = 50000.0

	# --- Bug 1: Missile / Nuclear transfer to docked ships ---
	print("==== Bug 1: Missile & Nuke Transfers to Ships ====")
	var ms: Node = w.missiles
	var cx: Vector3 = w.buildings[0].node.position
	var complex: Dictionary = w.place_building("strategicComplex", cx + Vector3(30, 0, 0), 0, true)
	complex.supplied = true
	var port: Dictionary = w.place_building("port", cx + Vector3(60, 0, 0), 0, true)
	port.supplied = true
	# Place nuclearSub 52m away from port (beyond old 38m DOCK_REACH, within new 68m+)
	var sub: Dictionary = w.spawn_unit("nuclearSub", port.node.position + Vector3(52, 0, 0), 0)
	sub.moving = false
	sub.target = null
	# Simulate an enemy in radar/attack range so enemy != null (before move)
	var foe: Dictionary = w.spawn_unit("corvette", port.node.position + Vector3(140, 0, 0), 1)
	sub.enemy = foe
	ms._manifest(complex)["nuke"] = 1
	check(ms.transfer_blocked(complex, port, "nuke", 1) == "", "strategicComplex -> port transfer allowed")
	check(ms.start_transfer(complex, port, "nuke", 1) == "", "strategicComplex -> port transfer started")
	sub.enemy = null
	foe.dead = true
	sim(25.0)
	check(ms.local_count(port, "nuke") == 1, "nuke arrived at port")
	sub.enemy = foe
	check(ms.transfer_blocked(port, sub, "nuke", 1) == "", "port -> nuclearSub at 52m (with enemy != null) allowed")
	sub.enemy = null
	check(ms.start_transfer(port, sub, "nuke", 1) == "", "port -> nuclearSub transfer started")
	sim(12.0)
	check(ms.local_count(sub, "nuke") == 1, "nuke loaded onto nuclearSub")
	var ready: Array = ms.ready_platforms("nuke", 0)
	check(ready.any(func(p): return is_same(p, sub)), "nuclearSub is ready platform for nuke launch")

	# Also test tactical missile -> destroyer
	var silo: Dictionary = w.place_building("missileSilo", cx + Vector3(-30, 0, 0), 0, true)
	silo.supplied = true
	var dd: Dictionary = w.spawn_unit("destroyer", port.node.position + Vector3(0, 0, 50), 0)
	dd.moving = false
	dd.target = null
	ms._manifest(port)["tactical"] = 1
	check(ms.transfer_blocked(port, dd, "tactical", 1) == "", "port -> destroyer tactical transfer allowed at 50m")
	check(ms.start_transfer(port, dd, "tactical", 1) == "", "port -> destroyer tactical transfer started")
	sim(12.0)
	check(ms.local_count(dd, "tactical") == 1, "tactical missile loaded onto destroyer")

	# --- Bug 2: Patrol HUD line count stability ---
	print("==== Bug 2: Patrol HUD Readout Stability ====")
	var airfield: Dictionary = w.place_building("airfield", cx + Vector3(0, 0, -45), 0, true)
	airfield.supplied = true
	var jet: Dictionary = w.spawn_unit("jet", airfield.node.position + Vector3(0, 0, 10), 0)
	jet.air_base = airfield
	jet.slot = 0
	jet.had_base = true
	jet.air_state = "ready"
	jet.sortie_left = w.AirOperations.fuel_capacity(jet)
	jet.selected = true
	w.order_mode = "patrol"
	w.hud._update_selection()
	var lines_hud: int = w.hud._sel_info.text.count("\n")
	check(lines_hud >= 1, "aircraft selection info preserves map-point/patrol footer line even over HUD")

	# --- Bug 3: Realistic Bingo Fuel Auto-RTB ---
	print("==== Bug 3: Bingo Fuel Auto-RTB ====")
	var away_dir: Vector3 = (cx - airfield.node.position).normalized()
	jet.heading = atan2(away_dir.x, away_dir.z)
	var app: Vector3 = w.AirOperations.approach_point(w, jet, airfield)
	var turn_away: float = w.AirOperations.turn_fuel(jet, jet.node.position, app)
	jet.heading = atan2(app.x - jet.node.position.x, app.z - jet.node.position.z)
	var turn_toward: float = w.AirOperations.turn_fuel(jet, jet.node.position, app)
	check(turn_away > turn_toward, "turn_fuel charges turning arc penalty when facing away from base")

	# Send jet far out on a mission until bingo hits, then simulate return & landing
	jet.node.position = airfield.node.position + Vector3(180, float(jet.altitude), 0)
	jet.fuel_position = jet.node.position
	jet.heading = PI * 0.5
	jet.target = airfield.node.position + Vector3(450, 0, 0)
	jet.sortie_left = w.AirOperations.bingo_fuel(w, jet, airfield) + 4.0
	var triggered_rtb := false
	for _s in range(600):
		sim(0.1)
		if jet.air_state in ["returning", "landing", "taxi_in", "parked", "rearming"]:
			triggered_rtb = true
		if jet.air_state in ["parked", "rearming"] or jet.dead:
			break
	check(triggered_rtb, "jet automatically triggered Bingo Fuel RTB")
	check(not jet.dead, "jet did NOT explode from fuel depletion")
	check(jet.air_state in ["parked", "rearming"], "jet safely landed at airfield (state=" + str(jet.air_state) + ")")

	print("\n==========================================")
	print("BUGS_FIX_CHECK: %d passed, %d failed" % [passed, errors.size()])
	print("BUGS_FIX_CHECK " + ("PASS" if errors.is_empty() else "FAIL"))
	print("==========================================")
	quit(0 if errors.is_empty() else 1)
