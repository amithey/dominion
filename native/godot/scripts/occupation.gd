extends Node3D
## Operational zones: taking ground on purpose.
##
## Press O and click the map: a zone (a ring of 60 m) is marked there, and the
## selected forces advance into it on an attack-move. Inside a zone its
## owner's troops count double toward holding the land (territory.gd), so the
## cells there are worn down and taken as a campaign aimed at one place
## rather than wherever an army happens to stand. Taken cells start as
## "occupied" and firm up the longer they are held.
##
## A zone in the land of a nation you are not fighting is an act of war: the
## cabinet asks first and follows the standing orders (a limited operation or
## a declared war), exactly like a first strike.
##
## When every land cell in the zone is yours, the zone is secured and lifted.
## At most MAX_ZONES per nation; a new one replaces the oldest.

const RADIUS := 60.0
const MAX_ZONES := 3
const FORCE_WEIGHT := 2.0   ## how much more a unit counts toward the land inside its own zone

var world: Node
var zones: Array = []       ## {centre: Vector3, radius: float, owner: int, node: Node3D, cells: Array[int]}
var placing := false
var _ring_mesh: ArrayMesh

func setup(world_node: Node) -> void:
	world = world_node

## The next click on the ground places a zone for the selected forces.
func begin_zone() -> void:
	placing = true
	world.hud.notice("Operational zone: click the ground to mark it. The selected forces will advance into it. Esc cancels.")

func cancel() -> void:
	placing = false

## Places a zone at `point` for `forces` (asks the cabinet first when the zone
## lies in the land of a nation you are not fighting).
func place(point: Vector3, forces: Array, owner := 0) -> void:
	placing = false
	var closed := foreign_owners(point, RADIUS, owner)
	if owner == 0 and not closed.is_empty() and world.engagement != null:
		_authorize(closed, func(): _create(point, forces, owner))
		return
	_create(point, forces, owner)

## Asks the cabinet for each nation in turn, then acts.
func _authorize(ids: Array, action: Callable) -> void:
	if ids.is_empty():
		action.call()
		return
	var id: int = ids[0]
	world.engagement.authorize(id, func(): _authorize(ids.slice(1), action))

## Nations (other than `owner` and those already at war or in an operation
## with it) whose land lies inside the circle.
func foreign_owners(point: Vector3, radius: float, owner: int) -> Array:
	var out := []
	for i in cells_in(point, radius):
		var o: int = world.territory.owner_of[i]
		if o >= 0 and o != owner and not world.hostile(owner, o) and not o in out:
			out.append(o)
	return out

func cells_in(point: Vector3, radius: float) -> Array[int]:
	var t: Node = world.territory
	var out: Array[int] = []
	for i in range(t.owner_of.size()):
		if t.terrain[i] == t.Terrain.WATER:
			continue
		var c: Vector3 = t.center(i)
		if Vector2(c.x - point.x, c.z - point.z).length() <= radius + t.cell * 0.35:
			out.append(i)
	return out

func _create(point: Vector3, forces: Array, owner: int) -> void:
	var mine := zones.filter(func(z): return z.owner == owner)
	if mine.size() >= MAX_ZONES:
		lift(mine[0], false)
	var zone := {"centre": point, "radius": RADIUS, "owner": owner, "cells": cells_in(point, RADIUS), "node": _marker(point, owner)}
	zones.append(zone)
	var army: Array = forces.filter(func(u): return not u.dead and u.owner == owner and u.dmg > 0.0)
	deploy(zone, army)
	if owner == 0:
		world.hud.notice("Operational zone marked: %d cells to take. %d units advancing." % [zone.cells.filter(func(i): return world.territory.owner_of[i] != 0).size(), army.size()])

## Spreads the force over the zone: each detachment takes one of the cells
## still to be won (the rest cover the centre), on an attack-move, so the
## ground is held cell by cell instead of by one crowd in the middle.
func deploy(zone: Dictionary, army: Array) -> void:
	if army.is_empty():
		return
	var t: Node = world.territory
	var targets: Array = zone.cells.filter(func(i): return t.owner_of[i] != zone.owner and world.open_ground(t.center(i)))
	# Nearest cells first, so the advance rolls forward from where the army is.
	var from: Vector3 = army[0].node.position
	targets.sort_custom(func(a, b): return t.center(a).distance_to(from) < t.center(b).distance_to(from))
	if targets.is_empty():
		world.order_move(army, zone.centre, true)
		return
	var parties := mini(targets.size(), maxi(1, army.size() / 2))
	for p in range(parties):
		var party: Array = []
		for k in range(p, army.size(), parties):
			party.append(army[k])
		var spot: Vector3 = t.center(targets[p])
		spot.y = world.height_at(spot.x, spot.z)
		world.order_move(party, spot, true)

## Called by territory.gd: the weight a unit adds to the land it stands on.
func weight(u: Dictionary) -> float:
	for z in zones:
		if z.owner == u.owner and Vector2(u.node.position.x - z.centre.x, u.node.position.z - z.centre.z).length() <= z.radius:
			return FORCE_WEIGHT
	return 1.0

## After each territory tick: zones whose land is all taken are secured.
func review() -> void:
	for z in zones.duplicate():
		var held := true
		for i in z.cells:
			if world.territory.owner_of[i] != z.owner:
				held = false
				break
		if held:
			lift(z, true)

func lift(z: Dictionary, secured: bool) -> void:
	zones.erase(z)
	if is_instance_valid(z.node):
		z.node.queue_free()
	if secured and z.owner == 0:
		world.hud.notice("Operational zone secured: the land is yours (occupied; it firms up as you hold it).")

func clear() -> void:
	for z in zones:
		if is_instance_valid(z.node):
			z.node.queue_free()
	zones.clear()
	placing = false

# ---------------------------------------------------------------- the marker

## A ring on the ground in the owner's colour with a floating label.
func _marker(point: Vector3, owner: int) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var colour: Color = Color(world.map.nations[owner].color) if owner < world.map.nations.size() else Color.WHITE
	var ring := MeshInstance3D.new()
	ring.mesh = _ring(point)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(colour.lightened(0.25), 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var label := Label3D.new()
	label.text = "OPERATIONAL ZONE"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.06
	label.outline_size = 12
	label.modulate = colour.lightened(0.4)
	label.no_depth_test = true
	label.position = Vector3(point.x, world.height_at(point.x, point.z) + 12.0, point.z)
	root.add_child(label)
	return root

## A dashed band 1.2 m wide that follows the ground round the circle.
func _ring(point: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 96
	for s in range(segments):
		if s % 4 == 3:
			continue  # the gaps between dashes
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var quad := []
		for a in [a0, a1]:
			for r in [RADIUS - 0.6, RADIUS + 0.6]:
				var x: float = point.x + cos(a) * r
				var z: float = point.z + sin(a) * r
				quad.append(Vector3(x, maxf(world.height_at(x, z), float(world.map.seaLevel)) + 0.35, z))
		st.add_vertex(quad[0]); st.add_vertex(quad[1]); st.add_vertex(quad[2])
		st.add_vertex(quad[1]); st.add_vertex(quad[3]); st.add_vertex(quad[2])
	return st.commit()

# ---------------------------------------------------------------- saves

func capture() -> Array:
	var out := []
	for z in zones:
		out.append({"centre": [z.centre.x, z.centre.y, z.centre.z], "owner": z.owner})
	return out

func restore(data: Array) -> void:
	clear()
	for z in data:
		var c: Array = z.centre
		_create(Vector3(c[0], c[1], c[2]), [], int(z.owner))
