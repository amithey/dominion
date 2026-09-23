extends Control
## The island in the corner: terrain shaded from the height grid (deep and
## shallow water, beach, grass, hills, rock), every building and unit as a dot
## in its nation's colour, and the camera's view as a gold wedge. Click or drag
## on it to move the camera there. Redrawn four times a second.

var world: Node
var _terrain: ImageTexture
var _half := 320.0
var _refresh := 0.0

func setup(world_node: Node) -> void:
	world = world_node
	_half = float(world.map.mapSize) * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	var n := 160
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sea := float(world.map.seaLevel)
	for y in range(n):
		for x in range(n):
			var wx := -_half + (x + 0.5) / n * _half * 2.0
			var wz := -_half + (y + 0.5) / n * _half * 2.0
			var h: float = world.height_at(wx, wz) - sea
			var c: Color
			if h < -6.0:
				c = Color("12334a")
			elif h < 0.0:
				c = Color("1f5f73").lerp(Color("12334a"), clampf(-h / 6.0, 0.0, 1.0))
			elif h < 1.2:
				c = Color("b7a877")
			elif h < 9.0:
				c = Color("4e7a3a").lerp(Color("6c8a45"), h / 9.0)
			else:
				c = Color("6c8a45").lerp(Color("8a8579"), clampf((h - 9.0) / 10.0, 0.0, 1.0))
			# A little hill shading from the slope.
			var slope: float = world.height_at(wx + 3.0, wz + 3.0) - world.height_at(wx, wz)
			c = c.lightened(clampf(slope * 0.05, 0.0, 0.2)) if slope > 0.0 else c.darkened(clampf(-slope * 0.05, 0.0, 0.2))
			img.set_pixel(x, y, c)
	_terrain = ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	_refresh += delta
	if _refresh > 0.25:
		_refresh = 0.0
		queue_redraw()

func to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + _half) / (_half * 2.0), (p.z + _half) / (_half * 2.0)) * size

func to_world(point: Vector2) -> Vector3:
	var f := point / size
	return Vector3(-_half + f.x * _half * 2.0, 0, -_half + f.y * _half * 2.0)

func _draw() -> void:
	if world == null or _terrain == null:
		return
	draw_texture_rect(_terrain, Rect2(Vector2.ZERO, size), false)
	var colours := []
	for n in world.map.nations:
		colours.append(Color(n.color).lightened(0.2))
	# Territory: every held cell washed in its owner's colour, fronts in gold.
	var t: Node = world.territory
	if t != null:
		var cell_px := size / float(t.cols)
		for i in range(t.owner_of.size()):
			var o: int = t.owner_of[i]
			if o < 0:
				continue
			var r := Rect2(Vector2(i % t.cols, i / t.cols) * cell_px, cell_px)
			draw_rect(r, Color(1.0, 0.84, 0.42, 0.35) if t.contested[i] else Color(colours[o % colours.size()], 0.26))
	for b in world.buildings:
		if b.dead:
			continue
		var p := to_map(b.root.position)
		var s := 5.0 if b.key in ["hq", "cityCenter", "villageCenter"] else 3.5
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), colours[b.owner % colours.size()])
		if b.key == "hq":
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color.WHITE, false, 1.0)
	for u in world.units:
		if u.dead:
			continue
		draw_circle(to_map(u.node.position), 1.6 if not u.vehicle else 2.0, colours[u.owner % colours.size()])
	var pts := camera_outline()
	if pts.size()==4:
		pts.append(pts[0])
		draw_polyline(pts, Color("f1d98a"), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color("8c7644"), false, 1.0)

func camera_outline() -> PackedVector2Array:
	var result := PackedVector2Array()
	var viewport: Vector2 = world.get_viewport().get_visible_rect().size
	var plane := Plane(Vector3.UP,world.height_at(world.cam_focus.x,world.cam_focus.z))
	for corner in [Vector2.ZERO,Vector2(viewport.x,0),viewport,Vector2(0,viewport.y)]:
		var origin: Vector3 = world.camera.project_ray_origin(corner)
		var ray: Vector3 = world.camera.project_ray_normal(corner)
		var at = plane.intersects_ray(origin,ray)
		if at == null:
			at = origin+ray*world.camera.far
		result.append(to_map(at).clamp(Vector2.ZERO,size))
	return result

func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		var p := to_world(event.position)
		world.cam_focus = Vector3(p.x, world.cam_focus.y, p.z)
		world.clamp_camera()
		queue_redraw()
		accept_event()
