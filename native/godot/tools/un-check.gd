extends SceneTree
## End-to-end UN regressions with real diplomacy/economy/market/save/UI.
var w: Node
var errors: Array[String] = []
var passed := 0
var u

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for frame in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		push_error("UN fixture failed to load")
		quit(1)
		return
	w.start_match("easy")
	w.menu._root.hide()
	for frame in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["un"])
	u = w.un
	u.queue.clear()
	u.current = null
	var d: Node = w.diplomacy
	var Data := preload("res://scripts/un_data.gd")
	check(u.members().size() == 4 and u.council().size() == 4, "every campaign member is represented")
	check(u.needed({"measure": "ceasefire", "target": 1, "other": 2}) == 3, "parties' abstentions do not reduce the affirmative threshold")
	var old_nation: Dictionary = w.map.nations[3].duplicate(true)
	w.map.nations[3].id = "future_country"
	check(3 in u.members() and not u.permanent(3), "new identity automatically joins Assembly without receiving a veto")
	check(Data.region(w, 3) == "Unassigned" and not Data.nam(w, 3), "unknown identity is not assigned an invented region or alignment")
	w.map.nations[3].un_region = "Africa"
	check(Data.region(w, 3) == "Africa", "future country's explicit electoral region works")
	w.map.nations[3].un = "observer"
	check(not 3 in u.members() and not 3 in u.council(), "observer cannot vote or retain Council membership")
	w.map.nations[3].un = "member"
	w.map.nations[3].un_seat = "usa"
	check(u.council().size() == 3, "two representations of one P5 cannot duplicate a veto seat")
	w.map.nations[3].un_seat = "sixth_veto"
	check(not u.permanent(3), "metadata cannot create a sixth permanent seat")
	w.map.nations[3] = old_nation

	var invalid_count: int = u.queue.size()
	check(u.table("player", 999, -1, 0, "invalid", "economic").is_empty() and u.queue.size() == invalid_count, "invalid incident cannot enter the Council queue")
	check(u.draft("unknown", 3).contains("recognised"), "unknown resolution type is rejected")
	check(u.draft("ceasefire", 3, -1).contains("not at war"), "invalid second party is rejected before diplomacy indexing")
	var cf: Dictionary = u.table("player", 0, 1, 0, "their war", "ceasefire")
	u._open(cf)
	check(u.cast("yes").contains("open") and u.player_vote == "", "no vote during consultations")
	u._to_vote()
	check(u.cast("yes").contains("must abstain") and u.vote_of(0, cf) == "abstain", "player cannot bypass Article 27 by manually voting yes")
	check(u.cast("typo").contains("Vote yes") and u.player_vote == "", "invalid ballot cannot corrupt vote tally")
	u.current = null
	u.queue.clear()
	var dr: Dictionary = u.table("player", 3, -1, 0, "its conduct", "condemn")
	u._open(dr)
	w.economy.res.money = 100000.0
	var cash: float = w.economy.res.money
	check(u.lobby(999, 1).contains("Council") and w.economy.res.money == cash, "invalid lobby target cannot charge funds")
	check(u.amend("force").contains("No cause") and u.current.measure == "condemn", "amendment cannot bypass evidence requirements")
	u._to_vote()
	check(u.cast("no").contains("NO") and 0 in u.tally(dr, true).vetoes, "permanent player's negative ballot is a veto")
	check(u.cast("abstain").contains("ABSTAIN") and not 0 in u.tally(dr, true).vetoes, "permanent abstention is not a veto")
	var preview: Dictionary = u._with(dr, "targeted")
	check(u.vote_of(0, preview) == "abstain", "whip count does not reuse another draft's ballot")
	check(u.lobby(2, 1).contains("consultations") and w.economy.res.money == cash, "closed consultations cannot accept paid lobbying")
	w.game_time = float(dr.closes)
	check(u.cast("yes").contains("open"), "ballot at exact deadline is rejected")
	u.current = null
	u.queue.clear()

	# Independent Assembly ballots and voluntary national implementation.
	d.set_score(1, 3, -100.0)
	d.set_score(2, 3, -100.0)
	var vetoed := {"number": 4001, "kind": "wmd", "measure": "economic", "target": 3, "other": -1, "by": 1, "cause": "a chemical attack", "title": "Restrictions following an attack", "votes": {}, "lobby": {}, "player_choice": "no", "vetoed_by": [0], "result": "vetoed", "tally": {"yes": 2, "no": 1, "abstain": 1}}
	u.record.append(vetoed)
	u._assembly(vetoed)
	check(vetoed.assembly.result == "pending" and u.assembly_record.is_empty(), "veto opens a separate debate instead of instant Assembly sanctions")
	u._update_assembly()
	check(u.assembly_current != null and u.assembly_current.player_choice == "", "Assembly ballot starts independently of Council veto")
	check(u.cast_assembly("yes").contains("YES"), "player can vote differently in the Assembly")
	u.assembly_current.player_choice = "abstain"
	w.game_time = float(u.assembly_current.closes)
	u._update_assembly()
	check(u.assembly_record[-1].result == "adopted", "two affirmative votes versus one negative pass with abstention excluded")
	check(vetoed.assembly.result == "adopted", "Council record links to the subsequent Assembly outcome")
	check(not 0 in u.assembly_record[-1].participants, "Assembly passage never auto-enrols player in restrictions")
	check(u.join_voluntary(3, true).contains("join") and u.trade_blocked(0, 3, "oil"), "joining voluntary restrictions closes non-humanitarian bilateral trade")
	check(not u.trade_blocked(0, 3, "food"), "voluntary restrictions exempt food")
	u.join_voluntary(3, false)
	check(not u.trade_blocked(0, 3, "oil"), "leaving voluntary restrictions restores bilateral trade")
	check(u.cast_assembly("no").contains("No open"), "closed Assembly vote cannot be altered")

	# Sanctions renew, lift, and leave humanitarian access intact.
	u._apply_measure("economic", 0, 60.0)
	u._apply_measure("economic", 0, 120.0)
	check(w.power_effects.filter(func(e): return int(e.nation) == 0 and e.get("un", "") == "economic").size() == 1, "renewed sanctions do not compound identical income penalties")
	check(w.market.buy("oil", 1).contains("closed") and not w.market.buy("food", 1).contains("closed"), "market enforces food exemption through the real buy API")
	check(w.market.sell("oil", 1).contains("closed") and not w.market.sell("food", 1).contains("closed"), "real sell API also respects humanitarian exemption")
	check(u.trade_blocked(0, 1, "oil") and not u.trade_blocked(0, 1, "food"), "comprehensive restrictions apply to routes as well as instant exchange")
	u.join_voluntary(3, true)
	u._enforce({"measure": "lift", "target": 3, "other": -1, "votes": {}})
	check(not u.under(3, "embargo") and u.under(3, "voluntary"), "Council cannot repeal sovereign voluntary measures with its sanction-lifting resolution")
	w.game_time += 121.0
	check(not u.market_closed(0, "oil"), "sanctions end at their actual expiry")

	# Actual war continues until consent is delivered.
	d.declare_war(0, 1)
	u._enforce({"measure": "peacekeeping", "target": 0, "other": 1, "votes": {}})
	check(d.at_war(0, 1) and u.missions.is_empty(), "resolution does not end war or deploy unconsented peacekeepers")
	u.compliance[-1].responses[1] = false
	var case_id: int = int(u.compliance[-1].id)
	u.respond(case_id, true)
	check(d.at_war(0, 1) and u.missions.is_empty(), "one party's consent is insufficient")
	u.compliance[-1].responses[1] = true
	u._update_compliance()
	check(not d.at_war(0, 1) and u.missions.size() == 1, "both parties' consent creates a ceasefire and monitoring mandate")
	d.declare_war(1, 0)
	check(int(u.missions[0].breaker) == 1, "actual ceasefire breaker is recorded")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snapshot)
	u = w.un
	check(int(u.missions[0].breaker) == 1, "save/load retains violator identity")
	u.update(0.0)
	check(u.queue.any(func(q): return q.kind == "violation" and int(q.target) == 1), "violation investigation targets the aggressor after load")
	u._start_compliance({"measure": "ceasefire", "target": 0, "other": 1})
	u.compliance[-1].responses[1] = true
	case_id = int(u.compliance[-1].id)
	w.game_time = float(u.compliance[-1].until)
	check(u.respond(case_id, true).contains("No active"), "late compliance reply cannot revive an expired mandate")
	u._update_compliance()
	check(d.at_war(0, 1) and u.compliance.is_empty(), "failed Chapter VI consent does not force peace")
	check(u.mediate(1).contains("good offices") and u.compliance.size() == 1, "Secretary-General mediation is available without Council seat or vote")
	check(u.mediate(1).contains("already"), "duplicate mediation requests do not stack")

	# Relief has atomic costs/caps/cooldowns.
	w.economy.res.food = 0.0
	w.economy.res.money = 0.0
	u.aid_next = 0.0
	check(u.relief(0).contains("$250") and w.economy.res.food == 0.0, "unfunded relief does not award free food")
	w.economy.res.money = 10000.0
	check(u.relief(0).contains("reaches") and w.economy.res.food == minf(80.0, w.economy.caps.food), "humanitarian channel delivers actual food")
	cash = w.economy.res.money
	check(u.relief(0).contains("shipment") and w.economy.res.money == cash, "relief cooldown cannot double-charge or double-deliver")
	# Pending ballots, mediation, cases and cooldowns survive JSON save.
	u.next_draft = 0.0
	u.assembly_draft(1)
	u._assembly(vetoed)
	u._update_assembly()
	u.cast_assembly("no")
	u._seen["audit"] = w.game_time
	u._war_since["0-1"] = w.game_time - 123.0
	u._campaign[3] = 120.0
	snapshot = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snapshot)
	u = w.un
	check(u.assembly_current.player_choice == "no" and not u.assembly_queue.is_empty(), "pending Assembly ballot and queued debates survive whole-world JSON save")
	check(u.compliance.size() == 1 and bool(u.compliance[0].responses.get(1, false)), "pending consent survives JSON integer-key conversion")
	check(u._seen.has("audit") and u._war_since.has("0-1") and u._campaign.has(3), "incident deduplication, war clock and seat campaign survive save")
	check(u.aid_next > w.game_time, "relief cooldown survives save")
	# Future members can bring a crisis while outside Council.
	old_nation = w.map.nations[0].duplicate(true)
	w.map.nations[0].id = "future_player"
	u.elected.erase(0)
	u.next_draft = 0.0
	check(not 0 in u.council() and u.draft("condemn", 1).contains("tables"), "non-Council member can submit a crisis proposal")
	check(u.cast("yes").contains("Vote yes"), "submitting a proposal does not grant a Council ballot")
	w.map.nations[0] = old_nation
	# Elected seat rotation cannot silently re-elect a departing member.
	u.elected[3] = w.game_time
	u._elect()
	check(not u.elected.has(3) and 3 in u.just_left, "departing elected member cannot receive an immediate second term")
	# Build every real UI tab with the pending processes.
	w.hud.show()
	for tab in ["council", "draft", "assembly", "org", "record"]:
		w.hud.toggle_panel("un", true)
		w.hud._panels.un_tab = tab
		w.hud.refresh_side()
		check(w.hud._side_rows.get_child_count() >= 2, "UN interface tab: " + tab)
	test_scale()
	print("UN: %d passed, %d failed" % [passed, errors.size()])
	print("UN_CHECK PASS" if errors.is_empty() else "UN_CHECK FAIL")
	quit(0 if errors.is_empty() else 1)

func test_scale() -> void:
	var d: Node = w.diplomacy
	var old_nations: Array = w.map.nations.duplicate(true)
	var old_grids: Array = [d.score.duplicate(true), d.war.duplicate(true), d.alliance.duplicate(true), d.pact.duplicate(true), d.nap.duplicate(true)]
	var old_effects: Array = w.power_effects.duplicate(true)
	var old_n: int = d.n
	w.map.nations = []
	var p5 := ["usa", "china", "russia", "uk", "france"]
	var regions: Array = preload("res://scripts/un_data.gd").SEATS.keys()
	for i in range(35):
		w.map.nations.append({"id": p5[i] if i < 5 else "future_%d" % i, "name": "Country %02d" % i, "un_region": regions[i % regions.size()], "color": "#ffffff"})
	d.n = 35
	d.score = []
	d.war = []
	d.alliance = []
	d.pact = []
	d.nap = []
	for g in range(5):
		var grid: Array = [d.score, d.war, d.alliance, d.pact, d.nap][g]
		for i in range(35):
			var row := []
			row.resize(35)
			row.fill(0.0 if g == 0 else false)
			grid.append(row)
	var expanded = preload("res://scripts/un.gd").new(w)
	check(expanded.members().size() == 35, "Assembly automatically scales to 35 future members")
	check(expanded.council().size() == 15 and expanded.elected.size() == 10, "larger world retains five permanent and ten elected Council seats")
	check(expanded.needed({"measure": "condemn", "target": 30, "other": -1}) == 9, "full fifteen-member Council requires nine affirmative votes")
	var counts := {}
	for i in expanded.elected:
		var region: String = preload("res://scripts/un_data.gd").region(w, int(i))
		counts[region] = int(counts.get(region, 0)) + 1
	check(counts == preload("res://scripts/un_data.gd").SEATS, "full Council elected seats preserve geographic allocation")
	var old_time: float = w.game_time
	var departing: Array = expanded.elected.keys()
	w.game_time += expanded.TERM + 1.0
	expanded._elect()
	check(expanded.elected.size() == 10 and not expanded.elected.keys().any(func(i): return i in departing), "expanded membership permits rotation without immediate re-election")
	expanded.assessment = 300.0
	expanded._dues_history = [100.0, 300.0]
	expanded.arrears = 400.0
	check(expanded.lost_vote(), "Article 19 sums actual previous assessments rather than doubling latest income rate")
	w.game_time = old_time
	w.map.nations = old_nations
	d.n = old_n
	d.score = old_grids[0]
	d.war = old_grids[1]
	d.alliance = old_grids[2]
	d.pact = old_grids[3]
	d.nap = old_grids[4]
	w.power_effects = old_effects
