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
##   carrier              a flagship whose air wing strikes far; it cannot
##                        hunt submarines
##   asFrigate            an escort built to hunt submarines
## All figures are game balance.

const VEHICLES := ["mineLayer", "mineClearer", "recoveryVehicle", "decoy", "counterBatteryRadar", "coastalASM"]
const AIR := ["aewc", "ewJet", "maritimePatrol"]
const FIXED_WING := ["aewc", "ewJet", "maritimePatrol"]
const NAVAL := ["carrier", "asFrigate"]
const ALTITUDE := {"aewc": 32.0, "ewJet": 27.0, "maritimePatrol": 21.0}
const SHIP_LENGTH := {"carrier": 24.0, "asFrigate": 13.0}
const WEAPON := {"coastalASM": "missile", "asFrigate": "missile", "carrier": "missile", "maritimePatrol": "missile", "ewJet": "missile", "mineClearer": "rocket"}
const NAVAL_ONLY := ["coastalASM", "maritimePatrol"]
const SUBMARINES := ["submarine", "nuclearSub", "orca"]
const SUB_HUNTERS := ["maritimePatrol", "asFrigate"]
const GUNS := ["artillery", "mlrs", "himars", "k9", "heavyRocket", "tos1a", "towedHowitzer", "wheeledHowitzer", "mortarTeam"]
const AIR_DEFENCE := ["samLauncher", "aaVehicle", "shortRangeSAM", "laserAD", "irisT", "manpads", "abmLauncher", "saudiThaad", "aegisCruiser", "type45"]

const MINE_RADIUS := 9.0
const MINE_CHARGES := 4
const MINE_DAMAGE := 150.0
const LAY_AFTER := 6.0       # seconds halted before an engineer lays a field
const LAY_COOLDOWN := 45.0
const FIELDS_PER_NATION := 12
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
	# The support units of each nation, by key, for the hot damage path.
	var support := {}
	for u in w.units:
		if not _alive(u) or not (u.key in ["counterBatteryRadar", "aewc", "ewJet", "maritimePatrol"]):
			continue
		if u.get("fly", false) and str(u.get("air_state", "")) in ["parked", "rearming"]:
			continue   # on the ground at its airfield
		var o := int(u.owner)
		if not support.has(o): support[o] = {}
		if not support[o].has(u.key): support[o][u.key] = []
		support[o][u.key].append(u.node.position)
	s.support = support
	for u in w.units:
		if not _alive(u) or w.disabled(u):
			continue
		match u.key:
			"mineLayer": _engineer(w, s, u, dt)
			"mineClearer": _clear(w, s, u, dt)
			"recoveryVehicle": _repair(w, u, dt)
	_trigger(w, s)

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

## A field of anti-vehicle mines at `at`, laid by `owner`.
static func lay(w: Node, owner: int, at: Vector3) -> Dictionary:
	var s := state(w)
	var f := {"id": int(s.next_id), "owner": owner, "at": at, "charges": MINE_CHARGES, "hits": {}, "clearing": 0.0, "mesh": null}
	s.next_id = int(s.next_id) + 1
	s.fields.append(f)
	_dress(w, f)
	if owner == 0 and w.hud != null:
		w.hud.notice("ENGINEERS: a minefield is laid. Enemy vehicles that drive into it will be struck; infantry walks through anti-vehicle mines.")
	return f

## The owner sees its own fields as a faint disc; the enemy sees nothing.
static func _dress(w: Node, f: Dictionary) -> void:
	if int(f.owner) != 0 or w.get("effects") == null:
		return
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = MINE_RADIUS
	disc.bottom_radius = MINE_RADIUS
	disc.height = 0.06
	disc.radial_segments = 24
	mi.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.7, 0.2, 0.22)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y: float = w.height_at(float(f.at.x), float(f.at.z)) if w.has_method("height_at") else float(f.at.y)
	mi.position = Vector3(f.at.x, y + 0.2, f.at.z)
	w.add_child(mi)
	f.mesh = mi

static func _remove(s: Dictionary, f: Dictionary) -> void:
	s.fields.erase(f)
	if f.mesh != null and is_instance_valid(f.mesh):
		f.mesh.queue_free()

## Enemy vehicles in a field are struck, once each every three seconds.
static func _trigger(w: Node, s: Dictionary) -> void:
	if s.fields.is_empty():
		return
	for f in s.fields.duplicate():
		var o := int(f.owner)
		for u in w.units:
			if not _alive(u) or not u.get("vehicle", false) or u.get("fly", false) or u.get("naval", false) or int(u.owner) == o:
				continue
			if not w.hostile(o, int(u.owner)):
				continue
			var p: Vector3 = u.node.position
			if Vector2(p.x - f.at.x, p.z - f.at.z).length() > MINE_RADIUS:
				continue
			var key := str(u.node.get_instance_id())
			if w.game_time < float(f.hits.get(key, -10.0)) + 3.0:
				continue
			f.hits[key] = w.game_time
			w.damage(u, MINE_DAMAGE, {"owner": o, "key": "mine", "dead": true, "covert": true})
			if w.get("effects") != null:
				w.effects.explosion(p + Vector3.UP * 0.5, 1.4, true)
			f.charges = int(f.charges) - 1
			if int(u.owner) == 0 and w.hud != null:
				w.hud.notice("MINES: your %s drove into a minefield." % str(w.unit_defs.get(u.key, {}).get("name", u.key)), p)
			if int(f.charges) <= 0:
				_remove(s, f)
				break

static func _clear(w: Node, s: Dictionary, u: Dictionary, dt: float) -> void:
	var at: Vector3 = u.node.position
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
		if other == u or not _alive(other) or int(other.owner) != int(u.owner) or not other.get("vehicle", false) or other.get("fly", false) or other.get("naval", false):
			continue
		var s: float = float(other.hp) / maxf(float(other.max_hp), 1.0)
		if s < share and other.node.position.distance_to(u.node.position) < REPAIR_REACH:
			share = s
			worst = other
	if worst != null:
		worst.hp = minf(float(worst.max_hp), float(worst.hp) + REPAIR_RATE * dt)
		u.recovering = worst   # (not "repairing": that is the repair order a save keeps)

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

## Whether `thing` (an enemy of `owner`) is found by `owner`'s sensors (fog_of_war.visible).
static func sensed(w: Node, owner: int, thing: Dictionary) -> bool:
	var s := state(w)
	if s.support.get(owner, {}).is_empty() or thing.get("node") == null:
		return false
	var at: Vector3 = thing.node.position
	var key := str(thing.get("key", ""))
	if (key in GUNS or _base(key) in GUNS) and _near(s, owner, "counterBatteryRadar", at, RADAR_REACH):
		return true
	if (thing.get("fly", false) or thing.get("naval", false)) and not (key in SUBMARINES or _base(key) in SUBMARINES) and _near(s, owner, "aewc", at, AEW_REACH):
		return true
	if (key in SUBMARINES or _base(key) in SUBMARINES) and _near(s, owner, "maritimePatrol", at, 90.0):
		return true
	return false

## Whether `attacker` may engage `target` at all (force_catalog.can_target).
static func can_target(attacker: Dictionary, target: Dictionary) -> bool:
	var key := str(attacker.get("key", ""))
	if key in NAVAL_ONLY and not target.get("naval", false):
		return false
	if key == "carrier" and (str(target.get("key", "")) in SUBMARINES or load("res://scripts/force_catalog.gd").base(str(target.get("key", ""))) in SUBMARINES):
		return false
	return true

# ---------------------------------------------------------------- saves

static func capture(w: Node) -> Dictionary:
	var s := state(w)
	return {"fields": s.fields.map(func(f): return {"owner": int(f.owner), "x": float(f.at.x), "y": float(f.at.y), "z": float(f.at.z), "charges": int(f.charges)})}

static func restore(w: Node, data: Dictionary) -> void:
	var s := state(w)
	for f in s.fields.duplicate():
		_remove(s, f)
	for d in data.get("fields", []):
		var f := lay_quiet(w, int(d.get("owner", 0)), Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0))))
		f.charges = clampi(int(d.get("charges", MINE_CHARGES)), 1, MINE_CHARGES)

static func lay_quiet(w: Node, owner: int, at: Vector3) -> Dictionary:
	var s := state(w)
	var f := {"id": int(s.next_id), "owner": owner, "at": at, "charges": MINE_CHARGES, "hits": {}, "clearing": 0.0, "mesh": null}
	s.next_id = int(s.next_id) + 1
	s.fields.append(f)
	_dress(w, f)
	return f
