extends Node
## Espionage, ported from the intelligence engine in js/diplomacy.js.
## An Intelligence Agency lets the player recruit named field agents and send
## them on covert operations (SPY_OPS in config.js, through the map export)
## against a chosen nation and, for assassinations, a chosen person. Success
## depends on the operation, the agent's skill, the agency, the network built
## inside that nation, heat from earlier operations, intelligence already gathered
## and the rival's counter-intelligence (difficulty). Every outcome matters:
## - success builds the network, raises heat, trains the agent and files
##   intelligence, which reveals more about the nation in the Intel panel
##   (treasury, army, treaties) and at 60+ warns of attacks before they land;
## - failure burns the network, and the agent may be captured: relations drop,
##   a failed assassination can start a war, and the agent can be ransomed;
## - the effects are real: stolen money moves between treasuries, cyber
##   attacks stop the rival's production, proxy cells and rebels cut its
##   income, a false flag turns two rivals on each other, and a dead head of
##   state or general paralyses its army or blunts it. Stolen research becomes
##   faster training at home (the native world has no research tree yet).
## Hostile services strike back: sabotage, theft of funds and blueprints,
## unless the agency and idle agents catch them.

signal changed

const TICK := 10.0
const INTEL_TIERS := [[10, "Treasury and buildings"], [25, "Army strength"], [40, "Wars, allies and pacts"], [60, "Warning of attacks on you"]]
const INTEL_GAIN := {"buildNetwork": 6, "reconDossier": 18, "cyberAttack": 8, "stealFunds": 5, "stealTech": 10, "sabotage": 6, "proxyCell": 8, "armRebels": 8, "falseFlag": 6, "assassinate": 12}

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

func setup(world_node: Node, espionage: Dictionary) -> void:
	world = world_node
	cfg = espionage
	for i in range(1, world.map.nations.size()):
		network[i] = 0.0
		heat[i] = 0.0
		intel[i] = 0.0
		types[i] = {}
		debuffs[i] = {}

func ops() -> Dictionary:
	return cfg.ops

func has_agency() -> bool:
	return world.economy.owned("intelAgency") > 0

func ready_agents() -> Array:
	return agents.filter(func(a): return a.status == "ready")

func rank(agent: Dictionary) -> String:
	return cfg.ranks[clampi(int(agent.skill) - 1, 0, cfg.ranks.size() - 1)]

func recruit_cost() -> int:
	return int(cfg.recruitBase) + agents.size() * int(cfg.recruitStep)

func person(nation: int, role: String) -> String:
	return world.map.nations[nation].get("people", {}).get(role, role.capitalize())

func active(nation: int, kind: String) -> bool:
	return debuffs.get(nation, {}).get(kind, 0.0) > clock

func _set_debuff(nation: int, kind: String, seconds: float) -> void:
	debuffs[nation][kind] = maxf(debuffs[nation].get(kind, 0.0), clock + seconds)

## Multiplier on an AI nation's income (proxy cells, rebels, a dead leader).
func income_mult(nation: int) -> float:
	var m := 1.0
	if active(nation, "proxy"):
		m *= 0.7
	if active(nation, "unrest"):
		m *= 0.75
	if active(nation, "president"):
		m *= 0.65
	return m

## Multiplier on the damage a nation's forces deal (a dead general: -30%).
func damage_mult(nation: int) -> float:
	return 0.7 if nation > 0 and active(nation, "general") else 1.0

## Whether an AI nation can launch attacks (not while leaderless).
func paralyzed(nation: int) -> bool:
	return active(nation, "paralyzed")

## Whether its factories run (a cyber attack stops them).
func production_down(nation: int) -> bool:
	return active(nation, "cyber")

func training_boost() -> float:
	return 1.25 if boost_until > clock else 1.0

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
			var price := int(cfg.ransom)
			if not world.economy.pay({"money": price}):
				return "Buying back \"%s\" costs $%d." % [a.name, price]
			var captor = world.market.ai_nation(int(a.captured_by))
			if captor != null:
				captor.money += price
			a.status = "ready"
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
	types[nation][kind] = true
	reports.push_front({"t": clock, "nation": nation, "text": text})
	if reports.size() > 25:
		reports.pop_back()

# ---------------------------------------------------------------- operations

func counter_spy(nation: int) -> float:
	if active(nation, "spymaster"):
		return 0.0
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
	return clampf(p, 0.05, 0.95)

## Runs `op_key` against `nation` with the given agent (or the first ready one).
func run(op_key: String, nation: int, role := "", agent_id := -1, roll := -1.0) -> String:
	var op: Dictionary = ops().get(op_key, {})
	var d: Node = world.diplomacy
	if op.is_empty():
		return ""
	if not has_agency():
		return "Covert operations require an Intelligence Agency."
	var agent = null
	for a in agents:
		if a.status == "ready" and (agent_id < 0 or a.id == agent_id):
			agent = a
			break
	if agent == null:
		return "No agent available. Recruit one at the Intelligence Agency."
	if d.defeated(nation):
		return "That nation no longer exists."
	if network.get(nation, 0.0) < float(op.get("minNetwork", 0)):
		return "%s needs network %d in %s. Build your network first." % [op.name, int(op.minNetwork), d.name_of(nation)]
	if op.get("needsPerson", false) and role == "":
		return "Choose a target person."
	if not world.economy.pay({"money": float(op.cost)}):
		return "%s costs $%d." % [op.name, int(op.cost)]
	var p := clampf(success_chance(op_key, nation) + (int(agent.skill) - 1) * float(cfg.skillBonus), 0.05, 0.97)
	var r := randf() if roll < 0.0 else roll
	var nat_name: String = d.name_of(nation)
	var message := ""
	if r < p:
		network[nation] = clampf(network[nation] + (16.0 if op_key == "buildNetwork" else 3.0), 0.0, 100.0)
		heat[nation] = clampf(heat[nation] + (2.0 if op_key == "reconDossier" else 8.0), 0.0, 100.0)
		message = _succeed(op_key, nation, role)
		_gain_xp(agent)
		add_report(nation, op_key, "%s in %s — success (Agent \"%s\")" % [op.name, nat_name, agent.name], INTEL_GAIN.get(op_key, 5))
	else:
		heat[nation] = clampf(heat[nation] + 14.0, 0.0, 100.0)
		network[nation] = clampf(network[nation] - 5.0, 0.0, 100.0)
		if randf() < clampf(0.55 - (int(agent.skill) - 1) * 0.07, 0.15, 0.6):
			agent.status = "captured"
			agent.captured_by = nation
			d.change(0, nation, -25.0)
			message = "Operation failed: Agent \"%s\" was CAPTURED by %s. Ransom: $%d in the Intel panel." % [agent.name, nat_name, int(cfg.ransom)]
			if op_key == "assassinate" and randf() < 0.35:
				world.ai.declare_war(nation, false)
		else:
			message = "Operation failed, but Agent \"%s\" escaped cleanly." % agent.name
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
		"reconDossier":
			var report := {"t": clock, "army": d.army_strength(nation), "money": int(nat.money) if nat else 0,
				"buildings": world.buildings.filter(func(b): return b.owner == nation and not b.dead).size(), "relation": int(d.rel(0, nation))}
			dossiers[nation] = report
			return "Recon dossier on %s: army %d, treasury $%d, %d buildings, relation %+d." % [nat_name, report.army, report.money, report.buildings, report.relation]
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
			boost_until = maxf(boost_until, clock) + 180.0
			return "Stolen designs from %s: your units train 25%% faster for 3 minutes." % nat_name
		"sabotage":
			var t = _random_building(nation)
			if t == null:
				return "Sabotage succeeded but found no valuable target."
			covert_damage(t, t.max_hp * 0.7)
			return "Sabotage: %s's %s is burning." % [nat_name, t.def.name]
		"proxyCell":
			_set_debuff(nation, "proxy", 180.0)
			return "A proxy cell is disrupting %s's economy for 3 minutes (-30%% income)." % nat_name
		"armRebels":
			_set_debuff(nation, "unrest", 180.0)
			for i in range(2):
				var t = _random_building(nation)
				if t != null:
					covert_damage(t, t.max_hp * 0.35)
			return "Rebels armed inside %s: income -25%% for 3 minutes, facilities attacked." % nat_name
		"falseFlag":
			var rivals := range(1, d.n).filter(func(i): return i != nation and not d.defeated(i))
			if rivals.is_empty():
				return "No rival to frame."
			var rival: int = rivals[randi() % rivals.size()]
			d.change(nation, rival, -45.0)
			if d.rel(nation, rival) < -70.0 and randf() < 0.45:
				d.declare_war(nation, rival)
			return "False flag planted: %s and %s blame each other." % [nat_name, d.name_of(rival)]
		"assassinate":
			var who := person(nation, role)
			var text := ""
			match role:
				"president":
					_set_debuff(nation, "president", 240.0)
					_set_debuff(nation, "paralyzed", 90.0)
					if nat:
						nat.money = floorf(nat.money * 0.6)
					for j in range(1, d.n):
						if j != nation and not d.defeated(j):
							d.change(nation, j, -12.0)
					text = "%s of %s assassinated! Income -35%% for 4 minutes, army paralysed for 90 s, treasury looted." % [who, nat_name]
				"general":
					_set_debuff(nation, "general", 240.0)
					_set_debuff(nation, "paralyzed", 60.0)
					for u in world.units:
						if u.owner == nation and not u.dead and u.attack_move:
							u.target = null
							u.attack_move = false
					text = "%s of %s eliminated! Their army deals 30%% less damage for 4 minutes; its offensive collapses." % [who, nat_name]
				"scientist":
					boost_until = maxf(boost_until, clock) + 240.0
					text = "%s of %s eliminated! Their designs are yours: training 25%% faster for 4 minutes." % [who, nat_name]
				_:
					_set_debuff(nation, "spymaster", 300.0)
					network[nation] = clampf(network[nation] + 20.0, 0.0, 100.0)
					text = "%s of %s eliminated! Their counter-intelligence is down for 5 minutes." % [who, nat_name]
			if randf() < 0.4:
				d.change(0, nation, -50.0)
				text += " The killing was traced back to you!"
				if randf() < 0.5:
					world.ai.declare_war(nation, false)
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
	clock += delta
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		tick()

func tick() -> void:
	for i in heat:
		heat[i] = maxf(0.0, heat[i] - 1.5)
		intel[i] = maxf(0.0, intel[i] - 0.35)
	if clock > 240.0 and randf() < 0.028:
		enemy_attempt()

func enemy_attempt(force_outcome := "") -> String:
	var d: Node = world.diplomacy
	var hostiles := range(1, d.n).filter(func(i): return not d.defeated(i) and (d.at_war(0, i) or d.rel(0, i) < -25.0))
	if hostiles.is_empty():
		return ""
	var attacker: int = hostiles[randi() % hostiles.size()]
	var name: String = d.name_of(attacker)
	var nat = world.market.ai_nation(attacker)
	var defence := 0.25 + (0.18 if has_agency() else 0.0) + ready_agents().size() * 0.05
	var text := ""
	if force_outcome == "caught" or (force_outcome == "" and randf() < clampf(defence, 0.1, 0.9)):
		d.change(0, attacker, -8.0)
		add_report(attacker, "counterintel", "Enemy agent from %s captured and interrogated" % name, 8.0)
		text = "COUNTER-INTELLIGENCE: an agent from %s was caught. Interrogation yields intelligence on them." % name
	else:
		var r := randf()
		if r < 0.4:
			var amount := minf(world.economy.res.money, 200.0 + randi() % 300)
			world.economy.res.money -= amount
			if nat:
				nat.money += amount
			text = "%s agents siphoned $%d from your treasury!" % [name, int(amount)]
		elif r < 0.7:
			boost_until = 0.0
			if nat:
				nat.money += 300.0
			text = "%s stole your military blueprints and sold them on." % name
		else:
			var t = _random_building(0)
			if t != null:
				covert_damage(t, t.max_hp * 0.4)
				text = "SABOTAGE! %s operatives bombed your %s!" % [name, t.def.name]
	if text != "":
		world.hud.notice(text)
	changed.emit()
	return text

## Intel at 60+ warns of an attack wave before it sets out.
func warn_attack(nation: int) -> void:
	if intel.get(nation, 0.0) >= 60.0:
		world.hud.notice("INTELLIGENCE: %s will launch an attack within 30 seconds." % world.diplomacy.name_of(nation))

# ---------------------------------------------------------------- saving

func capture() -> Dictionary:
	return {"agents": agents, "network": network, "heat": heat, "intel": intel, "types": types, "reports": reports,
		"dossiers": dossiers, "debuffs": debuffs, "clock": clock, "boost_until": boost_until, "next_id": _next_id}

func restore(data: Dictionary) -> void:
	agents.clear()
	for a in data.get("agents", []):
		var copy: Dictionary = a.duplicate()
		for key in ["id", "skill", "xp", "ops", "captured_by"]:
			copy[key] = int(copy[key])
		agents.append(copy)
	for grid in ["network", "heat", "intel"]:
		var into: Dictionary = get(grid)
		for key in data.get(grid, {}):
			into[int(key)] = float(data[grid][key])
	for key in data.get("types", {}):
		types[int(key)] = data.types[key].duplicate()
	reports = data.get("reports", []).duplicate(true)
	dossiers.clear()
	for key in data.get("dossiers", {}):
		dossiers[int(key)] = data.dossiers[key]
	for key in data.get("debuffs", {}):
		debuffs[int(key)] = data.debuffs[key].duplicate()
	clock = float(data.get("clock", 0.0))
	boost_until = float(data.get("boost_until", 0.0))
	_next_id = int(data.get("next_id", agents.size() + 1))
