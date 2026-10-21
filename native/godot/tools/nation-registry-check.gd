extends SceneTree
## The nation registry: every nation is one file, the order is the saved index, and
## no identity can be missing a field, a portrait or a unique colour.
const Registry := preload("res://scripts/nation_registry.gd")
const F := preload("res://scripts/factions.gd")
const Extra := preload("res://scripts/additional_factions.gd")
const Regional := preload("res://scripts/regional_factions.gd")
## Saved games and arsenals store a nation by position: these never move.
const FROZEN := ["usa", "china", "eu", "iran", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "saudi", "brazil", "indonesia", "ukraine", "north_korea", "egypt", "australia", "pakistan", "iraq", "syria", "afghanistan", "yemen", "houthis", "ethiopia", "nigeria", "sudan", "south_sudan"]
const FIELDS := ["id", "group", "arsenal", "name", "leader", "colour", "portrait", "signature", "doctrine"]
const GROUPS := ["core", "additional", "regional"]
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var ids: Array = Registry.column("id")
	check(ids.size() >= FROZEN.size(), "the registry holds at least the %d first nations" % FROZEN.size())
	for i in range(FROZEN.size()):
		check(i < ids.size() and ids[i] == FROZEN[i], "position %d is still %s" % [i, FROZEN[i]])
	var seen := {"id": {}, "name": {}, "colour": {}, "portrait": {}, "leader": {}}
	for script in Registry.ORDER:
		var d: Dictionary = script.DATA
		var id := str(d.get("id", ""))
		for field in FIELDS:
			check(d.has(field) and str(d[field]).strip_edges() != "", "%s has %s" % [id, field])
		check(d.keys().size() == FIELDS.size() + (1 if d.has("profile") else 0), id + " has no stray field")
		if d.has("profile"):
			check(d.profile.get("strengths", []).size() >= 1 and d.profile.get("weaknesses", []).size() >= 1, id + " profile states strengths and weaknesses")
			check(preload("res://scripts/national_profile.gd").of_id(id) == d.profile, id + " profile is the one the game reads")
		check(script.resource_path == "res://scripts/nations/%s.gd" % id, id + " lives in a file of its own name")
		check(str(d.get("group", "")) in GROUPS, id + " has a known group")
		check(str(d.get("colour", "")).is_valid_html_color(), id + " colour is a valid colour")
		check(ResourceLoader.exists("res://ui/leaders/%s-v2.png" % d.get("portrait", "")), id + " portrait file exists")
		check(str(d.get("arsenal", "")) == id or str(d.get("group", "")) == "core", id + " arsenal is its own id unless it is one of the first nine")
		for key in seen:
			var value := str(d.get(key, "")).to_lower()
			check(not seen[key].has(value), "%s: %s is unique" % [id, key])
			seen[key][value] = true
	check(F.IDS == ids and F.NAMES == Registry.column("name") and F.ARSENALS == Registry.column("arsenal"), "Factions reads the registry")
	check(Extra.IDS == ids.slice(9) and Regional.IDS == ids.slice(22, 28) , "the older columns are slices of the registry")
	check(preload("res://scripts/force_catalog.gd").IDS == ids, "the force catalogue lists the same nations")
	for i in range(ids.size()):
		check(F.nation(i)["id"] == ids[i] and F.nation(i)["name"] == F.NAMES[i], "nation %d builds from the registry" % i)
		check(Registry.data(str(ids[i])).get("id", "") == ids[i], "%s found by id" % ids[i])
	check(Registry.data("no_such_nation").is_empty(), "an unknown id finds nothing")
	check(ids.is_read_only() and F.NAMES.is_read_only() and Regional.IDS.is_read_only(), "every column is read-only, as the constants it replaced were")
	print("NATION_REGISTRY %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
