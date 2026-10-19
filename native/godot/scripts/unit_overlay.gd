extends Control
## Over the battlefield, under the panels: over the player's own units that
## stand idle for want of supplies, why: "NO FUEL", "NO AMMUNITION"
## (war_costs.gd sets unit.operating_shortage); over any unit in sight, its
## rank in gold chevrons (veterancy.gd) and a star for the general aboard
## (generals.gd). Health bars are health_overlay.gd's.

const FAR := 420.0            # beyond this camera distance no marker is drawn

var world: Node
var _elapsed := 0.0
var _badge_styles: Dictionary = {}
var _widths: Dictionary = {}   # "size:text" -> pixel width (measuring text is slow; the labels repeat)
const ROLE_INDEX := {"W": 0, "SEA": 1, "AIR": 2, "ART": 3, "AA": 4, "ARM": 5, "INF": 6}

func text_width(font: Font, text: String, size: int) -> float:
	var key := "%d:%s" % [size, text]
	if not _widths.has(key):
		if _widths.size() > 400: _widths.clear()
		_widths[key] = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return float(_widths[key])

func badge_style(selected: bool) -> StyleBoxFlat:
	if not _badge_styles.has(selected):
		_badge_styles[selected] = preload("res://scripts/ui_theme.gd").box(Color("142c3d"), Color("f0d690") if selected else Color("526b7c"), 1, 4, 0.0, 2)
	return _badge_styles[selected]

func setup(world_node: Node) -> void:
	world = world_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if _elapsed >= 0.1 and world != null and world.camera != null:
		_elapsed = 0.0
		queue_redraw()

## Readable roles at strategy distance; shape and lettering supplement owner colour.
static func role_of(u: Dictionary) -> String:
	var key := str(u.get("key", ""))
	if key == "worker": return "W"
	if u.get("naval", false): return "SEA"
	if u.get("fly", false): return "AIR"
	if key in ["artillery", "mlrs", "himars", "tos1a", "k9", "heavyRocket", "mortarTeam", "towedHowitzer", "wheeledHowitzer"]: return "ART"
	if key in ["aaVehicle", "samLauncher", "manpads", "laserAD", "irisT", "abmLauncher", "saudiThaad", "hpmVehicle", "shortRangeSAM"]: return "AA"
	return "ARM" if u.get("vehicle", false) else "INF"

func role_markers() -> Array:
	var result := []
	if world == null or world.camera == null: return result
	var cam: Camera3D = world.camera
	var occupied := {}
	# Selected units win a crowded cell. Different roles/owners keep separate badges.
	for selected in [true, false]:
		for u in world.units:
			if bool(u.get("selected", false)) != selected or u.dead or u.get("stowed", false) or not u.node.visible: continue
			if world.get("fog") != null and not world.fog.shows(u): continue
			var at: Vector3 = u.node.get_global_transform_interpolated().origin + Vector3.UP * 3.5
			var distance := cam.global_position.distance_to(at)
			if distance > FAR or (distance < 85.0 and not selected) or cam.is_position_behind(at): continue
			var p := cam.unproject_position(at) + Vector2(0, -20)
			if not get_viewport_rect().has_point(p): continue
			var role := role_of(u)
			var cell: int = ((floori(p.x / 36.0) + 512) << 24) | ((floori(p.y / 26.0) + 512) << 14) | (int(u.owner) << 6) | int(ROLE_INDEX.get(role, 7))
			if occupied.has(cell):
				result[occupied[cell]].count += 1
				continue
			occupied[cell] = result.size()
			result.append({"at": p, "role": role, "owner": int(u.owner), "selected": selected, "count": 1})
	return result

var _lines: Dictionary = {}   # "size:text" -> a shaped TextLine (draw_string shapes its text on every call)

func _draw_label(font: Font, text: String, size: int, baseline: Vector2, colour: Color) -> void:
	var key := "%d:%s" % [size, text]
	if not _lines.has(key):
		if _lines.size() > 400: _lines.clear()
		var line := TextLine.new()
		line.add_string(text, font, size)
		_lines[key] = line
	var line: TextLine = _lines[key]
	line.draw(get_canvas_item(), baseline - Vector2(0, line.get_line_ascent()), colour)

## Badges that would overlap are stacked upward. Placed boxes are filed by
## screen cell, so a badge is tested only against its neighbours (testing every
## placed box made eighty badges cost ten times as much).
func _roles(font: Font) -> void:
	var grid: Dictionary = {}
	var colours: Dictionary = {}
	for mark in role_markers():
		var text: String = mark.role + (" ×%d" % mark.count if mark.count > 1 else "")
		var width := text_width(font, text, 12) + 10
		var box := Rect2(mark.at - Vector2(width * 0.5, 9), Vector2(width, 18))
		for attempt in range(8):
			var clash := false
			var probe := box.grow(2)
			for cx in range(floori(probe.position.x / 48.0), floori(probe.end.x / 48.0) + 1):
				for cy in range(floori(probe.position.y / 24.0), floori(probe.end.y / 24.0) + 1):
					var here: Array = grid.get((cx + 64) * 4096 + cy + 64, [])
					for other in here:
						if other.grow(2).intersects(box):
							clash = true
							break
					if clash: break
				if clash: break
			if not clash: break
			box.position.y -= 21.0
		for cx in range(floori(box.position.x / 48.0), floori(box.end.x / 48.0) + 1):
			for cy in range(floori(box.position.y / 24.0), floori(box.end.y / 24.0) + 1):
				var k: int = (cx + 64) * 4096 + cy + 64
				if not grid.has(k): grid[k] = []
				grid[k].append(box)
		# (two plain rectangles: a rounded, bordered style box is tessellated on every
		# call and cost more than all the rest of the badge)
		var style := badge_style(mark.selected)
		draw_rect(box, style.border_color)
		draw_rect(box.grow(-1.0), style.bg_color)
		if not colours.has(mark.owner): colours[mark.owner] = Color(world.map.nations[mark.owner].color)
		draw_rect(Rect2(box.position, Vector2(3, 18)), colours[mark.owner])
		_draw_label(font, text, 12, box.position + Vector2(6, 13), Color("f5ecd8"))

static func shortage_text(reason: String) -> String:
	return {"fuel": "NO FUEL", "aviation fuel": "NO AVIATION FUEL", "ammunition budget": "NO AMMUNITION"}.get(reason, reason.to_upper())

## A full district pad appears as soon as it is ordered. Explain what is
## still being built without requiring the player to select every site.
func construction_markers() -> Array:
	var out := []
	if world == null or world.camera == null: return out
	for b in world.buildings:
		if b.dead or b.built or b.owner != 0 or not b.root.is_visible_in_tree(): continue
		if world.get("fog") != null and not world.fog.shows(b): continue
		var at: Vector3 = b.root.position + Vector3.UP * 7.0
		if world.camera.is_position_behind(at) or world.camera.global_position.distance_to(at) > FAR: continue
		var screen: Vector2 = world.camera.unproject_position(at)
		if not get_viewport_rect().has_point(screen): continue
		var status := "BUILDING"
		if int(b.get("builders", 0)) == 0 and not b.def.get("water", false):
			var assigned: bool = world.units.any(func(u): return not u.dead and is_same(u.get("build_site"), b))
			status = "WORKER EN ROUTE" if assigned else "NEEDS WORKER"
		out.append({"at":screen, "status":status, "progress":clampf(float(b.progress), 0.0, 1.0)})
	return out

func _construction(font: Font) -> void:
	for mark in construction_markers():
		var text := "%s · %d%%" % [mark.status, mini(99, floori(mark.progress * 100.0))]
		var width := text_width(font, text, 13) + 16.0
		var box := Rect2(mark.at - Vector2(width * 0.5, 20), Vector2(width, 24))
		var accent := Color("e89a78") if mark.status == "NEEDS WORKER" else Color("e8c66a")
		draw_rect(box.grow(1), Color("0b151e"))
		draw_rect(box, Color("162833"))
		draw_string(font, box.position + Vector2(8, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
		draw_rect(Rect2(box.position + Vector2(0, 21), Vector2(width, 3)), Color("33414b"))
		draw_rect(Rect2(box.position + Vector2(0, 21), Vector2(width * mark.progress, 3)), accent)

func _draw() -> void:
	if world == null or world.camera == null:
		return
	var cam: Camera3D = world.camera
	var view := get_viewport_rect()
	var font := ThemeDB.fallback_font
	var fog = world.get("fog")
	_roles(font)
	_construction(font)
	for u in world.units:
		# (cheap tests first: most units have neither rank nor shortage)
		var ranked: bool = int(u.get("rank", 0)) > 0 or u.has("general")
		var short: bool = int(u.owner) == 0 and str(u.get("operating_shortage", "")) != ""
		if not (ranked or short) or u.dead or u.get("stowed", false) or not u.node.visible:
			continue
		if ranked:
			_insignia(u, cam, view, font, fog)
		if not short:
			continue
		var top: Vector3 = u.node.get_global_transform_interpolated().origin + Vector3.UP * (3.4 if u.get("vehicle", false) else 2.6)
		if cam.is_position_behind(top) or cam.global_position.distance_to(top) > FAR:
			continue
		var p := cam.unproject_position(top)
		if not view.has_point(p):
			continue
		var text := shortage_text(str(u.operating_shortage))
		var width := text_width(font, text, 11)
		var box := Rect2(p + Vector2(-width * 0.5 - 4, -54), Vector2(width + 8, 14))   # above role and health
		draw_rect(box, Color(0.35, 0.06, 0.05, 0.85))
		draw_string(font, box.position + Vector2(4, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffd9cf"))

## Gold chevrons for a unit's rank, beside its health bar; a star and a name
## for a general aboard.
func _insignia(u: Dictionary, cam: Camera3D, view: Rect2, font: Font, fog) -> void:
	if fog != null and not fog.shows(u):
		return
	var top: Vector3 = u.node.get_global_transform_interpolated().origin + Vector3.UP * (3.4 if u.get("vehicle", false) else 2.6)
	if cam.is_position_behind(top) or cam.global_position.distance_to(top) > FAR * 0.6:
		return
	var p := cam.unproject_position(top)
	if not view.has_point(p):
		return
	var gold := Color("e8c66a")
	var r: int = int(u.get("rank", 0))
	for i in range(r):
		var y := p.y - 14.0 - i * 4.0
		var x := p.x + 27.0   # just right of the 40-pixel health bar
		draw_polyline(PackedVector2Array([Vector2(x - 5, y - 3), Vector2(x, y), Vector2(x + 5, y - 3)]), gold, 2.0)
	if u.has("general") and world.get("generals") != null and world.generals != null:
		var g = world.generals.general_of(u)
		if g != null:
			var star := PackedVector2Array()
			for k in range(10):
				var rad := 6.0 if k % 2 == 0 else 2.6
				var a := -PI / 2.0 + k * PI / 5.0
				star.append(p + Vector2(-33, -10) + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(star, gold)
			if int(u.owner) == 0:
				draw_string(font, p + Vector2(-26, -24), g.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)
