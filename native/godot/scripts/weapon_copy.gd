extends RefCounted
## Player-facing descriptions of existing game mechanics, never real-world
## performance figures. Shared by production, stockpile and ship launch menus.
const ROLES := {
	"cluster": "Anti-unit: strong against troops, weak against buildings.",
	"antiShip": "Anti-ship: triple damage to ships, a quarter on land.",
	"penetrator": "Bunker-buster: triple damage to buildings, ignores bunkers.",
	"thermobaric": "Anti-infantry blast: ignores bunkers, weak against vehicles.",
	"antiRadar": "Radar killer: triple damage to emitters, disables them for 30 s.",
	"emp": "Electronic strike: disables electronics on its path. No blast.",
	"hemp": "Nuclear EMP: blackout and satellite damage. No ground blast.",
	"mirv": "Nuclear: three more warheads around the target.",
	"neutron": "Anti-crew nuclear strike: kills people, spares buildings.",
	"hgv": "Glider: hard to intercept, extra damage to ships.",
	"brahmos": "Fast strike on land or sea. Double damage to ships.",
	"burevestnik": "Nuclear-powered: leaves a radioactive trail.",
	"dirty": "Radiation: lasting fallout, not a nuclear blast.",
	"chemical": "Chemical: toxic clouds that keep hurting exposed units.",
	"chlorine": "Chemical: a weaker, shorter cloud.",
	"riot": "Riot gas: drives troops out of cover. Counts as chemical war.",
	"incapacitant": "Disables infantry for a while. Counts as chemical war.",
	"anthrax": "Biological: a long-lasting danger zone.",
	"bio": "Biological: can start an outbreak in a nearby town.",
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
	if def.get("sub_only", false): return "Nuclear strike from a submarine, on or near the coast."
	if bool(def.get("nuclear", key == "nuke")): return "Nuclear strike: huge blast and lasting fallout."
	return "Area strike on units and buildings."

static func summary(w: Node, key: String) -> String:
	var def: Dictionary = w.missiles.def_of(key)
	if def.is_empty(): return "Unavailable weapon."
	var kind: String = preload("res://scripts/arsenal_catalog.gd").platform_kind(w, 0, key)
	var lines: Array[String] = [role(def, key), "Launch from: " + str(PLATFORMS.get(kind, "a compatible platform")) + "."]
	var special: String = str(def.get("special", ""))
	if special in ["emp", "hemp"]:
		lines.append("Radius %d m. No blast damage." % int(def.get("radius", 0)))
	else:
		lines.append("Blast %d m, up to %d damage." % [int(def.get("radius",0)), roundi(float(def.get("dmg",0)) * 1.75)])
	if bool(def.get("nuclear", key == "nuke")):
		lines.append("Needs nuclear release. Raises the nuclear alert; every nation likes you 30 less.")
	elif special in ["dirty", "chemical", "chlorine", "riot", "incapacitant", "anthrax", "bio"]:
		lines.append("Contaminates the area. The world and the UN may react.")
	var desc: String = str(def.get("desc", ""))
	if "Future programme" in desc or "assessed capability" in desc:
		lines.append("Future capability.")
	return "\n".join(PackedStringArray(lines))

static func tooltip(w: Node, key: String, production: bool) -> String:
	var lines := summary(w, key)
	if production:
		lines += "\nQueues one. It goes to storage when done."
	else:
		lines += "\nClick, then click the map to launch one. Esc cancels."
		lines += "\nIt can hit your own forces. Striking a nation at peace can start a war."
	return lines
