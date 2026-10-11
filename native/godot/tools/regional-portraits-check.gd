extends SceneTree
const F := preload("res://scripts/factions.gd")
const R := preload("res://scripts/regional_factions.gd")
const Gallery := preload("res://scripts/leader_gallery.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var paths := []
	for id in R.IDS + ["egypt"]:
		var index: int = F.IDS.find(id)
		var leader: String = F.LEADERS[index]
		var path: String = Gallery.portrait(leader)
		check(path == "res://ui/leaders/%s-v2.png" % F.PORTRAITS[index], id + " resolves to PNG portrait")
		check(not path in paths, id + " has distinct portrait")
		paths.append(path)
		var full: Texture2D = load(path)
		check(full != null and full.get_width() >= 1024 and full.get_height() > full.get_width(), id + " portrait resolution")
		if full == null: continue
		for aspect in [292.0 / 160.0, 1.0, 1.5]:
			var face: Texture2D = Gallery.face(leader, aspect)
			check(face is AtlasTexture, id + " uses face crop")
			if face is AtlasTexture:
				check(absf(face.region.size.x / face.region.size.y - aspect) < 0.001, id + " face crop aspect")
				check(Rect2(Vector2.ZERO, full.get_size()).encloses(face.region), id + " face crop bounds")
		var badge: Texture2D = Gallery.badge(leader)
		check(badge is AtlasTexture and Rect2(Vector2.ZERO, full.get_size()).encloses(badge.region), id + " HUD badge crop")
		check(Gallery.nation_portrait_identity(F.nation(index, true)) == leader, id + " resolves independently of player slot")
	for old_name in R.LEADER_ALIASES:
		check(Gallery.portrait(old_name) == Gallery.portrait(R.LEADER_ALIASES[old_name]), old_name + " old-save compatibility")
	check(Gallery.portrait("Successor 1 (President)") == "", "successor does not reuse incumbent")
	print("REGIONAL_PORTRAITS %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
