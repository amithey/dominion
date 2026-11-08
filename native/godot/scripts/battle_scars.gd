extends Node3D
## Terrain-conformal fading battle scars & impact craters (Track 4C).
## Heavy shell, bomb, and missile blasts leave a 3D scorched crater ring aligned
## to the local hillside normal that weathers and fades out over SCAR_LIFETIME s.
## Uses a fixed-size ring buffer (MAX_SCARS) so memory and node count stay bounded.

const MAX_SCARS := 56
const SCAR_LIFETIME := 115.0

var w: Node
var _pool: Array = []   # [{node, mat_rim, mat_pit, age, life}]
var _cursor := 0
var _rim_mesh: TorusMesh
var _pit_mesh: CylinderMesh

func _init(world: Node = null) -> void:
	w = world
	name = "BattleScars"

func _ready() -> void:
	_rim_mesh = TorusMesh.new()
	_rim_mesh.inner_radius = 0.62
	_rim_mesh.outer_radius = 1.0
	_rim_mesh.rings = 18
	_rim_mesh.ring_segments = 6

	_pit_mesh = CylinderMesh.new()
	_pit_mesh.top_radius = 0.72
	_pit_mesh.bottom_radius = 0.55
	_pit_mesh.height = 0.06
	_pit_mesh.radial_segments = 16

func add_crater(at: Vector3, blast_size: float) -> void:
	if w == null or blast_size < 1.35:
		return
	var gy: float = w.height_at(at.x, at.z)
	if w.get("map") != null and gy <= float(w.map.seaLevel) + 0.25:
		return
	var entry: Dictionary
	if _pool.size() < MAX_SCARS:
		entry = _create_scar_slot()
		_pool.append(entry)
	else:
		entry = _pool[_cursor]
		_cursor = (_cursor + 1) % MAX_SCARS

	var radius := clampf(blast_size * 1.18, 1.5, 7.5)
	var root: Node3D = entry.node
	var nrm: Vector3 = w.normal_at(at.x, at.z) if w.has_method("normal_at") else Vector3.UP
	var up := nrm.normalized()
	var right := up.cross(Vector3.FORWARD)
	if right.length() < 0.01:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var fwd := right.cross(up).normalized()
	root.global_transform = Transform3D(Basis(right * radius, up * (0.28 + radius * 0.06), fwd * radius), Vector3(at.x, gy + 0.05, at.z))
	root.rotate_object_local(Vector3.UP, randf() * TAU)
	root.visible = true
	entry.age = 0.0
	entry.life = SCAR_LIFETIME * clampf(0.85 + blast_size * 0.12, 0.85, 1.45)
	(entry.mat_rim as StandardMaterial3D).albedo_color = Color(0.20, 0.17, 0.14, 0.88)
	(entry.mat_pit as StandardMaterial3D).albedo_color = Color(0.08, 0.07, 0.06, 0.94)

func _create_scar_slot() -> Dictionary:
	var root := Node3D.new()
	var mat_rim := StandardMaterial3D.new()
	mat_rim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_rim.albedo_color = Color(0.20, 0.17, 0.14, 0.88)
	mat_rim.roughness = 0.98
	mat_rim.disable_receive_shadows = false

	var mat_pit := StandardMaterial3D.new()
	mat_pit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_pit.albedo_color = Color(0.08, 0.07, 0.06, 0.94)
	mat_pit.roughness = 1.0

	var rim := MeshInstance3D.new()
	rim.mesh = _rim_mesh
	rim.material_override = mat_rim
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rim)

	var pit := MeshInstance3D.new()
	pit.mesh = _pit_mesh
	pit.material_override = mat_pit
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pit)

	root.visible = false
	add_child(root)
	return {"node": root, "mat_rim": mat_rim, "mat_pit": mat_pit, "age": 0.0, "life": SCAR_LIFETIME}

func update(delta: float) -> void:
	for entry in _pool:
		var root: Node3D = entry.node
		if not root.visible:
			continue
		entry.age = float(entry.age) + delta
		var ratio := clampf(float(entry.age) / maxf(float(entry.life), 1.0), 0.0, 1.0)
		if ratio >= 1.0:
			root.visible = false
			continue
		var fade := 1.0 - smoothstep(0.55, 1.0, ratio)
		(entry.mat_rim as StandardMaterial3D).albedo_color.a = 0.88 * fade
		(entry.mat_pit as StandardMaterial3D).albedo_color.a = 0.94 * fade
