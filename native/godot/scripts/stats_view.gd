extends RefCounted
## Diplomacy > Statistics: the published figures of every nation (world_stats.gd): an overview table as
## the IMF and the statistics offices print it, with each nation's credit rating and its crises
## (crisis.gd); and for each indicator a chart over time and a ranking. Hide or show a nation's line.
const UI := preload("res://scripts/ui_theme.gd")
const Stats := preload("res://scripts/world_stats.gd")
const Crisis := preload("res://scripts/crisis.gd")
const BAD_UP := ["inflation", "unemployment", "debt", "fragility", "displaced"]

## The overview: one row a nation, its main figures as published, its rating and its crises.
static func overview(hud: Node, S: RefCounted) -> void:
	var w: Node = hud.world
	var card: VBoxContainer = hud._card(UI.GOLD)
	card.add_child(hud._text("Nations at a glance", 17, UI.CREAM, true))
	var note: Label = hud._text("As the statistics offices and the IMF publish them: GDP, its growth over the last quarter, inflation, unemployment, public debt, the markets' credit rating and the fragility index (higher is worse). Others' figures are a release late. Below each nation, its crises.", 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 440
	card.add_child(note)
	var cols := [["", 112], ["GDP", 66], ["Growth", 52], ["Infl.", 46], ["Jobless", 46], ["Debt", 44], ["Rating", 44], ["Fragile", 44]]
	var head: HBoxContainer = hud._row(card, 2)
	for c in cols:
		var l: Label = hud._text(str(c[0]), 11, UI.MUTED, true)
		l.custom_minimum_size.x = float(c[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if c[0] != "" else HORIZONTAL_ALIGNMENT_LEFT
		head.add_child(l)
	var crisis: RefCounted = w.get("crisis")
	for pair in S.ranking("gdp"):
		var id: int = pair[0]
		var row: HBoxContainer = hud._row(card, 2)
		var name: Label = hud._text("You" if id == 0 else w.diplomacy.name_of(id), 12, hud._nation_colour(id).lightened(0.35), id == 0)
		name.custom_minimum_size.x = float(cols[0][1])
		name.clip_text = true
		row.add_child(name)
		var growth: float = S.latest(id, "growth")
		var cells := [[Stats.format("gdp", pair[1]), UI.CREAM], [Stats.format("growth", growth), UI.GOOD if growth > 0.05 else (UI.BAD if growth < -0.05 else UI.MUTED)],
			[Stats.format("inflation", S.latest(id, "inflation")), UI.BAD if S.latest(id, "inflation") >= 30.0 else UI.CREAM],
			[Stats.format("unemployment", S.latest(id, "unemployment")), UI.CREAM],
			[Stats.format("debt", S.latest(id, "debt")), UI.BAD if S.latest(id, "debt") >= 150.0 else UI.CREAM]]
		var letters: String = crisis.rating(id) if crisis != null else "-"
		cells.append([letters, UI.GOOD if letters.begins_with("A") else (UI.BAD if letters.begins_with("C") or letters == "D" else UI.CREAM)])
		cells.append(["%.0f" % S.latest(id, "fragility"), UI.BAD if S.latest(id, "fragility") >= 90.0 else UI.CREAM])
		for i in range(cells.size()):
			var l: Label = hud._text(str(cells[i][0]), 12, cells[i][1])
			l.custom_minimum_size.x = float(cols[i + 1][1])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
		if crisis != null:
			var names := PackedStringArray()
			for k in crisis.list(id):
				names.append(str(Crisis.KINDS[k].title))
			if not names.is_empty():
				var line: Label = hud._text("   " + ", ".join(names), 11, UI.BAD if id == 0 else Color(0.95, 0.72, 0.4))
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				line.custom_minimum_size.x = 440
				card.add_child(line)
	# Your own crises, in full.
	if crisis != null and not crisis.list(0).is_empty():
		var mine: VBoxContainer = hud._card(UI.BAD)
		mine.add_child(hud._text("Your crises", 15, UI.CREAM, true))
		for c in crisis.describe(0):
			var l: Label = hud._text("%s: %s" % [c.title, c.text], 12, UI.CREAM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 440
			mine.add_child(l)

static func draw(panel: RefCounted) -> void:
	var hud: Node = panel.hud
	var w: Node = hud.world
	var S: RefCounted = w.stats
	if S == null:
		return
	if S.series.is_empty():
		S.release()
	var metric: String = panel.stats_metric
	if metric != "overview" and not Stats.METRICS.has(metric):
		metric = "overview"
	var groups: Array = [["", ["overview"]]] + Stats.GROUPS
	for g in groups:
		var tabs := HFlowContainer.new()
		tabs.add_theme_constant_override("h_separation", 4)
		tabs.add_theme_constant_override("v_separation", 4)
		hud._side_rows.add_child(tabs)
		if g[0] != "":
			var head: Label = hud._text(str(g[0]), 12, UI.MUTED, true)
			head.custom_minimum_size.x = 64
			tabs.add_child(head)
		for m in g[1]:
			var which: String = m
			var b: Button = hud._button(tabs, "Overview" if m == "overview" else Stats.TITLES[m], func():
				panel.stats_metric = which
				hud.refresh_side()
				return "")
			b.toggle_mode = true
			b.button_pressed = m == metric
			b.tooltip_text = "Every nation's main figures and its crises." if m == "overview" else Stats.NOTES[m]
	if metric == "overview":
		overview(hud, S)
		return
	var card: VBoxContainer = hud._card(UI.GOLD)
	card.add_child(hud._text("%s  (%s)" % [Stats.TITLES[metric], Stats.UNITS[metric]], 17, UI.CREAM, true))
	var note: Label = hud._text(Stats.NOTES[metric], 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 440
	card.add_child(note)
	var ids: Array = S.series.keys()
	ids.sort()
	var visible_ids: Array = ids.filter(func(id): return not panel.stats_hidden.get(id, false))
	card.add_child(chart(hud, S, metric, visible_ids, Vector2(470, 230)))
	# The ranking: the legend, the latest figure, the change over two minutes, and the error of an estimate.
	var rank := 0
	for pair in S.ranking(metric):
		var id: int = pair[0]
		rank += 1
		var row: HBoxContainer = hud._row(card, 8)
		var hidden: bool = panel.stats_hidden.get(id, false)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = hud._nation_colour(id) if not hidden else Color(0.4, 0.45, 0.5)
		row.add_child(dot)
		var name: String = "You" if id == 0 else w.diplomacy.name_of(id)
		var label: Label = hud._text("%d.  %s" % [rank, name], 14, (hud._nation_colour(id).lightened(0.35) if not hidden else UI.MUTED), id == 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var c: float = S.change(id, metric)
		var arrow := "▲" if c > 0.005 else ("▼" if c < -0.005 else "–")
		var good: bool = (c > 0.0) != (metric in BAD_UP)   # (rising inflation, debt or fragility is bad news)
		if metric in ["growth"]:
			row.add_child(hud._text("", 13, UI.MUTED))
		else:
			row.add_child(hud._text("%s %d%%" % [arrow, int(roundf(minf(absf(c), 9.99) * 100.0))], 13, (UI.GOOD if good else UI.BAD) if absf(c) > 0.005 else UI.MUTED))
		var bound: float = S.error(id) * (0.5 if metric == "milex" else 1.0)
		var value: Label = hud._text(Stats.format(metric, pair[1]) + ("" if id == 0 or not metric in Stats.ESTIMATED else "  ±%d%%" % int(roundf(bound * 100.0))), 14, UI.CREAM, true)
		value.custom_minimum_size.x = 120
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		var toggle := Button.new()
		toggle.flat = true
		toggle.text = "hide" if not hidden else "show"
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.pressed.connect(func():
			panel.stats_hidden[id] = not panel.stats_hidden.get(id, false)
			hud.refresh_side())
		row.add_child(toggle)
	if metric in Stats.ESTIMATED:
		var est: Label = hud._text("Figures for other nations are estimates. Intelligence on a nation (Intel, Dossiers) narrows the error.", 12, UI.MUTED)
		est.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		est.custom_minimum_size.x = 440
		card.add_child(est)

## The chart: one line per nation, you drawn thicker, with the axes labelled.
static func chart(hud: Node, S: RefCounted, metric: String, ids: Array, size: Vector2) -> Control:
	var control := Control.new()
	control.custom_minimum_size = size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = UI.font(500)
	var lines := {}
	var t0 := INF
	var t1 := -INF
	var hi := 0.0
	var lo := 0.0
	for id in ids:
		var pts: Array = S.points(id, metric)
		lines[id] = pts
		for p in pts:
			t0 = minf(t0, float(p.t))
			t1 = maxf(t1, float(p.t))
			hi = maxf(hi, float(p.v))
			lo = minf(lo, float(p.v))
	hi = maxf(hi * 1.08, 1.0)
	lo *= 1.08
	var left := 52.0
	var bottom := 22.0
	control.draw.connect(func():
		control.draw_style_box(UI.box(Color("0b1b29"), Color("36516b"), 1, 4, 0.0), Rect2(Vector2.ZERO, size))
		var plot := Rect2(left, 8, size.x - left - 10, size.y - bottom - 12)
		for tick in range(0, 5):
			var y: float = plot.position.y + plot.size.y * float(tick) / 4.0
			control.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.7, 0.8, 0.9, 0.12), 1.0)
			control.draw_string(font, Vector2(4, y + 4), Stats.format(metric, lerpf(hi, lo, float(tick) / 4.0)), HORIZONTAL_ALIGNMENT_LEFT, left - 8, 11, Color(0.75, 0.82, 0.88, 0.8))
		if lo < 0.0:
			var zero: float = plot.end.y - plot.size.y * (0.0 - lo) / (hi - lo)
			control.draw_line(Vector2(plot.position.x, zero), Vector2(plot.end.x, zero), Color(0.9, 0.9, 0.9, 0.35), 1.0)
		var span := maxf(t1 - t0, 1.0)
		control.draw_string(font, Vector2(plot.position.x, size.y - 6), "%d min ago" % int(roundf(span / 60.0)) if span >= 60.0 else "start", HORIZONTAL_ALIGNMENT_LEFT, 100, 11, Color(0.75, 0.82, 0.88, 0.8))
		control.draw_string(font, Vector2(plot.end.x - 40, size.y - 6), "now", HORIZONTAL_ALIGNMENT_RIGHT, 40, 11, Color(0.75, 0.82, 0.88, 0.8))
		for id in ids:
			var pts: Array = lines[id]
			if pts.size() < 2:
				continue
			var line := PackedVector2Array()
			for p in pts:
				line.append(Vector2(plot.position.x + plot.size.x * (float(p.t) - t0) / span, plot.end.y - plot.size.y * (float(p.v) - lo) / (hi - lo)))
			var colour: Color = hud._nation_colour(id)
			control.draw_polyline(line, Color(0, 0, 0, 0.5), 4.0 if id == 0 else 3.0, true)
			control.draw_polyline(line, colour.lightened(0.15), 3.0 if id == 0 else 2.0, true)
			control.draw_circle(line[line.size() - 1], 3.5, colour.lightened(0.3)))
	return control
