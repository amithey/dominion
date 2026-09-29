extends RefCounted
## --setup-test: the New Game sheet offers as many rivals as each map holds, and
## a match set up there starts with them all. Runs in the packaged game too.
static func run(w: Node) -> void:
	var errors: Array[String] = []
	var menu: Node = w.menu
	var catalogue = preload("res://scripts/map_catalogue.gd")
	menu.open_new_game()
	await w.get_tree().process_frame
	for key in ["island", "frontier", "inland_sea", "crown", "great_lakes", "pangaea"]:
		var picker: OptionButton = menu._panel.find_child("MapPicker", true, false)
		var index: int = catalogue.KEYS.find(key)
		picker.select(index)
		picker.item_selected.emit(index)
		await w.get_tree().process_frame
		var most := 0
		for b in menu._panel.find_children("*", "OptionButton", true, false):
			for i in range(b.item_count):
				var text: String = b.get_item_text(i)
				if text == "One rival": most = maxi(most, 1)
				elif text.ends_with(" rivals") and text.split(" ")[0].is_valid_int(): most = maxi(most, int(text.split(" ")[0]))
		var want: int = w.MatchSetup.capacity(key) - 1
		print("  %s: up to %d rivals offered (%d expected)" % [key, most, want])
		if most != want: errors.append("%s offers %d rivals, not %d" % [key, most, want])
	# A crown match of eight, set up from the sheet's own options.
	menu.setup_options.map = "crown"
	menu.setup_options.players = 8
	var options: Dictionary = w.MatchSetup.normalize(menu.setup_options)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(w.MAP_PATH))
	w.MatchSetup.apply(data, options)
	var capitals: int = data.buildings.filter(func(b): return b.key == "hq").size()
	print("  crown with eight: %d nations, %d capitals" % [data.nations.size(), capitals])
	if int(options.players) != 8 or data.nations.size() != 8 or capitals != 8:
		errors.append("a crown match of eight starts with %d nations" % data.nations.size())
	print("SETUP_TEST %s" % ("PASS" if errors.is_empty() else "FAIL: " + str(errors)))
	w.get_tree().quit(0 if errors.is_empty() else 1)
