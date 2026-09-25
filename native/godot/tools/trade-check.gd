extends SceneTree
## Trade at sea: every open route shows its freighter (moored while it waits,
## sailing with a cargo), agents can sink a rival's cargo, and a hostile
## saboteur sinks your next one. With --capture, pictures of the freighter
## (build/trade-*.png).
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
	# A harbour must stand in your own land: the nearest coastal hex is granted,
	# as if the town had grown to it.
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var gh: Vector2i = w.logistics.world_hex(w.start) + Vector2i(q, r)
				var ga: Vector3 = w.logistics.hex_center(gh)
				if w.logistics.hex_distance(w.logistics.world_hex(w.start), gh) == ring and w.site_problem("shipyard", ga, 0) == "Outside your territory" and not w.has_meta("granted"):
					var gi: int = w.territory.index_of(w.territory.hex_at(ga))
					w.territory.owner_of[gi] = 0
					w.territory.control[gi] = 80.0
					var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
					w.territory.purchased[str(gi)] = {"owner": 0, "settlement": w.territory.settlement_key(capital)}
					w.set_meta("granted", ga)
	# A port on the nearest coast, a pact and an export route.
	var spot = null
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				if spot == null and w.logistics.hex_distance(home, h) == ring and w.site_problem("port", w.logistics.hex_center(h), 0) == "":
					spot = w.logistics.hex_center(h)
	check(spot != null, "a port can be placed on the coast")
	if spot == null:
		quit(1)
		return
	w.place_building("port", spot, 0, true)
	w.economy.recalculate()
	w.diplomacy.pact[0][1] = true
	w.economy.res.oil = 0.0
	var opened: String = w.market.open_route(1, "oil", "export", 25)
	print("  ", opened)
	var traffic: Node = w.get_children().filter(func(n): return n.get_script() == preload("res://scripts/route_traffic.gd"))[0]
	w.market.tick()
	traffic._sync()
	traffic._process(0.1)
	var ship = traffic.vehicles.get("ship:%d" % w.market.routes[0].id) if not w.market.routes.is_empty() else null
	check(ship != null and ship.node.visible, "a route waiting for stock still shows its freighter, moored")
	var moored: Vector3 = ship.node.position if ship != null else Vector3.ZERO
	w.economy.res.oil = 500.0
	w.market.tick()
	for i in range(40):
		traffic._process(0.25)
		w.market._tick += 0.25
	check(ship != null and w.market.routes[0].shipment != null and ship.node.position.distance_to(moored) > 8.0, "with a cargo aboard the freighter sails")
	# Your agents sink a rival's cargo.
	var nat = w.market.ai_nation(1)
	var before: float = nat.money
	var text: String = w.espionage._succeed("shipping", 1, "")
	print("  ", text)
	check(nat.money < before, "sabotaging a rival's shipping costs it a cargo")
	# A hostile saboteur sinks your next cargo.
	w.market.sabotaged = 1
	var lost: int = w.market.lost
	for i in range(6):
		w.market.tick()
	check(w.market.lost > lost and w.market.sabotaged == 0, "a saboteur's work sinks your next cargo")
	if "--capture" in OS.get_cmdline_user_args():
		for n in w.find_children("*", "Label3D", true, false) + w.find_children("*", "Sprite3D", true, false):
			n.visible = false
		var cam := Camera3D.new()
		cam.fov = 40
		w.add_child(cam)
		cam.current = true
		for view in [["side", Vector3(1, 0.35, 0.2)], ["bow", Vector3(-0.4, 0.5, 1.0)]]:
			for i in range(3):
				traffic._process(0.05)
				await process_frame
			var at: Vector3 = ship.node.position + Vector3(0, 2, 0)
			var dir: Vector3 = view[1]
			dir = ship.node.basis * dir
			cam.look_at_from_position(at + dir.normalized() * 26.0, at)
			for i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/trade-%s.png" % view[0])
	print("TRADE_TEST PASS" if errors.is_empty() else "TRADE_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
