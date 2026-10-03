extends RefCounted
## What one nation learned to do in its own war: Russia's capabilities from
## the war in Ukraine (2022-2026), each a Russia-only discovery. Research and
## sources: native/RUSSIA-WAR-CAPABILITIES-2026-10-04.md.
##
##   Foreign Recruitment  North Korea's corps in Kursk (about 11,000 troops at
##                        the start of 2026) and contract recruits from Nepal,
##                        Cuba, Africa and 40-odd other countries: while at
##                        war, foreign soldiers join at the capital.
##   UMPK Glide Bombs     wings and guidance on old FAB bombs, some 3,500 a
##                        month by early 2025, dropped 40-70 km from the
##                        target, outside most air defence: every jet built
##                        afterwards is a Su-34 with glide bombs (unit_quality).
##   Fibre-Optic Drones   FPV drones steered down a fibre-optic cable (the
##                        Rubikon centre; some 50,000 a month in 2025): no
##                        jammer can stop them, and they reach further.
## Russia also builds the Shahed: the Geran-2 from Alabuga (national_arsenal,
## national_variants).

const RECRUITS := 4
const RECRUIT_COST := 60.0
const RECRUIT_SECONDS := 150.0

const DISCOVERIES := {
	"foreignRecruitment": {"name": "Foreign Recruitment", "cost": 400, "branch": "army", "era": 2, "nation": "russia",
		"reqDiscovery": null, "reqBuilding": "barracks", "fx": {"foreignRecruitment": 1.0},
		"desc": "Russia only. North Korea's corps (about 11,000 troops in Kursk) and contract recruits from Nepal, Cuba, Africa and dozens of other countries: while you are at war, 4 foreign soldiers join at your capital every 2.5 minutes, $60 each."},
	"glideBombs": {"name": "UMPK Glide Bombs", "cost": 550, "branch": "air", "era": 3, "nation": "russia",
		"reqDiscovery": "guidedMunitions", "reqBuilding": "airfield", "fx": {"glideBombs": 1.0},
		"desc": "Russia only. Wings and satellite guidance on old FAB bombs (some 3,500 a month by early 2025), dropped 40-70 km from the target: every jet built afterwards is a Su-34 with glide bombs, +50% range and +20% damage."},
	"fibreOpticDrones": {"name": "Fibre-Optic Drones", "cost": 600, "branch": "hightech", "era": 4, "nation": "russia",
		"reqDiscovery": "droneSwarms", "reqBuilding": null, "fx": {"fibreOpticDrones": 1.0},
		"desc": "Russia only. FPV drones steered down a fibre-optic cable (the Rubikon centre; some 50,000 a month in 2025): FPV teams trained afterwards cannot be jammed and reach 30% further."},
}

## Registers the discoveries (modern_warfare.apply).
static func apply(w: Node) -> void:
	var discoveries: Dictionary = w.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)

## Whether `owner` has discovery `key`: the player once it is complete, a rival
## once its technology reaches the discovery's era.
static func has(w: Node, owner: int, key: String) -> bool:
	if w.get("research") == null or w.research == null:
		return false
	if owner == 0:
		return w.research.bonus(key) >= 1.0
	return w.research.ai_tech(owner) >= float(w.research.era_of(key)) * 2.0

## Every frame: foreign recruits for a Russia at war.
static func update(w: Node, delta: float) -> void:
	var due: Dictionary = w.get_meta("recruits_due", {})
	for owner in range(w.map.nations.size()):
		if preload("res://scripts/factions.gd").identity(w, owner) != "russia":
			continue
		if not has(w, owner, "foreignRecruitment") or not at_war(w, owner):
			due.erase(owner)
			continue
		if not due.has(owner):
			due[owner] = w.game_time + RECRUIT_SECONDS
		elif w.game_time >= float(due[owner]):
			due[owner] = w.game_time + RECRUIT_SECONDS
			recruit(w, owner)
	w.set_meta("recruits_due", due)

static func at_war(w: Node, owner: int) -> bool:
	if w.diplomacy == null:
		return false
	for other in range(w.diplomacy.n):
		if other != owner and w.diplomacy.at_war(owner, other) and not w.diplomacy.defeated(other):
			return true
	return false

## A batch of foreign soldiers at `owner`'s capital. Returns how many came.
static func recruit(w: Node, owner: int) -> int:
	var hq = null
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			hq = b
			break
	if hq == null or not preload("res://scripts/war_costs.gd").pay(w, owner, RECRUIT_COST * RECRUITS):
		return 0
	var centre: Vector3 = hq.root.position
	var reach: float = float(hq.get("footprint", 8.0)) * 0.7 + 4.0
	for i in range(RECRUITS):
		var at: Vector3 = centre + Vector3.FORWARD.rotated(Vector3.UP, TAU * (i + 0.5) / RECRUITS + 0.4) * reach
		at.y = w.height_at(at.x, at.z)
		var u: Dictionary = w.spawn_unit("soldier", at, owner)
		u.foreign_recruit = true
	if owner == 0:
		w.hud.notice("Foreign recruits arrive at your capital: %d soldiers ($%d), North Korean troops and contract recruits from abroad." % [RECRUITS, int(RECRUIT_COST * RECRUITS)])
	return RECRUITS
