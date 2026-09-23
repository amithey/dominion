extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func ready_world(previous := 0) -> Node:
	for i in range(2000):
		await process_frame
		if current_scene!=null and current_scene.get_instance_id()!=previous and current_scene.get("menu")!=null and current_scene.menu.get("_root")!=null:
			return current_scene
	return null
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w := await ready_world()
	if w==null:
		print("FLOW FAIL initial scene")
		quit(1)
		return
	var previous := w.get_instance_id()
	w.menu.setup_options = {"map":"mirrored","players":2,"nation":2,"style":"sandbox"}
	w.menu.start("normal")
	w = await ready_world(previous)
	if w==null or w.match_config.nation!=2 or w.map.nations.size()!=2 or w.ai.nations.size()!=1 or paused:
		print("FLOW FAIL new campaign")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	previous = w.get_instance_id()
	set_meta("match_config",w.MatchSetup.normalize(data.match_config))
	set_meta("pending_load",data)
	reload_current_scene()
	w = await ready_world(previous)
	var ok: bool = w!=null and w.map.nations.size()==2 and w.match_config.nation==2 and not paused
	print("CAMPAIGN FLOW ","PASS" if ok else "FAIL")
	if w!=null:
		for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
			for player in w.find_children("*",kind,true,false):
				player.stop()
	await create_timer(0.15).timeout
	quit(0 if ok else 1)
