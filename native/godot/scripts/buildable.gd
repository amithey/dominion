extends Node
## Where you can and cannot build, shown on the land itself, as a 4X game does.
##
## Always: ground too steep for a district (the same test as site_problem:
## more than 6 m of rise across a hex) is painted as grey rock by
## terrain.gdshader, from a height texture made here, so a hill you cannot
## build on looks like one.
##
## While a district is being placed: every hex near the view is tested with
## world.site_problem() for that building and tinted in the terrain: green
## where it can go, red hatching where the land itself forbids it (too steep,
## too close to the water), and a grey veil where something else does
## (outside your land, already built on, inland for a harbour). The test runs a
## few dozen hexes per frame, so placing never stalls the game.

const PER_FRAME := 40          # hexes tested per frame while placing
const REACH := 190.0           # metres round the view that are tested

var world: Node
var _key := ""
var _img: Image
var _tex: ImageTexture
var _queue: Array[int] = []
var _dirty := false
var _since_upload := 0

func setup(world_node: Node) -> void:
	world = world_node
	var mat := _terrain_material()
	if mat == null:
		return
	var n: int = world.grid_size
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RF, world.heights.to_byte_array())
	mat.set_shader_parameter("height_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("height_grid", Vector4(world.grid_origin.x, world.grid_origin.y, world.grid_step, float(n)))

func _terrain_material() -> ShaderMaterial:
	if world == null or world.terrain_node == null:
		return null
	return world.terrain_node.material_override as ShaderMaterial

func _territory_ready() -> bool:
	return world.territory != null and world.territory.cols > 0

## Starts or stops the overlay for building `key` ("" stops it).
func show_for(key: String) -> void:
	var mat := _terrain_material()
	if mat == null or not _territory_ready():
		return
	var on: bool = key != "" and world.is_district(key)
	_key = key if on else ""
	mat.set_shader_parameter("show_build", on)
	if not on:
		_queue.clear()
		return
	var t = world.territory
	_img = Image.create(t.cols, t.rows, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	mat.set_shader_parameter("build_tex", _tex)
	_queue.clear()
	_refill()

# Every hex within reach of the view, nearest first.
func _refill() -> void:
	var t = world.territory
	var focus: Vector3 = world.cam_focus
	var near := []
	for i in range(t.cols * t.rows):
		var c: Vector3 = t.center(i)
		var d := Vector2(c.x - focus.x, c.z - focus.z).length()
		if d < REACH:
			near.append([d, i])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for pair in near:
		_queue.append(pair[1])

func _process(_delta: float) -> void:
	if _key == "":
		return
	if world.placing != _key:
		show_for(world.placing)  # placement ended or switched building
		return
	if _queue.is_empty():
		_refill()  # keep checking: units move, land changes hands
	var t = world.territory
	var sea := float(world.map.seaLevel)
	for n in range(mini(PER_FRAME, _queue.size())):
		var i: int = _queue.pop_front()
		var c: Vector3 = t.center(i)
		c.y = world.height_at(c.x, c.z)
		var colour := Color(0, 0, 0, 0)  # open sea: no mark
		if c.y > sea - 0.5:
			var problem: String = world.site_problem(_key, c, 0)
			if problem == "":
				colour = Color(0, 1, 0, 1)
			elif _is_land_problem(problem):
				colour = Color(1, 0, 0, 1)
			else:
				colour = Color(0, 0, 1, 1)
		var col: int = i % t.cols
		var row: int = i / t.cols
		if _img.get_pixel(col, row) != colour:
			_img.set_pixel(col, row, colour)
			_dirty = true
	_since_upload += 1
	if _dirty and _since_upload >= 4:
		_tex.update(_img)
		_dirty = false
		_since_upload = 0

# Too steep or too near the water: the land itself says no (red hatching).
# An inland hex for a harbour is only greyed, so the coast stands out.
func _is_land_problem(problem: String) -> bool:
	for word in ["steep", "too close to the water", "dry land"]:
		if problem.to_lower().contains(word):
			return true
	return false

## --capture-build: the land round the capital with and without a district
## being placed, and the steepest hills near it (build/buildable-*.png).
static func capture(w: Node) -> void:
	for i in range(40):
		await w.get_tree().process_frame
	# The steepest ground within 170 m of the capital.
	var hill: Vector3 = w.start
	var worst := 0.0
	for x in range(-170, 171, 6):
		for z in range(-170, 171, 6):
			var p: Vector3 = w.start + Vector3(x, 0, z)
			var rise := absf(w.height_at(p.x + 8, p.z) - w.height_at(p.x - 8, p.z)) + absf(w.height_at(p.x, p.z + 8) - w.height_at(p.x, p.z - 8))
			if rise > worst and w.height_at(p.x, p.z) > 1.0:
				worst = rise
				hill = p
	w.economy.res.money = 1e6
	for key in w.economy.res:
		w.economy.res[key] = maxf(float(w.economy.res[key]), 1e5)
	var shots := [["city", w.start, 150.0, 0.95, 0.3, ""], ["city-placing", w.start, 150.0, 0.95, 0.3, "housing"],
		["hill", hill, 110.0, 0.7, 0.9, ""], ["hill-placing", hill, 110.0, 0.7, 0.9, "housing"], ["coast-placing", w.start, 260.0, 1.2, 0.0, "port"]]
	for shot in shots:
		w.cancel_placement()
		w.cam_focus = shot[1]
		w.cam_dist = shot[2]
		w.cam_dist_target = shot[2]
		w.cam_pitch = shot[3]
		w.cam_yaw = shot[4]
		if shot[5] != "":
			w.begin_placement(shot[5])
		for f in range(70):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/buildable-%s.png" % shot[0])
	w.cancel_placement()
	w.get_tree().quit()
