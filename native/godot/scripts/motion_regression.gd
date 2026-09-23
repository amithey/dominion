## --motion-test: ground movement is physical (motion.gd).
## A tank ordered to a point behind it must turn on the spot before it drives,
## build speed gradually, rock on its springs, and stop on its mark; a soldier
## must reach running speed within a second; a gun must kick the hull.
extends RefCounted

const DT := 1.0 / 60.0

static func step(w: Node, frames: int) -> void:
	for i in range(frames):
		w._physics_process(DT)

static func run(w: Node) -> void:
	var failures: Array[String] = []
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	var field: Vector3 = w.land_point(w.start, 70.0)
	var tank: Dictionary = w.spawn_unit("tank", field, 0)
	tank.heading = 0.0
	w.place_on_ground(tank, field)
	var goal: Vector3 = field + Vector3(0, 0, -24)
	goal.y = w.height_at(goal.x, goal.z)
	w.order_move([tank], goal)
	var from: Vector3 = tank.node.position
	step(w, 12)
	if tank.get("cur_speed", 0.0) > 1.0:
		failures.append("Tank drove off at %.1f m/s before turning toward a goal behind it" % tank.cur_speed)
	if Vector2(tank.node.position.x - from.x, tank.node.position.z - from.z).length() > 0.6:
		failures.append("Tank slid sideways while it should have pivoted")
	var top := 0.0
	var tilt := 0.0
	var reached := false
	var ramp_checked := false
	for frame in range(60 * 25):
		step(w, 1)
		top = maxf(top, tank.get("cur_speed", 0.0))
		tilt = maxf(tilt, absf(tank.get("sus_pitch", 0.0)))
		if not ramp_checked and tank.get("cur_speed", 0.0) > 0.3:
			ramp_checked = true
			if tank.cur_speed > tank.speed * 0.6:
				failures.append("Tank reached %.1f m/s in one step; no acceleration" % tank.cur_speed)
		if tank.target == null:
			reached = true
			break
	var miss := Vector2(tank.node.position.x - goal.x, tank.node.position.z - goal.z).length()
	if not reached or miss > 2.5:
		failures.append("Tank did not stop on its mark (%.1f m away, arrived=%s)" % [miss, reached])
	if top < tank.speed * 0.7:
		failures.append("Tank never reached cruising speed (top %.1f of %.1f)" % [top, tank.speed])
	if tilt < 0.004:
		failures.append("Tank body never pitched on its suspension")
	if absf(angle_difference(tank.heading, PI)) > 0.5:
		failures.append("Tank is not facing the way it drove (heading %.2f)" % tank.heading)
	# A soldier is at a run within a second.
	var soldier: Dictionary = w.spawn_unit("soldier", field + Vector3(8, 0, 0), 0)
	soldier.heading = 0.0
	w.order_move([soldier], field + Vector3(8, 0, 30))
	step(w, 1)
	var first: float = soldier.get("cur_speed", 0.0)
	step(w, 59)
	if first >= soldier.speed * 0.5:
		failures.append("Soldier jumped to %.1f m/s in one frame" % first)
	if soldier.get("cur_speed", 0.0) < soldier.speed * 0.8:
		failures.append("Soldier still at %.1f m/s after a second" % soldier.cur_speed)
	# Firing kicks the hull.
	tank.sus_pitch_v = 0.0
	w.Motion.recoil(tank, 1.0)
	if tank.sus_pitch_v >= 0.0:
		failures.append("Firing did not kick the hull")
	if failures.is_empty():
		print("MOTION_TEST PASS: tank top %.1f m/s, max body pitch %.3f rad, stopped %.2f m from its mark" % [top, tilt, miss])
	else:
		for f in failures:
			print("MOTION_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
