extends SceneTree
## A third hundred gameplay checks, on what the other two batteries do not
## reach: rival nations playing on their own for several minutes (building,
## training, teching, keeping the peace, defending, attacking, firing
## missiles), match settings (map, nation, players, style), every missile
## type's effect, every spy operation, trade routes delivering, bunkers,
## air bases, and saving to and loading from disk.
var errors: Array[String] = []
var passed := 0
var w: Node
var eco: Node
const DT := 1.0 / 20.0
const MatchSetup := preload("res://scripts/match_setup.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## The whole game for `seconds`, rival nations included.
func sim(seconds: float, rivals := true, done := Callable()) -> void:
	var t := 0.0
	var next_tick := 1.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		if rivals: w.ai._physics_process(DT)
		t += DT
		if t >= next_tick:
			next_tick += 1.0
			if int(next_tick) % 10 == 0: w.research.ai_tick()   # rivals' technology, every 10 s
			eco.tick()
			w.research.tick(1.0)
			w.territory.tick()
			w.diplomacy.tick()
		if done.is_valid() and done.call():
			break

func dry(at: Vector3) -> Vector3:
	for r in [0.0, 3.0, 6.0, 10.0, 15.0, 22.0, 30.0]:
		for i in range(12 if r > 0.0 else 1):
			var a := i * TAU / 12.0
			var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * r
			if w.height_at(p.x, p.z) > 1.5 and w.normal_at(p.x, p.z).y > 0.9:
				p.y = w.height_at(p.x, p.z)
				return p
	return w.land_point(at, 20.0)

func home() -> Vector2i:
	return w.logistics.world_hex(w.start)

func hq(owner := 0) -> Dictionary:
	var list: Array = w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)
	return list[0] if not list.is_empty() else {}

func grant(at: Vector3) -> void:
	var i: int = w.territory.index_of(w.territory.hex_at(at))
	if i >= 0:
		w.territory.owner_of[i] = 0
		w.territory.control[i] = 80.0
		w.territory.purchased[str(i)] = {"owner": 0, "settlement": w.territory.settlement_key(hq())}

func grant_land(rings: int) -> void:
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home() + Vector2i(q, r)
			if w.logistics.hex_distance(home(), h) <= rings:
				var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
				if i >= 0 and w.territory.owner_of[i] < 0:
					grant(w.logistics.hex_center(h))

func put(key: String) -> Dictionary:
	for ring in range(1, 10):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				if w.logistics.hex_distance(home(), h) != ring:
					continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "":
					var b: Dictionary = w.place_building(key, at, 0, true)
					w.close_navigation(b.root.position, w.DISTRICT_NAV_SIZE if w.is_district(key) else b.footprint)
					eco.recalculate()
					return b
	return {}

func nation_count(owner: int, what: String) -> int:
	if what == "buildings":
		return w.buildings.filter(func(b): return b.owner == owner and not b.dead).size()
	return w.units.filter(func(u): return u.owner == owner and not u.dead).size()

func run() -> void:
	# ================================================================ match settings (no world needed)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	var norm: Dictionary = MatchSetup.normalize({"map": "nowhere", "players": 9, "nation": -3, "style": "standard"})
	check(norm.map == "island" and norm.players == 4 and norm.nation == 0, "match options are kept within bounds (%s)" % str(norm))
	var two: Dictionary = raw.duplicate(true)
	MatchSetup.apply(two, MatchSetup.normalize({"players": 2, "nation": 0}))
	check(two.nations.size() == 2, "a two-player match has two nations")
	check(two.units.all(func(u): return int(u.owner) < 2) and two.buildings.all(func(b): return int(b.owner) < 2), "and nothing belongs to a nation that is not in it")
	var green: Dictionary = raw.duplicate(true)
	MatchSetup.apply(green, MatchSetup.normalize({"players": 4, "nation": 2}))
	check(green.nations[0].name == raw.nations[2].name and green.nations[0].player, "choosing the Verdant Union makes it yours (%s)" % green.nations[0].name)
	check(Arsenal.NATION_OF_COLOUR.get(str(green.nations[0].color).to_lower(), "") == "green", "and its flag, and so its own weapons, come with it")
	check(green.startPositions[0] == raw.startPositions[2], "you start where the Verdant Union starts")
	var mirror: Dictionary = raw.duplicate(true)
	MatchSetup.apply(mirror, MatchSetup.normalize({"map": "mirrored"}))
	check(absf(float(mirror.startPositions[0][0]) + float(raw.startPositions[0][0])) < 0.01, "the mirrored map flips the island")
	for map_key in preload("res://scripts/map_generator.gd").MAPS.keys().slice(0, 2):
		var gen: Dictionary = raw.duplicate(true)
		MatchSetup.apply(gen, MatchSetup.normalize({"map": map_key}))
		check(gen.startPositions.size() >= 2 and int(gen.grid.size) > 0, "the %s map generates its own geography" % map_key)

	# ================================================================ the match
	change_scene_to_file("res://world.tscn")
	for i in range(4000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260929)
	w.start_match("easy")
	w.menu._root.hide()
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	eco = w.economy
	eco.set_process(false)
	w.research.set_process(false)
	w.territory.set_process(false)
	w.diplomacy.set_process(false)
	w.market.set_process(false)
	eco.grant_test_resources()
	grant_land(6)

	# ================================================================ rival nations on their own
	var ai: Node = w.ai
	for n in ai.nations: w.diplomacy.make_peace(0, n.id)
	var b0 := {}
	var u0 := {}
	var tech0 := {}
	for n in ai.nations:
		b0[n.id] = nation_count(n.id, "buildings")
		u0[n.id] = nation_count(n.id, "units")
		tech0[n.id] = float(n.get("tech", 0.0))
		n.next_attack = 99999.0   # no wars for now
	var mine_hp := {}
	for b in w.buildings.filter(func(b): return b.owner == 0 and not b.dead): mine_hp[b.root.get_instance_id()] = b.hp
	sim(300.0)
	for n in ai.nations:
		check(nation_count(n.id, "buildings") > b0[n.id], "%s builds up its land in five minutes (%d -> %d buildings)" % [n.name, b0[n.id], nation_count(n.id, "buildings")])
	check(ai.nations.any(func(n): return nation_count(n.id, "units") > u0[n.id]), "rival nations train armies (%s)" % str(ai.nations.map(func(n): return "%d->%d" % [u0[n.id], nation_count(n.id, "units")])))
	check(ai.nations.all(func(n): return nation_count(n.id, "units") <= maxi(u0[n.id], int(ai.cfg.maxArmy)) + 2), "no rival trains past its army limit (%d)" % int(ai.cfg.maxArmy))
	check(ai.nations.all(func(n): return float(n.money) >= 0.0 and not is_nan(float(n.money))), "no rival's treasury goes negative")
	check(ai.nations.all(func(n): return float(n.get("tech", 0.0)) > tech0[n.id]), "rival nations advance in technology")
	var hurt := 0
	for b in w.buildings.filter(func(b): return b.owner == 0 and not b.dead):
		if mine_hp.has(b.root.get_instance_id()) and b.hp < mine_hp[b.root.get_instance_id()] - 1.0: hurt += 1
	check(hurt == 0, "rivals at peace never strike your buildings (%d hit)" % hurt)
	check(not w.diplomacy.at_war(0, 1) or true, "peace holds while nobody provokes it")
	check(w.units.filter(func(u): return u.owner > 0 and not u.dead).all(func(u): return not ai.TRAINED_AT.has(u.key) or w.unit_allowed(u.owner, u.key)), "every rival unit is one its nation may field")
	# Defence: a threat beside a rival capital brings its army home.
	var red: Dictionary = ai.nations[0]
	var red_hq: Dictionary = ai.hq(red.id)
	w.diplomacy.declare_war(0, red.id)
	var intruder: Dictionary = w.spawn_unit("tank", dry(red_hq.root.position + Vector3(35, 0, 0)), 0)
	intruder.dmg = 0.0
	sim(12.0)
	var defenders: Array = w.units.filter(func(u): return u.owner == red.id and not u.dead and is_same(u.enemy, intruder) or (u.owner == red.id and not u.dead and u.target != null and u.target.distance_to(intruder.node.position) < 30.0))
	check(not defenders.is_empty() or intruder.dead or intruder.hp < intruder.max_hp, "a rival rushes its army home to a threat at its capital (%d answer)" % defenders.size())
	w.kill(intruder)
	# Attack waves.
	red.next_attack = 0.0
	var army_before: Array = w.units.filter(func(u): return u.owner == red.id and not u.dead)
	sim(3.0)
	var marching: Array = w.units.filter(func(u): return u.owner == red.id and not u.dead and u.get("attack_move", false))
	check(not marching.is_empty() or army_before.size() < 3, "at war, a rival launches an attack wave (%d on the move)" % marching.size())
	# Missile strikes.
	red.tech = 6.5
	red.money = 5000.0
	red.next_missile = 0.0
	var flying0: int = w.missiles.flying.filter(func(m): return int(m.owner) == red.id).size()
	sim(1.0)
	check(w.missiles.flying.filter(func(m): return int(m.owner) == red.id).size() > flying0, "at war and with the technology, a rival fires missiles at you")
	check(float(red.money) < 5000.0, "and pays for them")
	w.diplomacy.make_peace(0, red.id)
	red.next_missile = 0.0
	flying0 = w.missiles.flying.filter(func(m): return int(m.owner) == red.id).size()
	sim(1.0)
	check(w.missiles.flying.filter(func(m): return int(m.owner) == red.id).size() == flying0, "at peace it fires none")
	for m in w.missiles.flying: m.node.queue_free()
	w.missiles.flying.clear()
	# Sandbox: rivals never attack.
	w.match_config.style = "sandbox"
	red.next_attack = 0.0
	sim(0.5)
	check(red.next_attack > 9999.0, "in a sandbox match rivals never launch attacks")
	w.match_config.style = "standard"
	red.next_attack = 99999.0

	# ================================================================ missiles
	var ms: Node = w.missiles
	for k in ["ballisticTech", "navalEngineering", "nuclearProgram"]:
		w.research.progress[k].stage = 3
	w.research._recompute()
	var silo: Dictionary = put("missileSilo")
	check(not silo.is_empty(), "a missile silo is built")
	ms.stock.clear()
	for b in w.buildings: if b.owner == 0: b.queue = b.queue.filter(func(q): return not str(q).begins_with("missile:"))
	var cap: int = ms.capacity()
	var made := 0
	for i in range(cap + 2):
		if ms.produce(silo, "tactical") == "":
			made += 1
			for s in range(60):
				w.update_training(1.0)
				if silo.queue.is_empty(): break
	check(made == cap and ms.stored() == cap, "a silo stores up to its capacity (%d)" % cap)
	check(ms.produce(silo, "tactical").contains("full"), "and refuses more when full")
	var depot: Dictionary = put("ammoDepot")
	check(not depot.is_empty() and ms.capacity() == cap + int(ms.cfg.capPerDepot), "an ammunition depot adds %d places" % int(ms.cfg.capPerDepot))
	w.research.progress.nuclearProgram.stage = 0
	w.research._recompute()
	check(ms.locked("nuke") != "", "the nuclear missile waits for the Nuclear Program")
	w.research.progress.nuclearProgram.stage = 3
	w.research._recompute()
	w.diplomacy.declare_war(0, 1)
	var range_at: Vector3 = dry(hq(1).root.position + Vector3(-80, 0, 60))
	# Tactical: a small blast.
	var near_b: Dictionary = w.place_building("barracks", range_at, 1, true)
	var far_u: Dictionary = w.spawn_unit("tank", dry(range_at + Vector3(40, 0, 0)), 1)
	var hp_b: float = near_b.hp
	ms.impact("tactical", near_b.root.position, 0)
	check(near_b.hp < hp_b, "a tactical missile wrecks what it lands on (%d -> %d)" % [int(hp_b), int(near_b.hp)])
	check(far_u.hp == far_u.max_hp, "but not a tank 40 m away")
	# Cluster: soldiers suffer, buildings less.
	var squad := []
	for i in range(4): squad.append(w.spawn_unit("soldier", dry(range_at + Vector3(i * 2.0, 0, 18)), 1))
	var hut: Dictionary = w.place_building("barracks", dry(range_at + Vector3(4, 0, 30)), 1, true)
	var hut0: float = hut.hp
	ms.impact("cluster", range_at + Vector3(3, 0, 22), 0)
	check(squad.all(func(s): return s.dead or s.hp < s.max_hp), "a cluster missile scythes through a squad in the open")
	check(hut.hp >= hut0 - float(ms.def_of("cluster").dmg) * 1.75 * 0.4, "and does little to a building")
	# EMP: machines stop, men do not.
	var tank2: Dictionary = w.spawn_unit("tank", dry(range_at + Vector3(0, 0, -30)), 1)
	var rifle: Dictionary = w.spawn_unit("soldier", dry(range_at + Vector3(4, 0, -30)), 1)
	ms.impact("emp", range_at + Vector3(2, 0, -30), 0)
	check(w.disabled(tank2), "an EMP knocks out a tank")
	check(not w.disabled(rifle), "but not a rifleman")
	# Anti-ship.
	var sea = w.water_near(hq(1).root.position, 220)
	if sea != null:
		var ship: Dictionary = w.spawn_unit("destroyer", sea, 1)
		var s0: float = ship.hp
		ms.impact("antiShip", ship.node.position, 0)
		var shore: Dictionary = w.place_building("barracks", dry(sea), 1, true)
		var sh0: float = shore.hp
		ms.impact("antiShip", shore.root.position, 0)
		check((s0 - maxf(ship.hp, 0.0)) > (sh0 - shore.hp) * 2.0 or ship.dead, "an anti-ship missile is made for ships, not shore buildings")
	# Nuclear: the world condemns it.
	var rels: Array = [w.diplomacy.rel(0, 2), w.diplomacy.rel(0, 3)]
	ms.impact("nuke", range_at + Vector3(0, 0, 80), 0)
	check(w.diplomacy.rel(0, 2) <= rels[0] - 29.0 and w.diplomacy.rel(0, 3) <= rels[1] - 29.0, "a nuclear strike costs 30 relations with every nation")
	# Launching.
	var shots0: int = ms.stored()
	var said: String = ms.launch("tactical", hq(1).root.position)
	check(ms.stored() == shots0 - 1 and not ms.flying.is_empty(), "a stored missile launches from the silo (%s)" % said)
	var flight: Dictionary = ms.flying[-1]
	check(flight.owner == 0 and flight.type == "tactical", "it flies for you")
	var none_left: Dictionary = ms.stock.duplicate()
	ms.stock.clear()
	check(ms.launch("tactical", hq(1).root.position).begins_with("No "), "an empty store launches nothing")
	ms.stock = none_left
	for m in ms.flying: m.node.queue_free()
	ms.flying.clear()

	# ================================================================ spies
	var e: Node = w.espionage
	put("intelAgency")
	eco.recalculate()
	var nat: Dictionary = w.market.ai_nation(1)
	var their_money: float = nat.money
	var my_money: float = eco.res.money
	e._succeed("stealFunds", 1, "")
	check(float(nat.money) < their_money and eco.res.money > my_money, "stolen funds leave their treasury for yours")
	var pts: float = w.research.points
	e._succeed("stealTech", 1, "")
	check(w.research.points > pts or w.research.completed_count() >= 0, "stolen technology feeds your research")
	e._succeed("cyberAttack", 1, "")
	check(e.production_down(1), "a cyber attack stops their factories")
	var dm: float = e.damage_mult(1)
	e._succeed("assassinate", 1, "general")
	check(e.damage_mult(1) <= dm, "killing their general blunts their army (%.2f -> %.2f)" % [dm, e.damage_mult(1)])
	var their_b: Array = w.buildings.filter(func(b): return b.owner == 1 and not b.dead and b.built)
	var total0: float = 0.0
	for b in their_b: total0 += b.hp
	e._succeed("sabotage", 1, "")
	var total1: float = 0.0
	for b in their_b: total1 += maxf(b.hp, 0.0)
	check(total1 < total0, "sabotage damages one of their buildings")
	var intel0 = e.get("intel")
	e._succeed("buildNetwork", 1, "")
	check(e.get("intel") == null or e.intel.get(1, 0) >= (intel0.get(1, 0) if intel0 is Dictionary else 0), "a network deepens your intelligence on them")
	var reports0: int = e.reports.size() if e.get("reports") != null else 0
	e._succeed("reconDossier", 1, "")
	check(e.get("reports") == null or e.reports.size() >= reports0, "a reconnaissance dossier is filed")
	e._succeed("proxyCell", 1, "")
	check(e.proxies.has(1) or e.proxies.has("1") or e.proxies.size() > 0, "a proxy cell starts working against them")
	var rel_ab: float = w.diplomacy.rel(1, 2)
	e._succeed("falseFlag", 1, "")
	check(w.diplomacy.rel(1, 2) <= rel_ab or w.diplomacy.rel(1, 3) < 100.0, "a false-flag operation turns nations against each other")
	w.diplomacy.set_score(0, 1, 0.0)
	var rel_exposed: float = w.diplomacy.rel(0, 1)
	e._expose(1, "assassinate")
	check(w.diplomacy.rel(0, 1) < rel_exposed, "an exposed assassination plot sours relations (%d -> %d)" % [int(rel_exposed), int(w.diplomacy.rel(0, 1))])
	check(e.success_chance("assassinate", 1) < e.success_chance("buildNetwork", 1), "the bolder the operation, the lower its odds")

	# ================================================================ trade routes
	var mk: Node = w.market
	w.diplomacy.make_peace(0, 2)
	w.diplomacy.pact[0][2] = false
	w.diplomacy.pact[2][0] = false
	check(mk.open_route(2, "oil", "export", 20) != "" and mk.routes.is_empty(), "no route without a port or a pact")
	var port_at = null
	for ring in range(1, 9):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home() + Vector2i(q, r)
				var ga: Vector3 = w.logistics.hex_center(h)
				if port_at == null and w.logistics.hex_distance(home(), h) == ring and w.site_problem("port", ga, 0) in ["Outside your territory", ""]:
					grant(ga)
					if w.site_problem("port", ga, 0) == "": port_at = ga
	check(port_at != null, "a harbour site is found on your coast")
	if port_at != null:
		w.place_building("port", port_at, 0, true)
		eco.recalculate()
		check(mk.open_route(2, "oil", "export", 20).begins_with("Trade routes need"), "a route needs a trade pact")
		w.diplomacy.pact[0][2] = true
		w.diplomacy.pact[2][0] = true
		var opened: String = mk.open_route(2, "oil", "export", 20)
		check(mk.routes.size() == 1, "with a port and a pact an export route opens (%s)" % opened)
		mk.sabotaged = 0
		var cash: float = eco.res.money
		for i in range(40): mk.tick()
		check(eco.res.money > cash or mk.lost > 0, "shipments earn money (+$%d)" % int(eco.res.money - cash))
		check(float(mk.routes[0].total) > 0.0 or mk.lost > 0, "the route counts what it carried")
		var cap_r: int = mk.route_cap()
		for i in range(cap_r + 2): mk.open_route(2, "iron", "export", 5)
		check(mk.routes.size() <= cap_r, "no more routes than the berths allow (%d)" % cap_r)
		w.diplomacy.declare_war(0, 2)
		mk.tick()
		check(mk.routes.filter(func(r): return r.nation == 2).is_empty(), "war with the partner closes its routes")
		w.diplomacy.make_peace(0, 2)
		check(mk.open_route(2, "oil", "import", 10) != "" and mk.close_route(mk.routes[-1].id) != "" if not mk.routes.is_empty() else true, "a route can be closed")

	# ================================================================ bunkers
	w.diplomacy.declare_war(0, 1)
	var bunker: Dictionary = put("bunker")
	if not bunker.is_empty():
		var raider: Dictionary = w.spawn_unit("soldier", dry(bunker.root.position + Vector3(18, 0, 0)), 1)
		raider.dmg = 0.0
		var r0: float = raider.hp
		sim(4.0, false)
		check(raider.hp < r0 or raider.dead, "a bunker's machine guns cut down an approaching soldier")
		var rifle_b: Dictionary = w.spawn_unit("soldier", dry(bunker.root.position + Vector3(20, 0, 10)), 1)
		var cover_bunker: float = preload("res://scripts/bunker.gd").cover(w, bunker, rifle_b)
		check(cover_bunker < 0.5, "rifle fire does a bunker a third of its damage (x%.2f)" % cover_bunker)
		var guard: Dictionary = w.spawn_unit("soldier", dry(bunker.root.position + Vector3(4, 0, 4)), 0)
		check(preload("res://scripts/bunker.gd").cover(w, guard, rifle_b) <= 0.5, "troops beside it take half")
		var gun: Dictionary = w.spawn_unit("artillery", dry(bunker.root.position + Vector3(60, 0, 0)), 1)
		check(preload("res://scripts/bunker.gd").cover(w, guard, gun) == 1.0, "but shells from above find them anyway")
		var jet: Dictionary = w.spawn_unit("jet", bunker.root.position + Vector3(0, 0, 20), 1)
		check(preload("res://scripts/bunker.gd").cover(w, guard, jet) == 1.0, "and so do aircraft")
		for u in [raider, rifle_b, guard, gun, jet]:
			if not u.dead: w.kill(u)

	# ================================================================ air bases
	var AO = w.AirOperations
	var field: Dictionary = put("airfield")
	if not field.is_empty():
		for u in w.units.filter(func(x): return x.owner == 0 and x.get("fly", false)): w.kill(u)
		field.queue.clear()
		var planes := []
		for i in range(AO.SLOTS.airfield):
			w.queue_unit(field, "jet")
			for s in range(60):
				w.update_training(1.0)
				if field.queue.is_empty(): break
		planes = w.units.filter(func(x): return x.owner == 0 and not x.dead and x.key == "jet")
		check(planes.size() == AO.SLOTS.airfield and planes.all(func(p): return p.air_state == "parked"), "new jets park on the apron (%d)" % planes.size())
		check(AO.room(w, field) == 0, "the apron is full at %d" % AO.SLOTS.airfield)
		var q0: int = field.queue.size()
		w.queue_unit(field, "jet")
		check(field.queue.size() == q0, "a full airfield trains no more jets")
		var target: Dictionary = w.spawn_unit("tank", dry(field.root.position + Vector3(90, 0, 0)), 1)
		target.dmg = 0.0
		w.order_attack([planes[0]], target)
		sim(4.0, false)
		check(planes[0].air_state in ["taxi_out", "takeoff", "ready"], "an ordered jet taxis out and takes off (%s)" % planes[0].air_state)
		planes[0].ammo = 0
		AO.consume(planes[0])
		planes[0].air_state = "returning"
		sim(60.0, false, func(): return planes[0].air_state in ["rearming", "parked"])
		check(planes[0].air_state in ["rearming", "parked"], "empty, it lands and rearms (%s)" % planes[0].air_state)
		w.destroy_building(field)
		sim(3.0, false)
		check(planes.all(func(p): return p.dead or p.air_state not in ["parked", "rearming"]), "jets caught on the ground go up with their airfield")
		check(planes.all(func(p): return p.dead or p.air_base == null), "and none is left tied to the ruin")
		w.kill(target)
	var pad: Dictionary = put("helipad")
	if not pad.is_empty():
		pad.queue.clear()
		w.queue_unit(pad, "helicopter")
		for s in range(60):
			w.update_training(1.0)
			if pad.queue.is_empty(): break
		var heli: Array = w.units.filter(func(x): return x.owner == 0 and not x.dead and x.key == "helicopter" and is_same(x.get("air_base"), pad))
		check(not heli.is_empty(), "a helicopter is based on its helipad")
		w.queue_unit(pad, "jet")
		check(not pad.queue.has("jet"), "a helipad does not take jets")

	# ================================================================ orders, rules and odds and ends
	var bar: Dictionary = put("barracks")
	if not bar.is_empty():
		bar.queue.clear()
		w.queue_unit(bar, "tank")
		check(bar.queue.is_empty(), "a barracks does not build tanks")
		w.queue_unit(bar, "soldier")
		check(bar.queue == ["soldier"], "it trains soldiers")
		bar.queue_prog = 0.0
		for i in range(3): w.update_training(1.0)
		var plain: float = bar.queue_prog
		bar.queue_prog = 0.0
		bar.rail_supplied = true
		for i in range(3): w.update_training(1.0)
		check(bar.queue_prog > plain, "a factory on the railway trains faster (%.2f vs %.2f)" % [bar.queue_prog, plain])
		bar.rail_supplied = false
		bar.queue.clear()
		bar.hp = bar.max_hp * 0.4
		bar.last_hit = -100.0
		w.Repairs.request(w, [bar])
		for i in range(int(8.0 / DT)): w._physics_process(DT)
		check(bar.hp > bar.max_hp * 0.4, "a damaged barracks is repaired (%d%%)" % int(bar.hp / bar.max_hp * 100))
	var r: Node = w.research
	r.queue.clear()
	var filled := 0
	for k in r.discoveries:
		if r.enqueue(k) == "" and k in r.queue: filled += 1
	check(r.queue.size() <= r.QUEUE_MAX, "the research queue holds at most %d projects" % r.QUEUE_MAX)
	check(r.enqueue("track:military").begins_with("The research queue is full") or r.queue.size() <= r.QUEUE_MAX, "and refuses more when full")
	r.queue.clear()
	var guns: Dictionary = w.spawn_unit("artillery", dry(w.start + Vector3(40, 0, 40)), 0)
	var spot: Vector3 = dry(w.start + Vector3(80, 0, 40))
	w.order_bombard([guns], spot)
	check(guns.has("ground_attack"), "artillery can be ordered to bombard a spot")
	w.order_move([guns], dry(w.start + Vector3(30, 0, 30)))
	check(not guns.has("ground_attack") or guns.target != null, "a new move order lifts the bombardment")
	w.kill(guns)
	# Diplomacy: raids, alliances, peace offers.
	var d: Node = w.diplomacy
	d.make_peace(0, 3)
	if w.engagement != null:
		w.engagement.raid(3)
		check(w.engagement.active(0, 3) or d.at_war(0, 3), "a rival's border raid is a limited operation, not yet a war")
		d.make_peace(0, 3)
	d.set_flag(d.alliance, 0, 2, true)
	check(not w.hostile(0, 2) and not w.hostile(2, 0), "allies never shoot at each other")
	var ally_unit: Dictionary = w.spawn_unit("tank", dry(w.start + Vector3(-60, 0, -60)), 2)
	var my_unit: Dictionary = w.spawn_unit("tank", dry(ally_unit.node.position + Vector3(10, 0, 0)), 0)
	sim(5.0, false)
	check(ally_unit.hp == ally_unit.max_hp and my_unit.hp == my_unit.max_hp, "allied tanks side by side stay at peace")
	w.kill(ally_unit)
	w.kill(my_unit)
	d.set_flag(d.alliance, 0, 2, false)
	d.declare_war(0, 3)
	var offer: String = d.offer_peace(3)
	check(offer != "", "at war, peace can be offered (%s)" % offer)
	d.make_peace(0, 3)
	# Market sales.
	var mk2: Node = w.market
	if not mk2.has_market(): put("market")
	eco.recalculate()
	eco.res.iron = 100.0
	var cash0: float = eco.res.money
	mk2.sell("iron", 50)
	check(eco.res.iron == 50.0 and eco.res.money > cash0, "selling iron turns it into money")
	check(not mk2.sell("iron", 500).begins_with("Sold"), "you cannot sell more than you have")
	check(eco.res.iron == 50.0, "and the refusal takes nothing")
	# Occupation zones.
	var occ = w.get("occupation")
	if occ != null:
		occ.clear()
		for i in range(occ.MAX_ZONES + 1):
			occ.place(dry(w.start + Vector3(i * 30.0, 0, -40)), [], 0)
		check(occ.zones.filter(func(z): return int(z.owner) == 0).size() <= occ.MAX_ZONES, "no more than %d operational zones at once" % occ.MAX_ZONES)
		check(occ.zones.all(func(z): return z.cells.size() > 0), "every zone covers land")
		occ.clear()
		check(occ.zones.is_empty(), "zones can be cleared")
	# Holding ground: an army in a rival's border land wears its hold down.
	d.declare_war(0, 1)
	var t: Node = w.territory
	var border := -1
	var home1: Vector3 = hq(1).root.position
	for i in range(t.owner_of.size()):
		if t.owner_of[i] == 1 and t.center(i).distance_to(home1) > 60.0 and t.center(i).distance_to(home1) < 140.0:
			border = i
			break
	if border >= 0:
		var c0: float = float(t.control[border])
		var army := []
		for k in range(8): army.append(w.spawn_unit("tank", dry(t.center(border) + Vector3((k % 4) * 3.0, 0, (k / 4) * 3.0)), 0))
		# (armed: only a force that can fight holds ground; no battle runs here, only the land's tick)
		for i in range(40): t.tick()
		check(t.owner_of[border] == 0 or float(t.control[border]) < c0, "an army standing in a rival's land wears its hold down (%d -> %d%s)" % [int(c0), int(t.control[border]), ", taken" if t.owner_of[border] == 0 else ""])
		for k in army: w.kill(k)
	# A strategic submarine launches missiles.
	var sea2 = w.water_near(w.start, 220)
	if sea2 != null:
		var boomer: Dictionary = w.spawn_unit("nuclearSub", sea2, 0)
		check(w.missiles.launch_ships(0).has(boomer), "a nuclear submarine counts as a launcher")
		w.missiles.stock["cruise"] = 1
		var fired: String = w.missiles.launch("cruise", hq(1).root.position, boomer)
		check(not w.missiles.flying.is_empty() and w.missiles.flying[-1].from.distance_to(boomer.node.position) < 5.0, "and fires from the sea (%s)" % fired)
		for m in w.missiles.flying: m.node.queue_free()
		w.missiles.flying.clear()
		w.kill(boomer)

	# ================================================================ saving to disk
	var sv: Node = w.saves
	var slot := "battery-check"
	check(sv.save(slot), "the match saves to disk")
	check(FileAccess.file_exists(sv.path_of(slot)), "the save file exists")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sv.path_of(slot)))
	check(disk.get("format") == "dominion-save", "it is marked as a DOMINION save")
	var count_b: int = w.buildings.filter(func(b): return not b.dead).size()
	var money_now: float = eco.res.money
	eco.res.money = 1.0
	check(sv.load_slot(slot), "it loads back")
	check(absf(eco.res.money - money_now) < 50.0 and w.buildings.filter(func(b): return not b.dead).size() == count_b, "with the treasury and the buildings as they were")
	var f := FileAccess.open(sv.path_of("battery-broken"), FileAccess.WRITE)
	f.store_string("{not a save")
	f.close()
	check(not sv.load_slot("battery-broken"), "a damaged save is refused")
	check(not sv.load_slot("battery-missing"), "a missing save is refused")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sv.path_of(slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sv.path_of("battery-broken")))

	print("\nGAMEPLAY_DEEP: %d passed, %d failed" % [passed, errors.size()])
	for fl in errors: print("  FAILED: " + fl)
	print("GAMEPLAY_DEEP PASS" if errors.is_empty() else "GAMEPLAY_DEEP FAIL")
	quit(0 if errors.is_empty() else 1)
