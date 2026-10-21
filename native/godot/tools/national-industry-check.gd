extends SceneTree
## Which buildings and which units each nation really has (national_industry.gd,
## regional_factions.fields; research native/NATIONAL-INDUSTRY-RESEARCH-2026-10-13.md):
## no Chip Fab, data centre or technology park for a nation without that
## industry, no reactor where there is no civil nuclear programme, no HIMARS or
## submarine for a militia or a landlocked state, and the era's compute goal asks
## such a nation for universities, not fabs.
var errors: Array[String] = []
var passed := 0
var w: Node
const F := preload("res://scripts/factions.gd")
const I := preload("res://scripts/national_industry.gd")
const V := preload("res://scripts/national_variants.gd")
const R := preload("res://scripts/regional_factions.gd")
const D := preload("res://scripts/ai_data.gd")
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
	# ---- the table, for every nation
	for id in F.IDS:
		check((id in I.CHIP_FAB) == (id in ["usa", "china", "eu", "france", "uk", "japan", "south_korea", "israel", "india", "russia"]), "%s: Chip Fab only with a semiconductor industry" % id)
	check(not "houthis" in I.CHIP_FAB and not "yemen" in I.CHIP_FAB and not "iran" in I.CHIP_FAB and not "turkiye" in I.CHIP_FAB, "the Houthis, Yemen, Iran and Türkiye import their chips")
	check(I.NO_REACTOR == ["australia", "indonesia"], "Australia and Indonesia run research reactors only")

	# ---- the Houthis in play
	await begin("houthis")
	for key in ["chipFab", "aiDataCenter", "techPark", "fusionCell", "nuclearReactor"]:
		check(not V.builds(w, 0, key), "the Houthis cannot build %s" % key)
	var why: String = w.site_problem("chipFab", w.start + Vector3(40, 0, 40), 0)
	check(why.begins_with("No semiconductor"), "and the placement says why: %s" % why)
	var hq_ok: bool = V.builds(w, 0, "hq") and V.builds(w, 0, "farm") and V.builds(w, 0, "barracks") and V.builds(w, 0, "missileSilo") and V.builds(w, 0, "school")
	check(hq_ok, "they keep their capital, farms, barracks, school and missile tunnels")
	for key in ["himars", "submarine", "nuclearSub", "samLauncher", "jet", "bomber", "destroyer", "stealthFighter", "railgunShip"]:
		check(not w.unit_allowed(0, key), "the Houthis do not field the %s" % key)
	for key in ["mlrs", "loiterer", "coastalDrone", "gunboat", "seaDrone", "fpvTeam", "tank", "soldier"]:
		check(w.unit_allowed(0, key), "the Houthis do field the %s" % key)
	var r = w.research
	var goals: Array = r.era_requirements(r.eras.size() - 1).map(func(q): return str(q[0]))
	check(not goals.has("Chip Fabs") and (goals.has("Universities") or goals.is_empty()), "the era's compute goal asks them for universities (%s)" % ", ".join(PackedStringArray(goals)))
	check(not w.research.def_of("aiRevolution").is_empty() and not V.builds(w, 0, "chipFab"), "(the AI Revolution discovery stays out of reach without a fab)")

	# ---- landlocked Ethiopia
	await begin("ethiopia")
	check(not w.unit_allowed(0, "submarine") and not w.unit_allowed(0, "seaDrone") and not w.unit_allowed(0, "himars"), "landlocked Ethiopia has no submarine, sea drone or HIMARS")
	check(V.builds(w, 0, "aiDataCenter") and V.builds(w, 0, "techPark") and not V.builds(w, 0, "chipFab"), "Ethiopia (AI level 2) has a technology park and a data centre, but no fab")
	check(w.unit_allowed(0, "jet") and w.unit_allowed(0, "akinci") and w.unit_allowed(0, "mlrs"), "and its documented jets, drones and rockets")

	# ---- the United States builds everything
	await begin("usa")
	for key in ["chipFab", "aiDataCenter", "techPark", "fusionCell", "nuclearReactor"]:
		check(V.builds(w, 0, key), "the United States builds %s" % key)
	var goals_us: Array = w.research.era_requirements(w.research.eras.size() - 1).map(func(q): return str(q[0]))
	check(goals_us.has("Chip Fabs"), "and its compute goal is Chip Fabs")

	# ---- a rival never raises what it cannot build
	var pick_bad := 0
	var rival_id: String = F.identity(w, 1)
	for k in ["chipFab", "aiDataCenter", "techPark", "fusionCell", "nuclearReactor"]:
		if V.builds(w, 1, k) != I.allowed(w, 1, k) or (not I.allowed(w, 1, k) and V.builds(w, 1, k)): pick_bad += 1
	check(pick_bad == 0, "a rival (%s) is held to the same table" % rival_id)

	print("NATIONAL_INDUSTRY %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("NATIONAL_INDUSTRY %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
