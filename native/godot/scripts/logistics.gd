extends Node3D
## Supply network, ported from js/logistics.js.
## Roads and railways join neighbouring hexes. A settlement (capital, village,
## city) is supplied when an intact route of its owner's links it to the
## capital; every building in a settlement's district shares that status.
## Cut-off settlements stop training and stop counting for the economy, and
## tax coverage drops; railways add 25% production speed. Explosions damage
## each half of a link separately (a half belongs to the hex it lies in), and
## rebuilding a damaged link is a cheaper repair. AI nations connect isolated
## settlements to their capital by road.

const DIRECTIONS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

var world: Node
var radius := 12.0
var transport := {}
var rail_bonus := 0.25
var edges := {}            # key -> {a, b, owner, kind, hp, max_hp, half: [hp, hp]}
var reachable := {}        # owner -> {hex: true}
var rail_reachable := {}
var dirty := true
var _mesh: MeshInstance3D
var _grid: MeshInstance3D
var _preview: MeshInstance3D
var _timer := 0.0
var _ai_timer := {}

func setup(world_node: Node, cfg: Dictionary) -> void:
	world = world_node
	radius = float(cfg.hexRadius)
	transport = cfg.transport
	rail_bonus = float(cfg.get("railProductionBonus", 0.25))
	_mesh = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # colours below are picked in sRGB
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	update_supply()

# ---------------------------------------------------------------- hex maths

func hex_center(h: Vector2i) -> Vector3:
	var x := radius * sqrt(3.0) * (h.x + h.y / 2.0)
	var z := radius * 1.5 * h.y
	return Vector3(x, world.height_at(x, z), z)

func world_hex(p: Vector3) -> Vector2i:
	var q := (sqrt(3.0) * p.x / 3.0 - p.z / 3.0) / radius
	var r := p.z * 2.0 / (3.0 * radius)
	var a := roundf(q)
	var b := roundf(r)
	var c := roundf(-q - r)
	var da := absf(a - q)
	var db := absf(b - r)
	var dc := absf(c + q + r)
	if da > db and da > dc:
		a = -b - c
	elif db > dc:
		b = -a - c
	return Vector2i(int(a), int(b))

func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (absi(a.x - b.x) + absi(a.y - b.y) + absi(a.x + a.y - b.x - b.y)) / 2

func edge_key(a: Vector2i, b: Vector2i, owner: int) -> String:
	var ka := "%d,%d" % [a.x, a.y]
	var kb := "%d,%d" % [b.x, b.y]
	return "%d:%s|%s" % [owner, ka, kb] if ka < kb else "%d:%s|%s" % [owner, kb, ka]

# ---------------------------------------------------------------- planning

## Land only, no steep climbs (railways need gentler grades), and no link
## through a rival nation's settlement district.
func passable(a: Vector2i, b: Vector2i, kind: String, rivals: Array) -> bool:
	if not terrain_ok(a, b, kind):
		return false
	var p := hex_center(a)
	var t := hex_center(b)
	for i in range(0, 7, 2):
		var x := lerpf(p.x, t.x, i / 6.0)
		var z := lerpf(p.z, t.z, i / 6.0)
		for r in rivals:
			if Vector2(r.x - x, r.z - z).length() < r.y:
				return false
	return true

# Terrain never changes, so each link's slope and water check is cached.
var _terrain_cache := {}
func terrain_ok(a: Vector2i, b: Vector2i, kind: String) -> bool:
	var key := "%d,%d|%d,%d|%s" % [a.x, a.y, b.x, b.y, kind]
	if _terrain_cache.has(key):
		return _terrain_cache[key]
	var p := hex_center(a)
	var t := hex_center(b)
	var half := float(world.map.mapSize) * 0.5 - radius
	var previous := p.y
	var ok := true
	for i in range(7):
		var x := lerpf(p.x, t.x, i / 6.0)
		var z := lerpf(p.z, t.z, i / 6.0)
		var y: float = world.height_at(x, z)
		if absf(x) > half or absf(z) > half or y < 0.3 or absf(y - previous) > (1.4 if kind == "rail" else 2.5):
			ok = false
			break
		previous = y
	_terrain_cache[key] = ok
	return ok

# Rival settlement districts (x, radius, z) a route may not cross.
func rival_districts(owner: int) -> Array:
	var out := []
	for s in world.buildings:
		if not s.dead and s.owner != owner and float(s.def.get("buildRadius", 0)) > 0.0:
			out.append(Vector3(s.root.position.x, float(s.def.buildRadius), s.root.position.z))
	return out

## Bounded A* over hexes (planning runs on clicks and hex changes only).
func plan(start: Vector2i, goal: Vector2i, owner: int, kind: String) -> Array:
	if hex_distance(start, goal) > 70:
		return []
	var rivals := rival_districts(owner)
	var open := [{"h": start, "g": 0, "f": hex_distance(start, goal)}]
	var best := {start: 0}
	var parent := {}
	var count := 0
	while not open.is_empty() and count < 4500:
		count += 1
		open.sort_custom(func(x, y): return x.f > y.f)
		var cur: Dictionary = open.pop_back()
		if cur.g != best.get(cur.h, -1):
			continue
		if cur.h == goal:
			var route := [goal]
			while parent.has(route[0]):
				route.push_front(parent[route[0]])
			return route
		for d in DIRECTIONS:
			var next: Vector2i = cur.h + d
			if not passable(cur.h, next, kind, rivals):
				continue
			var g: int = cur.g + 1
			if g >= best.get(next, 1 << 30):
				continue
			best[next] = g
			parent[next] = cur.h
			open.append({"h": next, "g": g, "f": g + hex_distance(next, goal)})
	return []

## New links at full price; damaged ones of the same kind at a repair rate.
func quote(route: Array, kind: String, owner: int) -> Dictionary:
	var cost := {"money": 0.0, "iron": 0.0}
	for i in range(1, route.size()):
		var e = edges.get(edge_key(route[i - 1], route[i], owner))
		if e != null and e.hp >= e.max_hp and (e.kind == kind or e.kind == "rail"):
			continue
		var repair: bool = e != null and (e.kind == kind or e.kind == "rail")
		var rate := 1.0
		var price: Dictionary = transport[kind]
		if repair:
			rate = 0.5 * (1.0 - (e.half[0] + e.half[1]) * 0.5 / e.max_hp)
			price = transport[e.kind]
		cost.money += ceilf(float(price.money) * rate)
		cost.iron += ceilf(float(price.iron) * rate)
	return cost

func build(route: Array, kind: String, owner: int) -> bool:
	if route.size() < 2:
		return false
	var cost := quote(route, kind, owner)
	if owner == 0:
		if not world.economy.pay(cost):
			return false
	else:
		var nation = null
		for n in world.ai.nations:
			if n.id == owner:
				nation = n
		if nation == null or nation.money < cost.money + cost.iron * 2.0:
			return false
		nation.money -= cost.money + cost.iron * 2.0
	for i in range(1, route.size()):
		var key := edge_key(route[i - 1], route[i], owner)
		var old = edges.get(key)
		var next_kind: String = "rail" if old != null and old.kind == "rail" else kind
		var hp := float(transport[next_kind].hp)
		edges[key] = {"a": route[i - 1], "b": route[i], "owner": owner, "kind": next_kind, "hp": hp, "max_hp": hp, "half": [hp, hp]}
	dirty = true
	world.refresh_streets()
	update_supply()
	return true

# ---------------------------------------------------------------- supply

func settlement_of(b: Dictionary):
	if b.def.get("settlement") != null:
		return b
	var best = null
	var best_d := INF
	for s in world.buildings:
		if s.dead or not s.built or s.owner != b.owner or s.def.get("settlement") == null:
			continue
		# The nearest of the owner's settlements. Buildings may stand anywhere in
		# the nation's land (not only inside a settlement's radius); one beyond
		# every radius used to belong to none, count as cut off, and stall its
		# production at 0%.
		var d: float = s.root.position.distance_to(b.root.position)
		if d < best_d:
			best_d = d
			best = s
	return best

func reach_from(owner: int, rail_only: bool) -> Dictionary:
	var graph := {}
	for e in edges.values():
		if e.owner != owner or e.hp <= 0.0 or (rail_only and e.kind != "rail"):
			continue
		graph.get_or_add(e.a, []).append(e.b)
		graph.get_or_add(e.b, []).append(e.a)
	var reached := {}
	var queue := []
	for b in world.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			var h := world_hex(b.root.position)
			reached[h] = true
			queue.append(h)
	while not queue.is_empty():
		var h: Vector2i = queue.pop_back()
		for n in graph.get(h, []):
			if not reached.has(n):
				reached[n] = true
				queue.append(n)
	return reached

func update_supply() -> void:
	var owners := {}
	for b in world.buildings:
		owners[b.owner] = true
	for owner in owners:
		reachable[owner] = reach_from(owner, false)
		rail_reachable[owner] = reach_from(owner, true)
	dirty = false
	for b in world.buildings:
		if b.dead:
			continue
		var s = settlement_of(b)
		var hex := world_hex(s.root.position) if s != null else Vector2i(99999, 99999)
		var supplied: bool = s != null and reachable.get(b.owner, {}).has(hex)
		if b.owner == 0 and b.built and b.def.get("settlement") != null and b.has("supplied") and b.supplied != supplied:
			world.hud.notice("%s: %s" % [b.def.name, "supply restored" if supplied else "supply cut — reconnect roads or rails"])
		b.supplied = supplied
		b.rail_supplied = s != null and s.key != "hq" and rail_reachable.get(b.owner, {}).has(hex)

func _physics_process(delta: float) -> void:
	if world == null:
		return
	_timer -= delta
	if _timer <= 0.0 or dirty:
		_timer = 1.0
		update_supply()
	if world.ai != null:
		for n in world.ai.nations:
			if n.defeated:
				continue
			_ai_timer[n.id] = _ai_timer.get(n.id, 20.0) - delta * n.speed
			if _ai_timer[n.id] <= 0.0:
				_ai_timer[n.id] = 20.0
				connect_isolated(n.id)

# AI: route the first cut-off settlement back to the capital by road.
func connect_isolated(owner: int) -> void:
	var capital = null
	for b in world.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			capital = b
	if capital == null:
		return
	for b in world.buildings:
		if b.owner == owner and not b.dead and b.built and b.def.get("settlement") != null and b != capital and not b.get("supplied", true):
			var route := plan(world_hex(capital.root.position), world_hex(b.root.position), owner, "road")
			if not route.is_empty():
				build(route, "road", owner)
			return

## Explosions wear down every half-link within `reach` of the blast.
func damage_at(at: Vector3, reach: float, amount: float, area := false) -> int:
	var hit := 0
	var impacted := world_hex(at)
	for e in edges.values():
		var a := hex_center(e.a)
		var b := hex_center(e.b)
		var d := b - a
		d.y = 0
		for side in range(2):
			if not area and (e.a if side == 0 else e.b) != impacted:
				continue
			var t := clampf(((at.x - a.x) * d.x + (at.z - a.z) * d.z) / maxf(d.length_squared(), 0.01), side * 0.5, side * 0.5 + 0.5)
			var gap := Vector2(at.x - a.x - t * d.x, at.z - a.z - t * d.z).length()
			if (area and gap > reach) or e.half[side] <= 0.0:
				continue
			e.half[side] = maxf(0.0, e.half[side] - amount * (1.0 - 0.5 * gap / maxf(reach,0.01) if area else 1.0))
			hit += 1
		e.hp = minf(e.half[0], e.half[1])
	if hit > 0:
		dirty = true
		rebuild_mesh()
	return hit

# ---------------------------------------------------------------- drawing

# Roads: asphalt with a painted centre line. Railways: a gravel bed with
# sleepers and two steel rails. Broken halves show as scorched fragments.
func rebuild_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var asphalt := Color("3b3b38")
	var verge := Color("6b6452")
	var gravel := Color("6f6a61")
	var ballast := Color("8a847a")
	var steel := Color("a9a8a2")
	var edge_line := Color("d8d6cc")
	var paint := Color("d9c27a")
	var sleeper := Color("3f3127")
	var broken := Color("5a3a2c")
	var junctions := {}   # hex -> kind of the links meeting there (outside districts)
	for e in edges.values():
		var from := hex_center(e.a)
		var to := hex_center(e.b)
		var mid := (from + to) * 0.5
		for side in range(2):
			var a := from if side == 0 else mid
			var b := mid if side == 0 else to
			# Inside a district hex the district's own street takes over.
			var hex: Vector2i = e.a if side == 0 else e.b
			var owner_there = world.district_hex.get(hex)
			if owner_there != null and not owner_there.dead and e.half[side] > 0.0:
				continue
			if e.half[side] <= 0.0:
				_strip(st, a.lerp(b, 0.0), a.lerp(b, 0.3), 2.4, 0.0, broken, 0.07)
				_strip(st, a.lerp(b, 0.72), a.lerp(b, 1.0), 2.4, 0.0, broken, 0.07)
				continue
			if junctions.get(hex, "") != "road":
				junctions[hex] = e.kind
			if e.kind == "rail":
				# Ballast bed, sleepers every 0.8 m, two rails on a 1.1 m gauge.
				_strip(st, a, b, 3.4, 0.0, gravel, 0.06)
				_strip(st, a, b, 2.6, 0.0, ballast, 0.09)
				var dir := (b - a)
				dir.y = 0
				var across := Vector3(-dir.z, 0, dir.x).normalized()
				var count := maxi(1, int(dir.length() / 0.8))
				for k in range(count):
					var p := a.lerp(b, (k + 0.5) / count)
					_strip(st, p - across * 1.05, p + across * 1.05, 0.24, 0.0, sleeper, 0.12)
				for offset in [-0.55, 0.55]:
					_strip(st, a, b, 0.12, offset, steel, 0.19)
			else:
				# Two lanes: a verge, asphalt, white edge lines and a dashed centre line.
				_strip(st, a, b, 5.4, 0.0, verge, 0.06)
				_strip(st, a, b, 4.4, 0.0, asphalt, 0.09)
				for offset in [-1.95, 1.95]:
					_strip(st, a, b, 0.12, offset, edge_line, 0.11)
				var run := Vector2(b.x - a.x, b.z - a.z).length()
				var dashes := maxi(1, int(run / 4.0))
				for k in range(dashes):
					_strip(st, a.lerp(b, (k + 0.2) / dashes), a.lerp(b, (k + 0.7) / dashes), 0.12, 0.0, paint, 0.11)
	# Where links meet outside a town, a round patch of the same surface joins them.
	for hex in junctions:
		var c := hex_center(hex)
		_disc(st, c, 2.9 if junctions[hex] == "road" else 1.9, asphalt if junctions[hex] == "road" else ballast, 0.095)
	st.generate_normals()
	_mesh.mesh = st.commit()

func _disc(st: SurfaceTool, c: Vector3, r: float, color: Color, lift: float) -> void:
	st.set_color(color)
	var centre := Vector3(c.x, world.height_at(c.x, c.z) + lift, c.z)
	for k in range(12):
		var a0 := TAU * k / 12.0
		var a1 := TAU * (k + 1) / 12.0
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		p0.y = world.height_at(p0.x, p0.z) + lift
		p1.y = world.height_at(p1.x, p1.z) + lift
		for v in [centre, p1, p0]:
			st.add_vertex(v)

# A ribbon from a to b, `width` wide, draped on the terrain in short steps.
func _strip(st: SurfaceTool, a: Vector3, b: Vector3, width: float, offset: float, color: Color, lift: float) -> void:
	var dir := b - a
	dir.y = 0
	var length := dir.length()
	if length < 0.01:
		return
	var across := Vector3(-dir.z, 0, dir.x) / length
	var steps := maxi(1, int(length / 1.5))
	st.set_color(color)
	for i in range(steps):
		var p0 := a + dir * (float(i) / steps) + across * offset
		var p1 := a + dir * (float(i + 1) / steps) + across * offset
		var v := [p0 - across * width * 0.5, p0 + across * width * 0.5, p1 - across * width * 0.5, p1 + across * width * 0.5]
		for j in range(4):
			v[j].y = world.height_at(v[j].x, v[j].z) + lift
		for index in [0, 2, 1, 1, 2, 3]:
			st.add_vertex(v[index])

## Faint hex outlines on land, shown while laying roads.
func show_grid(visible: bool) -> void:
	if _grid == null and visible:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		var limit := int(float(world.map.mapSize) * 0.5 / (radius * 1.5)) + 2
		for q in range(-limit * 2, limit * 2 + 1):
			for r in range(-limit, limit + 1):
				var c := hex_center(Vector2i(q, r))
				if absf(c.x) > float(world.map.mapSize) * 0.5 - radius or absf(c.z) > float(world.map.mapSize) * 0.5 - radius or c.y < 0.3:
					continue
				for i in range(6):
					for corner in [i, i + 1]:
						var angle := deg_to_rad(corner * 60.0 + 30.0)
						var x := c.x + cos(angle) * radius
						var z := c.z + sin(angle) * radius
						st.add_vertex(Vector3(x, world.height_at(x, z) + 0.15, z))
		_grid = MeshInstance3D.new()
		_grid.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.83, 0.77, 0.57, 0.35)
		_grid.material_override = m
		_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_grid)
	if _grid:
		_grid.visible = visible

## The planned route as a bright ribbon through hex centres.
func show_preview(route: Array) -> void:
	if _preview == null:
		_preview = MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color("ffd57d")
		m.no_depth_test = true
		_preview.material_override = m
		add_child(_preview)
	if route.size() < 2:
		_preview.visible = false
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, route.size()):
		_strip(st, hex_center(route[i - 1]), hex_center(route[i]), 0.7, 0.0, Color.WHITE, 0.4)
	_preview.mesh = st.commit()
	_preview.visible = true
