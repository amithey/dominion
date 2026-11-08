extends RefCounted
## Topographical High-Ground Advantage & Ridge Line-of-Sight (Track 3B):
##   - Units positioned on hills/ridges gain elevated sight (+22% max) and
##     direct-fire / radar reach (+15% max).
##   - Firing downhill (>= 3.0m height advantage) deals up to +15% damage, while
##     firing uphill into an elevated defender suffers a -12% penalty.
##   - Steep intervening terrain crests occlude direct ground-to-ground spotting
##     in fog_of_war.gd (aircraft, satellites, and high-ground observers see over).

static func elevation_above_sea(w: Node, pos: Vector3) -> float:
	if w == null or w.get("map") == null:
		return 0.0
	return maxf(0.0, w.height_at(pos.x, pos.z) - float(w.map.seaLevel))

## Sight multiplier for fog_of_war.gd (1.0 on flat lowlands, up to 1.22 on high ridges; +20% if garrisoned).
static func sight_mult(w: Node, u: Dictionary) -> float:
	var mult := 1.0
	if u.get("garrison_building") != null:
		mult *= 1.20
	if u.get("fly", false) or u.get("naval", false):
		return mult
	var elev := elevation_above_sea(w, u.node.position)
	if elev > 4.5:
		mult *= 1.0 + clampf((elev - 4.5) / 28.0, 0.0, 0.22)
	return mult

## Effective weapon range bonus multiplier for elevated ground units (1.0 .. 1.15).
static func range_mult(w: Node, u: Dictionary) -> float:
	if u.get("fly", false) or u.get("naval", false):
		return 1.0
	var elev := elevation_above_sea(w, u.node.position)
	if elev <= 5.0:
		return 1.0
	return 1.0 + clampf((elev - 5.0) / 34.0, 0.0, 0.15)

## Combat damage multiplier from relative ground elevation between attacker and target.
static func damage_mult(w: Node, attacker: Dictionary, target: Dictionary) -> float:
	if w == null or attacker.is_empty() or target.is_empty():
		return 1.0
	if attacker.get("fly", false) or target.get("fly", false) or attacker.get("naval", false):
		return 1.0
	var a_node = attacker.get("node") if not attacker.get("is_building", false) else attacker.get("root")
	var t_node = target.get("node") if not target.get("is_building", false) else target.get("root")
	if a_node == null or t_node == null or not is_instance_valid(a_node) or not is_instance_valid(t_node):
		return 1.0
	var ha: float = float(w.height_at(a_node.position.x, a_node.position.z)) + (3.0 if attacker.get("garrison_building") != null else 0.0)
	var ht: float = float(w.height_at(t_node.position.x, t_node.position.z)) + (3.0 if target.get("garrison_building") != null else 0.0)
	var diff: float = ha - ht
	if diff >= 3.0:
		return 1.0 + clampf((diff - 2.0) / 26.0, 0.0, 0.15)
	if diff <= -3.5:
		return 0.88
	return 1.0

## True when a ground observer at `from_pos` has an unobstructed line of sight to `to_pos`
## (no intervening hill crest rising > 4.0m above the eye-to-target ray).
static func los_clear(w: Node, from_pos: Vector3, to_pos: Vector3, observer_elevated := false) -> bool:
	if observer_elevated or w == null:
		return true
	var flat_d := Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z).length()
	if flat_d < 22.0:
		return true
	var eye_a: float = float(w.height_at(from_pos.x, from_pos.z)) + 2.4
	var eye_b: float = float(w.height_at(to_pos.x, to_pos.z)) + 2.2
	for t in [0.33, 0.52, 0.70]:
		var mx := lerpf(from_pos.x, to_pos.x, t)
		var mz := lerpf(from_pos.z, to_pos.z, t)
		var ray_y := lerpf(eye_a, eye_b, t)
		var ground_y: float = w.height_at(mx, mz)
		if ground_y > ray_y + 3.8:
			return false
	return true
