extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	seed(4817)
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(2000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	paused = true
	var e: Node = w.espionage
	var at = w.test_site("intelAgency", w.start)
	check(at != null, "agency site exists")
	if at == null:
		quit(1)
		return
	w.place_building("intelAgency", at, 0, true)
	w.economy.res.money = 100000.0
	e.recruit()
	e.recruit()
	e.network[1] = 75.0
	e.intel[1] = 75.0
	e._collect(1, false)
	var original: String = e.person(1, "president")
	var funds: float = w.economy.res.money
	check(e.run("assassinate", 1, "president", -1, 0.0).contains("authorized"), "leadership assignment accepted")
	check(not e.active(1, "president") and e.missions.size() == 1, "no instant effect")
	check(not e.run("assassinate", 1, "general").contains("authorized") and w.economy.res.money == funds-1400.0, "second agent cannot bypass target lock or spend money")
	e.advance(179.0)
	check(e.person(1, "president") == original, "incumbent unchanged during preparation")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(e.capture()))
	e.restore(saved)
	e.advance(1.0)
	check(e.active(1, "president") and e.person(1, "president") != original, "save resumes assignment once and records succession")
	var generation: int = e.succession[1].president
	e.advance(5.0)
	check(not e.run("assassinate", 1, "president").contains("authorized"), "five-second repeat rejected")
	e.advance(30.0)
	check(e.blocked_reason("assassinate", 1, "general").contains("window"), "changing role cannot bypass national lockdown")
	check(e.succession[1].president == generation, "assignment resolves exactly once")
	e.run("buildNetwork", 2, "", -1, 0.0)
	var a: int = e.missions[0].agent
	e.cancel_mission(a)
	e.advance(31.0)
	check(not e.run("buildNetwork", 2).contains("authorized"), "recall preserves cooldown")
	e._collect(1, false)
	var dossier: String = e.dossier_text(1)
	w.market.ai_nation(1).money += 90000.0
	check(e.dossier_text(1) == dossier, "report does not leak live treasury changes")
	e.advance(181.0)
	check(e.dossier_text(1).contains("STALE"), "dossier becomes stale")
	check(e.blocked_reason("armRebels", 2).contains("network") or e.blocked_reason("armRebels", 2).contains("intelligence"), "escalation requires access")
	e.network[2] = 70.0
	e.intel[2] = 70.0
	check(e.blocked_reason("armRebels", 2).contains("partner"), "rebels require a partner")
	e.run("proxyCell", 2, "", -1, 0.0)
	e.advance(120.0)
	check(e.proxies.has(2) and e.income_mult(2) < 1.0, "proxy has real target impact")
	funds = w.economy.res.money
	e.advance(10.0)
	check(w.economy.res.money <= funds-29.9, "proxy costs sponsor upkeep")
	var proxy_save: Dictionary = JSON.parse_string(JSON.stringify(e.capture()))
	e.restore(proxy_save)
	check(e.proxies.has(2), "proxy state survives JSON save")
	e.end_proxy(2)
	check(not e.proxies.has(2) and e.income_mult(2) == 1.0, "ending funding stops pressure")
	e.proxies[2] = {"strength":50.0,"autonomy":69.99,"until":e.clock+100.0}
	e.advance(1.0)
	check(not e.proxies.has(2) and e.scandal_until > e.clock, "autonomous proxy blowback affects sponsor")
	var relation: float = w.diplomacy.rel(0, 2)
	w.diplomacy.set_flag(w.diplomacy.pact, 0, 2, true)
	e._expose(2, "sabotage")
	check(w.diplomacy.rel(0, 2) <= relation and not w.diplomacy.pact[0][2], "attribution damages relations and trade")
	e.advance(700.0)
	check(not e.active(1, "president"), "leadership effects expire")
	check(not e.run("assassinate", -1, "president").contains("authorized"), "invalid nation rejected")
	var legacy: Dictionary = e.capture().duplicate(true)
	for key in ["missions","cooldowns","succession","proxies","stability"]: legacy.erase(key)
	e.restore(legacy)
	check(e.missions.is_empty() and e.proxies.is_empty(), "legacy save clears new transient state")
	e.network[2] = 70.0
	e.intel[2] = 70.0
	var snapshot: Dictionary = e.capture()
	e.network[2] = 0.0
	e.restore(snapshot)
	check(e.network[2] == 70.0, "in-memory saves own independent state")
	check(e.run("sabotage", 2, "", -1, 0.999).contains("authorized"), "failed operation still has preparation")
	e.advance(100.0)
	e.advance(31.0)
	check(e.cooldowns[2].sabotage > e.clock and not e.run("sabotage", 2).contains("authorized"), "failure cannot bypass cooldown")
	check(not e.reports.is_empty() and e.reports[0].text.contains("failed"), "failure filed as a report")
	print("ESPIONAGE_TEST ", "PASS" if errors.is_empty() else "FAIL")
	quit(0 if errors.is_empty() else 1)
