extends RefCounted
## United Nations gameplay; research: native/UN-RESEARCH-2026-10-05.md.
## A scaled Council uses permanent seats, rotating elected regional seats,
## consultations, affirmative thresholds and vetoes. Assembly recommendations
## have separate ballots and voluntary national implementation. Chapter VI
## proposals and peace observation await consent; Chapter VII restrictions
## affect economy/production/trade with a civilian food exemption. The
## Secretary-General offers mediation and raises prolonged wars. All active
## processes persist through JSON saves. Time scales and economic percentages
## are game balance, not claims about the real organisation.
const Data := preload("res://scripts/un_data.gd")
const TERM := 600.0
const PRESIDENCY := 60.0
const CONSULT_SECONDS := 15.0
const VOTE_SECONDS := 20.0
const PASS_SHARE := 0.6
const GA_SHARE := 2.0 / 3.0
const SANCTION_SECONDS := 360.0
const WITHDRAW_SECONDS := 120.0
const DRAFT_COOLDOWN := 90.0
const LOBBY_COST := 400.0
const DUES_PERIOD := 240.0
const ART99_AFTER := 300.0
const FIRST_NUMBER := 1        # campaign-local draft numbering
const FOREVER := 1.0e9
const MEASURES := {
	"statement": {"name": "Presidential statement", "severity": 0, "chapter": 6},
	"condemn": {"name": "Condemnation", "severity": 1, "chapter": 7},
	"ceasefire": {"name": "Ceasefire proposal", "severity": 1, "chapter": 6},
	"peacekeeping": {"name": "Consented peace observation", "severity": 1, "chapter": 6},
	"withdraw": {"name": "Demand to withdraw", "severity": 1, "chapter": 7},
	"targeted": {"name": "Targeted sanctions", "severity": 2, "chapter": 7},
	"embargo": {"name": "Arms embargo", "severity": 2, "chapter": 7},
	"icc": {"name": "Referral to the ICC", "severity": 3, "chapter": 7},
	"economic": {"name": "Comprehensive sanctions", "severity": 3, "chapter": 7},
	"nonproliferation": {"name": "Non-proliferation sanctions", "severity": 3, "chapter": 7},
	"force": {"name": "Authorisation of force", "severity": 4, "chapter": 7},
	"lift": {"name": "Lifting of sanctions", "severity": 0, "chapter": 7},
}
## The measures a sponsor tries, strongest first, by what the draft is about.
const LADDER := {
	"wmd": ["economic", "embargo", "targeted", "condemn", "statement"],
	"breakout": ["nonproliferation", "embargo", "targeted", "condemn"],
	"aggression": ["withdraw", "condemn", "statement"],
	"war": ["ceasefire", "statement"],
	"violation": ["economic", "targeted", "condemn"],
	"test": ["targeted", "condemn", "statement"],
}
const BASE := {"wmd": 0.8, "breakout": 0.7, "aggression": 0.3, "war": 0.45, "violation": 0.5, "test": 0.5, "player": 0.0}

var w: Node
var elected := {}              # member -> its term's end
var just_left: Array = []      # may not stand again at once
var term_ends := 0.0           # the next election
var presidency_ends := 0.0
var president := -1
var queue: Array = []
var current = null             # {number, kind, measure, title, target, other, by, cause, votes, lobby, phase, opens, closes}
var record: Array = []
var demands: Array = []        # {aggressor, victim, until}
var missions: Array = []       # peacekeeping: {a, b, until}
var authorised := {}           # target -> until: force authorised against it
var indicted := {}             # target -> true: referred to the ICC
var player_vote := ""
var next_draft := 0.0
var arrears := 0.0             # the player's unpaid dues
var withhold := false
var assessment := 0.0
var next_dues := 0.0
var sg_region := ""
var sg_votes := 0
var _number := FIRST_NUMBER
var _seen := {}
var _war_since := {}
var _campaign := {}
var assembly_queue: Array = []
var assembly_current = null
var assembly_record: Array = []
var compliance: Array = []       # demands await compliance, never magically end wars
var aid_next := 0.0
var _case_id := 1
var _dues_history: Array = []

func _init(world: Node) -> void:
	w = world
	_elect(true)
	_rotate()
	_choose_sg()
	_standing()
	next_dues = w.game_time + DUES_PERIOD

func _name(i: int) -> String:
	return "you" if i == 0 else w.diplomacy.name_of(i)

func _cap(i: int) -> String:
	return "You" if i == 0 else w.diplomacy.name_of(i)

func permanent(i: int) -> bool:
	return Data.permanent(w, i)

func _alive(i: int) -> bool:
	return i >= 0 and i < w.diplomacy.n and not w.diplomacy.defeated(i)

func members() -> Array:
	var out := []
	for i in range(w.diplomacy.n):
		if _alive(i) and Data.status(w, i) == "member":
			out.append(i)
	return out

func council() -> Array:
	var out := []
	var occupied := []
	for i in members():
		if permanent(i):
			var nation: Dictionary = w.map.nations[i]
			var seat := str(nation.get("un_seat", Data.seat_of(Data.ident(w, i))))
			if not seat in occupied:
				occupied.append(seat)
				out.append(i)
		elif elected.has(i):
			out.append(i)
	return out

func seats() -> int:
	return mini(10, ceili(members().filter(func(i): return not permanent(i)).size() / 2.0))

# ---------------------------------------------------------------- elections and the presidency

func _standing_of(i: int) -> float:
	var s := 0.0
	for j in members():
		if j != i: s += w.diplomacy.rel(i, j)
	return s + float(_campaign.get(i, 0.0))

## The General Assembly elects the members whose seats fall vacant, by region.
func _elect(first := false) -> void:
	var leaving: Array = elected.keys().filter(func(i): return first or float(elected[i]) <= w.game_time or not _alive(i))
	just_left = leaving.duplicate()
	for i in leaving: elected.erase(i)
	var want := seats()
	var filled := {}
	for i in elected: filled[Data.region(w, i)] = int(filled.get(Data.region(w, i), 0)) + 1
	var won := []
	while elected.size() < want:
		var pool: Array = members().filter(func(i): return not permanent(i) and not elected.has(i) and (first or not i in just_left))
		if pool.is_empty():
			break
		# The region furthest below its share of the seats.
		var best_region := ""
		var gap := -INF
		for r in Data.SEATS:
			if not pool.any(func(i): return Data.region(w, i) == r):
				continue
			var g: float = float(Data.SEATS[r]) / 10.0 * want - float(filled.get(r, 0))
			if g > gap:
				gap = g
				best_region = r
		var candidates: Array = pool.filter(func(i): return Data.region(w, i) == best_region) if best_region != "" else pool
		candidates.sort_custom(func(a, b): return _standing_of(a) > _standing_of(b))
		var pick: int = candidates[0]
		# Staggered terms: half the first members serve a single year.
		elected[pick] = w.game_time + (TERM * 0.5 if first and elected.size() % 2 == 1 else TERM)
		filled[Data.region(w, pick)] = int(filled.get(Data.region(w, pick), 0)) + 1
		won.append(pick)
	_campaign.clear()
	term_ends = w.game_time + TERM * 0.5
	if not first and (0 in won or 0 in leaving) and not permanent(0):
		w.hud.notice("UN: %s" % ("the General Assembly elects you to the Security Council for two years." if 0 in won else "your term on the Security Council has ended."))

## Your campaign for a seat: aid and visits, $1,500 a time.
func campaign() -> String:
	if not 0 in members():
		return "Observers cannot seek a Council seat."
	if 0 in just_left:
		return "A departing Council member cannot be immediately re-elected."
	if permanent(0) or elected.has(0):
		return "You already sit on the Council."
	if not w.economy.pay({"money": 1500.0}):
		return "A campaign costs $1,500."
	_campaign[0] = float(_campaign.get(0, 0.0)) + 120.0
	return "Your diplomats campaign for a seat at the next election (in %ds)." % ceili(term_ends - w.game_time)

var _told_presidency := false

func _rotate() -> void:
	var order: Array = council()
	order.sort_custom(func(a, b): return w.diplomacy.name_of(a) < w.diplomacy.name_of(b))
	if order.is_empty():
		president = -1
		return
	var at: int = order.find(president)
	president = order[(at + 1) % order.size()]
	presidency_ends = w.game_time + PRESIDENCY
	if president == 0 and w.hud != null and not _told_presidency:
		_told_presidency = true   # once is news; every fourth minute is noise
		w.hud.notice("UN: you hold the presidency of the Security Council this month: your drafts are taken first.")

## The Council recommends a Secretary-General by straw polls (a permanent
## member's "discourage" is a veto); the Assembly appoints. Latin America's turn.
func _choose_sg() -> void:
	sg_region = "the UN Secretariat"
	sg_votes = 0   # no fictional appointment/straw-poll result

## Sanctions regimes already in force (un_data.STANDING).
func _standing() -> void:
	for i in members():
		var row: Dictionary = Data.STANDING.get(Data.ident(w, i), {})
		if row.is_empty():
			continue
		for m in row.measures:
			_apply_measure(m, i, FOREVER)
		record.append({"number": 0, "kind": "standing", "measure": "standing", "title": "Sanctions on %s over %s" % [_name(i), row.res],
			"target": i, "other": -1, "by": -1, "cause": row.res, "votes": {}, "lobby": {}, "result": "in force", "tally": {"yes": 0, "no": 0, "abstain": 0}, "time": 0.0})

# ---------------------------------------------------------------- the clock

func update(_delta: float) -> void:
	if w.game_time >= term_ends:
		_elect()
	if w.game_time >= presidency_ends:
		_rotate()
	if current == null and not queue.is_empty():
		var at := 0
		for k in range(queue.size()):
			if int(queue[k].by) == president and president >= 0:
				at = k   # the president's own draft first
				break
		_open(queue.pop_at(at))
	if current != null:
		if current.phase == "consult" and w.game_time >= float(current.opens) + CONSULT_SECONDS:
			_to_vote()
		elif current.phase == "vote" and w.game_time >= float(current.closes):
			_close()
	for dm in demands.duplicate():
		if w.game_time >= float(dm.until):
			demands.erase(dm)
			if w.diplomacy.at_war(int(dm.aggressor), int(dm.victim)) and _alive(int(dm.aggressor)):
				table("violation", int(dm.aggressor), int(dm.victim), int(dm.victim), "its defiance of the Council's demand to stop its war on %s" % _name(int(dm.victim)))
	for m in missions.duplicate():
		if w.game_time >= float(m.until):
			missions.erase(m)
		elif w.diplomacy.at_war(int(m.a), int(m.b)):
			missions.erase(m)
			w.hud.notice("UN: the ceasefire between %s and %s is broken under the peacekeepers' eyes." % [_name(int(m.a)), _name(int(m.b))])
			var breaker: int = int(m.get("breaker", m.a))
			table("violation", breaker, int(m.b) if breaker == int(m.a) else int(m.a), -1, "breaking a ceasefire watched by UN peacekeepers")
	for t in authorised.keys():
		if w.game_time >= float(authorised[t]): authorised.erase(t)
	_article_99()
	_dues()
	_update_assembly()
	_update_compliance()

## The Secretary-General brings a long war to the Council.
func _article_99() -> void:
	var d: Node = w.diplomacy
	for a in range(d.n):
		for b in range(a + 1, d.n):
			var key := "%d-%d" % [a, b]
			if not d.at_war(a, b) or not _alive(a) or not _alive(b):
				_war_since.erase(key)
				continue
			if not _war_since.has(key):
				_war_since[key] = w.game_time
			elif w.game_time - float(_war_since[key]) >= ART99_AFTER and w.game_time - float(_seen.get("war" + key, -1e9)) >= 600.0:
				_seen["war" + key] = w.game_time
				table("war", a, b, -1, "the war between %s and %s (Art. 99)" % [_name(a), _name(b)])

## Your dues (a share of your income, as members pay by capacity); two years
## unpaid, you lose your vote in the Assembly (Art. 19).
func _dues() -> void:
	if w.game_time < next_dues or w.economy == null:
		return
	next_dues = w.game_time + DUES_PERIOD
	var rates = w.economy.get("rates")
	var rate: float = float(rates.get("money", 0.0)) if rates is Dictionary else 0.0
	assessment = clampf(rate * 12.0, 40.0, 1500.0)
	_dues_history.append(assessment)
	if _dues_history.size() > 2: _dues_history.pop_front()
	if withhold or not w.economy.pay({"money": assessment + arrears}):
		arrears += assessment
		if lost_vote():
			w.hud.notice("UN: your arrears ($%d) exceed two years of dues: you lose your vote in the General Assembly (Art. 19)." % int(arrears))
	else:
		arrears = 0.0

func lost_vote() -> bool:
	var threshold: float = _dues_history.reduce(func(total, amount): return total + float(amount), 0.0)
	return _dues_history.size() >= 2 and arrears >= threshold

func pay_arrears() -> String:
	if arrears <= 0.0:
		return "You owe the UN nothing."
	if not w.economy.pay({"money": arrears}):
		return "Your arrears are $%d." % int(arrears)
	arrears = 0.0
	return "Your arrears are paid: your vote in the Assembly is safe."

# ---------------------------------------------------------------- what comes before it

## A weapon of mass destruction used, or a breakout (wmd.gd).
func wmd_used(kind: String, weapon: String, by: int, victims: Array) -> void:
	var what: String = {"nuclear": "its use of a nuclear weapon", "chemical": "its use of chemical weapons", "bio": "its use of a biological weapon", "dirty": "its radiological attack",
		"reactor": "its attack on a nuclear reactor", "space": "its nuclear detonation in orbit", "breakout": "its nuclear weapon, built in breach of the NPT"}.get(kind, "its weapons of mass destruction")
	var sponsor: int = int(victims[0]) if not victims.is_empty() else -1
	table("breakout" if kind == "breakout" else "wmd", by, -1, sponsor, what)

## A war declared: opens a crisis case for any active pair of countries.
func war_declared(a: int, b: int, reason: String) -> void:
	for m in missions:
		if (int(m.a) == a and int(m.b) == b) or (int(m.a) == b and int(m.b) == a):
			m.breaker = a
	if reason.contains("ally") or reason.contains("coalition") or (float(authorised.get(b, 0.0)) > w.game_time):
		return   # collective self-defence or an authorised coalition
	var key := "%d-%d" % [a, b]
	if w.game_time - float(_seen.get(key, -10000.0)) < 600.0:
		return
	_seen[key] = w.game_time
	table("aggression", a, b, b, "%s attack on %s" % ["your" if a == 0 else w.diplomacy.name_of(a) + "'s", _name(b)])

## Puts a draft before the Council. `measure` "" lets the sponsor choose the
## strongest that would pass (or, if none would, force a vote on the strongest).
func table(kind: String, target: int, other: int, by: int, cause: String, measure := "") -> Dictionary:
	if kind in ["wmd", "breakout"]:
		queue = queue.filter(func(q): return not (q.kind == "aggression" and int(q.target) == target))
	if not _alive(target) or (other >= 0 and not _alive(other)) or (measure != "" and not MEASURES.has(measure)):
		return {}
	var dr := {"kind": kind, "measure": measure, "target": target, "other": other, "by": by, "cause": cause, "votes": {}, "lobby": {}, "title": "", "player_choice": ""}
	if measure == "":
		dr.measure = _penholder(dr)
	dr.title = _title(dr)
	queue.append(dr)
	return dr

func _title(dr: Dictionary) -> String:
	var t: int = int(dr.target)
	var o: int = int(dr.other)
	match str(dr.measure):
		"statement": return "Presidential statement on %s" % ("the war between %s and %s" % [_name(t), _name(o)] if o >= 0 and dr.kind == "war" else "%s's conduct: %s" % [_cap(t), dr.cause])
		"condemn": return "Condemns %s for %s" % [_name(t), dr.cause]
		"ceasefire": return "Proposes a ceasefire between %s and %s" % [_name(t), _name(o)]
		"peacekeeping": return "A ceasefire between %s and %s, watched by UN peacekeepers" % [_name(t), _name(o)]
		"withdraw": return "Demands that %s stop its war on %s within 2 minutes" % [_name(t), _name(o)]
		"targeted": return "Targeted sanctions on %s for %s" % [_name(t), dr.cause]
		"embargo": return "An arms embargo on %s for %s" % [_name(t), dr.cause]
		"icc": return "Refers %s to the International Criminal Court for %s" % [_name(t), dr.cause]
		"economic": return "Comprehensive sanctions on %s for %s (Chapter VII)" % [_name(t), dr.cause]
		"nonproliferation": return "Non-proliferation sanctions on %s for %s" % [_name(t), dr.cause]
		"force": return "Authorises all necessary means against %s for %s" % [_name(t), dr.cause]
		"lift": return "Lifts the sanctions on %s" % _name(t)
	return str(dr.cause)

## The sponsor's choice: the strongest measure on its ladder that would pass.
func _penholder(dr: Dictionary) -> String:
	var ladder: Array = LADDER.get(dr.kind, ["condemn"])
	for m in ladder:
		if tally(_with(dr, m), true).passes:
			return m
	return ladder[0]   # nothing would pass: force the vote and expose the veto

func _with(dr: Dictionary, measure: String) -> Dictionary:
	var c: Dictionary = dr.duplicate()
	c.measure = measure
	c.votes = {}
	c.player_choice = ""
	return c

func _open(dr: Dictionary) -> void:
	dr.electorate = council().duplicate()
	dr.number = _number if dr.measure != "statement" else 0
	if dr.measure != "statement":
		_number += 1
	dr.opens = w.game_time
	dr.phase = "consult"
	dr.closes = w.game_time + CONSULT_SECONDS + VOTE_SECONDS
	current = dr
	player_vote = ""
	if dr.measure == "statement":
		w.hud.notice("UN SECURITY COUNCIL: a presidential statement is proposed: %s. It needs every member's consent." % dr.title)
	else:
		w.hud.notice("UN SECURITY COUNCIL: draft resolution %d: %s. Consultations begin.%s" % [dr.number, dr.title, " Vote in the UN window (U)." if 0 in council() else ""])

## Consultations end: an AI sponsor weakens a draft that would be vetoed; then the vote.
func _to_vote() -> void:
	var dr: Dictionary = current
	if int(dr.by) != 0 and not tally(dr, true).passes:
		var ladder: Array = LADDER.get(dr.kind, [])
		var at: int = ladder.find(dr.measure)
		for k in range(at + 1, ladder.size()):
			if at >= 0 and tally(_with(dr, ladder[k]), true).passes:
				dr.measure = ladder[k]
				dr.title = _title(dr)
				w.hud.notice("UN: to escape a veto, the draft is weakened: %s." % dr.title)
				break
	dr.phase = "vote"
	dr.closes = w.game_time + (VOTE_SECONDS if 0 in council() else 2.0)

## The player's amendment during consultations.
func amend(measure: String) -> String:
	if current == null or int(current.by) != 0 or current.phase != "consult":
		return "Only your own draft, during consultations."
	var why := _measure_blocked(measure, int(current.target), int(current.other))
	if why != "": return why
	current.measure = measure
	current.player_choice = ""
	player_vote = ""
	current.title = _title(current)
	return "Your draft now reads: %s." % current.title

## Lobbying a member: aid moves its vote one step (`toward` +1 yes, -1 no).
func lobby_cost() -> float:
	return LOBBY_COST * (1.0 + 0.5 * float(MEASURES[current.measure].severity)) if current != null else LOBBY_COST

func lobby(member: int, toward: int) -> String:
	if current == null or current.phase != "consult" or member == 0 or not member in council() or not toward in [-1, 1]:
		return "Lobby a Council member during consultations."
	if abs(int(current.lobby.get(member, 0)) + toward) > 2:
		return "This delegation has already considered your full offer."
	var cost := lobby_cost()
	if not w.economy.pay({"money": cost}):
		return "Lobbying %s costs $%d." % [w.diplomacy.name_of(member), int(cost)]
	current.lobby[member] = clampi(int(current.lobby.get(member, 0)) + toward, -2, 2)
	w.diplomacy.change(0, member, 2.0)
	return "Your aid to %s is noted ($%d): it now leans %s." % [w.diplomacy.name_of(member), int(cost), vote_of(member, current).to_upper()]

# ---------------------------------------------------------------- the vote

func _score(i: int, dr: Dictionary) -> float:
	var d: Node = w.diplomacy
	var t: int = int(dr.target)
	var o: int = int(dr.other)
	var sev: float = float(MEASURES[dr.measure].severity)
	if dr.measure == "lift":
		return d.rel(i, t) / 100.0 - 0.1
	if dr.measure in ["ceasefire", "peacekeeping"]:
		# Peace is popular with those not fighting; the sponsor's friends follow it.
		return 0.6 + (d.rel(i, int(dr.by)) / 400.0 if int(dr.by) >= 0 and int(dr.by) != i else 0.0)
	var s: float = float(BASE.get(dr.kind, 0.0)) - d.rel(i, t) / 125.0 - 0.12 * sev
	if d.at_war(i, t) or i == o or i == int(dr.by):
		s += 1.0
	if d.allied(i, t) or _patron(i, t) or (permanent(i) and Data.shields(w, i, t)):
		s -= 1.5
	if Data.nam(w, i) and Data.nam(w, t):
		s -= 0.1 * sev   # non-aligned solidarity
	if dr.kind == "test" and str(preload("res://scripts/cbrn_data.gd").treaty(w, t, "npt")) == "nws":
		s -= 0.35   # a test by a recognised nuclear-weapon state draws words, rarely sanctions
	if Data.ident(w, i) in ["russia", "china"] and not dr.kind in ["wmd", "breakout"]:
		s -= 0.15 * sev   # sovereignty first
	if dr.kind == "war":
		s += 0.25
	if int(dr.by) >= 0 and int(dr.by) != i:
		s += d.rel(i, int(dr.by)) / 250.0
	return s

func vote_of(i: int, dr: Dictionary) -> String:
	var t: int = int(dr.target)
	var o: int = int(dr.other)
	var ga: bool = str(dr.get("chamber", "council")) == "assembly"
	if not ga and dr.measure != "statement" and (i == t or i == o) and int(MEASURES[dr.measure].chapter) == 6:
		return "abstain"   # a party to the dispute abstains (Art. 27(3))
	if i == 0 and str(dr.get("player_choice", "")) in ["yes", "no", "abstain"]:
		return str(dr.player_choice)
	if i == t:
		return "yes" if dr.measure == "lift" else "no"
	if i == 0:
		return "abstain"
	var steps := ["no", "abstain", "yes"]
	var s := _score(i, dr)
	var v := 2 if s > 0.25 else (0 if s < (-0.45 if permanent(i) else -0.2) else 1)
	# Historic alignment influences the score, but current diplomacy can change it.
	v = clampi(v + int(dr.get("lobby", {}).get(i, 0)), 0, 2)
	return steps[v]

func _patron(i: int, t: int) -> bool:
	var e = w.get("espionage")
	return e != null and e.puppets.has(t) and int(e.puppets[t].get("patron", -1)) == i

func cast(choice: String) -> String:
	if current == null or current.phase != "vote" or w.game_time >= float(current.closes) or not 0 in current.get("electorate", council()) or not choice in ["yes", "no", "abstain"]:
		return "Vote yes, no or abstain while the Council vote is open."
	if current.measure != "statement" and int(MEASURES[current.measure].chapter) == 6 and 0 in [int(current.target), int(current.other)]:
		return "As a party to this Chapter VI dispute, you must abstain."
	player_vote = choice
	current.player_choice = choice
	return "You vote %s on %s." % [choice.to_upper(), "the statement" if current.measure == "statement" else "draft resolution %d" % int(current.number)]

## The count: yes, no, abstain, the vetoes, and whether it passes. With
## `predict`, nothing is written down (the whip count).
func tally(dr: Dictionary, predict := false) -> Dictionary:
	var out := {"yes": 0, "no": 0, "abstain": 0, "vetoes": [], "passes": false}
	var c: Array = dr.get("electorate", council())
	for i in c:
		var v := vote_of(i, dr)
		if not predict:
			dr.votes[i] = v
		out[v] += 1
		if v == "no" and permanent(i):
			out.vetoes.append(i)
	if dr.measure == "statement":
		out.passes = not c.is_empty() and out.no == 0   # consensus, not a formal vote
	else:
		out.passes = out.yes >= needed(dr) and out.vetoes.is_empty()
	return out

## Yes votes needed: 9 of 15, proportionally scaled for smaller campaigns.
func needed(dr: Dictionary) -> int:
	# Nine of fifteen in a full Council; proportional in smaller campaigns.
	# Abstention does not reduce the affirmative-vote threshold.
	return maxi(1, ceili(dr.get("electorate", council()).size() * PASS_SHARE))

func _close() -> void:
	var dr: Dictionary = current
	current = null
	var t := tally(dr)
	dr.tally = {"yes": t.yes, "no": t.no, "abstain": t.abstain}
	dr.time = w.game_time
	var label := "the presidential statement" if dr.measure == "statement" else "resolution %d" % int(dr.number)
	if t.passes:
		dr.result = "adopted"
		w.hud.notice("UN: %s ADOPTED %s: %s." % [label, "by consensus" if dr.measure == "statement" else "%d-%d-%d" % [t.yes, t.no, t.abstain], dr.title])
		_enforce(dr)
	elif dr.measure == "statement":
		dr.result = "failed"
		w.hud.notice("UN: no consensus on the presidential statement (%d objected)." % t.no)
	elif not t.vetoes.is_empty():
		dr.result = "vetoed"
		dr.vetoed_by = t.vetoes
		var who := ", ".join(PackedStringArray(t.vetoes.map(func(v): return _cap(v))))
		w.hud.notice("UN: %s VETOED draft resolution %d (%d-%d-%d). The General Assembly meets on it." % [who, int(dr.number), t.yes, t.no, t.abstain])
		_assembly(dr)
	else:
		dr.result = "failed"
		w.hud.notice("UN: draft resolution %d failed: %d votes in favour of the %d needed." % [int(dr.number), t.yes, needed(dr)])
	record.append(dr)

func _enforce(dr: Dictionary) -> void:
	var t: int = int(dr.target)
	var o: int = int(dr.other)
	var d: Node = w.diplomacy
	match str(dr.measure):
		"statement":
			for i in council():
				if i != t: d.change(i, t, -3.0)
		"condemn":
			for i in council():
				if dr.votes.get(i, "") == "yes": d.change(i, t, -6.0)
			if w.get("support") != null and w.support != null: w.support.change(t, -3.0)
		"ceasefire", "peacekeeping":
			_start_compliance(dr)
		"withdraw":
			demands.append({"aggressor": t, "victim": o, "until": w.game_time + WITHDRAW_SECONDS})
			if t == 0:
				w.hud.notice("UN: make peace with %s within 2 minutes or face sanctions." % _name(o))
		"targeted", "embargo", "economic":
			_apply_measure(dr.measure, t, SANCTION_SECONDS)
		"nonproliferation":
			_apply_measure("embargo", t, SANCTION_SECONDS * 2.0)
			_apply_measure("economic", t, SANCTION_SECONDS)
		"icc":
			indicted[t] = true
			for i in members():
				if i != t and bool(preload("res://scripts/cbrn_data.gd").treaty(w, i, "icc")):
					d.change(i, t, -10.0)
			w.hud.notice("UN: the situation in %s is referred to the ICC for independent investigation. A referral is not an arrest warrant or conviction." % _name(t))
		"force":
			authorised[t] = w.game_time + 600.0
			for i in members():
				if i == 0 or i == t or d.at_war(i, t) or d.allied(i, t) or (permanent(i) and Data.shields(w, i, t)):
					continue
				if d.rel(i, t) < -15.0 and randf() < 0.5:
					d.declare_war(i, t, "%s joins the UN-authorised coalition against %s." % [d.name_of(i), _name(t)])
			w.hud.notice("UN: all necessary means are authorised against %s: joining the coalition is no aggression." % _name(t))
		"lift":
			w.power_effects = w.power_effects.filter(func(e): return not (int(e.nation) == t and int(e.get("by", 0)) == -2))
			w.hud.notice("UN: the sanctions on %s are lifted." % _name(t))
	d.changed.emit()
	if w.economy != null: w.economy.recalculate()
	if w.research != null: w.research._recompute()

## A sanctions measure in force on `t` (saved with the power effects).
func _apply_measure(measure: String, t: int, seconds: float) -> void:
	var until: float = w.game_time + seconds if seconds < FOREVER else FOREVER
	# Renew a regime instead of multiplying identical penalties indefinitely.
	for e in w.power_effects:
		if int(e.nation) == t and int(e.get("by", 0)) == -2 and str(e.get("un", "")) == measure:
			e.until = maxf(float(e.until), until)
			return
	match measure:
		"targeted":
			w.power_effects.append({"kind": "income", "nation": t, "value": 0.9, "until": until, "by": -2, "un": "targeted"})
		"economic":
			w.power_effects.append({"kind": "income", "nation": t, "value": 0.7, "until": until, "by": -2, "un": "economic"})
		"embargo":
			w.power_effects.append({"kind": "un_embargo", "nation": t, "value": 0.6, "until": until, "by": -2, "un": "embargo"})
	if seconds < FOREVER and w.hud != null:
		w.hud.notice("UN SANCTIONS on %s: %s." % [_name(t), {"targeted": "targeted restrictions (game abstraction: income -10%)", "economic": "comprehensive sanctions (income -30%; food relief exempt)", "embargo": "an arms embargo (game abstraction: military production -40%)"}[measure]])

func under(i: int, measure: String) -> bool:
	return w.power_effects.any(func(e): return int(e.nation) == i and str(e.get("un", "")) == measure and float(e.until) > w.game_time)

func sanctioned(i: int) -> bool:
	return w.power_effects.any(func(e): return int(e.nation) == i and int(e.get("by", 0)) in [-2, -3] and float(e.until) > w.game_time)

## Military production under an arms embargo (world.update_training, ai.gd).
func production_mult(i: int) -> float:
	return 0.6 if under(i, "embargo") else 1.0

## The world market shut to `i` by comprehensive sanctions (market.gd).
func market_closed(i: int, resource := "") -> bool:
	# Game abstraction of a humanitarian exemption, not an unlimited trade licence.
	return under(i, "economic") and resource != "food"

# ---------------------------------------------------------------- the General Assembly

## After a veto: debate and a separate non-binding Assembly ballot.
func _assembly(dr: Dictionary) -> void:
	# 76/262 mandates a debate, not automatic adoption or trade sanctions.
	dr.assembly = {"result": "pending", "yes": 0, "no": 0, "abstain": 0}
	var gd: Dictionary = _with(dr, "condemn")
	gd.chamber = "assembly"
	gd.player_choice = ""
	gd.source = int(dr.number)
	gd.phase = "queued"
	gd.lobby = {}
	gd.title = "Non-binding recommendation following the veto: " + str(dr.title)
	assembly_queue.append(gd)

func assembly_draft(t: int) -> String:
	if not 0 in members(): return "Observers may attend but cannot sponsor or vote."
	if not _alive(t) or t == 0: return "Choose a nation."
	if w.game_time < next_draft: return "Your mission is preparing another proposal."
	if cause_against(t) == "": return "No recorded crisis to bring before the Assembly."
	next_draft = w.game_time + DRAFT_COOLDOWN
	assembly_queue.append({"kind": "player", "chamber": "assembly", "measure": "condemn", "target": t, "other": -1, "by": 0, "cause": cause_against(t), "title": "Assembly recommendation on %s: %s" % [_name(t), cause_against(t)], "votes": {}, "lobby": {}, "player_choice": "", "source": -1})
	return "Your Assembly recommendation is queued; every member can vote, with no veto."

func cast_assembly(choice: String) -> String:
	if assembly_current == null or w.game_time >= float(assembly_current.closes) or not choice in ["yes", "no", "abstain"]:
		return "No open Assembly vote."
	if not 0 in members() or lost_vote(): return "You have no Assembly vote."
	assembly_current.player_choice = choice
	return "Your Assembly vote: %s." % choice.to_upper()

func _update_assembly() -> void:
	if assembly_current == null and not assembly_queue.is_empty():
		assembly_current = assembly_queue.pop_front()
		assembly_current.phase = "vote"
		assembly_current.closes = w.game_time + VOTE_SECONDS
		w.hud.notice("UN GENERAL ASSEMBLY: a separate vote opens. All members may vote in the Assembly tab (U); no veto applies.")
	if assembly_current != null and w.game_time >= float(assembly_current.closes):
		_finish_assembly()

func _finish_assembly() -> void:
	var d: Node = w.diplomacy
	var dr: Dictionary = assembly_current
	assembly_current = null
	var t: int = int(dr.target)
	var yes := []
	var no := 0
	var abstain := 0
	for i in members():
		if i == 0 and lost_vote():
			continue   # Art. 19
		var v := vote_of(i, dr)
		dr.votes[i] = v
		if v == "yes": yes.append(i)
		elif v == "no": no += 1
		else: abstain += 1
	dr.tally = {"yes": yes.size(), "no": no, "abstain": abstain}
	dr.time = w.game_time
	dr.participants = []
	if yes.size() > 0 and yes.size() >= ceili((yes.size() + no) * GA_SHARE):
		dr.result = "adopted"
		for i in yes:
			if i != t: d.change(i, t, -8.0)
		if w.get("support") != null and w.support != null:
			w.support.change(t, -6.0)
		if dr.kind in ["wmd", "breakout", "aggression", "violation"]:
			# An affirmative vote does not compel national implementation.
			for i in yes:
				if i != 0 and i != t and d.rel(i, t) < -25.0 and not d.allied(i, t):
					dr.participants.append(i)
		w.hud.notice("UN GENERAL ASSEMBLY: recommendation adopted %d-%d-%d. It is non-binding; %d nations voluntarily join economic restrictions." % [yes.size(), no, abstain, dr.participants.size()])
		d.changed.emit()
	else:
		dr.result = "failed"
		w.hud.notice("UN General Assembly: no two-thirds majority (%d-%d-%d)." % [yes.size(), no, abstain])
	dr.until = w.game_time + SANCTION_SECONDS
	assembly_record.append(dr)
	_refresh_voluntary(t)
	for original in record:
		if int(original.get("number", -2)) == int(dr.get("source", -1)):
			original.assembly = {"result": dr.result, "yes": yes.size(), "no": no, "abstain": abstain}
	if w.economy != null: w.economy.recalculate()

func _refresh_voluntary(target: int) -> void:
	var participants := []
	var until: float = w.game_time
	for dr in assembly_record:
		if int(dr.target) != target or dr.result != "adopted" or float(dr.until) <= w.game_time: continue
		until = maxf(until, float(dr.until))
		for i in dr.get("participants", []):
			if not int(i) in participants: participants.append(int(i))
	w.power_effects = w.power_effects.filter(func(e): return not (int(e.nation) == target and int(e.get("by", 0)) == -3 and e.get("un", "") == "voluntary"))
	if not participants.is_empty():
		w.power_effects.append({"kind": "income", "nation": target, "value": 1.0 - minf(0.25, 0.015 * participants.size()), "until": until, "by": -3, "un": "voluntary", "participants": participants})

func join_voluntary(target: int, join: bool) -> String:
	for k in range(assembly_record.size() - 1, -1, -1):
		var dr: Dictionary = assembly_record[k]
		if int(dr.target) != target or dr.result != "adopted" or float(dr.until) <= w.game_time: continue
		if target == 0 or not 0 in members(): return "You cannot join restrictions against yourself."
		for proposal in assembly_record:
			if int(proposal.target) == target: proposal.participants.erase(0)
		if join: dr.participants.append(0)
		_refresh_voluntary(target)
		w.economy.recalculate()
		return "You %s the voluntary restrictions on %s." % ["join" if join else "leave", _name(target)]
	return "No active Assembly recommendation."

func trade_blocked(a: int, b: int, resource: String) -> bool:
	if resource == "food": return false
	if market_closed(a, resource) or market_closed(b, resource): return true
	for dr in assembly_record:
		if dr.result == "adopted" and float(dr.until) > w.game_time:
			if (int(dr.target) == a and b in dr.participants) or (int(dr.target) == b and a in dr.participants): return true
	return false

# ---------------------------------------------------------------- compliance, mediation and humanitarian relief

func _ai_consent(i: int, other: int) -> bool:
	if not w.diplomacy.at_war(i, other): return true
	var popular: float = w.support.value(i) if w.get("support") != null else 50.0
	return popular < 55.0 or w.diplomacy.army_strength(i) <= w.diplomacy.army_strength(other) * 1.25

func _start_compliance(dr: Dictionary) -> void:
	var a: int = int(dr.target)
	var b: int = int(dr.other)
	if not _alive(a) or not _alive(b) or a == b: return
	var responses := {}
	for i in [a, b]:
		if i != 0: responses[i] = _ai_consent(i, b if i == a else a)
	compliance.append({"id": _case_id, "a": a, "b": b, "measure": dr.measure, "responses": responses, "until": w.game_time + WITHDRAW_SECONDS})
	_case_id += 1
	w.hud.notice("UN: %s awaits compliance by %s and %s. The war continues until both accept; respond in the Council tab." % [MEASURES[dr.measure].name, _name(a), _name(b)])

func respond(case_id: int, accept: bool) -> String:
	for c in compliance:
		if int(c.id) == case_id and 0 in [int(c.a), int(c.b)] and float(c.until) > w.game_time:
			c.responses[0] = accept
			_update_compliance()
			return "You %s the UN proposal." % ("accept" if accept else "reject")
	return "No active proposal addressed to you."

func _update_compliance() -> void:
	for c in compliance.duplicate():
		var a: int = int(c.a)
		var b: int = int(c.b)
		if not _alive(a) or not _alive(b):
			compliance.erase(c)
			continue
		if bool(c.responses.get(a, false)) and bool(c.responses.get(b, false)):
			if w.diplomacy.at_war(a, b): w.diplomacy.make_peace(a, b)
			if c.measure == "peacekeeping" and not missions.any(func(m): return (int(m.a) == a and int(m.b) == b) or (int(m.a) == b and int(m.b) == a)):
				missions.append({"a": a, "b": b, "until": w.game_time + 480.0})
			w.hud.notice("UN: both parties accept. %s" % ("Consented peace observers monitor the ceasefire for 8 minutes." if c.measure == "peacekeeping" else "The ceasefire takes effect."))
			compliance.erase(c)
		elif w.game_time >= float(c.until):
			compliance.erase(c)
			# A Chapter VI recommendation's rejection is not automatically a sanctionable violation.
			w.hud.notice("UN: the proposal between %s and %s expired without both parties' consent." % [_name(a), _name(b)])

func mediate(other: int) -> String:
	if not _alive(other) or other == 0 or not w.diplomacy.at_war(0, other): return "Choose an opponent in an active war."
	if compliance.any(func(c): return 0 in [int(c.a), int(c.b)] and other in [int(c.a), int(c.b)]): return "A proposal is already awaiting a response."
	if w.game_time < next_draft: return "Your mission is preparing another proposal."
	next_draft = w.game_time + DRAFT_COOLDOWN
	_start_compliance({"target": 0, "other": other, "measure": "ceasefire"})
	return "The Secretary-General offers good offices: both sides must accept."

func relief(target: int) -> String:
	if not _alive(target): return "Choose a nation."
	if w.game_time < aid_next: return "Another relief shipment can be arranged in %ds." % ceili(aid_next - w.game_time)
	if target == 0:
		var room: float = float(w.economy.caps.get("food", 0.0)) - float(w.economy.res.get("food", 0.0))
		if room <= 0.0: return "Your food stores are full."
		if not w.economy.pay({"money": 250.0}): return "Relief logistics cost $250."
		w.economy.res.food += minf(80.0, room)
	else:
		if not w.economy.pay({"money": 250.0, "food": 80.0}): return "Sending relief costs $250 and 80 food."
		if w.market != null:
			if not w.market.ai_stock.has(target): w.market.ai_stock[target] = {}
			w.market.ai_stock[target].food = float(w.market.ai_stock[target].get("food", 0.0)) + 80.0
		w.diplomacy.change(0, target, 5.0)
	if w.get("support") != null: w.support.change(target, 2.0)
	aid_next = w.game_time + 120.0
	w.economy.recalculate()
	return "Humanitarian food relief reaches %s; sanctions do not block this civilian channel." % _name(target)

# ---------------------------------------------------------------- the player's drafts

func cause_against(t: int) -> String:
	if w.get("wmd") != null and w.wmd != null:
		for inc in w.wmd.incidents:
			if int(inc.by) == t and inc.get("attributed", true) and w.game_time - float(inc.time) < 900.0:
				return {"nuclear": "its use of nuclear weapons", "chemical": "its use of chemical weapons", "bio": "its use of biological weapons", "dirty": "its radiological attack",
					"reactor": "its attack on a nuclear reactor", "space": "its nuclear detonation in orbit", "breakout": "its nuclear breakout"}.get(inc.kind, "its weapons of mass destruction")
	for dm in demands:
		if int(dm.aggressor) == t:
			return "its war on %s" % _name(int(dm.victim))
	var cases: Array = record + queue + ([current] if current != null else [])
	for r in cases:
		if r.kind == "aggression" and int(r.target) == t and w.diplomacy.at_war(t, int(r.other)) and w.game_time - float(r.get("time", 0.0)) < 900.0:
			return "its war on %s" % _name(int(r.other))
	return ""

func draft_blocked(measure: String, t: int, o := -1) -> String:
	if w.game_time < next_draft and president != 0:
		return "Your mission can table another draft in %ds." % ceili(next_draft - w.game_time)
	if not 0 in members():
		return "Observers can attend but cannot sponsor a member's proposal."
	return _measure_blocked(measure, t, o)

func _measure_blocked(measure: String, t: int, o := -1) -> String:
	if not MEASURES.has(measure): return "Choose a recognised UN measure."
	if not _alive(t) or t == 0:
		return "Choose a nation."
	if measure in ["targeted", "embargo", "economic", "nonproliferation", "withdraw", "icc", "force"] and cause_against(t) == "":
		return "No cause: sanctions need weapons of mass destruction, a war of aggression or a defied demand on record."
	if measure in ["ceasefire", "peacekeeping", "withdraw"] and (not _alive(o) or t == o or not w.diplomacy.at_war(t, o)):
		return "They are not at war."
	if measure == "lift" and not sanctioned(t):
		return "%s is under no UN sanctions." % w.diplomacy.name_of(t)
	return ""

func draft(measure: String, t: int, o := -1) -> String:
	var why := draft_blocked(measure, t, o)
	if why != "":
		return why
	next_draft = w.game_time + DRAFT_COOLDOWN
	var cause: String = cause_against(t)
	if cause == "":
		cause = "the war between %s and %s" % [_name(t), _name(o)] if o >= 0 else "its conduct"
	var dr := table("player", t, o, 0, cause, measure)
	return "Your mission tables a draft: %s." % dr.title

func bonuses() -> Dictionary:
	return {"happiness": -3.0} if sanctioned(0) else {}

func capture() -> Dictionary:
	var clean := func(dr):
		var c: Dictionary = dr.duplicate(true)
		for field in ["votes", "lobby", "responses"]:
			var out := {}
			for k in c.get(field, {}): out[str(k)] = c[field][k]
			c[field] = out
		return c
	var el := {}
	for k in elected: el[str(k)] = elected[k]
	var au := {}
	for k in authorised: au[str(k)] = authorised[k]
	var ind := {}
	for k in indicted: ind[str(k)] = true
	return {"elected": el, "just_left": just_left, "term_ends": term_ends, "presidency_ends": presidency_ends, "president": president,
		"queue": queue.map(clean), "current": clean.call(current) if current != null else null, "record": record.map(clean),
		"demands": demands, "missions": missions, "authorised": au, "indicted": ind, "next_draft": next_draft, "number": _number,
		"player_vote": player_vote, "arrears": arrears, "withhold": withhold, "assessment": assessment, "next_dues": next_dues,
		"sg_region": sg_region, "sg_votes": sg_votes,
		"assembly_queue": assembly_queue.map(clean), "assembly_current": clean.call(assembly_current) if assembly_current != null else null,
		"assembly_record": assembly_record.map(clean), "compliance": compliance.map(clean), "case_id": _case_id, "aid_next": aid_next,
		"seen": _seen.duplicate(), "war_since": _war_since.duplicate(), "campaign": _campaign.duplicate(), "dues_history": _dues_history.duplicate()}

func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var fix := func(dr):
		var c: Dictionary = dr.duplicate(true)
		for k in ["target", "other", "by", "number"]:
			if c.has(k): c[k] = int(c[k])
		var votes := {}
		for k in c.get("votes", {}): votes[int(k)] = c.votes[k]
		c.votes = votes
		var lob := {}
		for k in c.get("lobby", {}): lob[int(k)] = int(c.lobby[k])
		c.lobby = lob
		if c.has("vetoed_by"): c.vetoed_by = Array(c.vetoed_by).map(func(v): return int(v))
		for field in ["electorate", "participants"]:
			if c.has(field): c[field] = Array(c[field]).map(func(v): return int(v))
		var responses := {}
		for k in c.get("responses", {}): responses[int(k)] = bool(c.responses[k])
		c.responses = responses
		# Older saves stored the player's Council choice outside its draft.
		if not c.has("player_choice"): c.player_choice = ""
		return c
	elected.clear()
	for k in data.get("elected", {}): elected[int(k)] = float(data.elected[k])
	just_left = Array(data.get("just_left", [])).map(func(v): return int(v))
	term_ends = float(data.get("term_ends", w.game_time + TERM * 0.5))
	presidency_ends = float(data.get("presidency_ends", w.game_time + PRESIDENCY))
	president = int(data.get("president", -1))
	queue = Array(data.get("queue", [])).map(fix)
	current = fix.call(data.current) if data.get("current") != null else null
	record = Array(data.get("record", [])).map(fix)
	demands = Array(data.get("demands", [])).map(func(dm): return {"aggressor": int(dm.aggressor), "victim": int(dm.victim), "until": float(dm.until)})
	missions = Array(data.get("missions", [])).map(func(m):
		var mission := {"a": int(m.a), "b": int(m.b), "until": float(m.until)}
		if m.has("breaker"): mission.breaker = int(m.breaker)
		return mission)
	authorised.clear()
	for k in data.get("authorised", {}): authorised[int(k)] = float(data.authorised[k])
	indicted.clear()
	for k in data.get("indicted", {}): indicted[int(k)] = true
	next_draft = float(data.get("next_draft", 0.0))
	_number = int(data.get("number", FIRST_NUMBER))
	player_vote = str(data.get("player_vote", ""))
	if current != null and str(current.get("player_choice", "")) == "": current.player_choice = player_vote
	arrears = float(data.get("arrears", 0.0))
	withhold = bool(data.get("withhold", false))
	assessment = float(data.get("assessment", 0.0))
	next_dues = float(data.get("next_dues", w.game_time + DUES_PERIOD))
	sg_region = str(data.get("sg_region", sg_region))
	sg_votes = int(data.get("sg_votes", sg_votes))
	assembly_queue = Array(data.get("assembly_queue", [])).map(fix)
	assembly_current = fix.call(data.assembly_current) if data.get("assembly_current") != null else null
	assembly_record = Array(data.get("assembly_record", [])).map(fix)
	compliance = Array(data.get("compliance", [])).map(fix)
	_case_id = int(data.get("case_id", 1))
	aid_next = float(data.get("aid_next", 0.0))
	_seen = data.get("seen", {}).duplicate()
	_war_since = data.get("war_since", {}).duplicate()
	_campaign.clear()
	for k in data.get("campaign", {}): _campaign[int(k)] = float(data.campaign[k])
	_dues_history = data.get("dues_history", []).duplicate()
	if _dues_history.is_empty() and assessment > 0.0:
		_dues_history = [assessment, assessment]   # compatibility with earlier dues model
