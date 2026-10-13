extends SceneTree
const UI := preload("res://scripts/ui_theme.gd")
const Overlay := preload("res://scripts/unit_overlay.gd")
var w: Node
var errors: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func frames(n := 12) -> void:
	for i in range(n): await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label); push_error(label)
func shot(name: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visual-finish/" + name + ".png")
func production_fits() -> void:
	await frames()
	for card in w.hud._list.get_children():
		if not card is Button or not card.has_meta("cost"): continue
		var content: Control = card.get_child(0)
		check(content.get_combined_minimum_size().y <= card.size.y - 17, "Production card height fits")
		check(content.get_combined_minimum_size().x <= content.size.x + 1, "Production card width fits")
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute("res://build/visual-finish")
	set_meta("match_config", {"map":"island", "players":3, "nation":0})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: push_error("Visual scene not ready"); quit(1); return
	# World skips interactive menu setup when a command-line test flag is present.
	if w.menu._root == null: w.menu.setup(w)
	root.size = Vector2i(1280,800)
	w.ui_scale = 1.0
	w.apply_ui_scale()
	w.menu.open_main()
	await shot("01-main-menu")
	w.menu.open_new_game()
	await shot("02-campaign")
	w.menu.open_settings()
	await shot("03-settings")
	w.start_match("easy")
	w.menu.close()
	await frames()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["un", "wmd", "defcon", "directorate", "generals", "events", "support"])
	w.economy.grant_test_resources()
	w.cam_focus = w.start
	w.cam_dist = 110
	w.cam_dist_target = 110
	w.update_camera(1.0)
	if "--visual-forward-smoke" in OS.get_cmdline_user_args():
		await shot("11-forward-battlefield")
		print("VISUAL_FORWARD_SMOKE PASS")
		quit(0)
		return
	await shot("04-battlefield")
	var tank: Dictionary = w.units.filter(func(u): return u.owner == 0 and u.get("vehicle", false) and not u.get("fly", false))[0]
	tank.hp = tank.max_hp * 0.55
	w.select_same_kind(tank)
	w.hud.notice("Selected armour: damaged units retain clear health and ownership markers.", tank.node.position)
	await shot("04-unit-selection")
	for u in w.units:
		u.selected = false
		u.ring.visible = false
	var site: Dictionary = w.place_building("farm", w.start + Vector3(-22,0,18), 0, false)
	site.progress = 0.35
	w.hud._update_panel()
	await shot("04-construction-progress")
	w.hud.set_production_open(true)
	await production_fits()
	await shot("05-construction")
	var silo: Dictionary = w.place_building("missileSilo", w.start + Vector3(18,0,18), 0, true)
	w.select_building(silo)
	await production_fits()
	check(w.hud._extra.defcon[1].get_global_rect().end.x < w.hud.find_child("TimeControls", true, false).get_child(0).get_global_rect().position.x, "All national figures clear time controls with full stores and missiles")
	await shot("06-missiles-selection")
	w.select_building(null)
	w.hud.set_production_open(false)
	w.hud.toggle_cabinet()
	await shot("07-cabinet")
	w.hud.toggle_cabinet()
	w.hud.toggle_log()
	await shot("07-log")
	w.hud.toggle_log()
	for mode in ["diplomacy", "market", "intel", "defence", "territory", "un"]:
		w.hud.toggle_panel(mode, true)
		await frames()
		check(root.get_visible_rect().grow(2).encloses(w.hud._win.get_global_rect()), mode + " window fits at 1280x800")
		await shot("07-" + mode)
	w.hud.toggle_panel("defence", true)
	for tab in ["ai", "arsenal", "nuclear"]:
		w.hud._panels.defence_tab = tab
		w.hud.refresh_side()
		await shot("08-defence-" + tab)
	w.hud.toggle_panel("defence")
	w.hud.toggle_research()
	await shot("09-research")
	w.hud.toggle_research()
	root.size = Vector2i(1600,900)
	w.hud.toggle_panel("market", true)
	await frames()
	check(root.get_visible_rect().grow(2).encloses(w.hud._win.get_global_rect()), "Market fits at 1600x900")
	await shot("10-large-market")
	check(Overlay.role_of({"key":"wheeledHowitzer", "vehicle":true}) == "ART", "New artillery has artillery badge")
	check(Overlay.role_of({"key":"shortRangeSAM", "vehicle":true}) == "AA", "New SAM has air defence badge")
	print("VISUAL_FINISH_VIEWS ", "PASS" if errors.is_empty() else errors, " checks=", checks)
	quit(0 if errors.is_empty() else 1)
