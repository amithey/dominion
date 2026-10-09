extends SceneTree
## The living world (ambience.gd) and the battle's look: smoke from stacks and,
## in the cold seasons, from house chimneys; snow that comes with winter and
## never in the first spring; flocks that scatter at a blast; the order ring;
## torn-cloud smoke and dust instead of soft discs; slim unit health bars.
var errors: Array[String] = []
var passed := 0
var w: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
	set_meta("match_config", {"map": "island", "players": 4, "nation": 0, "opening": "light"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	w.ai.set_physics_process(false)
	var A := preload("res://scripts/ambience.gd")
	var amb: Node3D = w.ambience
	check(amb != null and amb.is_inside_tree(), "the world has its ambience")

	# ---- the seasons' snow
	check(A.snow_at(0.0) == 0.0 and A.snow_at(10.0) == 0.0, "no snow in the first spring: no winter came before it")
	check(A.snow_at(200.0) == 0.0 and A.snow_at(450.0) == 0.0, "none in summer or autumn")
	check(A.snow_at(560.0) > 0.4 and A.snow_at(560.0) < 0.6 and A.snow_at(600.0) == 1.0, "it settles over the first days of winter")
	check(A.snow_at(720.0) == 1.0 and A.snow_at(730.0) > 0.0 and A.snow_at(745.0) == 0.0, "and melts as the next spring begins")
	w.game_time = 650.0
	amb.update(0.1)
	check(is_equal_approx(amb.winter, 1.0), "the shaders are told it is winter (global winter)")
	w.game_time = 100.0
	amb.update(0.1)
	check(amb.winter == 0.0, "and summer")

	# ---- smoke: stacks always, chimneys in the cold
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	var plant = null
	for k in range(30):
		var at = w.test_site("powerPlant", home + Vector3(cos(k) * 40.0, 0, sin(k) * 40.0))
		if at != null:
			plant = w.place_building("powerPlant", at, 0, true)
			break
	var cottage = null
	for k in range(30):
		var at = w.test_site("cottage", home + Vector3(cos(k * 1.7) * 30.0, 0, sin(k * 1.7) * 30.0))
		if at != null:
			cottage = w.place_building("cottage", at, 0, true)
			break
	check(plant != null and not plant.root.find_children("SmokeIndustry*", "Marker3D", true, false).is_empty(), "a power station marks where its stacks smoke")
	check(cottage != null and not cottage.root.find_children("SmokeHome*", "Marker3D", true, false).is_empty(), "a cottage marks its chimney")
	w.cam_focus = home
	w.game_time = 100.0
	amb._update_plumes()
	var summer: int = amb.plumes()
	w.game_time = 620.0
	amb._update_plumes()
	var winter: int = amb.plumes()
	check(summer > 0, "stacks smoke in summer (%d plumes)" % summer)
	check(winter > summer, "chimneys join them in winter (%d plumes)" % winter)
	w.cam_focus = home + Vector3(5000, 0, 5000)
	amb._update_plumes()
	check(amb.plumes() == 0, "nothing smokes far from the camera")
	w.cam_focus = home
	w.game_time = 100.0

	# ---- birds and the order ring
	check(amb.flock_count() == A.FLOCKS, "flocks circle near the camera")
	amb.update(0.1)
	var f: Dictionary = amb._flocks[0]
	amb._scare(1.0, f.centre)
	check(float(f.flee) > 0.0, "a blast near a flock scatters it")
	amb.ping(home + Vector3(10, 0, 10), false)
	amb.ping(home + Vector3(-10, 0, 10), true)
	check(amb.rings() == 2, "an order leaves a ring where it was sent")
	for i in range(10): amb.update(0.1)
	check(amb.rings() == 0, "and the rings fade within a second")

	# ---- the battle's look
	var E := preload("res://scripts/effects.gd")
	var cloud: Texture2D = E.cloud_texture()
	var img := cloud.get_image()
	var centre := img.get_pixel(64, 64).a
	var corner := img.get_pixel(2, 2).a
	var ragged := 0
	for k in range(32):
		var a := TAU * k / 32.0
		var px := img.get_pixel(int(64 + cos(a) * 44.0), int(64 + sin(a) * 44.0)).a
		if absf(px - img.get_pixel(int(64 + cos(a + PI / 16.0) * 44.0), int(64 + sin(a + PI / 16.0) * 44.0)).a) > 0.05:
			ragged += 1
	check(centre > 0.4 and corner < 0.02, "a puff of smoke is dense at the heart and gone at the edge")
	check(ragged >= 8, "with a torn rim, not a smooth disc (%d of 32 steps change)" % ragged)
	check(E.cloud_texture() == cloud, "one cloud texture, shared")
	var smoke_tex = w.effects._smoke_mesh.material.albedo_texture
	check(smoke_tex == cloud and w.effects._dirt_mesh.material.albedo_texture == cloud, "battle smoke and dust use it")
	var src := FileAccess.get_file_as_string("res://scripts/health_overlay.gd")
	check(src.contains("_bar(ent, eye, screen_rect, 3.0, 40.0, 5.0)"), "a unit's health bar is slimmer than a building's")

	print("LIFE %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("LIFE %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
