extends SceneTree
## Fog of war (fog_of_war.gd): the player sees what its side sees; enemy units
## show only where watched, enemy buildings once seen; artillery needs a
## spotter; a CIA network and allies reveal more; what was explored survives a
## save; sandbox matches have no fog.
var errors: Array[String] = []
var passed := 0
var w: Node
const Tactics := preload("res://scripts/tactics.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

func hq(owner: int) -> Dictionary:
	return w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)[0]

func open(style: String) -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": style})
	change_scene_to_file("res://world.tscn")
	w = null
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

func run() -> void:
	await open("standard")
	var fog = w.fog
	check(fog != null and fog.enabled, "a standard match is played under the fog of war")
	var home: Vector3 = hq(0).root.position
	var rival: Dictionary = hq(1)
	fog.refresh()
	check(fog.watches(home) and not fog.watches(rival.root.position) and not fog.charted(rival.root.position), "your capital is watched; a rival's capital, far off, has never been seen")
	check(not rival.root.visible and not fog.shows(rival), "so the rival's capital is not on the map")
	# An enemy unit: hidden far off, shown beside your troops.
	w.diplomacy.declare_war(1, 0)
	var far_tank: Dictionary = w.spawn_unit("tank", ground(home + Vector3(160, 0, 0)), 1)
	var near_tank: Dictionary = w.spawn_unit("tank", ground(home + Vector3(25, 0, 0)), 1)
	fog.refresh()
	check(not far_tank.node.visible and not fog.shows(far_tank), "an enemy tank 160 m out is hidden")
	check(near_tank.node.visible and fog.shows(near_tank), "one 25 m from your capital is seen")
	# Artillery needs a spotter.
	var spot: Vector3 = home + Vector3(-20, 0, 60)
	var gun: Dictionary = w.spawn_unit("artillery", ground(spot), 0)
	var target: Dictionary = w.spawn_unit("tank", ground(spot + Vector3(0, 0, 55)), 1)
	fog.refresh()
	w.rebuild_grid()   # (the spatial grid the targeting searches; the physics step is off)
	var blind = Tactics.pick_target(w, gun, maxf(gun.aggro, gun.range))
	check(blind == null or not is_same(blind, target), "your artillery does not fire on a tank 55 m off that no one sees (sight %d m, range %d m)" % [int(fog.sight_of(gun)), int(gun.range)])
	var scout: Dictionary = w.spawn_unit("soldier", ground(spot + Vector3(0, 0, 40)), 0)
	scout.target = scout.node.position
	fog.refresh()
	w.rebuild_grid()
	var spotted = Tactics.pick_target(w, gun, maxf(gun.aggro, gun.range))
	check(spotted != null and is_same(spotted, target), "with a soldier spotting it, the artillery fires")
	for u in [scout, target, gun, far_tank, near_tank]: w.kill(u)
	# A building once seen stays on the map where it was seen.
	var outpost: Dictionary = w.place_building("barracks", w.test_site("barracks", rival.root.position + Vector3(-30, 0, 0)), 1, true)
	fog.refresh()
	check(not outpost.root.visible, "a rival barracks never seen is not on the map")
	var raider: Dictionary = w.spawn_unit("commando", ground(outpost.root.position + Vector3(15, 0, 0)), 0)
	fog.refresh()
	check(outpost.get("seen", false) and outpost.root.visible, "a commando beside it sees it")
	w.kill(raider)
	fog.refresh()
	check(outpost.root.visible and not fog.watches(outpost.root.position) and fog.charted(outpost.root.position), "when the commando is gone it stays on the map, its land grey (seen, not watched)")
	# A CIA network reveals a nation's buildings.
	var third: Dictionary = hq(2)
	check(not third.root.visible, "a third nation's capital is unseen")
	w.espionage.intel[2] = 12.0
	fog.refresh()
	check(third.root.visible and third.get("seen", false), "intelligence of 10 in that nation puts its buildings on the map")
	# Allies share what they see.
	if w.diplomacy.at_war(0, 3): w.diplomacy.make_peace(0, 3)
	w.diplomacy.set_flag(w.diplomacy.alliance, 0, 3, true)
	var ally_capital: Vector3 = hq(3).root.position
	var intruder: Dictionary = w.spawn_unit("tank", ground(ally_capital + Vector3(20, 0, 0)), 1)
	fog.refresh()
	check(fog.watches(ally_capital) and intruder.node.visible, "an ally's capital and the enemy beside it are seen (shared sight)")
	# Explored land and seen buildings survive a save.
	var saved: Dictionary = fog.capture()
	var explored_before: int = fog.explored.count(1)
	fog.explored.fill(0)
	outpost.seen = false
	fog.restore(JSON.parse_string(JSON.stringify(saved)))
	check(fog.explored.count(1) == explored_before and outpost.get("seen", false), "explored land (%d cells) and remembered buildings survive a save" % explored_before)
	# Cost.
	var t0 := Time.get_ticks_usec()
	for i in range(20): fog.refresh()
	var ms: float = (Time.get_ticks_usec() - t0) / 20000.0
	check(ms < 6.0, "a fog refresh takes %.2f ms (four a second; budget 6)" % ms)
	# Sandbox: no fog.
	await open("sandbox")
	check(w.fog != null and not w.fog.enabled and w.fog.shows(hq(1)), "a sandbox match has no fog")
	print("\nFOG_OF_WAR: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("FOG_OF_WAR PASS" if errors.is_empty() else "FOG_OF_WAR FAIL")
	quit(0 if errors.is_empty() else 1)
