extends SceneTree
## Pictures of every in-game menu (the strip, the Cabinet, build, research, market,
## intelligence, diplomacy, territory, selections, help, pause) to user://menus-*.png,
## for reviewing the look. Run with a window: --path . --resolution 1600x900 --script.
var w: Node
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in range(14): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("menus-%s.png" % name))
	print("SHOT ", name)
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu.close()
	w.hud.show()
	w.economy.grant_test_resources()
	w.place_building("intelAgency", w.test_site("intelAgency", w.start), 0, true)
	w.economy.recalculate()
	# (a few minutes of history for the Cabinet's charts)
	for i in range(36):
		w.game_time += 5.0
		w.economy.res.money += randf_range(-800.0, 1500.0)
		w.economy.civilians += randf_range(-3.0, 6.0)
		w.hud._refresh = 1.0
		w.hud._process(0.3)
	for i in range(30): await process_frame
	await shot("hud")
	w.hud.toggle_cabinet()
	await shot("cabinet")
	w.hud.toggle_cabinet()
	w.hud.toggle_build()
	await shot("build")
	w.hud.toggle_build()
	w.hud.toggle_research()
	await shot("research")
	w.hud.toggle_research()
	for p in ["market", "intel", "diplomacy", "territory"]:
		w.hud.toggle_panel(p, true)
		await shot(p)
		w.hud.toggle_panel(p)
	var tanks: Array = w.units.filter(func(u): return u.owner == 0 and u.key == "tank")
	for u in tanks: u.selected = true
	await shot("units")
	for u in w.units: u.selected = false
	var barracks = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks")
	if not barracks.is_empty():
		w.select_building(barracks[0])
		await shot("barracks")
		w.select_building(null)
	var hq = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	w.select_building(hq)
	await shot("capital")
	w.select_building(null)
	w.hud.toggle_help()
	await shot("help")
	w.hud.toggle_help()
	w.menu.open_pause()
	await shot("pause")
	quit()
