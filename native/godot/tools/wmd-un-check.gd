extends SceneTree
## Weapons of mass destruction (wmd.gd) and the United Nations (un.gd):
## who may build what, nuclear yields and fallout, the HPM and the HEMP, the
## chemical cloud, the outbreak, and the Council, the vetoes and the Assembly.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## Lets the Council vote through drafts (by default) until one matches `pred`.
func reach(u, pred: Callable) -> bool:
	for i in range(30):
		u.update(0.0)
		if u.current == null:
			return false
		if pred.call(u.current):
			return true
		w.game_time = float(u.current.closes) + 0.1
		u.update(0.0)
	return false

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["wmd", "un", "defcon"])
	seed(11)
	var d: Node = w.diplomacy
	var ms: Node = w.missiles
	var W = w.wmd
	var u = w.un
	var V := preload("res://scripts/national_variants.gd")
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var ids := []
	for i in range(d.n): ids.append(preload("res://scripts/factions.gd").identity(w, i))
	print("nations: ", ids)

	# ---- who may build what
	check(ms.def_of("emp").name == "HPM Cruise Missile" and V.admits(ms.def_of("emp").nation, "blue") and not V.admits(ms.def_of("emp").nation, "gold"), "the EMP missile is the HPM cruise missile, for the US, China and Russia only (not Iran)")
	check(ms.locked("tsarBomba") != "" and ms.locked("chemical") != "" and ms.locked("bioweapon") != "", "the United States cannot build the Tsar Bomba, chemical or biological weapons")
	check(V.admits(ms.def_of("chemical").nation, "gold") and V.admits(ms.def_of("chemical").nation, "russia") and V.admits(ms.def_of("chemical").nation, "north_korea") and not V.admits(ms.def_of("chemical").nation, "red"), "chemical weapons: Russia, North Korea and Iran")
	check(V.admits(ms.def_of("bioweapon").nation, "russia") and V.admits(ms.def_of("bioweapon").nation, "north_korea") and not V.admits(ms.def_of("bioweapon").nation, "gold"), "biological weapons: Russia and North Korea")
	check(float(ms.def_of("tsarBomba").radius) > float(ms.def_of("hydrogenBomb").radius) and float(ms.def_of("hydrogenBomb").radius) > float(ms.def_of("nuke").radius) and float(ms.def_of("nuke").radius) > float(ms.def_of("tacticalNuke").radius), "yields: Tsar Bomba > thermonuclear > strategic > tactical")
	check(w.map.research.discoveries.has("thermonuclear") and w.map.research.discoveries.has("enhancedRadiation"), "Thermonuclear Weapons and Enhanced Radiation Weapons are discoveries")

	# ---- a tactical nuclear strike and its fallout
	var rival := 3   # Iran (not a permanent member)
	var their_hq: Dictionary = w.buildings.filter(func(b): return b.owner == rival and b.key == "hq")[0]
	var gz: Vector3 = their_hq.root.position + Vector3(40, 0, 40)
	var soldier: Dictionary = w.spawn_unit("soldier", ground(gz + Vector3(4, 0, 0)), rival)
	soldier.hp = soldier.max_hp
	ms.impact("tacticalNuke", gz, 0)
	var zone: Array = W.zones.filter(func(z): return z.kind == "fallout")
	check(zone.size() == 1 and absf(float(zone[0].radius) - 18.0 * 0.8) < 0.1, "a tactical nuclear strike leaves fallout (radius %.1f)" % (float(zone[0].radius) if not zone.is_empty() else 0.0))
	check(w.defcon.level() == 1 and W.incidents.any(func(i): return i.kind == "nuclear" and int(i.by) == 0), "it is a nuclear weapon: DEFCON 1, and it is on the record")
	var victim: Dictionary = w.spawn_unit("soldier", ground(zone[0].at), rival)
	var hp0: float = victim.hp
	var shed: Dictionary = w.place_building("barracks", ground(zone[0].at + Vector3(3, 0, 0)), rival, true)
	w.game_time += 1.0
	W._tick = 1.0
	W.update(0.0)
	check(victim.hp < hp0 or victim.dead, "infantry in the fallout sickens (%d to %d)" % [int(hp0), int(victim.hp)])
	check(float(shed.get("disabled_until", 0.0)) > w.game_time, "a building in it falls silent")
	check(w.site_problem("barracks", zone[0].at, 0).contains("Contaminated"), "no one may build on it")
	var s0: float = W.strength_of(zone[0])
	w.game_time += 100.0
	check(W.strength_of(zone[0]) < s0 * 0.6, "the fallout decays (%.2f to %.2f)" % [s0, W.strength_of(zone[0])])
	w.game_time += 100.0
	W._tick = 1.0
	W.update(0.0)
	check(W.zones.filter(func(z): return z.kind == "fallout").is_empty(), "and after its time it is gone")

	# ---- the neutron warhead
	var tank: Dictionary = w.spawn_unit("tank", ground(gz + Vector3(-60, 0, 0)), rival)
	var bunker: Dictionary = w.place_building("barracks", ground(gz + Vector3(-60, 0, 24)), rival, true)
	var tank_hp: float = tank.hp
	var b_hp: float = bunker.hp
	ms.impact("neutronBomb", gz + Vector3(-60, 0, 6), 0)
	var tank_loss: float = (tank_hp - maxf(tank.hp, 0.0)) / tank.max_hp
	var b_loss: float = (b_hp - bunker.hp) / bunker.max_hp
	check(tank_loss > b_loss * 3.0, "the neutron warhead kills crews and spares buildings beyond its small blast (tank -%d%%, barracks -%d%%)" % [roundi(tank_loss * 100), roundi(b_loss * 100)])

	# ---- the high-altitude EMP
	var far: Vector3 = home + Vector3(-160, 0, 120)
	var apc: Dictionary = w.spawn_unit("tank", ground(far), 1)
	var drone: Dictionary = w.spawn_unit("drone", ground(far + Vector3(6, 0, 0)), 1)
	var plant: Dictionary = w.place_building("barracks", w.test_site("barracks", far + Vector3(0, 0, 20)), 1, true)
	var plant_hp: float = plant.hp
	var apc_hp: float = apc.hp
	w.space.sats[1].recon = 10
	ms.impact("nuclearEmp", far, 0)
	check(float(apc.get("disabled_until", 0.0)) > w.game_time + 60.0 and is_equal_approx(apc.hp, apc_hp) and is_equal_approx(plant.hp, plant_hp), "the high-altitude EMP blacks out a tank and a barracks for 90 s without a scratch")
	check(drone.dead, "drones under it fall")
	check(w.space.count(1, "recon") < 10, "and it knocks satellites out of orbit (%d of 10 left)" % w.space.count(1, "recon"))

	# ---- the HPM cruise missile
	var col: Array = []
	var from: Vector3 = home + Vector3(150, 0, -150)
	var to: Vector3 = home + Vector3(150, 0, -50)
	for f in [0.6, 0.8, 1.0]:
		col.append(w.spawn_unit("tank", ground(from.lerp(to, f)), 2))
	var mine: Dictionary = w.spawn_unit("tank", ground(to + Vector3(3, 0, 0)), 0)
	ms.impact("emp", to, 0, from)
	check(col.all(func(t): return float(t.get("disabled_until", 0.0)) > w.game_time and t.hp == t.max_hp), "the HPM missile's three pulses knock out three tanks along its path, harming no one")
	check(float(mine.get("disabled_until", 0.0)) <= w.game_time, "and spares its own side's")

	# ---- chemical and biological
	var squad: Dictionary = w.spawn_unit("soldier", ground(home + Vector3(-120, 0, -120)), 2)
	var armour: Dictionary = w.spawn_unit("tank", ground(home + Vector3(-118, 0, -120)), 2)
	ms.impact("chemical", home + Vector3(-120, 0, -120), 3)
	for i in range(5):
		w.game_time += 1.0
		W._tick = 1.0
		W.update(0.0)
	check((squad.dead or squad.hp < squad.max_hp * 0.8) and armour.hp > armour.max_hp * 0.85, "a chemical cloud kills infantry; tank crews are protected (squad %d%%%s, tank %d%%)" % [roundi(100.0 * squad.hp / squad.max_hp), " dead" if squad.dead else "", roundi(100.0 * armour.hp / armour.max_hp)])
	check(W.incidents.any(func(i): return i.kind == "chemical" and int(i.by) == 3), "Iran's use of chemical weapons is on the record")
	var towns: Array = w.buildings.filter(func(b): return not b.dead and b.key in W.TOWNS)
	var first: Dictionary = towns[0]
	W._infect(first, 3)
	var sick: int = W.zones.filter(func(z): return z.kind == "bio").size()
	var near: Array = towns.filter(func(b): return b != first and b.root.position.distance_to(first.root.position) <= W.SPREAD_RANGE)
	for i in range(30):
		W._spread(W.zones.filter(func(z): return z.kind == "bio")[0])
	check(sick == 1 and (near.is_empty() or W.zones.filter(func(z): return z.kind == "bio").size() > 1), "an outbreak spreads to a neighbouring town (%d towns sick)" % W.zones.filter(func(z): return z.kind == "bio").size())

	# ---- the United Nations
	check(u.permanent(0) and 0 in u.council() and u.council().size() == d.n, "the United States sits on the Security Council as a permanent member (council of %d)" % u.council().size())
	check(u.queue.size() + (1 if u.current != null else 0) >= 2, "the nuclear strike and the chemical attack are before the Council (%d drafts)" % (u.queue.size() + (1 if u.current != null else 0)))
	# The draft against you: veto it.
	var found: bool = reach(u, func(dr): return int(dr.target) == 0 and dr.kind == "wmd")
	check(found, "a draft condemning your nuclear strike")
	u.cast("no")
	var rel0: float = d.rel(1, 0)
	w.game_time = float(u.current.closes) + 0.1
	u.update(0.0)
	var last: Dictionary = u.record[-1]
	check(last.result == "vetoed" and 0 in last.vetoed_by, "you veto it")
	check(last.has("assembly"), "the General Assembly meets on the veto (%s, %d-%d-%d)" % [last.assembly.get("result", "?"), int(last.assembly.get("yes", 0)), int(last.assembly.get("no", 0)), int(last.assembly.get("abstain", 0))])
	# Iran's chemical attack: you vote yes; the Council sanctions it.
	for i in range(d.n):
		if i != 3: d.set_score(i, 3, -60.0)
	found = reach(u, func(dr): return int(dr.target) == 3 and dr.kind == "wmd")
	check(found, "a draft against Iran's chemical attack")
	u.cast("yes")
	w.game_time = float(u.current.closes) + 0.1
	u.update(0.0)
	check(u.record[-1].result == "adopted" and u.sanctioned(3), "adopted: UN sanctions on Iran")
	check(is_equal_approx(preload("res://scripts/faction_powers.gd").income_mult(w, 3), 0.75), "its income falls 25%")
	# A permanent member protects itself.
	d.declare_war(1, 2)
	W._incident("chemical", "chemical", 1, [2])
	reach(u, func(dr): return int(dr.target) == 1 and dr.kind == "wmd")
	u.cast("yes")
	w.game_time = float(u.current.closes) + 0.1
	u.update(0.0)
	check(u.record[-1].result == "vetoed" and 1 in u.record[-1].vetoed_by, "%s vetoes a draft against itself" % d.name_of(1))
	# A ceasefire between two rivals.
	u.next_draft = 0.0
	var tabled: String = u.draft("ceasefire", 1, 2)
	u.update(0.0)
	u.cast("yes")
	w.game_time = float(u.current.closes) + 0.1
	u.update(0.0)
	var cf: Dictionary = u.record[-1]
	check(tabled.contains("tables") and cf.kind == "ceasefire" and cf.result in ["adopted", "vetoed", "failed"], "you can table a ceasefire; the Council votes on it (%s)" % cf.result)
	# Aggression.
	d.make_peace(0, 3)
	u._seen_wars.clear()
	d.declare_war(0, 3)
	check(u.queue.any(func(q): return q.kind == "aggression" and int(q.target) == 0), "your war on Iran goes before the Council as an aggression")
	check(u.draft_blocked("sanctions", 2).contains("No cause") or u.draft_blocked("sanctions", 2).contains("table another"), "sanctions need a cause")
	# Saving.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snap)
	check(w.un.record.size() == u.record.size() and w.un.sanctioned(3), "a save keeps the UN's record and the sanctions in force")
	check(w.wmd.zones.size() == W.zones.size() and w.wmd.incidents.size() == W.incidents.size(), "and the poisoned ground and the incidents")
	# Rivals with chemical weapons use them.
	var iran: Dictionary = w.ai.nations.filter(func(n): return n.id == 3)[0]
	iran.tech = 5.0
	if not w.diplomacy.at_war(0, 3): w.diplomacy.declare_war(3, 0)
	w.spawn_unit("soldier", ground(home + Vector3(30, 0, 30)), 0)
	var fired := false
	for i in range(200):
		iran.wmd_at = -1000.0
		var before: int = w.missiles.flying.size()
		w.wmd._ai_use()
		if w.missiles.flying.size() > before and w.missiles.flying[-1].type == "chemical":
			fired = true
			break
	check(fired, "Iran, at war with you, fires chemical weapons at your troops")
	# The windows.
	w.hud.show()
	for tab in ["council", "assembly", "record"]:
		w.hud.toggle_panel("un", true)
		w.hud._panels.un_tab = tab
		w.hud.refresh_side()
		check(w.hud._side_rows.get_child_count() >= 2, "the UN window's %s tab" % tab)
	print("\nWMD_UN: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("WMD_UN PASS" if errors.is_empty() else "WMD_UN FAIL")
	quit(0 if errors.is_empty() else 1)
