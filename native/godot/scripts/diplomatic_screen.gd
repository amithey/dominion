extends Control
const UI := preload("res://scripts/ui_theme.gd")
var world: Node
var service: Node
var nation := 1
var column: VBoxContainer
var content: VBoxContainer
var stage: Control
var status: Label
var progress: ProgressBar
var terms := {"res": "iron", "dir": "export", "qty": 25}
var last_tick := 0
var channel_widgets: Array = []

func setup(w: Node) -> void:
	world = w
	service = w.diplomacy.contacts
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.045, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 45
	frame.offset_right = -45
	frame.offset_top = 60
	frame.offset_bottom = -40
	frame.add_theme_stylebox_override("panel", UI.plate(UI.PANEL_TOP, UI.PANEL_LOW, UI.TRIM, 22, UI.LIFT, UI.GOLD, 2, 8))
	add_child(frame)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)
	service.changed.connect(_refresh)
	hide()

func open(target: int) -> void:
	nation = target
	show()
	_refresh()

func _text(parent: Node, text: String, size := 16, colour := UI.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, reason := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 36
	b.disabled = reason != ""
	b.tooltip_text = reason
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _run(action: Callable) -> void:
	var result = action.call()
	if result is String and result != "": world.hud.notice(result)
	_refresh()

func _refresh() -> void:
	if not visible or column == null: return
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	progress = null
	channel_widgets.clear()
	var s: Dictionary = service.session
	var current := not s.is_empty() and int(s.nation) == nation
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := _text(head, "FOREIGN OFFICE  /  " + world.diplomacy.name_of(nation), 24, UI.BRIGHT)
	title.add_theme_font_override("font", UI.serif())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if current and s.phase not in ["concluded", "choosing"]:
		_button(head, "Back to contact options", func(): _run(service.back_to_channels))
	_button(head, "Close", hide)
	_text(column, "%s  ·  Relations %+d  ·  %s" % [service.leader(nation), world.diplomacy.rel(0, nation), "AT WAR" if world.diplomacy.at_war(0, nation) else "Diplomatic relations"], 14, UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	row.add_child(left)
	var identities := [service.leader(0), service.leader(nation)]
	stage = preload("res://scripts/leader_gallery.gd").new() if preload("res://scripts/leader_gallery.gd").available(identities) else preload("res://scripts/summit_stage.gd").new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(stage)
	stage.setup([Color(world.map.nations[0].color), Color(world.map.nations[nation].color)], [service.leader(0), service.leader(nation)], current and s.phase == "talking" and s.channel == "visit")
	_text(left, "%s    /    %s" % [service.leader(0), service.leader(nation)] if current and s.channel == "visit" and s.phase == "talking" else "Office of " + service.leader(nation), 17, UI.BRIGHT)
	status = _text(left, "Choose how to approach this government. Each channel has its own timing, agenda and influence.", 16)
	_text(left, "Simulation continues while this screen is open. Accepted terms take effect immediately. Closing the screen keeps the contact open.", 12, UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	if not current:
		_channels()
	elif s.phase == "choosing":
		status.text = s.message
		_channels()
		_button(content, "End this contact", func(): service.finish())
	elif s.phase in ["travelling", "connecting"]:
		_text(content, "INVITATION ACCEPTED" if s.channel == "visit" else "ESTABLISHING CONTACT", 20, UI.GOLD)
		_text(content, service.CHANNELS[s.channel].name, 18)
		if s.channel == "mediator": _text(content, "Via " + s.mediator, 15, UI.MUTED)
		progress = ProgressBar.new()
		progress.show_percentage = false
		content.add_child(progress)
		_text(content, "You may close this screen and continue governing. A notification will announce when talks are ready.")
		_button(content, "Cancel contact · fee is not refundable", func(): service.finish("Contact cancelled by your government."))
	elif s.phase == "talking":
		status.text = s.message
		_text(content, "NEGOTIATING TABLE" if s.channel == "visit" else service.CHANNELS[s.channel].name.to_upper(), 20, UI.GOLD)
		_text(content, "%d / %d agenda items discussed" % [s.used.size(), service.CHANNELS[s.channel].topics], 14, UI.MUTED)
		_button(content, "Conclude talks & read communique", func(): service.finish())
		if not s.counter.is_empty():
			_text(content, s.message, 17, UI.BRIGHT)
			_button(content, "Accept concession · $200", func(): _run(service.answer_counter.bind(true)))
			_button(content, "Decline counteroffer", func(): _run(service.answer_counter.bind(false)))
		else:
			_shipping_terms()
			for key in service.TOPICS:
				var topic: Array = service.TOPICS[key]
				var reason: String = service.topic_reason(key, terms)
				_button(content, topic[0], func(): _run(service.propose.bind(key, terms.duplicate())), reason)
				_text(content, reason if reason != "" else topic[1], 12, UI.MUTED)
			# Firm language for the situation you are in: peacetime, cold war or war.
			var state: String = service.relation_state(nation)
			_text(content, "FIRM LANGUAGE  ·  %s" % service.STANCE_GROUPS[state].to_upper(), 16, UI.GOLD)
			for key in service.STANCES:
				if not state in service.STANCES[key][2]:
					continue
				var stance: Array = service.STANCES[key]
				var why: String = service.topic_reason(key)
				_button(content, stance[0], func(): _run(service.propose.bind(key)), why)
				_text(content, why if why != "" else stance[1], 12, UI.MUTED)
	else:
		status.text = s.message
		_text(content, "JOINT COMMUNIQUE", 21, UI.GOLD)
		if s.results.is_empty(): _text(content, "No agreement was signed.")
		for result in s.results:
			_text(content, "%s  ·  %s" % [result.outcome.to_upper(), service.title(result.key)], 16, UI.GOOD if result.outcome in ["Accepted", "Regret expressed", "Conceded", "Heeded", "Complied", "Agreed", "Surrendered", "Exchanged"] else UI.BAD)
			_text(content, result.detail, 13, UI.MUTED)
		_text(content, "Arrange a follow-up", 18, UI.GOLD)
		_channels()
	last_tick = -1
	_process(0)

func _channels() -> void:
	var notes := {"mediator": "A discreet intermediary. Especially useful for peace talks; two agenda items. No arms licensing or defence alliance.", "phone": "Fast, direct contact. Two agenda items; useful for practical agreements and crises.", "visit": "The host must consent. Travel time depends on distance. Four agenda items, strongest influence; defence alliances can be negotiated here."}
	for key in service.CHANNELS:
		var c: Dictionary = service.CHANNELS[key]
		var button := _button(content, "%s  ·  $%d" % [c.name, c.fee], func(): _run(service.begin.bind(nation, key)), service.start_reason(nation, key))
		_text(content, "%s\nPreparation: %ds · influence +%d" % [notes[key], ceili(service.duration(nation, key)), c.influence], 14, UI.MUTED)
		var reason: String = service.start_reason(nation, key)
		var warning := _text(content, reason, 12, UI.BAD)
		warning.visible = reason != ""
		channel_widgets.append({"key": key, "button": button, "warning": warning})
	if not service.session.is_empty() and service.session.phase != "concluded" and int(service.session.nation) != nation:
		_button(content, "Resume existing contact", func(): open(int(service.session.nation)))

func _shipping_terms() -> void:
	_text(content, "Shipping terms (for a route proposal)", 12, UI.GOLD)
	var row := HBoxContainer.new()
	content.add_child(row)
	for field in ["res", "dir", "qty"]:
		var options: Array = service.world.market.resources() if field == "res" else (["export", "import"] if field == "dir" else [10, 25, 50])
		var choice := OptionButton.new()
		for value in options:
			choice.add_item(str(value).capitalize())
			if value == terms[field]: choice.select(choice.item_count - 1)
		choice.item_selected.connect(func(i): terms[field] = options[i])
		row.add_child(choice)

func _process(_delta: float) -> void:
	if not visible or service == null: return
	var tick := int(service.clock)
	if tick == last_tick: return
	last_tick = tick
	var s: Dictionary = service.session
	for item in channel_widgets:
		var reason: String = service.start_reason(nation, item.key)
		item.button.disabled = reason != ""
		item.button.tooltip_text = reason
		item.warning.text = reason
		item.warning.visible = reason != ""
	if not s.is_empty() and int(s.nation) == nation and s.phase in ["travelling", "connecting"]:
		status.text = "%s\n%s · %ds remaining" % [s.message, service.CHANNELS[s.channel].name, maxi(0, ceili(float(s.ready) - service.clock))]
		if progress != null: progress.value = 100.0 * clampf(1.0 - (float(s.ready) - service.clock) / float(s.duration), 0, 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventKey: accept_event()

func _input(event: InputEvent) -> void:
	if not visible or not world.hud.visible: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
		elif event.keycode not in [KEY_TAB, KEY_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_F5, KEY_F9]:
			get_viewport().set_input_as_handled()
