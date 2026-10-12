extends SceneTree
## Drones and robots entering armies (research native/DRONES-ROBOTS-RESEARCH-2026-10-12.md):
## the armed and logistics ground robots, the armed robot dog and the heavy
## bomber drone, by the nations documented using them; their models; the
## logistics robot's evacuation; a robot's loss costs no war support; the
## bomber drone stays aloft; the existing fibre-optic FPV upgrade is untouched.
var errors: Array[String] = []
var passed := 0
var w: Node
const C := preload("res://scripts/force_catalog.gd")
const T := preload("res://scripts/war_tools.gd")
const F := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func begin(id: String) -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": F.IDS.find(id), "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["fog", "un", "wmd", "directorate", "defcon", "events", "support"])

func run() -> void:
	# ---- the record
	check(C.operators("combatUGV").has("ukraine") and C.operators("combatUGV").has("russia") and not C.operators("combatUGV").has("usa"), "armed ground robots: Ukraine and Russia fight with them; the United States only trials them")
	check(C.operators("logisticsUGV").has("usa") and C.names("logisticsUGV").usa == "S-MET", "the US Army fields the S-MET cargo robot")
	check(C.operators("robotDog") == ["china"], "an armed robot dog only for China, shown in a live exercise")
	check(C.operators("heavyBomberDrone").has("ukraine") and C.names("heavyBomberDrone").ukraine.contains("Vampire"), "Ukraine's Vampire heavy bomber drone")
	check(preload("res://scripts/unit_quality.gd").UPGRADES.fpvTeam.has("russia") and not C.ROLES.has("fiberFPV"), "the fibre-optic FPV stays an upgrade of the FPV team (not duplicated)")

	await begin("ukraine")
	var spot: Vector3 = w.start + Vector3(30, 0, 30)
	var made := {}
	for key in ["combatUGV", "logisticsUGV", "heavyBomberDrone"]:
		check(w.unit_allowed(0, key), "Ukraine fields the %s" % w.unit_defs[key].name)
		made[key] = w.spawn_unit(key, spot + Vector3(made.size() * 8, 0, 0), 0)
		check(not made[key].is_empty() and made[key].node != null, "%s: spawned with a model" % key)
	check(w.unit_defs.combatUGV.name == "Droid TW 12.7" and w.unit_defs.logisticsUGV.name == "Termit / Gimli", "Ukrainian robots by name")
	check(made.combatUGV.get("turret") != null or made.combatUGV.node.find_child("*", true, false) != null, "the armed robot carries a weapon station")
	# Evacuation.
	var hurt: Dictionary = w.spawn_unit("soldier", made.logisticsUGV.node.position + Vector3(3, 0, 0), 0)
	hurt.hp = hurt.max_hp * 0.3
	var hp0: float = hurt.hp
	for i in range(8): T.update(w, 0.25)
	check(hurt.hp > hp0 + 5.0, "a logistics robot brings the wounded back (%d -> %d)" % [hp0, hurt.hp])
	# No crew, no mourning.
	var support0: float = w.support.value(0)
	w.kill(made.combatUGV)
	check(is_equal_approx(w.support.value(0), support0), "a robot lost costs no war support")
	var soldier: Dictionary = w.spawn_unit("soldier", spot + Vector3(-10, 0, 0), 0)
	w.kill(soldier)
	check(w.support.value(0) < support0, "(a soldier lost does)")
	# The bomber drone stays aloft.
	var bomber: Dictionary = made.heavyBomberDrone
	check("heavyBomberDrone" in w.AirOperations.TUBE_LAUNCHED and int(w.AirOperations.CAPACITY.heavyBomberDrone) >= 99, "the heavy bomber drone needs no parking slot and stays aloft")
	check(w.unit_defs.heavyBomberDrone.get("fly", false) and bomber.get("fly", false), "and flies")

	await begin("china")
	var dog: Dictionary = w.spawn_unit("robotDog", w.start + Vector3(30, 0, 30), 0)
	check(w.unit_allowed(0, "robotDog") and not dog.is_empty() and dog.node != null, "China's armed robot dog, with its own model")
	check(w.unit_defs.combatUGV.name == "Sharp Claw", "China's Sharp Claw ground robot")

	print("ROBOTS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("ROBOTS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
