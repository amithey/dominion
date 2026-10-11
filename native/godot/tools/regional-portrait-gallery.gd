extends SceneTree
const F := preload("res://scripts/factions.gd")
const R := preload("res://scripts/regional_factions.gd")
const Gallery := preload("res://scripts/leader_gallery.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1536, 1024)
	root.content_scale_size = Vector2i(1536, 1024)
	var background := ColorRect.new()
	background.color = Color("10233a")
	background.size = Vector2(1536, 1024)
	root.add_child(background)
	for i in range(R.IDS.size()):
		var x := 24 + (i % 3) * 512
		var y := 20 + (i / 3) * 512
		var title := Label.new()
		title.text = R.NAMES[i]
		title.position = Vector2(x, y)
		title.add_theme_font_size_override("font_size", 22)
		root.add_child(title)
		var full := TextureRect.new()
		full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		full.texture = load(Gallery.portrait(R.LEADERS[i]))
		full.position = Vector2(x, y + 40)
		full.size = Vector2(280, 380)
		full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(full)
		var face := TextureRect.new()
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture = Gallery.badge(R.LEADERS[i])
		face.position = Vector2(x + 292, y + 40)
		face.size = Vector2(180, 180)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		root.add_child(face)
		var wide := TextureRect.new()
		wide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wide.texture = Gallery.face(R.LEADERS[i], 292.0 / 160.0)
		wide.position = Vector2(x + 292, y + 240)
		wide.size = Vector2(180, 99)
		wide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		root.add_child(wide)
		var name_label := Label.new()
		name_label.text = R.LEADERS[i]
		name_label.position = Vector2(x, y + 430)
		name_label.size = Vector2(472, 60)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(name_label)
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build")
	root.get_texture().get_image().save_png("res://build/regional-portrait-gallery.png")
	print("REGIONAL_PORTRAIT_GALLERY PASS")
	quit()


