extends Node
## World market and overseas trade, ported from the trade engine in
## js/diplomacy.js. Prices come from config.js (TRADE_PRICE and friends,
## through the map export) and drift every 10 seconds between 55% and 190%.
## A Market allows instant deals (sell at 90%, buy at 115% of the price).
## A Commercial Port opens standing routes to nations the player has a trade
## pact with: each route loads a cargo, sails for 30 s and delivers it, or is
## lost at sea (8%, less with warships to escort). Two berths per port;
## contracts come from trade pacts and markets. Routes collapse on war, when
## the pact ends or when port capacity is lost; cargo at sea is then forfeited.

signal changed

const TICK := 10.0

var world: Node
var cfg: Dictionary
var mult := {}           # resource -> price multiplier
var routes: Array = []   # {id, nation, res, dir, qty, shipment, status, total}
var delivered := 0
var lost := 0
var _next_id := 1
var _tick := 0.0

func setup(world_node: Node, trade: Dictionary) -> void:
	world = world_node
	cfg = trade
	for key in cfg.price:
		mult[key] = 1.0

func resources() -> Array:
	return cfg.price.keys()

func price(res: String) -> float:
	return float(cfg.price[res]) * float(mult.get(res, 1.0))

func has_market() -> bool:
	return world.economy.owned("market") > 0

func ports() -> int:
	return world.economy.owned("port")

## Routes allowed: commercial contracts (pacts + up to two markets), limited by berths.
func route_cap() -> int:
	var d: Node = world.diplomacy
	var pacts := 0
	for i in range(1, d.n):
		if not d.defeated(i) and d.pact[0][i]:
			pacts += 1
	var contracts := pacts + mini(world.economy.owned("market"), 2)
	return maxi(0, mini(contracts, ports() * int(cfg.routesPerPort)))

## Armed warships at sea lower the chance of losing a cargo.
func risk() -> float:
	var escorts := 0
	for u in world.units:
		if u.owner == 0 and not u.dead and u.get("naval", false) and u.dmg > 0.0:
			escorts += 1
	return clampf(0.08 - escorts * 0.015, 0.015, 0.08)

func cap_of(res: String) -> float:
	return float(world.economy.caps.get(res, INF))

# ---------------------------------------------------------------- instant deals

func sell(res: String, qty: int) -> String:
	if not has_market():
		return "Instant market deals require a Market."
	var eco: Node = world.economy
	if eco.res.get(res, 0.0) < qty:
		return "Not enough %s to sell." % res
	var earned := roundi(qty * price(res) * float(cfg.instantSell))
	eco.res[res] -= qty
	eco.res.money += earned
	changed.emit()
	return "Sold %d %s for $%d." % [qty, res, earned]

func buy(res: String, qty: int) -> String:
	if not has_market():
		return "Instant market deals require a Market."
	var eco: Node = world.economy
	var cost := roundi(qty * price(res) * float(cfg.instantBuy))
	if eco.res.money < cost:
		return "Buying %d %s costs $%d." % [qty, res, cost]
	if eco.res.get(res, 0.0) + qty > cap_of(res):
		return "Not enough %s storage for this purchase." % res
	eco.res.money -= cost
	eco.res[res] += qty
	changed.emit()
	return "Bought %d %s for $%d." % [qty, res, cost]

# ---------------------------------------------------------------- routes

func open_route(nation: int, res: String, dir: String, qty: int) -> String:
	var d: Node = world.diplomacy
	if ports() == 0:
		return "Overseas trade requires a completed Commercial Port."
	if d.defeated(nation):
		return "That nation no longer exists."
	if d.at_war(0, nation):
		return "You cannot trade with a nation you are at war with."
	if not d.pact[0][nation]:
		return "Trade routes need a trade pact with %s." % d.name_of(nation)
	if routes.size() >= route_cap():
		return "Route limit reached (%d). Each port has %d berths; trade pacts and markets give contracts." % [route_cap(), int(cfg.routesPerPort)]
	routes.append({"id": _next_id, "nation": nation, "res": res, "dir": dir, "qty": qty, "shipment": null, "status": "Awaiting cargo", "total": 0.0})
	_next_id += 1
	changed.emit()
	return "Trade route opened: %s %d %s %s %s." % ["exporting" if dir == "export" else "importing", qty, res, "to" if dir == "export" else "from", d.name_of(nation)]

func close_route(id: int) -> String:
	for i in range(routes.size()):
		if routes[i].id == id:
			var r: Dictionary = routes[i]
			routes.remove_at(i)
			if r.shipment != null:
				lost += 1
			changed.emit()
			return "Trade route with %s closed%s." % [world.diplomacy.name_of(r.nation), "; the cargo at sea was forfeited" if r.shipment != null else ""]
	return ""

func _process(delta: float) -> void:
	if world == null or world.economy == null or world.game_over != "":
		return
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		tick()

func ai_nation(id: int):
	for n in world.ai.nations:
		if n.id == id:
			return n
	return null

func tick() -> void:
	for res in mult:
		mult[res] = clampf(mult[res] * (0.97 + randf() * 0.06), 0.55, 1.9)
	var d: Node = world.diplomacy
	var eco: Node = world.economy
	while routes.size() > route_cap():
		var r: Dictionary = routes.pop_back()
		if r.shipment != null:
			lost += 1
		world.hud.notice("The %s route closed: your ports lost capacity%s." % [d.name_of(r.nation), "; its cargo was lost" if r.shipment != null else ""])
	for i in range(routes.size() - 1, -1, -1):
		var r: Dictionary = routes[i]
		if d.defeated(r.nation) or d.at_war(0, r.nation) or not d.pact[0][r.nation]:
			if r.shipment != null:
				lost += 1
			routes.remove_at(i)
			world.hud.notice("Trade route with %s collapsed%s." % [d.name_of(r.nation), " — the cargo at sea was lost" if r.shipment != null else ""])
			continue
		var partner = ai_nation(r.nation)
		if r.shipment != null:
			r.shipment.eta -= TICK
			r.status = "At sea — %ds" % maxi(0, int(r.shipment.eta))
			if r.shipment.eta > 0.0:
				continue
			var cargo: Dictionary = r.shipment
			r.shipment = null
			if randf() < risk():
				lost += 1
				r.status = "Shipment lost — reloading"
				world.hud.notice("A %s shipment on the %s route was lost at sea. Warships reduce this risk." % [r.res, d.name_of(r.nation)])
				continue
			if r.dir == "export":
				eco.res.money += cargo.value
				if partner != null:
					partner.money = maxf(0.0, partner.money - cargo.value * 0.5)
			else:
				eco.res[r.res] = minf(cap_of(r.res), eco.res.get(r.res, 0.0) + cargo.qty)
				if partner != null:
					partner.money += cargo.value * 0.5
			r.total += cargo.value
			delivered += 1
			r.status = "Delivered — reloading"
			d.change(0, r.nation, 0.8)
			continue
		var value := roundi(r.qty * price(r.res) * (float(cfg.importMarkup) if r.dir == "import" else 1.0))
		var voyage := float(cfg.voyage)
		if r.dir == "export" and eco.res.get(r.res, 0.0) >= r.qty:
			eco.res[r.res] -= r.qty
			r.shipment = {"qty": r.qty, "value": value, "eta": voyage}
			r.status = "Outbound — %ds" % int(voyage)
		elif r.dir == "import" and eco.res.money >= value:
			if eco.res.get(r.res, 0.0) + r.qty <= cap_of(r.res):
				eco.res.money -= value
				r.shipment = {"qty": r.qty, "value": value, "eta": voyage}
				r.status = "Inbound — %ds" % int(voyage)
			else:
				r.status = "Stalled — no storage"
		else:
			r.status = "Stalled — not enough stock" if r.dir == "export" else "Stalled — not enough money"
	changed.emit()

func capture() -> Dictionary:
	return {"mult": mult, "routes": routes, "delivered": delivered, "lost": lost, "next_id": _next_id}

func restore(data: Dictionary) -> void:
	for key in data.get("mult", {}):
		mult[key] = float(data.mult[key])
	routes.clear()
	for r in data.get("routes", []):
		var copy: Dictionary = r.duplicate(true)
		copy.id = int(copy.id)
		copy.nation = int(copy.nation)
		copy.qty = int(copy.qty)
		routes.append(copy)
	delivered = int(data.get("delivered", 0))
	lost = int(data.get("lost", 0))
	_next_id = int(data.get("next_id", routes.size() + 1))
