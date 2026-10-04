extends RefCounted
## The home front: how far each nation's people still back its wars (0-100).
## Research (native/WAR-SUPPORT-RESEARCH-2026-10-04.md): democracies are far
## more sensitive to casualties and to long wars than autocracies; a just
## cause (being attacked) and success soften it; being attacked rallies a
## people round the flag; Hearts of Iron IV ties war support to output and
## stability.
## - It falls: every second of war (half as fast in a war of defence), with
##   every soldier, vehicle, aircraft and ship lost, with shortages, and in a
##   democracy that starts a war without being attacked.
## - It rises: when the nation is attacked (once per war), with victories
##   (enemy losses, enemy towns taken), and back toward its level in peace.
## - Its effects (the player's through research bonuses, a rival's through its
##   income, its will to fight and to make peace):
##     Rallied 75+   production +10%, damage +5%, happiness +4
##     Steady 50-75  none
##     Weary 30-50   income -8%, happiness -4
##     Protests      income -15%, production -10%, damage -5%, happiness -8
##     Collapse <15  income -25%, production -20%, damage -10%, happiness -12;
##                   in a democracy, two minutes of it and parliament forces
##                   a ceasefire.
## A weary rival will not start a new war (below 35) and makes peace sooner.

const Factions := preload("res://scripts/factions.gd")
const REGIME := {"usa": "democracy", "eu": "democracy", "japan": "democracy", "israel": "democracy", "india": "democracy",
	"uk": "democracy", "south_korea": "democracy", "brazil": "democracy", "indonesia": "democracy", "australia": "democracy",
	"ukraine": "democracy", "turkiye": "hybrid", "pakistan": "hybrid", "iraq": "hybrid",
	"china": "autocracy", "russia": "autocracy", "iran": "autocracy", "north_korea": "autocracy", "saudi": "autocracy",
	"egypt": "autocracy", "syria": "autocracy", "afghanistan": "autocracy"}
const SENSITIVITY := {"democracy": 1.0, "hybrid": 0.7, "autocracy": 0.45}
const BASELINE := {"democracy": 60.0, "hybrid": 65.0, "autocracy": 70.0}
const TIERS := [[75.0, "Rallied"], [50.0, "Steady"], [30.0, "Weary"], [15.0, "Protests"], [0.0, "Collapse"]]
const EFFECTS := {"Rallied": {"prodPct": 0.1, "dmgAll": 0.05, "happiness": 4.0}, "Steady": {},
	"Weary": {"incomePct": -0.08, "happiness": -4.0},
	"Protests": {"incomePct": -0.15, "prodPct": -0.1, "dmgAll": -0.05, "happiness": -8.0},
	"Collapse": {"incomePct": -0.25, "prodPct": -0.2, "dmgAll": -0.1, "happiness": -12.0}}
const AI_INCOME := {"Rallied": 1.05, "Steady": 1.0, "Weary": 0.92, "Protests": 0.85, "Collapse": 0.75}
const FATIGUE := 0.018        # a point a minute or so for each war, in a democracy
const RECOVERY := 0.03        # back toward its level in peace, per second
const RALLY := 12.0
const AGGRESSOR := 6.0        # a democracy that starts a war unprovoked
const CEASEFIRE_AFTER := 120.0

var w: Node
var support := {}             # owner -> 0..100
var defending := {}           # "a:b" -> true: a was attacked by b (a war of defence for a)
var low_since := {}           # owner -> game time it fell into Collapse
var _tier := ""
var _tick := 0.0

func _init(world: Node) -> void:
	w = world
	for owner in range(w.map.nations.size()):
		support[owner] = baseline(owner)
	_tier = tier(0)

func regime(owner: int) -> String:
	return REGIME.get(Factions.identity(w, owner), "hybrid")

func sensitivity(owner: int) -> float:
	return SENSITIVITY[regime(owner)]

func baseline(owner: int) -> float:
	return BASELINE[regime(owner)]

func value(owner: int) -> float:
	return float(support.get(owner, 60.0))

func tier(owner: int) -> String:
	for t in TIERS:
		if value(owner) >= t[0]:
			return t[1]
	return "Collapse"

## The player's war support as research bonuses (research._recompute).
func bonuses() -> Dictionary:
	return EFFECTS[tier(0)]

func ai_income_mult(owner: int) -> float:
	return AI_INCOME[tier(owner)]

func change(owner: int, amount: float) -> void:
	if not support.has(owner):
		return
	support[owner] = clampf(value(owner) + amount, 0.0, 100.0)

func _key(a: int, b: int) -> String:
	return "%d:%d" % [a, b]

func update(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	step(_tick)
	_tick = 0.0

## Time passes: wars wear on the people, peace restores them.
func step(dt: float) -> void:
	var d: Node = w.diplomacy
	for owner in support.keys():
		if owner > 0 and d.defeated(owner):
			continue
		var enemies: Array = d.enemies_of(owner)
		if enemies.is_empty():
			support[owner] = move_toward(value(owner), baseline(owner), RECOVERY * dt)
		else:
			for enemy in enemies:
				change(owner, -FATIGUE * sensitivity(owner) * dt * (0.5 if defending.has(_key(owner, enemy)) else 1.0))
		if owner == 0 and w.economy != null:
			change(0, -0.01 * w.economy.shortages.size() * sensitivity(0) * dt)
	# A democracy in Collapse for two minutes: parliament forces a ceasefire.
	for owner in support.keys():
		if tier(owner) != "Collapse" or regime(owner) != "democracy" or d.enemies_of(owner).is_empty():
			low_since.erase(owner)
			continue
		if not low_since.has(owner):
			low_since[owner] = w.game_time
		elif w.game_time - float(low_since[owner]) >= CEASEFIRE_AFTER:
			_ceasefire(owner)
	_follow_player()

## The player's tier changed: its bonuses and a word on what it means.
func _follow_player() -> void:
	var now := tier(0)
	if now == _tier:
		return
	var worse: bool = TIERS.map(func(t): return t[1]).find(now) > TIERS.map(func(t): return t[1]).find(_tier)
	_tier = now
	if w.research != null:
		w.research._recompute()
	if w.economy != null:
		w.economy.recalculate()
	if w.hud != null:
		w.hud.notice("WAR SUPPORT %d%%: %s. %s" % [int(value(0)), now, describe(now) if worse or now == "Rallied" else "The people's mood improves."])

func describe(t: String) -> String:
	return {"Rallied": "The nation rallies: production +10%, damage +5%.", "Steady": "No effect.",
		"Weary": "War weariness: income -8%, happiness -4.", "Protests": "Protests: income -15%, production -10%, damage -5%.",
		"Collapse": "Collapse of support: income -25%, production -20%, damage -10%. A democracy's parliament will force a ceasefire in two minutes."}[t]

func _ceasefire(owner: int) -> void:
	var d: Node = w.diplomacy
	var ended := []
	for enemy in d.enemies_of(owner):
		d.make_peace(owner, enemy)
		ended.append(d.name_of(enemy) if enemy != 0 else "you")
	low_since.erase(owner)
	change(owner, 10.0)   # relief
	if owner == 0:
		w.hud.notice("PARLIAMENT FORCES A CEASEFIRE: after two minutes of collapsed war support, the war with %s is over." % ", ".join(PackedStringArray(ended)))
	elif w.hud != null:
		w.hud.notice("World news: protests force %s's government into a ceasefire with %s." % [d.name_of(owner), ", ".join(PackedStringArray(ended))])

## A unit lost (world.kill): its nation mourns, its enemies take heart.
func lost(unit: Dictionary) -> void:
	var owner: int = int(unit.owner)
	if unit.get("stowed", false) or unit.key in ["worker", "shahed", "loiterer", "wingman", "interceptorDrone", "harop"] or unit.get("foreign_recruit", false):
		return   # a drone or a hired foreigner is not a son or daughter of the nation
	var amount := 0.9 if unit.get("fly", false) or unit.get("naval", false) else (0.5 if unit.get("vehicle", false) else 0.25)
	change(owner, -amount * sensitivity(owner))
	for enemy in w.diplomacy.enemies_of(owner):
		change(enemy, amount * 0.15)

## A building lost (world.destroy_building): a town or a capital weighs most.
func building_lost(b: Dictionary) -> void:
	var owner: int = int(b.owner)
	var town: bool = b.key in ["hq", "cityCenter", "villageCenter"]
	change(owner, -(8.0 if town else 0.6) * sensitivity(owner))
	if town:
		for enemy in w.diplomacy.enemies_of(owner):
			change(enemy, 4.0)

## A war begins (diplomacy.declare_war): the attacked rally, an unprovoked
## democracy pays for it.
func war_declared(attacker: int, target: int) -> void:
	if not defending.has(_key(target, attacker)):
		defending[_key(target, attacker)] = true
		change(target, RALLY)
	if regime(attacker) == "democracy" and not defending.has(_key(attacker, target)):
		change(attacker, -AGGRESSOR)
	_follow_player()

func capture() -> Dictionary:
	var out := {}
	for k in support:
		out[str(k)] = support[k]
	return {"support": out, "defending": defending.keys()}

func restore(data: Dictionary) -> void:
	for k in data.get("support", {}):
		support[int(k)] = float(data.support[k])
	defending.clear()
	for k in data.get("defending", []):
		defending[str(k)] = true
	_tier = tier(0)
	if w.research != null:
		w.research._recompute()
