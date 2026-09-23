extends Control
## A cinematic menu backdrop. The artwork stays opaque over the live world;
## slow camera drift and dust animate only while the main menu is visible.

const ART := preload("res://ui/backgrounds/war-table-v1.png")
var _time := 0.0
var _frame := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()

func _visibility_changed() -> void:
	set_process(is_visible_in_tree())
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_frame += delta
	if _frame >= 1.0 / 30.0:
		_frame = 0.0
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Cover any aspect ratio, with enough overscan that the slow drift never
	# exposes an edge. The interface itself stays still for easy targeting.
	var art_size := Vector2(ART.get_size())
	var zoom := maxf(size.x / art_size.x, size.y / art_size.y) * 1.035
	var extent := art_size * zoom
	var drift := Vector2(sin(_time * 0.045), cos(_time * 0.038)) * size * 0.004
	draw_texture_rect(ART, Rect2((size - extent) * 0.5 + drift, extent), false)
	# Sparse, slow dust motes in the window light. Deterministic placement
	# avoids random flicker; opacity fades before a particle wraps.
	for i in range(34):
		var phase := fposmod(float(i) * 0.618034 + _time * 0.009, 1.0)
		var x := (0.45 + fposmod(float(i) * 0.381966, 0.49)) * size.x
		x += sin(_time * 0.16 + float(i)) * 9.0
		var y := (0.12 + (1.0 - phase) * 0.74) * size.y
		var alpha := sin(phase * PI) * (0.12 + float(i % 3) * 0.045)
		draw_circle(Vector2(x, y), 0.65 + float(i % 3) * 0.35, Color(1.0, 0.86, 0.62, alpha))
