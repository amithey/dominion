extends RefCounted
## Warships and aircraft, built from code like the ground vehicles (armor.gd
## supplies the geometry: eight-corner blocks, cylinders and lofts skinned over
## cross-sections). Ships have real hulls: flared bows that rise to a raked
## stem, a transom stern, red antifouling below the waterline, sloped
## superstructures, masts, a spinning radar and a gun turret that traverses.
## Aircraft have lofted fuselages with glass canopies, swept or straight wings,
## tails, engines, weapons and the nation's roundels; helicopters have rotor
## heads that the game spins. Finishes ride in the vertex colour
## (vehicle.gdshader); moving parts stay separate nodes. Models face +Z.

const NAVAL := ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
const AIR := ["helicopter", "gunship", "jet", "bomber", "drone"]
const PAINTS := {"ship": Color("5e676c"), "sub": Color("2b2f32"), "heli": Color("4d5641"), "gunship": Color("454c3c"),
	"jet": Color("737d84"), "bomber": Color("50585c"), "drone": Color("8a9297")}

const PAINT := Color(0.5, 0.0, 0.0)
const LIGHT := Color(0.58, 0.0, 0.0)
const DARK := Color(0.36, 0.0, 0.0)
const DECK := Color(0.3, 0.1, 0.0)
const METAL := Color(0.5, 1.0, 0.0)
const RUBBER := Color(0.2, 0.75, 0.0)
const TEAM := Color(0.5, 0.0, 1.0)
const GLASS := Color(0.5, 0.0, 0.5)
const RED := Color(0.5, 0.0, 0.25)
const WHITE := Color(1.0, 0.0, 0.0)   # shade 2: deck markings

var world: Node
const Armor := preload("res://scripts/armor.gd")
var g: Armor               # armor.gd, for its geometry
var _materials := {}
var _wake_process: ParticleProcessMaterial
var _wake_mesh: QuadMesh

func setup(world_node: Node) -> void:
	world = world_node
	g = Armor.new()
	g.setup(world)

func material_for(owner: int, finish: String) -> ShaderMaterial:
	var key := "%d:%s" % [owner, finish]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/vehicle.gdshader")
		m.set_shader_parameter("noise_tex", world.noise_texture)
		m.set_shader_parameter("paint", PAINTS[finish])
		m.set_shader_parameter("dust_color", PAINTS[finish] * 0.85)  # salt and exhaust grime, not road dust
		m.set_shader_parameter("team", Color(world.map.nations[owner].color) if owner < world.map.nations.size() else Color.WHITE)
		m.set_shader_parameter("vertex_tone", true)
		_materials[key] = m
	return _materials[key]

## Returns {root, rotor, radar, turret}; unused parts are null.
func build(key: String, owner: int) -> Dictionary:
	var finish := "ship"
	match key:
		"submarine", "nuclearSub": finish = "sub"
		"helicopter": finish = "heli"
		"gunship": finish = "gunship"
		"jet": finish = "jet"
		"bomber": finish = "bomber"
		"drone": finish = "drone"
	g._mat = material_for(owner, finish)
	var st := g._begin()
	var parts := {"root": Node3D.new(), "rotor": null, "radar": null, "turret": null}
	match key:
		"destroyer":
			destroyer(st, parts, 15.0, 2.8)
		"corvette":
			corvette(st, parts, 10.5, 2.2)
		"gunboat":
			gunboat(st, parts, 7.5, 1.8)
		"submarine", "nuclearSub":
			submarine(st, 11.0 if key == "submarine" else 14.0, key == "nuclearSub")
		"helicopter":
			helicopter(st, parts, false)
		"gunship":
			helicopter(st, parts, true)
		"bomber":
			bomber(st)
		"drone":
			drone(st)
		_:
			fighter(st)
	g._attach(parts.root, st)
	return parts

func _node(parts: Dictionary, slot: String, at: Vector3, parent: Node3D = null) -> Array:
	var node := Node3D.new()
	node.position = at
	(parent if parent != null else parts.root).add_child(node)
	parts[slot] = node
	return [node, g._begin()]

# ---------------------------------------------------------------- ships

## A ship's hull from 16 stations: flared sides that narrow to a raked stem,
## a sheer that rises toward the bow, a flat transom, a deck, and red
## antifouling below the waterline. Returns deck height at t (0 stern, 1 bow).
func hull(st: SurfaceTool, length: float, beam: float, freeboard: float, draft: float, bow_rise: float) -> Callable:
	var deck_at := func(t: float) -> float: return freeboard + bow_rise * pow(maxf(0.0, t - 0.45) / 0.55, 2.0)
	var half := func(t: float) -> float:
		if t < 0.55:
			return beam * 0.5 * (0.84 + 0.16 * smoothstep(0.0, 0.3, t))
		return beam * 0.5 * maxf(sqrt(clampf((1.0 - t) / 0.45, 0.0, 1.0)), 0.015)
	var rings := []
	var decks := []
	for i in range(17):
		var t := i / 16.0
		var z := -length * 0.5 + t * length
		var w: float = half.call(t)
		var h: float = deck_at.call(t)
		var d := draft * (1.0 if t < 0.88 else lerpf(1.0, 0.35, (t - 0.88) / 0.12)) * (0.8 if t < 0.08 else 1.0)
		var rake := pow(t, 4.0) * length * 0.05
		var ring := PackedVector3Array([
			Vector3(-w, h, z + rake), Vector3(-w * 0.97, 0.18, z + rake * 0.4), Vector3(-w * 0.93, -0.12, z + rake * 0.3),
			Vector3(-w * 0.7, -d * 0.75, z), Vector3(0, -d, z), Vector3(w * 0.7, -d * 0.75, z),
			Vector3(w * 0.93, -0.12, z + rake * 0.3), Vector3(w * 0.97, 0.18, z + rake * 0.4), Vector3(w, h, z + rake)])
		rings.append(ring)
		decks.append([ring[0], ring[8]])
	g.loft(st, rings, false, func(mid: Vector3) -> Color: return RED if mid.y < -0.1 else (DARK if mid.y < 0.2 else PAINT))
	for i in range(16):
		g._tri(st, decks[i][0], decks[i][1], decks[i + 1][1], Vector3.UP, DECK)
		g._tri(st, decks[i][0], decks[i + 1][1], decks[i + 1][0], Vector3.UP, DECK)
	g.cap(st, rings[0], Vector3.BACK * -1.0, PAINT)
	# Bulwark and railings along the deck edge.
	for i in range(2, 15):
		var t := i / 16.0
		for side: float in [-1.0, 1.0]:
			var p: Vector3 = rings[i][0 if side < 0.0 else 8]
			g.block(st, Vector3(0.04, 0.32, 0.04), p, METAL)
	return deck_at

## A naval gun on a traversing mount: a faceted stealth shield and a long barrel.
func naval_gun(parts: Dictionary, at: Vector3, size: float) -> void:
	var made := _node(parts, "turret", at)
	var t: SurfaceTool = made[1]
	g.hexa(t, [Vector3(-0.55, 0, 0.9), Vector3(0.55, 0, 0.9), Vector3(0.75, 0, -0.9), Vector3(-0.75, 0, -0.9),
		Vector3(-0.3, 0.6, 0.4), Vector3(0.3, 0.6, 0.4), Vector3(0.55, 0.65, -0.8), Vector3(-0.55, 0.65, -0.8)], LIGHT, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3.ZERO))
	g.cyl(t, 0.08 * size, 2.4 * size, Vector3(0, 0.3 * size, 1.9 * size), "z", PAINT, 10, 0.065 * size)
	g.cyl(t, 0.13 * size, 0.35 * size, Vector3(0, 0.3 * size, 0.85 * size), "z", DARK, 10)
	g._attach(made[0], t)

## A mast with yards, sensor boxes and a radar array that turns.
func mast(st: SurfaceTool, parts: Dictionary, at: Vector3, height: float) -> void:
	g.cyl(st, 0.16, height, at + Vector3(0, height * 0.5, 0), "y", LIGHT, 8, 0.07)
	for k: float in [0.45, 0.7]:
		g.block(st, Vector3(1.6 * (1.1 - k), 0.06, 0.06), at + Vector3(0, height * k, 0), METAL)
	g.block(st, Vector3(0.5, 0.35, 0.5), at + Vector3(0, height * 0.55, 0.15), DARK)
	var made := _node(parts, "radar", at + Vector3(0, height, 0))
	var r: SurfaceTool = made[1]
	g.cyl(r, 0.05, 0.3, Vector3(0, 0.15, 0), "y", METAL, 6)
	g.block(r, Vector3(1.5, 0.4, 0.1), Vector3(0, 0.3, 0), DARK, 0.1)
	g.block(r, Vector3(1.4, 0.06, 0.3), Vector3(0, 0.26, -0.1), METAL)
	g._attach(made[0], r)

func destroyer(st: SurfaceTool, parts: Dictionary, length: float, beam: float) -> void:
	var deck: Callable = hull(st, length, beam, 1.1, 0.95, 0.55)
	var h := func(z: float) -> float: return deck.call(z / length + 0.5)
	# Forward superstructure with a raised bridge and wrap-around windows.
	var bz := length * 0.07
	g.block(st, Vector3(beam * 0.74, 1.45, length * 0.17), Vector3(0, h.call(bz), bz), LIGHT, 0.14, 0.35, 0.1)
	g.block(st, Vector3(beam * 0.62, 0.62, length * 0.1), Vector3(0, h.call(bz) + 1.45, bz + 0.2), LIGHT, 0.08, 0.3)
	g.block(st, Vector3(beam * 0.56, 0.18, 0.05), Vector3(0, h.call(bz) + 1.78, bz + length * 0.05 + 0.02), GLASS, 0.0, 0.08)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.05, 0.16, length * 0.06), Vector3(side * beam * 0.31, h.call(bz) + 1.78, bz + 0.3), GLASS)
		# Phased-array panels on the superstructure faces and bridge wings.
		g.block(st, Vector3(0.05, 0.7, 0.7), Vector3(side * beam * 0.34, h.call(bz) + 0.6, bz + 0.2), DARK)
		g.block(st, Vector3(0.5, 0.08, 0.5), Vector3(side * beam * 0.36, h.call(bz) + 1.45, bz + 0.6), LIGHT)
		# Lifeboat canisters and davits amidships.
		g.cyl(st, 0.2, 0.8, Vector3(side * beam * 0.36, h.call(-length * 0.05) + 0.6, -length * 0.05), "z", WHITE, 10)
	mast(st, parts, Vector3(0, h.call(bz) + 2.07, bz - 0.2), 3.0)
	# Funnel with the nation's band and a dark cap.
	var fz := -length * 0.1
	g.block(st, Vector3(beam * 0.42, 1.7, length * 0.1), Vector3(0, h.call(fz), fz), PAINT, 0.1, 0.25, 0.1)
	g.block(st, Vector3(beam * 0.32, 0.3, length * 0.08), Vector3(0, h.call(fz) + 1.2, fz - 0.05), TEAM, 0.02)
	g.block(st, Vector3(beam * 0.3, 0.14, length * 0.07), Vector3(0, h.call(fz) + 1.6, fz - 0.1), METAL)
	# Hangar, close-in weapon system on its roof, helicopter deck at the stern.
	var hz := -length * 0.26
	g.block(st, Vector3(beam * 0.78, 1.25, length * 0.14), Vector3(0, h.call(hz), hz), LIGHT, 0.1, 0.1, 0.05)
	g.cyl(st, 0.26, 0.35, Vector3(0, h.call(hz) + 1.42, hz + 0.4), "y", METAL, 10)
	g.prim(st, _sphere(0.28), Transform3D(Basis().scaled(Vector3(1, 1.3, 1)), Vector3(0, h.call(hz) + 1.85, hz + 0.4)), WHITE)
	var pad := -length * 0.41
	g.block(st, Vector3(0.1, 0.02, 1.0), Vector3(-0.3, h.call(pad) + 0.01, pad), WHITE)
	g.block(st, Vector3(0.1, 0.02, 1.0), Vector3(0.3, h.call(pad) + 0.01, pad), WHITE)
	g.block(st, Vector3(0.6, 0.02, 0.1), Vector3(0, h.call(pad) + 0.01, pad), WHITE)
	# Vertical launch cells on the foredeck, anchor at the bow.
	for r in range(2):
		for c in range(4):
			g.block(st, Vector3(0.28, 0.06, 0.28), Vector3((c - 1.5) * 0.34, h.call(length * 0.2) + 0.0, length * 0.2 + r * 0.34), METAL)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.2, 0.25, 0.15), Vector3(side * 0.35, h.call(length * 0.44) - 0.5, length * 0.44), METAL)
	naval_gun(parts, Vector3(0, h.call(length * 0.31), length * 0.31), 1.0)

func corvette(st: SurfaceTool, parts: Dictionary, length: float, beam: float) -> void:
	var deck: Callable = hull(st, length, beam, 0.95, 0.75, 0.4)
	var h := func(z: float) -> float: return deck.call(z / length + 0.5)
	var bz := length * 0.02
	g.block(st, Vector3(beam * 0.72, 1.3, length * 0.26), Vector3(0, h.call(bz), bz), LIGHT, 0.12, 0.35, 0.2)
	g.block(st, Vector3(beam * 0.6, 0.16, 0.05), Vector3(0, h.call(bz) + 1.0, bz + length * 0.13 - 0.22), GLASS, 0.0, 0.05)
	mast(st, parts, Vector3(0, h.call(bz) + 1.3, bz - 0.3), 2.4)
	g.block(st, Vector3(beam * 0.36, 0.28, length * 0.07), Vector3(0, h.call(bz) + 0.75, bz - length * 0.1), TEAM)
	# Anti-ship missile canisters angled over the stern quarter.
	for side: float in [-1.0, 1.0]:
		for i in range(2):
			var xf := Transform3D(Basis(Vector3.UP, side * 0.35) * Basis(Vector3.RIGHT, -0.25), Vector3(side * 0.35, h.call(-length * 0.22) + 0.3 + i * 0.3, -length * 0.22))
			g.cyl(st, 0.14, 1.6, Vector3.ZERO, "z", DARK, 8, -1.0, xf)
	g.cyl(st, 0.22, 0.3, Vector3(0, h.call(-length * 0.36) + 0.15, -length * 0.36), "y", METAL, 10)
	g.prim(st, _sphere(0.24), Transform3D(Basis().scaled(Vector3(1, 1.3, 1)), Vector3(0, h.call(-length * 0.36) + 0.52, -length * 0.36)), WHITE)
	naval_gun(parts, Vector3(0, h.call(length * 0.3), length * 0.3), 0.8)

func gunboat(st: SurfaceTool, parts: Dictionary, length: float, beam: float) -> void:
	var deck: Callable = hull(st, length, beam, 0.7, 0.5, 0.35)
	var h := func(z: float) -> float: return deck.call(z / length + 0.5)
	var cz := -length * 0.05
	g.block(st, Vector3(beam * 0.7, 0.95, length * 0.3), Vector3(0, h.call(cz), cz), LIGHT, 0.1, 0.35, 0.1)
	g.block(st, Vector3(beam * 0.62, 0.22, 0.05), Vector3(0, h.call(cz) + 0.62, cz + length * 0.15 - 0.3), GLASS, 0.0, 0.1)
	for side: float in [-1.0, 1.0]:
		g.block(st, Vector3(0.05, 0.22, length * 0.18), Vector3(side * beam * 0.33, h.call(cz) + 0.6, cz), GLASS)
		g.cyl(st, 0.03, 0.9, Vector3(side * 0.45, h.call(-length * 0.35) + 0.6, -length * 0.35), "z", METAL, 6)
	g.block(st, Vector3(beam * 0.4, 0.2, 0.6), Vector3(0, h.call(cz) + 0.95, cz - 0.3), TEAM)
	mast(st, parts, Vector3(0, h.call(cz) + 0.95, cz - 0.2), 1.6)
	naval_gun(parts, Vector3(0, h.call(length * 0.3), length * 0.3), 0.55)

## Teardrop hull lofted from rings, a sail with diving planes, cruciform
## tail and propeller; the ballistic-missile boat has a missile deck.
func submarine(st: SurfaceTool, length: float, missiles: bool) -> void:
	var r := length * 0.075
	var rings := []
	for i in range(19):
		var t := i / 18.0
		var z := -length * 0.5 + t * length
		var k := 1.0
		if t > 0.86:
			k = sqrt(maxf(0.0, 1.0 - pow((t - 0.86) / 0.14, 2.0)))
		elif t < 0.3:
			k = lerpf(0.12, 1.0, smoothstep(0.0, 0.3, t))
		rings.append(g.ellipse(z, r * maxf(k, 0.04), r * maxf(k, 0.04), 0.0, 14))
	g.loft(st, rings, true, func(mid: Vector3) -> Color: return PAINT if mid.y > -r * 0.35 else DARK)
	g.cap(st, rings[0], Vector3.BACK * -1.0, DARK)
	var sz := length * 0.16
	g.block(st, Vector3(r * 0.55, r * 1.5, length * 0.14), Vector3(0, r * 0.7, sz), PAINT, r * 0.05, length * 0.03, length * 0.01)
	g.block(st, Vector3(r * 0.57, r * 0.25, length * 0.07), Vector3(0, r * 1.75, sz + 0.2), TEAM, 0.0, 0.1)
	g.block(st, Vector3(r * 2.6, 0.06, length * 0.035), Vector3(0, r * 1.5, sz + 0.2), PAINT)
	for k: float in [0.25, 0.5]:
		g.cyl(st, 0.03, 0.6, Vector3(0.1 * (k - 0.37) * 4.0, r * 2.2 + 0.3, sz), "y", METAL, 4)
	# Cruciform tail and a seven-bladed propeller.
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var xf := Transform3D(Basis(Vector3.BACK, a), Vector3(0, 0, -length * 0.42))
		g.block(st, Vector3(0.05, r * 1.3, length * 0.07), Vector3(0, 0, 0), PAINT, 0.0, length * 0.03, 0.0, xf)
	g.cyl(st, r * 0.15, 0.2, Vector3(0, 0, -length * 0.5 - 0.1), "z", METAL, 8)
	for b in range(7):
		var xf := Transform3D(Basis(Vector3.BACK, TAU * b / 7.0) * Basis(Vector3.UP, 0.4), Vector3(0, 0, -length * 0.5 - 0.1))
		g.block(st, Vector3(0.1, r * 0.55, 0.04), Vector3(0, 0, 0), METAL, 0.0, 0.0, 0.0, xf)
	if missiles:
		# The missile deck: a hump aft of the sail with rows of hatches.
		g.block(st, Vector3(r * 1.1, r * 0.25, length * 0.26), Vector3(0, r * 0.85, -length * 0.06), PAINT, r * 0.15, 0.3, 0.3)
		for i in range(6):
			for side: float in [-1.0, 1.0]:
				g.cyl(st, r * 0.17, 0.04, Vector3(side * r * 0.25, r * 1.11, -length * 0.16 + i * length * 0.04), "y", DARK, 10)

# ---------------------------------------------------------------- aircraft

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s

## Fuselage lofted along Z from (t, half-width, half-height, centre y) stations.
func fuselage(st: SurfaceTool, length: float, stations: Array, colour: Color) -> void:
	var rings := []
	for s in stations:
		rings.append(g.ellipse(-length * 0.5 + s[0] * length, maxf(s[1], 0.01), maxf(s[2], 0.01), s[3] if s.size() > 3 else 0.0, 12))
	g.loft(st, rings, true, func(_mid: Vector3) -> Color: return colour)
	g.cap(st, rings[0], Vector3.BACK * -1.0, DARK)

## A flat surface (wing, stabiliser or fin) from a root and a tip chord:
## root_front/back and tip_front/back are points on its mid-plane.
func surface(st: SurfaceTool, rf: Vector3, rb: Vector3, tf: Vector3, tb: Vector3, thick_root: float, thick_tip: float, normal: Vector3, colour: Color) -> void:
	var n := normal.normalized()
	g.hexa(st, [rf - n * thick_root * 0.5, tf - n * thick_tip * 0.5, tb - n * thick_tip * 0.5, rb - n * thick_root * 0.5,
		rf + n * thick_root * 0.5, tf + n * thick_tip * 0.5, tb + n * thick_tip * 0.5, rb + n * thick_root * 0.5], colour)

func roundel(st: SurfaceTool, at: Vector3, r: float) -> void:
	g.cyl(st, r, 0.02, at, "y", WHITE, 14)
	g.cyl(st, r * 0.62, 0.03, at, "y", TEAM, 14)

func missile(st: SurfaceTool, at: Vector3, length: float) -> void:
	g.cyl(st, length * 0.05, length, at, "z", WHITE, 8)
	g.cyl(st, length * 0.05, length * 0.18, at + Vector3(0, 0, length * 0.59), "z", DARK, 8, 0.005)
	for a: float in [0.0, PI * 0.5]:
		g.block(st, Vector3(length * 0.2, 0.02, length * 0.1), Vector3.ZERO, METAL, 0.0, 0.0, 0.0, Transform3D(Basis(Vector3.BACK, a), at + Vector3(0, 0, -length * 0.42)))

## Twin-engine air superiority fighter: blended fuselage, bubble canopy,
## swept wings, twin canted tails, missiles on the wing stations.
func fighter(st: SurfaceTool) -> void:
	var l := 8.5
	fuselage(st, l, [[0.0, 0.62, 0.3], [0.08, 0.7, 0.34], [0.3, 0.72, 0.36], [0.55, 0.55, 0.38, 0.04], [0.7, 0.38, 0.36, 0.06], [0.84, 0.26, 0.28, 0.02], [0.94, 0.12, 0.13], [1.0, 0.01, 0.01]], PAINT)
	g.prim(st, _sphere(0.3), Transform3D(Basis().scaled(Vector3(0.95, 0.95, 3.2)), Vector3(0, 0.36, l * 0.2)), GLASS)
	# Engine nozzles and intakes.
	for side: float in [-1.0, 1.0]:
		g.cyl(st, 0.26, 0.5, Vector3(side * 0.34, 0.0, -l * 0.5 - 0.15), "z", METAL, 12, 0.3)
		g.cyl(st, 0.2, 0.06, Vector3(side * 0.34, 0.0, -l * 0.5 - 0.41), "z", DARK, 12)
		g.block(st, Vector3(0.36, 0.5, 1.6), Vector3(side * 0.62, -0.28, l * 0.06), DARK, 0.04, 0.3)
		# Wing, horizontal tail, canted fin with the nation's flash.
		surface(st, Vector3(side * 0.6, 0, 0.8), Vector3(side * 0.6, 0, -2.4), Vector3(side * 3.5, 0, -2.0), Vector3(side * 3.5, 0, -2.7), 0.16, 0.05, Vector3.UP, PAINT)
		surface(st, Vector3(side * 0.5, 0, -2.9), Vector3(side * 0.5, 0, -4.1), Vector3(side * 1.9, 0, -3.8), Vector3(side * 1.9, 0, -4.35), 0.08, 0.04, Vector3.UP, PAINT)
		var tip := Vector3(side * 0.95, 1.55, -3.9)
		surface(st, Vector3(side * 0.42, 0.25, -2.4), Vector3(side * 0.42, 0.25, -4.1), tip, tip + Vector3(0, 0, -0.55), 0.1, 0.04, Vector3(1, -0.3 * side, 0) if side > 0 else Vector3(1, 0.3, 0), PAINT)
		g.block(st, Vector3(0.13, 0.3, 0.5), Vector3(side * 0.74, 0.95, -3.55), TEAM)
		roundel(st, Vector3(side * 2.4, 0.09, -1.6), 0.36)
		missile(st, Vector3(side * 3.5, -0.08, -1.9), 1.7)
		missile(st, Vector3(side * 2.2, -0.24, -1.2), 1.9)
		g.block(st, Vector3(0.05, 0.14, 0.9), Vector3(side * 2.2, -0.14, -1.2), METAL)

## Strategic bomber: long fuselage, swept wings with four engine pods, a tall fin.
func bomber(st: SurfaceTool) -> void:
	var l := 9.5
	fuselage(st, l, [[0.0, 0.2, 0.3, 0.2], [0.1, 0.42, 0.55], [0.5, 0.5, 0.6], [0.78, 0.48, 0.56], [0.9, 0.38, 0.45, 0.05], [0.97, 0.2, 0.24], [1.0, 0.02, 0.02]], PAINT)
	g.block(st, Vector3(0.7, 0.28, 0.9), Vector3(0, 0.42, l * 0.36), GLASS, 0.18, 0.4, 0.1)
	for side: float in [-1.0, 1.0]:
		surface(st, Vector3(side * 0.45, 0.1, 1.2), Vector3(side * 0.45, 0.1, -1.4), Vector3(side * 5.75, -0.1, -2.4), Vector3(side * 5.75, -0.1, -3.2), 0.28, 0.07, Vector3.UP, PAINT)
		surface(st, Vector3(side * 0.3, 0.2, -3.6), Vector3(side * 0.3, 0.2, -4.6), Vector3(side * 2.2, 0.2, -4.3), Vector3(side * 2.2, 0.2, -4.8), 0.1, 0.04, Vector3.UP, PAINT)
		for e: float in [1.8, 3.3]:
			var z := 0.4 - e * 0.36
			g.block(st, Vector3(0.06, 0.3, 0.8), Vector3(side * e, -0.25, z), METAL)
			g.cyl(st, 0.24, 1.3, Vector3(side * e, -0.45, z + 0.2), "z", DARK, 12, 0.2)
			g.cyl(st, 0.18, 0.05, Vector3(side * e, -0.45, z + 0.86), "z", METAL, 12)
		roundel(st, Vector3(side * 3.6, 0.1, -1.4), 0.42)
	surface(st, Vector3(0, 0.4, -2.6), Vector3(0, 0.4, -4.7), Vector3(0, 2.4, -4.2), Vector3(0, 2.4, -5.0), 0.12, 0.05, Vector3.RIGHT, PAINT)
	g.block(st, Vector3(0.14, 0.45, 0.6), Vector3(0, 1.8, -4.45), TEAM)

## Reconnaissance drone: slim body with a bulbous sensor nose, long straight
## wings, an inverted V-tail and a pusher propeller.
func drone(st: SurfaceTool) -> void:
	var l := 3.2
	fuselage(st, l, [[0.0, 0.08, 0.1], [0.2, 0.16, 0.18], [0.6, 0.18, 0.2, 0.02], [0.85, 0.2, 0.24, 0.06], [0.97, 0.12, 0.14, 0.04], [1.0, 0.02, 0.02, 0.03]], PAINT)
	g.prim(st, _sphere(0.13), Transform3D(Basis(), Vector3(0, -0.2, l * 0.3)), GLASS)
	for side: float in [-1.0, 1.0]:
		surface(st, Vector3(side * 0.15, 0.1, 0.35), Vector3(side * 0.15, 0.1, -0.15), Vector3(side * 2.3, 0.14, 0.2), Vector3(side * 2.3, 0.14, -0.05), 0.07, 0.03, Vector3.UP, PAINT)
		surface(st, Vector3(side * 0.08, -0.05, -1.2), Vector3(side * 0.08, -0.05, -1.5), Vector3(side * 0.6, -0.55, -1.35), Vector3(side * 0.6, -0.55, -1.55), 0.04, 0.02, Vector3(1, side * 0.9, 0) if side > 0 else Vector3(1, -0.9, 0), PAINT)
		roundel(st, Vector3(side * 1.6, 0.18, 0.1), 0.14)
		missile(st, Vector3(side * 1.1, 0.0, 0.1), 0.7)
	for b in range(3):
		g.block(st, Vector3(0.05, 0.42, 0.02), Vector3(0, -0.21, 0), METAL, 0.0, 0.0, 0.0, Transform3D(Basis(Vector3.BACK, TAU * b / 3.0), Vector3(0, 0.0, -l * 0.5 - 0.04)))

## Attack helicopter (tandem cockpits, stub wings with rocket pods and
## missiles) or heavy gunship (bigger cabin, five blades, twin pods a side).
func helicopter(st: SurfaceTool, parts: Dictionary, heavy: bool) -> void:
	var s := 1.25 if heavy else 1.0
	var w := 0.72 if heavy else 0.5
	fuselage(st, 4.8 * s, [[0.0, w * 0.6, 0.55 * s, 0.25], [0.2, w, 0.8 * s, 0.1], [0.55, w, 0.85 * s], [0.8, w * 0.85, 0.7 * s, -0.1], [0.94, w * 0.55, 0.45 * s, -0.25], [1.0, w * 0.2, 0.2 * s, -0.35]], PAINT)
	# Stepped tandem canopies (gunner in front, pilot above and behind).
	g.prim(st, _sphere(0.42 * s), Transform3D(Basis().scaled(Vector3(w * 1.9, 0.9, 1.9)), Vector3(0, 0.25 * s, 1.55 * s)), GLASS)
	g.prim(st, _sphere(0.42 * s), Transform3D(Basis().scaled(Vector3(w * 1.9, 1.0, 1.7)), Vector3(0, 0.62 * s, 0.6 * s)), GLASS)
	if heavy:
		for i in range(3):
			for side: float in [-1.0, 1.0]:
				g.block(st, Vector3(0.04, 0.3, 0.35), Vector3(side * w * 1.0, 0.1, -0.2 - i * 0.55), GLASS)
	# Tail boom, fin, stabiliser, tail rotor.
	var boom := []
	for i in range(5):
		var t := i / 4.0
		boom.append(g.ellipse(-2.2 * s - t * 3.6 * s, lerpf(0.34, 0.12, t) * s, lerpf(0.4, 0.14, t) * s, lerpf(0.2, 0.45, t) * s, 10))
	g.loft(st, boom, true, func(_m: Vector3) -> Color: return PAINT)
	surface(st, Vector3(0, 0.4 * s, -5.3 * s), Vector3(0, 0.4 * s, -6.0 * s), Vector3(0, 1.6 * s, -5.8 * s), Vector3(0, 1.6 * s, -6.3 * s), 0.1, 0.05, Vector3.RIGHT, PAINT)
	g.block(st, Vector3(0.12, 0.35, 0.4), Vector3(0, 1.0 * s, -5.9 * s), TEAM)
	surface(st, Vector3(0, 0.45 * s, -5.0 * s), Vector3(0, 0.45 * s, -5.5 * s), Vector3(1.0 * s, 0.45 * s, -5.1 * s), Vector3(1.0 * s, 0.45 * s, -5.45 * s), 0.06, 0.03, Vector3.UP, PAINT)
	surface(st, Vector3(0, 0.45 * s, -5.0 * s), Vector3(0, 0.45 * s, -5.5 * s), Vector3(-1.0 * s, 0.45 * s, -5.1 * s), Vector3(-1.0 * s, 0.45 * s, -5.45 * s), 0.06, 0.03, Vector3.UP, PAINT)
	for b in range(4):
		g.block(st, Vector3(0.03, 1.3 * s, 0.1), Vector3(0, -0.65 * s, 0), METAL, 0.0, 0.0, 0.0, Transform3D(Basis(Vector3.RIGHT, TAU * b / 4.0), Vector3(0.14 * s, 1.3 * s, -6.05 * s)))
	# Engines either side of the rotor mast, exhausts, chin gun, landing gear.
	for side: float in [-1.0, 1.0]:
		g.cyl(st, 0.26 * s, 1.5 * s, Vector3(side * (w + 0.1), 0.72 * s, -0.4 * s), "z", LIGHT, 10, 0.22 * s)
		g.cyl(st, 0.17 * s, 0.3 * s, Vector3(side * (w + 0.1), 0.72 * s, -1.25 * s), "z", METAL, 10)
		g.block(st, Vector3(0.06, 0.08, 0.9 * s), Vector3(side * 0.55 * s, -1.0 * s, 0.3), METAL)
		g.cyl(st, 0.16, 0.12, Vector3(side * 0.55 * s, -0.95 * s, 0.9), "x", RUBBER, 10)
		g.block(st, Vector3(0.05, 0.55 * s, 0.05), Vector3(side * 0.5 * s, -0.95 * s, 0.9), METAL)
		# Stub wing with rocket pods and anti-tank missiles.
		surface(st, Vector3(side * w * 0.9, -0.05, 0.4), Vector3(side * w * 0.9, -0.05, -0.4), Vector3(side * (w + 1.2 * s), -0.2, 0.25), Vector3(side * (w + 1.2 * s), -0.2, -0.3), 0.14, 0.08, Vector3.UP, PAINT)
		var pods := [w + 0.55 * s, w + 1.1 * s] if heavy else [w + 0.7 * s]
		for x: float in pods:
			g.cyl(st, 0.2, 1.1, Vector3(side * x, -0.45, 0.05), "z", DARK, 12)
			g.cyl(st, 0.16, 0.04, Vector3(side * x, -0.45, 0.62), "z", METAL, 12)
		if not heavy:
			for m in range(2):
				missile(st, Vector3(side * (w + 1.15), -0.35 - m * 0.2, 0.1), 0.9)
	g.cyl(st, 0.14, 0.2, Vector3(0, -0.65 * s, 1.7 * s), "y", METAL, 10)
	g.cyl(st, 0.03, 0.7, Vector3(0, -0.75 * s, 2.0 * s), "z", METAL, 6)
	g.cyl(st, 0.1, 0.5, Vector3(0, 0.95 * s, 0.1), "y", METAL, 8)
	# Rotor head and blades: a node the game spins.
	var made := _node(parts, "rotor", Vector3(0, 1.22 * s, 0.1))
	var r: SurfaceTool = made[1]
	g.cyl(r, 0.2 * s, 0.22, Vector3.ZERO, "y", METAL, 10)
	var blades := 5 if heavy else 4
	for b in range(blades):
		var xf := Transform3D(Basis(Vector3.UP, TAU * b / blades) * Basis(Vector3.BACK, 0.03), Vector3.ZERO)
		g.block(r, Vector3(0.28 * s, 0.035, 3.0 * s), Vector3(0, 0, 1.6 * s), DARK, 0.0, 0.0, 0.0, xf)
	g._attach(made[0], r)

## Foam churned up behind a moving ship.
func wake(length: float) -> GPUParticles3D:
	if _wake_process == null:
		_wake_process = ParticleProcessMaterial.new()
		_wake_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_wake_process.emission_box_extents = Vector3(0.9, 0.05, 0.4)
		_wake_process.direction = Vector3(0, 0.2, -1)
		_wake_process.spread = 25
		_wake_process.initial_velocity_min = 0.3
		_wake_process.initial_velocity_max = 1.0
		_wake_process.gravity = Vector3.ZERO
		_wake_process.scale_min = 1.0
		_wake_process.scale_max = 1.8
		var grow := Curve.new()
		grow.add_point(Vector2(0, 0.6))
		grow.add_point(Vector2(1, 1.0))
		var grow_tex := CurveTexture.new()
		grow_tex.curve = grow
		_wake_process.scale_curve = grow_tex
		var fade := Gradient.new()
		fade.set_color(0, Color(0.95, 0.97, 0.97, 0.7))
		fade.set_color(1, Color(0.9, 0.95, 0.95, 0.0))
		var fade_tex := GradientTexture1D.new()
		fade_tex.gradient = fade
		_wake_process.color_ramp = fade_tex
		var puff := Gradient.new()
		puff.set_color(0, Color(1, 1, 1, 1))
		puff.set_color(1, Color(1, 1, 1, 0))
		var puff_tex := GradientTexture2D.new()
		puff_tex.gradient = puff
		puff_tex.fill = GradientTexture2D.FILL_RADIAL
		puff_tex.fill_from = Vector2(0.5, 0.5)
		puff_tex.fill_to = Vector2(0.5, 0.0)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = puff_tex
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_wake_mesh = QuadMesh.new()
		_wake_mesh.size = Vector2(2.2, 2.2)
		_wake_mesh.material = m
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 3.5
	p.local_coords = false
	p.emitting = false
	p.process_material = _wake_process
	p.draw_pass_1 = _wake_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0.1, -length * 0.45)
	return p

