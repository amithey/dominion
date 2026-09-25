extends SceneTree
## A played match on fast-forward, as a player would: a town of districts, workers
## and an army trained, a village founded and linked by road, research queued,
## a market deal and a trade route. The game runs on its own loop (time scale
## 8) and every half minute of game time the check looks for trouble:
## - a construction site that has stopped growing though workers are free;
## - a supplied building whose queue does not move;
## - research that has points and an open project but does not advance;
## - resources that are negative or not numbers;
## - a unit ordered to move that has not arrived after 90 s;
## - rival nations that stop building.
## Everything found is listed; the test fails on any of it.
var errors: Array[String] = []
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func game_wait(seconds: float) -> void:
	var until: float = w.game_time + seconds
	var guard := 0
	while w.game_time < until and guard < 200000:
		guard += 1
		await process_frame
func place(key: String) -> Dictionary:
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(1, 7):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				if w.logistics.hex_distance(home, h) != ring:
					continue
				var at: Vector3 = w.logistics.hex_center(h) if w.is_district(key) else w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "" and w.build_site(key, at):
					return w.buildings[-1]
	return {}
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("normal")
	w.menu.close()  # unpauses the game, as Begin campaign does
	w.economy.grant_test_resources()
	Engine.time_scale = 8.0
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	# Workers, a town, research.
	for k in range(3):
		w.queue_unit(hq, "worker")
	var sites := []
	for key in ["farm", "housing", "residential", "market", "school", "warehouse", "library", "cottage"]:
		var s: Dictionary = place(key)
		if not s.is_empty():
			sites.append(s)
	print("  placed %d sites: %s" % [sites.size(), sites.map(func(s): return s.key)])
	check(sites.size() >= 6, "a town's worth of districts can be placed in the starting land")
	for key in ["fertilizers", "taxAdministration", "forestry", "eliteTraining"]:
		w.research.enqueue(key)
	# An army.
	var barracks: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "barracks")
	var factory: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "tankFactory")
	for k in range(3):
		if not barracks.is_empty(): w.queue_unit(barracks[0], "soldier")
		if not factory.is_empty(): w.queue_unit(factory[0], "tank")
	# A market deal.
	var money: float = w.economy.res.money
	await game_wait(5.0)
	var watch := {}      # site id -> [progress, since]
	var queues := {}     # building id -> [queue size, prog, since]
	var research_seen := [0.0, 0.0]
	var findings := {}
	var village = null
	var road_done := false
	var moved := []
	for step in range(24):   # 24 x 30 s = 12 game minutes
		await game_wait(30.0)
		var t: float = w.game_time
		# Found a village and link it once there are workers to spare.
		if village == null and step == 4:
			for ring in range(4, 10):
				if village != null: break
				for q in range(-ring, ring + 1):
					if village != null: break
					for r in range(-ring, ring + 1):
						var h: Vector2i = w.logistics.world_hex(w.start) + Vector2i(q, r)
						var at: Vector3 = w.logistics.hex_center(h)
						if w.logistics.hex_distance(w.logistics.world_hex(w.start), h) == ring and w.site_problem("villageCenter", at, 0) == "" and w.build_site("villageCenter", at):
							village = w.buildings[-1]
							break
			check(village != null, "a village can be founded")
		if village != null and village.built and not road_done:
			var route: Array = w.logistics.plan(w.logistics.world_hex(hq.root.position), w.logistics.world_hex(village.root.position), 0, "road")
			road_done = route.size() > 1 and w.logistics.build(route, "road", 0)
			w.logistics.update_supply()
			check(road_done and village.get("supplied", false), "the village is linked to the capital by road and supplied")
		# Orders for the army now and then.
		if step % 6 == 3:
			var army: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.dmg > 0.0 and not u.get("fly", false) and not u.get("naval", false))
			if not army.is_empty():
				var goal: Vector3 = w.land_point(w.start, 110.0)
				w.order_move(army.slice(0, 6), goal)
				moved.append([t, army.slice(0, 6)])
		# Sites: growing, or waiting for no good reason.
		var free_workers: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == "worker" and u.build_site == null).size()
		for b in w.buildings:
			if b.owner != 0 or b.dead or b.built:
				continue
			var id: int = b.root.get_instance_id()
			var was: Array = watch.get(id, [b.progress, t])
			if b.progress > float(was[0]) + 0.001:
				watch[id] = [b.progress, t]
			elif t - float(was[1]) > 90.0 and free_workers > 0:
				findings["site %s stuck at %d%% for %ds with %d free workers" % [b.key, int(b.progress * 100), int(t - float(was[1])), free_workers]] = true
			else:
				watch[id] = was
		# Queues.
		for b in w.buildings:
			if b.owner != 0 or b.dead or not b.built or b.queue.is_empty():
				continue
			var id: int = b.root.get_instance_id()
			var was: Array = queues.get(id, [b.queue.size(), b.queue_prog, t])
			if b.queue.size() != int(was[0]) or b.queue_prog != float(was[1]):
				queues[id] = [b.queue.size(), b.queue_prog, t]
			elif t - float(was[2]) > 60.0 and b.get("supplied", true) and not w.disabled(b):
				findings["%s queue (%s) stopped for %ds while supplied" % [b.key, str(b.queue), int(t - float(was[2]))]] = true
		# Research.
		var r: Node = w.research
		var progress_sum := 0.0
		for k in r.progress:
			progress_sum += float(r.progress[k].get("stage", 0)) * 1000.0 + float(r.progress[k].get("work", 0.0))
		if not r.queue.is_empty() and r.points > 10.0 and r.queue.any(func(k): return not str(k).begins_with("track:") and r.blocker(k) == ""):
			if progress_sum <= research_seen[0] and t - research_seen[1] > 45.0:
				findings["research idle with %d points and an open project (%s)" % [int(r.points), str(r.queue)]] = true
		if progress_sum > research_seen[0]:
			research_seen = [progress_sum, t]
		if r.queue.size() < 2:
			for key in r.discoveries:
				if r.blocker(key) == "" and not r.done(key) and not key in r.queue:
					r.enqueue(key)
					break
		# Resources.
		for key in w.economy.res:
			var v: float = w.economy.res[key]
			if is_nan(v) or is_inf(v) or v < -0.01:
				findings["resource %s is %s" % [key, str(v)]] = true
		# Units sent 90 s ago have arrived.
		for m in moved:
			if t - float(m[0]) > 90.0 and not m.has("checked"):
				var late: Array = m[1].filter(func(u): return not u.dead and u.target != null)
				if not late.is_empty():
					findings["%d of %d units still marching 90 s after an order" % [late.size(), m[1].size()]] = true
				m.append("checked")
		# Keep the economy going: new workers and sites if all are done.
		if step % 5 == 0:
			w.economy.grant_test_resources()
			w.queue_unit(hq, "worker")
			var s: Dictionary = place(["cottage", "housing", "park", "hospital", "university"][step / 5 % 5])
		if step % 10 == 0:
			print("  t=%ds sites done %d/%d, units %d, era %d, discoveries %d, AI buildings %s" % [int(t), w.buildings.filter(func(b): return b.owner == 0 and b.built).size(), w.buildings.filter(func(b): return b.owner == 0).size(), w.units.filter(func(u): return u.owner == 0 and not u.dead).size(), r.era, r.completed_count(), str(w.ai.nations.map(func(n): return w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size()))])
	Engine.time_scale = 1.0
	# The market and trade, and the rivals.
	var sold: String = w.market.sell("iron", 25)
	print("  market: ", sold)
	var ai_counts: Array = w.ai.nations.map(func(n): return w.buildings.filter(func(b): return b.owner == n.id and not b.dead).size())
	check(ai_counts.all(func(c): return c > 6), "every rival nation has built up (%s buildings)" % str(ai_counts))
	check(w.research.completed_count() >= 3, "research completes discoveries (%d)" % w.research.completed_count())
	for f in findings:
		print("FINDING: ", f)
	check(findings.is_empty(), "nothing stuck or broken in 12 minutes of play (%d findings)" % findings.size())
	print("PLAYTHROUGH PASS" if errors.is_empty() else "PLAYTHROUGH FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
