## --land-test: the rules of land.
## 1. Anywhere in your territory is buildable, even far from a settlement centre.
## 2. Troops claim unclaimed land only by paying for it (none without money).
## 3. Sea hexes off a nation's coast are its territorial waters.
extends RefCounted

static func run(w: Node) -> void:
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	var t: Node = w.territory
	t.tick()
	# 0. A settlement's land grows with its people, up to its limit.
	var hq: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq" and not b.dead)[0]
	w.economy.civilians = 40.0
	var small: int = t.rings_of(hq)
	w.economy.civilians = w.economy.civ_cap
	for k in range(6):
		w.place_building("residential", w.test_site("residential", hq.root.position), 0, true)
	w.economy.recalculate()
	w.economy.civilians = w.economy.civ_cap
	var large: int = t.rings_of(hq)
	print("LAND capital rings: %d with few people, %d with a full city (limit %d)" % [small, large, t.RINGS_MAX.hq])
	if not (small < large and large <= t.RINGS_MAX.hq):
		failures.append("the capital's land did not grow with its people (%d -> %d)" % [small, large])
	for k in range(4):
		t.tick()
	# 1. Grow the land with a building at its edge (every building claims a ring),
	# then take the hex of it farthest from any settlement centre.
	var centres: Array = w.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.def.get("settlement") != null)
	var edge := -1
	var edge_d := -1.0
	for i in range(t.owner_of.size()):
		if t.owner_of[i] == 0 and t.terrain[i] != t.Terrain.WATER and w.open_ground(t.center(i)):
			var d: float = t.center(i).distance_to(centres[0].root.position)
			if d > edge_d:
				edge_d = d
				edge = i
	if edge >= 0:
		var c: Vector3 = t.center(edge)
		w.place_building("park", w.snap_to_hex(Vector3(c.x, w.height_at(c.x, c.z), c.z)), 0, true)
		for k in range(4):
			t.tick()
	var far := -1
	var far_d := 0.0
	for i in range(t.owner_of.size()):
		if t.owner_of[i] != 0 or t.terrain[i] == t.Terrain.WATER:
			continue
		var c: Vector3 = t.center(i)
		var taken = w.district_hex.get(w.logistics.world_hex(c))
		if taken != null and not taken.dead:
			continue
		var d := INF
		for b in centres:
			d = minf(d, Vector2(b.root.position.x - c.x, b.root.position.z - c.z).length() - float(b.def.get("buildRadius", 0)))
		if d > far_d:
			far_d = d
			far = i
	if far >= 0:
		var at: Vector3 = t.center(far)
		at.y = w.height_at(at.x, at.z)
		var problem: String = w.site_problem("farm", w.snap_to_hex(at), 0)
		if problem == "Outside your territory":
			failures.append("your own land %.0f m beyond the settlement radius was refused" % far_d)
		print("LAND own hex %.0f m past the settlement radius: %s" % [far_d, problem if problem != "" else "buildable"])
	# 2. Troops never claim unclaimed land; it is bought at a town hall, four hexes at most.
	var hall: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq" and not b.dead)[0]
	var options: Array = t.purchase_candidates(hall)
	if options.is_empty():
		failures.append("the capital's town hall offers no land to buy")
	else:
		var spot: Vector3 = t.center(options[0])
		spot.y = w.height_at(spot.x, spot.z)
		var squad := []
		for k in range(3):
			squad.append(w.spawn_unit("soldier", spot + Vector3(k * 1.5, 0, 0), 0))
		for k in range(3):
			t.tick()
		if t.owner_of[options[0]] == 0:
			failures.append("troops claimed unclaimed land by standing on it")
		for u in squad:
			w.kill(u)
		w.economy.res.money = 10000.0
		var got := 0
		for k in range(6):
			var now: Array = t.purchase_candidates(hall)
			if now.is_empty():
				break
			var said: String = t.purchase(hall, now[0])
			if said.begins_with("Land bought"):
				got += 1
		t.tick()
		var paid: float = 10000.0 - w.economy.res.money
		var kept: int = t.purchased.keys().filter(func(k): return t.owner_of[int(k)] == 0).size()
		print("LAND town hall bought %d hexes for $%d; %d still held after a tick" % [got, int(paid), kept])
		if got != t.PURCHASES:
			failures.append("a settlement bought %d hexes (limit %d)" % [got, t.PURCHASES])
		if absf(paid - got * t.LAND_PRICE) > 0.01:
			failures.append("buying cost %.0f for %d hexes" % [paid, got])
		if kept != got:
			failures.append("bought land was lost on the next territory tick")
	# 3. Territorial waters: a building on the coast makes the sea off it yours.
	for i in range(t.owner_of.size()):
		if t.terrain[i] == t.Terrain.COAST and t.owner_of[i] == -1 and w.open_ground(t.center(i)):
			var c: Vector3 = t.center(i)
			w.place_building("park", Vector3(c.x, w.height_at(c.x, c.z), c.z), 0, true)
			break
	for k in range(3):
		t.tick()
	# 3. Territorial waters.
	var waters := 0
	var wrong := 0
	for i in range(t.owner_of.size()):
		if t.terrain[i] != t.Terrain.WATER or t.owner_of[i] < 0:
			continue
		waters += 1
		var coast_owner := false
		for j in t.neighbours(i):
			if t.owner_of[j] == t.owner_of[i]:
				coast_owner = true
		if not coast_owner:
			wrong += 1
	print("LAND territorial water hexes: %d (%d not touching their owner's hexes)" % [waters, wrong])
	if waters == 0:
		failures.append("no nation holds any territorial waters")
	if wrong > 0:
		failures.append("%d sea hexes held apart from their owner's coast" % wrong)
	if failures.is_empty():
		print("LAND_TEST PASS")
	else:
		for f in failures:
			print("LAND_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
