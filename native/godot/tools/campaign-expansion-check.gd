extends SceneTree
## All 22 factions across all 18 maps. Seeded resources and workers placed at
## each legal site isolate expansion/continuation from travel and AI combat.
## Each case builds a fourth settlement, finishes a farm there, negotiates,
## advances campaign systems and restores an in-memory save. Never saves a slot.
class QuietMenu extends "res://scripts/menu.gd":
	func load_settings() -> void: world.apply_ui_scale()
	func save_settings() -> void: pass
const Factions := preload("res://scripts/factions.gd")
const Maps := preload("res://scripts/map_catalogue.gd")
var w: Node
var rows: Array = []
var label := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	rows.append({"case": label, "check": text, "passed": ok})
	print(("ok " if ok else "FAIL ") + label + ": " + text)
func legal_site(key: String, near := Vector3.INF):
	var candidates: Array = []
	for i in range(w.territory.owner_of.size()):
		var at: Vector3 = w.territory.center(i)
		if near != Vector3.INF and at.distance_to(near) > 60.0: continue
		if w.height_at(at.x, at.z) <= float(w.map.seaLevel) + 1.0: continue
		candidates.append(at)
	candidates.sort_custom(func(a, b): return a.distance_squared_to(w.start) < b.distance_squared_to(w.start))
	for at in candidates:
		if w.site_problem(key, at, 0) == "": return at
	return null
func construct(key: String, at: Vector3) -> Dictionary:
	if not w.build_site(key, at): return {}
	var site: Dictionary = w.buildings[-1]
	var worker: Dictionary = w.units.filter(func(u): return u.owner == 0 and u.key == "worker" and not u.dead)[0]
	w.order_build([worker], site)
	w.place_on_ground(worker, site.root.position + Vector3(1, 0, 1))
	worker.target = null
	# Faction rates differ. Wait for real progress, not nominal buildTime.
	for second in range(ceili(float(site.def.buildTime) * 2.0) + 10):
		w.update_construction(1.0)
		w.effects._physics_process(1.0)
		if site.built: break
	return site
func run() -> void:
	for nation in range(Factions.IDS.size()):
		if "--case=brazil" in OS.get_cmdline_user_args() and Factions.IDS[nation] != "brazil": continue
		var key: String = Maps.KEYS[nation % Maps.KEYS.size()]
		label = Factions.IDS[nation] + " / " + key
		set_meta("match_config", {"map": key, "nation": nation, "players": 4, "opening": "light", "fog": false})
		change_scene_to_file("res://world.tscn")
		w = null
		for i in range(60000):
			await process_frame
			if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
				w = current_scene; break
		if w == null: check(false, "campaign loaded"); break
		var old = w.menu
		w.menu = QuietMenu.new(); w.add_child(w.menu); w.menu.setup(w); old.queue_free()
		w.start_match("easy"); w.menu.close(); w.saves.autosave_every = 0
		preload("res://tools/test_kit.gd").quiet(w, ["victory"])
		w.set_process(false); w.set_physics_process(false)
		for c in w.get_children(): c.set_process(false); c.set_physics_process(false)
		w.economy.grant_test_resources()
		# Exercise the visible continuation control, alternating victory/defeat.
		w.game_over = "victory" if nation % 2 == 0 else "defeat"
		w.continuing_after_end = false
		w.hud.show_end(w.game_over.to_upper(), "Expansion regression")
		var buttons: Array = w.hud.find_children("*", "Button", true, false).filter(func(b): return b.text == "Continue playing" and not b.is_queued_for_deletion())
		if not buttons.is_empty(): buttons[-1].pressed.emit()
		check(w.continuing_after_end and not w.match_stopped() and not paused, "end-screen button resumes play")
		var city := {}
		var built := true
		for i in range(3):
			var at = legal_site("cityCenter")
			if at == null:
				print("NO LEGAL CITY SITE: settlement ", i + 2)
				built = false; break
			city = construct("cityCenter", at)
			if city.is_empty() or not city.built:
				print("UNFINISHED CITY: ", at, " progress=", city.get("progress"), " builders=", city.get("builders"))
				built = false; break
			w.territory._process(w.territory.TICK)
		check(built and w.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.def.get("settlement") != null).size() >= 4, "four settlements constructed on legal hexes")
		var farm_at = legal_site("farm", city.root.position) if not city.is_empty() else null
		var farm := construct("farm", farm_at) if farm_at != null else {}
		check(not farm.is_empty() and farm.built and w.territory.owner_at(farm.root.position) == 0, "fourth settlement has room for a worker-built farm")
		var clock: float = w.diplomacy.contacts.clock
		var points: float = w.research.points
		var contacts: Node = w.diplomacy.contacts
		w.diplomacy.set_score(0, 1, 40)
		var contact_ok: bool = contacts.begin(1, "phone") == ""
		for second in range(120):
			w.research._process(1.0); w.territory._process(1.0)
			contacts._process(1.0); w.market._process(1.0); w.espionage._process(1.0)
		var offer_ok: bool = contacts.propose("aid") == ""
		check(contact_ok and offer_ok and contacts.clock >= clock + 120.0 and w.research.points > points, "two minutes of systems and a diplomatic agreement after expansion")
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
		w.saves.restore(snapshot)
		check(w.continuing_after_end and not w.match_stopped() and w.buildings.filter(func(b): return b.owner == 0 and b.key == "cityCenter" and b.built and not b.dead).size() >= 3 and w.diplomacy.contacts.session.results.size() >= 1, "expansion, continuation and diplomatic decisions survive save restore")
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/round5")
	var file := FileAccess.open("res://build/round5/expansion-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	var failed := rows.filter(func(r): return not r.passed).size()
	print("EXPANSION: %d checks, %d failures" % [rows.size(), failed])
	print("EXPANSION PASS" if failed == 0 else "EXPANSION FAIL")
	quit(0 if failed == 0 else 1)
