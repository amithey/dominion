## --state-test: a nation works as a state.
## 1. A barracks far from its settlement's centre still trains (it once
##    belonged to no settlement, counted as cut off, and stalled at 0%).
## 2. A market anywhere in your land lets you trade.
## 3. After ten minutes, AI nations have built an economy, not only an army.
extends RefCounted

static func run(w: Node) -> void:
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	for k in w.economy.res.keys():
		w.economy.res[k] = 99999.0
	w.economy.pop_cap = 500
	var t: Node = w.territory
	var far = null
	for i in range(t.owner_of.size()):
		var c: Vector3 = t.center(i)
		var d: float = c.distance_to(w.start)
		if t.terrain[i] != t.Terrain.WATER and d > 90.0 and d < 120.0 and w.open_ground(c):
			far = w.snap_to_hex(c)
			break
	var barracks: Dictionary = w.place_building("barracks", far, 0, true)
	var market: Dictionary = w.place_building("market", far + Vector3(0, 0, 21), 0, true)
	w.logistics.update_supply()
	w.economy.recalculate()
	w.queue_unit(barracks, "soldier")
	for f in range(60 * 30):
		w.update_training(1.0 / 60.0)
	if not barracks.queue.is_empty():
		failures.append("a barracks %.0f m from the capital left its soldier at %d%% (supplied %s)" % [far.distance_to(w.start), int(barracks.queue_prog * 100), barracks.get("supplied", "?")])
	var sold: String = w.market.sell("iron", 25)
	if not sold.begins_with("Sold"):
		failures.append("a market far from the capital could not trade: " + sold)
	print("STATE far barracks trained: %s; market: %s" % [barracks.queue.is_empty(), sold])
	for f in range(60 * 60 * 10):
		w.ai._physics_process(1.0 / 60.0)
	for n in w.ai.nations:
		var civil := 0
		var military := 0
		for b in w.buildings:
			if b.owner == n.id and not b.dead and b.key != "hq":
				if b.def.get("cat", "") == "military":
					military += 1
				else:
					civil += 1
		print("STATE AI nation %d: %d economic and civic, %d military buildings" % [n.id, civil, military])
		if civil < military or civil < 6:
			failures.append("AI nation %d built %d economic and %d military buildings" % [n.id, civil, military])
	# A strategic submarine fires from the stockpile, with no silo at all.
	var sea = w.water_near(w.start, 320)
	if sea != null:
		for b in w.missiles.silos():
			b.dead = true
		var sub: Dictionary = w.spawn_unit("nuclearSub", sea, 0)
		var first: String = w.missiles.types().keys()[0]
		w.missiles.stock[first] = 2
		var said: String = w.missiles.launch(first, sea + Vector3(60, 0, 60), sub)
		print("STATE submarine launch: " + said)
		if w.missiles.stock[first] != 1 or w.missiles.flying.is_empty():
			failures.append("a strategic submarine could not launch a missile: " + said)
	# F8, for testing: plenty of everything, and it lasts.
	var money: float = w.economy.res.money
	w.economy.grant_test_resources()
	w.economy.tick()
	if w.economy.res.money < money + 99000.0 or w.economy.res.get("iron", 0.0) < 90000.0 or w.economy.pop_cap < 200:
		failures.append("F8 did not grant the test resources (money %.0f, iron %.0f, army cap %d)" % [w.economy.res.money, w.economy.res.get("iron", 0.0), w.economy.pop_cap])
	if failures.is_empty():
		print("STATE_TEST PASS")
	else:
		for f in failures:
			print("STATE_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
