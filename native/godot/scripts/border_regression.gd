## --border-test: borders, passage and taking ground.
## 1. Crossing into a nation at peace without leave is a border incident:
##    relations fall, their government answers, and the trespassers take no land.
## 2. A friendly nation grants passage when asked; guests take no land.
## 3. At war, an operational zone in their land is taken.
extends RefCounted

const DT := 1.0 / 60.0

static func simulate(w: Node, seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for f in range(frames):
		w._physics_process(DT)
		if f % 60 == 59:
			w.passage.watch(1.0)
		if f % 120 == 119:
			w.territory.tick()

## A cell of `nation`'s land far from its buildings (the edge of its country),
## next to land that is not its own.
static func border_cell(w: Node, nation: int) -> int:
	var t: Node = w.territory
	var best := -1
	var best_d := -1.0
	var home = w.ai.hq(nation)
	for i in range(t.owner_of.size()):
		if t.owner_of[i] != nation or t.terrain[i] == t.Terrain.WATER or not w.open_ground(t.center(i)):
			continue
		var d: float = t.center(i).distance_to(home.root.position) if home != null else 0.0
		if d > best_d:
			best_d = d
			best = i
	return best

## Open ground outside `nation`'s land, near `at`.
static func outside(w: Node, nation: int, at: Vector3) -> Vector3:
	for r in range(20, 200, 10):
		for k in range(16):
			var p: Vector3 = at + Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0)) * r
			if w.open_ground(p) and w.territory.owner_at(p) != nation:
				p.y = w.height_at(p.x, p.z)
				return p
	return at

static func squad(w: Node, at: Vector3, n: int) -> Array:
	var out := []
	for i in range(n):
		out.append(w.spawn_unit("tank", at + Vector3((i % 3) * 7.0, 0, (i / 3) * 7.0), 0))
	return out

static func run(w: Node) -> void:
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		n.next_attack = 99999.0
	for id in range(1, d.n):
		d.set_flag(d.war, 0, id, false)
	w.territory.tick()
	var cell := border_cell(w, 1)
	if cell < 0:
		print("BORDER_TEST FAIL: nation 1 holds no land")
		w.get_tree().quit(1)
		return
	var inside: Vector3 = w.territory.center(cell)
	inside.y = w.height_at(inside.x, inside.z)
	var gate := outside(w, 1, inside)
	# Nation 1's own troops stay out of the way of the measurement.
	for u in w.units:
		if u.owner == 1 and not u.dead:
			w.kill(u)

	# 1. Crossing without leave.
	d.set_score(0, 1, -5.0)
	var tanks := squad(w, gate, 3)
	var issued := [false]
	w.passage.check_order(tanks, inside, func():
		issued[0] = true
		w.order_move(tanks, inside))
	if issued[0] or w.passage.last_answers.size() != 4:
		failures.append("an order into foreign land was not stopped for the cabinet's question")
	w.passage.answer("Cross anyway")
	if not issued[0]:
		failures.append("'Cross anyway' did not give the order")
	var rel_before: float = d.rel(0, 1)
	var control_before: float = w.territory.control[cell]
	var incidents_before: int = int(w.engagement.incidents.get("1", 0))
	simulate(w, 32.0)
	var entered := tanks.any(func(u): return w.territory.owner_at(u.node.position) == 1)
	if not entered:
		failures.append("the tanks never entered nation 1's land")
	if int(w.passage.incidents.get("0>1", 0)) < 1:
		failures.append("crossing without leave was not recorded as a border incident")
	if d.rel(0, 1) > rel_before - 3.0:
		failures.append("relations did not fall for the trespass (%.1f -> %.1f)" % [rel_before, d.rel(0, 1)])
	if int(w.engagement.incidents.get("1", 0)) <= incidents_before and not d.at_war(0, 1):
		failures.append("their government never answered 30 s of trespass")
	if w.territory.owner_of[cell] != 1:
		failures.append("trespassers at peace took the land")
	print("BORDER phase 1: relations %.1f -> %.1f, border incidents %d, government answers %d, cell still theirs: %s (control %.0f -> %.0f)" % [rel_before, d.rel(0, 1), int(w.passage.incidents.get("0>1", 0)), int(w.engagement.incidents.get("1", 0)) - incidents_before, w.territory.owner_of[cell] == 1, control_before, w.territory.control[cell]])
	for u in tanks:
		w.kill(u)

	# 2. Passage from a friend.
	d.set_flag(d.war, 0, 1, false)
	w.engagement.operations.clear()
	d.set_score(0, 1, 70.0)
	var guests := squad(w, gate, 3)
	issued[0] = false
	w.passage.check_order(guests, inside, func():
		issued[0] = true
		w.order_move(guests, inside))
	w.passage.answer("Request passage")
	if not w.passage.has_passage(0, 1) or not issued[0]:
		failures.append("a friendly nation (+70) refused passage or the order was not given")
	var control_guest: float = w.territory.control[cell]
	simulate(w, 20.0)
	if int(w.passage.incidents.get("0>1", 0)) > 1:
		failures.append("guests with passage caused a border incident")
	if w.territory.owner_of[cell] != 1 or w.territory.control[cell] < control_guest - 1.0:
		failures.append("guests with passage wore down the owner's hold")
	print("BORDER phase 2: passage %s (%.0f s left), control %.0f -> %.0f" % [w.passage.has_passage(0, 1), w.passage.seconds_left(0, 1), control_guest, w.territory.control[cell]])
	for u in guests:
		w.kill(u)

	# 3. War and an operational zone.
	d.declare_war(0, 1)
	var army := squad(w, gate, 6)
	w.occupation.place(inside, army, 0)
	if w.occupation.zones.is_empty():
		failures.append("the operational zone was not placed")
	else:
		var zone: Dictionary = w.occupation.zones[0]
		var theirs_before: int = zone.cells.filter(func(i): return w.territory.owner_of[i] == 1).size()
		var taken := 0
		for k in range(12):
			simulate(w, 15.0)
			taken = zone.cells.filter(func(i): return w.territory.owner_of[i] == 0).size()
			if taken > 0 and not w.occupation.zones.has(zone):
				break
		print("BORDER phase 3: zone of %d cells (%d theirs), %d taken after the advance" % [zone.cells.size(), theirs_before, taken])
		if taken == 0:
			failures.append("an army holding an operational zone at war took no land in 3 minutes")
	if failures.is_empty():
		print("BORDER_TEST PASS")
	else:
		for f in failures:
			print("BORDER_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
