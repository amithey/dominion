extends SceneTree
var w: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "defcon", "events", "support", "un"])
	var a = w.directorate
	w.research.era = 5
	w.economy.grant_test_resources()
	for res in w.economy.res: w.economy.res[res] = 50000.0
	for key in ["machineLearning", "militaryAI", "frontierModels"]: w.research.progress[key].stage = 3
	for key in a.applications.Data.PROGRAMS.values(): w.research.progress[key.research].stage = 3
	for key in ["powerPlant", "fusionCell", "university", "hospital", "farm", "library", "school", "barracks", "techPark", "aiDataCenter"]:
		w.place_building(key, w.start + Vector3(40 + randf() * 90, 0, 50 + randf() * 70), 0, true)
	a.st[0].level = 4
	a._refresh(0)
	a.applications.row(0, "administration").validated = true
	a.applications.commission(0, "administration")
	a.applications.start(0, "agriculture")
	a.applications.row(0, "agriculture").work = 31.0
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	a.ui_tab = "applications"
	DirAccess.make_dir_recursive_absolute("res://build")
	for group in ["civil", "security", "state"]:
		a.applications.category = group
		w.hud.refresh_side()
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ai-applications-%s.png" % group)
	print("AI_APPLICATIONS_VIEWS PASS")
	quit()
