## Rolling hills on every map of the generator: for each map, the land that stops being buildable because of the hills (a hex whose six
## points differ by more than 6 m, a 8 m site whose heights differ by more than 3.5 m), and that nothing the map places has moved.
## Run: Godot --headless --path native/godot --script res://tools/hills-maps-check.gd [-- map ...]
extends SceneTree

const Topography := preload("res://scripts/topography.gd")
const Gen := preload("res://scripts/map_generator.gd")

func _init() -> void:
	var keys: Array = []
	for a in OS.get_cmdline_user_args():
		keys.append(a)
	if keys.is_empty():
		keys = ["island"] + Gen.MAPS.keys()
	var all_ok := true
	for key in keys:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
		if key != "island":
			Gen.generate(data, key)
		var g: Dictionary = data.grid
		var n := int(g.size)
		var step := float(g.step)
		var origin := Vector2(g.origin[0], g.origin[1])
		var sea := float(data.seaLevel)
		var h0 := PackedFloat32Array()
		h0.resize(n * n)
		for i in range(n * n):
			h0[i] = maxf(float(g.heightsCm[i]) / 100.0, -36.0)
		Topography.refine(h0, n, sea)
		h0 = Topography.heights()
		var h1 := h0.duplicate()
		preload("res://scripts/hills.gd").apply(h1, n, step, origin, sea, data)
		var moved := 0
		var placed := 0
		for k in ["startPositions", "buildings", "deposits", "units"]:
			for e in data.get(k, []):
				var x: float = (e[0] if e is Array else e.x)
				var z: float = (e[1] if e is Array else e.z)
				var ci := int(round((x - origin.x) / step))
				var cj := int(round((z - origin.y) / step))
				if ci < 0 or cj < 0 or ci >= n or cj >= n:
					continue
				placed += 1
				if absf(h1[cj * n + ci] - h0[cj * n + ci]) > 0.05:
					moved += 1
		# Hex test over the dry land on a 12 m lattice, as site_problem does for a district.
		var hex_ok0 := 0
		var hex_ok1 := 0
		var hex_n := 0
		var site_ok0 := 0
		var site_ok1 := 0
		var r := 12.0 * 0.8
		var x := origin.x + 40.0
		while x < origin.x + n * step - 40.0:
			var z := origin.y + 40.0
			while z < origin.y + n * step - 40.0:
				var cx := int(round((x - origin.x) / step))
				var cz := int(round((z - origin.y) / step))
				z += 12.0
				if h0[cz * n + cx] < sea + 1.0:
					continue
				var lo0 := INF
				var hi0 := -INF
				var lo1 := INF
				var hi1 := -INF
				var dry := true
				for k in range(6):
					var a := deg_to_rad(30.0 + 60.0 * k)
					var px := int(round((x + cos(a) * r - origin.x) / step))
					var pz := int(round((z - 12.0 + sin(a) * r - origin.y) / step))
					lo0 = minf(lo0, h0[pz * n + px])
					hi0 = maxf(hi0, h0[pz * n + px])
					lo1 = minf(lo1, h1[pz * n + px])
					hi1 = maxf(hi1, h1[pz * n + px])
				if lo0 < sea + 0.25:
					continue
				hex_n += 1
				if hi0 - lo0 <= 6.0: hex_ok0 += 1
				if hi1 - lo1 <= 6.0: hex_ok1 += 1
				# the middle building footprint: heights over a 7 m square round the centre
				var l0 := INF
				var u0 := -INF
				var l1 := INF
				var u1 := -INF
				for dz in [-3.5, 0.0, 3.5]:
					for dx in [-3.5, 0.0, 3.5]:
						var qi := int(round((x + dx - origin.x) / step))
						var qj := int(round((z - 12.0 + dz - origin.y) / step))
						l0 = minf(l0, h0[qj * n + qi]); u0 = maxf(u0, h0[qj * n + qi])
						l1 = minf(l1, h1[qj * n + qi]); u1 = maxf(u1, h1[qj * n + qi])
				if u0 - l0 <= 3.5: site_ok0 += 1
				if u1 - l1 <= 3.5: site_ok1 += 1
			x += 12.0
		var lost_hex := 100.0 * float(hex_ok0 - hex_ok1) / maxf(hex_n, 1)
		var lost_site := 100.0 * float(site_ok0 - site_ok1) / maxf(hex_n, 1)
		var ok := moved == 0 and lost_hex < 4.0 and lost_site < 4.0
		if not ok: all_ok = false
		print("%-16s land hexes %5d  buildable hex %.1f%% -> %.1f%%  site %.1f%% -> %.1f%%  placed %d moved %d  %s" % [key, hex_n, 100.0 * hex_ok0 / maxf(hex_n, 1), 100.0 * hex_ok1 / maxf(hex_n, 1), 100.0 * site_ok0 / maxf(hex_n, 1), 100.0 * site_ok1 / maxf(hex_n, 1), placed, moved, "ok" if ok else "TOO MUCH"])
	print("HILLS_MAPS PASS" if all_ok else "HILLS_MAPS FAIL")
	quit()
