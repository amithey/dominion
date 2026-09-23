## --sea-test: a warship can sail round the island. Ships start at points of
## open sea all round the coast and are sent to the far side; each must find a
## route and get there.
extends RefCounted

const DT := 1.0 / 20.0   # ships are slow: coarse steps are enough

## Open water `reach` metres out from the island's middle along `angle`
## (the first deep-water point past the coast, plus a margin).
static func sea_point(w: Node, angle: float) -> Vector3:
	var dir := Vector3(cos(angle), 0, sin(angle))
	var last_land := 0.0
	for r in range(0, 700, 5):
		var p := dir * float(r)
		if not w.is_water(p, w.DEEP * 1.5):
			last_land = float(r)
	var at := dir * (last_land + 45.0)
	at.y = float(w.map.seaLevel)
	return at

static func run(w: Node) -> void:
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	if w.naval_navigation == null:
		w.naval_navigation = preload("res://scripts/naval_navigation.gd").new()
		w.naval_navigation.setup(w)
	var nav = w.naval_navigation
	# How the open water breaks into separate pieces (flood fill).
	var seen := {}
	var pieces := []
	for id in nav.open:
		if seen.has(id):
			continue
		var size := 0
		var stack := [id]
		seen[id] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			size += 1
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var n: Vector2i = c + d
				if nav.grid.region.has_point(n) and not nav.grid.is_point_solid(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		pieces.append(size)
	pieces.sort()
	pieces.reverse()
	print("SEA water grid: %d open cells of %d, pieces %s, map half %d" % [nav.open.size(), nav.grid.region.size.x * nav.grid.region.size.y, str(pieces.slice(0, 8)), int(nav.half)])
	var failures := PackedStringArray()
	var report := PackedStringArray()
	for k in range(8):
		var a := k * TAU / 8.0
		var from := sea_point(w, a)
		var to := sea_point(w, a + PI)
		var ship: Dictionary = w.spawn_unit("destroyer", from, 0)
		w.order_move([ship], to)
		var route: PackedVector3Array = PackedVector3Array()
		var arrived := -1.0
		var t := 0.0
		while t < 400.0:
			w.move_craft(ship, DT)
			t += DT
			if route.is_empty() and not ship.path.is_empty():
				route = ship.path.duplicate()
			if ship.target == null:
				arrived = t
				break
		var left := Vector2(to.x - ship.node.position.x, to.z - ship.node.position.z).length()
		report.append("%d deg: route %d pts, %s" % [int(rad_to_deg(a)), route.size(), ("arrived in %d s" % int(arrived)) if arrived >= 0.0 else "stuck %d m short" % int(left)])
		if arrived < 0.0 or left > 30.0:
			failures.append("a ship from %d deg could not reach the far side (%d m short, route %d points)" % [int(rad_to_deg(a)), int(left), route.size()])
		w.kill(ship)
		ship.node.visible = false
	for line in report:
		print("SEA " + line)
	if failures.is_empty():
		print("SEA_TEST PASS")
	else:
		for f in failures:
			print("SEA_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
