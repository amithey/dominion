extends Control
## What the situation report (sitrep.gd) shows on screen:
##   - an alert banner under the top bar: the live attacks and losses, most severe first, each a card
##     that jumps the camera to the place when clicked; critical ones pulse and sound a short alarm;
##   - the count of unread warnings on the Log button;
##   - the Situation report window (L): a summary of the last minutes by category, and the full
##     message log in a second tab.
## The minimap draws the pings itself (minimap.gd reads sitrep.active_pings()).

const UI := preload("res://scripts/ui_theme.gd")
const CAT_COLOUR := {"warning": Color("ff6a52"), "enemy": Color("e8a05a"), "attack": Color("e0604a"), "loss": Color("d9894a"), "kill": Color("7fc08a"), "war": Color("c98fb0"), "econ": Color("d8b866"), "done": Color("8fb8d8"), "world": Color("9aa7b0")}
const MAX_CARDS := 3
const WINDOW_SECONDS := 300.0

var hud: Node
var world: Node
var _banner: VBoxContainer
var _cards := {}               # event key -> PanelContainer
var _clock := 0.0
var _sound_at := -99.0
var _heard := {}               # event key -> true: its alarm already sounded
var tab := "summary"           # "summary" | "all"
var rows: VBoxContainer        # the window's content (the HUD builds the window; this fills it)
var summary_label: Label
var _fill_clock := 0.0

func setup(hud_node: Node) -> void:
	hud = hud_node
	world = hud.world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = VBoxContainer.new()
	_banner.name = "AlertBanner"
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.0
	_banner.offset_left = -100
	_banner.offset_right = 380
	_banner.offset_top = 110
	_banner.add_theme_constant_override("separation", 4)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

func _process(delta: float) -> void:
	if world == null or world.sitrep == null:
		return
	_clock += delta
	for card in _cards.values():
		if card.get_meta("crit", false):
			card.modulate.a = 0.82 + 0.18 * sin(_clock * 7.0)
	if int(_clock * 5.0) == int((_clock - delta) * 5.0):
		return
	world.sitrep.update()
	_refresh_banner()
	_refresh_badge()
	# The open summary follows the battle (once a second; the message tab refreshes on each message).
	_fill_clock += 0.2
	if _fill_clock >= 1.0:
		_fill_clock = 0.0
		if tab == "summary" and rows != null and is_instance_valid(rows) and rows.is_visible_in_tree():
			fill()

## The live alerts as cards (at most MAX_CARDS).
func _refresh_banner() -> void:
	var alerts: Array = world.sitrep.alerts().slice(0, MAX_CARDS)
	var keep := {}
	for e in alerts:
		keep[e.key] = true
		var card: PanelContainer = _cards.get(e.key)
		if card == null:
			card = _make_card(e)
			_cards[e.key] = card
			_banner.add_child(card)
			if e.cat == "warning" and not _heard.has(e.key) and _clock - _sound_at > 6.0 and world.audio != null:
				_sound_at = _clock
				_heard[e.key] = true
				world.audio.diplomatic_feedback("alert")
		var label: Label = card.get_meta("label")
		var text := _card_text(e)
		if label.text != text:
			label.text = text
	for key in _cards.keys():
		if not keep.has(key):
			_banner.remove_child(_cards[key])
			_cards[key].queue_free()
			_cards.erase(key)

func _card_text(e: Dictionary) -> String:
	var more := ""
	if int(e.n) > 3 and e.cat == "attack":
		more = "   ·   %d hits" % int(e.n)
	return "%s%s" % [e.text, more]

func _make_card(e: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var crit: bool = e.cat == "warning"   # red is for what intelligence tells you; reports of damage are amber
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.05, 0.04, 0.93) if crit else Color(0.2, 0.12, 0.04, 0.93)
	style.border_color = Color("e0604a") if crit else Color("e2a23c")
	style.border_width_left = 5
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.shadow_size = 5
	style.shadow_color = Color(0, 0, 0, 0.35)
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("crit", crit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var mark := Label.new()
	mark.text = "!" if crit else "•"
	mark.add_theme_font_size_override("font_size", 17)
	mark.add_theme_color_override("font_color", Color("ff7a64") if crit else Color("f1c86a"))
	row.add_child(mark)
	var label := Label.new()
	label.text = _card_text(e)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UI.TEXT)
	row.add_child(label)
	var look := Label.new()
	look.text = "click: look"
	look.add_theme_font_size_override("font_size", 11)
	look.add_theme_color_override("font_color", UI.MUTED)
	row.add_child(look)
	card.set_meta("label", label)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "Click to look at the place. L opens the situation report."
	var key: String = e.key
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for ev in world.sitrep.events:
				if ev.key == key and ev.pos != Vector3.INF:
					world.cam_focus = Vector3(ev.pos.x, world.cam_focus.y, ev.pos.z)
					world.clamp_camera()
					break)
	return card

## "Log (3)" in red when warnings came while the window was closed.
func _refresh_badge() -> void:
	var button: Button = hud.get("_log_button") if hud.get("_log_button") != null else null
	if button == null:
		return
	var n: int = world.sitrep.unread
	var text := "Log" if n <= 0 else "Log %d" % mini(n, 99)
	if button.text != text:
		button.text = text
		button.add_theme_color_override("font_color", Color("ff8a70") if world.sitrep.unread_critical > 0 else (Color("f1c86a") if n > 0 else UI.TEXT))

# ---------------------------------------------------------------- the window

## Fills the window's content for the current tab.
func fill() -> void:
	if rows == null or world == null or world.sitrep == null:
		return
	var scroll := rows.get_parent() as ScrollContainer
	var keep: int = scroll.scroll_vertical if scroll != null else 0
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	if tab == "all":
		_fill_all()
	else:
		_fill_summary()
	if scroll != null:
		scroll.set_deferred("scroll_vertical", keep)

func _fill_summary() -> void:
	var s: RefCounted = world.sitrep
	var head: Label = hud._text("Last %d minutes: %s" % [int(WINDOW_SECONDS / 60.0), s.headline(WINDOW_SECONDS)], 15, UI.CREAM, true)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 500
	rows.add_child(head)
	var groups: Array = s.summary(WINDOW_SECONDS)
	if groups.is_empty():
		rows.add_child(hud._text("Nothing has happened to you recently.", 14, UI.MUTED))
	for g in groups:
		var title: Label = hud._text("%s  (%d)" % [s.TITLES[g[0]], g[1].size()], 15, CAT_COLOUR[g[0]], true)
		rows.add_child(title)
		var shown := 0
		for e in g[1]:
			shown += 1
			if shown > 12:
				rows.add_child(hud._text("   ... and %d more" % (g[1].size() - 12), 12, UI.MUTED))
				break
			rows.add_child(_entry_row(e))

func _entry_row(e: Dictionary) -> Control:
	var t := int(e.t)
	var live: bool = world.game_time - float(e.last) <= 9.0 and e.cat in ["warning", "attack", "loss"]
	var text := "%02d:%02d   %s%s" % [t / 60, t % 60, str(e.text), ("   ×%d" % int(e.n)) if int(e.n) > 1 and e.cat in ["attack"] else ""]
	if e.pos != Vector3.INF:
		var b := Button.new()
		b.text = text
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Color("ff9a84") if live else UI.TEXT)
		b.tooltip_text = "Click to look at the place"
		b.custom_minimum_size.x = 500
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var at: Vector3 = e.pos
		b.pressed.connect(func():
			world.cam_focus = Vector3(at.x, world.cam_focus.y, at.z)
			world.clamp_camera())
		return b
	var l: Label = hud._text(text, 13, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500
	return l

func _fill_all() -> void:
	if hud.notice_log.is_empty():
		rows.add_child(hud._text("No messages yet.", 14, UI.MUTED))
	for i in range(hud.notice_log.size() - 1, -1, -1):
		var line: Label = hud._text(hud.notice_log[i], 13, UI.CREAM if i == hud.notice_log.size() - 1 else UI.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 500
		rows.add_child(line)
