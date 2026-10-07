extends HBoxContainer
## Illustrated real-leader portraits for new games, with legacy art retained. Resolve by identity, not player index, since
## campaign selection reorders the nations. Successors use the 3D fallback.
const ART := {"E. Hale": "hale", "K. Volkov": "volkov", "L. Moreau": "moreau", "R. Qadir": "qadir"}

static func portrait(identity: String) -> String:
	var factions = preload("res://scripts/factions.gd")
	for i in range(factions.LEADERS.size()):
		if identity == factions.LEADERS[i]:
			var image := "res://ui/leaders/%s-v2.png" % factions.PORTRAITS[i]
			if ResourceLoader.exists(image): return image
			var emblem := "res://ui/leaders/%s-emblem.svg" % factions.PORTRAITS[i]
			return emblem if ResourceLoader.exists(emblem) else ""
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
	if path.ends_with(".svg"): return full
	var w := float(full.get_width())
	var h := float(full.get_height())
	var cw := minf(w, h * aspect)
	var ch := cw / aspect
	var current := path.ends_with("-v2.png")
	var x := clampf(w * (0.5 if current else 0.43) - cw * 0.5, 0.0, w - cw)   # the face sits a little left of centre
	var y := clampf(h * 0.3 - ch * (0.5 if current else 0.42), 0.0, h - ch)    # and in the upper third
	var atlas := AtlasTexture.new()
	atlas.atlas = full
	atlas.region = Rect2(x, y, cw, ch)
	return atlas

static func available(identities: Array) -> bool:
	return identities.all(func(identity): return portrait(str(identity)) != "")

## Old campaigns keep fictional presidents. Resolve their display portrait by
## faction identity; never by slot, because the player's chosen nation is first.
## A successor's name is retained rather than silently displaying another leader.
static func nation_portrait_identity(nation: Dictionary) -> String:
	var leader := str(nation.get("people", {}).get("president", ""))
	var legacy := leader.is_empty()
	for key in ART:
		if key in leader: legacy = true
	if not legacy: return leader
	var factions = preload("res://scripts/factions.gd")
	var index: int = factions.IDS.find(str(nation.get("id", "")))
	if index < 0: index = factions.ARSENALS.find(str(nation.get("arsenal", "")))
	if index < 0: index = factions.COLOURS.find(str(nation.get("color", "")).to_lower())
	return str(factions.LEADERS[index]) if index >= 0 else leader

## A close-up for the small HUD badge, using the same artwork as New Game.
static func badge(identity: String) -> Texture2D:
	var texture := face(identity, 1.0)
	if texture is AtlasTexture and portrait(identity).ends_with("-v2.png"):
		var full: Texture2D = texture.atlas
		var edge := minf(float(full.get_width()), float(full.get_height())) * 0.6
		texture.region = Rect2(clampf(full.get_width() * 0.5 - edge * 0.5, 0.0, full.get_width() - edge), clampf(full.get_height() * 0.3 - edge * 0.5, 0.0, full.get_height() - edge), edge, edge)
	return texture

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
