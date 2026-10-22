extends SceneTree
## A helicopter idle for a while, loaded with troops and sent somewhere, flies there (it used to freeze
## or turn back to base because its flight time ran out while it hovered); an attack warning needs an
## agent network or a satellite, not just the discovery.
var w: Node
var errors: Array[String] = []
const DT := 1.0 / 20.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func sim(sec: float) -> void:
	var t := 0.0
	while t < sec:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	var Air = preload("res://scripts/airlift.gd")
	var heli = w.units.filter(func(u): return u.owner == 0 and u.key == "helicopter")[0]
	sim(120.0)
	check(heli.air_state == "ready" and float(heli.sortie_left) > 80.0, "a helicopter hovering idle keeps its flight time (%s, %.0f s)" % [heli.air_state, float(heli.sortie_left)])
	var soldiers = w.units.filter(func(u): return u.owner == 0 and u.key == "soldier").slice(0, 4)
	for sd in soldiers: sd.node.position = heli.node.position + Vector3(3, 0, 0)
	check(Air.order_board(w, soldiers, heli) == 4, "four soldiers board it")
	sim(6.0)
	check(heli.get("cargo", []).size() == 4, "they are aboard")
	var dest: Vector3 = heli.node.position + Vector3(110, 0, 30)
	var start: Vector3 = heli.node.position
	w.order_move([heli], dest)
	sim(10.0)
	check(heli.air_state == "ready" and heli.node.position.distance_to(start) > 60.0, "it flies to the point instead of turning back (%s, %.0f m out)" % [heli.air_state, heli.node.position.distance_to(start)])
	# A helicopter already returning with flight time left obeys a new order.
	heli.air_state = "returning"
	heli.sortie_left = 50.0
	var before: Vector3 = heli.node.position
	w.order_move([heli], before + Vector3(-60, 0, 0))
	check(heli.air_state == "ready", "a new order cancels a return to base while there is flight time")
	# Warnings.
	var d: Node = w.diplomacy
	d.declare_war(0, 1)
	w.espionage.intel[1] = 0.0
	w.research.progress.satelliteRecon.stage = 3
	w.research._recompute()
	check(w.research.bonus("warn") >= 1.0, "satellite reconnaissance is researched")
	var n0: int = w.hud.notice_log.size()
	w.hud._recent_notices.clear()
	w.espionage.warn_attack(1)
	check(w.hud.notice_log.size() == n0, "no agents and no satellite in orbit: no warning of an attack")
	w.space.sats[0].recon = 1
	w.espionage.warn_attack(1)
	check(w.hud.notice_log.size() == n0 + 1, "with a reconnaissance satellite up: warned")
	w.space.sats[0].recon = 0
	check(float(w.sitrep.early_warning(1).level) == 0.0, "the situation report agrees: no warning source")
	w.espionage.intel[1] = 70.0
	check(float(w.sitrep.early_warning(1).level) >= 1.0, "agents in the country give full warning")
	print("HELI_ORDER ", "PASS" if errors.is_empty() else "FAIL %d" % errors.size())
	quit(0 if errors.is_empty() else 1)
