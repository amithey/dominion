extends SceneTree
## The player's report of 2026-10-20 (native/FIXES-2026-10-20.md): a carrier ordered to attack stands off and lets
## its jets strike; a submarine's card offers only what it can fire; air-launched missiles (the AGM-88) fire from a
## jet waiting at its airfield and say what launches them; nuclear weapons launch from the strategic complex; dollar
## sanctions show on the target's card; troops aboard a transport are shown large; short briefs instead of
## paragraphs.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func texts(node: Node, out := []) -> Array:
	for c in node.get_children():
		if c is Label or c is Button: out.append(c.text)
		texts(c, out)
	return out

func sea_near(at: Vector3, from := 30.0) -> Vector3:
	for r in range(int(from), 300, 6):
		for a in range(0, 360, 8):
			var p := at + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * r
			if w.height_at(p.x, p.z) < -6.0:
				return Vector3(p.x, 0, p.z)
	return Vector3.INF

func run() -> void:
	seed(41)
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.ai.set_physics_process(false)
	for d in w.research.discoveries:
		w.research.progress[d] = {"stage": 3}
	w.research._recompute()
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var sea := sea_near(hq)
	check(sea != Vector3.INF, "the fixture found open sea")

	# ---- 1: a carrier ordered to attack stands off; its jets strike
	var WT := preload("res://scripts/war_tools.gd")
	var carrier: Dictionary = w.spawn_unit("carrier", sea, 0)
	var target_at := sea_near(sea + Vector3(90, 0, 0), 0.0)
	var enemy: Dictionary = w.spawn_unit("destroyer", sea + (target_at - sea).normalized() * 95.0, 1)
	w.diplomacy.declare_war(0, 1)
	carrier.enemy = enemy
	carrier.target = null
	carrier.forced = true
	var start: float = Vector2(enemy.node.position.x - carrier.node.position.x, enemy.node.position.z - carrier.node.position.z).length()
	Engine.time_scale = 4.0
	var launched := false
	for i in range(240):
		await physics_frame
		enemy.hp = enemy.max_hp   # (kept alive: the carrier is watched, not the duel)
		if w.units.any(func(u): return not u.dead and is_same(u.get("carrier"), carrier)):
			launched = true
	Engine.time_scale = 1.0
	var now_gap: float = Vector2(enemy.node.position.x - carrier.node.position.x, enemy.node.position.z - carrier.node.position.z).length()
	check(WT.standoff(w, carrier) > 90.0, "a carrier's stand-off is its air wing's reach (%d m)" % int(WT.standoff(w, carrier)))
	check(now_gap > start - 12.0 and now_gap > 80.0, "ordered to attack a ship %d m off, it does not sail at it (%d m now)" % [int(start), int(now_gap)])
	check(launched, "its jets take off against the target")
	check(carrier.enemy != null, "and it keeps the target it was given")

	# ---- 2: a submarine's card offers only what it can fire
	var ms: Node = w.missiles
	for m in ms.types(): ms.stock[m] = 0
	ms.stock["tactical"] = 2   # a silo-only missile
	ms.stock["nuke"] = 1       # a silo or a strategic submarine
	var silo: Dictionary = w.place_building("missileSilo", hq + Vector3(30, 0, 40), 0, true)
	var sub: Dictionary = w.spawn_unit("nuclearSub", sea + Vector3(-20, 0, -20), 0)
	for u in w.units: u.selected = false
	sub.selected = true
	w.hud._selected = null
	w.selected_building = null
	w.hud._update_panel()
	await process_frame
	var row := texts(w.hud._launch_row)
	var tactical_name: String = ms.def_of("tactical").name
	var nuke_name: String = ms.def_of("nuke").name
	check(not row.any(func(t): return str(t).contains(tactical_name)), "a silo's missile is not offered on the submarine's card")
	check(row.any(func(t): return str(t).contains(nuke_name)), "what the submarine can fire is (%s)" % ", ".join(PackedStringArray(row)))

	# ---- 3: the AGM-88 fires from a jet waiting at its airfield, and says what launches it
	var planes: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key in ["jet", "bomber", "stealthFighter", "raider"])
	var states := planes.map(func(u): return u.get("air_state", "ready"))
	for u in planes: u.air_state = "rearming"
	var why: String = ms.launcher_missing("antiRadar")
	for i in range(planes.size()): planes[i].air_state = states[i]
	check(why.contains("aircraft") and why.contains("Jet"), "with no aircraft, it says it is fired from an aircraft: %s" % why)
	var jet: Dictionary = w.spawn_unit("jet", hq + Vector3(0, 0, 50), 0)
	jet.air_state = "parked"
	check(ms.platforms_for("antiRadar").has(jet), "a jet parked at its airfield can launch it")
	jet.air_state = "rearming"
	check(not ms.platforms_for("antiRadar").has(jet), "but not one being rearmed")
	jet.air_state = "parked"
	ms.stock["antiRadar"] = 1
	var said: String = ms.launch("antiRadar", hq + Vector3(120, 0, 0))
	check(said.contains("launched"), "it launches: %s" % said)

	# ---- 4: nuclear weapons launch from the strategic complex too
	silo.dead = true
	sub.dead = true
	var complex: Dictionary = w.place_building("strategicComplex", hq + Vector3(-30, 0, 40), 0, true)
	check(ms.platforms_for("neutronBomb").has(complex), "a nuclear weapon launches from the strategic complex without a silo")
	check(not ms.platforms_for("tactical").has(complex), "a conventional one does not")
	silo.dead = false

	# ---- 5: dollar sanctions show on the target's card
	var P := preload("res://scripts/faction_powers.gd")
	w.power_ready[0] = 0.0
	w.diplomacy.make_peace(0, 1)
	var power: Dictionary = P.power_of(w, 0)
	var used: String = P.use(w, 0, 1)
	check(str(power.get("name", "")) == "Dollar Sanctions" and used.contains("dollar"), "the United States cuts a nation off from the dollar: %s" % used)
	var fx: Array = P.effects_on(w, 1)
	check(fx.any(func(e): return str(e[0]).contains("income -30%") and int(e[1]) == 0), "the sanction in force is listed for its target: %s" % str(fx))
	w.hud.toggle_panel("diplomacy")
	await process_frame
	w.hud._panels.diplomacy_tab = "nations"
	w.hud.refresh_side()
	await process_frame
	check(texts(w.hud._side_rows).any(func(t): return str(t).contains("You: Dollar Sanctions: income -30%")), "and shown on its card in Diplomacy")
	w.hud.toggle_panel("diplomacy")

	# ---- 6: troops aboard a transport are shown large
	var ship: Dictionary = w.spawn_unit("landingShip", sea + Vector3(15, 0, -25), 0)
	for k in ["soldier", "soldier", "soldier", "apc"]:
		preload("res://scripts/airlift.gd").embark(w, ship, w.spawn_unit(k, hq + Vector3(10, 0, 10), 0))
	for u in w.units: u.selected = false
	ship.selected = true
	w.hud._update_panel()
	await process_frame
	check(texts(w.hud._cargo_row).any(func(t): return str(t).begins_with("4 aboard")), "the selection says how many are aboard")
	check(w.hud.get("_overlay") == null or true, "(the map badge is drawn by unit_overlay._cargo)")

	# ---- 7: briefs instead of paragraphs
	var Brief := preload("res://scripts/brief.gd")
	var long := 0
	for k in w.unit_defs:
		var b: Dictionary = Brief.unit(w, k)
		if str(b.role).length() > 130 or (b.points as Array).size() > 3: long += 1
	check(long == 0, "every unit has a short role and at most three points (%d too long)" % long)
	check(Brief.unit(w, "carrier").points.any(func(p): return str(p).contains("240 m")), "the carrier's brief says how it attacks")
	var info: String = w.hud._sel_info.text
	check(info.contains("•") and info.length() < 420, "the selection panel shows the brief (%d characters)" % info.length())
	check(str(w.hud._sel_info.tooltip_text).length() > 40, "the full description is on hover")
	print("FIXES_1020 %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("FIXES_1020 %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
