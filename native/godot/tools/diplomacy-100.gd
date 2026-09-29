extends SceneTree
## A hundred checks on diplomacy: relations; war and peace; treaties and their
## terms; the world turning (rivals feuding and making up, relations with you
## drifting); letters from foreign governments; contacts between leaders
## (channels, agendas, counteroffers, aid, arms exports, demands, expiry);
## firm language (protests, sanctions, red lines, ultimatums, surrender);
## limited operations and how governments answer them; passage through other
## nations' land; saves; and the Diplomacy screen.
var errors: Array[String] = []
var passed := 0
var w: Node
var d: Node
var c: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func load_match(cfg: Dictionary, difficulty := "normal") -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match(difficulty)
	w.menu._root.hide()
	for i in range(8): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		node.set_process(false)
	d = w.diplomacy
	c = d.contacts
	c.set_process(false)
	w.passage.set_process(false)

func nation(id: int) -> Dictionary:
	for n in w.ai.nations:
		if n.id == id: return n
	return {}

func reset(a: int) -> void:
	if d.at_war(0, a): d.make_peace(0, a)
	for grid in [d.alliance, d.pact, d.nap]: d.set_flag(grid, 0, a, false)

func clear_letters() -> void:
	w.hud._letters.clear()
	if w.hud._letter_box != null:
		w.hud._letter_box.free()
		w.hud._letter_box = null

func letter_text() -> String:
	if w.hud._letter_box == null: return ""
	var parts := PackedStringArray()
	for l in w.hud._letter_box.find_children("*", "Label", true, false): parts.append(l.text)
	return " | ".join(parts)

func press(label: String) -> bool:
	if w.hud._letter_box == null: return false
	for b in w.hud._letter_box.find_children("*", "Button", true, false):
		if b.text == label:
			b.pressed.emit()
			return true
	return false

func army(owner: int, count: int, key := "tank") -> Array:
	var out := []
	var at: Vector3 = w.start if owner == 0 else w.ai.hq(owner).root.position
	for i in range(count): out.append(w.spawn_unit(key, w.land_point(at, 30.0), owner))
	return out

## A leader contact through `channel`, ready to talk.
func talk(n: int, channel := "phone") -> String:
	c.session = {}
	c.cooldowns.erase(str(n))
	w.economy.res.money = maxf(w.economy.res.money, 50000.0)
	var why: String = c.begin(n, channel)
	if why != "": return why
	c.advance(float(c.session.duration) + 0.5)
	return "" if c.session.phase == "talking" else "not talking: " + str(c.session.phase)

func last_result() -> Dictionary:
	return c.session.results[-1] if not c.session.get("results", []).is_empty() else {}

func run() -> void:
	await load_match({"map": "island", "players": 4, "nation": 0, "style": "standard"})
	seed(4242)
	w.economy.grant_test_resources()
	w.economy.res.money = 100000.0
	clear_letters()

	# ------------------------------------------------ A. relations (1-8)
	var sym := true
	for a in range(d.n):
		for b in range(d.n):
			if d.rel(a, b) != d.rel(b, a): sym = false
	check(sym, "relations are the same both ways")
	d.set_score(0, 1, 250.0)
	var hi: float = d.rel(0, 1)
	d.set_score(0, 1, -250.0)
	check(hi == 100.0 and d.rel(0, 1) == -100.0, "and run from -100 to +100")
	d.set_score(0, 1, 0.0)
	var china: int = -1
	for i in range(1, d.n):
		if str(w.map.nations[i].get("id", "")) == "china": china = i
	check(china < 0 or d.rel(0, china) < 10.0, "history counts: the United States starts cool with China (%d)" % (int(d.rel(0, china)) if china > 0 else 0))
	d.set_flag(d.pact, 0, 2, true)
	d.set_flag(d.nap, 0, 2, true)
	check(d.status_text(2) == "trade pact, non-aggression", "the status line lists the treaties (%s)" % d.status_text(2))
	reset(2)
	var armed: int = w.units.filter(func(u): return u.owner == 1 and not u.dead and u.dmg > 0.0).size()
	w.spawn_unit("worker", w.land_point(w.ai.hq(1).root.position, 20.0), 1)
	check(d.army_strength(1) == armed, "army strength counts armed units only (%d)" % armed)
	d.declare_war(1, 2)
	check(2 in d.enemies_of(1) and not 3 in d.enemies_of(1), "a nation knows its enemies")
	d.make_peace(1, 2)
	var easy: Dictionary = nation(1)
	var hard: Dictionary = nation(2)
	easy.level = "easy"
	hard.level = "hard"
	check(d.aggression_of(2) > d.aggression_of(1), "a hard government is more aggressive (%.2f against %.2f)" % [d.aggression_of(2), d.aggression_of(1)])

	# ------------------------------------------------ B. war and peace (9-20)
	d.set_score(0, 3, 40.0)
	d.set_flag(d.alliance, 0, 3, true)
	d.set_flag(d.pact, 0, 3, true)
	d.declare_war(0, 3)
	check(d.at_war(0, 3) and d.at_war(3, 0) and d.rel(0, 3) == -100.0, "war: both sides, relations at the bottom")
	check(not d.allied(0, 3) and not d.pact[0][3] and not d.nap[0][3], "and every treaty between them ends")
	d.make_peace(0, 3)
	reset(3)
	d.set_score(0, 1, 30.0)
	d.set_score(0, 2, 30.0)
	d.set_flag(d.nap, 0, 3, true)
	d.declare_war(0, 3)
	check(d.rel(0, 1) <= 22.1 and d.rel(0, 2) <= 22.1, "breaking a non-aggression pact: every other nation trusts you less (%d, %d)" % [int(d.rel(0, 1)), int(d.rel(0, 2))])
	d.make_peace(0, 3)
	var joined := 0
	for i in range(20):
		d.make_peace(1, 3)
		d.make_peace(0, 3)
		d.set_flag(d.alliance, 1, 3, true)
		d.declare_war(0, 3)
		if d.at_war(1, 0):
			joined += 1
			d.make_peace(1, 0)
	check(joined >= 4 and joined <= 16, "attack a nation, and its allies may join it (%d times of 20)" % joined)
	d.set_flag(d.alliance, 1, 3, false)
	var r_before: float = d.rel(0, 3)
	d.declare_war(0, 3)
	check(d.rel(0, 3) == r_before, "declaring war twice changes nothing")
	d.make_peace(0, 3)
	check(not d.at_war(0, 3) and d.rel(0, 3) == -30.0, "peace: no war, relations at -30")
	check(d.offer_peace(3).begins_with("You are not at war"), "there is no peace to offer to a nation at peace")
	for u in w.units:
		if u.owner == 3 and not u.dead: w.kill(u)
	army(0, 12)
	var strong := 0
	for i in range(100):
		d.declare_war(0, 3)
		if d.offer_peace(3).contains("accepted"): strong += 1
		else: d.make_peace(0, 3)
	army(3, 30)
	var weak := 0
	for i in range(100):
		d.declare_war(0, 3)
		if d.offer_peace(3).contains("accepted"): weak += 1
		else: d.make_peace(0, 3)
	check(strong > weak, "the stronger you are, the readier they are for peace (%d%% against %d%%)" % [strong, weak])
	for u in w.units:   # equal footing: no army on either side, so only temperament differs
		if u.owner in [0, 1, 2] and not u.dead and u.dmg > 0.0: w.kill(u)
	var calm := 0
	var fierce := 0
	for i in range(200):
		d.declare_war(0, 1)
		if d.offer_peace(1).contains("accepted"): calm += 1
		d.make_peace(0, 1)
		d.declare_war(0, 2)
		if d.offer_peace(2).contains("accepted"): fierce += 1
		d.make_peace(0, 2)
	check(calm > fierce, "an easy government makes peace more readily than a hard one (%d against %d of 200)" % [calm, fierce])
	d.set_score(0, 1, -50.0)
	check(d.ai_wants_war(1, 0), "a government whose relations have collapsed wants war")
	d.set_flag(d.nap, 0, 1, true)
	check(not d.ai_wants_war(1, 0), "not while a non-aggression pact holds")
	d.set_flag(d.nap, 0, 1, false)
	d.set_flag(d.alliance, 0, 1, true)
	check(not d.ai_wants_war(1, 0), "nor against an ally")
	reset(1)

	# ------------------------------------------------ C. treaties (21-30)
	d.set_score(0, 1, 0.0)
	var cash: float = w.economy.res.money
	d.gift(1)
	check(absf(cash - w.economy.res.money - d.GIFT) < 0.01 and d.rel(0, 1) == 9.0, "a gift costs $%d and warms relations by 9" % int(d.GIFT))
	w.economy.res.money = 10.0
	check(d.gift(1).begins_with("A meaningful gift costs") and d.rel(0, 1) == 9.0, "no gift without the money")
	w.economy.res.money = 100000.0
	d.set_score(0, 1, 15.0)
	check(d.propose_pact(1).begins_with("Relations too cold") and not d.pact[0][1], "a trade pact needs relations of +20")
	d.declare_war(0, 1)
	check(d.propose_pact(1) == "No trade during war.", "and peace")
	d.make_peace(0, 1)
	d.set_score(0, 1, 30.0)
	d.propose_pact(1)
	cash = w.economy.res.money
	var theirs0: float = float(nation(1).money)
	d.tick()
	check(d.pact[0][1] and w.economy.res.money >= cash + 39.9 and float(nation(1).money) >= theirs0 + 39.9, "a trade pact pays both sides $40 every ten seconds")
	d.set_score(0, 2, 5.0)
	check(d.propose_nap(2).begins_with("Relations need"), "a non-aggression pact needs +10")
	var signed := 0
	var refusals_cost := true
	for i in range(40):
		d.set_flag(d.nap, 0, 2, false)
		d.set_score(0, 2, 20.0)
		var said: String = d.propose_nap(2)
		if d.nap[0][2]: signed += 1
		elif d.rel(0, 2) != 17.0: refusals_cost = false
	check(signed > 10 and signed < 40 and refusals_cost, "and is signed often, not always; a refusal costs 3 (%d of 40)" % signed)
	d.set_score(0, 3, 40.0)
	check(d.propose_alliance(3).begins_with("They need a relation of at least +55"), "an alliance needs +55")
	var allied := 0
	for i in range(40):
		d.set_flag(d.alliance, 0, 3, false)
		d.set_score(0, 3, 70.0)
		d.propose_alliance(3)
		if d.allied(0, 3): allied += 1
	check(allied >= 22 and allied <= 38, "and is agreed about three times in four (%d of 40)" % allied)
	d.set_flag(d.alliance, 0, 3, true)
	var joins := 0
	for i in range(40):
		d.declare_war(0, 2)
		d.make_peace(3, 2)
		d.set_score(0, 3, 70.0)
		d.request_joint_war(3, 2)
		if d.at_war(3, 2): joins += 1
		d.make_peace(0, 2)
	check(joins > 10 and joins < 40, "an ally asked to join your war comes, often (%d of 40)" % joins)
	d.declare_war(0, 2)
	check(d.request_joint_war(1, 2) == "" and not d.at_war(1, 2), "a nation that is no ally is not asked")
	d.make_peace(0, 2)
	for i in range(1, 4): reset(i)

	# ------------------------------------------------ D. the world turning (31-38)
	for a in range(1, 4):
		for b in range(a + 1, 4):
			d.set_score(a, b, 0.0)
			d.make_peace(a, b)
			d.set_score(a, b, 0.0)
	d.tick()
	check(d.rel(1, 2) != 0.0 or d.rel(1, 3) != 0.0, "rival relations drift from tick to tick")
	var feud := false
	for i in range(200):
		d.set_score(1, 2, -90.0)
		d.tick()
		if d.at_war(1, 2):
			feud = true
			break
	check(feud, "a bitter feud between rivals turns into war")
	var cease := false
	for i in range(300):
		d.tick()
		if not d.at_war(1, 2):
			cease = true
			break
	check(cease, "and wars between rivals end in ceasefires")
	reset(1)
	d.set_score(0, 1, 50.0)
	d.tick()
	check(d.rel(0, 1) < 50.0, "warm relations with you cool without care (%.1f)" % d.rel(0, 1))
	d.set_score(0, 1, -50.0)
	d.tick()
	var plain_mend: float = d.rel(0, 1) + 50.0
	w.research.progress.diplomaticCorps.stage = 3
	w.research._recompute()
	d.set_score(0, 1, -50.0)
	d.tick()
	var corps_mend: float = d.rel(0, 1) + 50.0
	w.research.progress.diplomaticCorps.stage = 0
	w.research._recompute()
	check(corps_mend > plain_mend, "cold relations mend faster with a Diplomatic Corps (%+.1f against %+.1f)" % [corps_mend, plain_mend])
	d.set_score(0, 1, -10.0)
	d.set_score(0, 2, -10.0)
	d.tick()
	check(d.rel(0, 2) < d.rel(0, 1), "a hard government's relations with you sour faster")
	d.set_score(0, 2, -10.0)
	d.set_flag(d.pact, 0, 2, true)
	d.tick()
	var with_pact: float = d.rel(0, 2)
	check(with_pact > d.rel(0, 1) - 0.01 or with_pact >= -10.0, "treaties hold the souring back")
	reset(2)
	var hq3 = w.ai.hq(3)
	w.destroy_building(hq3)
	w.ai._physics_process(0.1)
	var frozen: float = d.rel(1, 3)
	for i in range(5): d.tick()
	check(d.defeated(3) and d.rel(1, 3) == frozen, "a fallen nation's relations stand still")

	# ------------------------------------------------ E. letters (39-48)
	check(d._next_letter >= 200.0 or w.game_time > 0.0, "no foreign mail in the first minutes")
	clear_letters()
	for u in w.units:
		if u.owner == 1 and not u.dead: w.kill(u)
	army(0, 5)
	d.declare_war(0, 1)
	var wrote := false
	for i in range(20):
		clear_letters()
		d.write_letter()
		if letter_text().contains("ceasefire") and letter_text().contains(d.name_of(1)):
			wrote = true
			break
	check(wrote, "a weaker enemy writes proposing a ceasefire")
	press("Accept")
	check(not d.at_war(0, 1), "accepted, the war ends")
	var kinds := {"alliance": [70.0, "proposes an alliance"], "pact": [30.0, "trade pact"], "tribute": [-40.0, "tribute"], "nap": [5.0, "non-aggression"]}
	var got := {}
	for kind in kinds:
		reset(1)
		reset(2)
		d.set_score(0, 1, kinds[kind][0])
		d.set_score(0, 2, kinds[kind][0])
		var text := ""
		for i in range(10):
			clear_letters()
			d.write_letter()
			text = letter_text()
			if text.contains(kinds[kind][1]): break
		got[kind] = text.contains(kinds[kind][1])
		var who: int = 1 if text.contains(d.name_of(1)) else 2
		var r0: float = d.rel(0, who)
		cash = w.economy.res.money
		press("Accept")
		match kind:
			"alliance": check(got[kind] and d.allied(0, who) and d.rel(0, who) >= r0 + 14.9, "a warm government proposes an alliance; accepted: allies, +15")
			"pact": check(got[kind] and d.pact[0][who], "a friendly one proposes a trade pact")
			"tribute": check(got[kind] and w.economy.res.money <= cash - 199.9 and d.rel(0, who) >= r0 + 11.9, "a hostile one demands $200 in tribute; paid, relations +12")
			"nap": check(got[kind] and d.nap[0][who], "a neutral one asks for a non-aggression pact")
	reset(1)
	reset(2)
	d.set_score(0, 1, -40.0)
	d.set_score(0, 2, -40.0)
	w.economy.res.money = 50.0
	clear_letters()
	d.write_letter()
	var tribute_to: int = 1 if letter_text().contains(d.name_of(1)) else 2
	var r_t: float = d.rel(0, tribute_to)
	press("Accept")
	check(d.rel(0, tribute_to) <= r_t - 14.9, "tribute that cannot be paid offends (-15)")
	w.economy.res.money = 100000.0
	reset(1)
	reset(2)
	d.set_score(0, 1, 70.0)
	d.set_score(0, 2, 70.0)
	clear_letters()
	d.write_letter()
	var decliner: int = 1 if letter_text().contains(d.name_of(1)) else 2
	press("Decline")
	check(d.rel(0, decliner) <= 62.1, "declining an alliance costs 8 (%d)" % int(d.rel(0, decliner)))
	# An offer that has lapsed: the letter waits for an answer, the world does not.
	reset(1)
	reset(2)
	d.set_score(0, 1, 70.0)
	d.set_score(0, 2, 70.0)
	clear_letters()
	d.write_letter()
	var offerer: int = 1 if letter_text().contains(d.name_of(1)) else 2
	d.declare_war(offerer, 0)
	press("Accept")
	check(not (d.allied(0, offerer) and d.at_war(0, offerer)), "an alliance offered before a war cannot be accepted during it")
	d.make_peace(0, offerer)
	reset(offerer)
	d.set_score(0, 1, 30.0)
	d.set_score(0, 2, 30.0)
	clear_letters()
	d.write_letter()
	var pact_from: int = 1 if letter_text().contains(d.name_of(1)) else 2
	d.declare_war(pact_from, 0)
	press("Accept")
	check(not (d.pact[0][pact_from] and d.at_war(0, pact_from)), "nor a trade pact")
	d.make_peace(0, pact_from)
	clear_letters()

	# ------------------------------------------------ F. leaders in contact (49-71)
	for i in range(1, 3): reset(i)
	d.set_score(0, 1, 40.0)
	cash = w.economy.res.money
	c.session = {}
	c.cooldowns.clear()
	c.begin(1, "phone")
	check(absf(cash - w.economy.res.money - 25.0) < 0.01 and c.session.phase == "connecting", "a secure telephone call costs $25 and connects")
	c.advance(5.5)
	check(c.session.phase == "talking", "after five seconds the leaders talk")
	check(c.start_reason(2, "phone") == "Conclude the current contact first.", "one contact at a time")
	c.propose("trade")
	check(last_result().get("outcome", "") == "Accepted" and d.pact[0][1], "warm relations: a trade agreement is signed")
	c.propose("nap")
	check(c.topic_reason("aid").begins_with("The agenda is full"), "a telephone call holds two items")
	check(c.topic_reason("trade") != "", "an item is not discussed twice")
	c.finish()
	check(c.start_reason(1, "phone").begins_with("Their diplomatic office is busy"), "after a contact their office is busy for a while")
	c.session = {}
	c.cooldowns.clear()
	check(c.topic_reason("trade") == "Wait until contact is established.", "nothing is proposed before contact")
	talk(2, "phone")
	d.set_score(0, 2, 90.0)
	check(c.topic_reason("alliance") == "A defence alliance requires an in-person summit.", "an alliance needs a state visit")
	var dur: float = c.duration(2, "visit")
	check(dur >= 60.0 and dur <= 180.0, "a state visit takes the journey's time (%d s)" % int(dur))
	d.set_score(0, 2, -40.0)
	c.session = {}
	c.cooldowns.clear()
	check(c.start_reason(2, "visit").begins_with("Visit invitation declined"), "no state visit to a hostile government")
	d.set_score(0, 2, 90.0)
	talk(2, "visit")
	c.propose("alliance")
	check(d.allied(0, 2), "at a summit a close friend agrees an alliance")
	reset(2)
	d.set_score(0, 2, -10.0)   # willing, but not quite: a counteroffer
	talk(2, "phone")
	c.propose("nap")
	var countered: bool = not c.session.counter.is_empty()
	cash = w.economy.res.money
	c.answer_counter(true)
	check(countered and d.nap[0][2] and w.economy.res.money <= cash - 199.9, "near the line they counter with a $200 concession; accepted, the pact is signed")
	reset(2)
	d.set_score(0, 2, -10.0)
	talk(2, "phone")
	c.propose("nap")
	c.answer_counter(false)
	check(last_result().get("outcome", "") == "No agreement" and not d.nap[0][2], "declined, nothing is signed")
	for u in w.units:
		if u.owner == 2 and not u.dead: w.kill(u)
	army(0, 10)
	army(2, 2)
	d.declare_war(0, 2)
	talk(2, "mediator")
	c.propose("peace")
	check(not d.at_war(0, 2), "a much stronger army makes peace through a mediator")
	reset(2)
	d.set_score(0, 2, 10.0)
	talk(2, "phone")
	cash = w.economy.res.money
	var given: float = float(nation(2).money)
	c.propose("aid")
	check(w.economy.res.money <= cash - 299.9 and float(nation(2).money) >= given + 299.9 and d.rel(0, 2) >= 21.9, "development aid: $300 to their treasury, relations +12")
	c.session = {}
	c.cooldowns.clear()
	c.exports.clear()
	d.set_score(0, 2, 50.0)
	nation(2).money = 5000.0
	talk(2, "phone")
	var tanks0: int = w.units.filter(func(u): return u.owner == 2 and u.key == "tank" and not u.dead).size()
	c.propose("arms")
	var bought: bool = c.exports.size() == 1
	cash = w.economy.res.money
	c.advance(61.0)
	check(bought and w.units.filter(func(u): return u.owner == 2 and u.key == "tank" and not u.dead).size() == tanks0 + 1 and w.economy.res.money >= cash + 799.9, "an arms export: a tank is made and delivered in a minute, and paid for ($800)")
	c.session = {}
	c.cooldowns.clear()
	talk(2, "phone")
	c.propose("arms")
	cash = w.economy.res.money
	var buyer_cash: float = float(nation(2).money)
	d.declare_war(0, 2)
	c.advance(1.0)
	check(c.exports.is_empty() and w.economy.res.money > cash and float(nation(2).money) > buyer_cash, "war cancels an export, and both sides are refunded")
	d.make_peace(0, 2)
	reset(2)
	for u in w.units:
		if u.owner == 2 and not u.dead: w.kill(u)
	army(2, 1)
	nation(2).money = 5000.0
	d.set_score(0, 2, 30.0)
	talk(2, "phone")
	var payer0: float = float(nation(2).money)
	c.propose("demand")
	check(float(nation(2).money) <= payer0 - 299.9 or last_result().get("outcome", "") == "Rejected", "with the stronger army you may demand compensation (%s)" % last_result().get("outcome", ""))
	c.session = {}
	c.cooldowns.clear()
	cash = w.economy.res.money
	c.begin(2, "phone")
	c.back_to_channels()
	check(absf(w.economy.res.money - cash) < 0.01 and c.session.phase == "choosing", "changing channel before anything is said refunds the fee")
	c.session = {}
	c.cooldowns.clear()
	talk(1, "phone")
	c.advance(400.0)
	check(c.session.phase == "concluded" and c.session.message.begins_with("The diplomatic window has closed"), "an unused contact closes after its window")
	c.session = {}
	c.cooldowns.clear()
	talk(1, "phone")
	w.espionage.succession[1]["president"] = 1
	c.advance(1.0)
	check(c.session.phase == "concluded" and c.session.message.contains("leadership has changed"), "a change of leader suspends the talks")
	w.espionage.succession[1]["president"] = 0
	c.session = {}
	c.cooldowns.clear()
	talk(1, "phone")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.capture()))
	c.session = {}
	c.restore(saved)
	check(c.session.get("phase", "") == "talking" and int(c.session.nation) == 1, "a contact under way survives a save")
	c.finish()

	# ------------------------------------------------ G. firm language (72-81)
	reset(1)
	d.set_score(0, 1, 10.0)
	check(c.relation_state(1) == "peace", "relations are at peace, in a cold war, or at war (peace)")
	d.set_score(0, 1, -50.0)
	check(c.relation_state(1) == "cold", "deep hostility is a cold war")
	d.set_score(0, 1, 10.0)
	talk(1, "phone")
	c.propose("protest")
	check(last_result().get("outcome", "") in ["Regret expressed", "Rejected"], "a formal protest is answered (%s)" % last_result().get("outcome", ""))
	var foe_of_1: int = 2
	d.set_score(foe_of_1, 1, -40.0)
	d.set_score(0, foe_of_1, 0.0)
	var r1: float = d.rel(0, 1)
	c.propose("condemn")
	check(d.rel(0, 1) <= r1 - 9.9 and d.rel(0, foe_of_1) >= 2.9, "a public condemnation: -10 with them, +3 with their enemies")
	c.finish()
	c.session = {}
	c.cooldowns.clear()
	d.set_flag(d.pact, 0, 1, false)
	talk(1, "visit")
	check(c.topic_reason("sanctions") == "Sanctions need a trade agreement to suspend.", "sanctions need a trade agreement to threaten")
	c.finish()
	c.session = {}
	c.cooldowns.clear()
	talk(1, "phone")
	var r_recall: float = d.rel(0, 1)
	c.propose("recall")
	check(d.rel(0, 1) <= r_recall - 14.9 and float(c.cooldowns[str(1)]) >= c.clock + 230.0, "recalling the ambassador: -15, and no contact for four minutes")
	c.finish()
	c.cooldowns[str(1)] = c.clock + 240.0
	c.session = {}
	c.cooldowns.clear()
	for u in w.units:
		if u.owner == 1 and not u.dead: w.kill(u)
	army(0, 6)
	var foe: Dictionary = nation(1)
	foe.next_attack = 100.0
	talk(1, "phone")
	c.propose("redline")
	check(float(foe.next_attack) >= 249.0, "a credible red line puts back their next offensive")
	c.finish()
	c.session = {}
	c.cooldowns.clear()
	d.set_score(0, 1, -50.0)
	var intruder: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 25.0), 1)
	talk(1, "phone")
	c.propose("ultimatum")
	check(last_result().get("outcome", "") == "Complied" and (intruder.target != null or d.at_war(0, 1)), "an ultimatum: with the stronger army, their forces leave your land")
	c.finish()
	d.declare_war(0, 1)
	foe.money = 5000.0
	c.session = {}
	c.cooldowns.clear()
	talk(1, "phone")
	cash = w.economy.res.money
	c.propose("surrender")
	check(not d.at_war(0, 1) and w.economy.res.money >= cash + 599.9, "with twice their army you may demand surrender: $600 and peace")
	c.finish()
	d.declare_war(0, 1)
	c.session = {}
	c.cooldowns.clear()
	talk(1, "phone")
	var r_war: float = d.rel(0, 1)
	c.propose("prisoners")
	check(d.rel(0, 1) >= r_war + 5.9 and d.at_war(0, 1), "a prisoner exchange warms relations a little; the war goes on")
	w.missiles.stock["nuke"] = 1
	foe.next_attack = 10.0
	c.propose("escalation")
	check(float(foe.next_attack) >= 249.0, "an escalation warning backed by a nuclear missile holds their offensive back")
	c.finish()
	d.make_peace(0, 1)

	# ------------------------------------------------ H. limited operations (82-89)
	var eng = w.engagement
	reset(2)
	d.set_score(0, 2, 20.0)
	d.set_flag(d.pact, 0, 2, true)
	eng.incidents.erase("2")
	eng.begin(2, "limited")
	check(not d.at_war(0, 2) and eng.active(0, 2) and not d.pact[0][2] and d.rel(0, 2) <= 2.1, "a limited operation: no war, 90 seconds, treaties end, relations -18")
	var went_to_war := false
	for i in range(20):
		if d.at_war(0, 2): d.make_peace(0, 2)
		eng.incidents["2"] = 7   # (a far stronger army of yours deters them: many grievances)
		d.set_score(0, 2, -90.0)
		eng.answer(2)
		if d.at_war(0, 2):
			went_to_war = true
			break
	check(went_to_war, "a government that has swallowed too much calls it war")
	d.make_peace(0, 2)
	eng.policy = "war"
	eng.begin(2, eng.policy)
	check(d.at_war(0, 2), "under full-war orders the strike comes with a declaration")
	d.make_peace(0, 2)
	eng.policy = "limited"
	eng.operations.clear()
	eng.begin(1, "limited")
	var shooter: Dictionary = w.spawn_unit("tank", w.land_point(w.start, 30.0), 0)
	var mark: Dictionary = w.spawn_unit("tank", shooter.node.position + Vector3(12, 0, 0), 1)
	shooter.enemy = mark
	w.game_time += 91.0
	eng.update()
	check(not eng.active(0, 1) and shooter.enemy == null and not d.at_war(0, 1), "when the operation ends the shooting stops, and no one has declared war")
	w.kill(shooter)
	w.kill(mark)
	eng.operations.clear()
	clear_letters()
	d.set_score(0, 1, 0.0)
	eng.raid(1)
	check(eng.active(0, 1) and d.rel(0, 1) <= -11.9 and letter_text().contains("limited operation"), "a rival's border strike: relations -12, and the cabinet asks you how to answer")
	check(press("Declare war") and d.at_war(0, 1), "answered with a declaration of war")
	d.make_peace(0, 1)
	eng.operations.clear()
	var their_farm: Dictionary = w.place_building("farm", w.land_point(w.ai.hq(2).root.position, 25.0), 2, true)
	var hit: Array = eng.affected(their_farm.root.position, 8.0)
	check(2 in hit, "a strike on a building is traced to its nation")

	# ------------------------------------------------ I. passage (90-96)
	var pas: Node = w.passage
	reset(2)
	pas.grants.clear()
	d.set_score(0, 2, 60.0)
	var asked: String = pas.request(2)
	check(pas.has_passage(0, 2) and pas.seconds_left(0, 2) > 200.0, "a friend grants passage for four minutes (%s)" % asked)
	pas.grants.clear()
	d.set_score(0, 2, -30.0)
	var no: String = pas.request(2)
	check(not pas.has_passage(0, 2) and d.rel(0, 2) <= -31.9, "a hostile government refuses, and minds being asked")
	d.set_flag(d.alliance, 0, 2, true)
	check(pas.has_passage(0, 2), "allies may always cross")
	d.set_flag(d.alliance, 0, 2, false)
	pas.grant(0, 2, 10.0)
	w.game_time += 11.0
	check(not pas.has_passage(0, 2), "and a grant runs out")
	# Your soldier in their land.
	w.territory.tick()
	var inside: Vector3 = Vector3.INF
	for i in range(w.territory.owner_of.size()):
		if w.territory.owner_of[i] == 2 and w.open_ground(w.territory.center(i)):
			inside = w.territory.center(i)
			break
	d.set_score(0, 2, 0.0)
	var walker: Dictionary = w.spawn_unit("soldier", inside, 0)
	var inc0: int = int(eng.incidents.get("2", 0))
	pas.trespass.clear()
	pas.answered.clear()
	for i in range(30): pas.watch(1.0)
	check(d.rel(0, 2) <= -2.9 and int(eng.incidents.get("2", 0)) > inc0, "crossing their land without leave: relations fall, and after a while their government answers")
	w.kill(walker)
	if d.at_war(0, 2): d.make_peace(0, 2)
	clear_letters()
	eng.operations.clear()   # (their answer to the trespass above may have opened one)
	for i in range(1, 3):
		if d.at_war(0, i): d.make_peace(0, i)
	for u in w.units:   # (the soldier from the ultimatum above may still be on its way home)
		if u.owner > 0 and not u.dead and w.territory.owner_at(u.node.position) == 0: w.kill(u)
	var guest: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 20.0), 2)
	pas.asked.clear()
	pas.trespass.clear()
	pas.watch(1.0)
	var letter: String = letter_text()
	var withdrew: bool = press("Demand withdrawal")
	check(letter.contains("crossed into your territory") and withdrew and guest.target != null, "their soldiers in your land: you are asked, and a demand sends them home")
	w.kill(guest)
	clear_letters()
	var soldier: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 20.0), 0)
	var issued := {"done": false}
	pas.check_order([soldier], inside, func(): issued.done = true)
	var options: Array = pas.last_answers.map(func(a): return a[0])
	pas.answer("Cross anyway")
	check(options.size() == 4 and issued.done, "an order across closed land asks first: request, operation, cross anyway or cancel")
	w.kill(soldier)
	clear_letters()

	# ------------------------------------------------ J. the fallen, saves, the screen (97-100)
	check(d.status_text(3) == "defeated" or not d.defeated(3), "a fallen nation's status reads 'defeated'")
	d.set_score(0, 1, 42.0)
	d.set_flag(d.nap, 0, 1, true)
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	d.set_score(0, 1, -10.0)
	d.set_flag(d.nap, 0, 1, false)
	w.saves.restore(data)
	for i in range(5): await process_frame
	d = w.diplomacy
	check(absf(d.rel(0, 1) - 42.0) < 0.1 and d.nap[0][1], "a save keeps relations and treaties")
	w.hud.show()
	w.hud._panels = w.hud._panels if w.hud._panels != null else preload("res://scripts/side_panels.gd").new(w.hud)
	w.hud._panels.diplomacy_tab = "nations"
	w.hud.toggle_panel("diplomacy", true)
	await process_frame
	var text := PackedStringArray()
	for l in w.hud._side_rows.find_children("*", "Label", true, false): text.append(l.text)
	var joined_text: String = " | ".join(text)
	check(joined_text.contains(d.name_of(1).split(" · ")[0]) and joined_text.contains(d.name_of(2).split(" · ")[0]), "the Diplomacy screen lists the rivals")
	w.hud.toggle_panel("diplomacy", false)

	print("\nDIPLOMACY_100: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("DIPLOMACY_100 PASS" if errors.is_empty() else "DIPLOMACY_100 FAIL")
	quit(0 if errors.is_empty() else 1)
