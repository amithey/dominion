extends SceneTree
## The match's pace (0.9.43): the world runs at 60%, 75% or 100% of its
## original speed, all of it together, while the camera keeps its own.
var errors: Array[String] = []
var passed := 0
var w: Node
const Setup := preload("res://scripts/match_setup.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## Real seconds of play at the current pace: how far game time, a soldier and the camera go.
func play(seconds: float, soldier: Dictionary, goal: Vector3) -> Array:
	var t0: float = w.game_time
	var p0: Vector3 = soldier.node.position
	w.order_move([soldier], goal)
	var cam0: Vector3 = w.cam_focus
	var start := Time.get_ticks_msec()
	var held := InputEventKey.new()
	held.physical_keycode = KEY_D
	held.pressed = true
	Input.parse_input_event(held)
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
	held.pressed = false
	Input.parse_input_event(held)
	var real := (Time.get_ticks_msec() - start) / 1000.0
	return [(w.game_time - t0) / real, soldier.node.position.distance_to(p0) / real, w.cam_focus.distance_to(cam0) / real]

func run() -> void:
	check(Setup.normalize({}).pace == 0.75, "a new match runs at 75% pace")
	check(Setup.normalize({"pace": 0.62}).pace == 0.6 and Setup.normalize({"pace": "x"}).pace == 0.75 and Setup.normalize({"pace": 3.0}).pace == 1.0, "any other value snaps to the nearest pace on offer")
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard", "pace": 0.75})
	change_scene_to_file("res://world.tscn")
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	paused = false
	check(Engine.time_scale == 1.0, "a test script driving the game keeps full speed")
	var warm := Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm < 4000: await process_frame   # past the first, slow frames
	var runner: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 30.0), 0)
	var far: Vector3 = w.land_point(w.start, 120.0)
	var full: Array = await play(3.0, runner, far)
	w.apply_pace(true)
	check(absf(Engine.time_scale - 0.75) < 0.001, "the match's pace slows the engine clock to 75%")
	w.cam_focus = w.start
	var back: Vector3 = w.land_point(w.start, 120.0)
	var slow: Array = await play(3.0, runner, back)
	print("  full: %s   at 75%%: %s" % [str(full), str(slow)])
	check(absf(slow[0] / full[0] - 0.75) < 0.08, "game time runs at 75%% (%.2f against %.2f a second)" % [slow[0], full[0]])
	check(slow[1] < full[1] * 0.9 and slow[1] > full[1] * 0.55, "a soldier covers less ground each second (%.1f against %.1f m)" % [slow[1], full[1]])
	check(slow[2] > full[2] * 0.85, "the camera pans as fast as ever (%.1f against %.1f m a second)" % [slow[2], full[2]])
	var data: Dictionary = w.saves.capture()
	check(float(data.match_config.get("pace", 0.0)) == 0.75, "the pace is kept in a save")
	Engine.time_scale = 1.0
	print("\nPACE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("PACE PASS" if errors.is_empty() else "PACE FAIL")
	quit(0 if errors.is_empty() else 1)
