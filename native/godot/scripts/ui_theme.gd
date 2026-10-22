extends RefCounted
## Geopolitical atlas: deep navy, pale ink, sand selection and fine map rules.
## Sans-serif headings and body text; semantic warning colours remain.
## One shared theme covers the HUD, ministries, campaign and pause menus.

# ---------------------------------------------------------------- palette
const INK := Color("081725")
const BG := Color("10233a")
const BG_2 := Color("172f47")
const LIFT := Color(1, 1, 1, 0.0)   ## (the old plates' lit edge: flat now)
const TRIM := Color("526272")
const GOLD := Color("c1af86")
const BRIGHT := Color("f4ead4")
const CREAM := Color("eee9de")
const TEXT := Color("d8dfe5")
const MUTED := Color("a1b0bd")
const GOOD := Color("5fd39a")
const BAD := Color("f08a6b")
# The surfaces (the plates were two-tone gradients; now one flat colour each).
const PANEL_TOP := Color("10283e")
const PANEL_LOW := Color("10233a")
const BAND_TOP := Color("19354d")
const BAND_LOW := Color("142b42")
const KEY_TOP := Color("1c3850")
const KEY_LOW := Color("142b42")

## Ministry accents complement icons and names; colour never carries meaning alone.
const MINISTRY := {
	"economy": Color("d8bd80"), "market": Color("d8bd80"), "research": Color("91baf0"),
	"diplomacy": Color("b6a6e3"), "intel": Color("8dc8c9"), "territory": Color("a9c68f"), "defence": Color("e2a28a"), "un": Color("8ebfdc"),
	"land": Color("a9c68f"), "military": Color("e2a28a"), "build": Color("d8bd80"),
	"people": Color("a9c68f"), "cabinet": Color("d8bd80"), "menu": GOLD,
}
## Each resource's colour on the strip.
const RESOURCE_TINT := {
	"money": GOLD, "food": Color("b2d497"), "iron": Color("b2c5d8"), "oil": Color("d8b18d"),
	"silicon": Color("8ecadf"), "uranium": Color("c2d98e"), "gas": Color("b5b6e7"),
}

static func ministry(key: String) -> Color:
	return MINISTRY.get(key, GOLD)

## A screen button in its ministry's colour: lit from below by a bar of it.
static func ministry_button(b: Button, key: String) -> void:
	var accent := ministry(key)
	for state in [["normal", 0.0, 0.0, 0], ["hover", 0.10, 0.6, 2], ["pressed", 0.16, 1.0, 3], ["hover_pressed", 0.22, 1.0, 3]]:
		var s := StyleBoxFlat.new()
		s.bg_color = accent if int(state[3]) == 3 else Color(BG.lerp(accent, float(state[1])), 0.98)
		s.border_color = Color(accent, float(state[2]))
		s.border_width_bottom = int(state[3])
		s.set_corner_radius_all(5)
		s.corner_radius_bottom_left = 0 if int(state[3]) > 0 else 2
		s.corner_radius_bottom_right = 0 if int(state[3]) > 0 else 2
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		b.add_theme_stylebox_override(state[0], s)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	b.add_theme_color_override("icon_normal_color", accent.lightened(0.1))
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_pressed_color", INK)
	b.add_theme_color_override("icon_hover_pressed_color", INK)

## A tab inside a ministry's window: the open one filled with its colour.
static func ministry_tab(b: Button, key: String) -> void:
	var accent := ministry(key)
	for state in [["normal", 0.0, 0.0, 0], ["hover", 0.08, 0.5, 2], ["pressed", 0.14, 1.0, 2], ["hover_pressed", 0.2, 1.0, 2]]:
		var s := StyleBoxFlat.new()
		s.bg_color = accent if float(state[1]) >= 0.14 else Color(BG_2.lerp(accent, float(state[1])), 0.98)
		s.border_color = Color(accent, float(state[2]))
		s.border_width_bottom = int(state[3])
		s.set_corner_radius_all(5)
		s.corner_radius_bottom_left = 0
		s.corner_radius_bottom_right = 0
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		b.add_theme_stylebox_override(state[0], s)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)

## A window's title band: the slate band, a bar of the ministry's colour down
## its left, a hairline beneath.
static func ministry_band(key: String) -> StyleBoxFlat:
	var accent := ministry(key)
	var s := StyleBoxFlat.new()
	s.bg_color = BAND_TOP.lerp(accent, 0.06)
	s.border_color = accent
	s.border_width_bottom = 1
	s.set_corner_radius_all(0)
	s.content_margin_left = 14
	s.content_margin_right = 10
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s


# ---------------------------------------------------------------- fonts

static func font(weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Arial"])
	f.font_weight = weight
	# Grayscale: with LCD antialiasing and hinting, a hyphen or minus sign
	# vanished at 12-13 px ("income -10%" read "income  10%").
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	return f

# Compatibility name for existing callers: all interface text uses the same
# readable sans-serif family, with weight providing the heading hierarchy.
static func serif(weight := 600) -> SystemFont:
	return font(weight)

## Keep titles readable as written; letterspaced() is available for short marks.
static func caps(text: String) -> String:
	return text

static func letterspaced(text: String) -> String:
	var upper := text.to_upper()
	var out := ""
	for i in range(upper.length()):
		var c := upper[i]
		out += "  " if c == " " else c
		if i < upper.length() - 1 and c != " " and upper[i + 1] != " ":
			out += " "
	return out

# ---------------------------------------------------------------- plates

## A plate as a stylebox: the two body colours, the frame, and the room the
## content needs inside it.
## (The situation room draws it flat: one colour, a hairline frame, soft
## corners, a rule or an accent bar where asked, a soft shadow for a window.)
static func plate(top: Color, bottom: Color, border := Color(0, 0, 0, 0), margin := 10.0, bevel := LIFT, rule := Color(0, 0, 0, 0), rule_px := 0, shadow := 0, accent := Color(0, 0, 0, 0), accent_px := 0) -> StyleBox:
	var s := StyleBoxFlat.new()
	s.bg_color = top.lerp(bottom, 0.35)
	s.anti_aliasing = true
	s.set_corner_radius_all(8 if shadow > 0 else 5)
	if border.a > 0.0:
		s.border_color = Color(TRIM, 0.9) if border.s < 0.35 or border.v < 0.6 else Color(border, 0.9)
		s.set_border_width_all(1)
	if rule_px > 0 and rule.a > 0.0:
		s.border_width_bottom = clampi(rule_px, 1, 3)
		s.border_color = rule
	if accent_px > 0 and accent.a > 0.0:
		s.border_width_left = clampi(accent_px, 2, 4)
		s.border_color = accent
	if shadow > 0:
		s.shadow_size = clampi(shadow, 0, 12)
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(margin)
	return s

## The band across the head of a panel: light at the top, dark at the bottom,
## closed by a gold rule. The title of the panel sits on it.
static func band(margin := 10.0, top := BAND_TOP, bottom := BAND_LOW, rule := GOLD, rule_px := 1) -> StyleBox:
	var s := plate(top, bottom, Color(0, 0, 0, 0), margin, LIFT, Color(rule, 0.65), rule_px)
	s.set_corner_radius_all(0)
	return s

## A trough: the sunken dark ground that a list, a picture or a bar sits in.
static func inset(margin := 6.0, radius := 2) -> StyleBoxFlat:
	return box(INK, Color(TRIM, 0.7), 1, maxi(radius, 4), margin)

## A flat box, kept for the small parts — pills, rings, meters, rounded icon
## buttons — that want one colour and a round corner rather than a plate.
static func box(bg: Color, border: Color, width := 1, radius := 6, margin := 10.0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_offset = Vector2(0, 2)
	return s

# ---------------------------------------------------------------- the theme

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 15
	var bold := font(600)
	var heading := serif(600)
	# Panels: a navy plate in a bronze frame, standing off the battlefield on
	# its own shadow.
	var panel := plate(Color(PANEL_TOP, 0.97), Color(PANEL_LOW, 0.97), TRIM, 12.0, LIFT, Color(0, 0, 0, 0), 0, 7)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# Buttons: a navy keycap in a bronze frame; brighter and gold framed under
	# the cursor; gold edged and brighter while selected.
	t.set_stylebox("normal", "Button", box(Color("14263a"), Color(TRIM, 1.0), 1, 6, 9.0))
	t.set_stylebox("hover", "Button", box(Color("1b3450"), GOLD, 1, 6, 9.0))
	t.set_stylebox("pressed", "Button", box(Color(GOLD, 0.30), GOLD, 1, 6, 9.0))
	t.set_stylebox("hover_pressed", "Button", box(Color(GOLD, 0.40), BRIGHT, 1, 6, 9.0))
	t.set_stylebox("disabled", "Button", box(Color("0d1822"), Color(TRIM, 0.5), 1, 6, 9.0))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(GOLD, 0.7), 1, 6, 0.0))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("8d9dab"))
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 14)
	# Drop-downs follow the buttons, but an open one stays readable rather
	# than turning gold.
	for kind in ["OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "disabled", "focus"]:
			t.set_stylebox(state, kind, t.get_stylebox(state, "Button"))
		t.set_stylebox("pressed", kind, plate(Color("36546b"), Color("21384b"), GOLD, 9.0, Color(1, 1, 1, 0.16)))
		t.set_color("font_color", kind, CREAM)
		t.set_color("font_hover_color", kind, BRIGHT)
		t.set_color("font_pressed_color", kind, BRIGHT)
	t.set_stylebox("panel", "PopupMenu", plate(Color("243c50"), Color("111f30"), TRIM, 6.0, LIFT, Color(0, 0, 0, 0), 0, 7))
	t.set_stylebox("hover", "PopupMenu", plate(Color("36566e"), Color("20374b"), GOLD, 4.0, Color(1, 1, 1, 0.14)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", BRIGHT)
	t.set_color("font_disabled_color", "PopupMenu", MUTED)
	t.set_constant("v_separation", "PopupMenu", 12)
	t.set_constant("h_separation", "PopupMenu", 12)
	# Sliders and fields: the same brass over a sunken trough.
	t.set_stylebox("slider", "HSlider", inset(3.0, 3))
	t.set_stylebox("grabber_area", "HSlider", box(TRIM, TRIM, 0, 3, 3.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, GOLD, 0, 3, 3.0))
	t.set_stylebox("normal", "LineEdit", inset(9.0, 2))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), BRIGHT, 1, 2, 0.0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color("35565b"))
	for kind in ["CheckButton", "CheckBox"]:
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, BRIGHT)
		t.set_stylebox("focus", kind, box(Color(0, 0, 0, 0), BRIGHT, 1, 2, 3.0))
	var separator := box(Color(TRIM, 0.45), Color.TRANSPARENT, 0, 0, 0.0)
	separator.content_margin_left = 1
	separator.content_margin_top = 1
	t.set_stylebox("separator", "VSeparator", separator)
	t.set_stylebox("separator", "HSeparator", separator)
	# Text.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	# Progress bars: a sunken trough with a struck-gold fill.
	t.set_stylebox("background", "ProgressBar", inset(0.0, 2))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, Color(0, 0, 0, 0), 0, 4, 0.0))
	t.set_color("font_color", "ProgressBar", CREAM)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "ProgressBar", 3)
	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", plate(Color("1a3036"), Color("0a171b"), GOLD, 9.0, LIFT, Color(0, 0, 0, 0), 0, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)
	# Slim scroll bars.
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 2.0))
		t.set_stylebox("grabber", kind, box(Color("4b6668"), Color(0, 0, 0, 0), 0, 3, 2.0))
		t.set_stylebox("grabber_highlight", kind, box(TRIM, Color(0, 0, 0, 0), 0, 3, 2.0))
		t.set_stylebox("grabber_pressed", kind, box(GOLD, Color(0, 0, 0, 0), 0, 3, 2.0))
	# Headings use the same family at a stronger weight.
	t.add_type("HeaderLabel")
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", heading)
	t.set_font_size("font_size", "HeaderLabel", 21)
	t.set_color("font_color", "HeaderLabel", CREAM)
	# A tab in a strip: dim and flat while it waits, a gold plate while its
	# page is the one on show. Active text remains light for contrast.
	t.add_type("TabButton")
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", box(Color(BG_2, 0.6), Color(0, 0, 0, 0), 0, 6, 7.0))
	t.set_stylebox("hover", "TabButton", box(Color("1a3046"), Color(0, 0, 0, 0), 0, 6, 7.0))
	var tab_on := box(Color(GOLD, 0.16), GOLD, 0, 6, 7.0)
	tab_on.border_width_bottom = 2
	t.set_stylebox("pressed", "TabButton", tab_on)
	t.set_stylebox("hover_pressed", "TabButton", tab_on)
	t.set_color("font_color", "TabButton", MUTED)
	t.set_color("font_hover_color", "TabButton", BRIGHT)
	t.set_color("font_pressed_color", "TabButton", BRIGHT)
	t.set_color("font_hover_pressed_color", "TabButton", BRIGHT)
	# A row in a list: a quiet plate that lifts under the cursor.
	t.add_type("RowButton")
	t.set_type_variation("RowButton", "Button")
	t.set_stylebox("normal", "RowButton", box(Color("12212f"), Color(TRIM, 0.6), 1, 6, 6.0))
	t.set_stylebox("hover", "RowButton", box(Color("18304a"), GOLD, 1, 6, 6.0))
	var row_on := box(Color(GOLD, 0.18), GOLD, 0, 6, 6.0)
	row_on.border_width_left = 3
	t.set_stylebox("pressed", "RowButton", row_on)
	t.set_stylebox("disabled", "RowButton", box(Color("0d1822"), Color(TRIM, 0.4), 1, 6, 6.0))
	t.set_color("font_color", "RowButton", CREAM)
	t.set_color("font_pressed_color", "RowButton", CREAM)
	t.set_color("font_hover_pressed_color", "RowButton", CREAM)
	# Search and editable fields follow the same quiet inset treatment.
	t.set_stylebox("normal", "LineEdit", plate(INK, BG, Color(TRIM, 0.45), 6.0))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), GOLD, 1, 6, 5.0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", BRIGHT)
	t.set_color("selection_color", "LineEdit", Color("365d69"))
	# Atlas controls: sand selection has dark ink, including icons, for contrast.
	for kind in ["Button", "TabButton", "RowButton"]:
		var normal := box(KEY_LOW, Color(TRIM, 0.45), 1, 6, 9.0 if kind == "Button" else 6.0)
		var hover := box(KEY_TOP.lightened(0.05), GOLD, 1, 6, 9.0 if kind == "Button" else 6.0)
		var selected := box(GOLD, BRIGHT, 1, 6, 9.0 if kind == "Button" else 6.0)
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, hover)
		for state in ["pressed", "hover_pressed"]:
			if kind == "RowButton":
				# A list row carries its own light labels: selected it turns deep blue
				# with a gold frame, not sand (light text on sand could not be read).
				t.set_stylebox(state, kind, box(Color("2d4863"), GOLD, 2, 6, 6.0))
				t.set_color("font_%s_color" % state, kind, BRIGHT)
				t.set_color("icon_%s_color" % state, kind, BRIGHT)
				continue
			t.set_stylebox(state, kind, selected)
			t.set_color("font_%s_color" % state, kind, INK)
			t.set_color("icon_%s_color" % state, kind, INK)
		t.set_stylebox("focus", kind, box(Color.TRANSPARENT, BRIGHT, 2, 6, 0.0))
		t.set_color("icon_normal_color", kind, GOLD)
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, BRIGHT)
	t.set_stylebox("panel", "TooltipPanel", plate(BG_2, BG, GOLD, 9.0, LIFT, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("hover", "PopupMenu", box(GOLD, GOLD, 0, 2, 4.0))
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("grabber", "VScrollBar", box(TRIM, Color.TRANSPARENT, 0, 2, 2.0))
	t.set_stylebox("grabber", "HScrollBar", box(TRIM, Color.TRANSPARENT, 0, 2, 2.0))
	return t

## Merges the look into Godot's default theme, which every Control falls back
## to wherever it sits (CanvasLayers do not pass a window's theme down).
static func install() -> void:
	var t := build()
	var base := ThemeDB.get_default_theme()
	base.merge_with(t)
	base.default_font = t.default_font
	base.default_font_size = t.default_font_size
	ThemeDB.fallback_font = t.default_font
	ThemeDB.fallback_font_size = t.default_font_size

## Original engraved SVG icons, with PNG fallback for older callers.
static func icon(name: String) -> Texture2D:
	var vector_path := "res://ui/icons/%s.svg" % name
	if ResourceLoader.exists(vector_path):
		return load(vector_path)
	var path := "res://ui/icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null
