extends Node3D
## DOMINION world, native renderer.
## Loads a map exported by the browser game (js/map-export.js, ?export=...) so
## both engines show the same island: terrain, trees, buildings and units.
## Forward+ provides the sea's refraction/depth colour, SSAO, fog and soft
## shadows. Command-line (after "--"):
##   --bench=N [--no-vsync] [--quit-after-bench]   same phases as the browser
##   --capture-views                               renders build/view-*.png
##   --motion-test                                 acceleration, pivot turns, suspension
##   --battle / --capture-battle                   skirmish demo (key B in game)
##   --nav-test                                    checks routes around buildings and water
##   --economy-test / --capture-economy            build, train and collect in fast time
##   --difficulty=easy|normal|hard  --ai-speed=N    AI opponents (browser difficulty table)
##   --ai-test / --capture-ai                      AI builds, trains, declares war and attacks
##   --logistics-test / --capture-logistics        supply, damage and repair of roads and rails
##   --air-sea-test / --capture-air-sea            ships stay at sea, aircraft fly, both fight
##   --save-test                                   save, change everything, load, compare

const MAP_PATH := "res://data/map-seed1.json"
const SOLDIER_HEIGHT := 2.35       # the browser's readable RTS scale
const SOLDIER_SPEED := 5.2         # metres per second while running
const RUN_CLIP_SPEED := 4.6        # speed the run clip was authored for (no foot sliding)
const REAL_RUN_CLIP_SPEED := 6.4   # the same for the realistic soldier's run, at game scale
# Weapons carried by the realistic soldier: length in centimetres (skeleton units).
const WEAPON_LENGTH := {"AK": 88.0, "Sniper_2": 118.0, "RocketLauncher": 92.0, "SMG": 62.0}
const TANK_SPEED := 4.2
const BUILDING_MODELS := {
	"hq": "res://assets/downtown/Building_Medium_2_001.gltf",
	"barracks": "res://assets/building-d.glb",
	"tankFactory": "res://assets/building-h.glb",
	"warehouse": "res://assets/building-f.glb",
	"farm": "res://assets/BigBarn.glb",
	"cottage": "res://assets/House_A.glb",
	"housing": "res://assets/building-e.glb",
	"residential": "res://assets/House_D.glb",
	"foodDepot": "res://assets/SiloHouse.glb",
	"workerHouse": "res://assets/House_B.glb",
	"villageCenter": "res://assets/House_C.glb",
	"school": "res://assets/building-b.glb",
	"library": "res://assets/House_D.glb",
	"university": "res://assets/building-c.glb",
	"hospital": "res://assets/building-g.glb",
	"cityHall": "res://assets/downtown/Building_Medium_2_001.gltf",
	"cityCenter": "res://assets/downtown/Building_Medium_2_001.gltf",
	"bank": "res://assets/building-e.glb",
	"courthouse": "res://assets/building-c.glb",
	"policeStation": "res://assets/building-d.glb",
	"tvStation": "res://assets/building-b.glb",
	"techPark": "res://assets/building-g.glb",
	"chipFab": "res://assets/building-h.glb",
	"oilRefinery": "res://assets/building-f.glb",
	"nuclearReactor": "res://assets/building-h.glb",
	"powerPlant": "res://assets/building-f.glb",
}
const BUILDING_SIZE := {"hq": 10.0, "barracks": 9.0, "tankFactory": 9.5, "warehouse": 9.5, "farm": 7.5, "cottage": 5.0, "extractor": 6.0}
# A district fills its hex; only its central building blocks movement.
const DISTRICT_NAV_SIZE := 6.0
const INFANTRY := ["soldier", "sniper", "commando", "rocketSoldier", "worker"]
const VEHICLES := ["tank", "apc", "artillery", "aaVehicle", "mlrs", "samLauncher"]
const NAVAL := ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
const AIR := ["helicopter", "gunship", "jet", "bomber", "drone"]
const FIXED_WING := ["jet", "bomber", "drone"]
const AirOperations := preload("res://scripts/air_operations.gd")
const ALTITUDE := {"helicopter": 14.0, "gunship": 13.0, "jet": 26.0, "bomber": 30.0, "drone": 18.0}
const SHIP_LENGTH := {"gunboat": 7.5, "corvette": 10.5, "destroyer": 15.0, "submarine": 11.0, "nuclearSub": 14.0}
const DEEP := -1.2   # water at least this deep (below sea level) carries a ship

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
var realistic_scene: PackedScene   # the textured Mixamo soldier; null falls back to the stylised one
var gun_meshes := {}               # weapon name -> Mesh taken from the stylised kit
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
var effects: Node3D
var audio: Node3D
var coast_focus := Vector3.INF
var coast_point := Vector3.ZERO
var unit_defs := {}
var shake_strength := 0.0
var battle_started := false
var building_spots: Array[Vector3] = []  # x, footprint, z
var buildings: Array[Dictionary] = []
var deposits: Array[Dictionary] = []
var building_defs := {}
var economy: Node
var hud: CanvasLayer
var worker_scene: PackedScene
var placing := ""
var ghost: Node3D
var ghost_ok := ""
var selected_building = null
var selection_marker: MeshInstance3D
var nav_region: NavigationRegion3D
var nav_heights := PackedVector3Array()
var nav_open := PackedByteArray()
var nav_n := 0
var site_timer := 0.0
var ai: Node
var diplomacy: Node
var game_over := ""
var craft: RefCounted
var armor: RefCounted     # armor.gd: ground vehicles built from code
var saves: Node
var menu: CanvasLayer
var info_layer: CanvasLayer
var match_difficulty := "easy"
var match_speed := 1.0
# A normal launch (no test or benchmark flags) starts at the main menu.
var interactive := false
var damage_profile := {}
var infantry_keys := []
var armor_keys := []
var logistics: Node3D
var districts: RefCounted
var district_hex := {}    # Vector2i -> building entity that owns the hex
var transport_kind := ""
var transport_start = null
var transport_route := []
var transport_hover := Vector2i(1 << 20, 0)
var nav_ready := false
var market: Node          # market.gd: world market and trade routes
var espionage: Node       # espionage.gd: agents and covert operations
var territory: Node3D     # territory.gd: gradual control of 40 m cells
var passage: Node         # passage.gd: who may cross whose land, and border incidents
var occupation: Node3D    # occupation.gd: operational zones for taking ground
var missiles: Node3D      # missiles.gd: silo production, launches, impacts
var research: Node        # research.gd: discoveries in stages, tracks, eras
var portraits: Node       # portraits.gd: pictures of every unit and building for the interface
var health_overlay: Control  # hud.gd's health bars, for the feature probe
# Ground units are bucketed into 8 m cells once per frame; keeping clear of
# each other and looking for targets then reads a handful of buckets instead
# of the whole army, which is what made large battles crawl.
const GRID := 8.0
var grid := {}
var air_sea: Array = []   # living ships and aircraft (not in the ground grid)
var tree_parts := {}       # Vector2(x, z) of a tree -> [[MultiMesh, instance], ...] (site_clearing.gd fells them)
var site_answers: Array = []  # the answers of the latest site-clearing letter (tests)
var lod_turn := 0
# `-- --no-perf` puts the work back the way it was before the performance
# pass: no neighbour buckets, no distance detail, shadows to the horizon. It
# is only there so the two can be measured against each other.
var perf_opts := true
var game_time := 0.0      # match seconds (EMP and other timed effects)
var shots_fired := 0      # every weapon discharge (the battle test watches it)
var sim_tick := 0         # simulation steps taken (staggers per-unit work; tests step by hand)
var missile_aim := ""     # missile type waiting for a target click
var cam_lift := 0.0       # raises the camera's look-at point above the ground (captures)
var edge_scroll := true   # pan when the mouse touches the screen edge (Settings)
var middle_drag := false  # the middle mouse button drags the map
var order_mode := ""
const MatchSetup := preload("res://scripts/match_setup.gd")
var match_config: Dictionary = MatchSetup.DEFAULT.duplicate()
var engagement: RefCounted
var naval_navigation: RefCounted
const Repairs := preload("res://scripts/repairs.gd")
const Motion := preload("res://scripts/motion.gd")
const Tactics := preload("res://scripts/tactics.gd")
const SiteClearing := preload("res://scripts/site_clearing.gd")
const Picking := preload("res://scripts/picking.gd")
const NAV_STEP := 4.0
var fps_frames := 0

func _ready() -> void:
	interactive = true
	for a in OS.get_cmdline_user_args():
		if not (a.begins_with("--quality") or a.begins_with("--difficulty") or a == "--no-vsync"):
			interactive = false
	map = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	match_config = MatchSetup.normalize(get_tree().get_meta("match_config",MatchSetup.DEFAULT))
	if "--campaign-test" in OS.get_cmdline_user_args():
		match_config = {"map":"mirrored","players":2,"nation":2,"style":"sandbox"}
	MatchSetup.apply(map,match_config)
	engagement = preload("res://scripts/engagement.gd").new()
	engagement.world = self
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
	unit_defs = map.get("unitDefs", {})
	var combat_cfg: Dictionary = map.get("combat", {})
	damage_profile = combat_cfg.get("damageProfile", {})
	infantry_keys = combat_cfg.get("infantry", INFANTRY)
	armor_keys = combat_cfg.get("armor", ["tank", "artillery"])
	craft = preload("res://scripts/craft.gd").new()
	building_defs = map.get("buildingDefs", {})
	soldier_scene = load("res://assets/CharacterSoldier.glb")
	if ResourceLoader.exists("res://assets/Soldier.glb") and not "--toon-infantry" in OS.get_cmdline_user_args():
		realistic_scene = load("res://assets/Soldier.glb")
	worker_scene = load("res://assets/Worker.glb")
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
	preload("res://scripts/ui_theme.gd").install()  # the look of every panel, button and menu
	effects = preload("res://scripts/effects.gd").new()
	add_child(effects)
	effects.shake.connect(_on_shake)
	effects.world_ref = self
	effects.debris.world = self
	audio = preload("res://scripts/audio.gd").new()
	add_child(audio)
	effects.audio = audio
	build_environment()
	apply_quality()
	build_terrain()
	build_sea()
	build_trees()
	if quality != "low":
		build_grass()
	logistics = preload("res://scripts/logistics.gd").new()
	add_child(logistics)
	logistics.setup(self, map.logistics)
	districts = preload("res://scripts/districts.gd").new()
	districts.setup(self)
	craft.setup(self)
	if not "--stylised-vehicles" in OS.get_cmdline_user_args():
		armor = preload("res://scripts/armor.gd").new()
		armor.setup(self)
	build_deposits()
	for b in map.buildings:
		place_building(b.key, Vector3(b.x, 0, b.z), int(b.owner), true)
	refresh_streets()
	await build_navigation()
	for u in map.units:
		if u.key in INFANTRY or u.key in VEHICLES or u.key in NAVAL or u.key in AIR:
			spawn_unit(u.key, Vector3(u.x, 0, u.z), int(u.owner))
	camera = Camera3D.new()
	camera.fov = 48
	camera.near = 1
	camera.far = 2600
	add_child(camera)
	cam_focus = start + Vector3(0, 0, 1)
	make_hud()
	portraits = preload("res://scripts/portraits.gd").new()
	add_child(portraits)
	portraits.setup(self)
	economy = preload("res://scripts/economy.gd").new()
	add_child(economy)
	economy.setup(self, map.economy)
	for u in units:
		if u.owner == 0 and u.key != "worker":
			economy.garrison += int(unit_defs.get(u.key, {}).get("pop", 1))
	economy.recalculate()
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(self, economy)
	saves = preload("res://scripts/save.gd").new()
	add_child(saves)
	saves.setup(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench"):
			bench_units = 1  # set properly below; any benchmark runs without AI
	var difficulty := "easy"
	var ai_speed := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty="):
			difficulty = arg.get_slice("=", 1)
		if arg.begins_with("--ai-speed="):
			ai_speed = float(arg.get_slice("=", 1))
	if "--ai-test" in OS.get_cmdline_user_args() or "--capture-ai" in OS.get_cmdline_user_args():
		difficulty = "hard"
		ai_speed = 12.0
	if "--soak-test" in OS.get_cmdline_user_args():
		difficulty = "hard"
		ai_speed = 3.0
	ai = preload("res://scripts/ai.gd").new()
	add_child(ai)
	diplomacy = preload("res://scripts/diplomacy.gd").new()
	add_child(diplomacy)
	diplomacy.setup(self, map.nations.size(), float(map.ai.difficulty.get(difficulty, map.ai.difficulty.easy).aggression), ai_speed)
	match_difficulty = difficulty
	match_speed = ai_speed
	market = preload("res://scripts/market.gd").new()
	add_child(market)
	market.setup(self, map.trade)
	espionage = preload("res://scripts/espionage.gd").new()
	add_child(espionage)
	espionage.setup(self, map.espionage)
	missiles = preload("res://scripts/missiles.gd").new()
	add_child(missiles)
	missiles.setup(self, map.missiles)
	territory = preload("res://scripts/territory.gd").new()
	add_child(territory)
	territory.setup(self, map.territory)
	research = preload("res://scripts/research.gd").new()
	add_child(research)
	research.setup(self, map.research)
	passage = preload("res://scripts/passage.gd").new()
	add_child(passage)
	passage.setup(self)
	occupation = preload("res://scripts/occupation.gd").new()
	add_child(occupation)
	occupation.setup(self)
	if not interactive and bench_units == 0 and not ("--capture-views" in OS.get_cmdline_user_args() or "--capture-menu" in OS.get_cmdline_user_args() or "--menu-test" in OS.get_cmdline_user_args() or "--capture-battle" in OS.get_cmdline_user_args() or "--economy-test" in OS.get_cmdline_user_args() or "--capture-economy" in OS.get_cmdline_user_args() or "--nav-test" in OS.get_cmdline_user_args() or "--logistics-test" in OS.get_cmdline_user_args() or "--capture-logistics" in OS.get_cmdline_user_args()):
		ai.setup(self, map.ai, difficulty, ai_speed)
	menu = preload("res://scripts/menu.gd").new()
	add_child(menu)
	selection_marker = MeshInstance3D.new()
	var marker_mesh := TorusMesh.new()
	marker_mesh.rings = 48
	marker_mesh.ring_segments = 4
	selection_marker.mesh = marker_mesh
	var marker_mat := StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Color("9ff29b")
	selection_marker.material_override = marker_mat
	selection_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection_marker.visible = false
	add_child(selection_marker)

	var args := OS.get_cmdline_user_args()
	if get_tree().has_meta("pending_load"):
		var data: Dictionary = get_tree().get_meta("pending_load")
		get_tree().remove_meta("pending_load")
		start_match(data.get("difficulty","easy"))
		saves.restore(data)
		menu.setup(self)
		menu.close()
		return
	if get_tree().has_meta("start_difficulty"):
		var chosen: String = get_tree().get_meta("start_difficulty")
		get_tree().remove_meta("start_difficulty")
		start_match(chosen)
		menu.setup(self)
		menu.close()
		return
	for arg in args:
		if arg.begins_with("--bench"):
			bench_units = clampi(int(arg.get_slice("=", 1)) if "=" in arg else 64, 1, 240)
		if arg == "--no-vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	profiling = "--profile" in args
	perf_opts = not "--no-perf" in args
	if not perf_opts:
		sun.directional_shadow_max_distance = 320 if quality == "high" else (230 if quality == "balanced" else 150)
	if bench_units > 0:
		start_benchmark()
	elif "--capture-views" in args:
		await capture_views()
	elif "--capture-battle" in args:
		await capture_battle()
	elif "--battle" in args:
		start_battle()
	elif "--nav-test" in args:
		nav_test()
	elif "--economy-test" in args:
		await economy_test(false)
	elif "--ai-test" in args:
		await ai_test(false)
	elif interactive:
		cam_focus = start
		cam_dist = 230.0
		cam_dist_target = 230.0
		cam_pitch = 0.42
		update_camera(0.0)
		menu.setup(self)
		menu.open_main()
	elif "--menu-test" in args:
		menu.setup(self)
		await menu_test()
	elif "--capture-menu" in args:
		menu.setup(self)
		await capture_menu()
	elif "--save-test" in args:
		await save_test()
	elif "--air-sea-test" in args or "--capture-air-sea" in args:
		await air_sea_test("--capture-air-sea" in args)
	elif "--research-test" in args or "--capture-research" in args:
		await research_test("--capture-research" in args)
	elif "--ui-test" in args:
		await ui_test()
	elif "--soak-test" in args:
		await soak_test(12.0)
	elif "--capture-screens" in args:
		await capture_screens()
	elif "--capture-tactics" in args:
		await preload("res://scripts/battle_regression.gd").capture(self)
	elif "--capture-deposits" in args:
		await preload("res://scripts/deposit_art.gd").capture(self)
	elif "--capture-city" in args:
		await preload("res://scripts/architecture.gd").capture(self)
	elif "--land-test" in args:
		await preload("res://scripts/land_regression.gd").run(self)
	elif "--sea-test" in args:
		await preload("res://scripts/sea_regression.gd").run(self)
	elif "--pick-test" in args:
		await preload("res://scripts/picking.gd").run(self)
	elif "--site-test" in args:
		await preload("res://scripts/site_clearing.gd").run(self)
	elif "--border-test" in args:
		await preload("res://scripts/border_regression.gd").run(self)
	elif "--convoy-test" in args:
		await preload("res://scripts/battle_regression.gd").convoy(self)
	elif "--battle-test" in args:
		await preload("res://scripts/battle_regression.gd").run(self)
	elif "--motion-test" in args:
		await preload("res://scripts/motion_regression.gd").run(self)
	elif "--combat-regression" in args:
		await preload("res://scripts/combat_regression.gd").run(self)
	elif "--polish-test" in args or "--campaign-test" in args or "--capture-polish" in args:
		await preload("res://scripts/polish_regression.gd").run(self,"--campaign-test" in args)
	elif battle_bench_size(args) > 0:
		await battle_bench(battle_bench_size(args))
	elif "--combat-test" in args or "--capture-combat" in args:
		await combat_test("--capture-combat" in args)
	elif "--capture-ui" in args:
		await capture_ui()
	elif "--camera-test" in args:
		await camera_test()
	elif "--capture-craft" in args:
		await capture_craft()
	elif "--capture-vehicles" in args:
		await capture_vehicles()
	elif "--capture-infantry" in args:
		await capture_infantry()
	elif "--systems-test" in args or "--capture-systems" in args:
		await systems_test("--capture-systems" in args)
	elif "--diplomacy-test" in args or "--capture-diplomacy" in args:
		await diplomacy_test("--capture-diplomacy" in args)
	elif "--logistics-test" in args:
		await logistics_test(false)
	elif "--capture-logistics" in args:
		await logistics_test(true)
	elif "--capture-ai" in args:
		await ai_test(true)
	elif "--capture-economy" in args:
		await economy_test(true)
	elif "--feature-probe" in args:
		for arg in args:
			if arg.begins_with("--probe-units="):
				bench_units = int(arg.get_slice("=", 1))
				start_benchmark()
				bench_phase = -1  # the drill army is spawned, but no benchmark runs
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
			sun.directional_shadow_max_distance = 220
			sun.directional_shadow_fade_start = 0.85
			viewport.msaa_3d = Viewport.MSAA_2X
		"balanced":
			env.ssao_enabled = false
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 140
			sun.directional_shadow_fade_start = 0.8
			# Integrated GPUs are fill-rate bound: render 3D at 77% and upscale with FSR.
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			viewport.scaling_3d_scale = 0.77
		_:
			env.ssao_enabled = false
			env.glow_enabled = false
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 95
			sun.directional_shadow_fade_start = 0.75
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
	# AgX keeps bright greens and skies from clipping to neon, like a film camera.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.tonemap_white = 12.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("b3c7d3")
	env.fog_density = 0.0005
	env.fog_aerial_perspective = 0.45  # distant land takes on the sky's blue: depth
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.06
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
				var spot := Vector2(t.x, t.z)
				if not tree_parts.has(spot):
					tree_parts[spot] = []
				tree_parts[spot].append([mm, i])
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
		foliage.set_shader_parameter("tint", Color(0.42, 0.62, 0.3) if leafy else material.albedo_color)
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

func footprint_of(key: String) -> float:
	return BUILDING_SIZE.get(key, float(building_defs.get(key, {}).get("size", 6)) * 1.9)

# The building's model, centred and scaled to its footprint (also used for the
# placement preview).
func building_model(key: String, x: float, z: float) -> Node3D:
	if key == "extractor":
		return extractor_model()
	if key in ["missileSilo", "ammoDepot"]:
		return bunker_model(key)
	var path: String = BUILDING_MODELS.get(key, "res://assets/building-a.glb")
	if key == "cottage":
		path = ["res://assets/House_A.glb", "res://assets/House_B.glb", "res://assets/House_C.glb"][absi(int(x * 7.0 + z * 3.0)) % 3]
	var model: Node3D = load(path).instantiate()
	var bounds := model_bounds(model)
	var footprint := footprint_of(key)
	var factor := minf(footprint / maxf(maxf(bounds.size.x, bounds.size.z), 0.01), footprint * 1.1 / maxf(bounds.size.y, 0.01))
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-bounds.get_center().x * factor, -bounds.position.y * factor, -bounds.get_center().z * factor)
	return model

# A pole in the corner of the plot flies the owner's colours.
func add_flag(root: Node3D, footprint: float, owner: int) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 7.0
	pole.mesh = pole_mesh
	pole.material_override = cached_material("flagpole", func(): return matte(Color("c8c8c0"), 0.4, 0.7))
	var corner := Vector3(footprint * 0.48, 3.5, footprint * 0.48) if footprint < 8.0 else Vector3(cos(deg_to_rad(330.0)) * 8.6, 3.5, sin(deg_to_rad(330.0)) * 8.6)
	pole.position = corner
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(1.8, 1.1, 0.05)
	flag.mesh = cloth
	var colour := Color(map.nations[owner].color) if owner < map.nations.size() else Color.WHITE
	flag.material_override = cached_material("flag:%d" % owner, func(): return matte(colour, 0.8))
	flag.position = corner + Vector3(0.95, 2.8, 0)
	root.add_child(flag)

# Low reinforced-concrete blocks: a launch control bunker with a blast wall
# and a radar mast, or a row of earth-banked magazines.
func bunker_model(key: String) -> Node3D:
	var root := Node3D.new()
	var concrete := cached_material("bunker-concrete", func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/architecture/concrete_diffuse.jpg")
		m.normal_enabled = true
		m.normal_texture = load("res://assets/architecture/concrete_normal.jpg")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.25
		m.albedo_color = Color("9a9890")
		return m)
	var steel := cached_material("bunker-steel", func(): return matte(Color("3b3f40"), 0.5, 0.6))
	var earth := cached_material("bunker-earth", func(): return matte(Color("56613a"), 0.95))
	var parts: Array
	if key == "missileSilo":
		parts = [
			[Vector3(7.0, 2.6, 5.0), Vector3(0, 1.3, 0), concrete],
			[Vector3(7.6, 0.4, 5.6), Vector3(0, 2.8, 0), concrete],
			[Vector3(1.6, 1.8, 0.2), Vector3(-1.6, 0.9, 2.55), steel],
			[Vector3(9.0, 3.2, 0.9), Vector3(0, 1.6, -3.6), concrete],
			[Vector3(0.25, 7.0, 0.25), Vector3(2.8, 6.0, 1.6), steel],
			[Vector3(1.8, 0.1, 0.1), Vector3(2.8, 8.0, 1.6), steel],
			[Vector3(1.2, 0.8, 1.2), Vector3(-2.4, 3.4, -1.0), steel],
		]
	else:
		parts = []
		for i in range(3):
			var x := (i - 1) * 3.2
			parts.append([Vector3(2.6, 2.2, 6.0), Vector3(x, 1.1, 0), earth])
			parts.append([Vector3(2.0, 1.6, 0.2), Vector3(x, 0.8, 3.05), concrete])
			parts.append([Vector3(1.0, 1.2, 0.12), Vector3(x, 0.6, 3.16), steel])
	for p in parts:
		var mesh := BoxMesh.new()
		mesh.size = p[0]
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.position = p[1]
		part.material_override = p[2]
		root.add_child(part)
	return root

# A pumpjack-style extraction rig in dark steel.
func extractor_model() -> Node3D:
	var rig := Node3D.new()
	var steel := matte(Color("3b3f40"), 0.5, 0.6)
	var paint := matte(Color("8a6a2a"), 0.7)
	var parts := [
		[Vector3(4.2, 0.6, 3.0), Vector3(0, 0.3, 0), steel],
		[Vector3(0.5, 4.0, 0.5), Vector3(-0.9, 2.3, 0), steel],
		[Vector3(0.5, 4.0, 0.5), Vector3(0.9, 2.3, 0), steel],
		[Vector3(5.2, 0.5, 0.6), Vector3(0.4, 4.4, 0), paint],
		[Vector3(0.9, 1.8, 0.9), Vector3(-2.2, 3.6, 0), paint],
		[Vector3(1.2, 1.4, 1.2), Vector3(2.4, 1.1, 0), steel],
	]
	for p in parts:
		var mesh := BoxMesh.new()
		mesh.size = p[0]
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.position = p[1]
		part.material_override = p[2]
		rig.add_child(part)
	return rig

## Creates a building entity. Unbuilt buildings are construction sites.
func snap_to_hex(at: Vector3) -> Vector3:
	var c: Vector3 = logistics.hex_center(logistics.world_hex(at))
	return c

func is_district(key: String) -> bool:
	return key != "extractor"

func place_building(key: String, at: Vector3, owner: int, built: bool) -> Dictionary:
	if is_district(key):
		return place_district(key, at, owner, built)
	var b := {"key": key, "x": at.x, "z": at.z}
	var model := building_model(key, at.x, at.z)
	var footprint := footprint_of(key)
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
	building_spots.append(Vector3(b.x, footprint, b.z))
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
	SiteClearing.fell(self, SiteClearing.conflicts(self, key, at).trees)  # no tree grows through a building
	return register_building(key, owner, built, root, model, footprint, at)

## Civilization-style: the building owns the whole hex, with a district tile,
## props and streets (districts.gd).
func place_district(key: String, at: Vector3, owner: int, built: bool) -> Dictionary:
	var centre := snap_to_hex(at)
	var city := 0
	for hex in district_hex:
		if not district_hex[hex].dead and district_hex[hex].owner == owner:
			city += 1
	var parts: Dictionary = districts.build(key, centre, fmod(absf(centre.x * 0.37 + centre.z * 0.61), 7.0), owner, city)
	var root := Node3D.new()
	root.position = Vector3(centre.x, parts.floor_y, centre.z)
	add_child(root)
	parts.pad.position.y = centre.y - parts.floor_y
	root.add_child(parts.pad)
	root.add_child(parts.container)
	building_spots.append(Vector3(centre.x, DISTRICT_NAV_SIZE, centre.z))
	var footprint: float = logistics.radius * 0.85 if districts.style_of(key) == 1 and not key in ["housing", "apartments"] else footprint_of(key)
	SiteClearing.fell(self, SiteClearing.conflicts(self, key, centre).trees)  # the whole hex is cleared
	var entity := register_building(key, owner, built, root, parts.container, footprint, centre)
	entity.pad = parts.pad
	entity.hex = logistics.world_hex(centre)
	district_hex[entity.hex] = entity
	return entity

func register_building(key: String, owner: int, built: bool, root: Node3D, model: Node3D, footprint: float, at: Vector3) -> Dictionary:
	var def: Dictionary = building_defs.get(key, {"name": key, "hp": 500, "buildTime": 10, "trains": [], "provides": {}, "desc": "", "cost": {}})
	var entity := {
		"key": key, "owner": owner, "def": def, "root": root, "model": model, "footprint": footprint,
		"built": built, "progress": 1.0 if built else 0.0, "hp": float(def.hp), "max_hp": float(def.hp),
		"queue": [], "queue_prog": 0.0, "dead": false, "builders": 0, "deposit": null,
		# Target fields shared with units, so combat treats both alike.
		"node": root, "vehicle": true, "is_building": true, "dmg": 0.0, "enemy": null, "target": null, "attack_move": false,
	}
	add_flag(root, footprint, owner)
	if def.get("onDeposit", false):
		var dep = deposit_near(at, 6.0)
		if dep != null:
			dep.extractor = entity
			entity.deposit = dep
	if not built:
		model.scale.y *= 0.06
		entity.full_scale_y = model.scale.y / 0.06
	buildings.append(entity)
	return entity

## Streets in each district run toward neighbouring districts of the same
## owner and toward every road or railway that enters its hex. Roads are not
## drawn inside district hexes (logistics.gd), so the two join up.
func refresh_streets() -> void:
	var links := {}
	for e in logistics.edges.values():
		if e.hp > 0.0:
			links[[e.a, e.b]] = true
			links[[e.b, e.a]] = true
	for hex in district_hex:
		var b: Dictionary = district_hex[hex]
		if b.dead:
			continue
		var centre: Vector3 = logistics.hex_center(hex)
		var mask := 0
		for d in logistics.DIRECTIONS:
			var other: Vector2i = hex + d
			var neighbour = district_hex.get(other)
			var joined: bool = links.has([hex, other]) or (neighbour != null and not neighbour.dead and neighbour.owner == b.owner)
			if not joined:
				continue
			var towards: Vector3 = logistics.hex_center(other) - centre
			var k := posmod(int(roundf(rad_to_deg(atan2(towards.z, towards.x)) / 60.0)), 6)
			mask |= 1 << k
		districts.set_streets(b.pad, mask)
	logistics.rebuild_mesh()

# ---------------------------------------------------------------- deposits

# Resource deposits from the map: a cluster of rocks tinted by type, oil as a
# dark glossy seep. Sea deposits need ships and are not shown yet.
func build_deposits() -> void:
	# Every resource, on land and at sea, as a readable site (deposit_art.gd).
	var types: Dictionary = map.get("depositTypes", {})
	var art := preload("res://scripts/deposit_art.gd").new(self)
	for d in map.deposits:
		var def: Dictionary = types.get(d.type, {})
		if def.is_empty():
			continue
		var water: bool = def.get("water", false)
		var at := Vector3(d.x, float(map.seaLevel) if water else height_at(d.x, d.z), d.z)
		var node := art.build(d.type, at, fmod(d.x * 3.7 + d.z, TAU))
		add_child(node)
		deposits.append({"type": d.type, "def": def, "pos": node.position, "node": node, "extractor": null, "water": water})

func deposit_near(at: Vector3, radius: float):
	var best = null
	var best_d := radius
	for d in deposits:
		var gap := Vector2(d.pos.x - at.x, d.pos.z - at.z).length()
		if gap < best_d:
			best_d = gap
			best = d
	return best

# ---------------------------------------------------------------- units

func spawn_unit(key: String, at: Vector3, owner: int) -> Dictionary:
	if key in NAVAL or key in AIR:
		return spawn_craft(key, at, owner)
	var vehicle := key in VEHICLES
	var realistic := not vehicle and key != "worker" and realistic_scene != null
	var node := Node3D.new()
	var built: Dictionary = armor.build(key, owner) if vehicle and armor != null else {}
	var model: Node3D
	if not built.is_empty():
		model = built.root  # already in metres, facing +Z, standing on the ground
	else:
		model = (tank_scene if vehicle else (worker_scene if key == "worker" else (realistic_scene if realistic else soldier_scene))).instantiate()
	node.add_child(model)
	if built.is_empty():
		if vehicle:
			model.rotation.y = PI * 0.5  # the Quaternius tank's gun points along -X; units face +Z
		elif realistic:
			model.rotation.y = PI  # the Mixamo soldier faces -Z
		var bounds := model_bounds(model)
		var factor: float = (6.0 / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)) if vehicle else (SOLDIER_HEIGHT / maxf(bounds.size.y, 0.01))
		model.scale = Vector3.ONE * factor
		model.position.y = -bounds.position.y * factor
	add_child(node)
	var turret: Node3D = null
	var dust: GPUParticles3D = null
	if not built.is_empty():
		turret = built.turret
		dust = make_dust()
		node.add_child(dust)
	elif vehicle:
		turret = dress_vehicle(model, owner)
		dust = make_dust()
		node.add_child(dust)
	elif key == "worker":
		dress_worker(model)
	elif realistic:
		dress_realistic(model, owner, {"sniper": "Sniper_2", "rocketSoldier": "RocketLauncher", "commando": "SMG"}.get(key, "AK"))
	else:
		dress_soldier(model, owner, {"sniper": "Sniper_2", "rocketSoldier": "RocketLauncher"}.get(key, "AK"))
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
		"model": model, "clip_speed": REAL_RUN_CLIP_SPEED if realistic else RUN_CLIP_SPEED,
		"axles": built.get("axles", []), "radar": built.get("radar"), "muzzle": built.get("muzzle", 4.2),
	}
	# Combat stats come from the browser's config.js via the map export.
	var def: Dictionary = unit_defs.get(key, {"hp": 100, "dmg": 10, "range": 13, "cooldown": 1.0, "aggro": 24})
	unit.merge({
		"key": key, "hp": float(def.hp), "max_hp": float(def.hp), "dmg": float(def.dmg),
		"range": float(def.range), "cooldown": float(def.cooldown), "aggro": float(def.get("aggro", def.range)),
		"reload": randf() * float(def.cooldown), "search": randf() * 0.35, "enemy": null,
		"attack_move": false, "dead": false, "dead_time": 0.0, "stance": "",
		"path": PackedVector3Array(), "path_goal": Vector3.INF, "repath": 0.0, "build_site": null,
		"engine": audio.add_engine(node) if vehicle else null,
	})
	if unit.player:
		# Looked up once: searching the clip list every frame was most of the CPU time.
		unit.run_clip = find_clip(unit.player, ["tank_forward"] if vehicle else ["run_gun", "run"])
		unit.idle_clip = "" if vehicle else find_clip(unit.player, ["idle_gun", "idle"])
		unit.shoot_clip = "" if vehicle else find_clip(unit.player, ["idle_shoot"])
		unit.death_clip = "" if vehicle else find_clip(unit.player, ["death"])
		unit.work_clip = find_clip(unit.player, ["interact"]) if key == "worker" else ""
		if unit.work_clip != "":
			unit.player.get_animation(unit.work_clip).loop_mode = Animation.LOOP_LINEAR
		if unit.shoot_clip != "":
			unit.player.get_animation(unit.shoot_clip).loop_mode = Animation.LOOP_LINEAR
		for clip in [unit.run_clip, unit.idle_clip]:
			if clip != "":
				unit.player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	place_on_ground(unit, at)
	if research:
		research.equip(unit)  # discoveries and rival tech set health, range and speed
	units.append(unit)
	animate(unit, false)
	return unit

## A model of `key` (unit, vehicle, ship, aircraft or building) for the
## interface's picture cards, in the player's colours, wrapped in a holder so
## its bounds are measured in the stage's space.
func display_model(key: String) -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = null
	if key in NAVAL or key in AIR:
		model = craft.build(key, 0).root
	elif key in VEHICLES:
		model = armor.build(key, 0).root if armor != null else tank_scene.instantiate()
	elif key == "worker" or key in INFANTRY:
		var realistic := key != "worker" and realistic_scene != null
		model = (realistic_scene if realistic else (worker_scene if key == "worker" else soldier_scene)).instantiate()
		var bounds := model_bounds(model)
		model.scale = Vector3.ONE * SOLDIER_HEIGHT / maxf(bounds.size.y, 0.01)
		if realistic:
			model.rotation.y = PI
			dress_realistic(model, 0, {"sniper": "Sniper_2", "rocketSoldier": "RocketLauncher", "commando": "SMG"}.get(key, "AK"))
		elif key == "worker":
			dress_worker(model)
		else:
			dress_soldier(model, 0)
		for player in model.find_children("*", "AnimationPlayer", true, false):
			var idle := find_clip(player, ["idle_gun", "idle"])
			if idle != "":
				player.play(idle)
				player.seek(0.4, true)
	elif building_defs.has(key):
		model = building_model(key, 0.0, 0.0)
		districts.tone(model, 0)  # the same weathered tones as in the city
	if model == null:
		return null
	holder.add_child(model)
	return holder

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
# Workers keep their hi-vis colours, just without the plastic shine.
func dress_worker(model: Node3D) -> void:
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh_instance.mesh.get_surface_count()):
			var source: Material = mesh_instance.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var key := "worker:%s" % source.resource_name
				mesh_instance.set_surface_override_material(i, cached_material(key, func():
					var m: StandardMaterial3D = source.duplicate()
					m.roughness = 0.85
					m.metallic = 0.0
					return m))

func dress_soldier(model: Node3D, owner: int, weapon_name := "AK") -> void:
	var u: Dictionary = UNIFORMS[owner % UNIFORMS.size()]
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var weapon: bool = mesh_instance.get_parent().name == "Index1_R"
		if weapon and mesh_instance.name != weapon_name:
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

# The realistic soldier: its photo-textured combat suit tinted toward the
# nation's field colour, and a weapon from the stylised kit in the right hand.
func dress_realistic(model: Node3D, owner: int, weapon_name: String) -> void:
	var u: Dictionary = UNIFORMS[owner % UNIFORMS.size()]
	var nation: Color = Color(map.nations[owner].color) if owner < map.nations.size() else Color.WHITE
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh_instance.mesh.get_surface_count()):
			var source: Material = mesh_instance.mesh.surface_get_material(i)
			if not (source is StandardMaterial3D):
				continue
			var visor: bool = source.resource_name.to_lower().contains("visor")
			var key := "real:%d:%s" % [owner, source.resource_name]
			mesh_instance.set_surface_override_material(i, cached_material(key, func():
				var m: StandardMaterial3D = source.duplicate()
				if visor:
					m.albedo_color = Color(0.12, 0.13, 0.12).lerp(nation, 0.25)
					m.roughness = 0.25
					m.metallic = 0.4
				else:
					# The nation's field colour over the texture's own light and shade.
					m.albedo_color = u.main * 2.3
					m.roughness = maxf(m.roughness, 0.78)
					m.metallic = 0.0
				return m))
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	# A shoulder patch in the flag's colour on each upper arm tells the sides apart.
	for side in ["Left", "Right"]:
		var arm := BoneAttachment3D.new()
		arm.bone_name = "mixamorig_%sArm" % side
		skeleton.add_child(arm)
		var patch := MeshInstance3D.new()
		var patch_mesh := BoxMesh.new()
		patch_mesh.size = Vector3(10.5, 7.0, 10.5)
		patch.mesh = patch_mesh
		patch.material_override = cached_material("patch:%d" % owner, func(): return matte(nation, 0.7))
		patch.position = Vector3(0, 11.0, 0)
		arm.add_child(patch)
	var slung := weapon_name == "RocketLauncher"
	var hand := BoneAttachment3D.new()
	hand.bone_name = "mixamorig_Spine2" if slung else "mixamorig_RightHand"
	skeleton.add_child(hand)
	var gun := MeshInstance3D.new()
	gun.mesh = gun_mesh(weapon_name)
	for i in range(gun.mesh.get_surface_count()):
		var source: Material = gun.mesh.surface_get_material(i)
		var name: String = source.resource_name if source else ""
		gun.set_surface_override_material(i, cached_material("gun:" + name, func(): return matte(Color("4a3526"), 0.8) if name.contains("Wood") else (matte(Color("5a2420"), 0.6) if name == "Red" else matte(Color("262829"), 0.42, 0.65))))
	# The kit's weapons lie along their longest axis; turn that onto the hand's
	# grip direction and size it in centimetres.
	var box := gun.mesh.get_aabb()
	var long_axis := 0 if box.size.x >= maxf(box.size.y, box.size.z) else (1 if box.size.y >= box.size.z else 2)
	var k: float = WEAPON_LENGTH.get(weapon_name, 90.0) / maxf(box.size[long_axis], 0.001)
	var align := Basis()
	if long_axis == 0:
		align = Basis(Vector3.UP, -PI * 0.5)
	elif long_axis == 1:
		align = Basis(Vector3.RIGHT, PI * 0.5)
	var grip: Basis = GUN_GRIP
	var offset: Vector3 = GUN_OFFSET + GUN_GRIP * Vector3(0, 0, WEAPON_LENGTH.get(weapon_name, 90.0) * 0.18)
	if slung:
		# Across the back, muzzle up over the right shoulder.
		grip = Basis(Vector3.BACK, -0.6) * Basis(Vector3.RIGHT, -PI * 0.5)
		offset = Vector3(0, 8.0, -17.0)
	var basis := grip * align.scaled(Vector3.ONE * k)
	gun.transform = Transform3D(basis, offset - basis * box.get_center())
	hand.add_child(gun)

# The grip in the hand bone's frame (bone Y runs along the fingers).
const GUN_GRIP := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const GUN_OFFSET := Vector3(0, 9.0, 3.0)

func gun_mesh(weapon_name: String) -> Mesh:
	if not gun_meshes.has(weapon_name):
		var kit: Node3D = soldier_scene.instantiate()
		for mesh_instance in kit.find_children("*", "MeshInstance3D", true, false):
			if mesh_instance.name == weapon_name:
				gun_meshes[weapon_name] = mesh_instance.mesh
		kit.free()
	return gun_meshes.get(weapon_name)

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

# Warships and aircraft share the unit record of ground units; movement and
# placement branch on "naval" and "fly".
func spawn_craft(key: String, at: Vector3, owner: int) -> Dictionary:
	var parts: Dictionary = craft.build(key, owner)
	var node: Node3D = parts.root
	add_child(node)
	var naval := key in NAVAL
	var length: float = SHIP_LENGTH.get(key, 8.0)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = length * 0.55 if naval else 3.0
	torus.outer_radius = torus.inner_radius + 0.12
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = cached_material("ring", func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("9ff29b")
		return m)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	node.add_child(ring)
	var wake: GPUParticles3D = null
	if naval:
		wake = craft.wake(length)
		node.add_child(wake)
	if parts.turret:
		parts.turret.set_meta("axis", Vector3.UP)
	var def: Dictionary = unit_defs.get(key, {"hp": 300, "dmg": 30, "range": 22, "cooldown": 2.0, "aggro": 30, "speed": 14})
	var unit := {
		"node": node, "ring": ring, "vehicle": true, "selected": false, "target": null, "player": null, "clip": "",
		"owner": owner, "speed": float(def.speed) * 0.45, "heading": 0.0, "moving": false,
		"turret": parts.turret, "turret_yaw": 0.0, "dust": wake, "phase": at.x * 0.37 + at.z * 0.21, "meshes": [],
		"naval": naval, "fly": key in AIR, "rotor": parts.rotor, "radar": parts.radar,
		"altitude": ALTITUDE.get(key, 0.0), "bank": 0.0, "length": length,
		"key": key, "hp": float(def.hp), "max_hp": float(def.hp), "dmg": float(def.dmg),
		"range": float(def.range), "cooldown": float(def.cooldown), "aggro": float(def.get("aggro", def.range)),
		"reload": randf() * float(def.cooldown), "search": randf() * 0.35, "enemy": null,
		"attack_move": false, "dead": false, "dead_time": 0.0, "stance": "",
		"path": PackedVector3Array(), "path_goal": Vector3.INF, "repath": 0.0, "build_site": null,
		"engine": audio.add_engine(node), "orbit": at,
	}
	if key in AIR:
		AirOperations.initialize(unit)
	place_on_ground(unit, at)
	if research:
		research.equip(unit)
	units.append(unit)
	return unit

func is_water(p: Vector3, depth := DEEP) -> bool:
	# Past the edge of the map there is only open sea (the terrain stops there;
	# height_at would repeat the edge's heights for ever and close the sea lanes).
	var half := float(map.mapSize) * 0.5
	if absf(p.x) > half or absf(p.z) > half:
		return true
	return height_at(p.x, p.z) < float(map.seaLevel) + depth

# Nearest point on open water to `from` (for ships leaving a shipyard).
func water_near(from: Vector3, reach := 90):
	for r in range(6, reach, 3):
		for i in range(16):
			var a := i * TAU / 16.0
			var p := from + Vector3(cos(a), 0, sin(a)) * r
			if is_water(p, DEEP * 1.5):
				return p
	return null

func place_on_ground(unit: Dictionary, at: Vector3) -> void:
	var node: Node3D = unit.node
	if unit.get("fly", false):
		# Aircraft hold their altitude over land or sea and bank into turns.
		var floor_y := maxf(height_at(at.x, at.z), float(map.seaLevel))
		var bob := sin(Time.get_ticks_msec() / 700.0 + unit.phase) * 0.35 if not (unit.key in FIXED_WING) else 0.0
		node.position = Vector3(at.x, floor_y + unit.altitude + bob, at.z)
		node.basis = Basis(Vector3.UP, unit.heading) * Basis(Vector3.BACK, unit.bank)
		return
	if unit.get("naval", false):
		# Ships ride the swell: a gentle heave, pitch and roll.
		var t := Time.get_ticks_msec() / 1000.0
		node.position = Vector3(at.x, float(map.seaLevel) + sin(t * 0.9 + unit.phase) * 0.12 - (0.9 if unit.key.ends_with("ub") or unit.key == "submarine" else 0.0), at.z)
		node.basis = Basis(Vector3.UP, unit.heading) * Basis(Vector3.RIGHT, sin(t * 0.7 + unit.phase) * 0.02) * Basis(Vector3.BACK, sin(t * 0.55 + unit.phase * 2.0) * 0.03)
		return
	node.position = Vector3(at.x, height_at(at.x, at.z), at.z)
	var heading := Basis(Vector3.UP, unit.heading)
	if unit.vehicle:
		# Vehicles pitch and roll with the ground under their tracks, on springs (motion.gd).
		# The ground's slope changes over metres, not millimetres: sample it again
		# only after the vehicle has moved half a metre.
		var probe: Vector3 = unit.get("ground_probe", Vector3.INF)
		if probe == Vector3.INF or Vector2(at.x - probe.x, at.z - probe.z).length_squared() > 0.25:
			unit.ground_probe = at
			unit.ground_normal = normal_at(at.x, at.z)
		node.basis = Motion.body_basis(unit, unit.ground_normal, unit.heading, get_physics_process_delta_time())
		if absf(node.position.y - float(unit.get("ground_told", -999.0))) > 0.04:
			unit.ground_told = node.position.y
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
	if unit.moving == moving and unit.clip != "":
		return
	unit.moving = moving
	if unit.dust:
		unit.dust.emitting = moving
	if not player:
		unit.clip = "static"  # vehicles built from code: wheels turn in _physics_process
		return
	var clip: String = unit.run_clip if moving else (unit.get("shoot_clip", "") if unit.get("enemy") != null and unit.get("shoot_clip", "") != "" else unit.idle_clip)
	if clip == "":
		player.pause()  # a parked tank's tracks stop
		unit.clip = "parked"
		return
	player.play(clip, 0.25)
	unit.clip = clip
	player.speed_scale = (maxf(unit.get("cur_speed", unit.speed), 0.8) / unit.get("clip_speed", RUN_CLIP_SPEED)) if moving else 1.0

func order_attack(selected: Array, enemy: Dictionary) -> void:
	for u in selected:
		if u.dead or u.owner == enemy.owner or effectiveness(u, enemy) <= 0.01 or u.dmg <= 0:
			continue
		# Establish hostility before splash filters run, including the first shell.
		if u.owner == 0 and enemy.owner > 0 and not hostile(u.owner, enemy.owner):
			ai.declare_war(enemy.owner, true)
		u.enemy = enemy
		u.forced = true  # an ordered target is not swapped for a nearer one
		u.ignore = {}
		u.erase("ground_attack")
		u.target = null
		u.attack_move = true
		u.path = PackedVector3Array()

func order_move(selected: Array, point: Vector3, attack := false) -> void:
	for u in selected:
		if u.has("ground_attack"):
			u.enemy = null
		u.erase("ground_attack")
		u.egress = null
		u.repath = 0.0
		u.attack_move = attack
		u.path = PackedVector3Array()
		u.build_site = null  # a new order takes a worker off its construction site
		u.forced = false
		u.best_rem = INF
		u.stall = 0.0
		u.stuck = 0
		u.holding = false
		if not attack:
			u.enemy = null  # a plain move order disengages
	# Ranks across the line of march (tactics.gd), marching at the pace of the
	# slowest so the body arrives together.
	var ground: Array = selected.filter(func(u): return not (u.get("fly", false) or u.get("naval", false)))
	var slots: Array = Tactics.formation(ground, point) if not ground.is_empty() else []
	var pace := INF
	for u in ground:
		pace = minf(pace, float(u.speed))
	for i in range(ground.size()):
		ground[i].target = slots[i]
		ground[i].pace = pace if ground.size() > 1 else INF
	var width := maxi(1, ceili(sqrt(selected.size())))
	var rows := ceili(float(selected.size()) / width)
	for i in range(selected.size()):
		if not (selected[i].get("fly", false) or selected[i].get("naval", false)):
			continue
		var spacing := 12.0 if selected[i].get("fly", false) else 14.0
		selected[i].target = point + Vector3((i % width - (width - 1) / 2.0) * spacing, 0, (floori(float(i) / width) - (rows - 1) / 2.0) * spacing)

func request_bombard(selected: Array, point: Vector3) -> void:
	var armed := selected.filter(func(u):return not u.dead and u.vehicle and u.dmg>0 and not u.key in ["samLauncher","aaVehicle","submarine","nuclearSub"])
	if armed.is_empty():
		hud.notice("Select artillery, a ground-attack aircraft or a vehicle with a ground weapon.")
		return
	engagement.authorize_area(point,6.0,func():order_bombard(armed,point))

func order_bombard(selected: Array, point: Vector3) -> void:
	for u in selected:
		if u.dead or not u.vehicle or u.dmg <= 0 or u.key in ["samLauncher", "aaVehicle", "submarine", "nuclearSub"]:
			continue
		if not is_instance_valid(u.get("bombard_marker")):
			u.bombard_marker = Node3D.new()
			add_child(u.bombard_marker)
		u.bombard_marker.position = point
		u.ground_attack = point
		u.enemy = {"node":u.bombard_marker,"root":u.bombard_marker,"dead":false,"owner":u.owner,"vehicle":true,"is_building":true,"footprint":1.0}
		u.target = null
		u.attack_move = true
		u.path = PackedVector3Array()

# ---------------------------------------------------------------- profiler
# `-- --profile` during a benchmark measures where each frame goes: every
# system reports the microseconds it spent, and the benchmark prints the
# average per frame. Off by default, so it costs nothing in a real game.
var profiling := false
var prof := {}
var prof_frames := 0

func clock() -> int:
	return Time.get_ticks_usec()

func spent(key: String, from: int) -> void:
	if profiling:
		prof[key] = float(prof.get(key, 0.0)) + float(Time.get_ticks_usec() - from)

func profile_report() -> String:
	if prof_frames == 0:
		return ""
	var rows := prof.keys()
	rows.sort_custom(func(a, b): return prof[a] > prof[b])
	var parts := PackedStringArray()
	for key in rows:
		parts.append("%s %.2f ms" % [key, prof[key] / prof_frames / 1000.0])
	return "per frame: " + ", ".join(parts)

## Buckets every living ground unit by its position.
func rebuild_grid() -> void:
	grid.clear()
	air_sea.clear()
	for u in units:
		if u.dead:
			continue
		if u.get("fly", false) or u.get("naval", false):
			air_sea.append(u)
			continue
		var p: Vector3 = u.node.position
		var key := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
		if grid.has(key):
			grid[key].append(u)
		else:
			grid[key] = [u]

## Every ground unit within `reach` metres of `at` (a few buckets wide).
func near_units(at: Vector3, reach: float) -> Array:
	var out := []
	var span := ceili(reach / GRID)
	var cx := floori(at.x / GRID)
	var cz := floori(at.z / GRID)
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var bucket = grid.get(Vector2i(cx + dx, cz + dz))
			if bucket != null:
				out.append_array(bucket)
	return out

## Distance work that does not have to happen every frame: a unit far from
## the camera stops animating and stops casting a shadow, and picks both up
## again as the camera comes near. Split over 12 frames so no frame pays for
## the whole army at once.
func update_detail_level() -> void:
	if units.is_empty() or camera == null or not perf_opts:
		return
	lod_turn = (lod_turn + 1) % 12
	var eye := camera.global_position
	var i := lod_turn
	while i < units.size():
		var u: Dictionary = units[i]
		i += 12
		if u.dead:
			continue
		var d: float = eye.distance_to(u.node.position)
		# Figures the camera cannot make out hold their pose: the animation
		# player is the single most expensive thing per unit.
		var animating: bool = d < 110.0 or not perf_opts
		if u.player != null and u.get("animating", true) != animating:
			u.animating = animating
			u.player.active = animating
		var shadow_near: bool = d < 75.0 or not perf_opts
		if u.get("shadowing", true) != shadow_near:
			u.shadowing = shadow_near
			var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow_near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for mesh in u.node.find_children("*", "MeshInstance3D", true, false):
				mesh.cast_shadow = mode

func _physics_process(delta: float) -> void:
	sim_tick += 1
	var now := Time.get_ticks_msec() / 1000.0
	var t0 := clock()
	rebuild_grid()
	update_detail_level()
	game_time += delta
	if engagement != null:
		engagement.update()
	if economy != null:
		Repairs.update(self,delta)
	if economy:
		update_construction(delta)
		update_training(delta)
	spent("build+train", t0)
	var t_units := clock()
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i]
		if unit.dead:
			var t_dead := clock()
			update_dead(unit, delta, i)
			spent("  wrecks and bodies", t_dead)
			continue
		var t_fight := clock()
		update_combat(unit, delta)
		spent("  targeting and firing", t_fight)
		var t_parts := clock()
		if unit.get("rotor") != null:
			unit.rotor.rotate_y(delta * 28.0)
		if unit.get("radar") != null:
			unit.radar.rotate_y(delta * 1.6)
		if unit.moving:
			for a in unit.get("axles", []):
				a.node.rotate_x(unit.get("cur_speed", unit.speed) * delta / a.radius)  # wheels roll with the ground
		spent("  wheels and rotors", t_parts)
		if unit.engine:
			var t_audio := clock()
			audio.engine_update(unit.engine, unit.moving, delta)
			spent("  engine sound", t_audio)
		if unit.turret:
			var aim: float
			if unit.enemy != null:
				var d: Vector3 = unit.enemy.node.position - unit.node.position
				aim = wrapf(atan2(d.x, d.z) - unit.heading, -PI, PI)
			else:
				aim = 0.0 if unit.moving else sin(now * 0.25 + unit.phase) * 0.9
			unit.turret_yaw = lerp_angle(unit.turret_yaw, aim, minf(1.0, delta * (2.2 if unit.enemy != null else 0.8)))
			unit.turret.basis = Basis(unit.turret.get_meta("axis"), unit.turret_yaw)
	spent("combat", t_units)
	var t_move := clock()
	var slot := 0
	for unit in units:
		slot += 1
		if unit.dead or disabled(unit):
			continue
		if unit.get("fly", false) or unit.get("naval", false):
			move_craft(unit, delta)
			continue
		var node: Node3D = unit.node
		var t_pre := clock()
		var shoved := Motion.knock_step(unit, delta)
		if shoved != Vector3.ZERO:
			var to_spot: Vector3 = node.position + shoved
			if height_at(to_spot.x, to_spot.z) > float(map.seaLevel) + 0.3:
				place_on_ground(unit, to_spot)
		var goal = unit.target
		var chasing := false
		if unit.enemy != null and (unit.target == null or unit.attack_move):
			var gap: Vector3 = unit.enemy.node.position - node.position
			gap.y = 0
			# Close in to a firing position of its own (tactics.gd), not onto the
			# enemy itself; once there, hold until the enemy draws clear of range.
			if gap_to(unit, unit.enemy) > unit.range * (1.03 if unit.get("holding", false) else 0.99):
				if thinks(unit) or not unit.has("spot"):
					unit.spot = Tactics.firing_spot(self, unit, unit.enemy)
				goal = unit.spot
				chasing = true
				unit.holding = false
				Tactics.unjam(self, unit, delta)
			else:
				unit.holding = true
				goal = null  # hold and fire; soldiers turn to face the enemy
				if not unit.vehicle:
					unit.heading = lerp_angle(unit.heading, atan2(gap.x, gap.z), minf(1.0, delta * 8.0))
					place_on_ground(unit, node.position)
				Motion.halt(unit, delta)
				if unit.moving:
					animate(unit, false)
				else:
					set_stance(unit)
		spent("  engage", t_pre)
		if goal == null:
			var t_idle := clock()
			Motion.halt(unit, delta)
			if unit.target == null and unit.moving:
				animate(unit, false)
			settle(unit)
			spread_out(unit, slot, delta)
			spent("  standing", t_idle)
			continue
		var t_steer := clock()
		var waypoint := steer_point(unit, goal, chasing, delta)
		spent("  steering", t_steer)
		var end: Vector3 = unit.path[unit.path.size() - 1] if not unit.path.is_empty() else goal
		var to: Vector3 = waypoint - node.position
		to.y = 0
		unit.traffic_cap = INF
		if unit.vehicle:
			# Hulls steer at a point further along the route and give way to
			# each other like traffic (tactics.gd), instead of being shoved.
			var aim: Vector3 = Tactics.look_ahead(unit, 7.0) if not unit.path.is_empty() else waypoint
			to = aim - node.position
			to.y = 0
			if thinks(unit) or not unit.has("traffic"):
				unit.traffic = Tactics.traffic(self, unit, to, Vector2(end.x - node.position.x, end.z - node.position.z).length() if not chasing else INF)
			var steer: Vector3 = unit.traffic.dir
			var swing := steer.signed_angle_to(to.normalized(), Vector3.UP) if to.length() > 0.001 else 0.0
			to = to.rotated(Vector3.UP, -swing) if absf(swing) > 0.001 else to
			unit.traffic_cap = unit.traffic.cap
		var remaining := Vector2(end.x - node.position.x, end.z - node.position.z).length()
		# A slot another unit is standing on is never reached exactly: when a
		# unit stops gaining on its mark, it counts as there if close, or tries
		# a fresh route, and after a few tries settles where it is.
		if not chasing:
			# Waiting in line behind a comrade is not being stuck.
			if remaining < float(unit.get("best_rem", INF)) - 0.4 or float(unit.get("traffic_cap", INF)) < 0.6:
				unit.best_rem = minf(remaining, float(unit.get("best_rem", INF)))
				unit.stall = 0.0
			else:
				unit.stall = float(unit.get("stall", 0.0)) + delta
			if unit.stall > 1.6:
				unit.stall = 0.0
				unit.best_rem = INF
				unit.stuck = int(unit.get("stuck", 0)) + 1
				# Close to the mark: that is where it stands. Far from it: a fresh
				# route, and only after many failures does it stop short.
				if remaining < (8.0 if unit.vehicle else 4.5) or (unit.stuck >= 4 and remaining < 20.0) or unit.stuck >= 10:
					remaining = 0.0
				else:
					unit.path = PackedVector3Array()
		if remaining < 0.35:
			if not chasing:
				unit.target = null
				unit.attack_move = false
			Motion.halt(unit, delta)
			animate(unit, false)
			settle(unit)
			continue
		# Speed, turning and slope are physical now: see motion.gd.
		var t_drive := clock()
		var travel := Motion.drive(self, unit, to, remaining, chasing, delta)
		spent("  driving", t_drive)
		var step := travel.length()
		var next: Vector3 = node.position + travel
		# Keep clear of other units instead of driving through them.
		# Crowd pressure is smooth, so each unit works it out every other frame
		# and keeps the last result in between; nothing moves differently.
		var t_sep := clock()
		var push: Vector3 = unit.get("push", Vector3.ZERO)
		if perf_opts and (sim_tick + slot) % 2 != 0:
			spent("  keeping clear", t_sep)
			next += (push if unit.vehicle else Tactics.sidestep(unit, travel, push)).limit_length(maxf(step * 1.5, delta * 1.5))
			if height_at(next.x, next.z) < float(map.seaLevel) + 0.25:
				unit.target = null
				Motion.halt(unit, delta)
				animate(unit, false)
				continue
			var t_place_now := clock()
			place_on_ground(unit, next)
			animate(unit, true)
			spent("  placing", t_place_now)
			continue
		push = Tactics.hard_push(self, unit, next) if unit.vehicle else Tactics.crowd_push(self, unit, next)
		unit.push = push
		spent("  keeping clear", t_sep)
		next += (push if unit.vehicle else Tactics.sidestep(unit, travel, push)).limit_length(maxf(step * 1.5, delta * 1.5))
		if height_at(next.x, next.z) < float(map.seaLevel) + 0.25:
			unit.target = null  # land units stop at the waterline
			Motion.halt(unit, delta)
			animate(unit, false)
			continue
		var t_place := clock()
		place_on_ground(unit, next)
		animate(unit, true)
		spent("  placing", t_place)
	spent("move", t_move)
	prof_frames += 1 if profiling else 0

# Standing units that overlap step apart a little at a time (a pile would
# block fire and feed every splash). Checked every fourth frame per unit.
func spread_out(unit: Dictionary, slot: int, delta: float) -> void:
	if (sim_tick + slot) % 4 != 0:
		return
	var push := Tactics.crowd_push(self, unit, unit.node.position)
	if push.length_squared() < 0.0025:
		return
	var next: Vector3 = unit.node.position + push.limit_length(delta * 4.0 * 1.6)
	if open_ground(next):
		place_on_ground(unit, next)

## Walkable by the walk grid (a lookup, unlike walkable(), which measures slope
## and every building); off the grid falls back to "above the waterline".
func open_ground(p: Vector3) -> bool:
	if nav_n == 0:
		return height_at(p.x, p.z) > float(map.seaLevel) + 0.3
	var half := float(map.mapSize) * 0.5
	var c := int((p.x + half) / NAV_STEP)
	var r := int((p.z + half) / NAV_STEP)
	if c < 0 or r < 0 or c >= nav_n - 1 or r >= nav_n - 1:
		return false
	return nav_open[r * (nav_n - 1) + c] == 1

## Whether this is one of `unit`'s decision frames (every THINK_EVERY-th
## physics frame, staggered across units so the work is spread evenly).
const THINK_EVERY := 6
func thinks(unit: Dictionary) -> bool:
	if not unit.has("think_slot"):
		unit.think_slot = randi() % THINK_EVERY
	return (sim_tick + int(unit.think_slot)) % THINK_EVERY == 0

# A parked vehicle keeps rocking on its springs until they come to rest.
func settle(unit: Dictionary) -> void:
	if unit.vehicle and absf(unit.get("sus_pitch", 0.0)) + absf(unit.get("sus_pitch_v", 0.0)) + absf(unit.get("sus_roll", 0.0)) + absf(unit.get("sus_roll_v", 0.0)) > 0.006:
		place_on_ground(unit, unit.node.position)

# ---------------------------------------------------------------- navigation

# A 4 m walk grid over the island: water, steep slopes and building
# footprints (with room for a tank to pass) are left out. The engine's
# NavigationServer finds routes on it.
func walkable(x: float, z: float) -> bool:
	var h := NAV_STEP * 0.5
	for corner in [Vector2(-h, -h), Vector2(h, -h), Vector2(-h, h), Vector2(h, h)]:
		if height_at(x + corner.x, z + corner.y) < float(map.seaLevel) + 0.4:
			return false
	if normal_at(x, z).y < 0.8:
		return false
	for spot in building_spots:
		if Vector2(x - spot.x, z - spot.z).length() < spot.y * 0.62 + 3.0:
			return false
	return true

func build_navigation() -> void:
	var half := float(map.mapSize) * 0.5
	var n := int(half * 2.0 / NAV_STEP) + 1
	nav_n = n
	nav_heights.resize(n * n)
	for r in range(n):
		for c in range(n):
			var x := -half + c * NAV_STEP
			var z := -half + r * NAV_STEP
			nav_heights[r * n + c] = Vector3(x, height_at(x, z), z)
	nav_open.resize((n - 1) * (n - 1))
	for r in range(n - 1):
		for c in range(n - 1):
			nav_open[r * (n - 1) + c] = 1 if walkable(-half + (c + 0.5) * NAV_STEP, -half + (r + 0.5) * NAV_STEP) else 0
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)
	var cells := rebuild_nav_mesh()
	var nav_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_active(nav_map, true)
	NavigationServer3D.map_set_use_async_iterations(nav_map, false)
	# The region joins the map on a later physics frame: wait until a query near
	# the base lands on the walk grid rather than at the empty map's origin.
	var probe := start + Vector3(0, 0, 30)
	probe.y = height_at(probe.x, probe.z)
	for i in range(240):
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map)==0:
			continue
		if NavigationServer3D.map_get_closest_point(nav_map, probe).distance_to(probe) < 20.0:
			nav_ready = true
			break
	print("Navigation: %d walkable cells, ready=%s" % [cells, nav_ready])

## Recomputes every walk cell from the current buildings (after loading).
func rebuild_walk_grid() -> void:
	if nav_n == 0:
		return
	var half := float(map.mapSize) * 0.5
	for r in range(nav_n - 1):
		for c in range(nav_n - 1):
			nav_open[r * (nav_n - 1) + c] = 1 if walkable(-half + (c + 0.5) * NAV_STEP, -half + (r + 0.5) * NAV_STEP) else 0
	rebuild_nav_mesh()

## Begins a match from the main menu: the AI nations wake up.
func start_match(difficulty: String) -> void:
	match_difficulty = difficulty
	var row: Dictionary = map.ai.difficulty.get(difficulty, map.ai.difficulty.easy)
	diplomacy.aggression = float(row.aggression)
	if ai.nations.is_empty():
		ai.setup(self, map.ai, difficulty, match_speed)
	cam_focus = start + Vector3(0, 0, 1)
	cam_dist_target = 115.0
	cam_pitch = 0.95
	hud.notice("%s difficulty. Build your economy, link your towns, and hold your capital." % difficulty.capitalize())

## Walks the menu flow: main menu (paused, no AI) -> new game on normal (AI
## wakes, play resumes) -> pause -> save -> load from the menu.
func menu_test() -> void:
	menu.open_main()
	var paused_at_menu: bool = get_tree().paused and ai.nations.is_empty()
	menu.open_new_game()
	menu.start("normal")
	var started: bool = not get_tree().paused and ai.nations.size() == 3 and match_difficulty == "normal"
	menu.open_pause()
	var paused: bool = get_tree().paused and not hud.visible
	saves.save("menutest")
	var money: float = economy.res.money
	economy.res.money = 1.0
	menu.load_game("menutest")
	var loaded: bool = not get_tree().paused and absf(economy.res.money - money) < 1.0 and hud.visible
	DirAccess.remove_absolute(saves.path_of("menutest"))
	print("paused at menu %s, new game %s, pause %s, load from menu %s" % [paused_at_menu, started, paused, loaded])
	var ok: bool = paused_at_menu and started and paused and loaded
	print("MENU_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Screenshots of the main, new game and settings screens.
func capture_menu() -> void:
	cam_focus = start
	cam_dist = 230.0
	cam_dist_target = 230.0
	cam_pitch = 0.42
	menu.open_main()
	for page in ["main", "new", "settings"]:
		if page == "new":
			menu.open_new_game()
		elif page == "settings":
			menu.open_settings()
		for i in range(40):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/menu-%s.png" % page)
	get_tree().quit()

## Removes every building, unit and road, before a saved game is restored.
func clear_match() -> void:
	cancel_placement()
	cancel_transport()
	select_building(null)
	for b in buildings:
		b.root.queue_free()
	for u in units:
		if is_instance_valid(u.get("bombard_marker")):
			u.bombard_marker.queue_free()
		u.node.queue_free()
	buildings.clear()
	units.clear()
	district_hex.clear()
	building_spots.clear()
	for d in deposits:
		d.extractor = null
	logistics.edges.clear()
	drill.clear()
	cancel_missile()
	if missiles:
		missiles.restore({})
	if territory:
		territory.reset()
	if occupation:
		occupation.clear()
	if passage:
		passage.restore({})

func rebuild_nav_mesh() -> int:
	var nav := NavigationMesh.new()
	nav.vertices = nav_heights
	var n := nav_n
	var cells := 0
	for r in range(n - 1):
		for c in range(n - 1):
			if nav_open[r * (n - 1) + c] == 0:
				continue
			var a := r * n + c
			nav.add_polygon(PackedInt32Array([a, a + n, a + n + 1, a + 1]))
			cells += 1
	nav_region.navigation_mesh = nav
	return cells

# A new building closes the walk cells under it (with room for a tank).
func close_navigation(at: Vector3, footprint: float) -> void:
	if nav_n == 0:
		return
	var half := float(map.mapSize) * 0.5
	var reach := footprint * 0.62 + 3.0
	var c0 := maxi(0, int((at.x - reach + half) / NAV_STEP))
	var c1 := mini(nav_n - 2, int((at.x + reach + half) / NAV_STEP))
	var r0 := maxi(0, int((at.z - reach + half) / NAV_STEP))
	var r1 := mini(nav_n - 2, int((at.z + reach + half) / NAV_STEP))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var x := -half + (c + 0.5) * NAV_STEP
			var z := -half + (r + 0.5) * NAV_STEP
			if Vector2(x - at.x, z - at.z).length() < reach:
				nav_open[r * (nav_n - 1) + c] = 0
	rebuild_nav_mesh()

func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not nav_ready:
		return PackedVector3Array([to])
	var route := NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)
	if route.is_empty():
		return PackedVector3Array([to])
	route = straighten(route)
	route.remove_at(0)  # the unit's own position
	if route.is_empty():
		route.append(to)
	return route

## The navigation grid is 4 m cells, so its routes zigzag cell to cell (36
## corners over 140 m of open field). Keep a corner only where the straight
## line past it would leave walkable ground: open country becomes one leg,
## and the route still bends round buildings, water and cliffs.
func straighten(route: PackedVector3Array) -> PackedVector3Array:
	if route.size() <= 2 or nav_n == 0:
		return route
	var out := PackedVector3Array([route[0]])
	var anchor := 0
	var i := 2
	while i < route.size():
		if not clear_line(route[anchor], route[i]):
			out.append(route[i - 1])
			anchor = i - 1
		i += 1
	out.append(route[route.size() - 1])
	return out

## Walkable ground all along the segment (sampled every 2 m on the walk grid).
func clear_line(a: Vector3, b: Vector3) -> bool:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var samples := maxi(1, ceili(length / 2.0))
	for k in range(1, samples):
		if not open_ground(a.lerp(b, float(k) / samples)):
			return false
	return true

# Next point to head for; plans (and re-plans while chasing) the route.
func steer_point(unit: Dictionary, goal: Vector3, chasing: bool, delta: float) -> Vector3:
	unit.repath -= delta
	var drift: float = unit.path_goal.distance_to(goal) if unit.path_goal != Vector3.INF else INF
	if unit.path.is_empty() or drift > (4.0 if chasing else 0.5):
		if not chasing or unit.repath <= 0.0 or unit.path.is_empty():
			unit.path = path_between(unit.node.position, goal)
			unit.path_goal = goal
			unit.repath = 0.8
	var pos: Vector3 = unit.node.position
	while unit.path.size() > 1 and Vector2(unit.path[0].x - pos.x, unit.path[0].z - pos.z).length() < 1.5:
		unit.path.remove_at(0)
	return unit.path[0] if not unit.path.is_empty() else goal

# Headless check: a route across the base must go around every building.
func nav_test() -> void:
	var failures := 0
	var tested := 0
	var nav_map := get_world_3d().navigation_map
	var probe_from := Vector3(start.x - 30, height_at(start.x - 30, start.z + 30), start.z + 30)
	var probe_to := Vector3(start.x + 30, height_at(start.x + 30, start.z + 30), start.z + 30)
	print("  map: regions=%d closest_from=%s raw_path=%d iteration=%d" % [NavigationServer3D.map_get_regions(nav_map).size(), NavigationServer3D.map_get_closest_point(nav_map, probe_from), NavigationServer3D.map_get_path(nav_map, probe_from, probe_to, true).size(), NavigationServer3D.map_get_iteration_id(nav_map)])
	for spot in building_spots:
		var from := Vector3(spot.x - spot.y * 1.6, 0, spot.z)
		var to := Vector3(spot.x + spot.y * 1.6, 0, spot.z)
		if height_at(from.x, from.z) < 1.0 or height_at(to.x, to.z) < 1.0:
			continue
		tested += 1
		var route := path_between(from, to)
		var previous := from
		for point in route:
			for k in range(8):
				var p := previous.lerp(point, k / 8.0)
				if Vector2(p.x - spot.x, p.z - spot.z).length() < spot.y * 0.5:
					failures += 1
				if height_at(p.x, p.z) < float(map.seaLevel):
					failures += 1
			previous = point
		print("  building at (%.0f, %.0f): %d waypoints" % [spot.x, spot.z, route.size()])
	print("NAV_TEST %s: %d routes, %d points inside buildings or water" % ["PASS" if failures == 0 and tested > 0 and nav_ready else "FAIL", tested, failures])
	get_tree().quit(0 if failures == 0 and tested > 0 else 1)

# ---------------------------------------------------------------- construction and training

# Construction sites call the nearest free worker; progress needs a worker on
# site (a second or third worker speeds it up). Barracks and factories train
# their queue and send each new unit a few metres out of the door.
func update_construction(delta: float) -> void:
	site_timer -= delta
	for b in buildings:
		if b.built or b.dead:
			continue
		var reach: float = b.footprint * 0.62 + 4.0
		var at: Vector3 = b.root.position
		var count := 0
		for u in units:
			if u.dead or u.build_site != b:
				continue
			if Vector2(u.node.position.x - at.x, u.node.position.z - at.z).length() < reach + 1.5 and u.target == null:
				count += 1
				if u.clip != u.work_clip and u.work_clip != "":
					u.player.play(u.work_clip, 0.2)
					u.player.speed_scale = 1.0
					u.clip = u.work_clip
				var face: Vector3 = at - u.node.position
				u.heading = atan2(face.x, face.z)
				place_on_ground(u, u.node.position)
		b.builders = count
		if count > 0:
			var skill: float = 1.0 + (research.bonus("prodPct") + research.bonus("buildPct") if research and b.owner == 0 else 0.0)
			b.progress = minf(1.0, b.progress + delta / maxf(float(b.def.buildTime), 1.0) * (1.0 + 0.5 * (count - 1)) * skill)
			b.model.scale.y = b.full_scale_y * lerpf(0.06, 1.0, b.progress)
			if randf() < delta * 1.5:
				effects.impact(at + Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3)))
		if b.progress >= 1.0:
			finish_building(b)
		elif site_timer <= 0.0 and count == 0 and b.owner == 0:
			call_worker(b)
	if site_timer <= 0.0:
		site_timer = 0.5

func call_worker(site: Dictionary) -> void:
	for u in units:
		if u.build_site == site and not u.dead:
			return  # already on the way
	var best = null
	var best_d := INF
	for u in units:
		if u.dead or u.owner != site.owner or u.key != "worker" or u.build_site != null or u.target != null:
			continue
		var d: float = u.node.position.distance_to(site.root.position)
		if d < best_d:
			best_d = d
			best = u
	if best == null:
		return
	var side: Vector3 = (best.node.position - site.root.position)
	side.y = 0
	side = side.normalized() if side.length() > 0.1 else Vector3.BACK
	order_move([best], site.root.position + side * (site.footprint * 0.62 + 3.0))
	best.build_site = site  # after the move order, which clears it

func finish_building(b: Dictionary) -> void:
	b.built = true
	b.progress = 1.0
	b.model.scale.y = b.full_scale_y
	for u in units:
		if u.build_site == b:
			u.build_site = null
			u.clip = ""
			animate(u, false)
	economy.recalculate()
	if b.owner == 0:
		hud.notice("%s complete" % b.def.name)
		if selected_building == b:
			hud.show_building(b)

func queue_unit(b: Dictionary, key: String) -> void:
	var def: Dictionary = unit_defs.get(key, {})
	if def.is_empty() or not b.built:
		return
	if b.queue.size() >= 5:
		hud.notice("Queue is full")
		return
	var queued_pop := 0
	for other in buildings:
		for q in other.queue:
			queued_pop += int(unit_defs.get(q, {}).get("pop", 0))
	if economy.pop_used + queued_pop + int(def.get("pop", 1)) > economy.pop_cap:
		hud.notice("Army capacity reached: build Housing Blocks")
		return
	var locked: String = research.unit_locked(key) if research else ""
	if locked != "":
		hud.notice("%s: %s." % [def.name, locked.to_lower()])
		return
	var cost: Dictionary = research.unit_cost(key, def.cost) if research else def.cost
	if not economy.pay(cost):
		hud.notice("Not enough %s" % economy.missing(cost))
		return
	b.queue.append(key)

func update_training(delta: float) -> void:
	for b in buildings:
		if b.dead or not b.built or b.queue.is_empty():
			continue
		if not b.get("supplied", true) or disabled(b):
			continue  # cut off (or struck by an EMP): the factory waits
		if b.owner > 0 and espionage and espionage.production_down(b.owner):
			continue  # a cyber attack stopped this nation's factories
		var rail: float = 1.0 + (logistics.rail_bonus if b.get("rail_supplied", false) else 0.0)
		if b.owner == 0 and research:
			rail *= 1.0 + research.bonus("prodPct")  # Industrialization, Fusion Power
		var first: String = b.queue[0]
		if first.begins_with("missile:"):
			b.queue_prog += delta * rail / maxf(missiles.build_time(first.substr(8)), 0.5)
			if b.queue_prog >= 1.0:
				b.queue_prog = 0.0
				b.queue.pop_front()
				missiles.finished(first.substr(8))
			continue
		var def: Dictionary = unit_defs[first]
		b.queue_prog += delta * rail / maxf(float(def.get("trainTime", 10)), 0.5)
		if b.queue_prog < 1.0:
			continue
		b.queue_prog = 0.0
		var key: String = b.queue.pop_front()
		var at: Vector3 = b.root.position
		var out := (Vector3(0, 0, 0) - at)
		out.y = 0
		out = out.normalized() if out.length() > 1.0 else Vector3.BACK
		var door: Vector3 = at + out * (b.footprint * 0.62 + 3.5)
		if key in NAVAL:
			var launch = water_near(at)
			if launch == null:
				b.queue.push_front(key)
				continue
			door = launch
			out = (door - at).normalized()
		var unit := spawn_unit(key, door, b.owner)
		unit.heading = atan2(out.x, out.z)
		order_move([unit], door + out * 8.0 + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		economy.recalculate()
		if b.owner == 0:
			hud.notice("%s ready" % def.name)

# ---------------------------------------------------------------- roads and railways

func begin_transport(kind: String) -> void:
	cancel_placement()
	transport_kind = kind
	transport_start = null
	transport_route = []
	logistics.show_grid(true)
	hud.show_transport("Click the starting hex (a settlement or an existing road), then the destination. Right click cancels.")

func cancel_transport() -> void:
	if transport_kind == "":
		return
	transport_kind = ""
	transport_start = null
	transport_route = []
	logistics.show_grid(false)
	logistics.show_preview([])
	hud.show_transport("")

func update_transport() -> void:
	if transport_kind == "" or transport_start == null:
		return
	var point = ground_point(get_viewport().get_mouse_position())
	if point == null:
		return
	var hex: Vector2i = logistics.world_hex(point)
	if hex == transport_hover:
		return
	transport_hover = hex
	transport_route = logistics.plan(transport_start, hex, 0, transport_kind)
	logistics.show_preview(transport_route)
	if transport_route.size() < 2:
		hud.show_transport("No land route there: roads cannot cross the sea, steep cliffs or a rival's land.")
		return
	var cost: Dictionary = logistics.quote(transport_route, transport_kind, 0)
	hud.show_transport("%d links · %s. Click to build; intact links are free, damaged ones are repaired at a discount." % [transport_route.size() - 1, hud.cost_text({"money": cost.money, "iron": cost.iron} if cost.iron > 0 else {"money": cost.money})])

func transport_click(screen: Vector2, keep: bool) -> void:
	var point = ground_point(screen)
	if point == null:
		return
	if transport_start == null:
		transport_start = logistics.world_hex(point)
		transport_hover = Vector2i(1 << 20, 0)
		hud.show_transport("Now click the destination hex.")
		return
	if transport_route.size() < 2:
		hud.notice("No route to build")
		return
	var cost: Dictionary = logistics.quote(transport_route, transport_kind, 0)
	if not logistics.build(transport_route, transport_kind, 0):
		hud.notice("Not enough %s" % economy.missing(cost))
		return
	hud.notice("%s built: supply network updated" % ("Road" if transport_kind == "road" else "Railway"))
	if keep:
		transport_start = transport_route[transport_route.size() - 1]
		transport_route = []
		logistics.show_preview([])
	else:
		cancel_transport()

## Saves a match, changes everything, loads, and checks that it came back.
func save_test() -> void:
	economy.res.money = 3210.0
	var farm_at: Vector3 = snap_to_hex(buildings[0].root.position + Vector3(-34, 0, 20))
	var site := place_building("farm", farm_at, 0, false)
	site.progress = 0.4
	var home: Vector2i = logistics.world_hex(buildings[0].root.position)
	var route: Array = logistics.plan(home, home + Vector2i(3, 0), 0, "road")
	logistics.build(route, "road", 0)
	diplomacy.declare_war(0, 2)
	diplomacy.set_score(0, 1, 42.0)
	var soldier: Dictionary = units.filter(func(u): return u.key == "soldier" and u.owner == 0)[0]
	soldier.hp = 37.0
	cam_focus = start + Vector3(12, 0, 7)
	var before: Dictionary = snapshot()
	if not saves.save("test"):
		get_tree().quit(1)
		return
	# Change everything.
	economy.res.money = 5.0
	for b in buildings:
		if b.key == "farm":
			destroy_building(b)
	logistics.edges.clear()
	diplomacy.make_peace(0, 2)
	diplomacy.set_score(0, 1, -80.0)
	for u in units.duplicate():
		kill(u)
	var loaded: bool = saves.load_slot("test")
	for i in range(3):
		await get_tree().physics_frame
	var after: Dictionary = snapshot()
	var same: bool = before == after
	if not same:
		for key in before:
			if before[key] != after.get(key):
				print("  differs: %s: %s -> %s" % [key, before[key], after.get(key)])
	var farm_back: bool = buildings.any(func(b): return b.key == "farm" and not b.built and absf(b.progress - 0.4) < 0.01)
	var path_ok: bool = path_between(start + Vector3(0, 0, 30), start + Vector3(0, 0, -30)).size() > 1
	print("saved %d buildings, %d units, %d road links; loaded %s, identical %s, construction kept %s, routes work %s" % [before.buildings, before.units, before.edges, loaded, same, farm_back, path_ok])
	var ok: bool = loaded and same and farm_back and path_ok
	print("SAVE_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

func snapshot() -> Dictionary:
	var hp_sum := 0.0
	for u in units:
		if not u.dead:
			hp_sum += u.hp
	return {
		"money": roundi(economy.res.money), "buildings": buildings.filter(func(b): return not b.dead).size(),
		"units": units.filter(func(u): return not u.dead).size(), "unit_hp": roundi(hp_sum),
		"edges": logistics.edges.size(), "war_0_2": diplomacy.at_war(0, 2), "rel_0_1": roundi(diplomacy.rel(0, 1)),
		"camera": Vector2i(roundi(cam_focus.x), roundi(cam_focus.z)),
	}

## Checks diplomacy: gifts warm relations, a trade pact pays both sides, a
## non-aggression pact stops AI wars, an ally joins the player's war, and peace
## can be made. Foreign letters get Accept/Decline.
func diplomacy_test(capture: bool) -> void:
	var d: Node = diplomacy
	economy.res.money = 5000.0
	for id in range(1, d.n):
		d.set_score(0, id, 0.0)
	var before: float = d.rel(0, 1)
	d.gift(1)
	var gift_ok: bool = d.rel(0, 1) > before
	d.set_score(0, 1, 30.0)
	d.propose_pact(1)
	var money: float = economy.res.money
	d.tick()
	var pact_ok: bool = d.pact[0][1] and economy.res.money >= money + 40.0
	d.set_score(0, 2, 60.0)
	d.nap[0][2] = true
	d.nap[2][0] = true
	var nap_ok: bool = not d.ai_wants_war(2, 0)
	d.set_score(0, 3, 90.0)
	while not d.allied(0, 3):
		d.propose_alliance(3)
	d.set_score(0, 1, -50.0)
	d.declare_war(1, 0)
	var joined := false
	for i in range(20):
		d.request_joint_war(3, 1)
		if d.at_war(3, 1):
			joined = true
			break
	var hostile_ok := hostile(0, 1) and hostile(3, 1) and not hostile(0, 2)
	d.set_score(0, 2, 60.0)
	if capture:
		hud.toggle_diplomacy()
		hud.ask("Golden Dominion proposes a trade pact ($40 every 10 s for both).", func(): pass, func(): pass)
		cam_focus = start
		for i in range(60):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/diplomacy-0.png")
	var peace := false
	for i in range(40):
		if d.at_war(0, 1):
			d.offer_peace(1)
		else:
			peace = true
			break
	print("gift %s, pact pays %s, NAP blocks war %s, ally joins %s, hostility %s, peace %s" % [gift_ok, pact_ok, nap_ok, joined, hostile_ok, peace])
	var ok: bool = gift_ok and pact_ok and nap_ok and joined and hostile_ok and peace
	print("DIPLOMACY_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## A hex near `from` where `key` may stand, or where only the territory rule
## objects (the test places it directly).
func test_site(key: String, from: Vector3) -> Variant:
	var origin: Vector2i = logistics.world_hex(from)
	for ring in range(1, 18):
		for dq in range(-ring, ring + 1):
			for dr in range(-ring, ring + 1):
				if absi(dq + dr) > ring:
					continue
				var at: Vector3 = logistics.hex_center(origin + Vector2i(dq, dr))
				var problem := site_problem(key, at, 0)
				if problem == "" or problem == "Outside your territory" or problem.begins_with("Inside "):
					return at
	return null

## Market, espionage, missiles, territory and saving them, in fast time.
func systems_test(capture: bool) -> void:
	for i in range(30):
		await get_tree().process_frame
	var d: Node = diplomacy
	var hq: Dictionary = buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var home: Vector3 = hq.root.position
	var placed := {}
	for key in ["market", "port", "intelAgency", "ammoDepot", "missileSilo"]:
		var at = test_site(key, home)
		if at == null:
			print("no site for %s" % key)
			continue
		placed[key] = place_building(key, at, 0, true)
		close_navigation(at, DISTRICT_NAV_SIZE)
	refresh_streets()
	economy.recalculate()
	for key in ["money", "iron", "oil", "silicon", "uranium"]:
		economy.res[key] = minf(60000.0, economy.caps.get(key, 60000.0))
	var built_ok := placed.size() == 5

	# Market: instant deals and a trade route that delivers or is lost at sea.
	var money: float = economy.res.money
	market.sell("oil", 50)
	var sold: bool = economy.res.money > money
	money = economy.res.money
	economy.res.iron -= 100.0
	market.buy("iron", 25)
	var bought: bool = economy.res.money < money
	d.set_score(0, 1, 40.0)
	d.set_flag(d.war, 0, 1, false)
	d.set_flag(d.pact, 0, 1, true)
	var opened: String = market.open_route(1, "oil", "export", 25)
	var trips := 0
	for i in range(12):
		market.tick()
		trips = market.delivered + market.lost
	var trade_ok: bool = sold and bought and market.routes.size() == 1 and trips >= 2
	print("market: sold %s, bought %s, route: %s, voyages %d (delivered %d, lost %d)" % [sold, bought, opened, trips, market.delivered, market.lost])

	# Espionage: agents, a network, real effects on the target nation.
	print(espionage.recruit())
	print(espionage.recruit())
	var nation2 = market.ai_nation(2)
	nation2.money = 2000.0
	for i in range(3):
		print(espionage.run("buildNetwork", 2, "", -1, 0.0))
		espionage.advance(75.0)
	money = economy.res.money
	print(espionage.run("stealFunds", 2, "", -1, 0.0))
	espionage.advance(90.0)
	var stolen: bool = economy.res.money > money and nation2.money < 2000.0
	espionage.network[2] = 65.0
	espionage.intel[2] = 65.0
	espionage._collect(2, false)
	print(espionage.run("assassinate", 2, "general", -1, 0.0))
	espionage.advance(210.0)
	print(espionage.run("cyberAttack", 2, "", -1, 0.0))
	espionage.advance(90.0)
	var spy_ok: bool = espionage.network[2] >= 18.0 and espionage.intel[2] > 10.0 and stolen and espionage.production_down(2) and espionage.damage_mult(2) < 1.0
	espionage.network[3] = 30.0
	espionage.intel[3] = 30.0
	espionage.run("sabotage", 3, "", -1, 0.99)
	espionage.advance(100.0)
	var failed: String = espionage.reports[0].text
	print(failed)
	var consequence: bool = "captured" in failed.to_lower() or "escaped" in failed.to_lower()
	espionage.enemy_attempt("caught")
	spy_ok = spy_ok and consequence and not espionage.reports.is_empty()
	print("espionage: network %d, intel %d, funds stolen %s, cyber %s, general %s, failure handled %s" % [espionage.network[2], espionage.intel[2], stolen, spy_ok, espionage.damage_mult(2) < 1.0, consequence])

	# Missiles: build one in the silo, fire it at a rival building, EMP and nuke.
	var silo: Dictionary = placed.get("missileSilo", {})
	var queued: String = missiles.produce(silo, "tactical") if not silo.is_empty() else "no silo"
	for i in range(400):
		update_training(0.1)
		if missiles.stock.tactical > 0:
			break
	var produced: bool = missiles.stock.tactical == 1
	var target = null
	for b in buildings:
		if b.owner == 1 and not b.dead and b.key != "hq":
			target = b
			break
	if target == null:
		target = buildings.filter(func(b): return b.owner == 1)[0]
	var hp_before: float = target.hp
	d.set_flag(d.war, 0, 1, false)
	print(missiles.launch("tactical", target.root.position))
	if capture:
		await capture_missile_flight(target.root.position)
	for i in range(200):
		missiles._physics_process(0.05)
		if missiles.flying.is_empty():
			break
	var struck: bool = target.hp < hp_before or target.dead
	var war_started: bool = d.at_war(0, 1)
	var victims: Array = units.filter(func(u): return u.owner == 1 and not u.dead and u.vehicle and not u.get("fly", false))
	var emp_target: Vector3 = victims[0].node.position if not victims.is_empty() else target.root.position
	missiles.stock.emp = 1
	missiles.launch("emp", emp_target)
	for i in range(200):
		missiles._physics_process(0.05)
		if missiles.flying.is_empty():
			break
	var emp_ok: bool = victims.is_empty() or disabled(victims[0]) or victims[0].dead
	for i in range(1, d.n):
		d.set_score(0, i, 20.0)
	var hq3: Dictionary = buildings.filter(func(b): return b.owner == 3 and b.key == "hq")[0]
	var ground_zero: Vector3 = hq3.root.position + Vector3(30, 0, 0)
	missiles.stock.nuke = 1
	print(missiles.launch("nuke", ground_zero))
	for i in range(300):
		missiles._physics_process(0.05)
		if missiles.flying.is_empty():
			break
	var condemned: bool = d.rel(0, 2) <= -9.0
	if capture:
		cam_yaw = PI * 0.25
		await capture_view("res://build/systems-nuke.png", ground_zero, 190.0, 0.45, 50)
	var missile_ok: bool = queued == "" and produced and struck and war_started and emp_ok and condemned
	print("missiles: queued [%s], produced %s, struck %s, war %s, EMP %s, nuke condemned %s (relation %d)" % [queued, produced, struck, war_started, emp_ok, condemned, int(d.rel(0, 2))])

	# Territory: the capital holds land; an occupying army takes enemy land.
	territory.tick()
	var home_cell: int = territory.cell_of(home)
	var holds: bool = territory.owner_of[home_cell] == 0 and territory.yields(0).cells > 3
	var enemy_cell := -1
	var hq2: Dictionary = buildings.filter(func(b): return b.owner == 2 and b.key == "hq")[0]
	for i in range(territory.owner_of.size()):
		if territory.owner_of[i] == 2 and territory.center(i).distance_to(hq2.root.position) > 60.0 and height_at(territory.center(i).x, territory.center(i).z) > float(map.seaLevel) + 1.0:
			enemy_cell = i
			break
	var taken := false
	if enemy_cell >= 0:
		var c: Vector3 = territory.center(enemy_cell)
		# Only a hostile army takes land (passage.gd): at peace it would be trespass.
		diplomacy.declare_war(0, 2)
		for i in range(14):
			spawn_unit("tank", c + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 0)  # inside the hex
		for i in range(120):
			territory.tick()
			if territory.owner_of[enemy_cell] == 0:
				taken = true
				break
	var land_ok: bool = holds and taken
	print("territory: capital holds %s (%d cells), army took cell %d: %s, fronts %d" % [holds, territory.yields(0).cells, enemy_cell, taken, territory.fronts])
	if capture:
		hud.toggle_panel("territory")
		await capture_view("res://build/systems-territory.png", home, 260.0, 1.05, 40)
		hud.toggle_panel("intel")
		await capture_view("res://build/systems-intel.png", home, 120.0, 0.9, 30)
		hud.toggle_panel("market")
		await capture_view("res://build/systems-market.png", home, 120.0, 0.9, 30)
		hud.toggle_panel("market")
		select_building(silo)
		await capture_view("res://build/systems-silo.png", silo.root.position, 42.0, 0.62, 40)

	# Saving keeps all four.
	saves.save("systemstest")
	var routes: int = market.routes.size()
	var agents: int = espionage.agents.size()
	var owners: PackedInt32Array = territory.owner_of.duplicate()
	missiles.stock.cruise = 2
	market.routes.clear()
	espionage.agents.clear()
	territory.reset()
	saves.load_slot("systemstest")
	DirAccess.remove_absolute(saves.path_of("systemstest"))
	var saved_ok: bool = market.routes.size() == routes and espionage.agents.size() == agents and missiles.stock.cruise == 0 and territory.owner_of == owners
	print("save: routes %d/%d, agents %d/%d, territory kept %s" % [market.routes.size(), routes, espionage.agents.size(), agents, territory.owner_of == owners])
	var ok: bool = built_ok and trade_ok and spy_ok and missile_ok and land_ok and saved_ok
	print("built %s, market %s, espionage %s, missiles %s, territory %s, save %s" % [built_ok, trade_ok, spy_ok, missile_ok, land_ok, saved_ok])
	print("SYSTEMS_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Close-ups of every infantry type of every nation, standing and running.
func capture_infantry() -> void:
	var spot := land_point(start, 40.0)
	var kinds := ["soldier", "sniper", "rocketSoldier", "commando"]
	var line: Array = []
	for owner in range(4):
		for i in range(kinds.size()):
			var u := spawn_unit(kinds[i], spot + Vector3(i * 2.4 - 3.6, 0, owner * 3.0 - 4.5), owner)
			u.heading = 0.4
			place_on_ground(u, u.node.position)
			line.append(u)
	var runner := spawn_unit("soldier", spot + Vector3(-6, 0, 8), 0)
	order_move([runner], spot + Vector3(60, 0, 8))
	cam_yaw = 0.35
	await capture_view("res://build/infantry-group.png", spot + Vector3(0, 0, 0), 16.0, 0.32, 50)
	cam_yaw = 1.4
	await capture_view("res://build/infantry-side.png", spot + Vector3(-1.2, 0, -4.5), 6.5, 0.18, 20)
	cam_yaw = 0.4 + PI
	await capture_view("res://build/infantry-back.png", spot + Vector3(1.2, 0, 0), 9.0, 0.3, 10)
	cam_yaw = runner.heading + PI * 0.5
	await capture_view("res://build/infantry-run.png", runner.node.position, 7.0, 0.2, 2)
	damage(line[0], 9999.0, line[1])
	damage(line[5], 9999.0, line[1])
	for i in range(60):
		await get_tree().physics_frame
	cam_yaw = 0.35
	await capture_view("res://build/infantry-dead.png", spot + Vector3(0, 0, -2), 12.0, 0.45, 5)
	get_tree().quit()

## Research in fast time: stages, facilities, half and full effects, eras,
## unit locks, tracks, rival research, espionage and saving.
func research_test(capture: bool) -> void:
	for i in range(20):
		await get_tree().process_frame
	var r: Node = research
	var home: Vector3 = buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for key in ["money", "iron", "oil", "silicon", "uranium"]:
		economy.res[key] = 5000.0
	var place := func(key: String) -> Dictionary:
		var at = test_site(key, home)
		var b := place_building(key, at, 0, true)
		close_navigation(at, DISTRICT_NAV_SIZE)
		economy.recalculate()
		return b
	# Research buildings raise the rate.
	r.tick(1.0)
	var base_rate: float = r.rate
	place.call("school")
	place.call("university")
	r.tick(1.0)
	var labs_ok: bool = r.rate > base_rate + 1.0
	# Three stages, never faster than 20 s each, half the effect after the prototype.
	r.points = 5000.0
	r.enqueue("fertilizers")
	var stage_times := []
	for t in range(120):
		var before: int = r.stage_of("fertilizers")
		r.tick(1.0)
		if r.stage_of("fertilizers") != before:
			stage_times.append(t + 1)
		if r.done("fertilizers"):
			break
	var paced: bool = stage_times.size() == 3 and stage_times[0] >= 20 and stage_times[1] - stage_times[0] >= 20
	var full_food: float = r.bonus("foodPct")
	var stages_ok: bool = paced and r.done("fertilizers") and absf(full_food - 0.5) < 0.01 and r.queue.is_empty()
	print("labs raise rate %s (%.2f -> %.2f); fertilizer stages at %s s, food bonus %.2f" % [labs_ok, base_rate, r.rate, str(stage_times), full_food])
	# The Regional Era needs a village and 8 buildings.
	var locked_before: String = r.enqueue("compositeArmor")
	var money_before: float = economy.res.money
	var village_at: Vector3 = home + Vector3(95, 0, 0)
	for a in range(16):
		var p: Vector3 = home + Vector3(cos(a * TAU / 16.0), 0, sin(a * TAU / 16.0)) * 95.0
		if site_problem("villageCenter", snap_to_hex(p), 0) == "":
			village_at = snap_to_hex(p)
			break
	place_building("villageCenter", village_at, 0, true)
	for k in ["farm", "housing", "warehouse", "library"]:
		place.call(k)
	r.tick(1.0)
	var era_ok: bool = r.era >= 1 and locked_before != "" and economy.res.money > money_before
	print("before the era: [%s]; era now %s, reward paid %s" % [locked_before, r.eras[r.era].name, economy.res.money > money_before])
	# A prototype needs its facility: Global Logistics waits for a Market.
	r.points = 5000.0
	r.enqueue("globalLogistics")
	for t in range(40):
		r.tick(1.0)
	var waited: bool = r.stage_of("globalLogistics") == 1 and r.blocker("globalLogistics").contains("Market")
	place.call("market")
	for t in range(80):
		r.tick(1.0)
	waited = waited and r.done("globalLogistics") and r.bonus("tradeRoutes") >= 1.0
	r.enqueue("compositeArmor")
	for t in range(80):
		r.tick(1.0)
	var tank := spawn_unit("tank", land_point(home, 30.0), 0)
	var armor_ok: bool = waited and r.done("compositeArmor") and absf(tank.max_hp - float(unit_defs.tank.hp) * 1.2) < 1.0
	print("prototype waited for the market %s, tank hp %d of %d base" % [waited, int(tank.max_hp), int(unit_defs.tank.hp)])
	# Warships and missiles are locked until their discovery.
	var ship_locked: bool = r.unit_locked("destroyer") != "" and missiles.locked("ballistic") != ""
	r.progress.navalEngineering.stage = 3
	r._recompute()
	var ship_open: bool = r.unit_locked("destroyer") == "" and missiles.locked("antiShip") == ""
	# A research track level.
	r.points = 1000.0
	r.enqueue("track:economy")
	for t in range(40):
		r.tick(1.0)
	var track_ok: bool = r.tracks.economy == 1 and r.bonus("incomePct") >= 0.12
	# Rivals research; stolen research moves points.
	for i in range(40):
		r.ai_tick()
	var rival: Dictionary = ai.nations[0]
	var rival_ok: bool = r.ai_tech(rival.id) >= 1.0 and r.damage_mult({"owner": rival.id}) > 1.0
	place.call("intelAgency")
	espionage.recruit()
	r.points = 0.0
	espionage.network[rival.id] = 25.0
	espionage.intel[rival.id] = 25.0
	espionage.run("stealTech", rival.id, "", -1, 0.0)
	espionage.advance(90.0)
	var stolen_ok: bool = r.points >= 119.0
	print("ships locked %s then open %s, economics level %d, rival tech %d, stolen %d points" % [ship_locked, ship_open, r.tracks.economy, int(r.ai_tech(rival.id)), int(r.points)])
	if capture:
		r.points = 900.0
		r.enqueue("irrigation")
		r.enqueue("navalEngineering")
		r.enqueue("advancedLogistics")
		for t in range(12):
			r.tick(1.0)
		hud.toggle_research()
		hud._rs_sel = "irrigation"
		hud._tree.selected = "irrigation"
		hud._rs_sig = ""
		hud._refresh_research()
		await capture_view("res://build/research-tree.png", home, 120.0, 0.9, 30)
		hud.toggle_research()
		select_building(buildings.filter(func(b): return b.key == "university")[0])
		await capture_view("res://build/research-university.png", buildings.filter(func(b): return b.key == "university")[0].root.position, 60.0, 0.7, 30)
	# Saving keeps it all.
	r.enqueue("publicEducation")
	saves.save("researchtest")
	var saved := {"era": r.era, "points": int(r.points), "queue": r.queue.duplicate(), "tracks": r.tracks.duplicate(), "fert": r.stage_of("fertilizers")}
	r.era = 0
	r.points = 0.0
	r.queue.clear()
	r.tracks.economy = 0
	saves.load_slot("researchtest")
	DirAccess.remove_absolute(saves.path_of("researchtest"))
	var save_ok: bool = r.era == saved.era and int(r.points) == saved.points and r.queue == saved.queue and r.tracks.economy == saved.tracks.economy and r.stage_of("fertilizers") == 3
	print("labs %s, stages %s, era %s, facility %s, locks %s, track %s, rivals %s, stolen %s, save %s" % [labs_ok, stages_ok, era_ok, armor_ok, ship_locked and ship_open, track_ok, rival_ok, stolen_ok, save_ok])
	var ok: bool = labs_ok and stages_ok and era_ok and armor_ok and ship_locked and ship_open and track_ok and rival_ok and stolen_ok and save_ok
	print("RESEARCH_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Drives the interface the way a player would: every screen opens and
## closes, every button in every screen is pressed, the production list
## builds and trains, the research tree queues, the menus open, and nothing
## raises an error on the way.
func ui_test() -> void:
	for i in range(30):
		await get_tree().process_frame
	var checks := {}
	var home: Vector3 = buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for key in ["market", "port", "intelAgency", "school", "missileSilo", "ammoDepot"]:
		var at = test_site(key, home)
		if at != null:
			place_building(key, at, 0, true)
	economy.recalculate()
	for key in ["money", "iron", "oil", "silicon", "uranium"]:
		economy.res[key] = minf(50000.0, economy.caps.get(key, 50000.0))
	diplomacy.set_score(0, 1, 60.0)
	diplomacy.set_flag(diplomacy.pact, 0, 1, true)
	espionage.recruit()
	# Every screen opens with content, and every button in it can be pressed.
	for mode in ["diplomacy", "market", "intel", "territory"]:
		hud.toggle_panel(mode, true)
		await get_tree().process_frame
		var opened: bool = hud._win.visible and hud._side_rows.get_child_count() > 0
		# The screen redraws after each press, so buttons are looked up afresh
		# by position every time.
		var pressed := 0
		var index := 0
		while index < 60:
			var buttons: Array = hud._side_rows.find_children("*", "Button", true, false)
			if index >= buttons.size():
				break
			var b: Button = buttons[index]
			index += 1
			if b.disabled or b.text.begins_with("Declare war"):
				continue  # war is pressed once below, so the other buttons stay useful
			b.pressed.emit()
			pressed += 1
			await get_tree().process_frame
		for b in hud._side_rows.find_children("*", "Button", true, false):
			if b.text.begins_with("Declare war"):
				b.pressed.emit()
				pressed += 1
				break
		checks["%s screen opens and its %d buttons work" % [mode, pressed]] = opened and (pressed > 3 or mode == "territory")
		hud.toggle_panel(mode)
		await get_tree().process_frame
		checks["%s screen closes" % mode] = not hud._win.visible
	# Territory view paints the terrain and explains a clicked cell.
	hud.toggle_panel("territory", true)
	var mat: ShaderMaterial = terrain_node.material_override
	checks["territory is painted on the terrain"] = mat.get_shader_parameter("show_territory") == true and mat.get_shader_parameter("territory_tex") != null
	checks["clicked land is described"] = territory.describe(home).contains("held by You")
	hud.toggle_panel("territory")
	checks["territory paint goes away"] = mat.get_shader_parameter("show_territory") == false
	# Production list: every tab lists its buildings; a bar starts placement.
	for tab in hud.BUILD_MENU:
		hud.build_tab = tab
		hud._shown_key = ""
		hud._update_panel()
		var bars: Array = hud._list.get_children().filter(func(b): return b is Button)
		checks["%s tab lists %d buildings" % [tab, bars.size()]] = bars.size() >= hud.BUILD_MENU[tab].filter(func(k): return building_defs.has(k)).size()
	hud.build_tab = "Economy"
	hud._shown_key = ""
	hud._update_panel()
	var farm_bar = hud._list.get_children().filter(func(b): return b is Button)[2]
	farm_bar.pressed.emit()
	checks["a production bar starts placing the building"] = placing == "farm"
	cancel_placement()
	# A barracks trains from its bars; the queue shows in the selection panel.
	var barracks = buildings.filter(func(b): return b.owner == 0 and b.key == "barracks")
	if not barracks.is_empty():
		select_building(barracks[0])
		await get_tree().process_frame
		hud._update_panel()
		var train: Array = hud._list.get_children().filter(func(b): return b is Button)
		var before: int = barracks[0].queue.size()
		train[0].pressed.emit()
		await get_tree().process_frame
		hud._update_panel()
		checks["barracks lists its %d units" % train.size()] = train.size() == barracks[0].def.trains.size()
		checks["a unit bar queues training"] = barracks[0].queue.size() == before + 1
		checks["the queue shows in the selection panel"] = hud._sel.visible and hud._sel_queue.get_child_count() == barracks[0].queue.size()
		select_building(null)
	# The silo lists every missile; building one works from its bar.
	var silo = buildings.filter(func(b): return b.owner == 0 and b.key == "missileSilo")
	if not silo.is_empty():
		select_building(silo[0])
		hud._update_panel()
		var bars: Array = hud._list.get_children().filter(func(b): return b is Button)
		checks["the silo lists all %d missiles" % missiles.types().size()] = bars.size() >= missiles.types().size()
		bars[0].pressed.emit()
		checks["a missile bar queues a missile"] = silo[0].queue.size() == 1
		select_building(null)
	# Selecting units fills the selection panel.
	var army := units.filter(func(u): return u.owner == 0 and u.dmg > 0.0)
	for u in army.slice(0, 3):
		u.selected = true
	hud._update_panel()
	checks["selected units show in the selection panel"] = hud._sel.visible and hud._sel_title.text != ""
	for u in army:
		u.selected = false
	# Top bar reads the economy.
	await get_tree().create_timer(0.3).timeout
	checks["top bar shows money"] = hud._chips.money[0].text == str(int(economy.res.money)) or hud._chips.money[0].text.begins_with(str(int(economy.res.money)).left(2))
	# Research screen opens, a discovery can be queued from its pane.
	hud.toggle_research()
	await get_tree().process_frame
	hud._rs_sel = "fertilizers"
	hud._rs_sig = ""
	hud._refresh_research()
	var research_buttons: Array = hud._rs_detail.find_children("*", "Button", true, false)
	if not research_buttons.is_empty():
		research_buttons[0].pressed.emit()
	checks["research screen queues a discovery"] = hud._rs.visible and "fertilizers" in research.queue
	hud.toggle_research()
	checks["research screen closes"] = not hud._rs.visible
	# Help, the minimap and the menus.
	hud.toggle_help()
	checks["help opens"] = hud._help.visible
	hud.toggle_help()
	var map_ctrl = hud.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == preload("res://scripts/minimap.gd"))[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 20)
	map_ctrl._gui_input(click)
	checks["a minimap click moves the camera"] = cam_focus.distance_to(home) > 100.0
	menu.setup(self)
	menu.open_pause()
	checks["pause menu opens and pauses"] = get_tree().paused and menu._root.visible
	menu.open_settings()
	checks["settings open"] = menu._panel.get_child_count() >= 5
	menu.close()
	checks["menu closes and play resumes"] = not get_tree().paused
	var failed := checks.keys().filter(func(k): return not checks[k])
	for k in checks:
		print("%s  %s" % ["ok  " if checks[k] else "FAIL", k])
	print("UI_TEST %s" % ("PASS" if failed.is_empty() else "FAIL"))
	get_tree().quit(0 if failed.is_empty() else 1)

## A whole match at speed: every rival on hard, time running four times as
## fast for `minutes` of game time. Every few seconds the world must still be
## sound: no unit or building with broken numbers, resources never negative,
## nothing below the ground or far off the map, and the game still running.
func soak_test(minutes: float) -> void:
	for i in range(20):
		await get_tree().process_frame
	for n in ai.nations:
		n.next_attack = 60.0
	Engine.time_scale = 4.0
	var problems := {}
	var seconds := 0.0
	var checks := 0
	var peak := 0
	var half := float(map.mapSize) * 0.6
	while seconds < minutes * 60.0 and game_over == "":
		await get_tree().create_timer(2.0).timeout
		seconds += 2.0 * Engine.time_scale
		checks += 1
		peak = maxi(peak, units.size())
		for key in economy.res:
			if economy.res[key] < -0.01 or is_nan(economy.res[key]):
				problems["resource %s went to %s" % [key, economy.res[key]]] = true
		for u in units:
			if u.dead:
				continue
			var p: Vector3 = u.node.position
			if is_nan(p.x) or is_nan(p.z) or is_nan(u.hp):
				problems["%s has broken numbers" % u.key] = true
			elif absf(p.x) > half or absf(p.z) > half:
				problems["%s left the map" % u.key] = true
			elif not u.get("naval", false) and not u.get("fly", false) and p.y < height_at(p.x, p.z) - 1.0:
				problems["%s sank into the ground" % u.key] = true
			if u.hp > u.max_hp + 0.5:
				problems["%s has more health than its maximum" % u.key] = true
		for b in buildings:
			if not b.dead and (is_nan(b.hp) or b.hp > b.max_hp + 0.5):
				problems["%s has broken health" % b.key] = true
		for n in ai.nations:
			if is_nan(n.money) or n.money < -0.01:
				problems["%s treasury broke" % n.name] = true
	Engine.time_scale = 1.0
	var built: int = buildings.filter(func(b): return b.owner > 0 and not b.dead).size()
	var wars: int = 0
	for a in range(diplomacy.n):
		for b in range(a + 1, diplomacy.n):
			if diplomacy.at_war(a, b):
				wars += 1
	print("played %d s of game time in %d checks: peak %d units, rivals hold %d buildings, %d wars, game over: %s" % [int(seconds), checks, peak, built, wars, game_over if game_over != "" else "no"])
	for p in problems:
		print("FAIL  " + p)
	var ok: bool = problems.is_empty() and built > 6
	print("SOAK_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Screenshots of every screen with something in it: diplomacy, the market
## with a trade route, intelligence with agents, territory with a picked
## cell, a foreign letter, the pause menu and the main menu.
func capture_screens() -> void:
	for i in range(30):
		await get_tree().process_frame
	var home: Vector3 = buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for key in ["market", "port", "intelAgency"]:
		var at = test_site(key, home)
		if at != null:
			place_building(key, at, 0, true)
	economy.recalculate()
	economy.res.money = 9000.0
	economy.res.oil = 300.0
	diplomacy.set_score(0, 1, 45.0)
	diplomacy.set_flag(diplomacy.pact, 0, 1, true)
	diplomacy.set_score(0, 3, 70.0)
	diplomacy.set_flag(diplomacy.alliance, 0, 3, true)
	diplomacy.declare_war(0, 2)
	market.open_route(1, "oil", "export", 25)
	market.tick()
	espionage.recruit()
	espionage.recruit()
	for i in range(2):
		espionage.run("buildNetwork", 2, "", -1, 0.0)
		espionage.advance(75.0)
	espionage.run("reconDossier", 2, "", -1, 0.0)
	espionage.advance(35.0)
	territory.tick()
	cam_yaw = PI * 0.25
	for mode in ["diplomacy", "market", "intel", "territory"]:
		hud.toggle_panel(mode, true)
		if mode == "territory":
			hud.pick_territory(territory.describe(home + Vector3(20, 0, 10)))
			await capture_view("res://build/screen-%s.png" % mode, home + Vector3(-30, 0, 0), 230.0, 1.0, 30)
			await capture_view("res://build/screen-territory-island.png", Vector3(-60, 0, 0), 520.0, 1.2, 20)
		else:
			await capture_view("res://build/screen-%s.png" % mode, home, 120.0, 0.9, 20)
	hud.toggle_panel("")
	hud._show_side("")
	hud.ask("Crimson Empire proposes a trade pact ($40 every 10 s for both).", func(): pass, func(): pass)
	await capture_view("res://build/screen-letter.png", home, 120.0, 0.9, 15)
	menu.setup(self)
	menu.open_pause()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/screen-pause.png")
	menu.open_main()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/screen-main.png")
	menu.open_new_game()
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/screen-new.png")
	get_tree().quit()

## The army size asked for with --battle-bench=N, or 0 when it was not asked for.
func battle_bench_size(args: PackedStringArray) -> int:
	for a in args:
		if a.begins_with("--battle-bench"):
			return int(a.get_slice("=", 1)) if "=" in a else 24
	return 0

## A battle measured: two armies of `size` meet with all the shooting,
## explosions and smoke of a real fight, and the frame times are reported the
## way the benchmark reports them. This is where stalls show up.
func battle_bench(size: int) -> void:
	for i in range(20):
		await get_tree().process_frame
	var centre := land_point(start + Vector3(0, 0, -40), 30.0)
	var ours := spawn_group(centre + Vector3(-22, 0, 0), 0, size, maxi(1, size / 4))
	var theirs := spawn_group(centre + Vector3(22, 0, 0), 1, size, maxi(1, size / 4))
	diplomacy.declare_war(0, 1)
	order_move(ours, centre + Vector3(12, 0, 0), true)
	order_move(theirs, centre + Vector3(-12, 0, 0), true)
	cam_focus = centre
	cam_dist = 70.0
	cam_dist_target = 70.0
	cam_pitch = 0.7
	cam_yaw = PI * 0.25
	for i in range(90):
		await get_tree().process_frame  # let them close and start shooting
	var times: Array[float] = []
	var gpu := 0.0
	var calls := 0
	var rid := get_viewport().get_viewport_rid()
	for i in range(600):
		await get_tree().process_frame
		times.append(get_process_delta_time() * 1000.0)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0.0
	var stalls := 0
	for t in times:
		total += t
		if t > 100.0:
			stalls += 1
	var n := times.size()
	print("DOMINION battle bench %s" % JSON.stringify({
		"units": units.filter(func(u): return not u.dead).size(), "fps": snappedf(n / (total / 1000.0), 0.1),
		"p50": snappedf(sorted[n / 2], 0.1), "p95": snappedf(sorted[int(n * 0.95)], 0.1), "worst": snappedf(sorted[n - 1], 0.1),
		"stalls_over_100ms": stalls, "gpu": snappedf(gpu / n, 0.1), "calls": roundi(float(calls) / n),
	}))
	if profiling:
		print("PROFILE  " + profile_report())
	get_tree().quit()

## Every armed unit type fights the kind of target it is made for; each must
## fire its own weapon (bombs, missiles, rockets, torpedoes, shells, bullets)
## and hurt the target, without hurting its own side.
func combat_test(capture := false) -> void:
	for i in range(10):
		await get_tree().process_frame
	if ai and not ai.nations.is_empty():
		for n in ai.nations:
			n.next_attack = 99999.0  # rivals stay home while the test runs
		diplomacy.declare_war(0, 1)
	var sea = water_near(start, 320)
	var land := land_point(start + Vector3(0, 0, -60), 40.0)
	var out: Vector3 = (sea - start).normalized() if sea != null else Vector3.FORWARD
	var open_sea: Vector3 = sea + out * 40.0 if sea != null else land
	var cases := [
		# attacker, target, attacker at, target at, projectile kind that must fly
		["jet", "tank", land, land + Vector3(30, 0, 0), "missile"],
		["bomber", "tank", land, land + Vector3(20, 0, 0), "bomb"],
		["drone", "apc", land, land + Vector3(20, 0, 0), "missile"],
		["helicopter", "tank", land, land + Vector3(15, 0, 0), "rocket"],
		["gunship", "soldier", land, land + Vector3(15, 0, 0), "rocket"],
		["artillery", "tank", land, land + Vector3(28, 0, 0), "shell_arc"],
		["mlrs", "soldier", land, land + Vector3(34, 0, 0), "rocket"],
		["rocketSoldier", "tank", land, land + Vector3(12, 0, 0), "rocket"],
		["samLauncher", "helicopter", land, land + Vector3(20, 0, 0), "missile"],
		["aaVehicle", "helicopter", land, land + Vector3(16, 0, 0), ""],
		["tank", "apc", land, land + Vector3(14, 0, 0), ""],
		["apc", "soldier", land, land + Vector3(10, 0, 0), ""],
		["soldier", "soldier", land, land + Vector3(10, 0, 0), ""],
		["sniper", "soldier", land, land + Vector3(20, 0, 0), ""],
		["commando", "soldier", land, land + Vector3(8, 0, 0), ""],
		["submarine", "gunboat", open_sea, open_sea + out.rotated(Vector3.UP, 1.2) * 16.0, "torpedo"],
		["nuclearSub", "corvette", open_sea, open_sea + out.rotated(Vector3.UP, 1.2) * 18.0, "torpedo"],
		["destroyer", "gunboat", open_sea, open_sea + out.rotated(Vector3.UP, 1.2) * 22.0, ""],
		["corvette", "helicopter", open_sea, open_sea + out.rotated(Vector3.UP, 1.2) * 18.0, ""],
	]
	var failures := []
	Engine.time_scale = 3.0
	for c in cases:
		var attacker := spawn_unit(c[0], c[2], 0)
		var target := spawn_unit(c[1], c[3], 1)
		target.target = target.node.position  # the target holds still
		target.dmg = 0.0                      # and does not shoot back
		var hp_start: float = target.hp
		var fired_before: int = int(effects.launched.get(c[4], 0))
		var friends_hp: float = attacker.hp
		order_attack([attacker], target)
		var hurt := false
		var shot: bool = not capture or not c[0] in ["jet", "bomber", "helicopter", "gunship", "mlrs", "submarine", "samLauncher"]
		# Physics delta already includes time_scale; allow a full 30 game seconds for an approach.
		for f in range(int(30.0 / get_physics_process_delta_time())):
			await get_tree().physics_frame
			if not shot and effects._projectiles.size() > 0 and effects._projectiles.any(func(p): return p.t > 0.12):
				shot = true
				Engine.time_scale = 1.0
				var mid: Vector3 = (attacker.node.position + target.node.position) * 0.5
				cam_focus = mid
				cam_lift = 4.0 if attacker.get("fly", false) else 0.0
				cam_dist = 42.0
				cam_dist_target = 42.0
				cam_pitch = 0.3
				cam_yaw = atan2(target.node.position.x - attacker.node.position.x, target.node.position.z - attacker.node.position.z) + PI * 0.55
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/combat-%s.png" % c[0])
				cam_lift = 0.0
				Engine.time_scale = 3.0
			if target.hp < hp_start or target.dead:
				hurt = true
				if c[4] == "" or int(effects.launched.get(c[4], 0)) > fired_before:
					break
		var fired: bool = c[4] == "" or int(effects.launched.get(c[4], 0)) > fired_before
		var ok: bool = hurt and fired and attacker.hp >= friends_hp
		print("%-14s vs %-11s fired %-9s %s  target %d/%d  %s" % [c[0], c[1], c[4] if c[4] != "" else "gun", fired, int(maxf(target.hp, 0.0)), int(hp_start), "OK" if ok else "FAIL"])
		if not ok:
			failures.append(c[0])
		for u in [attacker, target]:
			u.dead = true
			u.node.visible = false
		for i in range(4):
			await get_tree().physics_frame
	Engine.time_scale = 1.0
	print("failed: %s" % str(failures))
	print("COMBAT_TEST %s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)

## Screenshots of the interface: the build list, a selected barracks with
## its training bars, a selected army, and the controls help.
func capture_ui() -> void:
	cam_focus = start
	cam_dist_target = 110.0
	cam_pitch = 0.85
	economy.res.money = 2500.0
	for i in range(240):  # let the picture studio render the cards
		await get_tree().process_frame
	await capture_view("res://build/ui-build.png", start, 110.0, 0.85, 20)
	var barracks = null
	for b in buildings:
		if b.owner == 0 and b.key == "barracks":
			barracks = b
	if barracks != null:
		select_building(barracks)
		queue_unit(barracks, "soldier")
		queue_unit(barracks, "sniper")
		for i in range(200):
			await get_tree().process_frame
		await capture_view("res://build/ui-barracks.png", barracks.root.position, 70.0, 0.8, 10)
	select_building(null)
	var army := units.filter(func(u): return u.owner == 0 and u.dmg > 0.0 and not u.get("fly", false))
	for u in army.slice(0, 8):
		u.selected = true
		u.ring.visible = true
	for i in range(120):
		await get_tree().process_frame
	await capture_view("res://build/ui-army.png", army[0].node.position, 60.0, 0.8, 10)
	hud.toggle_help()
	await capture_view("res://build/ui-help.png", start, 110.0, 0.85, 10)
	get_tree().quit()

## Moves the camera with keys (WASD and arrows) and a middle-button drag,
## the way a player would, and checks that the view actually moves.
func camera_test() -> void:
	for i in range(10):
		await get_tree().process_frame
	var results := {}
	for entry in [["D", KEY_D, Vector2(1, 0)], ["A", KEY_A, Vector2(-1, 0)], ["W", KEY_W, Vector2(0, 1)], ["Right arrow", KEY_RIGHT, Vector2(1, 0)], ["Left arrow", KEY_LEFT, Vector2(-1, 0)], ["Up arrow", KEY_UP, Vector2(0, 1)]]:
		cam_focus = start
		var before := cam_focus
		var key := InputEventKey.new()
		key.physical_keycode = entry[1]
		key.keycode = entry[1]
		key.pressed = true
		Input.parse_input_event(key)
		for i in range(20):
			await get_tree().process_frame
		key.pressed = false
		Input.parse_input_event(key)
		await get_tree().process_frame
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var moved := cam_focus - before
		results[entry[0]] = moved.dot(right) * entry[2].x + moved.dot(forward) * entry[2].y > 1.0
	cam_focus = start
	var before := cam_focus
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(400, 300)
	_unhandled_input(press)  # straight to the handler, as the engine delivers them
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-200, 0)
	motion.position = Vector2(200, 300)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	_unhandled_input(motion)
	press.pressed = false
	_unhandled_input(press)
	for i in range(3):
		await get_tree().process_frame
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	results["Middle-button drag"] = (cam_focus - before).dot(right) > 1.0
	cam_focus = Vector3(99999, 0, 99999)
	clamp_camera()
	# The minimap wedge must point where the camera actually looks: the far edge
	# of the wedge lies ahead of the near edge, whatever the yaw.
	var mini = hud.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == preload("res://scripts/minimap.gd"))
	if not mini.is_empty():
		cam_focus = start
		for yaw in [0.0, PI * 0.5, PI * 1.25, PI * 1.75]:
			cam_yaw = yaw
			update_camera(0.0)
			await get_tree().process_frame
			var wedge: PackedVector2Array = mini[0].camera_outline()
			var ahead := ((wedge[2] + wedge[3]) * 0.5 - (wedge[0] + wedge[1]) * 0.5).normalized()
			var look: Vector3 = -camera.global_transform.basis.z
			var want := Vector2(look.x, look.z).normalized()
			results["minimap wedge faces the camera at yaw %d" % roundi(rad_to_deg(yaw))] = ahead.dot(want) > 0.95
	results["Stays over the island"] = absf(cam_focus.x) <= float(map.mapSize) * 0.5
	print(results)
	var ok := results.values().all(func(v): return v)
	print("CAMERA_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Close-ups of every warship at sea and every aircraft in the air.
func capture_craft() -> void:
	var sea = water_near(start, 320)
	var out: Vector3 = (sea - start).normalized()
	var side := Vector3(-out.z, 0, out.x)
	var ships := ["destroyer", "corvette", "gunboat", "submarine", "nuclearSub"]
	var fleet := []
	for i in range(ships.size()):
		var at: Vector3 = sea + out * 26.0 + side * (i - 2) * 22.0
		var u := spawn_unit(ships[i], at, i % 4)
		u.heading = atan2(side.x, side.z)
		place_on_ground(u, at)
		fleet.append(u)
	cam_yaw = atan2(-out.x, -out.z) + 0.5
	await capture_view("res://build/craft-fleet.png", sea + out * 26.0, 70.0, 0.4, 60)
	for u in fleet:
		cam_yaw = u.heading + 2.1
		await capture_view("res://build/craft-%s.png" % u.key, u.node.position, u.length * 1.25, 0.3, 10)
	for key in ["jet", "bomber", "drone", "helicopter", "gunship"]:
		var u := spawn_unit(key, start + Vector3(0, 0, 30), 0)
		for i in range(3):
			await get_tree().physics_frame
		cam_lift = u.node.position.y - height_at(u.node.position.x, u.node.position.z)
		cam_yaw = u.heading + 2.3
		await capture_view("res://build/craft-%s.png" % key, u.node.position, 12.0 if key in ["drone"] else 17.0, 0.35, 2)
		cam_lift = 0.0
		u.node.visible = false
		u.dead = true
	get_tree().quit()

## Close-ups of every ground vehicle, and a tank of every nation.
func capture_vehicles() -> void:
	var spot := land_point(start, 50.0)
	var kinds := ["tank", "apc", "artillery", "aaVehicle", "mlrs", "samLauncher"]
	for i in range(kinds.size()):
		var u := spawn_unit(kinds[i], spot + Vector3((i % 3) * 20.0 - 20.0, 0, floori(i / 3.0) * 22.0 - 11.0), 0)
		u.heading = 0.5
		place_on_ground(u, u.node.position)
	for owner in range(1, 4):
		var u := spawn_unit("tank", spot + Vector3(owner * 11.0 - 22.0, 0, 34.0), owner)
		u.heading = 0.5
		place_on_ground(u, u.node.position)
	var mover := spawn_unit("apc", spot + Vector3(-20, 0, -20), 0)
	order_move([mover], spot + Vector3(60, 0, -20))
	cam_yaw = 0.9
	await capture_view("res://build/vehicles-all.png", spot + Vector3(0, 0, 6), 62.0, 0.42, 60)
	for i in range(kinds.size()):
		cam_yaw = 0.5 + 0.9
		await capture_view("res://build/vehicle-%s.png" % kinds[i], spot + Vector3((i % 3) * 20.0 - 20.0, 0, floori(i / 3.0) * 22.0 - 11.0), 13.0, 0.3, 12)
	cam_yaw = 0.5 - 2.4
	await capture_view("res://build/vehicle-tank-rear.png", spot + Vector3(-20, 0, -11), 12.0, 0.35, 8)
	cam_yaw = 0.5
	await capture_view("res://build/vehicles-nations.png", spot + Vector3(0, 0, 34), 26.0, 0.35, 8)
	get_tree().quit()

## Frames a point and saves a screenshot.
func capture_view(path: String, focus: Vector3, dist: float, pitch: float, frames: int) -> void:
	cam_focus = focus
	cam_dist = dist
	cam_dist_target = dist
	cam_pitch = pitch
	for i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

## Follows a missile in flight for a screenshot.
func capture_missile_flight(target: Vector3) -> void:
	var m: Dictionary = missiles.flying[0]
	cam_yaw = atan2(m.from.x - target.x, m.from.z - target.z) + 1.3
	for i in range(int(m.dur * 60.0 * 0.5)):
		await get_tree().physics_frame
		if missiles.flying.is_empty():
			return
		cam_focus = m.node.global_position
		cam_lift = m.node.global_position.y - maxf(height_at(cam_focus.x, cam_focus.z), float(map.seaLevel))
		cam_dist = 30.0
		cam_dist_target = 30.0
		cam_pitch = 0.25
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/systems-missile.png")
	cam_lift = 0.0

## Checks the supply rules: a new village is cut off until a road links it,
## breaks when the road is shelled, recovers when repaired, and a railway
## gives it the production bonus.
func logistics_test(capture: bool) -> void:
	economy.res.money = 5000.0
	economy.res.iron = 500.0
	var home: Vector3 = buildings[0].root.position
	var village = null
	for r in [95.0, 110.0, 125.0, 80.0]:
		for i in range(24):
			var a := i * TAU / 24.0
			var at: Vector3 = snap_to_hex(home + Vector3(cos(a), 0, sin(a)) * r)
			if site_problem("villageCenter", at, 0) == "":
				village = place_building("villageCenter", at, 0, true)
				close_navigation(village.root.position, DISTRICT_NAV_SIZE)
				break
		if village != null:
			break
	if village == null:
		print("LOGISTICS_TEST FAIL: no spot for a village")
		get_tree().quit(1)
		return
	var shop = place_building("barracks", village.root.position + Vector3(logistics.radius * 1.732, 0, 0), 0, true)
	refresh_streets()
	logistics.update_supply()
	var cut_off: bool = not village.supplied and not shop.supplied
	var route: Array = logistics.plan(logistics.world_hex(home), logistics.world_hex(village.root.position), 0, "road")
	var price: Dictionary = logistics.quote(route, "road", 0)
	var built: bool = logistics.build(route, "road", 0)
	var connected: bool = village.supplied and shop.supplied
	var mid: Vector3 = logistics.hex_center(route[route.size() / 2])
	for i in range(3):
		logistics.damage_at(mid, 4.0, 60.0)
	logistics.update_supply()
	var broken: bool = not village.supplied
	var repair: Dictionary = logistics.quote(route, "road", 0)
	logistics.build(route, "road", 0)
	var repaired: bool = village.supplied
	var rail_route: Array = logistics.plan(logistics.world_hex(home), logistics.world_hex(village.root.position), 0, "rail")
	var rail_ok: bool = rail_route.size() > 1 and logistics.build(rail_route, "rail", 0) and village.rail_supplied
	print("Route %d links for $%d; cut off before %s, supplied after %s, broken by shelling %s, repair $%d (vs $%d), repaired %s, railway bonus %s" % [route.size() - 1, price.money, cut_off, connected, broken, repair.money, price.money, repaired, rail_ok])
	if capture:
		# Shell one link again so the picture shows intact road, railway and a break.
		logistics.damage_at(logistics.hex_center(route[1]), 3.0, 400.0)
		cam_focus = (home + village.root.position) * 0.5
		cam_dist = 120.0
		cam_dist_target = 120.0
		cam_pitch = 0.95
		for i in range(90):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/logistics-0.png")
	var ok: bool = cut_off and built and connected and broken and repaired and repair.money < price.money and rail_ok
	print("LOGISTICS_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

# ---------------------------------------------------------------- placement

## Arms a missile: the next left click on the map is its target.
func begin_missile(key: String) -> void:
	cancel_placement()
	cancel_transport()
	if int(missiles.stock.get(key, 0)) <= 0:
		hud.notice("No %s in storage." % missiles.def_of(key).name)
		return
	missile_aim = key
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	hud.notice("%s armed: click a target (Shift keeps firing, right click cancels)." % missiles.def_of(key).name)

func cancel_missile() -> void:
	missile_aim = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func begin_placement(key: String) -> void:
	cancel_missile()
	cancel_transport()
	cancel_placement()
	var def: Dictionary = building_defs.get(key, {})
	if def.is_empty():
		return
	if not economy.can_afford(def.cost):
		hud.notice("Not enough %s" % economy.missing(def.cost))
		return
	placing = key
	ghost = Node3D.new()
	ghost.add_child(building_model(key, 0, 0))
	add_child(ghost)
	set_ghost_colour(Color(0.4, 1.0, 0.5, 0.45))

func cancel_placement() -> void:
	placing = ""
	if ghost:
		ghost.queue_free()
		ghost = null

func set_ghost_colour(color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	for mesh_instance in ghost.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_override = m
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## "" when the building can go here, otherwise the reason it cannot.
func placement_problem(key: String, at: Vector3) -> String:
	return site_problem(key, at, 0)

func site_problem(key: String, at: Vector3, owner: int) -> String:
	var def: Dictionary = building_defs[key]
	var footprint := footprint_of(key)
	var half := footprint * 0.5
	var lowest := INF
	var highest := -INF
	for corner in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half), Vector2.ZERO]:
		var h := height_at(at.x + corner.x, at.z + corner.y)
		lowest = minf(lowest, h)
		highest = maxf(highest, h)
	if not is_district(key) and lowest < float(map.seaLevel) + 1.0:
		return "Too close to the water"
	if not is_district(key) and highest - lowest > 3.5:
		return "Ground too steep"
	if is_district(key):
		# One district per hex, on land that is not too steep across the hex.
		var hex: Vector2i = logistics.world_hex(at)
		var taken = district_hex.get(hex)
		if taken != null and not taken.dead:
			return "This hex already holds %s" % taken.def.name
		var low := INF
		var high := -INF
		for k in range(6):
			var a := deg_to_rad(30.0 + 60.0 * k)
			var h := height_at(at.x + cos(a) * logistics.radius * 0.8, at.z + sin(a) * logistics.radius * 0.8)
			low = minf(low, h)
			high = maxf(high, h)
		if def.get("coastal", false):
			if water_near(at) == null or at.distance_to(water_near(at)) > logistics.radius * 2.2:
				return "Must be built on the coast"
			if height_at(at.x, at.z) < float(map.seaLevel) + 0.8:
				return "The centre of the hex must be dry land"
		elif low < float(map.seaLevel) + 0.8:
			return "Too close to the water"
		if high - low > 6.0:
			return "Hex too steep"
	var in_district := false
	for b in buildings:
		if b.dead:
			continue
		var gap := Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length()
		if not is_district(key) and gap < (footprint + b.footprint) * 0.55:
			return "Too close to %s" % b.def.name
		if b.owner == owner and b.built and gap < float(b.def.get("buildRadius", 0)):
			in_district = true
	# Land you hold is land you may build on, anywhere in it (territory.gd, hex
	# by hex, sea hexes off your coast included); another nation's land is not.
	var land_owner: int = territory.owner_at(at) if territory != null else -1
	if land_owner == owner:
		in_district = true
	elif land_owner >= 0 and land_owner != owner:
		return "Inside %s's land" % ("your" if land_owner == 0 else diplomacy.name_of(land_owner))
	if def.get("unique", false) and buildings.any(func(b): return b.owner == owner and b.key == key and not b.dead):
		return "Only one %s per nation" % def.name
	if def.get("settlement") != null:
		# A new settlement stands apart from every other one and outside rivals' land.
		for b in buildings:
			if b.dead or b.def.get("settlement") == null:
				continue
			var gap := Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length()
			if gap < 70.0:
				return "Too close to %s" % b.def.name
			if b.owner != owner and gap < float(b.def.get("buildRadius", 0)) + 20.0:
				return "Inside a rival's land"
	elif not in_district:
		return "Outside your territory"
	if def.get("onDeposit", false):
		var dep = deposit_near(at, 6.0)
		if dep == null or dep.extractor != null:
			return "Build on a free resource deposit"
		var kinds = def.get("depositTypes")
		if kinds != null and not dep.type in kinds:
			return "Needs a %s" % " or ".join(PackedStringArray(kinds.map(func(k): return map.depositTypes[k].name)))
		if kinds == null and dep.get("water", false):
			return "Offshore deposits need an Offshore Rig"
	for u in units:
		if not u.dead and Vector2(u.node.position.x - at.x, u.node.position.z - at.z).length() < footprint * 0.45:
			return "Units in the way"
	return ""

func update_placement() -> void:
	if placing == "" or ghost == null:
		return
	var point = ground_point(get_viewport().get_mouse_position())
	if point == null:
		return
	var at := snap_to_hex(point) if is_district(placing) else Vector3(snappedf(point.x, 2.0), 0, snappedf(point.z, 2.0))
	if building_defs[placing].get("onDeposit", false):
		var dep = deposit_near(at, 10.0)
		if dep != null:
			at = Vector3(dep.pos.x, 0, dep.pos.z)
	at.y = height_at(at.x, at.z)
	ghost.position = at
	var problem := placement_problem(placing, at)
	if problem != ghost_ok:
		ghost_ok = problem
		set_ghost_colour(Color(0.4, 1.0, 0.5, 0.45) if problem == "" else Color(1.0, 0.35, 0.3, 0.45))

func confirm_placement(keep: bool) -> void:
	var at := ghost.position
	var problem := placement_problem(placing, at)
	if problem != "":
		hud.notice(problem)
		return
	var key := placing
	# Trees or a natural resource on the site: the player decides first (site_clearing.gd).
	var found := SiteClearing.conflicts(self, key, at)
	if not (found.trees.is_empty() and found.deposits.is_empty()):
		SiteClearing.ask(self, key, at, found, func(): build_site(key, at))
		cancel_placement()
		return
	if build_site(key, at) and (not keep or not economy.can_afford(building_defs[key].cost)):
		cancel_placement()

## Pays for and lays out the player's building `key` at `at`, and sends a worker.
func build_site(key: String, at: Vector3) -> bool:
	var def: Dictionary = building_defs[key]
	if not economy.pay(def.cost):
		hud.notice("Not enough %s" % economy.missing(def.cost))
		return false
	var site := place_building(key, at, 0, false)
	close_navigation(site.root.position, DISTRICT_NAV_SIZE if is_district(key) else site.footprint)
	refresh_streets()
	call_worker(site)
	return true

func select_building(b) -> void:
	selected_building = b
	hud.show_building(b)
	if b == null:
		selection_marker.visible = false
		return
	var torus: TorusMesh = selection_marker.mesh
	torus.inner_radius = b.footprint * 0.72
	torus.outer_radius = torus.inner_radius + 0.25
	selection_marker.position = b.root.position + Vector3.UP * 0.3
	selection_marker.visible = true

func building_under(screen: Vector2):
	var best = null
	var best_d := INF
	for b in buildings:
		if b.dead:
			continue
		var centre: Vector3 = b.root.position + Vector3.UP * 2.0
		if camera.is_position_behind(centre):
			continue
		var edge := camera.unproject_position(centre + camera.global_basis.x * b.footprint * 0.5)
		var mid := camera.unproject_position(centre)
		var d := mid.distance_to(screen)
		if d < mid.distance_to(edge) and d < best_d:
			best_d = d
			best = b
	return best

# Fast-time check: place a farm and a barracks, let workers build them,
# train a soldier, and confirm the treasury and food moved as expected.
func economy_test(capture: bool) -> void:
	var money_before: float = economy.res.money
	var hq_pos: Vector3 = buildings[0].root.position
	var spots := [hq_pos + Vector3(-34, 0, 20), hq_pos + Vector3(-34, 0, -8), hq_pos + Vector3(-14, 0, 34), hq_pos + Vector3(14, 0, 36), hq_pos + Vector3(40, 0, 30)]
	var placed := []
	for key in ["farm", "barracks", "housing"]:
		for spot in spots:
			var at: Vector3 = snap_to_hex(spot)
			if placement_problem(key, at) == "":
				placing = key
				ghost = Node3D.new()
				add_child(ghost)
				ghost.position = at
				confirm_placement(false)
				placed.append(key)
				break
	print("Placed: %s, money %.0f -> %.0f" % [placed, money_before, economy.res.money])
	if not placed.has("barracks"):
		print("ECONOMY_TEST FAIL: could not place a barracks")
		get_tree().quit(1)
		return
	cam_focus = hq_pos + Vector3(-18, 0, 24)
	cam_dist = 70.0
	cam_dist_target = 70.0
	cam_pitch = 0.7
	Engine.time_scale = 1.0 if capture else 6.0
	var trained := false
	var elapsed := 0.0
	var shot := 0
	while elapsed < (60.0 if capture else 120.0):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var barracks = null
		for b in buildings:
			if b.key == "barracks" and b.owner == 0 and not b.built:
				barracks = b
			if b.key == "barracks" and b.owner == 0 and b.built and b.queue.is_empty() and not trained and b.get("asked", false) == false:
				b.asked = true
				queue_unit(b, "soldier")
				trained = true
		if capture and (shot == 0 and elapsed > 6.0 or shot == 1 and elapsed > 22.0 or shot == 2 and elapsed > 50.0):
			if shot == 1:
				select_building(buildings.filter(func(b): return b.key == "barracks" and b.owner == 0 and b.built)[0])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/economy-%d.png" % shot)
			shot += 1
		if not capture and trained and buildings.all(func(b): return b.built or b.owner != 0) and buildings.all(func(b): return b.queue.is_empty()):
			break
	Engine.time_scale = 1.0
	var all_built := buildings.all(func(b): return b.built or b.owner != 0)
	var soldiers := units.filter(func(u): return u.owner == 0 and u.key == "soldier" and not u.dead).size()
	print("Built all: %s, soldiers now %d, money %.0f, food %.0f (%+.2f/s), iron %.0f, army %d/%d" % [all_built, soldiers, economy.res.money, economy.res.food, economy.rates.food, economy.res.iron, economy.pop_used, economy.pop_cap])
	var ok := all_built and trained
	print("ECONOMY_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

# Fast-time check of the AI on hard: it must build, train, go to war and
# send an attack at the player's base; then every rival capital falls and the
# game must report victory.
func ai_test(capture: bool) -> void:
	Engine.time_scale = 1.0 if capture else 3.0
	var home: Vector3 = buildings[0].root.position
	var most_buildings := 0
	var most_units := 0
	var reached := false
	var elapsed := 0.0
	var shot := 0
	while elapsed < (70.0 if capture else 140.0):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		for n in ai.nations:
			most_buildings = maxi(most_buildings, buildings.filter(func(b): return b.owner == n.id and not b.dead).size())
			most_units = maxi(most_units, units.filter(func(u): return u.owner == n.id and not u.dead).size())
		for u in units:
			if u.owner > 0 and not u.dead and u.node.position.distance_to(home) < 90.0:
				reached = true
		if capture:
			var rival = ai.hq(1)
			if rival != null and (shot == 0 and elapsed > 30.0):
				cam_focus = rival.root.position
				cam_dist = 110.0
				cam_dist_target = 110.0
				cam_pitch = 0.8
			if shot == 0 and elapsed > 34.0 or shot == 1 and elapsed > 66.0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/ai-%d.png" % shot)
				shot += 1
				cam_focus = home + Vector3(0, 0, 20)
		if reached and most_buildings >= 5 and not capture:
			break
	var wars: int = ai.nations.filter(func(n): return diplomacy.at_war(0, n.id)).size()
	var ai_links: int = logistics.edges.values().filter(func(e): return e.owner > 0).size()
	var ai_villages: int = buildings.filter(func(b): return b.owner > 0 and b.key == "villageCenter").size()
	print("AI: most buildings %d, most units %d, nations at war %d, reached your base %s, villages %d, road links %d" % [most_buildings, most_units, wars, reached, ai_villages, ai_links])
	for b in buildings:
		if b.owner > 0 and b.key == "hq" and not b.dead:
			destroy_building(b)
	Engine.time_scale = 1.0
	print("After rival capitals fall: game_over=%s" % game_over)
	var ok: bool = most_buildings >= 5 and most_units >= 3 and wars > 0 and reached and game_over == "victory"
	print("AI_TEST %s" % ("PASS" if ok else "FAIL"))
	if not capture:
		get_tree().quit(0 if ok else 1)
	else:
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/ai-2.png")
		get_tree().quit()

# ---------------------------------------------------------------- aircraft and ships

# Ships sail straight for their goal over open water and turn along the coast
# when land is ahead; aircraft fly straight at their altitude. Jets cannot
# hover: when they have nothing to do they circle, and they make strafing
# passes rather than stopping over a target.
func move_craft(unit: Dictionary, delta: float) -> void:
	if unit.get("fly", false) and AirOperations.update(self, unit, delta):
		return
	var node: Node3D = unit.node
	var pos := node.position
	var goal = unit.target
	var fixed: bool = unit.key in FIXED_WING
	var servicing: bool = unit.get("air_state", "ready") != "ready"
	if servicing:
		goal = AirOperations.goal(unit)
	elif unit.enemy != null and (unit.target == null or unit.attack_move):
		var gap := flat_distance(unit, unit.enemy)
		goal = unit.enemy.node.position if (gap > unit.range * 0.8 or fixed) else null
		if fixed and unit.get("egress") == null and gap < 45.0:
			var approach: Vector3 = unit.enemy.node.position - pos
			if absf(angle_difference(unit.heading, atan2(approach.x, approach.z))) > 1.0:
				# A close target behind the wing needs a new approach, not an endless tight orbit.
				unit.egress = pos + Basis(Vector3.UP, unit.heading) * Vector3.BACK * 80.0
	if unit.get("naval",false) and goal != null:
		if naval_navigation == null:
			naval_navigation = preload("res://scripts/naval_navigation.gd").new()
			naval_navigation.setup(self)
		naval_navigation.move(unit,goal,delta)
		if unit.dust:
			unit.dust.emitting = unit.moving
		return
	if fixed and not servicing and unit.get("egress") != null:
		if node.position.distance_to(unit.egress) < 12.0:
			unit.egress = null
		else:
			goal = unit.egress
	if goal == null and fixed:
		var t: float = Time.get_ticks_msec() / 1000.0 * 0.35 + unit.phase
		goal = unit.orbit + Vector3(cos(t), 0, sin(t)) * 30.0
	if goal == null:
		unit.moving = false
		if unit.dust:
			unit.dust.emitting = false
		place_on_ground(unit, pos)
		return
	var to: Vector3 = goal - pos
	to.y = 0
	if to.length() < (6.0 if fixed else 1.0):
		if not fixed:
			unit.target = null
			unit.attack_move = false
			unit.moving = false
			if unit.dust:
				unit.dust.emitting = false
		else:
			unit.orbit = goal if unit.target != null else unit.orbit
			unit.target = null
			# Fly through the waypoint and turn back for another pass; never hover.
			to = Basis(Vector3.UP, unit.heading)*Vector3.BACK*80.0
			unit.egress = pos+to
		if not fixed:
			place_on_ground(unit, pos)
			return
	var want := atan2(to.x, to.z)
	var turn := minf(1.0, delta * (1.2 if fixed else (2.4 if unit.fly else 0.9)))
	var old: float = unit.heading
	unit.heading = lerp_angle(unit.heading, want, turn)
	if unit.naval:
		# Look ahead: if the bow would run aground, try turning either way.
		var ahead: Vector3 = pos + Basis(Vector3.UP, unit.heading) * Vector3.BACK * unit.length
		if not is_water(ahead):
			var turned := false
			for swing in [0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
				var h: float = unit.heading + swing
				if is_water(pos + Basis(Vector3.UP, h) * Vector3.BACK * unit.length):
					unit.heading = lerp_angle(unit.heading, h, minf(1.0, delta * 3.0))
					turned = true
					break
			if not turned:
				unit.target = null
				unit.moving = false
				place_on_ground(unit, pos)
				return
	var speed: float = unit.speed * (1.0 if fixed or unit.fly else 0.8)
	var step := Basis(Vector3.UP, unit.heading) * Vector3.BACK * minf(to.length() + (20.0 if fixed else 0.0), speed * delta)
	var next := pos + step
	if unit.naval and not is_water(next, DEEP * 0.6):
		unit.target = null
		unit.moving = false
		place_on_ground(unit, pos)
		return
	unit.bank = lerpf(unit.bank, clampf(angle_difference(old, unit.heading) / maxf(delta, 0.001) * -0.35, -0.7, 0.7), minf(1.0, delta * 3.0)) if unit.fly else 0.0
	unit.moving = true
	if unit.dust:
		unit.dust.emitting = true
	place_on_ground(unit, next)

## Aircraft, a ship and a gunboat duel over the coast: checks ships never leave
## the water, aircraft keep their altitude, and the damage table lets
## aircraft be hit only by weapons that can reach them.
func air_sea_test(capture: bool) -> void:
	var sea = water_near(start, 320)
	if sea == null:
		print("AIR_SEA_TEST FAIL: no water near the capital")
		get_tree().quit(1)
		return
	var destroyer := spawn_unit("destroyer", sea, 0)
	var heli := spawn_unit("helicopter", start + Vector3(0, 0, 20), 0)
	var jet := spawn_unit("jet", start + Vector3(10, 0, 30), 0)
	var enemy_sea = water_near(sea + (sea - start).normalized() * 70.0, 200)
	var gunboat := spawn_unit("gunboat", enemy_sea if enemy_sea != null else sea + Vector3(40, 0, 0), 1)
	var tank := spawn_unit("tank", start + Vector3(-30, 0, 40), 1)
	if ai and not ai.nations.is_empty():
		diplomacy.declare_war(0, 1)
	var rifle_on_heli := effectiveness(units.filter(func(u): return u.key == "soldier")[0], heli) if units.any(func(u): return u.key == "soldier") else 0.0
	var tank_on_heli := effectiveness(tank, heli)
	order_move([destroyer], gunboat.node.position, true)
	order_move([heli], tank.node.position, true)
	order_move([jet], tank.node.position, true)
	cam_focus = sea
	cam_dist = 80.0
	cam_dist_target = 80.0
	cam_pitch = 0.7
	var worst_ship_ground := -INF
	var lowest_heli := INF
	var elapsed := 0.0
	var shot := 0
	while elapsed < 60.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if not destroyer.dead:
			worst_ship_ground = maxf(worst_ship_ground, height_at(destroyer.node.position.x, destroyer.node.position.z))
		if not heli.dead:
			lowest_heli = minf(lowest_heli, heli.node.position.y - maxf(height_at(heli.node.position.x, heli.node.position.z), 0.0))
		if capture:
			cam_focus = cam_focus.lerp(destroyer.node.position if shot < 1 else heli.node.position, 0.05)
			if shot == 0 and elapsed > 9.0 or shot == 1 and elapsed > 18.0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://build/air-sea-%d.png" % shot)
				shot += 1
		if gunboat.dead and tank.dead and not capture:
			break
	print("ship stayed at sea %s (highest ground under it %.1f m), helicopter never below %.1f m, rifles vs aircraft x%.2f, tanks vs aircraft x%.2f, gunboat sunk %s, tank destroyed %s" % [worst_ship_ground < 0.0, worst_ship_ground, lowest_heli, rifle_on_heli, tank_on_heli, gunboat.dead, tank.dead])
	var ok: bool = worst_ship_ground < 0.0 and lowest_heli > 8.0 and tank_on_heli <= 0.01 and gunboat.dead and tank.dead
	print("AIR_SEA_TEST %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

# ---------------------------------------------------------------- combat

## Nations at war fight (diplomacy.gd decides who is at war with whom).
func hostile(a: int, b: int) -> bool:
	if a == b:
		return false
	if engagement != null and engagement.active(a,b):
		return true
	if ai == null or ai.nations.is_empty():
		return true  # sandbox scenes without AI: every other owner is an enemy
	return diplomacy.at_war(a, b)

# Ground distance; altitude does not count against weapon range.
func flat_distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(b.node.position.x - a.node.position.x, b.node.position.z - a.node.position.z).length()

# Distance to what can be hit: a building's walls, not its centre.
func gap_to(unit: Dictionary, target: Dictionary) -> float:
	var d := Vector2(target.node.position.x - unit.node.position.x, target.node.position.z - unit.node.position.z).length()
	return d - (target.footprint * 0.45 if target.get("is_building", false) else 0.0)

## What kind of target this is, for the damage table (entities.js targetClass).
func target_class(t: Dictionary) -> String:
	if t.get("is_building", false):
		return "building"
	if t.get("fly", false):
		return "air"
	if t.get("naval", false):
		return "naval"
	if t.key in infantry_keys:
		return "infantry"
	if t.key in armor_keys:
		return "armor"
	return "light"

## Damage multiplier of `attacker` against `target` (0 = cannot engage).
func effectiveness(attacker: Dictionary, target: Dictionary) -> float:
	# Small arms cannot penetrate heavy armour; dedicated anti-tank infantry can.
	if attacker.key in ["soldier","sniper","commando","worker"] and target_class(target) in ["armor","air","naval"]:
		return 0.0
	var profile: Dictionary = damage_profile.get(attacker.key, {})
	if profile.is_empty():
		return 0.0 if target.get("fly", false) else 1.0
	return float(profile.get(target_class(target), 0.0))

## Nearest hostile unit in range; buildings only when no unit is near.
func nearest_enemy(unit: Dictionary, radius: float) -> Variant:
	var best = null
	var best_d := radius
	# Ground units scan the buckets around them; aircraft and ships, which are
	# few and range far, still scan everyone.
	var candidates: Array = units
	if perf_opts and not (unit.get("fly", false) or unit.get("naval", false)):
		candidates = []
		var span := ceili(radius / GRID)
		var cx := floori(unit.node.position.x / GRID)
		var cz := floori(unit.node.position.z / GRID)
		for dz in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var bucket = grid.get(Vector2i(cx + dx, cz + dz))
				if bucket != null:
					candidates.append_array(bucket)
	for other in candidates:
		if other.dead or not hostile(unit.owner, other.owner) or effectiveness(unit, other) <= 0.01:
			continue
		var d: float = flat_distance(unit, other)
		if d < best_d:
			best_d = d
			best = other
	if best != null:
		return best
	for b in buildings:
		if b.dead or not hostile(unit.owner, b.owner) or effectiveness(unit, b) <= 0.01:
			continue
		var d := gap_to(unit, b)
		if d < best_d:
			best_d = d
			best = b
	return best

## Knocked out by an EMP.
func disabled(ent: Dictionary) -> bool:
	return ent.get("disabled_until", 0.0) > game_time

func update_combat(unit: Dictionary, delta: float) -> void:
	if unit.get("fly", false) and (unit.get("ammo", 0) <= 0 or unit.get("air_state", "ready") != "ready"):
		return
	if unit.dmg <= 0.0 or disabled(unit):
		return  # workers do not fight; EMP-struck machines are dead weight
	unit.reload -= delta
	unit.search -= delta
	# Decisions run ten times a second, each unit on its own tick of six;
	# aiming and firing below still run every frame.
	if unit.enemy != null and thinks(unit) and not Tactics.keep_target(self, unit, delta * THINK_EVERY):
		set_stance(unit)
	# Units on a plain move order ignore the enemy; idle or attack-moving units engage.
	# They look as far as their weapon reaches (artillery outranges its own eyes otherwise).
	if unit.enemy == null and unit.search <= 0.0:
		unit.search = 0.35
		if unit.target == null or unit.attack_move:
			unit.enemy = Tactics.pick_target(self, unit, maxf(unit.aggro, unit.range))
	if unit.enemy == null or unit.reload > 0.0:
		return
	var enemy: Dictionary = unit.enemy
	var d := gap_to(unit, enemy)
	if d > unit.range * 1.03:
		return  # a unit holding at the edge of range still has its shot
	if unit.vehicle and unit.turret != null:
		# The gun only fires once the turret has swung onto the target.
		var gap: Vector3 = enemy.node.position - unit.node.position
		if absf(angle_difference(unit.turret_yaw, atan2(gap.x, gap.z) - unit.heading)) > 0.12:
			return
	elif unit.moving and not (unit.get("fly", false) or unit.get("naval", false)):
		return  # infantry and turretless vehicles stop to shoot; aircraft and ships fire on the move
	var t_shot := clock()
	var fired := fire(unit, enemy)
	spent("    shots", t_shot)
	if fired:
		unit.reload = unit.cooldown * randf_range(0.85, 1.15)
		unit.last_fire = game_time
		shots_fired += 1

## The weapon a unit fires, when it is more than a rifle or a gun turret.
const WEAPONS := {"bomber": "bomb", "jet": "missile", "drone": "missile", "helicopter": "rockets", "gunship": "rockets",
	"submarine": "torpedo", "nuclearSub": "torpedo", "artillery": "shell_arc", "mlrs": "rocket_salvo",
	"samLauncher": "sam", "rocketSoldier": "rocket"}

## Fires at `enemy`; false when the weapon cannot be used yet (a bomber that
## is not over its target), so the reload is not spent.
func fire(unit: Dictionary, enemy: Dictionary) -> bool:
	if unit.get("fly", false):
		if unit.ammo <= 0 or unit.air_state != "ready":
			return false
		if unit.key in FIXED_WING:
			var direction: Vector3 = enemy.node.position-unit.node.position
			if absf(angle_difference(unit.heading,atan2(direction.x,direction.z))) > 0.65:
				return false
	var weapon: String = WEAPONS.get(unit.key, "")
	if weapon != "":
		var fired := fire_weapon(unit, enemy, weapon)
		if fired and unit.get("fly", false):
			AirOperations.consume(unit)
		return fired
	_fire_gun(unit, enemy)
	return true

## Bombs, missiles, rocket salvos, torpedoes and artillery shells: each a
## projectile that is seen to fly and explodes where it lands.
func fire_weapon(unit: Dictionary, enemy: Dictionary, weapon: String) -> bool:
	var target: Vector3 = enemy.node.position + Vector3.UP * (2.0 if enemy.get("is_building", false) else (0.0 if enemy.get("fly", false) else 0.8))
	var dir := Basis(Vector3.UP, unit.heading) * Vector3.BACK
	var from: Vector3 = unit.node.position + dir * 1.5 + Vector3.UP * (1.6 if not unit.get("fly", false) else -0.8)
	var dmg: float = unit.dmg * (2.5 if unit.get("fly",false) else 1.0)
	match weapon:
		"bomb":
			# Only over the target: the bomber lines up and releases a stick.
			var flat := Vector2(target.x - unit.node.position.x, target.z - unit.node.position.z).length()
			if flat > 11.0:
				return false
			for i in range(4):
				var spot := target + dir * (i - 1.5) * 3.2 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
				spot.y = maxf(height_at(spot.x, spot.z), float(map.seaLevel))
				effects.projectile("bomb", unit.node.position + Vector3.DOWN * 1.2 + dir * i * 0.8, spot, func(at): blast(unit, at, dmg * 0.55, 5.0, 1.6), i * 0.18)
		"missile":
			effects.projectile("missile", from, target, func(at): blast(unit, at, dmg, 3.0, 1.2), 0.0, enemy.node if enemy.get("fly", false) or enemy.vehicle else null)
		"sam":
			effects.projectile("missile", unit.node.position + Vector3.UP * 3.0, target, func(at): blast(unit, at, dmg, 3.5, 1.0), 0.0, enemy.node)
		"rockets":
			var n := 4 if unit.key == "gunship" else 2
			for i in range(n):
				var spot := target + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
				effects.projectile("rocket", from + Basis(Vector3.UP, unit.heading) * Vector3((i % 2 - 0.5) * 2.0, 0, 0), spot, func(at): blast(unit, at, dmg * 1.1 / n, 2.8, 0.7), i * 0.09)
		"rocket":
			effects.projectile("rocket", unit.node.position + Vector3.UP * 1.6 + dir * 0.6, target, func(at): blast(unit, at, dmg, 2.2, 0.7))
		"torpedo":
			if not enemy.get("naval", false):
				return false
			var water: Vector3 = Vector3(from.x, float(map.seaLevel) - 0.3, from.z) + dir * unit.length * 0.4
			var aim := Vector3(target.x, float(map.seaLevel) - 0.3, target.z)
			effects.projectile("torpedo", water, aim, func(at): blast(unit, at, dmg, 3.5, 1.4))
		"shell_arc":
			var landing := target + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			effects.muzzle_flash(unit.turret.global_position + dir * float(unit.get("muzzle", 4.0)) if unit.turret else from, true)
			effects.projectile("shell_arc", from + Vector3.UP * 1.5, landing, func(at): blast(unit, at, dmg, 4.5, 1.5))
		"rocket_salvo":
			for i in range(6):
				var spot := target + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
				spot.y = maxf(height_at(spot.x, spot.z), float(map.seaLevel))
				effects.projectile("rocket", from + Vector3.UP * 1.5, spot, func(at): blast(unit, at, dmg * 0.3, 3.5, 0.9), i * 0.12)
	return true

## An explosion that hurts every hostile unit and building within `radius`
## (full damage near the centre, less toward the edge) and wears down roads.
func blast(shooter: Dictionary, at: Vector3, dmg: float, radius: float, size: float) -> void:
	var ground := maxf(height_at(at.x, at.z), float(map.seaLevel))
	effects.explosion(at, size, at.y - ground < 1.5)
	logistics.damage_at(at, radius, dmg * 1.5)
	for b in buildings:
		if not b.dead and hostile(shooter.owner, b.owner) and Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length() < b.footprint * 0.62 + radius * 0.5:
			damage(b, dmg * effectiveness(shooter, b), shooter)
	for other in units:
		if other.dead or not hostile(shooter.owner, other.owner):
			continue
		var d: float = other.node.position.distance_to(at)
		if d < radius:
			damage(other, dmg * effectiveness(shooter, other) * (1.0 if d < radius * 0.5 else 0.45), shooter)
			Motion.shove(other, at, (1.0 - d / radius) * clampf(size, 0.6, 1.6))

func _fire_gun(unit: Dictionary, enemy: Dictionary) -> void:
	var aim: Vector3 = enemy.node.position + Vector3.UP * (3.0 if enemy.get("is_building", false) else (1.3 if enemy.vehicle else 1.2))
	if enemy.get("is_building", false):
		# Aim at the near wall rather than the middle of the roof.
		var toward: Vector3 = (unit.node.position - enemy.node.position)
		toward.y = 0
		aim += toward.normalized() * enemy.footprint * 0.4
	if unit.get("fly", false) or (unit.get("naval", false) and unit.turret == null):
		# Rockets and cannon from aircraft; torpedoes and missiles from boats.
		var dir := Basis(Vector3.UP, unit.heading) * Vector3.BACK
		var muzzle: Vector3 = unit.node.position + dir * 2.5 + Vector3.DOWN * (0.6 if unit.fly else 0.0)
		effects.muzzle_flash(muzzle, false)
		effects.shell(muzzle, aim + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), func(at: Vector3): shell_hit(unit, at))
	elif unit.vehicle:
		var dir := Basis(Vector3.UP, unit.heading + unit.turret_yaw) * Vector3.BACK
		var muzzle: Vector3 = unit.turret.global_position + dir * (2.4 if unit.get("naval", false) else float(unit.get("muzzle", 4.2))) + Vector3.UP * 0.4
		effects.muzzle_flash(muzzle, true)
		Motion.recoil(unit, 1.4 if unit.key in ["tank", "artillery"] else 0.7)
		# Long shots and moving targets miss more often; point-blank shots rarely do.
		var miss_chance := 0.12 + 0.3 * clampf(gap_to(unit, enemy) / maxf(unit.range, 1.0), 0.0, 1.0) + (0.15 if enemy.get("moving", false) else 0.0)
		var miss := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) if randf() < miss_chance else Vector3.ZERO
		var landing := aim + miss
		landing.y = maxf(landing.y if miss == Vector3.ZERO else height_at(landing.x, landing.z), height_at(landing.x, landing.z))
		effects.shell(muzzle, landing, func(at: Vector3): shell_hit(unit, at))
	else:
		var dir := Basis(Vector3.UP, unit.heading) * Vector3.BACK
		var muzzle: Vector3 = unit.node.position + Vector3.UP * 1.45 + dir * 0.75
		effects.muzzle_flash(muzzle, false)
		# Rifle fire: accurate close in, poor at the edge of range or at a running man.
		var reach := clampf(gap_to(unit, enemy) / maxf(unit.range, 1.0), 0.0, 1.0)
		var hit := randf() < (0.55 if enemy.vehicle else 0.7) * lerpf(1.1, 0.6, reach) * (0.75 if enemy.get("moving", false) else 1.0)
		var end: Vector3 = aim + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		if not hit:
			end = enemy.node.position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
			end.y = height_at(end.x, end.z)
		effects.tracer(muzzle, end)
		effects.impact(end)
		if hit:
			damage(enemy, unit.dmg * effectiveness(unit, enemy), unit)

# A shell explodes where it lands and hurts everything close by.
func shell_hit(shooter: Dictionary, at: Vector3) -> void:
	effects.explosion(at, 1.0, at.y - height_at(at.x, at.z) < 1.5)
	logistics.damage_at(at, 3.0, shooter.dmg * 1.5)
	for b in buildings:
		if not b.dead and hostile(shooter.owner, b.owner) and Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length() < b.footprint * 0.62:
			damage(b, shooter.dmg * effectiveness(shooter, b), shooter)
	for other in units:
		if other.dead or not hostile(shooter.owner, other.owner):
			continue  # splash does not hurt friends, or start wars with bystanders
		var d: float = other.node.position.distance_to(at)
		if d < 3.5:
			damage(other, shooter.dmg * effectiveness(shooter, other) * (1.0 if d < 1.8 else 0.45), shooter)
			Motion.shove(other, at, 1.0 - d / 3.5)

func damage(unit: Dictionary, amount: float, source: Dictionary) -> void:
	if unit.dead:
		return
	# Striking a nation at peace starts a war with it.
	if ai and source.owner == 0 and unit.owner > 0 and not (engagement != null and engagement.active(0,unit.owner)):
		ai.declare_war(unit.owner, true)
	if espionage:
		amount *= espionage.damage_mult(source.owner)  # a dead general blunts an army
	if research:
		amount *= research.damage_mult(source) * research.armor_mult(unit)
	unit.hp -= amount
	if amount > 0:
		unit.last_hit = game_time
	if unit.get("is_building", false):
		if amount > 0 and unit.hp > 0:
			show_building_damage(unit)
		if unit.hp <= 0.0:
			destroy_building(unit)
		return
	# Return fire, at an attacker this weapon can hurt and reach (a rifleman
	# shelled by a jet does not stand and stare at it).
	if unit.enemy == null and unit.dmg > 0.0 and not source.dead and (unit.target == null or unit.attack_move) 			and source.has("key") and effectiveness(unit, source) > 0.01 and (Tactics.reachable(unit, source) or gap_to(unit, source) <= unit.range):
		unit.enemy = source
	if unit.hp <= 0.0:
		kill(unit)

func show_building_damage(b: Dictionary) -> void:
	if not is_instance_valid(b.get("damage_label")):
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 40
		label.pixel_size = 0.025
		label.outline_size = 9
		label.position = Vector3(0,10.0,0)
		b.root.add_child(label)
		b.damage_label = label
	if b.get("damage_fade") != null and b.damage_fade.is_valid():
		b.damage_fade.kill()
	b.damage_label.text = "%s  %d%%" % [b.def.name,ceili(100.0*maxf(0,b.hp)/b.max_hp)]
	b.damage_label.modulate = Color("f1b86a")
	b.damage_fade = create_tween()
	b.damage_fade.tween_interval(3.0)
	b.damage_fade.tween_property(b.damage_label,"modulate:a",0.0,1.0)

var charred: StandardMaterial3D
func kill(unit: Dictionary) -> void:
	if is_instance_valid(unit.get("bombard_marker")):
		unit.bombard_marker.queue_free()
	unit.dead = true
	unit.selected = false
	unit.ring.visible = false
	unit.target = null
	unit.enemy = null
	unit.dead_time = 0.0
	if unit.get("fly", false) or unit.get("naval", false):
		effects.explosion(unit.node.position + Vector3.UP, 2.4, false)
		if unit.engine:
			unit.engine.stop()
		if unit.dust:
			unit.dust.emitting = false
		return
	if unit.vehicle:
		var at: Vector3 = unit.node.position
		effects.explosion(at + Vector3.UP, 3.2, true)
		effects.burn(at, 24.0)
		if not charred:
			charred = matte(Color("1b1916"), 1.0)
		for mesh_instance in unit.meshes:
			for i in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(i, charred)
		if unit.dust:
			unit.dust.emitting = false
		if unit.engine:
			unit.engine.stop()
		if unit.player:
			unit.player.pause()
		# Shards of armour fly out; half the time the ammunition cooks off and
		# throws the turret clear (it flies and tumbles under gravity in update_dead).
		effects.debris.scatter(at + Vector3.UP * 1.2, 9, 11.0, 0.45, Color(0.11, 0.1, 0.09), 0.55)
		if unit.turret != null and randf() < 0.5:
			var gt: Transform3D = unit.turret.global_transform
			unit.turret.top_level = true
			unit.turret.global_transform = gt
			unit.toss = {"node": unit.turret, "vel": Vector3(randf_range(-3.5, 3.5), randf_range(10.0, 14.0), randf_range(-3.5, 3.5)),
				"spin": Vector3(randf_range(-5, 5), randf_range(-3, 3), randf_range(-5, 5)), "rest": false}
		else:
			# The blast knocks the turret askew.
			unit.turret.basis = Basis(unit.turret.get_meta("axis"), unit.turret_yaw + randf_range(-0.6, 0.6)).rotated(Vector3.RIGHT, randf_range(-0.2, 0.2))
	elif unit.player and unit.get("death_clip", "") != "":
		unit.player.get_animation(unit.death_clip).loop_mode = Animation.LOOP_NONE
		unit.player.speed_scale = 1.0
		unit.player.play(unit.death_clip, 0.1)
	else:
		# No death clip: the body goes limp and topples, forwards or back.
		unit.fall = 1.0 if randf() < 0.5 else -1.0
		if unit.player:
			unit.player.speed_scale = 0.15

# A destroyed building collapses into charred rubble that burns for a while.
func destroy_building(b: Dictionary) -> void:
	b.dead = true
	b.queue.clear()
	var at: Vector3 = b.root.position
	effects.explosion(at + Vector3.UP * 3.0, 4.0, true)
	effects.burn(at, 40.0)
	logistics.damage_at(at, b.footprint * 0.7, 260.0)
	if not charred:
		charred = matte(Color("1b1916"), 1.0)
	for mesh_instance in b.model.find_children("*", "MeshInstance3D", true, false):
		mesh_instance.material_override = charred
	if b.model is MeshInstance3D:
		b.model.material_override = charred
	# The structure comes apart: masonry and beams are thrown and rain down.
	effects.debris.scatter(at + Vector3.UP * 3.0, 22, 13.0, 0.9, Color(0.36, 0.33, 0.3), 0.6)
	b.model.scale.y *= 0.28
	b.model.rotation.z = randf_range(-0.08, 0.08)
	if b.has("pad"):
		refresh_streets()
	if b.deposit != null:
		b.deposit.extractor = null
	if selected_building == b:
		select_building(null)
	for u in units:
		if u.build_site == b:
			u.build_site = null
	economy.recalculate()
	var name: String = map.nations[b.owner].name if b.owner < map.nations.size() else "Enemy"
	hud.notice("%s %s destroyed" % ["Your" if b.owner == 0 else name, b.def.name])
	if b.key == "hq":
		check_game_over()

func check_game_over() -> void:
	if game_over != "":
		return
	if not buildings.any(func(b): return b.owner == 0 and b.key == "hq" and not b.dead):
		game_over = "defeat"
		hud.show_end("DEFEAT", "Your capital has fallen.")
		return
	if ai and not ai.nations.is_empty() and not buildings.any(func(b): return b.owner > 0 and b.key == "hq" and not b.dead):
		game_over = "victory"
		hud.show_end("VICTORY", "Every rival capital has fallen.")

# Fallen soldiers lie for a while, then sink away; wrecks stay.
func update_dead(unit: Dictionary, delta: float, index: int) -> void:
	unit.dead_time += delta
	if unit.get("fly", false):
		# Spiral down trailing smoke, then burn where it hits.
		var node: Node3D = unit.node
		var floor_y := maxf(height_at(node.position.x, node.position.z), float(map.seaLevel))
		if node.position.y > floor_y + 0.5:
			node.position += (Basis(Vector3.UP, unit.heading) * Vector3.BACK) * delta * 8.0 + Vector3.DOWN * delta * 14.0
			node.rotate_object_local(Vector3.BACK, delta * 3.0)
			if randf() < delta * 10.0:
				effects.impact(node.position)
		elif not unit.get("crashed", false):
			unit.crashed = true
			effects.explosion(node.position, 2.6, floor_y > float(map.seaLevel))
			effects.burn(node.position, 16.0)
		if unit.dead_time > 14.0:
			node.queue_free()
			units.remove_at(index)
		return
	if unit.get("naval", false):
		# Settle by the stern and slip under.
		unit.node.position.y -= delta * 0.6
		unit.node.rotate_object_local(Vector3.RIGHT, delta * 0.05)
		if unit.dead_time > 12.0:
			unit.node.queue_free()
			units.remove_at(index)
		return
	if unit.vehicle:
		if unit.has("toss") and not unit.toss.rest:
			var toss: Dictionary = unit.toss
			var piece: Node3D = toss.node
			toss.vel.y -= 16.0 * delta
			piece.global_position += toss.vel * delta
			if toss.spin.length() > 0.01:
				piece.global_transform.basis = Basis(toss.spin.normalized(), toss.spin.length() * delta) * piece.global_transform.basis
			var floor_y := height_at(piece.global_position.x, piece.global_position.z) + 0.3
			if piece.global_position.y < floor_y and toss.vel.y < 0.0:
				piece.global_position.y = floor_y
				if toss.vel.y > -3.0:
					toss.rest = true  # it lands and stays, a marker of how the tank died
				else:
					toss.vel = Vector3(toss.vel.x * 0.5, -toss.vel.y * 0.3, toss.vel.z * 0.5)
					toss.spin *= 0.4
					effects.impact(piece.global_position)
					effects.debris.scatter(piece.global_position, 3, 4.0, 0.25, Color(0.27, 0.22, 0.16))
		return
	if unit.has("fling"):
		# Thrown by the blast that killed him: a ballistic arc, tumbling, then down.
		var v: Vector3 = unit.fling
		v.y -= 16.0 * delta
		var p: Vector3 = unit.node.position + v * delta
		var floor_y := height_at(p.x, p.z)
		if p.y <= floor_y and v.y < 0.0:
			p.y = floor_y
			unit.erase("fling")
			unit.model.basis = unit.fling_base  # lands and lies as he fell (the death pose takes over)
			effects.impact(p)
		else:
			unit.fling = v
			unit.model.rotate_object_local(Vector3.RIGHT, float(unit.get("fling_spin", 3.0)) * delta)
		unit.node.position = p
		return
	if unit.has("fall"):
		var k := minf(unit.dead_time / 0.6, 1.0)
		unit.model.rotation.x = unit.fall * PI * 0.47 * k * k
		if k >= 1.0 and unit.player and unit.player.is_playing():
			unit.player.pause()
	if unit.dead_time > 7.0:
		unit.node.position.y -= delta * 0.35
	if unit.dead_time > 11.0:
		unit.node.queue_free()
		units.remove_at(index)

func set_stance(unit: Dictionary) -> void:
	if unit.vehicle or unit.player == null or unit.moving:
		return
	var want: String = unit.shoot_clip if unit.enemy != null and unit.shoot_clip != "" else unit.idle_clip
	if want != "" and unit.clip != want:
		unit.player.play(want, 0.2)
		unit.player.speed_scale = 1.0
		unit.clip = want

func _on_shake(strength: float, at: Vector3) -> void:
	var d := at.distance_to(Vector3(cam_focus.x, at.y, cam_focus.z))
	if d < 110.0:
		shake_strength = maxf(shake_strength, strength * (1.0 - d / 110.0))

# ---------------------------------------------------------------- battle demo

# A land point about `reach` metres from `from`, reachable without crossing water.
func land_point(from: Vector3, reach: float) -> Vector3:
	var best := from + Vector3(0, 0, reach)
	var best_score := -1
	for i in range(16):
		var a := i * TAU / 16.0
		var score := 0
		for k in range(1, 11):
			var p := from + Vector3(cos(a), 0, sin(a)) * reach * k / 10.0
			if height_at(p.x, p.z) > 1.5 and normal_at(p.x, p.z).y > 0.9:
				score += 1
		if score > best_score:
			best_score = score
			best = from + Vector3(cos(a), 0, sin(a)) * reach
	return best

func spawn_group(centre: Vector3, owner: int, soldiers: int, tanks: int) -> Array:
	var group := []
	var facing := atan2(start.x - centre.x, start.z - centre.z)
	for i in range(soldiers):
		group.append(spawn_unit("soldier", centre + Vector3((i % 6 - 2.5) * 2.6, 0, floori(i / 6.0) * 2.6), owner))
	for i in range(tanks):
		group.append(spawn_unit("tank", centre + Vector3((i - (tanks - 1) / 2.0) * 7.0, 0, -7.0), owner))
	for u in group:
		u.heading = facing
		place_on_ground(u, u.node.position)
	return group

func start_battle() -> void:
	if battle_started:
		return
	battle_started = true
	if ai and not ai.nations.is_empty():
		ai.declare_war(1, false)  # the demo enemy fights for nation 1
	var front := land_point(start, 80.0)
	var ours := spawn_group(start + (front - start) * 0.15, 0, 12, 2)
	var theirs := spawn_group(front, 1, 14, 3)
	for u in units:
		if u.owner == 0 and not u.dead:
			ours.append(u)
	order_move(ours, front, true)
	order_move(theirs, start + (front - start) * 0.2, true)

func battle_centre() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for u in units:
		if not u.dead and u.node.position.distance_to(start) < 140.0:
			sum += u.node.position
			count += 1
	return sum / maxi(count, 1)

func capture_battle() -> void:
	# The master mix is recorded too, so the soundtrack can be checked and heard.
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recorder)
	recorder.set_recording_active(true)
	start_battle()
	cam_pitch = 0.62
	cam_dist = 62.0
	cam_dist_target = 62.0
	var shots := [4.0, 8.0, 12.0, 17.0, 24.0]
	var elapsed := 0.0
	var index := 0
	DirAccess.make_dir_recursive_absolute("res://build")
	while index < shots.size():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		cam_focus = cam_focus.lerp(battle_centre(), 0.08)
		if elapsed >= shots[index]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/battle-%d.png" % index)
			index += 1
	recorder.set_recording_active(false)
	var clip := recorder.get_recording()
	if clip:
		clip.save_to_wav("res://build/battle-audio.wav")
	get_tree().quit()

# ---------------------------------------------------------------- camera and input

# Same orbit as updateCamera() in js/main.js.
func update_camera(delta: float) -> void:
	cam_dist += (cam_dist_target - cam_dist) * (1.0 - exp(-delta * 12.0))
	var ground := maxf(height_at(cam_focus.x, cam_focus.z), float(map.seaLevel))
	var focus := Vector3(cam_focus.x, ground + cam_lift, cam_focus.z)
	camera.global_position = focus + Vector3(sin(cam_yaw) * cam_dist * cos(cam_pitch), cam_dist * sin(cam_pitch), cos(cam_yaw) * cam_dist * cos(cam_pitch))
	camera.look_at(focus)
	# Sound: the listener stands at the focus; surf plays from the nearest shore.
	if focus.distance_to(coast_focus) > 20.0:
		coast_focus = focus
		coast_point = nearest_shore(focus)
	audio.follow(focus, camera, coast_point)
	if shake_strength > 0.01:
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength *= exp(-delta * 7.0)

func _process(delta: float) -> void:
	if camera == null:
		return  # still loading (_ready awaits the noise texture and navigation)
	update_placement()
	update_transport()
	if bench_phase >= 0:
		benchmark_frame(delta)
	else:
		pan_camera(delta)
	update_camera(delta)
	fps_time += delta
	fps_frames += 1
	if fps_time >= 1.0 and bench_phase < 0:
		var alive := [0, 0]
		for u in units:
			if not u.dead:
				alive[mini(u.owner, 1)] += 1
		status.text = "Army %d  vs  enemy %d  |  %d FPS  |  %s" % [alive[0], alive[1], roundi(fps_frames / fps_time), RenderingServer.get_video_adapter_name()]
		fps_time = 0
		fps_frames = 0

# Moves the camera the ways strategy players expect: WASD or the arrow keys,
# pushing the mouse against the edge of the screen, dragging with the middle
# mouse button (see _unhandled_input), Q/E to turn, R/F to tilt. Keys are read
# by their position, so they work with any keyboard layout (Hebrew included).
func pan_camera(delta: float) -> void:
	var pan := cam_dist * 0.9 * delta
	var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1.0
	# Edge scrolling, only while the game window has the focus and nothing is
	# being dragged.
	if edge_scroll and not dragging and not middle_drag and DisplayServer.window_is_focused():
		var mouse := get_viewport().get_mouse_position()
		var view := get_viewport().get_visible_rect().size
		var edge := 8.0
		if mouse.x >= 0.0 and mouse.y >= 0.0 and mouse.x <= view.x and mouse.y <= view.y:
			if mouse.x < edge: move.x -= 1.0
			elif mouse.x > view.x - edge: move.x += 1.0
			if mouse.y < edge: move.y += 1.0
			elif mouse.y > view.y - edge: move.y -= 1.0
	if move != Vector2.ZERO:
		cam_focus += (right * move.x + forward * move.y).normalized() * pan * (1.6 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	if Input.is_physical_key_pressed(KEY_Q): cam_yaw += delta * 1.6
	if Input.is_physical_key_pressed(KEY_E): cam_yaw -= delta * 1.6
	if Input.is_physical_key_pressed(KEY_R) or Input.is_physical_key_pressed(KEY_PAGEUP): cam_pitch = minf(1.25, cam_pitch + delta * 1.1)
	if Input.is_physical_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_PAGEDOWN): cam_pitch = maxf(0.3, cam_pitch - delta * 1.1)
	clamp_camera()

## Keeps the view over the island.
func clamp_camera() -> void:
	var half := float(map.mapSize) * 0.5
	cam_focus.x = clampf(cam_focus.x, -half, half)
	cam_focus.z = clampf(cam_focus.z, -half, half)

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
			# Zoom in toward the point under the cursor, as in most strategy games.
			var point = ground_point(event.position)
			if point != null and cam_dist_target > 18.0:
				cam_focus = cam_focus.lerp(Vector3(point.x, cam_focus.y, point.z), 0.12)
				clamp_camera()
			cam_dist_target = maxf(18.0, cam_dist_target * 0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist_target = minf(520.0, cam_dist_target / 0.88)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			middle_drag = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and missile_aim != "":
			if event.pressed:
				var point = ground_point(event.position)
				if point != null:
					var key := missile_aim
					engagement.authorize_area(point,float(missiles.def_of(key).radius),func():hud.notice(missiles.launch(key,point)))
					if int(missiles.stock.get(missile_aim, 0)) <= 0 or not event.shift_pressed:
						cancel_missile()
		elif event.button_index == MOUSE_BUTTON_RIGHT and missile_aim != "":
			if event.pressed:
				cancel_missile()
		elif event.button_index == MOUSE_BUTTON_LEFT and transport_kind != "":
			if event.pressed:
				transport_click(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and transport_kind != "":
			if event.pressed:
				cancel_transport()
		elif event.button_index == MOUSE_BUTTON_LEFT and placing != "":
			if event.pressed:
				confirm_placement(event.shift_pressed)  # Shift keeps placing
		elif event.button_index == MOUSE_BUTTON_RIGHT and placing != "":
			if event.pressed:
				cancel_placement()
		elif event.button_index == MOUSE_BUTTON_LEFT and occupation != null and occupation.placing:
			if event.pressed:
				var point = ground_point(event.position)
				if point != null:
					occupation.place(point, units.filter(func(u): return u.selected and not u.dead and u.owner == 0))
		elif event.button_index == MOUSE_BUTTON_LEFT and order_mode != "":
			if event.pressed:
				var point = ground_point(event.position)
				if point != null:
					var selected := units.filter(func(u): return u.selected and not u.dead and u.owner==0)
					if order_mode == "bombard":
						request_bombard(selected,point)
					else:
						passage.check_order(selected, point, func(): order_move(selected,point,true))
			else:
				order_mode = ""
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
			else:
				dragging = false
				selection_box.hide()
				var rect := Rect2(drag_start, event.position - drag_start).abs()
				var click := rect.size.length() < 8
				# A click hits a unit anywhere on its outline on screen (picking.gd),
				# not only near its centre: a whole submarine or destroyer is clickable.
				var own: Array = units.filter(func(u): return u.owner == 0 and not u.dead)
				var hit = Picking.pick(camera, own, event.position) if click else null
				var closest: Dictionary = hit if hit != null else {}
				for unit in own:
					if not event.shift_pressed:
						unit.selected = false
					if not click and rect.has_point(Picking.screen_centre(camera, unit)):
						unit.selected = true
				if not closest.is_empty():
					closest.selected = true
				# A click on empty ground or a building selects that building.
				if click and closest.is_empty():
					select_building(building_under(event.position))
					if hud.side_mode == "territory":
						var point = ground_point(event.position)
						if point != null:
							hud.pick_territory(territory.describe(point))  # who holds this land
				elif not closest.is_empty() or not click:
					select_building(null)
				for unit in units:
					unit.ring.visible = unit.selected
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if order_mode!="":
				order_mode = ""
				return
			var selected := units.filter(func(u): return u.selected and not u.dead)
			var target = enemy_under(event.position)
			if event.alt_pressed or Input.is_physical_key_pressed(KEY_ALT):
				var point = ground_point(event.position)
				if point != null:
					request_bombard(selected,point)
			elif event.ctrl_pressed or Input.is_physical_key_pressed(KEY_CTRL):
				var point = ground_point(event.position)
				if point != null:
					passage.check_order(selected, point, func(): order_move(selected,point,true))
			elif target != null:
				selected = selected.filter(func(u):return u.dmg>0 and effectiveness(u,target)>0.01)
				if not selected.is_empty():
					engagement.authorize(target.owner,func():
						if not target.dead:
							order_attack(selected.filter(func(u):return not u.dead),target))
			else:
				var point = ground_point(event.position)
				if point != null:
					var attack: bool = event.ctrl_pressed or Input.is_physical_key_pressed(KEY_CTRL)
					# Borders are checked first (passage.gd): foreign land needs leave.
					passage.check_order(selected, point, func(): order_move(selected, point, attack))
	elif event is InputEventMouseMotion and middle_drag:
		# The ground follows the mouse: drag it the way you would drag a map.
		var forward := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var scale := cam_dist * 0.0021
		cam_focus -= (right * event.relative.x - forward * event.relative.y) * scale
		clamp_camera()
	elif event is InputEventMouseMotion and dragging:
		var rect := Rect2(drag_start, event.position - drag_start).abs()
		selection_box.position = rect.position
		selection_box.size = rect.size
		selection_box.show()

func enemy_under(screen: Vector2) -> Variant:
	var best = Picking.pick(camera, units.filter(func(u): return not u.dead and u.owner != 0), screen)
	if best == null:
		var b = building_under(screen)
		if b != null and b.owner != 0:
			return b
	return best

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and order_mode!="":
		order_mode = ""
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_B:
		start_battle()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		hud.toggle_diplomacy()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		hud.toggle_panel("market")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		hud.toggle_panel("intel")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		hud.toggle_panel("territory")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_O and occupation != null:
		occupation.begin_zone()  # the next click marks an operational zone
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Y:
		hud.toggle_research()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		hud.toggle_help()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		saves.save("quicksave")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		saves.load_slot("quicksave")
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		# Esc first cancels what is in progress; with nothing to cancel it pauses.
		if placing == "" and transport_kind == "" and missile_aim == "" and selected_building == null and menu != null and menu._root != null:
			menu.open_pause()
		cancel_missile()
		cancel_transport()
		cancel_placement()
		select_building(null)
		if occupation != null:
			occupation.cancel()

func make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	info_layer = layer
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 58)  # below the resource strip
	panel.visible = "--debug-hud" in OS.get_cmdline_user_args()  # the player's HUD is hud.gd
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
	hint.text = "Drag/click: select   Right click: move / attack   Ctrl+right: attack-move   B: battle demo\nWASD: pan   Q/E: rotate   R/F: tilt   Wheel: zoom"
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
	if profiling:
		print("PROFILE  " + profile_report())
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

func nearest_shore(from: Vector3) -> Vector3:
	for radius in range(0, 260, 10):
		for i in range(16):
			var a := i * TAU / 16.0
			var p := from + Vector3(cos(a), 0, sin(a)) * radius
			if height_at(p.x, p.z) < 0.0:
				return Vector3(p.x, 0.5, p.z)
			if radius == 0:
				break
	return from + Vector3(0, -1000, 0)  # far inland: surf out of earshot

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
		["no unit animation", func(on):
			for u in units:
				if u.player != null:
					u.player.active = on],
		["no unit shadows", func(on):
			for u in units:
				for m in u.node.find_children("*", "MeshInstance3D", true, false):
					m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF],
		["no health bars", func(on):
			if health_overlay != null: health_overlay.visible = on],
		["no effects", func(on): effects.visible = on],
		["no buildings", func(on):
			for b in buildings: b.root.visible = on],
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
