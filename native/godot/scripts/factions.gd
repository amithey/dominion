extends RefCounted
## Playable identities, independent of map slots. Real leaders are a snapshot
## dated 2026-09-28; military modifiers are game balance, not factual rankings.
const NAMES := ["United States", "China", "European Union", "Iran", "Russia", "India", "Japan", "Turkiye", "Israel"]
const LEADERS := ["President Donald Trump", "President Xi Jinping", "Commission President Ursula von der Leyen", "President Masoud Pezeshkian", "President Vladimir Putin", "Prime Minister Narendra Modi", "Prime Minister Sanae Takaichi", "President Recep Tayyip Erdogan", "Prime Minister Benjamin Netanyahu"]
const IDS := ["usa", "china", "eu", "iran", "russia", "india", "japan", "turkiye", "israel"]
const ARSENALS := ["blue", "red", "green", "gold", "russia", "india", "japan", "turkiye", "israel"]
const COLOURS := ["#3b82f6", "#e0483e", "#33b86e", "#e8a83a", "#9868d9", "#ed7938", "#da79af", "#28b9ab", "#8fbce6"]
const PORTRAITS := ["trump", "xi", "vonderleyen", "pezeshkian", "putin", "modi", "takaichi", "erdogan", "netanyahu"]
const SIGNATURES := ["F-22 Raptor / B-21 Raider", "DF-17 Launcher", "IRIS-T SLM", "Shahed Launcher", "TOS-1A Solntsepyok", "BrahMos Battery", "Aegis Cruiser", "Bayraktar Akinci", "Harop"]
const DOCTRINES := [
	"Air superiority: exclusive F-22 and B-21, plus Golden Dome research. These capabilities require advanced research and costly aircraft.",
	"Missile power: exclusive DF-17 hypersonic launcher, particularly effective against ships. Long reloads leave gaps between salvos.",
	"Layered defence: exclusive IRIS-T SLM air defence. It protects an army from aircraft but cannot fight ground targets.",
	"Drone saturation: exclusive Shahed launcher. Five drones per salvo can overwhelm defences, but individual drones are fragile and slow.",
	"Massed artillery: artillery, MLRS and HIMARS gain 20% damage and 10% range, but move 15% slower.",
	"Resilient ground forces: combat infantry gain 15% health; rocket soldiers and ATGM teams deal 15% more damage. Crewed aircraft have 10% less health.",
	"Maritime engineering: ships gain 15% range and 10% speed. Tanks have 10% less health.",
	"Agile drones: drones, FPV teams and loitering munitions gain 20% speed and 10% damage, but have 15% less health.",
	"Precision defence: mobile SAMs, MANPADS and lasers gain 10% range and 15% shorter reloads. Missile interception gains 5 percentage points (capped at 97%). Commandos deal 15% more damage. These specialists have 10% less health."
]
static func labels() -> Array:
	var out := []
	for i in range(IDS.size()):
		out.append("%s · %s" % [NAMES[i], LEADERS[i]])
	return out
static func nation(index: int, player := false) -> Dictionary:
	return {"id": IDS[index], "arsenal": ARSENALS[index], "name": NAMES[index], "color": COLOURS[index], "player": player,
		"people": {"president": LEADERS[index], "general": "Chief of Defence", "scientist": "Chief Science Adviser", "spymaster": "Intelligence Director"}}
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
static func for_unit(w: Node, unit: Dictionary) -> Dictionary:
	var key := str(unit.get("key", ""))
	return modifiers(identity(w, int(unit.owner)), key, key in w.infantry_keys, unit.get("naval", false), unit.get("fly", false))

static func equip(w: Node, unit: Dictionary) -> void:
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
	unit.faction_equipped = true
