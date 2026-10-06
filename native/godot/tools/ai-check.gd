extends SceneTree
## Artificial intelligence (ai_directorate.gd, ai_data.gd, ai_panel.gd):
## compute and data centres, training runs and AI levels, the compute split,
## the autonomy doctrine and its incidents, autonomous seekers, the Targeting
## Fusion Cell, AI cyber campaigns both ways, rivals' AI and saving.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func finish(key: String) -> void:
	w.research.progress[key].stage = 3
	w.research._recompute()

func seconds(a, n: int) -> void:
	for i in range(n):
		a.update(1.0)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
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
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["directorate", "un", "support"])
	seed(11)
	var a = w.directorate
	var d: Node = w.diplomacy
	var AIData := preload("res://scripts/ai_data.gd")
	var hq0: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position

	# ---- data
	check(w.map.research.discoveries.has("machineLearning") and w.map.research.discoveries.has("militaryAI") and w.map.research.discoveries.has("frontierModels"), "the AI research chain is in the tree")
	check(w.building_defs.has("aiDataCenter") and w.building_defs.has("fusionCell"), "the AI Data Center and the Targeting Fusion Cell exist")
	check(AIData.rating(w, 0, "compute") == 5 and AIData.profile(w, 0).lean == "on", "the United States leads in compute and keeps a human on the loop")
	w.map.nations[2]["ai_profile"] = {"cyber": 4}
	check(AIData.rating(w, 2, "cyber") == 4, "a map entry's ai_profile overrides the table (nations added later)")
	w.map.nations[2].erase("ai_profile")
	var dated := RegEx.create_from_string("\\b(1[89]|20)\\d\\d\\b")
	var texts: Array = [a.DOCTRINE_DESC.values(), w.building_defs.aiDataCenter.desc, w.building_defs.fusionCell.desc]
	for k in a.DISCOVERIES: texts.append(a.DISCOVERIES[k].desc)
	check(dated.search(str(texts)) == null, "no years in the AI texts")

	# ---- compute
	check(a.compute_rate(0) == 0.0 and a.cap(0) == 0, "no compute and no AI before Machine Learning")
	check(a.doctrine_blocked("on") != "" and a.cyber_blocked(1) != "", "no doctrine and no cyber campaign before the research")
	finish("machineLearning")
	a._refresh(0)
	check(is_equal_approx(a.compute_rate(0), 0.5) and a.cap(0) == 2, "Machine Learning: national compute 0.5/s, AI level up to 2")
	var power_plant: bool = a._has(0, "powerPlant") or a._has(0, "nuclearReactor")
	w.economy.res.silicon = 5000.0
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq0 + Vector3(-50, 0, 40)), 0, true)
	check(is_equal_approx(a.compute_rate(0), 0.5 + (1.25 if power_plant else 1.0)), "an AI Data Center adds its compute")
	w.economy.res.silicon = 50.0
	var up: Dictionary = a.upkeep()
	check(is_equal_approx(float(up.silicon), 0.12) and is_equal_approx(float(up.money), 1.5), "a data centre burns silicon and money")
	var si0: float = w.economy.res.silicon
	w.economy.tick()
	check(w.economy.rates.silicon <= -0.12 + 0.0001 + maxf(0.0, si0) * 0.0 and w.economy.res.silicon < si0 + 50.0, "the economy charges the data centre's chips")
	w.economy.res.silicon = 0.0
	check(a.compute_rate(0) < 0.5 + 0.5, "without silicon a data centre runs at a quarter")
	w.economy.res.silicon = 5000.0

	# ---- training and the split
	for p in a.POOLS: a.alloc[p] = 0.0
	a.alloc.frontier = 100.0
	seconds(a, 400)
	check(a.level(0) == 2, "training runs raise the AI level to the research cap (2)")
	seconds(a, 200)
	check(a.level(0) == 2, "and no further without Military AI")
	check(a.reserve(0) == 0.0, "no compute to intelligence: the operations reserve stays empty")
	a.alloc.intel = 100.0
	a.alloc.frontier = 0.0
	seconds(a, 30)
	check(a.reserve(0) > 30.0, "intelligence compute fills the operations reserve")
	a.alloc.intel = 0.0
	a.alloc.economy = 100.0
	var research0: float = w.research.bonus("researchPct")
	seconds(a, 2)
	w.research._recompute()
	check(w.research.bonus("researchPct") > research0 + 0.01, "economy compute raises research")

	# ---- the doctrine
	check(a.set_doctrine("on").contains("on the loop") and a.doctrine(0) == "on", "the human-on-the-loop doctrine after Machine Learning")
	check(a.set_doctrine("out").contains("Military AI") and a.doctrine(0) == "on", "out of the loop needs Military AI")
	finish("militaryAI")
	a.alloc.economy = 0.0
	a.alloc.frontier = 100.0
	seconds(a, 700)
	check(a.level(0) == 3 and a.cap(0) == 3, "Military AI: the level reaches 3")
	a.alloc.frontier = 0.0
	a.alloc.military = 100.0
	seconds(a, 1)
	check(a.military(0) > 0.99, "full military compute")
	var drone_src := {"owner": 0, "key": "drone"}
	check(a.damage_mult(drone_src) > 1.1, "on the loop: drones strike harder")
	check(a.jam_factor(0) < 0.75 and a.jam_factor(0) > 0.6, "on the loop: drones a third harder to jam")
	a.set_doctrine("out")
	check(a.jam_factor(0) < 0.2, "out of the loop: drones almost impossible to jam")
	check(a.damage_mult({"owner": 0, "key": "soldier"}) > 1.05, "out of the loop: every unit a little deadlier")
	check(a.incident_rate(0) > 0.05, "out of the loop: incidents are likely at war")

	# ---- autonomous seekers (world.nearest_enemy)
	var foe := 1
	d.declare_war(0, foe, "test")
	var spot: Vector3 = w.test_site("aiDataCenter", hq0 + Vector3(80, 0, -80))
	var seeker: Dictionary = w.spawn_unit("loiterer", spot, 0)
	var tank: Dictionary = w.spawn_unit("tank", spot + Vector3(18, 0, 0), foe)
	var aa: Dictionary = w.spawn_unit("aaVehicle", spot + Vector3(-34, 0, 0), foe)
	w.rebuild_grid()
	check(a.seeks(seeker), "at level 3 a loitering munition seeks its own target")
	check(w.nearest_enemy(seeker, 60.0) == aa, "it chooses the air-defence vehicle over the nearer tank")
	a.set_doctrine("in")
	check(not a.seeks(seeker) and w.nearest_enemy(seeker, 60.0) == tank, "with a human in the loop it takes the nearest")
	check(is_equal_approx(w.jam_factor(seeker), w.space.jam_factor(0) if w.space != null else 1.0), "in the loop: no jamming protection")
	a.set_doctrine("on")
	check(w.jam_factor(seeker) < (w.space.jam_factor(0) if w.space != null else 1.0), "the world's jamming roll asks the doctrine")
	# Damage through world.damage.
	a.set_doctrine("in")
	tank.hp = 10000.0
	w.damage(tank, 100.0, {"owner": 0, "key": "drone", "dead": true})
	var loss_in: float = 10000.0 - tank.hp
	a.set_doctrine("on")
	tank.hp = 10000.0
	w.damage(tank, 100.0, {"owner": 0, "key": "drone", "dead": true})
	check(10000.0 - tank.hp > loss_in * 1.1, "world.damage applies the AI bonus")

	# ---- the Targeting Fusion Cell
	var arty := {"owner": 0, "key": "artillery"}
	var before: float = a.damage_mult(arty)
	w.place_building("fusionCell", w.test_site("fusionCell", hq0 + Vector3(50, 0, 50)), 0, true)
	seconds(a, 1)
	check(a.fusion(0) and a.damage_mult(arty) > before + 0.1, "the fusion cell makes artillery deadlier")
	var gun: Dictionary = w.spawn_unit("artillery", spot + Vector3(0, 0, 20), 0)
	check(a.aim(0) > 0.1 and w.guidance(gun) > (w.space.nav_factor(0) if w.space != null else 1.0), "and its aim and guidance better")

	# ---- incidents
	a.set_doctrine("out")
	var own: Dictionary = w.spawn_unit("tank", spot + Vector3(0, 0, -20), 0)
	var hp0: float = own.hp
	w.units = w.units.filter(func(u): return u.owner != 0 or u == own or u.key == "worker" or u.get("fly", false))
	check(a.fratricide(0) and own.hp < hp0, "an autonomous weapon can strike your own unit")
	var homes: Array = w.buildings.filter(func(b): return b.owner == foe and b.built and not b.dead and b.key in a.CIVILIAN)
	if homes.is_empty():
		w.place_building("cottage", w.test_site("cottage", w.buildings.filter(func(b): return b.owner == foe and b.key == "hq")[0].root.position + Vector3(30, 0, 30)), foe, true)
	var support0: float = w.support.value(0) if w.support != null else 0.0
	var rel0: float = d.rel(0, foe)
	var q0: int = w.un.queue.size() if w.un != null else 0
	check(a.civilian_strike(0, foe), "or strike civilians")
	print("    relations %.1f -> %.1f, support %.1f -> %.1f, council %d -> %d" % [rel0, d.rel(0, foe), support0, w.support.value(0) if w.support != null else 0.0, q0, w.un.queue.size() if w.un != null else 0])
	check(d.rel(0, foe) <= rel0 and (w.support == null or w.support.value(0) < support0) and (w.un == null or w.un.queue.size() > q0), "civilians struck: relations, war support and the Security Council")
	check(int(a.incidents.get(0, 0)) == 2, "incidents are counted")

	# ---- AI cyber campaigns
	finish("cyberWarfare")
	a.st[0].reserve = 600.0
	check(a.cyber_blocked(foe) == "", "a cyber campaign is ready")
	var reach: int = a.cyber_reach(0)
	var said: String = a.launch_cyber(foe)
	check(said.contains("AI CYBER") and not a.campaign.is_empty() and a.reserve(0) <= 600.0 - a.CYBER_COST, "it spends compute, not an agent")
	check(a.campaign.targets.size() <= reach and foe in a.campaign.targets, "it reaches up to %d nations" % reach)
	var hits := 0
	for attempt in range(6):
		if attempt > 0:
			a.cyber_ready = 0.0
			a.st[0].reserve = 600.0
			a.launch_cyber(foe)
		a.campaign.ends = w.game_time
		a.update(1.0)
		if w.espionage.production_down(foe):
			hits += 1
			break
	check(hits > 0 and a.campaign.is_empty(), "a campaign shuts the target's production down")
	check(a.cyber_blocked(foe).contains("reset"), "the operators need time before the next")
	# A rival's campaign against you.
	var site = w.buildings.filter(func(b): return b.owner == 0 and b.built and not b.dead and b.key in a.PRODUCTION)
	if site.is_empty():
		w.place_building("barracks", w.test_site("barracks", hq0 + Vector3(-40, 0, -40)), 0, true)
	check(a.rival_intrusion(foe, "hit").contains("shut down") and w.buildings.any(func(b): return b.owner == 0 and w.disabled(b)), "a rival's AI intrusion shuts one of your factories down")
	check(a.rival_intrusion(foe, "stopped").contains("stopped"), "or your cyber defence stops it")

	# ---- rivals
	var n1: Dictionary = w.ai.nations.filter(func(n): return n.id == foe)[0]
	n1.tech = 5.0
	var hq1: Vector3 = w.buildings.filter(func(b): return b.owner == foe and b.key == "hq")[0].root.position
	w.place_building("aiDataCenter", w.test_site("aiDataCenter", hq1 + Vector3(-45, 0, 45)), foe, true)
	seconds(a, 2)
	check(a.compute_rate(foe) > 1.0 and a.cap(foe) == 3, "a rival with technology 5 and a data centre has compute and may reach level 3")
	a.st[foe].level = 2
	a.st[foe].train = a.next_cost(foe) - 0.01
	seconds(a, 2)
	check(a.level(foe) == 3, "its training runs raise its level")
	seconds(a, 3000)
	check(a.level(foe) == 3, "but not past what its technology allows")
	a._rival_doctrines()
	var lean: String = AIData.profile(w, foe).lean
	check(a.doctrine(foe) == (lean if lean != "in" else "in"), "at war it fights by its national lean (%s)" % lean)
	n1.tech = 6.0
	var built := []
	for i in range(8):
		var k: String = w.ai.pick_building(n1)
		built.append(k)
		if k in ["missileSilo", "strategicComplex", "specialLab", "aiDataCenter", "fusionCell"]:
			w.place_building(k, w.test_site(k, hq1 + Vector3(60 - i * 20, 0, -60)), foe, true)
		if k == "fusionCell":
			break
	check("fusionCell" in built, "rivals build their data centres and a fusion cell (%s)" % ", ".join(PackedStringArray(built)))

	# ---- saving
	a.alloc.economy = 40.0
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	a.st[0].level = 0
	a.alloc.economy = 0.0
	w.saves.restore(snap)
	var b = w.directorate
	check(b.level(0) == 3 and b.doctrine(0) == "out" and is_equal_approx(float(b.alloc.economy), 40.0) and b.level(foe) == 3, "a save keeps the levels, the split and the doctrine")

	# ---- the AI tab draws
	w.hud.toggle_panel("defence", true)
	w.hud._panels.defence_tab = "ai"
	w.hud.refresh_side()
	var labels: Array = w.hud._side_rows.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(labels.any(func(t): return t.begins_with("AI level 3")) and labels.any(func(t): return t.contains("Compute allocation")), "the AI tab shows the level, the split and the doctrine")
	var buttons: Array = w.hud._side_rows.find_children("*", "Button", true, false).map(func(x): return x.text)
	check(buttons.has("on the loop") and buttons.any(func(t): return t.begins_with("Launch")), "with the doctrine and the campaign buttons")

	print("AI_CHECK %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("AI_CHECK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
