extends Control
## The research tree: one row per branch, one column per era. Each discovery is
## a card showing its three development stages as pips; lines run from each
## prerequisite to what it opens. Colours: complete (green), in development
## (gold), in the queue (blue outline), available (slate), locked by era or a
## prerequisite (dark). Clicking a card selects it for the details pane.

signal picked(key: String)

const COL_W := 196.0
const CARD_W := 176.0
const CARD_H := 46.0
const GAP := 8.0
const LEFT := 132.0
const TOP := 34.0

var research: Node
var selected := ""
var _cards := {}   # key -> Rect2
var _row_top := {}
var _row_h := {}

func setup(r: Node) -> void:
	research = r
	layout()

func layout() -> void:
	_cards.clear()
	var y := TOP
	for branch in research.BRANCHES:
		var tallest := 1
		var per_era := {}
		for key in research.discoveries:
			if research.def_of(key).branch != branch:
				continue
			var e: int = research.era_of(key)
			per_era[e] = per_era.get(e, 0) + 1
			var slot: int = per_era[e] - 1
			_cards[key] = Rect2(LEFT + e * COL_W + (COL_W - CARD_W) * 0.5, y + slot * (CARD_H + GAP), CARD_W, CARD_H)
			tallest = maxi(tallest, per_era[e])
		_row_top[branch] = y
		_row_h[branch] = tallest * (CARD_H + GAP)
		y += tallest * (CARD_H + GAP) + 10.0
	custom_minimum_size = Vector2(LEFT + research.eras.size() * COL_W + 10.0, y + 6.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for key in _cards:
			if _cards[key].has_point(event.position):
				selected = key
				picked.emit(key)
				queue_redraw()
				accept_event()
				return

func _draw() -> void:
	if research == null:
		return
	var font := get_theme_default_font()
	# Era columns: the current era highlighted, later ones dimmed.
	for e in range(research.eras.size()):
		var x := LEFT + e * COL_W
		var current: bool = e == research.era
		draw_rect(Rect2(x + 2, 0, COL_W - 4, size.y), Color(1, 1, 1, 0.05 if current else (0.02 if e < research.era else 0.0)))
		var title: String = research.eras[e].name
		draw_string(font, Vector2(x + 8, 20), title, HORIZONTAL_ALIGNMENT_LEFT, COL_W - 12, 15,
			Color("f1e3b4") if current else (Color("9fb3a2") if e < research.era else Color("6d7a80")))
	# Branch labels and row separators.
	for branch in research.BRANCHES:
		var y: float = _row_top[branch]
		draw_line(Vector2(6, y - 5), Vector2(size.x - 6, y - 5), Color(1, 1, 1, 0.07))
		draw_string(font, Vector2(8, y + 18), research.BRANCH_NAMES[branch], HORIZONTAL_ALIGNMENT_LEFT, LEFT - 12, 14, Color("c9d2d6"))
	# Prerequisite lines under the cards.
	for key in _cards:
		var need = research.def_of(key).get("reqDiscovery")
		if need == null or not _cards.has(need):
			continue
		var a: Rect2 = _cards[need]
		var b: Rect2 = _cards[key]
		var from := Vector2(a.end.x, a.get_center().y)
		var to := Vector2(b.position.x, b.get_center().y)
		if b.position.x <= a.position.x:  # same era: drop down from the card
			from = Vector2(a.get_center().x, a.end.y)
			to = Vector2(b.get_center().x, b.position.y)
		var mid := (from.x + to.x) * 0.5
		var colour := Color("7fbf7a") if research.done(need) else Color(1, 1, 1, 0.22)
		draw_polyline(PackedVector2Array([from, Vector2(mid, from.y), Vector2(mid, to.y), to]), colour, 2.0)
	# Cards.
	for key in _cards:
		var r: Rect2 = _cards[key]
		var stage: int = research.stage_of(key)
		var active: bool = not research.queue.is_empty() and research.queue[0] == key
		var queued: bool = key in research.queue
		var why: String = research.blocker(key)
		var fill := Color("152437")
		if stage >= 3:
			fill = Color("27553a")
		elif active or stage > 0:
			fill = Color("5f4a1c")
		elif why == "" or why.contains(" needs a "):
			fill = Color("1e3349")
		else:
			fill = Color("101823")
		draw_rect(r, fill)
		# A hairline of light along the top edge, as on every plate.
		draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.10), 1.0)
		var border := Color("f2dfa9") if key == selected else (Color("7fb7e8") if queued else Color("8c7038"))
		draw_rect(r, border, false, 2.0 if key == selected or queued else 1.0)
		var locked: bool = stage == 0 and why != "" and not why.contains(" needs a ")
		draw_string(font, r.position + Vector2(7, 18), research.def_of(key).name, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 12, 13,
			Color("7d888c") if locked else Color("eef2f3"))
		# Three development stages as pips, the current one filling up.
		for s in range(3):
			var pip := Rect2(r.position + Vector2(7 + s * 38, 28), Vector2(34, 8))
			draw_rect(pip, Color(0, 0, 0, 0.35))
			if s < stage:
				draw_rect(pip, Color("8fd18a"))
			elif s == stage and stage < 3:
				var work: float = research.progress[key].work
				var need: float = research.stage_points(key, s)
				if work > 0.0:
					draw_rect(Rect2(pip.position, Vector2(pip.size.x * clampf(work / need, 0.0, 1.0), pip.size.y)), Color("e3c15a"))
		if queued:
			draw_string(font, r.position + Vector2(CARD_W - 22, 38), str(research.queue.find(key) + 1), HORIZONTAL_ALIGNMENT_LEFT, 20, 12, Color("7fb7e8"))
