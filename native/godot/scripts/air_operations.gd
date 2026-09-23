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

const CAPACITY := {"jet": 4, "bomber": 3, "drone": 6, "helicopter": 8, "gunship": 8}
const SERVICE_SECONDS := 12.0
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
	u.ammo = CAPACITY.get(u.key, 0)
	u.air_state = "ready"
	u.service_left = 0.0
	u.air_base = null
	u.egress = null
	u.slot = -1

static func is_base(b: Dictionary) -> bool:
	return SLOTS.has(b.key)

static func available(world: Node, u: Dictionary, b: Dictionary) -> bool:
	return not b.dead and b.built and b.owner == u.owner and b.get("supplied", true) and not world.disabled(b) and (b.key == "airfield" or (b.key == "helipad" and u.key in ["helicopter", "gunship"]))

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
	return free - b.queue.size()

## Takes slot `i` of base `b` for aircraft `u`.
static func assign(world: Node, u: Dictionary, b: Dictionary, i: int) -> void:
	var slots := occupants(world, b)
	slots[i] = u
	u.air_base = b
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
	p.y = world.height_at(p.x, p.z) + 1.2
	return p

static func slot_point(world: Node, b: Dictionary, i: int) -> Vector3:
	var list: Array = SLOT_POSITIONS.get(b.key, [Vector3.ZERO])
	return on_base(world, b, list[i % list.size()])

## The nearest working base with room for `u` (or the one it already holds a slot at).
static func base_for(world: Node, u: Dictionary) -> Variant:
	var held = u.get("air_base")
	if held != null and available(world, u, held) and int(u.get("slot", -1)) >= 0:
		return held
	var best = null
	var distance := INF
	for b in world.buildings:
		if available(world, u, b) and free_slot(world, b) >= 0:
			var d: float = u.node.position.distance_squared_to(b.node.position)
			if d < distance:
				distance = d
				best = b
	return best

static func consume(u: Dictionary) -> void:
	u.ammo = maxi(0, int(u.ammo) - 1)
	if u.ammo == 0:
		u.air_state = "returning"
		u.egress = null

## The player tells aircraft to land at base `b` and stay there.
static func order_land(world: Node, u: Dictionary, b: Dictionary) -> bool:
	if not available(world, u, b):
		return false
	if not (is_same(u.get("air_base"), b) and int(u.get("slot", -1)) >= 0):
		var i := free_slot(world, b)
		if i < 0:
			return false
		release(world, u)
		assign(world, u, b, i)
	u.air_state = "returning"
	u.stay = true
	u.target = null
	u.enemy = null
	return true

## A new aircraft from `b`'s production line, parked on a free slot.
static func park_new(world: Node, u: Dictionary, b: Dictionary) -> bool:
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
	if u.air_state == "ready":
		return false
	if u.air_state == "parked":
		u.moving = false
		if u.target != null or u.enemy != null:
			u.stay = false
			_taxi_out(world, u)
		return true
	var base = u.air_base
	if base == null or not available(world, u, base) or int(u.get("slot", -1)) < 0:
		release(world, u)
		base = base_for(world, u)
		u.air_base = base
		if base != null:
			assign(world, u, base, free_slot(world, base))
		u.air_state = "returning" if base != null else "no base"
		u.service_left = 0.0
	if base == null:
		return false  # keep circling; no free replenishment without a working base
	var vertical: bool = base.key == "helipad" or u.key in ["helicopter", "gunship"]
	var slot := slot_point(world, base, u.slot)
	var touchdown := slot if vertical else on_base(world, base, Vector3(RUNWAY_X, 0, TOUCHDOWN))
	if u.air_state == "returning":
		var approach: Vector3 = touchdown - Vector3(0, 0, 85) if not vertical else touchdown + Vector3(0, 0, -30)
		if Vector2(u.node.position.x - approach.x, u.node.position.z - approach.z).length() < 18.0:
			u.air_state = "landing"
			u.landing_start = u.node.position
			u.landing_progress = 0.0
		else:
			return false
	if u.air_state == "landing":
		var duration: float = maxf(2.0, u.landing_start.distance_to(touchdown) / maxf(u.speed, 1.0))
		u.landing_progress = minf(1.0, u.landing_progress + delta / duration)
		var dir: Vector3 = touchdown - u.landing_start
		u.heading = lerp_angle(u.heading, atan2(dir.x, dir.z), minf(1, delta * 2.5))
		u.node.position = u.landing_start.lerp(touchdown, u.landing_progress)
		u.node.position.y = maxf(u.node.position.y, world.height_at(u.node.position.x, u.node.position.z) + 1.2)
		u.node.basis = Basis(Vector3.UP, u.heading)
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
			if u.get("stay", false):
				u.air_state = "parked"
			else:
				_taxi_out(world, u)
		return true
	if u.air_state == "taxi_out":
		var runway := touchdown if vertical else on_base(world, base, Vector3(RUNWAY_X, 0, RUNWAY_START))
		u.taxi_progress = minf(1.0, u.taxi_progress + delta / (TAXI_SECONDS if not vertical else 0.01))
		var dir3: Vector3 = runway - u.taxi_from
		if dir3.length() > 0.1:
			u.heading = lerp_angle(u.heading, atan2(dir3.x, dir3.z), minf(1, delta * 4.0))
		u.node.position = u.taxi_from.lerp(runway, u.taxi_progress)
		u.node.basis = Basis(Vector3.UP, u.heading)
		u.moving = true
		if u.taxi_progress >= 1.0:
			u.air_state = "takeoff"
			if not vertical:
				u.heading = 0.0  # lined up along the runway (+z)
		return true
	if u.air_state == "takeoff":
		var next: Vector3 = u.node.position + Basis(Vector3.UP, u.heading) * Vector3.BACK * u.speed * delta
		if vertical:
			next = u.node.position + Vector3.UP * delta * 6.0
		var floor_y: float = maxf(world.height_at(next.x, next.z), float(world.map.seaLevel))
		next.y = maxf(next.y + delta * 5.0, floor_y + 1.2)
		u.node.position = next
		u.moving = true
		if next.y >= floor_y + u.altitude:
			u.air_state = "ready"
			u.orbit = u.node.position
		return true
	return false

static func _park(u: Dictionary) -> void:
	u.air_state = "rearming"
	u.service_left = SERVICE_SECONDS if int(u.ammo) < int(CAPACITY.get(u.key, 0)) else 0.5
	u.moving = false

static func _taxi_out(world: Node, u: Dictionary) -> void:
	u.air_state = "taxi_out"
	u.taxi_from = u.node.position
	u.taxi_progress = 0.0

static func goal(u: Dictionary) -> Variant:
	if u.air_base != null:
		return u.air_base.node.position - Vector3(0, 0, 85)
	return null
