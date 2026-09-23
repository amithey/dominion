extends CanvasLayer
## Main menu and pause menu. An illustrated war table with drifting light
## fills the opening screen. New Game asks for a
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

const UI := preload("res://scripts/ui_theme.gd")

var _table: Control
var _shade: TextureRect
var _dim: ColorRect
var _brand: VBoxContainer
var _card: PanelContainer
var _band: PanelContainer
var _band_title: Label
var _margins: MarginContainer
var setup_options := {"map":"island","players":4,"nation":0,"style":"standard"}
var setup_difficulty := "easy"
var _briefing: Label
var _transition: Tween
var _scroll: ScrollContainer

func setup(world_node: Node) -> void:
	world = world_node
	setup_options = world.match_config.duplicate()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# A dedicated council-room backdrop covers the world only in the main menu.
	_table = preload("res://scripts/war_table.gd").new()
	_root.add_child(_table)
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Preserve contrast for every submenu without flattening the artwork.

	var fade := Gradient.new()
	fade.set_color(0, Color(0.025, 0.04, 0.04, 0.68))
	fade.add_point(0.62, Color(0.025, 0.04, 0.04, 0.36))
	fade.set_color(fade.get_point_count() - 1, Color(0.03, 0.06, 0.08, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.width = 256
	tex.height = 4
	_shade = TextureRect.new()
	_shade.texture = tex
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.anchor_bottom = 1.0
	_shade.offset_right = 1000
	_root.add_child(_shade)
	# Pause menu: the whole game dims behind a card.
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.05, 0.62)
	_root.add_child(_dim)
	_brand = VBoxContainer.new()
	_brand.offset_left = 64
	_brand.offset_top = 70
	_brand.add_theme_constant_override("separation", 16)
	_root.add_child(_brand)
	var crest := HBoxContainer.new()
	crest.add_theme_constant_override("separation", 18)
	_brand.add_child(crest)
	var emblem := TextureRect.new()
	emblem.texture = UI.icon("sovereign")
	emblem.custom_minimum_size = Vector2(70, 70)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.add_child(emblem)
	_title = Label.new()
	_title.text = "DOMINION"
	_title.theme_type_variation = "HeaderLabel"
	_title.add_theme_font_size_override("font_size", 62)
	_title.add_theme_color_override("font_color", Color("f1e3b4"))
	_title.add_theme_constant_override("outline_size", 2)
	crest.add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = "A WORLD TO SHAPE. A NATION TO LEAD."
	_subtitle.add_theme_color_override("font_color", UI.GOLD)
	_subtitle.add_theme_font_size_override("font_size", 16)
	_brand.add_child(_subtitle)
	var rule := ColorRect.new()
	rule.color = Color(UI.GOLD, 0.6)
	rule.custom_minimum_size = Vector2(420, 2)
	_brand.add_child(rule)
	# The menu sits in a card: under the title on the main menu, centred over
	# the dimmed game when paused.
	_card = PanelContainer.new()
	_root.add_child(_card)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	_card.add_child(frame)
	# The name of the screen rides a lit band closed by a gold rule.
	_band = PanelContainer.new()
	_band.add_theme_stylebox_override("panel", UI.band(10.0))
	_band.visible = false
	frame.add_child(_band)
	_band_title = Label.new()
	_band_title.theme_type_variation = "HeaderLabel"
	_band_title.add_theme_font_size_override("font_size", 18)
	_band_title.add_theme_color_override("font_color", UI.BRIGHT)
	_band.add_child(_band_title)
	_margins = MarginContainer.new()
	_margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(_margins)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_margins.add_child(_scroll)
	_panel = VBoxContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_theme_constant_override("separation", 10)
	_scroll.add_child(_panel)
	var credit := Label.new()
	credit.text = "DOMINION  ·  %s" % ProjectSettings.get_setting("application/config/version", "")
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 64
	credit.offset_top = -40
	_root.add_child(credit)
	load_settings()

## Main menu: title and card on the left. Paused: a card in the middle.
func _layout(paused: bool) -> void:
	_table.visible = not paused
	_shade.visible = not paused
	_brand.visible = not paused
	_dim.visible = paused
	# Paused, the card is a box and needs room inside it; on the main menu the
	# entries run flush under the title, with only a breath below the band.
	for side in ["left", "right", "bottom"]:
		_margins.add_theme_constant_override("margin_" + side, 18 if paused else 0)
	_margins.add_theme_constant_override("margin_top", 18 if paused else 12)
	if paused:
		_card.add_theme_stylebox_override("panel", UI.plate(Color("1a343d", 0.97), Color("0a191f", 0.97), UI.GOLD, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 10))
		_card.anchor_left = 0.5
		_card.anchor_right = 0.5
		_card.anchor_top = 0.5
		_card.anchor_bottom = 0.5
		_card.offset_left = -212
		_card.offset_right = 212
		_card.offset_top = -240
		_card.offset_bottom = 240
	else:
		_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_card.anchor_left = 0.0
		_card.anchor_right = 0.0
		_card.anchor_top = 0.0
		_card.anchor_bottom = 0.0
		_card.offset_left = 64
		_card.offset_right = 484
		_card.offset_top = 230
		_card.anchor_bottom = 1.0
		_card.offset_bottom = -64

# ---------------------------------------------------------------- screens

func open_main() -> void:
	in_match = false
	_show(true)
	_layout(false)
	_clear()
	_heading("")
	var invitation := _description("THE WAR COUNCIL")
	invitation.add_theme_color_override("font_color", UI.GOLD)
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
	_layout(true)
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
	_heading("CHART YOUR CAMPAIGN")
	_description("Choose your nation, rivals and the rules of engagement.")
	_setup_choice("Map",["Island · original","Island · mirrored west"],["island","mirrored"],"map")
	_setup_choice("Players",["2 · you + 1 AI","3 · you + 2 AI","4 · you + 3 AI"],[2,3,4],"players")
	_setup_choice("Nation / leader",world.MatchSetup.NATIONS,[0,1,2,3],"nation")
	_setup_choice("Style",["Standard strategy","Sandbox · no AI attack waves"],["standard","sandbox"],"style")
	var difficulty := OptionButton.new()
	for d in DIFFICULTIES:
		difficulty.add_item(d[1])
	difficulty.selected = ["easy","normal","hard"].find(setup_difficulty)
	difficulty.item_selected.connect(func(i):
		setup_difficulty=DIFFICULTIES[i][0]
		_update_briefing())
	_row("Difficulty",difficulty)
	_briefing = _description("")
	_update_briefing()
	_button("Begin campaign",func():start(setup_difficulty))
	_button("Back", open_main)

func _setup_choice(title: String,labels: Array,values: Array,key: String) -> void:
	var choice := OptionButton.new()
	choice.custom_minimum_size.x = 230
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.clip_text = true
	for label in labels:
		choice.add_item(label)
	choice.selected = values.find(setup_options[key])
	choice.item_selected.connect(func(i):
		setup_options[key]=values[i]
		_update_briefing())
	_row(title,choice)

func _description(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 340
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UI.MUTED)
	_panel.add_child(label)
	return label

func _update_briefing() -> void:
	if not is_instance_valid(_briefing):
		return
	var difficulty: Array = DIFFICULTIES[["easy","normal","hard"].find(setup_difficulty)]
	_briefing.text = "%s\n%d rival nations · %s\n%s" % [world.MatchSetup.NATIONS[int(setup_options.nation)], int(setup_options.players)-1, "mirrored island" if setup_options.map=="mirrored" else "original island", "Sandbox: rivals develop and defend, but launch no attack waves." if setup_options.style=="sandbox" else difficulty[2]]

func open_load() -> void:
	_clear()
	_heading("LOAD GAME")
	var slots := list_saves()
	if slots.is_empty():
		var none := Label.new()
		none.text = "No saved games yet. F5 saves during a match."
		_panel.add_child(none)
	for s in slots:
		_option_card(s.name.capitalize(), "Saved %s" % s.date, func(): load_game(s.name))
	_button("Back", open_pause if in_match else open_main)

func open_settings() -> void:
	_clear()
	_heading("SETTINGS")
	_description("Changes apply immediately and are saved automatically.")
	var quality := OptionButton.new()
	for q in ["high", "balanced", "low"]:
		quality.add_item(q.capitalize())
	quality.selected = ["high", "balanced", "low"].find(world.quality)
	quality.item_selected.connect(func(i):
		world.quality = ["high", "balanced", "low"][i]
		world.apply_quality()
		save_settings())
	_row("Graphics", quality)
	quality.tooltip_text = "High: full effects. Balanced: lighter shadows and upscaling. Low: prioritise performance."
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
	var volume_readout := Label.new()
	volume_readout.text = "%d%%" % volume.value
	volume.get_parent().add_child(volume_readout)
	volume.value_changed.connect(func(v):volume_readout.text = "%d%%" % v)
	var edge := CheckButton.new()
	edge.button_pressed = world.edge_scroll
	edge.toggled.connect(func(on):
		world.edge_scroll = on
		save_settings())
	_row("Scroll at screen edge", edge)
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
	if setup_options != world.match_config:
		world.get_tree().set_meta("match_config",setup_options.duplicate())
		world.get_tree().set_meta("start_difficulty",difficulty)
		world.get_tree().paused = false
		world.get_tree().reload_current_scene()
		return
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
	world.edge_scroll = bool(cfg.get_value("controls", "edge_scroll", true))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", world.quality)
	cfg.set_value("graphics", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.set_value("audio", "volume", roundf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0))
	cfg.set_value("controls", "edge_scroll", world.edge_scroll)
	cfg.save(SETTINGS)

# ---------------------------------------------------------------- widgets

func _clear() -> void:
	_briefing = null
	if _transition != null:
		_transition.kill()
	_panel.modulate.a = 0.0
	_transition = create_tween()
	_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition.tween_property(_panel,"modulate:a",1.0,0.16)
	_scroll.scroll_vertical = 0
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	_fit_card.call_deferred()

## Paused, the card is cut to the height of whatever screen is in it, so no
## empty box hangs below the entries.
func _fit_card() -> void:
	if _root == null or not in_match:
		return
	var tall: float = clampf(_panel.get_combined_minimum_size().y + 104.0, 200.0, _root.size.y - 80.0)
	_card.offset_top = -tall * 0.5
	_card.offset_bottom = tall * 0.5

func _heading(text: String) -> void:
	_band.visible = text != ""
	if text != "":
		_band_title.text = UI.caps(text)

func _accent(_width: int) -> Array:
	# Quiet navigation rests on the scenery; its underline becomes a jade
	# ribbon under pointer or keyboard focus.
	var normal := UI.plate(Color(0.06, 0.13, 0.15, 0.30), Color(0.03, 0.08, 0.10, 0.08), Color.TRANSPARENT, 14.0, Color.TRANSPARENT, Color(UI.TRIM, 0.45), 1)
	var hover := UI.plate(Color("29464c"), Color("11262c"), UI.GOLD, 14.0)
	return [normal, hover]

# A quiet serif menu entry; the primary action wears the sovereign seal.
func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.custom_minimum_size = Vector2(380, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_font_override("font", UI.serif())
	var styles := _accent(4)
	b.add_theme_stylebox_override("normal", styles[0])
	b.add_theme_stylebox_override("hover", styles[1])
	b.add_theme_stylebox_override("pressed", styles[1])
	b.add_theme_color_override("font_pressed_color", UI.BRIGHT)
	b.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, UI.BRIGHT, 1, 8, 0.0))
	if text in ["New Game", "Begin campaign", "Resume"]:
		b.add_theme_stylebox_override("normal", UI.plate(Color("344c49"), Color("18312f"), UI.GOLD, 14.0))
		b.icon = UI.icon("sovereign")
		b.add_theme_constant_override("icon_max_width", 28)
	b.pressed.connect(action)
	_panel.add_child(b)
	return b

# A larger choice with a line of explanation: difficulties, saved games.
func _option_card(title: String, detail: String, action: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 72)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = detail
	var styles := _accent(4)
	b.add_theme_stylebox_override("normal", styles[0])
	b.add_theme_stylebox_override("hover", styles[1])
	b.add_theme_stylebox_override("pressed", styles[1])
	b.pressed.connect(action)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 18
	col.offset_right = -12
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "HeaderLabel"
	t.add_theme_font_size_override("font_size", 19)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var dl := Label.new()
	dl.text = detail
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", UI.MUTED)
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(dl)
	_panel.add_child(b)

func _row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(380, 40)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.focus_mode = Control.FOCUS_ALL
	row.add_child(control)
	_panel.add_child(row)

func _unhandled_input(event: InputEvent) -> void:
	if _root != null and _root.visible and in_match and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
