extends Control
## Over the battlefield, under the panels: over the player's own units that
## stand idle for want of supplies, why: "NO FUEL", "NO AMMUNITION"
## (war_costs.gd sets unit.operating_shortage); over any unit in sight, its
## rank in gold chevrons (veterancy.gd) and a star for the general aboard
## (generals.gd). Health bars are health_overlay.gd's.

const FAR := 420.0            # beyond this camera distance no marker is drawn

var world: Node
var _elapsed := 0.0

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
	if key in ["artillery", "mlrs", "himars", "tos1a", "k9", "heavyRocket", "mortarTeam", "towedHowitzer"]: return "ART"
	if key in ["aaVehicle", "samLauncher", "manpads", "laserAD", "irisT", "abmLauncher", "saudiThaad", "hpmVehicle"]: return "AA"
	return "ARM" if u.get("vehicle", false) else "INF"

func role_markers() -> Array:
	var result := []
	if world == null or world.camera == null: return result
	var cam: Camera3D = world.camera
	var occupied := {}
	# Selected units win a crowded cell. Different roles/owners keep separate badges.
	for selected in [true, false]:
		for u in world.units:
			if bool(u.get("selected", false)) != selected or u.dead or u.get("stowed", false) or not u.node.is_visible_in_tree(): continue
			if world.get("fog") != null and not world.fog.shows(u): continue
			var at: Vector3 = u.node.position + Vector3.UP * 3.5
			var distance := cam.global_position.distance_to(at)
			if distance > FAR or (distance < 85.0 and not selected) or cam.is_position_behind(at): continue
			var p := cam.unproject_position(at) + Vector2(0, -20)
			if not get_viewport_rect().has_point(p): continue
			var role := role_of(u)
			var cell := "%d:%d:%d:%s" % [floori(p.x / 36.0), floori(p.y / 26.0), int(u.owner), role]
			if occupied.has(cell):
				result[occupied[cell]].count += 1
				continue
			occupied[cell] = result.size()
			result.append({"at": p, "role": role, "owner": int(u.owner), "selected": selected, "count": 1})
	return result

func _roles(font: Font) -> void:
	var placed: Array[Rect2] = []
	for mark in role_markers():
		var text: String = mark.role + (" ×%d" % mark.count if mark.count > 1 else "")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
		var box := Rect2(mark.at - Vector2(width * 0.5, 9), Vector2(width, 18))
		for attempt in range(8):
			if not placed.any(func(other): return other.grow(2).intersects(box)): break
			box.position.y -= 21.0
		placed.append(box)
		draw_rect(box.grow(1), Color("f0d690") if mark.selected else Color("0b151d"))
		draw_rect(box, Color("11232e"))
		var colour := Color(world.map.nations[mark.owner].color)
		draw_rect(Rect2(box.position, Vector2(3, 18)), colour)
		draw_string(font, box.position + Vector2(6, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f5ecd8"))

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
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
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
		if u.dead or u.get("stowed", false) or not u.node.is_visible_in_tree():
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
		var box := Rect2(p + Vector2(-width * 0.5 - 4, -54), Vector2(width + 8, 14))   # above role and health
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
