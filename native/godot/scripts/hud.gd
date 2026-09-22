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
	_notices = VBoxContainer.new()
	_notices.anchor_left = 0.5
	_notices.anchor_right = 0.5
	_notices.offset_left = -280
	_notices.offset_right = 280
	_notices.offset_top = 58
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

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var style := UI.box(Color(UI.BG, 0.96), UI.TRIM, 0, 0, 6.0, 8)
	style.border_width_bottom = 2
	style.content_margin_left = 14
	style.content_margin_right = 10
	bar.add_theme_stylebox_override("panel", style)
	bar.anchor_right = 1.0
	bar.offset_bottom = 46
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	bar.add_child(row)
	for r in RESOURCES:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 5)
		chip.tooltip_text = r[2]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(_icon(r[1], 26))
		var value := _text("0", 17, UI.CREAM)
		chip.add_child(value)
		var rate := _text("+0", 13, UI.GOOD)
		chip.add_child(rate)
		row.add_child(chip)
		_chips[r[0]] = [value, rate, chip]
	for extra in [["army", "army", "Army size against housing capacity. Build Housing Blocks for more."],
			["citizens", "citizens", "Citizens against the housing they can grow into. Happiness and health speed growth."],
			["research", "research", "Research points and their rate. Press Y for the research tree."],
			["land", "land", "Land held: territory cells. Press T for borders."],
			["missiles", "missile", "Missiles stored against Ammo Depot capacity."]]:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 5)
		chip.tooltip_text = extra[2]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(_icon(extra[1], 24))
		var value := _text("", 16, UI.CREAM)
		chip.add_child(value)
		row.add_child(chip)
		_extra[extra[0]] = [value, chip]
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_era = _text("", 15, GOLD, true)
	row.add_child(_era)
	# The screens, as in Civilization: a row of icon buttons under the top bar.
	var screens := HBoxContainer.new()
	screens.add_theme_constant_override("separation", 6)
	screens.offset_left = 12
	screens.offset_top = 54
	add_child(screens)
	row = screens
	for b in [["research", "Research (Y)", func(): toggle_research()], ["diplomacy", "Diplomacy (G)", func(): toggle_diplomacy()],
			["market", "World market (M)", func(): toggle_panel("market")], ["intel", "Intelligence (I)", func(): toggle_panel("intel")],
			["land", "Territory (T)", func(): toggle_panel("territory")], ["menu", "Menu (Esc)", func(): world.menu.open_pause() if world.menu and world.menu._root != null else null]]:
		var button := Button.new()
		button.icon = UI.icon(b[0])
		button.expand_icon = true
		button.custom_minimum_size = Vector2(46, 42)
		button.add_theme_stylebox_override("normal", UI.box(Color(UI.BG, 0.92), UI.TRIM, 1, 21, 6.0, 6))
		button.add_theme_stylebox_override("hover", UI.box(Color("233841"), GOLD, 2, 21, 6.0, 6))
		button.add_theme_stylebox_override("pressed", UI.box(Color("2c2a1d"), GOLD, 2, 21, 6.0, 6))
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
	add_child(_prod)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_prod.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_prod_title = _text("BUILD", 19, UI.CREAM, true)
	_prod_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_prod_title)
	var hide := Button.new()
	hide.text = "—"
	hide.tooltip_text = "Hide the production list (the Build button brings it back)"
	hide.focus_mode = Control.FOCUS_NONE
	hide.pressed.connect(func(): set_production_open(false))
	head.add_child(hide)
	_prod_hint = _text("", 13, UI.MUTED)
	_prod_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prod_hint.custom_minimum_size = Vector2(RIGHT_W - 24, 0)
	column.add_child(_prod_hint)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	column.add_child(_tabs)
	for tab in BUILD_MENU:
		var t := Button.new()
		t.text = tab
		t.toggle_mode = true
		t.button_pressed = tab == build_tab
		t.focus_mode = Control.FOCUS_NONE
		t.add_theme_font_size_override("font_size", 13)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(func():
			build_tab = tab
			for other in _tabs.get_children():
				other.button_pressed = other.text == tab
			_shown_key = ""
			_update_panel())
		_tabs.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
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

func _section(title: String) -> void:
	var l := _text(title.to_upper(), 13, GOLD, true)
	l.add_theme_font_size_override("font_size", 13)
	_list.add_child(l)

## One production bar: picture, name, one line of what it does, cost chips,
## time. Disabled (dimmed) when it cannot be afforded or is locked.
func _bar(key: String, title: String, desc: String, cost: Dictionary, seconds: float, locked: String, action: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(RIGHT_W - 28, 70)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = desc if locked == "" else "%s\n%s" % [locked, desc]
	b.set_meta("cost", cost)
	b.set_meta("locked", locked != "")
	b.pressed.connect(action)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -8
	row.offset_top = 4
	row.offset_bottom = -4
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(80, 60)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_portrait(pic, key)
	row.add_child(pic)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name := _text(title, 15, UI.CREAM, true)
	name.add_theme_font_size_override("font_size", 15)
	text.add_child(name)
	var line := _text(locked if locked != "" else desc, 12, UI.BAD if locked != "" else UI.MUTED)
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.custom_minimum_size = Vector2(200, 0)
	line.clip_text = true
	text.add_child(line)
	text.add_child(_cost_row(cost))
	if seconds > 0.0:
		var time := _text("%ds" % int(seconds), 13, UI.MUTED)
		time.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		row.add_child(time)
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
	_sel.offset_top = -214
	_sel.offset_bottom = -12
	add_child(_sel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_sel.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color("0a1418"), UI.TRIM, 1, 6, 2.0))
	row.add_child(frame)
	_sel_pic = TextureRect.new()
	_sel_pic.custom_minimum_size = Vector2(224, 168)
	_sel_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sel_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_sel_pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_sel_title = _text("", 20, UI.CREAM, true)
	col.add_child(_sel_title)
	_sel_sub = _text("", 13, GOLD)
	col.add_child(_sel_sub)
	_sel_hp = ProgressBar.new()
	_sel_hp.custom_minimum_size = Vector2(0, 14)
	_sel_hp.show_percentage = false
	col.add_child(_sel_hp)
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
	frame.add_theme_stylebox_override("panel", UI.box(Color(UI.BG, 0.96), UI.TRIM, 1, 6, 5.0, 8))
	add_child(frame)
	var map := preload("res://scripts/minimap.gd").new()
	map.custom_minimum_size = Vector2(MINI, MINI)
	frame.add_child(map)
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
	add_child(_help)
	var col := VBoxContainer.new()
	_help.add_child(col)
	col.add_child(_text("CONTROLS", 20, UI.CREAM, true))
	for line in [["Move the camera", "W A S D or the arrow keys, the screen edge, or drag with the middle mouse button"],
			["Turn / tilt / zoom", "Q E  ·  R F  ·  mouse wheel (zooms toward the cursor)"],
			["Select", "Click a unit or building, or drag a box around units"],
			["Orders", "Right click: move or attack  ·  Ctrl + right click: attack-move"],
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
		_era.text = world.research.eras[world.research.era].name.to_upper()
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
		_prod_title.text = "BUILD"
		_prod_hint.text = "Pick a building, then click a hex inside your city. Workers go and build it. Shift keeps placing; right click cancels."
		_tabs.visible = true
		_building_bars()
	else:
		_prod_title.text = _selected.def.name.to_upper()
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
	if transport_text != "":
		_sel.visible = true
		_sel_title.text = "ROAD" if world.transport_kind == "road" else "RAILWAY"
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
		_sel_title.text = b.def.name
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
		var name: String = world.unit_defs.get(main, {}).get("name", main)
		_sel_title.text = name if units.size() == 1 else "%d units" % units.size()
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
		return
	_sel.visible = false

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

# ---------------------------------------------------------------- diplomacy

var _diplo: PanelContainer
var _diplo_rows: VBoxContainer
var _letters: Array = []     # pending [text, accept, decline]
var _letter_box: PanelContainer

func _build_diplomacy_panel() -> void:
	_diplo = _box(Vector2.ZERO)
	# Left side, below the info panel: clear of notices and letters.
	_diplo.offset_left = 16
	_diplo.offset_right = 640
	_diplo.offset_top = 106
	_diplo.visible = false
	_diplo_rows = VBoxContainer.new()
	_diplo.add_child(_diplo_rows)

func toggle_diplomacy() -> void:
	_diplo.visible = not _diplo.visible
	if _diplo.visible:
		_show_side("")
		refresh_diplomacy()

func refresh_diplomacy() -> void:
	if _diplo == null or not _diplo.visible or world.diplomacy == null:
		return
	for child in _diplo_rows.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "DIPLOMACY"
	title.add_theme_font_size_override("font_size", 18)
	_diplo_rows.add_child(title)
	var d: Node = world.diplomacy
	for id in range(1, d.n):
		var row := VBoxContainer.new()
		var head := Label.new()
		var score: float = d.rel(0, id)
		head.text = "%s   relation %+d   %s   army %d" % [d.name_of(id), int(score), d.status_text(id), d.army_strength(id)]
		head.add_theme_color_override("font_color", Color(world.map.nations[id].color).lerp(Color.WHITE, 0.45))
		row.add_child(head)
		if not d.defeated(id):
			var buttons := HBoxContainer.new()
			if d.at_war(0, id):
				_diplo_button(buttons, "Offer peace", d.offer_peace.bind(id))
			else:
				_diplo_button(buttons, "Gift $250", d.gift.bind(id))
				if not d.pact[0][id]:
					_diplo_button(buttons, "Trade pact", d.propose_pact.bind(id))
				if not d.nap[0][id]:
					_diplo_button(buttons, "Non-aggression", d.propose_nap.bind(id))
				if not d.allied(0, id):
					_diplo_button(buttons, "Alliance", d.propose_alliance.bind(id))
				_diplo_button(buttons, "Declare war", _declare.bind(id))
			if d.allied(0, id):
				for enemy in range(1, d.n):
					if d.at_war(0, enemy) and not d.at_war(id, enemy):
						_diplo_button(buttons, "Call to war vs %s" % d.name_of(enemy).split(" ")[0], d.request_joint_war.bind(id, enemy))
			row.add_child(buttons)
		_diplo_rows.add_child(row)

func _declare(id: int) -> String:
	world.diplomacy.declare_war(0, id)
	return ""

func _diplo_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		var message: String = action.call()
		if message != "":
			notice(message)
		refresh_diplomacy())
	parent.add_child(b)

## A foreign government's proposal with Accept / Decline buttons.
func ask(text: String, accept: Callable, decline: Callable) -> void:
	_letters.append([text, accept, decline])
	if _letter_box == null:
		_show_letter()

func _show_letter() -> void:
	if _letters.is_empty():
		return
	var letter: Array = _letters.pop_front()
	_letter_box = _box(Vector2.ZERO)
	_letter_box.anchor_left = 0.5
	_letter_box.anchor_right = 0.5
	_letter_box.anchor_top = 0.5
	_letter_box.anchor_bottom = 0.5
	_letter_box.offset_left = -40  # right of centre, clear of the diplomacy panel
	_letter_box.offset_right = 480
	_letter_box.offset_top = -150
	var column := VBoxContainer.new()
	_letter_box.add_child(column)
	var heading := Label.new()
	heading.text = "FOREIGN OFFICE"
	heading.add_theme_color_override("font_color", GOLD)
	column.add_child(heading)
	var body := Label.new()
	body.text = letter[0]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(480, 0)
	column.add_child(body)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for choice in [["Accept", letter[1]], ["Decline", letter[2]]]:
		var b := Button.new()
		b.text = choice[0]
		var action: Callable = choice[1]
		b.pressed.connect(func():
			action.call()
			_letter_box.queue_free()
			_letter_box = null
			refresh_diplomacy()
			_show_letter())
		buttons.add_child(b)

## Victory or defeat: a large banner across the middle of the screen.
func show_end(title: String, subtitle: String) -> void:
	var box := _box(Vector2.ZERO)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -260
	box.offset_right = 260
	box.offset_top = -70
	box.offset_bottom = 70
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(column)
	var big := Label.new()
	big.text = title
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 44)
	big.add_theme_color_override("font_color", Color("f1e3b4") if title == "VICTORY" else Color("e8836f"))
	column.add_child(big)
	var small := Label.new()
	small.text = subtitle
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(small)

func notice(text: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color(UI.BG, 0.9), Color(UI.TRIM, 0.8), 1, 6, 8.0, 6))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(520, 0)
	label.add_theme_color_override("font_color", UI.CREAM)
	card.add_child(label)
	_notices.add_child(card)
	while _notices.get_child_count() > 4:
		_notices.get_child(0).free()  # at most four at once; the oldest goes
	var tween := card.create_tween()
	tween.tween_interval(3.4)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(card.queue_free)

# ---------------------------------------------------------------- market, intel and territory panels

var _side: PanelContainer
var _side_rows: VBoxContainer
var _scroll: ScrollContainer
var side_mode := ""          # "", "market", "intel" or "territory"
var _hooked := false
# Choices kept across rebuilds of the panels.
var trade_qty := 25
var route_nation := -1
var route_res := "oil"
var route_dir := "export"
var spy_target := 1
var spy_op := "buildNetwork"
var spy_role := "president"

## Shows a message unless it is empty.
func _say(message: String) -> void:
	if message != "":
		notice(message)

func toggle_panel(mode: String, force_open := false) -> void:
	_show_side("" if side_mode == mode and not force_open else mode)

func _show_side(mode: String) -> void:
	if _side == null:
		_side = _box(Vector2.ZERO)
		_side.offset_left = 16
		_side.offset_right = 700
		_side.offset_top = 106
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_side.add_child(_scroll)
		_side_rows = VBoxContainer.new()
		_scroll.add_child(_side_rows)
	# Between the info panel and the command panel, scrolling when longer.
	_scroll.custom_minimum_size = Vector2(676, maxf(160.0, get_viewport().get_visible_rect().size.y - 106.0 - 250.0))
	if not _hooked and world.market != null:
		_hooked = true
		world.market.changed.connect(func(): if side_mode == "market": refresh_side())
		world.espionage.changed.connect(func(): if side_mode == "intel": refresh_side())
		world.territory.changed.connect(func(): if side_mode == "territory": refresh_side())
	side_mode = mode
	_side.visible = mode != ""
	if mode != "":
		_diplo.visible = false
		if _rs != null:
			_rs.visible = false
	if world.territory:
		world.territory.set_visible_borders(mode == "territory")
	refresh_side()

func refresh_side() -> void:
	if _side == null or side_mode == "":
		return
	for child in _side_rows.get_children():
		_side_rows.remove_child(child)
		child.queue_free()
	match side_mode:
		"market":
			_market_panel()
		"intel":
			_intel_panel()
		"territory":
			_territory_panel()

func _label(parent: Control, text: String, colour := Color("b9c4c8"), size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(660, 0)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _heading(text: String) -> void:
	_label(_side_rows, text, Color("f1e3b4"), 18)

func _button(parent: Control, text: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(func():
		_say(action.call())
		refresh_side())
	parent.add_child(b)
	return b

## A drop-down of [[label, value], ...]; on_pick receives the value.
func _choice(parent: Control, items: Array, selected, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	for i in range(items.size()):
		o.add_item(items[i][0], i)
		if items[i][1] == selected:
			o.select(i)
	o.item_selected.connect(func(i): on_pick.call(items[i][1]))
	parent.add_child(o)
	return o

func _market_panel() -> void:
	var m: Node = world.market
	var d: Node = world.diplomacy
	_heading("WORLD MARKET")
	if m.has_market():
		_label(_side_rows, "Instant deals: sell at %d%%, buy at %d%% of the price. Prices move every 10 seconds." % [roundi(float(m.cfg.instantSell) * 100), roundi(float(m.cfg.instantBuy) * 100)])
	else:
		_label(_side_rows, "Build a Market to buy and sell instantly. Prices move every 10 seconds.", Color("e8a86f"))
	var qty_row := HBoxContainer.new()
	_side_rows.add_child(qty_row)
	_label(qty_row, "Quantity").custom_minimum_size = Vector2(80, 0)
	_choice(qty_row, m.cfg.qty.map(func(q): return [str(int(q)), int(q)]), trade_qty, func(v):
		trade_qty = v
		refresh_side())
	for res in m.resources():
		var row := HBoxContainer.new()
		_side_rows.add_child(row)
		var trend := "up" if m.mult[res] > 1.05 else ("down" if m.mult[res] < 0.95 else "steady")
		_label(row, "%s  $%.1f (%s)  stock %d" % [res.capitalize(), m.price(res), trend, int(economy.res.get(res, 0.0))], Color("dfe6e8")).custom_minimum_size = Vector2(300, 0)
		_button(row, "Sell %d (+$%d)" % [trade_qty, roundi(trade_qty * m.price(res) * float(m.cfg.instantSell))], m.sell.bind(res, trade_qty), m.has_market())
		_button(row, "Buy %d (-$%d)" % [trade_qty, roundi(trade_qty * m.price(res) * float(m.cfg.instantBuy))], m.buy.bind(res, trade_qty), m.has_market())
	_heading("TRADE ROUTES  %d/%d" % [m.routes.size(), m.route_cap()])
	_label(_side_rows, "Ports: %d (%d berths each). Contracts come from trade pacts and up to two Markets. Cargo sails %d s and is lost at sea %d%% of the time; armed warships lower it. Delivered %d, lost %d." % [m.ports(), int(m.cfg.routesPerPort), int(m.cfg.voyage), roundi(m.risk() * 100), m.delivered, m.lost])
	for r in m.routes:
		var row := HBoxContainer.new()
		_side_rows.add_child(row)
		_label(row, "%s %d %s %s %s — %s (total $%d)" % ["Export" if r.dir == "export" else "Import", r.qty, r.res, "to" if r.dir == "export" else "from", d.name_of(r.nation), r.status, int(r.total)], Color("dfe6e8")).custom_minimum_size = Vector2(540, 0)
		_button(row, "Close", m.close_route.bind(r.id))
	var partners := []
	for i in range(1, d.n):
		if d.pact[0][i] and not d.at_war(0, i) and not d.defeated(i):
			partners.append([d.name_of(i), i])
	if partners.is_empty():
		_label(_side_rows, "No trade partners: sign a trade pact in Diplomacy (G) first.", Color("e8a86f"))
		return
	if not partners.any(func(p): return p[1] == route_nation):
		route_nation = partners[0][1]
	var row := HBoxContainer.new()
	_side_rows.add_child(row)
	_choice(row, [["Export", "export"], ["Import", "import"]], route_dir, func(v): route_dir = v)
	_choice(row, m.resources().map(func(r): return [r.capitalize(), r]), route_res, func(v): route_res = v)
	_choice(row, partners, route_nation, func(v): route_nation = v)
	_button(row, "Open route (%d per voyage)" % trade_qty, func(): return m.open_route(route_nation, route_res, route_dir, trade_qty), m.ports() > 0)

func _intel_panel() -> void:
	var e: Node = world.espionage
	var d: Node = world.diplomacy
	_heading("INTELLIGENCE")
	if not e.has_agency():
		_label(_side_rows, "Build an Intelligence Agency to recruit agents and run covert operations. Hostile services already work against you.", Color("e8a86f"))
	var top := HBoxContainer.new()
	_side_rows.add_child(top)
	_button(top, "Recruit agent ($%d)" % e.recruit_cost(), e.recruit, e.has_agency())
	for a in e.agents:
		var row := HBoxContainer.new()
		_side_rows.add_child(row)
		var where: String = a.status if a.status != "captured" else "captured by %s" % d.name_of(int(a.captured_by))
		_label(row, "%s — %s (skill %d, %d ops) — %s" % [a.name, e.rank(a), a.skill, a.ops, where], Color("dfe6e8") if a.status == "ready" else Color("e8836f")).custom_minimum_size = Vector2(500, 0)
		if a.status == "captured":
			_button(row, "Ransom $%d" % int(e.cfg.ransom), e.ransom.bind(a.id))
	var nations := []
	for i in range(1, d.n):
		if not d.defeated(i):
			nations.append([d.name_of(i), i])
	if nations.is_empty():
		return
	if not nations.any(func(n): return n[1] == spy_target):
		spy_target = nations[0][1]
	_heading("OPERATION")
	var row := HBoxContainer.new()
	_side_rows.add_child(row)
	_choice(row, nations, spy_target, func(v):
		spy_target = v
		refresh_side())
	var ops := []
	for key in e.ops():
		ops.append(["%s ($%d)" % [e.ops()[key].name, int(e.ops()[key].cost)], key])
	_choice(row, ops, spy_op, func(v):
		spy_op = v
		refresh_side())
	var op: Dictionary = e.ops()[spy_op]
	var needs_person: bool = op.get("needsPerson", false)
	if needs_person:
		var people := []
		for role in e.cfg.targets:
			people.append(["%s: %s" % [e.cfg.targets[role].label, e.person(spy_target, role)], role])
		_choice(row, people, spy_role, func(v):
			spy_role = v
			refresh_side())
	var agent_bonus := 0.0
	if not e.ready_agents().is_empty():
		agent_bonus = (int(e.ready_agents()[0].skill) - 1) * float(e.cfg.skillBonus)
	var chance := clampf(e.success_chance(spy_op, spy_target) + agent_bonus, 0.05, 0.97)
	var need := float(op.get("minNetwork", 0))
	var blocked: bool = e.network.get(spy_target, 0.0) < need
	var info: String = op.desc + (" " + e.cfg.targets[spy_role].effect if needs_person else "")
	_label(_side_rows, "%s\nChance of success %d%%%s." % [info, roundi(chance * 100), (" — needs network %d" % int(need)) if blocked else ""])
	_button(_side_rows, "Run operation", func(): return e.run(spy_op, spy_target, spy_role if needs_person else ""), e.has_agency() and not e.ready_agents().is_empty() and not blocked)
	_heading("DOSSIERS")
	for n in nations:
		var id: int = n[1]
		var level: float = e.intel.get(id, 0.0)
		var lines := ["%s — intel %d, network %d, heat %d" % [n[0], int(level), int(e.network.get(id, 0.0)), int(e.heat.get(id, 0.0))]]
		var nat = world.market.ai_nation(id)
		if level >= 10.0 and nat != null:
			lines.append("  Treasury $%d, %d buildings" % [int(nat.money), world.buildings.filter(func(b): return b.owner == id and not b.dead).size()])
		if level >= 25.0:
			lines.append("  Army about %d" % d.army_strength(id))
		if level >= 40.0:
			var ties := []
			for j in range(d.n):
				if j != id and d.at_war(id, j):
					ties.append("at war with " + ("you" if j == 0 else d.name_of(j)))
				elif j != id and d.allied(id, j):
					ties.append("allied with " + ("you" if j == 0 else d.name_of(j)))
			lines.append("  " + (", ".join(PackedStringArray(ties)) if not ties.is_empty() else "no wars or alliances"))
		if level >= 60.0:
			lines.append("  Their attacks on you are reported 30 s early")
		for tier in e.INTEL_TIERS:
			if level < tier[0]:
				lines.append("  At intel %d: %s" % [tier[0], tier[1].to_lower()])
				break
		_label(_side_rows, "\n".join(PackedStringArray(lines)), Color(world.map.nations[id].color).lerp(Color.WHITE, 0.5))
	if not e.reports.is_empty():
		_heading("LATEST REPORTS")
		for r in e.reports.slice(0, 4):
			_label(_side_rows, r.text)

func _territory_panel() -> void:
	var t: Node = world.territory
	var land: int = t.land_cells()
	_heading("TERRITORY")
	_label(_side_rows, "Buildings project control; armed units occupy the cell they stand in. Land changes hands only once its control is worn down. Borders show on the map while this panel is open (gold = contested). Front cells: %d." % t.fronts)
	for id in range(world.map.nations.size()):
		if world.diplomacy.defeated(id):
			continue
		var y: Dictionary = t.yields(id)
		_label(_side_rows, "%s — %d cells (%d%% of the land): %d sovereign, %d integrated, %d occupied, %d contested" % ["You" if id == 0 else world.diplomacy.name_of(id), y.cells, roundi(100.0 * y.cells / maxf(land, 1)), y.sovereign, y.integrated, y.occupied, y.contested],
			Color(world.map.nations[id].color).lerp(Color.WHITE, 0.45))
	var mine: Dictionary = t.yields(0)
	_label(_side_rows, "Your land yields +$%.2f, +%.2f food and +%.3f iron per second (plains feed, forests and coasts pay, mountains give iron)." % [mine.money, mine.food, mine.iron], Color("dfe6e8"))

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
		_diplo.visible = false
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
	var solid: StyleBoxFlat = _rs.get_theme_stylebox("panel").duplicate()
	solid.bg_color = Color("0e191e")  # opaque: a screen of its own, not an overlay on the battle
	_rs.add_theme_stylebox_override("panel", solid)
	var column := VBoxContainer.new()
	_rs.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_rs_head = Label.new()
	_rs_head.add_theme_font_size_override("font_size", 18)
	_rs_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_rs_head)
	var close := Button.new()
	close.text = "Close (Y)"
	close.pressed.connect(toggle_research)
	top.add_child(close)
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
