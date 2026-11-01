extends Control
## The notification dock: where everything that happens to you is shown, on the right edge under the command
## bar, out of the way of the map. A message is a round icon, coloured by how urgent it is; hold the cursor on it
## and a card opens to its left with the words; click and you are taken to the place (or to the right window); right
## click puts it away. Urgent ones open their card by themselves for a few seconds and then fold into the icon,
## and every one stays until it is old or you have dealt with it, so none is missed. The same messages are in
## the Log (L). Above the icons the dock also carries the cards that must stay open: the UN invitation and the
## live alerts (sitrep_view.gd), which put themselves into `column`.
const UI := preload("res://scripts/ui_theme.gd")
const MAX_CHIPS := 8
const LIFE := {"crit": 75.0, "warn": 50.0, "info": 28.0}
const ICONS := {"warning": "intel", "enemy": "defence", "attack": "defence", "loss": "army", "kill": "defence",
	"war": "diplomacy", "un": "un", "econ": "market", "done": "build", "world": "log"}
const TITLES := {"warning": "Intelligence", "enemy": "Enemy sighted", "attack": "Under attack", "loss": "Lost",
	"kill": "Destroyed", "war": "Diplomacy", "un": "United Nations", "econ": "Economy", "done": "Done", "world": "News"}
const SEVERITY := {"crit": Color("f0674f"), "warn": Color("e6a63e"), "info": Color("d9b45f")}

var hud: Node
var world: Node
var column: VBoxContainer      # cards that stay open (the UN invitation, live alerts)
var strip: VBoxContainer       # the icons
var entries: Array = []        # oldest first: {key, cat, sev, text, at, born, count, chip, badge}
var _card: PanelContainer = null
var _card_for: Dictionary = {}
var _card_until := 0.0         # a card opened by itself stays until then
var _over_card := false
var _clock := 0.0
var _place_tick := 0.0

func setup(hud_node: Node) -> void:
	hud = hud_node
	world = hud.world
	name = "NotificationDock"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	column = VBoxContainer.new()
	column.name = "DockColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	strip = VBoxContainer.new()
	strip.name = "DockStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_constant_override("separation", 6)
	strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(strip)
	_place()

## The width free on the right edge: between the open windows on the left and the Build catalogue on the right.
func space() -> float:
	var right := get_viewport_rect().size.x - 12.0
	if hud._prod != null and hud._prod.visible:
		right = minf(right, hud._prod.get_global_rect().position.x - 10.0)
	var left := 0.0
	for n in [hud._win, hud._cabinet, hud._rs]:
		if n != null and n.visible:
			left = maxf(left, n.get_global_rect().end.x + 10.0)
	return right - left

## Keeps the dock on the right edge, left of the Build catalogue when that is open, and out of the way of any
## window on the left: with less than a card's width free only the icons show, with less than an icon's, nothing.
func _place() -> void:
	var size_now := get_viewport_rect().size
	var right := size_now.x - 12.0
	if hud._prod != null and hud._prod.visible:
		right = minf(right, hud._prod.get_global_rect().position.x - 10.0)
	var free := space()
	column.visible = free >= 300.0
	strip.visible = free >= 56.0
	if _card != null and free < 56.0:
		_card.visible = false
	var top := 134.0
	column.anchor_left = 0.0
	column.anchor_right = 0.0
	column.anchor_top = 0.0
	column.anchor_bottom = 0.0
	column.position = Vector2(right - 330.0, top)
	column.size = Vector2(330.0, 0.0)
	strip.anchor_left = 0.0
	strip.anchor_right = 0.0
	var cards_height: float = column.get_combined_minimum_size().y if column.visible else 0.0
	strip.position = Vector2(right - 46.0, top + cards_height + (8.0 if cards_height > 0.0 else 0.0))
	if _card != null and _card.visible:
		_position_card()

# ---------------------------------------------------------------- posting

## One message. `key` merges repeats (the same thing happening again): the icon gets a count and moves to the top.
func post(key: String, cat: String, sev: String, text: String, at := Vector3.INF) -> void:
	for e in entries:
		if e.key == key:
			e.text = text
			e.count = int(e.count) + 1
			e.born = _clock
			if SEVERITY.has(sev) and _rank(sev) > _rank(e.sev):
				e.sev = sev
				_style(e)
			_badge(e)
			entries.erase(e)
			entries.append(e)
			strip.move_child(e.chip, 0)
			if _card_for == e: _fill_card(e)
			return
	var e := {"key": key, "cat": cat, "sev": sev, "text": text, "at": at, "born": _clock, "count": 1}
	e.chip = _make_chip(e)
	entries.append(e)
	strip.add_child(e.chip)
	strip.move_child(e.chip, 0)
	while entries.size() > MAX_CHIPS:
		var victim: Dictionary = entries[0]
		for c in entries:
			if _rank(c.sev) < _rank(victim.sev): victim = c   # the least urgent, and of those the oldest, goes first
		_remove(victim)
	if sev == "crit":
		_open_card(e, 7.0)

func _rank(sev: String) -> int:
	return {"info": 0, "warn": 1, "crit": 2}.get(sev, 0)

func _make_chip(e: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(46, 46)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icon: TextureRect = hud._icon(ICONS.get(e.cat, "log"), 24)
	icon.modulate = UI.BRIGHT
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var badge := Label.new()
	badge.name = "Count"
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", UI.INK)
	badge.add_theme_stylebox_override("normal", UI.box(UI.GOLD, Color(0, 0, 0, 0), 0, 8, 2.0))
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(30, -2)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(badge)
	e.badge = badge
	e.chip = chip
	_style(e)
	chip.mouse_entered.connect(func(): _open_card(e, 0.0))
	chip.mouse_exited.connect(func(): _later_close(e))
	chip.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT: _activate(e)
			elif event.button_index == MOUSE_BUTTON_RIGHT: _remove(e))
	return chip

func _style(e: Dictionary) -> void:
	var colour: Color = SEVERITY.get(e.sev, UI.GOLD)
	var s := UI.box(Color(UI.INK, 0.94), colour, 2, 23, 0.0, 5)
	e.chip.add_theme_stylebox_override("panel", s)

func _badge(e: Dictionary) -> void:
	var n := int(e.count)
	e.badge.visible = n > 1
	e.badge.text = str(mini(n, 99))

# ---------------------------------------------------------------- the card beside an icon

func _open_card(e: Dictionary, hold: float) -> void:
	_card_for = e
	_card_until = _clock + hold
	if _card == null:
		_card = PanelContainer.new()
		_card.name = "DockCard"
		_card.mouse_filter = Control.MOUSE_FILTER_STOP
		_card.mouse_entered.connect(func(): _over_card = true)
		_card.mouse_exited.connect(func():
			_over_card = false
			_later_close(_card_for))
		add_child(_card)
	_fill_card(e)

func _fill_card(e: Dictionary) -> void:
	for c in _card.get_children(): c.queue_free()
	var colour: Color = SEVERITY.get(e.sev, UI.GOLD)
	var s := UI.plate(Color(UI.PANEL_TOP, 0.98), Color(UI.PANEL_LOW, 0.98), UI.GOLD, 12.0, UI.LIFT, Color(0, 0, 0, 0), 0, 6, colour, 4)
	_card.add_theme_stylebox_override("panel", s)
	_card.custom_minimum_size = Vector2(300, 0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	_card.add_child(body)
	var title := Label.new()
	title.text = TITLES.get(e.cat, "News") + ("   ×%d" % int(e.count) if int(e.count) > 1 else "")
	title.add_theme_font_override("font", UI.serif(600))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UI.GOLD)
	body.add_child(title)
	var words := Label.new()
	words.text = str(e.text)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size = Vector2(276, 0)
	words.add_theme_font_size_override("font_size", 15)
	words.add_theme_color_override("font_color", UI.CREAM)
	body.add_child(words)
	var hint := Label.new()
	hint.text = ("Click: go there" if e.at != Vector3.INF else "Click: open") + "   ·   Right-click: dismiss"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UI.MUTED)
	body.add_child(hint)
	_card.reset_size()
	_card.visible = true
	_position_card.call_deferred()

func _position_card() -> void:
	if _card == null or _card_for.is_empty() or not is_instance_valid(_card_for.chip):
		return
	_card.reset_size()
	var chip: Control = _card_for.chip
	var at := chip.global_position - global_position
	_card.position = Vector2(at.x - _card.size.x - 8.0, clampf(at.y, 4.0, maxf(4.0, get_viewport_rect().size.y - _card.size.y - 4.0)))

func _later_close(e: Dictionary) -> void:
	await get_tree().create_timer(0.2).timeout
	if _card != null and _card_for == e and not _over_card and _clock >= _card_until:
		_card.visible = false
		_card_for = {}

# ---------------------------------------------------------------- acting on a message

func _activate(e: Dictionary) -> void:
	if e.at != Vector3.INF:
		world.cam_focus = Vector3(e.at.x, world.cam_focus.y, e.at.z)
		world.clamp_camera()
	else:
		match str(e.cat):
			"war", "un": hud.toggle_panel("diplomacy", true)
			"econ": hud.toggle_panel("market", true)
			"warning", "enemy": hud.toggle_panel("intel", true)
			_: hud.toggle_log()
	_remove(e)

func _remove(e: Dictionary) -> void:
	entries.erase(e)
	if is_instance_valid(e.chip):
		e.chip.queue_free()
	if _card_for == e and _card != null:
		_card.visible = false
		_card_for = {}

func _process(delta: float) -> void:
	_clock += delta
	_place()   # every frame: it is a few comparisons, and a window opening must not be covered for even a moment
	for e in entries.duplicate():
		var hovered: bool = _card_for == e and _card != null and _card.visible
		if not hovered and _clock - float(e.born) > float(LIFE.get(e.sev, 28.0)):
			_remove(e)
	if _card != null and _card.visible and _card_until > 0.0 and _clock >= _card_until and not _over_card:
		var chip: Control = _card_for.get("chip") if not _card_for.is_empty() else null
		if chip == null or not chip.get_global_rect().has_point(get_global_mouse_position()):
			_card.visible = false
			_card_for = {}
			_card_until = 0.0
