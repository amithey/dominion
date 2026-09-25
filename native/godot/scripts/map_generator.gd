extends RefCounted
## More maps, built in the game from a seed, in the same format as the
## exported island (data/map-seed1.json): a height grid, start positions,
## trees, resource deposits, and each nation's starting town and army.
##
##   small        Small Isle     440 m   one compact island, capitals close together
##   twin         Twin Lands     720 m   two large islands joined by an isthmus
##   archipelago  Archipelago    800 m   four islands in a ring, linked by land bridges,
##                                       with islets holding offshore riches
##   continent    Continent      960 m   a great landmass: a mountain range with passes,
##                                       lakes, long coasts
##
## Everything that is not geography (unit and building rules, the economy, AI,
## research...) is kept from the exported island. Every capital stands on
## flat ground, on land joined to every other capital, and has oil, iron and
## gold within reach; the other deposits scale with the map's area.

const MAPS := {
	"small": {"name": "Small Isle", "size": 440, "desc": "One compact island; the capitals are close and fights come early."},
	"twin": {"name": "Twin Lands", "size": 720, "desc": "Two large islands joined by a narrow isthmus."},
	"archipelago": {"name": "Archipelago", "size": 800, "desc": "Four islands linked by land bridges, and rich islets."},
	"continent": {"name": "Continent", "size": 960, "desc": "A great landmass with a mountain range, passes and lakes."},
}
const STEP := 2.5
const MARGIN := 32.0
const HEX := 12.0

var size := 640.0
var half := 320.0
var style := ""
var starts: Array = []   # Vector2 capitals (hex centres)
var _n := 0
var _origin := 0.0
var _h := PackedFloat32Array()
var _coast := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _lakes := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

static func is_generated(key: String) -> bool:
	return MAPS.has(key)

## Replaces the geography of `data` (the exported island) with map `key`.
static func generate(data: Dictionary, key: String, seed := 7) -> void:
	var g = load("res://scripts/map_generator.gd").new()
	g._build(data, key, seed)

func _build(data: Dictionary, key: String, seed: int) -> void:
	style = key
	size = float(MAPS[key].size)
	half = size * 0.5
	_rng.seed = seed * 7919 + key.hash()
	for pair in [[_coast, 0.004, 4], [_hills, 0.012, 4], [_ridge, 0.006, 3], [_lakes, 0.009, 2]]:
		var noise: FastNoiseLite = pair[0]
		noise.seed = _rng.randi()
		noise.frequency = pair[1]
		noise.fractal_octaves = pair[2]
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	starts = _start_positions()
	_heights()
	var old_starts: Array = data.startPositions.duplicate(true)
	var old_hq := {}
	for b in data.buildings:
		if b.key == "hq":
			old_hq[int(b.owner)] = Vector2(float(b.x), float(b.z))
	data.mapSize = int(size)
	data.style = key
	data.grid = {"origin": [_origin, _origin], "step": STEP, "size": _n, "heightsCm": _heights_cm()}
	data.territory = data.get("territory", {}).duplicate()
	data.territory.halfMap = half
	# Towns and armies move with their capital (hex offsets stay hex offsets).
	for group in ["buildings", "units"]:
		for e in data[group]:
			var owner := int(e.owner)
			var delta: Vector2 = starts[owner] - old_hq.get(owner, Vector2.ZERO)
			e.x = float(e.x) + delta.x
			e.z = float(e.z) + delta.y
	data.startPositions = []
	for i in range(starts.size()):
		var delta: Vector2 = starts[i] - old_hq.get(i, Vector2.ZERO)
		data.startPositions.append([float(old_starts[i][0]) + delta.x, float(old_starts[i][1]) + delta.y])
	# Warships start at sea off their own coast.
	var naval := ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
	for u in data.units:
		if u.key in naval:
			var at := _sea_near(Vector2(float(u.x), float(u.z)), starts[int(u.owner)])
			u.x = at.x
			u.z = at.y
	data.trees = _trees()
	data.deposits = _deposits()

# ---------------------------------------------------------------- shape

## Capitals: hex centres, so every town's hex offsets stay on the grid.
func _start_positions() -> Array:
	var at := []
	match style:
		"small":
			at = [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]
		"twin":
			at = [Vector2(0.55, -0.42), Vector2(0.55, 0.42), Vector2(-0.55, 0.42), Vector2(-0.55, -0.42)]
		"archipelago":
			at = [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]
		_:
			at = [Vector2(0.52, -0.5), Vector2(0.48, 0.52), Vector2(-0.5, 0.48), Vector2(-0.52, -0.5)]
	return at.map(func(p): return _hex_centre(p * half))

func _hex_centre(p: Vector2) -> Vector2:
	var q := (sqrt(3.0) / 3.0 * p.x - p.y / 3.0) / HEX
	var r := (2.0 / 3.0 * p.y) / HEX
	var x := roundf(q)
	var z := roundf(r)
	var y := roundf(-q - r)
	var dx := absf(x - q)
	var dy := absf(y + q + r)
	var dz := absf(z - r)
	if dx > dy and dx > dz:
		x = -y - z
	elif dy <= dz:
		z = -x - y
	return Vector2(HEX * sqrt(3.0) * (x + z * 0.5), HEX * 1.5 * z)

## Land-ness: above 0 is land, the coast at 0, below is sea.
func _shape(p: Vector2) -> float:
	var u := p / half   # -1..1 across the map
	var f := 0.0
	match style:
		"small":
			f = 1.0 - (u * Vector2(1.0, 1.0)).length() / 0.86
		"twin":
			var west := 1.0 - ((u - Vector2(-0.52, 0.0)) * Vector2(1.9, 1.08)).length()
			var east := 1.0 - ((u - Vector2(0.52, 0.0)) * Vector2(1.9, 1.08)).length()
			var isthmus := 0.35 - absf(u.y) * 4.5 if absf(u.x) < 0.5 else -1.0
			f = maxf(maxf(west, east), isthmus)
		"archipelago":
			var best := -1.0
			for c in [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]:
				best = maxf(best, 1.0 - (u - c).length() / 0.36)
			# Land bridges round the ring (not across the middle).
			for pair in [[Vector2(0.5, -0.5), Vector2(0.5, 0.5)], [Vector2(0.5, 0.5), Vector2(-0.5, 0.5)], [Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)], [Vector2(-0.5, -0.5), Vector2(0.5, -0.5)]]:
				var d := _segment_distance(u, pair[0], pair[1])
				best = maxf(best, 0.3 - d * 5.0)
			# Islets in the middle and off the coasts.
			for c in [Vector2(0, 0), Vector2(0.0, -0.86), Vector2(0.86, 0.0), Vector2(0.0, 0.86), Vector2(-0.86, 0.0)]:
				best = maxf(best, 1.0 - (u - c).length() / 0.1)
			f = best
		_:
			f = 1.0 - (u * Vector2(1.0, 1.08)).length() / 0.92
	f += (_coast.get_noise_2d(p.x, p.y)) * 0.22
	# Capitals always stand well inland.
	for s in starts:
		f = maxf(f, 0.42 - p.distance_to(s) / 260.0)
	return f

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _heights() -> void:
	_origin = -(half + MARGIN)
	_n = int(ceil((size + MARGIN * 2.0) / STEP)) + 1
	_h.resize(_n * _n)
	var mountains: float = {"small": 0.35, "twin": 0.8, "archipelago": 0.55, "continent": 1.25}.get(style, 0.8)
	for r in range(_n):
		for c in range(_n):
			var p := Vector2(_origin + c * STEP, _origin + r * STEP)
			var f := _shape(p)
			var h: float
			if f > 0.0:
				var inland := smoothstep(0.0, 0.45, f)
				h = 0.6 + 6.0 * inland + _hills.get_noise_2d(p.x, p.y) * 5.0 * smoothstep(0.03, 0.35, f)
				# Ridges, strongest in the interior and far from the capitals.
				var near := INF
				for s in starts:
					near = minf(near, p.distance_to(s))
				var ridge := pow(maxf(0.0, _ridge.get_noise_2d(p.x, p.y) * 0.5 + 0.5), 3.0)
				var range_mask := smoothstep(0.18, 0.5, f) * smoothstep(90.0, 150.0, near) * mountains
				if style == "continent":
					# A long range across the middle, broken by passes.
					var spine := 1.0 - smoothstep(0.0, 70.0, absf(p.x * 0.35 + p.y * 0.94))
					var gap := smoothstep(0.25, 0.55, absf(_lakes.get_noise_2d(p.x * 0.4, 0.0)))
					range_mask = maxf(range_mask, spine * gap * smoothstep(0.2, 0.5, f) * 1.4)
				h += ridge * 22.0 * range_mask
				# Lakes on the continent, far from capitals.
				if style == "continent" and f > 0.35 and near > 140.0 and _lakes.get_noise_2d(p.x, p.y) > 0.42:
					h = minf(h, -2.5)
				# Flat ground for each capital's town.
				var flat := 1.0 - smoothstep(58.0, 92.0, near)
				h = lerpf(h, 3.2 + _hills.get_noise_2d(p.x, p.y) * 0.6, flat)
			else:
				h = maxf(0.6 + f * 90.0, -60.0)
			_h[r * _n + c] = h

## Land compared with the exported island's (50,665 dry grid points): what
## trees and deposits scale with.
func _land_share() -> float:
	var dry := 0
	for v in _h:
		if v > 0.0:
			dry += 1
	return float(dry) / 50665.0

func _heights_cm() -> Array:
	var out := []
	out.resize(_h.size())
	for i in range(_h.size()):
		out[i] = int(roundf(_h[i] * 100.0))
	return out

func height(p: Vector2) -> float:
	var c := clampi(int(roundf((p.x - _origin) / STEP)), 0, _n - 1)
	var r := clampi(int(roundf((p.y - _origin) / STEP)), 0, _n - 1)
	return _h[r * _n + c]

func _slope(p: Vector2) -> float:
	return (absf(height(p + Vector2(3, 0)) - height(p - Vector2(3, 0))) + absf(height(p + Vector2(0, 3)) - height(p - Vector2(0, 3)))) / 6.0

func _random_point() -> Vector2:
	return Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))

func _near_start(p: Vector2, reach: float) -> bool:
	for s in starts:
		if p.distance_to(s) < reach:
			return true
	return false

func _sea_near(from: Vector2, home: Vector2) -> Vector2:
	var out := (from - home).normalized() if from.distance_to(home) > 1.0 else Vector2(1, 0)
	for radius in range(60, int(size), 8):
		for k in range(24):
			var p := home + out.rotated(TAU * k / 24.0 * (1 if k % 2 == 0 else -1) * 0.5) * radius
			if height(p) < -6.0 and absf(p.x) < half and absf(p.y) < half:
				return p
	return from

# ---------------------------------------------------------------- trees and deposits

func _trees() -> Array:
	var out := []
	var area := _land_share()
	var groves := int(22 * area)
	var g := 0
	var tries := 0
	while g < groves and tries < groves * 40:
		tries += 1
		var c := _random_point()
		var h := height(c)
		if h < 2.0 or h > 14.0 or _near_start(c, 70.0):
			continue
		for k in range(_rng.randi_range(18, 38)):
			var p := c + Vector2(_rng.randfn(0.0, 9.0), _rng.randfn(0.0, 9.0))
			if height(p) > 1.2 and height(p) < 16.0 and _slope(p) < 0.5 and not _near_start(p, 50.0):
				out.append({"x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01), "scale": snappedf(_rng.randf_range(1.0, 1.7), 0.01), "kind": "real", "grove": g})
		g += 1
	for k in range(int(125 * area)):
		var p := _random_point()
		if height(p) > 1.2 and height(p) < 16.0 and _slope(p) < 0.5 and not _near_start(p, 50.0):
			out.append({"x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01), "scale": snappedf(_rng.randf_range(1.0, 1.6), 0.01), "kind": "real", "grove": -1})
	return out

## Deposits sit at hex centres, like the exported island's, one to a hex, and
## never in a hex a starting town stands on.
func _snap(p: Vector2) -> Vector2:
	return _hex_centre(p)

func _free(p: Vector2, taken: Array, gap: float) -> bool:
	for q in taken:
		if p.distance_to(q) < gap:
			return false
	return true

func _deposits() -> Array:
	var out := []
	var taken := []
	# Each capital: oil, iron and gold within reach.
	for s in starts:
		for type in ["oil", "iron", "gold"]:
			for tries in range(300):
				var p: Vector2 = _snap(s + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(55.0, 95.0))
				var h := height(p)
				if h > 1.5 and h < 14.0 and _slope(p) < 0.35 and _free(p, taken, 24.0) and not _near_start(p, 50.0):
					out.append({"type": type, "x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01)})
					taken.append(p)
					break
	var area := _land_share() * 0.85
	var land := {"iron": 13, "oil": 11, "gold": 8, "silicon": 11, "uranium": 9, "diamond": 7}
	for type in land:
		var want := int(round(land[type] * area))
		var placed := 0
		for tries in range(want * 200):
			if placed >= want:
				break
			var p := _snap(_random_point())
			var h := height(p)
			var mountain: bool = type in ["iron", "diamond", "uranium"]
			if h > 1.5 and h < (24.0 if mountain else 12.0) and _slope(p) < (0.6 if mountain else 0.35) and _free(p, taken, 24.0) and not _near_start(p, 48.0):
				out.append({"type": type, "x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01)})
				taken.append(p)
				placed += 1
	area = maxf(1.0, pow(size / 640.0, 1.5)) if style != "small" else 0.6
	var sea := {"seaOil": 10, "fish": 6}
	for type in sea:
		var want := int(round(sea[type] * area))
		var placed := 0
		for tries in range(want * 300):
			if placed >= want:
				break
			var p := _snap(_random_point())
			var h := height(p)
			var ok: bool = (h < -4.0 and h > -30.0) if type == "seaOil" else (h < -1.5 and h > -7.0)
			if ok and _free(p, taken, 30.0):
				out.append({"type": type, "x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01)})
				taken.append(p)
				placed += 1
	return out
