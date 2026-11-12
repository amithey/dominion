extends Control
## The island in the corner: terrain shaded from the height grid (deep and
## shallow water, beach, grass, hills, rock), every building and unit as a dot
## in its nation's colour, and the camera's view as a gold wedge. Click or drag
## on it to move the camera there. Redrawn four times a second.
##
## The map turns with the camera, so what is at the top of the screen is at
## the top of the map and the view wedge always points straight up; a gold
## needle on the rim marks north.

var world: Node
var _terrain: ImageTexture
var _half := 320.0
var _refresh := 0.0
var _fit := 1.0     # the island is scaled so no land is cut off at any angle
const SEA := Color("17474d")

func setup(world_node: Node) -> void:
	world = world_node
	_half = float(world.map.mapSize) * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true  # the view wedge is cut at the frame, never drawn over it
	var n := 160
	var far := 0.0  # the land pixel farthest from the centre, as a fraction of the half-width
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sea := float(world.map.seaLevel)
	for y in range(n):
		for x in range(n):
			var wx := -_half + (x + 0.5) / n * _half * 2.0
			var wz := -_half + (y + 0.5) / n * _half * 2.0
			var h: float = world.height_at(wx, wz) - sea
			var c: Color
			if h < -6.0:
				c = Color("17474d")
			elif h < 0.0:
				c = Color("277378").lerp(Color("17474d"), clampf(-h / 6.0, 0.0, 1.0))
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
			if h > 0.0:
				far = maxf(far, Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5))
	_terrain = ImageTexture.create_from_image(img)
	_fit = clampf(0.96 / maxf(far, 0.01), 0.68, 1.0)

var _territory_mesh: ArrayMesh
var _territory_key := 0

## Every held hex as six triangles with the owner's wash as a vertex colour.
func _build_territory(t: Node, colours: Array) -> ArrayMesh:
	var corners := PackedVector2Array()
	for k in range(6):
		var a := PI / 6.0 + k * PI / 3.0
		corners.append(Vector2(cos(a), sin(a)) * t.hex)
	var vertices := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	for i in range(t.owner_of.size()):
		var o: int = t.owner_of[i]
		if o < 0:
			continue
		var centre: Vector3 = t.center(i)
		var base := vertices.size()
		vertices.append(to_map(Vector3(centre.x, 0, centre.z)))
		var shade := Color(1.0, 0.84, 0.42, 0.35) if t.contested[i] else Color(colours[o % colours.size()], 0.26)
		shades.append(shade)
		for k in range(6):
			vertices.append(to_map(Vector3(centre.x + corners[k].x, 0, centre.z + corners[k].y)))
			shades.append(shade)
		for k in range(6):
			indices.append_array(PackedInt32Array([base, base + 1 + k, base + 1 + (k + 1) % 6]))
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = shades
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _process(delta: float) -> void:
	_refresh += delta
	var pinging: bool = world != null and world.get("sitrep") != null and not world.sitrep.pings.is_empty()
	if _refresh > (0.1 if pinging else 0.25):
		_refresh = 0.0
		queue_redraw()

func to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + _half) / (_half * 2.0), (p.z + _half) / (_half * 2.0)) * size

## Map space (north up) to the turned picture on screen.
func view_transform() -> Transform2D:
	var centre := size * 0.5
	var yaw: float = world.cam_yaw if world != null else 0.0
	return Transform2D(yaw, Vector2(_fit, _fit), 0.0, centre) * Transform2D(0.0, -centre)

func to_world(point: Vector2) -> Vector3:
	var f := view_transform().affine_inverse() * point / size
	return Vector3(-_half + f.x * _half * 2.0, 0, -_half + f.y * _half * 2.0)

func _draw() -> void:
	if world == null or _terrain == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	var xf := view_transform()
	draw_set_transform_matrix(xf)
	draw_texture_rect(_terrain, Rect2(Vector2.ZERO, size), false)
	# A quiet cartographic grid stays underneath fog and all tactical symbols.
	for tick in range(1, 4):
		var at := size * float(tick) / 4.0
		draw_line(Vector2(at.x, 0), Vector2(at.x, size.y), Color(0.8, 0.9, 1.0, 0.08))
		draw_line(Vector2(0, at.y), Vector2(size.x, at.y), Color(0.8, 0.9, 1.0, 0.08))
	var colours := []
	for n in world.map.nations:
		colours.append(Color(n.color).lightened(0.2))
	# Territory: every held cell washed in its owner's colour, fronts in gold. One
	# mesh, rebuilt only when ownership changes (polygon by polygon it cost
	# 15 ms a redraw).
	var t: Node = world.territory
	if t != null:
		var key: int = hash([hash(t.owner_of), hash(t.contested), size, colours.size()])
		if _territory_mesh == null or key != _territory_key:
			_territory_key = key
			_territory_mesh = _build_territory(t, colours)
		if _territory_mesh != null:
			draw_mesh(_territory_mesh, null)
	# Fog of war (fog_of_war.gd): land never seen dark, land not watched now grey.
	var fog = world.get("fog")
	if fog != null and fog.enabled:
		var corner := to_map(Vector3(fog.origin.x, 0, fog.origin.y))
		var far := to_map(Vector3(fog.origin.x + fog.n * fog.CELL, 0, fog.origin.y + fog.n * fog.CELL))
		draw_texture_rect(fog.texture, Rect2(corner, far - corner), false)
	var lenses = world.get("map_lenses")
	for b in world.buildings:
		if b.dead or (fog != null and not fog.shows(b)):
			continue
		var p := to_map(b.root.position)
		var s := 5.0 if b.key in ["hq", "cityCenter", "villageCenter"] else 3.5
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)).grow(1), Color("0b1b1d"))
		var bcol: Color = colours[b.owner % colours.size()]
		if lenses != null:
			bcol = lenses.building_minimap_color(b, bcol)
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), bcol)
		if b.key == "hq":
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color.WHITE, false, 1.0)
	for aircraft in world.units:
		if aircraft.dead or not aircraft.selected or aircraft.owner != 0 or not aircraft.get("fly", false):
			continue
		var radius: float = world.AirOperations.action_radius(aircraft)
		if radius > 0.0:
			var outline := PackedVector2Array()
			var centre: Vector3 = aircraft.node.position
			for step in range(49):
				var angle := TAU * float(step) / 48.0
				outline.append(to_map(centre + Vector3(cos(angle), 0.0, sin(angle)) * radius))
			draw_polyline(outline, Color(0.45, 0.8, 1.0, 0.5), 1.0, true)
		break
	for u in world.units:
		if u.dead or (fog != null and not fog.shows(u)):
			continue
		var p := to_map(u.node.position)
		var ink: Color = colours[u.owner % colours.size()]
		# (rectangles and bare primitives: a circle is tessellated on every call, and
		# a hundred units' worth cost 12 ms a redraw)
		if u.get("selected", false): draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color("f4ead4"), false, 1.0)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("0b1b1d"))
		if u.get("fly", false):
			draw_primitive(PackedVector2Array([p + Vector2(0,-3), p + Vector2(2.5,2), p + Vector2(-2.5,2)]), PackedColorArray([ink, ink, ink]), PackedVector2Array())
		elif u.get("naval", false):
			draw_primitive(PackedVector2Array([p + Vector2(0,-3), p + Vector2(2,0), p + Vector2(0,3), p + Vector2(-2,0)]), PackedColorArray([ink, ink, ink, ink]), PackedVector2Array())
		else:
			var r := 1.6 if not u.vehicle else 2.0
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), ink)
	# Where you are being hit: a ring that opens and fades (sitrep.gd), red for the serious ones.
	var report = world.get("sitrep")
	if report != null:
		for ping in report.active_pings(5.0):
			var age: float = clampf((float(world.game_time) - float(ping.born)) / 5.0, 0.0, 1.0)
			var at := to_map(ping.pos)
			var tint := Color("ff5a44") if ping.crit else Color("f1c86a")
			tint.a = (1.0 - age) * 0.95
			draw_arc(at, 4.0 + age * 15.0, 0.0, TAU, 20, tint, 2.0)
			draw_arc(at, 2.0 + age * 7.0, 0.0, TAU, 14, tint, 1.5)
	var pulse := fmod(float(world.game_time) * 0.9, 1.0)
	for cp in _crisis_points():
		var cat := to_map(cp.pos)
		var ctint: Color = cp.color
		ctint.a = (1.0 - pulse) * 0.9
		draw_arc(cat, 3.0 + pulse * 10.0, 0.0, TAU, 16, ctint, 1.8)
		draw_circle(cat, 2.2, Color(cp.color, 0.92))
	# The camera: the ground it sees as a wedge, an arrow at the far edge for the
	# direction it is looking, and a dot where the view is centred.
	var pts := camera_outline()
	if pts.size()==4:
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.52, 0.10))
		var ring := PackedVector2Array(pts)
		ring.append(pts[0])
		draw_polyline(ring, Color("f1d98a"), 1.5)
		var near := (pts[0] + pts[1]) * 0.5
		var far := (pts[2] + pts[3]) * 0.5
		if near.distance_to(far) > 4.0:
			var forward := (far - near).normalized()
			var side := Vector2(-forward.y, forward.x) * 3.6
			draw_colored_polygon(PackedVector2Array([far + forward * 5.5, far + side, far - side]), Color("f1d98a"))
		draw_circle(to_map(world.cam_focus), 1.8, Color("f1d98a"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# North: a needle on the rim, where the map's top edge now points.
	var north := xf.basis_xform(Vector2(0, -1)).normalized()
	var c := size * 0.5
	var rim := minf(c.x / maxf(absf(north.x), 0.001), c.y / maxf(absf(north.y), 0.001)) - 9.0
	var tip := c + north * rim
	var across := Vector2(-north.y, north.x)
	draw_colored_polygon(PackedVector2Array([tip + north * 6.0, tip + across * 4.0, tip - across * 4.0]), Color("f1d98a"))
	var font := ThemeDB.fallback_font
	draw_string(font, tip - north * 9.0 + Vector2(-4, 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f6ecd4"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("8c7644"), false, 1.0)

## The patch of ground the camera sees, as four points running round the wedge:
## the two near corners first, then the two far ones. A ray through a top corner
## of the screen passes above the horizon and never meets the ground, so it is
## stopped at a sensible distance instead of running out to the far plane and
## folding the wedge into the corner of the map.
func camera_outline() -> PackedVector2Array:
	var result := PackedVector2Array()
	var viewport: Vector2 = world.get_viewport().get_visible_rect().size
	var plane := Plane(Vector3.UP,world.height_at(world.cam_focus.x,world.cam_focus.z))
	var reach: float = maxf(world.cam_dist,40.0) * 3.0
	for corner in [Vector2(0.0,viewport.y),viewport,Vector2(viewport.x,0.0),Vector2.ZERO]:
		var origin: Vector3 = world.camera.project_ray_origin(corner)
		var ray: Vector3 = world.camera.project_ray_normal(corner)
		var at = plane.intersects_ray(origin,ray)
		if at == null or origin.distance_to(at) > reach:
			at = origin + ray * reach
		result.append(to_map(at))
	return result

func _crisis_points() -> Array:
	var out := []
	if world == null:
		return out
	for b in world.buildings:
		if not b.dead and int(b.owner) == 0 and float(b.get("fire", 0.0)) > 0.02:
			out.append({"pos": b.root.position, "color": Color(1.0, 0.34, 0.14)})
	for m in (world.missiles.flying if world.get("missiles") != null and world.missiles.get("flying") != null else []):
		if m.get("node") != null and is_instance_valid(m.node):
			out.append({"pos": m.node.position, "color": Color(1.0, 0.18, 0.22)})
	if world.get("logistics") != null:
		for e in world.logistics.edges.values():   # a cut road or railway: the middle of the link between its two hexes
			if int(e.owner) == 0 and float(e.hp) <= 0.0:
				out.append({"pos": (world.logistics.hex_center(e.a) + world.logistics.hex_center(e.b)) * 0.5, "color": Color(0.96, 0.72, 0.20)})
	return out

func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if press or drag:
		var p := to_world(event.position)
		if press:
			var click_pos: Vector2 = event.position as Vector2
			var best_d := 14.0
			var report = world.get("sitrep")
			if report != null:
				for ping in report.active_pings(5.0):
					var d: float = click_pos.distance_to(to_map(ping.pos))
					if d < best_d:
						best_d = d
						p = ping.pos
			for cp in _crisis_points():
				var d: float = click_pos.distance_to(to_map(cp.pos))
				if d < best_d:
					best_d = d
					p = cp.pos
		world.cam_focus = Vector3(p.x, world.cam_focus.y, p.z)
		world.clamp_camera()
		queue_redraw()
		accept_event()
