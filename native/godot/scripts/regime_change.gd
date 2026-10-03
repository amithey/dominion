extends RefCounted
## The United States' leadership raid, after Operation Absolute Resolve (the
## capture of Nicolas Maduro in Caracas, 3 January 2026): a CIA team on the
## ground for months learns the leader's pattern of life; Cyber Command and the
## NSA black out the capital and blind its air defences; some 150 aircraft
## strike the air defences; Delta Force flies in low by helicopter and takes
## the leader. Research: native/RUSSIA-WAR-CAPABILITIES-2026-10-04.md.
##
## The player's United States: an Intel operation (espionage.gd) against a
## nation at war with it or deeply hostile, with a network of 60, intelligence
## of 50, a fresh field dossier, special forces and an airfield or helipad.
## A rival United States: it plans one on its own against a nation it is at
## war with, the player included, once its technology reaches era 3 and it can
## spare $4,000; one every 20 minutes at most (ai_consider).
## - The raid, either way: the capital's power and factories go dark for 90 s
##   and its air defences near the capital are struck (60% of their strength).
## - Success: the leader is captured and the regime replaced. The nation
##   becomes the United States' client state under a puppet ruler: the war
##   ends, it allies itself with its patron, joins its wars, pays it tribute,
##   and never turns on it; its people resent it (stability 40). And the world
##   fears the United States: for 15 minutes no government dares start a war
##   with it, the weaker of its enemies sue for peace at once, and every
##   government thinks a little less of it (-6); the player's peace offers and
##   pacts are taken 30% more readily while it is feared.
## - A raid on the player cannot make the player's country a puppet: the
##   player's leader is captured, a quarter of the treasury is lost in the
##   chaos and a provisional government signs a ceasefire with the United
##   States. An intelligence agency usually gets warning (and a counter-
##   intelligence review, the agency and counter-intelligence research make
##   the raid likelier to fail).
## - Failure: a special forces team and a helicopter lost (the player's), the
##   target at war with the raider and on alert for 10 minutes, every nation's
##   relations with the raider down, and (for the player) a scandal at home.

const KEY := "decapitationRaid"
const OP := {"name": "Leadership raid (Absolute Resolve)", "cost": 3000, "base": 0.1,
	"desc": "United States only. A CIA team maps the leader's life, Cyber Command blacks out the capital and blinds its air defences, airstrikes hit them, and Delta Force flies in by helicopter to take the leader. Success replaces the regime with a puppet ruler: the nation becomes your client state (it allies with you, joins your wars and pays tribute) and the world fears you. Failure costs special forces, a helicopter and a scandal."}
const FEAR_SECONDS := 900.0
const FEAR_BONUS := 0.3
const AIR_DEFENCE := ["aaVehicle", "samLauncher", "manpads", "laserAD", "abmLauncher", "irisT", "saudiThaad", "type45"]
const STRIKE_RADIUS := 140.0
const AI_COST := 3000.0
const AI_RESERVE := 1000.0
const AI_ERA := 3
const AI_PREPARE := 150.0
const AI_COOLDOWN := 1200.0
const PUPPET_LEADER := "Interim President (backed by Washington)"

static func us(w: Node) -> bool:
	return preload("res://scripts/factions.gd").identity(w, 0) == "usa"

## What the player's raid needs beyond the usual (espionage.blocked_reason), or "".
static func blocked(e: Node, nation: int) -> String:
	var w: Node = e.world
	var d: Node = w.diplomacy
	if not us(w):
		return "United States only."
	if e.puppets.has(nation):
		return "%s is already a client state." % d.name_of(nation)
	if not d.at_war(0, nation) and d.rel(0, nation) > -50.0:
		return "Only against a nation at war with you, or relations below -50."
	if not e.dossiers.has(nation) or e.clock - float(e.dossiers[nation].t) > 180.0 or e.dossiers[nation].get("confidence", "low") == "low":
		return "Requires a field dossier less than 180 seconds old (the leader's pattern of life)."
	if not w.units.any(func(u): return u.owner == 0 and not u.dead and u.key == "commando"):
		return "Requires special forces: a commando unit."
	if not w.buildings.any(func(b): return b.owner == 0 and not b.dead and b.built and b.key in ["airfield", "helipad"]):
		return "Requires an airfield or helipad for the helicopters."
	return ""

## The player's raid, when its preparation is over (espionage._resolve).
static func resolve(e: Node, mission: Dictionary, chance: float, roll: float) -> String:
	var w: Node = e.world
	var d: Node = w.diplomacy
	var nation: int = int(mission.nation)
	var name: String = d.name_of(nation)
	var struck := _strike(e, nation)
	var text := ""
	if roll < chance:
		text = install(e, nation, 0)
		e._gain_xp(e._agent(int(mission.agent)))
		e.add_report(nation, KEY, "Leadership raid on %s: success. %d air defences struck." % [name, struck], 20.0)
	else:
		text = _fail(e, nation, 0)
		e.add_report(nation, KEY, "Leadership raid on %s: failed." % name, 0.0)
	e.changed.emit()
	d.changed.emit()
	return "THE RAID ON %s: cyber blackout, %d air defences struck, helicopters in. %s" % [name.to_upper(), struck, text]

## The blackout and the strike on the air defences around the capital.
static func _strike(e: Node, nation: int) -> int:
	var w: Node = e.world
	if nation > 0:
		e._set_debuff(nation, "cyber", 90.0)   # the capital's power and factories go dark
	var capital = null
	for b in w.buildings:
		if b.owner == nation and b.key == "hq" and not b.dead:
			capital = b
			break
	if capital == null:
		return 0
	var at: Vector3 = capital.root.position
	var hit := 0
	for u in w.units.duplicate():
		if u.dead or u.owner != nation or not u.key in AIR_DEFENCE or u.node.position.distance_to(at) > STRIKE_RADIUS:
			continue
		w.effects.explosion(u.node.position + Vector3.UP, 1.4, true)
		u.hp -= u.max_hp * 0.6
		hit += 1
		if u.hp <= 0.0:
			w.kill(u)
	for b in w.buildings.duplicate():
		if b.dead or b.owner != nation or b.key != "samSite" or b.root.position.distance_to(at) > STRIKE_RADIUS:
			continue
		w.effects.explosion(b.root.position + Vector3.UP * 2.0, 2.0, true)
		b.hp -= b.max_hp * 0.6
		hit += 1
		if b.hp <= 0.0:
			w.destroy_building(b)
	w.effects.explosion(at + Vector3.UP * 3.0, 1.0, true)   # the compound
	return hit

## The leader taken; a puppet ruler installed for `patron`; the world afraid.
static func install(e: Node, nation: int, patron: int) -> String:
	var w: Node = e.world
	var d: Node = w.diplomacy
	var name: String = d.name_of(nation)
	var deposed: String = e.person(nation, "president")
	e.succession[nation]["president"] = int(e.succession[nation].get("president", 0)) + 1
	e.puppets[nation] = {"since": e.clock, "leader": PUPPET_LEADER, "deposed": deposed, "tribute": 0.0, "patron": patron}
	if d.at_war(patron, nation):
		d.make_peace(patron, nation)
	for grid in [d.alliance, d.pact, d.nap]:
		d.set_flag(grid, patron, nation, true)
	d.set_score(patron, nation, 75.0)
	e.stability[nation] = 40.0   # its people resent the new government
	e._set_debuff(nation, "paralyzed", 60.0)   # its army is leaderless for a minute
	for u in w.units:
		if u.owner == nation and not u.dead and u.get("enemy") is Dictionary and int(u.enemy.get("owner", -1)) == patron:
			u.enemy = null
			u.target = null
			u.attack_move = false
	# The world takes note.
	e.fears[patron] = e.clock + FEAR_SECONDS
	var sued := []
	for other in range(d.n):
		if other == nation or other == patron or d.defeated(other) or e.puppets.has(other):
			continue
		d.change(patron, other, -6.0)
		if other != 0 and d.at_war(patron, other) and d.army_strength(other) < d.army_strength(patron):
			d.make_peace(patron, other)
			sued.append(d.name_of(other))
	var text := ""
	if patron == 0:
		text = "%s captured and flown out. %s is now a US client state under a puppet ruler: it allies with you, joins your wars and pays tribute. The world fears you: for 15 minutes no government dares go to war with you." % [deposed, name]
	else:
		text = "WORLD NEWS: American special forces seized %s of %s. A government that answers to Washington takes power: %s is now %s's client state, and the world fears the United States." % [deposed, name, name, d.name_of(patron)]
	if not sued.is_empty():
		text += " Fearing they are next, %s sue for peace." % ", ".join(PackedStringArray(sued))
	return text

## A failed raid by `raider` on `nation`.
static func _fail(e: Node, nation: int, raider: int) -> String:
	var w: Node = e.world
	var d: Node = w.diplomacy
	var lost := []
	for kinds in [["commando"], ["helicopter", "gunship"]]:   # the team, and one helicopter
		for u in w.units:
			if u.owner == raider and not u.dead and u.key in kinds:
				lost.append(w.unit_defs[u.key].name)
				w.kill(u)
				break
	d.change(raider, nation, -40.0)
	if not d.at_war(raider, nation):
		d.declare_war(nation, raider, "%s answers the failed raid with war!" % d.name_of(nation))
	for other in range(d.n):
		if other != nation and other != raider and not d.defeated(other):
			d.change(raider, other, -8.0)
	if nation > 0:
		e._set_debuff(nation, "alert", 600.0)
	if raider == 0:
		e.scandal_until = maxf(e.scandal_until, e.clock + 240.0)
		e.heat[nation] = minf(100.0, float(e.heat[nation]) + 30.0)
		return "The raid failed: %s lost; %s is on alert for 10 minutes and the world condemns you." % [" and ".join(PackedStringArray(lost)) if not lost.is_empty() else "the team", d.name_of(nation)]
	if nation == 0:
		return "COUNTER-INTELLIGENCE: your security forces foiled an American raid on your capital. The world condemns %s." % d.name_of(raider)
	return "WORLD NEWS: an American raid on %s's leader failed; %s condemns it." % [d.name_of(nation), d.name_of(nation)]

# ---------------------------------------------------------------- a rival United States

## Every intelligence tick: a rival United States may plan a raid (on a nation
## it is at war with, the player included) and carries out the ones it planned.
## `force` (tests) skips the dice.
static func ai_consider(e: Node, force := false) -> void:
	var w: Node = e.world
	var d: Node = w.diplomacy
	if w.ai == null:
		return
	for n in w.ai.nations:
		var raider: int = int(n.id)
		if n.defeated or preload("res://scripts/factions.gd").identity(w, raider) != "usa":
			continue
		if e.ai_raids.any(func(r): return int(r.raider) == raider) or e.clock < float(e.ai_raid_next.get(raider, 0.0)):
			continue
		if w.research.ai_tech(raider) < AI_ERA * 2.0 or float(n.money) < AI_COST + AI_RESERVE:
			continue
		var targets: Array = d.enemies_of(raider).filter(func(t): return t != raider and not e.puppets.has(t) and not d.defeated(t))
		if targets.is_empty() or not (force or randf() < 0.1):
			continue
		launch(e, raider, targets[randi() % targets.size()])

## A rival United States commits to a raid on `target` (150 s of preparation).
static func launch(e: Node, raider: int, target: int, roll := -1.0) -> bool:
	var w: Node = e.world
	if not preload("res://scripts/war_costs.gd").pay(w, raider, AI_COST):
		return false
	e.ai_raids.append({"raider": raider, "target": target, "ends": e.clock + AI_PREPARE, "roll": roll})
	e.ai_raid_next[raider] = e.clock + AI_PREPARE + AI_COOLDOWN
	if target == 0 and e.has_agency() and (roll >= 0.0 or randf() < 0.7):
		w.hud.notice("INTELLIGENCE: %s's CIA is preparing a raid on your capital to seize your leader (about %d s). A counter-intelligence review now would help." % [w.diplomacy.name_of(raider), int(AI_PREPARE)])
	return true

## The chance a rival's raid succeeds: the player's guard (an agency, counter-
## intelligence research, a review in progress) or a rival's own service.
static func ai_chance(e: Node, target: int) -> float:
	var w: Node = e.world
	if target == 0:
		var guard: float = (0.18 if e.has_agency() else 0.0) + (w.research.bonus("counterSpy") if w.research else 0.0) + (0.25 if e.clock < e.security_until else 0.0)
		return clampf(0.65 - guard, 0.1, 0.9)
	return clampf(0.6 - e.counter_spy(target) - (0.15 if e.active(target, "alert") else 0.0), 0.1, 0.9)

## Rival raids whose preparation is over.
static func ai_advance(e: Node) -> void:
	var w: Node = e.world
	var d: Node = w.diplomacy
	for raid in e.ai_raids.duplicate():
		if e.clock < float(raid.ends):
			continue
		e.ai_raids.erase(raid)
		var raider: int = int(raid.raider)
		var target: int = int(raid.target)
		if d.defeated(raider) or d.defeated(target) or not d.at_war(raider, target):
			continue
		var struck := _strike(e, target)
		var roll: float = float(raid.roll) if float(raid.roll) >= 0.0 else randf()
		var text := ""
		if roll < ai_chance(e, target):
			text = _capture_player(e, raider) if target == 0 else install(e, target, raider)
		else:
			text = _fail(e, target, raider)
		w.hud.notice("%s (%d air defences struck.)" % [text, struck])
		e.changed.emit()
		d.changed.emit()

## The player's leader seized: the country cannot become a puppet, but a
## quarter of the treasury is lost and a ceasefire is signed under duress.
static func _capture_player(e: Node, raider: int) -> String:
	var w: Node = e.world
	var d: Node = w.diplomacy
	var lost: float = float(w.economy.res.money) * 0.25
	w.economy.res.money -= lost
	d.make_peace(0, raider)
	d.set_score(0, raider, 0.0)
	e.fears[raider] = e.clock + FEAR_SECONDS
	for other in range(1, d.n):
		if other != raider and not d.defeated(other):
			d.change(raider, other, -6.0)
	return "AMERICAN SPECIAL FORCES SEIZED YOUR LEADER. In the chaos $%d of the treasury is lost, and the provisional government signs a ceasefire with %s. The world fears the United States." % [int(lost), d.name_of(raider)]

# ---------------------------------------------------------------- client states

## Every intelligence tick (10 s): client states pay, fight beside their patron
## and stay loyal; a rival United States plans and carries out its raids.
static func tick(e: Node) -> void:
	var w: Node = e.world
	var d: Node = w.diplomacy
	for nation in e.puppets.keys():
		var p: Dictionary = e.puppets[nation]
		var patron: int = int(p.get("patron", 0))
		if d.defeated(nation) or d.defeated(patron) or d.at_war(patron, nation):
			e.puppets.erase(nation)   # it fell, its patron fell, or the patron turned on it
			continue
		if d.rel(patron, nation) < 70.0:
			d.set_score(patron, nation, 70.0)
		d.set_flag(d.alliance, patron, nation, true)
		var nat = w.market.ai_nation(nation)
		if nat != null:
			var tribute: float = minf(float(nat.money), 25.0 + float(nat.money) * 0.04)
			nat.money -= tribute
			if patron == 0:
				w.economy.res.money += tribute
			else:
				var lord = w.market.ai_nation(patron)
				if lord != null:
					lord.money += tribute
			p.tribute = float(p.get("tribute", 0.0)) + tribute
		for enemy in d.enemies_of(patron):
			if enemy != nation and enemy != patron and not d.at_war(nation, enemy):
				d.declare_war(nation, enemy, "%s, %s client state, joins the war against %s." % [d.name_of(nation), "your" if patron == 0 else d.name_of(patron) + "'s", "you" if enemy == 0 else d.name_of(enemy)])
	ai_advance(e)
	ai_consider(e)

## Whether AI nation `id` will not start a war with `other`: a client state
## never turns on its patron, and nobody dares while `other` is feared.
static func restrains(w: Node, id: int, other: int) -> bool:
	var e = w.get("espionage")
	if e == null or e.get("puppets") == null:
		return false
	if e.puppets.has(id) and int(e.puppets[id].get("patron", 0)) == other:
		return true
	return feared(w, other)

static func feared(w: Node, patron := 0) -> bool:
	var e = w.get("espionage")
	return e != null and e.get("fears") != null and float(e.fears.get(patron, 0.0)) > float(e.clock)

## Extra acceptance for the player's peace offers and pacts while feared.
static func fear_bonus(w: Node) -> float:
	return FEAR_BONUS if feared(w, 0) else 0.0
