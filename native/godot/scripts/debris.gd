## Flying debris with real ballistics: clods of earth, splinters of armour and
## masonry thrown by explosions fall under gravity, bounce off the terrain
## with restitution and friction, tumble, and come to rest before they fade.
## Pieces that land in the sea sink. Every piece is one instance of a single
## MultiMesh, so a big battle's debris costs one draw call, and the pool is
## fixed in size: when it is full the oldest piece is reused.
extends MultiMeshInstance3D

const POOL := 360
const GRAVITY := 16.0        # a little above 9.8: at RTS scale real gravity looks floaty
const RESTITUTION := 0.34
const FRICTION := 0.55
const REST_TIME := 6.0       # seconds on the ground before a piece fades away

var world: Node
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _axis := PackedVector3Array()
var _angle := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _size := PackedFloat32Array()
var _age := PackedFloat32Array()     # < 0 means the slot is free
var _rest := PackedFloat32Array()
var _next := 0
var _alive := 0

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.6, 0.8)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	box.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = POOL
	for i in range(POOL):
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Packed arrays are values: resize each one itself, not a copy in a loop.
	_pos.resize(POOL)
	_vel.resize(POOL)
	_axis.resize(POOL)
	_angle.resize(POOL)
	_spin.resize(POOL)
	_size.resize(POOL)
	_age.resize(POOL)
	_rest.resize(POOL)
	_age.fill(-1.0)
	# Pieces fly anywhere on the map: never cull them by the pool's origin.
	custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 2000, 10000))

## Throws `count` pieces from `at`; `speed` is the launch speed in m/s,
## `size` the piece length in metres.
func scatter(at: Vector3, count: int, speed: float, size: float, color: Color, upward := 0.7) -> void:
	for i in range(count):
		var slot := _next
		_next = (_next + 1) % POOL
		if _age[slot] < 0.0:
			_alive += 1
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		dir = (dir * (1.0 - upward) + Vector3.UP * upward).normalized()
		_pos[slot] = at + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.5), randf_range(-0.4, 0.4))
		_vel[slot] = dir * speed * randf_range(0.45, 1.0)
		_axis[slot] = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_angle[slot] = randf() * TAU
		_spin[slot] = randf_range(4.0, 14.0)
		_size[slot] = size * randf_range(0.5, 1.2)
		_age[slot] = 0.0
		_rest[slot] = 0.0
		var shade := randf_range(0.75, 1.1)
		multimesh.set_instance_color(slot, Color(color.r * shade, color.g * shade, color.b * shade))
	multimesh.visible_instance_count = POOL if _alive > 0 else 0

func _physics_process(delta: float) -> void:
	if _alive == 0 or world == null:
		return
	var sea: float = float(world.map.seaLevel)
	for i in range(POOL):
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		var p := _pos[i]
		var v := _vel[i]
		var floor_y: float = world.height_at(p.x, p.z)
		var fade := 1.0
		if floor_y < sea and p.y < sea:
			# In the water: drag and a slow sink, then gone.
			v = v * maxf(0.0, 1.0 - delta * 4.0) + Vector3.DOWN * delta * 2.0
			p += v * delta
			_rest[i] += delta * 2.0
		else:
			v.y -= GRAVITY * delta
			p += v * delta
			var half := _size[i] * 0.25
			if p.y < floor_y + half:
				p.y = floor_y + half
				if v.y < 0.0:
					# Bounce off the slope: most of the vertical speed and some of the slide are lost.
					v = v.bounce(world.normal_at(p.x, p.z))
					v = Vector3(v.x * FRICTION, v.y * RESTITUTION, v.z * FRICTION)
					_spin[i] *= 0.6
				if v.length_squared() < 0.6:
					v = Vector3.ZERO
					_spin[i] = 0.0
					_rest[i] += delta
		_angle[i] += _spin[i] * delta
		_pos[i] = p
		_vel[i] = v
		if _rest[i] > REST_TIME:
			fade = maxf(0.0, 1.0 - (_rest[i] - REST_TIME) / 1.5)
			if fade <= 0.0 or _age[i] > 40.0:
				_age[i] = -1.0
				_alive -= 1
				multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), p))
				continue
		var s := _size[i] * fade
		multimesh.set_instance_transform(i, Transform3D(Basis(_axis[i], _angle[i]).scaled(Vector3(s, s, s)), p))
	if _alive == 0:
		multimesh.visible_instance_count = 0

func alive() -> int:
	return _alive
