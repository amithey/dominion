extends RefCounted
## Paths to victory besides conquest (every rival capital taken):
##   Dominance   hold 40% of the land for 3 minutes;
##   Technology  reach the Future era and complete four of its discoveries
##               (a rival: technology at its height, held for 5 minutes).
## A diplomatic victory comes with the blocs and alliances (the roadmap's last
## stage). Each path counts down in the open: a notice when a nation starts
## one, and the Cabinet's "Paths to Victory" shows where everyone stands.

const LAND_SHARE := 0.4
const LAND_HOLD := 180.0
const FUTURE_ERA := 5
const FUTURE_DISCOVERIES := 4
const TECH_HOLD := 300.0
const TICK := 2.0

var w: Node
var land_since := {}          # owner -> game time it first held the share
var tech_since := {}          # owner -> game time it reached the top
var _tick := 0.0

func _init(world: Node) -> void:
	w = world

func land_share(owner: int) -> float:
	var t = w.territory
	if t == null or t.owner_of.is_empty():
		return 0.0
	var mine := 0
	var land := 0
	for o in t.owner_of:
		land += 1
		if o == owner:
			mine += 1
	return float(mine) / maxf(land, 1)

## The player's Future-era discoveries completed.
func future_done() -> int:
	var r = w.research
	if r == null:
		return 0
	var n := 0
	for key in r.discoveries:
		if r.era_of(key) == FUTURE_ERA and r.done(key):
			n += 1
	return n

func tech_ready(owner: int) -> bool:
	var r = w.research
	if r == null:
		return false
	if owner == 0:
		return r.era >= FUTURE_ERA and future_done() >= FUTURE_DISCOVERIES
	return r.ai_tech(owner) >= 10.0

func update(delta: float) -> void:
	_tick += delta
	if _tick < TICK:
		return
	_tick = 0.0
	if w.game_over != "":
		return
	var d: Node = w.diplomacy
	for owner in range(w.map.nations.size()):
		if owner > 0 and d.defeated(owner):
			continue
		_track(owner, land_share(owner) >= LAND_SHARE, land_since, LAND_HOLD, "dominance")
		_track(owner, tech_ready(owner), tech_since, TECH_HOLD, "technology")

func _track(owner: int, holds: bool, since: Dictionary, hold: float, path: String) -> void:
	if w.game_over != "":
		return
	var d: Node = w.diplomacy
	var who: String = "You" if owner == 0 else d.name_of(owner)
	if not holds:
		if since.has(owner):
			since.erase(owner)
			w.hud.notice("%s %s lost the lead toward a %s victory: the countdown stops." % [who, "have" if owner == 0 else "has", path])
		return
	if not since.has(owner):
		since[owner] = w.game_time
		var what: String = ("%s %s %d%% of the land" % [who, "hold" if owner == 0 else "holds", roundi(LAND_SHARE * 100)]) if path == "dominance" else ("%s %s the summit of technology" % [who, "have reached" if owner == 0 else "has reached"])
		w.hud.notice("%s: %s wins a %s victory in %d minutes%s" % [what.to_upper() if owner > 0 else what, "you" if owner == 0 else who, path, int(hold / 60.0), " if you hold on." if owner == 0 else " unless stopped."])
		return
	if w.game_time - float(since[owner]) >= hold:
		_win(owner, path)

func _win(owner: int, path: String) -> void:
	if w.game_over != "":
		return
	var d: Node = w.diplomacy
	if owner == 0:
		w.game_over = "victory"
		w.hud.show_end("VICTORY", "A %s victory: %s." % [path, "you held %d%% of the land for %d minutes" % [roundi(LAND_SHARE * 100), int(LAND_HOLD / 60.0)] if path == "dominance" else "your nation reached the summit of the Future era first"])
	else:
		w.game_over = "defeat"
		w.hud.show_end("DEFEAT", "%s won a %s victory." % [d.name_of(owner), path])

## Where everyone stands (the Cabinet).
func standings() -> Array:
	var d: Node = w.diplomacy
	var leader_land := -1
	var leader_tech := -1
	for owner in range(1, w.map.nations.size()):
		if d.defeated(owner):
			continue
		if leader_land < 0 or land_share(owner) > land_share(leader_land):
			leader_land = owner
		if leader_tech < 0 or w.research.ai_tech(owner) > w.research.ai_tech(leader_tech):
			leader_tech = owner
	var capitals: int = w.buildings.filter(func(b): return b.owner > 0 and b.key == "hq" and not b.dead).size()
	var out := [{"path": "Conquest", "you": "%d rival capital%s left" % [capitals, "" if capitals == 1 else "s"], "rival": ""}]
	out.append({"path": "Dominance", "you": "%d%% of the land (%d%% needed, 3 min)%s" % [roundi(land_share(0) * 100), roundi(LAND_SHARE * 100), _left(0, land_since, LAND_HOLD)],
		"rival": "" if leader_land < 0 else "%s %d%%%s" % [d.name_of(leader_land), roundi(land_share(leader_land) * 100), _left(leader_land, land_since, LAND_HOLD)]})
	out.append({"path": "Technology", "you": "%s, %d of %d Future discoveries%s" % [w.research.eras[w.research.era].name, future_done(), FUTURE_DISCOVERIES, _left(0, tech_since, TECH_HOLD)],
		"rival": "" if leader_tech < 0 else "%s technology %d/10%s" % [d.name_of(leader_tech), int(w.research.ai_tech(leader_tech)), _left(leader_tech, tech_since, TECH_HOLD)]})
	if w.get("directorate") != null and w.directorate != null:
		out.append(w.directorate.standing())   # the AGI project (ai_directorate.gd)
	return out

func _left(owner: int, since: Dictionary, hold: float) -> String:
	if not since.has(owner):
		return ""
	return " — wins in %ds" % ceili(hold - (w.game_time - float(since[owner])))

func capture() -> Dictionary:
	var a := {}
	var b := {}
	for k in land_since: a[str(k)] = land_since[k]
	for k in tech_since: b[str(k)] = tech_since[k]
	return {"land": a, "tech": b}

func restore(data: Dictionary) -> void:
	land_since.clear()
	tech_since.clear()
	for k in data.get("land", {}): land_since[int(k)] = float(data.land[k])
	for k in data.get("tech", {}): tech_since[int(k)] = float(data.tech[k])
