extends Node
## Campaign intelligence: timed assignments, dated estimates, succession,
## partner upkeep and attribution. See native/ESPIONAGE-DESIGN.md for sources
## and deliberately compressed game-balance values. No real-world tradecraft.

signal changed

const TICK := 10.0
const INTEL_TIERS := [[10, "Treasury and buildings"], [25, "Army strength"], [40, "Wars, allies and pacts"], [60, "Warning of attacks on you"]]
const INTEL_GAIN := {"buildNetwork": 6, "reconDossier": 18, "cyberAttack": 8, "stealFunds": 5, "stealTech": 10, "sabotage": 6, "shipping": 6, "proxyCell": 8, "armRebels": 8, "falseFlag": 6, "assassinate": 12}

var world: Node
var cfg: Dictionary
var agents: Array = []        # {id, name, skill, xp, ops, status, captured_by}
var network := {}             # nation -> 0..100
var heat := {}
var intel := {}
var types := {}               # nation -> {op: true}
var reports: Array = []       # newest first: {t, nation, text}
var dossiers := {}            # nation -> last recon report
var debuffs := {}             # nation -> {kind: until}
var clock := 0.0
var boost_until := 0.0        # stolen research: faster training until then
var _next_id := 1
var _tick := 0.0
var missions: Array = []
var cooldowns := {}
var succession := {}
var proxies := {}
var stability := {}
var security_until := 0.0
var scandal_until := 0.0
var enemy_next := 240.0
var _catalog := {}

# Seconds of compressed campaign time, not real-world operational guidance.
# preparation, cooldown, minimum network, minimum intel, exposure risk
const PROGRAMS := {
	"buildNetwork": [45, 30, 0, 0, 0.04],
	"reconDossier": [35, 30, 8, 0, 0.03],
	"openSources": [25, 25, 0, 0, 0.0],
	"counterSweep": [50, 120, 0, 0, 0.0],
	"withdrawNetwork": [30, 60, 0, 0, 0.0],
	"influence": [100, 180, 20, 20, 0.20],
	"cyberAttack": [90, 180, 25, 25, 0.25],
	"stealFunds": [60, 120, 10, 10, 0.18],
	"stealTech": [90, 180, 20, 20, 0.20],
	"sabotage": [100, 180, 25, 25, 0.30],
	"shipping": [80, 180, 15, 15, 0.25],
	"proxyCell": [120, 240, 30, 30, 0.25],
	"armRebels": [150, 300, 40, 40, 0.40],
	"falseFlag": [150, 300, 45, 45, 0.45],
	"assassinate": [180, 600, 55, 55, 0.60],
}

func setup(world_node: Node, espionage: Dictionary) -> void:
	world = world_node
	cfg = espionage
	for i in range(1, world.map.nations.size()):
		network[i] = 0.0
		heat[i] = 0.0
		intel[i] = 0.0
		types[i] = {}
		debuffs[i] = {}
		cooldowns[i] = {}
		succession[i] = {}
		stability[i] = 75.0

func ops() -> Dictionary:
	if _catalog.is_empty():
		_catalog = cfg.ops.duplicate(true)
		_catalog.merge({
			"openSources": {"name":"Open-source assessment", "cost":90, "base":0.95, "desc":"Compile public economic and military indicators into a dated, low-confidence estimate."},
			"counterSweep": {"name":"Counter-intelligence review", "cost":240, "base":0.90, "desc":"Audit domestic security; raise interception for 3 minutes. An assigned agent cannot work abroad."},
			"withdrawNetwork": {"name":"Stand down network", "cost":100, "base":0.95, "desc":"Reduce foreign exposure by 35, sacrificing 10 network strength. Not an instant reset."},
			"influence": {"name":"Influence campaign", "cost":400, "base":0.60, "desc":"Reduce institutional stability temporarily. Can provoke a rally around the government and a diplomatic scandal."},
			"shipping": {"name":"Sabotage shipping lanes", "cost":350, "base":0.55, "desc":"Mine a harbour approach or wreck a freighter: the nation loses a cargo at sea (its money and the goods), and the shortage lifts that commodity's price on the world market."},
		})
		for key in _catalog:
			_catalog[key].minNetwork = PROGRAMS[key][2]
		_catalog.assassinate.cost = 1400
		_catalog.assassinate.desc = "Rare leadership strike: long preparation, fresh dossier and strong access. Succession limits disruption; exposure risks war and international condemnation."
		_catalog.proxyCell.desc = "Create a local partner for up to 5 minutes. Costs $3/s upkeep, reduces rival income up to 20%; autonomy can cause blowback."
		_catalog.armRebels.desc = "Requires an existing proxy. Temporary unrest reduces income; increases the partner's autonomy and exposure."
		_catalog.falseFlag.desc = "A diplomatic provocation damages relations between rivals. It cannot automatically make them declare war."
	return _catalog

func has_agency() -> bool:
	return world.economy.owned("intelAgency") > 0

func ready_agents() -> Array:
	return agents.filter(func(a): return a.status == "ready")

func rank(agent: Dictionary) -> String:
	return cfg.ranks[clampi(int(agent.skill) - 1, 0, cfg.ranks.size() - 1)]

func recruit_cost() -> int:
	return int(cfg.recruitBase) + agents.size() * int(cfg.recruitStep)

func person(nation: int, role: String) -> String:
	var generation := int(succession.get(nation, {}).get(role, 0))
	if generation > 0:
		return "Successor %d (%s)" % [generation, role.capitalize()]
	return world.map.nations[nation].get("people", {}).get(role, role.capitalize())

func active(nation: int, kind: String) -> bool:
	return debuffs.get(nation, {}).get(kind, 0.0) > clock

func _set_debuff(nation: int, kind: String, seconds: float) -> void:
	debuffs[nation][kind] = maxf(debuffs[nation].get(kind, 0.0), clock + seconds)

## Multiplier on an AI nation's income (proxy cells, rebels, a dead leader).
func income_mult(nation: int) -> float:
	var m := 1.0
	if proxies.has(nation):
		m *= 1.0 - 0.20 * float(proxies[nation].strength) / 100.0
	if active(nation, "unrest"):
		m *= 0.75
	if active(nation, "president"):
		m *= 0.65
	m *= 0.85 if active(nation, "influence") else 1.0
	m *= 1.0 - maxf(0.0, 75.0 - float(stability.get(nation, 75.0))) * 0.002
	return maxf(m, 0.4)

## Multiplier on the damage a nation's forces deal (a dead general: -30%).
func damage_mult(nation: int) -> float:
	return 0.7 if nation > 0 and active(nation, "general") else 1.0

## Whether an AI nation can launch attacks (not while leaderless).
func paralyzed(nation: int) -> bool:
	return active(nation, "paralyzed")

## Whether its factories run (a cyber attack stops them).
func production_down(nation: int) -> bool:
	return active(nation, "cyber")

# ---------------------------------------------------------------- agents

func recruit() -> String:
	if not has_agency():
		return "Build an Intelligence Agency first."
	var cost := recruit_cost()
	if not world.economy.pay({"money": cost}):
		return "Recruiting the next agent costs $%d." % cost
	var used := agents.map(func(a): return a.name)
	var free: Array = cfg.agentNames.filter(func(n): return not n in used)
	var name: String = free[randi() % free.size()] if not free.is_empty() else "%s-%d" % [cfg.agentNames[randi() % cfg.agentNames.size()], _next_id]
	agents.append({"id": _next_id, "name": name, "skill": 1, "xp": 0, "ops": 0, "status": "ready", "captured_by": -1})
	_next_id += 1
	changed.emit()
	return "Agent \"%s\" joins the service. Ready agents: %d." % [name, ready_agents().size()]

func ransom(agent_id: int) -> String:
	for a in agents:
		if a.id == agent_id and a.status == "captured":
			var price := int(float(cfg.ransom) * (1.0 + (world.research.bonus("ransomPct") if world.research else 0.0)))
			if not world.economy.pay({"money": price}):
				return "Buying back \"%s\" costs $%d." % [a.name, price]
			var captor = world.market.ai_nation(int(a.captured_by))
			if captor != null:
				captor.money += price
			a.status = "recovering"
			a.ready_at = clock + 45.0
			a.captured_by = -1
			changed.emit()
			return "Agent \"%s\" ransomed home, experience intact." % a.name
	return ""

func _gain_xp(agent: Dictionary) -> void:
	agent.xp += 1
	agent.ops += 1
	var skill: int = 1 + cfg.xpLevels.filter(func(t): return agent.xp >= int(t)).size()
	if skill > int(agent.skill):
		agent.skill = skill
		world.hud.notice("Agent \"%s\" promoted to %s (+%d%% success)." % [agent.name, rank(agent), roundi((skill - 1) * float(cfg.skillBonus) * 100.0)])

func add_report(nation: int, kind: String, text: String, amount: float) -> void:
	intel[nation] = clampf(intel.get(nation, 0.0) + amount, 0.0, 100.0)
	if amount > 0.0:
		types[nation][kind] = true
	reports.push_front({"t": clock, "nation": nation, "text": text})
	if reports.size() > 25:
		reports.pop_back()

# ---------------------------------------------------------------- operations

func counter_spy(nation: int) -> float:
	if active(nation, "spymaster"):
		return 0.02
	return float(world.map.ai.difficulty.get(world.match_difficulty, world.map.ai.difficulty.easy).get("counterSpy", 0.0))

func success_chance(op_key: String, nation: int) -> float:
	var op: Dictionary = ops()[op_key]
	var p := float(op.base)
	if has_agency():
		p += 0.10
	p += network.get(nation, 0.0) * 0.006
	p -= heat.get(nation, 0.0) * 0.004
	p += minf(types[nation].size() * 0.02, 0.10)
	p -= counter_spy(nation)
	if world.research:
		p += world.research.bonus("spyPct")  # Covert Ops levels, Cyber Warfare
	p -= 0.15 if active(nation, "alert") else 0.0
	return clampf(p, 0.05, 0.95)

## Resolve only a completed assignment. Submission and resolution are separate.
func _resolve(mission: Dictionary) -> String:
	var op_key: String = mission.op
	var nation: int = int(mission.nation)
	var role: String = mission.role
	var roll: float = float(mission.roll)
	var agent: Dictionary = _agent(int(mission.agent))
	var op: Dictionary = ops()[op_key]
	var d: Node = world.diplomacy
	var p := clampf(success_chance(op_key, nation) + (int(agent.skill) - 1) * float(cfg.skillBonus), 0.05, 0.97)
	var r := randf() if roll < 0.0 else roll
	var nat_name: String = d.name_of(nation)
	var message := ""
	if r < p:
		if op_key not in ["openSources", "counterSweep", "withdrawNetwork"]:
			network[nation] = clampf(network[nation] + (16.0 if op_key == "buildNetwork" else 3.0), 0.0, 100.0)
			heat[nation] = clampf(heat[nation] + (2.0 if op_key == "reconDossier" else 8.0), 0.0, 100.0)
		message = _succeed(op_key, nation, role)
		_gain_xp(agent)
		add_report(nation, op_key, "%s in %s — success (Agent \"%s\")" % [op.name, nat_name, agent.name], INTEL_GAIN.get(op_key, 12 if op_key == "openSources" else (0 if op_key in ["counterSweep", "withdrawNetwork"] else 5)))
	else:
		if PROGRAMS[op_key][4] > 0.0:
			heat[nation] = clampf(heat[nation] + 14.0, 0.0, 100.0)
			network[nation] = clampf(network[nation] - 5.0, 0.0, 100.0)
		if PROGRAMS[op_key][4] > 0.0 and randf() < clampf(0.55 - (int(agent.skill) - 1) * 0.07, 0.15, 0.6):
			agent.status = "captured"
			agent.captured_by = nation
			d.change(0, nation, -25.0)
			message = "Operation failed: Agent \"%s\" was CAPTURED by %s. Ransom: $%d in the Intel panel." % [agent.name, nat_name, int(cfg.ransom)]
			if op_key == "assassinate" and randf() < 0.35:
				world.ai.declare_war(nation, false)
		elif PROGRAMS[op_key][4] == 0.0:
			message = "Assessment inconclusive; agent returns for review. No foreign exposure."
		else:
			message = "Operation failed, but Agent \"%s\" escaped cleanly." % agent.name
	# Attribution is independent of success: successful interference can be exposed.
	if randf() < exposure_chance(op_key, nation):
		message += _expose(nation, op_key)
	if r >= p:
		add_report(nation, op_key, message, 0.0)
	else:
		reports[0].text += " — " + message
	changed.emit()
	d.changed.emit()
	return message

func _succeed(op_key: String, nation: int, role: String) -> String:
	var d: Node = world.diplomacy
	var nat = world.market.ai_nation(nation)
	var nat_name: String = d.name_of(nation)
	match op_key:
		"buildNetwork":
			return "Network expanded inside %s: infiltration %d/100." % [nat_name, int(network[nation])]
		"reconDossier", "openSources":
			return _collect(nation, op_key == "openSources")
		"counterSweep":
			security_until = clock + 180.0
			return "Domestic security review complete: interception +25 percentage points for 3 minutes."
		"withdrawNetwork":
			heat[nation] = maxf(0.0, heat[nation] - 35.0)
			network[nation] = maxf(0.0, network[nation] - 10.0)
			return "Network stood down: exposure -35, access -10."
		"influence":
			if randf() < 0.25:
				stability[nation] = minf(100.0, stability[nation] + 10.0)
				heat[nation] = minf(100.0, heat[nation] + 15.0)
				return "Influence backfired: the population rallied around its government. Stability +10."
			stability[nation] = maxf(20.0, stability[nation] - 20.0)
			_set_debuff(nation, "influence", 150.0)
			return "Institutional confidence weakened: income -15% for 150s; stability -20."
		"cyberAttack":
			_set_debuff(nation, "cyber", 90.0)
			return "Cyber attack: %s's factories and construction are down for 90 seconds." % nat_name
		"stealFunds":
			var amount := 0.0
			if nat:
				amount = minf(nat.money, 400.0 + randi() % 400)
				nat.money -= amount
			world.economy.res.money += amount
			return "Your agent siphoned $%d from %s." % [int(amount), nat_name]
		"stealTech":
			world.research.add_points(120.0)
			if nat:
				nat.tech = maxf(0.0, float(nat.get("tech", 0.0)) - 0.5)
			return "Research stolen from %s: +120 research points." % nat_name
		"shipping":
			var goods: Array = world.market.resources()
			var res: String = goods[randi() % goods.size()]
			var worth := 0.0
			if nat:
				worth = minf(nat.money, world.market.price(res) * 60.0)
				nat.money -= worth
			var stock: Dictionary = world.market.ai_stock.get(str(nation), {})
			stock[res] = maxf(0.0, float(stock.get(res, 100.0)) - 60.0)
			world.market.ai_stock[str(nation)] = stock
			world.market.pressure(res, 60, true)  # the lost cargo is bought again elsewhere
			return "Sabotage at sea: a %s freighter never reached port. A cargo of %s worth $%d is lost." % [nat_name, res, int(worth)]
		"sabotage":
			var t = _random_building(nation)
			if t == null:
				return "Sabotage succeeded but found no valuable target."
			covert_damage(t, t.max_hp * 0.7)
			return "Sabotage: %s's %s is burning." % [nat_name, t.def.name]
		"proxyCell":
			proxies[nation] = {"strength":70.0, "autonomy":15.0, "until":clock + 300.0}
			return "Local partner established: $3/s upkeep, up to -20% rival income, 5 minute mandate. Autonomous interests can cause blowback."
		"armRebels":
			if not proxies.has(nation):
				return "Partner dissolved during preparation. Support could not be delivered."
			_set_debuff(nation, "unrest", 120.0)
			proxies[nation].autonomy = minf(100.0, proxies[nation].autonomy + 25.0)
			stability[nation] = maxf(20.0, stability[nation] - 15.0)
			return "Partner pressure escalated: income -25% for 2 minutes; stability -15; partner autonomy +25."
		"falseFlag":
			var rivals := range(1, d.n).filter(func(i): return i != nation and not d.defeated(i))
			if rivals.is_empty():
				return "No rival to frame."
			var rival: int = rivals[randi() % rivals.size()]
			d.change(nation, rival, -45.0)
			return "False flag planted: %s and %s blame each other." % [nat_name, d.name_of(rival)]
		"assassinate":
			var who := person(nation, role)
			succession[nation][role] = int(succession[nation].get(role, 0)) + 1
			_set_debuff(nation, "alert", 360.0)
			var text := ""
			match role:
				"president":
					_set_debuff(nation, "president", 240.0)
					_set_debuff(nation, "paralyzed", 90.0)
					text = "%s of %s assassinated! Income -35%% for 4 minutes, army paralysed for 90 s, a successor takes office." % [who, nat_name]
				"general":
					_set_debuff(nation, "general", 240.0)
					_set_debuff(nation, "paralyzed", 60.0)
					for u in world.units:
						if u.owner == nation and not u.dead and u.attack_move:
							u.target = null
							u.attack_move = false
					text = "%s of %s eliminated! Their army deals 30%% less damage for 4 minutes; its offensive collapses." % [who, nat_name]
				"scientist":
					if nat:
						nat.tech = maxf(0.0, float(nat.get("tech", 0.0)) - 2.0)
					text = "%s of %s eliminated! Their research programme loses two levels; succession begins." % [who, nat_name]
				_:
					_set_debuff(nation, "spymaster", 300.0)
					network[nation] = clampf(network[nation] + 20.0, 0.0, 100.0)
					text = "%s of %s eliminated! Their counter-intelligence is down for 5 minutes." % [who, nat_name]
			return text
	return ""

func _random_building(nation: int):
	var targets: Array = world.buildings.filter(func(b): return b.owner == nation and not b.dead and b.built and b.key != "hq")
	return targets[randi() % targets.size()] if not targets.is_empty() else null

## Damage from agents: nobody fires a shot, so it does not start a war.
func covert_damage(b: Dictionary, amount: float) -> void:
	world.effects.explosion(b.root.position + Vector3.UP * 3.0, 2.2, true)
	world.effects.burn(b.root.position, 12.0)
	b.hp -= amount
	if b.hp <= 0.0:
		world.destroy_building(b)

# ---------------------------------------------------------------- hostile services

func _process(delta: float) -> void:
	if world == null or world.economy == null or world.game_over != "":
		return
	advance(delta)
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		tick()

func tick() -> void:
	for i in heat:
		heat[i] = maxf(0.0, heat[i] - 1.5)
		intel[i] = maxf(0.0, intel[i] - 0.35)
	if clock >= enemy_next and randf() < 0.028:
		enemy_attempt()
	changed.emit()

func enemy_attempt(force_outcome := "") -> String:
	if force_outcome == "" and clock < enemy_next:
		return ""
	enemy_next = clock + 150.0
	var d: Node = world.diplomacy
	var hostiles := range(1, d.n).filter(func(i): return not d.defeated(i) and (d.at_war(0, i) or d.rel(0, i) < -25.0))
	if hostiles.is_empty():
		return ""
	var attacker: int = hostiles[randi() % hostiles.size()]
	var name: String = d.name_of(attacker)
	var nat = world.market.ai_nation(attacker)
	var defence: float = 0.25 + (0.18 if has_agency() else 0.0) + ready_agents().size() * 0.05 + (world.research.bonus("counterSpy") if world.research else 0.0)
	defence += 0.25 if clock < security_until else 0.0
	var text := ""
	if force_outcome == "caught" or (force_outcome == "" and randf() < clampf(defence, 0.1, 0.9)):
		d.change(0, attacker, -8.0)
		add_report(attacker, "counterintel", "Enemy agent from %s captured and interrogated" % name, 8.0)
		world.research.add_points(40.0)
		text = "COUNTER-INTELLIGENCE: an agent from %s was caught. Interrogation yields intelligence and +40 research." % name
	else:
		var r := randf()
		if r < 0.4:
			var amount := minf(world.economy.res.money, 200.0 + randi() % 300)
			world.economy.res.money -= amount
			if nat:
				nat.money += amount
			text = "%s agents siphoned $%d from your treasury!" % [name, int(amount)]
		elif r < 0.55 and not world.market.routes.is_empty():
			# The next of your cargoes never arrives (market.gd).
			world.market.sabotaged += 1
			text = "%s saboteurs are working your shipping lanes: your next cargo will not arrive. Warships and counter-intelligence help." % name
		elif r < 0.7:
			world.research.add_points(-70.0)
			if nat:
				nat.tech = float(nat.get("tech", 0.0)) + 0.5
			text = "%s stole your research data (-70 research)!" % name
		else:
			var t = _random_building(0)
			if t != null:
				covert_damage(t, t.max_hp * 0.4)
				text = "SABOTAGE! %s operatives bombed your %s!" % [name, t.def.name]
	if text != "":
		world.hud.notice(text)
	changed.emit()
	return text

## Intel at 60+ (or Satellite Recon) warns of an attack wave before it sets out.
func warn_attack(nation: int) -> void:
	if (intel.get(nation, 0.0) >= 60.0 and dossiers.has(nation) and dossiers[nation].get("confidence", "low") != "low" and clock - float(dossiers[nation].t) <= 180.0) or (world.research and world.research.bonus("warn") >= 1.0):
		world.hud.notice("INTELLIGENCE: %s will launch an attack within 30 seconds." % world.diplomacy.name_of(nation))

# ---------------------------------------------------------------- saving

func capture() -> Dictionary:
	return {"agents": agents, "network": network, "heat": heat, "intel": intel, "types": types, "reports": reports,
		"dossiers": dossiers, "debuffs": debuffs, "clock": clock, "boost_until": boost_until, "next_id": _next_id, "missions":missions, "cooldowns":cooldowns,
		"succession":succession, "proxies":proxies, "stability":stability,
		"security_until":security_until, "scandal_until":scandal_until, "enemy_next":enemy_next}.duplicate(true)

func restore(data: Dictionary) -> void:
	agents.clear()
	for a in data.get("agents", []):
		var copy: Dictionary = a.duplicate()
		for key in ["id", "skill", "xp", "ops", "captured_by"]:
			copy[key] = int(copy[key])
		agents.append(copy)
	for field in ["network", "heat", "intel", "types", "debuffs"]:
		var state: Dictionary = get(field)
		state.clear()
		for nation in range(1, world.map.nations.size()):
			state[nation] = {} if field in ["types", "debuffs"] else 0.0
	for grid in ["network", "heat", "intel"]:
		var into: Dictionary = get(grid)
		for key in data.get(grid, {}):
			into[int(key)] = float(data[grid][key])
	for key in data.get("types", {}):
		types[int(key)] = data.types[key].duplicate()
	reports = data.get("reports", []).duplicate(true)
	dossiers.clear()
	for key in data.get("dossiers", {}):
		dossiers[int(key)] = data.dossiers[key].duplicate(true)
	for key in data.get("debuffs", {}):
		debuffs[int(key)] = data.debuffs[key].duplicate()
	clock = float(data.get("clock", 0.0))
	boost_until = float(data.get("boost_until", 0.0))
	_next_id = int(data.get("next_id", agents.size() + 1))

	missions = data.get("missions", []).duplicate(true)
	for field in ["cooldowns", "succession", "proxies", "stability"]:
		var into: Dictionary = get(field)
		into.clear()
		for key in data.get(field, {}):
			into[int(key)] = data[field][key].duplicate(true) if data[field][key] is Dictionary else data[field][key]
	for nation in network:
		if not cooldowns.has(nation): cooldowns[nation] = {}
		if not succession.has(nation): succession[nation] = {}
		if not stability.has(nation): stability[nation] = 75.0
	security_until = float(data.get("security_until", 0.0))
	scandal_until = float(data.get("scandal_until", 0.0))
	enemy_next = float(data.get("enemy_next", clock + 150.0))
	_tick = 0.0
	# Old saves with a leadership strike in effect must not revive its victim.
	if not data.has("succession"):
		for nation in debuffs:
			for role in cfg.targets:
				if active(int(nation), role):
					succession[nation][role] = 1
					cooldowns[nation]["assassinate"] = clock + 600.0

# ---------------------------------------------------------------- campaign lifecycle

func _agent(id: int) -> Dictionary:
	for a in agents:
		if int(a.id) == id:
			return a
	return {}

func exposure_chance(key: String, nation: int) -> float:
	var base: float = PROGRAMS[key][4]
	return 0.0 if base == 0.0 else clampf(base + float(heat.get(nation, 0.0)) * 0.003, 0.0, 0.9)

func blocked_reason(key: String, nation: int, role := "", agent_id := -1) -> String:
	if not ops().has(key) or nation <= 0 or nation >= world.map.nations.size():
		return "Choose a valid operation and foreign nation."
	if world.diplomacy.defeated(nation): return "That nation no longer exists."
	if not has_agency(): return "Build an Intelligence Agency first."
	if not agents.any(func(a): return a.status == "ready" and (agent_id < 0 or int(a.id) == agent_id)):
		return "No ready agent. Agents must finish deployment and recovery."
	for m in missions:
		if int(m.nation) == nation: return "One assignment per target at a time."
	var wait: float = float(cooldowns.get(nation, {}).get(key, 0.0)) - clock
	if wait > 0: return "Security/recovery window: %ds remaining." % ceili(wait)
	if key == "counterSweep" and security_until > clock: return "Domestic security review is already active."
	if network.get(nation, 0.0) < PROGRAMS[key][2]: return "Requires network %d." % PROGRAMS[key][2]
	if intel.get(nation, 0.0) < PROGRAMS[key][3]: return "Requires intelligence %d." % PROGRAMS[key][3]
	if key == "assassinate":
		if not cfg.targets.has(role): return "Choose a valid leadership role."
		if not dossiers.has(nation) or clock - float(dossiers[nation].t) > 180.0 or dossiers[nation].get("confidence", "low") == "low":
			return "Requires a field dossier less than 180 seconds old."
	if key == "proxyCell" and proxies.has(nation): return "A local partner is already supported."
	if key == "armRebels" and not proxies.has(nation): return "Establish a local partner first."
	if key == "falseFlag" and not range(1, world.diplomacy.n).any(func(i): return i != nation and not world.diplomacy.defeated(i)):
		return "No other surviving rival to implicate."
	if world.economy.res.money < float(ops()[key].cost): return "Insufficient treasury for this program."
	return ""

func run(op_key: String, nation: int, role := "", agent_id := -1, roll := -1.0) -> String:
	var reason := blocked_reason(op_key, nation, role, agent_id)
	if reason != "": return reason
	var agent: Dictionary = ready_agents().filter(func(a): return agent_id < 0 or int(a.id) == agent_id)[0]
	var duration: float = PROGRAMS[op_key][0]
	if not world.economy.pay({"money":float(ops()[op_key].cost)}): return "Insufficient treasury."
	agent.status = "deployed"
	missions.append({"op":op_key, "nation":nation, "role":role, "agent":agent.id,
		"started":clock, "ends":clock + duration, "roll":roll})
	# Reserve the target at submission. Failure, cancellation and save/load cannot bypass it.
	cooldowns[nation][op_key] = clock + duration + float(PROGRAMS[op_key][1])
	changed.emit()
	return "%s authorized: %ds preparation, then recovery. Funds committed." % [ops()[op_key].name, int(duration)]

func cancel_mission(agent_id: int) -> String:
	for m in missions:
		if int(m.agent) == agent_id:
			missions.erase(m)
			var a := _agent(agent_id)
			a.status = "recovering"
			a.ready_at = clock + 30.0
			changed.emit()
			return "Assignment recalled. Funds remain spent; security cooldown remains."
	return "No assignment to recall."

func end_proxy(nation: int) -> String:
	proxies.erase(nation)
	changed.emit()
	return "Partner funding ended. Upkeep and economic pressure stop."

func advance(delta: float) -> void:
	if delta <= 0: return
	if delta > 1.0:
		var remaining := delta
		while remaining > 0.0:
			var step := minf(1.0, remaining)
			advance(step)
			remaining -= step
		return
	clock += delta
	for a in agents:
		if a.status == "recovering" and clock >= float(a.get("ready_at", 0.0)):
			a.status = "ready"
			changed.emit()
	for mission in missions.duplicate():
		if clock < float(mission.ends): continue
		missions.erase(mission)
		var a := _agent(int(mission.agent))
		if a.is_empty(): continue
		var result := "Assignment cancelled: target no longer exists or agency was lost."
		if has_agency() and not world.diplomacy.defeated(int(mission.nation)):
			result = _resolve(mission)
		else:
			add_report(int(mission.nation), str(mission.op), result, 0.0)
		if a.status != "captured":
			a.status = "recovering"
			a.ready_at = clock + 30.0
		world.hud.notice(result)
		changed.emit()
	for nation in proxies.keys():
		var p: Dictionary = proxies[nation]
		if clock >= float(p.until) or world.diplomacy.defeated(int(nation)):
			proxies.erase(nation)
			continue
		if not world.economy.pay({"money":3.0 * delta}):
			p.strength = maxf(0.0, float(p.strength) - delta * 1.5)
			p.autonomy = minf(100.0, float(p.autonomy) + delta * 0.5)
		p.autonomy = minf(100.0, float(p.autonomy) + delta * 0.06)
		if p.strength <= 0.0 or p.autonomy >= 70.0:
			proxies.erase(nation)
			var text := "Local partner broke away; economic pressure ended." + _expose(int(nation), "proxyCell")
			add_report(int(nation), "proxy", text, 0.0)
			world.hud.notice(text)
	for nation in stability:
		stability[nation] = move_toward(float(stability[nation]), 75.0, delta * 0.035)
	# Domestic political scandal has a visible continuing budget cost.
	if clock < scandal_until:
		world.economy.res.money = maxf(0.0, world.economy.res.money - delta * 2.0)

func _expose(nation: int, key: String) -> String:
	var severe := key in ["assassinate", "armRebels", "falseFlag"]
	world.diplomacy.change(0, nation, -40.0 if severe else -20.0)
	for other in range(1, world.diplomacy.n):
		if other != nation and not world.diplomacy.defeated(other):
			world.diplomacy.change(0, other, -8.0 if severe else -3.0)
	world.diplomacy.set_flag(world.diplomacy.pact, 0, nation, false)
	scandal_until = maxf(scandal_until, clock + (180.0 if severe else 90.0))
	heat[nation] = minf(100.0, heat[nation] + 20.0)
	network[nation] = maxf(0.0, network[nation] - 12.0)
	_set_debuff(nation, "alert", 180.0)
	if key == "assassinate" and randf() < 0.35:
		world.ai.declare_war(nation, false)
	return " Attribution to your state: relations damaged, trade pact revoked, network compromised; scandal costs $2/s."

func _collect(nation: int, public_only: bool) -> String:
	var nat = world.market.ai_nation(nation)
	var quality := "low" if public_only else ("high" if network[nation] >= 55.0 else "medium")
	var uncertainty := 0.35 if quality == "low" else (0.1 if quality == "high" else 0.2)
	var army := float(world.diplomacy.army_strength(nation))
	var funds := float(nat.money) if nat else 0.0
	var ties: Array = []
	for other in range(world.diplomacy.n):
		if other != nation and world.diplomacy.at_war(nation, other):
			ties.append("war with " + world.diplomacy.name_of(other))
	dossiers[nation] = {"t":clock, "confidence":quality, "source":"Public indicators" if public_only else "Corroborated field reporting",
		"army_low":floori(army * (1.0-uncertainty)), "army_high":ceili(army * (1.0+uncertainty)),
		"money_low":floori(funds * (1.0-uncertainty)), "money_high":ceili(funds * (1.0+uncertainty)),
		"ties":", ".join(PackedStringArray(ties)), "stability":roundi(stability[nation])}
	return "Assessment filed: %s confidence; estimates reflect collection time, not live surveillance." % quality

func dossier_text(nation: int) -> String:
	if not dossiers.has(nation): return "No assessment on file. Commission public analysis or a recon dossier."
	var r: Dictionary = dossiers[nation]
	var age := maxi(0, int(clock - float(r.t)))
	if not r.has("confidence"): return "Legacy report: recollect to establish source confidence."
	return "%s | %s confidence | %ds old%s\nArmy estimate %d–%d; treasury $%d–%d\nInstitutional stability estimate %d/100\n%s" % [r.source, r.confidence, age, " — STALE" if age > 180 else "", r.army_low, r.army_high, r.money_low, r.money_high, r.stability, r.ties]

func impact_text(nation: int) -> String:
	var lines: Array[String] = []
	for entry in [["cyber", "Production disrupted"], ["unrest", "Unrest pressure"], ["influence", "Influence pressure"], ["president", "Leadership transition"], ["general", "Command disruption"], ["spymaster", "Intelligence disruption"], ["alert", "Heightened security"]]:
		if active(nation, entry[0]):
			lines.append("%s: %ds" % [entry[1], ceili(float(debuffs[nation][entry[0]]) - clock)])
	if not lines.is_empty() or proxies.has(nation):
		lines.append("Combined income penalty: %d%% (recovers over time)" % roundi((1.0-income_mult(nation))*100.0))
	return "\n".join(PackedStringArray(lines))

func role_effect(role: String) -> String:
	return {"president":"Income -35% for 240s; offensive pause 90s; successor takes office.",
		"general":"Damage -30% for 240s; offensive pause 60s; successor takes command.",
		"scientist":"Rival research -2 levels; no research windfall for the attacker.",
		"spymaster":"Counter-intelligence weakened for 300s; security alert still applies."}.get(role, "")
