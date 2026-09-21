extends CanvasLayer
## Economy interface: resource bar, command panel (build menu, or the selected
## building's details, training buttons and queue) and short notices.
## Buttons call back into world.gd; the panel refreshes four times a second.

const BUILD_MENU := ["villageCenter", "farm", "cottage", "housing", "residential", "warehouse", "foodDepot", "workerHouse", "extractor",
	"market", "port", "intelAgency", "barracks", "tankFactory", "shipyard", "helipad", "airfield", "ammoDepot", "missileSilo"]
const RES_LABELS := {"money": "$", "food": "Food", "iron": "Iron", "oil": "Oil", "silicon": "Silicon", "uranium": "Uranium"}
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
	_panel.offset_top = -292
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
	_buttons.columns = 8
	column.add_child(_buttons)

	_notices = VBoxContainer.new()
	# Notices on the right, clear of the info panel and the command panel.
	_notices.anchor_left = 1.0
	_notices.anchor_right = 1.0
	_notices.offset_left = -420
	_notices.offset_right = -16
	_notices.offset_top = 130  # below the panel buttons
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
		if key in ["silicon", "uranium"] and economy.res[key] < 0.5 and absf(rate) < 0.01:
			continue  # shown once the nation has any
		var cap := ("/%d" % int(economy.caps[key])) if economy.caps.has(key) and key != "food" else ""
		parts.append("%s %d%s (%s%.1f)" % [RES_LABELS[key], int(economy.res[key]), cap, "+" if rate >= 0 else "", rate])
	parts.append("Army %d/%d" % [economy.pop_used, economy.pop_cap])
	parts.append("Citizens %d/%d" % [int(economy.civilians), int(economy.civ_cap)])
	var settlements: Array = world.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.built and b.def.get("settlement") != null)
	parts.append("Supplied %d/%d" % [settlements.filter(func(b): return b.get("supplied", true)).size(), settlements.size()])
	if world.territory:
		parts.append("Land %d" % world.territory.yields(0).cells)
	if world.missiles and (world.missiles.stored() > 0 or not world.missiles.silos().is_empty()):
		parts.append("Missiles %d/%d" % [world.missiles.stored(), world.missiles.capacity()])
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
	if _selected != null and _selected.key == "missileSilo":
		key += ":%s" % str(world.missiles.stock)
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
					names.append(world.missiles.def_of(q.substr(8)).name if String(q).begins_with("missile:") else world.unit_defs[q].name)
				lines.append("In production: " + ", ".join(names))
			if _selected.key == "missileSilo":
				var held := PackedStringArray()
				for m in world.missiles.stock:
					if world.missiles.stock[m] > 0:
						held.append("%s %d" % [world.missiles.def_of(m).name, world.missiles.stock[m]])
				lines.append("Stored %d/%d (each Ammo Depot adds %d): %s" % [world.missiles.stored(), world.missiles.capacity(), int(world.missiles.cfg.capPerDepot), ", ".join(held) if not held.is_empty() else "none"])
			if world.disabled(_selected):
				lines.append("EMP: systems down.")
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
	elif _selected.built and _selected.key == "missileSilo":
		var ms: Node = world.missiles
		for m in ms.types():
			var mdef: Dictionary = ms.def_of(m)
			var why: String = ms.locked(m)
			_add_button("%s
%s" % [mdef.name, cost_text(mdef.cost) if why == "" else why], mdef.cost, "%s Damage %d, blast radius %d m." % [mdef.desc, int(mdef.dmg), int(mdef.radius)],
				func(): _say(ms.produce(_selected, m)))
			if why != "":
				_buttons.get_child(_buttons.get_child_count() - 1).set_meta("locked", true)
		for m in ms.types():
			if ms.stock[m] > 0:
				_add_button("LAUNCH
%s (%d)" % [ms.def_of(m).name, ms.stock[m]], {}, "Arm it, then click the target on the map.", func(): world.begin_missile(m))
	elif _selected.built and _selected.key in ["market", "port", "intelAgency"]:
		var which: String = "intel" if _selected.key == "intelAgency" else "market"
		_add_button("Open %s
(%s)" % ["Intelligence" if which == "intel" else "World Market", "I" if which == "intel" else "M"], {}, "", func(): toggle_panel(which, true))
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
	button.custom_minimum_size = Vector2(128, 46)
	button.add_theme_font_size_override("font_size", 13)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long names wrap instead of widening the panel
	button.set_meta("cost", cost)
	button.pressed.connect(action)
	_buttons.add_child(button)

func _update_enabled() -> void:
	for button in _buttons.get_children():
		if button is Button and button.has_meta("cost"):
			var cost: Dictionary = button.get_meta("cost")
			button.disabled = not economy.can_afford(cost) or button.get_meta("locked", false)

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
	var shortcut := 0
	for entry in [["Territory (T)", "territory"], ["Intel (I)", "intel"], ["Market (M)", "market"]]:
		var b := Button.new()
		b.text = entry[0]
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.offset_right = -16 - shortcut * 128
		b.offset_left = b.offset_right - 120
		b.offset_top = 90
		b.offset_bottom = 122
		b.pressed.connect(toggle_panel.bind(entry[1]))
		add_child(b)
		shortcut += 1
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
		_side.offset_top = 178
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_side.add_child(_scroll)
		_side_rows = VBoxContainer.new()
		_scroll.add_child(_side_rows)
	# Between the info panel and the command panel, scrolling when longer.
	_scroll.custom_minimum_size = Vector2(676, maxf(160.0, get_viewport().get_visible_rect().size.y - 178.0 - 330.0))
	if not _hooked and world.market != null:
		_hooked = true
		world.market.changed.connect(func(): if side_mode == "market": refresh_side())
		world.espionage.changed.connect(func(): if side_mode == "intel": refresh_side())
		world.territory.changed.connect(func(): if side_mode == "territory": refresh_side())
	side_mode = mode
	_side.visible = mode != ""
	if mode != "":
		_diplo.visible = false
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
