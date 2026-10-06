extends SceneTree
## A hundred checks on the intelligence game (espionage.gd): the agency and
## its agents; an assignment from submission to recovery; what makes success
## likelier; what each programme needs; what every operation does, to the
## rival and to you; failure, capture and ransom; promotion; exposure and its
## scandal; intelligence that decays and warns; the rival services working
## against you; what a hit does to a rival government in play (factories,
## income, offensives, its army's punch); local partners; saves; a nine-nation
## match; and the Intelligence panel.
var errors: Array[String] = []
var passed := 0
var w: Node
var e: Node
var d: Node
const DT := 1.0 / 15.0
const T := 1   # the usual target
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
	e = w.espionage
	d = w.diplomacy

func nation(id: int) -> Dictionary:
	for n in w.ai.nations:
		if n.id == id: return n
	return {}

func agency() -> void:
	if e.has_agency(): return
	var at: Vector3 = w.land_point(w.start, 45.0)
	w.place_building("intelAgency", at, 0, true)
	w.economy.recalculate()

func rich() -> void:
	w.economy.res.money = maxf(w.economy.res.money, 200000.0)

## A ready agent (recruited if need be).
func ready_agent() -> Dictionary:
	for a in e.agents:
		if a.status == "recovering": a.ready_at = e.clock
	e.advance(0.01)
	if e.ready_agents().is_empty():
		rich()
		e.recruit()
	return e.ready_agents()[0]

## Runs `key` against `nation` to its end with the outcome forced by `roll`
## (0 succeeds, 0.999 fails). Returns the report it files.
func op(key: String, nation := T, roll := 0.0, role := "") -> String:
	agency()
	rich()
	ready_agent()
	e.missions = e.missions.filter(func(m): return int(m.nation) != nation)
	e.cooldowns[nation] = {}
	e.network[nation] = maxf(float(e.network[nation]), float(e.PROGRAMS[key][2]))
	e.intel[nation] = maxf(float(e.intel[nation]), float(e.PROGRAMS[key][3]))
	if key == "assassinate":
		e.dossiers[nation] = {"t": e.clock, "confidence": "high", "source": "test", "army_low": 0, "army_high": 0, "money_low": 0, "money_high": 0, "ties": "", "stability": 75}
	if key == "armRebels" and not e.proxies.has(nation):
		e.proxies[nation] = {"strength": 70.0, "autonomy": 15.0, "until": e.clock + 300.0}
	var why: String = e.run(key, nation, role, -1, roll)
	if not why.contains("authorized"):
		return "BLOCKED: " + why
	e.advance(float(e.PROGRAMS[key][0]) + 1.0)
	return str(e.reports[0].text) if not e.reports.is_empty() else ""

func last_notice() -> String:
	var box: Node = w.hud._notices
	return str(box.get_child(box.get_child_count() - 1).get_child(0).text) if box.get_child_count() > 0 else ""

func assets(owner: int) -> int:
	return w.buildings.filter(func(b): return b.owner == owner and not b.dead).size()

func run() -> void:
	await load_match({"map": "island", "players": 4, "nation": 0, "style": "standard"}, "normal")
	seed(777)
	w.economy.grant_test_resources()

	# ------------------------------------------------ A. the agency and its agents (1-8)
	check(e.recruit().begins_with("Build an Intelligence Agency"), "no agents without an Intelligence Agency")
	check(e.blocked_reason("openSources", T) != "", "and no operations either")
	agency()
	rich()
	var cost1: int = e.recruit_cost()
	var cash: float = w.economy.res.money
	var said: String = e.recruit()
	check(said.contains("joins the service") and absf(cash - w.economy.res.money - cost1) < 0.01, "an agent is recruited for $%d" % cost1)
	var cost2: int = e.recruit_cost()
	check(cost2 == cost1 + int(e.cfg.recruitStep), "the next one costs more ($%d)" % cost2)
	for i in range(4): e.recruit()
	var names := {}
	for a in e.agents: names[a.name] = true
	check(names.size() == e.agents.size(), "every agent has a name of their own (%s)" % ", ".join(PackedStringArray(names.keys())))
	check(e.agents.all(func(a): return a.status == "ready" and int(a.skill) == 1), "new agents are ready rookies")
	cash = w.economy.res.money
	e.run("openSources", T, "", -1, 0.0)
	check(absf(cash - w.economy.res.money - float(e.ops().openSources.cost)) < 0.01, "an operation is paid for when it is authorised ($%d)" % int(e.ops().openSources.cost))
	check(e.agents.any(func(a): return a.status == "deployed"), "and its agent is deployed")

	# ------------------------------------------------ B. an assignment's life (9-16)
	var m: Dictionary = e.missions[0]
	var reports0: int = e.reports.size()
	e.advance(float(e.PROGRAMS.openSources[0]) - 2.0)
	check(e.missions.size() == 1 and e.reports.size() == reports0, "nothing is known before the preparation is over")
	e.advance(3.0)
	check(e.missions.is_empty() and e.reports.size() == reports0 + 1, "the result comes when it is over")
	var agent: Dictionary = e._agent(int(m.agent))
	check(agent.status == "recovering", "the agent then recovers")
	check(e.blocked_reason("openSources", T).begins_with("Security/recovery window"), "the same programme against the same nation waits out its window")
	e.advance(31.0)
	check(agent.status == "ready", "and is ready again after 30 s")
	e.run("openSources", 2, "", -1, 0.0)
	check(e.blocked_reason("buildNetwork", 2).begins_with("One assignment per target"), "one assignment per target at a time")
	var busy: Dictionary = e.missions[0]
	check(e.blocked_reason("buildNetwork", 3) == "", "while another agent works on another nation")
	cash = w.economy.res.money
	var recalled: String = e.cancel_mission(int(busy.agent))
	check(recalled.contains("recalled") and w.economy.res.money == cash and e.missions.is_empty() and float(e.cooldowns[2].values().max()) > e.clock, "a recalled assignment keeps its cost and its window")

	# ------------------------------------------------ C. the odds (17-24)
	for a in e.agents: a.status = "ready"
	var fresh: Dictionary = {"network": e.network[3], "heat": e.heat[3]}
	e.network[3] = 0.0
	e.heat[3] = 0.0
	var base_p: float = e.success_chance("stealFunds", 3)
	e.network[3] = 50.0
	check(e.success_chance("stealFunds", 3) > base_p, "a network inside the country raises the odds (%.0f%% -> %.0f%%)" % [base_p * 100, e.success_chance("stealFunds", 3) * 100])
	e.network[3] = 0.0
	e.heat[3] = 60.0
	check(e.success_chance("stealFunds", 3) < base_p, "heat on your service lowers them (%.0f%%)" % (e.success_chance("stealFunds", 3) * 100))
	e.heat[3] = 0.0
	e.types[3] = {"a": true, "b": true, "c": true}
	check(e.success_chance("stealFunds", 3) > base_p, "varied past operations help a little")
	e.types[3] = {}
	e._set_debuff(3, "alert", 100.0)
	check(e.success_chance("stealFunds", 3) < base_p - 0.1, "a country on alert is harder (%.0f%%)" % (e.success_chance("stealFunds", 3) * 100))
	e.debuffs[3] = {}
	var easy_n: Dictionary = nation(3)
	var level0: String = str(easy_n.get("level", ""))
	easy_n.level = "easy"
	var p_easy: float = e.success_chance("stealFunds", 3)
	easy_n.level = "hard"
	var p_hard: float = e.success_chance("stealFunds", 3)
	easy_n.level = level0
	check(p_hard < p_easy, "a hard government's counter-intelligence is tougher (%.0f%% against %.0f%%)" % [p_hard * 100, p_easy * 100])
	w.research.progress.cyberWarfare.stage = 3
	w.research._recompute()
	check(e.success_chance("stealFunds", 3) > base_p, "Cyber Warfare research raises the odds")
	w.research.progress.cyberWarfare.stage = 0
	w.research._recompute()
	e.heat[3] = 100.0
	e._set_debuff(3, "alert", 100.0)
	var worst: float = e.success_chance("assassinate", 3)
	e.network[3] = 100.0
	e.heat[3] = 0.0
	e.debuffs[3] = {}
	var best: float = e.success_chance("openSources", 3)
	check(worst >= 0.05 and best <= 0.95, "the odds never fall below 5% nor pass 95% (%.0f%%, %.0f%%)" % [worst * 100, best * 100])
	e.network[3] = fresh.network
	e.heat[3] = fresh.heat
	var agency_p: float = e.success_chance("stealFunds", 3)
	check(agency_p >= base_p, "the agency itself is worth ten points")

	# ------------------------------------------------ D. what programmes need (25-30)
	e.cooldowns[3] = {}
	e.network[3] = 0.0
	e.intel[3] = 0.0
	check(e.blocked_reason("reconDossier", 3) == "Requires network 8.", "a field dossier needs a network (8)")
	e.network[3] = 25.0
	check(e.blocked_reason("influence", 3) == "Requires intelligence 20.", "influence needs intelligence (20)")
	e.intel[3] = 60.0
	e.network[3] = 60.0
	e.dossiers.erase(3)
	check(e.blocked_reason("assassinate", 3, "general").begins_with("Requires a field dossier"), "a leadership strike needs a fresh dossier")
	check(e.blocked_reason("armRebels", 3) == "Establish a local partner first.", "arming rebels needs a local partner")
	e.proxies[3] = {"strength": 70.0, "autonomy": 15.0, "until": e.clock + 300.0}
	check(e.blocked_reason("proxyCell", 3) == "A local partner is already supported.", "one partner per country")
	e.proxies.erase(3)
	var poor: float = w.economy.res.money
	w.economy.res.money = 10.0
	check(e.blocked_reason("sabotage", 3) == "Insufficient treasury for this program.", "no operation without the money")
	w.economy.res.money = poor

	# ------------------------------------------------ E. what each operation does (31-52)
	var net0: float = e.network[T]
	var heat0: float = e.heat[T]
	op("buildNetwork")
	check(e.network[T] >= net0 + 16.0 - 0.01 and e.heat[T] > heat0, "building a network: +16 access, some heat (%d, heat %d)" % [int(e.network[T]), int(e.heat[T])])
	e.network[T] = 30.0
	op("reconDossier")
	check(e.dossiers.has(T) and e.dossiers[T].confidence == "medium" and e.dossiers[T].source == "Corroborated field reporting", "a field dossier: medium confidence with a network of 30")
	e.network[T] = 70.0
	op("reconDossier")
	check(e.dossiers[T].confidence == "high", "high confidence with a network of 70")
	var army: int = d.army_strength(T)
	check(army >= int(e.dossiers[T].army_low) and army <= int(e.dossiers[T].army_high), "its army estimate brackets the truth (%d in %d-%d)" % [army, int(e.dossiers[T].army_low), int(e.dossiers[T].army_high)])
	var heat_before: float = e.heat[T]
	op("openSources")
	check(e.dossiers[T].confidence == "low" and e.heat[T] == heat_before, "open sources: a low-confidence estimate, and no heat")
	op("counterSweep")
	check(e.security_until > e.clock + 100.0, "a counter-intelligence review guards you for 3 minutes")
	e.heat[T] = 50.0
	e.network[T] = 40.0
	op("withdrawNetwork")
	check(absf(e.heat[T] - 15.0) < 0.1 and absf(e.network[T] - 30.0) < 0.1, "standing down a network: heat -35, access -10")
	var backfires := 0
	var weakened := 0
	for i in range(16):
		e.stability[T] = 75.0
		e.debuffs[T] = {}
		op("influence")
		if e.stability[T] > 75.0: backfires += 1
		if e.active(T, "influence"): weakened += 1
	check(weakened >= 8 and backfires >= 1, "influence mostly weakens a government, and sometimes rallies it (%d weakened, %d backfired of 16)" % [weakened, backfires])
	e.debuffs[T] = {}
	op("cyberAttack")
	check(e.production_down(T), "a cyber attack stops the rival's factories")
	var rival: Dictionary = nation(T)
	rival.money = 1000.0
	rich()
	cash = w.economy.res.money
	op("stealFunds")
	var taken: float = 1000.0 - float(rival.money)
	# (an exposure's scandal may cost up to $2/s of the minute meanwhile)
	var gained: float = w.economy.res.money - cash + float(e.ops().stealFunds.cost)   # the operation's own price
	check(taken >= 400.0 and gained <= taken + 0.5 and gained >= taken - 125.0, "stealing funds: $%d moves from their treasury to yours ($%d net)" % [int(taken), int(gained)])
	rival.tech = 3.0
	var points: float = w.research.points
	op("stealTech")
	check(w.research.points >= points + 119.0 and absf(float(rival.tech) - 2.5) < 0.01, "stealing research: +120 points for you, half a level off theirs")
	rival.money = 5000.0
	var rich0: float = float(rival.money)
	var said_ship: String = op("shipping")
	check(float(rival.money) < rich0 and said_ship.contains("freighter"), "sabotaging shipping sinks a cargo and its value (%s)" % said_ship.substr(0, 70))
	var target_b: Array = w.buildings.filter(func(b): return b.owner == T and not b.dead and b.built and b.key != "hq")
	if target_b.is_empty():
		w.place_building("barracks", w.land_point(w.ai.hq(T).root.position, 30.0), T, true)
	var peace: bool = not d.at_war(0, T)
	op("sabotage")
	var burnt: bool = w.buildings.any(func(b): return b.owner == T and (b.dead or b.hp < b.max_hp * 0.5))
	check(burnt, "sabotage sets one of their buildings burning (70% of it)")
	check(not peace or not d.at_war(0, T), "and, fired by no soldier, starts no war")
	e.proxies.erase(T)
	op("proxyCell")
	check(e.proxies.has(T) and e.income_mult(T) < 1.0, "a local partner cuts the rival's income (%.0f%%)" % (e.income_mult(T) * 100))
	op("armRebels")
	check(e.active(T, "unrest") and e.income_mult(T) < 0.75, "armed rebels cut it further (%.0f%%)" % (e.income_mult(T) * 100))
	d.set_score(T, 2, 0.0)
	d.set_score(T, 3, 0.0)
	op("falseFlag")
	check(d.rel(T, 2) <= -44.0 or d.rel(T, 3) <= -44.0, "a false flag sets two rivals against each other (%d, %d)" % [int(d.rel(T, 2)), int(d.rel(T, 3))])
	e.debuffs[T] = {}
	e.proxies.erase(T)
	var leader: String = e.person(T, "president")
	op("assassinate", T, 0.0, "president")
	check(e.active(T, "president") and e.paralyzed(T) and absf(e.income_mult(T) - 0.65) < 0.05, "the head of state struck: income -35%, the army paralysed")
	check(e.person(T, "president").begins_with("Successor 1") and leader != e.person(T, "president"), "and a successor takes office (%s after %s)" % [e.person(T, "president"), leader])
	var attacker: Dictionary = w.spawn_unit("tank", w.land_point(w.ai.hq(2).root.position, 30.0), 2)
	w.order_move([attacker], w.start, true)
	e.debuffs[2] = {}
	op("assassinate", 2, 0.0, "general")
	check(e.damage_mult(2) < 0.75 and attacker.target == null, "the top general struck: their army hits 30% softer, its offensive stops")
	var sci: Dictionary = nation(3)
	sci.tech = 5.0
	e.debuffs[3] = {}
	op("assassinate", 3, 0.0, "scientist")
	check(absf(float(sci.tech) - 3.0) < 0.01, "the chief scientist struck: two research levels lost")
	e.debuffs[2] = {}
	var cs0: float = e.counter_spy(2)
	op("assassinate", 2, 0.0, "spymaster")
	check(e.counter_spy(2) <= 0.02 and e.active(2, "alert"), "the spymaster struck: their counter-intelligence collapses (%.2f -> %.2f), on alert though" % [cs0, e.counter_spy(2)])
	check(e.impact_text(2).contains("Intelligence disruption") and e.impact_text(2).contains("Heightened security"), "the Intel panel lists what is in effect against a nation")
	e.debuffs[2] = {}
	e.debuffs[3] = {}

	# ------------------------------------------------ F. failure, capture, ransom, promotion (53-58)
	e.heat[3] = 10.0
	e.network[3] = 30.0
	op("stealFunds", 3, 0.999)
	check(e.heat[3] >= 23.9 and e.network[3] <= 30.0 - 4.9 + 3.0, "a failed operation raises heat and costs access (heat %d)" % int(e.heat[3]))
	var caught: Dictionary = {}
	for i in range(30):
		d.set_score(0, 3, 0.0)
		op("sabotage", 3, 0.999)
		for a in e.agents:
			if a.status == "captured": caught = a
		if not caught.is_empty(): break
	check(not caught.is_empty() and int(caught.captured_by) == 3, "a failed risky operation can end in capture")
	check(caught.is_empty() or d.rel(0, 3) <= -20.0, "and a captured agent sours relations (%d)" % int(d.rel(0, 3)))
	var captor: Dictionary = nation(3)
	var captor_cash: float = float(captor.money)
	cash = w.economy.res.money
	var ransom: String = e.ransom(int(caught.get("id", -1)))
	check(ransom.contains("ransomed") and caught.status == "recovering" and float(captor.money) > captor_cash and w.economy.res.money < cash, "a ransom brings the agent home, and pays the captor")
	var quiet: String = op("openSources", 3, 0.999)
	check(quiet.contains("inconclusive"), "a failed open-source assessment is merely inconclusive (%s)" % quiet.substr(0, 60))
	rich()
	e.recruit()
	var vet: Dictionary = e.agents[-1]   # a new recruit, to watch rise
	for a in e.agents:
		if not is_same(a, vet):
			a.status = "away"   # out of the way: only the recruit works
	var skill0: int = int(vet.skill)
	for i in range(6):
		vet.status = "ready"
		op("openSources", 2, 0.0)
	check(int(vet.skill) > skill0 and int(vet.xp) >= 5, "successful operations promote an agent (%s, %d ops)" % [e.rank(vet), int(vet.ops)])
	for a in e.agents:
		if a.status == "away": a.status = "ready"

	# ------------------------------------------------ G. exposure (59-63)
	e.heat[2] = 0.0
	var ex0: float = e.exposure_chance("sabotage", 2)
	e.heat[2] = 80.0
	check(e.exposure_chance("sabotage", 2) > ex0 and e.exposure_chance("openSources", 2) == 0.0, "heat makes exposure likelier; open sources are never exposed")
	d.set_score(0, 2, 30.0)
	d.set_score(0, 3, 30.0)
	d.pact[0][2] = true
	d.pact[2][0] = true
	e.network[2] = 40.0
	e.debuffs[2] = {}
	e._expose(2, "sabotage")
	check(d.rel(0, 2) <= 10.5 and not d.pact[0][2], "exposed: relations -20 and the trade pact revoked")
	check(d.rel(0, 3) < 30.0, "and the other nations think less of you too")
	check(e.network[2] <= 28.1 and e.active(2, "alert"), "the network is compromised and the country on alert")
	cash = w.economy.res.money
	e.advance(20.0)
	check(w.economy.res.money < cash - 30.0, "a scandal costs $2 a second while it lasts")
	e.scandal_until = 0.0

	# ------------------------------------------------ H. intelligence that fades and warns (64-69)
	e.intel[2] = 50.0
	e.heat[2] = 20.0
	for i in range(10): e.tick()
	check(e.intel[2] < 50.0 and e.heat[2] < 20.0, "intelligence and heat fade with time (%.1f, %.1f)" % [e.intel[2], e.heat[2]])
	check(e.INTEL_TIERS.size() == 4 and int(e.INTEL_TIERS[3][0]) == 60, "intelligence opens four tiers, warning of attacks at 60")
	e.intel[2] = 70.0
	e.dossiers[2] = {"t": e.clock, "confidence": "high", "source": "x", "army_low": 1, "army_high": 2, "money_low": 1, "money_high": 2, "ties": "", "stability": 70}
	w.hud.notice("-")
	e.warn_attack(2)
	check(last_notice().begins_with("INTELLIGENCE"), "with intelligence 60 and a fresh dossier you are warned of an attack (%s)" % last_notice())
	e.dossiers[2].t = e.clock - 400.0
	w.hud.notice("--")
	e.warn_attack(2)
	check(last_notice() == "--", "a stale dossier gives no warning")
	check(e.dossier_text(2).contains("STALE"), "and the Intel panel marks it stale")
	check(e.dossier_text(1).contains("confidence"), "a dossier tells its confidence and age")

	# ------------------------------------------------ I. rival services against you (70-76)
	d.make_peace(0, 1)
	d.make_peace(0, 2)
	d.make_peace(0, 3)
	for i in range(1, 4): d.set_score(0, i, 40.0)
	e.enemy_next = 0.0
	check(e.enemy_attempt("theft") == "", "no hostile service works against you while every nation is friendly")
	d.declare_war(2, 0)
	e.enemy_next = 0.0
	var research0: float = w.research.points
	var caught_text: String = e.enemy_attempt("caught")
	check(caught_text.contains("caught") and w.research.points >= research0 + 39.0, "an enemy agent caught: +40 research from the interrogation")
	check(e.reports[0].text.contains("captured and interrogated"), "and it is on file")
	check(e.enemy_next > e.clock + 100.0, "a hostile service tries again only after a while")
	var outcomes := {"money": 0, "research": 0, "sabotage": 0, "caught": 0}
	w.economy.res.money = 100000.0
	for i in range(60):
		e.enemy_next = 0.0
		var text: String = e.enemy_attempt("")
		if text.contains("siphoned"): outcomes.money += 1
		elif text.contains("stole your research"): outcomes.research += 1
		elif text.contains("SABOTAGE"): outcomes.sabotage += 1
		elif text.contains("caught"): outcomes.caught += 1
	check(outcomes.money > 0 and outcomes.research > 0 and outcomes.sabotage > 0, "hostile services steal money, research and bomb buildings (%s)" % str(outcomes))
	var def_off: float = 0.0
	var def_on: float = 0.0
	for trial in range(2):
		if trial == 1: e.security_until = e.clock + 999.0
		var got := 0
		for i in range(80):
			e.enemy_next = 0.0
			if e.enemy_attempt("").contains("caught"): got += 1
		if trial == 0: def_off = got
		else: def_on = got
	e.security_until = 0.0
	check(def_on > def_off, "a counter-intelligence review catches more of them (%d against %d of 80)" % [int(def_on), int(def_off)])
	check(outcomes.caught > 0, "some are caught even without a review (%d of 60)" % outcomes.caught)

	# ------------------------------------------------ J. the hit, in play (77-84)
	d.make_peace(0, 2)
	var g: Dictionary = nation(2)
	g.money = 50000.0
	g.next_build = 0.0
	e.debuffs[2] = {}
	e._set_debuff(2, "cyber", 90.0)
	var b0: int = assets(2)
	for i in range(int(30.0 / DT)): w.ai._physics_process(DT)
	check(assets(2) == b0, "under a cyber attack a rival builds nothing (%d buildings)" % assets(2))
	e.debuffs[2] = {}
	g.next_build = 0.0
	for i in range(int(30.0 / DT)): w.ai._physics_process(DT)
	check(assets(2) > b0, "and builds again once it is over (%d)" % assets(2))
	g.money = 0.0
	g.next_build = 9999.0
	g.next_train = 9999.0
	for i in range(int(20.0 / DT)): w.ai._physics_process(DT)
	var normal_income: float = g.money
	g.money = 0.0
	e._set_debuff(2, "president", 240.0)
	for i in range(int(20.0 / DT)): w.ai._physics_process(DT)
	check(g.money < normal_income * 0.75, "a leaderless government earns less ($%d against $%d in 20 s)" % [int(g.money), int(normal_income)])
	e.debuffs[2] = {}
	d.declare_war(2, 0)
	g.money = 50000.0
	for i in range(10): w.spawn_unit("tank", w.land_point(w.ai.hq(2).root.position, 30.0), 2)
	g.next_attack = 0.0
	e._set_debuff(2, "paralyzed", 90.0)
	for i in range(int(3.0 / DT)): w.ai._physics_process(DT)
	check(not w.units.any(func(u): return u.owner == 2 and not u.dead and u.attack_move), "a paralysed army launches no attack")
	e.debuffs[2] = {}
	g.next_attack = 0.0
	for i in range(int(3.0 / DT)): w.ai._physics_process(DT)
	check(w.units.any(func(u): return u.owner == 2 and not u.dead and u.attack_move), "once it recovers, it attacks")
	var shooter: Dictionary = w.spawn_unit("tank", w.land_point(w.start, 60.0), 2)
	var victim: Dictionary = w.spawn_unit("apc", shooter.node.position + Vector3(8, 0, 0), 0)
	var hp_a: float = victim.hp
	w.damage(victim, 100.0, shooter)
	var normal_hit: float = hp_a - victim.hp
	victim.hp = hp_a
	e._set_debuff(2, "general", 240.0)
	w.damage(victim, 100.0, shooter)
	var soft_hit: float = hp_a - victim.hp
	e.debuffs[2] = {}
	check(soft_hit < normal_hit * 0.8, "without its general a rival's shots hit softer (%d against %d)" % [int(soft_hit), int(normal_hit)])
	w.kill(shooter)
	w.kill(victim)
	e.proxies[3] = {"strength": 70.0, "autonomy": 15.0, "until": e.clock + 300.0}
	cash = w.economy.res.money
	e.advance(10.0)
	check(absf(cash - w.economy.res.money - 30.0) < 1.0, "a local partner costs $3 a second")
	e.advance(300.0)
	check(not e.proxies.has(3), "and its mandate ends after 5 minutes")

	# ------------------------------------------------ K. partners, stability, saves, the fallen (85-92)
	agency()   # the rival services' bombs may have taken the agency
	e.proxies[3] = {"strength": 70.0, "autonomy": 15.0, "until": e.clock + 300.0}
	w.economy.res.money = 0.0
	e.advance(120.0)
	check(not e.proxies.has(3), "an unpaid partner breaks away")
	check(e.reports[0].text.contains("broke away"), "and it is on file")
	w.economy.res.money = 200000.0
	e.stability[3] = 40.0
	e.advance(200.0)
	check(e.stability[3] > 40.0, "a shaken government steadies with time (%.0f)" % e.stability[3])
	e.missions.clear()
	for a in e.agents: a.status = "ready"
	e.cooldowns[3] = {}
	e.network[3] = 30.0
	e.intel[3] = 30.0
	var sent: String = e.run("stealFunds", 3, "", -1, 0.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(e.capture()))
	e.missions.clear()
	e.restore(saved)
	check(e.missions.size() == 1 and int(e.missions[0].nation) == 3, "an assignment under way survives a save")
	check(e.blocked_reason("stealFunds", 3) != "", "and so does its window")
	e.advance(float(e.PROGRAMS.stealFunds[0]) + 1.0)
	check(e.missions.is_empty() and float(e.reports[0].t) >= e.clock - 2.0 and int(e.reports[0].nation) == 3, "and it ends after the load as it would have")
	e.cooldowns[3] = {}
	for a in e.agents: a.status = "ready"
	e.run("openSources", 3, "", -1, 0.0)
	w.destroy_building(w.ai.hq(3))
	w.ai._physics_process(0.1)
	e.advance(30.0)
	check(e.reports[0].text.contains("cancelled"), "an assignment against a fallen nation is cancelled")
	check(e.blocked_reason("openSources", 3) == "That nation no longer exists.", "and no new one can be sent")

	# ------------------------------------------------ L. the Intelligence panel (93-96)
	w.hud.show()
	w.hud._panels = w.hud._panels if w.hud._panels != null else preload("res://scripts/side_panels.gd").new(w.hud)
	var labels := func() -> String:
		var parts := PackedStringArray()
		for l in w.hud._side_rows.find_children("*", "Label", true, false): parts.append(l.text)
		for b in w.hud._side_rows.find_children("*", "Button", true, false): parts.append(b.text)
		return " | ".join(parts)
	for tab in ["operations", "agents", "dossiers", "reports"]:
		w.hud._panels.intel_tab = tab
		w.hud.toggle_panel("intel", true)
		await process_frame
		var text: String = labels.call()
		var want: String = {"operations": "Success", "agents": e.agents[0].name, "dossiers": "confidence", "reports": "success"}[tab]
		check(text.contains(want), "the Intelligence panel's %s tab shows %s" % [tab, want])
		w.hud.toggle_panel("intel", false)

	# ------------------------------------------------ M. nine nations, and national talent (97-100)
	await load_match({"map": "great_lakes", "players": 9, "nation": 8, "style": "standard"}, "normal")
	seed(99)
	w.economy.grant_test_resources()
	check(e.network.size() == 8 and e.stability.size() == 8, "with nine nations the service follows all eight rivals")
	var said9: String = op("reconDossier", 8)
	check(e.dossiers.has(8) and not said9.begins_with("BLOCKED"), "and works in the ninth (%s)" % said9.substr(0, 50))
	var israel_p: float = e.success_chance("stealTech", 5)
	w.map.nations[0].id = "russia"
	w.research._recompute()
	var russia_p: float = e.success_chance("stealTech", 5)
	w.map.nations[0].id = "israel"
	w.research._recompute()
	check(israel_p > russia_p, "a nation's own talent counts: Israel's service beats Russia's (%.0f%% against %.0f%%)" % [israel_p * 100, russia_p * 100])

	print("\nINTEL_100: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("INTEL_100 PASS" if errors.is_empty() else "INTEL_100 FAIL")
	quit(0 if errors.is_empty() else 1)
