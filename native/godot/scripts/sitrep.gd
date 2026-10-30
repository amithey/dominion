extends RefCounted
## The situation report: everything that happens to you, gathered, grouped and counted, so
## nothing is missed in a busy match (native/SITREP-2026-10-18.md).
##
## Raw events arrive from the world's damage, loss and destruction code (hits on your buildings
## and units, what you lose, what you destroy) and from every message the HUD shows (classified by
## its wording). Repeats are merged: forty hits on a barracks are one entry, "Barracks under attack",
## with its health. Each entry has a category and a severity:
##   attack  your buildings or forces under fire, missiles at you        warning or critical
##   loss    your units and buildings lost                                 warning or critical
##   kill    what you destroyed (the battle's other side)                  information
##   war     wars, treaties, sanctions, the UN                              information, critical for a war on you
##   econ    shortages, halted forces, money problems                       warning
##   done    production, buildings, research finished                        information
##   world   everything else
## What you are told depends on what you can know. A report of damage is amber: your own building burns in
## front of you, but the attacker is named only if you saw it or have intelligence on its nation, otherwise it is
## "an unidentified force". A warning, in red, comes only from intelligence: your agents in the enemy nation
## (network 60 or more), Satellite Reconnaissance, early-warning satellites or an airborne radar. Without
## them a rival's missile launch or an army on its way is not announced at all: you learn of it when it lands
## (espionage.gd INTEL_TIERS, "Warning of attacks on you").
## The HUD shows the live alerts as a banner, the minimap pings where you are hit, the Situation report
## window (L) summarises the last minutes by category, and when a battle ends a short report says how it went.

const WINDOW := {"warning": 45.0, "enemy": 60.0, "attack": 25.0, "loss": 40.0, "kill": 40.0, "war": 60.0, "econ": 60.0, "done": 30.0, "world": 20.0}
const TITLES := {"warning": "Intelligence warnings", "enemy": "Enemy forces sighted", "attack": "Under attack", "loss": "Lost", "kill": "Destroyed", "war": "Diplomacy and war", "econ": "Economy", "done": "Completed", "world": "Other news"}
const ORDER := ["warning", "enemy", "attack", "loss", "kill", "war", "econ", "done", "world"]
const SEV := {"info": 0, "warn": 1, "crit": 2}
const KEY_BUILDINGS := ["hq", "cityCenter", "villageCenter", "missileSilo", "airfield", "tankFactory", "powerPlant", "shipyard", "port", "commandCenter", "strategicComplex", "specialLab", "nuclearReactor", "intelAgency"]
const ALERT_SECONDS := 9.0
const WARNING_SECONDS := 20.0    # a warning stays on the banner this long
const SCAN_EVERY := 5.0          # seconds between looks for forces near your towns
const NEAR_TOWN := 130.0         # how close enemy forces must come to a town to be reported
const MIN_FORCE := 3             # fewer units than this are not "forces"       # how long an attack stays a live alert after its last hit
const BATTLE_QUIET := 22.0       # seconds without a hit before a battle is over
const MAX_EVENTS := 500
const THROTTLE := 0.4            # an entry's text is rewritten at most this often

var w: Node
var events: Array = []           # oldest first
var _by_key := {}                # key -> event, while it can still grow
var pings: Array = []            # {pos, born, crit} for the minimap
var unread := 0
var unread_critical := 0
var _battle := {}
var reports := 0                 # (tests) how many battle reports were issued
var _scan := 0.0

func _init(world: Node) -> void:
	w = world

func _now() -> float:
	return float(w.game_time)

## ---------------------------------------------------------------- recording

## One entry. `key` merges repeats inside the category's window; `text` replaces the old text.
func record(cat: String, sev: String, key: String, text: String, pos := Vector3.INF, amount := 0.0, extra := {}) -> Dictionary:
	var now := _now()
	var e: Dictionary = _by_key.get(key, {})
	if not e.is_empty() and now - float(e.last) <= float(WINDOW.get(cat, 30.0)):
		e.last = now
		e.n = int(e.n) + 1
		e.amount = float(e.amount) + amount
		if SEV[sev] > SEV[e.sev]:
			e.sev = sev
			_mark(e)
		if pos != Vector3.INF:
			e.pos = pos
		if now - float(e.get("shown", -9.0)) >= THROTTLE:
			e.text = text
			e.shown = now
		for k in extra:
			e[k] = extra[k]
		return e
	e = {"t": now, "last": now, "cat": cat, "sev": sev, "key": key, "text": text, "pos": pos, "n": 1, "amount": amount, "shown": now, "read": false}
	for k in extra:
		e[k] = extra[k]
	events.append(e)
	if events.size() > MAX_EVENTS:
		var old: Dictionary = events.pop_front()
		if _by_key.get(old.key) == old:
			_by_key.erase(old.key)
	_by_key[key] = e
	_mark(e)
	return e

## Who struck, as far as you know: named when you saw the attacker or have intelligence on its nation, or
## when only one nation is at war with you; otherwise an unidentified force.
func attacker_name(source: Dictionary, from: int) -> String:
	var fog = w.get("fog")
	var seen: bool = fog != null and source.get("node") != null and is_instance_valid(source.node) and fog.shows(source)
	var known: bool = seen or (w.espionage != null and float(w.espionage.intel.get(from, 0.0)) >= 25.0)
	if not known and w.diplomacy != null:
		var foes: Array = w.diplomacy.enemies_of(0)
		known = foes.size() == 1 and int(foes[0]) == from
	if not known:
		return "an unidentified force"
	return str(w.map.nations[from].name) if from < w.map.nations.size() else "an enemy"

func _mark(e: Dictionary) -> void:
	if int(SEV[e.sev]) >= 1:
		unread += 1
		if e.sev == "crit":
			unread_critical += 1
	if e.cat in ["warning", "attack", "loss"] and e.pos != Vector3.INF and int(SEV[e.sev]) >= 1:
		pings.append({"pos": e.pos, "born": _now(), "crit": e.cat == "warning"})
		if pings.size() > 12:
			pings.pop_front()

## A hit on one of your buildings or units (world.damage).
func damaged(target: Dictionary, amount: float, source: Dictionary) -> void:
	if amount <= 0.0 or int(target.get("owner", -1)) != 0:
		return
	var from: int = int(source.get("owner", -1))
	if from == 0 or from < 0:
		return
	var by := attacker_name(source, from)
	var pos: Vector3 = target.root.position if target.get("is_building", false) else target.node.position
	_battle_touch(pos)
	if target.get("is_building", false):
		var share: int = int(roundf(100.0 * maxf(0.0, float(target.hp)) / maxf(1.0, float(target.max_hp))))
		var name: String = str(target.def.name)
		var crit: bool = str(target.key) in KEY_BUILDINGS
		record("attack", "crit" if crit else "warn", "atk:b:%d" % target.root.get_instance_id(), "%s under attack by %s: %d%% health" % [name, by, share], pos, amount, {"building": target})
		return
	# Units: one entry per patch of ground and attacker, counting the units hurt.
	var cell := Vector2i(floori(pos.x / 70.0), floori(pos.z / 70.0))
	var key := "atk:u:%d:%d:%d" % [cell.x, cell.y, from]
	var e := record("attack", "warn", key, "Your forces are under fire from %s" % by, pos, amount)
	if not e.has("units"):
		e.units = {}
	e.units[target.node.get_instance_id()] = str(target.key)
	e.by = by

## A unit of yours (or an enemy's) was destroyed (world.kill).
func unit_lost(u: Dictionary) -> void:
	var by := int(u.get("last_by", -1))
	var name: String = str(w.unit_defs.get(u.key, {}).get("name", u.key))
	var pos: Vector3 = u.node.position
	if int(u.owner) == 0:
		var costly: bool = u.get("naval", false) or str(u.key) in ["carrier", "sixthGen", "raptor", "stealthFighter", "bomber", "railgunShip", "nuclearSub"]
		var e := record("loss", "crit" if costly else "warn", "loss:u:%s:%d" % [u.key, floori(_now() / 45.0)], "Lost: %s" % name, pos)
		if int(e.n) > 1:
			e.text = "Lost: %d× %s" % [e.n, name]
		_battle_touch(pos)
		_battle.lost = int(_battle.get("lost", 0)) + 1
	elif by == 0:
		var e := record("kill", "info", "kill:u:%s:%d" % [u.key, floori(_now() / 45.0)], "Destroyed: %s" % name, pos)
		if int(e.n) > 1:
			e.text = "Destroyed: %d× %s" % [e.n, name]
		_battle_touch(pos)
		_battle.killed = int(_battle.get("killed", 0)) + 1

## A building was destroyed (world.destroy_building).
func building_lost(b: Dictionary) -> void:
	var name: String = str(b.def.name)
	var pos: Vector3 = b.root.position
	if int(b.owner) == 0:
		record("loss", "crit", "loss:b:%d" % b.root.get_instance_id(), "Lost: %s destroyed" % name, pos)
		_battle_touch(pos)
		_battle.blost = int(_battle.get("blost", 0)) + 1
	elif int(b.get("last_by", -1)) == 0:
		record("kill", "info", "kill:b:%d" % b.root.get_instance_id(), "Destroyed: enemy %s" % name, pos)
		_battle_touch(pos)
		_battle.bkilled = int(_battle.get("bkilled", 0)) + 1

## Every message the HUD shows is also an entry, by its wording.
func from_notice(text: String, pos := Vector3.INF) -> void:
	var low := text.to_lower()
	var cat := "world"
	var sev := "info"
	if low.begins_with("intelligence") or low.begins_with("early warning"):
		cat = "warning"
		sev = "crit"
	elif low.begins_with("crisis:"):
		cat = "econ"   # a national crisis (crisis.gd)
		sev = "warn"
	elif low.begins_with("recovery:"):
		cat = "econ"
	elif low.begins_with("un ") or low.begins_with("un:") or low.begins_with("iaea:") or low.begins_with("wfp:") or low.begins_with("unhcr:"):
		cat = "war"   # the United Nations and its agencies: diplomacy and war
	elif low.contains("declares war") or low.contains("declared war") or low.contains("you are at war") or low.contains("treaty") or low.contains("alliance") or low.contains("ceasefire") or low.contains("peace") or low.contains("sanction") or low.contains("united nations") or low.contains("embargo"):
		cat = "war"
		if low.contains("on you") or low.contains("you are at war") or low.contains("attacked you"):
			sev = "crit"
	elif low.contains("incoming") or low.contains("missile") and (low.contains("launched") or low.contains("strike")) or low.contains("nuclear") and (low.contains("detected") or low.contains("launched")):
		cat = "attack"
		sev = "crit"
	elif low.contains("went down") or low.contains("destroyed") or low.contains("lost ") or low.contains("shot down"):
		cat = "loss"
		sev = "warn"
	elif low.contains("not enough") or low.contains("shortage") or low.contains("halted") or low.contains("no room") or low.contains("cannot afford") or low.contains("blocked") or low.contains("deficit") or low.contains("running out"):
		cat = "econ"
		sev = "warn"
	elif low.contains("complete") or low.contains("finished") or low.contains("ready") or low.contains("built") or low.contains("trained") or low.contains("discovered") or low.contains("researched") or low.contains("arrived") or low.contains("put ashore") or low.contains("opened"):
		cat = "done"
	record(cat, sev, "msg:" + text.left(80), text, pos)

## ---------------------------------------------------------------- battles

func _battle_touch(pos: Vector3) -> void:
	var now := _now()
	if _battle.is_empty():
		_battle = {"since": now, "pos": pos}
	_battle.last = now

## Every few seconds (hud): ends a quiet battle with a report.
func update() -> void:
	_scan += 0.2
	if _scan >= SCAN_EVERY:
		_scan = 0.0
		scan_forces()
	if _battle.is_empty():
		return
	if _now() - float(_battle.get("last", 0.0)) < BATTLE_QUIET:
		return
	var b := _battle
	_battle = {}
	var lost: int = int(b.get("lost", 0)) + int(b.get("blost", 0))
	var killed: int = int(b.get("killed", 0)) + int(b.get("bkilled", 0))
	if lost + killed < 2 or w.hud == null:
		return
	reports += 1
	var minutes := maxf(0.1, (float(b.last) - float(b.since)) / 60.0)
	var text := "Battle over (%.1f min): you lost %d, the enemy lost %d." % [minutes, lost, killed]
	if lost > killed * 2 and lost >= 3:
		text += " A costly fight."
	elif killed > lost * 2 and killed >= 3:
		text += " A clear win."
	w.hud.notice(text, b.pos)

## ---------------------------------------------------------------- intelligence

## Whether one of your reconnaissance or early-warning satellites is in orbit.
func _satellite_up() -> bool:
	return w.get("space") != null and w.space != null and (w.space.active(0, "recon") >= 1 or w.space.active(0, "warning") >= 1)

## How well you are warned of attacks by `nation`: {"level": 0..1, "source": text}. Level 0 means not at all.
func early_warning(nation: int) -> Dictionary:
	var best := {"level": 0.0, "source": ""}
	var name: String = str(w.map.nations[nation].name) if nation < w.map.nations.size() else "the enemy"
	if w.espionage != null and float(w.espionage.intel.get(nation, 0.0)) >= 60.0:
		best = {"level": 1.0, "source": "your agents in %s" % name}
	# The discovery only teaches the method: a satellite must actually be in orbit to see anything.
	if w.research != null and w.research.bonus("warn") >= 1.0 and float(best.level) < 0.8 and _satellite_up():
		best = {"level": 0.8, "source": "Satellite Reconnaissance"}
	if w.get("space") != null and w.space != null and w.space.active(0, "warning") >= 1 and float(best.level) < 0.8:
		best = {"level": 0.8, "source": "early-warning satellites"}
	if float(best.level) < 0.5 and w.units.any(func(u): return u.owner == 0 and not u.dead and u.key == "aewc" and w.airborne(u)):
		best = {"level": 0.5, "source": "airborne radar"}
	return best

## A rival's missile is on its way (ai.missile_strike). Announced only if you are warned of that nation's attacks.
func missile_launched(nation: int, missile: String, target: Dictionary, eta: float) -> bool:
	var ew := early_warning(nation)
	if float(ew.level) < 0.5:
		return false
	var name: String = str(w.map.nations[nation].name)
	var pos: Vector3 = target.root.position
	var text := "Early warning (%s): %s launched a %s at your %s, impact in about %d seconds." % [ew.source, name, missile, target.def.name, int(roundf(eta / 5.0) * 5.0)]
	if w.hud != null:
		w.hud.notice(text, pos)   # (recorded as a warning from its wording: from_notice)
	else:
		record("warning", "crit", "warn:missile:%d:%d" % [nation, floori(_now() / 20.0)], text, pos)
	return true

## Enemy forces near your towns: sighted ones are reported as you see them; unseen ones only if your
## intelligence or early warning covers that nation.
func scan_forces() -> void:
	if w.diplomacy == null:
		return
	var towns: Array = w.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.built and b.key in ["hq", "cityCenter", "villageCenter"])
	if towns.is_empty():
		return
	var fog = w.get("fog")
	for foe in w.diplomacy.enemies_of(0):
		var armed: Array = w.units.filter(func(u): return u.owner == foe and not u.dead and not u.get("stowed", false) and float(u.get("dmg", 0)) > 0.0)
		if armed.size() < MIN_FORCE:
			continue
		var ew := early_warning(foe)
		var name: String = str(w.map.nations[foe].name)
		for town in towns:
			var near: Array = armed.filter(func(u): return Vector2(u.node.position.x - town.root.position.x, u.node.position.z - town.root.position.z).length() <= NEAR_TOWN)
			if near.size() < MIN_FORCE:
				continue
			var seen: Array = near.filter(func(u): return fog == null or fog.shows(u))
			var tname: String = str(town.def.name)
			if seen.size() >= MIN_FORCE:
				record("enemy", "warn", "sight:%d:%d" % [foe, town.root.get_instance_id()], "%d %s units sighted near your %s" % [seen.size(), name, tname], town.root.position)
			elif float(ew.level) >= 1.0 or (float(ew.level) >= 0.8 and near.size() >= 5):
				var about := int(roundf(near.size() / 5.0) * 5.0) if near.size() >= 10 else near.size()
				record("warning", "crit", "warn:force:%d:%d" % [foe, town.root.get_instance_id()], "Intelligence (%s): about %d %s units are approaching your %s" % [ew.source, about, name, tname], town.root.position)

## ---------------------------------------------------------------- reading

## The wording of an entry that counts units (rebuilt when read, not on every hit).
func _fresh(e: Dictionary) -> Dictionary:
	if e.has("units"):
		var counts := {}
		for id in e.units:
			counts[e.units[id]] = int(counts.get(e.units[id], 0)) + 1
		e.text = "%d of your units under fire from %s (%s)" % [e.units.size(), e.get("by", "an enemy"), _list(counts)]
	return e

## Live alerts: attacks and losses whose last event was recent, most severe and newest first.
func alerts() -> Array:
	var now := _now()
	var out := []
	var max_window: float = maxf(WARNING_SECONDS, ALERT_SECONDS)
	for i in range(events.size() - 1, -1, -1):
		var e: Dictionary = events[i]
		if now - float(e.last) > max_window:
			break
		var live: float = WARNING_SECONDS if e.cat == "warning" else ALERT_SECONDS
		if e.cat in ["warning", "enemy", "attack", "loss"] and int(SEV[e.sev]) >= 1 and now - float(e.last) <= live:
			out.append(_fresh(e))
	# Intelligence warnings first, then by severity and recency.
	out.sort_custom(func(a, b):
		if (a.cat == "warning") != (b.cat == "warning"):
			return a.cat == "warning"
		return int(SEV[a.sev]) > int(SEV[b.sev]) or (int(SEV[a.sev]) == int(SEV[b.sev]) and float(a.last) > float(b.last)))
	return out

## Entries of the last `seconds`, grouped by category in display order: [[cat, [entries newest first]], ...].
func summary(seconds := 300.0) -> Array:
	var now := _now()
	var groups := {}
	for i in range(events.size() - 1, -1, -1):
		var e: Dictionary = events[i]
		if now - float(e.last) > seconds:
			break
		if not groups.has(e.cat): groups[e.cat] = []
		groups[e.cat].append(_fresh(e))
	var out := []
	for cat in ORDER:
		if groups.has(cat):
			out.append([cat, groups[cat]])
	return out

## One line: "3 attacks, 5 units lost, 2 completed" for the last `seconds`.
func headline(seconds := 300.0) -> String:
	var parts := PackedStringArray()
	for g in summary(seconds):
		var n := 0
		for e in g[1]: n += 1
		parts.append("%d %s" % [n, str(TITLES[g[0]]).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else "All quiet."

func mark_read() -> void:
	unread = 0
	unread_critical = 0
	for e in events: e.read = true

func active_pings(seconds := 5.0) -> Array:
	var now := _now()
	pings = pings.filter(func(p): return now - float(p.born) <= seconds)
	return pings

func _list(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys.slice(0, 3):
		parts.append("%d %s" % [counts[k], str(w.unit_defs.get(k, {}).get("name", k))])
	if keys.size() > 3:
		parts.append("%d more kinds" % (keys.size() - 3))
	return ", ".join(parts)
