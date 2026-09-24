extends Node3D
## Traffic on the supply network, and cargo ships at sea.
##
## Cars, lorries, buses and trains make whole trips on the intact roads and
## railways, from one town to the next, hex by hex. A town is always the end
## of a trip: the vehicle stops on the street at the edge of the district (its
## buildings stand in the middle) and, after a pause, turns round and sets
## off again; a train reverses out of the station. Road vehicles keep to the
## right-hand lane and take bends on a curve.
## They drive like vehicles: they speed up and brake at a limited rate, slow
## for bends and climbs, keep their distance from whatever is in front (brake
## lights come on), brake to a halt at the end of a trip and wait there a few
## seconds before setting off again. A train is a locomotive and its wagons,
## each on the track behind the one before; at a terminus it reverses, pushed
## by its locomotive. Bodies sit on the ground they are on (pitch and roll)
## and wheels turn with the distance covered.
##
## Each kind of vehicle (car, lorry, bus, locomotive, each wagon) is baked
## into one mesh and drawn with one MultiMesh, so a vehicle costs one
## transform a frame and the whole network a few draw calls however busy.
##
## Cargo ships exist only while an actual market shipment is at sea, and use
## the sea navigation grid.

const LANE := 1.05          # a road vehicle keeps this far right of the centre line
const STOP := 9.0           # a trip ends on the street this far from a town's centre (its edge)
const PER_EDGE := 0.7       # road vehicles per stretch of road
const MAX_ROAD := 40
const MAX_TRAINS := 6
const STRIDE := 16          # floats per MultiMesh instance: 3x4 transform + custom data

var world: Node
var vehicles := {}          # cargo ships: id -> {node, path, kind, route}
var elapsed := 0.0
var refresh := 0.0

var _graph := {"road": {}, "rail": {}}   # kind -> hex -> Array of neighbour hexes
var _edge_count := {"road": 0, "rail": 0}
var _fleet: Array = []      # road vehicles and trains
var _spawn_timer := 0.0
var _buf := {}              # model name -> PackedFloat32Array of its instances
var _layout_dirty := true
var _rng := RandomNumberGenerator.new()

const CAR_PAINT := ["e8e6df", "b9bcc0", "2b2d31", "8c1c1c", "1f3f73", "35523a", "c9b27c", "5d6770"]
const LORRY_BOX := ["d9d4c5", "a33a2a", "2f5d8a", "c98f2a", "6b7d4f", "e0e0dc"]

func _ready() -> void:
	_rng.randomize()
	_paint_shader = Shader.new()
	_paint_shader.code = PAINT_SHADER
	_lamp_shader = Shader.new()
	_lamp_shader.code = LAMP_SHADER

# Vertex colours are sRGB; alpha 1 marks the parts painted in the vehicle's own
# colour (INSTANCE_CUSTOM.rgb), alpha 0 a fixed colour.
const PAINT_SHADER := "shader_type spatial;
render_mode diffuse_burley;
uniform float rough = 0.5;
uniform float metal = 0.25;
varying vec3 paint;
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void vertex() {
	paint = to_linear(COLOR.a > 0.99 ? COLOR.rgb * INSTANCE_CUSTOM.rgb : COLOR.rgb);
}
void fragment() {
	ALBEDO = paint;
	ROUGHNESS = rough;
	METALLIC = metal;
}
"
# Tail lamps (alpha a little under 1) burn brighter while braking (INSTANCE_CUSTOM.a).
const LAMP_SHADER := "shader_type spatial;
render_mode unshaded;
varying vec3 glow;
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void vertex() {
	glow = to_linear(COLOR.rgb) * (COLOR.a > 0.5 ? mix(0.35, 1.8, INSTANCE_CUSTOM.a) : 1.0);
}
void fragment() {
	ALBEDO = glow;
}
"

func _process(delta: float) -> void:
	if world == null or world.logistics == null:
		return
	elapsed += delta
	refresh -= delta
	if refresh <= 0:
		refresh = 2.0
		_sync_network()
		_sync_ships()
	_populate(delta)
	for c in _fleet:
		_drive(c, delta)
	if _layout_dirty:
		_layout()
	_pose()
	_move_ships()

# ---------------------------------------------------------------- the network

## Re-reads the roads, railways and shipments now (normally every 2 s).
func _sync() -> void:
	_sync_network()
	_sync_ships()

func _sync_network() -> void:
	var graph := {"road": {}, "rail": {}}
	var count := {"road": 0, "rail": 0}
	for key in world.logistics.edges:
		var e: Dictionary = world.logistics.edges[key]
		var halves: Array = e.get("half", [e.hp, e.hp])
		if e.hp <= 0.0 or halves[0] <= 0.0 or halves[1] <= 0.0:
			continue
		if _is_town(e.a) and _is_town(e.b):
			continue  # inside a city the link runs through its buildings: no through traffic
		var g: Dictionary = graph[e.kind]
		if not g.has(e.a): g[e.a] = []
		if not g.has(e.b): g[e.b] = []
		if not e.b in g[e.a]: g[e.a].append(e.b)
		if not e.a in g[e.b]: g[e.b].append(e.a)
		count[e.kind] += 1
	_graph = graph
	_edge_count = count
	# A vehicle whose road was cut stops being drawn; a new one takes its place.
	var kept: Array = []
	for c in _fleet:
		if _route_intact(c):
			kept.append(c)
		else:
			_layout_dirty = true
	_fleet = kept

func _route_intact(c: Dictionary) -> bool:
	var g: Dictionary = _graph[c.kind]
	var hexes: Array = c.hexes
	for i in range(1, hexes.size()):
		if not g.has(hexes[i - 1]) or not hexes[i] in g[hexes[i - 1]]:
			return false
	return true

func _populate(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = 0.6
	var roads: int = mini(MAX_ROAD, ceili(_edge_count.road * PER_EDGE))
	var trains: int = mini(MAX_TRAINS, ceili(_edge_count.rail / 5.0))
	var have := {"road": 0, "rail": 0}
	for c in _fleet:
		have[c.kind] += 1
	for kind in ["rail", "road"]:
		var want: int = trains if kind == "rail" else roads
		if have[kind] < want:
			var c := _new_vehicle(kind)
			if not c.is_empty():
				_fleet.append(c)
				_layout_dirty = true
			return
		if have[kind] > want:
			for i in range(_fleet.size() - 1, -1, -1):
				if _fleet[i].kind == kind and _fleet[i].wait > 0.0:
					_fleet.remove_at(i)  # leaves while parked, never mid-road
					_layout_dirty = true
					return

func _is_town(h: Vector2i) -> bool:
	var d = world.district_hex.get(h)
	return d != null and not d.dead

## Hexes of a trip from `from`: to a town (or the end of a line) 2-14 links away.
func _trip(kind: String, from: Vector2i, avoid: Variant) -> Array:
	var g: Dictionary = _graph[kind]
	if not g.has(from):
		return []
	var prev := {from: from}
	var dist := {from: 0}
	var queue: Array = [from]
	# Out of a town the only way is back along the street it came in by.
	var exits: Array = [avoid] if avoid != null and _is_town(from) and avoid in g[from] else g[from]
	var ends: Array = []
	var any: Array = []
	while not queue.is_empty():
		var h: Vector2i = queue.pop_front()
		if dist[h] >= 14:
			continue
		for n in (exits if h == from else g[h]):
			if dist.has(n):
				continue
			dist[n] = dist[h] + 1
			prev[n] = h
			if _is_town(n):
				ends.append(n)  # a trip never drives through a town
				continue
			queue.append(n)
			if dist[n] >= 2:
				any.append(n)
				if g[n].size() == 1:
					ends.append(n)
	var pool: Array = ends if not ends.is_empty() else any
	if pool.is_empty():
		# A single link: shuttle across it.
		return [from, exits[_rng.randi() % exits.size()]] if not exits.is_empty() else []
	# Out in the country, prefer not to turn straight back the way it came.
	if not _is_town(from):
		var ahead: Array = pool.filter(func(h): return avoid == null or _first_step(prev, from, h) != avoid)
		if not ahead.is_empty() and _rng.randf() < 0.8:
			pool = ahead
	var goal: Vector2i = pool[_rng.randi() % pool.size()]
	var hexes: Array = [goal]
	while hexes[0] != from:
		hexes.push_front(prev[hexes[0]])
	return hexes

func _first_step(prev: Dictionary, from: Vector2i, goal: Vector2i) -> Vector2i:
	var h := goal
	while prev[h] != from:
		h = prev[h]
	return h

func _centre(h: Vector2i) -> Vector3:
	var c: Vector3 = world.logistics.hex_center(h)
	c.y = 0.0
	return c

# The track of a trip: from the edge of one town (or a junction) to the edge
# of the next, rounded at every bend, then offset to the right-hand lane.
# `came` is the hex before the first one, so a trip that sets off from a
# junction in the country continues the bend it was on.
func _track(kind: String, hexes: Array, came: Variant) -> PackedVector3Array:
	var rail := kind == "rail"
	var pts := PackedVector3Array()
	var n := hexes.size()
	for i in range(n):
		var c := _centre(hexes[i])
		var before: Variant = hexes[i - 1] if i > 0 else came
		var d_in: Vector3 = (c - _centre(before)).normalized() if before != null else Vector3.ZERO
		var d_out: Vector3 = (_centre(hexes[i + 1]) - c).normalized() if i < n - 1 else Vector3.ZERO
		var town := _is_town(hexes[i])
		if i == 0 and (town or d_in == Vector3.ZERO):
			pts.append(c + d_out * (STOP if town else 0.0))
		elif d_out == Vector3.ZERO:
			pts.append(c - d_in * (STOP if town else 0.0))
		elif d_in.dot(d_out) > 0.98:
			pts.append(c)
		else:
			var r := 6.0 if rail else 4.5
			_bezier(pts, c - d_in * r, c, c + d_out * r, 5)
	if rail:
		return pts
	var lane := PackedVector3Array()
	lane.resize(pts.size())
	for i in range(pts.size()):
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t := Vector3(b.x - a.x, 0, b.z - a.z)
		lane[i] = pts[i] + (_right(t.normalized()) * LANE if t.length() > 0.001 else Vector3.ZERO)
	return lane

func _right(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0, d.x)

func _bezier(pts: PackedVector3Array, a: Vector3, ctrl: Vector3, b: Vector3, steps: int) -> void:
	for k in range(steps + 1):
		var t := float(k) / steps
		pts.append(a * (1 - t) * (1 - t) + ctrl * 2.0 * (1 - t) * t + b * t * t)

func _lengths(path: PackedVector3Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(path.size())
	var total := 0.0
	for i in range(path.size()):
		if i > 0:
			total += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
		cum[i] = total
	return cum

# ---------------------------------------------------------------- vehicles

func _new_vehicle(kind: String) -> Dictionary:
	var g: Dictionary = _graph[kind]
	if g.is_empty():
		return {}
	var nodes: Array = g.keys()
	var towns: Array = nodes.filter(func(h): return _is_town(h))
	var from: Vector2i = (towns if not towns.is_empty() else nodes)[_rng.randi() % (towns.size() if not towns.is_empty() else nodes.size())]
	var hexes := _trip(kind, from, null)
	if hexes.size() < 2:
		return {}
	var c := {"kind": kind, "s": 0.0, "v": 0.0, "wait": _rng.randf_range(0.0, 5.0), "yaw": 0.0, "brake": false, "tick": _rng.randi() % 6}
	if kind == "rail":
		var line: float = _lengths(_track("rail", hexes, null))[-1]
		_make_train(c, line - 3.0)  # no longer than the line it runs on
	else:
		_make_road_vehicle(c)
	_set_trip(c, hexes, null, 0.0)
	c.yaw = _yaw_at(c, c.s)
	return c

func _set_trip(c: Dictionary, hexes: Array, came: Variant, lead_in: float) -> void:
	c.hexes = hexes
	c.path = _track(c.kind, hexes, came)
	c.cum = _lengths(c.path)
	c.s = lead_in
	c.total = c.cum[c.cum.size() - 1]

## At the end of a trip: the next one from here. A road vehicle drives on from
## where it stands; a train keeps its wagons on the track behind it, and at a
## terminus reverses, the last wagon now leading.
func _next_trip(c: Dictionary) -> void:
	var here: Vector2i = c.hexes[c.hexes.size() - 1]
	var came: Vector2i = c.hexes[c.hexes.size() - 2]
	var hexes := _trip(c.kind, here, came)
	if hexes.size() < 2:
		c.wait = 4.0
		return
	var stand: Vector3 = _point_at(c, c.s)
	var heading := Vector3(sin(c.yaw), 0, cos(c.yaw))
	if c.kind == "road":
		var track := _track("road", hexes, came)
		if hexes[1] == came:
			# Turning round: a tight U-turn across to the other lane.
			var left := -_right(heading)
			track.insert(0, stand + heading * 1.6 + left * LANE * 1.1)
			track.insert(0, stand + heading * 0.8 + left * LANE * 0.2)
		else:
			track = _ahead_of(track, stand, heading)
		track.insert(0, stand)
		c.hexes = hexes
		c.path = track
		c.cum = _lengths(track)
		c.s = 0.0
		c.total = c.cum[c.cum.size() - 1]
		return
	var consist: float = c.bodies[c.bodies.size() - 1].offset + c.bodies[c.bodies.size() - 1].length * 0.5 + 1.0
	var tail := _slice(c, c.s - consist, c.s)          # track under the train, rear to front
	var track := _track("rail", hexes, came)
	if hexes[1] == came:
		# Reversing out of a terminus: the rear of the train leads away.
		tail.reverse()
		var cum := _lengths(track)
		var rest := PackedVector3Array()
		for i in range(track.size()):
			if cum[i] > consist + 2.0:
				rest.append(track[i])
		tail.append_array(rest)
		c.bodies.reverse()
		var at := 0.0
		for b in c.bodies:
			b.offset = at + b.length * 0.5
			at += b.length + 0.6
		c.hexes = hexes
		c.path = tail
		c.cum = _lengths(tail)
		c.s = consist
		c.total = c.cum[c.cum.size() - 1]
		return
	var behind: float = _lengths(tail)[tail.size() - 1]
	tail.append_array(_ahead_of(track, stand, heading))
	c.hexes = hexes
	c.path = tail
	c.cum = _lengths(tail)
	c.s = behind
	c.total = c.cum[c.cum.size() - 1]

# A new trip's track can begin a few metres behind where the vehicle stopped
# (the start of a bend): drop those points so it never backs up.
func _ahead_of(track: PackedVector3Array, stand: Vector3, heading: Vector3) -> PackedVector3Array:
	while track.size() > 2:
		var rel := track[0] - stand
		if Vector2(rel.x, rel.z).length() < 9.0 and rel.x * heading.x + rel.z * heading.z < 0.3:
			track.remove_at(0)
		else:
			break
	return track

# Points of the current track between distances a and b (clamped).
func _slice(c: Dictionary, a: float, b: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.append(_point_at(c, maxf(a, 0.0)))
	for i in range(c.path.size()):
		if c.cum[i] > a and c.cum[i] < b:
			out.append(c.path[i])
	out.append(_point_at(c, b))
	return out

func _point_at(c: Dictionary, s: float) -> Vector3:
	var cum: PackedFloat32Array = c.cum
	var path: PackedVector3Array = c.path
	if s <= 0.0:
		var d0 := (path[1] - path[0]) if path.size() > 1 else Vector3.ZERO
		return path[0] + d0.normalized() * s if d0.length() > 0.001 else path[0]
	var i := cum.bsearch(s)
	if i >= path.size():
		return path[path.size() - 1]
	var span: float = cum[i] - cum[i - 1]
	return path[i - 1].lerp(path[i], (s - cum[i - 1]) / span if span > 0.0001 else 1.0)

func _yaw_at(c: Dictionary, s: float) -> float:
	var a := _point_at(c, s - 1.2)
	var b := _point_at(c, s + 1.2)
	return atan2(b.x - a.x, b.z - a.z) if Vector2(b.x - a.x, b.z - a.z).length() > 0.01 else c.yaw

func _drive(c: Dictionary, delta: float) -> void:
	if c.wait > 0.0:
		c.tick += 1
		c.wait -= delta
		c.v = 0.0
		c.brake = true
		if c.wait <= 0.0:
			_next_trip(c)
		return
	var remain: float = c.total - c.s
	c.tick += 1
	if c.tick % 6 == 0 or not c.has("limit"):
		# Looking ahead (a few times a second is plenty): bends and climbs.
		var here := _yaw_at(c, c.s)
		var bend := absf(wrapf(_yaw_at(c, c.s + 9.0) - here, -PI, PI)) + absf(wrapf(_yaw_at(c, c.s + 18.0) - here, -PI, PI)) * 0.5
		var limit: float = lerpf(c.vmax, c.vmax * 0.32, clampf(bend / 1.3, 0.0, 1.0))
		var ahead := _point_at(c, c.s + 6.0)
		var now := _point_at(c, c.s)
		var climb: float = (world.height_at(ahead.x, ahead.z) - world.height_at(now.x, now.z)) / 6.0
		c.limit = limit * clampf(1.0 - maxf(climb, 0.0) * c.heavy * 3.0, 0.45, 1.0)
	if c.tick % 3 == 0 or not c.has("gap"):
		c.gap = _gap_ahead(c, c.bodies[0].get("at", _point_at(c, c.s)))
	var target: float = c.limit
	# Brake to a stop at the end of the trip.
	target = minf(target, sqrt(2.0 * c.decel * 0.6 * maxf(remain - 0.2, 0.0)))
	# Keep a distance behind whatever is in front in the same lane.
	if c.gap < INF:
		target = minf(target, maxf(0.0, (c.gap - c.keep) * 0.8))
	var before: float = c.v
	c.v = move_toward(c.v, target, (c.accel if target > c.v else c.decel) * delta)
	c.brake = c.v < before - 0.01 * delta or c.v < 0.2
	c.s += c.v * delta
	if remain < 0.35 and c.v < 0.25:
		c.v = 0.0
		c.wait = _rng.randf_range(3.0, 8.0) if c.kind == "road" else _rng.randf_range(6.0, 12.0)

func _gap_ahead(c: Dictionary, at: Vector3) -> float:
	var fwd := Vector3(sin(c.yaw), 0, cos(c.yaw))
	var right := _right(fwd)
	var best := INF
	for o in _fleet:
		if is_same(o, c) or o.kind != c.kind:
			continue
		var ofwd := Vector3(sin(o.yaw), 0, cos(o.yaw))
		if ofwd.dot(fwd) < 0.2:
			continue  # oncoming or crossing: the other lane
		for b in o.bodies:
			var p: Vector3 = b.get("at", Vector3.INF)
			if p == Vector3.INF:
				continue
			var rel := p - at
			var along := rel.x * fwd.x + rel.z * fwd.z
			if along <= 0.0 or along > 28.0:
				continue
			if absf(rel.x * right.x + rel.z * right.z) > 1.3:
				continue
			best = minf(best, along - b.length * 0.5 - c.bodies[0].length * 0.5)
	return best

# ---------------------------------------------------------------- models
# A model is a list of parts, [shape, transform in the body's frame (+Z
# forward, ground at y 0), colour, surface], baked once into one mesh per
# model with three surfaces: paint, glass and lamps. Paint marked LIVERY takes
# each vehicle's own colour, and tail lamps glow brighter while it brakes
# (both per instance, in INSTANCE_CUSTOM).

const LIVERY := Color(1, 1, 1, 1)
const TINTED := 1.0

var _models := {}           # model name -> {mm: MultiMesh, count}
var _paint_shader: Shader
var _lamp_shader: Shader

func _part(parts: Array, shape: String, size: Vector3, at: Vector3, colour: Color, surface := "paint") -> void:
	var basis := Basis.from_scale(size)
	if shape == "wheel":
		basis = Basis(Vector3(0, 0, 1), PI * 0.5) * Basis.from_scale(size)  # axle across the vehicle
	elif shape == "barrel":
		basis = Basis(Vector3(1, 0, 0), PI * 0.5) * Basis.from_scale(size)  # lying along the vehicle
	if colour != LIVERY and colour.a >= 0.999:
		colour.a = 0.0  # a fixed colour, not the vehicle's paint
	parts.append([shape, Transform3D(basis, at), colour, surface])

func _wheels(parts: Array, zs: Array, track: float, r: float, width := 0.28) -> void:
	for z in zs:
		for x in [-track, track]:
			_part(parts, "wheel", Vector3(r * 2.0, width, r * 2.0), Vector3(x, r, z), Color("1b1d20"))

func _lamps(parts: Array, front: float, back: float, half: float, y: float) -> void:
	for x in [-half, half]:
		_part(parts, "box", Vector3(0.28, 0.14, 0.05), Vector3(x, y, front), Color("fff3d6"), "lamp")
		_part(parts, "box", Vector3(0.26, 0.12, 0.05), Vector3(x, y, back), Color(0.9, 0.08, 0.06, 0.995), "lamp")

# The model called `name`, made by `build` the first time it is needed.
func _model(name: String, build: Callable) -> String:
	if _models.has(name):
		return name
	var parts: Array = []
	build.call(parts)
	var mesh := ArrayMesh.new()
	var shapes := {"box": BoxMesh.new(), "wheel": _cylinder(10), "barrel": _cylinder(14)}
	for surface in ["paint", "glass", "lamp"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for part in parts:
			if part[3] != surface:
				continue
			any = true
			var arrays: Array = shapes[part[0]].get_mesh_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var xf: Transform3D = part[1]
			var nb := xf.basis.inverse().transposed()
			st.set_color(part[2])
			for i in arrays[Mesh.ARRAY_INDEX]:
				st.set_normal((nb * normals[i]).normalized())
				st.add_vertex(xf * verts[i])
		if not any:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = _lamp_shader if surface == "lamp" else _paint_shader
		if surface == "glass":
			mat.set_shader_parameter("rough", 0.08)
			mat.set_shader_parameter("metal", 0.6)
		st.set_material(mat)
		mesh = st.commit(mesh)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	_models[name] = {"mm": mm, "count": 0}
	return name

func _cylinder(sides: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.5
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = sides
	m.rings = 1
	return m

func _make_road_vehicle(c: Dictionary) -> void:
	var roll := _rng.randf()
	var body := {"lift": 0.1, "offset": 0.0}
	if roll < 0.58:
		body.model = _model("car", func(parts):
			_part(parts, "box", Vector3(1.5, 0.5, 3.6), Vector3(0, 0.55, 0), LIVERY)
			_part(parts, "box", Vector3(1.3, 0.06, 1.55), Vector3(0, 1.23, -0.2), LIVERY)
			_part(parts, "box", Vector3(1.36, 0.42, 1.8), Vector3(0, 1.0, -0.15), Color("1c262e"), "glass")
			_part(parts, "box", Vector3(1.52, 0.18, 0.12), Vector3(0, 0.4, 1.8), Color("2a2c2f"))
			_part(parts, "box", Vector3(1.52, 0.18, 0.12), Vector3(0, 0.4, -1.8), Color("2a2c2f"))
			_wheels(parts, [1.15, -1.15], 0.66, 0.3, 0.22)
			_lamps(parts, 1.83, -1.83, 0.5, 0.62))
		body.tint = Color(CAR_PAINT[_rng.randi() % CAR_PAINT.size()])
		body.length = 3.6
		c.merge({"vmax": _rng.randf_range(8.5, 11.0), "accel": 2.6, "decel": 5.0, "keep": 2.2, "heavy": 0.2})
	elif roll < 0.9:
		var tank := _rng.randf() < 0.3
		var box := Color(LORRY_BOX[_rng.randi() % LORRY_BOX.size()])
		body.model = _model("tanker" if tank else "lorry-" + box.to_html(false), func(parts):
			_part(parts, "box", Vector3(1.66, 0.3, 6.2), Vector3(0, 0.62, 0), Color("25282b"))
			_part(parts, "box", Vector3(1.7, 1.25, 1.5), Vector3(0, 1.25, 2.3), LIVERY)
			_part(parts, "box", Vector3(1.6, 0.5, 0.1), Vector3(0, 1.55, 3.06), Color("1c262e"), "glass")
			if tank:
				_part(parts, "barrel", Vector3(1.6, 4.1, 1.6), Vector3(0, 1.62, -0.9), Color("c9ccd0"))
			else:
				_part(parts, "box", Vector3(1.76, 1.75, 4.3), Vector3(0, 1.72, -0.85), box)
			_wheels(parts, [2.2, -1.2, -2.3], 0.72, 0.4, 0.3)
			_lamps(parts, 3.08, -3.02, 0.62, 0.75))
		body.tint = Color(["d8d8d2", "2d4f7c", "8f2b22", "39513b", "c4a24a"][_rng.randi() % 5])
		body.length = 6.4
		c.merge({"vmax": _rng.randf_range(6.5, 8.0), "accel": 1.4, "decel": 3.5, "keep": 3.0, "heavy": 1.0})
	else:
		body.model = _model("bus", func(parts):
			_part(parts, "box", Vector3(1.8, 1.9, 8.0), Vector3(0, 1.4, 0), LIVERY)
			_part(parts, "box", Vector3(1.84, 0.7, 7.2), Vector3(0, 1.75, -0.2), Color("1c262e"), "glass")
			_part(parts, "box", Vector3(1.6, 0.9, 0.08), Vector3(0, 1.65, 4.0), Color("1c262e"), "glass")
			_part(parts, "box", Vector3(1.7, 0.08, 7.6), Vector3(0, 2.38, 0), Color("e9e7e0"))
			_wheels(parts, [2.6, -2.5], 0.76, 0.45, 0.32)
			_lamps(parts, 4.02, -4.02, 0.66, 0.8))
		body.tint = Color(["d9a520", "b8342b", "2f6e8e"][_rng.randi() % 3])
		body.length = 8.0
		c.merge({"vmax": _rng.randf_range(6.5, 7.5), "accel": 1.2, "decel": 3.2, "keep": 3.2, "heavy": 0.8})
	c.bodies = [body]

func _make_train(c: Dictionary, room: float) -> void:
	var bodies: Array = []
	# The locomotive: long bonnet, cab, roof, a painted band, bogies.
	bodies.append({"length": 7.6, "tint": Color(["9c2a22", "1f4f7a", "2d5a3a", "d59b28"][_rng.randi() % 4]), "model": _model("locomotive", func(parts):
		_part(parts, "box", Vector3(2.0, 0.35, 7.6), Vector3(0, 0.95, 0), Color("22252a"))
		_part(parts, "box", Vector3(1.8, 1.55, 5.2), Vector3(0, 1.9, -1.0), LIVERY)
		_part(parts, "box", Vector3(2.0, 2.05, 2.0), Vector3(0, 2.15, 2.6), LIVERY)
		_part(parts, "box", Vector3(1.8, 0.62, 0.08), Vector3(0, 2.62, 3.61), Color("1c262e"), "glass")
		_part(parts, "box", Vector3(2.04, 0.5, 1.3), Vector3(0, 2.62, 2.6), Color("1c262e"), "glass")
		_part(parts, "box", Vector3(1.7, 0.12, 6.8), Vector3(0, 2.72, -0.3), Color("3a3d42"))
		_part(parts, "box", Vector3(1.84, 0.12, 5.3), Vector3(0, 1.45, -1.0), Color("e8d9a8"))
		_bogies(parts, 2.5)
		_lamps(parts, 3.82, -3.82, 0.6, 1.25))})
	var first := _rng.randi() % 3
	var fit := clampi(int((room - 7.6) / 6.6), 0, 3)
	for w in range(_rng.randi_range(mini(2, fit), fit)):
		var kind := (first + w) % 3
		var pick := _rng.randi() % 3
		var name: String = ["containers", "tank-wagon", "van"][kind] + str(pick)
		bodies.append({"length": 6.0, "tint": LIVERY, "model": _model(name, func(parts):
			_part(parts, "box", Vector3(2.0, 0.3, 6.0), Vector3(0, 0.95, 0), Color("2b2e33"))
			match kind:
				0:
					_part(parts, "box", Vector3(1.9, 1.9, 2.8), Vector3(0, 2.05, 1.5), Color(LORRY_BOX[pick]))
					_part(parts, "box", Vector3(1.9, 1.9, 2.8), Vector3(0, 2.05, -1.5), Color(LORRY_BOX[pick + 3]))
				1:
					_part(parts, "barrel", Vector3(1.9, 5.4, 1.9), Vector3(0, 2.05, 0), Color(["2a2a2a", "c9ccd0", "7a3b2a"][pick]))
				_:
					_part(parts, "box", Vector3(2.0, 2.1, 5.8), Vector3(0, 2.15, 0), Color(["6e3b2a", "5b6168", "4a5a3a"][pick]))
					_part(parts, "box", Vector3(1.7, 0.1, 5.8), Vector3(0, 3.25, 0), Color("4a4d52"))
			_bogies(parts, 2.0))})
	var at := 0.0
	for b in bodies:
		b.offset = at + b.length * 0.5
		b.lift = 0.2
		at += b.length + 0.6
	c.bodies = bodies
	c.merge({"vmax": _rng.randf_range(9.0, 11.5), "accel": 0.7, "decel": 1.6, "keep": 6.0, "heavy": 0.5})

func _bogies(parts: Array, z: float) -> void:
	for side in [z, -z]:
		_part(parts, "box", Vector3(1.6, 0.4, 2.0), Vector3(0, 0.5, side), Color("1a1c1f"))
		for dz in [-0.6, 0.6]:
			for x in [-0.55, 0.55]:
				_part(parts, "wheel", Vector3(0.7, 0.12, 0.7), Vector3(x, 0.35, side + dz), Color("3b3d40"))

# ---------------------------------------------------------------- drawing

# Gives every vehicle body a slot in its model's MultiMesh (after vehicles
# come or go).
func _layout() -> void:
	_layout_dirty = false
	for name in _models:
		_models[name].count = 0
	for c in _fleet:
		for b in c.bodies:
			b.slot = _models[b.model].count
			_models[b.model].count += 1
	for name in _models:
		var m: Dictionary = _models[name]
		m.mm.instance_count = m.count
		var buf := PackedFloat32Array()
		buf.resize(m.count * STRIDE)
		_buf[name] = buf

func _pose() -> void:
	var eye: Vector3 = world.cam_focus
	var sight: float = world.cam_dist * 2.2 + 80.0
	for c in _fleet:
		c.yaw = lerp_angle(c.yaw, _yaw_at(c, c.s), 0.35)
		var lead_at: Vector3 = c.bodies[0].get("at", Vector3.ZERO)
		var far: bool = c.bodies[0].has("at") and Vector2(lead_at.x - eye.x, lead_at.z - eye.z).length() > sight
		for b in c.bodies:
			var s: float = c.s - float(b.offset)
			var at := _point_at(c, s)
			var yaw: float = c.yaw if c.kind == "road" else _yaw_at(c, s)
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			var half: float = b.length * 0.42
			var right := _right(fwd) * 0.7
			if c.tick % (8 if far else 2) == 0 or not b.has("g"):
				# The ground under the wheels (every other frame; rarely out of sight).
				b.g = [_ground(at + fwd * half), _ground(at - fwd * half), _ground(at - right), _ground(at + right)]
			var g: Array = b.g
			at.y = (g[0] + g[1] + g[2] + g[3]) * 0.25 + float(b.lift)
			b.at = at
			var z := Vector3(fwd.x, (g[0] - g[1]) / (half * 2.0), fwd.z).normalized()
			var x_axis := Vector3(fwd.z, (g[2] - g[3]) / 1.4, -fwd.x).normalized()  # the body's +X side
			var y := z.cross(x_axis).normalized()
			x_axis = y.cross(z).normalized()
			var buf: PackedFloat32Array = _buf[b.model]
			var o: int = b.slot * STRIDE
			buf[o] = x_axis.x; buf[o + 1] = y.x; buf[o + 2] = z.x; buf[o + 3] = at.x
			buf[o + 4] = x_axis.y; buf[o + 5] = y.y; buf[o + 6] = z.y; buf[o + 7] = at.y
			buf[o + 8] = x_axis.z; buf[o + 9] = y.z; buf[o + 10] = z.z; buf[o + 11] = at.z
			var tint: Color = b.tint
			buf[o + 12] = tint.r; buf[o + 13] = tint.g; buf[o + 14] = tint.b
			buf[o + 15] = 1.0 if c.brake else 0.0
			_buf[b.model] = buf
	for name in _models:
		if _models[name].count > 0:
			_models[name].mm.buffer = _buf[name]

# The ground a wheel stands on: the terrain, or a district's paved floor.
func _ground(p: Vector3) -> float:
	var ground: float = world.height_at(p.x, p.z)
	var d = world.district_hex.get(world.logistics.world_hex(p))
	if d != null and not d.dead:
		var centre: Vector3 = d.root.position
		var f := clampf(Vector2(p.x - centre.x, p.z - centre.z).length() / world.logistics.radius, 0.0, 1.0)
		ground = maxf(lerpf(centre.y, ground, pow(f, 3.0)), ground + 0.03) + 0.05
	return ground

# ---------------------------------------------------------------- cargo ships

func _move_ships() -> void:
	for key in vehicles:
		var v: Dictionary = vehicles[key]
		var route = null
		for r in world.market.routes:
			if r.id == v.route: route = r
		if route == null or route.shipment == null:
			v.node.visible = false
			continue
		v.node.visible = true
		var f := clampf(1.0 - (float(route.shipment.eta) - world.market._tick) / float(world.market.cfg.voyage), 0, 1)
		var reverse: bool = route.dir == "import"
		if reverse: f = 1.0 - f
		var step: float = f * (v.path.size() - 1)
		var i := mini(floori(step), v.path.size() - 2)
		var a: Vector3 = v.path[i]
		var b: Vector3 = v.path[i + 1]
		var p := a.lerp(b, step - i)
		p.y = float(world.map.seaLevel) + 0.2
		v.node.position = p
		var want := atan2(b.x - a.x, b.z - a.z) + (PI if reverse else 0.0)
		v.node.rotation.y = lerp_angle(v.node.rotation.y, want, 0.05)

func _sync_ships() -> void:
	if world.market == null:
		return
	var live := {}
	for r in world.market.routes:
		if r.shipment == null: continue
		var id := "ship:%d" % r.id
		live[id] = true
		if vehicles.has(id): continue
		var port = null
		for b in world.buildings:
			if b.owner == 0 and b.key == "port" and b.built and not b.dead: port = b
		if port == null: continue
		if world.naval_navigation == null:
			world.naval_navigation = preload("res://scripts/naval_navigation.gd").new()
			world.naval_navigation.setup(world)
		var target: Array = world.map.startPositions[r.nation]
		var path: PackedVector3Array = world.naval_navigation.route(port.root.position, Vector3(target[0], 0, target[1]))
		if path.size() >= 2: _add_ship(id, path, r.id)
	for key in vehicles.keys():
		if not live.has(key):
			vehicles[key].node.queue_free()
			vehicles.erase(key)

func _add_ship(id: String, path: PackedVector3Array, route: int) -> void:
	var root := Node3D.new()
	add_child(root)
	_box(root, Vector3(3.2, 1.3, 9), Vector3(0, 0.7, 0), Color("253b46"))
	_box(root, Vector3(2.5, 1.5, 2), Vector3(0, 1.6, 2.7), Color("c2c1ae"))
	_box(root, Vector3(2.4, 1.2, 3.5), Vector3(0, 1.6, -1), Color("ae643c"))
	vehicles[id] = {"node": root, "path": path, "kind": "ship", "route": route}

func _box(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = world.matte(colour)
	root.add_child(mesh)

## --capture-traffic: two towns joined to the capital by road and one by
## railway; after the traffic has run a while, views of the roads, a town
## roundabout and the railway (build/traffic-*.png). Prints what is moving.
static func capture(w: Node) -> void:
	for i in range(30):
		await w.get_tree().process_frame
	for key in w.economy.res:
		w.economy.res[key] = maxf(float(w.economy.res[key]), 1e5)
	var home: Vector2i = w.logistics.world_hex(w.start)
	var towns: Array = []
	for d in [Vector2i(4, -1), Vector2i(-2, 4), Vector2i(-4, 0), Vector2i(1, -4)]:
		for step in range(3):
			var h: Vector2i = home + d + Vector2i(step, 0)
			var at: Vector3 = w.logistics.hex_center(h)
			if w.site_problem("villageCenter", at, 0) == "" or w.site_problem("housing", at, 0) == "":
				w.place_building("housing", at, 0, true)
				towns.append(h)
				break
		if towns.size() >= 3:
			break
	for i in range(towns.size()):
		var kind := "rail" if i == 0 else "road"
		var route: Array = w.logistics.plan(home, towns[i], 0, kind)
		w.logistics.build(route, kind, 0)
		if i > 0:
			w.logistics.build(w.logistics.plan(towns[i], towns[(i + 1) % towns.size()], 0, "road"), "road", 0)
	w.logistics.rebuild_mesh()
	var traffic = w.get_children().filter(func(n): return n.get_script() == load("res://scripts/route_traffic.gd"))[0]
	for i in range(60 * 30):
		await w.get_tree().process_frame
	var moving := {"road": 0, "rail": 0}
	for c in traffic._fleet:
		if c.v > 0.5:
			moving[c.kind] += 1
	print("TRAFFIC %d road vehicles (%d moving), %d trains (%d moving), links road %d rail %d" % [traffic._fleet.filter(func(c): return c.kind == "road").size(), moving.road, traffic._fleet.filter(func(c): return c.kind == "rail").size(), moving.rail, traffic._edge_count.road, traffic._edge_count.rail])
	var t0 := Time.get_ticks_usec()
	for i in range(60):
		traffic._process(1.0 / 60.0)
	print("TRAFFIC update %.2f ms a frame" % ((Time.get_ticks_usec() - t0) / 60000.0))
	var shots := [["overview", w.logistics.hex_center(home), 120.0, 0.9, 0.4]]
	var train = null
	for c in traffic._fleet:
		if c.kind == "rail":
			train = c
	var car = null
	for c in traffic._fleet:
		if c.kind == "road" and c.v > 1.0:
			car = c
	if car != null:
		shots.append(["road", car.bodies[0].at, 26.0, 0.55, car.yaw + 2.3])
	if towns.size() > 1:
		shots.append(["town", w.logistics.hex_center(towns[1]), 45.0, 0.75, 0.8])
	for shot in shots:
		w.cam_focus = shot[1]
		w.cam_dist = shot[2]
		w.cam_dist_target = shot[2]
		w.cam_pitch = shot[3]
		w.cam_yaw = shot[4]
		for f in range(20):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/traffic-%s.png" % shot[0])
	if train != null:
		# Follow the train for a few frames so it is in the picture.
		for f in range(40):
			w.cam_focus = train.bodies[0].at
			w.cam_dist = 30.0
			w.cam_dist_target = 30.0
			w.cam_pitch = 0.5
			w.cam_yaw = train.yaw + 2.2
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/traffic-train.png")
	w.get_tree().quit()
