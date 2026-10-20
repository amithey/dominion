extends SceneTree
## How the rivals lay out their towns (city_planner.gd): after ten minutes of building, each rival's
## districts form a compact body (they touch several of their own), not a string of beads with
## gaps, lone arms and far-flung villages.
var errors: Array[String] = []
var passed := 0
var w: Node
const P := preload("res://scripts/city_planner.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	seed(4242)
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w.menu._root == null: w.menu.setup(w)
	w.start_match("hard"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w, ["costs"])
	Engine.time_scale = 8.0
	var until: float = w.game_time + 14.0 * 60.0
	var guard := 0
	# The idle player's capital is kept standing: on hard a rival can take it before fourteen minutes, and a
	# lost match stops the clock (this check measures the rivals' towns, not the player's defence).
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	while w.game_time < until and guard < 200000:
		await process_frame
		guard += 1
		capital.hp = capital.max_hp
	Engine.time_scale = 1.0
	w.set_physics_process(false)
	var arms_total := 0.0
	for n in range(1, w.map.nations.size()):
		var c: Dictionary = P.compactness(w, n)
		arms_total += float(c.arms)
		print("RIVAL %d districts %d mean_ring %.2f holes %d arms %.2f" % [n, c.districts, c.mean_ring, c.holes, c.arms])
		check(c.districts >= 6, "rival %d has built a town (%d districts)" % [n, c.districts])
		check(c.holes <= 3, "rival %d leaves no gaps inside its town (%d)" % [n, c.holes])
		check(c.mean_ring <= 2.4, "rival %d's districts lie close to a town centre (%.2f rings on average)" % [n, c.mean_ring])
		check(c.arms <= 0.12, "rival %d has few lone arms (%.0f%%)" % [n, c.arms * 100.0])
	check(arms_total / float(w.map.nations.size() - 1) <= 0.09, "and on average under 9%% (%.1f%%)" % [100.0 * arms_total / float(w.map.nations.size() - 1)])
	print("AI_CITY %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("AI_CITY %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
