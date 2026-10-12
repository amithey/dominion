extends RefCounted
## Research -> local validation -> paid commissioning -> compute-limited operation.
const Data := preload("res://scripts/ai_applications_data.gd")
const Factions := preload("res://scripts/factions.gd")
const UseData := preload("res://scripts/ai_use_data.gd")
const Strategic := preload("res://scripts/ai_strategic.gd")
var _directorate: WeakRef
var a: RefCounted:
	get: return _directorate.get_ref()
var w: Node
var rows := {} # owner -> programme -> {work, validated, enabled}
var projects := {} # one validation at a time per nation
var coverage := {} # rebuilt each simulation second; never persisted
var consultation_ready := {} # global per initiating nation, not per target
var category := "civil"
var _rival_at := 0.0
var export_ready := {} # owner -> when it may sell its next AI package
var _strategic_at := 0.0

func _init(directorate: RefCounted, world: Node) -> void:
	_directorate = weakref(directorate)
	w = world

func country(owner: int) -> Array:
	return Data.COUNTRY.get(Factions.identity(w, owner), ["Limited evidence", "No verified deployment assumed.", []])

func row(owner: int, key: String) -> Dictionary:
	if not rows.has(owner): rows[owner] = {}
	if not rows[owner].has(key): rows[owner][key] = {"work": 0.0, "validated": false, "enabled": false}
	return rows[owner][key]

func facility(owner: int, key: String) -> bool:
	return w.buildings.any(func(b): return int(b.owner) == owner and b.key == key and b.built and not b.dead and b.get("supplied", true) and float(b.get("disabled_until", 0.0)) <= w.game_time)

func eligible(owner: int, key: String) -> String:
	if not Data.PROGRAMS.has(key): return "Unknown application."
	if owner < 0 or owner >= w.map.nations.size(): return "Unknown nation."
	if w.diplomacy.defeated(owner): return "Nation defeated."
	var p: Dictionary = Data.PROGRAMS[key]
	if a.AIData.ceiling(w, owner) < int(p.level): return "Beyond national AI capacity (level %d needed)." % int(p.level)
	if key == "strategic" and (w.get("defcon") == null or not w.defcon.nuclear(owner)): return "Only nuclear powers can commission strategic warning verification."
	var record: Array = UseData.of(Factions.identity(w, owner), key)
	if str(record[0]) == "barred": return "Barred by your nation's law: %s" % str(record[1])
	if key == "deadHand":
		if w.get("defcon") == null or not w.defcon.nuclear(owner): return "Only a nuclear power has warheads to automate."
		if a.signatory(owner, "nuclear"): return "You are bound by the declaration on human control of nuclear weapons: withdraw from it first (Doctrine)." if owner == 0 else "Bound by the declaration on human control of nuclear weapons."
	if a.level(owner) < int(p.level): return "Train AI to level %d first." % int(p.level)
	if not a.researched(owner, p.research): return "Complete research: %s." % str(p.name)
	if not facility(owner, p.facility): return "Needs a working, supplied %s." % str(w.building_defs.get(p.facility, {}).get("name", p.facility))
	if a.compute_rate(owner) <= 0.0: return "No working compute capacity."
	return ""

func price(key: String, commission: bool) -> float:
	return float(Data.PROGRAMS[key].money) * (0.6 if commission else 0.4)

func affordable(owner: int, money: float) -> bool:
	if owner == 0: return w.economy != null and w.economy.can_afford({"money": money})
	for n in w.ai.nations:
		if int(n.id) == owner: return float(n.money) >= money
	return false

func pay(owner: int, money: float) -> bool:
	if not affordable(owner, money): return false
	if owner == 0: return w.economy.pay({"money": money})
	for n in w.ai.nations:
		if int(n.id) == owner:
			n.money -= money
			return true
	return false

func start_blocked(owner: int, key: String) -> String:
	var why := eligible(owner, key)
	if why != "": return why
	if bool(row(owner, key).validated): return "Already validated."
	if projects.has(owner): return "One validation project at a time; pause the current project first."
	if not bool(row(owner, key).get("paid", false)) and not affordable(owner, price(key, false)): return "Needs $%d for local validation." % roundi(price(key, false))
	return ""

func start(owner: int, key: String) -> String:
	var why := start_blocked(owner, key)
	if why != "": return why
	# A paused project retains its paid work; restarting it does not charge twice.
	if not bool(row(owner, key).get("paid", false)):
		if not pay(owner, price(key, false)): return "Insufficient funds."
		row(owner, key).paid = true
	projects[owner] = key
	return "Validation started: %s. Half your Training runs compute now feeds local trials." % str(Data.PROGRAMS[key].name)

func pause(owner: int) -> String:
	projects.erase(owner)
	return "Validation paused; paid work retained."

func commission_blocked(owner: int, key: String) -> String:
	var why := eligible(owner, key)
	if why != "": return why
	if not bool(row(owner, key).validated): return "Complete local trials first."
	if bool(row(owner, key).enabled): return "Already commissioned."
	if not bool(row(owner, key).get("commissioned", false)) and not affordable(owner, price(key, true)): return "Needs $%d to commission." % roundi(price(key, true))
	return ""

func commission(owner: int, key: String) -> String:
	var why := commission_blocked(owner, key)
	if why != "": return why
	var r := row(owner, key)
	if not bool(r.get("commissioned", false)):
		if not pay(owner, price(key, true)): return "Insufficient funds."
		r.commissioned = true
		if key == "surveillance": _surveillance_reaction(owner)
	r.enabled = true
	refresh()
	if w.research != null: w.research._recompute()
	return "%s commissioned; running costs and compute demand apply." % str(Data.PROGRAMS[key].name)

## Democracies think less of a government that turns face recognition on its people.
func _surveillance_reaction(owner: int) -> void:
	var support = w.get("support")
	if support == null: return
	for other in range(w.diplomacy.n):
		if other != owner and not w.diplomacy.defeated(other) and support.regime(other) == "democracy":
			w.diplomacy.change(owner, other, -6.0)

func suspend(owner: int, key: String) -> String:
	row(owner, key).enabled = false
	refresh()
	if w.research != null: w.research._recompute()
	return "Application suspended; no running cost or compute demand."

func training_flow(owner: int) -> float:
	return a.flow(owner, "frontier") * (0.5 if projects.has(owner) else 1.0)

func running(owner: int, key: String) -> bool:
	return rows.has(owner) and rows[owner].has(key) and bool(rows[owner][key].enabled) and bool(rows[owner][key].validated) and eligible(owner, key) == ""

func demand(owner: int, pool: String) -> float:
	var total := 0.0
	for key in rows.get(owner, {}):
		if Data.PROGRAMS[key].pool == pool and running(owner, key): total += float(Data.PROGRAMS[key].demand)
	return total

## The share of the full effect: coverage, half again for the second generation.
func factor(owner: int, key: String) -> float:
	var f := float(coverage.get(owner, {}).get(key, 0.0))
	if f > 0.0 and int(rows[owner][key].get("gen", 1)) >= 2: f *= Data.GEN2
	return f

## Field experience a running application gathers: a second of full coverage
## is a second's experience; the second generation needs twice its trials' work.
func experience_needed(key: String) -> float:
	return float(Data.PROGRAMS[key].work) * 2.0

func upgrade_price(key: String) -> float:
	return float(Data.PROGRAMS[key].money) * 0.5

func upgrade_blocked(owner: int, key: String) -> String:
	var r := row(owner, key)
	if int(r.get("gen", 1)) >= 2: return "Second generation in service."
	if not running(owner, key): return "Only an operating application can be upgraded."
	if not a.researched(owner, Data.SECOND_GENERATION): return "Research Fielded AI: the second generation."
	if float(r.get("exp", 0.0)) < experience_needed(key): return "Field experience %d%%: keep it running." % int(100.0 * float(r.get("exp", 0.0)) / experience_needed(key))
	if not affordable(owner, upgrade_price(key)): return "Needs $%d." % roundi(upgrade_price(key))
	return ""

## The second generation, trained on what the first saw in service.
func upgrade(owner: int, key: String) -> String:
	var why := upgrade_blocked(owner, key)
	if why != "": return why
	if not pay(owner, upgrade_price(key)): return "Insufficient funds."
	row(owner, key).gen = 2
	refresh()
	if w.research != null: w.research._recompute()
	var text := "%s: the second generation enters service, trained on the first one's data. Its effect is half again as strong." % str(Data.PROGRAMS[key].name)
	if owner == 0: a._note(text)
	return text

## AI exports: the player's sale of a package to `target`.
func export_blocked(owner: int, target: int) -> String:
	return Strategic.export_blocked(w, owner, target, float(export_ready.get(owner, 0.0)))

func export_to(owner: int, target: int) -> String:
	var why := export_blocked(owner, target)
	if why != "": return why
	export_ready[owner] = w.game_time + Strategic.EXPORT_COOLDOWN
	return Strategic.export_to(w, owner, target)

func upkeep(owner := 0) -> float:
	var total := 0.0
	for key in rows.get(owner, {}):
		if running(owner, key): total += float(Data.PROGRAMS[key].upkeep)
	return total

func refresh() -> void:
	coverage.clear()
	for owner in rows:
		coverage[owner] = {}
		var funded := affordable(owner, upkeep(owner))
		for key in rows[owner]:
			if not funded or not running(owner, key): continue
			var p: Dictionary = Data.PROGRAMS[key]
			coverage[owner][key] = clampf(a.flow(owner, p.pool) / maxf(0.001, demand(owner, p.pool)), 0.0, 1.0)

func bonuses(owner := 0) -> Dictionary:
	var out := {}
	for key in coverage.get(owner, {}):
		for stat in Data.PROGRAMS[key].fx:
			out[stat] = float(out.get(stat, 0.0)) + float(Data.PROGRAMS[key].fx[stat]) * factor(owner, key)
	return out

func update() -> void:
	for owner in projects.keys():
		var key: String = projects[owner]
		if eligible(owner, key) != "": continue
		var r := row(owner, key)
		# National familiarity makes commissioning modestly easier, not a free capability.
		var familiar: bool = key in country(owner)[2]
		# A nation that already fields it (ai_use_data.gd) needs half the trials, one developing it 80%.
		var pace: float = (1.15 if familiar else 1.0) / UseData.work_factor(Factions.identity(w, owner), key)
		r.work = minf(float(Data.PROGRAMS[key].work), float(r.work) + a.flow(owner, "frontier") * 0.5 * pace)
		if float(r.work) >= float(Data.PROGRAMS[key].work):
			r.validated = true
			projects.erase(owner)
			if owner == 0:
				var text := "AI trials complete: %s. Ready for commissioning." % str(Data.PROGRAMS[key].name)
				a._note(text)
				w.hud.notice(text)
	refresh()
	for owner in coverage:
		for key in coverage[owner]:
			var r := row(owner, key)
			r.exp = minf(experience_needed(key), float(r.get("exp", 0.0)) + float(coverage[owner][key]))
	if w.game_time >= _strategic_at:
		_strategic_at = w.game_time + 30.0
		Strategic.undersea_tension(w)
	# Rivals pay upkeep too; player costs are deducted by economy.tick through directorate.upkeep().
	for owner in rows:
		if int(owner) > 0: pay(owner, upkeep(owner))
	if w.game_time >= _rival_at:
		_rival_at = w.game_time + 30.0
		_rivals()
	if w.research != null: w.research._recompute()

func _rivals() -> void:
	for n in w.ai.nations:
		var owner := int(n.id)
		if n.defeated: continue
		# What the nation already fields comes first (ai_use_data.gd), then its priorities.
		var priorities: Array = UseData.fielded(Factions.identity(w, owner)).filter(func(k): return Data.PROGRAMS.has(k))
		for k in country(owner)[2]:
			if not k in priorities: priorities.append(k)
		if w.defcon != null and w.defcon.nuclear(owner): priorities.append("strategic")
		for key in rows.get(owner, {}):
			if upgrade_blocked(owner, key) == "": upgrade(owner, key)
		if factor(owner, "export") >= 0.5 and w.game_time >= float(export_ready.get(owner, 0.0)):
			var buyers: Array = range(1, w.diplomacy.n).filter(func(t): return t != owner and export_blocked(owner, t) == "" and w.diplomacy.rel(owner, t) >= 20.0)
			if not buyers.is_empty(): export_to(owner, buyers[randi() % buyers.size()])
		for key in priorities:
			if eligible(owner, key) != "": continue
			if bool(row(owner, key).validated):
				if not bool(row(owner, key).enabled): commission(owner, key)
			elif not projects.has(owner):
				start(owner, key)
				break

func consultation_blocked(owner: int, target: int) -> String:
	if target < 0 or target >= w.map.nations.size() or owner == target or w.diplomacy.defeated(target): return "Choose a living foreign nation."
	if factor(owner, "diplomacy") < 0.5: return "Diplomatic analysis needs at least 50% operating coverage."
	if w.game_time < float(consultation_ready.get(owner, 0.0)): return "Consultation cooldown: %ds." % ceili(float(consultation_ready[owner]) - w.game_time)
	if not affordable(owner, 250.0) or a.reserve(owner) < 40.0: return "Needs $250 and 40 intelligence reserve."
	return ""

func consult(owner: int, target: int) -> String:
	var why := consultation_blocked(owner, target)
	if why != "": return why
	if not pay(owner, 250.0): return "Insufficient funds."
	a.st[owner].reserve -= 40.0
	consultation_ready[owner] = w.game_time + 180.0
	var gain := 4.0 if w.diplomacy.at_war(owner, target) else 8.0
	w.diplomacy.change(owner, target, gain)
	var text := "AI-assisted consultation with %s: relations +%d. Governments retain control of treaties and ceasefires." % [w.diplomacy.name_of(target), int(gain)]
	if owner == 0: a._note(text)
	return text

func capture() -> Dictionary:
	var saved_rows := {}
	for owner in rows: saved_rows[str(owner)] = rows[owner].duplicate(true)
	return {"rows": saved_rows, "projects": a._keyed(projects), "consultation": a._keyed(consultation_ready), "export": a._keyed(export_ready)}

func restore(data: Dictionary) -> void:
	rows.clear()
	projects.clear()
	consultation_ready.clear()
	export_ready.clear()
	for k in data.get("rows", {}):
		var owner := int(k)
		if owner < 0 or owner >= w.map.nations.size(): continue
		for key in data.rows[k]:
			if not Data.PROGRAMS.has(key): continue
			var saved: Dictionary = data.rows[k][key]
			var r := row(owner, key)
			r.work = clampf(float(saved.get("work", 0.0)), 0.0, float(Data.PROGRAMS[key].work))
			r.validated = bool(saved.get("validated", false))
			r.enabled = bool(saved.get("enabled", false)) and bool(r.validated)
			r.paid = bool(saved.get("paid", false))
			r.commissioned = bool(saved.get("commissioned", false))
			r.exp = clampf(float(saved.get("exp", 0.0)), 0.0, experience_needed(key))
			r.gen = clampi(int(saved.get("gen", 1)), 1, 2)
	for k in data.get("projects", {}):
		if int(k) >= 0 and int(k) < w.map.nations.size() and Data.PROGRAMS.has(str(data.projects[k])): projects[int(k)] = str(data.projects[k])
	for k in data.get("consultation", {}): consultation_ready[int(k)] = float(data.consultation[k])
	for k in data.get("export", {}): export_ready[int(k)] = float(data.export[k])
	refresh()
