extends HFlowContainer
## Persistent, readable diplomatic state. Colour is accompanied by words and
## progress steps, including when a counteroffer is waiting for the player.
const UI := preload("res://scripts/ui_theme.gd")
const GOOD := ["Accepted", "Regret expressed", "Conceded", "Heeded", "Complied", "Agreed", "Surrendered", "Exchanged"]
static func state(session: Dictionary, current: bool) -> Dictionary:
	if not current or session.get("phase", "") == "choosing": return {"step": 0, "text": "CHOOSE A CHANNEL", "cue": "", "colour": UI.MUTED}
	if session.phase in ["connecting", "travelling"]: return {"step": 1, "text": "DELEGATION TRAVELLING" if session.phase == "travelling" else "CONNECTING", "cue": "", "colour": UI.GOLD}
	if session.phase == "concluded": return {"step": 3, "text": "CONTACT CONCLUDED", "cue": "", "colour": UI.MUTED}
	if not session.get("counter", {}).is_empty(): return {"step": 2, "text": "COUNTEROFFER · YOUR DECISION", "cue": "counter", "colour": UI.GOLD}
	var results: Array = session.get("results", [])
	if not results.is_empty():
		var accepted: bool = results[-1].outcome in GOOD
		return {"step": 2, "text": str(results[-1].outcome).to_upper(), "cue": "accepted" if accepted else "rejected", "colour": UI.GOOD if accepted else UI.BAD}
	return {"step": 2, "text": "CONNECTED · READY TO TALK", "cue": "ready", "colour": UI.GOOD}

func setup(value: Dictionary) -> void:
	add_theme_constant_override("separation", 12)
	for i in range(3):
		var label := Label.new()
		label.text = ["1 · Contact", "2 · Negotiate", "3 · Communique"][i]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", UI.GOLD if value.step == i + 1 else UI.MUTED)
		add_child(label)
	var result := Label.new()
	result.text = value.text
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", value.colour)
	add_child(result)
	modulate.a = 0.45
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
