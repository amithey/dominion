extends SceneTree
## Actual HUD input, queued decisions and the shared munition portrait path.
var w: Node
var hud: Node
var passed := 0
var errors: Array[String] = []
var answers := 0
const Models := preload("res://scripts/munition_portraits.gd")

func _initialize() -> void: call_deferred("run")
func frames(n := 4) -> void:
	for i in range(n): await process_frame
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func handle(panel: Control) -> Control:
	for c in panel.find_children("*", "Control", true, false):
		if c.get_meta("drag_handle", false): return c
	return null

func pointer(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * at
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * at
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)

func drag(panel: Control, target: Vector2) -> void:
	var header := handle(panel)
	var at := header.global_position + Vector2(18, header.size.y * 0.5)
	motion(at)
	await frames(1)
	pointer(at, true)
	await frames(1)
	check(hud._windows.dragging == panel, "%s title starts drag through GUI input" % panel.get_meta("window_id"))
	motion(target + at - panel.global_position)
	await frames(1)
	# Release far from the title; the manager must consume it without a map click.
	pointer(Vector2(850, 700), false)
	await frames(2)
	check(hud._windows.dragging == null and panel.visible, "%s release outside title keeps window open" % panel.get_meta("window_id"))

func pics(panel: Node) -> Array:
	return panel.find_children("*", "TextureRect", true, false).filter(func(c): return c.has_meta("portrait_key"))

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--input-only" in OS.get_cmdline_user_args(): return
	await frames(80)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/ui-%s.png" % name)
	print("CAPTURE ", name)

func run() -> void:
	root.size = Vector2i(1600, 1000)
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	await frames(3)
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu.close()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["wmd"])
	hud = w.hud
	hud._letters.clear()
	if hud._letter_box != null:
		hud._letter_box.queue_free()
		hud._letter_box = null
	preload("res://scripts/cheats.gd").everything(w)
	root.content_scale_size = Vector2i(1600, 1000)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600, 1000)
	await frames(8)
	if DisplayServer.get_name() != "headless" and not "--input-only" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://build")
	var families := {}
	for key in w.missiles.types():
		var model: Node3D = Models.build(key, w.missiles.def_of(key))
		check(model != null and model.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s has a munition model" % key)
		if model != null:
			families[model.get_meta("munition_family")] = true
			model.free()
	check(families.size() >= 9, "payload families have distinct silhouettes")
	hud.set_production_open(true)
	await frames()
	hud._build_search.text = "farm"
	hud._build_search.text_changed.emit("farm")
	await frames()
	var rows: int = hud._list.get_child_count()
	await drag(hud._prod, Vector2(780, 130))
	check(hud._build_search.text == "farm" and hud._list.get_child_count() == rows, "production drag retains search and content")
	var prod_at: Vector2 = hud._prod.position
	hud.set_production_open(false)
	hud.set_production_open(true)
	await frames()
	check(hud._prod.position.is_equal_approx(prod_at), "production reopens at moved position")
	hud.toggle_panel("market", true)
	await frames(16)
	hud._win_scroll.scroll_vertical = 60
	await frames(12)
	var scroll: int = hud._win_scroll.scroll_vertical
	check(scroll == mini(60, int(hud._win_scroll.get_v_scroll_bar().max_value - hud._win_scroll.get_v_scroll_bar().page)), "requested ministry scroll survives automatic briefing layout")
	print("SCROLL_LAYOUT before size=", hud._win_scroll.size, " max=", hud._win_scroll.get_v_scroll_bar().max_value, " page=", hud._win_scroll.get_v_scroll_bar().page)
	await drag(hud._win, Vector2(20, 190))
	print("SCROLL_DRAG before=", scroll, " after=", hud._win_scroll.scroll_vertical)
	print("SCROLL_LAYOUT after size=", hud._win_scroll.size, " max=", hud._win_scroll.get_v_scroll_bar().max_value, " page=", hud._win_scroll.get_v_scroll_bar().page)
	check(hud.side_mode == "market" and hud._win_scroll.scroll_vertical == scroll, "ministry drag retains screen and scroll")
	var market_at: Vector2 = hud._win.position
	hud.refresh_side()
	await frames(8)
	check(hud._win.position.is_equal_approx(market_at), "live ministry refresh retains moved position")
	print("SCROLL_REFRESH value=", hud._win_scroll.scroll_vertical, " max=", hud._win_scroll.get_v_scroll_bar().max_value, " page=", hud._win_scroll.get_v_scroll_bar().page)
	check(hud._win_scroll.scroll_vertical == scroll, "live ministry refresh retains scroll after container layout")
	if "--scroll-only" in OS.get_cmdline_user_args():
		print("SCROLL_CHECK PASS" if errors.is_empty() else "SCROLL_CHECK FAIL")
		quit(0 if errors.is_empty() else 1)
		return
	hud.notice("A notice stays on screen while windows are floating.")
	hud._refresh = 1.0
	hud._process(0.3)
	await frames()
	check(root.get_visible_rect().grow(2).encloses(hud._notices.get_global_rect()), "notice feed stays on screen after windows move")
	hud.choose("Decision one", "An incoming proposal stays pending while its window is moved.", [["Continue", "good", func(): answers += 1]])
	hud.choose("Decision two", "This next proposal waits until the first is answered.", [["Continue", "good", func(): answers += 1]])
	await frames(8)
	var alert: Control = hud._letter_box
	print("WINDOW_RECTS ", hud._prod.get_global_rect(), " ", hud._win.get_global_rect(), " ", alert.get_global_rect(), " viewport ", root.get_visible_rect())
	check(hud._letters.size() == 1 and hud._win.visible and hud._prod.visible, "alerts queue and preserve existing open windows")
	check(not alert.get_global_rect().intersects(hud._prod.get_global_rect()) and not alert.get_global_rect().intersects(hud._win.get_global_rect()), "new alert occupies free space when available")
	await capture("windows")
	await drag(alert, Vector2(520, 560))
	check(answers == 0 and hud._letters.size() == 1 and hud._letter_box == alert, "drag never answers or dismisses a pending decision")
	var alert_at: Vector2 = alert.position
	var answer: Button = alert.find_children("*", "Button", true, false)[0]
	var answer_at := answer.global_position + answer.size * 0.5
	motion(answer_at)
	pointer(answer_at, true)
	await frames(1)
	pointer(answer_at, false)
	await frames(8)
	check(answers == 1 and hud._letters.is_empty() and hud._letter_box != alert, "answer resolves once and reveals next queued decision")
	check(hud._letter_box.position.is_equal_approx(alert_at), "next alert uses the player's moved position")
	hud._letter_box.find_children("*", "Button", true, false)[0].pressed.emit()
	await frames()
	check(answers == 2 and hud._letter_box == null, "both queued decisions resolve exactly once")
	hud._show_side("")
	hud._build_search.clear()
	for facility in ["missileSilo", "strategicComplex", "specialLab"]:
		if facility == "specialLab": w.map.nations[0]["id"] = "north_korea"
		var site: Variant = w.test_site(facility, w.start)
		if site == null: site = w.start + Vector3(150, 0, 150)
		var building: Dictionary = w.place_building(facility, site, 0, true)
		if building.is_empty():
			check(false, "%s fixture placed" % facility)
			continue
		w.select_building(building)
		await frames(8)
		var portraits := pics(hud._list)
		check(not portraits.is_empty() and portraits.all(func(c): return str(c.get_meta("portrait_key")).begins_with("missile:")), "%s production uses payload portraits" % facility)
		var keys: Array = w.missiles.listed_at(facility)
		if not keys.is_empty():
			hud._fill_queue(["missile:" + str(keys[0])], 0.4)
			check(pics(hud._sel_queue)[0].get_meta("portrait_key") == "missile:" + str(keys[0]), "%s queue uses the same payload portrait" % facility)
		await capture(facility)
	# Push beyond every screen edge and resize; the title remains reachable.
	await drag(hud._prod, Vector2(-10000, -10000))
	check(hud._prod.position.x >= 12 and hud._prod.position.y >= 56, "drag clamps the left and top edges")
	await drag(hud._prod, Vector2(10000, 10000))
	check(hud._prod.get_global_rect().end.x <= 1588.1 and hud._prod.get_global_rect().end.y <= 988.1, "drag clamps the right and bottom edges")
	root.content_scale_size = Vector2i(1280, 800)
	root.size = Vector2i(1280, 800)
	await frames(8)
	check(hud._prod.position.x >= 12 and hud._prod.get_global_rect().end.x <= 1268.1 and hud._prod.position.y <= 80, "viewport resize brings moved window back into reach")
	root.content_scale_factor = 0.8
	await frames(8)
	await drag(hud._prod, Vector2(500, 130))
	print("SCALED_DRAG position=", hud._prod.position, " view=", root.get_visible_rect(), " transform=", root.get_final_transform())
	check(hud._prod.position.is_equal_approx(Vector2(500, 130)), "drag follows the cursor with the game's scaled interface")
	if DisplayServer.get_name() != "headless" and not "--input-only" in OS.get_cmdline_user_args(): await gallery()
	print("WINDOWS_PORTRAITS %s: %d passed, %d failed" % ["PASS" if errors.is_empty() else "FAIL", passed, errors.size()])
	quit(0 if errors.is_empty() else 1)

func gallery() -> void:
	var keys := ["tactical", "cruise", "ballistic", "antiShip", "hypersonic", "antiRadar", "cluster", "bunkerMissile", "thermobaricMissile", "nuke", "tacticalNuke", "mirv", "nuclearCruise", "nuclearEmp", "neutronBomb", "tsarBomba", "poseidon", "chemical"]
	for key in keys: w.portraits.get_portrait("missile:" + key)
	for i in range(600):
		await process_frame
		if keys.all(func(k): return w.portraits._cache.get("missile:" + k) != null): break
	check(keys.all(func(k): return w.portraits._cache.get("missile:" + k) != null), "rendered portraits are ready for every displayed payload")
	root.content_scale_size = Vector2i(1600, 1000)
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600, 1000)
	var sheet := PanelContainer.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(sheet)
	sheet.add_theme_stylebox_override("panel", preload("res://scripts/ui_theme.gd").box(Color("0b1722"), Color("c1af86"), 1, 8, 20.0))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	sheet.add_child(grid)
	for key in keys:
		var card := VBoxContainer.new()
		grid.add_child(card)
		var pic := TextureRect.new()
		pic.texture = w.portraits.get_portrait("missile:" + key)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(245, 245)
		card.add_child(pic)
		var caption := Label.new()
		caption.text = key
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 19)
		card.add_child(caption)
	await capture("munition-gallery")
	sheet.queue_free()
