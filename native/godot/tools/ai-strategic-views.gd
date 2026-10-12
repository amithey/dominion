extends SceneTree
var w: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": preload("res://scripts/factions.gd").IDS.find("russia"), "style": "standard"})
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
	for key in ["machineLearning", "militaryAI", "aiSecondGeneration"]: w.research.progress[key].stage = 3
	for key in ["powerPlant", "fusionCell", "university", "hospital", "missileSilo", "policeStation", "tvStation", "bank", "samSite", "aiDataCenter", "aiDataCenter"]:
		w.place_building(key, w.start + Vector3(40 + randf() * 90, 0, 50 + randf() * 70), 0, true)
	a.st[0].level = 3
	a._refresh(0)
	for key in ["deadHand", "strategic", "surveillance", "revenue"]:
		a.applications.row(0, key).validated = true
		a.applications.commission(0, key)
	a.applications.row(0, "revenue").exp = 60.0
	a.applications.start(0, "biosecurity")
	a.applications.row(0, "biosecurity").work = 30.0
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	a.ui_tab = "applications"
	DirAccess.make_dir_recursive_absolute("res://build")
	for group in ["doomsday", "state", "world", "security"]:
		a.applications.category = group
		w.hud.refresh_side()
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ai-strategic-%s.png" % group)
	print("AI_STRATEGIC_VIEWS PASS")
	quit()
