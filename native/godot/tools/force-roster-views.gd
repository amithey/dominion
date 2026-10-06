extends SceneTree
const C := preload("res://scripts/force_catalog.gd")
var w: Node
var failed := 0
var passed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: failed += 1
func frames(n := 6) -> void:
	for frame in range(n): await process_frame
func capture(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/force-%s.png" % name)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1600, 1000)
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for frame in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu.close()
	await frames()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w)
	DirAccess.make_dir_recursive_absolute("res://build")
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("102433")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(40, 30)
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 20)
	canvas.add_child(grid)
	for key in C.ROLES:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(355, 290)
		grid.add_child(card)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(335, 235)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(pic)
		w.portraits.get_portrait(key)
		for frame in range(120):
			await process_frame
			if w.portraits._cache.has(key): break
		pic.texture = w.portraits._cache.get(key)
		check(pic.texture != null, "%s rendered portrait" % key)
		var label := Label.new()
		label.text = C.ROLES[key].name
		label.add_theme_font_size_override("font_size", 20)
		card.add_child(label)
	await capture("roles")
	canvas.queue_free()
	await frames()
	# Real production lists use the same national gates as queue_unit.
	for nation in ["japan", "israel"]:
		w.map.nations[0].id = nation
		C.apply(w)
		for key in w.unit_defs:
			w.unit_defs[key].name = preload("res://scripts/national_variants.gd").name_for(w, 0, key)
		w.portraits._cache.clear()
		var building: Dictionary = w.place_building("tankFactory", w.start + Vector3(26, 0, 26), 0, true)
		w.hud._shown_key = ""
		w.select_building(building)
		await frames(45)
		(w.hud._list.get_parent() as ScrollContainer).scroll_vertical = 100000
		var texts: Array = w.hud._list.find_children("*", "Label", true, false).map(func(n): return n.text)
		var joined: String = " ".join(texts)
		check(("Type 16" in joined and "Type 89" in joined and not "Namer" in joined) if nation == "japan" else ("Namer" in joined and not "Type 16" in joined), "%s factory shows national choices only" % nation)
		await capture(nation + "-factory")
	print("FORCE_VIEWS: %d passed, %d failed" % [passed, failed])
	print("FORCE_VIEWS PASS" if failed == 0 else "FORCE_VIEWS FAIL")
	quit(0 if failed == 0 else 1)
