extends CanvasLayer
## Main menu and pause menu. The world loads behind the menu and the camera
## circles the island slowly while the game is paused. New Game asks for a
## difficulty; Continue loads the newest save; Settings (graphics quality,
## full screen, master volume) persist in user://settings.cfg. In a match, Esc
## opens the pause menu: resume, save, load, settings, quit to the main menu.

const SETTINGS := "user://settings.cfg"
const GOLD := Color("a29269")
const DIFFICULTIES := [
	["easy", "Easy", "Rivals grow slowly and rarely attack. The first wave comes after about 13 minutes."],
	["normal", "Normal", "A fair fight: stronger economies, earlier and larger attacks."],
	["hard", "Hard", "Aggressive rivals with rich economies. Diplomacy sours quickly."],
]

var world: Node
var in_match := false
var _root: Control
var _panel: VBoxContainer
var _title: Label
var _subtitle: Label

func setup(world_node: Node) -> void:
	world = world_node
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# A dark band on the left so the menu reads over the moving scene.
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.07, 0.09, 0.78)
	shade.anchor_bottom = 1.0
	shade.offset_right = 460
	_root.add_child(shade)
	var box := VBoxContainer.new()
	box.offset_left = 56
	box.offset_top = 90
	box.offset_right = 420
	box.add_theme_constant_override("separation", 10)
	_root.add_child(box)
	_title = Label.new()
	_title.text = "DOMINION"
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color("f1e3b4"))
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = "Nations · supply lines · war"
	_subtitle.add_theme_color_override("font_color", GOLD)
	_subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(_subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	box.add_child(_panel)
	var credit := Label.new()
	credit.text = "Prototype build · Godot %s" % Engine.get_version_info().string
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 56
	credit.offset_top = -44
	_root.add_child(credit)
	load_settings()

# ---------------------------------------------------------------- screens

func open_main() -> void:
	in_match = false
	_show(true)
	_clear()
	_heading("")
	_button("New Game", open_new_game)
	var newest := newest_save()
	var continue_button := _button("Continue", func(): load_game(newest))
	continue_button.disabled = newest == ""
	_button("Load Game", open_load)
	_button("Settings", open_settings)
	_button("Quit", func(): world.get_tree().quit())

func open_pause() -> void:
	in_match = true
	_show(true)
	_clear()
	_heading("PAUSED")
	_button("Resume", close)
	_button("Save Game", func():
		world.saves.save("quicksave")
		close())
	_button("Load Game", open_load)
	_button("Settings", open_settings)
	_button("Quit to Main Menu", func():
		world.get_tree().paused = false
		world.get_tree().reload_current_scene())
	_button("Quit to Desktop", func(): world.get_tree().quit())

func open_new_game() -> void:
	_clear()
	_heading("NEW GAME")
	for d in DIFFICULTIES:
		var b := _button(d[1], func(): start(d[0]))
		b.tooltip_text = d[2]
		var note := Label.new()
		note.text = d[2]
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(340, 0)
		note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		_panel.add_child(note)
	_button("Back", open_main)

func open_load() -> void:
	_clear()
	_heading("LOAD GAME")
	var slots := list_saves()
	if slots.is_empty():
		var none := Label.new()
		none.text = "No saved games yet. F5 saves during a match."
		_panel.add_child(none)
	for s in slots:
		_button("%s   %s" % [s.name.capitalize(), s.date], func(): load_game(s.name))
	_button("Back", open_pause if in_match else open_main)

func open_settings() -> void:
	_clear()
	_heading("SETTINGS")
	var quality := OptionButton.new()
	for q in ["high", "balanced", "low"]:
		quality.add_item(q.capitalize())
	quality.selected = ["high", "balanced", "low"].find(world.quality)
	quality.item_selected.connect(func(i):
		world.quality = ["high", "balanced", "low"][i]
		world.apply_quality()
		save_settings())
	_row("Graphics", quality)
	var full := CheckButton.new()
	full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	full.toggled.connect(func(on):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		save_settings())
	_row("Full screen", full)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.custom_minimum_size = Vector2(180, 0)
	volume.value = roundf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0)
	volume.value_changed.connect(func(v):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.1) / 100.0))
		save_settings())
	_row("Volume", volume)
	_button("Back", open_pause if in_match else open_main)

func close() -> void:
	_show(false)
	world.get_tree().paused = false

func _show(visible_now: bool) -> void:
	_root.visible = visible_now
	world.hud.visible = not visible_now
	world.info_layer.visible = not visible_now
	world.get_tree().paused = visible_now

# ---------------------------------------------------------------- actions

func start(difficulty: String) -> void:
	world.start_match(difficulty)
	close()

func load_game(slot: String) -> void:
	if slot == "":
		return
	if world.saves.load_slot(slot):
		close()

func list_saves() -> Array:
	var out := []
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".json") and file != "test.json":
			var name := file.get_basename()
			var modified := FileAccess.get_modified_time("user://saves/" + file)
			out.append({"name": name, "time": modified, "date": Time.get_datetime_string_from_unix_time(modified).replace("T", " ")})
	out.sort_custom(func(a, b): return a.time > b.time)
	return out

func newest_save() -> String:
	var slots := list_saves()
	return slots[0].name if not slots.is_empty() else ""

# ---------------------------------------------------------------- settings file

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	var q: String = cfg.get_value("graphics", "quality", world.quality)
	if q != world.quality:
		world.quality = q
		world.apply_quality()
	if cfg.get_value("graphics", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(cfg.get_value("audio", "volume", 100.0)), 0.1) / 100.0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", world.quality)
	cfg.set_value("graphics", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.set_value("audio", "volume", roundf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0))
	cfg.save(SETTINGS)

# ---------------------------------------------------------------- widgets

func _clear() -> void:
	for child in _panel.get_children():
		child.queue_free()

func _heading(text: String) -> void:
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_font_size_override("font_size", 20)
	_panel.add_child(label)

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	_panel.add_child(b)
	return b

func _row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	row.add_child(control)
	_panel.add_child(row)

func _unhandled_input(event: InputEvent) -> void:
	if _root != null and _root.visible and in_match and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

# The island turns slowly behind the menu.
func _process(delta: float) -> void:
	if _root != null and _root.visible and not in_match and world.camera != null:
		world.cam_yaw += delta * 0.05
		world.update_camera(delta)
