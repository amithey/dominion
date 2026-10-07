extends SceneTree
## Real window resizing and keyboard input; does not overwrite player settings.
class RecordingMenu extends "res://scripts/menu.gd":
	var saves := 0
	var saved_full := false
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void:
		saves += 1
		saved_full = is_fullscreen()
var w: Node
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func frames(n := 10) -> void:
	for frame in range(n): await process_frame
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: failed += 1
func fills_window() -> bool:
	var visible: Rect2 = root.get_final_transform() * root.get_visible_rect()
	return visible.position.length() < 2.0 and (visible.size - Vector2(root.size)).length() < 3.0
func f11(echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F11
	event.keycode = KEY_F11
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await frames()
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FULLSCREEN_CHECK needs a real graphics display")
		quit(1)
		return
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for frame in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.menu.close()
	w.menu.set_process_input(false)
	w.menu.queue_free()
	w.menu = RecordingMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	w.menu.open_main()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 1000), Vector2i(1600, 900)]:
		w.menu.set_fullscreen(false)
		await frames(3)
		root.size = dimensions
		await frames(16)
		check(root.size == dimensions and fills_window(), "%s viewport fills resized window without letterboxing" % str(dimensions))
		check(w.menu._root.get_global_rect().grow(2).encloses(root.get_visible_rect()), "menu background covers expanded viewport")
	w.menu.set_fullscreen(true)
	await frames(16)
	check(w.menu.is_fullscreen() and fills_window(), "fullscreen uses the entire window")
	check(root.size == DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()), "fullscreen matches current monitor dimensions")
	w.menu.open_settings()
	await f11()
	check(not w.menu.is_fullscreen() and not w.menu.saved_full, "real F11 input returns to a window and saves that preference")
	await f11(true)
	check(not w.menu.is_fullscreen() and w.menu.saves == 1, "held F11 does not repeatedly switch modes")
	await f11()
	check(w.menu.is_fullscreen() and w.menu.saved_full and w.menu.saves == 2, "F11 returns to fullscreen and saves preference")
	var choice: Array = w.menu._panel.find_children("*", "Button", true, false).filter(func(b): return b.text == "Full screen")
	check(choice.size() == 1 and choice[0].button_pressed, "graphics settings reflect the keyboard change")
	var capture_dir := OS.get_environment("DOMINION_TEST_OUTPUT")
	if capture_dir.is_empty(): capture_dir = "res://build"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await frames()
	w.menu.open_main()
	await frames(16)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("fullscreen-menu.png"))
	w.start_match("easy")
	w.menu.close()
	await frames(16)
	check(not w.menu._root.visible and fills_window(), "battlefield fills the fullscreen viewport")
	await f11()
	check(not w.menu.is_fullscreen() and fills_window(), "F11 also works during a match")
	await f11()
	check(w.menu.is_fullscreen() and fills_window(), "match returns to the complete fullscreen viewport")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("fullscreen-game.png"))
	print("FULLSCREEN_CHECK: %d passed, %d failed" % [passed, failed])
	print("FULLSCREEN_CHECK PASS" if failed == 0 else "FULLSCREEN_CHECK FAIL")
	quit(0 if failed == 0 else 1)
