extends SceneTree
## Helicopters (airlift.gd; research native/HELICOPTERS-RESEARCH-2026-10-12.md):
## the heavy-lift and naval roles by nation, their models (a utility airframe,
## the Chinook's two rotors), boarding by right-click and landing with J, what
## fits aboard (the Mi-26 lifts an armoured carrier, a Chinook does not), loss
## with the helicopter, saves, and the naval helicopter's submarine hunt.
var errors: Array[String] = []
var passed := 0
var w: Node
const C := preload("res://scripts/force_catalog.gd")
const L := preload("res://scripts/airlift.gd")
const T := preload("res://scripts/war_tools.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func begin(nation: int) -> void:
	set_meta("match_config", {"map": "island", "players": 3, "nation": nation, "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("normal")
	w.menu.close()
	for i in range(3): await physics_frame
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w, ["fog", "un", "wmd", "directorate", "defcon", "events", "support"])

func tick(seconds: float) -> void:
	for i in range(int(seconds / 0.25)): T.update(w, 0.25)

func run() -> void:
	check(C.names("heavyLift").russia == "Mi-26" and C.names("heavyLift").usa == "CH-47F Chinook" and not C.names("heavyLift").has("iran"), "heavy lifters by nation (no Iranian Chinook claimed in service)")
	check(C.names("navalHelicopter").usa == "MH-60R Seahawk" and C.names("navalHelicopter").uk == "Wildcat HMA2" and C.names("navalHelicopter").russia == "Ka-27PL", "naval helicopters by nation")

	await begin(0)   # the United States
	var hq: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var spot := hq + Vector3(35, 0, 30)
	# ---- models
	var utility: Dictionary = w.spawn_unit("helicopter", spot, 0)
	check(utility.node.find_child("Force_helicopter", true, false) == null and utility.get("rotor") != null, "the utility helicopter has its own airframe and a turning rotor")
	var chinook: Dictionary = w.spawn_unit("heavyLift", spot + Vector3(12, 0, 0), 0)
	check(chinook.get("rotor") != null and chinook.get("rotor2") != null, "the Chinook has two rotors, and both turn")
	var naval: Dictionary = w.spawn_unit("navalHelicopter", spot + Vector3(24, 0, 0), 0)
	check(not naval.is_empty() and w.unit_defs.navalHelicopter.name == "MH-60R Seahawk", "the United States flies the MH-60R")
	for h in [utility, chinook, naval]:
		h.air_state = "ready"

	# ---- boarding and landing
	var squad := []
	for i in range(8):
		squad.append(w.spawn_unit("soldier", spot + Vector3(-6 + i, 0, -8), 0))
	var gun: Dictionary = w.spawn_unit("towedHowitzer", spot + Vector3(14, 0, -8), 0)
	var carrier: Dictionary = w.spawn_unit("apc", spot + Vector3(16, 0, -8), 0)
	check(L.places(w, utility, squad[0]) == 1 and L.places(w, utility, gun) == 0, "a utility helicopter takes soldiers, not guns")
	check(L.places(w, chinook, gun) == 6 and L.places(w, chinook, carrier) == 0, "a Chinook slings a towed gun, not an armoured carrier")
	var n: int = L.order_board(w, squad, utility)
	check(n == 6, "six board a utility helicopter, the rest wait (%d)" % n)
	for u in squad:
		if u.get("board") != null: u.node.position = utility.node.position + Vector3(2, 0, 0)
	tick(0.5)
	check(L.used(utility) == 6 and squad.filter(func(u): return u.dead).size() == 6, "they are aboard (and off the map)")
	check(L.order_board(w, [squad[7]], utility) == 0, "a full helicopter takes no more")
	var snap: Dictionary = JSON.parse_string(JSON.stringify({"cargo": utility.cargo}))
	check(Array(snap.cargo).size() == 6, "the load is saved with the helicopter")
	utility.node.position = spot + Vector3(-30, 14, 20)
	var landed: Array = L.unload(w, utility)
	check(landed.size() == 6 and L.used(utility) == 0 and landed.all(func(u): return not u.dead and u.key == "soldier"), "J lands them on dry ground (%d)" % landed.size())
	L.order_board(w, [gun], chinook)
	gun.node.position = chinook.node.position
	tick(0.5)
	check(L.used(chinook) == 6, "the Chinook takes the gun aboard")
	var sea = w.water_near(hq, 200)
	if sea != null:
		chinook.node.position = Vector3(sea.x, 15, sea.z)
		check(L.unload_blocked(w, chinook) != "", "but will not drop it into the sea")
	# Lost with the helicopter.
	L.order_board(w, [squad[6]], utility)
	squad[6].node.position = utility.node.position
	tick(0.5)
	w.kill(utility)
	tick(0.5)
	check(utility.get("cargo_lost", false), "those aboard are lost with it")

	# ---- the naval helicopter
	var sub := {"key": "submarine", "naval": true, "owner": 1}
	check(is_equal_approx(T.damage_mult(w, {"owner": 0, "key": "navalHelicopter"}, sub), T.SUB_FACTOR), "it strikes submarines hard")
	check(not C.can_target(w, {"key": "navalHelicopter"}, {"key": "tank"}), "and cannot engage targets on land")

	# ---- Russia's Mi-26 lifts an armoured carrier
	await begin(preload("res://scripts/factions.gd").IDS.find("russia"))
	var mi26: Dictionary = w.spawn_unit("heavyLift", w.start + Vector3(30, 0, 30), 0)
	var btr: Dictionary = w.spawn_unit("apc", w.start + Vector3(36, 0, 30), 0)
	check(w.unit_defs.heavyLift.name == "Mi-26" and L.places(w, mi26, btr) == 12, "the Mi-26 lifts an armoured carrier (twenty tonnes)")

	print("HELICOPTERS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("HELICOPTERS %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
