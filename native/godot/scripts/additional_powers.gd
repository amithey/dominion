extends RefCounted
## All state uses world.power_effects / power_ready and is included by the existing save service.
const F := preload("res://scripts/additional_factions.gd")
const POWERS := {
	"uk": {"name": "Trade Shield", "target": false, "cooldown": 300.0, "duration": 90.0, "costs": {"money": 500}, "needs": ["port"], "desc": "$500: halve random sea-cargo losses for 90s. Requires a supplied port and armed warship. Does not stop sabotage, war or a closed strait."},
	"south_korea": {"name": "Industrial Mobilization", "target": false, "cooldown": 300.0, "duration": 90.0, "costs": {"money": 600, "silicon": 50}, "needs": ["tankFactory", "powerPlant"], "desc": "$600 + 50 silicon: military production +25% for 90s. Requires a supplied tank factory and power plant. Blockaded production remains stopped."},
	"saudi": {"name": "Vision Investment", "target": false, "cooldown": 420.0, "duration": 120.0, "costs": {"money": 1500}, "needs": ["bank", "techPark"], "desc": "$1,500: construction +25% and research +15% for 120s. Requires a supplied Bank and Tech Park."},
	"brazil": {"name": "Food Diplomacy", "target": true, "cooldown": 300.0, "duration": 0.0, "costs": {"food": 150}, "needs": ["port"], "desc": "Send 150 food to a trade partner with a supplied port. After a 30s sea voyage: +18 relations and food delivered. War, lost ports or sabotage can destroy the shipment; a closed strait delays it."},
	"indonesia": {"name": "National Nutrition", "target": false, "cooldown": 300.0, "duration": 120.0, "costs": {"food": 150}, "needs": ["farm", "school"], "desc": "150 food: +8 health and +5 happiness for 120s. Requires a supplied farm and school. Keep enough food to feed your people."},
	"ukraine": {"name": "Emergency Reconstruction", "target": false, "cooldown": 300.0, "duration": 60.0, "costs": {"money": 500, "iron": 60}, "needs": [], "desc": "$500 + 60 iron: repair up to 25% max health over 60s on five damaged buildings near your selected settlement (capital by default). Destroyed or captured buildings cannot be restored."},
	"north_korea": {"name": "Artillery Readiness", "target": false, "cooldown": 360.0, "duration": 45.0, "costs": {"money": 400, "iron": 40}, "needs": ["tankFactory"], "desc": "$400 + 40 iron: artillery reloads 25% faster for 45s, but income falls 20% for 90s. Requires supplied tank factory and artillery."},
	"egypt": {"name": "Logistics Hub", "target": false, "cooldown": 360.0, "duration": 120.0, "costs": {"money": 600}, "needs": ["port"], "desc": "$600: trade shipments departing during the next 120s have 30% shorter journeys. Requires a supplied port; routes still need trading partners."},
	"australia": {"name": "Mining Boom", "target": false, "cooldown": 360.0, "duration": 90.0, "costs": {"money": 700}, "needs": [], "desc": "$700: supplied extractors produce 40% more for 90s. Requires an active extractor; normal storage caps and resource deposits apply."},
	"pakistan": {"name": "Defence Partnership", "target": true, "cooldown": 360.0, "duration": 120.0, "costs": {"money": 600, "silicon": 40}, "needs": [], "desc": "$600 + 40 silicon: you and one ally gain +15% research for 120s. Ends when the alliance breaks. Multiple partnerships do not stack."}
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
	var p: Dictionary = POWERS[id]
	for key in p.needs:
		if not owned(w, owner, key): return "Needs supplied " + str(w.building_defs.get(key, {}).get("name", key))
	for r in p.costs:
		if funds(w, owner, r) < float(p.costs[r]): return "Needs %d %s" % [int(p.costs[r]), r]
	match id:
		"uk":
			if escorts(w, owner) == 0: return "Needs an active armed warship"
		"brazil":
			if w.diplomacy.at_war(owner, target) or not w.diplomacy.pact[owner][target]: return "Needs a trade partner at peace"
			if not owned(w, target, "port"): return "Partner needs a supplied port"
		"ukraine":
			if repairs(w, owner).is_empty(): return "No damaged buildings near the selected settlement or capital"
		"north_korea":
			if not w.units.any(func(u): return u.owner == owner and not u.dead and F.base(u.key) in ["artillery", "mlrs", "himars"]): return "Needs artillery"
		"australia":
			if not w.buildings.any(func(b): return b.owner == owner and b.built and not b.dead and b.get("supplied", true) and not w.disabled(b) and b.deposit != null): return "Needs an active supplied extractor"
		"pakistan":
			if not w.diplomacy.allied(owner, target) or w.diplomacy.at_war(owner, target): return "Needs an ally at peace"
	return ""
static func effect(w: Node, kind: String, owner: int, value: float, duration: float, by := -1) -> Dictionary:
	var e := {"kind": kind, "nation": owner, "by": owner if by < 0 else by, "value": value, "until": w.game_time + duration}
	w.power_effects.append(e)
	return e
static func bonus(w: Node, owner: int, kind: String) -> float:
	var value := 0.0
	for e in w.power_effects:
		if e.kind == "extra_" + kind and int(e.nation) == owner and float(e.until) > w.game_time:
			if e.has("ally") and (w.diplomacy.defeated(int(e.by)) or w.diplomacy.defeated(int(e.ally)) or not w.diplomacy.allied(int(e.by), int(e.ally))): continue
			value = maxf(value, float(e.value))
	return value
static func use_trade_shield(w: Node, owner: int) -> void:
	effect(w, "extra_shipping", owner, 0.5, 90)
static func use_industrial_mobilization(w: Node, owner: int) -> void:
	effect(w, "extra_prodPct", owner, 0.25, 90)
static func use_vision_investment(w: Node, owner: int) -> void:
	effect(w, "extra_buildPct", owner, 0.25, 120)
	effect(w, "extra_researchPct", owner, 0.15, 120)
static func use_food_diplomacy(w: Node, owner: int, target: int) -> void:
	var e := effect(w, "extra_food_aid", target, 150, 86400, owner)
	e.eta = 30.0 * (1.0 - bonus(w, owner, "voyage"))
static func use_nutrition_program(w: Node, owner: int) -> void:
	effect(w, "extra_health", owner, 8, 120)
	effect(w, "extra_happiness", owner, 5, 120)
static func use_reconstruction(w: Node, owner: int) -> void:
	for b in repairs(w, owner):
		var e := effect(w, "extra_repair", owner, minf(b.max_hp * 0.25, b.max_hp - b.hp), 60)
		if not b.has("reconstruction_tag"): b.reconstruction_tag = str(Time.get_ticks_usec()) + ":" + str(b.root.get_instance_id())
		e.tag = b.reconstruction_tag
		e.x = b.root.position.x
		e.z = b.root.position.z
		e.key = b.key
		e.last = w.game_time
		e.rate = float(e.value) / 60.0
static func use_artillery_readiness(w: Node, owner: int) -> void:
	effect(w, "extra_reload", owner, 0.25, 45)
	effect(w, "income", owner, 0.8, 90)
static func use_logistics_hub(w: Node, owner: int) -> void:
	effect(w, "extra_voyage", owner, 0.3, 120)
static func use_mining_boom(w: Node, owner: int) -> void:
	effect(w, "extra_mining", owner, 0.4, 90)
static func use_defence_partnership(w: Node, owner: int, target: int) -> void:
	for recipient in [owner, target]:
		var e := effect(w, "extra_researchPct", recipient, 0.15, 120, owner)
		e.ally = target
static func use(w: Node, owner: int, target: int) -> String:
	var id := F.id_of(w, owner)
	if not pay(w, owner, POWERS[id].costs): return "Insufficient resources"
	match id:
		"uk": use_trade_shield(w, owner)
		"south_korea": use_industrial_mobilization(w, owner)
		"saudi": use_vision_investment(w, owner)
		"brazil": use_food_diplomacy(w, owner, target)
		"indonesia": use_nutrition_program(w, owner)
		"ukraine": use_reconstruction(w, owner)
		"north_korea": use_artillery_readiness(w, owner)
		"egypt": use_logistics_hub(w, owner)
		"australia": use_mining_boom(w, owner)
		"pakistan": use_defence_partnership(w, owner, target)
	return "%s activated %s." % [w.diplomacy.name_of(owner), POWERS[id].name]
static func sea_closed(w: Node, owner: int) -> bool:
	return w.power_effects.any(func(e): return e.kind == "hormuz" and int(e.by) != owner and float(e.until) > w.game_time)
static func step(w: Node, delta: float) -> void:
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
static func ai_target(w: Node, owner: int) -> int:
	var id := F.id_of(w, owner)
	if not POWERS[id].target: return -1
	for target in range(w.map.nations.size()):
		if target != owner and not w.diplomacy.defeated(target) and blocked(w, owner, target) == "": return target
	return -1
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
