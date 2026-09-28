extends SceneTree
## A rendered asset contact sheet, using the game's own portrait cropper.
const F = preload("res://scripts/factions.gd")
const Gallery = preload("res://scripts/leader_gallery.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(1536, 1080)
	var bg := ColorRect.new()
	bg.color = Color("0c1920")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(24, 24)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	bg.add_child(grid)
	for i in range(9):
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(480, 326)
		grid.add_child(col)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(480, 256)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.texture = Gallery.face(F.LEADERS[i], 480.0 / 256.0)
		col.add_child(pic)
		var name := Label.new()
		name.text = F.NAMES[i]
		name.add_theme_font_size_override("font_size", 24)
		name.modulate = Color(F.COLOURS[i]).lightened(0.3)
		col.add_child(name)
		var leader := Label.new()
		leader.text = F.LEADERS[i]
		leader.add_theme_font_size_override("font_size", 17)
		col.add_child(leader)
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/faction-leaders.png")
	quit()
