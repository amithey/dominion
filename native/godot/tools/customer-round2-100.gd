extends SceneTree
## A second customer review: modal input, research state, busy logs and ministries.
## Fixture resources are synthetic. No player settings or save files are written.
class RecordingMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
var h: Node
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String, category: String) -> void:
	rows.append({"id": rows.size() + 1, "category": category, "label": label, "passed": ok})
	print(("ok " if ok else "FAIL ") + label)
func frames(n := 5) -> void:
	for i in range(n): await process_frame
func labels(n: Node) -> String:
	return "\n".join(PackedStringArray(n.find_children("*", "Label", true, false).filter(func(c): return not c.is_queued_for_deletion()).map(func(c): return c.text)))
func button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if b.text == text and not b.is_queued_for_deletion(): return b
	return null
func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = true
	return e
func shot(name: String) -> void:
	await frames()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customer-round2/%s.png" % name)
func detail(k: String) -> void:
	h._rs_sel = k; h._rs_sig = ""; h._refresh_research()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/customer-round2")
	set_meta("match_config", {"map": "island", "players": 4, "nation": 4, "opening": "light"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(1); return
	w.menu.queue_free(); w.menu = RecordingMenu.new(); w.add_child(w.menu); w.menu.setup(w)
	w.menu.set_fullscreen(false); root.size = Vector2i(1280, 800)
	w.ui_scale = 0.8; w.apply_ui_scale(); w.start_match("easy"); w.menu.close()
	w.saves.autosave_every = 0
	w.set_physics_process(false)
	for system in w.get_children():
		if system != w.menu and not system is CanvasLayer:
			system.set_process(false); system.set_physics_process(false)
	w.economy.grant_test_resources()
	h = w.hud
	if is_instance_valid(h._guide): h._guide.queue_free(); h._guide = null
	await frames()
	# 1-24: twelve campaign shortcuts must not act behind either modal.
	var codes := [KEY_TAB, KEY_B, KEY_G, KEY_L, KEY_M, KEY_I, KEY_T, KEY_K, KEY_U, KEY_Y, KEY_SPACE, KEY_PLUS]
	for modal in ["contact", "result"]:
		h.close_windows()
		if modal == "contact": h.open_diplomatic_contact(1)
		else: w.game_over = "victory"; h.show_end("VICTORY", "Every rival capital has fallen.")
		await frames()
		for code in codes:
			var speed: float = w.game_speed
			w._input(key(code))
			check(w.game_speed == speed and h.side_mode == "" and not h.prod_open and (h._rs == null or not h._rs.visible) and (h._cabinet == null or not h._cabinet.visible) and (h._log_box == null or not h._log_box.visible), "%s modal blocks campaign shortcut %s" % [modal, OS.get_keycode_string(code)], "Modal input")
		if modal == "contact": h._diplomatic_contact_screen.hide()
	# 25-34: result ownership, focus, layering, continuation and load cleanup.
	check(h._end_dim.mouse_filter == Control.MOUSE_FILTER_STOP, "Result shade absorbs map clicks", "End dialog")
	check(h._end_box.z_index > h._diplomatic_contact_screen.z_index, "Result stays above the Foreign Office", "End dialog")
	check(root.gui_get_focus_owner() == button(h._end_box, "Continue playing"), "Continue receives keyboard focus", "End dialog")
	h.show_end("VICTORY", "Repeated result")
	check(h.get_children().filter(func(c): return c.name == "EndDialog").size() == 1 and h.get_children().filter(func(c): return c.name == "EndShade").size() == 1, "Repeated results leave exactly one dialog and shade", "End dialog")
	var focus: Vector3 = w.cam_focus
	Input.parse_input_event(key(KEY_W)); await frames(2); w.pan_camera(1.0)
	check(w.cam_focus.is_equal_approx(focus), "Result blocks held-key camera movement", "End dialog")
	var up := key(KEY_W); up.pressed = false; Input.parse_input_event(up)
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.position = Vector2(640, 400)
	var zoom: float = w.cam_dist_target; w._unhandled_input(wheel)
	var time: float = w.game_time; w._physics_process(1)
	check(w.cam_dist_target == zoom and w.game_time == time, "Pending result blocks map zoom and combat simulation", "End dialog")
	button(h._end_box, "Continue playing").pressed.emit()
	check(w.continuing_after_end and not w.match_stopped(), "Continue resumes the campaign after victory", "End dialog")
	check(not h.end_visible() and h._end_dim == null, "Continue removes both modal controls immediately", "End dialog")
	w._input(key(KEY_SPACE)); check(w.game_speed == 0, "Pause shortcut works again after continuation", "End dialog")
	w.set_speed(1); h.show_end("VICTORY", "Old match"); var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture())); w.saves.restore(saved)
	check(not h.end_visible(), "Loading a continued save clears an old result dialog", "End dialog")
	w.game_over = ""; w.continuing_after_end = false
	# 35-52: truthfully labelled stages, queue limits, materials, persistence.
	var r: Node = w.research
	r.queue.clear(); r.era = 0
	for k in r.progress: r.progress[k] = {"stage": 0, "work": 0.0, "paid": false}
	h.toggle_research(); detail("fertilizers"); await frames()
	check(labels(h._rs_detail).contains("Not queued") and not labels(h._rs_detail).contains("In development"), "Unqueued discovery never claims to be developing", "Research")
	r.enqueue("fertilizers"); r.progress.fertilizers.work = 17.0; r.dequeue("fertilizers")
	check(r.progress.fertilizers.work == 17.0, "Removing a project keeps its completed work", "Research")
	var cash: float = w.economy.res.money
	for k in ["fertilizers", "forestry", "taxAdministration", "eliteTraining"]: r.enqueue(k)
	check(r.queue.size() == 4, "Four different projects fit in the research queue", "Research")
	r.enqueue("fertilizers"); check(r.queue.size() == 4, "Queuing a project twice does not duplicate it", "Research")
	h._rs_sig = ""; h._refresh_research()
	check(h._rs_tracks.find_children("*", "Button", true, false).filter(func(b): return b.text == "Develop" and not b.is_queued_for_deletion()).all(func(b): return b.disabled and b.tooltip_text.contains("full")), "Full queue also disables field development buttons", "Research")
	detail("diplomaticCorps"); await frames()
	var add := button(h._rs_detail, "Add to queue")
	check(add != null and add.disabled, "Full queue disables adding another project", "Research")
	check(add != null and add.tooltip_text.contains("Remove a project first"), "Full queue explains how to make room", "Research")
	check(labels(h._rs_queue).contains("4 / 4"), "Queue counter agrees with its actual limit", "Research")
	check(r.enqueue("diplomaticCorps").contains("full"), "The service also refuses a fifth project", "Research")
	r.queue.clear(); r.era = 1; r.progress.publicEducation.stage = 1; r.progress.publicEducation.work = 0.0
	r.enqueue("publicEducation"); r.enqueue("taxAdministration"); detail("publicEducation"); await frames()
	check(r.stage_status("publicEducation") == "Waiting", "Project lacking a school is labelled Waiting", "Research")
	check(r.stage_status("taxAdministration") == "In development", "Project after a blocked one is labelled active", "Research")
	r.points = 1000; var work: float = r.progress.taxAdministration.work; r.tick(1)
	check(r.progress.taxAdministration.work > work, "Blocked first project lets the next research advance", "Research")
	r.queue = ["eliteTraining", "forestry"]; r.progress.eliteTraining.stage = 1; w.economy.res.money = 0
	check(r.active_item() == "forestry", "An unaffordable prototype lets a free study advance", "Research")
	w.economy.res.money = cash; r.queue = ["fertilizers"]; r.points = 100000; detail("fertilizers"); await frames()
	check(not h._rs_detail.find_children("*", "ProgressBar", true, false).is_empty(), "Current research stage retains its visible progress bar", "Research")
	for i in range(100): r.tick(1)
	check(r.done("fertilizers") and "fertilizers" not in r.queue, "Completed discovery leaves the queue", "Research")
	check(r.bonus("foodPct") >= 0.5, "Completed fertilizers improve farm production", "Research")
	r.queue = ["forestry"]; r.progress.forestry.work = 23
	var research_save: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(float(research_save.research.progress.forestry.work) == 23, "Save captures unfinished research work", "Research")
	r.queue.clear(); r.progress.forestry.work = 0; w.saves.restore(research_save)
	check("forestry" in w.research.queue and w.research.progress.forestry.work == 23, "Loading restores the research queue and work together", "Research")
	h.close_windows()
	# 53-68: a long campaign must keep the log usable and bounded.
	h.notice_log.clear(); h._recent_notices.clear(); h.toggle_log(); await frames()
	check(labels(h._log_rows).contains("No messages yet"), "Empty message log explains its state", "Message log")
	h.notice("Repeat test"); h.notice("Repeat test"); check(h.notice_log.size() == 1, "Repeated notices are recorded once", "Message log")
	for i in range(130): h.notice("Review event %03d — a long campaign log entry with details about production and diplomacy." % i)
	check(h.notice_log.size() == 120, "Message history is capped at 120 entries", "Message log")
	check(h._log_rows.get_child(0).text.contains("129"), "Newest event appears at the top", "Message log")
	check(not labels(h._log_rows).contains("event 000"), "Oldest events leave the bounded history", "Message log")
	h._fill_log(); h._fill_log()
	check(h._log_rows.get_child_count() == 120, "Two refreshes in one frame do not duplicate rows", "Message log")
	check(h._log_rows.get_children().all(func(c): return c.get_theme_font_size("font_size") >= 13), "All log entries have a readable font size", "Message log")
	check(h._log_rows.get_children().all(func(c): return c.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART), "All long log entries wrap at word boundaries", "Message log")
	await frames(10); var log_scroll: ScrollContainer = h._log_rows.get_parent(); log_scroll.scroll_vertical = 160; await frames()
	var old_scroll: int = log_scroll.scroll_vertical; h.notice("Incoming event while reading older history"); await frames()
	check(log_scroll.scroll_vertical == old_scroll and old_scroll > 0, "Incoming notices retain the reader's scroll offset", "Message log")
	h._recent_notices["Expired old event"] = -100; h.notice("Prune old notice cache")
	check(not h._recent_notices.has("Expired old event"), "Expired deduplication records are pruned", "Message log")
	var count: int = h.notice_log.size(); h.notice("Prune old notice cache")
	check(h.notice_log.size() == count and h._log_rows.get_child(0).text.contains("Prune old"), "Recent duplicates do not replace the latest log row", "Message log")
	check(h._notices.get_child_count() <= 3, "Bottom notice feed never exceeds three cards", "Message log")
	button(h._log_box, "Close  (L)").pressed.emit(); check(not h._log_box.visible, "Log close button works", "Message log")
	h.toggle_log(); check(h.notice_log.size() == 120, "Reopening the log retains campaign history", "Message log")
	await frames(); check(h._log_rows.size.x <= log_scroll.size.x + 2, "Log rows fit their scroll viewport without horizontal clipping", "Message log")
	var first_text: String = h._log_rows.get_child(0).text; h._windows._set_position(h._log_box, Vector2(700, 160)); h._windows.reflow(h._log_box)
	check(h._log_rows.get_child(0).text == first_text, "Dragging the log does not rebuild or lose its contents", "Message log")
	await shot("01-log"); h.close_windows()
	# 69-100: each ministry has an accessible title, content, close and stable pause state.
	for screen in ["diplomacy", "market", "intel", "defence", "un", "territory", "cabinet", "research"]:
		if screen == "cabinet": h.toggle_cabinet()
		elif screen == "research": h.toggle_research()
		else: h.toggle_panel(screen)
		await frames(12)
		var panel: Control = h._cabinet if screen == "cabinet" else (h._rs if screen == "research" else h._win)
		check(panel.is_visible_in_tree(), "%s opens its visible panel" % screen, "Ministry UI")
		var rect: Rect2 = root.get_visible_rect().grow(2)
		var closers: Array = panel.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and (b.text.begins_with("Close") or b.text in ["×", "✕", "X"]))
		check(not closers.is_empty() and rect.encloses(closers[0].get_global_rect()), "%s close button stays on screen" % screen, "Ministry UI")
		check(labels(panel).length() > 80, "%s includes explanatory content and figures" % screen, "Ministry UI")
		var speed: float = w.game_speed; var closed: bool = h.close_windows()
		check(closed and not panel.visible and w.game_speed == speed and not paused, "%s closes without pausing the campaign" % screen, "Ministry UI")
	await frames(); h.open_diplomatic_contact(1); w.game_over = "victory"; h.show_end("VICTORY", "The campaign can continue normally after this result."); await shot("02-end-modal")
	var file := FileAccess.open("res://build/customer-round2/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t")); file.close()
	var failures: Array = rows.filter(func(row): return not row.passed)
	print("CUSTOMER_ROUND2: %d checks, %d failures" % [rows.size(), failures.size()])
	quit(0 if failures.is_empty() and rows.size() == 100 else 1)
