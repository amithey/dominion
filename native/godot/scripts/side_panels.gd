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
	["Leadership", ["assassinate", "decapitationRaid"]],
]

var hud: Node
var diplomacy_tab := "nations"
var intel_tab := "operations"
var defence_tab := "generals"
var un_tab := "council"
var un_target := 1

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
			_power_card()
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
		pic.texture = Gallery.face(leader, 1.0)
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
	var client: bool = hud.world.espionage.puppets.has(id)
	if client:
		var patron: int = int(hud.world.espionage.puppets[id].get("patron", 0))
		hud._pill(head, "US CLIENT STATE" if patron == 0 else "CLIENT OF %s" % d.name_of(patron).to_upper(), PACT)   # a puppet ruler (regime_change.gd)
	if d.at_war(0, id):
		hud._pill(head, "AT WAR", WAR)
	if d.allied(0, id) and not client:
		hud._pill(head, "ALLY", ALLY)
	if d.pact[0][id] and not client:
		hud._pill(head, "TRADE", PACT)
	if d.nap[0][id] and not client:
		hud._pill(head, "NON-AGGRESSION", NAP)
	if not (client or d.at_war(0, id) or d.allied(0, id) or d.pact[0][id] or d.nap[0][id]):
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
	var P := preload("res://scripts/faction_powers.gd")
	var power: Dictionary = P.power_of(hud.world, 0)
	if not power.is_empty() and power.target:
		var why: String = P.blocked(hud.world, 0, id)
		var use: Button = hud._button(actions, str(power.name), func():
			P.use(hud.world, 0, id)
			hud.refresh_side(), why == "", "good")
		use.tooltip_text = str(power.desc) + ("" if why == "" else "  (" + why + ")")
	if d.allied(0, id):
		for enemy in range(1, d.n):
			if d.at_war(0, enemy) and not d.at_war(id, enemy):
				hud._button(card, "Call them to war against %s" % d.name_of(enemy), d.request_joint_war.bind(id, enemy))
	preload("res://scripts/nation_profile_view.gd").append_to(card, str(hud.world.map.nations[id].get("id", "")), func(): hud._fit_window(hud._win_scroll.scroll_vertical))

## Your nation's political power (faction_powers.gd): what it does, when it is
## ready, and a button when it takes no target (the others are on each card).
func _power_card() -> void:
	var w: Node = hud.world
	var P := preload("res://scripts/faction_powers.gd")
	var p: Dictionary = P.power_of(w, 0)
	if p.is_empty():
		return
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("Your nation: " + w.diplomacy.name_of(0), 13, hud.UI.MUTED))
	card.add_child(hud._text("National power: " + str(p.name), 16, hud.UI.CREAM, true))
	card.add_child(hud._text(str(p.desc), 13, hud.UI.TEXT))
	var wait: float = P.ready_in(w, 0)
	card.add_child(hud._text("Ready" if wait <= 0.0 else "Ready again in %d s" % int(ceilf(wait)), 13, hud.UI.GOOD if wait <= 0.0 else hud.UI.MUTED))
	if not p.target:
		var row: HBoxContainer = hud._row(card, 6)
		var why: String = P.blocked(w, 0)
		var button: Button = hud._button(row, "Use: " + str(p.name), func():
			P.use(w, 0)
			hud.refresh_side(), why == "", "good")
		button.tooltip_text = str(p.desc) + ("" if why == "" else " (" + why + ")")
		if why != "" and wait <= 0.0: card.add_child(hud._text(why, 13, hud.UI.MUTED))
	var active_until := 0.0
	for effect in w.power_effects:
		if int(effect.by) == 0 and str(effect.kind).begins_with("extra_") and effect.kind != "extra_food_aid":
			active_until = maxf(active_until, float(effect.until))
	if active_until > w.game_time:
		card.add_child(hud._text("Effect active for up to %d s" % ceili(active_until - w.game_time), 13, hud.UI.GOOD))
	if w.power_effects.any(func(e): return e.kind == "extra_food_aid" and int(e.by) == 0 and float(e.until) > w.game_time):
		card.add_child(hud._text("Food aid shipment in transit", 13, hud.UI.GOOD))
	# Your own strengths and weaknesses, in the same disclosure as the rivals' cards.
	preload("res://scripts/nation_profile_view.gd").append_to(card, preload("res://scripts/national_profile.gd").id_of(w, 0), func(): hud._fit_window(hud._win_scroll.scroll_vertical))

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
	_tabs([["Operations", "operations"], ["Agents (%d)" % e.agents.size(), "agents"], ["Dossiers", "dossiers"], ["Reports", "reports"], ["Space", "space"]], intel_tab, func(v): intel_tab = v)
	if intel_tab == "space":
		_space(d)
		return
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

## The space tab (space.gd): your satellites, launches, what you watch from
## orbit, the debris, and the anti-satellite missile.
func _space(d: Node) -> void:
	var s = hud.world.space
	if s == null:
		return
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("In orbit: %d satellite%s" % [s.total(0), "" if s.total(0) == 1 else "s"], 17, hud.UI.CREAM, true))
	var summary := PackedStringArray()
	for kind in s.KINDS:
		summary.append("%s %d" % [kind.capitalize(), s.count(0, kind)])
	card.add_child(hud._text("  ·  ".join(summary), 13, hud.UI.TEXT))
	var effects := PackedStringArray()
	if s.count(0, "recon") > 0:
		effects.append("an imaging pass over %s every %ds" % [d.name_of(int(s.watch.get(0, -1))) if int(s.watch.get(0, -1)) >= 0 else "no one", int(s.PASS_SECONDS / s.count(0, "recon"))])
	var nav: float = s.nav_factor(0)
	if nav > 1.0: effects.append("guided weapons +10% accuracy")
	elif nav < 1.0: effects.append("GPS denied: guided weapons -10% accuracy")
	if s.jam_factor(0) < 1.0: effects.append("drones half as easily jammed")
	if s.count(0, "warning") > 0: effects.append("+%d%% missile interception" % (5 * mini(s.count(0, "warning"), 2)))
	var fx: Label = hud._text("Now: " + ("; ".join(effects) if not effects.is_empty() else "nothing in orbit works for you yet."), 13, hud.UI.MUTED)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.custom_minimum_size.x = 460
	card.add_child(fx)
	if s.debris > 0.0:
		hud._meter(card, s.debris, 100.0, hud.UI.BAD, "Debris in orbit %d: each satellite has a %.1f%% chance in 30 s of being struck" % [int(s.debris), s.debris / 10.0])
	# Launches.
	var pad: VBoxContainer = hud._card()
	pad.add_child(hud._text("Launch", 15, hud.UI.CREAM, true))
	var how := "From your Missile Silo." if s.ident(0) in s.LAUNCHERS else "Your nation has no launcher of its own: launches are bought abroad at +50%."
	pad.add_child(hud._text(how, 12, hud.UI.MUTED))
	var help := {"recon": "Sees the watched nation's towns through the fog",
		"nav": "Two or more: guided weapons +10% accuracy",
		"comms": "Two or more: drones half as easily jammed",
		"warning": "+5% missile interception each (up to two)"}
	for kind in s.KINDS:
		var row: HBoxContainer = hud._row(pad)
		var why: String = s.launch_blocked(kind)
		var k: String = kind
		var b: Button = hud._button(row, "%s  (%s)" % [s.NAMES[kind], hud.cost_text(s.price(kind))], func(): return s.launch(k), why == "", "good")
		b.tooltip_text = help[kind] + ("" if why == "" else "
" + why)
		b.custom_minimum_size = Vector2(330, 34)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var note: Label = hud._text(why if why != "" else help[kind], 12, hud.UI.BAD if why != "" else hud.UI.MUTED)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
	# What the recon satellites watch.
	var targets := _targets(d)
	if not targets.is_empty() and s.count(0, "recon") > 0:
		var wr: HBoxContainer = hud._row(pad)
		wr.add_child(hud._text("Watch", 14, hud.UI.MUTED))
		var items := []
		for id in targets: items.append([d.name_of(id), id])
		hud._choice(wr, items, int(s.watch.get(0, targets[0])), func(v):
			s.watch[0] = int(v)
			hud.refresh_side())
	# Rivals in orbit, and the anti-satellite missile.
	var foes: VBoxContainer = hud._card(hud.UI.BAD)
	foes.add_child(hud._text("Rivals in orbit", 15, hud.UI.CREAM, true))
	for id in targets:
		var row: HBoxContainer = hud._row(foes)
		var lab: Label = hud._text("%s: %d satellites%s" % [d.name_of(id), s.total(id), "  (watching you)" if int(s.watch.get(id, -1)) == 0 and s.count(id, "recon") > 0 else ""], 13, hud._nation_colour(id).lightened(0.35))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var why: String = s.asat_blocked(id)
		var target: int = id
		if s.can_jam(0):
			var why_j: String = s.jam_blocked(id)
			var jb: Button = hud._button(row, "Jam ($%d)" % int(s.JAM_COST), func(): return s.jam(0, target), why_j == "")
			jb.tooltip_text = (why_j + "\n" if why_j != "" else "") + "Ground jammers silence its satellites for 2 minutes: nothing is destroyed and it is no act of war, but it is resented (-8)."
		var b: Button = hud._button(row, "Anti-satellite missile ($%d)" % int(s.ASAT_COST), func(): return s.fire_asat(0, target), why == "", "bad")
		b.tooltip_text = (why + "
" if why != "" else "") + "85% to destroy one satellite. An act of war; every other nation thinks less of you, and the debris threatens everyone's satellites, yours too."
	if preload("res://scripts/cbrn_data.gd").has(hud.world, 0, "nuclearAsat"):
		var why_n: String = s.orbital_nuke_blocked()
		var nb: Button = hud._button(foes, "Nuclear detonation in orbit ($%d)" % int(s.ORBITAL_NUKE_COST), func(): return s.orbital_nuke(0), why_n == "", "bad")
		nb.tooltip_text = (why_n + "
" if why_n != "" else "") + "Destroys about 70% of all satellites in orbit, yours too, and fills the orbit with debris. A nuclear detonation (DEFCON 1) and a breach of the Outer Space Treaty."

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
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, hud.UI.box(Color("2d4863"), hud._nation_colour(id).lightened(0.2), 2, 2, 9.0))
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
	# Standing orders: agents keep growing the network here and refreshing its
	# dossier on their own, one job at a time (espionage._standing_orders).
	var standing := CheckButton.new()
	standing.name = "StandingOrders"
	standing.text = "Standing orders on %s: grow the network to 60 and keep the dossier fresh ($160-180 a job)" % d.name_of(hud.spy_target)
	standing.button_pressed = e.standing.has(hud.spy_target)
	standing.focus_mode = Control.FOCUS_NONE
	standing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	standing.add_theme_font_size_override("font_size", 13)
	var who: int = hud.spy_target
	standing.toggled.connect(func(on: bool):
		if on: e.standing[who] = true
		else: e.standing.erase(who)
		hud.notice("Standing orders on %s %s." % [d.name_of(who), "issued: your agents take the next job each time one is free" if on else "withdrawn"]))
	brief.add_child(standing)
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
	hud._side_rows.add_child(hud._text(preload("res://scripts/war_costs.gd").summary(hud.world), 12, hud.UI.MUTED))
	var costs: Label = hud._text("Fuel is consumed by motorised travel. Ammunition and interceptors are paid when fired, including misses. Aircraft buy fuel before each sortie.", 12, hud.UI.MUTED)
	costs.tooltip_text = "Tank: 3.5 oil / 100 m, $1.20 / shell. Artillery: $2 / shell; MLRS: $6 / salvo. SAM: $5; ABM: $18; laser: $0.35 per attempt. Aircraft: 4–12 oil per 90-second sortie. Nuclear submarines use no oil."
	hud._side_rows.add_child(costs)
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
		b.tooltip_text = "Trade %s: its price, your stock and the trend. Click to select it." % r.capitalize()
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
	if m.ports() == 0 and m.land_links() == 0:
		hud._side_rows.add_child(hud._text("Trade needs a Commercial Port, or a road or railway to another nation's town.", 13, hud.UI.BAD))
	for r in m.routes:
		var card: VBoxContainer = hud._card(hud._nation_colour(r.nation))
		var head: HBoxContainer = hud._row(card, 8)
		head.add_child(hud._icon(r.res, 26))
		var arrow: String = "→" if r.dir == "export" else "←"
		var by: String = ("by " + (m.land_link(r.nation) if m.land_link(r.nation) != "" else "road")) if r.get("overland", false) else "by sea"
		var t: Label = hud._text("%s  %d %s  %s  %s  (%s)" % ["Export" if r.dir == "export" else "Import", r.qty, r.res, arrow, d.name_of(r.nation), by], 15, hud.UI.CREAM, true)
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
	hud._button(form, "Open route", func(): return m.open_route(hud.route_nation, hud.route_res, hud.route_dir, hud.trade_qty), m.ports() > 0 or m.land_link(hud.route_nation) != "", "good")

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
		col.add_child(hud._text("per second", 12, hud.UI.MUTED))
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

# ---------------------------------------------------------------- defence

## The Defence window: the general staff, the units' ranks, and the nuclear
## alert (generals.gd, veterancy.gd, defcon.gd).
func defence() -> void:
	_tabs([["Generals", "generals"], ["Veterans", "veterans"], ["Nuclear alert", "nuclear"], ["AI", "ai"]], defence_tab, func(v): defence_tab = v)
	match defence_tab:
		"ai":
			preload("res://scripts/ai_panel.gd").draw(self)
		"veterans":
			_veterans()
		"nuclear":
			_nuclear()
		_:
			_generals()

func _generals() -> void:
	var g = hud.world.generals
	if g == null:
		return
	var picked: Array = hud._selected_units().filter(func(u): return u.owner == 0 and not u.dead)
	var target = picked[0] if picked.size() == 1 else null
	var head: Label = hud._text("Your general staff: %d of %d. A general commands from a ground or naval unit; every unit of yours within %d m fights under their traits (Air Power: the whole air force). Select one unit, then give a general its command." % [g.of(0).size(), g.MAX_PLAYER, int(g.COMMAND_RADIUS)], 13, hud.UI.MUTED)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 460
	hud._side_rows.add_child(head)
	for gen in g.of(0):
		var card: VBoxContainer = hud._card(hud.UI.GOLD)
		card.add_child(hud._text("%s  ·  level %d  ·  %d kills" % [gen.name, int(gen.level), int(gen.kills)], 16, hud.UI.CREAM, true))
		for t in gen.traits:
			card.add_child(hud._text("%s: %s" % [g.TRAITS[t].name, g.TRAITS[t].desc], 12, hud.UI.TEXT))
		var where := "In reserve."
		if float(gen.wounded_until) > hud.world.game_time:
			where = "Wounded: back in %ds." % ceili(float(gen.wounded_until) - hud.world.game_time)
		elif gen.unit != null:
			where = "Commands from your %s (%d%% health)." % [hud.world.unit_defs.get(gen.unit.key, {}).get("name", gen.unit.key), roundi(100.0 * gen.unit.hp / gen.unit.max_hp)]
		card.add_child(hud._text(where, 12, hud.UI.MUTED))
		var row: HBoxContainer = hud._row(card)
		var why: String = g.assign_blocked(gen, target)
		var who: Dictionary = gen
		var b: Button = hud._button(row, "Give command of the selected unit", func(): return g.assign(who, target), why == "", "good")
		b.tooltip_text = why
		if gen.unit != null:
			hud._button(row, "Go to", func():
				hud.world.cam_focus = who.unit.node.position
				return "")
		hud._button(row, "Dismiss", func(): return g.dismiss(who), true, "bad")
	var offer: VBoxContainer = hud._card()
	offer.add_child(hud._text("Candidates  ·  $%d an appointment  ·  new ones in %ds" % [int(g.hire_cost()), maxi(0, ceili(g._next_offer - hud.world.game_time))], 15, hud.UI.CREAM, true))
	for i in range(g.candidates.size()):
		var c: Dictionary = g.candidates[i]
		var row: HBoxContainer = hud._row(offer)
		var lab: Label = hud._text("%s: %s" % [c.name, " · ".join(PackedStringArray(c.traits.map(func(t): return g.TRAITS[t].name)))], 13, hud.UI.TEXT)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.tooltip_text = "\n".join(PackedStringArray(c.traits.map(func(t): return "%s: %s" % [g.TRAITS[t].name, g.TRAITS[t].desc])))
		lab.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(lab)
		var index: int = i
		hud._button(row, "Appoint", func(): return g.hire(index), g.of(0).size() < g.MAX_PLAYER and hud.world.economy.res.money >= g.hire_cost(), "good")
	# The rivals' generals.
	var d: Node = hud.world.diplomacy
	var known := PackedStringArray()
	for i in range(1, d.n):
		if d.defeated(i):
			continue
		for gen in g.of(i):
			known.append("%s (%s): %s" % [gen.name, d.name_of(i), g.traits_text(gen)])
	if not known.is_empty():
		var foes: VBoxContainer = hud._card(hud.UI.BAD)
		foes.add_child(hud._text("Rival generals", 15, hud.UI.CREAM, true))
		for line in known:
			foes.add_child(hud._text(line, 12, hud.UI.TEXT))

func _veterans() -> void:
	var V := preload("res://scripts/veterancy.gd")
	var c: Array = V.census(hud.world)
	var card: VBoxContainer = hud._card(hud.UI.GOLD)
	card.add_child(hud._text("Your forces by rank", 16, hud.UI.CREAM, true))
	for r in range(V.RANKS.size()):
		var row: HBoxContainer = hud._row(card)
		var lab: Label = hud._text("%s  %s" % [V.RANKS[r], "^".repeat(r)], 14, V.CHEVRON if r > 0 else hud.UI.TEXT)
		lab.custom_minimum_size.x = 150
		row.add_child(lab)
		var fx := "as it leaves the factory" if r == 0 else "+%d%% damage, %d%% less damage taken%s" % [roundi((V.DAMAGE[r] - 1.0) * 100.0), roundi((1.0 - V.TAKEN[r]) * 100.0), ", repairs itself out of combat" if r == 3 else ""]
		row.add_child(hud._text("%d units  ·  %s" % [c[r], fx], 13, hud.UI.MUTED))
	var how: Label = hud._text("A unit earns experience from the damage it deals, and more for each kill. It becomes a Veteran once it has dealt its own health in damage, Elite at three times and Heroic at six. The rivals' units rank up the same way.", 12, hud.UI.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 460
	card.add_child(how)
	var best: Array = hud.world.units.filter(func(u): return u.owner == 0 and not u.dead and float(u.get("xp", 0.0)) > 0.0)
	best.sort_custom(func(a, b): return float(a.xp) / float(a.max_hp) > float(b.xp) / float(b.max_hp))
	if not best.is_empty():
		var top: VBoxContainer = hud._card()
		top.add_child(hud._text("The most experienced", 15, hud.UI.CREAM, true))
		for u in best.slice(0, 6):
			var row: HBoxContainer = hud._row(top)
			var lab: Label = hud._text("%s  ·  %s  ·  %d xp" % [hud.world.unit_defs.get(u.key, {}).get("name", u.key), V.rank_name(u), int(u.xp)], 13, hud.UI.TEXT)
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lab)
			var unit: Dictionary = u
			hud._button(row, "Go to", func():
				hud.world.cam_focus = unit.node.position
				return "")

func _nuclear() -> void:
	var dc = hud.world.defcon
	if dc == null:
		return
	var lvl: int = dc.level()
	var card: VBoxContainer = hud._card(hud.UI.BAD if lvl <= 2 else hud.UI.GOLD)
	card.add_child(hud._text("DEFCON %d" % lvl, 22, hud.UI.CREAM, true))
	card.add_child(hud._text(dc.DESC[lvl], 13, hud.UI.TEXT))
	var why: String = dc.cause()
	if why != "":
		card.add_child(hud._text("Cause: %s." % why, 13, hud.UI.MUTED))
	hud._meter(card, dc.tension, 100.0, hud.UI.BAD if lvl <= 2 else hud.UI.GOLD, "Nuclear tension %d  ·  DEFCON 4 at 20, 3 at 40, 2 at 60, 1 at 80" % roundi(dc.tension))
	var mine: VBoxContainer = hud._card()
	var p: int = int(dc.posture[0])
	mine.add_child(hud._text("Your forces: DEFCON %d" % p, 16, hud.UI.CREAM, true))
	var armed: bool = dc.nuclear(0)
	mine.add_child(hud._text(dc.posture_text(p, armed), 13, hud.UI.TEXT))
	var row: HBoxContainer = hud._row(mine)
	var up: Button = hud._button(row, "Raise the alert", func(): return dc.raise_posture(), p > 2, "bad")
	if p > 2:
		up.tooltip_text = "DEFCON %d: %s%s" % [p - 1, dc.posture_text(p - 1, armed), (" Every nation will think less of you (%d)." % (-8 if armed else -4)) if p - 1 == 2 else (" Nuclear powers -4 relations." if p - 1 == 3 else "")]
	hud._button(row, "Stand down", func(): return dc.lower_posture(), p < 5)
	var release: String = dc.release_blocked()
	if armed:
		mine.add_child(hud._text("Nuclear release: %s" % ("authorised." if release == "" else release), 12, hud.UI.BAD if release == "" else hud.UI.MUTED))
	else:
		# No bomb, no release: a threshold state may still break out (wmd.gd).
		var threshold: bool = preload("res://scripts/cbrn_data.gd").THRESHOLD.has(preload("res://scripts/cbrn_data.gd").ident(hud.world, 0))
		_wrap(mine, "Nuclear weapons: none.%s Your alert is a conventional mobilisation and does not raise the world's nuclear tension." % (" A Nuclear Breakout could build them." if threshold else ""), 12, hud.UI.MUTED)
	if armed:
		mine.add_child(hud._text("Deterrent: %s" % ("ready (a second strike is possible)" if dc.deterrent(0) else "none: no nuclear missile stored and no nuclear submarine at sea"), 12, hud.UI.MUTED))
	var nt = hud.world.get("tests")
	if nt != null and dc.nuclear(0):
		var test: VBoxContainer = hud._card(hud.UI.BAD)
		test.add_child(hud._text("Nuclear test", 15, hud.UI.CREAM, true))
		var how: Label = hud._text("Proves the weapon works: for 15 minutes rivals believe your deterrent (they are far slower to start a war with you, and slower to strike you with nuclear weapons), and your scientists learn from it. The world condemns it, tension rises, and the Security Council takes it up. Underground: almost nothing escapes. In the open air: a mushroom cloud and fallout that drifts with the wind, and twice the anger.", 12, hud.UI.MUTED)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size.x = 460
		test.add_child(how)
		if nt.believed(0):
			test.add_child(hud._text("Your deterrent is believed for %ds more (%d tests so far)." % [ceili(float(nt.deterred[0]) - hud.world.game_time), int(nt.count.get(0, 0))], 12, hud.UI.GOOD))
		var trow: HBoxContainer = hud._row(test)
		for kind in ["underground", "atmospheric"]:
			var test_blocked: String = nt.blocked(kind)
			var kk: String = kind
			var tb: Button = hud._button(trow, "%s (%s)" % [nt.KINDS[kind].name, hud.cost_text(nt.COST)], func(): return nt.conduct(0, kk), test_blocked == "", "bad")
			tb.tooltip_text = test_blocked
	var d: Node = hud.world.diplomacy
	var powers: VBoxContainer = hud._card()
	powers.add_child(hud._text("The nuclear powers", 15, hud.UI.CREAM, true))
	for i in range(1, d.n):
		if d.defeated(i) or not dc.nuclear(i):
			continue
		var state := "forces at DEFCON %d" % int(dc.posture[i])
		if dc.existential(i): state += ", fighting for its survival"
		if d.at_war(0, i): state += ", at war with you"
		powers.add_child(hud._text("%s: %s" % [d.name_of(i), state], 13, hud._nation_colour(i).lightened(0.35)))

# ---------------------------------------------------------------- united nations

## The UN window (un.gd): the Council and the draft before it, your own drafts,
## the General Assembly, the organisation (elections, the presidency, the
## Secretary-General, dues, peacekeepers, sanctions in force) and the record.
func united_nations() -> void:
	var u = hud.world.un
	if u == null:
		return
	_tabs([["Council", "council"], ["Draft", "draft"], ["Assembly", "assembly"], ["Organisation", "org"], ["Record", "record"]], un_tab, func(v): un_tab = v)
	match un_tab:
		"draft":
			_un_draft(u)
		"assembly":
			_assembly(u)
		"org":
			_un_org(u)
		"record":
			_un_record(u)
		_:
			_council(u)

func _wrap(parent: Control, text: String, size := 12, colour := Color(0, 0, 0, 0)) -> Label:
	var l: Label = hud._text(text, size, hud.UI.MUTED if colour.a == 0.0 else colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	parent.add_child(l)
	return l

func _council(u) -> void:
	var d: Node = hud.world.diplomacy
	var seats: VBoxContainer = hud._card(hud.UI.GOLD)
	seats.add_child(hud._text("The Security Council: %d members" % u.council().size(), 16, hud.UI.CREAM, true))
	for i in u.council():
		var tag := "permanent, veto" if u.permanent(i) else "elected, %s, %ds left" % [preload("res://scripts/un_data.gd").region(hud.world, i), maxi(0, ceili(float(u.elected.get(i, 0.0)) - hud.world.game_time))]
		_wrap(seats, "%s%s  ·  %s" % ["You" if i == 0 else d.name_of(i), "  (President)" if i == u.president else "", tag], 13, hud._nation_colour(i).lightened(0.35) if i != 0 else hud.UI.CREAM)
	_wrap(seats, "Full Council: 9 of 15 yes votes and no permanent-member veto. This campaign scales the Council to the nations present: %d yes votes required. Abstentions never lower that threshold. Parties abstain on Chapter VI resolutions. Presidential statements need consensus." % ceili(u.council().size() * u.PASS_SHARE))
	var floor: VBoxContainer = hud._card(hud.UI.BAD if u.current != null else Color(0, 0, 0, 0))
	if u.current == null:
		floor.add_child(hud._text("No draft is before the Council.", 14, hud.UI.MUTED))
	else:
		var dr: Dictionary = u.current
		var head := "Presidential statement" if dr.measure == "statement" else "Draft resolution %d" % int(dr.number)
		floor.add_child(hud._text("%s  ·  %s" % [head, "consultations" if dr.phase == "consult" else "voting"], 16, hud.UI.CREAM, true))
		_wrap(floor, dr.title, 13, hud.UI.TEXT)
		_wrap(floor, "Sponsor: %s  ·  measure: %s" % ["you" if int(dr.by) == 0 else ("the Secretary-General" if int(dr.by) < 0 else d.name_of(int(dr.by))), u.MEASURES[dr.measure].name])
		var t: Dictionary = u.tally(dr, true)
		floor.add_child(hud._text("Whip count: %d yes, %d no, %d abstain%s  ·  %s" % [t.yes, t.no, t.abstain, (" · veto by " + ", ".join(PackedStringArray(t.vetoes.map(func(v): return "you" if v == 0 else d.name_of(v))))) if not t.vetoes.is_empty() else "", "it would PASS" if t.passes else "it would FAIL"], 13, hud.UI.GOOD if t.passes else hud.UI.BAD))
		var closes: float = (float(dr.opens) + u.CONSULT_SECONDS) if dr.phase == "consult" else float(dr.closes)
		floor.add_child(hud._text("%s in %ds." % ["The vote opens" if dr.phase == "consult" else "The vote closes", maxi(0, ceili(closes - hud.world.game_time))], 12, hud.UI.MUTED))
		if 0 in dr.get("electorate", u.council()):
			var row: HBoxContainer = hud._row(floor)
			row.add_child(hud._text("Your vote%s:" % (" (" + u.player_vote + ")" if u.player_vote != "" else ""), 14, hud.UI.CREAM))
			var can_vote: bool = dr.phase == "vote"
			hud._button(row, "Yes", func(): return u.cast("yes"), can_vote, "good")
			hud._button(row, "Veto" if u.permanent(0) else "No", func(): return u.cast("no"), can_vote, "bad")
			hud._button(row, "Abstain", func(): return u.cast("abstain"), can_vote)
		if int(dr.by) == 0 and dr.phase == "consult":
			var amend: HBoxContainer = hud._row(floor, 4)
			amend.add_child(hud._text("Amend:", 12, hud.UI.MUTED))
			for m in ["economic", "embargo", "targeted", "condemn", "statement"]:
				var mm: String = m
				hud._button(amend, u.MEASURES[m].name, func(): return u.amend(mm), dr.measure != m)
		# Lobbying: aid to a member moves its vote one step.
		var lob: VBoxContainer = hud._card()
		lob.add_child(hud._text("Lobby a member ($%d each)" % int(u.lobby_cost()), 13, hud.UI.CREAM, true))
		for i in u.council():
			if i == 0 or i == int(dr.target):
				continue
			var row: HBoxContainer = hud._row(lob, 4)
			var lab: Label = hud._text("%s: %s" % [d.name_of(i), u.vote_of(i, dr)], 12, hud.UI.TEXT)
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lab)
			var who: int = i
			hud._button(row, "Toward yes", func(): return u.lobby(who, 1), dr.phase == "consult")
			hud._button(row, "Toward no", func(): return u.lobby(who, -1), dr.phase == "consult")
	if not u.queue.is_empty():
		floor.add_child(hud._text("%d more draft%s waiting." % [u.queue.size(), "" if u.queue.size() == 1 else "s"], 12, hud.UI.MUTED))
	for dm in u.demands:
		floor.add_child(hud._text("Demand in force: %s must stop the war on %s within %ds." % ["You" if int(dm.aggressor) == 0 else d.name_of(int(dm.aggressor)), "you" if int(dm.victim) == 0 else d.name_of(int(dm.victim)), maxi(0, ceili(float(dm.until) - hud.world.game_time))], 12, hud.UI.BAD))
	preload("res://scripts/un_activity.gd").council(self)

func _un_draft(u) -> void:
	var d: Node = hud.world.diplomacy
	var box: VBoxContainer = hud._card(hud.UI.GOLD)
	box.add_child(hud._text("Table a draft", 16, hud.UI.CREAM, true))
	_wrap(box, "Every member may bring a crisis and submit a proposal. Only Council members vote on its adoption. Sanctions, an ICC referral or force need a recorded cause. Assembly recommendations are voted separately by all members.")
	var nations := _targets(d)
	if nations.is_empty():
		return
	if not un_target in nations:
		un_target = nations[0]
	var pick: HBoxContainer = hud._row(box)
	pick.add_child(hud._text("Target", 13, hud.UI.MUTED))
	var items := []
	for i in nations: items.append([d.name_of(i), i])
	hud._choice(pick, items, un_target, func(v):
		un_target = int(v)
		hud.refresh_side())
	var target: int = un_target
	var ga_row: HBoxContainer = hud._row(box)
	hud._button(ga_row, "Propose Assembly recommendation", func(): return u.assembly_draft(target))
	var cause: String = u.cause_against(target)
	box.add_child(hud._text("Cause on record: %s." % (cause if cause != "" else "none"), 12, hud.UI.TEXT))
	var foes: Array = nations.filter(func(o): return o != target and d.at_war(target, o)) + ([0] if d.at_war(target, 0) else [])
	for m in ["statement", "condemn", "targeted", "embargo", "economic", "nonproliferation", "icc", "force", "lift"]:
		var row: HBoxContainer = hud._row(box, 6)
		var why: String = u.draft_blocked(m, target)
		var mm: String = m
		var b: Button = hud._button(row, u.MEASURES[m].name, func(): return u.draft(mm, target), why == "", "bad" if u.MEASURES[m].severity >= 3 else "")
		b.custom_minimum_size.x = 220
		var guess: Dictionary = u.tally({"kind": "player", "measure": m, "target": target, "other": -1, "by": 0, "cause": cause, "votes": {}, "lobby": {}}, true)
		var note: Label = hud._text(why if why != "" else "Expected: %d-%d-%d%s" % [guess.yes, guess.no, guess.abstain, "  (vetoed)" if not guess.vetoes.is_empty() else ("  (passes)" if guess.passes else "")], 12, hud.UI.BAD if why != "" else hud.UI.MUTED)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
	for o in foes:
		var other: int = o
		for m in ["ceasefire", "peacekeeping", "withdraw"]:
			var row: HBoxContainer = hud._row(box, 6)
			var why: String = u.draft_blocked(m, target, other)
			var mm: String = m
			var b: Button = hud._button(row, "%s with %s" % [u.MEASURES[m].name, "you" if other == 0 else d.name_of(other)], func(): return u.draft(mm, target, other), why == "")
			b.custom_minimum_size.x = 220
			if why != "":
				row.add_child(hud._text(why, 12, hud.UI.BAD))

func _assembly(u) -> void:
	preload("res://scripts/un_activity.gd").assembly(self)

func _un_org(u) -> void:
	var d: Node = hud.world.diplomacy
	var Cb := preload("res://scripts/cbrn_data.gd")
	var org: VBoxContainer = hud._card(hud.UI.GOLD)
	org.add_child(hud._text("The organisation", 16, hud.UI.CREAM, true))
	_wrap(org, "Secretary-General: offers good offices and mediation; brings prolonged wars to the Council after five game minutes (Art. 99). The real Secretary-General is appointed by the Assembly on the Council's recommendation; appointments are not simulated.", 12, hud.UI.TEXT)
	_wrap(org, "Presidency: %s, for %ds more (it rotates in alphabetical order)." % ["you" if u.president == 0 else (d.name_of(u.president) if u.president >= 0 else "vacant"), maxi(0, ceili(u.presidency_ends - hud.world.game_time))], 12, hud.UI.TEXT)
	var el: HBoxContainer = hud._row(org)
	el.add_child(hud._text("Next election in %ds." % maxi(0, ceili(u.term_ends - hud.world.game_time)), 12, hud.UI.TEXT))
	if not u.permanent(0) and not u.elected.has(0):
		hud._button(el, "Campaign for a seat ($1,500)", func(): return u.campaign())
	# Dues.
	var dues: VBoxContainer = hud._card(hud.UI.BAD if u.arrears > 0.0 else Color(0, 0, 0, 0))
	dues.add_child(hud._text("Your dues", 14, hud.UI.CREAM, true))
	var first: String = "First assessment in %ds, by your income." % maxi(0, ceili(u.next_dues - hud.world.game_time)) if u.assessment <= 0.0 else "Assessed $%d every 4 minutes, by your income." % int(u.assessment)
	_wrap(dues, "%s Arrears: $%d%s." % [first, int(u.arrears), " (vote lost, Art. 19)" if u.lost_vote() else ""], 12, hud.UI.TEXT)
	var drow: HBoxContainer = hud._row(dues)
	var withhold := CheckButton.new()
	withhold.text = "Withhold your dues (your vote in the Assembly is lost after two periods unpaid)"
	withhold.button_pressed = u.withhold
	withhold.focus_mode = Control.FOCUS_NONE
	withhold.add_theme_font_size_override("font_size", 12)
	withhold.toggled.connect(func(on: bool): u.withhold = on)
	drow.add_child(withhold)
	if u.arrears > 0.0:
		hud._button(drow, "Pay arrears", func(): return u.pay_arrears(), true, "good")
	# Peacekeeping, sanctions, indictments.
	var state: VBoxContainer = hud._card()
	state.add_child(hud._text("In force", 14, hud.UI.CREAM, true))
	for m in u.missions:
		state.add_child(hud._text("Peacekeepers between %s and %s (%ds)" % ["you" if int(m.a) == 0 else d.name_of(int(m.a)), "you" if int(m.b) == 0 else d.name_of(int(m.b)), maxi(0, ceili(float(m.until) - hud.world.game_time))], 12, hud.UI.TEXT))
	for i in u.members():
		var under := PackedStringArray()
		for m in ["targeted", "embargo", "economic", "voluntary"]:
			if u.under(i, m): under.append(m)
		if not under.is_empty():
			state.add_child(hud._text("%s: %s" % ["You" if i == 0 else d.name_of(i), ", ".join(under)], 12, hud.UI.BAD))
	for t in u.indicted:
		state.add_child(hud._text("Situation in %s: referred to the ICC" % ("your country" if int(t) == 0 else d.name_of(int(t))), 12, hud.UI.BAD))
	for t in u.authorised:
		state.add_child(hud._text("Force authorised against %s" % ("you" if int(t) == 0 else d.name_of(int(t))), 12, hud.UI.BAD))
	# Your treaties.
	var law: VBoxContainer = hud._card()
	law.add_child(hud._text("Your treaties", 14, hud.UI.CREAM, true))
	var npt: String = {"nws": "a recognised nuclear-weapon state", "party": "a party (no nuclear weapons)", "outside": "never joined", "withdrawn": "withdrawn"}.get(str(Cb.treaty(hud.world, 0, "npt")), "")
	_wrap(law, "Non-Proliferation Treaty: %s.  Chemical Weapons Convention: %s.  Biological Weapons Convention: %s.  International Criminal Court: %s." % [npt, str(Cb.treaty(hud.world, 0, "cwc")), str(Cb.treaty(hud.world, 0, "bwc")), "party" if bool(Cb.treaty(hud.world, 0, "icc")) else "not a party"], 12, hud.UI.TEXT)

func _un_record(u) -> void:
	var d: Node = hud.world.diplomacy
	if u.record.is_empty():
		hud._side_rows.add_child(hud._text("No resolution has been voted yet.", 13, hud.UI.MUTED))
		return
	for i in range(u.record.size() - 1, maxi(-1, u.record.size() - 15), -1):
		var r: Dictionary = u.record[i]
		var tone: Color = hud.UI.GOOD if r.result in ["adopted", "in force"] else (hud.UI.BAD if r.result == "vetoed" else hud.UI.MUTED)
		var card: VBoxContainer = hud._card(tone)
		var head := ("Resolution %d" % int(r.number)) if int(r.number) > 0 else ("Presidential statement" if r.measure == "statement" else "In force")
		head += ": %s" % str(r.result).to_upper()
		if r.result == "vetoed":
			head += " by " + ", ".join(PackedStringArray(r.get("vetoed_by", []).map(func(v): return "you" if int(v) == 0 else d.name_of(int(v)))))
		card.add_child(hud._text(head, 14, hud.UI.CREAM, true))
		_wrap(card, "%s%s" % [r.title, "  (%d-%d-%d)" % [int(r.tally.yes), int(r.tally.no), int(r.tally.abstain)] if int(r.number) > 0 else ""], 12, hud.UI.TEXT)
