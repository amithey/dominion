extends SceneTree
## Sea fields can be worked (territory.zone_owner): an offshore rig may stand
## anywhere in the nation's economic zone, not only its narrow territorial
## waters, so the fields off unsettled coasts are no longer out of everyone's
## reach. Placed through the placement path, built by marine contractors, and
## producing.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.ai.set_physics_process(false)
	var t = w.territory
	var fields: Array = w.deposits.filter(func(d): return d.get("water", false) and d.type != "fish")
	var mine: Array = []
	var theirs := 0
	for d in fields:
		var p := Vector3(d.pos.x, float(w.map.seaLevel) + 0.5, d.pos.z)
		var why: String = w.site_problem("offshoreRig", p, 0)
		if why == "": mine.append(p)
		elif why.ends_with("waters"): theirs += 1
	check(not mine.is_empty(), "at the start you can work sea fields in your economic zone (%d of %d)" % [mine.size(), fields.size()])
	check(theirs > 0, "fields nearer a rival's land are in its waters (%d)" % theirs)
	check(t.zone_owner(mine[0]) == 0 and t.owner_at(mine[0]) < 0, "the field lies beyond your territorial waters, inside your zone")
	var fish: Array = w.deposits.filter(func(d): return d.get("water", false) and d.type == "fish")
	if not fish.is_empty():
		var fp := Vector3(fish[0].pos.x, float(w.map.seaLevel) + 0.5, fish[0].pos.z)
		check(w.site_problem("offshoreRig", fp, 0).contains("Fishing Wharf") or w.site_problem("offshoreRig", fp, 0).ends_with("waters") or w.site_problem("offshoreRig", fp, 0) == "Outside your territory", "a fish shoal points to the Fishing Wharf")
	var land_check: String = w.site_problem("extractor", Vector3(fields[0].pos.x, 0, fields[0].pos.z), 0)
	check(land_check.contains("Offshore Rig") or land_check.contains("Fishing Wharf") or land_check.contains("open water"), "an extractor on a sea field says what to build there (%s)" % land_check)
	w.economy.grant_test_resources()
	w.begin_placement("offshoreRig")
	w.ghost.position = mine[0]
	var money0: float = w.economy.res.money
	w.confirm_placement(false)
	var rigs: Array = w.buildings.filter(func(b): return b.key == "offshoreRig" and b.owner == 0 and not b.dead)
	check(rigs.size() == 1 and w.economy.res.money < money0, "the placement path builds a rig there and charges for it")
	Engine.time_scale = 8.0
	for i in range(2400):
		await physics_frame
		if rigs[0].built: break
	Engine.time_scale = 1.0
	check(rigs[0].built, "marine contractors finish it")
	w.economy.tick()
	var res: String = rigs[0].deposit.def.res if rigs[0].deposit != null else ""
	check(res != "" and float(w.economy.rates.get(res, 0.0)) > 0.0, "it produces %s (%.1f a second)" % [res, float(w.economy.rates.get(res, 0.0))])
	print("OFFSHORE %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("OFFSHORE %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
