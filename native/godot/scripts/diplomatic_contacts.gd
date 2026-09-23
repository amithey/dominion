extends Node
## Stateful diplomatic talks. UI never writes treaties or spends funds itself.
signal changed
const CHANNELS := {
	"mediator": {"name": "Third-party message", "fee": 60, "delay": 30, "influence": 4, "topics": 2},
	"phone": {"name": "Secure telephone", "fee": 25, "delay": 5, "influence": 8, "topics": 2},
	"visit": {"name": "State visit", "fee": 180, "delay": 60, "influence": 20, "topics": 4}}
const TOPICS := {
	"peace": ["End hostilities", "End the war; existing territorial control remains. No automatic withdrawal.", 60],
	"trade": ["Trade agreement", "Sign market access; unlock port routes and bilateral trade income.", 30],
	"route": ["Open a shipping route", "Negotiate a recurring resource shipment using your port capacity.", 35],
	"nap": ["Non-aggression treaty", "Promise not to attack. Breaking the treaty harms international trust.", 40],
	"passage": ["Military transit permit", "Permission for your forces to cross their territory for 240 seconds.", 45],
	"aid": ["Development assistance", "Transfer $300 to their treasury; relations improve by 12.", -100],
	"arms": ["Conventional arms export", "Manufacture one tank at its normal resource cost. Buyer pays $800; delivery in 60 seconds.", 55],
	"alliance": ["Defence alliance", "Military partnership, reciprocal access and possible support in war.", 85],
	"demand": ["Demand compensation", "Demand $300. Requires military leverage; refusal costs 8 relations.", 65]}
var world: Node
var clock := 0.0
var session: Dictionary = {}
var cooldowns := {}
var history: Array = []
var exports: Array = []

func _process(delta: float) -> void:
	if world != null and world.economy != null and world.game_over == "" and not world.ai.nations.is_empty():
		advance(delta)

func leader(nation: int) -> String:
	return world.espionage.person(nation, "president")

func duration(nation: int, channel: String) -> float:
	if channel != "visit": return float(CHANNELS[channel].delay)
	var a: Array = world.map.startPositions[0]
	var b: Array = world.map.startPositions[nation]
	return clampf(45.0 + Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])) / 12.0, 60.0, 180.0)

func mediator(nation: int) -> String:
	var d: Node = world.diplomacy
	for i in range(1, d.n):
		if i != nation and not d.defeated(i) and not d.at_war(0, i) and not d.at_war(nation, i) and d.rel(0, i) >= 0 and d.rel(nation, i) >= 0:
			return d.name_of(i)
	return "International secretariat"

func start_reason(nation: int, channel: String) -> String:
	var d: Node = world.diplomacy
	if not CHANNELS.has(channel) or nation <= 0 or nation >= d.n: return "Invalid diplomatic destination."
	if d.defeated(nation): return "This government no longer controls a nation."
	var switching: bool = not session.is_empty() and session.phase == "choosing" and int(session.nation) == nation
	if not session.is_empty() and session.phase != "concluded" and not switching: return "Conclude the current contact first."
	var remaining: float = float(cooldowns.get(str(nation), 0.0)) - clock
	if remaining > 0 and not switching: return "Their diplomatic office is busy for %ds." % ceili(remaining)
	if channel == "visit" and (d.at_war(0, nation) or d.rel(0, nation) < -25): return "Visit invitation declined. Establish peace and improve relations first."
	if world.economy.res.money < CHANNELS[channel].fee: return "Insufficient funds for this channel."
	return ""

func begin(nation: int, channel: String) -> String:
	var reason := start_reason(nation, channel)
	if reason != "": return reason
	world.economy.pay({"money": CHANNELS[channel].fee})
	var delay := duration(nation, channel)
	var previous: Dictionary = session if session.get("phase", "") == "choosing" else {}
	session = {"nation": nation, "channel": channel, "phase": "travelling" if channel == "visit" else "connecting",
		"fee_paid": CHANNELS[channel].fee,
		"ready": clock + delay, "duration": delay, "leader": leader(nation), "visitor": leader(0),
		"mediator": mediator(nation), "results": previous.get("results", []), "used": previous.get("used", []), "counter": previous.get("counter", {}), "expires": clock + delay + 300,
		"message": "Invitation accepted. Your delegation is travelling." if channel == "visit" else "The diplomatic office is establishing contact."}
	cooldowns[str(nation)] = clock + delay + 120
	changed.emit()
	return ""

func back_to_channels() -> String:
	if session.is_empty() or session.phase in ["concluded", "choosing"]: return ""
	# Correcting an unused choice costs nothing. Once negotiation has begun,
	# keep its decisions and agenda usage so switching cannot replay a deal.
	if session.used.is_empty():
		world.economy.refund({"money": session.get("fee_paid", CHANNELS[session.channel].fee)})
		session.fee_paid = 0
	session.phase = "choosing"
	session.message = "Choose another channel. Previous decisions remain recorded." if not session.used.is_empty() else "Choose another channel. Your unused contact fee was refunded."
	changed.emit()
	return ""

func advance(delta: float) -> void:
	clock += maxf(delta, 0.0)
	for job in exports.duplicate():
		var target: int = int(job.nation)
		if world.diplomacy.defeated(target) or world.diplomacy.at_war(0, target):
			world.economy.refund(job.cost)
			var buyer = world.market.ai_nation(target)
			if buyer != null: buyer.money += float(job.price)
			exports.erase(job)
			world.hud.notice("Arms export cancelled: hostilities or government collapse. Both parties refunded.")
			changed.emit()
		elif clock >= float(job.ready):
			var home: Array = world.map.startPositions[target]
			world.spawn_unit("tank", world.land_point(Vector3(home[0], 0, home[1]), 24.0), target)
			world.economy.refund({"money": job.price})
			exports.erase(job)
			world.hud.notice("Arms export delivered to %s. Payment released: $%d." % [world.diplomacy.name_of(target), job.price])
			changed.emit()
	if session.is_empty() or session.phase == "concluded": return
	var n: int = int(session.nation)
	if world.diplomacy.defeated(n) or leader(n) != session.leader or leader(0) != session.visitor:
		finish("Talks suspended: the government or its leadership has changed.")
		return
	if session.phase != "choosing" and session.channel == "visit" and world.diplomacy.at_war(0, n):
		finish("Visit cancelled following the outbreak of war.")
		return
	if clock >= float(session.expires):
		finish("The diplomatic window has closed.")
	elif session.phase in ["travelling", "connecting"] and clock >= float(session.ready):
		session.phase = "talking"
		session.message = "The leaders are ready. Present your agenda."
		world.hud.notice("%s: diplomatic contact ready. Open Diplomacy or click their civic building." % world.diplomacy.name_of(n))
		changed.emit()

func topic_reason(key: String, terms: Dictionary = {}) -> String:
	if session.is_empty() or session.phase != "talking": return "Wait until contact is established."
	if not TOPICS.has(key): return "Unknown proposal."
	if not session.counter.is_empty(): return "Answer the pending counteroffer first."
	if key in session.used: return "Already discussed in this contact."
	if session.used.size() >= int(CHANNELS[session.channel].topics): return "The agenda is full. Conclude this contact."
	return _eligibility(key, terms)

func _eligibility(key: String, terms: Dictionary) -> String:
	var n: int = int(session.nation)
	var d: Node = world.diplomacy
	if d.defeated(n): return "The government is no longer available."
	if leader(n) != session.leader or leader(0) != session.visitor: return "Leadership changed; arrange a new contact."
	if key == "peace":
		return "" if d.at_war(0, n) else "There is no war to end."
	if d.at_war(0, n): return "Negotiate peace before discussing this topic."
	if key == "trade" and d.pact[0][n]: return "A trade agreement already exists."
	if key == "nap" and d.nap[0][n]: return "A non-aggression treaty already exists."
	if key == "alliance":
		if session.channel != "visit": return "A defence alliance requires an in-person summit."
		if d.allied(0, n): return "You are already allies."
	if key == "passage" and world.passage.has_passage(0, n): return "You already have military access."
	if key == "aid" and world.economy.res.money < 300: return "Assistance requires $300."
	if key == "route":
		if not d.pact[0][n]: return "Sign a trade agreement first."
		if world.market.ports() == 0: return "Build a Commercial Port first."
		if world.market.routes.size() >= world.market.route_cap(): return "No free shipping route capacity."
		if terms.get("res", "iron") not in world.market.resources() or terms.get("dir", "export") not in ["export", "import"] or int(terms.get("qty", 25)) not in [10, 25, 50]: return "Invalid shipping terms."
	if key == "arms":
		if session.channel == "mediator": return "Arms licensing requires direct contact."
		if d.rel(0, n) < 20: return "Arms exports require at least +20 relations."
		for i in range(1, d.n):
			if d.allied(0, i) and d.at_war(n, i): return "Export refused: buyer is at war with your ally."
		if world.economy.owned("tankFactory") == 0: return "Build a Tank Factory first."
		if not exports.is_empty(): return "Your arms export production slot is occupied."
		if not world.economy.can_afford(world.unit_defs.tank.cost): return "Insufficient resources to manufacture an export tank."
		var buyer = world.market.ai_nation(n)
		if buyer == null or buyer.money < 800: return "The buyer cannot finance this order."
	if key == "demand":
		if d.army_strength(0) <= d.army_strength(n): return "Your military position cannot support this demand."
		var payer = world.market.ai_nation(n)
		if payer == null or payer.money < 300: return "They cannot fund compensation."
	return ""

func propose(key: String, terms: Dictionary = {}) -> String:
	var reason := topic_reason(key, terms)
	if reason != "": return reason
	var n: int = int(session.nation)
	var d: Node = world.diplomacy
	var influence: float = float(CHANNELS[session.channel].influence)
	var willingness: float = d.rel(0, n) + influence + 30.0
	if key == "peace":
		willingness = 20 + influence + 30.0 * float(d.army_strength(0)) / maxf(1, float(d.army_strength(n)))
		if session.channel == "mediator": willingness += 15
	if key == "demand": willingness += 10.0 * float(d.army_strength(0)) / maxf(1, float(d.army_strength(n)))
	session.used.append(key)
	# Persistent decisions: there is no reroll on opening the window or loading.
	var threshold: float = float(TOPICS[key][2])
	if willingness >= threshold:
		_accept(key, terms, 0)
	elif willingness >= threshold - 25 and key not in ["aid", "demand", "arms"]:
		session.counter = {"key": key, "terms": terms.duplicate(true), "fee": 200}
		session.message = "Counteroffer: %s, with a $200 concession paid to their treasury." % TOPICS[key][0]
	else:
		if key == "demand": d.change(0, n, -8)
		_record(key, "Rejected", "Their government declined these terms.")
	d.changed.emit()
	changed.emit()
	return ""

func answer_counter(accept: bool) -> String:
	if session.is_empty() or session.phase != "talking" or session.counter.is_empty(): return "No pending counteroffer."
	var offer: Dictionary = session.counter.duplicate(true)
	if accept:
		var reason := _eligibility(offer.key, offer.terms)
		if reason != "": return reason
		if world.economy.res.money < float(offer.fee): return "Insufficient funds for the concession."
		session.counter = {}
		_accept(offer.key, offer.terms, int(offer.fee))
	else:
		session.counter = {}
		_record(offer.key, "No agreement", "You declined their counteroffer.")
	changed.emit()
	return ""

func _accept(key: String, terms: Dictionary, fee: int) -> void:
	var reason := _eligibility(key, terms)
	if reason != "":
		_record(key, "Lapsed", reason)
		return
	var n: int = int(session.nation)
	var d: Node = world.diplomacy
	var buyer = world.market.ai_nation(n)
	if fee > 0:
		if buyer == null or not world.economy.pay({"money": fee}):
			_record(key, "Lapsed", "The concession could not be settled.")
			return
		buyer.money += fee
	var detail: String = TOPICS[key][1]
	match key:
		"peace": d.make_peace(0, n)
		"trade": d.set_flag(d.pact, 0, n, true)
		"nap": d.set_flag(d.nap, 0, n, true)
		"alliance": d.set_flag(d.alliance, 0, n, true)
		"passage": world.passage.grant(0, n, 240)
		"aid":
			if buyer == null:
				_record(key, "Lapsed", "The recipient treasury is unavailable.")
				return
			world.economy.pay({"money": 300})
			buyer.money += 300
			d.change(0, n, 12)
		"route": detail = world.market.open_route(n, terms.get("res", "iron"), terms.get("dir", "export"), int(terms.get("qty", 25)))
		"arms":
			var cost: Dictionary = world.unit_defs.tank.cost.duplicate(true)
			world.economy.pay(cost)
			buyer.money -= 800
			exports.append({"nation": n, "price": 800, "cost": cost, "ready": clock + 60})
		"demand":
			buyer.money -= 300
			world.economy.refund({"money": 300})
			d.change(0, n, -12)
	if fee > 0: detail += " Concession paid: $%d." % fee
	_record(key, "Accepted", detail)
	d.changed.emit()

func _record(key: String, outcome: String, detail: String) -> void:
	session.results.append({"key": key, "outcome": outcome, "detail": detail})
	session.message = "%s — %s. %s" % [TOPICS[key][0], outcome, detail]

func finish(reason := "Contact concluded.") -> void:
	if session.is_empty() or session.phase == "concluded": return
	if not session.counter.is_empty():
		_record(session.counter.key, "No agreement", "The counteroffer was left unsigned.")
		session.counter = {}
	session.phase = "concluded"
	session.message = reason + " Accepted items have taken effect; all other items remain unsigned."
	cooldowns[str(session.nation)] = clock + 120
	history.push_front(session.duplicate(true))
	if history.size() > 12: history.resize(12)
	changed.emit()

func capture() -> Dictionary:
	return {"clock": clock, "session": session.duplicate(true), "cooldowns": cooldowns.duplicate(), "history": history.duplicate(true), "exports": exports.duplicate(true)}

func restore(data: Dictionary) -> void:
	clock = float(data.get("clock", 0))
	session = data.get("session", {}).duplicate(true)
	cooldowns = data.get("cooldowns", {}).duplicate()
	history = data.get("history", []).duplicate(true)
	exports = data.get("exports", []).duplicate(true)
	changed.emit()
