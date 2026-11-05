## Rolling hills: how much of the dry land they change, by how much, how steep the result is, and that the starts, buildings and deposits keep their ground.
## Run: Godot --headless --path native/godot --script res://tools/hills-check.gd
extends SceneTree

func _init() -> void:
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	var g: Dictionary = map.grid
	var n := int(g.size)
	var step := float(g.step)
	var origin := Vector2(g.origin[0], g.origin[1])
	var before := PackedFloat32Array()
	before.resize(n * n)
	for i in range(n * n):
		before[i] = maxf(float(g.heightsCm[i]) / 100.0, -36.0)
	var after := before.duplicate()
	preload("res://scripts/hills.gd").apply(after, n, step, origin, float(map.seaLevel), map)
	var land := 0
	var changed := 0
	var biggest := 0.0
	var steepest_before := 0.0
	var steepest_after := 0.0
	for j in range(1, n - 1):
		for i in range(1, n - 1):
			var k := j * n + i
			if before[k] > float(map.seaLevel) + 1.5:
				land += 1
				var d := absf(after[k] - before[k])
				if d > 0.3:
					changed += 1
				biggest = maxf(biggest, d)
			var sb := Vector2(before[k + 1] - before[k - 1], before[k + n] - before[k - n]).length() / (2.0 * step)
			var sa := Vector2(after[k + 1] - after[k - 1], after[k + n] - after[k - n]).length() / (2.0 * step)
			if before[k] > float(map.seaLevel) + 1.5:
				steepest_before = maxf(steepest_before, sb)
				steepest_after = maxf(steepest_after, sa)
	var bad := 0
	for key in ["startPositions", "buildings", "deposits"]:
		for e in map.get(key, []):
			var x: float = (e[0] if e is Array else e.x)
			var z: float = (e[1] if e is Array else e.z)
			var ci := int(round((x - origin.x) / step))
			var cj := int(round((z - origin.y) / step))
			if absf(after[cj * n + ci] - before[cj * n + ci]) > 0.05:
				bad += 1
	print("land cells %d, changed by over 0.3 m: %d (%.0f%%), biggest change %.1f m, steepest slope %.2f -> %.2f, placed things moved: %d" % [land, changed, 100.0 * changed / maxf(land, 1), biggest, steepest_before, steepest_after, bad])
	print("HILLS PASS" if bad == 0 and changed > land / 5 and steepest_after < steepest_before + 0.12 else "HILLS FAIL")
	quit()
