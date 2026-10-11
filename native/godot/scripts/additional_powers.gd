extends RefCounted
## All state uses world.power_effects / power_ready and is included by the existing save service.
const Regional := preload("res://scripts/regional_powers.gd")
const F := preload("res://scripts/additional_factions.gd")
## Each nation's lever on another state, researched nation by nation:
## native/NATIONAL-POWERS-RESEARCH-2026-10-10.md (sources there, never in the
## game's text). "hostile" levers are aimed at rivals; the others at partners.
const POWERS := {
	"yemen": Regional.POWERS.yemen, "houthis": Regional.POWERS.houthis, "ethiopia": Regional.POWERS.ethiopia,
	"nigeria": Regional.POWERS.nigeria, "sudan": Regional.POWERS.sudan, "south_sudan": Regional.POWERS.south_sudan,
	"uk": {"name": "Maritime Insurance Ban", "target": true, "hostile": true, "cooldown": 360.0, "duration": 150.0, "costs": {"money": 400}, "needs": [],
		"desc": "$400: the London market, which insures most of the world's ships, stops covering a rival's cargo. Its sea trade stops and its income falls 15% for 150 s. Relations with it fall 12. Not on an ally."},
	"south_korea": {"name": "Arms Export Deal", "target": true, "hostile": false, "cooldown": 360.0, "duration": 0.0, "costs": {"iron": 80}, "needs": ["tankFactory"],
		"desc": "80 iron: a partner at peace with you (+10 relations or better) buys tanks and howitzers on Korean export credit. Two tanks and an artillery piece join its army at its capital; you earn $900 and relations rise 15. Requires a supplied tank factory."},
	"saudi": {"name": "OPEC+ Output Cut", "target": false, "hostile": false, "cooldown": 420.0, "duration": 180.0, "costs": {"money": 400}, "needs": [],
		"desc": "$400 in withheld sales: the cartel cuts its output. The world price of oil rises sharply for 3 minutes and your income rises 15%. Washington is displeased (-8)."},
	"brazil": {"name": "Food Diplomacy", "target": true, "hostile": false, "cooldown": 300.0, "duration": 0.0, "costs": {"food": 150}, "needs": ["port"],
		"desc": "Send 150 food to a trade partner with a supplied port. After a 30s sea voyage: +18 relations and food delivered. War, lost ports or sabotage can destroy the shipment; a closed strait delays it."},
	"indonesia": {"name": "Export Ban", "target": true, "hostile": true, "cooldown": 360.0, "duration": 120.0, "costs": {"money": 200}, "needs": ["extractor"],
		"desc": "$200: stop exports of nickel and palm oil to a rival that depends on them. Its factories, shipyards and airfields stand still for 45 s and its income falls 10% for 2 minutes. Relations with it fall 10. Not on an ally. Requires a supplied extractor."},
	"ukraine": {"name": "Long-Range Drone Strikes", "target": true, "hostile": true, "cooldown": 300.0, "duration": 120.0, "costs": {"money": 400, "silicon": 30}, "needs": [],
		"desc": "$400 + 30 silicon: a wave of long-range drones on an enemy you are at war with. Two of its refineries, power plants or factories lose 35% of their health, and its income falls 12% for 2 minutes."},
	"north_korea": {"name": "Crypto Heist", "target": true, "hostile": true, "cooldown": 360.0, "duration": 0.0, "costs": {"money": 150}, "needs": [],
		"desc": "$150: state hackers rob a rival's exchanges and banks: a quarter of its treasury, up to $900, is yours. Half the time the theft is traced (relations -15). Not on an ally."},
	"egypt": {"name": "Suez Canal", "target": true, "hostile": false, "cooldown": 360.0, "duration": 120.0, "costs": {"money": 200}, "needs": ["port"],
		"desc": "$200: priority passage through the canal for a nation at peace with you: its trade voyages are 30% shorter for 2 minutes and relations rise 12. At war, the canal is closed to the enemy instead: its sea trade stops for 2 minutes. Requires a supplied port."},
	"australia": {"name": "Critical Minerals Pact", "target": true, "hostile": false, "cooldown": 360.0, "duration": 0.0, "costs": {"iron": 80, "uranium": 20}, "needs": ["extractor"],
		"desc": "80 iron + 20 uranium: a minerals pact with a partner at peace with you (+10 relations or better). The ore is delivered to it, you earn $700, and relations rise 15. Requires a supplied extractor."},
	"pakistan": {"name": "Mutual Defence Pact", "target": true, "hostile": false, "cooldown": 420.0, "duration": 0.0, "costs": {"money": 400}, "needs": [],
		"desc": "$400: a mutual defence pact with a friendly nation (+20 relations or better, not at war with you): an attack on one is an attack on both. You become allies and relations rise 10."},
	"iraq": {"name": "Popular Mobilization", "target": false, "hostile": false, "cooldown": 360.0, "duration": 0.0, "costs": {"money": 500, "food": 60}, "needs": ["barracks"], "desc": "$500 + 60 food: six militia fighters (four riflemen, two rocket teams) muster at your capital. The militias answer to Tehran as much as to Baghdad: relations with the United States -6, with Iran +4. Requires a supplied barracks."},
	"syria": {"name": "Reconstruction Aid", "target": false, "hostile": false, "cooldown": 420.0, "duration": 60.0, "costs": {"money": 100}, "needs": [], "desc": "$100 to host a donors' conference: $250 pledged by every nation at +20 relations or better (up to four) arrives 30s later, and up to five damaged buildings near your capital regain 20% of their health over 60s. Needs at least one such partner."},
	"afghanistan": {"name": "Insurgent Attacks", "target": true, "hostile": true, "cooldown": 300.0, "duration": 90.0, "costs": {"money": 300}, "needs": [], "desc": "$300: attacks deep inside an enemy country, at war with you or at -40 relations or worse. Three of its buildings (not its capital) lose 30% of their health, and its income falls 15% for 90s. Every other nation's opinion of you falls by 5, the target's by 15."}
}
static func nation(w: Node, owner: int):
	if w.ai != null:
		for n in w.ai.nations:
			if int(n.id) == owner: return n
	return null
static func stock(w: Node, owner: int) -> Dictionary:
	if owner == 0: return w.economy.res
	var key := str(owner)
	if not w.market.ai_stock.has(key): w.market.ai_stock[key] = {}
	return w.market.ai_stock[key]
static func funds(w: Node, owner: int, resource: String) -> float:
	if owner != 0 and resource == "money":
		var n = nation(w, owner)
		return float(n.money) if n != null else 0.0
	return float(stock(w, owner).get(resource, 0.0))
static func pay(w: Node, owner: int, costs: Dictionary) -> bool:
	for r in costs:
		if funds(w, owner, r) < float(costs[r]): return false
	for r in costs:
		if owner != 0 and r == "money": nation(w, owner).money -= float(costs[r])
		else: stock(w, owner)[r] = funds(w, owner, r) - float(costs[r])
	return true
static func owned(w: Node, owner: int, key: String) -> bool:
	return w.buildings.any(func(b): return b.owner == owner and b.key == key and b.built and not b.dead and b.get("supplied", true) and not w.disabled(b))
static func escorts(w: Node, owner: int) -> int:
	return w.units.filter(func(u): return u.owner == owner and not u.dead and u.get("naval", false) and u.dmg > 0 and not w.disabled(u)).size()
static func repairs(w: Node, owner: int) -> Array:
	var centre = w.selected_building if owner == 0 else null
	if centre == null or centre.dead or centre.owner != owner or centre.key not in ["hq", "cityCenter", "villageCenter"]:
		centre = null
		for b in w.buildings:
			if b.owner == owner and b.key == "hq" and not b.dead: centre = b
	if centre == null: return []
	var list: Array = w.buildings.filter(func(b): return b.owner == owner and b.built and not b.dead and b.hp < b.max_hp and b.root.position.distance_to(centre.root.position) <= 100.0)
	list.sort_custom(func(a, b): return a.hp / a.max_hp < b.hp / b.max_hp)
	return list.slice(0, 5)
static func blocked(w: Node, owner: int, target: int) -> String:
	var id := F.id_of(w, owner)
	if Regional.POWERS.has(id): return Regional.blocked(w, owner, target)
	var p: Dictionary = POWERS[id]
	for key in p.needs:
		if not owned(w, owner, key): return "Needs supplied " + str(w.building_defs.get(key, {}).get("name", key))
	for r in p.costs:
		if funds(w, owner, r) < float(p.costs[r]): return "Needs %d %s" % [int(p.costs[r]), r]
	if p.target and (target < 0 or target == owner or target >= w.diplomacy.n or w.diplomacy.defeated(target)): return "Choose a nation"
	match id:
		"uk", "indonesia":
			if w.diplomacy.allied(owner, target): return "Not on an ally"
		"south_korea", "australia":
			if w.diplomacy.at_war(owner, target) or w.diplomacy.rel(owner, target) < 10.0: return "Needs a partner at peace (+10 relations or better)"
		"brazil":
			if w.diplomacy.at_war(owner, target) or not w.diplomacy.pact[owner][target]: return "Needs a trade partner at peace"
			if not owned(w, target, "port"): return "Partner needs a supplied port"
		"ukraine":
			if not w.diplomacy.at_war(owner, target): return "Only on an enemy you are at war with"
			if strike_targets(w, target).is_empty(): return "No buildings to strike there"
		"north_korea":
			if w.diplomacy.allied(owner, target): return "Not on an ally"
			if funds(w, target, "money") < 100.0: return "Its treasury is nearly empty"
		"pakistan":
			if w.diplomacy.at_war(owner, target) or w.diplomacy.rel(owner, target) < 20.0: return "Needs a friendly nation (+20 relations or better)"
			if w.diplomacy.allied(owner, target): return "Already allied"
		"syria":
			if partners(w, owner).is_empty(): return "Needs a partner at +20 relations or better"
		"afghanistan":
			if target < 0 or target == owner or w.diplomacy.defeated(target): return "Choose a nation"
			if not w.diplomacy.at_war(owner, target) and w.diplomacy.rel(owner, target) > -40.0: return "Only against an enemy (at war, or -40 relations or worse)"
			if insurgency_targets(w, target).is_empty(): return "No buildings to strike there"
	return ""
static func effect(w: Node, kind: String, owner: int, value: float, duration: float, by := -1) -> Dictionary:
	var e := {"kind": kind, "nation": owner, "by": owner if by < 0 else by, "value": value, "until": w.game_time + duration}
	w.power_effects.append(e)
	return e
static func bonus(w: Node, owner: int, kind: String) -> float:
	var value: float = Regional.bonus(w, owner, kind)
	for e in w.power_effects:
		if e.kind == "extra_" + kind and int(e.nation) == owner and float(e.until) > w.game_time:
			if e.has("ally") and (w.diplomacy.defeated(int(e.by)) or w.diplomacy.defeated(int(e.ally)) or not w.diplomacy.allied(int(e.by), int(e.ally))): continue
			value = maxf(value, float(e.value))
	return value
static func use_food_diplomacy(w: Node, owner: int, target: int) -> void:
	var e := effect(w, "extra_food_aid", target, 150, 86400, owner)
	e.eta = 30.0 * (1.0 - bonus(w, owner, "voyage"))

## The capital of `owner` (its HQ), or null.
static func capital(w: Node, owner: int):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead: return b
	return null

## United Kingdom: the London market stops insuring the rival's cargo.
static func use_insurance_ban(w: Node, owner: int, target: int) -> void:
	effect(w, "sea_ban", target, 1.0, 150, owner)
	effect(w, "income", target, 0.85, 150, owner)
	w.diplomacy.change(owner, target, -12.0)

## South Korea: tanks and howitzers for a partner, on export credit.
static func use_arms_export(w: Node, owner: int, target: int) -> void:
	var hq = capital(w, target)
	if hq != null:
		for i in range(3):
			var at: Vector3 = w.land_point(hq.root.position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 3.0 + 0.4) * 20.0, 12.0)
			var u: Dictionary = w.spawn_unit("artillery" if i == 2 else "tank", at, target)
			u.exported_by = owner
	if owner == 0: w.economy.res.money += 900.0
	else: nation(w, owner).money += 900.0
	w.diplomacy.change(owner, target, 15.0)

## Saudi Arabia: the cartel cuts output; oil is dear and Riyadh earns more.
static func use_output_cut(w: Node, owner: int) -> void:
	effect(w, "oil_shock", owner, 0.35, 180)
	effect(w, "income", owner, 1.15, 180)
	for other in range(w.diplomacy.n):
		if other != owner and preload("res://scripts/national_arsenal.gd").identity(w, other) == "blue":
			w.diplomacy.change(owner, other, -8.0)

## How far an output cut lifts the price of `res` now (market.gd).
static func price_shock(w: Node, res: String) -> float:
	var up := 0.0
	if res == "oil":
		for e in w.power_effects:
			if e.kind == "oil_shock" and float(e.until) > w.game_time: up = maxf(up, float(e.value))
	return up

## Indonesia: no nickel and no palm oil for a rival.
static func use_export_ban(w: Node, owner: int, target: int) -> void:
	effect(w, "production", target, 0.0, 45, owner)
	effect(w, "income", target, 0.9, 120, owner)
	w.diplomacy.change(owner, target, -10.0)

## Ukraine: what long-range drones go for first: refineries, power, factories.
static func strike_targets(w: Node, target: int) -> Array:
	var order := ["oilRefinery", "powerPlant", "nuclearReactor", "extractor", "tankFactory", "airfield", "ammoDepot"]
	var list: Array = w.buildings.filter(func(b): return b.owner == target and b.built and not b.dead and b.key != "hq")
	list.sort_custom(func(a, b): return (order.find(a.key) if a.key in order else 99) < (order.find(b.key) if b.key in order else 99))
	return list.slice(0, 2)

static func use_drone_strikes(w: Node, owner: int, target: int) -> void:
	for b in strike_targets(w, target):
		w.damage(b, b.max_hp * 0.35, {"owner": owner, "key": "drone", "dead": true})
	effect(w, "income", target, 0.88, 120, owner)

## North Korea: state hackers empty a quarter of the rival's treasury.
static func use_crypto_heist(w: Node, owner: int, target: int) -> int:
	var take := minf(funds(w, target, "money") * 0.25, 900.0)
	if target == 0: w.economy.res.money -= take
	else: nation(w, target).money -= take
	if owner == 0: w.economy.res.money += take
	else: nation(w, owner).money += take
	if randf() < 0.5:
		w.diplomacy.change(owner, target, -15.0)   # traced
	return int(take)

## Egypt: priority through the canal for a friend; closed to an enemy.
static func use_suez(w: Node, owner: int, target: int) -> bool:
	if w.diplomacy.at_war(owner, target):
		effect(w, "sea_ban", target, 1.0, 120, owner)
		return false
	effect(w, "extra_voyage", target, 0.3, 120, owner)
	w.diplomacy.change(owner, target, 12.0)
	return true

## Australia: ore for a partner; money for Australia.
static func use_minerals_pact(w: Node, owner: int, target: int) -> void:
	for r in ["iron", "uranium"]:
		var cap: float = float(w.economy.caps.get(r, INF)) if target == 0 else 500.0
		stock(w, target)[r] = minf(cap, funds(w, target, r) + float(POWERS.australia.costs[r]))
	if owner == 0: w.economy.res.money += 700.0
	else: nation(w, owner).money += 700.0
	w.diplomacy.change(owner, target, 15.0)

## Pakistan: an attack on one is an attack on both.
static func use_defence_pact(w: Node, owner: int, target: int) -> void:
	w.diplomacy.set_flag(w.diplomacy.alliance, owner, target, true)
	w.diplomacy.change(owner, target, 10.0)
## Iraq: four riflemen and two rocket teams at the capital; Washington frowns, Tehran smiles.
static func use_popular_mobilization(w: Node, owner: int) -> void:
	var capital = null
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead: capital = b
	if capital == null: return
	for i in range(6):
		var at: Vector3 = w.land_point(capital.root.position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 6.0) * 16.0, 10.0)
		var u: Dictionary = w.spawn_unit("rocketSoldier" if i % 3 == 2 else "soldier", at, owner)
		u.militia = true
	for other in range(w.diplomacy.n):
		match preload("res://scripts/national_arsenal.gd").identity(w, other):
			"blue": w.diplomacy.change(owner, other, -6.0)
			"gold": w.diplomacy.change(owner, other, 4.0)

## Syria: the nations at +20 relations or better (four at most).
static func partners(w: Node, owner: int) -> Array:
	var out := []
	for other in range(w.diplomacy.n):
		if other != owner and not w.diplomacy.defeated(other) and not w.diplomacy.at_war(owner, other) and w.diplomacy.rel(owner, other) >= 20.0:
			out.append(other)
	return out.slice(0, 4)

static func use_reconstruction_aid(w: Node, owner: int) -> int:
	var paid := 250.0 * partners(w, owner).size()
	# Pledges take time to arrive (step() pays them).
	var pledge := effect(w, "extra_aid", owner, paid, 86400)
	pledge.eta = 30.0
	for b in repairs(w, owner):
		var e := effect(w, "extra_repair", owner, minf(b.max_hp * 0.2, b.max_hp - b.hp), 60)
		if not b.has("reconstruction_tag"): b.reconstruction_tag = str(Time.get_ticks_usec()) + ":" + str(b.root.get_instance_id())
		e.tag = b.reconstruction_tag
		e.x = b.root.position.x
		e.z = b.root.position.z
		e.key = b.key
		e.last = w.game_time
		e.rate = float(e.value) / 60.0
	return int(paid)

## Afghanistan: the target's standing buildings, its capital spared.
static func insurgency_targets(w: Node, target: int) -> Array:
	return w.buildings.filter(func(b): return b.owner == target and b.built and not b.dead and b.key != "hq")

static func use_insurgent_attacks(w: Node, owner: int, target: int) -> void:
	var list := insurgency_targets(w, target)
	list.shuffle()
	for b in list.slice(0, 3):
		w.damage(b, b.max_hp * 0.3, {"owner": owner, "key": "insurgents", "covert": true})
	var e := effect(w, "income", target, 0.85, 90, owner)
	e.erase("ally")
	for other in range(w.diplomacy.n):
		if other != owner and not w.diplomacy.defeated(other):
			w.diplomacy.change(owner, other, -15.0 if other == target else -5.0)

static func use(w: Node, owner: int, target: int) -> String:
	var id := F.id_of(w, owner)
	if Regional.POWERS.has(id): return Regional.use(w, owner, target)
	if not pay(w, owner, POWERS[id].costs): return "Insufficient resources"
	var me: String = w.diplomacy.name_of(owner)
	var who: String = w.diplomacy.name_of(target) if target >= 0 else ""
	match id:
		"uk":
			use_insurance_ban(w, owner, target)
			return "%s: the London market stops insuring %s's cargo. Its sea trade stops and its income falls." % [me, who]
		"south_korea":
			use_arms_export(w, owner, target)
			return "%s sells tanks and howitzers to %s on export credit: $900 earned." % [me, who]
		"saudi":
			use_output_cut(w, owner)
			return "%s leads an OPEC+ output cut: the price of oil climbs." % me
		"brazil": use_food_diplomacy(w, owner, target)
		"indonesia":
			use_export_ban(w, owner, target)
			return "%s bans nickel and palm oil exports to %s: its factories stand still." % [me, who]
		"ukraine":
			use_drone_strikes(w, owner, target)
			return "%s's long-range drones strike refineries and plants deep in %s." % [me, who]
		"north_korea":
			return "Hackers emptied $%d from %s's treasury." % [use_crypto_heist(w, owner, target), who]
		"egypt":
			return ("%s grants %s priority through the Suez Canal." if use_suez(w, owner, target) else "%s closes the Suez Canal to %s.") % [me, who]
		"australia":
			use_minerals_pact(w, owner, target)
			return "%s signs a critical minerals pact with %s: ore delivered, $700 earned." % [me, who]
		"pakistan":
			use_defence_pact(w, owner, target)
			return "%s and %s sign a mutual defence pact: an attack on one is an attack on both." % [me, who]
		"iraq": use_popular_mobilization(w, owner)
		"syria": return "%s secured $%d in reconstruction pledges, arriving in 30 seconds." % [w.diplomacy.name_of(owner), use_reconstruction_aid(w, owner)]
		"afghanistan": use_insurgent_attacks(w, owner, target)
	return "%s activated %s." % [w.diplomacy.name_of(owner), POWERS[id].name]
## A closed strait, an insurance ban or a closed canal (on this nation).
static func sea_closed(w: Node, owner: int) -> bool:
	return w.power_effects.any(func(e): return float(e.until) > w.game_time and ((e.kind == "hormuz" and int(e.by) != owner) or (e.kind == "sea_ban" and int(e.nation) == owner)))
static func step(w: Node, delta: float) -> void:
	Regional.step(w)
	for e in w.power_effects:
		if not str(e.kind).begins_with("extra_"): continue
		if w.diplomacy.defeated(int(e.nation)) or w.diplomacy.defeated(int(e.by)):
			e.until = 0.0
			continue
		if e.has("ally") and not w.diplomacy.allied(int(e.by), int(e.ally)):
			e.until = 0.0
			continue
		if e.kind == "extra_repair":
			var elapsed := maxf(0.0, minf(w.game_time, float(e.until)) - float(e.last))
			e.last = w.game_time
			var found := false
			for b in w.buildings:
				if b.owner == int(e.nation) and b.key == e.key and b.get("reconstruction_tag", "") == e.get("tag", "") and not b.dead and absf(b.root.position.x - float(e.x)) < 0.1 and absf(b.root.position.z - float(e.z)) < 0.1:
					found = true
					var amount := minf(float(e.value), float(e.rate) * elapsed)
					b.hp = minf(b.max_hp, b.hp + amount)
					e.value = maxf(0.0, float(e.value) - amount)
					break
			if not found: e.until = 0.0
		if e.kind == "extra_aid" and float(e.until) > w.game_time:
			e.eta = float(e.eta) - delta
			if e.eta <= 0.0:
				e.until = 0.0
				if int(e.nation) == 0: w.economy.res.money += float(e.value)
				else: nation(w, int(e.nation)).money += float(e.value)
				_notice(w, int(e.nation), -1, "Reconstruction aid arrived: $%d." % int(e.value))
			continue
		if e.kind != "extra_food_aid" or float(e.until) <= w.game_time: continue
		var source := int(e.by)
		var target := int(e.nation)
		if w.diplomacy.at_war(source, target) or not w.diplomacy.pact[source][target] or not owned(w, source, "port") or not owned(w, target, "port"):
			e.until = 0.0
			_notice(w, source, target, "Food aid lost: the trade route collapsed.")
			continue
		if sea_closed(w, source): continue
		e.eta = float(e.eta) - delta
		if e.eta > 0.0: continue
		e.until = 0.0
		var sabotage: bool = source == 0 and w.market.sabotaged > 0
		if sabotage: w.market.sabotaged -= 1
		var risk := clampf(0.08 - escorts(w, source) * 0.015, 0.015, 0.08) * (1.0 - bonus(w, source, "shipping"))
		if sabotage or randf() < risk:
			_notice(w, source, target, "Food aid lost at sea.")
			continue
		var cap: float = w.economy.caps.food if target == 0 else 500.0
		stock(w, target).food = minf(cap, funds(w, target, "food") + float(e.value))
		w.diplomacy.change(source, target, 18.0)
		_notice(w, source, target, "Food aid arrived: 150 food delivered, relations +18.")
static func _notice(w: Node, source: int, target: int, message: String) -> void:
	if w.hud != null and (source == 0 or target == 0): w.hud.notice(message)
## Whom a rival aims its lever at: a hostile one only at an enemy (at war, or
## at -30 or worse; one at war first), a friendly one at its closest partner.
static func ai_target(w: Node, owner: int) -> int:
	var id := F.id_of(w, owner)
	var power: Dictionary = POWERS.get(id, Regional.POWERS.get(id, {}))
	if not power.target: return -1
	var d: Node = w.diplomacy
	var best := -1
	var score := -INF
	for target in range(w.map.nations.size()):
		if target == owner or d.defeated(target) or blocked(w, owner, target) != "": continue
		var s: float
		if power.get("hostile", false):
			if not d.at_war(owner, target) and d.rel(owner, target) > -30.0: continue
			s = (1000.0 if d.at_war(owner, target) else 0.0) - d.rel(owner, target)
		else:
			s = d.rel(owner, target)
		if s > score:
			score = s
			best = target
	return best
## New rival factions have a small saved civilian model, driven by their real stocks.
static func civic_income(w: Node, n: Dictionary, delta: float) -> float:
	if not F.IDS.has(F.id_of(w, int(n.id))): return 1.0
	var p := F.profile(w, int(n.id))
	var stats: Dictionary = p.get("bonus", {})
	var happy := clampf(60.0 + float(stats.get("happiness", 0.0)) + bonus(w, n.id, "happiness"), 0, 100)
	var health := clampf(55.0 + float(stats.get("health", 0.0)) + bonus(w, n.id, "health"), 0, 100)
	var citizens := float(n.get("civilians", 120.0))
	var cap := 200.0
	for b in w.buildings:
		if b.owner == n.id and b.built and not b.dead: cap += float(b.def.get("provides", {}).get("civCap", 0.0))
	cap *= 1.0 + float(stats.get("civCapPct", 0.0))
	var growth := citizens * (happy - 45.0) / 50.0 * health / 100.0 * 0.0025 * float(p.get("growth", 1.0))
	if funds(w, n.id, "food") < 0.5: growth -= citizens * 0.005
	n.civilians = clampf(citizens + growth * delta, 20.0, cap)
	n.happiness = happy
	n.health = health
	return clampf(float(n.civilians) / 120.0, 0.5, 1.5)
