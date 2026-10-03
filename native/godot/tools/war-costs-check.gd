extends SceneTree
const Costs = preload("res://scripts/war_costs.gd")
const Air = preload("res://scripts/air_operations.gd")
const Modern = preload("res://scripts/modern_warfare.gd")
var checks := 0
var failures: Array[String] = []
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func funds(money := 1000.0, oil := 1000.0) -> void:
	w.economy.res.money = money
	w.economy.res.oil = oil
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w == null: quit(1); return
	w.start_match("easy")
	paused = true
	w.saves.autosave_every = 0
	var tank := {"key": "tank", "owner": 0, "vehicle": true, "fly": false, "naval": false}
	for amount in [0.08, 0.35, 0.75, 1.2, 2.0, 5.0, 6.0, 12.0, 18.0, 150.0]:
		funds(amount, 5.0)
		check(Costs.pay(w, 0, amount, 5.0), "Exact resource boundary")
		check(is_zero_approx(w.economy.res.money) and is_zero_approx(w.economy.res.oil), "Exact deduction")
		funds(amount - 0.001, 5.0)
		var before: Dictionary = w.economy.res.duplicate()
		check(not Costs.pay(w, 0, amount, 5.0), "Insufficient money refused")
		check(w.economy.res == before, "No partial oil payment")
		funds(amount, 4.999)
		check(not Costs.pay(w, 0, amount, 5.0), "Insufficient fuel refused")
		check(is_equal_approx(w.economy.res.money, amount), "No partial money payment")
	check(not Costs.pay(w, 0, -1.0), "Negative cost refused")
	check(not Costs.pay(w, 0, INF), "Nonfinite cost refused")
	funds()
	check(Costs.travel(w, tank, Vector3.ZERO, Vector3(100, 50, 0)), "Tank fuel debit")
	check(is_equal_approx(w.economy.res.oil, 996.5), "Distance only, not height")
	for count in [1, 10, 30, 60, 120]:
		funds()
		for j in range(count):
			Costs.travel(w, tank, Vector3(float(j) / count * 100, 0, 0), Vector3(float(j + 1) / count * 100, 0, 0))
		check(absf(w.economy.res.oil - 996.5) < 0.00001, "Frame partition invariant")
	for key in ["soldier", "worker", "commando", "medic", "nuclearSub", "orca", "seaDrone"]:
		var u := {"key": key, "owner": 0, "vehicle": false, "naval": key in ["nuclearSub", "orca", "seaDrone"]}
		funds()
		check(Costs.travel(w, u, Vector3.ZERO, Vector3(100, 0, 0)), "Non-oil platform travels")
		check(w.economy.res.oil == 1000.0, "No motor fuel for " + key)
	for weapon in Costs.SALVO:
		funds()
		var price: float = Costs.shot_cost(tank, weapon)
		check(Costs.shot(w, tank, weapon), "Funded weapon " + weapon)
		check(is_equal_approx(w.economy.res.money, 1000.0 - price), "One bill per salvo")
	for n in w.ai.nations:
		n.money = 100.0
		check(Costs.pay(w, int(n.id), 5.0, 2.0), "AI paid resources")
		check(n.money == 89.0, "AI oil uses existing exchange weight")
		n.money = 1.0
		check(not Costs.pay(w, int(n.id), 5.0), "AI cannot fire free")
	check(not Costs.pay(w, 10000, 1.0), "Unknown owner refused")
	# Exercise the real firing path and its launch guards.
	funds()
	var shooter: Dictionary = w.spawn_unit("tank", w.start + Vector3(25, 0, 0), 0)
	var target: Dictionary = w.spawn_unit("tank", w.start + Vector3(35, 0, 0), 1)
	check(w.fire(shooter, target), "Tank actually fires")
	check(is_equal_approx(w.economy.res.money, 998.8), "Actual tank shell paid")
	funds(0.0)
	check(not w.fire(shooter, target), "Empty treasury prevents real fire")
	check(w.economy.res.money == 0.0, "No overdraft")
	funds()
	var bomber: Dictionary = w.spawn_unit("bomber", w.start + Vector3(-100, 0, 0), 0)
	bomber.air_state = "ready"
	bomber.ammo = 3
	bomber.heading = atan2(target.node.position.x - bomber.node.position.x, target.node.position.z - bomber.node.position.z)
	check(not w.fire(bomber, target), "Bomb not released out of geometry")
	check(w.economy.res.money == 1000.0, "Unreleased bomb costs nothing")
	check(Costs.INTERCEPT.laserAD < Costs.INTERCEPT.samSite and Costs.INTERCEPT.samSite < Costs.INTERCEPT.abmLauncher, "Defence price hierarchy")
	w.diplomacy.declare_war(0, 1)
	var battery: Dictionary = w.spawn_unit("abmLauncher", w.start + Vector3(15, 0, 15), 0)
	for u in w.units:
		if u.key in Costs.INTERCEPT and not is_same(u, battery): w.kill(u)
	funds()
	battery.intercept_ready = 0.0
	var incoming := {"type": "ballistic", "owner": 1, "arc": true, "engaged": {}}
	Modern.intercept(w, incoming, battery.node.position + Vector3(0, 10, 0), 0.8)
	check(is_equal_approx(w.economy.res.money, 982.0), "Real interceptor attempt pays before result")
	check(incoming.engaged.has(battery.node.get_instance_id()), "Funded engagement marked")
	check(battery.intercept_ready > w.game_time, "Funded launcher reloads")
	var intercept_count: int = w.intercepts.size()
	Modern.intercept(w, incoming, battery.node.position, 0.8)
	check(w.intercepts.size() == intercept_count and w.economy.res.money == 982.0, "No duplicate interceptor payment")
	funds(0.0)
	battery.intercept_ready = 0.0
	incoming = {"type": "ballistic", "owner": 1, "arc": true, "engaged": {}}
	Modern.intercept(w, incoming, battery.node.position, 0.8)
	check(incoming.engaged.is_empty(), "Unaffordable interception never launches")
	check(battery.intercept_ready == 0.0, "Unaffordable launcher does not reload")
	check(w.intercepts.size() == intercept_count, "No phantom interceptor")
	funds()
	Modern.intercept(w, incoming, battery.node.position, 0.8)
	check(incoming.engaged.has(battery.node.get_instance_id()), "Funding recovery allows incoming missile defence")
	# Real movement freezes a dry tank without discarding its order.
	funds(1000.0, 0.0)
	shooter.enemy = null
	shooter.target = shooter.node.position + Vector3(40, 0, 0)
	var origin: Vector3 = shooter.node.position
	for i in range(30): w._physics_process(1.0 / 30.0)
	check(shooter.node.position.distance_to(origin) < 0.1, "No dry tank movement")
	check(shooter.target != null, "Fuel shortage retains move order")
	funds()
	for i in range(90): w._physics_process(1.0 / 30.0)
	check(shooter.node.position.distance_to(origin) > 0.5, "Tank resumes after fuel arrives")
	check(w.economy.res.oil < 1000.0, "Live movement consumes fuel")
	w.kill(battery)
	# Display net rates, but do not deduct event costs a second time.
	var airfield_at = w.test_site("airfield", w.start)
	check(airfield_at != null, "Aircraft service fixture")
	var base: Dictionary = w.place_building("airfield", airfield_at, 0, true)
	check(Air.park_new(w, bomber, base), "Bomber parks for service")
	bomber.target = w.start + Vector3(80, 0, 80)
	funds(1000.0, 0.0)
	Air.update(w, bomber, 0.1)
	check(bomber.air_state == "parked", "No fuel prevents departure")
	check(w.economy.res.money == 1000.0, "Failed sortie has no fee")
	funds()
	Air.update(w, bomber, 0.1)
	check(bomber.air_state == "taxi_out", "Paid aircraft departs")
	check(w.economy.res.oil == 988.0, "Bomber prepays sortie fuel")
	Air.update(w, bomber, 0.1)
	check(w.economy.res.oil == 988.0, "Taxi does not pay twice")
	bomber.air_state = "ready"
	bomber.sortie_left = 0.1
	Air.update(w, bomber, 0.2)
	check(bomber.air_state in ["returning", "landing"], "Fuel endurance forces return")
	funds()
	w.economy.military_flow = {"money": 0.0, "oil": 0.0}
	w.economy.tick()
	var base_rates: Dictionary = w.economy.rates.duplicate()
	funds()
	Costs.pay(w, 0, 12.0, 2.0, "intercepts")
	var paid_money: float = w.economy.res.money
	w.economy.tick()
	check(w.economy.military_rates.money == 12.0 and w.economy.military_rates.oil == 2.0, "Operating rates captured")
	check(absf(w.economy.res.money - paid_money - (w.economy.rates.money + 12.0)) < 0.00001, "No double subtraction")
	check(w.economy.military_flow.money == 0.0, "Flow resets each tick")
	# Save round trip: cumulative spending and a partially used fuel load.
	bomber.sortie_left = 31.25
	var spent: Dictionary = w.economy.military_spending.duplicate()
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(data)
	check(spent.keys().all(func(k): return is_equal_approx(w.economy.military_spending[k], spent[k])), "Spending survives JSON/save restore")
	var saved_bomber = w.units.filter(func(u): return u.key == "bomber" and u.owner == 0)
	check(saved_bomber.any(func(u): return is_equal_approx(u.sortie_left, 31.25)), "Aircraft fuel timer restored")
	data.economy.erase("military_spending")
	for u in data.units: u.erase("sortie_left")
	w.saves.restore(data)
	check(w.economy.military_spending.money == 0.0, "Old save ledger default")
	check(w.units.filter(func(u): return u.key == "bomber")[0].sortie_left == 90.0, "Old save aircraft default")
	print("WAR_COSTS %s (%d checks)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
