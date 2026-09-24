extends RefCounted
## Batteries share a cooldown between aircraft defence and missile interception.
static func update(w: Node, delta: float) -> void:
	for b in w.buildings:
		if b.dead or not b.built or b.key != "samSite" or w.disabled(b) or not b.get("supplied", true): continue
		b["aa_reload"] = maxf(0.0, float(b.get("aa_reload", 0.0)) - delta)
		if b.aa_reload > 0.0: continue
		var enemy = null
		var nearest := 140.0
		for u in w.units:
			if u.dead or not u.get("fly", false) or not w.hostile(b.owner, u.owner): continue
			var gap: float = w.flat_distance(b, u)
			if gap < nearest:
				nearest = gap
				enemy = u
		if enemy == null: continue
		b.aa_reload = 2.2
		var target: Dictionary = enemy
		w.effects.projectile("missile", b.root.position + Vector3.UP * 5, target.node.position, func(at):
			w.effects.explosion(at, 0.7, false)
			if not target.dead and w.hostile(b.owner, target.owner): w.damage(target, 44.0, b), 0.0, target.node)

static func intercept(w: Node, missile: Dictionary, at: Vector3) -> bool:
	# SAMs can intercept low-flying cruise missiles; ballistic warheads require
	# specialised ABM systems, which are deliberately not implied here.
	if missile.arc: return false
	for b in w.buildings:
		if b.dead or not b.built or b.key != "samSite" or w.disabled(b) or not b.get("supplied", true): continue
		if not w.hostile(b.owner, missile.owner) or float(b.get("aa_reload", 0.0)) > 0: continue
		if b.root.position.distance_to(at) > 140.0: continue
		b["aa_reload"] = 2.2
		w.effects.projectile("missile", b.root.position + Vector3.UP * 5, at, func(hit): w.effects.explosion(hit, 1.2, false))
		return true
	return false
