extends RefCounted
## Field fortifications and battlefield obstacles:
##   trench    infantry fighting trench (garrison up to 3 infantry, strong cover)
##   dugout    forward earth-and-timber bunker (garrison up to 4 infantry, heavy cover)
##   hedgehog  steel Czech hedgehogs ("X" beams): blocks hostile vehicles & tanks
##   atDitch   excavated anti-tank ditch: blocks hostile vehicles & tanks; needs engineers to breach
##
## Friendly infantry can enter trenches/dugouts for protection and fire out, and exit on move orders.
## Engineering vehicles (mineClearer) breach hostile hedgehogs and fill anti-tank ditches.

const TRENCH_COST := 20.0
const DUGOUT_COST := 45.0
const HEDGEHOG_COST := 15.0
const DITCH_COST := 25.0

const TRENCH_BUILD_TIME := 3.5
const DUGOUT_BUILD_TIME := 5.5
const HEDGEHOG_BUILD_TIME := 2.5
const DITCH_BUILD_TIME := 4.5

const TRENCH_REACH := 4.8
const DUGOUT_REACH := 5.5
const OBSTACLE_BLOCK_RADIUS := 3.0
const BREACH_REACH := 14.0
const BREACH_TIME := 3.5

const GARRISON_CAP := {"trench": 3, "dugout": 4}
const COSTS := {"trench": TRENCH_COST, "dugout": DUGOUT_COST, "hedgehog": HEDGEHOG_COST, "atDitch": DITCH_COST}
const BUILD_TIMES := {"trench": TRENCH_BUILD_TIME, "dugout": DUGOUT_BUILD_TIME, "hedgehog": HEDGEHOG_BUILD_TIME, "atDitch": DITCH_BUILD_TIME}
const MAX_HP := {"trench": 150.0, "dugout": 280.0, "hedgehog": 320.0, "atDitch": 460.0}
const OBSTACLES := ["hedgehog", "atDitch"]
const SHELTERS := ["trench", "dugout"]

var world: Node
var entries: Array[Dictionary] = []
var _mats := {}

func setup(world_node: Node) -> void:
	world = world_node

func _mat(key: String, color: Color, rough := 0.95, metallic := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metallic
		_mats[key] = m
	return _mats[key]

static func is_obstacle(kind: String) -> bool:
	return kind in OBSTACLES

static func is_shelter(kind: String) -> bool:
	return kind in SHELTERS

static func cost_of(kind: String) -> float:
	return float(COSTS.get(kind, TRENCH_COST))

static func _can_build(u: Dictionary, kind: String) -> bool:
	if u.dead or u.get("fly", false) or u.get("naval", false):
		return false
	if kind in ["hedgehog", "atDitch"]:
		return u.key == "worker" or u.key == "mineLayer" or (not u.vehicle and u.key != "worker")
	return not u.vehicle and u.key != "worker"

## Orders selected units to build a fortification or obstacle where they stand.
func order_dig(selected: Array, kind := "trench") -> int:
	var builders := selected.filter(func(u): return u.owner == 0 and _can_build(u, kind))
	if builders.is_empty():
		return 0
	var cost := cost_of(kind)
	var started := 0
	for u in builders:
		if world.economy == null or float(world.economy.res.get("money", 0.0)) < cost:
			if started == 0 and world.hud != null:
				world.hud.notice("Need $%d to build %s." % [int(cost), _label(kind)])
			break
		var pos: Vector3 = u.node.position
		if world.height_at(pos.x, pos.z) < float(world.map.seaLevel) + 0.4:
			continue
		if _near_existing(pos, 3.2):
			continue
		world.economy.res.money -= cost
		exit_unit(u)
		u.target = null
		u.enemy = null
		var ent := _spawn(u.owner, pos, float(u.heading), kind, false)
		u.digging = ent
		started += 1
	if started > 0 and world.hud != null:
		world.hud.notice("Constructing %d %s." % [started, _label(kind)])
	return started

## Places a defensive line of `kind` from `start_pos` to `end_pos` and assigns selected builders.
func order_line(selected: Array, kind: String, start_pos: Vector3, end_pos: Vector3) -> int:
	var builders := selected.filter(func(u): return u.owner == 0 and _can_build(u, kind))
	if builders.is_empty():
		if world.hud != null:
			world.hud.notice("Select infantry or engineers to build a %s line." % _label(kind))
		return 0
	var flat_a := Vector2(start_pos.x, start_pos.z)
	var flat_b := Vector2(end_pos.x, end_pos.z)
	var dist := flat_a.distance_to(flat_b)
	var spacing := 4.4 if is_obstacle(kind) else 5.2
	var count := clampi(int(floorf(dist / spacing)) + 1, 1, 16)
	var dir := (flat_b - flat_a).normalized() if dist > 0.2 else Vector2(0, 1)
	var heading := atan2(dir.x, dir.y)
	var cost := cost_of(kind)
	var placed := 0
	var sites: Array[Dictionary] = []
	for i in range(count):
		var t := 0.0 if count == 1 else float(i) / float(count - 1)
		var p2 := flat_a.lerp(flat_b, t)
		var pos := Vector3(p2.x, world.height_at(p2.x, p2.y), p2.y)
		if pos.y < float(world.map.seaLevel) + 0.4:
			continue
		if _near_existing(pos, 3.0):
			continue
		if world.economy == null or float(world.economy.res.get("money", 0.0)) < cost:
			if placed == 0 and world.hud != null:
				world.hud.notice("Need $%d per %s." % [int(cost), _label(kind)])
			break
		world.economy.res.money -= cost
		var ent := _spawn(0, pos, heading, kind, false)
		sites.append(ent)
		placed += 1
	if placed > 0:
		for i in range(builders.size()):
			var u: Dictionary = builders[i]
			exit_unit(u)
			var site: Dictionary = sites[i % sites.size()]
			u.digging_target = site
			world.order_move([u], site.pos)
		if world.hud != null:
			world.hud.notice("Defence line ordered: %d %s segments." % [placed, _label(kind)])
	return placed

func _near_existing(pos: Vector3, min_gap: float) -> bool:
	for e in entries:
		if not e.dead and Vector2(e.pos.x - pos.x, e.pos.z - pos.z).length() < min_gap:
			return true
	return false

static func _label(kind: String) -> String:
	match kind:
		"dugout": return "forward bunker"
		"hedgehog": return "anti-tank hedgehog"
		"atDitch": return "anti-tank ditch"
		_: return "fighting trench"

## Returns a built friendly shelter near `world_pos` (for right-click garrisoning).
func shelter_at(world_pos: Vector3, owner_id: int, radius := 5.0) -> Dictionary:
	var best := {}
	var best_d := radius
	for e in entries:
		if e.dead or not e.built or int(e.owner) != owner_id or not is_shelter(e.kind):
			continue
		var d := Vector2(e.pos.x - world_pos.x, e.pos.z - world_pos.z).length()
		if d < best_d:
			best_d = d
			best = e
	return best

## Orders selected infantry to enter a friendly trench or forward bunker.
func order_enter(selected: Array, ent: Dictionary) -> int:
	if ent.is_empty() or ent.dead or not ent.built or not is_shelter(ent.kind):
		return 0
	var cap := int(GARRISON_CAP.get(ent.kind, 3))
	var garrison: Array = ent.get("garrison", [])
	garrison = garrison.filter(func(u): return not u.dead and u.get("garrisoned_in") == ent)
	ent.garrison = garrison
	var ordered := 0
	for u in selected:
		if u.dead or u.owner != ent.owner or u.vehicle or u.get("fly", false) or u.get("naval", false) or u.key == "worker":
			continue
		if garrison.size() + ordered >= cap:
			break
		exit_unit(u)
		u.entering_fort = ent
		world.order_move([u], ent.pos)
		ordered += 1
	if ordered > 0 and world.hud != null:
		world.hud.notice("Infantry moving into %s (%d/%d)." % [_label(ent.kind), garrison.size() + ordered, cap])
	return ordered

## Removes `unit` from whichever trench/dugout it is garrisoned in.
func exit_unit(unit: Dictionary) -> void:
	unit.erase("entering_fort")
	unit.erase("digging_target")
	var ent = unit.get("garrisoned_in")
	if ent != null and typeof(ent) == TYPE_DICTIONARY:
		var g: Array = ent.get("garrison", [])
		g.erase(unit)
		_refresh_garrison_badge(ent)
	unit.erase("garrisoned_in")

## Ejects all infantry from trenches/dugouts among `selected`.
func order_exit(selected: Array) -> int:
	var count := 0
	for u in selected:
		if u.get("garrisoned_in") != null:
			exit_unit(u)
			count += 1
	if count > 0 and world.hud != null:
		world.hud.notice("%d infantry exited fortifications." % count)
	return count

func _spawn(owner_id: int, pos: Vector3, heading: float, kind: String, built: bool) -> Dictionary:
	pos.y = world.height_at(pos.x, pos.z)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = heading
	var model := Node3D.new()
	root.add_child(model)
	_build_mesh(model, kind)
	model.scale.y = 1.0 if built else 0.15
	world.add_child(root)
	var max_hp := float(MAX_HP.get(kind, 150.0))
	var ent := {
		"owner": owner_id,
		"pos": pos,
		"heading": heading,
		"kind": kind,
		"hp": max_hp,
		"max_hp": max_hp,
		"built": built,
		"progress": 1.0 if built else 0.05,
		"breaching": 0.0,
		"garrison": [],
		"dead": false,
		"node": root,
		"model": model,
		"badge": null,
	}
	entries.append(ent)
	return ent

func _build_mesh(parent: Node3D, kind: String) -> void:
	var earth := _mat("earth", Color("4a3c2c"), 0.98)
	var pit := _mat("pit", Color("231d16"), 0.98)
	var sandbag := _mat("sandbag", Color("9c8b68"), 0.95)
	var wood := _mat("wood", Color("5b432c"), 0.92)
	var camo := _mat("camo", Color("445238"), 0.95)
	var steel := _mat("steel", Color("3f4347"), 0.55, 0.7)

	if kind == "hedgehog":
		# Three crossed steel I-beams (Czech hedgehog) at two positions across the segment
		for offset_x in [-1.05, 1.05]:
			var cluster := Node3D.new()
			cluster.position = Vector3(offset_x, 0.55, 0.0)
			parent.add_child(cluster)
			for rot in [Vector3(0.65, 0.0, 0.65), Vector3(-0.65, 0.4, 0.65), Vector3(0.65, -0.4, -0.65)]:
				var beam := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.18, 1.55, 0.18)
				beam.mesh = box
				beam.material_override = steel
				beam.rotation = rot
				beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				cluster.add_child(beam)
		return

	if kind == "atDitch":
		# Wide excavated anti-tank trench + steep spoil berm on the defender's side
		_box(parent, Vector3(4.6, 0.12, 2.3), Vector3(0, 0.03, 0), pit)
		_box(parent, Vector3(4.6, 0.48, 0.85), Vector3(0, 0.24, -1.35), earth)
		_box(parent, Vector3(4.6, 0.28, 0.55), Vector3(0, 0.14, 1.25), earth)
		return

	# Trench & forward bunker (dugout)
	_box(parent, Vector3(3.6, 0.08, 1.3), Vector3(0, 0.03, 0), pit)
	_box(parent, Vector3(3.2, 0.05, 0.7), Vector3(0, 0.08, 0), wood)
	_box(parent, Vector3(4.0, 0.38, 0.85), Vector3(0, 0.19, 0.95), earth)
	for sx in [-1.35, -0.45, 0.45, 1.35]:
		_box(parent, Vector3(0.82, 0.24, 0.42), Vector3(sx, 0.48, 0.88), sandbag)
	_box(parent, Vector3(3.8, 0.28, 0.65), Vector3(0, 0.14, -0.90), earth)

	if kind == "dugout":
		for sx in [-1.5, 1.5]:
			for sz in [-0.45, 0.45]:
				_box(parent, Vector3(0.16, 0.95, 0.16), Vector3(sx, 0.48, sz), wood)
		_box(parent, Vector3(3.5, 0.18, 1.65), Vector3(0, 1.02, 0.0), wood)
		_box(parent, Vector3(3.7, 0.26, 1.80), Vector3(0, 1.22, 0.0), earth)
		_box(parent, Vector3(3.85, 0.06, 1.95), Vector3(0, 1.37, 0.0), camo)

func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _refresh_garrison_badge(ent: Dictionary) -> void:
	if ent.dead or not is_instance_valid(ent.get("node")):
		return
	var g: Array = ent.get("garrison", [])
	g = g.filter(func(u): return not u.dead and u.get("garrisoned_in") == ent)
	ent.garrison = g
	if g.is_empty():
		if ent.get("badge") != null and is_instance_valid(ent.badge):
			ent.badge.queue_free()
			ent.badge = null
		return
	if ent.get("badge") == null or not is_instance_valid(ent.badge):
		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 28
		lbl.pixel_size = 0.028
		lbl.position = Vector3(0, 1.85, 0)
		lbl.modulate = Color(0.95, 0.92, 0.72)
		ent.node.add_child(lbl)
		ent.badge = lbl
	ent.badge.text = "%d/%d" % [g.size(), int(GARRISON_CAP.get(ent.kind, 3))]

func update(delta: float) -> void:
	for u in world.units:
		if u.dead:
			if u.get("garrisoned_in") != null:
				exit_unit(u)
			continue
		# Handle unit walking to a defence-line site to start building it
		var dtarget = u.get("digging_target")
		if dtarget != null:
			if dtarget.dead or dtarget.built:
				u.erase("digging_target")
			elif u.node.position.distance_to(dtarget.pos) <= 3.2:
				u.target = null
				u.path = PackedVector3Array()
				u.digging = dtarget
				u.erase("digging_target")
		# Handle unit walking into a trench/dugout to garrison it
		var enter_ent = u.get("entering_fort")
		if enter_ent != null:
			if enter_ent.dead or not enter_ent.built:
				u.erase("entering_fort")
			elif Vector2(u.node.position.x - enter_ent.pos.x, u.node.position.z - enter_ent.pos.z).length() <= 3.6:
				var g: Array = enter_ent.get("garrison", [])
				var cap := int(GARRISON_CAP.get(enter_ent.kind, 3))
				if g.size() < cap and not u in g:
					g.append(u)
					enter_ent.garrison = g
					u.garrisoned_in = enter_ent
					u.target = null
					u.path = PackedVector3Array()
					_seat_garrison(enter_ent)
					_refresh_garrison_badge(enter_ent)
				u.erase("entering_fort")
		# Keep garrisoned units seated in their slot
		var g_ent = u.get("garrisoned_in")
		if g_ent != null:
			if g_ent.dead or u.target != null:
				exit_unit(u)
		# Progress active construction
		var ent = u.get("digging")
		if ent == null:
			continue
		if ent.dead or u.target != null or u.node.position.distance_to(ent.pos) > 3.8:
			u.erase("digging")
			continue
		if ent.built:
			u.erase("digging")
			continue
		var dur := float(BUILD_TIMES.get(ent.kind, TRENCH_BUILD_TIME))
		ent.progress = minf(1.0, float(ent.progress) + delta / dur)
		ent.model.scale.y = lerpf(0.15, 1.0, ent.progress)
		if ent.progress >= 1.0:
			ent.built = true
			ent.model.scale.y = 1.0
			u.erase("digging")
			# Move to the next unfinished segment in the same line if any
			_assign_next_line_site(u, ent.pos)

func _assign_next_line_site(u: Dictionary, from_pos: Vector3) -> void:
	var best := {}
	var best_d := 10.0
	for e in entries:
		if e.dead or e.built or int(e.owner) != int(u.owner):
			continue
		var d := Vector2(e.pos.x - from_pos.x, e.pos.z - from_pos.z).length()
		if d < best_d:
			best_d = d
			best = e
	if not best.is_empty():
		u.digging_target = best
		world.order_move([u], best.pos)

func _seat_garrison(ent: Dictionary) -> void:
	var g: Array = ent.get("garrison", [])
	var fwd := Vector3(sin(ent.heading), 0, cos(ent.heading))
	var right := Vector3(fwd.z, 0, -fwd.x)
	for i in range(g.size()):
		var u: Dictionary = g[i]
		if u.dead:
			continue
		var offset := (float(i) - float(g.size() - 1) * 0.5) * 0.95
		var p: Vector3 = ent.pos + right * offset
		p.y = world.height_at(p.x, p.z)
		u.node.position = p
		u.heading = ent.heading
		u.node.rotation.y = ent.heading

## True if `next` is blocked for `unit` by a built hostile anti-tank obstacle (hedgehog / atDitch).
## Infantry, aircraft, ships, and mine-clearing vehicles can approach/pass.
func blocks_vehicle(unit: Dictionary, next: Vector3) -> bool:
	if not unit.get("vehicle", false) or unit.get("fly", false) or unit.get("naval", false):
		return false
	if str(unit.get("key", "")) == "mineClearer":
		return false
	for e in entries:
		if e.dead or not e.built or not is_obstacle(e.kind):
			continue
		if not world.hostile(int(e.owner), int(unit.owner)):
			continue
		var d_next := Vector2(next.x - e.pos.x, next.z - e.pos.z).length()
		if d_next < OBSTACLE_BLOCK_RADIUS:
			var cur: Vector3 = unit.node.position
			var d_cur := Vector2(cur.x - e.pos.x, cur.z - e.pos.z).length()
			if d_next <= d_cur:
				return true
	return false

## Engineering vehicles (`mineClearer`) breach nearby hostile hedgehogs and fill anti-tank ditches.
func breach_near(clearer: Dictionary, dt: float) -> void:
	var at: Vector3 = clearer.node.position
	for i in range(entries.size() - 1, -1, -1):
		var e := entries[i]
		if e.dead or not is_obstacle(e.kind):
			continue
		if not world.hostile(int(e.owner), int(clearer.owner)):
			continue
		if Vector2(e.pos.x - at.x, e.pos.z - at.z).length() > BREACH_REACH:
			continue
		e.breaching = float(e.get("breaching", 0.0)) + dt
		if float(e.breaching) >= BREACH_TIME:
			var kind_lbl := _label(e.kind)
			var pos: Vector3 = e.pos
			_destroy(i)
			if world.get("effects") != null:
				world.effects.explosion(pos + Vector3.UP * 0.6, 2.0, true)
			if int(clearer.owner) == 0 and world.hud != null:
				world.hud.notice("ENGINEERS: breached enemy %s." % kind_lbl, pos)
			elif int(e.owner) == 0 and world.hud != null:
				world.hud.notice("DEFENCE: enemy engineers breached your %s." % kind_lbl, pos)

## Cover multiplier for `target` from `source`: infantry inside or near a built trench/dugout
## take reduced damage from direct fire, artillery, and FPV blasts.
func cover(target: Dictionary, source: Dictionary) -> float:
	if target.get("is_building", false) or target.get("vehicle", false) or target.get("fly", false) or target.get("naval", false):
		return 1.0
	var is_indirect: bool = source.has("key") and str(source.key) in ["artillery", "mlrs", "himars", "tos1a", "fpvTeam", "coastalDrone", "shaheenDrone", "mortarTeam"]
	var g_ent = target.get("garrisoned_in")
	if g_ent != null and typeof(g_ent) == TYPE_DICTIONARY and not g_ent.dead and g_ent.built:
		if g_ent.kind == "dugout":
			return 0.32 if is_indirect else 0.25
		return 0.50 if is_indirect else 0.35
	var best := 1.0
	var pos: Vector3 = target.node.position
	for e in entries:
		if e.dead or not e.built or not is_shelter(e.kind) or int(e.owner) != int(target.owner):
			continue
		var reach := DUGOUT_REACH if e.kind == "dugout" else TRENCH_REACH
		if pos.distance_to(e.pos) <= reach:
			var mult := (0.45 if is_indirect else 0.38) if e.kind == "dugout" else (0.65 if is_indirect else 0.50)
			best = minf(best, mult)
	return best

## Splash damage from explosions can degrade and destroy field fortifications.
## Anti-tank ditches resist light/medium splash and require heavy explosives or engineers.
func splash(at: Vector3, radius: float, amount: float) -> void:
	for i in range(entries.size() - 1, -1, -1):
		var e := entries[i]
		if e.dead:
			continue
		var d := at.distance_to(e.pos)
		if d <= radius + 2.5:
			var falloff := clampf(1.0 - d / maxf(radius + 2.5, 1.0), 0.15, 1.0)
			var resist := 0.30 if e.kind == "atDitch" else (0.50 if e.kind == "hedgehog" else 0.65)
			e.hp -= amount * falloff * resist
			if e.hp <= 0.0:
				_destroy(i)

func _destroy(idx: int) -> void:
	var e := entries[idx]
	e.dead = true
	for u in e.get("garrison", []).duplicate():
		if typeof(u) == TYPE_DICTIONARY:
			u.erase("garrisoned_in")
	if is_instance_valid(e.get("node")):
		e.node.queue_free()
	entries.remove_at(idx)

func export_state() -> Array:
	var out := []
	for e in entries:
		if not e.dead:
			out.append({
				"owner": e.owner,
				"pos": [e.pos.x, e.pos.y, e.pos.z],
				"heading": e.heading,
				"kind": e.kind,
				"hp": e.hp,
				"built": e.built,
				"progress": e.progress,
			})
	return out

func import_state(data: Array) -> void:
	for e in entries:
		if is_instance_valid(e.get("node")):
			e.node.queue_free()
	entries.clear()
	for row in data:
		var p: Array = row.get("pos", [0, 0, 0])
		var ent := _spawn(int(row.get("owner", 0)), Vector3(float(p[0]), float(p[1]), float(p[2])), float(row.get("heading", 0.0)), str(row.get("kind", "trench")), bool(row.get("built", true)))
		ent.hp = float(row.get("hp", ent.max_hp))
		ent.progress = float(row.get("progress", 1.0))
		ent.model.scale.y = 1.0 if ent.built else lerpf(0.15, 1.0, ent.progress)
