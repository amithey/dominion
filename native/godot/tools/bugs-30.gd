extends SceneTree
## Thirty checks hunting for bugs at the edges of the rules: things done twice,
## to the dead, out of bounds, without the money, with nonsense input; a huge
## time step; old and odd saves.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Setup := preload("res://scripts/match_setup.gd")
const Powers := preload("res://scripts/faction_powers.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func sim(seconds: float, step := DT) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(step)
		w.effects._physics_process(step)
		w.missiles._physics_process(step)
		t += step

func hq(owner: int):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			return b
	return null

func finite(v: Vector3) -> bool:
	return not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.x) or is_inf(v.z))

func dry_site(key: String) -> Vector3:
	for r in range(30, 160, 6):
		for i in range(16):
			var p: Vector3 = w.snap_to_hex(w.start + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * r)
			if w.site_problem(key, p, 0) == "":
				return p
	return Vector3.INF

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260930)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(10): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.set_process(false)
	w.economy.grant_test_resources()
	var half: float = float(w.map.mapSize) * 0.5

	# 1-2: a building destroyed twice.
	var at := dry_site("barracks")
	var barracks: Dictionary = w.place_building("barracks", at, 0, true)
	w.destroy_building(barracks)
	var squashed: float = barracks.model.scale.y
	w.destroy_building(barracks)
	check(is_equal_approx(barracks.model.scale.y, squashed), "a building destroyed twice is not crushed twice (%.3f vs %.3f)" % [barracks.model.scale.y, squashed])
	# 3: nothing is trained in a ruin.
	var money0: float = w.economy.res.money
	w.queue_unit(barracks, "soldier")
	check(barracks.queue.is_empty() and absf(w.economy.res.money - money0) < 0.01, "a destroyed barracks takes no orders, nor money (%d queued)" % barracks.queue.size())
	# 4: nor a missile in a ruined silo.
	var silo: Dictionary = w.place_building("missileSilo", dry_site("missileSilo"), 0, true)
	w.destroy_building(silo)
	money0 = w.economy.res.money
	var why: String = w.missiles.produce(silo, "tactical")
	check(silo.queue.is_empty() and absf(w.economy.res.money - money0) < 0.01, "a destroyed silo builds no missiles (%d queued)" % silo.queue.size())

	# 5-6: a unit killed twice; orders to the dead.
	var tank: Dictionary = w.spawn_unit("tank", w.land_point(w.start, 40.0), 0)
	w.kill(tank)
	var toss = tank.get("toss")
	w.kill(tank)
	check(tank.dead and is_same(tank.get("toss"), toss), "a unit killed twice dies once (no second turret toss)")
	w.order_move([tank], w.start + Vector3(30, 0, 30))
	check(tank.target == null, "the dead take no orders")

	# 7-8: out of bounds.
	var runner: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 30.0), 0)
	w.order_move([runner], Vector3(half * 3.0, 0, half * 3.0))
	sim(20.0)
	var p: Vector3 = runner.node.position
	check(absf(p.x) <= half and absf(p.z) <= half and finite(p), "an order off the edge of the map keeps the unit on it (%s)" % str(p.snapped(Vector3.ONE)))
	check(w.site_problem("farm", Vector3(half + 40.0, 0, 0), 0) != "" and w.site_problem("farm", Vector3(half * 0.98, 0, half * 0.98), 0) != "", "no building off the map or at sea")
	# 9: nor on another.
	var hq_at: Vector3 = hq(0).root.position
	check(w.site_problem("farm", hq_at, 0) != "", "no building on top of the capital")

	# 10-11: without the money.
	var saved_res: Dictionary = w.economy.res.duplicate()
	for k in w.economy.res: w.economy.res[k] = 0.0
	var site := dry_site("farm")
	var n_buildings: int = w.buildings.size()
	var placed: bool = w.build_site("farm", site)
	check(not placed and w.buildings.size() == n_buildings, "no money, no building site")
	var lab_note: String = w.research.enqueue("no_such_project")
	check(lab_note != "" and not "no_such_project" in w.research.queue, "an unknown research project is refused (%s)" % lab_note)
	w.economy.res = saved_res

	# 12-15: the market's edges.
	w.place_building("market", dry_site("market"), 0, true)
	w.economy.recalculate()
	w.economy.res.iron = 5.0
	var sold: String = w.market.sell("iron", 50)
	check(w.economy.res.iron == 5.0 and sold.begins_with("Not enough"), "selling more than you have is refused (%s)" % sold)
	check(w.market.sell("iron", 0).begins_with("Choose") and w.market.sell("iron", -5).begins_with("Choose") and w.economy.res.iron == 5.0, "selling nothing or less than nothing is refused")
	var cash: float = w.economy.res.money
	w.economy.res.money = 3.0
	var bought: String = w.market.buy("iron", 40)
	check(w.economy.res.money == 3.0 and w.economy.res.iron == 5.0, "buying without the money is refused (%s)" % bought)
	w.economy.res.money = 10000000.0
	w.market.buy("iron", 100000000)
	check(w.economy.res.iron <= w.market.cap_of("iron") + 0.01, "no purchase overflows the warehouses (%d of %d)" % [int(w.economy.res.iron), int(w.market.cap_of("iron"))])
	w.economy.res.money = cash

	# 16: a queue order cancelled twice refunds once.
	var yard: Dictionary = w.place_building("barracks", dry_site("barracks"), 0, true)
	w.economy.grant_test_resources()
	w.queue_unit(yard, "soldier")
	money0 = w.economy.res.money
	w.cancel_queued(yard, 0)
	var after_one: float = w.economy.res.money
	w.cancel_queued(yard, 0)
	w.cancel_queued(yard, 7)
	w.cancel_queued(yard, -1)
	check(after_one > money0 and w.economy.res.money == after_one, "a cancelled order is refunded once ($%d)" % int(after_one - money0))

	# 17-18: recalculating is idempotent.
	w.research._recompute()
	var bonus1: float = w.research.bonus("incomePct")
	w.research._recompute()
	w.research._recompute()
	check(is_equal_approx(bonus1, w.research.bonus("incomePct")), "recomputing research twice changes nothing (%.3f)" % bonus1)
	w.economy.recalculate()
	var caps1: Dictionary = w.economy.caps.duplicate()
	w.economy.recalculate()
	check(caps1 == w.economy.caps, "recalculating the economy twice changes nothing")

	# 19: an empty country.
	var people: float = w.economy.civilians
	w.economy.civilians = 0.0
	for i in range(5): w.economy.tick()
	check(w.economy.res.values().all(func(v): return not is_nan(v) and v >= 0.0) and not is_nan(w.economy.civilians) and w.economy.civilians >= 0.0, "a country with no people runs without breaking")
	w.economy.civilians = people

	# 20: a huge time step.
	var column: Array = []
	for i in range(6): column.append(w.spawn_unit(["tank", "soldier", "apc"][i % 3], w.land_point(w.start, 45.0), 0))
	w.order_move(column, w.start + Vector3(-60, 0, 40))
	sim(8.0, 1.0)
	check(column.all(func(u): return finite(u.node.position) and absf(u.node.position.x) <= half and absf(u.node.position.z) <= half), "a one-second time step leaves no unit lost or broken")

	# 21-22: territory and minimap at and past the edge.
	# Far off the map, the nearest edge hex answers (never a bad index).
	var cells: int = w.territory.owner_of.size()
	var far_cells: Array = [Vector3(half * 4.0, 0, -half * 4.0), Vector3(-half * 9.0, 0, half * 2.0), Vector3(0, 0, 1e6)].map(func(v): return w.territory.cell_of(v))
	check(far_cells.all(func(i): return i >= 0 and i < cells), "land far off the map resolves to a real edge hex (%s)" % str(far_cells))
	var mm: Control = null
	for c in w.hud.find_children("*", "Control", true, false):
		if c.get_script() == preload("res://scripts/minimap.gd"):
			mm = c
	var cam_yaw: float = w.cam_yaw
	w.cam_yaw = 0.7
	var spot := Vector3(123.0, 0, -87.0)
	var back: Vector3 = mm.to_world(mm.view_transform() * mm.to_map(spot)) if mm != null else Vector3.INF
	w.cam_yaw = cam_yaw
	check(mm != null and Vector2(back.x - spot.x, back.z - spot.z).length() < 1.0, "a point on the minimap leads back to the same place (%s)" % str(back.snapped(Vector3.ONE)))

	# 23-25: diplomacy and spies with the wrong nation.
	var d: Node = w.diplomacy
	d.declare_war(0, 0)
	check(not d.at_war(0, 0), "no nation goes to war with itself")
	check(w.espionage.blocked_reason("openSources", 0) != "" and w.espionage.blocked_reason("openSources", 99) != "", "no spying on yourself, nor on a nation that does not exist")
	var gone: int = 3
	w.destroy_building(hq(gone))
	w.ai._physics_process(0.1)
	d.set_score(0, gone, 90.0)
	var pact: String = d.propose_pact(gone)
	d.propose_nap(gone)
	d.propose_alliance(gone)
	check(d.defeated(gone) and not d.pact[0][gone] and not d.nap[0][gone] and not d.alliance[0][gone], "no treaty with a nation that has fallen, however warm (%s)" % pact)

	# 26: missiles with nothing to launch from.
	for u in w.missiles.launch_ships(0): w.kill(u)   # the starting destroyer and strategic submarine
	w.missiles.stock["tactical"] = 1
	var launched: String = w.missiles.launch("tactical", hq(1).root.position)
	check(launched != "" and int(w.missiles.stock.tactical) == 1, "no launch without a silo or a launch ship (%s)" % launched)

	# 27: a national power twice in a row.
	var power: Dictionary = Powers.power_of(w, 0)
	var first := ""
	var second := "no power"
	if not power.is_empty():
		first = Powers.use(w, 0, 1 if power.target else -1)
		second = Powers.blocked(w, 0, 1 if power.target else -1)
	check(second != "", "a national power waits for its cooldown (%s)" % second)

	# 28-29: saves: a missile in flight, and an old save from before each rival had a level.
	var flying: Dictionary = w.missiles.fly("cruise", w.start + Vector3.UP * 3.0, hq(1).root.position, 0)
	w.missiles._physics_process(0.5)
	var data: Dictionary = w.saves.capture()
	var json: String = JSON.stringify(data)
	var copy = JSON.parse_string(json)
	check(copy is Dictionary and str(copy.get("format", "")) == "dominion-save", "a save taken with a missile in the air is valid JSON")
	for n in copy.ai: n.erase("level")
	copy.match_config.erase("levels")
	copy.difficulty = "hard"
	w.saves.restore(copy)
	for i in range(5): await process_frame
	var old_ok: bool = w.ai.nations.all(func(n): return w.ai.row(n) == w.map.ai.difficulty.get(str(n.get("level", "")), w.ai.cfg))
	check(old_ok, "an old save without rival levels still loads (every rival at the match's difficulty)")

	# 30: nonsense options.
	var odd: Dictionary = Setup.normalize({"map": 7, "players": "abc", "nation": null, "rivals": "x", "levels": 5, "style": []})
	check(odd.map == "island" and int(odd.players) >= 2 and int(odd.nation) == 0 and odd.style == "standard" and not odd.has("rivals") and not odd.has("levels"), "nonsense match options fall back to sound ones (%s)" % str(odd))
	var roster: Array = Setup.roster(Setup.normalize({"map": "crown", "players": 8, "nation": 8, "rivals": [8, 8, 3, 3, -1, 42]}))
	var unique := {}
	for i in roster: unique[i] = true
	check(roster.size() == 8 and unique.size() == 8 and roster[0] == 8 and roster[1] == 3, "repeated or impossible rivals are ignored (%s)" % str(roster))

	print("\nBUGS_30: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("BUGS_30 PASS" if errors.is_empty() else "BUGS_30 FAIL")
	quit(0 if errors.is_empty() else 1)
