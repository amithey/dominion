## --capture-industry: every building the kit makes for industry, resources
## and defence, laid out on open ground and photographed (build/industry-*.png).
extends RefCounted

const KEYS := ["extractor:oil", "extractor:iron", "extractor:gold", "extractor:silicon", "extractor:uranium", "extractor:diamond",
	"oilRefinery", "chipFab", "nuclearReactor", "solarFarm", "ammoDepot", "missileSilo", "bunker", "samSite", "park", "stadium", "port", "shipyard"]

static func capture(w: Node) -> void:
	for i in range(30):
		await w.get_tree().process_frame
	var sea = w.water_near(w.start, 320)
	for entry: String in KEYS:
		var key: String = entry.get_slice(":", 0)
		var at: Vector3
		if key in ["port", "shipyard"]:
			at = w.snap_to_hex(w.land_point(sea, 6.0)) if sea != null else w.start
		elif entry.contains(":"):
			var type: String = entry.get_slice(":", 1)
			var dep = null
			for d in w.deposits:
				if d.type == type and d.extractor == null:
					dep = d
					break
			if dep == null:
				continue
			at = w.snap_to_hex(dep.pos)
		else:
			at = w.snap_to_hex(w.land_point(w.start + Vector3(0, 0, -90), 50.0))
		var b: Dictionary = w.place_building(key, at, 0, true)
		w.cam_focus = b.root.position
		w.cam_dist = 36.0
		w.cam_dist_target = 36.0
		w.cam_pitch = 0.95
		w.cam_yaw = 0.7
		for f in range(25):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/industry-%s.png" % entry.replace(":", "-"))
		w.destroy_building(b) if false else null
		b.root.visible = false
	w.get_tree().quit()
