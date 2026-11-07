extends SceneTree
## Propellers and tail rotors of the Blender aircraft are found and turn in play.
var w: Node
var errors: Array[String] = []
const DT := 1.0 / 20.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func sim(sec: float) -> void:
	var t := 0.0
	while t < sec:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	var at: Vector3 = w.start + Vector3(40, 0, 40)
	# the first model with a propeller and the first with a tail rotor
	var want := {"prop": "", "tail": ""}
	var CM := preload("res://scripts/craft_models.gd")
	for key in w.AIR:
		var parts: Dictionary = CM.build(w, key, 0)
		if parts.is_empty():
			continue
		if want.prop == "" and not parts.props.is_empty(): want.prop = key
		if want.tail == "" and not parts.tail_rotors.is_empty(): want.tail = key
		parts.root.free()
		if not "" in want.values():
			break
	print("keys: ", want)
	check(want.prop != "" and want.tail != "", "the roster has a propeller and a tail rotor to turn")
	for kind in ["prop", "tail"]:
		if want[kind] == "":
			continue
		var u: Dictionary = w.spawn_unit(want[kind], at, 0)
		var part: Node3D = u.props[0] if kind == "prop" else u.tail_rotors[0]
		var before := part.transform.basis
		sim(0.5)
		check(not part.transform.basis.is_equal_approx(before), "%s of %s turns" % [kind, want[kind]])
	print("CRAFT_PARTS PASS" if errors.is_empty() else "CRAFT_PARTS FAIL")
	quit()
