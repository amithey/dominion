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
	"apc": {"dmg": 10.0, "cooldown": 0.65},                          # a troop carrier out-shot a tank per second
	"bushmaster": {"dmg": 10.0, "cooldown": 0.78},
	"heavyAPC": {"hp": 740.0, "cooldown": 0.85},
	"machineGunTeam": {"cooldown": 0.50},
	"combatUGV": {"cooldown": 0.62},
	"seaDrone": {"dmg": 120.0, "cost_mult": 1.3},                  # explosive USV: takes 3-5 hits to sink warships instead of 1-shotting them
	"interceptorDrone": {"dmg": 85.0, "cost_mult": 1.35},          # dedicated anti-drone interceptor
	"suicideSquad": {"dmg": 95.0, "cost_mult": 1.9},               # glass-cannon blast team: price & blast tuned
	"loiterer": {"dmg": 120.0, "cost_mult": 1.3},
	"harop": {"cost_mult": 1.2},
	"gunship": {"dmg": 26.0, "cost_mult": 1.15},                   # trimmed so gunships do not dominate every ground battle
	"type45": {"cooldown": 3.9},                                   # air-defence destroyer: strong AA without excessive DPS
	"destroyer": {"cooldown": 2.8},
	"orca": {"cooldown": 2.8},
	"aaVehicle": {"dmg": 11.0},                                    # mobile SPAAG: effective AA, not top overall value
	"submarine": {"hp": 460.0, "dmg": 120.0, "cooldown": 4.5, "range": 34.0, "cost_mult": 1.55},       # tactical attack submarine: heavy torpedoes & stealth hull
	"nuclearSub": {"hp": 680.0, "dmg": 150.0, "cooldown": 4.5, "range": 38.0, "cost_mult": 1.35},      # nuclear submarine: heavy torpedoes & deep-water durability
	"asFrigate": {"dmg": 65.0, "cooldown": 2.4},                   # dedicated ASW escort
	"maritimePatrol": {"dmg": 110.0, "cooldown": 3.6},             # dedicated ASW patrol aircraft
	"navalHelicopter": {"dmg": 95.0, "cooldown": 3.0},             # carrier/coastal ASW helicopter
	"missileBoat": {"dmg": 98.0, "cooldown": 4.5},                 # fast anti-ship missile craft
	"kcr60": {"dmg": 55.0, "cooldown": 2.6},
	"lightFighter": {"dmg": 72.0, "cooldown": 2.1},                # nimble multirole fighter
	"stealthFighter": {"dmg": 105.0, "cooldown": 2.2},
	"jf17": {"dmg": 90.0, "cooldown": 2.2},
	"attackJet": {"dmg": 95.0, "cooldown": 2.5},                   # close air support strike jet
	"akinci": {"dmg": 78.0, "cooldown": 2.1},                      # heavy MALE strike drone
	"drone": {"dmg": 26.0, "cooldown": 0.70},                      # armed tactical UCAV
	"heavyBomberDrone": {"dmg": 45.0, "cooldown": 6.0},           # heavy drone bomber
	"soldier": {"dmg": 12.0},                                      # core line infantry
	"sniper": {"dmg": 62.0, "cooldown": 2.8},
	"atgmTeam": {"dmg": 85.0, "cooldown": 4.5},
	"fpvTeam": {"dmg": 75.0, "cooldown": 4.2},                     # infantry FPV drone operators
	"shaheenDrone": {"dmg": 68.0, "cooldown": 4.5},
	"coastalDrone": {"dmg": 82.0, "cooldown": 3.8, "cost_mult": 0.70},
	"robotDog": {"dmg": 20.0, "cooldown": 0.85},                   # armed quadruped scout
	"reconVehicle": {"dmg": 16.0, "cooldown": 0.70},               # armoured recon
	"shortRangeSAM": {"dmg": 54.0, "cooldown": 2.3},               # mobile SHORAD
	"tos1a": {"dmg": 135.0, "cooldown": 7.5},                      # thermobaric rocket salvo
	"mortarTeam": {"dmg": 54.0, "cooldown": 2.7},                  # infantry fire support
	"recoillessTeam": {"dmg": 58.0, "cooldown": 2.9},              # anti-armor infantry team
	"artillery": {"dmg": 82.0, "cooldown": 3.3},                   # self-propelled howitzer
	"k9": {"dmg": 78.0, "cooldown": 2.7},                          # modern SPG
	"towedHowitzer": {"dmg": 85.0, "cooldown": 3.8},
	"wheeledHowitzer": {"dmg": 90.0, "cooldown": 3.6},
	"mlrs": {"dmg": 105.0, "cooldown": 4.0},
	"himars": {"dmg": 125.0, "cooldown": 5.0},
	"heavyRocket": {"dmg": 130.0, "cooldown": 5.0},
	"coastalASM": {"dmg": 150.0, "cooldown": 5.0},
}
## key -> {target class: multiplier}
const PROFILE := {
	"samLauncher": {"air": 3.2},
	"type45": {"air": 2.4},                                        # an air-defence destroyer should not also be the best value ship
	"aaVehicle": {"air": 2.8},
	"interceptorDrone": {"air": 1.5},
	"seaDrone": {"naval": 1.35, "building": 0.6},
	"loiterer": {"naval": 0.8, "armor": 1.4, "light": 1.5, "building": 1.0},
	"submarine": {"naval": 2.0, "building": 1.2, "air": 0.0},
	"nuclearSub": {"naval": 2.1, "building": 1.5, "air": 0.0},
	"orca": {"naval": 2.2, "air": 0.0},
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
		if change.has("hp"):
			def.hp = float(change.hp)
		if change.has("cooldown"):
			def.cooldown = float(change.cooldown)
		if change.has("range"):
			def.range = float(change.range)
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
