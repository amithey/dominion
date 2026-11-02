extends SceneTree
## Each nation's own air-defence system (air_defence_systems.gd, native/AIR-DEFENCE-NATIONAL-2026-11.md): a name and
## data of its own, used by its SAM site's interception, reach, reload and aircraft damage; nations with no such
## battery have no SAM site to build.
var errors: Array[String] = []
var passed := 0
var w: Node
const F := preload("res://scripts/factions.gd")
const A := preload("res://scripts/air_defence_systems.gd")
const V := preload("res://scripts/national_variants.gd")
const M := preload("res://scripts/modern_warfare.gd")
const NONE := ["afghanistan", "nigeria", "south_sudan", "yemen", "syria"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func begin(id: String) -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": F.IDS.find(id), "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)

func run() -> void:
	# ---- the table: every nation has a system or is named as having none
	for id in F.IDS:
		check(A.has(id) != (id in NONE), "%s: a SAM system, or none" % id)
	for id in A.SYSTEMS:
		var s: Dictionary = A.SYSTEMS[id]
		var ok: bool = s.odds.size() == A.CLASSES.size() and str(s.name) != "" and float(s.reach) > 0.0 and float(s.reload) > 0.0 and float(s.aircraft) > 0.0
		for o in s.odds: ok = ok and float(o) >= 0.0 and float(o) <= 0.97
		check(ok, "%s: %s has a full, sane data row" % [id, s.name])
	check(A.SYSTEMS.israel.odds[0] > A.SYSTEMS.iraq.odds[0] and A.SYSTEMS.usa.odds[3] > A.SYSTEMS.brazil.odds[3], "a modern long-range system stops more than a short-range one")
	check(A.SYSTEMS.uk.odds[3] < A.SYSTEMS.usa.odds[3] and A.SYSTEMS.germany.odds[3] < A.SYSTEMS.france.odds[3], "Sky Sabre and IRIS-T are not ballistic-missile defences")
	check(A.line("usa").begins_with("Patriot PAC-3") and A.line("afghanistan").begins_with("None"), "the nation card shows the system, or that there is none")
	check(A.describe("usa").contains("%") and A.describe("afghanistan").begins_with("No ground"), "the description gives percentages, or says there is no battery")

	# ---- a nation with no battery cannot build one, and the placement says why
	await begin("afghanistan")
	check(not V.builds(w, 0, "samSite"), "Afghanistan cannot build a SAM site")
	check(w.site_problem("samSite", w.start + Vector3(40, 0, 40), 0).begins_with("No ground-based air-defence"), "and the placement says why")

	# ---- the United States, in play
	await begin("usa")
	check(V.builds(w, 0, "samSite"), "the United States can build a SAM site")
	check(str(w.building_defs.samSite.name) == "Patriot PAC-3 Battery", "the build menu calls it a Patriot PAC-3 battery (%s)" % str(w.building_defs.samSite.name))
	check(str(w.building_defs.samSite.desc).contains("cruise missiles") and str(w.building_defs.samSite.desc).contains("165"), "its card gives the interception and reach")
	var site: Dictionary = w.place_building("samSite", w.snap_to_hex(w.start + Vector3(60, 0, 60)), 0, true)
	check(str(site.def.name) == "Patriot PAC-3 Battery", "the placed battery carries the name")
	var chance := M.intercept_chance(w, "samSite", {"type": "ballistic", "owner": 1}, 0)
	check(absf(chance - 0.50) < 0.08, "it stops about half of ballistic missiles (%.2f)" % chance)
	check(A.reach(w, 0) == 165.0 and A.reload_time(w, 0) == 2.6 and A.aircraft_damage(w, 0) == 48.0, "its reach, reload and aircraft damage are its own")
	check(A.title(w, 0) == "a Patriot PAC-3 battery", "messages name it (%s)" % A.title(w, 0))

	print("AIR_DEFENCE_SYSTEMS %s %d" % ["FAIL" if not errors.is_empty() else "PASS", passed])
	if not errors.is_empty():
		print("FAILED: ", ", ".join(PackedStringArray(errors)))
	quit(0 if errors.is_empty() else 1)
