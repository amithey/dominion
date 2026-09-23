extends RefCounted
## Ammunition is counted in firing passes / salvos, not individual submunitions.
const CAPACITY := {"jet": 4, "bomber": 3, "drone": 6, "helicopter": 8, "gunship": 8}
const SERVICE_SECONDS := 12.0

static func initialize(u: Dictionary) -> void:
	u.ammo = CAPACITY.get(u.key, 0)
	u.air_state = "ready"
	u.service_left = 0.0
	u.air_base = null
	u.egress = null

static func available(world: Node, u: Dictionary, b: Dictionary) -> bool:
	return not b.dead and b.built and b.owner == u.owner and b.get("supplied", true) and not world.disabled(b) and (b.key == "airfield" or (b.key == "helipad" and u.key in ["helicopter", "gunship"]))

static func base_for(world: Node, u: Dictionary) -> Variant:
	var best = null
	var distance := INF
	for b in world.buildings:
		if available(world, u, b):
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

## True means this update owns movement (landing, service, or takeoff).
static func update(world: Node, u: Dictionary, delta: float) -> bool:
	if u.air_state == "ready":
		return false
	var base = u.air_base
	if base == null or not available(world, u, base):
		base = base_for(world, u)
		u.air_base = base
		u.air_state = "returning" if base != null else "no base"
		u.service_left = 0.0
	if base == null:
		return false  # keep circling; no free replenishment without a working base
	var landing: Vector3 = base.node.position + Vector3.UP * 1.2
	if u.air_state == "returning":
		var approach: Vector3 = landing - Vector3(0, 0, 85)
		if Vector2(u.node.position.x-approach.x,u.node.position.z-approach.z).length() < 18.0:
			u.air_state = "landing"
			u.landing_start = u.node.position
			u.landing_progress = 0.0
		else:
			return false
	if u.air_state == "landing":
		var duration: float = maxf(2.0, u.landing_start.distance_to(landing) / maxf(u.speed,1.0))
		u.landing_progress = minf(1.0, u.landing_progress + delta/duration)
		var dir: Vector3 = landing-u.landing_start
		u.heading = lerp_angle(u.heading,atan2(dir.x,dir.z),minf(1,delta*2.5))
		u.node.position = u.landing_start.lerp(landing,u.landing_progress)
		u.node.position.y = maxf(u.node.position.y,world.height_at(u.node.position.x,u.node.position.z)+1.2)
		u.node.basis = Basis(Vector3.UP,u.heading)
		u.moving = true
		if u.landing_progress >= 1.0:
			u.air_state = "rearming"
			u.service_left = SERVICE_SECONDS
		return true
	if u.air_state == "rearming":
		u.moving = false
		u.service_left = maxf(0.0,u.service_left-delta)
		if u.service_left == 0:
			u.ammo = CAPACITY[u.key]
			u.air_state = "takeoff"
		return true
	if u.air_state == "takeoff":
		var next: Vector3 = u.node.position + Basis(Vector3.UP,u.heading)*Vector3.BACK*u.speed*delta
		var floor_y: float = maxf(world.height_at(next.x,next.z),float(world.map.seaLevel))
		next.y = maxf(next.y+delta*5.0,floor_y+1.2)
		u.node.position = next
		u.moving = true
		if next.y >= floor_y+u.altitude:
			u.air_state = "ready"
			u.air_base = null
		return true
	return false

static func goal(u: Dictionary) -> Variant:
	if u.air_base != null:
		return u.air_base.node.position-Vector3(0,0,85)
	return null
