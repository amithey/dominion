extends CanvasLayer
## A visible frame before map generation; loading is never an unexplained blank.
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color("10233a")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	for item in [["DOMINION", 42], ["Preparing your campaign…", 22], ["Generating terrain, cities and navigation. Large maps can take a moment.", 16]]:
		var label := Label.new()
		label.text = item[0]
		label.add_theme_font_size_override("font_size", item[1])
		label.add_theme_color_override("font_color", Color("eee9de"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
