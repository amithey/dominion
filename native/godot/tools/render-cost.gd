## Where the frame goes: for four camera views of the island (the capital, the densest wood, open ground, the whole island) the frame
## time, draw calls and triangles with everything on, then with the trees, the grass, the shadows and the water each switched off,
## so the cost of each can be read as the difference. Run windowed:
##   Godot --path native/godot -s res://tools/render-cost.gd           (writes build/render-cost.txt)
extends SceneTree
const Perf := preload("res://scripts/building_perf.gd")
var w: Node
func _initialize() -> void: call_deferred("run")
## Average GPU and CPU render time (ms) and draw calls, triangles over `frames` frames.
func gpu_measure(frames: int) -> Dictionary:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in range(25):
		await process_frame
	var g := 0.0
	var c := 0.0
	var calls := 0
	var prims := 0
	for i in range(frames):
		await process_frame
		g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		c += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	return {"gpu": g / frames, "cpu": c / frames, "calls": calls / frames, "tris": prims / frames}

func view(name: String, focus: Vector3, dist: float, pitch: float, yaw: float) -> void:
	w.cam_focus = focus
	w.cam_dist = dist
	w.cam_dist_target = dist
	w.cam_pitch = pitch
	w.cam_yaw = yaw
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # the real cost, not the 60 fps cap
	Engine.max_fps = 0
	w.start_match("easy")
	w.menu.close()
	w.edge_scroll = false
	var dense := Vector3.ZERO
	var most := -1
	for t in w.map.trees:
		var n := 0
		for u in w.map.trees:
			if absf(u.x - t.x) < 14.0 and absf(u.z - t.z) < 14.0:
				n += 1
		if n > most:
			most = n
			dense = Vector3(t.x, w.height_at(t.x, t.z), t.z)
	var views := {"capital": [w.start, 70.0, 0.75, 0.6], "wood": [dense, 60.0, 0.6, 0.7], "open land": [Vector3(0, 0, 0), 110.0, 0.9, 0.3], "whole island": [Vector3(0, 0, 0), 420.0, 1.3, 0.0]}
	var lines := PackedStringArray()
	lines.append("%-14s %-16s %8s %8s %8s %10s" % ["view", "switched off", "gpu ms", "cpu ms", "calls", "triangles"])
	for name in views:
		var v: Array = views[name]
		view(name, v[0], v[1], v[2], v[3])
		var sun_shadow: bool = w.sun.shadow_enabled
		for off in ["nothing", "trees", "grass", "shadows", "water", "buildings"]:
			var hide_nodes: Array = []
			match off:
				"trees": hide_nodes = w.tree_nodes
				"grass": hide_nodes = w.grass_nodes
				"water": hide_nodes = [w.sea_node]
				"buildings": hide_nodes = w.buildings.map(func(b): return b.root)
				"shadows": w.sun.shadow_enabled = false
			for n in hide_nodes:
				if is_instance_valid(n): n.visible = false
			var r: Dictionary = await gpu_measure(80)
			lines.append("%-14s %-16s %8.1f %8.1f %8d %10d" % [name, off, r.gpu, r.cpu, r.calls, r.tris])
			for n in hide_nodes:
				if is_instance_valid(n): n.visible = true
			w.sun.shadow_enabled = sun_shadow
	var f := FileAccess.open("res://build/render-cost.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	for l in lines: print("RC ", l)
	quit()
