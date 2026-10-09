extends SceneTree
const Overlay := preload("res://scripts/unit_overlay.gd")
class FakeFog extends RefCounted:
	var blocked := false
	func shows(_entity: Dictionary) -> bool: return not blocked
class MarkerWorld extends Node3D:
	var camera: Camera3D
	var units: Array = []
	var buildings: Array = []
	var fog := FakeFog.new()
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	rows.append({"check":text,"passed":ok}); print(("ok " if ok else "FAIL ") + text)
func run() -> void:
	root.size = Vector2i(1280, 800)
	var w := MarkerWorld.new(); root.add_child(w)
	w.camera = Camera3D.new(); w.add_child(w.camera)
	w.camera.position = Vector3(0, 90, 70); w.camera.look_at(Vector3.ZERO)
	var site := Node3D.new(); w.add_child(site)
	var b := {"root":site,"owner":0,"dead":false,"built":false,"progress":0.35,"builders":0,"def":{"water":false}}
	w.buildings = [b]
	var overlay := Overlay.new(); root.add_child(overlay); overlay.setup(w)
	check(overlay.construction_markers().size() == 1, "an unfinished owned site has a marker")
	check(overlay.construction_markers()[0].status == "NEEDS WORKER", "no assigned crew is explicit")
	check(is_equal_approx(overlay.construction_markers()[0].progress, 0.35), "progress uses the actual building work")
	w.units = [{"dead":false,"build_site":b}]
	check(overlay.construction_markers()[0].status == "WORKER EN ROUTE", "assigned workers travelling to the site are distinguished")
	w.units[0].dead = true
	check(overlay.construction_markers()[0].status == "NEEDS WORKER", "a dead assigned worker does not count")
	w.units.clear(); b.builders = 1
	check(overlay.construction_markers()[0].status == "BUILDING", "an active crew is building")
	b.builders = 0; b.def.water = true
	check(overlay.construction_markers()[0].status == "BUILDING", "marine contractors do not ask for a land worker")
	b.def.water = false; b.built = true
	check(overlay.construction_markers().is_empty(), "completed buildings lose the construction marker")
	b.built = false; b.dead = true
	check(overlay.construction_markers().is_empty(), "destroyed sites lose the construction marker")
	b.dead = false; b.owner = 1
	check(overlay.construction_markers().is_empty(), "enemy construction details are not exposed")
	b.owner = 0; site.hide()
	check(overlay.construction_markers().is_empty(), "hidden sites are ignored")
	site.show(); w.fog.blocked = true
	check(overlay.construction_markers().is_empty(), "fogged sites are ignored")
	w.fog.blocked = false; site.position = w.camera.position + w.camera.basis.z * 100
	check(overlay.construction_markers().is_empty(), "sites behind the camera are ignored")
	site.position = Vector3(0, 0, -1000)
	check(overlay.construction_markers().is_empty(), "distant construction does not clutter the map")
	site.position = Vector3.ZERO; b.progress = -1.0
	check(overlay.construction_markers()[0].progress == 0.0, "invalid negative progress is bounded")
	b.progress = 2.0
	check(overlay.construction_markers()[0].progress == 1.0, "over-complete progress is bounded")
	overlay.queue_free(); w.queue_free(); await process_frame
	await actual_site()
	var failed := rows.filter(func(r): return not r.passed).size()
	DirAccess.make_dir_recursive_absolute("res://build/round5")
	var f := FileAccess.open("res://build/round5/construction-results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":rows.size(),"failed":failed,"results":rows},"\t")); f.close()
	print("CONSTRUCTION_FEEDBACK: %d checks, %d failures" % [rows.size(), failed])
	quit(0 if failed == 0 else 1)
func shot(w: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	w.hud._overlay.queue_redraw(); w.hud._process(0.3)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/round5/" + name + ".png")
func actual_site() -> void:
	set_meta("match_config", {"map":"island","players":4,"nation":0,"opening":"light","style":"standard","progression":true,"fog":false})
	change_scene_to_file("res://world.tscn")
	var w: Node
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null: w = current_scene; break
	if w == null: check(false,"actual world loaded"); return
	var old = w.menu
	w.menu = QuietMenu.new(); w.add_child(w.menu); w.menu.setup(w); old.queue_free()
	w.menu.set_fullscreen(false); root.size = Vector2i(1280, 800)
	w.start_match("normal"); w.menu.close(); w.saves.autosave_every = 0
	w.set_process(false); w.set_physics_process(false)
	for c in w.get_children(): c.set_process(false); c.set_physics_process(false)
	var at = null
	for i in range(w.territory.owner_of.size()):
		if w.territory.owner_of[i] != 0: continue
		var p: Vector3 = w.territory.center(i)
		if w.site_problem("farm", p, 0) == "": at = p; break
	check(at != null and w.site_problem("farm", at, 0) == "", "a real starting campaign has a legal farm site")
	if at == null: return
	var money: float = w.economy.res.money
	check(w.build_site("farm", at) and w.economy.res.money < money, "normal starting funds pay for the actual farm")
	var b: Dictionary = w.buildings[-1]
	w.cam_focus = b.root.position; w.cam_dist = 90; w.cam_dist_target = 90; w.update_camera(1.0)
	var overlay: Node = w.hud._overlay
	check(overlay.construction_markers().size() == 1 and overlay.construction_markers()[0].status == "WORKER EN ROUTE", "a newly ordered farm shows its assigned worker travelling")
	for u in w.units: u.build_site = null
	check(overlay.construction_markers()[0].status == "NEEDS WORKER", "a real unattended farm asks for a worker")
	await shot(w, "construction-waiting")
	w.resume_construction(b)
	var worker: Dictionary = w.units.filter(func(u): return u.key == "worker" and u.owner == 0 and is_same(u.build_site,b))[0]
	w.place_on_ground(worker,b.root.position + Vector3(1,0,1)); worker.target = null
	w.update_construction(float(b.def.buildTime) * 0.35)
	check(b.progress > 0 and b.progress < 1 and overlay.construction_markers()[0].status == "BUILDING", "real construction advances the live progress marker")
	await shot(w, "construction-building")
	w.finish_building(b)
	check(overlay.construction_markers().is_empty(), "completing the actual farm removes the marker")
