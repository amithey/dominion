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

enum { PLASTER, BRICK, STONE, ROOF, TRIM, GLASS, WOOD, BANNER, METAL, PLANK, GLOW, GLOWG, GLOWW, GLOWR, CONCRETE, PANEL, STEEL, PAVERS, ASPHALT, GRAVEL }

var world: Node
var _materials := {}
var _st := {}             # surface -> SurfaceTool for the building being made
var xf := Transform3D.IDENTITY   # where the next piece goes, in the container's space
var banner_colour := Color.WHITE
var nation := ""          # the nation id of the building being made (a SAM site is launched differently in different services)
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

## The tileable PBR set `set_name` (assets/art/materials), `tile` metres to a repeat; vertex colours tint it (above 1 brightens).
func _pbr(m: StandardMaterial3D, set_name: String, tile: float, metal: float, rough: float) -> void:
	var dir := "res://assets/art/materials/%s_" % set_name
	m.albedo_texture = load(dir + "albedo.png")
	var normal = load(dir + "normal.png")
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = 0.8
	var rough_tex = load(dir + "roughness.png")
	if rough_tex != null:
		m.roughness_texture = rough_tex
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = rough
	m.metallic = metal
	m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func _material(kind: int) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.24 if kind == GLASS else (0.52 if kind == METAL else 0.88)
	m.metallic = 0.45 if kind == METAL else (0.18 if kind == GLASS else 0.0)
	m.metallic_specular = 0.55 if kind == GLASS else 0.35
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
			# Glass reflects the sky (and its clouds): glossy, a little metallic, bright at a glancing angle.
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.07
			m.metallic = 0.32
			m.metallic_specular = 0.9
			m.rim_enabled = true
			m.rim = 0.15
			m.rim_tint = 0.5
		WOOD:
			m.roughness = 0.8
		GLOW, GLOWG, GLOWW, GLOWR:
			# Lit slits, status lamps and warm lights: they stay bright at night and in shade.
			m.roughness = 0.4
			m.emission_enabled = true
			m.emission = Color("4fb6ee") if kind == GLOW else (Color("5fdc66") if kind == GLOWG else (Color("ff4a3a") if kind == GLOWR else Color("ffc070")))
			m.emission_energy_multiplier = 0.9 if kind != GLOWW else 0.7
		CONCRETE:
			_pbr(m, "concrete_smooth", 3.0, 0.0, 1.0)
		PANEL:
			_pbr(m, "corrugated_metal_grey", 5.0, 0.3, 0.9)
		STEEL:
			_pbr(m, "steel_painted_dark", 2.0, 0.5, 0.8)
		PAVERS:
			_pbr(m, "concrete_pavers", 2.0, 0.0, 1.0)
		ASPHALT:
			_pbr(m, "asphalt_worn", 3.0, 0.0, 1.0)
		GRAVEL:
			_pbr(m, "gravel", 2.0, 0.0, 1.0)
		BANNER:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.9
	if not tex.is_empty():
		m.albedo_texture = tex[0]
		m.normal_enabled = true
		m.normal_texture = tex[1]
		m.normal_scale = 0.65 # mortar and tiles have relief without sparkling at strategy distance
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[kind] = m
	return m

# ---------------------------------------------------------------- geometry

var _smoke: Array = []   # [point, "Industry" or "Home"]: where smoke rises (ambience.gd)

func begin() -> void:
	_st.clear()
	_smoke.clear()
	xf = Transform3D.IDENTITY

func smoke(point: Vector3, kind: String) -> void:
	_smoke.append([xf * point, kind])

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
		var surface_colour := colour
		if kind in [PLASTER, BRICK, STONE, PLANK]:
			# Baked contact weathering: the base reads as grounded even on Low.
			# Vertex colour keeps the existing material batches and draw count.
			var clean := smoothstep(0.25, 2.8, pts[k].y)
			surface_colour = colour.darkened((1.0 - clean) * 0.18)
		st.set_color(surface_colour)
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
	var glass := Color("1c2d36") if not lit else Color("cba468")
	# Two panes pick up different sky tones; a darker upper reveal makes the
	# opening read as recessed without transparent glass or an extra material.
	for pane in range(2):
		var y0 := centre.y - h * 0.5 + h * 0.5 * pane
		var pane_colour := glass.lightened(0.3) if pane == 1 and not lit else glass
		quad(GLASS, Vector3(centre.x-w*0.5,y0,z),Vector3(centre.x+w*0.5,y0,z),
			Vector3(centre.x+w*0.5,y0+h*0.5,z),Vector3(centre.x-w*0.5,y0+h*0.5,z),pane_colour)
	box(TRIM,Vector3(centre.x-w*0.5,centre.y-0.025,z),Vector3(centre.x+w*0.5,centre.y+0.025,z+0.05),frame.darkened(0.12))
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
	# Door panels and a brass handle remain in the existing WOOD/METAL batches.
	for side in [-1.0, 1.0]:
		box(WOOD,Vector3(x+side*0.25-0.18,y0+0.28,z+0.085),Vector3(x+side*0.25+0.18,y0+1.9,z+0.11),colour.lightened(0.09))
	box(METAL,Vector3(x+0.35,y0+0.95,z+0.12),Vector3(x+0.40,y0+1.2,z+0.18),Color("bfa372"))

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
	smoke(Vector3(x, y0 + h + 0.3, z), "Home")
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
		smoke(c + Vector3(0, 17.3 * s, 0), "Industry")
	# A heap of coal and the transformer yard with a lattice pylon.
	cylinder(TRIM, Vector3(-w * 0.5 - 1.8 * s, 0.0, d * 0.2), 2.0 * s, 1.6 * s, Color("26272a"), 12, 0.3)
	var yard := Vector3(w * 0.5 + 1.6 * s, 0.0, 0.8 * s)
	for i in range(3):
		box(METAL, yard + Vector3(-0.5, 0.0, (i - 1) * 1.4 - 0.4), yard + Vector3(0.5, 1.4, (i - 1) * 1.4 + 0.4), Color("6a7470"))
	for leg in [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)]:
		var foot: Vector3 = yard + Vector3(0, 0, -3.2 * s) + leg
		box(TRIM, foot + Vector3(-0.07, 0, -0.07), foot + Vector3(0.07, 9.0 * s, 0.07), Color("8a8c88"))
	box(TRIM, yard + Vector3(-1.8, 7.5 * s, -3.2 * s - 0.08), yard + Vector3(1.8, 7.5 * s + 0.15, -3.2 * s + 0.08), Color("8a8c88"))

## An airfield. One runway along z at RUNWAY_X (the same numbers air_operations.gd flies by), a taxiway to a four-slot
## apron, an arched hangar and a control tower west of the runway, a fuel farm behind a bund, an operations building,
## approach and edge lights, and a floodlit perimeter. Everything stands on a hexagonal concrete slab.
func airfield(rng: RandomNumberGenerator) -> void:
	const AO := preload("res://scripts/air_operations.gd")
	var rx: float = AO.RUNWAY_X
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var pale := Color(1.5, 1.5, 1.52)
	var bright := Color(2.3, 2.3, 2.4)
	var line := Color(1.7, 1.7, 1.6)
	var yel := Color(1.5, 1.25, 0.3)
	var warm := Color(1.0, 0.88, 0.65)
	# ---- the slab (a hexagon like the district), the runway with shoulders, markings and lights
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(ASPHALT, Vector3(rx - 2.0, 0.1, -10.0), Vector3(rx + 2.0, 0.16, 10.0), Color(0.82, 0.82, 0.86))
	for side in [-1.0, 1.0]:
		box(CONCRETE, Vector3(rx + side * 2.0 - (0.3 if side > 0 else 0.0), 0.1, -10.0), Vector3(rx + side * 2.0 + (0.3 if side < 0 else 0.0), 0.165, 10.0), Color(1.25, 1.25, 1.25))
		box(TRIM, Vector3(rx + side * 1.8 - 0.04, 0.16, -9.8), Vector3(rx + side * 1.8 + 0.04, 0.17, 9.8), line)
	for z in range(-8, 8, 2):
		box(TRIM, Vector3(rx - 0.06, 0.16, z + 0.2), Vector3(rx + 0.06, 0.17, z + 1.2), line)
	for end in [-1.0, 1.0]:
		for k in range(5):   # the threshold bars
			var x := rx - 1.5 + k * 0.75
			box(TRIM, Vector3(x, 0.16, end * 9.3 - 0.45), Vector3(x + 0.35, 0.17, end * 9.3 + 0.45), line)
		for k in range(2):   # the touchdown marks
			for sx in [-0.8, 0.8]:
				box(TRIM, Vector3(rx + sx - 0.18, 0.16, end * (6.6 - k * 1.2) - 0.35), Vector3(rx + sx + 0.18, 0.17, end * (6.6 - k * 1.2) + 0.35), line)
	for i in range(11):   # edge lights, green at the near end, red at the far
		var z := -9.5 + i * 1.9
		for side in [-1.0, 1.0]:
			var k := GLOWG if z < -7.0 else (GLOWR if z > 7.0 else GLOWW)
			var col := Color(0.6, 1.0, 0.55) if k == GLOWG else (Color(1.0, 0.4, 0.35) if k == GLOWR else warm)
			box(k, Vector3(rx + side * 2.45 - 0.07, 0.1, z - 0.07), Vector3(rx + side * 2.45 + 0.07, 0.3, z + 0.07), col)
	for i in range(4):   # PAPI lights beside the near threshold
		box(GLOWR if i < 2 else GLOWW, Vector3(rx - 3.2 - i * 0.5, 0.1, -6.0), Vector3(rx - 2.8 - i * 0.5, 0.45, -5.6), Color(1.0, 0.4, 0.35) if i < 2 else warm)
	# ---- the taxiway to the apron and the apron itself, with parking boxes, lead-in lines and slot bars
	box(ASPHALT, Vector3(rx + 2.0, 0.1, -1.4), Vector3(3.2, 0.155, 1.4), Color(0.9, 0.9, 0.92))
	box(TRIM, Vector3(rx + 2.0, 0.16, -0.04), Vector3(3.2, 0.17, 0.04), yel)
	for side in [-1.0, 1.0]:
		box(TRIM, Vector3(rx + 2.0, 0.16, side * 1.3 - 0.03), Vector3(3.2, 0.17, side * 1.3 + 0.03), yel)
	box(CONCRETE, Vector3(3.2, 0.1, -8.6), Vector3(9.6, 0.15, 8.6), Color(1.3, 1.3, 1.3))
	for i in range(AO.SLOT_POSITIONS.airfield.size()):
		var sp: Vector3 = AO.SLOT_POSITIONS.airfield[i]
		for side in [-1.0, 1.0]:
			box(TRIM, Vector3(sp.x - 1.6, 0.15, sp.z + side * 1.9 - 0.05), Vector3(sp.x + 2.4, 0.16, sp.z + side * 1.9 + 0.05), yel)
		box(TRIM, Vector3(sp.x + 2.4, 0.15, sp.z - 1.9), Vector3(sp.x + 2.5, 0.16, sp.z + 1.9), yel)
		box(TRIM, Vector3(3.2, 0.15, sp.z - 0.05), Vector3(sp.x - 1.6, 0.16, sp.z + 0.05), yel)
		for k in range(i + 1):
			box(TRIM, Vector3(sp.x + 1.9, 0.15, sp.z - 0.6 + k * 0.35), Vector3(sp.x + 2.2, 0.16, sp.z - 0.6 + k * 0.35 + 0.12), line)
		for side in [-1.0, 1.0]:   # the tie-down rings
			box(TRIM, Vector3(sp.x - 0.3, 0.15, sp.z + side * 1.2 - 0.1), Vector3(sp.x + 0.1, 0.19, sp.z + side * 1.2 + 0.1), Color("5a6a72"))
	# ---- the hangar: block walls, a barrel vault, an open lit door, a stripe, roof vents and an apron in front
	var hx := rx - 5.0
	var hz := -4.0
	var hw := 2.3
	var hl := 3.7
	var sv := xf
	xf = xf * Transform3D(Basis(), Vector3(hx, 0, hz))
	box(CONCRETE, Vector3(-hw - 2.2, 0.1, hl), Vector3(hw + 2.4, 0.15, hl + 3.8), Color(1.3, 1.3, 1.3))
	for sx in [-1.0, 1.0]:
		box(PANEL, Vector3(sx * hw - (0.08 if sx > 0 else -0.0) - (0.0 if sx > 0 else 0.08), 0.15, -hl), Vector3(sx * hw + (0.08 if sx > 0 else 0.0), 2.6, hl), pale)
	box(PANEL, Vector3(-hw, 0.15, -hl - 0.08), Vector3(hw, 2.6, -hl), pale)
	for s in range(10):
		var a0 := -PI * 0.5 + PI * s / 10.0
		var a1 := -PI * 0.5 + PI * (s + 1) / 10.0
		var x0 := hw * sin(a0)
		var x1 := hw * sin(a1)
		var y0 := 2.6 + 1.7 * cos(a0)
		var y1 := 2.6 + 1.7 * cos(a1)
		quad(PANEL, Vector3(x0, y0, hl), Vector3(x1, y1, hl), Vector3(x1, y1, -hl), Vector3(x0, y0, -hl), pale)
		quad(PANEL, Vector3(x0, 2.6, hl), Vector3(x1, 2.6, hl), Vector3(x1, y1, hl), Vector3(x0, y0, hl), pale)
		quad(PANEL, Vector3(x1, 2.6, -hl), Vector3(x0, 2.6, -hl), Vector3(x0, y0, -hl), Vector3(x1, y1, -hl), pale)
	box(TRIM, Vector3(-hw + 0.2, 0.15, hl), Vector3(hw - 0.2, 3.3, hl + 0.05), ink)       # the open door
	for k in range(3):
		box(GLOWW, Vector3(-1.3 + k * 1.1, 2.7, hl + 0.04), Vector3(-0.9 + k * 1.1, 2.8, hl + 0.08), warm)
	for sx in [-1.0, 1.0]:
		box(STEEL, Vector3(sx * (hw - 0.2) - 0.08, 0.15, hl + 0.02), Vector3(sx * (hw - 0.2) + 0.08, 3.3, hl + 0.12), bright)
	box(TRIM, Vector3(-hw + 0.1, 3.3, hl), Vector3(hw - 0.1, 3.45, hl + 0.2), haz)
	for k in range(4):
		box(TRIM, Vector3(-hw + 0.04, 0.2 + k * 0.0, -hl + 0.6 + k * 1.8), Vector3(-hw - 0.01, 2.4, -hl + 0.7 + k * 1.8), Color("8a949a"))
	for k in range(2):
		cylinder(METAL, Vector3(-0.0, 4.2, -2.0 + k * 3.0), 0.3, 0.3, light, 10)
	banner(-hw + 0.5, 3.2, hl + 0.05, 1.8)
	xf = sv
	# ---- the control tower: a concrete shaft with a stair window strip, a flared glass cab, a deep roof and a radar
	var tx := rx - 5.0
	var tz := 5.5
	box(CONCRETE, Vector3(tx - 0.8, 0.1, tz - 0.8), Vector3(tx + 0.8, 5.6, tz + 0.8), Color(1.3, 1.3, 1.3))
	for k in range(5):
		box(GLASS, Vector3(tx - 0.12, 0.8 + k * 0.9, tz + 0.8), Vector3(tx + 0.12, 1.3 + k * 0.9, tz + 0.84), Color("2f5568"))
	box(TRIM, Vector3(tx - 1.0, 5.6, tz - 1.0), Vector3(tx + 1.0, 5.76, tz + 1.0), Color("56646a"))
	box(TRIM, Vector3(tx - 1.65, 5.76, tz - 1.65), Vector3(tx + 1.65, 5.9, tz + 1.65), Color(1.3, 1.3, 1.3))
	box(GLASS, Vector3(tx - 1.55, 5.9, tz - 1.55), Vector3(tx + 1.55, 7.2, tz + 1.55), Color("2c4d5c"))
	for k in range(5):
		var cx := tx - 1.55 + k * 0.775
		bar(STEEL, Vector3(cx, 5.9, tz + 1.55), Vector3(cx, 7.2, tz + 1.55), 0.035, bright)
		bar(STEEL, Vector3(cx, 5.9, tz - 1.55), Vector3(cx, 7.2, tz - 1.55), 0.035, bright)
	box(TRIM, Vector3(tx - 2.0, 7.2, tz - 2.0), Vector3(tx + 2.0, 7.4, tz + 2.0), Color("3a464c"))
	for sd in [-1.0, 1.0]:   # a yellow fascia round the cab roof
		box(TRIM, Vector3(tx + sd * 2.0 - 0.04, 7.2, tz - 2.0), Vector3(tx + sd * 2.0 + 0.04, 7.4, tz + 2.0), haz)
		box(TRIM, Vector3(tx - 2.0, 7.2, tz + sd * 2.0 - 0.04), Vector3(tx + 2.0, 7.4, tz + sd * 2.0 + 0.04), haz)
	bar(STEEL, Vector3(tx, 7.5, tz), Vector3(tx, 8.6, tz), 0.04, bright)
	bar(TRIM, Vector3(tx - 0.8, 8.6, tz), Vector3(tx + 0.8, 8.6, tz), 0.06, ink)
	box(GLOWR, Vector3(tx - 0.1, 8.65, tz - 0.1), Vector3(tx + 0.1, 8.85, tz + 0.1), Color(1.0, 0.4, 0.35))
	for sx in [-1.0, 1.0]:   # a railing round the cab roof
		bar(STEEL, Vector3(tx + sx * 1.9, 7.5, tz - 1.9), Vector3(tx + sx * 1.9, 7.5, tz + 1.9), 0.02, bright)
	# ---- the operations building south of the taxiway: a long low block, a glass front, a canopy and a flagpole
	box(PANEL, Vector3(-0.6, 0.1, 4.4), Vector3(3.0, 2.8, 8.4), pale)
	box(TRIM, Vector3(-0.7, 2.8, 4.3), Vector3(3.1, 2.95, 8.5), Color("56646a"))
	box(GLASS, Vector3(-0.3, 0.8, 4.4 - 0.04), Vector3(2.7, 2.3, 4.4), Color("2f5568"))
	for gx in range(5):
		bar(STEEL, Vector3(-0.3 + gx * 0.75, 0.8, 4.34), Vector3(-0.3 + gx * 0.75, 2.3, 4.34), 0.03, bright)
	box(CONCRETE, Vector3(-0.8, 2.5, 3.2), Vector3(3.2, 2.62, 4.5), teal_colour())
	for px in [-0.6, 3.0]:
		bar(STEEL, Vector3(px, 0.1, 3.3), Vector3(px, 2.5, 3.3), 0.05, bright)
	for k in range(2):
		fan(Vector3(0.4 + k * 1.8, 2.95, 6.4), 0.4)
	bar(STEEL, Vector3(3.6, 0.1, 3.4), Vector3(3.6, 5.6, 3.4), 0.04, bright)
	banner(3.6, 5.5, 3.4, 1.6)
	# ---- the fuel farm: two tanks inside a bund wall with a pump house and a loading arm
	box(CONCRETE, Vector3(-0.8, 0.1, -9.0), Vector3(2.6, 0.5, -3.8), Color(1.25, 1.25, 1.25))
	box(PAVERS, Vector3(-0.6, 0.5, -8.8), Vector3(2.4, 0.52, -4.0), Color(1.1, 1.1, 1.1))
	for i in range(2):
		var cz := -7.4 + i * 2.6
		cylinder(METAL, Vector3(0.9, 0.52, cz), 0.95, 2.0, light, 16)
		cylinder(TRIM, Vector3(0.9, 2.52, cz), 0.98, 0.06, Color("8a949a"), 16)
		box(TRIM, Vector3(0.85, 2.58, cz - 0.1), Vector3(0.95, 2.78, cz + 0.1), ink)
		bar(STEEL, Vector3(1.8, 0.52, cz), Vector3(1.8, 2.4, cz), 0.03, bright)
		box(TRIM, Vector3(-0.45, 1.2, cz - 0.05), Vector3(-0.2, 1.3, cz + 0.05), Color("c83a2e"))
	box(PANEL, Vector3(-0.7, 0.52, -4.3), Vector3(0.7, 1.7, -3.9), pale)
	pipe(METAL, Vector3(0.0, 0.8, -7.4), Vector3(0.0, 0.8, -4.3), 0.1, Color("c83a2e"))
	# ---- the windsock, two floodlight masts at the far corners, an approach-light bar and a perimeter fence
	bar(STEEL, Vector3(1.2, 0.1, 9.6), Vector3(1.2, 4.0, 9.6), 0.05, bright)
	for k in range(4):
		pipe(METAL, Vector3(1.2 + k * 0.5, 4.0 - k * 0.04, 9.6), Vector3(1.2 + (k + 1) * 0.5, 3.96 - k * 0.04, 9.6), 0.26 - k * 0.04, Color("f08030") if k % 2 == 0 else Color("f0eee4"), 8)
	for p in [Vector3(-9.0, 0, -4.2), Vector3(9.4, 0, 3.0), Vector3(9.4, 0, -4.0), Vector3(-6.4, 0, 8.4)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 6.0, 0), 0.06, bright)
		box(GLOWW, p + Vector3(-0.4, 5.95, -0.15), p + Vector3(0.4, 6.05, 0.15), warm)
	for i in range(8):
		box(GLOWW, Vector3(rx - 1.8 + i * 0.5, 0.1, -10.6), Vector3(rx - 1.64 + i * 0.5, 0.25, -10.44), warm)
	for i in range(14):
		var a := TAU * i / 14.0
		var fp := Vector3(cos(a) * 11.4, 0.1, sin(a) * 11.4)
		if absf(fp.x) < 10.4 and absf(fp.z) < 12.0 - absf(fp.x) * 0.577:
			bar(STEEL, fp, fp + Vector3(0, 1.5, 0), 0.03, bright)
	for t in [Vector3(-9.8, 0, -7.4), Vector3(-6.2, 0, 7.0), Vector3(9.8, 0, 6.4)]:
		cylinder(WOOD, t + Vector3(0, 0.1, 0), 0.2, 1.5, Color("6a5038"), 7, 0.13)
		dome(PLASTER, t + Vector3(0, 1.3, 0), 1.1, 1.1, Color("3f6e3c"), 10, 4)

func teal_colour() -> Color:
	return Color("2f6f7e")

## A shipping container, 2.6 x 1.25 x 1.1 m lying along x, its lower corner at `lo`; the paint is brightened for the grey metal.
func container(lo: Vector3, colour: Color) -> void:
	box(PANEL, lo, lo + Vector3(2.6, 1.25, 1.1), Color(colour.r * 1.7, colour.g * 1.7, colour.b * 1.7))
	box(TRIM, lo + Vector3(2.6, 0.05, 0.1), lo + Vector3(2.64, 1.2, 1.0), Color("2a2f33"))
	box(TRIM, lo + Vector3(-0.04, 0.05, 0.1), lo + Vector3(0.0, 1.2, 1.0), Color("2a2f33"))

## A quay-side container crane at x on the quay: a portal on two rails, a lattice boom out over the water and a back
## reach, a trolley, and (when `lift` is set) a container hanging from its spreader.
func ship_crane(x: float, paint: Color, lift: Color, lifting: bool) -> void:
	var ink := Color("1d252a")
	var lxs := [x - 1.7, x + 1.7]
	for lx in lxs:
		for lz in [6.0, 8.2]:
			bar(TRIM, Vector3(lx, 0.4, lz), Vector3(lx, 8.6, lz), 0.2, paint)
		bar(TRIM, Vector3(lx, 8.6, 6.0), Vector3(lx, 8.6, 8.2), 0.2, paint)
		bar(TRIM, Vector3(lx, 1.8, 6.0), Vector3(lx, 7.4, 8.2), 0.07, paint)
		bar(TRIM, Vector3(lx, 1.8, 8.2), Vector3(lx, 7.4, 6.0), 0.07, paint)
		bar(TRIM, Vector3(lx, 0.45, 5.9), Vector3(lx, 0.45, 8.3), 0.25, ink)          # the bogie on its rail
		# the boom: top and bottom chords, posts and diagonals, out over the water
		bar(TRIM, Vector3(lx, 9.0, 3.0), Vector3(lx, 9.5, 13.6), 0.13, paint)
		bar(TRIM, Vector3(lx, 8.2, 6.0), Vector3(lx, 8.55, 13.6), 0.1, paint)
		for k in range(6):
			var z0 := 6.0 + k * 1.3
			var z1 := z0 + 1.3
			var yt0 := 9.0 + (z0 - 3.0) * 0.047
			var yt1 := 9.0 + (z1 - 3.0) * 0.047
			bar(TRIM, Vector3(lx, yt0 - 0.85, z0), Vector3(lx, yt0, z0), 0.05, paint)
			bar(TRIM, Vector3(lx, yt0 - 0.85, z0), Vector3(lx, yt1, z1), 0.04, paint)
		bar(TRIM, Vector3(lx, 9.0, 3.0), Vector3(lx, 8.6, 6.0), 0.1, paint)       # the back reach
	for z in [6.0, 8.2, 13.6]:
		bar(TRIM, Vector3(lxs[0], 9.0 + (z - 3.0) * 0.047, z), Vector3(lxs[1], 9.0 + (z - 3.0) * 0.047, z), 0.1, paint)
	box(TRIM, Vector3(x - 1.5, 9.1, 3.2), Vector3(x + 1.5, 10.5, 5.6), paint)              # the machinery house
	box(GLASS, Vector3(x - 1.4, 9.5, 5.6), Vector3(x + 1.4, 10.3, 5.64), Color("2f5568"))
	box(TRIM, Vector3(x - 1.6, 10.5, 3.1), Vector3(x + 1.6, 10.62, 5.7), Color("aab4b8"))
	box(TRIM, Vector3(x - 1.2, 7.7, 10.5), Vector3(x + 1.2, 8.2, 11.7), ink)                # the trolley
	box(TRIM, Vector3(x - 2.9, 6.7, 10.7), Vector3(x - 2.2, 7.6, 11.5), Color("3a4a54"))    # the driver's cab
	box(GLASS, Vector3(x - 2.88, 6.9, 11.5), Vector3(x - 2.22, 7.5, 11.54), Color("2f5568"))
	var drop := 2.8 if lifting else 6.2
	for cx in [-0.7, 0.7]:
		bar(TRIM, Vector3(x + cx, 7.6, 11.1), Vector3(x + cx, drop + 0.3, 11.1), 0.025, ink)
	box(TRIM, Vector3(x - 0.9, drop, 10.75), Vector3(x + 0.9, drop + 0.3, 11.45), ink)       # the spreader
	if lifting:
		container(Vector3(x - 1.3, drop - 1.25, 10.55), lift)
	box(GLOWR, Vector3(x - 0.1, 9.6, 13.6), Vector3(x + 0.1, 9.9, 13.8), Color(1.0, 0.4, 0.35))

## A hull on the slip: stepped slices narrowing to a bow, red below the waterline and grey above, on keel blocks,
## with the forward third still open frames, scaffolding along the sides and welding lights.
func hull(x: float, z0: float, z1: float) -> void:
	var n := 16
	var ink := Color("1d252a")
	for k in range(n):
		var s := (k + 0.5) / n
		var za := z0 + (z1 - z0) * k / n
		var zb := z0 + (z1 - z0) * (k + 1) / n
		var hw := 1.8 * (0.78 + 0.22 * smoothstep(0.0, 0.2, s))
		if s > 0.62:
			hw *= sqrt(maxf(0.0, 1.0 - pow((s - 0.62) / 0.38, 2.0)))
		hw = maxf(hw, 0.12)
		box(TRIM, Vector3(x - hw, 0.9, za), Vector3(x + hw, 2.1, zb), Color("8a3a2e"))
		if s < 0.65:
			box(TRIM, Vector3(x - hw * 0.96, 2.1, za), Vector3(x + hw * 0.96, 3.2, zb), Color("9aa3a8"))
			box(TRIM, Vector3(x - hw * 0.96, 3.2, za), Vector3(x + hw * 0.96, 3.26, zb), Color("56646a"))
		else:
			for side in [-1.0, 1.0]:
				bar(TRIM, Vector3(x + side * hw * 0.96, 2.1, (za + zb) * 0.5), Vector3(x + side * hw * 0.96, 3.2, (za + zb) * 0.5), 0.05, Color("9aa3a8"))
			if k % 2 == 0:
				bar(TRIM, Vector3(x - hw * 0.96, 3.2, (za + zb) * 0.5), Vector3(x + hw * 0.96, 3.2, (za + zb) * 0.5), 0.05, Color("9aa3a8"))
		if k % 3 == 0:
			box(CONCRETE, Vector3(x - 0.5, 0.4, za), Vector3(x + 0.5, 0.9, za + 0.5), Color(1.1, 1.1, 1.1))   # a keel block
	box(TRIM, Vector3(x - 0.9, 3.26, z0 + 1.0), Vector3(x + 0.9, 4.4, z0 + 3.4), Color("c9d0d2"))              # the deckhouse so far
	box(GLASS, Vector3(x - 0.8, 3.7, z0 + 3.4), Vector3(x + 0.8, 4.2, z0 + 3.44), Color("2f5568"))
	for i in range(8):   # scaffolding along both sides: posts and two lifts of boards
		var sz := z0 + 0.8 + i * 1.35
		for side in [-1.0, 1.0]:
			var sx: float = x + side * 2.45
			bar(STEEL, Vector3(sx, 0.4, sz), Vector3(sx, 4.4, sz), 0.04, Color(2.3, 2.3, 2.4))
			if i < 7:
				for y in [2.2, 3.5]:
					box(TRIM, Vector3(sx - 0.25, y, sz), Vector3(sx + 0.25, y + 0.05, sz + 1.35), Color("d9b45f"))
	for p in [Vector3(x - 2.0, 3.3, z0 + 5.0), Vector3(x + 2.0, 2.3, z0 + 7.5), Vector3(x + 1.8, 3.3, z0 + 3.0)]:
		box(GLOWW, p, p + Vector3(0.18, 0.18, 0.18), Color(1.0, 0.9, 0.7))

## A helipad hex: two lit and marked pads (the positions air_operations.gd uses), an arched hangar with its doors open
## and lit, a control cabin, a fuel point, a crash tender, a windsock and floodlights.
func helipad(rng: RandomNumberGenerator) -> void:
	const AO := preload("res://scripts/air_operations.gd")
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var pale := Color(1.5, 1.5, 1.52)
	var bright := Color(2.3, 2.3, 2.4)
	box(CONCRETE, Vector3(-8.4, -1.4, -9.4), Vector3(8.4, 0.18, 6.6), Color(1.0, 1.0, 1.0))
	box(PAVERS, Vector3(-8.2, 0.18, -4.2), Vector3(8.2, 0.2, 6.4), Color(1.2, 1.2, 1.2))
	for sp in AO.SLOT_POSITIONS.helipad:
		cylinder(CONCRETE, sp + Vector3(0, 0.18, 0), 2.9, 0.08, Color(1.3, 1.3, 1.3), 28)
		cylinder(TRIM, sp + Vector3(0, 0.265, 0), 2.55, 0.02, Color("6d777c"), 28)
		for k in range(28):
			var a0 := TAU * k / 28.0
			var a1 := TAU * (k + 1) / 28.0
			bar(TRIM, sp + Vector3(cos(a0) * 2.5, 0.285, sin(a0) * 2.5), sp + Vector3(cos(a1) * 2.5, 0.285, sin(a1) * 2.5), 0.05, Color("f0eee4"))
		for k in range(20):
			var a0 := TAU * k / 20.0
			var a1 := TAU * (k + 1) / 20.0
			bar(TRIM, sp + Vector3(cos(a0) * 2.1, 0.285, sin(a0) * 2.1), sp + Vector3(cos(a1) * 2.1, 0.285, sin(a1) * 2.1), 0.04, haz if k % 2 == 0 else ink)
		box(TRIM, sp + Vector3(-0.8, 0.27, -0.95), sp + Vector3(-0.5, 0.30, 0.95), Color("f0eee4"))
		box(TRIM, sp + Vector3(0.5, 0.27, -0.95), sp + Vector3(0.8, 0.30, 0.95), Color("f0eee4"))
		box(TRIM, sp + Vector3(-0.5, 0.27, -0.15), sp + Vector3(0.5, 0.30, 0.15), Color("f0eee4"))
		for k in range(16):   # the edge lights
			var a := TAU * k / 16.0
			box(GLOWW, sp + Vector3(cos(a) * 2.78 - 0.07, 0.22, sin(a) * 2.78 - 0.07), sp + Vector3(cos(a) * 2.78 + 0.07, 0.32, sin(a) * 2.78 + 0.07), Color(1.0, 0.88, 0.65))
	for x in [-3.5, 3.5]:   # taxi lines from each pad to the hangar
		box(TRIM, Vector3(x - 0.05, 0.2, -4.2), Vector3(x + 0.05, 0.21, -2.9), Color(0.95, 0.85, 0.3))
	# the hangar: walls, a barrel-vault roof, an open lit door, a lit office annex and roof fans
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(0, 0, -7.0))
	var hw := 4.2
	var hd := 3.8
	walls(PANEL, hw * 2.0, hd * 2.0, 0.13, 3.6, pale)
	box(CONCRETE, Vector3(-hw - 0.06, 0.13, hd - 0.02), Vector3(hw + 0.06, 0.7, hd + 0.07), Color(1.1, 1.1, 1.1))
	for s in range(8):
		var a0 := -PI * 0.5 + PI * s / 8.0
		var a1 := -PI * 0.5 + PI * (s + 1) / 8.0
		var x0 := hw * sin(a0)
		var x1 := hw * sin(a1)
		var y0 := 3.73 + 1.7 * cos(a0)
		var y1 := 3.73 + 1.7 * cos(a1)
		quad(PANEL, Vector3(x0, y0, hd), Vector3(x1, y1, hd), Vector3(x1, y1, -hd), Vector3(x0, y0, -hd), pale)
		quad(PANEL, Vector3(x0, 3.73, hd), Vector3(x1, 3.73, hd), Vector3(x1, y1, hd), Vector3(x0, y0, hd), pale)
		quad(PANEL, Vector3(x1, 3.73, -hd), Vector3(x0, 3.73, -hd), Vector3(x0, y0, -hd), Vector3(x1, y1, -hd), pale)
	box(TRIM, Vector3(-3.0, 0.13, hd), Vector3(3.0, 3.4, hd + 0.05), ink)                 # the open door
	box(GLOWW, Vector3(-2.7, 3.1, hd + 0.04), Vector3(2.7, 3.2, hd + 0.09), Color(1.0, 0.88, 0.65))
	for k in range(3):
		box(GLOWW, Vector3(-2.0 + k * 2.0, 2.2, hd + 0.04), Vector3(-1.6 + k * 2.0, 2.3, hd + 0.08), Color(1.0, 0.88, 0.65))
	for sx in [-1.0, 1.0]:
		box(STEEL, Vector3(sx * 3.1 - 0.1, 0.13, hd + 0.02), Vector3(sx * 3.1 + 0.1, 3.4, hd + 0.12), bright)
	box(TRIM, Vector3(-3.1, 3.4, hd), Vector3(3.1, 3.55, hd + 0.2), haz)
	box(PANEL, Vector3(hw, 0.13, -1.4), Vector3(hw + 2.2, 2.7, 1.6), pale)                 # the office annex
	box(TRIM, Vector3(hw - 0.1, 2.7, -1.5), Vector3(hw + 2.3, 2.85, 1.7), Color("56646a"))
	for k in range(2):
		box(GLASS, Vector3(hw + 0.2 + k * 1.0, 1.0, 1.6), Vector3(hw + 1.0 + k * 1.0, 2.1, 1.64), Color("2f5568"))
	for k in range(2):
		fan(Vector3(-1.6 + k * 3.2, 5.44, 0.0), 0.5)
	banner(-hw + 0.8, 3.3, hd + 0.05, 2.0)
	xf = saved
	# the control cabin: a concrete shaft, a glass cab and a radar bar
	box(CONCRETE, Vector3(6.4, 0.13, -5.2), Vector3(7.6, 4.4, -4.0), Color(1.3, 1.3, 1.3))
	box(TRIM, Vector3(6.1, 4.4, -5.5), Vector3(7.9, 4.55, -3.7), Color("56646a"))
	box(GLASS, Vector3(6.2, 4.55, -5.4), Vector3(7.8, 5.7, -3.8), Color("2c4d5c"))
	for cx in [6.2, 7.0, 7.8]:
		bar(STEEL, Vector3(cx, 4.55, -5.4), Vector3(cx, 5.7, -5.4), 0.04, bright)
	box(TRIM, Vector3(6.0, 5.7, -5.6), Vector3(8.0, 5.85, -3.6), Color(1.3, 1.3, 1.3))
	bar(STEEL, Vector3(7.0, 5.85, -4.6), Vector3(7.0, 6.9, -4.6), 0.04, bright)
	bar(TRIM, Vector3(6.2, 6.9, -4.6), Vector3(7.8, 6.9, -4.6), 0.06, ink)
	box(GLOWR, Vector3(6.9, 6.95, -4.7), Vector3(7.1, 7.15, -4.5), Color(1.0, 0.4, 0.35))
	# a fuel point: a tank on saddles, a dispenser and a hose
	pipe(METAL, Vector3(6.6, 0.95, -0.4), Vector3(6.6, 0.95, 2.4), 0.7, light, 14)
	for z in [0.0, 2.0]:
		box(CONCRETE, Vector3(5.9, 0.13, z - 0.15), Vector3(7.3, 0.8, z + 0.15), Color(1.2, 1.2, 1.2))
	box(TRIM, Vector3(7.5, 0.13, 0.6), Vector3(8.0, 1.6, 1.1), Color("c83a2e"))
	box(GLOWG, Vector3(7.55, 1.2, 1.1), Vector3(7.95, 1.4, 1.14), Color(0.6, 1.0, 0.55))
	# a crash tender with a light bar
	box(TRIM, Vector3(-7.5, 0.35, -2.6), Vector3(-5.2, 1.5, -1.6), Color("c0392b"))
	box(TRIM, Vector3(-5.2, 0.35, -2.6), Vector3(-4.2, 2.0, -1.6), Color("a8322a"))
	box(GLASS, Vector3(-4.2, 1.3, -2.5), Vector3(-4.16, 1.9, -1.7), Color("1c2d36"))
	box(TRIM, Vector3(-7.5, 1.0, -2.62), Vector3(-5.2, 1.15, -2.6), Color("f0eee4"))
	box(GLOWR, Vector3(-5.0, 2.0, -2.4), Vector3(-4.5, 2.12, -1.8), Color(1.0, 0.4, 0.35))
	for wx in [-6.8, -5.6, -4.7]:
		for wz in [-2.7, -1.5]:
			box(TRIM, Vector3(wx - 0.3, 0.13, wz - 0.1), Vector3(wx + 0.3, 0.7, wz + 0.1), Color("1a1c1e"))
	# a windsock on a mast, floodlights and a low fence
	bar(STEEL, Vector3(-7.4, 0.13, 3.6), Vector3(-7.4, 5.2, 3.6), 0.05, bright)
	for k in range(4):
		pipe(METAL, Vector3(-7.4 + k * 0.62, 5.2 - k * 0.05, 3.6), Vector3(-7.4 + (k + 1) * 0.62, 5.15 - k * 0.05, 3.6), 0.34 - k * 0.05, Color("f08030") if k % 2 == 0 else Color("f0eee4"), 8)
	for p in [Vector3(-8.0, 0, 5.8), Vector3(8.0, 0, 5.8), Vector3(8.0, 0, -8.6), Vector3(-8.0, 0, -8.6)]:
		bar(STEEL, p + Vector3(0, 0.13, 0), p + Vector3(0, 5.2, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.35, 5.15, -0.15), p + Vector3(0.35, 5.25, 0.15), Color(1.0, 0.88, 0.65))
	for i in range(14):
		var fx := -8.1 + i * 1.25
		bar(STEEL, Vector3(fx, 0.13, 6.2), Vector3(fx, 1.3, 6.2), 0.03, bright)
	box(TRIM, Vector3(-8.1, 1.0, 6.17), Vector3(8.1, 1.04, 6.23), Color("a0aaae"))

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
	bar(TRIM, a, b, t, colour)

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
		"oil", "seaOil", "gas", "seaGas":
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

## A square beam of half-thickness t from a to b, in any material.
func bar(kind: int, a: Vector3, b: Vector3, t: float, colour: Color) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var saved := xf
	xf = xf * Transform3D(Basis(x, y, z), a)
	box(kind, Vector3(-t, 0, -t), Vector3(t, length, t), colour)
	xf = saved

## A round pipe of radius r from a to b (open at the lower end).
func pipe(kind: int, a: Vector3, b: Vector3, r: float, colour: Color, sides := 8) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var saved := xf
	xf = xf * Transform3D(Basis(x, y, z), a)
	cylinder(kind, Vector3.ZERO, r, length, colour, sides)
	xf = saved

## A cooling fan seen from above: a pale ring, a dark well, three blades and a hub, on top of a unit at c.
func fan(c: Vector3, r: float) -> void:
	cylinder(METAL, c, r, 0.16, Color(1.0, 1.0, 1.02), 16)
	cylinder(TRIM, c + Vector3(0, 0.165, 0), r * 0.84, 0.01, Color("1d252a"), 16)
	for k in range(3):
		var a := TAU * k / 3.0 + 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		bar(METAL, c + Vector3(0, 0.19, 0) - dir * r * 0.78, c + Vector3(0, 0.19, 0) + dir * r * 0.78, 0.045, Color("9aa4a8"))
	cylinder(METAL, c + Vector3(0, 0.17, 0), r * 0.14, 0.07, Color("c9d0d2"), 8)

## A glowing hexagon outline, r metres across from the centre, on a wall facing +z.
func hexagon(c: Vector3, r: float, t: float, kind: int, colour: Color) -> void:
	for i in range(6):
		var a0 := PI / 6.0 + TAU * i / 6.0
		var a1 := a0 + TAU / 6.0
		bar(kind, c + Vector3(cos(a0) * r, sin(a0) * r, 0), c + Vector3(cos(a1) * r, sin(a1) * r, 0), t, colour)

## A louvred plant door on a wall facing +z at depth z: a dark recess and rows of slats.
func louvres(x0: float, x1: float, y0: float, y1: float, z: float, colour: Color, dark: Color) -> void:
	box(TRIM, Vector3(x0, y0, z - 0.02), Vector3(x1, y1, z + 0.04), dark)
	var n := int((y1 - y0) / 0.16)
	for i in range(n):
		var y := y0 + 0.08 + i * 0.16
		box(TRIM, Vector3(x0 + 0.05, y, z + 0.03), Vector3(x1 - 0.05, y + 0.07, z + 0.11), colour)

## A small car parked nose to +z, its feet at p.
func car(p: Vector3, colour: Color) -> void:
	box(TRIM, p + Vector3(-0.85, 0.2, -1.6), p + Vector3(0.85, 0.75, 1.6), colour)
	box(GLASS, p + Vector3(-0.75, 0.75, -0.9), p + Vector3(0.75, 1.3, 0.9), Color("1c2d36"))
	box(TRIM, p + Vector3(-0.78, 1.3, -0.8), p + Vector3(0.78, 1.34, 0.8), colour)
	for sx in [-0.85, 0.85]:
		for sz in [-1.0, 1.0]:
			box(TRIM, p + Vector3(sx - 0.1, 0.0, sz - 0.3), p + Vector3(sx + 0.1, 0.4, sz + 0.3), Color("1a1c1e"))

## An AI data centre. A long server hall in pale cladding with a dark shadow gap and a concrete parapet, glowing slits
## and louvred plant doors, a glass lobby under a cantilevered canopy, a roof of dry coolers with their pipework, a
## row of cooling towers with their basins, backup generators and a fuel tank, a two-transformer substation, a solar
## car port, a gatehouse and lamp posts. Pale surfaces are brightened past white on purpose (vertex colours above 1).
func data_centre(rng: RandomNumberGenerator) -> void:
	var pale := Color(1.5, 1.5, 1.52)
	var teal := Color("2f6f7e")
	var gold := Color("d9b45f")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var steel := Color("8e999e")
	var origin := xf
	xf = xf * Transform3D(Basis(), Vector3(-0.4, 0, 0.6))
	# ---- the ground: a concrete slab, a paved forecourt, a gravel plant yard, asphalt and parking lines
	box(CONCRETE, Vector3(-9.0, -1.6, -9.6), Vector3(9.8, 0.12, 6.4), Color(1.0, 1.0, 1.0))
	box(PAVERS, Vector3(-0.2, 0.12, 3.8), Vector3(7.0, 0.15, 6.2), Color(1.25, 1.25, 1.25))
	box(ASPHALT, Vector3(-9.0, 0.12, 2.0), Vector3(-0.4, 0.15, 6.2), Color(1.1, 1.1, 1.1))
	box(GRAVEL, Vector3(4.6, 0.12, -9.6), Vector3(9.8, 0.17, 2.2), Color(1.1, 1.1, 1.1))
	for i in range(4):
		box(TRIM, Vector3(-8.6 + i * 2.3, 0.15, 2.3), Vector3(-8.5 + i * 2.3, 0.16, 5.7), Color(0.95, 0.95, 0.9))
	# ---- the server hall, 10.4 x 6.8 and 5.6 high, centred at (-1.8, -3.0)
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(-1.8, 0, -3.0))
	var W := 10.4
	var D := 6.8
	var H := 5.6
	walls(PANEL, W, D, 0.12, H, pale)
	for s in range(4):   # a concrete plinth round the foot
		var yaw := s * PI * 0.5
		var sp := xf
		xf = xf * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
		var span := W if s % 2 == 0 else D
		var depth := D if s % 2 == 0 else W
		box(CONCRETE, Vector3(-span * 0.5 - 0.06, 0.12, depth * 0.5 - 0.02), Vector3(span * 0.5 + 0.06, 0.75, depth * 0.5 + 0.07), Color(1.1, 1.1, 1.1))
		# panel joints: dark reveals every 2.6 m
		var n := int(span / 2.6)
		for i in range(1, n + 1):
			var x := -span * 0.5 + i * span / (n + 1) * 1.0
			box(TRIM, Vector3(x - 0.03, 0.75, depth * 0.5), Vector3(x + 0.03, H - 0.6, depth * 0.5 + 0.035), ink)
		# the shadow gap under the parapet, and the parapet itself
		box(TRIM, Vector3(-span * 0.5, H - 0.6, depth * 0.5), Vector3(span * 0.5, H - 0.4, depth * 0.5 + 0.05), ink)
		box(CONCRETE, Vector3(-span * 0.5 - 0.12, H - 0.4, depth * 0.5 - 0.1), Vector3(span * 0.5 + 0.12, H + 0.4, depth * 0.5 + 0.12), Color(1.3, 1.3, 1.3))
		xf = sp
	box(GRAVEL, Vector3(-W * 0.5, H, -D * 0.5), Vector3(W * 0.5, H + 0.06, D * 0.5), Color(0.9, 0.9, 0.9))
	# lit slits in groups of three, high on the walls; louvred plant doors low on the front and back
	for i in range(6):
		var z := -D * 0.5 + 0.7 + i * 1.08
		for side in [-1.0, 1.0]:
			var xs: float = side * W * 0.5
			box(TRIM, Vector3(minf(xs, xs + side * 0.05), 3.55, z - 0.06), Vector3(maxf(xs, xs + side * 0.05), 4.45, z + 0.66), ink)
			box(GLOW, Vector3(minf(xs + side * 0.04, xs + side * 0.09), 3.65, z), Vector3(maxf(xs + side * 0.04, xs + side * 0.09), 4.35, z + 0.6), Color(0.75, 0.92, 1.0))
	for i in range(3):
		var x := -4.5 + i * 1.5
		box(TRIM, Vector3(x - 0.06, 3.55, D * 0.5), Vector3(x + 1.26, 4.45, D * 0.5 + 0.05), ink)
		box(GLOW, Vector3(x, 3.65, D * 0.5 + 0.04), Vector3(x + 1.2, 4.35, D * 0.5 + 0.09), Color(0.75, 0.92, 1.0))
	louvres(-4.7, -2.6, 0.95, 3.2, D * 0.5, light, ink)
	louvres(-2.3, -0.2, 0.95, 3.2, D * 0.5, light, ink)
	# the emblem: a lit hexagon over the lobby
	hexagon(Vector3(3.0, 4.35, D * 0.5 + 0.02), 0.55, 0.06, GLOW, Color(0.75, 0.92, 1.0))
	hexagon(Vector3(3.0, 4.35, D * 0.5 + 0.02), 0.26, 0.05, GLOW, Color(0.75, 0.92, 1.0))
	# the back wall: a row of grilles
	var back := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	for i in range(3):
		louvres(-4.2 + i * 2.9, -2.4 + i * 2.9, 0.95, 3.0, D * 0.5, light, ink)
	xf = back
	# roof: dry coolers, two rows of four, each a housing under a fan ring, joined by insulated pipes
	var roof := H + 0.4
	for row in range(2):
		for i in range(4):
			var cx := -3.9 + i * 2.6
			var cz := -1.6 + row * 3.0
			box(METAL, Vector3(cx - 0.95, roof, cz - 0.85), Vector3(cx + 0.95, roof + 1.0, cz + 0.85), Color(1.0, 1.0, 1.02))
			box(TRIM, Vector3(cx - 0.97, roof + 0.55, cz - 0.87), Vector3(cx + 0.97, roof + 0.62, cz + 0.87), steel)
			for k in range(3):
				box(TRIM, Vector3(cx - 0.8 + k * 0.8, roof, cz + 0.85), Vector3(cx - 0.5 + k * 0.8, roof + 0.5, cz + 0.88), ink)
			fan(Vector3(cx, roof + 1.0, cz), 0.66)
	pipe(METAL, Vector3(-4.8, roof + 0.3, 0.0), Vector3(4.8, roof + 0.3, 0.0), 0.1, light)
	pipe(METAL, Vector3(-4.8, roof + 0.55, 0.0), Vector3(4.8, roof + 0.55, 0.0), 0.07, teal)
	for i in range(8):
		box(TRIM, Vector3(-4.6 + i * 1.3, roof, -0.05), Vector3(-4.5 + i * 1.3, roof + 0.3, 0.05), ink)
	# stair bulkhead, a lightning mast and a radome
	box(PANEL, Vector3(-4.9, roof, 1.4), Vector3(-3.3, roof + 2.2, 3.0), pale)
	box(TRIM, Vector3(-5.0, roof + 2.2, 1.3), Vector3(-3.2, roof + 2.35, 3.1), Color("56646a"))
	box(TRIM, Vector3(-4.4, roof, 3.0), Vector3(-3.8, roof + 1.9, 3.04), ink)
	bar(METAL, Vector3(4.4, roof, -2.6), Vector3(4.4, roof + 2.6, -2.6), 0.04, ink)
	cylinder(METAL, Vector3(4.4, roof + 2.6, -2.6), 0.1, 0.1, light, 8)
	bar(METAL, Vector3(3.6, roof, 2.7), Vector3(3.6, roof + 1.2, 2.7), 0.05, steel)
	dome(TRIM, Vector3(3.6, roof + 1.2, 2.7), 0.62, 0.5, Color(1.4, 1.4, 1.4), 14, 4)
	xf = saved
	# ---- the lobby: a glass annex with a curtain wall, a cantilevered canopy, doors, planters and the nation's banner
	var lx0 := 0.4
	var lx1 := 5.8
	var lz0 := 0.4
	var lz1 := 4.0
	box(CONCRETE, Vector3(lx0, 0.12, lz0), Vector3(lx1, 0.32, lz1), Color(1.2, 1.2, 1.2))
	box(PANEL, Vector3(lx0, 0.32, lz0), Vector3(lx0 + 0.1, 4.4, lz1), pale)
	for gx in range(5):   # the front curtain wall: panes of varied tint between steel mullions
		for gy in range(3):
			var x0 := lx0 + 0.1 + gx * (lx1 - lx0 - 0.1) / 5.0
			var x1 := x0 + (lx1 - lx0 - 0.1) / 5.0
			var y0 := 0.32 + gy * 1.36
			var tone := 0.85 + rng.randf() * 0.5
			quad(GLASS, Vector3(x0, y0, lz1), Vector3(x1, y0, lz1), Vector3(x1, y0 + 1.36, lz1), Vector3(x0, y0 + 1.36, lz1), Color("2f5568") * tone)
	for gz in range(3):   # the side wall, towards the plant
		for gy in range(3):
			var z0 := lz0 + gz * (lz1 - lz0) / 3.0
			var z1 := z0 + (lz1 - lz0) / 3.0
			var y0 := 0.32 + gy * 1.36
			var tone := 0.85 + rng.randf() * 0.5
			quad(GLASS, Vector3(lx1, y0, z1), Vector3(lx1, y0, z0), Vector3(lx1, y0 + 1.36, z0), Vector3(lx1, y0 + 1.36, z1), Color("2f5568") * tone)
	for gx in range(6):
		var mx := lx0 + 0.1 + gx * (lx1 - lx0 - 0.1) / 5.0
		box(STEEL, Vector3(mx - 0.05, 0.32, lz1), Vector3(mx + 0.05, 4.4, lz1 + 0.12), Color(1.6, 1.6, 1.6))
	for gz in range(4):
		var mz := lz0 + gz * (lz1 - lz0) / 3.0
		box(STEEL, Vector3(lx1, 0.32, mz - 0.05), Vector3(lx1 + 0.12, 4.4, mz + 0.05), Color(1.6, 1.6, 1.6))
	for gy in range(4):
		var my := 0.32 + gy * 1.36
		box(STEEL, Vector3(lx0, my - 0.04, lz1), Vector3(lx1 + 0.12, my + 0.04, lz1 + 0.12), Color(1.6, 1.6, 1.6))
	box(TRIM, Vector3(2.5, 0.32, lz1 + 0.02), Vector3(4.1, 2.4, lz1 + 0.07), ink)          # the double door
	box(TRIM, Vector3(3.27, 0.32, lz1 + 0.07), Vector3(3.33, 2.4, lz1 + 0.13), steel)
	box(METAL, Vector3(3.05, 1.0, lz1 + 0.12), Vector3(3.15, 1.5, lz1 + 0.17), light)
	box(METAL, Vector3(3.45, 1.0, lz1 + 0.12), Vector3(3.55, 1.5, lz1 + 0.17), light)
	box(CONCRETE, Vector3(lx0 - 0.7, 4.4, lz0), Vector3(lx1 + 0.8, 4.78, lz1 + 1.1), Color(1.25, 1.25, 1.25))   # the canopy
	box(TRIM, Vector3(lx0 - 0.7, 4.4, lz1 + 1.02), Vector3(lx1 + 0.8, 4.78, lz1 + 1.12), gold)
	box(TRIM, Vector3(lx0 - 0.7, 4.34, lz1 + 0.55), Vector3(lx1 + 0.8, 4.4, lz1 + 1.1), teal)
	box(GLOWW, Vector3(lx0 - 0.5, 4.3, lz1 + 0.4), Vector3(lx1 + 0.6, 4.34, lz1 + 0.6), Color(1.0, 0.85, 0.6))
	for cx in [lx0 - 0.5, 2.6, lx1 + 0.6]:
		bar(STEEL, Vector3(cx, 0.15, lz1 + 0.9), Vector3(cx, 4.4, lz1 + 0.9), 0.1, Color(1.6, 1.6, 1.6))
	box(CONCRETE, Vector3(2.2, 0.12, lz1 + 0.08), Vector3(4.4, 0.2, lz1 + 1.4), Color(1.3, 1.3, 1.3))
	banner(0.0, 4.2, 0.5, 2.6)
	for px in [lx0 + 0.2, lx1 - 1.0]:
		box(CONCRETE, Vector3(px, 0.12, lz1 + 0.3), Vector3(px + 1.2, 0.7, lz1 + 0.95), Color(1.2, 1.2, 1.2))
		dome(PLASTER, Vector3(px + 0.6, 0.7, lz1 + 0.62), 0.5, 0.45, Color("4f7f46"), 10, 3)
	for k in range(4):
		cylinder(STEEL, Vector3(1.2 + k * 1.6, 0.12, lz1 + 1.7), 0.07, 0.7, Color(1.5, 1.5, 1.5), 8)
	# ---- the cooling plant on the right: three towers on a concrete basin, piped to the hall
	box(CONCRETE, Vector3(5.0, 0.12, -7.6), Vector3(9.4, 0.45, 1.8), Color(1.25, 1.25, 1.25))
	for i in range(3):
		var tz := -6.2 + i * 2.9
		var tx := 7.2
		box(PANEL, Vector3(tx - 1.3, 0.45, tz - 1.2), Vector3(tx + 1.3, 3.2, tz + 1.2), Color(1.35, 1.38, 1.4))
		var tsave := xf
		xf = xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(tx, 0, tz))
		louvres(-1.05, 1.05, 0.75, 3.0, 1.3, light, ink)
		xf = tsave
		cylinder(METAL, Vector3(tx, 3.2, tz), 1.1, 0.8, light, 16, 0.96)
		cylinder(TRIM, Vector3(tx, 4.0, tz), 0.9, 0.02, ink, 16)
		fan(Vector3(tx, 3.98, tz), 0.9)
		box(GLOWG, Vector3(tx + 1.3, 2.6, tz - 0.15), Vector3(tx + 1.36, 2.85, tz + 0.15), Color(0.6, 1.0, 0.55))
	pipe(METAL, Vector3(5.6, 0.9, -6.4), Vector3(5.6, 0.9, 0.2), 0.2, light)
	pipe(METAL, Vector3(5.6, 1.3, -6.4), Vector3(5.6, 1.3, 0.2), 0.15, teal)
	pipe(METAL, Vector3(5.6, 0.9, -3.4), Vector3(3.3, 0.9, -3.4), 0.2, light)
	pipe(METAL, Vector3(5.6, 1.3, -2.6), Vector3(3.3, 1.3, -2.6), 0.15, teal)
	for z in [-5.2, -2.0, 0.0]:
		box(TRIM, Vector3(5.5, 0.45, z - 0.06), Vector3(5.7, 0.7, z + 0.06), ink)
	# ---- backup power behind the hall: three generator containers with stacks, and a fuel tank on saddles
	for i in range(3):
		var gx := -6.0 + i * 3.0
		box(METAL, Vector3(gx - 1.3, 0.12, -8.3), Vector3(gx + 1.3, 2.3, -7.1), Color(0.7, 0.74, 0.78))
		box(TRIM, Vector3(gx - 1.34, 2.3, -8.34), Vector3(gx + 1.34, 2.42, -7.06), ink)
		for k in range(4):
			box(TRIM, Vector3(gx - 1.0 + k * 0.62, 0.3, -7.1), Vector3(gx - 0.95 + k * 0.62, 2.1, -7.07), ink)
		box(GLOWG, Vector3(gx + 1.0, 1.6, -7.1), Vector3(gx + 1.2, 1.8, -7.06), Color(0.6, 1.0, 0.55))
		pipe(METAL, Vector3(gx + 0.7, 2.42, -7.9), Vector3(gx + 0.7, 3.8, -7.9), 0.12, Color("30383c"))
		cylinder(TRIM, Vector3(gx + 0.7, 3.8, -7.9), 0.17, 0.08, ink, 8)
	pipe(METAL, Vector3(2.3, 0.95, -8.0), Vector3(4.3, 0.95, -8.0), 0.75, light, 14)
	for x in [2.7, 3.9]:
		box(CONCRETE, Vector3(x - 0.15, 0.12, -8.6), Vector3(x + 0.15, 0.55, -7.4), Color(1.2, 1.2, 1.2))
	box(TRIM, Vector3(3.2, 1.7, -8.12), Vector3(3.4, 1.9, -7.88), steel)
	# ---- the substation: two transformers with radiator fins and bushings under a small gantry
	for i in range(2):
		var ex := 5.8 + i * 2.8
		var ez := -8.4
		box(METAL, Vector3(ex - 0.9, 0.17, ez - 0.7), Vector3(ex + 0.9, 1.7, ez + 0.7), Color(0.78, 0.9, 0.84))
		for k in range(6):
			box(METAL, Vector3(ex - 0.8 + k * 0.32, 0.3, ez + 0.7), Vector3(ex - 0.72 + k * 0.32, 1.5, ez + 0.95), Color(0.7, 0.8, 0.75))
		pipe(METAL, Vector3(ex - 0.6, 1.7, ez), Vector3(ex + 0.6, 1.7, ez), 0.2, Color(0.7, 0.8, 0.75), 10)
		for k in range(3):
			pipe(METAL, Vector3(ex - 0.5 + k * 0.5, 1.7, ez - 0.35), Vector3(ex - 0.5 + k * 0.5, 2.7, ez - 0.35), 0.09, Color("d9c9a8"))
			cylinder(TRIM, Vector3(ex - 0.5 + k * 0.5, 2.7, ez - 0.35), 0.12, 0.08, Color("a89878"), 8)
	lattice(Vector3(5.0, 0.17, -9.2), 5.0, 1.0, 0.4, steel)
	lattice(Vector3(9.4, 0.17, -9.2), 5.0, 1.0, 0.4, steel)
	bar(TRIM, Vector3(5.0, 5.0, -9.2), Vector3(9.4, 5.0, -9.2), 0.07, steel)
	# ---- a solar car port over the parking, with three cars
	for i in range(3):
		var px := -8.6 + i * 2.3
		var tilt := xf
		xf = xf * Transform3D(Basis(Vector3.RIGHT, 0.16), Vector3(px + 1.15, 3.5, 2.2))
		quad(GLASS, Vector3(-1.1, 0, 3.6), Vector3(1.1, 0, 3.6), Vector3(1.1, 0, 0), Vector3(-1.1, 0, 0), Color("172538"))
		for k in range(1, 4):
			box(TRIM, Vector3(-1.1, 0.005, k * 0.9 - 0.02), Vector3(1.1, 0.02, k * 0.9 + 0.02), Color(1.2, 1.25, 1.3))
		box(TRIM, Vector3(-0.02, 0.005, 0), Vector3(0.02, 0.02, 3.6), Color(1.2, 1.25, 1.3))
		box(STEEL, Vector3(-1.1, -0.1, 0), Vector3(1.1, 0, 3.6), Color(1.4, 1.4, 1.4))
		xf = tilt
	for x in [-8.6, -4.0, -1.7]:
		bar(STEEL, Vector3(x, 0.15, 2.5), Vector3(x, 3.6, 2.5), 0.09, Color(1.5, 1.5, 1.5))
		bar(STEEL, Vector3(x, 0.15, 5.7), Vector3(x, 3.0, 5.7), 0.09, Color(1.5, 1.5, 1.5))
	for c in [[-7.45, Color("e8ecee")], [-5.15, Color("26384e")], [-2.85, Color("a8322a")]]:
		car(Vector3(c[0], 0.15, 3.0), c[1])
	# ---- a gatehouse with a barrier on the drive, lamp posts, a fence, trees and a hedge
	box(PANEL, Vector3(7.6, 0.12, 4.0), Vector3(9.4, 2.6, 5.6), pale)
	box(GLASS, Vector3(7.7, 1.0, 5.6), Vector3(9.3, 2.2, 5.64), Color("2f5568"))
	box(TRIM, Vector3(7.4, 2.6, 3.8), Vector3(9.6, 2.78, 5.8), Color("56646a"))
	bar(TRIM, Vector3(6.9, 1.0, 5.0), Vector3(7.6, 1.0, 5.0), 0.05, steel)
	box(TRIM, Vector3(5.2, 0.9, 4.95), Vector3(6.9, 1.05, 5.05), Color("d8d8d0"))
	for k in range(4):
		box(TRIM, Vector3(5.2 + k * 0.425, 0.9, 4.94), Vector3(5.2 + k * 0.425 + 0.21, 1.05, 5.06), Color("c83a2e"))
	box(STEEL, Vector3(5.0, 0.12, 4.9), Vector3(5.2, 1.15, 5.1), Color(1.5, 1.5, 1.5))
	for p in [Vector3(-0.8, 0, 6.0), Vector3(3.4, 0, 6.0), Vector3(8.8, 0, 2.4), Vector3(-9.0, 0, -1.0), Vector3(-9.0, 0, -6.0)]:
		bar(STEEL, p + Vector3(0, 0.15, 0), p + Vector3(0, 4.4, 0), 0.05, Color(1.4, 1.4, 1.4))
		bar(STEEL, p + Vector3(0, 4.4, 0), p + Vector3(0.45, 4.5, 0), 0.04, Color(1.4, 1.4, 1.4))
		box(GLOWW, p + Vector3(0.3, 4.38, -0.14), p + Vector3(0.75, 4.44, 0.14), Color(1.0, 0.88, 0.65))
	for i in range(15):
		var fx := -9.0 + i * 1.28
		if fx > 4.6 and fx < 6.5:
			continue
		bar(STEEL, Vector3(fx, 0.12, 6.3), Vector3(fx, 1.5, 6.3), 0.035, Color(1.2, 1.2, 1.2))
	box(TRIM, Vector3(-9.0, 1.2, 6.27), Vector3(4.6, 1.26, 6.33), Color("a0aaae"))
	box(TRIM, Vector3(-9.0, 0.5, 6.27), Vector3(4.6, 0.56, 6.33), Color("a0aaae"))
	box(TRIM, Vector3(6.5, 1.2, 6.27), Vector3(9.8, 1.26, 6.33), Color("a0aaae"))
	box(TRIM, Vector3(6.5, 0.5, 6.27), Vector3(9.8, 0.56, 6.33), Color("a0aaae"))
	for t in [Vector3(-8.6, 0, -6.0), Vector3(-8.2, 0, 0.4), Vector3(9.2, 0, 6.2)]:
		cylinder(WOOD, t + Vector3(0, 0.12, 0), 0.2, 1.6, Color("6a5038"), 7, 0.13)
		dome(PLASTER, t + Vector3(0, 1.3, 0), 1.1, 1.1, Color("3f6e3c"), 10, 4)
		dome(PLASTER, t + Vector3(0.35, 2.1, 0.15), 0.75, 0.8, Color("4f8046"), 8, 3)
	for i in range(4):
		dome(PLASTER, Vector3(0.6 + i * 1.4, 0.0, 6.9), 0.7, 0.6, Color("3f6e3c"), 8, 3)
	xf = origin

## A parabolic dish at c on a short pedestal: a dark rim, a pale bowl tilted up and yawed, a feed arm and a feed horn.
func dish(c: Vector3, r: float, yaw: float, tilt: float) -> void:
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	pipe(METAL, c, c + Vector3(0, 1.0, 0), 0.14, Color(1.5, 1.5, 1.55), 10)
	box(STEEL, c + Vector3(-0.3, 0.0, -0.3), c + Vector3(0.3, 0.15, 0.3), bright)
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt), c + Vector3(0, 1.0, 0))
	cylinder(METAL, Vector3(0, 0, 0), 0.22, 0.3, Color(1.5, 1.5, 1.55), 10)
	cylinder(METAL, Vector3(0, 0.3, 0), 0.22, r * 0.5, Color(1.65, 1.65, 1.7), 20, r)    # the bowl: a cone opening upwards
	cylinder(TRIM, Vector3(0, 0.3 + r * 0.5, 0), r, 0.04, ink, 20)                         # the dark rim
	cylinder(TRIM, Vector3(0, 0.3 + r * 0.5 + 0.045, 0), r * 0.94, 0.01, Color("2a343a"), 20)
	for k in range(3):
		var a := TAU * k / 3.0 + 0.5
		bar(STEEL, Vector3(cos(a) * r * 0.9, 0.3 + r * 0.5, sin(a) * r * 0.9), Vector3(0, 0.3 + r * 0.5 + r * 0.75, 0), 0.025, bright)
	cylinder(METAL, Vector3(0, 0.3 + r * 0.5 + r * 0.7, 0), 0.07, 0.18, Color(1.6, 1.6, 1.65), 8)
	xf = saved

## A radome on a drum: a white sphere cap on a short ring with a lit seam.
func radome(c: Vector3, r: float) -> void:
	cylinder(PANEL, c, r * 0.92, 0.45, Color(1.45, 1.45, 1.5), 18)
	cylinder(GLOW, c + Vector3(0, 0.45, 0), r * 0.94, 0.05, Color(0.75, 0.92, 1.0), 18)
	dome(TRIM, c + Vector3(0, 0.5, 0), r, r * 0.95, Color(1.7, 1.7, 1.72), 18, 6)

## The targeting fusion cell: a hardened, earth-bermed operations block whose long front is a lit screen wall, with a
## roof of radomes and dishes, a sensor mast, a communications container park, generators and a guarded, fenced yard.
func fusion_cell(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var bright := Color(2.3, 2.3, 2.4)
	var pale := Color(1.5, 1.5, 1.52)
	var olive := Color(0.62, 0.7, 0.58)
	var warm := Color(1.0, 0.88, 0.65)
	var cyan := Color(0.75, 0.92, 1.0)
	var teal := Color("2f6f7e")
	var origin := xf
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(PAVERS, Vector3(-9.0, 0.1, 0.4), Vector3(9.0, 0.13, 7.0), Color(1.2, 1.2, 1.2))
	box(GRAVEL, Vector3(-9.0, 0.1, -8.0), Vector3(9.0, 0.14, -4.6), Color(1.1, 1.1, 1.1))
	# ---- the operations block: concrete, 11 x 5 m, 4 m high, with a lit screen wall on the front and earth banked at the back
	var bx := 0.0
	var bz := -2.0
	var W := 11.0
	var D := 5.0
	box(CONCRETE, Vector3(bx - W * 0.5, 0.1, bz - D * 0.5), Vector3(bx + W * 0.5, 4.0, bz + D * 0.5), Color(1.2, 1.2, 1.2))
	box(CONCRETE, Vector3(bx - W * 0.5 - 0.15, 4.0, bz - D * 0.5 - 0.15), Vector3(bx + W * 0.5 + 0.15, 4.3, bz + D * 0.5 + 0.15), Color(1.35, 1.35, 1.35))
	box(GRAVEL, Vector3(bx - W * 0.5, 4.3, bz - D * 0.5), Vector3(bx + W * 0.5, 4.34, bz + D * 0.5), Color(0.9, 0.9, 0.9))
	for k in range(7):   # panel joints on the front
		box(TRIM, Vector3(bx - W * 0.5 + 0.7 + k * 1.6 - 0.03, 0.4, bz + D * 0.5), Vector3(bx - W * 0.5 + 0.7 + k * 1.6 + 0.03, 3.9, bz + D * 0.5 + 0.03), ink)
	box(TRIM, Vector3(bx - W * 0.5, 3.0, bz + D * 0.5), Vector3(bx + W * 0.5, 3.15, bz + D * 0.5 + 0.06), ink)
	# the screen wall: a band of lit panels, each a different brightness, between mullions
	var z0 := bz + D * 0.5
	for k in range(8):
		var x0 := bx - W * 0.5 + 0.4 + k * 1.3
		var tone := 0.55 + rng.randf() * 0.45
		box(GLOW, Vector3(x0, 3.2, z0 + 0.02), Vector3(x0 + 1.1, 3.9, z0 + 0.08), Color(0.5 * tone + 0.35, 0.8 * tone + 0.15, 1.0))
	for k in range(9):
		box(STEEL, Vector3(bx - W * 0.5 + 0.35 + k * 1.3, 3.15, z0), Vector3(bx - W * 0.5 + 0.45 + k * 1.3, 3.95, z0 + 0.1), bright)
	# the blast door in a recess, with hazard stripes and a lamp
	box(TRIM, Vector3(-1.1, 0.1, z0), Vector3(1.1, 2.6, z0 + 0.06), ink)
	box(PANEL, Vector3(-0.95, 0.1, z0 + 0.06), Vector3(0.95, 2.4, z0 + 0.14), Color(1.45, 1.45, 1.5))
	for k in range(5):
		box(TRIM, Vector3(-0.85 + k * 0.38, 0.15, z0 + 0.15), Vector3(-0.7 + k * 0.38, 2.3, z0 + 0.16), haz if k % 2 == 0 else ink)
	box(GLOWW, Vector3(-0.2, 2.7, z0 + 0.04), Vector3(0.2, 2.8, z0 + 0.12), warm)
	box(CONCRETE, Vector3(-1.4, 0.1, z0 + 0.1), Vector3(1.4, 0.22, z0 + 1.1), Color(1.3, 1.3, 1.3))
	# earth banked against the sides and back
	for sx in [-1.0, 1.0]:
		dome(PLASTER, Vector3(sx * (W * 0.5 + 0.1), 0.1, bz), 2.2, 2.0, Color("3f6e3c"), 12, 4)
	dome(PLASTER, Vector3(0, 0.1, bz - D * 0.5 - 0.3), 4.2, 2.0, Color("3f6e3c"), 16, 4)
	# ---- the roof: a big radome, two small ones, three dishes of different size, a sensor mast and a cable tray
	radome(Vector3(-3.6, 4.34, bz + 0.2), 1.35)
	radome(Vector3(-0.6, 4.34, bz - 1.2), 0.8)
	radome(Vector3(1.0, 4.34, bz + 1.4), 0.7)
	dish(Vector3(3.4, 4.34, bz - 0.9), 1.1, 0.5, 0.9)
	dish(Vector3(4.9, 4.34, bz + 1.3), 0.8, -0.7, 0.8)
	dish(Vector3(-5.0, 4.34, bz - 1.6), 0.7, 2.4, 0.7)
	lattice(Vector3(1.8, 4.34, bz - 1.9), 6.5, 0.9, 0.35, Color(1.5, 1.5, 1.55))
	for y in [7.2, 8.4, 9.6]:
		bar(STEEL, Vector3(1.0, 4.34 + y - 3.4, bz - 1.9), Vector3(2.6, 4.34 + y - 3.4, bz - 1.9), 0.04, bright)
	bar(STEEL, Vector3(1.8, 4.34 + 6.5, bz - 1.9), Vector3(1.8, 4.34 + 7.8, bz - 1.9), 0.03, bright)
	box(GLOWR, Vector3(1.7, 4.34 + 7.8, bz - 2.0), Vector3(1.9, 4.34 + 8.0, bz - 1.8), Color(1.0, 0.4, 0.35))
	box(METAL, Vector3(-2.0, 4.34, bz + 1.6), Vector3(0.2, 4.9, bz + 2.2), Color(1.3, 1.35, 1.4))      # the cable tray
	for k in range(2):
		fan(Vector3(5.2 - k * 1.5, 4.9, bz - 1.4 + 0.0), 0.35)
	# ---- the communications yard on the left: three containers with antennas, a feeder and a generator
	for i in range(3):
		var z := 2.4 + i * 1.5 - 0.0
		box(PANEL, Vector3(-8.2, 0.1, z), Vector3(-5.6, 1.9, z + 1.25), pale if i != 1 else olive * 1.7)
		box(TRIM, Vector3(-8.25, 1.9, z - 0.05), Vector3(-5.55, 2.0, z + 1.3), Color("56646a"))
		box(GLOWG, Vector3(-5.6, 1.4, z + 0.5), Vector3(-5.54, 1.55, z + 0.7), Color(0.6, 1.0, 0.55))
		bar(STEEL, Vector3(-7.4, 2.0, z + 0.6), Vector3(-7.4, 3.6, z + 0.6), 0.03, bright)
		bar(TRIM, Vector3(-7.7, 3.6, z + 0.6), Vector3(-7.1, 3.6, z + 0.6), 0.03, ink)
	pipe(METAL, Vector3(-5.5, 0.4, 3.0), Vector3(-2.2, 0.4, 0.8), 0.07, Color("c83a2e"))
	box(PANEL, Vector3(5.4, 0.1, 3.0), Vector3(8.2, 2.1, 4.8), pale)
	box(TRIM, Vector3(5.3, 2.1, 2.9), Vector3(8.3, 2.22, 4.9), Color("56646a"))
	for k in range(4):
		box(TRIM, Vector3(5.6 + k * 0.65, 0.4, 3.0), Vector3(5.66 + k * 0.65, 1.9, 3.04), ink)
	pipe(METAL, Vector3(7.7, 2.22, 3.6), Vector3(7.7, 3.6, 3.6), 0.12, Color("30383c"))
	cylinder(TRIM, Vector3(7.7, 3.6, 3.6), 0.17, 0.08, ink, 8)
	box(GLOWG, Vector3(5.3, 1.4, 3.8), Vector3(5.34, 1.6, 4.0), Color(0.6, 1.0, 0.55))
	# a command vehicle at the door
	box(TRIM, Vector3(2.0, 0.35, 4.6), Vector3(4.8, 1.9, 5.8), Color("4c5a38"))
	box(TRIM, Vector3(4.8, 0.35, 4.6), Vector3(5.7, 1.4, 5.8), Color("55633f"))
	box(GLASS, Vector3(5.7, 0.9, 4.7), Vector3(5.74, 1.35, 5.7), Color("1c2d36"))
	for wx in [2.8, 4.0, 5.2]:
		for wz in [4.55, 5.85]:
			box(TRIM, Vector3(wx - 0.3, 0.1, wz - 0.1), Vector3(wx + 0.3, 0.7, wz + 0.1), Color("1a1c1e"))
	bar(STEEL, Vector3(3.4, 1.9, 5.2), Vector3(3.4, 3.0, 5.2), 0.03, bright)
	dish(Vector3(2.6, 1.9, 5.2), 0.35, 0.3, 0.7)
	# a guard booth and a barrier at the gate, floodlights, a perimeter fence leaning outward, and trees
	box(PANEL, Vector3(-3.6, 0.1, 6.0), Vector3(-2.2, 2.4, 7.2), pale)
	box(TRIM, Vector3(-3.7, 2.4, 5.9), Vector3(-2.1, 2.52, 7.3), Color("56646a"))
	box(GLASS, Vector3(-3.5, 1.1, 7.2), Vector3(-2.3, 2.2, 7.24), Color("2f5568"))
	bar(TRIM, Vector3(-2.2, 1.0, 6.6), Vector3(-0.2, 1.0, 6.6), 0.05, bright)
	for k in range(4):
		box(TRIM, Vector3(-2.2 + k * 0.5, 0.95, 6.55), Vector3(-1.95 + k * 0.5, 1.05, 6.65), Color("c83a2e") if k % 2 == 0 else Color("f0eee4"))
	for p in [Vector3(-8.6, 0, 5.4), Vector3(8.6, 0, 5.4), Vector3(8.6, 0, -4.4), Vector3(-8.6, 0, -4.4), Vector3(0.0, 0, 8.4)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.2, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.4, 5.15, -0.15), p + Vector3(0.4, 5.25, 0.15), warm)
	for i in range(22):
		var a := TAU * i / 22.0
		var fp := Vector3(cos(a) * 11.0, 0.1, sin(a) * 11.0)
		if absf(fp.x) < 10.0 and absf(fp.z) < 11.5 - absf(fp.x) * 0.577:
			if fp.z > 6.0 and absf(fp.x) < 3.4:
				continue
			bar(STEEL, fp, fp + Vector3(0, 1.8, 0), 0.03, bright)
			bar(STEEL, fp + Vector3(0, 1.8, 0), fp + Vector3(fp.x * 0.03, 2.1, fp.z * 0.03), 0.02, bright)
	for t in [Vector3(-9.2, 0, -6.2), Vector3(9.2, 0, -6.0)]:
		cylinder(WOOD, t + Vector3(0, 0.1, 0), 0.2, 1.5, Color("6a5038"), 7, 0.13)
		dome(PLASTER, t + Vector3(0, 1.3, 0), 1.1, 1.1, Color("3f6e3c"), 10, 4)
	xf = origin

## A missile lying on its cradle along +x from `a`: a pale body with a dark band, a red nose and three tail fins.
func missile_lying(a: Vector3, length: float, r: float) -> void:
	var ink := Color("1d252a")
	pipe(METAL, a, a + Vector3(length, 0, 0), r, Color(1.5, 1.5, 1.52), 14)
	pipe(TRIM, a + Vector3(length * 0.55, 0, 0), a + Vector3(length * 0.55 + 0.35, 0, 0), r * 1.02, ink, 14)
	pipe(TRIM, a + Vector3(length * 0.3, 0, 0), a + Vector3(length * 0.3 + 0.15, 0, 0), r * 1.02, Color("c0392b"), 14)
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.BACK, -PI * 0.5), a + Vector3(length, 0, 0))
	cylinder(TRIM, Vector3.ZERO, r, r * 3.2, Color("5d6468"), 14, 0.03)
	xf = saved
	for k in range(3):
		var ang := TAU * k / 3.0
		box(TRIM, a + Vector3(0.05, sin(ang) * r - 0.02, cos(ang) * r - 0.02), a + Vector3(0.7, sin(ang) * (r + 0.28) + 0.02, cos(ang) * (r + 0.28) + 0.02), Color("5d6468"))

## An earth-covered magazine: a concrete barrel vault with a planted earth cover, a concrete headwall with a blast
## door, a hazard stripe and a number plate, vents and a drain, facing +z. `c` is the middle of its front.
func magazine(c: Vector3, hw: float, hl: float, number: int) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	var h0 := 1.2
	var rise := hw * 0.85
	box(CONCRETE, c + Vector3(-hw - 0.1, 0.0, -hl * 2.0), c + Vector3(hw + 0.1, h0, 0.0), Color(1.25, 1.25, 1.25))
	for s in range(10):
		var a0 := -PI * 0.5 + PI * s / 10.0
		var a1 := -PI * 0.5 + PI * (s + 1) / 10.0
		var x0 := hw * sin(a0)
		var x1 := hw * sin(a1)
		var y0 := h0 + rise * cos(a0)
		var y1 := h0 + rise * cos(a1)
		var e0 := (hw + 0.45) * sin(a0)
		var e1 := (hw + 0.45) * sin(a1)
		var ey0 := h0 + (rise + 0.45) * cos(a0)
		var ey1 := h0 + (rise + 0.45) * cos(a1)
		var z1 := c.z
		var z0 := c.z - hl * 2.0
		quad(CONCRETE, c + Vector3(x0, y0, 0), c + Vector3(x1, y1, 0), c + Vector3(x1, y1, z0 - c.z), c + Vector3(x0, y0, z0 - c.z), Color(1.25, 1.25, 1.25))
		quad(PLASTER, c + Vector3(e0, ey0, -0.25), c + Vector3(e1, ey1, -0.25), c + Vector3(e1, ey1, z0 - c.z), c + Vector3(e0, ey0, z0 - c.z), Color("4a7a42") if s % 2 == 0 else Color("42703c"))
	# the headwall: a concrete face with the arch cut out and a recessed steel door
	box(CONCRETE, c + Vector3(-hw - 0.45, 0.0, -0.25), c + Vector3(-hw + 0.5, h0 + rise * 0.6, 0.12), Color(1.35, 1.35, 1.35))
	box(CONCRETE, c + Vector3(hw - 0.5, 0.0, -0.25), c + Vector3(hw + 0.45, h0 + rise * 0.6, 0.12), Color(1.35, 1.35, 1.35))
	box(CONCRETE, c + Vector3(-hw - 0.45, h0 + rise * 0.6, -0.25), c + Vector3(hw + 0.45, h0 + rise + 0.2, 0.12), Color(1.35, 1.35, 1.35))
	box(TRIM, c + Vector3(-hw + 0.55, 0.0, 0.0), c + Vector3(hw - 0.55, h0 + rise * 0.6, 0.06), ink)
	box(PANEL, c + Vector3(-hw + 0.7, 0.0, 0.06), c + Vector3(hw - 0.7, h0 + rise * 0.55, 0.16), Color(1.4, 1.45, 1.4))
	for k in range(6):
		box(TRIM, c + Vector3(-hw + 0.8 + k * ((hw - 0.8) * 2.0 / 6.0), 0.1, 0.17), c + Vector3(-hw + 0.8 + k * ((hw - 0.8) * 2.0 / 6.0) + 0.16, h0 + rise * 0.5, 0.18), haz if k % 2 == 0 else ink)
	box(STEEL, c + Vector3(-0.04, 0.2, 0.18), c + Vector3(0.04, h0 + rise * 0.45, 0.22), bright)
	box(TRIM, c + Vector3(-0.35, h0 + rise * 0.72, 0.1), c + Vector3(0.35, h0 + rise * 0.72 + 0.4, 0.14), Color(1.6, 1.6, 1.5))
	for k in range(number):
		box(TRIM, c + Vector3(-0.25 + k * 0.2, h0 + rise * 0.72 + 0.08, 0.14), c + Vector3(-0.17 + k * 0.2, h0 + rise * 0.72 + 0.32, 0.16), ink)
	box(GLOWW, c + Vector3(-0.15, h0 + rise * 0.55 + 0.1, 0.0), c + Vector3(0.15, h0 + rise * 0.55 + 0.2, 0.1), Color(1.0, 0.88, 0.65))
	for k in range(2):   # vents on the crown
		pipe(METAL, c + Vector3(-0.8 + k * 1.6, h0 + rise + 0.25, -hl * 1.1), c + Vector3(-0.8 + k * 1.6, h0 + rise + 0.8, -hl * 1.1), 0.12, Color("8a949a"), 8)
		cylinder(TRIM, c + Vector3(-0.8 + k * 1.6, h0 + rise + 0.8, -hl * 1.1), 0.2, 0.06, ink, 8)
	box(CONCRETE, c + Vector3(-hw + 0.3, 0.0, 0.1), c + Vector3(hw - 0.3, 0.12, 1.3), Color(1.3, 1.3, 1.3))   # the doorstep

## An ammunition depot: three earth-covered magazines in a row, a loading apron with a flatbed and a forklift, a
## gantry over pallets of crates, an open shed with three missiles on cradles, a guard tower, gate and fenced yard.
func ammo_depot(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var bright := Color(2.3, 2.3, 2.4)
	var pale := Color(1.5, 1.5, 1.52)
	var olive := Color(0.62, 0.7, 0.55)
	var warm := Color(1.0, 0.88, 0.65)
	var origin := xf
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(GRAVEL, Vector3(-9.2, 0.1, -9.0), Vector3(9.2, 0.14, -2.2), Color(1.1, 1.1, 1.1))
	box(ASPHALT, Vector3(-9.2, 0.1, -2.2), Vector3(9.2, 0.15, 1.2), Color(0.85, 0.85, 0.88))
	box(PAVERS, Vector3(-9.0, 0.1, 1.2), Vector3(9.0, 0.13, 7.2), Color(1.2, 1.2, 1.2))
	box(TRIM, Vector3(-9.2, 0.16, -0.5), Vector3(9.2, 0.17, -0.4), Color(0.95, 0.85, 0.3))
	# ---- the three magazines, set back at z -2.4 with their doors facing the apron
	for i in range(3):
		magazine(Vector3(-6.4 + i * 6.4, 0.1, -2.4), 2.3, 2.8, i + 1)
	# ---- the loading apron: a flatbed with a missile crate, a forklift with a pallet, crates and drums
	box(TRIM, Vector3(-8.2, 0.55, -1.6), Vector3(-4.6, 0.7, -0.5), Color("3a464c"))
	box(TRIM, Vector3(-4.6, 0.4, -1.6), Vector3(-3.5, 1.9, -0.5), Color("4c5a38"))
	box(GLASS, Vector3(-3.5, 1.2, -1.5), Vector3(-3.46, 1.8, -0.6), Color("1c2d36"))
	for wx in [-7.4, -6.4, -3.9]:
		for wz in [-1.7, -0.4]:
			box(TRIM, Vector3(wx - 0.3, 0.1, wz - 0.1), Vector3(wx + 0.3, 0.7, wz + 0.1), Color("1a1c1e"))
	box(WOOD, Vector3(-8.0, 0.7, -1.5), Vector3(-5.2, 1.45, -0.6), Color("6a5a3a"))
	for k in range(5):
		box(TRIM, Vector3(-7.9 + k * 0.6, 0.7, -0.62), Vector3(-7.84 + k * 0.6, 1.45, -0.58), Color("3a301e"))
	box(TRIM, Vector3(0.6, 0.35, 0.2), Vector3(2.0, 0.55, 1.1), Color("c9972a"))
	box(TRIM, Vector3(2.0, 0.15, 0.25), Vector3(2.9, 0.22, 0.2 + 0.85), Color("8a949a"))
	bar(STEEL, Vector3(2.9, 0.2, 0.25), Vector3(2.9, 1.9, 0.25), 0.04, bright)
	bar(STEEL, Vector3(2.9, 0.2, 1.05), Vector3(2.9, 1.9, 1.05), 0.04, bright)
	box(WOOD, Vector3(3.0, 0.2, 0.2), Vector3(3.9, 0.35, 1.1), Color("8a6a3a"))
	box(PANEL, Vector3(3.1, 0.35, 0.3), Vector3(3.8, 1.0, 1.0), olive * 1.7)
	pipe(METAL, Vector3(0.9, 0.55, 0.65), Vector3(0.9, 1.7, 0.65), 0.05, Color("3a464c"))
	for k in range(3):
		var cx := -2.4 + k * 1.1
		cylinder(METAL, Vector3(cx, 0.15, 3.0), 0.32, 0.9, Color("5d6a4a") * 1.5, 10)
		cylinder(TRIM, Vector3(cx, 1.05, 3.0), 0.33, 0.05, ink, 10)
	for st in range(3):
		var sx := -8.2 + st * 1.6
		for layer in range(2 - st % 2):
			box(WOOD, Vector3(sx, 0.13 + layer * 0.7, 3.0), Vector3(sx + 1.3, 0.13 + layer * 0.7 + 0.65, 4.0), Color("7a6a42") if (st + layer) % 2 == 0 else olive * 1.5)
			box(TRIM, Vector3(sx + 0.05, 0.13 + layer * 0.7 + 0.3, 4.0), Vector3(sx + 1.25, 0.13 + layer * 0.7 + 0.36, 4.02), haz)
	# ---- a gantry crane over a pallet row on the left of the yard
	for gz in [4.6, 6.2]:
		bar(TRIM, Vector3(-8.8, 0.13, gz), Vector3(-8.8, 4.2, gz), 0.12, Color("c8902a"))
		bar(TRIM, Vector3(-4.4, 0.13, gz), Vector3(-4.4, 4.2, gz), 0.12, Color("c8902a"))
		bar(TRIM, Vector3(-8.8, 4.2, gz), Vector3(-4.4, 4.2, gz), 0.12, Color("c8902a"))
	bar(TRIM, Vector3(-8.8, 4.2, 4.6), Vector3(-8.8, 4.2, 6.2), 0.1, Color("c8902a"))
	bar(TRIM, Vector3(-4.4, 4.2, 4.6), Vector3(-4.4, 4.2, 6.2), 0.1, Color("c8902a"))
	box(TRIM, Vector3(-7.0, 3.9, 5.1), Vector3(-6.2, 4.4, 5.7), ink)
	bar(TRIM, Vector3(-6.6, 3.9, 5.4), Vector3(-6.6, 2.0, 5.4), 0.02, ink)
	box(TRIM, Vector3(-6.9, 1.8, 5.2), Vector3(-6.3, 2.0, 5.6), ink)
	for k in range(3):
		box(WOOD, Vector3(-8.2 + k * 1.4, 0.13, 5.1), Vector3(-7.2 + k * 1.4, 1.0, 5.7), Color("7a6a42") if k != 1 else olive * 1.5)
	# ---- the open missile shed on the right: a flat roof on posts, three missiles on cradles under it
	var shed := xf
	box(PANEL, Vector3(2.8, 3.4, 4.0), Vector3(8.8, 3.6, 7.0), pale)
	box(TRIM, Vector3(2.7, 3.6, 3.9), Vector3(8.9, 3.7, 7.1), Color("56646a"))
	for px in [3.0, 5.8, 8.6]:
		for pz in [4.2, 6.8]:
			bar(STEEL, Vector3(px, 0.13, pz), Vector3(px, 3.4, pz), 0.07, bright)
	for k in range(3):
		var mz := 4.7 + k * 0.9
		for cx in [3.8, 7.6]:
			box(TRIM, Vector3(cx - 0.1, 0.13, mz - 0.4), Vector3(cx + 0.1, 0.55, mz + 0.4), Color("5a5d60"))
		missile_lying(Vector3(3.2, 0.85, mz), 5.2 - (0.4 if k == 1 else 0.0), 0.28)
	box(GLOWW, Vector3(3.2, 3.35, 5.0), Vector3(8.4, 3.4, 5.1), warm)
	box(GLOWW, Vector3(3.2, 3.35, 6.5), Vector3(8.4, 3.4, 6.6), warm)
	# ---- a guard tower with a roofed cab, the gate with a barrier, floodlights, warning plates and the perimeter fence
	lattice(Vector3(8.4, 0.1, -3.4), 5.0, 1.3, 1.0, Color(1.4, 1.4, 1.45))
	box(PANEL, Vector3(7.7, 5.0, -4.1), Vector3(9.1, 6.3, -2.7), pale)
	box(GLASS, Vector3(7.75, 5.3, -2.72), Vector3(9.05, 6.1, -2.68), Color("2f5568"))
	box(TRIM, Vector3(7.5, 6.3, -4.3), Vector3(9.3, 6.45, -2.5), Color("56646a"))
	box(GLOWW, Vector3(8.2, 6.15, -2.5), Vector3(8.6, 6.25, -2.4), warm)
	box(PANEL, Vector3(-0.8, 0.13, 7.6), Vector3(0.8, 2.4, 8.8), pale)
	box(TRIM, Vector3(-0.9, 2.4, 7.5), Vector3(0.9, 2.52, 8.9), Color("56646a"))
	box(GLASS, Vector3(-0.7, 1.1, 8.8), Vector3(0.7, 2.2, 8.84), Color("2f5568"))
	bar(TRIM, Vector3(0.9, 1.0, 8.2), Vector3(2.8, 1.0, 8.2), 0.05, bright)
	for k in range(4):
		box(TRIM, Vector3(0.9 + k * 0.48, 0.95, 8.15), Vector3(1.15 + k * 0.48, 1.05, 8.25), Color("c83a2e") if k % 2 == 0 else Color("f0eee4"))
	for p in [Vector3(-9.0, 0, 6.0), Vector3(9.0, 0, 5.4), Vector3(-9.0, 0, -4.8), Vector3(9.0, 0, -7.0), Vector3(-3.2, 0, -8.6), Vector3(3.2, 0, -8.6)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.4, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.4, 5.35, -0.15), p + Vector3(0.4, 5.45, 0.15), warm)
	for i in range(22):
		var a := TAU * i / 22.0
		var fp := Vector3(cos(a) * 11.0, 0.1, sin(a) * 11.0)
		if absf(fp.x) < 10.0 and absf(fp.z) < 11.5 - absf(fp.x) * 0.577:
			if fp.z > 6.0 and absf(fp.x) < 3.4:
				continue
			bar(STEEL, fp, fp + Vector3(0, 1.8, 0), 0.03, bright)
			bar(STEEL, fp + Vector3(0, 1.8, 0), fp + Vector3(fp.x * 0.03, 2.1, fp.z * 0.03), 0.02, bright)
			if i % 4 == 0:
				box(TRIM, fp + Vector3(-0.3, 1.0, -0.02), fp + Vector3(0.3, 1.5, 0.02), haz)
	banner(-9.0, 4.4, 7.4, 1.8)
	xf = origin

## A radiation warning plate on a wall facing +z at `c`: a yellow disc with three dark blades and a dark hub.
func trefoil(c: Vector3, r: float) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c)
	cylinder(TRIM, Vector3(0, -0.03, 0), r, 0.03, haz, 24)
	for k in range(3):
		var a := TAU * k / 3.0 + PI / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		for w in range(5):
			var f := 0.38 + w * 0.12
			cylinder(TRIM, d * r * f * 0.75 + Vector3(0, -0.015, 0), r * 0.16, 0.03, ink, 8)
	cylinder(TRIM, Vector3(0, -0.015, 0), r * 0.12, 0.03, ink, 10)
	xf = saved

## A tall brick-free concrete vent stack with red and white bands and a beacon, base at c.
func vent_stack(c: Vector3, h: float, r: float) -> void:
	var rings := 8
	for i in range(rings):
		var f0 := float(i) / rings
		var f1 := float(i + 1) / rings
		var r0 := r * (1.0 - 0.3 * f0)
		var r1 := r * (1.0 - 0.3 * f1)
		var col := Color("c0392b") if i % 2 == 1 and i > 2 else Color(1.45, 1.45, 1.48)
		cylinder(CONCRETE if col.r < 1.0 else PANEL, c + Vector3(0, f0 * h, 0), r0, h / rings, col, 14, r1)
	cylinder(TRIM, c + Vector3(0, h, 0), r * 0.74, 0.12, Color("1d252a"), 14)
	cylinder(GLOWR, c + Vector3(0, h + 0.12, 0), 0.12, 0.2, Color(1.0, 0.4, 0.35), 8)
	for y in [h * 0.45, h * 0.8]:   # a service ladder cage down one side
		bar(STEEL, c + Vector3(r * 0.9, y, 0), c + Vector3(r * 0.9, y + 0.8, 0), 0.03, Color(2.3, 2.3, 2.4))

## A watch tower: a lattice, a glass cab under a deep roof, a searchlight and a ladder.
func watch_tower(c: Vector3, h: float) -> void:
	var pale := Color(1.5, 1.5, 1.52)
	var warm := Color(1.0, 0.88, 0.65)
	lattice(c, h, 1.5, 1.1, Color(1.4, 1.4, 1.45))
	box(PANEL, c + Vector3(-0.9, h, -0.9), c + Vector3(0.9, h + 1.3, 0.9), pale)
	box(GLASS, c + Vector3(-0.85, h + 0.3, 0.9), c + Vector3(0.85, h + 1.1, 0.94), Color("2f5568"))
	box(GLASS, c + Vector3(0.9, h + 0.3, -0.85), c + Vector3(0.94, h + 1.1, 0.85), Color("2f5568"))
	box(TRIM, c + Vector3(-1.2, h + 1.3, -1.2), c + Vector3(1.2, h + 1.45, 1.2), Color("3a464c"))
	box(GLOWW, c + Vector3(-0.2, h + 1.15, 1.2), c + Vector3(0.2, h + 1.3, 1.4), warm)
	bar(STEEL, c + Vector3(0, h + 1.45, 0), c + Vector3(0, h + 2.3, 0), 0.03, Color(2.3, 2.3, 2.4))

## The strategic weapons complex: a hardened assembly hall with a ribbed roof, lit clerestory and a sliding door, three
## earth-covered storage bays, a vent stack and filter plant, a transporter on the apron, and a double fence with
## watch towers and a guarded gate.
func strategic_complex(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var bright := Color(2.3, 2.3, 2.4)
	var pale := Color(1.5, 1.5, 1.52)
	var warm := Color(1.0, 0.88, 0.65)
	var cyan := Color(0.75, 0.92, 1.0)
	var origin := xf
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(GRAVEL, Vector3(-9.2, 0.1, -9.0), Vector3(9.2, 0.14, -4.0), Color(1.1, 1.1, 1.1))
	box(ASPHALT, Vector3(-9.2, 0.1, -4.0), Vector3(9.2, 0.15, 2.2), Color(0.85, 0.85, 0.88))
	box(PAVERS, Vector3(-9.0, 0.1, 2.2), Vector3(9.0, 0.13, 7.4), Color(1.2, 1.2, 1.2))
	box(TRIM, Vector3(-9.2, 0.16, -1.0), Vector3(9.2, 0.17, -0.94), Color(0.95, 0.85, 0.3))
	# ---- the assembly hall: 11 x 4.6, 5.4 high, panel joints, a dark band, a ribbed roof with lit clerestory slits
	var hx := 0.0
	var hz := -6.5
	var W := 11.0
	var D := 4.6
	var H := 5.4
	box(CONCRETE, Vector3(hx - W * 0.5, 0.1, hz - D * 0.5), Vector3(hx + W * 0.5, H, hz + D * 0.5), Color(1.3, 1.3, 1.3))
	box(TRIM, Vector3(hx - W * 0.5 - 0.05, 3.1, hz - D * 0.5 - 0.05), Vector3(hx + W * 0.5 + 0.05, 3.3, hz + D * 0.5 + 0.05), ink)
	for k in range(7):
		var jx := hx - W * 0.5 + 0.7 + k * 1.6
		box(TRIM, Vector3(jx - 0.03, 0.4, hz + D * 0.5), Vector3(jx + 0.03, 3.1, hz + D * 0.5 + 0.03), ink)
	box(CONCRETE, Vector3(hx - W * 0.5 - 0.2, H, hz - D * 0.5 - 0.2), Vector3(hx + W * 0.5 + 0.2, H + 0.35, hz + D * 0.5 + 0.2), Color(1.4, 1.4, 1.4))
	for k in range(3):   # ribbed roof
		var z0 := hz - D * 0.5 + k * D / 3.0
		var z1 := z0 + D / 3.0
		quad(PANEL, Vector3(hx - W * 0.5, H + 0.35, z0), Vector3(hx + W * 0.5, H + 0.35, z0), Vector3(hx + W * 0.5, H + 1.2, z1 - 0.05), Vector3(hx - W * 0.5, H + 1.2, z1 - 0.05), Color(1.4, 1.4, 1.45))
		quad(GLOW, Vector3(hx + W * 0.5 - 0.3, H + 0.4, z1), Vector3(hx - W * 0.5 + 0.3, H + 0.4, z1), Vector3(hx - W * 0.5 + 0.3, H + 1.15, z1 - 0.04), Vector3(hx + W * 0.5 - 0.3, H + 1.15, z1 - 0.04), cyan)
	for k in range(3):
		fan(Vector3(-3.6 + k * 3.6, H + 0.4, hz - 1.0), 0.45)
	# the sliding door: a recessed opening with a tall leaf, rails and hazard stripes, a lit canopy over it
	var fz := hz + D * 0.5
	box(TRIM, Vector3(-2.2, 0.1, fz), Vector3(2.2, 4.4, fz + 0.06), ink)
	box(PANEL, Vector3(-2.1, 0.1, fz + 0.06), Vector3(0.1, 4.3, fz + 0.16), Color(1.45, 1.45, 1.5))
	for k in range(6):
		box(TRIM, Vector3(-2.0 + k * 0.35, 0.15, fz + 0.17), Vector3(-1.85 + k * 0.35, 4.2, fz + 0.18), haz if k % 2 == 0 else ink)
	bar(STEEL, Vector3(-2.4, 4.5, fz + 0.2), Vector3(2.8, 4.5, fz + 0.2), 0.06, bright)
	box(CONCRETE, Vector3(-2.6, 4.5, fz), Vector3(2.6, 4.7, fz + 1.2), Color(1.35, 1.35, 1.35))
	box(GLOWW, Vector3(-2.3, 4.45, fz + 0.3), Vector3(2.3, 4.5, fz + 0.4), warm)
	trefoil(Vector3(4.0, 3.9, fz + 0.04), 0.65)
	for sx in [-1.0, 1.0]:   # side wings with louvres and filter boxes
		box(PANEL, Vector3(sx * 6.4 - 0.9, 0.1, hz - 1.4), Vector3(sx * 6.4 + 0.9, 3.2, hz + 1.4), pale)
		box(TRIM, Vector3(sx * 6.4 - 1.0, 3.2, hz - 1.5), Vector3(sx * 6.4 + 1.0, 3.35, hz + 1.5), Color("56646a"))
	vent_stack(Vector3(7.8, 0.1, -8.4), 12.5, 0.75)
	for k in range(3):
		box(PANEL, Vector3(5.8 + k * 0.9 - 0.4, H + 0.35, hz - 1.9), Vector3(5.8 + k * 0.9 + 0.4, H + 1.6, hz - 0.9), Color(1.4, 1.4, 1.45))
	pipe(METAL, Vector3(5.8, H + 1.2, hz - 1.4), Vector3(7.8, 9.0, -8.4), 0.12, Color("30383c"))
	# ---- three storage bays at the front of the hall, each an earth-covered magazine
	for i in range(3):
		magazine(Vector3(-6.4 + i * 6.4, 0.1, 0.2), 1.9, 1.7, i + 1)
	# ---- the transporter on the apron: a trailer carrying a canister, and a tractor unit
	box(TRIM, Vector3(-8.4, 0.5, 3.2), Vector3(-3.0, 0.7, 4.4), Color("3a464c"))
	pipe(METAL, Vector3(-8.0, 1.2, 3.8), Vector3(-3.6, 1.2, 3.8), 0.5, Color(1.5, 1.5, 1.52), 14)
	pipe(TRIM, Vector3(-6.4, 1.2, 3.8), Vector3(-6.2, 1.2, 3.8), 0.52, haz, 14)
	pipe(TRIM, Vector3(-4.6, 1.2, 3.8), Vector3(-4.4, 1.2, 3.8), 0.52, haz, 14)
	box(TRIM, Vector3(-3.0, 0.4, 3.1), Vector3(-1.7, 2.2, 4.5), Color("4c5a38"))
	box(GLASS, Vector3(-1.7, 1.4, 3.2), Vector3(-1.66, 2.1, 4.4), Color("1c2d36"))
	for wx in [-7.6, -6.6, -5.6, -2.5]:
		for wz in [3.1, 4.5]:
			box(TRIM, Vector3(wx - 0.35, 0.1, wz - 0.1), Vector3(wx + 0.35, 0.8, wz + 0.1), Color("1a1c1e"))
	box(GLOWR, Vector3(-2.0, 2.2, 3.5), Vector3(-1.8, 2.34, 4.1), Color(1.0, 0.4, 0.35))
	# a gantry crane over a loading bay on the right
	for gz in [3.0, 5.2]:
		bar(TRIM, Vector3(3.2, 0.13, gz), Vector3(3.2, 4.4, gz), 0.12, Color("c8902a"))
		bar(TRIM, Vector3(7.6, 0.13, gz), Vector3(7.6, 4.4, gz), 0.12, Color("c8902a"))
		bar(TRIM, Vector3(3.2, 4.4, gz), Vector3(7.6, 4.4, gz), 0.12, Color("c8902a"))
	bar(TRIM, Vector3(3.2, 4.4, 3.0), Vector3(3.2, 4.4, 5.2), 0.1, Color("c8902a"))
	bar(TRIM, Vector3(7.6, 4.4, 3.0), Vector3(7.6, 4.4, 5.2), 0.1, Color("c8902a"))
	box(TRIM, Vector3(5.0, 4.1, 3.6), Vector3(5.8, 4.6, 4.6), ink)
	bar(TRIM, Vector3(5.4, 4.1, 4.1), Vector3(5.4, 2.0, 4.1), 0.02, ink)
	box(TRIM, Vector3(5.1, 1.8, 3.9), Vector3(5.7, 2.0, 4.3), ink)
	for k in range(2):
		box(PANEL, Vector3(4.2 + k * 2.2, 0.13, 3.6), Vector3(5.2 + k * 2.2, 0.9, 4.6), Color(0.7, 0.75, 0.65) * 1.7)
	# ---- the gate house with a barrier, floodlights, watch towers and a double perimeter fence
	box(PANEL, Vector3(-0.9, 0.13, 6.6), Vector3(0.9, 2.5, 7.8), pale)
	box(TRIM, Vector3(-1.0, 2.5, 6.5), Vector3(1.0, 2.62, 7.9), Color("56646a"))
	box(GLASS, Vector3(-0.8, 1.1, 7.8), Vector3(0.8, 2.3, 7.84), Color("2f5568"))
	bar(TRIM, Vector3(1.0, 1.0, 7.2), Vector3(3.2, 1.0, 7.2), 0.05, bright)
	for k in range(4):
		box(TRIM, Vector3(1.0 + k * 0.55, 0.95, 7.15), Vector3(1.28 + k * 0.55, 1.05, 7.25), Color("c83a2e") if k % 2 == 0 else Color("f0eee4"))
	trefoil(Vector3(-0.0, 2.9, 7.9), 0.4)
	watch_tower(Vector3(-8.8, 0.1, -5.0), 5.2)
	watch_tower(Vector3(8.8, 0.1, -5.0), 5.2)
	watch_tower(Vector3(-8.0, 0.1, 6.0), 5.2)
	watch_tower(Vector3(8.0, 0.1, 6.0), 5.2)
	for p in [Vector3(-3.6, 0, 2.0), Vector3(3.6, 0, 2.0), Vector3(-9.0, 0, 0.0), Vector3(9.0, 0, 0.0)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.4, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.4, 5.35, -0.15), p + Vector3(0.4, 5.45, 0.15), warm)
	for ring in [10.2, 11.4]:
		for i in range(30):
			var a := TAU * i / 30.0
			var fp := Vector3(cos(a) * ring, 0.1, sin(a) * ring)
			if absf(fp.x) < 10.1 and absf(fp.z) < 11.4 - absf(fp.x) * 0.577:
				if fp.z > 5.0 and absf(fp.x) < 3.6:
					continue
				bar(STEEL, fp, fp + Vector3(0, 2.0 if ring > 11.0 else 1.6, 0), 0.03, bright)
				if i % 5 == 0:
					box(TRIM, fp + Vector3(-0.3, 1.0, -0.02), fp + Vector3(0.3, 1.5, 0.02), haz)
	banner(-9.0, 4.4, 7.2, 1.8)
	xf = origin

## A biohazard sign on a wall facing +z at `c`: a yellow disc with a dark hub and three dark rings round it.
func biohazard(c: Vector3, r: float) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c)
	cylinder(TRIM, Vector3(0, -0.03, 0), r, 0.03, haz, 24)
	for k in range(3):
		var a := TAU * k / 3.0 + PI / 2.0
		var d := Vector3(cos(a), 0, sin(a)) * r * 0.5
		cylinder(TRIM, d + Vector3(0, -0.015, 0), r * 0.36, 0.03, ink, 16)
		cylinder(TRIM, d + Vector3(0, -0.005, 0), r * 0.24, 0.03, haz, 16)
	cylinder(TRIM, Vector3(0, -0.012, 0), r * 0.14, 0.03, ink, 12)
	xf = saved

## The special weapons laboratory: a sealed, windowless containment block with a lit observation corridor, an airlock
## with hazard doors, HEPA filter boxes and exhaust stacks on the roof, effluent decontamination tanks, cold-storage
## containers, a decontamination trailer, and a double fence with a guarded gate.
func special_lab(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var light := Color("dfe4e6")
	var bright := Color(2.3, 2.3, 2.4)
	var pale := Color(1.55, 1.55, 1.58)
	var warm := Color(1.0, 0.88, 0.65)
	var cyan := Color(0.75, 0.92, 1.0)
	var teal := Color("2f6f7e")
	var origin := xf
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(PAVERS, Vector3(-9.2, 0.1, -9.0), Vector3(9.2, 0.13, 7.6), Color(1.25, 1.25, 1.25))
	box(ASPHALT, Vector3(-1.4, 0.13, 1.5), Vector3(1.4, 0.16, 9.4), Color(0.85, 0.85, 0.88))
	# ---- the containment block: 10.4 x 5, 4.4 high, pale panels, a teal band, narrow lit slits, a dark parapet
	var hx := -0.4
	var hz := -5.6
	var W := 10.4
	var D := 5.0
	var H := 4.4
	box(CONCRETE, Vector3(hx - W * 0.5 - 0.1, 0.1, hz - D * 0.5 - 0.1), Vector3(hx + W * 0.5 + 0.1, 0.7, hz + D * 0.5 + 0.1), Color(1.25, 1.25, 1.25))
	box(PANEL, Vector3(hx - W * 0.5, 0.7, hz - D * 0.5), Vector3(hx + W * 0.5, H, hz + D * 0.5), pale)
	box(TRIM, Vector3(hx - W * 0.5 - 0.04, 2.5, hz - D * 0.5 - 0.04), Vector3(hx + W * 0.5 + 0.04, 2.9, hz + D * 0.5 + 0.04), teal)
	box(CONCRETE, Vector3(hx - W * 0.5 - 0.15, H, hz - D * 0.5 - 0.15), Vector3(hx + W * 0.5 + 0.15, H + 0.4, hz + D * 0.5 + 0.15), Color(1.4, 1.4, 1.4))
	box(GRAVEL, Vector3(hx - W * 0.5, H + 0.4, hz - D * 0.5), Vector3(hx + W * 0.5, H + 0.44, hz + D * 0.5), Color(0.9, 0.9, 0.9))
	var fz := hz + D * 0.5
	for k in range(8):   # panel joints
		box(TRIM, Vector3(hx - W * 0.5 + 0.6 + k * 1.3 - 0.03, 0.7, fz), Vector3(hx - W * 0.5 + 0.6 + k * 1.3 + 0.03, H, fz + 0.03), Color("8a949a"))
	for k in range(6):   # the narrow lit slits high on the front
		box(GLOW, Vector3(hx - W * 0.5 + 0.7 + k * 1.6, 3.2, fz + 0.02), Vector3(hx - W * 0.5 + 1.8 + k * 1.6, 3.5, fz + 0.07), cyan)
	# the observation corridor: a glass-walled link along the front-left, lit inside
	box(CONCRETE, Vector3(-6.4, 0.1, fz), Vector3(-1.2, 0.3, fz + 1.9), Color(1.25, 1.25, 1.25))
	box(GLASS, Vector3(-6.3, 0.3, fz + 1.8), Vector3(-1.3, 2.4, fz + 1.84), Color("2c4d5c"))
	box(GLASS, Vector3(-6.3, 0.3, fz), Vector3(-6.26, 2.4, fz + 1.8), Color("2c4d5c"))
	for k in range(6):
		bar(STEEL, Vector3(-6.3 + k, 0.3, fz + 1.84), Vector3(-6.3 + k, 2.4, fz + 1.84), 0.04, bright)
	box(TRIM, Vector3(-6.45, 2.4, fz - 0.05), Vector3(-1.15, 2.55, fz + 2.0), Color("56646a"))
	box(GLOW, Vector3(-6.0, 2.3, fz + 0.2), Vector3(-1.6, 2.36, fz + 1.7), warm)
	# the airlock: a small block with a double hazard door, a canopy and signs
	box(PANEL, Vector3(0.6, 0.1, fz), Vector3(3.8, 3.0, fz + 1.9), pale)
	box(TRIM, Vector3(0.5, 3.0, fz - 0.05), Vector3(3.9, 3.15, fz + 2.0), teal)
	box(TRIM, Vector3(1.4, 0.1, fz + 1.9), Vector3(3.0, 2.5, fz + 1.95), ink)
	box(PANEL, Vector3(1.5, 0.1, fz + 1.95), Vector3(2.15, 2.4, fz + 2.03), Color(1.5, 1.5, 1.55))
	box(PANEL, Vector3(2.25, 0.1, fz + 1.95), Vector3(2.9, 2.4, fz + 2.03), Color(1.5, 1.5, 1.55))
	for k in range(4):
		box(TRIM, Vector3(1.55 + k * 0.33, 0.12, fz + 2.04), Vector3(1.65 + k * 0.33, 2.3, fz + 2.05), haz if k % 2 == 0 else ink)
	box(GLOWW, Vector3(2.0, 2.6, fz + 1.9), Vector3(2.4, 2.7, fz + 2.1), warm)
	biohazard(Vector3(2.2, 2.85, fz + 1.92), 0.28)
	biohazard(Vector3(5.2, 3.3, fz + 0.04), 0.7)
	# ---- the roof: three HEPA filter boxes with fans, an air handler, two exhaust stacks and a pipe run
	for k in range(3):
		box(PANEL, Vector3(-3.6 + k * 2.5, H + 0.44, hz - 1.7), Vector3(-2.0 + k * 2.5, H + 1.7, hz - 0.3), Color(1.5, 1.5, 1.55))
		box(TRIM, Vector3(-3.65 + k * 2.5, H + 1.7, hz - 1.75), Vector3(-1.95 + k * 2.5, H + 1.8, hz - 0.25), Color("56646a"))
		fan(Vector3(-2.8 + k * 2.5, H + 1.8, hz - 1.0), 0.5)
	box(PANEL, Vector3(3.6, H + 0.44, hz - 1.8), Vector3(6.6, H + 2.2, hz + 0.2), Color(1.4, 1.45, 1.5))
	box(TRIM, Vector3(3.5, H + 2.2, hz - 1.9), Vector3(6.7, H + 2.3, hz + 0.3), Color("56646a"))
	louvres(3.9, 6.3, H + 0.7, H + 2.0, hz + 0.2, light, ink)
	for k in range(2):
		pipe(METAL, Vector3(-4.2 + k * 0.0, H + 0.44, hz + 1.4 - k * 0.4), Vector3(-4.2, H + 2.6, hz + 1.4 - k * 0.4), 0.14, Color("8a949a"), 10)
		cylinder(TRIM, Vector3(-4.2, H + 2.6, hz + 1.4 - k * 0.4), 0.22, 0.1, ink, 10)
	pipe(METAL, Vector3(-3.8, H + 0.8, hz + 0.6), Vector3(3.5, H + 0.8, hz + 0.6), 0.12, teal, 10)
	vent_stack(Vector3(-8.4, 0.1, -7.6), 9.0, 0.55)
	# ---- effluent decontamination tanks on a bund at the right, piped to the block
	box(CONCRETE, Vector3(5.2, 0.1, -9.0), Vector3(9.2, 0.55, -3.6), Color(1.3, 1.3, 1.3))
	box(PAVERS, Vector3(5.4, 0.55, -8.8), Vector3(9.0, 0.58, -3.8), Color(1.1, 1.1, 1.1))
	for k in range(2):
		var tz := -7.3 + k * 2.4
		cylinder(METAL, Vector3(7.2, 0.58, tz), 0.95, 3.0, Color(1.7, 1.7, 1.75), 16)
		cylinder(TRIM, Vector3(7.2, 3.58, tz), 0.98, 0.06, Color("8a949a"), 16)
		cylinder(TRIM, Vector3(7.2, 3.64, tz), 0.4, 0.12, ink, 10)
		bar(STEEL, Vector3(8.2, 0.58, tz), Vector3(8.2, 3.4, tz), 0.03, bright)
		for y in [1.0, 1.8, 2.6]:
			bar(STEEL, Vector3(8.2, y, tz), Vector3(7.9, y, tz), 0.02, bright)
	pipe(METAL, Vector3(5.6, 1.0, -7.3), Vector3(5.6, 1.0, -4.8), 0.1, Color("c83a2e"), 8)
	pipe(METAL, Vector3(5.6, 1.4, -7.3), Vector3(5.6, 1.4, -4.8), 0.08, teal, 8)
	box(PANEL, Vector3(5.2, 0.58, -4.5), Vector3(6.4, 1.8, -3.9), Color(1.5, 1.5, 1.55))
	box(GLOWG, Vector3(6.4, 1.3, -4.3), Vector3(6.46, 1.5, -4.1), Color(0.6, 1.0, 0.55))
	# ---- cold-storage containers on the left, each with a cooling unit
	for k in range(2):
		var cz := -8.4 + k * 1.6 + 0.0
		box(PANEL, Vector3(-9.0, 0.1, cz), Vector3(-6.2, 2.0, cz + 1.4), Color(1.6, 1.6, 1.62))
		box(TRIM, Vector3(-9.05, 2.0, cz - 0.05), Vector3(-6.15, 2.1, cz + 1.45), Color("56646a"))
		box(GLOWG, Vector3(-6.2, 1.4, cz + 0.5), Vector3(-6.14, 1.55, cz + 0.7), Color(0.6, 1.0, 0.55))
		fan(Vector3(-8.2, 2.1, cz + 0.7), 0.4)
		fan(Vector3(-7.2, 2.1, cz + 0.7), 0.4)
		box(TRIM, Vector3(-9.0, 0.1, cz + 0.2), Vector3(-8.96, 1.9, cz + 1.2), ink)
	# ---- the decontamination trailer near the gate: a white trailer with a shower awning and signs
	box(TRIM, Vector3(4.4, 0.45, 2.2), Vector3(8.0, 0.65, 3.6), Color("3a464c"))
	box(PANEL, Vector3(4.5, 0.65, 2.2), Vector3(7.9, 2.5, 3.6), Color(1.6, 1.6, 1.62))
	box(TRIM, Vector3(4.4, 2.5, 2.1), Vector3(8.0, 2.62, 3.7), Color("56646a"))
	box(TRIM, Vector3(7.0, 0.65, 3.6), Vector3(7.6, 2.2, 3.66), ink)
	box(TRIM, Vector3(6.6, 2.2, 3.6), Vector3(8.0, 2.3, 4.7), teal)
	for px in [6.7, 7.9]:
		bar(STEEL, Vector3(px, 0.1, 4.6), Vector3(px, 2.2, 4.6), 0.04, bright)
	biohazard(Vector3(5.5, 1.6, 3.65), 0.3)
	for wx in [5.0, 7.2]:
		for wz in [2.1, 3.7]:
			box(TRIM, Vector3(wx - 0.3, 0.1, wz - 0.1), Vector3(wx + 0.3, 0.55, wz + 0.1), Color("1a1c1e"))
	# ---- a generator and a fuel tank, the gate house with a barrier, floodlights and the double fence
	box(PANEL, Vector3(-9.0, 0.1, 3.4), Vector3(-6.4, 1.9, 5.0), Color(1.5, 1.5, 1.52))
	box(TRIM, Vector3(-9.1, 1.9, 3.3), Vector3(-6.3, 2.02, 5.1), Color("56646a"))
	for k in range(4):
		box(TRIM, Vector3(-8.7 + k * 0.6, 0.4, 5.0), Vector3(-8.64 + k * 0.6, 1.7, 5.04), ink)
	pipe(METAL, Vector3(-8.5, 2.02, 4.0), Vector3(-8.5, 3.4, 4.0), 0.12, Color("30383c"), 8)
	box(PANEL, Vector3(-4.2, 0.1, 6.6), Vector3(-2.6, 2.4, 7.8), Color(1.5, 1.5, 1.52))
	box(TRIM, Vector3(-4.3, 2.4, 6.5), Vector3(-2.5, 2.52, 7.9), Color("56646a"))
	box(GLASS, Vector3(-4.1, 1.1, 7.8), Vector3(-2.7, 2.2, 7.84), Color("2f5568"))
	bar(TRIM, Vector3(-2.6, 1.0, 7.2), Vector3(-1.4, 1.0, 7.2), 0.05, bright)
	for k in range(3):
		box(TRIM, Vector3(-2.6 + k * 0.4, 0.95, 7.15), Vector3(-2.4 + k * 0.4, 1.05, 7.25), Color("c83a2e") if k % 2 == 0 else Color("f0eee4"))
	for p in [Vector3(-9.0, 0, 1.0), Vector3(9.0, 0, 1.0), Vector3(9.0, 0, -9.0), Vector3(-3.0, 0, 8.4), Vector3(3.0, 0, 8.4)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.2, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.4, 5.15, -0.15), p + Vector3(0.4, 5.25, 0.15), warm)
	for ring in [10.2, 11.4]:
		for i in range(30):
			var a := TAU * i / 30.0
			var fp := Vector3(cos(a) * ring, 0.1, sin(a) * ring)
			if absf(fp.x) < 10.1 and absf(fp.z) < 11.4 - absf(fp.x) * 0.577:
				if fp.z > 5.0 and absf(fp.x) < 3.4:
					continue
				bar(STEEL, fp, fp + Vector3(0, 2.0 if ring > 11.0 else 1.6, 0), 0.03, bright)
				if i % 5 == 0:
					box(TRIM, fp + Vector3(-0.3, 1.0, -0.02), fp + Vector3(0.3, 1.5, 0.02), haz)
	banner(-9.0, 4.4, 6.4, 1.8)
	xf = origin

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

## A shipyard or port on the water's edge, the quay along z 4 to 9.5 facing the water. The port has a paved container
## yard with stacks, two quay cranes (one lifting), a warehouse, a harbour-master tower and mast lights; the shipyard
## has a building hall, a slipway with a hull under construction, a goliath gantry and a material yard.
func harbour(rng: RandomNumberGenerator, port: bool) -> void:
	var ink := Color("1d252a")
	var haz := Color("e0b020")
	var pale := Color(1.5, 1.5, 1.52)
	var bright := Color(2.3, 2.3, 2.4)
	var teal := Color("2f6f7e")
	# the quay: a deep concrete slab, a paved yard, fenders, bollards and a painted edge
	box(CONCRETE, Vector3(-8.2, -1.6, -8.6), Vector3(8.2, 0.4, 9.6), Color(1.05, 1.05, 1.05))
	box(PAVERS if port else ASPHALT, Vector3(-8.0, 0.4, -8.4), Vector3(8.0, 0.43, 9.4), Color(1.2, 1.2, 1.2))
	box(TRIM, Vector3(-8.0, 0.43, 8.9), Vector3(8.0, 0.44, 9.05), haz)
	for i in range(11):
		var fx := -7.5 + i * 1.5
		box(TRIM, Vector3(fx - 0.25, -0.6, 9.6), Vector3(fx + 0.25, 0.3, 9.85), ink)               # a rubber fender
	for i in range(8):
		var bx := -7.0 + i * 2.0
		cylinder(STEEL, Vector3(bx, 0.43, 9.15), 0.22, 0.4, bright, 8)
		cylinder(STEEL, Vector3(bx, 0.83, 9.15), 0.3, 0.14, bright, 8)
	if not port:
		_shipyard(rng, ink, haz, pale, bright, teal)
		return
	var paints := [Color("8a3a2e"), Color("2f5a78"), Color("56703a"), Color("a8782a"), Color("c8c8c0"), Color("6a2f50")]
	# container stacks, three bays of up to three high
	for bay in range(3):
		for col in range(2):
			for row in range(2):
				var cx := -7.2 + bay * 2.9
				var cz := -7.4 + col * 2.4 + row * 1.15
				for layer in range(1 + (bay + col + row) % 3):
					container(Vector3(cx, 0.43 + layer * 1.25, cz), paints[rng.randi() % paints.size()])
	# two quay cranes, the left one lifting a container
	ship_crane(-3.2, teal, Color("a8782a"), true)
	ship_crane(3.4, teal, Color("a8782a"), false)
	# a warehouse with roller doors on its water side and a gable roof
	box(PANEL, Vector3(2.4, 0.43, -8.0), Vector3(7.8, 4.2, -2.2), pale)
	box(TRIM, Vector3(2.3, 4.2, -8.1), Vector3(7.9, 4.35, -2.1), Color("56646a"))
	for k in range(9):   # standing-seam ribs, a ridge cap and roof vents
		box(TRIM, Vector3(2.4 + k * 0.62, 4.35, -8.0), Vector3(2.46 + k * 0.62, 4.45, -2.2), Color("8a949a"))
	box(TRIM, Vector3(2.3, 4.45, -5.2), Vector3(7.9, 4.6, -5.0), Color("56646a"))
	for k in range(3):
		cylinder(METAL, Vector3(3.6 + k * 1.8, 4.35, -6.6), 0.32, 0.45, Color("aab4b8"), 10)
		cylinder(TRIM, Vector3(3.6 + k * 1.8, 4.8, -6.6), 0.4, 0.06, Color("56646a"), 10)
	for k in range(3):
		box(TRIM, Vector3(2.8 + k * 1.7, 0.43, -2.2), Vector3(4.2 + k * 1.7, 3.0, -2.16), ink)
		box(STEEL, Vector3(2.8 + k * 1.7, 3.0, -2.2), Vector3(4.2 + k * 1.7, 3.15, -2.1), bright)
	box(GLOWW, Vector3(3.2, 3.5, -2.16), Vector3(7.4, 3.58, -2.1), Color(1.0, 0.88, 0.65))
	# the harbour master's tower: a concrete shaft, a glass cab and a radar
	box(CONCRETE, Vector3(-7.4, 0.43, 2.0), Vector3(-6.2, 6.0, 3.2), Color(1.3, 1.3, 1.3))
	box(TRIM, Vector3(-7.7, 6.0, 1.7), Vector3(-5.9, 6.15, 3.5), Color("56646a"))
	box(GLASS, Vector3(-7.6, 6.15, 1.8), Vector3(-6.0, 7.3, 3.4), Color("2c4d5c"))
	box(TRIM, Vector3(-7.8, 7.3, 1.6), Vector3(-5.8, 7.45, 3.6), Color(1.3, 1.3, 1.3))
	bar(STEEL, Vector3(-6.8, 7.45, 2.6), Vector3(-6.8, 8.4, 2.6), 0.04, bright)
	bar(TRIM, Vector3(-7.5, 8.4, 2.6), Vector3(-6.1, 8.4, 2.6), 0.06, ink)
	banner(-5.7, 5.8, 2.0, 2.2)
	# mast lights and two yard trucks
	for p in [Vector3(-7.4, 0, -1.0), Vector3(0.0, 0, 2.6), Vector3(7.4, 0, 2.6)]:
		bar(STEEL, p + Vector3(0, 0.43, 0), p + Vector3(0, 7.0, 0), 0.07, bright)
		for k in range(3):
			box(GLOWW, p + Vector3(-0.6 + k * 0.45, 6.95, -0.15), p + Vector3(-0.3 + k * 0.45, 7.1, 0.15), Color(1.0, 0.88, 0.65))
	for t in [Vector3(-0.8, 0.43, 4.4), Vector3(5.4, 0.43, 5.4)]:
		box(TRIM, t + Vector3(0, 0.3, 0), t + Vector3(1.6, 0.9, 0.9), haz)
		box(TRIM, t + Vector3(1.6, 0.3, 0), t + Vector3(2.3, 1.4, 0.9), Color("c9972a"))
		box(GLASS, t + Vector3(2.3, 0.8, 0.1), t + Vector3(2.34, 1.3, 0.8), Color("1c2d36"))
		for wx in [0.3, 1.5, 2.0]:
			for wz in [-0.1, 0.9]:
				box(TRIM, t + Vector3(wx - 0.25, 0, wz - 0.08), t + Vector3(wx + 0.25, 0.5, wz + 0.08), Color("1a1c1e"))

func _shipyard(rng: RandomNumberGenerator, ink: Color, haz: Color, pale: Color, bright: Color, teal: Color) -> void:
	# the building hall: a long shed with a vaulted roof, a lit open end towards the slip and an office wing
	var saved := xf
	xf = xf * Transform3D(Basis(), Vector3(-4.6, 0, -2.4))
	var hw := 3.4
	var hd := 5.6
	walls(PANEL, hw * 2.0, hd * 2.0, 0.43, 6.0, pale)
	for s in range(8):
		var a0 := -PI * 0.5 + PI * s / 8.0
		var a1 := -PI * 0.5 + PI * (s + 1) / 8.0
		var x0 := hw * sin(a0)
		var x1 := hw * sin(a1)
		var y0 := 6.43 + 1.9 * cos(a0)
		var y1 := 6.43 + 1.9 * cos(a1)
		quad(PANEL, Vector3(x0, y0, hd), Vector3(x1, y1, hd), Vector3(x1, y1, -hd), Vector3(x0, y0, -hd), pale)
		quad(PANEL, Vector3(x0, 6.43, hd), Vector3(x1, 6.43, hd), Vector3(x1, y1, hd), Vector3(x0, y0, hd), pale)
		quad(PANEL, Vector3(x1, 6.43, -hd), Vector3(x0, 6.43, -hd), Vector3(x0, y0, -hd), Vector3(x1, y1, -hd), pale)
	box(TRIM, Vector3(-2.7, 0.43, hd), Vector3(2.7, 5.4, hd + 0.05), ink)
	box(GLOWW, Vector3(-2.4, 5.0, hd + 0.04), Vector3(2.4, 5.12, hd + 0.09), Color(1.0, 0.88, 0.65))
	for k in range(3):
		box(GLOWW, Vector3(-1.8 + k * 1.8, 3.6, hd + 0.04), Vector3(-1.4 + k * 1.8, 3.7, hd + 0.08), Color(1.0, 0.88, 0.65))
	for sx in [-1.0, 1.0]:
		box(STEEL, Vector3(sx * 2.8 - 0.1, 0.43, hd + 0.02), Vector3(sx * 2.8 + 0.1, 5.4, hd + 0.12), bright)
	box(TRIM, Vector3(-2.8, 5.4, hd), Vector3(2.8, 5.55, hd + 0.2), haz)
	for i in range(6):   # clerestory windows along the sides
		box(GLASS, Vector3(hw, 4.4, -hd + 0.8 + i * 1.8), Vector3(hw + 0.04, 5.4, -hd + 2.2 + i * 1.8), Color("2f5568"))
		box(GLASS, Vector3(-hw - 0.04, 4.4, -hd + 0.8 + i * 1.8), Vector3(-hw, 5.4, -hd + 2.2 + i * 1.8), Color("2f5568"))
	box(PANEL, Vector3(hw, 0.43, -hd), Vector3(hw + 2.0, 3.0, -hd + 3.4), pale)
	box(TRIM, Vector3(hw - 0.1, 3.0, -hd - 0.1), Vector3(hw + 2.1, 3.15, -hd + 3.5), Color("56646a"))
	for k in range(2):
		box(GLASS, Vector3(hw + 2.0, 1.0, -hd + 0.5 + k * 1.4), Vector3(hw + 2.04, 2.2, -hd + 1.5 + k * 1.4), Color("2f5568"))
	banner(-hw + 0.8, 5.3, hd + 0.05, 2.2)
	xf = saved
	# the slipway on the right: paving down into the water, rails and a hull on keel blocks
	quad(ASPHALT, Vector3(0.0, 0.43, 6.0), Vector3(8.0, 0.43, 6.0), Vector3(8.0, -0.8, 9.6), Vector3(0.0, -0.8, 9.6), Color(1.1, 1.1, 1.1))
	for rx in [2.4, 6.4]:
		bar(STEEL, Vector3(rx, 0.5, -6.0), Vector3(rx, 0.5, 6.0), 0.1, bright)
		bar(STEEL, Vector3(rx, 0.5, 6.0), Vector3(rx, -0.7, 9.6), 0.1, bright)
	hull(4.4, -5.0, 6.6)
	# the goliath gantry: four legs, two portal beams and a bridge with a trolley and hook
	var gold := Color("c8902a")
	for gx in [2.0, 6.8]:
		for gz in [-5.6, 5.2]:
			bar(TRIM, Vector3(gx, 0.43, gz), Vector3(gx, 11.0, gz), 0.28, gold)
			box(TRIM, Vector3(gx - 0.5, 0.43, gz - 0.4), Vector3(gx + 0.5, 0.9, gz + 0.4), ink)
		bar(TRIM, Vector3(gx, 11.0, -5.6), Vector3(gx, 11.0, 5.2), 0.28, gold)
		bar(TRIM, Vector3(gx, 3.0, -5.6), Vector3(gx, 10.0, 5.2), 0.08, gold)
		bar(TRIM, Vector3(gx, 3.0, 5.2), Vector3(gx, 10.0, -5.6), 0.08, gold)
	for gz in [-5.6, 5.2]:
		bar(TRIM, Vector3(2.0, 11.0, gz), Vector3(6.8, 11.0, gz), 0.3, gold)
	bar(TRIM, Vector3(2.0, 11.4, 0.0), Vector3(6.8, 11.4, 0.0), 0.35, gold)
	box(TRIM, Vector3(3.7, 10.6, -0.8), Vector3(5.1, 11.2, 0.8), ink)
	for cx in [-0.35, 0.35]:
		bar(TRIM, Vector3(4.4 + cx, 10.6, 0.0), Vector3(4.4 + cx, 6.0, 0.0), 0.02, ink)
	box(TRIM, Vector3(4.2, 5.7, -0.2), Vector3(4.6, 6.0, 0.2), ink)
	box(GLOWR, Vector3(2.0 - 0.15, 11.4, -5.7), Vector3(2.0 + 0.15, 11.7, -5.4), Color(1.0, 0.4, 0.35))
	# a material yard: steel plates, pipe racks, a welding cabin and a portable generator
	for i in range(3):
		box(PANEL, Vector3(-8.0 + i * 1.9, 0.43, 4.4), Vector3(-6.4 + i * 1.9, 0.43 + 0.5 + i * 0.35, 6.0), Color(1.0, 0.95, 0.9))
	for k in range(4):
		pipe(METAL, Vector3(-7.8, 0.75 + (k % 2) * 0.35, 7.0 + k * 0.4), Vector3(-3.4, 0.75 + (k % 2) * 0.35, 7.0 + k * 0.4), 0.16, Color("c9972a") if k % 2 == 0 else Color("8e999e"))
	box(PANEL, Vector3(-3.0, 0.43, 6.4), Vector3(-0.8, 2.4, 8.0), pale)
	box(TRIM, Vector3(-3.1, 2.4, 6.3), Vector3(-0.7, 2.52, 8.1), Color("56646a"))
	box(GLASS, Vector3(-2.6, 1.1, 8.0), Vector3(-1.2, 2.0, 8.04), Color("2f5568"))
	for p in [Vector3(-8.0, 0, 0.0), Vector3(0.4, 0, -7.6), Vector3(8.0, 0, -7.6)]:
		bar(STEEL, p + Vector3(0, 0.43, 0), p + Vector3(0, 6.2, 0), 0.06, bright)
		for k in range(2):
			box(GLOWW, p + Vector3(-0.4 + k * 0.5, 6.15, -0.15), p + Vector3(-0.1 + k * 0.5, 6.3, 0.15), Color(1.0, 0.88, 0.65))

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
	if silo:
		# Underground launch cells and one raised inspection missile make this
		# unmistakable beside the low earth-covered ammunition magazines.
		box(STONE, Vector3(-7, 0, -7), Vector3(7, 0.3, 7), Color("aaa99e"))
		for x in [-3.5, 3.5]:
			cylinder(STONE, Vector3(x, 0.3, -2), 2.5, 0.6, Color("727b7c"), 24)
			cylinder(METAL, Vector3(x, 0.9, -2), 2.15, 0.18, Color("343e43"), 24)
			box(TRIM, Vector3(x-2.3, 1.09, -2.12), Vector3(x+2.3, 1.14, -1.88), Color("e3b949"))
		cylinder(METAL, Vector3(-3.5, 1.1, -2), 0.65, 6.0, Color("dce0dc"), 16)
		cylinder(BANNER, Vector3(-3.5, 7.1, -2), 0.65, 1.8, Color("ad4534"), 16, 0.0)
		lattice(Vector3(-5.5, 0.3, -2), 7.0, 0.8, 0.6, Color("7c8585"))
		box(STONE, Vector3(1, 0.3, 3.5), Vector3(5.5, 2.5, 6), Color("b4b2a5"))
		box(GLASS, Vector3(1.5, 1.3, 6.01), Vector3(5, 2, 6.08), Color("426779"))
		return
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

## One launch cell: a concrete collar with a steel ring and a hazard stripe, rails and a round blast door. Open, the
## door has slid aside and the missile stands in the well against a service tower; closed, the door lies over the well.
func silo_cell(c: Vector3, open: bool) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	cylinder(CONCRETE, c + Vector3(0, 0.1, 0), 3.1, 0.6, Color(1.15, 1.15, 1.15), 28, 2.75)
	cylinder(PANEL, c + Vector3(0, 0.7, 0), 2.45, 0.1, Color(1.45, 1.45, 1.5), 28)
	for k in range(24):
		var a0 := TAU * k / 24.0
		var a1 := TAU * (k + 1) / 24.0
		bar(TRIM, c + Vector3(cos(a0) * 2.62, 0.72, sin(a0) * 2.62), c + Vector3(cos(a1) * 2.62, 0.72, sin(a1) * 2.62), 0.07, haz if k % 2 == 0 else ink)
	for k in range(8):
		var a := TAU * k / 8.0 + 0.2
		box(GLOWW, c + Vector3(cos(a) * 2.95 - 0.09, 0.62, sin(a) * 2.95 - 0.09), c + Vector3(cos(a) * 2.95 + 0.09, 0.74, sin(a) * 2.95 + 0.09), Color(1.0, 0.85, 0.6))
	for sz in [-1.55, 1.55]:   # the rails the door slides on
		bar(STEEL, c + Vector3(-6.4, 0.86, sz), c + Vector3(2.4, 0.86, sz), 0.1, bright)
		for px in [-6.0, -3.0, 0.0, 2.0]:
			box(CONCRETE, c + Vector3(px - 0.12, 0.1, sz - 0.12), c + Vector3(px + 0.12, 0.78, sz + 0.12), Color(1.1, 1.1, 1.1))
	var door := c + Vector3(-3.1 if open else 0.0, 0.92, 0)
	if open:
		cylinder(TRIM, c + Vector3(0, 0.71, 0), 2.3, 0.01, ink, 28)   # the well
	cylinder(PANEL, door, 2.55, 0.3, Color(1.45, 1.45, 1.5), 28)
	for k in range(6):   # ribs across the door
		var a := PI * k / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		bar(STEEL, door + Vector3(0, 0.32, 0) - dir * 2.35, door + Vector3(0, 0.32, 0) + dir * 2.35, 0.07, Color(1.25, 1.25, 1.3))
	cylinder(STEEL, door + Vector3(0, 0.3, 0), 0.36, 0.22, Color(1.3, 1.3, 1.35), 10)
	for k in range(20):
		var a0 := TAU * k / 20.0
		var a1 := TAU * (k + 1) / 20.0
		bar(TRIM, door + Vector3(cos(a0) * 2.35, 0.32, sin(a0) * 2.35), door + Vector3(cos(a1) * 2.35, 0.32, sin(a1) * 2.35), 0.06, haz if k % 2 == 0 else ink)
	if not open:
		return
	# the missile: white body, two dark bands, a red roundel, a three-stage nose
	var base := c + Vector3(0, 0.72, 0)
	cylinder(METAL, base, 0.78, 5.4, Color(1.5, 1.5, 1.52), 16)
	cylinder(TRIM, base + Vector3(0, 1.8, 0), 0.8, 0.35, ink, 16)
	cylinder(TRIM, base + Vector3(0, 2.6, 0), 0.8, 0.2, Color("c0392b"), 16)
	cylinder(TRIM, base + Vector3(0, 3.9, 0), 0.8, 0.35, ink, 16)
	cylinder(TRIM, base + Vector3(0, 5.4, 0), 0.78, 0.9, Color("5d6468"), 16, 0.5)
	cylinder(TRIM, base + Vector3(0, 6.3, 0), 0.5, 0.9, Color("5d6468"), 16, 0.2)
	cylinder(TRIM, base + Vector3(0, 7.2, 0), 0.2, 0.5, Color("c0392b"), 12, 0.0)
	# the service tower beside it, with two swing arms and a red beacon
	lattice(c + Vector3(2.4, 0.1, 0), 7.8, 1.1, 0.75, Color(1.3, 1.3, 1.35))
	for y in [3.0, 5.4]:
		bar(STEEL, c + Vector3(2.05, y, 0), c + Vector3(0.82, y, 0), 0.08, bright)
		box(STEEL, c + Vector3(1.7, y - 0.05, -0.6), c + Vector3(2.9, y + 0.05, 0.6), Color(1.3, 1.3, 1.35))
	box(GLOWR, c + Vector3(2.25, 7.9, -0.15), c + Vector3(2.55, 8.2, 0.15), Color(1.0, 0.4, 0.35))

## A missile silo complex: two launch cells, one open with its missile raised, a hardened control centre with antennas,
## fuel tanks, a generator shed, a guard tower and a fence.
func missile_silo(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var steel := Color("8e999e")
	var light := Color("dfe4e6")
	var bright := Color(2.3, 2.3, 2.4)
	var conc := Color(1.15, 1.15, 1.15)
	var pale := Color(1.5, 1.5, 1.52)
	# the ground: a deep slab, an apron of pavers and a gravel strip behind
	box(CONCRETE, Vector3(-8.6, -1.6, -8.2), Vector3(8.6, 0.1, 8.2), Color(1.0, 1.0, 1.0))
	box(PAVERS, Vector3(-8.4, 0.1, 0.9), Vector3(8.4, 0.13, 8.0), Color(1.2, 1.2, 1.2))
	box(GRAVEL, Vector3(-8.4, 0.1, -8.0), Vector3(8.4, 0.15, -6.0), Color(1.1, 1.1, 1.1))
	silo_cell(Vector3(-3.5, 0, -2.4), true)
	silo_cell(Vector3(3.9, 0, -2.4), false)
	# cable trenches from the control centre to each cell
	for x in [-2.3, 2.7]:
		box(CONCRETE, Vector3(x - 0.3, 0.1, 0.5), Vector3(x + 0.3, 0.3, 3.4), Color(1.2, 1.2, 1.2))
		box(TRIM, Vector3(x - 0.3, 0.3, 0.5), Vector3(x + 0.3, 0.33, 3.4), ink)
	# the control centre: a hardened block under earth, a blast door, vents and an antenna mast
	var origin := xf
	xf = xf * Transform3D(Basis(), Vector3(0, 0, 5.5))
	walls(CONCRETE, 8.6, 3.6, 0.13, 2.5, conc)
	box(CONCRETE, Vector3(-4.5, 2.6, -1.9), Vector3(4.5, 3.0, 1.9), Color(1.3, 1.3, 1.3))
	box(GRAVEL, Vector3(-4.2, 3.0, -1.6), Vector3(4.2, 3.04, 1.6), Color(0.9, 0.9, 0.9))
	for sx in [-1.0, 1.0]:
		dome(PLASTER, Vector3(sx * 4.6, 0.13, 0), 2.8, 2.3, Color("4f7f46"), 12, 4)
	box(TRIM, Vector3(-1.5, 0.13, 1.8), Vector3(1.5, 2.55, 1.86), ink)          # the blast door in its recess
	box(PANEL, Vector3(-1.25, 0.13, 1.86), Vector3(1.25, 2.25, 1.96), Color(1.45, 1.45, 1.5))
	for k in range(6):
		bar(TRIM, Vector3(-1.2 + k * 0.48, 0.2, 1.97), Vector3(-1.2 + k * 0.48 + 0.2, 2.2, 1.97), 0.025, haz if k % 2 == 0 else ink)
	cylinder(STEEL, Vector3(0, 1.2, 1.96), 0.3, 0.12, light, 10)
	for sx in [-1.9, 1.9]:
		box(GLOWW, Vector3(sx - 0.15, 2.3, 1.84), Vector3(sx + 0.15, 2.45, 1.94), Color(1.0, 0.85, 0.6))
	box(TRIM, Vector3(-0.6, 2.7, 1.88), Vector3(0.6, 3.0, 1.92), haz)
	for i in range(3):
		pipe(METAL, Vector3(-3.3 + i * 0.7, 3.04, -0.8), Vector3(-3.3 + i * 0.7, 4.0, -0.8), 0.17, Color("30383c"))
		cylinder(TRIM, Vector3(-3.3 + i * 0.7, 4.0, -0.8), 0.24, 0.08, ink, 8)
	bar(STEEL, Vector3(3.0, 3.04, -0.6), Vector3(3.0, 8.0, -0.6), 0.06, bright)
	for y in [5.0, 6.4, 7.6]:
		bar(STEEL, Vector3(2.4, y, -0.6), Vector3(3.6, y, -0.6), 0.04, bright)
	bar(METAL, Vector3(1.5, 3.04, -1.0), Vector3(1.5, 4.6, -1.0), 0.05, steel)
	dome(TRIM, Vector3(1.5, 4.6, -1.0), 0.7, 0.45, Color(1.4, 1.4, 1.4), 14, 4)
	xf = origin
	# fuel and oxidiser tanks on saddles with a pump house
	for i in range(2):
		var tx := 6.2 + i * 1.7
		pipe(METAL, Vector3(tx, 1.15, 1.8), Vector3(tx, 1.15, 5.8), 0.8 - i * 0.1, light, 14)
		for z in [2.4, 5.2]:
			box(CONCRETE, Vector3(tx - 0.8, 0.13, z - 0.2), Vector3(tx + 0.8, 0.8, z + 0.2), Color(1.2, 1.2, 1.2))
		box(TRIM, Vector3(tx - 0.12, 1.9 - i * 0.1, 3.6), Vector3(tx + 0.12, 2.1 - i * 0.1, 4.0), steel)
	box(PANEL, Vector3(5.6, 0.13, 6.4), Vector3(8.2, 2.3, 7.9), pale)
	box(TRIM, Vector3(5.5, 2.3, 6.3), Vector3(8.3, 2.46, 8.0), Color("56646a"))
	box(TRIM, Vector3(6.4, 0.13, 7.9), Vector3(7.4, 1.8, 7.95), ink)
	pipe(METAL, Vector3(6.2, 0.5, 5.8), Vector3(6.2, 0.5, 6.4), 0.12, Color("c83a2e"))
	# a generator shed with louvres, a stack and a transformer
	box(PANEL, Vector3(-8.0, 0.13, 3.4), Vector3(-5.2, 2.4, 6.4), pale)
	box(TRIM, Vector3(-8.1, 2.4, 3.3), Vector3(-5.1, 2.55, 6.5), Color("56646a"))
	louvres(-7.6, -5.6, 0.5, 2.0, 6.4, light, ink)
	pipe(METAL, Vector3(-7.4, 2.55, 4.0), Vector3(-7.4, 4.0, 4.0), 0.14, Color("30383c"))
	cylinder(TRIM, Vector3(-7.4, 4.0, 4.0), 0.2, 0.08, ink, 8)
	box(METAL, Vector3(-8.0, 0.13, 7.0), Vector3(-6.4, 1.6, 8.0), Color(0.78, 0.9, 0.84))
	for k in range(3):
		pipe(METAL, Vector3(-7.7 + k * 0.5, 1.6, 7.5), Vector3(-7.7 + k * 0.5, 2.4, 7.5), 0.08, Color("d9c9a8"))
	box(GLOWG, Vector3(-5.2, 1.5, 4.7), Vector3(-5.14, 1.7, 4.9), Color(0.6, 1.0, 0.55))
	# a support truck on the apron
	box(TRIM, Vector3(-1.4, 0.35, 1.5), Vector3(1.6, 1.4, 2.4), Color("55633f"))
	box(TRIM, Vector3(1.6, 0.35, 1.5), Vector3(2.7, 1.9, 2.4), Color("4c5a38"))
	box(GLASS, Vector3(2.7, 1.2, 1.6), Vector3(2.74, 1.8, 2.3), Color("1c2d36"))
	for wx in [-0.9, 0.9, 2.1]:
		for wz in [1.45, 2.45]:
			box(TRIM, Vector3(wx - 0.3, 0.13, wz - 0.1), Vector3(wx + 0.3, 0.7, wz + 0.1), Color("1a1c1e"))
	box(GLOWW, Vector3(2.7, 0.55, 1.6), Vector3(2.74, 0.7, 1.75), Color(1.0, 0.85, 0.6))
	# a guard tower in the back corner
	lattice(Vector3(-7.4, 0.1, -7.2), 6.0, 1.5, 1.2, Color(1.3, 1.3, 1.35))
	box(PANEL, Vector3(-8.2, 6.0, -8.0), Vector3(-6.6, 7.5, -6.4), pale)
	box(GLASS, Vector3(-8.15, 6.4, -6.42), Vector3(-6.65, 7.2, -6.38), Color("2f5568"))
	box(TRIM, Vector3(-8.4, 7.5, -8.2), Vector3(-6.4, 7.65, -6.2), Color("56646a"))
	box(GLOWW, Vector3(-7.6, 7.35, -6.2), Vector3(-7.0, 7.45, -6.1), Color(1.0, 0.88, 0.65))
	# a perimeter fence with outward-leaning wire, a gate in the front corner, and floodlights
	for i in range(13):
		var fx := -8.4 + i * 1.4
		for fz in [-8.0, 8.0]:
			if fz > 0 and fx > 3.0 and fx < 5.6:
				continue
			bar(STEEL, Vector3(fx, 0.1, fz), Vector3(fx, 1.7, fz), 0.035, bright)
			bar(STEEL, Vector3(fx, 1.7, fz), Vector3(fx, 2.0, fz + (0.3 if fz > 0 else -0.3)), 0.025, bright)
	for i in range(12):
		var fz := -7.2 + i * 1.4
		for fx in [-8.4, 8.4]:
			bar(STEEL, Vector3(fx, 0.1, fz), Vector3(fx, 1.7, fz), 0.035, bright)
	for y in [0.6, 1.2, 1.7]:
		box(TRIM, Vector3(-8.4, y, 7.97), Vector3(3.0, y + 0.04, 8.03), Color("a0aaae"))
		box(TRIM, Vector3(5.6, y, 7.97), Vector3(8.4, y + 0.04, 8.03), Color("a0aaae"))
		box(TRIM, Vector3(-8.4, y, -8.03), Vector3(8.4, y + 0.04, -7.97), Color("a0aaae"))
		box(TRIM, Vector3(-8.43, y, -8.0), Vector3(-8.37, y + 0.04, 8.0), Color("a0aaae"))
		box(TRIM, Vector3(8.37, y, -8.0), Vector3(8.43, y + 0.04, 8.0), Color("a0aaae"))
	for p in [Vector3(-8.0, 0, 7.6), Vector3(8.0, 0, 7.6), Vector3(8.0, 0, -7.4), Vector3(0.0, 0, -7.4)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.0, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.3, 4.95, -0.15), p + Vector3(0.3, 5.05, 0.15), Color(1.0, 0.88, 0.65))
	# a warning plate on the gate and painted lines on the apron
	box(TRIM, Vector3(3.2, 1.0, 8.04), Vector3(4.2, 1.6, 8.08), haz)
	box(TRIM, Vector3(-8.0, 0.13, 1.0), Vector3(8.0, 0.14, 1.12), Color(0.95, 0.85, 0.3))

## A machine gun on a tripod at `c` pointing along +z: a dark receiver, a barrel with a flash hider, a shield plate and a
## box of belted ammunition.
func machine_gun(c: Vector3, yaw: float) -> void:
	var ink := Color("1d252a")
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.UP, yaw), c)
	for k in range(3):
		var a := TAU * k / 3.0
		bar(STEEL, Vector3(0, 0.55, 0), Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45), 0.025, Color(1.5, 1.5, 1.55))
	box(TRIM, Vector3(-0.1, 0.5, -0.3), Vector3(0.1, 0.72, 0.35), ink)
	pipe(METAL, Vector3(0, 0.62, 0.3), Vector3(0, 0.62, 1.2), 0.045, Color("30383c"), 8)
	cylinder(TRIM, Vector3(0, 0.62, 1.2), 0.07, 0.1, ink, 8)
	box(TRIM, Vector3(-0.32, 0.46, 0.55), Vector3(0.32, 0.9, 0.6), Color("3a4630"))
	box(TRIM, Vector3(0.16, 0.4, -0.2), Vector3(0.4, 0.58, 0.1), Color("4c5a38"))
	xf = saved

## A sandbag emplacement: a horseshoe of staggered bags three courses high, open towards +z, with a machine gun inside.
func sandbag_nest(c: Vector3, yaw: float) -> void:
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.UP, yaw), c)
	for course in range(3):
		var y := course * 0.32
		var off := 0.0 if course % 2 == 0 else 0.3
		for k in range(7):   # the back
			box(PLASTER, Vector3(-1.3 + k * 0.4 + off - 0.2, y, -1.0), Vector3(-1.3 + k * 0.4 + off + 0.2, y + 0.3, -0.62), Color("b0a27a") if (k + course) % 2 == 0 else Color("a2946c"))
		for k in range(3):   # the two sides
			for sx in [-1.0, 1.0]:
				box(PLASTER, Vector3(sx * 1.3 - 0.19, y, -0.6 + k * 0.4 + off * 0.6), Vector3(sx * 1.3 + 0.19, y + 0.3, -0.2 + k * 0.4 + off * 0.6), Color("a89a72") if (k + course) % 2 == 0 else Color("9a8c66"))
	xf = saved
	machine_gun(c + Vector3(0, 0.0, 0.0), yaw)

## A row of concrete dragon's teeth: pyramids that stop tanks, in a staggered double row from `a` to `b` along x at z.
func dragons_teeth(x0: float, x1: float, z: float) -> void:
	var n := int((x1 - x0) / 0.9)
	for k in range(n):
		var x := x0 + k * 0.9
		for row in range(2):
			var zz := z + row * 0.8
			var xx := x + row * 0.45
			cylinder(CONCRETE, Vector3(xx, 0.1, zz), 0.42, 0.75, Color(1.2, 1.2, 1.2), 4, 0.06)

## Coils of razor wire along x from x0 to x1 at z: a rolled spiral on stakes.
func wire_coil(x0: float, x1: float, z: float) -> void:
	var steel := Color(3.0, 3.0, 3.1)
	var n := int((x1 - x0) / 0.5)
	for k in range(n):
		var x := x0 + k * 0.5
		cylinder(PANEL, Vector3(x, 0.55 + 0.3 * sin(k * 1.3), z), 0.22, 0.03, steel, 10)
		cylinder(PANEL, Vector3(x + 0.25, 0.7 + 0.3 * cos(k * 1.3), z), 0.22, 0.03, steel, 10)
	for k in range(0, n, 4):
		bar(STEEL, Vector3(x0 + k * 0.5, 0.1, z), Vector3(x0 + k * 0.5, 1.1, z), 0.025, steel)

## A bunker: a low reinforced-concrete pillbox with a stepped roof, three firing ports with gun barrels, an armoured
## cupola, an ammunition door, a sunken trench with duckboards, sandbag machine-gun nests, dragon's teeth, razor wire,
## camouflage netting and a floodlit perimeter.
func bunker(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	var warm := Color(1.0, 0.88, 0.65)
	var origin := xf
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(GRAVEL, Vector3(-9.2, 0.1, -9.0), Vector3(9.2, 0.14, 8.0), Color(1.0, 1.0, 1.0))
	box(ASPHALT, Vector3(-1.0, 0.1, 3.0), Vector3(1.0, 0.15, 9.4), Color(0.8, 0.8, 0.84))
	# ---- the main pillbox: a stepped block, 8 x 4.8 and 3.2 high, rough-cast with a heavy slab roof and an earth cap
	var bz := -2.2
	box(CONCRETE, Vector3(-4.4, 0.1, bz - 2.6), Vector3(4.4, 3.2, bz + 2.6), Color(1.15, 1.15, 1.15))
	box(CONCRETE, Vector3(-4.7, 3.2, bz - 2.9), Vector3(4.7, 3.7, bz + 2.9), Color(1.3, 1.3, 1.3))
	box(PLASTER, Vector3(-0.2, 3.7, bz - 2.0), Vector3(3.6, 3.95, bz + 2.0), Color("4a7a42"))
	dome(PLASTER, Vector3(1.2, 3.7, bz - 0.2), 2.4, 0.8, Color("42703c"), 14, 3)
	for k in range(5):   # form-work lines on the walls
		box(TRIM, Vector3(-4.4, 0.7 + k * 0.5, bz + 2.6), Vector3(4.4, 0.74 + k * 0.5, bz + 2.63), Color("a0a8aa"))
	# three firing ports in the front with gun barrels, and slits on the sides
	var fz := bz + 2.6
	for x in [-2.6, 0.0, 2.6]:
		box(TRIM, Vector3(x - 0.75, 1.6, fz - 0.05), Vector3(x + 0.75, 2.35, fz + 0.04), ink)
		box(CONCRETE, Vector3(x - 0.9, 2.35, fz), Vector3(x + 0.9, 2.5, fz + 0.3), Color(1.4, 1.4, 1.4))
		pipe(METAL, Vector3(x, 1.98, fz - 0.4), Vector3(x, 1.98, fz + 0.9), 0.07, Color("30383c"), 8)
		cylinder(TRIM, Vector3(x, 1.98, fz + 0.9), 0.1, 0.12, ink, 8)
	for sx in [-1.0, 1.0]:
		box(TRIM, Vector3(sx * 4.4 - 0.03, 1.8, bz - 0.6), Vector3(sx * 4.4 + 0.03, 2.2, bz + 0.6), ink)
	# the armoured cupola on the roof with a viewing slit, a periscope and an antenna
	cylinder(STEEL, Vector3(-1.6, 4.0, bz - 0.6), 0.9, 0.7, Color(1.5, 1.5, 1.55), 12, 0.7)
	dome(STEEL, Vector3(-1.6, 4.7, bz - 0.6), 0.7, 0.3, Color(1.5, 1.5, 1.55), 12, 3)
	box(TRIM, Vector3(-2.1, 4.15, bz - 0.0), Vector3(-1.1, 4.4, bz + 0.3), ink)
	bar(STEEL, Vector3(-1.0, 4.0, bz - 1.1), Vector3(-1.0, 6.2, bz - 1.1), 0.025, bright)
	pipe(METAL, Vector3(1.6, 3.7, bz - 1.0), Vector3(1.6, 4.5, bz - 1.0), 0.09, Color("30383c"), 8)   # an exhaust vent
	cylinder(TRIM, Vector3(1.6, 4.5, bz - 1.0), 0.14, 0.06, ink, 8)
	# the ammunition door on the left side with a stripe and a lamp
	box(TRIM, Vector3(-4.45, 0.1, bz + 0.6), Vector3(-4.38, 2.0, bz + 1.8), ink)
	box(PANEL, Vector3(-4.52, 0.1, bz + 0.7), Vector3(-4.45, 1.9, bz + 1.7), Color(1.45, 1.45, 1.5))
	box(TRIM, Vector3(-4.55, 1.0, bz + 0.7), Vector3(-4.5, 1.15, bz + 1.7), haz)
	box(GLOWW, Vector3(-4.6, 2.2, bz + 1.0), Vector3(-4.5, 2.3, bz + 1.4), warm)
	# ---- the trench: a sunken zig-zag in front of the pillbox with duckboards and a ladder
	box(CONCRETE, Vector3(-6.4, -0.3, 1.2), Vector3(6.4, 0.12, 2.6), Color(0.9, 0.9, 0.92))
	box(TRIM, Vector3(-6.2, -0.28, 1.4), Vector3(6.2, -0.24, 2.4), Color("6a5a3a"))
	for sx in [-1.0, 1.0]:
		box(CONCRETE, Vector3(sx * 6.4 - 0.1, -0.3, 1.2), Vector3(sx * 6.4 + 0.1, 0.5, 2.6), Color(1.2, 1.2, 1.2))
	for k in range(9):   # revetment planks along the front lip
		box(WOOD, Vector3(-6.0 + k * 1.5, 0.12, 2.6), Vector3(-5.2 + k * 1.5, 0.55, 2.7), Color("6a5038"))
	for k in range(5):
		bar(STEEL, Vector3(5.6, -0.2 + k * 0.2, 1.3), Vector3(5.6, -0.2 + k * 0.2, 2.5), 0.02, bright)
	# ---- sandbag machine-gun nests at the trench ends and in the middle, dragon's teeth and wire beyond
	sandbag_nest(Vector3(-5.4, 0.12, 3.6), 0.2)
	sandbag_nest(Vector3(5.4, 0.12, 3.6), -0.2)
	sandbag_nest(Vector3(0.0, 0.12, 4.6), 0.0)
	dragons_teeth(-8.8, -2.0, 6.0)
	dragons_teeth(2.0, 8.8, 6.0)
	wire_coil(-8.8, -1.4, 7.4)
	wire_coil(1.4, 8.8, 7.4)
	# ---- camouflage netting over the rear, an ammunition store and a field generator
	for p in [Vector3(-3.6, 0, -7.4), Vector3(3.6, 0, -7.4), Vector3(-3.6, 0, -5.8), Vector3(3.6, 0, -5.8)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 2.6, 0), 0.05, bright)
	quad(PLASTER, Vector3(-4.2, 2.6, -5.4), Vector3(4.2, 2.6, -5.4), Vector3(4.2, 2.6, -8.0), Vector3(-4.2, 2.6, -8.0), Color("4f5c38"))
	quad(PLASTER, Vector3(-4.2, 2.4, -5.0), Vector3(4.2, 2.4, -5.0), Vector3(4.2, 2.6, -5.4), Vector3(-4.2, 2.6, -5.4), Color("5c6a42"))
	for k in range(4):
		box(WOOD, Vector3(-3.0 + k * 1.5, 0.1, -7.5), Vector3(-1.9 + k * 1.5, 0.8 + (k % 2) * 0.5, -6.5), Color("7a6a42") if k % 2 == 0 else Color(0.62, 0.68, 0.55) * 1.5)
	box(PANEL, Vector3(5.2, 0.1, -6.6), Vector3(7.4, 1.5, -5.4), Color(1.5, 1.5, 1.52))
	box(TRIM, Vector3(5.1, 1.5, -6.7), Vector3(7.5, 1.6, -5.3), Color("56646a"))
	box(GLOWG, Vector3(7.4, 1.0, -6.1), Vector3(7.46, 1.2, -5.9), Color(0.6, 1.0, 0.55))
	# ---- floodlights, a flag, and a ring of posts with warning plates
	for p in [Vector3(-8.0, 0, 5.0), Vector3(8.0, 0, 5.0), Vector3(-8.6, 0, -6.0), Vector3(8.6, 0, -6.0)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.0, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.4, 4.95, -0.15), p + Vector3(0.4, 5.05, 0.15), warm)
	for i in range(30):
		var a := TAU * i / 30.0
		var fp := Vector3(cos(a) * 11.2, 0.1, sin(a) * 11.2)
		if absf(fp.x) < 10.1 and absf(fp.z) < 11.4 - absf(fp.x) * 0.577:
			if fp.z > 6.0 and absf(fp.x) < 1.6:
				continue
			bar(STEEL, fp, fp + Vector3(0, 1.7, 0), 0.03, bright)
			if i % 6 == 0:
				box(TRIM, fp + Vector3(-0.3, 0.9, -0.02), fp + Vector3(0.3, 1.4, 0.02), haz)
	banner(-1.0, 6.1, bz - 1.2, 1.6)   # hung from the cupola mast
	xf = origin

## A road-mobile canister launcher at `c` facing +z: a truck on three axles with a cab, a stabiliser frame, and four
## canisters raised at an angle (or laid down when `raised` is false) with orange caps.
func sam_launcher(c: Vector3, raised: bool, body: Color) -> void:
	var ink := Color("1d252a")
	var dark := body * 0.75
	box(TRIM, c + Vector3(-1.1, 0.7, -3.6), c + Vector3(1.1, 1.05, 2.4), dark)                    # the chassis
	box(TRIM, c + Vector3(-1.15, 1.05, -3.0), c + Vector3(1.15, 1.25, 1.6), body)                  # the deck
	box(TRIM, c + Vector3(-1.1, 0.75, 2.4), c + Vector3(1.1, 2.55, 3.8), body)                    # the cab
	box(GLASS, c + Vector3(-0.9, 1.7, 3.8), c + Vector3(0.9, 2.4, 3.84), Color("1c2d36"))
	box(TRIM, c + Vector3(-1.1, 0.75, 3.8), c + Vector3(1.1, 1.1, 3.95), ink)                     # the bumper
	for ax in [-2.8, -0.4, 3.1]:
		for sx in [-1.0, 1.0]:
			box(TRIM, c + Vector3(sx * 1.0 - 0.17, 0.0, ax - 0.5), c + Vector3(sx * 1.0 + 0.17, 1.0, ax + 0.5), Color("1a1c1e"))
	for sz in [-3.4, 1.8]:   # outriggers
		for sx in [-1.0, 1.0]:
			box(TRIM, c + Vector3(sx * 1.6 - 0.1, 0.0, sz - 0.12), c + Vector3(sx * 1.1 + 0.1, 0.25, sz + 0.12), ink)
	var saved := xf
	var tilt := -1.2 if raised else -0.06
	xf = xf * Transform3D(Basis(Vector3.RIGHT, tilt), c + Vector3(0, 1.4, -2.4))
	box(TRIM, Vector3(-1.0, -0.15, -0.3), Vector3(1.0, 0.0, 1.6), Color("3a4630"))
	for rx in [-0.95, 0.95]:   # two side rails carry the canisters
		box(TRIM, Vector3(rx - 0.06, -0.1, -0.3), Vector3(rx + 0.06, 0.12, 4.4), Color("3a4630"))
	for ix in range(2):
		for iy in range(2):
			var x0 := -0.9 + ix * 0.9
			var y0 := 0.1 + iy * 0.9
			box(PANEL, Vector3(x0, y0, 0.0), Vector3(x0 + 0.8, y0 + 0.8, 4.4), Color(0.78, 0.82, 0.7) * 1.7)
			box(TRIM, Vector3(x0 + 0.05, y0 + 0.05, 4.4), Vector3(x0 + 0.75, y0 + 0.75, 4.46), Color("c9702a"))
			box(TRIM, Vector3(x0, y0 + 0.35, 0.8), Vector3(x0 + 0.8, y0 + 0.45, 0.95), ink)
	xf = saved

## A vertical launch module: a low armoured block with a grid of hatches on its roof, two of them open with
## a missile tip showing, and a lit status panel.
func sam_vls(c: Vector3) -> void:
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	box(CONCRETE, c + Vector3(-1.9, 0.0, -2.2), c + Vector3(1.9, 0.35, 2.2), Color(1.25, 1.25, 1.25))
	box(PANEL, c + Vector3(-1.7, 0.35, -2.0), c + Vector3(1.7, 1.9, 2.0), Color(0.62, 0.68, 0.58) * 1.7)
	box(TRIM, c + Vector3(-1.8, 1.9, -2.1), c + Vector3(1.8, 2.0, 2.1), Color("3a464c"))
	for ix in range(3):
		for iz in range(4):
			var hx := c.x - 1.15 + ix * 1.15
			var hz := c.z - 1.5 + iz * 1.0
			var open := (ix == 1 and iz == 1) or (ix == 0 and iz == 3)
			box(TRIM, Vector3(hx - 0.4, c.y + 2.0, hz - 0.4), Vector3(hx + 0.4, c.y + 2.06, hz + 0.4), ink)
			if open:
				pipe(METAL, Vector3(hx, c.y + 2.0, hz), Vector3(hx, c.y + 3.1, hz), 0.2, Color(1.5, 1.5, 1.52), 10)
				cylinder(TRIM, Vector3(hx, c.y + 3.1, hz), 0.2, 0.5, Color("5d6468"), 10, 0.03)
				box(TRIM, Vector3(hx + 0.35, c.y + 2.06, hz - 0.35), Vector3(hx + 0.65, c.y + 2.5, hz - 0.05), Color("c9702a"))
			else:
				box(STEEL, Vector3(hx - 0.36, c.y + 2.06, hz - 0.36), Vector3(hx + 0.36, c.y + 2.1, hz + 0.36), bright)
	box(GLOW, c + Vector3(-1.2, 1.1, 2.0), c + Vector3(1.2, 1.5, 2.06), Color(0.75, 0.92, 1.0))

## A phased-array radar on a tower trailer at `c` facing +z: a square array tilted back, a mast and outriggers.
func sam_radar(c: Vector3, size: float) -> void:
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	box(TRIM, c + Vector3(-1.4, 0.4, -2.0), c + Vector3(1.4, 0.8, 2.0), Color("4c5a38"))
	for sz in [-1.7, 1.7]:
		for sx in [-1.0, 1.0]:
			box(TRIM, c + Vector3(sx * 1.5 - 0.12, 0.0, sz - 0.12), c + Vector3(sx * 1.5 + 0.12, 0.5, sz + 0.12), ink)
	box(PANEL, c + Vector3(-0.5, 0.8, -0.6), c + Vector3(0.5, 3.0, 0.6), Color(0.62, 0.68, 0.58) * 1.7)
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.RIGHT, 0.22), c + Vector3(0, 3.0, 0.2))
	box(PANEL, Vector3(-size * 0.5, 0.0, 0.0), Vector3(size * 0.5, size, 0.3), Color(0.78, 0.82, 0.7) * 1.8)
	box(TRIM, Vector3(-size * 0.5 + 0.12, 0.12, 0.3), Vector3(size * 0.5 - 0.12, size - 0.12, 0.34), Color("22343c"))
	for gx in range(6):
		for gy in range(6):
			if (gx + gy) % 2 == 0:
				box(TRIM, Vector3(-size * 0.5 + 0.25 + gx * (size - 0.5) / 6.0, 0.25 + gy * (size - 0.5) / 6.0, 0.34), Vector3(-size * 0.5 + 0.25 + (gx + 0.8) * (size - 0.5) / 6.0, 0.25 + (gy + 0.8) * (size - 0.5) / 6.0, 0.36), Color("2f4b56"))
	xf = saved
	box(GLOWR, c + Vector3(-0.1, 3.0 + size + 0.2, 0.2), c + Vector3(0.1, 3.0 + size + 0.4, 0.4), Color(1.0, 0.4, 0.35))

## A surveillance radar: a lattice tower with a slowly turning mesh antenna on top.
func sam_search_radar(c: Vector3) -> void:
	var bright := Color(2.3, 2.3, 2.4)
	lattice(c, 6.0, 1.3, 0.9, Color(1.4, 1.4, 1.45))
	box(TRIM, c + Vector3(-0.6, 6.0, -0.6), c + Vector3(0.6, 6.4, 0.6), Color("3a464c"))
	box(PANEL, c + Vector3(-2.2, 6.4, -0.12), c + Vector3(2.2, 8.0, 0.12), Color(1.6, 1.6, 1.62))
	for k in range(6):
		box(TRIM, c + Vector3(-2.2 + k * 0.88, 6.4, -0.16), c + Vector3(-2.1 + k * 0.88, 8.0, 0.16), Color("8a949a"))
	bar(STEEL, c + Vector3(0, 8.0, 0), c + Vector3(0, 8.8, 0), 0.03, bright)

## A ground-based air-defence site: a battery of four launchers (road-mobile canisters, or a vertical-launch block
## for the nations that field one) around a phased-array radar, a surveillance radar, a command container under
## camouflage netting, a generator, sandbag walls and a fenced yard with a gate.
func sam_site(rng: RandomNumberGenerator) -> void:
	var haz := Color("e0b020")
	var ink := Color("1d252a")
	var bright := Color(2.3, 2.3, 2.4)
	var pale := Color(1.5, 1.5, 1.52)
	var olive := Color(0.62, 0.68, 0.55)
	var warm := Color(1.0, 0.88, 0.65)
	var vertical: bool = nation in ["uk", "germany", "france", "italy", "israel", "australia", "ukraine", "netherlands"]
	var origin := xf
	var s0 := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI / 6.0), Vector3.ZERO)
	cylinder(CONCRETE, Vector3(0, -1.6, 0), 12.3, 1.7, Color(1.0, 1.0, 1.0), 6)
	xf = s0
	box(GRAVEL, Vector3(-9.2, 0.1, -9.0), Vector3(9.2, 0.14, 8.0), Color(1.0, 1.0, 1.0))
	box(ASPHALT, Vector3(-1.2, 0.1, 1.0), Vector3(1.2, 0.15, 9.4), Color(0.85, 0.85, 0.88))
	box(ASPHALT, Vector3(-9.0, 0.1, 0.4), Vector3(9.0, 0.15, 1.6), Color(0.85, 0.85, 0.88))
	# ---- four launchers in a row on concrete pads, each behind a sandbag wall on the +z side, the first two raised
	for i in range(4):
		var lx := -6.0 + i * 4.0
		box(CONCRETE, Vector3(lx - 1.8, 0.1, -6.6), Vector3(lx + 1.8, 0.2, -0.2), Color(1.3, 1.3, 1.3))
		if vertical:
			sam_vls(Vector3(lx, 0.2, -3.4))
		else:
			sam_launcher(Vector3(lx, 0.2, -3.6), i < 3, olive)
		for k in range(5):   # the sandbag wall: staggered rounded blocks
			box(PLASTER, Vector3(lx - 1.9 + k * 0.78, 0.2, -7.2), Vector3(lx - 1.2 + k * 0.78, 0.7, -6.7), Color("a89a72"))
			if k < 4:
				box(PLASTER, Vector3(lx - 1.5 + k * 0.78, 0.7, -7.2), Vector3(lx - 0.8 + k * 0.78, 1.2, -6.7), Color("9a8c66"))
	# ---- the phased-array radar and the surveillance radar behind and beside the battery
	sam_radar(Vector3(0.0, 0.1, 5.4), 2.8)
	sam_search_radar(Vector3(7.0, 0.1, 5.2))
	box(CONCRETE, Vector3(-1.8, 0.1, 3.2), Vector3(1.8, 0.14, 7.2), Color(1.3, 1.3, 1.3))
	# ---- the command post under camouflage netting: a container, antennas, a table of screens, a generator
	box(PANEL, Vector3(-8.2, 0.1, 3.0), Vector3(-5.2, 2.0, 4.4), pale)
	box(TRIM, Vector3(-8.25, 2.0, 2.95), Vector3(-5.15, 2.1, 4.45), Color("56646a"))
	box(GLOW, Vector3(-7.6, 1.2, 4.4), Vector3(-5.8, 1.7, 4.46), Color(0.75, 0.92, 1.0))
	bar(STEEL, Vector3(-7.4, 2.1, 3.6), Vector3(-7.4, 4.4, 3.6), 0.03, bright)
	bar(TRIM, Vector3(-7.9, 4.4, 3.6), Vector3(-6.9, 4.4, 3.6), 0.03, ink)
	for k in range(4):
		bar(STEEL, Vector3(-8.8 + (k % 2) * 4.2, 0.1, 2.0 + (k / 2) * 3.4), Vector3(-8.8 + (k % 2) * 4.2, 3.0, 2.0 + (k / 2) * 3.4), 0.05, bright)
	quad(PLASTER, Vector3(-8.8, 3.0, 5.4), Vector3(-4.6, 3.0, 5.4), Vector3(-4.6, 3.0, 2.0), Vector3(-8.8, 3.0, 2.0), Color("5c6a42"))
	quad(PLASTER, Vector3(-8.8, 3.0, 2.0), Vector3(-4.6, 3.0, 2.0), Vector3(-4.6, 2.2, 1.4), Vector3(-8.8, 2.2, 1.4), Color("4f5c38"))
	box(PANEL, Vector3(-4.0, 0.1, 6.2), Vector3(-2.4, 1.6, 7.6), pale)
	box(TRIM, Vector3(-4.1, 1.6, 6.1), Vector3(-2.3, 1.72, 7.7), Color("56646a"))
	pipe(METAL, Vector3(-3.4, 1.72, 6.6), Vector3(-3.4, 2.8, 6.6), 0.1, Color("30383c"))
	box(GLOWG, Vector3(-2.4, 1.0, 6.8), Vector3(-2.34, 1.2, 7.0), Color(0.6, 1.0, 0.55))
	# ---- the guard post at the gate, floodlights, warning plates and the perimeter fence leaning outward
	box(PANEL, Vector3(2.2, 0.1, 8.0), Vector3(3.6, 2.3, 9.2), pale)
	box(TRIM, Vector3(2.1, 2.3, 7.9), Vector3(3.7, 2.42, 9.3), Color("56646a"))
	box(GLASS, Vector3(2.3, 1.0, 9.2), Vector3(3.5, 2.1, 9.24), Color("2f5568"))
	bar(TRIM, Vector3(1.2, 1.0, 8.4), Vector3(-0.2, 1.0, 8.4), 0.05, bright)
	for k in range(3):
		box(TRIM, Vector3(1.2 - k * 0.46, 0.95, 8.35), Vector3(1.0 - k * 0.46, 1.05, 8.45), Color("c83a2e") if k % 2 == 0 else Color("f0eee4"))
	for p in [Vector3(-9.0, 0, 5.0), Vector3(9.0, 0, 3.0), Vector3(9.0, 0, -6.0), Vector3(-9.0, 0, -7.0), Vector3(0.0, 0, -8.6)]:
		bar(STEEL, p + Vector3(0, 0.1, 0), p + Vector3(0, 5.2, 0), 0.05, bright)
		box(GLOWW, p + Vector3(-0.4, 5.15, -0.15), p + Vector3(0.4, 5.25, 0.15), warm)
	for i in range(26):
		var a := TAU * i / 26.0
		var fp := Vector3(cos(a) * 11.0, 0.1, sin(a) * 11.0)
		if absf(fp.x) < 10.0 and absf(fp.z) < 11.4 - absf(fp.x) * 0.577:
			if fp.z > 7.0 and fp.x > -1.6 and fp.x < 1.6:
				continue
			bar(STEEL, fp, fp + Vector3(0, 1.8, 0), 0.03, bright)
			bar(STEEL, fp + Vector3(0, 1.8, 0), fp + Vector3(fp.x * 0.03, 2.1, fp.z * 0.03), 0.02, bright)
			if i % 5 == 0:
				box(TRIM, fp + Vector3(-0.3, 1.0, -0.02), fp + Vector3(0.3, 1.5, 0.02), haz)
	banner(-9.0, 4.4, 7.0, 1.8)
	xf = origin

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
	smoke(Vector3(w * 0.32, 13.6, -d * 0.3), "Industry")
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
	for i in range(_smoke.size()):
		var m := Marker3D.new()
		m.name = "Smoke%s%d" % [_smoke[i][1], i]
		m.position = _smoke[i][0]
		root.add_child(m)
	_smoke.clear()
	return root

## The recipes this kit knows, by building key.
static func has_recipe(key: String) -> bool:
	return key in ["hq", "cityCenter", "cityHall", "courthouse", "bank", "university", "library", "school", "policeStation",
		"hospital", "market", "villageCenter", "tankFactory", "warehouse", "barracks", "cottage", "residential", "workerHouse",
		"luxuryVillas", "housing", "apartments", "tvStation", "intelAgency", "techPark", "farm", "foodDepot", "powerPlant", "airfield", "helipad",
		"extractor", "mountainMine", "oilRefinery", "chipFab", "aiDataCenter", "fusionCell", "strategicComplex", "specialLab", "nuclearReactor", "solarFarm", "shipyard", "port",
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
