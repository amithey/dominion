extends Node3D
## DOMINION world, native renderer.
## Loads a map exported by the browser game (js/map-export.js, ?export=...) so
## both engines show the same island: terrain, trees, buildings and units.
## Forward+ provides the sea's refraction/depth colour, SSAO, fog and soft
## shadows. Command-line (after "--"):
##   --bench=N [--no-vsync] [--quit-after-bench]   same phases as the browser
##   --capture-views                               renders build/view-*.png

const MAP_PATH := "res://data/map-seed1.json"
const SOLDIER_HEIGHT := 2.35       # the browser's readable RTS scale
const SOLDIER_SPEED := 5.2         # metres per second while running
const RUN_CLIP_SPEED := 4.6        # speed the run clip was authored for (no foot sliding)
const TANK_SPEED := 4.2
const BUILDING_MODELS := {
	"hq": "res://assets/downtown/Building_Medium_2_001.gltf",
	"barracks": "res://assets/building-d.glb",
	"tankFactory": "res://assets/building-h.glb",
	"warehouse": "res://assets/building-f.glb",
	"farm": "res://assets/BigBarn.glb",
	"cottage": "res://assets/House_A.glb",
}
const BUILDING_SIZE := {"hq": 15.0, "barracks": 12.0, "tankFactory": 15.0, "warehouse": 12.0, "farm": 13.0, "cottage": 9.0}
const INFANTRY := ["soldier", "sniper", "commando", "rocketSoldier", "worker"]
const VEHICLES := ["tank", "apc", "artillery", "aaVehicle", "mlrs", "samLauncher"]

var map: Dictionary
var heights := PackedFloat32Array()
var grid_size := 0
var grid_origin := Vector2.ZERO
var grid_step := 1.0
var start := Vector3.ZERO

var camera: Camera3D
var cam_focus := Vector3.ZERO
var cam_yaw := PI * 0.25
var cam_pitch := 0.95
var cam_dist := 115.0
var cam_dist_target := 115.0

var units: Array[Dictionary] = []
var status: Label
var selection_box: Panel
var dragging := false
var drag_start := Vector2.ZERO
var soldier_scene: PackedScene
var tank_scene: PackedScene

# Benchmark state (fields match js/benchmark.js)
const BENCH_WARMUP := 2.0
const BENCH_WARMUP_FRAMES := 60
const BENCH_DURATION := 8.0
const BENCH_PHASES := [
	{"name": "Army close-up", "dist": 85.0, "pitch": 0.8, "dx": 14.0, "dz": 18.0, "pan": 0.0},
	{"name": "Base overview", "dist": 200.0, "pitch": 0.95, "dx": 0.0, "dz": 10.0, "pan": 0.0},
	{"name": "Camera pan", "dist": 110.0, "pitch": 0.85, "dx": 0.0, "dz": 18.0, "pan": 45.0},
]
var bench_units := 0
var bench_phase := -1
var bench_elapsed := 0.0
var bench_warm := 0
var bench_measuring := false
var bench_frames: Array[float] = []
var bench_cpu: Array[float] = []
var bench_gpu: Array[float] = []
var bench_render_cpu: Array[float] = []
var bench_calls := 0
var bench_primitives := 0
var bench_results: Array = []
var drill: Array[Dictionary] = []
var drill_side := 1.0
var drill_timer := 0.0
var env: Environment
var sun: DirectionalLight3D
var terrain_node: MeshInstance3D
var sea_node: MeshInstance3D
var tree_nodes: Array[Node3D] = []
var grass_nodes: Array[Node3D] = []
var noise_texture: NoiseTexture2D
var quality := "high"
var fps_time := 0.0
var fps_frames := 0

func _ready() -> void:
	map = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var grid: Dictionary = map.grid
	grid_size = int(grid.size)
	grid_step = float(grid.step)
	grid_origin = Vector2(grid.origin[0], grid.origin[1])
	heights.resize(grid_size * grid_size)
	var cm: Array = grid.heightsCm
	for i in range(cm.size()):
		# The browser drops the map edge into an abyss; a seabed is enough here.
		heights[i] = maxf(float(cm[i]) / 100.0, -36.0)
	start = Vector3(map.startPositions[0][0], 0, map.startPositions[0][1])
	start.y = height_at(start.x, start.z)
	soldier_scene = load("res://assets/CharacterSoldier.glb")
	tank_scene = load("res://assets/Tank.fbx")

	noise_texture = NoiseTexture2D.new()
	noise_texture.width = 512
	noise_texture.height = 512
	noise_texture.seamless = true
	noise_texture.generate_mipmaps = true
	var fbm := FastNoiseLite.new()
	fbm.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fbm.frequency = 0.008
	fbm.fractal_octaves = 5
	noise_texture.noise = fbm
	await noise_texture.changed

	quality = pick_quality()
	build_environment()
	apply_quality()
	build_terrain()
	build_sea()
	build_trees()
	if quality != "low":
		build_grass()
	for b in map.buildings:
		place_building(b)
	for u in map.units:
		if u.key in INFANTRY or u.key in VEHICLES:
			spawn_unit(u.key, Vector3(u.x, 0, u.z), int(u.owner))
	camera = Camera3D.new()
	camera.fov = 48
	camera.near = 1
	camera.far = 2600
	add_child(camera)
	cam_focus = start + Vector3(0, 0, 1)
	make_hud()

	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--bench"):
			bench_units = clampi(int(arg.get_slice("=", 1)) if "=" in arg else 64, 1, 240)
		if arg == "--no-vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if bench_units > 0:
		start_benchmark()
	elif "--capture-views" in args:
		await capture_views()
	elif "--feature-probe" in args:
		await feature_probe()

# ---------------------------------------------------------------- quality

# Integrated GPUs (Intel UHD/Iris, AMD APUs) start on "balanced"; dedicated
# cards get everything. --quality=high|balanced|low overrides the guess.
func pick_quality() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			return arg.get_slice("=", 1)
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if adapter.contains("intel") or adapter.contains("radeon(tm) graphics") or adapter.contains("vega"):
		return "balanced"
	return "high"

func apply_quality() -> void:
	var viewport := get_viewport()
	match quality:
		"high":
			env.ssao_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 320
			viewport.msaa_3d = Viewport.MSAA_2X
		"balanced":
			env.ssao_enabled = false
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 230
			# Integrated GPUs are fill-rate bound: render 3D at 77% and upscale with FSR.
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			viewport.scaling_3d_scale = 0.77
		_:
			env.ssao_enabled = false
			env.glow_enabled = false
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 150
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			viewport.scaling_3d_scale = 0.6

# ---------------------------------------------------------------- terrain

func height_at(x: float, z: float) -> float:
	var gx := clampf((x - grid_origin.x) / grid_step, 0, grid_size - 1.001)
	var gz := clampf((z - grid_origin.y) / grid_step, 0, grid_size - 1.001)
	var c := int(gx)
	var r := int(gz)
	var fx := gx - c
	var fz := gz - r
	var i := r * grid_size + c
	var top := lerpf(heights[i], heights[i + 1], fx)
	var bottom := lerpf(heights[i + grid_size], heights[i + grid_size + 1], fx)
	return lerpf(top, bottom, fz)

func normal_at(x: float, z: float) -> Vector3:
	var e := grid_step
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()

func build_terrain() -> void:
	var n := grid_size
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(n * n)
	normals.resize(n * n)
	for r in range(n):
		for c in range(n):
			var i := r * n + c
			vertices[i] = Vector3(grid_origin.x + c * grid_step, heights[i], grid_origin.y + r * grid_step)
			var hl := heights[r * n + maxi(c - 1, 0)]
			var hr := heights[r * n + mini(c + 1, n - 1)]
			var hd := heights[maxi(r - 1, 0) * n + c]
			var hu := heights[mini(r + 1, n - 1) * n + c]
			normals[i] = Vector3(hl - hr, 2.0 * grid_step, hd - hu).normalized()
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for r in range(n - 1):
		for c in range(n - 1):
			var a := r * n + c
			indices[k] = a; indices[k + 1] = a + 1; indices[k + 2] = a + n
			indices[k + 3] = a + 1; indices[k + 4] = a + n + 1; indices[k + 5] = a + n
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	for layer in ["grass", "dirt", "rock", "sand"]:
		material.set_shader_parameter(layer + "_albedo", load("res://assets/terrain/%s_color.jpg" % layer))
		material.set_shader_parameter(layer + "_normal", load("res://assets/terrain/%s_normal.jpg" % layer))
	material.set_shader_parameter("sea_level", float(map.seaLevel))
	material.set_shader_parameter("noise_tex", noise_texture)
	terrain_node = MeshInstance3D.new()
	terrain_node.mesh = mesh
	terrain_node.material_override = material
	terrain_node.name = "Terrain"
	add_child(terrain_node)

func build_sea() -> void:
	var plane := PlaneMesh.new()
	# Large enough to reach the horizon from any RTS camera angle.
	var extent := 4200.0
	plane.size = Vector2(extent, extent)
	plane.subdivide_width = 420
	plane.subdivide_depth = 420
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader")
	material.set_shader_parameter("noise_tex", noise_texture)
	sea_node = MeshInstance3D.new()
	sea_node.mesh = plane
	sea_node.material_override = material
	sea_node.position.y = float(map.seaLevel)
	sea_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea_node.name = "Sea"
	add_child(sea_node)

func build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4d7fb8")
	sky_material.sky_horizon_color = Color("b9cfdc")
	sky_material.ground_horizon_color = Color("b9cfdc")
	sky_material.ground_bottom_color = Color("7d97a4")
	sky_material.sun_angle_max = 20
	var sky := Sky.new()
	sky.sky_material = sky_material
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("b3c7d3")
	env.fog_density = 0.0005
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 320
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.2
	add_child(sun)

# ---------------------------------------------------------------- trees

# One MultiMesh per mesh of each birch variant: 863 trees in ~10 draws.
func build_trees() -> void:
	var variants := []
	for v in range(1, 6):
		var root: Node3D = load("res://assets/nature/BirchTree_%d.gltf" % v).instantiate()
		var parts := []
		var top := 0.0
		for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
			var local := mesh_transform(root, mesh_instance)
			parts.append({"mesh": mesh_instance.mesh, "local": local})
			top = maxf(top, (local * mesh_instance.get_aabb()).end.y)
		root.free()
		variants.append({"parts": parts, "height": maxf(top, 0.1), "trees": []})
	for t in map.trees:
		var index: int = int(t.grove) % 5 if int(t.grove) >= 0 else int(absf(t.x * 7.0 + t.z * 13.0)) % 5
		variants[index].trees.append(t)
	# Split every variant into 96 m cells so trees outside the view are culled,
	# instead of one map-wide MultiMesh that is always drawn in full.
	var cells := {}
	for v in range(variants.size()):
		for t in variants[v].trees:
			var key := Vector3i(v, floori(t.x / 96.0), floori(t.z / 96.0))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(t)
	var leaf_materials := {}
	for key in cells:
		var variant: Dictionary = variants[key.x]
		var trees: Array = cells[key]
		for part in variant.parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part.mesh
			mm.instance_count = trees.size()
			for i in range(trees.size()):
				var t: Dictionary = trees[i]
				var size := 7.5 * float(t.scale) / float(variant.height)
				var spin := fmod(t.x * 12.9898 + t.z * 78.233, TAU)
				var basis := Basis(Vector3.UP, spin).scaled(Vector3(size, size * (0.92 + fmod(absf(t.x), 0.16)), size))
				mm.set_instance_transform(i, Transform3D(basis, Vector3(t.x, height_at(t.x, t.z) - 0.15, t.z)) * part.local)
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			if not leaf_materials.has(part.mesh):
				leaf_materials[part.mesh] = foliage_mesh(part.mesh)
			mm.mesh = leaf_materials[part.mesh]
			add_child(node)
			tree_nodes.append(node)

# Copy of a tree mesh drawn with the wind shader. The birch leaf texture is
# autumn yellow; the tint turns it into summer yellow-green foliage.
func foliage_mesh(source: Mesh) -> Mesh:
	var mesh: Mesh = source.duplicate()
	var shader: Shader = load("res://shaders/foliage.gdshader")
	for i in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(i) as BaseMaterial3D
		if material == null:
			continue
		var leafy: bool = material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or "leaf" in material.resource_name.to_lower() or (material.albedo_texture != null and "leaves" in material.albedo_texture.resource_path.to_lower())
		var foliage := ShaderMaterial.new()
		foliage.shader = shader
		foliage.set_shader_parameter("albedo_tex", material.albedo_texture)
		foliage.set_shader_parameter("leaves", leafy)
		foliage.set_shader_parameter("tint", Color(0.58, 0.84, 0.42) if leafy else material.albedo_color)
		foliage.set_shader_parameter("alpha_cut", material.alpha_scissor_threshold if leafy else 0.0)
		mesh.surface_set_material(i, foliage)
	return mesh

func mesh_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

# ---------------------------------------------------------------- grass

# One tuft of real blade triangles (no alpha texture).
func make_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(14):
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf() * 0.35
		var across := Vector3(cos(a + 1.4), 0, sin(a + 1.4))
		var h := rng.randf_range(0.28, 0.6)
		var w := rng.randf_range(0.05, 0.09)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.28)
		# Normals lean up so tufts light like the ground they stand on.
		st.set_normal(Vector3.UP.lerp(across.cross(Vector3.UP), 0.3).normalized())
		st.set_uv(Vector2(0, 0))
		st.add_vertex(base - across * w)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(base + across * w)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(base + lean + Vector3(0, h, 0))
	return st.commit()

# Tufts on flat grassland in 32 m cells that are only drawn near the camera.
func build_grass() -> void:
	var density := 0.6 if quality == "high" else 0.35
	var reach := 110.0 if quality == "high" else 75.0
	var tuft := make_tuft()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/grass.gdshader")
	material.set_shader_parameter("noise_tex", noise_texture)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var half := float(map.mapSize) * 0.5
	var cell := 32.0
	var per_cell := int(cell * cell * density)
	var cx := -half
	while cx < half:
		var cz := -half
		while cz < half:
			var transforms := []
			for i in range(per_cell):
				var x := cx + rng.randf() * cell
				var z := cz + rng.randf() * cell
				var y := height_at(x, z)
				if y < 1.8 or normal_at(x, z).y < 0.94:
					continue
				var size := rng.randf_range(0.7, 1.35)
				transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.2), size)), Vector3(x, y - 0.05, z)))
			if transforms.size() > 8:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = tuft
				mm.instance_count = transforms.size()
				for i in range(transforms.size()):
					mm.set_instance_transform(i, transforms[i])
				var node := MultiMeshInstance3D.new()
				node.multimesh = mm
				node.material_override = material
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.visibility_range_end = reach
				node.visibility_range_end_margin = 12.0
				add_child(node)
				grass_nodes.append(node)
			cz += cell
		cx += cell

# ---------------------------------------------------------------- buildings

func model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh_transform(root, mesh_instance) * mesh_instance.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func place_building(b: Dictionary) -> void:
	var path: String = BUILDING_MODELS.get(b.key, "res://assets/building-a.glb")
	var model: Node3D = load(path).instantiate()
	var bounds := model_bounds(model)
	var footprint: float = BUILDING_SIZE.get(b.key, 11.0)
	var factor := minf(footprint / maxf(maxf(bounds.size.x, bounds.size.z), 0.01), footprint * 1.1 / maxf(bounds.size.y, 0.01))
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-bounds.get_center().x * factor, -bounds.position.y * factor, -bounds.get_center().z * factor)
	var root := Node3D.new()
	root.add_child(model)
	# Built on the highest corner of its footprint, with a stone plinth that
	# buries into the slope rather than floating above it.
	var half := footprint * 0.55
	var lowest := INF
	var highest := -INF
	for corner in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half), Vector2.ZERO]:
		var h := height_at(b.x + corner.x, b.z + corner.y)
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	root.position = Vector3(b.x, highest, b.z)
	var plinth := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(footprint * 1.04, highest - lowest + 1.2, footprint * 1.04)
	plinth.mesh = box
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/architecture/concrete_diffuse.jpg")
	stone.normal_enabled = true
	stone.normal_texture = load("res://assets/architecture/concrete_normal.jpg")
	stone.roughness_texture = load("res://assets/architecture/concrete_roughness.jpg")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.18
	plinth.material_override = stone
	plinth.position.y = -box.size.y * 0.5 + 0.12
	root.add_child(plinth)
	add_child(root)

# ---------------------------------------------------------------- units

func spawn_unit(key: String, at: Vector3, owner: int) -> Dictionary:
	var vehicle := key in VEHICLES
	var node := Node3D.new()
	var model: Node3D = (tank_scene if vehicle else soldier_scene).instantiate()
	node.add_child(model)
	if vehicle:
		model.rotation.y = PI * 0.5  # the Quaternius tank's gun points along -X; units face +Z
	var bounds := model_bounds(model)
	var factor: float = (6.0 / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)) if vehicle else (SOLDIER_HEIGHT / maxf(bounds.size.y, 0.01))
	model.scale = Vector3.ONE * factor
	model.position.y = -bounds.position.y * factor
	add_child(node)
	var turret: Node3D = null
	var dust: GPUParticles3D = null
	if vehicle:
		turret = dress_vehicle(model, owner)
		dust = make_dust()
		node.add_child(dust)
	else:
		dress_soldier(model, owner)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.25 if not vehicle else 3.3
	torus.outer_radius = torus.inner_radius + 0.08
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color("9ff29b")
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.12
	ring.visible = false
	node.add_child(ring)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var unit := {
		"node": node, "ring": ring, "vehicle": vehicle, "selected": false, "target": null,
		"player": players[0] if not players.is_empty() else null, "clip": "", "owner": owner,
		"speed": TANK_SPEED if vehicle else SOLDIER_SPEED, "heading": 0.0, "moving": false,
		"turret": turret, "turret_yaw": 0.0, "dust": dust, "phase": at.x * 0.37 + at.z * 0.21,
		"meshes": model.find_children("*", "MeshInstance3D", true, false) if vehicle else [],
	}
	if unit.player:
		# Looked up once: searching the clip list every frame was most of the CPU time.
		unit.run_clip = find_clip(unit.player, ["tank_forward"] if vehicle else ["run_gun", "run"])
		unit.idle_clip = "" if vehicle else find_clip(unit.player, ["idle_gun", "idle"])
		for clip in [unit.run_clip, unit.idle_clip]:
			if clip != "":
				unit.player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	place_on_ground(unit, at)
	units.append(unit)
	animate(unit, false)
	return unit

# Uniform colours per nation: olive, desert tan, urban grey, woodland brown.
const UNIFORMS := [
	{"main": Color("5d6446"), "pants": Color("4c5139"), "gear": Color("55594a")},
	{"main": Color("9a8a66"), "pants": Color("857656"), "gear": Color("7d7462")},
	{"main": Color("5f6668"), "pants": Color("4c5254"), "gear": Color("585d5f")},
	{"main": Color("6a5a44"), "pants": Color("514536"), "gear": Color("5a5040")},
]
const VEHICLE_PAINT := [Color("3a4029"), Color("7a6b4b"), Color("4a4f4f"), Color("4d4131")]
var unit_materials := {}

func cached_material(key: String, make: Callable) -> Material:
	if not unit_materials.has(key):
		unit_materials[key] = make.call()
	return unit_materials[key]

func matte(color: Color, roughness := 0.88, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

# The Quaternius soldier ships holding all 14 weapons at once; keep the rifle.
# Its saturated toy colours become matte field uniform in the nation's colour.
func dress_soldier(model: Node3D, owner: int) -> void:
	var u: Dictionary = UNIFORMS[owner % UNIFORMS.size()]
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var weapon: bool = mesh_instance.get_parent().name == "Index1_R"
		if weapon and mesh_instance.name != "AK":
			mesh_instance.visible = false
			continue
		for i in range(mesh_instance.mesh.get_surface_count()):
			var source: Material = mesh_instance.mesh.surface_get_material(i)
			var name: String = source.resource_name if source else ""
			var key := "%d:%s:%s" % [owner, name, weapon]
			var material: Material = null
			if weapon:
				material = cached_material(key, func(): return matte(Color("5a3f2a"), 0.8) if name == "Wood" else matte(Color("2c2e2f"), 0.45, 0.6))
			else:
				match name:
					"Character_Main": material = cached_material(key, func(): return matte(u.main))
					"Pants": material = cached_material(key, func(): return matte(u.pants))
					"Grey": material = cached_material(key, func(): return matte(u.gear, 0.8))
					"Black": material = cached_material(key, func(): return matte(Color("1e201c"), 0.75))
					"DarkGrey": material = cached_material(key, func(): return matte(Color("2f322d"), 0.8))
					"Skin":
						material = cached_material(key, func():
							var skin: StandardMaterial3D = (source as StandardMaterial3D).duplicate() if source is StandardMaterial3D else matte(Color("b08560"))
							skin.roughness = 0.65
							skin.metallic = 0.0
							return skin)
			if material:
				mesh_instance.set_surface_override_material(i, material)

# Painted, weathered hull; the turret and gun move onto one pivot at the turret
# centre so the turret can traverse. Returns that pivot.
func dress_vehicle(model: Node3D, owner: int) -> Node3D:
	var paint: Color = VEHICLE_PAINT[owner % VEHICLE_PAINT.size()]
	var shader: Shader = load("res://shaders/vehicle.gdshader")
	var shades := {"Main": 1.0, "Main_Light": 1.08, "Main_Dark": 0.78, "Main_Details": 0.5, "Wheels": 0.4}
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh_instance.mesh.get_surface_count()):
			var source: Material = mesh_instance.mesh.surface_get_material(i)
			var name: String = source.resource_name if source else "Main"
			var key := "vehicle:%d:%s" % [owner, name]
			var material := cached_material(key, func():
				var m := ShaderMaterial.new()
				m.shader = shader
				m.set_shader_parameter("noise_tex", noise_texture)
				m.set_shader_parameter("paint", paint)
				m.set_shader_parameter("shade", shades.get(name, 1.0))
				m.set_shader_parameter("metal", 1.0 if name in ["Main_Details", "Wheels"] else 0.0)
				return m)
			mesh_instance.set_surface_override_material(i, material)
	var turret := model.get_node_or_null("Tank_Turret") as Node3D
	var gun := model.get_node_or_null("Tank_Gun") as Node3D
	if not turret:
		return null
	var box: AABB = turret.transform * turret.get_aabb()
	var pivot := Node3D.new()
	pivot.name = "TurretPivot"
	model.add_child(pivot)
	pivot.position = box.get_center()
	# FBX models arrive rotated from Z-up, so the model's own Y axis is not
	# vertical: traverse around world-up expressed in the model's space.
	pivot.set_meta("axis", (model.transform.basis.orthonormalized().inverse() * Vector3.UP).normalized())
	for part in [turret, gun]:
		if part:
			var local: Transform3D = pivot.transform.affine_inverse() * part.transform
			part.get_parent().remove_child(part)
			pivot.add_child(part)
			part.transform = local
	return pivot

# Dust kicked up behind the tracks while a vehicle drives.
var dust_process: ParticleProcessMaterial
var dust_mesh: QuadMesh
func make_dust() -> GPUParticles3D:
	if not dust_process:
		dust_process = ParticleProcessMaterial.new()
		dust_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		dust_process.emission_box_extents = Vector3(1.6, 0.2, 0.4)
		dust_process.direction = Vector3(0, 1, -0.6)
		dust_process.spread = 35
		dust_process.initial_velocity_min = 0.5
		dust_process.initial_velocity_max = 1.4
		dust_process.gravity = Vector3(0, 0.15, 0)
		dust_process.damping_min = 0.6
		dust_process.damping_max = 1.2
		dust_process.scale_min = 0.9
		dust_process.scale_max = 1.6
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.5))
		grow.add_point(Vector2(1, 1.0))
		var grow_tex := CurveTexture.new()
		grow_tex.curve = grow
		dust_process.scale_curve = grow_tex
		var fade := Gradient.new()
		fade.set_color(0, Color(0.55, 0.49, 0.38, 0.26))
		fade.set_color(1, Color(0.6, 0.55, 0.45, 0.0))
		var fade_tex := GradientTexture1D.new()
		fade_tex.gradient = fade
		dust_process.color_ramp = fade_tex
		var puff := Gradient.new()
		puff.set_color(0, Color(1, 1, 1, 1))
		puff.set_color(1, Color(1, 1, 1, 0))
		var puff_tex := GradientTexture2D.new()
		puff_tex.gradient = puff
		puff_tex.fill = GradientTexture2D.FILL_RADIAL
		puff_tex.fill_from = Vector2(0.5, 0.5)
		puff_tex.fill_to = Vector2(0.5, 0.0)
		var puff_mat := StandardMaterial3D.new()
		puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff_mat.albedo_texture = puff_tex
		puff_mat.vertex_color_use_as_albedo = true
		puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dust_mesh = QuadMesh.new()
		dust_mesh.size = Vector2(2.6, 2.6)
		dust_mesh.material = puff_mat
	var dust := GPUParticles3D.new()
	dust.amount = 28
	dust.lifetime = 1.8
	dust.local_coords = false
	dust.emitting = false
	dust.process_material = dust_process
	dust.draw_pass_1 = dust_mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.position = Vector3(0, 0.3, -2.6)
	return dust

func place_on_ground(unit: Dictionary, at: Vector3) -> void:
	var node: Node3D = unit.node
	node.position = Vector3(at.x, height_at(at.x, at.z), at.z)
	var heading := Basis(Vector3.UP, unit.heading)
	if unit.vehicle:
		# Vehicles pitch and roll with the ground under their tracks.
		var up := normal_at(at.x, at.z)
		var travel := (heading * Vector3.BACK).slide(up).normalized()
		node.basis = Basis.looking_at(-travel, up)  # model +Z along the direction of travel
		for mesh_instance in unit.get("meshes", []):
			mesh_instance.set_instance_shader_parameter("ground_y", node.position.y)
	else:
		node.basis = heading

func find_clip(player: AnimationPlayer, names: Array) -> String:
	for wanted in names:
		for clip in player.get_animation_list():
			if clip.to_lower() == wanted or clip.to_lower().ends_with("|" + wanted):
				return clip
	return ""

# Clip playback speed follows ground speed, so feet do not slide.
func animate(unit: Dictionary, moving: bool) -> void:
	var player: AnimationPlayer = unit.player
	if not player or (unit.moving == moving and unit.clip != ""):
		return
	unit.moving = moving
	if unit.dust:
		unit.dust.emitting = moving
	var clip: String = unit.run_clip if moving else unit.idle_clip
	if clip == "":
		player.pause()  # a parked tank's tracks stop
		unit.clip = "parked"
		return
	player.play(clip, 0.25)
	unit.clip = clip
	player.speed_scale = (unit.speed / RUN_CLIP_SPEED) if moving else 1.0

func order_move(selected: Array, point: Vector3) -> void:
	var width := maxi(1, ceili(sqrt(selected.size())))
	var rows := ceili(float(selected.size()) / width)
	for i in range(selected.size()):
		var spacing := 5.5 if selected[i].vehicle else 2.6
		selected[i].target = point + Vector3((i % width - (width - 1) / 2.0) * spacing, 0, (floori(float(i) / width) - (rows - 1) / 2.0) * spacing)

func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for unit in units:
		if unit.turret:
			var aim: float = 0.0 if unit.moving else sin(now * 0.25 + unit.phase) * 0.9
			unit.turret_yaw = lerp_angle(unit.turret_yaw, aim, minf(1.0, delta * 0.8))
			unit.turret.basis = Basis(unit.turret.get_meta("axis"), unit.turret_yaw)
	for unit in units:
		var node: Node3D = unit.node
		if unit.target == null:
			continue
		var to: Vector3 = unit.target - node.position
		to.y = 0
		if to.length() < 0.3:
			unit.target = null
			animate(unit, false)
			continue
		var step := minf(to.length(), unit.speed * delta)
		var next: Vector3 = node.position + to.normalized() * step
		if height_at(next.x, next.z) < float(map.seaLevel) + 0.25:
			unit.target = null  # land units stop at the waterline
			animate(unit, false)
			continue
		var want := atan2(to.x, to.z)
		unit.heading = lerp_angle(unit.heading, want, minf(1.0, delta * (4.0 if unit.vehicle else 10.0)))
		place_on_ground(unit, next)
		animate(unit, true)

# ---------------------------------------------------------------- camera and input

# Same orbit as updateCamera() in js/main.js.
func update_camera(delta: float) -> void:
	cam_dist += (cam_dist_target - cam_dist) * (1.0 - exp(-delta * 12.0))
	var ground := maxf(height_at(cam_focus.x, cam_focus.z), float(map.seaLevel))
	var focus := Vector3(cam_focus.x, ground, cam_focus.z)
	camera.global_position = focus + Vector3(sin(cam_yaw) * cam_dist * cos(cam_pitch), cam_dist * sin(cam_pitch), cos(cam_yaw) * cam_dist * cos(cam_pitch))
	camera.look_at(focus)

func _process(delta: float) -> void:
	if bench_phase >= 0:
		benchmark_frame(delta)
	else:
		var pan := cam_dist * 0.9 * delta
		var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		if Input.is_physical_key_pressed(KEY_W): cam_focus += forward * pan
		if Input.is_physical_key_pressed(KEY_S): cam_focus -= forward * pan
		if Input.is_physical_key_pressed(KEY_D): cam_focus += right * pan
		if Input.is_physical_key_pressed(KEY_A): cam_focus -= right * pan
		if Input.is_physical_key_pressed(KEY_Q): cam_yaw += delta * 1.6
		if Input.is_physical_key_pressed(KEY_E): cam_yaw -= delta * 1.6
		if Input.is_physical_key_pressed(KEY_R): cam_pitch = minf(1.25, cam_pitch + delta * 1.1)
		if Input.is_physical_key_pressed(KEY_F): cam_pitch = maxf(0.3, cam_pitch - delta * 1.1)
	update_camera(delta)
	fps_time += delta
	fps_frames += 1
	if fps_time >= 1.0 and bench_phase < 0:
		status.text = "%d units  |  %d FPS  |  %s" % [units.size(), roundi(fps_frames / fps_time), RenderingServer.get_video_adapter_name()]
		fps_time = 0
		fps_frames = 0

func ground_point(screen: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var t := 0.0
	for i in range(400):
		var p := origin + direction * t
		if p.y <= height_at(p.x, p.z):
			return p
		t += 2.0
	return null

func _unhandled_input(event: InputEvent) -> void:
	if bench_phase >= 0:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist_target = maxf(18.0, cam_dist_target - 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist_target = minf(260.0, cam_dist_target + 6.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
			else:
				dragging = false
				selection_box.hide()
				var rect := Rect2(drag_start, event.position - drag_start).abs()
				var click := rect.size.length() < 8
				var closest: Dictionary = {}
				var best := 24.0
				for unit in units:
					if unit.owner != 0:
						continue
					var screen := camera.unproject_position(unit.node.position + Vector3.UP)
					if not event.shift_pressed:
						unit.selected = false
					if click and screen.distance_to(event.position) < best:
						best = screen.distance_to(event.position)
						closest = unit
					if not click and rect.has_point(screen):
						unit.selected = true
				if not closest.is_empty():
					closest.selected = true
				for unit in units:
					unit.ring.visible = unit.selected
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var point = ground_point(event.position)
			if point != null:
				order_move(units.filter(func(u): return u.selected), point)
	elif event is InputEventMouseMotion and dragging:
		var rect := Rect2(drag_start, event.position - drag_start).abs()
		selection_box.position = rect.position
		selection_box.size = rect.size
		selection_box.show()

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111f25e6")
	style.border_color = Color("a29269")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "DOMINION  /  NATIVE WORLD (seed %s, %s quality)" % [str(map.seed), quality]
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Drag/click: select   Right click: move   WASD: pan   Q/E: rotate   R/F: tilt   Wheel: zoom"
	column.add_child(hint)
	status = Label.new()
	column.add_child(status)
	selection_box = Panel.new()
	selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.6, 0.8, 0.4, 0.15)
	box.border_color = Color("cce58b")
	box.set_border_width_all(1)
	selection_box.add_theme_stylebox_override("panel", box)
	layer.add_child(selection_box)
	selection_box.hide()

# ---------------------------------------------------------------- benchmark

func start_benchmark() -> void:
	# Same drill as js/review.js: a 17x17 lattice at 4 m, every fourth an APC.
	for row in range(-8, 9):
		for col in range(-8, 9):
			if drill.size() >= bench_units:
				break
			var p := start + Vector3(col * 4, 0, row * 4)
			if height_at(p.x, p.z) < 0.5:
				continue
			var blocked := false
			for u in units:
				if Vector2(u.node.position.x, u.node.position.z).distance_to(Vector2(p.x, p.z)) < 3:
					blocked = true
					break
			if not blocked:
				drill.append(spawn_unit("apc" if drill.size() % 4 == 0 else "soldier", p, 0))
	for u in drill:
		u.selected = true
		u.ring.visible = true
	order_move(drill, start + Vector3(28, 0, 24))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	bench_phase = 0

func hold_bench_camera() -> void:
	var p: Dictionary = BENCH_PHASES[bench_phase]
	var a: float = bench_elapsed * 0.6 if p.pan > 0 else 0.0
	cam_focus = start + Vector3(p.dx + cos(a) * p.pan, 0, p.dz + sin(a) * p.pan)
	cam_yaw = PI * 0.25
	cam_pitch = p.pitch
	cam_dist = p.dist
	cam_dist_target = p.dist

func benchmark_frame(delta: float) -> void:
	hold_bench_camera()
	drill_timer += delta
	if drill_timer > 8.0:
		drill_timer = 0
		drill_side = -drill_side
		order_move(drill, start + Vector3(28 * drill_side, 0, 24))
	bench_elapsed += delta
	if not bench_measuring:
		bench_warm += 1
		if bench_elapsed >= BENCH_WARMUP and bench_warm >= BENCH_WARMUP_FRAMES:
			bench_measuring = true
			bench_elapsed = 0
		return
	bench_frames.append(delta * 1000)
	bench_cpu.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000)
	var rid := get_viewport().get_viewport_rid()
	bench_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	bench_render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
	bench_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	bench_primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	if bench_elapsed < BENCH_DURATION:
		return
	var sorted := bench_frames.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	var hitches := 0
	for f in bench_frames:
		total += f
		if f > 33.4:
			hitches += 1
	var cpu := 0.0
	for c in bench_cpu:
		cpu += c
	var gpu := 0.0
	for g in bench_gpu:
		gpu += g
	var render_cpu := 0.0
	for r in bench_render_cpu:
		render_cpu += r
	bench_results.append({
		"phase": BENCH_PHASES[bench_phase].name, "fps": snappedf(n / (total / 1000.0), 0.1),
		"p50": snappedf(sorted[int(n * 0.5)], 0.1), "p95": snappedf(sorted[mini(n - 1, int(n * 0.95))], 0.1),
		"p99": snappedf(sorted[mini(n - 1, int(n * 0.99))], 0.1), "worst": snappedf(sorted[n - 1], 0.1),
		"hitches": hitches, "cpu": snappedf(cpu / n, 0.1), "gpu": snappedf(gpu / n, 0.1), "render_cpu": snappedf(render_cpu / n, 0.1),
		"calls": roundi(float(bench_calls) / n), "triangles": roundi(float(bench_primitives) / n), "frames": n,
	})
	bench_phase += 1
	bench_elapsed = 0
	bench_warm = 0
	bench_measuring = false
	bench_frames.clear()
	bench_cpu.clear()
	bench_gpu.clear()
	bench_render_cpu.clear()
	bench_calls = 0
	bench_primitives = 0
	if bench_phase < BENCH_PHASES.size():
		return
	bench_phase = -1
	var valid := true
	for r in bench_results:
		if r.frames < 120:
			valid = false
	var size := DisplayServer.window_get_size()
	var data := {
		"version": 1, "engine": "godot " + Engine.get_version_info().string, "scene": "world " + str(map.seed),
		"renderer": RenderingServer.get_current_rendering_method(), "date": Time.get_datetime_string_from_system(true),
		"quality": quality, "units": units.size(), "resolution": "%d×%d" % [size.x, size.y],
		"vsync": DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
		"gpu": RenderingServer.get_video_adapter_name(), "valid": valid, "phases": bench_results,
	}
	print("DOMINION benchmark ", JSON.stringify(data))
	DirAccess.make_dir_recursive_absolute("res://build")
	var out := FileAccess.open("res://build/world-bench-%s-%d.json" % [RenderingServer.get_current_rendering_method(), bench_units], FileAccess.WRITE)
	out.store_string(JSON.stringify(data, "  "))
	out.close()
	if "--quit-after-bench" in OS.get_cmdline_user_args():
		get_tree().quit()

# ---------------------------------------------------------------- screenshots

func capture_views() -> void:
	var coast := find_coast(start)
	var views := {
		"base": [start + Vector3(0, 0, 1), 115.0, 0.95, PI * 0.25],
		"units": [start + Vector3(8, 0, 20), 30.0, 0.55, PI * 0.25],
		"coast": [coast, 70.0, 0.55, PI * 0.25 + 0.6],
		"landscape": [start + Vector3(-60, 0, 40), 230.0, 0.42, PI * 0.25 - 0.4],
	}
	# Keep the home army on the move so the capture shows running and dust.
	order_move(units.filter(func(u): return u.owner == 0), start + Vector3(10, 0, 44))
	for view in views:
		var v: Array = views[view]
		cam_focus = v[0]
		cam_dist = v[1]
		cam_dist_target = v[1]
		cam_pitch = v[2]
		cam_yaw = v[3]
		for i in range(90):
			if view == "units":
				cam_focus = army_centre()
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build")
		get_viewport().get_texture().get_image().save_png("res://build/view-%s.png" % view)
	get_tree().quit()

func army_centre() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for u in units:
		if u.owner == 0:
			sum += u.node.position
			count += 1
	return sum / maxi(count, 1)

func find_coast(from: Vector3) -> Vector3:
	for radius in range(20, 400, 6):
		for i in range(24):
			var a := i * TAU / 24.0
			var p := from + Vector3(cos(a), 0, sin(a)) * radius
			if height_at(p.x, p.z) < 0.0:
				return p
	return from

# --feature-probe: average frame time with each expensive feature switched off
# in turn, from the base overview camera. Run with --no-vsync.
func feature_probe() -> void:
	cam_focus = start + Vector3(0, 0, 10)
	cam_dist = 110.0
	cam_dist_target = 110.0
	cam_pitch = 0.85
	var viewport := get_viewport()
	var plain := StandardMaterial3D.new()
	plain.albedo_color = Color("61784a")
	var terrain_material := terrain_node.material_override
	var configs := [
		["all features", func(on): pass],
		["no SSAO", func(on): env.ssao_enabled = on],
		["no shadows", func(on): sun.shadow_enabled = on],
		["no MSAA/FXAA", func(on):
			viewport.msaa_3d = Viewport.MSAA_2X if on else Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if on else Viewport.SCREEN_SPACE_AA_DISABLED],
		["no fog/glow", func(on):
			env.fog_enabled = on
			env.glow_enabled = on],
		["plain terrain", func(on): terrain_node.material_override = terrain_material if on else plain],
		["no sea", func(on): sea_node.visible = on],
		["no trees", func(on):
			for t in tree_nodes: t.visible = on],
		["no grass", func(on):
			for g in grass_nodes: g.visible = on],
		["no units", func(on):
			for u in units: u.node.visible = on],
	]
	var results := {}
	for config in configs:
		config[1].call(false)
		for i in range(40):
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for i in range(90):
			await get_tree().process_frame
		results[config[0]] = snappedf((Time.get_ticks_usec() - t0) / 90000.0, 0.01)
		config[1].call(true)
	var all_off := func(on):
		for config in configs: config[1].call(on)
	all_off.call(false)
	for i in range(40):
		await get_tree().process_frame
	var t1 := Time.get_ticks_usec()
	for i in range(90):
		await get_tree().process_frame
	results["everything off"] = snappedf((Time.get_ticks_usec() - t1) / 90000.0, 0.01)
	all_off.call(true)
	print("DOMINION feature probe (ms per frame) ", JSON.stringify(results))
	get_tree().quit()
