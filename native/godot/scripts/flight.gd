## How aircraft fly (world.move_craft, world.place_on_ground, world.update_dead).
##
## Turning. An aeroplane turns by banking: it rolls into the turn (roll rate), holds a turn rate its class can sustain, and
## rolls out as its nose comes on to the course. The old rule closed a share of the heading error every frame, so a jet
## snapped round at 200 degrees a second when its target was behind it and crawled through the last few degrees. The bank
## shown is the one that turn rate needs, so a hard turn is seen as a hard turn.
##
## Helicopters carry momentum: a velocity that is pulled toward the one wanted with a limited acceleration, so they ease
## away, swing wide when the order changes and flare to a hover instead of stopping dead. The fuselage shows it: nose down
## to gather speed, nose up to stop, rolled toward a sideways push.
##
## Height. Aircraft hold their height over the ground with a limited rate of climb and descent, looking a little ahead, so
## they rise before a hill and sink after it (nose up, nose down) instead of copying every bump of the ground below.
##
## Falling. A shot-down aircraft keeps the speed it had: it arcs on under gravity with the nose dropping, rolling; a
## helicopter spins round its mast as it comes down.
extends RefCounted

## class -> [turn rate (rad/s), bank in that turn (rad), roll rate (rad/s)]
const CLASSES := {
	"fighter": [1.0, 1.1, 2.8],
	"heavy": [0.5, 0.6, 1.0],
	"drone": [0.75, 0.7, 1.8],
	"rotary": [1.7, 0.38, 2.0],
}
const HEAVY := ["bomber", "raider", "aewc", "maritimePatrol", "heavyBomberDrone", "akinci"]
const DRONES := ["drone", "loiterer", "shahed", "harop", "interceptorDrone", "carrierDrone"]
const ROTARY_ACCEL := 6.5      # m/s²
const ROTARY_BRAKE := 4.5      # the deceleration a helicopter plans its stop with (below what it can do, so it holds the plan)
const CLIMB := {true: 9.0, false: 5.5}    # m/s, fixed wing and rotary
const SINK := {true: 7.0, false: 4.5}
const FALL_GRAVITY := 12.0

static func class_of(unit: Dictionary, fixed: bool) -> Array:
	var c = unit.get("_flight")
	if c == null:
		var key: String = unit.key
		c = CLASSES["rotary"] if not fixed else (CLASSES["heavy"] if key in HEAVY else (CLASSES["drone"] if key in DRONES else CLASSES["fighter"]))
		unit["_flight"] = c
	return c

## Turns `unit` toward heading `want` and returns its new heading.
static func turn(unit: Dictionary, want: float, fixed: bool, delta: float) -> float:
	var c := class_of(unit, fixed)
	var err := angle_difference(unit.heading, want)
	# The turn rate wanted: all it has when well off the course, easing as the nose comes round.
	var rate := clampf(err * 2.6, -float(c[0]), float(c[0]))
	# It has to roll into the turn first: the rate follows the stick in about a third of a second.
	var cur: float = move_toward(float(unit.get("yaw_rate", 0.0)), rate, float(c[0]) * 3.0 * delta)
	var step := cur * delta
	if step * err > 0.0 and absf(step) > absf(err):
		step = err
		cur = 0.0
	unit.yaw_rate = cur
	return wrapf(unit.heading + step, -PI, PI)

## The heading an aeroplane should steer to reach a goal `to` metres away (flat). A goal inside its turning circle cannot be
## reached by turning toward it (it would orbit the goal for ever): it flies on to open the distance, then comes round.
static func steer(unit: Dictionary, to: Vector3, want: float) -> float:
	var radius: float = float(unit.speed) / float(class_of(unit, true)[0])
	var local: Vector3 = Basis(Vector3.UP, unit.heading).inverse() * to
	if local.z > 0.0 and absf(local.x) < 3.0:
		return want   # dead ahead: nothing to work out
	var centre := Vector3(signf(local.x) * radius if local.x != 0.0 else radius, 0.0, 0.0)
	if (Vector3(local.x, 0.0, local.z) - centre).length() < radius * 0.97:
		return unit.heading
	return want

## The bank that goes with the turn being flown (and, for a helicopter, the tilt of a body that is being pushed along).
static func attitude(unit: Dictionary, fixed: bool, delta: float) -> void:
	var c := class_of(unit, fixed)
	var bank_want: float = -float(unit.get("yaw_rate", 0.0)) / float(c[0]) * float(c[1])
	if not fixed:
		var inv := Basis(Vector3.UP, unit.heading).inverse()
		var acc: Vector3 = inv * Vector3(unit.get("air_acc", Vector3.ZERO))
		var vel: Vector3 = inv * Vector3(unit.get("air_vel", Vector3.ZERO))
		# Local +z is the nose, local +x the left side. A rotor disc tilts the way it is pushing.
		var pitch_want := clampf(acc.z * 0.04 + vel.z / maxf(float(unit.speed), 1.0) * 0.08, -0.32, 0.32)
		bank_want = clampf(bank_want - acc.x * 0.05, -0.45, 0.45)
		unit.pitch = move_toward(float(unit.get("pitch", 0.0)), pitch_want, 1.4 * delta)
	unit.bank = move_toward(float(unit.get("bank", 0.0)), bank_want, float(c[2]) * delta)

## A helicopter's step toward a goal `to` metres away (flat): its velocity is pulled toward the one wanted.
static func hover_step(unit: Dictionary, to: Vector3, delta: float) -> Vector3:
	var v: Vector3 = unit.get("air_vel", Vector3.ZERO)
	var dist := to.length()
	var want := Vector3.ZERO
	if dist > 0.01:
		# Never faster than it can stop in the distance left.
		want = to / dist * minf(float(unit.speed), sqrt(2.0 * ROTARY_BRAKE * dist) + 0.4)
	var nv := v.move_toward(want, ROTARY_ACCEL * delta)
	unit.air_acc = (nv - v) / maxf(delta, 0.0001)
	unit.air_vel = nv
	var step := nv * delta
	if dist > 0.01 and step.length() > dist and step.dot(to) > 0.0:
		step = to
	return step

## A helicopter with no goal slows to a hover (it does not stop dead); returns this frame's drift.
static func coast(unit: Dictionary, delta: float) -> Vector3:
	var v: Vector3 = unit.get("air_vel", Vector3.ZERO)
	if v == Vector3.ZERO:
		unit.air_acc = Vector3.ZERO
		return Vector3.ZERO
	var nv := v.move_toward(Vector3.ZERO, ROTARY_ACCEL * delta)
	unit.air_acc = (nv - v) / maxf(delta, 0.0001)
	unit.air_vel = nv
	unit.yaw_rate = move_toward(float(unit.get("yaw_rate", 0.0)), 0.0, 5.0 * delta)
	return nv * delta

## The height (y) of `unit` over the point `at`, whose ground (or sea) is at `floor_y`: held with a limited rate of
## climb and descent. The first placement, and a jump across the map, put it straight at its height.
static func altitude(w: Node, unit: Dictionary, at: Vector3, floor_y: float, fixed: bool) -> float:
	var node: Node3D = unit.node
	var want: float = floor_y + float(unit.altitude)
	var now: float = w.game_time
	var jumped: bool = Vector2(at.x - node.position.x, at.z - node.position.z).length() > 25.0
	if not unit.has("alt_y") or jumped:
		unit.alt_y = want
		unit.alt_v = 0.0
		unit.alt_t = now
		unit.pitch = 0.0
		return want
	var y: float = unit.alt_y
	if absf(node.position.y - float(unit.get("alt_set", node.position.y))) > 0.05:
		y = node.position.y   # something else has been flying it (a take-off, a landing): carry on from where it is
	var dt := clampf(now - float(unit.get("alt_t", now)), 0.0, 0.25)
	unit.alt_t = now
	var v: float = unit.get("alt_v", 0.0)
	if dt > 0.0:
		if unit.get("moving", false):
			# It looks ahead, as a pilot does: the height to hold is that of the higher ground it is flying toward.
			var lead := (1.2 if fixed else 0.8) * float(unit.speed)
			var ax: float = at.x + sin(unit.heading) * lead
			var az: float = at.z + cos(unit.heading) * lead
			want = maxf(want, maxf(w.height_at(ax, az), float(w.map.seaLevel)) + float(unit.altitude))
		var v_want := clampf((want - y) * 1.8, -float(SINK[fixed]), float(CLIMB[fixed]))
		v = move_toward(v, v_want, 14.0 * dt)
		y += v * dt
		var hard: float = floor_y + minf(float(unit.altitude), 3.0)   # whatever happens, not into the hill
		if y < hard:
			y = hard
			v = maxf(v, 0.0)
		if fixed:
			# The nose points where it is going: up in a climb, down in a descent.
			unit.pitch = lerpf(float(unit.get("pitch", 0.0)), -clampf(atan2(v, maxf(float(unit.speed), 1.0)), -0.3, 0.35), minf(1.0, dt * 5.0))
	unit.alt_y = y
	unit.alt_v = v
	return y

## One frame of a shot-down aircraft's fall. Returns true while it is still in the air.
static func fall(w: Node, unit: Dictionary, floor_y: float, delta: float) -> bool:
	var node: Node3D = unit.node
	if node.position.y <= floor_y + 0.5:
		return false
	var rotary: bool = not (unit.key in w.FIXED_WING)
	if not unit.has("fall_vel"):
		var ahead := Basis(Vector3.UP, unit.heading) * Vector3.BACK
		var flying: bool = str(unit.get("air_state", "ready")) in ["ready", "returning", "no base"]
		var v0: Vector3 = Vector3(unit.get("air_vel", Vector3.ZERO)) if rotary else ahead * float(unit.speed)
		unit.fall_vel = (v0 if flying else Vector3.ZERO) + Vector3.UP * float(unit.get("alt_v", 0.0))
		unit.fall_spin = (1.0 if randf() < 0.5 else -1.0) * randf_range(1.6, 3.4)
		unit.fall_pitch = 0.0
	var v: Vector3 = unit.fall_vel
	v.y -= FALL_GRAVITY * delta
	var drag := maxf(0.0, 1.0 - 0.22 * delta)   # the air takes the forward speed away, slowly
	v.x *= drag
	v.z *= drag
	unit.fall_vel = v
	node.position += v * delta
	if rotary:
		# Without its tail rotor it spins round the mast, and tips over as it goes.
		node.rotate_object_local(Vector3.UP, float(unit.fall_spin) * 1.6 * delta)
		node.rotate_object_local(Vector3.BACK, 0.35 * delta)
	else:
		node.rotate_object_local(Vector3.BACK, float(unit.fall_spin) * delta)
		if float(unit.fall_pitch) < 1.1:
			# The nose drops toward the way it is falling.
			var d := minf(0.75 * delta, 1.1 - float(unit.fall_pitch))
			unit.fall_pitch = float(unit.fall_pitch) + d
			node.global_transform.basis = Basis(Basis(Vector3.UP, unit.heading) * Vector3.RIGHT, d) * node.global_transform.basis
	return true
