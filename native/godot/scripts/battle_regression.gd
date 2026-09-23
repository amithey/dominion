## --battle-test: a set-piece fight between two mixed forces, measured.
## Fails when the fight stalls (enemies within reach but nobody firing),
## when units pile onto one spot, or when a unit freezes with an enemy it
## neither shoots nor approaches.
extends RefCounted

const DT := 1.0 / 60.0

static func step(w: Node) -> void:
	w._physics_process(DT)
	w.effects._physics_process(DT)
	w.effects.debris._physics_process(DT)

## Two equal mixed forces on open ground, ordered to attack-move into each other.
static func setup(w: Node) -> Dictionary:
	if w.ai and not w.ai.nations.is_empty():
		w.ai.declare_war(1, false)
	# Two equal mixed forces on open ground, 110 m apart, clear of the capital.
	var far: Vector3 = w.land_point(w.start, 150.0)
	var axis: Vector3 = (far - w.start).normalized()
	var a: Vector3 = w.start + axis * 45.0
	var b: Vector3 = w.start + axis * 150.0
	var fighters: Array = []
	for side in [[a, 0, axis], [b, 1, -axis]]:
		var centre: Vector3 = side[0]
		var across := Vector3(-side[2].z, 0, side[2].x)
		var roster := ["soldier", "soldier", "soldier", "soldier", "soldier", "soldier", "soldier", "soldier",
			"rocketSoldier", "rocketSoldier", "sniper", "tank", "tank", "tank", "apc", "artillery"]
		for i in range(roster.size()):
			var spot: Vector3 = centre + across * ((i % 6) - 2.5) * 4.0 - side[2] * floorf(i / 6.0) * 5.0
			var u: Dictionary = w.spawn_unit(roster[i], spot, side[1])
			u.heading = atan2(side[2].x, side[2].z)
			fighters.append(u)
	w.order_move(fighters.filter(func(u): return u.owner == 0), b, true)
	w.order_move(fighters.filter(func(u): return u.owner == 1), a, true)
	return {"fighters": fighters, "a": a, "b": b, "axis": axis}

## --capture-tactics: the same fight rendered: ranks on the march, firing
## lines, and the minimap turned with the camera.
static func capture(w: Node) -> void:
	await w.get_tree().physics_frame
	var fight := setup(w)
	var mid: Vector3 = (fight.a + fight.b) * 0.5
	var shots := [[3.0, "march", fight.a + fight.axis * 12.0, 70.0], [12.0, "contact", mid, 80.0], [17.0, "firefight", mid, 62.0]]
	var elapsed := 0.0
	for shot in shots:
		while elapsed < shot[0]:
			await w.get_tree().process_frame
			elapsed += w.get_process_delta_time()
			w.cam_focus = w.cam_focus.lerp(shot[2], 0.1)
			w.cam_dist_target = shot[3]
			w.cam_pitch = 0.9
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/tactics-%s.png" % shot[1])
	for yaw in [0.0, PI * 0.25, 2.2]:
		w.cam_yaw = yaw
		for i in range(20):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = w.get_viewport().get_texture().get_image()
		var sz := img.get_size()
		img.get_region(Rect2i(sz.x - 240, sz.y - 240, 240, 240)).save_png("res://build/minimap-%d.png" % int(yaw * 100))
	w.get_tree().quit()

static func run(w: Node) -> void:
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.effects.debris.set_physics_process(false)
	await w.get_tree().physics_frame
	var fight := setup(w)
	var fighters: Array = fight.fighters
	var a: Vector3 = fight.a
	var axis: Vector3 = fight.axis
	var track := {}   # unit -> [position 5 s ago, time]
	var stalled_units := 0   # seconds a unit spent loaded, in range and silent
	var silent := {}
	var frozen := {}
	var worst_pile := 0
	var pile_seconds := 0
	var report := PackedStringArray()
	for second in range(120):
		var shots_before: int = w.shots_fired
		for f in range(60):
			w._physics_process(DT)
			w.effects._physics_process(DT)
			w.effects.debris._physics_process(DT)
			if f % 6 == 0:
				# Silent: loaded, its target in range and the gun on it, yet not firing.
				for u in fighters:
					if u.dead:
						continue
					var id: int = u.node.get_instance_id()
					var ready: bool = u.enemy != null and u.reload <= 0.0 and w.gap_to(u, u.enemy) <= u.range
					if ready and u.turret != null:
						var g: Vector3 = u.enemy.node.position - u.node.position
						ready = absf(angle_difference(u.turret_yaw, atan2(g.x, g.z) - u.heading)) <= 0.12
					silent[id] = float(silent.get(id, 0.0)) + 0.1 if ready else 0.0
					if silent[id] > 1.0:
						silent[id] = 0.0
						stalled_units += 1
						print("BATTLE   silent %s owner %d t=%.1f: enemy=%s gap %.1f/%.0f moving=%s holding=%s" % [u.key, u.owner, w.game_time, u.enemy.get("key", "building"), w.gap_to(u, u.enemy), u.range, u.moving, u.get("holding", false)])
		var shots: int = w.shots_fired - shots_before
		var alive := [0, 0]
		var in_contact := 0
		var pile := 0
		var live: Array = fighters.filter(func(u): return not u.dead)
		for u in live:
			alive[mini(u.owner, 1)] += 1
			var threat = w.nearest_enemy(u, u.range)
			if threat != null and not threat.get("is_building", false):
				in_contact += 1
			for o in live:
				if not is_same(o, u) and o.owner == u.owner and u.vehicle == o.vehicle and Vector2(o.node.position.x - u.node.position.x, o.node.position.z - u.node.position.z).length() < (4.0 if u.vehicle else 0.8):
					pile += 1  # soldiers inside a metre of each other, or hulls overlapping
			# Frozen: has an enemy, is not firing and has not moved for five seconds.
			var id: int = u.node.get_instance_id()
			var was = track.get(id)
			if was == null or w.game_time - was[1] >= 5.0:
				if was != null and u.enemy != null and u.node.position.distance_to(was[0]) < 0.5 and w.game_time - float(u.get("last_fire", -100.0)) > 5.0:
					frozen[id] = "%s owner %d (enemy %s at %.1f m, range %.0f, holding %s moving %s speed %.2f path %d heading err %.2f)" % [u.key, u.owner, u.enemy.get("key", "?"), w.gap_to(u, u.enemy), u.range, u.get("holding", false), u.moving, u.get("cur_speed", 0.0), u.path.size(), absf(angle_difference(u.heading, atan2(u.enemy.node.position.x - u.node.position.x, u.enemy.node.position.z - u.node.position.z)))]
				track[id] = [u.node.position, w.game_time]
		pile /= 2
		worst_pile = maxi(worst_pile, pile)
		if pile > 3:
			pile_seconds += 1
		if second % 10 == 9:
			report.append("t=%d s: alive %d vs %d, in contact %d, shots/s %d, piled pairs %d" % [second + 1, alive[0], alive[1], in_contact, shots, pile])
		if alive[0] == 0 or alive[1] == 0:
			report.append("t=%d s: decided, alive %d vs %d" % [second + 1, alive[0], alive[1]])
			break
	for line in report:
		print("BATTLE " + line)
	var failures := PackedStringArray()
	# Phase two: an ordered attack, then a plain move. Nobody may stay stuck.
	for u in w.units:
		if not u.dead and u.owner != 0 and u.node.position.distance_to(a) < 120.0:
			w.kill(u)
	var squad: Array = []
	for i in range(5):
		squad.append(w.spawn_unit("tank" if i == 0 else "soldier", a + Vector3(i * 3.0, 0, 0), 0))
	var victim: Dictionary = w.spawn_unit("soldier", a + axis * 38.0, 1)
	w.order_attack(squad, victim)
	var killed_after := -1.0
	for f in range(60 * 25):
		step(w)
		if victim.dead:
			killed_after = f / 60.0
			break
	if killed_after < 0.0:
		failures.append("an ordered attack on a lone soldier 38 m away did not kill it in 25 s")
	var after: Vector3 = a - axis * 25.0
	w.order_move(squad, after)
	var arrived := -1.0
	for f in range(60 * 25):
		step(w)
		if squad.all(func(u): return u.dead or u.target == null):
			arrived = f / 60.0
			break
	if arrived < 0.0:
		var lost := squad.filter(func(u): return not u.dead and u.target != null)
		var why := PackedStringArray()
		for u in lost:
			why.append("%s %.1f m off, enemy %s, moving %s, speed %.1f, stuck %d" % [u.key, Vector2(u.target.x - u.node.position.x, u.target.z - u.node.position.z).length(), u.enemy.get("key", "?") if u.enemy != null else "none", u.moving, u.get("cur_speed", 0.0), u.get("stuck", 0)])
		failures.append("%d units still had not arrived 25 s after a move order that followed an attack: %s" % [lost.size(), "; ".join(why)])
	# Ground troops ordered onto a ship neither freeze on it nor wade after it.
	var sea = w.water_near(w.start, 320)
	var boat_check := "no sea nearby"
	if sea != null:
		var boat: Dictionary = w.spawn_unit("gunboat", sea, 1)
		var shore: Vector3 = w.nearest_shore(sea)
		var landlubbers: Array = [w.spawn_unit("soldier", w.land_point(shore, 25.0), 0)]
		w.order_attack(landlubbers, boat)
		for f in range(60 * 3):
			step(w)
		var l: Dictionary = landlubbers[0]
		boat_check = "enemy dropped" if l.enemy == null else "still aiming at the ship"
		if l.enemy != null and w.gap_to(l, boat) > l.range:
			failures.append("a soldier kept chasing an out-of-reach ship")
		w.kill(boat)
	print("BATTLE phase two: target killed after %.1f s, squad arrived %.1f s after the move order; ship: %s" % [killed_after, arrived, boat_check])
	if stalled_units > 0:
		failures.append("%d times a unit sat loaded, on target and silent for a second" % stalled_units)
	if pile_seconds > 5:
		failures.append("units piled on one spot for %d seconds (worst %d pairs)" % [pile_seconds, worst_pile])
	if frozen.size() > 0:
		failures.append("%d units froze with an enemy: %s" % [frozen.size(), ", ".join(PackedStringArray(frozen.values().slice(0, 5)))])
	if failures.is_empty():
		print("BATTLE_TEST PASS: %d shots, %d silent unit-seconds, worst pile %d pairs" % [w.shots_fired, stalled_units, worst_pile])
	else:
		for f in failures:
			print("BATTLE_TEST FAIL: " + f)
	w.get_tree().quit(0 if failures.is_empty() else 1)
