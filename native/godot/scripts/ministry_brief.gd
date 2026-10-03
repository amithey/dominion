extends RefCounted
## The briefing down the left of a ministry's window (hud.gd's side window):
## who runs the ministry, and its key figures in large type in the ministry's
## colour, the way a minister's morning note opens. Built again with the
## window, so it follows the game.

const UI := preload("res://scripts/ui_theme.gd")

## [the ministry's name, the office in charge (a key of the nation's "people")]
const OFFICES := {
	"diplomacy": ["Ministry of Foreign Affairs", "president"],
	"market": ["Treasury · World Market", "president"],
	"intel": ["Intelligence Directorate", "spymaster"],
	"territory": ["Ministry of the Interior", "president"],
}

static func subtitle(mode: String) -> String:
	return OFFICES.get(mode, ["", ""])[0]

## Fills `box` with the briefing for `mode`.
static func fill(hud: Node, box: VBoxContainer, mode: String) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var w: Node = hud.world
	var accent: Color = UI.ministry(mode)
	var title := _label(box, UI.caps("Briefing"), 13, accent.lightened(0.35), true)
	title.add_theme_font_size_override("font_size", 13)
	var me: Dictionary = w.map.nations[0]
	var office: String = OFFICES.get(mode, ["", "president"])[1]
	var who: String = str(me.get("people", {}).get(office, ""))
	if who != "":
		_label(box, who, 12, UI.MUTED)
	match mode:
		"diplomacy": _diplomacy(hud, box, accent)
		"market": _market(hud, box, accent)
		"intel": _intel(hud, box, accent)
		"territory": _territory(hud, box, accent)

static func _label(parent: Control, text: String, size := 14, colour := UI.TEXT, serif := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if serif: l.add_theme_font_override("font", UI.serif(600))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## A key figure: a large number in the ministry's colour, its caption beneath.
static func _figure(box: VBoxContainer, value: String, caption: String, accent: Color, tone := Color(0, 0, 0, 0)) -> void:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent, 0.10)
	s.border_color = accent if tone.a == 0.0 else tone
	s.border_width_left = 4
	s.set_corner_radius_all(5)
	s.content_margin_left = 12
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", s)
	box.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -3)
	card.add_child(col)
	var v := _label(col, value, 26 if value.length() <= 9 else (20 if value.length() <= 14 else 16), (accent if tone.a == 0.0 else tone).lightened(0.35), true)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.clip_text = true
	_label(col, caption, 12, UI.MUTED)

static func _diplomacy(hud: Node, box: VBoxContainer, accent: Color) -> void:
	var d: Node = hud.world.diplomacy
	var wars := 0
	var allies := 0
	var pacts := 0
	var sum := 0.0
	var count := 0
	var warmest := ["", -INF]
	var coldest := ["", INF]
	for i in range(1, d.n):
		if d.defeated(i): continue
		count += 1
		var r: float = d.rel(0, i)
		sum += r
		if d.at_war(0, i): wars += 1
		if d.allied(0, i): allies += 1
		if d.pact[0][i]: pacts += 1
		var name: String = d.name_of(i).split(" · ")[0]
		if r > warmest[1]: warmest = [name, r]
		if r < coldest[1]: coldest = [name, r]
	_figure(box, str(wars), "at war" if wars != 1 else "war", accent, UI.BAD if wars > 0 else Color(0, 0, 0, 0))
	_figure(box, "%d · %d" % [allies, pacts], "allies · trade pacts", accent)
	_figure(box, "%+d" % roundi(sum / maxf(count, 1)), "average standing, %d nations" % count, accent)
	if count > 0:
		_figure(box, warmest[0], "the warmest (%+d)" % int(warmest[1]), accent, UI.GOOD)
		_figure(box, coldest[0], "the coldest (%+d)" % int(coldest[1]), accent, UI.BAD if coldest[1] < -25.0 else Color(0, 0, 0, 0))

static func _market(hud: Node, box: VBoxContainer, accent: Color) -> void:
	var w: Node = hud.world
	var eco: Node = w.economy
	var m: Node = w.market
	_figure(box, "$" + hud.compact_number(eco.res.get("money", 0.0)), "in the treasury", accent)
	var rate: float = eco.rates.get("money", 0.0)
	_figure(box, "%s%.1f/s" % ["+" if rate >= 0.0 else "", rate], "income", accent, UI.GOOD if rate >= 0.0 else UI.BAD)
	_figure(box, "%d / %d" % [m.routes.size(), m.route_cap()], "trade routes", accent)
	# The dearest goods on the exchange: what is worth selling.
	var best := ["", -INF]
	for r in m.cfg.price:
		var p: float = m.price(r)
		if p > best[1]: best = [r, p]
	if best[0] != "":
		_figure(box, "%s $%.2f" % [str(best[0]).capitalize(), best[1]], "the dearest on the exchange", accent)

static func _intel(hud: Node, box: VBoxContainer, accent: Color) -> void:
	var e: Node = hud.world.espionage
	var d: Node = hud.world.diplomacy
	_figure(box, str(e.agents.size()), "agents", accent)
	_figure(box, str(e.missions.size()), "operations under way", accent)
	var deepest := ["", -1.0]
	for k in e.network:
		if float(e.network[k]) > deepest[1] and int(k) > 0 and int(k) < d.n:
			deepest = [d.name_of(int(k)).split(" · ")[0], float(e.network[k])]
	_figure(box, deepest[0] if deepest[0] != "" else "None yet", "the deepest network (%d)" % int(maxf(deepest[1], 0.0)), accent)
	_figure(box, str(e.reports.size()), "reports on file", accent)

static func _territory(hud: Node, box: VBoxContainer, accent: Color) -> void:
	var w: Node = hud.world
	var t: Node = w.territory
	var cells: int = int(t.yields(0).cells)
	_figure(box, str(cells), "hexes held", accent)
	_figure(box, "%d%%" % roundi(100.0 * cells / maxf(float(t.land_cells()), 1.0)), "of all the land", accent)
	var towns: int = w.buildings.filter(func(b): return b.owner == 0 and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"]).size()
	_figure(box, str(towns), "settlements", accent)
	var biggest := ["", -1]
	for i in range(1, w.diplomacy.n):
		var c: int = int(t.yields(i).cells)
		if c > biggest[1]: biggest = [w.diplomacy.name_of(i).split(" · ")[0], c]
	if biggest[1] >= 0:
		_figure(box, biggest[0], "the largest rival (%d hexes)" % biggest[1], accent, UI.BAD if biggest[1] > cells else Color(0, 0, 0, 0))
