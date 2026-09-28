extends RefCounted
## One compact disclosure for the gameplay team's national profile data.
const UI := preload("res://scripts/ui_theme.gd")

static func append_to(parent: Control, faction_id: String, resized := Callable()) -> void:
	# Older builds can still open these menus before the profile module lands.
	var path := "res://scripts/national_profile.gd"
	if not ResourceLoader.exists(path):
		return
	var profile: Dictionary = load(path).summary(faction_id)
	if profile.is_empty():
		return
	var stack := VBoxContainer.new()
	stack.name = "NationalProfile"
	stack.add_theme_constant_override("separation", 8)
	parent.add_child(stack)
	var toggle := Button.new()
	toggle.text = "Strengths & weaknesses  +"
	toggle.toggle_mode = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size.y = 36
	toggle.tooltip_text = "Show this nation's gameplay advantages and trade-offs."
	stack.add_child(toggle)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.hide()
	stack.add_child(details)
	for group in [["strengths", "STRENGTHS", UI.GOOD], ["weaknesses", "WEAKNESSES", UI.BAD]]:
		var title := Label.new()
		title.text = group[1]
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", group[2])
		details.add_child(title)
		for line in profile.get(group[0], []):
			var text := Label.new()
			text.text = "• " + str(line)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_theme_font_size_override("font_size", 13)
			text.add_theme_color_override("font_color", UI.TEXT)
			details.add_child(text)
	toggle.toggled.connect(func(on):
		details.visible = on
		toggle.text = "Strengths & weaknesses  −" if on else "Strengths & weaknesses  +"
		if resized.is_valid():
			resized.call_deferred())
