extends SceneTree
## Unconventional weapons (cbrn_data.gd, wmd.gd) and the United Nations
## (un_data.gd, un.gd): who has what, the new weapons and their effects, and
## the Council, its votes, vetoes and measures, the Assembly and the dues.
var errors: Array[String] = []
var passed := 0
var w: Node
var u
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func ground(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

## Runs the Council until the draft matching `pred` is before it (others are voted by default).
func reach(pred: Callable) -> bool:
	for i in range(40):
		u.update(0.0)
		if u.current == null:
			return false
		if pred.call(u.current):
			return true
		finish()
	return false

## Consultations, then the vote, then the result.
func finish() -> void:
	if u.current == null:
		return
	if u.current.phase == "consult":
		w.game_time = float(u.current.opens) + u.CONSULT_SECONDS + 0.1
		u.update(0.0)
	if u.current != null:
		w.game_time = float(u.current.closes) + 0.1
		u.update(0.0)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "style": "standard"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["wmd", "un", "defcon"])
	seed(11)
	var d: Node = w.diplomacy
	var ms: Node = w.missiles
	var W = w.wmd
	u = w.un
	var C := preload("res://scripts/cbrn_data.gd")
	var D := preload("res://scripts/un_data.gd")
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var ids := []
	for i in range(d.n): ids.append(C.ident(w, i))
	print("nations: ", ids)

	# ---- who has what (cbrn_data.gd)
	check(C.has(w, 0, "nuke") and C.has(w, 0, "mirv") and C.has(w, 0, "emp") and not C.has(w, 0, "chemical") and not C.has(w, 0, "riotAgent"), "the United States: nuclear, MIRV and microwave weapons; no chemical weapons")
	check(C.has(w, 1, "hydrogenBomb") and C.has(w, 1, "nuclearGlide") and not C.has(w, 1, "tsarBomba") and not C.has(w, 1, "chemical"), "China: thermonuclear and a nuclear glider; no Tsar Bomba, no chemical weapons")
	check(C.has(w, 2, "mirv") and C.has(w, 2, "neutronBomb") and C.has(w, 2, "hydrogenBomb"), "France (the European Union): MIRV, neutron and thermonuclear warheads")
	check(C.has(w, 3, "incapacitant") and not C.has(w, 3, "chemical") and not C.has(w, 3, "nuke"), "Iran: incapacitating agents only; no nerve agents, no bomb")
	check("north_korea" in C.ids_for("hydrogenBomb") and not "india" in C.ids_for("hydrogenBomb") and not "israel" in C.ids_for("hydrogenBomb"), "thermonuclear: North Korea likely (2017); India's claim disputed, Israel's unproven")
	check("india" in C.ids_for("mirv") and "pakistan" in C.ids_for("mirv") and not "north_korea" in C.ids_for("mirv"), "MIRV: India and Pakistan have tested; North Korea's is aspirational")
	check("egypt" in C.ids_for("chemical") and "north_korea" in C.ids_for("chemical") and not "iran" in C.ids_for("chemical"), "nerve agents: Egypt and North Korea (outside the CWC), not Iran")
	check(C.has(w, 0, "bunkerBuster") and C.has(w, 0, "nuclearCruise") and not C.has(w, 1, "bunkerBuster") and not C.has(w, 1, "nuclearCruise"), "the US: the B61-11/-13 bunker buster and the AGM-86B nuclear cruise missile; China neither")
	check(not C.has(w, 0, "chlorine") and C.has(w, 3, "chlorine") and not C.has(w, 1, "chlorine"), "chlorine: only a state already breaking the chemical ban (Iran), never the US or China")
	w.place_building("nuclearReactor", w.test_site("nuclearReactor", home + Vector3(-70, 0, 60)), 0, true)
	check(not C.has(w, 0, "dirtyBomb") and ms.locked("dirtyBomb").begins_with("Not fielded"), "the US, even with a reactor, builds no dirty bomb")
	var iran_hq: Dictionary = w.buildings.filter(func(b): return b.owner == 3 and b.key == "hq")[0]
	var no_reactor: bool = not C.has(w, 3, "dirtyBomb")
	w.place_building("nuclearReactor", w.test_site("nuclearReactor", iran_hq.root.position + Vector3(60, 0, -50)), 3, true)
	check(no_reactor and C.has(w, 3, "dirtyBomb"), "Iran, outside the norm, could with a reactor's material")
	var real_id = w.map.nations[3].get("id")
	w.map.nations[3].id = "turkiye"
	var apart: bool = C.has(w, 3, "tacticalNuke")
	d.set_flag(d.alliance, 0, 3, true)
	var shared: bool = C.has(w, 3, "tacticalNuke") and not C.has(w, 3, "nuke")
	d.set_flag(d.alliance, 0, 3, false)
	w.map.nations[3].id = real_id
	check(not apart and shared, "NATO nuclear sharing: Turkey may drop the US B61s at Incirlik only while allied with the US")
	check(ms.locked("riotAgent").begins_with("Not fielded") and ms.locked("tsarBomba").begins_with("Not fielded"), "another nation's weapon is locked as not fielded (and the silo hides it)")
	w.map.nations[2]["cbrn"] = ["chemical"]
	var future_ok: bool = C.has(w, 2, "chemical") and not C.has(w, 2, "mirv")
	w.map.nations[2].erase("cbrn")
	w.map.nations[2]["un_region"] = "Africa"
	var region_ok: bool = D.region(w, 2) == "Africa"
	w.map.nations[2].erase("un_region")
	check(future_ok and region_ok, "a nation added later declares its own weapons and UN group on its nation data")
	check(str(C.treaty(w, 0, "npt")) == "nws" and str(C.treaty(w, 3, "npt")) == "party" and bool(C.treaty(w, 2, "icc")) and not bool(C.treaty(w, 0, "icc")), "treaties: the US a weapon state outside the ICC, Iran an NPT party, France in the ICC")

	# ---- the new weapons
	var rival := 3
	var their_hq: Dictionary = w.buildings.filter(func(b): return b.owner == rival and b.key == "hq")[0]
	var before_zones: int = W.zones.size()
	var before_inc: int = W.incidents.size()
	ms.impact("mirv", their_hq.root.position + Vector3(40, 0, 40), 0)
	check(W.zones.size() - before_zones == 3 and W.incidents.size() - before_inc == 1, "a MIRV missile: three warheads, three fallout zones, one incident")
	check(float(preload("res://scripts/modern_warfare.gd").INTERCEPT.glide.abmLauncher) <= 0.1 and preload("res://scripts/modern_warfare.gd").CLASS_OF.nuclearGlide == "glide", "a nuclear glide vehicle: missile defence stops 10% at most")
	ms.stock["poseidon"] = 1
	w.defcon.posture[0] = 2
	var inland: String = ms.launch("poseidon", home + Vector3(0, 0, 10))
	for sub in w.units.filter(func(x): return x.owner == 0 and x.key == "nuclearSub" and not x.dead): w.kill(sub)
	var no_sub: String = ms.launch("poseidon", w.water_near(home, 200) if w.water_near(home, 200) != null else home)
	check((inland.contains("sea") or inland.contains("submarine")) and no_sub.contains("submarine") and int(ms.stock.poseidon) == 1, "Poseidon: only from a nuclear submarine, only at a coast (%s / %s)" % [inland, no_sub])
	var react: Dictionary = w.place_building("nuclearReactor", w.test_site("nuclearReactor", their_hq.root.position + Vector3(-50, 0, -40)), rival, true)
	react.last_by = 0
	var nz: int = W.zones.size()
	w.destroy_building(react)
	check(W.zones.size() == nz + 1 and W.incidents.any(func(i): return i.kind == "reactor" and int(i.by) == 0), "a reactor destroyed spreads its core, and the attack is laid at your door")
	var squad: Dictionary = w.spawn_unit("soldier", ground(home + Vector3(60, 0, -60)), 0)
	w.place_building("bunker", ground(home + Vector3(64, 0, -60)), 0, true)
	var tank_src: Dictionary = w.spawn_unit("tank", ground(home + Vector3(90, 0, -60)), 1)
	var sheltered: float = preload("res://scripts/bunker.gd").cover(w, squad, tank_src)
	ms.impact("riotAgent", squad.node.position, 1)
	var flushed: float = preload("res://scripts/bunker.gd").cover(w, squad, tank_src)
	check(sheltered < 1.0 and flushed == 1.0, "riot agents drive troops from their bunker (cover %.2f, then %.2f)" % [sheltered, flushed])
	var vault: Dictionary = w.place_building("bunker", ground(home + Vector3(140, 0, 140)), 1, true)
	var vault2: Dictionary = w.place_building("bunker", ground(home + Vector3(-140, 0, -140)), 1, true)
	for v in [vault, vault2]:
		v.max_hp = 200000.0   # (sturdy enough to measure the blow rather than be flattened by it)
		v.hp = 200000.0
	var v0: float = vault.hp
	var v1: float = vault2.hp
	ms.impact("bunkerBuster", vault.root.position + Vector3(6, 0, 0), 0)
	ms.impact("nuclearCruise", vault2.root.position + Vector3(6, 0, 0), 0)
	var hit_pen: float = v0 - vault.hp
	var hit_air: float = v1 - vault2.hp
	check(hit_pen > hit_air * 2.0, "an earth penetrator strikes a bunker far harder than a cruise missile's airburst (%d against %d)" % [int(hit_pen), int(hit_air)])
	var sleeper: Dictionary = w.spawn_unit("soldier", ground(home + Vector3(-90, 0, -90)), 0)
	ms.impact("incapacitant", sleeper.node.position, 3)
	w.game_time += 1.0
	W._tick = 1.0
	W.update(0.0)
	check(float(sleeper.get("disabled_until", 0.0)) > w.game_time, "an incapacitant puts infantry to sleep")
	ms.impact("anthrax", home + Vector3(-120, 0, 100), 1)
	var spores: Array = W.zones.filter(func(z): return z.kind == "anthrax")
	check(spores.size() == 1 and float(spores[0].until) - float(spores[0].born) >= 480.0, "anthrax spores hold the ground for 8 minutes")
	# Attribution: a chemical attack waits for the OPCW.
	var chem_by := 3
	var before_q: int = u.queue.filter(func(q): return int(q.target) == chem_by).size()
	ms.impact("incapacitant", their_hq.root.position + Vector3(-20, 0, 60), chem_by)
	var pending: Dictionary = W.incidents[-1]
	check(not pending.attributed and u.queue.filter(func(q): return int(q.target) == chem_by).size() == before_q, "a chemical attack is not blamed until the OPCW has investigated")
	w.game_time += W.INVESTIGATION + 1.0
	W._tick = 1.0
	W.update(0.0)
	check(pending.attributed and u.queue.filter(func(q): return int(q.target) == chem_by).size() > before_q, "60 s later it is attributed and goes to the Council")
	# Breakout.
	W.break_out(3)
	check(w.defcon.nuclear(3) and C.has(w, 3, "nuke") and "saudi" in w.map.research.discoveries.nuclearBreakout.nation, "Iran breaks out: it has the bomb, and Saudi Arabia may follow")
	check(u.queue.any(func(q): return q.kind == "breakout" and int(q.target) == 3), "the IAEA sends it to the Council")
	check(w.space.orbital_nuke_blocked().contains("Russia"), "only Russia can detonate a nuclear weapon in orbit")
	w.space.sats[1].recon = 10
	W.orbital_burst(1)
	check(w.space.count(1, "recon") <= 6, "one such burst wipes out most satellites (%d of 10 left)" % w.space.count(1, "recon"))

	# ---- the United Nations
	check(D.SEATS.values().reduce(func(a, b): return a + b, 0) == 10, "ten elected seats by region: 3 African, 2 Asia-Pacific, 2 Latin American, 2 Western, 1 Eastern European")
	check(u.permanent(0) and u.permanent(1) and u.permanent(2) and not u.permanent(3), "the United States, China and France (the EU) hold permanent seats")
	check(u.council().size() == 4 and u.elected.has(3), "Iran is elected to the Council's one elected seat here")
	check(u.under(3, "embargo") and u.production_mult(3) < 1.0 and u.record.any(func(r): return r.result == "in force" and int(r.target) == 3), "the snapback sanctions on Iran are in force from the start")
	var pres: int = u.president
	w.game_time = u.presidency_ends + 0.1
	u.update(0.0)
	check(pres >= 0 and u.president != pres, "the presidency rotates")
	# A shielded target: the penholder forces a vote, China vetoes, the Assembly meets.
	u.queue.clear()
	u.current = null
	var dr: Dictionary = u.table("wmd", 3, -1, 2, "its use of chemical weapons")
	check(dr.measure == "economic" and not u.tally(dr, true).vetoes.is_empty(), "China shields Iran: no measure would pass, so the sponsor forces the vote on sanctions")
	reach(func(x): return x == dr)
	finish()
	check(u.record[-1].result == "vetoed" and 1 in u.record[-1].get("vetoed_by", []) and u.record[-1].has("assembly"), "China vetoes; the General Assembly meets (%s)" % str(u.record[-1].get("assembly", {})))
	# Art. 27(3): parties abstain on a ceasefire.
	d.declare_war(1, 2)
	var cf: Dictionary = u.table("player", 1, 2, 0, "their war", "ceasefire")
	check(u.vote_of(1, cf) == "abstain" and u.vote_of(2, cf) == "abstain", "on a ceasefire the parties abstain (Art. 27(3)): no veto")
	reach(func(x): return x == cf)
	u.cast("yes")
	finish()
	check(u.record[-1].result == "adopted" and not d.at_war(1, 2), "the ceasefire passes and the war ends (%s)" % u.record[-1].result)
	# Your draft: consultations, amendments, lobbying.
	u.next_draft = 0.0
	for i in range(d.n):
		if i != 3: d.set_score(i, 3, -60.0)
	var why_none: String = u.draft_blocked("economic", 2)
	var mine: String = u.draft("economic", 3)
	check(why_none.contains("No cause") and mine.contains("tables"), "you may sanction only with a cause on record")
	reach(func(x): return int(x.by) == 0)
	check(u.amend("targeted").contains("Targeted") and u.current.measure == "targeted", "in consultations you may amend your draft")
	var lean0: String = u.vote_of(2, u.current)
	w.economy.res.money = 100000.0
	u.lobby(2, -1)
	var lean1: String = u.vote_of(2, u.current)
	check(lean0 != lean1, "lobbying moves a member's vote (%s to %s)" % [lean0, lean1])
	u.lobby(2, 1)
	u.cast("yes")
	finish()
	check(u.record[-1].measure == "targeted", "the draft is voted as amended (%s)" % u.record[-1].result)
	# A statement needs consensus.
	var st: Dictionary = u.table("war", 1, 2, -1, "their war", "statement")
	reach(func(x): return x == st)
	u.cast("no")
	finish()
	check(u.record[-1].result == "failed", "one objection sinks a presidential statement")
	# Sanctions bite: the market, production.
	u._apply_measure("economic", 0, 60.0)
	check(w.market.buy("oil", 1).contains("closed"), "comprehensive sanctions shut the world market to you")
	u._apply_measure("embargo", 0, 60.0)
	check(is_equal_approx(u.production_mult(0), 0.6), "an arms embargo slows military production by 40%")
	# Force, the ICC, peacekeepers.
	u._enforce({"measure": "force", "target": 3, "other": -1, "votes": {}})
	u._seen.clear()
	d.make_peace(0, 3)
	var q0: int = u.queue.filter(func(q): return q.kind == "aggression").size()
	d.declare_war(0, 3)
	check(u.authorised.has(3) and u.queue.filter(func(q): return q.kind == "aggression").size() == q0, "force authorised: joining the war on Iran is no aggression")
	u._enforce({"measure": "icc", "target": 3, "other": -1, "votes": {}})
	check(u.indicted.has(3), "an ICC referral indicts Iran's leaders")
	d.make_peace(1, 2)
	u._enforce({"measure": "peacekeeping", "target": 1, "other": 2, "votes": {}})
	d.declare_war(1, 2)
	u.update(0.0)
	check(u.queue.any(func(q): return q.kind == "violation" and int(q.target) == 1), "a ceasefire broken under the peacekeepers' eyes goes back to the Council")
	# Art. 99.
	d.declare_war(2, 3)
	u.update(0.0)
	w.game_time += u.ART99_AFTER + 1.0
	u.update(0.0)
	check(u.queue.any(func(q): return q.kind == "war"), "the Secretary-General brings a long war to the Council (Art. 99)")
	# Dues.
	u.withhold = true
	for i in range(3):
		u.next_dues = 0.0
		u._dues()
	check(u.lost_vote(), "two years of withheld dues: no vote in the Assembly (Art. 19)")
	u.withhold = false
	check(u.pay_arrears().contains("paid") and not u.lost_vote(), "paying the arrears restores it")
	# Elections.
	w.game_time = u.term_ends + 0.1
	u.update(0.0)
	check(u.council().size() >= 3 and u.term_ends > w.game_time, "the Assembly holds the elections on time")
	# Saving.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(snap)
	check(w.un.record.size() == u.record.size() and w.un.under(3, "embargo") and w.un.indicted.has(3), "a save keeps the record, the sanctions and the indictments")
	check(w.wmd.broken_out.has(3) and w.wmd.zones.size() == W.zones.size(), "and the breakout and the poisoned ground")
	u = w.un
	# The window.
	w.hud.show()
	for tab in ["council", "draft", "assembly", "org", "record"]:
		w.hud.toggle_panel("un", true)
		w.hud._panels.un_tab = tab
		w.hud.refresh_side()
		check(w.hud._side_rows.get_child_count() >= 2, "the UN window's %s tab" % tab)
	print("\nWMD_UN: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("WMD_UN PASS" if errors.is_empty() else "WMD_UN FAIL")
	quit(0 if errors.is_empty() else 1)
