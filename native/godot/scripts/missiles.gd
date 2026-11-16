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
const SHIPYARD := "shipyard"
const PORTS := ["shipyard"]
const STORAGE_FACILITIES := ["strategicComplex", "specialLab", "ammoDepot", "missileSilo", "airfield", "shipyard"]
const DOCK_REACH := 68.0
const TACTICAL_SHIPS := ["destroyer", "aegisCruiser"]
const AIR_LAUNCHERS := ["jet", "bomber", "stealthFighter", "raider"]
const LAUNCH_UNITS := ["nuclearSub", "submarine", "destroyer", "aegisCruiser", "corvette", "bomber", "raider", "jet", "stealthFighter", "drone", "fpvTeam"]
const AIR_ONLY_NUKES := ["bunkerBuster", "tsarBomba"]
var _overlay_mesh := ImmediateMesh.new()
var _overlay_instance: MeshInstance3D
var _overlay_labels: Array[Label3D] = []
var _overlay_clock := 0.0
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

func is_unconventional(key: String) -> bool:
	return category(key) in ["nuclear", "special"]

func local_weapon(key: String) -> bool:
	return key == "tactical" or category(key) in ["nuclear", "special"]

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

func _can_air_carry(key: String, owner: int) -> bool:
	var cat := category(key)
	if cat == "nuclear":
		return not key in ["poseidon", "burevestnik"]
	if cat == "special":
		return key != "riotAgent"
	return load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key) in ["air", "air_or_sea"]

func _can_sea_carry(key: String, owner: int) -> bool:
	if key == "tactical":
		return true
	var cat := category(key)
	if cat == "nuclear":
		return not key in AIR_ONLY_NUKES
	if cat == "special":
		return key != "riotAgent" and key != "bioweapon"
	return load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key) in ["sea", "sub", "air_or_sea", "ground_or_sea", "strategic"]

func is_storage_only(entity: Dictionary) -> bool:
	return bool(entity.get("is_building", false)) and entity.key in ["ammoDepot", "airfield", SHIPYARD]

func storage_accepts(entity: Dictionary, key: String) -> bool:
	if not local_weapon(key) or storage_slots(entity) <= 0:
		return false
	if not entity.get("is_building", false):
		if entity.key in ["drone", "fpvTeam"]:
			return key == "riotAgent"
		return _other_platforms_for(key, int(entity.owner), true).any(func(p): return is_same(p, entity))
	var k := String(entity.get("key", ""))
	if not k in STORAGE_FACILITIES:
		return false
	match k:
		"ammoDepot":
			return true
		"strategicComplex":
			return category(key) == "nuclear"
		"specialLab":
			return category(key) == "special"
		"missileSilo":
			return not key in AIR_ONLY_NUKES and key != "poseidon"
		"airfield":
			return _can_air_carry(key, int(entity.owner))
		"shipyard":
			return _can_sea_carry(key, int(entity.owner))
	return false

func storage_slots(entity: Dictionary) -> int:
	if entity.get("is_building", false):
		match entity.key:
			"strategicComplex", "specialLab", "airfield": return 2
			"missileSilo", "ammoDepot", "shipyard": return 4
		return 0
	if entity.key in ["nuclearSub", "submarine", "aegisCruiser", "bomber", "raider"]:
		return 2
	if entity.key in ["destroyer", "corvette", "jet", "stealthFighter", "drone", "fpvTeam"]:
		return 1
	return 0

func free_storage(entity: Dictionary) -> int:
	var slots := storage_slots(entity)
	if slots <= 0:
		return 0
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
	return maxi(0, slots - used)

func has_local_storage(entity: Dictionary) -> bool:
	if entity.get("is_building", false):
		return entity.key in STORAGE_FACILITIES
	return entity.key in LAUNCH_UNITS

func asset_name(entity: Dictionary) -> String:
	if entity.get("is_building", false):
		return str(entity.def.name)
	return str(world.unit_defs.get(entity.key, {}).get("name", entity.key))

func _dock_near(ship: Dictionary, dock: Dictionary) -> bool:
	var reach := DOCK_REACH + float(dock.get("def", {}).get("size", 10.0)) * 0.5
	return Air.distance(ship.node.position, dock.node.position) <= reach

func _supplied(entity: Dictionary) -> bool:
	return entity.get("supplied", true)

## Returns the friendly operational shipyard or airfield servicing `unit`, or {} when out of service proximity.
func service_hub_for(unit: Dictionary) -> Dictionary:
	if unit.is_empty() or unit.get("is_building", false) or unit.dead:
		return {}
	var owner := int(unit.owner)
	if unit.get("naval", false):
		if unit.get("moving", false) or unit.target != null:
			return {}
		var best := {}
		var best_dist := INF
		for b in world.buildings:
			if b.key == SHIPYARD and _active(b, owner) and _supplied(b) and _dock_near(unit, b):
				var d := Air.distance(unit.node.position, b.node.position)
				if d < best_dist:
					best_dist = d
					best = b
		return best
	if unit.get("fly", false):
		if str(unit.get("air_state", "")) != "parked":
			return {}
		var ab = unit.get("air_base")
		if ab != null and typeof(ab) == TYPE_DICTIONARY and ab.get("key", "") == "airfield" and _active(ab, owner) and _supplied(ab):
			return ab
		return {}
	if unit.key in ["drone", "fpvTeam"]:
		var best_site := {}
		var best_d := 40.0
		for b in world.buildings:
			if b.key in ["specialLab", "ammoDepot", "missileSilo"] and _active(b, owner) and _supplied(b):
				var d := Air.distance(unit.node.position, b.node.position)
				if d <= best_d:
					best_d = d
					best_site = b
		return best_site
	return {}

func _at_service(unit: Dictionary, facility: Dictionary, _direct := false) -> bool:
	var hub := service_hub_for(unit)
	return not hub.is_empty() and is_same(hub, facility)

func transfer_blocked(source: Dictionary, destination: Dictionary, key: String, count := 1, _direct := false) -> String:
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
		return "Unload at a Shipyard or Airfield first."
	if not _supplied(source) or not _supplied(destination):
		return "Supply route unavailable."
	if to_unit:
		var hub := service_hub_for(destination)
		if hub.is_empty():
			if destination.get("naval", false):
				return "Ship or submarine must be stopped near a friendly Shipyard."
			if destination.get("fly", false):
				return "Aircraft must be parked at a friendly Airfield."
			return "Unit must be stationed near a compatible support facility."
		if not _supplied(hub):
			return "Service facility supply route unavailable."
	if from_unit:
		var src_hub := service_hub_for(source)
		if src_hub.is_empty():
			if source.get("naval", false):
				return "Ship or submarine must be stopped near a friendly Shipyard to unload."
			if source.get("fly", false):
				return "Aircraft must be parked at a friendly Airfield to unload."
			return "Unit must be stationed near a compatible support facility to unload."
		if not _supplied(src_hub):
			return "Service facility supply route unavailable."
	return ""

func _hub_for_pair(source: Dictionary, destination: Dictionary) -> Dictionary:
	if not destination.get("is_building", false):
		return service_hub_for(destination)
	if not source.get("is_building", false):
		return service_hub_for(source)
	return {}

func transfer_duration(source: Dictionary, destination: Dictionary, count: int) -> float:
	var from_b := bool(source.get("is_building", false))
	var to_b := bool(destination.get("is_building", false))
	if from_b and to_b:
		return 6.0 + Air.distance(source.node.position, destination.node.position) / 22.0
	var dock_time := 5.0 + float(count) * 1.5
	var hub := _hub_for_pair(source, destination)
	if hub.is_empty():
		return dock_time
	var other: Dictionary = source if not to_b else destination
	if is_same(other, hub):
		return dock_time
	return dock_time + 6.0 + Air.distance(other.node.position, hub.node.position) / 22.0

## All friendly entities where `key` can currently be placed/loaded from `source`.
func valid_destinations(source: Dictionary, key: String, count := 1) -> Array:
	var out: Array = []
	if source.is_empty() or not local_weapon(key):
		return out
	var owner := int(source.get("owner", 0))
	for entity in world.buildings + world.units:
		if entity.dead or int(entity.owner) != owner or is_same(entity, source):
			continue
		if transfer_blocked(source, entity, key, count) == "":
			out.append(entity)
	return out

## Compatible friendly combat units of `owner` that currently need docking at a Shipyard or Airfield before loading `key`.
func blocked_candidate_hints(source: Dictionary, key: String, count := 1) -> Array:
	var out: Array = []
	if not local_weapon(key) or not source.get("is_building", false):
		return out
	var owner := int(source.get("owner", 0))
	for u in world.units:
		if u.dead or int(u.owner) != owner or world.disabled(u):
			continue
		if not storage_accepts(u, key) or free_storage(u) < count:
			continue
		if not service_hub_for(u).is_empty():
			continue
		var hint := "Sail near Shipyard" if u.get("naval", false) else ("Park at Airfield" if u.get("fly", false) else "Move near facility")
		out.append({"entity": u, "reason": hint})
	return out

## Returns every building and unit of `owner` currently holding `key`: [{entity, count, can_launch}].
func where_is(key: String, owner := 0) -> Array:
	var out: Array = []
	var r_plats := platforms_for(key, owner)
	for entity in world.buildings + world.units:
		if entity.dead or int(entity.owner) != owner or not entity.has("payloads"):
			continue
		var c := local_count(entity, key)
		if c > 0:
			var can_fire := r_plats.any(func(p): return is_same(p, entity))
			out.append({"entity": entity, "count": c, "can_launch": can_fire})
	return out

## One-click load of `key` from any friendly storage facility (or `preferred_source`) onto `destination`.
## Enforces Shipyard proximity for naval units and Airfield parking for aircraft.
func quick_load_onto(destination: Dictionary, key: String, count := 1, preferred_source = null) -> String:
	var owner := int(destination.get("owner", 0))
	if not destination.get("is_building", false):
		var hub := service_hub_for(destination)
		if hub.is_empty():
			if destination.get("naval", false):
				if destination.get("moving", false) or destination.target != null:
					return "Stop the ship or submarine near a friendly Shipyard to load %s." % def_of(key).get("name", key)
				return "Move the ship or submarine near a friendly Shipyard to load %s." % def_of(key).get("name", key)
			if destination.get("fly", false):
				return "Land and park the aircraft at a friendly Airfield to load %s." % def_of(key).get("name", key)
			return "Move unit near a compatible storage facility first."
	if preferred_source != null and typeof(preferred_source) == TYPE_DICTIONARY and not preferred_source.is_empty():
		if not is_same(preferred_source, destination) and transfer_blocked(preferred_source, destination, key, count) == "":
			return start_transfer(preferred_source, destination, key, count)
	var best_src := {}
	var best_score := -999999.0
	var plats := platforms_for(key, owner)
	var hub_for_dst := service_hub_for(destination)
	for b in world.buildings:
		if b.dead or int(b.owner) != owner or not b.built or local_count(b, key) < count:
			continue
		if transfer_blocked(b, destination, key, count) != "":
			continue
		var is_launcher := plats.any(func(p): return is_same(p, b))
		var at_hub_bonus := 50.0 if (not hub_for_dst.is_empty() and is_same(b, hub_for_dst)) else 0.0
		var score := at_hub_bonus + float(local_count(b, key)) * 10.0 - (25.0 if is_launcher else 0.0) - Air.distance(b.node.position, destination.node.position) * 0.01
		if score > best_score:
			best_score = score
			best_src = b
	if best_src.is_empty():
		return "No stored %s available to load." % def_of(key).get("name", key)
	return start_transfer(best_src, destination, key, count)

## One-click load of 1 warhead of `key` onto the best available docked/parked/silo launcher of `owner`.
func quick_load_any_launcher(key: String, owner := 0, preferred_source = null, filter_kind := "") -> String:
	var candidates := _other_platforms_for(key, owner, true)
	if filter_kind == "sub":
		candidates = candidates.filter(func(c): return not c.get("is_building", false) and c.key in ["nuclearSub", "submarine"])
	elif filter_kind == "ship":
		candidates = candidates.filter(func(c): return not c.get("is_building", false) and c.key in ["destroyer", "aegisCruiser", "corvette"])
	elif filter_kind == "air":
		candidates = candidates.filter(func(c): return not c.get("is_building", false) and c.get("fly", false))
	elif filter_kind == "silo":
		candidates = candidates.filter(func(c): return c.get("is_building", false))
	candidates.sort_custom(func(a, b):
		var a_ready: bool = not bool(a.get("is_building", false)) and not service_hub_for(a).is_empty()
		var b_ready: bool = not bool(b.get("is_building", false)) and not service_hub_for(b).is_empty()
		if a_ready != b_ready:
			return a_ready
		var a_unit := not bool(a.get("is_building", false))
		var b_unit := not bool(b.get("is_building", false))
		if a_unit != b_unit:
			return a_unit
		var a_sub := str(a.get("key", "")) in ["nuclearSub", "submarine"]
		var b_sub := str(b.get("key", "")) in ["nuclearSub", "submarine"]
		if a_sub != b_sub:
			return a_sub
		return local_count(a, key) < local_count(b, key))
	var blocked_msg := ""
	for dst in candidates:
		if free_storage(dst) <= 0:
			continue
		var res := quick_load_onto(dst, key, 1, preferred_source)
		if res == "":
			return ""
		if blocked_msg == "":
			blocked_msg = res
	return blocked_msg if blocked_msg != "" else "No compatible launcher at a Shipyard or Airfield with free slots."

func _changed_logistics() -> void:
	logistics_revision += 1
	changed.emit()

func transfer_or_load(source: Dictionary, destination: Dictionary, key: String, count := 1) -> String:
	return start_transfer(source, destination, key, count)

func start_transfer(source: Dictionary, destination: Dictionary, key: String, count := 1, _direct := false) -> String:
	var reason := transfer_blocked(source, destination, key, count)
	if reason != "":
		return reason
	var from_b := bool(source.get("is_building", false))
	var to_b := bool(destination.get("is_building", false))
	var loading: bool = not (from_b and to_b)
	var hub := _hub_for_pair(source, destination)
	var stage := "transit"
	var dock_time := 5.0 + float(count) * 1.5
	var transit_time := 0.0
	var leg_from: Vector3 = source.node.position
	var leg_to: Vector3 = destination.node.position
	var stage_dur := 0.0
	if from_b and to_b:
		stage = "transit"
		stage_dur = 6.0 + Air.distance(source.node.position, destination.node.position) / 22.0
		transit_time = stage_dur
	elif loading and not hub.is_empty():
		var other_b: Dictionary = source if from_b else destination
		if is_same(other_b, hub):
			stage = "loading"
			stage_dur = dock_time
		elif from_b:
			stage = "transit"
			transit_time = 6.0 + Air.distance(source.node.position, hub.node.position) / 22.0
			stage_dur = transit_time
			leg_to = hub.node.position
		else:
			stage = "loading"
			transit_time = 6.0 + Air.distance(hub.node.position, destination.node.position) / 22.0
			stage_dur = dock_time
			leg_to = hub.node.position
	else:
		stage = "loading"
		stage_dur = dock_time
	var total_time := transit_time + (dock_time if loading else 0.0)
	_manifest(source)[key] = local_count(source, key) - count
	transfers.append({"id": next_transfer_id, "key": key, "owner": source.owner, "count": count,
		"source": source, "destination": destination, "via_hub": null if hub.is_empty() else hub,
		"stage": stage, "start": leg_from, "leg_end": leg_to, "position": leg_from,
		"remaining": total_time, "duration": total_time, "stage_remaining": stage_dur, "stage_duration": stage_dur,
		"transit_duration": transit_time, "dock_duration": dock_time,
		"loading": loading, "status": "In transit" if stage == "transit" else "Loading"})
	next_transfer_id += 1
	_changed_logistics()
	return ""

func transfer_job(id: int) -> Variant:
	for job in transfers:
		if job.id == id:
			return job
	return null

func redirect_transfer(job: Dictionary, destination: Dictionary) -> String:
	if not transfers.has(job) or not _active(destination, int(job.owner)) or not destination.get("is_building", false):
		return "Choose an operational storage facility."
	if job.loading and job.stage == "loading" and job.source != null and not job.source.get("is_building", false):
		return "Finish unloading at the dock first."
	if is_same(job.destination, destination):
		return "Shipment already assigned to this facility."
	if not storage_accepts(destination, job.key) or free_storage(destination) < job.count or not _supplied(destination):
		return "Destination cannot accept the shipment."
	job.destination = destination
	job.via_hub = null
	job.loading = false
	job.stage = "transit"
	job.start = job.position
	job.leg_end = destination.node.position
	job.duration = 8.0 + Air.distance(job.position, destination.node.position) / 16.0
	job.remaining = job.duration
	job.stage_duration = job.duration
	job.stage_remaining = job.duration
	job.status = "In transit"
	_changed_logistics()
	return ""

func _end_transfer(job: Dictionary, receiver) -> void:
	transfers.erase(job)
	var delivered: bool = _alive(receiver) and receiver.owner == job.owner and storage_accepts(receiver, job.key)
	if delivered:
		_manifest(receiver)[job.key] = local_count(receiver, job.key) + int(job.count)
	if job.owner == 0 and world.hud != null:
		var status := ("delivered to " + asset_name(receiver)) if delivered else "weapon lost"
		world.hud.notice("%s x%d: %s." % [def_of(job.key).name, job.count, status])
	_changed_logistics()

func cancel_transfer(job: Dictionary) -> String:
	if not transfers.has(job):
		return "Shipment already finished."
	if (job.stage == "loading" and job.source != null and job.source.get("is_building", false)) or (job.remaining >= job.duration and _alive(job.source) and free_storage(job.source) >= job.count):
		_end_transfer(job, job.source)
		return ""
	if _alive(job.source) and job.source.get("is_building", false):
		return redirect_transfer(job, job.source)
	var hub = job.get("via_hub")
	if hub != null and _active(hub, int(job.owner)) and free_storage(hub) >= job.count:
		return redirect_transfer(job, hub)
	return "Source unavailable. Redirect the shipment to another facility."

func abandon_transfer(job: Dictionary) -> void:
	if transfers.has(job):
		_end_transfer(job, null)

func on_entity_destroyed(entity: Dictionary, announce := true) -> void:
	if world == null:
		return
	var lost_total := 0
	var manifest := _manifest(entity)
	for k in manifest.keys():
		lost_total += int(manifest[k])
	manifest.clear()
	entity.erase("payloads")
	entity.erase("payload_order")
	if world.get("payload_pick") != null and typeof(world.payload_pick) == TYPE_DICTIONARY and not world.payload_pick.is_empty():
		var src = world.payload_pick.get("source")
		if src != null and is_same(src, entity):
			world.cancel_payload_transfer()
	for job in transfers.duplicate():
		var from_ent := is_same(job.source, entity)
		var to_ent := is_same(job.destination, entity)
		var hub_ent := job.get("via_hub") != null and is_same(job.via_hub, entity)
		if not (from_ent or to_ent or hub_ent):
			continue
		if job.loading:
			if to_ent and job.stage == "transit" and job.source != null and _alive(job.source) and job.source.get("is_building", false):
				redirect_transfer(job, job.source)
			elif to_ent or from_ent or hub_ent:
				lost_total += int(job.count)
				transfers.erase(job)
		else:
			if from_ent and job.remaining >= job.duration * 0.9:
				lost_total += int(job.count)
				transfers.erase(job)
	if announce and lost_total > 0 and int(entity.get("owner", -1)) == 0 and world.hud != null:
		world.hud.notice("%s destroyed — %d carried weapon%s lost with it." % [asset_name(entity), lost_total, "" if lost_total == 1 else "s"])
	_changed_logistics()

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
		var hub = job.get("via_hub")
		if not _active(destination, job.owner) or not _supplied(destination):
			job.status = "Destination unavailable"
			continue
		if job.loading:
			var unit_ent: Dictionary = destination if (source != null and source.get("is_building", false)) else source
			var fac_ent: Dictionary = hub if hub != null else (source if source.get("is_building", false) else destination)
			if not _alive(fac_ent) or fac_ent.owner != job.owner:
				_end_transfer(job, source if (source != null and _alive(source) and source.get("is_building", false)) else null)
				continue
			if not _at_service(unit_ent, fac_ent):
				if str(job.get("stage", "loading")) == "transit" and source != null and _alive(source) and source.get("is_building", false):
					# Unit departed before convoy reached the hub: deposit at the hub if possible, else return to source.
					if free_storage(fac_ent) >= job.count and storage_accepts(fac_ent, job.key):
						redirect_transfer(job, fac_ent)
					else:
						redirect_transfer(job, source)
				else:
					_end_transfer(job, fac_ent if (free_storage(fac_ent) >= job.count and storage_accepts(fac_ent, job.key)) else source)
				continue
			if not _active(fac_ent, job.owner) or not _supplied(fac_ent):
				job.status = "Service paused"
				continue
		else:
			if _alive(source) and source.owner == job.owner and not _supplied(source):
				job.status = "Supply route cut"
				continue
		var step := delta
		for _hop in range(4):
			if step <= 0.0 or not transfers.has(job):
				break
			if str(job.get("stage", "transit")) == "transit":
				job.status = "In transit (via %s)" % asset_name(hub) if (job.loading and hub != null and not is_same(source, hub)) else "In transit"
			else:
				job.status = "Unloading at dock" if (source != null and not source.get("is_building", false)) else "Loading onto launcher"
			var prev_stage := float(job.get("stage_remaining", job.remaining))
			var spent := minf(step, prev_stage)
			var next_stage := maxf(0.0, prev_stage - spent)
			step -= spent
			job.stage_remaining = next_stage
			job.remaining = maxf(0.0, float(job.remaining) - spent)
			var leg_dur := maxf(0.01, float(job.get("stage_duration", job.duration)))
			var leg_start: Vector3 = job.get("start", source.node.position)
			var leg_end: Vector3 = job.get("leg_end", destination.node.position)
			job.position = leg_start.lerp(leg_end, clampf(1.0 - next_stage / leg_dur, 0.0, 1.0))
			if next_stage > 0.0:
				break
			if job.loading and hub != null and str(job.get("stage", "")) == "transit":
				job.stage = "loading"
				job.stage_duration = float(job.get("dock_duration", 6.5))
				job.stage_remaining = job.stage_duration
				job.start = hub.node.position
				job.leg_end = destination.node.position
				job.position = hub.node.position
			elif job.loading and hub != null and str(job.get("stage", "")) == "loading" and destination.get("is_building", false) and not is_same(hub, destination):
				job.stage = "transit"
				job.loading = false
				job.stage_duration = float(job.get("transit_duration", 6.0))
				job.stage_remaining = job.stage_duration
				job.start = hub.node.position
				job.leg_end = destination.node.position
				job.position = hub.node.position
			else:
				_end_transfer(job, destination)
				break

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
	if category(key) == "nuclear":
		if key == "poseidon":
			return world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and u.key in ["nuclearSub", "submarine"])
		var nav_keys := ["nuclearSub", "submarine", "destroyer", "aegisCruiser"] if key in ["nuke", "mirv", "hydrogenBomb", "nuclearEmp", "burevestnik"] else ["nuclearSub", "submarine", "destroyer", "aegisCruiser", "corvette"]
		var air_keys := ["bomber", "raider"] if key in ["nuke", "mirv", "hydrogenBomb", "nuclearEmp"] else ([] if key == "burevestnik" else AIR_LAUNCHERS)
		var out: Array = [] if key in ["bunkerBuster", "tsarBomba"] else _sites(owner, key)
		for u in world.units:
			if u.dead or int(u.owner) != owner or (not storage and world.disabled(u)):
				continue
			if not key in ["bunkerBuster", "tsarBomba"] and u.key in nav_keys:
				out.append(u)
			elif u.key in air_keys and (storage or u.get("air_state", "ready") in ["ready", "parked"]):
				out.append(u)
		return out
	var cat := category(key)
	if cat == "special":
		if key == "riotAgent":
			var drones: Array = world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in ["drone", "fpvTeam"] and (storage or (not world.disabled(u) and u.get("air_state", "ready") == "ready")))
			return drones + _sites(owner, key)
		var out: Array = _sites(owner, key)
		for u in world.units:
			if u.dead or int(u.owner) != owner or (not storage and world.disabled(u)):
				continue
			if key != "bioweapon" and u.key in ["nuclearSub", "submarine", "destroyer", "aegisCruiser", "corvette"]:
				out.append(u)
			elif u.key in AIR_LAUNCHERS and (storage or u.get("air_state", "ready") in ["ready", "parked"]):
				out.append(u)
		return out
	var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key)
	if key == "tactical" and kind == "ground":
		return _sites(owner, key) + world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in (TACTICAL_SHIPS + ["corvette", "submarine", "nuclearSub"]) and (storage or not world.disabled(u)))
	if kind == "air":
		# In the air or waiting at its airfield (it takes off with the missile); not one being rearmed or landing.
		return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in AIR_LAUNCHERS and (storage or (not world.disabled(u) and u.get("air_state", "ready") in ["ready", "parked"])))
	if kind == "drone":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in ["drone", "fpvTeam"] and not world.disabled(u) and u.get("air_state", "ready") == "ready")
	if kind == "air_or_sea":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and (u.key in ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"] or (u.key in AIR_LAUNCHERS and (storage or u.get("air_state", "ready") in ["ready", "parked"]))))
	if kind in ["sea", "sub"]:
		return world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and u.key in (["nuclearSub", "submarine"] if kind == "sub" else ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"]))
	if kind in ["strategic", "ground_or_sea"]:
		var ships: Array = world.units.filter(func(u): return u.owner == owner and not u.dead and (storage or not world.disabled(u)) and u.key in ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"])
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
	if category(key) == "nuclear":
		if key == "poseidon":
			return "a submarine or nuclear submarine"
		if key in ["bunkerBuster", "tsarBomba"]:
			return "a Bomber, Raider, Stealth Fighter or Jet"
		return "a Submarine, Missile Ship (Destroyer/Cruiser), Bomber, Missile Silo or Strategic Complex"
	var cat := category(key)
	if cat == "special":
		if key == "riotAgent":
			return "a Drone, FPV team, Special Lab or Missile Silo"
		if key == "bioweapon":
			return "an aircraft (Bomber, Raider, Stealth Fighter, Jet), Special Lab or Missile Silo"
		return "a Special Lab, Missile Silo, Submarine, Missile Ship or Strike Aircraft"
	var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key)
	if key == "tactical" and kind == "ground": return "a missile silo, submarine, destroyer or cruiser"
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
		if str(platform.get("air_state", "")) in ["returning", "no base"]:
			platform.air_state = "ready"
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

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 12
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_overlay_instance = MeshInstance3D.new()
	_overlay_instance.mesh = _overlay_mesh
	_overlay_instance.material_override = mat
	_overlay_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay_instance.top_level = true
	add_child(_overlay_instance)

func _label_at(idx: int, text: String, at: Vector3, colour: Color) -> void:
	while _overlay_labels.size() <= idx:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.08
		l.font_size = 24
		l.outline_size = 7
		l.outline_modulate = Color(0.05, 0.07, 0.06, 0.92)
		l.render_priority = 13
		l.visible = false
		add_child(l)
		_overlay_labels.append(l)
	var lbl := _overlay_labels[idx]
	lbl.text = text
	lbl.modulate = colour
	lbl.global_position = at
	lbl.visible = true

func _ring_verts(centre: Vector3, inner_r: float, outer_r: float, colour: Color, y_lift := 0.55) -> void:
	var segs := 28
	var sea := float(world.map.seaLevel) if world != null and world.get("map") != null else 0.0
	for i in range(segs):
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(centre.x + cos(a0) * inner_r, 0.0, centre.z + sin(a0) * inner_r)
		var p1 := Vector3(centre.x + cos(a0) * outer_r, 0.0, centre.z + sin(a0) * outer_r)
		var p2 := Vector3(centre.x + cos(a1) * outer_r, 0.0, centre.z + sin(a1) * outer_r)
		var p3 := Vector3(centre.x + cos(a1) * inner_r, 0.0, centre.z + sin(a1) * inner_r)
		for pt in [p0, p1, p2, p0, p2, p3]:
			var h: float = maxf(float(world.height_at(pt.x, pt.z)), sea) + y_lift if world != null else centre.y + y_lift
			_overlay_mesh.surface_set_color(colour)
			_overlay_mesh.surface_add_vertex(Vector3(pt.x, h, pt.z))

func _draw_segment(a: Vector3, b: Vector3, width: float, colour: Color, y_lift := 0.9) -> void:
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if dir.length_squared() < 0.001:
		return
	var perp := Vector3(-dir.z, 0.0, dir.x).normalized() * (width * 0.5)
	var sea := float(world.map.seaLevel) if world != null and world.get("map") != null else 0.0
	for pt in [a - perp, a + perp, b + perp, a - perp, b + perp, b - perp]:
		var h: float = maxf(float(world.height_at(pt.x, pt.z)), sea) + y_lift if world != null else pt.y + y_lift
		_overlay_mesh.surface_set_color(colour)
		_overlay_mesh.surface_add_vertex(Vector3(pt.x, h, pt.z))

func _update_overlay(delta: float) -> void:
	_overlay_clock += delta
	_overlay_mesh.clear_surfaces()
	for l in _overlay_labels:
		l.visible = false
	if world == null or DisplayServer.get_name() == "headless":
		return
	var pick: Dictionary = world.get("payload_pick") if world.get("payload_pick") is Dictionary else {}
	var own_jobs: Array = transfers.filter(func(j): return int(j.owner) == 0)
	if pick.is_empty() and own_jobs.is_empty():
		return
	_overlay_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var pulse := 0.72 + 0.28 * sin(_overlay_clock * 5.0)
	var l_idx := 0
	if not pick.is_empty():
		var src = pick.get("source")
		var key := str(pick.get("key", ""))
		var count := maxi(1, int(pick.get("count", 1)))
		if _alive(src):
			var sp: Vector3 = src.node.position
			var sr: float = float(src.get("footprint", 8.0)) * 0.65 if src.get("is_building", false) else 6.0
			_ring_verts(sp, sr, sr + 1.1, Color(0.95, 0.78, 0.28, 0.95))
			_label_at(l_idx, "FROM: %s" % def_of(key).get("name", key), sp + Vector3(0, 7.5, 0), Color("f5d26b"))
			l_idx += 1
			for dst in valid_destinations(src, key, count):
				var dp: Vector3 = dst.node.position
				var r: float = float(dst.get("footprint", 8.0)) * 0.68 if dst.get("is_building", false) else 6.5
				_ring_verts(dp, 0.3, r, Color(0.18, 0.92, 0.42, 0.22 * pulse), 0.48)
				_ring_verts(dp, r, r + 1.4, Color(0.24, 1.0, 0.48, 0.95), 0.6)
				var tag := "LOAD" if not dst.get("is_building", false) else ("UNLOAD" if not src.get("is_building", false) else ("SILO" if dst.key == "missileSilo" else ("DEPOT" if dst.key == "ammoDepot" else ("SHIPYARD" if dst.key == "shipyard" else ("AIRFIELD" if dst.key == "airfield" else "STORE")))))
				_label_at(l_idx, "%s (%d free · %.0fs)" % [tag, free_storage(dst), transfer_duration(src, dst, count)], dp + Vector3(0, 8.0, 0), Color(0.45, 1.0, 0.62))
				l_idx += 1
			for hint in blocked_candidate_hints(src, key):
				var u: Dictionary = hint.entity
				var up: Vector3 = u.node.position
				_ring_verts(up, 5.2, 6.2, Color(0.95, 0.65, 0.22, 0.72), 0.52)
				_label_at(l_idx, hint.reason, up + Vector3(0, 7.0, 0), Color(0.98, 0.78, 0.36))
				l_idx += 1
	for job in own_jobs:
		if not _alive(job.destination):
			continue
		var a: Vector3 = job.position
		var b: Vector3 = job.get("leg_end", job.destination.node.position)
		var hub = job.get("via_hub")
		_draw_segment(a, b, 0.55, Color(0.35, 0.92, 0.96, 0.75))
		if hub != null and _alive(hub) and str(job.get("stage", "")) == "transit" and not is_same(hub, job.destination):
			_draw_segment(hub.node.position, job.destination.node.position, 0.45, Color(0.3, 0.95, 0.55, 0.65))
		_ring_verts(a, 1.4, 2.5, Color(0.96, 0.84, 0.32, 0.95), 1.2)
		var tag_txt := "%s · %.0fs" % [def_of(job.key).get("icon", job.key), maxf(0.0, float(job.remaining))]
		_label_at(l_idx, tag_txt, a + Vector3(0, 5.0, 0), Color(0.45, 0.96, 1.0))
		l_idx += 1
	_overlay_mesh.surface_end()

func _physics_process(delta: float) -> void:
	_logistics_step += delta
	if _logistics_step >= 0.25:
		_update_transfers(_logistics_step)
		_update_air_payloads()
		_logistics_step = 0.0
	_update_overlay(delta)
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
			"via_hub": _save_entity(job.get("via_hub"), buildings, units),
			"stage": str(job.get("stage", "transit")),
			"start": _save_point(job.start), "leg_end": _save_point(job.get("leg_end", job.destination.node.position if _alive(job.destination) else job.position)),
			"position": _save_point(job.position), "remaining": job.remaining,
			"duration": job.duration, "stage_remaining": float(job.get("stage_remaining", job.remaining)),
			"stage_duration": float(job.get("stage_duration", job.duration)),
			"transit_duration": float(job.get("transit_duration", job.duration)),
			"dock_duration": float(job.get("dock_duration", 6.5)),
			"loading": job.loading, "status": job.status})
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
		job.via_hub = _load_entity(row.get("via_hub"), buildings, units)
		job.start = _load_point(row.start)
		job.leg_end = _load_point(row.leg_end) if row.has("leg_end") else (job.destination.node.position if _alive(job.destination) else _load_point(row.position))
		job.position = _load_point(row.position)
		if not job.has("stage"): job.stage = "loading" if job.loading else "transit"
		if not job.has("stage_remaining"): job.stage_remaining = job.remaining
		if not job.has("stage_duration"): job.stage_duration = job.duration
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
