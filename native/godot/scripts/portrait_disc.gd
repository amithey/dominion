extends Control
## The circular mask clips only the portrait; the parent button draws its ring.

func _init() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Color.WHITE, true, -1.0, true)
