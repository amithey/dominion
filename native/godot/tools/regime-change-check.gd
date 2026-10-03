extends SceneTree
## The United States' leadership raid (regime_change.gd, after Operation
## Absolute Resolve): what it needs; on success the regime falls to a puppet
## ruler, the nation becomes a US client state (allied, paying tribute,
## joining US wars, never turning on it) and the world fears the United
## States; on failure special forces are lost and the target goes to war.
var errors: Array[String] = []
var passed := 0
var w: Node
const RC := preload("res://scripts/regime_change.gd")
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

func hq(owner: int) -> Dictionary:
	return w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)[0]

## Everything the raid needs against `nation`, but the money and the war.
func prepare(e: Node, nation: int) -> void:
	e.network[nation] = 70.0
	e.intel[nation] = 60.0
	e.heat[nation] = 0.0
	e.dossiers[nation] = {"t": e.clock, "confidence": "high", "source": "test"}

func run() -> void:
	set_meta("match_config", {"map": "pangaea", "players": 3, "nation": Factions.IDS.find("usa"), "style": "sandbox"})
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
	w.effects.set_physics_process(false)
	w.ai.set_physics_process(false)
	var e: Node = w.espionage
	var d: Node = w.diplomacy
	w.economy.res.money = 100000.0
	for n in w.ai.nations: n.money = 5000.0
	var home: Vector3 = hq(0).root.position

	# 1: the operation, the United States' alone, and what it needs.
	check(e.ops().has(RC.KEY) and RC.us(w), "the leadership raid is in the United States' Intel catalog")
	d.declare_war(1, 0)
	check(e.blocked_reason(RC.KEY, 1).begins_with("Build an Intelligence Agency"), "it needs an intelligence agency first")
	w.place_building("intelAgency", ground(home + Vector3(-40, 0, -30)), 0, true)
	e.recruit()
	e.network[1] = 70.0
	e.intel[1] = 60.0
	var why: String = e.blocked_reason(RC.KEY, 1)
	check(why.begins_with("Requires a field dossier"), "a fresh dossier on the leader's pattern of life (\"%s\")" % why)
	prepare(e, 1)
	why = e.blocked_reason(RC.KEY, 1)
	if why.begins_with("Requires special forces"):
		check(true, "special forces (a commando unit)")
		w.spawn_unit("commando", ground(home + Vector3(20, 0, 20)), 0)
	else:
		check(w.units.any(func(u): return u.owner == 0 and not u.dead and u.key == "commando"), "special forces (a commando unit): the starting army has one")
	why = e.blocked_reason(RC.KEY, 1)
	if why.begins_with("Requires an airfield"):
		w.place_building("helipad", ground(home + Vector3(40, 0, -30)), 0, true)
	check(e.blocked_reason(RC.KEY, 1) == "", "with all of it the raid can be authorised (\"%s\")" % e.blocked_reason(RC.KEY, 1))
	check(e.success_chance(RC.KEY, 1) > 0.4 and e.success_chance(RC.KEY, 1) < 0.95, "success %d%% with a network of 70" % roundi(e.success_chance(RC.KEY, 1) * 100))

	# 2: success. An air defence by the target's capital, a weaker third nation at war with you.
	var capital: Vector3 = hq(1).root.position
	var sam: Dictionary = w.spawn_unit("samLauncher", ground(capital + Vector3(25, 0, 0)), 1)
	d.declare_war(2, 0)
	for u in w.units:
		if u.owner == 2 and not u.dead and u.dmg > 0.0 and d.army_strength(2) >= d.army_strength(0): w.kill(u)
	var deposed: String = e.person(1, "president")
	var money: float = w.economy.res.money
	check(e.run(RC.KEY, 1, "", -1, 0.0).contains("authorized") and money - w.economy.res.money >= 3000.0, "authorised: $3,000 and 150 s of preparation")
	e.advance(160.0)
	check(e.puppets.has(1) and e.person(1, "president").contains("Washington") and deposed != e.person(1, "president"),
		"%s is captured; a puppet ruler governs: %s" % [deposed, e.person(1, "president")])
	check(not d.at_war(0, 1) and d.allied(0, 1) and d.rel(0, 1) >= 70.0, "the client state makes peace and allies itself with the United States")
	check(sam.dead or sam.hp <= sam.max_hp * 0.41, "the air defences by its capital were struck (%d of %d)" % [int(maxf(sam.hp, 0.0)), int(sam.max_hp)])
	check(e.production_down(1), "its capital is blacked out (factories down)")
	check(RC.feared(w) and not d.at_war(0, 2), "the world fears the United States: the weaker enemy sues for peace at once")
	d.set_score(2, 0, -95.0)
	check(not d.ai_wants_war(2, 0) and is_equal_approx(RC.fear_bonus(w), RC.FEAR_BONUS), "while feared, even a nation at -95 does not dare start a war; peace offers and pacts +30%")

	# 3: the client state pays tribute, joins your wars, and never turns on you.
	var nat = w.market.ai_nation(1)
	nat.money = 5000.0
	money = w.economy.res.money
	e.tick()
	check(w.economy.res.money - money > 200.0, "it pays tribute ($%d this tick)" % int(w.economy.res.money - money))
	d.declare_war(0, 2)
	e.tick()
	check(d.at_war(1, 2), "it joins your war against %s" % d.name_of(2))
	e.fears[0] = e.clock - 1.0
	d.set_score(2, 0, -95.0)
	d.set_score(1, 0, -95.0)
	check(d.ai_wants_war(2, 0) or d.at_war(2, 0), "the fear passes in time")
	check(not d.ai_wants_war(1, 0), "but a client state never turns on you")
	e.tick()
	check(d.rel(0, 1) >= 70.0, "its government stays loyal (relations held at +70)")
	var saved: Dictionary = e.capture()
	e.puppets.clear()
	e.restore(saved)
	check(e.puppets.has(1), "the client state survives a save and load")

	# 4: failure. A second raid, on nation 2, goes wrong.
	if d.at_war(0, 2) == false: d.declare_war(2, 0)
	e.advance(40.0)   # the agent comes home
	prepare(e, 2)
	if not w.units.any(func(u): return u.owner == 0 and not u.dead and u.key == "commando"):
		w.spawn_unit("commando", ground(home + Vector3(22, 0, 22)), 0)
	w.spawn_unit("helicopter", ground(home + Vector3(30, 0, 22)), 0)
	var teams: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == "commando").size()
	var helos: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key in ["helicopter", "gunship"]).size()
	var reason: String = e.blocked_reason(RC.KEY, 2)
	check(reason == "", "a second raid can be prepared (\"%s\")" % reason)
	e.run(RC.KEY, 2, "", -1, 0.99)
	e.advance(160.0)
	var teams_after: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == "commando").size()
	var helos_after: int = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key in ["helicopter", "gunship"]).size()
	check(not e.puppets.has(2) and teams_after == teams - 1 and helos_after == helos - 1, "a failed raid loses a special forces team and a helicopter")
	check(d.at_war(0, 2) and e.active(2, "alert") and e.scandal_until > e.clock, "the target is at war with you and on alert, and a scandal follows")

	# 5: a rival United States raids on its own: another rival, then you.
	e.puppets.clear()
	w.map.nations[1].id = "usa"
	var rival_us: Dictionary = w.market.ai_nation(1)
	rival_us.tech = 6.0
	rival_us.money = 20000.0
	if d.at_war(0, 1): d.make_peace(0, 1)
	for grid in [d.alliance, d.pact, d.nap]: d.set_flag(grid, 1, 2, false)
	d.declare_war(1, 2)
	e.ai_raid_next.clear()
	e.ai_raids.clear()
	RC.ai_consider(e, true)
	check(e.ai_raids.size() == 1 and int(e.ai_raids[0].raider) == 1 and float(rival_us.money) <= 20000.0 - RC.AI_COST,
		"a rival United States at era 3, at war, plans a raid of its own ($%d)" % int(RC.AI_COST))
	e.ai_raids.clear()
	RC.launch(e, 1, 2, 0.0)
	e.advance(RC.AI_PREPARE + 10.0)
	e.tick()   # (rival raids are carried out on the intelligence tick)
	check(e.puppets.has(2) and int(e.puppets[2].get("patron", -1)) == 1 and d.allied(1, 2) and not d.at_war(1, 2),
		"its raid succeeds: %s becomes %s's client state" % [d.name_of(2), d.name_of(1)])
	d.set_score(0, 1, -95.0)
	check(RC.feared(w, 1) and RC.restrains(w, 2, 1) and not d.ai_wants_war(2, 1), "the world fears that United States, and its client never turns on it")
	var nat2 = w.market.ai_nation(2)
	nat2.money = 5000.0
	var lord_before: float = float(rival_us.money)
	e.tick()
	check(float(rival_us.money) > lord_before, "the client pays its tribute to its patron")
	# A raid on you: your country cannot become a puppet, but you lose your leader.
	e.puppets.clear()
	d.declare_war(1, 0)
	money = w.economy.res.money
	RC.launch(e, 1, 0, 0.0)
	e.advance(RC.AI_PREPARE + 10.0)
	e.tick()   # (rival raids are carried out on the intelligence tick)
	check(not d.at_war(0, 1) and w.economy.res.money < money * 0.8 and not e.puppets.has(0),
		"a raid on you seizes your leader: a quarter of the treasury lost, a ceasefire signed ($%d -> $%d)" % [int(money), int(w.economy.res.money)])
	d.declare_war(1, 0)
	e.security_until = e.clock + 400.0
	var guarded: float = RC.ai_chance(e, 0)
	e.security_until = 0.0
	check(guarded < RC.ai_chance(e, 0), "a counter-intelligence review makes a raid on you likelier to fail (%d%% against %d%%)" % [roundi(guarded * 100), roundi(RC.ai_chance(e, 0) * 100)])
	money = w.economy.res.money
	RC.launch(e, 1, 0, 0.99)
	e.advance(RC.AI_PREPARE + 10.0)
	e.tick()   # (rival raids are carried out on the intelligence tick)
	check(d.at_war(0, 1) and w.economy.res.money >= money - 1.0, "a foiled raid costs you nothing; the war goes on")

	print("\nREGIME_CHANGE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("REGIME_CHANGE PASS" if errors.is_empty() else "REGIME_CHANGE FAIL")
	quit(0 if errors.is_empty() else 1)
