extends RefCounted
## The look of every panel, button and label in DOMINION, set once on the
## root window so the HUD, menus and dialogs all share it: deep teal panels
## with a thin gold trim and soft shadow, buttons that light up gold on hover,
## gold progress bars, and Windows' Bahnschrift (the DIN-style face strategy
## games favour) with Segoe UI as the fallback. Nothing is downloaded.

const BG := Color("101b30")
const BG_2 := Color("1b2c43")
const TRIM := Color("a28b56")
const GOLD := Color("e0c17c")
const CREAM := Color("f4e9cf")
const TEXT := Color("dde5e7")
const MUTED := Color("93a4aa")
const GOOD := Color("8fd18a")
const BAD := Color("e8836f")

static func font(weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	f.hinting = TextServer.HINTING_LIGHT
	return f

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

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 15
	var bold := font(600)
	var heading := SystemFont.new()
	heading.font_names = PackedStringArray(["Palatino Linotype", "Georgia", "Times New Roman"])
	heading.font_weight = 600
	# Panels.
	var panel := box(Color(BG, 0.97), TRIM, 1, 2, 12.0, 10)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# Buttons: dark slate, gold on hover, sunk when pressed, faded when disabled.
	t.set_stylebox("normal", "Button", box(Color("1b2a31"), Color("34464d"), 1, 5, 7.0))
	t.set_stylebox("hover", "Button", box(Color("233841"), GOLD, 1, 5, 7.0))
	t.set_stylebox("pressed", "Button", box(Color("2c2a1d"), GOLD, 2, 5, 7.0))
	t.set_stylebox("hover_pressed", "Button", box(Color("35321f"), GOLD, 2, 5, 7.0))
	t.set_stylebox("disabled", "Button", box(Color("141d21"), Color("263136"), 1, 5, 7.0))
	t.set_stylebox("focus", "Button", box(Color(0,0,0,0), CREAM, 2, 2, 0.0))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("66757a"))
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 14)
	# Drop-downs and their menus.
	for kind in ["OptionButton", "MenuButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(state, kind, t.get_stylebox(state, "Button"))
		t.set_color("font_color", kind, CREAM)
	t.set_stylebox("panel", "PopupMenu", box(BG_2, TRIM, 1, 5, 6.0, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color("2a3f47"), GOLD, 1, 4, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	# Text.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	# Progress bars: a dark trough with a gold fill.
	t.set_stylebox("background", "ProgressBar", box(Color("0a1216"), Color("2a383e"), 1, 4, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(Color("c9a653"), Color("e8cf86"), 0, 4, 0.0))
	t.set_color("font_color", "ProgressBar", CREAM)
	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", box(Color("0c161b"), GOLD, 1, 5, 9.0, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)
	# Slim scroll bars.
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 4, 2.0))
		t.set_stylebox("grabber", kind, box(Color("3c5058"), Color(0, 0, 0, 0), 0, 4, 2.0))
		t.set_stylebox("grabber_highlight", kind, box(Color("5b7079"), Color(0, 0, 0, 0), 0, 4, 2.0))
		t.set_stylebox("grabber_pressed", kind, box(GOLD, Color(0, 0, 0, 0), 0, 4, 2.0))
	# Headings get the heavier face through a type variation.
	t.add_type("HeaderLabel")
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", heading)
	t.set_font_size("font_size", "HeaderLabel", 21)
	t.set_color("font_color", "HeaderLabel", CREAM)
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
