extends RefCounted
## UN-specific widgets isolated from the concurrently edited menu and HUD.

static func council(p) -> void:
	var hud: Node = p.hud
	var u = hud.world.un
	for c in u.compliance:
		var box: VBoxContainer = hud._card(hud.UI.GOLD)
		box.add_child(hud._text("Awaiting compliance / consent", 14, hud.UI.CREAM, true))
		p._wrap(box, "%s between %s and %s. Both parties must accept; %ds remain." % [u.MEASURES[c.measure].name, u._cap(int(c.a)), u._cap(int(c.b)), maxi(0, ceili(float(c.until) - hud.world.game_time))])
		for i in [int(c.a), int(c.b)]:
			p._wrap(box, "%s: %s" % [u._cap(i), "awaiting reply" if not c.responses.has(i) else ("accepts" if bool(c.responses[i]) else "declines")])
		if 0 in [int(c.a), int(c.b)]:
			var case_id: int = int(c.id)
			var row: HBoxContainer = hud._row(box)
			hud._button(row, "Accept", func(): return u.respond(case_id, true), true, "good")
			hud._button(row, "Decline", func(): return u.respond(case_id, false), true, "bad")
	var civil: VBoxContainer = hud._card()
	civil.add_child(hud._text("Secretary-General and civilian relief", 14, hud.UI.CREAM, true))
	p._wrap(civil, "Good offices offer mediation without a Council vote. Humanitarian relief remains available under sanctions: $250 logistics, 80 food, 120s between deliveries. Peace observers require both parties' consent; they are a monitoring mission, not combat units.")
	var relief_row: HBoxContainer = hud._row(civil)
	hud._button(relief_row, "Arrange food relief ($250)", func(): return u.relief(0))
	for i in u.members():
		if i == 0: continue
		var who: int = i
		var row: HBoxContainer = hud._row(civil)
		var label: Label = hud._text(u._cap(i), 12, hud.UI.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		hud._button(row, "Send food relief", func(): return u.relief(who))
		if hud.world.diplomacy.at_war(0, who):
			hud._button(row, "Request mediation", func(): return u.mediate(who))

static func assembly(p) -> void:
	var hud: Node = p.hud
	var u = hud.world.un
	var box: VBoxContainer = hud._card(hud.UI.GOLD)
	box.add_child(hud._text("General Assembly: %d members" % u.members().size(), 16, hud.UI.CREAM, true))
	p._wrap(box, "One vote per member; no veto. Peace and security recommendations need two-thirds of yes + no votes; abstentions are excluded. A Council veto opens a debate and a separate recommendation vote here. Recommendations do not compel sanctions or stop wars.")
	if u.lost_vote(): p._wrap(box, "Your Assembly vote is suspended because of unpaid dues (Art. 19). Pay arrears in Organisation.", 13, hud.UI.BAD)
	if u.assembly_current != null:
		var dr: Dictionary = u.assembly_current
		var voting: VBoxContainer = hud._card(hud.UI.GOLD)
		voting.add_child(hud._text("Assembly vote open", 15, hud.UI.CREAM, true))
		p._wrap(voting, str(dr.title), 13, hud.UI.TEXT)
		p._wrap(voting, "Closes in %ds. Your choice: %s." % [maxi(0, ceili(float(dr.closes) - hud.world.game_time)), str(dr.player_choice) if str(dr.player_choice) != "" else "abstain (default)"])
		var row: HBoxContainer = hud._row(voting)
		var allowed: bool = 0 in u.members() and not u.lost_vote()
		hud._button(row, "Yes", func(): return u.cast_assembly("yes"), allowed, "good")
		hud._button(row, "No", func(): return u.cast_assembly("no"), allowed, "bad")
		hud._button(row, "Abstain", func(): return u.cast_assembly("abstain"), allowed)
	else:
		p._wrap(box, "No Assembly vote is open. %d recommendations are queued." % u.assembly_queue.size())
	for i in range(u.assembly_record.size() - 1, maxi(-1, u.assembly_record.size() - 12), -1):
		var dr: Dictionary = u.assembly_record[i]
		var card: VBoxContainer = hud._card(hud.UI.GOOD if dr.result == "adopted" else hud.UI.MUTED)
		card.add_child(hud._text("Recommendation: %s (%d-%d-%d)" % [str(dr.result).to_upper(), int(dr.tally.yes), int(dr.tally.no), int(dr.tally.abstain)], 14, hud.UI.CREAM, true))
		p._wrap(card, str(dr.title))
		if dr.result == "adopted" and float(dr.until) > hud.world.game_time:
			p._wrap(card, "Voluntary restrictions: %d participants; %ds remain. Food is exempt." % [dr.participants.size(), ceili(float(dr.until) - hud.world.game_time)])
			if int(dr.target) != 0:
				var target: int = int(dr.target)
				var row: HBoxContainer = hud._row(card)
				hud._button(row, "Join restrictions", func(): return u.join_voluntary(target, true), not 0 in dr.participants)
				hud._button(row, "Leave restrictions", func(): return u.join_voluntary(target, false), 0 in dr.participants)
