extends SceneTree
## Customer round 5, part 3: the customer who mashes everything. Random keys, random clicks, drags, wheel
## and double clicks go into the running game through the real input pipeline (Viewport.push_input, so the
## interface sees them before the world does), between short stretches of play. Every event is one check:
## it passes when the engine reports no script error and the game keeps a sane state (no NaN positions,
## no selected unit that is dead, no negative treasury, the match still there). The sequence is seeded, so
## a failure names the exact events that led to it and can be replayed.
## Usage: --sessions=N --events=M --seed=S. Table: res://build/audit/customer5-monkey.txt
## Needs a user:// backup: the Load screen can delete a save and F5 writes one (the audit runner restores it).
const Kit := preload("res://tools/audit_kit.gd")
const Registry := preload("res://scripts/nation_registry.gd")
const Maps := preload("res://scripts/map_generator.gd")
const MatchSetup := preload("res://scripts/match_setup.gd")
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var K
var w: Node
var recent: Array = []
var event_log: Array = []
func _initialize() -> void: call_deferred("run")

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const SPECIAL := [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F6, KEY_F7, KEY_F8, KEY_F10, KEY_F12, KEY_SPACE, KEY_TAB, KEY_ENTER, KEY_ESCAPE, KEY_EQUAL, KEY_MINUS, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_DELETE, KEY_HOME, KEY_BACKSPACE, KEY_PAGEUP, KEY_PAGEDOWN]
## F5 saves a quick-save (sandboxed by the backup), F9 reloads the scene, F11 toggles the window: not tried.

func key_event(code: int, down: bool, shift := false, ctrl := false, alt := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	return e

func mouse_event(at: Vector2, button: int, down: bool, shift := false, ctrl := false, double := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = button
	e.pressed = down
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	e.double_click = double and down
	e.button_mask = (1 << (button - 1)) if down else 0
	return e

func motion(at: Vector2, rel := Vector2.ZERO, held := 0) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	e.button_mask = held
	return e

func feed(e: InputEvent) -> void:
	root.push_input(e, false)

func rnd_point() -> Vector2:
	var size := root.get_visible_rect().size
	return Vector2(randf() * size.x, randf() * size.y)

func frames(n := 2) -> void:
	for i in range(n): await process_frame

## One random action; returns what it was, in words, so a failure can be replayed.
func do_event() -> String:
	var r := randi() % 100
	if r < 38:
		var code: int
		var label: String
		var pick := randi() % 100
		if pick < 55:
			var ch := LETTERS[randi() % LETTERS.length()]
			code = ch.unicode_at(0)   # KEY_A.. are the ASCII codes
			label = ch
		elif pick < 75:
			code = KEY_0 + randi() % 10
			label = str(code - KEY_0)
		else:
			code = SPECIAL[randi() % SPECIAL.size()]
			label = OS.get_keycode_string(code)
		var shift := randi() % 6 == 0
		var ctrl := randi() % 6 == 0
		var alt := randi() % 25 == 0
		if alt and code == KEY_F4: alt = false   # closing the window is the operating system's job
		feed(key_event(code, true, shift, ctrl, alt))
		feed(key_event(code, false, shift, ctrl, alt))
		return "key %s%s%s%s" % [("Alt+" if alt else ""), ("Ctrl+" if ctrl else ""), ("Shift+" if shift else ""), label]
	if r < 66:
		var at := rnd_point()
		var button := MOUSE_BUTTON_LEFT if randi() % 10 < 7 else MOUSE_BUTTON_RIGHT
		var shift := randi() % 5 == 0
		var ctrl := randi() % 9 == 0
		feed(motion(at))
		feed(mouse_event(at, button, true, shift, ctrl))
		feed(mouse_event(at, button, false, shift, ctrl))
		return "click %s at (%d,%d)%s%s" % [("left" if button == MOUSE_BUTTON_LEFT else "right"), at.x, at.y, (" +shift" if shift else ""), (" +ctrl" if ctrl else "")]
	if r < 78:
		var a := rnd_point()
		var b := rnd_point()
		feed(motion(a))
		feed(mouse_event(a, MOUSE_BUTTON_LEFT, true))
		for step in range(1, 5):
			var p := a.lerp(b, step / 4.0)
			feed(motion(p, (b - a) / 4.0, 1))
		feed(mouse_event(b, MOUSE_BUTTON_LEFT, false))
		return "drag (%d,%d) to (%d,%d)" % [a.x, a.y, b.x, b.y]
	if r < 86:
		var at := rnd_point()
		var e := InputEventMouseButton.new()
		e.position = at
		e.global_position = at
		e.button_index = MOUSE_BUTTON_WHEEL_UP if randi() % 2 == 0 else MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = true
		e.factor = 1.0
		feed(e)
		return "wheel %s at (%d,%d)" % [("up" if e.button_index == MOUSE_BUTTON_WHEEL_UP else "down"), at.x, at.y]
	if r < 92:
		var at := rnd_point()
		feed(motion(at))
		feed(mouse_event(at, MOUSE_BUTTON_LEFT, true, false, false, true))
		feed(mouse_event(at, MOUSE_BUTTON_LEFT, false))
		return "double-click at (%d,%d)" % [at.x, at.y]
	if r < 96:
		var d := 0.2 + randf() * 1.8
		var t := 0.0
		while t < d and is_instance_valid(w) and w.is_inside_tree():
			await process_frame
			t += 1.0 / 30.0
		return "wait %.1f s" % d
	# a deliberate fresh order on the selection: move to a random spot on the map
	var map_size := 400.0
	var spot: Vector3 = w.start + Vector3((randf() - 0.5) * map_size, 0, (randf() - 0.5) * map_size)
	var chosen: Array = w.units.filter(func(u): return u.owner == 0 and u.selected and not u.dead)
	if not chosen.is_empty(): w.order_move(chosen, spot, randi() % 3 == 0)
	return "order %d selected units to (%d,%d)" % [chosen.size(), spot.x, spot.z]

func sane() -> String:
	if not is_instance_valid(w) or not w.is_inside_tree() or current_scene != w:
		return "the match is gone (the scene changed or quit)"
	for u in w.units:
		if u.dead: continue
		var p: Vector3 = u.node.position
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): return "unit %s has a non-finite position" % u.key
		if u.selected and u.dead: return "a dead unit is still selected"
	for r in w.economy.res:
		var v := float(w.economy.res[r])
		if is_nan(v) or is_inf(v): return "treasury %s is %s" % [r, v]
	if w.economy.res.money < -1.0e6: return "treasury money is %d" % w.economy.res.money
	return ""

## A fingerprint of everything an input can visibly change.
func signature() -> String:
	var sel := 0
	for u in w.units:
		if u.selected and not u.dead: sel += 1
	var shown := 0
	for c in w.hud.find_children("*", "Control", true, false):
		if c.visible and c.is_visible_in_tree(): shown += 1
	return "%s|%.1f|%d|%s|%s|%d|%s" % [str(w.cam_focus.snapped(Vector3(0.1, 0.1, 0.1))), w.cam_dist_target, sel, str(w.game_speed), str(paused), shown, str(w.placing)]

func boot_session(nation: int, map_key: String, difficulty: String) -> bool:
	K.take_errors()
	set_meta("match_config", {"map": map_key, "players": clampi(4, 2, MatchSetup.capacity(map_key)), "nation": nation})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: return false
	var old = w.menu
	w.menu = QuietMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	old.queue_free()
	w.menu.set_fullscreen(false)
	root.size = Vector2i(1280, 800)
	w.start_match(difficulty)
	w.menu.close()
	w.saves.autosave_every = 0
	await frames(5)
	K.take_errors()
	return true

func run() -> void:
	var sessions := 6
	var per_session := 400
	var seed_base := 20261030
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sessions="): sessions = int(a.split("=")[1])
		if a.begins_with("--events="): per_session = int(a.split("=")[1])
		if a.begins_with("--seed="): seed_base = int(a.split("=")[1])
	K = Kit.new(self, "customer5-monkey")
	var ids: Array = Registry.column("id")
	var maps: Array = ["island", "mirrored"] + Maps.MAPS.keys()
	var diffs := ["easy", "normal", "hard"]
	var total := 0
	for s in range(sessions):
		seed(seed_base + s)
		var nation := (s * 11 + 5) % ids.size()
		var map_key: String = maps[(s * 7 + 2) % maps.size()]
		var tag := "S%d %s/%s" % [s, ids[nation], map_key]
		if not await boot_session(nation, map_key, diffs[s % 3]):
			K.fail("monkey", tag, "the session did not start")
			continue
		K.ok("monkey", tag + " | start", "")
		event_log.clear()
		var fails := 0
		var effective := 0
		for n in range(per_session):
			var before: String = signature() if is_instance_valid(w) and w.is_inside_tree() else ""
			var what: String = await do_event()
			event_log.append(what)
			if event_log.size() > 8: event_log.pop_front()
			await frames(1)
			total += 1
			if before != "" and is_instance_valid(w) and w.is_inside_tree() and signature() != before: effective += 1
			var errs: Array = K.take_errors()
			var broken := sane()
			if not errs.is_empty():
				fails += 1
				K.fail("monkey", "%s | event %d: %s" % [tag, n, what], "engine error: %s || previous: %s" % [str(errs[0]).substr(0, 220), " / ".join(PackedStringArray(event_log.slice(0, event_log.size() - 1).slice(-4)))])
			elif broken != "":
				fails += 1
				K.fail("monkey", "%s | event %d: %s" % [tag, n, what], broken)
				if broken.begins_with("the match is gone"):
					# a customer who found the exit: bring them back for the rest of the session
					if not await boot_session(nation, map_key, diffs[s % 3]):
						break
			else:
				K.ok("monkey", "%s | event %d: %s" % [tag, n, what], "")
		K.ok("monkey", tag + " | session", "%d events, %d with a problem, %d changed something visible" % [per_session, fails, effective])
		if effective < per_session / 16: K.fail("monkey", tag + " | the input reaches the game", "only %d of %d events changed anything: the test is not driving the game" % [effective, per_session])
		else: K.ok("monkey", tag + " | the input reaches the game", "%d of %d events changed the camera, the selection, a window or the speed" % [effective, per_session])
	K.ok("monkey", "total", "%d events fed" % total)
	quit(K.finish())
