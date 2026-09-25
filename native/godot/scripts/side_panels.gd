extends RefCounted
## The Diplomacy and Intelligence windows (hud.gd side window), redesigned.
## Each window has tabs along its top so nothing needs long scrolling:
##
## Diplomacy
##   Nations    one compact card per nation: the leader's portrait, name and
##              title, status tags, a relation gauge, whom they fight and whom
##              they stand with, and the actions (contact, declare war, call
##              an ally to war).
##   World map  a chart of every nation against every other: war, alliance,
##              trade pact, non-aggression, or plain relations by colour.
##   Orders     the cabinet's standing orders for strikes short of war.
##
## Intelligence
##   Operations pick the target nation from coloured tabs, then an operation
##              from a list grouped by kind (each with cost and odds); the
##              chosen one opens in a briefing card with the Authorize button.
##   Agents     the service's agents and the missions under way.
##   Dossiers   what the service knows of each nation.
##   Reports    the latest reports.
##
## Gameplay calls are unchanged (diplomacy.gd, espionage.gd, engagement.gd);
## this only lays them out. Widgets come from hud.gd (_card, _row, _text,
## _button, _pill, _meter, _segments...).

const Gallery := preload("res://scripts/leader_gallery.gd")
const WAR := Color("e0574a")
const ALLY := Color("6fc46a")
const PACT := Color("d8b866")
const NAP := Color("6fa6d8")
const OP_GROUPS := [
	["Intelligence", ["openSources", "buildNetwork", "reconDossier", "counterSweep", "withdrawNetwork"]],
	["Economic warfare", ["stealFunds", "stealTech", "cyberAttack", "shipping"]],
	["Sabotage and subversion", ["sabotage", "influence", "proxyCell", "armRebels", "falseFlag"]],
	["Leadership", ["assassinate"]],
]

var hud: Node
var diplomacy_tab := "nations"
var intel_tab := "operations"

func _init(owner: Node) -> void:
	hud = owner

## A row of tabs along the top of the window.
func _tabs(items: Array, selected: String, on_pick: Callable) -> void:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 3)
	hud._side_rows.add_child(holder)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.toggle_mode = true
		b.button_pressed = item[1] == selected
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 32
		b.add_theme_font_size_override("font_size", 14)
		var value: String = item[1]
		b.pressed.connect(func():
			on_pick.call(value)
			hud.refresh_side())
		holder.add_child(b)

# ---------------------------------------------------------------- diplomacy

func diplomacy() -> void:
	var d: Node = hud.world.diplomacy
	var wars := 0
	for id in range(1, d.n):
		if not d.defeated(id) and d.at_war(0, id):
			wars += 1
	_tabs([["Nations", "nations"], ["World map", "world"], ["Orders", "orders"]], diplomacy_tab, func(v): diplomacy_tab = v)
	match diplomacy_tab:
		"world":
			_world_chart()
		"orders":
			hud._standing_orders()
		_:
			var line := "%d nations · %s" % [d.n - 1, ("at war with %d" % wars) if wars > 0 else "at peace with all"]
			hud._side_rows.add_child(hud._text(line, 13, hud.UI.MUTED))
			for id in range(1, d.n):
				_nation_card(id)

func _portrait(id: int, size: float) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", hud.UI.box(Color("0b1620"), hud._nation_colour(id), 2, 2, 6.0))
	frame.custom_minimum_size = Vector2(size, size)
	var leader: String = hud.world.espionage.person(id, "president")
	var path := Gallery.portrait(leader)
	if path != "":
		var pic := TextureRect.new()
		pic.texture = load(path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(size - 6, size - 6)
		frame.add_child(pic)
	else:
		var initial: Label = hud._text(hud.world.diplomacy.name_of(id).substr(0, 1), int(size * 0.45), hud._nation_colour(id).lightened(0.4), true)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(initial)
	frame.tooltip_text = leader
	return frame

func _nation_card(id: int) -> void:
	var d: Node = hud.world.diplomacy
	var card: VBoxContainer = hud._card(hud._nation_colour(id))
	var top: HBoxContainer = hud._row(card, 12)
	top.add_child(_portrait(id, 74))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var head: HBoxContainer = hud._row(info, 6)
	var name: Label = hud._text(d.name_of(id), 18, hud._nation_colour(id).lightened(0.4), true)
	name.add_theme_font_size_override("font_size", 18)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if d.defeated(id):
		hud._pill(head, "DEFEATED", hud.UI.MUTED)
		return
	if d.at_war(0, id):
		hud._pill(head, "AT WAR", WAR)
	if d.allied(0, id):
		hud._pill(head, "ALLY", ALLY)
	if d.pact[0][id]:
		hud._pill(head, "TRADE", PACT)
	if d.nap[0][id]:
		hud._pill(head, "NON-AGGRESSION", NAP)
	if not (d.at_war(0, id) or d.allied(0, id) or d.pact[0][id] or d.nap[0][id]):
		hud._pill(head, "PEACE", Color("9aa7ab"))
	info.add_child(hud._text(hud.world.espionage.person(id, "president"), 13, hud.UI.MUTED))
	var score: float = d.rel(0, id)
	var colour := Color("c0564a").lerp(Color("8a9396"), clampf((score + 100.0) / 100.0, 0.0, 1.0)) if score < 0.0 else Color("8a9396").lerp(Color("5fae63"), clampf(score / 100.0, 0.0, 1.0))
	hud._meter(info, score + 100.0, 200.0, colour, "%+d  ·  %s" % [int(score), hud._relation_word(score)])
	# Whom they fight and whom they stand with, among the other nations.
	var fights := PackedStringArray()
	var friends := PackedStringArray()
	for other in range(1, d.n):
		if other == id or d.defeated(other):
			continue
		if d.at_war(id, other):
			fights.append(d.name_of(other))
		elif d.allied(id, other):
			friends.append(d.name_of(other))
	var ties := PackedStringArray()
	if not fights.is_empty():
		ties.append("At war with " + ", ".join(fights))
	if not friends.is_empty():
		ties.append("Allied with " + ", ".join(friends))
	if not ties.is_empty():
		card.add_child(hud._text("   ·   ".join(ties), 13, hud.UI.TEXT))
	var actions: HBoxContainer = hud._row(card, 6)
	var contact: Button = hud._button(actions, "Contact", hud.open_diplomatic_contact.bind(id), true, "good")
	contact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contact.tooltip_text = "Open a channel to this government: proposals, firm language, trade."
	if not d.at_war(0, id):
		hud._button(actions, "Declare war", hud._declare.bind(id), true, "bad")
	if d.allied(0, id):
		for enemy in range(1, d.n):
			if d.at_war(0, enemy) and not d.at_war(id, enemy):
				hud._button(card, "Call them to war against %s" % d.name_of(enemy), d.request_joint_war.bind(id, enemy))

## Every nation against every other, you included: one square per pair.
func _world_chart() -> void:
	var d: Node = hud.world.diplomacy
	var card: VBoxContainer = hud._card()
	card.add_child(hud._text("Who stands where", 16, hud.UI.CREAM, true))
	var ids: Array = range(0, d.n).filter(func(i): return not d.defeated(i))
	var cell := 44.0
	var label_w := 150.0
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(label_w + cell * ids.size() + 4, 30 + cell * ids.size() + 4)
	card.add_child(chart)
	var font: Font = hud.UI.font(500)
	chart.draw.connect(func():
		for r in range(ids.size()):
			var a: int = ids[r]
			var who: String = "You" if a == 0 else d.name_of(a)
			chart.draw_string(font, Vector2(0, 30 + cell * r + cell * 0.62), who, HORIZONTAL_ALIGNMENT_LEFT, label_w - 8, 14, hud._nation_colour(a).lightened(0.35))
			for c in range(ids.size()):
				var b: int = ids[c]
				var box := Rect2(label_w + cell * c + 2, 30 + cell * r + 2, cell - 4, cell - 4)
				if r == 0:
					chart.draw_rect(Rect2(label_w + cell * c + 2, 4, cell - 4, 20), hud._nation_colour(b))
				if a == b:
					chart.draw_rect(box, Color("0b1620"))
					continue
				var fill: Color
				var mark := ""
				if d.at_war(a, b):
					fill = WAR
					mark = "W"
				elif d.allied(a, b):
					fill = ALLY
					mark = "A"
				elif d.pact[a][b]:
					fill = PACT
					mark = "T"
				elif d.nap[a][b]:
					fill = NAP
					mark = "N"
				else:
					var s: float = d.rel(a, b)
					fill = Color("8a9396").lerp(Color("c0564a") if s < 0.0 else Color("5fae63"), clampf(absf(s) / 100.0, 0.0, 1.0) * 0.8)
					fill = fill.darkened(0.35)
				chart.draw_rect(box, fill)
				chart.draw_rect(box, Color(0, 0, 0, 0.5), false, 1.0)
				if mark != "":
					chart.draw_string(font, box.position + Vector2(0, cell * 0.64), mark, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, Color(0.05, 0.08, 0.1)))
	var legend: HBoxContainer = hud._row(card, 8)
	hud._pill(legend, "W  war", WAR)
	hud._pill(legend, "A  alliance", ALLY)
	hud._pill(legend, "T  trade pact", PACT)
	hud._pill(legend, "N  non-aggression", NAP)
	card.add_child(hud._text("Other squares: relations, from red (hostile) through grey to green (friendly).", 12, hud.UI.MUTED))

# ---------------------------------------------------------------- intelligence

func intel() -> void:
	var e: Node = hud.world.espionage
	var d: Node = hud.world.diplomacy
	hud._intel_progress.clear()
	var ready: int = e.ready_agents().size()
	var busy: int = e.missions.size()
	_tabs([["Operations", "operations"], ["Agents (%d)" % e.agents.size(), "agents"], ["Dossiers", "dossiers"], ["Reports", "reports"]], intel_tab, func(v): intel_tab = v)
	var status := PackedStringArray(["%d ready" % ready, "%d on missions" % busy])
	if e.security_until > e.clock:
		status.append("security review %ds" % ceili(e.security_until - e.clock))
	if e.scandal_until > e.clock:
		status.append("scandal $2/s for %ds" % ceili(e.scandal_until - e.clock))
	hud._side_rows.add_child(hud._text("  ·  ".join(status), 13, hud.UI.MUTED))
	if not e.has_agency():
		hud._side_rows.add_child(hud._text("Build an Intelligence Agency (Civic & research) to recruit agents. Rival services already work against you.", 13, hud.UI.BAD))
	match intel_tab:
		"agents":
			_agents(e, d)
		"dossiers":
			_dossiers(e, d)
		"reports":
			_reports(e)
		_:
			_operations(e, d)

func _targets(d: Node) -> Array:
	var out := []
	for i in range(1, d.n):
		if not d.defeated(i):
			out.append(i)
	return out

func _operations(e: Node, d: Node) -> void:
	var nations := _targets(d)
	if nations.is_empty():
		return
	if not hud.spy_target in nations:
		hud.spy_target = nations[0]
	# The target: one tab per nation in its colour, with the network there.
	var pick: HBoxContainer = hud._row(hud._side_rows, 4)
	for id in nations:
		var b := Button.new()
		b.text = "%s  %d" % [d.name_of(id), int(e.network.get(id, 0.0))]
		b.tooltip_text = "Network %d · intelligence %d · heat %d" % [int(e.network.get(id, 0.0)), int(e.intel.get(id, 0.0)), int(e.heat.get(id, 0.0))]
		b.toggle_mode = true
		b.button_pressed = id == hud.spy_target
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", hud._nation_colour(id).lightened(0.35))
		b.add_theme_color_override("font_pressed_color", hud._nation_colour(id).lightened(0.6))
		var target: int = id
		b.pressed.connect(func():
			hud.spy_target = target
			hud.refresh_side())
		pick.add_child(b)
	var agent_bonus := 0.0
	if not e.ready_agents().is_empty():
		agent_bonus = (int(e.ready_agents()[0].skill) - 1) * float(e.cfg.skillBonus)
	# The chosen operation's briefing.
	var ops: Dictionary = e.ops()
	if not ops.has(hud.spy_op):
		hud.spy_op = ops.keys()[0]
	var op: Dictionary = ops[hud.spy_op]
	var needs_person: bool = op.get("needsPerson", false)
	var brief: VBoxContainer = hud._card(hud._nation_colour(hud.spy_target))
	var bh: HBoxContainer = hud._row(brief)
	var title: Label = hud._text("%s  →  %s" % [op.name, d.name_of(hud.spy_target)], 17, hud.UI.CREAM, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(title)
	var chance := clampf(e.success_chance(hud.spy_op, hud.spy_target) + agent_bonus, 0.05, 0.97)
	hud._meter(brief, chance, 1.0, hud.UI.GOLD, "Success %d%%   ·   exposure risk %d%%" % [roundi(chance * 100), roundi(e.exposure_chance(hud.spy_op, hud.spy_target) * 100)])
	var detail: Label = hud._text(op.desc, 13, hud.UI.TEXT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 460
	brief.add_child(detail)
	if needs_person:
		var people := []
		for role in e.cfg.targets:
			people.append(["%s: %s" % [e.cfg.targets[role].label, e.person(hud.spy_target, role)], role])
		var pr: HBoxContainer = hud._row(brief)
		pr.add_child(hud._text("Target", 14, hud.UI.MUTED))
		hud._choice(pr, people, hud.spy_role, func(v):
			hud.spy_role = v
			hud.refresh_side())
		brief.add_child(hud._text(e.role_effect(hud.spy_role), 12, hud.UI.MUTED))
	brief.add_child(hud._text("$%d  ·  prepare %ds  ·  cooldown %ds  ·  needs intel %d" % [int(op.cost), e.PROGRAMS[hud.spy_op][0], e.PROGRAMS[hud.spy_op][1], e.PROGRAMS[hud.spy_op][3]], 13, hud.GOLD))
	var reason: String = e.blocked_reason(hud.spy_op, hud.spy_target, hud.spy_role if needs_person else "")
	if reason != "":
		brief.add_child(hud._text(reason, 13, hud.UI.BAD))
	var go: Button = hud._button(brief, "Authorize operation", func(): return e.run(hud.spy_op, hud.spy_target, hud.spy_role if needs_person else ""), reason == "", "good")
	go.custom_minimum_size.y = 36
	# Every operation, grouped, with its cost and odds against this target.
	var listed := {}
	for group in OP_GROUPS:
		var keys: Array = group[1].filter(func(k): return ops.has(k))
		if keys.is_empty():
			continue
		hud._heading(group[0])
		for key in keys:
			listed[key] = true
			_op_row(e, key, agent_bonus)
	var rest: Array = ops.keys().filter(func(k): return not listed.has(k))
	if not rest.is_empty():
		hud._heading("Other")
		for key in rest:
			_op_row(e, key, agent_bonus)

func _op_row(e: Node, key: String, agent_bonus: float) -> void:
	var op: Dictionary = e.ops()[key]
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.toggle_mode = true
	b.button_pressed = key == hud.spy_op
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.tooltip_text = op.desc
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var why: String = e.blocked_reason(key, hud.spy_target, hud.spy_role)
	var name: Label = hud._text(op.name, 14, hud.UI.CREAM if why == "" else hud.UI.MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var chance := clampf(e.success_chance(key, hud.spy_target) + agent_bonus, 0.05, 0.97)
	var odds: Label = hud._text("%d%%" % roundi(chance * 100), 13, Color("8fd18a") if chance >= 0.6 else (hud.GOLD if chance >= 0.35 else Color("e8836f")))
	odds.custom_minimum_size.x = 44
	odds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(odds)
	var cost: Label = hud._text("$%d" % int(op.cost), 13, hud.GOLD)
	cost.custom_minimum_size.x = 56
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cost)
	b.pressed.connect(func():
		hud.spy_op = key
		hud.refresh_side())
	hud._side_rows.add_child(b)

func _agents(e: Node, d: Node) -> void:
	var service: VBoxContainer = hud._card()
	var head: HBoxContainer = hud._row(service)
	var st: Label = hud._text("Field agents", 16, hud.UI.CREAM, true)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(st)
	hud._button(head, "Recruit ($%d)" % e.recruit_cost(), e.recruit, e.has_agency(), "good")
	if e.agents.is_empty():
		service.add_child(hud._text("No agents yet.", 13, hud.UI.MUTED))
	for a in e.agents:
		var row: HBoxContainer = hud._row(service, 8)
		var badge: Label = hud._text(str(a.name).substr(0, 1), 16, hud.GOLD, true)
		badge.custom_minimum_size = Vector2(26, 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(badge)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(hud._text("%s   %s" % [a.name, "★".repeat(int(a.skill)) + "☆".repeat(5 - int(a.skill))], 14, hud.UI.CREAM))
		col.add_child(hud._text("%s  ·  %d operations" % [e.rank(a), a.ops], 12, hud.UI.MUTED))
		if a.status == "captured":
			hud._pill(row, "CAPTURED by %s" % d.name_of(int(a.captured_by)), WAR)
			hud._button(row, "Ransom $%d" % int(e.cfg.ransom), e.ransom.bind(a.id))
		elif a.status == "ready":
			hud._pill(row, "READY", ALLY)
		else:
			hud._pill(row, ("RECOVERY %ds" % ceili(float(a.get("ready_at", e.clock)) - e.clock)) if a.status == "recovering" else str(a.status).to_upper(), hud.GOLD)
	if not e.missions.is_empty():
		hud._heading("Missions under way")
	for mission in e.missions:
		var card: VBoxContainer = hud._card(hud._nation_colour(int(mission.nation)))
		var remaining := maxi(0, ceili(float(mission.ends) - e.clock))
		var duration: float = float(mission.ends) - float(mission.started)
		var progress := 1.0 - float(remaining) / duration
		var title: String = "%s · %s" % [e.ops()[mission.op].name, d.name_of(int(mission.nation))]
		var meter: Control = hud._meter(card, progress, 1.0, hud.UI.GOLD, "%s · %ds" % [title, remaining])
		hud._intel_progress.append({"bar": meter.get_child(0), "label": meter.get_child(1), "ends": mission.ends, "duration": duration, "title": title})
		hud._button(card, "Recall the agent", e.cancel_mission.bind(int(mission.agent)), true, "bad")
	for nation in e.proxies:
		var proxy: Dictionary = e.proxies[nation]
		var card: VBoxContainer = hud._card(hud._nation_colour(int(nation)))
		card.add_child(hud._text("Local partner in %s: strength %d · autonomy %d · $3/s" % [d.name_of(int(nation)), proxy.strength, proxy.autonomy], 13, hud.GOLD))
		hud._button(card, "End partner funding", e.end_proxy.bind(int(nation)), true, "bad")

func _dossiers(e: Node, d: Node) -> void:
	for id in _targets(d):
		var level: float = e.intel.get(id, 0.0)
		var card: VBoxContainer = hud._card(hud._nation_colour(id))
		var top: HBoxContainer = hud._row(card, 12)
		top.add_child(_portrait(id, 56))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(col)
		col.add_child(hud._text(d.name_of(id), 16, hud._nation_colour(id).lightened(0.4), true))
		hud._meter(col, level, 100.0, Color("6fa6d8"), "Intelligence %d  ·  network %d  ·  heat %d" % [int(level), int(e.network.get(id, 0.0)), int(e.heat.get(id, 0.0))])
		var tiers := PackedStringArray()
		for t in e.INTEL_TIERS:
			tiers.append(("✓ " if level >= float(t[0]) else "· ") + str(t[1]))
		card.add_child(hud._text("   ".join(tiers), 11, hud.UI.MUTED))
		var assessment: Label = hud._text(e.dossier_text(id), 13, hud.UI.TEXT)
		assessment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		assessment.custom_minimum_size.x = 460
		card.add_child(assessment)
		var impact: String = e.impact_text(id)
		if impact != "":
			card.add_child(hud._text(impact, 13, hud.GOLD))

func _reports(e: Node) -> void:
	if e.reports.is_empty():
		hud._side_rows.add_child(hud._text("No reports yet.", 13, hud.UI.MUTED))
		return
	for r in e.reports.slice(0, 12):
		var card: VBoxContainer = hud._card(hud._nation_colour(int(r.get("nation", 0))) if int(r.get("nation", 0)) > 0 else Color(0, 0, 0, 0))
		var head: HBoxContainer = hud._row(card)
		var when: Label = hud._text("%ds ago" % maxi(0, int(e.clock - float(r.t))), 12, hud.UI.MUTED)
		head.add_child(when)
		var text: Label = hud._text(str(r.text), 13, hud.UI.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 460
		card.add_child(text)
