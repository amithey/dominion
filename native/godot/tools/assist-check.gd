extends SceneTree
## Idle troops answer a fight beside them (world.update_combat, Tactics.pick_target
## engaged_with): an idle tank 35 m from an enemy that is shooting at its side
## turns on it, though it is past the tank's own sight (26 m); not an enemy
## that is fighting no one; not a tank on a move order; and not past the
## distance it would chase anyway (1.6 times its sight).
var errors: Array[String] = []
var passed := 0
var w: Node
const DT := 1.0 / 15.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func sim(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		w._physics_process(DT)
		w.effects._physics_process(DT)
		t += DT

## A point offset from the open ground chosen in run(), on the ground there (not moved: the distances are the test).
var origin := Vector3.ZERO
func flat(at: Vector3) -> Vector3:
	return Vector3(at.x, w.height_at(at.x, at.z), at.z)

func run() -> void:
	set_meta("match_config", {"map": "pangaea", "players": 2, "nation": 0, "style": "sandbox"})
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
	w.effects.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.diplomacy.declare_war(1, 0)
	# Open ground well away from both capitals.
	# (a stretch of dry, level ground near your capital, 140 m square)
	var spot: Vector3 = Vector3.INF
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for k in range(24):
		var c: Vector3 = home + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 24.0) * 150.0
		var dry := true
		for x in range(-70, 71, 10):
			for z in range(-70, 121, 10):
				if w.height_at(c.x + x, c.z + z) < 1.5: dry = false
		if dry:
			spot = c
			break
	check(spot != Vector3.INF, "open dry ground to test on")
	var cases := []
	# 1: an enemy 35 m off, shooting at one of yours.
	var mine: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(10, 0, 0)), 0)
	var guard: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(-35, 0, 0)), 0)
	var raider: Dictionary = w.spawn_unit("tank", spot, 1)
	var sight: float = maxf(guard.aggro, guard.range)
	var gap: float = guard.node.position.distance_to(raider.node.position)
	check(gap > sight and gap < sight * 1.6, "the setting: the raider is %d m from the idle tank, past its sight (%d m), within 1.6 times it" % [int(gap), int(sight)])
	raider.enemy = mine
	for t in range(30):
		sim(0.2)
		raider.enemy = mine if not mine.dead else raider.enemy
		if guard.enemy != null: break
	check(is_same(guard.enemy, raider), "an idle tank 35 m away turns on an enemy shooting at its side")
	for u in [mine, guard, raider]: if not u.dead: w.kill(u)
	# 2: the same enemy fighting no one.
	guard = w.spawn_unit("tank", flat(spot + Vector3(-35, 0, 40)), 0)
	raider = w.spawn_unit("tank", flat(spot + Vector3(0, 0, 40)), 1)
	raider.target = raider.node.position   # (held: it neither moves nor looks for a fight)
	sim(3.0)
	check(guard.enemy == null, "an enemy 35 m away that is fighting no one is left alone, as before")
	for u in [guard, raider]: if not u.dead: w.kill(u)
	# 3: a tank on a move order does not turn aside.
	mine = w.spawn_unit("tank", flat(spot + Vector3(10, 0, -60)), 0)
	var mover: Dictionary = w.spawn_unit("tank", flat(spot + Vector3(-35, 0, -60)), 0)
	raider = w.spawn_unit("tank", flat(spot + Vector3(0, 0, -60)), 1)
	w.order_move([mover], flat(spot + Vector3(-35, 0, -160)))
	raider.enemy = mine
	sim(3.0)
	check(mover.enemy == null, "a tank on a move order still ignores the fight")
	for u in [mine, mover, raider]: if not u.dead: w.kill(u)
	# 4: past 1.6 times its sight, nothing.
	mine = w.spawn_unit("tank", flat(spot + Vector3(0, 0, 100)), 0)
	guard = w.spawn_unit("tank", flat(spot + Vector3(-60, 0, 100)), 0)
	raider = w.spawn_unit("tank", flat(spot + Vector3(10, 0, 100)), 1)
	raider.enemy = mine
	sim(3.0)
	check(guard.enemy == null, "70 m away, past the distance it would chase, the idle tank stays put")
	print("\nASSIST: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("ASSIST PASS" if errors.is_empty() else "ASSIST FAIL")
	quit(0 if errors.is_empty() else 1)
