extends RefCounted
## The side windows (hud.gd): Diplomacy, Intelligence, World market and
## Territory, redesigned.
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

# ---------------------------------------------------------------- world market
## World market tabs: Exchange (the selected commodity's chart and the deal
## desk over a list of every commodity) and Trade routes (the fleet, each
## route with its voyage, and a form for a new one).

var market_tab := "exchange"
var market_res := "oil"
const UP := Color("8fd18a")
const DOWN := Color("e8836f")

func market() -> void:
	var m: Node = hud.world.market
	_tabs([["Exchange", "exchange"], ["Trade routes (%d/%d)" % [m.routes.size(), m.route_cap()], "routes"]], market_tab, func(v): market_tab = v)
	if market_tab == "routes":
		_routes(m)
	else:
		_exchange(m)

func _trend(m: Node, res: String) -> Color:
	var moved: float = m.change(res, 60.0)
	return UP if moved > 0.01 else (DOWN if moved < -0.01 else hud.UI.MUTED)

## A price chart: the line, a soft fill under it, and the first price dotted.
func _chart(points: Array, colour: Color, size: Vector2) -> Control:
	var chart := Control.new()
	chart.custom_minimum_size = size
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var values: Array = points.slice(maxi(0, points.size() - 90))
	chart.draw.connect(func():
		var w := size.x
		var h := size.y
		if values.size() < 2:
			chart.draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(colour, 0.5), 1.0)
			return
		var lo := INF
		var hi := -INF
		for v in values:
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		var span := maxf(hi - lo, 0.02)
		var line := PackedVector2Array()
		for i in range(values.size()):
			line.append(Vector2(w * i / (values.size() - 1), h - 3.0 - (h - 6.0) * (float(values[i]) - lo) / span))
		var fill := PackedVector2Array(line)
		fill.append(Vector2(w, h))
		fill.append(Vector2(0, h))
		chart.draw_colored_polygon(fill, Color(colour, 0.14))
		var start_y: float = line[0].y
		for x in range(0, int(w), 8):
			chart.draw_line(Vector2(x, start_y), Vector2(x + 4, start_y), Color(1, 1, 1, 0.18), 1.0)
		chart.draw_polyline(line, colour, 2.0, true)
		chart.draw_circle(line[line.size() - 1], 3.0, colour))
	return chart

func _exchange(m: Node) -> void:
	var eco: Node = hud.world.economy
	if not m.resources().has(market_res):
		market_res = m.resources()[0]
	var res: String = market_res
	if not m.has_market():
		hud._side_rows.add_child(hud._text("Build a Market to trade on the exchange. Prices still move with the world's trade.", 13, hud.UI.BAD))
	# The desk: the selected commodity.
	var desk: VBoxContainer = hud._card(_trend(m, res))
	var head: HBoxContainer = hud._row(desk, 10)
	head.add_child(hud._icon(res, 34))
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_col)
	title_col.add_child(hud._text(res.capitalize(), 18, hud.UI.CREAM, true))
	var cap: float = float(eco.caps.get(res, INF))
	title_col.add_child(hud._text("You hold %d%s" % [int(eco.res.get(res, 0.0)), (" of %d" % int(cap)) if cap < INF else ""], 12, hud.UI.MUTED))
	var price_col := VBoxContainer.new()
	price_col.add_theme_constant_override("separation", 0)
	head.add_child(price_col)
	var big: Label = hud._text("$%.2f" % m.price(res), 22, hud.UI.CREAM, true)
	big.add_theme_font_size_override("font_size", 22)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_col.add_child(big)
	var moved: float = m.change(res, 60.0)
	var longer: float = m.change(res, 180.0)
	var mv: Label = hud._text("%s %.1f%% in 1 min   %s %.1f%% in 3 min" % ["▲" if moved >= 0 else "▼", absf(moved) * 100, "▲" if longer >= 0 else "▼", absf(longer) * 100], 12, _trend(m, res))
	mv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_col.add_child(mv)
	desk.add_child(_chart(m.history.get(res, []), _trend(m, res), Vector2(480, 72)))
	var qty_row: HBoxContainer = hud._row(desk, 8)
	qty_row.add_child(hud._text("Quantity", 13, hud.UI.MUTED))
	hud._segments(qty_row, m.cfg.qty.map(func(q): return [str(int(q)), int(q)]), hud.trade_qty, func(v): hud.trade_qty = v)
	var q: int = hud.trade_qty
	var sell_v := floori(m.quote(res, q, false))
	var buy_v := ceili(m.quote(res, q, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_row.add_child(spacer)
	qty_row.add_child(hud._text("$%.2f / $%.2f a unit" % [float(sell_v) / q, float(buy_v) / q], 12, hud.UI.MUTED))
	var deal: HBoxContainer = hud._row(desk, 8)
	var sell: Button = hud._button(deal, "Sell %d  +$%d" % [q, sell_v], m.sell.bind(res, q), m.has_market(), "good")
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.custom_minimum_size.y = 36
	var buy: Button = hud._button(deal, "Buy %d  -$%d" % [q, buy_v], m.buy.bind(res, q), m.has_market())
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.custom_minimum_size.y = 36
	_note(desk, "A deal fills now; the price answers over the next seconds. Big blocks cost more a unit.")
	# Every commodity: click one to trade it.
	hud._heading("Commodities")
	for r in m.resources():
		var b := Button.new()
		b.theme_type_variation = "RowButton"
		b.toggle_mode = true
		b.button_pressed = r == res
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -10
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		row.add_child(hud._icon(r, 24))
		var name: Label = hud._text(r.capitalize(), 14, hud.UI.CREAM)
		name.custom_minimum_size.x = 76
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_chart(m.history.get(r, []), _trend(m, r), Vector2(110, 24)))
		row.add_child(holder)
		var have: Label = hud._text("have %d" % int(eco.res.get(r, 0.0)), 12, hud.UI.MUTED)
		have.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		have.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(have)
		var ch: float = m.change(r, 60.0)
		var arrow: String = "▲" if ch > 0.01 else ("▼" if ch < -0.01 else "•")
		var pl: Label = hud._text("$%.2f  %s%.1f%%" % [m.price(r), arrow, absf(ch) * 100], 14, _trend(m, r) if absf(ch) > 0.01 else hud.UI.TEXT)
		pl.custom_minimum_size.x = 118
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(pl)
		var pick: String = r
		b.pressed.connect(func():
			market_res = pick
			hud.refresh_side())
		hud._side_rows.add_child(b)

## A grey hint that wraps to the window's width.
func _note(parent: Control, text: String) -> void:
	var l: Label = hud._text(text, 12, hud.UI.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 440
	parent.add_child(l)

## A small figure with its label, such as "2 / 4" over "routes in use".
func _stat(parent: Control, value: String, label: String, colour: Color) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", hud.UI.box(Color("0f1c2b"), Color("2d4460"), 1, 3, 6.0))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	box.add_child(col)
	var v: Label = hud._text(value, 18, colour, true)
	v.add_theme_font_size_override("font_size", 18)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(v)
	var l: Label = hud._text(label, 11, hud.UI.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	parent.add_child(box)

func _routes(m: Node) -> void:
	var d: Node = hud.world.diplomacy
	var stats: HBoxContainer = hud._row(hud._side_rows, 6)
	_stat(stats, "%d" % m.ports(), "ports", hud.UI.CREAM)
	_stat(stats, "%d / %d" % [m.routes.size(), m.route_cap()], "routes in use", hud.UI.CREAM)
	_stat(stats, "%d%%" % roundi(m.risk() * 100), "loss at sea", DOWN if m.risk() > 0.05 else hud.GOLD)
	_stat(stats, "%d" % m.delivered, "delivered", UP)
	_stat(stats, "%d" % m.lost, "lost", DOWN if m.lost > 0 else hud.UI.MUTED)
	if m.ports() == 0:
		hud._side_rows.add_child(hud._text("Overseas trade needs a Commercial Port on the coast.", 13, hud.UI.BAD))
	for r in m.routes:
		var card: VBoxContainer = hud._card(hud._nation_colour(r.nation))
		var head: HBoxContainer = hud._row(card, 8)
		head.add_child(hud._icon(r.res, 26))
		var arrow: String = "→" if r.dir == "export" else "←"
		var t: Label = hud._text("%s  %d %s  %s  %s" % ["Export" if r.dir == "export" else "Import", r.qty, r.res, arrow, d.name_of(r.nation)], 15, hud.UI.CREAM, true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		hud._button(head, "Close", m.close_route.bind(r.id), true, "bad")
		if r.shipment != null:
			var left: float = maxf(0.0, float(r.shipment.eta) - m._tick)
			hud._meter(card, 1.0 - left / float(m.cfg.voyage), 1.0, hud.GOLD, "%s  ·  worth $%d" % [r.status, int(r.shipment.value)])
		else:
			var status: String = str(r.status)
			var stalled: bool = status.begins_with("Stalled") or status.contains("lost") or status.contains("Sunk")
			card.add_child(hud._text(status, 13, DOWN if stalled else hud.UI.MUTED))
		card.add_child(hud._text("$%d traded on this route so far" % int(r.total), 12, hud.UI.MUTED))
	# A new route.
	var partners := []
	for i in range(1, d.n):
		if d.pact[0][i] and not d.at_war(0, i) and not d.defeated(i):
			partners.append([d.name_of(i), i])
	var form: VBoxContainer = hud._card(hud.GOLD)
	form.add_child(hud._text("New route", 15, hud.GOLD, true))
	if partners.is_empty():
		form.add_child(hud._text("No partners yet: sign a trade pact in Diplomacy (G).", 13, hud.UI.BAD))
		return
	if not partners.any(func(p): return p[1] == hud.route_nation):
		hud.route_nation = partners[0][1]
	var row: HBoxContainer = hud._row(form, 6)
	hud._segments(row, [["Export", "export"], ["Import", "import"]], hud.route_dir, func(v): hud.route_dir = v)
	hud._choice(row, m.resources().map(func(r): return [r.capitalize(), r]), hud.route_res, func(v): hud.route_res = v)
	hud._choice(row, partners, hud.route_nation, func(v): hud.route_nation = v)
	var value := roundi(hud.trade_qty * m.price(hud.route_res) * (float(m.cfg.importMarkup) if hud.route_dir == "import" else 1.0))
	_note(form, "%d units a voyage (worth about $%d), %d seconds at sea. Warships lower the losses." % [hud.trade_qty, value, int(m.cfg.voyage)])
	hud._button(form, "Open route", func(): return m.open_route(hud.route_nation, hud.route_res, hud.route_dir, hud.trade_qty), m.ports() > 0, "good")

# ---------------------------------------------------------------- territory
## Territory tabs: Your land (how firmly you hold it, what kind of land it is,
## what it yields, land for sale, the hex you clicked) and Nations (the
## island's land split between the nations: one bar, and a row each).

var territory_tab := "yours"
const STATUS_COLOURS := {"sovereign": Color("5fae63"), "integrated": Color("a7c35a"), "occupied": Color("d8b866"), "contested": Color("e0574a")}
const TERRAIN_COLOURS := [Color("3d6f9a"), Color("a7c35a"), Color("3f7d46"), Color("8a8f93"), Color("d9c38a")]

## A horizontal bar split into coloured shares: [[value, colour, label], ...].
func _split_bar(parent: Control, parts: Array, height := 22.0) -> void:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var total := 0.0
	for p in parts:
		total += float(p[0])
	var font: Font = hud.UI.font(600)
	bar.draw.connect(func():
		var w := bar.size.x
		var x := 0.0
		bar.draw_rect(Rect2(0, 0, w, height), Color("0b1620"))
		for p in parts:
			var span: float = w * float(p[0]) / maxf(total, 0.001)
			if span <= 0.5:
				continue
			bar.draw_rect(Rect2(x, 0, span, height), p[1])
			if span > 34.0 and str(p[2]) != "":
				bar.draw_string(font, Vector2(x, height * 0.72), str(p[2]), HORIZONTAL_ALIGNMENT_CENTER, span, 12, Color(0.05, 0.08, 0.1))
			x += span
		bar.draw_rect(Rect2(0, 0, w, height), Color(0, 0, 0, 0.5), false, 1.0))
	parent.add_child(bar)

func territory() -> void:
	_tabs([["Your land", "yours"], ["Nations", "nations"]], territory_tab, func(v): territory_tab = v)
	if territory_tab == "nations":
		_territory_nations()
	else:
		_territory_yours()

func _legend(parent: Control) -> void:
	var legend: HBoxContainer = hud._row(parent, 6)
	for s in ["sovereign", "integrated", "occupied", "contested"]:
		hud._pill(legend, s.capitalize(), STATUS_COLOURS[s])

func _territory_nations() -> void:
	var t: Node = hud.world.territory
	var land: int = t.land_cells()
	var d: Node = hud.world.diplomacy
	var card: VBoxContainer = hud._card()
	card.add_child(hud._text("The island's land", 16, hud.UI.CREAM, true))
	var parts := []
	var held := 0
	for id in range(hud.world.map.nations.size()):
		if d.defeated(id):
			continue
		var cells: int = t.yields(id).cells
		held += cells
		parts.append([cells, hud._nation_colour(id), "%d%%" % roundi(100.0 * cells / maxf(land, 1))])
	parts.append([maxi(0, land - held), Color("2a3642"), "free"])
	_split_bar(card, parts, 26.0)
	_note(card, "Each nation's land is painted on the map in its colour; gold stripes mark contested fronts.")
	for id in range(hud.world.map.nations.size()):
		if d.defeated(id):
			continue
		var y: Dictionary = t.yields(id)
		var row_card: VBoxContainer = hud._card(hud._nation_colour(id))
		var row: HBoxContainer = hud._row(row_card, 10)
		var name: Label = hud._text("You" if id == 0 else d.name_of(id), 15, hud._nation_colour(id).lightened(0.4), true)
		name.custom_minimum_size.x = 150
		row.add_child(name)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		_split_bar(col, [[y.sovereign, STATUS_COLOURS.sovereign, ""], [y.integrated, STATUS_COLOURS.integrated, ""], [y.occupied, STATUS_COLOURS.occupied, ""], [y.contested, STATUS_COLOURS.contested, ""]], 12.0)
		col.add_child(hud._text("%d hexes  ·  %d%% of the land%s" % [y.cells, roundi(100.0 * y.cells / maxf(land, 1)), ("  ·  %d contested" % y.contested) if y.contested > 0 else ""], 12, hud.UI.MUTED))
		if id > 0 and d.at_war(0, id):
			hud._pill(row, "AT WAR", WAR)
	_legend(hud._side_rows)

func _territory_yours() -> void:
	var t: Node = hud.world.territory
	var y: Dictionary = t.yields(0)
	var land: int = t.land_cells()
	# How firmly the land is held.
	var hold: VBoxContainer = hud._card(hud._nation_colour(0))
	var head: HBoxContainer = hud._row(hold, 8)
	var title: Label = hud._text("Your land", 16, hud.UI.CREAM, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(hud._text("%d hexes  ·  %d%% of the island" % [y.cells, roundi(100.0 * y.cells / maxf(land, 1))], 13, hud.UI.MUTED))
	_split_bar(hold, [[y.sovereign, STATUS_COLOURS.sovereign, str(y.sovereign)], [y.integrated, STATUS_COLOURS.integrated, str(y.integrated)], [y.occupied, STATUS_COLOURS.occupied, str(y.occupied)], [y.contested, STATUS_COLOURS.contested, str(y.contested)]], 24.0)
	_legend(hold)
	_note(hold, "Land yields more the firmer you hold it: sovereign 100%, integrated 75%, occupied 40%, contested 15%.")
	# What kind of land.
	var kinds := [0, 0, 0, 0, 0]
	for i in range(t.owner_of.size()):
		if t.owner_of[i] == 0:
			kinds[t.terrain[i]] += 1
	var terrain_card: VBoxContainer = hud._card()
	terrain_card.add_child(hud._text("Kinds of land", 15, hud.UI.CREAM, true))
	var tparts := []
	for k in range(1, 5):
		tparts.append([kinds[k], TERRAIN_COLOURS[k], ("%s %d" % [t.TERRAIN_NAMES[k], kinds[k]]) if kinds[k] > 0 else ""])
	_split_bar(terrain_card, tparts, 24.0)
	_note(terrain_card, "Plains grow food, forest and coast pay money, mountains give iron. Territorial waters: %d hexes." % kinds[0])
	# Yields.
	var yields: HBoxContainer = hud._row(hud._side_rows, 6)
	for item in [["money", y.money, "%.2f"], ["food", y.food, "%.2f"], ["iron", y.iron, "%.3f"], ["oil", y.oil, "%.3f"]]:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", hud.UI.box(Color("0f1c2b"), Color("2d4460"), 1, 3, 6.0))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(r)
		r.add_child(hud._icon(item[0], 22))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		r.add_child(col)
		col.add_child(hud._text("+" + (item[2] % item[1]), 15, hud.UI.CREAM, true))
		col.add_child(hud._text("per second", 10, hud.UI.MUTED))
		yields.add_child(box)
	# Land for sale at your town halls.
	var sale: VBoxContainer = hud._card(hud.GOLD)
	sale.add_child(hud._text("Buying land", 15, hud.GOLD, true))
	var any := false
	for b in hud.world.buildings:
		if b.dead or not b.built or b.owner != 0 or not t.RINGS_MAX.has(b.key):
			continue
		any = true
		var row: HBoxContainer = hud._row(sale, 8)
		var n: Label = hud._text(b.def.name, 13, hud.UI.CREAM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(hud._text("%d of %d left  ·  %d on offer" % [t.purchases_left(b), t.PURCHASES, t.purchase_candidates(b).size()], 12, hud.UI.MUTED))
	sale.add_child(hud._text(("Select a capital, city or village centre and press Buy land: $%d a hex." % int(t.LAND_PRICE)) if any else "Found a village or city to buy land around it.", 12, hud.UI.MUTED))
	# The hex clicked on the map.
	var pick: VBoxContainer = hud._card()
	pick.add_child(hud._text("Selected hex", 15, hud.UI.CREAM, true))
	var pl: Label = hud._text(hud.territory_pick, 13, hud.UI.TEXT)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pl.custom_minimum_size.x = 460
	pick.add_child(pl)
