extends RefCounted
## The one list of playable nations. Each lives in scripts/nations/<id>.gd (a DATA
## dictionary); this file only fixes their order. ORDER is append-only: a nation's
## position is its saved index, so a new nation goes at the end and none is reordered.
## factions.gd, additional_factions.gd and regional_factions.gd read their old parallel
## arrays (IDS, NAMES, LEADERS...) from here.
## Groups: "core" (the nine first nations), "additional" (the 2026-10-02/03 nations)
## "regional" (the six regional entities of 2026-10-11) and "expansion" (nations added after them).
const ORDER := [
	preload("res://scripts/nations/usa.gd"),
	preload("res://scripts/nations/china.gd"),
	preload("res://scripts/nations/eu.gd"),
	preload("res://scripts/nations/iran.gd"),
	preload("res://scripts/nations/russia.gd"),
	preload("res://scripts/nations/india.gd"),
	preload("res://scripts/nations/japan.gd"),
	preload("res://scripts/nations/turkiye.gd"),
	preload("res://scripts/nations/israel.gd"),
	preload("res://scripts/nations/uk.gd"),
	preload("res://scripts/nations/south_korea.gd"),
	preload("res://scripts/nations/saudi.gd"),
	preload("res://scripts/nations/brazil.gd"),
	preload("res://scripts/nations/indonesia.gd"),
	preload("res://scripts/nations/ukraine.gd"),
	preload("res://scripts/nations/north_korea.gd"),
	preload("res://scripts/nations/egypt.gd"),
	preload("res://scripts/nations/australia.gd"),
	preload("res://scripts/nations/pakistan.gd"),
	preload("res://scripts/nations/iraq.gd"),
	preload("res://scripts/nations/syria.gd"),
	preload("res://scripts/nations/afghanistan.gd"),
	preload("res://scripts/nations/yemen.gd"),
	preload("res://scripts/nations/houthis.gd"),
	preload("res://scripts/nations/ethiopia.gd"),
	preload("res://scripts/nations/nigeria.gd"),
	preload("res://scripts/nations/sudan.gd"),
	preload("res://scripts/nations/south_sudan.gd"),
	preload("res://scripts/nations/france.gd")
]

## One field of every nation in ORDER, optionally only those in `groups`. The result is
## read-only, as the constant arrays it replaces were.
static func column(field: String, groups: Array = []) -> Array:
	var out := []
	for script in ORDER:
		var entry: Dictionary = script.DATA
		if groups.is_empty() or str(entry.group) in groups:
			out.append(entry[field])
	out.make_read_only()
	return out

static func data(id: String) -> Dictionary:
	for script in ORDER:
		if script.DATA.id == id:
			return script.DATA
	return {}
