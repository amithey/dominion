extends RefCounted
## Playable identities, independent of map slots. Real leaders are a snapshot
## dated 2026-09-28; military modifiers are game balance, not factual rankings.
const Registry := preload("res://scripts/nation_registry.gd")
## The columns below are read from the registry, one data file per nation in scripts/nations/.
static var IDS: Array = Registry.column("id")
static var ARSENALS: Array = Registry.column("arsenal")
static var NAMES: Array = Registry.column("name")
static var LEADERS: Array = Registry.column("leader")
static var COLOURS: Array = Registry.column("colour")
static var PORTRAITS: Array = Registry.column("portrait")
static var SIGNATURES: Array = Registry.column("signature")
static var DOCTRINES: Array = Registry.column("doctrine")
static func labels() -> Array:
	var out := []
	for i in range(IDS.size()):
		out.append("%s · %s" % [NAMES[i], LEADERS[i]])
	return out
static func nation(index: int, player := false) -> Dictionary:
	var entry := {"id": IDS[index], "arsenal": ARSENALS[index], "name": NAMES[index], "color": COLOURS[index], "player": player,
		"people": {"president": LEADERS[index], "general": "Chief of Defence", "scientist": "Chief Science Adviser", "spymaster": "Intelligence Director"}}
	entry.merge(preload("res://scripts/regional_factions.gd").metadata(IDS[index]), true)
	return entry
static func identity(w: Node, owner: int) -> String:
	if owner < 0 or owner >= w.map.nations.size():
		return ""
	var n: Dictionary = w.map.nations[owner]
	if n.has("id"):
		return str(n.id)
	var i := COLOURS.find(str(n.get("color", "")).to_lower())
	return IDS[i] if i >= 0 else ""
## Only new factions get numeric doctrines; the original four keep their arsenals.
static func modifiers(id: String, key: String, infantry: bool, naval: bool, fly: bool) -> Dictionary:
	var m := {"hp": 1.0, "damage": 1.0, "range": 1.0, "speed": 1.0, "cooldown": 1.0}
	match id:
		"russia":
			if key in ["artillery", "mlrs", "himars"]:
				m.damage = 1.2
				m.range = 1.1
				m.speed = 0.85
		"india":
			if infantry and key != "worker":
				m.hp = 1.15
			if key in ["rocketSoldier", "atgmTeam"]:
				m.damage = 1.15
			if fly and key not in ["drone", "loiterer", "shahed", "wingman"]:
				m.hp = 0.9
		"japan":
			if naval:
				m.range = 1.15
				m.speed = 1.1
			if key == "tank":
				m.hp = 0.9
		"turkiye":
			if key in ["drone", "loiterer", "fpvTeam"]:
				m.speed = 1.2
				m.damage = 1.1
				m.hp = 0.85
		"israel":
			if key in ["samLauncher", "manpads", "laserAD"]:
				m.range = 1.1
				m.cooldown = 0.85
				m.hp = 0.9
			if key == "commando":
				m.damage = 1.15
				m.hp = 0.9
	return m
## The doctrine and the quality of the nation's own system (unit_quality.gd) together.
static func for_unit(w: Node, unit: Dictionary) -> Dictionary:
	var key := str(unit.get("key", ""))
	var id := identity(w, int(unit.owner))
	var m := modifiers(id, key, key in w.infantry_keys, unit.get("naval", false), unit.get("fly", false))
	var Q := preload("res://scripts/unit_quality.gd")
	# A unit keeps the system it was built as: one in service before its
	# successor was researched stays the older system (an Su-35S stays one).
	var built_before: bool = unit.get("faction_equipped", false) and not unit.get("upgraded", false)
	var q: Dictionary = Q.of(id, key) if built_before else Q.of_unit(w, int(unit.owner), id, key)
	for stat in ["hp", "damage", "speed", "range"]:
		m[stat] = float(m[stat]) * float(q[stat])
	m.cooldown = float(m.cooldown) * float(q.get("cooldown", 1.0))
	m.accuracy = q.accuracy
	m.flags = q.get("flags", {})   # (the M1E3's own active protection, a fibre-optic drone)
	m.upgraded = q.has("name")
	return m

static func equip(w: Node, unit: Dictionary) -> void:
	# Apply the payload correction to legacy saved ISR aircraft as well.
	if unit.key == "drone" and identity(w, int(unit.owner)) in load("res://scripts/arsenal_catalog.gd").ISR:
		unit.dmg = 0.0
	if unit.get("faction_equipped", false):
		return
	var m := for_unit(w, unit)
	unit.hp *= float(m.hp)
	unit.max_hp *= float(m.hp)
	unit.range *= float(m.range)
	if float(m.range) > 1.0:
		unit.aggro = maxf(float(unit.aggro), float(unit.range))
	unit.speed *= float(m.speed)
	unit.cooldown *= float(m.cooldown)
	unit.accuracy = float(m.accuracy)
	for flag in m.flags:
		unit[flag] = m.flags[flag]
	unit.upgraded = m.upgraded
	unit.faction_equipped = true
