extends RefCounted
## The shape of the land, refined as the map loads.
##
## The exported height grid (2.5 m cells) has hard steps, so shores zigzag and
## inland lakes were only the sea surface showing through hollows that dip a
## little below sea level: flat, sandy-bottomed, with a band of surf round them.
## Here the heights are smoothed, and every body of water that does not reach
## the open sea becomes a lake with a real basin, deepening from its shore
## toward the middle. The lakes are recorded (lake_mask) so the water shader
## can treat them as still water, without surf.

const SMOOTH_PASSES := 2
const LAKE_SLOPE := 0.6     ## metres of depth gained per 2.5 m cell from the shore
const LAKE_DEPTH := 4.5     ## deepest a lake gets
const OPEN_DEPTH := 1.5     ## water this deep, reached from the map's edge, is the open sea
const COAST_CELLS := 6      ## how far (in 2.5 m cells) the sea's own shallows reach from that water
const BANK := 0.5           ## a lake's shore rises at least this far above the water
const SEA_SHELF := 0.45     ## metres of depth per cell off the sea's shore
const LIFT := 0.5           ## land lower than this above the sea is raised clear of the swell

## Smooths `heights` in place and carves the lake basins. Returns the lake
## mask (1 where a grid cell is lake water).
static func refine(heights: PackedFloat32Array, n: int, sea: float) -> PackedByteArray:
	# Smoothing: a 3x3 weighted blur, keeping land land and sea sea.
	for pass_i in range(SMOOTH_PASSES):
		var out := heights.duplicate()
		for r in range(1, n - 1):
			for c in range(1, n - 1):
				var i := r * n + c
				var sum := heights[i] * 4.0
				sum += (heights[i - 1] + heights[i + 1] + heights[i - n] + heights[i + n]) * 2.0
				sum += heights[i - n - 1] + heights[i - n + 1] + heights[i + n - 1] + heights[i + n + 1]
				var v := sum / 16.0
				# Never let smoothing move the shoreline: keep each cell on its side of the sea.
				if (heights[i] >= sea) != (v >= sea):
					v = sea + (0.05 if heights[i] >= sea else -0.05)
				out[i] = v
		heights = out
	# Open sea: water reached from the edge of the grid through real depth
	# (the island's middle is almost flat, and its hollows touch the sea only
	# through ankle-deep channels), then the shallows along its own coast.
	var ocean := PackedByteArray()
	ocean.resize(n * n)
	var stack: Array[int] = []
	for k in range(n):
		for i in [k, (n - 1) * n + k, k * n, k * n + n - 1]:
			if heights[i] < sea - OPEN_DEPTH and ocean[i] == 0:
				ocean[i] = 1
				stack.append(i)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var r := i / n
		var c := i % n
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var rr: int = r + d[0]
			var cc: int = c + d[1]
			if rr < 0 or cc < 0 or rr >= n or cc >= n:
				continue
			var j := rr * n + cc
			if ocean[j] == 0 and heights[j] < sea - OPEN_DEPTH:
				ocean[j] = 1
				stack.append(j)
	var coast: Array[int] = []
	for i in range(n * n):
		if ocean[i] == 1:
			coast.append(i)
	for step in range(COAST_CELLS):
		var next: Array[int] = []
		for i in coast:
			var r := i / n
			var c := i % n
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var rr: int = r + d[0]
				var cc: int = c + d[1]
				if rr < 0 or cc < 0 or rr >= n or cc >= n:
					continue
				var j := rr * n + cc
				if ocean[j] == 0 and heights[j] < sea:
					ocean[j] = 1
					next.append(j)
		coast = next
	# Lakes: the rest of the wet cells. Distance to the shore, in cells, by a
	# breadth-first sweep inward from the shoreline.
	var lake := PackedByteArray()
	lake.resize(n * n)
	var dist := PackedInt32Array()
	dist.resize(n * n)
	dist.fill(-1)
	var front: Array[int] = []
	for i in range(n * n):
		if heights[i] < sea and ocean[i] == 0:
			lake[i] = 1
	# Distance from the shore for every wet cell, sea and lake alike.
	for i in range(n * n):
		if heights[i] >= sea:
			continue
		var r := i / n
		var c := i % n
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var rr: int = r + d[0]
			var cc: int = c + d[1]
			if rr >= 0 and cc >= 0 and rr < n and cc < n and heights[rr * n + cc] >= sea:
				dist[i] = 1
				front.append(i)
				break
	while not front.is_empty():
		var next: Array[int] = []
		for i in front:
			var r := i / n
			var c := i % n
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var rr: int = r + d[0]
				var cc: int = c + d[1]
				if rr < 0 or cc < 0 or rr >= n or cc >= n:
					continue
				var j := rr * n + cc
				if heights[j] < sea and dist[j] < 0:
					dist[j] = dist[i] + 1
					next.append(j)
		front = next
	for i in range(n * n):
		if lake[i] == 1:
			heights[i] = minf(heights[i], sea - minf(0.35 + dist[i] * LAKE_SLOPE, LAKE_DEPTH))
		elif heights[i] < sea and dist[i] > 0:
			# The sea shelves steadily from its shore too (it only ever gets deeper
			# here), so surf is a line at the waterline, not a white sheet over flats.
			heights[i] = minf(heights[i], sea - minf(0.3 + dist[i] * SEA_SHELF, 8.0))
		elif heights[i] >= sea and heights[i] < sea + BANK:
			# Dry land right beside a lake gets a clear bank instead of a film of water.
			var r := i / n
			var c := i % n
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var rr: int = r + d[0]
				var cc: int = c + d[1]
				if rr >= 0 and cc >= 0 and rr < n and cc < n and lake[rr * n + cc] == 1:
					heights[i] = sea + BANK
					break
	# One more light blur over the basins only, so their floors are smooth.
	var out2 := heights.duplicate()
	for r in range(1, n - 1):
		for c in range(1, n - 1):
			var i := r * n + c
			if lake[i] == 1:
				var v := (heights[i] * 2.0 + heights[i - 1] + heights[i + 1] + heights[i - n] + heights[i + n]) / 6.0
				out2[i] = minf(v, sea - 0.2)
	heights = out2
	# Dry land barely above the sea let the swell (about 0.3 m) wash over it
	# as a film of water with surf: the "lakes by water level". Land below
	# LIFT is raised smoothly (order kept) to stand clear of the waves.
	for i in range(n * n):
		var above := heights[i] - sea
		if above >= 0.0 and above < LIFT:
			heights[i] = sea + LIFT * 0.6 + above * 0.4
	_result = heights
	return lake

static var _result := PackedFloat32Array()

## The refined heights from the last refine() (packed arrays are values in
## GDScript, so the caller takes them back from here).
static func heights() -> PackedFloat32Array:
	return _result
