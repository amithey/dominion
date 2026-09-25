extends CanvasLayer
## Main menu and pause menu. An illustrated war table with drifting light
## fills the opening screen; the entries on the left each say what they do
## (Continue names the campaign it resumes), and a dispatch card on the right
## gives a tip. New Game is a campaign sheet: the four nations as portrait
## cards, rivals, island, rules and difficulty as choice cards, and a summary
## with Begin. Settings (graphics quality, full screen, master volume) persist
## in user://settings.cfg. In a match, Esc opens the pause menu: a card with
## the campaign's name, era and year over resume, save, load, settings, quit.

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
var _dispatch: PanelContainer
const Gallery := preload("res://scripts/leader_gallery.gd")
const TIPS := [
	"Right-click an unfinished building with workers selected to finish it; shift + right-click adds it to their list of jobs.",
	"Prices on the world market answer big orders over a few seconds: sell a large stock in parts.",
	"A shipyard may stand on free coast up to three hexes from your land.",
	"Bunkers take a third of the damage from ground fire and shelter troops beside them.",
	"Air defence only fires at aircraft in the air. Parked aircraft are safe from it, and exposed to everything else.",
	"Research carries on with the next project when the first one waits for a building or materials.",
	"The Diplomacy window's World map tab shows who is at war with whom.",
	"Artillery reaches three hexes: keep it behind your armour.",
]

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
	# A dispatch on the right of the opening screen: a tip for the campaign.
	_dispatch = PanelContainer.new()
	_dispatch.add_theme_stylebox_override("panel", UI.plate(Color(0.08, 0.15, 0.17, 0.9), Color(0.03, 0.07, 0.09, 0.92), UI.GOLD, 16.0))
	_dispatch.anchor_left = 1.0
	_dispatch.anchor_right = 1.0
	_dispatch.anchor_top = 1.0
	_dispatch.anchor_bottom = 1.0
	_dispatch.offset_left = -470
	_dispatch.offset_right = -56
	_dispatch.offset_top = -190
	_dispatch.offset_bottom = -56
	_root.add_child(_dispatch)
	load_settings()

## Main menu: title and card on the left. Paused: a card in the middle.
func _layout(paused: bool) -> void:
	_table.visible = not paused
	_shade.visible = not paused
	_brand.visible = not paused
	_dim.visible = paused
	_dispatch.visible = false  # open_main shows it
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
	_wide(false)
	_clear()
	_heading("")
	var invitation := _description("THE WAR COUNCIL")
	invitation.add_theme_color_override("font_color", UI.GOLD)
	_entry("New Game", "Chart a campaign: your nation, its rivals and the rules.", "sovereign", open_new_game, true)
	var newest := newest_save()
	var slots := list_saves()
	var last := "No campaign saved yet."
	if newest != "":
		last = "Resume \"%s\", saved %s." % [newest.capitalize(), slots[0].date]
	var continue_button := _entry("Continue", last, "land", func(): load_game(newest))
	continue_button.disabled = newest == ""
	_entry("Load Game", ("%d saved campaign%s." % [slots.size(), "" if slots.size() == 1 else "s"]) if not slots.is_empty() else "Nothing saved yet: F5 saves during a match.", "research", open_load)
	_entry("Settings", "Graphics, full screen, sound and scrolling.", "menu", open_settings)
	_entry("Quit", "Leave for the desktop.", "", func(): world.get_tree().quit())
	_show_dispatch()

## The tip card on the opening screen.
func _show_dispatch() -> void:
	for child in _dispatch.get_children():
		_dispatch.remove_child(child)
		child.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_dispatch.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var seal := TextureRect.new()
	seal.texture = UI.icon("diplomacy")
	seal.custom_minimum_size = Vector2(22, 22)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(seal)
	var title := Label.new()
	title.text = UI.caps("Dispatch from the front")
	title.theme_type_variation = "HeaderLabel"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UI.GOLD)
	head.add_child(title)
	var tip := Label.new()
	tip.text = TIPS[randi() % TIPS.size()]
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 380
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", UI.CREAM)
	col.add_child(tip)
	_dispatch.visible = true

func open_pause() -> void:
	in_match = true
	_show(true)
	_layout(true)
	_clear()
	_wide(false)
	_heading("PAUSED")
	_campaign_line()
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
	_wide(true)
	_dispatch.visible = false
	_heading("CHART YOUR CAMPAIGN")
	_section("Your nation")
	var nations := HBoxContainer.new()
	nations.add_theme_constant_override("separation", 10)
	_panel.add_child(nations)
	for i in range(world.MatchSetup.NATIONS.size()):
		nations.add_child(_nation_card(i))
	# Rivals and rules share a row.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 18)
	_panel.add_child(pair)
	for half in [["Rivals", [["One", "A duel.", 2], ["Two", "Room for alliances.", 3], ["Three", "The whole map.", 4]], "players"],
			["Rules", [["Standard", "Rivals send attack waves.", "standard"], ["Sandbox", "Rivals never attack.", "sandbox"]], "style"]]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 10)
		pair.add_child(box)
		_section(half[0], box)
		_choices(half[1], half[2], box)
	# The maps, smallest to largest.
	_section("Map")
	var gen: Dictionary = preload("res://scripts/map_generator.gd").MAPS
	var maps := [["Small Isle", "440 m", "small"], ["The Island", "640 m, east", "island"], ["Mirrored", "640 m, west", "mirrored"],
		["Twin Lands", "720 m", "twin"], ["Archipelago", "800 m", "archipelago"], ["Continent", "960 m", "continent"]]
	_choices(maps, "map")
	_map_note()
	_section("Difficulty")
	var levels := []
	for d in DIFFICULTIES:
		levels.append([d[1], d[2], d[0]])
	_choices(levels, "difficulty")
	# The summary and the two buttons, side by side.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	_panel.add_child(foot)
	_briefing = Label.new()
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing.add_theme_font_size_override("font_size", 14)
	_briefing.add_theme_color_override("font_color", UI.CREAM)
	foot.add_child(_briefing)
	var back := _button("Back", open_main)
	back.custom_minimum_size = Vector2(130, 54)
	_panel.remove_child(back)
	foot.add_child(back)
	var go := _button("Begin campaign", func(): start(setup_difficulty))
	go.custom_minimum_size = Vector2(280, 54)
	_panel.remove_child(go)
	foot.add_child(go)
	_update_briefing()

func _map_name(key: String) -> String:
	var gen: Dictionary = preload("res://scripts/map_generator.gd").MAPS
	return gen[key].name if gen.has(key) else ("mirrored island" if key == "mirrored" else "original island")

## The New Game sheet is wide (the four nations side by side); the others are a column.
func _wide(on: bool) -> void:
	if in_match:
		# Paused: the centred card widens for the settings, and back again.
		_card.offset_left = -470 if on else -212
		_card.offset_right = 470 if on else 212
		return
	_card.offset_right = 64 + (880 if on else 420)
	_card.offset_top = 48 if on else 230
	_brand.visible = not on  # the sheet needs the height; the title returns with the main menu

func _section(title: String, parent: Control = null) -> void:
	var l := Label.new()
	l.text = UI.caps(title)
	l.theme_type_variation = "HeaderLabel"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UI.GOLD)
	(parent if parent != null else _panel).add_child(l)

## A nation as a card: the leader's portrait, the flag colour, name and title.
func _nation_card(i: int) -> Button:
	var parts: PackedStringArray = str(world.MatchSetup.NATIONS[i]).split(" \u00b7 ")
	var colour := Color(world.map.nations[i].color) if i < world.map.nations.size() else UI.GOLD
	var chosen: bool = int(setup_options.nation) == i
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 206)
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	b.button_pressed = chosen
	b.add_theme_stylebox_override("normal", UI.box(Color(0.05, 0.1, 0.12, 0.85), colour.darkened(0.3), 1, 4, 6.0))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.08, 0.15, 0.17, 0.95), colour, 2, 4, 6.0))
	b.add_theme_stylebox_override("pressed", UI.box(Color(0.1, 0.18, 0.18, 0.95), UI.GOLD, 3, 4, 6.0))
	b.add_theme_stylebox_override("hover_pressed", UI.box(Color(0.1, 0.18, 0.18, 0.95), UI.GOLD, 3, 4, 6.0))
	b.pressed.connect(func():
		setup_options.nation = i
		open_new_game())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 6
	col.offset_right = -6
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var pic := TextureRect.new()
	var path := Gallery.portrait(parts[1] if parts.size() > 1 else "")
	if path != "":
		pic.texture = load(path)
	pic.custom_minimum_size = Vector2(0, 124)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var flag := ColorRect.new()
	flag.color = colour
	flag.custom_minimum_size = Vector2(0, 5)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(flag)
	var name := Label.new()
	name.text = parts[0]
	name.theme_type_variation = "HeaderLabel"
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", colour.lightened(0.45))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name)
	var leader := Label.new()
	leader.text = ("\u2713  " if chosen else "") + (parts[1] if parts.size() > 1 else "")
	leader.add_theme_font_size_override("font_size", 13)
	leader.add_theme_color_override("font_color", UI.GOLD if chosen else UI.MUTED)
	leader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(leader)
	return b

## A row of choice cards for one setting: [[title, line, value], ...].
func _choices(items: Array, key: String, parent: Control = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	(parent if parent != null else _panel).add_child(row)
	for item in items:
		var chosen: bool = (setup_difficulty == item[2]) if key == "difficulty" else (setup_options[key] == item[2])
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = chosen
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_stylebox_override("normal", UI.box(Color(0.05, 0.1, 0.12, 0.8), Color("2d4460"), 1, 4, 8.0))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.08, 0.15, 0.17, 0.95), Color(UI.GOLD, 0.7), 1, 4, 8.0))
		b.add_theme_stylebox_override("pressed", UI.box(Color("28443f"), UI.GOLD, 2, 4, 8.0))
		b.add_theme_stylebox_override("hover_pressed", UI.box(Color("28443f"), UI.GOLD, 2, 4, 8.0))
		var value = item[2]
		b.pressed.connect(func():
			if key == "difficulty":
				setup_difficulty = value
			else:
				setup_options[key] = value
			open_new_game())
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 12
		col.offset_right = -10
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var t := Label.new()
		t.text = ("\u2713 " if chosen else "") + str(item[0])
		t.theme_type_variation = "HeaderLabel"
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", UI.BRIGHT if chosen else UI.CREAM)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(t)
		var d := Label.new()
		d.text = item[1]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", UI.MUTED)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
		row.add_child(b)

## A line under the maps about the one chosen.
func _map_note() -> void:
	var gen: Dictionary = preload("res://scripts/map_generator.gd").MAPS
	var key := str(setup_options.map)
	var text: String = gen[key].desc if gen.has(key) else ("The original island, 640 m: rivals on every side." if key == "island" else "The original island mirrored: start in the west.")
	var l := _description(text)
	l.add_theme_color_override("font_color", UI.CREAM)

## Paused: which campaign this is, where it stands.
func _campaign_line() -> void:
	var nation := str(world.MatchSetup.NATIONS[int(world.match_config.get("nation", 0))]).split(" \u00b7 ")[0]
	var era := ""
	if world.research:
		era = "%s  \u00b7  " % world.research.eras[world.research.era].name
	var line := _description("%s  \u00b7  %s%s  \u00b7  year %d" % [nation, era, str(world.match_difficulty).capitalize(), 1 + int(world.game_time / 720.0)])
	line.add_theme_color_override("font_color", UI.GOLD)

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
	var rivals := int(setup_options.players) - 1
	_briefing.text = "%s\n%d rival%s  ·  %s  ·  %s  ·  %s" % [world.MatchSetup.NATIONS[int(setup_options.nation)], rivals, "" if rivals == 1 else "s", _map_name(str(setup_options.map)), "sandbox" if setup_options.style=="sandbox" else "standard rules", difficulty[1]]

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

var settings_tab := "graphics"

## Settings in four tabs, each setting a card with a line saying what it does.
## Every change applies at once and is saved (user://settings.cfg).
func open_settings() -> void:
	_clear()
	_wide(true)
	_dispatch.visible = false
	_heading("SETTINGS")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	_panel.add_child(tabs)
	for t in [["Graphics", "graphics"], ["Sound", "sound"], ["Controls", "controls"], ["Game", "game"]]:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_pressed = settings_tab == t[1]
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 16)
		var key: String = t[1]
		b.pressed.connect(func():
			settings_tab = key
			open_settings())
		tabs.add_child(b)
	match settings_tab:
		"sound":
			_settings_sound()
		"controls":
			_settings_controls()
		"game":
			_settings_game()
		_:
			_settings_graphics()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	_panel.add_child(foot)
	var note := _description("Changes apply at once and are saved.")
	_panel.remove_child(note)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(note)
	var solid := UI.plate(Color("29464c"), Color("11262c"), Color(UI.GOLD, 0.7), 14.0)
	var reset := _button("Defaults", func():
		_reset_settings()
		open_settings())
	reset.custom_minimum_size = Vector2(150, 50)
	reset.add_theme_stylebox_override("normal", solid)
	_panel.remove_child(reset)
	foot.add_child(reset)
	var back := _button("Back", open_pause if in_match else open_main)
	back.custom_minimum_size = Vector2(150, 50)
	back.add_theme_stylebox_override("normal", solid)
	_panel.remove_child(back)
	foot.add_child(back)

## A setting as a card: its name and what it does on the left, the control on the right.
func _setting(title: String, detail: String, control: Control) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.12, 0.85), Color("2d4460"), 1, 4, 12.0))
	_panel.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "HeaderLabel"
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", UI.CREAM)
	col.add_child(t)
	var d := Label.new()
	d.text = detail
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 380
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", UI.MUTED)
	col.add_child(d)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.focus_mode = Control.FOCUS_ALL
	row.add_child(control)

## Buttons side by side, one lit: [[label, value], ...].
func _segmented(items: Array, selected, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.toggle_mode = true
		b.button_pressed = item[1] == selected
		b.custom_minimum_size = Vector2(96, 36)
		var value = item[1]
		b.pressed.connect(func():
			on_pick.call(value)
			save_settings()
			open_settings())
		row.add_child(b)
	return row

func _switch(on: bool, on_toggle: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.text = "On" if on else "Off"
	c.toggled.connect(func(v):
		c.text = "On" if v else "Off"
		on_toggle.call(v)
		save_settings())
	return c

func _slider(value: float, low: float, high: float, step: float, shown: Callable, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var readout := Label.new()
	readout.text = shown.call(value)
	readout.custom_minimum_size.x = 56
	readout.add_theme_color_override("font_color", UI.GOLD)
	row.add_child(readout)
	s.value_changed.connect(func(v):
		readout.text = shown.call(v)
		on_change.call(v)
		save_settings())
	return row

## 100% is each bus's designed level (the effects bus keeps 4 dB of headroom, audio.gd).
func _bus_trim(bus: String) -> float:
	return -4.0 if bus == "SFX" else 0.0

func _bus_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return roundf(db_to_linear(AudioServer.get_bus_volume_db(i) - _bus_trim(bus)) * 100.0) if i >= 0 else 100.0

func _set_bus_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.1) / 100.0) + _bus_trim(bus))
		AudioServer.set_bus_mute(i, v <= 0.5)

func _settings_graphics() -> void:
	_setting("Quality", {"high": "Full effects: ambient occlusion, four shadow cascades, sharp at full resolution.", "balanced": "Lighter shadows and upscaling: smooth on most laptops.", "low": "Fewest effects, no grass: the fastest."}.get(world.quality, ""),
		_segmented([["High", "high"], ["Balanced", "balanced"], ["Low", "low"]], world.quality, func(v):
			world.quality = v
			world.apply_quality()))
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_setting("Display", "Play in a window, or across the whole screen.", _segmented([["Window", false], ["Full screen", true]], full, func(v):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)))
	_setting("Vertical sync", "Matches frames to the screen: no tearing, and less heat and noise from the laptop.", _switch(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED, func(v):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)))
	_setting("Frame limit", "The most frames a second the game draws. A limit keeps a laptop cooler.", _segmented([["30", 30], ["60", 60], ["120", 120], ["None", 0]], Engine.max_fps, func(v): Engine.max_fps = v))
	_setting("Frame counter", "Frames per second in the bottom-right corner.", _switch(world.show_fps, func(v): world.show_fps = v))

func _settings_sound() -> void:
	_setting("Master volume", "Everything the game plays.", _slider(_bus_volume("Master"), 0, 100, 1, func(v): return "%d%%" % v, func(v): _set_bus_volume("Master", v)))
	_setting("Battle and world sounds", "Guns, engines, explosions, wind and surf.", _slider(_bus_volume("SFX"), 0, 100, 1, func(v): return "%d%%" % v, func(v): _set_bus_volume("SFX", v)))

func _settings_controls() -> void:
	_setting("Scroll at the screen edge", "Move the camera by touching the edge of the screen with the mouse.", _switch(world.edge_scroll, func(v): world.edge_scroll = v))
	_setting("Camera speed", "How fast the camera pans with the keys and the screen edge.", _slider(world.pan_speed * 100.0, 40, 200, 10, func(v): return "%d%%" % v, func(v): world.pan_speed = v / 100.0))
	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 24)
	keys.add_theme_constant_override("v_separation", 3)
	for pair in [["W A S D / arrows", "Move the camera (Shift: faster)"], ["Wheel", "Zoom"], ["Middle button + drag", "Turn and tilt the view"], ["Shift + middle drag", "Drag the map"],
			["Right click", "Move, attack; on a site with workers: build"], ["Shift + right click", "Add a site to the workers' list"], ["Ctrl + right click", "Attack-move"], ["Alt + right click", "Bombard an area"],
			["B", "Build list"], ["G  M  I  T  Y", "Diplomacy, market, intelligence, territory, research"], ["O", "Mark an operational zone"], ["F5 / F9", "Quick save / load"], ["Esc", "Pause menu"]]:
		var k := Label.new()
		k.text = pair[0]
		k.add_theme_color_override("font_color", UI.GOLD)
		k.add_theme_font_size_override("font_size", 13)
		keys.add_child(k)
		var d := Label.new()
		d.text = pair[1]
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", UI.CREAM)
		keys.add_child(d)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.12, 0.85), Color("2d4460"), 1, 4, 12.0))
	var col := VBoxContainer.new()
	card.add_child(col)
	var t := Label.new()
	t.text = "Keys and mouse"
	t.theme_type_variation = "HeaderLabel"
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", UI.CREAM)
	col.add_child(t)
	col.add_child(keys)
	_panel.add_child(card)

func _settings_game() -> void:
	var every: float = world.saves.autosave_every if world.saves else 180.0
	_setting("Autosave", "Saves the match as \"Autosave\" at this interval, so a crash or a mistake costs little.", _segmented([["1 min", 60.0], ["3 min", 180.0], ["5 min", 300.0], ["Off", 0.0]], every, func(v):
		if world.saves: world.saves.autosave_every = v))

func _reset_settings() -> void:
	world.quality = "balanced"
	world.apply_quality()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	world.show_fps = true
	_set_bus_volume("Master", 100.0)
	_set_bus_volume("SFX", 100.0)
	world.edge_scroll = true
	world.pan_speed = 1.0
	if world.saves:
		world.saves.autosave_every = 180.0
	save_settings()

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
	_set_bus_volume("SFX", float(cfg.get_value("audio", "effects", 100.0)))
	world.edge_scroll = bool(cfg.get_value("controls", "edge_scroll", true))
	world.pan_speed = float(cfg.get_value("controls", "pan_speed", 1.0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(cfg.get_value("graphics", "vsync", true)) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(cfg.get_value("graphics", "max_fps", 0))
	world.show_fps = bool(cfg.get_value("graphics", "show_fps", true))
	if world.saves:
		world.saves.autosave_every = float(cfg.get_value("game", "autosave", 180.0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", world.quality)
	cfg.set_value("graphics", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.set_value("audio", "volume", roundf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0))
	cfg.set_value("controls", "edge_scroll", world.edge_scroll)
	cfg.set_value("controls", "pan_speed", world.pan_speed)
	cfg.set_value("audio", "effects", _bus_volume("SFX"))
	cfg.set_value("graphics", "vsync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	cfg.set_value("graphics", "max_fps", Engine.max_fps)
	cfg.set_value("graphics", "show_fps", world.show_fps)
	if world.saves:
		cfg.set_value("game", "autosave", world.saves.autosave_every)
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

## A main-menu entry: an icon, the name, and a line saying what it does.
func _entry(text: String, detail: String, icon_name: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 66)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = detail
	var styles := _accent(4)
	b.add_theme_stylebox_override("normal", UI.plate(Color("344c49"), Color("18312f"), UI.GOLD, 14.0) if primary else styles[0])
	b.add_theme_stylebox_override("hover", styles[1])
	b.add_theme_stylebox_override("pressed", styles[1])
	b.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, UI.BRIGHT, 1, 8, 0.0))
	b.pressed.connect(action)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -12
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := TextureRect.new()
	pic.texture = UI.icon(icon_name) if icon_name != "" else null
	pic.custom_minimum_size = Vector2(30, 30)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := Label.new()
	t.text = text
	t.add_theme_font_override("font", UI.serif())
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color("f1e3b4"))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var d := Label.new()
	d.text = detail
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d.clip_text = true
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", UI.MUTED)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(d)
	b.focus_entered.connect(func(): t.add_theme_color_override("font_color", UI.BRIGHT))
	b.focus_exited.connect(func(): t.add_theme_color_override("font_color", Color("f1e3b4")))
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
