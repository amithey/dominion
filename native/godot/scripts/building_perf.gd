## --perf-buildings: how heavy are the Blender-made buildings together? A block of cities (every building the game can draw,
## repeated) is placed round the camera and the frame time, draw calls and triangles are measured, with the Blender models and
## with the older code-built ones (build/perf-buildings.txt).
extends RefCounted

const KEYS := ["hq", "villageCenter", "cottage", "residential", "workerHouse", "luxuryVillas", "housing", "apartments", "farm", "foodDepot", "warehouse",
	"powerPlant", "nuclearReactor", "market", "cityCenter", "bank", "cityHall", "school", "library", "university", "hospital", "policeStation", "fireStation",
	"courthouse", "tvStation", "techPark", "intelAgency", "chipFab", "aiDataCenter", "park", "stadium", "oilRefinery", "tankFactory", "railwayStation",
	"barracks", "bunker", "samSite", "ammoDepot", "airfield", "helipad", "missileSilo", "commandCenter", "waterTreatment", "solarFarm", "worship", "prison", "embassy", "stockExchange"]

static func measure(w: Node, frames: int) -> Dictionary:
	for i in range(20):
		await w.get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var calls := 0
	var prims := 0
	for i in range(frames):
		await w.get_tree().process_frame
		calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	return {"ms": ms, "calls": calls / frames, "tris": prims / frames, "mem_mb": OS.get_static_memory_usage() / 1048576.0}

static func place_range(w: Node, from: int, to: int, spread: float) -> void:
	var centre: Vector3 = w.start + Vector3(0, 0, -60)
	for i in range(from, to):
		var key: String = KEYS[i % KEYS.size()]
		var at: Vector3 = w.snap_to_hex(centre + Vector3((i % 8 - 3.5) * spread, 0, (i / 8 - 3.0) * spread))
		w.place_building(key, at, 0, true)

static func run(w: Node) -> void:
	for i in range(30):
		await w.get_tree().process_frame
	w.edge_scroll = false
	var BM := preload("res://scripts/building_models.gd")
	var lines := PackedStringArray()
	w.cam_focus = w.start + Vector3(0, 0, -60)
	w.cam_yaw = 0.4
	w.cam_pitch = 0.9
	var base: Dictionary = await measure(w, 90)
	lines.append("baseline (no extra buildings): %.1f ms  %d calls  %d tris" % [base.ms, base.calls, base.tris])
	var mode := "code-built" if "--code-built" in OS.get_cmdline_user_args() + OS.get_cmdline_args() else "blender"
	BM.blender_enabled = mode == "blender"
	var placed := 0
	for count in [16, 48]:
		var t0 := Time.get_ticks_usec()
		place_range(w, placed, count, 30.0)
		placed = count
		var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		for dist in [90.0, 220.0]:
			w.cam_dist = dist
			w.cam_dist_target = dist
			var r: Dictionary = await measure(w, 90)
			lines.append("%-10s %2d buildings  camera %3d m: %.1f ms/frame (%.0f fps)  %d draw calls  %.2f M tris   placed in %.0f ms  mem %.0f MB" % [mode, count, int(dist), r.ms, 1000.0 / maxf(r.ms, 0.01), r.calls, r.tris / 1.0e6, build_ms, r.mem_mb])
	var f := FileAccess.open("res://build/perf-%s.txt" % mode, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	for l in lines:
		print("PERF ", l)
	w.get_tree().quit()
