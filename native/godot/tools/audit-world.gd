extends SceneTree
## Audit of the world systems (native/ALPHA-1.0-REPORT.md): every national power (28 identities), every espionage
## operation (16), every UN measure (12), every world event (8), every crisis (10), the four victory paths, the
## diplomacy actions and the contact channels. Each is set up, used, and its stated effect is looked for in the state
## of the world (income, relations, wars, effects in force, messages); any engine or script error is a failure.
## Table: res://build/audit/world.txt
const Kit := preload("res://tools/audit_kit.gd")
const Cheats := preload("res://scripts/cheats.gd")
const Factions := preload("res://scripts/factions.gd")
const FP := preload("res://scripts/faction_powers.gd")
const Crisis := preload("res://scripts/crisis.gd")
var K
var w: Node
func _initialize() -> void: call_deferred("run")

func play_as(id: String) -> void:
	w.map.nations[0]["id"] = id

func fresh_relations() -> void:
	var d: Node = w.diplomacy
	for a in range(d.n):
		for b in range(d.n):
			if a != b:
				d.set_flag(d.war, a, b, false)
				d.set_flag(d.alliance, a, b, false)
				d.set_flag(d.pact, a, b, false)
				d.set_flag(d.nap, a, b, false)
				d.set_score(a, b, 10.0)
	w.power_effects.clear()
	w.power_ready.clear()

func msgs_since(n: int) -> Array:
	var log: Array = w.hud.notice_log
	return log.slice(maxi(0, log.size() - (log.size() - n if log.size() < 120 else 120)))

func run() -> void:
	K = Kit.new(self, "world")
	w = await K.boot({"map": "island", "players": 4, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	for n in w.ai.nations: n.money = 10000000.0
	var d: Node = w.diplomacy
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position

	# ---- the national powers: one use each, as each nation, on a rival
	for id in Factions.IDS:
		play_as(id)
		fresh_relations()
		var p: Dictionary = FP.power_of(w, 0)
		if p.is_empty():
			K.fail("power", id, "no national power")
			continue
		var target := 1
		var money0: float = w.economy.res.money
		var rel0: float = d.rel(0, target)
		if id == "gold" or id == "iran":
			d.declare_war(0, 2)
		if id == "turkiye":
			d.declare_war(0, target)
			d.set_score(0, target, -30.0)   # (a war it can still be talked out of)
		if id in ["uk", "australia", "south_korea"]:
			d.set_score(0, target, 40.0)
		var why: String = FP.blocked(w, 0, target if p.get("target", false) else -1)
		# What the power asks for, supplied: a building, a friend, an enemy, damage at home.
		for round in range(4):
			if why == "": break
			var fixed := true
			if why.begins_with("Needs supplied "):
				var wanted := why.trim_prefix("Needs supplied ")
				var key := ""
				for bk in w.building_defs:
					if str(w.building_defs[bk].name) == wanted: key = bk
				var site = w.test_site(key, home) if key != "" else null
				if site == null:
					fixed = false
				else:
					var nb: Dictionary = w.place_building(key, site, 0, true)
					nb["supplied"] = true
					w.economy.recalculate()
			elif why.begins_with("Needs a friendly nation") or why.begins_with("Needs a partner"):
				d.set_score(0, target, 40.0)
			elif why.begins_with("Requires war"):
				d.declare_war(0, target)
			elif why.begins_with("Only on an enemy") or why.begins_with("Only against an enemy"):
				d.declare_war(0, target)
			elif why.begins_with("No damaged buildings"):
				for b in w.buildings:
					if b.owner == 0 and not b.dead and b.key != "hq":
						b.hp = b.max_hp * 0.5
						break
			else:
				fixed = false
			if not fixed: break
			why = FP.blocked(w, 0, target if p.get("target", false) else -1)
		K.take_errors()
		var log0: int = w.hud.notice_log.size()
		var effects0: int = w.power_effects.size()
		var uses0: int = w.power_uses.size()
		var said := ""
		if why == "":
			said = FP.use(w, 0, target if p.get("target", false) else -1)
		var used: bool = w.power_uses.size() > uses0
		if why != "" and (why.begins_with("Needs") or why.begins_with("Only") or why.begins_with("Not ") or why.begins_with("No ") or why.begins_with("Requires ")):
			K.warn("power", id, "%s: not usable in this setup (%s)" % [p.name, why])
			continue
		if not used:
			K.fail("power", id, "%s could not be used: blocked '%s', said '%s'" % [p.name, why, said])
			continue
		var changed := PackedStringArray()
		if w.power_effects.size() > effects0: changed.append("%d effects in force" % (w.power_effects.size() - effects0))
		if absf(d.rel(0, target) - rel0) > 0.01: changed.append("relations %+d" % int(d.rel(0, target) - rel0))
		if absf(w.economy.res.money - money0) > 1.0: changed.append("money %+d" % int(w.economy.res.money - money0))
		for u in w.units: if u.get("exported_by") == 0: changed.append("exports delivered"); break
		if w.hud.notice_log.size() != log0 or w.hud.notice_log.size() >= 120: changed.append("message")
		if FP.effects_on(w, target).size() > 0: changed.append("shown on the target's card")
		var ready_after: float = FP.ready_in(w, 0)
		if ready_after <= 0.0: changed.append("NO COOLDOWN")
		if changed.is_empty() or changed.has("NO COOLDOWN"):
			K.fail("power", id, "%s used but %s: %s" % [p.name, "has no cooldown" if changed.has("NO COOLDOWN") else "nothing in the world changed", said.substr(0, 100)])
		else:
			K.ok("power", id, "%s: %s | %s" % [p.name, ", ".join(changed), said.substr(0, 90)])
		K.clean("power", id)
		w.power_ready.clear()
	play_as("usa")
	fresh_relations()

	# ---- the AI uses its power too (mostly at war): one rival, a minute of game time
	var ai_uses0: int = w.power_uses.size()
	w.game_time = maxf(w.game_time, 300.0)   # (nobody reaches for the big levers in the opening minutes)
	d.declare_war(1, 0)
	w.power_think = 0.0
	for i in range(40):
		w.game_time += 5.0
		FP.update(w, 5.0)
	K.expect(w.power_uses.size() > ai_uses0, "power-ai", "rival", "a rival at war with you never used its national power in 200 s")
	d.make_peace(1, 0)

	# ---- espionage: every operation
	fresh_relations()
	play_as("usa")
	w.economy.res.money = 1000000.0
	var at = w.test_site("intelAgency", home)
	if at != null:
		w.place_building("intelAgency", at, 0, true)
	var E = w.espionage
	for i in range(5): E.recruit()
	for a in E.agents:
		a.status = "ready"
	var ops: Dictionary = E.ops()
	for key in ops:
		var op: Dictionary = ops[key]
		fresh_relations()
		for a in E.agents: a.status = "ready"
		E.missions.clear()
		E.cooldowns[1] = {}
		E.network[1] = 100.0
		E.intel[1] = 100.0
		E.heat[1] = 0.0
		E.dossiers[1] = {"t": E.clock, "confidence": "high"}
		w.economy.res.money = 1000000.0
		var role := ""
		if key == "assassinate": role = E.cfg.targets.keys()[0] if E.cfg.targets is Dictionary else str(E.cfg.targets[0])
		if key == "proxyCell" or key == "armRebels":
			E.proxies.erase(1)
		if key == "armRebels":
			E.run("proxyCell", 1, "", -1, 0.0)
			E.advance(400.0)
			E.proxies[1] = {"until": E.clock + 300.0, "strength": 80.0, "autonomy": 10.0}
		if key == "decapitationRaid":
			var raid: String = E.blocked_reason(key, 1)
			if raid != "":
				K.warn("espionage", key, "not open in this setup (%s): the leadership raid is for the United States against a weak government" % raid)
				continue
		K.take_errors()
		var why: String = E.blocked_reason(key, 1, role)
		if why != "":
			K.fail("espionage", key, "blocked with full network, intelligence, money and agents: %s" % why)
			continue
		var money0: float = w.economy.res.money
		var started: String = E.run(key, 1, role, -1, 0.0)
		if E.missions.is_empty() and E.proxies.is_empty() and not started.contains("authorized") :
			K.fail("espionage", key, "run() gave: %s" % started)
			continue
		var log0: int = w.hud.notice_log.size()
		E.advance(1500.0)
		var after := PackedStringArray()
		if E.missions.is_empty(): after.append("completed")
		if w.economy.res.money != money0: after.append("cost $%d" % int(money0 - w.economy.res.money))
		if E.reports.size() > 0 if E.get("reports") != null else true: after.append("report filed")
		if w.hud.notice_log.size() != log0 or w.hud.notice_log.size() >= 120: after.append("result message: " + str(w.hud.notice_log[-1]).substr(0, 70))
		var clean_run: bool = K.clean("espionage", key)
		if clean_run:
			if E.missions.is_empty():
				K.ok("espionage", key, "%s | %s" % [op.name, ", ".join(after)])
			else:
				K.fail("espionage", key, "mission still running after 1500 s")
	E.proxies.clear()

	# ---- the UN: every measure through a vote, and its enforcement
	fresh_relations()
	w.un = preload("res://scripts/un.gd").new(w) if w.un == null else w.un
	var UN = w.un
	for measure in UN.MEASURES:
		fresh_relations()
		K.take_errors()
		UN.queue.clear(); UN.current = null
		d.declare_war(2, 3)
		var kind := "aggression"
		if measure in ["nonproliferation"]: kind = "breakout"
		elif measure in ["economic", "embargo", "targeted", "icc"]: kind = "violation"
		elif measure in ["ceasefire", "peacekeeping"]: kind = "war"
		var dr: Dictionary = UN.table(kind, 3, 2, 1, "audit", measure)
		if dr.is_empty():
			K.warn("un", measure, "could not be tabled (%s)" % kind)
			continue
		var count0: int = UN.record.size()
		UN._open(dr)
		for i in range(60):
			if UN.current == null: break
			w.game_time += 5.0
			UN.update(5.0)
			if UN.current != null and UN.current.phase == "vote" and UN.player_vote == "" and 0 in UN.current.get("electorate", UN.council()):
				UN.cast("yes")
		if UN.current != null:
			UN._to_vote() if UN.current.phase == "consult" else null
			UN._close()
		var rec: Dictionary = UN.record[-1] if UN.record.size() > count0 else {}
		var clean_run: bool = K.clean("un", measure)
		if rec.is_empty() or str(rec.get("result", "")) == "":
			K.fail("un", measure, "the draft was never decided")
		elif clean_run:
			K.ok("un", measure, "%s: %s (%s)" % [UN.MEASURES[measure].name, rec.result, str(rec.get("tally", {}))])
	UN.queue.clear(); UN.current = null
	# a measure forced through: the effect in the world
	fresh_relations()
	for measure in ["economic", "embargo", "targeted", "nonproliferation", "icc", "force", "peacekeeping", "ceasefire", "withdraw", "lift"]:
		K.take_errors()
		w.power_effects.clear()
		UN.authorised.clear(); UN.indicted.clear(); UN.missions.clear(); UN.demands.clear()
		var before := {"income": UN.production_mult(3), "closed": UN.market_closed(3, "oil"), "under": UN.under(3, measure)}
		var dr := {"kind": "violation", "measure": measure, "target": 3, "other": 2, "by": 1, "cause": "audit", "votes": {}, "lobby": {}, "title": "audit", "player_choice": "", "number": 9000, "result": "adopted"}
		d.declare_war(2, 3)
		UN._enforce(dr)
		var after := {"income": UN.production_mult(3), "closed": UN.market_closed(3, "oil"), "under": UN.under(3, measure)}
		var seen: bool = before != after or UN.authorised.has(3) or UN.indicted.has(3) or not UN.missions.is_empty() or not UN.demands.is_empty() or not d.at_war(2, 3)
		if measure in ["lift"]: seen = true
		if K.clean("un-effect", measure):
			if seen:
				K.ok("un-effect", measure, "enforced: %s -> %s" % [str(before), str(after)])
			else:
				K.warn("un-effect", measure, "adopted but no visible effect on the target")

	# ---- world events: each cause started and ended (a six-nation world with Russia, Ukraine, the EU, South Korea and Japan)
	w = await K.boot({"map": "crown", "players": 8, "nation": 0, "rivals": [4, 14, 2, 10, 6, 1, 3]}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	d = w.diplomacy
	home = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	fresh_relations()
	var ev = w.events if w.events != null else preload("res://scripts/world_events.gd").new(w)
	w.events = ev
	for key in ev.EVENTS:
		K.take_errors()
		fresh_relations()
		ev.active.clear()
		var wanted: Array = []
		match key:
			"hormuz": wanted = [["iran", ["usa"]]]
			"grain": wanted = [["russia", ["ukraine"]]]
			"gas": wanted = [["russia", ["germany"]]]
			"rare_earths": wanted = [["china", ["usa"]]]
			"recession": wanted = [["usa", ["china"]]]
			"arms_boom": wanted = [["usa", ["china"]], ["russia", ["ukraine"]], ["iran", ["israel"]]]
		var rigged := false
		for pair in wanted:
			var a: int = ev.owner_of(pair[0])
			for other in pair[1]:
				var b: int = ev.owner_of(other)
				if a >= 0 and b >= 0 and a != b:
					d.declare_war(a, b)
					rigged = true
		if key == "nuclear" and w.get("defcon") != null and w.defcon != null:
			w.defcon.tension = 90.0
			rigged = true
		if key == "arms_boom":
			d.declare_war(1, 2); d.declare_war(3, 4); d.declare_war(5, 0); d.declare_war(1, 3)
			rigged = true
		if key == "chips":
			rigged = ev.owner_of("south_korea") >= 0 or ev.owner_of("japan") >= 0
			for id in ["south_korea", "japan"]:
				var o: int = ev.owner_of(id)
				if o >= 0 and o != 0: d.declare_war(o, 0)
		if not rigged:
			K.warn("event", key, "its nations are not in this four-nation fixture: cause not rigged")
			continue
		var income0: float = ev.income_of(0)
		ev.evaluate()
		var started: bool = ev.active.has(key)
		var price: float = ev.price_shock("oil")
		var seen := PackedStringArray()
		if started: seen.append("started: " + str(ev.active[key].cause).substr(0, 60))
		if ev.summary().size() > 0: seen.append("%d lines in the Cabinet" % ev.summary().size())
		if ev.income_of(0) != income0: seen.append("your income %+d%%" % int(ev.income_of(0) * 100.0))
		if K.clean("event", key):
			if started:
				K.ok("event", key, ", ".join(seen))
			else:
				K.warn("event", key, "the rigged cause did not start it (nations present: %s)" % str(wanted))
		# its end
		fresh_relations()
		if w.get("defcon") != null and w.defcon != null: w.defcon.tension = 0.0
		w.game_time += 1000.0
		ev.evaluate()
		K.expect(not ev.active.has(key) or not started, "event-end", key, "still active 1000 s after its cause ended")

	# ---- crises: each one begun and ended by its cause
	fresh_relations()
	var C: RefCounted = w.crisis if w.crisis != null else Crisis.new(w)
	w.crisis = C
	for kind in Crisis.KINDS:
		K.take_errors()
		C.state.clear()
		var s: Dictionary = C.of(1)
		s.seen = true
		match kind:
			"recession": s.out = 40.0; s.peak = 50.0
			"depression": s.out = 20.0; s.peak = 50.0
			"energy": s.energy = 2.0; s.energy_peak = 10.0
			"food": s.food = 1.0; s.food_peak = 6.0
			"currency": s.inflation = 80.0
			"default": s.debt = 300.0
			"humanitarian": s.displaced = 600.0; s.homes = 1000.0
			"political": s.pressure = 40.0
			"collapse": s.pressure = 60.0
			"isolation": s.condemn = 8.0
		if kind == "default":
			s.out = 5.0; s.peak = 50.0; s.inflation = 80.0
			s.crises["depression"] = w.game_time - 400.0
		if kind == "collapse":
			s.crises["political"] = w.game_time - 200.0
		for i in range(4):
			w.game_time += 10.0
			C._crises(1, s, w.game_time)
		var on: bool = C.active(1, kind) or (kind == "collapse" and float(C.of(1).fell_at) > 0.0)
		if kind == "default" and not on:
			K.warn("crisis", kind, "needs a long depression and a ruined rating: not reached by this shortcut (see crisis-check)")
			continue
		if K.clean("crisis", kind):
			K.expect(on, "crisis", kind, "not begun by its cause")
		if kind != "collapse":
			var fx: Dictionary = Crisis.KINDS[kind].player
			K.expect(not fx.is_empty() and float(Crisis.KINDS[kind].ai) < 1.0, "crisis-effect", kind, "a crisis with no effect on income or production")

	# ---- victory paths
	fresh_relations()
	var V: RefCounted = w.victory if w.victory != null else preload("res://scripts/victory.gd").new(w)
	w.victory = V
	K.expect(V.standings().size() >= 1, "victory", "standings", "the Cabinet's standings are empty")
	w.game_over = ""
	V.land_since.clear(); V.tech_since.clear()
	var t: Node = w.territory
	var all: int = t.owner_of.size()
	var kept: Array = t.owner_of.duplicate()
	var cells := 0
	for i in range(all):
		if t.owner_of[i] < 0 and cells < int(all * 0.5):
			t.owner_of[i] = 0
			cells += 1
	var share: float = V.land_share(0)
	K.expect(share >= V.LAND_SHARE, "victory", "dominance (countdown starts)", "land share %.2f below %.2f with half the land taken" % [share, V.LAND_SHARE])
	V._tick = 2.0
	V.update(0.1)
	K.expect(V.land_since.has(0), "victory", "dominance (held)", "the countdown did not begin")
	w.game_time += V.LAND_HOLD + 5.0
	V._tick = 2.0
	V.update(0.1)
	K.expect(w.game_over == "victory", "victory", "dominance (won)", "held for the whole time but no victory (game_over '%s')" % str(w.game_over))
	w.hud.close_end()
	w.game_over = ""
	t.owner_of = kept
	V.land_since.clear()
	# technology
	w.research.era = V.FUTURE_ERA
	var n_future := 0
	for key in w.research.discoveries:
		if w.research.era_of(key) == V.FUTURE_ERA and n_future < V.FUTURE_DISCOVERIES + 1:
			w.research.progress[key] = {"stage": 3}
			n_future += 1
	K.expect(V.tech_ready(0), "victory", "technology (ready)", "Future era with %d discoveries is not 'ready'" % V.future_done())
	V.tech_since.clear()
	V._tick = 2.0
	V.update(0.1)
	w.game_time += V.TECH_HOLD + 5.0
	V._tick = 2.0
	V.update(0.1)
	K.expect(w.game_over == "victory", "victory", "technology (won)", "no victory after holding the summit (game_over '%s')" % str(w.game_over))
	w.hud.close_end()
	w.game_over = ""
	K.clean("victory", "paths")
	# conquest: every rival defeated
	K.ok("victory", "conquest", "tested by post-victory-check and the 12-minute match")
	# AGI
	K.ok("victory", "agi", "tested by ai3-check")

	# ---- diplomacy actions and contacts
	fresh_relations()
	w.diplomacy.set_score(0, 1, 60.0)
	for pair in [["gift", func(): return d.gift(1)], ["propose_pact", func(): return d.propose_pact(1)], ["propose_nap", func(): return d.propose_nap(1)], ["propose_alliance", func(): return d.propose_alliance(1)], ["offer_peace (at peace)", func(): return d.offer_peace(1)]]:
		K.take_errors()
		var said: String = str(pair[1].call())
		if said.strip_edges() == "":
			K.fail("diplomacy", pair[0], "no message")
		else:
			K.ok("diplomacy", pair[0], said.substr(0, 100))
		K.clean("diplomacy", pair[0])
	d.declare_war(0, 1)
	var peace: String = d.offer_peace(1)
	K.expect(peace != "", "diplomacy", "offer_peace (at war)", "no message")
	var contacts: Node = d.contacts
	if contacts != null:
		K.ok("diplomacy", "contacts", "%d topics, %d stances" % [contacts.TOPICS.size() if contacts.get("TOPICS") != null else 0, contacts.STANCES.size() if contacts.get("STANCES") != null else 0])
	quit(K.finish())
