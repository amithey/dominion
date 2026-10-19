extends SceneTree
## Order marks (order_marks.gd): a flag where the selected units were sent, one flag for a group however
## its slots spread, a dashed route from the lead unit, green to move and red to attack, a count over a
## group's flag, and the marks go when the units arrive or are deselected.
var errors: Array[String] = []
var passed := 0
var w: Node
const M := preload("res://scripts/order_marks.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal"); w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false); w.ai.set_physics_process(false)
	var om: Node3D = w.order_marks
	check(om != null and om is Node3D and om.get_parent() == w, "the world has the order marks")
	var p: Vector3 = w.land_point(w.start, 70.0)
	var squad := []
	for i in range(8): squad.append(w.spawn_unit("soldier", p + Vector3(i % 4 * 3.0, 0, floorf(i / 4.0) * 3.0), 0))
	for u in w.units: u.selected = false
	for u in squad: u.selected = true
	om._process(0.016)
	check(om.marks_drawn == 0 and om.lines_drawn == 0, "nothing is drawn for units with no order")
	var goal: Vector3 = w.land_point(p, 100.0)
	w.order_move(squad, goal)
	om._process(0.016)
	check(om.marks_drawn == 1, "one flag for a group of eight (%d)" % om.marks_drawn)
	check(om.lines_drawn > 20, "a dashed route is drawn (%d dashes)" % om.lines_drawn)
	check(squad.all(func(u): return u.order_goal.distance_to(goal) < 0.01), "every unit remembers the point the player clicked")
	var flag: Dictionary = om._flags.values()[0]
	check(flag.colour == M.MOVE and flag.pos.distance_to(goal) < 0.01, "green, standing where the player clicked")
	check(om._labels.size() >= 1 and om._labels[0].visible and om._labels[0].text == "×8", "the group's flag shows its number")
	# Attack-move turns it red.
	w.order_move(squad, goal, true)
	om._process(0.016)
	check(om._flags.values()[0].colour == M.ATTACK, "attack-move is red")
	# A second order elsewhere is a second flag; the first fades.
	var other: Vector3 = w.land_point(p, 60.0)
	w.order_move(squad.slice(0, 4), other)
	om._process(0.016)
	check(om.marks_drawn >= 2, "two destinations, two flags (%d)" % om.marks_drawn)
	# Arrival and deselection take the marks away after a moment.
	for u in squad:
		u.target = null
		u.path = PackedVector3Array()
	for i in range(20): om._process(0.1)
	check(om.marks_drawn == 0 and om._flags.is_empty(), "when they arrive the flags go")
	w.order_move(squad, goal)
	om._process(0.016)
	for u in squad: u.selected = false
	for i in range(20): om._process(0.1)
	check(om._flags.is_empty(), "and when the group is deselected")
	# An enemy's units are never marked.
	var foe: Dictionary = w.spawn_unit("soldier", p + Vector3(40, 0, 0), 1)
	foe.selected = true
	foe.target = goal
	om._process(0.016)
	check(om.marks_drawn == 0, "no marks for a rival's units")
	foe.selected = false
	# Boarding is amber.
	var heli: Dictionary = w.spawn_unit("helicopter", p + Vector3(10, 0, 10), 0)
	var s2: Dictionary = squad[0]
	s2.selected = true
	preload("res://scripts/airlift.gd").order_board(w, [s2], heli)
	om._process(0.016)
	check(om.marks_drawn >= 1 and om._flags.values().any(func(f): return f.colour == M.BOARD), "boarding is amber")
	print("ORDER_MARKS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("ORDER_MARKS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
