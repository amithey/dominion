extends SceneTree
## Pictures of the new tools of war (war_tools.gd) as their unit cards draw them:
## build/war-tools-models.png. Needs a window (not headless).
const NEW := ["mineLayer", "mineClearer", "recoveryVehicle", "decoy", "counterBatteryRadar", "coastalASM", "aewc", "ewJet", "maritimePatrol", "carrier", "asFrigate"]
var w: Node
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n := 8) -> void:
	for frame in range(n): await process_frame
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
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	w.start_match("easy")
	w.menu.close()
	await frames()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://build")
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("102433")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(20, 16)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	canvas.add_child(grid)
	for key: String in NEW:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(300, 250)
		grid.add_child(card)
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(300, 215)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(picture)
		w.portraits.get_portrait(key)
		for frame in range(240):
			await process_frame
			if w.portraits._cache.has(key): break
		picture.texture = w.portraits._cache.get(key)
		if picture.texture == null:
			failures += 1
			print("FAIL no portrait: " + key)
		var title := Label.new()
		title.text = "%s  (%s)" % [w.unit_defs[key].get("generic", key), w.unit_defs[key].name]
		title.add_theme_font_size_override("font_size", 14)
		card.add_child(title)
	await frames(14)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/war-tools-models.png")
	print("WAR_TOOLS_VIEWS PASS" if failures == 0 else "WAR_TOOLS_VIEWS FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
