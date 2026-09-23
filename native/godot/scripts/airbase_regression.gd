## --airbase-test: an airfield has four parking slots. New jets park on them,
## a fifth cannot be trained, a jet ordered out taxis, takes off and flies,
## and a jet ordered onto the base lands, taxis in and parks on its slot.
## --capture-airfield renders the base with its aircraft (build/airfield-*.png).
extends RefCounted

const DT := 1.0 / 30.0

static func setup(w: Node) -> Dictionary:
	for k in w.economy.res.keys():
		w.economy.res[k] = 99999.0
	w.economy.pop_cap = 500
	# A hex clear of deposits and buildings, a short way from the capital.
	var at = null
	for r in range(3, 12):
		for k in range(12):
			var p: Vector3 = w.snap_to_hex(w.start + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * r * 18.0)
			if w.site_problem("airfield", p, 0) in ["", "Outside your territory"] and w.deposit_near(p, 16.0) == null:
				at = p
				break
		if at != null:
			break
	var base: Dictionary = w.place_building("airfield", at, 0, true)
	w.logistics.update_supply()
	return base

static func run(w: Node) -> void:
	w.set_physics_process(false)
	await w.get_tree().physics_frame
	var failures := PackedStringArray()
	var base := setup(w)
	for i in range(4):
		w.queue_unit(base, "jet")
	w.queue_unit(base, "jet")
	if base.queue.size() != 4:
		failures.append("the queue took %d jets for 4 slots" % base.queue.size())
	for f in range(int(60.0 / DT) * 4):
		w.update_training(DT)
		if base.queue.is_empty():
			break
	var jets: Array = w.units.filter(func(u): return u.key == "jet" and u.owner == 0 and not u.dead)
	var parked := jets.filter(func(u): return u.air_state == "parked")
	if parked.size() != 4:
		failures.append("%d of 4 new jets parked on the apron" % parked.size())
	var slots := {}
	for u in parked:
		slots[u.slot] = true
		if u.node.position.distance_to(w.AirOperations.slot_point(w, base, u.slot)) > 0.5:
			failures.append("jet not on its slot")
	if slots.size() != parked.size():
		failures.append("two jets share a slot")
	if w.AirOperations.room(w, base) != 0:
		failures.append("a full base reports room")
	# One jet goes out.
	var jet: Dictionary = parked[0]
	w.order_move([jet], base.root.position + Vector3(120, 0, 80))
	var seen := {}
	for f in range(int(40.0 / DT)):
		w.move_craft(jet, DT)
		seen[jet.air_state] = true
		if jet.air_state == "ready":
			break
	if not (seen.has("taxi_out") and seen.has("takeoff") and jet.air_state == "ready"):
		failures.append("an ordered jet did not taxi out and take off (%s)" % str(seen.keys()))
	for f in range(int(10.0 / DT)):
		w.move_craft(jet, DT)
	# And comes back to land.
	w.order_move([jet], base.root.position)
	seen.clear()
	for f in range(int(120.0 / DT)):
		w.move_craft(jet, DT)
		seen[jet.air_state] = true
		if jet.air_state == "parked":
			break
	if jet.air_state != "parked" or not seen.has("taxi_in"):
		failures.append("a jet ordered onto the base did not land, taxi in and park (%s, now %s)" % [str(seen.keys()), jet.air_state])
	elif jet.node.position.distance_to(w.AirOperations.slot_point(w, base, jet.slot)) > 0.5:
		failures.append("the jet came back to the wrong place")
	print("AIRBASE 4 slots, %d parked, cycle %s" % [parked.size(), str(seen.keys())])
	if failures.is_empty():
		print("AIRBASE_TEST PASS")
	else:
		for f in failures:
			print("AIRBASE_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)

static func capture(w: Node) -> void:
	for i in range(30):
		await w.get_tree().process_frame
	var base := setup(w)
	for i in range(3):
		var j: Dictionary = w.spawn_unit(["jet", "bomber", "drone"][i], base.root.position, 0)
		w.AirOperations.park_new(w, j, base)
	var heli: Dictionary = {}
	for shot in [["airfield", 34.0, 1.3, 0.0], ["airfield-low", 28.0, 0.5, 2.2]]:
		w.cam_focus = base.root.position
		w.cam_dist = shot[1]
		w.cam_dist_target = shot[1]
		w.cam_pitch = shot[2]
		w.cam_yaw = shot[3]
		for f in range(30):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/%s.png" % shot[0])
	w.get_tree().quit()
