extends Control
## Quiet cartographic furniture on the opening screen, drawn at viewport size.
## Decorative only: never captures input or redraws during gameplay.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var ink := Color("c1af86", 0.075)
	for x in range(0, int(size.x), 96):
		draw_line(Vector2(x, 0), Vector2(x, size.y), ink, 1.0)
	for y in range(0, int(size.y), 96):
		draw_line(Vector2(0, y), Vector2(size.x, y), ink, 1.0)
	var centre := Vector2(size.x - 112, 112)
	var accent := Color("c1af86", 0.32)
	draw_arc(centre, 55, 0, TAU, 80, accent, 1.0, true)
	draw_arc(centre, 43, 0, TAU, 64, ink, 1.0, true)
	for i in range(8):
		var direction := Vector2.UP.rotated(i * PI / 4)
		draw_line(centre + direction * 35, centre + direction * 65, accent, 1.0, true)
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0,-48), centre + Vector2(8,0), centre + Vector2(0,15), centre + Vector2(-8,0)]), accent)
