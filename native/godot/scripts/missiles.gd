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
## Requirements stand in for the browser's discoveries: anti-ship missiles
## need a Shipyard, strategic missiles an Ammo Depot, nukes uranium.

signal changed

const REQUIRES := {"navalEngineering": ["shipyard", "a Shipyard"], "ballisticTech": ["ammoDepot", "an Ammo Depot"]}
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
	return cfg.types.get(key, {})

func capacity() -> int:
	return int(cfg.baseCap) + int(cfg.capPerDepot) * world.economy.owned("ammoDepot")

func stored() -> int:
	var n := 0
	for key in stock:
		n += int(stock[key])
	return n

func queued() -> int:
	var n := 0
	for b in world.buildings:
		if b.owner == 0 and not b.dead:
			n += b.queue.filter(func(q): return String(q).begins_with("missile:")).size()
	return n

## "" when the player may build this type, otherwise why not.
func locked(key: String) -> String:
	var need: String = def_of(key).get("needsDiscovery", "")
	if REQUIRES.has(need) and world.economy.owned(REQUIRES[need][0]) == 0:
		return "Needs %s" % REQUIRES[need][1]
	return ""

func silos(owner := 0) -> Array:
	return world.buildings.filter(func(b): return b.owner == owner and b.key == "missileSilo" and b.built and not b.dead)

## Queues a missile at `silo`. Returns an error or "".
func produce(silo: Dictionary, key: String) -> String:
	var def := def_of(key)
	if def.is_empty() or not silo.built:
		return ""
	var why := locked(key)
	if why != "":
		return "%s: %s." % [def.name, why.to_lower()]
	if silo.queue.size() >= 5:
		return "Queue is full"
	if stored() + queued() >= capacity():
		return "Missile storage full (%d). Build Ammo Depots for +%d each." % [capacity(), int(cfg.capPerDepot)]
	if not world.economy.pay(def.cost):
		return "Not enough %s" % world.economy.missing(def.cost)
	silo.queue.append("missile:" + key)
	changed.emit()
	return ""

## Called by world.update_training when a silo finishes one.
func finished(key: String) -> void:
	stock[key] = int(stock.get(key, 0)) + 1
	world.hud.notice("%s ready (%d/%d stored)." % [def_of(key).name, stored(), capacity()])
	changed.emit()

func build_time(key: String) -> float:
	return float(def_of(key).get("buildTime", 20))

# ---------------------------------------------------------------- launching

func launch(key: String, target: Vector3) -> String:
	if int(stock.get(key, 0)) <= 0:
		return "No %s in storage." % def_of(key).get("name", key)
	var from_silos := silos()
	if from_silos.is_empty():
		return "Missiles launch from a Missile Silo."
	var silo: Dictionary = from_silos[0]
	for s in from_silos:
		if s.root.position.distance_to(target) < silo.root.position.distance_to(target):
			silo = s
	stock[key] -= 1
	var def := def_of(key)
	var from: Vector3 = silo.root.position + Vector3.UP * 3.0
	target.y = maxf(world.height_at(target.x, target.z), float(world.map.seaLevel))
	var dist := Vector2(target.x - from.x, target.z - from.z).length()
	var arc: bool = def.get("arc", false)
	var node := missile_mesh(key)
	add_child(node)
	node.global_position = from
	flying.append({"type": key, "node": node, "from": from, "to": target, "t": 0.0, "owner": 0,
		"dur": clampf(dist / float(def.speed), 2.5, 9.0) if arc else maxf(0.6, dist / float(def.speed)) + 1.0,
		"arc": arc, "trail": 0.0, "peak": maxf(60.0, dist * 0.45)})
	world.effects.explosion(from, 1.2, true)
	world.effects.burn(from, 6.0)
	changed.emit()
	if key == "nuke":
		return "NUCLEAR MISSILE LAUNCHED. %d left." % stock[key]
	return "%s launched." % def.name

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
			impact(m.type, m.to, m.owner)

func impact(key: String, at: Vector3, owner: int) -> void:
	var def := def_of(key)
	var radius := float(def.radius)
	var dmg := float(def.dmg)
	var special: String = def.get("special", "")
	var nuclear := key == "nuke"
	world.effects.explosion(at + Vector3.UP, radius * 0.22, true)
	if nuclear:
		world.effects.mushroom(at, radius)
	elif radius > 15.0:
		world.effects.explosion(at + Vector3.UP * 3.0, radius * 0.16, false)
	world.logistics.damage_at(at, radius if nuclear else radius * 0.4, dmg)
	var source := {"owner": owner, "dead": true, "key": "missile"}
	var hit := []
	for ent in world.units + world.buildings:
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
			"emp":
				var cls: String = world.target_class(ent)
				if cls in ["building", "air", "naval", "armor", "light"]:
					ent.disabled_until = maxf(ent.get("disabled_until", 0.0), world.game_time + EMP_SECONDS)
				mult = 0.25 if building else 0.45
		hit.append(ent)
		world.damage(ent, dmg * mult * (1.0 - 0.5 * d / radius), source)
	if special == "emp":
		world.effects.emp_flash(at, radius)
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
	return {"stock": stock}

func restore(data: Dictionary) -> void:
	for key in stock:
		stock[key] = int(data.get("stock", {}).get(key, 0))
	for m in flying:
		m.node.queue_free()
	flying.clear()
