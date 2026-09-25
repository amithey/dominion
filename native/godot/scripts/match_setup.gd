extends RefCounted
const DEFAULT := {"map":"island","players":4,"nation":0,"style":"standard"}
const NATIONS := ["Atlantic Federation · President E. Hale","Crimson Empire · Premier K. Volkov","Verdant Union · Chancellor L. Moreau","Golden Dominion · Sultan R. Qadir"]

static func normalize(options: Dictionary) -> Dictionary:
	var map_key := str(options.get("map", "island"))
	var maps: Array = ["island", "mirrored"] + preload("res://scripts/map_generator.gd").MAPS.keys()
	return {"map":map_key if map_key in maps else "island",
		"players":clampi(int(options.get("players",4)),2,4),
		"nation":clampi(int(options.get("nation",0)),0,3),
		"style":"sandbox" if options.get("style","standard")=="sandbox" else "standard"}

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
	var nation := clampi(int(options.get("nation",0)),0,3)
	var count := clampi(int(options.get("players",4)),2,4)
	var order := [nation]
	for i in range(4):
		if i!=nation and order.size()<count:
			order.append(i)
	var old_nations: Array = data.nations.duplicate(true)
	data.nations = []
	for i in range(order.size()):
		var info: Dictionary = old_nations[order[i]]
		info.player = i==0
		data.nations.append(info)
	data.startPositions = order.map(func(i): return data.startPositions[i])
	for group in ["buildings","units"]:
		data[group] = data[group].filter(func(e): return int(e.owner) in order)
		for entry in data[group]:
			entry.owner = order.find(int(entry.owner))
