extends Node
## World market and overseas trade, ported from the trade engine in
## js/diplomacy.js. Base prices come from config.js (TRADE_PRICE and friends,
## through the map export).
##
## The market is an exchange, not a shop. A deal is filled at once, at a quote
## that gets worse the bigger the order is next to the market's depth
## (slippage), but the listed price does not jump: every order joins the
## order flow, and the price moves over the following seconds as the flow is
## absorbed (exchange_step, every 2 s). The impact grows faster than the
## order (a few dozen units barely register; a sudden block of hundreds moves
## the price hard), and the other traders answer in their own ways: value
## traders buy below fair value and sell above it, momentum traders chase a
## move, others ignore it, and there is always some noise. Fair value itself
## drifts, and war drives up oil, gas and iron. AI nations trade on the same
## book. A Market allows instant deals (sell at 90%, buy at 115% of the price).
## A Commercial Port opens standing routes to nations the player has a trade
## pact with: each route loads a cargo, sails for 30 s and delivers it, or is
## lost at sea (8%, less with warships to escort). Two berths per port;
## contracts come from trade pacts and markets. Routes collapse on war, when
## the pact ends or when port capacity is lost; cargo at sea is then forfeited.

signal changed

const TICK := 10.0
const STEP := 2.0            # seconds between exchange steps
const DEPTH := 450.0         # units the market absorbs per step before prices strain
const HISTORY := 90          # price samples kept per commodity (3 minutes)

var world: Node
var cfg: Dictionary
var mult := {}           # resource -> price multiplier
var routes: Array = []   # {id, nation, res, dir, qty, shipment, status, total}
var delivered := 0
var lost := 0
var _next_id := 1
var _tick := 0.0
var ai_stock := {} # persistent national commodity inventories
var volume := {}
var flow := {}           # resource -> net orders not yet absorbed (+ buying, - selling)
var fair := {}           # resource -> fair value, as a multiplier of the base price
var history := {}        # resource -> recent multipliers, oldest first
var _step := 0.0
var sabotaged := 0       # cargoes enemy saboteurs will sink (espionage.gd)

## Price move from `units` of net order flow (signed): negligible for small
## orders, steep for a block that is large next to the market's depth.
func impact(units: float) -> float:
	var desks := 0
	if world:
		for b in world.buildings:
			if b.key == "market" and b.built and not b.dead:
				desks += 1
	var depth: float = DEPTH * (1.0 + 0.25 * desks)
	return signf(units) * pow(absf(units) / depth, 1.4) * 0.35

## What `qty` units fetch or cost now: the listed price, the dealer's margin,
## and half the move the order itself will cause (a big order walks the book).
func quote(res: String, qty: int, buying: bool) -> float:
	var signed := float(qty) * (1.0 if buying else -1.0)
	var slip := impact(float(flow.get(res, 0.0)) + signed) - impact(float(flow.get(res, 0.0)))
	var avg := maxf(0.1, float(mult[res]) * (1.0 + slip * 0.5))
	return qty * float(cfg.price[res]) * avg * float(cfg.instantBuy if buying else cfg.instantSell)

## An order joins the flow; the price answers over the next exchange steps.
func pressure(res: String, qty: int, buying: bool) -> void:
	flow[res] = float(flow.get(res, 0.0)) + (1.0 if buying else -1.0) * qty
	volume[res] = int(volume.get(res, 0)) + qty

## One step of the exchange: order flow is absorbed, and the other traders act.
func exchange_step() -> void:
	var war := false
	if world and world.diplomacy:
		for i in range(1, world.diplomacy.n):
			if world.diplomacy.at_war(0, i):
				war = true
	for res in mult:
		var m := float(mult[res])
		var f := float(flow.get(res, 0.0))
		var fv := float(fair.get(res, 1.0))
		# Fair value wanders slowly; war makes fuel and metal dear.
		var target := 1.0 + (0.25 if war and res in ["oil", "gas", "iron"] else 0.0)
		fv = clampf(fv + randfn(0.0, 0.006) + (target - fv) * 0.01, 0.7, 1.6)
		fair[res] = fv
		var past: Array = history.get(res, [])
		var trend := 0.0
		if past.size() >= 3:
			trend = m - float(past[past.size() - 3])
		# A share of the flow is absorbed this step; the rest keeps pressing.
		var absorbed := f * 0.4
		var move := impact(absorbed)
		# Contrarian desks sometimes lean against a sharp move, sometimes not.
		if absf(move) > 0.02 and randf() < 0.35:
			move *= randf_range(0.4, 0.8)
		move += (fv - m) * 0.05                       # value traders
		move += trend * randf_range(0.0, 0.3)         # momentum traders (or none)
		move += randfn(0.0, 0.006)                    # noise
		mult[res] = clampf(m + move, 0.35, 3.0)
		flow[res] = f - absorbed
		past.append(mult[res])
		if past.size() > HISTORY:
			past.pop_front()
		history[res] = past

## Change of the listed price over the last `seconds` (a fraction; 0.05 = +5%).
func change(res: String, seconds := 60.0) -> float:
	var past: Array = history.get(res, [])
	var back := int(seconds / STEP)
	if past.size() <= 1:
		return 0.0
	var then := float(past[maxi(0, past.size() - 1 - back)])
	return float(mult[res]) / maxf(then, 0.01) - 1.0

func setup(world_node: Node, trade: Dictionary) -> void:
	world = world_node
	cfg = trade
	for key in cfg.price:
		mult[key] = 1.0
		fair[key] = 1.0
		flow[key] = 0.0
		history[key] = [1.0]

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
	var contracts := pacts + mini(world.economy.owned("market"), 2) + (int(world.research.bonus("tradeRoutes")) if world.research else 0)
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
	if qty <= 0 or not cfg.price.has(res): return "Choose a positive quantity of a traded commodity."
	if not has_market():
		return "Instant market deals require a Market."
	var eco: Node = world.economy
	if eco.res.get(res, 0.0) < qty:
		return "Not enough %s to sell." % res
	var earned := floori(quote(res, qty, false))
	eco.res[res] -= qty
	eco.res.money += earned
	pressure(res, qty, false)
	changed.emit()
	return "Sold %d %s for $%d." % [qty, res, earned]

func buy(res: String, qty: int) -> String:
	if qty <= 0 or not cfg.price.has(res): return "Choose a positive quantity of a traded commodity."
	if not has_market():
		return "Instant market deals require a Market."
	var eco: Node = world.economy
	var cost := ceili(quote(res, qty, true))
	if eco.res.money < cost:
		return "Buying %d %s costs $%d." % [qty, res, cost]
	if eco.res.get(res, 0.0) + qty > cap_of(res):
		return "Not enough %s storage for this purchase." % res
	eco.res.money -= cost
	eco.res[res] += qty
	pressure(res, qty, true)
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
	_step += delta
	if _step >= STEP:
		_step -= STEP
		exchange_step()
		changed.emit()
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
	trade_ai()  # prices move in exchange_step: the traders pull them toward fair value
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
			if sabotaged > 0:
				sabotaged -= 1
				lost += 1
				r.status = "Sunk by saboteurs — reloading"
				world.hud.notice("SABOTAGE: the %s cargo on the %s route was sunk. It never arrived." % [r.res, d.name_of(r.nation)])
				continue
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
			pressure(r.res, r.qty, false)
			r.shipment = {"qty": r.qty, "value": value, "eta": voyage}
			r.status = "Outbound — %ds" % int(voyage)
		elif r.dir == "import" and eco.res.money >= value:
			if eco.res.get(r.res, 0.0) + r.qty <= cap_of(r.res):
				eco.res.money -= value
				pressure(r.res, r.qty, true)
				r.shipment = {"qty": r.qty, "value": value, "eta": voyage}
				r.status = "Inbound — %ds" % int(voyage)
			else:
				r.status = "Stalled — no storage"
		else:
			r.status = "Stalled — not enough stock" if r.dir == "export" else "Stalled — not enough money"
	changed.emit()

func capture() -> Dictionary:
	return {"mult": mult, "routes": routes, "delivered": delivered, "lost": lost, "next_id": _next_id, "ai_stock": ai_stock, "volume": volume, "flow": flow, "fair": fair, "history": history, "sabotaged": sabotaged}

func restore(data: Dictionary) -> void:
	ai_stock = data.get("ai_stock", {}).duplicate(true)
	volume = data.get("volume", {}).duplicate(true)
	for key in data.get("mult", {}):
		mult[key] = float(data.mult[key])
	for key in data.get("flow", {}):
		flow[key] = float(data.flow[key])
	for key in data.get("fair", {}):
		fair[key] = float(data.fair[key])
	for key in data.get("history", {}):
		history[key] = Array(data.history[key]).map(func(v): return float(v))
	routes.clear()
	for r in data.get("routes", []):
		var copy: Dictionary = r.duplicate(true)
		copy.id = int(copy.id)
		copy.nation = int(copy.nation)
		copy.qty = int(copy.qty)
		routes.append(copy)
	sabotaged = int(data.get("sabotaged", 0))
	delivered = int(data.get("delivered", 0))
	lost = int(data.get("lost", 0))
	_next_id = int(data.get("next_id", routes.size() + 1))

func trade_ai() -> void:
	if world.ai == null: return
	for nation in world.ai.nations:
		if world.diplomacy.defeated(nation.id): continue
		var id := str(nation.id)
		if not ai_stock.has(id): ai_stock[id] = {}
		var stock: Dictionary = ai_stock[id]
		var desks := 0
		for b in world.buildings:
			if b.owner != nation.id or b.dead or not b.built or not b.get("supplied", true): continue
			if b.key == "market": desks += 1
			if b.deposit != null:
				var resource: String = b.deposit.def.res
				stock[resource] = minf(500.0, float(stock.get(resource, 100.0)) + float(b.deposit.def.rate) * TICK)
			if b.key in ["farm", "fishingWharf"]: stock["food"] = minf(500.0, float(stock.get("food", 100.0)) + 30.0)
		var army := 0
		for u in world.units:
			if u.owner == nation.id and not u.dead: army += 1
		for resource in cfg.price:
			var use: float = 12.0 + army * 0.3 if resource == "food" else (3.0 + army * 0.12 if resource in ["oil", "iron", "gas"] else 2.0)
			stock[resource] = maxf(0.0, float(stock.get(resource, 100.0)) - use)
			if desks == 0: continue
			if stock[resource] < 70.0:
				var bill := ceili(quote(resource, 30, true))
				if nation.money >= bill + 150:
					nation.money -= bill
					stock[resource] += 30
					pressure(resource, 30, true)
			elif stock[resource] > 180.0:
				nation.money += floori(quote(resource, 30, false))
				stock[resource] -= 30
				pressure(resource, 30, false)
