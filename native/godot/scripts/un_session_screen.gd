extends Control
## A persistent invitation and an accessible, separate UN chamber. All ballots
## go through un.gd; opening/closing this screen never casts a vote or pauses time.
const UI := preload("res://scripts/ui_theme.gd")
const ACCENT := Color("8ebfdc")
const EFFECTS := {
	"statement": "A political statement. Adoption worsens Council members' relations with the subject; it imposes no sanctions.",
	"condemn": "A condemnation. Supporting delegations worsen relations with the subject, whose public support also falls. No automatic sanctions.",
	"ceasefire": "Requests a ceasefire. Both parties must consent before peace takes effect; adoption alone does not stop the war.",
	"peacekeeping": "Proposes civilian peace observers. Both parties must consent; observers monitor rather than fight.",
	"withdraw": "Demands peace within 120 seconds. Failure to comply can lead to sanctions.",
	"targeted": "Targeted sanctions reduce the subject's treasury income by 10% for 360 seconds.",
	"embargo": "An arms embargo reduces the subject's military production by 40% for 360 seconds.",
	"economic": "Comprehensive sanctions reduce income by 30% for 360 seconds and restrict trade. Food relief is exempt.",
	"nonproliferation": "Combines an arms embargo for 720 seconds with comprehensive economic sanctions for 360 seconds. Food relief is exempt.",
	"icc": "Refers the situation for independent ICC investigation and affects relations with ICC parties. This is not a conviction or an arrest warrant.",
	"force": "Authorises a coalition for 600 seconds. Other nations may join a war against the subject; authorisation does not itself order your troops to attack.",
	"lift": "Removes Council sanctions from the subject.",
}
var hud: Node
var screen: PanelContainer
var invitation: PanelContainer
var invitation_text: Label
var join_button: Button
var heading: Label
var phase: Label
var title: Label
var details: Label
var effect: Label
var rule: Label
var eligibility: Label
var choice_label: Label
var result_label: Label
var timer: ProgressBar
var seats: HFlowContainer
var ballots: Dictionary = {}
var selected := "council"
var proposal: Dictionary = {}
var seen := {}
var pending: Array = []
var _source
var _elapsed := 0.0
var _seat_signature := ""
var _feedback := ""

func label(parent: Node, words: String, px := 16, colour := UI.TEXT) -> Label:
	var item: Label = hud._text(words, px, colour, px >= 22)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func button(parent: Node, words: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = words
	item.custom_minimum_size = Vector2(0, 44)
	item.add_theme_font_size_override("font_size", 16)
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func card(parent: Node, words: String) -> VBoxContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UI.box(UI.BG_2, UI.TRIM, 1, 8, 18))
	parent.add_child(plate)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	plate.add_child(body)
	label(body, words, 17, ACCENT)
	return body

func setup(owner_hud: Node) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	invitation = PanelContainer.new()
	invitation.add_theme_stylebox_override("panel", UI.box(UI.INK, ACCENT, 2, 6, 12, 8))
	if hud.get("_dock") != null:
		invitation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud._dock.column.add_child(invitation)   # a card in the notification dock, not a panel over the map
		hud._dock.column.move_child(invitation, 0)
	else:
		invitation.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		invitation.offset_left = -245; invitation.offset_right = 245
		invitation.offset_top = 112
		add_child(invitation)
	var feed := VBoxContainer.new()
	feed.add_theme_constant_override("separation", 8)
	invitation.add_child(feed)
	label(feed, "UNITED NATIONS", 15, ACCENT)
	invitation_text = label(feed, "", 16)
	join_button = button(feed, "Attend session", func():
		if not pending.is_empty(): open_proposal(pending[0].chamber, pending[0].draft))
	screen = PanelContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_stylebox_override("panel", UI.box(UI.INK, ACCENT, 2, 0, 24))
	add_child(screen)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	screen.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	header.add_child(hud._icon("un", 48))
	heading = label(header, "UNITED NATIONS", 28, UI.CREAM)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "Return to game  ·  Esc", close)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	layout.add_child(navigation)
	button(navigation, "Security Council", func(): open_session("council"))
	button(navigation, "General Assembly", func(): open_session("assembly"))
	button(navigation, "UN affairs & records", func(): close(); hud.toggle_panel("un", true))
	phase = label(navigation, "", 16, ACCENT)
	phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer = ProgressBar.new()
	timer.custom_minimum_size.y = 6
	timer.show_percentage = false
	layout.add_child(timer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	var briefing := card(content, "THE VOTE")
	title = label(briefing, "", 24, UI.CREAM)
	details = label(briefing, "", 15, UI.MUTED)
	effect = label(briefing, "", 17)
	rule = label(briefing, "", 15, ACCENT)
	var delegates := card(content, "WHO VOTES")
	seats = HFlowContainer.new()
	seats.add_theme_constant_override("h_separation", 8)
	seats.add_theme_constant_override("v_separation", 8)
	delegates.add_child(seats)
	# The ballot stays visible even when the briefing scrolls on a smaller screen.
	var ballot := card(layout, "YOUR VOTE")
	result_label = label(ballot, "", 18, UI.GOOD)
	eligibility = label(ballot, "", 15, UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	ballot.add_child(row)
	for value in ["yes", "no", "abstain"]:
		var vote: String = value
		var b := button(row, "", func(): cast(vote))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 54
		var accent: Color = {"yes":UI.GOOD, "no":UI.BAD, "abstain":ACCENT}[value]
		b.add_theme_stylebox_override("normal", UI.box(UI.BG_2, accent, 2, 6, 12))
		b.add_theme_stylebox_override("hover", UI.box(UI.BG_2.lightened(0.12), accent, 2, 6, 12))
		b.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, UI.CREAM, 2, 6, 12))
		ballots[value] = b
	choice_label = label(ballot, "", 16, UI.CREAM)
	label(layout, "The game keeps running. You can change your vote until it closes.", 14, UI.MUTED)
	screen.hide()
	invitation.hide()
	refresh()

func key(chamber: String, dr: Dictionary) -> String:
	# Statements have number zero; opened time distinguishes successive ones.
	return "%s:%d:%.3f:%d:%s" % [chamber, int(dr.get("number", -1)), float(dr.get("opens", dr.get("closes", 0))), int(dr.get("source", -1)), dr.get("title", "")]

func concluded(chamber: String, dr: Dictionary) -> bool:
	var u = hud.world.un
	# Assembly drafts inherit the vetoed Council record's result. The live
	# authoritative chamber pointer, not that inherited field, defines activity.
	var active = u.current if chamber == "council" else u.assembly_current
	return not is_same(active, dr) and dr.has("result")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()

func refresh() -> void:
	if hud == null: return
	var u = hud.world.un
	if u == null:
		screen.hide(); invitation.hide(); return
	if not is_same(_source, u):
		_source = u; seen.clear(); proposal = {}; _seat_signature = ""
	if screen.visible and not proposal.is_empty():
		# Loading a save replaces draft dictionaries on the same UN object.
		# Rebind to the authoritative draft so the open ballot cannot become stale.
		var active = u.current if selected == "council" else u.assembly_current
		var history: Array = u.record if selected == "council" else u.assembly_record
		var candidates: Array = history.duplicate()
		if active != null: candidates.push_front(active)
		var rebound := false
		for candidate in candidates:
			if key(selected, candidate) == key(selected, proposal):
				proposal = candidate; rebound = true; break
		if not rebound: proposal = {}; _feedback = ""
	pending.clear()
	for chamber in ["council", "assembly"]:
		var dr = u.current if chamber == "council" else u.assembly_current
		if dr != null: pending.append({"chamber":chamber, "draft":dr})
		var history: Array = u.record if chamber == "council" else u.assembly_record
		if not history.is_empty():
			var last: Dictionary = history.back()
			if not seen.has(key(chamber, last)): pending.append({"chamber":chamber, "draft":last})
	# An uncast live ballot takes priority over an old result or a ballot already
	# submitted in the other chamber, so simultaneous sessions remain actionable.
	pending.sort_custom(func(a, b): return priority(a) < priority(b))
	# Keep the UN navigation badge live while another window is being used.
	# The large invitation must not cover its tabs, briefing or controls.
	# It sits in the notification dock on the right edge: it gives way only when a window leaves no room for it.
	var workspace_busy: bool = hud.modal_input_active() or hud.side_mode == "un"   # (the UN window itself says what the card would)
	if hud.get("_dock") != null and hud._dock.space() < 300.0: workspace_busy = true
	invitation.visible = not screen.visible and not pending.is_empty() and hud.visible and not workspace_busy
	if not pending.is_empty():
		var top: Dictionary = pending[0]
		var dr: Dictionary = top.draft
		var active: bool = not concluded(top.chamber, dr)
		var status := "result ready"
		if active:
			var consult: bool = dr.get("phase", "") == "consult"
			var deadline: float = float(dr.get("opens", 0)) + u.CONSULT_SECONDS if consult else float(dr.closes)
			status = ("vote opens" if consult else "voting closes") + " in " + preload("res://scripts/un_plain.gd").span(deadline - hud.world.game_time)
		invitation_text.text = "%s · %s\n%s" % ["Security Council" if top.chamber == "council" else "General Assembly", status, str(dr.title)]
		join_button.text = ("Attend session" if active else "Read decision") + ("  ·  %d messages" % pending.size() if pending.size() > 1 else "")
	if hud._screen_buttons.has("un"):
		hud._screen_buttons.un.text = "UN (%d)" % pending.size() if not pending.is_empty() else "UN"
	if screen.visible: render()

func priority(message: Dictionary) -> int:
	if concluded(message.chamber, message.draft): return 3
	if message.draft.get("phase", "") == "vote" and message.draft.get("player_choice", "") == "": return 0
	return 1 if message.draft.get("phase", "") == "consult" else 2

func open_session(chamber := "council") -> void:
	var u = hud.world.un
	if u == null: return
	var dr = u.current if chamber == "council" else u.assembly_current
	var history: Array = (u.record if chamber == "council" else u.assembly_record).filter(func(r): return u.MEASURES.has(str(r.get("measure", ""))))   # (a standing sanction is not a session)
	open_proposal(chamber, dr if dr != null else (history.back() if not history.is_empty() else {}))

func open_proposal(chamber: String, dr: Dictionary) -> void:
	selected = chamber; proposal = dr; _feedback = ""; _seat_signature = ""
	hud.close_windows()
	if hud._resource_site != null: hud._resource_site.hide()
	hud.world.dragging = false
	hud.world.middle_drag = false
	hud.move_child(self, -1)
	screen.show(); invitation.hide()
	if not dr.is_empty() and concluded(chamber, dr): seen[key(chamber, dr)] = true
	render()

func close() -> void:
	if not proposal.is_empty() and concluded(selected, proposal): seen[key(selected, proposal)] = true
	screen.hide()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus): focus.release_focus()
	refresh()

func _input(event: InputEvent) -> void:
	if not screen.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func blocked_reason() -> String:
	var u = hud.world.un
	if proposal.is_empty(): return "No vote right now."
	if concluded(selected, proposal): return "Voting has closed. The result is above."
	var current = u.current if selected == "council" else u.assembly_current
	if not is_same(current, proposal): return "This session has ended."
	if hud.world.game_time >= float(proposal.closes): return "Voting has closed. Counting the votes."
	if selected == "assembly":
		if not 0 in u.members(): return "You attend as an observer and cannot vote."
		if u.lost_vote(): return "Your Assembly vote is suspended for unpaid dues. Pay them under UN, Dues & members."
	else:
		if not 0 in proposal.get("electorate", u.council()): return "You can watch, but you have no Council seat in this vote."
		if proposal.measure != "statement" and int(u.MEASURES.get(proposal.measure, {}).get("chapter", 7)) == 6 and 0 in [int(proposal.target), int(proposal.other)]:
			return "You are a party to this dispute, so you must abstain."
	if str(proposal.get("phase", "")) != "vote": return "Talks are under way. Voting opens when they end."
	return ""

func cast(value: String) -> void:
	if blocked_reason() != "": return
	var u = hud.world.un
	_feedback = u.cast_assembly(value) if selected == "assembly" else u.cast(value)
	render()

func render() -> void:
	var u = hud.world.un
	var assembly: bool = selected == "assembly"
	heading.text = "United Nations  ·  " + ("General Assembly" if assembly else "Security Council")
	var empty: bool = proposal.is_empty()
	var done: bool = not empty and concluded(selected, proposal)
	var consult: bool = not empty and proposal.get("phase", "") == "consult" and not done
	var deadline: float = 0.0 if empty else (float(proposal.get("opens", 0)) + u.CONSULT_SECONDS if consult else float(proposal.get("closes", 0)))
	var remaining: int = maxi(0, ceili(deadline - hud.world.game_time))
	phase.text = "NO VOTE NOW" if empty else ("VOTE ENDED" if done else ("TALKS · VOTE OPENS IN " if consult else "VOTING OPEN · ENDS IN ") + preload("res://scripts/un_plain.gd").span(remaining).to_upper())
	timer.max_value = u.CONSULT_SECONDS if consult else u.VOTE_SECONDS
	timer.value = remaining if not done else 0
	title.text = "No vote right now." if empty else str(proposal.title)
	details.text = "A message appears when a new vote opens." if empty else "About: %s   ·   Proposed by: %s" % [u._cap(int(proposal.target)), "Secretary-General" if int(proposal.by) < 0 else u._cap(int(proposal.by))]
	effect.text = "" if empty else ("A recommendation, not an order. It changes how countries see the target, and economic limits only apply to those who choose to join." if assembly else preload("res://scripts/un_plain.gd").what(proposal.measure))
	if not empty:
		effect.text = ("Adopted measure: " if done and proposal.result == "adopted" else ("Proposed effect (not adopted): " if done else "If adopted: ")) + effect.text
	rule.text = "To pass: two thirds of the Yes and No votes. No veto here." if assembly else ("To pass: nobody objects." if not empty and proposal.measure == "statement" else "To pass: %d yes votes and no veto. Abstaining neither helps nor hurts." % (u.needed(proposal) if not empty else maxi(1, ceili(u.council().size() * u.PASS_SHARE))))
	var reason := blocked_reason()
	eligibility.text = reason if reason != "" else "You can vote now."
	var choice: String = str(proposal.get("player_choice", ""))
	choice_label.text = "You voted: " + choice.to_upper() if choice != "" else "You have not voted. No vote counts as abstaining."
	if empty: choice_label.text = "You can vote when a vote opens."
	if not empty and not assembly and proposal.measure != "statement" and int(u.MEASURES.get(proposal.measure, {}).get("chapter", 7)) == 6 and 0 in [int(proposal.target), int(proposal.other)]:
		choice_label.text = "You must ABSTAIN: you are a party to this dispute."
	elif "observer" in reason or "no Council seat" in reason or "suspended" in reason:
		choice_label.text = "You can watch, but not vote."
	if _feedback != "": choice_label.text += "  ·  " + _feedback
	var no_label := "NO"
	if not assembly and not empty:
		if proposal.measure == "statement": no_label = "OBJECT"
		elif u.permanent(0): no_label = "VETO (blocks it)"
	var texts := {"yes":"YES", "no":no_label, "abstain":"ABSTAIN"}
	for value in ballots:
		ballots[value].text = ("✓  " if choice == value else "") + texts[value]
		ballots[value].disabled = reason != ""
	result_label.text = ""
	result_label.visible = done
	if done:
		var count: Dictionary = proposal.get("tally", {})
		result_label.text = "RESULT: %s  ·  %d yes  ·  %d no  ·  %d abstain" % [str(proposal.result).to_upper(), count.get("yes",0), count.get("no",0), count.get("abstain",0)]
		result_label.add_theme_color_override("font_color", UI.GOOD if proposal.result == "adopted" else UI.BAD)
		seen[key(selected, proposal)] = true
	var members: Array = u.members() if assembly else proposal.get("electorate", u.council())
	var signature := str(members) + selected + str(done) + str(proposal.get("votes", {})) + str(proposal.get("player_choice", ""))
	if signature != _seat_signature:
		_seat_signature = signature
		for child in seats.get_children(): seats.remove_child(child); child.queue_free()
		for member in members:
			var plate := PanelContainer.new()
			plate.custom_minimum_size.x = 205
			plate.add_theme_stylebox_override("panel", UI.box(UI.BG, ACCENT if member == 0 else UI.TRIM, 1, 6, 12))
			seats.add_child(plate)
			var body := VBoxContainer.new()
			plate.add_child(body)
			label(body, "You" if member == 0 else u._cap(member), 16, UI.CREAM)
			var status: String = "Member" if assembly else ("Permanent · can veto" if u.permanent(member) else "Elected seat")
			if done: status = "Voted: " + str(proposal.get("votes", {}).get(member, "not recorded")).to_upper()
			elif member == 0 and choice != "": status = "You voted: " + choice.to_upper()
			label(body, status, 14, ACCENT if member == 0 else UI.MUTED)
