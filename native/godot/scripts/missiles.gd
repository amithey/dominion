extends Node3D
## Missiles, ported from js/entities.js (MISSILES in config.js, through the map
## export). A Missile Silo builds munitions in its queue (tactical, cruise,
## cluster, EMP, anti-ship, ballistic, hypersonic, nuclear); they are stored up
## to 2 plus 4 per Ammo Depot. The player picks a missile and clicks a target:
## it launches from the nearest silo, cruise types fly low and dive, ballistic
## types climb on a high arc, and on impact everything within the blast radius
## takes damage falling off to half at the edge.
## Specials: cluster shreds units but barely hurts buildings, anti-ship
## triples against ships, EMP disables vehicles, aircraft, ships and
## buildings for 35 s. Striking a nation you are at peace with is an act of
## war. A nuclear strike leaves a mushroom cloud, wrecks roads across the
## blast, and the whole world turns on you (-30 relations with everyone).
## As in the browser, anti-ship missiles need Naval Engineering, ballistic and
## hypersonic missiles Ballistic Technology, nukes the Nuclear Program.

signal changed


var world: Node
var cfg: Dictionary
var stock := {}
var flying: Array = []   # {type, node, from, to, t, dur, arc, trail}
var clock := 0.0
var transfers: Array = []
var unassigned := {}
var next_transfer_id := 1
var logistics_revision := 0
var _logistics_step := 0.0
const Air := preload("res://scripts/air_operations.gd")
const Costs := preload("res://scripts/war_costs.gd")
const PORTS := ["port", "shipyard"]
const DOCK_REACH := 38.0
const TACTICAL_SHIPS := ["destroyer", "aegisCruiser"]
const AIR_LAUNCHERS := ["jet", "bomber", "stealthFighter", "raider"]
# Release distances in map units, tuned independently of the damage radius.
const AIR_RELEASE_RANGE := {
	"bunkerBuster": 11.0, "tsarBomba": 11.0, "tacticalNuke": 36.0,
	"antiRadar": 62.0, "bunkerMissile": 48.0, "antiShip": 56.0,
	"cruise": 72.0, "nuclearCruise": 80.0,
}

func setup(world_node: Node, missiles: Dictionary) -> void:
	world = world_node
	cfg = missiles
	for key in cfg.types:
		stock[key] = 0

func types() -> Dictionary:
	return cfg.types

func def_of(key: String) -> Dictionary:
	return cfg.types.get(key, preload("res://scripts/national_arsenal.gd").MISSILES.get(key, preload("res://scripts/faction_arsenal.gd").MISSILES.get(key, {})))

## Where each weapon is made: conventional missiles at a Missile Silo, nuclear
## warheads at a Strategic Weapons Complex, chemical, biological and
## radiological weapons at a Special Weapons Laboratory. Each kind has its own
## storage; all of them launch from a silo (or a missile ship).
const FACILITY := {"conventional": "missileSilo", "nuclear": "strategicComplex", "special": "specialLab"}
const PER_FACILITY := 2      # nuclear or special weapons each facility can hold

func category(key: String) -> String:
	var def := def_of(key)
	if def.get("nuclear", key == "nuke"):
		return "nuclear"
	if str(def.get("special", "")) in ["dirty", "chemical", "chlorine", "riot", "incapacitant", "anthrax", "bio"]:
		return "special"
	return "conventional"

func facility_of(key: String) -> String:
	return FACILITY[category(key)]

func local_weapon(key: String) -> bool:
	return key == "tactical" or category(key) == "nuclear"

func _alive(entity) -> bool:
	return entity != null and not entity.dead and is_instance_valid(entity.node)

func _active(entity, owner: int) -> bool:
	return _alive(entity) and entity.owner == owner and entity.get("built", true) and not world.disabled(entity)

func _manifest(entity: Dictionary) -> Dictionary:
	if int(entity.get("payload_owner", -1)) != int(entity.owner):
		entity.payload_owner = entity.owner
		entity.payloads = {}
	return entity.get_or_add("payloads", {})

func local_count(entity: Dictionary, key: String) -> int:
	if entity.get("payload_owner") != entity.owner:
		return 0
	return int(entity.get("payloads", {}).get(key, 0))

func total_for(key: String, owner := 0) -> int:
	if not local_weapon(key):
		return int(stock.get(key, 0)) if owner == 0 else 0
	var total := int(unassigned.get(key, 0)) if owner == 0 else 0
	for entity in world.buildings + world.units:
		if not entity.dead and entity.owner == owner and entity.has("payloads"):
			total += local_count(entity, key)
	for job in transfers:
		if job.owner == owner and job.key == key:
			total += int(job.count)
	return total

func storage_accepts(entity: Dictionary, key: String) -> bool:
	if not local_weapon(key):
		return false
	if not entity.get("is_building", false):
		return _other_platforms_for(key, int(entity.owner), true).any(func(p): return is_same(p, entity))
	if entity.key in PORTS or entity.key == facility_of(key):
		return true
	if entity.key == "missileSilo" or (key == "tactical" and entity.key == "ammoDepot"):
		return true
	return entity.key == "airfield" and load("res://scripts/arsenal_catalog.gd").platform_kind(world, entity.owner, key) in ["air", "air_or_sea"]

func storage_slots(entity: Dictionary) -> int:
	match entity.key:
		"strategicComplex", "airfield": return 2
		"missileSilo", "ammoDepot", "shipyard", "port": return 4
	return 2 if entity.key == "nuclearSub" else 1

func free_storage(entity: Dictionary) -> int:
	var used := 0
	for count in _manifest(entity).values():
		used += int(count)
	if entity.get("is_building", false):
		for entry in entity.queue:
			if String(entry).begins_with("missile:") and local_weapon(String(entry).substr(8)):
				used += 1
	for job in transfers:
		if job.owner == entity.owner and (is_same(job.destination, entity) or (job.loading and is_same(job.source, entity))):
			used += int(job.count)
	return maxi(0, storage_slots(entity) - used)

func has_local_storage(entity: Dictionary) -> bool:
	return entity.key in ["strategicComplex", "missileSilo", "ammoDepot", "airfield"] + PORTS

func asset_name(entity: Dictionary) -> String:
	if entity.get("is_building", false):
		return str(entity.def.name)
	return str(world.unit_defs.get(entity.key, {}).get("name", entity.key))

func _dock_near(ship: Dictionary, port: Dictionary) -> bool:
	return Air.distance(ship.node.position, port.node.position) <= DOCK_REACH

func _supplied(entity: Dictionary) -> bool:
	return entity.get("supplied", true)

func _at_service(unit: Dictionary, facility: Dictionary) -> bool:
	if unit.get("naval", false):
		return facility.key in PORTS and _dock_near(unit, facility) and not unit.get("moving", false) and unit.target == null and unit.enemy == null
	return unit.get("fly", false) and unit.air_state == "parked" and is_same(unit.get("air_base"), facility)

func transfer_blocked(source: Dictionary, destination: Dictionary, key: String, count := 1) -> String:
	if not _active(source, int(source.owner)) or not _active(destination, int(source.owner)) or is_same(source, destination):
		return "Choose two different operational facilities or units of your nation."
	if count <= 0 or local_count(source, key) < count:
		return "That quantity is no longer available."
	if not storage_accepts(destination, key):
		return "Destination cannot hold this weapon."
	if free_storage(destination) < count:
		return "Destination storage is full or reserved."
	var from_unit := not bool(source.get("is_building", false))
	var to_unit := not bool(destination.get("is_building", false))
	if from_unit and to_unit:
		return "Unload at a compatible facility first."
	if not _supplied(source) or not _supplied(destination):
		return "Supply route unavailable."
	if (from_unit or to_unit) and not _at_service(source if from_unit else destination, destination if from_unit else source):
		return "Stop the ship at a friendly port or park the aircraft at its airfield."
	return ""

func transfer_duration(source: Dictionary, destination: Dictionary, count: int) -> float:
	if not (source.get("is_building", false) and destination.get("is_building", false)):
		return 7.0 + count * 2.0
	return 8.0 + Air.distance(source.node.position, destination.node.position) / 16.0

func _changed_logistics() -> void:
	logistics_revision += 1
	changed.emit()

func start_transfer(source: Dictionary, destination: Dictionary, key: String, count := 1) -> String:
	var reason := transfer_blocked(source, destination, key, count)
	if reason != "":
		return reason
	var loading: bool = not (source.get("is_building", false) and destination.get("is_building", false))
	var position: Vector3 = source.node.position
	var time := transfer_duration(source, destination, count)
	_manifest(source)[key] = local_count(source, key) - count
	transfers.append({"id": next_transfer_id, "key": key, "owner": source.owner, "count": count,
		"source": source, "destination": destination, "start": position, "position": position,
		"remaining": time, "duration": time, "loading": loading, "status": "Handling"})
	next_transfer_id += 1
	_changed_logistics()
	return ""

func transfer_job(id: int) -> Variant:
	for job in transfers:
		if job.id == id:
			return job
	return null

func redirect_transfer(job: Dictionary, destination: Dictionary) -> String:
	if job.loading or not transfers.has(job) or not _active(destination, int(job.owner)) or not destination.get("is_building", false):
		return "Choose an operational storage facility."
	if is_same(job.destination, destination):
		return "Shipment already assigned to this facility."
	if not storage_accepts(destination, job.key) or free_storage(destination) < job.count or not _supplied(destination):
		return "Destination cannot accept the shipment."
	job.destination = destination
	job.start = job.position
	job.duration = 8.0 + Air.distance(job.position, destination.node.position) / 16.0
	job.remaining = job.duration
	_changed_logistics()
	return ""

func _end_transfer(job: Dictionary, receiver) -> void:
	transfers.erase(job)
	var delivered: bool = _alive(receiver) and receiver.owner == job.owner
	if delivered:
		_manifest(receiver)[job.key] = local_count(receiver, job.key) + int(job.count)
	if job.owner == 0 and world.hud != null:
		var status := "at " + asset_name(receiver) if delivered else "shipment lost"
		world.hud.notice("%s x%d: %s." % [def_of(job.key).name, job.count, status])
	_changed_logistics()

func cancel_transfer(job: Dictionary) -> String:
	if not transfers.has(job):
		return "Shipment already finished."
	if job.loading or (job.remaining >= job.duration and _alive(job.source) and free_storage(job.source) >= job.count):
		_end_transfer(job, job.source)
		return ""
	if _alive(job.source):
		return redirect_transfer(job, job.source)
	return "Source unavailable. Redirect the shipment to another facility."

func abandon_transfer(job: Dictionary) -> void:
	if transfers.has(job):
		_end_transfer(job, null)

func assign_legacy(key: String, destination: Dictionary) -> String:
	if int(unassigned.get(key, 0)) <= 0 or not _active(destination, 0) or not destination.get("is_building", false):
		return "No unassigned weapon or destination unavailable."
	if not storage_accepts(destination, key) or free_storage(destination) <= 0:
		return "No compatible storage space."
	unassigned[key] -= 1
	_manifest(destination)[key] = local_count(destination, key) + 1
	_changed_logistics()
	return ""

func _update_transfers(delta: float) -> void:
	for job in transfers.duplicate():
		var source = job.source
		var destination = job.destination
		if job.loading:
			if not _alive(source) or source.owner != job.owner:
				_end_transfer(job, null)
				continue
			if not _alive(destination) or destination.owner != job.owner:
				_end_transfer(job, source)
				continue
			var from_site: bool = source.get("is_building", false)
			if not _at_service(destination if from_site else source, source if from_site else destination):
				_end_transfer(job, source)
				continue
			if not _active(source, job.owner) or not _supplied(source):
				job.status = "Service paused"
				continue
		if not _active(destination, job.owner) or not _supplied(destination):
			job.status = "Destination unavailable"
			continue
		if not job.loading and _alive(source) and source.owner == job.owner and not _supplied(source):
			job.status = "Supply route cut"
			continue
		job.status = "Loading" if job.loading else "In transit"
		job.remaining -= delta
		job.position = job.start.lerp(destination.node.position, clampf(1.0 - job.remaining / job.duration, 0.0, 1.0))
		if job.remaining <= 0.0:
			_end_transfer(job, destination)

func capacity(cat := "conventional") -> int:
	if cat == "conventional":
		return int(cfg.baseCap) + int(cfg.capPerDepot) * world.economy.owned("ammoDepot")
	return PER_FACILITY * world.economy.owned(FACILITY[cat])

func stored(cat := "conventional", pooled_only := false) -> int:
	# Every kind that is held anywhere: the shared pool, and the weapons kept where they are (a silo, a port, a
	# platform, one being carried, one not yet assigned). Those never enter the pool, so the pool alone undercounts.
	var keys := {}
	for key in stock:
		keys[key] = true
	if not pooled_only:
		for key in unassigned:
			keys[key] = true
		for job in transfers:
			keys[job.key] = true
		for entity in world.buildings + world.units:
			if not entity.dead and entity.owner == 0 and entity.has("payloads"):
				for key in entity.payloads:
					keys[key] = true
	var n := 0
	for key in keys:
		if category(key) == cat and (not pooled_only or not local_weapon(key)):
			n += total_for(key)
	return n

func queued(cat := "conventional", pooled_only := false) -> int:
	var n := 0
	for b in world.buildings:
		if b.owner == 0 and not b.dead:
			for item in b.queue:
				if not String(item).begins_with("missile:"):
					continue
				var key := String(item).substr(8)
				if category(key) == cat and (not pooled_only or not local_weapon(key)):
					n += 1
	return n

## The weapons a facility lists: its own kind, not hidden, and not another
## nation's (a weapon you could have with research or a building is listed, locked).
func listed_at(building_key: String) -> Array:
	return types().keys().filter(func(k):
		if def_of(k).get("hidden", false) or facility_of(k) != building_key:
			return false
		var lock := locked(k)
		return not (lock.begins_with("Not fielded") or (lock != "" and preload("res://scripts/national_arsenal.gd").foreign(world, def_of(k).get("nation", "")) != "" and not preload("res://scripts/cbrn_data.gd").CAPABILITY.has(k))))

## "" when the player may build this type, otherwise the discovery it needs.
func locked(key: String) -> String:
	if not types().has(key) or def_of(key).get("hidden", false):
		return "Unavailable payload"
	var national: String = load("res://scripts/arsenal_catalog.gd").missile_blocked(world, 0, key)
	if national != "": return national
	var wmd = world.get("wmd")
	var cbrn: bool = preload("res://scripts/cbrn_data.gd").CAPABILITY.has(key)
	if cbrn and wmd != null:
		var why: String = wmd.capability_blocked(key)   # who really has it (cbrn_data.gd)
		if why != "":
			return why
	else:
		var only: String = "" if world.map.nations[0].has("missiles") and key in world.map.nations[0].missiles else preload("res://scripts/national_arsenal.gd").foreign(world, def_of(key).get("nation", ""))
		if only != "":
			return only   # e.g. nuclear weapons outside the nuclear powers
	if wmd != null and 0 in wmd.broken_out and key in ["nuke", "tacticalNuke", "nuclearEmp"]:
		return ""   # a nuclear breakout skips the Nuclear Program
	if category(key) == "nuclear" and world.research != null and not world.research.done("nuclearProgram"):
		return "Needs Nuclear Program"
	var need: String = def_of(key).get("needsDiscovery", "")
	if need != "" and world.research and not world.research.done(need):
		return "Needs %s" % world.research.def_of(need).get("name", need)
	return ""

## Ships that carry and fire missiles from the nation's stockpile: the
## strategic submarine and the destroyer (the missile ship).
const LAUNCH_SHIPS := ["nuclearSub", "destroyer", "missileBoat"]

## Missile ships of `owner` able to fire (alive, not disabled).
func launch_ships(owner := 0) -> Array:
	return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in LAUNCH_SHIPS and not world.disabled(u))

func silos(owner := 0) -> Array:
	return world.buildings.filter(func(b): return b.owner == owner and b.key == "missileSilo" and b.built and not b.dead)

## Payload-specific launch validation, shared by human and rival attacks.
func platforms_for(key: String, owner := 0) -> Array:
	# Fast boats add only their conventional anti-ship capability; their
	# presence must never become a strategic or land-attack launch platform.
	if key == "antiShip":
		var boats: Array = world.units.filter(func(u): return u.owner == owner and not u.dead and u.key == "missileBoat" and not world.disabled(u))
		if not boats.is_empty():
			return boats + _other_platforms_for(key, owner)
	return _other_platforms_for(key, owner)

func ready_platforms(key: String, owner := 0) -> Array:
	var local := local_weapon(key)
	return platforms_for(key, owner).filter(func(p):
		if p.has("payload_order") or (local and local_count(p, key) <= 0):
			return false
		if p.get("fly", false) and p.air_state == "parked":
			var base = p.get("air_base")
			return base != null and Air.available(world, p, base)
		return true)

func pooled_available(key: String) -> int:
	var count := int(stock.get(key, 0))
	if count > 0:
		for unit in world.units:
			if not unit.dead and unit.owner == 0 and unit.has("payload_order") and unit.payload_order.key == key:
				count -= 1
	return maxi(0, count)

func _other_platforms_for(key: String, owner: int, storage := false) -> Array:
	var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key)
	if key == "tactical" and kind == "ground":
		return _sites(owner, key) + world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in TACTICAL_SHIPS and (storage or not world.disabled(u)))
	if kind == "air":
		# In the air or waiting at its airfield (it takes off with the missile); not one being rearmed or landing.
		return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in AIR_LAUNCHERS and (storage or (not world.disabled(u) and u.get("air_state", "ready") in ["ready", "parked"])))
	if kind == "drone":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in ["drone", "fpvTeam"] and not world.disabled(u) and u.get("air_state", "ready") == "ready")
	if kind == "air_or_sea":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and (u.key in ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"] or (u.key in AIR_LAUNCHERS and (storage or u.get("air_state", "ready") in ["ready", "parked"]))))
	if kind in ["sea", "sub"]:
		return world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and u.key in (["nuclearSub"] if kind == "sub" or category(key) == "nuclear" else ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"]))
	if kind in ["strategic", "ground_or_sea"]:
		var ships: Array = world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and u.key in (["nuclearSub"] if kind == "strategic" else ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"]))
		return _sites(owner, key) + ships
	return _sites(owner, key)

## The buildings that launch `key`: a missile silo, and for a nuclear or special weapon also the facility
## that holds it (a nation with a strategic complex but no silo could not fire its own bombs).
func _sites(owner: int, key: String) -> Array:
	var keys := ["missileSilo"]
	if category(key) == "nuclear": keys.append("strategicComplex")
	if category(key) == "special": keys.append("specialLab")
	return world.buildings.filter(func(b): return b.owner == owner and b.key in keys and b.built and not b.dead and not world.disabled(b))

## In plain words, what launches `key` for `owner` ("a Jet, Bomber, Stealth Fighter or Raider").
func launchers_text(key: String, owner := 0) -> String:
	var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key)
	if key == "tactical" and kind == "ground": return "a missile silo, destroyer or Aegis cruiser"
	var named := func(b: String) -> String: return str(world.building_defs.get(b, {}).get("name", b))
	var site: String = "a " + named.call("missileSilo") + (" or a " + named.call("strategicComplex") if category(key) == "nuclear" else (" or a " + named.call("specialLab") if category(key) == "special" else ""))
	match kind:
		"air": return "an aircraft: a Jet, Bomber, Stealth Fighter or Raider (at its airfield or in the air)"
		"drone": return "a Drone or an FPV team"
		"air_or_sea": return "an aircraft (Jet, Bomber, Stealth Fighter, Raider) or a warship (Destroyer, Corvette, Cruiser, Submarine)"
		"sub": return "a nuclear submarine"
		"sea": return "a nuclear submarine" if category(key) == "nuclear" else "a warship: a Destroyer, Corvette, Cruiser or Submarine"
		"strategic": return site + " or a nuclear submarine"
		"ground_or_sea": return site + ", or a warship (Destroyer, Corvette, Cruiser, Submarine)"
	return site

## Why `key` cannot be launched now for want of a launcher, in words ("" when it can).
func launcher_missing(key: String, owner := 0) -> String:
	if not ready_platforms(key, owner).is_empty():
		return ""
	if local_weapon(key) and not platforms_for(key, owner).is_empty():
		return "No compatible launcher is loaded with %s." % def_of(key).name
	return "%s is fired from %s. You have none ready." % [def_of(key).get("name", key), launchers_text(key, owner)]

func available_to(owner: int, key: String) -> bool:
	if not types().has(key) or def_of(key).get("hidden", false): return false
	if load("res://scripts/arsenal_catalog.gd").missile_blocked(world, owner, key) != "": return false
	if preload("res://scripts/cbrn_data.gd").CAPABILITY.has(key):
		return preload("res://scripts/cbrn_data.gd").has(world, owner, key)
	if world.map.nations[owner].has("missiles"):
		return key in world.map.nations[owner].missiles
	return preload("res://scripts/national_variants.gd").admits(def_of(key).get("nation", ""), preload("res://scripts/national_arsenal.gd").identity(world, owner))

## Queues a missile at `silo`. Returns an error or "".
func produce(silo: Dictionary, key: String) -> String:
	var def := def_of(key)
	if int(silo.get("owner", -1)) != 0:
		return "Cannot produce at another nation's facility."
	if def.is_empty() or not silo.built or silo.dead:
		return ""
	var why := locked(key)
	if why != "":
		return "%s: %s." % [def.name, why.to_lower()]
	if silo.key != facility_of(key):
		return "%s is made at a %s." % [def.name, world.building_defs.get(facility_of(key), {}).get("name", facility_of(key))]
	if silo.queue.size() >= 5:
		return "Queue is full"
	var cat := category(key)
	if local_weapon(key) and free_storage(silo) <= 0:
		return "Storage at this facility is full or reserved."
	if not local_weapon(key) and stored(cat, true) + queued(cat, true) >= capacity(cat):
		if cat == "conventional":
			return "Missile storage full (%d). Build Ammo Depots for +%d each." % [capacity(), int(cfg.capPerDepot)]
		return "Storage full (%d): each %s holds %d." % [capacity(cat), world.building_defs.get(FACILITY[cat], {}).get("name", ""), PER_FACILITY]
	var price := production_cost(key)
	if not world.economy.pay(price):
		return "Not enough %s" % world.economy.missing(price)
	world.queue_paid_order(silo, "missile:" + key, price)
	changed.emit()
	return ""

func queue_rival_payload(owner: int, key: String) -> bool:
	if owner <= 0 or not local_weapon(key) or not available_to(owner, key) or total_for(key, owner) >= 3:
		return false
	for facility in world.buildings:
		if not _active(facility, owner) or facility.key != facility_of(key) or not _supplied(facility) or free_storage(facility) <= 0 or facility.queue.size() >= 5:
			continue
		if facility.queue.has("missile:" + key):
			return false
		var cost := float(def_of(key).get("cost", {}).get("money", 400.0))
		if not Costs.pay(world, owner, cost):
			return false
		world.queue_paid_order(facility, "missile:" + key, {"money": cost})
		return true
	return false

func deploy_rival_payload(owner: int, key: String) -> void:
	if owner <= 0 or not local_weapon(key) or transfers.any(func(job): return job.owner == owner and job.key == key):
		return
	var platforms := _other_platforms_for(key, owner, true)
	for platform in platforms:
		if platform.get("is_building", false) or local_count(platform, key) > 0:
			continue
		var depot = platform.get("air_base")
		if platform.get("naval", false):
			for port in world.buildings:
				if _active(port, owner) and port.key in PORTS and _supplied(port):
					depot = port
					if _dock_near(platform, port):
						break
		if depot == null or not _active(depot, owner):
			continue
		if local_count(depot, key) > 0:
			if start_transfer(depot, platform, key) == "":
				return
			if platform.get("naval", false) and not _dock_near(platform, depot) and platform.target == null and platform.enemy == null:
				var dock = world.water_near(depot.node.position, int(DOCK_REACH))
				if dock is Vector3:
					world.order_move([platform], dock)
			continue
		for source in world.buildings:
			# Keep a reserve at a production site that can also launch the weapon.
			var reserve := 1 if platforms.has(source) else 0
			if _active(source, owner) and local_count(source, key) > reserve and start_transfer(source, depot, key) == "":
				return

func production_cost(key: String) -> Dictionary:
	var price := {}
	var cost: Dictionary = def_of(key).get("cost", {})
	for resource in cost:
		price[resource] = roundf(float(cost[resource]) * preload("res://scripts/national_profile.gd").cost_mult(world, 0, "missile"))
	return price

## Called by world.update_training when a silo finishes one.
func finished(key: String, facility: Dictionary) -> void:
	if local_weapon(key):
		_manifest(facility)[key] = local_count(facility, key) + 1
		_changed_logistics()
	else:
		stock[key] = int(stock.get(key, 0)) + 1
		changed.emit()
	if facility.owner == 0 and world.hud != null:
		world.hud.notice("%s ready at %s." % [def_of(key).name, asset_name(facility)])

func build_time(key: String) -> float:
	return float(def_of(key).get("buildTime", 20))

# ---------------------------------------------------------------- launching

## Fires `key` at `target` from `platform` (a silo or a missile ship), or
## from the platform nearest the target when none is given.
func launch(key: String, target: Vector3, platform = null) -> String:
	var result := launch_from(key, target, 0, platform)
	if result.has("error"):
		return result.error
	return "%s mission assigned." % def_of(key).name if result.get("pending", false) else "%s launched." % def_of(key).name

func _target_blocked(key: String, target: Vector3) -> String:
	if not target.is_finite():
		return "Invalid target."
	if def_of(key).get("sub_only", false) and world.water_near(target, 40) == null:
		return "%s needs a target on or near the sea." % def_of(key).name
	return ""

func _ready_key(key: String, owner: int) -> bool:
	return locked(key) == "" if owner == 0 else available_to(owner, key)

func launch_from(key: String, target: Vector3, owner: int, platform = null, automated_release := false) -> Dictionary:
	if not _ready_key(key, owner):
		return {"error": locked(key) if owner == 0 else "Weapon unavailable."}
	if owner == 0 and category(key) == "nuclear" and not automated_release and world.get("defcon") != null and world.defcon.release_blocked() != "":
		return {"error": world.defcon.release_blocked()}
	var reason := _target_blocked(key, target)
	if reason != "":
		return {"error": reason}
	if owner == 0 and not local_weapon(key) and pooled_available(key) <= 0:
		return {"error": "No unreserved %s in storage." % def_of(key).name}
	var platforms := ready_platforms(key, owner)
	if platform != null:
		if not platforms.any(func(p): return is_same(p, platform)):
			return {"error": "Selected platform cannot launch this weapon: incompatible, disabled or empty."}
		return _launch_ready(key, target, platform, automated_release)
	if platforms.is_empty():
		return {"error": launcher_missing(key, owner)}
	platforms.sort_custom(func(a, b): return a.node.position.distance_squared_to(target) < b.node.position.distance_squared_to(target))
	var result := {}
	for candidate in platforms:
		result = _launch_ready(key, target, candidate, automated_release)
		if not result.has("error"):
			break
	return result

func release_range(key: String, platform: Dictionary) -> float:
	return float(AIR_RELEASE_RANGE.get(key, maxf(12.0, Air.attack_release_range(platform))))

func _launch_ready(key: String, target: Vector3, platform: Dictionary, automated_release: bool) -> Dictionary:
	if platform.get("fly", false):
		var reason := Air.mission_blocked(world, platform, target, 4.0, release_range(key, platform))
		if reason != "":
			return {"error": reason}
		platform.erase("patrol")
		platform.payload_order = {"key": key, "target": target, "automatic": automated_release}
		platform.target = target
		platform.enemy = null
		platform.egress = null
		platform.attack_move = false
		_changed_logistics()
		return {"pending": true}
	return _fire_loaded(key, target, platform)

func _fire_loaded(key: String, target: Vector3, platform: Dictionary) -> Dictionary:
	var owner: int = platform.owner
	if local_weapon(key):
		_manifest(platform)[key] = local_count(platform, key) - 1
	elif owner == 0:
		stock[key] -= 1
	var mobile: bool = not platform.get("is_building", false)
	var projectile := fly(key, platform.node.position + Vector3.UP * (1.5 if mobile else 3.0), target, owner, mobile)
	_changed_logistics()
	return projectile

func _update_air_payloads() -> void:
	for u in world.units:
		if u.dead or not u.has("payload_order"):
			continue
		var order: Dictionary = u.payload_order
		var target: Vector3 = order.target
		var key: String = order.key
		if u.air_state in ["returning", "no base", "landing"] or not _ready_key(key, u.owner):
			u.erase("payload_order")
			u.target = null
			if u.air_state == "ready":
				Air.return_to_base(u)
			_changed_logistics()
			continue
		if u.air_state != "ready" or world.disabled(u) or Air.distance(u.node.position, target) > release_range(key, u):
			continue
		var release: bool = category(key) != "nuclear" or u.owner != 0 or order.automatic or world.get("defcon") == null or world.defcon.release_blocked() == ""
		var loaded: bool = local_count(u, key) > 0 if local_weapon(key) else u.owner != 0 or int(stock.get(key, 0)) > 0
		if release and loaded and _target_blocked(key, target) == "" and Air.mission_blocked(world, u, target, 0.0, release_range(key, u)) == "":
			_fire_loaded(key, target, u)
		elif u.owner == 0 and world.hud != null:
			world.hud.notice("Release cancelled. Aircraft returning with its payload.")
		u.erase("payload_order")
		Air.return_to_base(u)
		_changed_logistics()

## A missile in the air from `from` to `target`, fired by `owner` (rivals'
## strikes come through here too: ai.gd).
func fly(key: String, from: Vector3, target: Vector3, owner: int, ship := false) -> Dictionary:
	var def := def_of(key)
	target.y = maxf(world.height_at(target.x, target.z), float(world.map.seaLevel))
	var dist := Vector2(target.x - from.x, target.z - from.z).length()
	var arc: bool = def.get("arc", false)
	var node := missile_mesh(key)
	add_child(node)
	node.global_position = from
	var m := {"type": key, "node": node, "from": from, "to": target, "t": 0.0, "owner": owner,
		"dur": clampf(dist / float(def.speed), 2.5, 9.0) if arc else maxf(0.6, dist / float(def.speed)) + 1.0,
		"arc": arc, "trail": 0.0, "peak": maxf(60.0, dist * 0.45)}
	flying.append(m)
	world.effects.explosion(from, 1.2, not ship)
	if not ship:
		world.effects.burn(from, 6.0)
	return m

func position_at(m: Dictionary, f: float) -> Vector3:
	var from: Vector3 = m.from
	var to: Vector3 = m.to
	var flat := from.lerp(to, f)
	if m.arc:
		flat.y = lerpf(from.y, to.y, f) + 4.0 * m.peak * f * (1.0 - f)
	else:
		# Cruise: climb out, fly low over the land, dive in the last stretch.
		var cruise := maxf(world.height_at(flat.x, flat.z), float(world.map.seaLevel)) + 16.0
		var climb := smoothstep(0.0, 0.18, f)
		var dive := smoothstep(0.82, 1.0, f)
		flat.y = lerpf(lerpf(from.y, cruise, climb), to.y, dive)
	return flat

func _physics_process(delta: float) -> void:
	_logistics_step += delta
	if _logistics_step >= 0.25:
		_update_transfers(_logistics_step)
		_update_air_payloads()
		_logistics_step = 0.0
	if world == null:
		return
	clock += delta
	for i in range(flying.size() - 1, -1, -1):
		var m: Dictionary = flying[i]
		m.t += delta
		# A missile is not at one speed all the way: it lifts off slowly on its booster and gathers speed, and a
		# ballistic one comes down far faster than it went up. `f` stays the share of the path flown.
		var u: float = minf(m.t / m.dur, 1.0)
		var f: float = (0.45 * u + 0.55 * u * u) if m.arc else u * (0.8 + 0.2 * u)
		var node: Node3D = m.node
		var p := position_at(m, f)
		if preload("res://scripts/air_defence.gd").intercept(world, m, p, f):
			node.queue_free()
			flying.remove_at(i)
			continue
		var ahead := position_at(m, minf(f + 0.01, 1.0))
		node.global_position = p
		if ahead.distance_to(p) > 0.01:
			node.look_at(ahead, Vector3.UP if absf((ahead - p).normalized().y) < 0.98 else Vector3.RIGHT)
		m.trail += delta
		if m.trail > 0.06:
			m.trail = 0.0
			world.effects.trail(p - (ahead - p).normalized() * 1.5)
		if f >= 1.0:
			node.queue_free()
			flying.remove_at(i)
			impact(m.type, m.to, m.owner, m.from)

func impact(key: String, at: Vector3, owner: int, from := Vector3.INF) -> void:
	var def := def_of(key)
	var radius := float(def.radius)
	var special: String = def.get("special", "")
	var nuclear: bool = key == "nuke" or def.get("nuclear", false)
	if special == "antiRadar":
		at = preload("res://scripts/conventional_missiles.gd").home(world, at, owner)   # it rides the nearest air-defence radar's beam
	# The burst itself is the warhead's profile (firepower.gd): the explosion, the roads, who is struck and how hard.
	var hit: Array = preload("res://scripts/firepower.gd").strategic(world, key, def, at, owner)
	# What lasts: fallout, a gas cloud, an outbreak, a blackout (wmd.gd).
	var struck_by := []
	for ent in hit:
		if int(ent.owner) != owner and not int(ent.owner) in struck_by:
			struck_by.append(int(ent.owner))
	if world.get("wmd") != null and world.wmd != null:
		if special == "hemp":
			for b in world.buildings:
				if not b.dead and int(b.owner) != owner and not int(b.owner) in struck_by and b.root.position.distance_to(at) <= radius:
					struck_by.append(int(b.owner))
		world.wmd.after_impact(key, at, owner, from, struck_by)
	# The escalation ladder (defcon.gd): who was struck, and with what.
	if world.get("defcon") != null and world.defcon != null:
		var struck: Array = struck_by
		if nuclear:
			world.defcon.nuclear_used(owner, struck)
		else:
			world.defcon.struck(key, struck)
	if nuclear and owner == 0:
		for i in range(1, world.diplomacy.n):
			if not world.diplomacy.defeated(i):
				world.diplomacy.change(0, i, -30.0)
		world.diplomacy.changed.emit()
		world.hud.notice("The world condemns your nuclear strike. Relations with every nation fall by 30.")

# ---------------------------------------------------------------- models

func _part(parent: Node3D, mesh: PrimitiveMesh, colour: Color, at: Vector3, rot := Vector3.ZERO, glow := false) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.45
	mat.metallic = 0.3
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = colour
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)

func _cyl(r: float, h: float, r_top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	return c

func _fin(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

## A missile modelled along -Z (the direction look_at points it).
func missile_mesh(key: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.rotation.x = -PI * 0.5   # cylinders stand on Y; lay them along -Z
	root.add_child(body)
	var team := Color(world.map.nations[0].color)
	var arc: bool = def_of(key).get("arc", false)
	var k := 1.0 if not arc else (1.8 if key == "nuke" else 1.5)
	var hull := Color("f2f4f6") if key == "nuke" else (Color("b9c2cc") if arc else Color("d8dde2"))
	var nose := Color("d12b2b") if key == "nuke" else team
	var length := 2.8 * k
	var r := 0.28 * k
	_part(body, _cyl(r, length), hull, Vector3.ZERO)
	_part(body, _cyl(r, 0.9 * k, 0.02), nose, Vector3(0, length * 0.5 + 0.45 * k, 0))
	if key == "nuke":
		_part(body, _cyl(r * 1.05, 0.3), Color("d12b2b"), Vector3(0, length * 0.2, 0))
		_part(body, _cyl(r * 1.05, 0.3), Color("1c1f24"), Vector3(0, -length * 0.3, 0))
	for j in range(4):
		var a := j * PI * 0.5
		var fin := Vector3(cos(a), 0, sin(a)) * r
		_part(body, _fin(Vector3(0.42 * k if j % 2 == 0 else 0.04, 0.55 * k, 0.04 if j % 2 == 0 else 0.42 * k)), nose if arc else team, fin * 1.6 + Vector3(0, -length * 0.4, 0))
	if not arc:
		_part(body, _fin(Vector3(1.8 * k, 0.35 * k, 0.06)), hull.darkened(0.15), Vector3(0, 0.1, 0))
	_part(body, _cyl(r * 0.9, 0.5, r * 0.4), Color(1.0, 0.7, 0.3), Vector3(0, -length * 0.5 - 0.25, 0), Vector3.ZERO, true)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position = Vector3(0, 0, length * 0.6)
	root.add_child(light)
	body.scale = Vector3.ONE * 2.2  # readable at RTS distance, like the units
	return root

# ---------------------------------------------------------------- saving

func _save_entity(entity, buildings: Array, units: Array) -> Variant:
	if not _alive(entity):
		return null
	var building: bool = entity.get("is_building", false)
	var group := buildings if building else units
	for i in range(group.size()):
		if is_same(group[i], entity):
			return {"building": building, "index": i}
	return null

func _load_entity(reference, buildings: Array, units: Array) -> Variant:
	if reference == null:
		return null
	var group := buildings if reference.building else units
	var index := int(reference.index)
	return group[index] if index >= 0 and index < group.size() else null

func _save_point(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func _load_point(point: Array) -> Vector3:
	return Vector3(point[0], point[1], point[2])

func _capture_logistics(buildings: Array, units: Array) -> Dictionary:
	var payloads := []
	for entity in buildings + units:
		var manifest: Dictionary = _manifest(entity) if entity.has("payloads") else {}
		if manifest.values().any(func(count): return int(count) > 0) or entity.has("payload_order"):
			var row := {"entity": _save_entity(entity, buildings, units), "stock": manifest.duplicate()}
			if entity.has("payload_order"):
				var order: Dictionary = entity.payload_order
				row.order = {"key": order.key, "target": _save_point(order.target), "automatic": order.automatic}
			payloads.append(row)
	var shipments := []
	for job in transfers:
		shipments.append({"id": job.id, "key": job.key, "owner": job.owner, "count": job.count,
			"source": _save_entity(job.source, buildings, units), "destination": _save_entity(job.destination, buildings, units),
			"start": _save_point(job.start), "position": _save_point(job.position), "remaining": job.remaining,
			"duration": job.duration, "loading": job.loading, "status": job.status})
	return {"payloads": payloads, "shipments": shipments, "unassigned": unassigned.duplicate(), "next_id": next_transfer_id}

func _restore_logistics(data: Dictionary, buildings: Array, units: Array) -> void:
	transfers.clear()
	unassigned.clear()
	_logistics_step = 0.0
	for entity in buildings + units:
		entity.erase("payloads")
		entity.erase("payload_owner")
		entity.erase("payload_order")
	var saved: Dictionary = data.get("logistics", {})
	next_transfer_id = int(saved.get("next_id", 1))
	if not data.has("logistics"):
		for key in stock:
			if not local_weapon(key) or int(stock[key]) <= 0:
				continue
			unassigned[key] = int(stock[key])
			stock[key] = 0
			for b in buildings:
				if b.owner != 0 or not b.built or b.key != facility_of(key):
					continue
				var count := mini(int(unassigned[key]), free_storage(b))
				_manifest(b)[key] = local_count(b, key) + count
				unassigned[key] -= count
		_changed_logistics()
		return
	unassigned = saved.get("unassigned", {}).duplicate()
	for row in saved.get("payloads", []):
		var entity = _load_entity(row.entity, buildings, units)
		if entity == null:
			continue
		entity.payload_owner = entity.owner
		entity.payloads = row.stock.duplicate()
		if row.has("order"):
			entity.payload_order = {"key": row.order.key, "target": _load_point(row.order.target), "automatic": row.order.automatic}
	for row in saved.get("shipments", []):
		var job: Dictionary = row.duplicate()
		job.source = _load_entity(row.source, buildings, units)
		job.destination = _load_entity(row.destination, buildings, units)
		job.start = _load_point(row.start)
		job.position = _load_point(row.position)
		transfers.append(job)
	_changed_logistics()

func capture() -> Dictionary:
	var flights := []
	var buildings: Array = world.buildings.filter(func(b): return not b.dead)
	var units: Array = world.units.filter(func(u): return not u.dead)
	for m in flying:
		var engaged: Dictionary = m.get("engaged", {})
		var defenders_used := []
		# Runtime node IDs change on load; save indices into the same live
		# building/unit lists used by save.gd instead of persisting those IDs.
		for group in [buildings, units]:
			for i in range(group.size()):
				if engaged.has(group[i].node.get_instance_id()):
					defenders_used.append({"building": is_same(group, buildings), "index": i})
		flights.append({"type": m.type, "owner": m.owner, "from": [m.from.x, m.from.y, m.from.z],
			"to": [m.to.x, m.to.y, m.to.z], "t": m.t, "dur": m.dur, "arc": m.arc,
			"peak": m.peak, "trail": m.trail, "dome": engaged.has("dome"), "defenders": defenders_used})
	return {"stock": stock.duplicate(), "flying": flights, "clock": clock, "logistics": _capture_logistics(buildings, units)}

func restore(data: Dictionary) -> void:
	for key in stock:
		stock[key] = int(data.get("stock", {}).get(key, 0))
	for m in flying:
		m.node.queue_free()
	flying.clear()
	clock = float(data.get("clock", 0.0))
	var buildings: Array = world.buildings.filter(func(b): return not b.dead)
	var units: Array = world.units.filter(func(u): return not u.dead)
	_restore_logistics(data, buildings, units)
	for saved in data.get("flying", []):
		if def_of(str(saved.type)).is_empty():
			continue
		var m: Dictionary = saved.duplicate(true)
		m.from = Vector3(saved.from[0], saved.from[1], saved.from[2])
		m.to = Vector3(saved.to[0], saved.to[1], saved.to[2])
		m.owner = int(saved.owner)
		m.engaged = {}
		if saved.get("dome", false):
			m.engaged["dome"] = true
		for defender in saved.get("defenders", []):
			var group: Array = buildings if defender.building else units
			var index := int(defender.index)
			if index >= 0 and index < group.size():
				m.engaged[group[index].node.get_instance_id()] = true
		# Recreate only the missile, never replay launch effects or spend stock.
		m.node = missile_mesh(str(m.type))
		add_child(m.node)
		var fraction := clampf(float(m.t) / maxf(float(m.dur), 0.001), 0.0, 1.0)
		var at := position_at(m, fraction)
		m.node.global_position = at
		var ahead := position_at(m, minf(fraction + 0.01, 1.0))
		if ahead.distance_to(at) > 0.01:
			m.node.look_at(ahead, Vector3.UP if absf((ahead - at).normalized().y) < 0.98 else Vector3.RIGHT)
		flying.append(m)
