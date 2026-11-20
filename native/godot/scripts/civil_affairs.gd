extends RefCounted
## Civil agreements are settled from actual food stocks and both national treasuries.
const Powers := preload("res://scripts/additional_powers.gd")
const LOCAL_COST := {"Housing": {"money": 400, "iron": 20}, "Harbour": {"money": 550, "iron": 30}}
const JOINT_COST := {"University": {"money": 500, "iron": 10}, "Power grid": {"money": 450, "iron": 35}}
const HOME_FLOOR := 60
const LOT_PERIOD := 40.0
var w: Node
var contract := {}
var rival_contracts := []
var projects := {}
var reserve := 0.0
var honoured := {}
var last_report := ""

func _init(world: Node) -> void:
	w = world

func report(message: String) -> String:
	last_report = message
	w.hud.notice(message)
	return message

func partner_open(id: int) -> bool:
	return id > 0 and _peaceful(0, id)

func _peaceful(seller: int, buyer: int) -> bool:
	var d: Node = w.diplomacy
	return seller != buyer and seller >= 0 and buyer >= 0 and seller < d.n and buyer < d.n and not d.defeated(seller) and not d.defeated(buyer) and not d.at_war(seller, buyer)

func votes(id: int, lot: int, guarantee: bool, seller := 0) -> Array:
	return _votes(seller, id if seller == 0 else 0, lot, guarantee)

func _votes(seller: int, buyer: int, lot: int, guarantee: bool) -> Array:
	var supporters := []
	if Powers.owned(w, seller, "farm"): supporters.append("Growers")
	if _peaceful(seller, buyer) and w.diplomacy.pact[seller][buyer]: supporters.append("Merchants")
	if guarantee or Powers.funds(w, seller, "food") >= HOME_FLOOR + 3 * lot: supporters.append("Households")
	return supporters

func active_contract(owner: int) -> Dictionary:
	if not contract.is_empty() and (owner == 0 or int(contract.partner) == owner): return contract
	for deal in rival_contracts:
		if int(deal.seller) == owner or int(deal.buyer) == owner: return deal
	return {}

func export_floor(owner := 0) -> float:
	var deal := active_contract(owner)
	return HOME_FLOOR if deal.get("guarantee", false) and int(deal.get("seller", 0)) == owner else 0.0

func _credit(owner: int, amount: int) -> void:
	if owner == 0: w.economy.res.money += amount
	else: w.market.ai_nation(owner).money += amount

func _food_fits(owner: int, lot: int) -> bool:
	var capacity := float(w.economy.caps.food) if owner == 0 else 500.0
	return Powers.funds(w, owner, "food") + lot <= capacity

func price_per_lot(id: int, lot: int, seller := 0) -> int:
	return _price(seller, id if seller == 0 else 0, lot)

func _reputation_key(seller: int, buyer: int) -> String:
	if seller == 0: return str(buyer)
	if buyer == 0: return "import-" + str(seller)
	return "%d>%d" % [seller, buyer]

func _price(seller: int, buyer: int, lot: int) -> int:
	var reputation := mini(4, int(honoured.get(_reputation_key(seller, buyer), 0)))
	return ceili(lot * w.market.price("food") * (1.20 + 0.05 * reputation))

func sign(id: int, lot: int, guarantee: bool, importing := false) -> String:
	if importing and (not has_offer(id, "Food") or lot != 20 or not guarantee): return "This protected food offer is unavailable."
	return _ratify(id if importing else 0, 0 if importing else id, lot, guarantee)

func _ratify(seller: int, buyer: int, lot: int, guarantee: bool) -> String:
	if lot not in [20, 40] or not _peaceful(seller, buyer): return "A peaceful partner is required."
	if not active_contract(seller).is_empty() or not active_contract(buyer).is_empty(): return "A partner already has an active food contract."
	if w.un != null and w.un.trade_blocked(seller, buyer, "food"): return "Food trade is restricted."
	if _votes(seller, buyer, lot, guarantee).size() < 2: return "Parliament requires two of the three caucuses."
	if Powers.funds(w, seller, "food") < lot + (HOME_FLOOR if guarantee else 0): return "Not enough food to pledge the first shipment."
	if not _food_fits(buyer, lot): return "The buyer has no room for the first shipment."
	var payment := _price(seller, buyer, lot)
	if not Powers.pay(w, buyer, {"money": 3 * payment}): return "The buyer cannot fund all three shipments."
	var deal := {"seller": seller, "buyer": buyer, "lot": lot, "payment": payment, "guarantee": guarantee, "sent": 0,
		"next": w.game_time, "deadline": w.game_time + 3 * LOT_PERIOD + 20, "extended": false}
	if seller == 0 or buyer == 0:
		deal.partner = buyer if seller == 0 else seller
		contract = deal
	else:
		rival_contracts.append(deal)
	if seller != 0 and w.market.ai_nation(seller).get("civic_offer") == "Food": w.market.ai_nation(seller).erase("civic_offer")
	_ship(deal)
	return report("Food contract ratified. First shipment delivered against the advance.") if deal.has("partner") else ""

func _ship(deal: Dictionary) -> void:
	Powers.stock(w, int(deal.seller)).food -= int(deal.lot)
	_credit(int(deal.seller), int(deal.payment))
	_deliver_food(int(deal.buyer), int(deal.lot))
	deal.sent += 1
	deal.next += LOT_PERIOD

func extend_deadline() -> String:
	return _extend(contract)

func _extend(deal: Dictionary) -> String:
	if deal.is_empty() or deal.extended: return "Only one extension is available."
	if w.game_time > float(deal.deadline): return "The deadline has passed."
	var seller := int(deal.seller)
	var buyer := int(deal.buyer)
	if seller != 0 and not deal.get("extension_requested", false): return "The seller has not requested an extension."
	if not _peaceful(seller, buyer) or w.diplomacy.rel(seller, buyer) < 20: return "An extension requires relations of +20."
	deal.deadline += 60
	deal.extended = true
	w.diplomacy.change(seller, buyer, -3)
	return report("Deadline extended by 60 seconds. Relations fell by 3.") if deal.has("partner") else ""

func tick() -> void:
	if not contract.is_empty() and _settled(contract): contract.clear()
	for i in range(rival_contracts.size() - 1, -1, -1):
		if _settled(rival_contracts[i]): rival_contracts.remove_at(i)

func _settled(deal: Dictionary) -> bool:
	var seller := int(deal.seller)
	var buyer := int(deal.buyer)
	var lot := int(deal.lot)
	if not _peaceful(seller, buyer) or w.game_time > float(deal.deadline):
		_credit(buyer, (3 - int(deal.sent)) * int(deal.payment))
		if not w.diplomacy.defeated(seller) and not w.diplomacy.defeated(buyer): w.diplomacy.change(seller, buyer, -8)
		if deal.has("partner"): report("Food contract ended early. Unpaid instalments returned to the buyer.")
		return true
	if w.game_time < float(deal.next) or (w.un != null and w.un.trade_blocked(seller, buyer, "food")): return false
	if Powers.funds(w, seller, "food") < lot + (HOME_FLOOR if deal.guarantee else 0) or not _food_fits(buyer, lot):
		if seller != 0 and not deal.extended and w.game_time >= float(deal.deadline) - LOT_PERIOD and w.diplomacy.rel(seller, buyer) >= 20:
			deal.extension_requested = true
			if buyer != 0: _extend(deal)
		return false
	_ship(deal)
	if int(deal.sent) < 3: return false
	var key := _reputation_key(seller, buyer)
	honoured[key] = int(honoured.get(key, 0)) + 1
	w.diplomacy.change(seller, buyer, 8)
	if deal.has("partner"): report("Food contract completed. Relations improved and the partner offers better terms.")
	return true

func _deliver_food(id: int, amount: int) -> void:
	var stock := Powers.stock(w, id)
	stock.food = float(stock.get("food", 0)) + amount

func store_food() -> String:
	var amount := minf(20, 120 - reserve)
	if amount <= 0 or w.economy.res.food < amount + export_floor(): return "Insufficient available food or no room in the reserve."
	reserve += amount
	w.economy.res.food -= amount
	return "Food moved to the emergency reserve."

func release_food(maximum: float) -> float:
	var amount := maxf(0, minf(maximum, minf(reserve, w.economy.caps.food - w.economy.res.food)))
	reserve -= amount
	w.economy.res.food += amount
	return amount

func improve(town: Dictionary, kind: String, owner := 0) -> String:
	if not LOCAL_COST.has(kind) or town.dead or not town.built or town.owner != owner or town.def.get("settlement") == null or not town.get("supplied", true): return "Choose a supplied town hall."
	if town.has("local_improvement"): return "This town has already spent its development budget."
	if kind == "Harbour" and not preload("res://scripts/national_variants.gd").builds(w, owner, "port"): return "This nation does not operate sea ports."
	if kind == "Harbour" and not w.coast_near(town.root.position, w.logistics.radius * 2.6): return "The harbour needs a coastal town."
	var paid: bool = w.economy.pay(LOCAL_COST[kind]) if owner == 0 else Powers.pay(w, owner, LOCAL_COST[kind])
	if not paid: return "Insufficient money or iron."
	apply_improvement(town, kind)
	if owner != 0: return "Local investment completed."
	w.economy.recalculate()
	return report("%s development completed at %s." % [kind, town.def.name])

func apply_improvement(town: Dictionary, kind: String) -> void:
	if not LOCAL_COST.has(kind) or town.has("local_improvement"): return
	town.local_improvement = kind
	town.def = town.def.duplicate(true)
	if kind == "Harbour": town.def.provides.harbour = 1
	if kind == "Housing": town.def.provides.civCap = float(town.def.provides.get("civCap", 0)) + 80

func rail_quote(id: int) -> Dictionary:
	var a = w.ai.hq(0)
	var b = w.ai.hq(id)
	if a == null or b == null: return {}
	var route: Array = w.logistics.plan(w.logistics.world_hex(a.root.position), w.logistics.world_hex(b.root.position), 0, "rail")
	if route.size() < 2: return {}
	var quote: Dictionary = w.logistics.quote(route, "rail", 0)
	quote.route = route
	return quote

func commission(id: int, kind: String, agreed: Dictionary = {}) -> String:
	if not partner_open(id) or not w.diplomacy.pact[0][id] or w.diplomacy.rel(0, id) < 20: return "A trade partner at peace and relations of at least +20 are required."
	var buyer = w.market.ai_nation(id)
	if kind == "Railway":
		var quote := rail_quote(id)
		if quote.is_empty(): return "No land corridor between these capitals."
		if quote.money <= 0: return "The rail corridor is already complete."
		if agreed.is_empty() or quote.money > agreed.money or quote.iron > agreed.iron: return "Survey the rail corridor again to confirm its cost."
		var route: Array = quote.route
		var share := floori(quote.money * 0.5)
		if buyer.money < share or w.economy.res.money < quote.money - share or w.economy.res.iron < quote.iron: return "Rail requires $%d and %d iron from you and $%d from the partner." % [quote.money - share, quote.iron, share]
		buyer.money -= share
		w.economy.res.money += share
		if not w.logistics.build(route, "rail", 0):
			buyer.money += share
			w.economy.res.money -= share
			return "Rail construction could not begin."
	else:
		if not JOINT_COST.has(kind): return "Unknown project."
		var key := str(id)
		if kind in projects.get(key, []): return "Already commissioned with this partner."
		var cost: Dictionary = JOINT_COST[kind]
		if buyer.money < cost.money or not w.economy.pay(cost): return "Both treasuries must cover their share and you must provide the iron."
		buyer.money -= cost.money
		projects.get_or_add(key, []).append(kind)
	w.diplomacy.change(0, id, 4)
	return report("Joint %s commissioned with %s." % [kind.to_lower(), w.diplomacy.name_of(id)])

func partnerships(owner: int, kind: String) -> int:
	var count := 0
	for key in projects:
		var id := int(key)
		if (owner == 0 or owner == id) and kind in projects[key] and partner_open(id) and w.diplomacy.pact[0][id]: count += 1
	return count

func has_offer(id: int, kind: String) -> bool:
	if not partner_open(id) or (kind == "Food" and not active_contract(id).is_empty()): return false
	return w.market.ai_nation(id).get("civic_offer", "") == kind

func rival_budget(n: Dictionary, stock: Dictionary) -> void:
	var id := int(n.id)
	var available := float(n.money)
	var planned := str(n.get("planned_building", ""))
	if w.building_defs.has(planned):
		var definition: Dictionary = w.building_defs[planned]
		var cost := preload("res://scripts/additional_factions.gd").building_cost(w, id, planned, definition.get("base_cost", definition.cost))
		available -= w.ai.weighted_cost(cost)
	var hunger := float(stock.get("food", 100)) < 65
	n.tax_policy = "Relief" if available > 1500 and n.get("happiness", 60) < 55 else ("Levy" if n.money < 250 else "Standard")
	var programme := str(n.get("civil_programme", ""))
	if w.game_time >= float(n.get("programme_until", 0)):
		programme = ""
		n.civil_programme = ""
	if programme == "" and available > 1500:
		var winter := fmod(w.game_time, 720) >= 540
		if winter and float(stock.get("gas", 100)) < 80: programme = "Home insulation"
		elif hunger and Powers.owned(w, id, "farm"): programme = "Farm grants"
		elif n.get("health", 55) < 65: programme = "Public clinics"
		if programme != "" and Powers.pay(w, id, {"money": w.economy.CIVIL_PROGRAMMES[programme].cost}):
			available -= float(w.economy.CIVIL_PROGRAMMES[programme].cost)
			n.civil_programme = programme
			n.programme_until = w.game_time + w.economy.PROGRAMME_TERM
	var grain := float(stock.get("food", 100))
	var stored := float(n.get("grain_reserve", 0))
	if grain > 160 and stored < 120:
		var amount := minf(20, 120 - stored)
		n.grain_reserve = stored + amount
		stock.food = grain - amount
	if w.game_time < float(n.get("next_civic_decision", 120)): return
	n.next_civic_decision = w.game_time + 90 + id
	if available > 2000:
		var can_harbour: bool = preload("res://scripts/national_variants.gd").builds(w, id, "port")
		for town in w.buildings:
			if town.owner != id or town.dead or not town.built or town.def.get("settlement") == null or town.has("local_improvement") or not town.get("supplied", true): continue
			var coastal: bool = can_harbour and w.coast_near(town.root.position, w.logistics.radius * 2.6)
			improve(town, "Harbour" if coastal else "Housing", id)
			break
	n.erase("civic_offer")
	if stock.get("food", 0) >= HOME_FLOOR + 60 and active_contract(id).is_empty():
		for other in w.ai.nations:
			var buyer := int(other.id)
			if not _peaceful(id, buyer) or not active_contract(buyer).is_empty(): continue
			if float(Powers.stock(w, buyer).get("food", 100)) >= 65: continue
			if _ratify(id, buyer, 20, true).is_empty(): break
	if not partner_open(id): return
	if contract.is_empty() and active_contract(id).is_empty() and stock.get("food", 0) >= HOME_FLOOR + 60 and w.economy.res.food < w.economy.caps.food * 0.6 and votes(id, 20, true, id).size() >= 2:
		n.civic_offer = "Food"
	elif w.diplomacy.pact[0][id] and w.diplomacy.rel(0, id) >= 20:
		for kind in ["Power grid", "University"]:
			if kind not in projects.get(str(id), []) and n.money >= JOINT_COST[kind].money:
				n.civic_offer = kind
				break

func capture() -> Dictionary:
	return {"contract": contract.duplicate(true), "rival_contracts": rival_contracts.duplicate(true), "projects": projects.duplicate(true), "reserve": reserve, "honoured": honoured.duplicate(), "report": last_report}

func _normalise_deal(deal: Dictionary) -> void:
	deal.seller = int(deal.get("seller", 0))
	if deal.has("partner"):
		deal.partner = int(deal.partner)
		deal.buyer = int(deal.partner) if deal.seller == 0 else 0
	else:
		deal.buyer = int(deal.get("buyer", 0))
	deal.lot = int(deal.get("lot", 20))
	deal.payment = int(deal.get("payment", 0))
	deal.sent = int(deal.get("sent", 0))

func restore(data: Dictionary) -> void:
	contract = data.get("contract", {}).duplicate(true)
	rival_contracts = data.get("rival_contracts", []).duplicate(true)
	if not contract.is_empty(): _normalise_deal(contract)
	for deal in rival_contracts: _normalise_deal(deal)
	projects = data.get("projects", {}).duplicate(true)
	honoured = data.get("honoured", {}).duplicate()
	reserve = clampf(float(data.get("reserve", 0)), 0, 120)
	last_report = str(data.get("report", ""))
