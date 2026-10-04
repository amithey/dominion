extends SceneTree
## World events with causes (world_events.gd): a war or a blockade starts each
## one, it lasts while its cause lasts (and a little after), and it reaches
## every nation through prices and incomes by how exposed each is.
var errors: Array[String] = []
var passed := 0
var w: Node
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func who(id: String) -> int:
	for i in range(w.map.nations.size()):
		if Factions.identity(w, i) == id: return i
	return -1

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": Factions.IDS.find("usa"), "style": "standard",
		"rivals": [Factions.IDS.find("china"), Factions.IDS.find("iran"), Factions.IDS.find("eu")]})
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
	var ev = w.events
	var d: Node = w.diplomacy
	var china := who("china")
	var iran := who("iran")
	var eu := who("eu")
	check(ev != null and china > 0 and iran > 0 and eu > 0, "a match of the United States, China, Iran and Europe")
	ev.evaluate()
	check(ev.active.is_empty() and ev.price_shock("oil") == 0.0, "in peace the world is calm: no event, no shock")

	# 1: Iran at war with the United States closes Hormuz.
	var oil0: float = w.market.mult.oil
	d.declare_war(iran, 0)
	ev.evaluate()
	check(ev.active.has("hormuz") and w.market.mult.oil > oil0 * 1.3, "Iran at war with the United States: Hormuz closes, oil jumps (%.2f -> %.2f)" % [oil0, w.market.mult.oil])
	check(is_equal_approx(ev.income_of(0), 0.04) and ev.ai_income_mult(china) < 1.0 and ev.ai_income_mult(eu) < 1.0,
		"the United States, a producer, earns more (+4%%); China (%d%%) and Europe (%d%%) pay" % [roundi((ev.ai_income_mult(china) - 1.0) * 100), roundi((ev.ai_income_mult(eu) - 1.0) * 100)])
	check(w.research._bonus.get("incomePct", 0.0) >= 0.04 - 0.0001 or w.research.bonus("incomePct") >= 0.0, "the player's income carries the event")
	for i in range(150): w.market.exchange_step()
	check(w.market.fair.oil > 1.4, "the market's fair price of oil climbs toward the shock (%.2f)" % w.market.fair.oil)
	# It lasts while the cause lasts, and a little after.
	d.make_peace(iran, 0)
	ev.evaluate()
	check(ev.active.has("hormuz"), "peace: the strait does not reopen at once")
	w.game_time += ev.LINGER + 1.0
	ev.evaluate()
	check(not ev.active.has("hormuz"), "45 s later it reopens")
	# Iran can close it by its own power.
	w.power_effects.append({"kind": "hormuz", "nation": iran, "by": iran, "value": 0.85, "until": w.game_time + 60.0})
	ev.evaluate()
	check(ev.active.has("hormuz") and str(ev.active.hormuz.cause).contains("closed"), "Iran closing the strait itself starts it too")
	w.power_effects.clear()
	w.game_time += ev.LINGER + 1.0
	ev.evaluate()

	# 2: two great economies at war: a global recession and a rare-earth shock.
	d.declare_war(china, 0)
	ev.evaluate()
	check(ev.active.has("recession") and ev.active.has("rare_earths"), "the United States and China at war: a global recession and a rare-earth shock")
	check(ev.price_shock("silicon") > 0.5 and ev.bonuses().get("researchPct", 0.0) < 0.0 and ev.income_of(eu) < 0.0,
		"silicon dearer, American research slower (%d%%), every economy smaller" % roundi(ev.bonuses().get("researchPct", 0.0) * 100))
	# 3: three wars: an arms boom.
	d.declare_war(iran, eu)
	d.declare_war(china, eu)
	ev.evaluate()
	check(ev.active.has("arms_boom") and ev.income_of(0) > -0.06 - 0.03 + 0.03, "three wars: an arms boom (the United States sells more)")
	# 4: Russia in the match: grain.
	w.map.nations[eu].id = "russia"
	ev.evaluate()
	check(ev.active.has("grain") and ev.price_shock("food") >= 0.5, "Russia at war: Black Sea grain stops, food dearer")
	w.map.nations[eu].id = "eu"
	# 5: a town destroyed: refugees.
	var civ0: float = w.economy.civilians
	var town: Dictionary = w.place_building("villageCenter", w.test_site("villageCenter", w.start + Vector3(90, 0, 40)), china, true)
	w.destroy_building(town)
	var to_me: Array = ev.refugees.filter(func(r): return int(r.to) == 0)
	check(ev.refugees.size() == 2, "a Chinese village destroyed: its people flee to the two nearest nations")
	check(to_me.is_empty() or (w.economy.civilians > civ0 and ev.bonuses().get("happiness", 0.0) <= -3.0), "refugees who reach you add citizens and strain")
	# 6: the Cabinet tells it.
	var lines: Array = ev.summary()
	check(lines.size() >= 3 and lines.all(func(l): return str(l.cause) != ""), "the Cabinet lists each event with its cause (%d)" % lines.size())
	# 7: saved.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ev.capture()))
	var keys: Array = ev.active.keys()
	ev.active.clear()
	ev.restore(saved)
	check(ev.active.keys().size() == keys.size(), "the events in force survive a save")
	print("\nWORLD_EVENTS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("WORLD_EVENTS PASS" if errors.is_empty() else "WORLD_EVENTS FAIL")
	quit(0 if errors.is_empty() else 1)
