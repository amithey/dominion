extends SceneTree
## Audit of every unit definition (native/ALPHA-1.0-REPORT.md): all of w.unit_defs at runtime (about 96).
## For each unit: its definition is sane and plausible for its class (speed, health, damage, range, cost against the
## class); where it is trained and who fields it (all 28 national identities tried); it spawns with a model, in its
## element; it hurts the target class it is made for and never its own side; it drives, sails or flies where it is
## sent; its brief and name read properly. Table: res://build/audit/units.txt
const Kit := preload("res://tools/audit_kit.gd")
const Cheats := preload("res://scripts/cheats.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
const Factions := preload("res://scripts/factions.gd")
const Extra := preload("res://scripts/additional_factions.gd")
const Brief := preload("res://scripts/brief.gd")
const DT := 1.0 / 30.0
## Units that exist only to be launched by something else (never trained).
const LAUNCHED := ["carrierJet", "carrierDrone", "shahed", "wingman", "interceptorDrone", "mirvWarhead"]
var K
var w: Node
var idents: Array = []
func _initialize() -> void: call_deferred("run")

func settle(seconds: float) -> void:
	for i in range(int(seconds / DT)):
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)

func play_as(id: String) -> void:
	w.map.nations[0]["id"] = id

func land(offset: Vector3) -> Vector3:
	return w.land_point(w.start + offset, 40.0)

func target_of(cls: String, at: Vector3, sea: Vector3) -> Dictionary:
	match cls:
		"infantry": return w.spawn_unit("soldier", at, 1)
		"light": return w.spawn_unit("apc", at, 1)
		"armor": return w.spawn_unit("tank", at, 1)
		"naval": return w.spawn_unit("destroyer", sea, 1)
		"air":
			var jet: Dictionary = w.spawn_unit("jet", at, 1)
			jet.air_state = "ready"
			return jet
	return w.place_building("barracks", at, 1, true)

func median(values: Array) -> float:
	if values.is_empty(): return 0.0
	var v := values.duplicate()
	v.sort()
	return float(v[v.size() / 2])

func cost_of(def: Dictionary) -> float:
	var total := 0.0
	for r in def.get("cost", {}):
		total += float(def.cost[r]) * (1.0 if r == "money" else (3.0 if r in ["iron", "oil"] else 5.0))
	return total

func class_of(def: Dictionary) -> String:
	return "air" if def.get("fly", false) else ("sea" if def.get("naval", false) else ("vehicle" if def.get("vehicle", false) else "foot"))

func run() -> void:
	K = Kit.new(self, "units")
	w = await K.boot({"map": "island", "players": 3, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for n in w.ai.nations: n.money = 10000000.0
	w.economy.grant_test_resources()
	w.diplomacy.declare_war(0, 1)
	idents = Factions.IDS.duplicate()
	var sea: Vector3 = w.water_near(w.start, 220)
	var keys: Array = w.unit_defs.keys()
	keys.sort()
	K.ok("units", "all", "%d unit definitions" % keys.size())

	# ---- trained where, and by whom
	var trained_at := {}
	for b in w.building_defs:
		for k in w.building_defs[b].get("trains", []):
			trained_at[k] = b
	var fielded := {}
	var research_need := {}
	for key in keys:
		fielded[key] = []
	for id in idents:
		play_as(id)
		Cheats.everything(w)   # (every programme open: this asks who may field a unit, not what they have researched)
		for key in keys:
			if w.unit_allowed(0, key):
				fielded[key].append(id)
	play_as("usa")

	# ---- definition sanity and plausibility, per class
	var by_class := {"foot": [], "vehicle": [], "sea": [], "air": []}
	for key in keys:
		var d: Dictionary = w.unit_defs[key]
		by_class[class_of(d)].append(key)
	var med := {}
	for c in by_class:
		med[c] = {"speed": median(by_class[c].map(func(k): return float(w.unit_defs[k].get("speed", 0)))), "hp": median(by_class[c].map(func(k): return float(w.unit_defs[k].get("hp", 0)))), "range": median(by_class[c].filter(func(k): return float(w.unit_defs[k].get("dmg", 0)) > 1.0).map(func(k): return float(w.unit_defs[k].get("range", 0))))}
	for key in keys:
		var d: Dictionary = w.unit_defs[key]
		var c := class_of(d)
		var problems := PackedStringArray()
		var notes := PackedStringArray()
		if str(d.get("name", "")).strip_edges() == "" or str(d.name).contains("null"): problems.append("no proper name")
		if float(d.get("hp", 0)) <= 0.0: problems.append("hp <= 0")
		if float(d.get("speed", 0)) <= 0.0 and not key in ["decoy"]: notes.append("speed 0")
		if float(d.get("dmg", 0)) > 1.0:
			if float(d.get("range", 0)) <= 0.0: problems.append("armed but range 0")
			if float(d.get("cooldown", 0)) <= 0.0: problems.append("armed but cooldown 0")
			if float(d.get("aggro", 0)) < float(d.get("range", 0)) * 0.8: notes.append("aggro %d below range %d" % [int(d.aggro), int(d.range)])
		var speed := float(d.get("speed", 0))
		if speed > 0.0 and med[c].speed > 0.0 and (speed > med[c].speed * 3.0 or speed < med[c].speed / 3.0): notes.append("speed %.1f vs class median %.1f" % [speed, med[c].speed])
		if float(d.get("hp", 0)) > med[c].hp * 6.0 or float(d.get("hp", 0)) < med[c].hp / 6.0: notes.append("hp %d vs class median %d" % [int(d.hp), int(med[c].hp)])
		if float(d.get("dmg", 0)) > 1.0 and med[c].range > 0.0 and float(d.get("range", 0)) > med[c].range * 4.0: notes.append("range %d vs class median %d" % [int(d.range), int(med[c].range)])
		if trained_at.has(key) and cost_of(d) <= 0.0: problems.append("trained but free")
		if cost_of(d) > 0.0 and float(d.get("dmg", 0)) > 1.0 and float(d.hp) * float(d.dmg) / cost_of(d) > 400.0: notes.append("value for price %.0f (very high)" % (float(d.hp) * float(d.dmg) / cost_of(d)))
		var brief: Dictionary = Brief.unit(w, key)
		if str(brief.role).length() > 130 or (brief.points as Array).size() > 3: problems.append("brief too long")
		if str(d.get("desc", "")).strip_edges() == "": problems.append("no description")
		if not trained_at.has(key) and not key in LAUNCHED: notes.append("trained nowhere")
		if trained_at.has(key) and fielded[key].is_empty(): problems.append("fielded by no nation")
		var detail := "%s, %s: speed %.1f hp %d dmg %d range %d, cost %d; trained at %s; fielded by %s" % [c, d.get("name", key), speed, int(d.get("hp", 0)), int(d.get("dmg", 0)), int(d.get("range", 0)), int(cost_of(d)), str(trained_at.get(key, "-")), "everyone" if fielded[key].size() == idents.size() else (",".join(PackedStringArray(fielded[key].slice(0, 6))) + ("..." if fielded[key].size() > 6 else ""))]
		if not problems.is_empty():
			K.fail("unit-def", key, "; ".join(problems) + " | " + detail)
		elif not notes.is_empty():
			K.warn("unit-def", key, "; ".join(notes) + " | " + detail)
		else:
			K.ok("unit-def", key, detail)

	# ---- spawn, combat, friendly fire (each as a nation that fields it)
	var slot := 0
	for key in keys:
		slot += 1
		var def: Dictionary = w.unit_defs[key]
		play_as(fielded[key][0] if not fielded[key].is_empty() else "usa")
		var base: Vector3 = land(Vector3(-160 + (slot % 6) * 55, 0, -120 + (slot / 6) * 25))
		K.take_errors()
		var u: Dictionary = w.spawn_unit(key, sea if def.get("naval", false) else base, 0)
		if u.is_empty():
			K.fail("unit-spawn", key, "spawn_unit returned nothing")
			continue
		var ground: float = w.height_at(u.node.position.x, u.node.position.z)
		var in_element: bool = u.node.position.y >= ground - 0.5
		var element := "on land"
		if def.get("fly", false):
			element = "in the air"
			in_element = u.node.position.y > ground + 5.0
		elif def.get("naval", false):
			element = "at sea"
			in_element = w.is_water(u.node.position, -0.5)
		if not (u.node.get_child_count() > 0 and u.hp > 0.0 and in_element):
			K.fail("unit-spawn", key, "model %d, hp %d, %s: %s" % [u.node.get_child_count(), int(u.hp), element, "not in its element" if not in_element else "no model/hp"])
		else:
			K.ok("unit-spawn", key, element)
		K.clean("unit-spawn", key)
		if float(def.get("dmg", 0)) <= 1.0 and not key in ["df17", "shahedLauncher", "brahmos"]:
			if u.dmg > 0.0:
				K.fail("unit-combat", key, "has no weapon in its definition but fights (dmg %.1f)" % u.dmg)
			else:
				K.ok("unit-combat", key, "unarmed")
			w.kill(u)
			continue
		var profile: Dictionary = w.damage_profile.get(key, {})
		if profile.is_empty():
			K.fail("unit-combat", key, "armed but has no damage profile")
			w.kill(u)
			continue
		var best: String = str(profile.keys()[0])
		for cls in profile:
			if float(profile[cls]) > float(profile[best]): best = cls
		if float(profile[best]) <= 0.0:
			K.fail("unit-combat", key, "armed but hurts nothing (profile %s)" % str(profile))
			w.kill(u)
			continue
		var spot: Vector3 = u.node.position + Vector3(minf(u.range * 0.5, 20.0), 0, 0)
		if not def.get("naval", false) or best != "naval": spot = w.land_point(spot, 60.0)
		var enemy: Dictionary = target_of(best, spot if best != "naval" or def.get("naval", false) else sea + Vector3(14, 0, 0), sea + Vector3(14, 0, 0))
		if def.get("fly", false):
			u.node.position = enemy.node.position + Vector3(-4, 18, 0)
			u.air_state = "ready"
		var friend: Dictionary = w.spawn_unit("soldier", w.land_point(enemy.node.position + Vector3(0, 0, 18), 8.0), 0) if not enemy.get("naval", false) else {}
		var hp0: float = enemy.hp
		var weapon: String = str(w.WEAPONS.get(key, preload("res://scripts/war_tools.gd").WEAPON.get(key, "")))
		K.take_errors()
		var hurt := false
		if weapon == "swarm":
			var n: int = Arsenal.launch_swarm(w, u, enemy)
			hurt = n > 0
		else:
			for shot in range(10):
				if enemy.dead or enemy.hp < hp0:
					break
				if u.dead:
					break
				if weapon != "":
					w.fire_weapon(u, enemy, weapon)
				else:
					w._fire_gun(u, enemy)
				settle(3.0 if weapon in ["hgv", "brahmos"] else 1.5)
			hurt = enemy.dead or enemy.hp < hp0
		if not hurt and (weapon in ["kamikaze", "detonate", "fpv"] or key in ["suicideSquad", "harop", "loiterer"]):
			hurt = u.dead   # one-use weapons are spent
		var tag := "%s (weapon %s, %s)" % [best, weapon if weapon != "" else "gun", "%d -> %d" % [int(hp0), int(enemy.hp)] if weapon != "swarm" else "swarm"]
		if hurt:
			K.ok("unit-combat", key, "hurts a " + tag)
		else:
			K.fail("unit-combat", key, "does not hurt the %s it is made for: %s" % [best, tag])
		if not friend.is_empty() and not weapon in ["hgv", "brahmos"]:
			if friend.dead or friend.hp < friend.max_hp:
				K.fail("unit-friendly-fire", key, "hurt its own side")
			w.kill(friend)
		K.clean("unit-combat", key)
		if not enemy.dead and not enemy.get("is_building", false): w.kill(enemy)
		if enemy.get("is_building", false) and not enemy.dead: w.destroy_building(enemy)
		if not u.dead: w.kill(u)
	for u in w.units.filter(func(x): return x.key == "shahed" and not x.dead): w.kill(u)

	# ---- orders: every mobile unit goes where it is sent
	play_as("usa")
	var mobile := keys.filter(func(k): return float(w.unit_defs[k].get("speed", 0)) > 0.0 and not k in ["shahed", "wingman", "interceptorDrone"])
	var batch_size := 12
	var index := 0
	while index < mobile.size():
		var batch: Array = mobile.slice(index, index + batch_size)
		index += batch_size
		var movers := []
		var i := 0
		for key in batch:
			var def: Dictionary = w.unit_defs[key]
			var start: Vector3
			var goal: Vector3
			if def.get("naval", false):
				start = sea + Vector3(i * 14.0, 0, 0)
				goal = start + Vector3(0, 0, 40)
				if not w.is_water(goal, -0.5): goal = start + Vector3(0, 0, -40)
			else:
				start = land(Vector3(-30 + i * 9, 0, 20 + (index / batch_size) * 4))
				goal = w.land_point(start + Vector3(30, 0, 18), 10.0)
			var u: Dictionary = w.spawn_unit(key, start, 0)
			if u.is_empty(): continue
			if def.get("fly", false): u.air_state = "ready"
			w.order_move([u], goal)
			movers.append([u, goal, u.node.position, key])
			i += 1
		K.take_errors()
		for step in range(int(25.0 / DT)):
			w._physics_process(DT)
		for m in movers:
			var moved: float = Vector2(m[0].node.position.x - m[2].x, m[0].node.position.z - m[2].z).length()
			var key: String = m[3]
			if m[0].dead:
				K.fail("unit-move", key, "died on its way (alone, at peace)")
			elif moved < 6.0:
				K.fail("unit-move", key, "ordered to move %d m, moved %d m in 25 s" % [int(Vector2(m[1].x - m[2].x, m[1].z - m[2].z).length()), int(moved)])
			else:
				K.ok("unit-move", key, "%d m in 25 s (speed %.1f)" % [int(moved), float(w.unit_defs[key].speed)])
		K.clean("unit-move", "batch %d" % (index / batch_size))
		for m in movers:
			if not m[0].dead: w.kill(m[0])
	quit(K.finish())
