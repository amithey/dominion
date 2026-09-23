extends RefCounted

static func run(w: Node) -> void:
	var failures: Array[String] = []
	w.set_physics_process(false)
	var tank: Dictionary = w.spawn_unit("tank",w.start,0)
	var building: Dictionary = w.place_building("housing",w.start+Vector3(40,0,0),1,true)
	w.order_attack([tank],building)
	var hp: float = building.hp
	w.shell_hit(tank,building.node.position)
	if not w.hostile(0,1) or building.hp >= hp:
		failures.append("First explicit shell strike must damage a neutral building")
	if not is_instance_valid(building.get("damage_label")):
		failures.append("Building hit has no visible damage feedback")
	# A half-link belongs to exactly one hex, including a strike away from asphalt.
	var h: Vector2i = w.logistics.world_hex(w.start)
	var neighbor: Vector2i = h+Vector2i(1,0)
	var edge := {"a":h,"b":neighbor,"owner":0,"kind":"road","half":[100.0,100.0],"hp":100.0,"max_hp":100.0}
	w.logistics.edges.clear()
	w.logistics.edges["regression"] = edge
	w.logistics.damage_at(w.logistics.hex_center(h),1.0,40.0)
	if edge.half != [60.0,100.0]:
		failures.append("Conventional strike crossed a hex boundary")
	w.logistics.damage_at(w.logistics.hex_center(h),80.0,40.0,true)
	if edge.half[1] >= 100.0:
		failures.append("Nuclear radius did not reach adjacent infrastructure")
	w.order_bombard([tank],w.logistics.hex_center(h))
	if not tank.has("ground_attack"):
		failures.append("Infrastructure bombardment order missing")
	w.order_move([tank],w.start)
	if tank.has("ground_attack") or tank.enemy != null:
		failures.append("Move did not cancel bombardment")
	var jet: Dictionary = w.spawn_unit("jet",w.start+Vector3(0,0,-50),0)
	jet.target = jet.node.position
	var before: Vector3 = jet.node.position
	w.move_craft(jet,0.1)
	if jet.node.position.distance_to(before)<0.1:
		failures.append("Fixed-wing aircraft stopped at its waypoint")
	jet.ammo = 1
	w.AirOperations.consume(jet)
	if w.fire(jet,building):
		failures.append("Empty aircraft fired")
	for b in w.buildings:
		if b.key in ["airfield","helipad"]:
			b.supplied = false
	w.move_craft(jet,0.1)
	if jet.ammo != 0 or jet.air_state != "no base":
		failures.append("Aircraft replenished without an available base")
	var base: Dictionary = w.place_building("airfield",w.start+Vector3(40,0,40),0,true)
	base.supplied = true
	var visited := {}
	var service_time := 0.0
	for i in range(18000):
		visited[jet.air_state] = true
		if jet.air_state == "rearming":
			service_time += 1.0/60.0
		w.move_craft(jet,1.0/60.0)
		if jet.air_state == "ready":
			break
	if jet.air_state != "ready" or jet.ammo != w.AirOperations.CAPACITY.jet or service_time<11.9 or not visited.has("landing") or not visited.has("takeoff"):
		failures.append("Return / landing / timed rearm / takeoff cycle failed: %s" % jet.air_state)
	jet.ammo = 2
	var save: Dictionary = w.saves.capture()
	var aircraft: Array = save.units.filter(func(u): return u.key == "jet")
	if not aircraft.any(func(u): return u.ammo == 2):
		failures.append("Save omitted aircraft ammunition")
	base.dead = true
	jet.ammo = 0
	jet.air_state = "returning"
	w.move_craft(jet,0.1)
	if jet.air_state != "no base":
		failures.append("Destroyed base remained available")
	w.saves.restore(save)
	var restored: Array = w.units.filter(func(u): return u.key == "jet" and u.get("ammo",-1) == 2)
	if restored.is_empty():
		failures.append("Save/load replenished or lost ammunition")
	else:
		for u in w.units:
			u.selected = false
		restored[0].selected = true
		w.hud._update_selection()
		if not "Ammunition: 2/4" in w.hud._sel_info.text:
			failures.append("Aircraft selection omitted ammunition")
		if "--capture-operations" in OS.get_cmdline_user_args():
			await w.capture_view("res://build/aircraft-ammunition.png",restored[0].node.position,90.0,0.65,30)
	await w.get_tree().process_frame
	await w.get_tree().process_frame
	print("COMBAT_REGRESSION ","PASS" if failures.is_empty() else "FAIL", " ", failures)
	w.get_tree().quit(0 if failures.is_empty() else 1)
