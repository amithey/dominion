extends SceneTree
## Round 3 of the customer review: 100 checks on what an unhappy customer met
## and what was fixed (native/CUSTOMER-REVIEW-ROUND-3-2026-10-09.md). Never
## writes the player's settings or saves.
class QuietMenu extends "res://scripts/menu.gd":
	func save_settings() -> void: pass
var w: Node
var h: Node
var rows: Array = []
const UI := preload("res://scripts/ui_theme.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String, area: String) -> void:
	rows.append({"id": rows.size() + 1, "area": area, "label": label, "passed": ok})
	print(("ok   " if ok else "FAIL ") + "%03d %s" % [rows.size(), label])
func frames(k := 4) -> void:
	for i in range(k): await process_frame
func texts(n: Node) -> String:
	var parts := PackedStringArray()
	for c in n.find_children("*", "", true, false):
		if c.is_queued_for_deletion(): continue
		if c is Label or c is Button: parts.append(c.text)
	return "\n".join(parts)
func button(n: Node, label: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and str(b.text).strip_edges() == label: return b
	return null
func fits(b: Button) -> bool:
	var font: Font = b.get_theme_font("font")
	var need := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	return need + (26.0 if b.icon != null else 0.0) + 12.0 <= b.size.x + 2.0

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	var old = w.menu
	w.menu = QuietMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	old.queue_free()
	w.start_match("easy")
	w.menu.close()
	w.saves.autosave_every = 0
	h = w.hud
	await frames(10)
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	var d: Node = w.diplomacy
	var hq0: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var home: Vector3 = hq0.root.position

	# ---- 1-10: letters and messages
	h._letters.clear()
	if h._letter_box != null: h._letter_box.queue_free(); h._letter_box = null
	var rel0: float = d.rel(0, 3)
	var declined := [false]
	h.ask("Iran demands $200 in tribute, or relations will suffer.", func(): pass, func(): declined[0] = true; d.change(0, 3, -15.0))
	h.ask("China proposes a trade pact.", func(): pass, func(): pass)
	await frames()
	check(texts(h._letter_box).contains("Reply within 60 s"), "A letter from abroad says how long it waits for an answer", "Letters")
	var timer: Timer = h._letter_box.find_children("*", "Timer", true, false)[0]
	check(timer.wait_time == 60.0 and timer.process_mode != Node.PROCESS_MODE_ALWAYS, "It waits 60 s of game time, and not while the game is paused", "Letters")
	var log0: int = h.notice_log.size()
	timer.timeout.emit()
	await frames()
	check(declined[0], "No answer counts as a refusal", "Letters")
	check(d.rel(0, 3) < rel0, "The refusal costs what refusing would have cost", "Letters")
	check(h.notice_log.size() > log0 and str(h.notice_log[-1]).contains("No answer was sent"), "A message explains that the letter lapsed", "Letters")
	check(h._letter_box != null and texts(h._letter_box).contains("China proposes"), "The next letter then appears", "Letters")
	h._letter_box.queue_free(); h._letter_box = null; h._letters.clear()
	h.choose("AUTHORIZE STRIKE", "Strike?", [["Cancel", "", func(): pass], ["Authorize", "bad", func(): pass]])
	await frames()
	check(h._letter_box.find_children("*", "Timer", true, false).is_empty(), "Your own decisions (a strike to authorise) never lapse", "Letters")
	h._letter_box.queue_free(); h._letter_box = null
	var bang := RegEx.create_from_string("notice\\(\"[^\"]*![\"\\)]")
	var loud := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd") and bang.search(FileAccess.get_file_as_string("res://scripts/" + f)) != null: loud += 1
	check(loud == 0, "No message shouts with an exclamation mark (%d files)" % loud, "Messages")
	w.research.points = 0.0
	var spies: Node = w.espionage
	var text0: String = ""
	seed(4)
	for i in range(40):
		spies.enemy_next = 0.0
		var said: String = spies.enemy_attempt("")
		if said.contains("laboratories") or said.contains("research data"):
			text0 = said
			break
	check(text0 == "" or (text0.contains("no research points to lose") and w.research.points >= 0.0), "Stolen research with nothing stored says so, and never goes below zero", "Messages")
	w.research.points = 50.0
	var lost := ""
	for i in range(80):
		spies.enemy_next = 0.0
		var said2: String = spies.enemy_attempt("")
		if said2.contains("research data"):
			lost = said2
			break
		w.research.points = 50.0
	check(lost == "" or lost.contains("-50"), "Stolen research reports what was really lost (%s)" % lost.left(50), "Messages")

	# ---- 11-22: spelling and text
	var names := PackedStringArray()
	var descs := PackedStringArray()
	for table in [w.building_defs, w.unit_defs, w.map.research.discoveries, w.map.missiles.types]:
		for k in table:
			names.append(str(table[k].get("name", "")))
			descs.append(str(table[k].get("desc", "")))
	var all_text := "\n".join(names) + "\n" + "\n".join(descs)
	check(not "\n".join(names).contains("Center"), "No name is spelt 'Center'", "Text")
	check(w.building_defs.villageCenter.name == "Village Centre" and w.building_defs.cityCenter.name == "City Centre", "Village Centre and City Centre", "Text")
	check(str(w.map.research.discoveries.compositeArmor.name).contains("Armour"), "Composite Armour", "Text")
	var us := RegEx.create_from_string("\\b(Center|Centers|Armor|armored|Defense|defense|color)\\b")
	check(us.search(all_text) == null, "No American spelling in any name or description (%s)" % (us.search(all_text).get_string() if us.search(all_text) else "none"), "Text")
	var req: Array = w.research.era_requirements(1) if w.research.has_method("era_requirements") else []
	check(req.is_empty() or req.any(func(x): return str(x[0]) == "Village Centres"), "The next era asks for 'Village Centres'", "Text")
	check(str(w.building_defs.aiDataCenter.desc).length() <= 200, "AI Data Centre card is short (%d)" % str(w.building_defs.aiDataCenter.desc).length(), "Text")
	check(str(w.building_defs.fusionCell.desc).length() <= 200, "Targeting Fusion Cell card is short (%d)" % str(w.building_defs.fusionCell.desc).length(), "Text")
	check(str(w.map.research.discoveries.agiProject.desc).length() <= 220, "The AGI Project card is short", "Text")
	var dated := RegEx.create_from_string("\\b(19[0-9]{2}|20[0-4][0-9])\\b")
	check(dated.search("\n".join(descs)) == null, "No year in any description", "Text")
	check(w.building_defs.has("aiDataCenter") and w.building_defs.has("villageCenter"), "Spelling changed the text, not the keys", "Text")
	check(fits(h._screen_buttons["diplomacy"]), "'Diplomacy' fits its button in the ministry strip", "Text")
	check(h._screen_buttons.values().all(func(b): return fits(b)), "Every ministry button's name fits", "Text")

	# ---- 23-36: settings and sound
	check(FileAccess.get_file_as_string("res://scripts/world.gd").contains("var show_fps := false"), "The frame counter is off for a new player", "Settings")
	var cfg_path := "user://r3-settings-probe.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "show_fps", true)
	cfg.save(cfg_path)
	cfg.load(cfg_path)
	check((bool(cfg.get_value("graphics", "show_fps", false)) if cfg.has_section_key("graphics", "fps_choice") else false) == false, "Settings saved before the change turn the counter off once", "Settings")
	cfg.set_value("graphics", "fps_choice", true)
	check((bool(cfg.get_value("graphics", "show_fps", false)) if cfg.has_section_key("graphics", "fps_choice") else false) == true, "A player who chose the counter keeps it", "Settings")
	DirAccess.remove_absolute(cfg_path)
	check(AudioServer.get_bus_index("Music") >= 0, "A Music bus", "Sound")
	check(AudioServer.get_bus_index("Interface") >= 0, "An Interface bus for clicks", "Sound")
	var au: Node = w.audio
	check(au._music != null and au._music.stream != null and au._music.bus == "Music", "Music plays on its own bus", "Sound")
	check(au._music.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "The music loops", "Sound")
	check(au._click != null and au._click.stream != null, "A button click sound", "Sound")
	var probe := Button.new()
	h.add_child(probe)
	await frames()
	check(probe.has_meta("clicks"), "Every new button clicks", "Sound")
	probe.queue_free()
	w.menu._show(true)
	w.menu.settings_tab = "sound"
	w.menu.open_settings()
	await frames()
	var sound := texts(w.menu._root)
	check(sound.contains("Music"), "Settings > Sound has a Music slider", "Sound")
	check(sound.contains("Interface clicks"), "and an Interface clicks slider", "Sound")
	w.menu._set_bus_volume("Music", 40.0)
	check(absf(w.menu._bus_volume("Music") - 40.0) <= 1.0, "The music volume is set and read back", "Sound")
	w.menu._reset_settings()
	check(absf(w.menu._bus_volume("Music") - 100.0) <= 1.0, "Defaults bring the music back to 100%", "Sound")
	check(au._music.process_mode == Node.PROCESS_MODE_ALWAYS, "The music keeps playing in the pause menu", "Sound")
	w.menu.close()

	# ---- 37-50: menus and saves
	var M = load("res://scripts/menu.gd")
	var now := int(Time.get_unix_time_from_system())
	check(M.when(now - 60).begins_with("today at"), "A save from a minute ago: 'today at …'", "Menus")
	check(M.when(now - 86400).begins_with("yesterday at") or M.when(now - 86400).begins_with("today at"), "Yesterday's save: 'yesterday at …'", "Menus")
	check(M.when(now - 3 * 86400 - 3600).ends_with("days ago"), "Three days ago: '3 days ago'", "Menus")
	check(RegEx.create_from_string("^\\d{1,2} [A-Z][a-z]+$").search(M.when(now - 40 * 86400)) != null, "Older saves: day and month (%s)" % M.when(now - 40 * 86400), "Menus")
	var snap: Dictionary = w.saves.capture()
	check(snap.has("summary") and str(snap.summary.nation) == d.name_of(0), "A save records whose campaign it is", "Saves")
	check(str(snap.summary.era) != "" and int(snap.summary.year) >= 1, "and its era and year", "Saves")
	var probe_path := "user://r3-save-probe.json"
	var f := FileAccess.open(probe_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(snap))
	f.close()
	var about: String = M._about(probe_path)
	DirAccess.remove_absolute(probe_path)
	check(about.contains(d.name_of(0)) and about.contains("year"), "The load list describes a save: %s" % about, "Saves")
	w.menu._show(true)
	w.menu.open_main()
	await frames()
	var main_text := texts(w.menu._root)
	check(RegEx.create_from_string("\\d\\d:\\d\\d:\\d\\d").search(main_text) == null, "The main menu shows no raw timestamp with seconds", "Menus")
	var quit_entry := button(w.menu._root, "")
	var has_icon := false
	for b in w.menu._root.find_children("*", "Button", true, false):
		if texts(b).contains("Quit") and not b.find_children("*", "TextureRect", true, false).filter(func(t): return t.texture != null).is_empty():
			has_icon = true
	check(has_icon, "Quit has an icon like every other entry", "Menus")
	w.menu.in_match = true
	w.menu.open_pause()
	await frames()
	var to_menu := button(w.menu._root, "Quit to Main Menu")
	to_menu.pressed.emit()
	await frames()
	check(to_menu.text.contains("Click again"), "Quit to Main Menu asks for a second click", "Menus")
	check(is_instance_valid(w) and w.is_inside_tree(), "and the first click does not leave the campaign", "Menus")
	var dummy := Button.new()
	w.menu.add_child(dummy)
	w.menu._confirmed(dummy, "Quit")
	check(w.menu._confirmed(dummy, "Quit"), "A second click within four seconds confirms", "Menus")
	var dummy2 := Button.new()
	w.menu.add_child(dummy2)
	w.menu._confirmed(dummy2, "Quit to Desktop")
	await create_timer(4.3, true).timeout
	check(dummy2.text.strip_edges() == "Quit to Desktop", "The question goes away after four seconds", "Menus")
	w.menu.close()
	w.menu.setup_options["map"] = "europe"
	var picker: OptionButton = w.menu._start_picker(1)
	check(picker.custom_minimum_size.x >= 170.0, "Start pickers are wide enough for a region's name", "Menus")
	picker.free()
	w.menu.setup_options["map"] = "island"

	# ---- 51-58: diplomacy
	h._letters.clear()
	h._declare(1)
	await frames()
	check(h._letter_box != null and not d.at_war(0, 1), "Declare war asks first", "Diplomacy")
	check(texts(h._letter_box).contains(d.name_of(1)), "The question names the nation", "Diplomacy")
	button(h._letter_box, "Cancel").pressed.emit()
	await frames()
	check(not d.at_war(0, 1), "Cancel keeps the peace", "Diplomacy")
	h._declare(1)
	await frames()
	button(h._letter_box, "Declare war").pressed.emit()
	await frames()
	check(d.at_war(0, 1), "Declare war, confirmed, is war", "Diplomacy")
	d.set_flag(d.alliance, 2, 3, true)
	h._declare(3)
	await frames()
	check(texts(h._letter_box).contains(d.name_of(2)), "The question lists the target's allies", "Diplomacy")
	button(h._letter_box, "Cancel").pressed.emit()
	d.set_flag(d.alliance, 2, 3, false)
	w.menu._show(true)
	w.menu.setup_options["players"] = 4
	w.menu.open_new_game()
	await frames()
	var grid: GridContainer = w.menu._root.find_children("RivalGrid", "GridContainer", true, false)[0]
	check(grid.columns == 1, "Three rivals sit in one tidy column", "New game")
	w.menu.setup_options["players"] = 9
	w.menu.setup_options["map"] = "pangaea"
	w.menu.open_new_game()
	await frames()
	grid = w.menu._root.find_children("RivalGrid", "GridContainer", true, false)[0]
	check(grid.columns == 2, "Eight rivals in two columns", "New game")
	check(w.menu._root.find_children("BeginCampaign", "Button", true, false).size() == 1, "Begin campaign is on the sheet", "New game")
	w.menu.setup_options["players"] = 4
	w.menu.setup_options["map"] = "island"
	w.menu.close()

	# ---- 59-70: the selection panel and the hover tag
	var barracks: Dictionary = w.place_building("barracks", w.test_site("barracks", home + Vector3(-40, 0, -40)), 0, true)
	w.select_building(barracks)
	h._update_selection()
	await frames(2)
	check(not h._commands["Attack-move"].visible, "A selected barracks offers no Attack-move", "Selection")
	check(not h._commands["Bombard"].visible, "nor Bombard", "Selection")
	check(not h._commands["Repair"].visible, "nor Repair while undamaged", "Selection")
	barracks.hp = barracks.max_hp * 0.5
	h._update_selection()
	await frames(2)
	check(h._commands["Repair"].visible, "A damaged building offers Repair", "Selection")
	w.select_building(null)
	var s1: Dictionary = w.spawn_unit("soldier", home + Vector3(25, 0, 25), 0)
	var s2: Dictionary = w.spawn_unit("soldier", home + Vector3(27, 0, 25), 0)
	for u in w.units: u.selected = false
	s1.selected = true
	s2.selected = true
	h._update_selection()
	await frames(2)
	check(h._commands["Attack-move"].visible, "Soldiers offer Attack-move", "Selection")
	check(h._sel_sub.text.contains("Soldiers"), "Two soldiers read '2 Soldiers' (%s)" % h._sel_sub.text, "Selection")
	s2.selected = false
	h._update_selection()
	await frames(2)
	var stats := texts(h._sel_stats)
	check(not h._sel_sub.text.contains("1 "), "One soldier reads 'Soldier'", "Selection")
	var acc := RegEx.create_from_string("(\\d+)%").search_all(stats).map(func(m): return int(m.get_string(1)))
	check(acc.all(func(v): return v <= 100), "No stat shows more than 100 percent (%s)" % str(acc), "Selection")
	check(stats.contains("m/s"), "Speed has its unit", "Selection")
	s1.selected = false
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	w.cam_focus = s1.node.position
	w.cam_dist_target = 60.0
	w.cam_dist = 60.0
	await frames(10)
	var at: Vector2 = cam.unproject_position(s1.node.position + Vector3.UP * 0.8)
	var hit = h.unit_at_screen(at)
	check(hit != null and (hit == s1 or hit == s2), "The mouse over a soldier finds it", "Hover")
	var foe_unit: Dictionary = w.spawn_unit("soldier", home + Vector3(25, 0, -25), 1)
	check(h.hover_text(foe_unit).contains(d.name_of(1)) and h.hover_text(s1).contains("Yours"), "The tag says whose it is", "Hover")
	check(h.unit_at_screen(at + Vector2(400, 300)) == null, "Empty ground names no one", "Hover")

	# ---- 71-78: idle workers
	var workers: Array = w.units.filter(func(u): return u.owner == 0 and u.key == "worker" and not u.dead)
	for u in workers:
		u.build_site = null; u.target = null; u.build_queue = []
	h._refresh = 0.3
	h._process(0.3)
	check(h._idle_button.visible, "Idle workers get a button", "Workers")
	check(h._idle_button.text.contains(str(workers.size())), "It counts them (%s)" % h._idle_button.text, "Workers")
	w.select_building(hq0)
	var focus0: Vector3 = w.cam_focus
	h._idle_button.pressed.emit()
	check(w.units.filter(func(u): return u.selected).size() == workers.size() and workers.all(func(u): return u.selected), "One click selects exactly the idle workers", "Workers")
	check(w.cam_focus.distance_to(workers[0].node.position) < 1.0, "and brings the camera to them", "Workers")
	check(w.selected_building == null, "The selected building is let go", "Workers")
	check(str(h.notice_log[-1]).contains("right-click"), "A message says what to do next", "Workers")
	workers[0].build_site = barracks
	check(not h.idle_workers().has(workers[0]), "A worker with a site is not idle", "Workers")
	for u in workers: u.build_site = barracks
	h._refresh = 0.3
	h._process(0.3)
	check(not h._idle_button.visible, "No idle workers, no button", "Workers")
	for u in workers: u.build_site = null; u.selected = false

	# ---- 79-84: damage tags over buildings
	barracks.hp = barracks.max_hp * 0.9
	w.show_building_damage(barracks)
	var tag: Label3D = barracks.damage_label
	check(tag.font_size * tag.pixel_size < 40 * 0.025, "Damage tags are smaller than they were (%d px)" % tag.font_size, "Graphics")
	check(tag.modulate.g > tag.modulate.r, "Healthy: green", "Graphics")
	barracks.hp = barracks.max_hp * 0.45
	w.show_building_damage(barracks)
	check(tag.modulate.r > 0.9 and tag.modulate.g > 0.7 and tag.modulate.b < 0.5, "Half: amber", "Graphics")
	barracks.hp = barracks.max_hp * 0.2
	w.show_building_damage(barracks)
	check(tag.modulate.r > tag.modulate.g and tag.modulate.g < 0.6, "Nearly gone: red", "Graphics")
	check(tag.position.y >= 12.0, "Above the roof", "Graphics")
	check(tag.text.ends_with("%"), "With its health in percent", "Graphics")

	# ---- 85-88: the era cartouche
	w.game_time = 10.0
	h._refresh = 0.3
	h._process(0.3)
	check(h._era.text.contains("SPRING"), "The cartouche shows the season (%s)" % h._era.text, "Top bar")
	w.game_time = 200.0
	h._refresh = 0.3
	h._process(0.3)
	check(h._era.text.contains("SUMMER"), "Summer follows", "Top bar")
	w.game_time = 560.0
	h._refresh = 0.3
	h._process(0.3)
	check(h._era.text.contains("WINTER"), "Winter, when homes burn gas", "Top bar")
	w.game_time = 800.0
	h._refresh = 0.3
	h._process(0.3)
	check(h._era.text.contains("YEAR 2"), "A year is four seasons", "Top bar")

	# ---- 89-92: the end dialog
	h.show_end("VICTORY", "A test victory.")
	await frames()
	var stay := button(h._end_box, "Continue playing")
	var leave := button(h._end_box, "Main menu")
	check(stay != null and stay.custom_minimum_size.x >= 170 and leave.custom_minimum_size.x >= 170, "End buttons are full-size", "End dialog")
	check(stay.get_theme_font_size("font_size") >= 16, "with readable text", "End dialog")
	check(root.gui_get_focus_owner() == stay, "Continue playing has the focus", "End dialog")
	check(leave != null, "Main menu is offered too", "End dialog")
	h.close_end()

	# ---- 93-100: the rest
	h._process(0.3)
	check(not h._fps.visible, "No frame counter on the HUD by default", "Settings")
	w.show_fps = true
	h._refresh = 0.3
	h._process(0.3)
	check(h._fps.visible, "Switched on, it shows", "Settings")
	w.show_fps = false
	check(not FileAccess.get_file_as_string("res://scripts/espionage.gd").contains("(-70 research)!"), "The old stolen-research wording is gone", "Messages")
	var style = load("res://scripts/house_style.gd")
	check(style.fix("Missile Defense Center") == "Missile Defence Centre", "House style: 'Defense Center' becomes 'Defence Centre'", "Text")
	check(style.fix("Defence and armour") == "Defence and armour", "and leaves British spelling alone", "Text")
	check(style.fix("Recenter") == "Recenter", "but never a word inside another word", "Text")
	h.toggle_panel("defence", true)
	h._panels.defence_tab = "ai"
	w.directorate.ui_tab = "compute"
	h.refresh_side()
	await frames()
	check(texts(h._side_rows).contains("Centre") or not texts(h._side_rows).contains("Center"), "The AI tab says 'Data Centre'", "Text")
	h.toggle_panel("defence")
	h._letters.clear()
	if h._letter_box != null: h._letter_box.queue_free(); h._letter_box = null
	var acted := [false]
	h.choose("BORDER", "China forces have crossed into your territory without leave.", [["Grant passage", "good", func(): acted[0] = true], ["Open fire", "bad", func(): acted[0] = true]])
	await frames()
	var border_timers: Array = h._letter_box.find_children("*", "Timer", true, false)
	if not border_timers.is_empty(): border_timers[0].timeout.emit()
	await frames()
	check(not border_timers.is_empty() and h._letter_box == null and not acted[0], "A border letter from abroad is set aside after 60 s, without acting on your behalf", "Letters")
	var failed := rows.filter(func(r): return not r.passed)
	print("CUSTOMER_ROUND3: %d checks, %d failures" % [rows.size(), failed.size()])
	for r in failed: print("  FAILED %03d %s" % [r.id, r.label])
	var out := FileAccess.open("res://build/customer-round3-100.json", FileAccess.WRITE)
	if out != null: out.store_string(JSON.stringify(rows, "  "))
	print("CUSTOMER_ROUND3 %s" % ("PASS" if failed.is_empty() and rows.size() == 100 else "FAIL"))
	quit(0 if failed.is_empty() else 1)
