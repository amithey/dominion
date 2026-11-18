extends Node
## The player's economy, ported from updateCity() in js/entities.js.
## Every number comes from the map export (config.js): prices, build times,
## what each building provides, deposit rates and the economy constants.
## Once a second: citizens grow toward housing capacity, taxes are collected
## through the administration level, farms feed citizens and soldiers,
## extractors fill material stores up to their caps.

signal changed

const RESOURCES := ["money", "food", "oil", "iron", "silicon", "uranium", "gas"]

var civil: RefCounted
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
# The army a nation starts with is its standing garrison: it has barracks of
# its own and does not take up the housing that new recruits need.
var garrison := 0
var test_mode := false   ## F8 (testing): huge stores, set by grant_test_resources()
var military_spending := {"money": 0.0, "oil": 0.0, "shots": 0.0, "intercepts": 0.0}
var military_flow := {"money": 0.0, "oil": 0.0}
var military_rates := {"money": 0.0, "oil": 0.0}
var operating_notices := {}
const TEST_CAP := 99999.0
const TAX_POLICIES := {
	"Relief": {"factor": 0.80, "approval": 8},
	"Standard": {"factor": 1.0, "approval": 0},
	"Levy": {"factor": 1.25, "approval": -10}}
const CIVIL_PROGRAMMES := {
	"Farm grants": {"cost": 240, "effect": "Supplied farms produce 25% more food."},
	"Public clinics": {"cost": 300, "effect": "National health rises by 12 points."},
	"Home insulation": {"cost": 200, "effect": "Homes use 40% less heating gas in winter."}}
const PROGRAMME_TERM := 180
var tax_policy := "Standard"
var civil_programme := ""
var programme_left := 0

func fund_programme(programme: String) -> bool:
	if programme_left > 0 or not CIVIL_PROGRAMMES.has(programme): return false
	if not pay({"money": CIVIL_PROGRAMMES[programme].cost}): return false
	civil_programme = programme
	programme_left = PROGRAMME_TERM
	return true

func restore_civil_policy(data: Dictionary) -> void:
	tax_policy = str(data.get("tax_policy", "Standard"))
	if not TAX_POLICIES.has(tax_policy): tax_policy = "Standard"
	civil_programme = str(data.get("civil_programme", ""))
	programme_left = clampi(int(data.get("programme_left", 0)), 0, PROGRAMME_TERM) if CIVIL_PROGRAMMES.has(civil_programme) else 0
	if programme_left == 0: civil_programme = ""

func farm_output() -> float:
	var r: Node = world.research
	var output := float(cfg.farmFood) * (1.0 + float(r.bonus("foodPct") if r else 0.0))
	return output * (1.25 if civil_programme == "Farm grants" else 1.0)

var _tick := 0.0

func setup(world_node: Node, economy: Dictionary) -> void:
	world = world_node
	civil = preload("res://scripts/civil_affairs.gd").new(world)
	cfg = economy
	restore_civil_policy({})
	for key in RESOURCES:
		res[key] = float(cfg.startResources.get(key, 0))
		rates[key] = 0.0
	# The starting garrison needs an initial operational fuel reserve; the old
	# economy started with zero oil because movement was free.
	res.oil = maxf(float(res.oil), 60.0)
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

## Built and standing, supplied or not (a research facility need only exist).
func standing(key: String) -> int:
	var n := 0
	for b in world.buildings:
		if b.owner == 0 and b.built and not b.dead and b.key == key:
			n += 1
	return n

func provided(stat: String) -> float:
	var total := 0.0
	for b in world.buildings:
		if b.owner == 0 and b.built and not b.dead and b.get("supplied", true):
			total += float(b.def.provides.get(stat, 0.0))
	return total

## Income share from buildings, with the ceilings their cards state: banks
## add up to +60% together, luxury villas up to +16%.
const INCOME_CEILING := {"bank": 0.60, "luxuryVillas": 0.16}
func income_pct() -> float:
	var total := 0.0
	var capped := {}
	for b in world.buildings:
		if b.owner != 0 or not b.built or b.dead or not b.get("supplied", true):
			continue
		var pct := float(b.def.provides.get("incomePct", 0.0))
		if INCOME_CEILING.has(b.key):
			capped[b.key] = float(capped.get(b.key, 0.0)) + pct
		else:
			total += pct
	for key in capped:
		total += minf(float(capped[key]), float(INCOME_CEILING[key]))
	return total

## Storage beyond the base: warehouses, and any other building whose card
## promises storage (a railway station's goods yard).
func storage_bonus() -> float:
	var extra := owned("warehouse") * float(cfg.warehouseBonus)
	for b in world.buildings:
		if b.owner == 0 and b.built and not b.dead and b.get("supplied", true) and b.key != "warehouse":
			extra += float(b.def.provides.get("matCap", 0.0))
	return extra

## Industry that turns one resource into another (the building cards):
## an oil refinery burns 0.06 oil/s for $7/s; a nuclear reactor burns 0.04
## uranium/s for $5/s and +20% production (one reactor's worth) while fuelled.
const REFINERY_OIL := 0.06
const REFINERY_MONEY := 7.0
const REACTOR_URANIUM := 0.04
const REACTOR_MONEY := 5.0
const REACTOR_PRODUCTION := 0.20
const MOUNTAIN_IRON := 0.8
const HOSPITAL_REACH := 40.0
const HOSPITAL_HEAL := 0.02   ## share of maximum health a second
var reactor_fuelled := false

func recalculate() -> void:
	civ_cap = (float(cfg.baseCivCap) + provided("civCap")) * (1.0 + (world.research.bonus("civCapPct") if world.research else 0.0))
	var mat_cap := storage_bonus()
	for key in cfg.baseCap:
		caps[key] = float(cfg.baseCap[key]) + mat_cap
	caps.food = float(cfg.foodCapBase) + owned("foodDepot") * float(cfg.foodDepotBonus)
	if test_mode:
		for key in caps:
			caps[key] = maxf(caps[key], TEST_CAP)
	# Taxes need administration; residential districts extend it (config.js admin).
	admin = clampf(float(cfg.baseAdmin) + mini(owned("residential"), 3) * 0.05 + mini(owned("villageCenter"), 3) * 0.05 + owned("cityCenter") * 0.10, float(cfg.baseAdmin), 1.0)
	pop_cap = int(provided("pop")) + garrison
	_plant = minf(provided("prodPct"), 0.30) + (REACTOR_PRODUCTION if reactor_fuelled and owned("nuclearReactor") > 0 else 0.0)
	_depot_damage = minf(provided("dmgPct"), 0.25)
	_depot_reload = minf(owned("ammoDepot") * 0.06, 0.18)
	_command_health = minf(provided("hpPct"), 0.10)
	pop_used = 0
	for u in world.units:
		if u.owner == 0 and not u.dead:
			pop_used += int(world.unit_defs.get(u.key, {}).get("pop", 1))
			for c in u.get("cargo", []):
				pop_used += int(world.unit_defs.get(str(c.get("key", "")), {}).get("pop", 1))

## Once a second: hospitals treat your wounded infantry near them (2% of their
## health a second, not under fire: 6 s after the last hit). Vehicles are repaired.
func _heal_near_hospitals() -> void:
	var hospitals: Array = []
	for b in world.buildings:
		if b.owner == 0 and b.key == "hospital" and b.built and not b.dead and b.get("supplied", true) and not b.get("blackout", false):
			hospitals.append(b.root.position)
	if hospitals.is_empty():
		return
	for u in world.units:
		if u.dead or u.owner != 0 or u.get("fly", false) or u.get("naval", false) or u.get("vehicle", false) or float(u.hp) >= float(u.max_hp):
			continue
		if float(world.game_time) - float(u.get("last_hit", -100.0)) < 6.0:
			continue
		var p: Vector3 = u.node.position
		for h in hospitals:
			if Vector2(p.x - h.x, p.z - h.z).length() <= HOSPITAL_REACH:
				u.hp = minf(float(u.max_hp), float(u.hp) + float(u.max_hp) * HOSPITAL_HEAL)
				break

## For testing the game (F8): $100,000 more, every store raised to 99,999 and
## filled, and 200 more army capacity. Each press adds again.
func grant_test_resources() -> void:
	test_mode = true
	garrison += 200
	recalculate()
	res.money += 100000.0
	for key in caps:
		res[key] = caps[key]
	civilians = civ_cap
	changed.emit()

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
	var food_in: float = owned("farm") * farm_output() + float(land.food)
	# A bigger city eats more per head (it no longer grows its own food).
	var food_out := civilians * float(cfg.foodPerCivilian) * (1.0 + civilians / 2000.0) * float(preload("res://scripts/additional_factions.gd").profile(world, 0).get("civilian_food", 1.0)) + army * float(cfg.foodPerSoldier)
	for b in world.buildings:
		if b.dead or not b.built or b.owner != 0 or not b.key in ["fishingWharf", "fishingPlatform"] or not b.get("supplied", true): continue
		var shoals := 0
		for d in world.deposits:
			if d.type == "fish" and d.pos.distance_to(b.root.position) <= 60: shoals += 1
		food_in += (2.0 + mini(shoals, 2) * 2.0) * float(preload("res://scripts/additional_factions.gd").profile(world, 0).get("fishing", 1.0))
	rates.food = food_in - food_out
	if res.food + rates.food < 1 and civil.reserve > 0:
		civil.release_food(1 - res.food - rates.food)
	res.food = clampf(res.food + rates.food, 0.0, caps.food)
	var starving: bool = res.food <= 0.5
	# Citizens grow with happiness and health (the browser's 60 and 55 to start),
	# which civic buildings and discoveries raise.
	happiness = clampf(60.0 + float(TAX_POLICIES[tax_policy].approval) + provided("happiness") + (r.bonus("happiness") if r else 0.0) - SHORTAGE_UNREST * shortages.size() - (COLD_UNREST if cold else 0.0), 0.0, 100.0)
	health = clampf(55.0 + (12.0 if civil_programme == "Public clinics" else 0.0) + provided("health") + (r.bonus("health") if r else 0.0), 0.0, 100.0)
	var growth := civilians * ((happiness - 45.0) / 50.0) * (health / 100.0) * 0.0025
	if growth > 0.0:
		growth *= preload("res://scripts/national_profile.gd").growth(world, 0)   # a young or an ageing population
	if starving:
		growth -= civilians * 0.005
	if cold:
		growth -= civilians * 0.004   # the cold takes the old and the ill
	civilians = clampf(civilians + growth, 20.0, civ_cap)
	# Taxes reach only settlements the supply network connects (config.js
	# supplyCoverage, weighted by how many people each settlement houses).
	# Markets and ports add a share of income (config.js incomePct).
	rates.money = civilians * float(cfg.taxPerCivilian) * float(TAX_POLICIES[tax_policy].factor) * admin * supply_coverage() * (1.0 + income_pct() + (r.bonus("incomePct") if r else 0.0))
	rates.money += float(land.money)
	rates.money *= preload("res://scripts/faction_powers.gd").income_mult(world, 0)   # sanctions, sabotage, a closed strait
	# Extractors on deposits, and iron from held mountains.
	for key in ["oil", "iron", "silicon", "uranium", "gas"]:
		rates[key] = 0.0
	rates.iron = float(land.iron) * preload("res://scripts/national_profile.gd").resource_mult(world, 0, "iron")
	rates.oil = float(land.get("oil", 0.0)) * preload("res://scripts/national_profile.gd").resource_mult(world, 0, "oil")
	var mining: float = 1.0 + (r.bonus("extractPct") if r else 0.0)
	for b in world.buildings:
		if b.owner != 0 or not b.built or b.dead or b.deposit == null or not b.get("supplied", true):
			continue
		var dep: Dictionary = b.deposit.def
		rates[dep.res] = rates.get(dep.res, 0.0) + float(dep.rate) * mining * (1.0 + preload("res://scripts/additional_powers.gd").bonus(world, 0, "mining")) * preload("res://scripts/national_profile.gd").resource_mult(world, 0, dep.res)
	# Mountain mines dig iron out of the high rock (no deposit needed).
	rates.iron += owned("mountainMine") * MOUNTAIN_IRON * mining * preload("res://scripts/national_profile.gd").resource_mult(world, 0, "iron")
	# Refineries turn crude into money while there is crude to refine.
	var refineries := owned("oilRefinery")
	if refineries > 0 and float(res.get("oil", 0.0)) >= refineries * REFINERY_OIL:
		rates.oil -= refineries * REFINERY_OIL
		rates.money += refineries * REFINERY_MONEY
	# Reactors pay and speed industry while they have uranium to burn.
	var reactors := owned("nuclearReactor")
	var was_fuelled := reactor_fuelled
	reactor_fuelled = reactors > 0 and float(res.get("uranium", 0.0)) >= reactors * REACTOR_URANIUM
	if reactor_fuelled:
		rates.uranium -= reactors * REACTOR_URANIUM
		rates.money += reactors * REACTOR_MONEY
	if was_fuelled != reactor_fuelled:
		recalculate()
	_heal_near_hospitals()
	# A growing population burns fuel and uses electronics: oil from about 150
	# people up, chips (silicon) once a city passes 400. Running short makes
	# people unhappy (see happiness above, applied on the next tick).
	var oil_use := maxf(civilians - 150.0, 0.0) * OIL_PER_PERSON
	var chip_use := maxf(civilians - 400.0, 0.0) * CHIPS_PER_PERSON
	rates.oil = rates.get("oil", 0.0) - oil_use
	rates.silicon = rates.get("silicon", 0.0) - chip_use
	# AI Data Centers burn chips and money (ai_directorate.gd).
	var dc_use: Dictionary = world.directorate.upkeep() if world.get("directorate") != null and world.directorate != null else {}
	rates.silicon -= float(dc_use.get("silicon", 0.0))
	rates.money -= float(dc_use.get("money", 0.0))
	shortages.clear()
	# Four 180-second seasons; the final quarter needs household heating.
	var heating := civilians * 0.006 if fmod(world.game_time, 720.0) >= 540.0 else 0.0
	if civil_programme == "Home insulation": heating *= 0.6
	rates.gas -= heating
	var was_cold := cold
	cold = heating > 0.0 and res.gas <= 0.5
	if cold: shortages.append("winter heating")
	if cold and not was_cold:
		world.hud.notice("Winter and no gas: homes are unheated. People are suffering and falling ill, factories run slow. Open gas fields, build offshore rigs or buy gas on the World market.")
	elif was_cold and not cold and heating > 0.0:
		world.hud.notice("Gas is flowing again: the winter heating is back.")
	if oil_use > 0.0 and res.get("oil", 0.0) <= 0.5:
		shortages.append("oil")
	if chip_use > 0.0 and res.get("silicon", 0.0) <= 0.5:
		shortages.append("chips")
	for key in RESOURCES:
		if key == "food":
			continue
		res[key] = maxf(res[key] + rates.get(key, 0.0), 0.0)
		if caps.has(key):
			res[key] = minf(res[key], caps[key])
	# Charges were already deducted at launch/travel; subtract from displayed
	# rates only, so the resource bar shows net flow without charging twice.
	for key in ["money", "oil"]:
		military_rates[key] = military_flow[key]
		rates[key] -= military_flow[key]
		military_flow[key] = 0.0
	civil.tick()
	if programme_left > 0:
		programme_left -= 1
		if programme_left == 0:
			world.hud.notice("%s programme completed." % civil_programme)
			civil_programme = ""
	changed.emit()

const OIL_PER_PERSON := 0.0012     ## oil a second for each person past 150
const CHIPS_PER_PERSON := 0.0006   ## silicon a second for each person past 400
const SHORTAGE_UNREST := 6.0       ## happiness lost for each shortage (oil, chips)
var shortages: Array[String] = []
var cold := false                  ## winter with no gas: unrest, deaths and slow factories (world.update_training)
const COLD_UNREST := 10.0         ## happiness lost (on top of the shortage's) while the homes are unheated
const COLD_SLOWDOWN := 0.75       ## production speed of every factory while the homes are unheated

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

## One town's accounts (a capital, city or village centre `s`): the homes and
## other buildings that belong to it (the nearest town hall, logistics.gd),
## how many people live there (the nation's citizens shared by housing), what
## its amenities add to happiness, its food balance and the taxes it pays.
func city_report(s: Dictionary) -> Dictionary:
	var own: Array = []
	for b in world.buildings:
		if b.owner != s.owner or b.dead or not b.built:
			continue
		if is_same(b, s) or (b.def.get("settlement") == null and is_same(world.logistics.settlement_of(b), s)):
			own.append(b)
	var capacity := 0.0
	var amenities := 0.0
	var farms := 0.0
	var taxable_weight := 0.0
	var homes := 0
	for b in own:
		var p: Dictionary = b.def.provides
		capacity += float(p.get("civCap", 0.0))
		if float(p.get("civCap", 0.0)) > 0.0 and not is_same(b, s):
			homes += 1
		amenities += float(p.get("happiness", 0.0))
		if b.get("supplied", true):
			taxable_weight += float(POPULATION_WEIGHTS.get(b.key, 0.0))
		if b.key == "farm":
			farms += farm_output() if b.owner == 0 and b.get("supplied", true) else (float(cfg.farmFood) if b.owner != 0 else 0.0)
		elif b.key == "fishingWharf":
			farms += 2.0
	if s.key == "hq":
		capacity += float(cfg.baseCivCap)  # the capital's own streets
	# The nation's citizens live where the homes are.
	var total_weight := 0.0
	var all_capacity := float(cfg.baseCivCap)
	for b in world.buildings:
		if b.owner == s.owner and b.built and not b.dead:
			all_capacity += float(b.def.provides.get("civCap", 0.0))
			total_weight += float(POPULATION_WEIGHTS.get(b.key, 0.0))
	var people := 0.0
	if s.owner == 0:
		people = civilians * capacity / maxf(all_capacity, 1.0)
	var supplied: bool = s.get("supplied", true)
	var eats := people * float(cfg.foodPerCivilian) * (1.0 + civilians / 2000.0)
	var r: Node = world.research
	var taxable_people := civilians * taxable_weight / maxf(total_weight, 1.0) if s.owner == 0 else 0.0
	var tax: float = preload("res://scripts/faction_powers.gd").income_mult(world, 0) * taxable_people * float(cfg.taxPerCivilian) * float(TAX_POLICIES[tax_policy].factor) * admin * (1.0 + income_pct() + (r.bonus("incomePct") if r else 0.0))
	return {"residents": people, "capacity": capacity, "homes": homes, "buildings": own.size(), "amenities": amenities,
		"happiness": happiness, "food_in": farms, "food_out": eats, "tax": tax, "supplied": supplied}

## What military and industrial buildings add, with their ceilings (the
## building cards promise these): power plants +15% production and
## construction each, up to +30%; ammo depots +5% damage each, up to +25%, and
## 6% faster reloading each, up to 18%; a command centre +10% health for the
## units trained while it stands.
## (Counted in recalculate(), not per shot: a battle fires thousands.)
var _plant := 0.0
var _depot_damage := 0.0
var _depot_reload := 0.0
var _command_health := 0.0

func plant_bonus() -> float:
	return _plant

func depot_damage() -> float:
	return _depot_damage

func depot_reload() -> float:
	return _depot_reload

func command_health() -> float:
	return _command_health

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
