extends Node3D
## Where your selected units are going, drawn on the ground while they go:
##   - a marching dashed line from each selected unit along its route to its mark;
##   - one flag at each destination (a pole and pennant over a pulsing ring), with the
##     number of units heading there; the units' own slots as small diamonds;
##   - green to move, red to attack or attack-move, amber for boarding and landings;
##   - a target ring on the enemy a unit is chasing.
## The flag and its lines stay while any selected unit still goes there, and fade a moment
## after the last one arrives (ambience.ping is the click's own ring and radio acknowledgement).
## Research and design: native/ORDER-MARKS-2026-10-18.md.

const MOVE := Color(0.45, 0.95, 0.55)
const ATTACK := Color(0.95, 0.3, 0.22)
const BOARD := Color(0.98, 0.76, 0.28)
const DASH := 1.7
const GAP := 1.1
const WIDTH := 0.38
const MAX_UNITS := 40          # lines drawn at most for this many selected units
const MAX_DASHES := 90         # per unit
const CELL := 9.0              # destinations closer than this are one flag
const LINGER := 1.2            # seconds a flag stays after the last unit arrives

var w: Node
var _mesh := ImmediateMesh.new()
var _instance := MeshInstance3D.new()
var _labels: Array[Label3D] = []
var _flags := {}               # cell key -> {"pos", "colour", "fade", "seen", "slots"}
var _clock := 0.0
var marks_drawn := 0           # (tests) flags shown this frame
var lines_drawn := 0           # (tests) dashes shown this frame

func _init(world: Node) -> void:
	w = world

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_instance.mesh = _mesh
	_instance.material_override = mat
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.top_level = true
	add_child(_instance)

func _process(delta: float) -> void:
	_clock += delta
	_mesh.clear_surfaces()
	marks_drawn = 0
	lines_drawn = 0
	var mine: Array = w.units.filter(func(u): return u.selected and not u.dead and int(u.owner) == 0 and not u.get("stowed", false))
	for flag in _flags.values():
		flag.seen = false
	var batch := 0
	var routes := []
	for u in mine:
		var goal = u.get("target")
		var chase = u.get("enemy")
		var colour := MOVE
		if u.get("attack_move", false) or (chase != null and not chase.get("dead", true) and not u.has("ground_attack")) or u.has("ground_attack"):
			colour = ATTACK
		if u.get("board") != null or u.get("unload_go") != null:
			colour = BOARD
		if u.get("unload_go") != null:
			goal = u.unload_go
		elif u.get("board") != null and is_instance_valid(u.board.node):
			goal = u.board.node.position
		if goal == null:
			continue
		batch += 1
		if batch > MAX_UNITS:
			break
		# The flag stands where the player clicked; each unit's own slot is a diamond beside it.
		var mark: Vector3 = u.order_goal if u.get("order_goal") != null and u.get("target") != null and u.get("board") == null and u.get("unload_go") == null else goal
		routes.append([u, goal, colour, mark])
		var key := Vector2i(floori(mark.x / CELL), floori(mark.z / CELL))
		var flag: Dictionary = _flags.get(key, {})
		if flag.is_empty():
			flag = {"pos": mark, "colour": colour, "fade": 0.0, "seen": true, "slots": []}
			_flags[key] = flag
		flag.seen = true
		flag.fade = 1.0
		flag.colour = colour
		flag.slots.append(goal)
	var counts := {}
	for r in routes:
		var key := Vector2i(floori(r[3].x / CELL), floori(r[3].z / CELL))
		counts[key] = int(counts.get(key, 0)) + 1
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var drew := false
	# One bold line per group (the first unit of each destination and kind of movement); the others a faint
	# line when the selection is small, none when it is large: forty identical lines hide the map.
	var leads := {}
	for r in routes:
		var u: Dictionary = r[0]
		var key := Vector3i(floori(r[3].x / CELL), floori(r[3].z / CELL), 2 if u.get("fly", false) else (1 if u.get("naval", false) else 0))
		var lead: bool = not leads.has(key)
		if lead:
			leads[key] = true
		if lead or routes.size() <= 12:
			_route(u, r[1], r[2], 1.0 if lead else 0.3)
		drew = true
		var chase = u.get("enemy")
		if chase != null and not chase.get("dead", true) and chase.get("node") != null and is_instance_valid(chase.node) and not u.has("ground_attack"):
			_ring(chase.node.position, 3.2, ATTACK, 0.8 + 0.2 * sin(_clock * 6.0))
	var slot_seen := {}
	for key in _flags.keys():
		var flag: Dictionary = _flags[key]
		if not flag.seen:
			flag.fade = float(flag.fade) - delta / LINGER
			if float(flag.fade) <= 0.0:
				_flags.erase(key)
				continue
		_flag(flag, int(counts.get(key, 0)))
		marks_drawn += 1
		drew = true
		flag.slots = []
	if not drew:
		# An empty surface is not allowed: a degenerate triangle keeps the mesh valid.
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()
	_labels_update(counts)

## A marching dashed line from the unit along its route to the mark.
func _route(u: Dictionary, goal: Vector3, colour: Color, strength := 1.0) -> void:
	var points: Array[Vector3] = [u.node.position]
	var path: PackedVector3Array = u.get("path", PackedVector3Array())
	for i in range(path.size()):
		points.append(path[i])
	if points.size() == 1 or points[points.size() - 1].distance_to(goal) > 1.0:
		points.append(goal)
	var travelled := 0.0
	var offset := fmod(_clock * 2.6, DASH + GAP)
	var dashes := 0
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg := Vector2(b.x - a.x, b.z - a.z).length()
		if seg < 0.05:
			continue
		var pos := -offset
		while pos < seg and dashes < MAX_DASHES:
			var from := maxf(pos, 0.0)
			var to := minf(pos + DASH, seg)
			if to > from + 0.05:
				var t0 := from / seg
				var t1 := to / seg
				var p0: Vector3 = a.lerp(b, t0)
				var p1: Vector3 = a.lerp(b, t1)
				# Fade in near the unit and out at the mark so the line reads as a direction.
				var along := (travelled + from)
				var alpha := clampf(along / 6.0, 0.15, 1.0) * 0.85 * strength
				_dash(p0, p1, Color(colour.r, colour.g, colour.b, alpha), 1.0 if strength >= 1.0 else 0.6)
				dashes += 1
				lines_drawn += 1
			pos += DASH + GAP
		travelled += seg

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, maxf(w.height_at(p.x, p.z), float(w.map.seaLevel)) + 0.28, p.z)

func _dash(a: Vector3, b: Vector3, colour: Color, thin := 1.0) -> void:
	var p := _ground(a)
	var q := _ground(b)
	var dir := Vector3(q.x - p.x, 0, q.z - p.z)
	if dir.length() < 0.01:
		return
	var side := dir.normalized().cross(Vector3.UP) * (WIDTH * 0.5 * thin * (1.0 if thin < 1.0 else 1.25))
	_quad(p - side, p + side, q + side, q - side, colour)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	for v in [a, b, c, a, c, d]:
		_mesh.surface_set_color(colour)
		_mesh.surface_add_vertex(v)

func _tri(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	for v in [a, b, c]:
		_mesh.surface_set_color(colour)
		_mesh.surface_add_vertex(v)

## A flat ring on the ground.
func _ring(at: Vector3, radius: float, colour: Color, alpha := 1.0) -> void:
	var c := Color(colour.r, colour.g, colour.b, 0.85 * alpha)
	var steps := 28
	var inner := radius - 0.55
	for i in range(steps):
		if i % 7 == 6:
			continue   # a broken ring
		var a0 := TAU * i / steps
		var a1 := TAU * (i + 1) / steps
		var p0 := _ground(at + Vector3(cos(a0), 0, sin(a0)) * radius)
		var p1 := _ground(at + Vector3(cos(a1), 0, sin(a1)) * radius)
		var q0 := _ground(at + Vector3(cos(a0), 0, sin(a0)) * inner)
		var q1 := _ground(at + Vector3(cos(a1), 0, sin(a1)) * inner)
		_quad(p0, p1, q1, q0, c)

## The destination: a pulsing ring, a pole and a pennant; the units' own slots as diamonds.
func _flag(flag: Dictionary, count: int) -> void:
	var colour: Color = flag.colour
	var fade: float = clampf(float(flag.fade), 0.0, 1.0)
	var at: Vector3 = flag.pos
	var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
	_ring(at, 3.2 + 0.6 * pulse, Color(0.05, 0.08, 0.08), fade * 0.45)
	_ring(at, 3.0 + 0.6 * pulse, Color(colour.r, colour.g, colour.b), fade * (0.7 + 0.3 * pulse))
	var base := _ground(at)
	var c := Color(colour.r, colour.g, colour.b, 0.95 * fade)
	var top := base + Vector3(0, 7.0, 0)
	var side := Vector3(0.16, 0, 0.16)
	_quad(base - side, base + side, top + side, top - side, Color(1, 1, 1, 0.9 * fade))
	# The pennant, waving a little.
	var wave := sin(_clock * 3.0) * 0.25
	_tri(top, top + Vector3(3.4, -0.9 + wave, 0.4), top + Vector3(0, -2.4, 0), c)
	_tri(top, top + Vector3(0, -2.4, 0), top + Vector3(3.4, -0.9 + wave, -0.4), Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, c.a))
	# Slots: where each unit of a group will stand.
	if count > 1:
		for s in flag.slots:
			if Vector2(s.x - at.x, s.z - at.z).length() < 0.4:
				continue
			var g := _ground(s)
			_quad(g + Vector3(0, 0, -0.55), g + Vector3(0.55, 0, 0), g + Vector3(0, 0, 0.55), g + Vector3(-0.55, 0, 0), Color(colour.r, colour.g, colour.b, 0.8 * fade))

## "12" over a flag that several units are going to.
func _labels_update(counts: Dictionary) -> void:
	var shown := 0
	for key in counts:
		var count: int = counts[key]
		if count < 2 or not _flags.has(key):
			continue
		var label: Label3D
		if shown < _labels.size():
			label = _labels[shown]
		else:
			label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.fixed_size = true
			label.pixel_size = 0.0011
			label.font_size = 40
			label.outline_size = 12
			label.modulate = Color(1, 1, 1, 0.95)
			label.top_level = true
			add_child(label)
			_labels.append(label)
		label.text = "×%d" % count
		label.global_position = _ground(_flags[key].pos) + Vector3(0, 8.4, 0)
		label.visible = true
		shown += 1
	for i in range(shown, _labels.size()):
		_labels[i].visible = false
