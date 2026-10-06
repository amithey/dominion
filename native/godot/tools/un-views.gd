extends SceneTree
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
	preload("res://tools/test_kit.gd").quiet(w, ["un"])
	w.un.queue.clear()
	w.un.current = null
	w.diplomacy.declare_war(0, 1)
	var dr: Dictionary = w.un.table("wmd", 3, -1, 2, "a weapons incident", "targeted")
	w.un._open(dr)
	w.un._start_compliance({"target": 0, "other": 1, "measure": "peacekeeping"})
	w.un._assembly({"number": 1, "kind": "wmd", "measure": "economic", "target": 3, "other": -1, "by": 2, "cause": "a weapons incident", "title": "Restrictions following a weapons incident", "votes": {}, "lobby": {}})
	w.un._update_assembly()
	DirAccess.make_dir_recursive_absolute("res://build")
	for tab in ["council", "draft", "assembly", "org", "record"]:
		w.hud.toggle_panel("un", true)
		w.hud._panels.un_tab = tab
		w.hud.refresh_side()
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/un-%s.png" % tab)
		print("UN_CAPTURE ", tab)
	print("UN_VIEWS PASS")
	quit()
