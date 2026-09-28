extends RefCounted
const DEFAULT := {"map":"island","players":4,"nation":0,"style":"standard"}
## Each nation's own flag colour, in the order of NATIONS (map.nations is
## reordered once a match is set up, player first).
const Factions = preload("res://scripts/factions.gd")
const COLOURS = Factions.COLOURS
static var NATIONS: Array = Factions.labels()

static func normalize(options: Dictionary) -> Dictionary:
	var map_key := str(options.get("map", "island"))
	var maps: Array = ["island", "mirrored"] + preload("res://scripts/map_generator.gd").MAPS.keys()
	var out := {"map":map_key if map_key in maps else "island",
		"players":clampi(int(options.get("players",4)),2,4),
		"nation":clampi(int(options.get("nation",0)),0,Factions.IDS.size()-1),
		"style":"sandbox" if options.get("style","standard")=="sandbox" else "standard"}
	if options.get("rivals") is Array:
		out.rivals = []
		for rival in options.rivals:
			var i := int(rival)
			if i >= 0 and i < Factions.IDS.size() and i != out.nation and not i in out.rivals and out.rivals.size() < int(out.players) - 1:
				out.rivals.append(i)
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

static func apply(data: Dictionary, options: Dictionary) -> void:
	var MapGenerator = preload("res://scripts/map_generator.gd")
	if MapGenerator.is_generated(str(options.get("map", "island"))):
		MapGenerator.generate(data, str(options.map))  # a new map's geography (map_generator.gd)
	if options.get("map","island")=="mirrored":
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
	var nation := clampi(int(options.get("nation",0)),0,Factions.IDS.size()-1)
	var count := clampi(int(options.get("players",4)),2,4)
	# Faction roster and geographic slots are separate. Old selections retain
	# their original towns; new factions reuse the same four tested town layouts.
	var chosen := roster(options)
	var home := nation % 4
	var order := [home]
	for i in range(4):
		if i != home and order.size() < count:
			order.append(i)
	data.nations = []
	for i in range(chosen.size()):
		data.nations.append(Factions.nation(chosen[i], i == 0))
	data.startPositions = order.map(func(i): return data.startPositions[i])
	for group in ["buildings","units"]:
		data[group] = data[group].filter(func(e): return int(e.owner) in order)
		for entry in data[group]:
			entry.owner = order.find(int(entry.owner))
