extends SceneTree
## The whole research tree can be finished: with every facility built, the
## last era reached and materials to hand, queuing the discoveries four at a
## time completes every one of them, and a project that is waiting does not
## hold up the ones queued behind it.
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(3000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.menu._root.hide()
	var r: Node = w.research
	# A waiting project (its facility is missing) must not block the queue.
	w.economy.grant_test_resources()
	r.era = 1
	r.points = 5000.0
	r.progress["navalEngineering"].stage = 1   # the prototype needs a Shipyard
	r.enqueue("navalEngineering")
	var other := ""
	for key in r.discoveries:
		if other == "" and r.era_of(key) <= 1 and r.def_of(key).get("reqBuilding") == null and r.def_of(key).get("reqDiscovery") == null and not r.done(key):
			other = key
	r.enqueue(other)
	var before: int = r.stage_of(other)
	for s in range(40):
		r.tick(1.0)
	check(r.stage_of(other) > before, "a project behind a waiting one still advances (%s)" % other)
	r.queue.clear()
	# Every facility, the last era, plenty of everything: all of it completes.
	var needed := {}
	for key in r.discoveries:
		var b = r.def_of(key).get("reqBuilding")
		if b != null:
			needed[b] = true
	for key in needed:
		var b: Dictionary = w.place_building(key, w.start + Vector3(randf_range(-300, 300), 0, randf_range(-300, 300)), 0, true)
	r.era = r.eras.size() - 1
	for s in range(60 * 60 * 3):
		for res in w.economy.res:
			w.economy.res[res] = maxf(float(w.economy.res[res]), 1e6)
		r.points = 1e6
		for key in r.discoveries:
			if r.queue.size() < r.QUEUE_MAX and not r.done(key) and not key in r.queue:
				r.enqueue(key)
		r.tick(1.0)
		if r.completed_count() == r.discoveries.size():
			break
	var missing: Array = r.discoveries.keys().filter(func(k): return not r.done(k))
	print("  completed %d of %d; not done: %s" % [r.completed_count(), r.discoveries.size(), missing.map(func(k): return "%s (%s)" % [k, r.blocker(k)])])
	check(missing.is_empty(), "every discovery can be completed")
	print("RESEARCH_COMPLETE PASS" if errors.is_empty() else "RESEARCH_COMPLETE FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
