extends SceneTree
## Shipyards build warships: a shipyard on the player's coast trains every
## ship it offers, and each one comes out on the water.
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
	w.economy.grant_test_resources()
	for i in range(10):
		await process_frame
	# The nearest coastal hex a shipyard may go on, unclaimed coast included.
	var spot = null
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				if spot == null and w.logistics.hex_distance(home, h) == ring:
					var at: Vector3 = w.logistics.hex_center(h)
					if w.site_problem("shipyard", at, 0) == "":
						spot = at
	check(spot != null, "a shipyard can be placed on the coast near the starting land")
	if spot == null:
		quit(1)
		return
	var yard: Dictionary = w.place_building("shipyard", spot, 0, true)
	for key in yard.def.trains:
		var locked: String = w.research.unit_locked(key) if w.research else ""
		var before: int = w.units.filter(func(u): return u.key == key).size()
		w.queue_unit(yard, key)
		var queued: bool = key in yard.queue
		for f in range(60 * 90):
			w.update_training(1.0 / 60.0)
			if w.units.filter(func(u): return u.key == key).size() > before:
				break
		var made: Array = w.units.filter(func(u): return u.key == key)
		var afloat: bool = made.size() > before and w.is_water(made[-1].node.position, 0.0)
		print("  %s: locked '%s', queued %s, launched %s, queue now %s" % [key, locked, queued, made.size() > before, yard.queue])
		check(locked != "" or afloat, "the shipyard launches a %s" % key)
		yard.queue.clear()
	# A click on a queued order cancels it and gives the money back.
	var money: float = w.economy.res.money
	w.queue_unit(yard, "gunboat")
	var paid: float = money - w.economy.res.money
	w.cancel_queued(yard, 0)
	check(paid > 0.0 and yard.queue.is_empty() and absf(w.economy.res.money - money) < 0.01, "cancelling a queued ship refunds it")
	print("NAVAL_TEST PASS" if errors.is_empty() else "NAVAL_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
