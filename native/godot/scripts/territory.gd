extends Node3D
## Gradual territory control, ported from js/territory.js. The island is cut
## into 40 m cells (TERRITORY_CELL, through the map export). Every two seconds
## buildings project authority over nearby cells (capitals and city centres
## furthest) and armed units occupy the cell they stand in. A cell with no
## owner goes to the strongest presence; an owned cell loses control while a
## rival dominates it and flips only when control is worn down, so conquest is
## a campaign, not a switch. Cells where two nations are close in strength are
## contested (front lines).
## Land pays: every held cell yields money, and by terrain plains add food,
## forests money, mountains iron and coasts trade money, scaled by how firmly
## the cell is held (sovereign, integrated, occupied, contested). The player's
## yields go into the economy; AI nations bank theirs as money.
## Borders are drawn as coloured ribbons on the ground while the Territory
## panel is open (T), as in the browser.

signal changed

const TICK := 2.0
enum Terrain { WATER, PLAINS, FOREST, MOUNTAIN, COAST }
const TERRAIN_NAMES := ["Water", "Plains", "Forest", "Mountain", "Coast"]
const STATUS_YIELD := {"sovereign": 1.0, "integrated": 0.75, "occupied": 0.4, "contested": 0.15}
const RIBBON := 2.4

var world: Node
var cell := 40.0
var half_map := 320.0
var cols := 0
var owner_of := PackedInt32Array()
var control := PackedFloat32Array()
var contested := PackedByteArray()
var terrain := PackedByteArray()
var fronts := 0
var show_borders := false
var _dirty := true
var _tick := 0.0
var _borders: MeshInstance3D
var _material: StandardMaterial3D

func setup(world_node: Node, cfg: Dictionary) -> void:
	world = world_node
	cell = float(cfg.get("cell", 40.0))
	half_map = float(cfg.get("halfMap", float(world.map.mapSize) * 0.5))
	cols = ceili(half_map * 2.0 / cell)
	var n := cols * cols
	owner_of.resize(n)
	owner_of.fill(-1)
	control.resize(n)
	control.fill(0.0)
	contested.resize(n)
	contested.fill(0)
	terrain.resize(n)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.015
	noise.seed = 91
	var sea := float(world.map.seaLevel)
	for i in range(n):
		var c := center(i)
		var h: float = world.height_at(c.x, c.z)
		if h < sea + 0.05:
			terrain[i] = Terrain.WATER
			continue
		var coast := false
		for d in [Vector2(cell, 0), Vector2(-cell, 0), Vector2(0, cell), Vector2(0, -cell)]:
			if world.height_at(c.x + d.x, c.z + d.y) < sea:
				coast = true
				break
		if coast:
			terrain[i] = Terrain.COAST
		elif h > sea + 6.0:
			terrain[i] = Terrain.MOUNTAIN
		elif noise.get_noise_2d(c.x, c.z) > 0.1:
			terrain[i] = Terrain.FOREST
		else:
			terrain[i] = Terrain.PLAINS
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_borders = MeshInstance3D.new()
	_borders.material_override = _material
	_borders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_borders.visible = false
	add_child(_borders)
	tick()

func reset() -> void:
	owner_of.fill(-1)
	control.fill(0.0)
	contested.fill(0)
	_dirty = true

func center(i: int) -> Vector3:
	return Vector3((i % cols + 0.5) * cell - half_map, 0, (i / cols + 0.5) * cell - half_map)

func cell_of(at: Vector3) -> int:
	var cx := clampi(floori((at.x + half_map) / cell), 0, cols - 1)
	var cz := clampi(floori((at.z + half_map) / cell), 0, cols - 1)
	return cz * cols + cx

func owner_at(at: Vector3) -> int:
	return owner_of[cell_of(at)]

func status(i: int) -> String:
	if contested[i]:
		return "contested"
	if control[i] >= 70.0:
		return "sovereign"
	if control[i] >= 40.0:
		return "integrated"
	return "occupied"

## Per-second yields of the land `nation` holds.
func yields(nation: int) -> Dictionary:
	var out := {"money": 0.0, "food": 0.0, "iron": 0.0, "oil": 0.0, "cells": 0, "sovereign": 0, "integrated": 0, "occupied": 0, "contested": 0}
	var r: Node = world.research if nation == 0 else null
	for i in range(owner_of.size()):
		if owner_of[i] != nation:
			continue
		var s := status(i)
		out[s] += 1
		out.cells += 1
		var m: float = STATUS_YIELD[s]
		out.money += 0.05 * m
		match terrain[i]:
			Terrain.PLAINS:
				out.food += 0.020 * m
			Terrain.FOREST:
				out.money += 0.030 * m * (1.0 + (r.bonus("forestPct") if r else 0.0))
			Terrain.MOUNTAIN:
				out.iron += 0.008 * m
			Terrain.COAST:
				out.money += 0.040 * m
				if r:
					out.food += 0.03 * m * r.bonus("coastFood")      # Aquaculture
					out.oil += 0.015 * m * r.bonus("coastOil")       # Offshore Drilling
	return out

func land_cells() -> int:
	var n := 0
	for t in terrain:
		if t != Terrain.WATER:
			n += 1
	return n

func is_front(i: int) -> bool:
	var o := owner_of[i]
	if o < 0:
		return false
	if contested[i]:
		return true
	var x := i % cols
	var z := i / cols
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var nz: int = z + d.y
		if nx >= 0 and nz >= 0 and nx < cols and nz < cols:
			var other := owner_of[nz * cols + nx]
			if other >= 0 and other != o:
				return true
	return false

func _presence(presence: PackedFloat32Array, at: Vector3, owner: int, weight: float, spread: int, nations: int) -> void:
	if owner < 0 or world.diplomacy.defeated(owner):
		return
	var cx := floori((at.x + half_map) / cell)
	var cz := floori((at.z + half_map) / cell)
	for dz in range(-spread, spread + 1):
		for dx in range(-spread, spread + 1):
			var nx := cx + dx
			var nz := cz + dz
			if nx < 0 or nz < 0 or nx >= cols or nz >= cols:
				continue
			var i := nz * cols + nx
			if terrain[i] == Terrain.WATER:
				continue
			presence[i * nations + owner] += weight / (1.0 + absi(dx) + absi(dz))

func _process(delta: float) -> void:
	if world == null or world.economy == null or world.game_over != "":
		return
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		tick()

func tick() -> void:
	var nations: int = world.map.nations.size()
	var presence := PackedFloat32Array()
	presence.resize(cols * cols * nations)
	for b in world.buildings:
		if b.dead or not b.built:
			continue
		var w := 30.0 if b.key == "hq" else 26.0 if b.key == "cityCenter" else 18.0 if b.key == "villageCenter" else 22.0 if b.key == "commandCenter" else 14.0
		_presence(presence, b.root.position, b.owner, w, 2 if b.key in ["hq", "cityCenter"] else 1, nations)
	for u in world.units:
		if u.dead or u.dmg <= 0.0 or u.get("fly", false) or u.get("naval", false):
			continue
		var stance := 1.2 if u.attack_move else 1.0
		var w: float = (1.1 + float(world.unit_defs.get(u.key, {}).get("pop", 1)) * 0.55) * stance
		_presence(presence, u.node.position, u.owner, w, 0, nations)
	var flipped := false
	for i in range(cols * cols):
		if terrain[i] == Terrain.WATER:
			continue
		if owner_of[i] >= 0 and world.diplomacy.defeated(owner_of[i]):
			owner_of[i] = -1
			control[i] = 0.0
			flipped = true
		var best := -1
		var best_w := 0.0
		var second_w := 0.0
		for n in range(nations):
			var w := presence[i * nations + n]
			if w > best_w:
				second_w = best_w
				best_w = w
				best = n
			elif w > second_w:
				second_w = w
		var fight := best_w > 0.6 and second_w > 0.45 and best_w < second_w * 1.75
		if contested[i] != int(fight):
			flipped = true
		contested[i] = 1 if fight else 0
		if best < 0 or best_w <= 0.35:
			if owner_of[i] >= 0:
				control[i] = maxf(12.0, control[i] - 0.15)
			continue
		if owner_of[i] == -1:
			owner_of[i] = best
			control[i] = clampf(best_w * 9.0, 18.0, 45.0)
			flipped = true
		elif owner_of[i] == best:
			control[i] = clampf(control[i] + best_w * (0.08 if fight else 0.28), 0.0, 100.0)
		elif fight:
			control[i] = clampf(control[i] - maxf(0.5, (best_w - second_w * 0.45) * 0.18), 0.0, 100.0)
		else:
			control[i] = clampf(control[i] - maxf(1.2, best_w * 0.5), 0.0, 100.0)
			if control[i] <= 1.0:
				var lost_by := owner_of[i]
				owner_of[i] = best
				control[i] = clampf(best_w * 8.0, 20.0, 55.0)
				flipped = true
				if lost_by == 0 or best == 0:
					var c := center(i)
					world.hud.notice("Territory %s near (%d, %d)." % ["lost to %s" % world.diplomacy.name_of(best) if lost_by == 0 else "taken from %s" % world.diplomacy.name_of(lost_by), int(c.x), int(c.z)])
	fronts = 0
	for i in range(cols * cols):
		if is_front(i):
			fronts += 1
	# AI nations bank their land's yield as money (twice the per-second rate).
	if world.ai != null:
		for nat in world.ai.nations:
			if not nat.defeated:
				var y := yields(nat.id)
				nat.money += (y.money + y.food * 2.5 + y.iron * 5.0) * TICK
	if flipped:
		_dirty = true
	if _dirty and show_borders:
		draw_fill()
	changed.emit()

func set_visible_borders(on: bool) -> void:
	show_borders = on
	_borders.visible = false  # the terrain now draws the borders itself
	draw_fill()
	for label in _labels:
		label.visible = on

# ---------------------------------------------------------------- the map view

var _labels: Array[Label3D] = []

## Paints the land each nation holds in its colour, in the terrain itself:
## a small texture with one texel per cell (colour and tint strength) that
## terrain.gdshader reads. Firmer control is a deeper colour, borders between
## nations are bright lines, contested cells are hatched in gold. Each
## nation's name floats over its heartland.
func draw_fill() -> void:
	var img := Image.create(cols, cols, false, Image.FORMAT_RGBA8)
	var sums := {}
	for i in range(owner_of.size()):
		var o := owner_of[i]
		if o < 0:
			continue
		var base: Color = Color(world.map.nations[o].color)
		var strength := 0.42 + 0.25 * clampf(control[i] / 100.0, 0.0, 1.0)
		img.set_pixel(i % cols, i / cols, Color(base.r, base.g, base.b, 1.0 if contested[i] else strength))
		var c := center(i)
		sums[o] = sums.get(o, Vector3.ZERO) + Vector3(c.x, 1.0, c.z)
	var mat: ShaderMaterial = world.terrain_node.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("territory_tex", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("territory_origin", Vector2(-half_map, -half_map))
		mat.set_shader_parameter("territory_cell", cell)
		mat.set_shader_parameter("territory_cols", float(cols))
		mat.set_shader_parameter("show_territory", show_borders)
	var sea := float(world.map.seaLevel)
	for label in _labels:
		label.queue_free()
	_labels.clear()
	for o in sums:
		var s3: Vector3 = sums[o]
		var at := Vector3(s3.x / s3.y, 0, s3.z / s3.y)
		at.y = maxf(world.height_at(at.x, at.z), sea) + 14.0
		var label := Label3D.new()
		label.text = world.map.nations[o].name.to_upper()
		label.font_size = 150
		label.pixel_size = 0.05
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(world.map.nations[o].color).lightened(0.35)
		label.outline_size = 36
		label.outline_modulate = Color(0.05, 0.08, 0.1, 0.85)
		label.position = at
		label.visible = show_borders
		add_child(label)
		_labels.append(label)

## What the territory view shows about the cell at `at` when it is clicked.
func describe(at: Vector3) -> String:
	var i := cell_of(at)
	var terrain_name: String = TERRAIN_NAMES[terrain[i]]
	if terrain[i] == Terrain.WATER:
		return "Open water: nobody holds the sea."
	var o := owner_of[i]
	if o < 0:
		return "%s, unclaimed. Buildings or an army standing here will claim it." % terrain_name
	var who: String = "You" if o == 0 else world.diplomacy.name_of(o)
	var status_text := status(i)
	var yields_text: String = {Terrain.PLAINS: "food and money", Terrain.FOREST: "money (timber)", Terrain.MOUNTAIN: "iron and money", Terrain.COAST: "trade money"}.get(terrain[i], "money")
	return "%s: held by %s, %s (control %d%%). Yields %s at %d%%.%s" % [terrain_name, who, status_text, int(control[i]), yields_text, roundi(STATUS_YIELD[status_text] * 100.0),
		" A front line: rival forces are contesting it." if contested[i] else ""]

# Ribbons along every edge between cells of different owners, in the owner's
# colour (gold where contested), slightly wavy so they read as borders, not a grid.
func draw_borders() -> void:
	_dirty = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var gold := Color("ffd66b")
	for z in range(cols):
		for x in range(cols):
			var i := z * cols + x
			var o := owner_of[i]
			if o < 0:
				continue
			var colour: Color = Color(world.map.nations[o].color).lightened(0.15)
			var x0 := x * cell - half_map
			var z0 := z * cell - half_map
			var sides := [[Vector2i(1, 0), Vector2(x0 + cell, z0), Vector2(x0 + cell, z0 + cell)],
				[Vector2i(-1, 0), Vector2(x0, z0 + cell), Vector2(x0, z0)],
				[Vector2i(0, 1), Vector2(x0 + cell, z0 + cell), Vector2(x0, z0 + cell)],
				[Vector2i(0, -1), Vector2(x0, z0), Vector2(x0 + cell, z0)]]
			for side in sides:
				var nx: int = x + side[0].x
				var nz: int = z + side[0].y
				var other := owner_of[nz * cols + nx] if nx >= 0 and nz >= 0 and nx < cols and nz < cols else -1
				if other == o:
					continue
				var c := gold if contested[i] else colour
				# Each nation draws its own side of a shared seam, inset a little.
				_ribbon(st, side[1], side[2], Vector2(x0 + cell * 0.5, z0 + cell * 0.5), c, o)
				count += 1
	_borders.mesh = st.commit() if count > 0 else null

func _ribbon(st: SurfaceTool, a: Vector2, b: Vector2, inside: Vector2, colour: Color, seed: int) -> void:
	var pieces := 10
	var along := (b - a).normalized()
	var normal := Vector2(-along.y, along.x)
	if normal.dot(inside - a) < 0.0:
		normal = -normal
	var points := []
	for s in range(pieces + 1):
		var t := float(s) / pieces
		var p := a.lerp(b, t) + normal * (1.2 + sin(t * PI) * sin((p_hash(a) + seed) * 3.1 + t * 9.0) * 0.8)
		points.append(p)
	var sea := float(world.map.seaLevel)
	for s in range(pieces):
		var p0: Vector2 = points[s]
		var p1: Vector2 = points[s + 1]
		var q0 := p0 + normal * RIBBON
		var q1 := p1 + normal * RIBBON
		if world.height_at(p0.x, p0.y) < sea and world.height_at(p1.x, p1.y) < sea:
			continue  # borders run over land; the coast is border enough
		var verts := []
		for p in [p0, p1, q1, q0]:
			verts.append(Vector3(p.x, maxf(world.height_at(p.x, p.y), sea) + 0.6, p.y))
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(colour, 0.85 if k in [0, 1] else 0.25))
			st.add_vertex(verts[k])

func p_hash(p: Vector2) -> float:
	return fmod(absf(p.x * 0.113 + p.y * 0.071), 7.0)

func capture() -> Dictionary:
	return {"owner": Array(owner_of), "control": Array(control).map(func(v): return snappedf(v, 0.1)), "contested": Array(contested)}

func restore(data: Dictionary) -> void:
	var saved: Array = data.get("owner", [])
	if saved.size() != owner_of.size():
		reset()
		return
	for i in range(saved.size()):
		owner_of[i] = int(saved[i])
		control[i] = float(data.control[i])
		contested[i] = int(data.contested[i])
	_dirty = true
	if show_borders:
		draw_borders()
