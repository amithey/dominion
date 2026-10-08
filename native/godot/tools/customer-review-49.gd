extends SceneTree
## 49 customer-facing checks. Together with gameplay-ui-50.gd's 51 checks,
## this is the 100-scenario customer review. Never write player preferences.
class RecordingMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
class BrokenSave extends "res://scripts/save.gd":
	func save(_slot: String) -> bool: return false
var w: Node
var hud: Node
var rows: Array = []
const UI := preload("res://scripts/ui_theme.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String, category: String) -> void:
	rows.append({"id": rows.size() + 52, "category": category, "label": label, "passed": ok})
	print(("ok " if ok else "FAIL ") + label)
func frames(n := 5) -> void:
	for i in range(n): await process_frame
func shot(name: String) -> void:
	await frames()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/customer-review")
	root.get_texture().get_image().save_png("res://build/customer-review/%s.png" % name)
func fits(c: Control) -> bool:
	return c.is_visible_in_tree() and root.get_visible_rect().grow(3).encloses(c.get_global_rect())
func text_in(n: Node) -> String:
	return "\n".join(PackedStringArray(n.find_children("*", "Label", true, false).filter(func(c): return not c.is_queued_for_deletion()).map(func(c): return c.text)))
func keyboard(code: Key, down := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	await frames(2)
func search(query: String) -> void:
	hud._build_search.text = query
	hud._shown_key = ""
	hud._update_panel()
	await frames()
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.menu.queue_free()
	w.menu = RecordingMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	w.menu.set_fullscreen(false)
	root.size = Vector2i(1280, 800)
	w.ui_scale = 0.8
	w.apply_ui_scale()
	w.start_match("easy")
	w.menu.close()
	w.saves.autosave_every = 0
	w.ai.set_physics_process(false)
	w.set_physics_process(false)
	w.economy.set_process(false)
	w.economy.grant_test_resources()
	seed(20261008)
	hud = w.hud
	if is_instance_valid(hud._guide): hud._guide.queue_free(); hud._guide = null
	w.cam_focus = w.start
	w.cam_dist = 115
	w.cam_dist_target = 115
	w.cam_pitch = 0.95
	w.edge_scroll = false
	w.update_camera(0)
	await shot("01-map")
	# Graphics switches must be reversible, with no leftover settings.
	w.quality = "low"; w.apply_quality()
	check(not w.env.glow_enabled and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Low disables costly glow and screen AA", "Graphics")
	check(w.grass_nodes.all(func(g): return not g.visible), "Low hides existing grass immediately", "Graphics")
	w.quality = "balanced"; w.apply_quality()
	check(is_equal_approx(root.scaling_3d_scale, 0.77), "Balanced restores its own render resolution", "Graphics")
	check(w.env.glow_enabled, "Balanced restores glow after Low", "Graphics")
	w.quality = "high"; w.apply_quality()
	check(is_equal_approx(root.scaling_3d_scale, 1), "High restores full resolution after Low", "Graphics")
	check(root.msaa_3d == Viewport.MSAA_2X, "High restores multisample AA", "Graphics")
	w.quality = "balanced"; w.apply_quality()
	check(root.msaa_3d == Viewport.MSAA_DISABLED, "Balanced removes High's multisample cost", "Graphics")
	# Empty lists must tell the player how to recover.
	hud.toggle_build()
	await search("a-building-that-does-not-exist")
	check(hud._list.find_child("BuildEmpty", true, false) != null, "Unmatched search explains the empty list", "Construction")
	var clear: Array = hud._list.find_children("*", "Button", true, false).filter(func(b): return b.text == "Clear search")
	check(clear.size() == 1, "Unmatched search offers a clear button", "Construction")
	if not clear.is_empty(): clear[0].pressed.emit()
	await frames()
	check(hud._build_search.text == "" and text_in(hud._list).contains("Farm"), "Clear search restores the building catalog", "Construction")
	await search("fArM")
	check(text_in(hud._list).contains("Farm"), "Building search ignores capitalization", "Construction")
	# Keystrokes used to leak into the battlefield while typing.
	hud._build_search.grab_focus()
	var speed: float = w.game_speed
	await keyboard(KEY_SPACE); await keyboard(KEY_SPACE, false)
	check(w.game_speed == speed, "Space in a search field does not pause the world", "Input")
	var focus: Vector3 = w.cam_focus
	await keyboard(KEY_W)
	w.pan_camera(1.0)
	await keyboard(KEY_W, false)
	check(w.cam_focus.is_equal_approx(focus), "Typing W in search does not pan the camera", "Input")
	await keyboard(KEY_ESCAPE); await keyboard(KEY_ESCAPE, false)
	check(root.gui_get_focus_owner() == null and not hud.prod_open, "Escape exits a focused building search", "Input")
	w.game_time = 600
	hud.start_guide()
	check(not is_instance_valid(hud._guide), "An old campaign does not reopen the guide automatically", "Guidance")
	hud.start_guide(true)
	check(is_instance_valid(hud._guide) and hud._guide.is_visible_in_tree(), "The guide can be reopened in a later campaign", "Guidance")
	check(hud._guide.step == 0 and hud._guide.base.farm == w.buildings.filter(func(b): return b.owner == 0 and b.key == "farm" and not b.dead).size(), "Reopened guide uses the current campaign as its baseline", "Guidance")
	hud._guide.queue_free(); hud._guide = null
	# Presentation and explanations.
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	w.select_building(capital); hud._update_selection()
	check(hud._sel_sub.text == "Capital", "The capital is labelled Capital rather than Military", "Clarity")
	for key in ["cityCenter", "villageCenter"]:
		var b: Dictionary = w.place_building(key, w.test_site(key, w.start), 0, true)
		w.select_building(b); hud._update_selection()
		check(hud._sel_sub.text == ("City" if key == "cityCenter" else "Village"), key + " has a meaningful settlement label", "Clarity")
	w.select_building(null)
	hud.set_production_open(true)
	await search("")
	var descriptions: Array = hud._list.find_children("*", "Label", true, false).filter(func(l): return l.autowrap_mode != TextServer.AUTOWRAP_OFF)
	var prices: Array = hud._list.find_children("ProductionCost", "HBoxContainer", true, false)
	for c in prices:
		var card: Control = c.get_parent().get_parent().get_parent()
		if not card.get_global_rect().grow(1).encloses(c.get_global_rect()): print("PRICE OVERFLOW: ", card.get_meta("cost"), " card=", card.get_global_rect(), " prices=", c.get_global_rect())
	check(not descriptions.is_empty() and descriptions.all(func(l): return l.get_theme_font_size("font_size") >= 14) and not prices.is_empty() and prices.all(func(c): return c.get_parent().get_parent().get_parent().get_global_rect().grow(1).encloses(c.get_global_rect())), "Building descriptions use legible type and prices fit their cards", "Typography")
	var disabled: Color = UI.build().get_color("font_disabled_color", "Button")
	check(disabled.r > 0.5 and disabled.g > 0.5, "Unavailable button text remains readable", "Typography")
	w.menu.open_pause(); w.menu.settings_tab = "controls"; w.menu.open_settings()
	var controls := text_in(w.menu._panel)
	for term in ["Left click / drag", "Space / + / -", "Home", "Cancel, close a window, then pause"]:
		check(controls.contains(term), "Controls explain " + term, "Guidance")
	await shot("02-controls")
	w.menu.settings_tab = "game"; w.menu.open_settings()
	var replay: Button = w.menu._panel.find_child("ReplayGuide", true, false)
	if replay != null: replay.pressed.emit()
	check(replay != null and not paused and is_instance_valid(hud._guide), "Game settings reopen the guide without resetting the match", "Guidance")
	if is_instance_valid(hud._guide): hud._guide.queue_free(); hud._guide = null
	# Every major ministry must fit and have actionable content.
	hud.close_windows()
	for mode in ["diplomacy", "market", "intel", "territory"]:
		hud.toggle_panel(mode, true); await frames(10)
		check(fits(hud._win) and not text_in(hud._side_rows).is_empty(), mode + " opens with readable content inside the screen", "Layout")
		await shot("03-" + mode)
		hud.close_windows()
	hud.toggle_research(); await frames()
	check(fits(hud._rs), "Research fits the screen", "Layout"); await shot("04-research"); hud.close_windows()
	hud.toggle_cabinet(); await frames()
	check(fits(hud._cabinet), "Cabinet fits the screen", "Layout"); await shot("05-cabinet"); hud.close_windows()
	hud.toggle_help(); await frames()
	check(fits(hud._help), "Controls help fits the screen", "Layout"); await shot("06-help"); hud.close_windows()
	hud.set_production_open(true); await frames()
	check(fits(hud._prod), "Construction catalog fits the screen", "Layout"); await shot("07-build"); hud.close_windows()
	for result in ["victory", "defeat"]:
		w.game_over = result
		hud.show_end(result.to_upper(), "A long explanation of the campaign result should wrap inside its window. ".repeat(4))
		await frames()
		var subtitle: Array = hud.find_children("*", "Label", true, false).filter(func(l): return l.text.begins_with("A long explanation") and not l.is_queued_for_deletion())
		check(subtitle.size() == 1 and fits(subtitle[0]) and subtitle[0].autowrap_mode != TextServer.AUTOWRAP_OFF, result + " explanation wraps and stays on screen", "Layout")
		await shot("08-" + result)
		var continue_buttons: Array = hud.find_children("*", "Button", true, false).filter(func(b): return b.text == "Continue playing" and not b.is_queued_for_deletion())
		continue_buttons[-1].pressed.emit(); await frames()
	w.game_over = ""; w.continuing_after_end = false
	root.size = Vector2i(1008, 600); await frames()
	w.menu.open_pause(); w.menu.settings_tab = "controls"; w.menu.open_settings(); await frames(10)
	check(fits(w.menu._card) and fits(w.menu._footer), "Controls settings fit a small window with Back always visible", "Layout")
	await shot("09-small-controls")
	w.menu.open_new_game(); await frames(10)
	var begin: Control = w.menu._root.find_child("BeginCampaign", true, false)
	check(begin != null and fits(begin), "Begin campaign stays accessible in a small window", "Layout")
	await shot("10-small-campaign")
	root.size = Vector2i(1280, 800); w.menu.close(); await frames()
	# Save failure, continuation and diplomacy have visible, recoverable states.
	var original: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	var real_saves: Node = w.saves
	w.saves = BrokenSave.new()
	w.add_child(w.saves)
	w.menu.open_pause()
	await frames()
	var save_buttons: Array = w.menu._root.find_children("*", "Button", true, false).filter(func(b): return b.text.strip_edges().to_lower() == "save game" and not b.is_queued_for_deletion())
	save_buttons[0].pressed.emit()
	check(paused and w.menu._root.visible and text_in(w.menu._panel).contains("Save failed"), "Failed Save Game keeps the campaign open and explains the failure", "Save")
	w.saves.queue_free(); w.saves = real_saves; w.menu.close()
	w.game_over = "victory"; w.continue_after_end()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	check(saved.continuing_after_end and saved.game_over == "victory", "Saving continuation retains the original victory result", "Save")
	w.saves.restore(saved)
	check(w.continuing_after_end and not w.match_stopped(), "Loading continuation resumes normal simulation", "Save")
	saved.erase("continuing_after_end"); w.saves.restore(saved)
	check(not w.match_stopped(), "An old finished save resumes safely", "Save")
	w.saves.restore(original)
	check(w.game_over == "" and not w.continuing_after_end, "Loading an unfinished save clears the previous result", "Save")
	var contacts: Node = w.diplomacy.contacts
	contacts.session = {}; contacts.cooldowns = {}
	var cash: float = w.economy.res.money
	contacts.begin(1, "phone")
	check(w.economy.res.money == cash - 25, "Secure telephone charges exactly its disclosed fee", "Diplomacy")
	contacts._process(6.0)
	check(contacts.session.phase == "talking", "Telephone countdown reaches negotiations", "Diplomacy")
	check(contacts.topic_reason("peace").contains("no war"), "Ending hostilities is blocked with a reason while at peace", "Diplomacy")
	contacts.back_to_channels()
	check(w.economy.res.money == cash, "Correcting an unused diplomatic channel refunds its fee", "Diplomacy")
	hud.open_diplomatic_contact(1)
	var contact_screen: Control = hud._diplomatic_contact_screen
	await keyboard(KEY_ESCAPE); await keyboard(KEY_ESCAPE, false)
	check(not contact_screen.visible and not contacts.session.is_empty(), "Escape closes the Foreign Office without losing the contact", "Diplomacy")
	DirAccess.make_dir_recursive_absolute("res://build/customer-review")
	var out := FileAccess.open("res://build/customer-review/results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(rows, "\t")); out.close()
	var failed: Array = rows.filter(func(r): return not r.passed)
	print("CUSTOMER_REVIEW: %d checks, %d failures" % [rows.size(), failed.size()])
	print("CUSTOMER_REVIEW PASS" if failed.is_empty() and rows.size() == 49 else "CUSTOMER_REVIEW FAIL")
	quit(0 if failed.is_empty() and rows.size() == 49 else 1)
