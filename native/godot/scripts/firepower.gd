## Firepower: what a weapon does where it lands (native/FIREPOWER-PHYSICS.md).
##
## Every weapon names a munition, and the munition's profile says what happens physically when it goes off: how far the
## blast reaches and how it falls away, whether it throws fragments, how hard it shoves what is near, whether it leaves a
## crater, what it sets alight, what it does to buildings and roads. A grenade and a nuclear warhead use the same template
## and share nothing else: each profile switches on only the parts it has.
##
## `detonate()` is the one place a burst is resolved. A new weapon takes an existing munition, adds a row to MUNITIONS, or
## calls register() from the file that owns it; a weapon with something of its own gives its profile an `on_detonate`
## callable. tools/firepower-check.gd fails on any weapon without a profile.
extends RefCounted

## What a profile may say, with the value taken when it does not.
const DEFAULTS := {
	"kind": "he",          # kinetic, he, heat, thermobaric, torpedo, beam, nuclear
	"radius": 3.0,         # lethal blast radius (m); 0: no blast (a bullet, a beam)
	"core": 0.35,          # share of the radius at full effect
	"edge": 0.25,          # effect left at the rim; the fall-off between is smooth
	"frag": 0.0,           # fragments reach this many radii (against men in the open)
	"frag_share": 0.0,     # their share of the damage
	"shock": 1.0,          # how hard it throws what is near (0: not at all)
	"fx": 1.0,             # size of the explosion shown and heard (0: none)
	"crater": true,        # leaves a crater when it bursts on the ground
	"fire": 0.0,           # what it sets alight: 0 nothing .. 1.35 a firestorm; -1: by the firing unit (the old table)
	"structures": 0.5,     # reach into a building beyond its walls, as a share of the radius
	"roads": 1.5,          # damage to roads and rails, as a multiple of the damage (0: none)
	"airburst": false,     # it bursts in the air by design: no crater, nothing to the roads below
	"road_reach": 0.0,     # how far its damage to roads reaches (m); 0: the blast radius
}
const KINDS := ["kinetic", "he", "heat", "thermobaric", "torpedo", "beam", "nuclear"]

## The munitions of the tactical weapons (world.fire_weapon delivers them; the numbers are those the weapons had).
const MUNITIONS := {
	# --- direct fire
	"bullet": {"kind": "kinetic", "radius": 0.0, "fx": 0.0, "shock": 0.0, "crater": false, "fire": -1.0, "roads": 0.0},
	"shell": {"kind": "he", "radius": 3.5, "fx": 1.0, "shock": 1.0, "fire": -1.0, "structures": 0.0, "road_reach": 3.0},            # a tank or ship's gun, an autocannon burst
	"railgun": {"kind": "kinetic", "radius": 2.5, "fx": 1.2, "shock": 1.2, "fire": 0.32},
	"laser": {"kind": "beam", "radius": 0.0, "fx": 0.0, "shock": 0.0, "crater": false, "fire": 0.2, "roads": 0.0},
	# --- shaped charges: a small burst, the damage is in the hit
	"rocket": {"kind": "heat", "radius": 2.2, "fx": 0.7, "shock": 0.7, "fire": 0.32},
	"atgm": {"kind": "heat", "radius": 2.0, "fx": 0.8, "shock": 0.8, "fire": 0.32},
	"fpv": {"kind": "heat", "radius": 2.4, "fx": 0.9, "shock": 0.9, "fire": 0.82},
	# --- high explosive: blast and fragments
	"grenade": {"kind": "he", "radius": 2.5, "frag": 2.0, "frag_share": 0.15, "fx": 0.5, "shock": 0.6, "crater": false, "fire": 0.2, "roads": 0.0},
	"mortar": {"kind": "he", "radius": 3.0, "frag": 1.6, "frag_share": 0.12, "fx": 0.8, "shock": 0.8, "fire": 0.52},
	"shell_arc": {"kind": "he", "radius": 4.5, "frag": 1.6, "frag_share": 0.12, "fx": 1.5, "shock": 1.5, "fire": 0.52},
	"rocket_salvo": {"kind": "he", "radius": 3.5, "frag": 1.5, "frag_share": 0.1, "fx": 0.9, "shock": 0.9, "fire": 0.82},
	"rockets": {"kind": "he", "radius": 2.8, "fx": 0.7, "shock": 0.7, "fire": 0.45},
	"guided": {"kind": "he", "radius": 3.0, "fx": 1.1, "shock": 1.1, "fire": 0.82},
	"bomb": {"kind": "he", "radius": 5.0, "frag": 1.5, "frag_share": 0.1, "fx": 1.6, "shock": 1.6, "fire": 0.82},
	"missile": {"kind": "he", "radius": 3.0, "fx": 1.2, "shock": 1.2, "fire": 0.52},
	"kamikaze": {"kind": "he", "radius": 4.0, "fx": 1.6, "shock": 1.6, "fire": 0.82},
	"detonate": {"kind": "he", "radius": 5.0, "frag": 1.4, "frag_share": 0.1, "fx": 1.8, "shock": 1.6, "fire": 0.82},
	# --- fuel-air: the pressure holds across the whole cloud, and everything burns
	"thermobaric": {"kind": "thermobaric", "radius": 5.5, "core": 0.7, "edge": 0.5, "fx": 1.4, "shock": 1.4, "crater": false, "fire": 1.3},
	# --- in the air and under the sea
	"sam": {"kind": "he", "radius": 3.5, "fx": 1.0, "shock": 1.0, "crater": false, "fire": 0.0, "airburst": true},
	"torpedo": {"kind": "torpedo", "radius": 3.5, "fx": 1.4, "shock": 1.4, "crater": false, "fire": 0.2, "roads": 0.0},
	# --- delivered by a system of their own (their burst is a strategic missile's, or a swarm's drones)
	"brahmos": {"kind": "he", "radius": 0.0, "fx": 0.0, "delivered_by": "missiles"},
	"hgv": {"kind": "he", "radius": 0.0, "fx": 0.0, "delivered_by": "missiles"},
	"swarm": {"kind": "he", "radius": 0.0, "fx": 0.0, "delivered_by": "swarm"},
}

## What a strategic missile sets alight, by its special effect (it used to be a table in building_fires.gd).
const STRATEGIC_FIRE := {"hemp": 0.0, "emp": 0.0, "antiRadar": 0.0, "neutron": 0.12, "thermobaric": 1.35, "cluster": 0.55}
const STRATEGIC_FIRE_DEFAULT := 0.85
const NUCLEAR_FIRE := 1.35

static var _extra := {}     # profiles registered at run time: key -> profile
static var _full := {}      # key -> profile with the defaults filled in

## Adds (or replaces) a munition from the file that owns the weapon. `profile` may carry `on_detonate`: a callable
## (world, shooter, at, damage) that runs first and returns true to replace the standard burst.
static func register(key: String, profile: Dictionary) -> void:
	_extra[key] = profile
	_full.erase(key)

## Takes a registered munition away again (a mod unloading, a test tidying up).
static func unregister(key: String) -> void:
	_extra.erase(key)
	_full.erase(key)

static func has(key: String) -> bool:
	return MUNITIONS.has(key) or _extra.has(key)

static func keys() -> Array:
	return MUNITIONS.keys() + _extra.keys()

## The profile of `key` with every field present. An unknown munition is an error (and bursts as plain high explosive).
static func profile(key: String) -> Dictionary:
	if _full.has(key):
		return _full[key]
	var raw: Dictionary = _extra.get(key, MUNITIONS.get(key, {}))
	if raw.is_empty():
		push_error("firepower: no profile for the munition '%s' (add it to Firepower.MUNITIONS or register it)" % key)
	var p := DEFAULTS.duplicate()
	p.merge(raw, true)
	_full[key] = p
	return p

## A profile for a burst given only by its size (the old blast(radius, size) call): plain high explosive.
static func plain(radius: float, size: float) -> Dictionary:
	var p := DEFAULTS.duplicate()
	p.radius = radius
	p.fx = size
	p.shock = clampf(size, 0.6, 1.6)
	p.fire = -1.0
	return p

## The weapon a unit fires ("" for a plain gun or small arms): the one table of who carries what.
static func weapon_of(w: Node, unit_key: String) -> String:
	var own: String = {"recoillessTeam": "rocket", "wheeledHowitzer": "shell_arc", "shortRangeSAM": "sam", "mortarTeam": "mortar", "towedHowitzer": "shell_arc", "attackJet": "missile", "lightFighter": "missile", "missileBoat": "missile"}.get(unit_key, "")
	if own != "":
		return own
	return preload("res://scripts/war_tools.gd").WEAPON.get(unit_key, w.WEAPONS.get(unit_key, ""))

## The munition a unit's fire is resolved with: its weapon, or the gun or small arms it has by its class.
static func munition_of(w: Node, unit: Dictionary) -> String:
	var weapon := weapon_of(w, str(unit.key))
	if weapon != "":
		return weapon
	return "shell" if unit.get("vehicle", false) or unit.get("fly", false) or unit.get("naval", false) else "bullet"

## How much of the damage reaches a point `d` metres from a burst of profile `p` (1 at the centre, 0 beyond the radius).
static func falloff(p: Dictionary, d: float) -> float:
	var radius: float = p.radius
	if radius <= 0.0 or d >= radius:
		return 0.0
	var x := d / radius
	if x <= float(p.core):
		return 1.0
	return lerpf(1.0, float(p.edge), smoothstep(float(p.core), 1.0, x))

## What a hit from `source` sets alight (building_fires.gd): from the munition it fired, or a strategic missile's
## warhead. -1 when the source says nothing about it (the firing unit's own table decides).
static func fire_of_source(source: Dictionary) -> float:
	if source.has("munition") and has(str(source.munition)):
		return float(profile(str(source.munition)).fire)
	if str(source.get("key", "")) == "missile":
		var special := str(source.get("special", ""))
		if special in ["hemp", "emp", "antiRadar", "neutron"]:
			return float(STRATEGIC_FIRE[special])
		if bool(source.get("nuclear", false)):
			return NUCLEAR_FIRE
		return float(STRATEGIC_FIRE.get(special, STRATEGIC_FIRE_DEFAULT))
	return -1.0

## A burst of `munition` at `at`, fired by `shooter`, of `dmg` at its centre: everything it does.
## `custom` gives the profile itself (for a burst that has no munition of its own).
static func detonate(w: Node, shooter: Dictionary, munition: String, at: Vector3, dmg: float, custom := {}) -> void:
	var p: Dictionary = custom if not custom.is_empty() else profile(munition)
	if p.has("on_detonate") and (p.on_detonate as Callable).call(w, shooter, at, dmg):
		return
	if munition != "":
		shooter["munition"] = munition   # what it was hit with: building_fires asks, through world.damage(target, .., shooter)
	var ground: float = maxf(w.height_at(at.x, at.z), float(w.map.seaLevel))
	var height: float = at.y - ground
	var on_ground: bool = height < 1.5
	var radius: float = p.radius
	if float(p.fx) > 0.0:
		w.effects.explosion(at, float(p.fx), on_ground, bool(p.crater) and not bool(p.airburst))
	# Roads and rails: only a burst at or near the ground reaches them.
	if float(p.roads) > 0.0 and radius > 0.0 and height < 4.0 and not bool(p.airburst):
		w.logistics.damage_at(at, float(p.road_reach) if float(p.road_reach) > 0.0 else radius, dmg * float(p.roads))
	if radius <= 0.0:
		return
	var owner: int = int(shooter.owner)
	var reach: float = radius * float(p.structures)
	for b in w.buildings:
		if not b.dead and w.hostile(owner, b.owner) and Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length() < b.footprint * 0.62 + reach:
			w.damage(b, dmg * w.effectiveness(shooter, b), shooter)
	var frag_reach: float = radius * float(p.frag) if float(p.frag_share) > 0.0 else 0.0
	var far: float = maxf(radius, frag_reach)
	var shock: float = p.shock
	for other in w.units:
		if other.dead or not w.hostile(owner, other.owner):
			continue   # a burst does not hurt friends, or start wars with bystanders
		var d: float = other.node.position.distance_to(at)
		if d >= far:
			continue
		if d < radius:
			w.damage(other, dmg * w.effectiveness(shooter, other) * falloff(p, d), shooter)
			if shock > 0.0:
				w.Motion.shove(other, at, (1.0 - d / radius) * shock)
		elif other.get("garrison_building") == null and w.target_class(other) == "infantry":
			# Fragments fly past the blast: they find men in the open, not armour and not troops behind walls.
			w.damage(other, dmg * w.effectiveness(shooter, other) * float(p.frag_share) * (1.0 - (d - radius) / maxf(frag_reach - radius, 0.01) * 0.6), shooter)

## What is wrong with the profiles ([] when nothing is): unknown fields, values out of range.
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for key in keys():
		var raw: Dictionary = _extra.get(key, MUNITIONS.get(key, {}))
		for field in raw:
			if not DEFAULTS.has(field) and not field in ["on_detonate", "delivered_by"]:
				out.append("%s: unknown field '%s'" % [key, field])
		var p := profile(key)
		if not str(p.kind) in KINDS: out.append("%s: unknown kind '%s'" % [key, p.kind])
		if float(p.radius) < 0.0 or float(p.radius) > 400.0: out.append("%s: radius %s" % [key, p.radius])
		if float(p.core) < 0.0 or float(p.core) > 1.0 or float(p.edge) < 0.0 or float(p.edge) > 1.0: out.append("%s: core or edge outside 0..1" % key)
		if float(p.frag_share) > 0.0 and float(p.frag) <= 1.0: out.append("%s: fragments must reach beyond the blast (frag > 1)" % key)
		if float(p.frag_share) < 0.0 or float(p.frag_share) > 0.5: out.append("%s: frag_share %s" % [key, p.frag_share])
		if float(p.fire) > 1.4 or (float(p.fire) < 0.0 and float(p.fire) != -1.0): out.append("%s: fire %s" % [key, p.fire])
		if float(p.shock) < 0.0 or float(p.shock) > 4.0: out.append("%s: shock %s" % [key, p.shock])
		if float(p.radius) == 0.0 and float(p.fx) > 0.0 and not raw.has("delivered_by"): out.append("%s: an explosion with no blast radius" % key)
	return out
