extends Control
## Original cartographic ornament, drawn once behind the menu, no texture download.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var gold := Color(0.8,0.68,0.4,0.16)
	var center := Vector2(size.x*0.77,size.y*0.49)
	var radius := minf(size.x*0.24,size.y*0.38)
	for scale in [0.92,1.0,1.05]:
		draw_arc(center,radius*scale,0,TAU,128,gold,1.0,true)
	for i in range(72):
		var direction := Vector2.from_angle(i*TAU/72)
		draw_line(center+direction*radius,center+direction*radius*(0.94 if i%6==0 else 0.98),gold,1.0,true)
	for i in range(8):
		var direction := Vector2.from_angle(i*TAU/8)
		var side := direction.orthogonal()
		var tip := center+direction*radius*(0.82 if i%2==0 else 0.48)
		draw_colored_polygon(PackedVector2Array([center,center+side*radius*0.05,tip]),Color(0.8,0.68,0.4,0.10))
		draw_polyline(PackedVector2Array([center-side*radius*0.05,tip,center+side*radius*0.05]),gold,1.0,true)
	for y in range(80,int(size.y),80):
		draw_line(Vector2(size.x*0.48,y),Vector2(size.x-24,y),Color(0.8,0.68,0.4,0.035),1.0)
