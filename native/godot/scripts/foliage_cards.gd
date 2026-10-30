extends RefCounted
## Plant cards (assets/art/foliage/*): crossed quads that show a cell of an atlas of plants, drawn with
## shaders/cards.gdshader. One MultiMesh per 32 m cell and plant kind; felled with the other vegetation (world.clear_site_grass).
const ART := "res://assets/art/foliage/"
## kind -> [atlas file, grid, card width (m), card height (m), quads in the star, wind sway, cut]
const KINDS := {
	"grass": ["grass_tufts_atlas_2048", Vector2(4, 3), 1.05, 0.9, 3, 0.10, 0.42],
	"flowers": ["wildflowers_atlas_2048", Vector2(3, 2), 0.7, 0.8, 2, 0.14, 0.45],
	"bush": ["bush_leaves_atlas_2048", Vector2(2, 2), 2.4, 2.0, 3, 0.05, 0.5],
	"reeds": ["reeds_atlas_1024", Vector2(2, 2), 1.5, 2.0, 2, 0.12, 0.45],
}
static var _meshes := {}
static var _materials := {}

static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var def: Array = KINDS[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads: int = def[4]
	for q in range(quads):
		var a := PI * float(q) / float(quads)
		var right := Vector3(cos(a), 0, sin(a)) * float(def[2]) * 0.5
		var up := Vector3(0, float(def[3]), 0)
		var n := Vector3(-sin(a), 0.35, cos(a)).normalized()   # normals lean up: the cards light like the ground under them
		var pts := [[-right, Vector2(0, 1)], [right, Vector2(1, 1)], [right + up, Vector2(1, 0)], [-right + up, Vector2(0, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(pts[idx][1])
			st.add_vertex(pts[idx][0])
	st.generate_tangents()
	var m: ArrayMesh = st.commit()
	_meshes[kind] = m
	return m

static func material(kind: String) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var def: Array = KINDS[kind]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/cards.gdshader")
	m.set_shader_parameter("atlas", load(ART + def[0] + ".png"))
	var normal = load(ART + def[0] + "_normal.png")
	if normal != null:
		m.set_shader_parameter("atlas_normal", normal)
	m.set_shader_parameter("grid", def[1])
	m.set_shader_parameter("sway", float(def[5]))
	m.set_shader_parameter("cut", float(def[6]))
	if kind == "bush" or kind == "reeds":
		m.set_shader_parameter("far_fade_start", 140.0)
	_materials[kind] = m
	return m

static func cell_count(kind: String) -> int:
	var g: Vector2 = KINDS[kind][1]
	return int(g.x * g.y)

## A node with `spots` ([{"pos": Vector3, "scale": float, "yaw": float, "cell": int, "tone": float}]) of one plant kind.
static func patch(kind: String, spots: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh(kind)
	mm.instance_count = spots.size()
	for i in range(spots.size()):
		var s: Dictionary = spots[i]
		var sc: float = s.scale
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(s.yaw)).scaled(Vector3(sc, sc, sc)), s.pos))
		mm.set_instance_custom_data(i, Color(float(s.cell), float(s.tone), 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.multimesh = mm
	node.material_override = material(kind)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
