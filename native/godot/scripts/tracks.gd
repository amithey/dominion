extends RefCounted
## Worn dirt tracks across the open land: the paths people and carts wore between the capitals and out to every deposit, wandering
## round the hills and breaking off where they would meet water. Visual only (the terrain shader draws them from a mask, and the
## grass keeps off them); roads, railways and routes for units are untouched. The network is grown like a spanning tree: every
## deposit joins the nearest place already connected, if that is within reach, so the tracks make a web round the capitals
## instead of a hundred lines to one point.
const REACH := 170.0       # farthest a track runs to join a place, metres
const WIDTH := 1.9         # half width of the worn strip, metres
const WOBBLE := 9.0        # how far a track wanders off the straight line, metres

static func _hash(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

## The mask, one byte per cell of the height grid (255 = bare, worn ground). `w` is the world (height_at, map, grid_*).
static func build(w: Node) -> PackedByteArray:
	var n: int = w.grid_size
	var mask := PackedByteArray()
	mask.resize(n * n)
	var sea := float(w.map.seaLevel)
	var places: Array = []
	for s in w.map.startPositions:
		places.append(Vector2(s[0], s[1]))
	var connected: Array = []
	# The capitals join in a ring, nearest first.
	if places.size() > 1:
		var ring: Array = places.duplicate()
		ring.sort_custom(func(a: Vector2, b: Vector2): return atan2(a.y, a.x) < atan2(b.y, b.x))
		for i in range(ring.size()):
			_track(w, mask, n, sea, ring[i], ring[(i + 1) % ring.size()])
		connected = places.duplicate()
	var pending: Array = []
	for d in w.map.deposits:
		if not d.get("water", false) and w.height_at(d.x, d.z) > sea + 1.0:
			pending.append(Vector2(d.x, d.z))
	while not pending.is_empty() and not connected.is_empty():
		var best_i := -1
		var best_j := -1
		var best_d := REACH
		for i in range(pending.size()):
			for j in range(connected.size()):
				var dist: float = pending[i].distance_to(connected[j])
				if dist < best_d:
					best_d = dist
					best_i = i
					best_j = j
		if best_i < 0:
			break
		_track(w, mask, n, sea, connected[best_j], pending[best_i])
		connected.append(pending[best_i])
		pending.remove_at(best_i)
	return mask

static func _track(w: Node, mask: PackedByteArray, n: int, sea: float, a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.01)
	var side := Vector2(-dir.y, dir.x)
	var seed := a.x * 0.37 + b.y * 0.51
	var steps := int(length / 1.2)
	var last := Vector2.INF
	for k in range(steps + 1):
		var t := float(k) / float(maxi(steps, 1))
		var bow := sin(t * PI)   # no wander at the ends, so a track arrives where it is going
		var off := (sin(t * length / 55.0 + seed) * 0.6 + sin(t * length / 21.0 + seed * 2.3) * 0.4) * WOBBLE * bow
		var p := a + dir * (t * length) + side * off
		if w.height_at(p.x, p.y) < sea + 0.7 or w.lake_at(Vector3(p.x, 0.0, p.y)):
			last = Vector2.INF
			continue
		_stamp(w, mask, n, p)
		last = p

static func _stamp(w: Node, mask: PackedByteArray, n: int, p: Vector2) -> void:
	var step: float = w.grid_step
	var ci := int(round((p.x - w.grid_origin.x) / step))
	var cj := int(round((p.y - w.grid_origin.y) / step))
	var r := int(ceil((WIDTH + 1.2) / step))
	for dj in range(-r, r + 1):
		var j := cj + dj
		if j < 0 or j >= n:
			continue
		for di in range(-r, r + 1):
			var i := ci + di
			if i < 0 or i >= n:
				continue
			var d := Vector2(di, dj).length() * step
			var v := int(255.0 * (1.0 - smoothstep(WIDTH * 0.45, WIDTH + 1.2, d)))
			if v > mask[j * n + i]:
				mask[j * n + i] = v
