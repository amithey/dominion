extends Node3D
## Homefront systemic depth (Track 1):
##   1A. Physical 3D Fire Engines (from fireStation) & Ambulances (from hospital)
##       that drive along intact road hex links (logistics.gd) or cross-country
##       to burning / casualty-struck buildings, with flashing emergency beacons
##       and on-scene water cannon spray.
##   1B. Power Grid & Local Blackouts: tracks national MW generation vs demand
##       plus local grid shock when a powerPlant or nuclearReactor is hit below
##       50% HP or destroyed. Blacked-out districts extinguish window glow and
##       suffer -35% production & -30% radar/sight until repaired or backed up
##       by a nearby solarFarm.
##   1C. Civilian Casualties & Hospital Load: hits on populated districts create
##       casualties; active hospitals & ambulances treat them, while uncontained
##       hospital overload erodes public health and war support.

const BASE_MUNICIPAL_MW := 160.0
const PLANT_MW := {"powerPlant": 140.0, "nuclearReactor": 280.0, "solarFarm": 65.0}
const DEMAND_MW := {
	"aiDataCenter": 48.0, "chipFab": 36.0, "fusionCell": 32.0, "strategicComplex": 30.0,
	"specialLab": 26.0, "tankFactory": 24.0, "shipyard": 24.0, "oilRefinery": 22.0,
	"samSite": 18.0, "commandCenter": 18.0, "airfield": 16.0, "intelAgency": 16.0,
	"techPark": 16.0, "tvStation": 14.0, "stockExchange": 14.0, "bank": 12.0,
	"hospital": 14.0, "apartments": 12.0, "residential": 10.0, "cityCenter": 14.0,
	"cityHall": 10.0, "university": 12.0, "warehouse": 8.0, "foodDepot": 8.0,
	"waterTreatment": 12.0, "railwayStation": 10.0, "port": 12.0,
}
const POPULATED_KEYS := [
	"cottage", "workerHouse", "luxuryVillas", "housing", "residential", "apartments",
	"villageCenter", "cityCenter", "hq", "market", "school", "library", "university",
	"cityHall", "courthouse", "bank", "stockExchange", "tvStation", "techPark",
	"museum", "worship", "stadium", "park", "hospital", "policeStation",
]
const PRIORITY_POWER_KEYS := ["hq", "hospital", "fireStation", "commandCenter", "villageCenter", "cityCenter"]

const ROAD_SPEED := 19.5
const OFFROAD_SPEED := 10.8
const ARRIVE_DIST := 11.5
const SOLAR_BACKUP_RADIUS := 62.0
const SUBSTATION_SHOCK_RADIUS := 92.0

var w: Node
var _tick := 0.0
var _beacon_time := 0.0
var power_supply := {}      # owner -> MW generated
var power_demand := {}      # owner -> MW required
var grid_damaged := {}      # owner -> Array of Vector3 positions where a power plant was crippled/destroyed recently
var casualties := {}        # owner -> float active untreated casualties
var hospital_cap := {}      # owner -> float hospital capacity
var dispatches: Array = []  # [{kind, owner, station, target, node, path, wp, on_road, state, timer, beacon_l, beacon_r, spray}]

static var _blackout_mat: StandardMaterial3D
static var _mat_cache := {}

func _init(world: Node = null) -> void:
	w = world
	name = "Homefront"

func setup(world: Node) -> void:
	w = world

static func _dark_window_mat() -> StandardMaterial3D:
	if _blackout_mat == null:
		_blackout_mat = StandardMaterial3D.new()
		_blackout_mat.albedo_color = Color(0.05, 0.06, 0.08)
		_blackout_mat.roughness = 0.35
		_blackout_mat.metallic = 0.15
		_blackout_mat.emission_enabled = false
	return _blackout_mat

static func _color_mat(key: String, col: Color, emit := 0.0, rough := 0.5) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mat_cache[key] = m
	return m

# ---------------------------------------------------------------- hooks from world.gd

func on_building_damaged(b: Dictionary, amount: float, _source: Dictionary = {}) -> void:
	if w == null or b.get("dead", false) or amount <= 0.0:
		return
	var key := str(b.get("key", ""))
	var owner := int(b.get("owner", 0))
	if key in ["powerPlant", "nuclearReactor"] and float(b.hp) / maxf(float(b.max_hp), 1.0) < 0.55:
		_record_grid_shock(owner, b.root.position)
	if key in POPULATED_KEYS and b.get("built", false):
		var scale := 0.22 if key in ["apartments", "residential", "cityCenter", "housing", "stadium", "market"] else 0.12
		var added := clampf(amount * scale, 0.5, 45.0)
		casualties[owner] = float(casualties.get(owner, 0.0)) + added
		b.casualty_site = clampf(float(b.get("casualty_site", 0.0)) + added, 0.0, 120.0)

func on_building_destroyed(b: Dictionary) -> void:
	if w == null:
		return
	var key := str(b.get("key", ""))
	var owner := int(b.get("owner", 0))
	if key in ["powerPlant", "nuclearReactor"]:
		_record_grid_shock(owner, b.root.position)
	if key in POPULATED_KEYS:
		casualties[owner] = float(casualties.get(owner, 0.0)) + 18.0

func _record_grid_shock(owner: int, at: Vector3) -> void:
	if not grid_damaged.has(owner):
		grid_damaged[owner] = []
	for entry in grid_damaged[owner]:
		if (entry.pos as Vector3).distance_to(at) < 18.0:
			entry.until = w.game_time + 95.0
			return
	grid_damaged[owner].append({"pos": at, "until": w.game_time + 95.0})

# ---------------------------------------------------------------- simulation & dispatch

func update(delta: float) -> void:
	if w == null:
		return
	_update_vehicles(delta)
	_tick += delta
	if _tick < 0.5:
		return
	var dt := _tick
	_tick = 0.0
	_update_power_and_casualties(dt)
	_reconcile_dispatches()

func _update_power_and_casualties(dt: float) -> void:
	var n_nations: int = w.map.nations.size() if w.get("map") != null and w.map.has("nations") else 1
	for o in range(n_nations):
		power_supply[o] = BASE_MUNICIPAL_MW
		power_demand[o] = 0.0
		hospital_cap[o] = 0.0
		if grid_damaged.has(o):
			grid_damaged[o] = (grid_damaged[o] as Array).filter(func(e): return float(e.until) > w.game_time)

	var solar_sites := {}
	var healthy_plants := {}
	var damaged_plants := {}
	for b in w.buildings:
		if b.dead or not b.built:
			continue
		var o := int(b.owner)
		var key := str(b.key)
		var hp_share := clampf(float(b.hp) / maxf(float(b.max_hp), 1.0), 0.0, 1.0)
		if PLANT_MW.has(key):
			if not w.disabled(b) and float(b.get("fire", 0.0)) < 0.65:
				var mw := float(PLANT_MW[key]) * hp_share * (1.0 if b.get("supplied", true) or key == "solarFarm" else 0.55)
				power_supply[o] = float(power_supply.get(o, BASE_MUNICIPAL_MW)) + mw
				if key == "solarFarm" and hp_share >= 0.45:
					if not solar_sites.has(o): solar_sites[o] = []
					solar_sites[o].append(b.root.position)
				elif hp_share >= 0.55:
					if not healthy_plants.has(o): healthy_plants[o] = []
					healthy_plants[o].append(b.root.position)
				else:
					if not damaged_plants.has(o): damaged_plants[o] = []
					damaged_plants[o].append(b.root.position)
			else:
				if not damaged_plants.has(o): damaged_plants[o] = []
				damaged_plants[o].append(b.root.position)
		else:
			var req := float(DEMAND_MW.get(key, 6.0 if not b.def.get("water", false) else 2.0))
			power_demand[o] = float(power_demand.get(o, 0.0)) + req

		if key == "hospital" and not w.disabled(b) and not b.get("blackout", false):
			var mult := (1.25 if b.get("supplied", true) else 0.65) * hp_share
			hospital_cap[o] = float(hospital_cap.get(o, 0.0)) + 45.0 * mult

	# Determine per-building blackout status and sync window glow materials.
	for b in w.buildings:
		if b.dead or not b.built:
			continue
		var o := int(b.owner)
		var key := str(b.key)
		if key in ["powerPlant", "nuclearReactor", "solarFarm", "farm", "park", "mountainMine", "extractor", "offshoreRig"]:
			_set_blackout(b, false)
			continue
		var pos: Vector3 = b.root.position
		var has_solar_backup := false
		for sp in solar_sites.get(o, []):
			if (sp as Vector3).distance_to(pos) <= SOLAR_BACKUP_RADIUS:
				has_solar_backup = true
				break
		var local_outage := false
		if not has_solar_backup:
			for dp in damaged_plants.get(o, []):
				if (dp as Vector3).distance_to(pos) <= SUBSTATION_SHOCK_RADIUS:
					local_outage = true
					break
			if not local_outage and grid_damaged.has(o):
				for entry in grid_damaged[o]:
					if (entry.pos as Vector3).distance_to(pos) <= SUBSTATION_SHOCK_RADIUS:
						local_outage = true
						break
			if local_outage:
				for hp_pos in healthy_plants.get(o, []):
					if (hp_pos as Vector3).distance_to(pos) <= SUBSTATION_SHOCK_RADIUS * 0.75:
						local_outage = false
						break
		var sup := float(power_supply.get(o, BASE_MUNICIPAL_MW))
		var dem := float(power_demand.get(o, 0.0))
		var national_deficit := dem > sup and not has_solar_backup
		var shed_load := false
		if national_deficit:
			var ratio := sup / maxf(dem, 1.0)
			shed_load = ratio < 0.62 or not (key in PRIORITY_POWER_KEYS)
		_set_blackout(b, local_outage or shed_load)

	# Process casualty treatment by hospitals and ambulances.
	for o in range(n_nations):
		var cas := float(casualties.get(o, 0.0))
		if cas <= 0.01:
			casualties[o] = 0.0
			continue
		var cap := float(hospital_cap.get(o, 0.0))
		var amb_bonus := 0.0
		for d in dispatches:
			if d.kind == "ambulance" and int(d.owner) == o and d.state == "working":
				amb_bonus += 18.0
		var treated := (2.2 + cap * 0.14 + amb_bonus * 0.25) * dt
		casualties[o] = maxf(0.0, cas - treated)
		var overload := maxf(0.0, casualties[o] - maxf(cap, 15.0))
		if overload > 0.0:
			if o == 0 and w.get("economy") != null and w.economy != null:
				w.economy.health = clampf(float(w.economy.health) - minf(1.8, overload * 0.018) * dt, 10.0, 100.0)
			if w.get("support") != null and w.support != null:
				w.support.change(o, -minf(0.25, overload * 0.0025) * w.support.sensitivity(o) * dt)
		elif o == 0 and cap > 0.0 and w.get("economy") != null and w.economy != null and float(w.economy.health) < 85.0:
			w.economy.health = minf(85.0, float(w.economy.health) + 0.35 * dt)

	for b in w.buildings:
		if not b.dead and float(b.get("casualty_site", 0.0)) > 0.0:
			var rate := 8.5 if b.get("ambulance_on_scene", false) else 1.8
			b.casualty_site = maxf(0.0, float(b.get("casualty_site", 0.0)) - rate * dt)

func _set_blackout(b: Dictionary, state: bool) -> void:
	if bool(b.get("blackout", false)) == state:
		return
	b.blackout = state
	if b.get("root") == null or not is_instance_valid(b.root):
		return
	var dark_mat := _dark_window_mat()
	for mi in (b.root as Node3D).find_children("*", "MeshInstance3D", true, false):
		if mi.name == "DamageProps" or mi.name == "FireVisual" or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var src_mat: Material = mi.mesh.surface_get_material(s)
			var role := src_mat.resource_name if src_mat != null else ""
			if role in ["glow_warm", "glow_cyan", "glow_dim"]:
				if state:
					mi.set_surface_override_material(s, dark_mat)
				else:
					var owner_col := Color(w.map.nations[int(b.owner)].color) if w.get("map") != null and int(b.owner) < w.map.nations.size() else Color.WHITE
					var orig: Material = preload("res://scripts/building_models.gd").blend_material(role, owner_col)
					var stg := int(b.get("damage_stage", 0))
					mi.set_surface_override_material(s, preload("res://scripts/building_fires.gd")._damaged_material(orig, stg) if stg > 0 else orig)

# ---------------------------------------------------------------- physical emergency vehicles (1A)

func _reconcile_dispatches() -> void:
	# Clean finished dispatches
	for i in range(dispatches.size() - 1, -1, -1):
		var d: Dictionary = dispatches[i]
		if d.state == "done" or d.station == null or d.station.get("dead", false):
			if d.target != null:
				if d.kind == "fire_engine": d.target.fire_engine_on_scene = false
				else: d.target.ambulance_on_scene = false
			if d.node != null and is_instance_valid(d.node):
				d.node.queue_free()
			dispatches.remove_at(i)

	# 1. Dispatch Fire Engines from active Fire Stations to burning buildings with assigned crews.
	for b in w.buildings:
		if b.dead or not b.built or float(b.get("fire", 0.0)) <= 0.01 or int(b.get("fire_crews", 0)) <= 0:
			continue
		if _has_dispatch_for("fire_engine", b):
			continue
		var station = _nearest_active_station(int(b.owner), "fireStation", b.root.position)
		if station != null:
			_spawn_dispatch("fire_engine", int(b.owner), station, b)

	# 2. Dispatch Ambulances from active Hospitals to casualty sites.
	for b in w.buildings:
		if b.dead or not b.built or float(b.get("casualty_site", 0.0)) <= 3.0:
			continue
		if _has_dispatch_for("ambulance", b):
			continue
		var hosp = _nearest_active_station(int(b.owner), "hospital", b.root.position)
		if hosp != null and _active_count_from(hosp) < 2:
			_spawn_dispatch("ambulance", int(b.owner), hosp, b)

func _has_dispatch_for(kind: String, target: Dictionary) -> bool:
	for d in dispatches:
		if d.kind == kind and is_same(d.target, target) and d.state != "returning":
			return true
	return false

func _active_count_from(station: Dictionary) -> int:
	var n := 0
	for d in dispatches:
		if is_same(d.station, station):
			n += 1
	return n

func _nearest_active_station(owner: int, key: String, at: Vector3) -> Variant:
	var best = null
	var best_d := INF
	for b in w.buildings:
		if b.dead or not b.built or int(b.owner) != owner or str(b.key) != key or w.disabled(b):
			continue
		var d := Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length()
		if d < best_d:
			best_d = d
			best = b
	return best

## Computes road hex waypoints using BFS over intact road links in logistics.gd.
func _compute_route(owner: int, from_pos: Vector3, to_pos: Vector3) -> Dictionary:
	var logi = w.get("logistics")
	if logi == null:
		return {"points": [from_pos, to_pos], "on_road": false}
	var h_start: Vector2i = logi.world_hex(from_pos)
	var h_goal: Vector2i = logi.world_hex(to_pos)
	if h_start == h_goal:
		return {"points": [from_pos, to_pos], "on_road": true}

	var adj := {}
	for e in logi.edges.values():
		if e.kind == "road" and float(e.hp) > 0.0 and (int(e.owner) == owner or (w.diplomacy != null and w.diplomacy.allied(owner, int(e.owner)))):
			if not adj.has(e.a): adj[e.a] = []
			if not adj.has(e.b): adj[e.b] = []
			adj[e.a].append(e.b)
			adj[e.b].append(e.a)
	if w.get("district_hex") != null:
		for h in w.district_hex.keys():
			var db: Dictionary = w.district_hex[h]
			if db.get("dead", false) or int(db.get("owner", -1)) != owner:
				continue
			for dir in logi.DIRECTIONS:
				var nh: Vector2i = h + dir
				if w.district_hex.has(nh):
					var ndb: Dictionary = w.district_hex[nh]
					if not ndb.get("dead", false) and int(ndb.get("owner", -1)) == owner:
						if not adj.has(h): adj[h] = []
						if not (nh in adj[h]): adj[h].append(nh)

	# Find road hex closest to start (within 1 hex) and road hex closest to goal (within 2 hexes)
	var start_hex := h_start
	if not adj.has(start_hex):
		for dir in logi.DIRECTIONS:
			if adj.has(h_start + dir):
				start_hex = h_start + dir
				break
	if not adj.has(start_hex):
		return {"points": [from_pos, to_pos], "on_road": false}

	var queue: Array[Vector2i] = [start_hex]
	var prev := {start_hex: start_hex}
	var best_end := start_hex
	var best_dist: int = logi.hex_distance(start_hex, h_goal)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d_goal: int = logi.hex_distance(cur, h_goal)
		if d_goal < best_dist:
			best_dist = d_goal
			best_end = cur
		if cur == h_goal:
			best_end = cur
			best_dist = 0
			break
		for nb in adj.get(cur, []):
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)

	if best_end == start_hex or best_dist > 2:
		return {"points": [from_pos, to_pos], "on_road": false}

	var hex_chain: Array[Vector2i] = []
	var step := best_end
	while step != start_hex:
		hex_chain.push_front(step)
		step = prev[step]
	hex_chain.push_front(start_hex)

	var pts: Array[Vector3] = [from_pos]
	for h in hex_chain:
		pts.append(logi.hex_center(h))
	pts.append(to_pos)
	return {"points": pts, "on_road": true}

func _spawn_dispatch(kind: String, owner: int, station: Dictionary, target: Dictionary) -> void:
	var start_pos: Vector3 = station.root.position + Vector3(3.5, 0.0, 3.5)
	start_pos.y = w.height_at(start_pos.x, start_pos.z)
	var goal_pos: Vector3 = target.root.position
	var dir := Vector3(start_pos.x - goal_pos.x, 0.0, start_pos.z - goal_pos.z)
	if dir.length() < 0.5:
		dir = Vector3(1.0, 0.0, 0.0)
	var park_pos: Vector3 = goal_pos + dir.normalized() * 7.8
	park_pos.y = w.height_at(park_pos.x, park_pos.z)

	var route := _compute_route(owner, start_pos, park_pos)
	var vnode := _build_emergency_vehicle_mesh(kind)
	add_child(vnode.root)
	vnode.root.position = start_pos
	dispatches.append({
		"kind": kind,
		"owner": owner,
		"station": station,
		"target": target,
		"node": vnode.root,
		"beacon_l": vnode.beacon_l,
		"beacon_r": vnode.beacon_r,
		"spray": vnode.spray,
		"path": route.points,
		"wp": 1,
		"on_road": bool(route.on_road),
		"state": "outbound",
		"timer": 0.0,
	})

func _build_emergency_vehicle_mesh(kind: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "FireEngine" if kind == "fire_engine" else "Ambulance"
	var body_col := Color("c82820") if kind == "fire_engine" else Color("f0eee8")
	var stripe_col := Color("f2ece0") if kind == "fire_engine" else Color("d82c24")
	var body_mat := _color_mat("em_body_" + kind, body_col, 0.0, 0.42)
	var stripe_mat := _color_mat("em_stripe_" + kind, stripe_col, 0.0, 0.45)
	var dark_mat := _color_mat("em_dark", Color(0.10, 0.11, 0.13), 0.0, 0.85)
	var metal_mat := _color_mat("em_metal", Color(0.76, 0.78, 0.82), 0.0, 0.35)
	var red_glow := _color_mat("em_red_glow", Color(1.0, 0.18, 0.12), 3.4, 0.2)
	var blue_glow := _color_mat("em_blue_glow", Color(0.18, 0.55, 1.0), 3.4, 0.2)

	# Chassis & main body
	var hull := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(1.55, 1.15, 3.8 if kind == "fire_engine" else 3.1)
	hbox.material = body_mat
	hull.mesh = hbox
	hull.position = Vector3(0.0, 0.82, 0.0)
	root.add_child(hull)

	# Contrasting emergency stripe / cross band
	var stripe := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(1.59, 0.24, 3.82 if kind == "fire_engine" else 3.12)
	sbox.material = stripe_mat
	stripe.mesh = sbox
	stripe.position = Vector3(0.0, 0.78, 0.0)
	root.add_child(stripe)

	# Cab & windshield
	var cab := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(1.48, 0.55, 1.15)
	cbox.material = dark_mat
	cab.mesh = cbox
	cab.position = Vector3(0.0, 1.12, 1.15 if kind == "fire_engine" else 0.85)
	root.add_child(cab)

	if kind == "fire_engine":
		# Roof ladder & water monitor cannon
		var ladder := MeshInstance3D.new()
		var lbox := BoxMesh.new()
		lbox.size = Vector3(0.48, 0.14, 3.2)
		lbox.material = metal_mat
		ladder.mesh = lbox
		ladder.position = Vector3(0.0, 1.48, -0.2)
		root.add_child(ladder)

	# 4 wheels
	for sx in [-0.72, 0.72]:
		for sz in [-1.1, 1.1]:
			var w_mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.32
			cyl.bottom_radius = 0.32
			cyl.height = 0.24
			cyl.material = dark_mat
			w_mi.mesh = cyl
			w_mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			w_mi.position = Vector3(sx, 0.32, sz)
			root.add_child(w_mi)

	# Emergency roof beacons (flashing red & blue)
	var beacon_l := MeshInstance3D.new()
	var bl_mesh := BoxMesh.new()
	bl_mesh.size = Vector3(0.42, 0.18, 0.28)
	bl_mesh.material = red_glow
	beacon_l.mesh = bl_mesh
	beacon_l.position = Vector3(-0.36, 1.52, 1.1 if kind == "fire_engine" else 0.8)
	root.add_child(beacon_l)

	var beacon_r := MeshInstance3D.new()
	var br_mesh := BoxMesh.new()
	br_mesh.size = Vector3(0.42, 0.18, 0.28)
	br_mesh.material = blue_glow
	beacon_r.mesh = br_mesh
	beacon_r.position = Vector3(0.36, 1.52, 1.1 if kind == "fire_engine" else 0.8)
	root.add_child(beacon_r)

	# Water spray stream for fire engine when on-scene
	var spray: MeshInstance3D = null
	if kind == "fire_engine":
		spray = MeshInstance3D.new()
		var scyl := CylinderMesh.new()
		scyl.top_radius = 0.08
		scyl.bottom_radius = 0.26
		scyl.height = 8.5
		scyl.material = _color_mat("em_water_jet", Color(0.68, 0.88, 1.0), 1.6, 0.2)
		spray.mesh = scyl
		spray.position = Vector3(0.0, 2.8, 4.2)
		spray.rotation_degrees = Vector3(68.0, 0.0, 0.0)
		spray.visible = false
		root.add_child(spray)

	return {"root": root, "beacon_l": beacon_l, "beacon_r": beacon_r, "spray": spray}

func _update_vehicles(delta: float) -> void:
	_beacon_time += delta * 9.0
	var flash_a := sin(_beacon_time) > 0.0
	for d in dispatches:
		var node: Node3D = d.node
		if node == null or not is_instance_valid(node):
			d.state = "done"
			continue
		if d.beacon_l != null:
			d.beacon_l.visible = flash_a
		if d.beacon_r != null:
			d.beacon_r.visible = not flash_a

		var tgt: Dictionary = d.target
		var st: Dictionary = d.station
		if st == null or st.get("dead", false):
			d.state = "done"
			continue

		if d.state == "outbound":
			if tgt == null or tgt.get("dead", false) or (d.kind == "fire_engine" and float(tgt.get("fire", 0.0)) <= 0.005) or (d.kind == "ambulance" and float(tgt.get("casualty_site", 0.0)) <= 0.5):
				d.state = "returning"
				var back := _compute_route(int(d.owner), node.position, st.root.position)
				d.path = back.points
				d.wp = 1
				d.on_road = bool(back.on_road)
				continue
			if _drive_along(d, delta):
				d.state = "working"
				d.timer = 0.0
				var look_to := Vector3(tgt.root.position.x, node.position.y, tgt.root.position.z)
				if node.position.distance_to(look_to) > 0.2:
					node.look_at(look_to, Vector3.UP)
					node.rotate_object_local(Vector3.UP, PI)
				if d.kind == "fire_engine":
					tgt.fire_engine_on_scene = true
					if d.spray != null: d.spray.visible = true
				else:
					tgt.ambulance_on_scene = true

		elif d.state == "working":
			d.timer = float(d.timer) + delta
			if d.kind == "fire_engine":
				if tgt == null or tgt.get("dead", false) or float(tgt.get("fire", 0.0)) <= 0.005:
					if tgt != null: tgt.fire_engine_on_scene = false
					if d.spray != null: d.spray.visible = false
					d.state = "returning"
					var back := _compute_route(int(d.owner), node.position, st.root.position)
					d.path = back.points
					d.wp = 1
					d.on_road = bool(back.on_road)
				elif d.spray != null:
					d.spray.visible = true
					d.spray.scale.y = 0.92 + 0.12 * sin(_beacon_time * 1.7)
			else:
				if tgt == null or tgt.get("dead", false) or float(tgt.get("casualty_site", 0.0)) <= 0.5 or float(d.timer) >= 14.0:
					if tgt != null: tgt.ambulance_on_scene = false
					d.state = "returning"
					var back := _compute_route(int(d.owner), node.position, st.root.position)
					d.path = back.points
					d.wp = 1
					d.on_road = bool(back.on_road)

		elif d.state == "returning":
			if d.spray != null:
				d.spray.visible = false
			if _drive_along(d, delta):
				d.state = "done"

func _drive_along(d: Dictionary, delta: float) -> bool:
	var pts: Array = d.path
	var wp := int(d.wp)
	if wp >= pts.size():
		return true
	var node: Node3D = d.node
	var speed := ROAD_SPEED if bool(d.on_road) else OFFROAD_SPEED
	var goal: Vector3 = pts[wp]
	var flat_cur := Vector2(node.position.x, node.position.z)
	var flat_goal := Vector2(goal.x, goal.z)
	var vec := flat_goal - flat_cur
	var dist := vec.length()
	var step := speed * delta
	if dist <= maxf(step, 0.8):
		node.position = Vector3(goal.x, w.height_at(goal.x, goal.z), goal.z)
		d.wp = wp + 1
		return int(d.wp) >= pts.size()
	var dir := vec / dist
	var nx := flat_cur.x + dir.x * step
	var nz := flat_cur.y + dir.y * step
	node.position = Vector3(nx, w.height_at(nx, nz), nz)
	var yaw := atan2(dir.x, dir.y)
	node.rotation = Vector3(0.0, yaw, 0.0)
	return false

# ---------------------------------------------------------------- status & serialization

func hud_status(b: Dictionary) -> String:
	if b.get("dead", false) or not b.get("built", false):
		return ""
	var lines := PackedStringArray()
	var o := int(b.owner)
	if b.get("blackout", false):
		lines.append("POWER OUTAGE — local grid blacked out (-35% output/radar). Repair power plants or add a Solar Farm.")
	if float(b.get("casualty_site", 0.0)) > 1.0:
		lines.append("Casualties on site (%d) — %s" % [ceili(float(b.casualty_site)), "Ambulance crew treating wounded." if b.get("ambulance_on_scene", false) else "awaiting Hospital response."])
	var key := str(b.key)
	if key in ["powerPlant", "nuclearReactor", "solarFarm"]:
		var sup := int(roundf(float(power_supply.get(o, BASE_MUNICIPAL_MW))))
		var dem := int(roundf(float(power_demand.get(o, 0.0))))
		lines.append("Power Grid: %d MW supply / %d MW demand (%s)." % [sup, dem, "surplus" if sup >= dem else "DEFICIT — brownouts active"])
	elif key == "hospital":
		var cas := int(roundf(float(casualties.get(o, 0.0))))
		var cap := int(roundf(float(hospital_cap.get(o, 0.0))))
		lines.append("Medical Service: %d active casualties / %d bed capacity." % [cas, cap])
	return "\n".join(lines)

func capture() -> Dictionary:
	var cas := {}
	for k in casualties:
		cas[str(k)] = casualties[k]
	return {"casualties": cas}

func restore(data: Dictionary) -> void:
	casualties.clear()
	for k in data.get("casualties", {}):
		casualties[int(k)] = float(data.casualties[k])
	for d in dispatches:
		if d.node != null and is_instance_valid(d.node):
			d.node.queue_free()
	dispatches.clear()
	_update_power_and_casualties(0.1)
