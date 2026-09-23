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
func _bar(ent: Dictionary, eye: Vector3, screen_rect: Rect2, lift: float) -> void:
	# Only what has been hurt carries a bar: an untouched unit shows nothing,
	# selected or not, so a healthy army does not clutter the battlefield.
	var selected: bool = ent.get("selected", false)
	if ent.dead or ent.hp >= ent.max_hp:
		return
	var p: Vector3 = ent.node.position + Vector3.UP * lift
	if (eye.distance_to(p) > 130.0 and world.perf_opts) or world.camera.is_position_behind(p):
		return
	var screen: Vector2 = world.camera.unproject_position(p)
	if not screen_rect.has_point(screen):
		return
	var ratio := clampf(float(ent.hp) / ent.max_hp, 0, 1)
	var rect := Rect2(screen - Vector2(30, 0), Vector2(60, 8))
	draw_rect(rect.grow(2), Color("101721"))
	draw_rect(Rect2(rect.position, Vector2(60 * ratio, 8)), Color("79c98a") if ratio > 0.5 else (Color("e2bd65") if ratio > 0.25 else Color("e97465")))
	draw_rect(rect, Color("d9cfb1"), false, 1)
	if selected or not world.perf_opts:
		for i in range(1, 5):
			draw_line(rect.position + Vector2(i * 12, 0), rect.position + Vector2(i * 12, 8), Color(0, 0, 0, 0.45))

func _draw() -> void:
	if world == null or world.camera == null:
		return
	var clock: int = world.clock()
	# Only what the player can actually read: hurt, in front of the camera, on
	# screen and within 130 m. Ticks are drawn on selected units only, which
	# keeps a big battle from costing hundreds of strokes a frame.
	var eye: Vector3 = world.camera.global_position
	var screen_rect := Rect2(Vector2(-40, -20), size + Vector2(80, 40))
	for ent in world.units:
		_bar(ent, eye, screen_rect, 3.0)
	for ent in world.buildings:
		_bar(ent, eye, screen_rect, 9.0)
	world.spent("health bars", clock)
