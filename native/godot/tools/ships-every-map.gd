extends SceneTree
## Can a shipyard be placed and ships launched on every map? (prints per map)
var w: Node
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var maps: Array = ["island"] + preload("res://scripts/map_generator.gd").MAPS.keys()
	for key in maps:
		set_meta("match_config", {"map": key, "players": 2, "nation": 0, "style": "sandbox", "fog": false})
		change_scene_to_file("res://world.tscn")
		w = null
		for i in range(40000):
			await process_frame
			if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
				w = current_scene
				break
		w.start_match("easy")
		w.menu.close()
		w.economy.grant_test_resources()
		var home: Vector2i = w.logistics.world_hex(w.start)
		var problems := {}
		var spot = null
		for ring in range(1, 14):
			for q in range(-ring, ring + 1):
				for r in range(-ring, ring + 1):
					var h := home + Vector2i(q, r)
					if w.logistics.hex_distance(home, h) != ring: continue
					var at: Vector3 = w.logistics.hex_center(h)
					var p: String = w.site_problem("shipyard", at, 0)
					if p == "Outside your territory" and w.coast_near(at, w.logistics.radius * 1.6):
						var gi: int = w.territory.index_of(w.territory.hex_at(at))
						if gi >= 0:
							w.territory.owner_of[gi] = 0
							w.territory.control[gi] = 80.0
							var cap: Dictionary = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0]
							w.territory.purchased[str(gi)] = {"owner": 0, "settlement": w.territory.settlement_key(cap)}
							p = w.site_problem("shipyard", at, 0)
					problems[p] = int(problems.get(p, 0)) + 1
					if p == "" and spot == null: spot = at
		if spot == null:
			print("SHIPS %s: NO SHIPYARD SITE within 13 hexes; reasons %s" % [key, str(problems)])
			continue
		var yard: Dictionary = w.place_building("shipyard", spot, 0, true)
		var report := []
		for ship in ["gunboat", "corvette", "destroyer"]:
			if not w.unit_allowed(0, ship):
				report.append("%s:not-allowed" % ship)
				continue
			var locked: String = w.research.unit_locked(ship) if w.research else ""
			var before: int = w.units.filter(func(u): return u.key == ship).size()
			w.queue_unit(yard, ship)
			var queued: bool = ship in yard.queue
			for f in range(60 * 90):
				w.update_training(1.0 / 60.0)
				if w.units.filter(func(u): return u.key == ship).size() > before: break
			var made: bool = w.units.filter(func(u): return u.key == ship).size() > before
			report.append("%s:locked='%s' queued=%s launched=%s" % [ship, locked, queued, made])
			yard.queue.clear()
		print("SHIPS %s: yard ok | %s" % [key, " | ".join(report)])
	quit()
