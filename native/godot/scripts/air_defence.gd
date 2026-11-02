extends RefCounted
## Batteries share a cooldown between aircraft defence and missile interception.
static func update(w: Node, delta: float) -> void:
	for b in w.buildings:
		if b.dead or not b.built or b.key != "samSite" or w.disabled(b) or not b.get("supplied", true): continue
		b["aa_reload"] = maxf(0.0, float(b.get("aa_reload", 0.0)) - delta)
		if b.aa_reload > 0.0: continue
		var ADS := preload("res://scripts/air_defence_systems.gd")
		var enemy = null
		var reach := ADS.reach(w, int(b.owner))   # the nation's own system
		var nearest := reach
		# AI battle management: batteries share targets, no two shots at one aircraft (ai_directorate.gd).
		var shared: bool = w.get("directorate") != null and w.directorate != null and w.directorate.coordinated(int(b.owner))
		for u in w.units:
			if u.dead or not w.airborne(u) or not w.hostile(b.owner, u.owner): continue  # only aircraft in flight
			if shared and float(u.get("aa_claimed_until", 0.0)) > w.game_time and int(u.get("aa_claimed_by", -1)) == int(b.owner): continue
			var gap: float = w.flat_distance(b, u)
			if preload("res://scripts/modern_warfare.gd").hidden(w, u, gap, reach): continue  # stealth
			if gap < nearest:
				nearest = gap
				enemy = u
		if enemy == null: continue
		if not preload("res://scripts/war_costs.gd").pay(w, int(b.owner), 5.0, 0.0, "intercepts"):
			preload("res://scripts/war_costs.gd").blocked(w, b, "interceptor budget")
			continue
		b.aa_reload = ADS.reload_time(w, int(b.owner))
		if shared:
			enemy.aa_claimed_until = w.game_time + 1.5
			enemy.aa_claimed_by = int(b.owner)
		var target: Dictionary = enemy
		w.effects.projectile("missile", b.root.position + Vector3.UP * 5, target.node.position, func(at):
			w.effects.explosion(at, 0.7, false)
			if not target.dead and w.hostile(b.owner, target.owner): w.damage(target, ADS.aircraft_damage(w, int(b.owner)), b), 0.0, target.node)

## Missile interception: every SAM site, mobile SAM, missile defence battery
## and laser the missile flies past gets one shot, with odds by missile class
## (modern_warfare.gd: cruise missiles are usually stopped, ballistic ones
## need an ABM battery, hypersonic ones mostly get through).
static func intercept(w: Node, missile: Dictionary, at: Vector3, f := 1.0) -> bool:
	return preload("res://scripts/modern_warfare.gd").intercept(w, missile, at, f)
