extends CanvasLayer
## Economy interface: resource bar, command panel (build menu, or the selected
## building's details, training buttons and queue) and short notices.
## Buttons call back into world.gd; the panel refreshes four times a second.

const BUILD_MENU := ["villageCenter", "farm", "cottage", "housing", "residential", "warehouse", "foodDepot", "workerHouse", "extractor", "barracks", "tankFactory", "shipyard", "helipad", "airfield"]
const RES_LABELS := {"money": "$", "food": "Food", "iron": "Iron", "oil": "Oil"}
const GOLD := Color("a29269")

var world: Node
var economy: Node
var _bar: Label
var _panel: PanelContainer
var _title: Label
var _info: Label
var _buttons: GridContainer
var _queue: ProgressBar
var _notices: VBoxContainer
var _selected = null      # building entity shown in the panel, or null for the build menu
var _shown_key := ""
var _refresh := 0.0

func setup(world_node: Node, economy_node: Node) -> void:
	world = world_node
	economy = economy_node
	# A resource strip across the top of the screen.
	var top := _box(Vector2(0, 0))
	top.anchor_right = 1.0
	top.offset_bottom = 38
	_bar = Label.new()
	_bar.add_theme_font_size_override("font_size", 16)
	_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_bar)

	_panel = _box(Vector2.ZERO)
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16
	_panel.offset_top = -236
	_panel.offset_right = 900
	_panel.offset_bottom = -16
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	column.add_child(_title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(850, 0)
	_info.add_theme_color_override("font_color", Color("b9c4c8"))
	column.add_child(_info)
	_queue = ProgressBar.new()
	_queue.custom_minimum_size = Vector2(850, 10)
	_queue.show_percentage = false
	column.add_child(_queue)
	_buttons = GridContainer.new()
	_buttons.columns = 7
	column.add_child(_buttons)

	_notices = VBoxContainer.new()
	# Notices on the right, clear of the info panel and the command panel.
	_notices.anchor_left = 1.0
	_notices.anchor_right = 1.0
	_notices.offset_left = -420
	_notices.offset_right = -16
	_notices.offset_top = 92  # below the Diplomacy button
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)
	show_building(null)
	_build_diplomacy_panel()

func _box(_at: Vector2) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111f25e6")
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)
	add_child(box)
	return box

func cost_text(cost: Dictionary) -> String:
	var parts := []
	for key in cost:
		parts.append(("$%d" % int(cost[key])) if key == "money" else ("%d %s" % [int(cost[key]), key]))
	return " · ".join(PackedStringArray(parts)) if not parts.is_empty() else "free"

func _process(delta: float) -> void:
	if economy == null:
		return
	_refresh += delta
	if _refresh < 0.25:
		return
	_refresh = 0.0
	var parts := []
	for key in RES_LABELS:
		var rate: float = economy.rates.get(key, 0.0)
		var cap := ("/%d" % int(economy.caps[key])) if economy.caps.has(key) and key != "food" else ""
		parts.append("%s %d%s (%s%.1f)" % [RES_LABELS[key], int(economy.res[key]), cap, "+" if rate >= 0 else "", rate])
	parts.append("Army %d/%d" % [economy.pop_used, economy.pop_cap])
	parts.append("Citizens %d/%d" % [int(economy.civilians), int(economy.civ_cap)])
	var settlements: Array = world.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.built and b.def.get("settlement") != null)
	parts.append("Supplied %d/%d" % [settlements.filter(func(b): return b.get("supplied", true)).size(), settlements.size()])
	_bar.text = "   ".join(PackedStringArray(parts))
	if _selected != null and (_selected.dead or _selected.owner != 0):
		show_building(null)
	_update_panel()

var transport_text := ""
## Road or rail planning status (empty ends it).
func show_transport(text: String) -> void:
	transport_text = text
	_shown_key = ""
	_update_panel()

## null shows the build menu; a building entity shows its details and training.
func show_building(building) -> void:
	_selected = building
	_shown_key = ""
	_update_panel()

func _update_panel() -> void:
	var key: String = "menu" if _selected == null else "%s:%s:%d" % [_selected.key, _selected.built, _selected.queue.size()]
	if transport_text != "":
		_title.text = "ROAD" if world.transport_kind == "road" else "RAILWAY"
		_info.text = transport_text
		_queue.visible = false
	elif _selected == null:
		_title.text = "BUILD"
		_info.text = "Pick a structure, then click the ground inside one of your districts (right click cancels). Workers go and build it. A Village Center founds a new district: link it to the capital by road or rail so it is supplied."
		_queue.visible = false
	else:
		var def: Dictionary = _selected.def
		_title.text = def.name.to_upper()
		if not _selected.built:
			_info.text = "Under construction: %d%%%s" % [int(_selected.progress * 100), "" if _selected.builders > 0 else " — waiting for a worker"]
			_queue.visible = true
			_queue.value = _selected.progress * 100
		else:
			var lines := ["HP %d/%d. %s" % [int(_selected.hp), int(_selected.max_hp), def.desc]]
			if not _selected.get("supplied", true):
				lines.append("OUT OF SUPPLY: production stopped. Connect this district to the capital by road or rail.")
			elif _selected.get("rail_supplied", false):
				lines.append("Rail supplied: +25% production.")
			if not _selected.queue.is_empty():
				var names := PackedStringArray()
				for q in _selected.queue:
					names.append(world.unit_defs[q].name)
				lines.append("Training: " + ", ".join(names))
			_info.text = "\n".join(PackedStringArray(lines))
			_queue.visible = not _selected.queue.is_empty()
			_queue.value = _selected.queue_prog * 100
	if key == _shown_key:
		_update_enabled()
		return
	_shown_key = key
	for child in _buttons.get_children():
		child.queue_free()
	if _selected == null:
		for b in BUILD_MENU:
			var def: Dictionary = world.building_defs.get(b, {})
			if def.is_empty():
				continue
			_add_button("%s\n%s" % [def.name, cost_text(def.cost)], def.cost, def.desc, func(): world.begin_placement(b))
		for kind in ["road", "rail"]:
			var price: Dictionary = world.logistics.transport[kind]
			var cost := {"money": price.money, "iron": price.iron} if float(price.iron) > 0 else {"money": price.money}
			_add_button("%s\n%s per hex" % ["Road" if kind == "road" else "Railway", cost_text(cost)], cost,
				"Click a start hex, then a destination. Links settlements to the capital so they are supplied." + ("" if kind == "road" else " Railways speed production by 25%."),
				func(): world.begin_transport(kind))
	elif _selected.built:
		for u in _selected.def.trains:
			var def: Dictionary = world.unit_defs.get(u, {})
			if def.is_empty():
				continue
			_add_button("%s\n%s" % [def.name, cost_text(def.cost)], def.cost, def.desc, func(): world.queue_unit(_selected, u))
	_update_enabled()

func _add_button(text: String, cost: Dictionary, tip: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(118, 46)
	button.set_meta("cost", cost)
	button.pressed.connect(action)
	_buttons.add_child(button)

func _update_enabled() -> void:
	for button in _buttons.get_children():
		if button is Button and button.has_meta("cost"):
			var cost: Dictionary = button.get_meta("cost")
			button.disabled = not economy.can_afford(cost)

# ---------------------------------------------------------------- diplomacy

var _diplo: PanelContainer
var _diplo_rows: VBoxContainer
var _letters: Array = []     # pending [text, accept, decline]
var _letter_box: PanelContainer

func _build_diplomacy_panel() -> void:
	var toggle := Button.new()
	toggle.text = "Diplomacy (G)"
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.offset_left = -150
	toggle.offset_right = -16
	toggle.offset_top = 52
	toggle.offset_bottom = 84
	toggle.pressed.connect(toggle_diplomacy)
	add_child(toggle)
	var row := 0
	for entry in [["Save (F5)", func(): world.saves.save("quicksave")], ["Load (F9)", func(): world.saves.load_slot("quicksave")]]:
		var b := Button.new()
		b.text = entry[0]
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.offset_left = -300 - row * 110
		b.offset_right = -160 - row * 110
		b.offset_left = b.offset_right - 100
		b.offset_top = 52
		b.offset_bottom = 84
		b.pressed.connect(entry[1])
		add_child(b)
		row += 1
	_diplo = _box(Vector2.ZERO)
	# Left side, below the info panel: clear of notices and letters.
	_diplo.offset_left = 16
	_diplo.offset_right = 640
	_diplo.offset_top = 228
	_diplo.visible = false
	_diplo_rows = VBoxContainer.new()
	_diplo.add_child(_diplo_rows)

func toggle_diplomacy() -> void:
	_diplo.visible = not _diplo.visible
	if _diplo.visible:
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
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(404, 0)
	label.add_theme_color_override("font_color", Color("f1e3b4"))
	label.add_theme_color_override("font_outline_color", Color("111f25"))
	label.add_theme_constant_override("outline_size", 6)
	_notices.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(2.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
