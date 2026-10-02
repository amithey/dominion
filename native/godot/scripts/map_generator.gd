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
##   highlands    Highlands     1040 m   5 regions on a mountainous plateau
##   great_lakes  Great Lakes   1520 m   9 regions on a continent full of lakes
##   pangaea      Pangaea       1680 m   10 regions on one supercontinent split by a range
##   ten_isles    Ten Isles     1760 m   10 islands round an ocean, with a lone central isle
##
## The larger maps ("slots") place their capitals on a ring, joined by broad,
## flat land routes; a match uses as many of them as it has nations
## (match_setup.gd spreads the nations evenly round the ring).
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
	"frontier": {"name": "Great Frontier", "size": 1120, "slots": 6, "desc": "Six spacious starting regions on a broad continent, with open inland routes."},
	"inland_sea": {"name": "Inland Sea", "size": 1280, "slots": 7, "desc": "Seven starting regions around a central sea; a continuous land belt links the coasts."},
	"crown": {"name": "Crown Isles", "size": 1440, "slots": 8, "desc": "Eight large islands around a lagoon, linked by coastal land bridges."},
	"highlands": {"name": "Highlands", "size": 1040, "slots": 5, "desc": "Five regions on a high plateau; mountain walls funnel armies through the valleys."},
	"great_lakes": {"name": "Great Lakes", "size": 1520, "slots": 9, "ring": 0.7, "desc": "Nine regions on a continent dotted with lakes; a land ring links every capital."},
	"pangaea": {"name": "Pangaea", "size": 1680, "slots": 10, "ring": 0.7, "desc": "Ten regions on one supercontinent, split by a mountain range with passes."},
	"ten_isles": {"name": "Ten Isles", "size": 1760, "slots": 10, "desc": "Ten islands round an open ocean, joined by narrow land bridges; a rich isle alone in the middle."},
	"continents_plus": {"name": "Continents and Distant Lands", "size": 1600, "slots": 8, "desc": "Two homeland continents joined only by a far southern isthmus, and between them the Distant Lands: rich islands no one starts on, waiting for the first navy."},
	"fractal": {"name": "Fractal", "size": 1280, "slots": 6, "desc": "Wild, ragged land of peninsulas, inlets and lakes, every region different; a land route still links each capital to the next."},
	"middle_east": {"name": "Middle East", "size": 1600, "slots": 8, "real": true, "desc": "The real map, from the Aegean to Persia and from Moscow to Arabia: the Caspian, Black and Red seas, the Caucasus and the Zagros. Each nation whose capital lies here starts there."},
	"europe": {"name": "Europe", "size": 1760, "slots": 9, "real": true, "desc": "The real map, from Iberia to the Urals and down to the Levant: the Alps, the Baltic and the Mediterranean. Each nation whose capital lies here starts there."},
	"east_asia": {"name": "East Asia", "size": 1760, "slots": 9, "real": true, "desc": "The real map, from India to Japan and from Mongolia to Java: the Himalaya, the Tibetan plateau and the island chains. Island nations need a navy."},
}
## The real-world maps (world_geography.gd): their capitals stand where the real ones do.
const REAL := ["middle_east", "europe", "east_asia"]
const Geography = preload("res://scripts/world_geography.gd")
## Continents and Distant Lands: the islands between the homelands.
const DISTANT := [Vector2(0.0, -0.62), Vector2(0.03, -0.25), Vector2(-0.03, 0.12), Vector2(0.04, 0.45)]
var _geo := {}
## Capacity describes prepared geography slots, independently of active nations.
## "ring": how far out the capitals stand (a share of the half-width; 0.64 when
## unset), so that on the great continents they are near enough the coast for
## a harbour.
const EXPANDED := ["frontier", "inland_sea", "crown", "highlands", "great_lakes", "pangaea", "ten_isles", "fractal"]
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
	if style in REAL:
		_geo = Geography.raster(style, size, 360)
	starts = _start_positions()
	_heights()
	var old_starts: Array = data.startPositions.duplicate(true)
	# (the regions chosen on the New Game screen, by nation: match_setup.gd "starts")
	var chosen: Array = data.get("startSlots", [])
	data.erase("startSlots")
	var active_starts := []
	if style in REAL:
		active_starts = _real_starts(data.get("nations", []), old_starts.size(), chosen)
	else:
		active_starts = _spread_starts(old_starts.size(), chosen)
	var old_hq := {}
	for b in data.buildings:
		if b.key == "hq":
			old_hq[int(b.owner)] = Vector2(float(b.x), float(b.z))
	data.mapSize = int(size)
	data.style = key
	data.mapSeed = seed
	# Geography contract for future 6-8 nation setup; no invented nations or armies.
	data.spawnPositions = starts.map(func(p): return [p.x, p.y])
	data.mapCapacity = starts.size()
	data.grid = {"origin": [_origin, _origin], "step": STEP, "size": _n, "heightsCm": _heights_cm()}
	data.territory = data.get("territory", {}).duplicate()
	data.territory.halfMap = half
	# Towns and armies move with their capital (hex offsets stay hex offsets).
	for group in ["buildings", "units"]:
		for e in data[group]:
			var owner := int(e.owner)
			var delta: Vector2 = active_starts[owner] - old_hq.get(owner, Vector2.ZERO)
			e.x = float(e.x) + delta.x
			e.z = float(e.z) + delta.y
	data.startPositions = []
	for i in range(old_starts.size()):
		var delta: Vector2 = active_starts[i] - old_hq.get(i, Vector2.ZERO)
		data.startPositions.append([float(old_starts[i][0]) + delta.x, float(old_starts[i][1]) + delta.y])
	# Warships start at sea off their own coast.
	var naval := ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub"]
	for u in data.units:
		if u.key in naval:
			var at := _sea_near(Vector2(float(u.x), float(u.z)), active_starts[int(u.owner)])
			u.x = at.x
			u.z = at.y
	data.trees = _trees()
	data.deposits = _deposits()

# ---------------------------------------------------------------- shape

## Capitals: hex centres, so every town's hex offsets stay on the grid.
## True start locations: each nation at its own capital when the map shows
## it; the others at the open starts (other great cities), then anywhere free.
func _real_starts(nations: Array, count: int, chosen := []) -> Array:
	var slots: Array = Geography.MAPS[style].starts
	var taken := {}
	var out: Array = _chosen_starts(count, chosen, taken)
	for i in range(count):
		if out[i] != null:
			continue
		var id: String = str(nations[i].get("id", "")) if i < nations.size() else ""
		for k in range(slots.size()):
			if id != "" and slots[k][2] == id and not taken.has(k):
				taken[k] = true
				out[i] = starts[k]
				break
	# The others take the open cities in the map's order. In a duel the two face
	# each other across the map, as on the other maps: an open city within a
	# quarter of the map of the other capital is passed over (two newcomers to
	# the Middle East got Riyadh and Baghdad, 320 m apart on a 1600 m map).
	for pass_open in [true, false]:
		for i in range(count):
			if out[i] != null:
				continue
			var pick := -1
			var far := -1
			var far_gap := -1.0
			for k in range(slots.size()):
				if taken.has(k) or (pass_open and slots[k][2] != ""):
					continue
				var gap := INF
				for s in out:
					if s != null: gap = minf(gap, starts[k].distance_to(s))
				if pick < 0 and (count > 2 or gap >= size * 0.25):
					pick = k
				if gap > far_gap:
					far = k
					far_gap = gap
			if pick < 0: pick = far
			if pick >= 0:
				taken[pick] = true
				out[i] = starts[pick]
	return out

## The generated maps: the nations spread evenly round the regions, but for
## those whose region was chosen; a nation whose even share another took by
## choice goes to the free region farthest from every capital placed.
func _spread_starts(count: int, chosen: Array) -> Array:
	var taken := {}
	var out: Array = _chosen_starts(count, chosen, taken)
	for i in range(count):
		if out[i] != null:
			continue
		var k := int(i * starts.size() / count)
		if taken.has(k):
			var far_gap := -1.0
			for j in range(starts.size()):
				if taken.has(j):
					continue
				var gap := INF
				for s in out:
					if s != null: gap = minf(gap, starts[j].distance_to(s))
				if gap > far_gap:
					far_gap = gap
					k = j
		taken[k] = true
		out[i] = starts[k]
	return out

## The regions chosen on the New Game screen (-1: automatic), each taken once.
func _chosen_starts(count: int, chosen: Array, taken: Dictionary) -> Array:
	var out: Array = []
	out.resize(count)
	for i in range(mini(count, chosen.size())):
		var k := int(chosen[i])
		if k >= 0 and k < starts.size() and not taken.has(k):
			taken[k] = true
			out[i] = starts[k]
	return out

## Where map `key`'s capital regions lie, -1..1 across the map (x east, y
## south), in region order, without building the map (the New Game screen).
static func slot_positions(key: String) -> Array:
	var g = load("res://scripts/map_generator.gd").new()
	g.style = key
	g.size = float(MAPS[key].size)
	g.half = g.size * 0.5
	return g._start_positions().map(func(p): return p / g.half)

func _start_positions() -> Array:
	var at := []
	if style in REAL:
		for s in Geography.MAPS[style].starts:
			at.append(_hex_centre(Geography.to_world(style, size, s[0], s[1])))
		return at
	if style == "continents_plus":
		at = [Vector2(-0.72, -0.5), Vector2(-0.38, -0.62), Vector2(-0.72, 0.35), Vector2(-0.38, 0.5),
			Vector2(0.72, 0.5), Vector2(0.38, 0.62), Vector2(0.72, -0.35), Vector2(0.38, -0.5)]
		return at.map(func(p): return _hex_centre(p * half))
	if style in EXPANDED:
		var count := int(MAPS[style].slots)
		for i in range(count):
			at.append(_hex_centre(Vector2.from_angle(-PI / 4.0 + TAU * i / count) * half * float(MAPS[style].get("ring", 0.64))))
		return at
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

## Land-ness: above 0 is land, the coast at 0, below is sea. `route`: the
## distance to the land routes, when the caller has it already.
func _shape(p: Vector2, route := -1.0) -> float:
	var u := p / half   # -1..1 across the map
	var f := 0.0
	if style in REAL:
		f = _geo_sample(_geo.sdf, p) / 230.0 + _coast.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.06
		for s in starts:
			f = maxf(f, 0.28 - p.distance_to(s) / 160.0)   # (the ground for a capital's town, no more)
		return f
	match style:
		"frontier":
			f = 1.0 - (u * Vector2(1.0, 1.04)).length() / 0.92
		"inland_sea":
			f = minf((u.length() - 0.32) * 2.8, (0.93 - u.length()) * 2.8)
		"crown":
			f = -1.0
			for s in starts:
				f = maxf(f, 1.0 - p.distance_to(s) / (half * 0.25))
		"ten_isles":
			f = 1.0 - p.length() / (half * 0.16)   # the lone isle in the middle
			for s in starts:
				f = maxf(f, 1.0 - p.distance_to(s) / (half * 0.17))
		"highlands":
			f = 1.0 - (u * Vector2(1.0, 1.02)).length() / 0.9
		"great_lakes":
			f = 1.0 - (u * Vector2(1.0, 1.06)).length() / 0.89
		"pangaea":
			f = 1.0 - (u * Vector2(1.04, 1.0)).length() / 0.89
		"continents_plus":
			# Two homelands, a thin isthmus far to the south, and the Distant Lands between.
			var wobble := _hills.get_noise_2d(p.x * 0.5, p.y * 0.5) * 0.35
			var west := 1.0 - ((u - Vector2(-0.55, 0.0)) / Vector2(0.34, 0.86)).length() + wobble
			var east := 1.0 - ((u - Vector2(0.55, 0.0)) / Vector2(0.34, 0.86)).length() + wobble
			var isthmus := 0.3 - absf(u.y - 0.8 - sin(u.x * 9.0) * 0.04) * 7.0 if absf(u.x) < 0.42 else -1.0
			f = maxf(maxf(west, east), isthmus)
			for c in DISTANT:
				f = maxf(f, 1.0 - (u - c).length() / 0.12 + _hills.get_noise_2d(p.x * 1.6, p.y * 1.6) * 0.7)
		"fractal":
			f = 0.2 - u.length() * 0.45 + _coast.get_noise_2d(p.x * 1.8, p.y * 1.8) * 0.9 + _hills.get_noise_2d(p.x * 0.7, p.y * 0.7) * 0.35
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
	# Guaranteed broad land routes round the ring, with sea retained in the middle.
	if style in EXPANDED:
		# (on Fractal a narrower, wandering route, so the land stays ragged)
		var wide: float = 26.0 + _hills.get_noise_2d(p.x, p.y) * 10.0 if style == "fractal" else 42.0
		f = maxf(f, (wide - (route if route >= 0.0 else _route_distance(p))) / 110.0)
	# Capitals always stand well inland.
	for s in starts:
		f = maxf(f, 0.42 - p.distance_to(s) / 260.0)
	return f

## A raster of world_geography.gd (sdf or mountains) at `p`, bilinearly.
func _geo_sample(grid: PackedFloat32Array, p: Vector2) -> float:
	var n: int = _geo.cells
	var x := clampf((p.x + half) / size * n - 0.5, 0.0, n - 1.001)
	var y := clampf((p.y + half) / size * n - 0.5, 0.0, n - 1.001)
	var c := int(x)
	var r := int(y)
	var fx := x - c
	var fy := y - r
	var c1 := mini(c + 1, n - 1)
	var r1 := mini(r + 1, n - 1)
	var top := lerpf(grid[r * n + c], grid[r * n + c1], fx)
	var bottom := lerpf(grid[r1 * n + c], grid[r1 * n + c1], fx)
	return lerpf(top, bottom, fy)

func _route_distance(p: Vector2) -> float:
	var nearest := INF
	for i in range(starts.size()):
		nearest = minf(nearest, _segment_distance(p, starts[i], starts[(i + 1) % starts.size()]))
	return nearest

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _heights() -> void:
	_origin = -(half + MARGIN)
	_n = int(ceil((size + MARGIN * 2.0) / STEP)) + 1
	_h.resize(_n * _n)
	var mountains: float = {"small": 0.35, "twin": 0.8, "archipelago": 0.55, "continent": 1.25, "highlands": 1.9, "great_lakes": 0.6, "pangaea": 1.1, "ten_isles": 0.45, "middle_east": 0.3, "europe": 0.3, "east_asia": 0.3, "continents_plus": 0.9, "fractal": 0.7}.get(style, 0.8)
	var lakes: float = {"continent": 0.42, "pangaea": 0.42, "great_lakes": 0.28}.get(style, 2.0)   # noise above this is a lake
	var expanded := style in EXPANDED
	for r in range(_n):
		for c in range(_n):
			var p := Vector2(_origin + c * STEP, _origin + r * STEP)
			var route := _route_distance(p) if expanded else INF
			var f := _shape(p, route)
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
				if style == "continent" or style == "pangaea":
					# A long range across the middle, broken by passes.
					var spine := 1.0 - smoothstep(0.0, 70.0, absf(p.x * 0.35 + p.y * 0.94))
					var gap := smoothstep(0.25, 0.55, absf(_lakes.get_noise_2d(p.x * 0.4, 0.0)))
					range_mask = maxf(range_mask, spine * gap * smoothstep(0.2, 0.5, f) * 1.4)
				if style in REAL:
					# The real ranges: the Alps, the Caucasus, the Zagros, the Himalaya...
					var real_range: float = _geo_sample(_geo.mountains, p)
					range_mask = maxf(range_mask, real_range * 2.6 * smoothstep(0.05, 0.3, f) * smoothstep(90.0, 150.0, near))
					h += real_range * 16.0 * smoothstep(0.05, 0.3, f) * smoothstep(80.0, 140.0, near)
				h += ridge * 22.0 * range_mask
				# Lakes on the continent, far from capitals.
				if f > 0.35 and near > 140.0 and _lakes.get_noise_2d(p.x, p.y) > lakes:
					h = minf(h, -2.5)
				# Flat ground for each capital's town.
				var flat := 1.0 - smoothstep(58.0, 92.0, near)
				h = lerpf(h, 3.2 + _hills.get_noise_2d(p.x, p.y) * 0.6, flat)
			else:
				h = maxf(0.6 + f * 90.0, -60.0)
			if expanded:
				# Flatten the centre of each passage for ground units and future roads.
				var road := 1.0 - (smoothstep(10.0, 22.0, route) if style == "fractal" else smoothstep(18.0, 36.0, route))
				h = lerpf(h, 3.2, road)
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
	# Snapping a sampled point to a hex can push it outside the map.
	if absf(p.x) >= half or absf(p.y) >= half:
		return false
	for q in taken:
		if p.distance_to(q) < gap:
			return false
	return true

func _deposits() -> Array:
	var out := []
	var taken := []
	# Each capital: oil, iron and gold within reach.
	# (A capital on a small island, as real ones can be, takes what land it has:
	# a closer ring, then a wider one.)
	for s in starts:
		for type in ["oil", "iron", "gold"]:
			var placed := false
			for ring in [[55.0, 95.0, 50.0, 0.35, 1.5, 14.0], [38.0, 108.0, 34.0, 0.5, 1.2, 16.0]]:
				if placed:
					break
				for tries in range(300):
					var p: Vector2 = _snap(s + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(ring[0], ring[1]))
					var h := height(p)
					if h > ring[4] and h < ring[5] and _slope(p) < ring[3] and _free(p, taken, 20.0 if ring[0] < 50.0 else 24.0) and not _near_start(p, ring[2]):
						out.append({"type": type, "x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01)})
						taken.append(p)
						placed = true
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
	# The Distant Lands are rich: each island holds gold, diamonds, uranium and oil.
	if style == "continents_plus":
		for c in DISTANT:
			for type in ["gold", "diamond", "uranium", "oil"]:
				for tries in range(200):
					var p: Vector2 = _snap(c * half + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, half * 0.07))
					var h := height(p)
					if h > 1.5 and h < 16.0 and _slope(p) < 0.5 and _free(p, taken, 20.0):
						out.append({"type": type, "x": snappedf(p.x, 0.01), "z": snappedf(p.y, 0.01)})
						taken.append(p)
						break
	return out
