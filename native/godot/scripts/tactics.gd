## How units fight and march as a body.
##
## Firing positions: a unit closing on an enemy does not run to the enemy's
## own spot (where the whole squad used to meet and jam). It heads for a point
## inside its weapon range on its own bearing, fanned out from its comrades,
## so a squad spreads into a firing line and everyone has a shot.
##
## Target choice: prefer what is already in range, what this weapon hurts most,
## and what is already wounded (so fire concentrates and kills). A target that
## cannot be reached (a ship, an aircraft out of range) is not chased, and a
## chase that makes no progress is abandoned for a while.
##
## Formations: a group move becomes ranks across the line of march (armour in
## front, infantry behind, artillery at the back); slots are handed out in the
## order units already stand in, so lines do not cross; and the group marches
## at the pace of its slowest member, arriving together.
extends RefCounted

const RETARGET := 1.2        # seconds between looks for a better target
const CHASE_LIMIT := 12.0    # seconds of chasing without closing in before giving up
const IGNORE_FOR := 10.0     # how long an abandoned target is ignored
const SUPPORT := ["artillery", "mlrs", "samLauncher", "aaVehicle"]

## Where `unit` should stand to shoot at `enemy`.
static func firing_spot(w: Node, unit: Dictionary, enemy: Dictionary) -> Vector3:
	var e: Vector3 = enemy.node.position
	var away: Vector3 = unit.node.position - e
	away.y = 0.0
	if away.length() < 0.1:
		away = -Vector3(sin(unit.heading), 0, cos(unit.heading))
	# Each unit keeps its own fixed bearing offset, so a squad fans out.
	# A unit that found its spot blocked has moved its bearing on (unit.bearing).
	var spread := (fposmod(float(unit.phase) * 7.31, 1.0) - 0.5) * 1.1 + float(unit.get("bearing", 0.0))
	var dir := away.normalized().rotated(Vector3.UP, spread)
	var stand: float = unit.range * 0.78 + (float(enemy.footprint) * 0.45 if enemy.get("is_building", false) else 0.0)
	for shrink in [1.0, 0.8, 0.6]:
		var p: Vector3 = e + dir * stand * shrink
		if w.height_at(p.x, p.z) > float(w.map.seaLevel) + 0.4:
			p.y = w.height_at(p.x, p.z)
			return p
	return e

## Can a ground unit ever get this target into range by walking?
static func reachable(unit: Dictionary, target: Dictionary) -> bool:
	if unit.get("fly", false) or unit.get("naval", false):
		return true
	return not (target.get("naval", false) or target.get("fly", false))

## Best hostile target within `radius`, or null. Lower score is better.
## Ground units read only the grid buckets in reach (plus the short list of
## ships and aircraft); the cheap tests (owner, distance) run before the
## costly ones (hostility, the damage table).
static func pick_target(w: Node, unit: Dictionary, radius: float) -> Variant:
	var best = null
	var best_score := INF
	var ignore: Dictionary = unit.get("ignore", {})
	var at: Vector3 = unit.node.position
	var r2 := radius * radius
	var lists: Array = []
	if w.perf_opts and not (unit.get("fly", false) or unit.get("naval", false)):
		var span := ceili(radius / w.GRID)
		var cx := floori(at.x / w.GRID)
		var cz := floori(at.z / w.GRID)
		for dz in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var bucket = w.grid.get(Vector2i(cx + dx, cz + dz))
				if bucket != null:
					lists.append(bucket)
		lists.append(w.air_sea)
	else:
		lists.append(w.units)
	var own: int = unit.owner
	for list in lists:
		for other in list:
			if other.owner == own or other.dead:
				continue
			var op: Vector3 = other.node.position
			var d2 := (op.x - at.x) * (op.x - at.x) + (op.z - at.z) * (op.z - at.z)
			if d2 > r2:
				continue
			if not w.hostile(own, other.owner):
				continue
			var eff: float = w.effectiveness(unit, other)
			if eff <= 0.01:
				continue
			var d := sqrt(d2)
			if d > unit.range and not reachable(unit, other):
				continue
			if not ignore.is_empty() and float(ignore.get(other.node.get_instance_id(), -1.0)) > w.game_time:
				continue
			var score: float = d / maxf(unit.range, 1.0) - eff * 0.5 - (1.0 - other.hp / maxf(other.max_hp, 1.0)) * 0.4
			if d <= unit.range:
				score -= 1.0
			if score < best_score:
				best_score = score
				best = other
	if best != null:
		return best
	var best_d := radius
	for b in w.buildings:
		if b.dead or b.owner == own:
			continue
		var bp: Vector3 = b.root.position
		if absf(bp.x - at.x) > radius + 20.0 or absf(bp.z - at.z) > radius + 20.0:
			continue
		if not w.hostile(own, b.owner) or w.effectiveness(unit, b) <= 0.01:
			continue
		var d: float = w.gap_to(unit, b)
		if d < best_d:
			best_d = d
			best = b
	return best

## Called every combat tick for a unit with an enemy: drops targets that are
## gone, no longer hostile, unreachable, or not being closed on; swaps for a
## better one in range. Returns false when the enemy was dropped.
static func keep_target(w: Node, unit: Dictionary, delta: float) -> bool:
	var enemy: Dictionary = unit.enemy
	if unit.has("ground_attack"):
		return true  # a bombardment order holds until another order
	if enemy.dead or not w.hostile(unit.owner, enemy.owner):
		drop(unit)
		return false
	var gap: float = w.gap_to(unit, enemy)
	if gap > unit.range and not reachable(unit, enemy):
		drop(unit)
		return false
	if not unit.get("forced", false) and gap > maxf(unit.aggro, unit.range) * 1.6:
		drop(unit)
		return false
	# A chase that does not close the distance is given up for a while.
	# Aircraft are exempt: they fly through, turn and come back by design.
	if gap > unit.range and not unit.get("fly", false):
		if not is_same(unit.get("chase_of"), enemy) or gap < float(unit.get("chase_best", INF)) - 1.5:
			unit.chase_of = enemy
			unit.chase_best = gap
			unit.chase_since = w.game_time
		elif w.game_time - float(unit.chase_since) > CHASE_LIMIT:
			var ignore: Dictionary = unit.get("ignore", {})
			ignore[enemy.node.get_instance_id()] = w.game_time + IGNORE_FOR
			unit.ignore = ignore
			drop(unit)
			return false
	# Now and then look for something better that is already in range.
	unit.retarget = float(unit.get("retarget", 0.0)) - delta
	if unit.retarget <= 0.0 and not unit.get("forced", false):
		unit.retarget = RETARGET
		var better = pick_target(w, unit, maxf(unit.aggro, unit.range))
		if better != null and not is_same(better, enemy) and w.gap_to(unit, better) <= unit.range and (gap > unit.range or better.hp < enemy.hp * 0.5):
			unit.enemy = better
	return true

static func drop(unit: Dictionary) -> void:
	unit.enemy = null
	unit.forced = false
	unit.chase_of = null
	unit.holding = false

# ---------------------------------------------------------------- formations

## Slot for every unit of `selected` around `point`, in ranks across the line
## of march. Returns an Array of Vector3 in the order of `selected`.
static func formation(selected: Array, point: Vector3) -> Array:
	var centre := Vector3.ZERO
	for u in selected:
		centre += u.node.position
	centre /= maxf(selected.size(), 1)
	var forward: Vector3 = point - centre
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 1.0 else Vector3.FORWARD
	var side := Vector3(-forward.z, 0, forward.x)
	# Armour leads, infantry follows, support fires from the back. Groups hold
	# indices into `selected`: unit records refer to each other (targets), so
	# they are never used as keys or compared by value.
	var groups := [[], [], []]
	for i in range(selected.size()):
		var u: Dictionary = selected[i]
		groups[2 if u.key in SUPPORT else (0 if u.vehicle else 1)].append(i)
	var result := []
	result.resize(selected.size())
	var depth := 0.0
	var extent := 0.0   # how far behind the front rank the last rank stands
	for g in range(3):
		var members: Array = groups[g]
		if members.is_empty():
			continue
		var spacing := 6.0 if g != 1 else 2.8
		var width := maxi(1, ceili(sqrt(members.size() * (1.0 if g != 1 else 2.2))))
		# Hand out slots left to right in the order units already stand across
		# the line of march, so nobody crosses a comrade's path.
		members.sort_custom(func(a, b): return side.dot(selected[a].node.position) < side.dot(selected[b].node.position))
		var rows := ceili(float(members.size()) / width)
		for k in range(members.size()):
			var row := k / width
			var in_row := mini(width, members.size() - row * width)
			var across := (k % width - (in_row - 1) / 2.0) * spacing
			result[members[k]] = point + side * across - forward * (depth + row * spacing)
		extent = depth + (rows - 1) * spacing
		depth += rows * spacing + 1.5
	# Centre the whole block, first rank to last, on the point clicked.
	var shift := forward * extent * 0.5
	for i in range(result.size()):
		result[i] += shift
	return result

# ---------------------------------------------------------------- crowding

## When the crowd pushes straight back against where a unit is going, it
## steps round the obstruction instead (always to the same side for the
## same unit, so two units facing each other pass rather than dance).
static func sidestep(unit: Dictionary, travel: Vector3, push: Vector3) -> Vector3:
	if travel.length_squared() < 0.000001 or push.length_squared() < 0.000001:
		return push
	var along := push.dot(travel.normalized())
	if along >= -0.3 * push.length():
		return push
	var side := Vector3(-travel.z, 0, travel.x).normalized() * (1.0 if fposmod(float(unit.phase), 2.0) < 1.0 else -1.0)
	return push + side * push.length() * 0.9

## A chasing unit that has not got anywhere for a moment takes a new bearing
## round its target and a fresh route.
static func unjam(w: Node, unit: Dictionary, delta: float) -> void:
	unit.jam_t = float(unit.get("jam_t", 0.0)) + delta
	if unit.jam_t < 1.5:
		return
	unit.jam_t = 0.0
	var was: Vector3 = unit.get("jam_at", Vector3.INF)
	unit.jam_at = unit.node.position
	if was != Vector3.INF and was.distance_to(unit.node.position) < 0.8:
		unit.bearing = float(unit.get("bearing", 0.0)) + (0.7 if fposmod(float(unit.phase), 2.0) < 1.0 else -0.7)
		unit.path = PackedVector3Array()

## Push that separates a ground unit at `at` from its neighbours.
static func crowd_push(w: Node, unit: Dictionary, at: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var cx := floori(at.x / w.GRID)
	var cz := floori(at.z / w.GRID)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bucket = w.grid.get(Vector2i(cx + dx, cz + dz)) if w.perf_opts else (w.units if dx == 0 and dz == 0 else null)
			if bucket == null:
				continue
			for other in bucket:
				if is_same(other, unit) or other.dead or other.get("fly", false) or other.get("naval", false):
					continue
				var gap: Vector3 = at - other.node.position
				gap.y = 0
				# Hulls are about seven metres long: two vehicles keep 6.5 m apart.
				var clearance: float = (1.1 if not (unit.vehicle or other.vehicle) else 3.4) + (3.1 if unit.vehicle and other.vehicle else 0.0)
				var d2 := gap.length_squared()
				if d2 < clearance * clearance:
					if d2 < 0.000001:
						# Exactly on top of each other: split along a fixed per-unit direction.
						var a: float = float(unit.phase) * 12.9
						gap = Vector3(cos(a), 0, sin(a)) * 0.001
						d2 = gap.length_squared()
					var d := sqrt(d2)
					push += gap / d * (clearance - d)
	return push
