extends SceneTree
## Audit of the player's order "attack that" for every armed unit (native/ALPHA-1.0-REPORT.md), through the real order
## pipeline (world.order_attack, then the simulation): each unit is given an enemy of the class it is made for.
##   A. inside its weapon's reach: within 25 game seconds the enemy is hurt (or the unit is spent, for one-use weapons).
##   B. well outside its reach (two and a half times): the unit does something about it: it hurts the enemy, or
##      closes the distance, or (a carrier, a launcher, an aircraft on a sortie) its wing or salvo goes up; a unit that
##      does nothing at all is a finding.
## Table: res://build/audit/orders.txt
const Kit := preload("res://tools/audit_kit.gd")
const Cheats := preload("res://scripts/cheats.gd")
const DT := 1.0 / 30.0
var K
var w: Node
func _initialize() -> void: call_deferred("run")

func play_as(id: String) -> void:
	w.map.nations[0]["id"] = id

func target_for(cls: String, at: Vector3, sea: Vector3) -> Dictionary:
	match cls:
		"infantry": return w.spawn_unit("soldier", at, 1)
		"light": return w.spawn_unit("apc", at, 1)
		"armor": return w.spawn_unit("tank", at, 1)
		"naval": return w.spawn_unit("destroyer", sea, 1)
		"air":
			var hover: Dictionary = w.spawn_unit("helicopter", at, 1)   # (a helicopter hangs in the air: a jet would fly out of a short-range gun's reach)
			hover.air_state = "ready"
			return hover
	return w.place_building("barracks", at, 1, true)

## A dry point exactly `d` metres from `from` (the first of eight directions that is land), or INF.
func dry_at(from: Vector3, d: float) -> Vector3:
	for k in range(8):
		var a := TAU * float(k) / 8.0
		var p := from + Vector3(cos(a), 0, sin(a)) * d
		if w.height_at(p.x, p.z) > float(w.map.seaLevel) + 0.6:
			p.y = w.height_at(p.x, p.z)
			return p
	return Vector3.INF

func step(seconds: float) -> void:
	for i in range(int(seconds / DT)):
		w._physics_process(DT)
		w.effects._physics_process(DT)    # (shells and missiles fly in these: they are stepped by hand here)
		w.missiles._physics_process(DT)

func gap(a: Dictionary, b: Dictionary) -> float:
	var pa: Vector3 = a.node.position
	var pb: Vector3 = b.root.position if b.get("is_building", false) else b.node.position
	return Vector2(pa.x - pb.x, pa.z - pb.z).length()

func run() -> void:
	K = Kit.new(self, "orders")
	w = await K.boot({"map": "island", "players": 3, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	Cheats.everything(w)
	w.economy.grant_test_resources()
	for n in w.ai.nations: n.money = 10000000.0
	w.diplomacy.declare_war(0, 1)
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var sea: Vector3 = w.water_near(home, 240)
	var keys: Array = w.unit_defs.keys()
	keys.sort()
	var tested := 0
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.split("=")[1]
	for key in keys:
		if only != "" and not key in only.split(","): continue
		var def: Dictionary = w.unit_defs[key]
		if float(def.get("dmg", 0)) <= 1.0 or key in ["carrierJet", "carrierDrone", "shahed", "wingman", "interceptorDrone"]:
			continue
		var ident := "usa"
		for id in preload("res://scripts/factions.gd").IDS:
			play_as(id)
			if w.unit_allowed(0, key):
				ident = id
				break
		play_as(ident)
		K.take_errors()
		var naval: bool = def.get("naval", false)
		var fly: bool = def.get("fly", false)
		var base: Vector3 = w.land_point(home + Vector3(-200, 0, -160 + (tested % 6) * 6), 40.0)
		var profile: Dictionary = w.damage_profile.get(key, {})
		if profile.is_empty():
			continue
		var best: String = str(profile.keys()[0])
		for cls in profile:
			if float(profile[cls]) > float(profile[best]): best = cls
		var reach: float = float(def.get("range", 20))
		if key == "carrier": reach = preload("res://scripts/war_tools.gd").STRIKE_REACH
		tested += 1
		# ---------------- A: inside reach
		var u: Dictionary = w.spawn_unit(key, sea if naval else base, 0)
		if u.is_empty():
			K.fail("order-reach", key, "could not be spawned")
			continue
		if fly: u.air_state = "ready"
		var spot: Vector3 = u.node.position + Vector3(minf(reach * 0.6, 60.0), 0, 0)
		if not naval or best != "naval":
			var dry := dry_at(u.node.position, minf(reach * 0.6, 60.0)) if not naval else Vector3.INF
			spot = dry if dry != Vector3.INF else w.land_point(spot, 60.0)
		var foe_sea: Vector3 = sea + Vector3(minf(reach * 0.6, 60.0), 0, 0)
		var enemy: Dictionary = target_for(best, spot, foe_sea if (naval or best == "naval") else sea)
		if enemy.is_empty():
			K.warn("order-reach", key, "no enemy of class %s could be made" % best)
			w.kill(u)
			continue
		if fly:
			u.node.position = Vector3(enemy.node.position.x - 6.0 if not enemy.get("is_building", false) else enemy.root.position.x - 6.0, 22.0, enemy.node.position.z if not enemy.get("is_building", false) else enemy.root.position.z)
		var hp0: float = enemy.hp
		var gap0: float = gap(u, enemy)
		w.order_attack([u], enemy)
		step(25.0 if not key in ["carrier"] else 14.0)
		var hurt: bool = enemy.dead or enemy.hp < hp0 - 0.5 or (key == "carrier" and w.units.any(func(x): return not x.dead and is_same(x.get("carrier"), u)))
		var spent: bool = u.dead and (key in ["suicideSquad", "harop", "loiterer", "seaDrone", "shahed", "coastalDrone", "fpvTeam", "shaheenDrone"] or def.get("desc", "").contains("One use") or def.get("desc", "").contains("one use"))
		if hurt or spent:
			K.ok("order-reach", key, "%s within reach (%s): %d -> %d" % [best, "wing launched" if key == "carrier" else "hit", int(hp0), int(enemy.hp)])
		elif gap0 > reach * 1.1 and not fly:
			K.warn("order-reach", key, "the fixture put the %s %d m away, beyond its reach (%d m): not a finding" % [best, int(gap0), int(reach)])
		else:
			K.fail("order-reach", key, "ordered at a %s inside its reach and after 25 s did nothing (enemy %d of %d, unit hp %d, state %s)" % [best, int(enemy.hp), int(hp0), int(u.hp), str(u.get("air_state", "-"))])
		K.clean("order-reach", key)
		for x in w.units.filter(func(x): return not x.dead and (is_same(x, u) or is_same(x, enemy) or is_same(x.get("carrier"), u))): w.kill(x)
		if enemy.get("is_building", false) and not enemy.dead: w.destroy_building(enemy)
		# ---------------- B: far outside reach
		if fly or key in ["suicideSquad", "seaDrone", "harop", "loiterer"]:
			continue   # (aircraft and one-use weapons: their sorties are tested by the airfield, wing and war suites)
		var u2: Dictionary = w.spawn_unit(key, sea if naval else base, 0)
		var far_dist: float = clampf(reach * 2.5, 45.0, 200.0)
		var spot2: Vector3 = w.land_point(u2.node.position + Vector3(far_dist, 0, 0), 60.0)
		if naval: spot2 = sea + Vector3(far_dist, 0, 0)
		var enemy2: Dictionary = target_for(best, spot2, sea + Vector3(far_dist, 0, 0))
		if enemy2.is_empty():
			w.kill(u2)
			continue
		var g0: float = gap(u2, enemy2)
		var hp2: float = enemy2.hp
		w.order_attack([u2], enemy2)
		step(14.0)
		var closed: float = g0 - gap(u2, enemy2)
		if enemy2.hp < hp2 - 0.5 or enemy2.dead:
			K.ok("order-far", key, "hit it from %d m" % int(g0))
		elif closed > g0 * 0.12:
			K.ok("order-far", key, "closed %d of %d m" % [int(closed), int(g0)])
		elif key in ["carrier"]:
			K.ok("order-far", key, "stands off by design")
		elif best in ["air", "naval"] and not naval and not fly:
			K.ok("order-far", key, "a land weapon against a %s does not chase it, by design (it cannot follow into the air or onto the sea)" % best)
		else:
			K.warn("order-far", key, "ordered at a %s %d m away (reach %d m) it neither hit it nor closed in (closed %.0f m): it %s" % [best, int(g0), int(reach), closed, "stands still" if not u2.moving else "moves without closing"])
		K.clean("order-far", key)
		for x in w.units.filter(func(x): return not x.dead and (is_same(x, u2) or is_same(x, enemy2))): w.kill(x)
		if enemy2.get("is_building", false) and not enemy2.dead: w.destroy_building(enemy2)
	K.ok("orders", "summary", "%d armed units tried" % tested)
	quit(K.finish())
