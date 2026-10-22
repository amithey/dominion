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

const VEHICLES := ["mineLayer", "mineClearer", "recoveryVehicle", "decoy", "counterBatteryRadar", "coastalASM", "combatUGV", "logisticsUGV", "robotDog"]
const AIR := ["aewc", "ewJet", "maritimePatrol", "carrierJet", "carrierDrone", "heavyLift", "navalHelicopter", "heavyBomberDrone"]
const FIXED_WING := ["aewc", "ewJet", "maritimePatrol", "carrierJet", "carrierDrone"]
const NAVAL := ["carrier", "asFrigate", "landingShip"]
const ALTITUDE := {"aewc": 32.0, "ewJet": 27.0, "maritimePatrol": 21.0, "carrierJet": 24.0, "carrierDrone": 20.0, "heavyLift": 15.0, "navalHelicopter": 13.0, "heavyBomberDrone": 9.0}
const SHIP_LENGTH := {"carrier": 30.0, "asFrigate": 13.0, "landingShip": 16.0}
const WEAPON := {"coastalASM": "missile", "asFrigate": "missile", "maritimePatrol": "missile", "ewJet": "missile", "mineClearer": "rocket", "carrierJet": "missile", "carrierDrone": "missile", "navalHelicopter": "missile", "heavyBomberDrone": "bomb"}
const NAVAL_ONLY := ["coastalASM", "maritimePatrol", "navalHelicopter"]
const SUBMARINES := ["submarine", "nuclearSub", "orca"]
const SUB_HUNTERS := ["maritimePatrol", "asFrigate", "navalHelicopter"]
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
const ROBOTS := ["combatUGV", "logisticsUGV", "robotDog", "heavyBomberDrone", "carrierDrone"]   # no crew: no war support lost
const EVAC_REACH := 14.0
const EVAC_RATE := 6.0
# The air wing (by class: force_models.CARRIER_STYLE): aircraft aboard, and what flies from the deck.
const WING := {"usa": 5, "china": 5, "france": 5, "italy": 3, "uk": 4, "india": 4, "turkiye": 4, "japan": 4, "iran": 3}
const WING_AIRCRAFT := {"usa": "F/A-18E Super Hornet", "china": "J-15T", "france": "Rafale M", "italy": "F-35B Lightning", "uk": "F-35B Lightning", "india": "MiG-29K", "japan": "F-35B Lightning", "turkiye": "Bayraktar TB3", "iran": "Shahed-129"}
## How far from the carrier its aircraft will fly to strike (a third of the island's width): far beyond the carrier's own
## guns (24 m), which only defend it. A sortie is 45 seconds in the air at about 34 m a second.
const STRIKE_REACH := 240.0
const LAUNCH_EVERY := 3.0
const SORTIE := 45.0
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
	# The support units of each nation, by key, for the hot damage path.
	var support := {}
	for u in w.units:
		if not _alive(u) or not (u.key in ["counterBatteryRadar", "aewc", "ewJet", "maritimePatrol", "navalHelicopter"]):
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
			"carrier": _air_wing(w, u, dt)
			"mineLayer": _engineer(w, s, u, dt)
			"mineClearer": _clear(w, s, u, dt)
			"recoveryVehicle": _repair(w, u, dt)
			"logisticsUGV": _evacuate(w, u, dt)
	_trigger(w, s)
	preload("res://scripts/airlift.gd").update(w)   # troops boarding helicopters

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

## A logistics robot brings the wounded back: the worst-hurt infantry near it recovers.
static func _evacuate(w: Node, u: Dictionary, dt: float) -> void:
	var worst = null
	var share := 0.999
	for other in w.units:
		if other == u or not _alive(other) or int(other.owner) != int(u.owner) or not other.key in w.infantry_keys or other.key == "worker":
			continue
		var s: float = float(other.hp) / maxf(float(other.max_hp), 1.0)
		if s < share and other.node.position.distance_to(u.node.position) < EVAC_REACH:
			share = s
			worst = other
	if worst != null:
		worst.hp = minf(float(worst.max_hp), float(worst.hp) + EVAC_RATE * dt)

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
	if (key in SUBMARINES or _base(key) in SUBMARINES) and (_near(s, owner, "maritimePatrol", at, 90.0) or _near(s, owner, "navalHelicopter", at, 60.0)):
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
			u.sortie_left = 0.0
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
		return ordered if Vector2(op.x - carrier.node.position.x, op.z - carrier.node.position.z).length() <= STRIKE_REACH * 1.05 else null   # (out of reach: the carrier is closing)
	if not bool(_wing(w, carrier).get("auto", true)):
		return null   # orders only: nothing goes up unless you point at something
	var o := int(carrier.owner)
	var at: Vector3 = carrier.node.position
	var best = null
	var score := INF
	for e in w.units + w.buildings:
		if e.dead or int(e.owner) == o or int(e.owner) < 0 or not w.hostile(o, int(e.owner)):
			continue
		if str(e.get("key", "")) in SUBMARINES or _base(str(e.get("key", ""))) in SUBMARINES:
			continue
		var p: Vector3 = e.node.position if not e.get("is_building", false) else e.root.position
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d > STRIKE_REACH:
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
	var info := wing_info(w, carrier)
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
static func carrier_flight(w: Node, u: Dictionary, delta: float) -> bool:
	var carrier = u.get("carrier")
	if carrier == null or carrier.dead:
		u.carrier = null
		return false
	if str(u.get("air_state", "ready")) == "ready":
		u.sortie_left = float(u.get("sortie_left", SORTIE)) - delta
		var enemy = u.get("enemy")
		if (enemy == null or enemy.dead) and u.get("target") == null:
			u.idle_air = float(u.get("idle_air", 0.0)) + delta
		else:
			u.idle_air = 0.0
		if float(u.sortie_left) <= 0.0 or int(u.get("ammo", 1)) <= 0 or float(u.idle_air) > 4.0:
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
