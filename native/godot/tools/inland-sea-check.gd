extends SceneTree
## A big sea enclosed by land (Inland Sea, Crown, Archipelago, Ten Isles) counts as sea: coast for a shipyard.
var w: Node
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func run() -> void:
	for key in ["inland_sea", "crown", "ten_isles", "archipelago"]:
		set_meta("match_config", {"map": key, "players": 2, "nation": 0, "style": "sandbox", "fog": false})
		change_scene_to_file("res://world.tscn")
		w = null
		for i in range(40000):
			await process_frame
			if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
				w = current_scene
				break
		var centre := Vector3(0, 0, 0)
		var found := false
		var shore := Vector3.ZERO
		for r in range(0, 600, 5):
			for i in range(24):
				var a := i * TAU / 24.0
				var p := Vector3(cos(a), 0, sin(a)) * r
				if w.is_water(p, -0.5) and w.lake_at(p):
					check(false, "%s: water at %d m from the middle is still a lake" % [key, r])
					found = true
					break
			if found: break
		var water_cells := 0
		var coast_ok := false
		for r in range(0, 500, 4):
			for i in range(36):
				var a := i * TAU / 36.0
				var p := Vector3(cos(a), 0, sin(a)) * r
				p.y = w.height_at(p.x, p.z)
				if w.is_water(p, -0.5):
					water_cells += 1
				elif water_cells > 40 and not coast_ok and w.coast_near(p, w.logistics.radius * 1.6):
					coast_ok = true
		check(not found, "%s: no part of the middle sea is a lake" % key)
		check(water_cells > 40 and coast_ok, "%s: dry ground beside the middle sea counts as coast (%d water samples)" % [key, water_cells])
	print("INLAND_SEA ", "PASS" if errors.is_empty() else "FAIL %d" % errors.size())
	quit(0 if errors.is_empty() else 1)
