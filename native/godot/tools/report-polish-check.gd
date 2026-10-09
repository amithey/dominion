extends SceneTree
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
const Overlay := preload("res://scripts/unit_overlay.gd")
const Feedback := preload("res://scripts/contact_feedback.gd")
var w: Node
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	rows.append({"label": text, "passed": ok})
	print(("ok " if ok else "FAIL ") + text)
func frames(n := 5) -> void:
	for i in range(n): await process_frame
func focus(at: Vector3, distance: float) -> void:
	w.cam_focus = at; w.cam_dist = distance; w.cam_dist_target = distance; w.update_camera(1.0)
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	w.hud._process(0.3)
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/round5/" + name + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/round5")
	set_meta("match_config", {"map":"island", "players":4, "nation":0, "opening":"light", "fog":false})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null: w = current_scene; break
	if w == null: quit(1); return
	var old = w.menu
	w.menu = QuietMenu.new(); w.add_child(w.menu); w.menu.setup(w); old.queue_free()
	w.menu.set_fullscreen(false); root.size = Vector2i(1280, 800)
	w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_process(false); w.set_physics_process(false)
	for c in w.get_children(): c.set_process(false); c.set_physics_process(false)
	if is_instance_valid(w.hud._guide): w.hud._guide.queue_free(); w.hud._guide = null
	w.edge_scroll = false
	await frames()
	var h: Node = w.hud
	var overlay: Node = h._overlay
	var home: Vector3 = w.start + Vector3(25, 0, 35)
	for u in w.units: u.node.hide()
	var roles := {"worker":"W", "soldier":"INF", "tank":"ARM", "artillery":"ART", "mortarTeam":"ART", "towedHowitzer":"ART", "tos1a":"ART", "heavyRocket":"ART", "aaVehicle":"AA", "samLauncher":"AA", "saudiThaad":"AA", "manpads":"AA", "helicopter":"AIR", "destroyer":"SEA"}
	var group: Array = []
	for key in roles:
		var u: Dictionary = w.spawn_unit(key, home + Vector3((group.size() % 5) * 12 - 24, 0, (group.size() / 5) * 12 - 12), 0)
		group.append(u)
		check(Overlay.role_of(u) == roles[key], key + " has the correct strategy role")
	focus(home, 170.0)
	check(not overlay.role_markers().is_empty(), "Healthy units have readable markers at strategy zoom")
	await shot("01-strategy-roles")
	for u in group: u.node.hide()
	var worker: Dictionary = group[0]
	worker.node.show(); w.place_on_ground(worker, home)
	focus(home, 55.0)
	check(overlay.role_markers().is_empty(), "Unselected nearby units leave the detailed model clear")
	worker.selected = true
	check(overlay.role_markers().size() == 1 and overlay.role_markers()[0].selected, "Selected nearby units keep a gold-framed role")
	worker.selected = false; focus(home, 150.0)
	var worker2: Dictionary = w.spawn_unit("worker", home + Vector3(0.05, 0, 0.05), 0)
	check(overlay.role_markers().size() == 1 and overlay.role_markers()[0].count == 2, "Overlapping same-role units combine with a count")
	worker2.node.hide()
	for flag in ["dead", "stowed"]:
		worker[flag] = true
		check(overlay.role_markers().is_empty(), flag + " units have no strategy marker")
		worker[flag] = false
	worker.node.hide(); check(overlay.role_markers().is_empty(), "Hidden units have no strategy marker"); worker.node.show()
	focus(home, 600.0); check(overlay.role_markers().is_empty(), "Markers stop beyond the far limit")
	focus(home, 150.0)
	var enemy: Dictionary = w.spawn_unit("soldier", home, 1)
	w.fog.enabled = true; w.fog.seen.fill(0)
	check(overlay.role_markers().all(func(m): return m.owner == 0), "Fog does not leak enemy roles")
	w.fog.enabled = false; enemy.node.hide()
	var dep: Dictionary = w.deposits[0]
	var marker: Node3D = dep.node.find_child("Icon", true, false)
	var disc: Sprite3D = marker.get_child(0)
	check(disc.fixed_size and disc.pixel_size * disc.texture.get_width() < 0.03, "Resource markers use a compact, fixed screen size")
	w.deposit_marker(dep, false); check(not marker.visible, "Worked deposits can still hide their icon")
	w.deposit_marker(dep, true); check(marker.visible, "Released deposits recover their icon")
	var terrain_material: ShaderMaterial = w.terrain_node.material_override
	for layer in ["grass", "dirt", "rock", "sand"]:
		for kind in ["albedo", "normal"]:
			var texture: Texture2D = terrain_material.get_shader_parameter(layer + "_" + kind)
			check(texture.get_image().has_mipmaps(), layer + " " + kind + " supports distant texture filtering")
	# Watertight foliage crowns: every triangle edge has exactly two faces.
	var pine := preload("res://scripts/pines.gd").mesh()
	var arrays := pine.surface_get_arrays(1)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
	else:
		indices.resize(vertices.size())
		for i in range(vertices.size()): indices[i] = i
	var edges := {}
	for i in range(0, indices.size(), 3):
		for j in range(3):
			var a := str(vertices[indices[i + j]])
			var b := str(vertices[indices[i + (j + 1) % 3]])
			var edge := a + "|" + b if a < b else b + "|" + a
			edges[edge] = int(edges.get(edge, 0)) + 1
	check(not edges.is_empty() and edges.values().all(func(n): return n == 2), "Pine crowns have no cracked triangle seams")
	# The guide offers real actions, without toggling panels closed on repeats.
	var guide := preload("res://scripts/beginner_guide.gd").new()
	h.add_child(guide); guide.setup(w, h)
	guide._action.pressed.emit(); guide._action.pressed.emit()
	check(h.prod_open, "Guide Build action remains open on repeat")
	guide._process(0.5); check(guide.step == 1, "Guide notices the opened build list")
	guide._action.pressed.emit(); check(w.placing == "farm", "Guide starts the actual farm placement tool")
	w.cancel_placement(); h.set_production_open(false)
	var farm_at = null
	for i in range(w.territory.owner_of.size()):
		var at: Vector3 = w.territory.center(i)
		if w.site_problem("farm", at, 0) == "": farm_at = at; break
	check(farm_at != null, "Opening has a legal farm site")
	if farm_at != null:
		w.build_site("farm", farm_at)
		var farm: Dictionary = w.buildings[-1]
		guide._process(0.5); guide._action.pressed.emit()
		check(w.units.any(func(u): return is_same(u.get("build_site"), farm)), "Guide assigns workers to the unfinished farm")
		w.order_build([worker], farm)
		w.place_on_ground(worker, farm.root.position + Vector3(1, 0, 1)); worker.target = null
		w.update_construction(float(farm.def.buildTime) + 1.0)
		guide._process(0.5); check(guide.step == 3 and farm.built, "Guide waits for actual construction")
	guide._action.pressed.emit(); check(w.placing == "cottage", "Guide opens housing placement")
	w.cancel_placement()
	guide.step = 4; guide._show(); guide._action.pressed.emit(); guide._action.pressed.emit()
	check(h._rs != null and h._rs.visible, "Guide research action opens and stays open")
	h.toggle_research(); guide.step = 5; guide._show(); guide._action.pressed.emit(); guide._action.pressed.emit()
	check(h.side_mode == "diplomacy", "Guide diplomacy action opens and stays open")
	h.close_windows(); guide.step = 6; guide._show(); guide._action.pressed.emit()
	check(w.game_speed == 2.0, "Guide pace action changes the actual simulation speed")
	w.set_speed(1.0); guide.step = 1; guide._show(); focus(w.start, 115.0)
	await shot("02-opening-guide")
	root.size = Vector2i(1008, 600); w.ui_scale = 1.0; w.apply_ui_scale(); await frames()
	check(root.get_visible_rect().encloses(guide._action.get_global_rect()), "Guide action fits a 1008×600 window at 100% UI")
	root.size = Vector2i(1280, 800); w.ui_scale = 0.8; w.apply_ui_scale()
	guide.queue_free(); await frames()
	# Actual service transitions drive the ribbon and distinct interface cues.
	var c: Node = w.diplomacy.contacts
	h.open_diplomatic_contact(1)
	var screen: Node = h._diplomatic_contact_screen
	w.diplomacy.set_score(0, 1, 40)
	screen.open(1)
	check(Feedback.state(c.session, false).step == 0, "Diplomacy starts at channel choice")
	c.begin(1, "phone")
	check(Feedback.state(c.session, true).step == 1 and screen.progress != null, "Connecting shows a separate waiting stage")
	c.advance(5.0)
	check(Feedback.state(c.session, true).cue == "ready", "A connected call reports readiness")
	check(w.audio._feedback.stream == w.audio._cues.ready, "Connected call plays its interface cue")
	c.propose("aid")
	check(Feedback.state(c.session, true).cue == "accepted", "Accepted agreement has positive feedback")
	check(w.audio._feedback.stream == w.audio._cues.accepted, "Acceptance plays a distinct cue")
	await shot("03-diplomacy-accepted")
	root.size = Vector2i(1008, 600); w.ui_scale = 1.0; w.apply_ui_scale(); await frames()
	var close_buttons: Array = screen.find_children("*", "Button", true, false).filter(func(b): return b.text == "Close" and not b.is_queued_for_deletion())
	check(not close_buttons.is_empty() and root.get_visible_rect().encloses(close_buttons[-1].get_global_rect()), "Diplomacy Close fits a 1008×600 window at 100% UI")
	check(root.get_visible_rect().encloses(screen.status.get_global_rect()), "Diplomatic response stays visible in a short window")
	await shot("04-diplomacy-short-window")
	root.size = Vector2i(1280, 800); w.ui_scale = 0.8; w.apply_ui_scale()
	c.session.counter = {"key":"nap", "terms":{}, "fee":200}; c.changed.emit()
	check(Feedback.state(c.session, true).cue == "counter", "Pending counteroffer clearly waits for the player")
	c.answer_counter(false)
	check(Feedback.state(c.session, true).cue == "rejected", "Declining a counteroffer shows no agreement")
	c.finish(); check(Feedback.state(c.session, true).step == 3, "Concluded contact reaches the communique stage")
	screen.hide()
	# Sound responds to nearby combat, fades in real time and respects buses.
	var audio: Node = w.audio
	check(audio._battle_music.stream is AudioStreamWAV and is_equal_approx(audio._battle_music.stream.get_length(), 48.0), "Original battle cue is a complete 48-second track")
	check(audio._battle_music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Battle music loops rather than stopping after one play")
	check(audio._music.bus == "Music" and audio._battle_music.bus == "Music" and audio._feedback.bus == "Interface", "Music and diplomacy obey their own settings channels")
	audio._battle_hold = 0.0; audio._battle_mix = 0.0
	audio.play("rifle", audio._focus + Vector3(300, 0, 0))
	check(audio._battle_hold == 0.0, "Distant gunfire does not interrupt peaceful music")
	audio.play("rifle", audio._focus)
	check(audio._battle_hold > 0.0, "Nearby combat requests the battle cue")
	var scale := Engine.time_scale
	for speed in [0.75, 3.0]:
		Engine.time_scale = speed; audio._battle_mix = 0.0; audio._battle_hold = 18.0
		audio._process(3.0 * speed)
		check(is_equal_approx(audio._battle_mix, 0.5), "Music crossfade uses real time at scale %.2f" % speed)
	Engine.time_scale = scale
	audio._battle_hold = 0.0; audio._battle_mix = 1.0; audio._process(6.0 * scale)
	check(is_zero_approx(audio._battle_mix) and audio._music.volume_db > -10.0, "Peaceful theme returns after combat ends")
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus, true); audio._process(0.1)
	check(AudioServer.is_bus_mute(bus), "Crossfade preserves the player's music mute")
	AudioServer.set_bus_mute(bus, false)
	for cue in audio._cues:
		check(audio._cues[cue].get_length() > 0.3, "Diplomatic cue " + cue + " is a complete sound")
	var failed := rows.filter(func(r): return not r.passed).size()
	var file := FileAccess.open("res://build/round5/polish-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	print("REPORT_POLISH: %d checks, %d failures" % [rows.size(), failed])
	print("REPORT_POLISH PASS" if failed == 0 else "REPORT_POLISH FAIL")
	quit(0 if failed == 0 else 1)
