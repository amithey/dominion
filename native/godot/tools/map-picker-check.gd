extends SceneTree
const Catalogue = preload("res://scripts/map_catalogue.gd")
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok:
		errors.append(label)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.menu.open_new_game()
	await process_frame
	var picker: OptionButton = w.menu._panel.find_child("MapPicker", true, false)
	var preview: TextureRect = w.menu._panel.find_child("MapPreview", true, false)
	var note: Label = w.menu._panel.find_child("MapDescription", true, false)
	check(picker != null and preview != null and note != null, "map picker controls exist")
	if picker == null or preview == null or note == null:
		quit(1)
		return
	check(picker.item_count == Catalogue.KEYS.size(), "all %d maps available" % Catalogue.KEYS.size())
	for i in range(picker.item_count):
		var key: String = Catalogue.KEYS[i]
		picker.select(i)
		picker.item_selected.emit(i)
		await process_frame
		# The sheet is rebuilt for the map's room for rivals.
		picker = w.menu._panel.find_child("MapPicker", true, false)
		preview = w.menu._panel.find_child("MapPreview", true, false)
		note = w.menu._panel.find_child("MapDescription", true, false)
		check(picker.selected == i, key + " stays selected")
		check(w.menu.setup_options.map == key, key + " selection updates campaign")
		check(w.MatchSetup.normalize(w.menu.setup_options).map == key, key + " survives setup normalization")
		check(preview.texture != null and preview.texture.resource_path == Catalogue.preview_path(key), key + " correct preview")
		check(note.text.contains("%d regions" % Catalogue.entry(key).slots), key + " correct capacity")
		check(w.menu._briefing.text.contains(w.menu._map_name(key)), key + " briefing updates immediately")
		check(w.menu.setup_options.players == 4, key + " preserves active players")
		check(preview.get_global_rect().end.x <= w.menu._panel.get_global_rect().end.x, key + " preview fits panel")
	w.menu.setup_options.players = 2
	w.menu.open_new_game()
	await process_frame
	note = w.menu._panel.find_child("MapDescription", true, false)
	check(note.text.contains("2 in this campaign"), "rival changes update map information")
	check(w.menu.setup_options.map == Catalogue.KEYS[-1], "map selection survives rebuilding menu")
	if DisplayServer.get_name() != "headless":
		w.menu._scroll.ensure_control_visible(w.menu._panel.find_child("MapPicker", true, false))
		for i in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/map-picker.png")
	print("MAP_PICKER_TEST PASS" if errors.is_empty() else "MAP_PICKER_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
