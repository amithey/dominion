extends RefCounted
## Weapons of mass destruction, the ground they poison, and who used what.
## Research and sources: native/CBRN-UN-RESEARCH-2026-10-05.md. Who has which
## weapon is cbrn_data.gd's (data for every faction, rules for new ones).
##
## NUCLEAR (released only at posture 2: defcon.gd)
##   Tactical (5-10 kt) . Nuclear (strategic) . Thermonuclear (~1 Mt)
##   Tsar Bomba (50 Mt, Russia) . Neutron (kills crews, spares buildings)
##   High-Altitude EMP (no blast: a wide blackout; satellites lost)
##   MIRV (one missile, three warheads that fall around the target)
##   Nuclear Glide Vehicle (Avangard; China's orbital glider): nearly unstoppable
##   Burevestnik (nuclear-powered cruise missile: a radioactive trail behind it)
##   Poseidon (nuclear torpedo from a submarine: a radioactive wave on a coast)
## Every nuclear burst leaves FALLOUT that drifts downwind and decays by the
## 7-10 rule. A Nuclear Reactor destroyed spews its core over the land around
## it (Chernobyl's zone is still 2,600 km2): an attack on one is a crime too
## (Additional Protocol I, Art. 56).
##
## ELECTROMAGNETIC: the HPM Cruise Missile (CHAMP/HiJENKS): three non-lethal
## microwave pulses along its path.
##
## CHEMICAL (banned by the CWC of 1993)
##   Nerve Agent (sarin/VX): a drifting cloud that kills infantry
##   Chlorine: a weaker cloud, improvised by anyone
##   Riot Agent (CS, chloropicrin): little death, but troops are driven from cover
##   Incapacitant (fentanyl-type agents): infantry falls unconscious
## BIOLOGICAL (banned by the BWC of 1972)
##   Anthrax: long-lived spores, an area no one can hold; not contagious
##   Engineered Disease: an outbreak that spreads from town to town
## RADIOLOGICAL: the dirty bomb (any nation with a reactor).
##
## A threshold state (Iran; Saudi Arabia once Iran goes) may break out:
## Nuclear Breakout gives it the bomb, and the IAEA sends it to the Council.
## Every use is recorded. A chemical or biological attack is attributed only
## after an investigation (the OPCW's teams, the Secretary-General's
## Mechanism): 60 seconds. Then the world's verdict goes to the UN (un.gd).

const Cbrn := preload("res://scripts/cbrn_data.gd")
const NUCLEAR := ["tacticalNuke", "nuke", "hydrogenBomb", "tsarBomba", "neutronBomb", "nuclearEmp", "mirv", "mirvWarhead", "nuclearGlide", "burevestnik", "poseidon", "bunkerBuster", "nuclearCruise"]
const MISSILES := {
	"tacticalNuke": {"name": "Tactical Nuclear Missile", "icon": "TN", "buildTime": 45, "cost": {"money": 1400, "iron": 50, "silicon": 40, "uranium": 12},
		"dmg": 2600, "radius": 18, "speed": 60, "arc": true, "nuclear": true, "needsDiscovery": "nuclearProgram",
		"desc": "A low-yield nuclear warhead (5-10 kt) for the battlefield: a small blast and a small fallout. Still a nuclear weapon: the world's alert goes to DEFCON 1 and every nation condemns its use."},
	"hydrogenBomb": {"name": "Thermonuclear Missile", "icon": "H", "buildTime": 90, "cost": {"money": 3200, "iron": 100, "silicon": 80, "uranium": 45},
		"dmg": 7000, "radius": 62, "speed": 48, "arc": true, "nuclear": true, "needsDiscovery": "thermonuclear",
		"desc": "A two-stage hydrogen bomb of about a megaton: a blast that erases a city and its surroundings, and a wide fallout for 7 minutes."},
	"tsarBomba": {"name": "Tsar Bomba", "icon": "TSAR", "buildTime": 150, "cost": {"money": 6000, "iron": 160, "silicon": 100, "uranium": 90},
		"dmg": 14000, "radius": 105, "speed": 40, "arc": true, "nuclear": true, "needsDiscovery": "thermonuclear",
		"desc": "A 50-megaton thermonuclear device, Russia's alone: the largest yield ever built. Almost all of it comes from fusion, so its fallout is small for so enormous a blast."},
	"neutronBomb": {"name": "Neutron Warhead", "icon": "N", "buildTime": 55, "cost": {"money": 1800, "silicon": 50, "uranium": 20},
		"dmg": 3200, "radius": 26, "speed": 60, "arc": true, "nuclear": true, "special": "neutron", "needsDiscovery": "enhancedRadiation",
		"desc": "Enhanced radiation: a small blast but a flood of neutrons that kills tank crews and infantry and spares buildings, with short-lived radiation. No one fields one today: this is a programme to build them."},
	"nuclearEmp": {"name": "High-Altitude Nuclear EMP", "icon": "HEMP", "buildTime": 60, "cost": {"money": 2200, "silicon": 60, "uranium": 25},
		"dmg": 0, "radius": 110, "speed": 55, "arc": true, "nuclear": true, "special": "hemp", "needsDiscovery": "nuclearProgram",
		"desc": "A warhead burst high above the target: no blast on the ground, but everything electronic in a very wide circle goes dark for 90 s, aircraft in the air are crippled, drones fall, and satellites in orbit are knocked out. A nuclear detonation all the same."},
	"mirv": {"name": "MIRV Missile", "icon": "MIRV", "buildTime": 100, "cost": {"money": 3600, "iron": 110, "silicon": 90, "uranium": 50},
		"dmg": 0, "radius": 30, "speed": 52, "arc": true, "nuclear": true, "special": "mirv", "needsDiscovery": "ballisticTech",
		"desc": "One missile, three independently targeted warheads of about 100 kt that fall around the target. Stop it before the warheads part, or not at all."},
	"mirvWarhead": {"name": "MIRV warhead", "icon": "RV", "hidden": true, "dmg": 2400, "radius": 20, "speed": 60, "arc": true, "nuclear": true, "buildTime": 1, "cost": {}, "desc": ""},
	"nuclearGlide": {"name": "Nuclear Glide Vehicle", "icon": "HGV-N", "buildTime": 80, "cost": {"money": 3000, "iron": 70, "silicon": 90, "uranium": 30},
		"dmg": 4500, "radius": 38, "speed": 180, "arc": true, "nuclear": true, "needsDiscovery": "ballisticTech",
		"desc": "A nuclear warhead on a hypersonic glider that manoeuvres all the way down: missile defence almost never catches it."},
	"burevestnik": {"name": "Burevestnik", "icon": "9M730", "buildTime": 110, "cost": {"money": 4000, "iron": 90, "silicon": 80, "uranium": 40},
		"dmg": 4000, "radius": 34, "speed": 90, "nuclear": true, "special": "burevestnik", "needsDiscovery": "thermonuclear",
		"desc": "A nuclear-powered cruise missile of almost unlimited range, flying low. Its open reactor leaves patches of radiation along its path."},
	"bunkerBuster": {"name": "Nuclear Bunker Buster", "icon": "B61-11", "buildTime": 70, "cost": {"money": 2600, "iron": 90, "silicon": 50, "uranium": 25},
		"dmg": 3600, "radius": 16, "speed": 55, "arc": true, "nuclear": true, "special": "penetrator", "needsDiscovery": "nuclearProgram",
		"desc": "An earth-penetrating nuclear bomb: it buries itself before it bursts, so it covers a small circle on the surface, but buildings, bunkers and silos in it are crushed three times over. A ground burst: a heavy, dirty fallout."},
	"nuclearCruise": {"name": "Nuclear Cruise Missile", "icon": "ALCM", "buildTime": 60, "cost": {"money": 2200, "iron": 60, "silicon": 60, "uranium": 18},
		"dmg": 3200, "radius": 28, "speed": 80, "nuclear": true, "needsDiscovery": "nuclearProgram",
		"desc": "A nuclear warhead (5-150 kt) on a low-flying cruise missile: it hugs the ground below early radar, but air defence that sees it can stop it."},
	"poseidon": {"name": "Nuclear Torpedo", "icon": "2M39", "buildTime": 140, "cost": {"money": 5500, "iron": 140, "silicon": 90, "uranium": 70},
		"dmg": 9000, "radius": 60, "speed": 40, "nuclear": true, "special": "poseidon", "needsDiscovery": "thermonuclear", "sub_only": true,
		"desc": "A nuclear torpedo that strikes a coast and throws a radioactive wave over it. Fired from a nuclear submarine or a coastal Missile Silo, at a target near the sea."},
	"dirtyBomb": {"name": "Radiological (Dirty) Bomb", "icon": "RDD", "buildTime": 25, "cost": {"money": 500, "iron": 20, "uranium": 8},
		"dmg": 300, "radius": 8, "speed": 70, "special": "dirty",
		"desc": "A conventional charge wrapped round radioactive material. It kills few, but contaminates the ground for 6 minutes: nobody builds there and towns empty. A crime the world does not forgive."},
	"chemical": {"name": "Nerve Agent Warhead", "icon": "GB", "buildTime": 22, "cost": {"money": 450, "iron": 20, "oil": 10},
		"dmg": 30, "radius": 4, "speed": 75, "special": "chemical",
		"desc": "Sarin or VX: a cloud that drifts downwind for 90 s and kills infantry (armour crews are protected); VX lingers on the ground. Banned by the Chemical Weapons Convention."},
	"chlorine": {"name": "Chlorine Bombs", "icon": "Cl", "buildTime": 12, "cost": {"money": 150, "iron": 10},
		"dmg": 20, "radius": 4, "speed": 70, "special": "chlorine",
		"desc": "An industrial chemical turned into a weapon: a weaker, shorter cloud than a nerve agent. A breach of the Chemical Weapons Convention like any other."},
	"riotAgent": {"name": "Riot Agent Munitions", "icon": "CS", "buildTime": 10, "cost": {"money": 120, "iron": 8},
		"dmg": 10, "radius": 3, "speed": 75, "special": "riot",
		"desc": "CS gas and chloropicrin dropped on trenches: they kill few, but troops in the cloud lose the protection of their bunkers. Allowed for police, banned as a method of warfare."},
	"incapacitant": {"name": "Incapacitating Agent", "icon": "PBA", "buildTime": 30, "cost": {"money": 600, "silicon": 20},
		"dmg": 10, "radius": 3, "speed": 75, "special": "incapacitant",
		"desc": "A fentanyl-type aerosol: infantry in the cloud falls unconscious, and some never wake. Banned as a weapon of war."},
	"anthrax": {"name": "Anthrax Warhead", "icon": "BA", "buildTime": 45, "cost": {"money": 800, "silicon": 20, "food": 40},
		"dmg": 0, "radius": 4, "speed": 70, "special": "anthrax",
		"desc": "Anthrax spores: not contagious, but the ground stays lethal for 8 minutes, an area no army can hold. Banned by the Biological Weapons Convention."},
	"bioweapon": {"name": "Engineered Disease", "icon": "BW", "buildTime": 50, "cost": {"money": 900, "silicon": 20, "food": 60},
		"dmg": 0, "radius": 4, "speed": 70, "special": "bio",
		"desc": "A contagious engineered disease released over a town: an outbreak that sickens its people and soldiers and spreads to the nearest towns, whoever holds them, yours too."},
}
const DISCOVERIES := {
	"thermonuclear": {"name": "Thermonuclear Weapons", "cost": 1000, "branch": "strategic", "era": 4,
		"reqDiscovery": "nuclearProgram", "reqBuilding": "nuclearReactor", "fx": {},
		"desc": "The two-stage hydrogen bomb: unlocks the Thermonuclear Missile, and for Russia the Tsar Bomba, the Burevestnik and the Poseidon."},
	"enhancedRadiation": {"name": "Enhanced Radiation Weapons", "cost": 800, "branch": "strategic", "era": 4,
		"reqDiscovery": "nuclearProgram", "reqBuilding": "nuclearReactor", "fx": {},
		"desc": "The neutron bomb: a small fusion warhead that kills by radiation rather than blast. Unlocks the Neutron Warhead."},
	"nuclearBreakout": {"name": "Nuclear Breakout", "cost": 1400, "branch": "strategic", "era": 4,
		"reqBuilding": "nuclearReactor", "fx": {},
		"desc": "Enrich to weapons grade and build a device: the bomb at once (the Nuclear Missile, the Tactical Nuclear Missile and the high-altitude EMP). The IAEA will report it to the Security Council, the world will turn on you, and your neighbours may follow."},
}
const FALLOUT := {
	"tacticalNuke": [0.8, 150.0, 0.6], "nuke": [0.8, 300.0, 1.0], "hydrogenBomb": [0.9, 420.0, 1.3],
	"tsarBomba": [0.85, 480.0, 1.0], "neutronBomb": [0.75, 60.0, 1.6], "mirvWarhead": [0.8, 240.0, 0.9],
	"nuclearGlide": [0.8, 300.0, 1.0], "burevestnik": [0.8, 300.0, 1.1], "poseidon": [1.2, 600.0, 1.5],
	"bunkerBuster": [1.2, 360.0, 1.4], "nuclearCruise": [0.8, 240.0, 0.9],
}
const HARM := {
	"fallout": {"infantry": 0.03, "vehicle": 0.01, "naval": 0.005, "building": 0.004},
	"chemical": {"infantry": 0.06, "vehicle": 0.004, "naval": 0.0, "building": 0.0},
	"riot": {"infantry": 0.008, "vehicle": 0.0, "naval": 0.0, "building": 0.0},
	"incap": {"infantry": 0.01, "vehicle": 0.001, "naval": 0.0, "building": 0.0},
	"anthrax": {"infantry": 0.02, "vehicle": 0.003, "naval": 0.0, "building": 0.0},
	"bio": {"infantry": 0.012, "vehicle": 0.003, "naval": 0.0, "building": 0.0},
}
const ZONE_COLOUR := {"fallout": Color(0.75, 0.95, 0.15), "chemical": Color(0.85, 0.85, 0.2), "riot": Color(0.9, 0.9, 0.85),
	"incap": Color(0.6, 0.85, 0.95), "anthrax": Color(0.85, 0.55, 0.35), "bio": Color(0.75, 0.4, 0.95)}
const CONDEMN := {"chemical": 20.0, "bio": 30.0, "dirty": 15.0, "reactor": 15.0, "breakout": 15.0}
const INVESTIGATION := 60.0
const TOWNS := ["hq", "cityCenter", "villageCenter"]
const HPM_SECONDS := 45.0
const HEMP_SECONDS := 90.0
const SPREAD_EVERY := 40.0
const SPREAD_RANGE := 170.0
const RINGS := 7
const SEGMENTS := 36

var w: Node
var zones: Array = []        # {kind, at, radius, strength, born, until, owner, drift, town, decal}
var incidents: Array = []    # {kind, weapon, by, victims, time, attributed}
var broken_out: Array = []   # nations that broke out to the bomb
var wind := Vector2.RIGHT
var _tick := 0.0
var _ai_tick := 0.0

func _init(world: Node) -> void:
	w = world
	wind = Vector2.RIGHT.rotated(randf() * TAU) * 0.25

## Registers the weapons and the discoveries (modern_warfare.apply), with each
## weapon's nations from cbrn_data.gd (rule-based ones: missiles.locked asks
## capability_blocked).
static func apply(world: Node) -> void:
	var types: Dictionary = world.map.missiles.get("types", {})
	for key in MISSILES:
		types[key] = MISSILES[key].duplicate(true)
	for key in Cbrn.CAPABILITY:
		if types.has(key) and Cbrn.CAPABILITY[key].has("ids"):
			types[key].nation = Cbrn.arsenal_ids(Cbrn.CAPABILITY[key].ids)
	if types.has("nuke"):
		types.nuke.nuclear = true
		types.nuke.desc = "A strategic warhead of a few hundred kilotons: the city-killer. Its fallout poisons the ground for 5 minutes. Released only at posture 2; the whole world will condemn it."
	if types.has("emp"):
		types.emp.name = "HPM Cruise Missile"
		types.emp.dmg = 0
		types.emp.radius = 15
		types.emp.desc = "A high-power microwave cruise missile: no blast and no deaths. Over the last stretch of its flight it fires three microwave pulses that knock out the electronics of vehicles, aircraft, ships and buildings for 45 s and bring drones down."
	# Where they are made (missiles.gd FACILITY): two buildings of their own.
	var defs: Dictionary = world.map.get("buildingDefs", {})
	defs.strategicComplex = {"name": "Strategic Weapons Complex", "cat": "military", "size": 8, "hp": 1600, "cost": {"money": 2500, "iron": 150, "silicon": 80},
		"buildTime": 45, "trains": [], "provides": {}, "onDeposit": false, "depositTypes": null, "unique": false, "unbuildable": false,
		"buildRadius": 0, "settlement": null, "coastal": false,
		"desc": "Assembles nuclear warheads and keeps them (2 per complex). They are launched from a Missile Silo or a nuclear submarine. Only a nuclear-armed nation can build one."}
	defs.specialLab = {"name": "Special Weapons Laboratory", "cat": "military", "size": 6, "hp": 900, "cost": {"money": 1500, "iron": 60, "silicon": 60},
		"buildTime": 35, "trains": [], "provides": {}, "onDeposit": false, "depositTypes": null, "unique": false, "unbuildable": false,
		"buildRadius": 0, "settlement": null, "coastal": false,
		"desc": "Produces chemical, biological and radiological weapons and keeps them (2 per laboratory). They are launched from a Missile Silo. Only a nation with such a programme can build one."}
	if defs.has("missileSilo"):
		defs.missileSilo.desc = "Produces conventional missiles (tactical, cruise, cluster, microwave, anti-ship, ballistic, hypersonic), stored in Ammo Depots, and launches every missile you hold, nuclear and special weapons included."
	var discoveries: Dictionary = world.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)
	discoveries.thermonuclear.nation = Cbrn.arsenal_ids(Cbrn.ids_for("hydrogenBomb"))
	discoveries.enhancedRadiation.nation = Cbrn.arsenal_ids(Cbrn.ids_for("neutronBomb"))
	discoveries.nuclearBreakout.nation = Cbrn.arsenal_ids(Cbrn.THRESHOLD.keys().filter(func(id): return Cbrn.THRESHOLD[id].after == ""))

static func is_nuclear(key: String) -> bool:
	return key in NUCLEAR

## Why the player may not build or fire weapon `key` for want of the capability
## (cbrn_data.gd), or "" (missiles.locked).
func capability_blocked(key: String) -> String:
	if not Cbrn.CAPABILITY.has(key):
		return ""
	return Cbrn.blocked(w, 0, key)

# ---------------------------------------------------------------- impacts

## After a warhead lands (missiles.impact): its lasting effects.
func after_impact(key: String, at: Vector3, owner: int, from: Vector3, struck: Array) -> void:
	var def: Dictionary = w.missiles.def_of(key)
	var radius := float(def.get("radius", 10.0))
	match str(def.get("special", "")):
		"emp":
			_hpm(at, from, radius, owner)
			return
		"hemp":
			_blackout(at, radius, HEMP_SECONDS, owner, true)
			w.effects.emp_flash(at + Vector3.UP * 60.0, radius)
			_satellites(0.3, "the high-altitude burst")
		"mirv":
			# The bus releases three warheads that fall around the target.
			for i in range(3):
				var p: Vector3 = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(10.0, radius)
				p.y = maxf(w.height_at(p.x, p.z), float(w.map.seaLevel))
				w.missiles.impact("mirvWarhead", p, owner)
		"burevestnik":
			var start: Vector3 = from if from != Vector3.INF else at
			for f in [0.3, 0.55, 0.8]:
				_zone("fallout", start.lerp(at, f), 9.0, 150.0, 0.35, owner, 0.0)   # the open reactor's exhaust
		"dirty":
			_zone("fallout", at, 26.0, 360.0, 0.45, owner, 0.15)
			_incident("dirty", key, owner, struck)
		"chemical":
			_zone("chemical", at, 22.0, 90.0, 1.0, owner, 0.5)
			_zone("chemical", at, 10.0, 240.0, 0.5, owner, 0.0)   # VX lingers on the ground
			_incident("chemical", key, owner, struck + _owners_near(at, 22.0, owner))
		"chlorine":
			_zone("chemical", at, 18.0, 60.0, 0.6, owner, 0.6)
			_incident("chemical", key, owner, struck + _owners_near(at, 18.0, owner))
		"riot":
			_zone("riot", at, 16.0, 45.0, 1.0, owner, 0.4)
			_incident("chemical", key, owner, struck + _owners_near(at, 16.0, owner))
		"incapacitant":
			_zone("incap", at, 18.0, 50.0, 1.0, owner, 0.4)
			_incident("chemical", key, owner, struck + _owners_near(at, 18.0, owner))
		"anthrax":
			_zone("anthrax", at, 26.0, 480.0, 1.0, owner, 0.0)
			_incident("bio", key, owner, struck + _owners_near(at, 26.0, owner))
		"bio":
			var town = _town_near(at, 60.0)
			if town != null:
				_infect(town, owner)
			else:
				_zone("bio", at, 30.0, 240.0, 1.0, owner, 0.0)
			_incident("bio", key, owner, struck + ([int(town.owner)] if town != null else []))
	if FALLOUT.has(key):
		var f: Array = FALLOUT[key]
		_zone("fallout", at, radius * float(f[0]), float(f[1]), float(f[2]), owner, 0.25)
	if is_nuclear(key) and key != "mirvWarhead":
		_incident("nuclear", key, owner, struck)

func _owners_near(at: Vector3, r: float, except: int) -> Array:
	var out := []
	for b in w.buildings:
		if not b.dead and int(b.owner) != except and not int(b.owner) in out and b.root.position.distance_to(at) <= r + 10.0:
			out.append(int(b.owner))
	for u in w.units:
		if not u.dead and int(u.owner) != except and not int(u.owner) in out and u.node.position.distance_to(at) <= r:
			out.append(int(u.owner))
	return out

## The HPM missile's three pulses over the last stretch of its flight.
func _hpm(at: Vector3, from: Vector3, radius: float, owner: int) -> void:
	var start: Vector3 = from if from != Vector3.INF else at
	for f in [0.6, 0.8, 1.0]:
		var p: Vector3 = start.lerp(at, f)
		p.y = maxf(w.height_at(p.x, p.z), float(w.map.seaLevel))
		_blackout(p, radius, HPM_SECONDS, owner, false)
		w.effects.emp_flash(p, radius)

## Satellites lost to a nuclear burst at altitude: each with chance `share`.
func _satellites(share: float, what: String) -> int:
	var s = w.get("space")
	if s == null:
		return 0
	var lost := 0
	for o in s.sats:
		for kind in s.KINDS:
			for i in range(s.count(o, kind)):
				if randf() < share:
					s.sats[o][kind] = s.count(o, kind) - 1
					lost += 1
	if lost > 0:
		w.hud.notice("SPACE: %s knocked %d satellites out of orbit." % [what, lost])
		if w.research != null: w.research._recompute()
	return lost

## Knocks out electronics; drones fall; with `airburst`, aircraft aloft are crippled.
func _blackout(at: Vector3, radius: float, seconds: float, owner: int, airburst: bool) -> void:
	var drones: Array = preload("res://scripts/modern_warfare.gd").DRONES
	for u in w.units:
		if u.dead or int(u.owner) == owner and not airburst:
			continue
		if Vector2(u.node.position.x - at.x, u.node.position.z - at.z).length() > radius:
			continue
		if u.key in drones or u.key in ["wingman", "loiterer", "shahed", "harop"]:
			w.kill(u)
			continue
		if u.key in w.infantry_keys and not u.key in ["fpvTeam"]:
			continue
		u.disabled_until = maxf(float(u.get("disabled_until", 0.0)), w.game_time + seconds)
		if airburst and u.get("fly", false) and w.airborne(u):
			w.damage(u, float(u.max_hp) * 0.6, {"owner": owner, "dead": true, "key": "missile"})
	for b in w.buildings:
		if b.dead or (int(b.owner) == owner and not airburst):
			continue
		if Vector2(b.root.position.x - at.x, b.root.position.z - at.z).length() <= radius:
			b.disabled_until = maxf(float(b.get("disabled_until", 0.0)), w.game_time + seconds)

## Whether `owner` has a working facility for its `kind` of weapon ("nuclear":
## a Strategic Weapons Complex; "special": a Special Weapons Laboratory). A
## rival without one cannot use those weapons: destroying it disarms them.
func armed(owner: int, kind: String) -> bool:
	var key: String = "strategicComplex" if kind == "nuclear" else "specialLab"
	return w.buildings.any(func(b): return int(b.owner) == owner and not b.dead and b.built and b.key == key)

## A nuclear submarine at sea: a second strike survives the loss of the complexes.
func at_sea(owner: int) -> bool:
	return w.units.any(func(u): return int(u.owner) == owner and not u.dead and u.key == "nuclearSub")

## A weapons facility destroyed (world.destroy_building): what it held is lost,
## and a little of it spreads.
func facility_destroyed(b: Dictionary) -> void:
	var owner := int(b.owner)
	var nuclear: bool = b.key == "strategicComplex"
	if nuclear:
		_zone("fallout", b.root.position, 18.0, 240.0, 0.5, int(b.get("last_by", -1)), 0.2)   # scattered fissile material
	else:
		_zone("chemical", b.root.position, 14.0, 90.0, 0.6, int(b.get("last_by", -1)), 0.3)   # agents released
	var d: Node = w.diplomacy
	var what := "Strategic Weapons Complex" if nuclear else "Special Weapons Laboratory"
	if owner == 0:
		# The weapons it held: the stock beyond what the remaining facilities hold is lost.
		var ms: Node = w.missiles
		var cat := "nuclear" if nuclear else "special"
		var lost := 0
		while ms.stored(cat) > ms.capacity(cat):
			for k in ms.stock.keys():
				if ms.category(k) == cat and int(ms.stock[k]) > 0:
					ms.stock[k] = int(ms.stock[k]) - 1
					lost += 1
					break
		w.hud.notice("Your %s has been destroyed%s." % [what, " with %d weapon%s in it" % [lost, "" if lost == 1 else "s"] if lost > 0 else ""])
	else:
		var left := armed(owner, "nuclear" if nuclear else "special")
		w.hud.notice("%s's %s has been destroyed%s." % [d.name_of(owner), what, "" if left else (": it can no longer make or use those weapons" + (" except from its submarines" if nuclear and at_sea(owner) else ""))])

## A Nuclear Reactor destroyed (world.destroy_building): its core spreads.
func reactor_destroyed(b: Dictionary) -> void:
	var by := int(b.get("last_by", -1))
	_zone("fallout", b.root.position, 48.0, 600.0, 1.2, by, 0.3)
	w.hud.notice("REACTOR DESTROYED: %s Nuclear Reactor has burst open; a radioactive plume spreads downwind." % ("your" if int(b.owner) == 0 else w.diplomacy.name_of(int(b.owner)) + "'s"))
	if by >= 0 and by != int(b.owner):
		_incident("reactor", "nuclearReactor", by, [int(b.owner)])

## A nuclear weapon detonated in orbit (space.gd): most satellites, everyone's.
func orbital_burst(owner: int) -> int:
	var lost := _satellites(0.7, "a nuclear detonation in orbit")
	if w.get("space") != null and w.space != null:
		w.space.debris = minf(100.0, w.space.debris + 40.0)
	if w.get("defcon") != null and w.defcon != null:
		w.defcon.nuclear_used(owner, [])
	_incident("space", "nuclearAsat", owner, [])
	return lost

# ---------------------------------------------------------------- zones

func _zone(kind: String, at: Vector3, radius: float, seconds: float, strength: float, owner: int, drift: float, town = null) -> Dictionary:
	var z := {"kind": kind, "at": at, "radius": radius, "strength": strength, "born": w.game_time, "until": w.game_time + seconds,
		"owner": owner, "drift": drift, "town": town, "decal": null}
	_dress(z)
	zones.append(z)
	return z

## The poisoned ground drawn on the terrain: a disc of rings that follows the
## ground, in the zone's colour, thickest at the centre and fading to its edge
## (a projected decal broke up on the terrain's own shader).
func _dress(z: Dictionary) -> void:
	if w.effects == null:
		return
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.effects.add_child(mi)
	z.decal = mi
	z.drawn_at = Vector3.INF
	_shape(z)

## (Re)builds the disc over the ground where the zone now lies.
func _shape(z: Dictionary) -> void:
	var mi: MeshInstance3D = z.decal
	var c: Color = ZONE_COLOUR[z.kind]
	var r: float = float(z.radius)
	var centre: Vector3 = z.at
	var sea: float = float(w.map.seaLevel)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_pts := []
	for ring in range(RINGS + 1):
		var f := float(ring) / RINGS
		var pts := []
		for k in range(SEGMENTS):
			var a := TAU * k / SEGMENTS
			var x: float = centre.x + cos(a) * r * f
			var zz: float = centre.z + sin(a) * r * f
			pts.append(Vector3(x - centre.x, maxf(w.height_at(x, zz), sea) + 0.6, zz - centre.z))
		ring_pts.append(pts)
	for ring in range(RINGS):
		var a0 := Color(c, 0.5 * (1.0 - pow(float(ring) / RINGS, 1.6)))
		var a1 := Color(c, 0.5 * (1.0 - pow(float(ring + 1) / RINGS, 1.6)))
		for k in range(SEGMENTS):
			var k2 := (k + 1) % SEGMENTS
			for v in [[ring_pts[ring][k], a0], [ring_pts[ring + 1][k], a1], [ring_pts[ring + 1][k2], a1],
					[ring_pts[ring][k], a0], [ring_pts[ring + 1][k2], a1], [ring_pts[ring][k2], a0]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	mi.mesh = st.commit()
	mi.global_position = Vector3(centre.x, 0.0, centre.z)
	z.drawn_at = centre

## Strength now: fallout follows the 7-10 rule (a sevenfold time, a tenth the dose).
func strength_of(z: Dictionary) -> float:
	var age: float = maxf(0.0, w.game_time - float(z.born))
	var s: float = float(z.strength)
	if z.kind == "fallout":
		s *= pow(1.0 + age / 30.0, -0.6)
	return s

func contaminated(at: Vector3, kinds := ["fallout"]) -> bool:
	for z in zones:
		if z.kind in kinds and Vector2(at.x - z.at.x, at.z - z.at.z).length() <= float(z.radius):
			return true
	return false

## Whether `u` stands in a riot-agent cloud: no bunker shelters it (bunker.gd).
func flushed(u: Dictionary) -> bool:
	return not zones.is_empty() and u.has("node") and contaminated(u.node.position, ["riot"])

func update(delta: float) -> void:
	_tick += delta
	_ai_tick += delta
	for z in zones:
		if float(z.drift) > 0.0 and w.game_time - float(z.born) < 120.0:
			z.at += Vector3(wind.x, 0, wind.y) * float(z.drift) * delta * 4.0
		if is_instance_valid(z.decal):
			if z.at.distance_to(z.get("drawn_at", z.at)) > 2.0:
				_shape(z)
			z.decal.transparency = 1.0 - clampf(0.45 + 0.6 * strength_of(z), 0.3, 1.0) * (0.85 + 0.15 * sin(w.game_time * 2.0))
	if _tick < 1.0:
		return
	var dt := _tick
	_tick = 0.0
	for z in zones.duplicate():
		if w.game_time >= float(z.until) or (z.town != null and z.town.dead):
			_end(z)
			continue
		_harm(z, dt)
		if z.kind == "bio" and z.town != null and w.game_time - float(z.get("spread_at", z.born)) >= SPREAD_EVERY:
			z.spread_at = w.game_time
			_spread(z)
	# Investigations end: the attack is attributed, and goes to the UN.
	for inc in incidents:
		if not inc.get("attributed", true) and w.game_time >= float(inc.time) + INVESTIGATION:
			inc.attributed = true
			_verdict(inc)
	if w.research != null and w.research.done("nuclearBreakout") and not 0 in broken_out:
		break_out(0)
	if _ai_tick >= 15.0:
		_ai_tick = 0.0
		_ai_use()

func _end(z: Dictionary) -> void:
	zones.erase(z)
	if is_instance_valid(z.decal):
		z.decal.queue_free()
	if w.research != null:
		w.research._recompute()

func _harm(z: Dictionary, dt: float) -> void:
	var s := strength_of(z)
	var table: Dictionary = HARM[z.kind]
	var r: float = float(z.radius)
	for u in w.units:
		if u.dead or (u.get("fly", false) and w.airborne(u)):
			continue
		if Vector2(u.node.position.x - z.at.x, u.node.position.z - z.at.z).length() > r:
			continue
		var cls := "naval" if u.get("naval", false) else ("infantry" if u.key in w.infantry_keys else "vehicle")
		if z.kind == "incap" and cls == "infantry":
			u.disabled_until = maxf(float(u.get("disabled_until", 0.0)), w.game_time + 3.0)   # unconscious
		var amount: float = float(u.max_hp) * float(table[cls]) * s * dt
		if amount <= 0.0:
			continue
		u.hp -= amount
		u.last_hit = w.game_time
		if u.hp <= 0.0:
			w.kill(u)
	for b in w.buildings:
		if b.dead or Vector2(b.root.position.x - z.at.x, b.root.position.z - z.at.z).length() > r + b.footprint * 0.3:
			continue
		if z.kind == "fallout":
			b.disabled_until = maxf(float(b.get("disabled_until", 0.0)), w.game_time + 2.0)   # no one works in it
			b.hp -= float(b.max_hp) * float(table.building) * s * dt
			if b.hp <= 0.0:
				w.destroy_building(b)
				continue
		if b.key in TOWNS and int(b.owner) == 0 and w.economy != null and z.kind in ["fallout", "chemical", "anthrax", "bio"]:
			w.economy.civilians = maxf(0.0, w.economy.civilians - 0.6 * s * dt)

## An outbreak at a town.
func _infect(town: Dictionary, owner: int) -> void:
	if zones.any(func(z): return z.kind == "bio" and z.town == town):
		return
	_zone("bio", town.root.position, 34.0, 300.0, 1.0, owner, 0.0, town)
	var d: Node = w.diplomacy
	if int(town.owner) == 0:
		w.hud.notice("OUTBREAK in your %s: a disease spreads among its people and soldiers." % town.def.name)
	elif int(town.owner) == owner and owner == 0:
		w.hud.notice("BLOWBACK: the disease has reached your own %s." % town.def.name)
	elif d.at_war(0, int(town.owner)) or owner == 0:
		w.hud.notice("Outbreak reported in %s's %s." % [d.name_of(int(town.owner)), town.def.name])

func _town_near(at: Vector3, r: float):
	var best = null
	for b in w.buildings:
		if not b.dead and b.key in TOWNS and b.root.position.distance_to(at) <= r and (best == null or b.root.position.distance_to(at) < best.root.position.distance_to(at)):
			best = b
	return best

func _spread(z: Dictionary) -> void:
	if randf() > 0.4:
		return
	var best = null
	for b in w.buildings:
		if b.dead or not b.key in TOWNS or b == z.town or zones.any(func(o): return o.kind == "bio" and o.town == b):
			continue
		var dist: float = b.root.position.distance_to(z.town.root.position)
		if dist <= SPREAD_RANGE and (best == null or dist < best.root.position.distance_to(z.town.root.position)):
			best = b
	if best != null:
		_infect(best, int(z.owner))

func bonuses() -> Dictionary:
	var hit := 0
	for b in w.buildings:
		if not b.dead and int(b.owner) == 0 and b.key in TOWNS and zones.any(func(z): return z.kind != "riot" and Vector2(b.root.position.x - z.at.x, b.root.position.z - z.at.z).length() <= float(z.radius)):
			hit += 1
	if hit == 0:
		return {}
	return {"happiness": -minf(15.0, 5.0 * hit), "incomePct": -minf(0.2, 0.05 * hit)}

func ai_income_mult(owner: int) -> float:
	var hit := 0
	for z in zones:
		if z.town != null and int(z.town.owner) == owner:
			hit += 1
	return maxf(0.6, 1.0 - 0.06 * hit)

# ---------------------------------------------------------------- breakout

## A threshold state builds the bomb.
func break_out(owner: int) -> void:
	if owner in broken_out:
		return
	broken_out.append(owner)
	var d: Node = w.diplomacy
	var who := "You have" if owner == 0 else "%s has" % d.name_of(owner)
	w.hud.notice("NUCLEAR BREAKOUT: %s built a nuclear weapon%s. The IAEA reports it to the Security Council." % [who, " and left the NPT" if str(Cbrn.treaty(w, owner, "npt")) == "party" else ""])
	if w.get("defcon") != null and w.defcon != null:
		w.defcon.tension = minf(79.0, w.defcon.tension + 15.0)
	# Its neighbours may follow (cbrn_data.THRESHOLD "after").
	var discoveries: Dictionary = w.map.research.discoveries
	for id in Cbrn.THRESHOLD:
		if Cbrn.THRESHOLD[id].after == Cbrn.ident(w, owner) and discoveries.has("nuclearBreakout"):
			var arsenal: String = Cbrn.arsenal_ids([id])[0]
			if not arsenal in discoveries.nuclearBreakout.nation:
				discoveries.nuclearBreakout.nation.append(arsenal)
	_incident("breakout", "nuke", owner, [])

# ---------------------------------------------------------------- the world's answer

func _incident(kind: String, weapon: String, by: int, victims: Array) -> void:
	var clean := []
	for v in victims:
		if int(v) != by and not int(v) in clean:
			clean.append(int(v))
	var inc := {"kind": kind, "weapon": weapon, "by": by, "victims": clean, "time": w.game_time, "attributed": not kind in ["chemical", "bio"]}
	incidents.append(inc)
	if inc.attributed:
		_verdict(inc)
	elif w.hud != null:
		w.hud.notice("A %s attack is reported; %s investigators are on their way (attribution in %ds)." % ["chemical" if kind == "chemical" else "biological", "OPCW" if kind == "chemical" else "UN", int(INVESTIGATION)])

func _verdict(inc: Dictionary) -> void:
	var kind: String = inc.kind
	var by: int = int(inc.by)
	var d: Node = w.diplomacy
	if CONDEMN.has(kind):
		for i in range(d.n):
			if i != by and not d.defeated(i):
				d.change(by, i, -float(CONDEMN[kind]))
		d.changed.emit()
		var what: String = {"chemical": "using chemical weapons", "bio": "using biological weapons", "dirty": "using a radiological bomb",
			"reactor": "destroying a nuclear reactor", "breakout": "building a nuclear weapon"}[kind]
		var source: String = {"chemical": "The OPCW attributes the attack: ", "bio": "UN investigators attribute it: "}.get(kind, "")
		w.hud.notice("%sthe world condemns %s for %s. Relations with every nation fall by %d." % [source, "you" if by == 0 else d.name_of(by), what, int(CONDEMN[kind])])
		if w.get("defcon") != null and w.defcon != null and kind != "breakout":
			w.defcon.tension = minf(79.0, w.defcon.tension + 10.0)
	if w.get("un") != null and w.un != null:
		w.un.wmd_used(kind, str(inc.weapon), by, inc.victims)

## Rivals use what they have: riot and nerve agents at the front, an
## incapacitant; anthrax, disease or chlorine only when fighting for survival.
func _ai_use() -> void:
	if w.ai == null or w.missiles == null:
		return
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		var owner: int = int(n.id)
		if n.defeated or not d.at_war(owner, 0) or float(n.get("tech", 0.0)) < 3.0:
			continue
		if not armed(owner, "special"):
			continue   # no laboratory, no chemical or biological weapons
		if w.game_time - float(n.get("wmd_at", -1000.0)) < 180.0:
			continue
		var desperate: bool = w.get("defcon") != null and w.defcon != null and w.defcon.existential(owner)
		var democracy: bool = w.get("support") != null and w.support != null and w.support.regime(owner) == "democracy"
		var options := []   # [key, chance a check]
		if Cbrn.has(w, owner, "riotAgent"): options.append(["riotAgent", 0.08])
		if Cbrn.has(w, owner, "chemical") and not democracy: options.append(["chemical", 0.12 if desperate else 0.05])
		if Cbrn.has(w, owner, "incapacitant"): options.append(["incapacitant", 0.05])
		if desperate and float(n.get("tech", 0.0)) >= 6.0:
			if Cbrn.has(w, owner, "anthrax"): options.append(["anthrax", 0.04])
			if Cbrn.has(w, owner, "bioweapon"): options.append(["bioweapon", 0.03])
		if desperate and not democracy and options.is_empty() and Cbrn.has(w, owner, "chlorine"):
			options.append(["chlorine", 0.05])
		var key := ""
		for o in options:
			if randf() < float(o[1]):
				key = o[0]
				break
		if key == "":
			continue
		var target := _ai_target(owner, key == "bioweapon")
		var platforms: Array = w.missiles.platforms_for(key, owner)
		if platforms.is_empty() or target == Vector3.INF:
			continue
		n.wmd_at = w.game_time
		w.missiles.fly(key, platforms[0].node.position + Vector3.UP * 3.0, target, owner)
		w.hud.notice("%s has fired %s at your %s!" % [d.name_of(owner), MISSILES[key].name.to_lower(), "town" if key == "bioweapon" else "troops"])
	# A threshold state at war may break out (cbrn_data.THRESHOLD).
	for n in w.ai.nations:
		var owner: int = int(n.id)
		var id := Cbrn.ident(w, owner)
		if n.defeated or owner in broken_out or not Cbrn.THRESHOLD.has(id):
			continue
		var after: String = Cbrn.THRESHOLD[id].after
		if after != "" and not broken_out.any(func(o): return Cbrn.ident(w, o) == after):
			continue
		if float(n.get("tech", 0.0)) >= 7.0 and not d.enemies_of(owner).is_empty() and randf() < 0.01:
			break_out(owner)

func _ai_target(owner: int, town: bool) -> Vector3:
	var home := Vector3.ZERO
	for b in w.buildings:
		if int(b.owner) == owner and b.key == "hq":
			home = b.root.position
	var best := Vector3.INF
	if town:
		for b in w.buildings:
			if int(b.owner) == 0 and not b.dead and b.key in TOWNS and (best == Vector3.INF or b.root.position.distance_to(home) < best.distance_to(home)):
				best = b.root.position
		return best
	for u in w.units:
		if int(u.owner) == 0 and not u.dead and u.key in w.infantry_keys and (best == Vector3.INF or u.node.position.distance_to(home) < best.distance_to(home)):
			best = u.node.position
	return best

func capture() -> Dictionary:
	var out := []
	for z in zones:
		out.append({"kind": z.kind, "at": [z.at.x, z.at.y, z.at.z], "radius": z.radius, "strength": z.strength, "born": z.born, "until": z.until,
			"owner": z.owner, "drift": z.drift, "town": [z.town.root.position.x, z.town.root.position.z] if z.town != null else null})
	return {"zones": out, "incidents": incidents, "wind": [wind.x, wind.y], "broken_out": broken_out}

func restore(data: Dictionary) -> void:
	for z in zones:
		if is_instance_valid(z.decal): z.decal.queue_free()
	zones.clear()
	for s in data.get("zones", []):
		var town = null
		if s.get("town") != null:
			town = _town_near(Vector3(float(s.town[0]), 0, float(s.town[1])), 6.0)
		var z := {"kind": str(s.kind), "at": Vector3(float(s.at[0]), float(s.at[1]), float(s.at[2])), "radius": float(s.radius), "strength": float(s.strength),
			"born": float(s.born), "until": float(s.until), "owner": int(s.owner), "drift": float(s.drift), "town": town, "decal": null}
		_dress(z)
		zones.append(z)
	incidents = Array(data.get("incidents", [])).map(func(i):
		var c: Dictionary = i.duplicate(true)
		c.by = int(c.by)
		c.victims = Array(c.get("victims", [])).map(func(v): return int(v))
		return c)
	broken_out = Array(data.get("broken_out", [])).map(func(v): return int(v))
	if data.has("wind"):
		wind = Vector2(float(data.wind[0]), float(data.wind[1]))
	if w.research != null:
		w.research._recompute()
