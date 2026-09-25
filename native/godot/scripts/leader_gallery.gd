extends HBoxContainer
## Original ImageGen portraits. Resolve by identity, not player index, since
## campaign selection reorders the nations. Successors use the 3D fallback.
const ART := {"E. Hale": "hale", "K. Volkov": "volkov", "L. Moreau": "moreau", "R. Qadir": "qadir"}

static func portrait(identity: String) -> String:
	for key in ART:
		if key in identity: return "res://ui/leaders/%s-v1.png" % ART[key]
	return ""

## The portrait cropped round the face at `aspect` (width / height): the
## pictures are tall, the face in the upper third, so a centred crop cut the
## heads off.
static func face(identity: String, aspect: float) -> Texture2D:
	var path := portrait(identity)
	if path == "":
		return null
	var full: Texture2D = load(path)
	var w := float(full.get_width())
	var h := float(full.get_height())
	var cw := minf(w, h * aspect)
	var ch := cw / aspect
	var x := clampf(w * 0.43 - cw * 0.5, 0.0, w - cw)   # the face sits a little left of centre
	var y := clampf(h * 0.3 - ch * 0.42, 0.0, h - ch)    # and in the upper third
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	atlas.region = Rect2(x, y, cw, ch)
	return atlas

static func available(identities: Array) -> bool:
	return identities.all(func(identity): return portrait(str(identity)) != "")

func setup(colours: Array, identities: Array, together: bool) -> void:
	custom_minimum_size = Vector2(420, 300)
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(2):
		if not together and i == 0: continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", preload("res://scripts/ui_theme.gd").plate(Color("122329"), Color("080f13"), colours[i].darkened(0.3), 3))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
		var picture := TextureRect.new()
		picture.texture = load(portrait(str(identities[i])))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.tooltip_text = str(identities[i])
		card.add_child(picture)
