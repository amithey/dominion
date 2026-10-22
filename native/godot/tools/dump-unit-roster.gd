extends SceneTree
## Writes res://build/unit-roster.json: every unit key each nation fields, under that nation's own name for it
## (native/tools/roster/make_roster.py turns it into native/CODEX-UNIT-ROSTER.md and .json for the model builders).
func _initialize() -> void: call_deferred("run")
func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	var w: Node = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close()
	var Factions := preload("res://scripts/factions.gd")
	var out := {"nations": [], "units": {}}
	for id in Factions.IDS:
		w.map.nations[0]["id"] = id
		out.nations.append(id)
		for key in w.unit_defs:
			if not w.unit_allowed(0, key): continue
			var def: Dictionary = w.unit_defs[key]
			var nm: String = preload("res://scripts/national_variants.gd").name_for(w, 0, key)
			if not out.units.has(key):
				out.units[key] = {"key": key, "generic": str(def.get("name", key)), "vehicle": bool(def.get("vehicle", false)), "naval": bool(def.get("naval", false)), "fly": bool(def.get("fly", false)), "nations": {}}
			out.units[key].nations[id] = nm
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/unit-roster.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("ROSTER units=%d nations=%d" % [out.units.size(), out.nations.size()])
	quit(0)
