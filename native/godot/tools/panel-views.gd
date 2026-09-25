extends SceneTree
## Every tab of the Diplomacy and Intelligence windows, with a little history
## (a war, an alliance, agents at work), saved to build/panel-*.png.
## Fails if any tab raises a script error or builds an empty window.
var w: Node
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/panel-%s.png" % name)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	w.start_match("easy")
	w.menu._root.hide()
	w.hud.show()
	w.economy.grant_test_resources()
	var d: Node = w.diplomacy
	d.set_flag(d.war, 0, 2, true)
	d.set_flag(d.pact, 0, 1, true)
	if d.n > 3:
		d.set_flag(d.war, 1, 3, true)
	w.place_building("intelAgency", w.test_site("intelAgency", w.start), 0, true)
	w.economy.recalculate()
	w.espionage.recruit()
	w.espionage.recruit()
	w.espionage.run("buildNetwork", 1)
	w.espionage.add_report(1, "reconDossier", "Recon dossier on the Crimson Empire filed", 20.0)
	w.cam_focus = w.start
	w.cam_dist_target = 120.0
	for tab in ["nations", "world", "orders"]:
		w.hud._panels = w.hud._panels if w.hud._panels != null else preload("res://scripts/side_panels.gd").new(w.hud)
		w.hud._panels.diplomacy_tab = tab
		w.hud.toggle_panel("diplomacy", true)
		if w.hud._side_rows.get_child_count() < 2: errors.append("diplomacy %s is empty" % tab)
		await shot("diplomacy-" + tab)
	for tab in ["operations", "agents", "dossiers", "reports"]:
		w.hud._panels.intel_tab = tab
		w.hud.toggle_panel("intel", true)
		if w.hud._side_rows.get_child_count() < 2: errors.append("intel %s is empty" % tab)
		await shot("intel-" + tab)
	w.hud.spy_op = "shipping"
	w.hud.refresh_side()
	await shot("intel-shipping")
	# World market: some price history, a port and an export route.
	for i in range(40):
		w.market.exchange_step()
	w.market.pressure("oil", 900, true)
	for i in range(12):
		w.market.exchange_step()
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
	var port_at = null
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				if port_at == null and w.logistics.hex_distance(home, h) == ring and w.site_problem("port", w.logistics.hex_center(h), 0) == "":
					port_at = w.logistics.hex_center(h)
	if port_at != null:
		w.place_building("port", port_at, 0, true)
		w.economy.recalculate()
		w.market.open_route(1, "oil", "export", 25)
		w.market.tick()
	for tab in ["exchange", "routes"]:
		w.hud._panels.market_tab = tab
		w.hud.toggle_panel("market", true)
		if w.hud._side_rows.get_child_count() < 2: errors.append("market %s is empty" % tab)
		await shot("market-" + tab)
	for tab in ["yours", "nations"]:
		w.hud._panels.territory_tab = tab
		w.hud.toggle_panel("territory", true)
		if w.hud._side_rows.get_child_count() < 2: errors.append("territory %s is empty" % tab)
		await shot("territory-" + tab)
	print("PANEL_VIEWS PASS" if errors.is_empty() else "PANEL_VIEWS FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
