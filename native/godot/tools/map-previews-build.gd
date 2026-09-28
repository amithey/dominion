extends SceneTree
## Rebuild committed thumbnails from the actual default-seed height grids.
const Catalogue = preload("res://scripts/map_catalogue.gd")
const Setup = preload("res://scripts/match_setup.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://ui/maps")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	for key in Catalogue.KEYS:
		var data: Dictionary = source.duplicate(true)
		Setup.apply(data, Setup.normalize({"map": key}))
		var starts: Array = data.get("spawnPositions", [])
		if starts.is_empty():
			for b in data.buildings:
				if b.key == "hq":
					starts.append([b.x, b.z])
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		var width := float(data.mapSize)
		var grid: Dictionary = data.grid
		for y in range(256):
			for x in range(256):
				var p := Vector2(x / 255.0 - 0.5, y / 255.0 - 0.5) * width
				var c := clampi(roundi((p.x - float(grid.origin[0])) / float(grid.step)), 0, int(grid.size) - 1)
				var r := clampi(roundi((p.y - float(grid.origin[1])) / float(grid.step)), 0, int(grid.size) - 1)
				var h := float(grid.heightsCm[r * int(grid.size) + c]) / 100.0
				var colour := Color("193b54") if h < 0.0 else Color("c7b989") if h < 1.5 else Color("628750").lerp(Color("c1bda8"), clampf(h / 26.0, 0.0, 1.0))
				for s in starts:
					var distance := p.distance_to(Vector2(s[0], s[1])) / width * 255.0
					if distance < 4.0:
						colour = Color("ffe1a0") if distance < 2.8 else Color("243028")
				img.set_pixel(x, y, colour)
		var err := img.save_png(Catalogue.preview_path(key))
		if err != OK:
			quit(1)
			return
		print("PREVIEW ", key, " ", starts.size(), " regions")
	print("MAP_PREVIEWS_BUILD PASS")
	quit()
