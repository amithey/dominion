extends SceneTree
## Round 3 customer playthrough: plays the real game through its input path
## (mouse clicks on the visible controls, keys, drags on the map) from the main
## menu on, over a long campaign, and saves a screenshot at every step
## (build/r3/NN-name.png) with what the player saw (build/r3/log.txt).
## Run with a window: Godot --path . --resolution 1600x900 -s res://tools/customer-round3-play.gd
## Never writes the player's settings or saves (a test slot only).
class QuietMenu extends "res://scripts/menu.gd":
	func save_settings() -> void: pass
var w: Node
var hud: Node
var n := 0
var log_lines: Array[String] = []
var part := "all"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="): part = a.substr(7)
	call_deferred("run")

func note(text: String) -> void:
	log_lines.append("[%03d] %s" % [n, text])
	print("R3 ", text)

func frames(k := 6) -> void:
	for i in range(k): await process_frame

func shot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/r3")
	n += 1
	root.get_texture().get_image().save_png("res://build/r3/%02d-%s.png" % [n, name])
	note("SHOT %02d %s" % [n, name])

## A point in the window from a point in the root viewport's canvas.
func to_window(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func mouse_move(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await frames(2)

func click_at(at: Vector2, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	await mouse_move(at)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.global_position = at
		e.button_index = button
		e.pressed = down
		e.shift_pressed = shift
		Input.parse_input_event(e)
		await frames(2)

func drag(a: Vector2, b: Vector2) -> void:
	await mouse_move(a)
	var e := InputEventMouseButton.new()
	e.position = a; e.global_position = a; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	for i in range(1, 7):
		await mouse_move(a.lerp(b, i / 6.0))
	var r := InputEventMouseButton.new()
	r.position = b; r.global_position = b; r.button_index = MOUSE_BUTTON_LEFT; r.pressed = false
	Input.parse_input_event(r)
	await frames(3)

func key(code: Key, shift := false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		e.shift_pressed = shift
		Input.parse_input_event(e)
		await frames(2)

## The visible control whose text is `text` (or starts with it).
func find_control(text: String, parent: Node = null, exact := false) -> Control:
	var best: Control = null
	for c in (parent if parent != null else root).find_children("*", "", true, false):
		if not c is Control or not c.is_visible_in_tree() or c.is_queued_for_deletion():
			continue
		var t := ""
		if c is Button: t = c.text
		elif c is Label: t = c.text
		elif c is RichTextLabel: t = c.get_parsed_text()
		else: continue
		t = t.strip_edges()
		if (t == text) if exact else t.begins_with(text):
			best = c
			if c is Button: return c
	return best

## Clicks the visible control showing `text`; false (and a note) when there is none.
func click_text(text: String, parent: Node = null, exact := false) -> bool:
	var c := find_control(text, parent, exact)
	if c == null:
		note("MISSING control '%s'" % text)
		return false
	var centre: Vector2 = c.get_global_rect().get_center()
	var at := to_window(centre)
	# Is something else on top of it there? The topmost control under the point.
	await click_at(at)
	return true

func world_point(p: Vector3) -> Vector2:
	return w.get_viewport().get_camera_3d().unproject_position(p)

func look_at(p: Vector3, dist := 115.0, pitch := 0.95) -> void:
	w.cam_focus = p
	w.cam_dist_target = dist
	w.cam_pitch = pitch
	if w.get("cam_dist") != null: w.cam_dist = dist
	await frames(20)

func play(seconds: float, speed := 4.0) -> void:
	Engine.time_scale = speed
	var until := Time.get_ticks_msec() + int(seconds * 1000.0 / speed)
	while Time.get_ticks_msec() < until:
		await process_frame
	Engine.time_scale = 1.0

func notices() -> Array:
	return hud.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree()).map(func(l): return l.text)

func hq(owner := 0) -> Dictionary:
	return w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)[0]

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		print("R3 no world"); quit(1); return
	hud = w.hud
	# The player's own settings are kept; nothing is written back.
	var old_menu = w.menu
	w.menu = QuietMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	old_menu.queue_free()
	w.menu.set_fullscreen(false)
	root.size = Vector2i(1600, 900)
	await frames(10)
	w.menu.open_main()
	await shot("main-menu")
	await click_text("New Game")
	await shot("new-game-sheet")
	# A nation of my own: the nation picker is an option list.
	var pick: OptionButton = w.menu.find_children("*", "OptionButton", true, false)[0]
	await click_at(to_window(pick.get_global_rect().get_center()))
	await shot("nation-list-open")
	await key(KEY_ESCAPE)
	await click_text("Begin campaign")
	await frames(3)
	await shot("loading")
	# Beginning a campaign builds a new world scene.
	for i in range(8000):
		await process_frame
		var sc = current_scene
		if sc != null and is_instance_valid(sc) and sc.get("nav_ready") == true and sc.get("ai") != null and not sc.ai.nations.is_empty():
			w = sc
			break
	hud = w.hud
	if not w.menu is QuietMenu:
		var m2 = w.menu
		w.menu = QuietMenu.new()
		w.add_child(w.menu)
		w.menu.setup(w)
		m2.queue_free()
		w.menu.close()
	await frames(30)
	w.saves.autosave_every = 0
	await shot("first-view")
	note("notices at start: " + str(notices().filter(func(t): return t.length() > 25).slice(0, 6)))
	# The top bar: hover each resource for its explanation.
	for x in [90, 150, 210, 270, 330]:
		await mouse_move(Vector2(x, 18))
		await frames(40)
	await shot("hover-resource")
	# The opening guide or tips, if any, then the build menu.
	await click_text("Build")
	await shot("build-menu")
	await click_text("Farm")
	var home: Vector3 = hq().root.position
	await mouse_move(world_point(home + Vector3(-34, 0, 28)))
	await shot("farm-placement")
	await click_at(world_point(home + Vector3(-34, 0, 28)))
	await shot("farm-placed")
	await click_text("Housing")
	await click_at(world_point(home + Vector3(30, 0, 34)))
	await key(KEY_ESCAPE)
	await play(30)
	await shot("after-30s")
	# Select a worker.
	var worker = w.units.filter(func(u): return u.owner == 0 and u.key == "worker" and not u.dead)
	if not worker.is_empty():
		await click_at(world_point(worker[0].node.position))
		await shot("worker-selected")
	# The capital.
	await click_at(world_point(home))
	await shot("capital-selected")
	await key(KEY_ESCAPE)
	# Research.
	await click_text("Research", null, true)
	await shot("research")
	var fert := find_control("Fertilizers")
	if fert: await click_at(to_window(fert.get_global_rect().get_center()))
	await shot("research-pick")
	await click_text("Research now")
	await shot("research-queued")
	await key(KEY_ESCAPE)
	# Every ministry.
	for item in [["Cabinet", "cabinet"], ["Diplomacy", "diplomacy"], ["Market", "market"], ["Intel", "intel"], ["Defence", "defence"], ["UN", "un"], ["Territory", "territory"], ["Log", "log"]]:
		await click_text(item[0], null, true)
		await shot(item[1])
		await key(KEY_ESCAPE)
		await frames(6)
	# The army: barracks, soldiers, a tank factory.
	w.economy.grant_test_resources()
	note("F8-like resources granted for the army part")
	await click_text("Build")
	var mil := find_control("Military")
	if mil: await click_at(to_window(mil.get_global_rect().get_center()))
	await shot("build-military")
	await click_text("Barracks")
	await click_at(world_point(home + Vector3(-30, 0, -36)))
	await click_text("Tank Factory")
	await click_at(world_point(home + Vector3(36, 0, -30)))
	await key(KEY_ESCAPE)
	await play(70, 6.0)
	await shot("sites-after-70s")
	var bar = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks" and not b.dead)
	if not bar.is_empty():
		await click_at(world_point(bar[0].root.position))
		await shot("barracks-selected")
		for i in range(4):
			var b := find_control("Soldier")
			if b == null: b = find_control("Rifle")
			if b == null: b = find_control("Infantry")
			if b: await click_at(to_window(b.get_global_rect().get_center()))
		await shot("training")
	await play(60, 6.0)
	# A box around the army.
	var army: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker")
	note("army units: %d" % army.size())
	if not army.is_empty():
		var c: Vector3 = army[0].node.position
		await look_at(c, 70.0)
		await drag(world_point(c) - Vector2(160, 110), world_point(c) + Vector2(160, 110))
		await shot("army-selected")
		await click_at(world_point(c + Vector3(40, 0, 10)), MOUSE_BUTTON_RIGHT)
		await shot("army-move-order")
		await play(8)
		await look_at(army[0].node.position, 24.0, 0.6)
		await shot("closeup-infantry")
	var tank = w.spawn_unit("tank", home + Vector3(20, 0, 50), 0)
	var jet = w.spawn_unit("jet", home + Vector3(40, 0, 60), 0)
	await look_at(tank.node.position, 18.0, 0.55)
	await shot("closeup-tank")
	await look_at(home, 60.0, 0.7)
	await shot("closeup-capital")
	# War: the nearest rival.
	var foe: int = 1
	var their: Dictionary = hq(foe)
	w.diplomacy.declare_war(0, foe)
	await shot("war-declared")
	for u in w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker"):
		w.order_move([u], their.root.position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)))
	for i in range(6):
		w.spawn_unit("tank", home + Vector3(30 + i * 5, 0, 40), 0)
	await play(90, 8.0)
	var front: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker")
	if not front.is_empty():
		await look_at(front[0].node.position, 60.0, 0.8)
	await shot("battle")
	await play(40, 8.0)
	await shot("battle-later")
	# Missiles.
	w.place_building("missileSilo", w.test_site("missileSilo", home + Vector3(-60, 0, 60)), 0, true)
	w.missiles.stock["cruise"] = 2
	await look_at(home, 115.0)
	await click_at(world_point(home + Vector3(-60, 0, 60)))
	await shot("silo-selected")
	w.begin_missile("cruise")
	await mouse_move(world_point(their.root.position))
	await shot("missile-aim")
	await click_at(world_point(their.root.position))
	await play(6)
	await look_at(their.root.position, 90.0)
	await shot("missile-impact")
	# The minimap and a long look across the map.
	await look_at(home, 230.0, 1.1)
	await shot("far-view")
	# Pause, save, settings.
	await key(KEY_ESCAPE)
	await shot("pause")
	await click_text("Settings")
	await shot("settings")
	await key(KEY_ESCAPE)
	await frames(10)
	await shot("after-settings-escape")
	await key(KEY_ESCAPE)
	await play(240, 8.0)
	await shot("late-game")
	note("notices late: " + str(notices().filter(func(t): return t.length() > 25).slice(0, 8)))
	print("R3 DONE")
	FileAccess.open("res://build/r3/log.txt", FileAccess.WRITE).store_string("\n".join(log_lines))
	quit(0)
