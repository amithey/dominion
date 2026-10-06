extends RefCounted

## What no nation starts with: aircraft, ships, armour and special forces are
## built or bought (every nation, you and the rivals alike, opens with a town,
## three workers and a small guard).
const OPENING_EXCLUDED := ["commando", "sniper", "tankFactory"]

## Whether `key` is part of the opening: workers and plain infantry, no vehicle, ship or aircraft.
static func in_opening(key: String) -> bool:
	if key in OPENING_EXCLUDED:
		return false
	var w = load("res://scripts/world.gd")
	return not (key in w.AIR or key in w.NAVAL or key in w.VEHICLES)
const DEFAULT := {"map":"island","players":4,"nation":0,"style":"standard","pace":0.75}
## How fast the world turns: everything (movement, building, training,
## research, the economy, the seasons, the rivals) runs at this share of the
## original speed. The camera and the interface keep their own speed.
const PACES := [0.6, 0.75, 1.0]
## Each nation's own flag colour, in the order of NATIONS (map.nations is
## reordered once a match is set up, player first).
const Factions = preload("res://scripts/factions.gd")
const COLOURS = Factions.COLOURS
const LEVELS := ["easy", "normal", "hard"]
static var NATIONS: Array = Factions.labels()

## How many nations map `key` has room for: its prepared capital regions,
## and never more than there are factions.
static func capacity(key: String) -> int:
	var maps: Dictionary = preload("res://scripts/map_generator.gd").MAPS
	return mini(int(maps[key].get("slots", 4)) if maps.has(key) else 4, Factions.IDS.size())

## Options as a match accepts them. "rivals": the rival factions chosen, in
## order; "levels": each rival's difficulty in the same order ("" or missing:
## the match's difficulty).
static func normalize(options: Dictionary) -> Dictionary:
	var map_key := str(options.get("map", "island"))
	var maps: Array = ["island", "mirrored"] + preload("res://scripts/map_generator.gd").MAPS.keys()
	map_key = map_key if map_key in maps else "island"
	var out := {"map":map_key,
		"players":clampi(_int(options.get("players",4),4),2,capacity(map_key)),
		"nation":clampi(_int(options.get("nation",0),0),0,Factions.IDS.size()-1),
		"style":"sandbox" if str(options.get("style","standard"))=="sandbox" else "standard",
		"pace":_pace(options.get("pace", 0.75))}
	# Fog of war (fog_of_war.gd): on unless chosen off, or a sandbox match.
	if str(options.get("opening", "")) == "light":
		out.opening = "light"   # a campaign from the New Game screen: a town, workers and a small guard
	out.fog = bool(options.get("fog", out.style != "sandbox")) if not (options.get("fog") is String) else str(options.fog) == "true"
	if options.get("rivals") is Array:
		out.rivals = []
		for rival in options.rivals:
			var i := _int(rival, -1)
			if i >= 0 and i < Factions.IDS.size() and i != out.nation and not i in out.rivals and out.rivals.size() < int(out.players) - 1:
				out.rivals.append(i)
	# Where each nation starts, in the order of the roster (you first): a region
	# of the map (start_slots) or -1 to leave it to the map. Each region once;
	# on the two original islands your prepared town is fixed, and theirs.
	if options.get("starts") is Array:
		var regions := region_count(map_key)
		var fixed := not preload("res://scripts/map_generator.gd").is_generated(map_key)
		out.starts = []
		for s in options.starts.slice(0, int(out.players)):
			var k := _int(s, -1)
			if k < 0 or k >= regions or k in out.starts or (fixed and (out.starts.is_empty() or k == 0)):
				k = -1
			out.starts.append(k)
		if out.starts.all(func(v): return v == -1):
			out.erase("starts")
	if options.get("levels") is Array:
		out.levels = []
		for level in options.levels.slice(0, int(out.players) - 1):
			out.levels.append(str(level) if str(level) in LEVELS else "")
		if out.levels.all(func(l): return l == ""):
			out.erase("levels")
	return out

## The nearest pace on offer to `value` (old saves have none: the default).
static func _pace(value) -> float:
	var v: float = float(value) if (value is float or value is int) else 0.75
	var best: float = PACES[0]
	for p in PACES:
		if absf(p - v) < absf(best - v): best = p
	return best

## A whole number from a save or a setting, or `fallback` when it is none
## (a damaged or hand-edited save must not stop the game loading).
static func _int(value, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback

## The original island's four starts (data/map-seed1.json), -1..1 across it:
## the first is your prepared town.
const ISLAND_STARTS := [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]

## How many capital regions map `key` has.
static func region_count(key: String) -> int:
	var maps: Dictionary = preload("res://scripts/map_generator.gd").MAPS
	return int(maps[key].get("slots", 4)) if maps.has(key) else ISLAND_STARTS.size()

## Map `key`'s capital regions for the New Game screen, in region order:
## {"at": -1..1 across the map (x east, y south), "name": the city on the
## real-world maps, else its quarter of the map}.
static func start_slots(key: String) -> Array:
	var MapGenerator = preload("res://scripts/map_generator.gd")
	var at: Array = []
	if MapGenerator.is_generated(key):
		at = MapGenerator.slot_positions(key)
	else:
		at = ISLAND_STARTS.map(func(p): return Vector2(-p.x, p.y) if key == "mirrored" else p)
	var out := []
	for k in range(at.size()):
		var name := _quarter(at[k])
		if key in MapGenerator.REAL:
			name = str(MapGenerator.Geography.MAPS[key].starts[k][3])
		out.append({"at": at[k], "name": name})
	return out

static func _quarter(p: Vector2) -> String:
	if p.length() < 0.2:
		return "Centre"
	return ["East", "South-east", "South", "South-west", "West", "North-west", "North", "North-east"][posmod(roundi(p.angle() / (PI / 4.0)), 8)]

## The chosen region of each nation in the roster (-1: left to the map).
static func starts_of(options: Dictionary) -> Array:
	var picks: Array = options.starts if options.get("starts") is Array else []
	var out := []
	for i in range(int(options.get("players", 4))):
		out.append(_int(picks[i], -1) if i < picks.size() else -1)
	return out

static func roster(options: Dictionary) -> Array:
	var nation := int(options.get("nation", 0))
	var count := int(options.get("players", 4))
	var result := [nation]
	for i in options.get("rivals", []):
		if int(i) >= 0 and int(i) < Factions.IDS.size() and not int(i) in result and result.size() < count:
			result.append(int(i))
	for i in range(Factions.IDS.size()):
		var candidate := i if nation < 4 else (nation + i + 1) % Factions.IDS.size()
		if not candidate in result and result.size() < count:
			result.append(candidate)
	return result

## Rival `slot` (1 = the first rival)'s difficulty, `fallback` when unset.
static func level_of(options: Dictionary, slot: int, fallback: String) -> String:
	var levels: Array = options.get("levels", [])
	var level := str(levels[slot - 1]) if slot >= 1 and slot <= levels.size() else ""
	return level if level in LEVELS else fallback

static func apply(data: Dictionary, options: Dictionary) -> void:
	var MapGenerator = preload("res://scripts/map_generator.gd")
	var key := str(options.get("map", "island"))
	var count := clampi(int(options.get("players",4)),2,capacity(key))
	# Faction roster and geographic slots are separate. The exported island has
	# four tested starts: the player's town and army (nation 0 there) and three
	# rival capitals with a guard. You always get the first, whichever nation you
	# lead; the rivals share the others, repeated when there are more than three.
	# Two nations on a four-start map face each other across it.
	var chosen := roster(options)
	var raw: int = data.startPositions.size()
	var order := [0, raw / 2] if count == 2 and raw >= 4 else [0]
	while order.size() < count:
		order.append(1 + (order.size() - 1) % (raw - 1))
	var picks: Array = starts_of(options)
	if MapGenerator.is_generated(key):
		data.startSlots = picks   # the generator places the towns (map_generator.gd)
	else:
		# A rival given a start of the island takes it (from whoever had it).
		for i in range(1, count):
			var k: int = picks[i]
			if k <= 0 or k >= raw or order[i] == k:
				continue
			var j := order.find(k)
			if j > 0:
				order[j] = order[i]
			order[i] = k
	data.nations = []
	for i in range(chosen.size()):
		data.nations.append(Factions.nation(chosen[i], i == 0))
	data.startPositions = order.map(func(i): return data.startPositions[i].duplicate())
	# Your starting army holds only what your nation fields (no bomber for Japan).
	preload("res://scripts/national_variants.gd").fix_start(data, str(data.nations[0].get("arsenal", "")))
	for group in ["buildings","units"]:
		var out := []
		for owner in range(order.size()):
			for entry in data[group]:
				if str(options.get("opening", "")) == "light" and not in_opening(str(entry.key)):
					continue   # every nation opens the same way: a town, workers and a small guard
				if int(entry.owner) == order[owner]:
					var copy: Dictionary = entry.duplicate(true)
					copy.owner = owner
					out.append(copy)
		data[group] = out
	if MapGenerator.is_generated(key):
		MapGenerator.generate(data, key)  # a new map's geography (map_generator.gd): the nations spread round its regions
	if key=="mirrored":
		var n := int(data.grid.size)
		var values: Array = data.grid.heightsCm
		for row in range(n):
			for col in range(n/2):
				var a := row*n+col
				var b := row*n+n-col-1
				var old = values[a]
				values[a] = values[b]
				values[b] = old
		data.grid.origin[0] = -(float(data.grid.origin[0])+(n-1)*float(data.grid.step))
		for group in ["trees","deposits","buildings","units"]:
			for entry in data[group]:
				entry.x = -float(entry.x)
		for p in data.startPositions:
			p[0] = -float(p[0])
