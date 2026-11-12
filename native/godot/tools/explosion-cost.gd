extends SceneTree
## What the explosion looks cost to draw (scripts/blasts.gd): a barrage of bursts is set off in view, once with each
## munition's own look and once with the old explosion ("classic") at the same sizes, and the frame times over the
## following seconds are compared. Run windowed:
##   Godot --path native/godot -s res://tools/explosion-cost.gd -- [--bursts=40] [--over=4] [--low]
const MIX := [["grenade", 0.5], ["shell", 1.0], ["heat", 0.8], ["mortar", 0.8], ["artillery", 1.5], ["rocket", 0.9],
	["missile", 1.2], ["bomb", 1.6], ["thermobaric", 1.4], ["flak", 1.0]]

var w: Node

func _initialize() -> void: call_deferred("run")

func barrage(centre: Vector3, bursts: int, over: float, classic: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var plan := []
	for i in range(bursts):
		var m: Array = MIX[i % MIX.size()]
		var at: Vector3 = centre + Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-30, 30))
		at.y = w.height_at(at.x, at.z) + (18.0 if m[0] == "flak" else 0.0)
		plan.append([rng.randf() * over, "classic" if classic else m[0], at, m[1], m[0]])
	plan.sort_custom(func(a, b): return a[0] < b[0])
	var times: Array[float] = []
	var t0 := Time.get_ticks_usec()
	var last := t0
	var next := 0
	while (Time.get_ticks_usec() - t0) / 1.0e6 < over + 4.0:
		var now := (Time.get_ticks_usec() - t0) / 1.0e6
		while next < plan.size() and plan[next][0] <= now:
			var p: Array = plan[next]
			w.effects.blast(p[1], p[2], p[3], {"on_ground": p[4] != "flak", "crater": false})
			next += 1
		await process_frame
		var t := Time.get_ticks_usec()
		times.append((t - last) / 1000.0)
		last = t
	times.sort()
	var mean := 0.0
	for x in times: mean += x / times.size()
	return {"mean": mean, "p95": times[int(times.size() * 0.95)], "worst": times[-1], "frames": times.size()}

func run() -> void:
	var bursts := 40
	var over := 4.0
	var low := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bursts="): bursts = int(a.get_slice("=", 1))
		elif a.begins_with("--over="): over = float(a.get_slice("=", 1))
		elif a == "--low": low = true
	change_scene_to_file("res://world.tscn")
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	w.start_match("easy")
	w.menu._root.hide()
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.effects.process_mode = Node.PROCESS_MODE_ALWAYS
	if low:
		w.quality = "low"
	var centre: Vector3 = w.land_point(w.start + Vector3(-90, 0, 70), 60.0)
	centre.y = w.height_at(centre.x, centre.z)
	var cam := Camera3D.new()
	cam.fov = 50
	w.add_child(cam)
	cam.current = true
	cam.look_at_from_position(centre + Vector3(0, 70, 75), centre)
	for i in range(90): await process_frame
	paused = false
	var idle := await barrage(centre, 0, 1.0, true)
	var old := await barrage(centre, bursts, over, true)
	for i in range(240): await process_frame
	paused = false
	var new := await barrage(centre, bursts, over, false)
	print("EXPLOSION_COST %d bursts over %.0f s%s" % [bursts, over, " (Low)" if low else ""])
	print("  idle     mean %.1f ms, p95 %.1f, worst %.1f" % [idle.mean, idle.p95, idle.worst])
	print("  classic  mean %.1f ms, p95 %.1f, worst %.1f (%d frames)" % [old.mean, old.p95, old.worst, old.frames])
	print("  looks    mean %.1f ms, p95 %.1f, worst %.1f (%d frames)" % [new.mean, new.p95, new.worst, new.frames])
	quit()
