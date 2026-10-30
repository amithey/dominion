extends SceneTree
## [customer round 5 variant: the laptop and the ultrawide] Audit of how every surface looks (native/ALPHA-1.0-REPORT.md), in a real window (not --headless):
## each surface and tab is opened at 1280x720, 1600x900 and 1920x1080 (and at UI scales 0.8 and 1.25 on the smallest),
## and every visible control is checked for what a player complains about: type under 11 px, labels cut off or
## shown as "...", buttons under 22 px, controls off the screen, buttons with no text, icon or tooltip. A screenshot
## of each surface at 1600x900 goes to res://build/audit-layout/. Findings: res://build/audit/layout.txt
## Run:  Godot_v4.7.2-stable_win64.exe --path . -s res://tools/audit-layout.gd
const Kit := preload("res://tools/audit_kit.gd")
var K
var w: Node
var seen := {}
var shots := 0

func _initialize() -> void: call_deferred("run")

func shot(name: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/audit-layout")
	root.get_texture().get_image().save_png("res://build/audit-layout/%s.png" % name.replace("/", "-").replace(" ", "_"))
	shots += 1

func audit(where: String) -> void:
	var vp := root.get_visible_rect()
	var stack: Array = [root]
	var items: Array = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.push_back(c)
		if n is Control and n.is_visible_in_tree() and n.size.x > 0 and n.size.y > 0:
			items.append(n)
	var found := 0
	for c: Control in items:
		var r := c.get_global_rect()
		if c is Label or c is Button or c is RichTextLabel or c is LineEdit:
			var txt: String = str(c.get("text")) if c.get("text") != null else ""
			var fs: int = c.get_theme_font_size("font_size")
			if txt.strip_edges() == "" and c is Label: continue
			if fs > 0 and fs < 11 and txt.length() > 3:
				found += add("small", where, "type %dpx: \"%s\"" % [fs, txt.substr(0, 40)], "tiny %s %d" % [txt.substr(0, 20), fs])
			if c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF and not c.clip_text and txt != "" and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				var need: float = c.get_minimum_size().x
				if c.size.x + 1.0 < need:
					found += add("clipped", where, "label cut off (%d of %d px): \"%s\"" % [c.size.x, need, txt.substr(0, 50)], "clip " + txt.substr(0, 30))
			if c is Label and c.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and c.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var font: Font = c.get_theme_font("font")
				var wpx := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if wpx > c.size.x + 2.0 and c.size.x > 20:
					found += add("truncated", where, "shown with '...' (%d of %d px): \"%s\"" % [c.size.x, wpx, txt.substr(0, 50)], "ellip " + txt.substr(0, 30))
			if c is Button and not c.disabled and (r.size.x < 22 or r.size.y < 22) and c.get_class() != "OptionButton":
				found += add("small-target", where, "button '%s' is %dx%d px" % [c.name, r.size.x, r.size.y], "tiny-btn %s" % c.name)
			if c is Button and txt.strip_edges() == "" and c.tooltip_text == "" and c.icon == null:
				found += add("unlabelled", where, "button '%s' has no text, icon or tooltip" % c.name, "unl %s" % c.name)
		if r.size.x > 4 and r.size.y > 4 and (r.position.x < -2 or r.position.y < -2 or r.end.x > vp.size.x + 2 or r.end.y > vp.size.y + 2):
			if (c is PanelContainer or c is Button or c is Label) and not clipped_by_ancestor(c):
				found += add("offscreen", where, "'%s' sticks out of the screen %s" % [c.name, r], "off %s" % c.name)
	if found == 0:
		K.ok("layout", where, "%d controls checked" % items.size())

## True when a scroll area (or any container that clips) above `c` hides what lies beyond its edge: that is not off the screen.
func clipped_by_ancestor(c: Control) -> bool:
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer or (n is Control and n.clip_contents):
			return true
		n = n.get_parent()
	return false

## Records a finding once per (kind, key) per resolution; returns 1 if new.
func add(kind: String, where: String, what: String, key: String) -> int:
	var k := "%s|%s|%s" % [kind, key, str(root.get_visible_rect().size)]
	if seen.has(k): return 0
	seen[k] = true
	K.warn("layout-" + kind, where, what)
	return 1

func reset() -> void:
	var h: Node = w.hud
	if w.menu != null: w.menu.close()
	if h._rs != null and h._rs.visible: h.toggle_research()
	if h._cabinet != null and h._cabinet.visible: h._cabinet.close()
	h._show_side("")
	if h._log_box != null: h._log_box.hide()
	if h._help != null: h._help.hide()
	h.set_production_open(false)
	w.select_building(null)
	for u in w.units: u.selected = false
	h.close_end()
	h._letters.clear()
	if h._letter_box != null and is_instance_valid(h._letter_box):
		h._letter_box.queue_free()
		h._letter_box = null
	if h._un_sessions != null: h._un_sessions.close()
	if h._diplomatic_contact_screen != null: h._diplomatic_contact_screen.hide()

func surfaces() -> Array:
	var h: Node = w.hud
	var P: RefCounted = h._panels
	var out: Array = []
	out.append(["hud", func(): pass])
	for t in ["nations", "world", "stats", "orders"]:
		out.append(["diplomacy-" + t, func(): P.diplomacy_tab = t; h.toggle_panel("diplomacy", true)])
	for m in ["overview", "gdp", "fragility"]:
		out.append(["statistics-" + m, func(): P.diplomacy_tab = "stats"; P.stats_metric = m; h.toggle_panel("diplomacy", true)])
	for t in ["operations", "agents", "dossiers", "reports", "space"]:
		out.append(["intel-" + t, func(): P.intel_tab = t; h.toggle_panel("intel", true)])
	for t in ["exchange", "routes"]:
		out.append(["market-" + t, func(): P.market_tab = t; h.toggle_panel("market", true)])
	for t in ["yours", "nations"]:
		out.append(["territory-" + t, func(): P.territory_tab = t; h.toggle_panel("territory", true)])
	for t in ["generals", "veterans", "nuclear", "arsenal"]:
		out.append(["defence-" + t, func(): P.defence_tab = t; h.toggle_panel("defence", true)])
	for t in ["compute", "applications", "doctrine", "operations", "agi", "rivals"]:
		out.append(["ai-" + t, func(): P.defence_tab = "ai"; w.directorate.ui_tab = t; h.toggle_panel("defence", true)])
	for t in ["council", "draft", "assembly", "agencies", "org", "record"]:
		out.append(["un-" + t, func(): P.un_tab = t; h.toggle_panel("un", true)])
	out.append(["research", func(): h.toggle_research()])
	out.append(["cabinet", func(): h.toggle_cabinet()])
	out.append(["log", func(): h.toggle_log()])
	out.append(["help", func(): h.toggle_help()])
	for tab in h.BUILD_MENU:
		out.append(["build-" + tab, func(): h.build_tab = tab; h.set_production_open(true); h._shown_key = ""; h._update_panel()])
	for key in ["hq", "missileSilo", "barracks", "shipyard", "intelAgency"]:
		out.append(["building-" + key, func():
			var list: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == key and b.built and not b.dead)
			if not list.is_empty(): w.select_building(list[0]); h._update_panel()])
	for key in ["soldier", "tank", "jet", "destroyer", "landingShip", "carrier"]:
		out.append(["unit-" + key, func():
			var list: Array = w.units.filter(func(u): return u.owner == 0 and u.key == key and not u.dead)
			if not list.is_empty(): list[0].selected = true; h._update_panel()])
	out.append(["letter", func(): h.ask("China asks for a non-aggression pact.", func(): pass, func(): pass)])
	out.append(["end-screen", func(): h.show_end("DEFEAT", "Test")])
	out.append(["un-session", func(): h.open_un_session("council")])
	out.append(["diplomatic-contact", func(): h.open_diplomatic_contact(1)])
	out.append(["menu-pause", func(): w.menu.open_pause()])
	out.append(["menu-about", func(): w.menu.open_pause(); w.menu.open_about()])
	for tab in ["graphics", "sound", "controls", "game"]:
		out.append(["settings-" + tab, func(): w.menu.open_pause(); w.menu.settings_tab = tab; w.menu.open_settings()])
	out.append(["menu-new-game", func(): w.menu.open_pause(); w.menu.open_new_game()])
	out.append(["menu-load", func(): w.menu.open_pause(); w.menu.open_load()])
	out.append(["menu-main", func(): w.menu.open_main()])
	return out

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("audit-layout needs a window: run without --headless")
		quit(2)
		return
	K = Kit.new(self, "customer5-layout")
	w = await K.boot({"map": "island", "players": 4, "nation": 0, "opening": "light"}, "easy", true)
	if w == null:
		quit(1)
		return
	w.economy.grant_test_resources()
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for key in ["market", "missileSilo", "barracks", "shipyard", "intelAgency", "school", "tankFactory", "airfield"]:
		var at = w.test_site(key, home)
		if at != null: w.place_building(key, at, 0, true)
	for key in ["soldier", "tank", "jet"]:
		w.spawn_unit(key, home + Vector3(12, 0, 12), 0)
	var sea := Vector3.INF
	for r in range(30, 260, 8):
		for a in range(0, 360, 12):
			var p := home + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * r
			if w.height_at(p.x, p.z) < -6.0:
				sea = Vector3(p.x, 0, p.z)
				break
		if sea != Vector3.INF: break
	if sea != Vector3.INF:
		for key in ["destroyer", "landingShip", "carrier"]:
			w.spawn_unit(key, sea + Vector3(randf() * 20.0, 0, randf() * 20.0), 0)
	for i in range(2): w.espionage.recruit()
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	for i in range(30): await process_frame
	w.hud.toggle_panel("diplomacy", true)   # (the side panels are created the first time one opens)
	for i in range(4): await process_frame
	reset()
	var plans := [[Vector2i(1366, 768), 1.0], [Vector2i(1024, 768), 1.0], [Vector2i(1280, 800), 1.0], [Vector2i(1024, 600), 0.8], [Vector2i(2560, 1440), 1.0], [Vector2i(3440, 1440), 1.0]]
	for plan in plans:
		DisplayServer.window_set_size(plan[0])
		root.size = plan[0]
		w.ui_scale = plan[1]
		w.apply_ui_scale()
		for i in range(8): await process_frame
		var tag := "%dx%d@%.2f" % [plan[0].x, plan[0].y, plan[1]]
		K.ok("layout-size", tag, "window %s, UI scale %.2f" % [str(root.get_visible_rect().size), plan[1]])
		for entry in surfaces():
			reset()
			await process_frame
			entry[1].call()
			for i in range(4): await process_frame
			var where: String = "%s @ %s" % [entry[0], tag]
			audit(where)
			if tag == "1366x768@1.00":
				await shot(entry[0])
		K.clean("layout", tag)
	reset()
	w.ui_scale = 1.0
	w.apply_ui_scale()
	print("AUDIT_LAYOUT shots=%d" % shots)
	quit(K.finish())
