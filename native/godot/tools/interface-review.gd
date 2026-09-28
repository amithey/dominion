extends SceneTree
## Visual and geometry regression for the menus and the in-match command UI.
var errors: Array[String] = []
var w: Node

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in range(20):
		await process_frame

func shot(page: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/interface-%s.png" % page)

func check(value: bool, label: String) -> void:
	if not value:
		errors.append(label)
		push_error(label)

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.menu.open_main()
	await shot("main")
	for nation in [0, 2, 8]:
		w.menu.setup_options.nation = nation
		w.menu.setup_options.map = "crown" if nation == 8 else "island"
		w.menu.open_new_game()
		await settle()
		var go: Button = w.menu._root.find_child("BeginCampaign", true, false)
		check(go != null and go.is_visible_in_tree(), "Begin campaign is visible")
		check(root.get_visible_rect().encloses(go.get_global_rect()), "Begin campaign fits the viewport")
		check(w.menu._footer.get_global_rect().position.y >= w.menu._scroll.get_global_rect().end.y, "Footer never overlaps the scrolling choices")
		var cols: Control = w.menu._panel.find_child("CampaignColumns", true, false)
		check(cols.size.x <= w.menu._scroll.size.x + 1, "Campaign columns fit without horizontal clipping")
		await shot("campaign-%d" % nation)
		var profile: Control = w.menu._panel.find_child("NationalProfile", true, false)
		if profile != null:
			profile.get_child(0).button_pressed = true
			await settle()
			w.menu._scroll.scroll_vertical = 9999
			await settle()
			check(root.get_visible_rect().encloses(go.get_global_rect()), "Begin stays visible with expanded national profile")
			check(profile.get_child(1).visible, "National profile expands")
			if nation == 8:
				await shot("campaign-profile")
	for tab in ["graphics", "sound", "controls", "game"]:
		w.menu.settings_tab = tab
		w.menu.open_settings()
		await shot("settings-" + tab)
	w.start_match("easy")
	paused = false
	w.menu._root.hide()
	w.hud.show()
	w.cam_focus = w.start
	w.cam_dist_target = 120.0
	await shot("hud")
	w.hud.set_production_open(true)
	await shot("build")
	w.hud.set_production_open(false)
	for mode in ["diplomacy", "market", "intel", "territory"]:
		w.hud.toggle_panel(mode, true)
		await shot(mode)
		check(root.get_visible_rect().encloses(w.hud._win.get_global_rect()), mode + " panel fits viewport")
		if mode == "diplomacy":
			var profile: Control = w.hud._side_rows.find_child("NationalProfile", true, false)
			if profile != null:
				profile.get_child(0).button_pressed = true
				await shot("diplomacy-profile")
				check(root.get_visible_rect().encloses(w.hud._win.get_global_rect()), "Expanded diplomacy profile fits viewport")
		check(w.hud._screen_buttons["land" if mode == "territory" else mode].button_pressed, mode + " navigation is highlighted")
	w.hud._show_side("")
	w.hud.toggle_panel("diplomacy", true)
	w.hud.set_production_open(true)
	w.hud.notice("Both command panels can remain open while messages stay readable.")
	await shot("both-docks")
	check(not w.hud._notices.get_global_rect().intersects(w.hud._prod.get_global_rect()), "Notices avoid construction")
	check(not w.hud._notices.get_global_rect().intersects(w.hud._win.get_global_rect()), "Notices avoid diplomacy")
	w.hud.set_production_open(false)
	w.hud._show_side("")
	w.hud.toggle_research()
	await shot("research")
	w.hud.toggle_research()
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	w.select_building(capital)
	await shot("selection")
	w.menu.open_pause()
	await shot("pause")
	w.menu.settings_tab = "graphics"
	w.menu.open_settings()
	await shot("pause-settings")
	print("INTERFACE_REVIEW PASS" if errors.is_empty() else "INTERFACE_REVIEW FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
