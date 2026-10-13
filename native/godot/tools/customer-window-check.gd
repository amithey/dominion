extends SceneTree
var w: Node
var errors: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func frames(n := 8) -> void:
	for i in range(n): await process_frame
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customer-" + name + ".png")
func key(code: Key) -> void:
	for down in [true,false]:
		var e := InputEventKey.new()
		e.keycode = code; e.physical_keycode = code; e.pressed = down
		Input.parse_input_event(e)
		await process_frame
	await frames()
func run() -> void:
	set_meta("match_config", {"map":"island", "players":4, "nation":0})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(2); return
	if w.menu._root == null: w.menu.setup(w)
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	w.set_physics_process(false); w.ai.set_physics_process(false)
	w.ui_scale = 1.0; w.apply_ui_scale()
	var u = w.un
	u.current = null; u.assembly_current = null; u.queue.clear(); u.record.clear(); u.assembly_record.clear(); u.assembly_queue.clear()
	var session = w.hud._un_sessions
	u._open(u.table("player",3,-1,0,"reported conduct","economic"))
	for viewport in [Vector2i(1280,800),Vector2i(1024,720),Vector2i(1920,1080)]:
		root.size = viewport; await frames()
		for command in w.hud._command_row.get_children():
			if command.visible:
				check(root.get_visible_rect().encloses(command.get_global_rect()), "named navigation action stays on screen: " + command.text)
		session.refresh()
		check(session.invitation.visible, "UN invitation visible on map at " + str(viewport))
		await key(KEY_K); session.refresh()
		check(w.hud.side_mode == "defence", "real K shortcut opens Defence")
		check(not session.invitation.visible, "UN banner does not cover Defence tabs")
		check(w.hud._screen_buttons.un.text.contains("1"), "pending UN message stays in navigation")
		check(root.get_visible_rect().encloses(w.hud._win.get_global_rect()), "Defence fits viewport " + str(viewport))
		await shot("defence-" + str(viewport.x))
		await key(KEY_ESCAPE); session.refresh()
		check(session.invitation.visible, "closing Defence restores invitation without dismissing message")
		await key(KEY_B); session.refresh()
		check(w.hud.prod_open and not session.invitation.visible, "build shortcut opens unobstructed catalogue")
		await key(KEY_ESCAPE); session.refresh()
		await key(KEY_U)
		check(session.screen.visible, "real UN shortcut reaches pending conference")
		await key(KEY_ESCAPE)
		check(not session.screen.visible, "Escape returns from conference without voting")
	# Animation and motion over actual physics frames, with only rival AI paused.
	root.size = Vector2i(1280,800)
	var p: Vector3 = w.land_point(w.start,70.0)
	var h: Dictionary = w.spawn_unit("helicopter", p, 0)
	var s: Dictionary = w.spawn_unit("soldier", p, 0)
	w.cam_focus = p; w.cam_dist_target = 110.0
	w.order_move([h],p + Vector3(45,0,0))
	w.order_move([s],w.nearest_open_centre(p + Vector3(12,0,12)))
	var before: Vector3 = h.node.position
	var rotor: Basis = h.rotor.basis
	w.set_physics_process(true)
	await shot("motion-start")
	await create_timer(2.0).timeout
	await shot("motion-end")
	check(h.node.position.distance_to(before) > 2.0, "helicopter travels during live physics")
	check(not h.rotor.basis.is_equal_approx(rotor), "helicopter rotor animates across frames")
	check(s.get("player") != null or str(s.get("clip", "")) != "", "infantry has an active animation state")
	print("CUSTOMER_WINDOW %s %d checks" % ["PASS" if errors.is_empty() else "FAIL",checks])
	quit(0 if errors.is_empty() else 1)
