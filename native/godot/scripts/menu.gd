extends CanvasLayer
## Main menu and pause menu. An illustrated war table with drifting light
## fills the opening screen; the entries on the left each say what they do
## (Continue names the campaign it resumes), and a dispatch card on the right
## gives a tip. New Game is a two-column campaign sheet: nine national leaders,
## a terrain preview, opponents and rules, with a persistent Begin footer.
## Settings (graphics quality, full screen, master volume) persist
## in user://settings.cfg. In a match, Esc opens the pause menu: a card with
## the campaign's name, era and year over resume, save, load, settings, quit.

const SETTINGS := "user://settings.cfg"
const GOLD := Color("c1af86")   ## atlas sand accent
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
var setup_options := {"map":"island","players":4,"nation":0,"style":"standard","fog":true}
var setup_difficulty := "easy"
var _briefing: Label
var _transition: Tween
var _scroll: ScrollContainer
var _dispatch: PanelContainer
var _footer: MarginContainer
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
	setup_options.opening = "light"   # every campaign from the menu opens the same way for every nation
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
	fade.set_color(0, Color(0.018, 0.035, 0.065, 0.94))
	fade.add_point(0.62, Color(0.018, 0.035, 0.065, 0.60))
	fade.set_color(fade.get_point_count() - 1, Color(0.03, 0.06, 0.08, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.width = 256
	tex.height = 4
	_shade = TextureRect.new()
	_shade.texture = tex
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.anchor_bottom = 1.0
	_shade.anchor_right = 1.0
	_root.add_child(_shade)
	var atlas := preload("res://scripts/atlas_ornament.gd").new()
	_shade.add_child(atlas)
	atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Pause menu: the whole game dims behind a card.
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.05, 0.62)
	_root.add_child(_dim)
	_brand = VBoxContainer.new()
	_brand.offset_left = 64
	_brand.offset_top = 82
	_brand.add_theme_constant_override("separation", 16)
	_root.add_child(_brand)
	var crest := HBoxContainer.new()
	crest.add_theme_constant_override("separation", 18)
	_brand.add_child(crest)
	var emblem := TextureRect.new()
	emblem.texture = UI.icon("territory")
	emblem.modulate = UI.GOLD
	emblem.custom_minimum_size = Vector2(70, 70)
	emblem.visible = emblem.texture != null   # no empty gap before the title when the emblem is missing
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.add_child(emblem)
	_title = Label.new()
	_title.text = "DOMINION"
	_title.theme_type_variation = "HeaderLabel"
	_title.add_theme_font_size_override("font_size", 66)
	_title.add_theme_color_override("font_color", Color("f1e3b4"))
	_title.add_theme_constant_override("outline_size", 2)
	crest.add_child(_title)
	_subtitle = Label.new()
	_subtitle.text = UI.caps("A world to shape. A nation to lead.")
	_subtitle.add_theme_color_override("font_color", UI.GOLD)
	_subtitle.add_theme_font_size_override("font_size", 14)
	_brand.add_child(_subtitle)
	var rule := ColorRect.new()
	rule.color = Color(UI.GOLD, 0.6)
	rule.custom_minimum_size = Vector2(420, 1)
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
	_band.add_theme_stylebox_override("panel", UI.band(18.0))
	_band.visible = false
	frame.add_child(_band)
	_band_title = Label.new()
	_band_title.theme_type_variation = "HeaderLabel"
	_band_title.add_theme_font_size_override("font_size", 22)
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
	_footer = MarginContainer.new()
	_footer.name = "CampaignFooter"
	for side in ["left", "right", "top", "bottom"]:
		_footer.add_theme_constant_override("margin_" + side, 18)
	frame.add_child(_footer)
	_footer.hide()
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
	_dispatch.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.94), Color(UI.PANEL_LOW, 0.96), UI.GOLD, 16.0))
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
		_card.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.98), Color(UI.PANEL_LOW, 0.98), UI.GOLD, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 10))
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
	var invitation := _description(UI.caps("The war council"))
	invitation.add_theme_color_override("font_color", UI.GOLD)
	_entry("New Game", "Chart a campaign: your nation, its rivals and the rules.", "sovereign", open_new_game, true)
	var newest := newest_save()
	var slots := list_saves()
	var last := "No campaign saved yet."
	if newest != "":
		last = ("%s, saved %s." % [slots[0].about, slots[0].date]) if str(slots[0].about) != "" else ("Resume \"%s\", saved %s." % [newest.capitalize(), slots[0].date])
	var continue_button := _entry("Continue", last, "land", func(): load_game(newest))
	continue_button.disabled = newest == ""
	_entry("Load Game", ("%d saved campaign%s." % [slots.size(), "" if slots.size() == 1 else "s"]) if not slots.is_empty() else "Nothing saved yet: F5 saves during a match.", "research", open_load)
	_entry("Settings", "Graphics, full screen, sound and scrolling.", "menu", open_settings)
	_entry("Quit", "Leave for the desktop.", "quit", func(): world.get_tree().quit())
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
	var save_button := _button("Save Game", save_campaign)
	save_button.tooltip_text = "Create a separate campaign save. F5 replaces QuickSave."
	_button("Load Game", open_load)
	_button("Settings", open_settings)
	if preload("res://scripts/cheats.gd").allowed():
		var cheat := _button("Testing: everything (F10)", func():
			world.hud.notice(preload("res://scripts/cheats.gd").everything(world))
			close())
		cheat.name = "CheatEverything"
		cheat.tooltip_text = "For testing the game: every era and all your nation's research, $1,000,000 more and every store filled."
	var to_menu := _button("Quit to Main Menu", func(): pass)
	to_menu.pressed.connect(func():
		if not _confirmed(to_menu, "Quit to Main Menu"): return
		world.get_tree().paused = false
		world.get_tree().reload_current_scene())
	var to_desktop := _button("Quit to Desktop", func(): pass)
	to_desktop.pressed.connect(func():
		if not _confirmed(to_desktop, "Quit to Desktop"): return
		world.get_tree().quit())

## A second press within four seconds confirms leaving a campaign (it used to
## leave at once, with no word about what had not been saved).
func _confirmed(b: Button, label: String) -> bool:
	if b.has_meta("armed") and Time.get_ticks_msec() - int(b.get_meta("armed")) < 4000:
		return true
	b.set_meta("armed", Time.get_ticks_msec())
	b.text = "  Click again: unsaved progress is lost"
	get_tree().create_timer(4.0, true).timeout.connect(func():
		if is_instance_valid(b): b.text = "  " + label)
	return false

func save_campaign() -> void:
	var base := "Campaign " + Time.get_datetime_string_from_system().replace("T", " ").replace(":", "-")
	var slot := base
	var suffix := 2
	while FileAccess.file_exists(world.saves.path_of(slot)):
		slot = "%s (%d)" % [base, suffix]
		suffix += 1
	if world.saves.save(slot):
		close()
	else:
		_description("Save failed. Your game is still open. Check available disk space and try again.")

func open_new_game() -> void:
	_clear()
	_wide(true)
	_dispatch.visible = false
	_heading("Chart your campaign")
	var columns := HBoxContainer.new()
	columns.name = "CampaignColumns"
	columns.add_theme_constant_override("separation", 24)
	_panel.add_child(columns)
	var nation := VBoxContainer.new()
	nation.custom_minimum_size.x = 304
	nation.add_theme_constant_override("separation", 12)
	columns.add_child(nation)
	_section("01  /  Lead a nation", nation)
	var factions = preload("res://scripts/factions.gd")
	var selector := OptionButton.new()
	selector.name = "FactionPicker"
	selector.custom_minimum_size.y = 42
	for title in factions.NAMES:
		selector.add_item(title)
	selector.select(int(setup_options.nation))
	selector.item_selected.connect(func(index):
		setup_options.nation = index
		open_new_game())
	nation.add_child(selector)
	nation.add_child(_nation_card(int(setup_options.nation)))
	var national := Label.new()
	var arsenal: String = factions.ARSENALS[int(setup_options.nation)]
	var power: Dictionary = preload("res://scripts/faction_powers.gd").POWERS.get(arsenal, preload("res://scripts/additional_powers.gd").POWERS.get(arsenal, {}))
	national.text = "%s\n%s" % [factions.SIGNATURES[int(setup_options.nation)], power.name]
	national.tooltip_text = "Signature weapon & national power\n" + str(power.desc)
	national.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	national.add_theme_font_size_override("font_size", 15)
	national.add_theme_color_override("font_color", UI.GOLD)
	nation.add_child(national)
	var doctrine := Label.new()
	doctrine.text = factions.DOCTRINES[int(setup_options.nation)]
	doctrine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doctrine.add_theme_font_size_override("font_size", 14)
	doctrine.add_theme_color_override("font_color", UI.TEXT)
	nation.add_child(doctrine)
	preload("res://scripts/nation_profile_view.gd").append_to(nation, factions.IDS[int(setup_options.nation)])
	var rule := VSeparator.new()
	columns.add_child(rule)
	var campaign := VBoxContainer.new()
	campaign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign.add_theme_constant_override("separation", 12)
	columns.add_child(campaign)
	_section("02  /  Choose your world", campaign)
	_map_picker(campaign)
	_section("03  /  Set the balance of power", campaign)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	campaign.add_child(options)
	# As many rivals as the map has regions (and factions to lead them).
	var counts := []
	for players in range(2, world.MatchSetup.capacity(str(setup_options.map)) + 1):
		counts.append(["One rival" if players == 2 else "%d rivals" % (players - 1), players])
	_setup_select("Rivals", counts, "players", options)
	_setup_select("Rules", [["Standard", "standard"], ["Sandbox", "sandbox"]], "style", options)
	_setup_select("Fog of war", [["On", true], ["Off", false]], "fog", options)
	_setup_select("Difficulty", [["Easy", "easy"], ["Normal", "normal"], ["Hard", "hard"]], "difficulty", options)
	_setup_select("Pace", [["Slow · 60%", 0.6], ["Relaxed · 75%", 0.75], ["Standard · 100%", 1.0]], "pace", options)
	_rival_pickers(campaign)
	var explanation := Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 13)
	explanation.add_theme_color_override("font_color", UI.MUTED)
	explanation.text = ("Sandbox: rivals develop their nations without sending attack waves." if setup_options.style == "sandbox" else DIFFICULTIES[["easy", "normal", "hard"].find(setup_difficulty)][2])
	campaign.add_child(explanation)
	# Always visible, independently of the campaign sheet's scrolling body.
	_footer.show()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	_footer.add_child(foot)
	_briefing = Label.new()
	_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing.add_theme_font_size_override("font_size", 13)
	_briefing.add_theme_color_override("font_color", UI.MUTED)
	foot.add_child(_briefing)
	var back := _button("Back", open_main)
	back.custom_minimum_size = Vector2(110, 50)
	_panel.remove_child(back)
	foot.add_child(back)
	var go := _button("Begin campaign", func(): start(setup_difficulty))
	go.name = "BeginCampaign"
	go.add_theme_stylebox_override("normal", UI.box(Color("2c6a50"), UI.GOLD, 1, 6, 9.0))
	go.add_theme_stylebox_override("hover", UI.box(Color("39866a"), UI.BRIGHT, 1, 6, 9.0))
	go.add_theme_color_override("font_color", UI.BRIGHT)
	go.custom_minimum_size = Vector2(250, 50)
	_panel.remove_child(go)
	foot.add_child(go)
	_update_briefing()
	_fit_wide.call_deferred()

## The wide campaign sheet is cut to its contents, centred, so no empty box hangs below it.
func _fit_wide() -> void:
	await world.get_tree().process_frame
	if _root == null or in_match or _card.anchor_right != 1.0 or _panel.get_child_count() == 0:
		return
	var tall: float = _panel.get_combined_minimum_size().y + _footer.get_combined_minimum_size().y + 110.0
	tall = clampf(tall, 440.0, _root.size.y - 64.0)
	var margin: float = (_root.size.y - tall) * 0.5
	_card.offset_top = margin
	_card.offset_bottom = -margin

func _setup_select(title: String, items: Array, key: String, parent: Control) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	_section(title, col)
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 40
	for item in items:
		picker.add_item(item[0])
		if item[1] == (setup_difficulty if key == "difficulty" else setup_options.get(key, 0.75 if key == "pace" else null)):
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index):
		if key == "difficulty":
			setup_difficulty = items[index][1]
			setup_options.erase("levels")   # every rival follows the new difficulty
		else:
			setup_options[key] = items[index][1]
		open_new_game())
	col.add_child(picker)

## Each rival: which nation, and how hard it plays (the Difficulty above sets
## them all at once).
func _rival_pickers(parent: Control = null) -> void:
	_section("Nations: where each starts, which nation, how hard it plays", parent)
	var factions = preload("res://scripts/factions.gd")
	var chosen: Array = world.MatchSetup.roster(setup_options)
	var you := HBoxContainer.new()
	you.add_theme_constant_override("separation", 6)
	(parent if parent != null else _panel).add_child(you)
	you.add_child(_start_picker(0))
	var you_label := Label.new()
	you_label.text = "You: %s" % factions.NAMES[chosen[0]]
	you_label.add_theme_font_size_override("font_size", 14)
	you_label.add_theme_color_override("font_color", UI.GOLD)
	you.add_child(you_label)
	var grid := GridContainer.new()
	grid.name = "RivalGrid"
	grid.columns = 1 if chosen.size() <= 4 else 2   # up to three rivals in one tidy column (an odd one out sat alone)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	(parent if parent != null else _panel).add_child(grid)
	for slot in range(1, chosen.size()):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		grid.add_child(row)
		row.add_child(_start_picker(slot))
		var picker := OptionButton.new()
		picker.name = "RivalPicker%d" % slot
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.custom_minimum_size.y = 40
		picker.fit_to_longest_item = false
		picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for i in range(factions.IDS.size()):
			if i in chosen and i != chosen[slot]:
				continue
			picker.add_item(factions.NAMES[i], i)
			if i == chosen[slot]:
				picker.select(picker.item_count - 1)
		picker.item_selected.connect(func(index):
			var rivals: Array = chosen.slice(1)
			rivals[slot - 1] = picker.get_item_id(index)
			setup_options.rivals = rivals
			open_new_game())
		row.add_child(picker)
		var level := OptionButton.new()
		level.name = "RivalLevel%d" % slot
		level.custom_minimum_size = Vector2(112, 40)
		level.tooltip_text = "How hard %s plays: its income, how fast it builds and trains, the size of its army and waves, and how readily it goes to war." % factions.NAMES[chosen[slot]]
		var current: String = world.MatchSetup.level_of(setup_options, slot, setup_difficulty)
		for item in [["Easy", "easy"], ["Normal", "normal"], ["Hard", "hard"]]:
			level.add_item(item[0])
			if item[1] == current:
				level.select(level.item_count - 1)
		level.item_selected.connect(func(index):
			var levels: Array = setup_options.get("levels", []).duplicate()
			while levels.size() < chosen.size() - 1:
				levels.append("")
			levels[slot - 1] = ["easy", "normal", "hard"][index]
			setup_options.levels = levels
			_update_briefing())
		row.add_child(level)

## The regions' numbers on the map preview, each beside its dot; a region a
## nation chose takes that nation's colour.
func _region_marks(preview: TextureRect, key: String) -> void:
	for child in preview.get_children():
		child.queue_free()
	var roster: Array = world.MatchSetup.roster(setup_options)
	var picks: Array = world.MatchSetup.starts_of(setup_options)
	var regions: Array = world.MatchSetup.start_slots(key)
	for k in range(regions.size()):
		var p: Vector2 = regions[k].at
		var mark := Label.new()
		mark.name = "Region%d" % (k + 1)
		mark.text = str(k + 1)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_font_size_override("font_size", 16 if picks.has(k) else 13)
		mark.add_theme_constant_override("outline_size", 4)
		mark.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		var who := picks.find(k)
		var colours: Array = world.MatchSetup.COLOURS
		mark.add_theme_color_override("font_color", Color(colours[roster[who]]) if who >= 0 and who < roster.size() and roster[who] < colours.size() else UI.CREAM)
		mark.anchor_left = (p.x + 1.0) * 0.5
		mark.anchor_right = mark.anchor_left
		mark.anchor_top = (p.y + 1.0) * 0.5
		mark.anchor_bottom = mark.anchor_top
		mark.offset_left = 4
		mark.offset_top = -19
		mark.offset_right = 24
		mark.offset_bottom = -1
		preview.add_child(mark)

## Where nation `slot` of the roster (0: you) starts: Auto, or a region of the
## map, numbered as on the preview. A region another nation holds is swapped.
func _start_picker(slot: int) -> OptionButton:
	var key := str(setup_options.map)
	var regions: Array = world.MatchSetup.start_slots(key)
	var picks: Array = world.MatchSetup.starts_of(setup_options)
	var fixed: bool = not preload("res://scripts/map_generator.gd").is_generated(key)
	var picker := OptionButton.new()
	picker.name = "StartPicker%d" % slot
	picker.custom_minimum_size = Vector2(176, 40)
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if fixed and slot == 0:
		picker.add_item("1 · %s (your town)" % regions[0].name, 1)
		picker.disabled = true
		picker.tooltip_text = "On the original islands you always start in your prepared town."
		return picker
	picker.tooltip_text = "Where this nation starts: a region of the map, numbered as on the map above, or Auto (the map's own choice: on the real-world maps, a nation's own capital)."
	picker.add_item("Auto", 0)
	for k in range(regions.size()):
		if fixed and k == 0:
			continue
		picker.add_item("%d · %s" % [k + 1, regions[k].name], k + 1)
		if picks[slot] == k:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index):
		var k: int = picker.get_item_id(index) - 1
		var now: Array = world.MatchSetup.starts_of(setup_options)
		var other := now.find(k) if k >= 0 else -1
		if other >= 0 and other != slot:
			now[other] = now[slot]
		now[slot] = k
		setup_options.starts = now
		open_new_game())
	return picker

func _map_name(key: String) -> String:
	var gen: Dictionary = preload("res://scripts/map_generator.gd").MAPS
	return gen[key].name if gen.has(key) else ("mirrored island" if key == "mirrored" else "original island")

## Campaign setup and settings use a wide sheet; navigation remains a column.
func _wide(on: bool) -> void:
	if in_match:
		_card.offset_left = -470 if on else -212
		_card.offset_right = 470 if on else 212
		return
	_card.anchor_right = 1.0 if on else 0.0
	_card.offset_left = 40 if on else 64
	_card.offset_right = -40 if on else 484
	_card.offset_top = 32 if on else 250
	_card.offset_bottom = -48 if on else -64
	_brand.visible = not on
	_card.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.98), Color(UI.PANEL_LOW, 0.98), Color(UI.TRIM, 0.7), 0.0, UI.LIFT, Color.TRANSPARENT, 0, 8) if on else StyleBoxEmpty.new())
	for side in ["left", "right", "top", "bottom"]:
		_margins.add_theme_constant_override("margin_" + side, 20 if on else 0)

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
	var colour := Color(world.MatchSetup.COLOURS[i]) if i < world.MatchSetup.COLOURS.size() else UI.GOLD
	var chosen: bool = int(setup_options.nation) == i
	var b := Button.new()
	b.custom_minimum_size = Vector2(304, 260)
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	b.button_pressed = chosen
	b.add_theme_stylebox_override("normal", UI.box(Color(0.05, 0.1, 0.12, 0.85), colour.darkened(0.3), 1, 4, 6.0))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.08, 0.15, 0.17, 0.95), colour, 2, 4, 6.0))
	b.add_theme_stylebox_override("pressed", UI.box(UI.KEY_LOW, UI.GOLD, 1, 3, 6.0))
	b.add_theme_stylebox_override("hover_pressed", UI.box(UI.KEY_LOW, UI.GOLD, 1, 3, 6.0))
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
	pic.texture = Gallery.face(parts[1] if parts.size() > 1 else "", 292.0 / 160.0)
	pic.custom_minimum_size = Vector2(0, 160)
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
	leader.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

## Terrain previews are baked from the same seed as each campaign, so opening
## the picker never generates a large world or stalls the menu.
func _map_picker(parent: Control = null) -> void:
	var catalogue = preload("res://scripts/map_catalogue.gd")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	(parent if parent != null else _panel).add_child(row)
	var preview := TextureRect.new()
	preview.name = "MapPreview"
	preview.custom_minimum_size = Vector2(240, 240)
	preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # square: the region numbers sit on their dots
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(preview)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	row.add_child(detail)
	var picker := OptionButton.new()
	picker.name = "MapPicker"
	picker.custom_minimum_size.y = 42
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in catalogue.KEYS:
		var info: Dictionary = catalogue.entry(key)
		picker.add_item("%s  /  %d m  /  %d regions" % [info.name, info.size, info.slots])
		picker.set_item_metadata(picker.item_count - 1, key)
	picker.select(maxi(0, catalogue.KEYS.find(str(setup_options.map))))
	detail.add_child(picker)
	var note := Label.new()
	note.name = "MapDescription"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UI.CREAM)
	detail.add_child(note)
	var legend := Label.new()
	legend.text = "Gold dots: prepared capital regions, numbered as in Start below (coloured: a nation chose it). North is up."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", UI.MUTED)
	detail.add_child(legend)
	var update := func(index: int):
		var key := str(picker.get_item_metadata(index))
		setup_options.map = key
		var info: Dictionary = catalogue.entry(key)
		preview.texture = load(catalogue.preview_path(key))
		preview.tooltip_text = "%s: %d x %d m" % [info.name, info.size, info.size]
		_region_marks(preview, key)
		note.text = "%s\n%d regions: room for up to %d nations; %d in this campaign." % [info.desc, info.slots, world.MatchSetup.capacity(key), int(setup_options.players)]
		_update_briefing()
	picker.item_selected.connect(func(index):
		update.call(index)
		setup_options.erase("starts")   # another map, other regions
		# A smaller map has room for fewer rivals; a larger one offers more.
		setup_options.players = mini(int(setup_options.players), world.MatchSetup.capacity(str(setup_options.map)))
		open_new_game())
	update.call(picker.selected)

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
	# Rivals of mixed difficulty: how many play each.
	var mix := {}
	for slot in range(1, rivals + 1):
		var level: String = world.MatchSetup.level_of(setup_options, slot, setup_difficulty)
		mix[level] = int(mix.get(level, 0)) + 1
	var hardness: String = difficulty[1]
	if mix.size() > 1:
		hardness = "  ".join(["easy", "normal", "hard"].filter(func(l): return mix.has(l)).map(func(l): return "%d %s" % [mix[l], l]))
	_briefing.text = "%s\n%d rival%s  ·  %s  ·  %s  ·  %s" % [world.MatchSetup.NATIONS[int(setup_options.nation)], rivals, "" if rivals == 1 else "s", _map_name(str(setup_options.map)), "sandbox" if setup_options.style=="sandbox" else "standard rules", "%s · %d%% pace" % [hardness, roundi(float(setup_options.get("pace", 0.75)) * 100.0)]]

func open_load() -> void:
	_clear()
	_heading("LOAD GAME")
	var slots := list_saves()
	if slots.is_empty():
		var none := Label.new()
		none.text = "No saved games yet. F5 saves during a match."
		_panel.add_child(none)
	for s in slots:
		_option_card(s.name.capitalize(), ("%s  ·  saved %s" % [s.about, s.date]) if str(s.about) != "" else "Saved %s" % s.date, func(): load_game(s.name))
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
	_footer.show()
	_footer.add_child(foot)
	var note := _description("Changes apply at once and are saved.")
	_panel.remove_child(note)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(note)
	var solid := UI.plate(UI.KEY_TOP, UI.KEY_LOW, Color(UI.GOLD, 0.7), 14.0)
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
	card.add_theme_stylebox_override("panel", UI.box(UI.BG, Color("304254"), 1, 3, 14.0))
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
	var full := is_fullscreen()
	_setting("Display", "Fill the whole screen without borders. F11 switches between full screen and a window.", _segmented([["Window", false], ["Full screen", true]], full, set_fullscreen))
	_setting("Vertical sync", "Matches frames to the screen: no tearing, and less heat and noise from the laptop.", _switch(DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED, func(v):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)))
	_setting("Frame limit", "The most frames a second the game draws. A limit keeps a laptop cooler.", _segmented([["30", 30], ["60", 60], ["120", 120], ["None", 0]], Engine.max_fps, func(v): Engine.max_fps = v))
	_setting("Frame counter", "Frames per second in the bottom-right corner.", _switch(world.show_fps, func(v): world.show_fps = v))
	_setting("Interface size", "The size of the panels and text: smaller leaves more of the battlefield in view.", _segmented([["Small", 0.7], ["Medium", 0.8], ["Large", 0.9], ["Original", 1.0]], world.ui_scale, func(v):
		world.ui_scale = v
		world.apply_ui_scale()))

func _settings_sound() -> void:
	_setting("Master volume", "Everything the game plays.", _slider(_bus_volume("Master"), 0, 100, 1, func(v): return "%d%%" % v, func(v): _set_bus_volume("Master", v)))
	_setting("Battle and world sounds", "Guns, engines, explosions, wind and surf.", _slider(_bus_volume("SFX"), 0, 100, 1, func(v): return "%d%%" % v, func(v): _set_bus_volume("SFX", v)))
	_setting("Music", "The theme that plays under the campaign and the menus.", _slider(_bus_volume("Music"), 0, 100, 1, func(v): return "%d%%" % v, func(v): _set_bus_volume("Music", v)))
	_setting("Interface clicks", "A soft click when you press a button.", _slider(_bus_volume("Interface"), 0, 100, 1, func(v): return "%d%%" % v, func(v): _set_bus_volume("Interface", v)))

func _settings_controls() -> void:
	_setting("Scroll at the screen edge", "Move the camera by touching the edge of the screen with the mouse.", _switch(world.edge_scroll, func(v): world.edge_scroll = v))
	_setting("Camera speed", "How fast the camera pans with the keys and the screen edge.", _slider(world.pan_speed * 100.0, 40, 200, 10, func(v): return "%d%%" % v, func(v): world.pan_speed = v / 100.0))
	var keys := GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 24)
	keys.add_theme_constant_override("v_separation", 3)
	for pair in [["Left click / drag", "Select one unit / select a group"], ["Shift + left click", "Add or remove a unit from the selection"], ["W A S D / arrows", "Move the camera (Shift: faster)"], ["Wheel", "Zoom"], ["Middle button + drag", "Turn and tilt the view"], ["Shift + middle drag", "Drag the map"],
			["Right click", "Move, attack; on a site with workers: build"], ["Shift + right click", "Add a site to the workers' list"], ["Ctrl + right click", "Attack-move"], ["Alt + right click", "Bombard an area"],
			["B", "Build list"], ["G  M  I  T  Y", "Diplomacy, market, intelligence, territory, research"], ["Tab / K / U / L", "Cabinet / defence / United Nations / message log"], ["Space / + / -", "Pause or resume / faster / slower"], ["Home", "Return to your capital"], ["O", "Mark an operational zone"], ["F5 / F9", "Quick save / load"], ["F11", "Full screen / window"], ["Esc", "Cancel, close a window, then pause"]]:
		var k := Label.new()
		k.text = pair[0]
		k.add_theme_color_override("font_color", UI.GOLD)
		k.add_theme_font_size_override("font_size", 15)
		keys.add_child(k)
		var d := Label.new()
		d.text = pair[1]
		d.add_theme_font_size_override("font_size", 15)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 360
		d.add_theme_color_override("font_color", UI.CREAM)
		keys.add_child(d)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(UI.BG, Color("304254"), 1, 3, 14.0))
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
	var guide := Button.new()
	guide.name = "ReplayGuide"
	guide.text = "Show first steps"
	guide.disabled = not in_match
	guide.tooltip_text = "Start a campaign to open the guide." if not in_match else "Reopen the guided introduction without resetting your campaign."
	guide.pressed.connect(func():
		close()
		world.hud.start_guide(true))
	_setting("Beginner guide", "Walk through construction, housing, research, diplomacy and game speed again.", guide)

func _reset_settings() -> void:
	world.quality = "balanced"
	world.apply_quality()
	set_fullscreen(true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	world.show_fps = false
	_set_bus_volume("Master", 100.0)
	_set_bus_volume("SFX", 100.0)
	_set_bus_volume("Music", 100.0)
	_set_bus_volume("Interface", 100.0)
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
			out.append({"name": name, "time": modified, "date": when(modified), "about": _about("user://saves/" + file)})
	out.sort_custom(func(a, b): return a.time > b.time)
	return out

## A save's time in words: "today at 17:48", "yesterday at 09:10", "3 days ago", "6 October".
static func when(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var then := Time.get_datetime_dict_from_unix_time(unix + bias)
	var now_unix := int(Time.get_unix_time_from_system())
	var now := Time.get_datetime_dict_from_unix_time(now_unix + bias)
	var day := func(d: Dictionary) -> int: return int(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day})) / 86400
	var days: int = day.call(now) - day.call(then)
	var clock := "%02d:%02d" % [int(then.hour), int(then.minute)]
	if days <= 0: return "today at " + clock
	if days == 1: return "yesterday at " + clock
	if days < 7: return "%d days ago" % days
	return "%d %s" % [int(then.day), ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][int(then.month) - 1]]

## Whose campaign a save holds: "United States · Industrial Era · year 3 · Easy".
static func _about(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > 8_000_000:
		return ""
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or not data.has("summary"):
		return ""
	var s: Dictionary = data.summary
	var parts := PackedStringArray()
	for k in ["nation", "era"]:
		if str(s.get(k, "")) != "": parts.append(str(s[k]))
	parts.append("year %d" % int(s.get("year", 1)))
	if str(s.get("difficulty", "")) != "": parts.append(str(s.difficulty))
	return "  ·  ".join(parts)

func newest_save() -> String:
	var slots := list_saves()
	return slots[0].name if not slots.is_empty() else ""

# ---------------------------------------------------------------- settings file

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		world.apply_ui_scale()
		return
	world.ui_scale = float(cfg.get_value("graphics", "ui_scale", world.ui_scale))
	world.apply_ui_scale()
	var q: String = cfg.get_value("graphics", "quality", world.quality)
	if q != world.quality:
		world.quality = q
		world.apply_quality()
	set_fullscreen(bool(cfg.get_value("graphics", "fullscreen", true)))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(cfg.get_value("audio", "volume", 100.0)), 0.1) / 100.0))
	_set_bus_volume("SFX", float(cfg.get_value("audio", "effects", 100.0)))
	_set_bus_volume("Music", float(cfg.get_value("audio", "music", 100.0)))
	_set_bus_volume("Interface", float(cfg.get_value("audio", "clicks", 100.0)))
	world.edge_scroll = bool(cfg.get_value("controls", "edge_scroll", true))
	world.pan_speed = float(cfg.get_value("controls", "pan_speed", 1.0))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(cfg.get_value("graphics", "vsync", true)) else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(cfg.get_value("graphics", "max_fps", 0))
	# The counter used to be on for everyone; settings saved before then turn it off once.
	world.show_fps = bool(cfg.get_value("graphics", "show_fps", false)) if cfg.has_section_key("graphics", "fps_choice") else false
	if world.saves:
		world.saves.autosave_every = float(cfg.get_value("game", "autosave", 180.0))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", world.quality)
	cfg.set_value("graphics", "fullscreen", is_fullscreen())
	cfg.set_value("audio", "volume", roundf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0))
	cfg.set_value("controls", "edge_scroll", world.edge_scroll)
	cfg.set_value("controls", "pan_speed", world.pan_speed)
	cfg.set_value("audio", "effects", _bus_volume("SFX"))
	cfg.set_value("audio", "music", _bus_volume("Music"))
	cfg.set_value("audio", "clicks", _bus_volume("Interface"))
	cfg.set_value("graphics", "vsync", DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
	cfg.set_value("graphics", "max_fps", Engine.max_fps)
	cfg.set_value("graphics", "show_fps", world.show_fps)
	cfg.set_value("graphics", "fps_choice", true)
	cfg.set_value("graphics", "ui_scale", world.ui_scale)
	if world.saves:
		cfg.set_value("game", "autosave", world.saves.autosave_every)
	cfg.save(SETTINGS)

# ---------------------------------------------------------------- widgets

func _clear() -> void:
	_briefing = null
	_footer.hide()
	for child in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
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
	var tall: float = clampf(_panel.get_combined_minimum_size().y + 104.0 + (_footer.get_combined_minimum_size().y if _footer.visible else 0.0), 200.0, _root.size.y - 80.0)
	_card.offset_top = -tall * 0.5
	_card.offset_bottom = tall * 0.5

func _heading(text: String) -> void:
	_band.visible = text != ""
	if text != "":
		_band_title.text = UI.caps(text)

func _accent(_width: int) -> Array:
	# Quiet navigation rests on the scenery; its underline becomes a jade
	# ribbon under pointer or keyboard focus.
	var normal := UI.plate(Color(0.035, 0.065, 0.10, 0.80), Color(0.025, 0.045, 0.07, 0.72), Color.TRANSPARENT, 14.0, Color.TRANSPARENT, Color(UI.TRIM, 0.45), 1)
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
		b.add_theme_stylebox_override("normal", UI.plate(Color("375265"), Color("203341"), UI.GOLD, 14.0))
		b.icon = UI.icon("sovereign")
		b.add_theme_constant_override("icon_max_width", 28)
	b.pressed.connect(action)
	_panel.add_child(b)
	return b

## A main-menu entry: an icon, the name, and a line saying what it does.
func _entry(text: String, detail: String, icon_name: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 70)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = detail
	var styles := _accent(4)
	b.add_theme_stylebox_override("normal", UI.plate(Color("375265"), Color("203341"), UI.GOLD, 14.0) if primary else styles[0])
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
	d.add_theme_font_size_override("font_size", 14)
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

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F11 or event.keycode == KEY_F11):
		set_fullscreen(not is_fullscreen())
		save_settings()
		if _root != null and _root.visible and _title != null and _title.text == "SETTINGS": open_settings()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _root != null and _root.visible and in_match and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
