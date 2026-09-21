extends Node3D
## Battle effects for the native world: muzzle flashes, rifle tracers, tank
## shells, explosions (fireball, rising smoke, sparks, a flash of light and a
## scorch mark on the ground), bullet impacts and burning wrecks.
## Particle and material resources are built once and shared; every effect is
## a short-lived node that update() fades and frees.

signal shake(strength: float, at: Vector3)

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

# Live effects: {node, age, life, kind, ...}
var _live: Array[Dictionary] = []
var _shells: Array[Dictionary] = []

func _ready() -> void:
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
		var mark := Decal.new()
		mark.texture_albedo = _scorch
		mark.size = Vector3(size * 3.4, 4.0, size * 3.4)
		mark.rotation.y = randf() * TAU
		add_child(mark)
		mark.global_position = at
		_live.append({"node": mark, "age": 0.0, "life": 45.0, "kind": "scorch"})
	_light(at + Vector3.UP * size, 9.0 * size, 10.0 + 8.0 * size, 0.35 + 0.1 * size)
	shake.emit(0.25 * size, at)

## Bullet striking the ground or a soldier: a small puff of dust.
func impact(at: Vector3) -> void:
	_burst(_puff, _smoke_mesh, at, 3, 0.8, 0.35)

## A wreck that keeps burning and smoking for a while.
func burn(at: Vector3, seconds: float) -> void:
	for i in range(int(seconds / 3.0)):
		_live.append({"node": null, "age": -i * 3.0, "life": 0.0, "kind": "burn", "at": at, "fired": false})

# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	for i in range(_shells.size() - 1, -1, -1):
		var s: Dictionary = _shells[i]
		s.t += delta
		var k: float = minf(s.t / s.time, 1.0)
		var node: Node3D = s.node
		node.global_position = s.from.lerp(s.to, k)
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
			"scorch":
				e.node.modulate.a = clampf((e.life - e.age) / 8.0, 0.0, 1.0)
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
