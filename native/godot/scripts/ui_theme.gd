extends RefCounted
## The look of every panel, button and label in DOMINION, cut in the manner of
## the great 4X strategy games: deep navy plates inside a bronze frame, a body
## that catches the light along its top edge and sinks into shadow at the
## bottom, a gold rule under every heading, and headings set in letterspaced
## capitals. The plates are small textures drawn here at startup (a gradient,
## a bevel, a double frame and a soft drop shadow) and stretched as nine
## patches, which is what gives the panels their depth. Built once and merged
## into the default theme, so the HUD, the menus and the dialogs all share it.
## Windows' Bahnschrift carries the text and Palatino the headings; nothing is
## downloaded.

# ---------------------------------------------------------------- palette
const INK := Color("05090f")     ## the darkest ground: troughs, insets, frames
const BG := Color("0b1522")      ## a panel body
const BG_2 := Color("16263a")    ## a raised body: cards, rows, popups
const LIFT := Color(1, 1, 1, 0.09)  ## the lit top edge of a plate
const TRIM := Color("8c7038")    ## the bronze frame
const GOLD := Color("d7b264")    ## gold: rules, headings, the active state
const BRIGHT := Color("f2dfa9")  ## lit gold: hover and focus
const CREAM := Color("f6ecd4")
const TEXT := Color("cbd8e4")
const MUTED := Color("8497a9")
const GOOD := Color("83c98c")
const BAD := Color("e0805f")
# The bodies of the plates, lit edge first.
const PANEL_TOP := Color("17273c")
const PANEL_LOW := Color("0a1220")
const BAND_TOP := Color("2a4265")
const BAND_LOW := Color("101e30")
const KEY_TOP := Color("1e3149")
const KEY_LOW := Color("0e1a29")

static var _plates := {}

# ---------------------------------------------------------------- fonts

static func font(weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	f.hinting = TextServer.HINTING_LIGHT
	return f

static func serif(weight := 600) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "Times New Roman"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	return f

## Capitals with a hair space between the letters, the way a strategy game
## sets the name of a panel. Spaces between words open wider so the words
## still read as words.
static func caps(text: String) -> String:
	var upper := text.to_upper()
	var out := ""
	for i in range(upper.length()):
		var c := upper[i]
		out += "  " if c == " " else c
		if i < upper.length() - 1 and c != " " and upper[i + 1] != " ":
			out += " "
	return out

# ---------------------------------------------------------------- plates

## Draws one plate: a vertical gradient body, a hairline of light just inside
## the top edge, a double frame (near black outside, bronze inside), an
## optional gold rule along the bottom, and an optional soft drop shadow. Each
## distinct plate is drawn once and kept.
static func _plate_texture(top: Color, bottom: Color, border: Color, bevel: Color, rule: Color, rule_px: int, shadow: int, accent := Color(0, 0, 0, 0), accent_px := 0) -> ImageTexture:
	var key := "%s|%s|%s|%s|%s|%d|%d|%s|%d" % [top, bottom, border, bevel, rule, rule_px, shadow, accent, accent_px]
	if _plates.has(key):
		return _plates[key]
	var size := 64
	var pad: int = clampi(shadow, 0, 10)
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inner := size - pad * 2
	# The soft shadow, fading outwards from the frame.
	if pad > 0:
		for y in range(size):
			for x in range(size):
				var d: int = maxi(maxi(pad - x, x - (size - pad - 1)), maxi(pad - y, y - (size - pad - 1)))
				if d > 0:
					var fade := 1.0 - float(d) / float(pad + 1)
					img.set_pixel(x, y, Color(0, 0, 0, 0.42 * fade * fade))
	# The body.
	for y in range(inner):
		var c: Color = top.lerp(bottom, float(y) / float(maxi(inner - 1, 1)))
		for x in range(inner):
			img.set_pixel(pad + x, pad + y, c)
	# The gold rule along the bottom edge.
	if rule_px > 0 and rule.a > 0.0:
		for y in range(rule_px):
			for x in range(inner):
				img.set_pixel(pad + x, size - pad - 1 - y, rule)
	# A band of gold down the left edge: the mark of a menu entry.
	if accent_px > 0 and accent.a > 0.0:
		for x in range(clampi(accent_px, 0, 6)):
			for y in range(inner):
				img.set_pixel(pad + x, pad + y, accent)
	# The double frame: near black outside, bronze inside.
	if border.a > 0.0:
		for ring in range(2):
			var c: Color = Color(0, 0, 0, 0.85) if ring == 0 else border
			var lo: int = pad + ring
			var hi: int = size - pad - 1 - ring
			for i in range(lo, hi + 1):
				img.set_pixel(i, lo, c)
				img.set_pixel(i, hi, c)
				img.set_pixel(lo, i, c)
				img.set_pixel(hi, i, c)
	# The hairline of light just inside the top edge.
	if bevel.a > 0.0:
		var y: int = pad + (2 if border.a > 0.0 else 0)
		for x in range(pad + 2, size - pad - 2):
			img.set_pixel(x, y, bevel)
	var tex := ImageTexture.create_from_image(img)
	_plates[key] = tex
	return tex

## A plate as a stylebox: the two body colours, the frame, and the room the
## content needs inside it.
static func plate(top: Color, bottom: Color, border := Color(0, 0, 0, 0), margin := 10.0, bevel := LIFT, rule := Color(0, 0, 0, 0), rule_px := 0, shadow := 0, accent := Color(0, 0, 0, 0), accent_px := 0) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _plate_texture(top, bottom, border, bevel, rule, rule_px, shadow, accent, accent_px)
	var pad: int = clampi(shadow, 0, 10)
	s.set_texture_margin_all(pad + 10)
	s.set_content_margin_all(margin)
	if pad > 0:
		s.set_expand_margin_all(pad)
	return s

## The band across the head of a panel: light at the top, dark at the bottom,
## closed by a gold rule. The title of the panel sits on it.
static func band(margin := 10.0, top := BAND_TOP, bottom := BAND_LOW, rule := GOLD, rule_px := 2) -> StyleBoxTexture:
	return plate(top, bottom, Color(0, 0, 0, 0), margin, Color(1, 1, 1, 0.10), rule, rule_px)

## A trough: the sunken dark ground that a list, a picture or a bar sits in.
static func inset(margin := 6.0, radius := 2) -> StyleBoxFlat:
	return box(INK, Color(TRIM, 0.55), 1, radius, margin)

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
	# the cursor; struck in gold while held.
	t.set_stylebox("normal", "Button", plate(KEY_TOP, KEY_LOW, Color(TRIM, 0.85), 9.0))
	t.set_stylebox("hover", "Button", plate(Color("2b4462"), Color("15243a"), GOLD, 9.0, Color(1, 1, 1, 0.16)))
	t.set_stylebox("pressed", "Button", plate(Color("caa551"), Color("8a6c28"), BRIGHT, 9.0, Color(1, 1, 1, 0.30)))
	t.set_stylebox("hover_pressed", "Button", plate(Color("e0bc68"), Color("9c7c2f"), BRIGHT, 9.0, Color(1, 1, 1, 0.35)))
	t.set_stylebox("disabled", "Button", plate(Color("101823"), Color("0a1017"), Color(TRIM, 0.30), 9.0, Color(0, 0, 0, 0)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRIGHT, 1, 2, 0.0))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", BRIGHT)
	t.set_color("font_pressed_color", "Button", Color("14202e"))
	t.set_color("font_hover_pressed_color", "Button", Color("14202e"))
	t.set_color("font_disabled_color", "Button", Color("5c6b7a"))
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 14)
	# Drop-downs follow the buttons, but an open one stays readable rather
	# than turning gold.
	for kind in ["OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "disabled", "focus"]:
			t.set_stylebox(state, kind, t.get_stylebox(state, "Button"))
		t.set_stylebox("pressed", kind, plate(Color("2b4462"), Color("15243a"), GOLD, 9.0, Color(1, 1, 1, 0.16)))
		t.set_color("font_color", kind, CREAM)
		t.set_color("font_hover_color", kind, BRIGHT)
		t.set_color("font_pressed_color", kind, BRIGHT)
	t.set_stylebox("panel", "PopupMenu", plate(Color("1a2c42"), Color("0d1726"), TRIM, 6.0, LIFT, Color(0, 0, 0, 0), 0, 7))
	t.set_stylebox("hover", "PopupMenu", plate(Color("2e4868"), Color("1b2d45"), GOLD, 4.0, Color(1, 1, 1, 0.14)))
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
	t.set_color("selection_color", "LineEdit", Color("2f4a66"))
	for kind in ["CheckButton", "CheckBox"]:
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, BRIGHT)
		t.set_stylebox("focus", kind, box(Color(0, 0, 0, 0), BRIGHT, 1, 2, 3.0))
	# Text.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	# Progress bars: a sunken trough with a struck-gold fill.
	t.set_stylebox("background", "ProgressBar", inset(0.0, 2))
	t.set_stylebox("fill", "ProgressBar", plate(Color("e3c47c"), Color("ac8636"), Color(0, 0, 0, 0), 0.0, Color(1, 1, 1, 0.28)))
	t.set_color("font_color", "ProgressBar", CREAM)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "ProgressBar", 3)
	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", plate(Color("142234"), Color("080e18"), GOLD, 9.0, LIFT, Color(0, 0, 0, 0), 0, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)
	# Slim scroll bars.
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 2.0))
		t.set_stylebox("grabber", kind, box(Color("3f5872"), Color(0, 0, 0, 0), 0, 3, 2.0))
		t.set_stylebox("grabber_highlight", kind, box(TRIM, Color(0, 0, 0, 0), 0, 3, 2.0))
		t.set_stylebox("grabber_pressed", kind, box(GOLD, Color(0, 0, 0, 0), 0, 3, 2.0))
	# Headings take the serif face.
	t.add_type("HeaderLabel")
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", heading)
	t.set_font_size("font_size", "HeaderLabel", 21)
	t.set_color("font_color", "HeaderLabel", CREAM)
	# A tab in a strip: dim and flat while it waits, a gold plate while its
	# page is the one on show.
	t.add_type("TabButton")
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", plate(Color("16243a"), Color("0c1420"), Color(TRIM, 0.55), 7.0, Color(1, 1, 1, 0.05)))
	t.set_stylebox("hover", "TabButton", plate(Color("26405f"), Color("14233a"), GOLD, 7.0, Color(1, 1, 1, 0.14)))
	t.set_stylebox("pressed", "TabButton", plate(Color("d9b566"), Color("9c7a2e"), BRIGHT, 7.0, Color(1, 1, 1, 0.32)))
	t.set_stylebox("hover_pressed", "TabButton", plate(Color("e8c874"), Color("a88434"), BRIGHT, 7.0, Color(1, 1, 1, 0.36)))
	t.set_color("font_color", "TabButton", Color("b9c8d6"))
	t.set_color("font_hover_color", "TabButton", BRIGHT)
	t.set_color("font_pressed_color", "TabButton", Color("141f2b"))
	t.set_color("font_hover_pressed_color", "TabButton", Color("141f2b"))
	# A row in a list: a quiet plate that lifts under the cursor.
	t.add_type("RowButton")
	t.set_type_variation("RowButton", "Button")
	t.set_stylebox("normal", "RowButton", plate(Color("152437"), Color("0c1524"), Color(TRIM, 0.50), 6.0, Color(1, 1, 1, 0.06)))
	t.set_stylebox("hover", "RowButton", plate(Color("24405f"), Color("13243a"), GOLD, 6.0, Color(1, 1, 1, 0.16)))
	t.set_stylebox("pressed", "RowButton", plate(Color("2d4a6b"), Color("182c45"), BRIGHT, 6.0, Color(1, 1, 1, 0.20)))
	t.set_stylebox("disabled", "RowButton", plate(Color("101823"), Color("0a1017"), Color(TRIM, 0.22), 6.0, Color(0, 0, 0, 0)))
	t.set_color("font_color", "RowButton", CREAM)
	t.set_color("font_pressed_color", "RowButton", CREAM)
	t.set_color("font_hover_pressed_color", "RowButton", CREAM)
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

## A small texture from ui/icons (resources and panels).
static func icon(name: String) -> Texture2D:
	var path := "res://ui/icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null
