extends RefCounted
## The sea's surface mesh: a grid whose spacing is fine over the map and widens toward the horizon, instead of one even grid over the
## whole 4 km. The swell is drawn by displacing vertices, so an even grid spends most of its 350,000 triangles on open ocean nobody
## looks at while sampling the 13 m waves over the island too coarsely (10 m cells). Rows and columns are shared by the whole grid, so
## the surface has no cracks where the spacing changes. About half the triangles, and the cells over the map are half the size.
const DENSE_COLUMNS := 240      # columns across the fine middle (the same rows)

## `half_map`: half the map's width (m); `extent`: half the sea's width (m).
static func build(half_map: float, extent: float) -> ArrayMesh:
	var dense_half := half_map + 160.0
	var step := (2.0 * dense_half) / DENSE_COLUMNS
	var line: Array[float] = []   # positions along one axis, from -extent to +extent
	var out_pos: Array[float] = []
	var x := dense_half
	var s := step
	while x < extent:
		s *= 1.28
		x = minf(x + s, extent)
		out_pos.append(x)
		if x >= extent:
			break
	for i in range(out_pos.size() - 1, -1, -1):
		line.append(-out_pos[i])
	for k in range(DENSE_COLUMNS + 1):
		line.append(-dense_half + k * step)
	for p in out_pos:
		line.append(p)
	var n := line.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	normals.resize(n * n)
	uvs.resize(n * n)
	for j in range(n):
		for i in range(n):
			var idx := j * n + i
			verts[idx] = Vector3(line[i], 0.0, line[j])
			normals[idx] = Vector3.UP
			uvs[idx] = Vector2(line[i] / (2.0 * extent) + 0.5, line[j] / (2.0 * extent) + 0.5)
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for j in range(n - 1):
		for i in range(n - 1):
			var a := j * n + i
			indices[k] = a; indices[k + 1] = a + 1; indices[k + 2] = a + n
			indices[k + 3] = a + 1; indices[k + 4] = a + n + 1; indices[k + 5] = a + n
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
