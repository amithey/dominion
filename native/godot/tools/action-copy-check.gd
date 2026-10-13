extends SceneTree
const Copy := preload("res://scripts/action_copy.gd")
const Weapon := preload("res://scripts/weapon_copy.gd")
var w: Node
var errors: Array[String] = []
var checks := 0
var audit: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + words)
	if not ok: errors.append(words)
func frames(n := 6) -> void:
	for i in range(n): await process_frame
func cards() -> Array:
	return w.hud._list.get_children().filter(func(c): return c is Button and c.has_meta("cost"))
func scan(page: String) -> void:
	await frames()
	var buttons: Array = root.find_children("*", "BaseButton", true, false).filter(func(b): return b.is_visible_in_tree())
	var missing: Array = []
	for b in buttons:
		w.hud.get_node("ButtonHints").update(b)
		if b.tooltip_text.strip_edges().length() < 10: missing.append(b.text if b is Button else b.name)
		audit.append(page + " | " + (b.text if b is Button else str(b.name)) + " | " + b.tooltip_text.replace("\n", " / "))
	check(missing.is_empty(), "%s: all %d visible buttons have explanatory help %s" % [page, buttons.size(), missing])
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/action-copy-" + name + ".png")
func run() -> void:
	set_meta("match_config", {"map":"island", "players":4, "nation":0, "opening":"light"})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(1); return
	if w.menu._root == null: w.menu.setup(w)
	root.size = Vector2i(1280,800)
	w.start_match("easy"); w.menu.close()
	w.set_physics_process(false); w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["un", "directorate", "defcon", "support"])
	w.ui_scale = 1.0; w.apply_ui_scale()
	w.economy.grant_test_resources()
	await scan("HUD")
	w.hud.set_production_open(true); await scan("Construction")
	var silo: Dictionary = w.place_building("missileSilo", w.start + Vector3(18,0,18), 0, true)
	w.select_building(silo)
	await scan("Weapon production")
	check(not cards().is_empty(), "Weapon production remains available")
	for card in cards():
		check(card.tooltip_text.contains("queue ONE") and card.tooltip_text.contains("does not fire"), "Production explains storage and does not imply a launch")
		check(card.get_child(0).get_combined_minimum_size().y <= card.size.y - 17, "Weapon copy fits its dynamically sized card")
	await shot("production")
	if DisplayServer.get_name() != "headless" and not cards().is_empty():
		var motion := InputEventMouseMotion.new()
		motion.position = cards()[0].get_global_rect().get_center()
		root.push_input(motion)
		await create_timer(1.2).timeout
		await shot("weapon-help")
	var cash: float = w.economy.res.money
	var amount: int = w.missiles.stored()
	var queue_size: int = silo.queue.size()
	for card in cards(): card.mouse_entered.emit(); card.focus_entered.emit()
	check(w.economy.res.money == cash and w.missiles.stored() == amount and silo.queue.size() == queue_size, "Reading help neither spends resources nor queues or launches a weapon")
	if not cards().is_empty():
		var first: String = w.missiles.listed_at("missileSilo")[0]
		cards()[0].pressed.emit()
		check(silo.queue.size() == queue_size + 1 and w.missiles.stored() == amount, "Production button still queues one weapon without firing it")
		w.cancel_queued(silo, 0)
	w.missiles.stock.tactical = 1
	w.hud._missile_view = "stockpile"; w.hud._shown_key = ""; w.hud._update_panel()
	await scan("Stockpile targeting")
	check(cards().size() == 1 and cards()[0].tooltip_text.contains("launch ONE"), "Stockpile explains the actual next click")
	if not cards().is_empty():
		cards()[0].pressed.emit()
		check(w.missile_aim == "tactical" and w.missiles.stock.tactical == 1, "Target selection still preserves inventory until launch")
		w.cancel_placement()
	await shot("stockpile")
	# Cover every payload installed in this campaign, including national families.
	for key in w.missiles.types():
		var def: Dictionary = w.missiles.def_of(key)
		var help := Weapon.summary(w, key)
		check(help.contains("Role:") and help.contains("Launch from:"), "%s has a practical role and correct platform category" % key)
		if str(def.get("special", "")) in ["emp", "hemp"]:
			check(help.contains("no blast damage") and not help.contains("centre damage"), "%s does not advertise fictitious blast damage" % key)
	check(Weapon.role({"special":"antiShip"}, "").contains("quarter"), "Anti-ship copy discloses its land-target weakness")
	check(Weapon.role({"special":"cluster"}, "").contains("weak against buildings"), "Cluster copy distinguishes its target type")
	check(Weapon.display_name(w, "tactical") != Weapon.display_name(w, "ballistic"), "Shared national family names still distinguish tactical and ballistic choices")
	w.select_building(null); w.hud.set_production_open(false)
	for mode in ["diplomacy", "market", "intel", "defence", "territory", "un"]:
		w.hud.toggle_panel(mode, true); await scan(mode)
	var sp = w.hud._panels
	for tab in ["agents", "dossiers", "reports", "space"]:
		sp.intel_tab = tab; w.hud.toggle_panel("intel", true); await scan("Intel / " + tab)
	for tab in ["generals", "veterans", "nuclear", "arsenal", "ai"]:
		sp.defence_tab = tab; w.hud.toggle_panel("defence", true); await scan("Defence / " + tab)
	for tab in ["compute", "applications", "doctrine", "operations", "agi", "rivals"]:
		w.directorate.ui_tab = tab; w.hud.refresh_side(); await scan("AI / " + tab)
		if tab == "compute":
			var plus: Array = w.hud._side_rows.find_children("*", "Button", true, false).filter(func(b): return b.text == "+")
			check(not plus.is_empty() and plus[0].tooltip_text.contains("10 percentage"), "AI allocation controls disclose their exact step")
	for tab in ["council", "draft", "assembly", "org", "record"]:
		sp.un_tab = tab; w.hud.toggle_panel("un", true); await scan("UN / " + tab)
	w.hud._show_side(""); w.hud.toggle_research(); await scan("Research"); w.hud.toggle_research()
	w.menu.open_pause(); await scan("Pause menu")
	w.menu.open_new_game(); await scan("New campaign")
	for tab in ["graphics", "sound", "controls", "game"]:
		w.menu.settings_tab = tab; w.menu.open_settings(); await scan("Settings / " + tab)
	w.menu.close()
	var hints: Node = w.hud.get_node("ButtonHints")
	var b := Button.new(); b.text = "Declare war"; w.hud.add_child(b); await frames()
	check(b.has_meta("copy_registered") and b.tooltip_text.contains("Start a war"), "A late-created button is automatically explained")
	var before: String = b.tooltip_text
	for i in range(5): hints.update(b)
	check(b.tooltip_text == before, "Repeated hovering never duplicates the explanation")
	b.tooltip_text = "Unavailable: needs an agreement."
	hints.update(b)
	check(b.tooltip_text.contains("Unavailable") and b.tooltip_text.contains("Start a war"), "Dynamic blocking reasons survive alongside the explanation")
	b.queue_free()
	# Generic context-only controls must keep their explanation across hovers.
	var box := HBoxContainer.new(); w.hud.add_child(box)
	var caption := Label.new(); caption.text = "Example setting"; box.add_child(caption)
	var unknown := Button.new(); unknown.text = "Medium"; unknown.toggle_mode = true; box.add_child(unknown)
	await frames(); hints.update(unknown)
	var context_tip: String = unknown.tooltip_text
	hints.update(unknown)
	check(unknown.tooltip_text == context_tip and context_tip.contains("Example setting"), "Context-only controls retain their own nearby explanation across hovers")
	box.queue_free()
	var purchase := Button.new(); purchase.text = "Example purchase"
	purchase.set_meta("cost", {"money":100.0})
	var old_money: float = w.economy.res.money
	w.economy.res.money = 0; w.hud.add_child(purchase); await frames()
	hints.update(purchase)
	check(purchase.tooltip_text.contains("Unavailable: need"), "Unaffordable actions explain the missing resources")
	w.economy.res.money = old_money; hints.update(purchase)
	check(not purchase.tooltip_text.contains("Unavailable: need"), "Resource explanation clears when the action becomes affordable")
	purchase.queue_free()
	var file := FileAccess.open("res://build/action-copy-audit.txt", FileAccess.WRITE)
	file.store_string("\n".join(PackedStringArray(audit)))
	print("ACTION_COPY PASS %d" % checks if errors.is_empty() else "ACTION_COPY FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
