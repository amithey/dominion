extends SceneTree
## Captures the AI tab's five pages (build/ai-<page>.png) in a plausible
## mid-game state, to look at the layout. Run without --headless.
var w: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	w.hud.show()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "defcon"])
	var a = w.directorate
	for k in ["machineLearning", "militaryAI", "frontierModels", "agiProject", "cyberWarfare", "collaborativeCombatAircraft"]:
		w.research.progress[k].stage = 3
	w.research._recompute()
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	w.economy.res.silicon = 900.0
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq0 + Vector3(-50, 0, 40)), 0, true)
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq0 + Vector3(-70, 0, 60)), 0, true)
	a.st[0].level = 4
	a.alloc = {"military": 30.0, "economy": 30.0, "intel": 20.0, "frontier": 20.0}
	a.st[0].reserve = 420.0
	a.st[1].level = 3
	a.st[2].level = 2
	a.agi[0] = {"stage": 1, "progress": 1200.0, "alignment": 400.0}
	a.agi[1] = {"stage": 0, "progress": 800.0, "alignment": 50.0}
	w.diplomacy.declare_war(0, 1)
	a.set_doctrine("on")
	for i in range(3): a.update(1.0)
	a._rival_doctrines()
	a._note("AI CYBER: the agents broke into China: factories and construction down for 100s.")
	DirAccess.make_dir_recursive_absolute("res://build")
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	for page in ["compute", "doctrine", "operations", "agi", "rivals"]:
		a.ui_tab = page
		w.hud.refresh_side()
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/ai-%s.png" % page)
		print("AI_CAPTURE ", page)
	print("AI_VIEWS PASS")
	quit()
