extends SceneTree
## The cars, lorries, buses and trains on the roads and railways
## (route_traffic.gd): they appear on the network you build, as many as its
## length calls for; drive, within their speed, on the road and in the
## right-hand lane; keep their distance; slow for bends; brake to a halt at the
## end of a trip and set off on the next; stand on the ground; leave a road
## that is cut and come back when it is mended; trains keep their wagons
## coupled and reverse at a terminus; none drives through a town; and the
## whole network costs little to run.
var errors: Array[String] = []
var passed := 0
var w: Node
var traffic: Node
const DT := 1.0 / 30.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func road_segments(kind: String) -> Array:
	var out := []
	for e in w.logistics.edges.values():
		if e.kind == kind and e.hp > 0.0:
			out.append([w.logistics.hex_center(e.a), w.logistics.hex_center(e.b)])
	return out

func seg_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (ap - ab * t).length()

func off_road(p: Vector3, segs: Array) -> float:
	var best := INF
	for s in segs: best = minf(best, seg_distance(p, s[0], s[1]))
	return best

func step(seconds: float, each := Callable()) -> void:
	var t := 0.0
	while t < seconds:
		traffic._process(DT)
		if each.is_valid(): each.call()
		t += DT

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20261001)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	traffic = w.get_children().filter(func(n): return n.get_script() == preload("res://scripts/route_traffic.gd"))[0]
	traffic.set_process(false)
	traffic._rng.seed = 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): traffic._rng.seed = int(a.substr(7))
	w.economy.grant_test_resources()
	w.economy.res.money = 1e6
	w.economy.res.iron = 1e5
	# A road out of the capital into the country, turning half way; a railway beside it.
	var home: Vector2i = w.logistics.world_hex(w.start)
	var built := 0
	var road: Array = []
	for goal in [home + Vector2i(-7, 3), home + Vector2i(-4, 8), home + Vector2i(3, 7), home + Vector2i(-8, -2)]:
		var route: Array = w.logistics.plan(home, goal, 0, "road")
		if route.size() >= 5 and w.logistics.build(route, "road", 0):
			built += 1
			if road.is_empty(): road = route
	var rail: Array = []
	for goal in [home + Vector2i(6, -5), home + Vector2i(7, 0), home + Vector2i(0, -7), home + Vector2i(-6, -4)]:
		var route: Array = w.logistics.plan(home + (Vector2i(1, -1)), goal, 0, "rail")
		if route.size() >= 6 and w.logistics.build(route, "rail", 0):
			rail = route
			break
	traffic._sync()
	var road_edges: int = traffic._edge_count.road
	print("  %d roads built (%d links), railway of %d hexes" % [built, road_edges, rail.size()])
	check(built >= 2 and road_edges >= 8, "a road network is built out of the capital (%d links)" % road_edges)

	# 1-2: traffic appears, in proportion.
	step(40.0)
	var cars: Array = traffic._fleet.filter(func(c): return c.kind == "road")
	var trains: Array = traffic._fleet.filter(func(c): return c.kind == "rail")
	var want: int = mini(traffic.MAX_ROAD, ceili(road_edges * traffic.PER_EDGE))
	check(cars.size() >= want - 1 and cars.size() <= traffic.MAX_ROAD, "road traffic appears, as much as the network calls for (%d of %d)" % [cars.size(), want])
	check(rail.is_empty() or trains.size() >= 1, "a train runs on the railway (%d)" % trains.size())

	# 3-9: a minute of driving, watched every step.
	var segs: Array = road_segments("road")
	var S := {"too_fast": 0, "strays": 0, "worst_off": 0.0, "left_lane": 0, "right_lane": 0, "crashes": 0, "floating": 0, "broken": 0, "in_town": 0, "trips": 0, "gaps_ok": true, "back": false}
	var towns: Array = []
	for h in w.district_hex:
		var d = w.district_hex[h]
		if d != null and not d.dead: towns.append(d.root.position)
	var watch := func():
		var fleet: Array = traffic._fleet
		for c in fleet:
			if c.v > c.vmax + 0.05: S.too_fast += 1
			if c.wait > 0.0:
				if not c.has("_waited"): c["_waited"] = true
				elif not c["_waited"]: c["_waited"] = true
			elif c.get("_waited", false):
				c["_waited"] = false
				S.trips += 1
			for b in c.bodies:
				if not b.has("at"): continue
				var p: Vector3 = b.at
				if is_nan(p.x) or is_nan(p.y) or is_nan(p.z): S.broken += 1; continue
				var g: float = traffic._ground(p)
				if absf(p.y - g - float(b.lift)) > 0.8: S.floating += 1
			if c.kind != "road" or not c.bodies[0].has("at"): continue
			var p: Vector3 = c.bodies[0].at
			var off: float = off_road(p, segs)
			S.worst_off = maxf(S.worst_off, off)
			if off > 4.0:
				S.strays += 1
				if S.strays < 4: print("  STRAY off %.1f at %s s %.1f/%.1f wait %.1f v %.1f hexes %s path0 %s" % [off, str(p.snapped(Vector3.ONE)), c.s, c.total, c.wait, c.v, str(c.hexes), str(c.path[0].snapped(Vector3.ONE))])
			for t in towns:
				if Vector2(p.x - t.x, p.z - t.z).length() < traffic.STOP - 2.0: S.in_town += 1
			# Which side of its road: the right of its heading.
			if c.v > 2.0:
				var fwd := Vector3(sin(c.yaw), 0, cos(c.yaw))
				var best := INF
				var side := 0.0
				for s in segs:
					var dd: float = seg_distance(p, s[0], s[1])
					if dd < best:
						best = dd
						var dir: Vector3 = (s[1] - s[0]).normalized()
						if dir.dot(fwd) < 0.0: dir = -dir
						var rel: Vector3 = p - s[0]
						side = dir.x * rel.z - dir.z * rel.x   # < 0 : right of the heading
				if best < 3.0:
					if side > 0.2: S.right_lane += 1   # the game's right hand: (-z, x) of the heading
					elif side < -0.2: S.left_lane += 1
		for i in range(fleet.size()):
			var a: Dictionary = fleet[i]
			if a.kind != "road" or not a.bodies[0].has("at"): continue
			a["_far"] = maxf(float(a.get("_far", 0.0)), a.s)
			for j in range(i + 1, fleet.size()):
				var b: Dictionary = fleet[j]
				if b.kind != "road" or not b.bodies[0].has("at"): continue
				var fa := Vector3(sin(a.yaw), 0, cos(a.yaw))
				var fb := Vector3(sin(b.yaw), 0, cos(b.yaw))
				if fa.dot(fb) < 0.7: continue   # oncoming or crossing
				var rel: Vector3 = b.bodies[0].at - a.bodies[0].at
				var along: float = absf(rel.x * fa.x + rel.z * fa.z)
				var across: float = absf(rel.x * fa.z - rel.z * fa.x)
				if across < 1.0 and along < (a.bodies[0].length + b.bodies[0].length) * 0.5 - 0.3 and a.v + b.v > 0.5:
					S.crashes += 1
					if S.crashes < 4: print("  CRASH along %.1f across %.1f v %.1f/%.1f wait %.1f/%.1f s %.1f/%.1f of %.1f/%.1f same trip %s at %s" % [along, across, a.v, b.v, a.wait, b.wait, a.s, b.s, a.total, b.total, str(a.hexes == b.hexes), str(a.bodies[0].at.snapped(Vector3.ONE))])
	var t0 := Time.get_ticks_usec()
	step(60.0, watch)
	var frame_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / (60.0 / DT)
	var movers: int = traffic._fleet.filter(func(c): return c.kind == "road" and float(c.get("_far", 0.0)) > 5.0).size()
	check(movers >= cars.size() * 0.7, "the cars drive (%d of %d covered ground)" % [movers, cars.size()])
	check(S.too_fast == 0, "no vehicle goes over its top speed")
	check(S.strays == 0, "every car keeps to the road (at most %.1f m from its line)" % S.worst_off)
	check(S.right_lane > S.left_lane * 4, "they drive on the right (%d samples right of the line, %d left)" % [S.right_lane, S.left_lane])
	check(S.crashes == 0, "no car drives into the one in front")
	check(S.floating == 0 and S.broken == 0, "every vehicle stands on the ground (%d off it, %d broken)" % [S.floating, S.broken])
	check(S.in_town == 0, "no car drives through a town's buildings (%d)" % S.in_town)
	check(S.trips >= 3, "cars stop at the end of a trip and set off on the next (%d)" % S.trips)

	# 10: slower in bends than on the straight.
	var bend_v := []
	var straight_v := []
	step(20.0, func():
		for c in traffic._fleet:
			if c.kind != "road" or c.wait > 0.0 or c.v < 0.5 or not c.has("limit"): continue
			var here: float = traffic._yaw_at(c, c.s)
			var turn: float = absf(wrapf(traffic._yaw_at(c, c.s + 8.0) - here, -PI, PI))
			if turn > 0.6: bend_v.append(c.v / c.vmax)
			elif turn < 0.05 and c.limit >= c.vmax * 0.99: straight_v.append(c.v / c.vmax))
	var bend_avg: float = bend_v.reduce(func(s, v): return s + v, 0.0) / maxf(bend_v.size(), 1)
	var straight_avg: float = straight_v.reduce(func(s, v): return s + v, 0.0) / maxf(straight_v.size(), 1)
	check(bend_v.size() > 10 and bend_avg < straight_avg, "they slow for bends (%.0f%% of top speed, %.0f%% on the straight)" % [bend_avg * 100.0, straight_avg * 100.0])

	# 11: trains stay coupled.
	var train_moved := false
	for c in traffic._fleet:
		if c.kind == "rail" and c.bodies[0].has("at"): c["_t0"] = c.bodies[0].at
	step(30.0, func():
		for c in traffic._fleet:
			if c.kind != "rail": continue
			for i in range(1, c.bodies.size()):
				if not (c.bodies[i].has("at") and c.bodies[i - 1].has("at")): continue
				var gap: float = c.bodies[i].at.distance_to(c.bodies[i - 1].at)
				var want_gap: float = (c.bodies[i].length + c.bodies[i - 1].length) * 0.5 + 0.6
				if absf(gap - want_gap) > 2.5: S.gaps_ok = false)
	for c in traffic._fleet:
		if c.kind == "rail" and c.has("_t0") and c.bodies[0].at.distance_to(c["_t0"]) > 5.0: train_moved = true
	check(rail.is_empty() or (S.gaps_ok and train_moved), "trains run with their wagons coupled")

	# 12-13: a cut road empties; mended, traffic returns.
	var cut: Dictionary = {}
	for key in w.logistics.edges:
		var e: Dictionary = w.logistics.edges[key]
		if e.kind == "road" and e.a in road and e.b in road and not traffic._is_town(e.a) and not traffic._is_town(e.b) and road.find(e.a) >= 2:
			cut = e
			break
	var on_cut := func(c): return c.kind == "road" and range(1, c.hexes.size()).any(func(i): return (c.hexes[i - 1] == cut.a and c.hexes[i] == cut.b) or (c.hexes[i - 1] == cut.b and c.hexes[i] == cut.a))
	cut.hp = 0.0
	cut.half = [0.0, 0.0]
	traffic._sync()
	step(3.0)
	check(not traffic._fleet.any(on_cut), "no car drives over a destroyed stretch of road")
	var others: int = traffic._fleet.filter(func(c): return c.kind == "road").size()
	check(others >= 1, "traffic carries on on the rest of the network (%d cars)" % others)
	cut.hp = cut.max_hp
	cut.half = [cut.max_hp, cut.max_hp]
	traffic._sync()
	step(150.0, func(): S.back = S.back or traffic._fleet.any(on_cut))
	check(S.back, "mended, the road carries traffic again")

	# 14: the network costs little.
	check(frame_ms < 3.0, "all of it costs %.2f ms a frame" % frame_ms)
	# 15: drawn: one instance per body.
	var bodies := 0
	for c in traffic._fleet: bodies += c.bodies.size()
	var instances := 0
	for name in traffic._models: instances += int(traffic._models[name].count)
	check(instances == bodies, "every vehicle is drawn, once (%d instances for %d bodies)" % [instances, bodies])
	print("\nROAD_TRAFFIC: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("ROAD_TRAFFIC PASS" if errors.is_empty() else "ROAD_TRAFFIC FAIL")
	quit(0 if errors.is_empty() else 1)
