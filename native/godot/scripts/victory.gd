extends RefCounted
## Paths to victory besides conquest (every rival capital taken):
##   Dominance   hold 40% of the land for 3 minutes;
##   Technology  reach the Future era and complete four of its discoveries
##               (a rival: technology at its height, held for 5 minutes).
## Prosperity rewards a supplied civilian economy. Diplomacy rewards lasting
## peaceful partnerships. Both can be pursued from the Cabinet without conquest.

const CIVIL_HOLD := 180.0
const RESERVE := 6000
const TOWNS := 3
const SECTORS := {"farm": "Food", "fishingWharf": "Food", "market": "Commerce", "bank": "Commerce",
	"school": "Education", "university": "Education", "hospital": "Health"}
const SERVICES := {"Food": "farm or fishing wharf", "Commerce": "market or bank", "Education": "school or university", "Health": "hospital"}
const LAND_SHARE := 0.4
const LAND_HOLD := 180.0
const FUTURE_ERA := 5
const FUTURE_DISCOVERIES := 4
const TECH_HOLD := 300.0
const TICK := 2.0

var w: Node
var land_since := {}          # owner -> game time it first held the share
var tech_since := {}          # owner -> game time it reached the top
var economic_since := {}
var diplomatic_since := {}
var _tick := 0.0

func _init(world: Node) -> void:
	w = world

func _land_shares() -> PackedFloat64Array:
	var shares := PackedFloat64Array()
	shares.resize(w.map.nations.size())
	var t = w.territory
	if t == null: return shares
	var terrain: PackedByteArray = t.terrain
	var owners: PackedInt32Array = t.owner_of
	var land := 0
	for i in range(owners.size()):
		if terrain[i] == preload("res://scripts/territory.gd").Terrain.WATER: continue
		land += 1
		var owner := owners[i]
		if owner >= 0 and owner < shares.size(): shares[owner] += 1.0
	for i in range(shares.size()):
		shares[i] /= maxf(land, 1)
	return shares

func land_share(owner: int) -> float:
	var shares := _land_shares()
	return shares[owner] if owner >= 0 and owner < shares.size() else 0.0

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

func _civil_accounts() -> Array:
	var accounts := []
	var d: Node = w.diplomacy
	for owner in range(d.n):
		var treasury := float(w.economy.res.money) if owner == 0 else 0.0
		accounts.append({"money": treasury, "towns": 0, "services": {}, "embassy": false, "partners": 0, "peace": true})
	for nation in w.ai.nations:
		accounts[int(nation.id)].money = nation.money
	for b in w.buildings:
		if b.dead or not b.built or not b.get("supplied", true) or w.disabled(b): continue
		var account: Dictionary = accounts[b.owner]
		if b.def.get("settlement") != null: account.towns += 1
		if b.key == "embassy": account.embassy = true
		if SECTORS.has(b.key): account.services[SECTORS[b.key]] = true
	for owner in range(d.n):
		for other in range(owner + 1, d.n):
			if d.defeated(owner) or d.defeated(other): continue
			if d.at_war(owner, other):
				accounts[owner].peace = false
				accounts[other].peace = false
			elif d.pact[owner][other] and (d.allied(owner, other) or d.nap[owner][other]) and d.rel(owner, other) >= 55:
				accounts[owner].partners += 1
				accounts[other].partners += 1
	return accounts

func _partners_needed() -> int:
	# Keep the starting roster as the denominator so conquering a partner
	# cannot lower the diplomatic goal.
	return maxi(1, ceili((w.diplomacy.n - 1) * 0.6))

func update(delta: float) -> void:
	_tick += delta
	if _tick < TICK:
		return
	_tick = 0.0
	if w.game_over != "":
		return
	var d: Node = w.diplomacy
	var shares := _land_shares()
	var accounts := _civil_accounts()
	for owner in range(w.map.nations.size()):
		if owner > 0 and d.defeated(owner):
			continue
		_track(owner, shares[owner] >= LAND_SHARE, land_since, LAND_HOLD, "dominance")
		_track(owner, tech_ready(owner), tech_since, TECH_HOLD, "technology")
		var a: Dictionary = accounts[owner]
		_track(owner, a.towns >= TOWNS and a.services.size() == SERVICES.size() and a.money >= RESERVE, economic_since, CIVIL_HOLD, "economic")
		_track(owner, a.embassy and a.peace and a.partners >= _partners_needed(), diplomatic_since, CIVIL_HOLD, "diplomatic")

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
		w.hud.notice("%s started the %s victory countdown (%d minutes)." % [who, path, int(hold / 60.0)])
		return
	if w.game_time - float(since[owner]) >= hold:
		_win(owner, path)

func _win(owner: int, path: String) -> void:
	if w.game_over != "":
		return
	var d: Node = w.diplomacy
	if owner == 0:
		w.game_over = "victory"
		var reasons := {"dominance": "You maintained control of the land.", "technology": "You reached the summit of the Future era.",
			"economic": "Your towns sustained a diverse civilian economy and a treasury reserve.",
			"diplomatic": "Your embassy sustained a peaceful coalition of treaty partners."}
		w.hud.show_end("VICTORY", "A %s victory. %s" % [path, reasons[path]])
	else:
		w.game_over = "defeat"
		w.hud.show_end("DEFEAT", "%s won a %s victory." % [d.name_of(owner), path])

## Where everyone stands (the Cabinet).
func standings() -> Array:
	var d: Node = w.diplomacy
	var shares := _land_shares()
	var leader_land := -1
	var leader_tech := -1
	for owner in range(1, w.map.nations.size()):
		if d.defeated(owner):
			continue
		if leader_land < 0 or shares[owner] > shares[leader_land]:
			leader_land = owner
		if leader_tech < 0 or w.research.ai_tech(owner) > w.research.ai_tech(leader_tech):
			leader_tech = owner
	var capitals: int = w.buildings.filter(func(b): return b.owner > 0 and b.key == "hq" and not b.dead).size()
	var out := [{"path": "Conquest", "you": "%d rival capital%s left" % [capitals, "" if capitals == 1 else "s"], "rival": ""}]
	out.append({"path": "Dominance", "you": "%d%% of the land (%d%% needed, 3 min)%s" % [roundi(shares[0] * 100), roundi(LAND_SHARE * 100), _left(0, land_since, LAND_HOLD)],
		"rival": "" if leader_land < 0 else "%s %d%%%s" % [d.name_of(leader_land), roundi(shares[leader_land] * 100), _left(leader_land, land_since, LAND_HOLD)]})
	out.append({"path": "Technology", "you": "%s, %d of %d Future discoveries%s" % [w.research.eras[w.research.era].name, future_done(), FUTURE_DISCOVERIES, _left(0, tech_since, TECH_HOLD)],
		"rival": "" if leader_tech < 0 else "%s technology %d/10%s" % [d.name_of(leader_tech), int(w.research.ai_tech(leader_tech)), _left(leader_tech, tech_since, TECH_HOLD)]})
	var a: Dictionary = _civil_accounts()[0]
	var missing := PackedStringArray()
	for service in SERVICES:
		if not a.services.has(service): missing.append(SERVICES[service])
	var services := "All four services supplied" if missing.is_empty() else "Still needed: " + ", ".join(missing)
	out.append({"path": "Economic prosperity", "you": "%d/%d supplied towns (capital counts), $%d/$%d in reserve. %s. Maintain all for 3 minutes%s." % [a.towns, TOWNS, int(a.money), RESERVE, services, _left(0, economic_since, CIVIL_HOLD)], "rival": _civil_rival(economic_since)})
	out.append({"path": "Diplomatic coalition", "you": "%s; %s; %d/%d partners. Each needs +55 relations, a trade pact and either non-aggression or alliance. Maintain all for 3 minutes%s." % ["Embassy supplied" if a.embassy else "Supply an embassy", "At peace" if a.peace else "Make peace with every rival", a.partners, _partners_needed(), _left(0, diplomatic_since, CIVIL_HOLD)], "rival": _civil_rival(diplomatic_since)})
	if w.get("directorate") != null and w.directorate != null:
		out.append(w.directorate.standing())   # the AGI project (ai_directorate.gd)
	return out

func _civil_rival(since: Dictionary) -> String:
	var first := -1
	for owner in since:
		if owner != 0 and not w.diplomacy.defeated(owner) and (first < 0 or since[owner] < since[first]): first = owner
	return "" if first < 0 else w.diplomacy.name_of(first) + _left(first, since, CIVIL_HOLD)

func _left(owner: int, since: Dictionary, hold: float) -> String:
	if not since.has(owner):
		return ""
	return " — wins in %ds" % ceili(hold - (w.game_time - float(since[owner])))

func capture() -> Dictionary:
	var a := {}
	var b := {}
	for k in land_since: a[str(k)] = land_since[k]
	for k in tech_since: b[str(k)] = tech_since[k]
	return {"land": a, "tech": b, "economic": economic_since.duplicate(), "diplomatic": diplomatic_since.duplicate()}

func restore(data: Dictionary) -> void:
	land_since.clear()
	tech_since.clear()
	for k in data.get("land", {}): land_since[int(k)] = float(data.land[k])
	for k in data.get("tech", {}): tech_since[int(k)] = float(data.tech[k])
	economic_since.clear()
	diplomatic_since.clear()
	for k in data.get("economic", {}): economic_since[int(k)] = float(data.economic[k])
	for k in data.get("diplomatic", {}): diplomatic_since[int(k)] = float(data.diplomatic[k])
