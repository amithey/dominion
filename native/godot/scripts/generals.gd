extends RefCounted
## Generals with traits. Research: native/STAGE5-RESEARCH-2026-10-05.md.
##
## The player keeps a general staff: up to three generals at a time, chosen
## from three candidates (new ones every five minutes), each with two traits.
## A general takes command from a ground or naval unit; every unit of yours
## within 50 m of it fights under the general's traits (Air Power reaches the
## whole air force). Each enemy killed under their command counts: at 8 kills a
## general rises to the second level and at 20 to the third, and each level
## strengthens the traits by a quarter.
## If the unit the general commands from is destroyed, the general is killed
## half the time. Otherwise they escape wounded and are out of action for
## 2 minutes. A general killed costs the nation war support and gives heart to
## its enemies.
## Every rival keeps two generals of its own, with traits its doctrine favours,
## at the head of its strongest unit. An assassination of a rival's general
## (espionage.gd) kills its most senior one.

const Factions := preload("res://scripts/factions.gd")
const COMMAND_RADIUS := 50.0
const MAX_PLAYER := 3
const AI_GENERALS := 2
const CANDIDATES := 3
const REFRESH := 300.0
const WOUNDED := 120.0
const LEVELS := [0, 8, 20]          # kills for levels 1, 2, 3
const ARTILLERY := ["artillery", "mlrs", "himars"]
const DRONES := ["drone", "loiterer", "fpvTeam", "seaDrone", "shahed", "harop"]

## key -> name, what it does (in words), and its numbers:
##   dmg {class: x}   damage of units in command of that class ("*" all)
##   taken x          damage taken by units in command
##   xp x             experience earned by units in command
##   heal x           health a second (share of max) out of combat
const TRAITS := {
	"spearhead": {"name": "Armoured Spearhead", "desc": "Tanks and armour +15% damage", "dmg": {"armor": 0.15}},
	"gunner": {"name": "Master Gunner", "desc": "Artillery and rocket launchers +20% damage", "dmg": {"artillery": 0.2}},
	"fortress": {"name": "Defensive Genius", "desc": "Units in command take 12% less damage", "taken": -0.12},
	"airpower": {"name": "Air Power", "desc": "The whole air force +15% damage", "dmg": {"air": 0.15}},
	"infantry": {"name": "Infantry Commander", "desc": "Infantry +15% damage and 8% less damage taken", "dmg": {"infantry": 0.15}, "taken_infantry": -0.08},
	"logistician": {"name": "Logistician", "desc": "Units in command repair 0.4% of their health a second out of combat", "heal": 0.004},
	"inspiring": {"name": "Inspiring", "desc": "Units in command gain experience 50% faster", "xp": 0.5},
	"reckless": {"name": "Reckless", "desc": "+12% damage, but 10% more damage taken", "dmg": {"*": 0.12}, "taken": 0.1},
	"cautious": {"name": "Cautious", "desc": "12% less damage taken, but 4% less damage", "dmg": {"*": -0.04}, "taken": -0.12},
	"drones": {"name": "Drone Warfare", "desc": "Drones and loitering munitions +20% damage", "dmg": {"drone": 0.2}},
	"admiral": {"name": "Admiral", "desc": "Ships in command +15% damage", "dmg": {"naval": 0.15}},
}
## The traits each nation's officer corps tends to (the rest are rarer).
const DOCTRINE := {
	"usa": ["airpower", "spearhead", "logistician"], "china": ["gunner", "admiral", "drones"],
	"russia": ["gunner", "reckless", "spearhead"], "eu": ["logistician", "cautious", "fortress"],
	"iran": ["drones", "infantry", "fortress"], "india": ["gunner", "infantry", "fortress"],
	"japan": ["admiral", "cautious", "logistician"], "turkiye": ["drones", "spearhead", "infantry"],
	"israel": ["airpower", "inspiring", "spearhead"], "uk": ["admiral", "inspiring", "infantry"],
	"ukraine": ["drones", "inspiring", "fortress"], "north_korea": ["gunner", "reckless", "infantry"],
	"south_korea": ["spearhead", "fortress", "gunner"], "pakistan": ["infantry", "gunner", "fortress"],
}
## Surnames for the generals a nation fields (invented officers).
const NAMES := {
	"usa": ["Hale", "Mercer", "Brooks", "Whitaker", "Calloway", "Dunn", "Reyes", "Holt", "Garrison", "Pike"],
	"china": ["Zhao", "Liu", "Chen", "Wang", "Sun", "Huang", "Ma", "Gao", "Lin", "Xu"],
	"russia": ["Volkov", "Sokolov", "Orlov", "Lebedev", "Morozov", "Kozlov", "Zaitsev", "Belov", "Gromov", "Titov"],
	"eu": ["Lefèvre", "Hoffmann", "Rossi", "Moreau", "Novak", "Jansen", "Kowalski", "Bauer", "Duval", "Ferrari"],
	"iran": ["Rahimi", "Karimi", "Hosseini", "Jafari", "Moradi", "Rostami", "Ahmadi", "Shirazi", "Tehrani", "Bagheri"],
	"india": ["Sharma", "Rathore", "Menon", "Singh", "Nair", "Chauhan", "Rao", "Thapa", "Iyer", "Bhatia"],
	"japan": ["Takeda", "Kuroda", "Sato", "Ishikawa", "Mori", "Fujita", "Ogawa", "Nakamura", "Hayashi", "Kondo"],
	"turkiye": ["Yilmaz", "Demir", "Kaya", "Celik", "Aydin", "Ozturk", "Arslan", "Kurt", "Polat", "Sahin"],
	"israel": ["Ben-Ari", "Levi", "Peretz", "Mizrahi", "Golan", "Avital", "Barak", "Shaked", "Carmel", "Eitan"],
	"uk": ["Ashworth", "Pembroke", "Hollis", "Kerr", "Fairfax", "Llewellyn", "Graham", "Stirling", "Hartley", "Blake"],
	"ukraine": ["Kovalenko", "Bondarenko", "Shevchuk", "Tkachenko", "Moroz", "Kravets", "Savchenko", "Lysenko", "Hnatiuk", "Melnyk"],
	"*": ["Kader", "Haddad", "Santos", "Lima", "Okafor", "Nasser", "Rahman", "Pratama", "Kim", "Park", "Khan", "Farouk"],
}

var w: Node
var roster: Array = []        # {id, name, owner, traits, kills, level, unit, wounded_until, alive}
var candidates: Array = []    # the player's: {name, traits, cost}
var _serial := 0
var _next_offer := 0.0
var _tick := 0.0
var _by_owner := {}           # owner -> generals in command (rebuilt each second)

func _init(world: Node) -> void:
	w = world
	_offer()
	for n in w.ai.nations:
		for i in range(AI_GENERALS):
			_enlist(int(n.id))

func ident(owner: int) -> String:
	return Factions.identity(w, owner)

func _name_for(owner: int) -> String:
	var pool: Array = NAMES.get(ident(owner), NAMES["*"])
	var taken: Array = roster.map(func(g): return g.name)
	taken.append_array(candidates.map(func(c): return c.name))   # three candidates are three different people
	for i in range(30):
		var n := "Gen. %s" % pool[randi() % pool.size()]
		if not n in taken:
			return n
	return "Gen. %s %d" % [pool[0], roster.size()]

func _traits_for(owner: int) -> Array:
	var favoured: Array = DOCTRINE.get(ident(owner), [])
	var all: Array = TRAITS.keys()
	var first: String = favoured[randi() % favoured.size()] if not favoured.is_empty() and randf() < 0.75 else all[randi() % all.size()]
	var second: String = first
	while second == first:
		second = favoured[randi() % favoured.size()] if not favoured.is_empty() and randf() < 0.5 else all[randi() % all.size()]
	return [first, second]

func _new(owner: int, name: String, traits: Array) -> Dictionary:
	_serial += 1
	var g := {"id": _serial, "name": name, "owner": owner, "traits": traits, "kills": 0, "level": 1, "unit": null, "wounded_until": 0.0, "alive": true}
	roster.append(g)
	return g

func _enlist(owner: int) -> Dictionary:
	return _new(owner, _name_for(owner), _traits_for(owner))

func _offer() -> void:
	candidates.clear()
	for i in range(CANDIDATES):
		candidates.append({"name": _name_for(0), "traits": _traits_for(0)})
	_next_offer = w.game_time + REFRESH

func hire_cost() -> float:
	return 600.0 + 400.0 * of(0).size()

## The living generals of `owner`.
func of(owner: int) -> Array:
	return roster.filter(func(g): return g.alive and int(g.owner) == owner)

func hire(index: int) -> String:
	if index < 0 or index >= candidates.size():
		return ""
	if of(0).size() >= MAX_PLAYER:
		return "Your general staff is full (%d). Dismiss one first." % MAX_PLAYER
	var cost := hire_cost()
	if not w.economy.pay({"money": cost}):
		return "A general's appointment costs $%d." % int(cost)
	var c: Dictionary = candidates[index]
	candidates.remove_at(index)
	candidates.append({"name": _name_for(0), "traits": _traits_for(0)})
	var g := _new(0, c.name, c.traits)
	return "%s joins your general staff (%s). Select a unit and give them its command." % [g.name, traits_text(g)]

func dismiss(g: Dictionary) -> String:
	g.alive = false
	_release(g)
	return "%s retires." % g.name

## Gives general `g` the command of unit `u`.
func assign(g: Dictionary, u: Dictionary) -> String:
	var why := assign_blocked(g, u)
	if why != "":
		return why
	_release(g)
	g.unit = u
	u.general = g.id
	_rebuild()
	return "%s takes command from the %s: units within %d m fight under their command." % [g.name, w.unit_defs.get(u.key, {}).get("name", u.key), int(COMMAND_RADIUS)]

func assign_blocked(g: Dictionary, u) -> String:
	if not g.alive:
		return "Gone."
	if float(g.wounded_until) > w.game_time:
		return "Wounded: back in %ds." % ceili(float(g.wounded_until) - w.game_time)
	if u == null or u.dead or int(u.owner) != int(g.owner):
		return "Select one of your units first."
	if u.get("fly", false) or float(u.get("dmg", 0.0)) <= 0.0 or u.key == "worker":
		return "A general commands from a ground or naval fighting unit."
	if u.has("general") and int(u.general) != int(g.id):
		return "That unit already carries a general."
	return ""

func _release(g: Dictionary) -> void:
	if g.unit != null:
		g.unit.erase("general")
	g.unit = null
	_rebuild()

func general_of(u: Dictionary):
	if not u.has("general"):
		return null
	for g in roster:
		if g.alive and int(g.id) == int(u.general):
			return g
	return null

func _rebuild() -> void:
	_by_owner.clear()
	for g in roster:
		if g.alive and g.unit != null and not g.unit.dead:
			if not _by_owner.has(int(g.owner)): _by_owner[int(g.owner)] = []
			_by_owner[int(g.owner)].append(g)

func strength(g: Dictionary) -> float:
	return 1.0 + 0.25 * (int(g.level) - 1)

## The generals whose command covers unit `u`: it stands within 50 m of them.
func commanding(u: Dictionary) -> Array:
	var out := []
	for g in _by_owner.get(int(u.get("owner", -1)), []):
		if g.unit == u or (u.has("node") and g.unit.node.position.distance_to(u.node.position) <= COMMAND_RADIUS):
			out.append(g)
	return out

func _class(u: Dictionary) -> Array:
	var base: String = preload("res://scripts/additional_factions.gd").base(str(u.get("key", "")))
	var out := ["*"]
	if u.get("fly", false): out.append("air")
	elif u.get("naval", false): out.append("naval")
	elif base in w.infantry_keys: out.append("infantry")
	elif base in w.armor_keys: out.append("armor")
	if base in ARTILLERY: out.append("artillery")
	if base in DRONES: out.append("drone")
	return out

## The damage `source` deals, from the generals commanding it (world.damage).
func damage_mult(source: Dictionary) -> float:
	if source.get("is_building", false) or not _by_owner.has(int(source.get("owner", -1))):
		return 1.0
	var m := 1.0
	var cls := _class(source)
	for g in commanding(source):
		for t in g.traits:
			if t == "airpower":
				continue   # (counted below, over the whole air force)
			var dmg: Dictionary = TRAITS[t].get("dmg", {})
			for c in dmg:
				if c in cls:
					m += float(dmg[c]) * strength(g)
	if source.get("fly", false):
		for g in _by_owner[int(source.owner)]:
			if "airpower" in g.traits:
				m += float(TRAITS.airpower.dmg.air) * strength(g)
	return maxf(m, 0.5)

## The damage `target` takes, from the generals commanding it.
func taken_mult(target: Dictionary) -> float:
	if target.get("is_building", false) or not _by_owner.has(int(target.get("owner", -1))):
		return 1.0
	var m := 1.0
	var infantry: bool = "infantry" in _class(target)
	for g in commanding(target):
		for t in g.traits:
			m += float(TRAITS[t].get("taken", 0.0)) * strength(g)
			if infantry:
				m += float(TRAITS[t].get("taken_infantry", 0.0)) * strength(g)
	return clampf(m, 0.5, 1.5)

func xp_mult(source: Dictionary) -> float:
	var m := 1.0
	for g in commanding(source):
		if "inspiring" in g.traits:
			m += float(TRAITS.inspiring.xp) * strength(g)
	return m

## An enemy killed by a unit under command: the generals' record.
func credit_kill(source: Dictionary) -> void:
	if not _by_owner.has(int(source.get("owner", -1))):
		return
	for g in commanding(source):
		g.kills = int(g.kills) + 1
		var lvl := 1
		for i in range(LEVELS.size()):
			if int(g.kills) >= int(LEVELS[i]): lvl = i + 1
		if lvl > int(g.level):
			g.level = lvl
			if int(g.owner) == 0:
				w.hud.notice("%s rises to level %d after %d kills: traits +%d%%." % [g.name, lvl, int(g.kills), roundi((strength(g) - 1.0) * 100.0)])

## The unit carrying a general is gone (world.kill).
func unit_lost(u: Dictionary) -> void:
	var g = general_of(u)
	if g == null:
		return
	g.unit = null
	u.erase("general")
	if randf() < 0.5:
		_fall(g, "killed in action")
	else:
		g.wounded_until = w.game_time + WOUNDED
		if int(g.owner) == 0:
			w.hud.notice("%s escaped the wreck of their command, wounded: out of action for 2 minutes." % g.name)
	_rebuild()

func _fall(g: Dictionary, how: String) -> void:
	g.alive = false
	g.unit = null
	var d: Node = w.diplomacy
	var owner: int = int(g.owner)
	if w.get("support") != null and w.support != null:
		w.support.change(owner, -4.0 * w.support.sensitivity(owner))
		for enemy in d.enemies_of(owner):
			w.support.change(enemy, 2.0)
	if owner == 0:
		w.hud.notice("%s has been %s. The nation mourns." % [g.name, how])
	elif d.at_war(0, owner):
		w.hud.notice("%s of %s has been %s." % [g.name, d.name_of(owner), how])
	_rebuild()

## An assassination (espionage.gd): the nation's most senior general dies.
func assassinated(owner: int) -> String:
	var mine := of(owner)
	if mine.is_empty():
		return ""
	mine.sort_custom(func(a, b): return int(a.kills) > int(b.kills))
	var g: Dictionary = mine[0]
	var name: String = g.name
	if g.unit != null: g.unit.erase("general")
	_fall(g, "assassinated")
	return name

## Once a second: the offer, wounds, healing under a Logistician, the rivals' staffs.
func update(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	var dt := _tick
	_tick = 0.0
	if w.game_time >= _next_offer:
		_offer()
	preload("res://scripts/veterancy.gd").update(w, dt)   # Heroic units' field repairs
	_rebuild()
	for owner in _by_owner:
		for g in _by_owner[owner]:
			if not "logistician" in g.traits:
				continue
			for u in w.units:
				if u.dead or int(u.owner) != owner or u.hp >= u.max_hp or w.game_time - float(u.get("last_hit", -100.0)) < 8.0:
					continue
				if g.unit.node.position.distance_to(u.node.position) <= COMMAND_RADIUS:
					u.hp = minf(float(u.max_hp), float(u.hp) + float(u.max_hp) * float(TRAITS.logistician.heal) * strength(g) * dt)
	_ai_staff()

var _ai_next := 0.0
func _ai_staff() -> void:
	if w.game_time < _ai_next or w.ai == null:
		return
	_ai_next = w.game_time + 20.0
	for n in w.ai.nations:
		var owner: int = int(n.id)
		if n.defeated:
			continue
		var staff := of(owner)
		if staff.size() < AI_GENERALS and w.game_time - float(n.get("general_lost_at", -1000.0)) > 240.0:
			_enlist(owner)
			n.general_lost_at = w.game_time
			staff = of(owner)
		for g in staff:
			if g.unit != null and not g.unit.dead:
				continue
			if float(g.wounded_until) > w.game_time:
				continue
			var best = null
			for u in w.units:
				if u.dead or int(u.owner) != owner or u.has("general") or assign_blocked(g, u) != "":
					continue
				if best == null or float(u.max_hp) > float(best.max_hp):
					best = u
			if best != null:
				g.unit = best
				best.general = g.id
	_rebuild()

func traits_text(g: Dictionary) -> String:
	return " · ".join(PackedStringArray(g.traits.map(func(t): return TRAITS[t].name)))

func capture() -> Dictionary:
	var alive: Array = w.units.filter(func(u): return not u.dead)
	var out := []
	for g in roster:
		if not g.alive:
			continue
		out.append({"id": g.id, "name": g.name, "owner": g.owner, "traits": g.traits, "kills": g.kills, "level": g.level,
			"wounded_until": g.wounded_until, "unit": alive.find(g.unit) if g.unit != null else -1})
	return {"roster": out, "candidates": candidates, "serial": _serial, "next_offer": _next_offer}

func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	for u in w.units: u.erase("general")
	roster.clear()
	var alive: Array = w.units.filter(func(u): return not u.dead)
	for s in data.get("roster", []):
		var g := {"id": int(s.id), "name": str(s.name), "owner": int(s.owner), "traits": Array(s.traits), "kills": int(s.kills), "level": int(s.level),
			"unit": null, "wounded_until": float(s.get("wounded_until", 0.0)), "alive": true}
		var i := int(s.get("unit", -1))
		if i >= 0 and i < alive.size():
			g.unit = alive[i]
			alive[i].general = g.id
		roster.append(g)
	candidates = Array(data.get("candidates", candidates))
	_serial = int(data.get("serial", roster.size()))
	_next_offer = float(data.get("next_offer", w.game_time + REFRESH))
	_rebuild()
