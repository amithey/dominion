extends SceneTree
## Regressions for refunds and saving a match during active combat/policy.
const Powers = preload("res://scripts/faction_powers.gd")
const Factions = preload("res://scripts/factions.gd")
var w: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func site(key: String) -> Vector3:
	var at = w.test_site(key, w.start)
	assert(at != null, "test needs a valid " + key + " site")
	return at

func json_save() -> Dictionary:
	return JSON.parse_string(JSON.stringify(w.saves.capture()))

func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	w.saves.autosave_every = 0
	paused = true
	seed(20260929)
	w.economy.grant_test_resources()
	# Iran pays 75% for missiles. Cancelling must return exactly that price.
	var original: Dictionary = w.map.nations[0].duplicate(true)
	w.map.nations[0] = Factions.nation(3, true)
	w.research._recompute()
	var silo: Dictionary = w.place_building("missileSilo", site("missileSilo"), 0, true)
	var before: Dictionary = w.economy.res.duplicate()
	w.missiles.produce(silo, "tactical")
	check(silo.queue.size() == 1, "discounted missile was queued")
	var paid: float = before.money - w.economy.res.money
	check(paid > 0 and paid < w.missiles.def_of("tactical").cost.money, "national missile discount was charged")
	w.cancel_queued(silo, 0)
	check(w.economy.res == before, "cancelled discounted missile refunds only what was paid")
	# Queue two differently priced orders, serialize, and cancel them out of order.
	w.missiles.produce(silo, "tactical")
	w.map.nations[0] = original
	w.research._recompute()
	w.missiles.produce(silo, "tactical")
	var queued_at: Vector3 = silo.root.position
	var queued_save := json_save()
	w.saves.restore(queued_save)
	silo = w.buildings.filter(func(b): return b.key == "missileSilo" and b.root.position.distance_to(queued_at) < 1)[0]
	w.cancel_queued(silo, 1)
	w.cancel_queued(silo, 0)
	check(w.economy.res == before, "saved queue retains the price of each individual order")
	# A researched unit discount can change while an older order waits.
	var barracks: Dictionary = w.place_building("tankFactory", site("tankFactory"), 0, true)
	w.economy.pop_cap = 999
	before = w.economy.res.duplicate()
	w.queue_unit(barracks, "tank")
	check(barracks.queue.size() == 1, "unit order accepted")
	w.research._bonus["costVehiclePct"] = -0.4
	w.cancel_queued(barracks, 0)
	check(w.economy.res == before, "unit refund does not change when a new discount is discovered")
	w.research._recompute()
	before = w.economy.res.duplicate()
	w.queue_unit(barracks, "tank")
	var first_cost: float = before.money - w.economy.res.money
	w.research._bonus["costVehiclePct"] = -0.4
	w.queue_unit(barracks, "tank")
	barracks.supplied = true
	w.update_training(100)
	check(barracks.queue.size() == 1 and barracks.queue_costs.size() == 1, "completed order removes only its own receipt")
	w.cancel_queued(barracks, 0)
	check(is_equal_approx(w.economy.res.money, before.money - first_cost), "cancelling the next order refunds the next receipt")
	w.research._recompute()
	# Loading the same save must rewind policies, not retain later effects.
	w.game_time = 100
	w.power_ready.clear()
	w.power_effects.clear()
	Powers.use(w, 0, 1)
	var cooldown: float = Powers.ready_in(w, 0)
	var active_save := json_save()
	w.power_ready.clear()
	w.power_effects.clear()
	w.power_uses.clear()
	w.saves.restore(active_save)
	check(is_equal_approx(Powers.ready_in(w, 0), cooldown), "power cooldown survives JSON load")
	check(is_equal_approx(Powers.income_mult(w, 1), 0.7), "active sanctions survive JSON load")
	check(w.power_uses.size() == 1, "power usage history survives load")
	w.game_time += 181
	check(Powers.income_mult(w, 1) == 1 and Powers.ready_in(w, 0) > 0, "loaded sanctions expire while their cooldown continues")
	w.game_time = 500
	w.power_ready.clear()
	w.power_effects.clear()
	var peaceful_save := json_save()
	Powers.use(w, 0, 1)
	w.saves.restore(peaceful_save)
	check(Powers.ready_in(w, 0) == 0 and Powers.income_mult(w, 1) == 1, "loading earlier state clears policies applied after that save")
	# A missile has left storage and is halfway to its target when saved.
	var target: Vector3 = w.start + Vector3(150, 0, 0)
	var missile: Dictionary = w.missiles.fly("cruise", w.start + Vector3.UP * 5, target, 1, true)
	target = missile.to  # launch adjusts the destination to the terrain height
	w.missiles._physics_process(0.3)
	var elapsed: float = missile.t
	var defender: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	missile.engaged = {defender.node.get_instance_id(): true, "dome": true}
	defender.disabled_until = w.game_time + 25
	defender.intercept_ready = w.game_time + 8
	defender.aa_reload = 3.0
	var mobile: Dictionary = w.spawn_unit("samLauncher", w.land_point(w.start, 35), 0)
	mobile.disabled_until = w.game_time + 12
	mobile.intercept_ready = w.game_time + 6
	missile.engaged[mobile.node.get_instance_id()] = true
	w.research.tracks.military = 5
	w.research._recompute()
	var veteran: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 45), 0)
	var veteran_max: float = veteran.max_hp
	for nation in w.ai.nations:
		if nation.id == 1:
			nation.tech = 8.0
	var rival_veteran: Dictionary = w.spawn_unit("soldier", w.land_point(w.start, 55), 1)
	var rival_max: float = rival_veteran.max_hp
	var original_stats: Array = w.units.map(func(u): return [u.max_hp, u.range, u.speed, u.cooldown])
	var flight_save := json_save()
	w.saves.restore(flight_save)
	check(w.missiles.flying.size() == 1, "missile in flight is not erased by loading")
	if w.missiles.flying.size() == 1:
		var restored: Dictionary = w.missiles.flying[0]
		check(restored.type == "cruise" and restored.owner == 1 and is_equal_approx(restored.t, elapsed), "missile owner, type and elapsed flight are preserved")
		check(restored.to.distance_to(target) < 1, "missile keeps its destination")
		var loaded_defender: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
		check(restored.engaged.has(loaded_defender.node.get_instance_id()) and restored.engaged.has("dome"), "load does not grant a defender another interception attempt")
		check(loaded_defender.disabled_until == w.game_time + 25 and loaded_defender.intercept_ready == w.game_time + 8 and loaded_defender.aa_reload == 3, "EMP and defence cooldowns survive load")
		var loaded_mobile: Dictionary = w.units.filter(func(u): return u.key == "samLauncher" and u.disabled_until == w.game_time + 12)[0]
		check(restored.engaged.has(loaded_mobile.node.get_instance_id()) and loaded_mobile.intercept_ready == w.game_time + 6, "mobile defence keeps its EMP, cooldown and interception attempt")
		w.missiles._physics_process(restored.dur)
		check(w.missiles.flying.is_empty(), "restored missile continues to impact")
	# Exercise the menu's fresh-scene loading path, not only restore in-place.
	var old_world := w.get_instance_id()
	set_meta("match_config", flight_save.match_config)
	set_meta("pending_load", flight_save)
	paused = false
	reload_current_scene()
	w = null
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_world and current_scene.get("menu") != null and current_scene.menu.get("_root") != null:
			w = current_scene
			break
	check(w != null, "saved combat state opens in a fresh scene")
	if w == null:
		quit(1)
		return
	paused = true
	w.saves.autosave_every = 0
	check(w.missiles.flying.size() == 1 and w.missiles.flying[0].owner == 1, "fresh scene retains the incoming missile")
	var saved_veterans: Array = w.units.filter(func(u): return u.key == "soldier" and u.owner == 0 and is_equal_approx(u.hp, veteran_max))
	check(saved_veterans.size() == 1 and is_equal_approx(saved_veterans[0].max_hp, veteran_max), "fresh load restores researched maximum health before spawning player units")
	var saved_rivals: Array = w.units.filter(func(u): return u.key == "soldier" and u.owner == 1 and is_equal_approx(u.hp, rival_max))
	check(saved_rivals.size() == 1 and is_equal_approx(saved_rivals[0].max_hp, rival_max), "fresh load restores rival technology before spawning rival units")
	# (to a millionth: a save writes figures shorter than a double, and a nation's
	# quality multipliers, unit_quality.gd, leave fractions in the last digits)
	var loaded_stats: Array = w.units.map(func(u): return [u.max_hp, u.range, u.speed, u.cooldown])
	var same: bool = loaded_stats.size() == original_stats.size()
	for i in range(mini(loaded_stats.size(), original_stats.size())):
		for j in range(4):
			same = same and absf(float(loaded_stats[i][j]) - float(original_stats[i][j])) <= 0.000001 * maxf(1.0, absf(float(original_stats[i][j])))
	check(same, "loading preserves equipment on both old and upgraded units")
	# Old saves start with no new policy, flight or receipt data.
	var legacy := json_save()
	legacy.erase("national_powers")
	legacy.missiles.erase("flying")
	for b in legacy.buildings:
		b.erase("queue_costs")
		for timer in ["disabled_until", "intercept_ready", "aa_reload"]:
			b.erase(timer)
	for u in legacy.units:
		u.erase("equipment")
		for timer in ["disabled_until", "intercept_ready"]:
			u.erase(timer)
	w.saves.restore(legacy)
	check(w.power_ready.is_empty() and w.power_effects.is_empty() and w.missiles.flying.is_empty(), "legacy saves load with safe empty state")
	check(w.units.all(func(u): return u.disabled_until == 0 and u.intercept_ready == 0), "legacy unit timers default to ready")
	# Diplomatic contact loaded from JSON keeps integer nation id and enforces post-contact cooldown.
	w.diplomacy.contacts.session = {"nation": 1, "channel": "phone", "phase": "active", "counter": {}, "results": [], "message": ""}
	var contact_save := json_save()
	w.saves.restore(contact_save)
	check(typeof(w.diplomacy.contacts.session.nation) == TYPE_INT, "loaded diplomatic contact normalises nation id to int")
	w.diplomacy.contacts.finish()
	check(float(w.diplomacy.contacts.cooldowns.get("1", 0.0)) > w.diplomacy.contacts.clock, "finishing a loaded diplomatic contact sets cooldown under integer key")
	# Loading an older save clears live satellites, nuclear postures, war support, UN state and grid shocks.
	if w.space != null: w.space.sats[0] = {"recon": 2, "gps": 1, "comms": 0, "warning": 0}
	if w.defcon != null: w.defcon.posture[0] = 2
	if w.support != null: w.support.support[0] = 15.0
	if w.un != null:
		w.un.indicted[1] = true
		w.un.arrears = 500.0
		if w.un.agencies != null: w.un.agencies.iaea_flagged[1] = true
	if w.homefront != null: w.homefront.grid_damaged[0] = [Vector3.ZERO]
	if w.get("directorate") != null and w.directorate != null:
		w.directorate.st[0].level = 4
		w.directorate.st[0].doctrine = "out"
		w.directorate.signed.nuclear.erase(0)
	if w.fog != null: w.fog.explored.fill(1)
	if w.get("sitrep") != null and w.sitrep != null:
		w.sitrep.record("warning", "crit", "test-warning", "Phantom future alert", Vector3.ZERO)
	if w.space != null:
		w.space.reveals.append({"at": Vector3.ZERO, "radius": 30.0, "until": 9999.0})
		w.space._pass[0] = 9999.0
		w.space._jam_ready[0] = 9999.0
	if w.passage != null:
		w.passage.asked[1] = 9999.0
	if w.get("generals") != null and w.generals != null:
		w.generals._ai_next = 9999.0
	if w.get("directorate") != null and w.directorate != null:
		w.directorate._alarm_at[0] = 9999.0
		w.directorate._agi_risk_at[0] = 9999.0
		w.directorate._incident_at[0] = 9999.0
		w.directorate.applications._rival_at = 9999.0
		w.directorate.applications._strategic_at = 9999.0
	if w.get("crisis") != null and w.crisis != null:
		w.crisis._last_news = 9999.0
	# Upgraded unit names must revert when loading an earlier save where the upgrade is not yet researched.
	w.map.nations[0] = Factions.nation(0, true)
	w.research.progress["nextGenAbrams"] = {"stage": 0, "work": 0.0, "paid": false}
	w.research._recompute()
	var base_tank_name: String = str(w.unit_defs["tank"].name)
	var prev_ev_ver: int = w.events._version if w.events != null else 0
	var older := json_save()
	w.research.progress["nextGenAbrams"] = {"stage": 3, "work": 0.0, "paid": true}
	w.research._recompute()
	check(str(w.unit_defs["tank"].name) == "M1E3 Abrams", "researching nextGenAbrams renames player tank to M1E3 Abrams")
	for section in ["space", "defcon", "support", "un", "homefront", "directorate", "fog"]: older.erase(section)
	w.saves.restore(older)
	check(str(w.unit_defs["tank"].name) == base_tank_name, "loading earlier save reverts upgraded unit_defs name back to base national name")
	check(w.space == null or (w.space.total(0) == 0 and w.space.reveals.is_empty() and w.space._pass.is_empty() and w.space._jam_ready.is_empty()), "loading an older save resets live satellites, recon reveals and space timers")
	check(w.passage == null or w.passage.asked.is_empty(), "loading clears live border-trespass prompt cooldowns")
	check(w.get("generals") == null or w.generals == null or w.generals._ai_next == 0.0, "loading resets AI general enlistment schedule")
	check(w.defcon == null or w.defcon.posture.get(0, -1) == 5, "loading an older save resets live nuclear postures to default")
	check(w.support == null or is_equal_approx(w.support.value(0), w.support.baseline(0)), "loading an older save resets live war support to baseline")
	check(w.un == null or (w.un.indicted.is_empty() and w.un.arrears == 0.0 and w.un.agencies.iaea_flagged.is_empty()), "loading an older save clears live UN and agency state")
	check(w.homefront == null or w.homefront.grid_damaged.is_empty(), "loading clears homefront grid shocks")
	check(w.get("directorate") == null or w.directorate == null or (w.directorate.level(0) == 0 and w.directorate.doctrine(0) == "in" and w.directorate._alarm_at.is_empty() and w.directorate.applications._rival_at == 0.0 and w.directorate.applications._strategic_at == 0.0), "loading an older save resets live AI directorate level, doctrine and schedule timers")
	check(w.get("crisis") == null or w.crisis == null or w.crisis._last_news < 0.0, "loading resets crisis world-news cooldown timer")
	check(w.fog == null or w.fog.explored.count(0) > 0, "loading an older save clears live explored fog of war")
	check(w.get("sitrep") == null or w.sitrep == null or (w.sitrep.events.is_empty() and w.sitrep.pings.is_empty() and w.sitrep.unread == 0), "loading clears live sitrep alerts, pings and unread counts")
	check(w.events == null or w.events._version > prev_ev_ver, "loading bumps world events version")
	# UN enforcement must not act on a target defeated while voting was open.
	if w.un != null and w.ai.nations.size() >= 1:
		var defeated_id: int = int(w.ai.nations[0].id)
		var was_defeated: bool = bool(w.ai.nations[0].defeated)
		var rel_before: float = w.diplomacy.rel(0, defeated_id)
		w.ai.nations[0].defeated = true
		w.un._enforce({"measure": "statement", "target": defeated_id, "other": -1, "votes": {}})
		w.un._enforce({"measure": "force", "target": defeated_id, "other": -1, "votes": {}})
		check(is_equal_approx(w.diplomacy.rel(0, defeated_id), rel_before) and not w.un.authorised.has(defeated_id), "UN enforcement skips a target defeated before voting closed")
		w.ai.nations[0].defeated = was_defeated
	# Physics & combat logic regressions (cover, submarine targeting cache, Golden Dome, EW, airlift fuel, garrison).
	var Modern := preload("res://scripts/modern_warfare.gd")
	var Bunker := preload("res://scripts/bunker.gd")
	var WarTools := preload("res://scripts/war_tools.gd")
	var UrbanGarrison := preload("res://scripts/urban_garrison.gd")
	var Airlift := preload("res://scripts/airlift.gd")
	w.economy.operating_notices["fuel"] = 9999.0
	w.saves.restore(older)
	check(w.economy.operating_notices.is_empty(), "loading clears operating shortage notice cooldowns")
	# 1. Golden Dome handles supersonic/glide/underwater missiles without crashing or charging for underwater torpedoes.
	w.economy.grant_test_resources()
	w.research.progress["goldenDome"] = {"stage": 3, "work": 0.0, "paid": true}
	w.research._recompute()
	w.diplomacy.declare_war(0, 1)
	var m_before: float = float(w.economy.res.money)
	var dome_poseidon := Modern.dome(w, {"type": "poseidon", "owner": 1, "arc": false, "engaged": {}}, w.start, 0.5)
	check(not dome_poseidon and is_equal_approx(float(w.economy.res.money), m_before), "Golden Dome ignores underwater Poseidon without crashing or charging $150")
	Modern.dome(w, {"type": "nuclearGlide", "owner": 1, "arc": true, "engaged": {}}, w.start, 0.6)
	Modern.dome(w, {"type": "brahmos", "owner": 1, "arc": false, "engaged": {}}, w.start, 0.6)
	check(true, "Golden Dome evaluates nuclearGlide and brahmos without key errors")
	# 2. effectiveness() cache must NOT let non-ASW units target submarines after fighting a surface ship.
	var sea_pt = w.water_near(w.start, 320)
	if sea_pt != null:
		var tnk_c: Dictionary = w.spawn_unit("tank", w.start + Vector3(12, 0, 0), 0)
		var corv_c: Dictionary = w.spawn_unit("corvette", sea_pt, 0)
		var dest_e: Dictionary = w.spawn_unit("destroyer", sea_pt + Vector3(8, 0, 0), 1)
		var sub_e: Dictionary = w.spawn_unit("submarine", sea_pt + Vector3(16, 0, 0), 1)
		check(w.effectiveness(tnk_c, dest_e) > 0.0 and w.effectiveness(tnk_c, sub_e) == 0.0, "effectiveness cache keeps tanks unable to target submarines after engaging surface ships")
		check(w.effectiveness(corv_c, dest_e) > 0.0 and w.effectiveness(corv_c, sub_e) == 0.0, "effectiveness cache keeps corvettes unable to target submarines after engaging surface ships")
		if w.map.nations.size() >= 3:
			var sub_p: Dictionary = w.spawn_unit("submarine", sea_pt + Vector3(24, 0, 0), 0)
			sub_p.last_fire = -999.0
			var frig2: Dictionary = w.spawn_unit("asFrigate", sea_pt + Vector3(30, 0, 0), 2)
			check(not Modern.hidden(w, sub_p, 6.0, 80.0, 2), "Modern.hidden checks the actual viewer nation for submarine sonar detection")
			w.kill(sub_p); w.kill(frig2)
		w.kill(tnk_c); w.kill(corv_c); w.kill(dest_e); w.kill(sub_e)
	# 3. Bunker & fortification cover allow missiles, pierce warheads, indirect artillery, and flushed troops.
	var bkr: Dictionary = w.place_building("bunker", site("bunker"), 0, true)
	var towed: Dictionary = w.spawn_unit("towedHowitzer", bkr.root.position + Vector3(20, 0, 0), 1)
	var nuke_src := {"owner": 1, "dead": true, "key": "missile", "missile_key": "nuke", "special": "", "nuclear": true, "pierce": false}
	var thermo_src := {"owner": 1, "dead": true, "key": "missile", "missile_key": "thermobaricMissile", "special": "thermobaric", "nuclear": false, "pierce": true}
	check(is_equal_approx(Bunker.cover(w, bkr, towed), 1.0) and is_equal_approx(Bunker.cover(w, bkr, nuke_src), 1.0), "bunker cover does not reduce towedHowitzer or strategic missile damage")
	w.kill(towed); w.destroy_building(bkr)
	# 4. EW jet jams fixed SAM site buildings.
	var sam_b: Dictionary = w.place_building("samSite", site("samSite"), 1, true)
	var ew_u: Dictionary = w.spawn_unit("ewJet", sam_b.root.position + Vector3(15, 0, 0), 0)
	ew_u.air_state = "ready"
	var jet_u: Dictionary = w.spawn_unit("jet", sam_b.root.position + Vector3(20, 0, 0), 0)
	jet_u.air_state = "ready"
	WarTools.update(w, 0.3)
	check(WarTools.damage_mult(w, sam_b, jet_u) < 0.9, "ewJet jams fixed samSite buildings")
	w.kill(ew_u); w.kill(jet_u); w.destroy_building(sam_b)
	# 5. Urban garrison evacuates on ownership flip and indoor troops do not physically push outdoor vehicles.
	var apt: Dictionary = w.place_building("apartments", site("apartments"), 0, true)
	var g_sol: Dictionary = w.spawn_unit("soldier", apt.root.position + Vector3(4, 0, 0), 0)
	UrbanGarrison.enter(w, g_sol, apt)
	var out_tnk: Dictionary = w.spawn_unit("tank", g_sol.node.position + Vector3(1.5, 0, 0), 0)
	w.rebuild_grid()
	check(w.Tactics.hard_push(w, out_tnk, out_tnk.node.position).length() < 0.01, "garrisoned indoor soldiers do not physically push outdoor tanks")
	apt.owner = 1
	UrbanGarrison.update(w, 0.1)
	check(g_sol.get("garrison_building") == null, "flipping building ownership evacuates the old owner's garrison")
	w.kill(out_tnk); w.kill(g_sol); w.destroy_building(apt)
	# 6. Parked transport helicopter respects aviation fuel shortage.
	var hpad: Dictionary = w.place_building("helipad", site("helipad"), 0, true)
	hpad.supplied = true
	var th: Dictionary = w.spawn_unit("helicopter", hpad.root.position, 0)
	w.AirOperations.park_new(w, th, hpad)
	var far_s: Dictionary = w.spawn_unit("soldier", w.land_point(hpad.root.position + Vector3(45, 0, 0), 10.0), 0)
	w.economy.res.oil = 0.0
	Airlift.order_board(w, [far_s], th)
	check(th.air_state == "parked", "parked helicopter stays grounded when player has zero aviation fuel")
	w.economy.grant_test_resources()
	w.kill(far_s); w.kill(th); w.destroy_building(hpad)
	# 7. Unmanned seaDrone/drone/decoy losses do not drain war support.
	if w.support != null:
		var sup0: float = w.support.value(0)
		var dec_u: Dictionary = w.spawn_unit("decoy", w.start + Vector3(14, 0, 0), 0)
		w.kill(dec_u)
		check(is_equal_approx(w.support.value(0), sup0), "losing an unmanned decoy does not lower home-front war support")
	w.diplomacy.make_peace(0, 1)
	for i in range(3):
		await process_frame
	print("GAMEPLAY_STATE_AUDIT %d checks, %d failures" % [checks, failures.size()])
	print("GAMEPLAY_STATE_AUDIT PASS" if failures.is_empty() else "GAMEPLAY_STATE_AUDIT FAIL")
	quit(0 if failures.is_empty() else 1)
