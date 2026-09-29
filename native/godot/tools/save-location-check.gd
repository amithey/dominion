extends SceneTree
## Run the existing disk-save regressions against disposable project-local
## slots, leaving the player's real saves and settings untouched.
class TestSave extends "res://scripts/save.gd":
	func setup(w: Node) -> void:
		world = w
		autosave_every = 0
		DirAccess.make_dir_recursive_absolute("res://build/audit-saves")
	func path_of(slot: String) -> String:
		return "res://build/audit-saves/%s.json" % slot

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.saves.queue_free()
	w.saves = TestSave.new()
	w.add_child(w.saves)
	w.saves.setup(w)
	if "--systems" in OS.get_cmdline_user_args():
		await w.systems_test(false)
	else:
		await w.save_test()
