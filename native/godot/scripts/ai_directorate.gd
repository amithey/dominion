extends RefCounted
## Artificial intelligence as a national resource (the AI tab of the Defence
## window). Research and sources: native/AI-RESEARCH-2026-10-06.md.
##
## Compute comes from the nation's industry (ai_data.gd "compute", once Machine
## Learning is researched) and from AI Data Centers (1 a second each, a quarter
## more with a Power Plant or a Nuclear Reactor, a quarter as much without
## chips; each burns silicon and money). The player splits it four ways:
##   Military AI       powers the military effects below
##   Economy           research and income
##   Intelligence      fills the operations reserve that AI cyber campaigns
##                     spend, and the cyber defence against rivals' campaigns
##   Training runs     raise the AI level (0..5), as far as research allows:
##                     Machine Learning 2, Military AI 3, Frontier Models 4
## A pool gives its full effect at 0.4 compute a second per AI level (0.3 for
## intelligence); less compute, less effect.
##
## The autonomy doctrine (Human in / on / out of the loop):
##   in    a human approves every strike: no autonomy bonus, no incidents
##   on    machines act and a human may stop them: drones a third harder to
##         jam and stronger with each AI level; rare incidents
##   out   no human once a weapon is launched: drones almost unjammable,
##         every unit a little deadlier, and autonomous loitering munitions
##         choose the most valuable target in reach; but incidents are
##         frequent: your own units struck, or civilians, which costs war
##         support and brings the Security Council in
## At AI level 3 with the doctrine on or out, loitering munitions and
## interceptor drones pick their own targets (air defences first, then
## artillery, then armour). The Targeting Fusion Cell passes every target to
## every gun: artillery deadlier and accurate, missiles and guided rockets
## less likely to stray.
## AI cyber campaigns hit several rivals at once and need no agent, only
## compute; rivals with AI run campaigns against the player too.
## Rivals follow the same rules: their level follows their technology and
## compute, their doctrine their national lean (ai_data.gd).
##
## The economy: AI raises research, income and production, and automates jobs:
## without a retraining programme the people it puts out of work are unhappy.
## Chips: the chip-supply nations (ai_data.CONTROLLERS) can put export controls
## on a rival, halving its data centres (smuggling wins some of it back, at a
## risk); when AI data centres buy up the world's chips, a chip shortage
## follows (world_events.gd "chips").
## Intelligence: AI reads satellite images and open sources: intelligence grows
## faster, recon passes reveal more for longer, and attacks are foreseen.
## Influence: synthetic media (deepfakes) against a rival's home front.
## Model theft: an operation to steal a stronger rival's model weights.
## Collaborative Combat Aircraft (research): every fighter takes off with a
## loyal wingman (future_weapons.gd battle groups).
## Air-defence battle management: batteries share targets (no two missiles at
## one drone) and intercept a little more often.
## Treaties: the Treaty on Autonomous Weapons (signatories keep a human in or
## on the loop) and the declaration on human control of nuclear weapons.

const AIData := preload("res://scripts/ai_data.gd")
const Factions := preload("res://scripts/factions.gd")

const BUILDINGS := ["aiDataCenter", "fusionCell"]
const LEVEL_NAMES := ["None", "Narrow AI", "Machine learning at scale", "Military AI", "Frontier models", "General intelligence"]
const LEVEL_COST := [0.0, 150.0, 400.0, 900.0, 1800.0, 4000.0]
## The research that lets the level rise (the highest first).
const CAPS := [["frontierModels", 4], ["militaryAI", 3], ["machineLearning", 2]]
const POOLS := ["military", "economy", "intel", "frontier"]
const POOL_NAMES := {"military": "Military AI", "economy": "Economy", "intel": "Intelligence and cyber", "frontier": "Training runs"}
const NEED := {"military": 0.4, "economy": 0.4, "intel": 0.3}
const RIVAL_ALLOC := {"military": 35.0, "economy": 25.0, "intel": 15.0, "frontier": 25.0}
const DOCTRINES := ["in", "on", "out"]
const DOCTRINE_NAMES := {"in": "Human in the loop", "on": "Human on the loop", "out": "Human out of the loop"}
const DOCTRINE_DESC := {
	"in": "A human approves every strike. No autonomy bonus and no incidents.",
	"on": "Machines act; a human watches and may stop them. Drones a third harder to jam and stronger with each AI level. Rare incidents.",
	"out": "No human once a weapon is launched. Drones almost impossible to jam, every unit a little deadlier. Frequent incidents: your own units struck, or civilians.",
}
## Incidents a minute at war at full military compute, before the models' quality.
const INCIDENT_RATE := {"in": 0.0, "on": 0.03, "out": 0.14}
const DC_OUTPUT := 1.0
const DC_UPKEEP := {"silicon": 0.12, "money": 1.5}
const NATIONAL := 0.1
const OPS_CAP := 600.0
const SEEKERS := ["loiterer", "harop", "shahed", "interceptorDrone"]
const DRONE_KEYS := ["drone", "loiterer", "fpvTeam", "harop", "shahed", "interceptorDrone", "seaDrone", "akinci", "wingman"]
const ARTY_KEYS := ["artillery", "mlrs", "himars", "k9", "heavyRocket", "tos1a"]
const AIR_DEFENCE := ["samSite", "samLauncher", "aaVehicle", "abmLauncher", "irisT", "laserAD", "saudiThaad", "manpads", "aegisCruiser", "type45"]
const CIVILIAN := ["cottage", "housing", "residential", "apartments", "workerHouse", "school", "hospital", "library", "market", "university"]
const PRODUCTION := ["barracks", "tankFactory", "airfield", "shipyard", "chipFab", "techPark", "missileSilo", "helipad"]
const CYBER_COST := 120.0
const CYBER_PREP := 20.0
const CYBER_COOLDOWN := 120.0
const CYBER_HOLD := 40.0   # a rival's intrusion shuts a building down this long
const INFLUENCE_COST := 150.0
const INFLUENCE_COOLDOWN := 180.0
const THEFT_COST := {"money": 1200.0}
const THEFT_COMPUTE := 100.0
const THEFT_COOLDOWN := 300.0
const CONTROL_SECONDS := 600.0
const SMUGGLE_COST := 600.0
const CCA_FIGHTERS := ["jet", "stealthFighter", "raptor", "jf17"]
const TREATIES := {
	"laws": {"name": "Treaty on Autonomous Weapons", "desc": "Signatories keep a human in or on the loop: no weapon chooses and strikes on its own."},
	"nuclear": {"name": "Declaration on Human Control of Nuclear Weapons", "desc": "Signatories keep machines out of the decision to use nuclear weapons."},
}

const DISCOVERIES := {
	"machineLearning": {"name": "Machine Learning", "cost": 500, "branch": "hightech", "era": 3, "reqDiscovery": "microchips", "reqBuilding": "techPark", "fx": {},
		"desc": "Models trained on your nation's data. Your industry starts producing compute, the AI level can reach 2, and you can build AI Data Centers. Opens the Human-on-the-loop doctrine and AI cyber campaigns (with Cyber Warfare)."},
	"militaryAI": {"name": "Military AI", "cost": 800, "branch": "hightech", "era": 4, "reqDiscovery": "machineLearning", "reqBuilding": "aiDataCenter", "fx": {},
		"desc": "The AI level can reach 3. Unlocks the Targeting Fusion Cell; loitering munitions and interceptor drones pick their own targets; opens the Human-out-of-the-loop doctrine. Requires an AI Data Center."},
	"frontierModels": {"name": "Frontier Models", "cost": 1300, "branch": "hightech", "era": 5, "reqDiscovery": "militaryAI", "reqBuilding": "aiDataCenter", "fx": {},
		"desc": "The largest models: the AI level can reach 4, and every AI effect grows with it. Requires an AI Data Center."},
	"collaborativeCombatAircraft": {"name": "Collaborative Combat Aircraft", "cost": 750, "branch": "air", "era": 4, "reqDiscovery": "militaryAI", "reqBuilding": "airfield", "fx": {},
		"desc": "Every fighter you train takes off with a loyal wingman: an uncrewed combat drone that flies its wing, strikes what it strikes and draws fire. A lost wingman costs no lives and is replaced while the fighter rearms."},
}

var w: Node
var st := {}            # owner -> {level, train, reserve, doctrine, rate}
var alloc := {"military": 30.0, "economy": 30.0, "intel": 20.0, "frontier": 20.0}   # the player's split
var campaign := {}      # the player's AI cyber campaign under way: {targets, ends}
var cyber_ready := 0.0  # when the player may launch the next
var cyber_target := -1  # the rival chosen in the AI tab
var ui_tab := "compute" # the AI tab's page
var retraining := false # the player's retraining programme
var controls := {}      # nation -> {by, until}: chip export controls on it
var smuggling := {}     # nation -> true: it smuggles chips past the controls
var signed := {"laws": {}, "nuclear": {}}   # treaty -> {owner: true}
var influence_ready := 0.0
var theft_ready := 0.0
var _rival_ops := {}    # rival -> {"influence": t, "theft": t, "controls": t}
var _reputation_t := 0.0
var incidents := {}     # owner -> autonomous incidents so far
var log: Array = []     # the player's recent AI events, newest first: {t, text}
var _rival_cyber := {}  # rival -> when it may run its next campaign
var _incident_at := {}  # owner -> time of its next incident roll
var _mil := {}          # owner -> military power 0..1 (cached each second)
var _fusion := {}       # owner -> has a working Targeting Fusion Cell
var _auto := {}         # owner -> autonomy rating
var _econ_shown := -1.0
var _t := 0.0
var _doctrine_t := 0.0

func _init(world: Node) -> void:
	w = world
	for owner in range(w.map.nations.size()):
		st[owner] = {"level": 0, "train": 0.0, "reserve": 0.0, "doctrine": "in", "rate": 0.0}
		_auto[owner] = AIData.rating(w, owner, "autonomy")
		for t in AIData.profile(w, owner).get("signs", []):
			if signed.has(t):
				signed[t][owner] = true   # the player's nation too: it may withdraw

static func apply(world: Node) -> void:
	var defs: Dictionary = world.map.get("buildingDefs", {})
	defs.aiDataCenter = {"name": "AI Data Center", "cat": "economy", "size": 7, "hp": 900, "cost": {"money": 1800, "iron": 60, "silicon": 120},
		"buildTime": 40, "trains": [], "provides": {}, "onDeposit": false, "depositTypes": null, "unique": false, "unbuildable": false,
		"buildRadius": 0, "settlement": null, "coastal": false, "reqDiscovery": "machineLearning",
		"desc": "Produces 1 compute a second for your AI (a quarter more with a Power Plant or a Nuclear Reactor). Burns 0.12 silicon and $1.5 a second; without silicon it runs at a quarter. Split the compute in the Defence window, AI tab. A target for enemy missiles. Requires Machine Learning."}
	defs.fusionCell = {"name": "Targeting Fusion Cell", "cat": "military", "size": 6, "hp": 800, "cost": {"money": 1600, "iron": 40, "silicon": 80},
		"buildTime": 35, "trains": [], "provides": {}, "onDeposit": false, "depositTypes": null, "unique": true, "unbuildable": false,
		"buildRadius": 0, "settlement": null, "coastal": false, "reqDiscovery": "militaryAI",
		"desc": "Every target any of your units sees goes at once to every gun: artillery and rocket artillery hit harder and closer, missiles and guided rockets stray less. Its strength follows the compute you give Military AI. With the doctrine out of the loop it sometimes marks a civilian building. Requires Military AI. One per nation."}
	var discoveries: Dictionary = world.map.research.discoveries
	for key in DISCOVERIES:
		discoveries[key] = DISCOVERIES[key].duplicate(true)

# ---------------------------------------------------------------- queries

func _row(owner: int) -> Dictionary:
	if not st.has(owner):
		st[owner] = {"level": 0, "train": 0.0, "reserve": 0.0, "doctrine": "in", "rate": 0.0}
		_auto[owner] = AIData.rating(w, owner, "autonomy")
	return st[owner]

func level(owner: int) -> int:
	return int(_row(owner).level)

func doctrine(owner: int) -> String:
	return str(_row(owner).doctrine)

func reserve(owner: int) -> float:
	return float(_row(owner).reserve)

## The highest AI level `owner`'s research allows.
func cap(owner: int) -> int:
	if owner == 0:
		if w.research == null:
			return 0
		for c in CAPS:
			if w.research.done(c[0]):
				return int(c[1])
		return 0
	var tech: float = w.research.ai_tech(owner) if w.research != null else 0.0
	return 4 if tech >= 7.0 else (3 if tech >= 5.0 else (2 if tech >= 3.0 else 0))

## Whether `owner` has the research behind a level (or, for a rival, the technology).
func researched(owner: int, key: String) -> bool:
	if owner == 0:
		return w.research != null and w.research.done(key)
	var need := {"machineLearning": 3.0, "militaryAI": 5.0, "frontierModels": 7.0, "cyberWarfare": 3.0}
	return w.research != null and w.research.ai_tech(owner) >= float(need.get(key, 99.0))

func data_centres(owner: int) -> int:
	var n := 0
	for b in w.buildings:
		if int(b.owner) == owner and b.key == "aiDataCenter" and b.built and not b.dead and b.get("supplied", true):
			n += 1
	return n

func _has(owner: int, key: String) -> bool:
	return w.buildings.any(func(b): return int(b.owner) == owner and b.key == key and b.built and not b.dead)

## Compute a second: the nation's industry and its data centres.
func compute_rate(owner: int) -> float:
	var rate := 0.0
	if researched(owner, "machineLearning"):
		rate += AIData.rating(w, owner, "compute") * NATIONAL
	var dc := data_centres(owner)
	if dc > 0:
		var each := DC_OUTPUT
		if _has(owner, "powerPlant") or _has(owner, "nuclearReactor"):
			each *= 1.25
		if owner == 0 and w.economy != null and float(w.economy.res.get("silicon", 0.0)) <= 0.5:
			each *= 0.25   # no chips to replace the burnt-out ones
		each *= chip_factor(owner)
		rate += each * dc
	return rate

func share(owner: int, pool: String) -> float:
	var a: Dictionary = alloc if owner == 0 else RIVAL_ALLOC
	var total := 0.0
	for p in POOLS: total += float(a.get(p, 0.0))
	return 0.25 if total <= 0.0 else float(a.get(pool, 0.0)) / total

func flow(owner: int, pool: String) -> float:
	return float(_row(owner).rate) * share(owner, pool)

## How fully a pool is supplied, 0..1 (no AI, no effect).
func power(owner: int, pool: String) -> float:
	var lvl := level(owner)
	if lvl <= 0 or not NEED.has(pool):
		return 0.0
	return clampf(flow(owner, pool) / (float(NEED[pool]) * lvl), 0.0, 1.0)

func military(owner: int) -> float:
	return float(_mil.get(owner, 0.0))

func fusion(owner: int) -> bool:
	return bool(_fusion.get(owner, false))

## Training cost of the next level, after the models' quality.
func next_cost(owner: int) -> float:
	var lvl := level(owner)
	if lvl >= 5:
		return 0.0
	return LEVEL_COST[lvl + 1] * (1.3 - 0.08 * AIData.rating(w, owner, "models"))

# ---------------------------------------------------------------- effects (hot paths: cached values only)

func _base(key: String) -> String:
	return preload("res://scripts/additional_factions.gd").base(key)

## The damage factor of `source`'s shot.
func damage_mult(source: Dictionary) -> float:
	if not source.has("owner") or not source.has("key"):
		return 1.0
	var o := int(source.owner)
	var m := military(o)
	if m <= 0.0:
		return 1.0
	var key := _base(str(source.key))
	var doc := doctrine(o)
	var f := 1.0
	if doc != "in" and (key in DRONE_KEYS or str(source.key) in DRONE_KEYS):
		f += 0.04 * level(o) * m * (0.6 + 0.1 * float(_auto.get(o, 1)))
	if key in ARTY_KEYS and fusion(o):
		f += 0.15 * m
	if doc == "out":
		f += 0.06 * m
	return f

## A factor on the chance jamming brings `owner`'s drones down.
func jam_factor(owner: int) -> float:
	var m := military(owner)
	match doctrine(owner):
		"on": return 1.0 - 0.3 * m
		"out": return 1.0 - 0.85 * m
	return 1.0

## Better aim for `owner`'s guns (less scatter) from the fusion cell.
func aim(owner: int) -> float:
	return 0.12 * military(owner) if fusion(owner) else 0.0

## Guided weapons stray less with the fusion cell.
func guidance(owner: int) -> float:
	return 1.0 + 0.08 * military(owner) if fusion(owner) else 1.0

## Whether `unit` picks its own target (world.nearest_enemy).
func seeks(unit: Dictionary) -> bool:
	var o := int(unit.owner)
	return level(o) >= 3 and doctrine(o) != "in" and (str(unit.key) in SEEKERS or _base(str(unit.key)) in SEEKERS)

## How much an autonomous seeker wants `e` (distance is divided by it).
func value_of(e: Dictionary) -> float:
	var k := str(e.get("key", ""))
	if k in AIR_DEFENCE:
		return 4.0
	if _base(k) in ARTY_KEYS:
		return 3.0
	if k == "shahed":
		return 2.0
	if e.get("is_building", false):
		return 1.8 if str(e.get("def", {}).get("cat", "")) == "military" else 1.0
	if e.get("vehicle", false):
		return 1.5
	return 1.0

## The player's research and income from the Economy pool (research._recompute).
func bonuses() -> Dictionary:
	var out := {}
	var lvl := level(0)
	var e := power(0, "economy")
	if e > 0.0:
		out = {"researchPct": 0.04 * lvl * e, "incomePct": 0.02 * lvl * e, "prodPct": 0.03 * lvl * e}
		if not retraining:
			out.happiness = -unrest()
	var m := power(0, "military")
	if lvl >= 2 and m > 0.0:
		out.interceptPct = 0.03 * lvl * m   # air-defence battle management
	return out

## The share of jobs AI has automated (the Economy pool).
func automation(owner := 0) -> float:
	return minf(0.25, 0.05 * level(owner) * power(owner, "economy"))

## Happiness lost to automation without a retraining programme.
func unrest() -> float:
	return minf(10.0, automation() * 40.0)

func retraining_cost() -> float:
	return 1.0 + 1.5 * level(0)

func set_retraining(on: bool) -> String:
	retraining = on
	if w.research != null:
		w.research._recompute()
	return "AI: retraining programme %s." % ("started: the people automation puts out of work learn new trades ($%.1f a second)" % retraining_cost() if on else "ended")

## A rival's income from its AI economy.
func ai_income_mult(owner: int) -> float:
	return 1.0 + 0.03 * level(owner) * power(owner, "economy")

## Interception odds a rival's batteries gain from AI battle management.
func intercept_bonus(owner: int) -> float:
	return 0.03 * level(owner) * military(owner) if level(owner) >= 2 else 0.0

## Whether `owner`'s batteries share targets (air_defence.gd).
func coordinated(owner: int) -> bool:
	return level(owner) >= 2 and military(owner) > 0.2

## Intelligence gained grows with AI analysis (espionage.add_report).
func intel_mult(owner := 0) -> float:
	return 1.0 + 0.1 * level(owner) * power(owner, "intel")

## Reveal time and radius of a recon pass (space.gd).
func recon_mult(owner: int) -> float:
	return 1.0 + 0.08 * level(owner) * power(owner, "intel")

## AI reading of open sources and imagery foresees attacks (espionage.warn_attack).
func warns() -> bool:
	return level(0) >= 2 and power(0, "intel") >= 0.5

## The silicon and money the player's data centres burn a second (economy.tick).
func upkeep() -> Dictionary:
	var n := data_centres(0)
	var out := {"silicon": DC_UPKEEP.silicon * n, "money": DC_UPKEEP.money * n} if n > 0 else {}
	if retraining and power(0, "economy") > 0.0:
		out.money = float(out.get("money", 0.0)) + retraining_cost()
	return out

# ---------------------------------------------------------------- the player's orders

func set_alloc(pool: String, step: float) -> String:
	if not alloc.has(pool):
		return ""
	alloc[pool] = clampf(float(alloc[pool]) + step, 0.0, 100.0)
	_refresh(0)
	if w.research != null:
		w.research._recompute()
	return ""

func doctrine_blocked(doc: String) -> String:
	if doc == "on" and not researched(0, "machineLearning"):
		return "Research Machine Learning first."
	if doc == "out" and not researched(0, "militaryAI"):
		return "Research Military AI first."
	if doc == "out" and signatory(0, "laws"):
		return "You signed the Treaty on Autonomous Weapons: withdraw from it first."
	return ""

func set_doctrine(doc: String) -> String:
	if not doc in DOCTRINES:
		return ""
	var why := doctrine_blocked(doc)
	if why != "":
		return why
	if doctrine(0) == doc:
		return ""
	_row(0).doctrine = doc
	var text := "AUTONOMY: your forces now fight with the %s." % DOCTRINE_NAMES[doc].to_lower()
	if doc == "out":
		text += " Expect incidents."
	_note(text)
	return text

## Why the player cannot launch an AI cyber campaign at `target` now, or "".
func cyber_blocked(target: int) -> String:
	if not researched(0, "machineLearning") or not researched(0, "cyberWarfare"):
		return "Research Machine Learning and Cyber Warfare first."
	if level(0) < 1:
		return "Your AI needs a first training run (level 1)."
	if not campaign.is_empty():
		return "A campaign is under way."
	if cyber_ready > w.game_time:
		return "The operators reset: %ds." % ceili(cyber_ready - w.game_time)
	var d: Node = w.diplomacy
	if target <= 0 or target >= d.n or d.defeated(target):
		return "Choose a rival."
	if reserve(0) < CYBER_COST:
		return "Needs %d compute in the operations reserve (you have %d)." % [int(CYBER_COST), int(reserve(0))]
	return ""

## How many nations a campaign reaches at once.
func cyber_reach(owner: int) -> int:
	return 1 + level(owner) / 2

func launch_cyber(target: int) -> String:
	var why := cyber_blocked(target)
	if why != "":
		return why
	var d: Node = w.diplomacy
	var targets := [target]
	var others: Array = range(1, d.n).filter(func(i): return i != target and not d.defeated(i) and (d.at_war(0, i) or d.rel(0, i) < -25.0))
	others.sort_custom(func(a, b): return d.rel(0, a) < d.rel(0, b))
	for i in others:
		if targets.size() >= cyber_reach(0) or reserve(0) < CYBER_COST * (targets.size() + 1):
			break
		targets.append(i)
	_row(0).reserve = reserve(0) - CYBER_COST * targets.size()
	campaign = {"targets": targets, "ends": w.game_time + CYBER_PREP}
	var names := PackedStringArray()
	for t in targets: names.append(d.name_of(t))
	return "AI CYBER: agents launched against %s. Results in %ds." % [", ".join(names), int(CYBER_PREP)]

## A nation's defence against AI cyber campaigns.
func cyber_defence(owner: int) -> float:
	var p := 0.03 * AIData.rating(w, owner, "cyber") + 0.06 * level(owner)
	if owner == 0:
		p += 0.1 * level(0) * power(0, "intel")
	return p

func _resolve_campaign() -> void:
	var d: Node = w.diplomacy
	var e = w.get("espionage")
	var lvl := level(0)
	var hit := PackedStringArray()
	var held := PackedStringArray()
	var exposed := PackedStringArray()
	var down := 60.0 + 10.0 * lvl
	for t in campaign.get("targets", []):
		var target := int(t)
		if d.defeated(target):
			continue
		var p := clampf(0.4 + 0.08 * lvl + 0.03 * AIData.rating(w, 0, "cyber") + 0.1 * power(0, "intel") - cyber_defence(target), 0.1, 0.9)
		if randf() < p:
			hit.append(d.name_of(target))
			if e != null and e.debuffs.has(target):
				e._set_debuff(target, "cyber", down)
				e.intel[target] = minf(100.0, float(e.intel.get(target, 0.0)) + 5.0)
		else:
			held.append(d.name_of(target))
		if randf() < clampf(0.3 - 0.03 * lvl, 0.05, 0.3):
			exposed.append(d.name_of(target))
			d.change(0, target, -15.0)
	campaign = {}
	cyber_ready = w.game_time + CYBER_COOLDOWN
	var text := "AI CYBER: "
	text += ("the agents broke into %s: factories and construction down for %ds." % [", ".join(hit), int(down)]) if not hit.is_empty() else "the agents found no way in."
	if not held.is_empty(): text += " %s held out." % ", ".join(held)
	if not exposed.is_empty(): text += " Traced back to you by %s (-15 relations)." % ", ".join(exposed)
	_note(text)
	w.hud.notice(text)

# ---------------------------------------------------------------- the clock

func update(delta: float) -> void:
	_t += delta
	_doctrine_t += delta
	if _t < 1.0:
		return
	_t -= 1.0
	var d: Node = w.diplomacy
	for owner in st.keys():
		if owner > 0 and d.defeated(owner):
			continue
		_second(owner)
	if _doctrine_t >= 10.0:
		_doctrine_t = 0.0
		_rival_doctrines()
	if not campaign.is_empty() and w.game_time >= float(campaign.ends):
		_resolve_campaign()
	_rival_campaigns()
	_rival_operations()
	_lapse_controls()
	_reputation_t += 1.0
	if _reputation_t >= 300.0:
		_reputation_t = 0.0
		_reputation()
	var econ := snappedf(power(0, "economy") * level(0), 0.05)
	if econ != _econ_shown:
		_econ_shown = econ
		if w.research != null:
			w.research._recompute()

func _refresh(owner: int) -> void:
	var row := _row(owner)
	row.rate = compute_rate(owner)
	_mil[owner] = power(owner, "military")
	_fusion[owner] = _has(owner, "fusionCell")

func _second(owner: int) -> void:
	_refresh(owner)
	var row := _row(owner)
	row.reserve = minf(OPS_CAP, float(row.reserve) + flow(owner, "intel"))
	var lvl := int(row.level)
	if lvl < cap(owner):
		row.train = float(row.train) + flow(owner, "frontier")
		if float(row.train) >= next_cost(owner):
			row.train = 0.0
			row.level = lvl + 1
			_level_up(owner, lvl + 1)
	elif lvl > cap(owner) and owner == 0:
		pass   # research is never lost
	_incidents(owner)

func _level_up(owner: int, lvl: int) -> void:
	_refresh(owner)
	if owner == 0:
		var what := {1: "the first useful models", 2: "models trained at national scale", 3: "military AI: autonomous seekers can choose their targets", 4: "frontier models: every AI effect is stronger"}
		var text := "AI: your models reach level %d, %s." % [lvl, what.get(lvl, LEVEL_NAMES[lvl].to_lower())]
		_note(text)
		w.hud.notice(text)
		if w.research != null:
			w.research._recompute()
	elif lvl >= 3:
		w.hud.notice("INTELLIGENCE: %s's AI reaches level %d (%s)." % [w.diplomacy.name_of(owner), lvl, LEVEL_NAMES[lvl].to_lower()])

func _note(text: String) -> void:
	log.push_front({"t": w.game_time, "text": text})
	if log.size() > 8:
		log.resize(8)

# ---------------------------------------------------------------- incidents

## Incidents a minute for `owner` now.
func incident_rate(owner: int) -> float:
	return float(INCIDENT_RATE.get(doctrine(owner), 0.0)) * military(owner) * (1.2 - 0.08 * AIData.rating(w, owner, "models"))

func _incidents(owner: int) -> void:
	var rate := incident_rate(owner)
	if rate <= 0.0:
		return
	var next := float(_incident_at.get(owner, w.game_time + 60.0))
	if not _incident_at.has(owner):
		_incident_at[owner] = next
		return
	if w.game_time < next:
		return
	_incident_at[owner] = w.game_time + 60.0
	var d: Node = w.diplomacy
	var foes: Array = d.enemies_of(owner).filter(func(f): return f != owner and not d.defeated(f))
	if foes.is_empty() or randf() >= rate:
		return
	if randf() < 0.5:
		fratricide(owner)
	else:
		civilian_strike(owner, foes[randi() % foes.size()])

## An autonomous weapon strikes one of `owner`'s own units.
func fratricide(owner: int) -> bool:
	var own: Array = w.units.filter(func(u): return int(u.owner) == owner and not u.dead and u.key != "worker" and not u.get("fly", false))
	if own.is_empty():
		return false
	var fighting: Array = own.filter(func(u): return u.get("enemy") != null)
	var victim: Dictionary = (fighting if not fighting.is_empty() else own)[randi() % (fighting if not fighting.is_empty() else own).size()]
	var amount := float(victim.get("max_hp", victim.hp)) * 0.4
	w.damage(victim, amount, {"owner": owner, "dead": true, "key": "incident"})
	incidents[owner] = int(incidents.get(owner, 0)) + 1
	if owner == 0:
		var text := "AUTONOMY: one of your autonomous weapons misidentified your own %s and struck it." % str(w.unit_defs.get(victim.key, {}).get("name", victim.key))
		_note(text)
		w.hud.notice(text)
	return true

## An autonomous strike hits a civilian building of `victim`'s.
func civilian_strike(owner: int, victim: int) -> bool:
	var homes: Array = w.buildings.filter(func(b): return int(b.owner) == victim and not b.dead and b.built and b.key in CIVILIAN)
	if homes.is_empty():
		return false
	var b: Dictionary = homes[randi() % homes.size()]
	var what: String = str(b.def.name).to_lower()
	w.damage(b, float(b.max_hp) * 0.35, {"owner": owner, "dead": true, "key": "incident"})
	incidents[owner] = int(incidents.get(owner, 0)) + 1
	var d: Node = w.diplomacy
	var cause := "an autonomous strike on a %s in %s" % [what, "your country" if victim == 0 else d.name_of(victim)]
	if w.get("un") != null and w.un != null:
		w.un.table("civilians", owner, -1, victim, ("an autonomous strike on a %s" % what))
	if owner == 0:
		if w.get("support") != null and w.support != null:
			w.support.change(0, -6.0)
		d.change(0, victim, -10.0)
		for other in range(1, d.n):
			if other != victim and not d.defeated(other):
				d.change(0, other, -2.0)
		var text := "AUTONOMY: your targeting marked a %s in %s as a military site and struck it. Civilians died: war support -6, and the Security Council will take it up." % [what, d.name_of(victim)]
		_note(text)
		w.hud.notice(text)
	elif victim == 0:
		w.hud.notice("%s's autonomous weapons struck your %s: %s." % [d.name_of(owner), what, cause])
	return true

# ---------------------------------------------------------------- rivals

func _rival_doctrines() -> void:
	if w.ai == null:
		return
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		var owner := int(n.id)
		if n.defeated:
			continue
		var lvl := level(owner)
		var lean := str(AIData.profile(w, owner).get("lean", "in"))
		var doc := "in"
		if lvl >= 1:
			var at_war: bool = not d.enemies_of(owner).filter(func(f): return f != owner).is_empty()
			doc = lean if at_war else ("on" if lean != "in" else "in")
			if doc == "out" and lvl < 3:
				doc = "on"
			# A nation fighting for its survival takes the human out of the loop.
			if at_war and doc == "on" and lvl >= 3 and w.get("defcon") != null and w.defcon != null and w.defcon.existential(owner):
				doc = "out"
		if doc == "out" and signatory(owner, "laws"):
			# A signatory breaks the treaty only when its survival is at stake.
			if w.get("defcon") != null and w.defcon != null and w.defcon.existential(owner):
				_breach(owner, "laws")
			else:
				doc = "on"
		_row(owner).doctrine = doc

func _rival_campaigns() -> void:
	if w.ai == null:
		return
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		var owner := int(n.id)
		if n.defeated or level(owner) < 2 or not researched(owner, "cyberWarfare"):
			continue
		if not (d.at_war(owner, 0) or d.rel(owner, 0) < -40.0):
			continue
		if not _rival_cyber.has(owner):
			_rival_cyber[owner] = w.game_time + 120.0 + randf() * 120.0
			continue
		if w.game_time < float(_rival_cyber[owner]):
			continue
		_rival_cyber[owner] = w.game_time + 180.0 + randf() * 120.0
		rival_intrusion(owner)

## A rival's AI campaign against the player: stopped, or a production building shut down.
func rival_intrusion(owner: int, force := "") -> String:
	var d: Node = w.diplomacy
	var name: String = d.name_of(owner)
	var stop := clampf(0.2 + cyber_defence(0) - 0.04 * AIData.rating(w, owner, "cyber") - 0.03 * level(owner), 0.05, 0.85)
	var text := ""
	if force == "stopped" or (force == "" and randf() < stop):
		text = "AI CYBER DEFENCE: your systems stopped an AI-driven intrusion from %s." % name
	else:
		var sites: Array = w.buildings.filter(func(b): return int(b.owner) == 0 and not b.dead and b.built and b.key in PRODUCTION)
		if sites.is_empty():
			return ""
		var b: Dictionary = sites[randi() % sites.size()]
		b.disabled_until = maxf(float(b.get("disabled_until", 0.0)), w.game_time + CYBER_HOLD)
		if w.research != null:
			w.research.add_points(-30.0)
		text = "AI CYBER: an AI-driven intrusion from %s shut down your %s for %ds and wiped research data (-30)." % [name, str(b.def.name), int(CYBER_HOLD)]
	_note(text)
	w.hud.notice(text)
	return text

# ---------------------------------------------------------------- saving

func capture() -> Dictionary:
	var rows := {}
	for k in st: rows[str(k)] = st[k].duplicate()
	var inc := {}
	for k in incidents: inc[str(k)] = incidents[k]
	var rc := {}
	for k in _rival_cyber: rc[str(k)] = _rival_cyber[k]
	var ctl := {}
	for k in controls: ctl[str(k)] = controls[k].duplicate()
	var smg := {}
	for k in smuggling: smg[str(k)] = true
	var sig := {}
	for t in signed:
		sig[t] = signed[t].keys().map(func(o): return int(o))
	var ops := {}
	for k in _rival_ops: ops[str(k)] = _rival_ops[k].duplicate()
	return {"st": rows, "alloc": alloc.duplicate(), "campaign": campaign.duplicate(true), "cyber_ready": cyber_ready, "incidents": inc, "log": log.duplicate(true), "rival_cyber": rc,
		"retraining": retraining, "controls": ctl, "smuggling": smg, "signed": sig, "influence_ready": influence_ready, "theft_ready": theft_ready, "rival_ops": ops}

func restore(data: Dictionary) -> void:
	for k in data.get("st", {}):
		var row: Dictionary = data.st[k]
		st[int(k)] = {"level": int(row.get("level", 0)), "train": float(row.get("train", 0.0)), "reserve": float(row.get("reserve", 0.0)), "doctrine": str(row.get("doctrine", "in")), "rate": float(row.get("rate", 0.0))}
	for p in data.get("alloc", {}):
		if alloc.has(p): alloc[p] = float(data.alloc[p])
	campaign = data.get("campaign", {})
	if campaign.has("targets"):
		campaign.targets = campaign.targets.map(func(t): return int(t))
	cyber_ready = float(data.get("cyber_ready", 0.0))
	incidents.clear()
	for k in data.get("incidents", {}): incidents[int(k)] = int(data.incidents[k])
	log = data.get("log", [])
	_rival_cyber.clear()
	for k in data.get("rival_cyber", {}): _rival_cyber[int(k)] = float(data.rival_cyber[k])
	retraining = bool(data.get("retraining", false))
	controls.clear()
	for k in data.get("controls", {}):
		controls[int(k)] = {"by": int(data.controls[k].get("by", -1)), "until": float(data.controls[k].get("until", 0.0))}
	smuggling.clear()
	for k in data.get("smuggling", {}): smuggling[int(k)] = true
	if data.has("signed"):
		for t in signed:
			signed[t] = {}
			for o in data.signed.get(t, []): signed[t][int(o)] = true
	influence_ready = float(data.get("influence_ready", 0.0))
	theft_ready = float(data.get("theft_ready", 0.0))
	_rival_ops.clear()
	for k in data.get("rival_ops", {}): _rival_ops[int(k)] = data.rival_ops[k]
	for owner in st.keys():
		_refresh(owner)
	# Fighters keep their loyal wingmen (the flag is not saved with the unit).
	for u in w.units:
		if not u.dead and str(u.key) in CCA_FIGHTERS and has_cca(int(u.owner)):
			u.cca = true
	if w.research != null:
		w.research._recompute()

# ---------------------------------------------------------------- chips

func can_control(owner: int) -> bool:
	return Factions.identity(w, owner) in AIData.CONTROLLERS or bool(w.map.nations[owner].get("chip_controller", false)) if owner >= 0 and owner < w.map.nations.size() else false

## Compute a data centre loses to export controls (smuggling wins some back)
## and to a chip shortage.
func chip_factor(owner: int) -> float:
	var f := 1.0
	if controlled(owner):
		f *= 0.8 if smuggling.has(owner) else 0.5
	if w.get("events") != null and w.events != null and w.events.active.has("chips"):
		f *= 0.8
	return f

func controlled(owner: int) -> bool:
	return controls.has(owner) and float(controls[owner].until) > w.game_time

func control_blocked(target: int) -> String:
	if not can_control(0):
		return "Only the chip-supply nations can deny chips."
	var d: Node = w.diplomacy
	if target <= 0 or target >= d.n or d.defeated(target):
		return "Choose a rival."
	if controlled(target):
		return "%s is already under export controls." % d.name_of(target)
	if can_control(target):
		return "%s makes its own chip tools." % d.name_of(target)
	return ""

## `by` denies advanced chips to `target` for ten minutes.
func impose_controls(by: int, target: int) -> String:
	if by == 0:
		var why := control_blocked(target)
		if why != "":
			return why
	var d: Node = w.diplomacy
	controls[target] = {"by": by, "until": w.game_time + CONTROL_SECONDS}
	smuggling.erase(target)
	d.change(by, target, -15.0)
	var text := "CHIPS: %s put%s export controls on %s: its data centres run at half for 10 minutes unless it smuggles chips in." % ["You" if by == 0 else d.name_of(by), "" if by == 0 else "s", "you" if target == 0 else d.name_of(target)]
	_note(text)
	w.hud.notice(text)
	return text

func smuggle_blocked() -> String:
	if not controlled(0):
		return "No export controls on you."
	if smuggling.has(0):
		return "Chips are already being smuggled in."
	if w.economy.res.money < SMUGGLE_COST:
		return "Costs $%d." % int(SMUGGLE_COST)
	return ""

## Chips smuggled past the controls through third countries.
func smuggle() -> String:
	var why := smuggle_blocked()
	if why != "":
		return why
	w.economy.pay({"money": SMUGGLE_COST})
	smuggling[0] = true
	var text := "CHIPS: smugglers bring chips in through third countries: your data centres run at 80%."
	var by: int = int(controls[0].by)
	if randf() < 0.25:
		w.diplomacy.change(0, by, -10.0)
		controls[0].until = float(controls[0].until) + 300.0
		text += " %s found out: the controls are extended by 5 minutes (-10 relations)." % w.diplomacy.name_of(by)
	_note(text)
	return text

func _lapse_controls() -> void:
	for t in controls.keys():
		if float(controls[t].until) <= w.game_time:
			controls.erase(t)
			smuggling.erase(t)
			if t == 0:
				_note("CHIPS: the export controls on you have lapsed.")
				w.hud.notice("CHIPS: the export controls on you have lapsed.")

## How many AI data centres the world runs (the chip shortage's cause).
func world_data_centres() -> int:
	var n := 0
	for b in w.buildings:
		if b.key == "aiDataCenter" and b.built and not b.dead:
			n += 1
	return n

# ---------------------------------------------------------------- influence and theft

func influence_blocked(target: int) -> String:
	if level(0) < 2:
		return "Needs AI level 2."
	if influence_ready > w.game_time:
		return "Ready in %ds." % ceili(influence_ready - w.game_time)
	var d: Node = w.diplomacy
	if target <= 0 or target >= d.n or d.defeated(target):
		return "Choose a rival."
	if reserve(0) < INFLUENCE_COST:
		return "Needs %d compute in the operations reserve." % int(INFLUENCE_COST)
	return ""

## Synthetic media aimed at `target`'s home front, by `by`.
func influence(by: int, target: int, force := "") -> String:
	if by == 0:
		var why := influence_blocked(target)
		if why != "":
			return why
		_row(0).reserve = reserve(0) - INFLUENCE_COST
		influence_ready = w.game_time + INFLUENCE_COOLDOWN
	var d: Node = w.diplomacy
	var e = w.get("espionage")
	var p := clampf(0.5 + 0.06 * level(by) - 0.04 * AIData.rating(w, target, "cyber") - (0.1 * level(0) * power(0, "intel") if target == 0 else 0.0), 0.1, 0.9)
	var who: String = "you" if target == 0 else d.name_of(target)
	var text := ""
	if force == "works" or (force == "" and randf() < p):
		if w.get("support") != null and w.support != null:
			w.support.change(target, -8.0 if target > 0 else -5.0)
		if target > 0 and e != null and e.stability.has(target):
			e.stability[target] = maxf(20.0, float(e.stability[target]) - 10.0)
		text = "INFLUENCE: synthetic videos and voices flood %s: %s." % ["your country" if target == 0 else d.name_of(target), "war support falls" if target == 0 else "its people turn against the war and its government (war support -8, stability -10)"]
		if by > 0:
			text = "INFLUENCE: %s floods your country with synthetic videos and voices: war support -5." % d.name_of(by)
	else:
		text = "INFLUENCE: %s saw through the fakes." % ("your people" if target == 0 else who)
	if by == 0 and randf() < clampf(0.35 - 0.03 * level(0), 0.1, 0.35):
		d.change(0, target, -20.0)
		for other in range(1, d.n):
			if other != target and not d.defeated(other):
				d.change(0, other, -4.0)
		if w.get("support") != null and w.support != null:
			w.support.change(0, -4.0)
		text += " The campaign was traced to you: a scandal at home and abroad."
	_note(text)
	w.hud.notice(text)
	return text

func theft_blocked(target: int) -> String:
	var d: Node = w.diplomacy
	if target <= 0 or target >= d.n or d.defeated(target):
		return "Choose a rival."
	var e = w.get("espionage")
	if e == null or not e.has_agency():
		return "Build an Intelligence Agency first."
	if level(target) <= level(0):
		return "%s's models are no better than yours." % d.name_of(target)
	if theft_ready > w.game_time:
		return "Ready in %ds." % ceili(theft_ready - w.game_time)
	if reserve(0) < THEFT_COMPUTE or not w.economy.can_afford(THEFT_COST):
		return "Costs $%d and %d compute." % [int(THEFT_COST.money), int(THEFT_COMPUTE)]
	return ""

## An operation by `by` to steal `target`'s model weights.
func steal(by: int, target: int, force := "") -> String:
	var d: Node = w.diplomacy
	if by == 0:
		var why := theft_blocked(target)
		if why != "":
			return why
		w.economy.pay(THEFT_COST)
		_row(0).reserve = reserve(0) - THEFT_COMPUTE
		theft_ready = w.game_time + THEFT_COOLDOWN
	var e = w.get("espionage")
	var network: float = float(e.network.get(target, 0.0)) if e != null and by == 0 else 30.0
	var p := clampf(0.3 + 0.05 * AIData.rating(w, by, "cyber") + network * 0.004 - cyber_defence(target), 0.05, 0.85)
	var text := ""
	if force == "works" or (force == "" and randf() < p):
		var mine := level(by)
		var theirs := level(target)
		var gained := mini(theirs, mine + ceili((theirs - mine) / 2.0))
		_row(by).level = gained
		_row(by).train = 0.0
		_refresh(by)
		text = "MODEL THEFT: %s stole %s's model weights: %s AI is now level %d." % ["your agents" if by == 0 else d.name_of(by), "your" if target == 0 else d.name_of(target), "your" if by == 0 else "its", gained]
		if by == 0 and w.research != null:
			w.research._recompute()
	else:
		text = "MODEL THEFT: %s against %s failed." % ["your operation" if by == 0 else d.name_of(by) + "'s operation", "you" if target == 0 else d.name_of(target)]
		if randf() < 0.4:
			d.change(by, target, -30.0)
			text += " It was exposed (-30 relations)."
			if can_control(target) and not controlled(by):
				impose_controls(target, by)
	_note(text)
	w.hud.notice(text)
	return text

## Rivals' influence campaigns, model thefts and export controls against the player.
func _rival_operations() -> void:
	if w.ai == null:
		return
	var d: Node = w.diplomacy
	for n in w.ai.nations:
		var owner := int(n.id)
		if n.defeated:
			continue
		var ops: Dictionary = _rival_ops.get(owner, {})
		_rival_ops[owner] = ops
		# A rival under controls smuggles once it has looked for a way round.
		if controlled(owner) and not smuggling.has(owner) and w.game_time - (float(controls[owner].until) - CONTROL_SECONDS) > 60.0:
			smuggling[owner] = true
		var hostile: bool = d.at_war(owner, 0) or d.rel(owner, 0) < -40.0
		if not hostile:
			continue
		var now: float = w.game_time
		# Each operation waits a while after the hostility begins, then recurs.
		for op in ["influence", "theft", "controls"]:
			if not ops.has(op):
				ops[op] = now + {"influence": 240.0, "theft": 300.0, "controls": 180.0}[op] + randf() * 120.0
		if level(owner) >= 2 and now >= float(ops.influence):
			influence(owner, 0)
			ops.influence = now + 300.0 + randf() * 180.0
		if level(0) >= level(owner) + 2 and now >= float(ops.theft):
			steal(owner, 0)
			ops.theft = now + 420.0 + randf() * 180.0
		if can_control(owner) and level(0) >= 2 and not controlled(0) and now >= float(ops.controls):
			impose_controls(owner, 0)
			ops.controls = now + 900.0

# ---------------------------------------------------------------- treaties

func signatory(owner: int, treaty: String) -> bool:
	return signed.get(treaty, {}).has(owner)

func signatories(treaty: String) -> Array:
	var d: Node = w.diplomacy
	return signed.get(treaty, {}).keys().filter(func(o): return o == 0 or not d.defeated(o))

func sign_blocked(treaty: String) -> String:
	if signatory(0, treaty):
		return "Signed."
	if treaty == "laws" and doctrine(0) == "out":
		return "Bring a human back into the loop first."
	return ""

func sign(treaty: String) -> String:
	var why := sign_blocked(treaty)
	if why != "":
		return why
	signed[treaty][0] = true
	var d: Node = w.diplomacy
	for o in signatories(treaty):
		if o != 0:
			d.change(0, o, 3.0)
	var text := "TREATY: you signed the %s. The other signatories think better of you (+3)." % TREATIES[treaty].name
	_note(text)
	return text

func withdraw(treaty: String) -> String:
	if not signatory(0, treaty):
		return ""
	signed[treaty].erase(0)
	var d: Node = w.diplomacy
	for o in signatories(treaty):
		d.change(0, o, -5.0)
	var text := "TREATY: you withdrew from the %s. Its signatories take it badly (-5)." % TREATIES[treaty].name
	_note(text)
	return text

## A signatory breaks a treaty: the Security Council takes it up.
func _breach(owner: int, treaty: String) -> void:
	signed[treaty].erase(owner)
	var d: Node = w.diplomacy
	for o in signatories(treaty):
		d.change(owner, o, -10.0)
	if w.get("un") != null and w.un != null:
		w.un.table("treaty", owner, -1, -1, "breaking the %s" % TREATIES[treaty].name)
	w.hud.notice("TREATY: %s has broken the %s and taken the human out of the loop." % [d.name_of(owner), TREATIES[treaty].name])

## Fighting without a human in the loop costs standing with the treaty's signatories.
func _reputation() -> void:
	var d: Node = w.diplomacy
	for owner in st.keys():
		if doctrine(owner) != "out" or (owner > 0 and d.defeated(owner)):
			continue
		for o in signatories("laws"):
			if o != owner:
				d.change(owner, o, -2.0)

# ---------------------------------------------------------------- collaborative combat aircraft

func has_cca(owner: int) -> bool:
	if owner == 0:
		return w.research != null and w.research.done("collaborativeCombatAircraft")
	return level(owner) >= 3 and w.research != null and w.research.ai_tech(owner) >= 6.0 and AIData.rating(w, owner, "autonomy") >= 3

## A fighter just trained takes a loyal wingman with it (world.gd, ai.gd).
func escort_fighter(unit: Dictionary) -> void:
	if str(unit.key) in CCA_FIGHTERS and has_cca(int(unit.owner)):
		unit.cca = true
		preload("res://scripts/future_weapons.gd").escort(w, unit)

# ---------------------------------------------------------------- the buildings' models

## A long, low server hall with chillers on the roof, or the fusion cell's
## operations block with its mast and dishes.
static func model(w: Node, key: String) -> Node3D:
	var root := Node3D.new()
	var cladding = w.cached_material("ai-cladding", func(): return w.matte(Color("b9bdc0"), 0.55, 0.3))
	var dark = w.cached_material("ai-dark", func(): return w.matte(Color("2f3438"), 0.5, 0.5))
	var steel = w.cached_material("bunker-steel", func(): return w.matte(Color("3b3f40"), 0.5, 0.6))
	var glow = w.cached_material("ai-glow", func():
		var m: StandardMaterial3D = w.matte(Color("5ab0e0"), 0.3)
		m.emission_enabled = true
		m.emission = Color("3d8fc4")
		m.emission_energy_multiplier = 0.8
		return m)
	var parts: Array = []
	if key == "aiDataCenter":
		parts = [
			[Vector3(11.0, 3.4, 7.0), Vector3(0, 1.7, -0.5), cladding],
			[Vector3(11.2, 0.25, 7.2), Vector3(0, 3.5, -0.5), dark],
			[Vector3(10.6, 0.35, 0.08), Vector3(0, 2.4, 3.02), glow],
			[Vector3(2.4, 1.2, 0.2), Vector3(-3.8, 0.6, 3.06), dark],
		]
		for i in range(4):
			parts.append([Vector3(1.8, 0.9, 1.8), Vector3(-3.9 + i * 2.6, 4.1, -1.2), steel])   # chillers
		for i in range(3):
			parts.append([Vector3(1.2, 1.6, 1.2), Vector3(-4.0 + i * 1.6, 0.8, -5.2), steel])   # generators
	else:
		parts = [
			[Vector3(7.0, 3.2, 5.0), Vector3(0, 1.6, 0), cladding],
			[Vector3(7.2, 0.3, 5.2), Vector3(0, 3.35, 0), dark],
			[Vector3(6.6, 0.3, 0.08), Vector3(0, 2.3, 2.52), glow],
			[Vector3(0.3, 7.5, 0.3), Vector3(2.6, 6.6, -1.6), steel],
			[Vector3(1.8, 0.1, 0.1), Vector3(2.6, 9.5, -1.6), steel],
			[Vector3(1.6, 1.6, 0.15), Vector3(-1.8, 4.4, -1.0), cladding],   # dishes
			[Vector3(1.2, 1.2, 0.15), Vector3(0.2, 4.2, -1.3), cladding],
		]
	for p in parts:
		var mesh := BoxMesh.new()
		mesh.size = p[0]
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.position = p[1]
		part.material_override = p[2]
		root.add_child(part)
	return root
