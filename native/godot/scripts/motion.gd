## Ground locomotion and vehicle body physics.
##
## Units no longer switch between standing and full speed in one frame. Speed
## builds up with a unit's acceleration and bleeds off with its brakes, so
## vehicles ease away, slow for corners and roll to a stop on their mark.
## Vehicles drive along their hull: when the goal is off to the side a tracked
## hull pivots on the spot and only then moves, instead of sliding sideways.
## A climb slows everyone and a descent helps a little.
##
## Each vehicle rides a sprung body (a damped spring on pitch and roll):
## it squats when it pulls away, dips its nose when it brakes, leans out of
## a turn, rocks back when its gun fires, and follows the ground's slope
## smoothly rather than snapping to every terrain triangle.
extends RefCounted

const INFANTRY_ACCEL := 11.0   # m/s²: a soldier is at a run in about half a second
const INFANTRY_BRAKE := 16.0
const INFANTRY_TURN := 11.0    # rad/s
const VEHICLE_ACCEL := 2.4     # a tank needs about two seconds to reach its top speed
const VEHICLE_BRAKE := 5.0
const VEHICLE_TURN := 1.35     # rad/s; tracked hulls pivot in place
const PIVOT_ANGLE := 1.25      # past this heading error a vehicle stops and turns first
const STEER_GAIN := 3.0        # turn rate per radian of heading error (then capped)

const SPRING := 70.0           # body stiffness
const DAMPING := 8.5           # below critical, so a hard stop rocks once or twice
const SQUAT := 0.018           # radians of pitch per m/s² of acceleration
const LEAN := 0.05             # radians of roll per rad/s·(m/s) of cornering
const MAX_TILT := 0.16

## Moves `unit` toward `to` (flat vector to its next waypoint), `remaining`
## metres from the end of its route, and returns this frame's displacement.
static func drive(w: Node, unit: Dictionary, to: Vector3, remaining: float, chasing: bool, delta: float) -> Vector3:
	var vehicle: bool = unit.vehicle
	var want := atan2(to.x, to.z)
	var err := angle_difference(unit.heading, want)
	var turn_rate := VEHICLE_TURN if vehicle else INFANTRY_TURN
	var old_heading: float = unit.heading
	# Proportional steering: a full-rate turn only when well off the line,
	# easing in as the heading comes round, so a hull settles on its course
	# instead of swinging past it and back (the old bang-bang weave).
	var turn := clampf(err * STEER_GAIN, -turn_rate, turn_rate) * delta
	if absf(turn) > absf(err):
		turn = err
	unit.heading = wrapf(unit.heading + turn, -PI, PI)
	unit.yaw_rate = angle_difference(old_heading, unit.heading) / maxf(delta, 0.0001)
	var fwd := Vector3(sin(unit.heading), 0, cos(unit.heading))
	# Throttle falls with the heading error; a hull facing away turns first.
	var align := 1.0
	if vehicle:
		align = clampf(1.0 - absf(err) / PIVOT_ANGLE, 0.0, 1.0)
		align = align * align * (3.0 - 2.0 * align)
	else:
		align = clampf(cos(err) * 0.5 + 0.5, 0.35, 1.0)
	# Grade along the direction of travel (rise over run).
	var p: Vector3 = unit.node.position
	var grade: float = (w.height_at(p.x + fwd.x * 2.0, p.z + fwd.z * 2.0) - w.height_at(p.x - fwd.x * 2.0, p.z - fwd.z * 2.0)) / 4.0
	var slope := clampf(1.0 - grade * (1.6 if vehicle else 1.5), 0.6 if vehicle else 0.45, 1.12)
	# A formation marches at the pace of its slowest member until it fights.
	var pace: float = unit.get("pace", INF) if not chasing else INF
	var top: float = minf(minf(unit.speed, pace), float(unit.get("traffic_cap", INF))) * slope * align
	var brake := VEHICLE_BRAKE if vehicle else INFANTRY_BRAKE
	# Never faster than a stop within the distance left: at the end of a route,
	# or at a firing position (otherwise a hull circles a moving mark forever).
	top = minf(top, sqrt(2.0 * brake * maxf(remaining if not chasing else to.length(), 0.0)) + 0.35)
	var v: float = unit.get("cur_speed", 0.0)
	var old_v := v
	v = move_toward(v, top, (VEHICLE_ACCEL if vehicle else INFANTRY_ACCEL) * delta if top > v else brake * delta)
	unit.cur_speed = v
	unit.accel = (v - old_v) / maxf(delta, 0.0001)
	if unit.player != null and unit.get("clip", "") == unit.get("run_clip", "#"):
		unit.player.speed_scale = maxf(v, 0.8) / unit.get("clip_speed", 4.6)
	# Soldiers step toward the waypoint while they finish turning; hulls go where they point.
	var dir := fwd if vehicle else fwd.lerp(to.normalized(), 0.5).normalized()
	return dir * minf(v * delta, to.length() + (0.0 if vehicle else 0.05))

## The unit is holding still this frame (arrived, firing or blocked).
static func halt(unit: Dictionary, delta: float) -> void:
	var v: float = unit.get("cur_speed", 0.0)
	if v == 0.0:
		unit.accel = 0.0
		unit.yaw_rate = 0.0
		return
	unit.cur_speed = 0.0
	unit.accel = -v / maxf(delta, 0.0001) * 0.25  # a firm stop, felt through the springs
	unit.yaw_rate = 0.0

## A gun firing kicks the hull back on its springs.
static func recoil(unit: Dictionary, strength := 1.0) -> void:
	if unit.get("vehicle", false) and not unit.get("naval", false) and not unit.get("fly", false):
		unit.sus_pitch_v = float(unit.get("sus_pitch_v", 0.0)) - 1.6 * strength

## Advances the spring and returns the vehicle's basis on ground with
## normal `ground_up`, heading `heading`.
static func body_basis(unit: Dictionary, ground_up: Vector3, heading: float, delta: float) -> Basis:
	# The hull follows the ground through its suspension, not triangle by triangle.
	var up: Vector3 = unit.get("hull_up", ground_up)
	# Normals on adjacent terrain cells can be almost parallel. Normalised
	# linear blending avoids an ill-conditioned slerp rotation axis there.
	up = up.lerp(ground_up, minf(1.0, delta * 9.0)).normalized()
	unit.hull_up = up
	var travel := (Basis(Vector3.UP, heading) * Vector3.BACK).slide(up).normalized()
	var base := Basis.looking_at(-travel, up)
	# Accelerating squats the tail (nose up), braking dives; turning leans out.
	var want_pitch := clampf(-float(unit.get("accel", 0.0)) * SQUAT, -MAX_TILT, MAX_TILT)
	var want_roll := clampf(float(unit.get("yaw_rate", 0.0)) * float(unit.get("cur_speed", 0.0)) * LEAN, -MAX_TILT, MAX_TILT)
	var pitch: float = unit.get("sus_pitch", 0.0)
	var pitch_v: float = unit.get("sus_pitch_v", 0.0)
	var roll: float = unit.get("sus_roll", 0.0)
	var roll_v: float = unit.get("sus_roll_v", 0.0)
	pitch_v += (-(pitch - want_pitch) * SPRING - pitch_v * DAMPING) * delta
	roll_v += (-(roll - want_roll) * SPRING - roll_v * DAMPING) * delta
	pitch = clampf(pitch + pitch_v * delta, -MAX_TILT, MAX_TILT)
	roll = clampf(roll + roll_v * delta, -MAX_TILT, MAX_TILT)
	unit.sus_pitch = pitch
	unit.sus_pitch_v = pitch_v
	unit.sus_roll = roll
	unit.sus_roll_v = roll_v
	return base * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)

## The shock of a blast at `at` reaching `unit` with `strength` (1 = at the
## centre of a shell burst, 0 = at the edge). Soldiers are shoved off their
## feet a step or two; one killed by the blast is thrown (update_dead flies
## him); a vehicle's hull is jolted on its springs, away from the burst.
static func shove(unit: Dictionary, at: Vector3, strength: float) -> void:
	if strength <= 0.0 or unit.get("fly", false) or unit.get("naval", false):
		return
	var away: Vector3 = unit.node.position - at
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	if unit.vehicle:
		var local := Basis(Vector3.UP, unit.heading).inverse() * away
		unit.sus_pitch_v = float(unit.get("sus_pitch_v", 0.0)) + local.z * 2.2 * strength
		unit.sus_roll_v = float(unit.get("sus_roll_v", 0.0)) - local.x * 2.2 * strength
		return
	if unit.dead:
		unit.fling = away * randf_range(4.0, 7.0) * strength + Vector3.UP * randf_range(5.5, 8.0) * strength
		unit.fling_spin = randf_range(-6.0, 6.0)
		if not unit.has("fling_base"):
			unit.fling_base = unit.model.basis
	else:
		unit.knock = Vector3(unit.get("knock", Vector3.ZERO)) + away * 4.5 * strength

## Slides a shoved soldier along and bleeds the shove off (friction).
## Returns the displacement for this frame.
static func knock_step(unit: Dictionary, delta: float) -> Vector3:
	var k: Vector3 = unit.get("knock", Vector3.ZERO)
	if k.length_squared() < 0.01:
		if k != Vector3.ZERO:
			unit.knock = Vector3.ZERO
		return Vector3.ZERO
	unit.knock = k * exp(-delta * 5.0)
	return k * delta
