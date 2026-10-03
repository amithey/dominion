extends Control
## The Cabinet (Tab, or the Cabinet button): the whole state at a glance, as a
## head of government sees it at the morning briefing. Each ministry has a
## large tile in its own colour (ui_theme.gd MINISTRY): the Treasury, the
## People, the Armed Forces, Research, Foreign Affairs, Territory,
## Intelligence and the National Power. A tile's button opens its ministry.
## Figures refresh every half second while the Cabinet is open.

const UI := preload("res://scripts/ui_theme.gd")
const Gallery := preload("res://scripts/leader_gallery.gd")
const Factions := preload("res://scripts/factions.gd")
var hud: Node
var world: Node
var _grid: GridContainer
var _head: HBoxContainer
var _refresh := 0.0

## A small chart of a figure over the last minutes (hud.history), in a ministry's colour.
class Sparkline extends Control:
	var points: Array = []
	var colour := Color.WHITE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("0a1522"))
		if points.size() < 2:
			draw_string(ThemeDB.fallback_font, Vector2(8, h * 0.6), "Charting… a point every 5 s", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.4))
			return
		var lo: float = points.min()
		var hi: float = points.max()
		if hi - lo < 0.001:
			hi = lo + 1.0
		var line := PackedVector2Array()
		for i in range(points.size()):
			line.append(Vector2(w * i / float(points.size() - 1), h - 4.0 - (h - 8.0) * (float(points[i]) - lo) / (hi - lo)))
		var area := line.duplicate()
		area.append(Vector2(w, h))
		area.append(Vector2(0, h))
		draw_colored_polygon(area, Color(colour, 0.18))
		draw_polyline(line, colour, 2.0, true)
		draw_circle(line[line.size() - 1], 3.5, colour)

## The chart of `key` from the HUD's history, with its span.
func _spark(parent: Control, key: String, accent: Color, caption: String) -> void:
	var points: Array = hud.history.get(key, [])
	var chart := Sparkline.new()
	chart.name = "Chart_" + key
	chart.points = points.duplicate()
	chart.colour = accent.lightened(0.2)
	chart.custom_minimum_size = Vector2(0, 46)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(chart)
	_label(parent, "%s, the last %d min" % [caption, maxi(1, ceili(points.size() * 5.0 / 60.0))], 11, UI.MUTED)

func setup(hud_node: Node) -> void:
	hud = hud_node
	world = hud.world
	name = "Cabinet"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.065, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 18)
	column.add_child(_head)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_grid)
	visible = false

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh += delta
	if _refresh >= 0.5:
		_refresh = 0.0
		refresh()

# ---------------------------------------------------------------- building blocks

func _label(parent: Control, text: String, size := 15, colour := UI.TEXT, serif := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if serif: l.add_theme_font_override("font", UI.serif(600))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## A ministry's tile: a raised plate with a band of its colour across the top.
func _tile(key: String, title: String, icon: String, action_text: String, action: Callable) -> VBoxContainer:
	var accent: Color = UI.ministry(key)
	var tile := PanelContainer.new()
	tile.name = "Tile_" + key
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(330, 250)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Color("132538"), 0.97)
	style.border_color = accent
	style.border_width_top = 6
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	tile.add_theme_stylebox_override("panel", style)
	_grid.add_child(tile)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	tile.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var badge := PanelContainer.new()
	var round := StyleBoxFlat.new()
	round.bg_color = Color(accent, 0.22)
	round.border_color = accent
	round.set_border_width_all(2)
	round.set_corner_radius_all(22)
	round.set_content_margin_all(7)
	badge.add_theme_stylebox_override("panel", round)
	top.add_child(badge)
	var pic := TextureRect.new()
	pic.texture = UI.icon(icon)
	pic.custom_minimum_size = Vector2(26, 26)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.modulate = accent.lightened(0.25)
	badge.add_child(pic)
	var t := _label(top, UI.caps(title), 19 if title.length() <= 12 else 16, accent.lightened(0.35), true)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if action_text != "":
		var b := Button.new()
		b.name = "Open_" + key
		b.text = action_text + "  ›"
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", accent.lightened(0.45))
		b.add_theme_stylebox_override("normal", UI.box(Color(accent, 0.16), Color(accent, 0.7), 1, 6, 8.0))
		b.add_theme_stylebox_override("hover", UI.box(Color(accent, 0.32), accent.lightened(0.3), 1, 6, 8.0))
		b.add_theme_stylebox_override("pressed", UI.box(Color(accent, 0.45), accent.lightened(0.3), 1, 6, 8.0))
		b.pressed.connect(func():
			close()
			action.call())
		top.add_child(b)
	return col

## A large figure with its caption beneath.
func _figure(parent: Control, value: String, caption: String, colour := UI.CREAM) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var v := _label(box, value, 30, colour, true)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(box, caption, 12, UI.MUTED)

func _figures(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

## A labelled gauge: `value` of `most` in `colour`.
func _gauge(parent: Control, caption: String, value: float, most: float, colour: Color, text := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var c := _label(row, caption, 13, UI.TEXT)
	c.custom_minimum_size = Vector2(92, 0)
	c.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(most, 0.001)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0a1522")
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var n := _label(row, text if text != "" else "%d / %d" % [int(value), int(most)], 13, UI.CREAM)
	n.custom_minimum_size = Vector2(96, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.autowrap_mode = TextServer.AUTOWRAP_OFF

func _rate(v: float) -> String:
	return "%s%.1f/s" % ["+" if v >= 0.0 else "", v]

# ---------------------------------------------------------------- the briefing

func refresh() -> void:
	if world == null or world.economy == null:
		return
	for c in _head.get_children(): c.queue_free()
	for c in _grid.get_children(): c.queue_free()
	var width: float = get_viewport().get_visible_rect().size.x
	_grid.columns = 4 if width >= 1500.0 else (3 if width >= 1100.0 else 2)
	_header()
	_treasury()
	_people()
	_forces()
	_research()
	_foreign()
	_territory()
	_intelligence()
	_power()

func _header() -> void:
	var me: Dictionary = world.map.nations[0]
	var colour := Color(str(me.get("color", "#cdb584")))
	var frame := PanelContainer.new()
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color("0a1522")
	ring.border_color = colour
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(12)
	ring.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", ring)
	_head.add_child(frame)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(112, 112)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var leader: String = str(me.get("people", {}).get("president", ""))
	face.texture = Gallery.face(leader, 1.0)
	frame.add_child(face)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.add_child(names)
	_label(names, "THE CABINET", 14, UI.GOLD, true)
	var n := _label(names, str(me.get("name", "")).split(" · ")[0], 40, colour.lightened(0.35), true)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label(names, leader, 17, UI.CREAM)
	var r: Node = world.research
	if r != null:
		_label(names, "%s  ·  year %d  ·  %s" % [r.eras[r.era].name, 1 + int(world.game_time / 720.0), ["Spring", "Summer", "Autumn", "Winter"][int(world.game_time / 180.0) % 4]], 14, UI.MUTED)
	var eco: Node = world.economy
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 12)
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(chips)
	for c in [["Treasury", "$" + hud.compact_number(eco.res.get("money", 0.0)), "economy"], ["Income", _rate(eco.rates.get("money", 0.0)), "economy"],
			["Approval", "%d%%" % int(eco.happiness), "people"], ["Army", "%d / %d" % [eco.pop_used, eco.pop_cap], "military"]]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(Color(UI.ministry(c[2]), 0.14), Color(UI.ministry(c[2]), 0.75), 1, 8, 12.0))
		chips.add_child(chip)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		chip.add_child(box)
		var v := _label(box, c[1], 26, UI.CREAM, true)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		var cap := _label(box, c[0], 12, UI.ministry(c[2]).lightened(0.3))
		cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	var shut := Button.new()
	shut.name = "CloseCabinet"
	shut.text = "Close  (Tab)"
	shut.focus_mode = Control.FOCUS_NONE
	shut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shut.custom_minimum_size = Vector2(120, 44)
	shut.pressed.connect(close)
	_head.add_child(shut)

func _treasury() -> void:
	var eco: Node = world.economy
	var col := _tile("economy", "Treasury", "money", "World market", func(): hud.toggle_panel("market", true))
	var row := _figures(col)
	_figure(row, "$" + hud.compact_number(eco.res.get("money", 0.0)), "in the treasury", UI.ministry("economy").lightened(0.4))
	var rate: float = eco.rates.get("money", 0.0)
	_figure(row, _rate(rate), "income", UI.GOOD if rate >= 0.0 else UI.BAD)
	_spark(col, "money", UI.ministry("economy"), "Treasury")
	for r in [["food", "Food", Color("8fd16a")], ["iron", "Iron", Color("a9b8c8")], ["oil", "Oil", Color("4fb3a8")], ["silicon", "Silicon", Color("7fd3f0")], ["gas", "Gas", Color("f0a65a")]]:
		var cap: float = float(eco.caps.get(r[0], 0.0))
		if cap > 0.0:
			_gauge(col, r[1], float(eco.res.get(r[0], 0.0)), cap, r[2], "%s  %s" % [hud.compact_number(eco.res.get(r[0], 0.0)), _rate(eco.rates.get(r[0], 0.0))])

func _people() -> void:
	var eco: Node = world.economy
	var col := _tile("people", "The People", "citizens", "Capital", func():
		for b in world.buildings:
			if b.owner == 0 and b.key == "hq" and not b.dead:
				world.select_building(b)
				break)
	var row := _figures(col)
	_figure(row, hud.compact_number(eco.civilians), "citizens, room for %s" % hud.compact_number(eco.civ_cap))
	_figure(row, _rate(eco.rates.get("food", 0.0)), "food", UI.GOOD if eco.rates.get("food", 0.0) >= 0.0 else UI.BAD)
	_spark(col, "citizens", UI.ministry("people"), "Citizens")
	_gauge(col, "Approval", eco.happiness, 100.0, Color("f0c25a") if eco.happiness >= 50.0 else UI.BAD, "%d%%" % int(eco.happiness))
	_gauge(col, "Health", eco.health, 100.0, Color("6ad0a0") if eco.health >= 50.0 else UI.BAD, "%d%%" % int(eco.health))
	_gauge(col, "Housing", eco.civilians, eco.civ_cap, UI.ministry("people"))

func _forces() -> void:
	var eco: Node = world.economy
	var col := _tile("military", "Armed Forces", "army", "Build", func(): hud.set_production_open(true))
	var mine: Array = world.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker")
	var counts := {"Infantry": 0, "Armour": 0, "Aircraft": 0, "Warships": 0}
	for u in mine:
		if u.get("fly", false): counts.Aircraft += 1
		elif u.get("naval", false): counts.Warships += 1
		elif u.get("vehicle", false): counts.Armour += 1
		else: counts.Infantry += 1
	var row := _figures(col)
	_figure(row, str(mine.size()), "units in service")
	var wars: Array = []
	for i in range(1, world.diplomacy.n):
		if world.diplomacy.at_war(0, i) and not world.diplomacy.defeated(i): wars.append(world.diplomacy.name_of(i).split(" · ")[0])
	_figure(row, str(wars.size()), "at war" if wars.size() != 1 else "war", UI.BAD if not wars.is_empty() else UI.GOOD)
	_spark(col, "army", UI.ministry("military"), "Units in service")
	_gauge(col, "Manpower", eco.pop_used, eco.pop_cap, UI.ministry("military"))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	col.add_child(line)
	for k in counts:
		var c := _label(line, "%s %d" % [k, counts[k]], 13, UI.TEXT)
		c.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not wars.is_empty():
		_label(col, "At war with " + ", ".join(PackedStringArray(wars)), 13, UI.BAD)

func _research() -> void:
	var r: Node = world.research
	if r == null: return
	var col := _tile("research", "Research", "research", "Research tree", func(): hud.toggle_research())
	var row := _figures(col)
	_figure(row, str(r.completed_count()), "discoveries made", UI.ministry("research").lightened(0.4))
	_figure(row, "+%.1f/s" % r.rate, "%d points" % int(r.points))
	_label(col, "Now: " + (r.status_of(r.queue[0]) if not r.queue.is_empty() else "nothing in development"), 13, UI.CREAM)
	_spark(col, "research", UI.ministry("research"), "Discoveries")
	if r.era + 1 < r.eras.size():
		_label(col, "Towards the %s:" % r.eras[r.era + 1].name, 13, UI.MUTED)
		for need in r.era_requirements(r.era + 1).slice(0, 3):
			_gauge(col, str(need[0]), float(need[1]), float(need[2]), UI.ministry("research"), ("%d%%" % int(float(need[1]) * 100.0)) if float(need[2]) <= 1.0 else "")
	else:
		_label(col, "The last era is reached.", 13, UI.GOOD)

func _foreign() -> void:
	var d: Node = world.diplomacy
	var col := _tile("diplomacy", "Foreign Affairs", "diplomacy", "Diplomacy", func(): hud.toggle_panel("diplomacy", true))
	for i in range(1, d.n):
		if d.defeated(i): continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		var dot := ColorRect.new()
		dot.color = Color(world.map.nations[i].color)
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var name := _label(row, d.name_of(i).split(" · ")[0], 14, UI.CREAM)
		name.custom_minimum_size = Vector2(120, 0)
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.clip_text = true
		var score: float = d.rel(0, i)
		var tag := "WAR" if d.at_war(0, i) else ("ALLY" if d.allied(0, i) else ("PACT" if d.pact[0][i] else ""))
		var tone: Color = UI.BAD if tag == "WAR" else (UI.GOOD if score >= 25.0 else (UI.MUTED if score > -25.0 else Color("e0a05f")))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = -100.0
		bar.max_value = 100.0
		bar.value = score
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("0a1522")
		bg.set_corner_radius_all(5)
		var fill := StyleBoxFlat.new()
		fill.bg_color = tone
		fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var n := _label(row, ("%s  " % tag if tag != "" else "") + "%+d" % int(score), 13, tone)
		n.custom_minimum_size = Vector2(76, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.autowrap_mode = TextServer.AUTOWRAP_OFF

func _territory() -> void:
	var t: Node = world.territory
	if t == null: return
	var col := _tile("territory", "Territory", "land", "Borders", func(): hud.toggle_panel("territory", true))
	var cells: int = int(t.yields(0).cells)
	var share: float = float(cells) / maxf(float(t.land_cells()), 1.0)
	var row := _figures(col)
	_figure(row, str(cells), "hexes held", UI.ministry("territory").lightened(0.4))
	_figure(row, "%d%%" % roundi(share * 100.0), "of the land")
	var towns: int = world.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"]).size()
	_label(col, "%d settlement%s" % [towns, "" if towns == 1 else "s"], 14, UI.CREAM)
	var others := []
	for i in range(1, world.diplomacy.n):
		others.append([int(t.yields(i).cells), i])
	others.sort_custom(func(a, b): return a[0] > b[0])
	for o in others.slice(0, 3):
		_gauge(col, world.diplomacy.name_of(o[1]).split(" · ")[0], float(o[0]), float(maxi(cells, others[0][0])), Color(world.map.nations[o[1]].color), str(o[0]))

func _intelligence() -> void:
	var e: Node = world.espionage
	if e == null: return
	var col := _tile("intel", "Intelligence", "intel", "Intelligence", func(): hud.toggle_panel("intel", true))
	var row := _figures(col)
	_figure(row, str(e.agents.size()), "agents", UI.ministry("intel").lightened(0.4))
	_figure(row, str(e.missions.size()), "operations under way")
	var best := []
	for k in e.network:
		best.append([float(e.network[k]), int(k)])
	best.sort_custom(func(a, b): return a[0] > b[0])
	for b in best.slice(0, 3):
		if b[1] >= 0 and b[1] < world.diplomacy.n:
			_gauge(col, world.diplomacy.name_of(b[1]).split(" · ")[0], b[0], 100.0, UI.ministry("intel"), "network %d" % int(b[0]))
	if not e.reports.is_empty():
		_label(col, "Latest: " + str(e.reports[0].get("text", "")).substr(0, 110), 12, UI.MUTED)

func _power() -> void:
	var Powers := preload("res://scripts/faction_powers.gd")
	var p: Dictionary = Powers.power_of(world, 0)
	if p.is_empty(): return
	var col := _tile("cabinet", "National Power", "sovereign", "Use it", func(): hud.toggle_panel("diplomacy", true))
	_label(col, str(p.get("name", "")), 24, UI.ministry("cabinet").lightened(0.3), true)
	_label(col, str(p.get("desc", "")), 13, UI.TEXT)
	var wait: float = Powers.ready_in(world, 0)
	_label(col, "Ready" if wait <= 0.0 else "Ready in %ds" % int(ceil(wait)), 15, UI.GOOD if wait <= 0.0 else UI.MUTED)
