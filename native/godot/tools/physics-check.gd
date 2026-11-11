extends SceneTree
## How things move, measured: aircraft turn at a bounded rate and bank with it; helicopters gather and shed speed and tilt as they
## do; aircraft climb and sink at bounded rates and never touch the ground; a shot-down aircraft carries on and falls faster and
## faster; ships gather way by their size, turn slower when long and heel in the turn; a tracked hull pivots where a wheeled one
## sweeps an arc, and both arrive; a ballistic missile comes down faster than it went up.
## Run: Godot --headless --path native/godot --script res://tools/physics-check.gd
var w: Node
var errors: Array[String] = []
var passed := 0
const DT := 1.0 / 30.0
const Flight := preload("res://scripts/flight.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)
func step() -> void:
	w._physics_process(DT)
	w.effects._physics_process(DT)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0, "opening": "light", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.ai.set_physics_process(false)
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.economy.grant_test_resources()
	var field: Vector3 = w.land_point(w.start + Vector3(-70, 0, 50), 40.0)

	# ------------------------------------------------------------ a jet's turn
	var jet: Dictionary = w.spawn_unit("jet", field, 0)
	jet.air_state = "ready"
	jet.sortie_left = 9999.0
	jet.heading = 0.0
	w.place_on_ground(jet, field)
	for i in range(30): step()
	var astern: Vector3 = jet.node.position - Basis(Vector3.UP, jet.heading) * Vector3.BACK * 160.0   # straight behind it
	w.order_move([jet], astern)
	var cls: Array = Flight.class_of(jet, true)
	var max_rate := 0.0
	var max_bank := 0.0
	var t_turn := -1.0
	for i in range(300):
		step()
		max_rate = maxf(max_rate, absf(float(jet.get("yaw_rate", 0.0))))
		max_bank = maxf(max_bank, absf(float(jet.bank)))
		var bearing := atan2(astern.x - jet.node.position.x, astern.z - jet.node.position.z)
		if t_turn < 0.0 and absf(angle_difference(jet.heading, bearing)) < 0.2:
			t_turn = (i + 1) * DT
	check(max_rate <= float(cls[0]) + 0.02 and max_rate > float(cls[0]) * 0.8, "a jet turns at its class's rate, no faster (%.2f of %.2f rad/s)" % [max_rate, float(cls[0])])
	check(max_bank > 0.7 and max_bank <= float(cls[1]) + 0.02, "and banks hard into the turn (%.2f rad)" % max_bank)
	check(t_turn > 2.0 and t_turn < 6.0, "a reversal takes a few seconds, not a snap (%.1f s)" % t_turn)
	var bomber: Dictionary = w.spawn_unit("bomber", field + Vector3(30, 0, 0), 0)
	check(float(Flight.class_of(bomber, true)[0]) < float(cls[0]) * 0.7, "a bomber turns slower than a fighter")
	# a goal inside its turning circle, off its wing: it must still get there (it used to orbit it for ever)
	bomber.air_state = "ready"
	bomber.sortie_left = 9999.0
	w.place_on_ground(bomber, field + Vector3(30, 0, 0))
	for i in range(20): step()
	var wing: Vector3 = bomber.node.position + Basis(Vector3.UP, bomber.heading) * Vector3.RIGHT * 14.0
	w.order_move([bomber], wing)
	var nearest := INF
	for i in range(600):
		step()
		nearest = minf(nearest, Vector2(bomber.node.position.x - wing.x, bomber.node.position.z - wing.z).length())
	check(nearest < 7.0, "a bomber reaches a point inside its turning circle by flying out and round (%.1f m at the nearest)" % nearest)

	# ------------------------------------------------------------ height: bounded climb, never into the ground
	var worst_v := 0.0
	var least := INF
	w.order_move([jet], w.start + Vector3(-200, 0, 150))
	for i in range(600):
		step()
		worst_v = maxf(worst_v, absf(float(jet.get("alt_v", 0.0))))
		least = minf(least, jet.node.position.y - maxf(w.height_at(jet.node.position.x, jet.node.position.z), float(w.map.seaLevel)))
	check(worst_v <= 9.05, "a jet climbs and sinks at a bounded rate (%.1f m/s at most)" % worst_v)
	check(least >= 2.9, "and keeps clear of the ground (%.1f m at least)" % least)

	# ------------------------------------------------------------ a helicopter's momentum
	var heli: Dictionary = w.spawn_unit("helicopter", field + Vector3(0, 0, 30), 0)
	heli.air_state = "ready"
	heli.sortie_left = 9999.0
	heli.heading = 0.0
	w.place_on_ground(heli, field + Vector3(0, 0, 30))
	for i in range(20): step()
	var from: Vector3 = heli.node.position
	var goal: Vector3 = from + Vector3(0, 0, 70)
	w.order_move([heli], goal)
	var v_after_half := 0.0
	var peak_v := 0.0
	var nose_down := 0.0
	var nose_up := 0.0
	var max_acc := 0.0
	for i in range(600):
		step()
		var v: float = Vector3(heli.get("air_vel", Vector3.ZERO)).length()
		if i == 14: v_after_half = v
		peak_v = maxf(peak_v, v)
		max_acc = maxf(max_acc, Vector3(heli.get("air_acc", Vector3.ZERO)).length())
		nose_down = maxf(nose_down, float(heli.get("pitch", 0.0)))
		nose_up = minf(nose_up, float(heli.get("pitch", 0.0)))
	var flat_off := Vector2(heli.node.position.x - goal.x, heli.node.position.z - goal.z).length()
	check(v_after_half > 1.0 and v_after_half < float(heli.speed) * 0.6, "a helicopter eases away: half a second in it is still gathering speed (%.1f of %.1f m/s)" % [v_after_half, float(heli.speed)])
	check(peak_v > float(heli.speed) * 0.9 and max_acc <= Flight.ROTARY_ACCEL + 0.1, "it reaches its speed, never pulling more than %.1f m/s² (%.1f)" % [Flight.ROTARY_ACCEL, max_acc])
	check(nose_down > 0.12 and nose_up < -0.05, "nose down to go (%.2f rad), nose up to stop (%.2f rad)" % [nose_down, nose_up])
	check(flat_off < 2.0 and Vector3(heli.get("air_vel", Vector3.ZERO)).length() < 0.2, "and it comes to a hover on its mark (%.1f m off)" % flat_off)

	# ------------------------------------------------------------ shot down: it carries on, and falls faster and faster
	var doomed: Dictionary = w.spawn_unit("jet", field + Vector3(-40, 0, 0), 0)
	doomed.air_state = "ready"
	doomed.sortie_left = 9999.0
	w.order_move([doomed], doomed.node.position + Vector3(0, 0, 300))
	for i in range(60): step()
	var p0: Vector3 = doomed.node.position
	w.kill(doomed)
	var falls: Array = []
	for i in range(150):
		var y0: float = doomed.node.position.y
		step()
		if not doomed.get("crashed", false):
			falls.append(y0 - doomed.node.position.y)
	var carried := Vector2(doomed.node.position.x - p0.x, doomed.node.position.z - p0.z).length()
	check(falls.size() > 20 and falls[falls.size() - 3] > falls[3] * 2.0, "a shot-down jet falls faster and faster (%.2f then %.2f m a frame)" % [falls[3] if falls.size() > 3 else 0.0, falls[falls.size() - 3] if falls.size() > 3 else 0.0])
	check(carried > 12.0 and doomed.get("crashed", false), "and carries on %.0f m before it hits" % carried)

	# ------------------------------------------------------------ ships: mass and helm
	var sea = w.water_near(w.start, 320, 3.0)
	var times := {}
	var rates := {}
	var heels := {}
	if sea != null:
		for key in ["gunboat", "carrier"]:
			var ship: Dictionary = w.spawn_unit(key, sea + Vector3(40 if key == "carrier" else 0, 0, 0), 0)
			var out: Vector3 = (ship.node.position - w.start)
			out.y = 0
			out = out.normalized()
			ship.heading = atan2(out.x, out.z)
			w.order_move([ship], ship.node.position + out * 160.0)
			var t := 0.0
			var reached := -1.0
			for i in range(450):
				step()
				t += DT
				if reached < 0.0 and float(ship.get("sailing_speed", 0.0)) > float(ship.speed) * 0.8 * 0.9:
					reached = t
			times[key] = reached
			# then hard over: a course at right angles
			var side := Vector3(out.z, 0, -out.x)
			w.order_move([ship], ship.node.position + side * 120.0 + out * 40.0)
			var rate := 0.0
			var heel := 0.0
			for i in range(240):
				step()
				rate = maxf(rate, absf(float(ship.get("yaw_rate", 0.0))))
				heel = maxf(heel, absf(float(ship.get("heel", 0.0))))
			rates[key] = rate
			heels[key] = heel
		check(times.gunboat > 0.8 and times.carrier > times.gunboat * 2.0, "a carrier gathers way far slower than a gunboat (%.1f s against %.1f s)" % [times.carrier, times.gunboat])
		check(rates.carrier < rates.gunboat * 0.6, "and answers her helm slower (%.2f against %.2f rad/s)" % [rates.carrier, rates.gunboat])
		check(heels.gunboat > 0.02, "a boat heels in a hard turn (%.3f rad)" % heels.gunboat)
	else:
		check(false, "open water near the capital for the ship trials")

	# ------------------------------------------------------------ tracked pivots, wheeled sweeps an arc
	var Motion := preload("res://scripts/motion.gd")
	var results := {}
	for key in ["tank", "supplyTruck"]:
		var at: Vector3 = w.land_point(field + Vector3(60 if key == "tank" else 90, 0, -40), 30.0)
		var u: Dictionary = w.spawn_unit(key, at, 0)
		u.heading = 0.0
		w.place_on_ground(u, at)
		for i in range(10): step()
		var start: Vector3 = u.node.position
		var goal2: Vector3 = start + Vector3(0, 0, -28)   # dead astern
		w.order_move([u], goal2)
		var drift := 0.0     # how far it strays from its spot before it faces the goal
		var facing := false
		for i in range(900):
			step()
			if not facing:
				if absf(angle_difference(u.heading, atan2(goal2.x - u.node.position.x, goal2.z - u.node.position.z))) < 0.5:
					facing = true
				else:
					drift = maxf(drift, Vector2(u.node.position.x - start.x, u.node.position.z - start.z).length())
		results[key] = {"drift": drift, "off": Vector2(u.node.position.x - goal2.x, u.node.position.z - goal2.z).length(), "wheeled": Motion.profile(u).wheeled, "accel": float(Motion.profile(u).accel)}
	check(not results.tank.wheeled and results.tank.drift < 1.2, "a tank turns about on its tracks where it stands (%.1f m of drift)" % results.tank.drift)
	check(results.supplyTruck.wheeled and results.supplyTruck.drift > 1.5, "a lorry has to roll to come about (%.1f m)" % results.supplyTruck.drift)
	check(results.tank.off < 3.0 and results.supplyTruck.off < 3.0, "both reach the mark behind them (%.1f m and %.1f m off)" % [results.tank.off, results.supplyTruck.off])
	check(results.supplyTruck.accel > results.tank.accel, "the lorry pulls away quicker than the tank (%.1f against %.1f m/s²)" % [results.supplyTruck.accel, results.tank.accel])

	# ------------------------------------------------------------ a ballistic missile: slow off the pad, fast coming down
	var ms = w.missiles
	var m := {"from": Vector3(0, 0, 0), "to": Vector3(300, 0, 0), "arc": true, "peak": 135.0, "t": 0.0, "dur": 8.0}
	var warp := func(u: float) -> float: return 0.45 * u + 0.55 * u * u
	var early: float = ms.position_at(m, warp.call(0.1)).distance_to(ms.position_at(m, warp.call(0.05)))
	var late: float = ms.position_at(m, warp.call(0.98)).distance_to(ms.position_at(m, warp.call(0.93)))
	check(late > early * 1.4, "a ballistic missile comes down faster than it lifted off (%.0f against %.0f m in the same time)" % [late, early])

	print("PHYSICS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("PHYSICS_CHECK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
