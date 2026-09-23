## A round portrait medallion in the 4X manner: the picture is clipped to a
## disc lit from above, and a bronze-and-gold ring is laid over its edge.
## Put the picture (a TextureRect) in as the first child; the ring is drawn
## by a child added here, so it always sits on top.
extends Control

const UI := preload("res://scripts/ui_theme.gd")

var tint := Color("20324d")   # the disc behind the picture; the owner's colour can be set here

class Ring extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_arc(c, r - 1.5, 0, TAU, 96, UI.INK, 3.0, true)
		draw_arc(c, r - 4.5, 0, TAU, 96, UI.TRIM, 3.5, true)
		draw_arc(c, r - 4.0, PI * 1.05, PI * 1.95, 48, UI.BRIGHT, 1.4, true)   # the lit upper edge
		draw_arc(c, r - 7.0, 0, TAU, 96, Color(UI.GOLD, 0.9), 1.2, true)
		draw_arc(c, r - 8.5, 0, TAU, 96, Color(0, 0, 0, 0.55), 1.5, true)

func _ready() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := Ring.new()
	add_child(ring)

func set_tint(colour: Color) -> void:
	tint = colour
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	# A disc lit from above: darker rim, brighter crown.
	draw_circle(c, r, tint.darkened(0.45), true, -1.0, true)
	draw_circle(c - Vector2(0, r * 0.18), r * 0.78, tint, true, -1.0, true)
	draw_circle(c - Vector2(0, r * 0.32), r * 0.45, tint.lightened(0.12), true, -1.0, true)
