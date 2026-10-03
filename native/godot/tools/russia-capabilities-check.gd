extends SceneTree
## Russia's capabilities from the war in Ukraine (national_capabilities.gd):
## three Russia-only discoveries (foreign recruits, UMPK glide bombs,
## fibre-optic drones) and the Geran-2, Russia's own Shahed.
var errors: Array[String] = []
var passed := 0
var w: Node
const Caps := preload("res://scripts/national_capabilities.gd")
const Factions := preload("res://scripts/factions.gd")
const V := preload("res://scripts/national_variants.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func complete(key: String) -> void:
	w.research.progress[key].stage = 3
	w.research._recompute()

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

func run() -> void:
	set_meta("match_config", {"map": "pangaea", "players": 2, "nation": Factions.IDS.find("russia"), "style": "sandbox"})
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
	w.diplomacy.declare_war(1, 0)
	w.economy.res.money = 50000.0
	w.economy.res.oil = 5000.0
	for n in w.ai.nations: n.money = 50000.0
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position

	# 1: the discoveries, Russia's alone.
	var keys := ["foreignRecruitment", "glideBombs", "fibreOpticDrones"]
	check(keys.all(func(k): return w.research.def_of(k).get("nation", "") == "russia") and preload("res://scripts/national_arsenal.gd").foreign(w, "russia") == "",
		"three Russia-only discoveries from the war in Ukraine, open to Russia")
	# 2: the Geran-2.
	check(w.unit_allowed(0, "shahedLauncher") and w.unit_defs.shahedLauncher.name == "Geran-2 Launcher" and V.admits(w.unit_defs.shahedLauncher.nation, "gold"),
		"Russia builds the Shahed as the %s (Iran still has it)" % w.unit_defs.shahedLauncher.name)

	# 3: foreign recruits: none before the discovery, four at the capital after, at a price.
	var foreign := func(owner: int) -> int: return w.units.filter(func(u): return not u.dead and u.owner == owner and u.get("foreign_recruit", false)).size()
	Caps.update(w, 0.1)
	check(not Caps.has(w, 0, "foreignRecruitment") and not w.get_meta("recruits_due", {}).has(0), "no foreign recruits before the discovery")
	complete("foreignRecruitment")
	Caps.update(w, 0.1)
	var due: Dictionary = w.get_meta("recruits_due", {})
	check(due.has(0) and is_equal_approx(float(due[0]) - w.game_time, Caps.RECRUIT_SECONDS), "at war, the first recruits are due in %d s" % int(Caps.RECRUIT_SECONDS))
	due[0] = w.game_time - 1.0
	w.set_meta("recruits_due", due)
	var money: float = w.economy.res.money
	Caps.update(w, 0.1)
	check(foreign.call(0) == Caps.RECRUITS and is_equal_approx(money - w.economy.res.money, Caps.RECRUIT_COST * Caps.RECRUITS),
		"%d foreign soldiers join at the capital ($%d)" % [foreign.call(0), int(money - w.economy.res.money)])
	var near: bool = w.units.filter(func(u): return not u.dead and u.owner == 0 and u.get("foreign_recruit", false)).all(func(u): return u.node.position.distance_to(home) < 40.0)
	check(near, "they arrive beside the capital")
	w.map.nations[1].id = "russia"
	for n in w.ai.nations:
		if n.id == 1: n.tech = 4.0
	check(Caps.has(w, 1, "foreignRecruitment") and Caps.recruit(w, 1) == Caps.RECRUITS and foreign.call(1) == Caps.RECRUITS, "a rival Russia at era 2 raises them too")
	w.map.nations[1].id = "usa"

	# 4: glide bombs: new jets are Su-34s with half again the range; bombers are not.
	var su35: Dictionary = w.spawn_unit("jet", ground(home + Vector3(30, 0, 30)), 0)
	var bomber0: Dictionary = w.spawn_unit("bomber", ground(home + Vector3(36, 0, 30)), 0)
	var name0: String = V.name_for(w, 0, "jet")
	complete("glideBombs")
	var su34: Dictionary = w.spawn_unit("jet", ground(home + Vector3(42, 0, 30)), 0)
	var bomber1: Dictionary = w.spawn_unit("bomber", ground(home + Vector3(48, 0, 30)), 0)
	check(w.unit_defs.jet.name == "Su-34 (UMPK glide bombs)" and name0 == "Su-35S", "after the research every new jet is a %s (before: %s)" % [w.unit_defs.jet.name, name0])
	check(su34.range / su35.range > 1.4 and w.research.damage_mult(su34) / w.research.damage_mult(su35) > 1.1,
		"its glide bombs reach %d m (the Su-35S %d m) and hit %.2fx as hard" % [int(su34.range), int(su35.range), w.research.damage_mult(su34) / w.research.damage_mult(su35)])
	check(is_equal_approx(bomber1.range, bomber0.range), "heavy bombers are left as they were")

	# 5: fibre-optic drones: a jammer stops radio FPV drones, never fibre-optic ones.
	var radio: Dictionary = w.spawn_unit("fpvTeam", ground(home + Vector3(-30, 0, 30)), 0)
	complete("fibreOpticDrones")
	var fibre: Dictionary = w.spawn_unit("fpvTeam", ground(home + Vector3(-34, 0, 30)), 0)
	check(fibre.get("fibre_optic", false) and not radio.get("fibre_optic", false) and fibre.range / radio.range > 1.25,
		"new FPV teams fly fibre-optic drones, reaching %d m (radio %d m)" % [int(fibre.range), int(radio.range)])
	var target: Dictionary = w.spawn_unit("tank", ground(home + Vector3(-30, 0, 60)), 1)
	w.spawn_unit("ewVehicle", ground(home + Vector3(-28, 0, 64)), 1)
	var jammed := {}
	for shooter in [radio, fibre]:
		var before: int = w.jammed_strikes
		for i in range(40):
			w.economy.res.money = 50000.0
			w.fire_weapon(shooter, target, "fpv")
		jammed[shooter.get("fibre_optic", false)] = w.jammed_strikes - before
	check(jammed[false] > 5 and jammed[true] == 0, "under an enemy jammer %d of 40 radio drones were lost, %d of 40 fibre-optic ones" % [jammed[false], jammed[true]])

	print("\nRUSSIA_CAPABILITIES: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("RUSSIA_CAPABILITIES PASS" if errors.is_empty() else "RUSSIA_CAPABILITIES FAIL")
	quit(0 if errors.is_empty() else 1)
