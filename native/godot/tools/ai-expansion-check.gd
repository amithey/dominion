extends SceneTree
## Rival nations grow as states: over fifteen minutes of a standard match each
## founds new villages and cities (not a capital with one village), keeps
## building, and never stalls on a building it has no room for.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 0.5
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func settlements(owner: int) -> Dictionary:
	var out := {"hq": 0, "cityCenter": 0, "villageCenter": 0}
	for b in w.buildings:
		if b.owner == owner and not b.dead and b.key in out:
			out[b.key] += 1
	return out

func run() -> void:
	var map: String = OS.get_environment("EXPANSION_MAP") if OS.get_environment("EXPANSION_MAP") != "" else "island"
	set_meta("match_config", {"map": map, "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.ai.set_physics_process(false)
	var start := {}
	for n in w.ai.nations: start[n.id] = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
	var minutes := 15
	for m in range(minutes):
		var t := 0.0
		while t < 60.0:
			w.game_time += DT
			w.ai._physics_process(DT)
			for node in [w.economy, w.research, w.territory, w.diplomacy]:
				node._process(DT)
			t += DT
		var line := PackedStringArray()
		for n in w.ai.nations:
			var s := settlements(n.id)
			line.append("%s %d+%d+%d/%d" % [n.name.split(" ")[0], s.hq, s.cityCenter, s.villageCenter, w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()])
		print("minute %2d  %s" % [m + 1, "   ".join(line)])
	for n in w.ai.nations:
		var s := settlements(n.id)
		var towns: int = s.cityCenter + s.villageCenter
		var total: int = w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()
		check(towns >= 3 and s.cityCenter >= 1, "%s founds new towns in %d minutes: %d cities and %d villages besides its capital" % [n.name, minutes, s.cityCenter, s.villageCenter])
		check(total >= int(start[n.id]) + 20, "%s keeps building (%d -> %d buildings)" % [n.name, int(start[n.id]), total])
	print("\nAI_EXPANSION: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("AI_EXPANSION PASS" if errors.is_empty() else "AI_EXPANSION FAIL")
	quit(0 if errors.is_empty() else 1)
