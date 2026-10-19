extends RefCounted
## Balance corrections found by measuring every armed unit's cost-efficiency
## (native/BALANCE-2026-10-18.md): hit points x damage per second x the damage it
## really does to what it fights, divided by what it costs. Units well above their
## own kind are brought back; nothing is made weaker than its cost would justify.
##
## Applied once, after every nation's and every role's own definition (modern_warfare.apply),
## by absolute values, so a second call changes nothing.

## key -> {stat: value} (cost entries are scaled: "cost_mult")
const UNITS := {
	"apc": {"dmg": 10.0},                                          # a troop carrier out-shot a tank per second
	"bushmaster": {"dmg": 10.0},
	"seaDrone": {"dmg": 240.0, "cost_mult": 1.3},                  # one hit nearly sank a destroyer for a third of its price
	"interceptorDrone": {"cost_mult": 1.35},                       # a cheap kill on any jet
	"loiterer": {"cost_mult": 1.3},
	"harop": {"cost_mult": 1.2},
	"gunship": {"dmg": 30.0, "cost_mult": 1.15},                   # the best damage per second per price in the game
}
## key -> {target class: multiplier}
const PROFILE := {
	"type45": {"air": 2.4},                                        # an air-defence destroyer should not also be the best value ship
	"aaVehicle": {"air": 2.8},
	"interceptorDrone": {"air": 1.5},
}
## missile key -> {field: value}
const MISSILES := {
	"ballistic": {"dmg": 1450.0, "cost_money": 1100.0},            # one missile flattened a whole block for less than a factory
	"tactical": {"cost_money": 290.0},
}

static func apply(w: Node) -> void:
	for key in UNITS:
		if not w.unit_defs.has(key) or w.unit_defs[key].get("balanced", false):
			continue
		var def: Dictionary = w.unit_defs[key]
		var change: Dictionary = UNITS[key]
		if change.has("dmg"):
			def.dmg = float(change.dmg)
		if change.has("cost_mult"):
			for resource in def.cost:
				def.cost[resource] = ceilf(float(def.cost[resource]) * float(change.cost_mult))
		def.balanced = true
	for key in PROFILE:
		if not w.damage_profile.has(key):
			continue
		for target in PROFILE[key]:
			w.damage_profile[key][target] = float(PROFILE[key][target])
	var types: Dictionary = w.map.missiles.types
	for key in MISSILES:
		if not types.has(key):
			continue
		var m: Dictionary = types[key]
		var change: Dictionary = MISSILES[key]
		if change.has("dmg"):
			m.dmg = float(change.dmg)
		if change.has("cost_money"):
			m.cost.money = float(change.cost_money)
