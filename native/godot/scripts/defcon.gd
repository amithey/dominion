extends RefCounted
## The nuclear escalation ladder. Research: native/STAGE5-RESEARCH-2026-10-05.md.
##
## The world's nuclear tension (0-100) sets its DEFCON, from 5 (peace) to 1
## (nuclear weapons have been used):
##   DEFCON 4  a war in which a nuclear power fights (tension 25+)
##   DEFCON 3  two nuclear powers at war with each other (45+)
##   DEFCON 2  a nuclear power fights for its survival: it has lost half its
##             towns or its capital is badly damaged (65+)
##   DEFCON 1  a nuclear weapon has been used: for five minutes (90+)
## Missiles that land on a nuclear power raise the tension (ballistic and
## hypersonic +6, others +2), and it falls back slowly when the cause is gone.
##
## Each nation's own alert, its posture, is its own choice: the player's is
## set in the Defence window. Raising it alarms the world and costs the
## economy, but readies the forces:
##   posture 4  watch                   (tension 25+)
##   posture 3  readiness: production +10%, income -4%, nuclear powers -4 relations
##   posture 2  mobilised: production +20%, damage +5%, income -10%; every nation
##              -8 relations; and only at posture 2 may a nuclear missile be released
## World DEFCON 2 and 1 shake the markets (world_events.gd: "Nuclear crisis").
##
## Rival nuclear powers raise their posture as their wars grow. One fighting
## for its survival, at posture 2, may use a nuclear weapon on the player:
## Russia twice as readily ("escalate to de-escalate"), and a third as readily
## when the player can strike back (nuclear missiles stored, or a nuclear
## submarine at sea). A nuclear power struck by the player's nuclear weapon
## strikes back within 20-40 seconds (a second strike), most of the time.

const Variants := preload("res://scripts/national_variants.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
const Factions := preload("res://scripts/factions.gd")
const TICK := 2.0
const FLOOR := {5: 0.0, 4: 25.0, 3: 45.0, 2: 65.0}
const BAND := [[80.0, 1], [60.0, 2], [40.0, 3], [20.0, 4]]
const USED_LOCK := 300.0
const SECOND_STRIKE := 0.8
const DESC := {
	5: "Peacetime readiness.",
	4: "Increased watch: a nuclear power is at war.",
	3: "Forces on readiness: nuclear powers fight one another.",
	2: "The step before nuclear war: a nuclear power fights for its survival.",
	1: "Nuclear war: a nuclear weapon has been used.",
}

var w: Node
var tension := 0.0
var posture := {}             # owner -> 5..2
var used_at := -1000.0
var used_by := -1
var retaliation := {}         # owner -> time it strikes back at the player
var _peak_towns := {}         # owner -> most towns it has held
var _tick := 0.0
var _ai_tick := 0.0
var _level := 5

func _init(world: Node) -> void:
	w = world
	for i in range(w.map.nations.size()):
		posture[i] = 5

func nuclear(owner: int) -> bool:
	if owner < 0 or w.missiles == null:
		return false
	if w.get("wmd") != null and w.wmd != null and owner in w.wmd.broken_out:
		return true   # a nuclear breakout (wmd.gd)
	return Variants.admits(w.missiles.def_of("nuke").get("nation", ""), Arsenal.identity(w, owner))

func level() -> int:
	for b in BAND:
		if tension >= float(b[0]):
			return int(b[1])
	return 5

func _towns(owner: int) -> Array:
	return w.buildings.filter(func(b): return int(b.owner) == owner and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"])

## A nuclear power fighting for its survival: half its towns lost, or its capital
## below half health (or gone).
func existential(owner: int) -> bool:
	if not nuclear(owner) or w.diplomacy.enemies_of(owner).is_empty():
		return false
	var towns := _towns(owner)
	var peak: int = int(_peak_towns.get(owner, towns.size()))
	if peak >= 2 and towns.size() * 2 <= peak:
		return true
	var hq: Array = towns.filter(func(b): return b.key == "hq")
	return hq.is_empty() or float(hq[0].hp) < float(hq[0].max_hp) * 0.5

## The tension the world's state holds up, and why.
func floor_now() -> Array:
	var d: Node = w.diplomacy
	var f := 0.0
	var why := ""
	for a in range(d.n):
		if d.defeated(a):
			continue
		for b in range(a + 1, d.n):
			if d.defeated(b) or not d.at_war(a, b):
				continue
			if nuclear(a) and nuclear(b) and f < 45.0:
				f = 45.0
				why = "%s and %s, both nuclear powers, are at war" % [d.name_of(a), d.name_of(b)]
			elif (nuclear(a) or nuclear(b)) and f < 25.0:
				f = 25.0
				why = "%s, a nuclear power, is at war" % d.name_of(a if nuclear(a) else b)
	for i in range(d.n):
		if not d.defeated(i) and existential(i) and f < 65.0:
			f = 65.0
			why = "your nation fights for its survival" if i == 0 else "%s, a nuclear power, fights for its survival" % d.name_of(i)
	for i in posture:
		var p: float = float(FLOOR[int(posture[i])])
		if p > f and not d.defeated(i):
			f = p
			why = ("you have raised your forces' alert to DEFCON %d" % int(posture[i])) if i == 0 else ("%s has raised its forces' alert to DEFCON %d" % [d.name_of(i), int(posture[i])])
	if w.game_time - used_at < USED_LOCK:
		f = 90.0
		why = "you have used a nuclear weapon" if used_by == 0 else "%s has used a nuclear weapon" % d.name_of(used_by)
	return [f, why]

func cause() -> String:
	return str(floor_now()[1])

func update(delta: float) -> void:
	_tick += delta
	_ai_tick += delta
	if _tick >= TICK:
		_tick = 0.0
		for i in range(w.map.nations.size()):
			_peak_towns[i] = maxi(int(_peak_towns.get(i, 0)), _towns(i).size())
		var f: float = float(floor_now()[0])
		if tension < f:
			tension = minf(f, tension + 15.0)
		else:
			tension = maxf(f, tension - 1.0)
		_announce()
	for owner in retaliation.keys():
		if w.game_time >= float(retaliation[owner]):
			retaliation.erase(owner)
			_strike(owner, "a second strike", "mirv" if preload("res://scripts/cbrn_data.gd").has(w, owner, "mirv") else "nuke")
	if _ai_tick >= 10.0:
		_ai_tick = 0.0
		_ai_nuclear()

func _announce() -> void:
	var now := level()
	if now == _level:
		return
	var up := now < _level
	_level = now
	if w.hud != null:
		w.hud.notice("DEFCON %d%s: %s%s" % [now, "" if up else " (easing)", DESC[now], (" Cause: %s." % cause()) if up and cause() != "" else ""])
	if w.research != null:
		w.research._recompute()

## A missile landed (missiles.impact): on a nuclear power, the tension rises.
func struck(key: String, owners: Array) -> void:
	var hit_nuclear := owners.any(func(o): return nuclear(int(o)))
	if not hit_nuclear:
		return
	var heavy: bool = key in ["ballistic", "hypersonic", "df17", "tactical"]
	tension = minf(79.0 if w.game_time - used_at >= USED_LOCK else 100.0, tension + (6.0 if heavy else 2.0))
	_announce()

## A nuclear weapon has gone off (missiles.impact).
func nuclear_used(owner: int, owners_hit: Array) -> void:
	used_at = w.game_time
	used_by = owner
	tension = 100.0
	var d: Node = w.diplomacy
	if owner > 0:
		for i in range(d.n):
			if i != owner and not d.defeated(i):
				d.change(owner, i, -30.0)
		d.changed.emit()
	# A nuclear power struck by the player's weapon answers in kind.
	if owner == 0:
		for o in owners_hit:
			var victim := int(o)
			if victim > 0 and nuclear(victim) and not d.defeated(victim) and not retaliation.has(victim) and randf() < SECOND_STRIKE:
				retaliation[victim] = w.game_time + randf_range(20.0, 40.0)
				posture[victim] = 2
	_announce()

## Nuclear release for the player: the alert goes straight to DEFCON 2, with
## every step's price paid on the way (hud: the release decision).
func authorise_release() -> String:
	var said := ""
	while int(posture[0]) > 2:
		said = raise_posture()
	return said

## The player's alert: one step up (toward 2) or down (toward 5).
func raise_posture() -> String:
	var p: int = int(posture[0])
	if p <= 2:
		return "Your forces are already at DEFCON 2."
	posture[0] = p - 1
	var d: Node = w.diplomacy
	for i in range(1, d.n):
		if d.defeated(i):
			continue
		if posture[0] == 2:
			d.change(0, i, -8.0)
		elif posture[0] == 3 and nuclear(i):
			d.change(0, i, -4.0)
	d.changed.emit()
	tension = maxf(tension, float(FLOOR[int(posture[0])]))
	_announce()
	if w.research != null:
		w.research._recompute()
	return "Your forces' alert is raised to DEFCON %d. %s" % [posture[0], posture_text(int(posture[0]))]

func lower_posture() -> String:
	var p: int = int(posture[0])
	if p >= 5:
		return "Your forces are at peacetime readiness."
	posture[0] = p + 1
	if w.research != null:
		w.research._recompute()
	return "Your forces stand down to DEFCON %d. %s" % [posture[0], posture_text(int(posture[0]))]

static func posture_text(p: int) -> String:
	match p:
		4: return "Watch: no cost, no effect on the forces."
		3: return "Readiness: production +10%, income -4%."
		2: return "Mobilised: production +20%, damage +5%, income -10%. Nuclear release authorised."
	return "Peacetime readiness."

## Why the player may not release a nuclear missile, or "".
func release_blocked() -> String:
	if int(posture[0]) > 2:
		return "Nuclear weapons are released only at DEFCON 2."
	return ""

## The player's posture as research bonuses (research._recompute).
func bonuses() -> Dictionary:
	match int(posture.get(0, 5)):
		3: return {"prodPct": 0.1, "incomePct": -0.04}
		2: return {"prodPct": 0.2, "dmgAll": 0.05, "incomePct": -0.1}
	return {}

## Rivals: their posture follows their wars; one fighting for its survival may
## use a nuclear weapon on the player.
func _ai_nuclear() -> void:
	if w.ai == null:
		return
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		var owner: int = int(n.id)
		if n.defeated or not nuclear(owner):
			continue
		var want := 5
		var enemies: Array = d.enemies_of(owner)
		if not enemies.is_empty():
			want = 4
			if enemies.any(func(e): return nuclear(int(e))): want = 3
			if existential(owner): want = 2
		if retaliation.has(owner): want = 2
		posture[owner] = want if want < int(posture[owner]) or w.game_time - used_at > USED_LOCK else int(posture[owner])
		if int(posture[owner]) != 2 or not d.at_war(owner, 0) or not existential(owner) or w.research.ai_tech(owner) < 6.0:
			continue
		if w.game_time - float(n.get("nuked_at", -1000.0)) < 240.0:
			continue
		var chance := 0.04
		if Factions.identity(w, owner) == "russia": chance *= 2.0
		if deterrent(0): chance *= 0.33
		if w.get("tests") != null and w.tests != null and w.tests.believed(0): chance *= 0.5   # a tested deterrent
		if randf() < chance:
			_strike(owner, "facing defeat", "tacticalNuke" if Factions.identity(w, owner) == "russia" else "nuke")

## The player can strike back: nuclear missiles stored or a nuclear submarine at sea.
func deterrent(owner: int) -> bool:
	if owner != 0 or not nuclear(0):
		return false
	var stored := 0
	for key in preload("res://scripts/wmd.gd").NUCLEAR:
		stored += int(w.missiles.stock.get(key, 0))
	return stored > 0 or w.units.any(func(u): return u.owner == 0 and not u.dead and u.key == "nuclearSub")

## Rival `owner` fires a nuclear missile at the player's town nearest to it.
func _strike(owner: int, why: String, key := "nuke") -> void:
	var d: Node = w.diplomacy
	# From a silo, else its capital, else any town it still holds.
	var home = null
	for b in w.buildings:
		if int(b.owner) != owner or b.dead:
			continue
		var rank: int = {"missileSilo": 3, "hq": 2, "cityCenter": 1, "villageCenter": 1}.get(b.key, 0)
		if rank > 0 and (home == null or rank > int({"missileSilo": 3, "hq": 2}.get(home.key, 1))):
			home = b
	var from := Vector3.ZERO
	if home != null:
		from = home.root.position
	else:
		# A second strike survives the first: a nuclear submarine or any unit
		# still in the field, else the hardened silos under its ruined capital.
		var carrier = null
		for u in w.units:
			if int(u.owner) == owner and not u.dead and (carrier == null or u.key == "nuclearSub"):
				carrier = u
		if carrier != null:
			from = carrier.node.position
		else:
			for b in w.buildings:
				if int(b.owner) == owner and b.key == "hq":
					from = b.root.position
	if from == Vector3.ZERO or d.defeated(owner):
		return
	var target = null
	for b in w.buildings:
		if int(b.owner) == 0 and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"]:
			if target == null or b.root.position.distance_to(from) < target.root.position.distance_to(from):
				target = b
	if target == null:
		return
	for n in w.ai.nations:
		if int(n.id) == owner: n.nuked_at = w.game_time
	w.missiles.fly(key, from + Vector3.UP * 3.0, target.root.position, owner)
	w.hud.notice("NUCLEAR LAUNCH DETECTED: %s has fired a %s at your %s (%s)! Air defence may stop it." % [d.name_of(owner), w.missiles.def_of(key).get("name", "nuclear missile").to_lower(), target.def.name, why])

func capture() -> Dictionary:
	var p := {}
	for k in posture: p[str(k)] = posture[k]
	var r := {}
	for k in retaliation: r[str(k)] = retaliation[k]
	var peak := {}
	for k in _peak_towns: peak[str(k)] = _peak_towns[k]
	return {"tension": tension, "posture": p, "used_at": used_at, "used_by": used_by, "retaliation": r, "peak": peak}

func restore(data: Dictionary) -> void:
	tension = float(data.get("tension", 0.0))
	for k in data.get("posture", {}): posture[int(k)] = int(data.posture[k])
	used_at = float(data.get("used_at", -1000.0))
	used_by = int(data.get("used_by", -1))
	retaliation.clear()
	for k in data.get("retaliation", {}): retaliation[int(k)] = float(data.retaliation[k])
	for k in data.get("peak", {}): _peak_towns[int(k)] = int(data.peak[k])
	_level = level()
	if w.research != null:
		w.research._recompute()
