extends RefCounted
## Escrow contracts and temporary effects live in the existing saved power state.
const POWERS := {
	"yemen": {"name": "Partner-Funded Reconstruction", "target": true, "hostile": false, "cooldown": 360.0, "duration": 30.0, "costs": {"money": 100}, "needs": ["school"], "desc": "$100 administration: a friendly partner pays $600 into escrow. After 30 seconds it funds reconstruction. Requires a supplied school and +20 relations. War or lost infrastructure refunds the partner; administration is spent."},
	"houthis": {"name": "Coastal Shipping Pressure", "target": true, "hostile": true, "cooldown": 360.0, "duration": 60.0, "costs": {"money": 250, "silicon": 40}, "needs": ["port"], "desc": "$250 + 40 silicon: a live coastal drone battery slows an enemy's shipping by up to 15% for 60 seconds. Each escort reduces pressure. Requires supplied ports on both sides and war; peace or a lost battery ends pressure."},
	"ethiopia": {"name": "Hydropower Export Contract", "target": true, "hostile": false, "cooldown": 360.0, "duration": 90.0, "costs": {"money": 100}, "needs": ["powerPlant"], "desc": "$100 connection: a friendly partner pays $450 for 90 seconds of grid access (+15% production). Revenue is released over time. War or lost power refunds the unused payment."},
	"nigeria": {"name": "Grid Stabilization", "target": false, "hostile": false, "cooldown": 300.0, "duration": 90.0, "costs": {"money": 350, "gas": 40}, "needs": ["powerPlant"], "desc": "$350 + 40 gas: stabilize a supplied power plant for 90 seconds, production +25%. Lost power ends the effect."},
	"sudan": {"name": "Restore Civil Infrastructure", "target": false, "hostile": false, "cooldown": 300.0, "duration": 60.0, "costs": {"money": 300, "iron": 40}, "needs": [], "desc": "$300 + 40 iron: repair up to five damaged buildings near the capital by 20% of their maximum health over 60 seconds. Requires damage to repair; destroyed or captured buildings receive nothing."},
	"south_sudan": {"name": "Oil Transit Agreement", "target": true, "hostile": false, "cooldown": 300.0, "duration": 30.0, "costs": {"oil": 100}, "needs": ["extractor"], "desc": "Sell 100 stocked oil to a friendly Sudan with a supplied extractor. Sudan pays $500 into escrow; on delivery you earn $400 and Sudan recovers $100 transit fees and receives the oil. War or lost extractors refunds both deposits. Needs +20 relations and room for the oil."}
}
static func blocked(w: Node, owner: int, target: int) -> String:
	var p = load("res://scripts/additional_powers.gd")
	var id: String = preload("res://scripts/factions.gd").identity(w, owner)
	var def: Dictionary = POWERS[id]
	for key in def.needs:
		if not p.owned(w, owner, key): return "Needs supplied " + str(w.building_defs[key].name)
	for r in def.costs:
		if p.funds(w, owner, r) < float(def.costs[r]): return "Needs %d %s" % [int(def.costs[r]), r]
	if def.target:
		if target < 0 or target == owner or target >= w.diplomacy.n or w.diplomacy.defeated(target): return "Choose a nation"
		if id == "houthis":
			if not w.diplomacy.at_war(owner, target): return "Requires war with the target"
			if not battery(w, owner): return "Needs a live coastal drone battery"
			if not p.owned(w, target, "port"): return "Target needs a supplied port"
		else:
			if w.diplomacy.at_war(owner, target) or w.diplomacy.rel(owner, target) < 20: return "Needs a partner at peace (+20 relations)"
			var payment: float = 600 if id == "yemen" else (450 if id == "ethiopia" else 500)
			if p.funds(w, target, "money") < payment: return "Partner cannot fund the agreement"
			if id == "south_sudan":
				if preload("res://scripts/factions.gd").identity(w, target) != "sudan": return "Requires Sudan as transit partner"
				if not p.owned(w, target, "extractor"): return "Sudan needs a supplied extractor"
				var cap: float = w.economy.caps.oil if target == 0 else 500.0
				if p.funds(w, target, "oil") + 100 > cap: return "Partner needs room for 100 oil"
	if id == "sudan" and p.repairs(w, owner).is_empty(): return "No damaged buildings near the capital"
	return ""
static func battery(w: Node, owner: int) -> bool:
	return w.units.any(func(u): return u.owner == owner and u.key == "coastalDrone" and not u.dead and not w.disabled(u))
static func credit(w: Node, owner: int, resource: String, amount: float) -> void:
	var p = load("res://scripts/additional_powers.gd")
	if resource == "money" and owner != 0:
		var n = p.nation(w, owner)
		if n != null: n.money += amount
	else:
		var cap: float = INF if resource == "money" else (float(w.economy.caps.get(resource, INF)) if owner == 0 else 500.0)
		p.stock(w, owner)[resource] = minf(cap, p.funds(w, owner, resource) + amount)
static func use(w: Node, owner: int, target: int) -> String:
	var p = load("res://scripts/additional_powers.gd")
	var id: String = preload("res://scripts/factions.gd").identity(w, owner)
	# Revalidate before either side is charged, including AI and direct calls.
	var why := blocked(w, owner, target)
	if why != "": return why
	if not p.pay(w, owner, POWERS[id].costs): return "Insufficient resources"
	if id == "sudan":
		for b in p.repairs(w, owner):
			var e: Dictionary = p.effect(w, "extra_repair", owner, minf(b.max_hp * 0.2, b.max_hp - b.hp), 60)
			if not b.has("reconstruction_tag"): b.reconstruction_tag = str(Time.get_ticks_usec()) + ":" + str(b.root.get_instance_id())
			e.merge({"tag": b.reconstruction_tag, "x": b.root.position.x, "z": b.root.position.z, "key": b.key, "last": w.game_time, "rate": float(e.value) / 60.0})
	else:
		var e: Dictionary = p.effect(w, "regional_" + id, owner, 0, float(POWERS[id].duration), owner)
		e.merge({"target": target, "last": w.game_time, "escrow": 0.0})
		if id in ["yemen", "ethiopia", "south_sudan"]:
			e.escrow = 600.0 if id == "yemen" else (450.0 if id == "ethiopia" else 500.0)
			p.pay(w, target, {"money": e.escrow})
	return "%s activated: %s." % [w.diplomacy.name_of(owner), POWERS[id].name]
static func valid(w: Node, e: Dictionary) -> bool:
	var p = load("res://scripts/additional_powers.gd")
	var owner := int(e.nation)
	var target := int(e.target)
	if w.diplomacy.defeated(owner): return false
	if target >= 0 and w.diplomacy.defeated(target): return false
	for key in POWERS[str(e.kind).trim_prefix("regional_")].needs:
		if not p.owned(w, owner, key): return false
	if e.kind == "regional_houthis": return w.diplomacy.at_war(owner, target) and battery(w, owner) and p.owned(w, target, "port")
	if target >= 0 and w.diplomacy.at_war(owner, target): return false
	if e.kind == "regional_south_sudan": return p.owned(w, target, "extractor")
	return true
static func bonus(w: Node, owner: int, kind: String) -> float:
	var value := 0.0
	for e in w.power_effects:
		if not str(e.kind).begins_with("regional_") or float(e.until) <= w.game_time or not valid(w, e): continue
		if kind == "prodPct":
			if e.kind == "regional_nigeria" and int(e.nation) == owner: value = maxf(value, 0.25)
			if e.kind == "regional_ethiopia" and int(e.target) == owner: value = maxf(value, 0.15)
		if kind == "shippingPressure" and e.kind == "regional_houthis" and int(e.target) == owner:
			value = maxf(value, maxf(0.0, 0.15 - load("res://scripts/additional_powers.gd").escorts(w, owner) * 0.03))
	return value
static func step(w: Node) -> void:
	for e in w.power_effects:
		if not str(e.kind).begins_with("regional_") or e.get("settled", false): continue
		var owner := int(e.nation)
		var target := int(e.target)
		if not valid(w, e):
			if float(e.escrow) > 0: credit(w, target, "money", float(e.escrow))
			if e.kind == "regional_south_sudan": credit(w, owner, "oil", 100)
			e.settled = true
			e.until = 0.0
			continue
		if e.kind == "regional_ethiopia":
			var elapsed := maxf(0, minf(w.game_time, float(e.until)) - float(e.last))
			var paid := minf(float(e.escrow), elapsed * 5.0)
			credit(w, owner, "money", paid)
			e.escrow -= paid
			e.last = minf(w.game_time, float(e.until))
		if w.game_time < float(e.until): continue
		if e.kind == "regional_yemen": credit(w, owner, "money", float(e.escrow))
		if e.kind == "regional_south_sudan":
			var p = load("res://scripts/additional_powers.gd")
			var cap: float = w.economy.caps.oil if target == 0 else 500.0
			if p.funds(w, target, "oil") + 100 <= cap:
				credit(w, target, "oil", 100)
				credit(w, owner, "money", 400)
				credit(w, target, "money", 100)
			else:
				credit(w, target, "money", float(e.escrow))
				credit(w, owner, "oil", 100)
		e.escrow = 0.0
		e.settled = true
