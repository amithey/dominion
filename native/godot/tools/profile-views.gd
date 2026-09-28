extends SceneTree
## A nation's strengths and weaknesses where the player sees them: the New Game
## picker (counted; its picture is interface-review.gd's) and the Diplomacy
## screen, your own nation and the rivals' (build/profile-diplomacy.png).
## Fails when a disclosure is missing or shows no lines.
var errors: Array[String] = []
var w: Node
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/profile-%s.png" % name)
## Opens every strengths-and-weaknesses disclosure under `parent`; returns how many lines they show.
func open_all(parent: Node) -> int:
	var lines := 0
	for stack in parent.find_children("NationalProfile", "", true, false):
		var toggle: Button = stack.get_child(0)
		toggle.button_pressed = true
		var details: Node = stack.get_child(1)
		lines += details.get_child_count()
	return lines
func run() -> void:
	var nation := int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 8
	# The match is set up for that nation before the world loads, so starting it
	# from the picker does not reload the scene.
	set_meta("match_config", {"map": "island", "players": 4, "nation": nation, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.menu.setup_options = w.match_config.duplicate()
	w.menu.open_new_game()
	await process_frame
	var picker_lines := open_all(w.menu._panel)
	if picker_lines < 4: errors.append("the New Game picker shows no strengths and weaknesses (%d lines)" % picker_lines)
	w.menu.start("easy")
	for i in range(20): await process_frame
	w.menu.close()
	w.hud.show()
	w.hud._panels = w.hud._panels if w.hud._panels != null else preload("res://scripts/side_panels.gd").new(w.hud)
	w.hud._panels.diplomacy_tab = "nations"
	w.hud.toggle_panel("diplomacy", true)
	await process_frame
	var cards: int = w.hud._side_rows.find_children("NationalProfile", "", true, false).size()
	var dip_lines := open_all(w.hud._side_rows)
	if cards < 2: errors.append("the Diplomacy screen shows %d national profiles (yours and the rivals' expected)" % cards)
	if dip_lines < 8: errors.append("the Diplomacy profiles show only %d lines" % dip_lines)
	await shot("diplomacy")
	print("  picker lines %d; diplomacy profiles %d with %d lines" % [picker_lines, cards, dip_lines])
	print("PROFILE_VIEWS PASS" if errors.is_empty() else "PROFILE_VIEWS FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
