extends RefCounted
## Each nation's own ground-based air-defence system: its name, how often one battery stops each class of missile,
## how far it reaches, how fast it fires again and how hard it hits an aircraft. A nation with no such battery in
## service has no SAM site to build (national_industry.gd asks `has`); the odds are game balance anchored to the
## generic SAM site (cruise 75%, ballistic 25%, hypersonic 8%, reach 140 m), raised for modern long-range
## systems and lowered for short-range and ageing ones. Sources are in native/AIR-DEFENCE-NATIONAL-2026-11.md.
##
## ODDS order: cruise, sea-skimmer, short ballistic, ballistic, hypersonic, supersonic, glider, ICBM.
const CLASSES := ["cruise", "seaSkimmer", "shortBallistic", "ballistic", "hypersonic", "supersonic", "glide", "icbm"]
const SYSTEMS := {
	"usa": {"name": "Patriot PAC-3", "odds": [0.85, 0.70, 0.70, 0.50, 0.10, 0.30, 0.0, 0.05], "reach": 165.0, "reload": 2.6, "aircraft": 48.0},
	"china": {"name": "HQ-9B", "odds": [0.78, 0.62, 0.50, 0.35, 0.10, 0.30, 0.0, 0.04], "reach": 170.0, "reload": 2.8, "aircraft": 46.0},
	"russia": {"name": "S-400", "odds": [0.80, 0.65, 0.50, 0.35, 0.10, 0.30, 0.0, 0.04], "reach": 185.0, "reload": 2.8, "aircraft": 48.0},
	"iran": {"name": "Bavar-373 and Khordad-15", "odds": [0.60, 0.50, 0.30, 0.20, 0.05, 0.20, 0.0, 0.0], "reach": 130.0, "reload": 3.0, "aircraft": 42.0},
	"india": {"name": "Akash-NG and S-400", "odds": [0.75, 0.60, 0.45, 0.30, 0.06, 0.25, 0.0, 0.02], "reach": 160.0, "reload": 2.8, "aircraft": 44.0},
	"japan": {"name": "Patriot PAC-3 and Type 03", "odds": [0.82, 0.68, 0.65, 0.50, 0.08, 0.30, 0.0, 0.04], "reach": 150.0, "reload": 2.6, "aircraft": 46.0},
	"turkiye": {"name": "Hisar-O and S-400", "odds": [0.70, 0.55, 0.35, 0.25, 0.06, 0.25, 0.0, 0.02], "reach": 150.0, "reload": 2.8, "aircraft": 44.0},
	"israel": {"name": "Iron Dome and David's Sling", "odds": [0.92, 0.78, 0.80, 0.60, 0.12, 0.35, 0.0, 0.03], "reach": 135.0, "reload": 1.8, "aircraft": 46.0},
	"germany": {"name": "IRIS-T SLM", "odds": [0.95, 0.90, 0.60, 0.30, 0.08, 0.35, 0.0, 0.0], "reach": 120.0, "reload": 2.0, "aircraft": 46.0},
	"france": {"name": "SAMP/T NG", "odds": [0.85, 0.75, 0.65, 0.50, 0.08, 0.30, 0.0, 0.03], "reach": 160.0, "reload": 2.6, "aircraft": 46.0},
	"italy": {"name": "SAMP/T", "odds": [0.80, 0.70, 0.55, 0.40, 0.06, 0.28, 0.0, 0.02], "reach": 155.0, "reload": 2.8, "aircraft": 45.0},
	"netherlands": {"name": "Patriot PAC-3", "odds": [0.85, 0.70, 0.70, 0.50, 0.10, 0.30, 0.0, 0.04], "reach": 160.0, "reload": 2.6, "aircraft": 46.0},
	"uk": {"name": "Sky Sabre", "odds": [0.90, 0.80, 0.30, 0.10, 0.04, 0.25, 0.0, 0.0], "reach": 110.0, "reload": 1.8, "aircraft": 44.0},
	"south_korea": {"name": "KM-SAM II and Patriot", "odds": [0.82, 0.66, 0.65, 0.50, 0.08, 0.30, 0.0, 0.03], "reach": 150.0, "reload": 2.6, "aircraft": 45.0},
	"saudi": {"name": "Patriot PAC-3", "odds": [0.75, 0.60, 0.60, 0.45, 0.07, 0.25, 0.0, 0.03], "reach": 160.0, "reload": 3.0, "aircraft": 44.0},
	"brazil": {"name": "Mistral and RBS 70", "odds": [0.45, 0.35, 0.05, 0.0, 0.0, 0.10, 0.0, 0.0], "reach": 70.0, "reload": 3.0, "aircraft": 36.0},
	"indonesia": {"name": "NASAMS and Starstreak", "odds": [0.60, 0.50, 0.10, 0.0, 0.0, 0.15, 0.0, 0.0], "reach": 100.0, "reload": 2.8, "aircraft": 40.0},
	"ukraine": {"name": "Patriot, IRIS-T and NASAMS", "odds": [0.82, 0.72, 0.45, 0.25, 0.06, 0.28, 0.0, 0.02], "reach": 130.0, "reload": 2.6, "aircraft": 45.0},
	"north_korea": {"name": "KN-06 and S-200", "odds": [0.45, 0.35, 0.20, 0.10, 0.0, 0.10, 0.0, 0.0], "reach": 120.0, "reload": 3.5, "aircraft": 40.0},
	"egypt": {"name": "S-300VM and HQ-9B", "odds": [0.70, 0.55, 0.40, 0.30, 0.06, 0.25, 0.0, 0.02], "reach": 150.0, "reload": 3.0, "aircraft": 43.0},
	"australia": {"name": "NASAMS", "odds": [0.80, 0.70, 0.20, 0.05, 0.03, 0.25, 0.0, 0.0], "reach": 110.0, "reload": 2.2, "aircraft": 44.0},
	"pakistan": {"name": "HQ-9/P and LY-80", "odds": [0.65, 0.50, 0.35, 0.20, 0.05, 0.20, 0.0, 0.02], "reach": 140.0, "reload": 3.0, "aircraft": 42.0},
	"iraq": {"name": "Pantsir-S1", "odds": [0.50, 0.40, 0.15, 0.0, 0.0, 0.10, 0.0, 0.0], "reach": 80.0, "reload": 2.0, "aircraft": 38.0},
	"ethiopia": {"name": "Pantsir-S1 and Pechora-2M", "odds": [0.40, 0.30, 0.05, 0.0, 0.0, 0.08, 0.0, 0.0], "reach": 90.0, "reload": 3.0, "aircraft": 36.0},
	"sudan": {"name": "Pechora-2M", "odds": [0.30, 0.20, 0.03, 0.0, 0.0, 0.05, 0.0, 0.0], "reach": 80.0, "reload": 3.5, "aircraft": 34.0},
	"houthis": {"name": "358 loitering SAM", "odds": [0.20, 0.10, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "reach": 70.0, "reload": 4.0, "aircraft": 32.0},
}
## In service nowhere: Afghanistan, Nigeria, South Sudan, Yemen's government and Syria field no battery of their own,
## so they have no SAM site to build and rely on fighters, anti-aircraft vehicles and shoulder-launched missiles.
const DEFAULT_REACH := 140.0
const DEFAULT_RELOAD := 2.2
const DEFAULT_AIRCRAFT := 44.0

static func has(id: String) -> bool:
	return SYSTEMS.has(id)

static func id_of(w: Node, owner: int) -> String:
	return preload("res://scripts/factions.gd").identity(w, owner)

static func system(w: Node, owner: int) -> Dictionary:
	return SYSTEMS.get(id_of(w, owner), {})

## One battery's chance to stop a missile of class `cls`, or -1 when this nation has no system of its own (the generic table applies).
static func odds(w: Node, owner: int, cls: String) -> float:
	var sys := system(w, owner)
	var i := CLASSES.find(cls)
	return -1.0 if sys.is_empty() or i < 0 else float(sys.odds[i])

static func reach(w: Node, owner: int) -> float:
	return float(system(w, owner).get("reach", DEFAULT_REACH))

static func reload_time(w: Node, owner: int) -> float:
	return float(system(w, owner).get("reload", DEFAULT_RELOAD))

static func aircraft_damage(w: Node, owner: int) -> float:
	return float(system(w, owner).get("aircraft", DEFAULT_AIRCRAFT))

## What the battery is called in messages ("a Patriot PAC-3 battery").
static func title(w: Node, owner: int) -> String:
	var sys := system(w, owner)
	return "a SAM site" if sys.is_empty() else "a %s battery" % str(sys.name)

## The data, in one short card: stop chances against the main classes, reach and the aircraft it brings down.
static func describe(id: String) -> String:
	if not SYSTEMS.has(id):
		return "No ground-based air-defence battery in service."
	var s: Dictionary = SYSTEMS[id]
	var o: Array = s.odds
	return "%s. One battery stops %d%% of cruise missiles, %d%% of ballistic, %d%% of hypersonic. Reach %d m; it shoots down aircraft in flight." % [str(s.name), roundi(o[0] * 100.0), roundi(o[3] * 100.0), roundi(o[4] * 100.0), int(s.reach)]

static func line(id: String) -> String:
	if not SYSTEMS.has(id):
		return "None: no SAM batteries."
	var s: Dictionary = SYSTEMS[id]
	return "%s: cruise %d%%, ballistic %d%%, hypersonic %d%%, reach %d m" % [str(s.name), roundi(s.odds[0] * 100.0), roundi(s.odds[3] * 100.0), roundi(s.odds[4] * 100.0), int(s.reach)]

## The SAM site as nation `owner` fields it: its own name and data.
static func def_for(w: Node, owner: int, def: Dictionary) -> Dictionary:
	var id := id_of(w, owner)
	var copy: Dictionary = def.duplicate(true)
	copy.name = "%s Battery" % str(SYSTEMS[id].name) if SYSTEMS.has(id) else "SAM Site"
	copy.desc = describe(id) if SYSTEMS.has(id) else "Automated anti-air battery: shoots down enemy aircraft in flight (not ground forces, not aircraft parked on a base)."
	return copy

## The build menu and the player's own cards show the player's nation's system.
static func apply(w: Node) -> void:
	if w.map.nations.is_empty() or not w.building_defs.has("samSite"):
		return
	var def: Dictionary = def_for(w, 0, w.building_defs.samSite)
	w.building_defs.samSite.name = def.name
	w.building_defs.samSite.desc = def.desc   # (others' sites get their own copy in register_building)
