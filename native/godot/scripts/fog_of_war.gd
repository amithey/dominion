extends RefCounted
## Fog of war: the player sees only what its forces, its buildings and its
## allies (and client states) see. Land never seen is dark; land seen before
## but not watched now is grey. An enemy unit shows only where it is seen; an
## enemy building, once seen, stays on the map where it was last seen (as a
## 4X or RTS map remembers it). The player's units do not fire on what no one
## on their side can see, and an enemy that cannot be seen cannot be clicked.
## Reconnaissance matters: artillery and rocket launchers see little of their
## own (they need a spotter), drones see far, air defence radars further, and a
## CIA network of intelligence 10 in a nation puts its buildings on the map.
## Rival governments play under it too, as far as the player is concerned: a
## rival knows only those of the player's buildings its own forces have seen
## (capitals are known to all), so its attacks and missiles go for what it has
## found, and its artillery, too, needs a spotter to fire on the player's units.
## Resource deposits on land never seen are not shown. Sandbox matches have no
## fog (match_config "fog": false turns it off in any match).

const CELL := 10.0
const UNEXPLORED := 0.82     # how dark land never seen is
const EXPLORED := 0.45       # how dark land seen before is
const TICK := 0.25
## How far each kind sees (metres); a unit always sees at least as far as it
## seeks targets, except the long-range weapons, which need spotters.
const SIGHT := {"soldier": 32, "rocketSoldier": 32, "commando": 40, "sniper": 48, "medic": 28, "worker": 26, "fpvTeam": 40,
	"atgmTeam": 36, "manpads": 40, "tank": 38, "apc": 44, "aaVehicle": 60, "samLauncher": 75, "ewVehicle": 55, "laserAD": 60,
	"abmLauncher": 70, "irisT": 75, "helicopter": 50, "gunship": 52, "jet": 60, "bomber": 50, "drone": 85, "loiterer": 55,
	"stealthFighter": 62, "sixthGen": 65, "wingman": 60, "raptor": 62, "akinci": 90, "gunboat": 45, "corvette": 55,
	"destroyer": 65, "submarine": 35, "nuclearSub": 35}
const SPOTTED := ["artillery", "mlrs", "himars", "df17", "tos1a", "brahmos", "k9", "shahedLauncher", "heavyRocket"]
const SPOTTER_SIGHT := 32.0
const BUILDING_SIGHT := {"hq": 85, "samSite": 90, "airfield": 60, "cityCenter": 60, "villageCenter": 50, "bunker": 45, "commandCenter": 70, "port": 50}

var w: Node
var enabled := true
var n := 0
var origin := Vector2.ZERO
var explored := PackedByteArray()
var seen := PackedByteArray()          # watched now
var image: Image
var texture: ImageTexture
var _tick := 0.0
var _masks := {}
var _scout_tick := 0
var rival_seen := {}         # rival -> cells its forces see (refreshed each second)

func _init(world: Node) -> void:
	w = world
	enabled = bool(w.match_config.get("fog", w.match_config.get("style", "standard") != "sandbox"))
	var half: float = float(w.map.mapSize) * 0.5 + 40.0
	n = int(ceil(half * 2.0 / CELL))
	origin = Vector2(-half, -half)
	explored.resize(n * n)
	seen.resize(n * n)
	image = Image.create(n, n, false, Image.FORMAT_LA8)
	image.fill(Color(0, 0, 0, UNEXPLORED))
	texture = ImageTexture.create_from_image(image)
	_bind()
	# Every government knows where the others' capitals are: they are on the map
	# from the start (and can be clicked to open contact), the land round them not.
	for b in w.buildings:
		if b.key == "hq" and not b.dead:
			b.seen = true

## The fog over everything that draws the land (global shader uniforms:
## shaders/fog.gdshaderinc).
func _bind() -> void:
	RenderingServer.global_shader_parameter_set("fog_on", enabled)
	RenderingServer.global_shader_parameter_set("fog_tex", texture)
	RenderingServer.global_shader_parameter_set("fog_rect", Vector4(origin.x, origin.y, n * CELL, n * CELL))

func index(p: Vector3) -> int:
	var c := int(floor((p.x - origin.x) / CELL))
	var r := int(floor((p.z - origin.y) / CELL))
	if c < 0 or r < 0 or c >= n or r >= n:
		return -1
	return r * n + c

## Whether the player's side watches point `p` now.
func watches(p: Vector3) -> bool:
	if not enabled:
		return true
	var i := index(p)
	return i >= 0 and seen[i] == 1

## Whether the player's side has ever seen point `p`.
func charted(p: Vector3) -> bool:
	if not enabled:
		return true
	var i := index(p)
	return i >= 0 and explored[i] == 1

## Whether `owner` shares its sight with the player: the player, its allies and
## its client states.
func friendly(owner: int) -> bool:
	if owner == 0:
		return true
	var d = w.diplomacy
	if d != null and owner < d.n and d.allied(0, owner):
		return true
	var e = w.get("espionage")
	return e != null and e.get("puppets") != null and e.puppets.has(owner) and int(e.puppets[owner].get("patron", 0)) == 0

## Whether the player may see (and so target or click) `thing`, a unit or building.
func shows(thing: Dictionary) -> bool:
	if not enabled or friendly(int(thing.owner)):
		return true
	if thing.get("is_building", false):
		return thing.get("seen", false)
	return watches(thing.node.position)

func sight_of(u: Dictionary) -> float:
	if u.key in SPOTTED:
		return SPOTTER_SIGHT
	return maxf(float(SIGHT.get(u.key, 34)), float(u.get("aggro", 0.0)) * (1.0 if u.get("fly", false) else 1.1))

func update(delta: float) -> void:
	if not enabled:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	refresh()

## Recomputes what the player's side sees, shows and hides the enemy, and
## repaints the fog.
func refresh() -> void:
	seen.fill(0)
	for u in w.units:
		if not u.dead and friendly(int(u.owner)):
			_stamp(u.node.position, sight_of(u))
	for b in w.buildings:
		if not b.dead and friendly(int(b.owner)):
			_stamp(b.root.position, float(BUILDING_SIGHT.get(b.key, b.footprint * 0.5 + 28.0)))
	# A CIA network deep enough puts a nation's buildings on the map.
	var e = w.get("espionage")
	for b in w.buildings:
		if b.dead or friendly(int(b.owner)):
			continue
		if not b.get("seen", false) and (seen[maxi(index(b.root.position), 0)] == 1 or (e != null and float(e.intel.get(int(b.owner), 0.0)) >= 10.0)):
			b.seen = true
			var i := index(b.root.position)
			if i >= 0: explored[i] = 1
		var show: bool = b.get("seen", false)
		if b.root.visible != show:
			b.root.visible = show
	for u in w.units:
		if u.dead or friendly(int(u.owner)):
			continue
		var show := watches(u.node.position)
		if u.node.visible != show:
			u.node.visible = show
			if not show:
				u.selected = false
	# Deposits on land never seen are not shown.
	for dep in w.deposits:
		var known := charted(dep.pos)
		if dep.node.visible != known:
			dep.node.visible = known
	# Once a second: what the rivals' forces see of the player's buildings.
	_scout_tick += 1
	if _scout_tick >= 4:
		_scout_tick = 0
		_scout()
	_paint()

## Once a second: what each rival's forces see, as a map of cells (rival_seen),
## and the player's buildings inside it become known to that rival.
func _scout() -> void:
	rival_seen.clear()
	var by_owner := {}
	for u in w.units:
		if u.dead or int(u.owner) == 0 or friendly(int(u.owner)):
			continue
		if not by_owner.has(int(u.owner)): by_owner[int(u.owner)] = []
		by_owner[int(u.owner)].append(u)
	for owner in by_owner:
		var cells := PackedByteArray()
		cells.resize(n * n)
		for u in by_owner[owner]:
			var c := int(floor((u.node.position.x - origin.x) / CELL))
			var r := int(floor((u.node.position.z - origin.y) / CELL))
			for off in _mask(int(ceil(sight_of(u) / CELL))):
				var x: int = c + off.x
				var z: int = r + off.y
				if x >= 0 and z >= 0 and x < n and z < n:
					cells[z * n + x] = 1
		rival_seen[owner] = cells
	for b in w.buildings:
		if b.dead or b.owner != 0:
			continue
		var i := index(b.root.position)
		if i < 0:
			continue
		for owner in rival_seen:
			if rival_seen[owner][i] == 1:
				if not b.has("known_by"):
					b.known_by = {}
				b.known_by[owner] = true

## Whether rival `owner` knows of building `b` (rivals know each other's; the
## player's they must find, its capital excepted).
func rival_knows(owner: int, b: Dictionary) -> bool:
	if not enabled or int(b.owner) != 0 or b.key == "hq":
		return true
	return b.get("known_by", {}).has(owner)

## Whether a rival's long-range weapon may fire at the player's unit `target`:
## one of the rival's own units must see it (a spotter): its sight map, a second old.
func rival_spots(owner: int, target: Dictionary) -> bool:
	if not enabled or int(target.owner) != 0:
		return true
	var cells = rival_seen.get(owner)
	var i := index(target.node.position)
	return cells != null and i >= 0 and cells[i] == 1

func _stamp(p: Vector3, radius: float) -> void:
	var c := int(floor((p.x - origin.x) / CELL))
	var r := int(floor((p.z - origin.y) / CELL))
	for off in _mask(int(ceil(radius / CELL))):
		var x: int = c + off.x
		var z: int = r + off.y
		if x < 0 or z < 0 or x >= n or z >= n:
			continue
		var i := z * n + x
		seen[i] = 1
		explored[i] = 1

func _mask(cells: int) -> Array:
	if not _masks.has(cells):
		var out := []
		for dz in range(-cells, cells + 1):
			for dx in range(-cells, cells + 1):
				if dx * dx + dz * dz <= cells * cells:
					out.append(Vector2i(dx, dz))
		_masks[cells] = out
	return _masks[cells]

func _paint() -> void:
	var data := PackedByteArray()
	data.resize(n * n * 2)
	var dark := int(UNEXPLORED * 255.0)
	var grey := int(EXPLORED * 255.0)
	for i in range(n * n):
		data[i * 2 + 1] = 0 if seen[i] == 1 else (grey if explored[i] == 1 else dark)
	image.set_data(n, n, false, Image.FORMAT_LA8, data)
	texture.update(image)

func capture() -> Dictionary:
	return {"explored": Marshalls.raw_to_base64(explored.compress(FileAccess.COMPRESSION_DEFLATE)), "size": explored.size(),
		"seen_buildings": w.buildings.filter(func(b): return not b.dead and b.get("seen", false)).map(func(b): return [b.root.position.x, b.root.position.z]),
		"known_by_rivals": w.buildings.filter(func(b): return not b.dead and not b.get("known_by", {}).is_empty()).map(func(b): return [b.root.position.x, b.root.position.z, b.known_by.keys()])}

func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var raw: PackedByteArray = Marshalls.base64_to_raw(str(data.get("explored", "")))
	var size := int(data.get("size", 0))
	if size == n * n and not raw.is_empty():
		explored = raw.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	for spot in data.get("known_by_rivals", []):
		for b in w.buildings:
			if not b.dead and absf(b.root.position.x - float(spot[0])) < 0.5 and absf(b.root.position.z - float(spot[1])) < 0.5:
				b.known_by = {}
				for o in spot[2]: b.known_by[int(o)] = true
	for spot in data.get("seen_buildings", []):
		for b in w.buildings:
			if not b.dead and absf(b.root.position.x - float(spot[0])) < 0.5 and absf(b.root.position.z - float(spot[1])) < 0.5:
				b.seen = true
	refresh()
