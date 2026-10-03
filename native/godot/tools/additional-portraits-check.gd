extends SceneTree
const F = preload("res://scripts/factions.gd")
const Gallery = preload("res://scripts/leader_gallery.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var paths := {}
	for id in ["uk", "south_korea", "saudi", "brazil", "indonesia", "ukraine", "north_korea", "egypt", "australia", "pakistan"]:
		var i: int = F.IDS.find(id)
		var path: String = Gallery.portrait(F.LEADERS[i])
		check(path == "res://ui/leaders/%s-v2.png" % F.PORTRAITS[i], "PNG selected: " + F.IDS[i])
		check(not paths.has(path), "Unique portrait: " + F.IDS[i])
		paths[path] = true
		var full: Texture2D = load(path)
		check(full != null and full.get_width() >= 1024 and full.get_height() > full.get_width(), "Portrait resolution")
		for aspect in [292.0 / 160.0, 1.0, 1.5]:
			var face: Texture2D = Gallery.face(F.LEADERS[i], aspect)
			check(face is AtlasTexture, "Face uses image crop")
			if face is AtlasTexture:
				var rect: Rect2 = face.region
				check(absf(rect.size.x / rect.size.y - aspect) < 0.001, "Crop aspect")
				check(Rect2(Vector2.ZERO, full.get_size()).encloses(rect), "Crop bounds")
	check(paths.size() == 10, "All ten additional portraits")
	check(Gallery.portrait("Successor 1 (President)") == "", "Successor has no incumbent portrait")
	print("Additional portraits: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
