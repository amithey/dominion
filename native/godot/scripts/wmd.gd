extends RefCounted
## Weapons of mass destruction and the ground they poison.
## Research and sources: native/WMD-RESEARCH-2026-10-05.md.
##
## Nuclear warheads by yield (all need posture 2 to release: defcon.gd):
##   Tactical Nuclear Missile  5-10 kt (US W76-2, B61 low settings; Russia's
##                             Iskander warheads): a small blast, a small fallout
##   Nuclear Missile           ~100-300 kt strategic warhead: the city-killer
##   Thermonuclear Missile     ~1 Mt (US B83 1.2 Mt), after Thermonuclear Weapons:
##                             the US, Russia, China, the UK, France
##   Tsar Bomba                50 Mt, Russia only (30 October 1961): the largest
##                             explosion ever made; 97% of it fusion, so cleaner
##                             than its size
##   Neutron Warhead           enhanced radiation (US W70-3/W79, retired 1992;
##                             France tested one in 1980, China in 1988): kills the
##                             crews of armour and the infantry, spares buildings
##   High-Altitude Nuclear EMP no blast on the ground: a burst high above blacks out
##                             everything electronic in a very wide circle and
##                             knocks satellites out of orbit (Starfish Prime, 1962);
##                             in Russian, Chinese and North Korean doctrine
## Every nuclear detonation leaves FALLOUT: radioactive ground that drifts
## downwind and decays (the 7-10 rule). Inside it, infantry dies, crews sicken,
## buildings fall silent and crumble, no one may build, and towns empty.
##
## The EMP Missile becomes the HPM Cruise Missile (CHAMP, tested 2012; HiJENKS
## 2022): the United States, China and Russia only. It kills no one; along the
## last stretch of its flight it fires microwave pulses that knock out the
## electronics of vehicles, aircraft, ships and buildings, and fry drones.
##
## Other weapons of mass destruction, for the nations assessed to have them:
##   Chemical warhead  Russia (chloropicrin and riot agents in Ukraine, 13,000+
##                     recorded uses), North Korea (2,500-5,000 t of agents),
##                     Iran (pharmaceutical-based agents, assessed a CWC
##                     violation in 2024): a drifting cloud that kills infantry
##   Biological        Russia and North Korea (US-assessed offensive programmes):
##                     an outbreak that spreads from town to town, the attacker's
##                     own included
##   Dirty bomb        no state has ever used one; the nuclear powers and Iran have
##                     the material: a small blast and long-lived contamination
## Every use is recorded for the United Nations (un.gd) and turns the world
## against its user.

const Variants := preload("res://scripts/national_variants.gd")
const NUKE_POWERS := ["blue", "red", "green", "russia", "india", "israel", "uk", "north_korea", "pakistan"]
const NUCLEAR := ["tacticalNuke", "nuke", "hydrogenBomb", "tsarBomba", "neutronBomb", "nuclearEmp"]
const MISSILES := {
	"tacticalNuke": {"name": "Tactical Nuclear Missile", "icon": "TN", "buildTime": 45, "cost": {"money": 1400, "iron": 50, "silicon": 40, "uranium": 12},
		"dmg": 2600, "radius": 18, "speed": 60, "arc": true, "nuclear": true, "needsDiscovery": "nuclearProgram", "nation": NUKE_POWERS,
		"desc": "Low yield, 5-10 kt, like the US W76-2 or Russia's Iskander warheads: a battlefield weapon with a small fallout. Still a nuclear weapon: DEFCON 1 and the world's condemnation."},
	"hydrogenBomb": {"name": "Thermonuclear Missile", "icon": "H", "buildTime": 90, "cost": {"money": 3200, "iron": 100, "silicon": 80, "uranium": 45},
		"dmg": 7000, "radius": 62, "speed": 48, "arc": true, "nuclear": true, "needsDiscovery": "thermonuclear", "nation": ["blue", "red", "green", "russia", "uk"],
		"desc": "A two-stage hydrogen bomb of about a megaton, like the US B83 (1.2 Mt): a blast that erases a city and its surroundings, and a wide fallout for 7 minutes."},
	"tsarBomba": {"name": "Tsar Bomba", "icon": "TSAR", "buildTime": 150, "cost": {"money": 6000, "iron": 160, "silicon": 100, "uranium": 90},
		"dmg": 14000, "radius": 105, "speed": 40, "arc": true, "nuclear": true, "needsDiscovery": "thermonuclear", "nation": ["russia"],
		"desc": "50 megatons, as on 30 October 1961: the largest explosion ever made, 3,300 times Hiroshima. 97% of it came from fusion, so its fallout is smaller than its blast. Russia only."},
	"neutronBomb": {"name": "Neutron Warhead", "icon": "N", "buildTime": 55, "cost": {"money": 1800, "silicon": 50, "uranium": 20},
		"dmg": 3200, "radius": 26, "speed": 60, "arc": true, "nuclear": true, "special": "neutron", "needsDiscovery": "enhancedRadiation", "nation": ["blue", "red", "green", "russia"],
		"desc": "Enhanced radiation, like the US W70-3 and W79 (retired 1992; France tested one in 1980, China in 1988): a small blast but a flood of neutrons that kills tank crews and infantry and spares buildings. Short-lived radiation."},
	"nuclearEmp": {"name": "High-Altitude Nuclear EMP", "icon": "HEMP", "buildTime": 60, "cost": {"money": 2200, "silicon": 60, "uranium": 25},
		"dmg": 0, "radius": 110, "speed": 55, "arc": true, "nuclear": true, "special": "hemp", "needsDiscovery": "nuclearProgram", "nation": ["blue", "red", "russia", "north_korea"],
		"desc": "A warhead burst high above the target: no blast on the ground, but everything electronic in a very wide circle goes dark for 90 s, aircraft in the air are crippled, drones fall, and satellites are knocked out (Starfish Prime, 1962, darkened Hawaii 1,445 km away). A nuclear detonation all the same."},
	"dirtyBomb": {"name": "Radiological (Dirty) Bomb", "icon": "RDD", "buildTime": 25, "cost": {"money": 500, "iron": 20, "uranium": 8},
		"dmg": 300, "radius": 8, "speed": 70, "special": "dirty", "nation": NUKE_POWERS + ["gold"],
		"desc": "A conventional charge wrapped round radioactive material. No state has ever used one (Chechen fighters hid one in a Moscow park in 1995). It kills few, but contaminates the ground for 6 minutes: nobody builds, towns empty. A crime the world will not forgive."},
	"chemical": {"name": "Chemical Warhead", "icon": "CW", "buildTime": 22, "cost": {"money": 450, "iron": 20, "oil": 10},
		"dmg": 30, "radius": 4, "speed": 75, "special": "chemical", "nation": ["russia", "north_korea", "gold"],
		"desc": "A nerve or choking agent: a cloud that drifts downwind for 90 s and kills infantry (armour crews are protected). Banned by the 1993 Chemical Weapons Convention; Russia uses chloropicrin in Ukraine, North Korea holds 2,500-5,000 tonnes, Iran develops pharmaceutical-based agents."},
	"bioweapon": {"name": "Biological Warhead", "icon": "BW", "buildTime": 50, "cost": {"money": 900, "silicon": 20, "food": 60},
		"dmg": 0, "radius": 4, "speed": 70, "special": "bio", "nation": ["russia", "north_korea"],
		"desc": "An engineered disease released over a town: an outbreak that sickens its people and its soldiers and spreads to the nearest towns, whoever holds them, yours too. Banned by the 1972 Biological Weapons Convention; the United States assesses that Russia and North Korea keep offensive programmes."},
}
const DISCOVERIES := {
	"thermonuclear": {"name": "Thermonuclear Weapons", "cost": 1000, "branch": "strategic", "era": 4, "nation": ["blue", "red", "green", "russia", "uk"],
		"reqDiscovery": "nuclearProgram", "reqBuilding": "nuclearReactor", "fx": {},
		"desc": "The two-stage hydrogen bomb (the US 1952, the USSR 1955, the UK 1957, China 1967, France 1968): unlocks the Thermonuclear Missile, and for Russia the Tsar Bomba."},
	"enhancedRadiation": {"name": "Enhanced Radiation Weapons", "cost": 800, "branch": "strategic", "era": 4, "nation": ["blue", "red", "green", "russia"],
		"reqDiscovery": "nuclearProgram", "reqBuilding": "nuclearReactor", "fx": {},
		"desc": "The neutron bomb: a small fusion warhead that kills by radiation rather than blast. Unlocks the Neutron Warhead."},
}
## Each contamination: radius as a share of the blast, how long it lasts,
## its strength (1 = a fission warhead's fallout), and how it drifts.
const FALLOUT := {
	"tacticalNuke": [0.8, 150.0, 0.6], "nuke": [0.8, 300.0, 1.0], "hydrogenBomb": [0.9, 420.0, 1.3],
	"tsarBomba": [0.85, 480.0, 1.0], "neutronBomb": [0.75, 60.0, 1.6],
}
## Damage a second at strength 1, as a share of health, by kind of zone and target.
const HARM := {
	"fallout": {"infantry": 0.03, "vehicle": 0.01, "naval": 0.005, "building": 0.004},
	"chemical": {"infantry": 0.06, "vehicle": 0.004, "naval": 0.0, "building": 0.0},
	"bio": {"infantry": 0.012, "vehicle": 0.003, "naval": 0.0, "building": 0.0},
}
const ZONE_COLOUR := {"fallout": Color(0.75, 0.95, 0.15), "chemical": Color(0.85, 0.85, 0.2), "bio": Color(0.75, 0.4, 0.95)}
const CONDEMN := {"chemical": 20.0, "bio": 30.0, "dirty": 15.0}
const TOWNS := ["hq", "cityCenter", "villageCenter"]
const HPM_SECONDS := 45.0
const HEMP_SECONDS := 90.0
const SPREAD_EVERY := 40.0
const SPREAD_RANGE := 170.0

var w: Node
var zones: Array = []        # {kind, at, radius, strength, born, until, owner, drift, town, decal}
var incidents: Array = []    # {kind, weapon, by, victims, time}: for the United Nations
var wind := Vector2.RIGHT
var _tick := 0.0
var _ai_tick := 0.0

func _init(world: Node) -> void:
	w = world
	wind = Vector2.RIGHT.rotated(randf() * TAU) * 0.25

## Registers the weapons and the discoveries (modern_warfare.apply).
static func apply(world: Node) -> void:
	var types: Dictionary = world.map.missiles.get("types", {})
	for key in MISSILES:
		types[key] = MISSILES[key].duplicate(true)
	if types.has("nuke"):
		types.nuke.nuclear = true
		types.nuke.desc = "A strategic warhead of a few hundred kilotons: the city-killer. Its fallout poisons the ground for 5 minutes. Released only at posture 2; the whole world will condemn it."
	if types.has("emp"):
		types.emp.name = "HPM Cruise Missile"
		types.emp.dmg = 0
		types.emp.radius = 15
		types.emp.nation = ["blue", "red", "russia"]
		types.emp.desc = "A high-power microwave cruise missile (CHAMP, tested 2012; HiJENKS, 2022): no blast and no deaths. Over the last stretch of its flight it fires three microwave pulses that knock out the electronics of vehicles, aircraft, ships and buildings for 45 s and bring drones down. The United States, China and Russia only."
	var discoveries: Dictionary = world.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)

static func is_nuclear(key: String) -> bool:
	return key in NUCLEAR

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
			_hemp(at, radius, owner)
		"dirty":
			_zone("fallout", at, 26.0, 360.0, 0.45, owner, 0.15)
			_incident("dirty", key, owner, struck)
		"chemical":
			_zone("chemical", at, 22.0, 90.0, 1.0, owner, 0.5)
			_incident("chemical", key, owner, struck + _owners_near(at, 22.0, owner))
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
	if is_nuclear(key):
		_incident("nuclear", key, owner, struck)

func _owners_near(at: Vector3, r: float, except: int) -> Array:
	var out := []
	for b in w.buildings:
		if not b.dead and int(b.owner) != except and not int(b.owner) in out and b.root.position.distance_to(at) <= r + 10.0:
			out.append(int(b.owner))
	return out

## The HPM missile's three pulses over the last stretch of its flight.
func _hpm(at: Vector3, from: Vector3, radius: float, owner: int) -> void:
	var start: Vector3 = from if from != Vector3.INF else at
	for f in [0.6, 0.8, 1.0]:
		var p: Vector3 = start.lerp(at, f)
		p.y = maxf(w.height_at(p.x, p.z), float(w.map.seaLevel))
		_blackout(p, radius, HPM_SECONDS, owner, false)
		w.effects.emp_flash(p, radius)

## A burst high above: everything electronic dark in a very wide circle.
func _hemp(at: Vector3, radius: float, owner: int) -> void:
	_blackout(at, radius, HEMP_SECONDS, owner, true)
	w.effects.emp_flash(at + Vector3.UP * 60.0, radius)
	# Satellites caught by the burst (Starfish Prime crippled a third of those in low orbit).
	var s = w.get("space")
	if s != null:
		var lost := 0
		for o in s.sats:
			for kind in s.KINDS:
				for i in range(s.count(o, kind)):
					if randf() < 0.3:
						s.sats[o][kind] = s.count(o, kind) - 1
						lost += 1
		if lost > 0:
			w.hud.notice("SPACE: the high-altitude burst knocked %d satellites out of orbit." % lost)
			if w.research != null: w.research._recompute()

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
const RINGS := 7
const SEGMENTS := 36

func _dress(z: Dictionary) -> void:
	if w.effects == null:
		return
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
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
	var ground := func(x: float, zz: float) -> float: return maxf(w.height_at(x, zz), sea) + 0.6
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
			pts.append(Vector3(x - centre.x, ground.call(x, zz), zz - centre.z))
		ring_pts.append(pts)
	var alpha := func(ring: int) -> float: return 0.5 * (1.0 - pow(float(ring) / RINGS, 1.6))
	for ring in range(RINGS):
		for k in range(SEGMENTS):
			var k2 := (k + 1) % SEGMENTS
			var a0: Color = Color(c, alpha.call(ring))
			var a1: Color = Color(c, alpha.call(ring + 1))
			var quad := [[ring_pts[ring][k], a0], [ring_pts[ring + 1][k], a1], [ring_pts[ring + 1][k2], a1],
				[ring_pts[ring][k], a0], [ring_pts[ring + 1][k2], a1], [ring_pts[ring][k2], a0]]
			for v in quad:
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

func update(delta: float) -> void:
	_tick += delta
	_ai_tick += delta
	# Drift and glow every frame (cheap: a handful of zones).
	for z in zones:
		if float(z.drift) > 0.0 and w.game_time - float(z.born) < 120.0:
			z.at += Vector3(wind.x, 0, wind.y) * float(z.drift) * delta * 4.0
		if is_instance_valid(z.decal):
			if z.at.distance_to(z.get("drawn_at", z.at)) > 2.0:
				_shape(z)   # it has drifted: lay it over the new ground
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
		# Towns empty: people flee, fall sick, die.
		if b.key in TOWNS and int(b.owner) == 0 and w.economy != null:
			w.economy.civilians = maxf(0.0, w.economy.civilians - 0.6 * s * dt)

## An outbreak at a town.
func _infect(town: Dictionary, owner: int) -> void:
	if zones.any(func(z): return z.kind == "bio" and z.town == town):
		return
	_zone("bio", town.root.position, 34.0, 300.0, 1.0, owner, 0.0, town)
	var d: Node = w.diplomacy
	if int(town.owner) == 0:
		w.hud.notice("OUTBREAK in your %s: an engineered disease spreads among its people and soldiers." % town.def.name)
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

## The disease jumps to the nearest town not yet infected, whoever holds it.
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

## The player's towns poisoned or sick: unhappiness and lost income (research._recompute).
func bonuses() -> Dictionary:
	var hit := 0
	for b in w.buildings:
		if not b.dead and int(b.owner) == 0 and b.key in TOWNS and zones.any(func(z): return Vector2(b.root.position.x - z.at.x, b.root.position.z - z.at.z).length() <= float(z.radius)):
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

# ---------------------------------------------------------------- the world's answer

func _incident(kind: String, weapon: String, by: int, victims: Array) -> void:
	var clean := []
	for v in victims:
		if int(v) != by and not int(v) in clean:
			clean.append(int(v))
	incidents.append({"kind": kind, "weapon": weapon, "by": by, "victims": clean, "time": w.game_time})
	var d: Node = w.diplomacy
	if CONDEMN.has(kind):
		for i in range(d.n):
			if i != by and not d.defeated(i):
				d.change(by, i, -float(CONDEMN[kind]))
		d.changed.emit()
		var what: String = {"chemical": "chemical weapons", "bio": "a biological weapon", "dirty": "a radiological bomb"}[kind]
		w.hud.notice("The world condemns %s for using %s. Relations with every nation fall by %d." % ["you" if by == 0 else d.name_of(by), what, int(CONDEMN[kind])])
		if w.get("defcon") != null and w.defcon != null:
			w.defcon.tension = minf(79.0, w.defcon.tension + 10.0)
	if w.get("un") != null and w.un != null:
		w.un.wmd_used(kind, weapon, by, clean)

## Rivals that have them use chemical weapons at the front; a biological
## weapon only when fighting for survival.
func _ai_use() -> void:
	if w.ai == null or w.missiles == null:
		return
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		var owner: int = int(n.id)
		if n.defeated or not d.at_war(owner, 0) or float(n.get("tech", 0.0)) < 3.0:
			continue
		if w.game_time - float(n.get("wmd_at", -1000.0)) < 180.0:
			continue
		var me: String = preload("res://scripts/national_arsenal.gd").identity(w, owner)
		var key := ""
		var desperate: bool = w.get("defcon") != null and w.defcon != null and w.defcon.existential(owner)
		if Variants.admits(MISSILES.bioweapon.nation, me) and desperate and float(n.get("tech", 0.0)) >= 6.0 and randf() < 0.05:
			key = "bioweapon"
		elif Variants.admits(MISSILES.chemical.nation, me) and randf() < 0.06:
			key = "chemical"
		if key == "":
			continue
		var target := _ai_target(owner, key == "bioweapon")
		var home = null
		for b in w.buildings:
			if int(b.owner) == owner and not b.dead and b.key in ["missileSilo", "hq"]:
				home = b
		if home == null or target == Vector3.INF:
			continue
		n.wmd_at = w.game_time
		w.missiles.fly(key, home.root.position + Vector3.UP * 3.0, target, owner)
		w.hud.notice("%s has fired a %s at your %s!" % [d.name_of(owner), MISSILES[key].name.to_lower(), "town" if key == "bioweapon" else "troops"])

## Where a rival aims: the player's infantry nearest it, or a town for a disease.
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
	return {"zones": out, "incidents": incidents, "wind": [wind.x, wind.y]}

func restore(data: Dictionary) -> void:
	for z in zones:
		if is_instance_valid(z.decal): z.decal.queue_free()
	zones.clear()
	for s in data.get("zones", []):
		var town = null
		if s.get("town") != null:
			var at := Vector3(float(s.town[0]), 0, float(s.town[1]))
			town = _town_near(at, 6.0)
		var z := {"kind": str(s.kind), "at": Vector3(float(s.at[0]), float(s.at[1]), float(s.at[2])), "radius": float(s.radius), "strength": float(s.strength),
			"born": float(s.born), "until": float(s.until), "owner": int(s.owner), "drift": float(s.drift), "town": town, "decal": null}
		_dress(z)
		zones.append(z)
	incidents = Array(data.get("incidents", []))
	if data.has("wind"):
		wind = Vector2(float(data.wind[0]), float(data.wind[1]))
	if w.research != null:
		w.research._recompute()
