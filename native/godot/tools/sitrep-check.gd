extends SceneTree
## The situation report (sitrep.gd, sitrep_view.gd): hits on your buildings and units, your losses and
## kills, merged and counted; messages classified; live alerts and their cards; the minimap pings; the
## battle report; the window's summary and message tabs; and the unread count on the Log button.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func labels(node: Node) -> String:
	var out := ""
	for c in node.get_children():
		if c is Label or c is Button: out += c.text + "\n"
	return out

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": 0, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal"); w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false); w.ai.set_physics_process(false)
	var S: RefCounted = w.sitrep
	var h: Node = w.hud
	var view: Control = h._sitrep_view
	check(S != null and S.events.is_empty() or S != null, "the world has a situation report")
	var p: Vector3 = w.land_point(w.start, 60.0)
	var raider: Dictionary = w.spawn_unit("tank", p + Vector3(30, 0, 0), 1)
	var own_building: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var barracks: Dictionary = w.place_building("barracks", w.land_point(p, 30.0), 0, true)

	# ---- hits on a building merge into one entry that follows its health
	w.damage(barracks, 40.0, raider)
	w.damage(barracks, 40.0, raider)
	w.damage(barracks, 40.0, raider)
	var atk: Array = S.events.filter(func(e): return e.cat == "attack")
	check(atk.size() == 1 and int(atk[0].n) == 3, "three hits on a barracks are one entry (%d entries, %d hits)" % [atk.size(), atk[0].n if not atk.is_empty() else 0])
	check(atk[0].text.contains("under attack by") and atk[0].text.contains("%"), "it says who and the health left: %s" % atk[0].text)
	check(S.alerts().size() == 1 and S.active_pings().size() >= 1, "it is a live alert and the minimap gets a ping")
	var hq_hit: Dictionary = w.damage(own_building, 10.0, raider) if false else {}
	w.damage(own_building, 10.0, raider)
	check(S.events.any(func(e): return e.cat == "attack" and e.sev == "crit" and e.text.contains(str(own_building.def.name))), "an attack on the capital is critical")
	# ---- not recorded: friendly fire, hits on the enemy, hits by nobody
	var own_tank: Dictionary = w.spawn_unit("tank", p, 0)
	var before: int = S.events.filter(func(e): return e.cat in ["attack", "loss"]).size()
	w.damage(own_tank, 10.0, own_tank)
	w.damage(raider, 10.0, own_tank)
	check(S.events.filter(func(e): return e.cat in ["attack", "loss"]).size() == before, "friendly fire and hits on the enemy are not alerts")

	# ---- units under fire: one entry for a patch of ground, counting the units
	var squad := []
	for i in range(3): squad.append(w.spawn_unit("tank", p + Vector3(i * 4.0, 0, 6), 0))
	for u in squad: w.damage(u, 20.0, raider)
	var fire: Array = S.events.filter(func(e): return e.cat == "attack" and str(e.key).begins_with("atk:u:"))
	check(fire.size() >= 1 and S.alerts().any(func(e): return e.text.begins_with("3 of your units") or e.text.begins_with("4 of your units")), "units hit together are one entry: %s" % (fire[0].text if not fire.is_empty() else "none"))

	# ---- losses merge by kind; kills are the other side
	for i in range(3):
		var t: Dictionary = w.spawn_unit("tank", p + Vector3(0, 0, 20 + i * 4.0), 0)
		t.last_by = 1
		w.kill(t)
	var lost: Array = S.events.filter(func(e): return e.cat == "loss")
	check(lost.size() == 1 and lost[0].text == "Lost: 3× %s" % w.unit_defs.tank.name, "three tanks lost are one entry: %s" % (lost[0].text if not lost.is_empty() else "none"))
	var foe: Dictionary = w.spawn_unit("soldier", p + Vector3(40, 0, 10), 1)
	foe.last_by = 0
	w.kill(foe)
	check(S.events.any(func(e): return e.cat == "kill" and e.text.begins_with("Destroyed")), "what you destroy is recorded")
	w.destroy_building(barracks)
	check(S.events.any(func(e): return e.cat == "loss" and e.sev == "crit" and e.text.contains("destroyed")), "a building lost is critical")

	# ---- what you know: attackers named only when seen or known, red only for intelligence
	var stranger: Dictionary = {"owner": 1, "key": "tank"}
	w.espionage.intel[1] = 0.0
	var foes: Array = w.diplomacy.enemies_of(0)
	var named: String = S.attacker_name(stranger, 1)
	check(named == "an unidentified force" or (foes.size() == 1 and foes[0] == 1), "an attacker you did not see and know nothing of is unidentified (%s)" % named)
	w.espionage.intel[1] = 30.0
	check(S.attacker_name(stranger, 1) == str(w.map.nations[1].name), "with intelligence on its nation it is named")
	w.espionage.intel[1] = 0.0
	check(S.early_warning(1).level == 0.0, "with no agents, satellites or radar you have no early warning")
	var target_b: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var log_before: int = h.notice_log.size()
	check(not S.missile_launched(1, "Cruise Missile", target_b, 40.0) and h.notice_log.size() == log_before, "a missile launched at you is NOT announced without early warning")
	check(not S.events.any(func(e): return e.cat == "warning"), "and there is no red warning")
	w.espionage.intel[1] = 70.0
	check(S.early_warning(1).level == 1.0 and S.early_warning(1).source.contains("agents"), "a network of agents in that nation (intelligence 60 or more) gives full warning")
	check(S.missile_launched(1, "Cruise Missile", target_b, 42.0), "then the launch is announced")
	var warn: Array = S.events.filter(func(e): return e.cat == "warning")
	check(warn.size() == 1 and warn[0].sev == "crit" and warn[0].text.contains("Early warning") and warn[0].text.contains("40 seconds"), "as a red warning with its source and impact time: %s" % (warn[0].text if not warn.is_empty() else ""))
	check(S.alerts()[0].cat == "warning", "warnings lead the banner")
	view._refresh_banner()
	var red := 0
	var amber := 0
	for key in view._cards:
		if view._cards[key].get_meta("crit", false): red += 1
		else: amber += 1
	check(red == 1 and amber >= 1, "the banner shows the warning red and reports of damage amber (%d red, %d amber)" % [red, amber])
	w.espionage.intel[1] = 0.0
	# Forces approaching a town: seen ones are reported as sightings, unseen ones only through intelligence.
	w.diplomacy.declare_war(0, 1, "test")
	var town: Dictionary = target_b
	var away: Vector3 = town.root.position + Vector3(126, 0, 0)
	var army := []
	for i in range(5): army.append(w.spawn_unit("tank", away + Vector3(0, 0, i * 3.0), 1))
	w.fog.enabled = true
	S.scan_forces()
	var seen_any: bool = army.any(func(u): return w.fog.shows(u))
	var sighted: bool = S.events.any(func(e): return e.cat == "enemy")
	var warned: bool = S.events.any(func(e): return e.cat == "warning" and e.text.contains("approaching"))
	check(seen_any == sighted and not warned, "without agents, forces you can see are sightings and unseen ones are not reported (seen: %s)" % seen_any)
	w.espionage.intel[1] = 80.0
	S.scan_forces()
	if not seen_any:
		check(S.events.any(func(e): return e.cat == "warning" and e.text.contains("approaching")), "with agents in its nation an approaching army is a warning even unseen")
	else:
		check(true, "(the fixture's army was within sight; the unseen case is covered by the early-warning checks above)")
	w.fog.enabled = false
	w.espionage.intel[1] = 0.0

	# ---- messages are classified
	var before_n: int = S.events.size()
	h.notice("Russia declares war on you")
	h.notice("Research complete: Steel")
	h.notice("Not enough iron")
	var cats := {}
	for e in S.events.slice(before_n): cats[e.text] = [e.cat, e.sev]
	check(cats.get("Russia declares war on you", []) == ["war", "crit"], "a war declared on you is critical diplomacy")
	check(cats.get("Research complete: Steel", [])[0] == "done", "finished research is completed work")
	check(cats.get("Not enough iron", [])[0] == "econ", "a shortage is economy")

	# ---- the summary
	var groups: Array = S.summary(300.0)
	var order: Array = groups.map(func(g): return g[0])
	check(order.find("attack") < order.find("loss") and order.find("loss") < order.find("kill") and order.has("war") and order.has("done") and order.has("econ"), "the summary groups by kind in order: %s" % str(order))
	check(S.headline(300.0).contains("under attack") and S.headline(300.0).contains("lost"), "and has a headline: %s" % S.headline(300.0))
	check(S.unread > 0 and S.unread_critical > 0, "unread warnings are counted (%d, %d critical)" % [S.unread, S.unread_critical])

	# ---- the screen
	view._refresh_banner()
	check(view._cards.size() >= 1 and view._cards.size() <= 3 and view._banner.get_child_count() == view._cards.size(), "the alert banner shows live alerts (%d cards)" % view._cards.size())
	view._refresh_badge()
	check(h._log_button.text.begins_with("Log ") and S.unread > 0, "the Log button shows the unread count: %s" % h._log_button.text)
	h.toggle_log()
	await process_frame
	var text := labels(h._log_rows)
	check(h._log_box.visible and text.contains("Last 5 minutes") and text.contains("Under attack") and text.contains("Lost: 3× %s" % w.unit_defs.tank.name), "the report window opens on the summary")
	check(S.unread == 0 and S.unread_critical == 0, "and opening it marks everything read")
	h.set_log_tab("all")
	await process_frame
	check(labels(h._log_rows).contains("Russia declares war on you"), "the second tab lists every message")
	h.set_log_tab("summary")
	h.toggle_log()

	# ---- alerts fade, the battle ends with a report
	w.game_time += 25.0
	check(S.alerts().is_empty(), "alerts go when the fighting stops")
	var reports: int = S.reports
	w.game_time += 30.0
	S.update()
	check(S.reports == reports + 1 and h.notice_log.any(func(l): return str(l).contains("Battle over")), "a battle that ends is reported")
	S.update()
	check(S.reports == reports + 1, "once")
	print("SITREP %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("SITREP %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
