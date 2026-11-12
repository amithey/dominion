extends SceneTree
## Films the explosion looks (scripts/blasts.gd): each look is set off on open ground (a flak burst in the air, a torpedo
## at sea) and photographed from the game's own camera angle at fixed moments after the burst. Writes
## build/explosions/<look>.png (one strip per look, left to right in time) and build/explosions-sheet.png (all of them).
## Run windowed (the GPU draws the films):
##   Godot --path native/godot -s res://tools/explosion-view.gd -- [look ...] [--times=0.05,0.2,0.5,1.0,2.0,4.0] [--low]
## A look that is not listed in SHOTS is filmed at size 1 on the ground.

## look -> [size, where ("ground", "air", "sea"), strategic radius (0: a tactical burst)]
const SHOTS := {
	"grenade": [0.5, "ground", 0.0],
	"shell": [1.0, "ground", 0.0],
	"heat": [0.8, "ground", 0.0],
	"mortar": [0.8, "ground", 0.0],
	"artillery": [1.5, "ground", 0.0],
	"rocket": [0.9, "ground", 0.0],
	"missile": [1.2, "ground", 0.0],
	"bomb": [1.6, "ground", 0.0],
	"railgun": [1.2, "ground", 0.0],
	"thermobaric": [1.4, "ground", 0.0],
	"flak": [1.0, "air", 0.0],
	"torpedo": [1.4, "sea", 0.0],
	"cluster": [3.3, "ground", 15.0],
	"penetrator": [3.3, "ground", 15.0],
	"aerosol": [3.3, "ground", 15.0],
	"nuclear": [8.8, "ground", 40.0],
	"classic": [1.5, "ground", 0.0],
}
const CELL := Vector2i(400, 225)

var w: Node
var cam: Camera3D

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var looks: Array = []
	var times: Array = [0.05, 0.2, 0.5, 1.0, 2.0, 4.0]
	var low := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--times="):
			times = Array(a.get_slice("=", 1).split(",")).map(func(t): return float(t))
		elif a == "--low":
			low = true
		else:
			looks.append(a)
	if looks.is_empty():
		looks = SHOTS.keys()
	change_scene_to_file("res://world.tscn")
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	w.start_match("easy")
	w.menu._root.hide()
	w.hud.hide()
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	if low:
		w.quality = "low"
	for u in w.units:
		if not u.dead: w.kill(u)
	# Open, level ground away from the towns, a fresh patch for each look (so no look is filmed in another's smoke or
	# on its scorch mark), and open sea.
	var spots: Array = []
	for tries in range(4000):
		if spots.size() >= looks.size():
			break
		var p: Vector3 = w.start + Vector3(randf_range(-260, 260), 0, randf_range(-260, 260))
		if w.height_at(p.x, p.z) < 2.0 or w.normal_at(p.x, p.z).y < 0.97 or not w.open_ground(p):
			continue
		var clear := INF
		for b in w.buildings:
			if not b.dead: clear = minf(clear, b.root.position.distance_to(p))
		for q in spots:
			clear = minf(clear, Vector3(q).distance_to(p) * 0.6)
		if clear > 30.0:
			p.y = w.height_at(p.x, p.z)
			spots.append(p)
	while spots.size() < looks.size():
		spots.append(spots[spots.size() % maxi(spots.size(), 1)] if not spots.is_empty() else w.start)
	var sea: Vector3 = w.water_near(w.start, 220) if w.water_near(w.start, 220) != null else w.start
	sea.y = float(w.map.seaLevel)
	w.effects.process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.fov = 45
	cam.far = 4000.0
	w.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute("res://build/explosions")
	var sheet := Image.create(CELL.x * times.size(), CELL.y * looks.size(), false, Image.FORMAT_RGBA8)
	for li in range(looks.size()):
		var look: String = looks[li]
		var shot: Array = SHOTS.get(look, [1.0, "ground", 0.0])
		var size: float = shot[0]
		var spot: Vector3 = spots[li]
		var at: Vector3 = spot
		if shot[1] == "air":
			at = spot + Vector3.UP * 18.0
		elif shot[1] == "sea":
			at = sea
		# The game's camera: high and to one side, far enough back that the whole burst and its smoke are in frame.
		var g := pow(size, 0.85)
		var dist: float = 7.0 + 7.5 * g if look != "nuclear" else 120.0
		var focus: Vector3 = at + Vector3.UP * (1.6 * g if look != "nuclear" else 30.0)
		cam.look_at_from_position(focus + Vector3(0.55, 0.62, 0.8).normalized() * dist, focus)
		for i in range(30): await process_frame   # the ground under the camera settles in
		var opts := {"on_ground": shot[1] == "ground", "dir": Vector3(-1, 0, -1)}
		if float(shot[2]) > 0.0:
			opts.radius = shot[2]
		# A background system may open a notice that pauses the game; the films must keep running whatever it does.
		if paused:
			print("  (the game had paused itself before %s)" % look)
		paused = false
		var t0 := Time.get_ticks_msec()
		w.effects.blast(look, at, size, opts)
		var strip := Image.create(CELL.x * times.size(), CELL.y, false, Image.FORMAT_RGBA8)
		for ti in range(times.size()):
			var t: float = times[ti] * (3.0 if look == "nuclear" else 1.0)
			while (Time.get_ticks_msec() - t0) / 1000.0 < t:
				await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(ti * CELL.x, 0))
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(ti * CELL.x, li * CELL.y))
		strip.save_png("res://build/explosions/%s%s.png" % [look, "-low" if low else ""])
		print("FILMED %s at %s" % [look, str(times)])
		# Let it all burn out before the next one.
		var wait := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - wait) < 4000 and w.effects.blasts.busy() > 0:
			await process_frame
	sheet.save_png("res://build/explosions-sheet%s.png" % ("-low" if low else ""))
	print("EXPLOSION_VIEW DONE %d looks" % looks.size())
	quit()
