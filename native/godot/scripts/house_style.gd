extends RefCounted
## One spelling in every name and description the player reads. The game
## writes British English (Defence, centre, armour), but the definitions
## exported from the browser version and a few added later used American
## spellings: "Village Center" beside "Defence", "Composite Armor" beside
## "armour". Only the text changes; every key stays as it is.

const WORDS := [
	["Centers", "Centres"], ["Center", "Centre"], ["centers", "centres"], ["center", "centre"],
	["Armored", "Armoured"], ["armored", "armoured"], ["Armor", "Armour"], ["armor", "armour"],
	["Defense", "Defence"], ["defense", "defence"], ["Color", "Colour"], ["color", "colour"],
]

static func fix(text: String) -> String:
	var out := text
	for pair in WORDS:
		var re := RegEx.create_from_string("\\b%s\\b" % pair[0])
		out = re.sub(out, pair[1], true)
	return out

static func apply(w: Node) -> void:
	var tables: Array = [w.building_defs, w.unit_defs, w.map.research.discoveries, w.map.missiles.get("types", {})]
	if w.map.research.has("tracks"):
		tables.append(w.map.research.tracks)
	for table in tables:
		for key in table:
			var def = table[key]
			if not def is Dictionary:
				continue
			for field in ["name", "desc"]:
				if def.get(field) is String:
					def[field] = fix(def[field])
