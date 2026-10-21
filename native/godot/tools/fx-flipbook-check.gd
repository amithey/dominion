extends SceneTree
## The filmed effects (assets/art/fx, shaders/fx_flipbook.gdshader, effects.gd flipbook()): every sheet in the manifest loads and has
## the frames it says; a ground blast, an air blast and a sea blast each start flipbooks; the frame runs from the first to the last
## and the quad is freed when it ends; a burning wreck's flames loop while it burns; the cheap Low preset keeps particles.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func books() -> Array:
	return w.effects._live.filter(func(e): return e.kind == "book")

func run() -> void:
	seed(5)
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)
	var fx: Node = w.effects
	# the sheets
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/MANIFEST.json"))
	var ok_all := true
	for kind in fx.BOOKS:
		var def: Dictionary = fx.BOOKS[kind]
		var entry: Variant = null
		for m in manifest:
			if str(m.file) == "fx/%s.png" % def.file: entry = m
		var tex: Texture2D = load("res://assets/art/fx/%s.png" % def.file)
		var good: bool = tex != null and entry != null and int(entry.frames) == int(def.frames) and int(def.grid.x * def.grid.y) >= int(def.frames) and tex.get_width() == int(entry.size[0])
		if not good: ok_all = false
		check(good, "sheet %s loads (%dx%d), %d frames as the manifest says" % [def.file, tex.get_width() if tex else 0, tex.get_height() if tex else 0, int(def.frames)])
	check(ok_all, "all %d sheets are in the manifest" % fx.BOOKS.size())
	# Low keeps particles, High and Balanced use the films (and tests can force them)
	w.quality = "low"
	check(not fx.books_on(), "Low keeps the cheap particles")
	fx.force_books = true
	check(fx.books_on(), "the films can be switched on")
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var land: Vector3 = Vector3(hq.x + 30.0, w.height_at(hq.x + 30.0, hq.z), hq.z)
	var n0: int = books().size()
	fx.explosion(land, 2.0, true)
	var ground_books: Array = books().slice(n0)
	check(ground_books.size() >= 2, "a ground blast of size 2 starts a blast and a smoke column (%d flipbooks)" % ground_books.size())
	check(ground_books.any(func(e): return e.node.scale.x > 7.0), "its width follows the size (%.1f m)" % ground_books[0].node.scale.x)
	n0 = books().size()
	fx.explosion(land + Vector3(0, 12, 0), 1.0, false)
	check(books().size() > n0, "an air burst starts a flipbook")
	var sea: Vector3 = w.water_near(hq, 240)
	n0 = books().size()
	fx.explosion(Vector3(sea.x, float(w.map.seaLevel) + 1.0, sea.z), 1.4, false)
	var sea_books: Array = books().slice(n0)
	check(sea_books.size() >= 2, "a burst over the sea adds a water splash (%d flipbooks)" % sea_books.size())
	n0 = books().size()
	fx.explosion(land, 5.0, true)
	check(books().slice(n0).size() >= 3, "a big blast adds the glow of the fireball (%d)" % books().slice(n0).size())
	# time: the frame runs and the quad goes
	var probe: Dictionary = books()[0]
	var life: float = probe.life
	fx._physics_process(life * 0.5)
	var mid: float = probe.node.get_instance_shader_parameter("frame")
	check(mid > 20.0 and mid < 44.0, "half-way through the film it is at frame %.0f of %d" % [mid, int(probe.frames)])
	fx._physics_process(life)
	check(not is_instance_valid(probe.node) or probe.node.is_queued_for_deletion(), "the film ends and its quad is freed")
	# a burning wreck loops
	n0 = books().size()
	fx.burn(land, 20.0)
	var fire: Dictionary = {}
	for e in books().slice(n0):
		if e.loop: fire = e
	check(not fire.is_empty(), "a burning wreck plays the looping flames")
	if not fire.is_empty():
		fx._physics_process(0.5)
		var f1: float = fire.node.get_instance_shader_parameter("frame")
		fx._physics_process(0.5)
		var f2: float = fire.node.get_instance_shader_parameter("frame")
		check(f2 != f1, "the flames move (%.1f then %.1f)" % [f1, f2])
		fx._physics_process(18.0)
		check(is_instance_valid(fire.node) and not fire.node.is_queued_for_deletion(), "they are still burning 19 s into a 20 s fire")
		fx._physics_process(2.0)
		check(not is_instance_valid(fire.node) or fire.node.is_queued_for_deletion(), "and gone when the fire is out")
	# impact dust
	n0 = books().size()
	fx.impact(land)
	check(books().size() > n0, "a bullet's impact raises a puff of dust")
	print("FX_FLIPBOOK %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("FX_FLIPBOOK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
