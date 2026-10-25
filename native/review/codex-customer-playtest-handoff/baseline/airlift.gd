extends RefCounted
## Helicopters that carry troops and equipment. Research:
## native/HELICOPTERS-RESEARCH-2026-10-12.md.
##
## Select soldiers (or, for a heavy-lift helicopter, light vehicles and guns) and
## right-click one of your transport helicopters: they go to it and board.
## Select the helicopter and press J to land them, anywhere on dry ground.
##   helicopter (utility: Black Hawk, Mi-17...)  6 places: infantry only
##   heavyLift (Chinook, Mi-26, Z-8)            12 places: infantry, and light
##                                              vehicles and towed guns slung or
##                                              carried (6 places each); the
##                                              Mi-26 lifts an armoured carrier too
## Infantry takes one place each. Those aboard are lost with the helicopter.

const CAPACITY := {"helicopter": 6, "heavyLift": 12}
const LIGHT_LOADS := ["reconVehicle", "towedHowitzer", "mortarTeam", "recoillessTeam", "decoy", "counterBatteryRadar"]
const HEAVY_LOADS := ["apc", "ifv", "bushmaster"]   # only for the 20-tonne class
const TWENTY_TONNE := ["russia"]                      # the Mi-26
const BOARD_REACH := 9.0

static func is_transport(u: Dictionary) -> bool:
	return CAPACITY.has(str(u.get("key", ""))) and not u.dead

static func _id(w: Node, owner: int) -> String:
	return str(w.map.nations[owner].get("id", "")) if owner >= 0 and owner < w.map.nations.size() else ""

## Places `u` takes aboard `heli`, or 0 if it cannot be carried.
static func places(w: Node, heli: Dictionary, u: Dictionary) -> int:
	var key := str(u.get("key", ""))
	if u.dead or u.get("fly", false) or u.get("naval", false) or int(u.owner) != int(heli.owner) or key == "worker":
		return 0
	if key in w.infantry_keys:
		return 1
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
	var mine: Array = w.units.filter(func(u): return is_transport(u) and int(u.owner) == 0)
	if mine.is_empty():
		return null
	var heli = preload("res://scripts/picking.gd").pick(w.camera, mine, screen)
	if heli == null or not selected.any(func(u): return u != heli and places(w, heli, u) > 0):
		return null
	return heli

## Those of `selected` that fit go to `heli` and board it.
static func order_board(w: Node, selected: Array, heli: Dictionary) -> int:
	var left := room(heli)
	var going := []
	for u in selected:
		var p := places(w, heli, u)
		if p <= 0 or p > left:
			continue
		left -= p
		u.board = heli
		going.append(u)
	if not going.is_empty():
		w.order_move(going, heli.node.position)
		for u in going: u.board = heli   # (a move order clears nothing of ours, but keep it explicit)
	if int(heli.owner) == 0 and w.hud != null:
		if going.is_empty():
			w.hud.notice("No room aboard the %s, or nothing in the selection it can carry." % str(w.unit_defs[heli.key].name))
		else:
			w.hud.notice("%d boarding the %s. Select it and press J to land them." % [going.size(), str(w.unit_defs[heli.key].name)])
	return going.size()

## Every quarter second (war_tools.update): boarding, and the loss of a helicopter's load.
static func update(w: Node) -> void:
	for u in w.units:
		if u.dead:
			if not u.get("stowed", false) and not u.get("cargo", []).is_empty() and not u.get("cargo_lost", false):
				u.cargo_lost = true
				if int(u.owner) == 0 and w.hud != null:
					w.hud.notice("Your %s went down with %d aboard." % [str(w.unit_defs.get(u.key, {}).get("name", u.key)), u.cargo.size()], u.node.position)
			continue
		var heli = u.get("board")
		if heli == null:
			continue
		if heli.dead or places(w, heli, u) > room(heli):
			u.board = null
			continue
		var a: Vector3 = u.node.position
		var b: Vector3 = heli.node.position
		if Vector2(a.x - b.x, a.z - b.z).length() <= BOARD_REACH:
			embark(w, heli, u)
		elif u.get("target") == null and u.get("enemy") == null:
			w.order_move([u], b)   # the helicopter moved: follow it
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
	if str(heli.get("air_state", "ready")) in ["parked", "rearming", "landing", "taxi_in", "taxi_out"]:
		return ""
	var p: Vector3 = heli.node.position
	if w.height_at(p.x, p.z) <= float(w.map.seaLevel) + 0.2:
		return "Over water: fly over dry ground to land them."
	return ""

## Lands everyone aboard around the helicopter.
static func unload(w: Node, heli: Dictionary) -> Array:
	var out := []
	if unload_blocked(w, heli) != "":
		return out
	var centre: Vector3 = heli.node.position
	var cargo: Array = heli.cargo
	for i in range(cargo.size()):
		var c: Dictionary = cargo[i]
		var angle := TAU * i / maxf(1.0, cargo.size())
		var spot := Vector3(centre.x + cos(angle) * 4.5, 0.0, centre.z + sin(angle) * 4.5)
		spot.y = w.height_at(spot.x, spot.z)
		var land = w.land_point(spot, 12.0) if w.has_method("land_point") else spot
		var u: Dictionary = w.spawn_unit(str(c.key), land if land != null else spot, int(heli.owner))
		if u.is_empty():
			continue
		u.hp = clampf(float(c.get("hp", u.max_hp)), 1.0, float(u.max_hp))
		if float(c.get("xp", 0.0)) > 0.0:
			preload("res://scripts/veterancy.gd").set_xp(u, float(c.xp))
		out.append(u)
	heli.cargo = []
	return out

## J: every selected transport of the player's lands its load.
static func unload_selected(w: Node) -> String:
	var helis: Array = w.units.filter(func(u): return u.selected and is_transport(u) and int(u.owner) == 0)
	if helis.is_empty():
		return ""
	var landed := 0
	var why := ""
	for h in helis:
		var blocked := unload_blocked(w, h)
		if blocked != "":
			why = blocked
			continue
		landed += unload(w, h).size()
	var text := ("%d landed." % landed) if landed > 0 else why
	if w.hud != null and text != "":
		w.hud.notice(text)
	return text
