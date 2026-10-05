extends Control
## Over the battlefield, under the panels: over the player's own units that
## stand idle for want of supplies, why: "NO FUEL", "NO AMMUNITION"
## (war_costs.gd sets unit.operating_shortage); over any unit in sight, its
## rank in gold chevrons (veterancy.gd) and a star for the general aboard
## (generals.gd). Health bars are health_overlay.gd's.

const FAR := 420.0            # beyond this camera distance no marker is drawn

var world: Node

func setup(world_node: Node) -> void:
	world = world_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if world != null and world.camera != null:
		queue_redraw()

static func shortage_text(reason: String) -> String:
	return {"fuel": "NO FUEL", "aviation fuel": "NO AVIATION FUEL", "ammunition budget": "NO AMMUNITION"}.get(reason, reason.to_upper())

func _draw() -> void:
	if world == null or world.camera == null:
		return
	var cam: Camera3D = world.camera
	var view := get_viewport_rect()
	var font := ThemeDB.fallback_font
	var fog = world.get("fog")
	for u in world.units:
		if u.dead or not u.node.visible:
			continue
		if int(u.get("rank", 0)) > 0 or u.has("general"):
			_insignia(u, cam, view, font, fog)
		if int(u.owner) != 0 or str(u.get("operating_shortage", "")) == "":
			continue
		var top: Vector3 = u.node.position + Vector3.UP * (3.4 if u.get("vehicle", false) else 2.6)
		if cam.is_position_behind(top) or cam.global_position.distance_to(top) > FAR:
			continue
		var p := cam.unproject_position(top)
		if not view.has_point(p):
			continue
		var text := shortage_text(str(u.operating_shortage))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var box := Rect2(p + Vector2(-width * 0.5 - 4, -30), Vector2(width + 8, 14))   # above the health bar
		draw_rect(box, Color(0.35, 0.06, 0.05, 0.85))
		draw_string(font, box.position + Vector2(4, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffd9cf"))

## Gold chevrons for a unit's rank, beside its health bar; a star and a name
## for a general aboard.
func _insignia(u: Dictionary, cam: Camera3D, view: Rect2, font: Font, fog) -> void:
	if fog != null and not fog.shows(u):
		return
	var top: Vector3 = u.node.position + Vector3.UP * (3.4 if u.get("vehicle", false) else 2.6)
	if cam.is_position_behind(top) or cam.global_position.distance_to(top) > FAR * 0.6:
		return
	var p := cam.unproject_position(top)
	if not view.has_point(p):
		return
	var gold := Color("e8c66a")
	var r: int = int(u.get("rank", 0))
	for i in range(r):
		var y := p.y - 14.0 - i * 4.0
		var x := p.x + 36.0
		draw_polyline(PackedVector2Array([Vector2(x - 5, y - 3), Vector2(x, y), Vector2(x + 5, y - 3)]), gold, 2.0)
	if u.has("general") and world.get("generals") != null and world.generals != null:
		var g = world.generals.general_of(u)
		if g != null:
			var star := PackedVector2Array()
			for k in range(10):
				var rad := 6.0 if k % 2 == 0 else 2.6
				var a := -PI / 2.0 + k * PI / 5.0
				star.append(p + Vector2(-44, -10) + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(star, gold)
			if int(u.owner) == 0:
				draw_string(font, p + Vector2(-36, -24), g.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)
