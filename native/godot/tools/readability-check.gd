extends SceneTree
var w: Node
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label); push_error(label)
func settle() -> void:
	for i in range(20): await process_frame
func shot(name: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/readability-%s.png" % name)
func cards() -> Array:
	return w.hud._list.get_children().filter(func(c): return c is Button and c.has_meta("cost"))
func verify_cards() -> void:
	await settle()
	for card in cards():
		var content: Control = card.get_child(0)
		check(content.get_combined_minimum_size().y <= card.size.y - 17, "Card fits all text vertically")
		check(content.get_combined_minimum_size().x <= content.size.x + 1, "Card text fits horizontally")
		check(card.find_child("ActionLabel", true, false) != null, "Card explains its action")
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene; break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu.close()
	w.ui_scale = 1.0
	w.apply_ui_scale()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "defcon", "events", "support", "un"])
	w.economy.grant_test_resources()
	w.hud.set_production_open(true)
	await verify_cards()
	await shot("build")
	var silo: Dictionary = w.place_building("missileSilo", w.start + Vector3(18,0,18), 0, true)
	w.select_building(silo)
	await verify_cards()
	check(not cards().is_empty(), "Weapon production has cards")
	if not cards().is_empty(): check(cards()[0].get_meta("cost") == w.missiles.production_cost(w.missiles.listed_at("missileSilo")[0]), "Displayed weapon price matches the charged national cost")
	for c in cards(): check(c.find_child("ActionLabel", true, false).text.begins_with("Produce"), "Production never arms a weapon")
	await shot("missiles")
	check(w.hud._extra.defcon[1].get_global_rect().end.x < w.hud.find_child("TimeControls", true, false).get_child(0).get_global_rect().position.x, "Resource strip stays clear of time controls at 100%")
	for i in range(w.missiles.storage_slots(silo)):
		w.missiles.finished("tactical", silo)
	w.hud._missile_view = "stockpile"
	w.hud._shown_key = ""
	w.hud._update_panel()
	await verify_cards()
	var targets: Array = cards().filter(func(c): return c.find_child("ActionLabel", true, false).text.begins_with("Choose target"))
	check(cards().size() == 2 and targets.size() == 1, "Stockpile offers transfer and launch for the local weapon")
	if not targets.is_empty():
		check(targets[0].find_child("ActionLabel", true, false).text.contains("1 stored weapon"), "Targeting action and inventory use are explicit")
		targets[0].pressed.emit()
		check(w.missiles.local_count(silo, "tactical") == w.missiles.storage_slots(silo), "Selecting a target does not spend inventory")
		w.cancel_placement()
	await shot("stockpile")
	w.hud._missile_view = "production"
	w.hud._shown_key = ""
	w.hud._update_panel()
	await verify_cards()
	check(cards().any(func(c): return c.disabled and c.tooltip_text.to_lower().contains("storage full")), "Full storage explains and disables production")
	w.ui_scale = 0.8
	w.apply_ui_scale()
	await verify_cards()
	w.ui_scale = 1.0
	w.apply_ui_scale()
	w.select_building(null)
	w.hud.set_production_open(false)
	for mode in ["diplomacy", "market", "intel", "defence"]:
		w.hud.toggle_panel(mode, true)
		await shot(mode)
		check(root.get_visible_rect().grow(2).encloses(w.hud._win.get_global_rect()), mode + " fits viewport")
	print("READABILITY_CHECK ", "PASS" if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)
