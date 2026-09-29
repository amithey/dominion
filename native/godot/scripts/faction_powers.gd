extends RefCounted
## Each nation's political power: the lever that nation pulls in the world of
## 2025-2026, used from the Diplomacy screen and recharged over minutes. The AI
## uses its nation's power too (mostly on nations it is at war with).
##
##   United States  Dollar Sanctions: secondary sanctions through the dollar
##                  system (maximum pressure on Iran, Russia's oil majors in 2025)
##   China          Rare-Earth Export Controls (April and October 2025): the
##                  target's factories, shipyards and airfields stop
##   European Union Sanctions Package (the 18th and 19th in 2025): the target
##                  earns less, and your partners turn against it too
##   Iran           Close the Strait of Hormuz: every other nation's sea trade stops
##   Russia         Energy Leverage: gas cut off, the target's economy suffers
##   India          Strategic Autonomy (Quad and BRICS, Russian oil and US
##                  markets): warmer relations with every nation at once
##   Japan          Development Aid: paid goodwill and a non-aggression pact
##   Turkiye        Istanbul Talks (the grain deal, prisoner exchanges, the 2025
##                  peace talks): ends a war, yours or two other nations'
##   Israel         Mossad Operation (Rising Lion, June 2025): sabotage,
##                  a stolen dossier and stolen research in one strike
## State lives on the world: power_ready {nation: game time} and power_effects.

const POWERS := {
	"blue": {"name": "Dollar Sanctions", "target": true, "cooldown": 300.0, "duration": 180.0,
		"desc": "Cut a nation off from the dollar system: its income falls 30% for 3 minutes. Relations with it fall 15."},
	"red": {"name": "Rare-Earth Export Controls", "target": true, "cooldown": 360.0, "duration": 90.0,
		"desc": "Stop rare-earth exports to a nation: its factories, shipyards and airfields stand still for 90 seconds. Relations with it fall 15."},
	"green": {"name": "Sanctions Package", "target": true, "cooldown": 300.0, "duration": 240.0,
		"desc": "A joint package: the nation's income falls 20% for 4 minutes, and every nation you have a pact or alliance with thinks less of it too. Relations with it fall 10."},
	"gold": {"name": "Close the Strait of Hormuz", "target": false, "cooldown": 480.0, "duration": 120.0,
		"desc": "Every other nation's sea trade stops for 2 minutes and their income falls 15%. Everyone's relations with you fall 10."},
	"russia": {"name": "Energy Leverage", "target": true, "cooldown": 300.0, "duration": 180.0,
		"desc": "Cut off the gas: the nation's income falls 25% for 3 minutes. Relations with it fall 15."},
	"india": {"name": "Strategic Autonomy", "target": false, "cooldown": 300.0, "duration": 0.0,
		"desc": "Deal with every camp at once: relations with every nation rise 12."},
	"japan": {"name": "Development Aid", "target": true, "cooldown": 240.0, "duration": 0.0, "cost": 800.0,
		"desc": "$800 of aid: relations with the nation rise 25 and it signs a non-aggression pact with you. Not for a nation you are at war with."},
	"turkiye": {"name": "Istanbul Talks", "target": true, "cooldown": 420.0, "duration": 0.0,
		"desc": "Host peace talks: a war between you and this nation ends (unless it hates you beyond -80), or, if you are at peace with it, its war with another nation does. Relations with both sides rise 10."},
	"israel": {"name": "Mossad Operation", "target": true, "cooldown": 360.0, "duration": 0.0,
		"desc": "A deep operation, never traced: sabotage in the nation's industry, a stolen dossier and stolen research. It needs no agents or agency."},
}

static func identity(w: Node, owner: int) -> String:
	return preload("res://scripts/national_arsenal.gd").identity(w, owner)

static func power_of(w: Node, owner: int) -> Dictionary:
	return POWERS.get(identity(w, owner), {})

## Seconds until `owner` may use its power again (0 when ready).
static func ready_in(w: Node, owner: int) -> float:
	return maxf(0.0, float(w.power_ready.get(owner, 0.0)) - w.game_time)

static func capture(w: Node) -> Dictionary:
	return {"ready": w.power_ready.duplicate(), "effects": w.power_effects.duplicate(true),
		"uses": w.power_uses.duplicate(true), "think": w.power_think}

static func restore(w: Node, data: Dictionary) -> void:
	w.power_ready.clear()
	# JSON converts integer dictionary keys into strings.
	for owner in data.get("ready", {}):
		w.power_ready[int(owner)] = float(data.ready[owner])
	w.power_effects = data.get("effects", []).duplicate(true)
	w.power_uses = data.get("uses", []).duplicate(true)
	w.power_think = float(data.get("think", 0.0))

## Why `owner` cannot use its power on `target` now, or "".
static func blocked(w: Node, owner: int, target := -1) -> String:
	var p := power_of(w, owner)
	if p.is_empty():
		return "No national power"
	if ready_in(w, owner) > 0.0:
		return "Ready in %d s" % int(ceilf(ready_in(w, owner)))
	var d: Node = w.diplomacy
	if p.target:
		if target < 0 or target == owner or target >= d.n or d.defeated(target):
			return "Choose a nation"
	match identity(w, owner):
		"japan":
			if d.at_war(owner, target):
				return "Not while at war with it"
			if owner == 0 and w.economy.res.money < float(p.cost):
				return "Needs $%d" % int(p.cost)
		"turkiye":
			if d.at_war(owner, target):
				if d.rel(owner, target) <= -80.0:
					return "It will not talk"
			elif _war_of(w, target, owner) < 0:
				return "No war to end"
	return ""

## Uses `owner`'s power (on `target` when it takes one). Returns what happened.
static func use(w: Node, owner: int, target := -1) -> String:
	var why := blocked(w, owner, target)
	if why != "":
		return why
	var p := power_of(w, owner)
	var d: Node = w.diplomacy
	var until: float = w.game_time + float(p.duration)
	var who: String = d.name_of(target) if target >= 0 else ""
	var me: String = "You" if owner == 0 else d.name_of(owner)
	var text := ""
	match identity(w, owner):
		"blue":
			_effect(w, "income", target, 0.7, until, owner)
			d.change(owner, target, -15.0)
			text = "%s cut %s off from the dollar: its income falls 30%% for 3 minutes." % [me, who]
		"red":
			_effect(w, "production", target, 0.0, until, owner)
			d.change(owner, target, -15.0)
			text = "%s stopped rare-earth exports to %s: its factories stand still for 90 seconds." % [me, who]
		"green":
			_effect(w, "income", target, 0.8, until, owner)
			d.change(owner, target, -10.0)
			for other in range(d.n):
				if other != owner and other != target and not d.defeated(other) and (d.allied(owner, other) or d.pact[owner][other]):
					d.change(other, target, -10.0)
			text = "%s adopted a sanctions package against %s: its income falls 20%% for 4 minutes." % [me, who]
		"gold":
			_effect(w, "hormuz", owner, 0.85, until, owner)
			for other in range(d.n):
				if other != owner and not d.defeated(other):
					d.change(owner, other, -10.0)
			text = "%s closed the Strait of Hormuz: all other sea trade stops for 2 minutes." % me
		"russia":
			_effect(w, "income", target, 0.75, until, owner)
			d.change(owner, target, -15.0)
			text = "%s cut off gas to %s: its income falls 25%% for 3 minutes." % [me, who]
		"india":
			for other in range(d.n):
				if other != owner and not d.defeated(other):
					d.change(owner, other, 12.0)
			text = "%s dealt with every camp at once: relations with every nation rise." % me
		"japan":
			if owner == 0:
				w.economy.res.money -= float(p.cost)
			d.change(owner, target, 25.0)
			d.set_flag(d.nap, owner, target, true)
			text = "%s sent development aid to %s: relations rise and a non-aggression pact is signed." % [me, who]
		"turkiye":
			if d.at_war(owner, target):
				d.make_peace(owner, target)
				d.change(owner, target, 10.0)
				text = "Talks in Istanbul: %s and %s make peace." % [me, who]
			else:
				var other := _war_of(w, target, owner)
				d.make_peace(target, other)
				d.change(owner, target, 10.0)
				d.change(owner, other, 10.0)
				text = "Talks in Istanbul: %s and %s make peace." % [who, d.name_of(other)]
		"israel":
			text = _mossad(w, owner, target)
	w.power_ready[owner] = w.game_time + float(p.cooldown)
	w.power_uses.append({"owner": owner, "power": identity(w, owner), "target": target, "time": w.game_time})
	if w.hud != null and (owner == 0 or target == 0 or identity(w, owner) in ["gold", "india"]):
		w.hud.notice(text)
	if d.has_signal("changed"):
		d.changed.emit()
	return text

static func _effect(w: Node, kind: String, nation: int, value: float, until: float, by: int) -> void:
	w.power_effects.append({"kind": kind, "nation": nation, "value": value, "until": until, "by": by})

## A nation `target` is at war with, other than `besides`, or -1.
static func _war_of(w: Node, target: int, besides: int) -> int:
	var d: Node = w.diplomacy
	for other in range(d.n):
		if other != target and other != besides and not d.defeated(other) and d.at_war(target, other):
			return other
	return -1

static func _mossad(w: Node, owner: int, target: int) -> String:
	var d: Node = w.diplomacy
	var hit := false
	var theirs: Array = w.buildings.filter(func(b): return b.owner == target and not b.dead and b.built and b.key != "hq")
	if not theirs.is_empty():
		var b: Dictionary = theirs[randi() % theirs.size()]
		w.damage(b, minf(b.max_hp * 0.5, 450.0), {"owner": owner, "dead": true, "key": "covert"})
		hit = true
	if owner == 0:
		w.research.points += 250.0
		if w.espionage != null:
			w.espionage.add_report(target, "reconDossier", "Mossad dossier on %s" % d.name_of(target), 30.0)
	else:
		for n in w.ai.nations:
			if n.id == owner:
				n.tech = minf(10.0, float(n.get("tech", 0.0)) + 0.5)
	return "A Mossad operation in %s: %sa dossier and research stolen, and nothing traced." % [d.name_of(target), "sabotage in its industry, " if hit else ""]

# ---------------------------------------------------------------- effects

static func _active(w: Node) -> Array:
	return w.power_effects.filter(func(e): return float(e.until) > w.game_time)

## Income multiplier for `nation` from sanctions, gas cut-offs and a closed strait.
static func income_mult(w: Node, nation: int) -> float:
	var m := 1.0
	for e in _active(w):
		if e.kind == "income" and int(e.nation) == nation:
			m *= float(e.value)
		elif e.kind == "hormuz" and int(e.by) != nation:
			m *= float(e.value)
	return m

## Military production of `nation` stopped by export controls.
static func production_blocked(w: Node, nation: int) -> bool:
	return _active(w).any(func(e): return e.kind == "production" and int(e.nation) == nation)

## Sea trade of `nation` stopped by a closed strait.
static func sea_closed(w: Node, nation: int) -> bool:
	return _active(w).any(func(e): return e.kind == "hormuz" and int(e.by) != nation)

const MILITARY := ["barracks", "tankFactory", "airfield", "helipad", "shipyard", "missileSilo"]

## Rival nations use their powers: mostly on the player when at war with it.
static func update(w: Node, delta: float) -> void:
	w.power_effects = _active(w)
	if w.ai == null:
		return
	w.power_think -= delta
	if w.power_think > 0.0:
		return
	w.power_think = 5.0
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		if n.defeated or ready_in(w, n.id) > 0.0 or power_of(w, n.id).is_empty():
			continue
		if w.game_time < 240.0:
			continue   # nobody reaches for the big levers in the opening minutes
		var p := power_of(w, n.id)
		var foe := -1
		for other in range(d.n):
			if other != n.id and not d.defeated(other) and d.at_war(n.id, other):
				foe = other
				if other == 0: break
		match identity(w, n.id):
			"india":
				if randf() < 0.3: use(w, n.id)
			"gold":
				if foe >= 0 and randf() < 0.25: use(w, n.id)
			"japan":
				var friend := -1
				for other in range(d.n):
					if other != n.id and not d.defeated(other) and not d.at_war(n.id, other) and d.rel(n.id, other) < 0.0:
						friend = other
				if friend >= 0 and randf() < 0.3: use(w, n.id, friend)
			"turkiye":
				if foe >= 0 and randf() < 0.2: use(w, n.id, foe)
			_:
				if foe >= 0 and p.target and randf() < 0.35: use(w, n.id, foe)
