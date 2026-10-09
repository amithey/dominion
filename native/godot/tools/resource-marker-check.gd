extends SceneTree
const Picking := preload("res://scripts/resource_picking.gd")
const Art := preload("res://scripts/deposit_art.gd")
class MarkerWorld extends Node3D:
	var camera: Camera3D
	var deposits: Array = []
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
var rows: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	rows.append({"check":text, "passed":ok})
	print(("ok " if ok else "FAIL ") + text)
func run() -> void:
	root.size = Vector2i(1280, 800)
	var w := MarkerWorld.new()
	root.add_child(w)
	w.camera = Camera3D.new(); w.add_child(w.camera); w.camera.current = true
	var art = Art.new(null)
	for water in [false, true]:
		var site := Node3D.new(); w.add_child(site)
		site.add_child(art._icon("seaOil" if water else "iron", 11.0 if water else 9.0))
		var dep := {"node":site, "pos":Vector3.ZERO}
		w.deposits = [dep]
		var icon: Node3D = site.get_node("Icon")
		for pitch in [0.3, 0.95, 1.25]:
			for zoom in [40.0, 115.0, 300.0]:
				w.camera.position = Vector3(0, zoom * sin(pitch), zoom * cos(pitch))
				w.camera.look_at(Vector3.ZERO)
				var mouse := w.camera.unproject_position(icon.global_position)
				var chosen = Picking.marker_at(w, mouse)
				check(chosen != null and is_same(chosen, dep), "%s marker at pitch %.2f / zoom %d targets its own deposit" % ["sea" if water else "land", pitch, zoom])
				if is_equal_approx(pitch, 0.3):
					var old = Plane(Vector3.UP, 0).intersects_ray(w.camera.project_ray_origin(mouse), w.camera.project_ray_normal(mouse))
					check(old != null and old.length() > 10.0, "reproduced old 10 m snap miss: %.1f m behind %s marker" % [old.length(), "sea" if water else "land"])
		var mouse := w.camera.unproject_position(icon.global_position)
		check(Picking.marker_at(w, mouse + Vector2(40, 0)) == null, "empty screen space does not snap to a %s deposit" % ["sea" if water else "land"])
		icon.hide()
		check(Picking.marker_at(w, mouse) == null, "hidden/occupied %s marker is not picked" % ["sea" if water else "land"])
		icon.show(); site.hide()
		check(Picking.marker_at(w, mouse) == null, "unexplored %s site is not revealed by picking" % ["sea" if water else "land"])
		site.queue_free()
		await process_frame
	w.deposits = [{"node":null}, {"node":Node3D.new()}]
	check(Picking.marker_at(w, Vector2.ZERO) == null, "missing nodes/markers are ignored safely")
	w.deposits[1].node.free()
	w.queue_free()
	await process_frame
	await placement_in_world()
	var failed := rows.filter(func(r): return not r.passed).size()
	DirAccess.make_dir_recursive_absolute("res://build/round5")
	var f := FileAccess.open("res://build/round5/resource-marker-results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":rows.size(), "failed":failed, "results":rows}, "\t")); f.close()
	print("RESOURCE_MARKER: %d checks, %d failures" % [rows.size(), failed])
	quit(0 if failed == 0 else 1)

func placement_in_world() -> void:
	set_meta("match_config", {"map":"island", "players":4, "nation":0, "opening":"light", "fog":false})
	change_scene_to_file("res://world.tscn")
	var world: Node
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			world = current_scene; break
	if world == null: check(false, "actual world loaded for marker placement"); return
	var old = world.menu
	world.menu = QuietMenu.new(); world.add_child(world.menu); world.menu.setup(world); old.queue_free()
	world.menu.set_fullscreen(false); root.size = Vector2i(1280, 800)
	world.start_match("easy"); world.menu.close(); world.saves.autosave_every = 0
	preload("res://tools/test_kit.gd").quiet(world)
	world.set_process(false); world.set_physics_process(false)
	for c in world.get_children(): c.set_process(false); c.set_physics_process(false)
	world.edge_scroll = false
	var fields: Array = world.deposits.filter(func(d): return d.type in ["seaOil", "seaGas"] and world.site_problem("offshoreRig", d.pos, 0) == "")
	check(not fields.is_empty(), "actual opening has an accessible offshore field")
	if fields.is_empty(): return
	var dep: Dictionary = fields[0]
	dep.node.show()
	world.economy.grant_test_resources()
	world.begin_placement("offshoreRig")
	world.cam_focus = dep.pos
	for pitch in [0.3, 0.95, 1.25]:
		world.cam_pitch = pitch; world.cam_dist = 115.0; world.cam_dist_target = 115.0
		world.update_camera(1.0)
		var mouse: Vector2 = world.camera.unproject_position(dep.node.get_node("Icon").global_position)
		world.update_placement(mouse)
		check(Vector2(world.ghost.position.x, world.ghost.position.z).distance_to(Vector2(dep.pos.x, dep.pos.z)) < 0.01, "real placement preview snaps from offshore marker at pitch %.2f" % pitch)
		check(world.ghost_ok == "", "offshore marker gives a valid preview at pitch %.2f" % pitch)
	world.cam_pitch = 0.3; world.update_camera(1.0)
	if DisplayServer.get_name() != "headless":
		world.hud._process(0.3)
		for i in range(10): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/round5/offshore-marker-preview.png")
	var money: float = world.economy.res.money
	world.ghost.position = Vector3.ZERO  # a stale preview must not decide the click's position
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = world.camera.unproject_position(dep.node.get_node("Icon").global_position)
	world._unhandled_input(click)
	var rigs: Array = world.buildings.filter(func(b): return b.owner == 0 and b.key == "offshoreRig" and not b.dead)
	check(rigs.size() == 1 and world.economy.res.money < money and rigs[0].deposit != null, "confirming marker placement pays for and binds the actual offshore rig")
