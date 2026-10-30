extends Node3D
## A living world (players said it felt empty and cheap):
## - smoke from industrial stacks (power stations, factories) while they stand,
##   and from house chimneys in autumn and winter (architecture.gd marks each
##   chimney and stack "SmokeIndustry" or "SmokeHome"); only near the camera,
##   and at most MAX_PLUMES at once;
## - winter you can see: a global shader value (winter, 0..1) lays snow on
##   flat ground and dusts the trees, fading in over WINTER_FADE seconds as the
##   last season of the year begins and out as it ends (economy.gd: the final
##   quarter of each 12-minute year);
## - birds: a few flocks circling over the land near the camera, which scatter
##   when an explosion goes off nearby (effects.shake);
## - an order marker: a ring that opens where you send units, green to move,
##   red to attack, with a short radio acknowledgement.

const YEAR := 720.0
const WINTER_FROM := 540.0
const WINTER_FADE := 40.0
const NEAR := 260.0
const MAX_PLUMES := 36
const FLOCKS := 2   # (4 flocks of 6 weighed on the frame rate and crowded the sky)
const BIRDS := 3

var w: Node
var _plumes := {}          # marker instance id -> GPUParticles3D
var _scan := 0.0
var _flocks: Array = []
var _ring_mesh: TorusMesh
var _rings: Array = []
var _ack: AudioStreamPlayer
var _industry_mat: ParticleProcessMaterial
var _home_mat: ParticleProcessMaterial
var _puff: QuadMesh
var winter := 0.0

func _init(world: Node) -> void:
	w = world

func _ready() -> void:
	# The renderer keeps a global between scenes: a new match or a summer save
	# must not inherit the last match's snow.
	winter = snow_at(float(w.game_time))
	RenderingServer.global_shader_parameter_set("winter", winter)
	_industry_mat = _smoke_material(Color(0.62, 0.61, 0.6, 0.55), 1.6, 2.8, 5.0)
	_home_mat = _smoke_material(Color(0.78, 0.77, 0.76, 0.35), 0.5, 1.2, 3.0)
	var tex: Texture2D = preload("res://scripts/effects.gd").cloud_texture()   # a torn puff, as battle smoke
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	_puff = QuadMesh.new()
	_puff.size = Vector2(2.2, 2.2)
	_puff.material = mat
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.82
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4
	var ack_stream = load("res://audio/ui_click.wav")
	_ack = AudioStreamPlayer.new()
	_ack.stream = ack_stream
	_ack.bus = "Interface" if AudioServer.get_bus_index("Interface") >= 0 else "Master"
	_ack.volume_db = -10.0
	_ack.pitch_scale = 0.62   # lower than a button: a radio's acknowledgement
	add_child(_ack)
	for f in range(FLOCKS):
		_flocks.append(_flock(f))
	if w.get("effects") != null and w.effects.has_signal("shake"):
		w.effects.shake.connect(_scare)

func _smoke_material(colour: Color, v_min: float, v_max: float, life_scale: float) -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3(0.25, 1, 0.1)
	p.spread = 12.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector3(0.35, 0.25, 0.12)   # a light wind
	p.damping_min = 0.2
	p.damping_max = 0.4
	p.scale_min = 0.7
	p.scale_max = 1.2
	p.angle_min = -180
	p.angle_max = 180
	p.angular_velocity_min = -12
	p.angular_velocity_max = 12
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.4 if life_scale > 4.0 else 1.6))
	var ct := CurveTexture.new()
	ct.curve = curve
	p.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(colour, 0.0))
	g.add_point(0.12, colour)
	g.set_color(g.get_point_count() - 1, Color(colour, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	return p

## The season's snow (0..1) at game time `t`.
static func snow_at(t: float) -> float:
	var day := fmod(t, YEAR)
	if day >= WINTER_FROM:
		return clampf((day - WINTER_FROM) / WINTER_FADE, 0.0, 1.0)   # it settles as winter begins
	if day < WINTER_FADE * 0.5 and t >= YEAR:
		return 1.0 - day / (WINTER_FADE * 0.5)   # and melts as the new year's spring begins (not in the first spring: no winter came before it)
	return 0.0

func update(delta: float) -> void:
	var s := snow_at(float(w.game_time))
	if absf(s - winter) > 0.004:
		winter = s
		RenderingServer.global_shader_parameter_set("winter", winter)
	_scan += delta
	if _scan >= 1.0:
		_scan = 0.0
		_update_plumes()
	_update_flocks(delta)
	for r in _rings.duplicate():
		r.age += delta
		var k: float = r.age / 0.7
		if k >= 1.0 or not is_instance_valid(r.node):
			if is_instance_valid(r.node): r.node.queue_free()
			_rings.erase(r)
			continue
		r.node.scale = Vector3(1, 0.4, 1) * lerpf(2.0, 6.5, k)
		r.node.get_surface_override_material(0).albedo_color.a = 0.9 * (1.0 - k)

# ---------------------------------------------------------------- smoke

func _update_plumes() -> void:
	var cam: Camera3D = w.get_viewport().get_camera_3d() if w.is_inside_tree() else null
	if cam == null:
		return
	var focus: Vector3 = w.cam_focus
	var cold: bool = int(fmod(float(w.game_time), YEAR) / 180.0) >= 2   # autumn and winter
	var want := {}
	var budget := MAX_PLUMES
	for b in w.buildings:
		if budget <= 0:
			break
		if b.dead or not b.built or b.root == null:
			continue
		if Vector2(b.root.position.x - focus.x, b.root.position.z - focus.z).length() > NEAR:
			continue
		if not b.has("smoke_marks"):
			b.smoke_marks = b.root.find_children("Smoke*", "Marker3D", true, false)
		for m in b.smoke_marks:
			if budget <= 0:
				break   # the budget holds within one building's stacks too
			if not is_instance_valid(m):
				continue
			var home: bool = m.name.begins_with("SmokeHome")
			if home and not cold:
				continue
			if not home and not b.get("supplied", true):
				continue   # a cut-off works stands cold
			want[m.get_instance_id()] = m
			budget -= 1
	for id in _plumes.keys():
		if not want.has(id) or not is_instance_valid(_plumes[id]):
			if is_instance_valid(_plumes[id]): _plumes[id].queue_free()
			_plumes.erase(id)
	for id in want:
		if not _plumes.has(id):
			var m: Marker3D = want[id]
			var home: bool = m.name.begins_with("SmokeHome")
			var p := GPUParticles3D.new()
			p.process_material = _home_mat if home else _industry_mat
			p.draw_pass_1 = _puff
			p.amount = 10 if home else 22
			p.lifetime = 3.0 if home else 5.0
			p.preprocess = p.lifetime
			p.local_coords = false
			p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 30, 16))
			m.add_child(p)
			_plumes[id] = p

func plumes() -> int:
	return _plumes.size()

# ---------------------------------------------------------------- birds

## One flock: gulls (white, pale grey wings with black tips, yellow bill) or crows (glossy black) in turn.
## Each bird is built from shaped meshes, nose toward +Z (look_at uses the model front): a streamlined body,
## a bill, a fanned tail, and swept wings of two panels (the outer one pointed) that bend as they beat.
## Gulls glide between beats; crows row steadily.
var _bird_meshes := {}

func _flock(i: int) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var gull: bool = i % 2 == 0
	var kind := "gull" if gull else "crow"
	var m := _bird_kit(kind)
	var birds := []
	for k in range(BIRDS):
		var bird := Node3D.new()
		bird.scale = Vector3.ONE * (2.4 if gull else 2.1) * randf_range(0.92, 1.08)   # big enough to read from the strategic camera
		root.add_child(bird)
		_bird_part(bird, m.body, m.body_mat, Vector3.ZERO)
		_bird_part(bird, m.beak, m.beak_mat, Vector3.ZERO)
		_bird_part(bird, m.tail, m.wing_mat, Vector3.ZERO)
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.name = "L" if side < 0 else "R"
			pivot.position = Vector3(side * 0.08, 0.06, 0.06)
			bird.add_child(pivot)
			var inner := _bird_part(pivot, m.inner, m.wing_mat, Vector3.ZERO)
			inner.scale = Vector3(side, 1, 1)
			var tip := Node3D.new()
			tip.name = "Tip"
			tip.position = Vector3(side * 0.56, 0, 0)
			pivot.add_child(tip)
			var outer := _bird_part(tip, m.outer, m.tip_mat, Vector3.ZERO)
			outer.scale = Vector3(side, 1, 1)
		birds.append({"node": bird, "phase": randf() * TAU, "glide": randf() * TAU, "offset": Vector3(randf_range(-5, 5), randf_range(-1.5, 1.5), randf_range(-5, 5))})
	return {"root": root, "birds": birds, "centre": Vector3.ZERO, "angle": randf() * TAU, "radius": randf_range(18.0, 34.0), "gull": gull,
		"height": randf_range(16.0, 26.0), "speed": randf_range(0.18, 0.3) * (1.0 if i % 2 == 0 else -1.0), "flee": 0.0, "home": false}

## The shared meshes and materials of a species, built once.
func _bird_kit(kind: String) -> Dictionary:
	if _bird_meshes.has(kind):
		return _bird_meshes[kind]
	var gull := kind == "gull"
	var kit := {
		"body_mat": _bird_material(Color(0.95, 0.96, 0.97) if gull else Color(0.1, 0.1, 0.12), 0.6 if gull else 0.78),
		"wing_mat": _bird_material(Color(0.66, 0.7, 0.75) if gull else Color(0.08, 0.08, 0.1), 0.7 if gull else 0.85),
		"tip_mat": _bird_material(Color(0.08, 0.08, 0.09) if gull else Color(0.06, 0.06, 0.08), 0.85),
		"beak_mat": _bird_material(Color(0.96, 0.76, 0.2) if gull else Color(0.12, 0.11, 0.1), 0.5),
	}
	# The body: a lathe along Z, tail to head, a little flattened.
	var profile := [[-0.5, 0.025], [-0.34, 0.1], [-0.12, 0.16], [0.12, 0.165], [0.3, 0.13], [0.4, 0.1], [0.48, 0.115], [0.57, 0.1], [0.63, 0.05], [0.66, 0.0]]
	kit.body = _lathe(profile, Vector2(1.0, 0.82), 10)
	kit.beak = _lathe([[0.62, 0.045], [0.7, 0.032], [0.8 if gull else 0.78, 0.0]], Vector2(0.8, 1.0), 6, 0.045)
	# The tail: a fan behind the body.
	# (a gull's is square, a crow's rounded like a wedge)
	if gull:
		kit.tail = _panel([Vector2(-0.07, -0.42), Vector2(0.07, -0.42), Vector2(0.16, -0.72), Vector2(0.0, -0.74), Vector2(-0.16, -0.72)], 0.0)
	else:
		kit.tail = _panel([Vector2(-0.06, -0.42), Vector2(0.06, -0.42), Vector2(0.14, -0.7), Vector2(0.08, -0.8), Vector2(0.0, -0.83), Vector2(-0.08, -0.8), Vector2(-0.14, -0.7)], 0.0)
	# The inner wing: broad, its leading edge a little curved (drawn for the right side, mirrored for the left).
	kit.inner = _panel([Vector2(0.0, 0.16), Vector2(0.3, 0.17), Vector2(0.56, 0.12), Vector2(0.56, -0.13), Vector2(0.28, -0.2), Vector2(0.0, -0.18)], 0.0)
	# The outer wing: swept back to a point (a gull) or fingered and blunt (a crow).
	if gull:
		kit.outer = _panel([Vector2(0.0, 0.12), Vector2(0.3, 0.05), Vector2(0.62, -0.12), Vector2(0.4, -0.16), Vector2(0.0, -0.13)], 0.0)
	else:
		kit.outer = _panel([Vector2(0.0, 0.12), Vector2(0.28, 0.1), Vector2(0.46, 0.02), Vector2(0.5, -0.06), Vector2(0.42, -0.14), Vector2(0.0, -0.13)], 0.0)
	_bird_meshes[kind] = kit
	return kit

## A body of revolution round Z: `profile` holds [z, radius] pairs; `squash` scales x and y.
func _lathe(profile: Array, squash: Vector2, sides: int, lift := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(profile.size() - 1):
		var a: Array = profile[k]
		var b: Array = profile[k + 1]
		for s in range(sides):
			var t0 := TAU * s / sides
			var t1 := TAU * (s + 1) / sides
			var p00 := Vector3(cos(t0) * a[1] * squash.x, sin(t0) * a[1] * squash.y + lift, a[0])
			var p01 := Vector3(cos(t1) * a[1] * squash.x, sin(t1) * a[1] * squash.y + lift, a[0])
			var p10 := Vector3(cos(t0) * b[1] * squash.x, sin(t0) * b[1] * squash.y + lift, b[0])
			var p11 := Vector3(cos(t1) * b[1] * squash.x, sin(t1) * b[1] * squash.y + lift, b[0])
			for v in [p00, p10, p11, p00, p11, p01]:
				st.set_normal(Vector3(v.x, v.y - lift, 0.0).normalized() if Vector2(v.x, v.y - lift).length() > 0.001 else Vector3.FORWARD)
				st.add_vertex(v)
	return st.commit()

## A flat panel (wing, tail) in the XZ plane, `y` above the body's axis; drawn from both sides.
func _panel(points: Array, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(1, points.size() - 1):
		for v in [points[0], points[k], points[k + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v.x, y, v.y))
	return st.commit()

func _bird_material(colour: Color, roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = roughness
	m.metallic_specular = 0.25   # feathers, not lacquer
	return m

func _bird_part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _update_flocks(delta: float) -> void:
	var focus: Vector3 = w.cam_focus
	for i in range(_flocks.size()):
		var f: Dictionary = _flocks[i]
		# Each flock keeps to its own patch of sky near the camera, over land.
		if not f.home or Vector2(f.centre.x - focus.x, f.centre.z - focus.z).length() > NEAR * 0.9:
			var a := TAU * i / float(FLOCKS) + randf() * 0.6
			f.centre = focus + Vector3(cos(a), 0, sin(a)) * randf_range(50.0, 140.0)
			f.centre.y = maxf(w.height_at(f.centre.x, f.centre.z), float(w.map.seaLevel))
			f.home = true
		f.flee = maxf(0.0, f.flee - delta)
		var speed: float = f.speed * (3.5 if f.flee > 0.0 else 1.0)
		f.angle += speed * delta
		var radius: float = f.radius + (f.flee * 12.0)
		var centre: Vector3 = f.centre + Vector3(cos(f.angle) * radius, f.height + f.flee * 6.0, sin(f.angle) * radius)
		var ground_y := maxf(w.height_at(centre.x, centre.z), float(w.map.seaLevel))
		centre.y = maxf(centre.y, ground_y + f.height + f.flee * 6.0)
		var heading := Vector3(-sin(f.angle), 0, cos(f.angle)) * signf(speed)
		for bird in f.birds:
			var n: Node3D = bird.node
			bird.phase += delta * (9.0 if f.flee > 0.0 else 6.0)
			n.position = centre + bird.offset + Vector3(0, sin(bird.phase * 0.3) * 0.6, 0)
			n.look_at(n.position + heading, Vector3.UP, true)   # (the model's nose is +Z)
			# A gull glides for stretches between beats; a crow rows on.
			var beat := 1.0
			if f.get("gull", false) and f.flee <= 0.0:
				bird.glide = float(bird.glide) + delta * 0.45
				beat = clampf(sin(float(bird.glide)) * 1.6 + 0.4, 0.08, 1.0)
			var flap := sin(bird.phase) * 0.6 * beat
			n.get_node("L").rotation.z = flap
			n.get_node("R").rotation.z = -flap
			# The wing tip lags the beat: the wing bends as it goes up and down.
			var lag := sin(bird.phase - 0.9) * 0.3 * beat
			n.get_node("L/Tip").rotation.z = lag
			n.get_node("R/Tip").rotation.z = -lag

## An explosion near a flock: the birds scatter.
func _scare(strength: float, at: Vector3) -> void:
	for f in _flocks:
		if Vector2(f.centre.x - at.x, f.centre.z - at.z).length() < 120.0:
			f.flee = maxf(float(f.flee), 4.0 + strength)

func flock_count() -> int:
	return _flocks.size()

# ---------------------------------------------------------------- orders

## A ring where units were sent: green to move, red to attack.
func ping(at: Vector3, attack := false) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _ring_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.3, 0.22, 0.9) if attack else Color(0.45, 0.95, 0.55, 0.9)
	mat.no_depth_test = true
	node.set_surface_override_material(0, mat)
	node.position = Vector3(at.x, maxf(w.height_at(at.x, at.z), float(w.map.seaLevel)) + 0.3, at.z)
	node.scale = Vector3(2.0, 0.8, 2.0)
	add_child(node)
	_rings.append({"node": node, "age": 0.0})
	if _ack != null:
		_ack.play()

func rings() -> int:
	return _rings.size()
