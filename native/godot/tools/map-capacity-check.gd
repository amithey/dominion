extends SceneTree
## Geography-only contract: all prepared slots, including unoccupied ones.
const Generator = preload("res://scripts/map_generator.gd")
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error(label)
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	for key in (Generator.EXPANDED if OS.get_cmdline_user_args().is_empty() else Array(OS.get_cmdline_user_args()[0].split(","))):
		for seed in [7, 42, 109]:
			var data: Dictionary = source.duplicate(true)
			var g = Generator.new()
			g._build(data, key, seed)
			var tag := "%s seed %d" % [key, seed]
			check(data.mapCapacity == int(Generator.MAPS[key].slots), tag + " capacity")
			check(data.startPositions.size() == source.startPositions.size(), tag + " preserves active nation count")
			check(data.buildings.size() == source.buildings.size() and data.units.size() == source.units.size(), tag + " preserves starting entities")
			for i in range(g.starts.size()):
				var s: Vector2 = g.starts[i]
				check(absf(s.x) < g.half - 100.0 and absf(s.y) < g.half - 100.0, tag + " expansion room")
				for j in range(i):
					check(s.distance_to(g.starts[j]) > 300.0, tag + " capital spacing")
				for angle in range(12):
					var p := s + Vector2.from_angle(TAU * angle / 12.0) * 55.0
					check(g.height(p) > 1.0 and g._slope(p) < 0.35, tag + " buildable starting district")
				var nearby := {}
				for d in data.deposits:
					if s.distance_to(Vector2(d.x, d.z)) < 110.0:
						nearby[d.type] = true
				check(nearby.has("oil") and nearby.has("iron") and nearby.has("gold"), tag + " starting resources slot %d" % i)
				var next: Vector2 = g.starts[(i + 1) % g.starts.size()]
				for k in range(101):
					var p := s.lerp(next, k / 100.0)
					check(g.height(p) > 1.0 and g._slope(p) < 0.35, tag + " continuous traversable passage")
			for e in data.buildings:
				check(g.height(Vector2(e.x, e.z)) > 0.3, tag + " starting building on land")
			var occupied := {}
			for d in data.deposits:
				var pos := Vector2(d.x, d.z)
				check(not occupied.has(pos), tag + " unique resource hex")
				occupied[pos] = true
				check(absf(pos.x) < g.half and absf(pos.y) < g.half, tag + " resource inside bounds")
			if seed == 7:
				var repeat: Dictionary = source.duplicate(true)
				Generator.generate(repeat, key, seed)
				check(repeat == data, tag + " reproducible generation")
				preview(g, key)
			print("CAPACITY ", tag, " checked ", data.mapCapacity, " slots")
	print("MAP_CAPACITY_TEST PASS" if errors.is_empty() else "MAP_CAPACITY_TEST FAIL: " + str(errors))
	quit(0 if errors.is_empty() else 1)
func preview(g, key: String) -> void:
	var img := Image.create(600, 600, false, Image.FORMAT_RGB8)
	for y in range(600):
		for x in range(600):
			var p: Vector2 = Vector2(x / 599.0 - 0.5, y / 599.0 - 0.5) * g.size
			var h: float = g.height(p)
			var c := Color("193b54") if h < 0.0 else Color("c7b989") if h < 1.5 else Color("628750").lerp(Color("c1bda8"), clampf(h / 26.0, 0.0, 1.0))
			for s in g.starts:
				if p.distance_to(s) < 10.0:
					c = Color("ffe1a0")
			img.set_pixel(x, y, c)
	img.save_png("res://build/map-layout-%s.png" % key)

