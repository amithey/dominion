extends RefCounted
const DEFAULT := {"map":"island","players":4,"nation":0,"style":"standard"}
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
		"players":clampi(int(options.get("players",4)),2,capacity(map_key)),
		"nation":clampi(int(options.get("nation",0)),0,Factions.IDS.size()-1),
		"style":"sandbox" if options.get("style","standard")=="sandbox" else "standard"}
	if options.get("rivals") is Array:
		out.rivals = []
		for rival in options.rivals:
			var i := int(rival)
			if i >= 0 and i < Factions.IDS.size() and i != out.nation and not i in out.rivals and out.rivals.size() < int(out.players) - 1:
				out.rivals.append(i)
	if options.get("levels") is Array:
		out.levels = []
		for level in options.levels.slice(0, int(out.players) - 1):
			out.levels.append(str(level) if str(level) in LEVELS else "")
		if out.levels.all(func(l): return l == ""):
			out.erase("levels")
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
	data.nations = []
	for i in range(chosen.size()):
		data.nations.append(Factions.nation(chosen[i], i == 0))
	data.startPositions = order.map(func(i): return data.startPositions[i].duplicate())
	for group in ["buildings","units"]:
		var out := []
		for owner in range(order.size()):
			for entry in data[group]:
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
