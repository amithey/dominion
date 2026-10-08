extends SceneTree
## Exercise the actual end-screen button and the process callbacks it unlocks.
var w: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func advance_systems() -> void:
	w.research._process(1.0)
	w.territory._process(w.territory.TICK)
	w.market._process(0.1)
	w.diplomacy.contacts._process(1.0)
	w.espionage._process(1.0)
	w.passage._process(0.1)

func free_site(key: String, near := Vector3.INF) -> Variant:
	for i in range(w.territory.owner_of.size()):
		var at: Vector3 = w.territory.center(i)
		if near != Vector3.INF and at.distance_to(near) > 65.0: continue
		if w.site_problem(key, at, 0) == "": return at
	return null

func fourth_city() -> void:
	var city: Dictionary = {}
	for i in range(4):
		var at = free_site("cityCenter")
		check(at != null, "city %d has a legal site after victory" % (i + 1))
		if at == null: return
		city = w.place_building("cityCenter", at, 0, true)
	w.territory._process(w.territory.TICK)
	check(w.territory.owner_at(city.root.position) == 0, "fourth city claims its territory after victory")
	var at = free_site("farm", city.root.position)
	check(at != null, "fourth city has legal room for a farm")
	if at == null: return
	check(w.build_site("farm", at), "farm construction starts in the fourth city's territory")
	var farm: Dictionary = w.buildings[-1]
	var worker: Dictionary = w.units.filter(func(u): return u.owner == 0 and u.key == "worker" and not u.dead)[0]
	w.place_on_ground(worker, farm.root.position + Vector3(1, 0, 1))
	worker.target = null
	worker.build_site = farm
	w.update_construction(float(farm.def.buildTime) + 1.0)
	check(farm.built, "worker completes a farm after victory")

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.menu._root.hide()
	w.saves.autosave_every = 0
	paused = true
	w.economy.grant_test_resources()
	var original: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	for result in ["victory", "defeat"]:
		w.game_over = result
		w.continuing_after_end = false
		w.hud.show_end(result.to_upper(), "Regression test")
		var points: float = w.research.points
		var ticks: int = w.territory._ticks
		var talks: float = w.diplomacy.contacts.clock
		advance_systems()
		check(w.research.points == points and w.territory._ticks == ticks and w.diplomacy.contacts.clock == talks, result + ": end state blocks updates before continuing")
		var buttons: Array = w.hud.find_children("*", "Button", true, false).filter(func(b): return b.text == "Continue playing" and not b.is_queued_for_deletion() and not b.get_parent().get_parent().get_parent().is_queued_for_deletion())
		check(buttons.size() == 1, result + ": one continuation button")
		if buttons.is_empty(): break
		w.set_speed(0.0)
		buttons[-1].pressed.emit()
		check(w.game_over == result and w.continuing_after_end and not w.match_stopped() and not paused and w.game_speed > 0.0, result + ": button resumes simulation and preserves result")
		paused = true
		var exchange: float = w.market._step
		var intel: float = w.espionage.clock
		var passage: float = w.passage._tick
		advance_systems()
		check(w.research.points > points, result + ": research earns points")
		check(w.territory._ticks > ticks, result + ": settlement territory updates")
		check(w.diplomacy.contacts.clock > talks, result + ": diplomatic talks advance")
		check(w.market._step != exchange and w.espionage.clock > intel and w.passage._tick != passage, result + ": market, espionage and passage resume")
		if result == "victory": fourth_city()
		w.check_game_over()
		w.victory._win(0, "technology")
		w.victory._win(1, "dominance")
		check(w.game_over == result, result + ": subsequent victory checks preserve the first result")
		var saved: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		w.saves.restore(saved)
		check(w.game_over == result and w.continuing_after_end and not w.match_stopped(), result + ": continuation survives save/load")
		saved.erase("continuing_after_end")
		w.saves.restore(saved)
		check(not w.match_stopped(), result + ": old finished saves resume")
		w.saves.restore(original)
		check(w.game_over == "" and not w.continuing_after_end, "unfinished save clears continuation state")
		await process_frame
	print("POST_VICTORY: %d checks, %d failures" % [checks, failures.size()])
	print("POST_VICTORY PASS" if failures.is_empty() else "POST_VICTORY FAIL")
	quit(0 if failures.is_empty() else 1)
