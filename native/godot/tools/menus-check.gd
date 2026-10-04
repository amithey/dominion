extends SceneTree
## The in-game menus, one by one: the resource strip shows the stores; each
## screen button and its key open and close its window; every tab of every
## window shows something and stays on screen; the build list and its search;
## a building's and a unit's panels; help; the pause menu and what it leads
## to; Esc closes what is open before it pauses; and a double click on a unit
## takes every unit of its kind on screen.
var errors: Array[String] = []
var passed := 0
var w: Node
var hud: Node
const UI := preload("res://scripts/ui_theme.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func frames(n := 3) -> void:
	for i in range(n): await process_frame

## Lets the HUD redraw (it refreshes four times a second).
func settle() -> void:
	hud._refresh = 1.0
	hud._process(0.3)
	await frames(2)

func key(code: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	w._input(e)
	await frames(2)

func on_screen(c: Control) -> bool:
	var view: Rect2 = c.get_viewport().get_visible_rect().grow(2.0)
	var r := c.get_global_rect()
	return view.encloses(r)

func buttons_in(c: Node) -> Array:
	return c.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu.close()
	hud = w.hud
	await frames(5)
	w.economy.grant_test_resources()
	w.place_building("intelAgency", w.test_site("intelAgency", w.start), 0, true)
	w.economy.recalculate()
	await settle()
	print("== the resource strip")
	# 1-3: the strip.
	var wrong := []
	for r in hud.RESOURCES:
		var shown: String = hud._chips[r[0]][0].text
		if shown != hud.compact_number(w.economy.res.get(r[0], 0.0)): wrong.append("%s %s" % [r[0], shown])
	check(wrong.is_empty(), "the strip shows every store as it stands (money %s)%s" % [hud._chips.money[0].text, "" if wrong.is_empty() else ": " + str(wrong)])
	check(hud._era.text != "" and hud._extra.army[0].text.contains("/") and hud._extra.citizens[0].text.contains("/"), "the era, the army and the citizens are shown (%s)" % hud._era.text)
	check(on_screen(hud._era.get_parent()) and hud._chips.money[2].get_global_rect().end.x < hud._era.get_parent().get_global_rect().position.x, "nothing in the strip runs under the era cartouche")
	# 4-13: each screen: its button and its key open it, and close it again.
	print("== the screen buttons and their keys")
	var screens := [["research", KEY_Y], ["diplomacy", KEY_G], ["market", KEY_M], ["intel", KEY_I], ["land", KEY_T]]
	for s in screens:
		var name: String = s[0]
		var open := func() -> bool: return hud._rs != null and hud._rs.visible if name == "research" else (hud._win != null and hud._win.visible and hud.side_mode == ("territory" if name == "land" else name))
		hud._screen_buttons[name].pressed.emit()
		await settle()
		var by_button: bool = open.call() and hud._screen_buttons[name].button_pressed
		hud._screen_buttons[name].pressed.emit()
		await settle()
		var closed: bool = not open.call()
		check(by_button and closed, "%s: its button opens the window, lit, and closes it" % name)
		await key(s[1])
		await settle()
		var by_key: bool = open.call()
		await key(s[1])
		await settle()
		check(by_key and not open.call(), "%s: its key opens and closes it" % name)
	# 14-17: every tab of every window shows something and stays on screen.
	print("== every tab of every window")
	for mode in ["diplomacy", "market", "intel", "territory"]:
		hud.toggle_panel(mode, true)
		await settle()
		# The tabs (segments): pressing one rebuilds the window, so each is found again by its name.
		# (the tab row: the first row of toggles, not the quantity chips or the expanders below)
		var toggles: Array = buttons_in(hud._win).filter(func(b): return b.toggle_mode)
		var names: Array = toggles.filter(func(b): return b.get_parent() == toggles[0].get_parent()).map(func(b): return b.text) if not toggles.is_empty() else []
		var pressed := 0
		var empty := []
		var off := []
		for n in names:
			var now: Array = buttons_in(hud._win).filter(func(b): return b.toggle_mode and b.text == n)
			if now.is_empty(): continue
			now[0].pressed.emit()
			await settle()
			pressed += 1
			if hud._side_rows.get_child_count() == 0: empty.append(n)
			if not on_screen(hud._win): off.append(n)
		check(hud._win.visible and pressed >= 1 and pressed == names.size() and empty.is_empty() and off.is_empty(), "%s: all %d tabs open with content, the window on screen (%s)%s" % [mode, pressed, ", ".join(PackedStringArray(names)), "" if empty.is_empty() and off.is_empty() else " empty %s, off screen %s" % [str(empty), str(off)]])
		# The ministry's briefing down the left, its name under the title, its tabs in its colour.
		var figures: int = hud._win_brief.get_children().filter(func(c): return c is PanelContainer).size()
		var tab_row: Array = buttons_in(hud._win).filter(func(b): return b.toggle_mode and b.text == names[0]) if not names.is_empty() else []
		var tab_style = tab_row[0].get_theme_stylebox("normal") if not tab_row.is_empty() else null
		check(figures >= 3 and hud._win_sub.text != "" and tab_style is StyleBoxFlat and tab_style.border_color.is_equal_approx(Color(UI.ministry(mode), tab_style.border_color.a)), "%s: a briefing of %d key figures, \"%s\" under the title, its tabs in its colour" % [mode, figures, hud._win_sub.text])
		hud.toggle_panel(mode)
		await settle()
	# The window stays on screen with the longest text there is: Afghanistan's power
	# (one long line, it once stretched the window past the right of the screen).
	var was: Dictionary = w.map.nations[0].duplicate()
	var Factions := preload("res://scripts/factions.gd")
	w.map.nations[0] = Factions.nation(Factions.IDS.find("afghanistan"), true)
	hud.toggle_panel("diplomacy", true)
	await settle()
	await frames(3)
	var long_ok: bool = on_screen(hud._win)
	var width: float = hud._win.size.x
	hud.toggle_panel("diplomacy")
	w.map.nations[0] = was
	await settle()
	check(long_ok, "the diplomacy window stays on screen with Afghanistan's long power text (%d px wide)" % int(width))
	# 18-21: research.
	print("== research")
	hud.toggle_research()
	await settle()
	var era_names: Array = w.research.eras.map(func(e): return str(e.name))
	var era_marks: Array = hud._rs.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and era_names.any(func(n): return l.text.ends_with(n)))
	check(hud._rs.visible and on_screen(hud._rs) and era_marks.size() >= 5, "research: the tree opens on screen, the eras marked across it (%d)" % era_marks.size())
	var develop: Array = buttons_in(hud._rs).filter(func(b): return b.text == "Develop")
	var before: int = w.research.queue.size()
	if not develop.is_empty(): develop[0].pressed.emit()
	await settle()
	check(develop.size() >= 4 and w.research.queue.size() == before + 1, "research: a track's Develop button queues it (%d in the queue)" % w.research.queue.size())
	hud.toggle_research()
	await settle()
	check(not hud._rs.visible, "research: it closes")
	# 22-26: the build list.
	print("== the build list")
	hud.toggle_build()
	await settle()
	var counts := {}
	for tab in ["Economy", "Civic & research", "Military"]:
		hud.build_tab = tab
		hud._update_panel()
		await frames(2)
		counts[tab] = buttons_in(hud._list).filter(func(b): return b.has_meta("cost")).size()
	check(hud._prod.visible and on_screen(hud._prod) and counts.values().all(func(c): return c >= 3), "build: each tab lists its buildings (%s)" % str(counts))
	hud.build_tab = "Economy"
	hud._build_search.text = "farm"
	hud._update_panel()
	await frames(2)
	var found: Array = buttons_in(hud._list).filter(func(b): return b.has_meta("cost"))
	check(found.size() >= 1 and found.size() < counts.Economy, "build: the search narrows the list (%d for \"farm\")" % found.size())
	hud._build_search.text = ""
	hud._update_panel()
	var bar: Array = buttons_in(hud._list).filter(func(b): return b.has_meta("cost"))
	if not bar.is_empty(): bar[0].pressed.emit()
	await frames(2)
	check(w.placing != "", "build: a bar starts placing its building (%s)" % w.placing)
	await key(KEY_ESCAPE)
	check(w.placing == "" and not w.menu._root.visible, "Esc cancels the placing first, without pausing")
	hud.toggle_build()
	await settle()
	check(not hud._prod.visible or hud._panel_mode() != "build", "build: it closes")
	# 27-30: a building's panel and a unit's.
	print("== selections")
	var barracks = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks")
	if barracks.is_empty(): barracks = [w.place_building("barracks", w.test_site("barracks", w.start), 0, true)]
	w.select_building(barracks[0])
	await settle()
	var trains: Array = buttons_in(hud._list).filter(func(b): return b.has_meta("cost"))
	var allowed: Array = barracks[0].def.trains.filter(func(u): return w.unit_defs.has(u) and w.unit_allowed(0, u))
	check(hud._prod.visible and trains.size() == allowed.size(), "a barracks lists the %d units your nation trains there" % allowed.size())
	var hq = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	w.select_building(hq)
	await settle()
	check(hud._sel.visible and on_screen(hud._sel) and hud._city_tiles.get_child_count() >= 4, "the capital's panel shows its accounts (%d tiles)" % hud._city_tiles.get_child_count())
	w.select_building(null)
	var tanks: Array = w.units.filter(func(u): return u.owner == 0 and u.key == "tank" and not u.dead)
	for u in tanks: u.selected = true
	await settle()
	check(hud._sel.visible and on_screen(hud._sel), "a group of tanks gets its panel")
	for u in w.units: u.selected = false
	await settle()
	# 31-32: help.
	await key(KEY_F1)
	var help_open: bool = hud._help.visible and on_screen(hud._help)
	await key(KEY_F1)
	check(help_open and not hud._help.visible, "F1 opens the help on screen and closes it")
	# 33: Esc closes an open window before it pauses.
	hud.toggle_panel("market", true)
	await settle()
	await key(KEY_ESCAPE)
	await settle()
	var market_closed: bool = not hud._win.visible
	var paused: bool = w.menu._root.visible
	if paused: w.menu.close()
	await frames(2)
	check(market_closed and not paused, "Esc closes the open window first, and does not pause (closed %s, paused %s)" % [market_closed, paused])
	# 34-38: the pause menu.
	print("== the pause menu")
	await key(KEY_ESCAPE)
	var labels: Array = buttons_in(w.menu._root).map(func(b): return b.text.strip_edges())
	check(w.menu._root.visible and get_root().get_tree().paused and ["Resume", "Save Game", "Load Game", "Settings", "Quit to Main Menu"].all(func(t): return t in labels), "Esc pauses: the menu has Resume, Save, Load, Settings and Quit (%d buttons)" % labels.size())
	var settings: Array = buttons_in(w.menu._root).filter(func(b): return b.text.strip_edges() == "Settings")
	settings[0].pressed.emit()
	await frames(4)
	var controls: int = w.menu._root.find_children("*", "Range", true, false).size() + w.menu._root.find_children("*", "OptionButton", true, false).size() + w.menu._root.find_children("*", "CheckBox", true, false).size() + w.menu._root.find_children("*", "CheckButton", true, false).size()
	check(controls >= 3, "Settings shows its controls (%d)" % controls)
	w.menu.open_pause()
	await frames(3)
	var load: Array = buttons_in(w.menu._root).filter(func(b): return b.text.strip_edges() == "Load Game")
	load[0].pressed.emit()
	await frames(4)
	check(w.menu._root.visible and w.menu._root.find_children("*", "Button", true, false).size() >= 1, "Load Game shows its page")
	w.menu.open_pause()
	await frames(3)
	var resume: Array = buttons_in(w.menu._root).filter(func(b): return b.text.strip_edges() == "Resume")
	resume[0].pressed.emit()
	await frames(4)
	check(not w.menu._root.visible and not get_root().get_tree().paused, "Resume returns to the game, unpaused")
	w.menu.open_pause()
	await frames(3)
	var all_on_screen: bool = buttons_in(w.menu._root).all(func(b): return on_screen(b))
	w.menu.close()
	await frames(3)
	check(all_on_screen, "every button of the pause menu is on screen")
	# The Cabinet: the whole state at a glance.
	print("== the Cabinet")
	await key(KEY_TAB)
	await settle()
	var cab = hud._cabinet
	var charts: Array = cab.find_children("Chart_*", "", true, false)
	check(charts.size() >= 4 and hud.history.money.size() >= 1, "the Cabinet charts the treasury, the citizens, the army and research over time (%d charts)" % charts.size())
	var tiles: Array = cab._grid.get_children().filter(func(t): return not t.is_queued_for_deletion())
	check(cab != null and cab.visible and on_screen(cab) and tiles.size() == 10, "Tab opens the Cabinet, full screen, with its 8 ministries, the world news and the paths to victory (%d)" % tiles.size())
	check(hud._screen_buttons.cabinet.button_pressed or (func(): hud._process(0.3); return hud._screen_buttons.cabinet.button_pressed).call(), "its screen button is lit while it is open")
	var money_shown: bool = cab.find_children("*", "Label", true, false).any(func(l): return l.text == "$" + hud.compact_number(w.economy.res.money))
	check(money_shown, "it shows the treasury as it stands ($%s)" % hud.compact_number(w.economy.res.money))
	var opens := {"research": func(): return hud._rs != null and hud._rs.visible, "diplomacy": func(): return hud.side_mode == "diplomacy",
		"economy": func(): return hud.side_mode == "market", "intel": func(): return hud.side_mode == "intel", "territory": func(): return hud.side_mode == "territory",
		"world": func(): return hud.side_mode == "market",
		"victory": func(): return hud.side_mode == "territory",
		"military": func(): return hud.prod_open, "people": func(): return w.selected_building != null and w.selected_building.key == "hq"}
	var failed := []
	for k in opens:
		hud.close_windows()
		w.select_building(null)
		hud.toggle_cabinet()
		await settle()
		var b = cab.find_child("Open_" + k, true, false)
		if b == null:
			failed.append(k + " (no button)")
			continue
		b.pressed.emit()
		await settle()
		if cab.visible or not opens[k].call(): failed.append(k)
	hud.close_windows()
	w.select_building(null)
	check(failed.is_empty(), "each tile's button closes the Cabinet and opens its ministry%s" % ("" if failed.is_empty() else ": not " + str(failed)))
	hud.toggle_cabinet()
	await settle()
	await key(KEY_ESCAPE)
	check(not cab.visible and not w.menu._root.visible, "Esc closes the Cabinet, without pausing")
	hud._id_face.pressed.emit()
	await settle()
	var by_face: bool = cab.visible
	hud.toggle_cabinet()
	check(hud._id_face.icon != null and by_face, "the leader's portrait heads the strip, and opens the Cabinet")
	var coloured := []
	for s in hud._screen_buttons:
		var style = hud._screen_buttons[s].get_theme_stylebox("normal")
		if style is StyleBoxFlat and style.border_color.is_equal_approx(Color(UI.ministry(s), style.border_color.a)): coloured.append(s)
	check(coloured.size() == hud._screen_buttons.size(), "every screen button wears its ministry's colour (%s)" % ", ".join(PackedStringArray(coloured)))
	# 39-42: a double click takes every unit of its kind on screen.
	print("== double click")
	w.cam_focus = w.start
	w.update_camera(0.0)
	await frames(3)
	var near: Vector3 = w.land_point(w.start + Vector3(0, 0, 25), 10.0)
	var kind := []
	for i in range(4): kind.append(w.spawn_unit("tank", w.land_point(near + Vector3(i * 4.0, 0, 0), 4.0), 0))
	var other: Dictionary = w.spawn_unit("soldier", w.land_point(near + Vector3(0, 0, 6), 4.0), 0)
	var far: Dictionary = w.spawn_unit("tank", w.land_point(w.start + Vector3(260, 0, 260), 30.0), 0)
	await frames(3)
	var view: Rect2 = w.get_viewport().get_visible_rect()
	var at: Vector2 = w.Picking.screen_centre(w.camera, kind[1])
	var far_seen: bool = not w.camera.is_position_behind(far.node.global_position) and view.has_point(w.Picking.screen_centre(w.camera, far))
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.double_click = true
	e.position = at
	w._unhandled_input(e)
	await frames(2)
	var tanks_on_screen: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == "tank" and not w.camera.is_position_behind(u.node.global_position) and view.has_point(w.Picking.screen_centre(w.camera, u)))
	check(kind.all(func(u): return u.selected) and tanks_on_screen.all(func(u): return u.selected), "a double click on a tank takes every tank on screen (%d)" % tanks_on_screen.size())
	check(not other.selected, "...and nothing of another kind")
	check(far_seen or not far.selected, "...and no tank off screen")
	other.selected = true
	e.shift_pressed = true
	w._unhandled_input(e)
	await frames(2)
	check(other.selected and kind.all(func(u): return u.selected), "with Shift, the tanks join what was already selected")
	print("\nMENUS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("MENUS PASS" if errors.is_empty() else "MENUS FAIL")
	quit(0 if errors.is_empty() else 1)
