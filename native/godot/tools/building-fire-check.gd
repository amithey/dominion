extends SceneTree
## Verifies building structural damage states, incendiary fire ignition,
## fire spread and collapse of light structures, Fire Station scaling (0 vs 1 vs 3+),
## HUD/Sitrep reporting, AI Fire Station response, and save/load persistence.

var errors: Array[String] = []
var passed := 0
var w: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok:
		passed += 1
	else:
		errors.append(label)

func sim(seconds: float, step := 0.1) -> void:
	var n := int(roundf(seconds / step))
	for _i in range(n):
		w._physics_process(step)

func clear_owner_fires_and_stations(owner: int) -> void:
	for i in range(w.buildings.size() - 1, -1, -1):
		var b: Dictionary = w.buildings[i]
		if b.owner == owner and b.key in ["fireStation", "cottage", "housing", "residential", "bunker"] and b.get("test_spawned", false):
			if b.has("hex") and w.district_hex.get(b.hex) == b:
				w.district_hex.erase(b.hex)
			b.root.queue_free()
			w.buildings.remove_at(i)

func spawn_test_building(key: String, at: Vector3, owner: int) -> Dictionary:
	var b: Dictionary = w.place_building(key, at, owner, true)
	b.supplied = true
	b.test_spawned = true
	return b

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0, "opening": "light", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for _i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()

	var BF := preload("res://scripts/building_fires.gd")
	var hq0: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
	var base_hex: Vector2i = w.logistics.world_hex(hq0.root.position) + Vector2i(5, -3)
	var base_pos: Vector3 = w.logistics.hex_center(base_hex)

	# ---- 1. Progressive structural damage states & reversible repairs
	var house1 := spawn_test_building("cottage", base_pos, 0)
	var orig_scale_y: float = house1.model.scale.y
	check(int(house1.get("damage_stage", 0)) == 0 and house1.root.get_node_or_null("DamageVisual") == null, "intact house starts at damage_stage 0 with clean geometry")

	# Non-incendiary rifle hit -> damaged state 1, NO fire
	w.damage(house1, house1.max_hp * 0.30, {"owner": 1, "key": "soldier", "dead": true})
	check(int(house1.get("damage_stage", 0)) == 1 and float(house1.get("fire", 0.0)) == 0.0, "rifle fire puts house into damage_stage 1 without starting a fire")
	check(house1.model.scale.y < orig_scale_y and house1.root.get_node_or_null("DamageVisual") != null, "damaged house shows structural sag and fallen rubble props")

	# Heavy non-incendiary damage -> critical damage state 2
	w.damage(house1, house1.max_hp * 0.42, {"owner": 1, "key": "soldier", "dead": true})
	check(int(house1.get("damage_stage", 0)) == 2 and house1.model.scale.y < orig_scale_y * 0.90, "heavy damage transitions house to critical damage_stage 2")

	# Paid repair restores HP and reverses visual state back to 0
	house1.last_hit = -100.0
	w.Repairs.request(w, [house1])
	sim(32.0, 0.25)
	check(is_equal_approx(house1.hp, house1.max_hp) and int(house1.get("damage_stage", -1)) == 0 and house1.root.get_node_or_null("DamageVisual") == null and is_equal_approx(house1.model.scale.y, orig_scale_y), "repairing a damaged house restores HP, upright geometry, and clean materials")
	clear_owner_fires_and_stations(0)

	# ---- 2. Incendiary hit, fire spread & total collapse of light structures (0 Fire Stations)
	check(BF.station_count(w, 0) == 0, "nation starts test with 0 Fire Stations")
	seed(12345)
	var c_origin := spawn_test_building("cottage", w.logistics.hex_center(base_hex), 0)
	var neighbours: Array = []
	for step_dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]:
		neighbours.append(spawn_test_building("cottage", w.logistics.hex_center(base_hex + step_dir), 0))
	var bunker := spawn_test_building("bunker", w.logistics.hex_center(base_hex + Vector2i(0, -1)), 0)

	# TOS-1A thermobaric hit on the centre cottage
	w.damage(c_origin, c_origin.max_hp * 0.28, {"owner": 1, "key": "tos1a", "dead": true})
	check(float(c_origin.get("fire", 0.0)) > 0.30 and c_origin.root.get_node_or_null("FireVisual") != null, "incendiary TOS-1A hit ignites a light cottage and spawns FireVisual")

	# Paid repair is blocked while on fire
	w.Repairs.request(w, [c_origin])
	check(not bool(c_origin.get("repairing", false)), "burning building cannot enter paid repair until extinguished")

	# Simulate 16 seconds with 0 Fire Stations: origin cottage burns down and fire spreads to neighbours!
	sim(16.0, 0.25)
	var spread_count := neighbours.filter(func(nb): return nb.dead or float(nb.get("fire", 0.0)) > 0.01 or nb.hp < nb.max_hp).size()
	check(c_origin.dead, "unchecked fire completely destroys the light cottage when nation has 0 Fire Stations")
	check(spread_count >= 1, "unchecked fire spreads across adjacent light cottages (%d/4 neighbours caught fire)" % spread_count)
	check(not bunker.dead and bunker.hp == bunker.max_hp, "adjacent hardened concrete bunker resists stray embers")
	clear_owner_fires_and_stations(0)

	# ---- 3. 1 Fire Station extinguishes an isolated house fire before collapse
	var station_hex := base_hex + Vector2i(3, 0)
	var fs1 := spawn_test_building("fireStation", w.logistics.hex_center(station_hex), 0)
	var saved_house := spawn_test_building("cottage", w.logistics.hex_center(base_hex), 0)
	saved_house.hp = saved_house.max_hp * 0.70
	BF.ignite(w, saved_house, 0.65, 1)
	sim(5.0, 0.25)
	check(not saved_house.dead and float(saved_house.get("fire", 0.0)) == 0.0 and saved_house.root.get_node_or_null("FireVisual") == null, "1 Fire Station extinguishes a burning house (HP left: %d/%d)" % [int(saved_house.hp), int(saved_house.max_hp)])
	check(int(saved_house.get("damage_stage", 0)) >= 1, "extinguished house remains in visible damaged state until repaired")
	clear_owner_fires_and_stations(0)

	# ---- 4. Scaling: 3 Fire Stations handle a 6-house barrage far better than 1 Fire Station
	# Run A: 1 Fire Station (2 crews) vs 6 simultaneous house fires
	seed(777)
	var _fs_single := spawn_test_building("fireStation", w.logistics.hex_center(base_hex + Vector2i(4, 0)), 0)
	var batch1: Array = []
	for idx in range(6):
		var h := spawn_test_building("cottage", w.logistics.hex_center(base_hex + Vector2i(idx * 2, -4)), 0)
		h.hp = h.max_hp * 0.62
		BF.ignite(w, h, 0.78, 1)
		batch1.append(h)
	sim(10.0, 0.25)
	var alive_1 := batch1.filter(func(h): return not h.dead).size()
	var total_hp_1 := 0.0
	for h in batch1:
		if not h.dead:
			total_hp_1 += float(h.hp)
	clear_owner_fires_and_stations(0)

	# Run B: 3 Fire Stations (6 crews) vs the exact same 6 simultaneous house fires
	seed(777)
	for s_i in range(3):
		spawn_test_building("fireStation", w.logistics.hex_center(base_hex + Vector2i(4 + s_i, 1)), 0)
	var batch3: Array = []
	for idx in range(6):
		var h := spawn_test_building("cottage", w.logistics.hex_center(base_hex + Vector2i(idx * 2, -4)), 0)
		h.hp = h.max_hp * 0.62
		BF.ignite(w, h, 0.78, 1)
		batch3.append(h)
	sim(10.0, 0.25)
	var alive_3 := batch3.filter(func(h): return not h.dead).size()
	var burning_3 := batch3.filter(func(h): return not h.dead and float(h.get("fire", 0.0)) > 0.001).size()
	var total_hp_3 := 0.0
	for h in batch3:
		if not h.dead:
			total_hp_3 += float(h.hp)

	check(alive_3 == 6 and burning_3 == 0, "3 Fire Stations extinguish all 6 simultaneous house fires with 6/6 houses saved")
	check(total_hp_3 > total_hp_1 + 350.0 and alive_3 > alive_1, "more Fire Stations save significantly more homes & HP (3 stations: %d/6 alive, %.0f HP vs 1 station: %d/6 alive, %.0f HP)" % [alive_3, total_hp_3, alive_1, total_hp_1])

	# ---- 5. HUD status & AI response
	var st_sample: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "fireStation" and not b.dead)[0]
	var hud_st := BF.hud_status(w, st_sample)
	check(hud_st.contains("3 stations (6 firefighting crews)"), "Fire Station HUD card reports national station and crew count (%s)" % hud_st)
	clear_owner_fires_and_stations(0)

	# AI emergency Fire Station priority when rival buildings are burning
	var n1: Dictionary = w.ai.nations[0]
	n1.tech = 4.0
	var ai_hq: Dictionary = w.buildings.filter(func(b): return b.owner == n1.id and b.key == "hq")[0]
	var ai_house := spawn_test_building("cottage", ai_hq.root.position + Vector3(26, 0, 0), n1.id)
	BF.ignite(w, ai_house, 0.65, 0)
	check(w.ai.pick_building(n1) == "fireStation", "AI nation with uncontained fire prioritizes building a Fire Station")
	clear_owner_fires_and_stations(n1.id)

	# ---- 6. Save / load roundtrip preserves damaged state and active fires
	var save_damaged := spawn_test_building("residential", w.logistics.hex_center(base_hex), 0)
	save_damaged.hp = save_damaged.max_hp * 0.35
	BF.sync_damage_state(w, save_damaged)
	var save_burning := spawn_test_building("cottage", w.logistics.hex_center(base_hex + Vector2i(3, -2)), 0)
	save_burning.hp = save_burning.max_hp * 0.72
	BF.ignite(w, save_burning, 0.68, 1)
	var dmg_pos: Vector3 = save_damaged.root.position
	var burn_pos: Vector3 = save_burning.root.position

	var captured: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(captured)

	var restored_dmg: Dictionary = w.buildings.filter(func(b): return b.key == "residential" and b.root.position.distance_to(dmg_pos) < 1.0)[0]
	var restored_burn: Dictionary = w.buildings.filter(func(b): return b.key == "cottage" and b.root.position.distance_to(burn_pos) < 1.0)[0]
	check(int(restored_dmg.get("damage_stage", 0)) == 2 and restored_dmg.root.get_node_or_null("DamageVisual") != null, "save/load restores critical structural damage_stage 2 and rubble props")
	check(is_equal_approx(float(restored_burn.get("fire", 0.0)), 0.68) and restored_burn.root.get_node_or_null("FireVisual") != null, "save/load restores active building fire intensity and FireVisual")

	print("BUILDING_FIRE %d passed, %d failed" % [passed, errors.size()])
	for e in errors:
		print("  FAILED: " + e)
	print("BUILDING_FIRE %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
