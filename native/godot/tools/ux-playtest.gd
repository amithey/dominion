extends SceneTree
## Plays the game like a person: real window, real key events, a screenshot of
## each screen (build/ux/*.png) and an audit of every visible control for what a
## player complains about (off screen, clipped text, tiny type, overlaps).
## Run without --headless:  godot --path . --script res://tools/ux-playtest.gd
var w: Node
var findings: Array[String] = []
var shots := 0

func _initialize() -> void: call_deferred("run")

func note(sev: String, where: String, what: String) -> void:
	var line := "[%s] %s: %s" % [sev, where, what]
	findings.append(line)
	print("UX ", line)

func shot(name: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/ux")
	root.get_texture().get_image().save_png("res://build/ux/%s.png" % name)
	shots += 1

func key(code: Key, shift := false, ctrl := false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.shift_pressed = shift
		e.ctrl_pressed = ctrl
		Input.parse_input_event(e)
	await process_frame
	await process_frame

func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.global_position = at
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame

## Every visible control of the screen against the usual complaints.
func audit(where: String) -> void:
	var vp := root.get_visible_rect()
	var seen := {}
	var stack: Array = [root]
	var items: Array = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.push_back(c)
		if n is Control and n.is_visible_in_tree() and n.size.x > 0 and n.size.y > 0:
			items.append(n)
	for c: Control in items:
		var r := c.get_global_rect()
		var label := "%s '%s'" % [c.get_class(), c.name]
		if c is Label or c is Button or c is RichTextLabel or c is LineEdit:
			var txt: String = c.get("text") if c.get("text") != null else ""
			if txt.strip_edges() == "" and c is Label: continue
			var font_size: int = c.get_theme_font_size("font_size")
			if c is Button and c.get_theme_font_size("font_size") > 0: font_size = c.get_theme_font_size("font_size")
			if font_size > 0 and font_size < 11 and txt.length() > 3:
				var k := "tiny %s %d" % [txt.substr(0, 20), font_size]
				if not seen.has(k):
					seen[k] = true
					note("small", where, "type %dpx is hard to read: \"%s\"" % [font_size, txt.substr(0, 40)])
			if c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF and not c.clip_text and txt != "":
				var need: float = c.get_minimum_size().x
				if c.size.x + 1.0 < need and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
					var k2 := "clip %s" % txt.substr(0, 30)
					if not seen.has(k2):
						seen[k2] = true
						note("clipped", where, "label cut off (%d of %d px): \"%s\"" % [c.size.x, need, txt.substr(0, 50)])
			if c is Label and c.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and c.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var font: Font = c.get_theme_font("font")
				var fs: int = c.get_theme_font_size("font_size")
				var wpx := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if wpx > c.size.x + 2.0 and c.size.x > 20:
					var k3 := "ellip %s" % txt.substr(0, 30)
					if not seen.has(k3):
						seen[k3] = true
						note("truncated", where, "text shown as '...' (%d of %d px): \"%s\"" % [c.size.x, wpx, txt.substr(0, 50)])
			if c is Button and not c.disabled and (r.size.x < 22 or r.size.y < 22) and c.get_class() != "OptionButton":
				var k4 := "tiny-btn %s" % c.name
				if not seen.has(k4):
					seen[k4] = true
					note("small", where, "button %s is only %dx%d px to hit" % [c.name, r.size.x, r.size.y])
			if c is Button and txt.strip_edges() == "" and c.tooltip_text == "" and c.icon == null:
				note("unlabelled", where, "button %s has no text, icon or tooltip" % c.name)
		if r.size.x > 4 and r.size.y > 4 and (r.position.x < -2 or r.position.y < -2 or r.end.x > vp.size.x + 2 or r.end.y > vp.size.y + 2):
			if c is PanelContainer or c is Button or c is Label:
				var k5 := "off %s" % c.name
				if not seen.has(k5) and not (c.get_parent() is ScrollContainer):
					seen[k5] = true
					note("offscreen", where, "%s sticks out of the screen: %s" % [label, r])

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800))
	change_scene_to_file("res://world.tscn")
	var t0 := Time.get_ticks_msec()
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	print("UX boot to menu: %d ms" % (Time.get_ticks_msec() - t0))
	if Time.get_ticks_msec() - t0 > 8000:
		note("slow", "start", "%d s from launch to a usable menu" % ((Time.get_ticks_msec() - t0) / 1000))
	await shot("01-main-menu")
	audit("main menu")
	w.menu.open_new_game()
	await shot("02-new-game")
	audit("new game")
	w.menu.open_settings()
	await shot("03-settings")
	audit("settings")
	w.menu.open_load()
	await shot("04-load")
	audit("load")
	w.menu.open_main()
	w.menu.start("easy")
	var t1 := Time.get_ticks_msec()
	for i in range(30): await process_frame
	print("UX start match: %d ms" % (Time.get_ticks_msec() - t1))
	await shot("05-first-view")
	audit("first view")
	for entry in [["06-build", KEY_B], ["07-research", KEY_Y], ["08-diplomacy", KEY_G], ["09-market", KEY_M], ["10-intel", KEY_I],
			["11-territory", KEY_T], ["12-defence", KEY_K], ["13-un", KEY_U], ["14-cabinet", KEY_TAB], ["15-log", KEY_L], ["16-help", KEY_F1]]:
		await key(entry[1])
		await shot(entry[0])
		audit(entry[0])
		await key(KEY_ESCAPE)
		for i in range(3): await process_frame
	await key(KEY_ESCAPE)
	await shot("17-pause")
	audit("pause")
	await key(KEY_ESCAPE)
	print("UX_PLAYTEST shots=%d findings=%d" % [shots, findings.size()])
	var f := FileAccess.open("res://build/ux/findings.txt", FileAccess.WRITE)
	f.store_string("\n".join(findings))
	f.close()
	quit()
