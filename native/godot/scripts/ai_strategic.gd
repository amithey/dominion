extends RefCounted
## The strategic and doomsday side of the AI applications (ai_applications.gd):
## automated retaliation (a "dead hand"), undersea sensing and the second
## strike, and AI exports. Research: native/AI-STRATEGIC-USE-RESEARCH-2026-10-11.md.
##
## Automated retaliation (a nuclear power not bound by the declaration on human
## control): once commissioned, a nuclear attack on the nation is answered by
## the machine whether or not anyone is left to give the order. Rivals know it:
## their first use on the player is half as likely, and a rival that has it
## always strikes back. But the machine cannot tell a real attack from a false
## warning: when the early-warning system reports an attack that is not there,
## it may fire. Strategic warning verification makes that rarer, never zero.
## Undersea sensing: anti-submarine weapons hit submarines harder, and a nuclear
## power's sea-based second strike is less certain. Its rivals know that too:
## while you run it in a war with a nuclear power, the world's tension rises.
## AI exports: a package of compute, models and services sold to a nation at
## peace with you: money, better relations, and a window into its networks
## (espionage network) that its people may resent.

const ACCIDENT := 0.12        # the chance a false warning fires an armed dead hand
const EXPORT_COOLDOWN := 240.0
const EXPORT_PRICE := 900.0
const UNDERSEA_TENSION := 3.0 # every 30 s at war with a nuclear power

static func apps(w: Node) -> RefCounted:
	return w.directorate.applications if w.get("directorate") != null and w.directorate != null else null

static func factor(w: Node, owner: int, key: String) -> float:
	var a := apps(w)
	return a.factor(owner, key) if a != null else 0.0

## Whether `owner`'s retaliation is automated (commissioned and running).
static func armed(w: Node, owner: int) -> bool:
	return factor(w, owner, "deadHand") > 0.0

## The nuclear warheads `owner` (the player) has ready to fire, nearest first.
static func _ready_warhead(w: Node) -> String:
	for key in preload("res://scripts/wmd.gd").NUCLEAR:
		if int(w.missiles.stock.get(key, 0)) > 0 and not w.missiles.platforms_for(key, 0).is_empty() and not w.missiles.def_of(key).get("sub_only", false):
			return key
	return ""

static func _town_of(w: Node, owner: int, near: Vector3) -> Variant:
	var best = null
	for b in w.buildings:
		if int(b.owner) == owner and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"]:
			if best == null or b.root.position.distance_to(near) < best.root.position.distance_to(near):
				best = b
	return best

## The player's machine fires one stored warhead at `target`'s nearest town.
## `why` is shown. Returns the text, or "" if nothing could be fired.
static func fire(w: Node, target: int, why: String) -> String:
	var key := _ready_warhead(w)
	if key == "" or target <= 0 or w.diplomacy.defeated(target):
		return ""
	var platforms: Array = w.missiles.platforms_for(key, 0)
	var from: Vector3 = platforms[0].node.position
	var town = _town_of(w, target, from)
	if town == null:
		return ""
	w.missiles.stock[key] = int(w.missiles.stock[key]) - 1
	w.missiles.fly(key, from + Vector3.UP * 3.0, town.root.position, 0)
	w.missiles.changed.emit()
	if not w.diplomacy.at_war(0, target) and w.ai != null:
		w.ai.declare_war(target, true)
	var text := "AUTOMATED RETALIATION: %s Your machine fired a %s at %s's %s; no one gave the order." % [why, str(w.missiles.def_of(key).get("name", key)).to_lower(), w.diplomacy.name_of(target), town.def.name]
	w.directorate._note(text)
	w.hud.notice(text)
	return text

## A rival's nuclear weapon hit the player (defcon.nuclear_used): the machine answers.
static func answer(w: Node, attacker: int) -> String:
	if not armed(w, 0):
		return ""
	return fire(w, attacker, "a nuclear detonation on your territory.")

## A false warning while the dead hand is armed (ai_directorate.false_alarm).
## `roll` forces the outcome in tests (-1: random).
static func accident(w: Node, owner: int, roll := -1.0) -> String:
	if not armed(w, owner):
		return ""
	var p := ACCIDENT * (1.0 - 0.6 * factor(w, owner, "strategic"))
	if (randf() if roll < 0.0 else roll) >= p:
		return ""
	var d: Node = w.diplomacy
	if owner == 0:
		# The machine reads the attack as coming from the most dangerous nuclear rival.
		var suspect := -1
		for i in range(1, d.n):
			if d.defeated(i) or not w.defcon.nuclear(i): continue
			if suspect < 0 or (d.at_war(0, i) and not d.at_war(0, suspect)) or (d.at_war(0, i) == d.at_war(0, suspect) and d.rel(0, i) < d.rel(0, suspect)):
				suspect = i
		if suspect < 0:
			return ""
		return fire(w, suspect, "The warning was false, but the machine was armed.")
	# A rival's machine fires only at an enemy it is already fighting.
	if not d.at_war(owner, 0):
		return ""
	w.defcon._strike(owner, "an automated launch on a false warning", "nuke")
	var text := "AUTOMATED RETALIATION: %s's machine fired on a false warning." % d.name_of(owner)
	w.directorate._note(text)
	return text

## The second-strike certainty a rival keeps against the player's undersea sensing.
static func second_strike(w: Node, victim: int, base: float) -> float:
	if armed(w, victim):
		return 1.0
	return base * (1.0 - 0.25 * factor(w, 0, "undersea"))

## Every 30 s (ai_applications.update): undersea sensing in a war with a nuclear power.
static func undersea_tension(w: Node) -> void:
	var dc = w.get("defcon")
	if dc == null:
		return
	var d: Node = w.diplomacy
	for owner in range(d.n):
		if d.defeated(owner) or factor(w, owner, "undersea") < 0.5:
			continue
		if d.enemies_of(owner).any(func(e): return dc.nuclear(int(e))):
			dc.tension = minf(79.0 if w.game_time - float(dc.used_at) >= dc.USED_LOCK else 100.0, float(dc.tension) + UNDERSEA_TENSION)
			if owner == 0 and not w.directorate.log.any(func(e): return str(e.text).begins_with("UNDERSEA")):
				w.directorate._note("UNDERSEA: your sensors track the enemy's missile submarines. Its second strike is no longer certain, and it knows it: nuclear tension rises while the hunt goes on.")

# ---------------------------------------------------------------- AI exports

static func export_blocked(w: Node, owner: int, target: int, ready_at: float) -> String:
	var d: Node = w.diplomacy
	if target < 0 or target >= d.n or target == owner or d.defeated(target):
		return "Choose a living foreign nation."
	if factor(w, owner, "export") < 0.5:
		return "AI exports need at least 50% operating coverage."
	if w.game_time < ready_at:
		return "Next package in %ds." % ceili(ready_at - w.game_time)
	if d.at_war(owner, target) or d.rel(owner, target) < -20.0:
		return "%s will not buy from you." % d.name_of(target)
	if w.directorate.controlled(target) and w.directorate.can_control(owner):
		return "%s is under your export controls." % d.name_of(target)
	return ""

## `owner` sells an AI package to `target`: the buyer pays, relations warm, the
## seller gains access; the buyer's AI economy grows a little (a level of training).
static func export_to(w: Node, owner: int, target: int) -> String:
	var d: Node = w.diplomacy
	# A second-generation package (ai_applications.upgrade) sells for more.
	var price := EXPORT_PRICE * (1.5 if factor(w, owner, "export") > 1.0 else 1.0)
	# A buyer that cannot pay takes it on credit: the seller still gains the access.
	var buyer_pays: bool = w.directorate.applications.pay(target, price)
	if buyer_pays:
		if owner == 0:
			w.economy.res.money += price
		else:
			for n in w.ai.nations:
				if int(n.id) == owner: n.money += price
	d.change(owner, target, 10.0)
	var row: Dictionary = w.directorate._row(target)
	row.train = float(row.train) + 40.0
	var e = w.get("espionage")
	if owner == 0 and e != null and e.network.has(target):
		e.network[target] = minf(100.0, float(e.network[target]) + 15.0)
	var text := ""
	if owner == 0:
		text = "AI EXPORT: %s bought your AI package%s. Relations +10; your engineers now run part of its networks (espionage network +15)." % [d.name_of(target), (" for $%d" % int(price)) if buyer_pays else " on credit"]
	elif target == 0:
		text = "AI EXPORT: %s sold you an AI package for $%d: your models train faster, and its engineers see part of your networks." % [d.name_of(owner), int(price)]
	else:
		text = "AI EXPORT: %s sold an AI package to %s." % [d.name_of(owner), d.name_of(target)]
	w.directorate._note(text)
	return text
