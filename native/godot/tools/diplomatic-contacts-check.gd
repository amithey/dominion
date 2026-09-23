extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("ok " if ok else "FAIL ", label)
	if not ok: errors.append(label)
func run() -> void:
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(2000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null:
			w = current_scene
			if w.menu.get("_root") == null: w.menu.setup(w)
			break
	if w == null:
		quit(1)
		return
	w.start_match("easy")
	paused = true
	w.menu._root.hide()
	w.hud.show()
	var c: Node = w.diplomacy.contacts
	var d: Node = w.diplomacy
	w.economy.res.money = 10000.0
	d.set_score(0, 1, 0)
	var initial_funds: float = w.economy.res.money
	c.begin(1, "visit")
	c.advance(1)
	c.back_to_channels()
	check(c.session.phase == "choosing" and w.economy.res.money == initial_funds, "back refunds an unused choice and returns to channel selection")
	c.restore(JSON.parse_string(JSON.stringify(c.capture())))
	c.back_to_channels()
	check(w.economy.res.money == initial_funds and c.begin(1, "phone") == "", "back is idempotent after loading and allows immediate channel switch")
	c.advance(5)
	c.propose("aid")
	c.back_to_channels()
	check(c.begin(1, "mediator") == "", "can switch channels after a discussion")
	c.advance(30)
	check(c.propose("aid") != "" and c.session.results.size() == 1, "switching preserves decisions and prevents replaying a deal")
	c.restore({})
	d.set_score(0, 1, 0)
	check(c.begin(1, "visit") == "", "visit invitation accepted")
	check(c.session.phase == "travelling" and c.topic_reason("trade") != "", "travel gates negotiations")
	check(c.begin(2, "phone") != "", "head of government cannot attend two contacts")
	var funds: float = w.economy.res.money
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.capture()))
	c.restore(saved)
	c.advance(float(c.session.duration))
	check(c.session.phase == "talking" and w.economy.res.money == funds, "save resumes travel without charging twice")
	check(c.propose("alliance") == "" and c.session.results[-1].outcome == "Rejected", "visit does not guarantee alliance")
	c.propose("passage")
	check(w.passage.has_passage(0, 1), "accepted transit enables actual border permission")
	c.propose("trade")
	check(d.pact[0][1], "accepted trade changes treaty")
	c.propose("aid")
	check(c.topic_reason("nap") != "", "four-item visit agenda enforced")
	check(c.propose("aid") != "" and w.economy.res.money == funds - 300, "duplicate proposal cannot spend twice")
	c.finish()
	check(c.history.size() == 1 and c.start_reason(1, "phone") != "", "communique and shared channel cooldown")
	c.finish()
	check(c.history.size() == 1, "conclusion idempotent")
	c.advance(121)
	d.set_score(0, 1, -20)
	c.begin(1, "phone")
	c.advance(5)
	c.propose("nap")
	check(not c.session.counter.is_empty() and not d.nap[0][1], "counteroffer is not an agreement")
	c.restore(JSON.parse_string(JSON.stringify(c.capture())))
	funds = w.economy.res.money
	c.answer_counter(true)
	check(d.nap[0][1] and w.economy.res.money == funds - 200, "saved counteroffer settles once")
	check(c.answer_counter(true) != "" and w.economy.res.money == funds - 200, "counter cannot replay")
	c.finish()
	c.advance(121)
	d.set_score(0, 1, 10)
	c.begin(1, "visit")
	d.set_flag(d.war, 0, 1, true)
	c.advance(1)
	check(c.session.phase == "concluded", "war interrupts state visit")
	c.advance(121)
	check(c.start_reason(1, "visit") != "" and c.begin(1, "mediator") == "", "wartime mediation remains available")
	c.advance(30)
	c.propose("peace")
	if not c.session.counter.is_empty(): c.answer_counter(true)
	check(not d.at_war(0, 1), "mediated peace ends actual war")
	c.finish()
	c.advance(121)
	d.set_score(0, 1, 80)
	c.begin(1, "phone")
	c.advance(5)
	check(c.topic_reason("alliance") != "", "alliance needs personal summit")
	check(c.topic_reason("route") != "", "route requires real port capacity")
	check(c.topic_reason("arms") != "", "arms require real factory")
	var at = w.test_site("tankFactory", w.start)
	if at != null: w.place_building("tankFactory", at, 0, true)
	w.economy.res.iron = 1000
	w.economy.res.oil = 1000
	w.market.ai_nation(1).money = 2000
	var before: int = w.units.size()
	funds = w.economy.res.money
	c.propose("arms")
	check(c.exports.size() == 1 and w.units.size() == before and w.economy.res.money == funds - 250, "arms consume production resources and wait for delivery")
	c.restore(JSON.parse_string(JSON.stringify(c.capture())))
	c.advance(60)
	check(c.exports.is_empty() and w.units.size() == before + 1 and w.economy.res.money == funds + 550, "saved export delivers one tank and settles payment")
	c.advance(1)
	check(w.units.size() == before + 1, "delivery cannot repeat")
	c.finish()
	c.advance(121)
	c.begin(1, "phone")
	c.advance(5)
	w.market.ai_nation(1).money = 2000
	funds = w.economy.res.money
	var iron: float = w.economy.res.iron
	c.propose("arms")
	d.set_flag(d.war, 0, 1, true)
	c.advance(1)
	check(c.exports.is_empty() and w.market.ai_nation(1).money == 2000 and w.economy.res.money == funds and w.economy.res.iron == iron, "war cancels exports and refunds both treasuries and materials")
	c.finish()
	c.advance(121)
	d.set_flag(d.war, 0, 1, false)
	c.begin(1, "visit")
	c.advance(float(c.session.duration))
	# Clicking the real foreign HQ opens the same contact, not production.
	for b in w.buildings:
		if b.owner == 1 and b.key == "hq":
			w.cam_focus = b.root.position
			w.cam_dist = 45.0
			w.cam_dist_target = 45.0
			w.cam_pitch = 0.65
			w.update_camera(0.0)
			var bounds: AABB = preload("res://scripts/picking.gd").local_box({"node": b.root})
			var roof: Vector3 = bounds.get_center() + Vector3.UP * bounds.size.y * 0.42
			var point: Vector2 = w.camera.unproject_position(b.root.global_transform * roof)
			check(is_same(w.building_under(point), b), "clicking the visible capital roof selects its building")
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			w._unhandled_input(event)
			event.pressed = false
			w._unhandled_input(event)
			break
	check(w.hud._diplomatic_contact_screen != null and w.hud._diplomatic_contact_screen.visible, "foreign civic building opens contact screen")
	for button in w.hud._diplomatic_contact_screen.find_children("*", "Button", true, false):
		if button.text == "Back to contact options":
			button.pressed.emit()
			break
	check(c.session.phase == "choosing", "visible back button returns to channel options")
	for button in w.hud._diplomatic_contact_screen.find_children("*", "Button", true, false):
		if button.text.begins_with("State visit"):
			check(not button.disabled, "replacement channel button is enabled immediately")
			button.pressed.emit()
			break
	c.advance(float(c.session.duration))
	var port_at = w.test_site("port", w.start)
	check(port_at != null, "commercial port site exists")
	if port_at != null: w.place_building("port", port_at, 0, true)
	check(c.propose("route", {"res": "money", "dir": "export", "qty": 999}) != "", "invalid cargo terms rejected")
	var routes_before: int = w.market.routes.size()
	c.propose("route", {"res": "iron", "dir": "export", "qty": 25})
	check(w.market.routes.size() == routes_before + 1 and w.market.routes[-1].nation == 1 and w.market.routes[-1].qty == 25, "negotiated shipping route reaches the real market")
	if "--capture-contacts" in OS.get_cmdline_user_args():
		for i in range(20): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/diplomatic-summit.png")
		c.propose("aid")
		c.propose("alliance")
		c.finish()
		for i in range(10): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/diplomatic-summary.png")
	# Whole-game persistence preserves the active contact and treaty effects.
	var whole: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	c.restore({})
	w.saves.restore(whole)
	check(c.session.get("nation", -1) == 1, "whole-game save restores diplomatic contact")
	if c.session.phase != "concluded":
		c.session.leader = "Previous leader"
		c.advance(0)
		check(c.session.phase == "concluded", "leadership replacement suspends talks")
	c.finish()
	c.advance(121)
	d.set_score(0, 1, -20)
	d.set_flag(d.nap, 0, 1, false)
	c.begin(1, "phone")
	c.advance(5)
	c.propose("nap")
	c.answer_counter(false)
	check(not d.nap[0][1] and c.session.results[-1].outcome == "No agreement", "declined counteroffer makes no treaty")
	c.advance(301)
	check(c.session.phase == "concluded", "unattended contact times out")
	c.restore({})
	check(c.session.is_empty() and c.exports.is_empty(), "old saves reset new subsystem")
	print("DIPLOMATIC_CONTACTS_TEST ", "PASS" if errors.is_empty() else "FAIL")
	quit(0 if errors.is_empty() else 1)
