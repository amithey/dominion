extends SceneTree
## Why does a long campaign get heavier? A scripted builder plays a real match for N game minutes at high
## speed (real frames, so the interface, minimap, fog and every _process run as in play) and every game minute
## records what it cost and what grew: milliseconds a frame (script/process and physics, from the engine's own
## monitors), real seconds the minute took, units, buildings, scene nodes, orphans, memory, and the size of
## every array and dictionary kept by the world and its systems. At the end it names what grew most.
## The builder: every game minute it funds the treasury, places a few buildings at once (the next in a
## rotation), queues units at every trainer, and every four minutes declares war on the nearest rival and
## sends the army against its capital, so towns, armies, roads, wrecks, logs and the AI all accumulate.
## Usage: --minutes=40 --scale=8 --nation=0 --map=island --players=4 --difficulty=normal --tag=name --no-builder
## Output: res://build/audit/growth-<tag>.csv and the summary on the console.
const Registry := preload("res://scripts/nation_registry.gd")
const MatchSetup := preload("res://scripts/match_setup.gd")
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
var rows: Array = []
var first_sizes: Dictionary = {}
var last_sizes: Dictionary = {}
var first_subtrees: Dictionary = {}
var last_subtrees: Dictionary = {}
func _initialize() -> void: call_deferred("run")

const ROTATION := ["farm", "housing", "barracks", "workerHouse", "extractor", "school", "residential", "tankFactory", "market", "warehouse", "library", "hospital", "powerPlant", "cottage", "foodDepot", "policeStation", "university", "bank", "park", "apartments", "stadium", "bunker", "samSite", "helipad", "ammoDepot", "techPark"]

func arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name): return a.split("=")[1]
	return fallback

func count_nodes(n: Node) -> int:
	var c := 1
	for k in n.get_children(): c += count_nodes(k)
	return c

## Sizes of every collection a node keeps in its own script variables.
func sizes_of(node: Object, label: String, into: Dictionary) -> void:
	if node == null: return
	for p in node.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0: continue
		var v = node.get(p.name)
		if v is Array or v is Dictionary:
			into["%s.%s" % [label, p.name]] = v.size()
		elif v is PackedVector3Array or v is PackedVector2Array or v is PackedInt32Array or v is PackedFloat32Array:
			into["%s.%s" % [label, p.name]] = v.size()

func collect_sizes() -> Dictionary:
	var out := {}
	sizes_of(w, "world", out)
	for name in ["economy", "ai", "effects", "missiles", "territory", "logistics", "diplomacy", "research", "market", "espionage", "hud", "events", "support", "victory", "space", "un", "wmd", "fog", "generals", "defcon", "crisis", "directorate", "minimap", "stats", "saves"]:
		var n = w.get(name)
		if n != null: sizes_of(n, name, out)
	return out

func subtrees() -> Dictionary:
	var out := {}
	for k in w.get_children(): out[str(k.name)] = count_nodes(k)
	return out

func own_buildings() -> Array:
	return w.buildings.filter(func(b): return b.owner == 0 and not b.dead)

func home_hex() -> Vector2i:
	return w.logistics.world_hex(w.start)

func find_site(key: String, max_ring: int) -> Variant:
	for ring in range(1, max_ring):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home_hex() + Vector2i(q, r)
				if w.logistics.hex_distance(home_hex(), h) != ring: continue
				var at: Vector3 = w.logistics.hex_center(h)
				if w.site_problem(key, at, 0) == "": return at
	return null

func grant_land(rings: int) -> void:
	for q in range(-rings, rings + 1):
		for r in range(-rings, rings + 1):
			var h := home_hex() + Vector2i(q, r)
			if w.logistics.hex_distance(home_hex(), h) <= rings:
				var i: int = w.territory.index_of(w.territory.hex_at(w.logistics.hex_center(h)))
				if i >= 0 and w.territory.owner_of[i] < 0:
					w.territory.owner_of[i] = 0
					w.territory.control[i] = 80.0

var rotation_at := 0
func build_some(n: int, max_ring: int) -> void:
	for k in range(n):
		var key: String = ROTATION[rotation_at % ROTATION.size()]
		rotation_at += 1
		if not w.building_defs.has(key): continue
		var at = find_site(key, max_ring)
		if at == null: continue
		var b: Dictionary = w.place_building(key, at, 0, true)
		if b.is_empty(): continue
		w.close_navigation(b.root.position, w.DISTRICT_NAV_SIZE if w.is_district(key) else b.footprint)
	w.economy.recalculate()

func train_some() -> void:
	for b in own_buildings():
		if not b.built or b.queue.size() >= 3: continue
		var options: Array = b.def.get("trains", []).filter(func(k): return k != "worker" and not w.unit_defs.get(k, {}).get("fly", false))
		if options.is_empty(): continue
		w.queue_unit(b, options[randi() % options.size()])

func attack_nearest() -> void:
	var best := -1
	var best_d := INF
	var target := Vector3.ZERO
	for n in range(1, w.map.nations.size()):
		for b in w.buildings:
			if b.owner == n and b.key == "hq" and not b.dead:
				var d: float = b.root.position.distance_to(w.start)
				if d < best_d: best_d = d; best = n; target = b.root.position
	if best < 0: return
	w.diplomacy.declare_war(0, best)
	var army: Array = w.units.filter(func(u): return u.owner == 0 and not u.dead and u.key != "worker" and not u.get("fly", false) and not u.get("naval", false))
	if not army.is_empty(): w.order_move(army, w.land_point(target, 40.0), true)

func run() -> void:
	var minutes := int(arg("minutes", "40"))
	var scale := float(arg("scale", "8"))
	var nation := int(arg("nation", "0"))
	var map_key := arg("map", "island")
	var players := clampi(int(arg("players", "4")), 2, MatchSetup.capacity(map_key))
	var difficulty := arg("difficulty", "normal")
	var tag := arg("tag", "%s-%s-%dm" % [Registry.column("id")[nation], map_key, minutes])
	var builder := not ("--no-builder" in OS.get_cmdline_user_args())
	seed(20261031)
	DirAccess.make_dir_recursive_absolute("res://build/audit")
	set_meta("match_config", {"map": map_key, "players": players, "nation": nation})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null:
		print("GROWTH FAIL: the world did not start")
		quit(1)
		return
	var old = w.menu
	w.menu = QuietMenu.new()
	w.add_child(w.menu)
	w.menu.setup(w)
	old.queue_free()
	w.menu.set_fullscreen(false)
	root.size = Vector2i(1280, 800)
	w.start_match(difficulty)
	w.menu.close()
	w.saves.autosave_every = 0
	w.edge_scroll = false
	if is_instance_valid(w.hud._guide): w.hud._guide.queue_free(); w.hud._guide = null
	for i in range(10): await process_frame
	grant_land(8)
	var funds: GDScript = preload("res://tools/test_kit.gd")
	Engine.time_scale = scale
	var next_minute := 60.0
	var minute := 0
	var wall_minute_start := Time.get_ticks_msec()
	var frames := 0
	var proc_sum := 0.0
	var phys_sum := 0.0
	var errors := 0
	var wall_total := Time.get_ticks_msec()
	print("GROWTH start: %s on %s, %d players, %d game minutes at x%.0f" % [Registry.column("id")[nation], map_key, players, minutes, scale])
	var header := "minute,real_s,frames,process_ms,physics_ms,fps,cpu_ms_per_game_s,units,buildings,nodes,orphans,objects,mem_mb,territory,rival_units,rival_buildings"
	rows.append(header)
	var guard := 0
	while minute < minutes and guard < 4000000:
		guard += 1
		await process_frame
		if not is_instance_valid(w) or current_scene != w:
			print("GROWTH FAIL: the match ended (the scene changed) at minute %d" % minute)
			break
		frames += 1
		if minute >= 1: watch_nan()
		proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if w.game_time >= next_minute:
			minute += 1
			next_minute += 60.0
			var real := (Time.get_ticks_msec() - wall_minute_start) / 1000.0
			var live_units: int = w.units.filter(func(u): return not u.dead).size()
			var live_buildings: int = w.buildings.filter(func(b): return not b.dead).size()
			var rival_units: int = w.units.filter(func(u): return u.owner > 0 and not u.dead).size()
			var rival_buildings: int = w.buildings.filter(func(b): return b.owner > 0 and not b.dead).size()
			var owned := 0
			for o in w.territory.owner_of: if o == 0: owned += 1
			var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			var row := "%d,%.1f,%d,%.2f,%.2f,%.0f,%.1f,%d,%d,%d,%d,%d,%.0f,%d,%d,%d" % [minute, real, frames, proc_sum / maxf(frames, 1), phys_sum / maxf(frames, 1), Engine.get_frames_per_second(), (proc_sum + phys_sum) / 60.0, live_units, live_buildings, nodes, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, owned, rival_units, rival_buildings]
			rows.append(row)
			print("GROWTH ", row)
			if minute == 2:
				first_sizes = collect_sizes()
				first_subtrees = subtrees()
			last_sizes = collect_sizes() if minute >= minutes - 1 or minute % 10 == 0 else last_sizes
			if minute >= minutes - 1: last_subtrees = subtrees()
			if minute % int(arg("probe-every", "5")) == 0 or minute == 2: probe(minute)
			wall_minute_start = Time.get_ticks_msec()
			frames = 0
			proc_sum = 0.0
			phys_sum = 0.0
			if minute == int(arg("save-at", "0")):
				var sf := FileAccess.open("res://build/audit/late-%s.json" % tag, FileAccess.WRITE)
				sf.store_string(JSON.stringify(w.saves.capture()))
				sf.close()
				print("GROWTH saved the state at minute %d" % minute)
			if builder:
				funds.fund(w)
				if minute % 5 == 0: grant_land(8 + minute / 5)
				build_some(3, 10 + minute / 4)
				train_some()
				if minute % 4 == 0: attack_nearest()
	Engine.time_scale = 1.0
	var f := FileAccess.open("res://build/audit/growth-%s.csv" % tag, FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(rows)))
	f.close()
	summary(tag)
	quit(0)

var nan_reports := 0
## The first unit whose position (or any vector it carries) stops being a finite number: what it was doing.
func watch_nan() -> void:
	if nan_reports >= 4: return
	for u in w.units:
		var bad := ""
		var p: Vector3 = u.node.position
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): bad = "position"
		# (infinity is the game's own "no goal" marker, e.g. path_goal; only NaN is a fault)
		for k in u:
			var v = u[k]
			if v is Vector3 and (is_nan(v.x) or is_nan(v.y) or is_nan(v.z)) and bad == "": bad = str(k)
			if v is Array and bad == "":
				for e in v:
					if e is Vector3 and (is_nan(e.x) or is_nan(e.y) or is_nan(e.z)): bad = str(k) + "[]"; break
		if bad != "":
			nan_reports += 1
			var facts := PackedStringArray()
			for k in u:
				var v = u[k]
				if v is bool or v is int or v is float or v is String or v is Vector3: facts.append("%s=%s" % [k, str(v)])
				elif v is Array: facts.append("%s=[%d]" % [k, v.size()])
			print("GROWTH NAN at game %.0f s: a %s of nation %d has a non-finite %s | %s" % [w.game_time, u.key, u.owner, bad, " ".join(facts).substr(0, 900)])
			return

## Hand-timed cost of every scripted system's _process and _physics_process (mean of a few calls, microsecond clock):
## label -> [process ms, physics ms]. A few calls advance the world by a few hundredths of a second: harmless.
var probes: Dictionary = {}   # minute -> {label: [p, f]}
func probe(minute: int) -> void:
	var nodes: Array = []
	var stack: Array = [w]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes.append(n)
		for k in n.get_children(): stack.append(k)
	var out := {}
	var total := 0.0
	for n in nodes:
		if n.get_script() == null: continue
		var label := "%s (%s)" % [n.get_script().resource_path.get_file(), n.name]
		var p := 0.0
		var f := 0.0
		if n.has_method("_process"):
			for i in range(6):
				var t0 := Time.get_ticks_usec()
				n._process(1.0 / 60.0)
				p += Time.get_ticks_usec() - t0
		if n.has_method("_physics_process"):
			for i in range(6):
				var t0 := Time.get_ticks_usec()
				n._physics_process(1.0 / 60.0)
				f += Time.get_ticks_usec() - t0
		out[label] = [p / 6000.0, f / 6000.0]
		total += p / 6000.0 + f / 6000.0
	out["TOTAL"] = [total, 0.0]
	probes[minute] = out
	var top := []
	for k in out: if k != "TOTAL": top.append([out[k][0] + out[k][1], k])
	top.sort_custom(func(a, b): return a[0] > b[0])
	print("GROWTH PROBE minute %d: %.1f ms for one frame and tick by hand | %s" % [minute, total, " | ".join(PackedStringArray(top.slice(0, 5).map(func(t): return "%s %.1f" % [t[1], t[0]])))])

func column(i: int) -> Array:
	var out := []
	for r in range(1, rows.size()): out.append(float(rows[r].split(",")[i]))
	return out

func mean(a: Array) -> float:
	if a.is_empty(): return 0.0
	var s := 0.0
	for v in a: s += float(v)
	return s / a.size()

func summary(tag: String) -> void:
	if rows.size() < 8:
		print("GROWTH too short to judge")
		return
	var n := rows.size() - 1
	var span := mini(4, n / 3)
	var cols := {"cpu ms per game second": 6, "process ms/frame": 3, "physics ms/frame": 4, "real_s per game min": 1, "units": 7, "buildings": 8, "nodes": 9, "orphans": 10, "objects": 11, "mem_mb": 12}
	print("GROWTH ---- early (minutes 2-%d) against late (last %d minutes)" % [2 + span - 1, span])
	for name in cols:
		var c: Array = column(cols[name])
		var early := mean(c.slice(1, 1 + span))
		var late := mean(c.slice(c.size() - span, c.size()))
		print("GROWTH %-24s %9.2f -> %9.2f  x%.2f" % [name, early, late, late / maxf(early, 0.001)])
	if probes.size() >= 2:
		var minutes_keys: Array = probes.keys()
		minutes_keys.sort()
		var first: Dictionary = probes[minutes_keys[0]]
		var last: Dictionary = probes[minutes_keys[minutes_keys.size() - 1]]
		print("GROWTH ---- hand-timed systems, minute %d against minute %d (ms for one frame plus one physics tick)" % [minutes_keys[0], minutes_keys[minutes_keys.size() - 1]])
		var prow := []
		for k in last: prow.append([last[k][0] + last[k][1], k, (first.get(k, [0.0, 0.0])[0] + first.get(k, [0.0, 0.0])[1])])
		prow.sort_custom(func(a, b): return a[0] > b[0])
		for r in prow.slice(0, 12): print("GROWTH   %-44s %7.2f -> %7.2f" % [r[1], r[2], r[0]])
		print("GROWTH series of the whole: ", " ".join(PackedStringArray(minutes_keys.map(func(m): return "m%d=%.1f" % [m, probes[m]["TOTAL"][0]]))))
	var growers := []
	for k in last_sizes:
		var a: int = int(first_sizes.get(k, 0))
		var b: int = int(last_sizes[k])
		if b - a >= 200: growers.append([b - a, k, a, b])
	growers.sort_custom(func(x, y): return x[0] > y[0])
	print("GROWTH ---- collections that grew most (script variables)")
	for g in growers.slice(0, 20): print("GROWTH   %-44s %7d -> %7d  (+%d)" % [g[1], g[2], g[3], g[0]])
	var trees := []
	for k in last_subtrees:
		var a: int = int(first_subtrees.get(k, 0))
		var b: int = int(last_subtrees[k])
		if b - a >= 100: trees.append([b - a, k, a, b])
	trees.sort_custom(func(x, y): return x[0] > y[0])
	print("GROWTH ---- scene subtrees that grew most (nodes)")
	for g in trees.slice(0, 12): print("GROWTH   %-44s %7d -> %7d  (+%d)" % [g[1], g[2], g[3], g[0]])
	print("GROWTH file: res://build/audit/growth-%s.csv" % tag)
