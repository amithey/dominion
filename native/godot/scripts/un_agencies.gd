extends RefCounted
## The United Nations beside its Council and Assembly: the rhythm of a working organisation
## (native/UN-AGENCIES-2026-10-19.md). Every UN event is a message that begins "UN" or an agency's name,
## so the situation report files it under diplomacy.
##
##   Secretary-General   a briefing on the state of the world every few minutes: wars, sanctions, hunger;
##                       and the General Assembly's general debate as each year begins
##   IAEA                inspection rounds. A country with a nuclear weapons complex that is not a recognised
##                       or known weapon state is found in breach of its safeguards: the Board of Governors
##                       (two-thirds of its members) reports it to the Security Council, which takes it up
##                       as a breakout case (un.table). Power reactors are inspected and routine findings
##                       published.
##   WFP and UNHCR       a humanitarian appeal for a nation at war for long, or one with its people hungry or
##                       frozen: it asks for money. Nations give; so can you ($150 or $400, which also earns
##                       goodwill); an appeal for you, if met, brings food. Whatever is raised goes to the cause.
## Times, sums and thresholds are game balance.

const TICK := 5.0
const BRIEFING_EVERY := 300.0
const IAEA_EVERY := 210.0
const APPEAL_EVERY := 120.0
const APPEAL_LENGTH := 220.0
const YEAR := 720.0
const NUCLEAR_STATES := ["usa", "china", "russia", "uk", "eu", "india", "pakistan", "israel", "north_korea"]
const WAR_FOR := 200.0       # seconds at war before an appeal is made for it
const GOODWILL := 6.0
const RELIEF_FOOD := 90.0
const GIFTS := [150.0, 400.0]

var w: Node
var news: Array = []             # newest first: {t, agency, text}
var appeals: Array = []          # {id, nation, kind, need, raised, until, donors, closed, result}
var iaea_flagged := {}           # nation -> true: a breach has gone to the Council
var next_briefing := 0.0
var next_iaea := 0.0
var next_appeal := 0.0
var last_year := 0
var _tick := 0.0
var _id := 1
var _war_clock := {}             # "a-b" -> the time that war began

func _init(world: Node) -> void:
	w = world
	next_briefing = w.game_time + 150.0
	next_iaea = w.game_time + 120.0
	next_appeal = w.game_time + 90.0
	last_year = int(w.game_time / YEAR)

func _name(i: int) -> String:
	return "You" if i == 0 else str(w.diplomacy.name_of(i))

func _cap(i: int) -> String:
	return "Your nation" if i == 0 else str(w.diplomacy.name_of(i))

func _say(agency: String, text: String, pos := Vector3.INF) -> void:
	news.push_front({"t": w.game_time, "agency": agency, "text": text})
	if news.size() > 40:
		news.pop_back()
	if w.hud != null:
		w.hud.notice("%s: %s" % [agency, text], pos)

## Every frame (un.update).
func update(delta: float) -> void:
	_tick += delta
	if _tick < TICK:
		return
	_tick = 0.0
	var now: float = w.game_time
	_wars(now)
	var year := int(now / YEAR)
	if year > last_year:
		last_year = year
		_general_debate(year)
	if now >= next_briefing:
		next_briefing = now + BRIEFING_EVERY
		_briefing()
	if now >= next_iaea:
		next_iaea = now + IAEA_EVERY
		_iaea()
	if now >= next_appeal:
		next_appeal = now + APPEAL_EVERY
		_open_appeal()
	_appeals(now)

# ---------------------------------------------------------------- the Secretary-General and the Assembly

func _alive_nations() -> Array:
	var out := []
	for i in range(w.map.nations.size()):
		if i == 0 or not w.diplomacy.defeated(i):
			out.append(i)
	return out

func _wars(now: float) -> void:
	var d: Node = w.diplomacy
	var live := {}
	for a in range(d.n):
		for b in range(a + 1, d.n):
			if d.at_war(a, b) and not d.defeated(a) and not d.defeated(b):
				var key := "%d-%d" % [a, b]
				live[key] = true
				if not _war_clock.has(key):
					_war_clock[key] = now
	for key in _war_clock.keys():
		if not live.has(key):
			_war_clock.erase(key)

func _briefing() -> void:
	var d: Node = w.diplomacy
	var wars := 0
	for key in _war_clock:
		wars += 1
	var sanctioned := 0
	for i in _alive_nations():
		if w.un != null and w.un.sanctioned(i): sanctioned += 1
	var open_appeals := appeals.filter(func(a): return not a.closed).size()
	var text := "The Secretary-General briefs the Council: %d war%s under way, %d nation%s under sanctions, %d humanitarian appeal%s open." % [wars, "" if wars == 1 else "s", sanctioned, "" if sanctioned == 1 else "s", open_appeals, "" if open_appeals == 1 else "s"]
	if wars == 0 and sanctioned == 0 and open_appeals == 0:
		text = "The Secretary-General reports a quiet quarter: no war, no sanctions, no appeal open."
	_say("UN", text)

func _general_debate(year: int) -> void:
	var members := _alive_nations()
	if members.is_empty():
		return
	var speaker: int = members[randi() % members.size()]
	var topics := ["peace and security", "the cost of living and hunger", "climate and energy", "the reform of the Security Council", "non-proliferation", "the rights of small states"]
	_say("UN", "The General Assembly opens its general debate (session %d). %s addresses the Assembly on %s." % [year + 1, _name(speaker), topics[randi() % topics.size()]])

# ---------------------------------------------------------------- IAEA

func _iaea() -> void:
	var inspected := 0
	for i in _alive_nations():
		var id: String = preload("res://scripts/factions.gd").identity(w, i)
		var reactors: int = w.buildings.filter(func(b): return b.owner == i and not b.dead and b.built and b.key == "nuclearReactor").size()
		var complex: bool = w.buildings.any(func(b): return b.owner == i and not b.dead and b.built and b.key == "strategicComplex")
		if complex and not id in NUCLEAR_STATES and not iaea_flagged.has(i):
			# Inspectors find work that is not declared: the Board of Governors reports it.
			iaea_flagged[i] = true
			var yes := 24 + randi() % 6
			_say("IAEA", "inspectors at %s report undeclared nuclear weapons work. The Board of Governors finds a breach of its safeguards agreement (%d of 35 in favour, two-thirds needed) and reports it to the Security Council." % [_name(i), yes])
			if w.un != null:
				w.un.table("breakout", i, -1, -1, "undeclared nuclear weapons work found by IAEA inspectors")
			return
		if reactors > 0 and inspected < 2:
			inspected += 1
			_say("IAEA", "inspectors visited %s's %d power reactor%s: safeguards conclusions drawn, nothing to report." % [_name(i), reactors, "" if reactors == 1 else "s"])

# ---------------------------------------------------------------- humanitarian appeals

func _open_appeal() -> void:
	if appeals.any(func(a): return not a.closed):
		return   # one at a time
	var now: float = w.game_time
	var candidates := []
	var eco: Node = w.economy
	if eco.res.food <= 0.5:
		candidates.append([0, "food", "the hunger of its people"])
	if eco.get("cold") == true:
		candidates.append([0, "cold", "a winter without heating"])
	for key in _war_clock:
		if now - float(_war_clock[key]) >= WAR_FOR:
			var parts: PackedStringArray = key.split("-")
			var pick := int(parts[0]) if randf() < 0.5 else int(parts[1])
			if appeals.any(func(a): return int(a.nation) == pick and now - float(a.until) < 600.0):
				continue
			candidates.append([pick, "refugees", "the people displaced by its war"])
	if candidates.is_empty():
		return
	var c: Array = candidates[randi() % candidates.size()]
	var need := 500.0 + 100.0 * float(randi() % 4)
	var agency := "UNHCR" if c[1] == "refugees" else "WFP"
	appeals.append({"id": _id, "nation": int(c[0]), "kind": c[1], "need": need, "raised": 0.0, "until": now + APPEAL_LENGTH, "donors": {}, "closed": false, "result": ""})
	_id += 1
	_say(agency, "appeals for $%d for %s: %s. Donations in the UN window (Agencies)." % [int(need), _name(int(c[0])).to_lower() if int(c[0]) != 0 else "your nation", c[2]])

func _appeals(now: float) -> void:
	for a in appeals:
		if a.closed:
			continue
		# Other nations give now and then.
		if randf() < 0.18:
			var donors := _alive_nations().filter(func(i): return i != 0 and i != int(a.nation) and w.diplomacy.rel(i, int(a.nation)) > -30.0)
			if not donors.is_empty():
				var who: int = donors[randi() % donors.size()]
				var gift := float(20 + randi() % 50)
				a.raised = float(a.raised) + gift
				a.donors[who] = float(a.donors.get(who, 0.0)) + gift
		if float(a.raised) >= float(a.need) or now >= float(a.until):
			_close(a)

func _close(a: Dictionary) -> void:
	a.closed = true
	var funded: bool = float(a.raised) >= float(a.need)
	var agency := "UNHCR" if a.kind == "refugees" else "WFP"
	var share := clampf(float(a.raised) / maxf(float(a.need), 1.0), 0.0, 1.0)
	if funded:
		a.result = "funded"
		_say(agency, "the appeal for %s is fully funded ($%d raised)." % [_name(int(a.nation)).to_lower() if int(a.nation) != 0 else "your nation", int(a.raised)])
	else:
		a.result = "short"
		_say(agency, "the appeal for %s closes at %d%% ($%d of $%d)." % [_name(int(a.nation)).to_lower() if int(a.nation) != 0 else "your nation", int(share * 100.0), int(a.raised), int(a.need)])
	if int(a.nation) == 0 and share > 0.0:
		var food := RELIEF_FOOD * share
		w.economy.res.food = minf(float(w.economy.res.food) + food, float(w.economy.caps.get("food", 9999.0)))
		_say("WFP", "%d food delivered to your people." % int(food))

## You give to an appeal. Returns "" or why not.
func donate(appeal_id: int, amount: float) -> String:
	for a in appeals:
		if int(a.id) != appeal_id:
			continue
		if a.closed:
			return "That appeal is closed."
		if int(a.nation) == 0:
			return "That appeal is for your own nation."
		if not w.economy.pay({"money": amount}):
			return "Not enough money."
		a.raised = float(a.raised) + amount
		a.donors[0] = float(a.donors.get(0, 0.0)) + amount
		w.diplomacy.change(0, int(a.nation), GOODWILL * amount / GIFTS[0] * 0.5)
		_say("UN", "you give $%d to the appeal for %s: goodwill earned." % [int(amount), _name(int(a.nation)).to_lower()])
		if float(a.raised) >= float(a.need):
			_close(a)
		return ""
	return "No such appeal."

## What is next on the calendar, in words.
func calendar() -> Array:
	var now: float = w.game_time
	var out := []
	out.append(["Secretary-General's briefing", maxf(0.0, next_briefing - now)])
	out.append(["IAEA inspection round", maxf(0.0, next_iaea - now)])
	out.append(["General Assembly: next general debate", maxf(0.0, (last_year + 1) * YEAR - now)])
	return out

# ---------------------------------------------------------------- saves

func capture() -> Dictionary:
	var ap := []
	for a in appeals:
		var c: Dictionary = a.duplicate(true)
		var donors := {}
		for k in a.donors: donors[str(k)] = a.donors[k]
		c.donors = donors
		ap.append(c)
	var flagged := {}
	for k in iaea_flagged: flagged[str(k)] = true
	return {"news": news.duplicate(true), "appeals": ap, "flagged": flagged, "briefing": next_briefing, "iaea": next_iaea, "appeal": next_appeal, "year": last_year, "id": _id, "wars": _war_clock.duplicate()}

func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	news = Array(data.get("news", [])).duplicate(true)
	appeals = []
	for a in data.get("appeals", []):
		var c: Dictionary = a.duplicate(true)
		var donors := {}
		for k in c.get("donors", {}): donors[int(k)] = float(c.donors[k])
		c.donors = donors
		c.nation = int(c.nation)
		c.id = int(c.id)
		appeals.append(c)
	iaea_flagged = {}
	for k in data.get("flagged", {}): iaea_flagged[int(k)] = true
	next_briefing = float(data.get("briefing", next_briefing))
	next_iaea = float(data.get("iaea", next_iaea))
	next_appeal = float(data.get("appeal", next_appeal))
	last_year = int(data.get("year", last_year))
	_id = int(data.get("id", 1))
	_war_clock = data.get("wars", {}).duplicate()
