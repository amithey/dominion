extends SceneTree
## The nation registry: every nation is one file, the order is the saved index, and
## no identity can be missing a field, a portrait or a unique colour.
const Registry := preload("res://scripts/nation_registry.gd")
const F := preload("res://scripts/factions.gd")
const Extra := preload("res://scripts/additional_factions.gd")
const Regional := preload("res://scripts/regional_factions.gd")
## Saved games and arsenals store a nation by position: these never move.
const FROZEN := ["usa", "china", "germany", "iran", "russia", "india", "japan", "turkiye", "israel", "uk", "south_korea", "saudi", "brazil", "indonesia", "ukraine", "north_korea", "egypt", "australia", "pakistan", "iraq", "syria", "afghanistan", "yemen", "houthis", "ethiopia", "nigeria", "sudan", "south_sudan"]
const FIELDS := ["id", "group", "arsenal", "name", "leader", "colour", "portrait", "signature", "doctrine"]
const GROUPS := ["core", "additional", "regional", "expansion"]
## Data a nation may carry for the tables that read the registry (see NATION-ADDITION-CHECKLIST.md).
const OPTIONAL := ["profile", "ai", "ai_evidence", "ai_use", "dossier", "force_names", "capabilities", "power"]
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
		check(d.keys().all(func(k): return k in FIELDS or k in OPTIONAL), id + " has no stray field")
		if d.has("profile"):
			check(d.profile.get("strengths", []).size() >= 1 and d.profile.get("weaknesses", []).size() >= 1, id + " profile states strengths and weaknesses")
			check(preload("res://scripts/national_profile.gd").of_id(id) == d.profile, id + " profile is the one the game reads")
		if d.has("ai"):
			check(int(d.ai.get("ceiling", -1)) in range(6) and str(d.ai.get("why", "")).length() > 20, id + " AI standing has a ceiling from 0 to 5 and a reason")
			check(preload("res://scripts/ai_data.gd").entry(id) == d.ai, id + " AI standing is the one the game reads")
		if d.has("ai_evidence"):
			check(d.ai_evidence.size() == 3 and d.ai_evidence[2] is Array and d.ai_evidence[2].size() == 4, id + " AI evidence is a headline, a source line and four priorities")
			check(preload("res://scripts/ai_applications_data.gd").evidence(id) == d.ai_evidence, id + " AI evidence is the one the game reads")
		if d.has("dossier"):
			var Arsenal := preload("res://scripts/arsenal_diversity_data.gd")
			check(Arsenal.profile(id) == d.dossier.profile and d.dossier.keys().size() == 3, id + " dossier is the one the game reads")
			check(d.dossier.roster.keys().all(func(k): return Arsenal.ROSTER.has(k) and Arsenal.roster(k).get(id, []) == d.dossier.roster[k]), id + " roster rows sit under known roles and merge into them")
			check(d.dossier.sources.keys().all(func(s): return Arsenal.source(s) == d.dossier.sources[s] and not Arsenal.SOURCES.has(s)), id + " own sources are found and not duplicated in the table")
		if d.has("force_names"):
			var Forces := preload("res://scripts/force_catalog.gd")
			check(d.force_names.keys().all(func(k): return Forces.ROLES.has(k) and str(d.force_names[k]).length() > 2 and not Forces.NAMES.get(k, {}).has(id)), id + " force names are for known roles and not also in the table")
			check(d.force_names.keys().all(func(k): return Forces.names(k).get(id, "") == d.force_names[k] and id in Forces.operators(k)), id + " force names are the roster the game reads, and it operates the role")
		if d.has("power"):
			var Powers := preload("res://scripts/additional_powers.gd")
			check(["name", "target", "hostile", "cooldown", "duration", "costs", "needs", "desc"].all(func(k): return d.power.has(k)) and str(d.power.desc).length() > 40, id + " power is fully defined")
			check(Powers.def(id) == d.power and Powers.has_power(id), id + " power is the one the game reads")
		if d.has("capabilities"):
			var Variants := preload("res://scripts/national_variants.gd")
			var caps: Dictionary = d.capabilities
			check(caps.keys().all(func(k): return k in ["units", "not_units", "research", "missiles", "names"]), id + " capabilities use known fields")
			check(caps.get("units", []).all(func(k): return Variants.ONLY.has(k) and d.arsenal in Variants.table("only")[k]), id + " units it adds are in the allow-lists and read back")
			check(caps.get("not_units", []).all(func(k): return Variants.EXCEPT.has(k) and d.arsenal in Variants.table("except")[k]), id + " units it lacks are in the exception lists and read back")
			check(caps.get("research", []).all(func(k): return Variants.RESEARCH_ONLY.has(k) and d.arsenal in Variants.table("research")[k]), id + " research it adds is in the allow-lists and reads back")
			check(caps.get("missiles", []).all(func(k): return Variants.MISSILE_ONLY.has(k) and d.arsenal in Variants.table("missiles")[k]), id + " missiles it adds are in the allow-lists and read back")
			check(caps.get("names", {}).keys().all(func(k): return Variants.table("names")[k][d.arsenal] == caps.names[k]), id + " unit names read back")
		if d.has("ai_use"):
			check(d.ai_use is Dictionary and preload("res://scripts/ai_use_data.gd").record(id) == d.ai_use, id + " AI use record is the one the game reads")
		check(script.resource_path == "res://scripts/nations/%s.gd" % id, id + " lives in a file of its own name")
		check(str(d.get("group", "")) in GROUPS, id + " has a known group")
		check(str(d.get("colour", "")).is_valid_html_color(), id + " colour is a valid colour")
		check(ResourceLoader.exists("res://ui/leaders/%s-v2.png" % d.get("portrait", "")) or ResourceLoader.exists("res://ui/leaders/%s-emblem.svg" % d.get("portrait", "")), id + " has a portrait or an emblem")
		check(str(d.get("arsenal", "")) == id or str(d.get("group", "")) == "core", id + " arsenal is its own id unless it is one of the first nine")
		for key in seen:
			var value := str(d.get(key, "")).to_lower()
			check(not seen[key].has(value), "%s: %s is unique" % [id, key])
			seen[key][value] = true
	check(F.IDS == ids and F.NAMES == Registry.column("name") and F.ARSENALS == Registry.column("arsenal"), "Factions reads the registry")
	check(Extra.IDS == ids.slice(9, 28) and Regional.IDS == ids.slice(22, 28), "the older columns are slices of the registry")
	check(preload("res://scripts/force_catalog.gd").IDS == ids, "the force catalogue lists the same nations")
	for i in range(ids.size()):
		check(F.nation(i)["id"] == ids[i] and F.nation(i)["name"] == F.NAMES[i], "nation %d builds from the registry" % i)
		check(Registry.data(str(ids[i])).get("id", "") == ids[i], "%s found by id" % ids[i])
	check(Registry.data("no_such_nation").is_empty(), "an unknown id finds nothing")
	check(Registry.LEGACY_LEADERS.values().all(func(name): return name in F.LEADERS) and Registry.legacy_leader("Nobody") == "Nobody", "an old seat holder resolves to the present one")
	check(ids.is_read_only() and F.NAMES.is_read_only() and Regional.IDS.is_read_only(), "every column is read-only, as the constants it replaced were")
	print("NATION_REGISTRY %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
