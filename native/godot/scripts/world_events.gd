extends RefCounted
## World events with causes: nothing here happens by chance. Each event starts
## because of what the nations do (a war, a blockade, a lost town), lasts while
## its cause lasts (and a little after), and reaches every nation through the
## world market and their economies, more or less by how exposed each is.
## Research and sources: native/WORLD-EVENTS-RESEARCH-2026-10-04.md.
##
##   Hormuz closed        Iran at war with the United States, Israel or Saudi
##                        Arabia, or Iran closing the strait itself: oil x1.8,
##                        gas x1.6; the Gulf exporters lose their outlet, the
##                        Asian importers (69% of the strait's oil) and Europe
##                        pay, other producers profit.
##   Black Sea grain      Russia or Ukraine at war: food x1.5; grain importers
##                        (Egypt above all) go hungry, other farm exporters gain.
##   Europe's gas crisis  Russia at war with Europe, the UK or Ukraine, or
##                        cutting Europe's gas: gas x2; Europe pays most, LNG
##                        exporters gain.
##   Rare-earth shock     China at war with an industrial power, or its export
##                        controls in force: silicon x1.7; the chip makers'
##                        research and industry slow.
##   Global recession     two of the five largest economies at war with each
##                        other: everyone earns less; fuel and metal cheapen.
##   Arms boom            three wars at once: the arms exporters sell more.
##   Refugee crisis       a town destroyed: its people flee to its nearest
##                        neighbours (citizens, and strain on their happiness).

const Factions := preload("res://scripts/factions.gd")
const TICK := 5.0
const LINGER := 45.0          # an event outlasts its cause by this long
const MAJORS := ["usa", "china", "eu", "japan", "india"]

## key -> name, the price shocks (fair value +x), per-nation income (by
## faction id; "*" every other nation), and the player's other effects.
const EVENTS := {
	"hormuz": {"name": "The Strait of Hormuz is closed",
		"prices": {"oil": 0.8, "gas": 0.6},
		"income": {"saudi": -0.25, "iraq": -0.25, "iran": -0.15, "japan": -0.12, "south_korea": -0.12, "india": -0.1, "china": -0.08, "pakistan": -0.08, "eu": -0.05,
			"usa": 0.04, "russia": 0.08, "brazil": 0.04, "australia": 0.03},
		"happiness": {"japan": -3.0, "south_korea": -3.0, "india": -2.0},
		"why": "about a fifth of the world's oil and of its LNG passes the strait; 69% of that oil goes to China, India, Japan and South Korea"},
	"grain": {"name": "Black Sea grain stops",
		"prices": {"food": 0.5},
		"income": {"egypt": -0.08, "pakistan": -0.04, "indonesia": -0.03, "iraq": -0.04, "syria": -0.05, "saudi": -0.02,
			"usa": 0.03, "brazil": 0.05, "australia": 0.04, "eu": 0.01},
		"happiness": {"egypt": -6.0, "syria": -5.0, "pakistan": -3.0, "iraq": -3.0, "afghanistan": -4.0, "indonesia": -2.0},
		"why": "Russia and Ukraine grow about a third of the world's wheat; in 2022 wheat rose 58%"},
	"gas": {"name": "Europe's gas crisis",
		"prices": {"gas": 1.0},
		"income": {"eu": -0.1, "uk": -0.05, "turkiye": -0.03, "usa": 0.05, "australia": 0.03, "russia": -0.04},
		"happiness": {"eu": -4.0, "uk": -2.0},
		"why": "Russia sent Europe 70 bcm less gas in 2022; prices passed 300 EUR/MWh"},
	"rare_earths": {"name": "Rare-earth shock",
		"prices": {"silicon": 0.7},
		"income": {"japan": -0.04, "south_korea": -0.04, "usa": -0.03, "eu": -0.03, "india": -0.02, "china": 0.03, "australia": 0.04},
		"research": {"usa": -0.08, "japan": -0.1, "south_korea": -0.1, "eu": -0.08, "india": -0.05, "uk": -0.05},
		"why": "China mines about 70% of the world's rare earths and refines about 90%"},
	"recession": {"name": "Global recession",
		"prices": {"oil": -0.2, "iron": -0.2, "silicon": -0.1},
		"income": {"*": -0.06},
		"why": "a war between two of the world's largest economies breaks the trade that binds them"},
	"arms_boom": {"name": "Arms boom",
		"prices": {"iron": 0.15},
		"income": {"usa": 0.04, "russia": 0.03, "eu": 0.03, "israel": 0.04, "south_korea": 0.04, "turkiye": 0.04, "china": 0.02},
		"why": "three wars at once: the arms exporters' order books fill"},
}

var w: Node
var active := {}              # key -> {since, cause_until, cause}
var refugees: Array = []      # {to, from, until, people}
var _tick := 0.0
var _version := 0             # bumps when the player's effects change

func _init(world: Node) -> void:
	w = world

func ident(owner: int) -> String:
	return Factions.identity(w, owner)

func owner_of(id: String) -> int:
	for i in range(w.map.nations.size()):
		if ident(i) == id and not w.diplomacy.defeated(i):
			return i
	return -1

func at_war_ids(a: String, others: Array) -> bool:
	var i := owner_of(a)
	if i < 0:
		return false
	for id in others:
		var j := owner_of(id)
		if j >= 0 and w.diplomacy.at_war(i, j):
			return true
	return false

func at_war_any(a: String) -> bool:
	var i := owner_of(a)
	return i >= 0 and not w.diplomacy.enemies_of(i).is_empty()

func _power(kind: String) -> bool:
	var effects = w.get("power_effects")
	return effects != null and effects.any(func(e): return e.kind == kind and float(e.until) > w.game_time)

## What causes each event now (a sentence), or "".
func cause_of(key: String) -> String:
	var d: Node = w.diplomacy
	match key:
		"hormuz":
			if _power("hormuz"):
				return "Iran has closed the strait"
			if at_war_ids("iran", ["usa", "israel", "saudi"]):
				return "Iran is at war with %s" % ", ".join(PackedStringArray(["usa", "israel", "saudi"].filter(func(x): return owner_of(x) >= 0 and owner_of("iran") >= 0 and d.at_war(owner_of("iran"), owner_of(x))).map(func(x): return d.name_of(owner_of(x)))))
		"grain":
			for id in ["russia", "ukraine"]:
				if at_war_any(id):
					return "%s is at war" % d.name_of(owner_of(id))
		"gas":
			if at_war_ids("russia", ["eu", "uk", "ukraine"]):
				return "Russia is at war in Europe"
			var eu := owner_of("eu")
			if eu >= 0 and w.get("power_effects") != null and w.power_effects.any(func(e): return e.kind == "income" and int(e.nation) == eu and ident(int(e.by)) == "russia" and float(e.until) > w.game_time):
				return "Russia has cut Europe's gas"
		"rare_earths":
			if at_war_ids("china", ["usa", "japan", "eu", "india", "south_korea", "uk", "australia"]):
				return "China is at war with an industrial power"
			if _power("production"):
				return "China's export controls are in force"
		"recession":
			for x in MAJORS:
				for y in MAJORS:
					if x < y and at_war_ids(x, [y]):
						return "%s and %s are at war" % [d.name_of(owner_of(x)), d.name_of(owner_of(y))]
		"arms_boom":
			var wars := 0
			for a in range(d.n):
				for b in range(a + 1, d.n):
					if d.at_war(a, b) and not d.defeated(a) and not d.defeated(b):
						wars += 1
			if wars >= 3:
				return "%d wars are being fought" % wars
	return ""

func update(delta: float) -> void:
	_tick += delta
	if _tick < TICK:
		return
	_tick = 0.0
	evaluate()

## Starts the events whose cause has come, ends those whose cause is long gone.
func evaluate() -> void:
	var changed := false
	for key in EVENTS:
		var cause := cause_of(key)
		if cause != "":
			if not active.has(key):
				active[key] = {"since": w.game_time, "cause_until": w.game_time, "cause": cause}
				_start(key, cause)
				changed = true
			else:
				active[key].cause_until = w.game_time
				active[key].cause = cause
		elif active.has(key) and w.game_time - float(active[key].cause_until) > LINGER:
			active.erase(key)
			_news("WORLD NEWS: it is over: %s no longer. Markets settle." % EVENTS[key].name.to_lower())
			changed = true
	for r in refugees.duplicate():
		if w.game_time > float(r.until):
			refugees.erase(r)
			changed = true
	if changed:
		_version += 1
		if w.research != null:
			w.research._recompute()
		if w.economy != null:
			w.economy.recalculate()

func _start(key: String, cause: String) -> void:
	var e: Dictionary = EVENTS[key]
	# Prices jump at once, then hold near their new level while it lasts.
	if w.market != null:
		for res in e.get("prices", {}):
			if w.market.mult.has(res):
				w.market.mult[res] = clampf(float(w.market.mult[res]) * (1.0 + float(e.prices[res]) * 0.6), 0.35, 3.0)
	var mine := income_of(0)
	var text := "WORLD NEWS: %s (%s). %s" % [e.name, cause, _prices_text(e)]
	if mine != 0.0:
		text += " Your income %+d%%." % roundi(mine * 100.0)
	_news(text)

func _prices_text(e: Dictionary) -> String:
	var parts := PackedStringArray()
	for res in e.get("prices", {}):
		parts.append("%s %+d%%" % [res, roundi(float(e.prices[res]) * 100.0)])
	return ("Prices: " + ", ".join(parts) + ".") if not parts.is_empty() else ""

func _news(text: String) -> void:
	if w.hud != null:
		w.hud.notice(text)

## The fair-value shock on commodity `res` from every event in force (market.exchange_step).
func price_shock(res: String) -> float:
	var s := 0.0
	for key in active:
		s += float(EVENTS[key].get("prices", {}).get(res, 0.0))
	return s

## The change to nation `owner`'s income from every event in force.
func income_of(owner: int) -> float:
	var id := ident(owner)
	var m := 0.0
	for key in active:
		var table: Dictionary = EVENTS[key].get("income", {})
		m += float(table.get(id, table.get("*", 0.0)))
	return m

func ai_income_mult(owner: int) -> float:
	return maxf(0.3, 1.0 + income_of(owner))

## The player's effects as research bonuses (research._recompute).
func bonuses() -> Dictionary:
	var id := ident(0)
	var out := {"incomePct": income_of(0)}
	var happy := 0.0
	var research := 0.0
	for key in active:
		happy += float(EVENTS[key].get("happiness", {}).get(id, 0.0))
		research += float(EVENTS[key].get("research", {}).get(id, 0.0))
	for r in refugees:
		if int(r.to) == 0:
			happy -= 3.0
	if happy != 0.0: out.happiness = happy
	if research != 0.0: out.researchPct = research
	return out

## A town destroyed (world.destroy_building): its people flee to the two
## nearest nations not at war with whoever drove them out.
func town_lost(b: Dictionary) -> void:
	if not b.key in ["hq", "cityCenter", "villageCenter"]:
		return
	var from: int = int(b.owner)
	var at: Vector3 = b.root.position
	var hosts := []
	for i in range(w.map.nations.size()):
		if i == from or w.diplomacy.defeated(i):
			continue
		var capital = null
		for c in w.buildings:
			if c.owner == i and c.key == "hq" and not c.dead:
				capital = c
		if capital != null:
			hosts.append([capital.root.position.distance_to(at), i])
	hosts.sort_custom(func(x, y): return x[0] < y[0])
	var people := 60 if b.key == "hq" else (40 if b.key == "cityCenter" else 20)
	for h in hosts.slice(0, 2):
		var to: int = h[1]
		refugees.append({"to": to, "from": from, "until": w.game_time + 240.0, "people": people})
		if to == 0 and w.economy != null:
			w.economy.civilians += people   # more hands, more mouths: and strain
	var names := PackedStringArray(hosts.slice(0, 2).map(func(h): return "you" if h[1] == 0 else w.diplomacy.name_of(h[1])))
	_news("WORLD NEWS: refugees flee the fall of %s's %s to %s." % [w.diplomacy.name_of(from), b.def.name, " and ".join(names)])
	_version += 1
	if w.research != null:
		w.research._recompute()

## Lines for the Cabinet: each event in force, its cause and what it does to you.
func summary() -> Array:
	var out := []
	for key in active:
		var e: Dictionary = EVENTS[key]
		var you := float(e.get("income", {}).get(ident(0), e.get("income", {}).get("*", 0.0)))
		out.append({"name": e.name, "cause": str(active[key].cause), "prices": _prices_text(e), "you": you, "why": e.get("why", "")})
	for r in refugees:
		if int(r.to) == 0:
			out.append({"name": "Refugees from %s" % w.diplomacy.name_of(int(r.from)), "cause": "their town fell", "prices": "", "you": 0.0, "why": "%d people sheltered; happiness -3" % int(r.people)})
	return out

func capture() -> Dictionary:
	return {"active": active.duplicate(true), "refugees": refugees.duplicate(true)}

func restore(data: Dictionary) -> void:
	active = data.get("active", {}).duplicate(true)
	refugees = data.get("refugees", []).duplicate(true)
	for r in refugees:
		r.to = int(r.to)
		r.from = int(r.from)
	if w.research != null:
		w.research._recompute()
