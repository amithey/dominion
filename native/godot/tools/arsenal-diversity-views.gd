extends SceneTree
const Data := preload("res://scripts/arsenal_diversity_data.gd")
var w: Node
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n := 8) -> void:
	for frame in range(n): await process_frame
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if not ok: failures += 1
func capture(name: String) -> void:
	await frames(14)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/arsenal-%s.png" % name)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for frame in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		push_error("Arsenal visual scene did not become ready")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	w.start_match("easy")
	w.menu.close()
	await frames()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["un", "wmd", "defcon", "ai_directorate", "generals"])
	w.ui_scale = 1.0
	w.apply_ui_scale()
	DirAccess.make_dir_recursive_absolute("res://build")
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "arsenal"
	for pair in [["japan", "fires"], ["ethiopia", "fires"], ["sudan", "limits"], ["usa", "land"]]:
		w.hud._panels.arsenal_country = pair[0]
		w.hud._panels.arsenal_domain = pair[1]
		w.hud.refresh_side()
		await frames()
		var picker: OptionButton = w.hud._side_rows.find_child("ArsenalCountry", true, false)
		check(picker != null and picker.item_count == 28, str(pair[0]) + " country picker")
		check(w.hud._win.get_global_rect().end.x <= 1281, str(pair[0]) + " window fits viewport")
		for label: Label in w.hud._side_rows.find_children("*", "Label", true, false):
			check(label.size.x < 540, str(pair[0]) + " label wraps: " + label.text.left(30))
		await capture(str(pair[0]) + "-" + str(pair[1]))
	w.hud.toggle_panel("defence")
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("102433")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var row := HBoxContainer.new()
	row.position = Vector2(30, 140)
	row.add_theme_constant_override("separation", 20)
	canvas.add_child(row)
	for key: String in Data.ROSTER:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(390, 350)
		row.add_child(card)
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(380, 300)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(picture)
		w.portraits.get_portrait(key)
		for frame in range(180):
			await process_frame
			if w.portraits._cache.has(key): break
		picture.texture = w.portraits._cache.get(key)
		check(picture.texture != null, key + " rendered native portrait")
		var title := Label.new()
		title.text = w.unit_defs[key].get("generic", key)
		title.add_theme_font_size_override("font_size", 20)
		card.add_child(title)
	await capture("new-models")
	print("ARSENAL_DIVERSITY_VIEWS PASS" if failures == 0 else "ARSENAL_DIVERSITY_VIEWS FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
