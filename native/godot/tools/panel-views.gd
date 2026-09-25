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
	print("PANEL_VIEWS PASS" if errors.is_empty() else "PANEL_VIEWS FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
