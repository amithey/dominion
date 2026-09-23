extends CanvasLayer
## The in-game interface, laid out like a 4X game (Civilization):
## - a top bar of resources, each an icon with its stock and its rate (green
##   when rising, red when falling), the era, and buttons for the Research,
##   Diplomacy, Market, Intelligence and Territory screens and the menu;
## - on the right, the production list: a bar per building or unit with its
##   picture (rendered from the game's own model), name, what it does, cost in
##   resource icons and time, grouped in tabs, or the selected building's own
##   training and missiles;
## - bottom left, the selection panel: a large picture of the selected
##   building or unit group, health, status and the training queue;
## - bottom right, the minimap; notices appear as small cards at the top.
## Buttons call back into world.gd; the panels refresh four times a second.

const UI := preload("res://scripts/ui_theme.gd")
const BUILD_MENU := {
	"Economy": ["villageCenter", "cityCenter", "farm", "cottage", "housing", "residential", "workerHouse", "warehouse", "foodDepot", "extractor", "market", "port", "bank", "oilRefinery", "powerPlant"],
	"Civic & research": ["school", "library", "university", "techPark", "chipFab", "hospital", "cityHall", "tvStation", "policeStation", "courthouse", "intelAgency", "nuclearReactor"],
	"Military": ["barracks", "tankFactory", "shipyard", "helipad", "airfield", "ammoDepot", "missileSilo"],
}
const RESOURCES := [
	["money", "money", "Treasury. Taxes from your citizens, markets and land; spent on everything."],
	["food", "food", "Food. Farms and farmland against what citizens and soldiers eat. At zero, growth stops."],
	["iron", "iron", "Iron. From mines on iron deposits and mountain land; for military buildings, vehicles and railways."],
	["oil", "oil", "Oil. From rigs on oil deposits; for aircraft and some buildings."],
	["silicon", "silicon", "Silicon. From silicon deposits; for high technology and missiles."],
	["uranium", "uranium", "Uranium. From uranium deposits; for the nuclear programme."],
]
const GOLD := Color("d8b866")
const RIGHT_W := 392.0
const MINI := 196.0

var world: Node
var economy: Node
var _selected = null      # building entity shown, or null
var _shown_key := ""
var _refresh := 0.0
var build_tab := "Economy"
var transport_text := ""
var prod_open := true

var _chips := {}          # resource -> [value Label, rate Label]
var _extra := {}          # "army" etc. -> Label
var _era: Label
var _prod: PanelContainer
var _prod_title: Label
var _prod_hint: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _sel: PanelContainer
var _sel_pic: TextureRect
var _sel_title: Label
var _sel_sub: Label
var _sel_hp: ProgressBar
var _sel_info: Label
var _sel_queue: HBoxContainer
var _sel_medal: Control
var _sel_stats: HBoxContainer
var _stat_values := {}    # caption -> [plate, value Label]
var _commands := {}
var _health_color := Color.TRANSPARENT
var _notices: VBoxContainer
var _fps: Label
var _help: PanelContainer
var _waiting := {}        # portrait key -> [TextureRect]

func setup(world_node: Node, economy_node: Node) -> void:
	world = world_node
	economy = economy_node
	world.portraits.portrait_ready.connect(_on_portrait)
	_build_top_bar()
	_build_production()
	_build_selection()
	_build_minimap()
	# Notices stack in the lane between the screens on the left (diplomacy,
	# market...) and the production list on the right, so they never cover either.
	_notices = VBoxContainer.new()
	_notices.anchor_left = 0.5
	_notices.anchor_right = 0.5
	_notices.anchor_top = 0.0
	_notices.anchor_bottom = 0.0
	_notices.offset_left = -60
	_notices.offset_right = 228
	_notices.offset_top = 106
	_notices.offset_bottom = 106
	_notices.grow_vertical = Control.GROW_DIRECTION_END
	_notices.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notices.add_theme_constant_override("separation", 6)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)
	_build_help()
	show_building(null)
	_build_diplomacy_panel()

func _box(_at: Vector2) -> PanelContainer:
	var box := PanelContainer.new()
	add_child(box)
	return box

func _icon(name: String, px := 22) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.icon(name)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _text(text: String, size := 15, colour := UI.TEXT, header := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if header:
		l.theme_type_variation = "HeaderLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func cost_text(cost: Dictionary) -> String:
	var parts := []
	for key in cost:
		parts.append(("$%d" % int(cost[key])) if key == "money" else ("%d %s" % [int(cost[key]), key]))
	return " · ".join(PackedStringArray(parts)) if not parts.is_empty() else "free"

## A row of cost chips: resource icon and amount, red when short.
func _cost_row(cost: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in cost:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(_icon(key, 16))
		var amount := _text(str(int(cost[key])), 13, UI.CREAM)
		amount.set_meta("res", key)
		amount.set_meta("need", float(cost[key]))
		chip.add_child(amount)
		row.add_child(chip)
	return row

# ---------------------------------------------------------------- top bar

## A thin bronze divider, the way a 4X game parts one yield from the next.
func _divider(height := 24) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Color(UI.TRIM, 0.55)
	line.custom_minimum_size = Vector2(1, height)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	# The yield strip: a lit band closed by a gold rule, as a 4X game wears it.
	var style := UI.band(5.0, Color("203b43"), Color("0a1d22"), UI.GOLD, 2)
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_bottom = 7
	bar.add_theme_stylebox_override("panel", style)
	bar.anchor_right = 1.0
	bar.offset_bottom = 48
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var first := true
	for r in RESOURCES:
		var chip := HBoxContainer.new()
		if not first:
			chip.add_child(_divider())
		first = false
		chip.add_theme_constant_override("separation", 5)
		chip.tooltip_text = r[2]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(_icon(r[1], 24))
		var value := _text("0", 17, UI.CREAM)
		chip.add_child(value)
		var rate := _text("+0", 13, UI.GOOD)
		rate.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		chip.add_child(rate)
		row.add_child(chip)
		_chips[r[0]] = [value, rate, chip]
	for extra in [["army", "army", "Army size against housing capacity. Build Housing Blocks for more."],
			["citizens", "citizens", "Citizens against the housing they can grow into. Happiness and health speed growth."],
			["research", "research", "Research points and their rate. Press Y for the research tree."],
			["land", "land", "Land held: territory cells. Press T for borders."],
			["missiles", "missile", "Missiles stored against Ammo Depot capacity."]]:
		var chip := HBoxContainer.new()
		chip.add_child(_divider())
		chip.add_theme_constant_override("separation", 5)
		chip.tooltip_text = extra[2]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(_icon(extra[1], 22))
		var value := _text("", 16, UI.CREAM)
		chip.add_child(value)
		row.add_child(chip)
		_extra[extra[0]] = [value, chip]
	# The era is cut into a small brass cartouche pinned to the right end of the
	# strip, so a nation with every store full never pushes it off the screen.
	var cartouche := PanelContainer.new()
	cartouche.add_theme_stylebox_override("panel", UI.plate(Color("2b4c52"), Color("16333a"), UI.GOLD, 7.0))
	cartouche.tooltip_text = "The era your nation has reached. Press Y for the research tree."
	_era = _text("", 15, UI.BRIGHT, true)
	_era.add_theme_font_size_override("font_size", 15)
	cartouche.add_child(_era)
	var right_end := HBoxContainer.new()
	right_end.anchor_right = 1.0
	right_end.offset_right = -12
	right_end.offset_top = 6
	right_end.alignment = BoxContainer.ALIGNMENT_END
	right_end.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_end)
	right_end.add_child(cartouche)
	# The screens: a mounted rack of round brass buttons under the strip.
	var rack := PanelContainer.new()
	rack.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	rack.offset_left = 12
	rack.offset_top = 54
	add_child(rack)
	var screens := HBoxContainer.new()
	screens.add_theme_constant_override("separation", 5)
	rack.add_child(screens)
	row = screens
	for b in [["research", "Research (Y)", func(): toggle_research()], ["diplomacy", "Diplomacy (G)", func(): toggle_diplomacy()],
			["market", "World market (M)", func(): toggle_panel("market")], ["intel", "Intelligence (I)", func(): toggle_panel("intel")],
			["land", "Territory (T)", func(): toggle_panel("territory")], ["menu", "Menu (Esc)", func(): world.menu.open_pause() if world.menu and world.menu._root != null else null]]:
		var button := Button.new()
		button.icon = UI.icon(b[0])
		button.expand_icon = true
		button.custom_minimum_size = Vector2(88, 40)
		button.text = {"research":"Research", "diplomacy":"Diplomacy", "market":"Market", "intel":"Intel", "land":"Territory", "menu":"Menu"}[b[0]]
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("icon_max_width", 20)
		button.add_theme_stylebox_override("normal", UI.box(Color("1f3941"), Color(UI.TRIM, 0.95), 1, 20, 8.0))
		button.add_theme_stylebox_override("hover", UI.box(Color("32565c"), UI.BRIGHT, 1, 20, 8.0))
		button.add_theme_stylebox_override("pressed", UI.box(Color("6d5624"), UI.BRIGHT, 1, 20, 8.0))
		button.tooltip_text = b[1]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(b[2])
		row.add_child(button)

# ---------------------------------------------------------------- production list

func _build_production() -> void:
	_prod = PanelContainer.new()
	_prod.anchor_left = 1.0
	_prod.anchor_right = 1.0
	_prod.anchor_bottom = 1.0
	_prod.offset_left = -RIGHT_W - 12
	_prod.offset_right = -12
	_prod.offset_top = 56
	_prod.offset_bottom = -MINI - 34
	# The panel itself carries no padding: the title band runs edge to edge.
	_prod.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.97), Color(UI.PANEL_LOW, 0.97), UI.TRIM, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 8))
	add_child(_prod)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_prod.add_child(column)
	# The title band: letterspaced capitals on brass, closed by a gold rule.
	var head_band := PanelContainer.new()
	head_band.add_theme_stylebox_override("panel", UI.band(8.0))
	column.add_child(head_band)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head_band.add_child(head)
	_prod_title = _text(UI.caps("Build"), 18, UI.BRIGHT, true)
	_prod_title.add_theme_font_size_override("font_size", 18)
	_prod_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prod_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_prod_title)
	var hide := Button.new()
	hide.text = "—"
	hide.custom_minimum_size = Vector2(30, 24)
	hide.tooltip_text = "Hide the production list (the Build button brings it back)"
	hide.focus_mode = Control.FOCUS_NONE
	hide.pressed.connect(func(): set_production_open(false))
	head.add_child(hide)
	# Everything under the band keeps its own margin.
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 10)
	column.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 7)
	body.add_child(inner)
	_prod_hint = _text("", 13, UI.MUTED)
	_prod_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prod_hint.custom_minimum_size = Vector2(RIGHT_W - 56, 0)
	inner.add_child(_prod_hint)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 3)
	inner.add_child(_tabs)
	for tab in BUILD_MENU:
		var t := Button.new()
		t.text = tab
		t.theme_type_variation = "TabButton"
		t.toggle_mode = true
		t.button_pressed = tab == build_tab
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(0, 30)
		t.add_theme_font_size_override("font_size", 13)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(func():
			build_tab = tab
			for other in _tabs.get_children():
				other.button_pressed = other.text == tab
			_shown_key = ""
			_update_panel())
		_tabs.add_child(t)
	# The list sits in a sunken trough, the way a 4X production list does.
	var trough := PanelContainer.new()
	trough.add_theme_stylebox_override("panel", UI.inset(5.0))
	trough.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(trough)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	trough.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	# A button to reopen the list when it is hidden.
	var reopen := Button.new()
	reopen.name = "Reopen"
	reopen.text = "  Build"
	reopen.icon = UI.icon("build")
	reopen.expand_icon = false
	reopen.anchor_left = 1.0
	reopen.anchor_right = 1.0
	reopen.anchor_top = 1.0
	reopen.anchor_bottom = 1.0
	reopen.offset_left = -132
	reopen.offset_right = -12
	reopen.offset_top = -MINI - 74
	reopen.offset_bottom = -MINI - 34
	reopen.focus_mode = Control.FOCUS_NONE
	reopen.visible = false
	reopen.pressed.connect(func(): set_production_open(true))
	add_child(reopen)

func set_production_open(on: bool) -> void:
	prod_open = on
	_prod.visible = on
	get_node("Reopen").visible = not on

## A heading inside the list: gold capitals with a hairline rule beneath.
func _section(title: String) -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text(UI.caps(title), 13, GOLD, true)
	l.add_theme_font_size_override("font_size", 13)
	holder.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(UI.TRIM, 0.75)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rule)
	_list.add_child(holder)

## One production bar: picture, name, one line of what it does, cost chips,
## time. Disabled (dimmed) when it cannot be afforded or is locked.
func _bar(key: String, title: String, desc: String, cost: Dictionary, seconds: float, locked: String, action: Callable) -> void:
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.custom_minimum_size = Vector2(0, 76)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = desc if locked == "" else "%s\n%s" % [locked, desc]
	b.set_meta("cost", cost)
	b.set_meta("locked", locked != "")
	b.pressed.connect(action)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7
	row.offset_right = -9
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# The picture sits in a sunken bronze-lipped frame, as a 4X entry does.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.inset(2.0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(80, 60)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_portrait(pic, key)
	frame.add_child(pic)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name := _text(title, 15, UI.CREAM, true)
	name.add_theme_font_size_override("font_size", 15)
	text.add_child(name)
	var line := _text(locked if locked != "" else desc, 12, UI.BAD if locked != "" else UI.MUTED)
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.custom_minimum_size = Vector2(190, 0)
	line.clip_text = true
	text.add_child(line)
	text.add_child(_cost_row(cost))
	if seconds > 0.0:
		# The build time in a small brass tally at the end of the row.
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tally := PanelContainer.new()
		tally.add_theme_stylebox_override("panel", UI.box(Color("081018"), Color(UI.TRIM, 0.8), 1, 2, 5.0))
		tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tally.add_child(_text("%ds" % int(seconds), 12, GOLD))
		holder.add_child(tally)
		row.add_child(holder)
	_list.add_child(b)

func _set_portrait(pic: TextureRect, key: String) -> void:
	var tex: Texture2D = world.portraits.get_portrait(key)
	if tex != null:
		pic.texture = tex
	else:
		pic.texture = UI.icon("army" if world.unit_defs.has(key) else "build")
		if not _waiting.has(key):
			_waiting[key] = []
		_waiting[key].append(pic)

func _on_portrait(key: String, tex: Texture2D) -> void:
	for pic in _waiting.get(key, []):
		if is_instance_valid(pic) and tex != null:
			pic.texture = tex
	_waiting.erase(key)

# ---------------------------------------------------------------- selection panel

func _build_selection() -> void:
	_sel = PanelContainer.new()
	_sel.anchor_top = 1.0
	_sel.anchor_bottom = 1.0
	_sel.offset_left = 12
	_sel.offset_right = 560
	_sel.offset_top = -272
	_sel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sel.offset_bottom = -12
	_sel.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.97), Color(UI.PANEL_LOW, 0.97), UI.TRIM, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 8))
	add_child(_sel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_sel.add_child(column)
	# The name of what is selected rides its own band, as in a 4X portrait.
	var head_band := PanelContainer.new()
	head_band.add_theme_stylebox_override("panel", UI.band(8.0))
	column.add_child(head_band)
	_sel_title = _text("", 19, UI.BRIGHT, true)
	_sel_title.add_theme_font_size_override("font_size", 19)
	head_band.add_child(_sel_title)
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 10)
	column.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	# The portrait sits in a round medallion ringed in bronze and gold, on a
	# disc of its owner's colour.
	_sel_medal = Control.new()
	_sel_medal.set_script(preload("res://scripts/medallion.gd"))
	_sel_medal.custom_minimum_size = Vector2(150, 150)
	_sel_medal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_sel_pic = TextureRect.new()
	_sel_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sel_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sel_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sel_pic.offset_top = 2
	_sel_pic.offset_bottom = 2
	_sel_medal.add_child(_sel_pic)
	row.add_child(_sel_medal)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	row.add_child(col)
	_sel_sub = _text("", 13, GOLD)
	_sel_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sel_sub)
	_sel_hp = ProgressBar.new()
	_sel_hp.custom_minimum_size = Vector2(0, 14)
	_sel_hp.custom_minimum_size.y = 22
	_sel_hp.show_percentage = true
	_sel_hp.add_theme_stylebox_override("fill",UI.plate(Color("6fae7a"),Color("30684a"),Color(0,0,0,0),0.0,Color(1,1,1,0.25)))
	col.add_child(_sel_hp)
	# Stat plaques: a small caption over a large figure, as a 4X unit card shows them.
	_sel_stats = HBoxContainer.new()
	_sel_stats.add_theme_constant_override("separation", 4)
	col.add_child(_sel_stats)
	for caption in ["ATTACK", "RANGE", "SPEED", "HEALTH"]:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		plate.add_theme_stylebox_override("panel", UI.plate(Color("1c2e47"), Color("0c1626"), Color(UI.TRIM, 0.8), 4.0))
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", -2)
		plate.add_child(stack)
		var cap := _text(caption, 10, UI.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(cap)
		var value := _text("", 16, UI.CREAM, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(value)
		_sel_stats.add_child(plate)
		_stat_values[caption] = [plate, value]
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation",4)
	col.add_child(commands)
	for action in ["Attack-move","Bombard","Repair"]:
		var button := Button.new()
		button.text = action
		button.toggle_mode = action != "Repair"
		button.tooltip_text = {"Attack-move":"Move to a destination and engage suitable targets along the way. Ctrl + right click.","Bombard":"Fire at a ground position or infrastructure. Alt + right click. Requires a suitable weapon.","Repair":"Repair damaged vehicles or completed buildings for $0.25 per HP. Pauses in combat."}[action]
		_commands[action] = button
		button.add_theme_font_size_override("font_size",12)
		button.custom_minimum_size = Vector2(0,30)
		button.pressed.connect(func():
			if action=="Repair":
				world.Repairs.request(world,[_selected] if _selected!=null else _selected_units())
			else:
				world.order_mode = "bombard" if action=="Bombard" else "attack"
				world.hud.notice("%s: click a destination on the battlefield." % action))
		commands.add_child(button)
	var health := Control.new()
	health.set_script(preload("res://scripts/health_overlay.gd"))
	world.health_overlay = health  # the feature probe can hide it
	health.world = world
	health.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(health)
	move_child(health,0)
	_sel_info = _text("", 13, UI.TEXT)
	_sel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sel_info.custom_minimum_size = Vector2(280, 0)
	_sel_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_sel_info)
	_sel_queue = HBoxContainer.new()
	_sel_queue.add_theme_constant_override("separation", 4)
	col.add_child(_sel_queue)
	_sel.visible = false

func _build_minimap() -> void:
	var frame := PanelContainer.new()
	frame.anchor_left = 1.0
	frame.anchor_right = 1.0
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -MINI - 24
	frame.offset_right = -12
	frame.offset_top = -MINI - 24
	frame.offset_bottom = -12
	frame.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.97), Color(UI.PANEL_LOW, 0.97), UI.TRIM, 5.0, UI.LIFT, Color(0, 0, 0, 0), 0, 7))
	add_child(frame)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UI.inset(2.0))
	frame.add_child(well)
	var map := preload("res://scripts/minimap.gd").new()
	map.custom_minimum_size = Vector2(MINI, MINI)
	well.add_child(map)
	map.setup(world)
	_fps = _text("", 11, Color(1, 1, 1, 0.4))
	_fps.anchor_left = 1.0
	_fps.anchor_right = 1.0
	_fps.anchor_top = 1.0
	_fps.anchor_bottom = 1.0
	_fps.offset_left = -MINI - 24
	_fps.offset_right = -16
	_fps.offset_top = -30
	_fps.offset_bottom = -14
	_fps.z_index = 1
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fps)

func _build_help() -> void:
	_help = PanelContainer.new()
	_help.anchor_left = 0.5
	_help.anchor_right = 0.5
	_help.anchor_top = 0.5
	_help.anchor_bottom = 0.5
	_help.offset_left = -300
	_help.offset_right = 300
	_help.offset_top = -210
	_help.visible = false
	_help.add_theme_stylebox_override("panel", UI.plate(Color("183039"), Color("0a191f"), UI.TRIM, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 9))
	add_child(_help)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 0)
	_help.add_child(sheet)
	var head_band := PanelContainer.new()
	head_band.add_theme_stylebox_override("panel", UI.band(9.0))
	sheet.add_child(head_band)
	var head := _text(UI.caps("Controls"), 19, UI.BRIGHT, true)
	head.add_theme_font_size_override("font_size", 19)
	head_band.add_child(head)
	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 14)
	sheet.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	body.add_child(col)
	for line in [["Move the camera", "W A S D or the arrow keys, the screen edge, or drag with the middle mouse button"],
			["Turn / tilt / zoom", "Q E  ·  R F  ·  mouse wheel (zooms toward the cursor)"],
			["Select", "Click a unit or building, or drag a box around units"],
			["Orders", "Right click: move or attack  ·  Ctrl + right click: attack-move"],
			["Bombard", "Alt + right click: fire at ground or infrastructure (armed vehicles)"],
			["Aircraft", "Limited salvos; empty aircraft return to a supplied airfield / helipad to rearm"],
			["Build", "Pick a building in the list on the right, click a hex in your city (Shift keeps placing)"],
			["Screens", "Y research  ·  G diplomacy  ·  M market  ·  I intelligence  ·  T territory"],
			["Game", "F5 save  ·  F9 load  ·  Esc cancel / pause menu  ·  F1 this help"],
			["Minimap", "Click or drag on it to jump anywhere on the island"]]:
		var row := HBoxContainer.new()
		var k := _text(line[0], 14, GOLD)
		k.custom_minimum_size = Vector2(150, 0)
		row.add_child(k)
		var v := _text(line[1], 14, UI.TEXT)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size = Vector2(410, 0)
		row.add_child(v)
		col.add_child(row)
	var close := Button.new()
	close.text = "Close (F1)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle_help)
	col.add_child(close)

func toggle_help() -> void:
	_help.visible = not _help.visible

# ---------------------------------------------------------------- refresh

func _process(delta: float) -> void:
	if economy == null:
		return
	_refresh += delta
	if _refresh < 0.25:
		return
	_refresh = 0.0
	var clock: int = world.clock()
	for r in RESOURCES:
		var key: String = r[0]
		var parts: Array = _chips[key]
		var rate: float = economy.rates.get(key, 0.0)
		var have: float = economy.res.get(key, 0.0)
		parts[2].visible = not (key in ["silicon", "uranium", "oil"] and have < 0.5 and absf(rate) < 0.01)
		# The storage cap shows only when the store is nearly full (and always in the tooltip).
		var cap: float = float(economy.caps.get(key, INF)) if key != "money" else INF
		parts[0].text = ("%d/%d" % [int(have), int(cap)]) if have >= cap * 0.9 else str(int(have))
		parts[0].add_theme_color_override("font_color", Color("f0b25a") if have >= cap * 0.9 else UI.CREAM)
		parts[2].tooltip_text = "%s
Stock %d%s, %s%.1f per second." % [RESOURCES.filter(func(x): return x[0] == key)[0][2], int(have), (" of %d" % int(cap)) if cap < INF else "", "+" if rate >= 0.0 else "", rate]
		parts[1].text = "%s%.1f" % ["+" if rate >= 0.0 else "", rate]
		parts[1].add_theme_color_override("font_color", UI.GOOD if rate > 0.01 else (UI.BAD if rate < -0.01 else UI.MUTED))
	_extra.army[0].text = "%d/%d" % [economy.pop_used, economy.pop_cap]
	_extra.army[0].add_theme_color_override("font_color", UI.BAD if economy.pop_used >= economy.pop_cap else UI.CREAM)
	_extra.citizens[0].text = "%d/%d" % [int(economy.civilians), int(economy.civ_cap)]
	if world.research:
		_extra.research[0].text = "%d  +%.1f" % [int(world.research.points), world.research.rate]
		# As a 4X game dates its turns: the era, then the year of the reign (a minute a year).
		_era.text = "%s  ·  YEAR %d" % [world.research.eras[world.research.era].name.to_upper(), 1 + int(world.game_time / 60.0)]
	if world.territory:
		_extra.land[0].text = str(world.territory.yields(0).cells)
	var silos: bool = world.missiles != null and (world.missiles.stored() > 0 or not world.missiles.silos().is_empty())
	_extra.missiles[1].visible = silos
	if silos:
		_extra.missiles[0].text = "%d/%d" % [world.missiles.stored(), world.missiles.capacity()]
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _selected != null and (_selected.dead or _selected.owner != 0):
		show_building(null)
	_update_panel()
	world.spent("hud", clock)

## Road or rail planning status (empty ends it).
func show_transport(text: String) -> void:
	transport_text = text
	_shown_key = ""
	_update_panel()

## null shows the build menu; a building entity shows its details and training.
func show_building(building) -> void:
	_selected = building
	_shown_key = ""
	if building != null and not prod_open:
		set_production_open(true)
	_update_panel()

func _selected_units() -> Array:
	return world.units.filter(func(u): return u.selected and not u.dead and u.owner == 0)

func _update_panel() -> void:
	_update_selection()
	_update_health_color()
	var key: String = ("menu:" + build_tab) if _selected == null else "%s:%s:%d" % [_selected.key, _selected.built, _selected.queue.size()]
	if _selected != null and _selected.key == "missileSilo":
		key += ":%s" % str(world.missiles.stock)
	if world.research:
		key += ":%d:%s" % [world.research.era, str(world.research.completed_count())]
	_tabs.visible = _selected == null
	if key == _shown_key:
		_update_enabled()
		return
	_shown_key = key
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _selected == null or not _selected.built or not _has_actions(_selected):
		_prod_title.text = UI.caps("Build")
		_prod_hint.text = "Pick a building, then click a hex inside your city. Workers go and build it. Shift keeps placing; right click cancels."
		_tabs.visible = true
		_building_bars()
	else:
		_prod_title.text = UI.caps(_selected.def.name)
		_prod_hint.text = "Choose what this building produces. Up to five orders queue here."
		_action_bars(_selected)
	_update_enabled()

func _has_actions(b: Dictionary) -> bool:
	return not b.def.get("trains", []).is_empty() or b.key in ["missileSilo", "market", "port", "intelAgency"] or b.key in world.research.LABS

func _building_bars() -> void:
	for b in BUILD_MENU[build_tab]:
		var def: Dictionary = world.building_defs.get(b, {})
		if def.is_empty():
			continue
		var why := ""
		if def.get("unique", false) and world.buildings.any(func(x): return x.owner == 0 and x.key == b and not x.dead):
			why = "Built (one per nation)"
		_bar(b, def.name, def.desc, def.cost, float(def.get("buildTime", 0)), why, func(): world.begin_placement(b))
	if build_tab == "Economy":
		_section("Transport")
		for kind in ["road", "rail"]:
			var price: Dictionary = world.logistics.transport[kind]
			var cost := {"money": price.money, "iron": price.iron} if float(price.iron) > 0 else {"money": price.money}
			_bar("villageCenter", "Road" if kind == "road" else "Railway", "Per hex. Click a start hex, then a destination: links towns to the capital so they are supplied." + ("" if kind == "road" else " Railways add 25% production."),
				cost, 0.0, "", func(): world.begin_transport(kind))

func _action_bars(b: Dictionary) -> void:
	if b.key == "missileSilo":
		var ms: Node = world.missiles
		var armed := false
		for m in ms.types():
			if ms.stock[m] > 0:
				if not armed:
					_section("Launch")
					armed = true
				_bar("missileSilo", "LAUNCH %s  (%d)" % [ms.def_of(m).name, ms.stock[m]], "Arm it, then click the target on the map.", {}, 0.0, "", func(): world.begin_missile(m))
		_section("Build missiles  (%d/%d stored)" % [ms.stored(), ms.capacity()])
		for m in ms.types():
			var mdef: Dictionary = ms.def_of(m)
			_bar("missileSilo", mdef.name, "%s Damage %d, blast %d m." % [mdef.desc, int(mdef.dmg), int(mdef.radius)], mdef.cost, float(mdef.buildTime), ms.locked(m), func(): _say(ms.produce(_selected, m)))
		return
	if b.key in world.research.LABS:
		_bar("university", "Open the research tree", "Research points from this building flow into the discovery at the head of the queue.", {}, 0.0, "", toggle_research)
		return
	if b.key in ["market", "port", "intelAgency"]:
		var which: String = "intel" if b.key == "intelAgency" else "market"
		_bar(b.key, "Open %s" % ("the intelligence service" if which == "intel" else "the world market"), "", {}, 0.0, "", func(): toggle_panel(which, true))
		return
	_section("Train")
	for u in b.def.trains:
		var def: Dictionary = world.unit_defs.get(u, {})
		if def.is_empty():
			continue
		var cost: Dictionary = world.research.unit_cost(u, def.cost) if world.research else def.cost
		var locked: String = world.research.unit_locked(u) if world.research else ""
		_bar(u, def.name, def.desc, cost, float(def.get("trainTime", 10)), locked, func(): world.queue_unit(_selected, u))

func _update_enabled() -> void:
	for b in _list.get_children():
		if not (b is Button) or not b.has_meta("cost"):
			continue
		var cost: Dictionary = b.get_meta("cost")
		b.disabled = not economy.can_afford(cost) or b.get_meta("locked", false)
		for amount in b.find_children("*", "Label", true, false):
			if amount.has_meta("res"):
				var short: bool = economy.res.get(amount.get_meta("res"), 0.0) < float(amount.get_meta("need"))
				amount.add_theme_color_override("font_color", UI.BAD if short else UI.CREAM)

## The selection panel: a building, a group of units, or road planning.
func _update_selection() -> void:
	var units := _selected_units()
	var own_units: Array = units.filter(func(u):return u.owner==0 and not u.dead) if _selected==null else []
	var assets: Array = [_selected] if _selected!=null else own_units
	_commands["Attack-move"].disabled = own_units.is_empty() or not own_units.any(func(u):return u.dmg>0)
	_commands["Bombard"].disabled = not own_units.any(func(u):return u.vehicle and u.dmg>0 and not u.key in ["aaVehicle","samLauncher","submarine","nuclearSub"])
	_commands["Repair"].disabled = not assets.any(func(e):return e.owner==0 and not e.dead and e.hp<e.max_hp and (e.get("is_building",false) and e.get("built",false) or e.get("vehicle",false)))
	_commands["Attack-move"].set_pressed_no_signal(world.order_mode=="attack")
	_commands["Bombard"].set_pressed_no_signal(world.order_mode=="bombard")
	for button in _commands.values():
		button.visible = transport_text==""
	_sel_stats.visible = false
	if transport_text != "":
		_sel.visible = true
		_sel_title.text = UI.caps("Road" if world.transport_kind == "road" else "Railway")
		_sel_sub.text = "Supply network"
		_sel_hp.visible = false
		_sel_info.text = transport_text
		_show_pic("villageCenter")
		_fill_queue([])
		return
	if _selected != null:
		var b: Dictionary = _selected
		_sel.visible = true
		_show_pic(b.key)
		_medal_owner(b.owner)
		_sel_title.text = UI.caps(b.def.name)
		_sel_sub.text = "Under construction" if not b.built else String(b.def.get("cat", "")).capitalize()
		_sel_hp.visible = true
		if not b.built:
			_sel_hp.max_value = 1.0
			_sel_hp.value = b.progress
		else:
			_sel_hp.max_value = b.max_hp
			_sel_hp.value = b.hp
		var lines := []
		if not b.built:
			lines.append("%d%% built%s" % [int(b.progress * 100), "" if b.builders > 0 else " — waiting for a worker"])
		else:
			lines.append("Health %d/%d. %s" % [int(b.hp), int(b.max_hp), b.def.desc])
			if not b.get("supplied", true):
				lines.append("OUT OF SUPPLY: production stopped. Link this town to the capital by road or rail.")
			elif b.get("rail_supplied", false):
				lines.append("Rail supplied: +25% production.")
			if world.disabled(b):
				lines.append("EMP: systems down.")
		_sel_info.text = "\n".join(PackedStringArray(lines))
		if b.get("repairing",false):
			_sel_info.text += "\nRepairing · pauses for 6 s after a hit."
		_fill_queue(b.queue, b.queue_prog)
		return
	if not units.is_empty():
		_sel.visible = true
		var counts := {}
		var hp := 0.0
		var max_hp := 0.0
		for u in units:
			counts[u.key] = counts.get(u.key, 0) + 1
			hp += u.hp
			max_hp += u.max_hp
		var main: String = counts.keys()[0]
		for k in counts:
			if counts[k] > counts[main]:
				main = k
		_show_pic(main)
		_medal_owner(units[0].owner)
		var lead: Dictionary = units.filter(func(u): return u.key == main)[0]
		_show_stats({"ATTACK": "%d" % int(lead.dmg), "RANGE": "%d m" % int(lead.range),
			"SPEED": "%.1f" % float(lead.speed), "HEALTH": "%d%%" % int(round(100.0 * hp / maxf(max_hp, 1.0)))})
		var name: String = world.unit_defs.get(main, {}).get("name", main)
		_sel_title.text = UI.caps(name if units.size() == 1 else "%d units" % units.size())
		var parts := PackedStringArray()
		for k in counts:
			parts.append("%d %s" % [counts[k], world.unit_defs.get(k, {}).get("name", k)])
		_sel_sub.text = ", ".join(parts)
		_sel_hp.visible = true
		_sel_hp.max_value = max_hp
		_sel_hp.value = hp
		var def: Dictionary = world.unit_defs.get(main, {})
		_sel_info.text = ("%s\nRight click to move or attack; Ctrl + right click to attack-move." % def.get("desc", "")) if units.size() == 1 else "Right click to move or attack; Ctrl + right click to attack-move."
		_fill_queue([])
		if units.size() == 1 and units[0].get("fly",false):
			var u: Dictionary = units[0]
			_sel_info.text = "Ammunition: %d/%d salvos | %s\n%s" % [u.ammo,world.AirOperations.CAPACITY[u.key],u.air_state.capitalize(),"Rearming: %.0f s" % u.service_left if u.air_state == "rearming" else "Empty aircraft return to a supplied air base."]
		elif units.any(func(u): return u.vehicle):
			_sel_info.text += "\nAlt + right click: bombard ground / infrastructure."
		_sel_info.text += "\nHP %d / %d%s" % [int(hp),int(max_hp)," · Repair ordered" if units.any(func(u): return u.get("repairing",false)) else ""]
		return
	_sel.visible = false

func _show_stats(values: Dictionary) -> void:
	_sel_stats.visible = true
	for caption in _stat_values:
		var shown: bool = values.has(caption)
		_stat_values[caption][0].visible = shown
		if shown:
			_stat_values[caption][1].text = values[caption]

func _medal_owner(owner: int) -> void:
	var colour := Color("20324d")
	if owner < world.map.nations.size():
		colour = Color(world.map.nations[owner].color).darkened(0.35).lerp(Color("20324d"), 0.35)
	if colour != _sel_medal.tint:
		_sel_medal.set_tint(colour)

func _update_health_color() -> void:
	var fraction := _sel_hp.value / maxf(_sel_hp.max_value,1.0)
	var color := UI.GOOD if fraction>0.6 else (UI.GOLD if fraction>0.3 else UI.BAD)
	if _selected!=null and not _selected.built:
		color = Color("82b2dc")
	if color != _health_color:
		_health_color = color
		_sel_hp.add_theme_stylebox_override("fill",UI.plate(color.lightened(0.15),color.darkened(0.3),Color(0,0,0,0),0.0,Color(1,1,1,0.25)))
	_sel_hp.tooltip_text = "%d / %d HP" % [int(_sel_hp.value),int(_sel_hp.max_value)] if _selected==null or _selected.built else "Construction progress"

var _pic_key := ""
func _show_pic(key: String) -> void:
	if key == _pic_key and _sel_pic.texture != null:
		return
	_pic_key = key
	_set_portrait(_sel_pic, key)

var _queue_sig := ""
func _fill_queue(queue: Array, progress := 0.0) -> void:
	var sig := str(queue)
	if sig != _queue_sig:
		_queue_sig = sig
		for child in _sel_queue.get_children():
			_sel_queue.remove_child(child)
			child.queue_free()
		for i in range(queue.size()):
			var item: String = queue[i]
			var slot := VBoxContainer.new()
			slot.add_theme_constant_override("separation", 1)
			var pic := TextureRect.new()
			pic.custom_minimum_size = Vector2(56, 42)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_set_portrait(pic, "missileSilo" if item.begins_with("missile:") else item)
			pic.tooltip_text = world.missiles.def_of(item.substr(8)).name if item.begins_with("missile:") else world.unit_defs.get(item, {}).get("name", item)
			slot.add_child(pic)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(56, 5)
			bar.show_percentage = false
			bar.max_value = 1.0
			slot.add_child(bar)
			_sel_queue.add_child(slot)
	if not queue.is_empty() and _sel_queue.get_child_count() > 0:
		var first: ProgressBar = _sel_queue.get_child(0).get_child(1)
		first.value = progress

# ---------------------------------------------------------------- screens
# Diplomacy, the world market, intelligence and territory share one window,
# docked on the left under the screen buttons: a title bar with the screen's
# icon and a close button, then cards. It is only as tall as its content.

const SCREENS := {"diplomacy": ["diplomacy", "Diplomacy"], "market": ["market", "World market"],
	"intel": ["intel", "Intelligence"], "territory": ["land", "Territory"]}

var _win: PanelContainer
var _win_icon: TextureRect
var _win_title: Label
var _win_scroll: ScrollContainer
var _side_rows: VBoxContainer
var side_mode := ""          # "", "diplomacy", "market", "intel" or "territory"
var _hooked := false
var _letters: Array = []     # pending [text, accept, decline]
var _letter_box: PanelContainer
# Choices kept across rebuilds of the screens.
var trade_qty := 25
var route_nation := -1
var route_res := "oil"
var route_dir := "export"
var spy_target := 1
var spy_op := "buildNetwork"
var spy_role := "president"
var territory_pick := "Click anywhere on the map to see who holds that land."

func _build_diplomacy_panel() -> void:
	_win = PanelContainer.new()
	_win.offset_left = 12
	_win.offset_top = 104
	_win.offset_right = 580
	_win.visible = false
	_win.add_theme_stylebox_override("panel", UI.plate(Color(UI.PANEL_TOP, 0.97), Color(UI.PANEL_LOW, 0.97), UI.TRIM, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 8))
	add_child(_win)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_win.add_child(column)
	# The title band: the screen's device, its name in capitals, and the way out.
	var head_band := PanelContainer.new()
	head_band.add_theme_stylebox_override("panel", UI.band(8.0))
	column.add_child(head_band)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	head_band.add_child(bar)
	_win_icon = _icon("diplomacy", 30)
	bar.add_child(_win_icon)
	_win_title = _text("", 20, UI.BRIGHT, true)
	_win_title.add_theme_font_size_override("font_size", 20)
	_win_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_win_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_win_title)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(34, 28)
	close.pressed.connect(func(): _show_side(""))
	bar.add_child(close)
	var body := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 10)
	column.add_child(body)
	_win_scroll = ScrollContainer.new()
	_win_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_win_scroll)
	_side_rows = VBoxContainer.new()
	_side_rows.add_theme_constant_override("separation", 8)
	_side_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_win_scroll.add_child(_side_rows)

func toggle_diplomacy() -> void:
	toggle_panel("diplomacy")

func refresh_diplomacy() -> void:
	if side_mode == "diplomacy":
		refresh_side()

## Shows a message unless it is empty.
func _say(message: String) -> void:
	if message != "":
		notice(message)

func toggle_panel(mode: String, force_open := false) -> void:
	_show_side("" if side_mode == mode and not force_open else mode)

func _show_side(mode: String) -> void:
	if not _hooked and world.market != null:
		_hooked = true
		world.market.changed.connect(func(): if side_mode == "market": refresh_side())
		world.espionage.changed.connect(func(): if side_mode == "intel": refresh_side())
		world.territory.changed.connect(func(): if side_mode == "territory": refresh_side())
		world.diplomacy.changed.connect(func(): if side_mode == "diplomacy": refresh_side())
	side_mode = mode
	_win.visible = mode != ""
	if mode != "" and _rs != null:
		_rs.visible = false
	if world.territory:
		world.territory.set_visible_borders(mode == "territory")
	if mode != "":
		_win_icon.texture = UI.icon(SCREENS[mode][0])
		_win_title.text = UI.caps(SCREENS[mode][1])
	refresh_side()

func refresh_side() -> void:
	if _win == null or side_mode == "":
		return
	var keep := _win_scroll.scroll_vertical
	for child in _side_rows.get_children():
		_side_rows.remove_child(child)
		child.queue_free()
	match side_mode:
		"diplomacy":
			_diplomacy_screen()
		"market":
			_market_panel()
		"intel":
			_intel_panel()
		"territory":
			_territory_panel()
	_fit_window.call_deferred(keep)

# The window is as tall as its content, up to the space above the bottom panels.
func _fit_window(keep_scroll: int) -> void:
	var room := get_viewport().get_visible_rect().size.y - 104.0 - 250.0
	_win_scroll.custom_minimum_size = Vector2(540, minf(_side_rows.get_combined_minimum_size().y, maxf(room, 160.0)))
	_win.reset_size()
	_win_scroll.scroll_vertical = keep_scroll

# ---------------------------------------------------------------- widgets

func _label(parent: Control, text: String, colour := UI.TEXT, size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

## A heading in a screen: gold capitals over a hairline rule.
func _heading(text: String) -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text(UI.caps(text), 14, GOLD, true)
	l.add_theme_font_size_override("font_size", 14)
	holder.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(UI.TRIM, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rule)
	_side_rows.add_child(holder)

## A card: a raised panel, with a stripe down the left in `stripe` if given.
func _card(stripe := Color(0, 0, 0, 0)) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := UI.box(Color("142337"), Color("2d4460"), 1, 2, 10.0)
	if stripe.a > 0.0:
		style.border_color = Color(stripe, 0.95)
		style.border_width_left = 5
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		style.content_margin_left = 14
	card.add_theme_stylebox_override("panel", style)
	_side_rows.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	card.add_child(col)
	return col

## A small rounded tag, like "AT WAR" or "ALLY".
func _pill(parent: Control, text: String, colour: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(colour, 0.22), Color(colour, 0.9), 1, 3, 4.0))
	var l := _text(text, 12, colour.lightened(0.3))
	p.add_child(l)
	parent.add_child(p)

## A bar with a caption over it: relation, chance, intelligence, land share.
func _meter(parent: Control, value: float, max_value: float, colour: Color, caption: String) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 20)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(holder)
	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	bar.max_value = max_value
	bar.value = value
	bar.add_theme_stylebox_override("fill", UI.plate(colour.lightened(0.18), colour.darkened(0.28), Color(0, 0, 0, 0), 0.0, Color(1, 1, 1, 0.25)))
	holder.add_child(bar)
	var l := _text(caption, 12, UI.CREAM)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 4)
	holder.add_child(l)

func _row(parent: Control, gap := 8) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", gap)
	parent.add_child(r)
	return r

func _button(parent: Control, text: String, action: Callable, enabled := true, tone := "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	if tone == "good":
		b.add_theme_stylebox_override("normal", UI.plate(Color("27553a"), Color("122a1d"), Color("6fae7a"), 9.0))
		b.add_theme_stylebox_override("hover", UI.plate(Color("37724d"), Color("1a3a28"), UI.BRIGHT, 9.0, Color(1, 1, 1, 0.18)))
	elif tone == "bad":
		b.add_theme_stylebox_override("normal", UI.plate(Color("5a2a24"), Color("2a1210"), Color("b06a58"), 9.0))
		b.add_theme_stylebox_override("hover", UI.plate(Color("7a382f"), Color("3a1a16"), UI.BRIGHT, 9.0, Color(1, 1, 1, 0.18)))
	b.pressed.connect(func():
		_say(action.call())
		refresh_side())
	parent.add_child(b)
	return b

## Buttons side by side, one of them lit: a compact choice.
func _segments(parent: Control, items: Array, selected, on_pick: Callable) -> void:
	var row := _row(parent, 2)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.toggle_mode = true
		b.button_pressed = item[1] == selected
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		var value = item[1]
		b.pressed.connect(func():
			on_pick.call(value)
			refresh_side())
		row.add_child(b)

## A drop-down of [[label, value], ...]; on_pick receives the value.
func _choice(parent: Control, items: Array, selected, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for i in range(items.size()):
		o.add_item(items[i][0], i)
		if items[i][1] == selected:
			o.select(i)
	o.item_selected.connect(func(i): on_pick.call(items[i][1]))
	parent.add_child(o)
	return o

func _nation_colour(id: int) -> Color:
	return Color(world.map.nations[id].color)

# ---------------------------------------------------------------- diplomacy

func _relation_word(score: float) -> String:
	if score >= 60.0: return "Friendly"
	if score >= 25.0: return "Cordial"
	if score > -25.0: return "Neutral"
	if score > -60.0: return "Unfriendly"
	return "Hostile"

func _diplomacy_screen() -> void:
	var d: Node = world.diplomacy
	_label(_side_rows, "Relations run from -100 to +100. Gifts, pacts and trade warm them; war, spies caught and broken treaties sour them.", UI.MUTED, 13)
	_standing_orders()
	for id in range(1, d.n):
		var card := _card(_nation_colour(id))
		var head := _row(card)
		var name := _text(d.name_of(id), 18, _nation_colour(id).lightened(0.4), true)
		name.add_theme_font_size_override("font_size", 18)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		if d.defeated(id):
			_pill(head, "DEFEATED", UI.MUTED)
			continue
		if d.at_war(0, id):
			_pill(head, "AT WAR", Color("e0574a"))
		if d.allied(0, id):
			_pill(head, "ALLY", Color("6fc46a"))
		if d.pact[0][id]:
			_pill(head, "TRADE PACT", Color("d8b866"))
		if d.nap[0][id]:
			_pill(head, "NON-AGGRESSION", Color("6fa6d8"))
		if not (d.at_war(0, id) or d.allied(0, id) or d.pact[0][id] or d.nap[0][id]):
			_pill(head, "PEACE", Color("9aa7ab"))
		var leader: String = world.map.nations[id].get("people", {}).get("president", "")
		card.add_child(_text("%s  ·  army of about %d" % [leader, d.army_strength(id)], 13, UI.MUTED))
		var score: float = d.rel(0, id)
		var colour := Color("c0564a").lerp(Color("8a9396"), clampf((score + 100.0) / 100.0, 0.0, 1.0)) if score < 0.0 else Color("8a9396").lerp(Color("5fae63"), clampf(score / 100.0, 0.0, 1.0))
		_meter(card, score + 100.0, 200.0, colour, "Relation %+d  ·  %s" % [int(score), _relation_word(score)])
		var buttons := _row(card, 6)
		if d.at_war(0, id):
			_button(buttons, "Offer peace", d.offer_peace.bind(id), true, "good")
		else:
			_button(buttons, "Gift $250", d.gift.bind(id))
			if not d.pact[0][id]:
				_button(buttons, "Trade pact", d.propose_pact.bind(id))
			if not d.nap[0][id]:
				_button(buttons, "Non-aggression", d.propose_nap.bind(id))
			if not d.allied(0, id):
				_button(buttons, "Alliance", d.propose_alliance.bind(id), true, "good")
			_button(buttons, "Declare war", _declare.bind(id), true, "bad")
		if d.allied(0, id):
			for enemy in range(1, d.n):
				if d.at_war(0, enemy) and not d.at_war(id, enemy):
					_button(card, "Call them to war against %s" % d.name_of(enemy), d.request_joint_war.bind(id, enemy))

## The cabinet's standing orders. A soldier carries out the order he is given;
## what the shot is called is decided here, by the state.
func _standing_orders() -> void:
	var e = world.engagement
	if e == null:
		return
	var card := _card(GOLD)
	card.add_child(_text(UI.caps("Standing orders"), 14, GOLD, true))
	_label(card, "How your government frames an attack on a nation you are not at war with. Your soldiers obey the order either way; the cabinet decides what it is called, and their government answers as it sees fit.", UI.MUTED, 13)
	_segments(card, [["Limited operation", "limited"], ["Full war", "war"]], e.policy, func(v):
		e.policy = v
		notice("Standing orders: %s." % e.doctrine_text()))
	_label(card, "Limited operation: ninety seconds of fighting, no declaration of war. They may contain it, answer in kind, or call it war — a government swallows only so many incidents." if e.policy == "limited" else "Full war: the strike comes with a declaration of war, and their allies may join them.",
		UI.TEXT, 13)
	var running := PackedStringArray()
	for id in range(1, world.diplomacy.n):
		if e.left(id) > 0.0:
			running.append("%s · %ds left · %d incident(s)" % [world.diplomacy.name_of(id), int(e.left(id)), int(e.incidents.get(str(id), 0))])
	if not running.is_empty():
		_label(card, "Operations under way: " + "   ".join(running), UI.BRIGHT, 13)

func _declare(id: int) -> String:
	world.diplomacy.declare_war(0, id)
	return ""

## A foreign government's proposal, as a letter in the middle of the screen.
func ask(text: String, accept: Callable, decline: Callable, title := "FOREIGN OFFICE") -> void:
	_letters.append([text, accept, decline, title, []])
	if _letter_box == null:
		_show_letter()

## A letter with more than two answers, for a decision that is not a yes or a
## no: each answer is [label, tone ("good", "bad" or ""), what it does].
func choose(title: String, text: String, answers: Array) -> void:
	_letters.append([text, func(): pass, func(): pass, title, answers])
	if _letter_box == null:
		_show_letter()

func _show_letter() -> void:
	if _letters.is_empty():
		return
	var letter: Array = _letters.pop_front()
	_letter_box = PanelContainer.new()
	_letter_box.add_theme_stylebox_override("panel", UI.plate(Color("1a2c45"), Color("0a171c"), UI.GOLD, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 10))
	_letter_box.anchor_left = 0.5
	_letter_box.anchor_right = 0.5
	_letter_box.anchor_top = 0.3
	_letter_box.offset_left = -260
	_letter_box.offset_right = 260
	add_child(_letter_box)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 0)
	_letter_box.add_child(sheet)
	var head_band := PanelContainer.new()
	head_band.add_theme_stylebox_override("panel", UI.band(10.0))
	sheet.add_child(head_band)
	var head := _row(head_band, 10)
	head.add_child(_icon("diplomacy", 30))
	var heading := _text(UI.caps(letter[3]), 19, UI.BRIGHT, true)
	heading.add_theme_font_size_override("font_size", 19)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(heading)
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 18)
	sheet.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margins.add_child(column)
	var body := _text(letter[0], 16, UI.CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(470, 0)
	column.add_child(body)
	var buttons := _row(column, 10)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var strike: bool = letter[3]=="AUTHORIZE STRIKE"
	var answers: Array = letter[4] if letter.size() > 4 else []
	if answers.is_empty():
		answers = [["Cancel" if strike else "Decline", "bad", letter[2]], ["Authorize" if strike else "Accept", "good", letter[1]]]
	for answer in answers:
		var choice := [answer[0], answer[2], answer[1]]
		var b := Button.new()
		b.text = choice[0]
		b.custom_minimum_size = Vector2(120, 38)
		b.focus_mode = Control.FOCUS_NONE
		# Green for the agreeable answer, red for the grave one; anything else
		# keeps the ordinary plate.
		var tone: String = choice[2]
		if tone != "":
			var good: bool = tone == "good"
			b.add_theme_stylebox_override("normal", UI.plate(Color("27553a") if good else Color("5a2a24"), Color("122a1d") if good else Color("2a1210"), Color("6fae7a") if good else Color("b06a58"), 9.0))
			b.add_theme_stylebox_override("hover", UI.plate(Color("37724d") if good else Color("7a382f"), Color("1a3a28") if good else Color("3a1a16"), UI.BRIGHT, 9.0, Color(1, 1, 1, 0.18)))
		var action: Callable = choice[1]
		b.pressed.connect(func():
			action.call()
			_letter_box.queue_free()
			_letter_box = null
			refresh_diplomacy()
			_show_letter())
		buttons.add_child(b)

## Victory or defeat: the screen dims and a banner says how it ended.
func show_end(title: String, subtitle: String) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.plate(Color("1a343d"), Color("0a171b"), UI.GOLD if title == "VICTORY" else UI.BAD, 26.0, UI.LIFT, Color(0, 0, 0, 0), 0, 10))
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -120
	add_child(box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	box.add_child(column)
	var big := _text(title, 56, Color("f1e3b4") if title == "VICTORY" else UI.BAD, true)
	big.add_theme_font_size_override("font_size", 56)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(big)
	var small := _text(subtitle, 17, UI.TEXT)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(small)
	var buttons := _row(column, 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var menu := Button.new()
	menu.text = "Main menu"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func():
		world.get_tree().paused = false
		world.get_tree().reload_current_scene())
	buttons.add_child(menu)
	var stay := Button.new()
	stay.text = "Keep watching"
	stay.focus_mode = Control.FOCUS_NONE
	stay.pressed.connect(func():
		dim.queue_free()
		box.queue_free())
	buttons.add_child(stay)

## A short message as a card at the bottom of the screen; four at most.
func notice(text: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.plate(Color("1d3050", 0.96), Color("0b1523", 0.96), Color(UI.TRIM, 0.9), 9.0, UI.LIFT, UI.GOLD, 1, 5))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(264, 0)
	label.add_theme_color_override("font_color", UI.CREAM)
	card.add_child(label)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notices.add_child(card)
	while _notices.get_child_count() > 4:
		_notices.get_child(0).free()  # the oldest goes
	var tween := card.create_tween()
	tween.tween_interval(3.6)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(card.queue_free)

# ---------------------------------------------------------------- world market

func _market_panel() -> void:
	var m: Node = world.market
	var d: Node = world.diplomacy
	var deals := _card()
	var top := _row(deals)
	var title := _text("Instant deals", 16, UI.CREAM, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_segments(top, m.cfg.qty.map(func(q): return [str(int(q)), int(q)]), trade_qty, func(v): trade_qty = v)
	if not m.has_market():
		deals.add_child(_text("Build a Market to trade instantly. Prices move every 10 seconds.", 13, UI.BAD))
	for res in m.resources():
		var row := _row(deals, 8)
		row.add_child(_icon(res, 24))
		var name := _text(res.capitalize(), 14, UI.CREAM)
		name.custom_minimum_size = Vector2(70, 0)
		row.add_child(name)
		var up: bool = m.mult[res] > 1.03
		var down: bool = m.mult[res] < 0.97
		var price := _text("$%.1f %s" % [m.price(res), "▲" if up else ("▼" if down else "•")], 14, Color("8fd18a") if up else (Color("e8836f") if down else UI.TEXT))
		price.custom_minimum_size = Vector2(80, 0)
		row.add_child(price)
		var stock := _text("have %d" % int(economy.res.get(res, 0.0)), 13, UI.MUTED)
		stock.custom_minimum_size = Vector2(80, 0)
		stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(stock)
		_button(row, "Sell +$%d" % roundi(trade_qty * m.price(res) * float(m.cfg.instantSell)), m.sell.bind(res, trade_qty), m.has_market(), "good")
		_button(row, "Buy -$%d" % roundi(trade_qty * m.price(res) * float(m.cfg.instantBuy)), m.buy.bind(res, trade_qty), m.has_market())
	var routes := _card()
	var head := _row(routes)
	var rt := _text("Trade routes  %d/%d" % [m.routes.size(), m.route_cap()], 16, UI.CREAM, true)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rt)
	head.add_child(_text("ports %d · loss at sea %d%% · delivered %d · lost %d" % [m.ports(), roundi(m.risk() * 100), m.delivered, m.lost], 12, UI.MUTED))
	routes.add_child(_text("Ships carry %d-second voyages to nations you have a trade pact with. Each port has %d berths; warships lower losses." % [int(m.cfg.voyage), int(m.cfg.routesPerPort)], 12, UI.MUTED))
	for r in m.routes:
		var row := _row(routes, 8)
		row.add_child(_icon(r.res, 20))
		var l := _text("%s %d %s %s  ·  %s  ·  $%d so far" % ["Export" if r.dir == "export" else "Import", r.qty, "to" if r.dir == "export" else "from", d.name_of(r.nation), r.status, int(r.total)], 13, UI.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_button(row, "Close", m.close_route.bind(r.id), true, "bad")
	var partners := []
	for i in range(1, d.n):
		if d.pact[0][i] and not d.at_war(0, i) and not d.defeated(i):
			partners.append([d.name_of(i), i])
	if partners.is_empty():
		routes.add_child(_text("No partners yet: sign a trade pact in Diplomacy (G).", 13, UI.BAD))
		return
	if not partners.any(func(p): return p[1] == route_nation):
		route_nation = partners[0][1]
	var form := _row(routes, 6)
	_segments(form, [["Export", "export"], ["Import", "import"]], route_dir, func(v): route_dir = v)
	_choice(form, m.resources().map(func(r): return [r.capitalize(), r]), route_res, func(v): route_res = v)
	_choice(form, partners, route_nation, func(v): route_nation = v)
	_button(routes, "Open route (%d per voyage)" % trade_qty, func(): return m.open_route(route_nation, route_res, route_dir, trade_qty), m.ports() > 0, "good")

# ---------------------------------------------------------------- intelligence

func _intel_panel() -> void:
	var e: Node = world.espionage
	var d: Node = world.diplomacy
	var service := _card()
	var head := _row(service)
	var st := _text("Field agents", 16, UI.CREAM, true)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(st)
	_button(head, "Recruit ($%d)" % e.recruit_cost(), e.recruit, e.has_agency(), "good")
	if not e.has_agency():
		service.add_child(_text("Build an Intelligence Agency (Civic & research) to recruit agents. Rival services already work against you.", 13, UI.BAD))
	for a in e.agents:
		var row := _row(service, 8)
		var stars := "★".repeat(int(a.skill)) + "☆".repeat(5 - int(a.skill))
		var l := _text("%s  %s  %s  ·  %d ops" % [a.name, stars, e.rank(a), a.ops], 14, UI.CREAM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if a.status == "captured":
			_pill(row, "CAPTURED by %s" % d.name_of(int(a.captured_by)), Color("e0574a"))
			_button(row, "Ransom $%d" % int(e.cfg.ransom), e.ransom.bind(a.id))
		else:
			_pill(row, "READY", Color("6fc46a"))
	var nations := []
	for i in range(1, d.n):
		if not d.defeated(i):
			nations.append([d.name_of(i), i])
	if nations.is_empty():
		return
	if not nations.any(func(n): return n[1] == spy_target):
		spy_target = nations[0][1]
	var plan := _card(_nation_colour(spy_target))
	var ph := _row(plan)
	var pt := _text("Operation against", 16, UI.CREAM, true)
	ph.add_child(pt)
	_choice(ph, nations, spy_target, func(v):
		spy_target = v
		refresh_side())
	var agent_bonus := 0.0
	if not e.ready_agents().is_empty():
		agent_bonus = (int(e.ready_agents()[0].skill) - 1) * float(e.cfg.skillBonus)
	for key in e.ops():
		var op: Dictionary = e.ops()[key]
		var need := float(op.get("minNetwork", 0))
		var blocked: bool = e.network.get(spy_target, 0.0) < need
		var chance := clampf(e.success_chance(key, spy_target) + agent_bonus, 0.05, 0.97)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = key == spy_op
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 34)
		b.tooltip_text = op.desc
		b.pressed.connect(func():
			spy_op = key
			refresh_side())
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var n := _text(op.name, 14, UI.MUTED if blocked else UI.CREAM)
		n.custom_minimum_size = Vector2(150, 0)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(n)
		var c := _text("$%d" % int(op.cost), 13, UI.GOLD)
		c.custom_minimum_size = Vector2(56, 0)
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(c)
		var meter := VBoxContainer.new()
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.alignment = BoxContainer.ALIGNMENT_CENTER
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(meter)
		_meter(meter, chance, 1.0, Color("5fae63").lerp(Color("c0564a"), 1.0 - chance), ("needs network %d" % int(need)) if blocked else "%d%% chance" % roundi(chance * 100))
		plan.add_child(b)
	var op: Dictionary = e.ops()[spy_op]
	var needs_person: bool = op.get("needsPerson", false)
	if needs_person:
		var people := []
		for role in e.cfg.targets:
			people.append(["%s: %s" % [e.cfg.targets[role].label, e.person(spy_target, role)], role])
		var pr := _row(plan)
		pr.add_child(_text("Target", 14, UI.MUTED))
		_choice(pr, people, spy_role, func(v):
			spy_role = v
			refresh_side())
		plan.add_child(_text(e.cfg.targets[spy_role].effect, 12, UI.MUTED))
	var blocked_now: bool = e.network.get(spy_target, 0.0) < float(op.get("minNetwork", 0))
	_button(plan, "Run %s" % op.name, func(): return e.run(spy_op, spy_target, spy_role if needs_person else ""), e.has_agency() and not e.ready_agents().is_empty() and not blocked_now, "good")
	_heading("What your service knows")
	for n in nations:
		var id: int = n[1]
		var level: float = e.intel.get(id, 0.0)
		var card := _card(_nation_colour(id))
		card.add_child(_text(n[0], 15, _nation_colour(id).lightened(0.4), true))
		_meter(card, level, 100.0, Color("6fa6d8"), "Intelligence %d  ·  network %d  ·  heat %d" % [int(level), int(e.network.get(id, 0.0)), int(e.heat.get(id, 0.0))])
		var lines := []
		var nat = world.market.ai_nation(id)
		if level >= 10.0 and nat != null:
			lines.append("Treasury $%d, %d buildings" % [int(nat.money), world.buildings.filter(func(b): return b.owner == id and not b.dead).size()])
		if level >= 25.0:
			lines.append("Army about %d" % d.army_strength(id))
		if level >= 40.0:
			var ties := []
			for j in range(d.n):
				if j != id and d.at_war(id, j):
					ties.append("at war with " + ("you" if j == 0 else d.name_of(j)))
				elif j != id and d.allied(id, j):
					ties.append("allied with " + ("you" if j == 0 else d.name_of(j)))
			lines.append(", ".join(PackedStringArray(ties)) if not ties.is_empty() else "No wars or alliances")
		if level >= 60.0:
			lines.append("Their attacks on you are reported 30 s early")
		for tier in e.INTEL_TIERS:
			if level < tier[0]:
				lines.append("At %d: %s" % [tier[0], tier[1].to_lower()])
				break
		card.add_child(_text("\n".join(PackedStringArray(lines)), 13, UI.TEXT))
	if not e.reports.is_empty():
		_heading("Latest reports")
		for r in e.reports.slice(0, 4):
			_label(_side_rows, "•  " + r.text, UI.TEXT, 13)

# ---------------------------------------------------------------- territory

func pick_territory(text: String) -> void:
	territory_pick = text
	if side_mode == "territory":
		refresh_side()

func _territory_panel() -> void:
	var t: Node = world.territory
	var land: int = t.land_cells()
	_label(_side_rows, "Each nation's land is painted on the map in its colour; gold stripes mark contested fronts.", UI.MUTED, 13)
	for id in range(world.map.nations.size()):
		if world.diplomacy.defeated(id):
			continue
		var y: Dictionary = t.yields(id)
		var card := _card(_nation_colour(id))
		var row := _row(card)
		var name := _text("You" if id == 0 else world.diplomacy.name_of(id), 15, _nation_colour(id).lightened(0.4), true)
		name.custom_minimum_size = Vector2(170, 0)
		row.add_child(name)
		var share := float(y.cells) / maxf(land, 1)
		var meter := VBoxContainer.new()
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(meter)
		_meter(meter, share, 0.5, _nation_colour(id), "%d cells  ·  %d%% of the land" % [y.cells, roundi(share * 100)])
		if y.contested > 0:
			_pill(row, "%d contested" % y.contested, Color("d8b866"))
	var pick := _card(UI.GOLD)
	pick.add_child(_text("Selected land", 14, GOLD, true))
	var pl := _text(territory_pick, 14, UI.CREAM)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pl.custom_minimum_size = Vector2(480, 0)
	pick.add_child(pl)
	var mine: Dictionary = t.yields(0)
	var yields := _row(_side_rows, 14)
	yields.add_child(_text("Your land yields per second:", 13, UI.MUTED))
	for item in [["money", "%.2f" % mine.money], ["food", "%.2f" % mine.food], ["iron", "%.3f" % mine.iron]]:
		yields.add_child(_icon(item[0], 18))
		yields.add_child(_text(item[1], 13, UI.CREAM))

# ---------------------------------------------------------------- research screen

var _rs: PanelContainer
var _rs_head: Label
var _rs_era: Label
var _tree: Control
var _rs_detail: VBoxContainer
var _rs_queue: VBoxContainer
var _rs_tracks: HBoxContainer
var _rs_sel := ""
var _rs_sig := ""
var _rs_live: Array = []   # [Control, callable] refreshed every second without rebuilding

func toggle_research() -> void:
	if _rs == null:
		_build_research()
		_rs.visible = false
	_rs.visible = not _rs.visible
	if _rs.visible:
		_show_side("")
		_rs_sig = ""
		_tree.layout()
		_refresh_research()

func _build_research() -> void:
	_rs = _box(Vector2.ZERO)
	_rs.anchor_right = 1.0
	_rs.anchor_bottom = 1.0
	_rs.offset_left = 16
	_rs.offset_right = -16
	_rs.offset_top = 56
	_rs.offset_bottom = -16
	# Opaque: a screen of its own, not an overlay on the battle.
	_rs.add_theme_stylebox_override("panel", UI.plate(Color("19343b"), Color("070d17"), UI.TRIM, 0.0, UI.LIFT, Color(0, 0, 0, 0), 0, 9))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_rs.add_child(column)
	var head_band := PanelContainer.new()
	head_band.add_theme_stylebox_override("panel", UI.band(9.0))
	column.add_child(head_band)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	head_band.add_child(top)
	top.add_child(_icon("research", 28))
	_rs_head = Label.new()
	_rs_head.theme_type_variation = "HeaderLabel"
	_rs_head.add_theme_font_size_override("font_size", 18)
	_rs_head.add_theme_color_override("font_color", UI.BRIGHT)
	_rs_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rs_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_rs_head)
	var close := Button.new()
	close.text = "Close (Y)"
	close.pressed.connect(toggle_research)
	top.add_child(close)
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 12)
	column.add_child(body)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	body.add_child(column)
	_rs_era = Label.new()
	_rs_era.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rs_era.custom_minimum_size = Vector2(1000, 0)  # a width to wrap at before the first layout
	_rs_era.add_theme_color_override("font_color", Color("c9d2d6"))
	column.add_child(_rs_era)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	_tree = preload("res://scripts/research_tree.gd").new()
	_tree.setup(world.research)
	_tree.picked.connect(func(key):
		_rs_sel = key
		_rs_sig = ""
		_refresh_research())
	scroll.add_child(_tree)
	var side := ScrollContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(side)
	var side_col := VBoxContainer.new()
	side_col.custom_minimum_size = Vector2(344, 0)
	side.add_child(side_col)
	_rs_detail = VBoxContainer.new()
	side_col.add_child(_rs_detail)
	_rs_queue = VBoxContainer.new()
	side_col.add_child(_rs_queue)
	_rs_tracks = HBoxContainer.new()
	column.add_child(_rs_tracks)
	world.research.changed.connect(func(): if _rs.visible: _refresh_research())

func _rs_label(parent: Control, text: String, colour := Color("b9c4c8"), size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _refresh_research() -> void:
	var r: Node = world.research
	_rs_head.text = "RESEARCH   %d points  (+%.2f/s)   %s   %d/%d discoveries" % [int(r.points), r.rate, r.eras[r.era].name, r.completed_count(), r.discoveries.size()]
	if r.era + 1 < r.eras.size():
		var nxt: Dictionary = r.eras[r.era + 1]
		var parts := PackedStringArray()
		for q in r.era_requirements(r.era + 1):
			var pct: bool = q[0] == "Share of the land"
			parts.append("%s %s %s/%s" % ["[x]" if q[1] >= q[2] else "[ ]", q[0], ("%d%%" % roundi(q[1] * 100)) if pct else str(int(q[1])), ("%d%%" % roundi(q[2] * 100)) if pct else str(int(q[2]))])
		_rs_era.text = "Next: the %s (%s). %s   Reward: $%d and %d research." % [nxt.name, nxt.desc, "   ".join(parts), int(nxt.reward.get("money", 0)), int(nxt.reward.get("research", 0))]
	else:
		_rs_era.text = "Your nation has reached the final era."
	_tree.queue_redraw()
	var sig := "%s|%s|%s|%d|%s" % [_rs_sel, str(r.queue), str(r.tracks), r.era, "" if _rs_sel == "" else "%d:%s" % [r.stage_of(_rs_sel), r.blocker(_rs_sel)]]
	if sig == _rs_sig:
		for live in _rs_live:
			live[1].call(live[0])
		return
	_rs_sig = sig
	_rs_live.clear()
	for box in [_rs_detail, _rs_queue, _rs_tracks]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_research_detail()
	_research_queue()
	_research_tracks()

func _research_detail() -> void:
	var r: Node = world.research
	if _rs_sel == "":
		_rs_label(_rs_detail, "Pick a discovery in the tree. Each one is developed in three stages; points from schools, libraries, universities and tech parks flow into the project at the head of the queue.")
		return
	var key := _rs_sel
	var def: Dictionary = r.def_of(key)
	_rs_label(_rs_detail, def.name.to_upper(), Color("f1e3b4"), 18)
	_rs_label(_rs_detail, "%s  ·  %s  ·  %d research" % [r.BRANCH_NAMES[def.branch], r.eras[r.era_of(key)].name, int(def.cost)], Color("9fb3a2"))
	_rs_label(_rs_detail, r.desc_of(key), Color("dfe6e8"))
	var needs := PackedStringArray()
	if def.get("reqDiscovery") != null:
		needs.append("%s %s" % ["[x]" if r.done(def.reqDiscovery) else "[ ]", r.def_of(def.reqDiscovery).name])
	if def.get("reqBuilding") != null:
		needs.append("%s %s (for the %s)" % ["[x]" if world.economy.owned(def.reqBuilding) > 0 else "[ ]", world.building_defs.get(def.reqBuilding, {"name": def.reqBuilding}).name, r.stage_names(key)[1].to_lower()])
	if not needs.is_empty():
		_rs_label(_rs_detail, "Requires: " + ", ".join(needs))
	var stage: int = r.stage_of(key)
	for s in range(3):
		var cost: Dictionary = r.stage_cost(key, s)
		var mark := "done" if s < stage else ("in development" if s == stage else "")
		_rs_label(_rs_detail, "%d. %s — %d research%s%s" % [s + 1, r.stage_names(key)[s], int(r.stage_points(key, s)), "" if cost.is_empty() else " + " + cost_text(cost), "   (%s)" % mark if mark != "" else ""],
			Color("8fd18a") if s < stage else (Color("e3c15a") if s == stage else Color("b9c4c8")))
		if s == stage:
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(330, 10)
			bar.show_percentage = false
			bar.max_value = r.stage_points(key, s)
			bar.value = r.progress[key].work
			_rs_detail.add_child(bar)
			_rs_live.append([bar, func(b): b.value = world.research.progress[key].work])
	_rs_label(_rs_detail, "A finished prototype (stage 2) gives half the effect; the last stage all of it and any unlocks.", Color("8a979c"), 12)
	if stage < 3:
		var row := HBoxContainer.new()
		_rs_detail.add_child(row)
		var b := Button.new()
		if key in r.queue:
			b.text = "Remove from queue"
			b.pressed.connect(func(): r.dequeue(key))
		else:
			b.text = "Research" if r.queue.is_empty() else "Add to queue"
			var why: String = r.blocker(key)
			b.disabled = why != "" and not why.contains(" needs a ")
			b.tooltip_text = why
			b.pressed.connect(func(): _say(r.enqueue(key)))
		row.add_child(b)
		if key in r.queue and r.queue[0] != key:
			var front := Button.new()
			front.text = "Do this first"
			front.pressed.connect(func():
				r.queue.erase(key)
				r.queue.push_front(key)
				r.changed.emit())
			row.add_child(front)

func _research_queue() -> void:
	var r: Node = world.research
	_rs_label(_rs_queue, "QUEUE (%d/%d)" % [r.queue.size(), r.QUEUE_MAX], Color("f1e3b4"), 16)
	if r.queue.is_empty():
		_rs_label(_rs_queue, "Nothing in development: research points are piling up.", Color("e8a86f"))
	for item in r.queue:
		var row := HBoxContainer.new()
		_rs_queue.add_child(row)
		var name: String = r.tracks_cfg[item.substr(6)].name if item.begins_with("track:") else r.def_of(item).name
		var l := _rs_label(row, "%s — %s" % [name, r.status_of(item)], Color("dfe6e8"))
		l.custom_minimum_size = Vector2(290, 0)
		_rs_live.append([l, func(label): label.text = "%s — %s" % [name, world.research.status_of(item)]])
		var x := Button.new()
		x.text = "x"
		x.pressed.connect(func(): r.dequeue(item))
		row.add_child(x)

func _research_tracks() -> void:
	var r: Node = world.research
	for key in r.tracks_cfg:
		var t: Dictionary = r.tracks_cfg[key]
		var b := Button.new()
		var level: int = r.tracks[key]
		var why: String = r.track_blocker(key)
		b.text = "%s %d/%d\n%s" % [t.name, level, int(t.max), "Maxed" if why == "Maxed" else ("Level %d: %d research" % [level + 1, int(r.track_cost(key))] if why == "" else why)]
		b.tooltip_text = t.desc
		b.disabled = why != "" or ("track:" + key) in r.queue
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(250, 44)
		b.pressed.connect(func(): _say(r.enqueue("track:" + key)))
		_rs_tracks.add_child(b)
