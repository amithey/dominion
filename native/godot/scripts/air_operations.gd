extends RefCounted
## Air bases, ammunition and the landing cycle.
##
## Ammunition is counted in firing passes / salvos, not individual submunitions.
## An airfield has SLOTS parking places on its apron and a runway along its
## hex; a helipad has two pads. Every aircraft belongs to a slot:
##   ready     flying its orders
##   returning heading for its base when its ammunition is spent (or when told to land)
##   landing   final approach down to the runway (a helicopter comes straight down on its slot)
##   taxi_in   rolling from the runway to its parking slot
##   rearming  parked on its slot while crews rearm it (SERVICE_SECONDS)
##   parked    on its slot, rearmed, waiting for orders (new aircraft start here)
##   taxi_out  rolling from its slot to the end of the runway
##   takeoff   climbing out along the runway
## A base whose slots are all taken accepts no more aircraft, and trains none.

const CAPACITY := {"jet": 4, "bomber": 3, "drone": 6, "helicopter": 8, "gunship": 8, "loiterer": 1, "stealthFighter": 4, "raptor": 4, "raider": 2, "shahed": 1, "sixthGen": 4, "wingman": 99, "akinci": 8, "harop": 1, "superTucano": 4, "interceptorDrone": 1, "jf17": 4, "attackJet": 4, "lightFighter": 3, "scoutHelicopter": 1, "aewc": 1, "ewJet": 3, "maritimePatrol": 4, "carrierJet": 2, "carrierDrone": 2, "heavyLift": 6, "navalHelicopter": 2, "heavyBomberDrone": 99}
const SERVICE_SECONDS := 12.0
const Costs := preload("res://scripts/war_costs.gd")
const RESERVE_SECONDS := 12.0
const APPROACH_SECONDS := 8.0
## Launched from a canister beside the runway, straight into the air: they hold
## no parking slot (and never come back).
const TUBE_LAUNCHED := ["loiterer", "shahed", "wingman", "harop", "interceptorDrone", "heavyBomberDrone"]
const SLOTS := {"airfield": 4, "helipad": 2}
## Where things are on an airfield, in its hex's own space (architecture.airfield draws the same).
const RUNWAY_X := -3.2
const RUNWAY_START := -10.0
const TOUCHDOWN := -6.0
const SLOT_POSITIONS := {
	"airfield": [Vector3(5.6, 0, -7.2), Vector3(5.6, 0, -2.4), Vector3(5.6, 0, 2.4), Vector3(5.6, 0, 7.2)],
	"helipad": [Vector3(-3.5, 0, 0), Vector3(3.5, 0, 0)],
}
const TAXI_SECONDS := 2.2
const PARK_HEADING := -2.3   ## aircraft park angled, so their wings clear the next slot

static func initialize(u: Dictionary) -> void:
	u.sortie_left = preload("res://scripts/war_costs.gd").SORTIE_SECONDS
	u.ammo = CAPACITY.get(u.key, 0)
	u.air_state = "ready"
	u.had_base = false
	u.service_left = 0.0
	u.air_base = null
	u.egress = null
	u.slot = -1

static func is_base(b: Dictionary) -> bool:
	return SLOTS.has(b.key)

## Helicopters land on helipads, aircraft on airfields: a helicopter no longer
## takes a jet's parking slot on the apron.
const ROTARY := ["helicopter", "gunship", "scoutHelicopter", "heavyLift", "navalHelicopter"]

static func available(world: Node, u: Dictionary, b: Dictionary) -> bool:
	return not b.dead and b.built and b.owner == u.owner and b.get("supplied", true) and not world.disabled(b) and ((b.key == "airfield" and not u.key in ROTARY) or (b.key == "helipad" and u.key in ROTARY))

## The aircraft holding each slot of base `b` (null where free); dead or
## departed holders are cleared.
static func occupants(world: Node, b: Dictionary) -> Array:
	var slots: Array = b.get("air_slots", [])
	var n: int = SLOTS.get(b.key, 0)
	if slots.size() != n:
		slots.resize(n)
	for i in range(n):
		var holder = slots[i]
		if holder != null and (holder.dead or not is_same(holder.get("air_base"), b) or int(holder.get("slot", -1)) != i):
			slots[i] = null
	b.air_slots = slots
	return slots

static func free_slot(world: Node, b: Dictionary) -> int:
	var slots := occupants(world, b)
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

## Aircraft based here plus those queued for training here, against its slots.
static func room(world: Node, b: Dictionary) -> int:
	var slots := occupants(world, b)
	var free := slots.count(null)
	return free - b.queue.filter(func(k): return not k in TUBE_LAUNCHED).size()

## Takes slot `i` of base `b` for aircraft `u`.
static func assign(world: Node, u: Dictionary, b: Dictionary, i: int) -> void:
	var slots := occupants(world, b)
	slots[i] = u
	u.air_base = b
	u.had_base = true
	u.slot = i

static func release(world: Node, u: Dictionary) -> void:
	var b = u.get("air_base")
	if b != null and int(u.get("slot", -1)) >= 0:
		var slots := occupants(world, b)
		if u.slot < slots.size() and is_same(slots[u.slot], u):
			slots[u.slot] = null
	u.slot = -1

## A world position on base `b` given in its hex's own space.
static func on_base(world: Node, b: Dictionary, local: Vector3) -> Vector3:
	var p: Vector3 = b.root.position + local
	p.y = maxf(world.height_at(p.x, p.z), b.root.position.y) + 1.2   # a raised platform lifts the aircraft with it
	return p

static func slot_point(world: Node, b: Dictionary, i: int) -> Vector3:
	var list: Array = SLOT_POSITIONS.get(b.key, [Vector3.ZERO])
	return on_base(world, b, list[i % list.size()])

static func distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func burn_rate(u: Dictionary) -> float:
	if u.get("carrier") != null:
		return 1.0
	if u.key in ROTARY:
		return 0.35
	if u.key in ["bomber", "raider", "maritimePatrol", "aewc"]:
		return 0.28
	return 0.4

## Fuel per metre uses the compressed map scale; time spent in the air
## still costs fuel, including when a helicopter is holding position.
static func travel_burn(u: Dictionary) -> float:
	if u.get("carrier") != null:
		return 0.0
	var distance_budget := 950.0
	if u.key in ["bomber", "raider", "maritimePatrol", "aewc"]:
		distance_budget = 1250.0
	elif u.key == "heavyLift":
		distance_budget = 1100.0
	elif u.key in ROTARY or u.key in TUBE_LAUNCHED:
		distance_budget = 750.0
	return Costs.SORTIE_SECONDS / distance_budget

static func fuel_per_metre(u: Dictionary) -> float:
	return travel_burn(u) + burn_rate(u) / maxf(float(u.speed), 1.0)

static func fuel_for(u: Dictionary, from: Vector3, to: Vector3) -> float:
	return distance(from, to) * fuel_per_metre(u)

static func fuel_capacity(u: Dictionary) -> float:
	return load("res://scripts/war_tools.gd").SORTIE if u.get("carrier") != null else Costs.SORTIE_SECONDS

static func attack_release_range(u: Dictionary) -> float:
	return 11.0 if u.key in ["bomber", "raider", "heavyBomberDrone"] else float(u.range) * 0.75

static func on_ground(u: Dictionary) -> bool:
	return u.get("air_state") in ["parked", "rearming", "taxi_in"]

static func approach_point(world: Node, u: Dictionary, b: Dictionary) -> Vector3:
	if u.key in ROTARY:
		return b.node.position + Vector3(0, 0, -30)
	return on_base(world, b, Vector3(RUNWAY_X, 0, TOUCHDOWN - 85.0))

static func landing_fuel(world: Node, u: Dictionary, from: Vector3, base: Dictionary) -> float:
	var approach := approach_point(world, u, base)
	return fuel_for(u, from, approach) + distance(approach, base.node.position) * travel_burn(u) + APPROACH_SECONDS * burn_rate(u)

## Keep the assigned slot when reachable. Search alternatives only when needed.
static func base_for(world: Node, u: Dictionary, from := Vector3.INF, fuel := INF) -> Variant:
	if not from.is_finite():
		from = u.node.position
	var held = u.get("air_base")
	if held != null and available(world, u, held) and int(u.get("slot", -1)) >= 0:
		if landing_fuel(world, u, from, held) <= fuel:
			return held
	var best = null
	var best_cost := INF
	for b in world.buildings:
		if not available(world, u, b):
			continue
		if is_same(held, b) and int(u.get("slot", -1)) >= 0:
			continue
		if room(world, b) <= 0:
			continue
		var cost := landing_fuel(world, u, from, b)
		if cost <= fuel and cost < best_cost:
			best_cost = cost
			best = b
	return best

## The same prediction is used by issued orders and by pursuit in flight.
static func departure_fuel(u: Dictionary) -> float:
	var run := 0.0 if u.key in ROTARY else 22.0 + float(u.altitude) * float(u.speed) / 7.0
	return 8.0 * burn_rate(u) + run * travel_burn(u)

static func mission_blocked(world: Node, u: Dictionary, point: Vector3, action_seconds := 8.0, release_range := 0.0) -> String:
	if not u.get("fly", false):
		return ""
	if u.get("ferrying", false) or u.get("air_state") in ["landing", "taxi_in"]:
		return "Aircraft is committed to landing or transfer."
	var from: Vector3 = u.node.position
	var leg := distance(from, point)
	var release := from.lerp(point, maxf(0.0, 1.0 - release_range / maxf(leg, 0.001)))
	var grounded := on_ground(u)
	var fuel := fuel_capacity(u) if grounded else float(u.get("sortie_left", 0.0))
	if grounded and not Costs.can_pay(world, int(u.owner), 0.0, Costs.sortie_fuel(u)):
		return "Not enough aviation fuel for takeoff."
	var outbound := fuel_for(u, from, release) + action_seconds * burn_rate(u) + (departure_fuel(u) if grounded else 0.0)
	if u.key in TUBE_LAUNCHED:
		return "" if outbound <= fuel else "Destination beyond flight range."
	var remaining := fuel - outbound - RESERVE_SECONDS * burn_rate(u)
	var carrier = u.get("carrier")
	if carrier != null and not carrier.dead:
		if distance(carrier.node.position, point) > load("res://scripts/war_tools.gd").STRIKE_REACH:
			return "Target beyond carrier strike range."
		var deck: Vector3 = load("res://scripts/war_tools.gd").recovery_point(carrier, u, release)
		return "" if fuel_for(u, release, deck) <= remaining else "Not enough fuel to recover aboard."
	# Scenario-spawned aircraft can be directed before a base is established.
	# They still consume fuel and have to land somewhere before it runs out.
	if not u.get("had_base", false) and u.get("air_base") == null and not grounded and not world.buildings.any(func(b): return available(world, u, b)):
		return "" if outbound + RESERVE_SECONDS * burn_rate(u) <= fuel else "Not enough fuel to reach the destination."
	return "" if base_for(world, u, release, remaining) != null else "No reachable landing slot with enough fuel in reserve."

static func patrol_seconds(world: Node, u: Dictionary, point: Vector3) -> float:
	if u.key in TUBE_LAUNCHED or u.get("carrier") != null or u.get("ferrying", false) or u.air_state in ["landing", "taxi_in"]:
		return 0.0
	var grounded := on_ground(u)
	var fuel := fuel_capacity(u) if grounded else float(u.sortie_left)
	fuel -= fuel_for(u, u.node.position, point) + RESERVE_SECONDS * burn_rate(u)
	if grounded:
		fuel -= departure_fuel(u)
	var base = base_for(world, u, point, fuel)
	if base == null:
		return 0.0
	var loiter_burn := burn_rate(u) * 0.3 if u.key in ROTARY else fuel_per_metre(u) * float(u.speed)
	return clampf((fuel - landing_fuel(world, u, point, base)) / maxf(loiter_burn, 0.01), 0.0, 45.0)

static func action_radius(u: Dictionary) -> float:
	var fuel := fuel_capacity(u) if on_ground(u) else float(u.get("sortie_left", 0.0))
	var usable := fuel - 8.0 * burn_rate(u)
	if u.key in TUBE_LAUNCHED:
		return maxf(0.0, usable / fuel_per_metre(u))
	var base = u.get("carrier")
	if base == null:
		base = u.get("air_base")
	if base == null or base.dead:
		return 0.0
	var approach_distance := 30.0 if u.key in ROTARY else 85.0
	if u.get("carrier") != null:
		approach_distance = 0.0
	usable -= (RESERVE_SECONDS + APPROACH_SECONDS) * burn_rate(u) + (departure_fuel(u) if on_ground(u) else 0.0)
	usable -= approach_distance * travel_burn(u)
	var metres := usable / fuel_per_metre(u) - distance(u.node.position, base.node.position)
	var radius := maxf(0.0, metres * 0.5)
	return minf(radius, load("res://scripts/war_tools.gd").STRIKE_REACH) if u.get("carrier") != null else radius

static func return_to_base(u: Dictionary) -> void:
	u.air_state = "returning"
	u.stay = true
	u.erase("patrol")
	u.enemy = null
	u.target = null
	u.egress = null

static func consume(u: Dictionary) -> void:
	u.ammo = maxi(0, int(u.ammo) - 1)
	if u.ammo == 0:
		u.air_state = "returning"
		u.egress = null

## The player tells aircraft to land at base `b` and stay there.
static func order_land(world: Node, u: Dictionary, b: Dictionary) -> bool:
	if not available(world, u, b) or u.key in TUBE_LAUNCHED or u.get("carrier") != null:
		return false
	var same_base := is_same(u.get("air_base"), b) and int(u.get("slot", -1)) >= 0
	var grounded := on_ground(u)
	if same_base and grounded:
		u.erase("payload_order")
		u.erase("patrol")
		u.stay = true
		u.target = null
		u.enemy = null
		return true
	var fuel := fuel_capacity(u) if grounded else float(u.sortie_left)
	var reserve := RESERVE_SECONDS * burn_rate(u) + (departure_fuel(u) if grounded else 0.0)
	if landing_fuel(world, u, u.node.position, b) + reserve > fuel:
		return false
	var slot := int(u.slot) if same_base else free_slot(world, b)
	if slot < 0 or (not same_base and room(world, b) <= 0):
		return false
	if grounded:
		var departure = u.get("air_base")
		if departure == null or not available(world, u, departure) or u.air_state != "parked" or not _taxi_out(world, u):
			return false
		u.departure = departure.node.position if departure != null else u.node.position
	if not same_base:
		release(world, u)
		assign(world, u, b, slot)
	u.erase("payload_order")
	u.erase("patrol")
	u.stay = true
	u.target = null
	u.enemy = null
	u.egress = null
	u.ferrying = grounded or u.air_state in ["taxi_out", "takeoff"]
	if not u.ferrying:
		return_to_base(u)
	return true

## A new aircraft from `b`'s production line, parked on a free slot.
static func park_new(world: Node, u: Dictionary, b: Dictionary) -> bool:
	if not available(world, u, b):
		return false
	var i := free_slot(world, b)
	if i < 0:
		return false
	assign(world, u, b, i)
	u.air_state = "parked"
	u.stay = true
	var at := slot_point(world, b, i)
	u.node.position = at
	u.heading = PARK_HEADING if b.key == "airfield" else 0.0  # parked at an angle, nose toward the taxiway
	u.node.basis = Basis(Vector3.UP, u.heading)
	return true

## True means this update owns movement (landing, service, or takeoff).
static func update(world: Node, u: Dictionary, delta: float) -> bool:
	if u.get("carrier") != null:
		return load("res://scripts/war_tools.gd").carrier_flight(world, u, delta)
	if not on_ground(u):
		var burn := burn_rate(u)
		if u.key in ROTARY and u.air_state == "ready" and not u.get("moving", false) and u.target == null and u.enemy == null:
			burn *= 0.3
		var position: Vector3 = u.node.position
		var travel := distance(position, u.get("fuel_position", position))
		u.fuel_position = position
		u.sortie_left = maxf(0.0, float(u.sortie_left) - delta * burn - travel * travel_burn(u))
		if u.sortie_left <= 0.0:
			world.kill(u)
			return true
	if u.key in TUBE_LAUNCHED:
		return false
	# Fuel and the way home are worked out twice a second of the aircraft's own flying (not by the world clock, so an
	# aircraft stepped on its own, in a test or a replay, checks as often as one in the game).
	var check_due := false
	if u.air_state in ["ready", "returning", "no base"]:
		u.fuel_check_in = float(u.get("fuel_check_in", 0.0)) - delta
		if float(u.fuel_check_in) <= 0.0:
			check_due = true
			u.fuel_check_in = 0.5
	if u.air_state == "ready" and u.has("patrol"):
		var patrol: Dictionary = u.patrol
		if distance(u.node.position, patrol.point) <= 18.0:
			patrol.on_station = true
		if patrol.on_station:
			patrol.remaining -= delta
			if patrol.remaining <= 0.0:
				return_to_base(u)
	if u.air_state == "ready" and check_due:
		var target = u.get("enemy")
		var point: Vector3 = target.node.position if target != null and not target.dead else u.get("target", null) if u.get("target") != null else u.node.position
		var release := attack_release_range(u) if target != null else 0.0
		if u.has("payload_order"):
			release = world.missiles.release_range(u.payload_order.key, u)
		var assigned = u.get("air_base")
		var base_lost: bool = assigned != null and not available(world, u, assigned)
		var needs_return := base_lost or mission_blocked(world, u, point, 4.0, release) != ""
		if needs_return and (u.get("had_base", false) or base_for(world, u, u.node.position, INF) != null):
			return_to_base(u)
			if not u.get("fuel_warned", false) and u.owner == 0 and world.hud != null:
				u.fuel_warned = true
				world.hud.notice("Aircraft returning: flight reserve reached.", u.node.position)
	if u.air_state == "ready":
		return false
	if u.air_state == "parked":
		u.moving = false
		if (u.target != null or u.enemy != null) and u.get("air_base") != null and available(world, u, u.air_base):
			u.stay = false
			_taxi_out(world, u)
		return true
	var base = u.get("air_base")
	var departing: bool = u.get("ferrying", false) and u.air_state in ["taxi_out", "takeoff"]
	var too_far: bool = check_due and u.air_state == "returning" and base != null and landing_fuel(world, u, u.node.position, base) > float(u.sortie_left)
	if u.air_state == "no base" and not check_due:
		return false
	if not departing and (base == null or not available(world, u, base) or int(u.get("slot", -1)) < 0 or too_far):
		if on_ground(u) and base != null and not base.dead and base.owner == u.owner:
			return true
		release(world, u)
		base = base_for(world, u, u.node.position, float(u.sortie_left))
		u.air_base = base
		if base != null:
			assign(world, u, base, free_slot(world, base))
			return_to_base(u)
		elif u.air_state != "no base" and u.owner == 0 and world.hud != null:
			world.hud.notice("Aircraft emergency: no reachable landing slot.", u.node.position)
		u.air_state = "returning" if base != null else "no base"
		u.service_left = 0.0
	if base == null and not departing:
		return false
	var vertical: bool = u.key in ROTARY
	var slot := slot_point(world, base, u.slot) if base != null else u.node.position as Vector3
	var touchdown := slot if vertical or base == null else on_base(world, base, Vector3(RUNWAY_X, 0, TOUCHDOWN))
	if u.air_state == "returning":
		var approach: Vector3 = goal(world, u)
		if Vector2(u.node.position.x - approach.x, u.node.position.z - approach.z).length() < 18.0:
			u.air_state = "landing"
			u.landing_start = u.node.position
			u.landing_progress = 0.0
		else:
			return false
	if u.air_state == "landing":
		# An approach is flown slowing down: it comes in a little above its cruising speed and touches down at half of
		# it; the descent is steep at first and flattens near the ground (the flare), with the nose coming up.
		var duration: float = maxf(2.0, u.landing_start.distance_to(touchdown) / maxf(u.speed, 1.0)) * 1.25
		u.landing_progress = minf(1.0, u.landing_progress + delta / duration)
		var p: float = u.landing_progress
		var along: float = 1.4 * p - 0.4 * p * p
		var down: float = 1.0 - pow(1.0 - p, 1.6)
		var dir: Vector3 = touchdown - u.landing_start
		u.heading = lerp_angle(u.heading, atan2(dir.x, dir.z), minf(1, delta * 2.5))
		u.node.position = u.landing_start.lerp(touchdown, along)
		u.node.position.y = lerpf(u.landing_start.y, touchdown.y, down)
		u.node.position.y = maxf(u.node.position.y, world.height_at(u.node.position.x, u.node.position.z) + 1.2)
		var flare: float = smoothstep(0.6, 1.0, p)
		u.node.basis = Basis(Vector3.UP, u.heading) * Basis(Vector3.RIGHT, (-0.14 if vertical else -0.1) * flare + 0.04 * (1.0 - flare))
		u.air_vel = Vector3.ZERO
		u.yaw_rate = 0.0
		u.bank = 0.0
		u.pitch = 0.0
		u.moving = true
		if u.landing_progress >= 1.0:
			if vertical:
				_park(u)
			else:
				u.air_state = "taxi_in"
				u.taxi_from = u.node.position
				u.taxi_progress = 0.0
		return true
	if u.air_state == "taxi_in":
		u.taxi_progress = minf(1.0, u.taxi_progress + delta / TAXI_SECONDS)
		var dir2: Vector3 = slot - u.taxi_from
		u.heading = lerp_angle(u.heading, atan2(dir2.x, dir2.z), minf(1, delta * 4.0))
		u.node.position = u.taxi_from.lerp(slot, u.taxi_progress)
		u.node.basis = Basis(Vector3.UP, u.heading)
		u.moving = true
		if u.taxi_progress >= 1.0:
			u.heading = PARK_HEADING
			u.node.basis = Basis(Vector3.UP, u.heading)
			_park(u)
		return true
	if u.air_state == "rearming":
		u.moving = false
		u.service_left = maxf(0.0, u.service_left - delta)
		if u.service_left == 0:
			u.ammo = CAPACITY[u.key]
			u.sortie_left = fuel_capacity(u)
			if u.get("stay", false) or (u.target == null and u.enemy == null):
				u.air_state = "parked"
			else:
				_taxi_out(world, u)
		return true
	if u.air_state == "taxi_out":
		var runway := touchdown
		if not vertical and base != null:
			runway = on_base(world, base, Vector3(RUNWAY_X, 0, RUNWAY_START))
		if departing and u.has("departure"):
			runway = u.departure + (Vector3.ZERO if vertical else Vector3(RUNWAY_X, 0, RUNWAY_START))
			runway.y = maxf(world.height_at(runway.x, runway.z), runway.y) + 1.2
		u.taxi_progress = minf(1.0, u.taxi_progress + delta / (TAXI_SECONDS if not vertical else 0.01))
		var dir3: Vector3 = runway - u.taxi_from
		if dir3.length() > 0.1:
			u.heading = lerp_angle(u.heading, atan2(dir3.x, dir3.z), minf(1, delta * 4.0))
		u.node.position = u.taxi_from.lerp(runway, u.taxi_progress)
		u.node.basis = Basis(Vector3.UP, u.heading)
		u.moving = true
		if u.taxi_progress >= 1.0:
			u.air_state = "takeoff"
			u.takeoff_roll = 0.0
		return true
	if u.air_state == "takeoff":
		# A rolling take-off: it turns onto the runway (+z) and gathers speed,
		# leaves the ground after 22 m, lifts its nose and climbs away. (It used
		# to slide down the runway sideways in its taxiing pose.)
		var next: Vector3
		var pitch := 0.0
		if vertical:
			# It lifts off gently and climbs faster once clear of the pad.
			var lifted: float = u.node.position.y - maxf(world.height_at(u.node.position.x, u.node.position.z), float(world.map.seaLevel))
			next = u.node.position + Vector3.UP * delta * lerpf(2.2, 6.0, clampf(lifted / 5.0, 0.0, 1.0))
		else:
			u.heading = lerp_angle(u.heading, 0.0, minf(1.0, delta * 5.0))
			var roll: float = float(u.get("takeoff_roll", 0.0))
			var pace: float = float(u.speed) * clampf(0.35 + roll / 45.0, 0.35, 1.1)
			next = u.node.position + Basis(Vector3.UP, u.heading) * Vector3.BACK * pace * delta
			u.takeoff_roll = roll + pace * delta
			if roll > 22.0:
				next.y += delta * 7.0
				pitch = clampf((roll - 22.0) / 30.0, 0.0, 0.22)
		var floor_y: float = maxf(world.height_at(next.x, next.z), float(world.map.seaLevel))
		next.y = maxf(next.y, floor_y + 1.2)
		u.node.position = next
		u.node.basis = Basis(Vector3.UP, u.heading) * Basis(Vector3.RIGHT, -pitch)
		u.moving = true
		if next.y >= floor_y + u.altitude:
			u.air_state = "returning" if u.get("ferrying", false) else "ready"
			u.ferrying = false
			u.erase("departure")
			u.orbit = u.node.position
		return true
	return false

static func _park(u: Dictionary) -> void:
	u.air_state = "rearming"
	u.service_left = SERVICE_SECONDS if int(u.ammo) < int(CAPACITY.get(u.key, 0)) else 0.5
	u.moving = false

static func _taxi_out(world: Node, u: Dictionary) -> bool:
	if not preload("res://scripts/war_costs.gd").pay(world, int(u.owner), 0.0, preload("res://scripts/war_costs.gd").sortie_fuel(u)):
		preload("res://scripts/war_costs.gd").blocked(world, u, "aviation fuel")
		return false
	u.sortie_left = Costs.SORTIE_SECONDS
	u.fuel_position = u.node.position
	u.fuel_warned = false
	u.operating_shortage = ""
	u.air_state = "taxi_out"
	u.taxi_from = u.node.position
	u.taxi_progress = 0.0
	return true

static func goal(world: Node, u: Dictionary) -> Variant:
	if u.air_base != null:
		var base: Dictionary = u.air_base
		if base.key == "helipad" or u.key in ROTARY:
			return slot_point(world, base, u.slot) + Vector3(0, 0, -30)
		return on_base(world, base, Vector3(RUNWAY_X, 0, TOUCHDOWN)) - Vector3(0, 0, 85)
	return null
