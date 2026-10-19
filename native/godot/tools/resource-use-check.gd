extends SceneTree
var w: Node
var errors: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("ok " if ok else "FAIL ") + label)
	if not ok: errors.append(label)
func frames(n := 5) -> void:
	for i in range(n): await process_frame
func capture(label: String, dep: Dictionary) -> void:
	if DisplayServer.get_name() == "headless": return
	w.cam_focus = dep.pos
	w.cam_dist = 90; w.cam_dist_target = 90
	w.update_camera(1.0)
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/resource-" + label + ".png")
func run() -> void:
	set_meta("match_config", {"map":"island", "players":3, "nation":0, "opening":"light"})
	change_scene_to_file("res://world.tscn")
	for i in range(12000):
		await create_timer(0.01).timeout
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene; break
	if w == null: quit(1); return
	if w.menu._root == null: w.menu.setup(w)
	root.size = Vector2i(1280,800)
	w.start_match("easy"); w.menu.close()
	w.set_physics_process(false); w.ai.set_physics_process(false)
	preload("res://tools/test_kit.gd").quiet(w)
	w.ui_scale = 1.0; w.apply_ui_scale()
	w.economy.grant_test_resources()
	var gold: Dictionary = w.deposits.filter(func(d): return d.type == "gold")[0]
	w.cam_focus = gold.pos
	w.cam_dist = 90; w.cam_dist_target = 90; w.update_camera(1.0)
	await frames()
	var icon: Node3D = gold.node.get_node("Icon")
	var screen: Vector2 = w.camera.unproject_position(icon.global_position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = screen; event.pressed = pressed
		w._unhandled_input(event)
	await frames()
	var panel = w.hud._resource_site
	check(panel != null and panel.visible and is_same(panel.deposit, gold), "Clicking the visible gold marker opens its resource action")
	if panel == null: quit(1); return
	check(root.get_visible_rect().encloses(panel.get_global_rect()), "Resource explanation fits the laptop viewport")
	check(panel.visible and panel._description.text.contains("MONEY"), "Gold explicitly becomes spendable money")
	check(panel.building_key() == "extractor", "Gold action uses extractor")
	await capture("gold", gold)
	var money: float = w.economy.res.money
	panel.place()
	check(w.placing == "extractor" and w.economy.res.money == money, "Choosing extraction does not charge or build")
	w.cancel_placement()
	# The existing economic loop must actually pay for a completed, supplied gold mine.
	w.economy.tick()
	var rate: float = w.economy.rates.money
	var mine: Dictionary = w.place_building("extractor", gold.pos, 0, true)
	mine.supplied = true
	check(is_same(mine.deposit, gold) and is_same(gold.extractor, mine), "Gold mine binds the actual deposit")
	w.economy.tick()
	check(w.economy.rates.money >= rate + 3.9, "Gold raises treasury income by its mining output")
	mine.supplied = false
	w.economy.tick()
	check(w.economy.rates.money < rate + 3.9, "Unsupplied mine cannot produce gold income")
	w.hud.open_resource_site(gold)
	check(panel._action.disabled, "An occupied deposit cannot order a second extractor")
	var fish: Dictionary = w.deposits.filter(func(d): return d.type == "fish")[0]
	w.hud.open_resource_site(fish)
	check(panel.building_key() == "fishingPlatform" and panel._description.text.contains("FOOD") and panel._description.text.contains("Fishing Wharf"), "Fish action explains food, the Fishing Platform and the Wharf")
	await capture("fish", fish)
	panel.place()
	check(w.placing == "fishingPlatform", "Fish action enters the real platform placement flow")
	w.cancel_placement()
	# Find a legal nearby coastal hex and test the border policy on that same site.
	var coast = null
	var frontier := -1
	var frontier_was := -1
	for i in range(w.territory.owner_of.size()):
		var at: Vector3 = w.territory.center(i)
		if w.territory.owner_of[i] != -1 or not w.coast_near(at, w.logistics.radius * 1.6): continue
		var near: int = i   # (a harbour stands only in your own land: the coast hex itself is taken as if bought)
		var was: int = w.territory.owner_of[near]
		w.territory.owner_of[near] = 0
		var why: String = w.site_problem("fishingWharf", at, 0)
		if why == "":
			coast = at; frontier = near; frontier_was = was; break
		w.territory.owner_of[near] = was
	check(coast != null, "Coast you own is usable for a wharf")
	var unowned_at: Vector3 = Vector3.INF
	for j in range(w.territory.owner_of.size()):
		var cj: Vector3 = w.territory.center(j)
		if w.territory.owner_of[j] == -1 and w.coast_near(cj, w.logistics.radius * 1.6) and w.site_problem("fishingWharf", cj, 0) == "Outside your territory":
			unowned_at = cj
			break
	check(unowned_at != Vector3.INF, "Unclaimed coast is refused: a wharf needs your own land")
	if coast != null:
		var idx: int = w.territory.cell_of(coast)
		w.territory.owner_of[idx] = 1
		check(w.site_problem("fishingWharf", coast, 0).contains("land"), "Rival-owned coast remains protected")
		w.territory.owner_of[idx] = 0
		# Move the fixture shoal into range, then verify actual food production.
		var old: Vector3 = fish.pos
		fish.pos = coast + Vector3(15,0,0)
		w.economy.tick()
		var food: float = w.economy.rates.food
		var wharf: Dictionary = w.place_building("fishingWharf", coast, 0, true)
		wharf.supplied = true
		w.economy.tick()
		check(w.economy.rates.food >= food + 3.9, "A supplied wharf catches nearby fish as food")
		wharf.supplied = false
		w.economy.tick()
		check(w.economy.rates.food < food + 3.9, "Unsupplied fishing does not produce food")
		fish.pos = old
		w.territory.owner_of[frontier] = frontier_was
	w.hud.open_resource_site(fish)
	w.hud.toggle_panel("market", true)
	check(not panel.visible, "Resource window yields to ministry navigation")
	w.hud.toggle_panel("market")
	w.hud.open_resource_site(fish)
	w.hud.toggle_cabinet()
	check(not panel.visible, "Cabinet closes the resource window")
	w.hud.toggle_cabinet()
	w.hud.open_resource_site(fish)
	w.hud.toggle_research()
	check(not panel.visible, "Research closes the resource window")
	w.hud.toggle_research()
	w.economy.res.money = 0
	w.hud.open_resource_site(fish)
	check(panel._action.disabled, "Unaffordable extraction has a disabled, explained action")
	w.fog.enabled = true
	var unknown: Array = w.deposits.filter(func(d): return not w.fog.charted(d.pos))
	if not unknown.is_empty():
		w.hud.open_resource_site(unknown[0])
		check(not panel.visible, "Uncharted deposits cannot reveal resource details")
	w.fog.enabled = false
	print("RESOURCE_USE ", "PASS" if errors.is_empty() else errors, " checks=", checks)
	quit(0 if errors.is_empty() else 1)
