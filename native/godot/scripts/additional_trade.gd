extends RefCounted
## Rival UK/Egypt sea commerce: one paid cargo at a time, saved in the AI state.
## Player commerce remains under the player's control in the Market screen.
const P := preload("res://scripts/additional_powers.gd")
const F := preload("res://scripts/additional_factions.gd")
static func tick(w: Node, delta: float) -> void:
	if w.ai == null: return
	for seller in w.ai.nations:
		var owner := int(seller.id)
		var cargo: Dictionary = seller.get("national_cargo", {})
		if not cargo.is_empty():
			var target := int(cargo.target)
			if w.diplomacy.defeated(owner) or w.diplomacy.defeated(target) or w.diplomacy.at_war(owner, target) or not w.diplomacy.pact[owner][target] or not P.owned(w, owner, "port") or not P.owned(w, target, "port"):
				seller.erase("national_cargo")
				continue
			if P.sea_closed(w, owner): continue
			cargo.eta = float(cargo.eta) - delta / (1.0 + preload("res://scripts/regional_powers.gd").bonus(w, owner, "shippingPressure"))
			if cargo.eta > 0.0: continue
			seller.erase("national_cargo")
			var risk := clampf(0.08 - P.escorts(w, owner) * 0.015, 0.015, 0.08) * (1.0 - P.bonus(w, owner, "shipping"))
			if randf() < risk: continue
			seller.money += float(cargo.value)
			P.stock(w, target)[cargo.resource] = minf(500.0, P.funds(w, target, cargo.resource) + float(cargo.qty))
			w.diplomacy.change(owner, target, 0.8)
			continue
		if F.id_of(w, owner) not in ["uk", "egypt"] or w.diplomacy.defeated(owner) or not P.owned(w, owner, "port"): continue
		for buyer in w.ai.nations:
			var target := int(buyer.id)
			if target == owner or w.diplomacy.defeated(target) or w.diplomacy.at_war(owner, target) or not w.diplomacy.pact[owner][target] or not P.owned(w, target, "port"): continue
			for resource in w.market.cfg.price:
				var value: float = ceilf(30.0 * w.market.price(resource) * preload("res://scripts/national_profile.gd").trade_mult(w, owner))
				if P.funds(w, owner, resource) < 130.0 or P.funds(w, target, resource) > 470.0 or buyer.money < value + 150.0: continue
				P.stock(w, owner)[resource] -= 30.0
				buyer.money -= value
				seller.national_cargo = {"target": target, "resource": resource, "qty": 30.0, "value": value, "eta": float(w.market.cfg.voyage) * (1.0 - P.bonus(w, owner, "voyage"))}
				break
			if seller.has("national_cargo"): break
