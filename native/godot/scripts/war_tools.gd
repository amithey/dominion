extends RefCounted
## The tools of war beyond the fighting units (force_catalog.gd ROLES):
## engineers, recovery, deception, sensors, and the ships and aircraft that
## carry them. Research: native/WAR-TOOLS-RESEARCH-2026-10-12.md.
##
##   mineLayer            halted for a few seconds, it lays an anti-vehicle
##                        minefield where it stands: enemy vehicles that enter
##                        it are struck (infantry is not: anti-vehicle mines);
##                        the enemy cannot see it, its owner can
##   mineClearer          a line charge clears enemy minefields near it (and
##                        is a crude weapon against infantry and buildings)
##   recoveryVehicle      repairs damaged friendly vehicles near it
##   decoy                an inflatable or wooden copy of a weapon: costs
##                        little, has no weapon, draws fire and loitering munitions
##   counterBatteryRadar  finds enemy guns and rocket launchers by their shells:
##                        reveals them within its reach, and your fire on
##                        them hits a quarter harder
##   coastalASM           a land battery that strikes only ships, far out to sea
##   aewc                 an airborne radar: reveals enemy aircraft and ships
##                        far around it, and your aircraft near it hit harder
##   ewJet                electronic attack: enemy air defences near it lose
##                        much of their aim
##   maritimePatrol       hunts submarines: reveals them, and strikes them hard
##   carrier              a flagship that carries its air wing: aircraft
##                        parked on deck take off against targets far out,
##                        strike, fly back, land and are rearmed; the ship's own
##                        guns only defend it (see "the air wing" below)
##   asFrigate            an escort built to hunt submarines
## All figures are game balance.

const VEHICLES := ["mineLayer", "mineClearer", "recoveryVehicle", "supplyTruck", "decoy", "counterBatteryRadar", "coastalASM", "combatUGV", "logisticsUGV", "robotDog"]
const AIR := ["aewc", "ewJet", "maritimePatrol", "carrierJet", "carrierDrone", "heavyLift", "navalHelicopter", "heavyBomberDrone"]
const FIXED_WING := ["aewc", "ewJet", "maritimePatrol", "carrierJet", "carrierDrone"]
const NAVAL := ["carrier", "asFrigate", "landingShip"]
const ALTITUDE := {"aewc": 32.0, "ewJet": 27.0, "maritimePatrol": 21.0, "carrierJet": 24.0, "carrierDrone": 20.0, "heavyLift": 22.0, "navalHelicopter": 20.0, "heavyBomberDrone": 19.0}
const SHIP_LENGTH := {"carrier": 30.0, "asFrigate": 13.0, "landingShip": 16.0}
const WEAPON := {"coastalASM": "missile", "asFrigate": "missile", "maritimePatrol": "missile", "ewJet": "missile", "mineClearer": "rocket", "carrierJet": "missile", "carrierDrone": "missile", "navalHelicopter": "missile", "heavyBomberDrone": "bomb"}
const NAVAL_ONLY := ["coastalASM", "maritimePatrol", "navalHelicopter"]
const SUBMARINES := ["submarine", "nuclearSub", "orca"]
const SUB_HUNTERS := ["maritimePatrol", "asFrigate", "navalHelicopter", "destroyer"]
const ASW_CAPABLE := ["destroyer", "asFrigate", "maritimePatrol", "navalHelicopter", "submarine", "nuclearSub", "orca"]
const GUNS := ["artillery", "mlrs", "himars", "k9", "heavyRocket", "tos1a", "towedHowitzer", "wheeledHowitzer", "mortarTeam"]
const AIR_DEFENCE := ["samLauncher", "aaVehicle", "shortRangeSAM", "laserAD", "irisT", "manpads", "abmLauncher", "saudiThaad", "aegisCruiser", "type45"]

const MINE_RADIUS := 11.5
const MINE_CHARGES := 5
const MINE_DAMAGE := 260.0
const AP_MINE_CHARGES := 7
const AP_MINE_DAMAGE := 68.0
const MINE_COST := 30.0
const LAY_AFTER := 6.0       # seconds halted before an engineer lays a field
const LAY_COOLDOWN := 45.0
const FIELDS_PER_NATION := 36
const CLEAR_REACH := 22.0
const CLEAR_TIME := 3.0
const REPAIR_REACH := 18.0
const REPAIR_RATE := 16.0    # health a second
const RADAR_REACH := 110.0
const RADAR_BONUS := 0.25
const AEW_REACH := 150.0
const AEW_BONUS := 0.1
const JAM_REACH := 60.0
const JAM_FACTOR := 0.6
const SUB_FACTOR := 1.8
const TICK := 0.25
const ROBOTS := ["combatUGV", "logisticsUGV", "robotDog", "heavyBomberDrone", "carrierDrone"]   # no crew: no war support lost
const EVAC_REACH := 14.0
const EVAC_RATE := 6.0
# The air wing (by class: force_models.CARRIER_STYLE): aircraft aboard, and what flies from the deck.
const WING := {"usa": 5, "china": 5, "france": 5, "italy": 3, "uk": 4, "india": 4, "turkiye": 4, "japan": 4, "iran": 3, "russia": 4, "brazil": 3, "indonesia": 3}
const WING_AIRCRAFT := {"usa": "F/A-18E Super Hornet", "china": "J-15T", "france": "Rafale M", "italy": "F-35B Lightning", "uk": "F-35B Lightning", "india": "MiG-29K", "japan": "F-35B Lightning", "turkiye": "Bayraktar TB3", "iran": "Shahed-129", "russia": "Su-33", "brazil": "AF-1 Skyhawk", "indonesia": "Carrier Drone"}
## How far from the carrier its aircraft will fly to strike: far beyond the carrier's own guns (24 m), which only defend it.
const STRIKE_REACH := 420.0
const LAUNCH_EVERY := 3.0
const SORTIE := 240.0
const REARM := 14.0
const REPLACE_EVERY := 45.0    ## seconds for a replacement aircraft to arrive for one lost
const HOLD := 30.0             ## seconds an automatic wing stays down after Recall (an order sends it up at once)
const REPLACE_COST := 400.0    ## what the player pays for it (a rival's navy is not charged)

## The state lives on the world (a match's meta), so a new match starts clean.
static func state(w: Node) -> Dictionary:
	if not w.has_meta("war_tools"):
		w.set_meta("war_tools", {"fields": [], "support": {}, "t": 0.0, "next_id": 1})
	return w.get_meta("war_tools")

static func _base(key: String) -> String:
	return load("res://scripts/force_catalog.gd").base(key)

static func _alive(u: Dictionary) -> bool:
	return not u.dead and u.node != null and is_instance_valid(u.node)

## Every frame (world._physics_process, beside the medics).
static func update(w: Node, delta: float) -> void:
	var s := state(w)
	s.t = float(s.t) + delta
	if float(s.t) < TICK:
		return
	var dt: float = s.t
	s.t = 0.0
	var t_lap: int = w.clock()
	# The support units of each nation, by key, for the hot damage path.
	var support := {}
	for u in w.units:
		if not _alive(u) or not (u.key in ["counterBatteryRadar", "aewc", "ewJet", "maritimePatrol", "navalHelicopter", "supplyTruck"]):
			continue
		if u.get("fly", false) and str(u.get("air_state", "")) in ["parked", "rearming"]:
			continue   # on the ground at its airfield
		var o := int(u.owner)
		if not support.has(o): support[o] = {}
		if not support[o].has(u.key): support[o][u.key] = []
		support[o][u.key].append(u.node.position)
	s.support = support
	t_lap = w.lap("    wt support index", t_lap)
	for u in w.units:
		if not _alive(u) or w.disabled(u):
			continue
		var t_handler: int = w.clock()
		match u.key:
			"carrier": _air_wing(w, u, dt)
			"mineLayer": _engineer(w, s, u, dt)
			"mineClearer": _clear(w, s, u, dt)
			"recoveryVehicle": _repair(w, u, dt)
			"supplyTruck": _resupply_column(w, u, dt)
			"logisticsUGV": _evacuate(w, u, dt)
		if w.profiling and u.key in ["carrier", "mineLayer", "mineClearer", "recoveryVehicle", "logisticsUGV"]:
			w.spent("      wt " + str(u.key), t_handler)
	t_lap = w.lap("    wt unit tools", t_lap)
	_trigger(w, s)
	_reveal_enemy_mines(w, s)
	t_lap = w.lap("    wt minefields (%d)" % s.fields.size() if w.profiling else "", t_lap)
	preload("res://scripts/airlift.gd").update(w)   # troops boarding helicopters
	t_lap = w.lap("    wt airlift", t_lap)

# ---------------------------------------------------------------- minefields

static func _engineer(w: Node, s: Dictionary, u: Dictionary, dt: float) -> void:
	var at: Vector3 = u.node.position
	var last: Vector3 = u.get("tool_last", at)
	u.tool_last = at
	if at.distance_to(last) > 0.3 * dt * 4.0:
		u.tool_idle = 0.0
		return
	u.tool_idle = float(u.get("tool_idle", 0.0)) + dt
	if float(u.tool_idle) < LAY_AFTER or w.game_time < float(u.get("tool_ready", 0.0)):
		return
	var own: Array = s.fields.filter(func(f): return int(f.owner) == int(u.owner))
	if own.size() >= FIELDS_PER_NATION or own.any(func(f): return Vector2(f.at.x - at.x, f.at.z - at.z).length() < MINE_RADIUS * 1.5):
		return
	lay(w, int(u.owner), at)
	u.tool_ready = w.game_time + LAY_COOLDOWN

## A field of mines (`"at"` anti-vehicle or `"ap"` anti-personnel) at `at`, laid by `owner`.
static func lay(w: Node, owner: int, at: Vector3, kind := "at") -> Dictionary:
	var s := state(w)
	var charges := AP_MINE_CHARGES if kind == "ap" else MINE_CHARGES
	var f := {"id": int(s.next_id), "owner": owner, "at": at, "kind": kind, "charges": charges, "hits": {}, "clearing": 0.0, "mesh": null}
	s.next_id = int(s.next_id) + 1
	s.fields.append(f)
	_dress(w, f)
	if owner == 0 and w.hud != null:
		if kind == "ap":
			w.hud.notice("ENGINEERS: an anti-personnel minefield is laid. Enemy infantry that enters it will be struck.")
		else:
			w.hud.notice("ENGINEERS: a minefield is laid. Enemy vehicles that drive into it will be struck; infantry walks through anti-vehicle mines.")
	return f

static func _can_lay_mine(u: Dictionary) -> bool:
	return _alive(u) and not u.get("fly", false) and not u.get("naval", false) and (not u.get("vehicle", false) or str(u.get("key", "")) in ["mineLayer", "worker"])

## Orders selected engineers, workers or infantry to lay a minefield at `at` (with cost).
static func order_lay_mine(w: Node, selected: Array, at: Vector3, kind := "at") -> int:
	var layers := selected.filter(func(u): return int(u.owner) == 0 and _can_lay_mine(u))
	if layers.is_empty():
		if w.hud != null:
			w.hud.notice("Select infantry, workers or an Engineer Minelayer to lay a minefield.")
		return 0
	var s := state(w)
	var own: Array = s.fields.filter(func(f): return int(f.owner) == 0)
	if own.size() >= FIELDS_PER_NATION:
		if w.hud != null:
			w.hud.notice("Minefield limit reached (%d fields)." % FIELDS_PER_NATION)
		return 0
	if w.economy == null or float(w.economy.res.get("money", 0.0)) < MINE_COST:
		if w.hud != null:
			w.hud.notice("Need $%d to lay a minefield." % int(MINE_COST))
		return 0
	if w.height_at(at.x, at.z) < float(w.map.seaLevel) + 0.4:
		if w.hud != null:
			w.hud.notice("Minefields must be laid on dry land.")
		return 0
	w.economy.res.money -= MINE_COST
	lay(w, 0, at, kind)
	w.order_move(layers, at)
	return 1

## Orders a line of minefields from `start_pos` to `end_pos`.
static func order_mine_line(w: Node, selected: Array, start_pos: Vector3, end_pos: Vector3, kind := "at") -> int:
	var layers := selected.filter(func(u): return int(u.owner) == 0 and _can_lay_mine(u))
	if layers.is_empty():
		if w.hud != null:
			w.hud.notice("Select infantry, workers or an Engineer Minelayer to lay a minefield line.")
		return 0
	var s := state(w)
	var flat_a := Vector2(start_pos.x, start_pos.z)
	var flat_b := Vector2(end_pos.x, end_pos.z)
	var dist := flat_a.distance_to(flat_b)
	var spacing := MINE_RADIUS * 1.45
	var count := clampi(int(floorf(dist / spacing)) + 1, 1, 10)
	var placed := 0
	for i in range(count):
		var own_count: int = s.fields.filter(func(f): return int(f.owner) == 0).size()
		if own_count >= FIELDS_PER_NATION:
			break
		if w.economy == null or float(w.economy.res.get("money", 0.0)) < MINE_COST:
			if placed == 0 and w.hud != null:
				w.hud.notice("Need $%d per minefield." % int(MINE_COST))
			break
		var t := 0.0 if count == 1 else float(i) / float(count - 1)
		var p2 := flat_a.lerp(flat_b, t)
		var pos := Vector3(p2.x, w.height_at(p2.x, p2.y), p2.y)
		if pos.y < float(w.map.seaLevel) + 0.4:
			continue
		if s.fields.any(func(f): return int(f.owner) == 0 and Vector2(f.at.x - pos.x, f.at.z - pos.z).length() < MINE_RADIUS * 1.1):
			continue
		w.economy.res.money -= MINE_COST
		lay_quiet(w, 0, pos, kind)
		placed += 1
	if placed > 0:
		w.order_move(layers, end_pos)
		if w.hud != null:
			w.hud.notice("ENGINEERS: laid %d %s minefields in a line." % [placed, "anti-personnel" if kind == "ap" else "anti-tank"])
	return placed

## True if any unit in `selected` is within `radius` of a friendly minefield.
static func has_own_mines_near(w: Node, selected: Array, radius := 16.0) -> bool:
	var s := state(w)
	for u in selected:
		if not _alive(u):
			continue
		for f in s.fields:
			if int(f.owner) == int(u.owner) and Vector2(f.at.x - u.node.position.x, f.at.z - u.node.position.z).length() <= radius:
				return true
	return false

## Clears friendly minefields near `selected` and refunds 50% of their cost.
static func clear_own_mines_near(w: Node, selected: Array, radius := 16.0) -> int:
	var s := state(w)
	var removed := 0
	for f in s.fields.duplicate():
		for u in selected:
			if _alive(u) and int(u.owner) == int(f.owner) and Vector2(f.at.x - u.node.position.x, f.at.z - u.node.position.z).length() <= radius:
				_remove(s, f)
				removed += 1
				break
	if removed > 0 and w.economy != null:
		w.economy.res.money = float(w.economy.res.get("money", 0.0)) + removed * MINE_COST * 0.5
	if removed > 0 and w.hud != null:
		w.hud.notice("Cleared %d friendly minefield(s) (+$%d refunded)." % [removed, roundi(removed * MINE_COST * 0.5)])
	return removed

static func clear_own_mines_at(w: Node, at: Vector3, owner := 0, radius := 8.0) -> int:
	var s := state(w)
	var removed := 0
	for f in s.fields.duplicate():
		if int(f.owner) == owner and Vector2(f.at.x - at.x, f.at.z - at.z).length() <= radius:
			_remove(s, f)
			removed += 1
	if removed > 0 and w.economy != null:
		w.economy.res.money = float(w.economy.res.get("money", 0.0)) + removed * MINE_COST * 0.5
	if removed > 0 and w.hud != null:
		w.hud.notice("Cleared %d friendly minefield(s) (+$%d refunded)." % [removed, roundi(removed * MINE_COST * 0.5)])
	return removed

## The owner sees its own fields as a terrain-conforming disc + visible mine markers; the enemy sees nothing.
static func _dress(w: Node, f: Dictionary) -> void:
	if int(f.owner) != 0 and not f.get("revealed", false):
		return
	var root := Node3D.new()
	var y: float = w.height_at(float(f.at.x), float(f.at.z)) if w.has_method("height_at") else float(f.at.y)
	root.position = Vector3(f.at.x, y, f.at.z)
	var is_ap := str(f.get("kind", "at")) == "ap"
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MINE_RADIUS
	disc.bottom_radius = MINE_RADIUS
	disc.height = 0.08
	disc.radial_segments = 24
	mi.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.92, 0.32, 0.18, 0.28) if is_ap else Color(0.90, 0.72, 0.18, 0.26)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.28, 0)
	root.add_child(mi)
	var casing_mat := StandardMaterial3D.new()
	casing_mat.albedo_color = Color("5a3828") if is_ap else Color("3b4432")
	casing_mat.roughness = 0.85
	var cap_mat := StandardMaterial3D.new()
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.albedo_color = Color("e84a27") if is_ap else Color("e6b422")
	var offsets := [Vector2.ZERO, Vector2(3.6, 0.0), Vector2(-3.6, 0.0), Vector2(1.8, 3.1), Vector2(-1.8, 3.1), Vector2(1.8, -3.1), Vector2(-1.8, -3.1)]
	for off in offsets:
		var wx: float = float(f.at.x) + off.x
		var wz: float = float(f.at.z) + off.y
		var wy: float = w.height_at(wx, wz) if w.has_method("height_at") else y
		var puck := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34 if is_ap else 0.48
		cyl.bottom_radius = 0.38 if is_ap else 0.54
		cyl.height = 0.18
		cyl.radial_segments = 12
		puck.mesh = cyl
		puck.material_override = casing_mat
		puck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puck.position = Vector3(off.x, wy - y + 0.12, off.y)
		root.add_child(puck)
		var fuse := MeshInstance3D.new()
		var fmesh := CylinderMesh.new()
		fmesh.top_radius = 0.14
		fmesh.bottom_radius = 0.14
		fmesh.height = 0.08
		fmesh.radial_segments = 8
		fuse.mesh = fmesh
		fuse.material_override = cap_mat
		fuse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fuse.position = Vector3(off.x, wy - y + 0.23, off.y)
		root.add_child(fuse)
	w.add_child(root)
	f.mesh = root

static func _remove(s: Dictionary, f: Dictionary) -> void:
	s.fields.erase(f)
	if f.mesh != null and is_instance_valid(f.mesh):
		f.mesh.queue_free()

## Enemy units in a matching minefield are struck, crippled, and slowed.
static func _trigger(w: Node, s: Dictionary) -> void:
	if s.fields.is_empty():
		return
	for f in s.fields.duplicate():
		var o := int(f.owner)
		var kind := str(f.get("kind", "at"))
		for u in w.units:
			if not _alive(u) or u.get("fly", false) or u.get("naval", false) or int(u.owner) == o:
				continue
			if kind == "ap":
				if u.get("vehicle", false):
					continue
			else:
				if not u.get("vehicle", false):
					continue
			if not w.hostile(o, int(u.owner)):
				continue
			var p: Vector3 = u.node.position
			if Vector2(p.x - f.at.x, p.z - f.at.z).length() > MINE_RADIUS:
				continue
			var key := str(u.node.get_instance_id())
			if w.game_time < float(f.hits.get(key, -10.0)) + 1.8:
				continue
			f.hits[key] = w.game_time
			var dmg := AP_MINE_DAMAGE if kind == "ap" else MINE_DAMAGE
			w.damage(u, dmg, {"owner": o, "key": "mine", "dead": true, "covert": true})
			u.cur_speed = 0.0
			u.mine_slow_until = w.game_time + (3.5 if kind == "ap" else 4.5)
			# Blast shrapnel hits nearby comrades in the same squad/column
			for other in w.units:
				if other == u or not _alive(other) or other.get("fly", false) or other.get("naval", false) or not w.hostile(o, int(other.owner)):
					continue
				if kind == "ap" and other.get("vehicle", false):
					continue
				if Vector2(other.node.position.x - p.x, other.node.position.z - p.z).length() <= 4.5:
					w.damage(other, dmg * 0.45, {"owner": o, "key": "mine", "dead": true, "covert": true})
					other.mine_slow_until = w.game_time + 2.5
			if w.get("effects") != null:
				w.effects.explosion(p + Vector3.UP * 0.5, 1.2 if kind == "ap" else 1.8, true)
			f.charges = int(f.charges) - 1
			if int(u.owner) == 0 and w.hud != null:
				w.hud.notice("MINES: your %s ran into an enemy minefield." % str(w.unit_defs.get(u.key, {}).get("name", u.key)), p)
			elif o == 0 and w.hud != null:
				w.hud.notice("MINES: enemy %s struck your minefield." % str(w.unit_defs.get(u.key, {}).get("name", u.key)), p)
			if int(f.charges) <= 0:
				_remove(s, f)
				break

static func _clear(w: Node, s: Dictionary, u: Dictionary, dt: float) -> void:
	var at: Vector3 = u.node.position
	if w.get("fortifications") != null and w.fortifications != null:
		w.fortifications.breach_near(u, dt)
	for f in s.fields.duplicate():
		if int(f.owner) == int(u.owner) or not w.hostile(int(u.owner), int(f.owner)):
			continue
		if Vector2(f.at.x - at.x, f.at.z - at.z).length() > CLEAR_REACH:
			continue
		f.clearing = float(f.clearing) + dt
		if float(f.clearing) >= CLEAR_TIME:
			_remove(s, f)
			if w.get("effects") != null:
				w.effects.explosion(Vector3(f.at.x, at.y, f.at.z) + Vector3.UP, 2.2, true)
			if int(u.owner) == 0 and w.hud != null:
				w.hud.notice("ENGINEERS: a line charge cleared an enemy minefield.", f.at)
			elif int(f.owner) == 0 and w.hud != null:
				w.hud.notice("MINES: the enemy cleared one of your minefields.", f.at)

## Reveals enemy minefields to the player when mine clearers or scouts approach.
static func _reveal_enemy_mines(w: Node, s: Dictionary) -> void:
	if s.fields.is_empty():
		return
	var eyes: Array = []
	for f in s.fields:
		if int(f.owner) == 0 or f.get("revealed", false):
			continue
		if eyes.is_empty():
			eyes = w.units.filter(func(u): return _alive(u) and int(u.owner) == 0 and u.key in ["mineClearer", "scoutTeam", "reconVehicle"])
			if eyes.is_empty():
				return
		for u in eyes:
			if Vector2(u.node.position.x - f.at.x, u.node.position.z - f.at.z).length() < CLEAR_REACH * 1.2:
				f.revealed = true
				_dress(w, f)
				break

## Fields `owner` may see: its own, and enemy fields its clearers or scouts are near.
static func visible_fields(w: Node, owner: int) -> Array:
	var s := state(w)
	var eyes: Array = w.units.filter(func(u): return _alive(u) and int(u.owner) == owner and u.key in ["mineClearer", "scoutTeam", "reconVehicle"])
	return s.fields.filter(func(f): return int(f.owner) == owner or eyes.any(func(u): return Vector2(u.node.position.x - f.at.x, u.node.position.z - f.at.z).length() < CLEAR_REACH * 1.2))

# ---------------------------------------------------------------- recovery

static func _repair(w: Node, u: Dictionary, dt: float) -> void:
	var worst = null
	var share := 0.999
	for other in w.units:
		# Most of the army is unhurt: the cheap tests that rule a unit out come first (this runs for every
		# recovery vehicle against every unit, four times a second).
		if float(other.hp) >= float(other.max_hp) * 0.999 or other == u or int(other.owner) != int(u.owner):
			continue
		if not other.get("vehicle", false) or other.get("fly", false) or other.get("naval", false) or not _alive(other):
			continue
		var s: float = float(other.hp) / maxf(float(other.max_hp), 1.0)
		if s < share and other.node.position.distance_to(u.node.position) < REPAIR_REACH:
			share = s
			worst = other
	if worst != null:
		worst.hp = minf(float(worst.max_hp), float(worst.hp) + REPAIR_RATE * dt)
		u.recovering = worst   # (not "repairing": that is the repair order a save keeps)

## A logistics robot brings the wounded back: the worst-hurt infantry near it recovers.
static func _evacuate(w: Node, u: Dictionary, dt: float) -> void:
	var worst = null
	var share := 0.999
	for other in w.units:
		if float(other.hp) >= float(other.max_hp) * 0.999 or other == u or int(other.owner) != int(u.owner):
			continue
		if not other.key in w.infantry_keys or other.key == "worker" or not _alive(other):
			continue
		var s: float = float(other.hp) / maxf(float(other.max_hp), 1.0)
		if s < share and other.node.position.distance_to(u.node.position) < EVAC_REACH:
			share = s
			worst = other
	if worst != null:
		worst.hp = minf(float(worst.max_hp), float(worst.hp) + EVAC_RATE * dt)

const SUPPLY_REACH := 28.0
const SUPPLY_RESERVE_MAX := 120.0

static func _resupply_column(w: Node, u: Dictionary, dt: float) -> void:
	if not u.has("supply_reserve"):
		u.supply_reserve = SUPPLY_RESERVE_MAX
	var at: Vector3 = u.node.position
	var o := int(u.owner)
	# Recharge onboard reserve when near a supplied friendly depot, HQ or city centre.
	for b in w.buildings:
		if b.dead or not b.built or int(b.owner) != o:
			continue
		if b.key in ["warehouse", "ammoDepot", "hq", "cityCenter"] and b.get("supplied", true):
			if Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length() <= 34.0:
				u.supply_reserve = minf(SUPPLY_RESERVE_MAX, float(u.supply_reserve) + 14.0 * dt)
				break
	# Clear operating shortages and slowly reload mobile launchers nearby.
	for other in w.units:
		if other == u or other.dead or int(other.owner) != o or not _alive(other):
			continue
		if Vector2(other.node.position.x - at.x, other.node.position.z - at.z).length() > SUPPLY_REACH:
			continue
		if str(other.get("operating_shortage", "")) != "" and float(u.get("supply_reserve", 0.0)) > 1.0:
			other.operating_shortage = ""
		if other.has("ammo") and not other.get("fly", false) and float(u.get("supply_reserve", 0.0)) >= 6.0:
			var max_ammo := int(other.get("max_ammo", 4))
			if int(other.ammo) < max_ammo:
				other.rearm_prog = float(other.get("rearm_prog", 0.0)) + dt
				if float(other.rearm_prog) >= 16.0:
					other.rearm_prog = 0.0
					other.ammo = int(other.ammo) + 1
					u.supply_reserve = maxf(0.0, float(u.supply_reserve) - 6.0)

static func near_supply_truck(w: Node, owner: int, pos: Vector3, reach := SUPPLY_REACH) -> bool:
	var s := state(w)
	if _near(s, owner, "supplyTruck", pos, reach):
		return true
	var raw_tick = w.get("sim_tick")
	var tick: int = int(raw_tick) if raw_tick != null else -1
	var ucount: int = w.units.size()
	if int(s.get("truck_tick", -2)) != tick or int(s.get("truck_ucount", -1)) != ucount:
		s["truck_tick"] = tick
		s["truck_ucount"] = ucount
		var by_owner := {}
		for u in w.units:
			if not u.dead and str(u.get("key", "")) == "supplyTruck" and u.get("node") != null and is_instance_valid(u.node):
				var o := int(u.owner)
				if not by_owner.has(o): by_owner[o] = []
				by_owner[o].append(u.node.position)
		s["truck_cache"] = by_owner
	var cache: Dictionary = s.get("truck_cache", {})
	if cache.is_empty() or not cache.has(owner):
		return false
	for p in cache[owner]:
		if Vector2(p.x - pos.x, p.z - pos.z).length() <= reach:
			return true
	return false

static func consume_truck_reserve(w: Node, owner: int, pos: Vector3, amount: float) -> bool:
	for u in w.units:
		if u.dead or int(u.owner) != owner or str(u.get("key", "")) != "supplyTruck" or not _alive(u):
			continue
		if Vector2(u.node.position.x - pos.x, u.node.position.z - pos.z).length() <= SUPPLY_REACH:
			var res := float(u.get("supply_reserve", SUPPLY_RESERVE_MAX))
			if res >= amount:
				u.supply_reserve = res - amount
				return true
	return false

# ---------------------------------------------------------------- sensors and damage

static func _near(s: Dictionary, owner: int, key: String, at: Vector3, reach: float) -> bool:
	for p in s.support.get(owner, {}).get(key, []):
		if Vector2(p.x - at.x, p.z - at.z).length() <= reach:
			return true
	return false

## A factor on `source`'s shot at `target` (world.damage).
static func damage_mult(w: Node, source: Dictionary, target: Dictionary) -> float:
	if not source.has("owner") or not source.has("key"):
		return 1.0
	var s := state(w)
	var f := 1.0
	var o := int(source.owner)
	var skey := str(source.key)
	var tkey := str(target.get("key", ""))
	# Submarine hunters.
	if skey in SUB_HUNTERS and (tkey in SUBMARINES or _base(tkey) in SUBMARINES):
		f *= SUB_FACTOR
	if s.support.is_empty() or target.get("node") == null:
		return f
	var at: Vector3 = target.node.position
	# Counter-battery radar: guns it has found are hit harder.
	if (tkey in GUNS or _base(tkey) in GUNS) and _near(s, o, "counterBatteryRadar", at, RADAR_REACH):
		f *= 1.0 + RADAR_BONUS
	var shooter = source.get("node")
	if shooter != null and is_instance_valid(shooter):
		var from: Vector3 = shooter.position
		# Airborne early warning: your aircraft under its picture hit harder.
		if source.get("fly", false) and _near(s, o, "aewc", from, AEW_REACH):
			f *= 1.0 + AEW_BONUS
		# Electronic attack: an air defence near the target's jammer loses its aim.
		if (skey in AIR_DEFENCE or _base(skey) in AIR_DEFENCE) and int(target.get("owner", -1)) >= 0 and _near(s, int(target.owner), "ewJet", from, JAM_REACH):
			f *= JAM_FACTOR
	return f

static func is_submarine(thing: Dictionary) -> bool:
	if thing.get("is_building", false):
		return false
	var key := str(thing.get("key", ""))
	return key in SUBMARINES or _base(key) in SUBMARINES

## True when a submerged submarine `sub` can be detected by `viewer_owner`:
## only when it recently fired/launched, or an ASW sonar unit is in range, or a ship is at point-blank periscope range.
static func submarine_detected(w: Node, viewer_owner: int, sub: Dictionary) -> bool:
	if sub.get("node") == null or not is_instance_valid(sub.node):
		return false
	var sub_owner := int(sub.get("owner", -1))
	if sub_owner == viewer_owner or (w.get("diplomacy") != null and w.diplomacy.allied(viewer_owner, sub_owner)):
		return true
	if w.game_time - float(sub.get("last_fire", -99.0)) < 3.0:
		return true
	var at: Vector3 = sub.node.position
	var s := state(w)
	if _near(s, viewer_owner, "maritimePatrol", at, 90.0) or _near(s, viewer_owner, "navalHelicopter", at, 65.0):
		return true
	for u in w.units:
		if not _alive(u):
			continue
		var uo := int(u.owner)
		if uo != viewer_owner and not (w.get("diplomacy") != null and w.diplomacy.allied(viewer_owner, uo)):
			continue
		var ukey := str(u.get("key", ""))
		var bkey := _base(ukey)
		var d := Vector2(u.node.position.x - at.x, u.node.position.z - at.z).length()
		if ukey in ["maritimePatrol", "asFrigate"] or bkey in ["maritimePatrol", "asFrigate"]:
			if d <= 85.0:
				return true
		elif ukey in ASW_CAPABLE:
			var sonar_r := 62.0
			if d <= sonar_r:
				return true
		elif d <= 8.0:
			return true
	return false

## Whether `thing` (an enemy of `owner`) is found by `owner`'s sensors (fog_of_war.visible).
static func sensed(w: Node, owner: int, thing: Dictionary) -> bool:
	if is_submarine(thing):
		return submarine_detected(w, owner, thing)
	var s := state(w)
	if s.support.get(owner, {}).is_empty() or thing.get("node") == null:
		return false
	var at: Vector3 = thing.node.position
	var key := str(thing.get("key", ""))
	if (key in GUNS or _base(key) in GUNS) and _near(s, owner, "counterBatteryRadar", at, RADAR_REACH):
		return true
	if (thing.get("fly", false) or thing.get("naval", false)) and _near(s, owner, "aewc", at, AEW_REACH):
		return true
	return false

## Whether `attacker` may engage `target` at all (force_catalog.can_target).
static func can_target(attacker: Dictionary, target: Dictionary) -> bool:
	var key := str(attacker.get("key", ""))
	if key in NAVAL_ONLY and not target.get("naval", false):
		return false
	if is_submarine(target):
		return key in ASW_CAPABLE
	return true

# ---------------------------------------------------------------- saves

static func capture(w: Node) -> Dictionary:
	var s := state(w)
	return {"fields": s.fields.map(func(f): return {"owner": int(f.owner), "x": float(f.at.x), "y": float(f.at.y), "z": float(f.at.z), "kind": str(f.get("kind", "at")), "charges": int(f.charges)})}

static func restore(w: Node, data: Dictionary) -> void:
	var s := state(w)
	for f in s.fields.duplicate():
		_remove(s, f)
	for d in data.get("fields", []):
		var kind := str(d.get("kind", "at"))
		var f := lay_quiet(w, int(d.get("owner", 0)), Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0))), kind)
		var max_c := AP_MINE_CHARGES if kind == "ap" else MINE_CHARGES
		f.charges = clampi(int(d.get("charges", max_c)), 1, max_c)

static func lay_quiet(w: Node, owner: int, at: Vector3, kind := "at") -> Dictionary:
	var s := state(w)
	var charges := AP_MINE_CHARGES if kind == "ap" else MINE_CHARGES
	var f := {"id": int(s.next_id), "owner": owner, "at": at, "kind": kind, "charges": charges, "hits": {}, "clearing": 0.0, "mesh": null}
	s.next_id = int(s.next_id) + 1
	s.fields.append(f)
	_dress(w, f)
	return f

# ---------------------------------------------------------------- the air wing

static func _id(w: Node, owner: int) -> String:
	return str(w.map.nations[owner].get("id", "")) if owner >= 0 and owner < w.map.nations.size() else ""

## The unit definitions of the aircraft a carrier launches (force_catalog.apply):
## never trained anywhere, they exist only aboard a carrier.
static func apply(w: Node) -> void:
	var jet: Dictionary = w.unit_defs.get("jet", {}).duplicate(true)
	jet.merge({"name": WING_AIRCRAFT.get(_id(w, 0), "Carrier Fighter"), "generic": "Carrier Fighter", "hp": 190, "dmg": 62, "range": 26, "cooldown": 2.6, "aggro": 40, "speed": 34, "cost": {}, "fly": true, "naval": false,
		"desc": "A fighter of a carrier's air wing: it takes off from the deck against a target, strikes, and flies back to land and rearm."}, true)
	jet.erase("nation")
	w.unit_defs.carrierJet = jet
	var drone: Dictionary = jet.duplicate(true)
	drone.merge({"name": WING_AIRCRAFT.get(_id(w, 0), "Carrier Drone") if _id(w, 0) in ["turkiye", "iran"] else "Carrier Drone", "generic": "Carrier Drone", "hp": 120, "dmg": 48, "speed": 26,
		"desc": "An armed drone of a drone carrier's wing: it takes off from the deck, strikes, and flies back to land and rearm."}, true)
	w.unit_defs.carrierDrone = drone
	for key in ["carrierJet", "carrierDrone"]:
		if w.get("damage_profile") != null:
			w.damage_profile[key] = {"infantry": 1.0, "light": 1.3, "armor": 1.2, "air": 0.9, "naval": 1.5, "building": 1.3}

## How far off a carrier ordered to attack stands from its target: inside its air wing's reach, never closer. It
## does not sail up to the enemy to use its own guns (they only defend it); with its aircraft gone it waits for
## replacements (REPLACE_EVERY) rather than steam into range of what it cannot fight.
static func standoff(_w: Node, _carrier: Dictionary) -> float:
	return STRIKE_REACH * 0.85

static func wing_size(w: Node, carrier: Dictionary) -> int:
	return int(WING.get(_id(w, int(carrier.owner)), 4))

## The air wing in numbers: size, aboard, flying, rearming, lost (waiting for a replacement), auto.
static func wing_info(w: Node, carrier: Dictionary) -> Dictionary:
	var wing := _wing(w, carrier)
	var flying := 0
	for u in w.units:
		if not u.dead and is_same(u.get("carrier"), carrier):
			flying += 1
	var size := wing_size(w, carrier)
	var rearming: int = (wing.rearming as Array).size()
	return {"size": size, "aboard": int(wing.aboard), "flying": flying, "rearming": rearming,
		"lost": maxi(0, size - int(wing.aboard) - flying - rearming), "auto": bool(wing.get("auto", true)), "replace_in": float(wing.get("replace_in", 0.0))}

## Words for the selection panel: what the wing is doing and how to use it.
static func wing_text(w: Node, carrier: Dictionary) -> String:
	var i := wing_info(w, carrier)
	var line := "%d on deck  ·  %d flying  ·  %d rearming" % [i.aboard, i.flying, i.rearming]
	if i.lost > 0:
		line += "  ·  %d lost (a replacement in %ds, $%d)" % [i.lost, ceili(float(i.replace_in)), int(REPLACE_COST)]
	var held: float = float(_wing(w, carrier).get("hold_until", 0.0)) - float(w.game_time)
	if held > 0.0:
		line += "  ·  held down for %ds" % ceili(held)
	return line

## Orders-only or automatic: automatic launches at the nearest enemy in reach; orders-only only at what you point at.
static func set_auto(carrier: Dictionary, on: bool) -> void:
	carrier.wing = carrier.get("wing", {"aboard": 0, "rearming": [], "next": 0.0})
	carrier.wing.auto = on

## Every aircraft of the wing breaks off and returns to the deck.
static func recall(w: Node, carrier: Dictionary) -> int:
	var n := 0
	carrier.enemy = null
	_wing(w, carrier).hold_until = w.game_time + HOLD   # (in automatic mode too: nothing goes up again at once)
	for u in w.units:
		if not u.dead and is_same(u.get("carrier"), carrier):
			u.air_state = "returning"
			u.enemy = null
			u.air_state = "returning"
			n += 1
	return n

## A carrier aboard which `n` aircraft wait; set up the first time it is seen.
static func _wing(w: Node, carrier: Dictionary) -> Dictionary:
	if not carrier.has("wing"):
		carrier.wing = {"aboard": wing_size(w, carrier), "rearming": [], "next": 0.0, "auto": true, "replace_in": REPLACE_EVERY}
	return carrier.wing

## What the carrier's aircraft go after: its own order, or the nearest enemy
## the nation can see within reach (ships first).
static func _strike_target(w: Node, carrier: Dictionary) -> Variant:
	var ordered = carrier.get("enemy")
	if ordered != null and not ordered.dead:
		var op: Vector3 = ordered.root.position if ordered.get("is_building", false) else ordered.node.position
		return ordered if Vector2(op.x - carrier.node.position.x, op.z - carrier.node.position.z).length() <= STRIKE_REACH else null   # (out of reach: the carrier is closing)
	if not bool(_wing(w, carrier).get("auto", true)):
		return null   # orders only: nothing goes up unless you point at something
	var o := int(carrier.owner)
	var at: Vector3 = carrier.node.position
	var best = null
	var score := INF
	# Distance first (a number), then who and what (dictionary lookups and strings): most of the world is out of reach.
	for pool in [w.units, w.buildings]:
		for e in pool:
			if e.dead:
				continue
			var p: Vector3 = e.node.position if not e.get("is_building", false) else e.root.position
			var d := Vector2(p.x - at.x, p.z - at.z).length()
			if d > STRIKE_REACH:
				continue
			if int(e.owner) == o or int(e.owner) < 0 or not w.hostile(o, int(e.owner)):
				continue
			if str(e.get("key", "")) in SUBMARINES or _base(str(e.get("key", ""))) in SUBMARINES:
				continue
			if o == 0 and w.get("fog") != null and w.fog.enabled and not w.fog.shows(e):
				continue
			var weight := d * (0.6 if e.get("naval", false) else 1.0)
			if weight < score:
				score = weight
				best = e
	return best

static func _air_wing(w: Node, carrier: Dictionary, dt: float) -> void:
	var wing := _wing(w, carrier)
	# Aircraft back from a sortie are rearmed below decks before they fly again.
	for t in wing.rearming.duplicate():
		if w.game_time >= float(t):
			wing.rearming.erase(t)
			wing.aboard = int(wing.aboard) + 1
	# A lost aircraft is replaced, one at a time, while the carrier lives (the player pays; a rival's navy is not charged).
	# How many of the wing are flying is a walk over every unit: once a second is often enough for the replacement clock.
	if w.game_time - float(wing.get("info_time", -9.0)) >= 1.0 or not wing.has("info_cache") or int(wing.aboard) != int(wing.get("info_aboard", -1)) or wing.rearming.size() != int(wing.get("info_rearming", -1)):
		wing.info_cache = wing_info(w, carrier)
		wing.info_time = w.game_time
		wing.info_aboard = int(wing.aboard)
		wing.info_rearming = wing.rearming.size()
	var info: Dictionary = wing.info_cache
	if int(info.lost) > 0:
		wing.replace_in = float(wing.get("replace_in", REPLACE_EVERY)) - dt
		if float(wing.replace_in) <= 0.0:
			var owner := int(carrier.owner)
			if owner != 0 or w.economy.pay({"money": REPLACE_COST}):
				wing.aboard = int(wing.aboard) + 1
				wing.replace_in = REPLACE_EVERY
				if owner == 0 and w.hud != null:
					w.hud.notice("CARRIER: a replacement aircraft has arrived ($%d). %d on deck." % [int(REPLACE_COST), int(wing.aboard)], carrier.node.position)
			else:
				wing.replace_in = 10.0   # no money: try again in ten seconds
				if not carrier.get("replace_told", false):
					carrier.replace_told = true
					w.hud.notice("CARRIER: no money for a replacement aircraft ($%d)." % int(REPLACE_COST), carrier.node.position)
	else:
		wing.replace_in = REPLACE_EVERY
	_show_deck(carrier, int(wing.aboard))
	wing.next = float(wing.next) - dt
	if int(wing.aboard) <= 0 or float(wing.next) > 0.0:
		return
	if w.game_time < float(wing.get("hold_until", 0.0)) and carrier.get("enemy") == null:
		return
	var target = _strike_target(w, carrier)
	if target == null:
		wing.next = 0.75   # nothing in reach: the search walks every unit and building, so look again in a moment, not next tick
		return
	wing.next = LAUNCH_EVERY
	wing.aboard = int(wing.aboard) - 1
	var key := "carrierDrone" if _id(w, int(carrier.owner)) in ["turkiye", "iran"] else "carrierJet"
	var deck: Vector3 = carrier.node.position + Basis(Vector3.UP, float(carrier.get("heading", 0.0))) * Vector3(0, 3.0, 9.0)
	var plane: Dictionary = w.spawn_unit(key, deck, int(carrier.owner))
	if plane.is_empty():
		wing.aboard = int(wing.aboard) + 1
		return
	plane.carrier = carrier
	plane.air_state = "ready"
	plane.heading = float(carrier.get("heading", 0.0))
	plane.ammo = 2
	plane.sortie_left = SORTIE
	plane.enemy = target
	plane.target = null
	if int(carrier.owner) == 0 and w.hud != null and not carrier.get("wing_told", false):
		carrier.wing_told = true
		w.hud.notice("CARRIER: your air wing is launching against targets within %d m. Aircraft land back aboard to rearm; select the carrier to see the wing, recall it or set it to orders only." % int(STRIKE_REACH), carrier.node.position)

## Deck aircraft shown while aboard (force_models._deck_planes).
static func _show_deck(carrier: Dictionary, aboard: int) -> void:
	if not carrier.has("deck_planes"):
		var found := []
		var i := 0
		while true:
			var n = carrier.node.find_child("DeckPlane%d" % i, true, false)
			if n == null: break
			found.append(n)
			i += 1
		carrier.deck_planes = found
	var planes: Array = carrier.deck_planes
	for i in range(planes.size()):
		if is_instance_valid(planes[i]):
			planes[i].visible = i < aboard

## A carrier's aircraft in flight (air_operations.update hands it here). True
## means this owns its movement. A plane whose carrier is gone looks for an
## airfield like any other.
static func recovery_point(carrier: Dictionary, u: Dictionary, from: Vector3) -> Vector3:
	var deck: Vector3 = carrier.node.position
	if not carrier.get("moving", false):
		return deck
	var travel := minf(30.0, deck.distance_to(from) / maxf(1.0, float(u.speed)))
	var course := Basis(Vector3.UP, float(carrier.heading)) * Vector3.BACK
	var advance := travel * float(carrier.get("cur_speed", carrier.speed))
	if carrier.get("target") != null:
		advance = minf(advance, deck.distance_to(carrier.target))
	return deck + course * advance

static func carrier_flight(w: Node, u: Dictionary, delta: float) -> bool:
	var carrier = u.get("carrier")
	if carrier == null or carrier.dead or carrier.owner != u.owner:
		u.carrier = null
		u.air_state = "returning"
		u.had_base = true
		return false
	u.sortie_left = float(u.get("sortie_left", SORTIE)) - delta
	if u.sortie_left <= 0.0:
		w.kill(u)
		return true
	if u.air_state == "ready":
		var enemy = u.get("enemy")
		var point: Vector3 = enemy.node.position if enemy != null and not enemy.dead else u.get("target", null) if u.get("target") != null else u.node.position
		var Air = load("res://scripts/air_operations.gd")
		var returning: bool = Air.mission_blocked(w, u, point, 4.0, float(u.range) * 0.75) != ""
		if (enemy == null or enemy.dead) and u.get("target") == null:
			u.idle_air = float(u.get("idle_air", 0.0)) + delta
		else:
			u.idle_air = 0.0
		if returning or int(u.get("ammo", 1)) <= 0 or float(u.idle_air) > 4.0:
			u.air_state = "returning"
		else:
			return false
	# Home to the deck: fly straight to the carrier and land.
	u.enemy = null
	u.target = null
	var deck: Vector3 = carrier.node.position
	var at: Vector3 = u.node.position
	var flat := Vector2(deck.x - at.x, deck.z - at.z)
	if flat.length() < 6.0:
		_recover(w, carrier, u)
		return true
	var step := minf(flat.length(), float(u.get("speed", 30.0)) * delta)
	var dir := flat.normalized()
	u.node.position += Vector3(dir.x, 0, dir.y) * step
	u.heading = atan2(dir.x, dir.y)
	u.node.rotation.y = u.heading
	u.moving = true
	return true

## Landed aboard: off the map (no wreck, no loss) and into the hangar to rearm.
static func _recover(w: Node, carrier: Dictionary, u: Dictionary) -> void:
	var wing := _wing(w, carrier)
	wing.rearming.append(w.game_time + REARM)
	preload("res://scripts/future_weapons.gd").stow(w, u)

# ---------------------------------------------------------------- rival navies

## How much of a rival's effort goes to its fleet, by its real navy: the blue-water
## navies first, coastal forces least (native/WAR-TOOLS-RESEARCH-2026-10-12.md).
const NAVY := {"usa": 1.0, "china": 1.0, "uk": 0.7, "france": 0.7, "germany": 0.4, "italy": 0.5, "netherlands": 0.35, "japan": 0.7, "russia": 0.6, "india": 0.6, "south_korea": 0.6,
	"turkiye": 0.5, "iran": 0.45, "australia": 0.45, "egypt": 0.4, "indonesia": 0.4, "israel": 0.35, "pakistan": 0.35, "saudi": 0.35,
	"brazil": 0.35, "north_korea": 0.3, "ukraine": 0.2, "houthis": 0.15, "yemen": 0.1, "nigeria": 0.2, "iraq": 0.05}

static func navy(w: Node, owner: int) -> float:
	return float(NAVY.get(_id(w, owner), 0.1))

## A rival choosing what to train (ai.gd): a nation with a real navy keeps a fleet
## in proportion to it, and favours warships while it is short of one.
static func ai_pick(w: Node, owner: int, options: Array) -> String:
	# A rival whose army must cross water raises landing ships first (ai_navy.gd).
	if "landingShip" in options and preload("res://scripts/ai_navy.gd").wants_transport(w, owner) and randf() < 0.6:
		return "landingShip"
	options = options.filter(func(k): return k != "landingShip")
	var ships: Array = options.filter(func(k): return w.unit_defs.get(k, {}).get("naval", false))
	if not ships.is_empty():
		var fleet := 0
		for u in w.units:
			if not u.dead and int(u.owner) == owner and u.get("naval", false) and u.key != "landingShip": fleet += 1
		var wanted := roundi(2.0 + 10.0 * navy(w, owner))
		if fleet < wanted and randf() < 0.25 + 0.6 * navy(w, owner):
			# The big ships too, once a nation can build them.
			var capital: Array = ships.filter(func(k): return k in ["carrier", "destroyer", "aegisCruiser", "type45", "asFrigate", "nuclearSub", "submarine"])
			if not capital.is_empty() and randf() < 0.5:
				return capital[randi() % capital.size()]
			return ships[randi() % ships.size()]
	return options[randi() % options.size()]
