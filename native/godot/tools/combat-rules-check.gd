extends SceneTree
## Air defence engages only aircraft in flight, artillery reaches three hexes,
## and bunkers fire on ground attackers and shelter troops beside them.
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.menu._root.hide()
	w.ai.declare_war(1, false)
	var at: Vector3 = w.land_point(w.start, 120.0)
	var sam: Dictionary = w.spawn_unit("samLauncher", at, 0)
	var tank: Dictionary = w.spawn_unit("tank", at + Vector3(20, 0, 0), 1)
	var jet: Dictionary = w.spawn_unit("jet", at + Vector3(0, 0, 30), 1)
	jet.node.position.y = w.height_at(jet.node.position.x, jet.node.position.z) + 30.0
	check(w.effectiveness(sam, tank) == 0.0, "a mobile SAM does not engage a tank")
	check(w.effectiveness(sam, jet) > 0.0, "a mobile SAM engages a jet in flight")
	jet.air_state = "parked"
	jet.node.position.y = w.height_at(jet.node.position.x, jet.node.position.z)
	check(w.effectiveness(sam, jet) == 0.0, "a mobile SAM ignores a jet parked on the ground")
	check(w.effectiveness(w.spawn_unit("aaVehicle", at, 0), tank) == 0.0, "an anti-aircraft vehicle does not engage a tank")
	var hex := 12.0 * sqrt(3.0)
	check(absf(float(w.unit_defs.artillery.range) - hex * 3.0) < 0.5, "artillery reaches three hexes (%.1f m)" % float(w.unit_defs.artillery.range))
	# Bunkers.
	var spot: Vector3 = w.land_point(w.start, 80.0)
	var bunker: Dictionary = w.place_building("bunker", spot, 0, true)
	var raider: Dictionary = w.spawn_unit("soldier", spot + Vector3(30, 0, 0), 1)
	var hp: float = raider.hp
	for f in range(120):
		preload("res://scripts/bunker.gd").update(w, 1.0 / 60.0)
	check(raider.hp < hp, "a bunker fires on an enemy soldier 30 m away")
	var guard: Dictionary = w.spawn_unit("soldier", spot + Vector3(6, 0, 0), 0)
	var exposed: Dictionary = w.spawn_unit("soldier", spot + Vector3(60, 0, 60), 0)
	var g0: float = guard.hp
	var e0: float = exposed.hp
	w.damage(guard, 10.0, raider)
	w.damage(exposed, 10.0, raider)
	check(g0 - guard.hp < (e0 - exposed.hp) * 0.6, "troops beside a bunker take less ground fire (%.1f vs %.1f)" % [g0 - guard.hp, e0 - exposed.hp])
	var b0: float = bunker.hp
	w.damage(bunker, 30.0, tank)
	check(b0 - bunker.hp < 12.0, "ground fire does a bunker a third of the damage")
	print("COMBAT_RULES PASS" if errors.is_empty() else "COMBAT_RULES FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
