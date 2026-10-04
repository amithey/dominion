extends RefCounted
## How a rival nation lays out its towns: by zones and in its own style, not a
## building dropped on whichever free hex came up first (ai.find_spot).
##
## Zones, in rings of hexes round the nearest town centre: the civic heart
## (town hall, market, bank, schools, hospital) on rings 1-2, homes on 1-3,
## industry and depots on 2-4 and the heavy plant (power, refinery, reactor)
## further out, farms on the outskirts (3-6), and the army on 2-6 on the side
## that faces its nearest rival. Every town grows outward, touching what it has.
##
## Styles, after how each nation builds its cities:
##   grid      long rows with a street of open hexes between them (the American
##             and Australian grid; the planned Gulf capitals)
##   compact   dense, filled-in rings round an old centre (European, British,
##             Japanese, Korean, Israeli, Turkish towns)
##   axial     a monumental avenue through the centre, the town drawn out along
##             it (Soviet, Chinese and North Korean planning; Cairo, Tehran)
##   linear    a ribbon along one line (Saudi Arabia's linear cities)
##   organic   grown, not drawn: zones loosely kept (South Asian, Southeast
##             Asian, Brazilian, Iraqi, Syrian, Afghan towns)

const STYLE := {"usa": "grid", "australia": "grid", "eu": "compact", "uk": "compact", "japan": "compact", "south_korea": "compact",
	"israel": "compact", "turkiye": "compact", "china": "axial", "russia": "axial", "north_korea": "axial", "ukraine": "axial",
	"iran": "axial", "egypt": "axial", "saudi": "linear", "india": "organic", "pakistan": "organic", "indonesia": "organic",
	"brazil": "organic", "iraq": "organic", "syria": "organic", "afghanistan": "organic"}
## zone -> [nearest ring, farthest ring]
const RINGS := {"civic": [1, 2], "home": [1, 3], "industry": [2, 4], "heavy": [3, 5], "farm": [3, 6], "army": [2, 6], "airbase": [4, 7]}
const ZONE := {"market": "civic", "bank": "civic", "cityHall": "civic", "school": "civic", "library": "civic", "university": "civic",
	"hospital": "civic", "policeStation": "civic", "museum": "civic", "courthouse": "civic", "tvStation": "civic", "intelAgency": "civic",
	"park": "home", "stadium": "home", "cottage": "home", "residential": "home", "apartments": "home", "luxuryVillas": "home", "workerHouse": "home",
	"warehouse": "industry", "foodDepot": "industry", "techPark": "industry", "chipFab": "industry", "waterTreatment": "industry", "mountainMine": "industry",
	"powerPlant": "heavy", "nuclearReactor": "heavy", "oilRefinery": "heavy", "solarFarm": "farm", "farm": "farm", "fishingWharf": "farm",
	"barracks": "army", "housing": "army", "tankFactory": "army", "ammoDepot": "army", "commandCenter": "civic", "samSite": "army", "bunker": "army",
	"helipad": "army", "airfield": "airbase", "missileSilo": "airbase", "shipyard": "army", "port": "industry"}
const TOWNS := ["hq", "cityCenter", "villageCenter"]
const CHECKS := 30

static func style_of(w: Node, owner: int) -> String:
	return STYLE.get(preload("res://scripts/factions.gd").identity(w, owner), "organic")

static func ring(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2

## The best hex for district `key` among `options` (hexes next to the nation's
## own districts), or null.
static func best(w: Node, owner: int, key: String, options: Array) -> Variant:
	var towns: Array = w.buildings.filter(func(b): return b.owner == owner and not b.dead and b.key in TOWNS)
	if towns.is_empty() or options.is_empty():
		return null
	var centres: Array = towns.map(func(b): return w.logistics.world_hex(b.root.position))
	var style := style_of(w, owner)
	var zone: String = ZONE.get(key, "home")
	var span: Array = RINGS[zone]
	var toward := _enemy_direction(w, owner, towns[0].root.position)
	var seen := {}
	var scored := []
	for hex in options:
		if seen.has(hex):
			continue
		seen[hex] = true
		# The nearest town centre, and where the hex lies from it.
		var c: Vector2i = centres[0]
		var d := ring(hex, c)
		for other in centres:
			var e := ring(hex, other)
			if e < d:
				d = e
				c = other
		var score := 0.0
		if d < span[0]: score -= (span[0] - d) * 2.5
		elif d > span[1]: score -= (d - span[1]) * 1.5
		else: score += 1.0
		var dq: int = hex.x - c.x
		var dr: int = hex.y - c.y
		match style:
			"grid":
				score += 1.4 if posmod(dr, 2) == 0 else (-1.2 if d > 1 else 0.0)   # rows, a street between
			"compact":
				score -= d * 0.6
			"axial":
				score -= absi(dr) * 0.9   # drawn out along the avenue (the q axis)
				if dr == 0: score += 0.8
			"linear":
				score -= absi(dr) * 1.8
			_:
				score += randf_range(-1.2, 1.2)
		# Towns grow touching what they have: a district beside its own kind is worth more.
		var neighbours := 0
		for step in w.logistics.DIRECTIONS:
			var near = w.district_hex.get(hex + step)
			if near != null and not near.dead and near.owner == owner:
				neighbours += 1
				if ZONE.get(near.key, "") == zone: score += 0.35
		score += neighbours * 0.3
		# The army faces the nearest rival.
		if zone in ["army", "airbase"] and toward != Vector3.ZERO:
			var at: Vector3 = w.logistics.hex_center(hex)
			var from: Vector3 = w.logistics.hex_center(c)
			var out := Vector3(at.x - from.x, 0, at.z - from.z)
			if out.length() > 0.1:
				score += out.normalized().dot(toward) * 1.2
		score += randf() * 0.25   # (no two towns alike)
		scored.append([score, hex])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	var tries := 0
	for pair in scored:
		tries += 1
		if tries > CHECKS:
			break
		var spot: Vector3 = w.logistics.hex_center(pair[1])
		if w.site_problem(key, spot, owner) == "":
			return spot
	return null

## The flat direction from `from` toward the nearest rival capital.
static func _enemy_direction(w: Node, owner: int, from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var nearest := INF
	for b in w.buildings:
		if b.dead or b.owner == owner or b.key != "hq":
			continue
		var d: float = b.root.position.distance_to(from)
		if d < nearest:
			nearest = d
			best = Vector3(b.root.position.x - from.x, 0, b.root.position.z - from.z).normalized()
	return best

## How orderly a nation's towns are (tests and the inspector): the share of its
## districts inside their zone's rings, and its style's signature.
static func order_of(w: Node, owner: int) -> Dictionary:
	var towns: Array = w.buildings.filter(func(b): return b.owner == owner and not b.dead and b.key in TOWNS)
	var centres: Array = towns.map(func(b): return w.logistics.world_hex(b.root.position))
	var inside := 0
	var total := 0
	var off_axis := 0.0
	var even_rows := 0
	for hex in w.district_hex:
		var b = w.district_hex[hex]
		if b.dead or b.owner != owner or b.key in TOWNS or centres.is_empty():
			continue
		var c: Vector2i = centres[0]
		var d := ring(hex, c)
		for other in centres:
			if ring(hex, other) < d:
				d = ring(hex, other)
				c = other
		var span: Array = RINGS[ZONE.get(b.key, "home")]
		total += 1
		if d >= span[0] and d <= span[1]: inside += 1
		off_axis += absi(hex.y - c.y)
		if posmod(hex.y - c.y, 2) == 0: even_rows += 1
	return {"districts": total, "zoned": float(inside) / maxf(total, 1), "off_axis": off_axis / maxf(total, 1), "rows": float(even_rows) / maxf(total, 1)}
