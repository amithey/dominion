extends SceneTree
## Second playtest: mouse play (select, move, build, camera), idle time, small screens.
var w: Node
var findings: Array[String] = []
func _initialize() -> void: call_deferred("run")
func note(sev: String, where: String, what: String) -> void:
	findings.append("[%s] %s: %s" % [sev, where, what])
	print("UX [%s] %s: %s" % [sev, where, what])
func shot(name: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/ux")
	root.get_texture().get_image().save_png("res://build/ux/%s.png" % name)
func key_hold(code: Key, seconds: float) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(seconds).timeout
	e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame
func key(code: Key) -> void:
	await key_hold(code, 0.05)
func mouse(at: Vector2, button := MOUSE_BUTTON_LEFT, down := true, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = button
	e.pressed = down
	e.shift_pressed = shift
	Input.parse_input_event(e)
	await process_frame
func move_to(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await process_frame
func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await move_to(at)
	await mouse(at, button, true)
	await mouse(at, button, false)
func find_text(text: String) -> Control:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.push_back(c)
		if n is Control and n.is_visible_in_tree() and (n is Label or n is Button) and str(n.get("text")).strip_edges().to_lower().begins_with(text.to_lower()):
			return n
	return null
func centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()
func scr(p: Vector3) -> Vector2:
	return w.camera.unproject_position(p)
func fps_now(seconds: float) -> float:
	var t := Time.get_ticks_msec()
	var f := Engine.get_process_frames()
	await create_timer(seconds).timeout
	return float(Engine.get_process_frames() - f) / ((Time.get_ticks_msec() - t) / 1000.0)
func money() -> float:
	return float(w.economy.res.money)

func boot() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800))
	await boot()
	w.menu.start("easy")
	for i in range(60): await process_frame
	var f0 := await fps_now(3.0)
	print("UX fps idle at start: %.1f" % f0)
	if f0 < 30: note("perf", "start", "only %.0f fps standing still in the first minute" % f0)
	# --- the units: click a tank
	var tanks: Array = w.units.filter(func(u): return u.owner == 0 and u.key.contains("tank") or (u.owner == 0 and u.key.contains("armor")))
	print("UX my units: ", w.units.filter(func(u): return u.owner == 0).map(func(u): return u.key).size(), " kinds ", w.units.filter(func(u): return u.owner == 0).map(func(u): return u.key).reduce(func(a, k): a[k] = a.get(k, 0) + 1; return a, {}))
	var mine: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead)
	var tank = null
	for u in mine:
		if u.key not in ["worker", "soldier", "rifleman"] and not str(u.key).contains("plane") and u.node.position.y < 50:
			tank = u
			break
	if tank == null: tank = mine[0]
	print("UX clicking unit ", tank.key)
	await click(scr(tank.node.global_position + Vector3(0, 1, 0)))
	await shot("20-unit-selected")
	note("info", "select", "selected after click: %s" % str(tank.selected))
	# move it
	var dest: Vector3 = tank.node.global_position + Vector3(25, 0, 10)
	var before: Vector3 = tank.node.global_position
	await click(scr(dest), MOUSE_BUTTON_RIGHT)
	await shot("21-move-order")
	await create_timer(4.0).timeout
	var moved: float = tank.node.global_position.distance_to(before)
	print("UX tank moved %.1f m in 4 s" % moved)
	if moved < 3.0: note("bug", "move", "a move order barely moved the unit (%.1f m in 4 s)" % moved)
	await shot("22-after-move")
	# box select infantry
	var inf: Array = mine.filter(func(u): return str(u.key).contains("sold") or str(u.key).contains("infantry") or u.key == "worker")
	print("UX infantry kinds: ", inf.map(func(u): return u.key).slice(0, 4))
	await mouse(Vector2(300, 300), MOUSE_BUTTON_LEFT, true)
	await move_to(Vector2(700, 600))
	await shot("23-box-select-drag")
	await mouse(Vector2(700, 600), MOUSE_BUTTON_LEFT, false)
	var sel_n: int = w.units.filter(func(u): return u.selected).size()
	print("UX box select count: %d" % sel_n)
	await shot("24-box-selected")
	# --- build a farm
	await click(Vector2(1215, 62))
	await shot("25-after-build-click")
	var farm := find_text("Farm")
	if farm == null:
		note("bug", "build", "no Farm in the build list after pressing the Build button")
	else:
		await click(centre(farm))
		await shot("26-placing-farm")
		print("UX placing=%s" % w.placing)
		# hover a spot next to the hq
		var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
		var m0 := money()
		var spots: Array = [Vector3(-30, 0, 20), Vector3(-25, 0, -25), Vector3(30, 0, 30), Vector3(0, 0, 40), Vector3(-40, 0, 0)]
		var placed := false
		for off in spots:
			var at: Vector3 = hq.root.global_position + off
			at.y = w.height_at(at.x, at.z)
			await move_to(scr(at))
			for i in range(3): await process_frame
			if w.ghost_ok == "":
				await shot("27-ghost-ok")
				await click(scr(at))
				placed = true
				break
			else:
				print("UX ghost says: ", w.ghost_ok)
		await shot("28-farm-placed")
		print("UX placed=%s money %.0f -> %.0f placing=%s" % [placed, m0, money(), w.placing])
		if not placed: note("ux", "build", "I could not find a valid hex for a Farm within 40 m of my own HQ in 5 tries")
		await key(KEY_ESCAPE)
	# --- the farm: who builds it?
	await create_timer(3.0).timeout
	await shot("29-farm-wait")
	# --- camera
	var c0: Vector3 = w.cam_focus
	await key_hold(KEY_D, 1.0)
	var dc: float = w.cam_focus.distance_to(c0)
	print("UX camera moved %.1f in 1 s of D" % dc)
	if dc < 3.0: note("bug", "camera", "holding D for 1 s moved the camera only %.1f" % dc)
	var z0: float = w.cam_dist_target
	await mouse(Vector2(640, 400), MOUSE_BUTTON_WHEEL_UP, true)
	await mouse(Vector2(640, 400), MOUSE_BUTTON_WHEEL_UP, true)
	print("UX zoom %.0f -> %.0f" % [z0, w.cam_dist_target])
	# edge scroll
	var c1: Vector3 = w.cam_focus
	await move_to(Vector2(1279, 400))
	await create_timer(1.0).timeout
	print("UX edge scroll moved %.1f" % w.cam_focus.distance_to(c1))
	await move_to(Vector2(640, 400))
	# minimap
	var c2: Vector3 = w.cam_focus
	await click(Vector2(1150, 700))
	for i in range(30): await process_frame
	print("UX minimap click moved camera %.1f" % w.cam_focus.distance_to(c2))
	await shot("30-after-minimap")
	# F5 / F9
	await key(KEY_F5)
	await shot("31-after-f5")
	# idle: let ten minutes pass without doing anything
	w.menu.close()
	var DT := 1.0 / 20.0
	var t := 0.0
	var log_before: int = w.hud.get("_log_lines").size() if w.hud.get("_log_lines") != null else -1
	while t < 600.0:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT
	await shot("32-after-10-min-idle")
	print("UX after 10 idle minutes: money %.0f food %.0f citizens %s" % [money(), float(w.economy.res.food), str(w.economy.res.get("citizens"))])
	print("UX_PLAY2 done")
	var f := FileAccess.open("res://build/ux/findings2.txt", FileAccess.WRITE)
	f.store_string("\n".join(findings))
	f.close()
	quit()
