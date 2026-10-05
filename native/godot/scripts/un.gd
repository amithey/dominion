extends RefCounted
## The United Nations. Research and sources: native/UN-RESEARCH-2026-10-05.md.
##
## The Security Council: the five permanent members in the match (the United
## States, Russia, China, the United Kingdom and France, for the European
## Union), each with a veto, and elected members for a term of 10 minutes
## (the General Assembly elects them by standing; the real Council has 10
## elected seats of two years). A draft resolution needs three-fifths of the
## Council voting yes (9 of 15 in New York) and no permanent member voting no.
## An abstention is not a veto (Council practice since 1946).
##
## What comes before it:
##   the use of a weapon of mass destruction (wmd.gd): a draft condemning its
##     user and imposing sanctions under Chapter VII (income -25% for 6 minutes);
##   a war of aggression involving the player: a draft demanding that the
##     aggressor withdraw (sanctions if it is still fighting 2 minutes later);
##   the player's own drafts (one every 2 minutes): sanctions on a nation with
##     a cause against it, or a ceasefire between two nations at war (adopted,
##     it ends their war).
## The members vote by their interest: a target's allies and its patron vote no,
## its victims and enemies yes, the rest by their relations with it; nearly
## everyone condemns weapons of mass destruction. The player votes when on the
## Council (25 s; the default is to abstain, or to vote no on a draft against
## yourself).
## A veto sends the matter to the General Assembly within days (the "veto
## initiative", resolution 76/262 of 2022): every nation votes, and a
## two-thirds majority condemns the target (relations with the yes votes -8,
## its war support -6) and costs the vetoing member some standing (-4 with
## the yes votes). The Assembly's resolutions bind no one, but they isolate.

const Factions := preload("res://scripts/factions.gd")
const P5 := ["usa", "russia", "china", "uk", "eu"]
const ELECTED_SEATS := 10
const TERM := 600.0
const VOTE_SECONDS := 25.0
const PASS_SHARE := 0.6
const GA_SHARE := 2.0 / 3.0
const SANCTIONS := 0.75
const SANCTION_SECONDS := 360.0
const WITHDRAW_SECONDS := 120.0
const DRAFT_COOLDOWN := 120.0
const FIRST_NUMBER := 2801     # the Council's resolutions had passed 2,790 by 2025

var w: Node
var elected: Array = []        # elected members of the Council
var term_ends := 0.0
var queue: Array = []          # drafts waiting
var current = null             # the draft being voted: {number, kind, title, target, other, by, cause, votes, opens, closes}
var record: Array = []         # finished drafts, newest last
var demands: Array = []        # {aggressor, victim, until}: withdraw or be sanctioned
var player_vote := ""          # "yes" / "no" / "abstain" for the current draft
var next_draft := 0.0          # the player's next draft
var _number := FIRST_NUMBER
var _seen_wars := {}

func _init(world: Node) -> void:
	w = world
	_elect()

func ident(i: int) -> String:
	return Factions.identity(w, i)

func permanent(i: int) -> bool:
	return ident(i) in P5

func _alive(i: int) -> bool:
	return i >= 0 and i < w.diplomacy.n and not w.diplomacy.defeated(i)

func members() -> Array:
	var out := []
	for i in range(w.diplomacy.n):
		if _alive(i): out.append(i)
	return out

func council() -> Array:
	var out := []
	for i in members():
		if permanent(i) or i in elected:
			out.append(i)
	return out

## The General Assembly elects the non-permanent members: the best liked.
func _elect() -> void:
	var d: Node = w.diplomacy
	var others: Array = members().filter(func(i): return not permanent(i))
	var standing := func(i):
		var s := 0.0
		for j in members():
			if j != i: s += d.rel(i, j)
		return s
	others.sort_custom(func(a, b): return standing.call(a) > standing.call(b))
	elected = others.slice(0, ELECTED_SEATS)
	term_ends = w.game_time + TERM

func update(_delta: float) -> void:
	if w.game_time >= term_ends:
		var before: bool = 0 in council()
		_elect()
		if not permanent(0) and (0 in elected) != before:
			w.hud.notice("UN: %s" % ("you have been elected to the Security Council." if 0 in elected else "your term on the Security Council has ended."))
	if current == null and not queue.is_empty():
		_open(queue.pop_front())
	if current != null and w.game_time >= float(current.closes):
		_close()
	for dm in demands.duplicate():
		if w.game_time >= float(dm.until):
			demands.erase(dm)
			if w.diplomacy.at_war(int(dm.aggressor), int(dm.victim)) and _alive(int(dm.aggressor)):
				_sanction(int(dm.aggressor), "it ignored the Council's demand to withdraw from %s" % _name(int(dm.victim)))

func _name(i: int) -> String:
	return "you" if i == 0 else w.diplomacy.name_of(i)

# ---------------------------------------------------------------- what comes before it

## A weapon of mass destruction used (wmd.gd).
func wmd_used(kind: String, weapon: String, by: int, victims: Array) -> void:
	var what: String = {"nuclear": "a nuclear weapon", "chemical": "chemical weapons", "bio": "a biological weapon", "dirty": "a radiological weapon"}.get(kind, "a weapon of mass destruction")
	var sponsor: int = int(victims[0]) if not victims.is_empty() else -1
	table("wmd", by, -1, sponsor, "the use of %s (%s)" % [what, w.missiles.def_of(weapon).get("name", weapon) if w.missiles != null else weapon])

## A war declared (diplomacy.declare_war): an aggression involving the player.
func war_declared(a: int, b: int, reason: String) -> void:
	if reason.contains("ally") or not (a == 0 or b == 0):
		return   # collective self-defence (Article 51), or a war far from you
	var key := "%d-%d" % [a, b]
	if w.game_time - float(_seen_wars.get(key, -10000.0)) < 600.0:
		return
	_seen_wars[key] = w.game_time
	table("aggression", a, b, b, "%s's attack on %s" % [w.diplomacy.name_of(a) if a > 0 else "your", "you" if b == 0 else w.diplomacy.name_of(b)])

## Puts a draft before the Council.
func table(kind: String, target: int, other: int, by: int, cause: String) -> Dictionary:
	var title := ""
	match kind:
		"wmd": title = "Condemns %s for %s; sanctions under Chapter VII" % [_name(target), cause]
		"aggression": title = "Demands that %s withdraw (%s)" % [_name(target), cause]
		"sanctions": title = "Sanctions on %s (%s)" % [_name(target), cause]
		"ceasefire": title = "Demands a ceasefire between %s and %s" % [_name(target), _name(other)]
	var draft := {"kind": kind, "title": title, "target": target, "other": other, "by": by, "cause": cause, "votes": {}}
	if kind == "wmd":
		# The weapon is the graver charge: it replaces a draft on the same attack.
		queue = queue.filter(func(q): return not (q.kind == "aggression" and int(q.target) == target))
	queue.append(draft)
	return draft

func _open(draft: Dictionary) -> void:
	draft.number = _number
	_number += 1
	draft.opens = w.game_time
	draft.closes = w.game_time + (VOTE_SECONDS if 0 in council() else 3.0)
	current = draft
	player_vote = ""
	w.hud.notice("UN SECURITY COUNCIL: draft resolution %d: %s.%s" % [draft.number, draft.title, " Cast your vote in the UN window (U)." if 0 in council() else ""])

# ---------------------------------------------------------------- the vote

## How member `i` votes on `draft`: "yes", "no" or "abstain".
func vote_of(i: int, draft: Dictionary) -> String:
	if i == 0 and player_vote != "":
		return player_vote
	var d: Node = w.diplomacy
	var t: int = int(draft.target)
	var o: int = int(draft.other)
	if i == t or (draft.kind == "ceasefire" and i == o and not d.at_war(i, t)):
		return "no"
	if i == 0:
		return "abstain"   # the player did not vote
	if draft.kind == "ceasefire":
		if i == o: return "no" if _winning(i, t) else "yes"
		if d.allied(i, t) or d.allied(i, o): return "abstain"
		return "yes"
	if d.allied(i, t) or _patron(i, t):
		return "no"
	var victim: bool = i == int(draft.by) or i == o
	if victim or d.at_war(i, t):
		return "yes"
	var base: float = {"wmd": 0.7, "aggression": 0.25, "sanctions": 0.05}.get(draft.kind, 0.0)
	var score: float = base - d.rel(i, t) / 100.0
	if int(draft.by) >= 0 and draft.kind == "sanctions":
		score += d.rel(i, int(draft.by)) / 200.0
	if score > 0.25: return "yes"
	if score < -0.15: return "no"
	return "abstain"

func _patron(i: int, t: int) -> bool:
	var e = w.get("espionage")
	return e != null and e.puppets.has(t) and int(e.puppets[t].get("patron", -1)) == i

func _winning(i: int, t: int) -> bool:
	return w.diplomacy.army_strength(i) > w.diplomacy.army_strength(t) * 1.3

func cast(choice: String) -> String:
	if current == null or not 0 in council():
		return ""
	player_vote = choice
	return "You vote %s on draft resolution %d." % [choice.to_upper(), current.number]

func tally(draft: Dictionary) -> Dictionary:
	var out := {"yes": 0, "no": 0, "abstain": 0, "vetoes": []}
	for i in council():
		var v := vote_of(i, draft)
		draft.votes[i] = v
		out[v] += 1
		if v == "no" and permanent(i):
			out.vetoes.append(i)
	return out

func _close() -> void:
	var draft: Dictionary = current
	current = null
	var t := tally(draft)
	var seats: int = council().size()
	var needed: int = ceili(seats * PASS_SHARE)
	draft.tally = {"yes": t.yes, "no": t.no, "abstain": t.abstain}
	draft.time = w.game_time
	if t.yes >= needed and t.vetoes.is_empty():
		draft.result = "adopted"
		w.hud.notice("UN: resolution %d ADOPTED %d-%d-%d: %s." % [draft.number, t.yes, t.no, t.abstain, draft.title])
		_enforce(draft)
	elif not t.vetoes.is_empty():
		draft.result = "vetoed"
		draft.vetoed_by = t.vetoes
		var who := ", ".join(PackedStringArray(t.vetoes.map(func(v): return _name(v))))
		w.hud.notice("UN: %s VETOED draft resolution %d (%d-%d-%d). The General Assembly meets on it." % ["You" if who == "you" else who, draft.number, t.yes, t.no, t.abstain])
		_assembly(draft)
	else:
		draft.result = "failed"
		w.hud.notice("UN: draft resolution %d failed: %d votes in favour of the %d needed." % [draft.number, t.yes, needed])
	record.append(draft)

func _enforce(draft: Dictionary) -> void:
	var t: int = int(draft.target)
	match draft.kind:
		"wmd", "sanctions":
			_sanction(t, draft.cause)
		"aggression":
			demands.append({"aggressor": t, "victim": int(draft.other), "until": w.game_time + WITHDRAW_SECONDS})
			if t == 0:
				w.hud.notice("UN: make peace with %s within 2 minutes or face sanctions." % _name(int(draft.other)))
		"ceasefire":
			if w.diplomacy.at_war(t, int(draft.other)):
				w.diplomacy.make_peace(t, int(draft.other))
				w.hud.notice("UN: the ceasefire between %s and %s is in force." % [_name(t), _name(int(draft.other))])

func _sanction(t: int, cause: String) -> void:
	w.power_effects.append({"kind": "income", "nation": t, "value": SANCTIONS, "until": w.game_time + SANCTION_SECONDS, "by": -2})
	w.hud.notice("UN SANCTIONS on %s (%s): income -25%% for 6 minutes." % [_name(t), cause])
	if w.economy != null: w.economy.recalculate()
	if w.research != null: w.research._recompute()

func sanctioned(i: int) -> bool:
	return w.power_effects.any(func(e): return e.kind == "income" and int(e.nation) == i and int(e.get("by", 0)) == -2 and float(e.until) > w.game_time)

## After a veto: the General Assembly votes; two thirds condemn.
func _assembly(draft: Dictionary) -> void:
	var d: Node = w.diplomacy
	var t: int = int(draft.target)
	var yes := []
	var no := 0
	var abstain := 0
	for i in members():
		var v := vote_of(i, draft)
		if v == "yes": yes.append(i)
		elif v == "no": no += 1
		else: abstain += 1
	draft.assembly = {"yes": yes.size(), "no": no, "abstain": abstain}
	if yes.size() >= ceili((yes.size() + no) * GA_SHARE) and yes.size() > 0:
		draft.assembly.result = "adopted"
		for i in yes:
			d.change(i, t, -8.0)
			for v in draft.get("vetoed_by", []):
				if int(v) != t: d.change(i, int(v), -4.0)
		if w.get("support") != null and w.support != null:
			w.support.change(t, -6.0)
		d.changed.emit()
		w.hud.notice("UN GENERAL ASSEMBLY condemns %s, %d-%d with %d abstentions. %s" % [_name(t), yes.size(), no, abstain, "The world turns its back on you." if t == 0 else ""])
	else:
		draft.assembly.result = "failed"
		w.hud.notice("UN General Assembly: no two-thirds majority on %s (%d-%d-%d)." % [draft.title.to_lower(), yes.size(), no, abstain])

# ---------------------------------------------------------------- the player's drafts

## Why nation `t` may be put under sanctions, or "" if there is no cause.
func cause_against(t: int) -> String:
	if w.get("wmd") != null and w.wmd != null:
		for inc in w.wmd.incidents:
			if int(inc.by) == t and w.game_time - float(inc.time) < 900.0:
				return "its use of %s weapons" % ("nuclear" if inc.kind == "nuclear" else ("chemical" if inc.kind == "chemical" else ("biological" if inc.kind == "bio" else "radiological")))
	for dm in demands:
		if int(dm.aggressor) == t:
			return "its war on %s" % _name(int(dm.victim))
	for r in record:
		if r.kind == "aggression" and int(r.target) == t and w.diplomacy.at_war(t, int(r.other)) and w.game_time - float(r.time) < 900.0:
			return "its war on %s" % _name(int(r.other))
	return ""

func draft_blocked(kind: String, t: int, o := -1) -> String:
	if w.game_time < next_draft:
		return "Your mission can table another draft in %ds." % ceili(next_draft - w.game_time)
	if not _alive(t) or t == 0:
		return "Choose a nation."
	if kind == "sanctions" and cause_against(t) == "":
		return "No cause: sanctions need a use of weapons of mass destruction or a war of aggression."
	if kind == "ceasefire" and not w.diplomacy.at_war(t, o):
		return "They are not at war."
	return ""

func draft(kind: String, t: int, o := -1) -> String:
	var why := draft_blocked(kind, t, o)
	if why != "":
		return why
	next_draft = w.game_time + DRAFT_COOLDOWN
	var cause: String = cause_against(t) if kind == "sanctions" else ""
	table(kind, t, o, 0, cause)
	return "Your mission tables a draft before the Security Council."

func bonuses() -> Dictionary:
	return {"happiness": -3.0} if sanctioned(0) else {}

func capture() -> Dictionary:
	var clean := func(dr):
		var c: Dictionary = dr.duplicate(true)
		var votes := {}
		for k in c.get("votes", {}): votes[str(k)] = c.votes[k]
		c.votes = votes
		return c
	return {"elected": elected, "term_ends": term_ends, "queue": queue.map(clean), "current": clean.call(current) if current != null else null,
		"record": record.map(clean), "demands": demands, "next_draft": next_draft, "number": _number, "player_vote": player_vote}

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
		if c.has("vetoed_by"): c.vetoed_by = Array(c.vetoed_by).map(func(v): return int(v))
		return c
	elected = Array(data.get("elected", [])).map(func(v): return int(v))
	term_ends = float(data.get("term_ends", w.game_time + TERM))
	queue = Array(data.get("queue", [])).map(fix)
	current = fix.call(data.current) if data.get("current") != null else null
	record = Array(data.get("record", [])).map(fix)
	demands = Array(data.get("demands", [])).map(func(dm): return {"aggressor": int(dm.aggressor), "victim": int(dm.victim), "until": float(dm.until)})
	next_draft = float(data.get("next_draft", 0.0))
	_number = int(data.get("number", FIRST_NUMBER))
	player_vote = str(data.get("player_vote", ""))
