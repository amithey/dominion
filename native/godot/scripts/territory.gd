extends Node3D
## Gradual territory control, hex by hex as in a 4X game. The land is the
## same hex grid the districts are built on (logistics.gd, 12 m hexes): a hex
## you build on is yours, with a ring of hexes around it, and settlements claim
## wider (the capital three rings, cities and villages two). Every two seconds
## buildings project authority over nearby hexes and armed units occupy the
## hex they stand in. A cell with no
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
const LAND_PRICE := 1000.0 ## money for one hex of unclaimed land, bought at a settlement's town hall
const PURCHASES := 4       ## hexes each settlement may buy
## How far a settlement's land reaches, in rings of hexes round its centre:
## it starts small and grows with the people living there, up to a limit.
const RINGS_MAX := {"hq": 4, "cityCenter": 4, "villageCenter": 3}
const PEOPLE_PER_RING := 110.0
const WATERS := 2          ## rings of sea off a nation's coast that are its territorial waters

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
var hex := 12.0          ## hex radius, centre to corner (the district grid's)
var rows := 0            ## cells are stored row by row: row = r + r0, column = offset q + c0
var r0 := 0
var c0 := 0
var area_scale := 1.0    ## yields were tuned for 40 m squares; a hex is smaller
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

func setup(world_node: Node, cfg: Dictionary) -> void:
	world = world_node
	half_map = float(cfg.get("halfMap", float(world.map.mapSize) * 0.5))
	hex = float(world.logistics.radius) if world.logistics != null else 12.0
	cell = hex * sqrt(3.0)  # the width of a hex, where callers want a cell size
	area_scale = (2.598 * hex * hex) / (40.0 * 40.0)
	r0 = ceili(half_map / (1.5 * hex)) + 1
	c0 = ceili(half_map / (sqrt(3.0) * hex)) + 1
	rows = 2 * r0 + 1
	cols = 2 * c0 + 1
	var n := cols * rows
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
		for k in range(6):
			var a := PI / 6.0 + k * PI / 3.0
			if world.height_at(c.x + cos(a) * hex, c.z + sin(a) * hex) < sea:
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
	tick()

func reset() -> void:
	purchased.clear()
	owner_of.fill(-1)
	control.fill(0.0)
	contested.fill(0)
	_dirty = true

## Axial hex coordinates (q, r) of cell `i`.
func axial(i: int) -> Vector2i:
	var r := i / cols - r0
	var q := (i % cols - c0) - (r - (r & 1)) / 2
	return Vector2i(q, r)

## Cell index of hex (q, r), or -1 off the grid.
func index_of(h: Vector2i) -> int:
	var row := h.y + r0
	var col := h.x + (h.y - (h.y & 1)) / 2 + c0
	if row < 0 or col < 0 or row >= rows or col >= cols:
		return -1
	return row * cols + col

func center(i: int) -> Vector3:
	var h := axial(i)
	return Vector3(hex * sqrt(3.0) * (h.x + h.y * 0.5), 0, hex * 1.5 * h.y)

## The hex that contains `at` (the same rounding as logistics.world_hex).
func hex_at(at: Vector3) -> Vector2i:
	var q := (sqrt(3.0) * at.x / 3.0 - at.z / 3.0) / hex
	var r := at.z * 2.0 / (3.0 * hex)
	var x := roundf(q)
	var z := roundf(r)
	var y := roundf(-q - r)
	var dx := absf(x - q)
	var dz := absf(z - r)
	var dy := absf(y + q + r)
	if dx > dz and dx > dy:
		x = -y - z
	elif dz > dy:
		z = -x - y
	return Vector2i(int(x), int(z))

func cell_of(at: Vector3) -> int:
	var i := index_of(hex_at(at))
	if i >= 0:
		return i
	var h := hex_at(at)
	return clampi(h.y + r0, 0, rows - 1) * cols + clampi(h.x + (h.y - (h.y & 1)) / 2 + c0, 0, cols - 1)

## The six corners of cell `i` on the ground plane (x, z), for maps.
func cell_polygon(i: int) -> PackedVector2Array:
	var c := center(i)
	var out := PackedVector2Array()
	for k in range(6):
		var a := PI / 6.0 + k * PI / 3.0
		out.append(Vector2(c.x + cos(a) * hex, c.z + sin(a) * hex))
	return out

func neighbours(i: int) -> Array[int]:
	var h := axial(i)
	var out: Array[int] = []
	for d in DIRS:
		var j := index_of(h + d)
		if j >= 0:
			out.append(j)
	return out

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
		if owner_of[i] != nation or terrain[i] == Terrain.WATER:
			continue  # territorial waters are held, but the land is what pays
		var s := status(i)
		out[s] += 1
		out.cells += 1
		var m: float = STATUS_YIELD[s] * area_scale
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

## Pays for one hex of unclaimed land; false when the nation cannot afford it.
## People living around settlement `s`: its own share and that of the homes
## nearest to it, times how full the nation's housing is.
func residents(s: Dictionary) -> float:
	var weights: Dictionary = world.economy.POPULATION_WEIGHTS if world.economy != null else {}
	var fill := 0.8
	if s.owner == 0 and world.economy != null:
		fill = clampf(world.economy.civilians / maxf(world.economy.civ_cap, 1.0), 0.0, 1.0)
	var people: float = float(weights.get(s.key, 60.0))
	for b in world.buildings:
		if b.dead or not b.built or b.owner != s.owner or b.def.get("settlement") != null or not weights.has(b.key):
			continue
		if is_same(world.logistics.settlement_of(b), s):
			people += float(weights[b.key])
	return people * fill

## Rings of land settlement `s` holds now (at least one, at most its limit).
func rings_of(s: Dictionary) -> int:
	return clampi(1 + int(residents(s) / PEOPLE_PER_RING), 1, int(RINGS_MAX.get(s.key, 2)))

func _buy(nation: int) -> bool:
	if nation == 0:
		return world.economy != null and world.economy.pay({"money": LAND_PRICE})
	if world.ai != null:
		for n in world.ai.nations:
			if n.id == nation and float(n.money) >= LAND_PRICE:
				n.money -= LAND_PRICE
				return true
	return false

## Territorial waters: sea hexes within WATERS rings of a nation's coast are
## its own (the nearest coast decides; where two coasts are equally near, the
## firmer hold). Returns whether any changed.
func _waters() -> bool:
	var dist := PackedInt32Array()
	dist.resize(cols * rows)
	dist.fill(99)
	var owner_w := PackedInt32Array()
	owner_w.resize(cols * rows)
	owner_w.fill(-1)
	var ctrl := PackedFloat32Array()
	ctrl.resize(cols * rows)
	var frontier: Array[int] = []
	for i in range(owner_of.size()):
		if terrain[i] != Terrain.WATER and owner_of[i] >= 0:
			for j in neighbours(i):
				if terrain[j] == Terrain.WATER and (dist[j] > 1 or control[i] > ctrl[j]):
					dist[j] = 1
					owner_w[j] = owner_of[i]
					ctrl[j] = control[i]
					if not j in frontier:
						frontier.append(j)
	for ring in range(2, WATERS + 1):
		var next: Array[int] = []
		for i in frontier:
			for j in neighbours(i):
				if terrain[j] == Terrain.WATER and dist[j] > ring - 1 and (dist[j] > ring or ctrl[i] > ctrl[j]):
					dist[j] = ring
					owner_w[j] = owner_w[i]
					ctrl[j] = ctrl[i]
					if not j in next:
						next.append(j)
		frontier = next
	var changed := false
	for i in range(owner_of.size()):
		if terrain[i] != Terrain.WATER:
			continue
		if owner_of[i] != owner_w[i]:
			owner_of[i] = owner_w[i]
			changed = true
		control[i] = ctrl[i]
		contested[i] = 0
	return changed

## Buying land, Civilization style: at a settlement's town hall (the capital,
## a city or a village centre) its owner picks unclaimed hexes next to its
## land and pays for each. Each settlement may buy PURCHASES hexes.
func settlement_key(s: Dictionary) -> String:
	return "%d,%d" % [roundi(s.root.position.x), roundi(s.root.position.z)]

func bought_by(s: Dictionary) -> int:
	var k := settlement_key(s)
	var n := 0
	for key in purchased:
		if purchased[key].settlement == k:
			n += 1
	return n

func purchases_left(s: Dictionary) -> int:
	return maxi(0, PURCHASES - bought_by(s))

## Hexes settlement `s` may buy now: unclaimed land touching its nation's
## land, within a few rings of the settlement.
func purchase_candidates(s: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if purchases_left(s) <= 0:
		return out
	var centre := hex_at(s.root.position)
	var reach: int = rings_of(s) + 2
	for dq in range(-reach, reach + 1):
		for dr in range(maxi(-reach, -dq - reach), mini(reach, -dq + reach) + 1):
			var i := index_of(centre + Vector2i(dq, dr))
			if i < 0 or terrain[i] == Terrain.WATER or owner_of[i] != -1:
				continue
			for j in neighbours(i):
				if owner_of[j] == s.owner:
					out.append(i)
					break
	return out

## Buys hex `i` for settlement `s`. Returns what happened.
func purchase(s: Dictionary, i: int) -> String:
	if purchases_left(s) <= 0:
		return "%s has bought all the land it may (%d hexes)." % [s.def.name, PURCHASES]
	if not i in purchase_candidates(s):
		return "That hex cannot be bought here: pick unclaimed land next to your own."
	if not _buy(s.owner):
		return "Not enough money: land costs $%d a hex." % int(LAND_PRICE)
	purchased[str(i)] = {"owner": s.owner, "settlement": settlement_key(s)}
	owner_of[i] = s.owner
	control[i] = 40.0
	draw_fill()
	changed.emit()
	return "Land bought for $%d. %d more hex%s may be bought at this %s." % [int(LAND_PRICE), purchases_left(s), "" if purchases_left(s) == 1 else "es", s.def.name]

## An AI nation with money to spare buys land for one of its settlements.
func ai_purchase(nation: int) -> void:
	for s in world.buildings:
		if s.dead or not s.built or s.owner != nation or not RINGS_MAX.has(s.key):
			continue
		var options := purchase_candidates(s)
		if not options.is_empty():
			purchase(s, options[randi() % options.size()])
			return

func is_front(i: int) -> bool:
	var o := owner_of[i]
	if o < 0:
		return false
	if contested[i]:
		return true
	for j in neighbours(i):
		var other := owner_of[j]
		if other >= 0 and other != o:
			return true
	return false

## Adds `owner`'s authority to every hex within `spread` rings of `at`,
## weaker with each ring.
func _presence(presence: PackedFloat32Array, at: Vector3, owner: int, weight: float, spread: int, nations: int) -> void:
	if owner < 0 or world.diplomacy.defeated(owner):
		return
	var h := hex_at(at)
	for dq in range(-spread, spread + 1):
		for dr in range(maxi(-spread, -dq - spread), mini(spread, -dq + spread) + 1):
			var i := index_of(h + Vector2i(dq, dr))
			if i < 0 or terrain[i] == Terrain.WATER:
				continue
			var ring := (absi(dq) + absi(dr) + absi(dq + dr)) / 2
			presence[i * nations + owner] += weight / (1.0 + ring)

func _process(delta: float) -> void:
	if world == null or world.economy == null or world.game_over != "":
		return
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		var clock: int = world.clock()
		tick()
		world.spent("territory", clock)

func tick() -> void:
	var nations: int = world.map.nations.size()
	var presence := PackedFloat32Array()
	presence.resize(cols * rows * nations)
	# Authority from buildings alone: land they claim is free; land that only
	# troops stand on, unclaimed by anyone, has to be bought.
	var built := PackedFloat32Array()
	built.resize(cols * rows * nations)
	for b in world.buildings:
		if b.dead or not b.built:
			continue
		# What you build on is yours, and a ring round it; settlements reach further.
		var w := 30.0 if b.key == "hq" else 26.0 if b.key == "cityCenter" else 18.0 if b.key == "villageCenter" else 22.0 if b.key == "commandCenter" else 14.0
		# A settlement's land grows with its people (rings_of); any other
		# building holds the hex it stands on.
		var reach := rings_of(b) if RINGS_MAX.has(b.key) else 0
		_presence(presence, b.root.position, b.owner, w, reach, nations)
		_presence(built, b.root.position, b.owner, w, reach, nations)
	# Land bought at a town hall is held as firmly as a building's own hex.
	for key in purchased:
		var entry: Dictionary = purchased[key]
		var i: int = int(key)
		if i >= 0 and i < owner_of.size() and not world.diplomacy.defeated(int(entry.owner)):
			presence[i * nations + int(entry.owner)] += 20.0
			built[i * nations + int(entry.owner)] += 20.0
	for u in world.units:
		if u.dead or u.dmg <= 0.0 or u.get("fly", false) or u.get("naval", false):
			continue
		# In another nation's land only a hostile force wears down its hold: a
		# guest with passage (or a trespasser at peace) takes nothing.
		var held := owner_of[cell_of(u.node.position)]
		if held >= 0 and held != u.owner and not world.hostile(u.owner, held):
			continue
		var stance := 1.2 if u.attack_move else 1.0
		var w: float = (1.1 + float(world.unit_defs.get(u.key, {}).get("pop", 1)) * 0.55) * stance
		if world.occupation != null:
			w *= world.occupation.weight(u)  # troops inside their own operational zone count double
		_presence(presence, u.node.position, u.owner, w, 0, nations)
	var flipped := false
	for i in range(cols * rows):
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
			if built[i * nations + best] <= 0.35:
				continue  # troops alone never claim unclaimed land: it is bought at a town hall
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
	if _waters():
		flipped = true
	fronts = 0
	for i in range(cols * rows):
		if is_front(i):
			fronts += 1
	if world.occupation != null:
		world.occupation.review()
	# AI nations bank their land's yield as money (twice the per-second rate).
	if world.ai != null:
		for nat in world.ai.nations:
			if not nat.defeated:
				var y := yields(nat.id)
				nat.money += (y.money + y.food * 2.5 + y.iron * 5.0) * TICK
	if flipped:
		_dirty = true
	if _dirty:
		draw_fill()  # borders are always on the map; the fill shows in the territory view
	changed.emit()

func set_visible_borders(on: bool) -> void:
	show_borders = on
	draw_fill()
	for label in _labels:
		label.visible = on

# ---------------------------------------------------------------- the map view

var _labels: Array[Label3D] = []
var purchased := {}               ## hex index (as text) -> {owner, settlement}: land bought at town halls

## Paints the land each nation holds in its colour, in the terrain itself:
## a small texture with one texel per hex (colour and tint strength) that
## terrain.gdshader reads. Every border between nations is drawn as a line
## along the hex edges at all times, as in a 4X game; the territory view (T)
## also washes the land in the owner's colour (firmer control, deeper colour)
## and hatches contested hexes in gold. Each nation's name floats over its
## heartland in the territory view.
func draw_fill() -> void:
	_dirty = false
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
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
	# The land and the sea draw the same hexes (territory.gdshaderinc), so
	# territorial waters show their borders too.
	var tex := ImageTexture.create_from_image(img)
	for node in [world.terrain_node, world.sea_node]:
		var mat: ShaderMaterial = node.material_override as ShaderMaterial if node != null else null
		if mat == null:
			continue
		mat.set_shader_parameter("territory_tex", tex)
		mat.set_shader_parameter("hex_radius", hex)
		mat.set_shader_parameter("hex_grid", Vector4(c0, r0, cols, rows))
		mat.set_shader_parameter("show_territory", show_borders)
		mat.set_shader_parameter("show_borders", true)
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

func capture() -> Dictionary:
	return {"owner": Array(owner_of), "control": Array(control).map(func(v): return snappedf(v, 0.1)), "contested": Array(contested), "purchased": purchased.duplicate(true)}

func restore(data: Dictionary) -> void:
	var saved: Array = data.get("owner", [])
	if saved.size() != owner_of.size():
		reset()
		return
	purchased = data.get("purchased", {}).duplicate(true)
	for i in range(saved.size()):
		owner_of[i] = int(saved[i])
		control[i] = float(data.control[i])
		contested[i] = int(data.contested[i])
	draw_fill()
