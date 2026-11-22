extends SceneTree
const A = preload("res://scripts/airlift.gd")
var w: Node
var errors: Array[String] = []
var passed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)
func run() -> void:
	set_meta("match_config", {"map":"island", "players":3, "nation":0})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	if w == null: quit(2); return
	if w.menu._root == null: w.menu.setup(w)
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	w.set_physics_process(false); w.ai.set_physics_process(false)
	var p: Vector3 = w.land_point(w.start, 70.0)
	var heli: Dictionary = w.spawn_unit("helicopter", p, 0)
	var soldier: Dictionary = w.spawn_unit("soldier", p + Vector3(60,0,0), 0)   # beyond BOARD_REACH (22 m), or he boards at once
	check(A.order_board(w, [soldier], heli) == 1, "transport accepts a boarding order")
	w.order_move([soldier], p + Vector3(40,0,0))
	check(soldier.get("board") == null, "a new move cancels the old boarding order")
	soldier.node.position = heli.node.position
	A.update(w)
	check(not soldier.dead and A.used(heli) == 0, "passing a helicopter after cancellation does not swallow the soldier")
	# The helicopter flew out for a boarding party that was then cancelled: on arrival it takes only those still boarding.
	heli.pickup_go = heli.node.position
	heli.pickup_sweep = false
	A.update(w)
	check(not soldier.get("stowed", false) and A.used(heli) == 0, "a pickup for a cancelled boarding does not sweep up the soldier")
	if soldier.dead: soldier = w.spawn_unit("soldier", p, 0)
	var enemy: Dictionary = w.spawn_unit("soldier", p + Vector3(30,0,0), 1)
	A.order_board(w, [soldier], heli)
	w.order_attack([soldier], enemy)
	check(soldier.get("board") == null, "an attack order cancels boarding")
	soldier.board = null
	# A saved/parked helicopter at an invalid location must not bypass terrain validation.
	heli.cargo = [{"key":"soldier", "hp":60.0, "places":1, "xp":0.0}]
	var sea := Vector3.ZERO
	var found := false
	for x in range(-450,451,15):
		for z in range(-450,451,15):
			if w.height_at(x,z) < float(w.map.seaLevel) - 0.3:
				sea = Vector3(x,30,z); found = true; break
		if found: break
	check(found, "fixture found actual water")
	heli.node.position = sea; heli.air_state = "parked"
	check(A.unload_blocked(w, heli) != "", "parked state cannot bypass the water check")
	var unloaded: Array = A.unload(w, heli)
	check(unloaded.is_empty() and heli.cargo.size() == 1, "failed landing retains cargo and creates no soldier in water")
	heli.node.position = p; heli.air_state = "ready"
	heli.cargo = [{"key":"soldier", "hp":60.0, "places":1, "xp":0.0}]
	unloaded = A.unload(w, heli)
	check(unloaded.size() == 1 and heli.cargo.is_empty(), "valid landing transfers exactly one passenger")
	check(unloaded.all(func(u): return w.open_ground(u.node.position) and w.walkable(u.node.position.x,u.node.position.z)), "landed soldiers stand on walkable ground outside buildings")
	check(unloaded.all(func(u): return is_equal_approx(float(u.hp),60.0)), "landing preserves wounded passenger health")
	var spare: Dictionary = w.spawn_unit("helicopter", p, 0)
	heli.cargo = [{"key":"soldier", "places":6}]
	var first: Dictionary = w.spawn_unit("soldier", p, 0)
	var replacement: Dictionary = w.spawn_unit("soldier", p, 0)
	w.hud._fill_cargo([heli, spare, first])
	w.hud._fill_cargo([heli, spare, replacement])
	var buttons: Array = w.hud._cargo_row.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Board selected"))
	check(buttons.size() == 1, "mixed selection offers boarding when a selected helicopter has room")
	if not buttons.is_empty(): buttons[0].pressed.emit()
	check(A.used(spare) == 1 and replacement.get("stowed", false) and not first.get("stowed", false), "boarding uses the current troops and skips a full first transport")
	var rendezvous: Vector3 = w.land_point(w.start, 140.0)
	var transport_a: Dictionary = w.spawn_unit("helicopter", rendezvous, 0)
	var transport_b: Dictionary = w.spawn_unit("helicopter", rendezvous, 0)
	var walking: Dictionary = w.spawn_unit("soldier", rendezvous + Vector3(24, 0, 0), 0)
	walking.node.position = rendezvous + Vector3(24, 0, 0)
	transport_a.cargo = [{"key":"soldier", "places":5}]
	check(A.load_nearby(w, [transport_a, transport_b], 26.0) == 1 and is_same(walking.get("board"), transport_a), "loading with two transports assigns a distant passenger once")
	var late_arrival: Dictionary = w.spawn_unit("soldier", rendezvous, 0)
	check(A.order_board(w, [late_arrival], transport_a) == 0, "the last place is reserved for the passenger already walking to board")
	w.order_move([walking], rendezvous)
	check(A.order_board(w, [late_arrival], transport_a) == 1, "cancelling a boarding order releases its reserved place")
	print("CUSTOMER_AIRLIFT %s %d checks" % ["PASS" if errors.is_empty() else "FAIL", passed + errors.size()])
	quit(0 if errors.is_empty() else 1)
