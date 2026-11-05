extends RefCounted
## Rolling hills on the dry land (applied to the height grid as the map loads, before anything stands on it): broad swells a few
## metres high and long hollows between them, so the island is no longer a billiard table and the sun finds slopes to light.
## They fade to nothing toward the shore and the lakes, and round everything the map puts on the ground (the start positions,
## buildings, deposits and units), so every start, district site and resource keeps the flat ground it was laid out on. The slopes
## stay well inside the building limits (a hex may differ by 6 m, a site by 3.5 m).
const HEIGHT := 4.4        # metres, broad swells
const DETAIL := 1.1        # metres, the smaller rises on them
const KEEP_FADE := 18.0    # the width of the fade out of the flat ground round every placed thing, metres
## Flat radius round a start position, a building, a deposit and a unit.
const KEEP := {"startPositions": 70.0, "buildings": 26.0, "deposits": 14.0, "units": 10.0}

static func apply(heights: PackedFloat32Array, n: int, step: float, origin: Vector2, sea: float, map: Dictionary) -> void:
	var broad := FastNoiseLite.new()
	broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad.seed = 4242
	broad.frequency = 1.0 / 130.0
	broad.fractal_octaves = 2
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.seed = 777
	fine.frequency = 1.0 / 48.0
	# Distance (m) to the nearest placed thing, stamped into a grid: each point lowers the allowance round it.
	var keep := PackedFloat32Array()
	keep.resize(n * n)
	keep.fill(1.0)
	var points: Array = []   # [position, flat radius]
	for s in map.get("startPositions", []):
		points.append([Vector2(s[0], s[1]), KEEP["startPositions"]])
	for key in ["buildings", "deposits", "units"]:
		for e in map.get(key, []):
			if e is Dictionary and e.has("x") and e.has("z"):
				points.append([Vector2(float(e.x), float(e.z)), KEEP[key]])
	for entry in points:
		var p: Vector2 = entry[0]
		var flat: float = entry[1]
		var reach := flat + KEEP_FADE
		var cells := int(ceil(reach / step))
		var ci := int(round((p.x - origin.x) / step))
		var cj := int(round((p.y - origin.y) / step))
		for dj in range(-cells, cells + 1):
			var j := cj + dj
			if j < 0 or j >= n:
				continue
			for di in range(-cells, cells + 1):
				var i := ci + di
				if i < 0 or i >= n:
					continue
				var d := Vector2(di, dj).length() * step
				var a := smoothstep(flat, reach, d)
				var idx := j * n + i
				if a < keep[idx]:
					keep[idx] = a
	for j in range(n):
		for i in range(n):
			var idx := j * n + i
			var above: float = heights[idx] - sea
			if above < 1.5:
				continue
			var x := origin.x + i * step
			var z := origin.y + j * step
			var land := smoothstep(1.5, 5.5, above)
			var shape := broad.get_noise_2d(x, z) * HEIGHT + fine.get_noise_2d(x, z) * DETAIL
			# Mostly rises, with the hollows shallower than the swells are tall.
			shape = shape if shape > 0.0 else shape * 0.45
			heights[idx] += shape * land * keep[idx]
