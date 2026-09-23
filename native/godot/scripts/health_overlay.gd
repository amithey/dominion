extends Control
var world: Node
var elapsed := 0.0
var _placed: Array[Rect2] = []   # bars already drawn this frame, so the next one steps clear
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
	# In a melee the bars would pile into one unreadable block: each steps up
	# above any bar it would cover (a few steps at most, then it is drawn anyway).
	# The footprint includes the frame and the owner tab, so neighbours never touch.
	var foot := Rect2(rect.position - Vector2(9, 3), rect.size + Vector2(12, 6))
	for attempt in range(8):
		var clash := false
		for other in _placed:
			if other.intersects(foot):
				clash = true
				foot.position.y = other.position.y - foot.size.y - 1
				break
		if not clash:
			break
	rect.position.y = foot.position.y + 3
	_placed.append(foot)
	draw_rect(rect.grow(2), Color("101721"))
	# The owner's colour on a small tab at the left, as 4X unit flags carry it.
	var owner: int = ent.get("owner", 0)
	if owner < world.map.nations.size():
		draw_rect(Rect2(rect.position - Vector2(7, 2), Vector2(5, 12)), Color(world.map.nations[owner].color))
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
	_placed.clear()
	for ent in world.units:
		_bar(ent, eye, screen_rect, 3.0)
	for ent in world.buildings:
		_bar(ent, eye, screen_rect, 9.0)
	world.spent("health bars", clock)
