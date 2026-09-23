## --capture-terrain: the ground from above and close up, and the lakes
## (build/terrain-*.png), to judge the land, the trees and the water.
extends RefCounted

static func capture(w: Node) -> void:
	for i in range(40):
		await w.get_tree().process_frame
	# The lake: the lowest dry-land basin nearest the middle of the island.
	var lake := Vector3.ZERO
	var best := INF
	for x in range(-200, 201, 8):
		for z in range(-200, 201, 8):
			var h: float = w.height_at(x, z)
			if h < float(w.map.seaLevel) and Vector2(x, z).length() < best:
				best = Vector2(x, z).length()
				lake = Vector3(x, h, z)
	var shots := [["top", Vector3(0, 0, 0), 420.0, 1.45, 0.0], ["high", w.start + Vector3(-80, 0, 60), 220.0, 1.2, 0.6],
		["field", w.start + Vector3(-70, 0, 50), 60.0, 0.55, 0.8], ["lake", lake, 90.0, 0.7, 0.4], ["lake-close", lake, 40.0, 0.45, 1.2]]
	for shot in shots:
		w.cam_focus = shot[1]
		w.cam_dist = shot[2]
		w.cam_dist_target = shot[2]
		w.cam_pitch = shot[3]
		w.cam_yaw = shot[4]
		for f in range(30):
			await w.get_tree().process_frame
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png("res://build/terrain-%s.png" % shot[0])
	w.get_tree().quit()
