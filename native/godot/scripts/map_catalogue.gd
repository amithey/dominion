extends RefCounted
## One ordered catalogue for the campaign picker and its baked terrain previews.
const Generator = preload("res://scripts/map_generator.gd")
const KEYS := ["small", "island", "mirrored", "twin", "archipelago", "continent", "frontier", "highlands", "inland_sea", "crown", "great_lakes", "pangaea", "ten_isles", "fractal", "continents_plus", "middle_east", "europe", "east_asia"]
static func entry(key: String) -> Dictionary:
	if Generator.MAPS.has(key):
		var info: Dictionary = Generator.MAPS[key].duplicate()
		info.slots = info.get("slots", 4)
		return info
	return {"name": "Mirrored Island" if key == "mirrored" else "The Island", "size": 640, "slots": 4,
		"desc": "The original island mirrored: start in the west." if key == "mirrored" else "The original island, with rivals on every side."}
static func preview_path(key: String) -> String:
	return "res://ui/maps/%s.png" % key
