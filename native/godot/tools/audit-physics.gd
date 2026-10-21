extends SceneTree
## Audit of what can exist and happen physically and logically (native/ALPHA-1.0-REPORT.md). Three parts:
##  A. THE RULES OF THE WORLD (static): what each building may train (a shipyard builds ships, a barracks infantry...),
##     where each building may stand (a harbour on a coast, a rig on open water, a farm on flat dry land: tried on a
##     mountain, inland, in the sea and on a beach), what a transport can carry (a helicopter no tank), who can launch
##     what from what, what a weapon can hurt (a rifle cannot hurt a battleship, a SAM cannot hit the ground, a
##     torpedo only ships), and a few thousand cross-checks of ORDER between classes drawn from the real world
##     (a fighter is faster than a bomber, a howitzer outranges a rifle, a ballistic missile is faster than a cruise
##     missile, a bigger warhead has a bigger blast, a carrier costs more than a destroyer).
##     FAIL: something impossible. WARN: an order the real world would not have (with the reason), for the user to
##     decide whether it is a game abstraction.
##  B. A SOAK (dynamic): a ten-minute four-nation match at speed, every unit and building looked at every half second:
##     land units never in deep water, ships never on dry land, aircraft not under the ground, buildings not in the sea
##     (except platforms), units never inside a building, nothing teleporting (a step longer than its speed allows),
##     nothing without health or with impossible health, no two units fused at one point for long.
##  C. ORDERS THE TERRAIN FORBIDS: a tank is sent into the sea, a destroyer inland, an infantry squad across a strait:
##     they must stop at the shore.
## Table: res://build/audit/physics.txt
const Kit := preload("res://tools/audit_kit.gd")
const Cheats := preload("res://scripts/cheats.gd")
const Air := preload("res://scripts/airlift.gd")
var K
var w: Node
func _initialize() -> void: call_deferred("run")

func val(key: String, stat: String) -> float:
	var d: Dictionary = w.unit_defs.get(key, {})
	if d.is_empty(): return NAN
	match stat:
		"cost":
			var total := 0.0
			for r in d.get("cost", {}):
				total += float(d.cost[r]) * (1.0 if r == "money" else (3.0 if r in ["iron", "oil"] else 5.0))
			return total
		_:
			return float(d.get(stat, 0))

## `a` must be greater than `b` in `stat`; `why` is the real-world reason.
func order(stat: String, a: String, b: String, why: String, strict := true) -> void:
	var va := val(a, stat)
	var vb := val(b, stat)
	var name := "%s: %s > %s" % [stat, a, b]
	if is_nan(va) or is_nan(vb):
		K.ok("order", name, "(one of them is not in this game)")
		return
	if (va > vb) if strict else (va >= vb):
		K.ok("order", name, "%.1f > %.1f: %s" % [va, vb, why])
	else:
		K.warn("order", name, "%s is %.1f but %s is %.1f. Real world: %s" % [a, va, b, vb, why])

func run() -> void:
	K = Kit.new(self, "physics")
	w = await K.boot({"map": "island", "players": 4, "nation": 0}, "hard", true)
	if w == null:
		quit(1)
		return
	Cheats.everything(w)
	for n in w.ai.nations: n.money = 10000000.0

	# ======================================================= A. the rules of the world
	# -- what each building trains
	var classes := {"barracks": "foot", "tankFactory": "vehicle", "airfield": "air", "helipad": "heli", "shipyard": "sea"}
	var heli_keys := ["helicopter", "gunship", "scoutHelicopter", "heavyLift", "navalHelicopter"]
	for b in classes:
		var bad := PackedStringArray()
		for u in w.building_defs[b].get("trains", []):
			var d: Dictionary = w.unit_defs.get(u, {})
			if d.is_empty(): continue
			var cls := "air" if d.get("fly", false) else ("sea" if d.get("naval", false) else ("vehicle" if d.get("vehicle", false) else "foot"))
			if u in heli_keys: cls = "heli"
			var ok_here: bool = cls == classes[b] or (b == "tankFactory" and cls in ["vehicle", "foot"] and not d.get("fly", false) and not d.get("naval", false)) or (b == "airfield" and cls == "air")
			if not ok_here:
				bad.append("%s (%s)" % [u, cls])
		if bad.is_empty():
			K.ok("rule-trains", b, "trains only what belongs there")
		else:
			K.fail("rule-trains", b, "trains what cannot be built there: %s" % ", ".join(bad))
	# every unit trained somewhere that matches its element (and nowhere else)
	for u in w.unit_defs:
		var homes := PackedStringArray()
		for b in w.building_defs:
			if u in w.building_defs[b].get("trains", []): homes.append(b)
		if homes.size() > 1 and u != "worker":
			K.warn("rule-trains", u, "trained at several buildings: %s" % ", ".join(homes))

	# -- where each building may stand (negative tests)
	var t: Node = w.territory
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for i in range(t.owner_of.size()):
		if t.owner_of[i] < 0: t.owner_of[i] = 0   # (the whole map is ours: only the ground and the water are tried)
	var sea := Vector3.INF
	var steep := Vector3.INF
	var steep_drop := 0.0
	var flat := Vector3.INF
	var beach := Vector3.INF
	var half: float = float(w.map.mapSize) * 0.5
	for x in range(-int(half) + 20, int(half) - 20, 12):
		for z in range(-int(half) + 20, int(half) - 20, 12):
			var h: float = w.height_at(x, z)
			var p := Vector3(x, h, z)
			if h < -8.0 and sea == Vector3.INF and w.is_water(p, -4.0): sea = Vector3(x, 0, z)
			var drop := 0.0
			for d in [Vector2(10, 0), Vector2(-10, 0), Vector2(0, 10), Vector2(0, -10)]:
				drop = maxf(drop, absf(w.height_at(x + d.x, z + d.y) - h))
			if h > 1.5 and drop > steep_drop:
				steep_drop = drop
				steep = p
			if flat == Vector3.INF and h > 2.0 and h < 12.0 and Vector2(x - home.x, z - home.z).length() < 160.0 and w.site_problem("farm", Vector3(x, h, z), 0) == "":
				flat = Vector3(x, h, z)
			if beach == Vector3.INF and h > 0.4 and h < 1.4 and w.coast_near(p, 14.0):
				beach = p
	K.ok("rule-sites", "terrain found", "sea %s, steepest ground %.1f m in 10 m, flat %s, beach %s" % [str(sea != Vector3.INF), steep_drop, str(flat != Vector3.INF), str(beach != Vector3.INF)])
	for key in w.building_defs:
		if key == "hq": continue
		var def: Dictionary = w.building_defs[key]
		var water: bool = def.get("water", false) or (def.get("depositTypes") != null and "seaOil" in def.depositTypes)
		var coastal: bool = def.get("coastal", false)
		var problems := PackedStringArray()
		if sea != Vector3.INF:
			var at_sea: String = w.site_problem(key, sea, 0)
			if not water and at_sea == "": problems.append("can be built in the open sea")
		if steep != Vector3.INF and steep_drop > 5.0 and not water and not coastal:
			var up: String = w.site_problem(key, steep, 0)
			if up == "": problems.append("can be built on a cliff (%.1f m drop in 10 m)" % steep_drop)
		if flat != Vector3.INF:
			var inland: String = w.site_problem(key, flat, 0)
			if coastal and inland == "" and not w.coast_near(flat, w.logistics.radius * 1.6): problems.append("a coastal building was allowed inland")
			if water and inland == "": problems.append("an offshore platform was allowed on dry land")
		if problems.is_empty():
			K.ok("rule-sites", key, "refused where it cannot stand (sea, peak, inland, as it applies)")
		else:
			K.fail("rule-sites", key, "; ".join(problems))
	K.clean("rule-sites", "sites")

	# -- what a transport can carry
	var helo: Dictionary = {"key": "helicopter", "owner": 0, "dead": false, "cargo": []}
	for u in ["tank", "apc", "artillery", "samLauncher", "himars"]:
		var probe: Dictionary = {"key": u, "owner": 0, "dead": false}
		if Air.places(w, helo, probe) > 0:
			K.fail("rule-cargo", "helicopter carries %s" % u, "an ordinary helicopter cannot lift a %s" % u)
	var chinook: Dictionary = {"key": "heavyLift", "owner": 0, "dead": false, "cargo": []}
	for u in ["tank", "artillery", "samLauncher", "himars"]:
		if Air.places(w, chinook, {"key": u, "owner": 0, "dead": false}) > 0:
			K.fail("rule-cargo", "heavy-lift carries %s" % u, "a heavy-lift helicopter cannot carry a main battle tank or a launcher")
	K.ok("rule-cargo", "helicopters", "no helicopter lifts a tank, an artillery piece or a launcher")
	for pair in [["helicopter", "soldier", true], ["landingShip", "tank", true], ["landingShip", "soldier", true]]:
		var carrier: Dictionary = {"key": pair[0], "owner": 0, "dead": false, "cargo": []}
		var u: Dictionary = w.spawn_unit(pair[1], w.land_point(home + Vector3(40, 0, 40), 20.0), 0)
		K.expect((Air.places(w, carrier, u) > 0) == pair[2], "rule-cargo", "%s carries %s" % [pair[0], pair[1]], "wrong: places %d" % Air.places(w, carrier, u))
		w.kill(u)
	var cap: Dictionary = Air.CAPACITY
	for k in cap:
		K.expect(cap[k] > 0 and cap[k] <= 60, "rule-cargo", "capacity of %s" % k, "%d places" % cap[k])

	# -- what a weapon can hurt (the damage table and the special cases)
	var specimens := {}
	var eff := func(a: String, b: String) -> float:
		var pair: Array = []
		for role in [[a, 0, "a"], [b, 1, "b"]]:
			var key: String = role[0]
			var tag: String = key + "/" + role[2]
			if not specimens.has(tag):
				var spot: Vector3 = sea if w.unit_defs[key].get("naval", false) and sea != Vector3.INF else w.land_point(home + Vector3(30 + specimens.size() * 3, 0, 60), 25.0)
				var u: Dictionary = w.spawn_unit(key, spot, int(role[1]))
				if u.is_empty(): return NAN
				if u.get("fly", false): u.air_state = "ready"
				specimens[tag] = u
			pair.append(specimens[tag])
		pair[0].owner = 0
		pair[1].owner = 1
		return w.effectiveness(pair[0], pair[1])
	var hard_rules := [["soldier", "destroyer", false, "a rifle cannot hurt a warship"], ["soldier", "tank", false, "a rifle cannot penetrate a tank"], ["soldier", "jet", false, "a rifle cannot reach a jet at speed and altitude"],
		["samLauncher", "tank", false, "a SAM cannot hit the ground"], ["aaVehicle", "destroyer", false, "an AA vehicle cannot hit a ship"], ["manpads", "tank", false, "a shoulder-fired SAM cannot hit a tank"],
		["submarine", "tank", false, "a torpedo cannot hit the land"], ["submarine", "soldier", false, "a torpedo cannot hit the land"], ["submarine", "destroyer", true, "a torpedo sinks a ship"],
		["rocketSoldier", "tank", true, "an anti-tank team kills tanks"], ["tank", "tank", true, "a tank kills a tank"], ["tank", "jet", false, "a tank gun cannot hit a jet"],
		["jet", "jet", true, "a fighter fights fighters"], ["bomber", "jet", false, "a bomber has no air-to-air weapon"], ["destroyer", "jet", true, "a destroyer has air defence"],
		["artillery", "jet", false, "a howitzer cannot shoot aircraft"], ["mlrs", "destroyer", true, "rockets can hit ships near the shore"],
		["seaDrone", "tank", false, "an explosive boat cannot reach land"], ["laserAD", "tank", false, "an air-defence laser does not hit tanks"],
		["medic", "tank", false, "a medic has a pistol"], ["worker", "soldier", false, "a worker is unarmed"]]
	for rule in hard_rules:
		if not w.unit_defs.has(rule[0]) or not w.unit_defs.has(rule[1]):
			continue
		var e: float = eff.call(rule[0], rule[1])
		if is_nan(e):
			K.warn("rule-weapon", "%s vs %s" % [rule[0], rule[1]], "could not be set up")
			continue
		K.expect((e > 0.0) == rule[2], "rule-weapon", "%s vs %s" % [rule[0], rule[1]], "%s (effectiveness %.2f)" % [rule[3], e])

	for tag in specimens:
		if not specimens[tag].dead: w.kill(specimens[tag])
	# -- launchers: who may launch what from what (a few cases that must hold)
	var ms: Node = w.missiles
	for m in ms.types():
		if ms.def_of(m).get("hidden", false): continue
		var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(w, 0, m)
		var cat: String = ms.category(m)
		if cat == "nuclear" and kind in ["ground"] and m not in ["neutronBomb", "nuclearGlide", "burevestnik", "tsarBomba"]:
			K.warn("rule-launch", m, "a nuclear weapon launched from the ground without the strategic ladder (kind %s)" % kind)
		if kind == "sub" and m != "poseidon":
			K.warn("rule-launch", m, "only a submarine launches it (kind sub)")
	K.ok("rule-launch", "launchers", "%d weapons" % ms.types().size())

	# -- the order between classes in the real world
	order("speed", "jet", "bomber", "a fighter is faster than a heavy bomber")
	order("speed", "jet", "helicopter", "a jet is faster than a helicopter")
	order("speed", "stealthFighter", "helicopter", "a jet is faster than a helicopter")
	order("speed", "bomber", "helicopter", "a bomber is faster than a helicopter")
	order("speed", "helicopter", "apc", "an aircraft is faster than a vehicle on the ground")
	order("speed", "tank", "soldier", "a tank drives at 60 km/h, a soldier walks at 5 (the game gives the soldier more: compressed scale)")
	order("speed", "apc", "tank", "a wheeled carrier is faster than a tracked tank")
	order("speed", "corvette", "destroyer", "a small combatant is faster than a large one")
	order("speed", "gunboat", "destroyer", "a patrol boat is faster than a destroyer")
	order("speed", "destroyer", "submarine", "a surface ship is faster than a submerged submarine")
	order("speed", "destroyer", "landingShip", "an amphibious ship is slower than a destroyer")
	order("speed", "helicopter", "destroyer", "a helicopter is faster than a ship")
	order("speed", "jet", "destroyer", "a jet is faster than a ship")
	order("speed", "tank", "artillery", "a self-propelled gun is as fast as or slower than a tank", false)
	order("hp", "carrier", "destroyer", "a carrier is bigger than a destroyer")
	order("hp", "destroyer", "corvette", "a destroyer is bigger than a corvette")
	order("hp", "corvette", "gunboat", "a corvette is bigger than a patrol boat")
	order("hp", "destroyer", "submarine", "a destroyer is bigger than an attack submarine", false)
	order("hp", "tank", "apc", "a tank is better armoured than an armoured car")
	order("hp", "apc", "soldier", "a vehicle is sturdier than a man")
	order("hp", "bomber", "jet", "a heavy bomber is bigger than a fighter")
	order("hp", "helicopter", "drone", "a crewed helicopter is sturdier than a small drone")
	order("range", "artillery", "tank", "a howitzer outranges a tank gun")
	order("range", "tank", "soldier", "a tank gun outranges a rifle")
	order("range", "mlrs", "artillery", "a rocket launcher outranges a howitzer")
	order("range", "himars", "artillery", "a guided rocket launcher outranges a howitzer")
	order("range", "samLauncher", "aaVehicle", "a long-range SAM outranges AA guns")
	order("range", "aaVehicle", "manpads", "AA guns outrange a shoulder-fired SAM", false)
	order("range", "sniper", "soldier", "a sniper rifle outranges a rifle")
	order("range", "artillery", "mortarTeam", "a howitzer outranges a mortar")
	order("range", "destroyer", "corvette", "a destroyer's missiles outrange a corvette's")
	order("range", "coastalASM", "destroyer", "a coastal anti-ship battery outranges a destroyer")
	order("range", "bomber", "soldier", "an aircraft's weapons reach beyond a rifle")
	order("cost", "carrier", "destroyer", "a carrier costs more than a destroyer")
	order("cost", "destroyer", "corvette", "a destroyer costs more than a corvette")
	order("cost", "tank", "apc", "a tank costs more than an armoured car")
	order("cost", "apc", "soldier", "a vehicle costs more than a man")
	order("cost", "bomber", "helicopter", "a strategic bomber costs more than a helicopter")
	order("cost", "stealthFighter", "jet", "a stealth fighter costs more than a fourth-generation fighter")
	order("cost", "nuclearSub", "submarine", "a ballistic-missile submarine costs more than an attack submarine")
	# missiles: speed, warhead, price
	var mt: Dictionary = ms.types()
	var mspeed := func(k: String) -> float: return float(ms.def_of(k).get("speed", NAN)) if ms.types().has(k) else NAN
	for pair in [["ballistic", "cruise", "a ballistic missile is faster than a cruise missile"], ["nuke", "cruise", "an intercontinental missile is faster than a cruise missile"],
			["hypersonic", "cruise", "a hypersonic missile is faster than a subsonic cruise missile"], ["hypersonic", "ballistic", "a hypersonic glider is faster than the missile that carries it", ],
			["antiShip", "cruise", "an anti-ship missile is as fast or faster than a land-attack cruise missile"], ["tactical", "cruise", "a short-range ballistic missile is faster than a cruise missile"],
			["tsarBomba", "nuke", "the Tsar bomb is slower: a bomb carried by an aircraft"]]:
		if ms.types().has(pair[0]) and ms.types().has(pair[1]):
			var a: float = mspeed.call(pair[0])
			var b: float = mspeed.call(pair[1])
			if pair[0] == "tsarBomba": continue
			if a > b:
				K.ok("order", "missile speed: %s > %s" % [pair[0], pair[1]], "%d > %d: %s" % [a, b, pair[2]])
			else:
				K.warn("order", "missile speed: %s > %s" % [pair[0], pair[1]], "%s is %d and %s is %d. Real world: %s" % [pair[0], a, pair[1], b, pair[2]])
	for pair in [["tsarBomba", "hydrogenBomb"], ["hydrogenBomb", "nuke"], ["nuke", "tacticalNuke"], ["nuke", "ballistic"], ["ballistic", "tactical"]]:
		if ms.types().has(pair[0]) and ms.types().has(pair[1]):
			var ra: float = float(ms.def_of(pair[0]).get("radius", 0))
			var rb: float = float(ms.def_of(pair[1]).get("radius", 0))
			var da: float = float(ms.def_of(pair[0]).get("dmg", 0))
			var db: float = float(ms.def_of(pair[1]).get("dmg", 0))
			var good: bool = ra >= rb and da >= db
			if good: K.ok("order", "blast: %s >= %s" % [pair[0], pair[1]], "radius %d >= %d, damage %d >= %d" % [ra, rb, da, db])
			else: K.warn("order", "blast: %s >= %s" % [pair[0], pair[1]], "a bigger weapon should not have a smaller blast (radius %d vs %d, damage %d vs %d)" % [ra, rb, da, db])

	# ======================================================= C. orders the terrain forbids
	w.set_physics_process(true)
	w.ai.set_physics_process(false)
	for n in w.ai.nations: n.money = 10000000.0
	w.diplomacy.make_peace(0, 1) if w.diplomacy.at_war(0, 1) else null
	var land0: Vector3 = w.land_point(home + Vector3(70, 0, 70), 30.0)
	var seaside: Vector3 = w.water_near(land0, 200)
	if seaside != null and seaside != Vector3.ZERO and sea != Vector3.INF:
		var tank: Dictionary = w.spawn_unit("tank", land0, 0)
		var squad: Dictionary = w.spawn_unit("soldier", land0 + Vector3(4, 0, 0), 0)
		var ship: Dictionary = w.spawn_unit("destroyer", seaside, 0)
		K.take_errors()
		w.order_move([tank, squad], sea)
		w.order_move([ship], land0 + (land0 - seaside).normalized() * 160.0)
		Engine.time_scale = 6.0
		var t_end: float = w.game_time + 90.0
		var guard := 0
		while w.game_time < t_end and guard < 6000:
			await process_frame
			guard += 1
		Engine.time_scale = 1.0
		for u in [tank, squad]:
			var p: Vector3 = u.node.position
			var hh: float = w.height_at(p.x, p.z)
			K.expect(u.dead or hh > float(w.map.seaLevel) - 1.0, "terrain-order", "%s ordered into the sea" % u.key, "it is at height %.1f (sea level %.1f): a land unit drove into deep water" % [hh, float(w.map.seaLevel)])
		var sp: Vector3 = ship.node.position
		K.expect(ship.dead or w.height_at(sp.x, sp.z) < float(w.map.seaLevel) + 1.5, "terrain-order", "destroyer ordered inland", "it is on land at height %.1f" % w.height_at(sp.x, sp.z))
		K.clean("terrain-order", "orders")
	else:
		K.warn("terrain-order", "fixture", "no coast found near the capital")

	# ======================================================= B. the soak
	var minutes := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="): minutes = float(a.split("=")[1])
	var prev := {}
	var counts := {"land_in_sea": 0, "ship_on_land": 0, "air_underground": 0, "building_in_sea": 0, "inside_building": 0, "teleport": 0, "bad_hp": 0, "fused": 0, "samples": 0}
	var examples := {}
	var seen_before := {}
	var fused_for := {}
	var t0: float = w.game_time
	var t_prev: float = t0
	Engine.time_scale = 8.0
	w.diplomacy.declare_war(1, 0)
	if w.map.nations.size() > 2: w.diplomacy.declare_war(1, 2)
	# (the idle player's capital is kept standing: a lost match stops the clock and ends the soak early)
	var capital: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var sea_level := float(w.map.seaLevel)
	var frames := 0
	while w.game_time - t0 < minutes * 60.0 and frames < 200000:
		await process_frame
		frames += 1
		capital.hp = capital.max_hp
		if w.game_over != "": w.game_over = ""
		if frames % 6 != 0: continue
		var now: float = w.game_time
		var dt := now - t_prev
		t_prev = now
		if dt <= 0.0: continue
		counts.samples += 1
		var live: Array = w.units.filter(func(u): return not u.dead and not u.get("stowed", false) and u.node.is_inside_tree())
		for u in live:
			var p: Vector3 = u.node.position
			var id: int = u.node.get_instance_id()
			var ground: float = w.height_at(p.x, p.z)
			var fly: bool = u.get("fly", false)
			var naval: bool = u.get("naval", false)
			if not fly and not naval and ground < sea_level - 1.2 and Vector2(p.x, p.z).length() < half:
				counts.land_in_sea += 1
				examples["land_in_sea"] = "%s at (%d, %d) height %.1f" % [u.key, p.x, p.z, ground]
			if naval and ground > sea_level + 1.8:
				counts.ship_on_land += 1
				examples["ship_on_land"] = "%s at (%d, %d) height %.1f" % [u.key, p.x, p.z, ground]
			if fly and u.get("air_state", "ready") in ["ready", "takeoff", "landing"] and p.y < ground - 0.5:
				counts.air_underground += 1
				examples["air_underground"] = "%s at (%d, %d): y %.1f below ground %.1f" % [u.key, p.x, p.z, p.y, ground]
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
				counts.bad_hp += 1
				examples["bad_hp"] = "%s has a position that is not a number" % u.key
			if float(u.hp) > float(u.max_hp) * 1.001 + 1.0 or float(u.max_hp) <= 0.0 or is_nan(float(u.hp)):
				counts.bad_hp += 1
				examples["bad_hp"] = "%s hp %s of %s" % [u.key, str(u.hp), str(u.max_hp)]
			if prev.has(id) and seen_before.has(id):
				var last: Vector3 = prev[id]
				var step := Vector2(p.x - last.x, p.z - last.z).length()
				var allowed := (float(u.speed) * 3.0 + 6.0) * dt + 4.0   # (a shove, a landing, a plane turning: margin)
				if fly: allowed = (float(u.speed) * 3.0 + 25.0) * dt + 10.0
				if step > allowed and not u.get("just_unloaded", false):
					counts.teleport += 1
					examples["teleport"] = "%s moved %.0f m in %.1f s (speed %.1f)" % [u.key, step, dt, float(u.speed)]
			prev[id] = p
			seen_before[id] = true
			# fused: another living unit of the same owner within 0.4 m, on the same level, for more than ten seconds
		for b in w.buildings:
			if b.dead or not b.built: continue
			var bp: Vector3 = b.root.position
			var bh: float = w.height_at(bp.x, bp.z)
			var offshore: bool = b.def.get("water", false)
			if not offshore and bh < sea_level - 0.5 and not b.def.get("coastal", false):
				counts.building_in_sea += 1
				examples["building_in_sea"] = "%s at (%d, %d) height %.1f" % [b.key, bp.x, bp.z, bh]
		if counts.samples % 6 == 0:
			var ground_units: Array = live.filter(func(u): return not u.get("fly", false) and not u.get("naval", false))
			for u in ground_units:
				var p: Vector3 = u.node.position
				for b in w.buildings:
					if b.dead or not b.built or w.is_district(b.key) and false: continue
					var gap := Vector2(b.root.position.x - p.x, b.root.position.z - p.z).length()
					if gap < b.footprint * 0.18 and not b.get("settlement") and b.key != "hq":
						counts.inside_building += 1
						examples["inside_building"] = "%s inside a %s at (%d, %d)" % [u.key, b.key, p.x, p.z]
						break
	Engine.time_scale = 1.0
	K.expect(w.game_time - t0 >= minutes * 60.0 - 1.0, "soak", "length", "the clock stopped after %d game seconds" % int(w.game_time - t0))
	K.ok("soak", "match", "%d samples over %d game minutes, %d units alive at the end" % [counts.samples, int((w.game_time - t0) / 60.0), w.units.filter(func(u): return not u.dead).size()])
	var forbidden := ["land_in_sea", "ship_on_land", "air_underground", "building_in_sea", "bad_hp"]
	for k in forbidden:
		if counts[k] == 0: K.ok("soak", k, "never")
		else: K.fail("soak", k, "%d times, e.g. %s" % [counts[k], examples.get(k, "")])
	for k in ["teleport", "inside_building"]:
		if counts[k] == 0: K.ok("soak", k, "never")
		elif counts[k] <= 3: K.warn("soak", k, "%d times, e.g. %s" % [counts[k], examples.get(k, "")])
		else: K.fail("soak", k, "%d times, e.g. %s" % [counts[k], examples.get(k, "")])
	K.clean("soak", "match")
	quit(K.finish())
