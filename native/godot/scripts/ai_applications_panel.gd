extends RefCounted
const Data := preload("res://scripts/ai_applications_data.gd")
const UseData := preload("res://scripts/ai_use_data.gd")
const Factions := preload("res://scripts/factions.gd")
const GROUPS := {"civil": ["administration", "agriculture", "industry", "health", "revenue"],
	"security": ["logistics", "sensors", "autonomy", "cyber", "targeting", "counterDrone", "undersea"],
	"state": ["diplomacy", "assurance", "science", "surveillance", "infoShield", "export"],
	"doomsday": ["strategic", "deadHand", "biosecurity"]}

static func draw(sp, a) -> void:
	var hud = sp.hud
	var apps = a.applications
	var info: Array = apps.country(0)
	var intro: VBoxContainer = hud._card(hud.UI.GOLD)
	intro.add_child(hud._text("AI applications: from research to service", 17, hud.UI.CREAM, true))
	sp._wrap(intro, "National evidence: %s. %s" % [info[0], info[1]], 12)
	sp._wrap(intro, "Research the application, validate it against local data, then commission it. Trials use half of Training runs compute. Working facilities, money and compute are needed throughout service. National priorities speed trials by 15%.", 12, hud.UI.MUTED)
	sp._tabs([["Civil economy", "civil"], ["Military", "security"], ["Politics & state", "state"], ["Doomsday", "doomsday"], ["Who uses what", "world"]], apps.category, func(v): apps.category = v)
	if apps.category == "world":
		_world(sp, a)
		return
	if apps.category == "doomsday":
		sp._wrap(intro, "Machines in the nuclear chain: a check on false warnings, a dead hand that answers when no one can, and the screening that stands between a model and a pathogen. Each is a choice between being believed and being safe.", 12, hud.UI.MUTED)
	var me: String = Factions.identity(hud.world, 0)
	for key in GROUPS.get(apps.category, GROUPS.civil):
		var k: String = key
		var p: Dictionary = Data.PROGRAMS[k]
		var r: Dictionary = apps.row(0, k)
		var card: VBoxContainer = hud._card()
		card.add_child(hud._text(str(p.name) + ("  / national priority" if k in info[2] else ""), 15, hud.UI.CREAM, true))
		sp._wrap(card, p.desc, 12)
		var record: Array = UseData.of(me, k)
		if str(record[0]) != "":
			sp._wrap(card, "Your nation: %s. %s" % [UseData.label(str(record[0])), str(record[1])], 11, hud.UI.CREAM if str(record[0]) == "fielded" else hud.UI.MUTED)
		var commissioned := bool(r.get("commissioned", false))
		var state := "Research required"
		if a.researched(0, p.research): state = "Ready for local validation"
		if float(r.work) > 0.0: state = "Local trials paused"
		if apps.projects.get(0, "") == k: state = "Engineering" if float(r.work) < float(p.work) * 0.5 else "Field trials"
		if bool(r.validated): state = "Validated; ready to commission"
		if commissioned: state = "Suspended"
		if bool(r.enabled): state = "Operating: %d%% coverage" % roundi(float(apps.coverage.get(0, {}).get(k, 0.0)) * 100.0)
		if bool(r.enabled) and int(r.get("gen", 1)) >= 2: state += ", second generation"
		sp._wrap(card, "%s | AI level %d | %s pool %.2f compute/s | $%.1f/s" % [state, int(p.level), a.POOL_NAMES[p.pool], float(p.demand), float(p.upkeep)], 11, hud.UI.GOLD)
		if not bool(r.validated) and (float(r.work) > 0.0 or apps.projects.get(0, "") == k):
			sp._wrap(card, "Local validation: %d / %d compute" % [int(r.work), int(p.work)], 11, hud.UI.CREAM)
			var progress := ProgressBar.new()
			progress.show_percentage = false
			progress.max_value = float(p.work)
			progress.value = float(r.work)
			progress.custom_minimum_size.y = 8
			card.add_child(progress)
		var buttons: HBoxContainer = hud._row(card)
		var why: String = ""
		if bool(r.enabled):
			why = apps.eligible(0, k)
			hud._button(buttons, "Suspend", func(): return apps.suspend(0, k), true)
		elif bool(r.validated):
			why = apps.commission_blocked(0, k)
			hud._button(buttons, "Resume" if commissioned else "Commission $%d" % roundi(apps.price(k, true)), func(): return apps.commission(0, k), why == "", "good")
		elif apps.projects.get(0, "") == k:
			why = apps.eligible(0, k)
			hud._button(buttons, "Pause trials", func(): return apps.pause(0), true)
		else:
			why = apps.start_blocked(0, k)
			hud._button(buttons, "Resume trials" if bool(r.get("paid", false)) else "Validate $%d" % roundi(apps.price(k, false)), func(): return apps.start(0, k), why == "", "good")
			if not a.researched(0, p.research):
				hud._button(buttons, "Open research", func(): return open_research(hud, str(p.research)), true)
		# The next stage: field experience, then the second generation.
		if bool(r.enabled) and int(r.get("gen", 1)) < 2:
			var need: float = apps.experience_needed(k)
			sp._wrap(card, "Field experience: %d%% toward the second generation" % int(100.0 * float(r.get("exp", 0.0)) / need), 11, hud.UI.CREAM)
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.max_value = need
			bar.value = float(r.get("exp", 0.0))
			bar.custom_minimum_size.y = 6
			card.add_child(bar)
			var up: String = apps.upgrade_blocked(0, k)
			hud._button(buttons, "Second generation $%d" % roundi(apps.upgrade_price(k)), func(): return apps.upgrade(0, k), up == "", "good").tooltip_text = up
		if why != "": sp._wrap(card, why, 11, hud.UI.MUTED)
		elif bool(r.enabled) and apps.factor(0, k) < 0.99:
			sp._wrap(card, "Coverage is limited by shared compute or running funds. Increase this pool's allocation, restore facilities or add compute.", 11, hud.UI.MUTED)
	if apps.category == "state":
		var sales: VBoxContainer = hud._card()
		sales.add_child(hud._text("AI exports", 15, hud.UI.CREAM, true))
		sp._wrap(sales, "Sell a package of compute, models and services to a nation at peace with you: $900 (more for a second-generation package), relations +10, its models train faster, and your engineers see part of its networks. One sale every 240 seconds.", 12)
		for target in sp._targets(hud.world.diplomacy):
			var t: int = target
			var why: String = apps.export_blocked(0, t)
			hud._button(sales, "Sell to " + hud.world.diplomacy.name_of(t), func(): return apps.export_to(0, t), why == "").tooltip_text = why
		var talks: VBoxContainer = hud._card()
		talks.add_child(hud._text("Diplomatic consultation", 15, hud.UI.CREAM, true))
		sp._wrap(talks, "$250 and 40 intelligence reserve; relations +8 at peace or +4 at war. One consultation every 180 seconds. Treaty and ceasefire decisions remain with governments.", 12)
		for target in sp._targets(hud.world.diplomacy):
			var t: int = target
			var why: String = apps.consultation_blocked(0, t)
			hud._button(talks, "Consult " + hud.world.diplomacy.name_of(t), func(): return apps.consult(0, t), why == "").tooltip_text = why

static func open_research(hud, key: String) -> String:
	if hud._rs == null or not hud._rs.visible: hud.toggle_research()
	hud._rs_sel = key
	hud._rs_sig = ""
	hud._refresh_research()
	return ""

## Who uses what: the public record for every nation in the match, and what each
## runs now (an intelligence picture: rivals' live programmes as the AI tab knows them).
static func _world(sp, a) -> void:
	var hud = sp.hud
	var w: Node = hud.world
	var apps = a.applications
	var d: Node = w.diplomacy
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("Who uses AI for what", 17, hud.UI.CREAM, true))
	sp._wrap(card, "The public record behind each nation, by domain: fielded, developing, barred by law or pledged against. A nation that already fields a use needs half the trials; one developing it, 80%. No public evidence is not proof of absence.", 12, hud.UI.MUTED)
	for i in range(d.n):
		if i > 0 and d.defeated(i): continue
		var id: String = Factions.identity(w, i)
		var row: VBoxContainer = hud._card()
		row.add_child(hud._text(("You: " if i == 0 else "") + d.name_of(i), 15, hud.UI.CREAM, true))
		var lines := []
		for status in ["fielded", "developing", "barred", "pledged"]:
			var names: Array = UseData.DOMAINS.filter(func(k): return UseData.status(id, k) == status).map(func(k): return UseData.DOMAIN_NAMES[k])
			if not names.is_empty(): lines.append("%s: %s" % [UseData.label(status), ", ".join(PackedStringArray(names))])
		sp._wrap(row, "
".join(PackedStringArray(lines)) if not lines.is_empty() else "No public evidence of military, political or strategic AI use.", 12)
		var live: Array = []
		for key in apps.rows.get(i, {}):
			if apps.factor(i, key) > 0.0: live.append(str(apps.Data.PROGRAMS[key].name) + (" (2nd gen)" if int(apps.rows[i][key].get("gen", 1)) >= 2 else ""))
		if not live.is_empty():
			sp._wrap(row, "In service now: " + ", ".join(PackedStringArray(live)), 11, hud.UI.GOLD)
		# The weightiest uses first: the doomsday chain, targeting, control of the people.
		var notable: Array = ["deadHand", "targeting", "surveillance", "influence", "undersea", "export", "counterDrone", "infoShield", "revenue", "biosecurity"].filter(func(k): return UseData.status(id, k) in ["fielded", "barred"])
		for k in notable.slice(0, 3):
			sp._wrap(row, "%s: %s" % [UseData.DOMAIN_NAMES[k], str(UseData.of(id, k)[1])], 11, hud.UI.MUTED)
