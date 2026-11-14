extends SceneTree

var passed := 0
var failed := 0

func ok(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("ok   " + msg)
	else:
		failed += 1
		print("FAIL " + msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	var w: Node = null
	for _i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	await process_frame

	w.economy.res.money = 5000.0
	w.diplomacy.declare_war(0, 1)
	var forts = w.fortifications
	var wt := preload("res://scripts/war_tools.gd")
	var base: Vector3 = w.buildings[0].root.position

	# 1. Dig trench & forward bunker, complete build, garrison infantry, check cover & exit
	var inf1: Dictionary = w.spawn_unit("soldier", base + Vector3(10, 0, 10), 0)
	var inf2: Dictionary = w.spawn_unit("soldier", base + Vector3(11, 0, 10), 0)
	var dug: int = forts.order_dig([inf1], "dugout")
	ok(dug == 1, "infantry started digging forward bunker")
	for _i in range(40):
		forts.update(0.2)
	ok(forts.entries.size() == 1 and forts.entries[0].built, "forward bunker completed construction")
	var bunker_ent: Dictionary = forts.entries[0]

	var entered: int = forts.order_enter([inf1, inf2], bunker_ent)
	ok(entered == 2, "two infantry ordered into forward bunker")
	inf1.node.position = bunker_ent.pos
	inf2.node.position = bunker_ent.pos
	forts.update(0.1)
	ok(bunker_ent.garrison.size() == 2 and inf1.get("garrisoned_in") == bunker_ent, "infantry garrisoned inside forward bunker")

	var enemy_inf: Dictionary = w.spawn_unit("soldier", base + Vector3(30, 0, 30), 1)
	var mult: float = forts.cover(inf1, enemy_inf)
	ok(mult <= 0.30, "garrisoned infantry in forward bunker gets heavy cover (%.2f)" % mult)

	var exited: int = forts.order_exit([inf1])
	ok(exited == 1 and inf1.get("garrisoned_in") == null and bunker_ent.garrison.size() == 1, "infantry exited forward bunker on order")

	# 2. Anti-tank hedgehog & ditch block hostile tanks, not infantry, and mineClearer breaches them
	var worker: Dictionary = w.spawn_unit("worker", base + Vector3(-20, 0, 0), 0)
	var line_count: int = forts.order_line([worker], "hedgehog", base + Vector3(-20, 0, -4), base + Vector3(-20, 0, 4))
	ok(line_count >= 2, "defence line placed %d hedgehog segments" % line_count)
	for e in forts.entries:
		if e.kind == "hedgehog":
			e.built = true
			e.progress = 1.0
			e.model.scale.y = 1.0

	var hedge: Dictionary = forts.entries.filter(func(e): return e.kind == "hedgehog")[0]
	var enemy_tank: Dictionary = w.spawn_unit("tank", hedge.pos + Vector3(4, 0, 0), 1)
	ok(forts.blocks_vehicle(enemy_tank, hedge.pos), "hedgehog blocks hostile tank")
	ok(not forts.blocks_vehicle(enemy_inf, hedge.pos), "hedgehog does not block infantry")

	var enemy_clearer: Dictionary = w.spawn_unit("mineClearer", hedge.pos + Vector3(4, 0, 0), 1)
	ok(not forts.blocks_vehicle(enemy_clearer, hedge.pos), "mineClearer can approach hostile obstacle to breach")
	for _i in range(25):
		forts.breach_near(enemy_clearer, 0.2)
	ok(hedge.dead, "mineClearer breached hostile hedgehog")

	# 3. Anti-tank & anti-personnel minefields + mine line + save/restore
	var ml: Dictionary = w.spawn_unit("mineLayer", base + Vector3(40, 0, 0), 0)
	var laid_ap := wt.order_lay_mine(w, [ml], base + Vector3(40, 0, 10), "ap")
	var laid_line := wt.order_mine_line(w, [ml], base + Vector3(40, 0, 30), base + Vector3(70, 0, 30), "at")
	ok(laid_ap == 1 and laid_line >= 2, "laid AP minefield and AT minefield line (%d)" % laid_line)

	var saved_forts: Array = forts.export_state()
	var saved_wt := wt.capture(w)
	forts.import_state(saved_forts)
	wt.restore(w, saved_wt)
	ok(forts.entries.size() == saved_forts.size(), "fortifications survive save/restore (%d)" % forts.entries.size())
	ok(wt.state(w).fields.size() == saved_wt.fields.size(), "minefields (AT/AP) survive save/restore (%d)" % wt.state(w).fields.size())

	print("FORTIFICATIONS %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
