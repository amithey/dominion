extends RefCounted
## Shrubs beside the groves: leafy cards from the shrub atlas (foliage_cards.gd), placed next to a share of the map's trees and felled
## with them when a building needs the ground (world.tree_parts, site_clearing.gd).

static func build(w: Node) -> void:
	var Cards := preload("res://scripts/foliage_cards.gd")
	var spots: Array = []
	for t in w.map.trees:
		var h := fposmod(sin(t.x * 4.7 + t.z * 9.1) * 43758.5453, 1.0)
		if h < 0.45:
			var a := h * TAU * 5.0
			var d := 3.0 + fposmod(h * 31.0, 1.0) * 5.0
			var x: float = t.x + cos(a) * d
			var z: float = t.z + sin(a) * d
			if w.height_at(x, z) > float(w.map.seaLevel) + 1.0:
				spots.append({"x": x, "z": z, "scale": 0.6 + fposmod(h * 17.0, 1.0) * 0.8})
	# One MultiMesh per 96 m cell, so the ones outside the view are culled.
	var cells := {}
	for s in spots:
		var key := Vector2i(floori(s.x / 96.0), floori(s.z / 96.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(s)
	for key in cells:
		var list: Array = cells[key]
		var card_spots := []
		for s in list:
			var tone := fposmod(sin(s.x * 3.3 + s.z * 5.9) * 43758.5453, 1.0)
			card_spots.append({"pos": Vector3(s.x, w.height_at(s.x, s.z) - 0.1, s.z), "scale": 0.7 + float(s.scale) * 0.8, "yaw": fmod(s.x * 12.9898 + s.z * 78.233, TAU), "cell": int(tone * 4.0) % 4, "tone": tone})
		var node: MultiMeshInstance3D = Cards.patch("bush", card_spots)
		for i in range(list.size()):
			var spot := Vector2(list[i].x, list[i].z)
			if not w.tree_parts.has(spot):
				w.tree_parts[spot] = []
			w.tree_parts[spot].append([node.multimesh, i])
		node.visibility_range_end = 260.0
		node.visibility_range_end_margin = 20.0
		w.add_child(node)
		w.tree_nodes.append(node)
