extends Node
## Saving and loading a match as JSON in user://saves/ (on Windows:
## %APPDATA%/Godot/app_userdata/DOMINION — Desktop Prototype/saves).
## A save records what the map file cannot: the economy, every building and
## unit with its health and orders, construction and training progress, the
## road and rail network, diplomacy, AI state and the camera. The terrain,
## trees and deposits come from the map file named in the save.
## F5 quick-saves, F9 quick-loads, and the game autosaves every three minutes.

const VERSION := 1
const AUTOSAVE_EVERY := 180.0

var world: Node
var _autosave := AUTOSAVE_EVERY

func setup(world_node: Node) -> void:
	world = world_node
	DirAccess.make_dir_recursive_absolute("user://saves")

func path_of(slot: String) -> String:
	return "user://saves/%s.json" % slot

func _process(delta: float) -> void:
	if world == null or world.game_over != "" or world.bench_phase >= 0:
		return
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE_EVERY
		save("autosave")

func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]

func _p(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])

# ---------------------------------------------------------------- save

func capture() -> Dictionary:
	var buildings := []
	for b in world.buildings:
		if b.dead:
			continue
		buildings.append({
			"key": b.key, "owner": b.owner, "pos": _v(b.root.position), "built": b.built,
			"progress": b.progress, "hp": b.hp, "queue": b.queue, "queue_prog": b.queue_prog,
			"ai_build": b.get("ai_build", false),
		})
	var units := []
	for u in world.units:
		if u.dead:
			continue
		units.append({
			"key": u.key, "owner": u.owner, "pos": _v(u.node.position), "heading": u.heading, "hp": u.hp,
			"target": _v(u.target) if u.target != null else null, "attack_move": u.attack_move,
		})
	var edges := []
	for e in world.logistics.edges.values():
		edges.append({"a": [e.a.x, e.a.y], "b": [e.b.x, e.b.y], "owner": e.owner, "kind": e.kind, "half": e.half})
	var d: Node = world.diplomacy
	var nations := []
	for n in world.ai.nations:
		var copy: Dictionary = n.duplicate()
		nations.append(copy)
	return {
		"format": "dominion-save", "version": VERSION, "map": world.MAP_PATH,
		"date": Time.get_datetime_string_from_system(), "quality": world.quality,
		"economy": {"res": world.economy.res, "civilians": world.economy.civilians},
		"buildings": buildings, "units": units, "edges": edges,
		"diplomacy": {"score": d.score, "war": d.war, "alliance": d.alliance, "pact": d.pact, "nap": d.nap},
		"ai": nations,
		"camera": {"focus": _v(world.cam_focus), "yaw": world.cam_yaw, "pitch": world.cam_pitch, "dist": world.cam_dist_target},
		"game_over": world.game_over,
	}

func save(slot: String) -> bool:
	var file := FileAccess.open(path_of(slot), FileAccess.WRITE)
	if file == null:
		world.hud.notice("Could not save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(capture()))
	file.close()
	if slot != "autosave":
		world.hud.notice("Game saved")
	return true

# ---------------------------------------------------------------- load

func load_slot(slot: String) -> bool:
	if not FileAccess.file_exists(path_of(slot)):
		world.hud.notice("No saved game yet")
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path_of(slot)))
	if not (data is Dictionary) or data.get("format") != "dominion-save":
		world.hud.notice("The saved game is damaged")
		return false
	if data.map != world.MAP_PATH:
		world.hud.notice("This save belongs to another map")
		return false
	restore(data)
	world.hud.notice("Game loaded")
	return true

func restore(data: Dictionary) -> void:
	world.clear_match()
	# Economy.
	for key in data.economy.res:
		world.economy.res[key] = float(data.economy.res[key])
	world.economy.civilians = float(data.economy.civilians)
	# Buildings, then their districts' streets and the walk grid.
	for s in data.buildings:
		var b: Dictionary = world.place_building(s.key, _p(s.pos), int(s.owner), bool(s.built))
		b.hp = float(s.hp)
		b.progress = float(s.progress)
		b.queue = s.queue.duplicate()
		b.queue_prog = float(s.queue_prog)
		if s.get("ai_build", false):
			b.ai_build = true
		if not b.built and b.has("full_scale_y"):
			b.model.scale.y = b.full_scale_y * lerpf(0.06, 1.0, b.progress)
	# Roads and railways.
	for e in data.edges:
		var a := Vector2i(int(e.a[0]), int(e.a[1]))
		var bb := Vector2i(int(e.b[0]), int(e.b[1]))
		var kind: String = e.kind
		var hp := float(world.logistics.transport[kind].hp)
		var half := [float(e.half[0]), float(e.half[1])]
		world.logistics.edges[world.logistics.edge_key(a, bb, int(e.owner))] = {
			"a": a, "b": bb, "owner": int(e.owner), "kind": kind, "hp": minf(half[0], half[1]), "max_hp": hp, "half": half,
		}
	world.refresh_streets()
	world.rebuild_walk_grid()
	# Units.
	for s in data.units:
		var u: Dictionary = world.spawn_unit(s.key, _p(s.pos), int(s.owner))
		u.heading = float(s.heading)
		u.hp = float(s.hp)
		if s.target != null:
			u.target = _p(s.target)
			u.attack_move = bool(s.attack_move)
		world.place_on_ground(u, _p(s.pos))
	# Diplomacy and the AI.
	var d: Node = world.diplomacy
	for name in ["score", "war", "alliance", "pact", "nap"]:
		var grid: Array = data.diplomacy[name]
		for a in range(mini(grid.size(), d.n)):
			for b in range(mini(grid[a].size(), d.n)):
				d.get(name)[a][b] = float(grid[a][b]) if name == "score" else bool(grid[a][b])
	for saved in data.ai:
		for n in world.ai.nations:
			if n.id == int(saved.id):
				for key in saved:
					n[key] = saved[key] if not (saved[key] is float and key == "id") else int(saved[key])
				n.id = int(saved.id)
				n.build_idx = int(saved.build_idx)
	world.logistics.dirty = true
	world.logistics.update_supply()
	world.economy.recalculate()
	# Camera.
	world.cam_focus = _p(data.camera.focus)
	world.cam_yaw = float(data.camera.yaw)
	world.cam_pitch = float(data.camera.pitch)
	world.cam_dist_target = float(data.camera.dist)
	world.game_over = data.get("game_over", "")
