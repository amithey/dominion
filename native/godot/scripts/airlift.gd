extends RefCounted
## Helicopters and landing ships that carry troops and equipment. Research:
## native/HELICOPTERS-RESEARCH-2026-10-12.md, native/TRANSPORTS-RESEARCH-2026-10-18.md.
##
## Select soldiers (or, for a heavy-lift helicopter, light vehicles and guns) and
## right-click one of your transports, or press its Board button: they go to it and
## board. A landing ship first sails to the nearest coast and the troops walk to the
## water's edge. Select the transport and press J (or the Unload button) to put them
## ashore; "Land at..." sends it to a chosen place and unloads on arrival.
##   helicopter (utility: Black Hawk, Mi-17...)  6 places: infantry only
##   heavyLift (Chinook, Mi-26, Z-8)            12 places: infantry, and light
##                                              vehicles and towed guns slung or
##                                              carried (6 places each); the
##                                              Mi-26 lifts an armoured carrier too
##   landingShip (Mistral, San Antonio...)     36 places: any ground unit; a soldier or an
##                                              engineer takes one place, a vehicle its army
##                                              capacity (2 to 6)
## Infantry takes one place each. Those aboard are lost with the transport.

const CAPACITY := {"helicopter": 6, "heavyLift": 12, "landingShip": 36}
const SHIPS := ["landingShip"]
const LIGHT_LOADS := ["reconVehicle", "towedHowitzer", "mortarTeam", "recoillessTeam", "decoy", "counterBatteryRadar"]
const HEAVY_LOADS := ["apc", "ifv", "bushmaster"]   # only for the 20-tonne class
const TWENTY_TONNE := ["russia"]                      # the Mi-26
const BOARD_REACH := 12.0         # a helicopter: the troops come to it
const SHIP_REACH := 26.0          # a ship: they stand on the shore beside it
const SHORE_REACH := 38.0         # how far from the hull the party can be set ashore
const ARRIVE := 12.0              # close enough to a landing point to unload
const BOARD_WAIT := 300.0          # seconds troops wait on the shore for a ship that has not come
const LANDING_TIMEOUT := 180.0     # seconds before an unfinished landing order is dropped

static func is_transport(u: Dictionary) -> bool:
	return CAPACITY.has(str(u.get("key", ""))) and not u.dead

static func is_ship(u: Dictionary) -> bool:
	return str(u.get("key", "")) in SHIPS

static func _id(w: Node, owner: int) -> String:
	return str(w.map.nations[owner].get("id", "")) if owner >= 0 and owner < w.map.nations.size() else ""

## Places `u` takes aboard `heli`, or 0 if it cannot be carried.
static func places(w: Node, heli: Dictionary, u: Dictionary) -> int:
	var key := str(u.get("key", ""))
	if u.dead or u.get("stowed", false) or u.get("fly", false) or u.get("naval", false) or int(u.owner) != int(heli.owner):
		return 0
	if key == "worker":
		return 1 if is_ship(heli) else 0
	if key in w.infantry_keys:
		return 1
	if is_ship(heli):
		var def: Dictionary = w.unit_defs.get(key, {})
		return clampi(int(def.get("pop", 1)), 1, 6) if not def.is_empty() else 0
	if heli.key == "heavyLift":
		if key in LIGHT_LOADS:
			return 6
		if key in HEAVY_LOADS and _id(w, int(heli.owner)) in TWENTY_TONNE:
			return 12
	return 0

static func used(heli: Dictionary) -> int:
	var n := 0
	for c in heli.get("cargo", []):
		n += int(c.get("places", 1))
	return n

static func room(heli: Dictionary) -> int:
	return int(CAPACITY.get(heli.key, 0)) - used(heli)

## The player's transport under the mouse, when the selection could board it.
static func transport_under(w: Node, selected: Array, screen: Vector2) -> Variant:
	var mine: Array = w.units.filter(func(u): return is_transport(u) and int(u.owner) == 0 and not u.get("stowed", false))
	if mine.is_empty():
		return null
	var heli = preload("res://scripts/picking.gd").pick(w.camera, mine, screen)
	if heli == null or not selected.any(func(u): return not is_same(u, heli) and places(w, heli, u) > 0):
		return null
	return heli

## The nearest transport of the player's that the selection could board, or null.
static func nearest_for(w: Node, selected: Array) -> Variant:
	var best = null
	var best_d := INF
	for t in w.units:
		if not is_transport(t) or int(t.owner) != 0 or t.get("stowed", false):
			continue
		if not selected.any(func(u): return not is_same(u, t) and places(w, t, u) > 0 and room(t) >= places(w, t, u)):
			continue
		var d: float = Vector2(t.node.position.x - selected[0].node.position.x, t.node.position.z - selected[0].node.position.z).length()
		if d < best_d:
			best_d = d
			best = t
	return best

## The nearest dry ground a person can stand on, within `reach` of `from`
## (the water's edge beside a ship): Vector3.INF if none.
static func shore_point(w: Node, from: Vector3, reach := 70.0) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for radius in range(4, int(reach) + 1, 4):
		for i in range(24):
			var a := TAU * i / 24.0
			var p: Vector3 = from + Vector3(cos(a), 0, sin(a)) * radius
			p.y = w.height_at(p.x, p.z)
			if p.y <= float(w.map.seaLevel) + 0.5 or not w.open_ground(p) or not w.walkable(p.x, p.z):
				continue
			var d := Vector2(p.x - from.x, p.z - from.z).length()
			if d < best_d:
				best_d = d
				best = p
		if best != Vector3.INF:
			return best
	return best

## Where the party walks to meet a ship: the shore beside it.
static func dock_for(w: Node, ship: Dictionary) -> Vector3:
	return shore_point(w, ship.node.position, SHIP_REACH + 14.0)

## Those of `selected` that fit go to `heli` and board it.
static func order_board(w: Node, selected: Array, heli: Dictionary) -> int:
	var left := room(heli)
	var going := []
	for u in selected:
		var p := places(w, heli, u)
		if p <= 0 or p > left:
			continue
		left -= p
		going.append(u)
	var name := str(w.unit_defs[heli.key].name)
	if going.is_empty():
		if int(heli.owner) == 0 and w.hud != null:
			w.hud.notice("No room aboard the %s, or nothing in the selection it can carry." % name)
		return 0
	var meet: Vector3 = heli.node.position
	if is_ship(heli):
		meet = _ship_meeting(w, heli, going)
		if meet == Vector3.INF:
			if int(heli.owner) == 0 and w.hud != null:
				w.hud.notice("No coast near your troops for the %s to come alongside." % name)
			return 0
	# Each goes to the meeting point on its own (a formation would leave the rear ranks out of reach).
	for u in going:
		w.order_move([u], meet)
		u.board = heli
		u.board_since = w.game_time
	if int(heli.owner) == 0 and w.hud != null:
		if is_ship(heli):
			w.hud.notice("%d boarding the %s at the shore. Select it and press J to put them ashore." % [going.size(), name])
		else:
			w.hud.notice("%d boarding the %s. Select it and press J to land them." % [going.size(), name])
	return going.size()

## Where a ship and the boarders meet: the ship stays if it already lies by a shore,
## otherwise it sails to the water nearest the troops. Returns the place the troops walk to.
static func _ship_meeting(w: Node, ship: Dictionary, going: Array) -> Vector3:
	var dock := dock_for(w, ship)
	if dock != Vector3.INF:
		return dock
	var centre := Vector3.ZERO
	for u in going:
		centre += u.node.position
	centre /= going.size()
	# The water nearest the troops, and the dry ground beside it where they will stand.
	var water = w.water_near(centre, 160)
	if water == null:
		return Vector3.INF
	var shore := shore_point(w, water, 40.0)
	if shore == Vector3.INF:
		return Vector3.INF
	var berth = w.water_near(shore, 30)
	if berth == null:
		return Vector3.INF
	w.order_move([ship], berth)
	ship.rendezvous = berth
	return shore

## Every quarter second (war_tools.update): boarding, landing orders, and the loss of a load.
static func update(w: Node) -> void:
	for u in w.units:
		if u.dead:
			if not u.get("stowed", false) and not u.get("cargo", []).is_empty() and not u.get("cargo_lost", false):
				u.cargo_lost = true
				if int(u.owner) == 0 and w.hud != null:
					w.hud.notice("Your %s went down with %d aboard." % [str(w.unit_defs.get(u.key, {}).get("name", u.key)), u.cargo.size()], u.node.position)
			continue
		if u.get("unload_go") != null:
			_landing_step(w, u)
		var heli = u.get("board")
		if heli == null:
			continue
		if heli.dead or places(w, heli, u) <= 0 or places(w, heli, u) > room(heli):
			u.board = null
			continue
		var a: Vector3 = u.node.position
		var b: Vector3 = heli.node.position
		var reach: float = SHIP_REACH if is_ship(heli) else BOARD_REACH
		if Vector2(a.x - b.x, a.z - b.z).length() <= reach:
			embark(w, heli, u)
		elif u.get("target") == null and u.get("enemy") == null:
			# Arrived short of it, or the carrier moved: walk to where it is now.
			var meet: Vector3 = b
			if is_ship(heli):
				meet = dock_for(w, heli)
				if meet == Vector3.INF:
					# The ship is still at sea, sailing to the coast: wait at the shore for it.
					if w.game_time - float(u.get("board_since", w.game_time)) > BOARD_WAIT:
						u.board = null
					continue
			w.order_move([u], meet)
			u.board = heli

## `u` is aboard `heli`: off the map, kept as what it was.
static func embark(w: Node, heli: Dictionary, u: Dictionary) -> void:
	if not heli.has("cargo"): heli.cargo = []
	heli.cargo.append({"key": u.key, "hp": float(u.hp), "places": places(w, heli, u), "xp": float(u.get("xp", 0.0))})
	u.board = null
	preload("res://scripts/future_weapons.gd").stow(w, u)

## Why `heli` cannot land its load here, or "".
static func unload_blocked(w: Node, heli: Dictionary) -> String:
	if heli.get("cargo", []).is_empty():
		return "Nobody aboard."
	var p: Vector3 = heli.node.position
	if is_ship(heli):
		if landing_spot(w, p, [], null, SHORE_REACH) == Vector3.INF:
			return "No shore within reach: sail closer to land, or use Land at to pick the beach."
		return ""
	if w.height_at(p.x, p.z) <= float(w.map.seaLevel) + 0.2:
		return "Over water: fly over dry ground to land them."
	if landing_spot(w, p) == Vector3.INF:
		return "No clear landing ground nearby: move away from buildings or cliffs."
	return ""

## Search actual clear ground, not land_point(), which only chooses a direction
## and can still end in water or inside a building footprint. From a ship the
## ring that comes first is the nearest shore; with `prefer`, the spot closest to it.
static func landing_spot(w: Node, centre: Vector3, occupied: Array = [], prefer = null, reach := 16.0) -> Vector3:
	var radii: Array = [4.5, 8.0, 12.0, 16.0] if reach <= 16.0 else range(8, int(reach) + 1, 4)
	for radius in radii:
		var best := Vector3.INF
		var best_d := INF
		for i in range(24):
			var angle := TAU * i / 24.0
			var p: Vector3 = centre + Vector3(cos(angle), 0, sin(angle)) * radius
			p.y = w.height_at(p.x, p.z)
			if w.open_ground(p) and w.walkable(p.x, p.z) and p.y > float(w.map.seaLevel) + 0.2 and occupied.all(func(at): return at.distance_to(p) >= 2.0):
				if prefer == null:
					return p
				var d: float = Vector2(p.x - prefer.x, p.z - prefer.z).length()
				if d < best_d:
					best_d = d
					best = p
		if best != Vector3.INF:
			return best
	return Vector3.INF

## Lands everyone aboard around the transport (a ship: on the nearest shore).
static func unload(w: Node, heli: Dictionary) -> Array:
	var out := []
	if unload_blocked(w, heli) != "":
		return out
	var centre: Vector3 = heli.node.position
	var cargo: Array = heli.cargo
	var remaining := []
	var occupied := []
	var ship := is_ship(heli)
	var anchor: Vector3 = centre
	if ship:
		anchor = landing_spot(w, centre, [], heli.get("unload_target"), SHORE_REACH)
	for i in range(cargo.size()):
		var c: Dictionary = cargo[i]
		var spot: Vector3
		if ship:
			spot = landing_spot(w, anchor, occupied, null, 24.0)
		else:
			spot = landing_spot(w, centre, occupied)
		if spot == Vector3.INF:
			remaining.append(c)
			continue
		var u: Dictionary = w.spawn_unit(str(c.key), spot, int(heli.owner))
		if u.is_empty():
			remaining.append(c)
			continue
		occupied.append(spot)
		u.hp = clampf(float(c.get("hp", u.max_hp)), 1.0, float(u.max_hp))
		if float(c.get("xp", 0.0)) > 0.0:
			preload("res://scripts/veterancy.gd").set_xp(u, float(c.xp))
		out.append(u)
	heli.cargo = remaining
	return out

# ---------------------------------------------------------------- landing orders

## What a transport carries, in words.
static func manifest(w: Node, t: Dictionary) -> String:
	var counts := {}
	for c in t.get("cargo", []):
		counts[c.key] = int(counts.get(c.key, 0)) + 1
	var parts := PackedStringArray()
	for k in counts:
		parts.append("%d %s" % [counts[k], str(w.unit_defs.get(k, {}).get("name", k))])
	return "Aboard %d of %d places%s" % [used(t), int(CAPACITY.get(t.key, 0)), (": " + ", ".join(parts)) if not parts.is_empty() else ""]

## The sea or air position from which `transport` can put people ashore at (or nearest to)
## land point `at`: {"go": Vector3, "beach": Vector3}, or {} when there is none.
static func landing_plan(w: Node, transport: Dictionary, at: Vector3) -> Dictionary:
	if not is_ship(transport):
		var spot := shore_point(w, at, 40.0)
		return {} if spot == Vector3.INF else {"go": spot, "beach": spot}
	# A ship stands off the beach: the nearest deep water to the place, with dry ground within reach of the hull.
	var water = w.water_near(at, 90)
	if water == null:
		return {}
	var beach := shore_point(w, water, SHORE_REACH - 10.0)
	if beach == Vector3.INF:
		return {}
	return {"go": water, "beach": beach}

## Orders `transport` to the place it can land from, and to unload on arrival.
static func order_unload_at(w: Node, transport: Dictionary, at: Vector3) -> bool:
	if transport.get("cargo", []).is_empty():
		return false
	var plan := landing_plan(w, transport, at)
	if plan.is_empty():
		return false
	_head_for(w, transport, plan)
	return true

static func _head_for(w: Node, t: Dictionary, plan: Dictionary) -> void:
	w.order_move([t], plan.go)
	t.unload_go = plan.go
	t.unload_target = plan.beach
	t.unload_since = w.game_time

static func _landing_step(w: Node, t: Dictionary) -> void:
	var go: Vector3 = t.unload_go
	var d: float = Vector2(t.node.position.x - go.x, t.node.position.z - go.z).length()
	var late: bool = w.game_time - float(t.get("unload_since", w.game_time)) > LANDING_TIMEOUT
	if d > ARRIVE and not late:
		return
	t.erase("unload_go")
	var landed_units := unload(w, t)
	var landed := landed_units.size()
	t.erase("unload_target")
	# A rival's landing party attacks at once (ai_navy.gd).
	if int(t.owner) != 0 and t.get("assault_target") != null and not landed_units.is_empty():
		w.order_move(landed_units, t.assault_target, true)
		t.erase("assault_target")
	if int(t.owner) == 0 and w.hud != null:
		if landed > 0:
			w.hud.notice("%d put ashore." % landed, t.node.position)
		else:
			var why := unload_blocked(w, t)
			w.hud.notice(why if why != "" else "The landing could not be completed here.")

## J / the Unload button: every selected transport of the player's lands its load here, or,
## if it cannot, sails to the nearest coast and lands there.
static func unload_selected(w: Node) -> String:
	var helis: Array = w.units.filter(func(u): return u.selected and is_transport(u) and int(u.owner) == 0)
	if helis.is_empty():
		return ""
	var landed := 0
	var heading := 0
	var why := ""
	for h in helis:
		var blocked := unload_blocked(w, h)
		if blocked == "":
			landed += unload(w, h).size()
			continue
		if h.get("cargo", []).is_empty():
			why = blocked
			continue
		# Not possible where it is: go to the nearest place where it is.
		var plan := _nearest_landing(w, h)
		if not plan.is_empty():
			_head_for(w, h, plan)
			heading += 1
		else:
			why = blocked
	var text := ""
	if landed > 0:
		text = "%d put ashore." % landed
	if heading > 0:
		text += (" " if text != "" else "") + "%d transport%s heading for the nearest landing place and will unload on arrival." % [heading, "s" if heading > 1 else ""]
	if text == "":
		text = why
	if w.hud != null and text != "":
		w.hud.notice(text)
	return text

## The nearest coast a transport can put people ashore at, searching outward.
static func _nearest_landing(w: Node, t: Dictionary) -> Dictionary:
	var from: Vector3 = t.node.position
	for radius in range(0, 260, 20):
		for i in range(1 if radius == 0 else 16):
			var a := TAU * i / 16.0
			var p: Vector3 = from + Vector3(cos(a), 0, sin(a)) * radius
			var plan := landing_plan(w, t, p)
			if not plan.is_empty():
				return plan
	return {}
