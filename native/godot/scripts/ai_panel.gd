extends RefCounted
## The AI tab of the Defence window (ai_directorate.gd), in four small pages:
##   Compute     the AI level and training run, compute and its split, the
##               economy (automation and retraining)
##   Doctrine    the autonomy doctrine and the AI treaties
##   Operations  AI cyber campaigns, influence, model theft, chips, sabotage
##   AGI         the AGI project, its safety share and the race
##   Rivals      rivals' AI and what has happened

const POOL_HELP := {
	"military": "Autonomy, seekers, fusion cell, air defence",
	"economy": "Research, income, production",
	"intel": "Operations reserve, cyber defence, analysis",
	"frontier": "Training runs: the next AI level",
}

static func draw(sp) -> void:
	var hud = sp.hud
	var a = hud.world.get("directorate")
	if a == null:
		return
	sp._tabs([["Compute", "compute"], ["Doctrine", "doctrine"], ["Operations", "operations"], ["AGI", "agi"], ["Rivals", "rivals"]], a.ui_tab, func(v): a.ui_tab = v)
	match a.ui_tab:
		"agi":
			_agi(sp, a)
		"doctrine":
			_doctrine(sp, a)
		"operations":
			_operations(sp, a)
		"rivals":
			_rivals(sp, a)
		_:
			_compute(sp, a)

static func _compute(sp, a) -> void:
	var hud = sp.hud
	var lvl: int = a.level(0)
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("AI level %d: %s" % [lvl, a.LEVEL_NAMES[lvl]], 18, hud.UI.CREAM, true))
	var cap: int = a.cap(0)
	if lvl < 5 and lvl < cap:
		hud._meter(card, float(a.st[0].train), a.next_cost(0), hud.UI.GOLD, "Training run to level %d: %d / %d compute" % [lvl + 1, int(a.st[0].train), int(a.next_cost(0))])
	else:
		var next := {0: "Machine Learning", 2: "Military AI", 3: "Frontier Models"}
		sp._wrap(card, "Research %s to train further." % next.get(cap, "further") if lvl < 4 else "Your models are at the frontier.", 12)
	var dc: int = a.data_centres(0)
	var src := "%d data centre%s" % [dc, "" if dc == 1 else "s"]
	if a.researched(0, "machineLearning"):
		src += ", national industry +%.1f/s" % (a.AIData.rating(hud.world, 0, "compute") * a.NATIONAL)
	card.add_child(hud._text("Compute %.1f/s  (%s)" % [float(a.st[0].rate), src], 13, hud.UI.TEXT))
	if a.chip_factor(0) < 1.0:
		sp._wrap(card, "Data centres at %d%%: %s." % [roundi(a.chip_factor(0) * 100.0), "export controls on you" + (" (smuggling)" if a.smuggling.has(0) else "") if a.controlled(0) else "a global chip shortage"], 12, hud.UI.BAD)
	if float(a.st[0].rate) <= 0.0:
		sp._wrap(card, "No compute yet: research Machine Learning and build an AI Data Center.", 12)
	var split: VBoxContainer = hud._card()
	split.add_child(hud._text("Compute allocation", 15, hud.UI.CREAM, true))
	for pool in a.POOLS:
		var row: HBoxContainer = hud._row(split, 6)
		var name: Label = hud._text("%s  %d%%" % [a.POOL_NAMES[pool], roundi(a.share(0, pool) * 100.0)], 13, hud.UI.TEXT)
		name.custom_minimum_size.x = 190
		row.add_child(name)
		var p: String = pool
		hud._button(row, "-", func(): return a.set_alloc(p, -10.0), float(a.alloc[pool]) > 0.0).custom_minimum_size.x = 30
		hud._button(row, "+", func(): return a.set_alloc(p, 10.0), float(a.alloc[pool]) < 100.0).custom_minimum_size.x = 30
		var state: String = POOL_HELP[pool]
		if a.NEED.has(pool) and lvl > 0:
			state += ": %d%%" % roundi(a.power(0, pool) * 100.0)
		var help: Label = hud._text(state, 11, hud.UI.MUTED)
		help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(help)
	# The AI economy and the jobs it takes.
	if a.automation() > 0.0:
		var eco: VBoxContainer = hud._card()
		eco.add_child(hud._text("Automation: %d%% of jobs" % roundi(a.automation() * 100.0), 15, hud.UI.CREAM, true))
		if a.retraining:
			sp._wrap(eco, "The retraining programme finds people new trades: no unrest ($%.1f a second)." % a.retraining_cost(), 12, hud.UI.GOOD)
		else:
			sp._wrap(eco, "People put out of work by AI are unhappy: happiness -%d." % roundi(a.unrest()), 12, hud.UI.BAD)
		var r: HBoxContainer = hud._row(eco)
		hud._button(r, "End retraining" if a.retraining else "Start retraining ($%.1f/s)" % a.retraining_cost(), func(): return a.set_retraining(not a.retraining), true, "" if a.retraining else "good")

static func _doctrine(sp, a) -> void:
	var hud = sp.hud
	var lvl: int = a.level(0)
	var doc_card: VBoxContainer = hud._card(hud.UI.BAD if a.doctrine(0) == "out" else Color(0, 0, 0, 0))
	doc_card.add_child(hud._text("Autonomy doctrine", 15, hud.UI.CREAM, true))
	var drow: HBoxContainer = hud._row(doc_card, 4)
	for doc in a.DOCTRINES:
		var dd: String = doc
		var why: String = a.doctrine_blocked(doc)
		var b: Button = hud._button(drow, a.DOCTRINE_NAMES[doc].replace("Human ", ""), func(): return a.set_doctrine(dd), why == "" and a.doctrine(0) != doc, "bad" if doc == "out" else ("good" if a.doctrine(0) == doc else ""))
		b.tooltip_text = a.DOCTRINE_DESC[doc] + ("" if why == "" else "\n" + why)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp._wrap(doc_card, "%s: %s" % [a.DOCTRINE_NAMES[a.doctrine(0)], a.DOCTRINE_DESC[a.doctrine(0)]], 12)
	var rate_now: float = a.incident_rate(0)
	if rate_now > 0.0:
		sp._wrap(doc_card, "At war: about %d%% chance of an incident each minute. Incidents so far: %d." % [roundi(rate_now * 100.0), int(a.incidents.get(0, 0))], 12, hud.UI.BAD)
	if lvl >= 3 and a.doctrine(0) != "in":
		sp._wrap(doc_card, "Loitering munitions and interceptor drones choose their own targets.", 12, hud.UI.GOOD)
	if a.coordinated(0):
		sp._wrap(doc_card, "AI battle management: your batteries share targets and intercept %d%% more often." % roundi(a.bonuses().get("interceptPct", 0.0) * 100.0), 12, hud.UI.GOOD)
	if a.has_cca(0):
		sp._wrap(doc_card, "Collaborative Combat Aircraft: every fighter you train takes a loyal wingman.", 12, hud.UI.GOOD)
	var dc = hud.world.get("defcon")
	if dc != null and dc.nuclear(0):
		var ew: VBoxContainer = hud._card(hud.UI.BAD if a.early_warning.has(0) else Color(0, 0, 0, 0))
		ew.add_child(hud._text("Automated early warning: %s" % ("on" if a.early_warning.has(0) else "off"), 15, hud.UI.CREAM, true))
		sp._wrap(ew, "An AI watches for missile launches and readies the answer: rivals believe a launch on warning (a third less likely to strike you first) and interception +5%. It can report an attack that is not there: your alert rises, and the world's tension with it.", 12)
		if a.early_warning.has(0):
			sp._wrap(ew, "False alarms: about %d%% a minute while tension is 20 or more." % roundi(a.alarm_rate(0) * 100.0), 12, hud.UI.BAD)
		var why_e: String = a.warning_blocked()
		var eb: Button = hud._button(ew, "Return the watch to officers" if a.early_warning.has(0) else "Automate the early warning", func(): return a.set_early_warning(not a.early_warning.has(0)), a.early_warning.has(0) or why_e == "", "" if a.early_warning.has(0) else "bad")
		eb.tooltip_text = why_e
		if why_e != "" and not a.early_warning.has(0):
			sp._wrap(ew, why_e, 11, hud.UI.MUTED)
	var tr: VBoxContainer = hud._card()
	tr.add_child(hud._text("AI treaties", 15, hud.UI.CREAM, true))
	for t in a.TREATIES:
		var tt: String = t
		var row: HBoxContainer = hud._row(tr)
		var lab: Label = hud._text("%s  (%d signatories)" % [a.TREATIES[t].name, a.signatories(t).size()], 13, hud.UI.TEXT)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.tooltip_text = a.TREATIES[t].desc
		row.add_child(lab)
		if a.signatory(0, t):
			hud._button(row, "Withdraw", func(): return a.withdraw(tt), true, "bad")
		else:
			var why: String = a.sign_blocked(t)
			var sb: Button = hud._button(row, "Sign", func(): return a.sign(tt), why == "", "good")
			sb.tooltip_text = why
	sp._wrap(tr, "Signatories of the autonomous weapons treaty keep a human in or on the loop. Fighting without one costs standing with them.", 11)

static func _operations(sp, a) -> void:
	var hud = sp.hud
	var d: Node = hud.world.diplomacy
	var targets: Array = sp._targets(d)
	var cy: VBoxContainer = hud._card()
	hud._meter(cy, a.reserve(0), a.OPS_CAP, Color("5ab0e0"), "Operations reserve %d / %d compute" % [int(a.reserve(0)), int(a.OPS_CAP)])
	if targets.is_empty():
		return
	if not a.get("cyber_target") in targets:
		a.cyber_target = targets[0]
	var trow: HBoxContainer = hud._row(cy)
	trow.add_child(hud._text("Target", 13, hud.UI.MUTED))
	var items := []
	for id in targets: items.append([d.name_of(id), id])
	hud._choice(trow, items, a.cyber_target, func(v):
		a.cyber_target = int(v)
		hud.refresh_side())
	var t: int = a.cyber_target
	var acts := [
		["AI cyber campaign (%d each)" % int(a.CYBER_COST), a.cyber_blocked(t), func(): return a.launch_cyber(t),
			"AI agents break in without an officer: factories and construction stop for a minute or more. Reaches %d nation%s. It may be traced back to you." % [a.cyber_reach(0), "" if a.cyber_reach(0) == 1 else "s"]],
		["Synthetic influence (%d)" % int(a.INFLUENCE_COST), a.influence_blocked(t), func(): return a.influence(0, t),
			"Deepfake videos and voices turn its people against the war: its war support -8, stability -10. If traced to you: a scandal at home and abroad."],
		["Steal model weights ($%d)" % int(a.THEFT_COST.money), a.theft_blocked(t), func(): return a.steal(0, t),
			"Your agents and AI go after a stronger rival's model: your AI level closes half the gap. If exposed: -30 relations, and a chip-supply nation puts export controls on you."],
	]
	if a.can_control(0):
		acts.append(["Chip export controls", a.control_blocked(t), func(): return a.impose_controls(0, t),
			"Deny it advanced chips: its data centres run at half for 10 minutes, unless it smuggles some in. -15 relations."])
	if a.agi.has(t):
		acts.append(["Sabotage its AGI project (%d)" % int(a.SABOTAGE_COST), a.sabotage_blocked(t), func(): return a.sabotage(0, t),
			"Corrupt its training runs: 40% of its stage's work lost. If traced: -40 relations."])
	for act in acts:
		var row: HBoxContainer = hud._row(cy)
		var why: String = act[1]
		var b: Button = hud._button(row, act[0], act[2], why == "", "bad")
		b.custom_minimum_size.x = 230
		b.tooltip_text = (why + "\n" if why != "" else "") + act[3]
		var note: Label = hud._text(why if why != "" else "Ready.", 11, hud.UI.MUTED if why != "" else hud.UI.GOOD)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(note)
	sp._wrap(cy, "Your cyber defence stops about %d%% of rivals' AI intrusions." % roundi(clampf(0.2 + a.cyber_defence(0), 0.05, 0.85) * 100.0), 12)
	if a.controlled(0):
		var ch: VBoxContainer = hud._card(hud.UI.BAD)
		ch.add_child(hud._text("Export controls on you: %ds left" % ceili(float(a.controls[0].until) - hud.world.game_time), 15, hud.UI.CREAM, true))
		var why_s: String = a.smuggle_blocked()
		var sm: Button = hud._button(ch, "Smuggle chips in ($%d)" % int(a.SMUGGLE_COST), func(): return a.smuggle(), why_s == "")
		sm.tooltip_text = (why_s + "\n" if why_s != "" else "") + "Through third countries: data centres back to 80%. If found out, the controls run 5 minutes longer."

static func _agi(sp, a) -> void:
	var hud = sp.hud
	var d: Node = hud.world.diplomacy
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("The AGI project", 18, hud.UI.CREAM, true))
	var stage: int = a.agi_stage(0)
	if stage >= 3:
		sp._wrap(card, "General intelligence achieved.", 13, hud.UI.GOOD)
	elif not a.researched(0, "agiProject"):
		sp._wrap(card, "Research The AGI Project (after Frontier Models) to begin. Three stages paid in compute: %s; %s; %s" % [a.AGI_GAINS[0], a.AGI_GAINS[1].to_lower(), a.AGI_GAINS[2].to_lower()], 12)
	elif a.level(0) < 4:
		sp._wrap(card, "Your AI must reach level 4 first.", 12)
	else:
		var row: Dictionary = a.agi.get(0, {"progress": 0.0, "alignment": 0.0})
		hud._meter(card, float(row.progress), a.agi_cost(0), hud.UI.GOLD, "Stage %d of 3, %s: %d / %d compute" % [stage + 1, a.AGI_STAGES[stage][0], int(row.progress), int(a.agi_cost(0))])
		sp._wrap(card, "On completion: %s The Training runs share of compute feeds it." % a.AGI_GAINS[stage], 12)
		for i in range(stage):
			sp._wrap(card, "Achieved: %s. %s" % [a.AGI_STAGES[i][0], a.AGI_GAINS[i]], 11, hud.UI.GOOD)
	var safe: VBoxContainer = hud._card(hud.UI.BAD if a.runaway_rate(0) >= 0.03 else Color(0, 0, 0, 0))
	var srow: HBoxContainer = hud._row(safe, 6)
	var sl: Label = hud._text("Safety (alignment)  %d%%" % roundi(a.safety * 100.0), 14, hud.UI.CREAM)
	sl.custom_minimum_size.x = 210
	srow.add_child(sl)
	hud._button(srow, "-", func(): return a.set_safety(-0.1), a.safety > 0.0).custom_minimum_size.x = 30
	hud._button(srow, "+", func(): return a.set_safety(0.1), a.safety < 0.5).custom_minimum_size.x = 30
	sp._wrap(safe, "Compute given to safety slows the project. Too little, and the system may run out of control: the stage's work halved, drones frozen, intrusions everywhere, markets down, perhaps a pathogen. Risk now: about %d%% a minute." % roundi(a.runaway_rate(0) * 100.0), 12)
	var race: VBoxContainer = hud._card()
	race.add_child(hud._text("The race", 15, hud.UI.CREAM, true))
	var any := false
	for id in sp._targets(d):
		if not a.agi.has(id):
			continue
		any = true
		race.add_child(hud._text("%s: stage %d of 3%s" % [d.name_of(id), a.agi_stage(id), " (it lost control %d time%s)" % [int(a.runaways[id]), "" if int(a.runaways[id]) == 1 else "s"] if a.runaways.has(id) else ""], 12, hud._nation_colour(id).lightened(0.35)))
	if not any:
		race.add_child(hud._text("No rival has begun.", 12, hud.UI.MUTED))

static func _rivals(sp, a) -> void:
	var hud = sp.hud
	var d: Node = hud.world.diplomacy
	var rv: VBoxContainer = hud._card()
	rv.add_child(hud._text("Rivals' AI", 15, hud.UI.CREAM, true))
	var any := false
	for id in sp._targets(d):
		if a.level(id) <= 0:
			continue
		any = true
		var extra := ""
		if a.controlled(id): extra += ", under export controls"
		if a.signatory(id, "laws"): extra += ", bound by the treaty"
		rv.add_child(hud._text("%s: level %d, %s%s" % [d.name_of(id), a.level(id), a.DOCTRINE_NAMES[a.doctrine(id)].to_lower(), extra], 12, hud._nation_colour(id).lightened(0.35)))
	if not any:
		rv.add_child(hud._text("No rival fields AI yet.", 12, hud.UI.MUTED))
	var lg: VBoxContainer = hud._card()
	lg.add_child(hud._text("Recent", 15, hud.UI.CREAM, true))
	if a.log.is_empty():
		lg.add_child(hud._text("Nothing yet.", 12, hud.UI.MUTED))
	for entry in a.log.slice(0, 5):
		sp._wrap(lg, str(entry.text), 11)
