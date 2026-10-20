extends RefCounted
## Short, plain descriptions (the player's report of 2026-10-20: "every text is unclear, you get lost in the
## words"): instead of a paragraph, a ROLE line (what it is for, in a few words) and two or three POINTS (how
## to use it, what it cannot do). The full description stays in the tooltip.
##
## Units listed in BRIEFS have hand-written briefs; any other unit or building is shortened by rule: its first
## sentence is the role, the next two short sentences are the points, and notes such as "United States only."
## or "Future programme / trials." become a TAG under the points.

const BRIEFS := {
	"worker": ["Builds, mines and clears forests", ["Right-click a building site to build it", "Right-click a deposit to mine it"]],
	"soldier": ["Basic infantry: cheap, everywhere", ["Best in numbers and in towns"]],
	"rocketSoldier": ["Infantry that kills tanks", ["Strong against armour and helicopters", "Weak against infantry"]],
	"sniper": ["Very long-range rifle", ["Keep it hidden behind your lines"]],
	"commando": ["Elite infantry for raids", ["Fast and deadly in small squads; expensive"]],
	"tank": ["Main battle tank", ["Heavy armour and gun: leads an attack", "Weak against rocket squads and aircraft"]],
	"apc": ["Fast armoured car", ["Kills infantry; screens your tanks", "Does not carry troops"]],
	"ifv": ["Armoured fighting vehicle", ["Strong against infantry and light vehicles", "Does not carry troops"]],
	"heavyAPC": ["Heavily armoured escort", ["Suppresses infantry; cannot fight tanks", "Does not carry troops"]],
	"artillery": ["Long-range gun", ["Fires far behind the line; needs a spotter", "Alt + right-click: shell a place", "Defenceless up close: escort it"]],
	"towedHowitzer": ["Cheap long-range gun", ["Alt + right-click: shell a place", "Slow to move; needs a spotter"]],
	"wheeledHowitzer": ["Mobile long-range gun", ["Alt + right-click: shell a place", "Moves fast between firing spots"]],
	"mlrs": ["Rocket artillery for wide areas", ["Alt + right-click: rocket a place", "Fragile: keep it behind the line"]],
	"himars": ["Precise guided rockets, far", ["Best against buildings and depots", "Fire, then move"]],
	"mortarTeam": ["Light indirect fire", ["Alt + right-click: a place to shell", "Weak against armour"]],
	"aaVehicle": ["Short-range air defence guns", ["Shoots helicopters, drones and jets near it"]],
	"samLauncher": ["Long-range air defence", ["Shoots down aircraft far around it", "Cannot hit ground targets"]],
	"shortRangeSAM": ["Mobile local air defence", ["Shoots aircraft and drones near it", "Cannot hit ground targets"]],
	"manpads": ["Infantry anti-aircraft missiles", ["Shoots helicopters and low aircraft"]],
	"laserAD": ["Laser air defence", ["Burns drones and rockets out of the sky"]],
	"abmLauncher": ["Missile defence", ["Intercepts incoming ballistic missiles near it"]],
	"ewVehicle": ["Jams drones", ["Enemy drones within 55 m mostly fail"]],
	"hpmVehicle": ["Microwave anti-drone weapon", ["Destroys every enemy drone within 45 m"]],
	"helicopter": ["Transport helicopter: 6 soldiers", ["Load: select troops, right-click the helicopter", "Unload: select it, press J"]],
	"heavyLift": ["Heavy transport helicopter: 12 places", ["Load: select troops, right-click the helicopter", "Unload: select it, press J", "Carries light vehicles and guns too"]],
	"gunship": ["Attack helicopter", ["Heavy, sustained fire on ground units", "Rocket squads and air defence threaten it"]],
	"scoutHelicopter": ["Unarmed scout helicopter", ["Sees far for your army", "Returns to a helipad for fuel"]],
	"navalHelicopter": ["Submarine-hunting helicopter", ["Finds and strikes submarines near it", "Cannot attack land targets"]],
	"jet": ["Strike fighter", ["Right-click a target: flies sorties from its airfield", "Can launch air missiles from your stock"]],
	"lightFighter": ["Light multirole fighter", ["Air combat first; light ground attack"]],
	"attackJet": ["Close air support jet", ["Strafes armour, infantry and buildings", "Needs fighter escort"]],
	"bomber": ["Heavy bomber", ["Carpet-bombs a wide area", "Slow: bring fighter escort"]],
	"stealthFighter": ["Stealth fighter", ["Enemy air defence sees it late", "Can launch air missiles from your stock"]],
	"drone": ["Armed drone", ["Cheap scout and striker", "Fragile; jammers bring it down"]],
	"loiterer": ["Loitering munition", ["Circles, then dives on a target. One use"]],
	"fpvTeam": ["FPV kamikaze drone team", ["Deadly to vehicles within 30 m", "Jammers stop most drones"]],
	"atgmTeam": ["Anti-tank missile team", ["Kills armour from cover"]],
	"medic": ["Combat medic", ["Heals infantry around it"]],
	"aewc": ["Flying radar", ["Reveals enemy aircraft and ships far around it", "Unarmed: escort it"]],
	"ewJet": ["Radar-jamming jet", ["Blinds enemy air defence near it", "Helps your strike aircraft get through"]],
	"maritimePatrol": ["Submarine-hunting aircraft", ["Finds and torpedoes submarines", "Cannot attack land targets"]],
	"heavyBomberDrone": ["Heavy bomber drone", ["Loiters low over the front, dropping bombs", "Slow and noisy: guns bring it down"]],
	"gunboat": ["Fast patrol boat", ["Guards the coast; shoots aircraft too"]],
	"corvette": ["Small warship", ["Fights ships near the coast", "Can launch sea missiles from your stock"]],
	"destroyer": ["Missile warship", ["Fights ships and aircraft", "Select it: fire missiles from your stock"]],
	"aegisCruiser": ["Missile-defence warship", ["Intercepts ballistic missiles near it"]],
	"type45": ["Air-defence destroyer", ["Shields the fleet from aircraft and missiles"]],
	"missileBoat": ["Fast missile boat", ["Hits ships hard", "Cannot fight aircraft or submarines"]],
	"submarine": ["Attack submarine", ["Torpedoes ships; hard to find", "Cannot attack land (except missiles from your stock)"]],
	"nuclearSub": ["Strategic missile submarine", ["Select it: fire missiles from your stock from the sea", "Torpedoes ships"]],
	"asFrigate": ["Submarine-hunting frigate", ["Escort your fleet against submarines"]],
	"carrier": ["Aircraft carrier: launches its jets", ["Attack: right-click an enemy: it stays ~100 m back, its jets strike", "Jets land back aboard to rearm", "No defence against submarines: escort it"]],
	"landingShip": ["Landing ship: carries 36 places", ["Load: select troops, right-click the ship", "Unload: press J (nearest coast) or Land at...", "Lightly armed: escort it"]],
	"seaDrone": ["Explosive sea drone", ["Rams a warship or harbour. One use"]],
	"orca": ["Uncrewed submarine", ["Quiet and cheap; torpedoes ships"]],
	"railgunShip": ["Railgun cruiser", ["Shells far inland; stops incoming missiles"]],
	"mineLayer": ["Lays minefields", ["Stop it for a few seconds: it mines that spot", "Mines hit enemy vehicles only"]],
	"mineClearer": ["Clears minefields", ["Drive it near enemy mines: it blasts a lane"]],
	"recoveryVehicle": ["Field repair vehicle", ["Repairs the most damaged vehicle near it", "Keep it behind the armour"]],
	"decoy": ["Fake weapon", ["Draws enemy fire away from the real one"]],
	"counterBatteryRadar": ["Finds enemy artillery", ["Reveals guns that fire near it; your fire on them +25%", "Unarmed"]],
	"coastalASM": ["Coastal anti-ship missiles", ["Hits warships far out at sea", "Cannot attack land or air"]],
	"scoutTeam": ["Scouts on foot", ["See far; spot for your artillery"]],
	"reconVehicle": ["Scout vehicle", ["See far; spot for your artillery"]],
	"machineGunTeam": ["Machine-gun team", ["Pins down infantry"]],
	"recoillessTeam": ["Recoilless rifle team", ["Cheap fire against light vehicles and bunkers"]],
	"directFire": ["Mobile gun", ["Good against vehicles and fortifications"]],
	"combatUGV": ["Armed ground robot", ["Holds a position or leads an assault", "Its loss costs no war support"]],
	"logisticsUGV": ["Supply robot", ["Infantry near it recover faster", "Unarmed"]],
	"robotDog": ["Armed robot dog", ["Scouts and fights in streets"]],
	"carrierJet": ["Carrier fighter", ["Launched by its carrier; lands back aboard"]],
	"carrierDrone": ["Carrier drone", ["Launched by its carrier; lands back aboard"]],
}

const TAG_PREFIXES := ["Future programme / trials.", "United States only.", "China only.", "Iran only.", "European Union only.", "Turkiye only.",
	"Israel only.", "UK only.", "Japan only.", "South Korea only.", "Saudi Arabia only.", "Indonesia only.", "Ukraine only.", "North Korea only.",
	"Australia only.", "Iraq only.", "Syria only.", "Afghanistan only.", "Fielded by Russia and Iraq."]

## {role, points, tag} for unit `key` (the hand-written brief, or the description shortened by rule).
static func unit(w: Node, key: String) -> Dictionary:
	var def: Dictionary = w.unit_defs.get(key, {})
	var desc := str(def.get("desc", ""))
	var tag := _tags(desc)
	if BRIEFS.has(key):
		var b: Array = BRIEFS[key]
		return {"role": b[0], "points": b[1], "tag": tag}
	return _by_rule(desc, tag)

## The same for a building.
static func building(w: Node, key: String) -> Dictionary:
	var desc := str(w.building_defs.get(key, {}).get("desc", ""))
	return _by_rule(desc, _tags(desc))

## Any long description shortened by rule.
static func shorten(desc: String) -> Dictionary:
	return _by_rule(desc, _tags(desc))

## The brief as text: the role, then "• point" lines, then the tag.
static func text(b: Dictionary) -> String:
	var lines := PackedStringArray([str(b.role)])
	for p in b.points:
		lines.append("• " + str(p))
	if str(b.get("tag", "")) != "":
		lines.append(str(b.tag))
	return "\n".join(lines)

static func _tags(desc: String) -> String:
	var tags := PackedStringArray()
	for t in TAG_PREFIXES:
		if desc.contains(t):
			tags.append(t.trim_suffix("."))
	return " · ".join(tags)

static func _plain(desc: String) -> String:
	var s := desc
	for t in TAG_PREFIXES:
		s = s.replace(t, "")
	return s.strip_edges()

## First sentence the role; the next two sentences the points, if short; a sentence that is only a category
## word ("Tank.") is dropped.
static func _by_rule(desc: String, tag: String) -> Dictionary:
	var sentences := []
	for raw in _plain(desc).replace("! ", ". ").split(". "):
		var s := str(raw).strip_edges().trim_suffix(".")
		if s == "" or (s.split(" ").size() <= 2 and sentences.is_empty()):
			continue   # "Tank", "SAM Launcher": a heading, not a sentence
		sentences.append(s)
	if sentences.is_empty():
		return {"role": desc, "points": [], "tag": tag}
	var role: String = sentences[0]
	var points := []
	for s in sentences.slice(1, 3):
		if str(s).length() <= 110:
			points.append(s)
	if role.length() > 120:
		var cut := role.find(":")
		if cut > 12 and cut < 90:
			points.push_front(role.substr(cut + 1).strip_edges())
			role = role.substr(0, cut)
	return {"role": role, "points": points, "tag": tag}
