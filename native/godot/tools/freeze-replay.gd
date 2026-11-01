extends SceneTree
## Replays a saved late match (growth-profile.gd --save-at=N) forward at a fixed time scale and prints the game
## clock every game second, so a freeze shows up as the clock that stopped (the last "REPLAY t=" line).
## Usage: --tag=name --scale=4 --until=2600 --step=1.   Output goes to the console only.
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
func _initialize() -> void: call_deferred("run")
func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name): return a.split("=")[1]
	return fallback
func run() -> void:
	var tag := arg("tag", "freeze4")
	var path := "res://build/audit/late-%s.json" % tag
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	set_meta("match_config", preload("res://scripts/match_setup.gd").normalize(data.get("match_config", {})))
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	var old = w.menu
	w.menu = QuietMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	old.queue_free()
	w.menu.set_fullscreen(false)
	root.size = Vector2i(1280, 800)
	w.start_match(str(data.get("difficulty", "normal")))
	w.menu.close()
	w.saves.autosave_every = 0
	w.saves.restore(data)
	if is_instance_valid(w.hud._guide): w.hud._guide.queue_free(); w.hud._guide = null
	Engine.time_scale = float(arg("scale", "4"))
	var until := float(arg("until", "2600"))
	var next_print := floorf(w.game_time) + 1.0
	print("REPLAY start t=%.1f" % w.game_time)
	while w.game_time < until:
		await process_frame
		if w.game_time >= next_print:
			print("REPLAY t=%.0f" % w.game_time)
			next_print = floorf(w.game_time) + float(arg("step", "1"))
	print("REPLAY done t=%.1f" % w.game_time)
	quit(0)
