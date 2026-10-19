extends RefCounted
## Rivals at sea (native/AI-NAVY-2026-10-18.md). Until now a rival's ships were built and then left
## at their shipyard (its attack waves took only land units), and an army that had to cross water
## simply stopped at the shore. A nation at war now uses its navy three ways:
##   sortie       a task force of its warships sails against the nearest enemy ships or coastal
##                works (ports, shipyards, rigs, wharves, towns on the shore), fights there, and
##                returns when its time is up;
##   defence      enemy ships that come within reach of its coast are met by whatever it has;
##   landing      when its army cannot walk to the enemy (no land route), it builds a landing ship,
##                musters infantry and armour on the quay, sails with escorts to a beach near an
##                enemy town, puts them ashore (airlift.gd) and the landed force attacks.
## How much of it depends on the nation's navy rating (war_tools.NAVY) and its difficulty; every
## operation is paced, so a rival never fields a fleet it has not built.

const Air := preload("res://scripts/airlift.gd")
const TICK := 4.0
const SORTIE_ALL := 130.0         # base seconds between sorties (scaled by aggression and speed)
const SORTIE_LENGTH := 160.0      # seconds a task force stays out
const DEFEND_REACH := 150.0       # enemy ships this close to a rival's building are met
const MIN_ESCORTS := 1
const WAVE_COOLDOWN := 150.0
const LOAD_TIMEOUT := 110.0
const MIN_TROOPS := 8
const COASTAL := ["port", "shipyard", "offshoreRig", "fishingWharf", "hq", "cityCenter", "villageCenter", "airfield", "oilRefinery"]

static func state(n: Dictionary) -> Dictionary:
	if not n.has("navy"):
		n.navy = {"t": 0.0, "next_sortie": 90.0, "sortie": {}, "wave_ready": 60.0, "ops": {}}
	return n.navy

## A rival's warships: armed, afloat, not a transport.
static func warships(w: Node, owner: int) -> Array:
	return w.units.filter(func(u): return int(u.owner) == owner and not u.dead and u.get("naval", false) and float(u.dmg) > 0.0 and not Air.is_ship(u) and not w.disabled(u))

static func transports(w: Node, owner: int) -> Array:
	return w.units.filter(func(u): return int(u.owner) == owner and not u.dead and Air.is_ship(u) and not w.disabled(u))

## Whether the rival's army cannot reach its enemy on foot: it needs the sea.
static func needs_sea(w: Node, ai: Node, n: Dictionary, home: Dictionary) -> bool:
	var st := state(n)
	if st.has("needs_sea_at") and w.game_time - float(st.needs_sea_at) < 30.0:
		return bool(st.get("needs_sea", false))
	var enemies: Array = w.diplomacy.enemies_of(n.id)
	var need := false
	if not enemies.is_empty():
		var target = ai.nearest_enemy_asset(home.root.position, enemies, n.id)
		if target != null:
			var route: PackedVector3Array = w.path_between(Vector3(home.root.position.x + 14.0, home.root.position.y, home.root.position.z), target.root.position)
			need = route.is_empty() or Vector2(route[route.size() - 1].x - target.root.position.x, route[route.size() - 1].z - target.root.position.z).length() > 30.0
	st.needs_sea = need
	st.needs_sea_at = w.game_time
	return need

## Whether the rival has a yard and fewer warships than its navy rating asks for (it trains ships even with its land army full).
static func fleet_short(w: Node, ai: Node, n: Dictionary) -> bool:
	if ai.production_sites(n.id, "gunboat").is_empty():
		return false
	if w.diplomacy.enemies_of(n.id).is_empty() and float(n.get("tech", 0.0)) < 2.0:
		return false
	var wanted := roundi(2.0 + 10.0 * preload("res://scripts/war_tools.gd").navy(w, n.id))
	return warships(w, n.id).size() + transports(w, n.id).size() < wanted

## A rival at war that needs the sea and has no landing ship (ai_pick builds one).
static func wants_transport(w: Node, owner: int) -> bool:
	for n in w.ai.nations:
		if int(n.id) == owner:
			var st := state(n)
			return bool(st.get("needs_sea", false)) and transports(w, owner).size() < 2
	return false

## Called for each rival every frame (ai.think); the real work every TICK seconds.
static func update(w: Node, ai: Node, n: Dictionary, home: Dictionary, delta: float) -> void:
	var st := state(n)
	st.t = float(st.t) + delta
	if float(st.t) < TICK:
		return
	var dt: float = st.t
	st.t = 0.0
	var enemies: Array = w.diplomacy.enemies_of(n.id)
	if enemies.is_empty() or w.match_config.get("style", "standard") == "sandbox":
		return
	var ships := warships(w, n.id)
	_defend(w, n, home, ships, enemies)
	_sortie(w, ai, n, home, ships, enemies, dt)
	if needs_sea(w, ai, n, home):
		_landing(w, ai, n, home, ships, enemies, dt)

# ---------------------------------------------------------------- sortie and defence

## Enemy ships near the rival's coast are met.
static func _defend(w: Node, n: Dictionary, home: Dictionary, ships: Array, enemies: Array) -> void:
	if ships.is_empty():
		return
	var mine: Array = w.buildings.filter(func(b): return b.owner == n.id and not b.dead and b.key in COASTAL)
	if mine.is_empty():
		return
	for foe in w.units:
		if foe.dead or not foe.get("naval", false) or not (foe.owner in enemies) or float(foe.dmg) <= 0.0:
			continue
		for b in mine:
			if Vector2(foe.node.position.x - b.root.position.x, foe.node.position.z - b.root.position.z).length() <= DEFEND_REACH:
				var free: Array = ships.filter(func(s): return s.get("target") == null and s.get("enemy") == null or w.flat_distance(s, foe) < 200.0)
				if not free.is_empty():
					w.order_attack(free.slice(0, 6), foe)
				return

static func _sortie(w: Node, ai: Node, n: Dictionary, home: Dictionary, ships: Array, enemies: Array, dt: float) -> void:
	var st := state(n)
	var sortie: Dictionary = st.sortie
	if not sortie.is_empty():
		# Home again when the time is up or the force has gone.
		var alive: Array = sortie.ships.filter(func(s): return not s.dead)
		if alive.is_empty() or w.game_time >= float(sortie.until):
			if not alive.is_empty():
				var door = w.water_near(home.root.position, 160)
				if door != null:
					w.order_move(alive, door)
			st.sortie = {}
			st.next_sortie = w.game_time + SORTIE_ALL / (0.6 + float(ai.row(n).get("aggression", 0.4))) / float(n.speed)
		return
	if w.game_time < float(st.next_sortie):
		return
	# A task force of the warships that are idle (the escort of a landing keeps its own).
	var idle: Array = ships.filter(func(s): return not s.get("escorting", false))
	var want: int = 2 + int(preload("res://scripts/war_tools.gd").navy(w, n.id) * 4.0)
	if idle.size() < 2:
		st.next_sortie = w.game_time + 40.0
		return
	var target: Variant = _sortie_target(w, home, enemies)
	if target == null:
		st.next_sortie = w.game_time + 60.0
		return
	var force: Array = idle.slice(0, want)
	var at: Vector3 = target.node.position if target.get("node") != null and not target.get("is_building", false) else target.root.position
	var stand_off = w.water_near(at, 70) if target.get("is_building", false) else at
	if stand_off == null:
		st.next_sortie = w.game_time + 60.0
		return
	w.order_move(force, stand_off, true)
	st.sortie = {"ships": force, "until": w.game_time + SORTIE_LENGTH, "target": target}
	if target.owner == 0 and w.hud != null:
		pass   # (an unseen fleet is not announced: you learn of it from your own radars and agents; sitrep.gd)

## The nearest enemy ship, or the nearest enemy coastal work, to sail against.
static func _sortie_target(w: Node, home: Dictionary, enemies: Array) -> Variant:
	var best = null
	var best_d := INF
	var from: Vector3 = home.root.position
	for u in w.units:
		if u.dead or not u.get("naval", false) or not (u.owner in enemies):
			continue
		var d: float = from.distance_to(u.node.position)
		if d < best_d:
			best_d = d
			best = u
	if best != null and best_d < 420.0:
		return best
	best = null
	best_d = INF
	var checked := 0
	for b in w.buildings:
		if b.dead or not (b.owner in enemies) or not b.key in COASTAL:
			continue
		checked += 1
		if checked > 60:
			break
		if w.water_near(b.root.position, 70) == null:
			continue
		var d: float = from.distance_to(b.root.position)
		if d < best_d:
			best_d = d
			best = b
	return best

# ---------------------------------------------------------------- landings

## Loads, sails, lands. One operation at a time per nation.
static func _landing(w: Node, ai: Node, n: Dictionary, home: Dictionary, ships: Array, enemies: Array, dt: float) -> void:
	var st := state(n)
	var fleet: Array = transports(w, n.id)
	if fleet.is_empty():
		return
	var ship: Dictionary = fleet[0]
	var op: Dictionary = ship.get("op", {})
	var now: float = w.game_time
	if op.is_empty():
		if now < float(st.wave_ready):
			return
		var troops := _troops(w, ai, n, ship, home)
		if troops.size() < MIN_TROOPS:
			return
		var target = ai.nearest_enemy_asset(home.root.position, enemies, n.id)
		if target == null:
			return
		var boarding := Air.order_board(w, troops, ship)
		if boarding < MIN_TROOPS:
			return
		ship.op = {"phase": "load", "since": now, "target": target.root.position, "target_building": target}
		return
	match op.phase:
		"load":
			var full: bool = Air.room(ship) <= 2
			var ready: bool = Air.used(ship) >= MIN_TROOPS and now - float(op.since) > 25.0
			if full or ready or now - float(op.since) > LOAD_TIMEOUT:
				if Air.used(ship) < MIN_TROOPS:
					_abort(w, n, ship)
					return
				var target_pos: Vector3 = op.target
				if op.target_building != null and not op.target_building.dead:
					target_pos = op.target_building.root.position
				if not Air.order_unload_at(w, ship, target_pos):
					# That town has no usable beach: another enemy building on a coast.
					var alt: Variant = _beach_target(w, ai, home, enemies, ship)
					if alt == null or not Air.order_unload_at(w, ship, alt.root.position):
						_abort(w, n, ship)
						return
					target_pos = alt.root.position
				ship.assault_target = target_pos
				op.phase = "sail"
				op.since = now
				# The escort goes ahead to the same water.
				var escorts: Array = ships.filter(func(s): return not s.get("escorting", false)).slice(0, MIN_ESCORTS + int(preload("res://scripts/war_tools.gd").navy(w, n.id) * 2.0))
				var go: Vector3 = ship.unload_go
				for e in escorts:
					e.escorting = true
					w.order_move([e], go + Vector3(randf_range(-14.0, 14.0), 0, randf_range(-14.0, 14.0)), true)
				op.escorts = escorts
		"sail":
			if ship.get("unload_go") == null and ship.get("cargo", []).is_empty():
				# Landed (airlift.gd sent the force in): the ship goes home for another wave.
				_finish(w, n, ship, home)
			elif now - float(op.since) > 260.0:
				_abort(w, n, ship)

## Infantry and armour of the rival that are idle, within reach of its yard, up to the ship's places.
static func _troops(w: Node, ai: Node, n: Dictionary, ship: Dictionary, home: Dictionary) -> Array:
	var out := []
	var left: int = Air.room(ship)
	var dock: Vector3 = ship.node.position
	var pool: Array = w.units.filter(func(u): return int(u.owner) == n.id and ai.available(u) and not u.get("naval", false) and not u.get("fly", false) and u.key != "worker" and u.get("board") == null and u.get("target") == null and Vector2(u.node.position.x - dock.x, u.node.position.z - dock.z).length() < 260.0)
	pool.sort_custom(func(a, b): return Vector2(a.node.position.x - dock.x, a.node.position.z - dock.z).length() < Vector2(b.node.position.x - dock.x, b.node.position.z - dock.z).length())
	for u in pool:
		var p := Air.places(w, ship, u)
		if p > 0 and p <= left:
			out.append(u)
			left -= p
		if left <= 0:
			break
	return out

static func _beach_target(w: Node, ai: Node, home: Dictionary, enemies: Array, ship: Dictionary) -> Variant:
	var best = null
	var best_d := INF
	for b in w.buildings:
		if b.dead or not (b.owner in enemies):
			continue
		var plan := Air.landing_plan(w, ship, b.root.position)
		if plan.is_empty():
			continue
		var d: float = home.root.position.distance_to(b.root.position)
		if d < best_d:
			best_d = d
			best = b
	return best

static func _abort(w: Node, n: Dictionary, ship: Dictionary) -> void:
	for u in w.units:
		if u.get("board") == ship:
			u.board = null
	ship.erase("unload_go")
	ship.erase("assault_target")
	_release(ship)
	ship.op = {}
	state(n).wave_ready = w.game_time + 45.0

static func _finish(w: Node, n: Dictionary, ship: Dictionary, home: Dictionary) -> void:
	_release(ship)
	ship.op = {}
	state(n).wave_ready = w.game_time + WAVE_COOLDOWN
	var door = w.water_near(home.root.position, 160)
	if door != null:
		w.order_move([ship], door)

static func _release(ship: Dictionary) -> void:
	for e in ship.get("op", {}).get("escorts", []):
		if e is Dictionary:
			e.erase("escorting")
