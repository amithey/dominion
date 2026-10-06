extends RefCounted
## Evidence and dates belong in native/ARSENAL-RESEARCH-2026-10-06.md.
## Operational equipment and playable future programmes are distinct. Existing
## unit/missile keys remain stable for saves; names and access belong to operators.
const Factions := preload("res://scripts/factions.gd")
const PROGRAM := "futureArsenal"
const UNIT_PROGRAMS := {
	"raider": ["usa"],
	"stealthFighter": ["india", "turkiye"],
	"sixthGen": ["usa", "china", "eu", "uk", "japan"],
	"wingman": ["usa", "china", "eu", "uk", "japan", "australia"],
	"railgunShip": ["china", "japan"], "orca": ["usa", "china"],
	"laserAD": ["usa", "china", "eu", "russia", "india", "japan", "turkiye"],
	"hpmVehicle": ["china", "japan"],
	"abmLauncher": ["uk", "india"],
}
const UNIT_NAMES := {
	"tank": {"eu": "Leopard 2A7V", "india": "Arjun Mk1"},
	"gunship": {"china": "Z-10"},
	"samLauncher": {"india": "Akash", "iraq": "Cheongung II (procurement programme)"},
	"jet": {"indonesia": "Rafale / F-16", "pakistan": "J-10C / JF-17 / F-16"},
	"submarine": {"eu": "Type 212A"},
	"drone": {"india": "Heron ISR", "pakistan": "Shahpar II / Burraq"},
	"abmLauncher": {"uk": "Sea Viper Evolution programme", "south_korea": "Patriot PAC-3"},
	"sixthGen": {"eu": "FCAS / GCAP programme", "uk": "GCAP programme", "japan": "GCAP programme"},
	"wingman": {"usa": "FQ-42 Vengeance", "australia": "MQ-28 Ghost Bat"},
	"corvette": {"uk": "Type 23 frigate", "brazil": "Tamandare frigate"},
	"destroyer": {"russia": "Udaloy-class", "north_korea": "Choe Hyon-class"},
	"gunboat": {"ukraine": "Island-class patrol boat", "iraq": "Patrol boat"},
	"atgmTeam": {"afghanistan": "Anti-armour rocket team"},
}
const ISR := ["eu", "india", "japan", "brazil"]
## Positive evidence for conventional missile families. Aircraft/ships are
## required where a national variant is air/sea launched. Lack of a record does
## not manufacture an arsenal for a new country. Custom nations supply missiles.
const MISSILES := {
	"tactical": {"usa": "PrSM", "china": "DF-15 / DF-16", "russia": "Iskander-M", "iran": "Fateh-110", "south_korea": "Hyunmoo-2", "ukraine": "ATACMS", "pakistan": "Fatah-1", "turkiye": "Bora", "israel": "LORA", "india": "Pralay", "north_korea": "KN-23"},
	"ballistic": {"usa": "PrSM", "china": "DF-21 / DF-26", "russia": "Iskander-M", "iran": "Qiam / Sejjil", "india": "Agni", "south_korea": "Hyunmoo-2", "saudi": "DF-3", "pakistan": "Shaheen", "turkiye": "Bora", "israel": "LORA", "north_korea": "Hwasong"},
	"cruise": {"usa": "Tomahawk", "china": "CJ-10", "russia": "Kalibr", "iran": "Soumar / Hoveyzeh", "eu": "SCALP / MdCN", "uk": "Storm Shadow / Tomahawk", "india": "BrahMos", "south_korea": "Hyunmoo-3", "pakistan": "Babur", "israel": "Delilah", "turkiye": "SOM", "ukraine": "Long Neptune", "north_korea": "Hwasal"},
	"antiShip": {"usa": "Naval Strike Missile / Harpoon", "china": "YJ-12B / YJ-18", "russia": "Oniks", "iran": "Noor", "eu": "Exocet", "uk": "Naval Strike Missile", "india": "BrahMos", "japan": "Type 25 SSM", "south_korea": "Haeseong", "saudi": "Harpoon / Exocet", "brazil": "Exocet", "indonesia": "Exocet / C-705", "ukraine": "Neptune", "north_korea": "Kumsong-3", "egypt": "Harpoon / Exocet", "australia": "Naval Strike Missile", "pakistan": "Zarb / Harbah", "israel": "Gabriel", "turkiye": "Atmaca"},
	"hypersonic": {"usa": "Dark Eagle programme", "china": "DF-17", "russia": "Kinzhal / Zircon", "india": "Long-range hypersonic programme", "iran": "Fattah (claimed capability)", "japan": "HVGP (initial deployment)"},
	"cluster": {"usa": "ATACMS cluster variant", "russia": "Iskander cluster variant", "ukraine": "ATACMS cluster variant", "china": "Tactical cluster variant"},
	"bunkerMissile": {"usa": "Tomahawk penetrator", "russia": "Kh-101 penetrator", "eu": "SCALP penetrator", "uk": "Storm Shadow penetrator", "turkiye": "SOM-B2"},
	"antiRadar": {"usa": "AGM-88 HARM", "eu": "AGM-88 HARM", "russia": "Kh-31P", "china": "YJ-91", "india": "Rudram", "israel": "AGM-88 HARM", "uk": "Anti-radiation missile programme", "ukraine": "AGM-88 HARM"},
	"thermobaricMissile": {"russia": "Thermobaric rocket payload"},
}
const MISSILE_PROGRAMS := {"hypersonic": ["usa", "india", "iran"], "antiRadar": ["uk"]}
const AIR := {"antiRadar": ["usa", "eu", "russia", "china", "india", "israel", "uk", "ukraine"], "bunkerMissile": ["russia", "eu", "uk", "turkiye"], "cruise": ["turkiye", "israel"], "tacticalNuke": ["usa", "eu"], "bunkerBuster": ["usa"], "tsarBomba": ["russia"], "nuclearCruise": ["usa", "russia", "eu"]}
const SEA := {"cruise": ["uk", "eu", "russia"], "nuke": ["uk", "eu"], "tacticalNuke": ["uk"], "mirv": ["uk", "eu"], "hydrogenBomb": ["uk", "eu"], "nuclearEmp": ["uk", "eu"], "nuclearCruise": ["israel"]}

static func programme_done(w: Node, owner: int) -> bool:
	if owner == 0:
		return w.research != null and w.research.done(PROGRAM)
	if w.ai != null:
		for n in w.ai.nations:
			if int(n.id) == owner:
				return float(n.get("tech", 0.0)) >= 10.0
	return false

static func unit_programme(w: Node, owner: int, key: String) -> bool:
	return Factions.identity(w, owner) in UNIT_PROGRAMS.get(key, []) or (key == "samLauncher" and Factions.identity(w, owner) == "iraq")

static func unit_blocked(w: Node, owner: int, key: String) -> String:
	return "Needs Future Arsenal programme" if unit_programme(w, owner, key) and not programme_done(w, owner) else ""

static func unit_status(w: Node, owner: int, key: String) -> String:
	if unit_programme(w, owner, key): return "development / trials"
	var id: String = Factions.identity(w, owner)
	if id in {"jet": ["south_korea"], "tank": ["turkiye"], "laserAD": ["israel"], "destroyer": ["north_korea"]}.get(key, []):
		return "initial delivery"
	return "operational category"

static func missile_name(w: Node, owner: int, key: String) -> String:
	if w.map.nations[owner].get("missile_names", {}).has(key):
		return str(w.map.nations[owner].missile_names[key])
	return str(MISSILES.get(key, {}).get(Factions.identity(w, owner), w.map.missiles.types.get(key, {}).get("generic", key)))

static func missile_blocked(w: Node, owner: int, key: String) -> String:
	var n: Dictionary = w.map.nations[owner]
	var id: String = Factions.identity(w, owner)
	if MISSILES.has(key):
		if n.has("missiles"):
			if not key in n.missiles:
				return "Not fielded by this nation"
		elif not MISSILES[key].has(id):
			return "Not fielded by this nation"
	if id in MISSILE_PROGRAMS.get(key, []) and not programme_done(w, owner):
		return "Needs Future Arsenal programme"
	return ""

static func platform_kind(w: Node, owner: int, key: String) -> String:
	var n: Dictionary = w.map.nations[owner]
	if n.get("missile_platforms", {}).has(key):
		return str(n.missile_platforms[key])
	var id: String = Factions.identity(w, owner)
	if key == "poseidon": return "sub"
	if key == "riotAgent": return "drone"
	if (key == "cruise" and id in ["eu", "uk"]) or (key == "hypersonic" and id == "russia") or (key == "antiShip" and id in ["eu", "brazil", "egypt"]): return "air_or_sea"
	if key == "antiShip" and id in ["uk", "saudi", "australia", "israel", "turkiye", "south_korea", "indonesia"]: return "sea"
	if id in AIR.get(key, []): return "air"
	if id in SEA.get(key, []): return "sea"
	if key in ["nuke", "mirv", "hydrogenBomb", "nuclearEmp"]: return "strategic"
	if key == "antiShip" or (key == "cruise" and id == "usa"): return "ground_or_sea"
	return "ground"

static func apply(w: Node) -> void:
	var d: Dictionary = w.map.research.discoveries
	d[PROGRAM] = {"name": "Future Arsenal", "branch": "strategic", "era": 5, "cost": 2800, "fx": {PROGRAM: 1.0}, "desc": "Develop trial systems and assessed strategic programmes. This is a hypothetical future capability, not confirmation of an operational arsenal."}
	if d.has("nextGenAbrams"):
		d.nextGenAbrams.era = 5
		d.nextGenAbrams.reqDiscovery = PROGRAM
		d.nextGenAbrams.desc = "Future M1E3 programme. Performance gains and built-in protection are game balance, not confirmed production specifications."
	for key in ["sixthGeneration", "railguns", "unmannedSubmarines", "glidePhaseInterceptor"]:
		if d.has(key):
			d[key].era = 5
			d[key].desc = "Future programme / trials. " + str(d[key].desc)
	d.enhancedRadiation.era = 5
	d.enhancedRadiation.reqDiscovery = PROGRAM
	d.thermonuclear.desc = "Thermonuclear payloads for eligible nuclear states. Historical and trial delivery systems also require Future Arsenal."
	# Explicit future-country research declarations extend country-specific gates.
	for n in w.map.nations:
		for key in n.get("research", []):
			if d.has(key) and d[key].has("nation"):
				var owners: Array = d[key].nation.duplicate() if d[key].nation is Array else [d[key].nation]
				var arsenal: String = {"usa": "blue", "china": "red", "eu": "green", "iran": "gold"}.get(str(n.get("id", "")), str(n.get("id", "")))
				if not arsenal in owners: owners.append(arsenal)
				d[key].nation = owners
	if d.has("sixthGeneration"):
		d.sixthGeneration.nation = ["blue", "red", "green", "uk", "japan"]
	d.fibreOpticDrones.nation = ["russia", "ukraine"]
	d.fibreOpticDrones.desc = "Fibre-optic FPV control for Russian and Ukrainian teams: resistant to radio jamming; the tether constrains use."
	for key in UNIT_NAMES:
		if w.unit_defs.has(key):
			w.unit_defs[key].generic = w.unit_defs[key].get("generic", w.unit_defs[key].name)
	for key in UNIT_PROGRAMS:
		if w.unit_defs.has(key):
			w.unit_defs[key].status = unit_status(w, 0, key)
			if id_for_player(w) in UNIT_PROGRAMS[key]:
				w.unit_defs[key].desc = "Future programme / trials. " + str(w.unit_defs[key].desc)
	for key in ["atgmTeam", "manpads", "laserAD", "abmLauncher", "submarine", "corvette", "destroyer"]:
		if not w.unit_defs.has(key): continue
		match key:
			"atgmTeam": w.unit_defs[key].desc = "Anti-armour team. Guidance differs by national system; combat values are game balance."
			"manpads": w.unit_defs[key].desc = "Infantry air defence: shoulder-launched or tripod-mounted according to the national system."
			"laserAD": w.unit_defs[key].desc = "Directed-energy air defence. Most national systems are programmes or trials; Iron Beam has initial operational delivery. Interception values are game balance."
			"abmLauncher": w.unit_defs[key].desc = "National missile defence system. Real systems defend different altitude and threat classes; displayed interception chances are game balance."
			"submarine": w.unit_defs[key].desc = "Attack submarine; propulsion differs by nation. Nuclear propulsion does not give it nuclear weapons."
			"corvette": w.unit_defs[key].desc = "Surface combatant: corvette or frigate according to the national class."
			"destroyer": w.unit_defs[key].desc = "Large missile combatant: destroyer, or missile frigate for nations using that class."
	var id: String = Factions.identity(w, 0)
	for key in UNIT_NAMES:
		if w.unit_defs.has(key) and UNIT_NAMES[key].has(id):
			w.unit_defs[key].name = UNIT_NAMES[key][id]
	if w.unit_defs.has("drone") and id in ISR:
		w.unit_defs.drone.desc = "Unarmed ISR aircraft: reconnaissance only. No attack payload is credited to this national variant."
	if w.unit_defs.has("wingman"):
		w.unit_defs.wingman.nation = ["blue", "red", "green", "uk", "japan", "australia"]
	if w.unit_defs.has("samLauncher") and id == "iraq":
		w.unit_defs.samLauncher.desc = "Procurement programme; delivery and operational readiness unconfirmed. Unlock through Future Arsenal."
	if w.unit_defs.has("jet") and id == "south_korea":
		w.unit_defs.jet.desc = "F-15K fleet with initial KF-21 deliveries. The first KF-21 block emphasises air combat; shared strike values are game balance."
	for key in MISSILES:
		if not w.map.missiles.types.has(key): continue
		var row: Dictionary = w.map.missiles.types[key]
		row.generic = row.name
		row.nation = preload("res://scripts/cbrn_data.gd").arsenal_ids(MISSILES[key].keys())
		if MISSILES[key].has(id): row.name = MISSILES[key][id]
		row.desc = "National missile family. Launch platform: %s. %s%s" % [platform_kind(w, 0, key), "Future programme / assessed capability. " if id in MISSILE_PROGRAMS.get(key, []) else "", str(row.desc)]
	for key in ["tsarBomba", "neutronBomb", "burevestnik", "poseidon", "nuclearAsat", "emp", "chemical", "chlorine", "incapacitant", "anthrax", "bioweapon"]:
		if w.map.missiles.types.has(key):
			w.map.missiles.types[key].desc = "Future / historical or assessed programme; not a verified operational payload inventory. " + str(w.map.missiles.types[key].desc)
	if w.map.missiles.types.has("bunkerBuster"):
		w.map.missiles.types.bunkerBuster.name = "B61-11 gravity bomb"
		w.map.missiles.types.bunkerBuster.desc = "Nuclear earth-penetrating gravity bomb. Requires a bomber or strike aircraft; not a silo-launched missile."
	w.map.missiles.types.poseidon.desc = "Future Russian underwater weapon programme. Requires a strategic submarine and a coastal target. Blast and wave effects are game balance."
	w.map.missiles.types.burevestnik.desc = "Future nuclear-powered cruise programme. The radioactive trail is a game effect; design and performance remain unverified."
	w.map.missiles.types.neutronBomb.desc = "Historical enhanced-radiation concept, recreated through future research. Relative damage to crews and buildings is a game abstraction."
	w.map.missiles.types.riotAgent.desc = "CS/CN riot agents. Their use in warfare is prohibited. Chloropicrin is a chemical warfare agent, not a riot agent."
	var own: Dictionary = w.map.nations[0]
	for key in own.get("unit_names", {}):
		if w.unit_defs.has(key): w.unit_defs[key].name = str(own.unit_names[key])
	for key in own.get("missile_names", {}):
		if w.map.missiles.types.has(key): w.map.missiles.types[key].name = str(own.missile_names[key])
	w.map.buildingDefs.missileSilo.desc = "Produces national conventional missile families. Ground-launched weapons fire here; aircraft and ship weapons need their proper launch platforms."
	w.map.buildingDefs.strategicComplex.desc = "Assembles and stores authorised national nuclear payloads. The payload determines whether an aircraft, strategic submarine or ground launcher is required."

static func id_for_player(w: Node) -> String:
	return Factions.identity(w, 0)
