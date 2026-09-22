extends Node
## The player's economy, ported from updateCity() in js/entities.js.
## Every number comes from the map export (config.js): prices, build times,
## what each building provides, deposit rates and the economy constants.
## Once a second: citizens grow toward housing capacity, taxes are collected
## through the administration level, farms feed citizens and soldiers,
## extractors fill material stores up to their caps.

signal changed

const RESOURCES := ["money", "food", "oil", "iron", "silicon", "uranium"]

var world: Node  # world.gd: buildings, units, deposits
var cfg: Dictionary
var res := {}
var rates := {}
var caps := {}
var civilians := 120.0
var happiness := 60.0
var health := 55.0
var civ_cap := 200.0
var admin := 0.28
var pop_used := 0
var pop_cap := 0
var _tick := 0.0

func setup(world_node: Node, economy: Dictionary) -> void:
	world = world_node
	cfg = economy
	for key in RESOURCES:
		res[key] = float(cfg.startResources.get(key, 0))
		rates[key] = 0.0
	civilians = float(cfg.startCivilians)
	recalculate()

func _process(delta: float) -> void:
	if world == null:
		return
	_tick += delta
	if _tick >= 1.0:
		_tick -= 1.0
		tick()

## What the player's finished buildings add up to.
func owned(key: String) -> int:
	var n := 0
	for b in world.buildings:
		if b.owner == 0 and b.built and not b.dead and b.get("supplied", true) and b.key == key:
			n += 1
	return n

func provided(stat: String) -> float:
	var total := 0.0
	for b in world.buildings:
		if b.owner == 0 and b.built and not b.dead and b.get("supplied", true):
			total += float(b.def.provides.get(stat, 0.0))
	return total

func recalculate() -> void:
	civ_cap = (float(cfg.baseCivCap) + provided("civCap")) * (1.0 + (world.research.bonus("civCapPct") if world.research else 0.0))
	var mat_cap := owned("warehouse") * float(cfg.warehouseBonus)
	for key in cfg.baseCap:
		caps[key] = float(cfg.baseCap[key]) + mat_cap
	caps.food = float(cfg.foodCapBase) + owned("foodDepot") * float(cfg.foodDepotBonus)
	# Taxes need administration; residential districts extend it (config.js admin).
	admin = clampf(float(cfg.baseAdmin) + mini(owned("residential"), 3) * 0.05 + mini(owned("villageCenter"), 3) * 0.05 + owned("cityCenter") * 0.10, float(cfg.baseAdmin), 1.0)
	pop_cap = int(provided("pop"))
	pop_used = 0
	for u in world.units:
		if u.owner == 0 and not u.dead:
			pop_used += int(world.unit_defs.get(u.key, {}).get("pop", 1))

func tick() -> void:
	recalculate()
	var army := 0
	for u in world.units:
		if u.owner == 0 and not u.dead and u.key != "worker":
			army += 1
	# Held land yields by terrain and how firmly it is held (territory.gd).
	var land: Dictionary = world.territory.yields(0) if world.territory != null else {"money": 0.0, "food": 0.0, "iron": 0.0}
	# Food: farms and farmland against mouths to feed.
	var r: Node = world.research
	var food_in: float = owned("farm") * float(cfg.farmFood) * (1.0 + (r.bonus("foodPct") if r else 0.0)) + float(land.food)
	var food_out := civilians * float(cfg.foodPerCivilian) + army * float(cfg.foodPerSoldier)
	rates.food = food_in - food_out
	res.food = clampf(res.food + rates.food, 0.0, caps.food)
	var starving: bool = res.food <= 0.5
	# Citizens grow with happiness and health (the browser's 60 and 55 to start),
	# which civic buildings and discoveries raise.
	happiness = clampf(60.0 + provided("happiness") + (r.bonus("happiness") if r else 0.0), 0.0, 100.0)
	health = clampf(55.0 + provided("health") + (r.bonus("health") if r else 0.0), 0.0, 100.0)
	var growth := civilians * ((happiness - 45.0) / 50.0) * (health / 100.0) * 0.0025
	if starving:
		growth -= civilians * 0.005
	civilians = clampf(civilians + growth, 20.0, civ_cap)
	# Taxes reach only settlements the supply network connects (config.js
	# supplyCoverage, weighted by how many people each settlement houses).
	# Markets and ports add a share of income (config.js incomePct).
	rates.money = civilians * float(cfg.taxPerCivilian) * admin * supply_coverage() * (1.0 + provided("incomePct") + (r.bonus("incomePct") if r else 0.0))
	rates.money += float(land.money)
	# Extractors on deposits, and iron from held mountains.
	for key in ["oil", "iron", "silicon", "uranium"]:
		rates[key] = 0.0
	rates.iron = float(land.iron)
	rates.oil = float(land.get("oil", 0.0))
	var mining: float = 1.0 + (r.bonus("extractPct") if r else 0.0)
	for b in world.buildings:
		if b.owner != 0 or not b.built or b.dead or b.deposit == null or not b.get("supplied", true):
			continue
		var dep: Dictionary = b.deposit.def
		rates[dep.res] = rates.get(dep.res, 0.0) + float(dep.rate) * mining
	for key in RESOURCES:
		if key == "food":
			continue
		res[key] += rates.get(key, 0.0)
		if caps.has(key):
			res[key] = minf(res[key], caps[key])
	changed.emit()

const POPULATION_WEIGHTS := {"hq": 200.0, "villageCenter": 90.0, "cityCenter": 260.0, "residential": 150.0, "cottage": 80.0, "apartments": 280.0, "luxuryVillas": 60.0}
func supply_coverage() -> float:
	var connected := 0.0
	var total := 0.0
	for b in world.buildings:
		if b.owner != 0 or b.dead or not b.built or not POPULATION_WEIGHTS.has(b.key):
			continue
		total += POPULATION_WEIGHTS[b.key]
		if b.get("supplied", true):
			connected += POPULATION_WEIGHTS[b.key]
	return connected / total if total > 0.0 else 0.0

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if res.get(key, 0.0) < float(cost[key]):
			return false
	return true

func missing(cost: Dictionary) -> String:
	for key in cost:
		if res.get(key, 0.0) < float(cost[key]):
			return key
	return ""

func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for key in cost:
		res[key] -= float(cost[key])
	changed.emit()
	return true

func refund(cost: Dictionary) -> void:
	for key in cost:
		res[key] += float(cost[key])
	changed.emit()
