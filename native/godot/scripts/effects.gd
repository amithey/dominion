extends Node3D
## Battle effects for the native world: muzzle flashes, rifle tracers, tank
## shells, explosions (fireball, rising smoke, sparks, a flash of light and a
## scorch mark on the ground), bullet impacts and burning wrecks.
## Particle and material resources are built once and shared; every effect is
## a short-lived node that update() fades and frees.

signal shake(strength: float, at: Vector3)

var audio: Node  # audio.gd; every effect also plays its sound when set
var world_ref: Node  # world.gd, for the profiler

var _fire: ParticleProcessMaterial
var _smoke: ParticleProcessMaterial
var _sparks: ParticleProcessMaterial
var _dirt: ParticleProcessMaterial
var _puff: ParticleProcessMaterial
var _fire_mesh: QuadMesh
var _smoke_mesh: QuadMesh
var _spark_mesh: QuadMesh
var _dirt_mesh: QuadMesh
var _flash_mesh: QuadMesh
var _tracer_mesh: BoxMesh
var _shell_mesh: BoxMesh
var _scorch: Texture2D
var _shock_mesh: PlaneMesh
var debris: MultiMeshInstance3D  # debris.gd: ballistic pieces thrown by blasts

# Live effects: {node, age, life, kind, ...}
var _live: Array[Dictionary] = []
var _shells: Array[Dictionary] = []

func _ready() -> void:
	debris = preload("res://scripts/debris.gd").new()
	add_child(debris)
	# The shock front of a blast: a bright ring racing outwards along the ground.
	var ring := Gradient.new()
	ring.set_color(0, Color(1, 0.9, 0.7, 0))
	ring.add_point(0.72, Color(1, 0.85, 0.6, 0))
	ring.add_point(0.9, Color(1, 0.9, 0.75, 0.55))
	ring.set_color(ring.get_point_count() - 1, Color(1, 1, 1, 0))
	var ring_tex := GradientTexture2D.new()
	ring_tex.gradient = ring
	ring_tex.fill = GradientTexture2D.FILL_RADIAL
	ring_tex.fill_from = Vector2(0.5, 0.5)
	ring_tex.fill_to = Vector2(0.5, 0.0)
	ring_tex.width = 128
	ring_tex.height = 128
	var shock_mat := StandardMaterial3D.new()
	shock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shock_mat.albedo_texture = ring_tex
	shock_mat.vertex_color_use_as_albedo = false
	shock_mat.no_depth_test = false
	_shock_mesh = PlaneMesh.new()
	_shock_mesh.size = Vector2(1, 1)
	_shock_mesh.material = shock_mat
	var soft := _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)], [0.0, 0.45, 1.0])
	_fire_mesh = _quad(2.0, _billboard(soft, true, false))
	_smoke_mesh = _quad(2.4, _billboard(soft, false, true))
	_spark_mesh = _quad(0.22, _billboard(soft, true, false))
	_dirt_mesh = _quad(0.5, _billboard(soft, false, true))
	var flash_mat := _billboard(soft, true, false)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # a plain mesh, not a particle
	flash_mat.albedo_color = Color(1.0, 0.78, 0.4)
	_flash_mesh = _quad(1.6, flash_mat)

	_fire = _particle_material(Vector3.UP, 180.0, 2.5, 7.0, Vector3(0, 2.0, 0), 5.0,
		[Color(1.0, 0.95, 0.7, 1), Color(1.0, 0.55, 0.12, 0.9), Color(0.45, 0.12, 0.03, 0.5), Color(0.1, 0.05, 0.03, 0)],
		[0.0, 0.25, 0.6, 1.0], 0.9, 2.2, [0.6, 1.4, 1.0])
	_smoke = _particle_material(Vector3.UP, 28.0, 1.2, 3.2, Vector3(0, 0.9, 0), 1.2,
		[Color(0.16, 0.15, 0.14, 0.0), Color(0.17, 0.16, 0.15, 0.72), Color(0.33, 0.32, 0.3, 0.4), Color(0.45, 0.44, 0.42, 0)],
		[0.0, 0.08, 0.5, 1.0], 1.2, 2.2, [0.5, 1.6, 3.2])
	_sparks = _particle_material(Vector3.UP, 70.0, 7.0, 16.0, Vector3(0, -9.8, 0), 0.6,
		[Color(1.0, 0.9, 0.55, 1), Color(1.0, 0.45, 0.1, 1), Color(0.3, 0.08, 0.02, 0)],
		[0.0, 0.5, 1.0], 0.6, 1.2, [1.0, 1.0, 0.6])
	_dirt = _particle_material(Vector3.UP, 40.0, 5.0, 11.0, Vector3(0, -9.8, 0), 0.4,
		[Color(0.24, 0.2, 0.15, 1), Color(0.3, 0.26, 0.2, 0.85), Color(0.35, 0.31, 0.25, 0)],
		[0.0, 0.6, 1.0], 0.6, 1.4, [1.0, 1.0, 0.8])
	_puff = _particle_material(Vector3.UP, 50.0, 0.6, 1.6, Vector3(0, 0.3, 0), 2.0,
		[Color(0.45, 0.41, 0.34, 0.55), Color(0.5, 0.46, 0.4, 0)],
		[0.0, 1.0], 0.4, 0.9, [0.6, 1.3, 1.8])

	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.45)
	tracer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(0.05, 0.05, 1.0)
	_tracer_mesh.material = tracer_mat
	_shell_mesh = BoxMesh.new()
	_shell_mesh.size = Vector3(0.14, 0.14, 2.2)
	_shell_mesh.material = tracer_mat

	var scorch := Gradient.new()
	scorch.set_color(0, Color(0.03, 0.025, 0.02, 0.9))
	scorch.add_point(0.55, Color(0.06, 0.05, 0.04, 0.6))
	scorch.set_color(scorch.get_point_count() - 1, Color(0.1, 0.08, 0.06, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = scorch
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_scorch = tex

# ---------------------------------------------------------------- building blocks

func _radial(colors: Array, offsets: Array) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t

# Fire and sparks glow (additive, unshaded); smoke and dirt are lit by the sun.
func _billboard(texture: Texture2D, glow: bool, lit: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = texture
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	return m

func _quad(size: float, material: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = material
	return q

func _particle_material(direction: Vector3, spread: float, v_min: float, v_max: float, gravity: Vector3, damping: float,
		colors: Array, offsets: Array, s_min: float, s_max: float, growth: Array) -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.damping_min = damping * 0.7
	p.damping_max = damping
	p.scale_min = s_min
	p.scale_max = s_max
	p.angle_min = -180
	p.angle_max = 180
	p.angular_velocity_min = -30
	p.angular_velocity_max = 30
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array(offsets)
	ramp.colors = PackedColorArray(colors)
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	p.color_ramp = ramp_tex
	var curve := Curve.new()
	curve.max_value = 4.0
	for i in range(growth.size()):
		curve.add_point(Vector2(float(i) / (growth.size() - 1), growth[i]))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	p.scale_curve = curve_tex
	return p

func _burst(process: ParticleProcessMaterial, mesh: Mesh, at: Vector3, amount: int, lifetime: float, scale := 1.0, box := Vector3.ZERO) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = process
	p.draw_pass_1 = mesh
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.92
	p.randomness = 0.4
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 40, 40))
	p.scale = Vector3.ONE * scale
	add_child(p)
	p.global_position = at
	p.emitting = true
	_live.append({"node": p, "age": 0.0, "life": lifetime + 0.2, "kind": "particles"})
	return p

func _light(at: Vector3, energy: float, reach: float, life: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	_live.append({"node": light, "age": 0.0, "life": life, "kind": "light", "energy": energy})

# ---------------------------------------------------------------- effects

## Short bright flash at a barrel tip.
func muzzle_flash(at: Vector3, big: bool) -> void:
	var flash := MeshInstance3D.new()
	flash.mesh = _flash_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.scale = Vector3.ONE * (2.4 if big else 0.7)
	add_child(flash)
	flash.global_position = at
	_live.append({"node": flash, "age": 0.0, "life": 0.07 if not big else 0.12, "kind": "flash"})
	if audio:
		audio.play("cannon" if big else "rifle", at, 0.0 if big else -3.0, 2.4 if big else 1.0)
	if big:
		_light(at, 5.0, 14.0, 0.15)
		_burst(_smoke, _smoke_mesh, at, 6, 2.2, 0.6)

## Rifle tracer: a glowing streak that travels to the target in a few frames.
func tracer(from: Vector3, to: Vector3) -> void:
	var streak := MeshInstance3D.new()
	streak.mesh = _tracer_mesh
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streak)
	var length := from.distance_to(to)
	streak.global_position = from
	if length > 0.01:
		streak.look_at_from_position(from, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_live.append({"node": streak, "age": 0.0, "life": 0.09, "kind": "tracer", "from": from, "to": to, "length": minf(length, 3.5)})

## Tank shell in flight; on_hit(position) runs when it lands.
func shell(from: Vector3, to: Vector3, on_hit: Callable) -> void:
	var projectile := MeshInstance3D.new()
	projectile.mesh = _shell_mesh
	projectile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(projectile)
	projectile.global_position = from
	projectile.look_at_from_position(from, to, Vector3.UP)
	_shells.append({"node": projectile, "from": from, "to": to, "t": 0.0, "time": maxf(from.distance_to(to) / 160.0, 0.04), "hit": on_hit})

## Explosion: size 1 is a tank shell hit, 3-4 a destroyed vehicle.
func explosion(at: Vector3, size: float, on_ground: bool) -> void:
	_burst(_fire, _fire_mesh, at + Vector3.UP * 0.4 * size, int(14 * size), 0.9, size * 0.8)
	_burst(_smoke, _smoke_mesh, at + Vector3.UP * 0.6 * size, int(10 * size), 5.0 + size, size * 0.9)
	_burst(_sparks, _spark_mesh, at + Vector3.UP * 0.3, int(18 * size), 1.3, 1.0)
	if on_ground:
		_burst(_dirt, _dirt_mesh, at, int(16 * size), 1.4, size * 0.7)
		# Clods of earth thrown out of the crater fall back and bounce.
		debris.scatter(at, int(5 + 4 * size), 6.0 + 3.0 * size, 0.28 + 0.1 * minf(size, 3.0), Color(0.27, 0.22, 0.16))
		if size >= 0.9:
			var shock := MeshInstance3D.new()
			shock.mesh = _shock_mesh
			shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(shock)
			shock.global_position = at + Vector3.UP * 0.25
			shock.scale = Vector3.ONE * 0.5
			_live.append({"node": shock, "age": 0.0, "life": 0.28 + 0.06 * size, "kind": "shock", "reach": 5.0 + 4.5 * size})
		var mark := Decal.new()
		mark.texture_albedo = _scorch
		mark.size = Vector3(size * 3.4, 4.0, size * 3.4)
		mark.rotation.y = randf() * TAU
		add_child(mark)
		mark.global_position = at
		_live.append({"node": mark, "age": 0.0, "life": 45.0, "kind": "scorch"})
	_light(at + Vector3.UP * size, 9.0 * size, 10.0 + 8.0 * size, 0.35 + 0.1 * size)
	if audio:
		audio.play("explosion", at, -4.0 + 3.0 * minf(size, 3.0), 1.6 + size)
	shake.emit(0.25 * size, at)

## Bullet striking the ground or a soldier: a small puff of dust.
func impact(at: Vector3) -> void:
	if audio:
		audio.play("impact", at, -12.0, 0.5)
	_burst(_puff, _smoke_mesh, at, 3, 0.8, 0.35)

## Projectiles that are seen to fly: kind is "missile" (a guided missile with
## a smoke trail, following `track` if given), "rocket" (a small unguided
## rocket), "bomb" (falls from the aircraft, gathering speed), "shell_arc" (an
## artillery shell on a high arc), "torpedo" (runs just under the water with a
## wake). on_hit(position) runs where it lands; `delay` staggers salvos.
var _projectiles: Array[Dictionary] = []
var _projectile_meshes := {}
var launched := {}   # projectile kind -> how many were fired (checked by tests)

func projectile(kind: String, from: Vector3, to: Vector3, on_hit: Callable, delay := 0.0, track: Node3D = null) -> void:
	var speed: float = {"missile": 75.0, "rocket": 65.0, "bomb": 0.0, "shell_arc": 55.0, "torpedo": 26.0}.get(kind, 60.0)
	var dist := from.distance_to(to)
	var time := sqrt(2.0 * maxf(from.y - to.y, 1.0) / 9.8) if kind == "bomb" else maxf(dist / speed, 0.15)
	var arc: float = {"missile": 0.12, "rocket": 0.06, "shell_arc": 0.32, "bomb": 0.0, "torpedo": 0.0}.get(kind, 0.0) * dist
	var node := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _projectile_mesh(kind)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.rotation.x = -PI * 0.5  # the cylinder lies along -Z, where look_at points
	node.add_child(body)
	if kind in ["missile", "rocket"]:
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.65, 0.3)
		glow.light_energy = 2.0
		glow.omni_range = 5.0
		node.add_child(glow)
	node.visible = delay <= 0.0
	add_child(node)
	node.global_position = from
	launched[kind] = int(launched.get(kind, 0)) + 1
	_projectiles.append({"kind": kind, "node": node, "from": from, "to": to, "t": -delay, "time": time, "arc": arc, "hit": on_hit, "track": track, "puff": 0.0})
	if delay <= 0.0 and audio and kind != "bomb":
		audio.play("cannon", from, -8.0, 1.2)

func _projectile_mesh(kind: String) -> Mesh:
	if not _projectile_meshes.has(kind):
		var c := CylinderMesh.new()
		var m := StandardMaterial3D.new()
		m.roughness = 0.5
		match kind:
			"bomb":
				c.top_radius = 0.12
				c.bottom_radius = 0.28
				c.height = 1.3
				m.albedo_color = Color("3d4432")
			"torpedo":
				c.top_radius = 0.2
				c.bottom_radius = 0.2
				c.height = 1.8
				m.albedo_color = Color("2a2e30")
			"shell_arc":
				c.top_radius = 0.05
				c.bottom_radius = 0.14
				c.height = 0.7
				m.albedo_color = Color(1.0, 0.8, 0.45)
				m.emission_enabled = true
				m.emission = Color(1.0, 0.6, 0.25)
			_:
				c.top_radius = 0.03 if kind == "missile" else 0.05
				c.bottom_radius = 0.1
				c.height = 1.3 if kind == "missile" else 0.8
				m.albedo_color = Color("dfe3e6")
		c.radial_segments = 8
		c.rings = 1
		c.material = m
		_projectile_meshes[kind] = c
	return _projectile_meshes[kind]

func _move_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		p.t += delta
		if p.t < 0.0:
			continue
		var node: Node3D = p.node
		if not node.visible:
			node.visible = true
			if audio and p.kind != "bomb":
				audio.play("cannon", p.from, -8.0, 1.2)
		if p.track != null and is_instance_valid(p.track):
			p.to = p.track.global_position  # guided: the missile follows its target
		var k: float = minf(p.t / p.time, 1.0)
		var pos: Vector3 = p.from.lerp(p.to, k)
		if p.kind == "bomb":
			pos = Vector3(lerpf(p.from.x, p.to.x, k), lerpf(p.from.y, p.to.y, k * k), lerpf(p.from.z, p.to.z, k))
		else:
			pos.y += p.arc * 4.0 * k * (1.0 - k)
		var ahead: Vector3 = pos - node.global_position
		node.global_position = pos
		if ahead.length() > 0.01:
			node.look_at(pos + ahead, Vector3.UP if absf(ahead.normalized().y) < 0.98 else Vector3.RIGHT)
		p.puff += delta
		if p.puff > 0.05:
			p.puff = 0.0
			match p.kind:
				"missile", "rocket":
					trail(pos - ahead.normalized() * 0.6)
				"torpedo":
					_burst(_puff, _smoke_mesh, pos + Vector3.UP * 0.4, 2, 1.2, 0.5)
		if k >= 1.0:
			node.queue_free()
			_projectiles.remove_at(i)
			p.hit.call(p.to)

## Exhaust behind a missile in flight: a bright spark and a puff of smoke.
func trail(at: Vector3) -> void:
	_burst(_smoke, _smoke_mesh, at, 2, 2.6, 0.5)
	_burst(_fire, _fire_mesh, at, 1, 0.22, 0.3)

## Nuclear blast: a blinding flash, a rising column and a spreading cap of
## smoke and fire, and a shock that shakes the camera from far away.
func mushroom(at: Vector3, size: float) -> void:
	_light(at + Vector3.UP * size, 60.0, size * 6.0, 2.5)
	for i in range(6):
		var h := size * (0.15 + 0.16 * i)
		_burst(_fire, _fire_mesh, at + Vector3.UP * h, 20, 2.5, size * 0.09 * (1.0 + i * 0.1), Vector3.ONE * size * 0.05)
		_burst(_smoke, _smoke_mesh, at + Vector3.UP * h, 16, 16.0, size * 0.12)
	var top := at + Vector3.UP * size * 1.1
	_burst(_fire, _fire_mesh, top, 60, 3.0, size * 0.22)
	_burst(_smoke, _smoke_mesh, top, 70, 22.0, size * 0.3)
	_burst(_dirt, _dirt_mesh, at, 80, 2.5, size * 0.25)
	# The cloud itself: a column and a cap that climb, swell, cool from glowing
	# orange to grey-brown smoke and thin out over half a minute.
	var cloud := Node3D.new()
	add_child(cloud)
	cloud.global_position = at
	# Lumpy billows, not smooth shapes: the column and the cap are each built
	# from overlapping puffs in three smoke tones. The hot core glows at first.
	var tones := [Color(0.30, 0.26, 0.23), Color(0.42, 0.37, 0.32), Color(0.55, 0.50, 0.45)]
	var mats := []
	for i in range(tones.size()):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(tones[i], 0.95)
		m.roughness = 1.0
		m.emission_enabled = true
		m.emission = Color(1.0, 0.42, 0.1)
		m.emission_energy_multiplier = 1.6 - i * 0.6
		mats.append(m)
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 1.0
	puff_mesh.height = 2.0
	puff_mesh.radial_segments = 14
	puff_mesh.rings = 7
	var rng := RandomNumberGenerator.new()
	var cap := Node3D.new()
	cap.position.y = size * 0.95
	cloud.add_child(cap)
	var puffs := []
	# Column: a twisting stack, wider at the foot.
	for i in range(9):
		var t := i / 8.0
		var r := size * lerpf(0.2, 0.12, t) * rng.randf_range(0.85, 1.15)
		puffs.append([cloud, Vector3(rng.randf_range(-0.04, 0.04) * size, size * 0.9 * t, rng.randf_range(-0.04, 0.04) * size), Vector3(r, r * 1.1, r), 0 if t < 0.4 else 1])
	# Cap: a ring of billows rolling outward, a crown on top, a darker underside.
	for i in range(14):
		var a := TAU * i / 14.0 + rng.randf() * 0.2
		var r := size * rng.randf_range(0.16, 0.22)
		puffs.append([cap, Vector3(cos(a), rng.randf_range(-0.05, 0.08), sin(a)) * size * 0.3, Vector3(r, r * 0.8, r), 1 + (i % 2)])
	for i in range(7):
		var a := TAU * i / 7.0
		var r := size * rng.randf_range(0.14, 0.19)
		puffs.append([cap, Vector3(cos(a) * size * 0.14, size * 0.12, sin(a) * size * 0.14), Vector3(r, r * 0.85, r), 2])
	puffs.append([cap, Vector3(0, -size * 0.08, 0), Vector3(size * 0.3, size * 0.12, size * 0.3), 0])
	# Base surge: a low ring of dust rolling out along the ground.
	for i in range(12):
		var a := TAU * i / 12.0
		var r := size * rng.randf_range(0.1, 0.15)
		puffs.append([cloud, Vector3(cos(a), 0.0, sin(a)) * size * 0.4, Vector3(r, r * 0.55, r), 1])
	for p in puffs:
		var puff := MeshInstance3D.new()
		puff.mesh = puff_mesh
		puff.material_override = mats[p[3]]
		puff.position = p[1]
		puff.scale = p[2]
		puff.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p[0].add_child(puff)
	cloud.scale = Vector3.ONE * 0.3
	_live.append({"node": cloud, "age": 0.0, "life": 40.0, "kind": "mushroom", "mats": mats, "size": size, "cap": cap})
	var mark := Decal.new()
	mark.texture_albedo = _scorch
	mark.size = Vector3(size * 2.2, 12.0, size * 2.2)
	add_child(mark)
	mark.global_position = at
	_live.append({"node": mark, "age": 0.0, "life": 240.0, "kind": "scorch"})
	burn(at, 60.0)
	if audio:
		audio.play("explosion", at, 6.0, 6.0)
	shake.emit(3.0, at)

## An EMP: a pale blue pulse and a crackle of sparks, no fireball.
func emp_flash(at: Vector3, size: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.75, 1.0)
	light.light_energy = 14.0
	light.omni_range = size * 2.0
	add_child(light)
	light.global_position = at + Vector3.UP * 4.0
	_live.append({"node": light, "age": 0.0, "life": 0.8, "kind": "light", "energy": 14.0})
	_burst(_sparks, _spark_mesh, at + Vector3.UP * 2.0, 90, 1.6, 1.4, Vector3(size, 2.0, size) * 0.5)

## A wreck that keeps burning and smoking for a while.
func burn(at: Vector3, seconds: float) -> void:
	for i in range(int(seconds / 3.0)):
		_live.append({"node": null, "age": -i * 3.0, "life": 0.0, "kind": "burn", "at": at, "fired": false})

# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	var clock: int = world_ref.clock() if world_ref != null else 0
	_move_projectiles(delta)
	for i in range(_shells.size() - 1, -1, -1):
		var s: Dictionary = _shells[i]
		s.t += delta
		var k: float = minf(s.t / s.time, 1.0)
		var node: Node3D = s.node
		# A real trajectory: aimed a little high, the shell drops onto its mark under gravity.
		var pos: Vector3 = s.from.lerp(s.to, k) + Vector3.UP * (0.5 * 9.8 * s.t * maxf(s.time - s.t, 0.0))
		var ahead: Vector3 = pos - node.global_position
		node.global_position = pos
		if ahead.length() > 0.01 and absf(ahead.normalized().y) < 0.98:
			node.look_at(pos + ahead, Vector3.UP)
		if k >= 1.0:
			node.queue_free()
			_shells.remove_at(i)
			s.hit.call(s.to)
	for i in range(_live.size() - 1, -1, -1):
		var e: Dictionary = _live[i]
		e.age += delta
		match e.kind:
			"flash":
				e.node.scale *= 0.8
			"light":
				e.node.light_energy = e.energy * maxf(0.0, 1.0 - e.age / e.life)
			"tracer":
				var k: float = minf(e.age / e.life, 1.0)
				e.node.global_position = e.from.lerp(e.to, k)
				e.node.scale = Vector3(1, 1, e.length)
			"shock":
				var k: float = minf(e.age / e.life, 1.0)
				var ease := 1.0 - (1.0 - k) * (1.0 - k)
				e.node.scale = Vector3.ONE * lerpf(0.5, e.reach * 2.0, ease)
				e.node.transparency = k
			"scorch":
				e.node.modulate.a = clampf((e.life - e.age) / 8.0, 0.0, 1.0)
			"mushroom":
				var k: float = e.age / e.life
				var grow := 1.0 - pow(1.0 - minf(e.age / 7.0, 1.0), 3.0)
				e.node.scale = Vector3.ONE * lerpf(0.3, 1.0, grow) * (1.0 + k * 0.3)
				e.cap.position.y = e.size * (0.95 + 0.35 * k)
				e.cap.scale = Vector3(1.0 + k * 0.7, 1.0, 1.0 + k * 0.7)
				e.cap.rotate_y(delta * 0.05)
				for m in e.mats:
					m.emission_energy_multiplier = maxf(0.0, m.emission_energy_multiplier - delta * 0.25)
					m.albedo_color.a = 0.95 * clampf((1.0 - k) * 2.5, 0.0, 1.0)
			"burn":
				if e.age >= 0.0 and not e.fired:
					e.fired = true
					_burst(_smoke, _smoke_mesh, e.at + Vector3.UP * 1.2, 8, 5.5, 1.1)
					_burst(_fire, _fire_mesh, e.at + Vector3.UP * 0.8, 5, 1.2, 0.5)
				if e.fired:
					_live.remove_at(i)
				continue
		if e.age >= e.life:
			if e.node:
				e.node.queue_free()
			_live.remove_at(i)
	if world_ref != null:
		world_ref.spent("effects", clock)
