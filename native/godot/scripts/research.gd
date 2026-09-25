extends Node
## Research, discoveries and national development eras.
## The discoveries, research tracks and eras come from config.js (DISCOVERIES,
## TECH_TRACKS, DEVELOPMENT_ERAS through the map export); this file adds how
## the native game develops them:
## - The nation advances through six eras (Founding to Future) by meeting real
##   goals: villages and cities, citizens, discoveries, trade routes, land.
##   Each discovery belongs to an era and cannot be started before it.
## - Every discovery is developed in three stages that suit its branch (design,
##   prototype, field trials for weapons; study, pilot, national rollout for
##   society...). Each stage needs research points and time; the prototype
##   stage needs the facility (reqBuilding) and materials, the last stage money.
##   A finished prototype already gives half the effect; the last stage gives
##   all of it and the unlocks (warships, strategic missiles, the nuclear boat).
## - Research is a queue of projects, not a purchase: points from the capital,
##   schools, libraries, universities and tech parks flow into the active stage
##   every second, and no stage completes in less than 20 seconds.
## - Research tracks (Economics, Military Science, Covert Ops, High-Tech) level
##   up to 5; level N needs era N.
## Rival nations research too (a tech level that raises their income, damage
## and armour); agents can steal research or kill a rival's chief scientist.

signal changed

const BRANCHES := ["society", "economy", "army", "air", "navy", "hightech", "strategic", "politics"]
const BRANCH_NAMES := {"society": "Society", "economy": "Economy", "army": "Ground forces", "air": "Air power",
	"navy": "Naval power", "hightech": "High technology", "strategic": "Strategic weapons", "politics": "Statecraft"}
## The three development stages of a discovery, by branch.
const STAGES := {
	"society": ["Study", "Pilot programme", "National rollout"],
	"economy": ["Research", "Pilot plant", "Industrial rollout"],
	"army": ["Design", "Prototype", "Field trials"],
	"air": ["Design", "Prototype", "Flight testing"],
	"navy": ["Design", "Prototype", "Sea trials"],
	"hightech": ["Research", "Prototype", "Mass production"],
	"strategic": ["Research", "Test programme", "Deployment"],
	"politics": ["Draft", "Pilot scheme", "Enactment"],
}
const STAGE_SHARE := [0.35, 0.35, 0.30]   # share of the research cost in each stage
const MIN_STAGE_SECONDS := 20.0
const QUEUE_MAX := 4

## Which era (0 Founding .. 5 Future) opens each discovery.
const ERA_OF := {
	"fertilizers": 0, "forestry": 0, "taxAdministration": 0, "eliteTraining": 0, "diplomaticCorps": 0,
	"irrigation": 1, "publicEducation": 1, "globalLogistics": 1, "compositeArmor": 1, "navalEngineering": 1, "aquaculture": 1, "jetPropulsion": 1, "massMedia": 1,
	"advancedMedicine": 2, "urbanPlanning": 2, "stockExchange": 2, "industrialization": 2, "advancedLogistics": 2, "sonarSystems": 2, "secretPolice": 2, "microchips": 2, "ballisticTech": 2,
	"nationalHealth": 3, "welfareState": 3, "heavyIndustry": 3, "advancedMining": 3, "guidedMunitions": 3, "precisionStrikes": 3, "offshoreDrilling": 3, "robotics": 3, "satelliteRecon": 3, "cyberWarfare": 3, "constitutionalReform": 3,
	"combinedArms": 4, "droneSwarms": 4, "stealthTech": 4, "aiRevolution": 4, "nuclearProgram": 4,
	"quantumComputing": 5, "fusionPower": 5,
}
## Effects the native game applies where config.js describes them only in words
## (or describes systems the native game does not have), with matching text.
const NATIVE := {
	"fertilizers": [{"foodPct": 0.5}, ""],
	"forestry": [{"forestPct": 1.0}, "Forest land yields twice as much money."],
	"advancedMedicine": [{"health": 10}, "+10 health: citizens grow faster. Requires a Hospital."],
	"stockExchange": [{"incomePct": 0.15}, ""],
	"robotics": [{"buildPct": 0.5}, "Construction is 50% faster: the machines do the heavy work."],
	"aiRevolution": [{"researchPct": 0.2, "incomePct": 0.1}, ""],
	"stealthTech": [{"airArmor": 0.3}, ""],
	"satelliteRecon": [{"warn": 1.0}, "Every attack on you is reported 30 seconds before it sets out."],
	"microchips": [{"chips": 1.0}, "Chip Fabs turn silicon into money and research. Requires a Tech Park."],
	"navalEngineering": [{}, "Unlocks the Destroyer and the Submarine, and the Anti-Ship Missile. Requires a Shipyard."],
	"ballisticTech": [{}, "Unlocks Ballistic and Hypersonic Missiles. Requires a Missile Silo."],
	"nuclearProgram": [{}, "Unlocks the Nuclear Missile and the Nuclear Submarine. Requires a Nuclear Reactor. The world will fear, and hate, you."],
	"fusionPower": [{"incomePct": 0.15, "prodPct": 0.1}, "+15% income and +10% production: energy too cheap to meter."],
	"massMedia": [{"happiness": 4}, "+4 happiness. Requires a TV Station."],
	"secretPolice": [{"counterSpy": 0.2, "happiness": -3}, "+20% chance to catch enemy agents, -3 happiness. Requires a Police Station."],
	"constitutionalReform": [{"incomePct": 0.05, "ransomPct": -0.5}, "+5% income; captured agents are released for half the ransom. Requires a Courthouse."],
	"offshoreDrilling": [{"coastOil": 1.0}, "Coastal land yields oil. Requires a Shipyard."],
	"aquaculture": [{"coastFood": 1.0}, "Coastal land yields food. Requires a Shipyard."],
	"welfareState": [{"happiness": 8, "incomePct": -0.06}, "+8 happiness, but -6% income."],
	"nationalHealth": [{"health": 8, "happiness": 3}, "+8 health, +3 happiness."],
	"publicEducation": [{"researchPct": 0.1}, "+10% research. Requires a School."],
}
const UNIT_REQUIRES := {"destroyer": "navalEngineering", "submarine": "navalEngineering", "nuclearSub": "nuclearProgram"}
const LABS := ["school", "library", "university", "techPark"]
const BASE_RATE := 0.4

var world: Node
var discoveries := {}
var tracks_cfg := {}
var eras: Array = []
var points := 0.0
var rate := 0.0
var progress := {}        # key -> {"stage": finished stages 0..3, "work": points in the current stage, "paid": bool}
var tracks := {}          # track -> level
var queue: Array = []     # discovery keys or "track:<name>"
var era := 0
var _tick := 0.0
var _ai_tick := 0.0
var _bonus := {}          # cached effect totals

func setup(world_node: Node, cfg: Dictionary) -> void:
	world = world_node
	discoveries = cfg.discoveries
	tracks_cfg = cfg.tracks
	eras = cfg.eras
	for key in discoveries:
		progress[key] = {"stage": 0, "work": 0.0, "paid": false}
	for key in tracks_cfg:
		tracks[key] = 0
	_recompute()

# ---------------------------------------------------------------- queries

func def_of(key: String) -> Dictionary:
	return discoveries.get(key, {})

func stage_of(key: String) -> int:
	return int(progress.get(key, {}).get("stage", 0))

func done(key: String) -> bool:
	return stage_of(key) >= 3

func era_of(key: String) -> int:
	return ERA_OF.get(key, 5)

func desc_of(key: String) -> String:
	var text: String = NATIVE.get(key, [{}, ""])[1]
	return text if text != "" else def_of(key).get("desc", "")

func effects_of(key: String) -> Dictionary:
	var fx: Dictionary = def_of(key).get("fx", {}).duplicate()
	if NATIVE.has(key):
		var native: Dictionary = NATIVE[key][0]
		if NATIVE[key][1] != "":
			fx = {}  # the native text replaces the browser's effects
		fx.merge(native, true)
	return fx

func stage_names(key: String) -> Array:
	return STAGES.get(def_of(key).get("branch", "society"), STAGES.society)

func stage_points(key: String, stage: int) -> float:
	return roundf(float(def_of(key).get("cost", 200)) * STAGE_SHARE[stage])

## Materials a stage needs before it can start (the prototype and the last stage).
func stage_cost(key: String, stage: int) -> Dictionary:
	var c := float(def_of(key).get("cost", 200))
	var branch: String = def_of(key).get("branch", "society")
	if stage == 0:
		return {}
	var cost := {}
	if stage == 1:
		match branch:
			"army", "navy":
				cost = {"money": c * 0.5, "iron": c * 0.12}
			"air":
				cost = {"money": c * 0.5, "iron": c * 0.08, "oil": c * 0.05}
			"hightech":
				cost = {"money": c * 0.5, "silicon": c * 0.06}
			"strategic":
				cost = {"money": c * 0.6, "iron": c * 0.1, "silicon": c * 0.04}
			"economy":
				cost = {"money": c * 0.6}
			_:
				cost = {"money": c * 0.5}
	else:
		cost = {"money": c * (0.8 if branch in ["strategic", "politics", "society"] else 0.6)}
		if branch == "economy":
			cost.iron = c * 0.05
		if key == "nuclearProgram":
			cost.uranium = 20.0
	for k in cost:
		cost[k] = roundf(cost[k])
	return cost

## Why `key` cannot advance to its next stage now ("" when it can).
func blocker(key: String) -> String:
	var stage := stage_of(key)
	if stage >= 3:
		return "Complete"
	if era_of(key) > era:
		return "Needs the %s" % eras[era_of(key)].name
	var need = def_of(key).get("reqDiscovery")
	if need != null and not done(need):
		return "Needs %s" % def_of(need).name
	var building = def_of(key).get("reqBuilding")
	if stage >= 1 and building != null and world.economy.owned(building) == 0:
		var name: String = world.building_defs.get(building, {"name": building}).name
		if world.economy.standing(building) > 0:
			# Built, but its settlement is cut off from the capital: it still
			# counts as a facility, and the player is told what is wrong.
			return ""
		for b in world.buildings:
			if b.owner == 0 and b.key == building and not b.dead and not b.built:
				return "%s needs a %s (under construction: %d%%)" % [stage_names(key)[stage], name, int(b.progress * 100)]
		return "%s needs a %s" % [stage_names(key)[stage], name]
	return ""

func available(key: String) -> bool:
	return blocker(key) == ""

func completed_count() -> int:
	var n := 0
	for key in progress:
		if done(key):
			n += 1
	return n

## The total of one effect over every discovery (half from a finished
## prototype, all of it once complete) and the research tracks.
func bonus(stat: String) -> float:
	return float(_bonus.get(stat, 0.0))

func _recompute() -> void:
	_bonus = {}
	for key in progress:
		var stage := stage_of(key)
		if stage < 2:
			continue
		var scale := 1.0 if stage >= 3 else 0.5
		var fx := effects_of(key)
		for stat in fx:
			_bonus[stat] = float(_bonus.get(stat, 0.0)) + float(fx[stat]) * scale
	var t := tracks
	_add("incomePct", 0.12 * t.get("economy", 0) + 0.04 * t.get("hightech", 0))
	_add("dmgAll", 0.08 * t.get("military", 0))
	_add("hpAll", 0.08 * t.get("military", 0))
	_add("spyPct", 0.08 * t.get("espionage", 0))
	_add("researchPct", 0.06 * t.get("hightech", 0))

func _add(stat: String, v: float) -> void:
	_bonus[stat] = float(_bonus.get(stat, 0.0)) + v

## "" when the player may train `unit`, otherwise what it needs.
func unit_locked(unit: String) -> String:
	var need: String = UNIT_REQUIRES.get(unit, "")
	return "" if need == "" or done(need) else "Needs %s" % def_of(need).name

# ---------------------------------------------------------------- projects

func track_cost(key: String) -> float:
	return float(tracks_cfg[key].baseCost) * (tracks.get(key, 0) + 1)

func track_blocker(key: String) -> String:
	var level: int = tracks.get(key, 0)
	if level >= int(tracks_cfg[key].max):
		return "Maxed"
	if level > era:
		return "Level %d needs the %s" % [level + 1, eras[mini(level, eras.size() - 1)].name]
	return ""

func enqueue(item: String) -> String:
	if item in queue:
		return ""
	if queue.size() >= QUEUE_MAX:
		return "The research queue is full (%d projects)." % QUEUE_MAX
	if item.begins_with("track:"):
		var why := track_blocker(item.substr(6))
		if why != "":
			return why
	else:
		var why := blocker(item)
		if why != "" and not why.contains(" needs a "):
			return why  # a missing facility only stops the stage that needs it
	queue.append(item)
	changed.emit()
	return ""

func dequeue(item: String) -> void:
	queue.erase(item)
	changed.emit()

## What the active project is doing, for the panel.
func status_of(item: String) -> String:
	if item.begins_with("track:"):
		var key := item.substr(6)
		return "%s level %d: %d/%d" % [tracks_cfg[key].name, tracks[key] + 1, int(progress.get(item, {}).get("work", 0.0)), int(track_cost(key))]
	var stage := stage_of(item)
	if stage >= 3:
		return "Complete"
	var why := blocker(item)
	if why != "":
		return why
	var cost := stage_cost(item, stage)
	if not progress[item].paid and not cost.is_empty() and not world.economy.can_afford(cost):
		return "%s waits for %s" % [stage_names(item)[stage], world.hud.cost_text(cost)]
	return "%s: %d/%d" % [stage_names(item)[stage], int(progress[item].work), int(stage_points(item, stage))]

func _process(delta: float) -> void:
	if world == null or world.economy == null or world.game_over != "":
		return
	_tick += delta
	if _tick >= 1.0:
		_tick -= 1.0
		tick(1.0)
	_ai_tick += delta
	if _ai_tick >= 10.0:
		_ai_tick = 0.0
		ai_tick()

func labs() -> int:
	var n := 0
	for key in LABS:
		n += world.economy.owned(key)
	return n

func tick(dt: float) -> void:
	var eco: Node = world.economy
	# Chip fabs turn silicon into money and research once microchips exist.
	var chip_rp := 0.0
	if bonus("chips") > 0.0:
		for i in range(eco.owned("chipFab")):
			if eco.res.silicon >= 0.2:
				eco.res.silicon -= 0.2 * dt
				eco.res.money += 2.0 * dt * bonus("chips")
				chip_rp += 0.6 * bonus("chips")
	rate = (BASE_RATE + eco.provided("researchRate") + chip_rp) * (1.0 + bonus("researchPct"))
	points += rate * dt
	_work(dt)
	_check_era()
	changed.emit()

# The first project in the queue that can advance draws points: its income,
# faster from a stockpile, but a stage never completes in under
# MIN_STAGE_SECONDS. A project waiting for an era, a discovery, a facility or
# materials keeps its place and the ones behind it carry on (a waiting first
# project used to stop the whole queue, so research never reached the end).
func _work(dt: float) -> void:
	var i := 0
	while i < queue.size():
		var item: String = queue[i]
		if item.begins_with("track:"):
			var key := item.substr(6)
			if track_blocker(key) == "Maxed":
				queue.remove_at(i)
				continue
			if track_blocker(key) != "":
				i += 1
				continue
			if not progress.has(item):
				progress[item] = {"work": 0.0}
			var need := track_cost(key)
			var draw := minf(points, maxf(rate, need / MIN_STAGE_SECONDS) * dt)
			points -= draw
			progress[item].work += draw
			if progress[item].work >= need:
				tracks[key] += 1
				progress.erase(item)
				queue.remove_at(i)
				_recompute()
				world.hud.notice("%s advanced to level %d." % [tracks_cfg[key].name, tracks[key]])
			return
		var stage := stage_of(item)
		if stage >= 3:
			queue.remove_at(i)
			continue
		if blocker(item) != "":
			i += 1
			continue  # waiting for an era, a discovery or a facility
		var p: Dictionary = progress[item]
		if not p.paid:
			var cost := stage_cost(item, stage)
			if not world.economy.pay(cost):
				i += 1
				continue  # waiting for materials
			p.paid = true
		var need := stage_points(item, stage)
		var draw := minf(points, maxf(rate, need / MIN_STAGE_SECONDS) * dt)
		points -= draw
		p.work += draw
		if p.work >= need:
			p.stage = stage + 1
			p.work = 0.0
			p.paid = false
			_recompute()
			world.economy.recalculate()
			var name: String = def_of(item).name
			if p.stage >= 3:
				queue.remove_at(i)
				world.hud.notice("DISCOVERY: %s is complete. %s" % [name, desc_of(item)])
			elif p.stage == 2:
				world.hud.notice("%s: %s done, half the effect is already in service." % [name, stage_names(item)[1]])
			else:
				world.hud.notice("%s: %s done. Next: %s." % [name, stage_names(item)[0], stage_names(item)[1]])
		return

## Research handed over by agents or rewards; negative when stolen.
func add_points(amount: float) -> void:
	points = maxf(0.0, points + amount)
	changed.emit()

# ---------------------------------------------------------------- eras

## Each requirement of the next era: [label, have, need].
func era_requirements(index: int) -> Array:
	if index >= eras.size():
		return []
	var out := []
	var eco: Node = world.economy
	var req: Dictionary = eras[index].req
	for key in req:
		var need := float(req[key])
		var have := 0.0
		var label: String = key
		match key:
			"villages":
				label = "Village Centers"
				have = eco.standing("villageCenter")  # linked to the capital or not
			"cities":
				label = "City Centers"
				have = eco.standing("cityCenter")
			"buildings":
				label = "Buildings"
				have = world.buildings.filter(func(b): return b.owner == 0 and b.built and not b.dead).size()
			"civilians":
				label = "Citizens"
				have = eco.civilians
				var cut := 0
				for b in world.buildings:
					if b.owner == 0 and b.built and not b.dead and not b.get("supplied", true) and float(b.def.provides.get("civCap", 0.0)) > 0.0:
						cut += 1
				if eco.civ_cap < need:
					label = "Citizens (homes for %d: build housing%s)" % [int(eco.civ_cap), ", and link %d cut-off town%s by road" % [cut, "" if cut == 1 else "s"] if cut > 0 else ""]
			"discoveries":
				label = "Discoveries"
				have = completed_count()
			"power":
				label = "Research buildings"   # the native game has no power grid: education drives industry
				need = ceilf(need / 15.0)
				have = labs()
			"routes":
				label = "Trade routes"
				have = world.market.routes.size() if world.market else 0
			"compute":
				label = "Chip Fabs"
				need = minf(need, 2.0)
				have = eco.owned("chipFab")
			"landShare":
				label = "Share of the land"
				have = float(world.territory.yields(0).cells) / maxf(world.territory.land_cells(), 1.0) if world.territory else 0.0
		out.append([label, have, need])
	return out

func _check_era() -> void:
	if era + 1 >= eras.size():
		return
	for r in era_requirements(era + 1):
		if r[1] < r[2]:
			return
	era += 1
	var reward: Dictionary = eras[era].reward
	world.economy.res.money += float(reward.get("money", 0))
	points += float(reward.get("research", 0))
	var opened := ERA_OF.keys().filter(func(k): return ERA_OF[k] == era).size()
	world.hud.notice("NEW ERA: the %s. %s +$%d, +%d research; %d discoveries open." % [eras[era].name, eras[era].desc, int(reward.get("money", 0)), int(reward.get("research", 0)), opened])
	changed.emit()

# ---------------------------------------------------------------- rival research

## Rival nations gain a tech level every few minutes (faster on harder
## difficulties); each level adds 5% income and 3% damage and armour.
func ai_tick() -> void:
	if world.ai == null:
		return
	var aggression := float(world.diplomacy.aggression) if world.diplomacy else 0.35
	for n in world.ai.nations:
		if n.defeated:
			continue
		n.tech = float(n.get("tech", 0.0)) + 10.0 / lerpf(260.0, 150.0, aggression)
		n.tech = minf(n.tech, 10.0)

func ai_tech(owner: int) -> float:
	if owner <= 0 or world.ai == null:
		return 0.0
	for n in world.ai.nations:
		if n.id == owner:
			return floorf(float(n.get("tech", 0.0)))
	return 0.0

## Damage dealt by `unit` (a unit dictionary), from discoveries or rival tech.
func damage_mult(unit: Dictionary) -> float:
	if unit.owner > 0:
		return 1.0 + 0.03 * ai_tech(unit.owner)
	var m := 1.0 + bonus("dmgAll")
	var key: String = unit.get("key", "")
	if key in world.infantry_keys:
		m += bonus("dmgInfantry")
	if key in ["artillery", "mlrs"]:
		m += bonus("dmgArty")
	if unit.get("fly", false):
		m += bonus("dmgAir")
	if key == "drone":
		m += bonus("dmgDrone")
	if unit.get("naval", false):
		m += bonus("dmgNaval")
	return m

## Damage taken by `unit` (stealth aircraft shrug some of it off).
func armor_mult(unit: Dictionary) -> float:
	if unit.owner == 0 and unit.get("fly", false):
		return 1.0 - bonus("airArmor")
	return 1.0

## Applied to a unit as it enters service: health, range and speed.
func equip(unit: Dictionary) -> void:
	var hp := 1.0
	if unit.owner > 0:
		hp += 0.03 * ai_tech(unit.owner)
	else:
		hp += bonus("hpAll")
		if unit.key in world.infantry_keys:
			hp += bonus("hpInfantry")
		elif unit.vehicle and not unit.get("fly", false) and not unit.get("naval", false):
			hp += bonus("hpVehicle")
		if unit.key in ["artillery", "mlrs"]:
			unit.range *= 1.0 + bonus("rangeArty")
		if unit.get("naval", false):
			unit.range *= 1.0 + bonus("rangeNaval")
		if unit.get("fly", false):
			unit.speed *= 1.0 + bonus("spdAir")
		elif not unit.get("naval", false):
			unit.speed *= 1.0 + bonus("spdGround")
	unit.hp *= hp
	unit.max_hp *= hp

## A unit's price after Heavy Industry and Drone Swarms.
func unit_cost(key: String, cost: Dictionary) -> Dictionary:
	var m := 1.0
	if key in world.VEHICLES or key in world.NAVAL:
		m += bonus("costVehiclePct")
	if key == "drone":
		m += bonus("costDronePct")
	if absf(m - 1.0) < 0.001:
		return cost
	var out := {}
	for k in cost:
		out[k] = roundf(float(cost[k]) * m)
	return out

# ---------------------------------------------------------------- saving

func capture() -> Dictionary:
	return {"points": points, "progress": progress, "tracks": tracks, "queue": queue, "era": era}

func restore(data: Dictionary) -> void:
	points = float(data.get("points", 0.0))
	era = int(data.get("era", 0))
	for key in progress.keys():
		if not discoveries.has(key):
			progress.erase(key)
	for key in discoveries:
		var saved: Dictionary = data.get("progress", {}).get(key, {})
		progress[key] = {"stage": int(saved.get("stage", 0)), "work": float(saved.get("work", 0.0)), "paid": bool(saved.get("paid", false))}
	for key in data.get("progress", {}):
		if String(key).begins_with("track:"):
			progress[key] = {"work": float(data.progress[key].get("work", 0.0))}
	for key in tracks:
		tracks[key] = int(data.get("tracks", {}).get(key, 0))
	queue = Array(data.get("queue", [])).map(func(q): return String(q))
	_recompute()
	changed.emit()
