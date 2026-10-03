extends SceneTree
## The sixth-generation battle group (future_weapons.gd): a fighter and its
## two loyal wingmen are three units that select, fly, attack and defend as
## one; the enemy shoots the wingmen first; on the ground they wait aboard
## (off the map), a lost one is replaced while the fighter rearms, and they
## launch as it takes off. Helicopters keep to helipads.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Future := preload("res://scripts/future_weapons.gd")
const Factions := preload("res://scripts/factions.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func sim(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT

func air(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z) + 26.0, at.z)

## Which side of the fighter's nose `u` flies on: -1 left, 1 right.
func side(leader: Dictionary, u: Dictionary) -> float:
	var local: Vector3 = Basis(Vector3.UP, leader.heading).inverse() * (u.node.position - leader.node.position)
	return signf(local.x)

func run() -> void:
	set_meta("match_config", {"map": "pangaea", "players": 2, "nation": Factions.IDS.find("usa"), "style": "sandbox"})
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
	w.diplomacy.declare_war(1, 0)
	for n in w.ai.nations: n.money = 50000.0
	w.economy.res.money = 50000.0
	w.economy.res.oil = 5000.0
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var start: Vector3 = home + Vector3(0, 0, 60)

	# 1: the group, and a click on any of it.
	var leader: Dictionary = w.spawn_unit("sixthGen", air(start), 0)
	leader.air_state = "ready"
	leader.orbit = leader.node.position
	var wing: Array = Future.escort(w, leader)
	check(Future.group_of(w, leader).size() == 3 and Future.group_of(w, wing[1]).size() == 3 and wing.all(func(u): return u.key == "wingman"),
		"an %s takes off with two loyal wingmen: three units, one group" % w.unit_defs.sixthGen.name)
	for u in w.units: u.selected = false
	wing[0].selected = true
	Future.select_group(w, wing[0])
	check(leader.selected and wing[1].selected, "a click on one wingman selects the whole group")
	for u in w.units: u.selected = false

	# 2: formation on a straight leg.
	sim(2.0)
	w.order_move([leader], air(start + Vector3(420, 0, 60)))
	var first: Array = wing.map(func(u): return int(Vector2(u.node.position.x - leader.node.position.x, u.node.position.z - leader.node.position.z).length()))
	sim(9.0)
	var gaps: Array = wing.map(func(u): return int(Vector2(u.node.position.x - leader.node.position.x, u.node.position.z - leader.node.position.z).length()))
	check(gaps.all(func(g): return g < 22) and side(leader, wing[0]) != side(leader, wing[1]),
		"on a straight leg the wingmen close up and hold their slots, one off each wing (%s m from the fighter, from %s)" % [str(gaps), str(first)])

	# 3: attacking together.
	var target: Dictionary = w.spawn_unit("tank", Vector3(start.x + 200, w.height_at(start.x + 200, start.z + 90), start.z + 90), 1)
	target.target = target.node.position
	leader.enemy = target
	leader.target = null
	sim(1.0)
	check(wing.all(func(u): return is_same(u.enemy, target)), "the wingmen strike the fighter's target")
	leader.enemy = null
	for u in wing: u.enemy = null
	w.kill(target)
	sim(1.0)

	# 4: defending: a hostile jet goes for one wingman; the fighter and the other wingman turn on it.
	var bandit: Dictionary = w.spawn_unit("jet", air(leader.node.position + Vector3(40, 0, 0)), 1)
	bandit.air_state = "ready"
	bandit.enemy = wing[0]
	leader.enemy = null
	leader.target = null
	Future.command(w, leader)
	check(is_same(leader.enemy, bandit) and is_same(wing[1].enemy, bandit), "whatever attacks one of the group is met by all of it (fighter and wingmen)")
	w.kill(bandit)
	sim(0.6)

	# 5: drawing fire: an enemy fighter beside the group picks a wingman, not the escorted fighter.
	leader.enemy = null
	for u in wing: u.enemy = null
	Future.command(w, leader)
	var hunter: Dictionary = w.spawn_unit("jet", air(leader.node.position + Vector3(0, 0, 3)), 1)
	hunter.air_state = "ready"
	wing[0].node.position = leader.node.position + Vector3(2, 0, 0)
	wing[1].node.position = leader.node.position + Vector3(-2, 0, 0)
	var picked = preload("res://scripts/tactics.gd").pick_target(w, hunter, 40.0)
	check(picked != null and picked.key == "wingman", "an enemy fighter goes for a wingman before the escorted fighter (it picked the %s)" % ("nothing" if picked == null else picked.key))
	w.kill(hunter)

	# 6: home together: on the ground the wingmen are aboard (off the map), a lost
	# one is replaced while the fighter rearms, and both launch as it takes off.
	w.kill(wing[0])
	sim(0.2)
	leader.air_state = "rearming"
	leader.service_left = 30.0
	var money: float = w.economy.res.money
	var flying_before: int = w.units.filter(func(u): return not u.dead and u.key == "wingman").size()
	Future.command(w, leader)
	sim(0.2)
	var flying_after: int = w.units.filter(func(u): return not u.dead and u.key == "wingman").size()
	check(Future.mates(w, leader).is_empty() and flying_after == flying_before - 1 and int(leader.wingmen_stowed) == 2 and money - w.economy.res.money >= Future.REPLACE_COST,
		"on the ground its wingmen are aboard, off the map, and the lost one is replaced ($%d; %d aboard)" % [int(money - w.economy.res.money), int(leader.wingmen_stowed)])
	leader.air_state = "ready"
	Future.command(w, leader)
	check(Future.mates(w, leader).size() == 2 and int(leader.wingmen_stowed) == 0, "as it takes off, both are launched beside it")
	# A squadron parked on its airfield puts no wingman on the map.
	var parked := []
	for i in range(6):
		var f: Dictionary = w.spawn_unit("sixthGen", air(start + Vector3(-60 - i * 12, 0, 0)), 0)
		f.air_state = "parked"
		parked.append(f)
		Future.escort(w, f)
	var extra: int = w.units.filter(func(u): return not u.dead and u.key == "wingman" and parked.any(func(f): return is_same(u.get("leader"), f))).size()
	check(extra == 0 and parked.all(func(f): return int(f.wingmen_stowed) == 2), "six parked fighters: their twelve wingmen wait aboard, none on the map")

	# 7: helicopters land on helipads only; an airfield's slots are the jets'.
	var Air := preload("res://scripts/air_operations.gd")
	var field: Dictionary = w.place_building("airfield", w.test_site("airfield", home + Vector3(-90, 0, -60)), 0, true)
	var pad: Dictionary = w.place_building("helipad", w.test_site("helipad", home + Vector3(90, 0, -60)), 0, true)
	var heli: Dictionary = w.spawn_unit("helicopter", air(home + Vector3(0, 0, -40)), 0)
	var jet: Dictionary = w.spawn_unit("jet", air(home + Vector3(10, 0, -40)), 0)
	check(not Air.available(w, heli, field) and Air.available(w, heli, pad) and Air.available(w, jet, field) and not Air.available(w, jet, pad),
		"a helicopter may not take an airfield slot; a jet may not take a helipad")
	check(not Air.park_new(w, heli, field), "a helicopter is never parked on an airfield's apron")
	var base = Air.base_for(w, heli)
	check(base != null and base.key == "helipad", "a returning helicopter heads for a helipad (%s)" % ("none" if base == null else base.key))
	print("\nBATTLE_GROUP: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("BATTLE_GROUP PASS" if errors.is_empty() else "BATTLE_GROUP FAIL")
	quit(0 if errors.is_empty() else 1)
