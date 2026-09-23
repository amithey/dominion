extends RefCounted
## Which unit is under the mouse.
##
## A click used to count only within 24 px of one point in the middle of a
## unit, so an eleven-metre submarine or a destroyer filling half the screen
## could be selected only by hitting its centre. Now every unit is tested
## against its real outline on screen: the unit's box (its meshes' bounds,
## measured once) is projected through the camera and the click must fall
## inside that shape, or within a small margin of it. Small units keep a
## minimum clickable radius so a soldier far away is still easy to pick.
## When shapes overlap, the one whose centre is nearest the click wins.

const MARGIN := 8.0       ## pixels of grace around a unit's outline
const MIN_RADIUS := 18.0  ## the smallest clickable radius round a unit's centre

## Buildings can be much taller than their ground footprint. Test the visible
## meshes with the camera ray, so a dome, roof or facade is also clickable.
## This runs only on clicks; do not cache construction meshes that can change.
static func pick_building(camera: Camera3D, buildings: Array, screen: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best = null
	var nearest := INF
	for building in buildings:
		if building.dead or not is_instance_valid(building.root): continue
		for mesh in building.root.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree(): continue
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var hit = mesh.get_aabb().intersects_ray(inverse * origin, inverse.basis * direction)
			if hit == null: continue
			var point: Vector3 = mesh.global_transform * hit
			if (point - origin).dot(direction) < 0: continue
			var distance := origin.distance_squared_to(point)
			if distance < nearest:
				nearest = distance
				best = building
	return best

## The unit's box in its own space, measured from its meshes once (the
## selection ring and effects are left out).
static func local_box(unit: Dictionary) -> AABB:
	if unit.has("pick_box"):
		return unit.pick_box
	var node: Node3D = unit.node
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if is_same(mi, unit.get("ring")) or not mi.visible:
			continue
		var xf := Transform3D.IDENTITY
		var current: Node = mi
		while current != null and current != node:
			if current is Node3D:
				xf = (current as Node3D).transform * xf
			current = current.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 2, 1))
	unit.pick_box = box
	return box

## Screen distance from `screen` to the unit's outline: 0 inside, otherwise
## pixels to the nearest edge. Returns INF behind the camera.
static func distance(camera: Camera3D, unit: Dictionary, screen: Vector2) -> float:
	var node: Node3D = unit.node
	var box := local_box(unit)
	var xf: Transform3D = node.global_transform
	var points := PackedVector2Array()
	for k in range(8):
		var corner := box.position + Vector3(box.size.x * (k & 1), box.size.y * ((k >> 1) & 1), box.size.z * ((k >> 2) & 1))
		var world_point: Vector3 = xf * corner
		if camera.is_position_behind(world_point):
			return INF
		points.append(camera.unproject_position(world_point))
	var hull := Geometry2D.convex_hull(points)
	var centre := camera.unproject_position(xf * box.get_center())
	var near_centre := maxf(centre.distance_to(screen) - MIN_RADIUS, 0.0)
	if hull.size() >= 3 and Geometry2D.is_point_in_polygon(screen, hull):
		return 0.0
	var edge := INF
	for i in range(hull.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(screen, hull[i], hull[i + 1])
		edge = minf(edge, closest.distance_to(screen))
	return minf(edge, near_centre)

## The best unit under `screen` among `candidates` (null if none), preferring
## clicks inside an outline, then the nearest centre.
static func pick(camera: Camera3D, candidates: Array, screen: Vector2) -> Variant:
	var best = null
	var best_score := INF
	for u in candidates:
		var d := distance(camera, u, screen)
		if d > MARGIN:
			continue
		var centre := camera.unproject_position(u.node.global_transform * local_box(u).get_center())
		var score := d * 1000.0 + centre.distance_to(screen)
		if score < best_score:
			best_score = score
			best = u
	return best

## The point on screen that stands for the unit in a drag box: its box centre.
static func screen_centre(camera: Camera3D, unit: Dictionary) -> Vector2:
	return camera.unproject_position(unit.node.global_transform * local_box(unit).get_center())

## --pick-test: every kind of unit is selectable by clicking anywhere on its
## body (ends and sides, not only the middle); empty ground selects nothing.
static func run(w: Node) -> void:
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	var sea = w.water_near(w.start, 320)
	var land: Vector3 = w.land_point(w.start + Vector3(0, 0, -60), 30.0)
	var cases := [["submarine", sea], ["destroyer", sea], ["tank", land], ["soldier", land], ["jet", land], ["helicopter", land]]
	var report := PackedStringArray()
	for c in cases:
		if c[1] == null:
			continue
		var u: Dictionary = w.spawn_unit(c[0], c[1], 0)
		u.heading = 0.7
		w.place_on_ground(u, c[1])
		w.cam_focus = u.node.position
		w.cam_dist = 45.0
		w.cam_dist_target = 45.0
		w.cam_pitch = 0.75
		w.update_camera(0.0)
		var box := local_box(u)
		var xf: Transform3D = u.node.global_transform
		var hits := 0
		var tries := 0
		# The middle, both ends and both sides, a little inside the outline.
		for f in [Vector3(0, 0, 0), Vector3(0, 0, 0.42), Vector3(0, 0, -0.42), Vector3(0.42, 0, 0), Vector3(-0.42, 0, 0)]:
			var local: Vector3 = box.get_center() + Vector3(box.size.x * f.x, 0, box.size.z * f.z)
			var screen: Vector2 = w.camera.unproject_position(xf * local)
			tries += 1
			if is_same(pick(w.camera, [u], screen), u):
				hits += 1
		var old_way := 0
		for f in [Vector3(0, 0, 0.42), Vector3(0, 0, -0.42)]:
			var screen: Vector2 = w.camera.unproject_position(xf * (box.get_center() + Vector3(0, 0, box.size.z * f.z)))
			if w.camera.unproject_position(u.node.position + Vector3.UP).distance_to(screen) < 24.0:
				old_way += 1
		var empty: Vector2 = w.camera.unproject_position(u.node.position) + Vector2(0, 260)
		if pick(w.camera, [u], empty) != null:
			failures.append("%s: a click on empty ground selected it" % c[0])
		if hits < tries:
			failures.append("%s: only %d of %d clicks on its body selected it" % [c[0], hits, tries])
		report.append("%s %d/%d (ends by the old rule: %d/2)" % [c[0], hits, tries, old_way])
		w.kill(u)
		u.node.visible = false
	print("PICK " + ", ".join(report))
	if failures.is_empty():
		print("PICK_TEST PASS")
	else:
		for f in failures:
			print("PICK_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
