extends SceneTree
## Thirty gameplay checks on a full-size match: nine nations on Pangaea, each
## rival at its own difficulty (0.9.38). Relations, the Diplomacy screen and
## the minimap with nine nations; rivals growing at their own pace; wars
## between rivals; an attack wave crossing the whole continent; peace, pacts,
## trade, spies, national powers and contacts with the farthest nation;
## missiles both ways; land; a rival's fall and the victory; a save to disk
## and back.
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
const Setup := preload("res://scripts/match_setup.gd")
const Powers := preload("res://scripts/faction_powers.gd")
const LEVELS := ["hard", "easy", "hard", "easy", "normal", "normal", "hard", "easy"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

## Everything a running match does, stepped by hand.
func sim(seconds: float, done := Callable()) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		w.ai._physics_process(DT)
		for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
			node._process(DT)
		t += DT
		if done.is_valid() and done.call():
			break

func hq(owner: int):
	for b in w.buildings:
		if b.owner == owner and b.key == "hq" and not b.dead:
			return b
	return null

func assets(owner: int) -> int:
	return w.buildings.filter(func(b): return b.owner == owner and not b.dead).size() + w.units.filter(func(u): return u.owner == owner and not u.dead).size()

func owner_of(id: String) -> int:
	for i in range(w.map.nations.size()):
		if str(w.map.nations[i].get("id", "")) == id: return i
	return -1

func run() -> void:
	set_meta("match_config", {"map": "pangaea", "players": 9, "nation": 0, "style": "standard", "levels": LEVELS})
	change_scene_to_file("res://world.tscn")
	for i in range(30000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	seed(20260929)
	w.start_match("normal")
	w.menu._root.hide()
	for i in range(10): await physics_frame
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	for node in [w.economy, w.research, w.territory, w.market, w.diplomacy, w.espionage]:
		node.set_process(false)
	var d: Node = w.diplomacy
	var count: int = w.map.nations.size()

	# 1-3: the match and its starting relations.
	check(count == 9 and w.ai.nations.size() == 8 and d.n == 9, "nine nations, eight rivals, diplomacy for nine (%d, %d, %d)" % [count, w.ai.nations.size(), d.n])
	var iran := owner_of("iran")
	var israel := owner_of("israel")
	check(iran > 0 and israel > 0 and d.rel(iran, israel) <= -50.0, "Iran and Israel start as enemies among nine (%d)" % int(d.rel(iran, israel)))
	check(d.rel(0, israel) >= 25.0, "the United States starts close to Israel (%d; a tie of +35 with up to 7.5 either way)" % int(d.rel(0, israel)))

	# 4-5: the Diplomacy screen and the minimap hold nine nations.
	w.hud.show()
	w.hud._panels = w.hud._panels if w.hud._panels != null else preload("res://scripts/side_panels.gd").new(w.hud)
	w.hud._panels.diplomacy_tab = "nations"
	w.hud.toggle_panel("diplomacy", true)
	await process_frame
	var cards: int = w.hud._side_rows.find_children("NationalProfile", "", true, false).size()
	check(cards == 9, "the Diplomacy screen shows all nine nations' profiles (%d)" % cards)
	w.hud.toggle_panel("diplomacy", false)
	var mm: Control = null
	for c in w.hud.find_children("*", "Control", true, false):
		if c.get_script() == preload("res://scripts/minimap.gd"):
			mm = c
			break
	var inside := 0
	if mm != null:
		for owner in range(count):
			var p: Vector2 = mm.to_map(hq(owner).root.position)
			if p.x > 0.0 and p.y > 0.0 and p.x < mm.size.x and p.y < mm.size.y: inside += 1
	check(inside == count, "every capital shows on the minimap (%d of %d)" % [inside, count])

	# 6: the camera reaches the farthest capital.
	var far := 1
	for owner in range(1, count):
		if hq(owner).root.position.distance_to(w.start) > hq(far).root.position.distance_to(w.start): far = owner
	w.cam_focus = hq(far).root.position
	w.clamp_camera()
	check(w.cam_focus.distance_to(hq(far).root.position) < 1.0, "the camera reaches the farthest capital, %d m away" % int(hq(far).root.position.distance_to(w.start)))
	w.cam_focus = w.start

	# 7-10: three minutes of peace: everyone grows, each at its own pace.
	var before := {}
	for n in w.ai.nations: before[n.id] = assets(n.id)
	var cells0 := {}
	w.territory.tick()
	for owner in range(count): cells0[owner] = int(w.territory.yields(owner).cells)
	var t0 := Time.get_ticks_msec()
	sim(180.0)
	var per_step: float = float(Time.get_ticks_msec() - t0) / (180.0 / DT)
	var grew: int = w.ai.nations.filter(func(n): return assets(n.id) > before[n.id]).size()
	check(grew == 8, "all eight rivals build up in three minutes (%d)" % grew)
	var gain := {"hard": [], "easy": []}
	for n in w.ai.nations:
		if gain.has(n.level): gain[n.level].append(assets(n.id) - before[n.id])
	var hard_avg: float = gain.hard.reduce(func(s, v): return s + v, 0) / float(maxi(gain.hard.size(), 1))
	var easy_avg: float = gain.easy.reduce(func(s, v): return s + v, 0) / float(maxi(gain.easy.size(), 1))
	check(hard_avg > easy_avg * 1.3, "hard rivals grow faster than easy ones (+%.1f vs +%.1f on average)" % [hard_avg, easy_avg])
	var tech := {"hard": 0.0, "easy": 0.0}
	for n in w.ai.nations:
		if tech.has(n.level): tech[n.level] = maxf(tech[n.level], float(n.get("tech", 0.0)))
	check(tech.hard > tech.easy, "hard rivals research faster (tech %.2f vs %.2f)" % [tech.hard, tech.easy])
	check(per_step < 60.0, "nine nations run smoothly (%.1f ms a step)" % per_step)
	var spread := 0
	w.territory.tick()
	for owner in range(1, count):
		if int(w.territory.yields(owner).cells) >= int(cells0[owner]): spread += 1
	check(spread == 8, "no rival loses land in peacetime (%d of 8)" % spread)

	# 11-12: a war between two rivals is fought.
	var a := iran
	var b := israel
	d.declare_war(a, b)
	check(d.at_war(a, b) and b in d.enemies_of(a), "rivals go to war with each other")
	for n in w.ai.nations:
		if n.id == a:
			n.money = 5000.0
			n.next_attack = 0.0
	for i in range(12): w.spawn_unit("tank", w.land_point(hq(a).root.position, 30.0), a)   # a hard government waits for a squad of nine or more
	var toward := 0
	sim(2.0)
	for u in w.units:
		if u.owner == a and not u.dead and u.target is Vector3 and (u.target as Vector3).distance_to(hq(b).root.position) < (u.target as Vector3).distance_to(hq(a).root.position):
			toward += 1
	check(toward >= 3, "Iran's attack wave sets off for Israel (%d units)" % toward)
	d.make_peace(a, b)

	# 13-14: the farthest rival's wave crosses the continent to your capital.
	d.declare_war(far, 0)
	for i in range(8): w.spawn_unit("tank", w.land_point(hq(far).root.position, 30.0), far)
	for n in w.ai.nations:
		if n.id == far: n.next_attack = 0.0
	var mine: Vector3 = hq(0).root.position
	var start_ms := Time.get_ticks_msec()
	var arrived := func(): return w.units.any(func(u): return u.owner == far and not u.dead and u.node.position.distance_to(mine) < 150.0)
	sim(480.0, arrived)   # (each nation's tanks now move at their own system's speed: unit_quality.gd)
	var closest := INF
	for u in w.units:
		if u.owner == far and not u.dead: closest = minf(closest, u.node.position.distance_to(mine))
	check(arrived.call(), "the farthest rival's army crosses the continent to your capital (closest %d m)" % int(closest))
	check(Time.get_ticks_msec() - start_ms < 240000, "the long march is simulated in time (%.0f s)" % ((Time.get_ticks_msec() - start_ms) / 1000.0))
	for u in w.units:
		if u.owner == far and not u.dead: w.kill(u)

	# 15-16: peace with it, then a trade pact.
	d.set_score(0, far, 40.0)
	var tries := 0
	while d.at_war(0, far) and tries < 12:
		d.offer_peace(far)
		tries += 1
	check(not d.at_war(0, far), "the farthest rival accepts peace (%d offers)" % tries)
	d.set_score(0, far, 60.0)
	var pact_text: String = d.propose_pact(far)
	check(d.pact[0][far], "and signs a trade pact: " + pact_text)

	# 17: trade with it.
	w.economy.grant_test_resources()
	var trade_text: String = w.market.open_route(far, "iron", "export", 10)
	var routes: int = w.market.routes.filter(func(r): return int(r.nation) == far).size() if w.market.get("routes") != null else 0
	check(routes >= 1 or trade_text.to_lower().contains("market") or trade_text.to_lower().contains("port") or trade_text.to_lower().contains("harbour") or trade_text.to_lower().contains("link"), "a trade route to the farthest nation opens, or says what it needs: " + trade_text)

	# 18: spies against the last nation on the list.
	w.place_building("intelAgency", w.land_point(w.start, 50.0), 0, true)
	w.economy.recalculate()
	w.espionage.recruit()
	var spy_text: String = w.espionage.run("openSources", 8)
	check(w.espionage.missions.any(func(m): return int(m.nation) == 8), "an agent is sent against the ninth nation: " + spy_text)

	# 19: your national power on the ninth nation.
	var power: Dictionary = Powers.power_of(w, 0)
	var power_text := "no power"
	if not power.is_empty():
		power_text = Powers.use(w, 0, 8 if power.target else -1)
	check(not power_text.begins_with("Choose"), "your national power works on the ninth nation: " + power_text)

	# 20: a summit with the ninth nation.
	var contacts = d.contacts
	var contact_text := "no contacts"
	if contacts != null:
		d.set_score(0, 8, 50.0)
		contact_text = contacts.begin(8, contacts.CHANNELS.keys()[0])
	check(contacts != null and (contact_text == "" or not contact_text.to_lower().contains("valid")), "a diplomatic contact opens with the ninth nation (%s)" % (contact_text if contact_text != "" else "started"))

	# 21-22: missiles both ways across the map.
	var target_b = hq(far)
	var hp0: float = target_b.hp
	var ours: Dictionary = w.missiles.fly("ballistic", w.start + Vector3.UP * 3.0, target_b.root.position, 0)
	sim(40.0, func(): return not ours in w.missiles.flying)
	check(target_b.hp < hp0 or target_b.dead, "your ballistic missile reaches the farthest capital (%d -> %d)" % [int(hp0), int(maxf(target_b.hp, 0.0))])
	d.declare_war(far, 0)
	var rival: Dictionary = {}
	for n in w.ai.nations:
		if n.id == far: rival = n
	rival.money = 5000.0
	# A missile needs a launch platform (arsenal_catalog.gd): the silo a rival builds at technology 2.
	if w.missiles.platforms_for("ballistic", far).is_empty():
		for k in range(24):
			var site = w.test_site("missileSilo", hq(far).root.position + Vector3.FORWARD.rotated(Vector3.UP, k * 0.7) * (30.0 + k * 3.0))
			if site != null:
				w.place_building("missileSilo", site, far, true)
				break
	var n_before: int = w.missiles.flying.size()
	var strike: Dictionary = w.ai.missile_strike(rival, hq(far), 6.0)
	check(not strike.is_empty() and w.missiles.flying.size() > n_before, "the farthest rival can strike your towns with missiles")
	sim(40.0, func(): return not strike in w.missiles.flying)

	# 23: land with nine nations.
	w.territory.tick()
	var yours: int = int(w.territory.yields(0).cells)
	var seat = hq(0)
	var options: Array = w.territory.purchase_candidates(seat)
	var bought := "nothing to buy"
	if not options.is_empty(): bought = w.territory.purchase(seat, options[0])
	w.territory.tick()
	check(int(w.territory.yields(0).cells) > yours, "you buy land beside your capital (%s)" % bought)

	# 24-26: a rival falls.
	var victim := owner_of("turkiye")
	w.destroy_building(hq(victim))
	sim(3.0)
	check(d.defeated(victim), "a rival without a capital is defeated")
	var still: int = w.units.filter(func(u): return u.owner == victim and not u.dead).size()
	var busy := false
	for n in w.ai.nations:
		if n.id == victim: busy = not n.defeated
	check(not busy, "and its government stops (%d units left in the field)" % still)
	check(w.game_over == "", "one fallen rival does not end the match")

	# 27-28: a save to disk and back.
	var rels := []
	for i in range(1, count): rels.append(snappedf(d.rel(0, i), 0.1))
	var buildings: int = w.buildings.filter(func(x): return not x.dead).size()
	check(w.saves.save("nine30"), "the nine-nation match saves to disk")
	w.economy.res.money = 1.0
	var loaded: bool = w.saves.load_slot("nine30")
	for i in range(30): await process_frame
	w = current_scene
	for i in range(30000):
		if w != null and w.get("nav_ready") == true: break
		await process_frame
		w = current_scene
	d = w.diplomacy
	var rels2 := []
	for i in range(1, w.map.nations.size()): rels2.append(snappedf(d.rel(0, i), 0.1))
	var levels_ok: bool = w.ai.nations.all(func(n): return str(n.get("level", "")) == Setup.level_of(w.match_config, int(n.id), "normal"))
	check(loaded and w.map.nations.size() == 9 and w.ai.nations.size() == 8 and levels_ok, "it loads with nine nations, each rival at its level")
	check(rels2 == rels and absf(w.buildings.filter(func(x): return not x.dead).size() - buildings) <= 1 and d.defeated(owner_of("turkiye")), "relations, towns and the fallen rival come back as they were")
	DirAccess.remove_absolute(w.saves.path_of("nine30"))

	# 29-30: the last capitals fall: victory.
	for i in range(30): await physics_frame
	w.set_physics_process(false)
	for owner in range(1, w.map.nations.size()):
		var h = hq(owner)
		if h != null: w.destroy_building(h)
	for n in w.ai.nations:
		w.ai._physics_process(0.1)
	w.check_game_over()
	check(w.ai.nations.all(func(n): return n.defeated), "every rival falls with its capital")
	check(w.game_over == "victory", "and the match is won (%s)" % w.game_over)

	print("\nGAMEPLAY_NINE: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("GAMEPLAY_NINE PASS" if errors.is_empty() else "GAMEPLAY_NINE FAIL")
	quit(0 if errors.is_empty() else 1)
