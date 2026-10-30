extends SceneTree
## Customer round 5, part 2: the annoying customer plays. Each scenario is one nation on one map at one
## difficulty. The customer does what a careless, impatient or hostile player does: orders units off the
## map, builds in the sea and on top of the capital, queues past the limit, spends money they do not have,
## demolishes twice, proposes peace to a friend and an alliance to an enemy, saves in the middle of a war and
## loads it back. Every step is judged by the engine's own errors (audit_kit Catcher) and by plain sense.
## Usage: --from=N --to=M picks a slice of the scenario list; --list prints it.
## Table: res://build/audit/customer5-play-<from>-<to>.txt
const Kit := preload("res://tools/audit_kit.gd")
const Registry := preload("res://scripts/nation_registry.gd")
const Maps := preload("res://scripts/map_generator.gd")
const MatchSetup := preload("res://scripts/match_setup.gd")
const DT := 1.0 / 20.0
var K
var w: Node
func _initialize() -> void: call_deferred("run")

func scenarios() -> Array:
	var ids: Array = Registry.column("id")
	var maps: Array = ["island", "mirrored"] + Maps.MAPS.keys()
	var out: Array = []
	var diffs := ["easy", "normal", "hard"]
	# every nation once, each on a different map, difficulty rotating
	for i in range(ids.size()):
		out.append({"nation": i, "map": maps[(i * 5 + 1) % maps.size()], "difficulty": diffs[i % 3], "players": [2, 3, 4][i % 3]})
	# every map once with a different nation
	for j in range(maps.size()):
		out.append({"nation": (j * 7 + 3) % ids.size(), "map": maps[j], "difficulty": diffs[(j + 1) % 3], "players": 4})
	# the four newest nations get two more maps each: the least-tested corner of the roster
	for n in [28, 29, 30, 2]:
		for k in range(2):
			out.append({"nation": n, "map": maps[(n * 3 + k * 11 + 4) % maps.size()], "difficulty": diffs[(n + k) % 3], "players": 4})
	return out

func sim(seconds: float, rivals := true) -> void:
	var t := 0.0
	var next_tick := 1.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		w.missiles._physics_process(DT)
		if rivals: w.ai._physics_process(DT)
		t += DT
		if t >= next_tick:
			next_tick += 1.0
			if int(next_tick) % 10 == 0: w.research.ai_tick()
			w.economy.tick()
			w.research.tick(1.0)
			w.territory.tick()
			w.diplomacy.tick()

func own(kind: String) -> Array:
	return w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key == kind)

func hq_of(owner := 0) -> Dictionary:
	var list: Array = w.buildings.filter(func(b): return b.owner == owner and b.key == "hq" and not b.dead)
	return list[0] if not list.is_empty() else {}

func home_hex() -> Vector2i:
	return w.logistics.world_hex(w.start)

func find_site(key: String) -> Variant:
	for ring in range(1, 10):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home_hex() + Vector2i(q, r)
				if w.logistics.hex_distance(home_hex(), h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "": return at
	return null

func finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)

func colour_gap(a: Color, b: Color) -> float:
	var r := (a.r + b.r) * 0.5
	return sqrt((2.0 + r) * pow((a.r - b.r) * 255.0, 2) + 4.0 * pow((a.g - b.g) * 255.0, 2) + (3.0 - r) * pow((a.b - b.b) * 255.0, 2))

func step(label: String, tag: String, detail := "") -> void:
	var errs: Array = K.take_errors()
	if errs.is_empty(): K.ok("play", "%s | %s" % [tag, label], detail)
	else: K.fail("play", "%s | %s" % [tag, label], "engine error: " + " || ".join(PackedStringArray(errs.slice(0, 2))))

func run() -> void:
	var list := scenarios()
	var from := 0
	var upto := list.size()
	var seed_shift := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed_shift = int(a.split("=")[1])
		if a.begins_with("--from="): from = int(a.split("=")[1])
		if a.begins_with("--to="): upto = int(a.split("=")[1])
		if a == "--list":
			for i in range(list.size()): print(i, " ", list[i])
			quit(0)
			return
	upto = mini(upto, list.size())
	K = Kit.new(self, "customer5-play-%d-%d" % [from, upto])
	var ids: Array = Registry.column("id")
	for i in range(from, upto):
		var sc: Dictionary = list[i]
		var cap: int = MatchSetup.capacity(sc.map)
		var players := clampi(int(sc.players), 2, cap)
		var tag := "#%d %s/%s/%s" % [i, ids[sc.nation], sc.map, sc.difficulty]
		var t0 := Time.get_ticks_msec()
		seed(20261030 + i + seed_shift)
		K.take_errors()
		w = await K.boot({"map": sc.map, "players": players, "nation": sc.nation}, sc.difficulty, true)
		if w == null:
			K.fail("play", tag + " | boot", "the match did not start")
			continue
		step("boot", tag, "%d players" % players)
		var nodes0: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		# keep the world still until we say so
		w.set_physics_process(false); w.effects.set_physics_process(false); w.missiles.set_physics_process(false)
		w.ai.set_physics_process(false); w.economy.set_process(false); w.research.set_process(false)
		w.territory.set_process(false); w.diplomacy.set_process(false)
		w.saves.autosave_every = 0

		# 1. who am I, who are they
		var me: Dictionary = w.map.nations[0]
		var names := {}
		var dup_names := PackedStringArray()
		for n in range(w.map.nations.size()):
			var nm := str(w.diplomacy.name_of(n)).strip_edges()
			if nm == "": dup_names.append("nation %d has no name" % n)
			elif names.has(nm): dup_names.append("two nations are called %s" % nm)
			names[nm] = true
		if dup_names.is_empty(): K.ok("identity", tag + " | names", ", ".join(PackedStringArray(names.keys())))
		else: K.fail("identity", tag + " | names", "; ".join(dup_names))
		if str(me.get("id", "")) == str(ids[sc.nation]): K.ok("identity", tag + " | I am who I chose", str(me.id))
		else: K.fail("identity", tag + " | I am who I chose", "chose %s, got '%s'" % [ids[sc.nation], me.get("id", "")])
		var worst := 9999.0
		var worst_pair := ""
		for a in range(w.map.nations.size()):
			for b in range(a + 1, w.map.nations.size()):
				var g := colour_gap(Color(str(w.map.nations[a].color)), Color(str(w.map.nations[b].color)))
				if g < worst: worst = g; worst_pair = "%s / %s" % [w.diplomacy.name_of(a), w.diplomacy.name_of(b)]
		if worst < 60.0: K.fail("identity", tag + " | colours", "%s are almost the same colour (gap %d)" % [worst_pair, int(worst)])
		elif worst < 100.0: K.warn("identity", tag + " | colours", "%s are close in colour (gap %d)" % [worst_pair, int(worst)])
		else: K.ok("identity", tag + " | colours", "closest pair gap %d" % int(worst))

		# 2. the starting town
		var hq := hq_of(0)
		var workers := own("worker")
		if hq.is_empty(): K.fail("start", tag + " | capital", "no capital"); continue
		var dry: bool = w.height_at(hq.root.position.x, hq.root.position.z) >= float(w.map.seaLevel) + 0.3
		if dry: K.ok("start", tag + " | capital on land", "")
		else: K.fail("start", tag + " | capital on land", "the capital stands in water")
		if workers.size() >= 3: K.ok("start", tag + " | workers", "%d" % workers.size())
		else: K.fail("start", tag + " | workers", "only %d workers at the start" % workers.size())
		var poor := PackedStringArray()
		for r in ["money", "food", "iron", "oil"]:
			if w.economy.res.has(r) and float(w.economy.res[r]) < 0.0: poor.append(r)
		if poor.is_empty(): K.ok("start", tag + " | no negative stock", "")
		else: K.fail("start", tag + " | no negative stock", "negative: " + ", ".join(poor))
		var enemies_near: int = w.units.filter(func(u): return u.owner != 0 and u.node.position.distance_to(w.start) < 45.0).size()
		if enemies_near == 0: K.ok("start", tag + " | nobody on my doorstep", "")
		else: K.fail("start", tag + " | nobody on my doorstep", "%d foreign units within 45 m of my capital at the start" % enemies_near)

		# 3. the careless customer: impossible orders, one after another
		var money0: float = w.economy.res.money
		var queued_before: int = 0
		var lodge = null
		for b in w.buildings:
			if b.owner == 0 and b.built and not b.dead and "worker" in b.def.get("trains", []): lodge = b; break
		if lodge != null:
			queued_before = lodge.queue.size()
			for k in range(8): w.queue_unit(lodge, "worker")
			step("eight workers queued in a row", tag)
			if lodge.queue.size() <= 5: K.ok("rude", tag + " | queue limit holds", "queue %d" % lodge.queue.size())
			else: K.fail("rude", tag + " | queue limit holds", "queue grew to %d" % lodge.queue.size())
			if w.economy.res.money <= money0: K.ok("rude", tag + " | queued units are paid for", "")
			else: K.fail("rude", tag + " | queued units are paid for", "money rose from %d to %d" % [money0, w.economy.res.money])
			w.cancel_queued(lodge, 99); w.cancel_queued(lodge, -1)
			step("cancel a unit that is not there", tag)
			while lodge.queue.size() > 0: w.cancel_queued(lodge, 0)
			if absf(w.economy.res.money - money0) < 1.0: K.ok("rude", tag + " | cancelling refunds everything", "")
			else: K.fail("rude", tag + " | cancelling refunds everything", "money %d before, %d after cancelling all" % [money0, w.economy.res.money])
		else:
			K.warn("rude", tag + " | worker queue", "no building that trains workers at the start")
		w.queue_unit(hq, "tank")
		step("queue a tank at the capital (it cannot)", tag)
		if workers.size() > 0:
			var far := Vector3(1.0e6, 0, -1.0e6)
			w.order_move(workers, far)
			step("order workers a million metres away", tag)
			w.order_move(workers, Vector3(NAN, 0, NAN) if false else Vector3(-5000.0, 0.0, 5000.0))
			step("order workers outside the map", tag)
			w.order_move(workers, w.start + Vector3(0, 0, 0))
			step("order workers onto their own position", tag)
			w.order_attack(workers, workers[0])
			step("order a worker to attack itself", tag)
			if workers[0].hp > 0 and not workers[0].dead: K.ok("rude", tag + " | self-attack is harmless", "")
			else: K.fail("rude", tag + " | self-attack is harmless", "a worker destroyed itself")
			var friend: Dictionary = w.spawn_unit("soldier", w.land_point(w.start + Vector3(10, 0, 10), 30.0), 0)
			var hp0: float = friend.hp
			w.order_attack(workers, friend)
			sim(4.0, false)
			step("order workers to attack a friendly soldier", tag)
			if friend.hp >= hp0 - 0.01: K.ok("rude", tag + " | no friendly fire by order", "")
			else: K.fail("rude", tag + " | no friendly fire by order", "a friendly soldier lost %d hp to an attack order from its own side" % int(hp0 - friend.hp))
		# building in absurd places
		var sea_point := Vector3.ZERO
		var found_sea := false
		for rr in range(20, 400, 20):
			for aa in range(16):
				var p: Vector3 = w.start + Vector3(cos(aa * TAU / 16.0), 0, sin(aa * TAU / 16.0)) * rr
				var edge: float = float(w.map.mapSize) * 0.5 - 6.0
				if absf(p.x) < edge and absf(p.z) < edge and w.height_at(p.x, p.z) < float(w.map.seaLevel) - 1.0: sea_point = p; found_sea = true; break
			if found_sea: break
		var problems := {
			"on top of the capital": hq.root.position,
			"a million metres away": Vector3(1.0e6, 0, 1.0e6),
			"below the map": Vector3(-9999.0, -50.0, -9999.0),
		}
		if found_sea: problems["in the sea"] = sea_point
		for what in problems:
			var why: String = w.site_problem("farm", problems[what], 0)
			var errs: Array = K.take_errors()
			if not errs.is_empty(): K.fail("rude", tag + " | build a farm " + what, "engine error: " + str(errs[0]))
			elif why == "": K.fail("rude", tag + " | build a farm " + what, "the game would allow it")
			else:
				K.ok("rude", tag + " | build a farm " + what, "refused: " + why)
				if what in ["a million metres away", "below the map"] and not (why.to_lower().contains("outside") or why.to_lower().contains("map") or why.to_lower().contains("edge")):
					K.warn("wording", tag + " | refusal text " + what, "a site off the map is refused as '%s': the player is told the wrong reason" % why)
		var cheap = find_site("farm")
		if cheap == null:
			K.warn("rude", tag + " | a legal farm site", "no legal farm site near the capital at the start")
		else:
			K.ok("rude", tag + " | a legal farm site", "")
			# no money: the customer clicks Build with an empty treasury
			var saved_res: Dictionary = w.economy.res.duplicate()
			for r in w.economy.res: w.economy.res[r] = 0.0
			var b_before: int = w.buildings.size()
			w.begin_placement("farm")
			var refused: bool = w.placing == ""
			w.cancel_placement()
			var sold: bool = w.build_site("farm", cheap)
			step("build a farm with an empty treasury", tag)
			if refused and not sold and w.buildings.size() == b_before: K.ok("rude", tag + " | no building on credit", "")
			else: K.fail("rude", tag + " | no building on credit", "refused=%s sold=%s buildings %d -> %d" % [refused, sold, b_before, w.buildings.size()])
			for r in saved_res: w.economy.res[r] = saved_res[r]
			# with money: a real farm, built by the real workers
			var pay0: float = w.economy.res.money
			var built_ok: bool = w.build_site("farm", cheap)
			step("build a farm with money", tag)
			if built_ok and w.economy.res.money < pay0: K.ok("build", tag + " | a farm is paid for", "-%d" % int(pay0 - w.economy.res.money))
			else: K.fail("build", tag + " | a farm is paid for", "built=%s money %d -> %d" % [built_ok, pay0, w.economy.res.money])
			var again: String = w.site_problem("farm", cheap, 0)
			if again != "": K.ok("build", tag + " | a second farm on the same spot is refused", again)
			else: K.fail("build", tag + " | a second farm on the same spot is refused", "the game allows two farms on one spot")
		# demolish: twice
		var spare = null
		for b in w.buildings:
			if b.owner == 0 and b.built and not b.dead and b.key != "hq": spare = b; break
		if spare != null:
			w.demolish(spare)
			w.demolish(spare)
			step("demolish the same building twice", tag)
		# the rude queue of orders: research that does not exist
		var bad_res: String = w.research.enqueue("notAThing")
		step("research a discovery that does not exist", tag, "answer: '%s'" % bad_res)
		if "notAThing" in w.research.queue:
			K.fail("rude", tag + " | unknown research refused", "an invented discovery sits in the research queue")
			w.research.queue.erase("notAThing")
		elif bad_res != "": K.ok("rude", tag + " | unknown research refused", bad_res)
		else: K.fail("rude", tag + " | unknown research refused", "no refusal")

		# 4. a real research and a real stretch of game
		var started := ""
		for key in w.research.discoveries.keys():
			if w.research.available(key) and w.research.shown(key):
				var reply: String = w.research.enqueue(key)
				if reply == "": started = key; break
		if started != "": K.ok("research", tag + " | research starts", started)
		else: K.warn("research", tag + " | research starts", "nothing available to start in the opening")
		var stock0: Dictionary = w.economy.res.duplicate()
		var units0: int = w.units.size()
		var wall := Time.get_ticks_msec()
		sim(60.0)
		var wall_s := (Time.get_ticks_msec() - wall) / 1000.0
		step("sixty seconds of play", tag, "%.1f s of real time" % wall_s)
		var nan_units := 0
		var lost := 0
		for u in w.units:
			if u.dead: continue
			if not finite(u.node.position): nan_units += 1
			elif absf(u.node.position.x) > 4000.0 or absf(u.node.position.z) > 4000.0: lost += 1
		if nan_units == 0: K.ok("sim", tag + " | no unit at an impossible position", "")
		else: K.fail("sim", tag + " | no unit at an impossible position", "%d units have a NaN/infinite position" % nan_units)
		if lost == 0: K.ok("sim", tag + " | nobody wandered off the map", "")
		else: K.fail("sim", tag + " | nobody wandered off the map", "%d units are more than 4 km out" % lost)
		var changed := false
		for r in stock0:
			if absf(float(w.economy.res[r]) - float(stock0[r])) > 0.5: changed = true
		if changed: K.ok("sim", tag + " | the economy moves", "")
		else: K.fail("sim", tag + " | the economy moves", "no stock changed in a minute")
		if wall_s > 25.0: K.warn("sim", tag + " | speed", "one game minute took %.0f s of real time" % wall_s)
		var rival_units: int = w.units.filter(func(u): return u.owner > 0 and not u.dead).size()
		var rival_blds: int = w.buildings.filter(func(b): return b.owner > 0 and not b.dead).size()
		if rival_blds > 0 and rival_units > 0: K.ok("ai", tag + " | the rivals live", "%d buildings, %d units" % [rival_blds, rival_units])
		else: K.fail("ai", tag + " | the rivals live", "%d buildings and %d units among the rivals" % [rival_blds, rival_units])
		if w.economy.pop_used <= w.economy.pop_cap + 2: K.ok("sim", tag + " | population within the cap", "%d/%d" % [w.economy.pop_used, w.economy.pop_cap])
		else: K.fail("sim", tag + " | population within the cap", "%d used of %d" % [w.economy.pop_used, w.economy.pop_cap])

		# 5. diplomacy by a difficult customer
		var others := range(1, w.map.nations.size())
		var diplo_bad := PackedStringArray()
		for o in others:
			var replies := [w.diplomacy.offer_peace(o), w.diplomacy.gift(o), w.diplomacy.propose_pact(o), w.diplomacy.propose_nap(o), w.diplomacy.propose_alliance(o)]
			for rep in replies:
				if not (rep is String): diplo_bad.append("a reply that is not text")
			var st := str(w.diplomacy.status_text(o))
			if st.strip_edges() == "": diplo_bad.append("nation %d has an empty status" % o)
		w.diplomacy.offer_peace(0)
		w.diplomacy.declare_war(0, 0)
		w.diplomacy.propose_alliance(0)
		step("diplomacy with everyone, and with myself", tag)
		if diplo_bad.is_empty(): K.ok("diplomacy", tag + " | every reply is text and every status is filled", "")
		else: K.fail("diplomacy", tag + " | replies", "; ".join(diplo_bad.slice(0, 3)))
		if not w.diplomacy.at_war(0, 0) and not w.diplomacy.allied(0, 0): K.ok("diplomacy", tag + " | no war or alliance with myself", "")
		else: K.fail("diplomacy", tag + " | no war or alliance with myself", "at_war=%s allied=%s" % [w.diplomacy.at_war(0, 0), w.diplomacy.allied(0, 0)])
		if others.size() > 0:
			w.diplomacy.declare_war(0, 1)
			var war_ok: bool = w.diplomacy.at_war(0, 1)
			var peace_text := str(w.diplomacy.offer_peace(1))
			sim(10.0)
			step("declare war, ask for peace, play ten seconds", tag)
			if war_ok: K.ok("diplomacy", tag + " | war can be declared", "")
			else: K.fail("diplomacy", tag + " | war can be declared", "declare_war did not put us at war")
			if peace_text.strip_edges() != "": K.ok("diplomacy", tag + " | asking for peace gets an answer", peace_text.substr(0, 60))
			else: K.fail("diplomacy", tag + " | asking for peace gets an answer", "empty reply")

		# 6. save in the middle of it, then load it back
		var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		var why: String = w.saves.problem_with(data)
		if why == "": K.ok("save", tag + " | the save passes its own check", "")
		else: K.fail("save", tag + " | the save passes its own check", why)
		var b_count: int = w.buildings.filter(func(b): return not b.dead).size()
		var u_count: int = w.units.filter(func(u): return not u.dead).size()
		var time_was: float = w.game_time
		var money_was: float = w.economy.res.money
		step("capture", tag)
		w.saves.restore(data)
		step("restore", tag)
		var b_after: int = w.buildings.filter(func(b): return not b.dead).size()
		var u_after: int = w.units.filter(func(u): return not u.dead).size()
		if absi(b_after - b_count) <= 1: K.ok("save", tag + " | buildings survive a load", "%d -> %d" % [b_count, b_after])
		else: K.fail("save", tag + " | buildings survive a load", "%d before, %d after" % [b_count, b_after])
		if absi(u_after - u_count) <= maxi(2, u_count / 20): K.ok("save", tag + " | units survive a load", "%d -> %d" % [u_count, u_after])
		else: K.fail("save", tag + " | units survive a load", "%d before, %d after" % [u_count, u_after])
		if absf(w.game_time - time_was) < 2.0: K.ok("save", tag + " | the clock survives a load", "")
		else: K.fail("save", tag + " | the clock survives a load", "%.1f before, %.1f after" % [time_was, w.game_time])
		if absf(w.economy.res.money - money_was) < maxf(50.0, money_was * 0.02): K.ok("save", tag + " | the treasury survives a load", "")
		else: K.fail("save", tag + " | the treasury survives a load", "%d before, %d after" % [money_was, w.economy.res.money])
		sim(15.0)
		step("fifteen seconds after loading", tag)

		# 7. the long wait: four more game minutes, and then the customer asks "what did I get for my time?"
		var farm_list: Array = w.buildings.filter(func(b): return b.owner == 0 and b.key == "farm" and not b.dead)
		var barracks = null
		for b in w.buildings:
			if b.owner == 0 and b.built and not b.dead and "soldier" in b.def.get("trains", []): barracks = b; break
		if barracks == null:
			var spot = find_site("barracks")
			if spot != null:
				barracks = w.place_building("barracks", spot, 0, true)
				K.take_errors()
		var soldiers0: int = own("soldier").size()
		if barracks != null:
			w.queue_unit(barracks, "soldier")
			w.queue_unit(barracks, "soldier")
		var research_progress0: float = 0.0
		if started != "": research_progress0 = float(w.research.progress.get(started, {}).get("work", 0.0)) + 100.0 * float(w.research.stage_of(started))
		var wall2 := Time.get_ticks_msec()
		sim(240.0)
		var wall2_s := (Time.get_ticks_msec() - wall2) / 1000.0
		step("four more minutes", tag, "%.1f s of real time" % wall2_s)
		if wall2_s > 60.0: K.warn("sim", tag + " | speed", "four game minutes took %.0f s of real time" % wall2_s)
		if w.game_over == "": K.ok("sim", tag + " | no instant defeat or victory", "")
		else: K.fail("sim", tag + " | no instant defeat or victory", "game over ('%s') about six minutes into the match" % w.game_over)
		var unfinished: int = farm_list.filter(func(b): return not b.built).size()
		if farm_list.is_empty(): K.warn("build", tag + " | the farm I ordered", "the farm is gone from the list")
		elif unfinished == 0: K.ok("build", tag + " | the farm I ordered gets finished", "")
		else: K.fail("build", tag + " | the farm I ordered gets finished", "%d of %d farms still unfinished after five minutes" % [unfinished, farm_list.size()])
		if barracks != null:
			var soldiers1: int = own("soldier").size()
			if soldiers1 >= soldiers0 + 2: K.ok("train", tag + " | two soldiers trained", "%d -> %d" % [soldiers0, soldiers1])
			else: K.fail("train", tag + " | two soldiers trained", "%d -> %d after four minutes (queue %d)" % [soldiers0, soldiers1, barracks.queue.size()])
		else: K.warn("train", tag + " | soldiers", "no building that trains soldiers at the start")
		if started != "":
			var progress1: float = float(w.research.progress.get(started, {}).get("work", 0.0)) + 100.0 * float(w.research.stage_of(started))
			if progress1 > research_progress0 or w.research.done(started): K.ok("research", tag + " | research progresses", started)
			else: K.fail("research", tag + " | research progresses", "'%s' did not move in four minutes" % started)
		var income: float = float(w.economy.rates.get("money", 0.0))
		if income > 0.0: K.ok("economy", tag + " | income is positive", "%.1f a second" % income)
		else: K.warn("economy", tag + " | income is positive", "income %.1f a second after six minutes" % income)
		var nan2 := 0
		for u in w.units:
			if not u.dead and not finite(u.node.position): nan2 += 1
		if nan2 == 0: K.ok("sim", tag + " | still no impossible positions", "")
		else: K.fail("sim", tag + " | still no impossible positions", "%d units with a NaN position" % nan2)
		var nodes1: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var orphans1: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		if nodes1 < 1.6 * nodes0 + 2000.0: K.ok("leak", tag + " | scene nodes stay bounded", "%d -> %d" % [nodes0, nodes1])
		else: K.fail("leak", tag + " | scene nodes stay bounded", "%d nodes after boot, %d after six minutes" % [nodes0, nodes1])
		if orphans1 < 400.0: K.ok("leak", tag + " | no pile of orphan nodes", "%d" % orphans1)
		else: K.fail("leak", tag + " | no pile of orphan nodes", "%d orphans: something is created and never freed" % orphans1)
		var total_units: int = w.units.filter(func(u): return not u.dead).size()
		if total_units <= 700: K.ok("leak", tag + " | unit count sane", "%d" % total_units)
		else: K.warn("leak", tag + " | unit count sane", "%d live units after six minutes" % total_units)
		var data2: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		var size_a: int = JSON.stringify(data2).length()
		w.saves.restore(data2)
		var after_dict: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		var size_b: int = JSON.stringify(after_dict).length()
		var drift := PackedStringArray()
		for k in data2:
			var ka: int = JSON.stringify(data2[k]).length()
			var kb: int = JSON.stringify(after_dict.get(k, null)).length()
			if absi(ka - kb) > 300: drift.append("%s %d->%d" % [k, ka, kb])
		step("a second capture and restore", tag)
		if absf(float(size_b - size_a)) <= 0.03 * float(size_a): K.ok("save", tag + " | save, load, save is stable", "%d -> %d bytes" % [size_a, size_b])
		else: K.fail("save", tag + " | save, load, save is stable", "%d bytes, then %d: each load changes the game (%s)" % [size_a, size_b, ", ".join(drift.slice(0, 4))])
		data2 = JSON.parse_string(JSON.stringify(w.saves.capture()))
		var why2: String = w.saves.problem_with(data2)
		if why2 == "": K.ok("save", tag + " | a six-minute save is sound", "")
		else: K.fail("save", tag + " | a six-minute save is sound", why2)
		var ai_pop: int = w.units.filter(func(u): return u.owner > 0 and not u.dead).size()
		var ai_blds2: int = w.buildings.filter(func(b): return b.owner > 0 and not b.dead).size()
		if ai_blds2 >= rival_blds and ai_pop >= 1: K.ok("ai", tag + " | the rivals keep growing", "%d buildings, %d units" % [ai_blds2, ai_pop])
		else: K.fail("ai", tag + " | the rivals keep growing", "buildings %d -> %d, units %d" % [rival_blds, ai_blds2, ai_pop])
		var secs := (Time.get_ticks_msec() - t0) / 1000
		K.ok("play", tag + " | finished", "%d s of real time" % secs)
		if not is_instance_valid(w): break
	quit(K.finish())
