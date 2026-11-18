extends SceneTree
## The effects the building cards promise (audit F3): refinery, mountain mine,
## reactor, railway storage, the bank ceiling, embassies and hospitals.
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var w: Node
var fails := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok: fails += 1
func site_for(key: String) -> Vector3:
	var home: Vector2i = w.logistics.world_hex(w.start)
	for ring in range(1, 12):
		for q in range(-ring, ring + 1):
			for r in range(-ring, ring + 1):
				var h := home + Vector2i(q, r)
				if w.logistics.hex_distance(home, h) == ring and w.site_problem(key, w.logistics.hex_center(h), 0) == "":
					return w.logistics.hex_center(h)
	return Vector3.INF
func put(key: String) -> Dictionary:
	var b: Dictionary = w.place_building(key, site_for(key), 0, true)
	b.supplied = true
	return b
func rates() -> Dictionary:
	var e = w.economy
	var keep: Dictionary = e.res.duplicate()
	var civ: float = e.civilians
	e.res.money = 5000.0; e.res.oil = 300.0; e.res.iron = 300.0; e.res.uranium = 300.0; e.res.silicon = 300.0; e.res.gas = 300.0; e.res.food = 300.0
	var before: Dictionary = e.res.duplicate()
	e.tick()
	var out := {}
	for k in before: out[k] = float(e.res[k]) - float(before[k])
	e.res = keep; e.civilians = civ
	return out
func run() -> void:
	change_scene_to_file("res://world.tscn")
	for i in range(8000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	var old = w.menu
	w.menu = QuietMenu.new(); w.add_child(w.menu); w.menu.setup(w); old.queue_free()
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	for p in [w, w.economy, w.ai, w.missiles, w.effects, w.diplomacy]:
		p.set_physics_process(false); p.set_process(false)
	for i in range(3): await process_frame
	var e = w.economy
	var r0 := rates()
	put("oilRefinery")
	var r1 := rates()
	check(absf((r1.money - r0.money) - 7.0) < 0.6 and absf((r1.oil - r0.oil) + 0.06) < 0.01, "an oil refinery: +$7/s for 0.06 oil/s (%+.2f $, %+.3f oil)" % [r1.money - r0.money, r1.oil - r0.oil])
	put("mountainMine")
	var r2 := rates()
	check(r2.iron - r1.iron > 0.7, "a mountain mine digs iron (%+.2f/s)" % (r2.iron - r1.iron))
	put("nuclearReactor")
	var plant0: float = e.plant_bonus()
	var r3 := rates()
	e.recalculate()
	check(absf((r3.money - r2.money) - 5.0) < 0.6 and absf((r3.uranium - r2.uranium) + 0.04) < 0.01 and e.plant_bonus() > plant0 + 0.19, "a fuelled reactor: +$5/s, 0.04 uranium/s, +20%% production (%+.2f $, %+.3f U, %.2f -> %.2f)" % [r3.money - r2.money, r3.uranium - r2.uranium, plant0, e.plant_bonus()])
	e.res.uranium = 0.0
	e.tick(); e.recalculate()
	check(not e.reactor_fuelled and e.plant_bonus() < plant0 + 0.01, "with no uranium it gives no production bonus")
	var cap0: float = e.caps.iron
	put("railwayStation"); e.recalculate()
	check(absf(e.caps.iron - cap0 - 300.0) < 0.5, "a railway station: +300 storage (%.0f -> %.0f)" % [cap0, e.caps.iron])
	var pct0: float = e.income_pct()
	for i in range(6): put("bank")
	check(absf(e.income_pct() - pct0 - 0.60) < 0.001, "six banks add +60%%, not +90%% (%+.2f)" % (e.income_pct() - pct0))
	var d = w.diplomacy
	var other := 1
	d.set_score(0, other, 0.0)
	d.tick()
	var plain: float = d.rel(0, other)
	d.set_score(0, other, 0.0)
	put("embassy"); put("embassy"); put("embassy")
	d.tick()
	check(absf((d.rel(0, other) - plain) - 1.0) < 0.05, "two embassies count: +1.0 a tick (%+.2f)" % (d.rel(0, other) - plain))
	var soldier: Dictionary = w.spawn_unit("soldier", w.start + Vector3(4, 0, 4), 0)
	soldier.hp = soldier.max_hp * 0.5
	var h := put("hospital")
	soldier.node.position = h.root.position + Vector3(12, 0, 0)
	w.place_on_ground(soldier, soldier.node.position)
	soldier.last_hit = -100.0
	var hp0: float = soldier.hp
	e.tick()
	check(soldier.hp > hp0 + 0.5, "a hospital treats wounded infantry beside it (%.1f -> %.1f)" % [hp0, soldier.hp])
	var tank: Dictionary = w.spawn_unit("tank", h.root.position + Vector3(-12, 0, 0), 0)
	tank.hp = tank.max_hp * 0.5
	var t0: float = tank.hp
	e.tick()
	check(absf(tank.hp - t0) < 0.01, "but not vehicles (repairs do that)")
	print("BUILDING_CARDS: %d failures" % fails)
	print("BUILDING_CARDS %s" % ("PASS" if fails == 0 else "FAIL"))
	quit()
