extends RefCounted
## Buildings built from code, in the manner of a modern 4X city.
##
## Instead of one generic model scaled to a hex, a district is made of real
## architecture: plastered and brick townhouses with tiled roofs, chimneys,
## shuttered windows and front doors; civic buildings of cut stone with
## columned porticoes, pediments, domes and clock towers; timber-framed village
## halls; brick factories with saw-tooth roofs and stacks. The nation's colour
## flies on banners on the civic facades.
##
## Surfaces carry texture generated once at start-up (plaster, brick, cut
## stone, roof tiles, each with a relief map from its own height field), so
## nothing is downloaded. UVs are laid in metres, so bricks and tiles keep
## their size on any wall or roof. Everything a district holds is gathered into
## one mesh per material (a handful of draws per district).

enum { PLASTER, BRICK, STONE, ROOF, TRIM, GLASS, WOOD, BANNER, METAL, PLANK }

var world: Node
var _materials := {}
var _st := {}             # surface -> SurfaceTool for the building being made
var xf := Transform3D.IDENTITY   # where the next piece goes, in the container's space
var banner_colour := Color.WHITE
var extract_type := ""    # the deposit under an Extractor, which decides what is built on it

func _init(world_node: Node) -> void:
	world = world_node

# ---------------------------------------------------------------- textures

## A tileable 1 m texture and its relief map, drawn by `paint(x, y) -> [shade, height]`.
func _texture(size: int, paint: Callable) -> Array:
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bump := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var v: Array = paint.call(x, y)
			var s: float = v[0]
			albedo.set_pixel(x, y, Color(s, s, s))
			bump.set_pixel(x, y, Color(v[1], v[1], v[1]))
	albedo.generate_mipmaps()
	bump.bump_map_to_normal_map(3.0)
	bump.generate_mipmaps()
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(bump)]

func _noise(seed: int, frequency: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = frequency
	return n

func _material(kind: int) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	var n := _noise(7 + kind, 0.08)
	var tex: Array = []
	match kind:
		PLASTER:
			# Smooth render with faint trowel marks and weathering.
			var grain := _noise(3, 0.6)
			tex = _texture(128, func(x: int, y: int) -> Array:
				var v := n.get_noise_2d(x, y) * 0.5 + 0.5
				var fine := grain.get_noise_2d(x, y) * 0.5 + 0.5
				return [0.86 + v * 0.1 + fine * 0.04, v * 0.4 + fine * 0.2])
		BRICK:
			# Courses of bricks 25 x 6.5 cm, offset every other course, pale mortar.
			tex = _texture(128, func(x: int, y: int) -> Array:
				var row := y / 8
				var shift := 16 if row % 2 == 1 else 0
				var mortar := (y % 8 == 0) or ((x + shift) % 32 == 0)
				var tone := fposmod(sin(float(row * 13 + (x + shift) / 32) * 12.9898) * 43758.5453, 1.0)
				if mortar:
					return [1.0, 0.0]
				return [0.62 + tone * 0.22 + (n.get_noise_2d(x, y) * 0.06), 0.8])
		STONE:
			# Ashlar: cut blocks 64 x 32 cm with fine joints.
			tex = _texture(128, func(x: int, y: int) -> Array:
				var row := y / 40
				var shift := 40 if row % 2 == 1 else 0
				var joint := (y % 40 < 2) or ((x + shift) % 80 < 2)
				var tone := fposmod(sin(float(row * 7 + (x + shift) / 80) * 78.233) * 43758.5453, 1.0)
				if joint:
					return [0.62, 0.0]
				return [0.84 + tone * 0.12 + n.get_noise_2d(x, y) * 0.05, 0.7 + n.get_noise_2d(x * 2, y * 2) * 0.2])
		ROOF:
			# Rows of overlapping tiles: each row darkens toward the one lying over it.
			tex = _texture(128, func(x: int, y: int) -> Array:
				var row := y / 16
				var shift := 8 if row % 2 == 1 else 0
				var in_row := float(y % 16) / 16.0
				var gap := (x + shift) % 16 == 0
				var tone := fposmod(sin(float(row * 31 + (x + shift) / 16) * 12.9898) * 43758.5453, 1.0)
				var shade := 0.78 + in_row * 0.2 + tone * 0.1
				if gap:
					shade *= 0.6
				return [clampf(shade, 0.0, 1.0), in_row])
		METAL:
			# Corrugated sheet: vertical ribs every 7.5 cm, lighter on the crests.
			tex = _texture(128, func(x: int, y: int) -> Array:
				var rib := 0.5 + 0.5 * cos(float(x) / 128.0 * TAU * 13.0)
				return [0.78 + rib * 0.18 + n.get_noise_2d(x, y) * 0.03, rib])
			m.metallic = 0.45
			m.roughness = 0.55
		PLANK:
			# Barn boards: vertical planks 16 cm wide with dark gaps and grain.
			tex = _texture(128, func(x: int, y: int) -> Array:
				var gap := x % 20 < 1
				var grain := n.get_noise_2d(x * 4, y * 0.3) * 0.08
				var tone := fposmod(sin(float(x / 20) * 12.9898) * 43758.5453, 1.0)
				if gap:
					return [0.45, 0.0]
				return [0.78 + tone * 0.14 + grain, 0.8])
			m.roughness = 0.9
		GLASS:
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.08
			m.metallic = 0.6
			m.metallic_specular = 0.9
		WOOD:
			m.roughness = 0.8
		BANNER:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.9
	if not tex.is_empty():
		m.albedo_texture = tex[0]
		m.normal_enabled = true
		m.normal_texture = tex[1]
		m.normal_scale = 1.2
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[kind] = m
	return m

# ---------------------------------------------------------------- geometry

func begin() -> void:
	_st.clear()
	xf = Transform3D.IDENTITY

func _tool(kind: int) -> SurfaceTool:
	if not _st.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[kind] = st
	return _st[kind]

## A flat quad a-b-c-d (counter-clockwise seen from the front), UVs in metres.
func quad(kind: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, uv_scale := 1.0) -> void:
	var st := _tool(kind)
	var pa := xf * a
	var pb := xf * b
	var pc := xf * c
	var pd := xf * d
	var n := (pb - pa).cross(pd - pa).normalized()
	var u := (b - a).length()
	var v := (d - a).length()
	var uvs := [Vector2(0, v), Vector2(u, v), Vector2(u, 0), Vector2(0, 0)]
	var pts := [pa, pb, pc, pd]
	# Godot's front faces wind clockwise; these quads are given counter-clockwise
	# as seen from outside (the normal above points out), so they are emitted reversed.
	for k in [0, 2, 1, 0, 3, 2]:
		st.set_color(colour)
		st.set_normal(n)
		st.set_uv(uvs[k] * uv_scale)
		st.add_vertex(pts[k])

func tri(kind: int, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var st := _tool(kind)
	var pa := xf * a
	var pb := xf * b
	var pc := xf * c
	var n := (pb - pa).cross(pc - pa).normalized()
	for p in [[pa, Vector2(a.x + a.z, a.y)], [pc, Vector2(c.x + c.z, c.y)], [pb, Vector2(b.x + b.z, b.y)]]:
		st.set_color(colour)
		st.set_normal(n)
		st.set_uv(Vector2(p[1].x, -p[1].y))
		st.add_vertex(p[0])

## An axis-aligned box from `lo` to `hi` (all six faces).
func box(kind: int, lo: Vector3, hi: Vector3, colour: Color) -> void:
	var c := [Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
		Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z)]
	quad(kind, c[0], c[1], c[2], c[3], colour)      # front (+z)
	quad(kind, c[4], c[5], c[6], c[7], colour)      # back
	quad(kind, c[1], c[4], c[7], c[2], colour)      # right (+x)
	quad(kind, c[5], c[0], c[3], c[6], colour)      # left
	quad(kind, c[3], c[2], c[7], c[6], colour)      # top
	quad(kind, c[5], c[4], c[1], c[0], colour)      # bottom

func cylinder(kind: int, centre: Vector3, r: float, h: float, colour: Color, sides := 10, top_r := -1.0) -> void:
	var r2 := r if top_r < 0.0 else top_r
	for i in range(sides):
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := centre + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var b1 := centre + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var t0 := centre + Vector3(cos(a0) * r2, h, sin(a0) * r2)
		var t1 := centre + Vector3(cos(a1) * r2, h, sin(a1) * r2)
		quad(kind, b1, b0, t0, t1, colour)
		if r2 > 0.0:
			tri(kind, centre + Vector3(0, h, 0), t1, t0, colour)

## A dome of `rings` bands on a circle of radius r at `centre`.
func dome(kind: int, centre: Vector3, r: float, rise: float, colour: Color, sides := 16, rings := 5) -> void:
	for j in range(rings):
		var f0 := float(j) / rings
		var f1 := float(j + 1) / rings
		var r0 := r * cos(f0 * PI * 0.5)
		var r1 := r * cos(f1 * PI * 0.5)
		var y0 := rise * sin(f0 * PI * 0.5)
		var y1 := rise * sin(f1 * PI * 0.5)
		for i in range(sides):
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			quad(kind, centre + Vector3(cos(a1) * r0, y0, sin(a1) * r0), centre + Vector3(cos(a0) * r0, y0, sin(a0) * r0),
				centre + Vector3(cos(a0) * r1, y1, sin(a0) * r1), centre + Vector3(cos(a1) * r1, y1, sin(a1) * r1), colour)

# ---------------------------------------------------------------- elements

## Four walls of a w x d block, `height` tall, standing on y0 (front faces +z).
func walls(kind: int, w: float, d: float, y0: float, height: float, colour: Color) -> void:
	var x := w * 0.5
	var z := d * 0.5
	var y1 := y0 + height
	quad(kind, Vector3(-x, y0, z), Vector3(x, y0, z), Vector3(x, y1, z), Vector3(-x, y1, z), colour)
	quad(kind, Vector3(x, y0, -z), Vector3(-x, y0, -z), Vector3(-x, y1, -z), Vector3(x, y1, -z), colour)
	quad(kind, Vector3(x, y0, z), Vector3(x, y0, -z), Vector3(x, y1, -z), Vector3(x, y1, z), colour)
	quad(kind, Vector3(-x, y0, -z), Vector3(-x, y0, z), Vector3(-x, y1, z), Vector3(-x, y1, -z), colour)

## A window on a wall facing +z at `centre` (width w, height h): dark glass
## with a light frame, a sill, and optionally painted shutters.
func window(centre: Vector3, w: float, h: float, frame: Color, shutters := Color(0, 0, 0, 0), lit := false) -> void:
	var z := centre.z + 0.02
	var glass := Color("24303a") if not lit else Color("f0c070")
	quad(GLASS, Vector3(centre.x - w * 0.5, centre.y - h * 0.5, z), Vector3(centre.x + w * 0.5, centre.y - h * 0.5, z),
		Vector3(centre.x + w * 0.5, centre.y + h * 0.5, z), Vector3(centre.x - w * 0.5, centre.y + h * 0.5, z), glass)
	var t := 0.08
	box(TRIM, Vector3(centre.x - w * 0.5 - t, centre.y + h * 0.5, z - 0.02), Vector3(centre.x + w * 0.5 + t, centre.y + h * 0.5 + t, z + 0.06), frame)
	box(TRIM, Vector3(centre.x - w * 0.5 - t, centre.y - h * 0.5 - t * 1.5, z - 0.02), Vector3(centre.x + w * 0.5 + t, centre.y - h * 0.5, z + 0.14), frame)
	box(TRIM, Vector3(centre.x - w * 0.5 - t, centre.y - h * 0.5, z - 0.02), Vector3(centre.x - w * 0.5, centre.y + h * 0.5, z + 0.05), frame)
	box(TRIM, Vector3(centre.x + w * 0.5, centre.y - h * 0.5, z - 0.02), Vector3(centre.x + w * 0.5 + t, centre.y + h * 0.5, z + 0.05), frame)
	box(TRIM, Vector3(centre.x - 0.02, centre.y - h * 0.5, z), Vector3(centre.x + 0.02, centre.y + h * 0.5, z + 0.04), frame)  # mullion
	if shutters.a > 0.0:
		for side in [-1.0, 1.0]:
			var x0: float = centre.x + side * (w * 0.5 + t + 0.02)
			var x1: float = x0 + side * w * 0.45
			box(WOOD, Vector3(minf(x0, x1), centre.y - h * 0.5, z - 0.01), Vector3(maxf(x0, x1), centre.y + h * 0.5, z + 0.04), shutters)

## Rows of windows on all four sides of a w x d block, `floors` storeys of `storey` metres.
func fenestrate(w: float, d: float, y0: float, floors: int, storey: float, frame: Color, shutters := Color(0, 0, 0, 0), rng: RandomNumberGenerator = null, skip_door := true) -> void:
	for side in range(4):
		var yaw := side * PI * 0.5
		var span := w if side % 2 == 0 else d
		var depth := d if side % 2 == 0 else w
		var saved := xf
		xf = xf * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
		var n := maxi(1, int(span / 1.9))
		for f in range(floors):
			for i in range(n):
				var x := -span * 0.5 + span * (i + 0.5) / n
				if skip_door and f == 0 and side == 0 and absf(x) < span / n * 0.6:
					continue  # the door goes here
				var lit: bool = rng != null and rng.randf() < 0.12
				window(Vector3(x, y0 + storey * (f + 0.55), depth * 0.5), 0.8, storey * 0.5, frame, shutters, lit)
		xf = saved

## A front door on the +z face with a small canopy.
func door(x: float, y0: float, z: float, colour: Color, canopy: Color) -> void:
	box(WOOD, Vector3(x - 0.55, y0, z), Vector3(x + 0.55, y0 + 2.2, z + 0.08), colour)
	box(TRIM, Vector3(x - 0.75, y0 + 2.2, z), Vector3(x + 0.75, y0 + 2.4, z + 0.12), Color("d8d0bc"))
	box(ROOF, Vector3(x - 0.9, y0 + 2.55, z), Vector3(x + 0.9, y0 + 2.65, z + 0.9), canopy)
	box(STONE, Vector3(x - 0.8, y0 - 0.02, z), Vector3(x + 0.8, y0 + 0.18, z + 0.6), Color("b8b0a0"))

## A cornice: a projecting band round the top of a w x d block at height y.
func cornice(w: float, d: float, y: float, colour: Color, depth := 0.25, band := 0.3) -> void:
	box(TRIM, Vector3(-w * 0.5 - depth, y, -d * 0.5 - depth), Vector3(w * 0.5 + depth, y + band, d * 0.5 + depth), colour)

## A hipped roof over w x d at y0 (with eaves `over` beyond the walls).
func hip_roof(w: float, d: float, y0: float, rise: float, colour: Color, over := 0.45) -> void:
	var x := w * 0.5 + over
	var z := d * 0.5 + over
	var ridge := maxf(x - z, 0.0) if w >= d else 0.0
	var ridge_z := maxf(z - x, 0.0) if d > w else 0.0
	var top := y0 + rise
	var a := Vector3(-x, y0, z)
	var b := Vector3(x, y0, z)
	var c := Vector3(x, y0, -z)
	var e := Vector3(-x, y0, -z)
	var r1 := Vector3(-ridge, top, ridge_z)
	var r2 := Vector3(ridge, top, ridge_z)
	var r3 := Vector3(ridge, top, -ridge_z)
	var r4 := Vector3(-ridge, top, -ridge_z)
	quad(ROOF, a, b, r2, r1, colour)
	quad(ROOF, c, e, r4, r3, colour)
	quad(ROOF, b, c, r3, r2, colour)
	quad(ROOF, e, a, r1, r4, colour)
	# The underside of the eaves, in shadow.
	quad(TRIM, e, c, b, a, Color("3a342c"))

## A gabled roof: ridge along x; gable ends in the wall material.
func gable_roof(w: float, d: float, y0: float, rise: float, colour: Color, wall_kind: int, wall_colour: Color, over := 0.4) -> void:
	var x := w * 0.5 + over
	var z := d * 0.5 + over
	var top := y0 + rise
	quad(ROOF, Vector3(-x, y0, z), Vector3(x, y0, z), Vector3(x, top, 0), Vector3(-x, top, 0), colour)
	quad(ROOF, Vector3(x, y0, -z), Vector3(-x, y0, -z), Vector3(-x, top, 0), Vector3(x, top, 0), colour)
	quad(TRIM, Vector3(-x, y0, -z), Vector3(x, y0, -z), Vector3(x, y0, z), Vector3(-x, y0, z), Color("3a342c"))
	for side in [-1.0, 1.0]:
		var gx: float = side * w * 0.5
		if side > 0:
			tri(wall_kind, Vector3(gx, y0, d * 0.5), Vector3(gx, y0, -d * 0.5), Vector3(gx, top - over * rise / z, 0), wall_colour)
		else:
			tri(wall_kind, Vector3(gx, y0, -d * 0.5), Vector3(gx, y0, d * 0.5), Vector3(gx, top - over * rise / z, 0), wall_colour)
	box(TRIM, Vector3(-x, top - 0.08, -0.12), Vector3(x, top + 0.12, 0.12), colour.darkened(0.25))  # ridge tiles

func chimney(x: float, z: float, y0: float, h: float) -> void:
	box(BRICK, Vector3(x - 0.35, y0, z - 0.3), Vector3(x + 0.35, y0 + h, z + 0.3), Color("a8604a"))
	box(TRIM, Vector3(x - 0.42, y0 + h, z - 0.37), Vector3(x + 0.42, y0 + h + 0.15, z + 0.37), Color("6a5a4c"))

## A banner in the nation's colour hanging on the +z face at (x, y).
func banner(x: float, y: float, z: float, h := 3.0) -> void:
	box(TRIM, Vector3(x - 0.55, y, z), Vector3(x + 0.55, y + 0.08, z + 0.25), Color("c9a24a"))
	quad(BANNER, Vector3(x - 0.45, y - h, z + 0.2), Vector3(x + 0.45, y - h, z + 0.2), Vector3(x + 0.45, y, z + 0.2), Vector3(x - 0.45, y, z + 0.2), banner_colour)
	tri(BANNER, Vector3(x - 0.45, y - h, z + 0.2), Vector3(x, y - h - 0.5, z + 0.2), Vector3(x + 0.45, y - h, z + 0.2), banner_colour)

## A classical portico on the +z face: steps, columns and a pediment.
func portico(width: float, z: float, y0: float, height: float, columns: int, stone: Color) -> void:
	var depth := 2.2
	for s in range(3):
		box(STONE, Vector3(-width * 0.5 - 0.3 * (3 - s), y0 + s * 0.18 - 0.2, z - 0.1), Vector3(width * 0.5 + 0.3 * (3 - s), y0 + (s + 1) * 0.18 - 0.2, z + depth + 0.35 * (3 - s)), stone.darkened(0.08))
	for i in range(columns):
		var cx := -width * 0.5 + width * (i + 0.5) / columns
		cylinder(STONE, Vector3(cx, y0 + 0.34, z + depth - 0.35), 0.28, height - 0.8, stone, 10)
		box(STONE, Vector3(cx - 0.38, y0 + 0.34 + height - 0.8, z + depth - 0.73), Vector3(cx + 0.38, y0 + height - 0.25, z + depth + 0.03), stone)
	box(STONE, Vector3(-width * 0.5 - 0.2, y0 + height - 0.25, z - 0.1), Vector3(width * 0.5 + 0.2, y0 + height + 0.35, z + depth + 0.2), stone.lightened(0.05))
	var py := y0 + height + 0.35
	var peak := py + width * 0.22
	tri(STONE, Vector3(-width * 0.5 - 0.2, py, z + depth + 0.2), Vector3(width * 0.5 + 0.2, py, z + depth + 0.2), Vector3(0, peak, z + depth + 0.2), stone.lightened(0.08))
	quad(ROOF, Vector3(-width * 0.5 - 0.35, py, z + depth + 0.3), Vector3(0, peak + 0.1, z + depth + 0.3), Vector3(0, peak + 0.1, z - 0.1), Vector3(-width * 0.5 - 0.35, py, z - 0.1), Color("6e7a78"))
	quad(ROOF, Vector3(0, peak + 0.1, z + depth + 0.3), Vector3(width * 0.5 + 0.35, py, z + depth + 0.3), Vector3(width * 0.5 + 0.35, py, z - 0.1), Vector3(0, peak + 0.1, z - 0.1), Color("6e7a78"))

# ---------------------------------------------------------------- buildings

## A townhouse, w wide and d deep, of `floors` storeys, front to +z.
func townhouse(rng: RandomNumberGenerator, w: float, d: float, floors: int) -> void:
	var palette := [Color("e8dcc2"), Color("d9b88a"), Color("e2c7b4"), Color("c9cfb4"), Color("efe6d4"), Color("d6a888")]
	var brick := rng.randf() < 0.3
	var wall_kind := BRICK if brick else PLASTER
	var wall: Color = Color("b8674c").lerp(Color("9c5a44"), rng.randf()) if brick else palette[rng.randi() % palette.size()]
	var storey := 2.9
	var h := floors * storey
	box(STONE, Vector3(-w * 0.5 - 0.1, -0.3, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, 0.35, d * 0.5 + 0.1), Color("a89f8e"))
	walls(wall_kind, w, d, 0.35, h, wall)
	var shutters: Color = [Color("4a6a5a"), Color("5a4a3a"), Color("3f5a7a"), Color("7a3a32"), Color(0, 0, 0, 0)][rng.randi() % 5]
	fenestrate(w, d, 0.35, floors, storey, Color("ece6d8"), shutters, rng)
	door(0.0, 0.35, d * 0.5, [Color("5a3a28"), Color("2f4a3a"), Color("6a2a2a")][rng.randi() % 3], Color("5a4a3a"))
	cornice(w, d, 0.35 + h, Color("e6dfd0"), 0.18, 0.22)
	var roof: Color = [Color("b0553a"), Color("9a4a34"), Color("5a6068"), Color("a86040")][rng.randi() % 4]
	if rng.randf() < 0.6:
		hip_roof(w, d, 0.57 + h, minf(w, d) * 0.42, roof)
	else:
		gable_roof(w, d, 0.57 + h, minf(w, d) * 0.5, roof, wall_kind, wall)
	chimney(w * 0.3 * (1.0 if rng.randf() < 0.5 else -1.0), -d * 0.2, 0.57 + h, minf(w, d) * 0.5 + 0.6)

## A cottage: one storey and a steep gabled roof, timber framed or brick.
func cottage(rng: RandomNumberGenerator, w: float, d: float) -> void:
	var framed := rng.randf() < 0.5
	var wall: Color = Color("efe4cc") if framed else Color("b8674c")
	var kind := PLASTER if framed else BRICK
	box(STONE, Vector3(-w * 0.5 - 0.1, -0.3, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, 0.3, d * 0.5 + 0.1), Color("9c9484"))
	walls(kind, w, d, 0.3, 2.8, wall)
	if framed:
		# Dark timber framing on the plaster.
		for side in [-1.0, 1.0]:
			for x in [-w * 0.5, -w * 0.17, w * 0.17, w * 0.5]:
				box(WOOD, Vector3(x - 0.08, 0.3, side * d * 0.5 - 0.04), Vector3(x + 0.08, 3.1, side * d * 0.5 + 0.04), Color("4a3526"))
			box(WOOD, Vector3(-w * 0.5, 1.55, side * d * 0.5 - 0.04), Vector3(w * 0.5, 1.7, side * d * 0.5 + 0.04), Color("4a3526"))
	fenestrate(w, d, 0.3, 1, 2.8, Color("e8e0cc"), Color("3f5a4a") if framed else Color(0, 0, 0, 0), rng)
	door(0.0, 0.3, d * 0.5, Color("4a3020"), Color("5a4a3a"))
	gable_roof(w, d, 3.1, d * 0.65, Color("8a4a34") if not framed else Color("6a5a3a"), kind, wall)
	chimney(-w * 0.3, 0.0, 3.1, d * 0.6 + 0.8)

## A stone civic building w x d with `floors` storeys; the recipe adds the rest.
func civic_block(w: float, d: float, floors: int, stone: Color, rng: RandomNumberGenerator) -> float:
	var storey := 3.6
	var h := floors * storey
	box(STONE, Vector3(-w * 0.5 - 0.3, -0.4, -d * 0.5 - 0.3), Vector3(w * 0.5 + 0.3, 0.5, d * 0.5 + 0.3), stone.darkened(0.15))
	walls(STONE, w, d, 0.5, h, stone)
	for f in range(1, floors):
		box(TRIM, Vector3(-w * 0.5 - 0.08, 0.5 + f * storey - 0.1, -d * 0.5 - 0.08), Vector3(w * 0.5 + 0.08, 0.5 + f * storey + 0.08, d * 0.5 + 0.08), stone.lightened(0.08))
	fenestrate(w, d, 0.5, floors, storey, stone.lightened(0.12), Color(0, 0, 0, 0), rng)
	cornice(w, d, 0.5 + h, stone.lightened(0.1), 0.35, 0.5)
	return 0.5 + h + 0.5

## Civic recipes: what stands on a city's special hexes.
func civic(key: String, rng: RandomNumberGenerator, footprint: float) -> void:
	# Warm honey limestone, as the civic quarters of a 4X city are built.
	var stone := Color("f0d9ae")
	var s := footprint / 10.0
	match key:
		"hq", "cityCenter", "cityHall":
			# The seat of government: a wide stone hall, portico, dome and flag.
			var w := 8.6 * s
			var d := 6.4 * s
			var top := civic_block(w, d, 3 if key != "cityHall" else 2, stone, rng)
			portico(w * 0.62, d * 0.5, 0.5, 6.2 * s, 6, stone.lightened(0.05))
			box(STONE, Vector3(-w * 0.5, top, -d * 0.5), Vector3(w * 0.5, top + 0.1, d * 0.5), stone.darkened(0.1))
			cylinder(STONE, Vector3(0, top, 0), 2.1 * s, 1.8 * s, stone.lightened(0.05), 16)
			dome(ROOF, Vector3(0, top + 1.8 * s, 0), 2.3 * s, 2.4 * s, Color("5e8a7a"), 18, 6)
			cylinder(TRIM, Vector3(0, top + 1.8 * s + 2.4 * s, 0), 0.3, 1.2, Color("c9a24a"), 8)
			banner(-w * 0.42, 0.5 + 3.6 * 2.4, d * 0.5, 3.4)
			banner(w * 0.42, 0.5 + 3.6 * 2.4, d * 0.5, 3.4)
		"courthouse", "bank":
			var w := 7.2 * s
			var d := 6.0 * s
			var top := civic_block(w, d, 2, Color("f2e2c2"), rng)
			portico(w * 0.8, d * 0.5, 0.5, 5.8 * s, 6 if key == "bank" else 4, Color("f6ead2"))
			hip_roof(w, d, top, 1.4 * s, Color("5a6068"), 0.2)
			banner(-w * 0.5 + 0.6, 0.5 + 6.0, d * 0.5 + 0.05, 2.6)
		"university", "library":
			var w := 8.0 * s
			var d := 6.2 * s
			var brick_red := Color("b0624a")
			box(STONE, Vector3(-w * 0.5 - 0.3, -0.4, -d * 0.5 - 0.3), Vector3(w * 0.5 + 0.3, 0.5, d * 0.5 + 0.3), Color("9c9484"))
			walls(BRICK, w, d, 0.5, 7.0, brick_red)
			fenestrate(w, d, 0.5, 2, 3.5, Color("e8e2d2"), Color(0, 0, 0, 0), rng)
			cornice(w, d, 7.5, Color("e2dac8"), 0.3, 0.4)
			portico(w * 0.45, d * 0.5, 0.5, 5.0 * s, 4, Color("e6dfcf"))
			if key == "library":
				cylinder(STONE, Vector3(0, 7.9, 0), 1.8 * s, 1.2, Color("e2dac8"), 16)
				dome(ROOF, Vector3(0, 9.1, 0), 2.0 * s, 1.9 * s, Color("6a7e8a"), 16, 5)
			else:
				hip_roof(w, d, 7.9, 1.8 * s, Color("5a6068"), 0.25)
				box(STONE, Vector3(-0.9, 9.0, -0.9), Vector3(0.9, 12.5, 0.9), Color("e2dac8"))
				box(TRIM, Vector3(-0.95, 11.2, 0.9), Vector3(0.95, 12.2, 0.95), Color("f2ead6"))  # clock face
				cylinder(ROOF, Vector3(0, 12.5, 0), 1.3, 2.4, Color("4e6a62"), 4, 0.0)
		"school", "policeStation", "hospital":
			var w := 7.6 * s
			var d := 6.0 * s
			var wall := Color("b8674c") if key != "hospital" else Color("eceae2")
			var kind := BRICK if key != "hospital" else PLASTER
			box(STONE, Vector3(-w * 0.5 - 0.2, -0.4, -d * 0.5 - 0.2), Vector3(w * 0.5 + 0.2, 0.4, d * 0.5 + 0.2), Color("9c9484"))
			walls(kind, w, d, 0.4, 6.4, wall)
			fenestrate(w, d, 0.4, 2, 3.2, Color("ece6d8"), Color(0, 0, 0, 0), rng)
			door(0.0, 0.4, d * 0.5, Color("3a4a5a"), Color("5a6068"))
			cornice(w, d, 6.8, Color("e2dac8"), 0.2, 0.3)
			if key == "hospital":
				box(TRIM, Vector3(-0.8, 5.0, d * 0.5 + 0.02), Vector3(0.8, 5.3, d * 0.5 + 0.08), Color("c8322b"))
				box(TRIM, Vector3(-0.15, 4.35, d * 0.5 + 0.02), Vector3(0.15, 5.95, d * 0.5 + 0.08), Color("c8322b"))
				box(TRIM, Vector3(-w * 0.5, 7.1, -d * 0.5), Vector3(w * 0.5, 7.5, d * 0.5), Color("d8d6ce"))
			else:
				hip_roof(w, d, 7.1, 2.0 * s, Color("5a6068"))
				if key == "school":
					# A bell cupola.
					box(WOOD, Vector3(-0.6, 9.0, -0.6), Vector3(0.6, 10.2, 0.6), Color("efe8d8"))
					cylinder(ROOF, Vector3(0, 10.2, 0), 0.95, 1.4, Color("4e6a62"), 4, 0.0)
		"market":
			# An open market hall: a tiled roof on stone piers.
			var w := 8.0 * s
			var d := 6.0 * s
			box(STONE, Vector3(-w * 0.5 - 0.3, -0.4, -d * 0.5 - 0.3), Vector3(w * 0.5 + 0.3, 0.3, d * 0.5 + 0.3), Color("a89f8e"))
			for i in range(5):
				for side in [-1.0, 1.0]:
					var x := -w * 0.5 + w * i / 4.0
					box(STONE, Vector3(x - 0.3, 0.3, side * d * 0.5 - 0.3), Vector3(x + 0.3, 4.0, side * d * 0.5 + 0.3), stone)
			box(WOOD, Vector3(-w * 0.5 - 0.3, 4.0, -d * 0.5 - 0.3), Vector3(w * 0.5 + 0.3, 4.4, d * 0.5 + 0.3), Color("5a4232"))
			hip_roof(w, d, 4.4, 2.6 * s, Color("b0553a"), 0.6)
		"villageCenter":
			# A timber-framed hall with a bell turret.
			var w := 7.0 * s
			var d := 5.2 * s
			box(STONE, Vector3(-w * 0.5 - 0.2, -0.4, -d * 0.5 - 0.2), Vector3(w * 0.5 + 0.2, 0.4, d * 0.5 + 0.2), Color("9c9484"))
			walls(PLASTER, w, d, 0.4, 5.6, Color("efe4cc"))
			for side in [-1.0, 1.0]:
				for i in range(6):
					var x := -w * 0.5 + w * i / 5.0
					box(WOOD, Vector3(x - 0.1, 0.4, side * d * 0.5 - 0.05), Vector3(x + 0.1, 6.0, side * d * 0.5 + 0.05), Color("4a3526"))
				box(WOOD, Vector3(-w * 0.5, 3.0, side * d * 0.5 - 0.05), Vector3(w * 0.5, 3.2, side * d * 0.5 + 0.05), Color("4a3526"))
			fenestrate(w, d, 0.4, 2, 2.8, Color("e8e0cc"), Color("3f5a4a"), rng)
			door(0.0, 0.4, d * 0.5, Color("4a3020"), Color("6a5a3a"))
			gable_roof(w, d, 6.0, d * 0.62, Color("6a5a3a"), PLASTER, Color("efe4cc"))
			box(WOOD, Vector3(-0.7, 8.6, -0.7), Vector3(0.7, 10.0, 0.7), Color("5a4232"))
			cylinder(ROOF, Vector3(0, 10.0, 0), 1.1, 1.8, Color("6a5a3a"), 4, 0.0)
			banner(w * 0.5 - 0.7, 5.0, d * 0.5 + 0.05, 2.4)
		"barracks", "policeHQ":
			# A fortified barracks: brick and stone, a crenellated parapet, an arched gate.
			var w := 8.4 * s
			var d := 6.0 * s
			box(STONE, Vector3(-w * 0.5 - 0.3, -0.4, -d * 0.5 - 0.3), Vector3(w * 0.5 + 0.3, 1.4, d * 0.5 + 0.3), Color("b8a888"))
			walls(BRICK, w, d, 1.4, 5.0, Color("9a5a44"))
			fenestrate(w, d, 1.4, 2, 2.5, Color("d8d0bc"), Color(0, 0, 0, 0), rng)
			box(WOOD, Vector3(-1.2, 0.0, d * 0.5 + 0.3), Vector3(1.2, 3.2, d * 0.5 + 0.4), Color("3a3028"))
			box(STONE, Vector3(-1.6, 3.2, d * 0.5 + 0.3), Vector3(1.6, 3.8, d * 0.5 + 0.5), Color("c8b898"))
			var top := 6.4
			box(STONE, Vector3(-w * 0.5 - 0.15, top, -d * 0.5 - 0.15), Vector3(w * 0.5 + 0.15, top + 0.5, d * 0.5 + 0.15), Color("c8b898"))
			for i in range(9):
				var x := -w * 0.5 + w * i / 8.0
				for side in [-1.0, 1.0]:
					box(STONE, Vector3(x - 0.3, top + 0.5, side * d * 0.5 - 0.25), Vector3(x + 0.3, top + 1.2, side * d * 0.5 + 0.15), Color("c8b898"))
			box(TRIM, Vector3(-w * 0.5, top + 0.45, -d * 0.5), Vector3(w * 0.5, top + 0.52, d * 0.5), Color("5a5650"))
			banner(-2.2, 5.8, d * 0.5 + 0.05, 2.8)
			banner(2.2, 5.8, d * 0.5 + 0.05, 2.8)
		_:
			# Anything else civic: a two-storey stone block with a hipped roof.
			var w := 7.0 * s
			var d := 5.6 * s
			var top := civic_block(w, d, 2, stone, rng)
			door(0.0, 0.5, d * 0.5, Color("3a3a3a"), Color("5a6068"))
			hip_roof(w, d, top, 1.6 * s, Color("5a6068"))
			banner(0.0, 6.5, d * 0.5, 2.4)

## A gambrel (barn) roof along x over w x d at y0: two pitches each side.
func gambrel_roof(w: float, d: float, y0: float, rise: float, colour: Color, wall_kind: int, wall_colour: Color, over := 0.35) -> void:
	var x := w * 0.5 + over
	var z := d * 0.5 + over
	var knee_z := d * 0.3
	var knee_y := y0 + rise * 0.62
	var top := y0 + rise
	# Lower steep pitch, then the shallow upper one, each side.
	quad(ROOF, Vector3(-x, y0, z), Vector3(x, y0, z), Vector3(x, knee_y, knee_z), Vector3(-x, knee_y, knee_z), colour)
	quad(ROOF, Vector3(-x, knee_y, knee_z), Vector3(x, knee_y, knee_z), Vector3(x, top, 0), Vector3(-x, top, 0), colour)
	quad(ROOF, Vector3(x, y0, -z), Vector3(-x, y0, -z), Vector3(-x, knee_y, -knee_z), Vector3(x, knee_y, -knee_z), colour)
	quad(ROOF, Vector3(x, knee_y, -knee_z), Vector3(-x, knee_y, -knee_z), Vector3(-x, top, 0), Vector3(x, top, 0), colour)
	quad(TRIM, Vector3(-x, y0, -z), Vector3(x, y0, -z), Vector3(x, y0, z), Vector3(-x, y0, z), Color("3a342c"))
	# The gable ends: a pentagon in the wall material, as three triangles each.
	for side in [-1.0, 1.0]:
		var gx: float = side * w * 0.5
		var a := Vector3(gx, y0, d * 0.5)
		var b := Vector3(gx, y0, -d * 0.5)
		var k1 := Vector3(gx, knee_y, knee_z)
		var k2 := Vector3(gx, knee_y, -knee_z)
		var t := Vector3(gx, top, 0)
		if side > 0:
			tri(wall_kind, a, b, k2, wall_colour)
			tri(wall_kind, a, k2, k1, wall_colour)
			tri(wall_kind, k1, k2, t, wall_colour)
		else:
			tri(wall_kind, b, a, k1, wall_colour)
			tri(wall_kind, b, k1, k2, wall_colour)
			tri(wall_kind, k2, k1, t, wall_colour)

## A corrugated silo at `c`, radius r, height h, with a domed or conical cap.
func silo(c: Vector3, r: float, h: float, conical := false) -> void:
	cylinder(STONE, c + Vector3(0, -0.3, 0), r + 0.25, 0.6, Color("a8a090"), 16)
	cylinder(METAL, c + Vector3(0, 0.3, 0), r, h, Color("b4b7b2"), 18)
	for band in [0.33, 0.66]:
		cylinder(TRIM, c + Vector3(0, 0.3 + h * band, 0), r + 0.05, 0.12, Color("9a9c98"), 18)
	if conical:
		cylinder(METAL, c + Vector3(0, 0.3 + h, 0), r + 0.1, r * 0.7, Color("b8bab6"), 18, 0.25)
	else:
		dome(METAL, c + Vector3(0, 0.3 + h, 0), r, r * 0.6, Color("c8cac6"), 18, 4)

## A farmstead: a red barn with a gambrel roof, a farmhouse with a porch, a silo.
func farm(rng: RandomNumberGenerator, footprint: float) -> void:
	var s := footprint / 7.5
	var w := 7.0 * s
	var d := 5.2 * s
	var red := Color("a8432f").lerp(Color("8f3a2a"), rng.randf())
	box(STONE, Vector3(-w * 0.5 - 0.1, -0.3, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, 0.5, d * 0.5 + 0.1), Color("8c8478"))
	walls(PLANK, w, d, 0.5, 3.6, red)
	# White corner boards.
	for x in [-w * 0.5, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			box(TRIM, Vector3(x - 0.12, 0.5, z - 0.12), Vector3(x + 0.12, 4.1, z + 0.12), Color("efe9dc"))
	# Big doors on both long sides, cross-braced, and a hay-loft door above.
	for side in [-1.0, 1.0]:
		var saved := xf
		if side < 0:
			xf = xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		box(PLANK, Vector3(-1.4, 0.5, d * 0.5), Vector3(1.4, 3.3, d * 0.5 + 0.08), red.darkened(0.15))
		box(TRIM, Vector3(-1.5, 3.3, d * 0.5), Vector3(1.5, 3.45, d * 0.5 + 0.12), Color("efe9dc"))
		box(TRIM, Vector3(-0.08, 0.5, d * 0.5 + 0.05), Vector3(0.08, 3.3, d * 0.5 + 0.12), Color("efe9dc"))
		for dx in [-0.7, 0.7]:
			box(TRIM, Vector3(dx - 0.62, 1.8, d * 0.5 + 0.06), Vector3(dx + 0.62, 1.95, d * 0.5 + 0.12), Color("efe9dc"))
		box(PLANK, Vector3(-0.6, 4.3, d * 0.5 - 0.05), Vector3(0.6, 5.3, d * 0.5 + 0.08), red.darkened(0.2))
		xf = saved
	gambrel_roof(w, d, 4.1, d * 0.62, Color("5a5f64"), PLANK, red)
	# A cupola on the ridge.
	var ridge := 4.1 + d * 0.62
	box(PLANK, Vector3(-0.5, ridge - 0.1, -0.5), Vector3(0.5, ridge + 0.8, 0.5), Color("efe9dc"))
	cylinder(ROOF, Vector3(0, ridge + 0.8, 0), 0.8, 0.9, Color("5a5f64"), 4, 0.0)
	# The farmhouse, set to one side, with a porch.
	var saved2 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-w * 0.5 - 3.4, 0, 0.6))
	cottage(rng, 4.2, 3.6)
	box(WOOD, Vector3(-1.8, 0.3, 1.8), Vector3(1.8, 0.45, 3.0), Color("7a5a3e"))
	for px in [-1.6, 1.6]:
		box(WOOD, Vector3(px - 0.07, 0.45, 2.85), Vector3(px + 0.07, 2.6, 2.95), Color("efe9dc"))
	box(ROOF, Vector3(-1.9, 2.6, 1.8), Vector3(1.9, 2.7, 3.1), Color("6a5a3a"))
	xf = saved2
	silo(Vector3(w * 0.5 + 1.8, 0, -d * 0.3), 1.3, 7.5)

## A granary: tall corrugated silos, the lift tower and gallery that feed them,
## and a warehouse shed with a loading dock.
func granary(rng: RandomNumberGenerator, footprint: float) -> void:
	var s := footprint / 9.5
	for i in range(4):
		silo(Vector3((i - 1.5) * 2.7 * s, 0, -1.6 * s), 1.25 * s, 8.5 * s, true)
	var tx := 2.5 * 2.7 * s
	box(METAL, Vector3(tx - 1.0, 0.0, -2.6 * s), Vector3(tx + 1.0, 12.0 * s, -0.6 * s), Color("c4c6c2"))
	box(ROOF, Vector3(tx - 1.2, 12.0 * s, -2.8 * s), Vector3(tx + 1.2, 12.3 * s, -0.4 * s), Color("7a3a2e"))
	box(METAL, Vector3(-1.5 * 2.7 * s, 9.6 * s, -2.1 * s), Vector3(tx, 10.6 * s, -1.1 * s), Color("b8bab6"))
	var w := 8.0 * s
	var d := 3.6 * s
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(0, 0, 2.6 * s))
	box(STONE, Vector3(-w * 0.5, -0.3, -d * 0.5), Vector3(w * 0.5, 0.9, d * 0.5 + 1.2), Color("9c9484"))
	walls(METAL, w, d, 0.9, 3.2, Color("a8b0a8"))
	for i in range(3):
		var x := -w * 0.33 + w * 0.33 * i
		box(WOOD, Vector3(x - 0.9, 0.9, d * 0.5), Vector3(x + 0.9, 3.3, d * 0.5 + 0.06), Color("6a7470"))
	gable_roof(w, d, 4.1, d * 0.35, Color("7a3a2e"), METAL, Color("a8b0a8"), 0.5)
	xf = saved

## A coal-fired power station: a brick turbine hall with tall arched windows
## and a clerestory, two banded stacks, a coal heap and a transformer yard.
func power_station(rng: RandomNumberGenerator, footprint: float) -> void:
	var s := footprint / 9.5
	var w := 8.4 * s
	var d := 5.4 * s
	var h := 8.0 * s
	var brick := Color("9c4e3a")
	box(STONE, Vector3(-w * 0.5 - 0.2, -0.4, -d * 0.5 - 0.2), Vector3(w * 0.5 + 0.2, 0.6, d * 0.5 + 0.2), Color("8c877e"))
	walls(BRICK, w, d, 0.6, h, brick)
	# Tall round-headed windows between brick pilasters, on both long sides.
	var n := 5
	for side in [-1.0, 1.0]:
		var saved := xf
		if side < 0:
			xf = xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		for i in range(n):
			var x := -w * 0.5 + w * (i + 0.5) / n
			window(Vector3(x, 0.6 + h * 0.5, d * 0.5), 1.0 * s, h * 0.62, Color("d8d0bc"))
			dome(STONE, Vector3(x, 0.6 + h * 0.81, d * 0.5 + 0.01), 0.55 * s, 0.35 * s, Color("d8d0bc"), 8, 2)
			if i > 0:
				var px := -w * 0.5 + w * i / n
				box(BRICK, Vector3(px - 0.18, 0.6, d * 0.5), Vector3(px + 0.18, 0.6 + h, d * 0.5 + 0.2), brick.darkened(0.1))
		xf = saved
	cornice(w, d, 0.6 + h, Color("c8b898"), 0.25, 0.4)
	gable_roof(w, d, 1.0 + h, d * 0.3, Color("5a5f64"), BRICK, brick, 0.3)
	# A glazed lantern along the ridge.
	var ridge := 1.0 + h + d * 0.3
	box(GLASS, Vector3(-w * 0.35, ridge - 0.2, -0.5), Vector3(w * 0.35, ridge + 0.7, 0.5), Color("8a9aa4"))
	box(ROOF, Vector3(-w * 0.37, ridge + 0.7, -0.7), Vector3(w * 0.37, ridge + 0.85, 0.7), Color("5a5f64"))
	# Two tall stacks with dark bands and red-and-white tops.
	for i in range(2):
		var c := Vector3((i - 0.5) * 3.0 * s, 0.6, -d * 0.5 - 2.2 * s)
		cylinder(BRICK, c, 0.95 * s, 17.0 * s, Color("a85a44"), 14, 0.7 * s)
		for band in [0.3, 0.6]:
			cylinder(TRIM, c + Vector3(0, 17.0 * s * band, 0), 0.95 * s * (1.0 - band * 0.27) + 0.06, 0.25, Color("3a3230"), 14)
		cylinder(TRIM, c + Vector3(0, 15.0 * s, 0), 0.76 * s, 1.0 * s, Color("e8e4dc"), 14)
		cylinder(TRIM, c + Vector3(0, 16.0 * s, 0), 0.73 * s, 1.0 * s, Color("b83a2e"), 14, 0.7 * s)
	# A heap of coal and the transformer yard with a lattice pylon.
	cylinder(TRIM, Vector3(-w * 0.5 - 1.8 * s, 0.0, d * 0.2), 2.0 * s, 1.6 * s, Color("26272a"), 12, 0.3)
	var yard := Vector3(w * 0.5 + 1.6 * s, 0.0, 0.8 * s)
	for i in range(3):
		box(METAL, yard + Vector3(-0.5, 0.0, (i - 1) * 1.4 - 0.4), yard + Vector3(0.5, 1.4, (i - 1) * 1.4 + 0.4), Color("6a7470"))
	for leg in [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)]:
		var foot: Vector3 = yard + Vector3(0, 0, -3.2 * s) + leg
		box(TRIM, foot + Vector3(-0.07, 0, -0.07), foot + Vector3(0.07, 9.0 * s, 0.07), Color("8a8c88"))
	box(TRIM, yard + Vector3(-1.8, 7.5 * s, -3.2 * s - 0.08), yard + Vector3(1.8, 7.5 * s + 0.15, -3.2 * s + 0.08), Color("8a8c88"))

## A military airfield on its hex: a runway along z with threshold bars,
## centre-line dashes and edge lights, a taxiway to an apron of numbered
## parking slots (air_operations.gd uses the same positions), an arched
## hangar, a control tower with a glazed cab, fuel tanks and a windsock.
## Coordinates are the hex's own (the district's container is not rotated).
func airfield(rng: RandomNumberGenerator) -> void:
	const AO := preload("res://scripts/air_operations.gd")
	var rx: float = AO.RUNWAY_X
	var asphalt := Color("3a3d40")
	var paint := Color("e8e6dc")
	# Runway: 3.6 m wide, corner to corner of the hex.
	quad(TRIM, Vector3(rx - 1.8, 0.12, 11.0), Vector3(rx + 1.8, 0.12, 11.0), Vector3(rx + 1.8, 0.12, -11.0), Vector3(rx - 1.8, 0.12, -11.0), asphalt)
	for z in range(-9, 10, 3):
		quad(TRIM, Vector3(rx - 0.07, 0.14, z + 1.0), Vector3(rx + 0.07, 0.14, z + 1.0), Vector3(rx + 0.07, 0.14, z), Vector3(rx - 0.07, 0.14, z), paint)
	for end in [-10.4, 10.4]:
		for k in range(4):
			var x := rx - 1.4 + k * 0.75 + 0.1
			quad(TRIM, Vector3(x, 0.14, end + 0.5), Vector3(x + 0.35, 0.14, end + 0.5), Vector3(x + 0.35, 0.14, end - 0.5), Vector3(x, 0.14, end - 0.5), paint)
	for z in range(-10, 11, 4):
		for side in [-1.0, 1.0]:
			box(TRIM, Vector3(rx + side * 1.95 - 0.08, 0.1, z - 0.08), Vector3(rx + side * 1.95 + 0.08, 0.35, z + 0.08), Color("f2d060"))
	# Taxiway from the runway to the apron, and the apron itself.
	quad(TRIM, Vector3(rx + 1.8, 0.11, 1.2), Vector3(3.2, 0.11, 1.2), Vector3(3.2, 0.11, -1.2), Vector3(rx + 1.8, 0.11, -1.2), Color("45484a"))
	quad(TRIM, Vector3(3.2, 0.11, 8.4), Vector3(8.0, 0.11, 8.4), Vector3(8.0, 0.11, -8.4), Vector3(3.2, 0.11, -8.4), Color("54575a"))
	for i in range(AO.SLOT_POSITIONS.airfield.size()):
		var sp: Vector3 = AO.SLOT_POSITIONS.airfield[i]
		# A painted parking box with a yellow lead-in line.
		for side in [-1.0, 1.0]:
			quad(TRIM, Vector3(sp.x - 1.6, 0.13, sp.z + side * 1.9 + 0.05), Vector3(sp.x + 2.4, 0.13, sp.z + side * 1.9 + 0.05), Vector3(sp.x + 2.4, 0.13, sp.z + side * 1.9 - 0.05), Vector3(sp.x - 1.6, 0.13, sp.z + side * 1.9 - 0.05), Color("f2d060"))
		quad(TRIM, Vector3(3.2, 0.13, sp.z + 0.05), Vector3(sp.x + 1.6, 0.13, sp.z + 0.05), Vector3(sp.x + 1.6, 0.13, sp.z - 0.05), Vector3(3.2, 0.13, sp.z - 0.05), Color("f2d060"))
		# The slot number, as bars (1 to 4).
		for k in range(i + 1):
			quad(TRIM, Vector3(sp.x + 1.9, 0.14, sp.z - 0.6 + k * 0.35 + 0.12), Vector3(sp.x + 2.2, 0.14, sp.z - 0.6 + k * 0.35 + 0.12), Vector3(sp.x + 2.2, 0.14, sp.z - 0.6 + k * 0.35), Vector3(sp.x + 1.9, 0.14, sp.z - 0.6 + k * 0.35), paint)
	# An arched hangar west of the runway, doors open toward it.
	var hx := rx - 5.0
	var hz := -4.0
	for i in range(10):
		var a0 := PI * i / 10.0
		var a1 := PI * (i + 1) / 10.0
		var p0 := Vector3(hx + cos(a0) * 2.4, sin(a0) * 2.6, 0)
		var p1 := Vector3(hx + cos(a1) * 2.4, sin(a1) * 2.6, 0)
		quad(METAL, Vector3(p1.x, p1.y, hz - 3.0), Vector3(p0.x, p0.y, hz - 3.0), Vector3(p0.x, p0.y, hz + 3.0), Vector3(p1.x, p1.y, hz + 3.0), Color("8a948a"))
	for i in range(10):
		var a0 := PI * i / 10.0
		var a1 := PI * (i + 1) / 10.0
		tri(METAL, Vector3(hx, 0, hz - 3.0), Vector3(hx + cos(a0) * 2.4, sin(a0) * 2.6, hz - 3.0), Vector3(hx + cos(a1) * 2.4, sin(a1) * 2.6, hz - 3.0), Color("7a847a"))
	quad(GLASS, Vector3(hx - 2.2, 0.1, hz + 3.01), Vector3(hx + 2.2, 0.1, hz + 3.01), Vector3(hx + 2.2, 2.2, hz + 3.01), Vector3(hx - 2.2, 2.2, hz + 3.01), Color("1c2026"))
	# Control tower.
	var tx := rx - 5.0
	var tz := 5.5
	box(STONE, Vector3(tx - 1.0, 0.0, tz - 1.0), Vector3(tx + 1.0, 5.2, tz + 1.0), Color("d8d2c2"))
	fenestrate(2.0, 2.0, 0.0, 1, 4.0, Color("e8e2d4"), Color(0, 0, 0, 0), rng, false)
	box(TRIM, Vector3(tx - 1.5, 5.2, tz - 1.5), Vector3(tx + 1.5, 5.35, tz + 1.5), Color("c8c2b2"))
	box(GLASS, Vector3(tx - 1.3, 5.35, tz - 1.3), Vector3(tx + 1.3, 6.6, tz + 1.3), Color("5a7888"))
	box(ROOF, Vector3(tx - 1.6, 6.6, tz - 1.6), Vector3(tx + 1.6, 6.8, tz + 1.6), Color("5a5f64"))
	box(TRIM, Vector3(tx - 0.04, 6.8, tz - 0.04), Vector3(tx + 0.04, 8.4, tz + 0.04), Color("a8aaa6"))
	box(TRIM, Vector3(tx - 0.12, 8.4, tz - 0.12), Vector3(tx + 0.12, 8.6, tz + 0.12), Color("d84030"))
	# Fuel tanks and the windsock.
	for i in range(2):
		cylinder(METAL, Vector3(7.2, 0.0, -9.3 + i * 0.0 + (i * 2.0)), 0.8, 1.6, Color("d8dcd6"), 12)
	box(TRIM, Vector3(0.6 - 0.04, 0.0, 9.5 - 0.04), Vector3(0.6 + 0.04, 3.0, 9.5 + 0.04), Color("d8d8d0"))
	cylinder(BANNER, Vector3(0.6, 2.9, 9.5), 0.2, 0.25, Color("f08030"), 8, 0.12)
	quad(BANNER, Vector3(0.6, 2.95, 9.35), Vector3(1.8, 2.8, 9.42), Vector3(1.8, 2.95, 9.58), Vector3(0.6, 3.1, 9.65), Color("f08030"))

## A helipad hex: two marked pads (the same positions air_operations.gd uses) and a small hangar.
func helipad(rng: RandomNumberGenerator) -> void:
	const AO := preload("res://scripts/air_operations.gd")
	for sp in AO.SLOT_POSITIONS.helipad:
		cylinder(STONE, sp + Vector3(0, -0.2, 0), 2.6, 0.35, Color("5a5d60"), 24)
		cylinder(TRIM, sp + Vector3(0, 0.16, 0), 2.1, 0.02, Color("e8e6dc"), 24)
		cylinder(TRIM, sp + Vector3(0, 0.17, 0), 1.95, 0.02, Color("5a5d60"), 24)
		# The H.
		box(TRIM, sp + Vector3(-0.8, 0.18, -0.9), sp + Vector3(-0.5, 0.2, 0.9), Color("e8e6dc"))
		box(TRIM, sp + Vector3(0.5, 0.18, -0.9), sp + Vector3(0.8, 0.2, 0.9), Color("e8e6dc"))
		box(TRIM, sp + Vector3(-0.5, 0.18, -0.15), sp + Vector3(0.5, 0.2, 0.15), Color("e8e6dc"))
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(0, 0, -6.5))
	box(STONE, Vector3(-3.0, -0.2, -1.8), Vector3(3.0, 0.3, 1.8), Color("9c9484"))
	walls(METAL, 6.0, 3.6, 0.3, 3.0, Color("8a948a"))
	gable_roof(6.0, 3.6, 3.3, 1.0, Color("5a5f64"), METAL, Color("8a948a"), 0.3)
	quad(GLASS, Vector3(-2.2, 0.3, 1.81), Vector3(2.2, 0.3, 1.81), Vector3(2.2, 2.6, 1.81), Vector3(-2.2, 2.6, 1.81), Color("1c2026"))
	xf = saved


# ---------------------------------------------------------------- industry

## A steel lattice mast from `base` up `h` metres, `w` wide at the foot, `top_w` at the top.
func lattice(base: Vector3, h: float, w: float, top_w: float, colour: Color) -> void:
	var legs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for leg in legs:
		var a := base + Vector3(leg.x * w * 0.5, 0, leg.y * w * 0.5)
		var b := base + Vector3(leg.x * top_w * 0.5, h, leg.y * top_w * 0.5)
		_beam(a, b, 0.09, colour)
	var bands := int(h / 2.2)
	for k in range(1, bands + 1):
		var f := float(k) / bands
		var ww: float = lerpf(w, top_w, f) * 0.5
		var y := h * f
		for i in range(4):
			var p0: Vector2 = legs[i] * ww
			var p1: Vector2 = legs[(i + 1) % 4] * ww
			_beam(base + Vector3(p0.x, y, p0.y), base + Vector3(p1.x, y, p1.y), 0.05, colour)
			if k > 0:
				var f0 := float(k - 1) / bands
				var w0: float = lerpf(w, top_w, f0) * 0.5
				var q0: Vector2 = legs[i] * w0
				_beam(base + Vector3(q0.x, h * f0, q0.y), base + Vector3(p1.x, y, p1.y), 0.035, colour)

## A square beam from a to b.
func _beam(a: Vector3, b: Vector3, t: float, colour: Color) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var saved := xf
	xf = xf * Transform3D(Basis(x, y, z), a)
	box(TRIM, Vector3(-t, 0, -t), Vector3(t, length, t), colour)
	xf = saved

## A heap of loose material (ore, coal, sand), a low cone of `r` metres.
func heap(c: Vector3, r: float, h: float, colour: Color) -> void:
	cylinder(TRIM, c, r, h, colour, 14, r * 0.15)

## A conveyor from a to b on legs.
func conveyor(a: Vector3, b: Vector3, colour: Color) -> void:
	_beam(a, b, 0.35, colour)
	var n := int(a.distance_to(b) / 2.5)
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		_beam(Vector3(p.x, 0, p.z), p, 0.06, Color("5a5d60"))

## A mine headframe: a steel A-frame over the shaft with its winding wheels,
## the winding house beside it.
func headframe(c: Vector3, h: float, steel: Color) -> void:
	lattice(c, h, 2.6, 1.2, steel)
	for side in [-1.0, 1.0]:
		_beam(c + Vector3(side * 1.2, 0, 3.6), c + Vector3(side * 0.5, h * 0.92, 0), 0.12, steel)
	cylinder(TRIM, c + Vector3(-0.1, h + 0.2, -0.9), 0.9, 0.18, Color("3a3d40"), 16)
	cylinder(TRIM, c + Vector3(-0.1, h + 0.2, 0.7), 0.9, 0.18, Color("3a3d40"), 16)
	var saved := xf
	xf = xf * Transform3D(Basis(), c + Vector3(0, 0, 5.8))
	box(STONE, Vector3(-2.0, -0.2, -1.4), Vector3(2.0, 0.3, 1.4), Color("9c9484"))
	walls(BRICK, 4.0, 2.8, 0.3, 3.2, Color("a0583f"))
	gable_roof(4.0, 2.8, 3.5, 1.0, Color("5a5f64"), BRICK, Color("a0583f"), 0.25)
	xf = saved

## What stands on an Extractor, by the resource under it.
func extractor(rng: RandomNumberGenerator) -> void:
	match extract_type:
		"oil", "seaOil":
			# A drilling derrick, storage tanks and the separator.
			lattice(Vector3(-3.0, 0, -2.0), 11.0, 3.0, 0.8, Color("c96a2b"))
			box(TRIM, Vector3(-4.2, 0.0, -3.2), Vector3(-1.8, 0.6, -0.8), Color("5a5d60"))
			for i in range(3):
				silo(Vector3(3.6, 0, -4.5 + i * 3.2), 1.2, 2.8, false)
			cylinder(METAL, Vector3(0.2, 0.3, 4.2), 0.6, 2.6, Color("d8d4c8"), 12)
			_beam(Vector3(-2.4, 1.0, -0.8), Vector3(2.4, 1.0, -4.5), 0.12, Color("3a3d40"))
		"iron":
			headframe(Vector3(-2.5, 0, -3.0), 11.0, Color("7a3a2e"))
			heap(Vector3(3.8, 0, -3.0), 3.0, 2.4, Color("6b3b26"))
			conveyor(Vector3(0.5, 0.4, -3.0), Vector3(3.6, 2.6, -3.0), Color("5a5d60"))
			for i in range(3):
				box(METAL, Vector3(2.0 + i * 1.6, 0.0, 3.2), Vector3(3.3 + i * 1.6, 1.3, 5.0), Color("6a4a3a"))
		"gold":
			headframe(Vector3(-2.5, 0, -3.0), 10.0, Color("5a5d60"))
			# The stamp mill: a tall timber building stepping down the slope.
			var saved := xf
			xf = xf * Transform3D(Basis(), Vector3(3.6, 0, 0.5))
			box(STONE, Vector3(-2.2, -0.2, -2.8), Vector3(2.2, 0.3, 2.8), Color("9c9484"))
			walls(PLANK, 4.4, 5.6, 0.3, 5.0, Color("8a6a48"))
			gable_roof(4.4, 5.6, 5.3, 1.6, Color("5a5f64"), PLANK, Color("8a6a48"), 0.3)
			xf = saved
			heap(Vector3(0.0, 0, 5.2), 1.8, 1.0, Color("d0b060"))
		"silicon":
			# A quarry of pale sand with a crane over it and the washing plant.
			heap(Vector3(-3.0, 0, 1.0), 3.6, 1.8, Color("ded8c8"))
			heap(Vector3(-1.0, 0, -3.8), 2.4, 1.2, Color("e8e2d2"))
			lattice(Vector3(2.4, 0, -3.5), 7.0, 1.6, 0.8, Color("e0b030"))
			_beam(Vector3(2.4, 7.0, -3.5), Vector3(-3.0, 6.0, 0.5), 0.14, Color("e0b030"))
			var saved2 := xf
			xf = xf * Transform3D(Basis(), Vector3(4.0, 0, 2.5))
			box(STONE, Vector3(-2.0, -0.2, -1.8), Vector3(2.0, 0.3, 1.8), Color("9c9484"))
			walls(METAL, 4.0, 3.6, 0.3, 3.4, Color("c8d0d4"))
			quad(GLASS, Vector3(-2.0, 1.6, 1.81), Vector3(2.0, 1.6, 1.81), Vector3(2.0, 3.0, 1.81), Vector3(-2.0, 3.0, 1.81), Color("6a8a9a"))
			gable_roof(4.0, 3.6, 3.7, 0.9, Color("5a5f64"), METAL, Color("c8d0d4"), 0.25)
			xf = saved2
		"uranium":
			headframe(Vector3(-2.5, 0, -3.0), 9.0, Color("5a5d60"))
			# Yellow drums under a shelter, behind a hazard fence.
			box(TRIM, Vector3(1.6, 3.0, 0.8), Vector3(6.0, 3.15, 5.2), Color("5a5f64"))
			for x in [1.8, 5.8]:
				for z in [1.0, 5.0]:
					box(TRIM, Vector3(x - 0.08, 0, z - 0.08), Vector3(x + 0.08, 3.0, z + 0.08), Color("8a8c88"))
			for i in range(9):
				cylinder(METAL, Vector3(2.4 + (i % 3) * 1.4, 0.0, 1.6 + (i / 3) * 1.4), 0.45, 1.1, Color("e0c030"), 10)
			for k in range(6):
				box(TRIM, Vector3(0.6 + k * 1.0, 0.0, -0.3), Vector3(1.1 + k * 1.0, 0.6, -0.2), Color("e0c030") if k % 2 == 0 else Color("2a2a2a"))
		"diamond":
			# A stepped open pit and the sorting plant.
			for k in range(4):
				cylinder(STONE, Vector3(-2.5, 0.05 - k * 0.02, 0.5), 5.0 - k * 1.1, 0.05, Color("5a5550").darkened(k * 0.12), 20)
			var saved3 := xf
			xf = xf * Transform3D(Basis(), Vector3(4.6, 0, -2.5))
			box(STONE, Vector3(-1.8, -0.2, -2.0), Vector3(1.8, 0.3, 2.0), Color("9c9484"))
			walls(METAL, 3.6, 4.0, 0.3, 5.6, Color("b8c0c4"))
			box(METAL, Vector3(-0.8, 5.9, -0.8), Vector3(0.8, 7.6, 0.8), Color("9aa4a8"))
			hip_roof(3.6, 4.0, 5.9, 0.8, Color("5a5f64"), 0.2)
			xf = saved3
			conveyor(Vector3(-1.5, 0.3, -1.0), Vector3(3.0, 4.0, -2.5), Color("5a5d60"))
		_:
			headframe(Vector3(0, 0, -2.0), 9.0, Color("5a5d60"))

## An oil refinery: distillation columns, spherical tanks, pipe racks and a flare stack.
func refinery(rng: RandomNumberGenerator) -> void:
	for i in range(3):
		var c := Vector3(-4.0 + i * 1.9, 0, -3.5)
		cylinder(METAL, c, 0.75 - i * 0.1, 8.0 + i * 2.0, Color("c8ccc8"), 14)
		for band in range(3):
			cylinder(TRIM, c + Vector3(0, 2.4 + band * 2.4, 0), 0.9 - i * 0.1, 0.18, Color("8a8c88"), 14)
		lattice(c + Vector3(0, 0, 0), 8.0 + i * 2.0, 1.7, 1.7, Color("6a6c6a"))
	for i in range(2):
		var c := Vector3(3.0, 0, -4.2 + i * 4.2)
		dome(METAL, c + Vector3(0, 2.0, 0), 1.6, 1.6, Color("e4e6e2"), 16, 5)
		var saved := xf
		xf = xf * Transform3D(Basis(Vector3.RIGHT, PI), c + Vector3(0, 2.0, 0))
		dome(METAL, Vector3.ZERO, 1.6, 1.6, Color("d8dad6"), 16, 5)
		xf = saved
		for leg in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			_beam(c + Vector3(leg.x, 0, leg.y) * 0.9, c + Vector3(leg.x, 2.0, leg.y) * 0.9 + Vector3(0, 0, 0), 0.07, Color("8a8c88"))
	for y in [1.8, 2.3]:
		_beam(Vector3(-4.0, y, 0.5), Vector3(4.5, y, 0.5), 0.12, Color("7a6a4a"))
	for x in [-3.5, 0.0, 3.5]:
		_beam(Vector3(x, 0, 0.5), Vector3(x, 2.4, 0.5), 0.08, Color("5a5d60"))
	_beam(Vector3(-5.5, 0, 4.5), Vector3(-5.5, 13.0, 4.5), 0.25, Color("8a3a2a"))
	cylinder(BANNER, Vector3(-5.5, 13.0, 4.5), 0.35, 0.9, Color("ffb347"), 8, 0.05)

## A chip fab: a long white clean-room hall with a glass front, ribbed roof
## plant and exhaust stacks.
func chip_fab(rng: RandomNumberGenerator) -> void:
	var w := 9.0
	var d := 6.0
	box(STONE, Vector3(-w * 0.5 - 0.2, -0.3, -d * 0.5 - 0.2), Vector3(w * 0.5 + 0.2, 0.3, d * 0.5 + 0.2), Color("b8b8b0"))
	walls(METAL, w, d, 0.3, 5.0, Color("eceee8"))
	quad(GLASS, Vector3(-w * 0.45, 0.4, d * 0.5 + 0.02), Vector3(w * 0.45, 0.4, d * 0.5 + 0.02), Vector3(w * 0.45, 3.4, d * 0.5 + 0.02), Vector3(-w * 0.45, 3.4, d * 0.5 + 0.02), Color("3a6a8a"))
	box(TRIM, Vector3(-w * 0.5, 5.3, -d * 0.5), Vector3(w * 0.5, 5.5, d * 0.5), Color("d8dad6"))
	for i in range(4):
		box(METAL, Vector3(-3.8 + i * 2.1, 5.5, -1.8), Vector3(-2.2 + i * 2.1, 6.4, 0.2), Color("a8b0b4"))
	for i in range(2):
		cylinder(METAL, Vector3(2.6 + i * 1.2, 5.5, 2.0), 0.3, 2.8, Color("d8dcd8"), 10)
	box(TRIM, Vector3(-w * 0.5, 4.6, d * 0.5), Vector3(-w * 0.5 + 3.0, 5.0, d * 0.5 + 0.05), banner_colour)

## A nuclear power station: a hyperbolic cooling tower, the containment dome
## and the turbine hall.
func nuclear(rng: RandomNumberGenerator) -> void:
	var c := Vector3(-3.2, 0, -2.0)
	var rings := 10
	for i in range(rings):
		var f0 := float(i) / rings
		var f1 := float(i + 1) / rings
		var r0 := 3.6 - 1.4 * sin(f0 * PI * 0.8)
		var r1 := 3.6 - 1.4 * sin(f1 * PI * 0.8)
		cylinder(STONE, c + Vector3(0, f0 * 12.0, 0), r0, 12.0 / rings, Color("d4d0c6").darkened(0.03 * (i % 2)), 22, r1)
	cylinder(TRIM, c + Vector3(0, 12.0, 0), 2.35, 0.1, Color("3a3a38"), 22)
	cylinder(STONE, Vector3(3.2, 0, -3.0), 2.4, 3.0, Color("c8c4ba"), 20)
	dome(STONE, Vector3(3.2, 3.0, -3.0), 2.4, 2.4, Color("dedad0"), 20, 6)
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(2.0, 0, 3.2))
	box(STONE, Vector3(-3.0, -0.2, -1.6), Vector3(3.0, 0.3, 1.6), Color("9c9484"))
	walls(METAL, 6.0, 3.2, 0.3, 4.0, Color("b8c0c4"))
	fenestrate(6.0, 3.2, 0.3, 1, 4.0, Color("d8dcd8"), Color(0, 0, 0, 0), rng, false)
	gable_roof(6.0, 3.2, 4.3, 0.8, Color("5a5f64"), METAL, Color("b8c0c4"), 0.25)
	xf = saved

## A solar farm: rows of tilted panels on frames and an inverter house.
func solar(rng: RandomNumberGenerator) -> void:
	for row in range(5):
		var z := -7.0 + row * 3.2
		var half := 7.0 - absf(row - 2) * 1.2
		var saved := xf
		xf = xf * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.0, z))
		quad(GLASS, Vector3(-half, 0, 0.9), Vector3(half, 0, 0.9), Vector3(half, 0, -0.9), Vector3(-half, 0, -0.9), Color("1e2e4a"))
		for x in range(int(-half), int(half), 1):
			quad(TRIM, Vector3(x - 0.02, 0.01, 0.9), Vector3(x + 0.02, 0.01, 0.9), Vector3(x + 0.02, 0.01, -0.9), Vector3(x - 0.02, 0.01, -0.9), Color("a8b0b8"))
		xf = saved
		for x in range(int(-half) + 1, int(half), 3):
			_beam(Vector3(x, 0, z), Vector3(x, 1.0, z), 0.06, Color("8a8c88"))
	box(METAL, Vector3(-1.0, 0, 8.0), Vector3(1.0, 1.8, 9.2), Color("c8ccc8"))

## A shipyard or port on the water's edge: sheds, a gantry crane and a quay;
## the port adds cranes, stacked containers and a warehouse.
func harbour(rng: RandomNumberGenerator, port: bool) -> void:
	box(STONE, Vector3(-8.0, -1.0, 4.0), Vector3(8.0, 0.4, 9.5), Color("a8a296"))  # the quay
	for x in range(-7, 8, 2):
		cylinder(TRIM, Vector3(x, 0.4, 9.2), 0.15, 0.4, Color("2a2a2a"), 8)
	if not port:
		# A building shed with an open end, and a gantry over the slip.
		var saved := xf
		xf = xf * Transform3D(Basis(), Vector3(-3.0, 0, -2.0))
		box(STONE, Vector3(-3.0, -0.2, -4.0), Vector3(3.0, 0.3, 4.0), Color("9c9484"))
		walls(METAL, 6.0, 8.0, 0.3, 6.0, Color("8a9aa0"))
		gable_roof(6.0, 8.0, 6.3, 2.0, Color("5a5f64"), METAL, Color("8a9aa0"), 0.3)
		xf = saved
		for x in [2.5, 7.0]:
			_beam(Vector3(x, 0, -2.0), Vector3(x, 10.0, -2.0), 0.3, Color("d0a030"))
			_beam(Vector3(x, 0, 6.0), Vector3(x, 10.0, 6.0), 0.3, Color("d0a030"))
		_beam(Vector3(2.5, 10.0, -2.0), Vector3(7.0, 10.0, -2.0), 0.3, Color("d0a030"))
		_beam(Vector3(2.5, 10.0, 6.0), Vector3(7.0, 10.0, 6.0), 0.3, Color("d0a030"))
		_beam(Vector3(4.75, 10.3, -2.0), Vector3(4.75, 10.3, 6.0), 0.35, Color("d0a030"))
	else:
		var paints := [Color("7a3b2e"), Color("35506a"), Color("5b6b3a"), Color("8a6a2a"), Color("b8b8b0")]
		for i in range(8):
			var x := -6.0 + (i % 4) * 2.8
			var z := -5.0 + (i / 4) * 2.6
			for layer in range(1 + rng.randi() % 2):
				box(METAL, Vector3(x, layer * 1.3, z), Vector3(x + 2.5, layer * 1.3 + 1.25, z + 1.2), paints[rng.randi() % paints.size()])
		for x in [-4.0, 3.0]:
			lattice(Vector3(x, 0.4, 7.0), 9.0, 2.0, 1.6, Color("c03a2a"))
			_beam(Vector3(x, 9.4, 3.0), Vector3(x, 9.4, 14.0), 0.3, Color("c03a2a"))
		var saved2 := xf
		xf = xf * Transform3D(Basis(), Vector3(5.0, 0, -3.5))
		walls(METAL, 4.0, 5.0, 0.0, 4.0, Color("a8b0a8"))
		gable_roof(4.0, 5.0, 4.0, 1.0, Color("7a3a2e"), METAL, Color("a8b0a8"), 0.3)
		xf = saved2

## A fishing wharf: a timber jetty, a net shed and boats alongside.
func wharf(rng: RandomNumberGenerator) -> void:
	box(PLANK, Vector3(-1.2, 0.1, -2.0), Vector3(1.2, 0.35, 10.0), Color("8a6a48"))
	for z in range(-1, 11, 2):
		for side in [-1.2, 1.2]:
			cylinder(WOOD, Vector3(side, -1.5, z), 0.15, 2.0, Color("5a4232"), 8)
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(-4.0, 0, -3.0))
	cottage(rng, 4.0, 3.2)
	xf = saved
	for i in range(2):
		var bz := 3.0 + i * 4.0
		box(WOOD, Vector3(1.6, -0.2, bz - 1.4), Vector3(2.8, 0.5, bz + 1.4), Color("e8e2d4") if i == 0 else Color("3a5a7a"))
		box(WOOD, Vector3(1.8, 0.5, bz - 0.4), Vector3(2.6, 1.3, bz + 0.5), Color("d8d0bc"))

## An arsenal: earth-covered magazines with blast doors, a missile rack and a
## hazard fence. Each Ammo Depot stores more missiles.
func arsenal(rng: RandomNumberGenerator, silo: bool) -> void:
	for i in range(3):
		var a := -0.9 + i * 0.9
		var c := Vector3(cos(a), 0, sin(a)) * 5.5 + Vector3(-1.5, 0, 0)
		var saved := xf
		xf = xf * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), c)
		for k in range(8):
			var a0 := PI * k / 8.0
			var a1 := PI * (k + 1) / 8.0
			quad(TRIM, Vector3(cos(a0) * 2.0, sin(a0) * 1.8, -2.4), Vector3(cos(a1) * 2.0, sin(a1) * 1.8, -2.4), Vector3(cos(a1) * 2.0, sin(a1) * 1.8, 2.4), Vector3(cos(a0) * 2.0, sin(a0) * 1.8, 2.4), Color("5b6b3a"))
		box(STONE, Vector3(-2.2, 0, 2.3), Vector3(2.2, 2.0, 2.7), Color("a8a296"))
		box(METAL, Vector3(-1.0, 0, 2.7), Vector3(1.0, 1.6, 2.8), Color("4a4f4c"))
		box(TRIM, Vector3(-1.0, 1.7, 2.75), Vector3(1.0, 1.85, 2.85), Color("e0c030"))
		xf = saved
	# The missile rack: missiles lying on cradles.
	for i in range(4 if not silo else 2):
		var z := -3.5 + i * 1.1
		box(TRIM, Vector3(-6.4, 0.0, z - 0.1), Vector3(-6.2, 0.7, z + 0.1), Color("5a5d60"))
		box(TRIM, Vector3(-2.0, 0.0, z - 0.1), Vector3(-1.8, 0.7, z + 0.1), Color("5a5d60"))
		var saved2 := xf
		xf = xf * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-1.2, 0.95, z))
		cylinder(METAL, Vector3.ZERO, 0.28, 5.4, Color("d8dcd8"), 10)
		cylinder(BANNER, Vector3(0, 5.4, 0), 0.28, 0.9, Color("c03a2a"), 10, 0.0)
		xf = saved2
	if silo:
		for i in range(2):
			var c2 := Vector3(3.5, 0, -4.0 + i * 3.4)
			cylinder(STONE, c2, 1.5, 0.5, Color("6a6e6a"), 20)
			cylinder(METAL, c2 + Vector3(0, 0.5, 0), 1.2, 0.1, Color("3a3e3c"), 20)
			box(TRIM, c2 + Vector3(-1.5, 0.52, -0.1), c2 + Vector3(1.5, 0.56, 0.1), Color("e0c030"))

## A bunker: a low concrete pillbox with firing slits.
func bunker(rng: RandomNumberGenerator) -> void:
	box(STONE, Vector3(-3.0, 0, -2.4), Vector3(3.0, 2.2, 2.4), Color("9a9890"))
	box(STONE, Vector3(-3.3, 2.2, -2.7), Vector3(3.3, 2.7, 2.7), Color("8a8880"))
	for x in [-1.8, 0.0, 1.8]:
		box(TRIM, Vector3(x - 0.6, 1.2, 2.39), Vector3(x + 0.6, 1.5, 2.45), Color("1a1c1e"))
	for i in range(10):
		var a := TAU * i / 10.0
		box(TRIM, Vector3(cos(a) * 4.6 - 0.5, 0, sin(a) * 4.0 - 0.3), Vector3(cos(a) * 4.6 + 0.5, 0.5, sin(a) * 4.0 + 0.3), Color("8a7a58"))

## A surface-to-air missile site: launchers with tilted tubes and a radar.
func sam_site(rng: RandomNumberGenerator) -> void:
	for i in range(3):
		var a := TAU * i / 3.0
		var c := Vector3(cos(a), 0, sin(a)) * 5.0
		box(METAL, c + Vector3(-1.4, 0, -0.9), c + Vector3(1.4, 1.0, 0.9), Color("5b6b3a"))
		var saved := xf
		xf = xf * Transform3D(Basis(Vector3.UP, -a).rotated(Vector3.UP, 0.0) * Basis(Vector3.BACK, 0.7), c + Vector3(0, 1.0, 0))
		for k in range(2):
			box(METAL, Vector3(-0.3 + k * 0.62, 0, -0.3), Vector3(0.27 + k * 0.62, 3.6, 0.3), Color("6a7a4a"))
		xf = saved
	lattice(Vector3.ZERO, 5.0, 1.4, 0.6, Color("8a8c88"))
	box(METAL, Vector3(-1.4, 5.0, -0.1), Vector3(1.4, 6.4, 0.1), Color("c8ccc8"))

## A park: lawns cut by paths, a fountain and a bandstand.
func park(rng: RandomNumberGenerator) -> void:
	cylinder(STONE, Vector3.ZERO, 2.2, 0.5, Color("c8c0b0"), 20)
	cylinder(GLASS, Vector3(0, 0.5, 0), 1.8, 0.04, Color("4a7a9a"), 20)
	cylinder(STONE, Vector3(0, 0.5, 0), 0.25, 1.4, Color("d8d0c0"), 10)
	var b := Vector3(5.0, 0, -4.0)
	cylinder(STONE, b, 2.0, 0.5, Color("c8c0b0"), 8)
	for k in range(8):
		var a := TAU * k / 8.0
		cylinder(WOOD, b + Vector3(cos(a) * 1.8, 0.5, sin(a) * 1.8), 0.08, 2.4, Color("e8e4d8"), 6)
	cylinder(ROOF, b + Vector3(0, 2.9, 0), 2.3, 1.2, Color("3e6a5a"), 8, 0.0)

## A stadium: an oval of stands round a green pitch, with floodlights.
func stadium(rng: RandomNumberGenerator) -> void:
	var rx := 8.5
	var rz := 6.5
	for k in range(24):
		var a0 := TAU * k / 24.0
		var a1 := TAU * (k + 1) / 24.0
		for tier in range(3):
			var f := 1.0 - tier * 0.12
			var y0 := tier * 1.2
			var p0 := Vector3(cos(a0) * rx * f, y0, sin(a0) * rz * f)
			var p1 := Vector3(cos(a1) * rx * f, y0, sin(a1) * rz * f)
			var q0 := Vector3(cos(a0) * rx * (f - 0.12), y0 + 1.2, sin(a0) * rz * (f - 0.12))
			var q1 := Vector3(cos(a1) * rx * (f - 0.12), y0 + 1.2, sin(a1) * rz * (f - 0.12))
			quad(STONE, p1, p0, q0, q1, Color("c8c4ba") if tier % 2 == 0 else banner_colour.lerp(Color("c8c4ba"), 0.5))
		quad(STONE, Vector3(cos(a1) * rx, 0, sin(a1) * rz), Vector3(cos(a0) * rx, 0, sin(a0) * rz), Vector3(cos(a0) * rx, 3.6, sin(a0) * rz), Vector3(cos(a1) * rx, 3.6, sin(a1) * rz), Color("b8b4aa"))
	quad(TRIM, Vector3(-4.5, 0.1, 2.6), Vector3(4.5, 0.1, 2.6), Vector3(4.5, 0.1, -2.6), Vector3(-4.5, 0.1, -2.6), Color("4f8a3a"))
	quad(TRIM, Vector3(-0.05, 0.12, 2.6), Vector3(0.05, 0.12, 2.6), Vector3(0.05, 0.12, -2.6), Vector3(-0.05, 0.12, -2.6), Color("e8e8e0"))
	for c in [Vector3(-7, 0, -5.5), Vector3(7, 0, -5.5), Vector3(-7, 0, 5.5), Vector3(7, 0, 5.5)]:
		_beam(c, c + Vector3(0, 9.0, 0), 0.12, Color("8a8c88"))
		box(TRIM, c + Vector3(-0.8, 9.0, -0.2), c + Vector3(0.8, 9.8, 0.2), Color("f2eed8"))

## An apartment block: storeys of plaster over a stone ground floor, with
## balconies, a flat roof behind a parapet and a water tank.
func apartments(rng: RandomNumberGenerator, footprint: float, floors: int) -> void:
	var s := footprint / 9.0
	var w := 7.4 * s
	var d := 6.0 * s
	var storey := 3.0
	var wall: Color = [Color("e2cfb0"), Color("d8c4a8"), Color("cbb89c"), Color("e8dcc8")][rng.randi() % 4]
	box(STONE, Vector3(-w * 0.5 - 0.1, -0.4, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, 3.4, d * 0.5 + 0.1), Color("a89f8e"))
	walls(PLASTER, w, d, 3.4, (floors - 1) * storey, wall)
	fenestrate(w, d, 0.4, floors, storey, Color("ece6d8"), Color(0, 0, 0, 0), rng)
	door(0.0, 0.4, d * 0.5 + 0.1, Color("3a3a3a"), Color("5a6068"))
	for f in range(1, floors):
		for i in [-1.0, 1.0]:
			var y := 0.4 + f * storey
			box(STONE, Vector3(i * w * 0.25 - 1.0, y - 0.1, d * 0.5), Vector3(i * w * 0.25 + 1.0, y + 0.05, d * 0.5 + 0.9), Color("cfc7b6"))
			box(TRIM, Vector3(i * w * 0.25 - 1.0, y + 0.05, d * 0.5 + 0.82), Vector3(i * w * 0.25 + 1.0, y + 0.95, d * 0.5 + 0.9), Color("3a3f44"))
	var top := 0.4 + floors * storey
	cornice(w, d, top, Color("e6dfd0"), 0.2, 0.3)
	box(STONE, Vector3(-w * 0.5, top, -d * 0.5), Vector3(w * 0.5, top + 0.8, -d * 0.5 + 0.25), Color("cfc7b6"))
	box(STONE, Vector3(-w * 0.5, top, d * 0.5 - 0.25), Vector3(w * 0.5, top + 0.8, d * 0.5), Color("cfc7b6"))
	box(TRIM, Vector3(-w * 0.5, top - 0.02, -d * 0.5), Vector3(w * 0.5, top + 0.05, d * 0.5), Color("5a5650"))
	cylinder(WOOD, Vector3(w * 0.25, top, -d * 0.2), 0.8, 1.8, Color("6a5a48"), 10)

## A brick factory with a saw-tooth roof and a stack.
func factory(rng: RandomNumberGenerator, footprint: float) -> void:
	var s := footprint / 10.0
	var w := 9.0 * s
	var d := 7.0 * s
	box(STONE, Vector3(-w * 0.5 - 0.2, -0.4, -d * 0.5 - 0.2), Vector3(w * 0.5 + 0.2, 0.3, d * 0.5 + 0.2), Color("8c877e"))
	walls(BRICK, w, d, 0.3, 5.2, Color("a85a44"))
	fenestrate(w, d, 0.3, 1, 5.2, Color("3a3f44"), Color(0, 0, 0, 0), rng, false)
	box(WOOD, Vector3(-1.4, 0.3, d * 0.5), Vector3(1.4, 3.8, d * 0.5 + 0.1), Color("5a6a72"))  # loading door
	var teeth := 4
	for i in range(teeth):
		var x0 := -w * 0.5 + w * i / teeth
		var x1 := x0 + w / teeth
		# Each tooth: a roof slope rising along x, then a vertical band of glass.
		var z := d * 0.5
		quad(ROOF, Vector3(x0, 5.5, z), Vector3(x1, 7.3, z), Vector3(x1, 7.3, -z), Vector3(x0, 5.5, -z), Color("6a6f74"))
		quad(GLASS, Vector3(x1, 5.5, z), Vector3(x1, 5.5, -z), Vector3(x1, 7.3, -z), Vector3(x1, 7.3, z), Color("8a9aa4"))
		tri(BRICK, Vector3(x0, 5.5, z), Vector3(x1, 5.5, z), Vector3(x1, 7.3, z), Color("a85a44"))
		tri(BRICK, Vector3(x1, 5.5, -z), Vector3(x0, 5.5, -z), Vector3(x1, 7.3, -z), Color("a85a44"))
	box(TRIM, Vector3(-w * 0.5 - 0.1, 5.3, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, 5.55, d * 0.5 + 0.1), Color("6a4a3a"))
	cylinder(BRICK, Vector3(w * 0.32, 0.3, -d * 0.3), 0.7, 13.0, Color("9a5040"), 12, 0.5)
	box(TRIM, Vector3(w * 0.32 - 0.6, 12.4, -d * 0.3 - 0.6), Vector3(w * 0.32 + 0.6, 12.8, -d * 0.3 + 0.6), Color("3a3230"))

## Finishes the building: one MeshInstance3D per material used, under a new node.
func commit() -> Node3D:
	var root := Node3D.new()
	for kind in _st:
		var st: SurfaceTool = _st[kind]
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _material(kind)
		mi.set_meta("architecture", true)
		root.add_child(mi)
	_st.clear()
	return root

## The recipes this kit knows, by building key.
static func has_recipe(key: String) -> bool:
	return key in ["hq", "cityCenter", "cityHall", "courthouse", "bank", "university", "library", "school", "policeStation",
		"hospital", "market", "villageCenter", "tankFactory", "warehouse", "barracks", "cottage", "residential", "workerHouse",
		"luxuryVillas", "housing", "apartments", "tvStation", "intelAgency", "techPark", "farm", "foodDepot", "powerPlant", "airfield", "helipad",
		"extractor", "mountainMine", "oilRefinery", "chipFab", "nuclearReactor", "solarFarm", "shipyard", "port",
		"fishingWharf", "ammoDepot", "missileSilo", "bunker", "samSite", "park", "stadium", "commandCenter",
		"museum", "waterTreatment"]

## --capture-city: close views of the capital's buildings (build/city-*.png).
static func capture(w: Node) -> void:
	for i in range(40):
		await w.get_tree().process_frame
	var home: Vector3 = w.start
	# Buildings the capital does not start with are laid out beside it for the pictures.
	for key in ["foodDepot", "powerPlant"]:
		if not w.buildings.any(func(b): return b.owner == 0 and b.key == key and not b.dead):
			var at = w.test_site(key, home)
			if at != null:
				w.place_building(key, at, 0, true)
	for i in range(10):
		await w.get_tree().process_frame
	var picks := {}
	for b in w.buildings:
		if b.owner == 0 and not b.dead and not picks.has(b.key):
			picks[b.key] = b.root.position
	var shots := [["overview", home, 70.0, 0.75, 0.7]]
	for key in ["hq", "cottage", "tankFactory", "barracks", "housing", "farm", "foodDepot", "powerPlant"]:
		if picks.has(key):
			shots.append([key, picks[key], 32.0, 0.5, 0.35])  # from the front (+z), where the entrances are
	for shot in shots:
		w.cam_focus = shot[1]
		w.cam_dist = shot[2]
		w.cam_dist_target = shot[2]
		w.cam_pitch = shot[3]
		w.cam_yaw = shot[4]
		for f in range(30):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/city-%s.png" % shot[0])
	w.get_tree().quit()
