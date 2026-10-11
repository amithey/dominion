extends RefCounted
const Data := preload("res://scripts/ai_applications_data.gd")
const GROUPS := {"civil": ["administration", "agriculture", "industry", "health"], "security": ["logistics", "sensors", "autonomy", "cyber"], "state": ["diplomacy", "assurance", "strategic", "science"]}

static func draw(sp, a) -> void:
	var hud = sp.hud
	var apps = a.applications
	var info: Array = apps.country(0)
	var intro: VBoxContainer = hud._card(hud.UI.GOLD)
	intro.add_child(hud._text("AI applications: from research to service", 17, hud.UI.CREAM, true))
	sp._wrap(intro, "National evidence: %s. %s" % [info[0], info[1]], 12)
	sp._wrap(intro, "Research the application, validate it against local data, then commission it. Trials use half of Training runs compute. Working facilities, money and compute are needed throughout service. National priorities speed trials by 15%.", 12, hud.UI.MUTED)
	sp._tabs([["Civil economy", "civil"], ["Military & security", "security"], ["State & strategic", "state"]], apps.category, func(v): apps.category = v)
	for key in GROUPS.get(apps.category, GROUPS.civil):
		var k: String = key
		var p: Dictionary = Data.PROGRAMS[k]
		var r: Dictionary = apps.row(0, k)
		var card: VBoxContainer = hud._card()
		card.add_child(hud._text(str(p.name) + ("  / national priority" if k in info[2] else ""), 15, hud.UI.CREAM, true))
		sp._wrap(card, p.desc, 12)
		var commissioned := bool(r.get("commissioned", false))
		var state := "Research required"
		if a.researched(0, p.research): state = "Ready for local validation"
		if float(r.work) > 0.0: state = "Local trials paused"
		if apps.projects.get(0, "") == k: state = "Engineering" if float(r.work) < float(p.work) * 0.5 else "Field trials"
		if bool(r.validated): state = "Validated; ready to commission"
		if commissioned: state = "Suspended"
		if bool(r.enabled): state = "Operating: %d%% coverage" % roundi(apps.factor(0, k) * 100.0)
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
		if why != "": sp._wrap(card, why, 11, hud.UI.MUTED)
		elif bool(r.enabled) and apps.factor(0, k) < 0.99:
			sp._wrap(card, "Coverage is limited by shared compute or running funds. Increase this pool's allocation, restore facilities or add compute.", 11, hud.UI.MUTED)
	if apps.category == "state":
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
