extends RefCounted
## The AI tab of the Defence window (ai_directorate.gd): the AI level and the
## training run, compute and how it is split, the autonomy doctrine, AI cyber
## campaigns and what rivals' AI is doing. Kept compact: four small cards.

const POOL_HELP := {
	"military": "Autonomy, autonomous seekers and the fusion cell",
	"economy": "Research and income",
	"intel": "Operations reserve and cyber defence",
	"frontier": "Training runs: the next AI level",
}

static func draw(sp) -> void:
	var hud = sp.hud
	var a = hud.world.get("directorate")
	if a == null:
		return
	var d: Node = hud.world.diplomacy
	var lvl: int = a.level(0)
	# The level and the training run.
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("AI level %d: %s" % [lvl, a.LEVEL_NAMES[lvl]], 18, hud.UI.CREAM, true))
	var cap: int = a.cap(0)
	if lvl < 5 and lvl < cap:
		hud._meter(card, float(a.st[0].train), a.next_cost(0), hud.UI.GOLD, "Training run to level %d: %d / %d compute" % [lvl + 1, int(a.st[0].train), int(a.next_cost(0))])
	else:
		var next := {0: "Machine Learning", 2: "Military AI", 3: "Frontier Models"}
		sp._wrap(card, "Research %s to train further." % next.get(cap, "further") if lvl < 4 else "Your models are at the frontier.", 12)
	var dc: int = a.data_centres(0)
	var rate: float = float(a.st[0].rate)
	var src := "%d data centre%s" % [dc, "" if dc == 1 else "s"]
	if a.researched(0, "machineLearning"):
		src += ", national industry +%.1f/s" % (a.AIData.rating(hud.world, 0, "compute") * a.NATIONAL)
	card.add_child(hud._text("Compute %.1f/s  (%s)" % [rate, src], 13, hud.UI.TEXT))
	if rate <= 0.0:
		sp._wrap(card, "No compute yet: research Machine Learning and build an AI Data Center.", 12)
	# The split.
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
	# The doctrine.
	var doc_card: VBoxContainer = hud._card(hud.UI.BAD if a.doctrine(0) == "out" else Color(0, 0, 0, 0))
	doc_card.add_child(hud._text("Autonomy doctrine", 15, hud.UI.CREAM, true))
	var drow: HBoxContainer = hud._row(doc_card, 4)
	for doc in a.DOCTRINES:
		var dd: String = doc
		var why: String = a.doctrine_blocked(doc)
		var b: Button = hud._button(drow, a.DOCTRINE_NAMES[doc].replace("Human ", ""), func(): return a.set_doctrine(dd), why == "" and a.doctrine(0) != doc, "bad" if doc == "out" else ("good" if a.doctrine(0) == doc else ""))
		b.toggle_mode = false
		b.tooltip_text = a.DOCTRINE_DESC[doc] + ("" if why == "" else "\n" + why)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp._wrap(doc_card, "%s: %s" % [a.DOCTRINE_NAMES[a.doctrine(0)], a.DOCTRINE_DESC[a.doctrine(0)]], 12)
	var rate_now: float = a.incident_rate(0)
	if rate_now > 0.0:
		sp._wrap(doc_card, "At war: about %d%% chance of an incident each minute. Incidents so far: %d." % [roundi(rate_now * 100.0), int(a.incidents.get(0, 0))], 12, hud.UI.BAD)
	if lvl >= 3 and a.doctrine(0) != "in":
		sp._wrap(doc_card, "Loitering munitions and interceptor drones choose their own targets.", 12, hud.UI.GOOD)
	# AI cyber campaigns.
	var cy: VBoxContainer = hud._card()
	cy.add_child(hud._text("AI cyber campaign", 15, hud.UI.CREAM, true))
	hud._meter(cy, a.reserve(0), a.OPS_CAP, Color("5ab0e0"), "Operations reserve %d / %d" % [int(a.reserve(0)), int(a.OPS_CAP)])
	var targets: Array = sp._targets(d)
	if not targets.is_empty():
		if not a.get("cyber_target") in targets:
			a.cyber_target = targets[0]
		var crow: HBoxContainer = hud._row(cy)
		var items := []
		for id in targets: items.append([d.name_of(id), id])
		hud._choice(crow, items, a.cyber_target, func(v):
			a.cyber_target = int(v)
			hud.refresh_side())
		var why_c: String = a.cyber_blocked(a.cyber_target)
		var cb: Button = hud._button(crow, "Launch (%d compute each)" % int(a.CYBER_COST), func(): return a.launch_cyber(a.cyber_target), why_c == "", "bad")
		cb.tooltip_text = (why_c + "\n" if why_c != "" else "") + "AI agents break in without an officer: factories and construction stop for a minute or more. Reaches %d nation%s (your target, then others hostile to you). It may be traced back to you." % [a.cyber_reach(0), "" if a.cyber_reach(0) == 1 else "s"]
		if why_c != "":
			sp._wrap(cy, why_c, 12)
	sp._wrap(cy, "Your cyber defence stops about %d%% of rivals' AI intrusions." % roundi(clampf(0.2 + a.cyber_defence(0), 0.05, 0.85) * 100.0), 12)
	# Rivals, and what happened.
	var rv: VBoxContainer = hud._card()
	rv.add_child(hud._text("Rivals' AI", 15, hud.UI.CREAM, true))
	for id in targets:
		if a.level(id) <= 0:
			continue
		rv.add_child(hud._text("%s: level %d, %s" % [d.name_of(id), a.level(id), a.DOCTRINE_NAMES[a.doctrine(id)].to_lower()], 12, hud._nation_colour(id).lightened(0.35)))
	if targets.all(func(id): return a.level(id) <= 0):
		rv.add_child(hud._text("No rival fields AI yet.", 12, hud.UI.MUTED))
	for entry in a.log.slice(0, 3):
		sp._wrap(rv, "%s" % entry.text, 11)
