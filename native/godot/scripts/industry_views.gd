## --capture-industry: every building the kit makes for industry, resources
## and defence, laid out on open ground and photographed (build/industry-*.png).
extends RefCounted

const KEYS := ["extractor:oil", "extractor:iron", "extractor:gold", "extractor:silicon", "extractor:uranium", "extractor:diamond",
	"oilRefinery", "chipFab", "aiDataCenter", "fusionCell", "nuclearReactor", "solarFarm", "ammoDepot", "strategicComplex", "specialLab", "missileSilo", "helipad", "airfield", "bunker", "samSite", "park", "stadium", "port", "shipyard", "cityHall", "bank", "hospital"]

static func capture(w: Node) -> void:
	for i in range(30):
		await w.get_tree().process_frame
	w.edge_scroll = false   # a mouse resting at the window edge would scroll the picture away
	var sea = w.water_near(w.start, 320)
	# --only=aiDataCenter --yaw=0.0 --dist=22 narrow the pictures to one building from one side.
	var only := ""
	var yaw := 0.7
	var dist := 36.0
	var pitch := -1.0
	var as_nation := ""
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--only="): only = a.get_slice("=", 1)
		elif a.begins_with("--yaw="): yaw = float(a.get_slice("=", 1))
		elif a.begins_with("--dist="): dist = float(a.get_slice("=", 1))
		elif a.begins_with("--pitch="): pitch = float(a.get_slice("=", 1))
		elif a.begins_with("--as="): as_nation = a.get_slice("=", 1)   # draw it as this nation fields it
	for entry: String in KEYS:
		if only != "" and entry != only:
			continue
		var key: String = entry.get_slice(":", 0)
		var at: Vector3
		if key in ["port", "shipyard"]:
			at = w.snap_to_hex(w.land_point(sea, 15.0)) if sea != null else w.start
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
		if as_nation != "": w.map.nations[0].id = as_nation
		var b: Dictionary = w.place_building(key, at, 0, true)
		w.cam_focus = b.root.position
		w.cam_dist = dist
		w.cam_dist_target = dist
		w.cam_pitch = pitch if pitch > 0.0 else (0.95 if only == "" else 0.6)
		w.cam_yaw = yaw
		for f in range(40):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/industry-%s.png" % entry.replace(":", "-"))
		w.destroy_building(b) if false else null
		b.root.visible = false
	w.get_tree().quit()
