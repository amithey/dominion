extends SceneTree
## Independent customer round after 0.9.82. Real input handlers, live controls,
## synthetic campaign fixtures; no player settings or saves are written.
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
var h: Node
var rows: Array = []
var home: Vector3
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String, area: String) -> void:
	rows.append({"id": rows.size() + 1, "area": area, "label": label, "passed": ok})
	print(("ok " if ok else "FAIL ") + "%03d %s" % [rows.size(), label])
func frames(n := 6) -> void:
	for i in range(n): await process_frame
func texts(n: Node) -> String:
	return "\n".join(PackedStringArray(n.find_children("*", "Label", true, false).filter(func(l): return not l.is_queued_for_deletion()).map(func(l): return l.text)))
func fits(c: Control) -> bool:
	return c.get_viewport().get_visible_rect().grow(2).encloses(c.get_global_rect())
func select(group: Array) -> void:
	w.select_building(null)
	for u in w.units: u.selected = group.has(u)
	h._update_selection()
func focus(at: Vector3, distance := 65.0) -> void:
	w.cam_focus = at; w.cam_dist = distance; w.cam_dist_target = distance
	w.update_camera(1.0)
func mouse(at: Vector2, shift := false, double := false) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
		e.shift_pressed = shift; e.double_click = double and down
		w._unhandled_input(e)
func drag_box(a: Vector2, b: Vector2, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = a; e.shift_pressed = shift
	w._unhandled_input(e)
	e = e.duplicate(); e.pressed = false; e.position = b
	w._unhandled_input(e)
func point(u: Dictionary) -> Vector2:
	return w.Picking.screen_centre(w.camera, u)
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customer4/" + name + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/customer4")
	if DisplayServer.get_name() == "headless": root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(1); return
	var old = w.menu
	w.menu = QuietMenu.new(); w.add_child(w.menu); w.menu.setup(w); old.queue_free()
	w.menu.set_fullscreen(false); root.size = Vector2i(1280, 800)
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	h = w.hud
	preload("res://tools/test_kit.gd").quiet(w, ["un", "defcon", "generals"])
	w.edge_scroll = false
	w.set_physics_process(false); w.set_process(false)
	for c in w.get_children():
		if not c is CanvasLayer: c.set_process(false); c.set_physics_process(false)
	if is_instance_valid(h._guide): h._guide.queue_free(); h._guide = null
	await frames()
	home = w.start + Vector3(20, 0, 35)
	for u in w.units: u.selected = false; u.node.hide()
	var worker: Dictionary = w.spawn_unit("worker", home, 0)
	var worker2: Dictionary = w.spawn_unit("worker", home + Vector3(5, 0, 0), 0)
	var soldier: Dictionary = w.spawn_unit("soldier", home + Vector3(-8, 0, 2), 0)
	var tank: Dictionary = w.spawn_unit("tank", home + Vector3(30, 0, -20), 0)
	focus(home)
	# 1-14: context-sensitive commands and honest worker guidance.
	select([worker])
	for action in ["Attack-move", "Bombard", "Repair"]:
		check(not h._commands[action].visible, "An unarmed worker is not offered " + action, "Commands")
	check(h._sel_info.text.contains("B opens") and h._sel_info.text.contains("construct"), "A worker explains how to begin building", "Commands")
	select([worker, worker2])
	check(not h._commands["Attack-move"].visible and not h._commands["Bombard"].visible, "A worker group has no combat orders", "Commands")
	check(h._sel_info.text.contains("Shift") and h._sel_info.text.contains("queues"), "A worker group explains queued construction jobs", "Commands")
	select([worker, soldier])
	check(h._commands["Attack-move"].visible, "A mixed escort group retains Attack-move", "Commands")
	check(not h._commands["Bombard"].visible, "An infantry escort has no unsupported Bombard", "Commands")
	select([soldier])
	check(h._commands["Attack-move"].visible, "Armed infantry retain Attack-move", "Commands")
	check(not h._commands["Repair"].visible, "Healthy infantry are not offered vehicle repair", "Commands")
	select([tank])
	check(h._commands["Bombard"].visible, "A tank retains supported ground fire", "Commands")
	check(not h._commands["Repair"].visible, "A healthy tank has no unnecessary repair order", "Commands")
	tank.hp *= 0.5; h._update_selection()
	check(h._commands["Repair"].visible and not h._commands["Repair"].disabled, "Damage makes tank repair available", "Commands")
	h._commands["Repair"].pressed.emit()
	check(tank.get("repairing", false), "The displayed repair order starts a repair", "Commands")
	tank.repairing = false; tank.hp = tank.max_hp
	# 15-28: selection follows the promise in Controls, through real handlers.
	h.close_windows(); w.cancel_placement(); select([])
	for u in w.units: u.node.hide()
	for u in [worker, worker2, soldier]: u.node.show()
	focus(home)
	mouse(point(worker)); check(worker.selected, "Plain click selects the clicked worker", "Selection")
	mouse(point(worker), true); check(not worker.selected, "Shift-click removes an already selected worker", "Selection")
	mouse(point(worker), true); check(worker.selected, "Shift-click adds an unselected worker", "Selection")
	mouse(point(soldier), true); check(worker.selected and soldier.selected, "Shift-click keeps the other selected kind", "Selection")
	mouse(point(worker), true); check(not worker.selected and soldier.selected, "Removing one unit preserves its escort", "Selection")
	mouse(point(worker)); check(worker.selected and not soldier.selected, "Plain click replaces a prior selection", "Selection")
	var bounds := Rect2(point(worker), Vector2.ZERO).expand(point(soldier)).grow(20)
	drag_box(bounds.position, bounds.end)
	check(worker.selected and soldier.selected, "Drag selection still takes visible units", "Selection")
	worker2.node.position = home + Vector3(45, 0, 0); focus(home)
	var at := point(worker2)
	drag_box(at - Vector2(20, 20), at + Vector2(20, 20), true)
	check(worker.selected and worker2.selected and soldier.selected, "Shift-drag adds without losing the first group", "Selection")
	worker2.node.hide(); select([worker2])
	drag_box(Vector2.ZERO, h.get_viewport().get_visible_rect().size)
	check(not worker2.selected, "Drag cannot select a hidden unit", "Selection")
	worker2.node.show(); worker2.stowed = true; select([worker2])
	drag_box(Vector2.ZERO, h.get_viewport().get_visible_rect().size)
	check(not worker2.selected, "Drag cannot select a stowed unit", "Selection")
	worker2.stowed = false; worker2.node.hide(); select([worker2])
	mouse(point(worker), false, true)
	check(worker.selected and not worker2.selected, "Double-click ignores hidden units of the same kind", "Selection")
	worker2.node.show(); worker2.stowed = true; select([worker2])
	mouse(point(worker), false, true)
	check(worker.selected and not worker2.selected, "Double-click ignores stowed units of the same kind", "Selection")
	select([soldier]); mouse(point(worker), true, true)
	check(worker.selected and soldier.selected, "Shift-double-click preserves a different selected kind", "Selection")
	mouse(Vector2(900, 500)); check(h._selected_units().is_empty(), "A plain click on empty ground clears unit selection", "Selection")
	worker2.stowed = false
	# 29-40: hover uses visible hulls and never reveals hidden information.
	for u in w.units: u.node.hide(); u.selected = false
	var ship = null
	for kind in ["worker", "soldier", "tank", "helicopter", "jet", "destroyer"]:
		var u: Dictionary = w.spawn_unit(kind, home, 0)
		focus(u.node.position, 45)
		check(h.unit_at_screen(point(u)) == u, kind + " is recognised at its visible centre", "Hover")
		if kind == "destroyer": ship = u
		else: u.node.hide()
	var box: AABB = w.Picking.local_box(ship)
	var end: Vector3 = box.position + box.size * Vector3(0.5, 0.5, 0.1)
	var tip: Vector2 = w.camera.unproject_position(ship.node.global_transform * end)
	check(h.unit_at_screen(tip) == ship, "A warship is recognised away from its centre on its hull", "Hover")
	ship.node.hide(); check(h.unit_at_screen(tip) == null, "Hiding the ship removes its hover target", "Hover")
	ship.node.show(); ship.stowed = true
	check(h.unit_at_screen(tip) == null, "Stowed craft expose no hover tag", "Hover")
	ship.stowed = false; ship.dead = true
	check(h.unit_at_screen(tip) == null, "Destroyed craft expose no live hover tag", "Hover")
	ship.dead = false
	check(h.hover_text(ship).contains("Yours") and h.hover_text(ship).contains("/"), "A live tag identifies ownership and health", "Hover")
	check(h.unit_at_screen(Vector2(-1000, -1000)) == null, "Empty space outside the viewport names no unit", "Hover")
	ship.node.hide()
	# 41-52: help is readable, scrollable, and always escapable on short screens.
	h.close_windows(); h.toggle_help()
	for dimensions in [Vector2i(1280, 800), Vector2i(1008, 600), Vector2i(1280, 720), Vector2i(1600, 900)]:
		for scale in [0.8, 1.0]:
			root.size = dimensions; w.ui_scale = scale; w.apply_ui_scale()
			await frames(10); h._fit_help(); await frames()
			check(fits(h._help) and fits(h._help.find_children("*", "Button", true, false)[0]), "Help and Close fit %dx%d at %.0f%%" % [dimensions.x, dimensions.y, scale * 100], "Help")
	root.size = Vector2i(1008, 600); w.ui_scale = 1.0; w.apply_ui_scale(); await frames(10); h._fit_help(); await frames()
	await shot("04-help-short-window")
	var scroll: ScrollContainer = h._help.find_child("HelpScroll", true, false)
	scroll.scroll_vertical = 10000; await frames()
	check(scroll.scroll_vertical > 0 or scroll.get_child(0).size.y <= scroll.size.y, "Short-window help reaches its final instructions by scrolling or fitting", "Help")
	check(texts(h._help).contains("Shift + middle") and texts(h._help).contains("Shift + click"), "Help agrees with camera panning and selection controls", "Help")
	check(texts(h._help).contains("F11") and texts(h._help).contains("B opens"), "Help includes fullscreen and the build shortcut", "Help")
	h._help.find_children("*", "Button", true, false)[0].pressed.emit()
	check(not h._help.visible, "Close remains usable after scrolling to the bottom", "Help")
	# 53-68: all volume sliders truly mute, recover and report the same value.
	for bus in ["Master", "SFX", "Music", "Interface"]:
		var i := AudioServer.get_bus_index(bus)
		w.menu._set_bus_volume(bus, 0)
		check(AudioServer.is_bus_mute(i) and w.menu._bus_volume(bus) == 0, bus + " zero really mutes and reads zero", "Sound")
		w.menu._set_bus_volume(bus, 37)
		check(not AudioServer.is_bus_mute(i) and absf(w.menu._bus_volume(bus) - 37) < 1, bus + " restores an audible intermediate level", "Sound")
		w.menu._set_bus_volume(bus, 100)
		check(absf(w.menu._bus_volume(bus) - 100) < 1, bus + " restores its designed full level", "Sound")
		AudioServer.set_bus_mute(i, true)
		check(w.menu._bus_volume(bus) == 0, bus + " reports mute even if stored gain is nonzero", "Sound")
		w.menu._set_bus_volume(bus, 100)
	# 69-74: Defaults restores the entire interface, not just effects.
	w.ui_scale = 0.7; w.apply_ui_scale(); w.edge_scroll = false; w.pan_speed = 1.8
	w.saves.autosave_every = 0; w.show_fps = true
	for bus in ["Master", "SFX", "Music", "Interface"]: w.menu._set_bus_volume(bus, 0)
	w.menu._reset_settings()
	check(is_equal_approx(w.ui_scale, 0.8) and is_equal_approx(root.content_scale_factor, 0.8), "Defaults restores the interface size immediately", "Defaults")
	check(w.quality == "balanced", "Defaults restores Balanced quality", "Defaults")
	check(w.edge_scroll and is_equal_approx(w.pan_speed, 1), "Defaults restores camera controls", "Defaults")
	check(not w.show_fps and Engine.max_fps == 0, "Defaults restores frame counter and limit", "Defaults")
	check(w.saves.autosave_every == 180, "Defaults restores the disclosed autosave interval", "Defaults")
	check(["Master", "SFX", "Music", "Interface"].all(func(bus): return w.menu._bus_volume(bus) == 100), "Defaults unmutes every audio bus", "Defaults")
	w.saves.autosave_every = 0; w.edge_scroll = false; w.menu.set_fullscreen(false); root.size = Vector2i(1280, 800)
	# 75-84: the tree agrees with the actual queue and has readable labels.
	h.toggle_research(); await frames()
	var r: Node = w.research
	r.queue.clear(); r.progress.fertilizers = {"stage": 0, "work": 0.0, "paid": false}
	r.queue.append("fertilizers")
	check(h._tree.active_card() == "fertilizers", "Tree highlights an available first project", "Research")
	r.progress.fertilizers.stage = 1; r.progress.fertilizers.paid = false
	w.economy.res.money = 0; r.queue.append("forestry")
	check(h._tree.active_card() == "forestry", "Tree highlights the next project while the first waits for funding", "Research")
	check(r.stage_status("fertilizers") == "Waiting", "Blocked first project says Waiting", "Research")
	w.economy.res.money = 1000000
	check(h._tree.active_card() == "fertilizers", "Funding resumes and highlights the waiting first project", "Research")
	r.queue.clear()
	check(h._tree.active_card() == "", "Empty queue highlights no active project", "Research")
	check(h._tree.TITLE_SIZE >= 14 and h._tree.STATE_SIZE >= 12, "Tree labels meet the increased readable font sizes", "Research")
	var font: Font = h._tree.get_theme_default_font()
	var original_card_width: float = h._tree.CARD_W
	for width in [134.0, 176.0, 210.0]:
		h._tree.CARD_W = width
		var titles: Array = ["Synthetic Fertilizers", "Automated Launch on Warning", "A Very Long National Research Programme", "Antidisestablishmentarianism"]
		for key in r.discoveries: titles.append(r.def_of(key).name)
		var contained := true
		for title in titles:
			var wrapped: String = h._tree.card_title(title, font)
			contained = contained and wrapped.split("\n").size() <= 2 and Array(wrapped.split("\n")).all(func(line): return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, h._tree.TITLE_SIZE).x <= width - 23)
		check(contained, "All discovery titles fit two lines at card width %d" % width, "Research")
	h._tree.CARD_W = original_card_width
	check(h._tree._get_tooltip(h._tree._cards.fertilizers.get_center()).contains(r.def_of("fertilizers").name), "Full discovery name remains available in its tooltip", "Research")
	await shot("02-research-after"); h.close_windows()
	# 85-90: all state ministries remain usable after context and layout changes.
	for mode in ["diplomacy", "market", "intel", "territory", "defence", "un"]:
		h.toggle_panel(mode, true); await frames(10)
		check(h._win.visible and fits(h._win) and texts(h._side_rows) != "", mode + " opens with content inside the viewport", "Ministries")
		h.close_windows()
	# 91-96: a customer can recover from a failed search and start real building.
	h.set_production_open(true); h._build_search.text = "zzzz no such building"; h._shown_key = ""; h._update_panel(); await frames()
	check(h._list.find_child("BuildEmpty", true, false) != null, "A failed search explains that nothing matches", "Construction")
	var clear: Button = null
	for b in h._list.find_children("*", "Button", true, false):
		if b.text == "Clear search": clear = b
	clear.pressed.emit()
	check(h._build_search.text == "" and h._list.find_child("BuildEmpty", true, false) == null, "Clear search restores the build catalog immediately", "Construction")
	for tab in h.BUILD_MENU:
		h.build_tab = tab; h._shown_key = ""; h._update_panel(); await frames()
		check(h._list.find_children("*", "Button", true, false).size() > 0, tab + " contains actual production choices", "Construction")
	w.begin_placement("farm")
	check(w.placing == "farm" and w.ghost != null, "A production choice begins live placement", "Construction")
	w.cancel_placement(); h.close_windows()
	# 97-100: result dialog does not trap the continuing player.
	for result in ["victory", "defeat"]:
		w.game_over = result; w.continuing_after_end = false
		h.show_end(result.capitalize(), "Customer round: keep playing.")
		check(h.modal_input_active() and w.match_stopped(), result + " initially stops the match with a result", "Continuation")
		for b in h._end_box.find_children("*", "Button", true, false):
			if b.text == "Continue playing": b.pressed.emit(); break
		check(not w.match_stopped() and not h.modal_input_active(), result + " continuation restores normal campaign input", "Continuation")
	var failed := rows.filter(func(row): return not row.passed)
	var f := FileAccess.open("res://build/customer4/results.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(rows, "  "))
	if "--profile-hover" in OS.get_cmdline_user_args():
		for u in w.units: u.node.hide()
		for i in range(200):
			w.spawn_unit(["worker", "soldier", "tank", "destroyer"][i % 4], home + Vector3((i % 20) * 8 - 80, 0, (i / 20) * 8 - 40), 0)
		focus(home, 120.0)
		h.unit_at_screen(Vector2(640, 400)) # warm mesh-bounds caches
		var began := Time.get_ticks_usec()
		for i in range(100): h.unit_at_screen(Vector2(250 + (i % 20) * 35, 180 + (i / 20) * 65))
		print("HOVER_PROFILE: 200 units, 100 probes, %.3f ms/probe" % ((Time.get_ticks_usec() - began) / 100000.0))
	print("CUSTOMER_ROUND4: %d checks, %d failures" % [rows.size(), failed.size()])
	print("CUSTOMER_ROUND4 %s" % ("PASS" if rows.size() == 100 and failed.is_empty() else "FAIL"))
	quit(0 if rows.size() == 100 and failed.is_empty() else 1)
