extends SceneTree
## Audit of every control (native/ALPHA-1.0-REPORT.md): boots a full match (every system on), opens each surface in turn
## and presses every enabled button on it, one at a time on a freshly opened surface. For each press it records:
##   FAIL  the engine or a script reported an error
##   WARN  nothing visible changed (a dead button), or a disabled button gives no reason (no tooltip)
##   ok    something changed
## Destructive controls (quit, start a new game, load a save, declare war) are only checked to exist and to explain
## themselves. Table: res://build/audit/ui.txt
const Kit := preload("res://tools/audit_kit.gd")
var K
var w: Node
var home: Vector3
var _skip_re := RegEx.new()
var surfaces_done := 0
var presses := 0
func _initialize() -> void: call_deferred("run")

func reset() -> void:
	var h: Node = w.hud
	w.get_tree().paused = false
	if w.menu != null: w.menu.close()
	if h._rs != null and h._rs.visible: h.toggle_research()
	if h._cabinet != null and h._cabinet.visible: h._cabinet.close()
	h._show_side("")
	if h._log_box != null: h._log_box.hide()
	if h._help != null: h._help.hide()
	h.set_production_open(false)
	w.select_building(null)
	for u in w.units: u.selected = false
	w.cancel_placement(); w.cancel_missile(); w.cancel_landing(); w.cancel_transport(); w.cancel_land_purchase()
	h._letters.clear()
	if h._letter_box != null and is_instance_valid(h._letter_box):
		h._letter_box.queue_free()
		h._letter_box = null
	if h._un_sessions != null: h._un_sessions.close()
	if h._diplomatic_contact_screen != null: h._diplomatic_contact_screen.hide()
	h.close_end()
	w.game_speed = 1.0

## Presses every enabled button of the surface `name`, each on a freshly opened copy.
func walk(name: String, opener: Callable, root_of: Callable, only := [], cap := 90) -> void:
	print("AUDIT_UI >> ", name)
	if not is_instance_valid(w):
		K.fail("ui-surface", name, "the world is gone: an earlier press restarted the game")
		return
	reset()
	opener.call()
	await K.frames(5)
	K.clean("ui", name + " opens")
	var root: Node = root_of.call()
	var first: Array = K.buttons_in(root)
	if first.is_empty():
		K.warn("ui", name, "no buttons")
		return
	var dead := 0
	var n := mini(first.size(), cap)
	var pressed := 0
	var reasonless := 0
	var total := first.size()
	var disabled_total := 0
	for b in first:
		if b.disabled:
			disabled_total += 1
			if b is Button and str(b.tooltip_text).strip_edges().length() < 10 and K.label_of(b).length() > 0:
				reasonless += 1
	first = []
	for i in range(n):
		reset()
		opener.call()
		await K.frames(3)
		var buttons: Array = K.buttons_in(root_of.call())
		if i >= buttons.size():
			break
		var b: BaseButton = buttons[i]
		var label: String = K.label_of(b)
		var key := "%s [%d] %s" % [name, i, label]
		if b.disabled:
			continue
		if _skip_re.search(label) != null or (not only.is_empty() and not label in only):
			K.ok("ui", key, "exists, not pressed (destructive or leaves the surface)")
			continue
		K.take_errors()
		var before: int = K.signature()
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed   # (a switch is driven by `toggled`; a tab by `pressed`: do both)
		b.pressed.emit()
		await K.frames(3)
		presses += 1
		pressed += 1
		if not K.clean("ui", key):
			continue
		if K.signature() == before:
			dead += 1
			K.warn("ui", key, "nothing visible changed")
		else:
			K.ok("ui", key)
	if reasonless > 0:
		K.warn("ui", name, "%d disabled buttons give no reason (no tooltip)" % reasonless)
	surfaces_done += 1
	K.ok("ui-surface", name, "%d buttons, %d pressed, %d without visible effect, %d disabled" % [total, pressed, dead, disabled_total])
	reset()

func run() -> void:
	_skip_re.compile("^(Quit|Start|Begin|Launch|Load|Continue|Delete|Exit|New campaign|Play|Main menu|Return to|Back to the)")
	K = Kit.new(self, "ui")
	w = await K.boot({"map": "island", "players": 4, "nation": 0, "opening": "light"}, "easy", true)
	if w == null:
		quit(1)
		return
	home = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	# A lived-in match: money and stores, buildings of every kind, units of every domain, agents, relations, research.
	w.economy.grant_test_resources()
	for key in ["market", "port", "intelAgency", "school", "university", "missileSilo", "ammoDepot", "barracks", "tankFactory", "airfield", "helipad", "shipyard", "strategicComplex", "hospital", "farm", "powerPlant"]:
		var at = w.test_site(key, home)
		if at != null:
			w.place_building(key, at, 0, true)
	w.economy.recalculate()
	var sea := Vector3.INF
	for r in range(30, 260, 8):
		for a in range(0, 360, 12):
			var p := home + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * r
			if w.height_at(p.x, p.z) < -6.0:
				sea = Vector3(p.x, 0, p.z)
				break
		if sea != Vector3.INF: break
	for key in ["soldier", "tank", "worker", "artillery", "jet", "helicopter"]:
		w.spawn_unit(key, home + Vector3(8, 0, 8) * (1 + randi() % 3), 0)
	if sea != Vector3.INF:
		for key in ["destroyer", "landingShip", "carrier"]:
			w.spawn_unit(key, sea + Vector3(randf() * 20.0, 0, randf() * 20.0), 0)
	for i in range(2): w.espionage.recruit()
	w.diplomacy.set_score(0, 1, 60.0)
	w.diplomacy.set_flag(w.diplomacy.pact, 0, 1, true)
	w.diplomacy.set_score(0, 2, -20.0)
	w.missiles.stock["tactical"] = 2
	w.missiles.stock["cruise"] = 1
	for i in range(40): await process_frame
	K.take_errors()
	var h: Node = w.hud
	h.toggle_panel("diplomacy", true)
	await K.frames(3)
	var P: RefCounted = h._panels
	reset()
	var side := func(): return h._side_rows

	# ---- the top bar and the dock
	await walk("HUD / top bar", func(): pass, func(): return h, ["Cabinet", "Research", "Diplomacy", "Market", "Intel", "Defence", "UN", "Territory", "Log", "Menu", "Build", "1x", "2x", "4x", "II", "Cheats"], 40)
	# ---- the side windows, every tab
	for t in ["nations", "world", "stats", "orders"]:
		await walk("Diplomacy / " + t, func(): P.diplomacy_tab = t; h.toggle_panel("diplomacy", true), side, [], 70)
	for m in ["overview", "gdp", "growth", "inflation", "unemployment", "debt", "military", "milex", "fragility", "displaced", "energy", "land", "tech", "infra"]:
		await walk("Statistics / " + m, func(): P.diplomacy_tab = "stats"; P.stats_metric = m; h.toggle_panel("diplomacy", true), side, [], 40)
	for t in ["operations", "agents", "dossiers", "reports", "space"]:
		await walk("Intel / " + t, func(): P.intel_tab = t; h.toggle_panel("intel", true), side, [], 70)
	for t in ["exchange", "routes"]:
		await walk("Market / " + t, func(): P.market_tab = t; h.toggle_panel("market", true), side, [], 70)
	for t in ["yours", "nations"]:
		await walk("Territory / " + t, func(): P.territory_tab = t; h.toggle_panel("land", true) if false else h.toggle_panel("territory", true), side, [], 60)
	for t in ["generals", "veterans", "nuclear", "arsenal"]:
		await walk("Defence / " + t, func(): P.defence_tab = t; h.toggle_panel("defence", true), side, [], 70)
	for t in ["compute", "applications", "doctrine", "operations", "agi", "rivals"]:
		await walk("Defence / AI / " + t, func(): P.defence_tab = "ai"; w.directorate.ui_tab = t; h.toggle_panel("defence", true), side, [], 60)
	for t in ["council", "draft", "assembly", "agencies", "org", "record"]:
		await walk("UN / " + t, func(): P.un_tab = t; h.toggle_panel("un", true), side, [], 70)
	# ---- full-screen and floating windows
	await walk("Research tree", func(): h.toggle_research(), func(): return h._rs, [], 80)
	await walk("Cabinet", func(): h.toggle_cabinet(), func(): return h._cabinet, [], 40)
	await walk("Message log", func(): h.toggle_log(), func(): return h._log_box, [], 30)
	await walk("Help", func(): h.toggle_help(), func(): return h._help, [], 10)
	# ---- the build list
	for tab in h.BUILD_MENU:
		await walk("Build / " + tab, func(): h.build_tab = tab; h.set_production_open(true); h._shown_key = ""; h._update_panel(), func(): return h._list, [], 40)
	# ---- selections: a building of each kind and a unit of each kind
	for key in ["hq", "missileSilo", "strategicComplex", "barracks", "tankFactory", "airfield", "helipad", "shipyard", "market", "intelAgency", "school", "university", "farm"]:
		var building = w.buildings.filter(func(b): return b.owner == 0 and b.key == key and b.built and not b.dead).front() if not w.buildings.filter(func(b): return b.owner == 0 and b.key == key and b.built and not b.dead).is_empty() else null
		if building == null:
			K.warn("ui-surface", "Building / " + key, "none in the fixture")
			continue
		await walk("Building / " + key, func(): w.select_building(building); h._update_panel(), func(): return h._list, [], 40)
	for key in ["soldier", "tank", "worker", "artillery", "jet", "helicopter", "destroyer", "landingShip", "carrier"]:
		var unit = w.units.filter(func(u): return u.owner == 0 and u.key == key and not u.dead).front() if not w.units.filter(func(u): return u.owner == 0 and u.key == key and not u.dead).is_empty() else null
		if unit == null:
			K.warn("ui-surface", "Unit / " + key, "none in the fixture")
			continue
		await walk("Unit / " + key, func(): unit.selected = true; h._update_panel(), func(): return h._sel, [], 30)
	# ---- the menus
	for tab in ["graphics", "sound", "controls", "game"]:
		await walk("Settings / " + tab, func(): w.menu.open_pause(); w.menu.settings_tab = tab; w.menu.open_settings(), func(): return w.menu._root, [], 40)
	await walk("Main menu", func(): w.menu.open_main(), func(): return w.menu._root, ["New Game", "Load Game", "Settings", "About"], 10)
	await walk("Pause menu", func(): w.menu.open_pause(), func(): return w.menu._root, ["Resume", "Save Game", "Load Game", "Settings", "About / Report a problem", "Testing tools..."], 14)
	await walk("About", func(): w.menu.open_pause(); w.menu.open_about(), func(): return w.menu._root, ["Report a problem", "Back"], 6)
	await walk("New game", func(): w.menu.open_pause(); w.menu.open_new_game(), func(): return w.menu._root, [], 80)
	await walk("Load game", func(): w.menu.open_pause(); w.menu.open_load(), func(): return w.menu._root, ["Back"], 20)
	# ---- modals: a letter, a choice, the end screen, a proposal at the UN, a diplomatic contact
	await walk("Letter (a proposal)", func(): h.ask("Test: China asks for a pact.", func(): pass, func(): pass), func(): return h, ["Accept", "Decline"], 60)
	await walk("Choice", func(): h.choose("TEST", "Choose.", [["One", "", func(): pass], ["Two", "bad", func(): pass]]), func(): return h, ["One", "Two"], 60)
	await walk("End screen", func(): h.show_end("DEFEAT", "Test"), func(): return h, [], 60)
	await walk("UN session", func(): h.open_un_session("council"), func(): return h._un_sessions, [], 30)
	await walk("Diplomatic contact", func(): h.open_diplomatic_contact(1), func(): return h._diplomatic_contact_screen, [], 40)
	# ---- last: war, which changes every other screen
	await walk("Declare war (card)", func(): P.diplomacy_tab = "nations"; h.toggle_panel("diplomacy", true), side, ["Declare war"], 90)
	reset()
	print("AUDIT_UI surfaces=%d presses=%d" % [surfaces_done, presses])
	quit(K.finish())
