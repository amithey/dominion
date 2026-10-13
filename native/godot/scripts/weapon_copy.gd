extends RefCounted
## Player-facing descriptions of existing game mechanics, never real-world
## performance figures. Shared by production, stockpile and ship launch menus.
const ROLES := {
	"cluster": "Anti-unit strike: strong against troop groups; weak against buildings.",
	"antiShip": "Anti-ship strike: triple damage to ships; only a quarter of normal damage on land.",
	"penetrator": "Bunker-buster: triple damage to buildings and ignores bunker protection. Conventional versions are weak against exposed troops.",
	"thermobaric": "Anti-infantry blast: ignores bunker protection; weaker against vehicles and solid buildings.",
	"antiRadar": "Radar suppression: homes on enemy air-defence radar within 40 m of your aim point, deals triple damage to emitters and disables them for 30 seconds.",
	"emp": "Electronic disruption: microwave pulses disable electronics along the flight path. No explosive blast.",
	"hemp": "Wide-area nuclear EMP: causes a blackout and damages satellites. No ground blast; nuclear escalation still applies.",
	"mirv": "Multiple nuclear warheads: releases three additional warheads around the target, causing several impacts.",
	"neutron": "Anti-crew nuclear strike: strong against people and vehicle crews; buildings take little damage near the centre and none farther out.",
	"hgv": "Glide strike: manoeuvring flight with reduced interception chances; extra damage to ships. It can still be intercepted.",
	"brahmos": "Fast strike against land or sea targets; double damage to ships.",
	"burevestnik": "Nuclear-powered strike: leaves a radioactive trail along the flight path as well as the target effects.",
	"dirty": "Radiological strike: contaminates the area with lasting fallout; this is not a nuclear detonation.",
	"chemical": "Chemical area denial: leaves toxic clouds and ground contamination that continue to harm exposed units.",
	"chlorine": "Chemical area denial: leaves a weaker, shorter-lived toxic cloud.",
	"riot": "Riot-agent cloud: drives troops out of cover and disrupts them; counts as chemical use in war.",
	"incapacitant": "Incapacitating cloud: temporarily disables exposed infantry; counts as chemical use in war.",
	"anthrax": "Persistent biological contamination: creates a long-lived hazardous area.",
	"bio": "Biological attack: can start an outbreak in a nearby town; otherwise contaminates the target area.",
}
const PLATFORMS := {
	"ground":"Missile silo", "air":"Ready strike aircraft", "drone":"Ready drone or FPV team",
	"air_or_sea":"Ready strike aircraft or compatible warship", "sea":"Compatible warship",
	"sub":"Strategic submarine", "strategic":"Missile silo or strategic submarine",
	"ground_or_sea":"Missile silo or compatible warship",
}
const FAMILIES := {"tactical":"Tactical strike", "ballistic":"Ballistic strike", "cruise":"Cruise missile", "hypersonic":"Hypersonic strike", "cluster":"Cluster munition", "emp":"Electronic attack", "antiShip":"Anti-ship missile", "nuke":"Strategic nuclear"}

static func display_name(w: Node, key: String) -> String:
	var name: String = str(w.missiles.def_of(key).get("name", key))
	return name + " · " + str(FAMILIES[key]) if FAMILIES.has(key) else name

static func role(def: Dictionary, key: String) -> String:
	var special: String = str(def.get("special", ""))
	if ROLES.has(special): return ROLES[special]
	if def.get("sub_only", false): return "Coastal nuclear strike: launched by a strategic submarine; target must be on or near the sea."
	if bool(def.get("nuclear", key == "nuke")): return "Nuclear area strike: massive blast and lasting fallout; can harm everything around the target."
	return "Area strike against units and buildings."

static func summary(w: Node, key: String) -> String:
	var def: Dictionary = w.missiles.def_of(key)
	if def.is_empty(): return "Unavailable weapon."
	var kind: String = preload("res://scripts/arsenal_catalog.gd").platform_kind(w, 0, key)
	var lines: Array[String] = ["Role: " + role(def, key), "Launch from: " + str(PLATFORMS.get(kind, "Compatible launch platform")) + "."]
	var special: String = str(def.get("special", ""))
	if special in ["emp", "hemp"]:
		lines.append("Effect radius: %d m · electronic effect, no blast damage." % int(def.get("radius", 0)))
	else:
		lines.append("Impact: %d m · base peak damage: %d HP." % [int(def.get("radius",0)), roundi(float(def.get("dmg",0)) * 1.75)])
	if bool(def.get("nuclear", key == "nuke")):
		lines.append("Consequence: nuclear release is required; use escalates the nuclear alert and lowers all nations' relations with you by 30.")
	elif special in ["dirty", "chemical", "chlorine", "riot", "incapacitant", "anthrax", "bio"]:
		lines.append("Consequence: hazardous contamination or agents; use can trigger international condemnation and UN action.")
	var desc: String = str(def.get("desc", ""))
	if "Future programme" in desc or "assessed capability" in desc:
		lines.append("Status: future programme / assessed capability in this scenario.")
	return "\n".join(PackedStringArray(lines))

static func tooltip(w: Node, key: String, production: bool) -> String:
	var lines := summary(w, key)
	if not str(w.missiles.def_of(key).get("special", "")) in ["emp", "hemp"]:
		lines += "\nDamage decreases toward the impact edge; target modifiers, defences and interception can change the outcome."
	if production:
		lines += "\nAction: pay the listed cost and queue ONE weapon. It enters storage when production finishes; this does not fire it."
	else:
		lines += "\nAction: enter targeting mode, then click the map to launch ONE stored weapon. Escape or right click cancels; choosing a weapon alone does not fire it."
		lines += "\nImpact can hit friendly forces too. Striking a nation at peace can start a war."
	return lines
