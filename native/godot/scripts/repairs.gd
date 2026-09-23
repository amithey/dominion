extends RefCounted
static func request(w: Node, entities: Array) -> void:
	var count := 0
	for e in entities:
		if e.owner==0 and not e.dead and e.hp<e.max_hp and (e.get("is_building",false) or e.vehicle):
			e.repairing = true
			count += 1
	w.hud.notice("Repair ordered for %d assets. $0.25 per HP; pauses while moving or under attack." % count)
static func update(w: Node, delta: float) -> void:
	for e in w.units+w.buildings:
		if not e.get("repairing",false) or e.dead:
			continue
		if e.hp>=e.max_hp:
			e.repairing = false
			continue
		if e.get("moving",false) or e.get("enemy")!=null or w.game_time-e.get("last_hit",-100.0)<6 or not e.get("supplied",true) or w.disabled(e):
			continue
		var amount := minf(e.max_hp-e.hp,e.max_hp*0.025*delta)
		if w.economy.pay({"money":amount*0.25}):
			e.hp += amount
