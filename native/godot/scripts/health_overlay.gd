extends Control
var world: Node
var elapsed := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 0.1:
		elapsed = 0
		queue_redraw()
func _draw() -> void:
	if world == null or world.camera == null:
		return
	for ent in world.units+world.buildings:
		if ent.dead or (ent.hp >= ent.max_hp and not ent.get("selected",false)):
			continue
		var p: Vector3 = ent.node.position+Vector3.UP*(9 if ent.get("is_building",false) else 3)
		if world.camera.is_position_behind(p):
			continue
		var screen: Vector2 = world.camera.unproject_position(p)
		if not Rect2(Vector2.ZERO,size).has_point(screen):
			continue
		var ratio := clampf(float(ent.hp)/ent.max_hp,0,1)
		var rect := Rect2(screen-Vector2(30,0),Vector2(60,8))
		draw_rect(rect.grow(2),Color("101721"))
		draw_rect(Rect2(rect.position,Vector2(60*ratio,8)),Color("79c98a") if ratio>0.5 else (Color("e2bd65") if ratio>0.25 else Color("e97465")))
		draw_rect(rect,Color("d9cfb1"),false,1)
		for i in range(1,5):
			draw_line(rect.position+Vector2(i*12,0),rect.position+Vector2(i*12,8),Color(0,0,0,0.45))
