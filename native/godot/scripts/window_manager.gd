extends Node
## Floating HUD windows keep their content, scroll and selection while dragged.
## Input continues outside the header, so releasing over the map never clicks it.
const EDGE := 12.0
const TOP := 56.0
var windows: Dictionary = {}
var positions: Dictionary = {}
var obstacles: Array[Control] = []
var dragging: Control
var drag_offset := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_resize)

func register_window(panel: Control, header: Control, id: String) -> void:
	windows[id] = panel
	panel.set_meta("window_id", id)
	header.set_meta("drag_handle", true)
	header.tooltip_text = "Drag the title to move this window"
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	_pass_header(header)
	header.gui_input.connect(func(event: InputEvent): _header_input(event, panel, header))
	if positions.has(id):
		_set_position(panel, positions[id])
	panel.visibility_changed.connect(func():
		if panel.visible: reflow.call_deferred(panel))
	reflow.call_deferred(panel)

func _pass_header(header: Control) -> void:
	# Containers pass events up; buttons keep their ordinary click behavior.
	for child in header.get_children():
		if child is BaseButton or child is LineEdit: continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE if child is Label or child is TextureRect else Control.MOUSE_FILTER_PASS
			child.mouse_default_cursor_shape = Control.CURSOR_MOVE
			_pass_header(child)

func _header_input(event: InputEvent, panel: Control, header: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = panel
			# gui_input coordinates belong to the title; _input belongs to the
			# viewport. Use the event itself so UI scale and queued input agree.
			drag_offset = header.global_position + event.position - panel.global_position
			raise_window(panel)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(dragging): return
	if not dragging.is_visible_in_tree():
		dragging = null
		return
	if event is InputEventMouseMotion:
		_set_position(dragging, event.position - drag_offset)
		reflow(dragging)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		positions[str(dragging.get_meta("window_id"))] = dragging.position
		dragging = null
		get_viewport().set_input_as_handled()

func raise_window(panel: Control) -> void:
	panel.get_parent().move_child(panel, -1)

func _set_position(panel: Control, at: Vector2) -> void:
	if panel.anchor_left == 0.0 and panel.anchor_right == 0.0 and panel.anchor_top == 0.0 and panel.anchor_bottom == 0.0:
		panel.position = at
		return
	var dimensions := panel.size
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = at
	panel.size = dimensions

func reflow(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.visible: return
	var view := get_viewport().get_visible_rect().size
	var at := Vector2(clampf(panel.position.x, EDGE, maxf(EDGE, view.x - panel.size.x - EDGE)),
		clampf(panel.position.y, TOP, maxf(TOP, view.y - panel.size.y - EDGE)))
	if not panel.position.is_equal_approx(at): _set_position(panel, at)
	var id: String = str(panel.get_meta("window_id", ""))
	if positions.has(id): positions[id] = panel.position

func _resize() -> void:
	for panel in windows.values():
		if is_instance_valid(panel): reflow.call_deferred(panel)

func place_alert(panel: Control) -> void:
	if not is_instance_valid(panel): return
	var id: String = str(panel.get_meta("window_id"))
	if positions.has(id):
		_set_position(panel, positions[id])
		reflow(panel)
		raise_window(panel)
		return
	var view := get_viewport().get_visible_rect().size
	var candidates: Array[Vector2] = [panel.position]
	var blockers: Array[Rect2] = []
	for other in windows.values() + obstacles:
		if is_instance_valid(other) and other != panel and other.is_visible_in_tree():
			var rect: Rect2 = other.get_global_rect().grow(10.0)
			blockers.append(rect)
			candidates.append(Vector2(rect.end.x, rect.position.y))
			candidates.append(Vector2(rect.position.x - panel.size.x, rect.position.y))
			candidates.append(Vector2(rect.position.x, rect.end.y))
	for y in range(104, int(view.y), 48):
		for x in range(12, int(view.x), 64): candidates.append(Vector2(x, y))
	var best := panel.position
	var score := INF
	for candidate in candidates:
		var at := Vector2(clampf(candidate.x, EDGE, maxf(EDGE, view.x - panel.size.x - EDGE)), clampf(candidate.y, TOP, maxf(TOP, view.y - panel.size.y - EDGE)))
		var rect := Rect2(at, panel.size)
		var overlap := 0.0
		for block in blockers:
			var intersection := rect.intersection(block)
			overlap += intersection.get_area()
		if overlap < score:
			best = at
			score = overlap
		if score == 0.0: break
	_set_position(panel, best)
	raise_window(panel)
