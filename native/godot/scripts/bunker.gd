extends RefCounted
## Bunkers hold ground. A built bunker:
## - fires its machine guns at the nearest hostile ground unit within REACH
##   (infantry suffer most, armour least; never at aircraft);
## - is hard to crack from the ground: fire from ground units does a third of
##   its damage to it (bombs, missiles and artillery shells still work);
## - shelters friendly troops within SHELTER: ground fire does them half damage.

const REACH := 42.0
const SHELTER := 16.0
const RELOAD := 0.8
const DAMAGE := 16.0
const VERSUS := {"infantry": 1.0, "light": 0.7, "armor": 0.25, "naval": 0.3, "building": 0.2}

static func update(w: Node, delta: float) -> void:
	for b in w.buildings:
		if b.dead or not b.built or b.key != "bunker" or w.disabled(b):
			continue
		b["mg_reload"] = maxf(0.0, float(b.get("mg_reload", 0.0)) - delta)
		if b.mg_reload > 0.0:
			continue
		var enemy = null
		var nearest := REACH
		for u in w.units:
			if u.dead or u.get("fly", false) or not w.hostile(b.owner, u.owner):
				continue
			var gap: float = w.flat_distance(b, u)
			if gap < nearest:
				nearest = gap
				enemy = u
		if enemy == null:
			continue
		b.mg_reload = RELOAD
		var from: Vector3 = b.root.position + Vector3.UP * 1.4
		var to: Vector3 = enemy.node.position + Vector3.UP * 0.9
		w.effects.muzzle_flash(from + (to - from).normalized() * 2.5, false)
		w.effects.tracer(from, to)
		w.damage(enemy, DAMAGE * float(VERSUS.get(w.target_class(enemy), 0.5)), b)

## Damage multiplier for `amount` from `source` hitting `target` (1 = full).
static func cover(w: Node, target: Dictionary, source: Dictionary) -> float:
	if source.get("fly", false) or source.get("is_building", false) or not source.has("key"):
		return 1.0  # aircraft, missiles and fortifications hit as hard as ever
	if source.key in ["artillery", "mlrs"]:
		return 1.0  # shells come down from above
	if target.get("is_building", false):
		return 0.33 if target.key == "bunker" else 1.0
	if target.get("fly", false) or target.get("naval", false):
		return 1.0
	for b in w.buildings:
		if b.key == "bunker" and b.built and not b.dead and b.owner == target.owner and w.flat_distance(b, target) < SHELTER:
			return 0.5
	return 1.0
