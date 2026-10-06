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

const EMP_SECONDS := 35.0

var world: Node
var cfg: Dictionary
var stock := {}
var flying: Array = []   # {type, node, from, to, t, dur, arc, trail}
var clock := 0.0

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

func capacity(cat := "conventional") -> int:
	if cat == "conventional":
		return int(cfg.baseCap) + int(cfg.capPerDepot) * world.economy.owned("ammoDepot")
	return PER_FACILITY * world.economy.owned(FACILITY[cat])

func stored(cat := "conventional") -> int:
	var n := 0
	for key in stock:
		if category(key) == cat:
			n += int(stock[key])
	return n

func queued(cat := "conventional") -> int:
	var n := 0
	for b in world.buildings:
		if b.owner == 0 and not b.dead:
			n += b.queue.filter(func(q): return String(q).begins_with("missile:") and category(String(q).substr(8)) == cat).size()
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
const LAUNCH_SHIPS := ["nuclearSub", "destroyer"]

## Missile ships of `owner` able to fire (alive, not disabled).
func launch_ships(owner := 0) -> Array:
	return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in LAUNCH_SHIPS and not world.disabled(u))

func silos(owner := 0) -> Array:
	return world.buildings.filter(func(b): return b.owner == owner and b.key == "missileSilo" and b.built and not b.dead)

## Payload-specific launch validation, shared by human and rival attacks.
func platforms_for(key: String, owner := 0) -> Array:
	var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(world, owner, key)
	if kind == "air":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in ["jet", "bomber", "stealthFighter", "raider"] and not world.disabled(u) and u.get("air_state", "ready") == "ready")
	if kind == "drone":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and u.key in ["drone", "fpvTeam"] and not world.disabled(u) and u.get("air_state", "ready") == "ready")
	if kind == "air_or_sea":
		return world.units.filter(func(u): return u.owner == owner and not u.dead and not world.disabled(u) and (u.key in ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"] or (u.key in ["jet", "bomber", "stealthFighter", "raider"] and u.get("air_state", "ready") == "ready")))
	if kind in ["sea", "sub"]:
		return world.units.filter(func(u): return u.owner == owner and not u.dead and not world.disabled(u) and u.key in (["nuclearSub"] if kind == "sub" or category(key) == "nuclear" else ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"]))
	if kind in ["strategic", "ground_or_sea"]:
		var ships: Array = world.units.filter(func(u): return u.owner == owner and not u.dead and not world.disabled(u) and u.key in (["nuclearSub"] if kind == "strategic" else ["submarine", "nuclearSub", "destroyer", "corvette", "aegisCruiser"]))
		return silos(owner).filter(func(b): return not world.disabled(b)) + ships
	return silos(owner).filter(func(b): return not world.disabled(b))

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
	if stored(cat) + queued(cat) >= capacity(cat):
		if cat == "conventional":
			return "Missile storage full (%d). Build Ammo Depots for +%d each." % [capacity(), int(cfg.capPerDepot)]
		return "Storage full (%d): each %s holds %d." % [capacity(cat), world.building_defs.get(FACILITY[cat], {}).get("name", ""), PER_FACILITY]
	var price := production_cost(key)
	if not world.economy.pay(price):
		return "Not enough %s" % world.economy.missing(price)
	world.queue_paid_order(silo, "missile:" + key, price)
	changed.emit()
	return ""

func production_cost(key: String) -> Dictionary:
	var price := {}
	var cost: Dictionary = def_of(key).get("cost", {})
	for resource in cost:
		price[resource] = roundf(float(cost[resource]) * preload("res://scripts/national_profile.gd").cost_mult(world, 0, "missile"))
	return price

## Called by world.update_training when a silo finishes one.
func finished(key: String) -> void:
	stock[key] = int(stock.get(key, 0)) + 1
	world.hud.notice("%s ready (%d/%d stored)." % [def_of(key).name, stored(category(key)), capacity(category(key))])
	changed.emit()

func build_time(key: String) -> float:
	return float(def_of(key).get("buildTime", 20))

# ---------------------------------------------------------------- launching

## Fires `key` at `target` from `platform` (a silo or a missile ship), or
## from the platform nearest the target when none is given.
func launch(key: String, target: Vector3, platform = null) -> String:
	var blocked := locked(key)
	if blocked != "": return blocked
	if int(stock.get(key, 0)) <= 0:
		return "No %s in storage." % def_of(key).get("name", key)
	if def_of(key).get("nuclear", key == "nuke") and world.get("defcon") != null and world.defcon.release_blocked() != "":
		return world.defcon.release_blocked()   # the escalation ladder (defcon.gd)
	var platforms: Array = platforms_for(key)
	if def_of(key).get("sub_only", false):
		# A torpedo: from a nuclear submarine, at a coast (wmd.gd: Poseidon).
		if platforms.is_empty():
			return "%s requires a strategic submarine." % def_of(key).name
		if world.water_near(target, 40) == null:
			return "%s needs a target on or near the sea." % def_of(key).name
	if platforms.is_empty():
		return "Needs a compatible %s launch platform." % load("res://scripts/arsenal_catalog.gd").platform_kind(world, 0, key)
	if platform != null and not platform in platforms:
		return "This platform cannot launch that national payload."
	if platform == null:
		platform = platforms[0]
		for s in platforms:
			if s.node.position.distance_to(target) < platform.node.position.distance_to(target):
				platform = s
	stock[key] -= 1
	var def := def_of(key)
	var ship: bool = not platform.get("is_building", false)
	fly(key, platform.node.position + Vector3.UP * (1.5 if ship else 3.0), target, 0, ship)
	changed.emit()
	if key == "nuke":
		return "NUCLEAR MISSILE LAUNCHED. %d left." % stock[key]
	return "%s launched." % def.name

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
	if world == null:
		return
	clock += delta
	for i in range(flying.size() - 1, -1, -1):
		var m: Dictionary = flying[i]
		m.t += delta
		var f: float = minf(m.t / m.dur, 1.0)
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
	var dmg := float(def.dmg)*1.75
	var special: String = def.get("special", "")
	var nuclear: bool = key == "nuke" or def.get("nuclear", false)
	# A burst high above (HEMP) or a microwave pulse (HPM) leaves the ground intact (wmd.gd).
	var no_blast: bool = special in ["hemp", "emp"]
	var Conv := preload("res://scripts/conventional_missiles.gd")
	if special == "antiRadar":
		at = Conv.home(world, at, owner)   # it rides the nearest air-defence radar's beam
	if not no_blast:
		world.effects.explosion(at + Vector3.UP, minf(radius, 60.0) * 0.22, true)
	if nuclear and not no_blast:
		world.effects.mushroom(at, minf(radius, 70.0))
	elif radius > 15.0 and not no_blast:
		world.effects.explosion(at + Vector3.UP * 3.0, radius * 0.16, false)
	if not no_blast:
		world.logistics.damage_at(at, radius if nuclear else radius * 0.4, dmg, nuclear)
	var source := {"owner": owner, "dead": true, "key": "missile", "pierce": special in ["penetrator", "thermobaric"]}
	var hit := []
	for ent in (world.units + world.buildings) if not no_blast else []:
		if ent.dead:
			continue
		var p: Vector3 = ent.node.position
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if ent.get("is_building", false):
			d = maxf(0.0, d - ent.footprint * 0.4)
		if d > radius:
			continue
		var mult := 1.0
		var building: bool = ent.get("is_building", false)
		match special:
			"cluster":
				mult = 0.35 if building else 1.75
			"antiShip":
				mult = 3.0 if ent.get("naval", false) else 0.25
			"hgv":
				mult = 2.5 if ent.get("naval", false) else 1.0
			"brahmos":
				mult = 2.0 if ent.get("naval", false) else 1.0
			"penetrator":
				# It bursts underground: what is built is crushed, bunkers too;
				# a conventional one does little to troops in the open.
				mult = 3.0 if building else (1.0 if nuclear else 0.35)
			"thermobaric", "antiRadar":
				mult = Conv.mult(special, ent, building)
				if special == "antiRadar" and ent.key in Conv.EMITTERS:
					ent.disabled_until = maxf(float(ent.get("disabled_until", 0.0)), world.game_time + Conv.SILENCE)
			"neutron":
				# Neutrons pass through armour and walls: crews and people die, buildings stand.
				# Its blast is small: buildings suffer only near the burst.
				mult = (0.2 if d < radius * 0.35 else 0.0) if building else (1.2 if ent.get("vehicle", false) else 1.0)
		hit.append(ent)
		world.damage(ent, dmg * mult * (1.0 - 0.5 * d / radius), source)
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
	return {"stock": stock.duplicate(), "flying": flights, "clock": clock}

func restore(data: Dictionary) -> void:
	for key in stock:
		stock[key] = int(data.get("stock", {}).get(key, 0))
	for m in flying:
		m.node.queue_free()
	flying.clear()
	clock = float(data.get("clock", 0.0))
	var buildings: Array = world.buildings.filter(func(b): return not b.dead)
	var units: Array = world.units.filter(func(u): return not u.dead)
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
