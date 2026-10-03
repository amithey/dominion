extends SceneTree
## Iraq, Syria and Afghanistan (additional_factions.gd, additional_powers.gd,
## national_variants.gd EXCEPT / RESEARCH_EXCEPT / BUILD_EXCEPT; research in
## native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md): each in the roster
## with its leader, profile, power and own unit; what each may and may not
## field, research and build; its power at work; Afghanistan's suicide squad;
## the rivals' AI using the powers and never building what they may not.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Factions := preload("res://scripts/factions.gd")
const F := preload("res://scripts/additional_factions.gd")
const P := preload("res://scripts/additional_powers.gd")
const Powers := preload("res://scripts/faction_powers.gd")
const Variants := preload("res://scripts/national_variants.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
const Gallery := preload("res://scripts/leader_gallery.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func idx(id: String) -> int:
	return Factions.IDS.find(id)

func begin(cfg: Dictionary) -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("normal")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for n in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		n.set_process(false)

func sim(seconds: float, rivals := false) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		if rivals: w.ai._physics_process(DT)
		for n in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
			n._process(DT)
		t += DT

func hq(owner := 0):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead: return b
	return null

func owner_of(id: String) -> int:
	for i in range(w.map.nations.size()):
		if str(w.map.nations[i].get("id", "")) == id: return i
	return -1

func place(key: String, owner: int, from: Vector3, reach := 70.0) -> Dictionary:
	for r in range(20, int(reach), 6):
		for k in range(12):
			var at: Vector3 = w.snap_to_hex(from + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 12.0) * r)
			if w.site_problem(key, at, owner) == "":
				var b: Dictionary = w.place_building(key, at, owner, true)
				return b
	return {}

func locked(keys: Array) -> Array:
	return keys.filter(func(k): return w.unit_defs.has(k) and w.research.unit_locked(k) == "")

func run() -> void:
	# 1-3: the roster.
	var ids := ["iraq", "syria", "afghanistan"]
	var leaders := {"iraq": "Prime Minister Ali al-Zaidi", "syria": "President Ahmed al-Sharaa", "afghanistan": "Supreme Leader Hibatullah Akhundzada"}
	check(ids.all(func(id): return idx(id) >= 0 and Factions.LEADERS[idx(id)] == leaders[id] and Factions.NAMES.size() == Factions.IDS.size() and Factions.PORTRAITS.size() == Factions.IDS.size() and Factions.COLOURS.size() == Factions.IDS.size() and Factions.DOCTRINES.size() == Factions.IDS.size() and Factions.SIGNATURES.size() == Factions.IDS.size()), "Iraq, Syria and Afghanistan are in the roster of %d nations, each with its leader, colour, doctrine and signature" % Factions.IDS.size())
	check(ids.all(func(id): return Gallery.portrait(leaders[id]).ends_with("-emblem.svg") or Gallery.portrait(leaders[id]).ends_with("-v2.png")), "each leader has a picture (%s)" % ", ".join(PackedStringArray(ids.map(func(id): return Gallery.portrait(leaders[id]).get_file()))))
	check(ids.all(func(id): return P.POWERS.has(id) and F.PROFILES[id].strengths.size() >= 3 and F.PROFILES[id].weaknesses.size() >= 3), "each has a national power and its strengths and weaknesses")

	# ---- Iraq, at Baghdad on the Middle East.
	await begin({"map": "middle_east", "players": 4, "nation": idx("iraq"), "rivals": [0, 3, idx("afghanistan")]})
	print("== Iraq")
	var baghdad: Vector2 = preload("res://scripts/world_geography.gd").to_world("middle_east", float(w.map.mapSize), 44.36, 33.31)
	check(Vector2(hq().root.position.x, hq().root.position.z).distance_to(baghdad) < 25.0, "Iraq starts at Baghdad on the Middle East map")
	check(w.unit_defs.jet.name == "F-16IQ Fighting Falcon" and w.unit_defs.tank.name == "M1A1M Abrams" and w.research.unit_locked("submarine") != "" and w.research.unit_locked("himars") != "" and w.research.unit_locked("stealthFighter") != "", "Iraq fields F-16IQs and Abrams; no submarines, guided rockets or stealth fighters")
	var at: Vector3 = hq().root.position
	check(w.site_problem("nuclearReactor", at, 0).begins_with("Not built by") and w.site_problem("missileSilo", at, 0).begins_with("Not built by") and Variants.builds(w, 0, "barracks"), "Iraq builds no nuclear reactor and no missile silo (%s)" % w.site_problem("nuclearReactor", at, 0))
	check(Arsenal.foreign(w, w.research.def_of("nuclearProgram").get("nation", "")) != "" and Arsenal.foreign(w, w.research.def_of("ballisticTech").get("nation", "")) != "", "Iraq researches no nuclear programme and no ballistic missiles")
	w.economy.grant_test_resources()
	if not P.owned(w, 0, "barracks"): place("barracks", 0, at)
	var usa := owner_of("usa")
	var iran := owner_of("iran")
	var r_usa: float = w.diplomacy.rel(0, usa)
	var r_iran: float = w.diplomacy.rel(0, iran)
	var before: int = w.units.filter(func(u): return u.owner == 0 and not u.dead).size()
	var said: String = Powers.use(w, 0)
	var militia: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.get("militia", false))
	check(militia.size() == 6 and w.units.filter(func(u): return u.owner == 0 and not u.dead).size() == before + 6 and militia.all(func(u): return u.node.position.distance_to(at) < 40.0), "Popular Mobilization: six militia fighters muster at the capital (%s)" % said)
	check(w.diplomacy.rel(0, usa) < r_usa - 3.0 and w.diplomacy.rel(0, iran) > r_iran + 2.0, "...and Washington frowns (%d to %d), Tehran smiles (%d to %d)" % [int(r_usa), int(w.diplomacy.rel(0, usa)), int(r_iran), int(w.diplomacy.rel(0, iran))])
	var cts: Dictionary = w.spawn_unit("ctsGolden", w.land_point(at, 30.0), 0)
	check(cts.max_hp >= float(w.unit_defs.commando.hp) * 1.15 and float(w.damage_profile.ctsGolden.building) > float(w.damage_profile.get("commando", {}).get("building", 1.0)), "the Golden Division: tougher than a commando and harder on buildings (%d hp)" % int(cts.max_hp))
	check(w.diplomacy.rel(0, iran) > w.diplomacy.rel(0, usa), "Iraq starts closer to Iran than to the United States")

	# ---- Syria.
	await begin({"map": "crown", "players": 4, "nation": idx("syria"), "rivals": [idx("turkiye"), idx("israel"), idx("iran")]})
	print("== Syria")
	var none: Array = locked(["jet", "gunship", "corvette", "submarine", "samLauncher", "bomber", "stealthFighter"])
	check(none.is_empty() and w.research.unit_locked("tank") == "" and w.research.unit_locked("helicopter") == "" and w.unit_defs.tank.name == "T-72", "Syria: no jets, attack helicopters, warships but gunboats, or strategic air defence; T-72 tanks and helicopters%s" % ("" if none.is_empty() else " (open: %s)" % str(none)))
	var start: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead)
	var wrong: Array = start.filter(func(u): return not Variants.fields(u.key, "syria"))
	check(wrong.is_empty() and start.any(func(u): return u.key == "drone") and not start.any(func(u): return u.key == "jet"), "Syria's starting army holds only what it fields (drones for the jets)")
	var soldier: Dictionary = w.spawn_unit("soldier", w.land_point(hq().root.position, 30.0), 0)
	check(soldier.max_hp >= float(w.unit_defs.soldier.hp) * 1.09, "Syria's infantry: battle-hardened, +10%% health (%d of %d)" % [int(soldier.max_hp), int(w.unit_defs.soldier.hp)])
	check(float(w.unit_defs.shaheenDrone.cost.money) < float(w.unit_defs.fpvTeam.cost.money) and w.research.unit_locked("shaheenDrone") != "Syria only", "the Shaheen drone team: cheaper than an FPV team ($%d against $%d)" % [int(w.unit_defs.shaheenDrone.cost.money), int(w.unit_defs.fpvTeam.cost.money)])
	for other in range(1, 4): w.diplomacy.set_score(0, other, 0.0)
	check(Powers.blocked(w, 0) != "", "Reconstruction Aid needs a partner (%s)" % Powers.blocked(w, 0))
	var turk := owner_of("turkiye")
	w.diplomacy.set_score(0, turk, 45.0)
	var money: float = w.economy.res.money
	hq().hp = hq().max_hp * 0.5
	var aid: String = Powers.use(w, 0)
	var capital_hp: float = hq().hp
	var paid_now: float = w.economy.res.money
	sim(35.0)
	check(paid_now <= money - 99.0 and w.economy.res.money >= money + 149.0 and hq().hp > capital_hp, "Reconstruction Aid: $100 now, $250 from Turkiye 30s later, and the damaged capital is mended (%s)" % aid)
	check(w.diplomacy.rel(0, owner_of("iran")) < w.diplomacy.rel(0, turk), "Syria is at odds with Iran, close to Turkiye")

	# ---- Afghanistan.
	await begin({"map": "crown", "players": 4, "nation": idx("afghanistan"), "rivals": [idx("pakistan"), 0, 4]})
	print("== Afghanistan")
	at = hq().root.position
	var built: Array = ["nuclearReactor", "missileSilo", "shipyard"].filter(func(k): return w.site_problem(k, at, 0) == "" or not w.site_problem(k, at, 0).begins_with("Not built by"))
	check(built.is_empty(), "Afghanistan builds no nuclear reactor, no missile silo and no naval shipyard (%s)" % w.site_problem("nuclearReactor", at, 0))
	none = locked(["jet", "gunship", "gunboat", "corvette", "destroyer", "submarine", "samLauncher", "himars", "seaDrone", "bomber", "stealthFighter"])
	check(none.is_empty() and w.research.unit_locked("helicopter") == "" and w.unit_defs.helicopter.name == "UH-60 (captured)", "Afghanistan: no air force but captured helicopters, no navy, no strategic air defence%s" % ("" if none.is_empty() else " (open: %s)" % str(none)))
	start = w.units.filter(func(u): return u.owner == 0 and not u.dead)
	check(not start.any(func(u): return u.get("naval", false)) and not start.any(func(u): return u.key in ["jet", "bomber"]), "Afghanistan's starting army: no warships, no jets (%d units)" % start.size())
	var foreign: Array = ["nuclearProgram", "navalEngineering", "ballisticTech", "stealthTech"].filter(func(k): return Arsenal.foreign(w, w.research.def_of(k).get("nation", "")) == "")
	check(foreign.is_empty(), "Afghanistan researches no nuclear programme, naval engineering, missiles or stealth")
	var rifle: Dictionary = w.spawn_unit("soldier", w.land_point(at, 30.0), 0)
	check(rifle.max_hp >= float(w.unit_defs.soldier.hp) * 1.14 and preload("res://scripts/national_profile.gd").cost_mult(w, 0, "soldier") < 0.85, "Afghan infantry: +15%% health (%d), 20%% cheaper" % int(rifle.max_hp))
	var pak := owner_of("pakistan")
	check(w.diplomacy.rel(0, pak) < -20.0 and w.diplomacy.rel(0, owner_of("russia")) > w.diplomacy.rel(0, pak), "Afghanistan starts hostile to Pakistan (%d), on better terms with Russia (%d)" % [int(w.diplomacy.rel(0, pak)), int(w.diplomacy.rel(0, owner_of("russia")))])
	# The suicide squad: beside a Pakistani depot, it detonates.
	w.economy.grant_test_resources()
	var them: Vector3 = hq(pak).root.position
	var depot: Dictionary = place("warehouse", pak, them)
	# (the guard stands on the squad's way in, where the blast goes off)
	var guard: Dictionary = w.spawn_unit("soldier", w.land_point(depot.root.position + Vector3(-7, 0, 0), 3.0), pak)
	var squad: Dictionary = w.spawn_unit("suicideSquad", w.land_point(depot.root.position + Vector3(-18, 0, 0), 8.0), 0)
	w.diplomacy.declare_war(0, pak)
	var depot_hp: float = depot.hp
	var guard_hp: float = guard.hp
	squad.enemy = depot
	sim(25.0)
	check(squad.dead and depot.hp <= depot_hp - 100.0 and (guard.dead or guard.hp < guard_hp), "the suicide squad closes in and detonates: the depot loses %d health, the guard is hit, the squad is gone" % int(depot_hp - depot.hp))
	# Insurgent attacks: not on a friend; on an enemy, three buildings and its income.
	var usa2 := owner_of("usa")
	w.diplomacy.set_score(0, usa2, 10.0)
	check(Powers.blocked(w, 0, usa2) != "", "Insurgent Attacks: not against a nation at peace and on fair terms (%s)" % Powers.blocked(w, 0, usa2))
	var targets: Array = P.insurgency_targets(w, pak)
	for i in range(3 - targets.size()): place("farm", pak, them)
	var hp_before := []   # [building, health] (dictionaries as keys hash by content)
	for b in P.insurgency_targets(w, pak): hp_before.append([b, b.hp])
	var r_russia: float = w.diplomacy.rel(0, owner_of("russia"))
	w.power_ready[0] = 0.0
	var told: String = Powers.use(w, 0, pak)
	var hit: int = hp_before.filter(func(pair): return pair[0].hp < pair[1] - 1.0).size()
	check(hit == 3 and hq(pak).hp == hq(pak).max_hp and absf(Powers.income_mult(w, pak) - 0.85) < 0.01, "Insurgent Attacks: three of Pakistan's buildings struck (not its capital), its income down 15%% (%s)" % told)
	check(w.diplomacy.rel(0, owner_of("russia")) < r_russia - 3.0, "...and the world's opinion of Afghanistan falls")
	# F10 does not open what the nation does not have.
	preload("res://scripts/cheats.gd").everything(w)
	check(not w.research.done("nuclearProgram") and w.site_problem("nuclearReactor", at, 0).begins_with("Not built by") and locked(["jet", "corvette"]).is_empty(), "even the testing cheat gives Afghanistan no nuclear programme, reactor, jets or navy")
	# A save keeps the nation and its effects.
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(data)
	for i in range(5): await process_frame
	check(str(w.map.nations[0].get("id", "")) == "afghanistan" and absf(Powers.income_mult(w, pak) - 0.85) < 0.01, "a save keeps Afghanistan and the attack's effect on Pakistan")

	# ---- The rivals' AI: Afghanistan and Iraq as rivals, at war with you.
	await begin({"map": "crown", "players": 3, "nation": 0, "rivals": [idx("afghanistan"), idx("iraq")]})
	print("== Afghanistan and Iraq as rivals")
	var afg := owner_of("afghanistan")
	var irq := owner_of("iraq")
	for n in w.ai.nations: n.money += 20000.0
	w.diplomacy.declare_war(afg, 0)
	w.game_time = 300.0
	var buildings0: int = w.buildings.filter(func(b): return b.owner == afg and not b.dead).size()
	sim(240.0, true)
	var forbidden: Array = w.buildings.filter(func(b): return b.owner in [afg, irq] and not b.dead and not Variants.builds(w, b.owner, b.key))
	var grew: bool = w.buildings.filter(func(b): return b.owner == afg and not b.dead).size() > buildings0
	check(forbidden.is_empty() and grew, "Afghanistan and Iraq as rivals build up but never what they may not (%d forbidden)" % forbidden.size())
	var afg_units: Array = w.units.filter(func(u): return u.owner == afg and not u.dead)
	check(not afg_units.any(func(u): return u.get("naval", false) or u.key in ["jet", "gunship", "bomber"]), "the Afghan rival fields no warships, jets or gunships (%d units)" % afg_units.size())
	check(Powers.ready_in(w, afg) > 0.0 or Powers.ready_in(w, irq) > 0.0, "the rivals use their national powers (Afghanistan ready in %ds, Iraq in %ds)" % [int(Powers.ready_in(w, afg)), int(Powers.ready_in(w, irq))])

	print("\nTHREE_NATIONS: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("THREE_NATIONS PASS" if errors.is_empty() else "THREE_NATIONS FAIL")
	quit(0 if errors.is_empty() else 1)
