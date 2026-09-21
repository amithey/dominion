extends Node3D

const RADIUS := 9.0
const DISTRICTS := [Vector3(-22,0,-8),Vector3(0,0,-8),Vector3(22,0,-8)]
var units: Array[Dictionary] = []
var camera: Camera3D
var rig: Node3D
var selection_box: Panel
var status: Label
var dragging := false
var drag_start := Vector2.ZERO
var nav_region: NavigationRegion3D
var navigation_ready := false
var anim_names: Dictionary = {}
var benchmark_time := 0.0
var benchmark_frames := 0
var benchmark_samples: Array[float] = []
var destination_marker: MeshInstance3D
var max_units := 96
# --bench=N mirrors the browser's ?bench=N: same phases, camera formula,
# marching army and JSON fields, so the two engines can be compared directly.
const BENCH_WARMUP := 2.0
const BENCH_DURATION := 8.0
const BENCH_PHASES := [
	{"name":"Army close-up","dist":85.0,"pitch":0.8,"focus":Vector3(0,0,20),"pan":0.0},
	{"name":"Base overview","dist":200.0,"pitch":0.95,"focus":Vector3(0,0,0),"pan":0.0},
	{"name":"Camera pan","dist":110.0,"pitch":0.85,"focus":Vector3(0,0,10),"pan":45.0},
]
var bench_units := 0
var bench_phase := -1
var bench_elapsed := 0.0
var bench_frames: Array[float] = []
var bench_cpu: Array[float] = []
var bench_calls := 0
var bench_primitives := 0
var bench_results: Array = []
var bench_march := 0.0
var bench_side := 1.0

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return result

func mesh_node(mesh: Mesh, surface: Material, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface
	node.position = pos
	parent.add_child(node)
	return node

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("9cb4bc")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c3d2d7")
	world.environment.ambient_light_energy = 0.35
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var ground := PlaneMesh.new()
	ground.size = Vector2(240,240)
	var grass := material(Color("65705b"))
	var ground_texture: Texture2D = load("res://assets/grass_color.jpg")
	var ground_image := ground_texture.get_image()
	ground_image.generate_mipmaps()
	grass.albedo_texture = ImageTexture.create_from_image(ground_image)
	grass.uv1_scale = Vector3(32,32,32)
	mesh_node(ground,grass,Vector3.ZERO)
	for center in DISTRICTS:
		make_district(center)
	make_navigation()
	rig = Node3D.new()
	add_child(rig)
	camera = Camera3D.new()
	rig.add_child(camera)
	camera.position = Vector3(30,42,42)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 59
	camera.far = 220
	camera.look_at(Vector3.ZERO)
	camera.current = true
	make_hud()
	var marker_mesh := TorusMesh.new()
	marker_mesh.inner_radius = 1.0
	marker_mesh.outer_radius = 1.15
	destination_marker = mesh_node(marker_mesh,material(Color("d5bc72")),Vector3.ZERO)
	destination_marker.hide()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench"):
			bench_units = clampi(int(arg.get_slice("=",1)) if "=" in arg else 64,1,240)
		if arg == "--no-vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if bench_units > 0:
		max_units = bench_units
		spawn_company(bench_units)
		arrange_bench_army()
	else:
		spawn_company(24)
	await get_tree().physics_frame
	NavigationServer3D.map_force_update(get_world_3d().navigation_map)
	await get_tree().physics_frame
	for frame in range(120):
		var probe := NavigationServer3D.map_get_path(get_world_3d().navigation_map,Vector3(0,0,20),Vector3(0,0,-30),true)
		if probe.size() >= 3:
			navigation_ready = true
			break
		await get_tree().physics_frame
	if bench_units > 0:
		start_benchmark()
	elif "--smoke-test" in OS.get_cmdline_user_args():
		await run_smoke_test()
	elif "--capture-preview" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build")
		var error := get_viewport().get_texture().get_image().save_png("res://build/preview.png")
		get_tree().quit(error)

func make_district(center: Vector3) -> void:
	var district_script = preload("res://scripts/district.gd")
	var district := Node3D.new()
	district.set_script(district_script)
	add_child(district)
	district.position = center
	district.build(self, DISTRICTS.find(center))

func model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB = root.global_transform.affine_inverse()*node.global_transform*node.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func make_navigation() -> void:
	var nav := NavigationMesh.new()
	var vertices := PackedVector3Array()
	const COUNT := 51
	for z in range(COUNT):
		for x in range(COUNT):
			vertices.append(Vector3(x*2-50,0,z*2-50))
	nav.set_vertices(vertices)
	for z in range(COUNT-1):
		for x in range(COUNT-1):
			var center := Vector3(x*2-49,0,z*2-49)
			var blocked := false
			for district in DISTRICTS:
				if center.distance_to(district) < RADIUS+2:
					blocked = true
			if not blocked:
				var a := z*COUNT+x
				nav.add_polygon(PackedInt32Array([a,a+COUNT,a+COUNT+1,a+1]))
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nav
	add_child(nav_region)
	nav_region.set_navigation_map(get_world_3d().navigation_map)
	NavigationServer3D.map_set_active(get_world_3d().navigation_map,true)
	NavigationServer3D.map_set_use_async_iterations(get_world_3d().navigation_map,false)

func spawn_company(count: int) -> void:
	var packed: PackedScene = load("res://assets/CharacterSoldier.glb")
	for i in range(count):
		var index := units.size()
		if index >= max_units:
			break
		var root := Node3D.new()
		add_child(root)
		var model: Node3D = packed.instantiate()
		root.add_child(model)
		var bounds := model_bounds(model)
		var factor := 1.8/maxf(bounds.size.y,0.01)
		model.scale = Vector3.ONE*factor
		model.position.y = -bounds.position.y*factor
		root.position = Vector3((index%12-6)*2.4,0,12+(index/12)*2.8)
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.65
		ring_mesh.outer_radius = 0.72
		ring_mesh.rings = 16
		ring_mesh.ring_segments = 6
		var ring := mesh_node(ring_mesh,material(Color("cce58b")),Vector3(0,0.04,0),root)
		ring.visible = false
		var players := model.find_children("*","AnimationPlayer",true,false)
		var player: AnimationPlayer = players[0] if not players.is_empty() else null
		units.append({"node":root,"ring":ring,"selected":false,"path":PackedVector3Array(),"player":player})
		play_unit(units.back(),false)

func play_unit(unit: Dictionary, moving: bool) -> void:
	var player: AnimationPlayer = unit.player
	if not player:
		return
	var wanted := "run" if moving else "idle"
	if not anim_names.has(wanted):
		for animation in player.get_animation_list():
			if wanted in animation.to_lower():
				anim_names[wanted] = animation
				break
	if anim_names.has(wanted) and player.current_animation != anim_names[wanted]:
		player.get_animation(anim_names[wanted]).loop_mode = Animation.LOOP_LINEAR
		player.play(anim_names[wanted],0.18)

func order_move(point: Vector3) -> void:
	if not navigation_ready:
		return
	var selected: Array[Dictionary] = []
	for unit in units:
		if unit.selected:
			selected.append(unit)
	var width := maxi(1,ceili(sqrt(selected.size())))
	if selected.is_empty():
		return
	destination_marker.position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,point)+Vector3(0,0.08,0)
	destination_marker.show()
	var rows := ceili(float(selected.size())/width)
	for i in range(selected.size()):
		var target := point+Vector3((i%width-(width-1)/2.0)*2.0,0,(floori(float(i)/width)-(rows-1)/2.0)*2.0)
		target = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,target)
		selected[i].path = NavigationServer3D.map_get_path(get_world_3d().navigation_map,selected[i].node.position,target,true)

func _physics_process(delta: float) -> void:
	for unit in units:
		var path: PackedVector3Array = unit.path
		var node: Node3D = unit.node
		if not path.is_empty():
			var difference := path[0]-node.position
			if difference.length() < 0.15:
				path.remove_at(0)
				unit.path = path
			else:
				node.position = node.position.move_toward(path[0],delta*5.2)
				node.rotation.y = lerp_angle(node.rotation.y,atan2(difference.x,difference.z),minf(1,delta*9))
		play_unit(unit,not unit.path.is_empty())

func ground_point(screen: Vector2) -> Variant:
	return Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = maxf(20,camera.size-4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = minf(110,camera.size+4)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
			else:
				dragging = false
				selection_box.hide()
				var rect := Rect2(drag_start,event.position-drag_start).abs()
				var click := rect.size.length()<8
				var closest: Dictionary = {}
				var distance := 22.0
				for unit in units:
					var screen := camera.unproject_position(unit.node.position+Vector3.UP)
					if click and screen.distance_to(event.position)<distance:
						distance = screen.distance_to(event.position)
						closest = unit
					if not event.shift_pressed:
						unit.selected = false
					if not click and rect.has_point(screen):
						unit.selected = true
				if not closest.is_empty():
					closest.selected = true
				for unit in units:
					unit.ring.visible = unit.selected
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var point = ground_point(event.position)
			if point != null:
				order_move(point)
	elif event is InputEventMouseMotion and dragging:
		var rect := Rect2(drag_start,event.position-drag_start).abs()
		selection_box.position = rect.position
		selection_box.size = rect.size
		selection_box.show()

func _process(delta: float) -> void:
	if not rig:
		return
	if bench_phase >= 0:
		benchmark_frame(delta)
		return
	var motion := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	rig.position += rig.basis*motion*delta*30
	rig.position.x = clampf(rig.position.x,-45,45)
	rig.position.z = clampf(rig.position.z,-45,45)
	rig.rotation.y += (float(Input.is_physical_key_pressed(KEY_Q))-float(Input.is_physical_key_pressed(KEY_E)))*delta
	benchmark_time += delta
	benchmark_frames += 1
	benchmark_samples.append(delta*1000)
	if benchmark_time >= 2:
		benchmark_samples.sort()
		status.text = "%d units  |  %d FPS  |  frame p95 %.1f ms" % [units.size(),roundi(benchmark_frames/benchmark_time),benchmark_samples[int(benchmark_samples.size()*0.95)]]
		benchmark_time=0
		benchmark_frames=0
		benchmark_samples.clear()

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	top.position = Vector2(18,18)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("18242bea")
	panel_style.border_color = Color("b7a16b")
	panel_style.border_width_left = 3
	panel_style.set_corner_radius_all(4)
	top.add_theme_stylebox_override("panel",panel_style)
	layer.add_child(top)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,14)
	top.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "DOMINION  /  FRONTIER DISTRICTS"
	title.add_theme_font_size_override("font_size",22)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Drag / click: select   |   Right click: move   |   WASD: pan   |   Q/E: orbit   |   Wheel: zoom"
	column.add_child(hint)
	status = Label.new()
	column.add_child(status)
	var row := HBoxContainer.new()
	column.add_child(row)
	var select_all := Button.new()
	select_all.text = "Select army"
	select_all.pressed.connect(func():
		for unit in units:
			unit.selected=true
			unit.ring.visible=true)
	row.add_child(select_all)
	var add_units := Button.new()
	add_units.text = "Add 24 units (max 96)"
	add_units.pressed.connect(func():spawn_company(24))
	row.add_child(add_units)
	selection_box=Panel.new()
	selection_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.6,0.8,0.4,0.15)
	style.border_color=Color("cce58b")
	style.set_border_width_all(1)
	selection_box.add_theme_stylebox_override("panel",style)
	layer.add_child(selection_box)
	selection_box.hide()

func run_smoke_test() -> void:
	var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map,Vector3(0,0,20),Vector3(0,0,-30),true)
	if not navigation_ready or units.size()!=24 or path.size()<3:
		push_error("Desktop smoke test failed: units or navigation")
		get_tree().quit(1)
		return
	units[0].selected=true
	var start: Vector3 = units[0].node.position
	order_move(Vector3(-10,0,4))
	for frame in range(90):
		await get_tree().physics_frame
	if units[0].node.position.distance_to(start)<1:
		push_error("Desktop smoke test failed: movement")
		get_tree().quit(1)
		return
	print("DESKTOP_SMOKE_PASS: 24 models, navigation around districts, unit movement")
	get_tree().quit()

func arrange_bench_army() -> void:
	var columns := ceili(sqrt(units.size()*1.5))
	for i in range(units.size()):
		units[i].node.position = Vector3((i%columns-(columns-1)/2.0)*2.2,0,14+(i/columns)*2.4)

func start_benchmark() -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48
	camera.far = 2600
	rig.transform = Transform3D.IDENTITY
	for unit in units:
		unit.selected = true
		unit.ring.visible = true
	bench_march = 0
	order_move(Vector3(25,0,25))
	bench_phase = 0
	bench_elapsed = 0

# Same orbit as updateCamera() in js/main.js, yaw fixed at pi/4.
func hold_bench_camera() -> void:
	var phase: Dictionary = BENCH_PHASES[bench_phase]
	var angle: float = bench_elapsed*0.6 if phase.pan > 0 else 0.0
	var focus: Vector3 = phase.focus+Vector3(cos(angle),0,sin(angle))*phase.pan
	var yaw := PI*0.25
	var dist: float = phase.dist
	var pitch: float = phase.pitch
	camera.global_position = focus+Vector3(sin(yaw)*dist*cos(pitch),dist*sin(pitch),cos(yaw)*dist*cos(pitch))
	camera.look_at(focus)

func benchmark_frame(delta: float) -> void:
	hold_bench_camera()
	bench_march += delta
	if bench_march > 8:
		bench_march = 0
		bench_side = -bench_side
		order_move(Vector3(25*bench_side,0,25))
	bench_elapsed += delta
	if bench_elapsed < BENCH_WARMUP:
		return
	bench_frames.append(delta*1000)
	bench_cpu.append((Performance.get_monitor(Performance.TIME_PROCESS)+Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000)
	bench_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	bench_primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	if bench_elapsed < BENCH_WARMUP+BENCH_DURATION:
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
	var cpu_total := 0.0
	for c in bench_cpu:
		cpu_total += c
	bench_results.append({
		"phase":BENCH_PHASES[bench_phase].name,
		"fps":snappedf(n/(total/1000.0),0.1),
		"p50":snappedf(sorted[int(n*0.5)],0.1),"p95":snappedf(sorted[mini(n-1,int(n*0.95))],0.1),
		"p99":snappedf(sorted[mini(n-1,int(n*0.99))],0.1),"worst":snappedf(sorted[n-1],0.1),
		"hitches":hitches,"cpu":snappedf(cpu_total/n,0.1),
		"calls":roundi(float(bench_calls)/n),"triangles":roundi(float(bench_primitives)/n),"frames":n,
	})
	bench_phase += 1
	bench_elapsed = 0
	bench_frames.clear()
	bench_cpu.clear()
	bench_calls = 0
	bench_primitives = 0
	if bench_phase < BENCH_PHASES.size():
		return
	bench_phase = -1
	var size := DisplayServer.window_get_size()
	var valid := true
	for r in bench_results:
		if r.frames < 120:
			valid = false
	var data := {
		"version":1,"engine":"godot "+Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"date":Time.get_datetime_string_from_system(true),"units":units.size(),
		"resolution":"%d×%d" % [size.x,size.y],"vsync":DisplayServer.window_get_vsync_mode()!=DisplayServer.VSYNC_DISABLED,
		"gpu":RenderingServer.get_video_adapter_name(),"valid":valid,"phases":bench_results,
	}
	var json := JSON.stringify(data,"  ")
	print("DOMINION benchmark ",JSON.stringify(data))
	DirAccess.make_dir_recursive_absolute("res://build")
	var out := FileAccess.open("res://build/bench-%s-%d.json" % [RenderingServer.get_current_rendering_method(),units.size()],FileAccess.WRITE)
	out.store_string(json)
	out.close()
	status.text = "Benchmark done: %s" % ["  |  ".join(PackedStringArray(bench_results.map(func(r): return "%s %.0f FPS p95 %.1f ms" % [r.phase,r.fps,r.p95])))]
	if "--quit-after-bench" in OS.get_cmdline_user_args():
		get_tree().quit()
