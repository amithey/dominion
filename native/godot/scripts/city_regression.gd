## --city-test: armour and workers inside a crowded city.
## 1. Tanks cross a city of two full rings of districts, and drive into its
##    middle; every hull must arrive.
## 2. A construction site with no worker calls one; a worker that cannot reach
##    the site is sent round to another side; a worker the player sends to an
##    unfinished site (right click) takes up the work.
extends RefCounted

const DT := 1.0 / 60.0

static func step(w: Node) -> void:
	w._physics_process(DT)
	w.effects._physics_process(DT)
	w.effects.debris._physics_process(DT)

## Districts on every dry, buildable hex within `rings` of the capital.
static func crowd_city(w: Node, rings: int) -> int:
	var home: Vector2i = w.logistics.world_hex(w.start)
	var placed := 0
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home + Vector2i(q, r)
			if w.logistics.hex_distance(home, h) > rings or h == home:
				continue
			if w.district_hex.has(h):
				continue
			var at: Vector3 = w.logistics.hex_center(h)
			if w.height_at(at.x, at.z) < float(w.map.seaLevel) + 1.0:
				continue
			var key := "housing" if (q + r) % 2 == 0 else "market"
			if not w.building_defs.has(key):
				key = "cottage"
			w.place_building(key, at, 0, true)
			w.close_navigation(at, w.DISTRICT_NAV_SIZE)
			placed += 1
	w.refresh_streets()
	return placed

## The navigation server takes in a changed walk grid between frames.
static func sync_nav(w: Node) -> void:
	for i in range(3):
		await w.get_tree().physics_frame

static var worst_wait := 0.0

static func drive(w: Node, group: Array, goal: Vector3, seconds: float) -> float:
	w.order_move(group, goal)
	var slow := {}
	for f in range(int(seconds * 60)):
		step(w)
		for u in group:
			if u.target != null and absf(u.get("cur_speed", 0.0)) < 0.4:
				var k: int = u.node.get_instance_id()
				slow[k] = slow.get(k, 0) + 1
				if slow[k] % 180 == 0 and OS.get_cmdline_user_args().has("--trace"):
					print("   slow %s at %s rem %.1f path %d stuck %d open %s cap %s" % [u.key, u.node.position, Vector2(u.target.x - u.node.position.x, u.target.z - u.node.position.z).length(), u.path.size(), u.get("stuck", 0), w.open_ground(u.node.position), u.get("traffic_cap", INF)])
		if group.all(func(u): return u.target == null):
			print("   standing still while ordered: %s s" % str(slow.values().map(func(v): return snappedf(v / 60.0, 0.1))))
			for v in slow.values():
				worst_wait = maxf(worst_wait, v / 60.0)
			return f / 60.0
	return -1.0

static func run(w: Node) -> void:
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	var placed := crowd_city(w, 2)
	await sync_nav(w)
	var hex_w: float = w.logistics.radius * sqrt(3.0)
	var home: Vector3 = w.logistics.hex_center(w.logistics.world_hex(w.start))
	# Across: from beyond the west edge of the city to beyond the east edge.
	for trial in [[Vector3(-1, 0, 0), Vector3(1, 0, 0)], [Vector3(0, 0, -1), Vector3(0.2, 0, 1)], [Vector3(1, 0, 1).normalized(), Vector3(-1, 0, -0.6).normalized()]]:
		var from: Vector3 = home + trial[0] * hex_w * 3.4
		var to: Vector3 = home + trial[1] * hex_w * 3.4
		if w.height_at(from.x, from.z) < 1.0 or w.height_at(to.x, to.z) < 1.0:
			continue
		var group := []
		for i in range(4):
			var u: Dictionary = w.spawn_unit("tank" if i % 2 == 0 else "apc", from + Vector3((i % 2) * 7.0 - 3.5, 0, (i / 2) * 7.0 - 3.5), 0)
			group.append(u)
		var took := drive(w, group, to, 90.0)
		var short: Array = group.filter(func(u): return u.target != null)
		print("CITY across %s -> %s: %s" % [trial[0], trial[1], ("%.1f s" % took) if took >= 0 else "%d of %d stuck" % [short.size(), group.size()]])
		if took > 75.0:
			failures.append("armour took %.0f s to cross 140 m of city (about 40-60 s is normal)" % took)
		if took < 0:
			for u in short:
				print("   stuck at %s, %.1f m from its mark, path %d" % [u.node.position, Vector2(u.target.x - u.node.position.x, u.target.z - u.node.position.z).length(), u.path.size()])
			failures.append("armour did not cross the city")
		# Then into the middle of the city: the capital's doorstep.
		var inner: Vector3 = home + (trial[0] + trial[1]).normalized() * hex_w * 0.5 if (trial[0] + trial[1]).length() > 0.1 else home + Vector3(hex_w * 0.5, 0, 0)
		took = drive(w, group, inner, 90.0)
		short = group.filter(func(u): return u.target != null)
		print("CITY into the centre: %s" % (("%.1f s" % took) if took >= 0 else "%d of %d stuck" % [short.size(), group.size()]))
		if took < 0:
			for u in short:
				print("   stuck at %s, %.1f m from its mark" % [u.node.position, Vector2(u.target.x - u.node.position.x, u.target.z - u.node.position.z).length()])
			failures.append("armour did not reach the city centre")
		for u in group:
			w.kill(u)
	# Construction: a site with nobody on it gets a worker.
	var site_at: Vector3 = home + Vector3(0, 0, hex_w * 3.0)
	site_at = w.logistics.hex_center(w.logistics.world_hex(site_at))
	var site: Dictionary = w.place_building("housing", site_at, 0, false)
	w.close_navigation(site.root.position, w.DISTRICT_NAV_SIZE)
	w.refresh_streets()
	await sync_nav(w)
	var worker: Dictionary = w.spawn_unit("worker", home + Vector3(0, 0, -hex_w * 3.0), 0)
	for f in range(60 * 150):
		step(w)
		if site.built:
			break
	print("CITY idle worker called to a site: built %s, progress %.2f" % [site.built, site.progress])
	if not site.built:
		failures.append("an unattended site was never finished")
	# A worker stuck on the wrong side: its approach point is made unreachable.
	var site2: Dictionary = w.place_building("housing", w.logistics.hex_center(w.logistics.world_hex(home + Vector3(hex_w * 3.0, 0, hex_w * 1.2))), 0, false)
	w.close_navigation(site2.root.position, w.DISTRICT_NAV_SIZE)
	await sync_nav(w)
	worker.build_site = site2
	worker.target = worker.node.position + Vector3(0.5, 0, 0)  # a pointless order it finishes at once, far from the site
	for f in range(60 * 150):
		step(w)
		if site2.built:
			break
	print("CITY worker left short of its site recovers: built %s, progress %.2f" % [site2.built, site2.progress])
	if not site2.built:
		failures.append("a worker that stopped short of its site never resumed")
	# The player resumes an abandoned site by sending a worker to it.
	var site3: Dictionary = w.place_building("housing", w.logistics.hex_center(w.logistics.world_hex(home + Vector3(-hex_w * 3.0, 0, hex_w * 1.2))), 0, false)
	w.close_navigation(site3.root.position, w.DISTRICT_NAV_SIZE)
	await sync_nav(w)
	site3.progress = 0.5
	w.order_move([worker], worker.node.position + Vector3(4, 0, 0))  # busy elsewhere: the site is abandoned
	for f in range(60):
		step(w)
	worker.build_site = null
	w.order_build([worker], site3)
	var assigned: bool = is_same(worker.build_site, site3)
	for f in range(60 * 150):
		step(w)
		if site3.built:
			break
	print("CITY right-click resumes a half-built site: assigned %s, built %s" % [assigned, site3.built])
	if not (assigned and site3.built):
		failures.append("sending a worker to an unfinished building did not finish it")
	# A worker's list of jobs: two sites queued (shift + right click) are built
	# one after the other; then it helps at the nearest unfinished site.
	var jobs := []
	for k in range(3):
		var h: Vector3 = w.logistics.hex_center(w.logistics.world_hex(home + Vector3(-hex_w * 3.0 + k * hex_w, 0, -hex_w * 2.6)))
		var s: Dictionary = w.place_building("housing", h, 0, false)
		w.close_navigation(s.root.position, w.DISTRICT_NAV_SIZE)
		jobs.append(s)
	await sync_nav(w)
	for other in w.units:
		if other.key == "worker" and not is_same(other, worker):
			other.node.position = home + Vector3(0, 0, 400)  # out of the way: only our worker builds
			other.build_site = null
			other.target = null
	w.order_build([worker], jobs[0])
	w.order_build([worker], jobs[1], true)
	var queued_ok: bool = is_same(worker.build_site, jobs[0]) and worker.build_queue.size() == 1
	for f in range(60 * 400):
		step(w)
		if jobs.all(func(j): return j.built):
			break
	print("CITY worker's job list: queued %s, built %s" % [queued_ok, jobs.map(func(j): return j.built)])
	if not (queued_ok and jobs.all(func(j): return j.built)):
		failures.append("a worker did not work through its list of jobs and then help elsewhere")
	print("CITY districts placed %d, longest a hull stood still under orders %.1f s" % [placed, worst_wait])
	if worst_wait > 8.0:
		failures.append("a hull stood still for %.1f s in the city streets" % worst_wait)
	for f in failures:
		print("FAIL: " + f)
	print("CITY_TEST %s" % ("PASS" if failures.is_empty() else "FAIL"))
	w.get_tree().quit(0 if failures.is_empty() else 1)
